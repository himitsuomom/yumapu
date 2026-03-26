// lib/domain/entities/facility.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class Facility extends Equatable {
  final String id;
  final String name;
  final String? nameKana;
  final String? googlePlaceId;
  final String? prefectureId;
  final String? facilityTypeId;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  final String? website;
  final Map<String, dynamic> businessHours;
  final Map<String, dynamic> priceInfo;
  final String dataSource;
  final int dataQualityScore;

  const Facility({
    required this.id,
    required this.name,
    this.nameKana,
    this.googlePlaceId,
    this.prefectureId,
    this.facilityTypeId,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
    this.website,
    this.businessHours = const {},
    this.priceInfo = const {},
    this.dataSource = 'government',
    this.dataQualityScore = 1,
  });

  /// 有効な座標を持つかどうか。
  bool get hasValidLocation => latitude != 0.0 || longitude != 0.0;

  factory Facility.fromJson(Map<String, dynamic> json) {
    double parseLat() {
      if (json['latitude'] != null) return (json['latitude'] as num).toDouble();
      if (json['lat'] != null) return (json['lat'] as num).toDouble();
      debugPrint('[Facility.fromJson] WARNING: latitude missing for id="${json['id']}"');
      return 0.0;
    }

    double parseLng() {
      if (json['longitude'] != null) return (json['longitude'] as num).toDouble();
      if (json['lng'] != null) return (json['lng'] as num).toDouble();
      debugPrint('[Facility.fromJson] WARNING: longitude missing for id="${json['id']}"');
      return 0.0;
    }

    return Facility(
      id: json['id'] as String,
      name: json['name'] as String,
      nameKana: json['name_kana'] as String?,
      googlePlaceId: json['google_place_id'] as String?,
      prefectureId: json['prefecture_id'] as String?,
      facilityTypeId: json['facility_type_id'] as String?,
      latitude: parseLat(),
      longitude: parseLng(),
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      businessHours: json['business_hours'] as Map<String, dynamic>? ?? {},
      priceInfo: json['price_info'] as Map<String, dynamic>? ?? {},
      dataSource: json['data_source'] as String? ?? 'government',
      dataQualityScore: json['data_quality_score'] as int? ?? 1,
    );
  }

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
        dataQualityScore
      ];
}
