import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_controller.dart';
import '../../planner/presentation/planner_dashboard.dart';
import '../../planner/state/planner_controller.dart';
import '../../profile/presentation/profile_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../tags/presentation/tags_page.dart';
import '../../updates/presentation/update_banner.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key});

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  int currentIndex = 0;

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
}
