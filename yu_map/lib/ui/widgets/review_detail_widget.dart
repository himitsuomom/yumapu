// lib/ui/widgets/review_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yu_map/ui/models/review_model.dart';

class ReviewDetailWidget extends StatelessWidget {
  final ReviewModel review;
  final bool showUserInfo;
  final VoidCallback? onLikePressed;
  final bool isLiked;
  final int likeCount;

  const ReviewDetailWidget({
    Key? key,
    required this.review,
    this.showUserInfo = true,
    this.onLikePressed,
    this.isLiked = false,
    this.likeCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showUserInfo) ...[
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(review.userAvatar),
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatDate(review.createdAt),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  RatingBarIndicator(
                    rating: review.rating.toDouble(),
                    itemBuilder: (context, index) => Icon(
                      Icons.star,
                      color: Colors.amber.shade300,
                    ),
                    itemCount: 5,
                    itemSize: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RatingBarIndicator(
                    rating: review.rating.toDouble(),
                    itemBuilder: (context, index) => Icon(
                      Icons.star,
                      color: Colors.amber.shade300,
                    ),
                    itemCount: 5,
                    itemSize: 20,
                  ),
                  Text(
                    _formatDate(review.createdAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            // Review text
            Text(
              review.content,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            
            // Photos
            if (review.photoUrls.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.photoUrls.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: review.photoUrls[index],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Like button
            Row(
              children: [
                IconButton(
                  onPressed: onLikePressed,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : null,
                  ),
                ),
                Text('$likeCount'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}日前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分前';
    } else {
      return 'たった今';
    }
  }
}