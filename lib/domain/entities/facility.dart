// lib/domain/entities/facility.dart
//
// ⚠️ このファイルが Facility の唯一の正式定義です。
// lib/models/facility.dart は削除済みです。
// すべての参照はこのパスを使ってください:
//   import 'package:yu_map/domain/entities/facility.dart';

import 'package:equatable/equatable.dart';

// デフォルト座標（東京中心）
const _kDefaultLat = 35.6812;
const _kDefaultLng = 139.7671;

class Facility extends Equatable {
  // ── コアID ──────────────────────────────────────────────────────────
  final String id;
  final String name;
  final String? nameKana;

  // ── 位置情報 ─────────────────────────────────────────────────────────
  final double latitude;
  final double longitude;
  final String address;

  // ── タイプ & 料金 ──────────────────────────────────────────────────
  /// 施設タイプ slug（'sauna' / 'onsen' / 'supersento' / 'public_bath'）
  final String type;

  /// 大人入浴料（円）
  final int price;

  // ── 評価 & 営業状態 ───────────────────────────────────────────────
  final double rating;
  final int reviewCount;
  final bool isOpen;

  // ── 連絡先 & 営業情報 ─────────────────────────────────────────────
  final String phone;
  final String hours;
  final String holiday;
  final String? website;

  // ── アメニティ ───────────────────────────────────────────────────
  /// DB の amenities JSONB カラムに対応。
  /// キーは core/config/amenity_config.dart の AmenityDef.key と一致。
  final Map<String, bool> amenities;

  // ── ドメイン層フィールド（クリーンアーキテクチャ用） ─────────────
  final String? googlePlaceId;
  final String? prefectureId;
  final String? facilityTypeId;
  final Map<String, dynamic> businessHours;
  final Map<String, dynamic> priceInfo;
  final String dataSource;
  final int dataQualityScore;

  // ── レガシー（互換性維持のみ）────────────────────────────────────
  /// マップ上の相対X位置（0.0〜1.0）。新規コードでは使用しないこと。
  final double x;

  /// マップ上の相対Y位置（0.0〜1.0）。新規コードでは使用しないこと。
  final double y;

  const Facility({
    required this.id,
    required this.name,
    this.nameKana,
    this.latitude = _kDefaultLat,
    this.longitude = _kDefaultLng,
    this.address = '',
    this.type = 'unknown',
    this.price = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isOpen = false,
    this.phone = '',
    this.hours = '',
    this.holiday = '',
    this.website,
    this.amenities = const {},
    this.googlePlaceId,
    this.prefectureId,
    this.facilityTypeId,
    this.businessHours = const {},
    this.priceInfo = const {},
    this.dataSource = 'user',
    this.dataQualityScore = 1,
    this.x = 0.5,
    this.y = 0.5,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '施設名不明',
      nameKana: json['name_kana'] as String?,
      // 'latitude'/'longitude' と 'lat'/'lng' 両スキーマに対応
      latitude: (json['latitude'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble() ??
          _kDefaultLat,
      longitude: (json['longitude'] as num?)?.toDouble() ??
          (json['lng'] as num?)?.toDouble() ??
          _kDefaultLng,
      address: json['address'] as String? ?? '',
      type: json['type'] as String? ??
          json['facility_type_id'] as String? ??
          'unknown',
      price: (json['price'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      isOpen: json['is_open'] as bool? ?? false,
      phone: json['phone'] as String? ?? '',
      hours: json['hours'] as String? ?? '',
      holiday: json['holiday'] as String? ?? '',
      website: json['website'] as String?,
      amenities: json['amenities'] != null
          ? Map<String, bool>.from(json['amenities'] as Map)
          : {},
      googlePlaceId: json['google_place_id'] as String?,
      prefectureId: json['prefecture_id'] as String?,
      facilityTypeId: json['facility_type_id'] as String?,
      businessHours:
          json['business_hours'] as Map<String, dynamic>? ?? {},
      priceInfo: json['price_info'] as Map<String, dynamic>? ?? {},
      dataSource: json['data_source'] as String? ?? 'user',
      dataQualityScore:
          (json['data_quality_score'] as num?)?.toInt() ?? 1,
      x: (json['x_coordinate'] as num?)?.toDouble() ?? 0.5,
      y: (json['y_coordinate'] as num?)?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'name_kana': nameKana,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'type': type,
        'price': price,
        'rating': rating,
        'review_count': reviewCount,
        'is_open': isOpen,
        'phone': phone,
        'hours': hours,
        'holiday': holiday,
        'website': website,
        'amenities': amenities,
        'google_place_id': googlePlaceId,
        'prefecture_id': prefectureId,
        'facility_type_id': facilityTypeId,
        'business_hours': businessHours,
        'price_info': priceInfo,
        'data_source': dataSource,
        'data_quality_score': dataQualityScore,
        'x_coordinate': x,
        'y_coordinate': y,
      };

  Facility copyWith({
    String? id,
    String? name,
    String? nameKana,
    double? latitude,
    double? longitude,
    String? address,
    String? type,
    int? price,
    double? rating,
    int? reviewCount,
    bool? isOpen,
    String? phone,
    String? hours,
    String? holiday,
    String? website,
    Map<String, bool>? amenities,
    String? googlePlaceId,
    String? prefectureId,
    String? facilityTypeId,
    Map<String, dynamic>? businessHours,
    Map<String, dynamic>? priceInfo,
    String? dataSource,
    int? dataQualityScore,
    double? x,
    double? y,
  }) {
    return Facility(
      id: id ?? this.id,
      name: name ?? this.name,
      nameKana: nameKana ?? this.nameKana,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      type: type ?? this.type,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isOpen: isOpen ?? this.isOpen,
      phone: phone ?? this.phone,
      hours: hours ?? this.hours,
      holiday: holiday ?? this.holiday,
      website: website ?? this.website,
      amenities: amenities ?? this.amenities,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      prefectureId: prefectureId ?? this.prefectureId,
      facilityTypeId: facilityTypeId ?? this.facilityTypeId,
      businessHours: businessHours ?? this.businessHours,
      priceInfo: priceInfo ?? this.priceInfo,
      dataSource: dataSource ?? this.dataSource,
      dataQualityScore: dataQualityScore ?? this.dataQualityScore,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        latitude,
        longitude,
        type,
        price,
        rating,
        isOpen,
        amenities,
      ];
}
