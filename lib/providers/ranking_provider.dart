// lib/providers/ranking_provider.dart
//
// ランキング機能のデータ管理
// user_rankings テーブルから取得し、users テーブルと JOIN して表示名・アバターを付加する

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/user_ranking.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// ランキング表示用の複合モデル
/// DB の user_rankings + users テーブルを JOIN した結果を保持する
class RankedUser {
  final UserRanking ranking;
  final String displayName;
  final String? avatarUrl;

  const RankedUser({
    required this.ranking,
    required this.displayName,
    this.avatarUrl,
  });

  factory RankedUser.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>?;
    final name = users?['display_name'] as String? ??
        users?['username'] as String? ??
        '湯めぐりユーザー';
    return RankedUser(
      ranking: UserRanking.fromJson(json),
      displayName: name,
      avatarUrl: users?['avatar_url'] as String?,
    );
  }
}

/// トップ50ランキングリスト（総得点降順）
final rankingListProvider =
    FutureProvider.autoDispose<List<RankedUser>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  if (client == null) return [];
  try {
    final data = await client
        .from('user_rankings')
        .select('*, users(display_name, username, avatar_url)')
        .order('total_points', ascending: false)
        .limit(50);
    return (data as List)
        .map((e) => RankedUser.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

/// 自分のランキングデータ（プロフィール画面・ランキング画面のマイポジション表示用）
final myRankingProvider =
    FutureProvider.autoDispose<RankedUser?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  final client = ref.read(supabaseClientProvider);
  if (client == null) return null;
  try {
    final data = await client
        .from('user_rankings')
        .select('*, users(display_name, username, avatar_url)')
        .eq('user_id', session.user.id)
        .maybeSingle();
    if (data == null) return null;
    return RankedUser.fromJson(data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});
