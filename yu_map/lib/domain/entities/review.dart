// lib/domain/entities/review.dart
import 'package:equatable/equatable.dart';

class Review extends Equatable {
  final String id;
  final String userId;
  final String facilityId;
  final String content;
  final int rating;
  final int likesCount;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.userId,
    required this.facilityId,
    required this.content,
    required this.rating,
    this.likesCount = 0,
    required this.createdAt,
  }) : assert(rating >= 1 && rating <= 5, 'Rating must be between 1 and 5');

  factory Review.fromJson(Map<String, dynamic> json) {
    final rawRating = json['rating'] as int;
    if (rawRating < 1 || rawRating > 5) {
      throw FormatException(
        'Invalid rating value: $rawRating. Must be between 1 and 5.',
      );
    }

    return Review(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      facilityId: json['facility_id'] as String,
      content: json['content'] as String? ?? '',
      rating: rawRating,
      likesCount: json['likes_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'facility_id': facilityId,
      'content': content,
      'rating': rating,
      'likes_count': likesCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Review copyWith({
    String? id,
    String? userId,
    String? facilityId,
    String? content,
    int? rating,
    int? likesCount,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      facilityId: facilityId ?? this.facilityId,
      content: content ?? this.content,
      rating: rating ?? this.rating,
      likesCount: likesCount ?? this.likesCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, facilityId, rating, createdAt];
}
