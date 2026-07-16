import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/weather_repository.dart';
import '../state/weather_controller.dart';

/// 天气状况 code → 图标映射（与后端 condition.code 对齐）
IconData _iconForCode(int code) {
  // 简化映射，可按后端实际 code 表扩展
  if (code >= 200 && code < 300) return Icons.thunderstorm;
  if (code >= 300 && code < 400) return Icons.grain;
  if (code >= 500 && code < 600) return Icons.water_drop;
  if (code >= 600 && code < 700) return Icons.ac_unit;
  if (code >= 700 && code < 800) return Icons.foggy;
  if (code == 800) return Icons.wb_sunny;
  if (code > 800) return Icons.cloud;
  return Icons.wb_cloudy;
}

class WeatherCard extends ConsumerWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherControllerProvider);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(context, state, colorScheme),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WeatherState state,
    ColorScheme colorScheme,
  ) {
    if (state.loading) {
      return const _WeatherSkeleton();
    }

    if (state.error != null) {
      return _WeatherError(
        message: state.error!,
        onRetry: () {
          // 通过 Provider 触发重试
          // 注意：此处需在父级持有 controller 引用，或改用 ref.read
        },
      );
    }

    if (state.data == null) {
      return const SizedBox.shrink();
    }

    return _WeatherContent(data: state.data!);
  }
}

class _WeatherContent extends StatelessWidget {
  final WeatherData data;

  const _WeatherContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final current = data.current;
    final daily = data.daily;
    final hourly = data.hourly;

    // 今日最高/最低温
    final todayHigh = daily.isNotEmpty ? daily.first.tempMax : null;
    final todayLow = daily.isNotEmpty ? daily.first.tempMin : null;

    // 未来 3 小时预报
    final next3 = hourly.take(3).toList();
    final hourlyText = next3
        .asMap()
        .entries
        .map((e) {
          final idx = e.key + 1;
          final h = e.value;
          return '${idx}h ${h.condition.text} ${h.temp.round()}°';
        })
        .join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：图标 + 当前温度 + 状况
        Row(
          children: [
            Icon(
              _iconForCode(current.condition.code),
              size: 32,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '${current.temp.round()}°',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                current.condition.text,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 第二行：最高/最低温
        if (todayHigh != null && todayLow != null)
          Text(
            '${todayHigh.round()}° / ${todayLow.round()}°',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 4),
        // 第三行：未来 3 小时
        if (hourlyText.isNotEmpty)
          Text(
            hourlyText,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _WeatherSkeleton extends StatelessWidget {
  const _WeatherSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 60,
              height: 24,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: 120,
          height: 16,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 14,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
}

class _WeatherError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _WeatherError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(
          Icons.cloud_off,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
      ],
    );
  }
}
