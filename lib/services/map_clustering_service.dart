import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';

/// Builds Google Maps [Marker]s from a list of [Facility] objects and
/// maintains a private cache for fast facility lookup by ID.
///
/// The internal cache is never exposed directly — external code must use
/// [cachedFacilities] (unmodifiable view) or [getCachedFacility].
class MapClusteringService {
  final Map<String, Facility> _cache = {};

  /// Unmodifiable view of all facilities currently held in the cache.
  Map<String, Facility> get cachedFacilities => Map.unmodifiable(_cache);

  /// Look up a single facility from the cache. Returns null if not found.
  Facility? getCachedFacility(String id) => _cache[id];

  /// Build a [Set] of [Marker]s for [facilities], replacing the cache.
  ///
  /// [onTap] is called with the tapped [Facility] when a marker is tapped.
  /// Facilities with invalid coordinates ([Facility.hasValidLocation] == false)
  /// are silently skipped.
  Set<Marker> buildMarkers(
    List<Facility> facilities, {
    required void Function(Facility) onTap,
  }) {
    _cache.clear();
    final markers = <Marker>{};

    for (final facility in facilities) {
      if (!facility.hasValidLocation) continue;

      _cache[facility.id] = facility;
      markers.add(
        Marker(
          markerId: MarkerId(facility.id),
          position: LatLng(facility.latitude, facility.longitude),
          infoWindow: InfoWindow(
            title: facility.name,
            snippet: facility.address,
          ),
          onTap: () => onTap(facility),
        ),
      );
    }

    return markers;
  }
}
