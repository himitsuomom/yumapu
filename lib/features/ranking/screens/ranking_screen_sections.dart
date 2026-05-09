part of 'ranking_screen.dart';

// ── ユーザープロフィール ボトムシート ─────────────────────────────────────────

class _UserProfileSheet extends ConsumerWidget {
  const _UserProfileSheet({
    required this.rankedUser,
    required this.rank,
  });

  final RankedUser rankedUser;
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = rankedUser.ranking;
    final isSignedIn = ref.watch(isSignedInProvider);
    final session = ref.watch(sessionProvider);
    final isMe = session != null && session.user.id == rankedUser.userId;
    final isFollowing = ref.watch(isFollowingProvider(rankedUser.userId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
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

            _Avatar(avatarUrl: rankedUser.avatarUrl, radius: 36),
            const SizedBox(height: 12),

            Text(
              rankedUser.displayName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  r.currentTitle,
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$rank 位',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ProfileStat(label: '合計PT', value: r.totalPoints.toString()),
                _ProfileStat(
                    label: '探索PT', value: r.explorerPoints.toString()),
                _ProfileStat(label: '社交PT', value: r.socialPoints.toString()),
                _ProfileStat(label: '訪問数', value: r.visitCount.toString()),
              ],
            ),

            if (!isMe) ...[
              const SizedBox(height: 16),
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
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onSurface,
                              )
                            : null,
                        onPressed: () async {
                          try {
                            if (isFollowing) {
                              await ref
                                  .read(followingIdsProvider.notifier)
                                  .unfollow(rankedUser.userId);
                            } else {
                              await ref
                                  .read(followingIdsProvider.notifier)
                                  .follow(rankedUser.userId);
                            }
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
                    : const SizedBox.shrink(),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// ボトムシート内の統計列
class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
        ),
      ],
    );
  }
}

// ── ポイントルール説明ダイアログの部品 ───────────────────────────────────────

class _PointRuleRow extends StatelessWidget {
  const _PointRuleRow({required this.rule});

  final _PointRule rule;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rule.color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(rule.icon, size: 18, color: rule.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.label, style: const TextStyle(fontSize: 13)),
                Text(
                  rule.unit,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF757575)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: rule.color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${rule.category} +${rule.points}',
              style: TextStyle(
                fontSize: 12,
                color: rule.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointTypeRow extends StatelessWidget {
  const _PointTypeRow({
    required this.color,
    required this.label,
    required this.description,
  });

  final Color color;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(fontSize: 12, color: Color(0xFF424242)),
          ),
        ),
      ],
    );
  }
}
