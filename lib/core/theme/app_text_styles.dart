import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  // English Translation Font (Lora)
  static TextStyle translation({
    double fontSize = 17,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.7,
    Color? color,
  }) {
    return GoogleFonts.lora(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
    );
  }

  // UI Font (DM Sans)
  static TextStyle ui({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // Arabic Text (Scheherazade New)
  static TextStyle arabic({
    double fontSize = 21,
    double height = 2.0,
    Color? color,
  }) {
    return GoogleFonts.scheherazadeNew(
      fontSize: fontSize,
      height: height,
      color: color,
    );
  }

  // Dedicated Section Header
  static TextStyle sectionHeader = ui(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
  );

  // Quote Style (Hadith Text)
  // English: Lora 17sp, height 1.7
  // Arabic: Scheherazade New 21sp, RTL, height 2.0
  static TextStyle hadithEnglish = translation(
    fontSize: 17,
    height: 1.7,
  );

  static TextStyle hadithArabic = arabic(
    fontSize: 21,
    height: 2.0,
  );
}
