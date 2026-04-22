// lib/features/reviews/widgets/review_bottom_sheet.dart
//
// レビュー投稿ボトムシート（共通ウィジェット）。
//
// facility_detail_screen.dart と facility_preview_sheet.dart の
// 両方から呼び出せるよう、公開クラスとして定義している。
//
// 使い方:
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     builder: (_) => ReviewBottomSheet(
//       facilityId: facility.id,
//       onSubmitted: () {
//         ref.invalidate(reviewListProvider(facility.id));
//         ref.invalidate(reviewCountProvider(facility.id));
//       },
//     ),
//   );

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/providers/review_provider.dart';

class ReviewBottomSheet extends ConsumerStatefulWidget {
  const ReviewBottomSheet({
    super.key,
    required this.facilityId,
    required this.onSubmitted,
  });

  /// 投稿対象の施設ID。
  final String facilityId;

  /// 投稿成功後に呼ばれるコールバック。
  /// 呼び出し元でキャッシュ無効化などを行うこと。
  final VoidCallback onSubmitted;

  @override
  ConsumerState<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends ConsumerState<ReviewBottomSheet> {
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _rating = 3;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(reviewNotifierProvider.notifier).postReview(
          facilityId: widget.facilityId,
          content: _contentController.text.trim(),
          rating: _rating,
        );
    if (!mounted) return;
    final reviewState = ref.read(reviewNotifierProvider);
    reviewState.whenOrNull(
      data: (_) {
        widget.onSubmitted();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('レビューを投稿しました！')),
        );
      },
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(reviewNotifierProvider) is AsyncLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── ドラッグハンドル ──────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── タイトル ──────────────────────────────────────────────
            Text(
              'レビューを書く',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ── 星評価セレクター ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFFFC107),
                    size: 32,
                  ),
                  onPressed:
                      isLoading ? null : () => setState(() => _rating = star),
                );
              }),
            ),
            const SizedBox(height: 12),

            // ── レビューテキストフィールド ─────────────────────────────
            TextFormField(
              controller: _contentController,
              maxLines: 5,
              maxLength: AppConstants.maxReviewLength,
              enabled: !isLoading,
              decoration: const InputDecoration(
                hintText: '施設の感想をお書きください（10文字以上）',
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null ||
                    v.trim().length < AppConstants.minReviewLength) {
                  return '${AppConstants.minReviewLength}文字以上で入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── 投稿ボタン ────────────────────────────────────────────
            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('投稿する'),
            ),
          ],
        ),
      ),
    );
  }
}
