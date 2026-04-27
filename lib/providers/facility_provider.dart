import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/location_provider.dart';
import 'package:yu_map/services/facility_service.dart';

export 'package:yu_map/services/facility_service.dart' show FacilitySortBy;

// ── Opening hours utility ────────────────────────────────────────────────────
//
// OSM opening_hours 形式を解析し「現在営業中かどうか」を判定する。
//
// 対応フォーマット（よく見られるパターンのみ）:
//   24/7                           → 常時営業
//   10:00-22:00                    → 時間のみ（毎日）
//   Mo-Su 10:00-22:00              → 曜日レンジ + 時間
//   Mo-Fr 09:00-17:00; Sa 10:00-14:00  → セミコロン区切り複数ルール
//   22:00-02:00                    → 終夜営業（時間をまたぐ）
//
// 返り値:
//   true  → 現在営業中
//   false → 現在閉業中
//   null  → 判定不能（データなし / 未対応フォーマット）
//           → フィルタリング時は「営業中とみなして除外しない」として扱う

bool? checkOpenNow(String? hoursString) {
  if (hoursString == null || hoursString.trim().isEmpty) return null;
  final h = hoursString.trim();

  // 24時間営業
  if (RegExp(r'^24\s*/\s*7$').hasMatch(h)) return true;

  final now = DateTime.now();
  final weekday = now.weekday; // 1=月, 2=火, ..., 7=日
  final currentMinutes = now.hour * 60 + now.minute;

  // セミコロン区切りで複数ルールを持てる（例: "Mo-Fr 09:00-17:00; Sa 10:00-14:00"）
  final rules = h.split(';');
  for (final rawRule in rules) {
    final rule = rawRule.trim();
    if (rule.isEmpty) continue;

    // 時間範囲を探す: HH:MM-HH:MM（通常ハイフン）または HH:MM–HH:MM（em-dash）
    final timeMatch = RegExp(
      r'(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})',
    ).firstMatch(rule);

    if (timeMatch == null) continue;

    final openMinutes = _parseTimeMinutes(timeMatch.group(1)!);
    final closeMinutes = _parseTimeMinutes(timeMatch.group(2)!);
    if (openMinutes == null || closeMinutes == null) continue;

    // 現在時刻チェック。closeMinutes <= openMinutes は終夜営業（例: 22:00-02:00）
    final bool timeOk = closeMinutes <= openMinutes
        ? currentMinutes >= openMinutes || currentMinutes < closeMinutes
        : currentMinutes >= openMinutes && currentMinutes < closeMinutes;

    if (!timeOk) continue;

    // 時間は一致。曜日も確認する。
    final dayPart = rule.substring(0, timeMatch.start).trim();
    if (dayPart.isEmpty || _matchesDay(dayPart, weekday)) {
      return true; // このルールで営業中
    }
  }

  return false;
}

int? _parseTimeMinutes(String s) {
  final parts = s.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  // 深夜0時越えは最大29時表記を想定（例: 25:00）
  if (h == null || m == null || h > 29 || m > 59) return null;
  return h * 60 + m;
}

bool _matchesDay(String dayPart, int weekday) {
  const abbr = {
    'mo': 1, 'tu': 2, 'we': 3, 'th': 4, 'fr': 5, 'sa': 6, 'su': 7,
  };
  final d = dayPart.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  // "Mo-Fr" 形式のレンジ（最も一般的）
  final rangeMatch = RegExp(r'^([a-z]{2})-([a-z]{2})$').firstMatch(d);
  if (rangeMatch != null) {
    final from = abbr[rangeMatch.group(1)];
    final to = abbr[rangeMatch.group(2)];
    if (from != null && to != null) {
      return from <= to
          ? weekday >= from && weekday <= to
          : weekday >= from || weekday <= to; // 週をまたぐ（例: Sa-Mo）
    }
  }

  // "Mo,We,Fr" 形式のカンマ区切りリスト
  final listed = d
      .split(',')
      .map((s) => abbr[s.trim()])
      .whereType<int>()
      .toSet();
  if (listed.isNotEmpty) return listed.contains(weekday);

  // 単一曜日（例: "Sa"）
  final single = abbr[d];
  if (single != null) return single == weekday;

  return false;
}

// ── Service provider ────────────────────────────────────────────────────────

final facilityServiceProvider = Provider<FacilityService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return FacilityService(client);
});

// ── Search parameters ────────────────────────────────────────────────────────

