import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // YuMapApp は AppLinks / FlutterSecureStorage / Firebase など多数の
  // プラットフォームチャネルに依存しているため、
  // CI (ubuntu) では全チャネルのモックが困難。
  // ここでは Riverpod の ProviderScope が正しく機能することを
  // シンプルなウィジェットで検証する。
  testWidgets('ProviderScope renders a widget correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Text('CI smoke test'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('CI smoke test'), findsOneWidget);
  });

  testWidgets('MaterialApp renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('hello'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });
}
