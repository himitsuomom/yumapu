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
    this.currentTitle = '\u6e6f\u3081\u3050\u308a\u521d\u5fc3\u8005',
    this.rankPosition,
  });

  factory UserRanking.fromJson(Map<String, dynamic> json) {
    return UserRanking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      explorerPoints: json['explorer_points'] as int? ?? 0,
      socialPoints: json['social_points'] as int? ?? 0,
      totalPoints: json['total_points'] as int? ?? 0,
      currentTitle: json['current_title'] as String? ?? '\u6e6f\u3081\u3050\u308a\u521d\u5fc3\u8005',
      rankPosition: json['rank_position'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'explorer_points': explorerPoints,
      'social_points': socialPoints,
      'total_points': totalPoints,
      'current_title': currentTitle,
      'rank_position': rankPosition,
    };
  }

  UserRanking copyWith({
    String? id,
    String? userId,
    int? explorerPoints,
    int? socialPoints,
    int? totalPoints,
    String? currentTitle,
    int? rankPosition,
  }) {
    return UserRanking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      explorerPoints: explorerPoints ?? this.explorerPoints,
      socialPoints: socialPoints ?? this.socialPoints,
      totalPoints: totalPoints ?? this.totalPoints,
      currentTitle: currentTitle ?? this.currentTitle,
      rankPosition: rankPosition ?? this.rankPosition,
    );
  }

  @override
  List<Object?> get props => [id, userId, totalPoints, currentTitle, rankPosition];
}
