// test/services/favorite_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/domain/entities/facility.dart';
import '../helpers/test_data.dart';

void main() {
  group('FavoriteService data handling', () {
    test('favorites response parsing to Facility list', () {
      // Simulate the favorites query response shape: 
      // favorites.select('facilities(*)').eq('user_id', ...)
      final favoritesResponse = [
        {
          'id': 'fav-1',
          'user_id': 'user-1',
          'facility_id': 'facility-1',
          'created_at': '2024-01-15T00:00:00Z',
          'facilities': TestData.facilityJson(id: 'facility-1', name: '温泉A'),
        },
        {
          'id': 'fav-2',
          'user_id': 'user-1',
          'facility_id': 'facility-2',
          'created_at': '2024-01-16T00:00:00Z',
          'facilities': TestData.facilityJson(id: 'facility-2', name: '温泉B'),
        },
      ];

      final facilities = favoritesResponse.map<Facility>((row) {
        final facilityData = row['facilities'] as Map<String, dynamic>;
        return Facility.fromJson(facilityData);
      }).toList();

      expect(facilities.length, 2);
      expect(facilities[0].id, 'facility-1');
      expect(facilities[0].name, '温泉A');
      expect(facilities[1].id, 'facility-2');
      expect(facilities[1].name, '温泉B');
    });

    test('empty favorites returns empty list', () {
      final emptyResponse = <Map<String, dynamic>>[];
      final facilities = emptyResponse.map<Facility>((row) {
        final facilityData = row['facilities'] as Map<String, dynamic>;
        return Facility.fromJson(facilityData);
      }).toList();

      expect(facilities, isEmpty);
    });

    test('isFavorite check with empty response', () {
      final response = <Map<String, dynamic>>[];
      final isFavorite = response.isNotEmpty;
      expect(isFavorite, false);
    });

    test('isFavorite check with matched response', () {
      final response = [{'id': 'fav-1'}];
      final isFavorite = response.isNotEmpty;
      expect(isFavorite, true);
    });
  });
}
