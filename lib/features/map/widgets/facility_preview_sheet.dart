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
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/features/reviews/widgets/review_bottom_sheet.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/review_provider.dart';

// ── 写真 + アメニティ取得用プロバイダー ────────────────────────────────────────

/// 施設の写真URLリスト（最新5枚）を取得する。
/// autoDispose: シートが閉じたら自動でキャッシュ解放。
final _facilityPhotosProvider =
    FutureProvider.autoDispose.family<List<String>, String>(
  (ref, facilityId) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return [];
    try {
      final rows = await client
          .from('photos')
          .select('storage_path, thumbnail_path')
          .eq('facility_id', facilityId)
          .order('created_at', ascending: false)
          .limit(5) as List;

      return rows.map((row) {
        final path = row['thumbnail_path'] as String? ??
            row['storage_path'] as String?;
        if (path == null || path.isEmpty) return '';
        return client.storage.from('photos').getPublicUrl(path);
      }).where((url) => url.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  },
);

/// 施設のアメニティ一覧（有効なものだけ）を取得する。
final _facilityAmenitiesProvider =
    FutureProvider.autoDispose.family<List<String>, String>(
  (ref, facilityId) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return [];
    try {
      final rows = await client
          .from('facility_amenities')
          .select('value, amenities!amenity_id(name_ja, code)')
          .eq('facility_id', facilityId) as List;

      return rows
          .where((row) {
            final v = (row['value'] as String? ?? '').toLowerCase();
            return v == 'true' || v == '1' || v == 'yes';
          })
          .map((row) =>
              (row['amenities'] as Map<String, dynamic>?)?['name_ja']
                  as String? ??
              '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  },
);

// ── メインウィジェット ──────────────────────────────────────────────────────────

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
  int _currentPhotoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final facility = widget.facility;
    final isFav = ref.watch(isFavoriteProvider(facility.id));
    final typeColor = _colorForType(facility.facilityType);

    // 写真・クチコミ・アメニティを並列取得
    final photosAsync = ref.watch(_facilityPhotosProvider(facility.id));
    final reviewsAsync = ref.watch(reviewListProvider(facility.id));
    final reviewCountAsync = ref.watch(reviewCountProvider(facility.id));
    final amenitiesAsync = ref.watch(_facilityAmenitiesProvider(facility.id));

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
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // ── ドラッグハンドル ────────────────────────────────────
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // ── 写真カルーセル ──────────────────────────────────────
              SliverToBoxAdapter(
                child: photosAsync.when(
                  loading: () => _buildPhotoPlaceholder(
                      isLoading: true, typeColor: typeColor),
                  error: (_, __) => _buildPhotoPlaceholder(
                      isLoading: false, typeColor: typeColor),
                  data: (urls) => urls.isEmpty
                      ? _buildPhotoPlaceholder(
                          isLoading: false, typeColor: typeColor)
                      : _buildPhotoCarousel(urls, typeColor),
                ),
              ),

              // ── 施設名 + タイプバッジ + 評価 + アメニティ + アクション + お気に入り ────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 4, 0),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // タイプカラーのアクセント縦線（IntrinsicHeightで高さを自動調整）
                        Container(
                          width: 4,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 施設タイプバッジ
                              if (facility.hasFacilityType)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _emojiForType(facility.facilityType),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        facility.facilityTypeJa,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: typeColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // 施設名
                              Text(
                                facility.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              // 星評価（クチコミデータがあれば表示）
                              reviewsAsync.whenOrNull(
                                data: (reviews) {
                                  if (reviews.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'クチコミなし',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    );
                                  }
                                  final avg = reviews
                                          .map((r) => r.rating)
                                          .fold(0, (a, b) => a + b) /
                                      reviews.length;
                                  final totalCount =
                                      reviewCountAsync.valueOrNull ??
                                          reviews.length;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: _StarRating(
                                      avg: avg,
                                      count: totalCount,
                                      color: typeColor,
                                    ),
                                  );
                                },
                              ) ??
                                  const SizedBox.shrink(),

                              // アメニティチップ（施設名の直下に移動）
                              amenitiesAsync.whenOrNull(
                                data: (names) {
                                  if (names.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: names.map((name) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: typeColor
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: typeColor
                                                    .withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: typeColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ) ??
                                  const SizedBox.shrink(),

                              // 電話・ウェブのアクションチップ（存在する場合のみ表示）
                              if (facility.phone != null &&
                                      facility.phone!.isNotEmpty ||
                                  facility.website != null &&
                                      facility.website!.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8, bottom: 4),
                                  child: Row(
                                    children: [
                                      if (facility.phone != null &&
                                          facility.phone!.isNotEmpty) ...[
                                        _ActionChip(
                                          icon: Icons.phone_outlined,
                                          label: '電話',
                                          color: typeColor,
                                          onTap: () => _launchPhone(
                                              context, facility.phone!),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (facility.website != null &&
                                          facility.website!.isNotEmpty)
                                        _ActionChip(
                                          icon: Icons.language_outlined,
                                          label: 'ウェブ',
                                          color: typeColor,
                                          onTap: () => _launchWeb(
                                              context, facility.website!),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // ナビチップ + お気に入りハートボタン（横並び）
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _ActionChip(
                                icon: Icons.near_me_outlined,
                                label: 'ナビ',
                                color: typeColor,
                                onTap: () => _launchMap(
                                  context,
                                  facility.latitude,
                                  facility.longitude,
                                  name: facility.name,
                                ),
                              ),
                            ),
                            _FavoriteButton(
                                facilityId: facility.id, isFav: isFav),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── 基本情報グリッド（情報がある場合のみ表示）──────────
              if (facility.price != null && facility.price! > 0 ||
                  facility.openingHours != null &&
                      facility.openingHours!.isNotEmpty ||
                  facility.address != null && facility.address!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      children: [
                        if (facility.price != null && facility.price! > 0)
                          _InfoRow(
                            icon: Icons.payments_outlined,
                            iconColor: typeColor,
                            label: '入浴料金',
                            value: '¥${facility.price}',
                          ),
                        if (facility.openingHours != null &&
                            facility.openingHours!.isNotEmpty)
                          _InfoRow(
                            icon: Icons.access_time_outlined,
                            iconColor: typeColor,
                            label: '営業時間',
                            value: facility.openingHours!,
                          ),
                        if (facility.address != null &&
                            facility.address!.isNotEmpty)
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            iconColor: typeColor,
                            label: '住所',
                            value: facility.address!,
                          ),
                      ],
                    ),
                  ),
                ),

              // ── クチコミプレビュー（最新2件）──────────────────────────
              SliverToBoxAdapter(
                child: reviewsAsync.whenOrNull(
                  data: (reviews) {
                    if (reviews.isEmpty) return const SizedBox.shrink();
                    final preview = reviews.take(2).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(
                            children: [
                              Icon(Icons.rate_review_outlined,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                'クチコミ',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                // reviewCountProvider で正確な総件数を表示
                                '(${reviewCountAsync.valueOrNull ?? reviews.length}件)',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        ...preview.map(
                            (r) => _ReviewTile(review: r)),
                      ],
                    );
                  },
                ) ??
                    const SizedBox.shrink(),
              ),

              const SliverToBoxAdapter(
                  child: Divider(height: 1)),

              // ── 「クチコミを書く」ボタン ───────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final isSignedIn =
                          ref.read(isSignedInProvider);
                      if (!isSignedIn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('クチコミを書くにはログインが必要です')),
                        );
                        return;
                      }
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                        builder: (_) => ReviewBottomSheet(
                          facilityId: facility.id,
                          onSubmitted: () {
                            ref.invalidate(
                                reviewListProvider(facility.id));
                            ref.invalidate(
                                reviewCountProvider(facility.id));
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.rate_review_outlined,
                        size: 18),
                    label: const Text(
                      'クチコミを書く',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: typeColor,
                      side: BorderSide(
                          color: typeColor.withValues(alpha: 0.5)),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

              // ── 「詳細を見る」ボタン ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  child: FilledButton.icon(
                    onPressed: widget.onOpenDetail,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text(
                      'チェックインなど詳細を見る',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: typeColor,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 写真プレースホルダー ────────────────────────────────────────────────────

  Widget _buildPhotoPlaceholder(
      {required bool isLoading, required Color typeColor}) {
    return Container(
      height: 180,
      color: typeColor.withValues(alpha: 0.06),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: typeColor),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hot_tub,
                      size: 44, color: typeColor.withValues(alpha: 0.4)),
                  const SizedBox(height: 6),
                  Text(
                    '写真はまだありません',
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }

  // ── 写真カルーセル ─────────────────────────────────────────────────────────

  Widget _buildPhotoCarousel(List<String> urls, Color typeColor) {
    return SizedBox(
      height: 210,
      child: Stack(
        children: [
          // スワイプできる写真一覧
          PageView.builder(
            itemCount: urls.length,
            onPageChanged: (i) =>
                setState(() => _currentPhotoIndex = i),
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: urls[index],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: typeColor.withValues(alpha: 0.08),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: typeColor),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[100],
                  child: Icon(Icons.broken_image,
                      color: Colors.grey[400], size: 36),
                ),
              );
            },
          ),
          // 枚数インジケーター（右下）
          if (urls.length > 1)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentPhotoIndex + 1} / ${urls.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── ランチャーヘルパー ────────────────────────────────────────────────────────

  Future<void> _launchPhone(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('電話を発信できませんでした')),
      );
    }
  }

  Future<void> _launchWeb(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ウェブサイトを開けませんでした')),
      );
    }
  }

  Future<void> _launchMap(
    BuildContext context,
    double lat,
    double lng, {
    required String name,
  }) async {
    final encodedName = Uri.encodeComponent(name);
    final geoUri =
        Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedName)');
    final appleMapsUri = Uri.parse(
        'https://maps.apple.com/?ll=$lat,$lng&q=$encodedName');
    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
      } else {
        await launchUrl(appleMapsUri,
            mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地図アプリを開けませんでした')),
      );
    }
  }

  // ── カラー・アイコンヘルパー ──────────────────────────────────────────────────

  static Color _colorForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'onsen':
        return const Color(0xFFE53935);
      case 'public_bath':
        return const Color(0xFF1976D2);
      case 'sauna':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF7B1FA2);
    }
  }

  static String _emojiForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'onsen':
        return '♨';
      case 'public_bath':
        return '🛁';
      case 'sauna':
        return '🧖';
      default:
        return '♨';
    }
  }
}

