import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/widgets/empty_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/features/search/widgets/facility_list_tile.dart';
import 'package:yu_map/features/search/widgets/filter_bar.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/navigation_provider.dart';
// FacilitySortBy は facility_provider.dart 経由でエクスポートされているため
// facility_service.dart を直接インポートする必要はない

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

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
  /// 検索ワード・種別・アメニティ・ソート・営業中フラグ・都道府県が変わったら変わる。
  String _filterKey(FacilitySearchParams p) =>
      '${p.searchQuery}|${p.facilityTypeId}|${p.amenityIds.join(",")}|${p.sortBy}|${p.isOpenNow}|${p.prefectureId}';

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
  void _onSearchSubmitted(String query) {
    _debounceTimer?.cancel();
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(
            searchQuery: query.trim().isEmpty ? null : query.trim(),
            page: 0,
            clearText: query.trim().isEmpty,
          ),
        );
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

  /// Toggles [amenityId] in the selection while preserving all other
  /// selected amenity IDs.
  void _onAmenityToggled(String amenityId) {
    ref.read(facilitySearchParamsProvider.notifier).update((p) {
      final current = List<String>.from(p.amenityIds);
      if (current.contains(amenityId)) {
        current.remove(amenityId);
      } else {
        current.add(amenityId);
      }
      return p.copyWith(amenityIds: current, page: 0);
    });
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
        params.prefectureId != null;

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
          const SizedBox(height: 8),
          // ── Filter chips ─────────────────────────────────────────────────
          FilterBar(
            selectedFacilityTypeId: params.facilityTypeId,
            selectedAmenityIds: params.amenityIds,
            onFacilityTypeChanged: _onFacilityTypeChanged,
            onAmenityToggled: _onAmenityToggled,
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
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

// ── 今週の人気施設セクション ─────────────────────────────────────────────────────

/// 検索画面上部に表示する横スクロール可能な「今週の人気施設」カードリスト。
/// trendingFacilitiesProvider から取得したデータを表示する。
/// フィルターなし・ページ0のときのみ表示される。
class _TrendingFacilitiesSection extends ConsumerWidget {
  const _TrendingFacilitiesSection({required this.onFacilityTap});

  final void Function(String facilityId) onFacilityTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingFacilitiesProvider);

    return trendingAsync.when(
      // データなし or 空 → セクションを非表示
      data: (facilities) {
        if (facilities.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    '今週の人気施設',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 130,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: facilities.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _TrendingCard(
                  facility: facilities[index],
                  onTap: () => onFacilityTap(facilities[index].id),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'すべての施設',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        );
      },
      // ロード中 → 小さなインジケーターだけ
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      // エラー → 非表示（UX を壊さない）
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// 人気施設1件分のコンパクトなカード（横スクロール用）。
class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.facility, required this.onTap});

  final Facility facility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 施設タイプ別アイコン
    final icon = switch (facility.facilityType) {
      'onsen' => '♨️',
      'sauna' => '🧖',
      'public_bath' => '🛁',
      _ => '🏠',
    };

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: SizedBox(
          width: 130,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // タイプアイコン
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                // 施設名（最大2行）
                Text(
                  facility.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // 住所（1行）
                if (facility.address != null && facility.address!.isNotEmpty)
                  Text(
                    facility.address!,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withAlpha(140),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 都道府県フィルターチップ ─────────────────────────────────────────────────────

/// 検索画面に表示する都道府県フィルターのコンパクトな行。
/// - 未選択: 「都道府県を選ぶ」 グレーチップ → タップでピッカーを開く
/// - 選択中: 「東京都」 カラーチップ + 「×」ボタン → × でリセット / チップタップで変更
class _PrefectureFilterChip extends ConsumerWidget {
  const _PrefectureFilterChip({
    required this.currentPrefectureId,
    required this.onTap,
    required this.onClear,
  });

  final String? currentPrefectureId;
  final VoidCallback onTap;   // チップタップ → ピッカーを開く
  final VoidCallback onClear; // × ボタン → フィルターをリセット

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefecturesAsync = ref.watch(prefectureOptionsProvider);

    return prefecturesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (prefectures) {
        if (prefectures.isEmpty) return const SizedBox.shrink();

        // 選択中の都道府県名を取得する（IDから名前に変換）
        final selectedName = currentPrefectureId == null
            ? null
            : prefectures
                .where((p) => p.id == currentPrefectureId)
                .map((p) => p.name)
                .firstOrNull;
        final isSelected = currentPrefectureId != null;
        final colorScheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              const Text(
                'エリア:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              // メインチップ: 未選択 = グレー, 選択中 = プライマリカラー
              ActionChip(
                avatar: Icon(
                  Icons.place,
                  size: 14,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                ),
                label: Text(
                  isSelected ? (selectedName ?? '都道府県') : '都道府県を選ぶ',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                ),
                backgroundColor: isSelected
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                // 選択済み・未選択どちらもタップでピッカーを開く（変更も可能）
                onPressed: onTap,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              // 選択中のとき「×」クリアボタンを横に表示する
              if (isSelected) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.cancel,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── 都道府県ピッカーボトムシート ──────────────────────────────────────────────────

/// 都道府県一覧をボトムシートで表示する。
/// 「全国」(null) + 47都道府県を地域別に区切り線を入れて表示する。
class _PrefecturePickerSheet extends ConsumerWidget {
  const _PrefecturePickerSheet({
    required this.currentPrefectureId,
    required this.onSelected,
  });

  final String? currentPrefectureId;

  /// 都道府県IDを引数として呼ばれる。null は「全国」を意味する。
  final void Function(String? id) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefecturesAsync = ref.watch(prefectureOptionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // ── ドラッグハンドル ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── タイトル ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text(
                    '都道府県を選ぶ',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── 都道府県リスト ─────────────────────────────────────────────
            Expanded(
              child: prefecturesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('読み込みエラー: $e')),
                data: (prefectures) {
                  // 「全国」オプション + 47都道府県を地域でグループ分けして表示する。
                  // 地域の順番: 北海道→東北→関東→中部→近畿→中国→四国→九州・沖縄
                  final regions = <String>[
                    '北海道', '東北', '関東', '中部', '近畿', '中国', '四国', '九州・沖縄',
                  ];

                  // 地域別にグループ化する
                  final byRegion = <String, List<PrefectureOption>>{};
                  final noRegion = <PrefectureOption>[];
                  for (final p in prefectures) {
                    if (p.region != null && regions.contains(p.region)) {
                      byRegion.putIfAbsent(p.region!, () => []).add(p);
                    } else {
                      noRegion.add(p);
                    }
                  }

                  // 表示するアイテムリスト（ヘッダーと施設をフラットにまとめる）
                  final items = <_ListItem>[];

                  // 「全国」行（フィルターをクリアする）
                  items.add(_PrefectureItem(null, '全国（絞り込みなし）'));

                  // 地域別グループを順番通りに追加する
                  for (final region in regions) {
                    final group = byRegion[region];
                    if (group == null || group.isEmpty) continue;
                    items.add(_RegionHeader(region));
                    for (final p in group) {
                      items.add(_PrefectureItem(p.id, p.name));
                    }
                  }

                  // 地域未設定の都道府県（DBデータが不完全な場合の安全網）
                  if (noRegion.isNotEmpty) {
                    items.add(const _RegionHeader('その他'));
                    for (final p in noRegion) {
                      items.add(_PrefectureItem(p.id, p.name));
                    }
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      if (item is _RegionHeader) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }
                      final prefItem = item as _PrefectureItem;
                      final isSelected = prefItem.id == currentPrefectureId ||
                          (prefItem.id == null && currentPrefectureId == null);
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(
                          prefItem.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () => onSelected(prefItem.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── ピッカー内部用の sealed リスト項目 ────────────────────────────────────────

/// ピッカーリストのアイテム基底クラス（ヘッダー or 都道府県行）
sealed class _ListItem {
  const _ListItem();
}

class _RegionHeader extends _ListItem {
  final String label;
  const _RegionHeader(this.label);
}

class _PrefectureItem extends _ListItem {
  final String? id; // null = 「全国」
  final String label;
  const _PrefectureItem(this.id, this.label);
}

// ── ソートチップ ──────────────────────────────────────────────────────────────

/// 選択可能な小さなチップ。ChoiceChipをコンパクトにラップする。
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final void Function(bool) onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── 検索リスト用ポップアップメニュー ──────────────────────────────────────────

/// 検索結果タイルの「⋮」ポップアップメニュー。
/// 「地図で見る」「お気に入りに追加/解除」「詳細を見る」の3項目を提供する。
/// ConsumerWidget にすることで isFavoriteProvider を watch できる。
class _FacilityPopupMenu extends ConsumerWidget {
  const _FacilityPopupMenu({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(facility.id));

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
      tooltip: 'メニュー',
      onSelected: (value) async {
        switch (value) {
          case 'show_on_map':
            ref.read(mapFlyToProvider.notifier).state = (
              lat: facility.latitude,
              lng: facility.longitude,
            );
            ref.read(homeTabIndexProvider.notifier).state = 0;
          case 'toggle_favorite':
            await ref
                .read(favoritesProvider.notifier)
                .toggle(facility.id);
            if (!context.mounted) return;
            final now = ref.read(isFavoriteProvider(facility.id));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(now ? 'お気に入りに追加しました' : 'お気に入りを解除しました'),
                duration: const Duration(seconds: 2),
              ),
            );
          case 'open_detail':
            Navigator.of(context).pushNamed(
              '/facility',
              arguments: facility.id,
            );
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'show_on_map',
          child: Row(
            children: [
              Icon(Icons.map_outlined, size: 18),
              SizedBox(width: 8),
              Text('地図で見る'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle_favorite',
          child: Row(
            children: [
              Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: isFavorite ? Colors.red : null,
              ),
              const SizedBox(width: 8),
              Text(isFavorite ? 'お気に入りを解除' : 'お気に入りに追加'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'open_detail',
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18),
              SizedBox(width: 8),
              Text('詳細を見る'),
            ],
          ),
        ),
      ],
    );
  }
}
