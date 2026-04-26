import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/location_provider.dart';

/// 施設一覧の1行ウィジェット。
///
/// お気に入りのトグルボタンと、現在地が取得できている場合は距離を表示する。
class FacilityListTile extends ConsumerWidget {
  const FacilityListTile({
    super.key,
    required this.facility,
    this.onTap,
  });

  final Facility facility;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(facility.id));

    // 現在地プロバイダーから緯度経度を取得して距離を計算する。
    // MapScreen が Geolocator で現在地を取得してから利用可能になる。
    final location = ref.watch(currentLocationProvider);
    final distKm = computeDistanceKm(
      lat1: location?.lat,
      lon1: location?.lng,
      lat2: facility.latitude,
      lon2: facility.longitude,
    );

    return ListTile(
      onTap: onTap,
      leading: _FacilityTypeIcon(facilityType: facility.facilityType),
      title: Text(
        facility.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 施設タイプ（例: 温泉施設、銭湯・公衆浴場）
          if (facility.hasFacilityType)
            Text(
              facility.facilityTypeJa,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF1565C0),
                  ),
            ),
          // 住所 + 距離（同じ行に並べる）
          if (facility.address != null || distKm != null)
            Row(
              children: [
                if (facility.address != null)
                  Expanded(
                    child: Text(
                      facility.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (distKm != null) ...[
                  if (facility.address != null) const SizedBox(width: 6),
                  Text(
                    formatDistanceKm(distKm),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ],
            ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? Colors.red : null,
        ),
        onPressed: () =>
            ref.read(favoritesProvider.notifier).toggle(facility.id),
      ),
      isThreeLine:
          facility.hasFacilityType &&
          (facility.address != null || distKm != null),
    );
  }
}

// ── 施設タイプアイコン ────────────────────────────────────────────────────────

class _FacilityTypeIcon extends StatelessWidget {
  const _FacilityTypeIcon({this.facilityType});

  final String? facilityType;

  @override
  Widget build(BuildContext context) {
    final iconData = switch (facilityType?.toLowerCase()) {
      'onsen' || '温泉施設' || '温泉' => Icons.hot_tub,
      'sauna' || 'サウナ' => Icons.local_fire_department,
      'public_bath' || 'sento' || '銭湯・公衆浴場' || '銭湯' =>
        Icons.bathtub_outlined,
      _ => Icons.water_drop_outlined,
    };

    return CircleAvatar(
      backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
      child: Icon(iconData, color: const Color(0xFF1565C0), size: 20),
    );
  }
}
