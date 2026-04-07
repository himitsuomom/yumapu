// lib/features/favorites/providers/favorites_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/services/supabase_service.dart';

class FavoritesNotifier extends StateNotifier<AsyncValue<List<Facility>>> {
  FavoritesNotifier() : super(const AsyncValue.data([]));

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(SupabaseService.fetchFavorites);
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, AsyncValue<List<Facility>>>(
  (ref) => FavoritesNotifier(),
);
