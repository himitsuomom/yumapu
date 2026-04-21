// lib/features/map/screens/map_screen.dart
//
// マップ画面（OpenStreetMap / flutter_map 版）
// APIキー不要・完全無料の OpenStreetMap タイルを使用。
// - 起動時に現在地周辺 5km を初期検索
// - カメラ停止後 800ms で再検索（onPositionChanged + debounce タイマー）
// - フィルターFABでアメニティ・施設タイプを絞り込める
// - 現在地ボタンで地図を現在地に移動する

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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
  late final MapController _mapController;
  final _clusteringService = MapClusteringService();
  List<Marker> _markers = [];

  /// 最後に検索したカメラ中心座標。
  /// 大きく移動したときだけ再検索するための比較用。
  LatLng? _lastSearchCenter;

  /// カメラが動いている最中の最新位置。
  MapCamera? _currentCamera;

  /// debounce（ちょっと待つ）タイマー。地図が止まった 800ms 後に再検索する。
  Timer? _idleTimer;

  static const _defaultCenter =
      LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

  /// カメラが何m移動したら再検索するかの閾値（2km）
  static const _reloadThresholdMeters = 2000.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initLocation();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _mapController.dispose();
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
    // flutter_map のカメラ移動
    _mapController.move(latLng, 13);
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
        return _defaultCenter;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return _defaultCenter;
    }
  }

  // ── Camera → re-search ────────────────────────────────────────────────────

  /// カメラ位置が変わるたびに呼ばれる。
  /// debounce タイマーで 800ms 静止後に再検索する。
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _currentCamera = camera;
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _onMapIdle();
    });
  }

  /// 地図が静止したとき呼ばれる。
  void _onMapIdle() {
    final camera = _currentCamera;
    if (camera == null) return;

    final newCenter = camera.center;
    final last = _lastSearchCenter;

    final shouldReload = last == null ||
        _distanceMeters(last, newCenter) > _reloadThresholdMeters;

    if (!shouldReload) return;

    _lastSearchCenter = newCenter;

    // ズームレベルに応じて検索半径を変える
    final zoom = camera.zoom;
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

  /// 2点間の距離（m）を概算する（ハーバーサイン法）
  double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
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
        final nextList = next.valueOrNull;
        if (nextList != null && nextList != previous?.valueOrNull) {
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
          // ── FlutterMap（OpenStreetMap タイル）───────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: AppConstants.defaultZoom,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              // OpenStreetMap タイルレイヤー（APIキー不要・完全無料）
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yumap.app',
                // タイルのキャッシュ設定（オフライン対応のため最大256枚保持）
                maxNativeZoom: 18,
              ),
              // 施設マーカーレイヤー
              MarkerLayer(markers: _markers),
            ],
          ),

          // ── ローディングインジケーター ─────────────────────────────
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

          // ── フィルター中バナー ────────────────────────────────────
          if (hasFilter)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
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

          // ── 現在地ボタン（右下）──────────────────────────────────
          Positioned(
            bottom: 96,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'my_location_fab',
              onPressed: _initLocation,
              tooltip: '現在地',
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),

      // ── フィルターFAB（左下）──────────────────────────────────────
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
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: Color(0xFF757575)),
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
