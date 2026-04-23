// lib/features/feed/screens/feed_screen.dart
//
// 投稿フィード画面
// ユーザーの投稿（温泉レポート）を新しい順で表示する。
// いいね・プルリフレッシュ・新規投稿ボタンを提供する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/features/feed/screens/create_post_screen.dart';
import 'package:yu_map/features/feed/screens/post_detail_screen.dart';
import 'package:yu_map/models/post.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/post_provider.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final feedAsync = ref.watch(postFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('フィード'),
        // 投稿ボタンは FAB だけに統一。AppBar のアイコンは削除。
      ),
      body: feedAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return const _EmptyFeedView();
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.read(postFeedProvider.notifier).load();
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return _PostCard(post: posts[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Color(0xFF757575)),
              const SizedBox(height: 8),
              Text('読み込みエラー: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(postFeedProvider.notifier).load(),
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      ),
      // ログインしていれば投稿ボタンをフローティング表示
      floatingActionButton: isSignedIn
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreatePostScreen(),
                ),
              ),
              tooltip: '投稿する',
              child: const Icon(Icons.edit_outlined),
            )
          : null,
    );
  }
}

// ── 投稿カード ────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});

  final Post post;

  static final _dateFormat = DateFormat('yyyy/MM/dd HH:mm');

  /// 削除確認ダイアログを表示し、OKなら投稿を削除する
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('投稿を削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(postFeedProvider.notifier).deletePost(post.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除に失敗しました。もう一度お試しください。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final session = ref.watch(sessionProvider);
    // 現在のログインユーザーが投稿者かどうかを確認
    final isMyPost = session != null && session.user.id == post.userId;

    // 投稿日時をフォーマット（パースできなければ生の文字列を表示）
    String formattedTime;
    try {
      final dt = DateTime.parse(post.time).toLocal();
      formattedTime = _dateFormat.format(dt);
    } catch (_) {
      formattedTime = post.time;
    }

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(post: post),
        ),
      ),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ヘッダー（アバター・名前・日時・削除メニュー） ────────────
          Row(
            children: [
              _PostAvatar(avatarUrl: post.avatar),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.user,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              // 自分の投稿だけ「…」メニューを表示
              if (isMyPost)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: Color(0xFF9E9E9E)),
                  tooltip: '操作',
                  onSelected: (value) {
                    if (value == 'delete') {
                      _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('削除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── 施設タグ ────────────────────────────────────────────────
          if (post.facilityName.isNotEmpty) ...[
            GestureDetector(
              onTap: post.facilityId.isNotEmpty
                  ? () => Navigator.of(context).pushNamed(
                        '/facility',
                        arguments: post.facilityId,
                      )
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hot_tub,
                        size: 14, color: Color(0xFF1565C0)),
                    const SizedBox(width: 4),
                    Text(
                      post.facilityName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── 本文 ────────────────────────────────────────────────────
          Text(post.content),

          // ── 画像 ────────────────────────────────────────────────────
          if (post.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ── フッター（いいねボタン・コメント数） ──────────────────────
          Row(
            children: [
              // いいねボタン（ログイン時のみ有効）
              _LikeButton(post: post, isSignedIn: isSignedIn),
              const SizedBox(width: 16),
              // commentsCount は posts.comments_count（DBトリガーで自動更新）
              if (post.commentsCount > 0) ...[
                const Icon(Icons.comment_outlined,
                    size: 18, color: Color(0xFF757575)),
                const SizedBox(width: 4),
                Text(
                  '${post.commentsCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      ),
    );
  }
}

// ── いいねボタン ──────────────────────────────────────────────────────────────

class _LikeButton extends ConsumerWidget {
  const _LikeButton({required this.post, required this.isSignedIn});

  final Post post;
  final bool isSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isSignedIn
          ? () {
              if (post.isLiked) {
                ref.read(postFeedProvider.notifier).unlikePost(post.id);
              } else {
                ref.read(postFeedProvider.notifier).likePost(post.id);
              }
            }
          : null,
      child: Row(
        children: [
          Icon(
            post.isLiked ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: post.isLiked
                ? Colors.redAccent
                : const Color(0xFF757575),
          ),
          const SizedBox(width: 4),
          Text(
            '${post.likes}',
            style: TextStyle(
              fontSize: 13,
              color: post.isLiked
                  ? Colors.redAccent
                  : const Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 投稿アバター ──────────────────────────────────────────────────────────────

class _PostAvatar extends StatelessWidget {
  const _PostAvatar({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: const Color(0xFFE3F2FD),
      );
    }
    return const CircleAvatar(
      radius: 20,
      backgroundColor: Color(0xFFE3F2FD),
      child: Icon(Icons.person, size: 20, color: Color(0xFF1565C0)),
    );
  }
}

// ── 空フィード表示 ─────────────────────────────────────────────────────────────

class _EmptyFeedView extends StatelessWidget {
  const _EmptyFeedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('♨️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            '投稿がまだありません',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '温泉の感想を投稿してみましょう！',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color(0xFF757575)),
          ),
        ],
      ),
    );
  }
}
