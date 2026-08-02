import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/zzz_theme_extension.dart';
import '../domain/weather_models.dart';
import '../state/weather_controller.dart';

/// Weather condition code to icon mapping, aligned with backend condition.code.
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

List<Color> _gradientForCode(int code, Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  if (code >= 200 && code < 300) {
    return isDark
        ? [const Color(0xFF2A1B4D), const Color(0xFF1A2A4D)]
        : [const Color(0xFFE8DFF5), const Color(0xFFD0E0F5)];
  }
  if (code >= 300 && code < 600) {
    return isDark
        ? [const Color(0xFF1E3A5F), const Color(0xFF0F3A3A)]
        : [const Color(0xFFD5E8F5), const Color(0xFFC8EBE8)];
  }
  if (code >= 600 && code < 700) {
    return isDark
        ? [const Color(0xFF5A7A8A), const Color(0xFFB8C4CC)]
        : [const Color(0xFFD8E8F0), const Color(0xFFE8F0F5)];
  }
  if (code >= 700 && code < 800) {
    return isDark
        ? [const Color(0xFF8A8A8A), const Color(0xFF4A4A4A)]
        : [const Color(0xFFE0E0E0), const Color(0xFFC8C8C8)];
  }
  if (code == 800) {
    return isDark
        ? [const Color(0xFFE8893B), const Color(0xFFF4C95D)]
        : [const Color(0xFFFDEBD0), const Color(0xFFF9E4B7)];
  }
  return isDark
      ? [const Color(0xFF4A5A6A), const Color(0xFF1E2A3A)]
      : [const Color(0xFFD8E0E8), const Color(0xFFC0D0E0)];
}

class _GradientTextColors {
  const _GradientTextColors({
    required this.primary,
    required this.secondary,
    required this.icon,
  });

  final Color primary;
  final Color secondary;
  final Color icon;
}

_GradientTextColors _textColorsForGradient(Brightness brightness) {
  return brightness == Brightness.dark
      ? const _GradientTextColors(
          primary: Colors.white,
          secondary: Colors.white70,
          icon: Colors.white,
        )
      : const _GradientTextColors(
          primary: Color(0xFF2D2D2D),
          secondary: Color(0xFF5A5A5A),
          icon: Color(0xFF404040),
        );
}

class WeatherCard extends ConsumerWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherControllerProvider);
    final controller = ref.read(weatherControllerProvider.notifier);
    final themeState = ref.watch(themeControllerProvider);
    final isZzz = themeState.preset == PlannerThemePreset.kamenRiderZzz;
    final theme = Theme.of(context);
    final zzz = context.zzz;
    final brightness = theme.brightness;

    final gradient = isZzz
        ? [
            zzz?.surfaceHigh ?? const Color(0xFF1A2130),
            zzz?.surfaceLow ?? const Color(0xFF0D111B),
          ]
        : state.data != null
            ? _gradientForCode(state.data!.current.condition.code, brightness)
            : _gradientForCode(999, brightness);

    final textColors = isZzz
        ? _GradientTextColors(
            primary: zzz?.textPrimary ?? theme.colorScheme.onSurface,
            secondary: zzz?.textSecondary ?? theme.colorScheme.onSurfaceVariant,
            icon: zzz?.signal ?? theme.colorScheme.primary,
          )
        : _textColorsForGradient(brightness);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isZzz ? 10 : 18),
        border: isZzz
            ? Border.all(
                color: zzz?.borderColor ?? theme.colorScheme.outlineVariant)
            : null,
        boxShadow: isZzz
            ? [
                BoxShadow(
                  color: (zzz?.accent ?? theme.colorScheme.primary)
                      .withValues(alpha: 0.08),
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
      child: _buildBody(state, controller, textColors),
    );
  }

  Widget _buildBody(
    WeatherState state,
    WeatherController controller,
    _GradientTextColors textColors,
  ) {
    if (state.loading && state.data == null) {
      return _WeatherSkeleton(textColors: textColors);
    }

    if (state.error != null && state.data == null) {
      return _WeatherError(
        message: state.error!,
        onRetry: () => controller.manualRefresh(),
        textColors: textColors,
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
      textColors: textColors,
    );
  }
}

class _WeatherContent extends StatelessWidget {
  const _WeatherContent({
    required this.data,
    required this.lastFetchedAt,
    required this.onRefresh,
    required this.isRefreshing,
    required this.textColors,
  });

  final WeatherData data;
  final DateTime? lastFetchedAt;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final _GradientTextColors textColors;

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
        Row(
          children: [
            Text(
              '当前位置',
              style: TextStyle(
                color: textColors.primary,
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
                  style: TextStyle(
                    color: textColors.secondary,
                    fontSize: 11,
                  ),
                ),
              ),
            isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(textColors.icon),
                    ),
                  )
                : IconButton(
                    onPressed: onRefresh,
                    icon: Icon(Icons.refresh, color: textColors.icon),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${current.temp.round()}°',
              style: TextStyle(
                color: textColors.primary,
                fontSize: 56,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              _iconForCode(current.condition.code),
              size: 32,
              color: textColors.icon,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                current.condition.text,
                style: TextStyle(
                  color: textColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '体感 ${current.feelsLike.round()}° · 湿度 ${current.humidity}% · 风速 ${current.windSpeed.toStringAsFixed(1)}m/s',
          style: TextStyle(
            color: textColors.secondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (todayHigh != null && todayLow != null)
              Text(
                'H:${todayHigh.round()}° L:${todayLow.round()}°',
                style: TextStyle(
                  color: textColors.primary,
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
                            color: textColors.icon,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${h.temp.round()}°',
                            style: TextStyle(
                              color: textColors.primary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${h.time.hour}:00',
                            style: TextStyle(
                              color: textColors.secondary,
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
  const _WeatherSkeleton({required this.textColors});

  final _GradientTextColors textColors;

  @override
  Widget build(BuildContext context) {
    final base = textColors.primary.withValues(alpha: 0.18);
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
  const _WeatherError({
    required this.message,
    this.onRetry,
    required this.textColors,
  });

  final String message;
  final VoidCallback? onRetry;
  final _GradientTextColors textColors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.cloud_off,
          size: 20,
          color: textColors.icon,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: textColors.primary,
              fontSize: 13,
            ),
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: Text(
              '重试',
              style: TextStyle(color: textColors.primary),
            ),
          ),
      ],
    );
  }
}
