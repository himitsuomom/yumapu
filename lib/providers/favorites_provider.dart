import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/result/result_extensions.dart';
import 'package:yu_map/providers/repository_providers.dart';

// ── Notifier ─────────────────────────────────────────────────────────────────

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final repo = ref.watch(favoritesRepositoryProvider);
    final result = await repo.getFavoriteIds();
    return result.dataOrNull ?? {};
  }

  /// Public reload trigger — re-fetches favorites from the repository.
  ///
  /// Useful when called from [HomeShell.initState] to ensure the local
  /// favorites set is fresh after login.
  Future<void> load() async => ref.invalidateSelf();

  /// Returns whether [facilityId] is in the current favorites set.
  bool isFavorite(String facilityId) =>
      state.valueOrNull?.contains(facilityId) ?? false;

  /// Toggles the favorite state with optimistic update.
  ///
  /// Immediately updates the local state, then syncs via the repository.
  /// Rolls back to the previous state if the server call fails.
  Future<void> toggle(String facilityId) async {
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

    final repo = ref.read(favoritesRepositoryProvider);
    final result = wasFavorited
        ? await repo.removeFavorite(facilityId)
        : await repo.addFavorite(facilityId);

    result.onFailure((e) {
      debugPrint('FavoritesNotifier.toggle failed, rolling back: $e');
      state = AsyncData(previous);
    });
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
