import 'dart:async';

import 'exercise_service.dart';
import '../models/exercise.dart';

/// 自主运动模式追踪器
///
/// 负责监听步数变化，使用 Android Activity Recognition API 识别运动类型，
/// 并自动上报运动记录到后端 exercise_records 表。
///
/// 步数目标默认 8000，可在设置中修改。
class AutoTracker {
  final ExerciseService _service;

  /// 每日步数目标
  int stepGoal = 8000;

  /// 当前累计步数（由外部 pedometer 插件更新）
  int _currentSteps = 0;

  /// 当前识别的运动类型
  ExerciseType _currentActivity = ExerciseType.other;

  /// 运动会话开始时间
  DateTime? _sessionStart;

  /// 运动进行中标志
  bool _isActive = false;

  /// 自动上报的最低时长（分钟），避免短时停顿也被记录
  static const int _minSessionMinutes = 1;

  /// 步数变化流控制器
  final StreamController<int> _stepController = StreamController<int>.broadcast();

  /// 运动类型变化流控制器
  final StreamController<ExerciseType> _activityController =
      StreamController<ExerciseType>.broadcast();

  AutoTracker({required ExerciseService service}) : _service = service;

  /// 当前步数
  int get currentSteps => _currentSteps;

  /// 当前活动类型
  ExerciseType get currentActivity => _currentActivity;

  /// 运动是否活跃
  bool get isActive => _isActive;

  /// 步数变化流
  Stream<int> get stepStream => _stepController.stream;

  /// 活动类型变化流
  Stream<ExerciseType> get activityStream => _activityController.stream;

  // ---------------------------------------------------------------------------
  // 步数更新
  // ---------------------------------------------------------------------------

  /// 外部 pedometer 插件回调
  void onStepCount(int steps) {
    _currentSteps = steps;
    _stepController.add(steps);

    // 步数增长自动将活动定为步行
    if (_currentActivity == ExerciseType.other && steps > 0) {
      _updateActivity(ExerciseType.walking);
    }
  }

  // ---------------------------------------------------------------------------
  // Activity Recognition 回调
  // ---------------------------------------------------------------------------

  /// Android Activity Recognition 回调
  void onActivityRecognized(String activityType, int confidence) {
    if (confidence < 75) return; // 忽略低置信度

    final inferred = ExerciseType.inferFromActivity(activityType: activityType);

    // 静止状态：结束当前运动会话
    if (activityType == 'still' && _isActive) {
      _endSession();
      return;
    }

    // 新运动类型：结束旧会话、开始新会话
    if (inferred != _currentActivity && inferred != ExerciseType.other) {
      if (_isActive) _endSession();
      _updateActivity(inferred);
      _startSession(inferred);
    }
  }

  // ---------------------------------------------------------------------------
  // 运动会话管理
  // ---------------------------------------------------------------------------

  void _updateActivity(ExerciseType type) {
    _currentActivity = type;
    _activityController.add(type);
  }

  void _startSession(ExerciseType type) {
    _sessionStart = DateTime.now();
    _isActive = true;
  }

  Future<void> _endSession() async {
    if (_sessionStart == null || !_isActive) return;

    final duration = DateTime.now().difference(_sessionStart!).inMinutes;
    _isActive = false;
    _sessionStart = null;

    if (duration < _minSessionMinutes) return;

    final steps = _currentSteps;
    final estimatedCalories = _estimateCalories(_currentActivity, duration);

    await _service.addAutoRecord(
      type: _currentActivity,
      durationMinutes: duration,
      calories: estimatedCalories,
      steps: steps,
    );
  }

  /// 手动结束当前会话（App 退出时调用）
  Future<void> endCurrentSession() async {
    await _endSession();
  }

  // ---------------------------------------------------------------------------
  // 热量估算
  // ---------------------------------------------------------------------------

  /// 基于运动类型和时长的粗略热量估算
  int _estimateCalories(ExerciseType type, int minutes) {
    // MET 值估算（约值）
    final met = switch (type) {
      ExerciseType.walking => 3.5,
      ExerciseType.running => 8.0,
      ExerciseType.cycling => 6.0,
      ExerciseType.swimming => 7.0,
      ExerciseType.strength => 5.0,
      ExerciseType.yoga => 2.5,
      ExerciseType.hiit => 10.0,
      ExerciseType.stretching => 2.0,
      ExerciseType.other => 3.0,
    };
    // 热量(kcal) ≈ MET × 体重(kg, 默认70) × 时间(h)
    return (met * 70 * minutes / 60).round();
  }

  // ---------------------------------------------------------------------------
  // 资源释放
  // ---------------------------------------------------------------------------

  void dispose() {
    _stepController.close();
    _activityController.close();
  }
}
