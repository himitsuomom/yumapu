// lib/screens/review_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/widgets/review_list_widget.dart';

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sample reviews data for demonstration
    final sampleReviews = [
      Review(
        id: 'review-1',
        userId: 'user-1',
        facilityId: 'facility-1',
        content: 'This is a wonderful hot spring! The water is very relaxing.',
        rating: 5,
        likesCount: 10,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Review(
        id: 'review-2',
        userId: 'user-2',
        facilityId: 'facility-1',
        content: 'Great atmosphere and friendly staff. Will visit again!',
        rating: 4,
        likesCount: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'review-3',
        userId: 'user-3',
        facilityId: 'facility-2',
        content: 'Average experience, nothing special but decent.',
        rating: 3,
        likesCount: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
      ),
      body: ReviewListWidget(reviews: sampleReviews),
    );
  }
}