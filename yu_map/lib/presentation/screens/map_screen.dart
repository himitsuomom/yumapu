import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yu_map/core/providers/facility_providers.dart';
import 'package:yu_map/services/map_clustering_service.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  late MapClusteringService _clusteringService;
  Set<Marker> _markers = {};
  bool _initialLocationSet = false;

  // Default initial position (Tokyo)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.681236, 139.767125),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _clusteringService = MapClusteringService();
    _clusteringService.initializeClusterManager(
      updateMarkers: (markers) {
        setState(() {
          _markers = markers;
        });
      },
    );
    
    // Listen to facilities changes (moved from build method for efficiency)
    ref.listenManual(facilitiesInBoundsProvider, (previous, next) {
      next.whenData((facilities) {
        _clusteringService.updateItems(facilities);
      });
    });
    
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services disabled, use default position and fetch facilities
      _initialLocationSet = true;
      _fetchInitialBounds();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied, use default position and fetch facilities
        _initialLocationSet = true;
        _fetchInitialBounds();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permission permanently denied, use default position and fetch facilities
      _initialLocationSet = true;
      _fetchInitialBounds();
      return;
    }
    
    // If permission granted, move to current location
    // The camera animation will trigger onCameraIdle which will fetch facilities
    try {
      final position = await Geolocator.getCurrentPosition();
      final controller = await _controller.future;
      _initialLocationSet = true;
      await controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14,
        ),
      ));
    } catch (e) {
      // Failed to get location, use default position
      _initialLocationSet = true;
      _fetchInitialBounds();
    }
  }

  Future<void> _fetchInitialBounds() async {
    if (!_controller.isCompleted) return;
    final controller = await _controller.future;
    final bounds = await controller.getVisibleRegion();
    ref.read(mapBoundsProvider.notifier).state = bounds;
  }

  void _onCameraIdle() async {
    final controller = await _controller.future;
    final bounds = await controller.getVisibleRegion();
    
    // Update providers
    ref.read(mapBoundsProvider.notifier).state = bounds;
    
    // Note: We might want to pass the map controller to the clustering service 
    // if it needs it for zoom levels, but the basic implementation uses markers.
    // The clustering service typically manages its own state or needs update calls.
    // Here we update items whenever facilities change.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // We'll add a custom button
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              _clusteringService.updateItems([]); // Initialize with empty
              // Note: Initial bounds fetch is handled by _initializeLocation
              // after location permission check completes to avoid race condition
            },
            onCameraMove: (position) {
              _clusteringService.onCameraMove(position);
            },
            onCameraIdle: () {
               _clusteringService.updateMap();
               _onCameraIdle();
            },
          ),
          Positioned(
            bottom: 110,
            right: 16,
            child: FloatingActionButton(
              onPressed: () async {
                final controller = await _controller.future;
                try {
                   final position = await Geolocator.getCurrentPosition();
                   controller.animateCamera(CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(position.latitude, position.longitude),
                      zoom: 15,
                    ),
                  ));
                } catch (e) {
                  // Handle location error
                }
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
