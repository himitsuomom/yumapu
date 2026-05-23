// test/providers/favorites_notifier_test.dart
//
// Unit tests for FavoritesNotifier using FakeFavoriteRepository.
// No Supabase, no network — fully in-memory.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/repository_providers.dart';
import '../helpers/fake_repositories.dart';

void main() {
  group('FavoritesNotifier', () {
    late FakeFavoriteRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeFavoriteRepository(initial: {'facility-1'});
      container = ProviderContainer(
        overrides: [
          favoritesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
    });

    test('build loads initial favorites from repository', () async {
      final state = await container.read(favoritesProvider.future);
      expect(state, contains('facility-1'));
    });

    test('build returns empty set when repository has no favorites', () async {
      final emptyRepo = FakeFavoriteRepository();
      final emptyContainer = ProviderContainer(
        overrides: [
          favoritesRepositoryProvider.overrideWithValue(emptyRepo),
        ],
      );
      addTearDown(emptyContainer.dispose);

      final state = await emptyContainer.read(favoritesProvider.future);
      expect(state, isEmpty);
    });

    test('isFavorite returns true for existing favorite', () async {
      await container.read(favoritesProvider.future);
      final notifier = container.read(favoritesProvider.notifier);
      expect(notifier.isFavorite('facility-1'), isTrue);
    });

    test('isFavorite returns false for non-favorite', () async {
      await container.read(favoritesProvider.future);
      final notifier = container.read(favoritesProvider.notifier);
      expect(notifier.isFavorite('facility-99'), isFalse);
    });

    test('toggle adds a new favorite', () async {
      await container.read(favoritesProvider.future);
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.toggle('facility-2');
      final state = container.read(favoritesProvider).valueOrNull;
      expect(state, contains('facility-2'));
    });

    test('toggle removes an existing favorite', () async {
      await container.read(favoritesProvider.future);
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.toggle('facility-1');
      final state = container.read(favoritesProvider).valueOrNull;
      expect(state, isNot(contains('facility-1')));
    });

    test('toggle rolls back on repository failure when adding', () async {
      await container.read(favoritesProvider.future);
      fakeRepo.shouldFail = true;
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.toggle('facility-99');
      final state = container.read(favoritesProvider).valueOrNull;
      // Roll back: facility-99 should NOT be in the set
      expect(state, isNot(contains('facility-99')));
    });

    test('toggle rolls back on repository failure when removing', () async {
      await container.read(favoritesProvider.future);
      fakeRepo.shouldFail = true;
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.toggle('facility-1'); // try to remove existing
      final state = container.read(favoritesProvider).valueOrNull;
      // Roll back: facility-1 should still be in the set
      expect(state, contains('facility-1'));
    });

    test('isFavoriteProvider returns true for favorited facility', () async {
      await container.read(favoritesProvider.future);
      final isFav = container.read(isFavoriteProvider('facility-1'));
      expect(isFav, isTrue);
    });

    test('isFavoriteProvider returns false for non-favorited facility',
        () async {
      await container.read(favoritesProvider.future);
      final isNotFav = container.read(isFavoriteProvider('facility-99'));
      expect(isNotFav, isFalse);
    });

    test('isFavoriteProvider updates after toggle', () async {
      await container.read(favoritesProvider.future);
      expect(container.read(isFavoriteProvider('facility-2')), isFalse);

      await container.read(favoritesProvider.notifier).toggle('facility-2');
      expect(container.read(isFavoriteProvider('facility-2')), isTrue);
    });

    test('build falls back to empty set when repository returns failure',
        () async {
      final failingRepo = FakeFavoriteRepository(shouldFail: true);
      final failContainer = ProviderContainer(
        overrides: [
          favoritesRepositoryProvider.overrideWithValue(failingRepo),
        ],
      );
      addTearDown(failContainer.dispose);

      // When getFavoriteIds fails, dataOrNull is null → build returns {}
      final state = await failContainer.read(favoritesProvider.future);
      expect(state, isEmpty);
    });
  });
}
