// lib/providers/auth_providers.dart
//
// Auth-related state providers using Riverpod.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/providers/service_providers.dart';

/// Stream of Supabase auth-state changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Whether the user is currently signed in.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
        data: (state) => state.session != null,
      ) ??
      false;
});

/// The currently signed-in user's public profile.
/// Re-fetched whenever the auth state changes.
final currentUserProfileProvider = FutureProvider<app.User?>((ref) async {
  // Re-evaluate whenever auth state changes
  ref.watch(authStateProvider);

  final authService = ref.watch(authServiceProvider);
  if (!authService.isAuthenticated) return null;

  return authService.fetchCurrentProfile();
});

/// Notifier for auth actions (sign-in, sign-up, sign-out).
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref.read(authServiceProvider).signInWithEmail(
            email: email,
            password: password,
          );
    });
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? username,
    String? displayName,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref.read(authServiceProvider).signUpWithEmail(
            email: email,
            password: password,
            username: username,
            displayName: displayName,
          );
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref.read(authServiceProvider).signOut();
    });
  }

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref.read(authServiceProvider).signInWithOAuth(provider);
    });
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(ref),
);
