import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/zzz_theme_extension.dart';
import '../../../widgets/stat_item.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import '../services/auto_tracker.dart';
import '../services/trainer_service.dart';
import '../services/exercise_providers.dart';

/// 运动页面
///
/// 顶部：今日运动总览（步数 / 运动时长 / 消耗热量）
/// 模式切换按钮（self ↔ trainer）
/// self 模式：实时步数 + 今日运动记录列表
/// trainer 模式：训练计划 + 手动记录入口 + 到期日提示
class ExercisePage extends ConsumerStatefulWidget {
  const ExercisePage({super.key});

  @override
  ConsumerState<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends ConsumerState<ExercisePage> {
  late final ExerciseService _exerciseService;
  late final AutoTracker _autoTracker;
  late final TrainerService _trainerService;
  StreamSubscription<int>? _stepSubscription;

  DailyExerciseSummary? _summary;
  ModeInfo? _modeInfo;
  int _currentSteps = 0;
  bool _loading = true;
  String? _error;

  // 操作级 loading 状态
  bool _modeSwitchLoading = false;
  bool _manualRecordLoading = false;
  final Set<String> _completingPlanIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_initAndLoad);
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _autoTracker.dispose();
    _trainerService.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    try {
      _exerciseService = ref.read(exerciseServiceProvider);
      _autoTracker = ref.read(autoTrackerProvider);
      _trainerService = ref.read(trainerServiceProvider);

      // 初始化私教模式检查
      await _trainerService.init();

      // 监听步数
      _stepSubscription = _autoTracker.stepStream.listen((steps) {
        if (mounted) setState(() => _currentSteps = steps);
      });

      await _refresh();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '初始化失败';
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (_exerciseService == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final summary = await _exerciseService.getTodaySummary();
      _modeInfo = await _exerciseService.getMode();

      if (mounted) {
        setState(() {
          _summary = summary;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 模式切换
  // ---------------------------------------------------------------------------

  Future<void> _onSwitchMode() async {
    final isTrainer = _modeInfo?.mode == ExerciseMode.trainer;
    final targetLabel = isTrainer ? '自主运动' : '私教模式';
    final targetMode = isTrainer ? ExerciseMode.self : ExerciseMode.trainer;

    final confirmed = await _showModeSwitchDialog(targetLabel);
    if (confirmed != true || !mounted) return;

    setState(() => _modeSwitchLoading = true);
    try {
      if (targetMode == ExerciseMode.trainer) {
        final endDate = await _showDatePicker();
        if (endDate == null) return;
        await _trainerService?.enableTrainer(endDate);
      } else {
        await _trainerService?.enableSelf();
      }
      await _refresh();
    } finally {
      if (mounted) setState(() => _modeSwitchLoading = false);
    }
  }

  Future<bool?> _showModeSwitchDialog(String targetLabel) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('切换运动模式'),
        content: Text('确认切换到「$targetLabel」模式？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _showDatePicker() async {
    return showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择私教到期日',
    );
  }

  // ---------------------------------------------------------------------------
  // 手动记录
  // ---------------------------------------------------------------------------

  Future<void> _onManualRecord() async {
    final result = await _showManualRecordSheet();
    if (result == null || !mounted) return;

    setState(() => _manualRecordLoading = true);
    try {
      final record = await _exerciseService?.addRecord(
        type: result.type,
        durationMinutes: result.durationMinutes,
        calories: result.calories,
      );

      if (record != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('已记录${record.type.label} ${record.durationMinutes}分钟')),
        );
        await _refresh();
      }
    } finally {
      if (mounted) setState(() => _manualRecordLoading = false);
    }
  }

  /// 手动记录半屏弹窗
  Future<_ManualRecordResult?> _showManualRecordSheet() {
    ExerciseType selectedType = ExerciseType.running;
    int minutes = 30;
    int? calories;

    return showModalBottomSheet<_ManualRecordResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '手动记录运动',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // 运动类型
                  Text('运动类型', style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ExerciseType.values.map((type) {
                      final selected = selectedType == type;
                      return ChoiceChip(
                        label: Text('${type.emoji} ${type.label}'),
                        selected: selected,
                        onSelected: (_) {
                          setSheetState(() => selectedType = type);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 时长
                  Row(
                    children: [
                      Text('时长', style: Theme.of(ctx).textTheme.labelMedium),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: minutes > 1
                            ? () => setSheetState(
                                () => minutes = (minutes - 5).clamp(1, 180))
                            : null,
                      ),
                      Text(
                        '$minutes 分钟',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setSheetState(
                            () => minutes = (minutes + 5).clamp(1, 180)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 确认按钮
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        ctx,
                        _ManualRecordResult(
                          type: selectedType,
                          durationMinutes: minutes,
                          calories: calories,
                        ),
                      ),
                      child: const Text('记录'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final isTrainer = _modeInfo?.mode == ExerciseMode.trainer;
    final trainerEndDate = _modeInfo?.trainerEndDate;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ---- 今日总览 ----
          _buildOverviewCard(theme),
          const SizedBox(height: 12),

          // ---- 模式切换 ----
          _buildModeToggle(theme, isTrainer),
          const SizedBox(height: 12),

          // ---- 到期日提示 ----
          if (isTrainer && trainerEndDate != null)
            _buildExpiryNotice(theme, trainerEndDate),

          // ---- 内容区 ----
          if (isTrainer)
            _buildTrainerContent(theme)
          else
            _buildSelfContent(theme),

          const SizedBox(height: 16),

          // ---- 手动记录按钮 ----
          Center(
            child: FilledButton.icon(
              onPressed: _manualRecordLoading ? null : _onManualRecord,
              icon: _manualRecordLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_circle_outline),
              label: Text(_manualRecordLoading ? '记录中...' : '手动记录'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 今日总览 ----

  Widget _buildOverviewCard(ThemeData theme) {
    final zzz = theme.extension<ZzzThemeExtension>();
    final summary = _summary;
    final totalMin = summary?.totalMinutes ?? 0;
    final totalKcal = summary?.totalCalories ?? 0;
    final totalSteps = summary?.totalSteps ?? _currentSteps;

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            StatItem(
              label: '步数',
              value: '$totalSteps',
              unit: '步',
              icon: Icons.directions_walk,
              color: zzz?.signal ?? theme.colorScheme.primary,
            ),
            _buildDivider(theme),
            StatItem(
              label: '运动时长',
              value: '$totalMin',
              unit: '分钟',
              icon: Icons.timer_outlined,
              color: totalMin > 0
                  ? (zzz?.success ?? Colors.teal)
                  : theme.colorScheme.onSurface,
            ),
            _buildDivider(theme),
            StatItem(
              label: '消耗热量',
              value: '$totalKcal',
              unit: '千卡',
              icon: Icons.local_fire_department,
              color: totalKcal > 0
                  ? (zzz?.warning ?? Colors.orange)
                  : theme.colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(
      width: 1,
      height: 40,
      color: theme.dividerColor.withValues(alpha: 0.5),
    );
  }

  // ---- 模式切换 ----

  Widget _buildModeToggle(ThemeData theme, bool isTrainer) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              isTrainer ? Icons.fitness_center : Icons.directions_run,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              isTrainer ? '私教模式' : '自主运动',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _modeSwitchLoading ? null : _onSwitchMode,
              icon: _modeSwitchLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isTrainer ? Icons.swap_horiz : Icons.swap_horiz,
                      size: 18,
                    ),
              label: Text(
                _modeSwitchLoading ? '切换中...' : (isTrainer ? '切回自主' : '开启私教'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 到期日提示 ----

  Widget _buildExpiryNotice(ThemeData theme, DateTime endDate) {
    final daysLeft = endDate.difference(DateTime.now()).inDays;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: daysLeft <= 3
            ? Colors.orange.shade50
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: daysLeft <= 3
              ? Colors.orange.shade200
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            daysLeft <= 3 ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 18,
            color: daysLeft <= 3 ? Colors.orange : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              daysLeft <= 0
                  ? '私教已到期，下次刷新将自动切回自主模式'
                  : '私教到期日：${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}（剩余 $daysLeft 天）',
              style: theme.textTheme.bodySmall?.copyWith(
                color: daysLeft <= 3 ? Colors.orange.shade800 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 自主模式内容 ----

  Widget _buildSelfContent(ThemeData theme) {
    final records = _summary?.records ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 步数目标进度
        _buildStepGoalCard(theme),
        const SizedBox(height: 16),

        // 今日运动记录
        Text(
          '今日运动记录',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (records.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '今日暂无运动记录\n出门走走吧！',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          )
        else
          ...records.map((r) => _buildRecordTile(theme, r)),
      ],
    );
  }

  Widget _buildStepGoalCard(ThemeData theme) {
    final steps = _currentSteps;
    final goal = _autoTracker?.stepGoal ?? 8000;
    final progress = (steps / goal).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk, size: 20),
                const SizedBox(width: 6),
                Text(
                  '步数目标',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '$steps / $goal',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progress >= 1.0 ? '目标达成！' : '还差 ${goal - steps} 步',
              style: theme.textTheme.labelSmall?.copyWith(
                color: progress >= 1.0
                    ? Colors.green
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 私教模式内容 ----

  Widget _buildTrainerContent(ThemeData theme) {
    final plans = _trainerService?.todayPlans ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日训练计划',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (plans.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '今日暂无训练计划\n可通过手动记录添加运动',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          )
        else
          ...plans.map((plan) => _buildPlanTile(theme, plan)),

        const SizedBox(height: 16),

        // 今日已完成记录
        Text(
          '已完成记录',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if ((_summary?.records ?? []).isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '暂无完成记录',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          )
        else
          ...(_summary?.records ?? []).map((r) => _buildRecordTile(theme, r)),
      ],
    );
  }

  // ---- 通用组件 ----

  Widget _buildRecordTile(ThemeData theme, ExerciseRecord record) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(record.type.emoji, style: const TextStyle(fontSize: 26)),
        title: Text(
          record.type.label,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${record.formattedTime} · ${record.source == "sensor" ? "自动记录" : "手动记录"}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${record.durationMinutes} 分钟',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (record.calories != null && record.calories! > 0)
              Text(
                '${record.calories} 千卡',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.orange.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanTile(ThemeData theme, TrainingPlan plan) {
    final timeStr =
        '${plan.scheduledTime.hour.toString().padLeft(2, '0')}:${plan.scheduledTime.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 0,
      color: plan.isCompleted
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: plan.isCompleted
            ? BorderSide.none
            : BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: plan.isCompleted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : Text(plan.exerciseType.emoji,
                style: const TextStyle(fontSize: 26)),
        title: Text(
          plan.exerciseType.label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '$timeStr · ${plan.durationMinutes} 分钟${plan.notes != null ? " · ${plan.notes}" : ""}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: plan.isCompleted
            ? SizedBox(
                width: 60,
                child: Text(
                  '已完成',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            : FilledButton(
                onPressed: _completingPlanIds.contains(plan.id)
                    ? null
                    : () async {
                        setState(() => _completingPlanIds.add(plan.id));
                        try {
                          final record =
                              await _trainerService?.completeTraining(
                            planId: plan.id,
                            type: plan.exerciseType,
                            durationMinutes: plan.durationMinutes,
                          );
                          if (record != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '已完成${record.type.label} ${record.durationMinutes}分钟'),
                              ),
                            );
                            await _refresh();
                          }
                        } finally {
                          if (mounted)
                            setState(() => _completingPlanIds.remove(plan.id));
                        }
                      },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(60, 32),
                ),
                child: _completingPlanIds.contains(plan.id)
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('完成', style: TextStyle(fontSize: 13)),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 辅助类
// ---------------------------------------------------------------------------

class _ManualRecordResult {
  final ExerciseType type;
  final int durationMinutes;
  final int? calories;

  const _ManualRecordResult({
    required this.type,
    required this.durationMinutes,
    this.calories,
  });
}

// StatItem 已提取为共享组件 widgets/stat_item.dart
