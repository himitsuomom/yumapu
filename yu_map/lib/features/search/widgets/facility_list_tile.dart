import 'package:flutter/material.dart';
import 'package:yu_map/domain/entities/facility.dart';

class FacilityListTile extends StatelessWidget {
  const FacilityListTile({
    super.key,
    required this.facility,
    required this.onTap,
  });
  final Facility facility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.hot_tub),
      ),
      title: Text(
        facility.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: facility.address != null
          ? Text(
              facility.address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600),
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
