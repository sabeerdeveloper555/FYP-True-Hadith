import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF1B6B3A);
  static const Color primaryDark = Color(0xFF134D2A);
  static const Color primaryLight = Color(0xFF2A8F52);

  // Accent
  static const Color accentGold = Color(0xFFC9A84C);
  static const Color accentGoldLight = Color(0xFFE0BC72);
  static const Color accentGoldDark = Color(0xFFA07830);

  // Neutral
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F9F7);
  static const Color surfaceVariant = Color(0xFFEEF3EE);

  // Text/Icons
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color onSurfaceVariant = Color(0xFF4A5A4A);

  // UI elements
  static const Color divider = Color(0xFFD9E4D9);
  static const Color border = Color(0xFFC2D4C2);
  static const Color shadow = Color(0x14000000);

  // Result Colors
  static const Color error = Color(0xFFC0392B);
  static const Color success = Color(0xFF1B6B3A);
  static const Color sahih = Color(0xFF1B6B3A); // Success
  static const Color hasan = Color(0xFFC9A84C); // Warning
  
  // Grade Chip Colors (Special)
  static const Color sahihBg = Color(0xFFE8F5ED);
  static const Color sahihText = Color(0xFF1B6B3A);
  static const Color sahihBorder = Color(0xFFA8D5B5);

  static const Color hasanBg = Color(0xFFFDF6E3);
  static const Color hasanText = Color(0xFF8A6914);
  static const Color hasanBorder = Color(0xFFD4B86A);

  static const Color daifBg = Color(0xFFFEF0EE);
  static const Color daifText = Color(0xFF9B3A2A);
  static const Color daifBorder = Color(0xFFE8AEA4);

  static Color getHadithColor(String classification) {
    final c = classification.toLowerCase();
    if (c.contains('sahih') || c.contains('صحيح')) return sahih;
    if (c.contains('hasan') || c.contains('حسن')) return hasan;
    if (c.contains('daif') || c.contains("da'if") || c.contains('ضعيف')) {
      return const Color(0xFF9B3A2A);
    }
    return const Color(0xFF9BA89B);
  }

  static Color getStatusColor(bool isAuthentic) {
    return isAuthentic ? sahih : error;
  }
}

class ThemeColors {
  ThemeColors._();

  static Color background(bool isDark) =>
      isDark ? const Color(0xFF121A15) : AppColors.background;

  static Color surface(bool isDark) =>
      isDark ? const Color(0xFF1E2D23) : AppColors.surface;

  static Color card(bool isDark) =>
      isDark ? const Color(0xFF1E2D23) : AppColors.surface;

  static Color textPrimary(bool isDark) =>
      isDark ? Colors.white : AppColors.onSurface;

  static Color textSecondary(bool isDark) =>
      isDark ? const Color(0xFFB0C4B0) : AppColors.onSurfaceVariant;

  static Color textLight(bool isDark) =>
      isDark ? const Color(0xFF889888) : const Color(0xFF9BA89B);

  static Color border(bool isDark) =>
      isDark ? const Color(0xFF3A5A3A) : AppColors.border;

  static Color divider(bool isDark) =>
      isDark ? const Color(0xFF3A5A3A) : AppColors.divider;

  static Color shadow(bool isDark) =>
      isDark ? Colors.black.withOpacity(0.3) : AppColors.shadow;

  static Color icon(bool isDark) =>
      isDark ? const Color(0xFF9DB89D) : AppColors.onSurfaceVariant;

  static Color shimmerBase(bool isDark) =>
      isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);

  static Color shimmerHighlight(bool isDark) =>
      isDark ? const Color(0xFF4A4A4A) : const Color(0xFFF5F5F5);

  static Color inputBackground(bool isDark) =>
      isDark ? const Color(0xFF1E2D23) : AppColors.surface;
}
