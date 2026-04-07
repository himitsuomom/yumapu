import 'package:flutter/material.dart';

/// Yu-Map design system — onsen-inspired warm palette for Japan-first launch.
class AppTheme {
  AppTheme._();

  // Brand colours
  static const Color primary = Color(0xFF1565C0);      // Deep blue (water)
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color secondary = Color(0xFFE65100);    // Warm orange (onsen)
  static const Color secondaryLight = Color(0xFFFF8A65);
  static const Color surface = Color(0xFFFAFAFA);
  static const Color background = Color(0xFFF5F5F5);
  static const Color error = Color(0xFFD32F2F);
  static const Color onPrimary = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFE0E0E0);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: primary,
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: textPrimary,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: primary,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 8,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: onPrimary,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: primary),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: primaryLight.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: divider),
          ),
        ),
      );
}
