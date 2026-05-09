import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/domain/entities/facility.dart';

/// 検索結果のソート順。
///
/// - [qualityScore]: データ品質スコア降順（デフォルト）
/// - [name]: 施設名のよみがな昇順（あいうえお順）
/// - [distance]: 現在地から近い順（クライアント側でソート）
enum FacilitySortBy { qualityScore, name, distance }

/// Handles all facility queries against Supabase.
///
/// Injected with a [SupabaseClient] so it can be mocked in tests.
/// Uses a `Map<String, dynamic>` cache keyed by facility ID.
class FacilityService {
  FacilityService(this._client);

  final SupabaseClient _client;

  // Raw JSON rows keyed by facility ID. Updated incrementally; never
  // cleared in full so that detail lookups survive between searches.
  final Map<String, dynamic> _cache = {};

  /// Unmodifiable view of the raw-row cache.
  Map<String, dynamic> get cache => Map.unmodifiable(_cache);

  // ── Public API ──────────────────────────────────────────────────────

  /// Search facilities.
  ///
  /// When [latitude], [longitude], and [radiusMeters] are provided the query
  /// delegates to the PostGIS RPC `get_facilities_in_bounds`.
  /// Otherwise a regular table query is built by chaining filters onto
  /// `var query` so that no filter is ever discarded.
  Future<List<Facility>> searchFacilities({
    String? searchQuery,
    String? prefectureId,
    String? facilityTypeId,
    List<String>? amenityIds,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    int page = 0,
    FacilitySortBy sortBy = FacilitySortBy.qualityScore,
  }) async {
    if (latitude != null && longitude != null && radiusMeters != null) {
      var results = await _searchByBounds(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        amenityIds: amenityIds,
        facilityTypeId: facilityTypeId,
        facilityLimit: AppConstants.pageSize,
      );
      // Bug-V12-1修正: bounds 検索は RPC 側でテキストフィルターを持たないため、
      // searchQuery がある場合はクライアント側で名前・住所の部分一致フィルターを適用する。
      // 例: 地図上で「草津」と入力すると、現在の表示範囲内の施設を
      //     名前/住所に"草津"を含むものだけに絞り込む。
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        results = results.where((f) {
          // displayName（;区切り前の表示名）と生の name 両方を検索対象にする。
          // これにより「草津温泉」で検索したとき、name が "草津温泉;Kusatsu Onsen"
          // の施設も正しくマッチする。
          final nameMatch = f.displayName.toLowerCase().contains(q) ||
              f.name.toLowerCase().contains(q);
          final addressMatch = (f.address ?? '').toLowerCase().contains(q);
          return nameMatch || addressMatch;
        }).toList();
      }
      return results;
    }

