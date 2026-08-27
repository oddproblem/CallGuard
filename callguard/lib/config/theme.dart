import 'package:flutter/material.dart';

/// Design tokens for the CallGuard app.
///
/// UX rationale: Security apps need to feel trustworthy and calm.
/// Deep charcoal base + teal accent = authority + safety.
/// No purple/neon — those read as "entertainment" not "protection."
class AppColors {
  AppColors._();

  // ── Base surfaces ──
  static const Color background = Color(0xFF0F1114);     // deep charcoal
  static const Color surface = Color(0xFF181B20);         // card background
  static const Color surfaceLight = Color(0xFF1F2328);    // slightly elevated

  // ── Accent: teal → universally reads "secure, protected" ──
  static const Color accent = Color(0xFF00BFA5);          // primary teal
  static const Color accentDark = Color(0xFF00897B);      // pressed / darker teal
  static const Color accentSubtle = Color(0xFF1A2F2C);    // teal-tinted surface for chips/pills

  // ── Text hierarchy ──
  static const Color textPrimary = Color(0xFFF0F0F0);    // warm white, not harsh
  static const Color textSecondary = Color(0xFF8B9098);   // readable muted
  static const Color textMuted = Color(0xFF505560);       // hints, captions

  // ── Borders ──
  static const Color border = Color(0xFF2A2D33);          // subtle but visible

  // ── Semantic ──
  static const Color success = Color(0xFF4CAF50);         // natural green, not neon
  static const Color warning = Color(0xFFFF9800);         // amber
  static const Color error = Color(0xFFEF5350);           // red, not neon
}

class AppGradients {
  AppGradients._();

  /// Primary action gradient — single-hue teal shift (not multi-color)
  static const LinearGradient accent = LinearGradient(
    colors: [AppColors.accent, AppColors.accentDark],
  );

  /// Used for avatars, key visual elements — teal to slightly deeper teal
  static const LinearGradient accentPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accent, Color(0xFF00796B)],
  );

  /// Card/surface gradient — very subtle depth
  static const LinearGradient surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.surface, AppColors.surfaceLight],
  );

  static LinearGradient error = LinearGradient(
    colors: [Colors.red.shade400, Colors.red.shade700],
  );

  static LinearGradient success = LinearGradient(
    colors: [Colors.green.shade600, Colors.green.shade800],
  );

  /// Background gradient — nearly flat charcoal with subtle warmth
  static const LinearGradient backgroundSubtle = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.background, Color(0xFF121518), AppColors.background],
    stops: [0.0, 0.5, 1.0],
  );
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const TextStyle idDisplay = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 36,
    fontWeight: FontWeight.bold,
    letterSpacing: 6,
    fontFamily: 'monospace',
  );

  static const TextStyle idDisplaySmall = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 4,
    fontFamily: 'monospace',
  );

  static const TextStyle label = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 11,
    letterSpacing: 2.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textMuted,
    fontSize: 13,
    letterSpacing: 1.5,
  );

  static const TextStyle dialInput = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    letterSpacing: 8,
    fontFamily: 'monospace',
    fontWeight: FontWeight.w600,
  );
}

/// Full app theme configuration.
ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentDark,
      surface: AppColors.surface,
    ),
    fontFamily: 'Roboto',
  );
}
