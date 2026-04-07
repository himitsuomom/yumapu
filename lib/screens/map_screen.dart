import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yu_map/core/config/amenity_config.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/services/supabase_service.dart';
import 'package:yu_map/widgets/hexagon_logo.dart';

/// MapScreen — real Google Maps view with facility markers and search
class MapScreen extends StatefulWidget {
  final Function(Facility) onFacilitySelected;

  const MapScreen({super.key, required this.onFacilitySelected});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // ビューポート内の施設（DB から取得した生データ）
  List<Facility> _viewportFacilities = [];
  bool _isViewportLoading = false;
  String? _viewportError;

  List<Facility> _searchResults = [];
  bool _isSearchLoading = false;
  String _searchQuery = '';
  Timer? _debounce;

  // アメニティフィルター（選択されたキーの集合）
  // 例: {'sauna', 'parking'} → 両方を持つ施設だけ表示
  Set<String> _activeFilters = {};

  /// 初期カメラ位置：東京
  static const _kInitialCamera = CameraPosition(
    target: LatLng(35.6812, 139.7671),
    zoom: 11.5,
  );

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController?.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Viewport fetch ─────────────────────────────────────────────────────────

  Future<void> _loadViewportFacilities() async {
    if (_mapController == null) return;
    if (_isViewportLoading) return;
    setState(() {
      _isViewportLoading = true;
      _viewportError = null;
    });

    try {
      final bounds = await _mapController!.getVisibleRegion();
      final facilities = await SupabaseService.fetchFacilitiesInBounds(
        swLat: bounds.southwest.latitude,
        swLng: bounds.southwest.longitude,
        neLat: bounds.northeast.latitude,
        neLng: bounds.northeast.longitude,
      );
      if (mounted) {
        setState(() {
          _viewportFacilities = facilities;
          _isViewportLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _viewportError = 'データの読み込みに失敗しました';
          _isViewportLoading = false;
        });
      }
    }
  }

  // ─── フィルタリング ──────────────────────────────────────────────────────────

  /// アクティブなフィルターを全て満たす施設だけを返す
  List<Facility> get _filteredFacilities {
    if (_activeFilters.isEmpty) return _viewportFacilities;
    return _viewportFacilities.where((f) {
      return _activeFilters.every((key) => f.amenities[key] == true);
    }).toList();
  }

  /// フィルター選択ボトムシートを表示
  void _showFilterSheet() {
    // ボトムシート内でStateを管理するためにStatefulBuilderを使用
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // ローカルコピーで操作し、確定ボタンで setState に反映する
        final localFilters = Set<String>.from(_activeFilters);
        return StatefulBuilder(
          builder: (_, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ハンドルバー
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '設備・アメニティで絞り込む',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() => localFilters.clear());
                          },
                          child: const Text('リセット'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AmenityConfig.definitions.map((def) {
                        final isSelected = localFilters.contains(def.key);
                        return FilterChip(
                          label: Text(def.label),
                          avatar: Icon(def.icon,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.deepOrange),
                          selected: isSelected,
                          selectedColor: Colors.deepOrange,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                localFilters.add(def.key);
                              } else {
                                localFilters.remove(def.key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          setState(() => _activeFilters = localFilters);
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          localFilters.isEmpty
                              ? 'すべて表示'
                              : '${localFilters.length}件の条件で絞り込む',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Markers ────────────────────────────────────────────────────────────────

  Set<Marker> _buildMarkers(List<Facility> facilities) {
    return facilities.map((f) {
      return Marker(
        markerId: MarkerId(f.id),
        position: LatLng(f.latitude, f.longitude),
        infoWindow: InfoWindow(
          title: f.name,
          snippet: '${_facilityTypeLabel(f.type)} · ¥${f.price}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () => widget.onFacilitySelected(f),
      );
    }).toSet();
  }

  String _facilityTypeLabel(String type) {
    switch (type) {
      case 'supersento':
        return 'スーパー銭湯';
      case 'sauna':
        return 'サウナ';
      case 'onsen':
        return '温泉';
      case 'public_bath':
        return '銭湯';
      default:
        return type;
    }
  }

  // ─── Search ─────────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchLoading = false;
      });
      return;
    }

    setState(() => _isSearchLoading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      try {
        final results = await SupabaseService.searchFacilities(query.trim());
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearchLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearchLoading = false);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearchLoading = false;
    });
  }

  void _selectSearchResult(Facility facility) {
    _clearSearch();
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(facility.latitude, facility.longitude),
        15.0,
      ),
    );
    widget.onFacilitySelected(facility);
  }

  // ─── Location ──────────────────────────────────────────────────────────────

  Future<void> _goToCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(_kInitialCamera),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15.0,
        ),
      );
    } catch (_) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(_kInitialCamera),
      );
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFacilities;
    final markers = _buildMarkers(filtered);
    final showSearchPanel = _searchQuery.isNotEmpty;
    final hasFilter = _activeFilters.isNotEmpty;

    return Stack(
      children: [
        // ── Google Map ──────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: _kInitialCamera,
          markers: markers,
          onMapCreated: (controller) {
            _mapController = controller;
            _loadViewportFacilities();
          },
          onCameraIdle: _loadViewportFacilities,
          onTap: (_) => _clearSearch(),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
        ),

        // ── Loading overlay ─────────────────────────────────────────
        if (_isViewportLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33FFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),

        // ── Error banner ────────────────────────────────────────────
        if (_viewportError != null)
          Positioned(
            bottom: 96,
            left: 16,
            right: 16,
            child: Material(
              borderRadius: BorderRadius.circular(12),
              elevation: 3,
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _viewportError!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadViewportFacilities,
                      child: const Text('再試行'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Search header ───────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search bar pill
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(28),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: HexagonLogo(size: 26),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'エリア・施設名で検索',
                              hintStyle: TextStyle(
                                  color: Colors.grey[400], fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 14),
                            ),
                          ),
                        ),
                        // フィルターボタン（アクティブ時はバッジ表示）
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.tune,
                                color: hasFilter
                                    ? Colors.deepOrange
                                    : Colors.grey,
                              ),
                              onPressed: _showFilterSheet,
                            ),
                            if (hasFilter)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Colors.deepOrange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_activeFilters.length}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: _clearSearch,
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(Icons.search, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),

                  // フィルター中の件数バナー
                  if (hasFilter && !showSearchPanel) ...[
                    const SizedBox(height: 6),
                    Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.deepOrange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_list,
                                color: Colors.deepOrange, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${filtered.length}件ヒット（フィルター: ${_activeFilters.length}件）',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.deepOrange),
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  setState(() => _activeFilters.clear()),
                              child: const Text(
                                'クリア',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.deepOrange,
                                    decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Search results dropdown
                  if (showSearchPanel) ...[
                    const SizedBox(height: 4),
                    Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxHeight: 280),
                          child: _buildSearchResultsPanel(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // ── My location button ──────────────────────────────────────
        Positioned(
          bottom: 96,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'mapReset',
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 3,
            onPressed: _goToCurrentLocation,
            child: const Icon(Icons.my_location_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsPanel() {
    if (_isSearchLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.search_off, color: Colors.grey[400]),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '"$_searchQuery" の検索結果は見つかりませんでした',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 56, endIndent: 16),
      itemBuilder: (_, i) {
        final f = _searchResults[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: const Text(
              '湯',
              style: TextStyle(
                  color: Colors.deepOrange, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            f.name,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            f.address,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            '¥${f.price}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.deepOrange),
          ),
          onTap: () => _selectSearchResult(f),
        );
      },
    );
  }
}
