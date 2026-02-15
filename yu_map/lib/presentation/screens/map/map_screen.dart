// lib/presentation/screens/map/map_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/facility_providers.dart';
import 'package:yu_map/providers/service_providers.dart';
import 'package:yu_map/presentation/widgets/amenity_filter_chips.dart';

/// Default camera position — centre of Japan.
const _defaultPosition = CameraPosition(
  target: LatLng(36.2048, 138.2529),
  zoom: 6,
);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Map<String, bool> _amenityFilters = {};
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _initClusterManager();
    _requestLocationAndMove();
  }

  void _initClusterManager() {
    final clusterService = ref.read(mapClusteringServiceProvider);
    if (!clusterService.isInitialized) {
      clusterService.initializeClusterManager(
        updateMarkers: (markers) {
          if (mounted) {
            setState(() => _markers = markers);
          }
        },
        onFacilityTap: (facilityId) {
          if (mounted) {
            context.push('/facility/$facilityId');
          }
        },
      );
    }
  }

  Future<void> _requestLocationAndMove() async {
    setState(() => _isLoadingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14,
        ),
      );
    } catch (_) {
      // Use default position if location is unavailable
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _onCameraIdle() {
    _mapController?.getVisibleRegion().then((bounds) {
      ref.read(mapFacilitiesProvider.notifier).loadInBounds(
            minLat: bounds.southwest.latitude,
            minLng: bounds.southwest.longitude,
            maxLat: bounds.northeast.latitude,
            maxLng: bounds.northeast.longitude,
            amenities: _amenityFilters.isEmpty ? null : _amenityFilters,
          );
    });
  }

  void _onFacilitiesUpdated(List<Facility> facilities) {
    final clusterService = ref.read(mapClusteringServiceProvider);
    clusterService.updateItems(facilities);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to facility data and update markers.
    ref.listen<AsyncValue<List<Facility>>>(
      mapFacilitiesProvider,
      (previous, next) {
        next.whenData(_onFacilitiesUpdated);
      },
    );

    final facilitiesState = ref.watch(mapFacilitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yu-Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Google Map ──
          GoogleMap(
            initialCameraPosition: _defaultPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraIdle: _onCameraIdle,
          ),

          // ── Amenity filter chips ──
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: AmenityFilterChips(
              selected: _amenityFilters,
              onChanged: (filters) {
                setState(() => _amenityFilters = filters);
                _onCameraIdle(); // re-fetch with new filters
              },
            ),
          ),

          // ── Loading indicator ──
          if (facilitiesState.isLoading || _isLoadingLocation)
            const Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(child: LinearProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _requestLocationAndMove,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
