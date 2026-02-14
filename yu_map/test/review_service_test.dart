// test/review_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/services/review_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late ReviewService reviewService;
  late MockSupabaseClient mockClient;

  setUp(() {
    mockClient = MockSupabaseClient();
    reviewService = ReviewService(mockClient);
  });

  group('ReviewService Tests', () {
    test('should submit a review successfully', () async {
      // Arrange
      const userId = 'user123';
      const facilityId = 'facility456';
      const content = 'Great experience!';
      const rating = 5;
      const photos = <dynamic>[];

      // Act
      final result = await reviewService.submitReview(
        userId: userId,
        facilityId: facilityId,
        content: content,
        rating: rating,
        photos: photos,
      );

      // Assert
      expect(result, 'mock-review-id');
    });

    test('should fetch reviews for a facility', () async {
      // Arrange
      const facilityId = 'facility456';

      // Act
      final result = await reviewService.getReviewsForFacility(facilityId);

      // Assert
      expect(result, isA<List>());
    });

    test('should toggle like on a review', () async {
      // Arrange
      const reviewId = 'review123';
      const userId = 'user123';

      // Act
      await reviewService.toggleLikeReview(reviewId, userId);

      // Assert - Verify the method was called
      // This would typically involve verifying interactions with the mock client
    });
  });
}

// Mock classes for testing
class MockSupabaseClient implements SupabaseClient {
  @override
  FunctionsClient get functions => MockFunctionsClient();

  @override
  StorageClient get storage => MockStorageClient();

  @override
  PostgrestClient from(String table) => MockPostgrestClient();

  @override
  AuthClient get auth => throw UnimplementedError();

  @override
  RealtimeChannel channel(String topic, {Map<String, dynamic>? config}) =>
      throw UnimplementedError();

  @override
  void removeChannel(RealtimeChannel channel) {
    throw UnimplementedError();
  }

  @override
  void removeAllChannels() {
    throw UnimplementedError();
  }

  @override
  Future<void> close() {
    throw UnimplementedError();
  }

  @override
  Future<void> removeSubscription(RealtimeChannel channel) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeAllSubscriptions() {
    throw UnimplementedError();
  }
}

class MockFunctionsClient implements FunctionsClient {
  @override
  Future<FunctionInvokeResponse> invoke(
    String functionName, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    return FunctionInvokeResponse(data: 'success', error: null);
  }
}

class MockStorageClient implements StorageClient {
  @override
  StorageFileApi from(String bucket) => MockStorageFileApi();
}

class MockStorageFileApi implements StorageFileApi {
  @override
  Future<UploadResponse> upload(String path, dynamic file, {FileOptions? fileOptions}) async {
    return UploadResponse(path: path);
  }
}

class MockPostgrestClient implements PostgrestClient {
  @override
  PostgrestQueryBuilder from(String table) => MockPostgrestQueryBuilder();
}

class MockPostgrestQueryBuilder implements PostgrestQueryBuilder {
  @override
  Future<PostgrestResponse> select([
    String? columns,
    {
      String? head,
      bool count,
    },
  ]) async {
    return PostgrestResponse(
      data: [
        {
          'id': 'mock-review-id',
          'user_id': 'user123',
          'facility_id': 'facility456',
          'content': 'Great experience!',
          'rating': 5,
          'created_at': DateTime.now().toIso8601String(),
        }
      ],
      count: 1,
      status: 200,
      statusText: 'OK',
    );
  }

  @override
  PostgrestFilterBuilder insert(dynamic values, {bool returning = true}) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder update(dynamic values, {bool returning = true}) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder delete({bool returning = true}) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder selectOne([
    String? columns, {
      bool returning = true,
    },
  ]) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder eq(String column, dynamic value) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder neq(String column, dynamic value) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder gt(String column, dynamic value) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder gte(String column, dynamic value) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder lt(String column, dynamic value) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder lte(String column, dynamic value) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder like(String column, String pattern) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder ilike(String column, String pattern) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder isNull(String column) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder not(String column, String operator, dynamic value) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder inSet(String column, Set<dynamic> values) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder contains(String column, dynamic value) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder containedBy(String column, dynamic value) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder rangeGt(String column, dynamic range) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder rangeGte(String column, dynamic range) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder rangeLt(String column, dynamic range) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder rangeLte(String column, dynamic range) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder rangeAdjacent(String column, dynamic range) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder overlaps(String column, dynamic range) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder textSearch(
    String column,
    String query, {
    TextSearchType type = TextSearchType.plain,
    String? config,
  }) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder order(
    String column, {
    bool ascending = true,
    bool nullsFirst = false,
    String? foreignTable,
  }) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder limit(
    int count, {
    String? foreignTable,
  }) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder range(
    int from,
    int to, {
    String? foreignTable,
  }) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder single() {
    return MockPostgrestFilterBuilder();
  }
}

