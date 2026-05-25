// lib/data/repositories/supabase_favorite_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';
import 'package:yu_map/domain/repositories/i_favorite_repository.dart';

class SupabaseFavoriteRepository implements IFavoriteRepository {
  SupabaseFavoriteRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Result<Set<String>>> getFavoriteIds() => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return <String>{};
        final rows = await _client
            .from('favorites')
            .select('facility_id')
            .eq('user_id', session.user.id) as List;
        return rows.map((r) => r['facility_id'] as String).toSet();
      });

  @override
  Future<Result<void>> addFavorite(String facilityId) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client.from('favorites').upsert(
          {'user_id': session.user.id, 'facility_id': facilityId},
          onConflict: 'user_id,facility_id',
        );
      });

  @override
  Future<Result<void>> removeFavorite(String facilityId) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client
            .from('favorites')
            .delete()
            .eq('user_id', session.user.id)
            .eq('facility_id', facilityId);
      });
}
