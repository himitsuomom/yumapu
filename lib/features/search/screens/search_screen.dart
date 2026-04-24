import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/widgets/empty_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
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

  @override
  void initState() {
    super.initState();
    // Bug-3修正: 地図画面など他の場所でsearchQueryが設定されている場合に
    // テキストフィールドをプロバイダーの値と同期する。
    // これにより「絞り込まれているのにテキストが空」という混乱を防ぐ。
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

  // ── Filter helpers ────────────────────────────────────────────────────────

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
                hintText: '施設名で検索',
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
          // ── Sort chips（UX-V9-4対応）────────────────────────────────────
          // 検索結果の並び順を「品質順」「名前順」から選べる。
          // ChoiceChip = ラジオボタンのような択一選択UI。
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
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
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Result list ──────────────────────────────────────────────────
          Expanded(
            child: facilityAsync.when(
              data: (facilities) {
                if (facilities.isEmpty) {
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
                return ListView.separated(
                  itemCount: facilities.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final facility = facilities[i];
                    return FacilityListTile(
                      facility: facility,
                      onTap: () => Navigator.of(context).pushNamed(
                        '/facility',
                        arguments: facility.id,
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => AppErrorWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(facilityListProvider),
              ),
            ),
          ),
        ],
      ),
    );
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
