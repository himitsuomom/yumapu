import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:collection';
import 'package:yu_map/domain/entities/facility.dart';

class FacilityMarker with ClusterItem {
  final Facility facility;

  FacilityMarker(this.facility);

  @override
  LatLng get location => LatLng(facility.latitude, facility.longitude);
}

// Simple LRU Cache implementation for managing marker icons
class LRUCache<K, V> {
  final int capacity;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();

  LRUCache(this.capacity);

  V? get(K key) {
    if (_cache.containsKey(key)) {
      final value = _cache.remove(key)!;
      _cache[key] = value; // Re-add to move to end (most recent)
      return value;
    }
    return null;
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= capacity) {
      // Remove the first (least recently used) item
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  void clear() {
    _cache.clear();
  }

  int get size => _cache.length;
  bool get isEmpty => _cache.isEmpty;
  bool get isFull => _cache.length >= capacity;
}

class MapClusteringService {
  late ClusterManager<FacilityMarker> _clusterManager;
  final LRUCache<String, BitmapDescriptor> _iconCache = LRUCache<String, BitmapDescriptor>(100); // Max 100 cached icons

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
      
      // Try to get icon from cache first
      BitmapDescriptor icon;
      final iconKey = '${facility.id}_${facility.latitude}_${facility.longitude}';
      final cachedIcon = _iconCache.get(iconKey);
      
      if (cachedIcon != null) {
        icon = cachedIcon;
      } else {
        // Create new icon for this facility
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        // Cache the icon for future use
        _iconCache.put(iconKey, icon);
      }
      
      return Marker(
        markerId: MarkerId(facility.id),
        position: cluster.location,
        icon: icon,
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
}
