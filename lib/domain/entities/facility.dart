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
      facilityType: json['facility_type'] as String?,
      latitude: lat,
      longitude: lng,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      businessHours: json['business_hours'] as Map<String, dynamic>? ?? {},
      priceInfo: json['price_info'] as Map<String, dynamic>? ?? {},
      dataSource: json['data_source'] as String? ?? 'government',
      dataQualityScore: (json['data_quality_score'] as num?)?.toInt() ?? 1,
    );
  }

  /// Returns false when both coordinates are 0.0 (data missing).
  /// Always check this before placing a map marker.
  bool get hasValidLocation => latitude != 0.0 || longitude != 0.0;

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
