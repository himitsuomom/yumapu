// lib/data/repositories/supabase_visit_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';
import 'package:yu_map/domain/repositories/i_visit_repository.dart';

class SupabaseVisitRepository implements IVisitRepository {
  SupabaseVisitRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Result<List<Map<String, dynamic>>>> getVisitsByUser(
          {int limit = 500, int offset = 0}) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return <Map<String, dynamic>>[];
        final rows = await _client
            .from('visits')
            .select('*, facilities(name, facility_types(code))')
            .eq('user_id', session.user.id)
            .order('visited_at', ascending: false)
            .range(offset, offset + limit - 1) as List;
        return rows
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
      });

  @override
  Future<Result<Map<String, dynamic>>> logVisit({
    required String facilityId,
    required double lat,
    required double lng,
  }) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        final result = await _client
            .from('visits')
            .insert({
              'facility_id': facilityId,
              'user_id': session.user.id,
              'visited_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        return Map<String, dynamic>.from(result as Map);
      });

  @override
  Future<Result<void>> deleteVisit(String visitId) => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client
            .from('visits')
            .delete()
            .eq('id', visitId)
            .eq('user_id', session.user.id);
      });

  @override
  Future<Result<bool>> hasVisitedToday(String facilityId) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return false;
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final data = await _client
            .from('visits')
            .select('id')
            .eq('user_id', session.user.id)
            .eq('facility_id', facilityId)
            .gte('visited_at', startOfDay.toIso8601String())
            .maybeSingle();
        return data != null;
      });

  @override
  Future<Result<int>> getVisitCount(String facilityId) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return 0;
        final response = await _client
            .from('visits')
            .select()
            .eq('user_id', session.user.id)
            .eq('facility_id', facilityId)
            .count();
        return response.count;
      });
}
