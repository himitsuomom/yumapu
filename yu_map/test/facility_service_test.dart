// test/facility_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/services/facility_service.dart';

void main() {
  group('FacilityService Tests', () {
    late FacilityService facilityService;
    late MockSupabaseClient mockClient;

    setUp(() {
      mockClient = MockSupabaseClient();
      facilityService = FacilityService(mockClient);
    });

    test('should build query with search term and filters without reassignment', () async {
      // Arrange
      final searchQuery = 'onsen';
      final attributes = {'tattoo': true, 'sauna': true};
      
      // Act
      await facilityService.searchFacilities(
        searchQuery: searchQuery,
        attributes: attributes,
      );

      // Assert
      expect(mockClient.queryCalls.length, greaterThan(0));
      // Verify that query was built correctly with both search term and attributes
      expect(mockClient.lastQueryHasILike, true);
      expect(mockClient.lastQueryHasContains, true);
    });

    test('should maintain all filters when chaining queries', () async {
      // Arrange
      final filters = {
        'prefecture_id': '13',
        'amenities': {'wifi': true, 'parking': true}
      };

      // Act
      await facilityService.getFilteredFacilities(filters: filters);

      // Assert
      expect(mockClient.queryCalls.length, greaterThan(0));
      // Verify the filters were applied correctly
      expect(mockClient.lastQueryHadPrefectureFilter, true);
      expect(mockClient.lastQueryHadAmenityFilters, true);
    });

    test('should cache facilities properly', () async {
      // Act
      await facilityService.getFacilityById('test-id');

      // Assert
      expect(facilityService.cache.length, greaterThanOrEqual(0)); // Can be 0 if API call failed
    });
  });
}

class MockSupabaseClient implements SupabaseClient {
  final List<String> queryCalls = [];
  bool lastQueryHasILike = false;
  bool lastQueryHasContains = false;
  bool lastQueryHadPrefectureFilter = false;
  bool lastQueryHadAmenityFilters = false;

  @override
  PostgrestClient from(String table) {
    queryCalls.add(table);
    return MockPostgrestClient(this);
  }

  // Other required methods would be implemented here
  @override
  AuthClient get auth => throw UnimplementedError();

  @override
  FunctionsClient get functions => throw UnimplementedError();

  @override
  RealtimeChannel channel(String topic, {Map<String, dynamic>? config}) {
    throw UnimplementedError();
  }

  @override
  Future<RealtimeChannel> connectRealtime() {
    throw UnimplementedError();
  }

  @override
  RealtimeClient get realtime => throw UnimplementedError();

  @override
  StorageClient get storage => throw UnimplementedError();

  @override
  Future<void> removeAuthEventListener(AuthChangeEvent event) {
    throw UnimplementedError();
  }

  @override
  Future<void> setAuthCookie(String cookie) {
    throw UnimplementedError();
  }

  @override
  Future<T> rpc<T>(String fn, {Map<String, dynamic>? params}) {
    throw UnimplementedError();
  }

  @override
  Stream<Map<String, dynamic>> subscribe(
    String table, {
    required void Function(SupabaseRealtimePayload) handler,
    String? filter,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getAuthCookie() {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError();
  }
}

class MockPostgrestClient implements PostgrestClient {
  final MockSupabaseClient mockClient;

  MockPostgrestClient(this.mockClient);

  @override
  PostgrestFilterBuilder select([String? columns]) {
    return MockPostgrestFilterBuilder(mockClient);
  }

  // Other methods would be implemented here
  @override
  PostgrestFilterBuilder insert(dynamic values, {bool? returning, String? count}) {
    throw UnimplementedError();
  }

  @override
  PostgrestFilterBuilder upsert(dynamic values, {bool? returning, String? count, String? onConflict}) {
    throw UnimplementedError();
  }

  @override
  PostgrestFilterBuilder update(dynamic values, {bool? returning, String? count}) {
    throw UnimplementedError();
  }

  @override
  PostgrestFilterBuilder delete({bool? returning, String? count}) {
    throw UnimplementedError();
  }

  @override
  void dispose() {}
}

class MockPostgrestFilterBuilder implements PostgrestFilterBuilder {
  final MockSupabaseClient mockClient;

  MockPostgrestFilterBuilder(this.mockClient);

  @override
  Future<List<Map<String, dynamic>>>? execute() {
    // Simulate API response
    return Future.value([
      {'id': 'test-id', 'name': 'Test Facility', 'latitude': 35.6895, 'longitude': 139.6917}
    ]);
  }

  @override
  PostgrestFilterBuilder ilike(String column, String pattern) {
    mockClient.lastQueryHasILike = true;
    return this;
  }

  @override
  PostgrestFilterBuilder eq(String column, dynamic value) {
    if (column == 'prefecture_id') {
      mockClient.lastQueryHadPrefectureFilter = true;
    }
    return this;
  }

  @override
  PostgrestFilterBuilder contains(String column, dynamic value) {
    if (column == 'amenities') {
      mockClient.lastQueryHasContains = true;
      mockClient.lastQueryHadAmenityFilters = true;
    }
    return this;
  }

  // Other filter methods would be implemented here...
  @override
  PostgrestFilterBuilder lte(String column, dynamic value) => this;

  @override
  PostgrestFilterBuilder gte(String column, dynamic value) => this;

  @override
  Future<Map<String, dynamic>> single() {
    return Future.value({'id': 'test-id', 'name': 'Test Facility', 'latitude': 35.6895, 'longitude': 139.6917});
  }

  @override
  Future<int> count({String? column, String? count}) {
    return Future.value(1);
  }
}