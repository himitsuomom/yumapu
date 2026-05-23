// lib/domain/repositories/i_follow_repository.dart
import 'package:yu_map/core/result/result.dart';

abstract interface class IFollowRepository {
  Future<Result<Set<String>>> getFollowingIds();
  Future<Result<({int followers, int following})>> getFollowCounts(
      String userId);
  Future<Result<void>> follow(String targetUserId);
  Future<Result<void>> unfollow(String targetUserId);
  Future<Result<bool>> isFollowing(String targetUserId);
}
