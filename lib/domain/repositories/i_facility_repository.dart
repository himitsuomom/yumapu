// lib/domain/repositories/i_facility_repository.dart
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/domain/entities/facility.dart';

enum FacilitySortByRepo { qualityScore, rating, reviewCount, distance, newest }

abstract interface class IFacilityRepository {
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
  });
  Future<Result<Facility?>> getFacilityById(String id);
  Future<Result<List<Facility>>> getTrendingFacilities({int limit = 20});
  Future<Result<Map<String, dynamic>>> getReviewSummary(String facilityId);
  Future<Result<void>> updateFacility(
      String facilityId, Map<String, dynamic> patch);
  void clearCache();
}
