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

/// フィードの並び順
///
/// newest = 新しい順（created_at DESC・カーソルページング）
/// popular = 人気順（likes DESC → created_at DESC・オフセットページング）
enum PostFeedSortBy { newest, popular }

/// 投稿フィードの状態管理
///
/// StateNotifier を使って「取得・いいね・投稿・画像アップロード」をカプセル化する。
/// StateNotifier = 状態（データ）を管理するクラス。変更時に自動でUIを更新する。
class PostFeedNotifier extends StateNotifier<AsyncValue<List<Post>>> {
  PostFeedNotifier(this._ref) : super(const AsyncLoading()) {
    load();
  }

  final Ref _ref;

  /// 1ページあたりの取得件数
  static const _pageSize = 20;

  /// 追加ページが存在するかどうか（false = 全件取得済み）
  bool _hasMore = true;

  /// `loadMore()` が実行中かどうか（二重取得防止）
  bool _isLoadingMore = false;

  /// 外部からページ末尾かどうかを確認するためのゲッター
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  /// サーバーサイドの施設絞り込みフィルター（null = 全件）。
  /// setFacilityFilter() で更新すると自動的に再取得する。
  String? _facilityIdFilter;

  /// 現在のソート順（デフォルト: 新しい順）
  PostFeedSortBy _sortBy = PostFeedSortBy.newest;

  /// フォロー中のユーザーの投稿のみ表示するかどうか（false = 全件）
  ///
  /// true の場合: get_following_posts RPC を使ってフォロー中の投稿だけを取得する。
  /// false の場合: 従来どおり全ユーザーの投稿を取得する。
  bool _showFollowingOnly = false;

  /// 外部からフォロー中フィルターの状態を取得するためのゲッター
  bool get showFollowingOnly => _showFollowingOnly;

  /// 外部からソート順を取得するためのゲッター
  PostFeedSortBy get sortBy => _sortBy;

  /// 施設絞り込みフィルターを設定して再読み込みする。
  ///
  /// [facilityId] が null の場合は全件表示に戻す。
  /// クライアントサイドフィルタリングと異なり、サーバーから
  /// 施設IDに一致する投稿だけを取得するため、ページング精度が上がる。
  Future<void> setFacilityFilter(String? facilityId) async {
    _facilityIdFilter = facilityId;
    await load();
  }

  /// ソート順を変更して再読み込みする。
  ///
  /// [sortBy] が現在と同じ値でも再取得を行い、最新状態に更新する。
  Future<void> setSortOrder(PostFeedSortBy sortBy) async {
    _sortBy = sortBy;
    await load();
  }

  /// フォロー中フィルターを切り替えて再読み込みする。
  ///
  /// [showFollowingOnly] が true のとき: フォロー中のユーザーの投稿のみ表示。
  /// false のとき: 全ユーザーの投稿を表示する。
  Future<void> setFollowingOnlyFilter(bool showFollowingOnly) async {
    _showFollowingOnly = showFollowingOnly;
    await load();
  }

