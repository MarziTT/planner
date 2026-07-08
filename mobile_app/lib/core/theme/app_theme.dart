import 'package:flutter/material.dart';

class PlannerPalette extends ThemeExtension<PlannerPalette> {
  const PlannerPalette({
    required this.surfaceMuted,
    required this.brand,
    required this.success,
    required this.warning,
  });

  final Color surfaceMuted;
  final Color brand;
  final Color success;
  final Color warning;

  @override
  PlannerPalette copyWith({
    Color? surfaceMuted,
    Color? brand,
    Color? success,
    Color? warning,
  }) {
    return PlannerPalette(
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      brand: brand ?? this.brand,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  PlannerPalette lerp(ThemeExtension<PlannerPalette>? other, double t) {
    if (other is! PlannerPalette) return this;
    return PlannerPalette(
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t) ?? surfaceMuted,
      brand: Color.lerp(brand, other.brand, t) ?? brand,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
    );
  }
}

class AppThemeBuilder {
  static ThemeData build({
    required Brightness brightness,
    required Color seed,
    required Color surfaceMuted,
  }) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      extensions: [
        PlannerPalette(
          surfaceMuted: surfaceMuted,
          brand: seed,
          success: const Color(0xFF2C9A68),
          warning: const Color(0xFFF59E0B),
        ),
      ],
    );
  }
}
