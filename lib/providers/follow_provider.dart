// lib/providers/follow_provider.dart
//
// フォロー/フォロワー機能のデータ管理
//
// 用語説明:
//   follower  = フォローしている人（自分）
//   following = フォローされている人（相手）
//
// 提供するプロバイダー:
//   followingIdsProvider     — 自分がフォロー中のユーザーIDセット
//   isFollowingProvider      — 特定ユーザーをフォロー中かどうか
//   followCountsProvider     — あるユーザーのフォロワー数・フォロー中数

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/providers/auth_provider.dart';

// ────────────────────────────────────────────────────────────────────────────
// 自分がフォロー中のユーザーIDセットを管理する StateNotifier
// ────────────────────────────────────────────────────────────────────────────

/// 自分がフォローしているユーザーIDの集合（Set）を保持するプロバイダー
///
/// Set を使う理由: フォロー済みかの判定が O(1) で高速。
/// フォロー/アンフォロー時に楽観的UI更新（画面を即時更新）を行う。
class FollowingNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  FollowingNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final client = _ref.read(supabaseClientProvider);
    final session = _ref.read(sessionProvider);
    if (client == null || session == null) {
      state = const AsyncData({});
      return;
    }

    try {
      // 自分がフォローしているユーザーのIDを全件取得
      final data = await client
          .from('user_follows')
          .select('following_id')
          .eq('follower_id', session.user.id);

      final ids = (data as List)
          .map((e) => e['following_id'] as String)
          .toSet();
      state = AsyncData(ids);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// フォロー処理（楽観的UI更新 + DB書き込み）
  ///
  /// 楽観的UI更新 = ボタンを押した瞬間に画面を変え、DB処理は裏で行う。
  /// 失敗したら元に戻す（ロールバック）。
  Future<void> follow(String targetUserId) async {
    final client = _ref.read(supabaseClientProvider);
    final session = _ref.read(sessionProvider);
    if (client == null || session == null) return;

    final current = state.valueOrNull ?? {};
    if (current.contains(targetUserId)) return; // すでにフォロー中

    // 楽観的UI更新: 画面を即時更新
    state = AsyncData({...current, targetUserId});

    try {
      await client.from('user_follows').insert({
        'follower_id':  session.user.id,
        'following_id': targetUserId,
      });
    } catch (_) {
      // DB書き込み失敗: ロールバック
      state = AsyncData(current);
      rethrow;
    }
  }

  /// アンフォロー処理（楽観的UI更新 + DB削除）
  Future<void> unfollow(String targetUserId) async {
    final client = _ref.read(supabaseClientProvider);
    final session = _ref.read(sessionProvider);
    if (client == null || session == null) return;

    final current = state.valueOrNull ?? {};
    if (!current.contains(targetUserId)) return; // フォローしていない

    // 楽観的UI更新: 画面を即時更新
    final updated = {...current}..remove(targetUserId);
    state = AsyncData(updated);

    try {
      await client
          .from('user_follows')
          .delete()
          .eq('follower_id', session.user.id)
          .eq('following_id', targetUserId);
    } catch (_) {
      // DB削除失敗: ロールバック
      state = AsyncData(current);
      rethrow;
    }
  }

  /// フォロー状態を再読み込み（ログイン直後などに使用）
  Future<void> refresh() => _load();
}

/// 自分がフォロー中のユーザーIDセット
///
/// autoDispose にしない理由: アプリ全体でフォロー状態を共有するため。
/// 毎回ロードが走ると UX が低下するため、グローバルに保持する。
final followingIdsProvider =
    StateNotifierProvider<FollowingNotifier, AsyncValue<Set<String>>>((ref) {
  return FollowingNotifier(ref);
});

// ────────────────────────────────────────────────────────────────────────────
// 特定ユーザーをフォロー中かどうかを返すセレクタープロバイダー
// ────────────────────────────────────────────────────────────────────────────

/// [userId] をフォローしているか否かを返す
///
/// `followingIdsProvider` のデータから派生させることで、
/// フォロー/アンフォロー後に自動的に UI が更新される。
final isFollowingProvider = Provider.family<bool, String>((ref, userId) {
  final ids = ref.watch(followingIdsProvider).valueOrNull ?? {};
  return ids.contains(userId);
});

// ────────────────────────────────────────────────────────────────────────────
// フォロワー数・フォロー中数
// ────────────────────────────────────────────────────────────────────────────

/// あるユーザーのフォロワー数とフォロー中数をまとめたデータクラス
class FollowCounts {
  const FollowCounts({
    required this.followersCount,
    required this.followingCount,
  });
  final int followersCount;
  final int followingCount;
}

/// 指定ユーザーのフォロワー数・フォロー中数を取得するプロバイダー
///
/// `family` = ユーザーIDごとに独立したプロバイダーを生成する。
/// `autoDispose` = 画面を離れたらキャッシュを解放してメモリを節約する。
final followCountsProvider =
    FutureProvider.family.autoDispose<FollowCounts, String>((ref, userId) async {
  final client = ref.read(supabaseClientProvider);
  if (client == null) return const FollowCounts(followersCount: 0, followingCount: 0);

  try {
    final result = await client.rpc(
      'get_follow_counts',
      params: {'p_user_id': userId},
    );
    final row = (result as List).firstOrNull as Map<String, dynamic>?;
    return FollowCounts(
      followersCount: (row?['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (row?['following_count'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return const FollowCounts(followersCount: 0, followingCount: 0);
  }
});
