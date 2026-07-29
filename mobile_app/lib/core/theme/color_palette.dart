import 'package:flutter/material.dart';

// ============================================================
// Centralized Color Palette — PixelPlanner
//
// Eliminates inline Color(0xFF...) hardcoding.
// Import this file instead of writing raw hex colors.
// ============================================================

// --- ZZZ Theme (original cyber-terminal palette) ---
const kZzzBg = Color(0xFF080A10);
const kZzzSurface = Color(0xFF111522);
const kZzzRed = Color(0xFFFF2147);
const kZzzSignal = Color(0xFF50E3FF);
const kZzzGreen = kZzzSignal; // Backward-compatible alias for old widgets.
const kZzzGreenLight = Color(0xFFF4F7FB);
const kZzzText = Color(0xFFF4F7FB);
const kZzzSilver = Color(0xFF6F7D91);

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
