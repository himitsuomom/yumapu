// lib/data/repositories/supabase_facility_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/domain/repositories/i_facility_repository.dart';

class SupabaseFacilityRepository implements IFacilityRepository {
  SupabaseFacilityRepository(this._client);
  final SupabaseClient _client;

  // In-memory cache keyed by facility ID
  final Map<String, dynamic> _cache = {};

  static const _selectFields =
      'id, name, name_kana, latitude, longitude, address, phone, '
      'website, prefecture_id, facility_type_id, '
      'facility_types(code), '
      'business_hours, price_info, data_source, data_quality_score';

  @override
  Future<Result<List<Facility>>> searchFacilities({
    String? searchQuery,
    String? prefectureId,
    String? facilityTypeId,
    List<String>? amenityIds,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    int page = 0,
    FacilitySortByRepo sortBy = FacilitySortByRepo.qualityScore,
  }) =>
      runCatching(() async {
        // Geo-bounded search via PostGIS RPC
        if (latitude != null && longitude != null && radiusMeters != null) {
          final radiusDeg = radiusMeters / 111000.0;
          final rows = await _client.rpc(
            'get_facilities_in_bounds',
            params: {
              'min_lat': latitude - radiusDeg,
              'min_lng': longitude - radiusDeg / 0.7,
              'max_lat': latitude + radiusDeg,
              'max_lng': longitude + radiusDeg / 0.7,
              'filter_amenities':
                  (amenityIds != null && amenityIds.isNotEmpty)
                      ? amenityIds
                      : null,
              'facility_limit': 500,
              'filter_facility_type': facilityTypeId,
            },
          ) as List;

          _updateCache(rows);

          var results = rows
              .map((r) => Facility.fromJson(r as Map<String, dynamic>))
              .toList();

          // Client-side text filter for geo-bounded results
          if (searchQuery != null && searchQuery.trim().isNotEmpty) {
            final q = searchQuery.trim().toLowerCase();
            results = results.where((f) {
              final nameMatch = f.displayName.toLowerCase().contains(q) ||
                  f.name.toLowerCase().contains(q);
              final addressMatch =
                  (f.address ?? '').toLowerCase().contains(q);
              return nameMatch || addressMatch;
            }).toList();
          }
          return results;
        }

        // Standard table query
        var query = _client.from('facilities').select(_selectFields);

        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final q = searchQuery.trim();
          query = query.or('name.ilike.%$q%,address.ilike.%$q%');
        }
        if (prefectureId != null) {
          query = query.eq('prefecture_id', prefectureId);
        }
        if (facilityTypeId != null) {
          query = query.eq('facility_type_id', facilityTypeId);
        }

        const pageSize = 50;
        final from = page * pageSize;
        final to = from + pageSize - 1;

        final sortField =
            sortBy == FacilitySortByRepo.qualityScore
                ? 'data_quality_score'
                : 'name_kana';
        final ascending = sortBy != FacilitySortByRepo.qualityScore;

        final rows = await query
            .order(sortField, ascending: ascending)
            .range(from, to) as List;

        _updateCache(rows);

        if (amenityIds != null && amenityIds.isNotEmpty) {
          return _filterByAmenities(rows, amenityIds);
        }

        return rows
            .map((r) => Facility.fromJson(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<Result<Facility?>> getFacilityById(String id) =>
      runCatching(() async {
        if (_cache.containsKey(id)) {
          return Facility.fromJson(_cache[id] as Map<String, dynamic>);
        }
        final row = await _client
            .from('facilities')
            .select(
              'id, name, name_kana, latitude, longitude, address, phone, '
              'website, prefecture_id, facility_type_id, '
              'facility_types(code), '
              'business_hours, price_info, hours, price, '
              'data_source, data_quality_score',
            )
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        _cache[id] = row;
        return Facility.fromJson(row);
      });

  @override
  Future<Result<List<Facility>>> getTrendingFacilities({int limit = 20}) =>
      runCatching(() async {
        // Try trending (check-in based) first
        final rows = await _client.rpc(
          'get_trending_facilities',
          params: {'days_ago': 30, 'limit_count': limit},
        ) as List;

        if (rows.isNotEmpty) {
          return rows
              .map((r) => Facility.fromJson(r as Map<String, dynamic>))
              .toList();
        }

        // Fallback to quality score
        final fallbackRows = await _client.rpc(
          'get_popular_facilities_no_visits',
          params: {'limit_count': limit},
        ) as List;

        return fallbackRows
            .map((r) => Facility.fromJson(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<Result<Map<String, dynamic>>> getReviewSummary(
          String facilityId) =>
      runCatching(() async {
        try {
          final result = await _client.rpc(
            'get_facility_review_summary',
            params: {'p_facility_id': facilityId},
          );
          if (result == null) return {'count': 0, 'avg_rating': 0.0};
          return Map<String, dynamic>.from(result as Map);
        } catch (_) {
          // Fallback: count + avg separately
          final countResponse = await _client
              .from('reviews')
              .select()
              .eq('facility_id', facilityId)
              .count();
          final count = countResponse.count;
          double avg = 0.0;
          if (count > 0) {
            final avgResult = await _client.rpc(
              'get_facility_avg_rating',
              params: {'p_facility_id': facilityId},
            );
            avg = avgResult == null
                ? 0.0
                : double.tryParse(avgResult.toString()) ?? 0.0;
          }
          return {'count': count, 'avg_rating': avg};
        }
      });

  @override
  Future<Result<void>> updateFacility(
          String facilityId, Map<String, dynamic> patch) =>
      runCatching(() async {
        await _client
            .from('facilities')
            .update(patch)
            .eq('id', facilityId);
        _cache.remove(facilityId);
      });

  @override
  void clearCache() => _cache.clear();

  // ── Private helpers ────────────────────────────────────────────────

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

    final Map<String, Set<String>> facilityAmenities = {};
    for (final row in amenityRows) {
      final fid = row['facility_id'] as String;
      final aid = row['amenity_id'] as String;
      facilityAmenities.putIfAbsent(fid, () => {}).add(aid);
    }

    final required = amenityIds.toSet();
    return rows
        .where((row) {
          final has =
              facilityAmenities[row['id'] as String] ?? const <String>{};
          return has.containsAll(required);
        })
        .map((r) => Facility.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  void _updateCache(List<dynamic> rows) {
    for (final row in rows) {
      _cache[row['id'] as String] = row;
    }
  }
}
