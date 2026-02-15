// lib/providers/facility_providers.dart
//
// Facility-related state providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/service_providers.dart';

/// Search parameters for facilities.
class FacilitySearchParams {
  final String? query;
  final String? prefectureId;
  final String? facilityTypeId;
  final Map<String, bool>? amenities;
  final double? latitude;
  final double? longitude;
  final double? radius;

  const FacilitySearchParams({
    this.query,
    this.prefectureId,
    this.facilityTypeId,
    this.amenities,
    this.latitude,
    this.longitude,
    this.radius,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FacilitySearchParams &&
          query == other.query &&
          prefectureId == other.prefectureId &&
          facilityTypeId == other.facilityTypeId &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          radius == other.radius;

  @override
  int get hashCode => Object.hash(
        query,
        prefectureId,
        facilityTypeId,
        latitude,
        longitude,
        radius,
      );
}

/// Current search parameters – mutable.
final facilitySearchParamsProvider =
    StateProvider<FacilitySearchParams>((ref) => const FacilitySearchParams());

/// Facility search results, auto-refreshed when params change.
final facilitySearchResultsProvider =
    FutureProvider<List<Facility>>((ref) async {
  final params = ref.watch(facilitySearchParamsProvider);
  final facilityService = ref.watch(facilityServiceProvider);

  return facilityService.searchFacilities(
    searchQuery: params.query,
    prefectureId: params.prefectureId,
    facilityTypeId: params.facilityTypeId,
    attributes: params.amenities,
    latitude: params.latitude,
    longitude: params.longitude,
    radius: params.radius,
  );
});

/// Single facility detail provider, keyed by ID.
final facilityDetailProvider =
    FutureProvider.family<Facility?, String>((ref, facilityId) async {
  final facilityService = ref.watch(facilityServiceProvider);
  return facilityService.getFacilityById(facilityId);
});

/// Notifier for the facilities visible on the map viewport.
class MapFacilitiesNotifier extends StateNotifier<AsyncValue<List<Facility>>> {
  final Ref _ref;

  MapFacilitiesNotifier(this._ref) : super(const AsyncValue.data([]));

  /// Load facilities within the given bounding box.
  Future<void> loadInBounds({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    Map<String, bool>? amenities,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = _ref.read(facilityServiceProvider);
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      final radius = (maxLat - minLat) * 111.0 / 2; // rough km

      return service.searchFacilities(
        latitude: centerLat,
        longitude: centerLng,
        radius: radius,
        attributes: amenities,
      );
    });
  }
}

final mapFacilitiesProvider =
    StateNotifierProvider<MapFacilitiesNotifier, AsyncValue<List<Facility>>>(
  (ref) => MapFacilitiesNotifier(ref),
);
