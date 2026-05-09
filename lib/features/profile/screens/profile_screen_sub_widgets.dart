part of 'profile_screen.dart';

// ── Ranking banner ────────────────────────────────────────────────────────────

class _RankingBanner extends StatelessWidget {
  const _RankingBanner({required this.rankedUser});

  final RankedUser rankedUser;

  @override
  Widget build(BuildContext context) {
    final r = rankedUser.ranking;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.leaderboard, color: Color(0xFF1565C0)),
        title: Text(
          r.currentTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${r.totalPoints} PT'
            '  ·  ${r.rankPosition != null ? '${r.rankPosition}位' : '圏外'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed('/ranking'),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1565C0), size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF757575),
                      ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: Color(0xFF757575),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }
    return card;
  }
}

// ── Plans link card ───────────────────────────────────────────────────────────

class _PlansLinkCard extends StatelessWidget {
  const _PlansLinkCard({required this.plansAsync});

  final AsyncValue<List<OnsenPlan>> plansAsync;

  @override
  Widget build(BuildContext context) {
    final planCount = plansAsync.valueOrNull?.length ?? 0;
    final isLoading = plansAsync.isLoading;

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/plans'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.route_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '湯めぐりプラン',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                isLoading ? '…' : '$planCount 件',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Visit row ─────────────────────────────────────────────────────────────────

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit, required this.dateFormat});

  final Visit visit;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final facilityName = visit.facilityName ?? visit.facilityId;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.place_outlined, color: Color(0xFF1565C0)),
      title: Text(
        facilityName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(dateFormat.format(visit.visitedAt)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pushNamed(
        '/facility',
        arguments: visit.facilityId,
      ),
    );
  }
}

// ── ゲーミフィケーションカード ────────────────────────────────────────────────

class _GamificationCards extends ConsumerWidget {
  const _GamificationCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myBadgesAsync = ref.watch(myBadgesProvider);
    final myRankingAsync = ref.watch(myRankingProvider);

    final badgeCount = myBadgesAsync.valueOrNull?.length ?? 0;
    final ranking = myRankingAsync.valueOrNull?.ranking;

    return Row(
      children: [
        Expanded(
          child: _GamificationCard(
            onTap: () => Navigator.of(context).pushNamed('/badges'),
            backgroundColor: const Color(0xFFFFF8E1),
            borderColor: const Color(0xFFFFD54F),
            icon: const Text('🏅', style: TextStyle(fontSize: 28)),
            title: 'バッジ',
            subtitle: myBadgesAsync.isLoading
                ? '読込中...'
                : badgeCount > 0
                    ? '$badgeCount 枚獲得！'
                    : 'まだ獲得なし',
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
        if (AppConfig.isRankingEnabled) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _GamificationCard(
              onTap: () => Navigator.of(context).pushNamed('/ranking'),
              backgroundColor: const Color(0xFFE3F2FD),
              borderColor: const Color(0xFF90CAF9),
              icon: const Icon(Icons.leaderboard, size: 28, color: Color(0xFF1565C0)),
              title: 'ランキング',
              subtitle: myRankingAsync.isLoading
                  ? '読込中...'
                  : ranking != null
                      ? (ranking.rankPosition != null
                          ? '${ranking.rankPosition}位'
                          : ranking.currentTitle)
                      : '記録なし',
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ],
      ],
    );
  }
}

class _GamificationCard extends StatelessWidget {
  const _GamificationCard({
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Widget icon;
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : backgroundColor;
    final bdColor = isDark
        ? Theme.of(context).colorScheme.outline
        : borderColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bdColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? Theme.of(context).colorScheme.onSurface.withAlpha(178)
                    : const Color(0xFF757575),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '詳細 →',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
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

// ── フォロワー数・フォロー中数 ────────────────────────────────────────────────

class _OwnFollowCountsRow extends ConsumerWidget {
  const _OwnFollowCountsRow({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(followCountsProvider(userId));

    return countsAsync.when(
      data: (counts) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FollowCountBadge(
            label: 'フォロワー',
            count: counts.followersCount,
          ),
          const SizedBox(width: 32),
          _FollowCountBadge(
            label: 'フォロー中',
            count: counts.followingCount,
          ),
        ],
      ),
      loading: () => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FollowCountBadge(label: 'フォロワー', count: -1),
          SizedBox(width: 32),
          _FollowCountBadge(label: 'フォロー中', count: -1),
        ],
      ),
      error: (_, __) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FollowCountBadge(label: 'フォロワー', count: -1),
          SizedBox(width: 32),
          _FollowCountBadge(label: 'フォロー中', count: -1),
        ],
      ),
    );
  }
}

class _FollowCountBadge extends StatelessWidget {
  const _FollowCountBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count < 0 ? '-' : '$count',
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
