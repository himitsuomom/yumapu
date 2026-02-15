// test/providers/favorite_providers_test.dart
//
// Tests for FavoriteNotifier and favorite providers.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yu_map/providers/favorite_providers.dart';
import 'package:yu_map/providers/service_providers.dart';
import '../helpers/mocks.dart';
import '../helpers/test_data.dart';

void main() {
  group('FavoriteNotifier', () {
    late ProviderContainer container;
    late MockFavoriteService mockFavoriteService;

    setUp(() {
      mockFavoriteService = MockFavoriteService();
      container = ProviderContainer(
        overrides: [
          favoriteServiceProvider.overrideWithValue(mockFavoriteService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is AsyncData(null)', () {
      final state = container.read(favoriteNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });

    test('toggle removes favorite when currently favorited', () async {
      when(() => mockFavoriteService.removeFavorite(any()))
          .thenAnswer((_) async {});
      when(() => mockFavoriteService.isFavorite(any()))
          .thenAnswer((_) async => false);
      when(() => mockFavoriteService.getFavorites())
          .thenAnswer((_) async => []);

      final notifier = container.read(favoriteNotifierProvider.notifier);
      await notifier.toggle('facility-1', currentlyFavorited: true);

      verify(() => mockFavoriteService.removeFavorite('facility-1')).called(1);
      verifyNever(() => mockFavoriteService.addFavorite(any()));
    });

    test('toggle adds favorite when not currently favorited', () async {
      when(() => mockFavoriteService.addFavorite(any()))
          .thenAnswer((_) async {});
      when(() => mockFavoriteService.isFavorite(any()))
          .thenAnswer((_) async => true);
      when(() => mockFavoriteService.getFavorites())
          .thenAnswer((_) async => []);

      final notifier = container.read(favoriteNotifierProvider.notifier);
      await notifier.toggle('facility-1', currentlyFavorited: false);

      verify(() => mockFavoriteService.addFavorite('facility-1')).called(1);
      verifyNever(() => mockFavoriteService.removeFavorite(any()));
    });

    test('toggle sets error on failure', () async {
      when(() => mockFavoriteService.addFavorite(any()))
          .thenThrow(Exception('DB error'));

      final notifier = container.read(favoriteNotifierProvider.notifier);
      await notifier.toggle('facility-1', currentlyFavorited: false);

      final state = container.read(favoriteNotifierProvider);
      expect(state.hasError, true);
    });

    test('toggle resets to data state on success', () async {
      when(() => mockFavoriteService.removeFavorite(any()))
          .thenAnswer((_) async {});
      when(() => mockFavoriteService.isFavorite(any()))
          .thenAnswer((_) async => false);
      when(() => mockFavoriteService.getFavorites())
          .thenAnswer((_) async => []);

      final notifier = container.read(favoriteNotifierProvider.notifier);
      await notifier.toggle('facility-1', currentlyFavorited: true);

      final state = container.read(favoriteNotifierProvider);
      expect(state.hasError, false);
      expect(state, isA<AsyncData<void>>());
    });
  });
}
