// lib/providers/review_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/services/review_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// StateNotifier to manage individual review like states
class ReviewLikeStateNotifier extends StateNotifier<Map<String, int>> {
  ReviewLikeStateNotifier(int initialCount) : super(const {});

  void updateLikeCount(String reviewId, int newCount) {
    state = {...state, reviewId: newCount};
  }

  void incrementLikeCount(String reviewId) {
    final currentCount = state[reviewId] ?? 0;
    state = {...state, reviewId: currentCount + 1};
  }

  void decrementLikeCount(String reviewId) {
    final currentCount = state[reviewId] ?? 0;
    if (currentCount > 0) {
      state = {...state, reviewId: currentCount - 1};
    }
  }

  void reset() {
    state = const {};
  }
}

// AsyncNotifier to handle asynchronous like toggling with backend integration
class ReviewLikeNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> toggleReviewLike(
    String reviewId, 
    ReviewService reviewService,
    Ref ref,
  ) async {
    // Get the current state to determine if the review is currently liked
    final currentReviewState = ref.read(reviewWithLikeStateProvider(
      ref.read(reviewsListProvider).firstWhere((r) => r.id == reviewId)
    ));

    // Toggle the local state immediately for UX
    if (currentReviewState.isLikedByCurrentUser) {
      ref.read(userLikedReviewsProvider.notifier).removeReview(reviewId);
      ref.read(reviewLikeStateProvider.notifier).decrementLikeCount(reviewId);
    } else {
      ref.read(userLikedReviewsProvider.notifier).addReview(reviewId);
      ref.read(reviewLikeStateProvider.notifier).incrementLikeCount(reviewId);
    }

    // Actually update the backend
    try {
      final newLikedStatus = !currentReviewState.isLikedByCurrentUser;
      final updatedLikedStatus = await reviewService.toggleReviewLike(
        reviewId, 
        isCurrentlyLiked: currentReviewState.isLikedByCurrentUser
      );

      // The service call may have resulted in a different state than expected
      // Update our local state to match the actual backend state
      if (updatedLikedStatus != currentReviewState.isLikedByCurrentUser) {
        ref.read(userLikedReviewsProvider.notifier).addReview(reviewId);
      } else {
        ref.read(userLikedReviewsProvider.notifier).removeReview(reviewId);
      }
    } catch (e) {
      // If the backend call fails, revert the optimistic update
      if (currentReviewState.isLikedByCurrentUser) {
        ref.read(userLikedReviewsProvider.notifier).addReview(reviewId);
        ref.read(reviewLikeStateProvider.notifier).incrementLikeCount(reviewId);
      } else {
        ref.read(userLikedReviewsProvider.notifier).removeReview(reviewId);
        ref.read(reviewLikeStateProvider.notifier).decrementLikeCount(reviewId);
      }
      // Re-throw the error so the UI can handle it
      rethrow;
    }
  }
}

// Provider for the async notifier
final reviewLikeNotifierProvider = AsyncNotifierProvider<ReviewLikeNotifier, void>(
  ReviewLikeNotifier.new,
);

// Provider for managing review like states
final reviewLikeStateProvider = 
    StateNotifierProvider<ReviewLikeStateNotifier, Map<String, int>>(
        (ref) => ReviewLikeStateNotifier());

// Notifier to track which reviews are liked by the current user
class UserLikedReviewsNotifier extends StateNotifier<Set<String>> {
  UserLikedReviewsNotifier() : super(const {});

  void toggleReviewLike(String reviewId) {
    final newSet = {...state};
    if (newSet.contains(reviewId)) {
      newSet.remove(reviewId);
    } else {
      newSet.add(reviewId);
    }
    state = newSet;
  }

  bool isReviewLiked(String reviewId) {
    return state.contains(reviewId);
  }

  void addReview(String reviewId) {
    state = {...state, reviewId};
  }

  void removeReview(String reviewId) {
    final newSet = {...state};
    newSet.remove(reviewId);
    state = newSet;
  }

  void reset() {
    state = const {};
  }
}

// Provider for tracking user's liked reviews
final userLikedReviewsProvider =
    StateNotifierProvider<UserLikedReviewsNotifier, Set<String>>(
        (ref) => UserLikedReviewsNotifier());

// Provider to hold a list of reviews (for demonstration purposes)
final reviewsListProvider = StateProvider<List<Review>>((ref) => []);

// Combined provider to get total like count for a specific review
final reviewTotalLikeCountProvider = Provider.family<int, String>((ref, reviewId) {
  // Get the user-managed like count from our state
  final userLikeState = ref.watch(reviewLikeStateProvider)[reviewId];
  
  // We'll now combine the original likes count from the review entity with changes
  final originalReview = ref.watch(reviewsListProvider).firstWhere(
    (review) => review.id == reviewId, 
    orElse: () => Review(
      id: reviewId,
      userId: '',
      facilityId: '',
      content: '',
      rating: 0,
      likesCount: 0,
      createdAt: DateTime.now(),
    )
  );
  
  // Return the sum of original count and any changes made locally
  return (userLikeState ?? originalReview.likesCount);
});

// Provider that combines the review entity with its dynamic like state
final reviewWithLikeStateProvider = Provider.family<ReviewWithLikeState, Review>(
    (ref, review) {
  final userLiked = ref.watch(userLikedReviewsProvider.select((liked) => liked.contains(review.id)));
  final dynamicLikeCount = ref.watch(reviewTotalLikeCountProvider(review.id));
  
  return ReviewWithLikeState(
    review: review,
    isLikedByCurrentUser: userLiked,
    likeCount: dynamicLikeCount,
  );
});

// Helper class to combine review entity with dynamic like state
class ReviewWithLikeState {
  final Review review;
  final bool isLikedByCurrentUser;
  final int likeCount;

  const ReviewWithLikeState({
    required this.review,
    required this.isLikedByCurrentUser,
    required this.likeCount,
  });
}

// Provider for the review service
final reviewServiceProvider = Provider<ReviewService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ReviewService(supabase);
});

// Global provider for Supabase client (assuming it's configured elsewhere)
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});