import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/facility_provider.dart';

/// Horizontal chip bar for quick amenity filters.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  static const _amenityFilters = <String, String>{
    'sauna': 'サウナ',
    'outdoor_bath': '露天風呂',
    'tattoo_friendly': 'タトゥーOK',
    'natural_hot_spring': '天然温泉',
    'parking': '駐車場',
    'cold_plunge': '水風呂',
    'mixed_bath': '混浴',
    'lodging': '宿泊',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(facilitySearchProvider);
    final activeFilters = state.amenityFilters;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _amenityFilters.entries.map((entry) {
          final isActive = activeFilters[entry.key] == true;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(entry.value),
              selected: isActive,
              onSelected: (selected) {
                final newFilters = Map<String, bool>.from(activeFilters);
                if (selected) {
                  newFilters[entry.key] = true;
                } else {
                  newFilters.remove(entry.key);
                }
                ref.read(facilitySearchProvider.notifier).search(
                      query: state.searchQuery,
                      amenityFilters: newFilters,
                    );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
