// lib/services/badge_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for badge definitions and user badge awards.
class BadgeService {
  final SupabaseClient _client;

  BadgeService(this._client);

  /// Fetch all available badges.
  Future<List<Map<String, dynamic>>> getAllBadges() async {
    try {
      final response = await _client
          .from('badges')
          .select()
          .order('category');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('BadgeService.getAllBadges error: $e');
      return [];
    }
  }

  /// Fetch badges earned by a specific user.
  Future<List<Map<String, dynamic>>> getUserBadges(String userId) async {
    try {
      final response = await _client
          .from('user_badges')
          .select('*, badges(*)')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('BadgeService.getUserBadges error: $e');
      return [];
    }
  }

  /// Check and award badges based on current stats.
  /// Returns the list of newly awarded badge codes.
  Future<List<String>> checkAndAwardBadges(String userId) async {
    final awarded = <String>[];

    try {
      // Fetch user stats
      final visits = await _client
          .from('visits')
          .select('id')
          .eq('user_id', userId);
      final reviews = await _client
          .from('reviews')
          .select('id')
          .eq('user_id', userId);

      final visitCount = visits.length;
      final reviewCount = reviews.length;

      // Define badge rules
      final rules = <String, bool>{
        'first_visit': visitCount >= 1,
        'explorer_10': visitCount >= 10,
        'explorer_50': visitCount >= 50,
        'explorer_100': visitCount >= 100,
        'first_review': reviewCount >= 1,
        'reviewer_10': reviewCount >= 10,
        'reviewer_50': reviewCount >= 50,
      };

      // Fetch already-earned badges
      final earned = await _client
          .from('user_badges')
          .select('badges(code)')
          .eq('user_id', userId);

      final earnedCodes = earned
          .map<String>((row) =>
              (row['badges'] as Map<String, dynamic>?)?['code'] as String? ?? '')
          .toSet();

      // Award new badges
      for (final entry in rules.entries) {
        if (entry.value && !earnedCodes.contains(entry.key)) {
          // Look up the badge ID by code
          final badge = await _client
              .from('badges')
              .select('id')
              .eq('code', entry.key)
              .maybeSingle();

          if (badge != null) {
            await _client.from('user_badges').insert({
              'user_id': userId,
              'badge_id': badge['id'],
            });
            awarded.add(entry.key);
          }
        }
      }
    } catch (e) {
      debugPrint('BadgeService.checkAndAwardBadges error: $e');
    }

    return awarded;
  }
}
