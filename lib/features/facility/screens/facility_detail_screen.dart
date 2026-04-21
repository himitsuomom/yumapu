import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/widgets/banner_ad_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/features/facility/widgets/review_card.dart';
import 'package:yu_map/features/inquiry/inquiry_screen.dart';
import 'package:yu_map/models/badge.dart';
import 'package:yu_map/models/onsen_plan.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/plan_provider.dart';
import 'package:yu_map/providers/review_provider.dart';
import 'package:yu_map/providers/visit_provider.dart';
import 'package:yu_map/services/analytics_service.dart';

class FacilityDetailScreen extends ConsumerStatefulWidget {
  const FacilityDetailScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  ConsumerState<FacilityDetailScreen> createState() =>
      _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends ConsumerState<FacilityDetailScreen> {
  bool _analyticsLogged = false;

  // ── URL helpers ───────────────────────────────────────────────────────────

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リンクを開けませんでした')),
      );
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('電話を発信できませんでした')),
      );
    }
  }

  // ── Check-in dialog ───────────────────────────────────────────────────────

  Future<void> _showCheckinDialog(Facility facility) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('チェックイン'),
        content: Text('${facility.name}にチェックインしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('チェックイン'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // チェックイン直前の時刻を記録（バッジ付与検出のため）
    final checkinTime = DateTime.now().toUtc();

    await ref
        .read(visitNotifierProvider.notifier)
        .logVisit(facilityId: facility.id);
    if (!mounted) return;

    final visitState = ref.read(visitNotifierProvider);
    if (visitState is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(visitState.error.toString()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('チェックインしました 🎉')),
    );

    // DBトリガーがバッジを付与するまで少し待つ
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // チェックイン後に新規付与されたバッジを取得して通知する
    await _notifyNewBadges(checkinTime);
  }

  /// チェックイン時刻以降に付与されたバッジを取得してダイアログ表示する
  Future<void> _notifyNewBadges(DateTime since) async {
    final client = ref.read(supabaseClientProvider);
    final userId = ref.read(sessionProvider)?.user.id;
    if (client == null || userId == null || !mounted) return;

    try {
      final rows = await client
          .from('user_badges')
          .select('*, badges(*)')
          .eq('user_id', userId)
          .gte('earned_at', since.toIso8601String());

      if (!mounted) return;
      final newBadges = (rows as List)
          .map((e) => UserBadge.fromJson(e as Map<String, dynamic>))
          .toList();

      if (newBadges.isEmpty) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _BadgeCelebrationDialog(badges: newBadges),
      );
    } catch (_) {
      // バッジ取得失敗は無視（チェックイン自体は成功している）
    }
  }

  // ── Inquiry navigation ────────────────────────────────────────────────────

  void _openInquiry(Facility facility) {
    Navigator.of(context).pushNamed(
      '/inquiry',
      arguments: {
        'type': InquiryType.hoursChange,
        'facilityName': facility.name,
      },
    );
  }

  // ── Plan bottom sheet ─────────────────────────────────────────────────────

  Future<void> _showAddToPlanSheet(Facility facility) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddToPlanSheet(facility: facility),
    );
  }

  // ── Review sheet ──────────────────────────────────────────────────────────

  void _showReviewSheet(Facility facility) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ReviewSheet(
        facilityId: facility.id,
        onSubmitted: () {
          ref.invalidate(reviewListProvider(facility.id));
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Log analytics once when facility data becomes available
    ref.listen(facilityDetailProvider(widget.facilityId), (_, next) {
      if (_analyticsLogged) return;
      next.whenData((facility) {
        if (facility != null) {
          _analyticsLogged = true;
          AnalyticsService.instance.logFacilityView(
            facilityId: facility.id,
            facilityName: facility.name,
          );
        }
      });
    });

    final facilityAsync = ref.watch(facilityDetailProvider(widget.facilityId));

    return facilityAsync.when(
      data: (facility) {
        if (facility == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('施設詳細')),
            body: const AppErrorWidget(message: '施設が見つかりませんでした'),
          );
        }
        return _buildScaffold(facility);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('施設詳細')),
        body: const LoadingWidget(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('施設詳細')),
        body: AppErrorWidget(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(facilityDetailProvider(widget.facilityId)),
        ),
      ),
    );
  }

  Widget _buildScaffold(Facility facility) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final isFavorite = ref.watch(isFavoriteProvider(facility.id));
    final reviewAsync = ref.watch(reviewListProvider(facility.id));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Map header ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                facility.name,
                style: const TextStyle(
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: facility.hasValidLocation
                  // OpenStreetMap タイル（APIキー不要・完全無料）
                  ? FlutterMap(
                      options: MapOptions(
                        initialCenter: ll.LatLng(
                            facility.latitude, facility.longitude),
                        initialZoom: AppConstants.detailZoom,
                        interactionOptions: const InteractionOptions(
                          // ヘッダー画像として使うため操作を無効化
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.yumap.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: ll.LatLng(
                                  facility.latitude, facility.longitude),
                              width: 44,
                              height: 44,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1565C0),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text('♨️',
                                      style: TextStyle(fontSize: 20)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : ColoredBox(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.map_outlined,
                            size: 80, color: Colors.grey),
                      ),
                    ),
            ),
            actions: [
              // Favorite button — login only
              if (isSignedIn)
                IconButton(
                  tooltip: isFavorite ? 'お気に入りを解除' : 'お気に入りに追加',
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: () =>
                      ref.read(favoritesProvider.notifier).toggle(facility.id),
                ),
            ],
          ),

          // ── Facility info ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _FacilityInfoSection(
              facility: facility,
              onPhone: facility.phone != null
                  ? () => _launchPhone(facility.phone!)
                  : null,
              onWebsite: facility.website != null
                  ? () => _launchUrl(facility.website!)
                  : null,
            ),
          ),

          // ── Action buttons (login only) ────────────────────────────────
          if (isSignedIn)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // 1行目: チェックイン・レビュー
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('チェックイン'),
                            onPressed: () => _showCheckinDialog(facility),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.rate_review_outlined),
                            label: const Text('レビューを書く'),
                            onPressed: () => _showReviewSheet(facility),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 2行目: プランに追加
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.playlist_add_outlined),
                        label: const Text('湯めぐりプランに追加'),
                        onPressed: () => _showAddToPlanSheet(facility),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 3行目: 問い合わせ
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.report_problem_outlined, size: 18),
                        label: const Text('営業時間の変更を報告する'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                        ),
                        onPressed: () => _openInquiry(facility),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Amenities ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _AmenitySection(facilityId: facility.id),
          ),

          // ── Reviews header ─────────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'レビュー',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // ── Review list ────────────────────────────────────────────────
          reviewAsync.when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('まだレビューはありません')),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => ReviewCard(
                    review: reviews[i],
                    onLike: isSignedIn
                        ? () => ref
                            .read(reviewNotifierProvider.notifier)
                            .likeReview(reviews[i].id)
                        : null,
                  ),
                  childCount: reviews.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: AppErrorWidget(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(reviewListProvider(facility.id)),
              ),
            ),
          ),

          // ── Banner ad ──────────────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: BannerAdWidget()),
            ),
          ),

          // Bottom padding for safe area
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Facility info section ─────────────────────────────────────────────────────

