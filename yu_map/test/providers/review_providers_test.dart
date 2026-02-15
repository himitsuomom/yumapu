// test/providers/review_providers_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yu_map/providers/review_providers.dart';
import 'package:yu_map/providers/service_providers.dart';
import '../helpers/mocks.dart';
import '../helpers/test_data.dart';

void main() {
  group('ReviewActionNotifier', () {
    late ProviderContainer container;
    late MockReviewService mockReviewService;

    setUp(() {
      mockReviewService = MockReviewService();
      container = ProviderContainer(
        overrides: [
          reviewServiceProvider.overrideWithValue(mockReviewService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is AsyncData(null)', () {
      final state = container.read(reviewActionProvider);
      expect(state, isA<AsyncData<void>>());
    });

    test('submitReview calls service and returns review', () async {
      final review = TestData.review();
      when(() => mockReviewService.createReview(
            facilityId: any(named: 'facilityId'),
            content: any(named: 'content'),
            rating: any(named: 'rating'),
          )).thenAnswer((_) async => review);

      final notifier = container.read(reviewActionProvider.notifier);
      final result = await notifier.submitReview(
        facilityId: 'facility-1',
        content: '最高！',
        rating: 5,
      );

      expect(result, isNotNull);
      expect(result!.rating, 5);
      verify(() => mockReviewService.createReview(
            facilityId: 'facility-1',
            content: '最高！',
            rating: 5,
          )).called(1);
    });

    test('submitReview handles error gracefully', () async {
      when(() => mockReviewService.createReview(
            facilityId: any(named: 'facilityId'),
            content: any(named: 'content'),
            rating: any(named: 'rating'),
          )).thenThrow(Exception('Network error'));

      final notifier = container.read(reviewActionProvider.notifier);
      final result = await notifier.submitReview(
        facilityId: 'facility-1',
        content: 'test',
        rating: 3,
      );

      expect(result, isNull);
      final state = container.read(reviewActionProvider);
      expect(state.hasError, true);
    });

    test('deleteReview calls service with correct ID', () async {
      when(() => mockReviewService.deleteReview(any()))
          .thenAnswer((_) async {});

      final notifier = container.read(reviewActionProvider.notifier);
      await notifier.deleteReview('review-1', 'facility-1');

      verify(() => mockReviewService.deleteReview('review-1')).called(1);
    });

    test('toggleLike calls service and returns new count', () async {
      when(() => mockReviewService.toggleLike(
            any(),
            isLiked: any(named: 'isLiked'),
          )).thenAnswer((_) async => 11);

      final notifier = container.read(reviewActionProvider.notifier);
      final newCount = await notifier.toggleLike(
        'review-1',
        isLiked: false,
      );

      expect(newCount, 11);
    });
  });
}
