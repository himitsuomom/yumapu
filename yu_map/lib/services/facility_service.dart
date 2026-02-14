// lib/services/facility_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';

class FacilityService {
  final SupabaseClient _client;

  FacilityService(this._client);

  // Cache for facilities to improve performance
  final Map<String, dynamic> _cache = {};
  
  // Getter to access cache safely
  Map<String, dynamic> get cache => Map.unmodifiable(_cache);

  Future<List<Facility>> searchFacilities({
    String? searchQuery,
    String? prefectureId,
    String? facilityTypeId,
    Map<String, bool>? attributes, // e.g., {'tattoo': true, 'sauna': true}
    double? latitude,
    double? longitude,
    double? radius,
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
          amenities
        ''');

    // Apply search string if provided
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('name', '%$searchQuery%');
    }

    // Apply location filters if provided (without discarding attribute filters)
    if (prefectureId != null) {
      query = query.eq('prefecture_id', prefectureId);
    }

    if (facilityTypeId != null) {
      query = query.eq('facility_type_id', facilityTypeId);
    }

    // Apply attribute filters (Tattoo, Sauna, etc.) - ensure they persist
    if (attributes != null) {
      for (final entry in attributes.entries) {
        if (entry.value) { // Only apply if attribute is true
          // For amenities stored as JSONB in Supabase
          query = query.contains('amenities', {entry.key: true});
        }
      }
    }

    // Apply geolocation filter if provided
    if (latitude != null && longitude != null && radius != null) {
      // Note: Actual geolocation filtering may require postgis functions
      // This is a simplified version
      query = query.lte('latitude', latitude + radius / 111.0)
                  .gte('latitude', latitude - radius / 111.0)
                  .lte('longitude', longitude + radius / (111.0 * 0.7)) // Approximate for Japan's latitude
                  .gte('longitude', longitude - radius / (111.0 * 0.7));
    }

    final response = await query;
    
    // Update cache with results
    _cache.clear(); // Clear old cache
    for (final row in response) {
      _cache[row['id']] = row;
    }

    return response.map((row) => Facility.fromJson(row)).toList();
  }

  // Updated method that properly chains queries without reassignment
  Future<List<Facility>> getFilteredFacilities({
    String? searchTerm,
    Map<String, dynamic>? filters,
  }) async {
    // Start with a base query
    var query = _client
        .from('facilities')
        .select('id, name, latitude, longitude, prefecture_id, facility_type_id, amenities');

    // Apply search term if provided
    if (searchTerm != null && searchTerm.trim().isNotEmpty) {
      query = query.ilike('name', '%$searchTerm%');
    }

    // Apply filters conditionally - this ensures all filters are maintained
    if (filters != null) {
      for (final entry in filters.entries) {
        if (entry.value != null) {
          if (entry.key == 'amenities') {
            // For amenity filters, use the correct Supabase syntax
            if (entry.value is Map<String, bool>) {
              final amenityFilters = entry.value as Map<String, bool>;
              for (final amenityEntry in amenityFilters.entries) {
                if (amenityEntry.value) {
                  query = query.contains('amenities', {amenityEntry.key: true});
                }
              }
            }
          } else {
            query = query.eq(entry.key, entry.value);
          }
        }
      }
    }

    final response = await query;
    return response.map((row) => Facility.fromJson(row)).toList();
  }

  // Simplified redundant null coalescing (fixed)
  Future<Facility?> getFacilityById(String id) async {
    if (_cache.containsKey(id)) {
      final cachedData = _cache[id];
      // Validate the cached data before using it to avoid runtime errors
      if (cachedData is Map<String, dynamic> && cachedData.containsKey('id')) {
        return Facility.fromJson(cachedData);
      } else {
        // If cached data is invalid, remove it and fetch fresh data
        _cache.remove(id);
      }
    }

    final response = await _client
        .from('facilities')
        .select('id, name, latitude, longitude, prefecture_id, facility_type_id, amenities')
        .eq('id', id)
        .single();

    // Validate the response before caching
    if (response is Map<String, dynamic> && response.containsKey('id')) {
      _cache[id] = response;
      return Facility.fromJson(response);
    }

    return null; // Return null if response is not valid
  }
}