// lib/services/review_service.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/review.dart';

class ReviewService {
  final SupabaseClient _client;

  ReviewService(this._client);

  /// Submit a new review with optional photos
  Future<String> submitReview({
    required String userId,
    required String facilityId,
    required String content,
    required int rating,
    List<Uint8List>? photos,
  }) async {
    try {
      // Insert the review into the database
      final response = await _client
          .from('reviews')
          .insert({
            'user_id': userId,
            'facility_id': facilityId,
            'content': content,
            'rating': rating,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id');

      final reviewId = response[0]['id'] as String;

      // If photos are provided, upload them
      if (photos != null && photos.isNotEmpty) {
        for (int i = 0; i < photos.length; i++) {
          await _client.storage
              .from('reviews')
              .upload('$reviewId/photo_$i.jpg', photos[i], fileOptions: FileOptions(upsert: true));
        }
      }

      // Trigger the edge function to recalculate rankings
      await _client.functions.invoke('verify-contribution', body: {
        'review_id': reviewId,
        'user_id': userId,
        'points': rating > 0 ? (rating >= 4 ? 10 : 5) : 0, // Points based on rating
      });

      return reviewId;
    } catch (e) {
      throw Exception('Failed to submit review: $e');
    }
  }

  /// Get reviews for a specific facility
  Future<List<Review>> getReviewsForFacility(String facilityId) async {
    try {
      final response = await _client
          .from('reviews')
          .select('*, users(username, avatar_url)')
          .eq('facility_id', facilityId)
          .order('created_at', ascending: false);

      return response.map((json) => Review.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch reviews: $e');
    }
  }

  /// Like/unlike a review
  Future<void> toggleLikeReview(String reviewId, String userId) async {
    try {
      final response = await _client
          .from('review_likes')
          .select()
          .eq('review_id', reviewId)
          .eq('user_id', userId);

      if (response.isEmpty) {
        // Add like
        await _client.from('review_likes').insert({
          'review_id': reviewId,
          'user_id': userId,
        });
      } else {
        // Remove like
        await _client.from('review_likes').delete().eq('review_id', reviewId).eq('user_id', userId);
      }
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  /// Check if a user liked a particular review
  Future<bool> hasUserLikedReview(String reviewId, String userId) async {
    try {
      final response = await _client
          .from('review_likes')
          .select()
          .eq('review_id', reviewId)
          .eq('user_id', userId);

      return response.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check like status: $e');
    }
  }
}