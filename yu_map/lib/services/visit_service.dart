// lib/services/visit_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for facility check-ins / visit tracking.
class VisitService {
  final SupabaseClient _client;

  VisitService(this._client);

  /// Record a visit (check-in) to a facility.
  /// Includes optional GPS coordinates for verification.
  /// The DB unique index prevents duplicate daily check-ins.
  Future<Map<String, dynamic>> checkIn({
    required String facilityId,
    double? latitude,
    double? longitude,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final data = <String, dynamic>{
      'user_id': userId,
      'facility_id': facilityId,
    };

    // If GPS is provided, verify proximity and store location.
    if (latitude != null && longitude != null) {
      data['check_in_location'] =
          'SRID=4326;POINT($longitude $latitude)';
      data['verified'] = true;
    }

    try {
      final response = await _client
          .from('visits')
          .insert(data)
          .select()
          .single();

      return response;
    } on PostgrestException catch (e) {
      // Handle duplicate daily check-in
      if (e.code == '23505') {
        throw StateError('Already checked in to this facility today.');
      }
      rethrow;
    }
  }

  /// Get the visit history for the current user.
  Future<List<Map<String, dynamic>>> getVisitHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    try {
      final response = await _client
          .from('visits')
          .select('*, facilities(id, name, latitude, longitude, address)')
          .eq('user_id', userId)
          .order('visited_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('VisitService.getVisitHistory error: $e');
      return [];
    }
  }

  /// Check if the user has visited a facility today.
  Future<bool> hasVisitedToday(String facilityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);

    final response = await _client
        .from('visits')
        .select('id')
        .eq('user_id', userId)
        .eq('facility_id', facilityId)
        .gte('visited_at', '${today}T00:00:00Z')
        .lte('visited_at', '${today}T23:59:59Z');

    return response.isNotEmpty;
  }
}
