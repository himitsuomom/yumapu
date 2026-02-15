// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  /// Correctly handles .contains() for joined relationship data
  /// Instead of using .contains() incorrectly on joined tables,
  /// we use proper PostgREST syntax with .filter()
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

    // Apply name filter if provided
    if (nameContains != null && nameContains.isNotEmpty) {
      query = query.ilike('name', '%$nameContains%');
    }

    // Apply location filters
    if (prefectureId != null) {
      query = query.eq('prefecture_id', prefectureId);
    }

    if (facilityTypeId != null) {
      query = query.eq('facility_type_id', facilityTypeId);
    }

    // Apply amenities filter using correct PostgREST syntax
    if (requiredAmenities != null && requiredAmenities.isNotEmpty) {
      // Method 1: Using PostgREST's filter functionality
      for (String amenity in requiredAmenities) {
        // For JSONB columns like 'amenities', use proper Supabase syntax
        query = query.contains('amenities', {amenity: true});
        
        // Alternative approach (more reliable for complex relationships):
        // We can join with the facility_amenities table if needed
        // query = query.filter('facility_amenities.amenity_name', 'eq', amenity)
        //              .filter('facility_amenities.is_available', 'eq', true);
      }
    }

    final response = await query;
    return response;
  }

  /// Alternative method for handling complex relationship searches
  /// This properly joins and filters related data
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