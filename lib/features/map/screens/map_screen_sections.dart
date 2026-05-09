part of 'map_screen.dart';

extension _MapScreenBuild on _MapScreenState {
  Widget _buildMapScreen(BuildContext context) {
    ref.listen<({double lat, double lng})?>(
      mapFlyToProvider,
      (previous, next) {
        if (next == null) return;
        final target = LatLng(next.lat, next.lng);
        _mapController.move(target, 15);
        _lastSearchCenter = target;
        _lastSearchZoom = 15;
        ref.read(mapSearchParamsProvider.notifier).update(
              (params) => params.copyWith(
                latitude: next.lat,
                longitude: next.lng,
                radiusMeters: 3000,
              ),
            );
        ref.read(mapFlyToProvider.notifier).state = null;
      },
    );

    ref.listen<AsyncValue<List<Facility>>>(
      mapFacilityListProvider,
      (previous, next) {
        final nextList = next.valueOrNull;
        if (nextList != null && nextList != previous?.valueOrNull) {
          _updateMarkers(nextList);
        }
      },
    );

    final params = ref.watch(mapSearchParamsProvider);
    final hasFilter = params.facilityTypeId != null ||
        params.amenityIds.isNotEmpty ||
        params.isOpenNow;
    final currentLoc = ref.watch(currentLocationProvider);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _MapScreenState._defaultCenter,
              initialZoom: AppConstants.defaultZoom,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yumap.app',
                maxNativeZoom: 18,
              ),
              if (currentLoc != null)
                CircleLayer(circles: [
                  CircleMarker(
                    point: LatLng(currentLoc.lat, currentLoc.lng),
                    color: const Color(0x331565C0),
                    borderColor: const Color(0x881565C0),
                    borderStrokeWidth: 1,
                    radius: 30,
                  ),
                ]),
              if (currentLoc != null)
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(currentLoc.lat, currentLoc.lng),
                    width: 18,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              MarkerLayer(markers: _markers),
            ],
          ),

          _MapSearchOverlay(
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            onSearchSubmitted: _onSearchSubmitted,
            onClearSearch: () {
              _searchDebounce?.cancel();
              _searchController.clear();
              ref
                  .read(mapSearchParamsProvider.notifier)
                  .update((p) => p.copyWith(clearText: true, page: 0));
            },
          ),

          const _MapCountBanner(),

          Positioned(
            bottom: 140,
            right: 8,
            child: _MapLegendCard(),
          ),

          Positioned(
            bottom: 96,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'my_location_fab',
              onPressed: _goToCurrentLocation,
              tooltip: '現在地',
              child: const Icon(Icons.my_location),
            ),
          ),

          const _MapEmptyState(),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showFilterSheet,
        tooltip: 'フィルター',
        icon: Icon(
          hasFilter ? Icons.filter_list : Icons.filter_list_outlined,
        ),
        label: Text(hasFilter ? 'フィルター中' : 'フィルター'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
