// lib/services/facility_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/facility.dart';

class FacilityService {
  final SupabaseClient _client;

  FacilityService(this._client);

  /// Fetch facilities within a bounding box
  Future<List<Facility>> getFacilitiesInBounds({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    List<String>? facilityTypes,
    int limit = 500,
  }) async {
    try {
      final response = await _client
          .rpc('get_facilities_in_bounds', params: {
            'min_lat': minLat,
            'min_lng': minLng,
            'max_lat': maxLat,
            'max_lng': maxLng,
            'filter_amenities': facilityTypes,
            'facility_limit': limit,
          })
          .select();

      return response
          .map<Facility>((json) => Facility.fromJson({
                'id': json['id'],
                'name': json['name'],
                'lat': json['lat'],
                'lng': json['lng'],
                'data_quality_score': json['data_quality_score'],
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch facilities in bounds: $e');
    }
  }

  /// Get a single facility by ID
  Future<Facility?> getFacilityById(String id) async {
    try {
      final response = await _client
          .from('facilities')
          .select()
          .eq('id', id)
          .single();

      // Extract coordinates from the location field (PostGIS point)
      final lat = response['location']['coordinates'][1];
      final lng = response['location']['coordinates'][0];

      return Facility.fromJson({
        ...response,
        'lat': lat,
        'lng': lng,
        'id': response['id'],
        'name': response['name'],
        'address': response['address'],
        'phone': response['phone'],
        'website': response['website'],
      });
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST116') {
        // No rows returned
        return null;
      }
      throw Exception('Failed to fetch facility: $e');
    }
  }

  /// Search facilities by name or other criteria
  Future<List<Facility>> searchFacilities({
    required String query,
    String? prefectureId,
    String? facilityTypeId,
    double? minLatitude,
    double? maxLatitude,
    double? minLongitude,
    double? maxLongitude,
    int limit = 50,
  }) async {
    try {
      var queryBuilder = _client
          .from('facilities')
          .select(
              '*, prefecture:prefectures(name), type:facility_types(code, name_ja)')
          .ilike('name', '%$query%')
          .limit(limit);

      if (prefectureId != null) {
        queryBuilder = queryBuilder.eq('prefecture_id', prefectureId);
      }

      if (facilityTypeId != null) {
        queryBuilder = queryBuilder.eq('facility_type_id', facilityTypeId);
      }

      if (minLatitude != null && maxLatitude != null &&
          minLongitude != null && maxLongitude != null) {
        queryBuilder = queryBuilder.overlaps(
          'location',
          {
            'type': 'Polygon',
            'coordinates': [
              [
                [minLongitude, minLatitude],
                [maxLongitude, minLatitude],
                [maxLongitude, maxLatitude],
                [minLongitude, maxLatitude],
                [minLongitude, minLatitude],
              ]
            ],
          },
        );
      }

      final response = await queryBuilder;

      return response
          .map<Facility>((json) => Facility.fromJson({
                ...json,
                'lat': json['location']['coordinates'][1],
                'lng': json['location']['coordinates'][0],
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to search facilities: $e');
    }
  }

  /// Get facilities by type
  Future<List<Facility>> getFacilitiesByType(String typeId, {int limit = 100}) async {
    try {
      final response = await _client
          .from('facilities')
          .select('*, location')
          .eq('facility_type_id', typeId)
          .limit(limit);

      return response
          .map<Facility>((json) => Facility.fromJson({
                ...json,
                'lat': json['location']['coordinates'][1],
                'lng': json['location']['coordinates'][0],
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch facilities by type: $e');
    }
  }

  /// Get facilities by prefecture
  Future<List<Facility>> getFacilitiesByPrefecture(String prefectureId, {int limit = 100}) async {
    try {
      final response = await _client
          .from('facilities')
          .select('*, location')
          .eq('prefecture_id', prefectureId)
          .limit(limit);

      return response
          .map<Facility>((json) => Facility.fromJson({
                ...json,
                'lat': json['location']['coordinates'][1],
                'lng': json['location']['coordinates'][0],
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch facilities by prefecture: $e');
    }
  }

  /// Get nearby facilities
  Future<List<Facility>> getNearbyFacilities({
    required double latitude,
    required double longitude,
    double radiusInKm = 5.0,
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .from('facilities')
          .select('*, location')
          .distance('location', {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          }, unit: 'km')
          .lte('distance', radiusInKm)
          .limit(limit);

      return response
          .map<Facility>((json) => Facility.fromJson({
                ...json,
                'lat': json['location']['coordinates'][1],
                'lng': json['location']['coordinates'][0],
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch nearby facilities: $e');
    }
  }

  /// Get popular facilities
  Future<List<Facility>> getPopularFacilities({int limit = 20}) async {
    try {
      // This would join with visits, reviews, etc. to get popularity
      final response = await _client
          .from('facilities')
          .select('*, location')
          .order('data_quality_score', ascending: false)
          .limit(limit);

      return response
          .map<Facility>((json) => Facility.fromJson({
                ...json,
                'lat': json['location']['coordinates'][1],
                'lng': json['location']['coordinates'][0],
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch popular facilities: $e');
    }
  }
}