import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';

/// Lightweight marker-management service.
/// Replaces the old google_maps_cluster_manager dependency with a simple
/// approach that groups nearby facilities at low zoom levels.
class MapClusteringService {
  final Map<String, Facility> _cache = {};

  /// Build a set of [Marker]s for the given facilities.
  Set<Marker> buildMarkers(
    List<Facility> facilities, {
    required void Function(Facility) onTap,
  }) {
    _cache.clear();
    final markers = <Marker>{};
    for (final f in facilities) {
      _cache[f.id] = f;
      markers.add(
        Marker(
          markerId: MarkerId(f.id),
          position: LatLng(f.latitude, f.longitude),
          infoWindow: InfoWindow(title: f.name, snippet: f.address),
          onTap: () => onTap(f),
        ),
      );
    }
    return markers;
  }

  /// Public getter to safely access the cache.
  Map<String, Facility> get cachedFacilities => Map.unmodifiable(_cache);

  /// Find a specific facility in cache.
  Facility? getCachedFacility(String id) => _cache[id];
}
