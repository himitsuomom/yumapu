import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/domain/entities/facility.dart';

/// Handles all facility queries against Supabase.
///
/// Injected with a [SupabaseClient] so it can be mocked in tests.
/// Uses a `Map<String, dynamic>` cache keyed by facility ID.
class FacilityService {
  FacilityService(this._client);

  final SupabaseClient _client;

  // Raw JSON rows keyed by facility ID. Updated incrementally; never
  // cleared in full so that detail lookups survive between searches.
  final Map<String, dynamic> _cache = {};

  /// Unmodifiable view of the raw-row cache.
  Map<String, dynamic> get cache => Map.unmodifiable(_cache);

  // ── Public API ──────────────────────────────────────────────────────

  /// Search facilities.
  ///
  /// When [latitude], [longitude], and [radiusMeters] are provided the query
  /// delegates to the PostGIS RPC `get_facilities_in_bounds`.
  /// Otherwise a regular table query is built by chaining filters onto
  /// `var query` so that no filter is ever discarded.
  Future<List<Facility>> searchFacilities({
    String? searchQuery,
    String? prefectureId,
    String? facilityTypeId,
    List<String>? amenityIds,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    int page = 0,
  }) async {
    if (latitude != null && longitude != null && radiusMeters != null) {
      return _searchByBounds(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        amenityIds: amenityIds,
        facilityLimit: AppConstants.pageSize,
      );
    }

    var query = _client.from('facilities').select(
          'id, name, name_kana, latitude, longitude, address, phone, '
          'website, prefecture_id, facility_type_id, '
          'business_hours, price_info, data_source, data_quality_score',
        );

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('name', '%${searchQuery.trim()}%');
    }
    if (prefectureId != null) {
      query = query.eq('prefecture_id', prefectureId);
    }
    if (facilityTypeId != null) {
      query = query.eq('facility_type_id', facilityTypeId);
    }

    final from = page * AppConstants.pageSize;
    final to = from + AppConstants.pageSize - 1;
    final rows = await query
        .order('data_quality_score', ascending: false)
        .range(from, to) as List;

    if (amenityIds != null && amenityIds.isNotEmpty) {
      return _filterByAmenities(rows, amenityIds);
    }

    _updateCache(rows);
    return rows.map((r) => Facility.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Fetch a single facility by ID.
  ///
  /// Returns the cached value when available to avoid a round-trip.
  Future<Facility?> getFacilityById(String id) async {
    if (_cache.containsKey(id)) {
      return Facility.fromJson(_cache[id] as Map<String, dynamic>);
    }
    try {
      final row = await _client
          .from('facilities')
          .select(
            'id, name, name_kana, latitude, longitude, address, phone, '
            'website, prefecture_id, facility_type_id, '
            'business_hours, price_info, data_source, data_quality_score',
          )
          .eq('id', id)
          .single();
      _cache[id] = row;
      return Facility.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// Remove a single entry from the cache (e.g. after a user edit).
  void evict(String facilityId) => _cache.remove(facilityId);

  /// Clear the entire cache.
  void clearCache() => _cache.clear();

  // ── Private helpers ─────────────────────────────────────────────────

  /// Calls the PostGIS RPC to fetch facilities within a bounding box.
  Future<List<Facility>> _searchByBounds({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    List<String>? amenityIds,
    int facilityLimit = 500,
  }) async {
    final radiusDeg = radiusMeters / 111000.0;
    final rows = await _client.rpc(
      'get_facilities_in_bounds',
      params: {
        'min_lat': latitude - radiusDeg,
        'min_lng': longitude - radiusDeg / 0.7,
        'max_lat': latitude + radiusDeg,
        'max_lng': longitude + radiusDeg / 0.7,
        'filter_amenities':
            (amenityIds != null && amenityIds.isNotEmpty) ? amenityIds : null,
        'facility_limit': facilityLimit,
      },
    ) as List;

    _updateCache(rows);
    return rows.map((r) => Facility.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Post-filters a list of raw rows to keep only those that have ALL of
  /// the requested amenity IDs in `facility_amenities`.
  Future<List<Facility>> _filterByAmenities(
    List<dynamic> rows,
    List<String> amenityIds,
  ) async {
    if (rows.isEmpty) return [];

    final facilityIds = rows.map((r) => r['id'] as String).toList();
    final amenityRows = await _client
        .from('facility_amenities')
        .select('facility_id, amenity_id')
        .inFilter('facility_id', facilityIds)
        .inFilter('amenity_id', amenityIds) as List;

    // Build a map of facilityId → set of matched amenity IDs.
    final Map<String, Set<String>> facilityAmenities = {};
    for (final row in amenityRows) {
      final fid = row['facility_id'] as String;
      final aid = row['amenity_id'] as String;
      facilityAmenities.putIfAbsent(fid, () => {}).add(aid);
    }

    final required = amenityIds.toSet();
    final filtered = rows.where((row) {
      final has = facilityAmenities[row['id'] as String] ?? const <String>{};
      return has.containsAll(required);
    }).toList();

    _updateCache(filtered);
    return filtered.map((r) => Facility.fromJson(r as Map<String, dynamic>)).toList();
  }

  void _updateCache(List<dynamic> rows) {
    for (final row in rows) {
      _cache[row['id'] as String] = row;
    }
  }
}
