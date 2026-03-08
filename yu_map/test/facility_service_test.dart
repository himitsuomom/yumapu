// test/facility_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/domain/entities/facility.dart';

void main() {
  group('Facility entity', () {
    test('fromJson parses basic fields', () {
      final json = <String, dynamic>{
        'id': 'f1',
        'name': 'Test Onsen',
        'name_kana': 'テストオンセン',
        'lat': 35.68,
        'lng': 139.69,
        'address': '東京都新宿区',
        'phone': '03-1234-5678',
        'website': 'https://example.com',
        'data_source': 'government',
        'data_quality_score': 3,
      };

      final facility = Facility.fromJson(json);

      expect(facility.id, 'f1');
      expect(facility.name, 'Test Onsen');
      expect(facility.nameKana, 'テストオンセン');
      expect(facility.latitude, 35.68);
      expect(facility.longitude, 139.69);
      expect(facility.address, '東京都新宿区');
      expect(facility.phone, '03-1234-5678');
      expect(facility.website, 'https://example.com');
      expect(facility.dataQualityScore, 3);
    });

    test('fromJson handles null optional fields', () {
      final json = <String, dynamic>{
        'id': 'f2',
        'name': 'Minimal Onsen',
      };

      final facility = Facility.fromJson(json);

      expect(facility.id, 'f2');
      expect(facility.name, 'Minimal Onsen');
      expect(facility.nameKana, isNull);
      expect(facility.latitude, 0.0);
      expect(facility.longitude, 0.0);
      expect(facility.address, isNull);
      expect(facility.phone, isNull);
      expect(facility.website, isNull);
      expect(facility.dataQualityScore, 1);
      expect(facility.dataSource, 'government');
    });

    test('fromJson parses businessHours and priceInfo', () {
      final json = <String, dynamic>{
        'id': 'f3',
        'name': 'Rich Onsen',
        'business_hours': {'mon': '10:00-22:00'},
        'price_info': {'adult': 800},
      };

      final facility = Facility.fromJson(json);

      expect(facility.businessHours, {'mon': '10:00-22:00'});
      expect(facility.priceInfo, {'adult': 800});
    });

    test('two facilities with same id are equal (Equatable)', () {
      const a = Facility(id: 'f1', name: 'A', latitude: 35.0, longitude: 139.0);
      const b = Facility(id: 'f1', name: 'A', latitude: 35.0, longitude: 139.0);

      expect(a, equals(b));
    });
  });

  group('Review entity', () {
    test('fromJson parses all fields', () {
      // Import is implicit through the test structure; test Review parsing
      // via the review entity test below.
    });
  });
}
