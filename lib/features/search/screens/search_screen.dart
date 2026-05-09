import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/widgets/empty_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/features/search/widgets/facility_list_tile.dart';
import 'package:yu_map/features/search/widgets/filter_bar.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/location_provider.dart';
import 'package:yu_map/providers/navigation_provider.dart';

part 'search_screen_sub_widgets.dart';
// FacilitySortBy は facility_provider.dart 経由でエクスポートされているため
// facility_service.dart を直接インポートする必要はない

/// 検索履歴を保存するストレージキー
const _kSearchHistoryKey = 'search_history_v1';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

  /// 検索バーのフォーカス管理。フォーカス時に履歴を表示するため使用。
  final _searchFocusNode = FocusNode();

  /// 検索バーがフォーカスされているかどうか。
  bool _isSearchFocused = false;

  /// 直近の検索履歴（最大5件）。SharedPreferences で永続化。
  List<String> _recentSearches = [];

  /// 検索履歴の永続化ストレージ。
  static const _storage = FlutterSecureStorage();

  /// リアルタイム検索用の debounce タイマー。
  /// ユーザーが入力を止めてから 400ms 後に検索を実行する。
  Timer? _debounceTimer;

  /// ページをまたいで蓄積された全施設リスト（「もっと見る」対応）。
  /// フィルター条件が変わったときはここをリセットする。
  List<Facility> _accumulatedFacilities = [];

  /// まだ次のページがあるかどうか。
  /// 最後に取得したページが pageSize 件ちょうどなら「あるかも」と判定する。
  bool _hasMore = false;

  /// 「もっと見る」読み込み中フラグ（二重タップ防止）。
  bool _isLoadingMore = false;

  /// フィルター条件（ページ番号を除く）の識別キー。
  /// これが変わったら蓄積リストをリセットする。
  String _prevFilterKey = '';

  // ── Filter helpers ────────────────────────────────────────────────────────

  /// フィルター条件（page除く）を文字列キーにする。
  /// 検索ワード・種別・アメニティ・ソート・営業中フラグ・都道府県・半径が変わったら変わる。
  String _filterKey(FacilitySearchParams p) =>
      '${p.searchQuery}|${p.facilityTypeId}|${p.amenityIds.join(",")}|${p.sortBy}|${p.isOpenNow}|${p.prefectureId}|${p.radiusMeters}';

  /// テキスト入力中にリアルタイムで呼ばれる。400ms のdebounce後に検索する。
  /// debounce = ユーザーが入力を止めてから少し待って検索することで、
  /// 1文字ごとに DB にアクセスしないようにする仕組み。
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(facilitySearchParamsProvider.notifier).update(
            (p) => p.copyWith(
              searchQuery: query.trim().isEmpty ? null : query.trim(),
              page: 0,
              clearText: query.trim().isEmpty,
            ),
          );
    });
  }

  /// Enterキー押下時にも確実に検索を実行する（debounce をスキップ）。
  /// 検索後は履歴に保存する。
  void _onSearchSubmitted(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(
            searchQuery: trimmed.isEmpty ? null : trimmed,
            page: 0,
            clearText: trimmed.isEmpty,
          ),
        );
    // 空でなければ履歴に保存
    if (trimmed.isNotEmpty) {
      _saveSearchQuery(trimmed);
    }
    // フォーカスを外して履歴パネルを閉じる
    _searchFocusNode.unfocus();
  }

  void _onFacilityTypeChanged(String? typeId) {
    ref.read(facilitySearchParamsProvider.notifier).update(
      (p) => typeId == null
          // null（「すべて」チップ）は clearFacilityType:true でリセット
          ? p.copyWith(clearFacilityType: true, page: 0)
          : p.copyWith(facilityTypeId: typeId, page: 0),
    );
  }

  /// 都道府県フィルターを変更する。
  /// null を渡すと「全国」（フィルターなし）に戻る。
  void _onPrefectureChanged(String? prefectureId) {
    ref.read(facilitySearchParamsProvider.notifier).update(
      (p) => prefectureId == null
          ? p.copyWith(clearPrefecture: true, page: 0)
          : p.copyWith(prefectureId: prefectureId, page: 0),
    );
  }

  /// 都道府県選択ボトムシートを表示する。
  /// ユーザーが選択すると [_onPrefectureChanged] を呼ぶ。
  Future<void> _showPrefecturePicker(String? currentPrefectureId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PrefecturePickerSheet(
        currentPrefectureId: currentPrefectureId,
        onSelected: (id) {
          Navigator.of(ctx).pop();
          _onPrefectureChanged(id);
        },
      ),
    );
  }

  /// アメニティ選択結果（ボトムシート経由）を一括で適用する。
  void _onAmenitiesChanged(List<String> ids) {
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(amenityIds: ids, page: 0),
        );
  }

  /// アメニティ選択ボトムシートを表示する。
  Future<void> _showAmenityPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AmenityPickerSheet(
        selectedIds: ref.read(facilitySearchParamsProvider).amenityIds,
        onChanged: (ids) {
          Navigator.of(ctx).pop();
          _onAmenitiesChanged(ids);
        },
      ),
    );
  }

  /// 距離フィルターを変更する。
  /// [radiusMeters] が null のとき「全国」（地理フィルターなし）に戻す。
  void _onDistanceChanged(double? radiusMeters) {
    if (radiusMeters == null) {
      ref.read(facilitySearchParamsProvider.notifier).update(
            (p) => p.copyWith(clearGeo: true, page: 0),
          );
    } else {
      final location = ref.read(currentLocationProvider);
      if (location == null) return;
      ref.read(facilitySearchParamsProvider.notifier).update(
            (p) => p.copyWith(
              latitude: location.lat,
              longitude: location.lng,
              radiusMeters: radiusMeters,
              page: 0,
            ),
          );
    }
  }

  /// UX-V9-4対応: ソート順を変更する。
  void _onSortChanged(FacilitySortBy sortBy) {
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(sortBy: sortBy, page: 0),
        );
  }

  /// UX-V9-6対応: 「今日営業中」フィルターをトグルする。
  void _onOpenNowChanged(bool value) {
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(isOpenNow: value, page: 0),
        );
  }

  void _clearFilters() {
    _debounceTimer?.cancel();
    _searchController.clear();
    ref.read(facilitySearchParamsProvider.notifier).state =
        const FacilitySearchParams();
  }

  /// 「もっと見る」ボタンが押されたとき。ページ番号を1つ増やす。
  /// facilityListProvider が再実行されて新しいページが取得される。
  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(page: p.page + 1),
        );
  }

  /// プルリフレッシュ時の処理。
  ///
  /// 現在のフィルター条件を維持しつつ page=0 に戻してリロードする。
  /// 蓄積リストをリセットして最初から表示し直す。
  /// RefreshIndicator が期待する Future<void> を返す。
  Future<void> _onRefresh() async {
    // 蓄積リストをリセット（次の build で page==0 の初回取得扱いになる）
    setState(() {
      _accumulatedFacilities = [];
      _hasMore = false;
      _isLoadingMore = false;
      _prevFilterKey = '';
    });
    // page=0 に戻して facilityListProvider を再トリガー
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(page: 0),
        );
    // プロバイダーの完了を待ってから RefreshIndicator のアニメーションを終了する
    try {
      await ref.read(facilityListProvider.future);
    } catch (_) {
      // エラー時はアニメーションを止めるだけ（AppErrorWidget が表示される）
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(facilitySearchParamsProvider);
    final facilityAsync = ref.watch(facilityListProvider);
    final hasActiveFilters = params.searchQuery != null ||
        params.facilityTypeId != null ||
        params.amenityIds.isNotEmpty ||
        params.sortBy != FacilitySortBy.qualityScore ||
        params.isOpenNow ||
        params.prefectureId != null ||
        params.radiusMeters != null;

    // フィルター条件が変わったら蓄積リストをリセットする。
    // ページ番号変更だけなら蓄積リストに追記する（「もっと見る」）。
    final currentFilterKey = _filterKey(params);
    if (currentFilterKey != _prevFilterKey) {
      // フィルター変更 → リセット
      _prevFilterKey = currentFilterKey;
      _accumulatedFacilities = [];
      _hasMore = false;
      _isLoadingMore = false;
    }

    // facilityListProvider の最新データを蓄積リストに統合する。
    facilityAsync.whenData((newPage) {
      final isNewPage = params.page > 0 && _accumulatedFacilities.isNotEmpty;
      if (isNewPage) {
        // ページ追加: 既存リストに新しいページを追記
        final existingIds = _accumulatedFacilities.map((f) => f.id).toSet();
        final toAdd = newPage.where((f) => !existingIds.contains(f.id)).toList();
        if (toAdd.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _accumulatedFacilities = [..._accumulatedFacilities, ...toAdd];
                _hasMore = newPage.length >= AppConstants.pageSize;
                _isLoadingMore = false;
              });
            }
          });
        } else {
          // 追記なし（重複 or 空）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasMore = false;
                _isLoadingMore = false;
              });
            }
          });
        }
      } else {
        // page==0: フィルター変更後の初回取得 → リストを置き換える
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _accumulatedFacilities = newPage;
              _hasMore = newPage.length >= AppConstants.pageSize;
              _isLoadingMore = false;
            });
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('施設を探す'),
        actions: [
          if (hasActiveFilters)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('クリア'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search field ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,       // リアルタイム検索
              onSubmitted: _onSearchSubmitted,   // Enter でも検索
              decoration: InputDecoration(
                // UX-V7-2: 施設名だけでなく住所・エリア名でも検索可能
                hintText: '施設名・エリア（草津、別府…）で検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: params.searchQuery != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _debounceTimer?.cancel();
                          _searchController.clear();
                          ref
                              .read(facilitySearchParamsProvider.notifier)
                              .update((p) => p.copyWith(
                                    clearText: true,
                                    page: 0,
                                  ));
                        },
                      )
                    : null,
              ),
            ),
          ),
          // ── 検索履歴パネル ─────────────────────────────────────────────────
          // 検索バーにフォーカスが当たっていて、テキストが未入力 & 履歴がある場合のみ表示。
          if (_isSearchFocused &&
              _searchController.text.isEmpty &&
              _recentSearches.isNotEmpty)
            _RecentSearchesPanel(
              searches: _recentSearches,
              onTap: _onRecentSearchTap,
              onRemove: _removeSearchQuery,
            ),
          const SizedBox(height: 8),
          // ── Filter chips ─────────────────────────────────────────────────
          FilterBar(
            selectedFacilityTypeId: params.facilityTypeId,
            selectedAmenityIds: params.amenityIds,
            onFacilityTypeChanged: _onFacilityTypeChanged,
            onShowAmenityPicker: _showAmenityPicker,
            isOpenNow: params.isOpenNow,
            onOpenNowChanged: _onOpenNowChanged,
          ),
          // ── Prefecture filter chip ────────────────────────────────────
          // 都道府県フィルター。タップするとボトムシートで都道府県一覧を表示する。
          // 選択中の場合はチップに都道府県名を表示し、ピンアイコンで強調する。
          _PrefectureFilterChip(
            currentPrefectureId: params.prefectureId,
            onTap: () => _showPrefecturePicker(params.prefectureId),
            onClear: () => _onPrefectureChanged(null),
          ),
          // ── Distance filter chips ─────────────────────────────────────
          _DistanceFilterRow(
            selectedRadiusMeters: params.radiusMeters,
            onDistanceChanged: _onDistanceChanged,
          ),
          // ── Sort chips（UX-V9-4 + UX-V11-1対応）──────────────────────
          // 検索結果の並び順を「品質順」「名前順」「距離順」から選べる。
          // ChoiceChip = ラジオボタンのような択一選択UI。
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Text(
                    '並び順:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  _SortChip(
                    label: '品質順',
                    selected: params.sortBy == FacilitySortBy.qualityScore,
                    onSelected: (_) => _onSortChanged(FacilitySortBy.qualityScore),
                  ),
                  const SizedBox(width: 6),
                  _SortChip(
                    label: '名前順',
                    selected: params.sortBy == FacilitySortBy.name,
                    onSelected: (_) => _onSortChanged(FacilitySortBy.name),
                  ),
                  const SizedBox(width: 6),
                  _SortChip(
                    label: '距離順',
                    selected: params.sortBy == FacilitySortBy.distance,
                    onSelected: (_) => _onSortChanged(FacilitySortBy.distance),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // ── Result list ──────────────────────────────────────────────────
          Expanded(
            child: _buildResultList(
              context,
              facilityAsync,
              hasActiveFilters,
              params,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList(
    BuildContext context,
    AsyncValue<List<Facility>> facilityAsync,
    bool hasActiveFilters,
    FacilitySearchParams params,
  ) {
    // 初回ロード中（蓄積リストが空）はローディングを表示する。
    // 「もっと見る」の2ページ目以降は蓄積リストを表示しながら下にスピナーを出す。
    if (facilityAsync.isLoading && _accumulatedFacilities.isEmpty) {
      return const LoadingWidget();
    }

    if (facilityAsync.hasError && _accumulatedFacilities.isEmpty) {
      return AppErrorWidget(
        message: facilityAsync.error.toString(),
        onRetry: () => ref.invalidate(facilityListProvider),
      );
    }

    if (_accumulatedFacilities.isEmpty) {
      return EmptyWidget(
        icon: Icons.search_off,
        message: '施設が見つかりませんでした',
        action: hasActiveFilters
            ? TextButton(
                onPressed: _clearFilters,
                child: const Text('フィルターをクリア'),
              )
            : null,
      );
    }

    // フィルターなし（検索語・種別・その他）の場合はリスト先頭に「今週の人気」を表示
    final showTrending = !hasActiveFilters && params.page == 0;

    // UX-V25-1: 引っ張って更新（プルリフレッシュ）対応。
    // ListView の件数が少ないときでも引っ張れるよう AlwaysScrollableScrollPhysics を指定。
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      // showTrending の場合はインデックス0に人気施設ウィジェットを挿入
      itemCount: _accumulatedFacilities.length + (showTrending ? 2 : 1),
      itemBuilder: (context, i) {
        // フィルターなし時: index 0 = 人気施設セクション
        if (showTrending && i == 0) {
          return _TrendingFacilitiesSection(
            onFacilityTap: (facilityId) =>
                Navigator.of(context).pushNamed('/facility', arguments: facilityId),
          );
        }

        // showTrending の場合はインデックスを 1 ずらす
        final listIndex = showTrending ? i - 1 : i;

        // 最終アイテム: 「もっと見る」ボタン or ローディング
        if (listIndex == _accumulatedFacilities.length) {
          return _buildFooter(facilityAsync.isLoading);
        }
        final facility = _accumulatedFacilities[listIndex];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: FacilityListTile(
                    facility: facility,
                    onTap: () => Navigator.of(context).pushNamed(
                      '/facility',
                      arguments: facility.id,
                    ),
                  ),
                ),
                // 地図で見る / お気に入り / 詳細を見る のポップアップメニュー
                _FacilityPopupMenu(facility: facility),
              ],
            ),
            const Divider(height: 1),
          ],
        );
      },
      ),
    );
  }

  /// リスト末尾に表示するフッター。
  /// - ロード中: スピナー
  /// - まだある: 「もっと見る」ボタン
  /// - 全件表示済み: 空白
  Widget _buildFooter(bool isLoading) {
    if (isLoading && _isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.expand_more, size: 18),
            label: Text(
              'もっと見る（${_accumulatedFacilities.length}件表示中）',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      );
    }
    // 全件表示済み
    if (_accumulatedFacilities.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '${_accumulatedFacilities.length}件をすべて表示しました',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void initState() {
    super.initState();
    // Bug-3修正: 地図画面など他の場所でsearchQueryが設定されている場合に
    // テキストフィールドをプロバイダーの値と同期する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentQuery =
          ref.read(facilitySearchParamsProvider).searchQuery ?? '';
      if (_searchController.text != currentQuery) {
        _searchController.text = currentQuery;
      }
    });
    // 検索履歴をストレージから読み込む
    _loadRecentSearches();
    // フォーカス状態の変化を監視して履歴パネルの表示を切り替える
    _searchFocusNode.addListener(_onFocusChanged);
  }

  /// ストレージから検索履歴を読み込む。
  Future<void> _loadRecentSearches() async {
    try {
      final raw = await _storage.read(key: _kSearchHistoryKey);
      if (raw != null && mounted) {
        final list = List<String>.from(
          jsonDecode(raw) as List<dynamic>,
        );
        setState(() => _recentSearches = list);
      }
    } catch (_) {
      // 読み込みに失敗しても検索機能には影響しない
    }
  }

  /// 検索履歴にキーワードを追加してストレージに保存する。
  ///
  /// 同じキーワードが既にある場合は先頭に移動する。
  /// 最大5件を超えた場合は末尾から削除する。
  Future<void> _saveSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final updated = [
      trimmed,
      ..._recentSearches.where((q) => q != trimmed),
    ].take(5).toList();
    if (mounted) setState(() => _recentSearches = updated);
    try {
      await _storage.write(
        key: _kSearchHistoryKey,
        value: jsonEncode(updated),
      );
    } catch (_) {
      // 保存に失敗しても検索機能には影響しない
    }
  }

  /// 特定の検索履歴を削除してストレージを更新する。
  Future<void> _removeSearchQuery(String query) async {
    final updated = _recentSearches.where((q) => q != query).toList();
    if (mounted) setState(() => _recentSearches = updated);
    try {
      await _storage.write(
        key: _kSearchHistoryKey,
        value: jsonEncode(updated),
      );
    } catch (_) {}
  }

  /// 検索バーのフォーカス変化を処理する。
  void _onFocusChanged() {
    if (mounted) {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    }
  }

  /// 検索履歴のキーワードをタップして検索を実行する。
  void _onRecentSearchTap(String query) {
    _searchController.text = query;
    _searchFocusNode.unfocus();
    _debounceTimer?.cancel();
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(searchQuery: query, page: 0),
        );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchFocusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }
}

