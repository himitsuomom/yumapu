// lib/ui/screens/review_photo_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/ui/widgets/review_submission_widget.dart';
import 'package:yu_map/ui/widgets/review_detail_widget.dart';
import 'package:yu_map/ui/providers/review_provider.dart';

class ReviewPhotoScreen extends ConsumerStatefulWidget {
  final String facilityId;

  const ReviewPhotoScreen({
    Key? key,
    required this.facilityId,
  }) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ReviewPhotoScreenState();
}

class _ReviewPhotoScreenState extends ConsumerState<ReviewPhotoScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('レビューと写真'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Review submission section
            Card(
              margin: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '新しいレビューを投稿',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ReviewSubmissionWidget(
                    facilityId: widget.facilityId,
                    onSuccess: () {
                      // Refresh reviews after successful submission
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('レビューが投稿されました！')),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Reviews section header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'レビュー一覧',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '42件のレビュー',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            // Sample reviews
            ReviewDetailWidget(
              review: ref.watch(currentReviewDraftProvider).localPhotos.isEmpty 
                ? _createSampleReview() 
                : _createSampleReview(), // Placeholder for actual reviews
            ),
            ReviewDetailWidget(
              review: _createSampleReviewSecondary(),
            ),
          ],
        ),
      ),
    );
  }

  // Sample review for demonstration
  ReviewModel _createSampleReview() {
    return ReviewModel(
      id: '1',
      userId: 'user123',
      facilityId: widget.facilityId,
      content: 'とても気持ちよかったです。清潔で落ち着ける空間でした。',
      rating: 5,
      photoUrls: [
        'https://images.unsplash.com/photo-1571003123894-1db0d53d0f1b?width=200&height=200',
        'https://images.unsplash.com/photo-1591871937573-74dbba5158eb?width=200&height=200'
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      userName: '田中太郎',
      userAvatar: 'https://ui-avatars.com/api/?name=田中太郎&background=random',
    );
  }

  ReviewModel _createSampleReviewSecondary() {
    return ReviewModel(
      id: '2',
      userId: 'user456',
      facilityId: widget.facilityId,
      content: 'サウナが最高でした！また来たいと思います。',
      rating: 4,
      photoUrls: [
        'https://images.unsplash.com/photo-1566665797739-1674de7a421a?width=200&height=200'
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      userName: '佐藤花子',
      userAvatar: 'https://ui-avatars.com/api/?name=佐藤花子&background=random',
    );
  }
}