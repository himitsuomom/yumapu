// lib/features/feed/screens/post_detail_screen.dart
//
// 投稿詳細画面
// 投稿の全文・画像を表示し、コメントの閲覧と追加ができる。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/models/post.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/comment_provider.dart';
import 'package:yu_map/providers/post_provider.dart';

part 'post_detail_screen_sub_widgets.dart';

class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({
    super.key,
    required this.post,
    this.focusComment = false,
  });

  final Post post;
  final bool focusComment;

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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(postFeedProvider.notifier).deletePost(post.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除に失敗しました。もう一度お試しください。')),
        );
      }
    }
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, String currentContent) async {
    final controller = TextEditingController(text: currentContent);
    final newContent = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('投稿を編集'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          maxLength: 500,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '内容を入力...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(ctx).pop(text);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newContent == null || newContent == currentContent) return;
    try {
      await ref.read(postFeedProvider.notifier).editPost(post.id, newContent);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('編集に失敗しました。もう一度お試しください。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(commentProvider(post.id));
    final isSignedIn = ref.watch(isSignedInProvider);
    final currentUserId = ref.watch(sessionProvider)?.user.id;
    final feedAsync = ref.watch(postFeedProvider);
    final latestPost =
        feedAsync.valueOrNull?.where((p) => p.id == post.id).firstOrNull ??
            post;
    final isMyPost = currentUserId != null && post.userId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿詳細'),
        actions: [
          if (isMyPost)
            PopupMenuButton<String>(
              tooltip: '操作',
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditDialog(context, ref, latestPost.content);
                } else if (value == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('編集'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('削除', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _PostBody(post: latestPost),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'コメント',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider(height: 1)),

                commentsAsync.when(
                  data: (comments) {
                    if (comments.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'まだコメントはありません\n最初のコメントを書いてみましょう！',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF757575)),
                            ),
                          ),
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _CommentTile(
                          comment: comments[index],
                          postId: post.id,
                          currentUserId: currentUserId,
                        ),
                        childCount: comments.length,
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('読み込みエラー: $e'),
                          TextButton(
                            onPressed: () =>
                                ref.read(commentProvider(post.id).notifier).load(),
                            child: const Text('再試行'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),

          if (isSignedIn) ...[
            const Divider(height: 1),
            _CommentInputBar(postId: post.id, autoFocus: focusComment),
          ],
        ],
      ),
    );
  }
}
