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
  const HomeShellPage({super.key});

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage>
    with WidgetsBindingObserver {
  int currentIndex = 0;
  StreamSubscription<NotificationTapEvent>? _tapSubscription;
  bool _initialDashboardLoadRequested = false;

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
      setState(() => currentIndex = 0);
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

    const pages = [
      HabitsDashboard(),
      TransitPage(),
      MealPage(),
      ExercisePage(),
      TagsPage(),
      ProfilePage(),
      SettingsPage(),
    ];

    final theme = Theme.of(context);
    final isZzz = ref.watch(themeControllerProvider).preset ==
        PlannerThemePreset.kamenRiderZzz;
    final zzzTokens = context.zzz;
    final zzzSurface = zzzTokens?.surface ?? zzzSurfaceColor;
    final zzzBg = zzzTokens?.bg ?? zzzBgColor;
    final zzzAccent = zzzTokens?.accent ?? zzzRed;
    final zzzSignal = zzzTokens?.signal ?? zzzGreen;
    final zzzText = zzzTokens?.textPrimary ?? zzzGreenLight;
    final zzzMuted = zzzTokens?.textTertiary ?? zzzSilver;
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
              if (currentIndex == 0) QuickCaptureBar(isZzz: isZzz),
              Expanded(child: pages[currentIndex]),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAgentPanel(context),
        tooltip: '$butlerName 管家',
        backgroundColor: isZzz ? zzzAccent : theme.colorScheme.primary,
        foregroundColor: isZzz ? zzzText : theme.colorScheme.onPrimary,
        shape: const CircleBorder(),
        child: const Icon(Icons.mic),
      ),
      bottomNavigationBar: _buildNavBar(
          isZzz, theme, zzzSignal, zzzMuted, zzzSurface, zzzAccent),
    );
  }

  Widget _buildNavBar(
    bool isZzz,
    ThemeData theme,
    Color zzzSignal,
    Color zzzMuted,
    Color zzzSurface,
    Color zzzAccent,
  ) {
    final nav = NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (value) {
        setState(() => currentIndex = value);
        // Refresh widget when navigating to dashboard (after potential changes)
        if (value == 0) {
          ref.read(widgetServiceProvider).refreshWidget();
        }
      },
      backgroundColor: isZzz ? zzzSurface : null,
      indicatorColor: isZzz ? zzzAccent.withValues(alpha: 0.24) : null,
      surfaceTintColor: isZzz ? zzzSignal.withValues(alpha: 0.06) : null,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: '仪表盘',
        ),
        NavigationDestination(
          icon: Icon(Icons.directions_subway_outlined),
          label: '出行',
        ),
        NavigationDestination(
          icon: Icon(Icons.restaurant_outlined),
          label: '饮食',
        ),
        NavigationDestination(
          icon: Icon(Icons.fitness_center_outlined),
          label: '运动',
        ),
        NavigationDestination(
          icon: Icon(Icons.sell_outlined),
          label: '标签',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: '账号',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: '设置',
        ),
      ],
    );

    if (!isZzz) return nav;

    return Theme(
      data: theme.copyWith(
        navigationBarTheme: NavigationBarThemeData(
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: zzzSignal);
            }
            return IconThemeData(color: zzzMuted);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(
                  color: zzzSignal, fontSize: 12, fontWeight: FontWeight.w500);
            }
            return TextStyle(color: zzzMuted, fontSize: 12);
          }),
        ),
      ),
      child: nav,
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

  Future<void> _showAgentPanel(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AgentDialogPanel(),
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
