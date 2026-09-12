import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core Brand Colors
  static const Color primary = Color(0xFF146C5B);
  static const Color accent = Color(0xFFD9A441);
  static const Color lightBackground = Color(0xFFF7F8F5);
  static const Color darkBackground = Color(0xFF111816);

  // Light Theme Palette
  static const Color lightPrimary = primary;
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFD4ECE5);
  static const Color lightOnPrimaryContainer = Color(0xFF07382E);

  static const Color lightSecondary = accent;
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFFCEECC);
  static const Color lightOnSecondaryContainer = Color(0xFF3F2E00);

  static const Color lightSurface = lightBackground;
  static const Color lightOnSurface = darkBackground;
  static const Color lightSurfaceContainer = Color(0xFFFFFFFF);
  static const Color lightOutline = Color(0xFFCCD4CF);
  static const Color lightOutlineVariant = Color(0xFFE2E7E4);

  // Dark Theme Palette
  static const Color darkPrimary = Color(0xFF4EB8A1);
  static const Color darkOnPrimary = Color(0xFF00382E);
  static const Color darkPrimaryContainer = Color(0xFF146C5B);
  static const Color darkOnPrimaryContainer = Color(0xFFD4ECE5);

  static const Color darkSecondary = Color(0xFFE5B558);
  static const Color darkOnSecondary = Color(0xFF3E2D00);
  static const Color darkSecondaryContainer = Color(0xFF5A4200);
  static const Color darkOnSecondaryContainer = Color(0xFFFCEECC);

  static const Color darkSurface = darkBackground;
  static const Color darkOnSurface = Color(0xFFEAEFEB);
  static const Color darkSurfaceContainer = Color(0xFF1A2321);
  static const Color darkOutline = Color(0xFF404E49);
  static const Color darkOutlineVariant = Color(0xFF2B3632);

  // Semantic Status Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFBA1A1A);
  static const Color darkError = Color(0xFFFFB4AB);
}
