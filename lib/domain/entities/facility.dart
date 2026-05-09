import 'package:equatable/equatable.dart';

/// Facility entity aligned with the `facilities` DB table and the
/// `get_facilities_in_bounds` RPC response.
///
/// Two coordinate formats are supported:
///   - Table direct query: `latitude` / `longitude`
///   - RPC response:       `lat` / `lng`
class Facility extends Equatable {
  final String id;
  final String name;
  final String? nameKana;
  final String? googlePlaceId;
  final String? prefectureId;
  final String? facilityTypeId;

  /// Facility type code from `facility_types.code` (e.g. 'onsen', 'sauna').
  /// Populated when fetched via the RPC or with a JOIN; null otherwise.
  final String? facilityType;

  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  final String? website;
  final Map<String, dynamic> businessHours;
  final Map<String, dynamic> priceInfo;

  /// OSM の opening_hours 形式の営業時間テキスト（例: "Mo-Fr 10:00-21:00"）。
  /// データがない施設では null になる。
  final String? openingHours;

  /// 入浴料金（円）。0 または null の場合は「不明」として扱う。
  final int? price;

  final String dataSource;
  final int dataQualityScore;

  const Facility({
    required this.id,
    required this.name,
    this.nameKana,
    this.googlePlaceId,
    this.prefectureId,
    this.facilityTypeId,
    this.facilityType,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
    this.website,
    this.businessHours = const {},
    this.priceInfo = const {},
    this.openingHours,
    this.price,
    this.dataSource = 'government',
    this.dataQualityScore = 1,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    // Handle both table query (latitude/longitude) and RPC (lat/lng).
    final lat = (json['latitude'] as num?)?.toDouble() ??
        (json['lat'] as num?)?.toDouble() ??
        0.0;
    final lng = (json['longitude'] as num?)?.toDouble() ??
        (json['lng'] as num?)?.toDouble() ??
        0.0;

    return Facility(
      id: json['id'] as String,
      name: json['name'] as String,
      nameKana: json['name_kana'] as String?,
      googlePlaceId: json['google_place_id'] as String?,
      prefectureId: json['prefecture_id'] as String?,
      facilityTypeId: json['facility_type_id'] as String?,
      // RPC は facility_type（code文字列）、テーブルクエリは
      // facility_types(code) のネストオブジェクトで返る。両方を対応する。
      facilityType: json['facility_type'] as String? ??
          (json['facility_types'] as Map<String, dynamic>?)?['code'] as String?,
      latitude: lat,
      longitude: lng,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      businessHours: json['business_hours'] as Map<String, dynamic>? ?? {},
      priceInfo: json['price_info'] as Map<String, dynamic>? ?? {},
      // hours は OSM の opening_hours 形式（例: "Mo-Fr 10:00-21:00"）
      openingHours: (json['hours'] as String?)?.trim().isEmpty == true
          ? null
          : json['hours'] as String?,
      price: (json['price'] as num?)?.toInt(),
      dataSource: json['data_source'] as String? ?? 'government',
      dataQualityScore: (json['data_quality_score'] as num?)?.toInt() ?? 1,
    );
  }

  /// Returns false when both coordinates are 0.0 (data missing).
  /// Always check this before placing a map marker.
  bool get hasValidLocation => latitude != 0.0 || longitude != 0.0;

  /// OSM の施設名は "草津温泉;Kusatsu Onsen" のように ; 区切りで複数言語が入ることがある。
  /// 表示用には先頭の名前だけを使う。DB への書き込みや検索では生の name を保持する。
  String get displayName => name.split(';').first.trim();

  /// facility_types.code を日本語表示名に変換する。
  /// DB の code は英語（'onsen', 'public_bath', 'sauna'）なので
  /// ユーザー向けには日本語名を使う。
  String get facilityTypeJa {
    switch (facilityType?.toLowerCase()) {
      case 'onsen':
        return '温泉施設';
      case 'public_bath':
        return '銭湯・公衆浴場';
      case 'sauna':
        return 'サウナ';
      default:
        return facilityType ?? '';
    }
  }

  /// facilityTypeJa が空でなければ true。
  bool get hasFacilityType =>
      facilityType != null && facilityType!.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        name,
        nameKana,
        googlePlaceId,
        prefectureId,
        facilityTypeId,
        latitude,
        longitude,
        dataQualityScore,
      ];
}
