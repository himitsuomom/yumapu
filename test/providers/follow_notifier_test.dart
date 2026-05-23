// test/providers/follow_notifier_test.dart
//
// Unit tests for FollowingNotifier using FakeFollowRepository.
// No Supabase, no network — fully in-memory.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/providers/follow_provider.dart';
import 'package:yu_map/providers/repository_providers.dart';
import '../helpers/fake_repositories.dart';

void main() {
  group('FollowingNotifier', () {
    late FakeFollowRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeFollowRepository(initial: {'user-a'});
      container = ProviderContainer(
        overrides: [
          followRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
    });

    test('build loads initial following IDs', () async {
      final state = await container.read(followingIdsProvider.future);
      expect(state, contains('user-a'));
    });

    test('build returns empty set when no followings', () async {
      final emptyRepo = FakeFollowRepository();
      final emptyContainer = ProviderContainer(
        overrides: [
          followRepositoryProvider.overrideWithValue(emptyRepo),
        ],
      );
      addTearDown(emptyContainer.dispose);

      final state = await emptyContainer.read(followingIdsProvider.future);
      expect(state, isEmpty);
    });

    test('follow adds user to following set', () async {
      await container.read(followingIdsProvider.future);
      await container.read(followingIdsProvider.notifier).follow('user-b');
      final state = container.read(followingIdsProvider).valueOrNull;
      expect(state, contains('user-b'));
    });

    test('follow is idempotent — already-followed user not duplicated',
        () async {
      await container.read(followingIdsProvider.future);
      await container.read(followingIdsProvider.notifier).follow('user-a');
      await container.read(followingIdsProvider.notifier).follow('user-a');
      final state = container.read(followingIdsProvider).valueOrNull;
      // Set can only have one entry per ID
      expect(state?.where((id) => id == 'user-a').length, equals(1));
    });

    test('unfollow removes user from following set', () async {
      await container.read(followingIdsProvider.future);
      await container.read(followingIdsProvider.notifier).unfollow('user-a');
      final state = container.read(followingIdsProvider).valueOrNull;
      expect(state, isNot(contains('user-a')));
    });

    test('follow rolls back on repository failure', () async {
      await container.read(followingIdsProvider.future);
      fakeRepo.shouldFail = true;
      await container.read(followingIdsProvider.notifier).follow('user-c');
      final state = container.read(followingIdsProvider).valueOrNull;
      expect(state, isNot(contains('user-c')));
    });

    test('unfollow rolls back on repository failure', () async {
      await container.read(followingIdsProvider.future);
      fakeRepo.shouldFail = true;
      await container.read(followingIdsProvider.notifier).unfollow('user-a');
      final state = container.read(followingIdsProvider).valueOrNull;
      // Roll back: user-a should still be in the set
      expect(state, contains('user-a'));
    });

    test('isFollowingProvider returns true for followed user', () async {
      await container.read(followingIdsProvider.future);
      expect(container.read(isFollowingProvider('user-a')), isTrue);
    });

    test('isFollowingProvider returns false for non-followed user', () async {
      await container.read(followingIdsProvider.future);
      expect(container.read(isFollowingProvider('user-x')), isFalse);
    });

    test('isFollowingProvider updates reactively after follow', () async {
      await container.read(followingIdsProvider.future);
      expect(container.read(isFollowingProvider('user-b')), isFalse);

      await container.read(followingIdsProvider.notifier).follow('user-b');
      expect(container.read(isFollowingProvider('user-b')), isTrue);
    });

    test('isFollowingProvider updates reactively after unfollow', () async {
      await container.read(followingIdsProvider.future);
      expect(container.read(isFollowingProvider('user-a')), isTrue);

      await container.read(followingIdsProvider.notifier).unfollow('user-a');
      expect(container.read(isFollowingProvider('user-a')), isFalse);
    });

    test('build falls back to empty set when repository returns failure',
        () async {
      final failingRepo = FakeFollowRepository(shouldFail: true);
      final failContainer = ProviderContainer(
        overrides: [
          followRepositoryProvider.overrideWithValue(failingRepo),
        ],
      );
      addTearDown(failContainer.dispose);

      // When getFollowingIds fails, dataOrNull is null → build returns {}
      final state = await failContainer.read(followingIdsProvider.future);
      expect(state, isEmpty);
    });
  });

  group('followCountsProvider', () {
    test('returns correct follower and following counts', () async {
      final fakeRepo = FakeFollowRepository();
      final container = ProviderContainer(
        overrides: [
          followRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final counts =
          await container.read(followCountsProvider('user-test').future);
      expect(counts.followersCount, equals(10));
      expect(counts.followingCount, equals(5));
    });

    test('returns zeros when repository fails', () async {
      final failRepo = FakeFollowRepository(shouldFail: true);
      final container = ProviderContainer(
        overrides: [
          followRepositoryProvider.overrideWithValue(failRepo),
        ],
      );
      addTearDown(container.dispose);

      final counts =
          await container.read(followCountsProvider('user-test').future);
      expect(counts.followersCount, equals(0));
      expect(counts.followingCount, equals(0));
    });
  });
}
