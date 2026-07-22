import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../data/weather_repository.dart';
import '../state/weather_controller.dart';

/// 天气状况 code → 图标映射（与后端 condition.code 对齐）
IconData _iconForCode(int code) {
  if (code >= 200 && code < 300) return Icons.thunderstorm;
  if (code >= 300 && code < 400) return Icons.grain;
  if (code >= 500 && code < 600) return Icons.water_drop;
  if (code >= 600 && code < 700) return Icons.ac_unit;
  if (code >= 700 && code < 800) return Icons.foggy;
  if (code == 800) return Icons.wb_sunny;
  if (code > 800) return Icons.cloud;
  return Icons.wb_cloudy;
}

/// 根据 condition.code 选择氛围渐变（深 → 浅）
List<Color> _gradientForCode(int code) {
  if (code >= 200 && code < 300) {
    // 雷暴：深紫到暗蓝
    return [const Color(0xFF2A1B4D), const Color(0xFF1A2A4D)];
  }
  if (code >= 300 && code < 600) {
    // 雨：冷蓝到暗青
    return [const Color(0xFF1E3A5F), const Color(0xFF0F3A3A)];
  }
  if (code >= 600 && code < 700) {
    // 雪：冰青到白灰
    return [const Color(0xFF5A7A8A), const Color(0xFFB8C4CC)];
  }
  if (code >= 700 && code < 800) {
    // 雾：灰白到暗灰
    return [const Color(0xFF8A8A8A), const Color(0xFF4A4A4A)];
  }
  if (code == 800) {
    // 晴：暖橙到浅金
    return [const Color(0xFFE8893B), const Color(0xFFF4C95D)];
  }
  // > 800 多云：灰青到暗蓝
  return [const Color(0xFF4A5A6A), const Color(0xFF1E2A3A)];
}

class WeatherCard extends ConsumerWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherControllerProvider);
    final controller = ref.read(weatherControllerProvider.notifier);
    final themeState = ref.watch(themeControllerProvider);
    final isZzz = themeState.preset == PlannerThemePreset.kamenRiderZzz;

    final gradient = state.data != null
        ? _gradientForCode(state.data!.current.condition.code)
        : [const Color(0xFF3A4A5A), const Color(0xFF1E2A3A)];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: isZzz
            ? Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.18))
            : null,
        boxShadow: isZzz
            ? [
                BoxShadow(
                  color: const Color(0xFF00FF41).withValues(alpha: 0.04),
                  blurRadius: 10,
                ),
              ]
            : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: _buildBody(context, state, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WeatherState state,
    WeatherController controller,
  ) {
    if (state.loading && state.data == null) {
      return const _WeatherSkeleton();
    }

    if (state.error != null && state.data == null) {
      return _WeatherError(
        message: state.error!,
        onRetry: () => controller.manualRefresh(),
      );
    }

    if (state.data == null) {
      return const SizedBox.shrink();
    }

    return _WeatherContent(
      data: state.data!,
      lastFetchedAt: state.lastFetchedAt,
      onRefresh: () => controller.manualRefresh(),
      isRefreshing: state.loading,
    );
  }
}

class _WeatherContent extends StatelessWidget {
  final WeatherData data;
  final DateTime? lastFetchedAt;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  const _WeatherContent({
    required this.data,
    required this.lastFetchedAt,
    required this.onRefresh,
    required this.isRefreshing,
  });

  String _lastUpdatedText() {
    if (lastFetchedAt == null) return '';
    final diff = DateTime.now().difference(lastFetchedAt!);
    if (diff.inMinutes < 1) return '刚刚更新';
    return '${diff.inMinutes} 分钟前更新';
  }

  @override
  Widget build(BuildContext context) {
    final current = data.current;
    final daily = data.daily;
    final hourly = data.hourly;

    final todayHigh = daily.isNotEmpty ? daily.first.tempMax : null;
    final todayLow = daily.isNotEmpty ? daily.first.tempMin : null;

    final next3 = hourly.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部行：位置 + 更新时间 + 刷新按钮
        Row(
          children: [
            const Text(
              '当前位置',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (lastFetchedAt != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _lastUpdatedText(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
          ],
        ),
        const SizedBox(height: 16),
        // 主角区：大温度 + 图标 + 状况
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${current.temp.round()}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              _iconForCode(current.condition.code),
              size: 32,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                current.condition.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 次级信息行：体感 · 湿度 · 风速
        Text(
          '体感 ${current.feelsLike.round()}° · 湿度 ${current.humidity}% · 风速 ${current.windSpeed.toStringAsFixed(1)}m/s',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        // 底部行：今日高低温 + 未来 3 小时趋势
        Row(
          children: [
            if (todayHigh != null && todayLow != null)
              Text(
                'H:${todayHigh.round()}° L:${todayLow.round()}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (todayHigh != null && todayLow != null && next3.isNotEmpty)
              const SizedBox(width: 16),
            if (next3.isNotEmpty)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: next3.asMap().entries.map((e) {
                    final h = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        children: [
                          Icon(
                            _iconForCode(h.condition.code),
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${h.temp.round()}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${h.time.hour}:00',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WeatherSkeleton extends StatelessWidget {
  const _WeatherSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Colors.white.withValues(alpha: 0.18);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 14,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const Spacer(),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              width: 120,
              height: 48,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: 200,
          height: 13,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 80,
              height: 14,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const Spacer(),
            Container(
              width: 120,
              height: 40,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
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
    return Row(
      children: [
        const Icon(
          Icons.cloud_off,
          size: 20,
          color: Colors.white,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: const Text(
              '重试',
              style: TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
