// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/user.dart' as app;

/// Service layer wrapping Supabase Auth operations.
class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  /// Current Supabase auth user (null when signed out).
  User? get currentUser => _client.auth.currentUser;

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => currentUser != null;

  /// Stream of auth state changes (sign-in / sign-out / token-refresh).
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ──────────────────────────────────────────────
  // Email / Password
  // ──────────────────────────────────────────────

  /// Register a new user with email & password.
  /// Creates the auth user and inserts a matching row in the public `users` table.
  Future<app.User> signUpWithEmail({
    required String email,
    required String password,
    String? username,
    String? displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw AuthException('Sign-up failed: no user returned.');
    }

    // Insert the public profile row.
    await _client.from('users').upsert({
      'id': user.id,
      'email': email,
      'username': username,
      'display_name': displayName ?? username,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    return app.User(
      id: user.id,
      email: email,
      username: username,
      displayName: displayName ?? username,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Sign in with an existing email & password.
  Future<app.User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw AuthException('Sign-in failed: no user returned.');
    }

    return _fetchProfile(user.id);
  }

  // ──────────────────────────────────────────────
  // OAuth (Google / Apple / Twitter)
  // ──────────────────────────────────────────────

  /// Sign in with a third-party OAuth provider.
  Future<void> signInWithOAuth(OAuthProvider provider) async {
    await _client.auth.signInWithOAuth(
      provider,
      redirectTo: 'io.supabase.yumap://login-callback/',
    );
  }

  // ──────────────────────────────────────────────
  // Session helpers
  // ──────────────────────────────────────────────

  /// Fetch the public profile for the currently signed-in user.
  Future<app.User?> fetchCurrentProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    try {
      return await _fetchProfile(uid);
    } catch (e) {
      debugPrint('AuthService.fetchCurrentProfile error: $e');
      return null;
    }
  }

  /// Update the public profile fields.
  Future<void> updateProfile({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');

    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (bio != null) updates['bio'] = bio;

    if (updates.isNotEmpty) {
      await _client.from('users').update(updates).eq('id', uid);
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Send a password-reset email.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ──────────────────────────────────────────────
  // Internal
  // ──────────────────────────────────────────────

  Future<app.User> _fetchProfile(String userId) async {
    final data = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    return app.User.fromJson(data);
  }
}
