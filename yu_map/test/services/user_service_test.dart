// test/services/user_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/domain/entities/user_ranking.dart';
import '../helpers/test_data.dart';

void main() {
  group('User entity (used by UserService)', () {
    test('fromJson creates correct User', () {
      final json = TestData.userJson();
      final user = app.User.fromJson(json);

      expect(user.id, 'user-1');
      expect(user.email, 'test@example.com');
      expect(user.username, 'onsen_lover');
      expect(user.displayName, '温泉太郎');
      expect(user.isPremium, false);
      expect(user.bio, '温泉が大好き');
    });

    test('toJson round-trips correctly', () {
      final original = TestData.user(isPremium: true);
      final json = original.toJson();
      final roundTripped = app.User.fromJson(json);

      expect(roundTripped.id, original.id);
      expect(roundTripped.username, original.username);
      expect(roundTripped.isPremium, true);
    });

    test('copyWith modifies specified fields only', () {
      final user = TestData.user();
      final updated = user.copyWith(
        username: 'new_name',
        isPremium: true,
      );

      expect(updated.username, 'new_name');
      expect(updated.isPremium, true);
      expect(updated.id, user.id);
      expect(updated.email, user.email);
      expect(updated.displayName, user.displayName);
    });

    test('User equality uses id, username, displayName, isPremium', () {
      final user1 = TestData.user();
      final user2 = TestData.user();
      expect(user1, equals(user2));

      final user3 = TestData.user(username: 'different');
      expect(user1, isNot(equals(user3)));
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'user-2',
        'email': null,
        'username': null,
        'display_name': null,
        'avatar_url': null,
        'bio': null,
        'is_premium': null,
        'created_at': '2024-06-01T00:00:00Z',
      };
      final user = app.User.fromJson(json);

      expect(user.id, 'user-2');
      expect(user.email, isNull);
      expect(user.username, isNull);
      expect(user.displayName, isNull);
      expect(user.isPremium, false); // defaults to false
    });
  });

  group('UserRanking entity (used by UserService)', () {
    test('fromJson creates correct ranking', () {
      final json = TestData.rankingJson();
      final ranking = UserRanking.fromJson(json);

      expect(ranking.userId, 'user-1');
      expect(ranking.explorerPoints, 500);
      expect(ranking.socialPoints, 300);
      expect(ranking.totalPoints, 800);
      expect(ranking.currentTitle, '温泉愛好家');
      expect(ranking.rankPosition, 42);
    });

    test('toJson round-trips correctly', () {
      final original = TestData.ranking();
      final json = original.toJson();
      final roundTripped = UserRanking.fromJson(json);

      expect(roundTripped.userId, original.userId);
      expect(roundTripped.explorerPoints, original.explorerPoints);
      expect(roundTripped.totalPoints, original.totalPoints);
    });

    test('copyWith modifies fields correctly', () {
      final ranking = TestData.ranking();
      final updated = ranking.copyWith(
        explorerPoints: 1000,
        currentTitle: '湯マスター',
      );

      expect(updated.explorerPoints, 1000);
      expect(updated.currentTitle, '湯マスター');
      expect(updated.socialPoints, ranking.socialPoints);
    });

    test('default values when fields are missing', () {
      final json = {
        'id': 'rank-new',
        'user_id': 'user-new',
      };
      final ranking = UserRanking.fromJson(json);

      expect(ranking.explorerPoints, 0);
      expect(ranking.socialPoints, 0);
      expect(ranking.totalPoints, 0);
      expect(ranking.currentTitle, '湯めぐり初心者');
      expect(ranking.rankPosition, isNull);
    });

    test('equality checks id, userId, totalPoints, currentTitle, rankPosition', () {
      final r1 = TestData.ranking();
      final r2 = TestData.ranking();
      expect(r1, equals(r2));
    });
  });
}
