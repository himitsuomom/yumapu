// lib/features/explore/screens/explore_screen.dart
//
// 地図と検索UIを1つの画面に統合した「探す」画面（#9 統合 Phase A）
//
// 構造:
//   - 背景全体: MapScreen（地図・マーカー・検索バー・フィルターFABをそのまま使用）
//   - 前景オーバーレイ: DraggableScrollableSheet で施設リストを下から表示
//     - 上スワイプで最大90%まで展開
//     - 初期表示は30%（地図が見える状態）
//
// Phase A の方針:
//   MapScreen と SearchScreen の機能を壊さず再利用する。
//   状態管理の完全統合（exploreSearchParamsProvider）は Phase B 以降で対応。

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
import 'package:yu_map/features/map/screens/map_screen.dart';
import 'package:yu_map/features/search/widgets/facility_list_tile.dart';
import 'package:yu_map/features/search/widgets/filter_bar.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/navigation_provider.dart';

part 'explore_screen_sub_widgets.dart';

/// 検索履歴を保存するストレージキー（SearchScreen と同じキーを共有）
const _kExploreSearchHistoryKey = 'search_history_v1';

/// 地図と施設リストを1画面に統合した「探す」タブ画面。
///
/// [MapScreen] を背景として全画面に表示し、[DraggableScrollableSheet] で
/// 施設リストを下部からオーバーレイ表示する。
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // MapScreen は自前の Scaffold を持つが、HomeShell の body は
    // BottomNavigationBar の高さ分だけ制約される。
    // clipBehavior: Clip.hardEdge でネストした Scaffold の描画が
    // 隣接タブ側にはみ出すのを防ぐ。
    return const Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // ── 背景: 地図（MapScreen をそのまま利用）──────────────────────────
        MapScreen(),
        // ── 前景: 施設リストの DraggableScrollableSheet ──────────────────
        _FacilityListSheet(),
      ],
    );
  }
}

// ── 施設リストシート ───────────────────────────────────────────────────────────

/// 画面下部からスワイプで展開できる施設リストシート。
///
/// SearchScreen の施設リスト・フィルター・ソート機能を
/// DraggableScrollableSheet にラップして地図の上に重ねる。
class _FacilityListSheet extends ConsumerStatefulWidget {
  const _FacilityListSheet();

  @override
  ConsumerState<_FacilityListSheet> createState() => _FacilityListSheetState();
}