// ── お気に入りボタン ──────────────────────────────────────────────────────────

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton(
      {required this.facilityId, required this.isFav});

  final String facilityId;
  final bool isFav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () =>
          ref.read(favoritesProvider.notifier).toggle(facilityId),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(isFav),
          color: isFav ? Colors.red[400] : Colors.grey[400],
          size: 28,
        ),
      ),
      tooltip: isFav ? 'お気に入りから外す' : 'お気に入りに追加',
    );
  }
}

// ── 星評価表示 ────────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  const _StarRating({
    required this.avg,
    required this.count,
    required this.color,
  });

  final double avg;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < avg.floor()) {
            return Icon(Icons.star, size: 14, color: color);
          } else if (i < avg) {
            return Icon(Icons.star_half, size: 14, color: color);
          } else {
            return Icon(Icons.star_border,
                size: 14, color: Colors.grey[400]);
          }
        }),
        const SizedBox(width: 4),
        Text(
          avg.toStringAsFixed(1),
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color),
        ),
        const SizedBox(width: 3),
        Text(
          '($count件)',
          style:
              TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

// ── 情報行 ────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── アクションチップ ──────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── クチコミ1件タイル ─────────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // アバター
              CircleAvatar(
                radius: 13,
                backgroundColor: Colors.grey[200],
                backgroundImage: review.authorAvatarUrl != null
                    ? CachedNetworkImageProvider(
                        review.authorAvatarUrl!)
                    : null,
                child: review.authorAvatarUrl == null
                    ? Icon(Icons.person,
                        size: 14, color: Colors.grey[500])
                    : null,
              ),
              const SizedBox(width: 8),
              // 表示名
              Expanded(
                child: Text(
                  review.authorDisplayName ?? '匿名ユーザー',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              // 星
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star
                        : Icons.star_border,
                    size: 11,
                    color: const Color(0xFFFFC107),
                  ),
                ),
              ),
            ],
          ),
          if (review.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.content,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Divider(height: 14),
        ],
      ),
    );
  }
}
