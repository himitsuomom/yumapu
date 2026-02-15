// lib/services/review_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/review.dart';

/// Service for managing facility reviews (CRUD + likes).
class ReviewService {
  final SupabaseClient _client;

  ReviewService(this._client);

  /// Fetch reviews for a facility, ordered by newest first.
  Future<List<Review>> getReviewsForFacility(
    String facilityId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('reviews')
          .select('*, users(username, display_name, avatar_url)')
          .eq('facility_id', facilityId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map<Review>((row) => Review.fromJson(row)).toList();
    } catch (e) {
      debugPrint('ReviewService.getReviewsForFacility error: $e');
      rethrow;
    }
  }

  /// Submit a new review.
  Future<Review> createReview({
    required String facilityId,
    required String content,
    required int rating,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5');
    }

    final response = await _client
        .from('reviews')
        .insert({
          'user_id': userId,
          'facility_id': facilityId,
          'content': content,
          'rating': rating,
        })
        .select()
        .single();

    return Review.fromJson(response);
  }

  /// Update an existing review (only the owner can do this via RLS).
  Future<Review> updateReview({
    required String reviewId,
    String? content,
    int? rating,
  }) async {
    final updates = <String, dynamic>{};
    if (content != null) updates['content'] = content;
    if (rating != null) {
      if (rating < 1 || rating > 5) {
        throw ArgumentError('Rating must be between 1 and 5');
      }
      updates['rating'] = rating;
    }

    final response = await _client
        .from('reviews')
        .update(updates)
        .eq('id', reviewId)
        .select()
        .single();

    return Review.fromJson(response);
  }

  /// Delete a review.
  Future<void> deleteReview(String reviewId) async {
    await _client.from('reviews').delete().eq('id', reviewId);
  }

  /// Toggle like on a review (increment / decrement `likes_count` via RPC or simple update).
  /// For a production app a `review_likes` join table is recommended.
  Future<int> toggleLike(String reviewId, {required bool isLiked}) async {
    // Simple optimistic implementation: adjust the counter directly.
    // In production, use a join table + DB function for accuracy.
    final response = await _client
        .from('reviews')
        .select('likes_count')
        .eq('id', reviewId)
        .single();

    final currentCount = response['likes_count'] as int? ?? 0;
    final newCount = isLiked
        ? (currentCount > 0 ? currentCount - 1 : 0)
        : currentCount + 1;

    await _client
        .from('reviews')
        .update({'likes_count': newCount})
        .eq('id', reviewId);

    return newCount;
  }

  /// Get the average rating for a facility.
  Future<double> getAverageRating(String facilityId) async {
    final response = await _client
        .from('reviews')
        .select('rating')
        .eq('facility_id', facilityId);

    if (response.isEmpty) return 0.0;

    final total = response.fold<int>(0, (sum, row) => sum + (row['rating'] as int));
    return total / response.length;
  }
}
