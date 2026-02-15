// lib/services/favorite_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';

/// Service for managing user's favorite facilities.
class FavoriteService {
  final SupabaseClient _client;

  FavoriteService(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  /// Add a facility to favorites.
  Future<void> addFavorite(String facilityId) async {
    if (_userId == null) throw StateError('Not authenticated');

    try {
      await _client.from('favorites').insert({
        'user_id': _userId,
        'facility_id': facilityId,
      });
    } on PostgrestException catch (e) {
      // Ignore duplicate
      if (e.code != '23505') rethrow;
    }
  }

  /// Remove a facility from favorites.
  Future<void> removeFavorite(String facilityId) async {
    if (_userId == null) throw StateError('Not authenticated');

    await _client
        .from('favorites')
        .delete()
        .eq('user_id', _userId!)
        .eq('facility_id', facilityId);
  }

  /// Check if a facility is in the user's favorites.
  Future<bool> isFavorite(String facilityId) async {
    if (_userId == null) return false;

    final response = await _client
        .from('favorites')
        .select('id')
        .eq('user_id', _userId!)
        .eq('facility_id', facilityId);

    return response.isNotEmpty;
  }

  /// Get all favorite facilities for the current user.
  Future<List<Facility>> getFavorites() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('favorites')
          .select('facilities(*)')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      return response.map<Facility>((row) {
        final facilityData = row['facilities'] as Map<String, dynamic>;
        return Facility.fromJson(facilityData);
      }).toList();
    } catch (e) {
      debugPrint('FavoriteService.getFavorites error: $e');
      return [];
    }
  }
}
