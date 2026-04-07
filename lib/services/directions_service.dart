// lib/services/directions_service.dart
//
// Google Directions API をサーバーサイドプロキシ（Supabase Edge Function）経由で呼び出すサービス。
// APIキーはクライアント側には一切持たず、supabase/functions/directions/index.ts で保護します。

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/config/app_config.dart';

/// Google Directions API の結果を保持するクラス
class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String distance; // e.g. "5.2 km"
  final String duration; // e.g. "12分"
  final LatLngBounds bounds;

  const DirectionsResult({
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.bounds,
  });
}

/// Google Directions API を Supabase Edge Function 経由で使うサービス。
///
/// セキュリティ設計:
///   - クライアントは APIキーを持たない
///   - APIキーは Supabase の Secrets（サーバーのみが参照可能）に保存
///   - 通信は SUPABASE_ANON_KEY + Authorization ヘッダで認証
class DirectionsService {
  /// Edge Function の相対パス（supabase URL に結合して使う）
  static const _functionPath = '/functions/v1/directions';

  /// 出発地から目的地までのルート情報を取得
  static Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final supabaseUrl = AppConfig.supabaseUrl;
    final anonKey = AppConfig.supabaseAnonKey;
    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;

    if (supabaseUrl.isEmpty || anonKey.isEmpty) {
      debugPrint('DirectionsService: Supabase URL or anon key is not set');
      return null;
    }

    final url = Uri.parse('$supabaseUrl$_functionPath');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'apikey': anonKey,
      // ログイン中はアクセストークンを使い、未ログインは anon key で代替
      'Authorization': 'Bearer ${accessToken ?? anonKey}',
    };

    final body = jsonEncode({
      'originLat': origin.latitude,
      'originLng': origin.longitude,
      'destLat': destination.latitude,
      'destLng': destination.longitude,
      'mode': 'driving',
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        debugPrint(
            'DirectionsService: Edge Function HTTP ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status != 'OK') {
        debugPrint('DirectionsService: Directions API status=$status');
        return null;
      }

      final routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final legs = route['legs'] as List<dynamic>;
      if (legs.isEmpty) return null;

      final leg = legs[0] as Map<String, dynamic>;

      final distance =
          (leg['distance'] as Map<String, dynamic>)['text'] as String;
      final duration =
          (leg['duration'] as Map<String, dynamic>)['text'] as String;

      final overviewPolyline =
          route['overview_polyline'] as Map<String, dynamic>;
      final encodedPoints = overviewPolyline['points'] as String;
      final polylinePoints = _decodePolyline(encodedPoints);

      final boundsData = route['bounds'] as Map<String, dynamic>;
      final northeast = boundsData['northeast'] as Map<String, dynamic>;
      final southwest = boundsData['southwest'] as Map<String, dynamic>;
      final bounds = LatLngBounds(
        northeast: LatLng(
          (northeast['lat'] as num).toDouble(),
          (northeast['lng'] as num).toDouble(),
        ),
        southwest: LatLng(
          (southwest['lat'] as num).toDouble(),
          (southwest['lng'] as num).toDouble(),
        ),
      );

      return DirectionsResult(
        polylinePoints: polylinePoints,
        distance: distance,
        duration: duration,
        bounds: bounds,
      );
    } catch (e) {
      debugPrint('DirectionsService: Exception $e');
      return null;
    }
  }

  /// Google Encoded Polyline Algorithm をデコード
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Latitude
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Longitude
      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}
