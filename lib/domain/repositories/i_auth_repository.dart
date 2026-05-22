// lib/domain/repositories/i_auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/domain/entities/user.dart' as app;

abstract interface class IAuthRepository {
  Session? get currentSession;
  Stream<AuthState> watchAuthState();
  Future<Result<Session>> signInWithEmail(
      {required String email, required String password});
  Future<Result<Session?>> signUpWithEmail(
      {required String email, required String password});
  Future<Result<void>> signOut();
  Future<Result<void>> resetPassword(String email);
  Future<Result<void>> deleteAccount();
  Future<Result<app.User?>> getCurrentUserProfile();
  Future<Result<bool>> isAdmin();
  Future<Result<bool>> isApprovedOwner(String facilityId);
}
