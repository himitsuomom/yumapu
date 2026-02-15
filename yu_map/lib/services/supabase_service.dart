// lib/services/supabase_service.dart
//
// NOTE: This service is superseded by FacilityService which provides
// the same functionality plus caching. Kept for backwards compatibility
// and potential future use with complex join queries.
// Consider removing if no longer referenced.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/utils/query_utils.dart';

@Deprecated('Use FacilityService instead for facility searches with caching.')
class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  /// Searches facilities with amenity filters using correct PostgREST syntax.
  Future<List<Map<String, dynamic>>> searchFacilitiesWithAmenities({
    String? nameContains,
    List<String>? requiredAmenities,
    String? prefectureId,
    String? facilityTypeId,
  }) async {
    var query = _client
        .from('facilities')
        .select('''
          id, 
          name, 
          latitude, 
          longitude, 
          prefecture_id, 
          facility_type_id,
          amenities,
          facility_amenities (
            amenity_id,
            is_available
          )
        ''');

    // Apply name filter with sanitized input
    if (nameContains != null && nameContains.isNotEmpty) {
      final sanitized = sanitizeLikeInput(nameContains);
      query = query.ilike('name', '%$sanitized%');
    }

    // Apply location filters
    if (prefectureId != null) {
      query = query.eq('prefecture_id', prefectureId);
    }

    if (facilityTypeId != null) {
      query = query.eq('facility_type_id', facilityTypeId);
    }

    // Apply amenities filter using correct PostgREST / JSONB syntax
    if (requiredAmenities != null && requiredAmenities.isNotEmpty) {
      for (final amenity in requiredAmenities) {
        query = query.contains('amenities', {amenity: true});
      }
    }

    final response = await query;
    return response;
  }

  /// Searches facilities with complex filters using inner joins.
  Future<List<Map<String, dynamic>>> searchFacilitiesWithComplexFilters({
    Map<String, dynamic>? filters,
  }) async {
    var query = _client
        .from('facilities')
        .select('''
          id, 
          name, 
          latitude, 
          longitude, 
          prefecture_id, 
          facility_type_id,
          amenities,
          facility_amenities!inner (
            amenity_id,
            is_available
          )
        ''');

    if (filters != null) {
      for (final entry in filters.entries) {
        final key = entry.key;
        final value = entry.value;

        if (key.startsWith('amenity_') && value == true) {
          final amenityName = key.substring(8); // Remove 'amenity_' prefix
          query = query.contains('amenities', {amenityName: true});
        } else {
          if (value != null) {
            query = query.eq(key, value);
          }
        }
      }
    }

    final response = await query;
    return response;
  }
}
