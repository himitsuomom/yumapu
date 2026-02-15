// lib/presentation/widgets/facility_list_tile.dart
import 'package:flutter/material.dart';
import 'package:yu_map/domain/entities/facility.dart';

/// A list tile for displaying a facility in search results.
class FacilityListTile extends StatelessWidget {
  final Facility facility;
  final VoidCallback? onTap;

  const FacilityListTile({
    super.key,
    required this.facility,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.hot_tub),
        ),
        title: Text(
          facility.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (facility.address != null)
              Text(
                facility.address!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                // Quality indicator
                ...List.generate(
                  5,
                  (i) => Icon(
                    Icons.star,
                    size: 12,
                    color: i < facility.dataQualityScore
                        ? Colors.amber
                        : Colors.grey.shade300,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  facility.dataSource,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
