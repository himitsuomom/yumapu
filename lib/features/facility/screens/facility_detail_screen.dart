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
part 'facility_detail_screen_sections.dart';

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

  void _onHeaderPageChanged(int i) => setState(() => _headerPhotoIndex = i);

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

}

