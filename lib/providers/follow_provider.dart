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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/result/result_extensions.dart';
import 'package:yu_map/providers/repository_providers.dart';

// ────────────────────────────────────────────────────────────────────────────
// 自分がフォロー中のユーザーIDセットを管理する AsyncNotifier
// ────────────────────────────────────────────────────────────────────────────

/// 自分がフォローしているユーザーIDの集合（Set）を保持するプロバイダー
///
/// Set を使う理由: フォロー済みかの判定が O(1) で高速。
/// フォロー/アンフォロー時に楽観的UI更新（画面を即時更新）を行う。
class FollowingNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final repo = ref.watch(followRepositoryProvider);
    final result = await repo.getFollowingIds();
    return result.dataOrNull ?? {};
  }

  /// フォロー処理（楽観的UI更新 + DB書き込み）
  ///
  /// 楽観的UI更新 = ボタンを押した瞬間に画面を変え、DB処理は裏で行う。
  /// 失敗したら元に戻す（ロールバック）。
  Future<void> follow(String targetUserId) async {
    final current = state.valueOrNull ?? {};
    if (current.contains(targetUserId)) return; // すでにフォロー中

    // 楽観的UI更新: 画面を即時更新
    state = AsyncData({...current, targetUserId});

    final repo = ref.read(followRepositoryProvider);
    final result = await repo.follow(targetUserId);
    result.onFailure((e) {
      // DB書き込み失敗: ロールバック
      debugPrint('FollowingNotifier.follow failed, rolling back: $e');
      state = AsyncData(current);
      throw e;
    });
  }

  /// アンフォロー処理（楽観的UI更新 + DB削除）
  Future<void> unfollow(String targetUserId) async {
    final current = state.valueOrNull ?? {};
    if (!current.contains(targetUserId)) return; // フォローしていない

    // 楽観的UI更新: 画面を即時更新
    final updated = {...current}..remove(targetUserId);
    state = AsyncData(updated);

    final repo = ref.read(followRepositoryProvider);
    final result = await repo.unfollow(targetUserId);
    result.onFailure((e) {
      // DB削除失敗: ロールバック
      debugPrint('FollowingNotifier.unfollow failed, rolling back: $e');
      state = AsyncData(current);
      throw e;
    });
  }

  /// フォロー状態を再読み込み（ログイン直後などに使用）
  Future<void> refresh() async => ref.invalidateSelf();
}

/// 自分がフォロー中のユーザーIDセット
///
/// autoDispose にしない理由: アプリ全体でフォロー状態を共有するため。
/// 毎回ロードが走ると UX が低下するため、グローバルに保持する。
final followingIdsProvider =
    AsyncNotifierProvider<FollowingNotifier, Set<String>>(
  FollowingNotifier.new,
);

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
  final repo = ref.read(followRepositoryProvider);
  final result = await repo.getFollowCounts(userId);
  final counts = result.dataOrNull ?? (followers: 0, following: 0);
  return FollowCounts(
    followersCount: counts.followers,
    followingCount: counts.following,
  );
});
