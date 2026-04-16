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
    /// facilityTypeId を null にリセットしたい場合は true を渡す
    bool clearFacilityType = false,
  }) {
    return FacilitySearchParams(
      searchQuery: clearText ? null : searchQuery ?? this.searchQuery,
      prefectureId: prefectureId ?? this.prefectureId,
      // clearFacilityType=true なら null、それ以外は渡した値 or 既存値
      facilityTypeId:
          clearFacilityType ? null : facilityTypeId ?? this.facilityTypeId,
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

// ── Facility amenities ────────────────────────────────────────────────────────

/// 施設のアメニティ一覧を取得する。
/// facility_amenities テーブルと amenities テーブルを JOIN して
/// 「この施設にある設備・泉質」のリストを返す。
class FacilityAmenity {
  final String code;
  final String nameJa;
  final String category;

  const FacilityAmenity({
    required this.code,
    required this.nameJa,
    required this.category,
  });

  factory FacilityAmenity.fromJson(Map<String, dynamic> json) {
    final amenity = json['amenities'] as Map<String, dynamic>? ?? json;
    return FacilityAmenity(
      code: amenity['code'] as String? ?? '',
      nameJa: amenity['name_ja'] as String? ?? '',
      category: amenity['category'] as String? ?? '',
    );
  }
}

final facilityAmenitiesProvider =
    FutureProvider.autoDispose.family<List<FacilityAmenity>, String>(
        (ref, facilityId) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return [];
  try {
    final rows = await client
        .from('facility_amenities')
        .select('amenities(code, name_ja, category)')
        .eq('facility_id', facilityId)
        .eq('value', 'true') as List;
    return rows
        .map((r) => FacilityAmenity.fromJson(r as Map<String, dynamic>))
        .where((a) => a.nameJa.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
});
