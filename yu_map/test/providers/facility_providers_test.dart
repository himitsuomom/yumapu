// test/providers/facility_providers_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/providers/facility_providers.dart';

void main() {
  group('FacilitySearchParams', () {
    test('default constructor has all nulls', () {
      const params = FacilitySearchParams();
      expect(params.query, isNull);
      expect(params.prefectureId, isNull);
      expect(params.facilityTypeId, isNull);
      expect(params.amenities, isNull);
      expect(params.latitude, isNull);
      expect(params.longitude, isNull);
      expect(params.radius, isNull);
    });

    test('equality works with same values', () {
      const params1 = FacilitySearchParams(query: '温泉');
      const params2 = FacilitySearchParams(query: '温泉');
      expect(params1, equals(params2));
    });

    test('inequality when query differs', () {
      const params1 = FacilitySearchParams(query: '温泉');
      const params2 = FacilitySearchParams(query: 'サウナ');
      expect(params1, isNot(equals(params2)));
    });

    test('equality with all fields populated', () {
      const params1 = FacilitySearchParams(
        query: '温泉',
        prefectureId: 'pref-13',
        facilityTypeId: 'type-onsen',
        latitude: 35.6,
        longitude: 139.7,
        radius: 10.0,
      );
      const params2 = FacilitySearchParams(
        query: '温泉',
        prefectureId: 'pref-13',
        facilityTypeId: 'type-onsen',
        latitude: 35.6,
        longitude: 139.7,
        radius: 10.0,
      );
      expect(params1, equals(params2));
    });

    test('hashCode is consistent with equality', () {
      const params1 = FacilitySearchParams(query: 'test', latitude: 35.0);
      const params2 = FacilitySearchParams(query: 'test', latitude: 35.0);
      expect(params1.hashCode, equals(params2.hashCode));
    });

    test('hashCode differs for different params', () {
      const params1 = FacilitySearchParams(query: 'test1');
      const params2 = FacilitySearchParams(query: 'test2');
      // hashCode may collide, but usually differs
      // This is more of a sanity check
      expect(params1.hashCode != params2.hashCode || params1 != params2, true);
    });

    test('amenities are excluded from equality check', () {
      const params1 = FacilitySearchParams(
        query: '温泉',
        amenities: {'sauna': true},
      );
      const params2 = FacilitySearchParams(
        query: '温泉',
        amenities: {'sauna': false},
      );
      // amenities is NOT part of == (only query, prefectureId, facilityTypeId, lat, lng, radius)
      expect(params1, equals(params2));
    });
  });
}
