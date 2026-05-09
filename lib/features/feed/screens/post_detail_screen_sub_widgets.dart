part of 'post_detail_screen.dart';

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

          Text(post.content, style: const TextStyle(fontSize: 15, height: 1.5)),

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
    final feedAsync = ref.watch(postFeedProvider);
    final latestPost = feedAsync.valueOrNull
            ?.where((p) => p.id == post.id)
            .firstOrNull ??
        post;

    return GestureDetector(
      onTap: isSignedIn
          ? () {
              if (latestPost.isLiked) {
                ref.read(postFeedProvider.notifier).unlikePost(latestPost.id);
              } else {
                ref.read(postFeedProvider.notifier).likePost(latestPost.id);
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
  final String? currentUserId;

  static final _dateFormat = DateFormat('MM/dd HH:mm');

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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
          _CommentAvatar(avatarUrl: comment.avatar),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(comment.text, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),

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
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
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
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  counterText: '',
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            _isSending
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
