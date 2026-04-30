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

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();

  /// ユーザーが選択した画像ファイル（null = 未選択）
  XFile? _pickedImage;
  bool _isSubmitting = false;

  /// Bug-2修正: 施設名だけでなくIDも保持する
  String? _selectedFacilityId;
  String _selectedFacilityName = '';

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// カメラまたはギャラリーから画像を選択する
  /// BottomSheetで選択肢を表示し、ユーザーが選んだソースで画像を取得する
  Future<void> _pickImage() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
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

  /// カメラ/ギャラリー選択BottomSheetを表示する
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

  /// 選択済み画像を削除する
  void _removeImage() {
    setState(() => _pickedImage = null);
  }

  /// 施設選択ダイアログを開く。
  ///
  /// ダイアログを開く前に直近5件のチェックイン施設を取得し、
  /// 検索ボックス未入力のときに「最近訪問した施設」として表示する。
  /// 取得に失敗した場合は空リストを渡して通常の検索モードにフォールバックする。
  Future<void> _openFacilityPicker() async {
    final service = ref.read(facilityServiceProvider);
    if (service == null) return;

    // 直近チェックインから重複のない施設ID（最大5件）を取得する。
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
    } catch (_) {
      // 取得失敗は無視して通常の検索モードで開く
    }

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

  /// 選択した施設をリセットする
  void _clearFacility() {
    setState(() {
      _selectedFacilityId = null;
      _selectedFacilityName = '';
    });
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
            // Bug-2修正: facilityId を正しく渡す
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

            // ── 施設選択（任意・推奨）────────────────────────────────
            // Bug-2修正: テキスト手入力→施設検索+選択に変更
            // 施設を選択すると facility_id が正しく設定される
            _FacilityPickerTile(
              selectedFacilityName: _selectedFacilityName.isEmpty
                  ? null
                  : _selectedFacilityName,
              onTap: _openFacilityPicker,
              onClear: _selectedFacilityId != null ? _clearFacility : null,
            ),
            // ソフトナッジ: 施設未選択の場合に案内テキストを表示する。
            // 施設タグがつくと地図から投稿を発見しやすくなるため選択を推奨する。
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

// ── 施設選択タイル ─────────────────────────────────────────────────────────────

/// 施設選択済みか否かで表示を切り替えるタイル。
/// タップで施設検索ダイアログを開く。
class _FacilityPickerTile extends StatelessWidget {
  const _FacilityPickerTile({
    required this.selectedFacilityName,
    required this.onTap,
    this.onClear,
  });

  final String? selectedFacilityName;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedFacilityName != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(80)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.hot_tub,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSelected ? selectedFacilityName! : '施設を選択（任意）',
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.grey.shade500,
                  fontSize: 16,
                ),
              ),
            ),
            // 施設選択済みならクリアボタンを表示
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, color: Colors.grey.shade500, size: 20),
              )
            else
              Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── 施設検索ダイアログ ─────────────────────────────────────────────────────────

/// 施設名で施設を検索し、選択した Facility を返すダイアログ。
class _FacilitySearchDialog extends StatefulWidget {
  const _FacilitySearchDialog({
    required this.service,
    this.recentFacilities = const [],
  });

  final FacilityService service;

  /// 検索ボックス未入力のときに「最近訪問した施設」セクションで表示する施設リスト。
  /// 空の場合はこのセクションを非表示にする。
  final List<Facility> recentFacilities;

  @override
  State<_FacilitySearchDialog> createState() => _FacilitySearchDialogState();
}

class _FacilitySearchDialogState extends State<_FacilitySearchDialog> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Facility> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// 400ms のdebounce付きで施設を検索する。
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final results = await widget.service.searchFacilities(
          searchQuery: query.trim(),
        );
        if (mounted) setState(() => _results = results);
      } catch (_) {
        if (mounted) setState(() => _results = []);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── タイトル ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  '施設を検索',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // ── 検索フィールド ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '施設名で検索（例: 草津温泉）',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── 検索結果一覧 ──────────────────────────────────────────
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: _buildResultList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 検索ボックスが空の場合：最近訪問した施設 or 入力案内を表示する。
    if (_searchController.text.isEmpty) {
      if (widget.recentFacilities.isNotEmpty) {
        return _RecentFacilitiesList(
          facilities: widget.recentFacilities,
          onTap: (f) => Navigator.of(context).pop(f),
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '施設名を入力して検索してください',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('施設が見つかりませんでした',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final facility = _results[index];
        return ListTile(
          leading: const Icon(Icons.hot_tub_outlined),
          title: Text(facility.name),
          subtitle: facility.address != null
              ? Text(
                  facility.address!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                )
              : null,
          onTap: () => Navigator.of(context).pop(facility),
        );
      },
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
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withAlpha(77),
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

// ── 最近訪問した施設リスト ─────────────────────────────────────────────────────

/// 施設ピッカーで検索ボックスが空のとき表示する「最近訪問した施設」セクション。
///
/// チェックイン履歴から重複なし最大5件の施設を一覧表示し、
/// タップするとその施設を選択してダイアログを閉じる。
class _RecentFacilitiesList extends StatelessWidget {
  const _RecentFacilitiesList({
    required this.facilities,
    required this.onTap,
  });

  final List<Facility> facilities;
  final void Function(Facility) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // セクションヘッダー
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.history,
                size: 15,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '最近訪問した施設',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 施設リスト
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: facilities.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final facility = facilities[index];
            return ListTile(
              leading: const Icon(Icons.hot_tub_outlined),
              title: Text(facility.name),
              subtitle: facility.address != null
                  ? Text(
                      facility.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
              dense: true,
              onTap: () => onTap(facility),
            );
          },
        ),
      ],
    );
  }
}
