// test/facility_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/domain/entities/review.dart';

void main() {
  group('Facility.fromJson', () {
    test('parses latitude/longitude keys', () {
      final facility = Facility.fromJson({
        'id': '1',
        'name': 'Test Onsen',
        'latitude': 35.6762,
        'longitude': 139.6503,
      });
      expect(facility.latitude, 35.6762);
      expect(facility.longitude, 139.6503);
    });

    test('parses lat/lng keys as fallback', () {
      final facility = Facility.fromJson({
        'id': '1',
        'name': 'Test Onsen',
        'lat': 35.6762,
        'lng': 139.6503,
      });
      expect(facility.latitude, 35.6762);
      expect(facility.longitude, 139.6503);
    });

    test('prefers latitude over lat when both present', () {
      final facility = Facility.fromJson({
        'id': '1',
        'name': 'Test Onsen',
        'latitude': 35.0,
        'lat': 36.0,
        'longitude': 139.0,
        'lng': 140.0,
      });
      expect(facility.latitude, 35.0);
      expect(facility.longitude, 139.0);
    });

    test('returns 0.0 when lat/lng missing', () {
      final facility = Facility.fromJson({
        'id': '1',
        'name': 'Test Onsen',
      });
      expect(facility.latitude, 0.0);
      expect(facility.longitude, 0.0);
    });

    test('hasValidLocation is true when coordinates are non-zero', () {
      final facility = Facility.fromJson({
        'id': '1',
        'name': 'Test Onsen',
        'latitude': 35.6762,
        'longitude': 139.6503,
      });
      expect(facility.hasValidLocation, isTrue);
    });

    test('hasValidLocation is false when both coordinates are zero', () {
      final facility = Facility.fromJson({
        'id': '1',
        'name': 'Test Onsen',
      });
      expect(facility.hasValidLocation, isFalse);
    });

    test('businessHours defaults to empty map when null', () {
      final facility = Facility.fromJson({
        'id': '1',
        'name': 'Test Onsen',
      });
      expect(facility.businessHours, isEmpty);
    });

    test('priceInfo defaults to empty map when null', () {
      final facility = Facility.fromJson({
        'id': '1',
        'name': 'Test Onsen',
      });
      expect(facility.priceInfo, isEmpty);
    });

    test('dataQualityScore defaults to 1 when null', () {
      final facility = Facility.fromJson({
        'id': '1',
        'name': 'Test Onsen',
      });
      expect(facility.dataQualityScore, 1);
    });

    test('dataSource defaults to government when null', () {
      final facility = Facility.fromJson({
        'id': '1',
        'name': 'Test Onsen',
      });
      expect(facility.dataSource, 'government');
    });
  });

  group('Facility equality', () {
    test('same id and data are equal', () {
      final a = Facility.fromJson({
        'id': '1',
        'name': 'Test',
        'latitude': 35.0,
        'longitude': 139.0,
      });
      final b = Facility.fromJson({
        'id': '1',
        'name': 'Test',
        'latitude': 35.0,
        'longitude': 139.0,
      });
      expect(a, equals(b));
    });

    test('different dataQualityScore are not equal', () {
      final a = Facility.fromJson({
        'id': '1',
        'name': 'Test',
        'data_quality_score': 3,
      });
      final b = Facility.fromJson({
        'id': '1',
        'name': 'Test',
        'data_quality_score': 5,
      });
      expect(a, isNot(equals(b)));
    });
  });

  group('Review.fromJson', () {
    test('parses basic fields', () {
      final review = Review.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Great onsen!',
        'rating': 5,
        'created_at': '2024-01-01T00:00:00Z',
      });
      expect(review.id, 'r1');
      expect(review.content, 'Great onsen!');
      expect(review.rating, 5);
    });

    test('likes_count defaults to 0 when null', () {
      final review = Review.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Nice',
        'rating': 4,
        'created_at': '2024-01-01T00:00:00Z',
      });
      expect(review.likesCount, 0);
    });

    test('parses users JOIN key for user info', () {
      final review = Review.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Nice',
        'rating': 4,
        'created_at': '2024-01-01T00:00:00Z',
        'users': {
          'display_name': 'Taro',
          'avatar_url': 'https://example.com/avatar.png',
          'is_premium': true,
        },
      });
      expect(review.userName, 'Taro');
      expect(review.userAvatarUrl, 'https://example.com/avatar.png');
      expect(review.isPremium, isTrue);
    });

    test('parses profiles JOIN key as fallback', () {
      final review = Review.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Nice',
        'rating': 4,
        'created_at': '2024-01-01T00:00:00Z',
        'profiles': {
          'username': 'taro123',
          'avatar_url': 'https://example.com/avatar2.png',
        },
      });
      expect(review.userName, 'taro123');
      expect(review.userAvatarUrl, 'https://example.com/avatar2.png');
    });

    test('users takes priority over profiles', () {
      final review = Review.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Nice',
        'rating': 4,
        'created_at': '2024-01-01T00:00:00Z',
        'users': {'display_name': 'From Users'},
        'profiles': {'display_name': 'From Profiles'},
      });
      expect(review.userName, 'From Users');
    });

    test('is_premium defaults to false when null', () {
      final review = Review.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Nice',
        'rating': 4,
        'created_at': '2024-01-01T00:00:00Z',
      });
      expect(review.isPremium, isFalse);
    });

    test('invalid created_at throws FormatException', () {
      expect(
        () => Review.fromJson({
          'id': 'r1',
          'user_id': 'u1',
          'facility_id': 'f1',
          'content': 'Nice',
          'rating': 4,
          'created_at': 'not-a-date',
        }),
        throwsFormatException,
      );
    });
  });

  group('Review equality', () {
    test('same id but different content are not equal', () {
      final a = Review.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Version 1',
        'rating': 4,
        'created_at': '2024-01-01T00:00:00Z',
      });
      final b = Review.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Version 2',
        'rating': 4,
        'created_at': '2024-01-01T00:00:00Z',
      });
      expect(a, isNot(equals(b)));
    });

    test('same content are equal', () {
      final a = Review.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Same text',
        'rating': 4,
        'created_at': '2024-01-01T00:00:00Z',
      });
      final b = Review.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Same text',
        'rating': 4,
        'created_at': '2024-01-01T00:00:00Z',
      });
      expect(a, equals(b));
    });
  });
}
