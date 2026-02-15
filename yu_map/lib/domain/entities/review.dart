// lib/domain/entities/review.dart
import 'package:equatable/equatable.dart';
import '../../models/photo_model.dart';

class Review extends Equatable {
  final String id;
  final String userId;
  final String facilityId;
  final String content;
  final int rating;
  final List<LocalPhoto> photos;
  final int likesCount;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.userId,
    required this.facilityId,
    required this.content,
    required this.rating,
    this.likesCount = 0,
    this.photos = const [],
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      facilityId: json['facility_id'] as String,
      content: json['content'] as String,
      rating: json['rating'] as int,
      likesCount: json['likes_count'] as int? ?? 0,
      photos: [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Review copyWith({
    String? id,
    String? userId,
    String? facilityId,
    String? content,
    int? rating,
    List<LocalPhoto>? photos,
    int? likesCount,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      facilityId: facilityId ?? this.facilityId,
      content: content ?? this.content,
      rating: rating ?? this.rating,
      photos: photos ?? this.photos,
      likesCount: likesCount ?? this.likesCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, facilityId, rating, photos, createdAt];
}
