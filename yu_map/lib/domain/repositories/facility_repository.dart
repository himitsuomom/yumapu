import 'package:yu_map/domain/entities/facility.dart';

abstract class FacilityRepository {
  Future<List<Facility>> getFacilitiesInBounds({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  });
}
