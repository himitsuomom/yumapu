// lib/providers/ranking_provider.dart
//
// ランキング機能のデータ管理
// user_rankings テーブルから取得し、users テーブルと JOIN して表示名・アバターを付加する

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/user_ranking.dart';
import 'package:yu_map/providers/auth_provider.dart';

// ── ランキングのソート種別 ──────────────────────────────────────────────────────

/// ランキング画面のソート切り替えに使う列挙型。
///
/// - [totalPoints]  : 合計PT（探索PT + 社交PT）。デフォルト
/// - [explorerPoints]: 探索PT（チェックイン数 × 100）
/// - [socialPoints] : 社交PT（レビュー × 50 + 投稿 × 30）
/// - [visitCount]   : 訪問数（純粋な訪問回数）
enum RankingSortBy {
  totalPoints,
  explorerPoints,
  socialPoints,
  visitCount,
}

extension RankingSortByExtension on RankingSortBy {
  /// DBカラム名に変換する
  String get column {
    switch (this) {
      case RankingSortBy.totalPoints:
        return 'total_points';
      case RankingSortBy.explorerPoints:
        return 'explorer_points';
      case RankingSortBy.socialPoints:
        return 'social_points';
      case RankingSortBy.visitCount:
        return 'visit_count';
    }
  }

  /// UIに表示するラベル
  String get label {
    switch (this) {
      case RankingSortBy.totalPoints:
        return '合計PT';
      case RankingSortBy.explorerPoints:
        return '探索PT';
      case RankingSortBy.socialPoints:
        return '社交PT';
      case RankingSortBy.visitCount:
        return '訪問数';
    }
  }

  /// ランキング行のトレーリングに表示する値を RankedUser から取り出す
  String trailingValue(RankedUser u) {
    switch (this) {
      case RankingSortBy.totalPoints:
        return '${u.ranking.totalPoints} PT';
      case RankingSortBy.explorerPoints:
        return '探索 ${u.ranking.explorerPoints} PT';
      case RankingSortBy.socialPoints:
        return '社交 ${u.ranking.socialPoints} PT';
      case RankingSortBy.visitCount:
        return '訪問 ${u.ranking.visitCount} 回';
    }
  }
}

// ── ランキングのソート種別を保持するProvider ──────────────────────────────────

/// ランキング画面で現在選択されているソート種別を保持するStateProvider。
///
/// ランキング画面の ChoiceChip がこの値を読み書きする。
/// rankingListProvider がこの値を watch することで、
/// 切り替えると即座にリストが再取得される。
final rankingSortByProvider = StateProvider<RankingSortBy>(
  (ref) => RankingSortBy.totalPoints,
);

// ── ランキング表示用モデル ─────────────────────────────────────────────────────

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

  /// user_rankings.user_id へのショートカット（フォロー機能などで使用）
  String get userId => ranking.userId;

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

// ── ランキングリストProvider ───────────────────────────────────────────────────

/// トップ50ランキングリスト（rankingSortByProvider が示す列で降順ソート）
///
/// rankingSortByProvider の値が変わると自動で再取得される。
final rankingListProvider =
    FutureProvider.autoDispose<List<RankedUser>>((ref) async {
  // ソート種別を watch → 値が変わると自動リビルド
  final sortBy = ref.watch(rankingSortByProvider);
  final client = ref.read(supabaseClientProvider);
  if (client == null) return [];
  try {
    final data = await client
        .from('user_rankings')
        .select('*, users(display_name, username, avatar_url)')
        .order(sortBy.column, ascending: false)
        .limit(50);
    return (data as List)
        .map((e) => RankedUser.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e, st) {
    // エラーをリスロー → ランキング画面の error ケースでリトライUI が表示される
    // 空リストを返すと「誰もいない」と誤認されるため、エラーとして伝播させる
    Error.throwWithStackTrace(e, st);
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
    return RankedUser.fromJson(data);
  } catch (e, st) {
    // エラーをリスロー → ランキング画面の自分の順位カードで error UI が表示される
    Error.throwWithStackTrace(e, st);
  }
});
