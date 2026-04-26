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
  /// 検索ワード・種別・アメニティ・ソート・営業中フラグが変わったら変わる。
  String _filterKey(FacilitySearchParams p) =>
      '${p.searchQuery}|${p.facilityTypeId}|${p.amenityIds.join(",")}|${p.sortBy}|${p.isOpenNow}';

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(facilitySearchParamsProvider);
    final facilityAsync = ref.watch(facilityListProvider);
    final hasActiveFilters = params.searchQuery != null ||
        params.facilityTypeId != null ||
        params.amenityIds.isNotEmpty ||
        params.sortBy != FacilitySortBy.qualityScore ||
        params.isOpenNow;

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

    return ListView.builder(
      // 「もっと見る」ボタンと条件次第ではローディングの分を +1 する
      itemCount: _accumulatedFacilities.length + 1,
      itemBuilder: (context, i) {
        // 最終アイテム: 「もっと見る」ボタン or ローディング or 「これ以上なし」
        if (i == _accumulatedFacilities.length) {
          return _buildFooter(facilityAsync.isLoading);
        }
        final facility = _accumulatedFacilities[i];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FacilityListTile(
              facility: facility,
              onTap: () => Navigator.of(context).pushNamed(
                '/facility',
                arguments: facility.id,
              ),
            ),
            const Divider(height: 1),
          ],
        );
      },
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
