import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/providers/review_provider.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });
  final String facilityId;
  final String facilityName;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  final _contentController = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('評価を選択してください')),
      );
      return;
    }
    final content = _contentController.text.trim();
    if (content.length < AppConstants.minReviewLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppConstants.minReviewLength}文字以上入力してください')),
      );
      return;
    }

    final success = await ref.read(reviewSubmitProvider.notifier).submitReview(
          facilityId: widget.facilityId,
          content: content,
          rating: _rating,
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('レビューを投稿しました！')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(reviewSubmitProvider);
    final isSubmitting = submitState is AsyncLoading;

    ref.listen<AsyncValue<void>>(reviewSubmitProvider, (_, state) {
      if (state is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('投稿に失敗しました: ${state.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('レビューを書く'),
        actions: [
          TextButton(
            onPressed: isSubmitting ? null : _submit,
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('投稿'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Facility name
            Text(
              widget.facilityName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),

            // Rating
            Text('評価', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Center(
              child: RatingBar.builder(
                initialRating: 0,
                minRating: 1,
                allowHalfRating: false,
                itemCount: 5,
                itemSize: 40,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (_, __) =>
                    const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (r) => setState(() => _rating = r.toInt()),
              ),
            ),
            const SizedBox(height: 24),

            // Content
            Text('レビュー内容', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 8,
              maxLength: AppConstants.maxReviewLength,
              decoration: const InputDecoration(
                hintText: '施設の感想を書いてください...',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
