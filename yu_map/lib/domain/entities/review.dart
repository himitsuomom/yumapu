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
  final String? userName;
  final String? userAvatarUrl;
  final bool isPremium;

  const Review({
    required this.id,
    required this.userId,
    required this.facilityId,
    required this.content,
    required this.rating,
    this.likesCount = 0,
    required this.createdAt,
    this.userName,
    this.userAvatarUrl,
    this.isPremium = false,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    // Support both 'users' and 'profiles' JOIN keys from Supabase
    final userJoin = json['users'] as Map<String, dynamic>? ??
        json['profiles'] as Map<String, dynamic>? ??
        {};

    return Review(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      facilityId: json['facility_id'] as String,
      content: json['content'] as String,
      rating: json['rating'] as int,
      likesCount: json['likes_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: userJoin['display_name'] as String? ?? userJoin['username'] as String?,
      userAvatarUrl: userJoin['avatar_url'] as String?,
      isPremium: userJoin['is_premium'] as bool? ?? false,
    );
  }

  @override
  // content を含めることで、同IDでも本文が異なれば別オブジェクトとして扱われる
  List<Object?> get props => [id, userId, facilityId, content, rating, createdAt];
}
