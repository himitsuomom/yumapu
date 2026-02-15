// lib/widgets/review_list_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/widgets/review_widget.dart';

class ReviewListWidget extends ConsumerWidget {
  final List<Review> reviews;

  const ReviewListWidget({
    Key? key,
    required this.reviews,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // Allow embedding in other scroll views
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final review = reviews[index];
        
        return ReviewWidget(
          review: review,
          onLikeChanged: (bool isLiked) {
            // Handle like status changes globally if needed
            // For example, you might want to sync with backend here
          },
        );
      },
    );
  }
}