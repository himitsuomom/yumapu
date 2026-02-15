// lib/services/map_clustering_service.dart
import 'package:flutter/foundation.dart';
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
  ClusterManager<FacilityMarker>? _clusterManager;

  /// Callback invoked when a single facility marker is tapped.
  void Function(String facilityId)? onFacilityTap;

  /// LRU-style cache for facilities displayed on the map.
  final Map<String, Facility> _cache = {};

  /// Whether the cluster manager has been initialized.
  bool get isInitialized => _clusterManager != null;

  void initializeClusterManager({
    required Function(Set<Marker>) updateMarkers,
    void Function(String facilityId)? onFacilityTap,
  }) {
    this.onFacilityTap = onFacilityTap;
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
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: '${cluster.count} facilities',
        ),
      );
    } else {
      final facility = cluster.items.first.facility;
      return Marker(
        markerId: MarkerId(facility.id),
        position: cluster.location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: facility.name),
        onTap: () {
          onFacilityTap?.call(facility.id);
        },
      );
    }
  }

  /// Updates the map items. Throws [StateError] if not initialized.
  void updateItems(List<Facility> facilities) {
    if (_clusterManager == null) {
      debugPrint(
        'MapClusteringService.updateItems called before initializeClusterManager(). '
        'Call initializeClusterManager() first.',
      );
      return;
    }

    final items = facilities.map((f) => FacilityMarker(f)).toList();
    _clusterManager!.setItems(items);

    // Update the cache with the new facilities
    _cache.clear();
    for (final facility in facilities) {
      _cache[facility.id] = facility;
    }
  }

  /// Returns an unmodifiable view of the cached facilities.
  Map<String, Facility> get cachedFacilities => Map.unmodifiable(_cache);

  /// Finds a specific facility in the cache by ID.
  Facility? getCachedFacility(String id) {
    return _cache[id];
  }

  /// Disposes the cluster manager and clears the cache.
  void dispose() {
    _clusterManager = null;
    _cache.clear();
  }
}
