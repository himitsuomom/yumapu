// lib/providers/location_provider.dart
//
// 現在地（緯度・経度）をアプリ全体で共有するプロバイダーと
// 距離計算ユーティリティ関数を定義する。
//
// 更新タイミング:
//   MapScreen が Geolocator で現在地を取得した際に書き込む。
//   他の画面は読み取りのみ。

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── 現在地プロバイダー ────────────────────────────────────────────────────────

/// アプリ全体で共有する現在地。
/// null = 未取得 または 位置情報権限なし。
/// MapScreen が現在地を取得するたびに更新される。
final currentLocationProvider = StateProvider<({double lat, double lng})?>(
  (ref) => null,
);

// ── 距離計算ユーティリティ ────────────────────────────────────────────────────

/// 2点間の距離を km 単位で返す（ハーバーサイン法による近似）。
///
/// [lat1] / [lon1]: 現在地の緯度・経度
/// [lat2] / [lon2]: 目的地（施設）の緯度・経度
///
/// 現在地が null の場合は null を返す。
double? computeDistanceKm({
  required double? lat1,
  required double? lon1,
  required double lat2,
  required double lon2,
}) {
  if (lat1 == null || lon1 == null) return null;
  const earthRadiusKm = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final sinLat = math.sin(dLat / 2);
  final sinLon = math.sin(dLon / 2);
  final cosA = math.cos(lat1 * math.pi / 180);
  final cosB = math.cos(lat2 * math.pi / 180);
  final h = sinLat * sinLat + cosA * cosB * sinLon * sinLon;
  return 2 * earthRadiusKm * math.asin(math.sqrt(h));
}

/// 距離 (km) をユーザー向けの表示文字列に変換する。
///
/// 1km 未満: 「○○m」形式（例: 「350m」）
/// 1km 以上: 「○.○km」形式（例: 「1.2km」）
String formatDistanceKm(double distanceKm) {
  if (distanceKm < 1.0) {
    return '${(distanceKm * 1000).round()}m';
  }
  return '${distanceKm.toStringAsFixed(1)}km';
}
