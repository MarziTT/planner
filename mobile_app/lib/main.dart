import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/cache/local_cache_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/habits/notify_manager.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final cache = LocalCacheService(prefs);

  // Phase 2 锁屏通知增强：注入 SharedPreferences + 注册全部 Channel
  NotifyManager.setSharedPreferences(prefs);
  // Notification channels are optional on OHOS; never block the first frame.
  try {
    await NotifyManager.ensureChannels();
  } catch (_) {
    // Native notification support may not be registered in every build.
  }

  runApp(
    ProviderScope(
      overrides: [
        themeControllerProvider.overrideWith((ref) => ThemeController(prefs)),
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        localCacheProvider.overrideWith((ref) => cache),
      ],
      child: const PixelPlannerApp(),
    ),
  );
}
