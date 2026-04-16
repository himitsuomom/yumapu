// lib/features/feed/screens/create_post_screen.dart
//
// 投稿作成画面
// テキストと任意の画像を入力して温泉レポートを投稿する。
// 施設名を任意で紐付けることができる。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yu_map/providers/post_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _facilityNameController = TextEditingController();
  final _imagePicker = ImagePicker();

  /// ユーザーが選択した画像ファイル（null = 未選択）
  XFile? _pickedImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    _facilityNameController.dispose();
    super.dispose();
  }

  /// ギャラリーから画像を選択する
  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      // 最大1920pxにリサイズして通信量・ストレージを節約する
      maxWidth: 1920,
      maxHeight: 1920,
      // JPEG品質80%（十分な画質を保ちつつサイズ削減）
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  /// 選択済み画像を削除する
  void _removeImage() {
    setState(() => _pickedImage = null);
  }

  Future<void> _submit() async {
    // フォームのバリデーション（入力チェック）を実行
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;

      // 画像が選択されている場合は先にStorageへアップロードしてURLを取得
      if (_pickedImage != null) {
        imageUrl = await ref
            .read(postFeedProvider.notifier)
            .uploadPostImage(_pickedImage!);
      }

      await ref.read(postFeedProvider.notifier).createPost(
            content: _contentController.text.trim(),
            facilityName: _facilityNameController.text.trim(),
            imageUrl: imageUrl,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿しました！')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投稿に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿する'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '投稿',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 本文入力 ──────────────────────────────────────────────
            TextFormField(
              controller: _contentController,
              maxLength: 1000,
              maxLines: 8,
              minLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '温泉の感想を書いてみましょう...\n例）泉質がとろとろで最高でした！',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return '本文を入力してください';
                }
                if (v.trim().length > 1000) {
                  return '1000文字以内で入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── 施設名入力（任意） ────────────────────────────────────
            TextFormField(
              controller: _facilityNameController,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: '施設名（任意）',
                hintText: '例）別府温泉 竹瓦温泉',
                prefixIcon: Icon(Icons.hot_tub),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── 画像選択エリア ────────────────────────────────────────
            _pickedImage == null
                ? _ImagePickerButton(onTap: _pickImage)
                : _ImagePreview(
                    imageFile: _pickedImage!,
                    onRemove: _removeImage,
                    onReplace: _pickImage,
                  ),
            const SizedBox(height: 16),

            // ── 注意書き ──────────────────────────────────────────────
            Text(
              '※ 投稿は全ユーザーに公開されます\n※ 他者を傷つけるような投稿はお控えください',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFF757575)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 画像未選択時のボタン ──────────────────────────────────────────────────────

class _ImagePickerButton extends StatelessWidget {
  const _ImagePickerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 6),
            Text(
              '写真を追加（任意）',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 画像選択済みプレビュー ──────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.imageFile,
    required this.onRemove,
    required this.onReplace,
  });

  final XFile imageFile;
  final VoidCallback onRemove;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 選択した画像のプレビュー（ローカルファイルは Image.file で表示）
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imageFile.path),
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),

        // 右上に削除ボタンと変更ボタンを重ねて表示
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              // 画像を変更するボタン
              _OverlayIconButton(
                icon: Icons.edit,
                tooltip: '画像を変更',
                onTap: onReplace,
              ),
              const SizedBox(width: 6),
              // 画像を削除するボタン
              _OverlayIconButton(
                icon: Icons.close,
                tooltip: '画像を削除',
                onTap: onRemove,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 画像プレビュー上に重ねて表示する丸いアイコンボタン
class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(153),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
