// lib/features/facility/widgets/facility_amenity_section.dart
//
// 施設詳細：設備・泉質セクション
// facility_amenities テーブルのデータをカテゴリ別にチップ表示する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/facility_provider.dart';

/// 施設詳細のアメニティ（設備・泉質）セクション。
/// facility_amenities テーブルのデータを Wrap で表示する。
class FacilityAmenitySection extends ConsumerWidget {
  const FacilityAmenitySection({super.key, required this.facilityId});

  final String facilityId;

  // カテゴリごとのアイコン定義
  IconData _iconForCategory(String category) {
    switch (category) {
      case 'spring_type':
        return Icons.water;
      case 'bath':
        return Icons.hot_tub;
      case 'sauna':
        return Icons.local_fire_department_outlined;
      case 'facility':
        return Icons.local_parking;
      case 'policy':
        return Icons.info_outline;
      case 'water':
        return Icons.hot_tub;
      default:
        return Icons.check_circle_outline;
    }
  }

  Color _colorForCategory(String category, BuildContext context) {
    switch (category) {
      case 'spring_type':
        return Theme.of(context).colorScheme.primary;
      case 'bath':
        return const Color(0xFF0277BD);
      case 'sauna':
        return const Color(0xFFE65100);
      case 'water':
        return const Color(0xFF1565C0);
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amenitiesAsync = ref.watch(facilityAmenitiesProvider(facilityId));

    return amenitiesAsync.when(
      data: (amenities) {
        if (amenities.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '設備・泉質',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: amenities.map((a) {
                  final color = _colorForCategory(a.category, context);
                  return Chip(
                    avatar: Icon(
                      _iconForCategory(a.category),
                      size: 16,
                      color: color,
                    ),
                    label: Text(
                      a.nameJa,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                    backgroundColor: color.withAlpha(26),
                    side: BorderSide(color: color.withAlpha(77)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
