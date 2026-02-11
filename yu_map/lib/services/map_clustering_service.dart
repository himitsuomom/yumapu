import 'dart:async';
import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:flutter/material.dart';

class FacilityMarker with ClusterItem {
  final Facility facility;

  FacilityMarker(this.facility);

  @override
  LatLng get location => LatLng(facility.latitude, facility.longitude);
}

class MapClusteringService {
  ClusterManager<FacilityMarker>? _clusterManager;
  Function(Set<Marker>)? _updateMarkersCallback;

  // Cache for custom marker icons to avoid recreating them repeatedly
  Map<int, BitmapDescriptor> _iconCache = {};

  void initializeClusterManager({
    required Function(Set<Marker>) updateMarkers,
  }) {
    _updateMarkersCallback = updateMarkers;
    
    _clusterManager = ClusterManager<FacilityMarker>(
      [],
      _updateMarkersCallback!,
      markerBuilder: _markerBuilder,
      levels: [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16, 16.5, 20],
      extraPercent: 0.2,
      stopClusteringZoom: 17.0,
    );
  }

  Future<Marker> _markerBuilder(Cluster<FacilityMarker> cluster) async {
    String markerId;
    LatLng position;
    BitmapDescriptor icon;
    VoidCallback? onTap;

    if (cluster.isMultiple) {
      // Cluster marker with number of facilities
      markerId = cluster.getId();
      position = cluster.location;
      
      // Create a custom cluster marker with the number of facilities
      icon = await _getClusterBitmapDescriptor(cluster.count);
      
      // Handle cluster tap - maybe zoom in or show info window
      onTap = () {
        // Could implement logic to zoom to show all facilities in cluster
        print('Cluster tapped with ${cluster.count} facilities');
      };
    } else {
      // Individual facility marker
      final facility = cluster.items.first.facility;
      markerId = facility.id;
      position = cluster.location;
      
      // Different icons based on facility type
      icon = await _getFacilityTypeIcon(facility);
      
      onTap = () {
        // Handle facility tap - navigate to detail page
        print('Facility ${facility.name} tapped');
      };
    }

    return Marker(
      markerId: MarkerId(markerId),
      position: position,
      icon: icon,
      onTap: onTap,
    );
  }

  // Create custom bitmap descriptor for clusters
  Future<BitmapDescriptor> _getClusterBitmapDescriptor(int count) async {
    if (_iconCache.containsKey(count)) {
      return _iconCache[count]!;
    }

    // In a real implementation, we would create a custom marker with canvas drawing
    // For now, we'll use hue variations based on count
    double hue = count > 5 ? BitmapDescriptor.hueRed :
                 count > 2 ? BitmapDescriptor.hueOrange :
                 BitmapDescriptor.hueGreen;

    BitmapDescriptor descriptor = await BitmapDescriptor.defaultMarkerWithHue(hue);
    _iconCache[count] = descriptor;
    
    return descriptor;
  }

  // Return different icons based on facility type
  Future<BitmapDescriptor> _getFacilityTypeIcon(Facility facility) async {
    // In a real implementation, we could load different icons based on facility type
    // For now, use different hues based on data quality
    double hue = facility.dataQualityScore >= 4 ? BitmapDescriptor.hueGreen :
                 facility.dataQualityScore >= 2 ? BitmapDescriptor.hueYellow :
                 BitmapDescriptor.hueRed;

    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  void updateItems(List<Facility> facilities) {
    if (_clusterManager != null) {
      final items = facilities.map((f) => FacilityMarker(f)).toList();
      _clusterManager!.setItems(items);
    }
  }

  void setViewport(LatLngBounds bounds) {
    _clusterManager?.setBounds(bounds);
  }

  void dispose() {
    _clusterManager?.dispose();
    _iconCache.clear();
  }
}
