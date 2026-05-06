import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_text_styles.dart';

class AppThemeDark {
  static ThemeData get dark {
    const primary = Color(0xFF2A8F52);
    const surface = Color(0xFF121A15);
    const secondary = Color(0xFFC9A84C);
    const onSurface = Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF134D2A),
        onPrimaryContainer: Color(0xFFB7E4C7),
        secondary: secondary,
        onSecondary: Color(0xFF1A1A1A),
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: Color(0xFF1E2D23),
        onSurfaceVariant: Color(0xFFB0C4B0),
        outline: Color(0xFF3A5A3A),
        error: Color(0xFFE57373),
      ),

      textTheme: GoogleFonts.dmSansTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A2820),
        foregroundColor: secondary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.translation(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: secondary,
        ),
        iconTheme: const IconThemeData(color: secondary),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF121A15),
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF5A7A5A),
        elevation: 8,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondary,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1E2D23),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF3A5A3A), width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E2D23),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A5A3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A5A3A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF5A7A5A)),
        hintStyle: const TextStyle(color: Color(0xFF5A7A5A)),
      ),

      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          color: Color(0xFFB0C4B0),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF3A5A3A),
        thickness: 1,
      ),

      iconTheme: const IconThemeData(
        color: Color(0xFF9DB89D),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1E2D23),
        labelStyle: const TextStyle(color: Color(0xFF9DB89D)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFF3A5A3A)),
        ),
      ),

      // Drawer
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF121A15),
      ),
    );
  }
}
