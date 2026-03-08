import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/widgets/empty_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/features/facility/screens/facility_detail_screen.dart';
import 'package:yu_map/features/search/widgets/facility_list_tile.dart';
import 'package:yu_map/features/search/widgets/filter_bar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(facilitySearchProvider.notifier).loadAll());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    ref.read(facilitySearchProvider.notifier).search(
          query: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
        );
  }

  void _openDetail(Facility facility) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FacilityDetailScreen(facilityId: facility.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(facilitySearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('施設を検索'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '施設名で検索...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(facilitySearchProvider.notifier)
                              .clearFilters();
                          ref
                              .read(facilitySearchProvider.notifier)
                              .loadAll();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _performSearch(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),

          // Filter chips
          const FilterBar(),

          // Results
          Expanded(
            child: _buildResults(searchState),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(FacilitySearchState state) {
    if (state.isLoading) {
      return const ShimmerList();
    }
    if (state.error != null) {
      return AppErrorWidget(
        message: 'データの取得に失敗しました',
        onRetry: () => ref.read(facilitySearchProvider.notifier).loadAll(),
      );
    }
    if (state.facilities.isEmpty) {
      return const EmptyWidget(
        message: '施設が見つかりませんでした',
        icon: Icons.hot_tub_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.facilities.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final facility = state.facilities[i];
        return FacilityListTile(
          facility: facility,
          onTap: () => _openDetail(facility),
        );
      },
    );
  }
}
