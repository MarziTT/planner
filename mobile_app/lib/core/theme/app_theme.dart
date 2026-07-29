import 'package:flutter/material.dart';

import 'zzz_theme_extension.dart';

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
      surfaceMuted:
          Color.lerp(surfaceMuted, other.surfaceMuted, t) ?? surfaceMuted,
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
    ZzzThemeExtension? zzzTheme,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final scheme = zzzTheme == null
        ? baseScheme
        : baseScheme.copyWith(
            primary: zzzTheme.accent,
            onPrimary: zzzTheme.textPrimary,
            primaryContainer: zzzTheme.accentDeep,
            onPrimaryContainer: zzzTheme.textPrimary,
            secondary: zzzTheme.signal,
            onSecondary: zzzTheme.bg,
            secondaryContainer: zzzTheme.surfaceHigh,
            onSecondaryContainer: zzzTheme.textPrimary,
            tertiary: zzzTheme.success,
            onTertiary: zzzTheme.bg,
            surface: zzzTheme.bg,
            surfaceContainerLowest: zzzTheme.bg,
            surfaceContainerLow: zzzTheme.surfaceLow,
            surfaceContainer: zzzTheme.surface,
            surfaceContainerHigh: zzzTheme.surfaceHigh,
            surfaceContainerHighest: zzzTheme.surfaceHigh,
            onSurface: zzzTheme.textPrimary,
            onSurfaceVariant: zzzTheme.textSecondary,
            outline: zzzTheme.borderStrong,
            outlineVariant: zzzTheme.borderColor,
            error: zzzTheme.danger,
            onError: zzzTheme.textPrimary,
          );
    final isDark = brightness == Brightness.dark;
    final popupBg =
        zzzTheme?.surfaceLow ?? (isDark ? const Color(0xFF15151F) : null);
    final popupSurface =
        zzzTheme?.surface ?? (isDark ? const Color(0xFF1A1A2E) : null);
    final cardColor = zzzTheme?.surface ?? scheme.surfaceContainerLow;
    final cardShape = zzzTheme?.cardShape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: zzzTheme?.bg ?? scheme.surface,
      fontFamily: zzzTheme?.terminalFontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: zzzTheme?.surface ?? scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: zzzTheme != null,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: zzzTheme?.cardElevation ?? 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: zzzTheme?.surfaceLow ?? surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(zzzTheme?.cardBorderRadius ?? 12),
          borderSide: BorderSide(
            color: zzzTheme?.borderColor ?? Colors.transparent,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(zzzTheme?.cardBorderRadius ?? 12),
          borderSide: BorderSide(
            color: zzzTheme?.borderColor ?? Colors.transparent,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(zzzTheme?.cardBorderRadius ?? 12),
          borderSide: BorderSide(
            color: zzzTheme?.signal ?? scheme.primary,
            width: zzzTheme == null ? 1 : 1.5,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: zzzTheme?.borderColor ?? scheme.outlineVariant,
        thickness: zzzTheme == null ? null : 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: zzzTheme?.accent,
          foregroundColor: zzzTheme?.textPrimary,
          elevation: zzzTheme?.cardElevation ?? 1,
          shape: zzzTheme?.cardShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: zzzTheme?.signal,
          side: zzzTheme == null
              ? null
              : BorderSide(color: zzzTheme.borderStrong),
          shape: zzzTheme?.cardShape,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: zzzTheme?.signal ?? scheme.primary,
        linearTrackColor: zzzTheme?.surfaceHigh,
        circularTrackColor: zzzTheme?.surfaceHigh,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: zzzTheme?.surfaceHigh,
        contentTextStyle:
            zzzTheme == null ? null : TextStyle(color: zzzTheme.textPrimary),
        actionTextColor: zzzTheme?.signal,
        shape: zzzTheme?.cardShape,
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: zzzTheme?.surface,
        indicatorColor: zzzTheme?.accentDeep,
        labelTextStyle: zzzTheme == null
            ? null
            : WidgetStatePropertyAll(
                TextStyle(color: zzzTheme.textSecondary),
              ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(popupBg ?? scheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      dialogTheme: isDark
          ? DialogThemeData(
              backgroundColor: popupSurface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            )
          : null,
      datePickerTheme: isDark
          ? DatePickerThemeData(
              backgroundColor: popupSurface,
              headerBackgroundColor: popupBg,
            )
          : null,
      timePickerTheme: isDark
          ? TimePickerThemeData(
              backgroundColor: popupSurface,
              dialBackgroundColor: popupBg,
            )
          : null,
      extensions: [
        PlannerPalette(
          surfaceMuted: surfaceMuted,
          brand: zzzTheme?.accent ?? seed,
          success: zzzTheme?.success ?? const Color(0xFF2C9A68),
          warning: zzzTheme?.warning ?? const Color(0xFFF59E0B),
        ),
        if (zzzTheme != null) zzzTheme,
      ],
    );
  }
}
