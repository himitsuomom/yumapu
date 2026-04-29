import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yu_map/app.dart';

void main() {
  setUp(() {
    // FlutterSecureStorage などのプラットフォームチャネルをダミーで応答させる。
    // これがないと initState の _initStorage が MissingPluginException で止まり
    // _onboardingCompleted が null のまま → CircularProgressIndicator が残る。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_native_splash'),
      (call) async => null,
    );
  });

  testWidgets('App renders login screen when not authenticated',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: YuMapApp(),
      ),
    );
    // _initStorage の非同期処理を全て完了させる
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 認証前 → LoginScreen が表示されていること
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
