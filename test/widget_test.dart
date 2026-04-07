// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yu_map/app.dart';

void main() {
  testWidgets('App renders login screen when not authenticated',
      (WidgetTester tester) async {
    // YuMapApp is a ConsumerWidget and requires ProviderScope.
    // In test environment AppConfig.isSupabaseConfigured returns false,
    // so the auth state is unauthenticated → LoginScreen is shown.
    await tester.pumpWidget(
      const ProviderScope(
        child: YuMapApp(),
      ),
    );
    await tester.pump();

    // LoginScreen's AppBar shows 'ログイン'
    expect(find.text('ログイン'), findsAtLeastNWidgets(1));
  });

  testWidgets('App wraps with MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: YuMapApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
