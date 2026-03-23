import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/widgets/crown_badge.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row with avatar, name, crown badge, and date
            Row(
              children: [
                UserAvatarWithCrown(
                  isPremium: review.authorIsPremium,
                  radius: 16,
                  avatarUrl: review.authorAvatarUrl,
                  fallbackIcon: Icons.person,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              review.authorDisplayName ?? '匿名ユーザー',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (review.authorIsPremium) ...[
                            const SizedBox(width: 6),
                            const PremiumChip(height: 18),
                          ],
                        ],
                      ),
                      Text(
                        DateFormat('yyyy/MM/dd').format(review.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Star rating
            RatingBarIndicator(
              rating: review.rating.toDouble(),
              itemBuilder: (_, __) =>
                  const Icon(Icons.star, color: Colors.amber),
              itemCount: 5,
              itemSize: 18,
            ),
            const SizedBox(height: 8),
            Text(review.content),
            if (review.likesCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.thumb_up, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${review.likesCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
