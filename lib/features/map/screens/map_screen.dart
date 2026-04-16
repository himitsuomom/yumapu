// lib/features/map/screens/map_screen.dart
//
// マップ画面
// Google Maps 上に温浴施設マーカーを表示する。
// - 起動時に現在地周辺 5km を初期検索
// - カメラが止まるたびに新しい中心座標で再検索（onCameraIdle）
// - フィルターFABでアメニティ・施設タイプを絞り込める

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/features/search/widgets/filter_bar.dart';
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

  /// 最後に検索したカメラ中心座標。
  /// onCameraIdle で大きく移動したときだけ再検索するための比較用。
  LatLng? _lastSearchCenter;

  /// カメラが動いている最中の最新位置（onCameraMove で更新）。
  CameraPosition? _currentCameraPosition;

  static const _defaultPosition = CameraPosition(
    target: LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
    zoom: AppConstants.defaultZoom,
  );

  /// カメラが何m移動したら再検索するかの閾値（2km）
  static const _reloadThresholdMeters = 2000.0;

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
    _lastSearchCenter = latLng;
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

  /// 現在地を取得する。権限なし・タイムアウトは日本中心にフォールバック。
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
      return const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    }
  }

  // ── Camera idle → re-search ───────────────────────────────────────────────

  /// カメラが止まったとき呼ばれる。
  /// 前回の検索中心から _reloadThresholdMeters 以上移動していれば再検索する。
  void _onCameraIdle() {
    final pos = _currentCameraPosition;
    if (pos == null) return;

    final newCenter = pos.target;
    final last = _lastSearchCenter;

    // 移動距離を計算（ハーバーサイン法の近似）
    bool shouldReload = last == null ||
        _distanceMeters(last, newCenter) > _reloadThresholdMeters;

    if (!shouldReload) return;

    _lastSearchCenter = newCenter;

    // ズームレベルに応じて検索半径を変える（遠ければ広く、近ければ狭く）
    final zoom = pos.zoom;
    final radius = zoom >= 14
        ? 3000.0
        : zoom >= 12
            ? 6000.0
            : zoom >= 10
                ? 15000.0
                : 30000.0;

    ref.read(facilitySearchParamsProvider.notifier).update(
          (params) => params.copyWith(
            latitude: newCenter.latitude,
            longitude: newCenter.longitude,
            radiusMeters: radius,
          ),
        );
  }

  /// 2点間の距離（m）を概算する（精度：数%以内）。
  double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0; // 地球半径（m）
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final cosA = math.cos(a.latitude * math.pi / 180);
    final cosB = math.cos(b.latitude * math.pi / 180);
    final h = sinLat * sinLat + cosA * cosB * sinLng * sinLng;
    return 2 * r * math.asin(math.sqrt(h));
  }

  // ── Markers ───────────────────────────────────────────────────────────────

  void _updateMarkers(List<Facility> facilities) {
    if (!mounted) return;
    final markers = _clusteringService.buildMarkers(
      facilities,
      onTap: _showFacilityPreview,
    );
    setState(() => _markers = markers);
  }

  // ── Bottom sheets ─────────────────────────────────────────────────────────

  void _showFacilityPreview(Facility facility) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FacilityPreviewSheet(facility: facility),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
    final params = ref.watch(facilitySearchParamsProvider);
    final hasFilter =
        params.facilityTypeId != null || params.amenityIds.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ─────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: _defaultPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (pos) => _currentCameraPosition = pos,
            onCameraIdle: _onCameraIdle,
          ),

          // ── ローディングインジケーター ─────────────────────────────────
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

          // ── フィルター中バナー（フィルターが有効のとき表示） ───────────
          if (hasFilter)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_list,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'フィルター適用中',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ref
                              .read(facilitySearchParamsProvider.notifier)
                              .update(
                                (p) => p.copyWith(
                                  clearFacilityType: true,
                                  amenityIds: [],
                                ),
                              );
                        },
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // ── フィルターFAB ─────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: _showFilterSheet,
        tooltip: 'フィルター',
        child: Icon(
          hasFilter ? Icons.filter_list : Icons.filter_list_outlined,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

/// マップ用フィルターボトムシート。
/// SearchScreen と同じ FilterBar ウィジェットを流用する。
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(facilitySearchParamsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ドラッグハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '絞り込み',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  // フィルターをすべてリセットするボタン
                  if (params.facilityTypeId != null ||
                      params.amenityIds.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(facilitySearchParamsProvider.notifier)
                            .update(
                              (p) => p.copyWith(
                                clearFacilityType: true,
                                amenityIds: [],
                              ),
                            );
                        Navigator.of(context).pop();
                      },
                      child: const Text('リセット'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // FilterBar = 施設タイプ + アメニティのチップ行
            FilterBar(
              selectedFacilityTypeId: params.facilityTypeId,
              selectedAmenityIds: params.amenityIds,
              onFacilityTypeChanged: (typeId) {
                ref.read(facilitySearchParamsProvider.notifier).update(
                      (p) => p.copyWith(facilityTypeId: typeId, page: 0),
                    );
              },
              onAmenityToggled: (amenityId) {
                ref.read(facilitySearchParamsProvider.notifier).update((p) {
                  final current = List<String>.from(p.amenityIds);
                  if (current.contains(amenityId)) {
                    current.remove(amenityId);
                  } else {
                    current.add(amenityId);
                  }
                  return p.copyWith(amenityIds: current, page: 0);
                });
              },
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('この条件で表示'),
                ),
              ),
            ),
          ],
        ),
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
            if (facility.hasFacilityType) ...[
              const SizedBox(height: 4),
              Chip(
                label: Text(facility.facilityTypeJa),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context)
                      .pushNamed('/facility', arguments: facility.id);
                },
                child: const Text('詳細を見る'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
