import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard.dart';
import '../state/dashboard_controller.dart';

/// Habits Dashboard — Phase 2 six-domain overview page.
///
/// Layout:
///   Top — date + mode tag
///   2×3 domain card grid (schedule / weather / routine / meals / exercise / transit)
///   Bottom — pattern announcement
class HabitsDashboard extends ConsumerStatefulWidget {
  const HabitsDashboard({super.key});

  @override
  ConsumerState<HabitsDashboard> createState() => _HabitsDashboardState();
}

class _HabitsDashboardState extends ConsumerState<HabitsDashboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dashboardControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(dashboardControllerProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(dashboardControllerProvider.notifier).load(),
        child: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildError(e.toString()),
          data: (data) => data == null
              ? _buildError('无法加载仪表盘数据')
              : _buildContent(context, data),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Content
  // -----------------------------------------------------------------------

  Widget _buildContent(BuildContext context, DashboardData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildHeader(context, data),
        const SizedBox(height: 20),
        _buildCardGrid(context, data),
        const SizedBox(height: 24),
        if (data.patternAnnouncement != null)
          _buildAnnouncement(data.patternAnnouncement!),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Header: date + status
  // -----------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, DashboardData data) {
    final now = DateTime.now();
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final weekday = weekdays[now.weekday - 1];
    final dateStr = '${now.month}月${now.day}日';

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$dateStr 星期$weekday',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _modeLabel(data),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh, size: 22),
          onPressed: () =>
              ref.read(dashboardControllerProvider.notifier).load(),
        ),
      ],
    );
  }

  String _modeLabel(DashboardData data) {
    final wake = data.routine.wakeTime;
    final hour = int.tryParse(wake.split(':').first) ?? 7;

    // Determine mode based on time
    final now = DateTime.now();
    if (now.weekday >= 6) return '休息日';
    if (hour <= 6) return '早起密集日';
    if (hour <= 8) return '工作日';
    if (hour <= 10) return '弹性工作日';
    return '自由日';
  }

  // -----------------------------------------------------------------------
  // 2×3 card grid
  // -----------------------------------------------------------------------

  Widget _buildCardGrid(BuildContext context, DashboardData data) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ScheduleCard(data.schedule),
        _WeatherCard(data.weather),
        _RoutineCard(data.routine),
        _MealsCard(data.meals),
        _ExerciseCard(data.exercise),
        _TransitCard(data.transit),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Card builders — each is a standalone widget
  // -----------------------------------------------------------------------

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(msg, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                ref.read(dashboardControllerProvider.notifier).load(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Announcement
  // -----------------------------------------------------------------------

  Widget _buildAnnouncement(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Domain cards
// ===========================================================================

// ---------------------------------------------------------------------------
// Schedule card
// ---------------------------------------------------------------------------

class _ScheduleCard extends StatelessWidget {
  final ScheduleSnapshot data;
  const _ScheduleCard(this.data);

  @override
  Widget build(BuildContext context) {
    return _DomainCard(
      icon: Icons.calendar_today_outlined,
      label: '日程',
      color: Colors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              children: [
                TextSpan(text: '${data.pendingCount}'),
                TextSpan(
                  text: ' 个待办',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (data.upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(
                    '暂无日程',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            ...data.upcoming.take(2).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                        ),
                        Text(
                          e.time,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weather card
// ---------------------------------------------------------------------------

class _WeatherCard extends StatelessWidget {
  final WeatherSnapshot data;
  const _WeatherCard(this.data);

  @override
  Widget build(BuildContext context) {
    if (!data.available) {
      return _DomainCard(
        icon: Icons.cloud_outlined,
        label: '天气',
        color: Colors.cyan,
        child: Center(
          child: Text(
            '获取中...',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return _DomainCard(
      icon: Icons.cloud_outlined,
      label: '天气',
      color: Colors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${data.temp}°',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  data.condition,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '今日 ${data.displayRange}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Routine card
// ---------------------------------------------------------------------------

class _RoutineCard extends StatelessWidget {
  final RoutineSnapshot data;
  const _RoutineCard(this.data);

  @override
  Widget build(BuildContext context) {
    return _DomainCard(
      icon: Icons.bedtime_outlined,
      label: '作息',
      color: Colors.indigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, size: 14,
                  color: Colors.orange.shade300),
              const SizedBox(width: 4),
              Text(
                '起床 ${data.wakeTime}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.nightlight_outlined, size: 14,
                  color: Colors.indigo.shade200),
              const SizedBox(width: 4),
              Text(
                '建议入睡 ${data.sleepTime}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.accessibility_new,
                  size: 14,
                  color: data.autoStopped
                      ? Colors.grey
                      : data.standingEnabled
                          ? Colors.green
                          : Colors.grey),
              const SizedBox(width: 4),
              Text(
                data.autoStopped
                    ? '站立已暂停'
                    : data.standingEnabled
                        ? '站立 ${data.standingCompleted}/${data.standingTotal}'
                        : '站立休息',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meals card
// ---------------------------------------------------------------------------

class _MealsCard extends StatelessWidget {
  final MealsSnapshot data;
  const _MealsCard(this.data);

  @override
  Widget build(BuildContext context) {
    return _DomainCard(
      icon: Icons.restaurant_outlined,
      label: '饮食',
      color: Colors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              children: [
                TextSpan(text: '${data.totalCalories}'),
                TextSpan(
                  text: ' kcal',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '已记 ${data.mealCount} 餐',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
          ),
          if (data.weeklyAvg > 0) ...[
            const SizedBox(height: 2),
            Text(
              '周均 ${data.weeklyAvg.round()} kcal',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise card
// ---------------------------------------------------------------------------

class _ExerciseCard extends StatelessWidget {
  final ExerciseSnapshot data;
  const _ExerciseCard(this.data);

  @override
  Widget build(BuildContext context) {
    return _DomainCard(
      icon: Icons.fitness_center_outlined,
      label: '运动',
      color: Colors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _MiniStat(
                  icon: Icons.directions_walk, value: '${data.totalSteps}', unit: '步'),
              const SizedBox(width: 10),
              _MiniStat(
                  icon: Icons.timer_outlined,
                  value: '${data.totalMinutes}',
                  unit: 'min'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  size: 14, color: Colors.deepOrange),
              const SizedBox(width: 4),
              Text(
                '${data.totalCalories} kcal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
        ),
        Text(
          ' $unit',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Transit card
// ---------------------------------------------------------------------------

class _TransitCard extends StatelessWidget {
  final TransitSnapshot data;
  const _TransitCard(this.data);

  @override
  Widget build(BuildContext context) {
    final hasTrip = data.trips.isNotEmpty;
    final trip = hasTrip ? data.trips.first : null;

    return _DomainCard(
      icon: Icons.directions_subway_outlined,
      label: '出行',
      color: Colors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasTrip)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flight_takeoff, size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(
                    '暂无出行',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: trip!.minutesToDeparture < 60
                        ? Colors.red
                        : Colors.purple.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trip.countdownDisplay,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: trip.minutesToDeparture < 60
                              ? Colors.red.shade300
                              : null,
                        ),
                  ),
                ),
              ],
            ),
            if (data.tripCount > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 14),
                child: Text(
                  '共 ${data.tripCount} 个行程',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.6)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared card shell
// ===========================================================================

class _DomainCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget child;

  const _DomainCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const Spacer(),
            child,
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}
