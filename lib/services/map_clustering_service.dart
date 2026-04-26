// lib/services/map_clustering_service.dart
//
// flutter_map 用マーカービルダー。
// 施設タイプ別カラーのピン型マーカーを生成する。
//   温泉   (onsen)       → 朱赤 #E53935
//   銭湯   (public_bath) → 青   #1976D2
//   サウナ (sauna)       → 緑   #2E7D32
//   その他               → 紫   #7B1FA2

import 'dart:ui' as ui;

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

      // ピンの高さ = ラベル行18px + 本体48px + 先端三角7px = 73px
      // Alignment.bottomCenter → 下端（三角の先端）が地理座標に一致する
      markers.add(
        Marker(
          point: LatLng(facility.latitude, facility.longitude),
          width: 68,
          height: 73,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () => onTap(captured),
            child: _PinMarker(facility: facility),
          ),
        ),
      );
    }

    return markers;
  }

  /// ズームレベルに応じてクラスタリングを適用しながらマーカーを生成する。
  ///
  /// ズームが低い（広域表示）ほどグリッドサイズを大きくし、
  /// 近接する複数施設を数字バッジ付きのクラスターマーカーにまとめる。
  ///
  /// - zoom >= 14 : 個別ピンマーカー（クラスタリングなし）
  /// - zoom >= 10 : 約0.05°（≈5.5km）のグリッドでまとめる
  /// - zoom < 10  : 約0.2°（≈22km）のグリッドでまとめる
  ///
  /// 初期表示のズームは13のため、このしきい値設定により東京・大阪など
  /// 施設密集エリアでも最初からクラスタリングが効く（Bug-V9-1対応）。
  /// zoom 14以上に拡大すると個別マーカーが表示され、施設を選択できる。
  ///
  /// [onClusterTap]: クラスターマーカーをタップしたとき呼ばれる。
  /// 中心座標（LatLng）と推奨ズームレベルを渡す（Bug-V11-1対応）。
  /// null の場合はタップしても何も起きない（後方互換のため省略可能）。
  List<Marker> buildMarkersWithClustering(
    List<Facility> facilities, {
    required void Function(Facility) onTap,
    required double zoomLevel,
    void Function(LatLng center, double targetZoom)? onClusterTap,
  }) {
    // ズームが十分高ければクラスタリング不要 → 従来の個別マーカー
    if (zoomLevel >= 14) {
      return buildMarkers(facilities, onTap: onTap);
    }

    _cache.clear();

    // グリッドサイズ（度）: ズームが低いほど大きいセルに収める
    final double gridSize = zoomLevel >= 10 ? 0.05 : 0.2;

    // グリッドセルキー → その中に含まれる施設リスト
    final Map<String, List<Facility>> cellMap = {};
    for (final facility in facilities) {
      if (!facility.hasValidLocation) continue;
      final cellKey =
          '${(facility.latitude / gridSize).floor()}_${(facility.longitude / gridSize).floor()}';
      cellMap.putIfAbsent(cellKey, () => []).add(facility);
    }

    final markers = <Marker>[];
    for (final cell in cellMap.values) {
      if (cell.length == 1) {
        // 1施設だけのセル → 個別ピンマーカー
        final f = cell.first;
        _cache[f.id] = f;
        markers.add(
          Marker(
            point: LatLng(f.latitude, f.longitude),
            width: 68,
            height: 73,
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () => onTap(f),
              child: _PinMarker(facility: f),
            ),
          ),
        );
      } else {
        // 複数施設のセル → クラスターマーカー
        // 中心座標 = セル内施設の緯度・経度の平均
        final avgLat =
            cell.map((f) => f.latitude).reduce((a, b) => a + b) / cell.length;
        final avgLng =
            cell.map((f) => f.longitude).reduce((a, b) => a + b) / cell.length;

        // 施設タイプの最多種別でクラスターの色を決める
        final typeCounts = <String, int>{};
        for (final f in cell) {
          final code = f.facilityType ?? 'other';
          typeCounts[code] = (typeCounts[code] ?? 0) + 1;
        }
        final dominantType = typeCounts.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;

        // クラスター内の全施設もキャッシュに入れておく
        for (final f in cell) {
          _cache[f.id] = f;
        }

        // クラスターのタップ先ズームレベル: 現在の2段階上（最大18）
        final clusterCenter = LatLng(avgLat, avgLng);
        final targetZoom = (zoomLevel + 2.0).clamp(0.0, 18.0);

        markers.add(
          Marker(
            point: clusterCenter,
            width: 52,
            height: 52,
            child: GestureDetector(
              // Bug-V11-1対応: クラスターをタップしたらズームインする
              onTap: onClusterTap != null
                  ? () => onClusterTap(clusterCenter, targetZoom)
                  : null,
              child: _ClusterMarker(
                count: cell.length,
                facilityTypeCode: dominantType,
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 施設タイプ → カラー共有関数（_PinMarker と _ClusterMarker で使う）
// ─────────────────────────────────────────────────────────────────────────────

Color _colorForFacilityType(String? typeCode) {
  switch (typeCode?.toLowerCase()) {
    case 'onsen':
      return const Color(0xFFE53935); // 朱赤（温泉）
    case 'public_bath':
      return const Color(0xFF1976D2); // 青（銭湯）
    case 'sauna':
      return const Color(0xFF2E7D32); // 深緑（サウナ）
    default:
      return const Color(0xFF7B1FA2); // 紫（その他）
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// クラスターマーカーウィジェット
// 複数施設が密集しているエリアに表示する円形バッジ
// ─────────────────────────────────────────────────────────────────────────────

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({
    required this.count,
    required this.facilityTypeCode,
  });

  final int count;
  final String facilityTypeCode;

  @override
  Widget build(BuildContext context) {
    final color = _colorForFacilityType(facilityTypeCode);
    final label = count > 99 ? '99+' : '$count';

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ピン型マーカーウィジェット
// ─────────────────────────────────────────────────────────────────────────────

class _PinMarker extends StatelessWidget {
  const _PinMarker({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final color = _colorForFacilityType(facility.facilityType);
    final icon = _iconForType(facility.facilityType);
    // 施設名を最大4文字に切り詰める
    final label = facility.name.length > 4
        ? '${facility.name.substring(0, 4)}…'
        : facility.name;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 施設名ラベル（ピンの上に配置）──────────────────────────────
        // ラベルを上にすることで、下端＝三角先端＝地理座標 の関係を保つ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.93),
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.9),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.clip,
          ),
        ),
        const SizedBox(height: 2),
        // ── ピン本体（丸いアイコン部分）────────────────────────────────
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              icon,
              style: const TextStyle(fontSize: 22, height: 1),
            ),
          ),
        ),
        // ── ピン先端（三角形）─────────────────────────────────────────
        // この三角の先端（下端）が地理座標になる
        CustomPaint(
          size: const Size(12, 7),
          painter: _TrianglePainter(color: color),
        ),
      ],
    );
  }

  // 施設タイプ → アイコン絵文字
  static String _iconForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'onsen':
        return '♨';
      case 'public_bath':
        return '🛁';
      case 'sauna':
        return '🧖';
      default:
        return '♨';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ピン先端の三角形を描画するカスタムペインター
// ─────────────────────────────────────────────────────────────────────────────

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
