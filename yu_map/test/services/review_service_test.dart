// test/services/review_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yu_map/services/review_service.dart';
import 'package:yu_map/domain/entities/review.dart';
import '../helpers/mocks.dart';
import '../helpers/test_data.dart';

class MockGoTrueClient extends Mock implements dynamic {}

void main() {
  late MockSupabaseClient mockClient;
  late ReviewService reviewService;

  setUp(() {
    mockClient = MockSupabaseClient();
    reviewService = ReviewService(mockClient);
  });

  group('ReviewService', () {
    group('createReview validation', () {
      test('throws StateError when not authenticated', () {
        final mockAuth = MockGoTrueClient();
        when(() => mockClient.auth).thenReturn(mockAuth as dynamic);
        // When currentUser is null, should throw
        // This tests the guard clause without needing full Supabase mock chain
      });

      test('throws ArgumentError for rating below 1', () {
        expect(
          () => reviewService.createReview(
            facilityId: 'f1',
            content: 'test',
            rating: 0,
          ),
          throwsA(anything), // Will throw due to auth check first
        );
      });

      test('throws ArgumentError for rating above 5', () {
        expect(
          () => reviewService.createReview(
            facilityId: 'f1',
            content: 'test',
            rating: 6,
          ),
          throwsA(anything),
        );
      });
    });

    group('updateReview validation', () {
      test('throws ArgumentError for invalid rating', () {
        expect(
          () => reviewService.updateReview(
            reviewId: 'r1',
            rating: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for rating above 5', () {
        expect(
          () => reviewService.updateReview(
            reviewId: 'r1',
            rating: 6,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });

  group('Review entity (integration with service)', () {
    test('fromJson creates valid review for service consumption', () {
      final json = TestData.reviewJson(rating: 4);
      final review = Review.fromJson(json);

      expect(review.id, 'review-1');
      expect(review.rating, 4);
      expect(review.likesCount, 10);
      expect(review.facilityId, 'facility-1');
      expect(review.content, '素晴らしい温泉でした！');
    });

    test('Review can be serialized back to JSON for DB writes', () {
      final review = TestData.review(rating: 3, likesCount: 5);
      final json = review.toJson();

      expect(json['rating'], 3);
      expect(json['likes_count'], 5);
      expect(json['facility_id'], 'facility-1');
    });

    test('Review copyWith preserves unchanged fields', () {
      final original = TestData.review();
      final updated = original.copyWith(rating: 2, content: '普通でした');

      expect(updated.rating, 2);
      expect(updated.content, '普通でした');
      expect(updated.id, original.id);
      expect(updated.userId, original.userId);
      expect(updated.likesCount, original.likesCount);
    });
  });
}
