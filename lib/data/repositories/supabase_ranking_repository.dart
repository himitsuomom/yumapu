// lib/data/repositories/supabase_ranking_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';
import 'package:yu_map/domain/entities/user_ranking.dart';
import 'package:yu_map/domain/repositories/i_ranking_repository.dart';

class SupabaseRankingRepository implements IRankingRepository {
  SupabaseRankingRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Result<List<UserRanking>>> getGlobalRanking({int limit = 100}) =>
      runCatching(() async {
        final data = await _client
            .from('user_rankings')
            .select()
            .order('total_points', ascending: false)
            .limit(limit);
        return (data as List)
            .map((e) => UserRanking.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<Result<List<UserRanking>>> getFollowingRanking({int limit = 50}) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return <UserRanking>[];

        // Get following IDs first
        final followData = await _client
            .from('user_follows')
            .select('following_id')
            .eq('follower_id', session.user.id);
        final followingIds = (followData as List)
            .map((e) => e['following_id'] as String)
            .toList();

        if (followingIds.isEmpty) return <UserRanking>[];

        final data = await _client
            .from('user_rankings')
            .select()
            .inFilter('user_id', followingIds)
            .order('total_points', ascending: false)
            .limit(limit);
        return (data as List)
            .map((e) => UserRanking.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<Result<UserRanking?>> getUserRank(String userId) =>
      runCatching(() async {
        final data = await _client
            .from('user_rankings')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        return data == null ? null : UserRanking.fromJson(data);
      });
}
