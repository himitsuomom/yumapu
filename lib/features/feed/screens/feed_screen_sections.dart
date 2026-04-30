part of 'feed_screen.dart';

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
class _EmptyFollowingFeedView extends ConsumerWidget {
  const _EmptyFollowingFeedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.read(postFeedProvider.notifier).load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
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
                  FilledButton.icon(
                    icon: const Icon(Icons.leaderboard_outlined, size: 18),
                    label: const Text('ランキングでユーザーを探す'),
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/ranking'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.public_outlined, size: 18),
                    label: const Text('すべての投稿を見る'),
                    onPressed: () {
                      ref
                          .read(postFeedProvider.notifier)
                          .setFollowingOnlyFilter(false);
                    },
                  ),
                ],
              ),
            ),
          ),
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
    final isMe = session != null && session.user.id == userId;
    final isFollowing = ref.watch(isFollowingProvider(userId));
    final countsAsync = ref.watch(followCountsProvider(userId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
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
            Text(
              userName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
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
                ) ??
                const SizedBox.shrink(),
            const SizedBox(height: 20),
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
                        label:
                            Text(isFollowing ? 'フォロー解除' : 'フォローする'),
                        style: isFollowing
                            ? FilledButton.styleFrom(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSurface,
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
                            ref.invalidate(followCountsProvider(userId));
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('操作に失敗しました。もう一度お試しください。')),
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
