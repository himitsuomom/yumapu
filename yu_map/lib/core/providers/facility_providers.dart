import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/data/repositories/facility_repository_impl.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/domain/repositories/facility_repository.dart';

// Provider for Supabase Client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Provider for FacilityRepository
final facilityRepositoryProvider = Provider<FacilityRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return FacilityRepositoryImpl(supabase);
});

// State provider for current map bounds
final mapBoundsProvider = StateProvider<LatLngBounds?>((ref) => null);

// Provider to fetch facilities based on bounds
final facilitiesInBoundsProvider = FutureProvider<List<Facility>>((ref) async {
  final bounds = ref.watch(mapBoundsProvider);
  if (bounds == null) return [];

  final repository = ref.watch(facilityRepositoryProvider);
  return repository.getFacilitiesInBounds(
    minLat: bounds.southwest.latitude,
    minLng: bounds.southwest.longitude,
    maxLat: bounds.northeast.latitude,
    maxLng: bounds.northeast.longitude,
  );
});
