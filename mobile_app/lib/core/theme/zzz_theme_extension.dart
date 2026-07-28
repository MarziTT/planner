import 'package:flutter/material.dart';

/// ZZZ (Kamen Rider) cyberpunk theme extension.
///
/// Centralizes all ZZZ-specific styling so pages don't need inline
/// `isZzz ? hardcodedColor : null` branching.
class ZzzThemeExtension extends ThemeExtension<ZzzThemeExtension> {
  const ZzzThemeExtension({
    required this.bg,
    required this.surface,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
    required this.borderGlow,
    this.cardElevation = 2,
    this.cardBorderRadius = 16,
  });

  /// Main background color
  final Color bg;

  /// Card / container surface color
  final Color surface;

  /// Accent color (buttons, highlights)
  final Color accent;

  /// Primary text color on dark bg
  final Color textPrimary;

  /// Secondary / muted text
  final Color textSecondary;

  /// Card border color
  final Color borderColor;

  /// Glow / shadow color
  final Color borderGlow;

  final double cardElevation;
  final double cardBorderRadius;

  /// Derived: error/destructive color (same as accent).
  Color get error => accent;

  /// Derived: muted text color (same as textSecondary).
  Color get textMuted => textSecondary;

  /// Standard ZZZ theme instance.
  static const standard = ZzzThemeExtension(
    bg: Color(0xFF0B0B12),
    surface: Color(0xFF12121C),
    accent: Color(0xFFFF2D55),
    textPrimary: Color(0xFFE8E8F0),
    textSecondary: Color(0xFF9E9EB8),
    borderColor: Color(0xFF2A2A3C),
    borderGlow: Color(0x1AFF2D55),
  );

  @override
  ZzzThemeExtension copyWith({
    Color? bg,
    Color? surface,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? borderColor,
    Color? borderGlow,
    double? cardElevation,
    double? cardBorderRadius,
  }) {
    return ZzzThemeExtension(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      borderColor: borderColor ?? this.borderColor,
      borderGlow: borderGlow ?? this.borderGlow,
      cardElevation: cardElevation ?? this.cardElevation,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
    );
  }

  @override
  ZzzThemeExtension lerp(ThemeExtension<ZzzThemeExtension>? other, double t) {
    if (other is! ZzzThemeExtension) return this;
    return ZzzThemeExtension(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      borderColor: Color.lerp(borderColor, other.borderColor, t) ?? borderColor,
      borderGlow: Color.lerp(borderGlow, other.borderGlow, t) ?? borderGlow,
      cardElevation: cardElevation,
      cardBorderRadius: cardBorderRadius,
    );
  }

  /// Pre-built card shape for ZZZ theme.
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        side: BorderSide(color: borderColor, width: 1),
      );
}

/// Convenience accessor for ZzzThemeExtension from BuildContext.
extension ZzzThemeX on BuildContext {
  /// Returns the ZzzThemeExtension if the current theme has one, else null.
  ZzzThemeExtension? get zzz =>
      Theme.of(this).extension<ZzzThemeExtension>();
}
