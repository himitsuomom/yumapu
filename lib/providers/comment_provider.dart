// lib/providers/comment_provider.dart
//
// 投稿コメントの状態管理
// 特定の投稿（postId）に対するコメントの取得・追加を管理する。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/models/post.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/post_provider.dart';

/// 特定の投稿のコメントを管理する StateNotifier
///
/// `.family` = postId ごとに別インスタンスを生成するための修飾子。
/// autoDispose = 詳細画面を閉じたときに自動でキャッシュを解放する。
class CommentNotifier extends StateNotifier<AsyncValue<List<Comment>>> {
  CommentNotifier(this._ref, this._postId) : super(const AsyncLoading()) {
    load();
  }

  final Ref _ref;
  final String _postId;

  /// コメント一覧を古い順で取得する
  Future<void> load() async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    try {
      final data = await client
          .from('comments')
          .select()
          .eq('post_id', _postId)
          .order('created_at', ascending: true);

      final comments = (data as List)
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList();

      state = AsyncData(comments);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// コメントを追加する
  ///
  /// comments テーブルは user_name / user_avatar を非正規化カラムとして持つため、
  /// 投稿前に currentUserProfileProvider でユーザー情報を取得してセットする。
  Future<void> addComment(String text) async {
    final client = _ref.read(supabaseClientProvider);
    final session = _ref.read(sessionProvider);
    if (client == null || session == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // 現在のユーザープロフィールを取得（表示名・アバターURL）
    final profile = await _ref.read(currentUserProfileProvider.future);
    final userName =
        profile?.displayName ?? profile?.username ?? '匿名ユーザー';
    final userAvatar = profile?.avatarUrl ?? '';

    await client.from('comments').insert({
      'post_id': _postId,
      'user_id': session.user.id,
      'user_name': userName,
      'user_avatar': userAvatar,
      'text': trimmed,
    });

    // フィードの commentsCount を楽観的UI更新で即時反映
    // （DBトリガーで posts.comments_count は更新済みなので整合性あり）
    final feedNotifier = _ref.read(postFeedProvider.notifier);
    final feedState = _ref.read(postFeedProvider).valueOrNull;
    if (feedState != null) {
      final updated = feedState.map((p) {
        if (p.id != _postId) return p;
        return p.copyWith(commentsCount: p.commentsCount + 1);
      }).toList();
      feedNotifier.updateState(updated);
    }

    // コメントリストを再取得
    await load();
  }
}

/// コメントプロバイダー（postId ごとに独立したインスタンス）
final commentProvider = StateNotifierProvider.autoDispose
    .family<CommentNotifier, AsyncValue<List<Comment>>, String>(
  (ref, postId) => CommentNotifier(ref, postId),
);
