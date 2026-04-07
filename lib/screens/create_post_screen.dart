// lib/screens/create_post_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/app_state.dart';
import 'package:yu_map/services/supabase_service.dart';

/// 投稿作成画面
class CreatePostScreen extends StatefulWidget {
  final Facility facility;
  final File? initialImage; // カスタムカメラからの初期画像（任意）

  const CreatePostScreen({
    super.key,
    required this.facility,
    this.initialImage,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // カスタムカメラから渡された初期画像をセット
    if (widget.initialImage != null) {
      _selectedImage = widget.initialImage;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// カメラまたはギャラリーから画像を選択
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,   // 画質80%に圧縮（容量削減）
      maxWidth: 1280,     // 最大幅1280px
      maxHeight: 1280,
    );
    if (pickedFile == null) return;
    setState(() => _selectedImage = File(pickedFile.path));
  }

  /// 画像選択方法を選ぶボトムシート
  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.orange),
              title: const Text('カメラで撮影'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('フォトライブラリから選択'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('画像を削除'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedImage = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿内容を入力してください')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // async前にcontext依存オブジェクトを取得
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    // 画像がある場合はアップロード
    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await SupabaseService.uploadPostImage(_selectedImage!);
      if (imageUrl == null && mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('画像のアップロードに失敗しました。テキストのみ投稿します'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    final success = await appState.createPost(
      facilityId: widget.facility.id,
      content: content,
      facilityName: widget.facility.name,
      imageUrl: imageUrl,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('投稿しました！ +30pt'),
          backgroundColor: Colors.green,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(appState.errorMessage ?? '投稿に失敗しました'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿する'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submitPost,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('投稿'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 施設情報
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.facility.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // テキスト入力
            TextField(
              controller: _contentController,
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'この施設の感想を書いてみましょう...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 画像エリア
            if (_selectedImage != null) ...[
              // 選択済み画像のプレビュー
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _showImageSourceSheet,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('変更',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // 画像追加ボタン
              GestureDetector(
                onTap: _showImageSourceSheet,
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.shade300,
                        style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate,
                          size: 32, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        '写真を追加（任意）',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 投稿ポイント案内
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade600, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '投稿すると +30pt 獲得',
                    style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
