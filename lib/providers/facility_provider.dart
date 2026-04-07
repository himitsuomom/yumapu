import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/services/facility_service.dart';

// ── Service provider ────────────────────────────────────────────────────────

final facilityServiceProvider = Provider<FacilityService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return FacilityService(client);
});

// ── Search parameters ────────────────────────────────────────────────────────

class FacilitySearchParams {
  final String? searchQuery;
  final String? prefectureId;
  final String? facilityTypeId;
  final List<String> amenityIds;
  final double? latitude;
  final double? longitude;
  final double? radiusMeters;
  final int page;

  const FacilitySearchParams({
    this.searchQuery,
    this.prefectureId,
    this.facilityTypeId,
    this.amenityIds = const [],
    this.latitude,
    this.longitude,
    this.radiusMeters,
    this.page = 0,
  });

  FacilitySearchParams copyWith({
    String? searchQuery,
    String? prefectureId,
    String? facilityTypeId,
    List<String>? amenityIds,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    int? page,
    bool clearGeo = false,
    bool clearText = false,
  }) {
    return FacilitySearchParams(
      searchQuery: clearText ? null : searchQuery ?? this.searchQuery,
      prefectureId: prefectureId ?? this.prefectureId,
      facilityTypeId: facilityTypeId ?? this.facilityTypeId,
      amenityIds: amenityIds ?? this.amenityIds,
      latitude: clearGeo ? null : latitude ?? this.latitude,
      longitude: clearGeo ? null : longitude ?? this.longitude,
      radiusMeters: clearGeo ? null : radiusMeters ?? this.radiusMeters,
      page: page ?? this.page,
    );
  }
}

final facilitySearchParamsProvider =
    StateProvider<FacilitySearchParams>((ref) => const FacilitySearchParams());

// ── Facility list ────────────────────────────────────────────────────────────

final facilityListProvider =
    FutureProvider.autoDispose<List<Facility>>((ref) async {
  final service = ref.watch(facilityServiceProvider);
  if (service == null) return [];
  final params = ref.watch(facilitySearchParamsProvider);
  return service.searchFacilities(
    searchQuery: params.searchQuery,
    prefectureId: params.prefectureId,
    facilityTypeId: params.facilityTypeId,
    amenityIds: params.amenityIds.isEmpty ? null : params.amenityIds,
    latitude: params.latitude,
    longitude: params.longitude,
    radiusMeters: params.radiusMeters,
    page: params.page,
  );
});

// ── Facility detail ──────────────────────────────────────────────────────────

final facilityDetailProvider =
    FutureProvider.autoDispose.family<Facility?, String>((ref, id) async {
  final service = ref.watch(facilityServiceProvider);
  if (service == null) return null;
  return service.getFacilityById(id);
});
