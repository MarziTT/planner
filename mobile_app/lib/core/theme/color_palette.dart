import 'package:flutter/material.dart';

// ============================================================
// Centralized Color Palette — PixelPlanner
//
// Eliminates inline Color(0xFF...) hardcoding.
// Import this file instead of writing raw hex colors.
// ============================================================

// --- ZZZ Theme (cyberpunk / gaming aesthetics) ---
// These are aliased from zzz_gif_decoration.dart for convenience.
// Re-exported to avoid circular imports between widgets/ and core/.

const kZzzBg = Color(0xFF0A0A0F);
const kZzzSurface = Color(0xFF0D0B12);
const kZzzRed = Color(0xFFFF1744);
const kZzzGreen = Color(0xFF00FF41);
const kZzzGreenLight = Color(0xFFE0F0E0);
const kZzzText = Color(0xFFE0F0E0);
const kZzzSilver = Color(0xFFC8C8D8);

// --- Weather Gradients ---
const kWeatherSunnyStart = Color(0xFF3A4A5A);
const kWeatherSunnyEnd = Color(0xFF1E2A3A);

// --- Semantic Colors ---
const kSuccessGreen = Color(0xFF4CAF50);
const kWarningOrange = Color(0xFFFF9800);
const kErrorRed = Color(0xFFE53935);
const kInfoBlue = Color(0xFF2196F3);

// --- Neutral / Surface ---
const kSurfaceWhite = Color(0xFFFFFFFF);
const kSurfaceOffWhite = Color(0xFFF5F5F5);
const kSurfaceLight = Color(0xFFFAFAFA);
const kTextPrimary = Color(0xFF212121);
const kTextSecondary = Color(0xFF757575);
const kTextHint = Color(0xFFBDBDBD);
const kDivider = Color(0xFFE0E0E0);
const kOverlayLight = Color(0x33000000);
const kOverlayMedium = Color(0x66000000);

// --- Dark Theme ---
const kDarkBg = Color(0xFF121212);
const kDarkSurface = Color(0xFF1E1E1E);
const kDarkCard = Color(0xFF252525);
const kDarkTextPrimary = Color(0xFFE0E0E0);
const kDarkTextSecondary = Color(0xFF9E9E9E);
const kDarkDivider = Color(0xFF424242);