class MockPostgrestFilterBuilder implements PostgrestFilterBuilder {
  @override
  Future<PostgrestResponse> select([
    String? columns,
    {
      String? head,
      bool count,
    },
  ]) async {
    return PostgrestResponse(
      data: [
        {
          'id': 'mock-review-id',
          'user_id': 'user123',
          'facility_id': 'facility456',
          'content': 'Great experience!',
          'rating': 5,
          'created_at': DateTime.now().toIso8601String(),
        }
      ],
      count: 1,
      status: 200,
      statusText: 'OK',
    );
  }

  @override
  Future<PostgrestResponse> insert(dynamic values, {bool returning = true}) async {
    return PostgrestResponse(
      data: [
        {'id': 'mock-review-id'}
      ],
      count: 1,
      status: 201,
      statusText: 'Created',
    );
  }

  @override
  Future<PostgrestResponse> update(dynamic values, {bool returning = true}) async {
    return PostgrestResponse(
      data: [],
      count: 0,
      status: 200,
      statusText: 'OK',
    );
  }

  @override
  Future<PostgrestResponse> delete({bool returning = true}) async {
    return PostgrestResponse(
      data: [],
      count: 0,
      status: 200,
      statusText: 'OK',
    );
  }

  @override
  PostgrestFilterBuilder eq(String column, dynamic value) => this;

  @override
  PostgrestFilterBuilder neq(String column, dynamic value) => this;

  @override
  PostgrestFilterBuilder gt(String column, dynamic value) => this;

  @override
  PostgrestFilterBuilder gte(String column, dynamic value) => this;

  @override
  PostgrestFilterBuilder lt(String column, dynamic value) => this;

  @override
  PostgrestFilterBuilder lte(String column, dynamic value) => this;

  @override
  PostgrestFilterBuilder like(String column, String pattern) => this;

  @override
  PostgrestFilterBuilder ilike(String column, String pattern) => this;

  @override
  PostgrestFilterBuilder isNull(String column) => this;

  @override
  PostgrestFilterBuilder not(String column, String operator, dynamic value) => this;

  @override
  PostgrestFilterBuilder inSet(String column, Set<dynamic> values) => this;

  @override
  PostgrestFilterBuilder contains(String column, dynamic value) => this;

  @override
  PostgrestFilterBuilder containedBy(String column, dynamic value) => this;

  @override
  PostgrestFilterBuilder rangeGt(String column, dynamic range) => this;

  @override
  PostgrestFilterBuilder rangeGte(String column, dynamic range) => this;

  @override
  PostgrestFilterBuilder rangeLt(String column, dynamic range) => this;

  @override
  PostgrestFilterBuilder rangeLte(String column, dynamic range) => this;

  @override
  PostgrestFilterBuilder rangeAdjacent(String column, dynamic range) => this;

  @override
  PostgrestFilterBuilder overlaps(String column, dynamic range) => this;

  @override
  PostgrestFilterBuilder textSearch(
    String column,
    String query, {
    TextSearchType type = TextSearchType.plain,
    String? config,
  }) => this;

  @override
  PostgrestFilterBuilder order(
    String column, {
    bool ascending = true,
    bool nullsFirst = false,
    String? foreignTable,
  }) => this;

  @override
  PostgrestFilterBuilder limit(
    int count, {
    String? foreignTable,
  }) => this;

  @override
  PostgrestFilterBuilder range(
    int from,
    int to, {
    String? foreignTable,
  }) => this;

  @override
  PostgrestFilterBuilder single() => this;
}

class FunctionInvokeResponse {
  final dynamic data;
  final dynamic error;

  FunctionInvokeResponse({this.data, this.error});
}

class UploadResponse {
  final String path;

  UploadResponse({required this.path});
}

class PostgrestResponse {
  final List<dynamic> data;
  final int? count;
  final int status;
  final String? statusText;

  PostgrestResponse({
    required this.data,
    this.count,
    required this.status,
    this.statusText,
  });
}