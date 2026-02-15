// lib/providers/user_providers.dart
//
// User-related state providers for profile, ranking, stats.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/user_ranking.dart';
import 'package:yu_map/providers/service_providers.dart';

/// Ranking for a specific user.
final userRankingProvider =
    FutureProvider.family<UserRanking?, String>((ref, userId) async {
  final userService = ref.watch(userServiceProvider);
  return userService.getUserRanking(userId);
});

/// Visit count for a specific user.
final userVisitCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final userService = ref.watch(userServiceProvider);
  return userService.getVisitCount(userId);
});

/// Review count for a specific user.
final userReviewCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final userService = ref.watch(userServiceProvider);
  return userService.getReviewCount(userId);
});

/// Global leaderboard.
final leaderboardProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userService = ref.watch(userServiceProvider);
  return userService.getLeaderboard();
});