  /// 最新 _pageSize 件の投稿を取得する（初回 / プルリフレッシュ）
  Future<void> load() async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      state = const AsyncData([]);
      return;
    }
    _hasMore = true;
    _isLoadingMore = false;
    state = const AsyncLoading();
    try {
      final session = _ref.read(sessionProvider);

      // ── フォロー中フィルターが有効な場合は RPC を使う ──────────────────────
      // get_following_posts RPC: フォロー中のユーザーの投稿だけをDB側で絞り込む。
      // 通常のクエリでは「フォロー中IDリスト → IN句」が必要で遅くなるため RPC が適切。
      if (_showFollowingOnly && session != null) {
        final params = <String, dynamic>{
          'p_user_id': session.user.id,
          'p_limit': _pageSize,
        };
        final rawData = await client.rpc('get_following_posts', params: params);
        // Dart の dynamic キャスト: rpc() は dynamic を返すため List に変換
        final dataList = List<Map<String, dynamic>>.from(
            (rawData as List).map((e) => Map<String, dynamic>.from(e as Map)));

        // いいね済みIDを取得してフラグをセット
        Set<String> likedIds = {};
        final postIds = dataList.map((e) => e['id'] as String).toList();
        if (postIds.isNotEmpty) {
          final likes = await client
              .from('post_likes')
              .select('post_id')
              .eq('user_id', session.user.id)
              .inFilter('post_id', postIds);
          likedIds = (likes as List).map((e) => e['post_id'] as String).toSet();
        }

        final posts = dataList.map((map) {
          // RPC の結果は users JOIN ではなくフラットな構造なので変換する
          // Post.fromJson が期待する users ネスト構造に組み直す
          final converted = Map<String, dynamic>.from(map);
          converted['users'] = {
            'display_name': converted.remove('display_name'),
            'username':     converted.remove('username'),
            'avatar_url':   converted.remove('avatar_url'),
          };
          return Post.fromJson(converted, isLiked: likedIds.contains(converted['id']));
        }).toList();

        _hasMore = posts.length >= _pageSize;
        state = AsyncData(posts);
        return;
      }

      // ── 通常クエリ（全件 or 施設フィルター）──────────────────────────────
      // users テーブルを JOIN して投稿者の表示名・アバターを取得
      // 施設IDフィルターが設定されている場合はサーバーサイドで絞り込む
      var query = client
          .from('posts')
          .select('*, users(display_name, username, avatar_url)');
      if (_facilityIdFilter != null) {
        query = query.eq('facility_id', _facilityIdFilter!);
      }
      final data = await query
          .order('created_at', ascending: false)
          .limit(_pageSize);

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

      // 取得件数がページサイズ未満なら最終ページ
      _hasMore = posts.length >= _pageSize;

      state = AsyncData(posts);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// 次ページを追加取得して既存リストに追記する（無限スクロール）
  ///
  /// カーソルベースページング: 現在のリスト末尾の `created_at` より古い投稿を取得する。
  /// フォロー中フィルターが有効な場合も RPC を使いカーソルで追加取得する。
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;

    final client = _ref.read(supabaseClientProvider);
    if (client == null) return;

    _isLoadingMore = true;

    try {
      final session = _ref.read(sessionProvider);
      final lastCreatedAt = current.last.time;

      // ── フォロー中フィルター有効時は RPC でページング ────────────────────
      if (_showFollowingOnly && session != null) {
        final params = <String, dynamic>{
          'p_user_id': session.user.id,
          'p_limit':   _pageSize,
          'p_cursor':  lastCreatedAt,
        };
        final rawMore = await client.rpc('get_following_posts', params: params);
        final moreList = List<Map<String, dynamic>>.from(
            (rawMore as List).map((e) => Map<String, dynamic>.from(e as Map)));

        Set<String> likedIds = {};
        final postIds = moreList.map((e) => e['id'] as String).toList();
        if (postIds.isNotEmpty) {
          final likes = await client
              .from('post_likes')
              .select('post_id')
              .eq('user_id', session.user.id)
              .inFilter('post_id', postIds);
          likedIds = (likes as List).map((e) => e['post_id'] as String).toSet();
        }

        final newPosts = moreList.map((map) {
          final converted = Map<String, dynamic>.from(map);
          converted['users'] = {
            'display_name': converted.remove('display_name'),
            'username':     converted.remove('username'),
            'avatar_url':   converted.remove('avatar_url'),
          };
          return Post.fromJson(converted, isLiked: likedIds.contains(converted['id']));
        }).toList();

        _hasMore = newPosts.length >= _pageSize;
        state = AsyncData([...current, ...newPosts]);
        return;
      }

      // ── 通常クエリでのページング ─────────────────────────────────────────
      // 施設IDフィルターが設定されている場合はサーバーサイドで絞り込む
      var moreQuery = client
          .from('posts')
          .select('*, users(display_name, username, avatar_url)')
          .lt('created_at', lastCreatedAt);
      if (_facilityIdFilter != null) {
        moreQuery = moreQuery.eq('facility_id', _facilityIdFilter!);
      }
      final data = await moreQuery
          .order('created_at', ascending: false)
          .limit(_pageSize);

      // ログイン中ユーザーのいいね済みIDを取得
      Set<String> likedIds = {};
      if (session != null) {
        final postIds =
            (data as List).map((e) => e['id'] as String).toList();
        if (postIds.isNotEmpty) {
          final likes = await client
              .from('post_likes')
              .select('post_id')
              .eq('user_id', session.user.id)
              .inFilter('post_id', postIds);
          likedIds =
              (likes as List).map((e) => e['post_id'] as String).toSet();
        }
      }

      final newPosts = (data as List).map((e) {
        final map = e as Map<String, dynamic>;
        final postId = map['id'] as String;
        return Post.fromJson(map, isLiked: likedIds.contains(postId));
      }).toList();

      _hasMore = newPosts.length >= _pageSize;
      state = AsyncData([...current, ...newPosts]);
    } catch (_) {
      // loadMore の失敗は致命的ではないため無視（次回スクロールで再試行できる）
    } finally {
      _isLoadingMore = false;
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

  /// 投稿削除（自分の投稿のみ削除可能）
  ///
  /// 楽観的UI更新: まず画面から消してから DB に DELETE を送る。
  /// DB 削除に失敗したら元の投稿リストに戻す（ロールバック）。
  /// 投稿に画像がある場合は Storage からも削除する。
  Future<void> deletePost(String postId) async {
    final client = _ref.read(supabaseClientProvider);
    final session = _ref.read(sessionProvider);
    if (client == null || session == null) return;

    final current = state.valueOrNull;
    if (current == null) return;

    // 削除対象の投稿を探す
    final target = current.where((p) => p.id == postId).firstOrNull;
    if (target == null) return;

    // 楽観的UI: 画面から即時削除
    state = AsyncData(current.where((p) => p.id != postId).toList());

    try {
      // DB の posts レコードを削除（RLS: 自分の投稿のみ削除可能）
      await client
          .from('posts')
          .delete()
          .eq('id', postId)
          .eq('user_id', session.user.id);

      // 画像が Storage にある場合は Storage からも削除する
      // imageUrl のパスから storage_path を抽出する
      if (target.imageUrl.isNotEmpty) {
        try {
          final uri = Uri.tryParse(target.imageUrl);
          if (uri != null) {
            // URL の末尾 2セグメントが "{userId}/{fileName}" の形式
            final segments = uri.pathSegments;
            if (segments.length >= 2) {
              final storagePath =
                  '${segments[segments.length - 2]}/${segments.last}';
              await client.storage
                  .from('post-images')
                  .remove([storagePath]);
            }
          }
        } catch (_) {
          // Storage 削除失敗は致命的ではないため無視
        }
      }
    } catch (_) {
      // DB 削除失敗: ロールバック
      state = AsyncData(current);
      rethrow;
    }
  }

  /// 投稿テキストを編集する（C-3対応・自分の投稿のみ）
  ///
  /// 楽観的UI更新: 先に画面を更新し、DB更新失敗時は元に戻す。
  /// RLS: posts_update_own ポリシーにより自分の投稿のみ許可される。
  Future<void> editPost(String postId, String newContent) async {
    final client = _ref.read(supabaseClientProvider);
    final session = _ref.read(sessionProvider);
    if (client == null || session == null) return;

    final current = state.valueOrNull;
    if (current == null) return;

    // 楽観的UI: 画面を即時更新（ユーザーが編集を確認した瞬間に反映）
    final optimistic = current
        .map((p) => p.id == postId ? p.copyWith(content: newContent) : p)
        .toList();
    state = AsyncData(optimistic);

    try {
      // DB UPDATE（RLS: auth.uid() = user_id のみ許可）
      await client
          .from('posts')
          .update({'content': newContent})
          .eq('id', postId)
          .eq('user_id', session.user.id);
    } catch (_) {
      // DB更新失敗: 楽観的更新をロールバック
      state = AsyncData(current);
      rethrow;
    }
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
