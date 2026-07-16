import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/theme/theme_controller.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        themeControllerProvider.overrideWith((ref) => ThemeController(prefs)),
        sharedPreferencesProvider.overrideWith((ref) => prefs),
      ],
      child: const PixelPlannerApp(),
    ),
  );
}
