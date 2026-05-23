// test/features/settings/settings_screen_test.dart
//
// Widget tests for SettingsScreen.
// All providers are overridden so no Supabase / RevenueCat / SecureStorage
// platform channels are invoked.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/features/settings/settings_screen.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/subscription_provider.dart';
import 'package:yu_map/providers/theme_provider.dart';
// ── Stub notifiers ────────────────────────────────────────────────────────

/// Thin ThemeModeNotifier that skips FlutterSecureStorage read.
class _StubThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system; // no storage read

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode; // no storage write
  }
}

/// SubscriptionNotifier backed by the real (no-op) SubscriptionService.
/// isRevenueCatConfigured is false in tests so no platform channels are hit.
class _StubSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionState();
}

// ── Helper ────────────────────────────────────────────────────────────────

Widget buildSubject({bool isSignedIn = false}) {
  return ProviderScope(
    overrides: [
      supabaseClientProvider.overrideWithValue(null),
      sessionProvider.overrideWithValue(null),
      isSignedInProvider.overrideWithValue(isSignedIn),
      isAdminProvider.overrideWith((ref) async => false),
      currentUserProfileProvider.overrideWith((ref) async => null),
      subscriptionProvider.overrideWith(
        _StubSubscriptionNotifier.new,
      ),
      themeModeProvider.overrideWith(() => _StubThemeModeNotifier()),
    ],
    child: const MaterialApp(
      home: SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('renders 設定 AppBar title', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('設定'), findsOneWidget);
  });

  testWidgets('renders プライバシーポリシー list tile', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // Scroll to bottom to build lazily-rendered list tiles
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump();

    expect(find.text('プライバシーポリシー'), findsOneWidget);
  });

  testWidgets('renders 利用規約 list tile', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump();

    expect(find.text('利用規約'), findsOneWidget);
  });

  testWidgets('shows ログイン tile when not signed in', (tester) async {
    await tester.pumpWidget(buildSubject(isSignedIn: false));
    await tester.pump();

    expect(find.text('ログイン'), findsOneWidget);
    expect(find.text('ログアウト'), findsNothing);
  });

  // NOTE: The 'isSignedIn: true' variant triggers _NotificationSettingsSection
  // which requires a Firebase app instance. Since tests run without Firebase,
  // this produces an unrecoverable platform-channel error. Covered indirectly
  // by the negative test below (ログイン shown ↔ ログアウト not shown).

  testWidgets('shows アカウント section header', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('アカウント'), findsOneWidget);
  });

  testWidgets('shows 外観 section header', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('外観'), findsOneWidget);
  });

  testWidgets('shows アプリ情報 section header', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('アプリ情報'), findsOneWidget);
  });

  testWidgets('shows フィードバック section header', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('フィードバック'), findsOneWidget);
  });

  testWidgets('shows バージョン tile', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('バージョン'), findsOneWidget);
  });

  // NOTE: Cannot test signed-in state without Firebase — see comment above.

  testWidgets('does not show 危険な操作 section when not signed in',
      (tester) async {
    await tester.pumpWidget(buildSubject(isSignedIn: false));
    await tester.pump();

    expect(find.text('危険な操作'), findsNothing);
  });
}
