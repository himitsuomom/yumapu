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
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/features/facility/screens/facility_report_screen.dart';
import 'package:yu_map/features/facility/screens/owner_facility_edit_screen.dart';
import 'package:yu_map/features/facility/screens/owner_registration_screen.dart';
import 'package:yu_map/features/facility/widgets/review_card.dart';
import 'package:yu_map/features/reviews/widgets/review_bottom_sheet.dart';
import 'package:yu_map/models/onsen_plan.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/plan_provider.dart';
import 'package:yu_map/providers/review_provider.dart';
import 'package:yu_map/providers/visit_provider.dart';
import 'package:yu_map/services/analytics_service.dart';
import 'package:yu_map/services/checkin_service.dart';

class FacilityDetailScreen extends ConsumerStatefulWidget {
  const FacilityDetailScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  ConsumerState<FacilityDetailScreen> createState() =>
      _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends ConsumerState<FacilityDetailScreen> {
  bool _analyticsLogged = false;

  /// チェックイン処理中フラグ（ボタン二重タップ防止）
  bool _isCheckingIn = false;

  /// UX-V11-3: ヘッダー写真カルーセル用コントローラーと現在ページインデックス
  final PageController _headerPageController = PageController();
  int _headerPhotoIndex = 0;

  // ── レビュー無限スクロール用ステート ──────────────────────────────────────

  /// 累積済みレビューリスト（ページをまたいで追記していく）
  final List<Review> _reviews = [];

  /// 次に取得するページ番号（0始まり）
  int _reviewPage = 0;

  /// まだ次のページが存在するか（false になったら「もっと見る」を非表示）
  bool _reviewHasMore = true;

  /// 追加ロード中フラグ（二重リクエスト防止）
  bool _reviewLoadingMore = false;

  /// 初回ロード中フラグ（初期スピナー表示用）
  bool _reviewInitialLoading = true;

  /// 初回ロードエラーメッセージ（null なら正常）
  String? _reviewError;

  /// スクロール末尾検知用コントローラー
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 初回レビューを非同期ロード（initState 内で Future は OK）
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReviews());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _headerPageController.dispose();
    super.dispose();
  }

  // ── レビュー無限スクロール メソッド ──────────────────────────────────────

  /// スクロール位置を監視し、末尾 200px 以内に達したら追加ロードを起動する。
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        !_reviewLoadingMore &&
        _reviewHasMore) {
      _fetchReviewPage(_reviewPage);
    }
  }

  /// レビューを最初から読み直す（投稿・削除後のリフレッシュ用）。
  Future<void> _loadReviews() async {
    if (!mounted) return;
    setState(() {
      _reviews.clear();
      _reviewPage = 0;
      _reviewHasMore = true;
      _reviewInitialLoading = true;
      _reviewError = null;
    });
    await _fetchReviewPage(0);
    if (mounted) setState(() => _reviewInitialLoading = false);
  }

  /// 指定ページのレビューを Supabase から取得し [_reviews] に追記する。
  Future<void> _fetchReviewPage(int page) async {
    if (_reviewLoadingMore) return;
    if (!mounted) return;

    setState(() => _reviewLoadingMore = true);

    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      if (mounted) setState(() => _reviewLoadingMore = false);
      return;
    }

    final from = page * AppConstants.pageSize;
    final to = from + AppConstants.pageSize - 1;

    try {
      final rows = await client
          .from('reviews')
          .select('*, users!user_id(display_name, avatar_url, is_premium)')
          .eq('facility_id', widget.facilityId)
          .order('created_at', ascending: false)
          .range(from, to) as List;

      if (!mounted) return;

      final newReviews =
          rows.map((r) => Review.fromJson(r as Map<String, dynamic>)).toList();

      setState(() {
        _reviews.addAll(newReviews);
        _reviewHasMore = newReviews.length == AppConstants.pageSize;
        _reviewPage = page + 1;
        _reviewLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewLoadingMore = false;
        // 最初のページだけエラーを表示する（追加ページは静かに失敗）
        if (page == 0) _reviewError = e.toString();
      });
    }
  }

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
  // ロジックは lib/services/checkin_service.dart の CheckinService に共通化。

  Future<void> _showCheckinDialog(Facility facility) async {
    if (_isCheckingIn) return;
    await CheckinService.performCheckin(
      context: context,
      ref: ref,
      facility: facility,
      setCheckingIn: (v) {
        if (mounted) setState(() => _isCheckingIn = v);
      },
    );
  }

  // ── Report / Owner navigation ─────────────────────────────────────────────

  /// 施設情報の誤りを報告する画面へ遷移（ログイン不要）
  void _openFacilityReport(Facility facility) {
    Navigator.of(context).pushNamed(
      '/facility-report',
      arguments: {
        'facilityId': facility.id,
        'facilityName': facility.name,
      },
    );
  }

  /// オーナー登録申請画面へ遷移（ログイン必須・画面内でチェック）
  void _openOwnerRegistration(Facility facility) {
    Navigator.of(context).pushNamed(
      '/owner-registration',
      arguments: {
        'facilityId': facility.id,
        'facilityName': facility.name,
      },
    );
  }

  /// 施設情報編集画面へ遷移（承認済みオーナーのみ）
  /// pop 時に true が返ってきたら施設情報を再取得する
  Future<void> _openOwnerFacilityEdit(Facility facility) async {
    final updated = await Navigator.of(context).pushNamed(
      '/owner/facility-edit',
      arguments: facility,
    );
    if (updated == true) {
      // 編集が保存されたので施設データをリフレッシュ（providerを無効化）
      ref.invalidate(facilityDetailProvider(facility.id));
    }
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
      builder: (_) => ReviewBottomSheet(
        facilityId: facility.id,
        onSubmitted: () {
          // 投稿後はレビューをページ先頭から読み直す
          _loadReviews();
          // 統合プロバイダーを invalidate してカウント・平均を再取得
          ref.invalidate(facilityReviewSummaryProvider(facility.id));
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
    // UX-V8-9: ログイン中のみいいね済みIDを取得してトグル表示に使う
    final likedIds = isSignedIn
        ? ref.watch(likedReviewIdsProvider(facility.id)).valueOrNull ?? {}
        : <String>{};
    // レビュー削除: 現在ログイン中のユーザーIDを取得（自分のレビューのみ削除可）
    final currentUserId = ref.watch(sessionProvider)?.user.id;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Photo carousel / Map header ────────────────────────────────
          // UX-V11-3: 写真がある場合はカルーセル、ない場合は地図を表示する。
          // facilityPhotosProvider は FacilityPreviewSheet と共有の共通プロバイダー。
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
              background: Builder(
                builder: (context) {
                  final photos = ref
                          .watch(facilityPhotosProvider(facility.id))
                          .valueOrNull ??
                      [];

                  if (photos.isNotEmpty) {
                    // 写真カルーセル（PageView）
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _headerPageController,
                          itemCount: photos.length,
                          onPageChanged: (i) =>
                              setState(() => _headerPhotoIndex = i),
                          itemBuilder: (_, i) => Image.network(
                            photos[i],
                            fit: BoxFit.cover,
                            // ネットワークエラー時はプレースホルダーを表示
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(Icons.image_not_supported,
                                    size: 48, color: Colors.grey),
                              ),
                            ),
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : ColoredBox(
                                        color: Colors.grey.shade100,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                          ),
                        ),
                        // 複数枚の場合のみページインジケーターを表示
                        if (photos.length > 1)
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                photos.length,
                                (i) => AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  width: _headerPhotoIndex == i ? 16 : 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: _headerPhotoIndex == i
                                        ? Colors.white
                                        : Colors.white54,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // 写真枚数バッジ（右上）
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library_outlined,
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${_headerPhotoIndex + 1}/${photos.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // 写真なし: 従来の地図表示にフォールバック
                  if (facility.hasValidLocation) {
                    return FlutterMap(
                      options: MapOptions(
                        initialCenter: ll.LatLng(
                            facility.latitude, facility.longitude),
                        initialZoom: AppConstants.detailZoom,
                        interactionOptions: const InteractionOptions(
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
                    );
                  }

                  return ColoredBox(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.map_outlined,
                          size: 80, color: Colors.grey),
                    ),
                  );
                },
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

          // ── UX-V13-2: 平均評価サマリー（施設名直下に大きく表示）────────
          SliverToBoxAdapter(
            child: _RatingSummaryBar(facilityId: facility.id),
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
                            icon: _isCheckingIn
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('チェックイン'),
                            // 処理中は null を渡してボタンを無効化する
                            onPressed: _isCheckingIn
                                ? null
                                : () => _showCheckinDialog(facility),
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
                  ],
                ),
              ),
            ),

          // ── Amenities ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _AmenitySection(facilityId: facility.id),
          ),

          // ── オーナー専用: 施設情報編集ボタン（承認済みオーナーのみ表示）──
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, _) {
                final isOwnerAsync =
                    ref.watch(isApprovedOwnerProvider(facility.id));
                final isOwner = isOwnerAsync.valueOrNull ?? false;
                if (!isOwner) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: FilledButton.icon(
                    onPressed: () => _openOwnerFacilityEdit(facility),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('施設情報を編集する'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 施設情報の改善（ログイン不要・常時表示）──────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '施設情報の改善に協力する',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                  Row(
                    children: [
                      // 情報を報告する（ゲスト可）
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.flag_outlined, size: 17),
                          label: const Text('情報を報告する'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _openFacilityReport(facility),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // オーナー登録（画面内でログインチェック）
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.business_outlined, size: 17),
                          label: const Text('オーナー登録'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _openOwnerRegistration(facility),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

          // ── Review list（無限スクロール）─────────────────────────────
          // _reviewInitialLoading が true の間はスピナーを表示する。
          // エラーは初回ロード時のみ表示する（追加ページのエラーは無視）。
          // スクロールは CustomScrollView の controller: _scrollController で
          // _onScroll() がリッスンし、末尾 200px 以内で次ページを自動ロードする。
          if (_reviewInitialLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_reviewError != null)
            SliverToBoxAdapter(
              child: AppErrorWidget(
                message: _reviewError!,
                onRetry: _loadReviews,
              ),
            )
          else if (_reviews.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('まだレビューはありません')),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final reviewId = _reviews[i].id;
                  final alreadyLiked = likedIds.contains(reviewId);
                  // 自分のレビューかどうかを確認して削除ボタンを表示する
                  final isOwner = currentUserId != null &&
                      _reviews[i].userId == currentUserId;
                  return ReviewCard(
                    review: _reviews[i],
                    isLiked: alreadyLiked,
                    onLike: isSignedIn && !alreadyLiked
                        ? () async {
                            await ref
                                .read(reviewNotifierProvider.notifier)
                                .likeReview(reviewId);
                            // いいね後はトグル状態だけ更新し、リスト全体は再ロードしない
                            ref.invalidate(
                                likedReviewIdsProvider(facility.id));
                          }
                        : null,
                    onUnlike: isSignedIn && alreadyLiked
                        ? () async {
                            await ref
                                .read(reviewNotifierProvider.notifier)
                                .unlikeReview(reviewId);
                            ref.invalidate(
                                likedReviewIdsProvider(facility.id));
                          }
                        : null,
                    // 自分のレビューのみ編集・削除ボタンを表示する
                    onEdit: isOwner
                        ? () async {
                            // 編集ボトムシートを開く（既存の内容・評価を渡す）
                            await showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => ReviewBottomSheet(
                                facilityId: widget.facilityId,
                                existingReviewId: reviewId,
                                existingContent: _reviews[i].content,
                                existingRating: _reviews[i].rating,
                                onSubmitted: () {
                                  // 編集後はリストをページ先頭から読み直す
                                  _loadReviews();
                                  ref.invalidate(
                                      facilityReviewSummaryProvider(
                                          facility.id));
                                },
                              ),
                            );
                          }
                        : null,
                    onDelete: isOwner
                        ? () async {
                            await ref
                                .read(reviewNotifierProvider.notifier)
                                .deleteReview(reviewId);
                            // 削除後はリストをページ先頭から読み直す
                            _loadReviews();
                            ref.invalidate(
                                facilityReviewSummaryProvider(facility.id));
                          }
                        : null,
                  );
                },
                childCount: _reviews.length,
              ),
            ),

          // ── 追加ロード中スピナー / 全件表示済みメッセージ ──────────────
          if (!_reviewInitialLoading)
            SliverToBoxAdapter(
              child: _reviewLoadingMore
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (!_reviewHasMore && _reviews.isNotEmpty)
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'すべてのレビューを表示しました（${_reviews.length}件）',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
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

// ── Rating summary bar ────────────────────────────────────────────────────────

/// UX-V13-2: 施設名直下に平均評価スコアと件数を大きく表示するウィジェット。
///
/// facilityReviewSummaryProvider でサーバーサイドAVGを取得し、
/// ★評価を横並びで見やすく表示する。0件の場合は非表示。
class _RatingSummaryBar extends ConsumerWidget {
  const _RatingSummaryBar({required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(facilityReviewSummaryProvider(facilityId));

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.count == 0) return const SizedBox.shrink();

        final avg = summary.avgRating;
        final count = summary.count;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // 星アイコン（塗りつぶし）
              const Icon(Icons.star, color: Color(0xFFFFC107), size: 22),
              const SizedBox(width: 6),
              // 平均スコア（大きめのテキスト）
              Text(
                avg.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFC107),
                    ),
              ),
              const SizedBox(width: 8),
              // 星を5個並べる（半星対応）
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = avg - i;
                  if (filled >= 1) {
                    return const Icon(Icons.star,
                        color: Color(0xFFFFC107), size: 16);
                  } else if (filled >= 0.5) {
                    return const Icon(Icons.star_half,
                        color: Color(0xFFFFC107), size: 16);
                  } else {
                    return const Icon(Icons.star_border,
                        color: Color(0xFFFFC107), size: 16);
                  }
                }),
              ),
              const SizedBox(width: 8),
              // 件数テキスト
              Text(
                '($count件)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── showAddToPlanSheet (public helper) ───────────────────────────────────────

/// UX-V13-5: お気に入り画面など外部から「プランに追加」シートを呼び出す公開ヘルパー。
///
/// _AddToPlanSheet はこのファイル内のプライベートクラスなので、
/// 他の画面はこの関数を通じてシートを表示する。
Future<void> showAddToPlanSheet(
    BuildContext context, Facility facility) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _AddToPlanSheet(facility: facility),
  );
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
                  // UX-4修正: .take(5) を削除して全件表示（スクロール対応）
                  ...plans.map((plan) {
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
