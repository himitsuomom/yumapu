// lib/domain/repositories/i_review_repository.dart
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/domain/entities/review.dart';

abstract interface class IReviewRepository {
  Future<Result<List<Review>>> getReviewsByFacility(String facilityId,
      {int limit = 20, int offset = 0});
  Future<Result<Review?>> getUserReviewForFacility(String facilityId);
  Future<Result<Review>> createReview({
    required String facilityId,
    required double rating,
    required String content,
  });
  Future<Result<void>> updateReview(String reviewId,
      {double? rating, String? content});
  Future<Result<void>> deleteReview(String reviewId);
  Future<Result<void>> likeReview(String reviewId);
  Future<Result<void>> unlikeReview(String reviewId);
}
