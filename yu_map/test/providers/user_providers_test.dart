// test/providers/user_providers_test.dart
//
// Tests for user-related providers (ranking, counts, leaderboard).

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yu_map/providers/user_providers.dart';
import 'package:yu_map/providers/service_providers.dart';
import 'package:yu_map/domain/entities/user_ranking.dart';
import '../helpers/mocks.dart';
import '../helpers/test_data.dart';

void main() {
  late MockUserService mockUserService;

  setUp(() {
    mockUserService = MockUserService();
  });

  group('userRankingProvider', () {
    test('returns ranking when user has one', () async {
      final ranking = TestData.ranking();
      when(() => mockUserService.getUserRanking(any()))
          .thenAnswer((_) async => ranking);

      final container = ProviderContainer(
        overrides: [
          userServiceProvider.overrideWithValue(mockUserService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(userRankingProvider('user-1').future);

      expect(result, isNotNull);
      expect(result!.explorerPoints, 500);
      expect(result.totalPoints, 800);
      expect(result.rankPosition, 42);
    });

    test('returns null when user has no ranking', () async {
      when(() => mockUserService.getUserRanking(any()))
          .thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          userServiceProvider.overrideWithValue(mockUserService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(userRankingProvider('user-new').future);
      expect(result, isNull);
    });
  });

  group('userVisitCountProvider', () {
    test('returns correct visit count', () async {
      when(() => mockUserService.getVisitCount(any()))
          .thenAnswer((_) async => 42);

      final container = ProviderContainer(
        overrides: [
          userServiceProvider.overrideWithValue(mockUserService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(userVisitCountProvider('user-1').future);
      expect(result, 42);
    });

    test('returns zero for new user', () async {
      when(() => mockUserService.getVisitCount(any()))
          .thenAnswer((_) async => 0);

      final container = ProviderContainer(
        overrides: [
          userServiceProvider.overrideWithValue(mockUserService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(userVisitCountProvider('user-new').future);
      expect(result, 0);
    });
  });

  group('userReviewCountProvider', () {
    test('returns correct review count', () async {
      when(() => mockUserService.getReviewCount(any()))
          .thenAnswer((_) async => 15);

      final container = ProviderContainer(
        overrides: [
          userServiceProvider.overrideWithValue(mockUserService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(userReviewCountProvider('user-1').future);
      expect(result, 15);
    });
  });

  group('leaderboardProvider', () {
    test('returns leaderboard data', () async {
      final leaderboardData = [
        {
          'user_id': 'user-1',
          'display_name': '温泉太郎',
          'total_points': 800,
          'rank_position': 1,
        },
        {
          'user_id': 'user-2',
          'display_name': 'サウナ好き',
          'total_points': 600,
          'rank_position': 2,
        },
      ];
      when(() => mockUserService.getLeaderboard())
          .thenAnswer((_) async => leaderboardData);

      final container = ProviderContainer(
        overrides: [
          userServiceProvider.overrideWithValue(mockUserService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(leaderboardProvider.future);

      expect(result.length, 2);
      expect(result[0]['rank_position'], 1);
      expect(result[1]['total_points'], 600);
    });

    test('returns empty list when no data', () async {
      when(() => mockUserService.getLeaderboard())
          .thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          userServiceProvider.overrideWithValue(mockUserService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(leaderboardProvider.future);
      expect(result, isEmpty);
    });
  });
}
