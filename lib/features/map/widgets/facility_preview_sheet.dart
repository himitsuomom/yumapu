// lib/features/map/widgets/facility_preview_sheet.dart
//
// マーカータップで表示されるボトムシート（下から出るカード）。
// 施設の主要情報をワンクリックで全て確認できる。
//
// 操作フロー:
//   マーカータップ → このシートが下から出る
//   シートをスワイプダウン → 閉じる
//   「詳細」ボタン → FacilityDetailScreen へ遷移
//   「お気に入り」ハートアイコン → お気に入り登録/解除（シート内で完結）
//   「電話」「ウェブ」「地図」ボタン → 外部アプリを開く

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/utils/opening_hours_parser.dart';
import 'package:yu_map/core/widgets/guest_restriction_dialog.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/core/widgets/photo_gallery_viewer.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/features/reviews/widgets/review_bottom_sheet.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/facility_provider.dart'
    show facilityPhotosProvider, facilityAmenitiesProvider;
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/review_provider.dart'
    show reviewListProvider, facilityReviewSummaryProvider;
import 'package:yu_map/services/checkin_service.dart';

part 'facility_preview_sheet_sub_widgets.dart';
part 'facility_preview_sheet_sections.dart';

/// マーカータップ時にボトムシートとして表示する施設プレビューカード。
class FacilityPreviewSheet extends ConsumerStatefulWidget {
  const FacilityPreviewSheet({
    super.key,
    required this.facility,
    required this.onOpenDetail,
  });

  final Facility facility;

  /// 「詳細を見る」ボタンが押されたときのコールバック。
  final VoidCallback onOpenDetail;

  @override
  ConsumerState<FacilityPreviewSheet> createState() =>
      _FacilityPreviewSheetState();
}

class _FacilityPreviewSheetState
    extends ConsumerState<FacilityPreviewSheet> {
  bool _isUploadingPhoto = false;
  bool _isCheckingIn = false;

  // ── 写真アップロード ───────────────────────────────────────────────────────

  /// ギャラリーから写真を選択して Supabase Storage にアップロードし、
  /// photos テーブルに記録する。
  Future<void> _pickAndUploadPhoto() async {
    final session = ref.read(sessionProvider);
    if (session == null) {
      if (!mounted) return;
      final goLogin = await GuestRestrictionDialog.show(
        context,
        featureName: '写真投稿',
      );
      if (goLogin == true && mounted) {
        Navigator.of(context).pushNamed('/login');
      }
      return;
    }

    if (_isUploadingPhoto) return;

    final source = await showModalBottomSheet<ImageSource>(
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
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この写真を投稿しますか？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.facility.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'この施設の写真として公開されます',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('投稿する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) throw Exception('接続エラー');

      final userId = session.user.id;
      final facilityId = widget.facility.id;

      final rawExt = picked.path.split('.').last.toLowerCase();
      final safeExt =
          ['jpg', 'jpeg', 'png', 'webp'].contains(rawExt) ? rawExt : 'jpg';
      final fileName = '${const Uuid().v4()}.$safeExt';
      final storagePath = 'facilities/$facilityId/$fileName';

      await client.storage.from('photos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$safeExt',
              upsert: false,
            ),
          );

      await client.from('photos').insert({
        'user_id': userId,
        'facility_id': facilityId,
        'storage_path': storagePath,
      });

      if (!mounted) return;

      ref.invalidate(facilityPhotosProvider(facilityId));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真を投稿しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── シェア ────────────────────────────────────────────────────────────────

  void _shareFacility() {
    final facility = widget.facility;
    final url = '${AppConstants.deepLinkBaseUrl}/facility/${facility.id}';
    Share.share('${facility.name}\n$url', subject: '湯マップ — ${facility.name}');
  }

  // ── チェックイン ───────────────────────────────────────────────────────────

  Future<void> _showCheckinDialog() async {
    if (_isCheckingIn) return;
    await CheckinService.performCheckin(
      context: context,
      ref: ref,
      facility: widget.facility,
      setCheckingIn: (v) {
        if (mounted) setState(() => _isCheckingIn = v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final facility = widget.facility;
    final typeColor = _colorForType(facility.facilityType);
    final photosAsync = ref.watch(facilityPhotosProvider(facility.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.30,
      maxChildSize: 0.92,
      expand: false,
      snap: true,
      snapSizes: const [0.45, 0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              const SliverToBoxAdapter(child: _SheetHandle()),
              SliverToBoxAdapter(
                child: photosAsync.when(
                  loading: () => _PhotoPlaceholder(
                    isLoading: true,
                    typeColor: typeColor,
                    isUploading: _isUploadingPhoto,
                    onAddPhoto: _pickAndUploadPhoto,
                  ),
                  error: (_, __) => _PhotoPlaceholder(
                    isLoading: false,
                    typeColor: typeColor,
                    isUploading: _isUploadingPhoto,
                    onAddPhoto: _pickAndUploadPhoto,
                  ),
                  data: (urls) => urls.isEmpty
                      ? _PhotoPlaceholder(
                          isLoading: false,
                          typeColor: typeColor,
                          isUploading: _isUploadingPhoto,
                          onAddPhoto: _pickAndUploadPhoto,
                        )
                      : _PhotoCarousel(
                          urls: urls,
                          typeColor: typeColor,
                          isUploading: _isUploadingPhoto,
                          onAddPhoto: _pickAndUploadPhoto,
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: _FacilityInfoCard(
                  facility: facility,
                  typeColor: typeColor,
                  onShare: _shareFacility,
                ),
              ),
              SliverToBoxAdapter(
                child: _BasicInfoSection(
                  facility: facility,
                  typeColor: typeColor,
                ),
              ),
              SliverToBoxAdapter(
                child: _ReviewPreviewSection(facilityId: facility.id),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1)),
              SliverToBoxAdapter(
                child: _BottomActionSection(
                  facility: facility,
                  typeColor: typeColor,
                  isCheckingIn: _isCheckingIn,
                  onCheckin: _showCheckinDialog,
                  onOpenDetail: widget.onOpenDetail,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
