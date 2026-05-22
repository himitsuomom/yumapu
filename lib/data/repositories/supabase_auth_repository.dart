// lib/data/repositories/supabase_auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/domain/repositories/i_auth_repository.dart';

class SupabaseAuthRepository implements IAuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Stream<AuthState> watchAuthState() => _client.auth.onAuthStateChange;

  @override
  Future<Result<Session>> signInWithEmail(
          {required String email, required String password}) =>
      runCatching(() async {
        final res = await _client.auth
            .signInWithPassword(email: email, password: password);
        if (res.session == null) throw const InvalidCredentialsException();
        return res.session!;
      });

  @override
  Future<Result<Session?>> signUpWithEmail(
          {required String email, required String password}) =>
      runCatching(() async {
        final res = await _client.auth.signUp(email: email, password: password);
        return res.session;
      });

  @override
  Future<Result<void>> signOut() => runCatching(_client.auth.signOut);

  @override
  Future<Result<void>> resetPassword(String email) =>
      runCatching(() => _client.auth.resetPasswordForEmail(email));

  @override
  Future<Result<void>> deleteAccount() => runCatching(() async {
        await _client.rpc('delete_user_account');
        await _client.auth.signOut();
      });

  @override
  Future<Result<app.User?>> getCurrentUserProfile() => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return null;
        final data = await _client
            .from('users')
            .select()
            .eq('id', session.user.id)
            .maybeSingle();
        return data == null ? null : app.User.fromJson(data);
      });

  @override
  Future<Result<bool>> isAdmin() => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return false;
        final data = await _client
            .from('users')
            .select('is_admin')
            .eq('id', session.user.id)
            .maybeSingle();
        return (data?['is_admin'] as bool?) ?? false;
      });

  @override
  Future<Result<bool>> isApprovedOwner(String facilityId) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return false;
        final data = await _client
            .from('owner_registrations')
            .select('id')
            .eq('facility_id', facilityId)
            .eq('user_id', session.user.id)
            .eq('status', 'approved')
            .maybeSingle();
        return data != null;
      });
}
