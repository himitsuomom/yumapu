import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/services/map_clustering_service.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  final _clusteringService = MapClusteringService();
  Set<Marker> _markers = {};

  static const _defaultPosition = CameraPosition(
    target: LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
    zoom: AppConstants.defaultZoom,
  );

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    final latLng = await _getCurrentLocation();
    if (!mounted) return;
    ref.read(facilitySearchParamsProvider.notifier).update(
          (params) => params.copyWith(
            latitude: latLng.latitude,
            longitude: latLng.longitude,
            radiusMeters: 5000,
          ),
        );
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(latLng, 13),
    );
  }

  /// Returns current device position. Falls back to Japan center on any error
  /// or when the user denies location permission.
  Future<LatLng> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      // Permission error, timeout, or service unavailable → fallback
      return const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    }
  }

  // ── Markers ───────────────────────────────────────────────────────────────

  /// Rebuilds the marker set from [facilities].
  ///
  /// Guards against calling [setState] after disposal.
  void _updateMarkers(List<Facility> facilities) {
    if (!mounted) return;
    final markers = _clusteringService.buildMarkers(
      facilities,
      onTap: _showFacilityPreview,
    );
    setState(() => _markers = markers);
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────

  void _showFacilityPreview(Facility facility) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FacilityPreviewSheet(facility: facility),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Only update markers when the facility list actually changes.
    // Comparing previous and next prevents redundant setState calls.
    ref.listen<AsyncValue<List<Facility>>>(
      facilityListProvider,
      (previous, next) {
        final prevList = previous?.valueOrNull;
        final nextList = next.valueOrNull;
        if (nextList != null && nextList != prevList) {
          _updateMarkers(nextList);
        }
      },
    );

    final isLoading = ref.watch(facilityListProvider) is AsyncLoading;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _defaultPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) => _mapController = controller,
          ),
          if (isLoading)
            const Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Facility preview sheet ────────────────────────────────────────────────────

class _FacilityPreviewSheet extends StatelessWidget {
  const _FacilityPreviewSheet({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Facility name
            Text(
              facility.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (facility.facilityType != null) ...[
              const SizedBox(height: 4),
              Chip(
                label: Text(facility.facilityType!),
                visualDensity: VisualDensity.compact,
              ),
            ],
            if (facility.address != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16,
                      color: Color(0xFF757575)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      facility.address!,
                      style: const TextStyle(color: Color(0xFF757575)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context)
                    .pushNamed('/facility', arguments: facility.id);
              },
              child: const Text('詳細を見る'),
            ),
          ],
        ),
      ),
    );
  }
}
