import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/widgets/banner_ad_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/guest_restriction_dialog.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/core/widgets/photo_gallery_viewer.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/features/facility/widgets/add_to_plan_sheet.dart';
import 'package:yu_map/features/facility/widgets/facility_amenity_section.dart';
import 'package:yu_map/features/facility/widgets/facility_info_section.dart';
import 'package:yu_map/features/facility/widgets/facility_rating_bar.dart';
import 'package:yu_map/features/facility/widgets/review_card.dart';
import 'package:yu_map/features/reviews/widgets/review_bottom_sheet.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/review_provider.dart';
import 'package:yu_map/providers/navigation_provider.dart';
import 'package:yu_map/services/analytics_service.dart';
import 'package:yu_map/services/checkin_service.dart';
import 'package:yu_map/services/review_service.dart';

part 'facility_detail_screen_sub_widgets.dart';

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
    if (AppConfig.isReviewEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadReviews());
    }
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

  /// 指定ページのレビューを ReviewService 経由で取得し [_reviews] に追記する。
  ///
  /// 直接 Supabase を呼ぶ代わりに ReviewService.fetchPage() を使うことで:
  ///   - ウィジェットがデータ層に直接依存しない（責務の分離）
  ///   - テスト時に ReviewService をモックしやすくなる
  Future<void> _fetchReviewPage(int page) async {
    if (_reviewLoadingMore) return;
    if (!mounted) return;

    setState(() => _reviewLoadingMore = true);

    final client = ref.read(supabaseClientProvider);

    try {
      final newReviews = await ReviewService.fetchPage(
        client: client,
        facilityId: widget.facilityId,
        page: page,
      );

      if (!mounted) return;

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

  // ── Share（施設URLシェア）─────────────────────────────────────────────────
  //
  // share_plus を使って「https://yumap.app/facility/{id}」形式のURLをシェアする。
  // URLを受け取った端末でアプリが開いている場合は app_links 経由でその施設へ遷移する。

  void _shareFacility(Facility facility) {
    final url = '${AppConstants.deepLinkBaseUrl}/facility/${facility.id}';
    final text = '${facility.name}\n$url';
    Share.share(text, subject: '湯マップ — ${facility.name}');
  }

  // ── 地図タブへ遷移 ────────────────────────────────────────────────────────
  // 施設詳細から「地図で確認」をタップした時の処理。
  // 1. mapFlyToProvider に座標をセットして MapScreen にカメラ移動を伝える
  // 2. homeTabIndexProvider を 0（地図タブ）に切り替える
  // 3. この詳細画面を閉じてホームに戻る

  void _goToMapTab(Facility facility) {
    // MapScreen がこのプロバイダーを watch し、非 null のときカメラを移動する
    ref.read(mapFlyToProvider.notifier).state = (
      lat: facility.latitude,
      lng: facility.longitude,
    );
    // ボトムナビを地図タブに切り替える（favorites_screen.dart と同じパターン）
    ref.read(homeTabIndexProvider.notifier).state = 0;
    // 施設詳細画面（pushNamed で積まれている）を閉じてホームシェルに戻る
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ── Check-in dialog ───────────────────────────────────────────────────────

  /// UX-61: チェックイン機能が Feature Flag でオフの場合に表示する「準備中」バー。
  /// 機能の存在をユーザーに伝え、完全に消えてしまうことを防ぐ。
  Widget _buildCheckinComingSoonBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(
              Icons.hourglass_empty_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
            label: Text(
              'チェックイン（近日公開）',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            // 準備中のため操作不可
            onPressed: null,
          ),
        ),
      ),
    );
  }

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
    await showAddToPlanSheet(context, facility);
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
    // UX-V27-2: ゲストモード時も「ログインしてチェックイン」ボタンを表示するために取得する。
    final isGuestMode = ref.watch(guestModeProvider);
    final isFavorite = ref.watch(isFavoriteProvider(facility.id));
    // UX-V8-9: ログイン中のみいいね済みIDを取得してトグル表示に使う
    final likedIds = isSignedIn
        ? ref.watch(likedReviewIdsProvider(facility.id)).valueOrNull ?? {}
        : <String>{};
    // レビュー削除: 現在ログイン中のユーザーIDを取得（自分のレビューのみ削除可）
    final currentUserId = ref.watch(sessionProvider)?.user.id;
    final photos =
        ref.watch(facilityPhotosProvider(facility.id)).valueOrNull ?? [];

    return Scaffold(
      // UX-V27-1: チェックインボタンをScaffold底部に固定する。
      // スクロールしてレビューを読んでいても常にチェックインできる。
      // UX-V27-2: ゲストモードでは「ログインしてチェックイン」を表示し、
      //           タップするとログイン誘導ダイアログが出る。
      // UX-61: isCheckinEnabled == false の場合も「準備中」バーを表示し、
      //        機能が存在することをユーザーに伝える（完全非表示を避ける）。
      bottomNavigationBar: AppConfig.isCheckinEnabled && (isSignedIn || isGuestMode)
          ? _StickyCheckinBar(
              facility: facility,
              isSignedIn: isSignedIn,
              isCheckingIn: _isCheckingIn,
              onCheckin: () => _showCheckinDialog(facility),
            )
          : !AppConfig.isCheckinEnabled
              ? _buildCheckinComingSoonBar()
              : null,
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
              background: _FacilityHeaderBackground(
                photos: photos,
                controller: _headerPageController,
                currentIndex: _headerPhotoIndex,
                onPageChanged: (i) => setState(() => _headerPhotoIndex = i),
                facility: facility,
              ),
            ),
            actions: [
              // Share button（ゲスト・ログイン問わず全員使える）
              IconButton(
                tooltip: 'シェア',
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () => _shareFacility(facility),
              ),
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
            child: FacilityRatingBar(facilityId: facility.id),
          ),

          // ── Facility info ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FacilityInfoSection(
              facility: facility,
              onPhone: facility.phone != null
                  ? () => _launchPhone(facility.phone!)
                  : null,
              onWebsite: facility.website != null
                  ? () => _launchUrl(facility.website!)
                  : null,
              onGoToMap: facility.hasValidLocation
                  ? () => _goToMapTab(facility)
                  : null,
            ),
          ),

          // ── Action buttons (login only) ────────────────────────────────
          if (isSignedIn)
            SliverToBoxAdapter(
              child: _FacilityActionButtons(
                onReview: AppConfig.isReviewEnabled
                    ? () => _showReviewSheet(facility)
                    : null,
                onPlan: () => _showAddToPlanSheet(facility),
              ),
            ),

          // ── Amenities ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FacilityAmenitySection(facilityId: facility.id),
          ),

          // ── オーナー専用: 施設情報編集ボタン（承認済みオーナーのみ表示）──
          SliverToBoxAdapter(
            child: _OwnerEditButton(
              facilityId: facility.id,
              onEdit: () => _openOwnerFacilityEdit(facility),
            ),
          ),

          // ── 施設情報の改善（ログイン不要・常時表示）──────────────────────
          SliverToBoxAdapter(
            child: _FacilityImproveSection(
              onReport: () => _openFacilityReport(facility),
              onOwner: () => _openOwnerRegistration(facility),
            ),
          ),

          // ── Reviews header ─────────────────────────────────────────────
          if (AppConfig.isReviewEnabled)
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
          if (AppConfig.isReviewEnabled && _reviewInitialLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (AppConfig.isReviewEnabled && _reviewError != null)
            SliverToBoxAdapter(
              child: AppErrorWidget(
                message: _reviewError!,
                onRetry: _loadReviews,
              ),
            )
          else if (AppConfig.isReviewEnabled && _reviews.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyReviewView(
                isSignedIn: isSignedIn,
                onWrite: () => _showReviewSheet(facility),
                onLogin: () => Navigator.of(context).pushNamed('/login'),
              ),
            )
          else if (AppConfig.isReviewEnabled)
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
              child: _ReviewFooter(
                loadingMore: _reviewLoadingMore,
                hasMore: _reviewHasMore,
                reviewCount: _reviews.length,
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

