import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  /// Menghasilkan [TextTheme] berbasis font Plus Jakarta Sans.
  static TextTheme createTextTheme(TextTheme baseTextTheme) {
    return GoogleFonts.plusJakartaSansTextTheme(baseTextTheme);
  }
}

