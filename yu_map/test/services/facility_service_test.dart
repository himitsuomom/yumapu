// test/services/facility_service_test.dart
//
// Tests for FacilityService cache behavior and Facility entity parsing.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yu_map/services/facility_service.dart';
import 'package:yu_map/domain/entities/facility.dart';
import '../helpers/mocks.dart';
import '../helpers/test_data.dart';

void main() {
  late MockSupabaseClient mockClient;
  late FacilityService facilityService;

  setUp(() {
    mockClient = MockSupabaseClient();
    facilityService = FacilityService(mockClient);
  });

  group('FacilityService cache', () {
    test('cache starts empty', () {
      expect(facilityService.cache, isEmpty);
    });

    test('clearCache removes all entries', () {
      facilityService.clearCache();
      expect(facilityService.cache, isEmpty);
    });

    test('cache getter returns unmodifiable map', () {
      final cache = facilityService.cache;
      expect(() => (cache as Map)['new-key'] = {}, throwsA(anything));
    });
  });

  group('Facility entity (used by FacilityService)', () {
    test('fromJson correctly parses all fields', () {
      final json = TestData.facilityJson();
      final facility = Facility.fromJson(json);

      expect(facility.id, 'facility-1');
      expect(facility.name, 'テスト温泉');
      expect(facility.latitude, 35.6895);
      expect(facility.longitude, 139.6917);
      expect(facility.address, '東京都渋谷区1-1-1');
      expect(facility.phone, '03-1234-5678');
      expect(facility.website, 'https://example.com');
      expect(facility.dataSource, 'government');
      expect(facility.dataQualityScore, 3);
      expect(facility.amenities['sauna'], true);
      expect(facility.amenities['outdoor_bath'], true);
    });

    test('fromJson falls back to lat/lng keys', () {
      final json = {
        'id': 'rpc-1',
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

    test('fromJson prioritizes latitude over lat', () {
      final json = {
        'id': 'both',
        'name': 'Both Keys',
        'latitude': 36.0,
        'longitude': 140.0,
        'lat': 99.0,
        'lng': 99.0,
      };
      final facility = Facility.fromJson(json);

      expect(facility.latitude, 36.0);
      expect(facility.longitude, 140.0);
    });

    test('fromJson defaults amenities to empty map when null', () {
      final json = {'id': 'no-amenities', 'name': 'No Amenities'};
      final facility = Facility.fromJson(json);

      expect(facility.amenities, isEmpty);
    });

    test('fromJson defaults amenities to empty map when missing', () {
      final json = {
        'id': 'missing',
        'name': 'Missing',
        'amenities': null,
      };
      final facility = Facility.fromJson(json);

      expect(facility.amenities, isEmpty);
    });

    test('toJson round-trips correctly', () {
      final original = Facility.fromJson(TestData.facilityJson());
      final json = original.toJson();
      final roundTripped = Facility.fromJson(json);

      expect(roundTripped, equals(original));
      expect(roundTripped.address, original.address);
      expect(roundTripped.amenities, original.amenities);
    });

    test('toJson includes all fields', () {
      final facility = TestData.facility();
      final json = facility.toJson();

      expect(json.containsKey('id'), true);
      expect(json.containsKey('name'), true);
      expect(json.containsKey('latitude'), true);
      expect(json.containsKey('longitude'), true);
      expect(json.containsKey('amenities'), true);
      expect(json.containsKey('data_source'), true);
      expect(json.containsKey('data_quality_score'), true);
    });

    test('copyWith creates modified copy', () {
      final facility = TestData.facility();
      final updated = facility.copyWith(
        name: 'Updated Onsen',
        dataQualityScore: 5,
        amenities: {'sauna': false},
      );

      expect(updated.name, 'Updated Onsen');
      expect(updated.dataQualityScore, 5);
      expect(updated.amenities['sauna'], false);
      expect(updated.id, facility.id);
      expect(updated.latitude, facility.latitude);
    });

    test('copyWith preserves all fields when no overrides', () {
      final facility = TestData.facility();
      final copy = facility.copyWith();

      expect(copy.id, facility.id);
      expect(copy.name, facility.name);
      expect(copy.latitude, facility.latitude);
      expect(copy.longitude, facility.longitude);
      expect(copy.address, facility.address);
      expect(copy.amenities, facility.amenities);
    });

    test('Equatable equality based on props', () {
      final f1 = TestData.facility();
      final f2 = TestData.facility();
      expect(f1, equals(f2));

      final f3 = TestData.facility(id: 'different');
      expect(f1, isNot(equals(f3)));
    });

    test('Equatable works even when non-prop fields differ', () {
      final f1 = TestData.facility(address: 'Address A');
      final f2 = TestData.facility(address: 'Address B');
      // address is NOT in props, so they should be equal
      expect(f1, equals(f2));
    });
  });
}
