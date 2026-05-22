import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/auth_provider.dart';

// ── Notifier ─────────────────────────────────────────────────────────────────

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final client = ref.watch(supabaseClientProvider);
    final session = ref.watch(sessionProvider);
    if (client == null || session == null) return {};

    final rows = await client
        .from('favorites')
        .select('facility_id')
        .eq('user_id', session.user.id) as List;
    return rows.map((r) => r['facility_id'] as String).toSet();
  }

  /// Public reload trigger — re-fetches favorites from Supabase.
  ///
  /// Useful when called from [HomeShell.initState] to ensure the local
  /// favorites set is fresh after login.
  Future<void> load() async => ref.invalidateSelf();

  /// Returns whether [facilityId] is in the current favorites set.
  bool isFavorite(String facilityId) =>
      state.valueOrNull?.contains(facilityId) ?? false;

  /// Toggles the favorite state with optimistic update.
  ///
  /// Immediately updates the local state, then syncs with Supabase.
  /// Rolls back to the previous state if the server call fails.
  Future<void> toggle(String facilityId) async {
    final client = ref.read(supabaseClientProvider);
    final session = ref.read(sessionProvider);
    if (client == null || session == null) return;

    final previous = state.valueOrNull ?? {};
    final wasFavorited = previous.contains(facilityId);

    // Optimistic update
    final optimistic = Set<String>.from(previous);
    if (wasFavorited) {
      optimistic.remove(facilityId);
    } else {
      optimistic.add(facilityId);
    }
    state = AsyncData(optimistic);

    try {
      if (wasFavorited) {
        await client
            .from('favorites')
            .delete()
            .eq('user_id', session.user.id)
            .eq('facility_id', facilityId);
      } else {
        await client.from('favorites').insert({
          'user_id': session.user.id,
          'facility_id': facilityId,
        });
      }
    } catch (e) {
      debugPrint('Favorites toggle failed, rolling back: $e');
      state = AsyncData(previous);
    }
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);

/// Convenience provider: `true` when [facilityId] is in the user's favorites.
final isFavoriteProvider = Provider.family<bool, String>((ref, facilityId) {
  return ref.watch(favoritesProvider).valueOrNull?.contains(facilityId) ?? false;
});
