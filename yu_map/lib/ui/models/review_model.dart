// lib/ui/models/review_model.dart
import 'package:equatable/equatable.dart';
import 'package:image/image.dart' as img;

class ReviewModel extends Equatable {
  final String id;
  final String userId;
  final String facilityId;
  final String content;
  final int rating;
  final List<String> photoUrls;
  final List<img.Image> localPhotos;
  final int likesCount;
  final DateTime createdAt;
  final String userName;
  final String userAvatar;

  const ReviewModel({
    required this.id,
    required this.userId,
    required this.facilityId,
    required this.content,
    required this.rating,
    this.photoUrls = const [],
    this.localPhotos = const [],
    this.likesCount = 0,
    required this.createdAt,
    required this.userName,
    required this.userAvatar,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      facilityId: json['facility_id'] as String,
      content: json['content'] as String,
      rating: json['rating'] as int,
      photoUrls: List<String>.from(json['photo_urls'] ?? []),
      likesCount: json['likes_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['user_name'] as String? ?? '',
      userAvatar: json['user_avatar'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'facility_id': facilityId,
      'content': content,
      'rating': rating,
      'photo_urls': photoUrls,
      'likes_count': likesCount,
      'created_at': createdAt.toIso8601String(),
      'user_name': userName,
      'user_avatar': userAvatar,
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        facilityId,
        content,
        rating,
        photoUrls,
        localPhotos,
        likesCount,
        createdAt,
        userName,
        userAvatar,
      ];
}