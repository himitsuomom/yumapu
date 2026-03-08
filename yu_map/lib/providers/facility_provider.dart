import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/services/facility_service.dart';

/// Facility service singleton.
/// Throws if Supabase is not configured.
final facilityServiceProvider = Provider<FacilityService>((ref) {
  final client = ref.read(supabaseClientProvider);
  if (client == null) {
    throw StateError('Supabase is not configured.');
  }
  return FacilityService(client);
});

/// Search state for facilities.
class FacilitySearchState {
  final List<Facility> facilities;
  final bool isLoading;
  final String? error;
  final String? searchQuery;
  final String? prefectureId;
  final String? facilityTypeId;
  final Map<String, bool> amenityFilters;

  const FacilitySearchState({
    this.facilities = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery,
    this.prefectureId,
    this.facilityTypeId,
    this.amenityFilters = const {},
  });

  FacilitySearchState copyWith({
    List<Facility>? facilities,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? prefectureId,
    String? facilityTypeId,
    Map<String, bool>? amenityFilters,
  }) {
    return FacilitySearchState(
      facilities: facilities ?? this.facilities,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      prefectureId: prefectureId ?? this.prefectureId,
      facilityTypeId: facilityTypeId ?? this.facilityTypeId,
      amenityFilters: amenityFilters ?? this.amenityFilters,
    );
  }
}

class FacilitySearchNotifier extends StateNotifier<FacilitySearchState> {
  FacilitySearchNotifier(this._service) : super(const FacilitySearchState());
  final FacilityService _service;

  Future<void> search({
    String? query,
    String? prefectureId,
    String? facilityTypeId,
    Map<String, bool>? amenityFilters,
  }) async {
    state = state.copyWith(
      isLoading: true,
      searchQuery: query,
      prefectureId: prefectureId,
      facilityTypeId: facilityTypeId,
      amenityFilters: amenityFilters,
    );
    try {
      final results = await _service.searchFacilities(
        searchQuery: query,
        prefectureId: prefectureId,
        facilityTypeId: facilityTypeId,
        attributes: amenityFilters,
      );
      state = state.copyWith(facilities: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await _service.searchFacilities();
      state = state.copyWith(facilities: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearFilters() {
    state = const FacilitySearchState();
  }
}

final facilitySearchProvider =
    StateNotifierProvider<FacilitySearchNotifier, FacilitySearchState>((ref) {
  return FacilitySearchNotifier(ref.read(facilityServiceProvider));
});

/// Single facility detail.
final facilityDetailProvider =
    FutureProvider.family<Facility?, String>((ref, id) async {
  final service = ref.read(facilityServiceProvider);
  return service.getFacilityById(id);
});
