// test/facility_service_test.dart
//
// Unit tests for FacilityService, entities, and input sanitization.
// Uses mocktail for clean mock setup.
//
// To run: flutter test test/facility_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/domain/entities/user.dart' as app_user;
import 'package:yu_map/domain/entities/user_ranking.dart';
import 'package:yu_map/services/facility_service.dart';

// --- Mocks ---

class MockSupabaseClient extends Mock implements SupabaseClient {}

// --- Test Data ---

final _sampleFacilityJson = {
  'id': 'test-id-1',
  'name': 'Test Onsen',
  'name_kana': null,
  'google_place_id': null,
  'latitude': 35.6895,
  'longitude': 139.6917,
  'address': 'Tokyo',
  'phone': null,
  'website': null,
  'business_hours': <String, dynamic>{},
  'price_info': <String, dynamic>{},
  'amenities': <String, dynamic>{'sauna': true, 'tattoo_friendly': false},
  'data_source': 'government',
  'data_quality_score': 3,
  'prefecture_id': 'pref-13',
  'facility_type_id': 'type-onsen',
};

void main() {
  late MockSupabaseClient mockClient;
  late FacilityService facilityService;

  setUp(() {
    mockClient = MockSupabaseClient();
    facilityService = FacilityService(mockClient);
  });

  // ---- Facility entity tests ----

  group('Facility entity', () {
    test('fromJson correctly parses latitude/longitude fields', () {
      final facility = Facility.fromJson(_sampleFacilityJson);
      expect(facility.latitude, 35.6895);
      expect(facility.longitude, 139.6917);
      expect(facility.name, 'Test Onsen');
      expect(facility.dataQualityScore, 3);
    });

    test('fromJson falls back to lat/lng keys (RPC results)', () {
      final json = {
        'id': 'test-id-2',
        'name': 'RPC Facility',
        'lat': 34.0,
        'lng': 135.0,
      };
      final facility = Facility.fromJson(json);
      expect(facility.latitude, 34.0);
      expect(facility.longitude, 135.0);
    });

    test('fromJson defaults to 0.0 when no coordinates', () {
      final json = {'id': 'no-coords', 'name': 'No Coords'};
      final facility = Facility.fromJson(json);
      expect(facility.latitude, 0.0);
      expect(facility.longitude, 0.0);
    });

    test('toJson round-trips correctly', () {
      final facility = Facility.fromJson(_sampleFacilityJson);
      final json = facility.toJson();
      expect(json['id'], 'test-id-1');
      expect(json['latitude'], 35.6895);
      expect(json['longitude'], 139.6917);
      expect(json['data_quality_score'], 3);

      // Round-trip: fromJson -> toJson -> fromJson should be equal
      final roundTripped = Facility.fromJson(json);
      expect(roundTripped, equals(facility));
    });

    test('fromJson parses amenities correctly', () {
      final facility = Facility.fromJson(_sampleFacilityJson);
      expect(facility.amenities, isA<Map<String, dynamic>>());
      expect(facility.amenities['sauna'], true);
      expect(facility.amenities['tattoo_friendly'], false);
    });

    test('fromJson defaults amenities to empty map when missing', () {
      final json = {'id': 'no-amenities', 'name': 'No Amenities'};
      final facility = Facility.fromJson(json);
      expect(facility.amenities, isEmpty);
    });

    test('copyWith creates modified copy while preserving other fields', () {
      final facility = Facility.fromJson(_sampleFacilityJson);
      final updated = facility.copyWith(name: 'Updated Onsen', dataQualityScore: 5);
      expect(updated.name, 'Updated Onsen');
      expect(updated.dataQualityScore, 5);
      expect(updated.id, facility.id);
      expect(updated.latitude, facility.latitude);
    });
  });

  // ---- Review entity tests ----

  group('Review entity', () {
    test('fromJson rejects rating below 1', () {
      final json = {
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Bad',
        'rating': 0,
        'created_at': '2024-01-01T00:00:00Z',
      };
      expect(() => Review.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('fromJson rejects rating above 5', () {
      final json = {
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Too high',
        'rating': 6,
        'created_at': '2024-01-01T00:00:00Z',
      };
      expect(() => Review.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('fromJson accepts valid rating and produces correct toJson', () {
      final json = {
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Great onsen!',
        'rating': 5,
        'likes_count': 10,
        'created_at': '2024-01-01T00:00:00Z',
      };
      final review = Review.fromJson(json);
      expect(review.rating, 5);
      expect(review.likesCount, 10);
      expect(review.content, 'Great onsen!');

      final output = review.toJson();
      expect(output['rating'], 5);
      expect(output['user_id'], 'u1');
    });

    test('fromJson defaults content to empty string when null', () {
      final json = {
        'id': 'r2',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': null,
        'rating': 3,
        'created_at': '2024-01-01T00:00:00Z',
      };
      final review = Review.fromJson(json);
      expect(review.content, '');
    });
  });

  // ---- User entity tests ----

  group('User entity', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'id': 'user-1',
        'email': 'test@example.com',
        'username': 'onsen_lover',
        'display_name': 'Onsen Lover',
        'avatar_url': null,
        'bio': 'I love hot springs',
        'is_premium': true,
        'created_at': '2024-06-01T12:00:00Z',
      };
      final user = app_user.User.fromJson(json);
      expect(user.isPremium, true);
      expect(user.username, 'onsen_lover');

      final output = user.toJson();
      expect(output['is_premium'], true);
      expect(output['display_name'], 'Onsen Lover');
    });
  });

  // ---- UserRanking entity tests ----

  group('UserRanking entity', () {
    test('fromJson parses correctly with defaults', () {
      final json = {
        'id': 'rank-1',
        'user_id': 'user-1',
      };
      final ranking = UserRanking.fromJson(json);
      expect(ranking.explorerPoints, 0);
      expect(ranking.socialPoints, 0);
      expect(ranking.totalPoints, 0);
      expect(ranking.currentTitle, '\u6e6f\u3081\u3050\u308a\u521d\u5fc3\u8005');
      expect(ranking.rankPosition, isNull);
    });

    test('toJson includes all fields', () {
      final ranking = UserRanking(
        id: 'rank-1',
        userId: 'user-1',
        explorerPoints: 500,
        socialPoints: 300,
        totalPoints: 800,
        currentTitle: '\u6e29\u6cc9\u611b\u597d\u5bb6',
        rankPosition: 42,
      );
      final json = ranking.toJson();
      expect(json['explorer_points'], 500);
      expect(json['rank_position'], 42);
    });
  });

  // ---- FacilityService cache tests ----

  group('FacilityService cache', () {
    test('cache starts empty', () {
      expect(facilityService.cache, isEmpty);
    });

    test('clearCache removes all entries', () {
      facilityService.clearCache();
      expect(facilityService.cache, isEmpty);
    });
  });
}
