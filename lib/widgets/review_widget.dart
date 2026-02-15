// lib/widgets/review_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/providers/review_provider.dart';

class ReviewWidget extends ConsumerWidget {
  final Review review;
  final Function(bool)? onLikeChanged; // Callback for when like status changes

  const ReviewWidget({
    Key? key,
    required this.review,
    this.onLikeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Update the list of reviews to include this review
    ref.read(reviewsListProvider.notifier).update((state) {
      if (!state.any((r) => r.id == review.id)) {
        return [...state, review];
      }
      return state;
    });

    // Watch the combined review state (includes dynamic like count and user's like status)
    final reviewWithLikeState = ref.watch(reviewWithLikeStateProvider(review));
    final reviewService = ref.watch(reviewServiceProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  review.content,
                  style: const TextStyle(fontSize: 16.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4.0),
                  Text(
                    review.rating.toString(),
                    style: const TextStyle(fontSize: 14.0),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      reviewWithLikeState.isLikedByCurrentUser
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: reviewWithLikeState.isLikedByCurrentUser
                          ? Colors.red
                          : Colors.grey,
                    ),
                    onPressed: () => _toggleLike(ref, reviewService),
                  ),
                  Text(
                    reviewWithLikeState.likeCount.toString(),
                    style: const TextStyle(fontSize: 14.0),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleLike(WidgetRef ref, ReviewService reviewService) async {
    try {
      // Call the async function to toggle the like status with backend integration
      await ref.read(reviewLikeNotifierProvider.notifier).toggleReviewLike(
        review.id,
        reviewService,
        ref,
      );
      
      // Optionally notify about the change
      final newState = ref.read(reviewWithLikeStateProvider(review));
      onLikeChanged?.call(newState.isLikedByCurrentUser);
    } catch (e) {
      // Handle error appropriately
      print('Error toggling like: $e');
      ScaffoldMessenger.of(WidgetsLocalizations.currentContext!).showSnackBar(
        SnackBar(content: Text('Could not update like: $e')),
      );
    }
  }
}