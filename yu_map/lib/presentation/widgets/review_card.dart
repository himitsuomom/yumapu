// lib/presentation/widgets/review_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/providers/review_providers.dart';
import 'package:intl/intl.dart';

/// Compact card showing a single review with interactive Like button.
class ReviewCard extends ConsumerStatefulWidget {
  final Review review;
  final bool showDeleteButton;

  const ReviewCard({
    super.key,
    required this.review,
    this.showDeleteButton = false,
  });

  @override
  ConsumerState<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<ReviewCard> {
  late int _likesCount;
  bool _isLiked = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.review.likesCount;
  }

  Future<void> _handleLike() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final newCount = await ref.read(reviewActionProvider.notifier).toggleLike(
            widget.review.id,
            isLiked: _isLiked,
          );
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount = newCount;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy/MM/dd').format(widget.review.createdAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: rating + date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RatingBarIndicator(
                  rating: widget.review.rating.toDouble(),
                  itemBuilder: (_, __) =>
                      const Icon(Icons.star, color: Colors.amber),
                  itemCount: 5,
                  itemSize: 18,
                ),
                Text(
                  dateStr,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Content
            if (widget.review.content.isNotEmpty)
              Text(
                widget.review.content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

            const SizedBox(height: 8),

            // Footer: likes button
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isProcessing ? null : _handleLike,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLiked
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          size: 16,
                          color: _isLiked
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_likesCount',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: _isLiked
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
