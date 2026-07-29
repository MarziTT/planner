import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/local_cache_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/zzz_theme_extension.dart';
import '../../../widgets/stat_item.dart';
import '../models/meal.dart';
import '../services/meal_ocr.dart';
import 'meal_entry_dialog.dart';

/// 饮食页面 — 今日饮食总览 + 拍照记录
///
/// 四张卡片（早餐/午餐/晚餐/加餐）+ 拍照按钮 + 统计卡片。
class MealPage extends ConsumerStatefulWidget {
  const MealPage({super.key});

  @override
  ConsumerState<MealPage> createState() => _MealPageState();
}

class _MealPageState extends ConsumerState<MealPage> {
  MealOcrService? _ocrService;
  DailySummaryResponse? _summary;
  bool _loading = true;
  String? _error;
  bool _ocrLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initAndLoad);
  }

  Future<void> _initAndLoad() async {
    try {
      final dio = ref.read(apiClientProvider);
      final cache = ref.read(localCacheProvider);
      _ocrService = MealOcrService(dio: dio, cache: cache);
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
    if (_ocrService == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final summary = await _ocrService!.getDailySummary();
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

  Future<void> _onCaptureTap() async {
    if (_ocrService == null || _ocrLoading) return;

    setState(() => _ocrLoading = true);

    try {
      final hint = MealType.inferFromTime(DateTime.now());
      final result = await _ocrService!.captureAndRecognize(mealTypeHint: hint);

      if (!mounted) return;

      if (result.isCancelled) return;

      if (result.isSuccess && result.record != null) {
        final record = result.record!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已记录${record.type.label}：${record.itemsSummary}'),
            duration: const Duration(seconds: 2),
          ),
        );
        await _refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('识别失败：${result.reason ?? "请手动记录"}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ocrLoading = false);
    }
  }

  Future<void> _onManualAdd(MealType type) async {
    if (_ocrService == null) return;

    final result = await MealEntryDialog.show(context, initialType: type);
    if (result == null) return;

    final record = await _ocrService!.addManual(
      mealType: result.mealType,
      items: result.items,
      recordedAt: result.recordedAt,
    );

    if (!mounted) return;

    if (record != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加${record.type.label}：${record.itemsSummary}'),
          duration: const Duration(seconds: 2),
        ),
      );
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('添加失败，请检查网络后重试'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ---- 统计卡片 ----
          _buildStatsCard(theme),
          const SizedBox(height: 16),

          // ---- 四餐卡片 ----
          ...MealType.values.map((type) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildMealCard(theme, type),
              )),

          const SizedBox(height: 8),

          // ---- 拍照按钮 ----
          Center(
            child: FilledButton.icon(
              onPressed: _ocrLoading ? null : _onCaptureTap,
              icon: _ocrLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(_ocrLoading ? '识别中...' : '拍照记录'),
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

  Widget _buildStatsCard(ThemeData theme) {
    final zzz = theme.extension<ZzzThemeExtension>();
    final summary = _summary;
    final totalKcal = summary?.totalCalories ?? 0;
    final weeklyAvg = summary?.weeklyAvgCalories ?? 0;

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            StatItem(
              label: '今日热量',
              value: '$totalKcal',
              unit: '千卡',
              icon: Icons.local_fire_department,
              color: totalKcal > 0
                  ? (zzz?.warning ?? Colors.orange)
                  : theme.colorScheme.onSurface,
            ),
            Container(
              width: 1,
              height: 40,
              color: theme.dividerColor.withValues(alpha: 0.5),
            ),
            StatItem(
              label: '本周日均',
              value: weeklyAvg > 0 ? '${weeklyAvg.toStringAsFixed(0)}' : '--',
              unit: '千卡',
              icon: Icons.show_chart,
              color: zzz?.signal ?? theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(ThemeData theme, MealType type) {
    final zzz = theme.extension<ZzzThemeExtension>();
    final record = _summary?.byType[type.apiValue] ?? null;

    return Card(
      elevation: 0,
      color: record != null
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: record != null
            ? BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              )
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Text(
          type.emoji,
          style: const TextStyle(fontSize: 28),
        ),
        title: Text(
          type.label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: record != null
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        subtitle: _buildMealSubtitle(theme, record),
        trailing: record != null
            ? Text(
                '· ${record.totalCalories} 千卡',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: zzz?.warning ?? Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              )
            : IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                tooltip: '手动添加',
                onPressed: () => _onManualAdd(type),
              ),
      ),
    );
  }

  Widget _buildMealSubtitle(ThemeData theme, MealRecord? record) {
    if (record == null) {
      return Text(
        '暂无记录',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    final itemsStr = record.itemsSummary;
    final timeStr = record.formattedTime;

    return Text(
      '$itemsStr · $timeStr',
      style: theme.textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// StatItem 已提取为共享组件 widgets/stat_item.dart
