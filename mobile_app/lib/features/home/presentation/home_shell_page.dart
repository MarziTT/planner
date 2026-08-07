import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/presentation/agent_dialog_panel.dart';
import '../../auth/state/auth_controller.dart';
import '../../../core/butler/butler_name_provider.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/zzz_theme_extension.dart';
import '../../fast_capture/domain/capture_enums.dart';
import '../../fast_capture/presentation/quick_capture_bar.dart';
import '../../notifications/data/reminder_gateway.dart';
import '../../notifications/domain/notification_tap_event.dart';
import '../../habits/views/habits_dashboard.dart';
import '../../planner/presentation/planner_dashboard.dart';
import '../../planner/state/planner_controller.dart';
import '../../profile/presentation/profile_page.dart';
import '../../settings/domain/settings_model.dart';
import '../../settings/presentation/settings_page.dart';
import '../../settings/state/settings_controller.dart';
import '../../tags/presentation/tags_page.dart';
import '../../meals/views/meal_page.dart';
import '../../exercise/views/exercise_page.dart';
import '../../transit/views/transit_page.dart';
import '../../updates/presentation/update_banner.dart';
import '../../../widgets/zzz_gif_decoration.dart';
import '../../widgets/widget_service.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key, this.initialTab = 'planner'});

  final String initialTab;

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage>
    with WidgetsBindingObserver {
  StreamSubscription<NotificationTapEvent>? _tapSubscription;
  bool _initialDashboardLoadRequested = false;

  static final List<_HomeModule> _modules = [
    _HomeModule(
      id: 'planner',
      label: '日程',
      icon: Icons.calendar_month_outlined,
      builder: () => const PlannerDashboard(),
    ),
    _HomeModule(
      id: 'dashboard',
      label: '今日总览',
      icon: Icons.dashboard_outlined,
      builder: () => const HabitsDashboard(),
    ),
    _HomeModule(
      id: 'transit',
      label: '出行',
      icon: Icons.directions_subway_outlined,
      builder: () => const TransitPage(),
    ),
    _HomeModule(
      id: 'meals',
      label: '饮食',
      icon: Icons.restaurant_outlined,
      builder: () => const MealPage(),
    ),
    _HomeModule(
      id: 'exercise',
      label: '运动',
      icon: Icons.fitness_center_outlined,
      builder: () => const ExercisePage(),
    ),
    _HomeModule(
      id: 'tags',
      label: '标签',
      icon: Icons.sell_outlined,
      builder: () => const TagsPage(),
    ),
    _HomeModule(
      id: 'profile',
      label: '账号',
      icon: Icons.person_outline,
      builder: () => const ProfilePage(),
    ),
    _HomeModule(
      id: 'settings',
      label: '设置',
      icon: Icons.settings_outlined,
      builder: () => const SettingsPage(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() {
      final settingsState = ref.read(settingsControllerProvider);
      if (settingsState.settings == null && !settingsState.loading) {
        ref.read(settingsControllerProvider.notifier).load();
      }
      _ensureDashboardLoadedForSession();

      final gateway = ref.read(reminderGatewayProvider);
      _tapSubscription = gateway.taps.listen(_onNotificationTap);

      gateway.getLaunchTap().then((tap) {
        if (tap != null) {
          _onNotificationTap(tap);
        }
      });
    });

    if (widget.initialTab != 'dashboard') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showModuleById(widget.initialTab);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncReminderSchedules(
        ref.read(plannerControllerProvider),
        ref.read(settingsControllerProvider).settings,
      );
    }
  }

  void _onNotificationTap(NotificationTapEvent event) {
    if (event.eventId != null) {
      ref.read(selectedPlannerEventIdProvider.notifier).state = event.eventId;
    }
    if (mounted) {
      _showModuleById(event.routeTab ?? 'dashboard');
      if (event.openQuickCapture) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已打开速记，可以直接新增行程')),
        );
      }
    }
  }

  void _ensureDashboardLoadedForSession() {
    if (_initialDashboardLoadRequested) return;
    final authState = ref.read(authControllerProvider);
    if (authState.session == null || authState.restoring) return;
    _initialDashboardLoadRequested = true;
    ref.read(plannerControllerProvider.notifier).loadDashboard();
    // Refresh widget after login
    ref.read(widgetServiceProvider).refreshWidget();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.session;
      final nextSession = next.session;
      if (previousSession == null && nextSession != null) {
        _initialDashboardLoadRequested = true;
        ref.read(plannerControllerProvider.notifier).loadDashboard();
        ref.read(widgetServiceProvider).refreshWidget();
      }
      if (previousSession != null && nextSession == null) {
        _initialDashboardLoadRequested = false;
        ref.read(plannerControllerProvider.notifier).markLoggedOut();
        ref.read(widgetServiceProvider).clearWidget();
      }
    });

    ref.listen(fastCaptureControllerProvider, (previous, next) {
      final pendingDraft = next.pendingDraft;
      if (pendingDraft != null && previous?.pendingDraft != pendingDraft) {
        showCaptureAmbiguitySheet(
          context,
          draft: pendingDraft,
          onMorning: () async {
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmAmbiguousHour(
                  pendingDraft.ambiguousHour ?? pendingDraft.startsAt.hour,
                );
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
          onAfternoon: () async {
            final hour =
                pendingDraft.ambiguousHour ?? pendingDraft.startsAt.hour;
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmAmbiguousHour(hour < 12 ? hour + 12 : hour);
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
          onCancel: () {
            ref
                .read(fastCaptureControllerProvider.notifier)
                .cancelPendingDraft();
          },
          onMissingMorning: () async {
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmMissingTime(TimePeriod.morning);
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
          onMissingAfternoon: () async {
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmMissingTime(TimePeriod.afternoon);
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
          onMissingEvening: () async {
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmMissingTime(TimePeriod.evening);
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
          onMissingAllDay: () async {
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmMissingTime(TimePeriod.allDay);
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
        );
      }

      final errorMessage = next.errorMessage;
      if (errorMessage != null &&
          errorMessage != previous?.errorMessage &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    });

    ref.listen(plannerControllerProvider, (previous, next) {
      _syncReminderSchedules(
          next, ref.read(settingsControllerProvider).settings);
    });

    ref.listen(settingsControllerProvider, (previous, next) {
      _syncReminderSchedules(
          ref.read(plannerControllerProvider), next.settings);
    });

    final theme = Theme.of(context);
    final isZzz = ref.watch(themeControllerProvider).preset ==
        PlannerThemePreset.kamenRiderZzz;
    final zzzTokens = context.zzz;
    final zzzBg = zzzTokens?.bg ?? zzzBgColor;
    final zzzSignal = zzzTokens?.signal ?? zzzGreen;
    final zzzText = zzzTokens?.textPrimary ?? zzzGreenLight;
    final butlerName = ref.watch(butlerNameProvider);

    PreferredSizeWidget appBar = AppBar(
      backgroundColor: isZzz ? zzzBg : null,
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isZzz
                    ? [zzzSignal, zzzSignal.withValues(alpha: 0.6)]
                    : [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.6),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              size: 17,
              color: isZzz ? zzzBg : theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'DD · $butlerName',
            style: isZzz ? TextStyle(color: zzzText) : null,
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _showModulePicker,
          icon: Icon(Icons.apps_outlined, color: isZzz ? zzzSignal : null),
          tooltip: '打开模块',
        ),
        IconButton(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: Icon(Icons.logout, color: isZzz ? zzzSignal : null),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: isZzz ? zzzBg : null,
      appBar: appBar,
      body: Stack(
        children: [
          if (isZzz)
            Positioned(
              right: 0,
              bottom: 0,
              child: ZzzCornerArt(
                spec: zzzSpecFromSeed(DateTime.now().day + 2),
                size: 80,
                opacity: 0.22,
              ),
            ),
          Column(
            children: [
              const UpdateBanner(),
              const _OfflineBanner(),
              Expanded(
                child: AgentDialogPanel(
                  embedded: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _syncReminderSchedules(
      PlannerState plannerState, PlannerSettings? settings) {
    if (settings == null) return;
    ref.read(reminderCoordinatorProvider).sync(
          events: plannerState.events,
          settings: settings,
        );
  }

  Future<void> _showModulePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '打开模块',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final module in _modules)
                      _ModuleTile(
                        module: module,
                        onTap: () {
                          Navigator.of(context).pop();
                          _showModule(module);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showModuleById(String id) async {
    final module = _modules.firstWhere(
      (module) =>
          module.id == id || (id == 'habits' && module.id == 'dashboard'),
      orElse: () => _modules.first,
    );
    await _showModule(module);
  }

  Future<void> _showModule(_HomeModule module) async {
    if (module.id == 'dashboard') {
      ref.read(widgetServiceProvider).refreshWidget();
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Icon(module.icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        module.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              Expanded(child: module.builder()),
            ],
          ),
        );
      },
    );
  }
}

class _HomeModule {
  const _HomeModule({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String label;
  final IconData icon;
  final Widget Function() builder;
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.onTap,
  });

  final _HomeModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(module.icon, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              module.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim bar showing "offline mode" at the top of the screen.
///
/// Watches [isOfflineProvider]; auto-hides when connectivity returns.
class _OfflineBanner extends ConsumerWidget {
  // ignore: unused_element – used in build() via Column
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    if (!isOffline) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.orange.shade700,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.cloud_off,
                size: 16, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '离线模式 · 数据可能不是最新',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
