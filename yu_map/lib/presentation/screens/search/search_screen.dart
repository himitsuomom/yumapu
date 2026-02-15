// lib/presentation/screens/search/search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/facility_providers.dart';
import 'package:yu_map/presentation/widgets/amenity_filter_chips.dart';
import 'package:yu_map/presentation/widgets/facility_list_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  Map<String, bool> _amenityFilters = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    ref.read(facilitySearchParamsProvider.notifier).state =
        FacilitySearchParams(
      query: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      amenities: _amenityFilters.isEmpty ? null : _amenityFilters,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(facilitySearchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('施設検索'),
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '施設名で検索...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch();
                  },
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),

          // ── Amenity filters ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: AmenityFilterChips(
              selected: _amenityFilters,
              onChanged: (filters) {
                setState(() => _amenityFilters = filters);
                _performSearch();
              },
            ),
          ),

          const Divider(),

          // ── Results ──
          Expanded(
            child: resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
              data: (facilities) {
                if (facilities.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '施設が見つかりません',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'キーワードやフィルタを変更してください',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: facilities.length,
                  itemBuilder: (context, index) {
                    return FacilityListTile(
                      facility: facilities[index],
                      onTap: () =>
                          context.push('/facility/${facilities[index].id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
