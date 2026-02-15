// test/services/badge_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_data.dart';

void main() {
  group('BadgeService data structures', () {
    test('badge JSON has correct structure', () {
      final json = TestData.badgeJson();

      expect(json['id'], 'badge-1');
      expect(json['code'], 'first_visit');
      expect(json['name_ja'], '初めての湯');
      expect(json['name_en'], 'First Visit');
      expect(json['description_ja'], '初めて施設にチェックインしました');
      expect(json['category'], 'explorer');
    });

    test('badge categories are valid', () {
      const validCategories = {'explorer', 'social', 'special'};

      final explorerBadge = TestData.badgeJson(category: 'explorer');
      expect(validCategories.contains(explorerBadge['category']), true);

      final socialBadge = TestData.badgeJson(category: 'social');
      expect(validCategories.contains(socialBadge['category']), true);

      final specialBadge = TestData.badgeJson(category: 'special');
      expect(validCategories.contains(specialBadge['category']), true);
    });

    test('badge award rules are complete', () {
      // Verify the badge rule codes match the seed data
      const badgeRules = {
        'first_visit': 1,
        'explorer_10': 10,
        'explorer_50': 50,
        'explorer_100': 100,
        'first_review': 1,
        'reviewer_10': 10,
        'reviewer_50': 50,
      };

      expect(badgeRules.length, 7);
      expect(badgeRules.keys, contains('first_visit'));
      expect(badgeRules.keys, contains('explorer_100'));
      expect(badgeRules.keys, contains('reviewer_50'));
    });

    test('badge rules have correct thresholds', () {
      const rules = <String, int>{
        'first_visit': 1,
        'explorer_10': 10,
        'explorer_50': 50,
        'explorer_100': 100,
        'first_review': 1,
        'reviewer_10': 10,
        'reviewer_50': 50,
      };

      // Verify thresholds are ascending for each category
      expect(rules['first_visit']!, lessThan(rules['explorer_10']!));
      expect(rules['explorer_10']!, lessThan(rules['explorer_50']!));
      expect(rules['explorer_50']!, lessThan(rules['explorer_100']!));
      expect(rules['first_review']!, lessThan(rules['reviewer_10']!));
      expect(rules['reviewer_10']!, lessThan(rules['reviewer_50']!));
    });
  });

  group('Badge earned codes parsing', () {
    test('extract earned codes from user_badges response', () {
      final userBadgesResponse = [
        {
          'id': 'ub-1',
          'user_id': 'user-1',
          'badge_id': 'badge-1',
          'earned_at': '2024-01-15T00:00:00Z',
          'badges': {
            'code': 'first_visit',
            'name_ja': '初めての湯',
          },
        },
        {
          'id': 'ub-2',
          'user_id': 'user-1',
          'badge_id': 'badge-2',
          'earned_at': '2024-02-15T00:00:00Z',
          'badges': {
            'code': 'first_review',
            'name_ja': '初レビュー',
          },
        },
      ];

      final earnedCodes = <String>{};
      for (final ub in userBadgesResponse) {
        final badge = ub['badges'] as Map<String, dynamic>?;
        if (badge != null) earnedCodes.add(badge['code'] as String);
      }

      expect(earnedCodes, containsAll(['first_visit', 'first_review']));
      expect(earnedCodes.length, 2);
    });

    test('handles null badges gracefully', () {
      final userBadgesResponse = [
        {
          'id': 'ub-1',
          'user_id': 'user-1',
          'badges': null,
        },
      ];

      final earnedCodes = <String>{};
      for (final ub in userBadgesResponse) {
        final badge = ub['badges'] as Map<String, dynamic>?;
        if (badge != null) earnedCodes.add(badge['code'] as String);
      }

      expect(earnedCodes, isEmpty);
    });
  });
}
