import 'package:flutter/material.dart';

/// ZZZ theme tokens.
///
/// The visual language is an original cyber-terminal treatment: graphite
/// surfaces, red alert energy, cyan telemetry, and restrained micro-glow.
/// Keeping the tokens here prevents pages from rebuilding the theme ad hoc.
class ZzzThemeExtension extends ThemeExtension<ZzzThemeExtension> {
  const ZzzThemeExtension({
    required this.bg,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.accent,
    required this.accentDeep,
    required this.signal,
    required this.success,
    required this.warning,
    required this.danger,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.borderColor,
    required this.borderStrong,
    required this.borderGlow,
    this.cardElevation = 2,
    this.cardBorderRadius = 10,
    this.terminalFontFamily = 'monospace',
  });

  final Color bg;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color accent;
  final Color accentDeep;
  final Color signal;
  final Color success;
  final Color warning;
  final Color danger;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color borderColor;
  final Color borderStrong;
  final Color borderGlow;
  final double cardElevation;
  final double cardBorderRadius;
  final String terminalFontFamily;

  Color get error => danger;
  Color get textMuted => textTertiary;

  /// Default ZZZ visual system: black graphite, red alert, cyan telemetry.
  static const standard = ZzzThemeExtension(
    bg: Color(0xFF080A10),
    surface: Color(0xFF111522),
    surfaceLow: Color(0xFF0D111B),
    surfaceHigh: Color(0xFF1A2130),
    accent: Color(0xFFFF2147),
    accentDeep: Color(0xFFB50F36),
    signal: Color(0xFF50E3FF),
    success: Color(0xFF40E0A0),
    warning: Color(0xFFFFC857),
    danger: Color(0xFFFF4D6D),
    textPrimary: Color(0xFFF4F7FB),
    textSecondary: Color(0xFFAAB4C4),
    textTertiary: Color(0xFF6F7D91),
    borderColor: Color(0xFF283448),
    borderStrong: Color(0xFF46617F),
    borderGlow: Color(0x26FF2147),
  );

  @override
  ZzzThemeExtension copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceLow,
    Color? surfaceHigh,
    Color? accent,
    Color? accentDeep,
    Color? signal,
    Color? success,
    Color? warning,
    Color? danger,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? borderColor,
    Color? borderStrong,
    Color? borderGlow,
    double? cardElevation,
    double? cardBorderRadius,
    String? terminalFontFamily,
  }) {
    return ZzzThemeExtension(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      accent: accent ?? this.accent,
      accentDeep: accentDeep ?? this.accentDeep,
      signal: signal ?? this.signal,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      borderColor: borderColor ?? this.borderColor,
      borderStrong: borderStrong ?? this.borderStrong,
      borderGlow: borderGlow ?? this.borderGlow,
      cardElevation: cardElevation ?? this.cardElevation,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      terminalFontFamily: terminalFontFamily ?? this.terminalFontFamily,
    );
  }

  @override
  ZzzThemeExtension lerp(ThemeExtension<ZzzThemeExtension>? other, double t) {
    if (other is! ZzzThemeExtension) return this;
    return ZzzThemeExtension(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t) ?? surfaceLow,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t) ?? surfaceHigh,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t) ?? accentDeep,
      signal: Color.lerp(signal, other.signal, t) ?? signal,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textTertiary:
          Color.lerp(textTertiary, other.textTertiary, t) ?? textTertiary,
      borderColor: Color.lerp(borderColor, other.borderColor, t) ?? borderColor,
      borderStrong:
          Color.lerp(borderStrong, other.borderStrong, t) ?? borderStrong,
      borderGlow: Color.lerp(borderGlow, other.borderGlow, t) ?? borderGlow,
      cardElevation: cardElevation,
      cardBorderRadius: cardBorderRadius,
      terminalFontFamily: terminalFontFamily,
    );
  }

  OutlinedBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        side: BorderSide(color: borderColor, width: 1),
      );
}

extension ZzzThemeX on BuildContext {
  ZzzThemeExtension? get zzz => Theme.of(this).extension<ZzzThemeExtension>();
}
