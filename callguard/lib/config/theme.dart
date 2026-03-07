import 'package:flutter/material.dart';

/// Design tokens for the CallGuard app.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0A0A1A);
  static const Color surface = Color(0xFF141428);
  static const Color surfaceLight = Color(0xFF1A1A3E);
  static const Color accent = Color(0xFF00D2FF);
  static const Color accentDark = Color(0xFF0099CC);
  static const Color purple = Color(0xFF7B2FFF);

  static const Color textPrimary = Colors.white;
  static Color textSecondary = Colors.white.withOpacity(0.4);
  static Color textMuted = Colors.white.withOpacity(0.25);
  static Color border = Colors.white.withOpacity(0.06);

  static const Color success = Colors.greenAccent;
  static const Color warning = Colors.orangeAccent;
  static const Color error = Colors.redAccent;
}

class AppGradients {
  AppGradients._();

  static const LinearGradient accent = LinearGradient(
    colors: [AppColors.accent, AppColors.accentDark],
  );

  static const LinearGradient accentPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accent, AppColors.purple],
  );

  static const LinearGradient surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.surface, AppColors.surfaceLight],
  );

  static LinearGradient error = LinearGradient(
    colors: [Colors.red.shade400, Colors.red.shade700],
  );

  static LinearGradient success = LinearGradient(
    colors: [Colors.green.shade400, Colors.green.shade700],
  );

  static const LinearGradient backgroundSubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.background, Color(0xFF0A102A), AppColors.background],
    stops: [0.0, 0.5, 1.0],
  );
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading = TextStyle(
    color: Colors.white,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );

  static const TextStyle idDisplay = TextStyle(
    color: Colors.white,
    fontSize: 40,
    fontWeight: FontWeight.bold,
    letterSpacing: 8,
    fontFamily: 'monospace',
  );

  static const TextStyle idDisplaySmall = TextStyle(
    color: Colors.white,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 6,
    fontFamily: 'monospace',
  );

  static TextStyle label = TextStyle(
    color: Colors.white.withOpacity(0.4),
    fontSize: 11,
    letterSpacing: 3,
    fontWeight: FontWeight.w600,
  );

  static TextStyle caption = TextStyle(
    color: Colors.white.withOpacity(0.3),
    fontSize: 13,
    letterSpacing: 2,
  );

  static const TextStyle dialInput = TextStyle(
    color: Colors.white,
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
      secondary: AppColors.purple,
      surface: AppColors.surface,
    ),
    fontFamily: 'Roboto',
  );
}
