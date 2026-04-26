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

class PostDetailScreen extends ConsumerWidget {
  /// [focusComment] が true のとき、画面表示直後にコメント入力欄へ自動フォーカスする。
  /// FeedScreen のコメントアイコンからタップされた場合に true を渡す（UX-V10-1）。
  const PostDetailScreen({
    super.key,
    required this.post,
    this.focusComment = false,
  });

  final Post post;

  /// コメント入力欄を自動フォーカスするかどうか。
  final bool focusComment;

  /// 投稿編集ダイアログを表示する（C-3対応）
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
    // 自分のコメントの削除判定用：ログイン中ユーザーのID
    final currentUserId = ref.watch(sessionProvider)?.user.id;
    // 最新の投稿内容を postFeedProvider から取得（編集後に本文を更新するため）
    final feedAsync = ref.watch(postFeedProvider);
    final latestPost =
        feedAsync.valueOrNull?.where((p) => p.id == post.id).firstOrNull ??
            post;
    final isMyPost = currentUserId != null && post.userId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿詳細'),
        // 自分の投稿の場合のみ編集メニューを表示
        actions: [
          if (isMyPost)
            PopupMenuButton<String>(
              tooltip: '操作',
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditDialog(context, ref, latestPost.content);
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
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // ── スクロール可能なコンテンツ ─────────────────────────────
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── 投稿本文 ────────────────────────────────────────
                // latestPost を渡すことで編集後に本文が即時更新される
                SliverToBoxAdapter(
                  child: _PostBody(post: latestPost),
                ),

                // ── コメントヘッダー ─────────────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(16, 8, 16, 4),
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

                // ── コメント一覧 ────────────────────────────────────
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

                // スクロール末尾の余白
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),

          // ── 下部コメント入力エリア（ログイン時のみ表示） ────────────
          if (isSignedIn) ...[
            const Divider(height: 1),
            _CommentInputBar(postId: post.id, autoFocus: focusComment),
          ],
        ],
      ),
    );
  }
}

// ── 投稿本文ウィジェット ───────────────────────────────────────────────────────

class _PostBody extends ConsumerWidget {
  const _PostBody({required this.post});

  final Post post;

  static final _dateFormat = DateFormat('yyyy/MM/dd HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);

    String formattedTime;
    try {
      final dt = DateTime.parse(post.time).toLocal();
      formattedTime = _dateFormat.format(dt);
    } catch (_) {
      formattedTime = post.time;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ヘッダー（アバター・名前・日時） ──────────────────────
          Row(
            children: [
              _DetailAvatar(avatarUrl: post.avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.user,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF757575)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── 施設タグ ────────────────────────────────────────────
          if (post.facilityName.isNotEmpty) ...[
            GestureDetector(
              onTap: post.facilityId.isNotEmpty
                  ? () => Navigator.of(context).pushNamed(
                        '/facility',
                        arguments: post.facilityId,
                      )
                  : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(14),
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
                          fontSize: 13, color: Color(0xFF1565C0)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── 本文 ────────────────────────────────────────────────
          Text(post.content, style: const TextStyle(fontSize: 15, height: 1.5)),

          // ── 画像 ────────────────────────────────────────────────
          if (post.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── いいねボタン ─────────────────────────────────────────
          _DetailLikeButton(post: post, isSignedIn: isSignedIn),
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
  }
}

// ── 詳細画面用いいねボタン ────────────────────────────────────────────────────

class _DetailLikeButton extends ConsumerWidget {
  const _DetailLikeButton({required this.post, required this.isSignedIn});

  final Post post;
  final bool isSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // postFeedProvider の最新状態から同じ投稿を探す（いいね状態を同期）
    final feedAsync = ref.watch(postFeedProvider);
    final latestPost = feedAsync.valueOrNull
            ?.where((p) => p.id == post.id)
            .firstOrNull ??
        post;

    return GestureDetector(
      onTap: isSignedIn
          ? () {
              if (latestPost.isLiked) {
                ref
                    .read(postFeedProvider.notifier)
                    .unlikePost(latestPost.id);
              } else {
                ref
                    .read(postFeedProvider.notifier)
                    .likePost(latestPost.id);
              }
            }
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            latestPost.isLiked ? Icons.favorite : Icons.favorite_border,
            size: 22,
            color: latestPost.isLiked
                ? Colors.redAccent
                : const Color(0xFF757575),
          ),
          const SizedBox(width: 6),
          Text(
            '${latestPost.likes}',
            style: TextStyle(
              fontSize: 14,
              color: latestPost.isLiked
                  ? Colors.redAccent
                  : const Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }
}

// ── アバター ─────────────────────────────────────────────────────────────────

class _DetailAvatar extends StatelessWidget {
  const _DetailAvatar({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: const Color(0xFFE3F2FD),
      );
    }
    return const CircleAvatar(
      radius: 22,
      backgroundColor: Color(0xFFE3F2FD),
      child: Icon(Icons.person, size: 22, color: Color(0xFF1565C0)),
    );
  }
}

// ── コメント行 ────────────────────────────────────────────────────────────────

class _CommentTile extends ConsumerWidget {
  const _CommentTile({
    required this.comment,
    required this.postId,
    required this.currentUserId,
  });

  final Comment comment;
  final String postId;

  /// ログイン中のユーザーID。未ログイン時は null。
  final String? currentUserId;

  static final _dateFormat = DateFormat('MM/dd HH:mm');

  /// 削除確認ダイアログを表示し、OKなら削除を実行する。
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('コメントを削除'),
        content: const Text('このコメントを削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref
          .read(commentProvider(postId).notifier)
          .deleteComment(comment.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String formattedTime;
    try {
      final dt = DateTime.parse(comment.time).toLocal();
      formattedTime = _dateFormat.format(dt);
    } catch (_) {
      formattedTime = comment.time;
    }

    final isOwn = currentUserId != null && comment.userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // アバター
          _CommentAvatar(avatarUrl: comment.avatar),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名前・日時
                Row(
                  children: [
                    Text(
                      comment.user,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF757575)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // コメント本文
                Text(comment.text, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),

          // 自分のコメントのみ削除ボタンを表示
          if (isOwn)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Colors.grey,
              tooltip: 'コメントを削除',
              visualDensity: VisualDensity.compact,
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
      ),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: const Color(0xFFE3F2FD),
      );
    }
    return const CircleAvatar(
      radius: 16,
      backgroundColor: Color(0xFFE3F2FD),
      child: Icon(Icons.person, size: 16, color: Color(0xFF1565C0)),
    );
  }
}

// ── コメント入力バー ──────────────────────────────────────────────────────────

class _CommentInputBar extends ConsumerStatefulWidget {
  const _CommentInputBar({required this.postId, this.autoFocus = false});

  final String postId;

  /// true のとき、ウィジェット表示直後にキーボードを自動表示する（UX-V10-1）。
  final bool autoFocus;

  @override
  ConsumerState<_CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends ConsumerState<_CommentInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // autoFocus が true のとき、フレームが描画されてからキーボードを表示する。
    // addPostFrameCallback で遅延させないと画面遷移アニメーション中に
    // フォーカスが当たり、描画が乱れることがある。
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await ref
          .read(commentProvider(widget.postId).notifier)
          .addComment(text);
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送信に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 8,
          top: 8,
          // キーボードが出たときにテキストフィールドが隠れないよう
          // MediaQuery でキーボードの高さ分だけ余白を追加
          bottom: 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'コメントを入力...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  counterText: '',
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            // 送信ボタン
            _isSending
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.send),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _send,
                    tooltip: '送信',
                  ),
          ],
        ),
      ),
    );
  }
}
