// lib/features/feed/screens/create_post_screen.dart
//
// 投稿作成画面
// テキストと任意の画像を入力して温泉レポートを投稿する。
// 施設を検索して選択することで、facility_id を正しく紐付けられる。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/post_provider.dart';
import 'package:yu_map/providers/visit_provider.dart';
import 'package:yu_map/services/facility_service.dart';

part 'create_post_screen_sub_widgets.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();

  XFile? _pickedImage;
  bool _isSubmitting = false;

  String? _selectedFacilityId;
  String _selectedFacilityName = '';

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('カメラで撮影'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('フォトライブラリから選択'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void _removeImage() {
    setState(() => _pickedImage = null);
  }

  Future<void> _openFacilityPicker() async {
    final service = ref.read(facilityServiceProvider);
    if (service == null) return;

    List<Facility> recentFacilities = [];
    try {
      final visits = ref.read(visitAllProvider).valueOrNull ?? [];
      final seenIds = <String>{};
      final recentIds = <String>[];
      for (final v in visits) {
        if (seenIds.add(v.facilityId)) {
          recentIds.add(v.facilityId);
          if (recentIds.length >= 5) break;
        }
      }
      if (recentIds.isNotEmpty) {
        recentFacilities = await service.getFacilitiesByIds(recentIds);
      }
    } catch (_) {}

    if (!mounted) return;
    final result = await showDialog<Facility>(
      context: context,
      builder: (_) => _FacilitySearchDialog(
        service: service,
        recentFacilities: recentFacilities,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedFacilityId = result.id;
        _selectedFacilityName = result.name;
      });
    }
  }

  void _clearFacility() {
    setState(() {
      _selectedFacilityId = null;
      _selectedFacilityName = '';
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;

      if (_pickedImage != null) {
        imageUrl = await ref
            .read(postFeedProvider.notifier)
            .uploadPostImage(_pickedImage!);
      }

      await ref.read(postFeedProvider.notifier).createPost(
            content: _contentController.text.trim(),
            facilityId: _selectedFacilityId,
            facilityName: _selectedFacilityName,
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

            _FacilityPickerTile(
              selectedFacilityName: _selectedFacilityName.isEmpty
                  ? null
                  : _selectedFacilityName,
              onTap: _openFacilityPicker,
              onClear: _selectedFacilityId != null ? _clearFacility : null,
            ),
            if (_selectedFacilityId == null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha(180),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '施設を選ぶと地図からも見つけてもらえます',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withAlpha(180),
                          ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            _pickedImage == null
                ? _ImagePickerButton(onTap: _pickImage)
                : _ImagePreview(
                    imageFile: _pickedImage!,
                    onRemove: _removeImage,
                    onReplace: _pickImage,
                  ),
            const SizedBox(height: 16),

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
