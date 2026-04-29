import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/widgets/banner_ad_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/core/widgets/photo_gallery_viewer.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/features/facility/screens/facility_report_screen.dart';
import 'package:yu_map/features/facility/screens/owner_facility_edit_screen.dart';
import 'package:yu_map/features/facility/screens/owner_registration_screen.dart';
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
import 'package:yu_map/providers/visit_provider.dart';
import 'package:yu_map/providers/navigation_provider.dart';
import 'package:yu_map/services/analytics_service.dart';
import 'package:yu_map/services/checkin_service.dart';
import 'package:yu_map/services/review_service.dart';

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
                    // 写真カルーセル（PageView）+ タップでフルスクリーン表示
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _headerPageController,
                          itemCount: photos.length,
                          onPageChanged: (i) =>
                              setState(() => _headerPhotoIndex = i),
                          itemBuilder: (context, i) => GestureDetector(
                            // タップすると PhotoGalleryViewer をフルスクリーンで表示する。
                            // ピンチズーム・スワイプ操作が可能になる。
                            onTap: () => PhotoGalleryViewer.show(
                              context,
                              photos: photos,
                              initialIndex: _headerPhotoIndex,
                            ),
                            child: Image.network(
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
                        // 写真枚数バッジ + 拡大ヒント（右上）
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
                                const Icon(Icons.zoom_in,
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
            child: FacilityAmenitySection(facilityId: facility.id),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'まだクチコミがありません',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'あなたが最初にクチコミを書いてみましょう！',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isSignedIn)
                      FilledButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('最初のクチコミを書く'),
                        onPressed: () => _showReviewSheet(facility),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text('ログインしてクチコミを書く'),
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/login'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                  ],
                ),
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

