// lib/domain/repositories/i_ranking_repository.dart
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/domain/entities/user_ranking.dart';

abstract interface class IRankingRepository {
  Future<Result<List<UserRanking>>> getGlobalRanking({int limit = 100});
  Future<Result<List<UserRanking>>> getFollowingRanking({int limit = 50});
  Future<Result<UserRanking?>> getUserRank(String userId);
}
