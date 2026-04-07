import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/widgets/crown_badge.dart';

/// A card displaying a single [Review] with author avatar, rating, content,
/// and optional likes count.
///
/// Uses [UserAvatarWithCrown] and [PremiumChip] for premium author display.
/// The likes icon is suppressed when [Review.likesCount] == 0.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.onLike,
  });

  final Review review;

  /// Called when the user taps the like button. Pass null to hide the button.
  final VoidCallback? onLike;

  static final _dateFormat = DateFormat('yyyy/MM/dd', 'ja');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author row ───────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatarWithCrown(
                  isPremium: review.authorIsPremium,
                  radius: 20,
                  avatarUrl: review.authorAvatarUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              review.authorDisplayName ?? '匿名ユーザー',
                              style: textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (review.authorIsPremium) ...[
                            const SizedBox(width: 6),
                            const PremiumChip(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dateFormat.format(review.createdAt),
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StarRating(rating: review.rating),
              ],
            ),
            const SizedBox(height: 10),
            // ── Review content ───────────────────────────────────────────
            Text(review.content, style: textTheme.bodyMedium),
            // ── Likes row (hidden when count == 0) ───────────────────────
            if (review.likesCount > 0 || onLike != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (review.likesCount > 0) ...[
                    const Icon(Icons.favorite, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      '${review.likesCount}',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (onLike != null)
                    InkWell(
                      onTap: onLike,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.favorite_border,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'いいね',
                              style: textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
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

// ── Star rating ───────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
          size: 14,
          color: const Color(0xFFFFC107),
        );
      }),
    );
  }
}
