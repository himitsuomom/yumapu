import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'dart:collection';
import 'dart:ui' as ui;

class FacilityMarker with ClusterItem {
  final Facility facility;

  FacilityMarker(this.facility);

  @override
  LatLng get location => LatLng(facility.latitude, facility.longitude);
}

// Simple LRU cache implementation for icons to prevent unbounded memory growth
class LRUCache<K, V> {
  final int capacity;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();

  LRUCache(this.capacity);

  V? get(K key) {
    if (_cache.containsKey(key)) {
      // Move accessed item to end (most recently used)
      final value = _cache.remove(key)!;
      _cache[key] = value;
      return value;
    }
    return null;
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      // Update existing key
      _cache.remove(key);
    } else if (_cache.length >= capacity) {
      // Remove oldest item if at capacity
      if (_cache.isNotEmpty) {
        _cache.remove(_cache.keys.first);
      }
    }
    // Add new item
    _cache[key] = value;
  }

  void clear() {
    _cache.clear();
  }
}

class MapClusteringService {
  late ClusterManager<FacilityMarker> _clusterManager;
  
  // Implement LRU cache for icons to prevent unbounded memory growth
  final LRUCache<String, BitmapDescriptor> _iconCache = LRUCache(100); // Max 100 cached icons

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
      final iconKey = 'facility_${facility.id}';
      
      final cachedIcon = _iconCache.get(iconKey);
      if (cachedIcon != null) {
        icon = cachedIcon;
      } else {
        // Create new icon (this is a simplified version - in practice you'd customize based on facility type)
        icon = await _createCustomIcon(facility);
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

  // Helper method to create custom icons
  Future<BitmapDescriptor> _createCustomIcon(Facility facility) async {
    // In a real implementation, you would create custom icons based on facility properties
    // Here we're simplifying with standard hue colors
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  void updateItems(List<Facility> facilities) {
    final items = facilities.map((f) => FacilityMarker(f)).toList();
    _clusterManager.setItems(items);
  }
  
  // Method to clear the icon cache when needed
  void clearIconCache() {
    _iconCache.clear();
  }
  
  // Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'current_size': _iconCache._cache.length,
      'capacity': _iconCache.capacity,
    };
  }
}
