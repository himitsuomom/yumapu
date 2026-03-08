import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/services/analytics_service.dart';

/// Exposes the Supabase client instance.
/// Returns null-safe: only usable when Supabase is configured.
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

/// Current Supabase session (nullable).
final sessionProvider = Provider<Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return client.auth.currentSession;
});

/// Whether the user is currently signed in.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider) != null;
});

/// Current app user profile loaded from the users table.
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

/// Auth actions (sign in, sign up, sign out).
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._client) : super(const AsyncData(null));
  final SupabaseClient _client;

  Future<void> signInWithEmail(String email, String password) async {
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
    state = const AsyncLoading();
    try {
      await _client.auth.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> resetPassword(String email) async {
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
  final client = ref.read(supabaseClientProvider);
  if (client == null) {
    throw StateError('Supabase is not configured. Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.');
  }
  return AuthNotifier(client);
});
