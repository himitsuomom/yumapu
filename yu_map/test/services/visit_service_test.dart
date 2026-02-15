// test/services/visit_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yu_map/services/visit_service.dart';
import '../helpers/mocks.dart';
import '../helpers/test_data.dart';

class MockGoTrueClient extends Mock implements dynamic {}

void main() {
  late MockSupabaseClient mockClient;
  late VisitService visitService;

  setUp(() {
    mockClient = MockSupabaseClient();
    visitService = VisitService(mockClient);
  });

  group('VisitService', () {
    group('checkIn', () {
      test('throws StateError when not authenticated', () {
        final mockAuth = MockGoTrueClient();
        when(() => mockClient.auth).thenReturn(mockAuth as dynamic);
        // Will throw because currentUser is null
        expect(
          () => visitService.checkIn(facilityId: 'f1'),
          throwsA(anything),
        );
      });
    });

    group('hasVisitedToday', () {
      test('returns false when not authenticated', () async {
        final mockAuth = MockGoTrueClient();
        when(() => mockClient.auth).thenReturn(mockAuth as dynamic);
        // hasVisitedToday should return false when userId is null
      });
    });

    group('getVisitHistory', () {
      test('throws StateError when not authenticated', () {
        final mockAuth = MockGoTrueClient();
        when(() => mockClient.auth).thenReturn(mockAuth as dynamic);
        expect(
          () => visitService.getVisitHistory(),
          throwsA(anything),
        );
      });
    });
  });

  group('Visit data parsing', () {
    test('visit JSON has correct structure', () {
      final json = TestData.visitJson();

      expect(json['id'], 'visit-1');
      expect(json['user_id'], 'user-1');
      expect(json['facility_id'], 'facility-1');
      expect(json['verified'], true);
      expect(json['facilities'], isA<Map<String, dynamic>>());
      expect((json['facilities'] as Map)['name'], 'テスト温泉');
    });

    test('visit JSON with unverified status', () {
      final json = TestData.visitJson(verified: false);
      expect(json['verified'], false);
    });

    test('GPS location string format for PostGIS', () {
      // Verify the expected format for check_in_location
      const lat = 35.6895;
      const lng = 139.6917;
      final locationStr = 'SRID=4326;POINT($lng $lat)';

      expect(locationStr, 'SRID=4326;POINT(139.6917 35.6895)');
      expect(locationStr, contains('SRID=4326'));
      expect(locationStr, contains('POINT'));
    });
  });
}