class _FacilityInfoSection extends StatelessWidget {
  const _FacilityInfoSection({
    required this.facility,
    this.onPhone,
    this.onWebsite,
  });

  final Facility facility;
  final VoidCallback? onPhone;
  final VoidCallback? onWebsite;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Facility type chip
          if (facility.hasFacilityType) ...[
            Chip(
              label: Text(facility.facilityTypeJa),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 8),
          ],
          // Address
          if (facility.address != null && facility.address!.isNotEmpty)
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: facility.address!,
              textStyle: textTheme.bodyMedium,
            ),
          // Opening hours
          if (facility.openingHours != null)
            _InfoRow(
              icon: Icons.access_time_outlined,
              text: facility.openingHours!,
              textStyle: textTheme.bodyMedium,
            ),
          // Price
          if (facility.price != null && facility.price! > 0)
            _InfoRow(
              icon: Icons.payments_outlined,
              text: '入浴料 ¥${facility.price}',
              textStyle: textTheme.bodyMedium,
            ),
          // Phone
          if (facility.phone != null)
            _InfoRow(
              icon: Icons.phone_outlined,
              text: facility.phone!,
              textStyle: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              onTap: onPhone,
            ),
          // Website
          if (facility.website != null)
            _InfoRow(
              icon: Icons.language_outlined,
              text: facility.website!,
              textStyle: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              onTap: onWebsite,
            ),
        ],
      ),
    );
  }
}

