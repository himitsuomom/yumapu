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

  /// Author metadata — populated when reviews are fetched with a user join.
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final bool authorIsPremium;

  const Review({
    required this.id,
    required this.userId,
    required this.facilityId,
    required this.content,
    required this.rating,
    this.likesCount = 0,
    required this.createdAt,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.authorIsPremium = false,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    // When fetched with a join (e.g. `select('*, users(*)')`), author data
    // lives under a nested `users` key.
    final userMap = json['users'] as Map<String, dynamic>?;

    return Review(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      facilityId: json['facility_id'] as String,
      content: json['content'] as String,
      rating: json['rating'] as int,
      likesCount: json['likes_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorDisplayName:
          userMap?['display_name'] as String? ?? userMap?['username'] as String?,
      authorAvatarUrl: userMap?['avatar_url'] as String?,
      authorIsPremium: userMap?['is_premium'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, userId, facilityId, rating, createdAt];
}
