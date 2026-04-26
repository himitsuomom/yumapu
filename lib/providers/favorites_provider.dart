import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/providers/auth_provider.dart';

// ── Notifier ─────────────────────────────────────────────────────────────────

class FavoritesNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  FavoritesNotifier(this._client, this._userId)
      : super(const AsyncLoading()) {
    if (_client != null && _userId != null) {
      _loadFavorites();
    } else {
      state = const AsyncData({});
    }
  }

  final SupabaseClient? _client;
  final String? _userId;

  Future<void> _loadFavorites() async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      state = const AsyncData({});
      return;
    }
    try {
      final rows = await client
          .from('favorites')
          .select('facility_id')
          .eq('user_id', userId) as List;
      if (!mounted) return;
      final ids = rows.map((r) => r['facility_id'] as String).toSet();
      state = AsyncData(ids);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncError(e, st);
    }
  }

  /// Public reload trigger — re-fetches favorites from Supabase.
  ///
  /// Useful when called from [HomeShell.initState] to ensure the local
  /// favorites set is fresh after login.
  Future<void> load() => _loadFavorites();

  /// Returns whether [facilityId] is in the current favorites set.
  bool isFavorite(String facilityId) =>
      state.valueOrNull?.contains(facilityId) ?? false;

  /// Toggles the favorite state with optimistic update.
  ///
  /// Immediately updates the local state, then syncs with Supabase.
  /// Rolls back to the previous state if the server call fails.
  Future<void> toggle(String facilityId) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return;

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
            .eq('user_id', userId)
            .eq('facility_id', facilityId);
      } else {
        await client.from('favorites').insert({
          'user_id': userId,
          'facility_id': facilityId,
        });
      }
    } catch (_) {
      // Roll back to previous state on failure
      if (mounted) state = AsyncData(previous);
    }
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, AsyncValue<Set<String>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  return FavoritesNotifier(client, session?.user.id);
});

/// Convenience provider: `true` when [facilityId] is in the user's favorites.
final isFavoriteProvider = Provider.family<bool, String>((ref, facilityId) {
  return ref.watch(favoritesProvider).valueOrNull?.contains(facilityId) ?? false;
});