// ── Amenity section ───────────────────────────────────────────────────────────

/// 施設詳細のアメニティ（設備・泉質）セクション。
/// facility_amenities テーブルのデータを Wrap で表示する。
class _AmenitySection extends ConsumerWidget {
  const _AmenitySection({required this.facilityId});

  final String facilityId;

  // カテゴリごとのアイコン定義
  IconData _iconForCategory(String category) {
    switch (category) {
      case 'spring_type':
        return Icons.water;
      case 'bath':
        return Icons.hot_tub;
      case 'sauna':
        return Icons.local_fire_department_outlined;
      case 'facility':
        return Icons.local_parking;
      case 'policy':
        return Icons.info_outline;
      case 'water':
        return Icons.hot_tub;
      default:
        return Icons.check_circle_outline;
    }
  }

  Color _colorForCategory(String category, BuildContext context) {
    switch (category) {
      case 'spring_type':
        return Theme.of(context).colorScheme.primary;
      case 'bath':
        return const Color(0xFF0277BD);
      case 'sauna':
        return const Color(0xFFE65100);
      case 'water':
        return const Color(0xFF1565C0);
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amenitiesAsync = ref.watch(facilityAmenitiesProvider(facilityId));

    return amenitiesAsync.when(
      data: (amenities) {
        if (amenities.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '設備・泉質',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: amenities.map((a) {
                  final color = _colorForCategory(a.category, context);
                  return Chip(
                    avatar: Icon(
                      _iconForCategory(a.category),
                      size: 16,
                      color: color,
                    ),
                    label: Text(
                      a.nameJa,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                    backgroundColor: color.withAlpha(26),
                    side: BorderSide(color: color.withAlpha(77)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.textStyle,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final TextStyle? textStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF757575)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: textStyle)),
          ],
        ),
      ),
    );
  }
}

// ── Badge celebration dialog ──────────────────────────────────────────────────

/// バッジ獲得を祝うダイアログ。上からconfettiが降ってくる演出付き。
class _BadgeCelebrationDialog extends StatefulWidget {
  const _BadgeCelebrationDialog({required this.badges});

  final List<UserBadge> badges;

  @override
  State<_BadgeCelebrationDialog> createState() =>
      _BadgeCelebrationDialogState();
}

class _BadgeCelebrationDialogState extends State<_BadgeCelebrationDialog> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    // ダイアログが開いたらすぐ confetti を開始
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  /// confetti の紙片を描く（星型）
  Path _drawStar(Size size) {
    final path = Path();
    const sides = 5;
    const innerRadiusRatio = 0.4;
    final outerR = size.width / 2;
    final innerR = outerR * innerRadiusRatio;
    final center = Offset(outerR, size.height / 2);

    for (int i = 0; i < sides * 2; i++) {
      final angle = (math.pi / sides) * i - math.pi / 2;
      final r = i.isEven ? outerR : innerR;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    // Stack は showDialog のオーバーレイ全体を覆うため SizedBox.expand で明示
    // confetti は上端中央から降り注ぐ。AlertDialog は中央に Align で固定。
    return SizedBox.expand(
      child: Stack(
        children: [
          // ── confetti（画面上端中央から下方向に発射）──────────────
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2, // 下方向
              numberOfParticles: 30,
              maxBlastForce: 30,
              minBlastForce: 10,
              emissionFrequency: 0.05,
              gravity: 0.3,
              colors: const [
                Color(0xFFFF6B6B),
                Color(0xFFFFD93D),
                Color(0xFF6BCB77),
                Color(0xFF4D96FF),
                Color(0xFFFF9F43),
              ],
              createParticlePath: _drawStar,
            ),
          ),

          // ── ダイアログ本体（画面中央）────────────────────────────
          Center(
            child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Text(
                '🏅',
                style: TextStyle(fontSize: 48),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'バッジを獲得しました！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.badges
                  .map(
                    (ub) => ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          ub.badge.displayIcon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      title: Text(
                        ub.badge.nameJa,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: ub.badge.descriptionJa != null
                          ? Text(
                              ub.badge.descriptionJa!,
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                    ),
                  )
                  .toList(),
            ),
          ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                FilledButton.icon(
                  icon: const Icon(Icons.celebration_outlined),
                  label: const Text('やった！'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review bottom sheet ───────────────────────────────────────────────────────

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.facilityId, required this.onSubmitted});

  final String facilityId;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
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
          const SnackBar(content: Text('レビューを投稿しました')),
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
            // Drag handle
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
            Text(
              'レビューを書く',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Star rating selector
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
                  onPressed: () => setState(() => _rating = star),
                );
              }),
            ),
            const SizedBox(height: 12),
            // Review text field
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
                if (v == null || v.trim().length < AppConstants.minReviewLength) {
                  return '${AppConstants.minReviewLength}文字以上で入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
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

// ── Add to plan bottom sheet ──────────────────────────────────────────────────

/// 湯めぐりプランに施設を追加するボトムシート。
/// 既存プラン一覧を表示し、タップで追加。新規プラン作成フォームも含む。
class _AddToPlanSheet extends ConsumerStatefulWidget {
  const _AddToPlanSheet({required this.facility});

  final Facility facility;

  @override
  ConsumerState<_AddToPlanSheet> createState() => _AddToPlanSheetState();
}

class _AddToPlanSheetState extends ConsumerState<_AddToPlanSheet> {
  bool _showCreateForm = false;
  final _titleCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(myPlansProvider);
    final planState = ref.watch(planNotifierProvider);
    final isLoading = planState is AsyncLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ドラッグハンドル
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            '湯めぐりプランに追加',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // プラン一覧
          plansAsync.when(
            data: (plans) {
              if (plans.isEmpty && !_showCreateForm) {
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'プランがまだありません。\n新しいプランを作成しましょう！',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('新しいプランを作成'),
                      onPressed: () =>
                          setState(() => _showCreateForm = true),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 既存プラン一覧（最大5件）
                  ...plans.take(5).map((plan) {
                    final alreadyAdded =
                        plan.containsFacility(widget.facility.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.hot_tub_outlined),
                      title: Text(plan.title),
                      subtitle: Text(
                        '${plan.facilityIds.length}施設',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: alreadyAdded
                          ? const Icon(Icons.check_circle,
                              color: Colors.green)
                          : const Icon(Icons.add_circle_outline),
                      onTap: alreadyAdded || isLoading
                          ? null
                          : () => _addToPlan(plan),
                    );
                  }),

                  const Divider(height: 24),

                  // 新規プラン作成ボタン
                  if (!_showCreateForm)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('新しいプランを作成'),
                      onPressed: () =>
                          setState(() => _showCreateForm = true),
                    ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const Text('プランの取得に失敗しました'),
          ),

          // 新規プラン作成フォーム
          if (_showCreateForm) ...[
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _titleCtrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'プラン名',
                  hintText: '例: 東京銭湯めぐり',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'プラン名を入力してください' : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showCreateForm = false),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isLoading ? null : _createPlanAndAdd,
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('作成して追加'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addToPlan(OnsenPlan plan) async {
    await ref.read(planNotifierProvider.notifier).addFacilityToPlan(
          planId: plan.id,
          facilityId: widget.facility.id,
          currentFacilityIds: plan.facilityIds,
        );

    if (!mounted) return;

    final state = ref.read(planNotifierProvider);
    if (state is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('追加に失敗しました: ${state.error}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // プロバイダーを更新してリストを再取得
    ref.invalidate(myPlansProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${plan.title}」に追加しました'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _createPlanAndAdd() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newPlan = await ref.read(planNotifierProvider.notifier).createPlan(
          title: _titleCtrl.text.trim(),
        );

    if (!mounted) return;
    if (newPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('プランの作成に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 作成したプランに施設を追加
    await ref.read(planNotifierProvider.notifier).addFacilityToPlan(
          planId: newPlan.id,
          facilityId: widget.facility.id,
          currentFacilityIds: newPlan.facilityIds,
        );

    if (!mounted) return;

    ref.invalidate(myPlansProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${newPlan.title}」を作成して追加しました'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }
}