class _FacilityListSheetState extends ConsumerState<_FacilityListSheet> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  List<String> _recentSearches = [];
  static const _storage = FlutterSecureStorage();
  Timer? _debounceTimer;
  List<Facility> _accumulatedFacilities = [];
  bool _hasMore = false;
  bool _isLoadingMore = false;
  Map<String, int> _checkinCounts = {};
  String _prevFilterKey = '';

  String _filterKey(FacilitySearchParams p) =>
      '${p.searchQuery}|${p.facilityTypeId}|${p.amenityIds.join(",")}|${p.sortBy}|${p.isOpenNow}|${p.prefectureId}|${p.radiusMeters}';

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
    if (trimmed.isNotEmpty) _saveSearchQuery(trimmed);
    _searchFocusNode.unfocus();
  }

  void _onFacilityTypeChanged(String? typeId) {
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => typeId == null
              ? p.copyWith(clearFacilityType: true, page: 0)
              : p.copyWith(facilityTypeId: typeId, page: 0),
        );
  }

  void _onAmenityToggled(String amenityId) {
    final currentIds = ref.read(facilitySearchParamsProvider).amenityIds;
    final newIds = currentIds.contains(amenityId)
        ? currentIds.where((id) => id != amenityId).toList()
        : [...currentIds, amenityId];
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(amenityIds: newIds, page: 0),
        );
  }

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

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(page: p.page + 1),
        );
  }

  Future<void> _onRefresh() async {
    setState(() {
      _accumulatedFacilities = [];
      _hasMore = false;
      _isLoadingMore = false;
      _prevFilterKey = '';
    });
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(page: 0),
        );
    try {
      await ref.read(facilityListProvider.future);
    } catch (_) {}
  }

  Future<void> _loadRecentSearches() async {
    try {
      final raw = await _storage.read(key: _kExploreSearchHistoryKey);
      if (raw != null && mounted) {
        final list = List<String>.from(jsonDecode(raw) as List<dynamic>);
        setState(() => _recentSearches = list);
      }
    } catch (_) {}
  }

  Future<void> _saveSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final updated =
        [trimmed, ..._recentSearches.where((q) => q != trimmed)].take(5).toList();
    if (mounted) setState(() => _recentSearches = updated);
    try {
      await _storage.write(
          key: _kExploreSearchHistoryKey, value: jsonEncode(updated));
    } catch (_) {}
  }

  Future<void> _removeSearchQuery(String query) async {
    final updated = _recentSearches.where((q) => q != query).toList();
    if (mounted) setState(() => _recentSearches = updated);
    try {
      await _storage.write(
          key: _kExploreSearchHistoryKey, value: jsonEncode(updated));
    } catch (_) {}
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
  }

  void _onRecentSearchTap(String query) {
    _searchController.text = query;
    _searchFocusNode.unfocus();
    _debounceTimer?.cancel();
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(searchQuery: query, page: 0),
        );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentQuery =
          ref.read(facilitySearchParamsProvider).searchQuery ?? '';
      if (_searchController.text != currentQuery) {
        _searchController.text = currentQuery;
      }
    });
    _loadRecentSearches();
    _searchFocusNode.addListener(_onFocusChanged);
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

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(facilitySearchParamsProvider);
    final facilityAsync = ref.watch(facilityListProvider);

    final checkinKey =
        (_accumulatedFacilities.map((f) => f.id).toList()..sort()).join(',');
    _checkinCounts =
        ref.watch(weeklyCheckinCountsProvider(checkinKey)).valueOrNull ?? {};

    final hasActiveFilters = params.searchQuery != null ||
        params.facilityTypeId != null ||
        params.amenityIds.isNotEmpty ||
        params.sortBy != FacilitySortBy.qualityScore ||
        params.isOpenNow ||
        params.prefectureId != null ||
        params.radiusMeters != null;

    final currentFilterKey = _filterKey(params);
    if (currentFilterKey != _prevFilterKey) {
      _prevFilterKey = currentFilterKey;
      _accumulatedFacilities = [];
      _hasMore = false;
      _isLoadingMore = false;
    }

    facilityAsync.whenData((newPage) {
      final isNewPage = params.page > 0 && _accumulatedFacilities.isNotEmpty;
      if (isNewPage) {
        final existingIds = _accumulatedFacilities.map((f) => f.id).toSet();
        final toAdd =
            newPage.where((f) => !existingIds.contains(f.id)).toList();
        if (toAdd.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _accumulatedFacilities = [
                  ..._accumulatedFacilities,
                  ...toAdd,
                ];
                _hasMore = newPage.length >= AppConstants.pageSize;
                _isLoadingMore = false;
              });
            }
          });
        } else {
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

    return DraggableScrollableSheet(
      initialChildSize: 0.43,
      minChildSize: 0.43,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: const [
              BoxShadow(blurRadius: 8, color: Colors.black12),
            ],
          ),
          child: Column(
            children: [
              // ── ドラッグハンドル ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── 検索バー ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmitted,
                  decoration: InputDecoration(
                    hintText: '施設名・エリア（草津、別府…）で検索',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
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
              // ── 検索履歴パネル ───────────────────────────────────────────
              if (_isSearchFocused &&
                  _searchController.text.isEmpty &&
                  _recentSearches.isNotEmpty)
                _ExploreRecentSearchesPanel(
                  searches: _recentSearches,
                  onTap: _onRecentSearchTap,
                  onRemove: _removeSearchQuery,
                ),
              const SizedBox(height: 4),
              // ── フィルターバー ───────────────────────────────────────────
              FilterBar(
                selectedFacilityTypeId: params.facilityTypeId,
                selectedAmenityIds: params.amenityIds,
                onFacilityTypeChanged: _onFacilityTypeChanged,
                onAmenityToggled: _onAmenityToggled,
                isOpenNow: params.isOpenNow,
                onOpenNowChanged: _onOpenNowChanged,
              ),
              // ── ソート + クリア ──────────────────────────────────────────
              _ExploreSortRow(
                params: params,
                hasActiveFilters: hasActiveFilters,
                onSortChanged: (sortBy) {
                  ref.read(facilitySearchParamsProvider.notifier).update(
                        (p) => p.copyWith(sortBy: sortBy, page: 0),
                      );
                },
                onClearFilters: _clearFilters,
              ),
              const Divider(height: 1),
              // ── 施設リスト ───────────────────────────────────────────────
              Expanded(
                child: _buildResultList(
                  context,
                  facilityAsync,
                  hasActiveFilters,
                  params,
                  scrollController,
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildResultList(
    BuildContext context,
    AsyncValue<List<Facility>> facilityAsync,
    bool hasActiveFilters,
    FacilitySearchParams params,
    ScrollController scrollController,
  ) {
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
      // Data arrived but addPostFrameCallback setState hasn't fired yet —
      // show loading briefly to avoid a one-frame flash of the empty state.
      if (facilityAsync.valueOrNull?.isNotEmpty ?? false) {
        return const LoadingWidget();
      }
      // SingleChildScrollView prevents overflow when the sheet is short and
      // the EmptyWidget content (icon + text + optional TextButton) exceeds
      // the available Expanded height (e.g. with active filters at minChildSize).
      return SingleChildScrollView(
        child: EmptyWidget(
          icon: Icons.search_off,
          message: '施設が見つかりませんでした',
          action: hasActiveFilters
              ? TextButton(
                  onPressed: _clearFilters,
                  child: const Text('フィルターをクリア'),
                )
              : null,
        ),
      );
    }

    final showTrending = !hasActiveFilters && params.page == 0;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount:
            _accumulatedFacilities.length + (showTrending ? 2 : 1),
        itemBuilder: (context, i) {
          if (showTrending && i == 0) {
            return _ExploreTrendingSection(
              onFacilityTap: (facilityId) => Navigator.of(context)
                  .pushNamed('/facility', arguments: facilityId),
            );
          }
          final listIndex = showTrending ? i - 1 : i;
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
                      weeklyCheckinCount: _checkinCounts[facility.id],
                      onTap: () => Navigator.of(context)
                          .pushNamed('/facility', arguments: facility.id),
                    ),
                  ),
                  _ExploreFacilityPopupMenu(facility: facility),
                ],
              ),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }

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
}
