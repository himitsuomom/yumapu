// lib/providers/post_provider.dart
//
// 投稿フィード機能のデータ管理
// posts テーブルと users テーブルを JOIN し、いいね済み状態も取得する

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:yu_map/models/post.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// 投稿フィードの状態管理
///
/// StateNotifier を使って「取得・いいね・投稿・画像アップロード」をカプセル化する。
/// StateNotifier = 状態（データ）を管理するクラス。変更時に自動でUIを更新する。
class PostFeedNotifier extends StateNotifier<AsyncValue<List<Post>>> {
  PostFeedNotifier(this._ref) : super(const AsyncLoading()) {
    load();
  }

  final Ref _ref;

  /// 最新30件の投稿を取得する
  Future<void> load() async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    try {
      final session = _ref.read(sessionProvider);

      // users テーブルを JOIN して投稿者の表示名・アバターを取得
      final data = await client
          .from('posts')
          .select('*, users(display_name, username, avatar_url)')
          .order('created_at', ascending: false)
          .limit(30);

      // ログイン中のユーザーのいいね済み投稿IDを取得
      Set<String> likedIds = {};
      if (session != null) {
        final likes = await client
            .from('post_likes')
            .select('post_id')
            .eq('user_id', session.user.id);
        likedIds =
            (likes as List).map((e) => e['post_id'] as String).toSet();
      }

      final posts = (data as List).map((e) {
        final map = e as Map<String, dynamic>;
        final postId = map['id'] as String;
        return Post.fromJson(map, isLiked: likedIds.contains(postId));
      }).toList();

      state = AsyncData(posts);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// 外部から投稿リストの状態を直接更新する
  ///
  /// comment_provider がコメント追加後に commentsCount を即時反映するために使用する。
  void updateState(List<Post> posts) {
    state = AsyncData(posts);
  }

  /// いいね（楽観的UI更新 = ボタン押下直後に画面を更新し、DB処理は裏で行う）
  ///
  /// copyWith で新しい Post を生成するため、ロールバック時は
  /// 元の `current` リストの Post が変更されておらず正しく戻せる。
  Future<void> likePost(String postId) async {
    final client = _ref.read(supabaseClientProvider);
    final session = _ref.read(sessionProvider);
    if (client == null || session == null) return;

    final current = state.valueOrNull;
    if (current == null) return;

    // 画面を即時更新（copyWith で新オブジェクトを生成 → 元リストは変わらない）
    state = AsyncData(current.map((p) {
      if (p.id != postId) return p;
      return p.copyWith(likes: p.likes + 1, isLiked: true);
    }).toList());

    try {
      await client.from('post_likes').insert({
        'post_id': postId,
        'user_id': session.user.id,
      });
    } catch (_) {
      // 失敗したら元に戻す（current は未変更なのでそのまま使える）
      state = AsyncData(current);
    }
  }

  /// いいね解除
  Future<void> unlikePost(String postId) async {
    final client = _ref.read(supabaseClientProvider);
    final session = _ref.read(sessionProvider);
    if (client == null || session == null) return;

    final current = state.valueOrNull;
    if (current == null) return;

    // 画面を即時更新（copyWith で新オブジェクトを生成）
    state = AsyncData(current.map((p) {
      if (p.id != postId) return p;
      return p.copyWith(likes: (p.likes - 1).clamp(0, p.likes), isLiked: false);
    }).toList());

    try {
      await client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', session.user.id);
    } catch (_) {
      // 失敗したら元に戻す
      state = AsyncData(current);
    }
  }

  /// 画像を Supabase Storage にアップロードし、公開URLを返す
  ///
  /// ファイルパスは `{userId}/{uuid}.{ext}` にする。
  /// Storage の DELETE ポリシーがフォルダ名をユーザーIDで照合するため
  /// 必ずユーザーIDをパスの先頭フォルダに置くこと。
  Future<String> uploadPostImage(XFile imageFile) async {
    final client = _ref.read(supabaseClientProvider);
    final session = _ref.read(sessionProvider);
    if (client == null || session == null) {
      throw Exception('ログインが必要です');
    }

    // 拡張子を安全な形式に限定する（jpg/jpeg/png/webp のみ許可）
    final rawExt = imageFile.path.split('.').last.toLowerCase();
    final safeExt =
        ['jpg', 'jpeg', 'png', 'webp'].contains(rawExt) ? rawExt : 'jpg';

    // ユニークなファイル名を生成してアップロード先パスを確定
    final fileName = '${const Uuid().v4()}.$safeExt';
    final storagePath = '${session.user.id}/$fileName';

    final bytes = await imageFile.readAsBytes();

    await client.storage.from('post-images').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$safeExt',
            upsert: false,
          ),
        );

    // パブリックバケットなので getPublicUrl で直接URLを取得できる
    return client.storage.from('post-images').getPublicUrl(storagePath);
  }

  /// 新規投稿作成
  Future<void> createPost({
    required String content,
    String? facilityId,
    String facilityName = '',
    String? imageUrl,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final session = _ref.read(sessionProvider);
    if (client == null || session == null) return;

    await client.from('posts').insert({
      'user_id': session.user.id,
      'content': content,
      if (facilityId != null) 'facility_id': facilityId,
      'facility_name': facilityName,
      if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
    });

    // 投稿後に再取得して最新状態を反映
    await load();
  }
}

/// 投稿フィードプロバイダー
/// autoDispose = 画面を離れたときに自動でキャッシュを解放する
final postFeedProvider = StateNotifierProvider.autoDispose<PostFeedNotifier,
    AsyncValue<List<Post>>>((ref) {
  return PostFeedNotifier(ref);
});