    // facility_types をネスト取得して facilityType（code）も一緒に返す
    var query = _client.from('facilities').select(
          'id, name, name_kana, latitude, longitude, address, phone, '
          'website, prefecture_id, facility_type_id, '
          'facility_types(code), '
          'business_hours, price_info, data_source, data_quality_score',
        );

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      // UX-V7-2: 施設名だけでなく住所（エリア・地名）でも検索できるように or() フィルターを使用。
      // 例: 「草津」→ 施設名「草津温泉○○」や住所「群馬県吾妻郡草津町」の両方にマッチする。
      final q = searchQuery.trim();
      query = query.or('name.ilike.%$q%,address.ilike.%$q%');
    }
    if (prefectureId != null) {
      query = query.eq('prefecture_id', prefectureId);
    }
    if (facilityTypeId != null) {
      query = query.eq('facility_type_id', facilityTypeId);
    }

    final from = page * AppConstants.pageSize;
    final to = from + AppConstants.pageSize - 1;

    // ソート順をパラメータで切り替える
    // qualityScore: データ品質の高い施設を上に（降順）
    // name: よみがな（name_kana）のあいうえお順（昇順）
    final sortField = sortBy == FacilitySortBy.name ? 'name_kana' : 'data_quality_score';
    final ascending = sortBy == FacilitySortBy.name;

    final rows = await query
        .order(sortField, ascending: ascending)
        .range(from, to) as List;

    if (amenityIds != null && amenityIds.isNotEmpty) {
      return _filterByAmenities(rows, amenityIds);
    }

    _updateCache(rows);
    return rows.map((r) => Facility.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Fetch a single facility by ID.
  ///
  /// Returns the cached value when available to avoid a round-trip.
  Future<Facility?> getFacilityById(String id) async {
    if (_cache.containsKey(id)) {
      return Facility.fromJson(_cache[id] as Map<String, dynamic>);
    }
    try {
      final row = await _client
          .from('facilities')
          .select(
            'id, name, name_kana, latitude, longitude, address, phone, '
            'website, prefecture_id, facility_type_id, '
            'facility_types(code), '
            'business_hours, price_info, hours, price, '
            'data_source, data_quality_score',
          )
          .eq('id', id)
          .single();
      _cache[id] = row;
      return Facility.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// 複数の施設を ID リストで一括取得する（N+1 防止）。
  ///
  /// Supabase の `inFilter` を使って1回のクエリで全施設を取得する。
  /// [ids] の順序を維持して返す（取得できなかった施設は除外）。
  Future<List<Facility>> getFacilitiesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    // キャッシュで全件解決できる場合は DB アクセスなし
    final cached = ids
        .map((id) => _cache.containsKey(id)
            ? Facility.fromJson(_cache[id] as Map<String, dynamic>)
            : null)
        .whereType<Facility>()
        .toList();
    if (cached.length == ids.length) {
      // ids の順序を維持する
      final cachedMap = {for (final f in cached) f.id: f};
      return ids.map((id) => cachedMap[id]).whereType<Facility>().toList();
    }

    try {
      final rows = await _client
          .from('facilities')
          .select(
            'id, name, name_kana, latitude, longitude, address, phone, '
            'website, prefecture_id, facility_type_id, '
            'facility_types(code), '
            'business_hours, price_info, hours, price, '
            'data_source, data_quality_score',
          )
          .inFilter('id', ids) as List;
      _updateCache(rows);
      // DB から返ってくる順序は不定なので ids の順に並べ直す
      final rowMap = <String, Map<String, dynamic>>{};
      for (final r in rows) {
        final m = r as Map<String, dynamic>;
        rowMap[m['id'] as String] = m;
      }
      return ids
          .where((id) => rowMap.containsKey(id))
          .map((id) => Facility.fromJson(rowMap[id]!))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Remove a single entry from the cache (e.g. after a user edit).
  void evict(String facilityId) => _cache.remove(facilityId);

  /// Clear the entire cache.
  void clearCache() => _cache.clear();

  // ── Private helpers ─────────────────────────────────────────────────

  /// lat/lng の BETWEEN を使った高速バウンディングボックス検索 RPC を呼ぶ。
  /// （PostGIS の ST_Within から lat/lng カラム直接参照に変更済み）
  Future<List<Facility>> _searchByBounds({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    List<String>? amenityIds,
    String? facilityTypeId,
    int facilityLimit = 500,
  }) async {
    final radiusDeg = radiusMeters / 111000.0;
    final rows = await _client.rpc(
      'get_facilities_in_bounds',
      params: {
        'min_lat': latitude - radiusDeg,
        'min_lng': longitude - radiusDeg / 0.7,
        'max_lat': latitude + radiusDeg,
        'max_lng': longitude + radiusDeg / 0.7,
        'filter_amenities':
            (amenityIds != null && amenityIds.isNotEmpty) ? amenityIds : null,
        'facility_limit': facilityLimit,
        'filter_facility_type': facilityTypeId,
      },
    ) as List;

    _updateCache(rows);
    return rows.map((r) => Facility.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Post-filters a list of raw rows to keep only those that have ALL of
  /// the requested amenity IDs in `facility_amenities`.
  Future<List<Facility>> _filterByAmenities(
    List<dynamic> rows,
    List<String> amenityIds,
  ) async {
    if (rows.isEmpty) return [];

    final facilityIds = rows.map((r) => r['id'] as String).toList();
    final amenityRows = await _client
        .from('facility_amenities')
        .select('facility_id, amenity_id')
        .inFilter('facility_id', facilityIds)
        .inFilter('amenity_id', amenityIds) as List;

    // Build a map of facilityId → set of matched amenity IDs.
    final Map<String, Set<String>> facilityAmenities = {};
    for (final row in amenityRows) {
      final fid = row['facility_id'] as String;
      final aid = row['amenity_id'] as String;
      facilityAmenities.putIfAbsent(fid, () => {}).add(aid);
    }

    final required = amenityIds.toSet();
    final filtered = rows.where((row) {
      final has = facilityAmenities[row['id'] as String] ?? const <String>{};
      return has.containsAll(required);
    }).toList();

    _updateCache(filtered);
    return filtered.map((r) => Facility.fromJson(r as Map<String, dynamic>)).toList();
  }

  void _updateCache(List<dynamic> rows) {
    for (final row in rows) {
      _cache[row['id'] as String] = row;
    }
  }
}
