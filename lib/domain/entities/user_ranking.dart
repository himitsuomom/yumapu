// lib/domain/entities/user_ranking.dart
import 'package:equatable/equatable.dart';

class UserRanking extends Equatable {
  final String id;
  final String userId;
  final int explorerPoints;
  final int socialPoints;
  final int totalPoints;
  final String currentTitle;
  final int? rankPosition;

  const UserRanking({
    required this.id,
    required this.userId,
    this.explorerPoints = 0,
    this.socialPoints = 0,
    this.totalPoints = 0,
    // TODO: Extract to AppLocalizations when UI layer is created
    // Use AppLocalizations.of(context)!.userRankingTitleBeginner
    this.currentTitle = '湯めぐり初心者',
    this.rankPosition,
  });

  factory UserRanking.fromJson(Map<String, dynamic> json) {
    return UserRanking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      explorerPoints: json['explorer_points'] as int? ?? 0,
      socialPoints: json['social_points'] as int? ?? 0,
      totalPoints: json['total_points'] as int? ?? 0,
      // TODO: Extract to AppLocalizations when UI layer is created
      currentTitle: json['current_title'] as String? ?? '湯めぐり初心者',
      rankPosition: json['rank_position'] as int?,
    );
  }

  @override
  List<Object?> get props => [id, userId, totalPoints, currentTitle, rankPosition];
}
