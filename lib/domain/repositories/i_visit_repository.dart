// lib/domain/repositories/i_visit_repository.dart
import 'package:yu_map/core/result/result.dart';

abstract interface class IVisitRepository {
  Future<Result<List<Map<String, dynamic>>>> getVisitsByUser(
      {int limit = 500, int offset = 0});
  Future<Result<Map<String, dynamic>>> logVisit({
    required String facilityId,
    required double lat,
    required double lng,
  });
  Future<Result<void>> deleteVisit(String visitId);
  Future<Result<bool>> hasVisitedToday(String facilityId);
  Future<Result<int>> getVisitCount(String facilityId);
}
