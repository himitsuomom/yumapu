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
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/services/external_map_launcher.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/utils/opening_hours_parser.dart';
import 'package:yu_map/core/widgets/guest_restriction_dialog.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/core/widgets/photo_gallery_viewer.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/features/feed/screens/create_post_screen.dart';
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
  bool _isCheckingIn = false;

  // FEATURE_DISABLED: photo upload
  // Future<void> _pickAndUploadPhoto() async { ... }

  // ── シェア ────────────────────────────────────────────────────────────────

  void _shareFacility() {
    final facility = widget.facility;
    final url = '${AppConstants.deepLinkBaseUrl}/facility/${facility.id}';
    SharePlus.instance.share(ShareParams(text: '${facility.displayName}\n$url', subject: '湯マップ — ${facility.displayName}'));
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
      onPostAfterCheckin: () {
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreatePostScreen(
              initialFacilityId: widget.facility.id,
              initialFacilityName: widget.facility.name,
            ),
          ),
        );
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
                  ),
                  error: (_, __) => _PhotoPlaceholder(
                    isLoading: false,
                    typeColor: typeColor,
                  ),
                  data: (urls) => urls.isEmpty
                      ? _PhotoPlaceholder(
                          isLoading: false,
                          typeColor: typeColor,
                        )
                      : _PhotoCarousel(
                          urls: urls,
                          typeColor: typeColor,
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
