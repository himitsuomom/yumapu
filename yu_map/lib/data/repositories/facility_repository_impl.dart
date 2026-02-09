import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/domain/repositories/facility_repository.dart';

class FacilityRepositoryImpl implements FacilityRepository {
  final SupabaseClient _supabase;

  FacilityRepositoryImpl(this._supabase);

  @override
  Future<List<Facility>> getFacilitiesInBounds({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_facilities_in_bounds',
        params: {
          'min_lat': minLat,
          'min_lng': minLng,
          'max_lat': maxLat,
          'max_lng': maxLng,
          'facility_limit': 500,
        },
      );

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Facility.fromJson(json)).toList();
    } catch (e) {
      // In a real app, handle errors properly (log, rethrow custom exception, etc.)
      print('Error fetching facilities: $e');
      return [];
    }
  }
}