class FacilitySearchParams {
  final String? searchQuery;
  final String? prefectureId;
  final String? facilityTypeId;
  final List<String> amenityIds;
  final double? latitude;
  final double? longitude;
  final double? radiusMeters;
  final int page;
  final FacilitySortBy sortBy;

  /// true のとき現在営業中の施設だけを表示する。
  /// DBではなくクライアント側で `openingHours` フィールドをパースしてフィルタリングする。
  /// `openingHours` が null / 解析不能な施設は「不明」として除外しない。
  final bool isOpenNow;

  const FacilitySearchParams({
    this.searchQuery,
    this.prefectureId,
    this.facilityTypeId,
    this.amenityIds = const [],
    this.latitude,
    this.longitude,
    this.radiusMeters,
    this.page = 0,
    this.sortBy = FacilitySortBy.qualityScore,
    this.isOpenNow = false,
  });

  FacilitySearchParams copyWith({
    String? searchQuery,
    String? prefectureId,
    String? facilityTypeId,
    List<String>? amenityIds,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    int? page,
    FacilitySortBy? sortBy,
    bool? isOpenNow,
    bool clearGeo = false,
    bool clearText = false,
    /// facilityTypeId を null にリセットしたい場合は true を渡す
    bool clearFacilityType = false,
    /// prefectureId を null にリセットしたい場合は true を渡す
    bool clearPrefecture = false,
  }) {
    return FacilitySearchParams(
      searchQuery: clearText ? null : searchQuery ?? this.searchQuery,
      prefectureId: clearPrefecture ? null : prefectureId ?? this.prefectureId,
      // clearFacilityType=true なら null、それ以外は渡した値 or 既存値
      facilityTypeId:
          clearFacilityType ? null : facilityTypeId ?? this.facilityTypeId,
      amenityIds: amenityIds ?? this.amenityIds,
      latitude: clearGeo ? null : latitude ?? this.latitude,
      longitude: clearGeo ? null : longitude ?? this.longitude,
      radiusMeters: clearGeo ? null : radiusMeters ?? this.radiusMeters,
      page: page ?? this.page,
      sortBy: sortBy ?? this.sortBy,
      isOpenNow: isOpenNow ?? this.isOpenNow,
    );
  }
}

/// 検索タブ用の施設絞り込みパラメーター。
/// テキスト検索・フィルター・ソートを管理する。
/// 地図画面の [mapSearchParamsProvider] とは独立している（Bug-V9-2対応）。
final facilitySearchParamsProvider =
    StateProvider<FacilitySearchParams>((ref) => const FacilitySearchParams());

/// 地図画面専用の施設絞り込みパラメーター。
/// 主に geo（緯度・経度・半径）と施設タイプフィルターを管理する。
/// 検索タブの [facilitySearchParamsProvider] とは独立しており、
/// 地図で設定したフィルターが検索タブに影響しないようにする（Bug-V9-2対応）。
final mapSearchParamsProvider =
    StateProvider<FacilitySearchParams>((ref) => const FacilitySearchParams());

// ── Facility list ────────────────────────────────────────────────────────────

/// 検索タブ用の施設一覧。[facilitySearchParamsProvider] を参照する。
final facilityListProvider =
    FutureProvider.autoDispose<List<Facility>>((ref) async {
  final service = ref.watch(facilityServiceProvider);
  if (service == null) return [];
  final params = ref.watch(facilitySearchParamsProvider);
  // 距離順ソートのとき DB ソートは品質順（全件取得後にクライアント側でソート）
  final dbSortBy = params.sortBy == FacilitySortBy.distance
      ? FacilitySortBy.qualityScore
      : params.sortBy;
  var results = await service.searchFacilities(
    searchQuery: params.searchQuery,
    prefectureId: params.prefectureId,
    facilityTypeId: params.facilityTypeId,
    amenityIds: params.amenityIds.isEmpty ? null : params.amenityIds,
    latitude: params.latitude,
    longitude: params.longitude,
    radiusMeters: params.radiusMeters,
    page: params.page,
    sortBy: dbSortBy,
  );
  // isOpenNow=true のとき、営業時間を解析して閉業中の施設を除外する。
  // openingHours が null / 解析不能（checkOpenNow==null）な施設は除外しない。
  if (params.isOpenNow) {
    results = results
        .where((f) => checkOpenNow(f.openingHours) != false)
        .toList();
  }
  // 距離順ソート: currentLocationProvider の現在地を使ってクライアント側で並べ替える。
  // 現在地が未取得の場合はソートしない（距離なし施設は末尾に）。
  if (params.sortBy == FacilitySortBy.distance) {
    final location = ref.read(currentLocationProvider);
    results.sort((a, b) {
      final da = computeDistanceKm(
        lat1: location?.lat,
        lon1: location?.lng,
        lat2: a.latitude,
        lon2: a.longitude,
      );
      final db = computeDistanceKm(
        lat1: location?.lat,
        lon1: location?.lng,
        lat2: b.latitude,
        lon2: b.longitude,
      );
      if (da == null && db == null) return 0;
      if (da == null) return 1;  // 距離不明は末尾
      if (db == null) return -1;
      return da.compareTo(db);
    });
  }
  return results;
});

