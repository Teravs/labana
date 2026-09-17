import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // COLOR SCHEMES
  // ---------------------------------------------------------------------------
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightOnPrimary,
    primaryContainer: AppColors.lightPrimaryContainer,
    onPrimaryContainer: AppColors.lightOnPrimaryContainer,
    secondary: AppColors.lightSecondary,
    onSecondary: AppColors.lightOnSecondary,
    secondaryContainer: AppColors.lightSecondaryContainer,
    onSecondaryContainer: AppColors.lightOnSecondaryContainer,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightOnSurface,
    surfaceContainer: AppColors.lightSurfaceContainer,
    error: AppColors.error,
    onError: Colors.white,
    outline: AppColors.lightOutline,
    outlineVariant: AppColors.lightOutlineVariant,
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    primaryContainer: AppColors.darkPrimaryContainer,
    onPrimaryContainer: AppColors.darkOnPrimaryContainer,
    secondary: AppColors.darkSecondary,
    onSecondary: AppColors.darkOnSecondary,
    secondaryContainer: AppColors.darkSecondaryContainer,
    onSecondaryContainer: AppColors.darkOnSecondaryContainer,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    surfaceContainer: AppColors.darkSurfaceContainer,
    error: AppColors.darkError,
    onError: Color(0xFF690005),
    outline: AppColors.darkOutline,
    outlineVariant: AppColors.darkOutlineVariant,
  );

  // ---------------------------------------------------------------------------
  // LIGHT THEME
  // ---------------------------------------------------------------------------
  static ThemeData get lightTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: AppColors.lightSurface,
    );

    final textTheme = AppTypography.createTextTheme(baseTheme.textTheme);

    return baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightOnSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.lightOnSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.lightSurfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightOutlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.lightOutline),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightOutlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.lightPrimary,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: AppColors.lightSurfaceContainer,
        indicatorColor: AppColors.lightPrimaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(size: 24, color: AppColors.lightPrimary);
          }
          return IconThemeData(
            size: 24,
            color: AppColors.lightOnSurface.withAlpha(180),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              fontSize: 11,
              letterSpacing: -0.3,
              fontWeight: FontWeight.w700,
              color: AppColors.lightPrimary,
            );
          }
          return textTheme.labelSmall?.copyWith(
            fontSize: 11,
            letterSpacing: -0.3,
            fontWeight: FontWeight.w500,
            color: AppColors.lightOnSurface.withAlpha(180),
          );
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurfaceContainer,
        selectedItemColor: AppColors.lightPrimary,
        unselectedItemColor: Color(0xFF7A8782),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.lightOnSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkBackground,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DARK THEME
  // ---------------------------------------------------------------------------
  static ThemeData get darkTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: AppColors.darkSurface,
    );

    final textTheme = AppTypography.createTextTheme(baseTheme.textTheme);

    return baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkOnSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.darkOnSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.darkSurfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkOutlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.darkOutline),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkOutlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.darkPrimary,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkError),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: AppColors.darkSurfaceContainer,
        indicatorColor: AppColors.darkPrimaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(size: 24, color: AppColors.darkPrimary);
          }
          return IconThemeData(
            size: 24,
            color: AppColors.darkOnSurface.withAlpha(180),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              fontSize: 11,
              letterSpacing: -0.3,
              fontWeight: FontWeight.w700,
              color: AppColors.darkPrimary,
            );
          }
          return textTheme.labelSmall?.copyWith(
            fontSize: 11,
            letterSpacing: -0.3,
            fontWeight: FontWeight.w500,
            color: AppColors.darkOnSurface.withAlpha(180),
          );
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurfaceContainer,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: Color(0xFF8B9792),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.darkOnSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E2825),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
