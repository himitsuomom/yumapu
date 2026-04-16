import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/widgets/empty_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/features/search/widgets/facility_list_tile.dart';
import 'package:yu_map/features/search/widgets/filter_bar.dart';
import 'package:yu_map/providers/facility_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filter helpers ────────────────────────────────────────────────────────

  void _onSearchSubmitted(String query) {
    ref.read(facilitySearchParamsProvider.notifier).update(
          (p) => p.copyWith(
            searchQuery: query.trim().isEmpty ? null : query.trim(),
            page: 0,
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

  void _clearFilters() {
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
        params.amenityIds.isNotEmpty;

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
              onSubmitted: _onSearchSubmitted,
              decoration: InputDecoration(
                hintText: '施設名で検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: params.searchQuery != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
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
