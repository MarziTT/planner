import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../habits/notify_manager.dart';
import 'exercise_service.dart';
import '../models/exercise.dart';

/// 私教模式服务
///
/// 负责：
/// - 检查 trainer_end_date，到期自动切换回 self 模式
/// - 按时推送训练提醒（jarvis_exercise channel）
/// - 快捷操作：[已完成] [推迟 1 小时]
/// - 训练完成后手动记录：类型、时长、强度
class TrainerService {
  final ExerciseService _service;
  Timer? _checkTimer;

  /// 当前模式信息
  ModeInfo? _modeInfo;

  /// 当前训练计划（由外部设置）
  List<TrainingPlan> _todayPlans = [];

  TrainerService({required ExerciseService service}) : _service = service;

  ModeInfo? get modeInfo => _modeInfo;
  bool get isTrainerMode => _modeInfo?.mode == ExerciseMode.trainer;
  DateTime? get endDate => _modeInfo?.trainerEndDate;
  bool get isExpired {
    if (!isTrainerMode || endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// 是否到期
  bool get hasExpired => isExpired;

  List<TrainingPlan> get todayPlans => List.unmodifiable(_todayPlans);

  // ---------------------------------------------------------------------------
  // 初始化
  // ---------------------------------------------------------------------------

  /// 加载当前模式并检查到期
  Future<void> init() async {
    _modeInfo = await _service.getMode();

    // 到期自动回切
    if (isExpired) {
      await _service.switchMode(ExerciseMode.self);
      _modeInfo = ModeInfo(mode: ExerciseMode.self);
    }

    // 定期检查到期
    _checkTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _checkExpiry(),
    );
  }

  Future<void> _checkExpiry() async {
    if (isExpired) {
      _modeInfo = await _service.switchMode(ExerciseMode.self);
    }
  }

  // ---------------------------------------------------------------------------
  // 模式切换
  // ---------------------------------------------------------------------------

  /// 切换到私教模式
  Future<ModeInfo?> enableTrainer(DateTime endDate) async {
    _modeInfo = await _service.switchMode(ExerciseMode.trainer, trainerEndDate: endDate);
    if (_modeInfo != null && _modeInfo!.mode == ExerciseMode.trainer) {
      _scheduleTodayPlans();
    }
    return _modeInfo;
  }

  /// 切换到自主模式
  Future<ModeInfo?> enableSelf() async {
    await _cancelAllReminders();
    _modeInfo = await _service.switchMode(ExerciseMode.self);
    return _modeInfo;
  }

  // ---------------------------------------------------------------------------
  // 训练计划
  // ---------------------------------------------------------------------------

  /// 设置今日训练计划并调度提醒
  void setTodayPlans(List<TrainingPlan> plans) {
    _todayPlans = plans;
    _scheduleTodayPlans();
  }

  void _scheduleTodayPlans() {
    for (final plan in _todayPlans) {
      if (plan.isCompleted) continue;
      _scheduleReminder(plan);
    }
  }

  void _scheduleReminder(TrainingPlan plan) {
    final scheduledDate = plan.scheduledTime;

    // 已过时间则立即通知
    final now = DateTime.now();
    final notifyTime = scheduledDate.isAfter(now) ? scheduledDate : now;

    NotifyManager.show(
      channel: NotifyChannel.exercise,
      title: '训练提醒',
      body: '${plan.exerciseType.label} · ${plan.durationMinutes} 分钟 · ${plan.notes ?? ""}',
      priority: NotifyPriority.important,
      scheduledDate: notifyTime,
      payload: NotifyPayload(
        eventType: 'exercise',
        eventId: plan.id.hashCode,
        scheduleId: plan.id.hashCode,
      ),
      extraActions: [
        const AndroidNotificationAction(
          NotifyActionId.complete,
          '已完成',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          NotifyActionId.postpone,
          '推迟 1 小时',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
  }

  Future<void> _cancelAllReminders() async {
    await NotifyManager.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // 完成训练
  // ---------------------------------------------------------------------------

  /// 完成一项训练并记录到后端
  Future<ExerciseRecord?> completeTraining({
    required String planId,
    required ExerciseType type,
    required int durationMinutes,
    int? calories,
  }) async {
    // 标记计划完成
    final idx = _todayPlans.indexWhere((p) => p.id == planId);
    if (idx >= 0) {
      _todayPlans[idx] = _todayPlans[idx].markCompleted();
    }

    // 写入记录
    return _service.addRecord(
      type: type,
      durationMinutes: durationMinutes,
      calories: calories,
    );
  }

  // ---------------------------------------------------------------------------
  // 资源释放
  // ---------------------------------------------------------------------------

  void dispose() {
    _checkTimer?.cancel();
  }
}

/// 单次训练计划
class TrainingPlan {
  final String id;
  final ExerciseType exerciseType;
  final int durationMinutes;
  final DateTime scheduledTime;
  final String? notes;
  final bool isCompleted;

  const TrainingPlan({
    required this.id,
    required this.exerciseType,
    required this.durationMinutes,
    required this.scheduledTime,
    this.notes,
    this.isCompleted = false,
  });

  TrainingPlan markCompleted() {
    return TrainingPlan(
      id: id,
      exerciseType: exerciseType,
      durationMinutes: durationMinutes,
      scheduledTime: scheduledTime,
      notes: notes,
      isCompleted: true,
    );
  }
}
