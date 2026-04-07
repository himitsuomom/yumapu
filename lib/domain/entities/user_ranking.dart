import 'package:equatable/equatable.dart';

class UserRanking extends Equatable {
  final String id;
  final String userId;
  final int explorerPoints;
  final int visitCount;
  final int contributionCount;
  final int socialPoints;
  final int reviewCount;
  final int photoCount;
  final int likesReceived;
  final int totalPoints;
  final String currentTitle;
  final int? rankPosition;

  const UserRanking({
    required this.id,
    required this.userId,
    this.explorerPoints = 0,
    this.visitCount = 0,
    this.contributionCount = 0,
    this.socialPoints = 0,
    this.reviewCount = 0,
    this.photoCount = 0,
    this.likesReceived = 0,
    this.totalPoints = 0,
    this.currentTitle = '湯めぐり初心者',
    this.rankPosition,
  });

  factory UserRanking.fromJson(Map<String, dynamic> json) {
    return UserRanking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      explorerPoints: json['explorer_points'] as int? ?? 0,
      visitCount: json['visit_count'] as int? ?? 0,
      contributionCount: json['contribution_count'] as int? ?? 0,
      socialPoints: json['social_points'] as int? ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      photoCount: json['photo_count'] as int? ?? 0,
      likesReceived: json['likes_received'] as int? ?? 0,
      totalPoints: json['total_points'] as int? ?? 0,
      currentTitle: json['current_title'] as String? ?? '湯めぐり初心者',
      rankPosition: json['rank_position'] as int?,
    );
  }

  @override
  List<Object?> get props => [id, userId, totalPoints, currentTitle, rankPosition];
}