/// 地図タブ用の施設一覧。[mapSearchParamsProvider] を参照する。
final mapFacilityListProvider =
    FutureProvider.autoDispose<List<Facility>>((ref) async {
  final service = ref.watch(facilityServiceProvider);
  if (service == null) return [];
  final params = ref.watch(mapSearchParamsProvider);
  var results = await service.searchFacilities(
    searchQuery: params.searchQuery,
    prefectureId: params.prefectureId,
    facilityTypeId: params.facilityTypeId,
    amenityIds: params.amenityIds.isEmpty ? null : params.amenityIds,
    latitude: params.latitude,
    longitude: params.longitude,
    radiusMeters: params.radiusMeters,
    page: params.page,
    sortBy: params.sortBy,
  );
  // isOpenNow=true のとき、営業時間を解析して閉業中の施設を除外する。
  if (params.isOpenNow) {
    results = results
        .where((f) => checkOpenNow(f.openingHours) != false)
        .toList();
  }
  return results;
});

// ── Facility detail ──────────────────────────────────────────────────────────

final facilityDetailProvider =
    FutureProvider.autoDispose.family<Facility?, String>((ref, id) async {
  final service = ref.watch(facilityServiceProvider);
  if (service == null) return null;
  return service.getFacilityById(id);
});

// ── Facility amenities ────────────────────────────────────────────────────────

/// 施設のアメニティ一覧を取得する。
/// facility_amenities テーブルと amenities テーブルを JOIN して
/// 「この施設にある設備・泉質」のリストを返す。
class FacilityAmenity {
  final String code;
  final String nameJa;
  final String category;

  const FacilityAmenity({
    required this.code,
    required this.nameJa,
    required this.category,
  });

  factory FacilityAmenity.fromJson(Map<String, dynamic> json) {
    final amenity = json['amenities'] as Map<String, dynamic>? ?? json;
    return FacilityAmenity(
      code: amenity['code'] as String? ?? '',
      nameJa: amenity['name_ja'] as String? ?? '',
      category: amenity['category'] as String? ?? '',
    );
  }
}

final facilityAmenitiesProvider =
    FutureProvider.autoDispose.family<List<FacilityAmenity>, String>(
        (ref, facilityId) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return [];
  try {
    final rows = await client
        .from('facility_amenities')
        .select('amenities(code, name_ja, category)')
        .eq('facility_id', facilityId)
        .eq('value', 'true') as List;
    return rows
        .map((r) => FacilityAmenity.fromJson(r as Map<String, dynamic>))
        .where((a) => a.nameJa.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
});

// ── Facility photos ───────────────────────────────────────────────────────────

/// 施設の写真 URL リスト（最新5枚）を取得する共有プロバイダー。
///
/// facility_preview_sheet と facility_detail_screen の両方で使う。
/// CODE-V13-1 修正: autoDispose を除去し、プレビューシート→詳細画面の遷移時に
/// キャッシュが破棄されて二重 API 呼び出しが発生する問題を解消する。
final facilityPhotosProvider =
    FutureProvider.family<List<String>, String>(
  (ref, facilityId) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return [];
    try {
      final rows = await client
          .from('photos')
          .select('storage_path, thumbnail_path')
          .eq('facility_id', facilityId)
          .order('created_at', ascending: false)
          .limit(5) as List;

      return rows.map((row) {
        final path = row['thumbnail_path'] as String? ??
            row['storage_path'] as String?;
        if (path == null || path.isEmpty) return '';
        return client.storage.from('photos').getPublicUrl(path);
      }).where((url) => url.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  },
);
