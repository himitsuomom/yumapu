// lib/domain/entities/facility.dart
import 'package:equatable/equatable.dart';

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
  final Map<String, dynamic> amenities;
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
    this.amenities = const {},
    this.dataSource = 'government',
    this.dataQualityScore = 1,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    // Support both 'lat'/'lng' (from RPC / PostGIS) and 'latitude'/'longitude' (from direct select)
    final lat = (json['latitude'] as num?)?.toDouble()
        ?? (json['lat'] as num?)?.toDouble()
        ?? 0.0;
    final lng = (json['longitude'] as num?)?.toDouble()
        ?? (json['lng'] as num?)?.toDouble()
        ?? 0.0;

    return Facility(
      id: json['id'] as String,
      name: json['name'] as String,
      nameKana: json['name_kana'] as String?,
      googlePlaceId: json['google_place_id'] as String?,
      prefectureId: json['prefecture_id'] as String?,
      facilityTypeId: json['facility_type_id'] as String?,
      latitude: lat,
      longitude: lng,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      businessHours: json['business_hours'] as Map<String, dynamic>? ?? {},
      priceInfo: json['price_info'] as Map<String, dynamic>? ?? {},
      amenities: json['amenities'] as Map<String, dynamic>? ?? {},
      dataSource: json['data_source'] as String? ?? 'government',
      dataQualityScore: json['data_quality_score'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_kana': nameKana,
      'google_place_id': googlePlaceId,
      'prefecture_id': prefectureId,
      'facility_type_id': facilityTypeId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'phone': phone,
      'website': website,
      'business_hours': businessHours,
      'price_info': priceInfo,
      'amenities': amenities,
      'data_source': dataSource,
      'data_quality_score': dataQualityScore,
    };
  }

  /// Creates a copy with optional field overrides.
  Facility copyWith({
    String? id,
    String? name,
    String? nameKana,
    String? googlePlaceId,
    String? prefectureId,
    String? facilityTypeId,
    double? latitude,
    double? longitude,
    String? address,
    String? phone,
    String? website,
    Map<String, dynamic>? businessHours,
    Map<String, dynamic>? priceInfo,
    Map<String, dynamic>? amenities,
    String? dataSource,
    int? dataQualityScore,
  }) {
    return Facility(
      id: id ?? this.id,
      name: name ?? this.name,
      nameKana: nameKana ?? this.nameKana,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      prefectureId: prefectureId ?? this.prefectureId,
      facilityTypeId: facilityTypeId ?? this.facilityTypeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      businessHours: businessHours ?? this.businessHours,
      priceInfo: priceInfo ?? this.priceInfo,
      amenities: amenities ?? this.amenities,
      dataSource: dataSource ?? this.dataSource,
      dataQualityScore: dataQualityScore ?? this.dataQualityScore,
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
        dataQualityScore,
      ];
}
