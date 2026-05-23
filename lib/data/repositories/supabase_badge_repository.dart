// lib/data/repositories/supabase_badge_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';
import 'package:yu_map/domain/repositories/i_badge_repository.dart';

class SupabaseBadgeRepository implements IBadgeRepository {
  SupabaseBadgeRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Result<List<Map<String, dynamic>>>> getAllBadges() =>
      runCatching(() async {
        final data = await _client
            .from('badges')
            .select()
            .order('category')
            .order('name_ja');
        return (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });

  @override
  Future<Result<List<Map<String, dynamic>>>> getUserBadges(String userId) =>
      runCatching(() async {
        final data = await _client
            .from('user_badges')
            .select('*, badges(*)')
            .eq('user_id', userId)
            .order('earned_at', ascending: false);
        return (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
}
