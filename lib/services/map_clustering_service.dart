// lib/services/map_clustering_service.dart
//
// flutter_map 用マーカービルダー。
// Facility リストから flutter_map の Marker リストを生成し、
// 施設IDでの高速検索のためにキャッシュを保持する。

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:yu_map/domain/entities/facility.dart';

class MapClusteringService {
  final Map<String, Facility> _cache = {};

  /// キャッシュ内の全施設（読み取り専用）
  Map<String, Facility> get cachedFacilities => Map.unmodifiable(_cache);

  /// IDで施設を検索する
  Facility? getCachedFacility(String id) => _cache[id];

  /// Facility リストから flutter_map の Marker リストを生成してキャッシュを更新する。
  /// 座標が無効な施設（[Facility.hasValidLocation] == false）は無視する。
  List<Marker> buildMarkers(
    List<Facility> facilities, {
    required void Function(Facility) onTap,
  }) {
    _cache.clear();
    final markers = <Marker>[];

    for (final facility in facilities) {
      if (!facility.hasValidLocation) continue;

      _cache[facility.id] = facility;
      final captured = facility; // クロージャでキャプチャ

      markers.add(
        Marker(
          point: LatLng(facility.latitude, facility.longitude),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => onTap(captured),
            child: _buildMarkerIcon(facility),
          ),
        ),
      );
    }

    return markers;
  }

  /// 施設タイプに応じたマーカーアイコンを返す。
  Widget _buildMarkerIcon(Facility facility) {
    // 施設タイプのコードに応じて絵文字を変える
    final emoji = _emojiForFacilityType(facility.facilityType);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  String _emojiForFacilityType(String? code) {
    switch (code?.toLowerCase()) {
      case 'onsen':
        return '♨️';
      case 'sauna':
        return '🧖';
      case 'public_bath':
        return '🛁';
      default:
        return '♨️';
    }
  }
}
