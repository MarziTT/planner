import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

enum PlannerThemePreset {
  sakuraSeason,
  ocean,
  forest,
  desertDusk,
  aurora,
  kamenRiderZzz,
}

class ThemeState {
  const ThemeState({
    required this.preset,
    required this.mode,
    required this.lightTheme,
    required this.darkTheme,
    required this.availablePresets,
  });

  final PlannerThemePreset preset;
  final ThemeMode mode;
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final List<PlannerThemePreset> availablePresets;
}

class ThemeController extends StateNotifier<ThemeState> {
  ThemeController(this._prefs) : super(_buildInitial(_prefs));

  final SharedPreferences? _prefs;

  static ThemeState _buildInitial(SharedPreferences? prefs) {
    final savedPreset = prefs?.getString('theme_preset');
    final savedMode = prefs?.getString('theme_mode');
    final preset = savedPreset != null
        ? _presetFromName(savedPreset)
        : PlannerThemePreset.forest;
    final mode = savedMode != null
        ? _modeFromName(savedMode)
        : ThemeMode.system;
    return _buildState(preset, mode, _defaultAvailable());
  }

  static List<PlannerThemePreset> _defaultAvailable() {
    return const [
      PlannerThemePreset.sakuraSeason,
      PlannerThemePreset.ocean,
      PlannerThemePreset.forest,
      PlannerThemePreset.desertDusk,
      PlannerThemePreset.aurora,
      PlannerThemePreset.kamenRiderZzz,
    ];
  }

  void setAvailableThemes(List<String> names) {
    final presets = names
        .map((n) => _presetFromName(n))
        .whereType<PlannerThemePreset>()
        .toList();
    if (presets.isEmpty) return;
    state = ThemeState(
      preset: state.preset,
      mode: state.mode,
      lightTheme: state.lightTheme,
      darkTheme: state.darkTheme,
      availablePresets: presets,
    );
  }

  void switchPreset(PlannerThemePreset preset) {
    state = _buildState(preset, state.mode, state.availablePresets);
    _prefs?.setString('theme_preset', preset.name);
  }

  void setThemeMode(ThemeMode mode) {
    state = _buildState(state.preset, mode, state.availablePresets);
    _prefs?.setString('theme_mode', mode.name);
  }

  static ThemeState _buildState(
    PlannerThemePreset preset,
    ThemeMode mode,
    List<PlannerThemePreset> available,
  ) {
    Color seed;
    Color lightMuted;
    Color darkMuted;

    switch (preset) {
      case PlannerThemePreset.sakuraSeason:
        seed = const Color(0xFFD98CB3);
        lightMuted = const Color(0xFFFFF5F8);
        darkMuted = const Color(0xFF1F1822);
      case PlannerThemePreset.ocean:
        seed = const Color(0xFF4A7A9E);
        lightMuted = const Color(0xFFF2F7FB);
        darkMuted = const Color(0xFF0F1A24);
      case PlannerThemePreset.forest:
        seed = const Color(0xFF5A8A6C);
        lightMuted = const Color(0xFFF4F9F5);
        darkMuted = const Color(0xFF101A14);
      case PlannerThemePreset.desertDusk:
        seed = const Color(0xFFC1764A);
        lightMuted = const Color(0xFFFDF7F2);
        darkMuted = const Color(0xFF1F1814);
      case PlannerThemePreset.aurora:
        seed = const Color(0xFF4AB8A6);
        lightMuted = const Color(0xFFF2FAF8);
        darkMuted = const Color(0xFF0F1A19);
      case PlannerThemePreset.kamenRiderZzz:
        seed = const Color(0xFFFF1744);
        lightMuted = const Color(0xFFFFF1F1);
        darkMuted = const Color(0xFF0A0A0F);
    }

    return ThemeState(
      preset: preset,
      mode: mode,
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
      availablePresets: available,
    );
  }

  static PlannerThemePreset _presetFromName(String name) {
    return PlannerThemePreset.values.firstWhere(
      (p) => p.name == name,
      orElse: () => PlannerThemePreset.forest,
    );
  }

  static ThemeMode _modeFromName(String name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }
}

final themeControllerProvider = StateNotifierProvider<ThemeController, ThemeState>(
  (ref) => throw UnimplementedError('Must be overridden in main.dart'),
);
