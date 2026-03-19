// lib/models/facility.dart

class Facility {
  final String id;
  final String name;
  final String type;
  final int price;
  final double rating;
  final int reviewCount;
  final bool isOpen;
  final String address;
  final String phone;
  final String hours;
  final String holiday;
  final double x; // マップ上の相対X位置 (0.0 ~ 1.0)
  final double y; // マップ上の相対Y位置 (0.0 ~ 1.0)
  final Map<String, bool> amenities;

  Facility({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.isOpen,
    required this.address,
    required this.phone,
    required this.hours,
    required this.holiday,
    required this.x,
    required this.y,
    required this.amenities,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      price: json['price'] as int,
      rating: (json['rating'] as num).toDouble(),
      reviewCount: json['review_count'] as int,
      isOpen: json['is_open'] as bool,
      address: json['address'] as String,
      phone: json['phone'] as String,
      hours: json['hours'] as String,
      holiday: json['holiday'] as String,
      x: (json['x_coordinate'] as num).toDouble(),
      y: (json['y_coordinate'] as num).toDouble(),
      amenities: Map<String, bool>.from(json['amenities'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'price': price,
      'rating': rating,
      'review_count': reviewCount,
      'is_open': isOpen,
      'address': address,
      'phone': phone,
      'hours': hours,
      'holiday': holiday,
      'x_coordinate': x,
      'y_coordinate': y,
      'amenities': amenities,
    };
  }

  Facility copyWith({
    String? id,
    String? name,
    String? type,
    int? price,
    double? rating,
    int? reviewCount,
    bool? isOpen,
    String? address,
    String? phone,
    String? hours,
    String? holiday,
    double? x,
    double? y,
    Map<String, bool>? amenities,
  }) {
    return Facility(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isOpen: isOpen ?? this.isOpen,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      hours: hours ?? this.hours,
      holiday: holiday ?? this.holiday,
      x: x ?? this.x,
      y: y ?? this.y,
      amenities: amenities ?? this.amenities,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Facility &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          price == other.price &&
          rating == other.rating &&
          reviewCount == other.reviewCount &&
          isOpen == other.isOpen &&
          address == other.address &&
          phone == other.phone &&
          hours == other.hours &&
          holiday == other.holiday &&
          x == other.x &&
          y == other.y &&
          amenities == other.amenities;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      type.hashCode ^
      price.hashCode ^
      rating.hashCode ^
      reviewCount.hashCode ^
      isOpen.hashCode ^
      address.hashCode ^
      phone.hashCode ^
      hours.hashCode ^
      holiday.hashCode ^
      x.hashCode ^
      y.hashCode ^
      amenities.hashCode;
}
