// test/core/app_theme_test.dart
//
// Tests for AppTheme brand colors and theme configuration.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/core/theme/app_theme.dart';

void main() {
  group('AppTheme brand colours', () {
    test('primaryBlue has correct hex value', () {
      expect(AppTheme.primaryBlue, const Color(0xFF1565C0));
    });

    test('deepBlue has correct hex value', () {
      expect(AppTheme.deepBlue, const Color(0xFF0D47A1));
    });

    test('onsenBrown has correct hex value', () {
      expect(AppTheme.onsenBrown, const Color(0xFF795548));
    });

    test('warmGrey has correct hex value', () {
      expect(AppTheme.warmGrey, const Color(0xFFF5F5F5));
    });

    test('errorRed has correct hex value', () {
      expect(AppTheme.errorRed, const Color(0xFFD32F2F));
    });
  });

  group('AppTheme.light', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.light;
    });

    test('uses Material 3', () {
      expect(theme.useMaterial3, true);
    });

    test('has light brightness', () {
      expect(theme.brightness, Brightness.light);
    });

    test('AppBar is centered with no elevation', () {
      expect(theme.appBarTheme.centerTitle, true);
      expect(theme.appBarTheme.elevation, 0);
    });

    test('Card has elevation 2 and rounded corners', () {
      expect(theme.cardTheme.elevation, 2);
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
    });

    test('InputDecoration is filled with rounded border', () {
      expect(theme.inputDecorationTheme.filled, true);
      expect(theme.inputDecorationTheme.border, isA<OutlineInputBorder>());
    });

    test('ElevatedButton has full-width minimum size', () {
      final style = theme.elevatedButtonTheme.style;
      expect(style, isNotNull);
    });

    test('BottomNavigationBar uses primaryBlue selection', () {
      expect(
        theme.bottomNavigationBarTheme.selectedItemColor,
        AppTheme.primaryBlue,
      );
      expect(
        theme.bottomNavigationBarTheme.type,
        BottomNavigationBarType.fixed,
      );
    });
  });

  group('AppTheme.dark', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.dark;
    });

    test('uses Material 3', () {
      expect(theme.useMaterial3, true);
    });

    test('has dark brightness', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('AppBar is centered with no elevation', () {
      expect(theme.appBarTheme.centerTitle, true);
      expect(theme.appBarTheme.elevation, 0);
    });

    test('Card has elevation 2 and rounded corners', () {
      expect(theme.cardTheme.elevation, 2);
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
    });

    test('InputDecoration is filled', () {
      expect(theme.inputDecorationTheme.filled, true);
    });
  });

  group('AppTheme consistency', () {
    test('light and dark themes share same card border radius', () {
      final lightShape = AppTheme.light.cardTheme.shape as RoundedRectangleBorder;
      final darkShape = AppTheme.dark.cardTheme.shape as RoundedRectangleBorder;
      expect(lightShape.borderRadius, darkShape.borderRadius);
    });

    test('light and dark themes share same AppBar configuration', () {
      expect(
        AppTheme.light.appBarTheme.centerTitle,
        AppTheme.dark.appBarTheme.centerTitle,
      );
      expect(
        AppTheme.light.appBarTheme.elevation,
        AppTheme.dark.appBarTheme.elevation,
      );
    });

    test('both themes use Material 3', () {
      expect(AppTheme.light.useMaterial3, true);
      expect(AppTheme.dark.useMaterial3, true);
    });
  });
}
