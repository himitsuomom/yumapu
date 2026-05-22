// lib/data/repositories/supabase_follow_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';
import 'package:yu_map/domain/repositories/i_follow_repository.dart';

class SupabaseFollowRepository implements IFollowRepository {
  SupabaseFollowRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Result<Set<String>>> getFollowingIds() => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return <String>{};
        final data = await _client
            .from('user_follows')
            .select('following_id')
            .eq('follower_id', session.user.id);
        return (data as List)
            .map((e) => e['following_id'] as String)
            .toSet();
      });

  @override
  Future<Result<({int followers, int following})>> getFollowCounts(
          String userId) =>
      runCatching(() async {
        final result = await _client.rpc(
          'get_follow_counts',
          params: {'p_user_id': userId},
        );
        final row = (result as List).firstOrNull as Map<String, dynamic>?;
        return (
          followers: (row?['followers_count'] as num?)?.toInt() ?? 0,
          following: (row?['following_count'] as num?)?.toInt() ?? 0,
        );
      });

  @override
  Future<Result<void>> follow(String targetUserId) => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client.from('user_follows').insert({
          'follower_id': session.user.id,
          'following_id': targetUserId,
        });
      });

  @override
  Future<Result<void>> unfollow(String targetUserId) => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client
            .from('user_follows')
            .delete()
            .eq('follower_id', session.user.id)
            .eq('following_id', targetUserId);
      });

  @override
  Future<Result<bool>> isFollowing(String targetUserId) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return false;
        final data = await _client
            .from('user_follows')
            .select('following_id')
            .eq('follower_id', session.user.id)
            .eq('following_id', targetUserId)
            .maybeSingle();
        return data != null;
      });
}
