// lib/features/map/screens/map_screen.dart
//
// マップ画面（OpenStreetMap / flutter_map 版）
// APIキー不要・完全無料の OpenStreetMap タイルを使用。
//
// 機能:
//   - 起動時に現在地周辺 5km を初期検索
//   - カメラ停止後 800ms で再検索（debounce）
//   - 上部オーバーレイ検索バーで施設名検索（400ms debounce）
//   - フィルターFABでアメニティ・施設タイプを絞り込める
//   - 現在地ボタンで地図を現在地に移動する
//   - マーカータップ → FacilityPreviewSheet（ボトムシート）を表示

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/features/map/widgets/facility_preview_sheet.dart';
import 'package:yu_map/features/search/widgets/filter_bar.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/location_provider.dart';
import 'package:yu_map/providers/navigation_provider.dart';
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

  // ── 地図カメラ debounce ───────────────────────────────────────────────────

  /// 最後に検索したカメラ中心座標。
  /// 大きく移動したときだけ再検索するための比較用。
  LatLng? _lastSearchCenter;

  /// 最後に検索したときのズームレベル。
  /// UX-3修正: ズームが大きく変わった場合も再検索トリガーとするために保持する。
  double? _lastSearchZoom;

  /// カメラが動いている最中の最新位置。
  MapCamera? _currentCamera;

  /// カメラ停止後の debounce タイマー（800ms 後に再検索）
  Timer? _idleTimer;

  // ── 検索バー ──────────────────────────────────────────────────────────────

  final _searchController = TextEditingController();

  /// 文字入力の debounce タイマー（400ms 後に検索を実行）
  Timer? _searchDebounce;

  // ── 定数 ─────────────────────────────────────────────────────────────────

  static const _defaultCenter =
      LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

  /// カメラが何m移動したら再検索するかの閾値（2km）
  static const _reloadThresholdMeters = 2000.0;

  // ── ライフサイクル ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initLocation();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── 現在地取得 ────────────────────────────────────────────────────────────

  /// アプリ起動時の初期化。現在地を取得してカメラを移動し、周辺施設を検索する。
  /// フィルター・検索テキストなどすべてのパラメータを初期値に設定する。
  Future<void> _initLocation() async {
    final latLng = await _getCurrentLocation();
    if (!mounted) return;

    _lastSearchCenter = latLng;
    _lastSearchZoom = 13; // 初期ズームレベルに合わせる

    // 現在地をアプリ全体で共有するプロバイダーに保存する
    // （FacilityListTile の距離表示などが参照する）
    ref.read(currentLocationProvider.notifier).state = (
      lat: latLng.latitude,
      lng: latLng.longitude,
    );

    // 地図を現在地にフォーカスし、周辺 5km の施設を検索する
    ref.read(mapSearchParamsProvider.notifier).update(
          (params) => params.copyWith(
            latitude: latLng.latitude,
            longitude: latLng.longitude,
            radiusMeters: 5000,
          ),
        );
    _mapController.move(latLng, 13);
  }

  /// Bug-V9-3: 現在地ボタン専用メソッド。
  ///
  /// [_initLocation] との違い：
  /// - カメラを現在地に移動する（同じ）
  /// - currentLocationProvider を更新する（同じ）
  /// - 地図の lat/lng/radius を更新する（同じ）
  /// - facilityTypeId・amenityIds・searchQuery などのフィルターは維持する（違い）
  ///
  /// ユーザーが施設タイプや検索ワードで絞り込んでいる最中に
  /// 現在地ボタンを押しても絞り込み設定が消えないようにする。
  Future<void> _goToCurrentLocation() async {
    final latLng = await _getCurrentLocation();
    if (!mounted) return;

    _lastSearchCenter = latLng;
    // ズームは 13 に固定（現在地ボタンは適度なズームで開く）
    _lastSearchZoom = 13;

    // 距離表示用プロバイダーを更新
    ref.read(currentLocationProvider.notifier).state = (
      lat: latLng.latitude,
      lng: latLng.longitude,
    );

    // 既存フィルター（facilityTypeId・amenityIds・searchQuery）を保持しつつ
    // 位置情報だけを更新する（copyWith は未指定フィールドを既存値で埋める）
    ref.read(mapSearchParamsProvider.notifier).update(
          (params) => params.copyWith(
            latitude: latLng.latitude,
            longitude: latLng.longitude,
            radiusMeters: 5000,
          ),
        );
    _mapController.move(latLng, 13);
  }

  /// 現在地を取得する。権限なし・タイムアウト時は日本中心（東京）にフォールバック。
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

  // ── カメラ移動 → 再検索 ───────────────────────────────────────────────────

  /// カメラ位置が変わるたびに呼ばれる。800ms 静止後に再検索する。
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
    final newZoom = camera.zoom;
    final last = _lastSearchCenter;
    final lastZoom = _lastSearchZoom;

    // UX-3修正: 移動距離 OR ズームレベルの変化（1段階以上）で再検索する。
    // これにより、ズームアウトして広域を見ようとした場合も新しい施設が取得される。
    final movedFar = last == null || _distanceMeters(last, newCenter) > _reloadThresholdMeters;
    final zoomChanged = lastZoom == null || (newZoom - lastZoom).abs() >= 1.0;
    final shouldReload = movedFar || zoomChanged;

    // ズームがクラスタリング閾値（14）を跨いだ場合、施設リストが変わらなくても
    // マーカーを再描画してクラスター/個別ピンの切り替えを即座に反映する。
    // （例: zoom 13.9 → 14.1 に変化した場合、shouldReload は false だが
    //   クラスターをやめて個別ピンに切り替える必要がある）
    final crossedClusterThreshold = lastZoom != null &&
        ((lastZoom < 14) != (newZoom < 14));
    if (!shouldReload) {
      if (crossedClusterThreshold) {
        final currentFacilities = ref.read(mapFacilityListProvider).valueOrNull;
        if (currentFacilities != null) {
          _updateMarkers(currentFacilities);
        }
      }
      return;
    }

    _lastSearchCenter = newCenter;
    _lastSearchZoom = newZoom;

    // ズームレベルに応じて検索半径を変える
    final zoom = camera.zoom;
    final radius = zoom >= 14
        ? 3000.0
        : zoom >= 12
            ? 6000.0
            : zoom >= 10
                ? 15000.0
                : 30000.0;

    ref.read(mapSearchParamsProvider.notifier).update(
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

  // ── 検索バー ──────────────────────────────────────────────────────────────

  /// 文字入力が変わるたびに呼ばれる。400ms 後に検索を実行する。
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _applySearch(query);
    });
  }

  /// Enter キー押下時に即座に検索する（debounce をスキップ）。
  /// 地名が含まれる場合は Nominatim でジオコーディングして地図を移動する。
  void _onSearchSubmitted(String query) {
    _searchDebounce?.cancel();
    _applySearchWithGeocoding(query);
  }

  /// 通常の施設名検索（リアルタイム入力用）。
  /// ジオコーディングはしない（重い処理のため入力中は行わない）。
  void _applySearch(String query) {
    final trimmed = query.trim();
    ref.read(mapSearchParamsProvider.notifier).update(
          (p) => trimmed.isEmpty
              ? p.copyWith(clearText: true, page: 0)
              : p.copyWith(searchQuery: trimmed, page: 0),
        );
  }

  /// 施設名検索 + Nominatim ジオコーディングを組み合わせた検索。
  /// Enter キー押下時にのみ実行する（ネットワークコストを抑えるため）。
  ///
  /// 動作フロー:
  ///   1. まず施設名フィルターを適用（即座にDBクエリ実行）
  ///   2. 並行して Nominatim API で日本国内の地名を検索
  ///   3. 地名が見つかったら地図カメラをその座標に移動し、周辺施設を再検索
  ///   4. 地名が見つからなければ施設名フィルターのみ（従来の動作）
  Future<void> _applySearchWithGeocoding(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      ref.read(mapSearchParamsProvider.notifier).update(
            (p) => p.copyWith(clearText: true, page: 0),
          );
      return;
    }

    // ステップ1: 施設名フィルターをまず適用（即座にレスポンス）
    ref.read(mapSearchParamsProvider.notifier).update(
          (p) => p.copyWith(searchQuery: trimmed, page: 0),
        );

    // ステップ2: Nominatim で地名検索（日本国内限定）
    final location = await _geocodeJapan(trimmed);
    if (!mounted) return;
    if (location == null) return; // 地名なし → 施設名フィルターのみで終了

    // ステップ3: 地図カメラを地名座標に移動して周辺施設を再検索
    final target = LatLng(location.$1, location.$2);
    _mapController.move(target, 13);
    _lastSearchCenter = target;
    _lastSearchZoom = 13;

    ref.read(mapSearchParamsProvider.notifier).update(
          (p) => p.copyWith(
            latitude: location.$1,
            longitude: location.$2,
            radiusMeters: 10000, // 地名検索は広めの10kmで探す
            page: 0,
          ),
        );
  }

  /// Nominatim API（OpenStreetMap の無料ジオコーダー）で日本国内の地名を検索する。
  ///
  /// 返り値: (latitude, longitude) のレコード。地名が見つからない場合は null。
  /// API制限: 1秒1リクエスト（ユーザー操作のEnter押下なので問題なし）。
  Future<(double, double)?> _geocodeJapan(String query) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': query,
          'format': 'json',
          'limit': '1',
          'countrycodes': 'jp', // 日本国内に限定
          'accept-language': 'ja',
        },
      );
      final response = await http.get(
        uri,
        headers: {
          // Nominatim の利用規約: User-Agent の指定が必須
          'User-Agent': 'YuMap/1.0 (com.yumap.app; contact: yumap@example.com)',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;
      final List<dynamic> results = jsonDecode(response.body) as List<dynamic>;
      if (results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat'] as String? ?? '');
      final lon = double.tryParse(first['lon'] as String? ?? '');
      if (lat == null || lon == null) return null;

      return (lat, lon);
    } catch (_) {
      // ネットワークエラー・タイムアウトは無視して施設名フィルターのみで継続
      return null;
    }
  }

  // ── マーカー更新 ─────────────────────────────────────────────────────────

  void _updateMarkers(List<Facility> facilities) {
    if (!mounted) return;
    // Bug-V9-1対応: 現在のズームレベルに応じてクラスタリングを適用する。
    // zoom >= 14 は個別ピン、それ未満はグリッドでまとめてクラスターバッジを表示。
    // 初期ズームは13のため、東京など密集エリアでも最初からクラスター表示になる。
    final zoom = _currentCamera?.zoom ?? AppConstants.defaultZoom;
    final markers = _clusteringService.buildMarkersWithClustering(
      facilities,
      onTap: _showFacilityPreview,
      zoomLevel: zoom,
      // Bug-V11-1対応: クラスターマーカーをタップしたらズームインする。
      // +2段階ズームアップしてクラスターを展開する。
      onClusterTap: (center, targetZoom) {
        _mapController.move(center, targetZoom);
      },
    );
    setState(() => _markers = markers);
  }

  // ── ボトムシート ─────────────────────────────────────────────────────────

  /// マーカータップ時に呼ばれる。地図上にボトムシートで施設情報を表示する。
  void _showFacilityPreview(Facility facility) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.transparent,
      builder: (_) => FacilityPreviewSheet(
        facility: facility,
        onOpenDetail: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed('/facility', arguments: facility.id);
        },
      ),
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
    // お気に入り画面など外部から「この座標に飛んでほしい」が届いたとき、
    // カメラを移動して周辺施設を再取得する。
    // 使用後は null にリセットして二重実行を防ぐ。
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
        // 使用後はリセット（次回も同じ施設に飛べるよう null に戻す）
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

    final facilityState = ref.watch(mapFacilityListProvider);
    final isLoading = facilityState is AsyncLoading;
    final params = ref.watch(mapSearchParamsProvider);
    final hasFilter = params.facilityTypeId != null ||
        params.amenityIds.isNotEmpty ||
        params.isOpenNow;
    // UX-V13-1: 現在地座標（null = 未取得 or 権限なし）
    final currentLoc = ref.watch(currentLocationProvider);

    // 検索クエリがある場合に表示する × バッジ
    final hasSearchQuery = params.searchQuery != null;

    // Bug-V6-3修正: 検索が1回以上実行されていて、かつ結果が0件のとき空状態メッセージを表示する。
    // facilityState.hasValue は AsyncData（空リスト含む）になったときに true になるため、
    // 初回ロード前（AsyncLoading）には表示されない。
    final showEmptyState = facilityState.hasValue &&
        !isLoading &&
        (facilityState.valueOrNull?.isEmpty ?? false) &&
        params.latitude != null;

    return Scaffold(
      body: Stack(
        children: [
          // ── FlutterMap（OpenStreetMap タイル）─────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
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
              // UX-V13-1: 現在地マーカー（青い丸）
              // currentLoc が null でなければ CircleLayer + MarkerLayer の2層で描画する。
              // flutter_map の各 Layer は FlutterMap.children の直接の子として配置する必要がある
              // （Stack で包むと座標変換が壊れる）。
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

          // ── 上部オーバーレイ（検索バー + フィルターバナー）────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 検索バー ──────────────────────────────────────────
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(28),
                  shadowColor: Colors.black26,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    onSubmitted: _onSearchSubmitted,
                    decoration: InputDecoration(
                      hintText: '施設名・エリアで検索',
                      // ローディング中はスピナー、通常は虫眼鏡アイコン
                      prefixIcon: isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(Icons.search),
                      // 入力中のみ × ボタンを表示する
                      suffixIcon: hasSearchQuery
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: '検索をクリア',
                              onPressed: () {
                                _searchDebounce?.cancel();
                                _searchController.clear();
                                ref
                                    .read(
                                        mapSearchParamsProvider.notifier)
                                    .update(
                                        (p) => p.copyWith(
                                            clearText: true, page: 0));
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),

                // ── フィルター適用中バナー ─────────────────────────────
                if (hasFilter) ...[
                  const SizedBox(height: 6),
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(20),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list,
                            size: 15,
                            color:
                                Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'フィルター適用中',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(mapSearchParamsProvider
                                      .notifier)
                                  .update(
                                    (p) => p.copyWith(
                                      clearFacilityType: true,
                                      amenityIds: [],
                                      isOpenNow: false,
                                    ),
                                  );
                            },
                            child: Icon(
                              Icons.close,
                              size: 15,
                              color:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── 現在地ボタン（右下）──────────────────────────────────────
          Positioned(
            bottom: 96,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'my_location_fab',
              // Bug-V9-3: フィルターを保持したまま現在地に移動する
              onPressed: _goToCurrentLocation,
              tooltip: '現在地',
              child: const Icon(Icons.my_location),
            ),
          ),

          // ── Bug-V6-3: 検索結果0件の空状態オーバーレイ ─────────────────
          if (showEmptyState)
            Positioned(
              bottom: 160,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(237), // 0.93 * 255 ≈ 237
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 36,
                        color: Color(0xFF9E9E9E),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '施設が見つかりません',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '検索条件を変えるか、別のエリアで試してください',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // ── フィルターFAB（左下）──────────────────────────────────────────
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

// ── フィルターボトムシート ────────────────────────────────────────────────────

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(mapSearchParamsProvider);

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
                      params.amenityIds.isNotEmpty ||
                      params.isOpenNow)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(mapSearchParamsProvider.notifier)
                            .update(
                              (p) => p.copyWith(
                                clearFacilityType: true,
                                amenityIds: [],
                                isOpenNow: false,
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
              isOpenNow: params.isOpenNow,
              onFacilityTypeChanged: (typeId) {
                ref.read(mapSearchParamsProvider.notifier).update(
                  (p) => typeId == null
                      ? p.copyWith(clearFacilityType: true, page: 0)
                      : p.copyWith(facilityTypeId: typeId, page: 0),
                );
              },
              onAmenityToggled: (amenityId) {
                ref.read(mapSearchParamsProvider.notifier).update((p) {
                  final current = List<String>.from(p.amenityIds);
                  if (current.contains(amenityId)) {
                    current.remove(amenityId);
                  } else {
                    current.add(amenityId);
                  }
                  return p.copyWith(amenityIds: current, page: 0);
                });
              },
              onOpenNowChanged: (value) {
                ref.read(mapSearchParamsProvider.notifier).update(
                      (p) => p.copyWith(isOpenNow: value, page: 0),
                    );
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
