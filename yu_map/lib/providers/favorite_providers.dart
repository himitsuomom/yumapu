// lib/providers/favorite_providers.dart
//
// Favorite / bookmark providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/service_providers.dart';

/// Whether a specific facility is favorited by the current user.
final isFavoriteProvider =
    FutureProvider.family<bool, String>((ref, facilityId) async {
  final service = ref.watch(favoriteServiceProvider);
  return service.isFavorite(facilityId);
});

/// All favorite facilities for the current user.
final favoriteFacilitiesProvider = FutureProvider<List<Facility>>((ref) async {
  final service = ref.watch(favoriteServiceProvider);
  return service.getFavorites();
});

/// Notifier for toggling favorites.
class FavoriteNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  FavoriteNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> toggle(String facilityId, {required bool currentlyFavorited}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = _ref.read(favoriteServiceProvider);
      if (currentlyFavorited) {
        await service.removeFavorite(facilityId);
      } else {
        await service.addFavorite(facilityId);
      }
      _ref.invalidate(isFavoriteProvider(facilityId));
      _ref.invalidate(favoriteFacilitiesProvider);
    });
  }
}

final favoriteNotifierProvider =
    StateNotifierProvider<FavoriteNotifier, AsyncValue<void>>(
  (ref) => FavoriteNotifier(ref),
);
