import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/home/presentation/home_shell_page.dart';
import '../features/onboarding/presentation/profile_setup_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.restoring) return state.matchedLocation == '/splash' ? null : '/splash';

      final loggedIn = authState.session != null;
      final goingToLogin = state.matchedLocation == '/login';
      final needsProfile = authState.session?.user.onboardingDone == false;

      if (!loggedIn && !goingToLogin) return '/login';
      if (loggedIn && goingToLogin) return needsProfile ? '/profile-setup' : '/home';
      if (loggedIn && needsProfile && state.matchedLocation != '/profile-setup') {
        return '/profile-setup';
      }
      if (!loggedIn && state.matchedLocation == '/splash') return '/login';
      if (loggedIn && state.matchedLocation == '/splash') {
        return needsProfile ? '/profile-setup' : '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const _SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/profile-setup', builder: (context, state) => const ProfileSetupPage()),
      GoRoute(
        path: '/home',
        builder: (context, state) => HomeShellPage(
          initialTab: state.uri.queryParameters['tab'] ?? 'dashboard',
        ),
      ),
    ],
  );
});

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
