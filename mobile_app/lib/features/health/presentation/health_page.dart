import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/health_models.dart';
import '../state/health_notifier.dart';

/// Premium health data center dashboard — P3-F2.
///
/// Displays exercise, nutrition, sleep, and standing trends over a 7-day window
/// with line charts, bar charts, and summary stat cards.
class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(healthNotifierProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(healthNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('健康中心'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(healthNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      body: _buildBody(state, theme),
    );
  }

  Widget _buildBody(HealthState state, ThemeData theme) {
    if (state.loadState == HealthLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.loadState == HealthLoadState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(state.errorMessage ?? '加载失败', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.read(healthNotifierProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final trends = state.trends;
    if (trends == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () => ref.read(healthNotifierProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildPeriodHeader(trends.period, theme),
          const SizedBox(height: 20),
          _buildSummaryCards(trends, theme),
          const SizedBox(height: 24),
          _buildSectionTitle('运动趋势', Icons.directions_run, theme),
          const SizedBox(height: 12),
          _buildExerciseChart(trends.exercise, theme),
          const SizedBox(height: 24),
          _buildSectionTitle('饮食摄入', Icons.restaurant, theme),
          const SizedBox(height: 12),
          _buildMealsChart(trends.meals, theme),
          const SizedBox(height: 24),
          _buildSectionTitle('站立习惯', Icons.accessibility_new, theme),
          const SizedBox(height: 12),
          _buildStandingChart(trends.standing, theme),
          const SizedBox(height: 24),
          _buildSectionTitle('睡眠作息', Icons.bedtime, theme),
          const SizedBox(height: 12),
          _buildSleepCard(trends.routine, theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Period header
  // -----------------------------------------------------------------------

  Widget _buildPeriodHeader(PeriodInfo period, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withAlpha(30),
            theme.colorScheme.tertiary.withAlpha(20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(40),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${period.days} 天健康报告',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${period.start} 至 ${period.end}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildPeriodBadge('${period.days}D', theme),
        ],
      ),
    );
  }

  Widget _buildPeriodBadge(String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Summary stat cards
  // -----------------------------------------------------------------------

  Widget _buildSummaryCards(HealthTrends trends, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.directions_run,
            label: '运动',
            value: '${trends.exercise.summary.totalMinutes}',
            unit: '分钟',
            color: Colors.green,
            theme: theme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department,
            label: '消耗',
            value: '${trends.exercise.summary.totalCalories}',
            unit: 'kcal',
            color: Colors.orange,
            theme: theme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.restaurant,
            label: '摄入',
            value: '${trends.meals.summary.totalCalories}',
            unit: 'kcal',
            color: Colors.blue,
            theme: theme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle,
            label: '站立',
            value: '${(trends.standing.summary.avgCompletionRate * 100).toInt()}',
            unit: '%',
            color: Colors.purple,
            theme: theme,
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Exercise line chart
  // -----------------------------------------------------------------------

  Widget _buildExerciseChart(ExerciseDomain exercise, ThemeData theme) {
    final spots = exercise.daily.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.totalMinutes.toDouble());
    }).toList();

    final maxY = spots.isEmpty
        ? 60.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: _chartCardDecoration(theme),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY < 10 ? 10 : maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 60 ? 30 : 15,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.colorScheme.outline.withAlpha(30),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= exercise.daily.length) return const SizedBox.shrink();
                  final d = exercise.daily[i].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      d.substring(5), // MM-DD
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: Colors.green,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) =>
                    FlDotCirclePainter(radius: 3, color: Colors.green, strokeWidth: 0),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.green.withAlpha(80), Colors.green.withAlpha(10)],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                  return LineTooltipItem(
                    '${s.y.toInt()} 分钟',
                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Meals bar chart
  // -----------------------------------------------------------------------

  Widget _buildMealsChart(MealsDomain meals, ThemeData theme) {
    final maxCals = meals.daily.isEmpty
        ? 2000.0
        : meals.daily.map((d) => d.totalCalories).reduce((a, b) => a > b ? a : b).toDouble() * 1.2;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: _chartCardDecoration(theme),
      child: BarChart(
        BarChartData(
          maxY: maxCals < 500 ? 500 : maxCals,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final d = meals.daily[groupIndex];
                return BarTooltipItem(
                  '${d.totalCalories} kcal\n'
                  '早${d.breakfast} 午${d.lunch} 晚${d.dinner}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= meals.daily.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      meals.daily[i].date.substring(5),
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.colorScheme.outline.withAlpha(30),
              strokeWidth: 1,
            ),
          ),
          barGroups: meals.daily.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.totalCalories.toDouble(),
                  color: Colors.blue,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Standing chart
  // -----------------------------------------------------------------------

  Widget _buildStandingChart(StandingDomain standing, ThemeData theme) {
    final rate = standing.summary.avgCompletionRate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _chartCardDecoration(theme),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '站立完成率',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(180),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(rate * 100).toInt()}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: rate >= 0.7 ? Colors.green : Colors.orange,
                      ),
                    ),
                    Text(
                      '连续 ${standing.summary.streak} 天',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: rate,
                        strokeWidth: 6,
                        backgroundColor: theme.colorScheme.outline.withAlpha(40),
                        valueColor: AlwaysStoppedAnimation(
                          rate >= 0.7 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                    Icon(
                      rate >= 0.7 ? Icons.emoji_events : Icons.trending_up,
                      color: rate >= 0.7 ? Colors.amber : Colors.orange,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MiniStat(label: '总提醒', value: '${standing.summary.total}'),
              _MiniStat(label: '已完成', value: '${standing.summary.completed}'),
              _MiniStat(label: '已跳过', value: '${standing.summary.skipped}'),
              _MiniStat(label: '活跃天', value: '${standing.summary.activeDays}'),
            ],
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Sleep / routine card
  // -----------------------------------------------------------------------

  Widget _buildSleepCard(RoutineDomain routine, ThemeData theme) {
    final avgWake = routine.summary.avgWakeTime;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _chartCardDecoration(theme),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.indigo.withAlpha(30),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bedtime, color: Colors.indigo, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '平均作息',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '起床 $avgWake   睡眠 ${routine.summary.avgSleepHours.toStringAsFixed(1)}h',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  '默认起床 ${routine.summary.defaultWakeTime}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(140),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withAlpha(100)),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Shared widgets
  // -----------------------------------------------------------------------

  Widget _buildSectionTitle(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  BoxDecoration _chartCardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: theme.colorScheme.outline.withAlpha(30)),
      boxShadow: [
        BoxShadow(
          color: theme.colorScheme.shadow.withAlpha(15),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Small reusable widgets
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final ThemeData theme;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(160),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            unit,
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: color.withAlpha(180)),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(150),
          ),
        ),
      ],
    );
  }
}
