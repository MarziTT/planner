import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

enum PlannerThemePreset {
  premiumMinimal,
  professionalDark,
  warmLife,
  forestOcean,
  kamenRiderZzz,
}

class ThemeState {
  const ThemeState({
    required this.preset,
    required this.mode,
    required this.lightTheme,
    required this.darkTheme,
  });

  final PlannerThemePreset preset;
  final ThemeMode mode;
  final ThemeData lightTheme;
  final ThemeData darkTheme;
}

class ThemeController extends StateNotifier<ThemeState> {
  ThemeController()
      : super(
          ThemeState(
            preset: PlannerThemePreset.premiumMinimal,
            mode: ThemeMode.dark,
            lightTheme: AppThemeBuilder.build(
              brightness: Brightness.light,
              seed: const Color(0xFF5B8CFF),
              surfaceMuted: const Color(0xFFF3F6FB),
            ),
            darkTheme: AppThemeBuilder.build(
              brightness: Brightness.dark,
              seed: const Color(0xFF7C5CFF),
              surfaceMuted: const Color(0xFF1D2433),
            ),
          ),
        );

  void switchPreset(PlannerThemePreset preset) {
    switch (preset) {
      case PlannerThemePreset.premiumMinimal:
        _setThemes(preset, const Color(0xFF5B8CFF), const Color(0xFFF3F6FB), const Color(0xFF1D2433));
        return;
      case PlannerThemePreset.professionalDark:
        _setThemes(preset, const Color(0xFF3E8BFF), const Color(0xFFF1F5F9), const Color(0xFF111827));
        return;
      case PlannerThemePreset.warmLife:
        _setThemes(preset, const Color(0xFFD97706), const Color(0xFFFFF7ED), const Color(0xFF2D1B12));
        return;
      case PlannerThemePreset.forestOcean:
        _setThemes(preset, const Color(0xFF0F9D7A), const Color(0xFFF0FDF9), const Color(0xFF0F2E2C));
        return;
      case PlannerThemePreset.kamenRiderZzz:
        _setThemes(preset, const Color(0xFFE53935), const Color(0xFFFFF1F1), const Color(0xFF170F17));
        return;
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = ThemeState(
      preset: state.preset,
      mode: mode,
      lightTheme: state.lightTheme,
      darkTheme: state.darkTheme,
    );
  }

  void _setThemes(PlannerThemePreset preset, Color seed, Color lightMuted, Color darkMuted) {
    state = ThemeState(
      preset: preset,
      mode: state.mode,
      lightTheme: AppThemeBuilder.build(
        brightness: Brightness.light,
        seed: seed,
        surfaceMuted: lightMuted,
      ),
      darkTheme: AppThemeBuilder.build(
        brightness: Brightness.dark,
        seed: seed,
        surfaceMuted: darkMuted,
      ),
    );
  }
}

final themeControllerProvider = StateNotifierProvider<ThemeController, ThemeState>(
  (ref) => ThemeController(),
);
