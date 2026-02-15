// lib/services/user_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/domain/entities/user_ranking.dart';

/// Service for user profile and ranking operations.
class UserService {
  final SupabaseClient _client;

  UserService(this._client);

  /// Fetch a user profile by ID.
  Future<app.User> getUserById(String userId) async {
    final data = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    return app.User.fromJson(data);
  }

  /// Update profile fields for the current user.
  Future<app.User> updateProfile({
    required String userId,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async {
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (bio != null) updates['bio'] = bio;

    final response = await _client
        .from('users')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return app.User.fromJson(response);
  }

  /// Fetch the ranking for a specific user.
  Future<UserRanking?> getUserRanking(String userId) async {
    try {
      final data = await _client
          .from('user_rankings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) return null;
      return UserRanking.fromJson(data);
    } catch (e) {
      debugPrint('UserService.getUserRanking error: $e');
      return null;
    }
  }

  /// Fetch the global leaderboard.
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 50}) async {
    final response = await _client
        .from('user_rankings')
        .select('*, users(username, display_name, avatar_url)')
        .order('total_points', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get the count of visits for a user.
  Future<int> getVisitCount(String userId) async {
    final response = await _client
        .from('visits')
        .select('id')
        .eq('user_id', userId);

    return response.length;
  }

  /// Get the count of reviews for a user.
  Future<int> getReviewCount(String userId) async {
    final response = await _client
        .from('reviews')
        .select('id')
        .eq('user_id', userId);

    return response.length;
  }
}
