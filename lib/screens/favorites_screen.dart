import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/app_state.dart';

/// FavoritesScreen - Displays user's favorite facilities
class FavoritesScreen extends StatelessWidget {
  final Function(Facility) onFacilitySelected;

  const FavoritesScreen({
    super.key,
    required this.onFacilitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お気に入り'),
        elevation: 0,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final favorites = appState.favoriteFacilities;

          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'お気に入りの施設がありません',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '気になる施設をお気に入りに追加しましょう',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final facility = favorites[index];
              return _buildFacilityCard(context, facility, onFacilitySelected);
            },
          );
        },
      ),
    );
  }

  Widget _buildFacilityCard(
    BuildContext context,
    Facility facility,
    Function(Facility) onSelect,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => onSelect(facility),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 施設タイプ別のカラープレースホルダー
            // （Facilityモデルに画像URLフィールドがないためアイコン表示）
            Expanded(
              flex: 3,
              child: Container(
                color: _facilityTypeColor(facility.type).withValues(alpha: 0.15),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _facilityTypeIcon(facility.type),
                        size: 40,
                        color: _facilityTypeColor(facility.type),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _facilityTypeLabel(facility.type),
                        style: TextStyle(
                          fontSize: 11,
                          color: _facilityTypeColor(facility.type),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          facility.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          facility.type,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${facility.rating}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${facility.reviewCount})',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 施設タイプ別のアイコン
  IconData _facilityTypeIcon(String type) {
    switch (type) {
      case 'sauna':
        return Icons.local_fire_department;
      case 'onsen':
        return Icons.hot_tub;
      case 'supersento':
        return Icons.pool;
      case 'public_bath':
        return Icons.bathtub;
      default:
        return Icons.spa;
    }
  }

  /// 施設タイプ別のカラー
  Color _facilityTypeColor(String type) {
    switch (type) {
      case 'sauna':
        return Colors.deepOrange;
      case 'onsen':
        return Colors.blue;
      case 'supersento':
        return Colors.teal;
      case 'public_bath':
        return Colors.indigo;
      default:
        return Colors.orange;
    }
  }

  /// 施設タイプ別のラベル
  String _facilityTypeLabel(String type) {
    switch (type) {
      case 'sauna':
        return 'サウナ';
      case 'onsen':
        return '温泉';
      case 'supersento':
        return 'スーパー銭湯';
      case 'public_bath':
        return '銭湯';
      default:
        return type;
    }
  }
}
