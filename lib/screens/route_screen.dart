// lib/screens/route_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/services/directions_service.dart';

/// ルート表示画面
/// 現在地から施設までのルートをPolylineで描画し、距離・所要時間を表示
class RouteScreen extends StatefulWidget {
  final Facility facility;
  final LatLng currentLocation;

  const RouteScreen({
    super.key,
    required this.facility,
    required this.currentLocation,
  });

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  GoogleMapController? _mapController;
  DirectionsResult? _directions;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDirections();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchDirections() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await DirectionsService.getDirections(
        origin: widget.currentLocation,
        destination: LatLng(
          widget.facility.latitude,
          widget.facility.longitude,
        ),
      );

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'ルート情報を取得できませんでした';
        });
        return;
      }

      setState(() {
        _directions = result;
        _isLoading = false;
      });

      // ルートの境界にカメラを合わせる
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(result.bounds, 80),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'エラーが発生しました: $e';
      });
    }
  }

  /// Googleマップのナビモードを起動
  Future<void> _launchNavigation() async {
    final lat = widget.facility.latitude;
    final lng = widget.facility.longitude;

    // Google Maps のナビモード URL
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng'
      '&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Web の場合は新しいタブで開く
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Googleマップを開けませんでした: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = LatLng(
      widget.facility.latitude,
      widget.facility.longitude,
    );

    // マーカー: 現在地(青) + 目的地(オレンジ)
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('origin'),
        position: widget.currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '現在地'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: widget.facility.name),
      ),
    };

    // ルートのPolyline
    final polylines = <Polyline>{};
    if (_directions != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _directions!.polylinePoints,
          color: Colors.blue,
          width: 5,
        ),
      );
    }

    // 初期カメラ位置: 2点の中間
    final midLat = (widget.currentLocation.latitude + destination.latitude) / 2;
    final midLng = (widget.currentLocation.longitude + destination.longitude) / 2;

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(midLat, midLng),
              zoom: 12,
            ),
            markers: markers,
            polylines: polylines,
            onMapCreated: (controller) {
              _mapController = controller;
              // ルートがすでに取得済みなら境界に合わせる
              if (_directions != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngBounds(_directions!.bounds, 80),
                );
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── ローディング ──
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x55FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          // ── 上部: 戻るボタン ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black87),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 下部: ルート情報パネル ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 施設名
              Text(
                widget.facility.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // 住所
              Text(
                widget.facility.address,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // エラー表示
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: _fetchDirections,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 距離・所要時間
              if (_directions != null) ...[
                Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.straighten,
                      label: _directions!.distance,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      icon: Icons.access_time,
                      label: _directions!.duration,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ナビ開始ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text(
                    'Googleマップでナビ開始',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _launchNavigation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
