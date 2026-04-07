import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/providers/review_provider.dart';
import 'package:yu_map/services/analytics_service.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  int _rating = 3;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validateContent(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < AppConstants.minReviewLength) {
      return '${AppConstants.minReviewLength}文字以上で入力してください（現在 ${trimmed.length} 文字）';
    }
    if (trimmed.length > AppConstants.maxReviewLength) {
      return '${AppConstants.maxReviewLength}文字以内で入力してください';
    }
    return null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('評価を選択してください')),
      );
      return;
    }

    final content = _contentController.text.trim();

    await ref.read(reviewNotifierProvider.notifier).postReview(
          facilityId: widget.facilityId,
          content: content,
          rating: _rating,
        );

    if (!mounted) return;
    final reviewState = ref.read(reviewNotifierProvider);

    reviewState.when(
      data: (_) async {
        await AnalyticsService.instance.logReviewSubmit(
          facilityId: widget.facilityId,
          rating: _rating,
          contentLength: content.length,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('レビューを投稿しました')),
        );
        Navigator.of(context).pop();
      },
      loading: () {},
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(reviewNotifierProvider) is AsyncLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('レビューを書く'),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _submit,
            child: const Text('投稿'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Facility name header
              Text(
                widget.facilityName,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // Star rating
              Text(
                '評価',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    icon: Icon(
                      star <= _rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFFC107),
                      size: 40,
                    ),
                    onPressed: isLoading
                        ? null
                        : () => setState(() => _rating = star),
                  );
                }),
              ),
              const SizedBox(height: 24),
              // Review content
              Text(
                'レビュー内容',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                maxLines: 8,
                maxLength: AppConstants.maxReviewLength,
                enabled: !isLoading,
                decoration: const InputDecoration(
                  hintText: '施設の感想をお書きください',
                  alignLabelWithHint: true,
                ),
                validator: _validateContent,
              ),
              const SizedBox(height: 24),
              // Submit button
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('投稿する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
