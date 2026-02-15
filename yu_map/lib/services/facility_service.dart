// lib/services/facility_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/utils/query_utils.dart';
import 'package:yu_map/domain/entities/facility.dart';

/// Cache entry with expiration support.
class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  _CacheEntry(this.value, Duration ttl)
      : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class FacilityService {
  final SupabaseClient _client;

  FacilityService(this._client);

  // LRU-style cache with TTL and size limit
  static const int _maxCacheSize = 200;
  static const Duration _cacheTtl = Duration(minutes: 10);
  final Map<String, _CacheEntry<Map<String, dynamic>>> _cache = {};

  /// Returns an unmodifiable view of current (non-expired) cache keys.
  Map<String, Map<String, dynamic>> get cache {
    _evictExpired();
    return Map.unmodifiable(
      _cache.map((key, entry) => MapEntry(key, entry.value)),
    );
  }

  /// Removes expired entries from the cache.
  void _evictExpired() {
    _cache.removeWhere((_, entry) => entry.isExpired);
  }

  /// Ensures the cache does not exceed [_maxCacheSize].
  /// Removes the oldest entries first when the limit is reached.
  void _enforceCacheLimit() {
    while (_cache.length > _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Adds a single entry to the cache with TTL and size enforcement.
  void _cacheEntry(String key, Map<String, dynamic> value) {
    _cache[key] = _CacheEntry(value, _cacheTtl);
    _enforceCacheLimit();
  }

  /// Clears the entire cache.
  void clearCache() {
    _cache.clear();
  }

  Future<List<Facility>> searchFacilities({
    String? searchQuery,
    String? prefectureId,
    String? facilityTypeId,
    Map<String, bool>? attributes,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    var query = _client
        .from('facilities')
        .select('''
          id, 
          name, 
          name_kana,
          google_place_id,
          latitude, 
          longitude, 
          address,
          phone,
          website,
          business_hours,
          price_info,
          data_source,
          data_quality_score,
          prefecture_id, 
          facility_type_id,
          amenities
        ''');

    // Apply search string with sanitized input
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final sanitized = sanitizeLikeInput(searchQuery);
      query = query.ilike('name', '%$sanitized%');
    }

    // Apply location filters
    if (prefectureId != null) {
      query = query.eq('prefecture_id', prefectureId);
    }

    if (facilityTypeId != null) {
      query = query.eq('facility_type_id', facilityTypeId);
    }

    // Apply attribute filters (Tattoo, Sauna, etc.)
    if (attributes != null) {
      for (final entry in attributes.entries) {
        if (entry.value) {
          query = query.contains('amenities', {entry.key: true});
        }
      }
    }

    // Apply geolocation bounding box filter
    if (latitude != null && longitude != null && radius != null) {
      query = query
          .lte('latitude', latitude + radius / 111.0)
          .gte('latitude', latitude - radius / 111.0)
          .lte('longitude', longitude + radius / (111.0 * 0.7))
          .gte('longitude', longitude - radius / (111.0 * 0.7));
    }

    final response = await query;

    // Update cache with results (additive, not destructive)
    _evictExpired();
    for (final row in response) {
      final id = row['id'] as String?;
      if (id != null) {
        _cacheEntry(id, row);
      }
    }

    return response.map((row) => Facility.fromJson(row)).toList();
  }

  Future<List<Facility>> getFilteredFacilities({
    String? searchTerm,
    Map<String, dynamic>? filters,
  }) async {
    var query = _client
        .from('facilities')
        .select('''
          id, name, name_kana, google_place_id,
          latitude, longitude, address, phone, website,
          business_hours, price_info, data_source, data_quality_score,
          prefecture_id, facility_type_id, amenities
        ''');

    // Apply search term with sanitized input
    if (searchTerm != null && searchTerm.trim().isNotEmpty) {
      final sanitized = sanitizeLikeInput(searchTerm.trim());
      query = query.ilike('name', '%$sanitized%');
    }

    // Apply filters conditionally
    if (filters != null) {
      for (final entry in filters.entries) {
        if (entry.value != null) {
          if (entry.key == 'amenities') {
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

  Future<Facility?> getFacilityById(String id) async {
    // Check cache first (with TTL validation)
    final cached = _cache[id];
    if (cached != null && !cached.isExpired) {
      return Facility.fromJson(cached.value);
    }

    // Remove expired entry if present
    if (cached != null) {
      _cache.remove(id);
    }

    final response = await _client
        .from('facilities')
        .select('''
          id, name, name_kana, google_place_id,
          latitude, longitude, address, phone, website,
          business_hours, price_info, data_source, data_quality_score,
          prefecture_id, facility_type_id, amenities
        ''')
        .eq('id', id)
        .single();

    _cacheEntry(id, response);
    return Facility.fromJson(response);
  }
}
