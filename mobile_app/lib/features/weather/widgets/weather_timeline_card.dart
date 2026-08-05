import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/zzz_theme_extension.dart';
import '../models/smart_advisory.dart';
import '../models/timeline_item.dart';
import '../weather_provider.dart';

/// Weather timeline overview card with a compact time-slot preview.
class WeatherTimelineCard extends ConsumerWidget {
  const WeatherTimelineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(smartAdvisoryProvider);
    final controller = ref.read(smartAdvisoryProvider.notifier);
    final themeState = ref.watch(themeControllerProvider);
    final isZzz = themeState.preset == PlannerThemePreset.kamenRiderZzz;
    final theme = Theme.of(context);
    final zzz = context.zzz;
    final brightness = theme.brightness;

    if (state.data == null && !state.loading && state.error == null) {
      Future.microtask(() => controller.loadAdvisory());
    }

    final cardBg = isZzz
        ? zzz?.surface.withValues(alpha: 0.92)
        : (brightness == Brightness.dark
            ? theme.colorScheme.surface.withValues(alpha: 0.6)
            : theme.colorScheme.surface);
    final borderColor = isZzz
        ? zzz?.borderColor ?? theme.colorScheme.outlineVariant
        : theme.dividerColor.withValues(alpha: 0.3);
    final textPrimary = isZzz
        ? zzz?.textPrimary ?? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface;
    final textSecondary = isZzz
        ? zzz?.textSecondary ?? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final highlightBg = isZzz
        ? (zzz?.signal ?? theme.colorScheme.primary).withValues(alpha: 0.08)
        : theme.colorScheme.primary.withValues(alpha: 0.06);
    final warningColor =
        isZzz ? zzz?.warning ?? theme.colorScheme.error : Colors.red.shade400;
    final accentColor =
        isZzz ? zzz?.signal ?? theme.colorScheme.primary : textPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(isZzz ? 10 : 16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            state,
            controller,
            textPrimary,
            textSecondary,
            accentColor,
          ),
          if (state.loading && state.data == null)
            _buildSkeleton(textPrimary)
          else if (state.error != null && state.data == null)
            _buildError(state.error!, controller, textPrimary, warningColor)
          else if (state.data != null)
            _buildTimeline(
              state.data!,
              textPrimary,
              textSecondary,
              highlightBg,
              warningColor,
              theme,
              isZzz,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildHeader(
    SmartAdvisoryState state,
    SmartAdvisoryController controller,
    Color textPrimary,
    Color textSecondary,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
      child: Row(
        children: [
          Icon(Icons.wb_sunny_outlined, size: 20, color: accentColor),
          const SizedBox(width: 8),
          Text(
            '天气',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (state.lastFetchedAt != null)
            Text(
              _formatLastUpdated(state.lastFetchedAt!),
              style: TextStyle(color: textSecondary, fontSize: 11),
            ),
          const SizedBox(width: 4),
          if (state.loading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(textSecondary),
              ),
            )
          else
            IconButton(
              onPressed: () => controller.manualRefresh(),
              icon: Icon(Icons.refresh, color: textSecondary, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    SmartAdvisory advisory,
    Color textPrimary,
    Color textSecondary,
    Color highlightBg,
    Color warningColor,
    ThemeData theme,
    bool isZzz,
  ) {
    final items = advisory.previewItems;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: highlightBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              advisory.summary,
              style: TextStyle(
                color: textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((item) => _buildTimelineItem(
                item,
                textPrimary,
                textSecondary,
                highlightBg,
                warningColor,
                isZzz,
              )),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    TimelineItem item,
    Color textPrimary,
    Color textSecondary,
    Color highlightBg,
    Color warningColor,
    bool isZzz,
  ) {
    final isExtreme = item.isExtremeWeather;
    final isHighPriority = item.isHighPriority;

    Color? bgColor;
    if (isExtreme) {
      bgColor = warningColor.withValues(alpha: 0.10);
    } else if (isHighPriority) {
      bgColor = highlightBg;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isExtreme
            ? Border.all(color: warningColor.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isExtreme
                  ? warningColor.withValues(alpha: 0.2)
                  : textSecondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.timeSlot,
              style: TextStyle(
                color: isExtreme ? warningColor : textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.event != null && item.event!.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.event!,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: isHighPriority
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHighPriority) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.priority_high,
                          size: 14,
                          color: isZzz ? warningColor : Colors.orange,
                        ),
                      ],
                      if (isExtreme) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: warningColor),
                      ],
                    ],
                  ),
                if (item.advisory != null && item.advisory!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: item.event != null ? 2 : 0),
                    child: Text(
                      item.advisory!,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _weatherBrief(item),
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(Color textPrimary) {
    final base = textPrimary.withValues(alpha: 0.12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 36,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < 3; i++) ...[
            Container(
              width: double.infinity,
              height: 48,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(
    String message,
    SmartAdvisoryController controller,
    Color textPrimary,
    Color warningColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: warningColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textPrimary, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => controller.manualRefresh(),
            child: Text('重试', style: TextStyle(color: textPrimary)),
          ),
        ],
      ),
    );
  }

  String _weatherBrief(TimelineItem item) {
    final w = item.weather;
    final buf = StringBuffer();
    buf.write('${w.temp.round()}°');
    if (w.feelsLike != null) {
      buf.write(' 体感${w.feelsLike!.round()}°');
    }
    buf.write(' · ${w.condition}');
    if (w.precipitation > 0) {
      buf.write(' · 降水${w.precipitation.toStringAsFixed(0)}%');
    }
    return buf.toString();
  }

  String _formatLastUpdated(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚更新';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    return '${diff.inHours}小时前';
  }
}
