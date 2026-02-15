// lib/presentation/widgets/amenity_filter_chips.dart
import 'package:flutter/material.dart';

/// Horizontal list of amenity filter chips for the map screen.
class AmenityFilterChips extends StatelessWidget {
  final Map<String, bool> selected;
  final ValueChanged<Map<String, bool>> onChanged;

  const AmenityFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _amenities = <String, String>{
    'sauna': 'サウナ',
    'tattoo_friendly': 'タトゥーOK',
    'outdoor_bath': '露天風呂',
    'cold_plunge': '水風呂',
    'natural_hot_spring': '天然温泉',
    'parking': '駐車場',
    'lodging': '宿泊可',
    'mixed_bath': '混浴',
    'stone_sauna': '岩盤浴',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _amenities.entries.map((entry) {
          final isSelected = selected[entry.key] == true;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (value) {
                final newMap = Map<String, bool>.from(selected);
                if (value) {
                  newMap[entry.key] = true;
                } else {
                  newMap.remove(entry.key);
                }
                onChanged(newMap);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
