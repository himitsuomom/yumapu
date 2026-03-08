import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/features/facility/screens/facility_detail_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(facilitySearchProvider.notifier).loadAll());
  }

  void _updateMarkers(List<Facility> facilities) {
    setState(() {
      _markers = facilities.map((f) {
        return Marker(
          markerId: MarkerId(f.id),
          position: LatLng(f.latitude, f.longitude),
          infoWindow: InfoWindow(
            title: f.name,
            snippet: f.address ?? '',
            onTap: () => _openFacilityDetail(f),
          ),
          onTap: () => _showFacilityPreview(f),
        );
      }).toSet();
    });
  }

  void _openFacilityDetail(Facility facility) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FacilityDetailScreen(facilityId: facility.id),
      ),
    );
  }

  void _showFacilityPreview(Facility facility) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _FacilityPreviewSheet(
        facility: facility,
        onTap: () {
          Navigator.pop(ctx);
          _openFacilityDetail(facility);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(facilitySearchProvider);

    ref.listen<FacilitySearchState>(facilitySearchProvider, (_, state) {
      if (!state.isLoading && state.error == null) {
        _updateMarkers(state.facilities);
      }
    });

    // Update markers when data first loads
    if (searchState.facilities.isNotEmpty && _markers.isEmpty) {
      Future.microtask(() => _updateMarkers(searchState.facilities));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
            tooltip: '現在地',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
              zoom: AppConstants.defaultZoom,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
          ),
          if (searchState.isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: LoadingWidget(message: '施設を読み込み中...'),
                  ),
                ),
              ),
            ),
          // Facility count badge
          Positioned(
            bottom: 16,
            left: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  '${searchState.facilities.length} 件',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    // Default to Tokyo if location services unavailable
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        const LatLng(35.6762, 139.6503),
        12,
      ),
    );
  }
}

class _FacilityPreviewSheet extends StatelessWidget {
  const _FacilityPreviewSheet({
    required this.facility,
    required this.onTap,
  });
  final Facility facility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              facility.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (facility.address != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      facility.address!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                child: const Text('詳細を見る'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
