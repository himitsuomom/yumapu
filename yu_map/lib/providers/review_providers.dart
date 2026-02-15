// lib/providers/review_providers.dart
//
// Review-related state providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/providers/service_providers.dart';

/// Reviews for a specific facility.
final facilityReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, facilityId) async {
  final reviewService = ref.watch(reviewServiceProvider);
  return reviewService.getReviewsForFacility(facilityId);
});

/// Average rating for a specific facility.
final facilityAverageRatingProvider =
    FutureProvider.family<double, String>((ref, facilityId) async {
  final reviewService = ref.watch(reviewServiceProvider);
  return reviewService.getAverageRating(facilityId);
});

/// Notifier for review CRUD actions.
class ReviewActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ReviewActionNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<Review?> submitReview({
    required String facilityId,
    required String content,
    required int rating,
  }) async {
    state = const AsyncValue.loading();
    Review? result;
    state = await AsyncValue.guard(() async {
      result = await _ref.read(reviewServiceProvider).createReview(
            facilityId: facilityId,
            content: content,
            rating: rating,
          );
      // Invalidate the reviews list so it refetches
      _ref.invalidate(facilityReviewsProvider(facilityId));
      _ref.invalidate(facilityAverageRatingProvider(facilityId));
    });
    return result;
  }

  Future<void> deleteReview(String reviewId, String facilityId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref.read(reviewServiceProvider).deleteReview(reviewId);
      _ref.invalidate(facilityReviewsProvider(facilityId));
      _ref.invalidate(facilityAverageRatingProvider(facilityId));
    });
  }

  Future<int> toggleLike(String reviewId, {required bool isLiked}) async {
    return _ref.read(reviewServiceProvider).toggleLike(
          reviewId,
          isLiked: isLiked,
        );
  }
}

final reviewActionProvider =
    StateNotifierProvider<ReviewActionNotifier, AsyncValue<void>>(
  (ref) => ReviewActionNotifier(ref),
);
