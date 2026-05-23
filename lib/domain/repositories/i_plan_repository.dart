// lib/domain/repositories/i_plan_repository.dart
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/models/onsen_plan.dart';

abstract interface class IPlanRepository {
  Future<Result<List<OnsenPlan>>> getPlans();
  Future<Result<OnsenPlan>> createPlan({
    required String name,
    required String description,
    required List<String> facilityIds,
  });
  Future<Result<void>> updatePlan(String planId,
      {String? name, String? description, List<String>? facilityIds});
  Future<Result<void>> deletePlan(String planId);
}
