// lib/ui/widgets/review_submission_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yu_map/ui/providers/review_provider.dart';
import 'dart:io';

class ReviewSubmissionWidget extends ConsumerStatefulWidget {
  final String facilityId;
  final VoidCallback? onSuccess;

  const ReviewSubmissionWidget({
    Key? key,
    required this.facilityId,
    this.onSuccess,
  }) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ReviewSubmissionWidgetState();
}

class _ReviewSubmissionWidgetState extends ConsumerState<ReviewSubmissionWidget> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(currentReviewDraftProvider);
    final draftNotifier = ref.read(currentReviewDraftProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Star rating
          Row(
            children: [
              for (int i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => draftNotifier.setRating(i),
                  child: Icon(
                    i <= draft.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Review text field
          TextField(
            controller: _textController,
            onChanged: (value) => draftNotifier.setContent(value),
            decoration: const InputDecoration(
              labelText: 'レビューを入力してください',
              border: OutlineInputBorder(),
              hintText: '施設の雰囲気やサービスについて教えてください',
            ),
            maxLines: 4,
          ),
          
          const SizedBox(height: 16),
          
          // Photo preview
          if (draft.localPhotos.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: draft.localPhotos.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: draft.localPhotos[index] is XFile
                            ? Image.file(
                                File((draft.localPhotos[index] as XFile).path),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image),
                              ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => draftNotifier.removePhoto(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Add photo button
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _addPhoto,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('写真を追加'),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Submit button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('レビューを投稿'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    
    if (photo != null) {
      setState(() {
        ref.read(currentReviewDraftProvider.notifier).addPhoto(photo);
      });
    }
  }

  Future<void> _submitReview() async {
    final draft = ref.watch(currentReviewDraftProvider);
    
    if (draft.rating == 0) {
      _showSnackBar('評価を選択してください');
      return;
    }
    
    if (draft.content.isEmpty) {
      _showSnackBar('レビューを入力してください');
      return;
    }
    
    // In a real implementation, we would call the review service here
    
    // Reset the form
    ref.read(currentReviewDraftProvider.notifier).clear();
    _textController.clear();
    
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    }
    
    _showSnackBar('レビューが投稿されました！');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}