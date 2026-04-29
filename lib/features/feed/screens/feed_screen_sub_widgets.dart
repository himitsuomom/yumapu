part of 'feed_screen.dart';

// ── 投稿カード ────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  const _PostCard({
    required this.post,
    this.activeFacilityFilter,
    this.onFacilityTap,
  });

  final Post post;

  /// 現在アクティブな施設フィルター名。施設タグのハイライト表示に使う。
  final String? activeFacilityFilter;

  /// 施設タグがタップされたときに呼ばれるコールバック（施設名, 施設ID）。
  final void Function(String facilityName, String facilityId)? onFacilityTap;

  static final _dateFormat = DateFormat('yyyy/MM/dd HH:mm');

  /// 投稿者のプロフィール情報をボトムシートで表示する。
  /// ランキング画面と同じ感覚でユーザー情報にアクセスできる。
  void _showAuthorProfile(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AuthorProfileSheet(
        userId: post.userId,
        userName: post.user,
        avatarUrl: post.avatar,
      ),
    );
  }

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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

  /// 投稿編集ダイアログを表示し、OKなら内容を更新する（C-3対応）
  ///
  /// TextEditingController で現在の投稿テキストを初期値にセットする。
  /// ダイアログ外タップまたは「キャンセル」で変更なし。
  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: post.content);
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
    if (newContent == null || newContent == post.content) return;
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
    final isSignedIn = ref.watch(isSignedInProvider);
    final session = ref.watch(sessionProvider);
    // 現在のログインユーザーが投稿者かどうかを確認
    final isMyPost = session != null && session.user.id == post.userId;

    // 施設タグがアクティブフィルターと一致するときハイライト表示する
    final isFacilityFiltered =
        activeFacilityFilter != null &&
        post.facilityName == activeFacilityFilter;

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
              // 投稿者アバター・名前タップ → ユーザープロフィールシートを表示
              GestureDetector(
                onTap: () => _showAuthorProfile(context),
                child: _PostAvatar(avatarUrl: post.avatar),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAuthorProfile(context),
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
              ),
              // 自分の投稿だけ「…」メニューを表示（編集・削除）
              if (isMyPost)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: Color(0xFF9E9E9E)),
                  tooltip: '操作',
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(context, ref);
                    } else if (value == 'delete') {
                      _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    // C-3対応: 編集メニューを追加
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
                          Icon(Icons.delete_outline,
                              color: Colors.red, size: 18),
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
          // タップすると施設絞り込みフィルターを設定する（アクティブ時はハイライト）
          if (post.facilityName.isNotEmpty) ...[
            GestureDetector(
              onTap: post.facilityId.isNotEmpty && onFacilityTap != null
                  ? () => onFacilityTap!(post.facilityName, post.facilityId)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  // アクティブフィルターと一致するときは紫系でハイライト
                  color: isFacilityFiltered
                      ? const Color(0xFFEDE7F6)
                      : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: isFacilityFiltered
                      ? Border.all(
                          color: const Color(0xFF7B1FA2), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hot_tub,
                      size: 14,
                      color: isFacilityFiltered
                          ? const Color(0xFF7B1FA2)
                          : const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.facilityName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isFacilityFiltered
                            ? const Color(0xFF7B1FA2)
                            : const Color(0xFF1565C0),
                      ),
                    ),
                    if (post.facilityId.isNotEmpty && onFacilityTap != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          isFacilityFiltered
                              ? Icons.filter_alt
                              : Icons.filter_alt_outlined,
                          size: 12,
                          color: isFacilityFiltered
                              ? const Color(0xFF7B1FA2)
                              : const Color(0xFF1565C0),
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
              // UX-V10-1: コメントアイコンをタップすると PostDetailScreen を
              // 開き、コメント入力欄に自動フォーカス（キーボードを即時表示）する。
              // UX-V11-5: 0件でも常にコメントアイコンを表示することで
              // 「コメントできる」ことに気づいてもらう（0件非表示だと見逃しやすい）。
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PostDetailScreen(
                      post: post,
                      focusComment: true,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                ),
              ),
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

/// 投稿が0件の場合に表示するウィジェット。
/// RefreshIndicator が機能するには scrollable な子が必要なため
/// ListView でラップしてプルリフレッシュを有効にする（UX-V11-5対応）。
class _EmptyFeedView extends ConsumerWidget {
  const _EmptyFeedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(postFeedProvider.notifier).load();
      },
      child: ListView(
        // コンテンツが少なくても引っ張って更新できるよう AlwaysScrollableScrollPhysics を指定
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
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
                const SizedBox(height: 4),
                Text(
                  '（下に引っ張って更新できます）',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── フォロー中タブ・投稿なし表示 ─────────────────────────────────────────────

/// フォロー中タブで投稿が0件の場合に表示するウィジェット。
/// 「まだ誰もフォローしていない」または「フォロー中の人が未投稿」の2ケースをカバー。
///
/// UX-V25-2: ランキング画面へのCTAボタンを追加。
/// フォロー相手が0人の初期状態で「どこに行けばいいか分からない」を解消する。
class _EmptyFollowingFeedView extends StatelessWidget {
  const _EmptyFollowingFeedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'フォロー中の投稿はありません',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'ランキングやフィードの投稿者プロフィールから\nユーザーをフォローしてみましょう',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF757575)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // UX-V25-2: ランキングへの導線ボタン
            // フォロー相手がいない初期状態のユーザーが次の行動を取りやすくする
            FilledButton.icon(
              icon: const Icon(Icons.leaderboard_outlined, size: 18),
              label: const Text('ランキングでユーザーを探す'),
              onPressed: () => Navigator.of(context).pushNamed('/ranking'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 施設絞り込み中・該当投稿なし表示 ─────────────────────────────────────────

/// 施設絞り込み中だが該当する投稿がない場合に表示するウィジェット。
class _FacilityEmptyView extends StatelessWidget {
  const _FacilityEmptyView({
    required this.facilityName,
    required this.onClear,
  });

  final String facilityName;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: Color(0xFF9E9E9E)),
          const SizedBox(height: 16),
          Text(
            '「$facilityName」の投稿はまだありません',
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('絞り込みを解除'),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

// ── ソートバー ─────────────────────────────────────────────────────────────────

/// フィード上部のソート切り替えバー（新しい順 / 人気順）。
///
/// ChoiceChip を横スクロールで並べる。
/// 選択中のチップはテーマのプライマリカラーで強調する。
class _SortBar extends StatelessWidget {
  const _SortBar({required this.current, required this.onChanged});

  final PostFeedSortBy current;
  final void Function(PostFeedSortBy) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _SortChip(
            label: '新しい順',
            icon: Icons.schedule,
            selected: current == PostFeedSortBy.newest,
            onTap: () => onChanged(PostFeedSortBy.newest),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: '人気順',
            icon: Icons.favorite,
            selected: current == PostFeedSortBy.popular,
            onTap: () => onChanged(PostFeedSortBy.popular),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant,
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
        width: 0.8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── 投稿者プロフィールシート ──────────────────────────────────────────────────

/// フィード投稿者のアバター・ユーザー名タップ時に表示する簡易プロフィールシート。
/// フォロー/アンフォローボタンとフォロワー数を表示する。
class _AuthorProfileSheet extends ConsumerWidget {
  const _AuthorProfileSheet({
    required this.userId,
    required this.userName,
    required this.avatarUrl,
  });

  final String userId;
  final String userName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final session = ref.watch(sessionProvider);
    // 自分自身のプロフィールを表示しているかどうか
    final isMe = session != null && session.user.id == userId;
    // フォロー済みかどうか（followingIdsProviderから派生）
    final isFollowing = ref.watch(isFollowingProvider(userId));
    // フォロワー数・フォロー中数を取得
    final countsAsync = ref.watch(followCountsProvider(userId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ドラッグハンドル（ボトムシートを引っ張って閉じる操作のヒント）
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // アバター
            if (avatarUrl.isNotEmpty)
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(avatarUrl),
              )
            else
              CircleAvatar(
                radius: 40,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            const SizedBox(height: 14),
            // ユーザー名
            Text(
              userName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // フォロワー数・フォロー中数（取得できたときだけ表示）
            countsAsync.whenOrNull(
              data: (counts) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FollowCountBadge(
                    label: 'フォロワー',
                    count: counts.followersCount,
                  ),
                  const SizedBox(width: 24),
                  _FollowCountBadge(
                    label: 'フォロー中',
                    count: counts.followingCount,
                  ),
                ],
              ),
            ) ?? const SizedBox.shrink(),
            const SizedBox(height: 20),
            // フォロー/アンフォローボタン
            // 自分自身には表示しない。未ログインは「ログインでフォロー」を促す。
            if (!isMe) ...[
              SizedBox(
                width: double.infinity,
                child: isSignedIn
                    ? FilledButton.icon(
                        icon: Icon(
                          isFollowing
                              ? Icons.person_remove_outlined
                              : Icons.person_add_outlined,
                          size: 18,
                        ),
                        label: Text(isFollowing ? 'フォロー解除' : 'フォローする'),
                        style: isFollowing
                            ? FilledButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.surfaceContainerHighest,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onSurface,
                              )
                            : null,
                        onPressed: () async {
                          try {
                            if (isFollowing) {
                              await ref
                                  .read(followingIdsProvider.notifier)
                                  .unfollow(userId);
                            } else {
                              await ref
                                  .read(followingIdsProvider.notifier)
                                  .follow(userId);
                            }
                            // フォロワー数表示を更新するためにプロバイダーを再取得
                            ref.invalidate(followCountsProvider(userId));
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('操作に失敗しました。もう一度お試しください。')),
                              );
                            }
                          }
                        },
                      )
                    : OutlinedButton.icon(
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text('ログインしてフォロー'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
              ),
              const SizedBox(height: 8),
            ],
            // 閉じるボタン
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// フォロワー数・フォロー中数の表示バッジ
class _FollowCountBadge extends StatelessWidget {
  const _FollowCountBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: const Color(0xFF757575)),
        ),
      ],
    );
  }
}
