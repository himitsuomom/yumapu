// test/features/auth/login_screen_test.dart
//
// Widget tests for LoginScreen.
// These tests do NOT require Supabase — they override all Riverpod providers
// with stub values so no platform channels are hit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/features/auth/screens/login_screen.dart';
import 'package:yu_map/providers/auth_provider.dart';

// ── Minimal stub that never hits Supabase ─────────────────────────────────
// Extends AuthNotifier (which is a StateNotifier) passing null as the client.
class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier() : super(null);
}

void main() {
  Widget buildSubject({AsyncValue<void> authState = const AsyncData(null)}) {
    final stubNotifier = _StubAuthNotifier();

    return ProviderScope(
      overrides: [
        // Override supabase client → null (not configured)
        supabaseClientProvider.overrideWithValue(null),

        // Override the auth notifier with our stub
        authNotifierProvider.overrideWith((ref) => _StubAuthNotifier()),

        // sessionProvider → null (not signed in)
        sessionProvider.overrideWithValue(null),

        // isSignedIn → false
        isSignedInProvider.overrideWithValue(false),

        // guestModeProvider → false
        guestModeProvider.overrideWith((ref) => false),
      ],
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  testWidgets('renders app title 湯マップ', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('湯マップ'), findsOneWidget);
  });

  testWidgets('renders AppBar with ログイン title', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // AppBar title
    expect(find.text('ログイン'), findsWidgets);
  });

  testWidgets('renders email and password fields', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);
  });

  testWidgets('renders ログイン ElevatedButton', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // The button text node (not the AppBar)
    final loginButtons = find.descendant(
      of: find.byType(ElevatedButton),
      matching: find.text('ログイン'),
    );
    expect(loginButtons, findsOneWidget);
  });

  testWidgets('renders ゲストとして閲覧する button', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('ゲストとして閲覧する'), findsOneWidget);
  });

  testWidgets('renders 新規登録 link', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('新規登録'), findsOneWidget);
  });

  testWidgets('renders パスワードを忘れた方はこちら link', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('パスワードを忘れた方はこちら'), findsOneWidget);
  });

  // NOTE: Validation tests (empty/invalid email/short password) are not
  // included here because _signIn() returns early with a SnackBar when
  // AppConfig.isSupabaseConfigured is false (the test environment).
  // The form validators are unit-tested separately via direct invocation.

  testWidgets('ElevatedButton is enabled when not loading', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('tapping ログイン button shows 認証サービス SnackBar when unconfigured',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(); // start SnackBar animation

    // Since Supabase is not configured in tests, a SnackBar is shown.
    expect(find.text('認証サービスが設定されていません'), findsOneWidget);
  });

  testWidgets('password visibility toggle icon is present', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Tap the visibility toggle
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
}
