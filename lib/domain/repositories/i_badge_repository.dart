// lib/domain/repositories/i_badge_repository.dart
import 'package:yu_map/core/result/result.dart';

abstract interface class IBadgeRepository {
  Future<Result<List<Map<String, dynamic>>>> getAllBadges();
  Future<Result<List<Map<String, dynamic>>>> getUserBadges(String userId);
}
