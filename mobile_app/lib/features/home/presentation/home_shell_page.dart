import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_controller.dart';
import '../../fast_capture/presentation/quick_capture_bar.dart';
import '../../notifications/data/reminder_gateway.dart';
import '../../notifications/domain/notification_tap_event.dart';
import '../../planner/presentation/planner_dashboard.dart';
import '../../planner/state/planner_controller.dart';
import '../../profile/presentation/profile_page.dart';
import '../../settings/domain/settings_model.dart';
import '../../settings/presentation/settings_page.dart';
import '../../settings/state/settings_controller.dart';
import '../../tags/presentation/tags_page.dart';
import '../../updates/presentation/update_banner.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key});

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage>
    with WidgetsBindingObserver {
  int currentIndex = 0;
  StreamSubscription<NotificationTapEvent>? _tapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() {
      final settingsState = ref.read(settingsControllerProvider);
      if (settingsState.settings == null && !settingsState.loading) {
        ref.read(settingsControllerProvider.notifier).load();
      }

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
    ref.read(selectedPlannerEventIdProvider.notifier).state = event.eventId;
    if (mounted) {
      setState(() => currentIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.session;
      final nextSession = next.session;
      if (previousSession == null && nextSession != null) {
        ref.read(plannerControllerProvider.notifier).loadDashboard();
      }
      if (previousSession != null && nextSession == null) {
        ref.read(plannerControllerProvider.notifier).markLoggedOut();
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
            final hour = pendingDraft.ambiguousHour ?? pendingDraft.startsAt.hour;
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmAmbiguousHour(hour < 12 ? hour + 12 : hour);
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
          onCancel: () {
            ref.read(fastCaptureControllerProvider.notifier).cancelPendingDraft();
          },
        );
      }

      final errorMessage = next.errorMessage;
      if (errorMessage != null && errorMessage != previous?.errorMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    });

    ref.listen(plannerControllerProvider, (previous, next) {
      _syncReminderSchedules(next, ref.read(settingsControllerProvider).settings);
    });

    ref.listen(settingsControllerProvider, (previous, next) {
      _syncReminderSchedules(ref.read(plannerControllerProvider), next.settings);
    });

    const pages = [
      PlannerDashboard(),
      TagsPage(),
      ProfilePage(),
      SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pixel Planner'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          const UpdateBanner(),
          if (currentIndex == 0) const QuickCaptureBar(),
          Expanded(child: pages[currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (value) => setState(() => currentIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            label: '计划',
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
      ),
    );
  }

  void _syncReminderSchedules(PlannerState plannerState, PlannerSettings? settings) {
    if (settings == null) return;
    ref.read(reminderCoordinatorProvider).sync(
          events: plannerState.events,
          settings: settings,
        );
  }
}
