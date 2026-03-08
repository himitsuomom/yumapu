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

  factory Facility.fromJson(Map<String, dynamic> json) {
    // Handling PostGIS point if returned as GeoJSON or similar would require parsing.
    // Assuming simple lat/lng fields for now or adapter layer handles it.
    return Facility(
      id: json['id'] as String,
      name: json['name'] as String,
      nameKana: json['name_kana'] as String?,
      googlePlaceId: json['google_place_id'] as String?,
      prefectureId: json['prefecture_id'] as String?,
      facilityTypeId: json['facility_type_id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble() ??
          0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ??
          (json['lng'] as num?)?.toDouble() ??
          0.0,
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
