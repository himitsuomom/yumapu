import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/favorites_provider.dart';

/// List tile for a [Facility] with an inline favorite toggle button.
///
/// Reads favorite state from [isFavoriteProvider] and dispatches
/// optimistic toggles through [favoritesProvider].
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
          if (facility.hasFacilityType)
            Text(
              facility.facilityTypeJa,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF1565C0),
                  ),
            ),
          if (facility.address != null)
            Text(
              facility.address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
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
      isThreeLine: facility.hasFacilityType && facility.address != null,
    );
  }
}

// ── Facility type icon ────────────────────────────────────────────────────────

class _FacilityTypeIcon extends StatelessWidget {
  const _FacilityTypeIcon({this.facilityType});

  final String? facilityType;

  @override
  Widget build(BuildContext context) {
    final iconData = switch (facilityType?.toLowerCase()) {
      'onsen' || '温泉施設' || '温泉' => Icons.hot_tub,
      'sauna' || 'サウナ' => Icons.local_fire_department,
      'public_bath' || 'sento' || '銭湯・公衆浴場' || '銭湯' => Icons.bathtub_outlined,
      _ => Icons.water_drop_outlined,
    };

    return CircleAvatar(
      backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
      child: Icon(iconData, color: const Color(0xFF1565C0), size: 20),
    );
  }
}
