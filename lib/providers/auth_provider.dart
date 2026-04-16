import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/services/analytics_service.dart';

/// Supabase client — null when Supabase is not configured.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppConfig.isSupabaseConfigured) return null;
  return Supabase.instance.client;
});

/// Auth state stream from Supabase.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const Stream.empty();
  return client.auth.onAuthStateChange;
});

/// Current Supabase session — null when not signed in or unconfigured.
///
/// Also watches [authStateProvider] so it rebuilds whenever the auth state
/// stream fires (e.g. after sign-in / sign-out).
final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider); // reactive to auth state changes
  final client = ref.watch(supabaseClientProvider);
  return client?.auth.currentSession;
});

/// Whether the user is currently signed in.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider) != null;
});

/// ゲストモード（ログインせずに地図・施設閲覧を許可するフラグ）。
/// "ゲストとして閲覧する" ボタンで true になる。
/// ログインすると不要だが、ログアウトしても true のままになる（再起動でリセット）。
final guestModeProvider = StateProvider<bool>((ref) => false);

/// Current user profile from the `users` table.
final currentUserProfileProvider =
    FutureProvider.autoDispose<app.User?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  final client = ref.read(supabaseClientProvider);
  if (client == null) return null;
  try {
    final data = await client
        .from('users')
        .select()
        .eq('id', session.user.id)
        .maybeSingle();
    if (data == null) return null;
    return app.User.fromJson(data);
  } catch (_) {
    return null;
  }
});

// ── Auth actions ────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._client) : super(const AsyncData(null));

  final SupabaseClient? _client;

  Future<void> signInWithEmail(String email, String password) async {
    if (_client == null) {
      state = AsyncError('Supabase is not configured.', StackTrace.current);
      return;
    }
    state = const AsyncLoading();
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      AnalyticsService.instance.logLogin();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    if (_client == null) {
      state = AsyncError('Supabase is not configured.', StackTrace.current);
      return;
    }
    state = const AsyncLoading();
    try {
      await _client.auth.signUp(email: email, password: password);
      AnalyticsService.instance.logSignUp();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signOut() async {
    if (_client == null) return;
    state = const AsyncLoading();
    try {
      await _client.auth.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> resetPassword(String email) async {
    if (_client == null) {
      state = AsyncError('Supabase is not configured.', StackTrace.current);
      return;
    }
    state = const AsyncLoading();
    try {
      await _client.auth.resetPasswordForEmail(email);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.read(supabaseClientProvider));
});
