part of 'plan_detail_screen.dart';

// ── プラン地図セクション ──────────────────────────────────────────────────────

class _PlanMapSection extends StatelessWidget {
  const _PlanMapSection({
    required this.facilities,
    required this.expanded,
    required this.onToggle,
  });

  final List<Facility> facilities;
  final bool expanded;
  final VoidCallback onToggle;

  Future<void> _openGoogleMaps(BuildContext context) async {
    if (facilities.isEmpty) return;
    final Uri uri;
    if (facilities.length == 1) {
      final f = facilities.first;
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${f.latitude},${f.longitude}'
        '&travelmode=driving',
      );
    } else {
      final origin = facilities.first;
      final dest = facilities.last;
      final waypoints = facilities.length > 2
          ? facilities
              .sublist(1, facilities.length - 1)
              .map((f) => '${f.latitude},${f.longitude}')
              .join('|')
          : null;
      final waypointParam =
          waypoints != null ? '&waypoints=$waypoints' : '';
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${origin.latitude},${origin.longitude}'
        '&destination=${dest.latitude},${dest.longitude}'
        '$waypointParam'
        '&travelmode=driving',
      );
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('マップアプリを開けませんでした')),
        );
      }
    }
  }

  ({ll.LatLng center, double zoom}) _computeBounds() {
    if (facilities.isEmpty) {
      return (center: ll.LatLng(35.6812, 139.7671), zoom: 10.0);
    }
    if (facilities.length == 1) {
      return (
        center: ll.LatLng(facilities[0].latitude, facilities[0].longitude),
        zoom: 13.0,
      );
    }

    final lats = facilities.map((f) => f.latitude).toList()..sort();
    final lngs = facilities.map((f) => f.longitude).toList()..sort();
    final minLat = lats.first;
    final maxLat = lats.last;
    final minLng = lngs.first;
    final maxLng = lngs.last;

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;

    double zoom;
    if (maxSpan < 0.01) {
      zoom = 14.0;
    } else if (maxSpan < 0.05) {
      zoom = 13.0;
    } else if (maxSpan < 0.2) {
      zoom = 11.0;
    } else if (maxSpan < 1.0) {
      zoom = 9.0;
    } else {
      zoom = 7.0;
    }

    return (center: ll.LatLng(centerLat, centerLng), zoom: zoom);
  }

  static Color _colorForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'onsen':
        return const Color(0xFFE53935);
      case 'public_bath':
        return const Color(0xFF1976D2);
      case 'sauna':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF7B1FA2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'ルートマップ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _openGoogleMaps(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ナビ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: expanded ? 200.0 : 0.0,
          child: expanded ? _buildMap() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMap() {
    final bounds = _computeBounds();
    return FlutterMap(
      options: MapOptions(
        initialCenter: bounds.center,
        initialZoom: bounds.zoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.yumap.app',
        ),
        MarkerLayer(
          markers: facilities.asMap().entries.map((entry) {
            final index = entry.key;
            final facility = entry.value;
            final color = _colorForType(facility.facilityType);
            return Marker(
              point: ll.LatLng(facility.latitude, facility.longitude),
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.location_pin, color: color, size: 36),
                  Positioned(
                    top: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: color,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── 施設リストアイテム（ドラッグハンドル＋削除ボタン付き）──────────────────────

class _FacilityReorderItem extends StatelessWidget {
  const _FacilityReorderItem({
    super.key,
    required this.facility,
    required this.index,
    required this.isUpdating,
    required this.onDelete,
    required this.onTap,
  });

  final Facility facility;
  final int index;
  final bool isUpdating;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Icon(
              Icons.drag_handle,
              color: isUpdating ? Colors.grey[300] : Colors.grey[500],
            ),
          ),
        ),
        Expanded(
          child: FacilityListTile(
            facility: facility,
            onTap: isUpdating ? null : onTap,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: isUpdating ? Colors.grey[300] : Colors.red[300],
          ),
          tooltip: '施設を削除',
          onPressed: isUpdating ? null : onDelete,
        ),
      ],
    );
  }
}
