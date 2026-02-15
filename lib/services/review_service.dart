// lib/services/review_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/review.dart';

class ReviewService {
  final SupabaseClient _client;

  ReviewService(this._client);

  /// Toggle like status for a review
  /// Updates the local cache immediately and syncs with backend
  Future<bool> toggleReviewLike(String reviewId, {bool? isCurrentlyLiked}) async {
    try {
      // In a real implementation, you would make the API call to update the like status
      // This is a simplified version that would actually interact with your Supabase backend
      
      // If we know the current like status, we can optimize the approach
      bool newLikedStatus;
      if (isCurrentlyLiked != null) {
        newLikedStatus = !isCurrentlyLiked;
      } else {
        // Otherwise, fetch the current status or maintain client-side state
        // For now, we'll assume it's a toggle from whatever the client thinks the current state is
        newLikedStatus = !(await isReviewLikedByCurrentUser(reviewId));
      }

      // Make API call to update like status
      final response = await _client
          .from('review_likes')
          .upsert({
            'review_id': reviewId,
            'user_id': await getCurrentUserId(), // You'd need to implement this
            'liked': newLikedStatus,
            'created_at': DateTime.now().toIso8601String()
          })
          .select();

      if (response.error != null) {
        throw Exception('Failed to toggle like: ${response.error?.message}');
      }

      // Update the review's like count as well
      if (newLikedStatus) {
        await _client
            .from('reviews')
            .update({'likes_count': await getReviewLikeCount(reviewId) + 1})
            .eq('id', reviewId);
      } else {
        await _client
            .from('reviews')
            .update({'likes_count': (await getReviewLikeCount(reviewId) - 1).clamp(0, 999999)})
            .eq('id', reviewId);
      }

      return newLikedStatus;
    } catch (e) {
      print('Error toggling review like: $e');
      rethrow;
    }
  }

  /// Check if a review is liked by the current user
  Future<bool> isReviewLikedByCurrentUser(String reviewId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return false;
      }

      final response = await _client
          .from('review_likes')
          .select('liked')
          .eq('review_id', reviewId)
          .eq('user_id', user.id)
          .single();

      return response['liked'] ?? false;
    } catch (e) {
      // If no record found, the review isn't liked
      return false;
    }
  }

  /// Get the total like count for a review
  Future<int> getReviewLikeCount(String reviewId) async {
    try {
      final response = await _client
          .from('reviews')
          .select('likes_count')
          .eq('id', reviewId)
          .single();
          
      return (response['likes_count'] as int?) ?? 0;
    } catch (e) {
      print('Error getting review like count: $e');
      return 0;
    }
  }

  /// Get the like status for multiple reviews at once
  Future<Map<String, bool>> getReviewsLikeStatus(List<String> reviewIds) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return {for (var id in reviewIds) id: false};
      }

      final response = await _client
          .from('review_likes')
          .select('review_id, liked')
          .inFilter('review_id', reviewIds)
          .eq('user_id', user.id);

      final Map<String, bool> result = {};
      
      for (final reviewId in reviewIds) {
        final record = response.data?.firstWhere(
          (element) => element['review_id'] == reviewId,
          orElse: () => null,
        );
        
        result[reviewId] = record?['liked'] ?? false;
      }

      return result;
    } catch (e) {
      print('Error getting reviews like status: $e');
      return {for (var id in reviewIds) id: false};
    }
  }

  /// Get current user ID utility method
  Future<String> getCurrentUserId() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.id;
  }
}