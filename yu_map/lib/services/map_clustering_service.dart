import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';

class FacilityMarker with ClusterItem {
  final Facility facility;

  FacilityMarker(this.facility);

  @override
  LatLng get location => LatLng(facility.latitude, facility.longitude);
}

class MapClusteringService {
  late ClusterManager<FacilityMarker> _clusterManager;

  void initializeClusterManager({
    required Function(Set<Marker>) updateMarkers,
  }) {
    _clusterManager = ClusterManager<FacilityMarker>(
      [],
      updateMarkers,
      markerBuilder: _markerBuilder,
      levels: [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16, 16.5, 20],
      extraPercent: 0.2,
      stopClusteringZoom: 17.0,
    );
  }

  Future<Marker> _markerBuilder(Cluster<FacilityMarker> cluster) async {
    if (cluster.isMultiple) {
      return Marker(
        markerId: MarkerId(cluster.getId()),
        position: cluster.location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Placeholder for custom icon
        onTap: () {
          // Handle cluster tap
        },
      );
    } else {
      final facility = cluster.items.first.facility;
      return Marker(
        markerId: MarkerId(facility.id),
        position: cluster.location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Placeholder for custom icon
        onTap: () {
          // Handle facility tap
        },
      );
    }
  }

  void updateItems(List<Facility> facilities) {
    final items = facilities.map((f) => FacilityMarker(f)).toList();
    _clusterManager.setItems(items);
  }

  void onCameraMove(CameraPosition position) {
    _clusterManager.onCameraMove(position);
  }

  void updateMap() {
    _clusterManager.updateMap();
  }
}
