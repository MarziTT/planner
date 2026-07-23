import 'package:flutter/material.dart';

import '../domain/planner_models.dart';

const _zzzBgColor = Color(0xFF0A0A0F);
const _zzzGreen = Color(0xFF00FF41);
const _zzzSurface = Color(0xFF0D0B12);

class PlannerCalendarPanel extends StatelessWidget {
  const PlannerCalendarPanel({
    super.key,
    required this.visibleMonth,
    required this.selectedDay,
    required this.today,
    required this.events,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDay,
    this.isZzz = false,
  });

  final bool isZzz;

  final DateTime visibleMonth;
  final DateTime selectedDay;
  final DateTime today;
  final List<PlannerEvent> events;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthStart = DateTime(visibleMonth.year, visibleMonth.month);
    final gridStart =
        monthStart.subtract(Duration(days: monthStart.weekday - 1));
    final cells = List<DateTime>.generate(
      42,
      (index) =>
          DateTime(gridStart.year, gridStart.month, gridStart.day + index),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isZzz ? _zzzSurface : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isZzz
              ? _zzzGreen.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: isZzz
            ? [
                BoxShadow(
                  color: _zzzGreen.withValues(alpha: 0.06),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${visibleMonth.year}年${visibleMonth.month}月',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isZzz ? _zzzGreen : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '点日期直接看当天，节假日和有安排的日子会标出来。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isZzz
                            ? const Color(0xFFA0A0B8).withValues(alpha: 0.7)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _WeekdayLabel('一', isZzz: isZzz),
              _WeekdayLabel('二', isZzz: isZzz),
              _WeekdayLabel('三', isZzz: isZzz),
              _WeekdayLabel('四', isZzz: isZzz),
              _WeekdayLabel('五', isZzz: isZzz),
              _WeekdayLabel('六', weekend: true, isZzz: isZzz),
              _WeekdayLabel('日', weekend: true, isZzz: isZzz),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final day = cells[index];
              final inMonth = day.month == visibleMonth.month;
              final isSelected = _isSameDay(day, selectedDay);
              final isToday = _isSameDay(day, today);
              final hasEvents = events.any(
                (event) =>
                    !event.startsAt.isBefore(today) &&
                    _isSameDay(event.startsAt, day),
              );
              final holiday = _holidayLabel(day);

              return _CalendarDayCell(
                day: day,
                inMonth: inMonth,
                isSelected: isSelected,
                isToday: isToday,
                hasEvents: hasEvents,
                holidayLabel: holiday,
                isZzz: isZzz,
                onTap: () => onSelectDay(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label, {this.weekend = false, this.isZzz = false});

  final String label;
  final bool weekend;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: weekend
                ? theme.colorScheme.error.withValues(alpha: 0.88)
                : (isZzz ? const Color(0xFFA0A0B8) : theme.colorScheme.onSurfaceVariant),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.inMonth,
    required this.isSelected,
    required this.isToday,
    required this.hasEvents,
    required this.holidayLabel,
    required this.onTap,
    this.isZzz = false,
  });

  final DateTime day;
  final bool inMonth;
  final bool isSelected;
  final bool isToday;
  final bool hasEvents;
  final String? holidayLabel;
  final VoidCallback onTap;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final red = isZzz ? const Color(0xFFFF1744) : theme.colorScheme.error;
    final primaryColor = isZzz ? _zzzGreen : theme.colorScheme.primary;
    final foreground = isSelected
        ? (isZzz ? _zzzBgColor : theme.colorScheme.onPrimary)
        : weekend
            ? red.withValues(alpha: inMonth ? 0.92 : 0.52)
            : inMonth
                ? (isZzz ? const Color(0xFFE0E0E0) : theme.colorScheme.onSurface)
                : (isZzz ? const Color(0xFFA0A0B8).withValues(alpha: 0.55) : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55));
    final markerLabel = holidayLabel ?? (isToday ? '\u4eca' : null);
    final markerColor = isSelected
        ? (isZzz ? _zzzBgColor.withValues(alpha: 0.88) : theme.colorScheme.onPrimary.withValues(alpha: 0.88))
        : holidayLabel != null
            ? primaryColor
            : (isZzz ? const Color(0xFFA0A0B8) : theme.colorScheme.onSurfaceVariant);
    final selectedBg = isZzz ? _zzzGreen : theme.colorScheme.primary;
    final todayBg = isZzz ? _zzzGreen.withValues(alpha: 0.18) : theme.colorScheme.primaryContainer.withValues(alpha: 0.72);

    return Material(
      color: isSelected
          ? selectedBg
          : isToday
              ? todayBg
              : (isZzz ? Colors.transparent : theme.colorScheme.surface),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Text(
                '${day.day}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
            if (markerLabel != null)
              Positioned(
                left: 3,
                right: 3,
                top: 4,
                child: Center(
                  child: Text(
                    markerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: markerColor,
                      fontSize: 8.5,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            if (hasEvents)
              Positioned(
                left: 0,
                right: 0,
                bottom: 5,
                child: Center(
                  child: Container(
                    key: Key(
                        'calendar_event_dot_${day.year}_${day.month}_${day.day}'),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isZzz ? _zzzBgColor : theme.colorScheme.onPrimary)
                          : primaryColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String? _holidayLabel(DateTime day) {
  const fixedHolidays = {
    '01-01': '元旦',
    '02-14': '情人节',
    '03-08': '妇女节',
    '05-01': '劳动节',
    '06-01': '儿童节',
    '09-10': '教师节',
    '10-01': '国庆',
    '12-31': '跨年',
  };
  const lunarHolidayMarks = {
    '2026-02-17': '春节',
    '2026-03-03': '元宵',
    '2026-04-05': '清明',
    '2026-06-19': '端午',
    '2026-08-19': '七夕',
    '2026-09-25': '中秋',
    '2026-10-18': '重阳',
    '2027-02-06': '春节',
    '2027-02-20': '元宵',
    '2027-04-05': '清明',
    '2027-06-09': '端午',
    '2027-08-08': '七夕',
    '2027-09-15': '中秋',
    '2027-10-08': '重阳',
  };

  final dateKey =
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  final fixedKey =
      '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  return lunarHolidayMarks[dateKey] ?? fixedHolidays[fixedKey];
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
