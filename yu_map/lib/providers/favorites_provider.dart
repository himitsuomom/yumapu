import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// User's favorited facility IDs (stored locally in Supabase).
/// Uses a simple "favorites" table approach: user_id + facility_id.
class FavoritesNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  FavoritesNotifier(this._ref) : super(const AsyncData({}));
  final Ref _ref;

  Future<void> load() async {
    final session = _ref.read(sessionProvider);
    if (session == null) {
      state = const AsyncData({});
      return;
    }
    state = const AsyncLoading();
    try {
      final client = _ref.read(supabaseClientProvider);
      final data = await client
          .from('favorites')
          .select('facility_id')
          .eq('user_id', session.user.id);
      final ids = (data as List)
          .map((r) => r['facility_id'] as String)
          .toSet();
      state = AsyncData(ids);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> toggle(String facilityId) async {
    final session = _ref.read(sessionProvider);
    if (session == null) return;
    final client = _ref.read(supabaseClientProvider);
    final current = state.valueOrNull ?? {};

    if (current.contains(facilityId)) {
      // Remove
      state = AsyncData({...current}..remove(facilityId));
      try {
        await client
            .from('favorites')
            .delete()
            .eq('user_id', session.user.id)
            .eq('facility_id', facilityId);
      } catch (_) {
        state = AsyncData({...current}); // revert
      }
    } else {
      // Add
      state = AsyncData({...current, facilityId});
      try {
        await client.from('favorites').insert({
          'user_id': session.user.id,
          'facility_id': facilityId,
        });
      } catch (_) {
        state = AsyncData({...current}); // revert
      }
    }
  }

  bool isFavorite(String facilityId) {
    return state.valueOrNull?.contains(facilityId) ?? false;
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, AsyncValue<Set<String>>>((ref) {
  return FavoritesNotifier(ref);
});

/// Full facility objects for the favorites list screen.
final favoriteFacilitiesProvider =
    FutureProvider.autoDispose<List<Facility>>((ref) async {
  final favIds = ref.watch(favoritesProvider).valueOrNull ?? {};
  if (favIds.isEmpty) return [];
  final client = ref.read(supabaseClientProvider);
  final data = await client
      .from('facilities')
      .select()
      .inFilter('id', favIds.toList());
  return (data as List).map((r) => Facility.fromJson(r)).toList();
});
