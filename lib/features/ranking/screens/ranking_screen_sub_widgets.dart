part of 'ranking_screen.dart';

// ── 自分の順位カード ──────────────────────────────────────────────────────────

class _MyRankCard extends StatelessWidget {
  const _MyRankCard({required this.rankedUser});

  final RankedUser rankedUser;

  @override
  Widget build(BuildContext context) {
    final r = rankedUser.ranking;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'あなたの順位',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withAlpha(180),
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Avatar(
                  avatarUrl: rankedUser.avatarUrl,
                  radius: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rankedUser.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        r.currentTitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                if (r.rankPosition != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${r.rankPosition}位',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                else
                  Text(
                    '圏外',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: const Color(0xFF757575)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MiniStat(label: '合計PT', value: r.totalPoints.toString()),
                const SizedBox(width: 16),
                _MiniStat(label: '探索PT', value: r.explorerPoints.toString()),
                const SizedBox(width: 16),
                _MiniStat(label: '社交PT', value: r.socialPoints.toString()),
                const SizedBox(width: 16),
                _MiniStat(label: '訪問数', value: r.visitCount.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoRankingCard extends StatelessWidget {
  const _NoRankingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.leaderboard_outlined,
                size: 40, color: Color(0xFF757575)),
            const SizedBox(height: 8),
            Text(
              '施設を訪問してランキングに参加しよう！',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF757575),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.map_outlined, size: 16),
              label: const Text('地図で施設を探す'),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── セクションヘッダー ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: const Color(0xFF757575)),
      ),
    );
  }
}

// ── ランキング行 ──────────────────────────────────────────────────────────────

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.rankedUser,
    this.sortBy = RankingSortBy.totalPoints,
  });

  final int rank;
  final RankedUser rankedUser;
  final RankingSortBy sortBy;

  void _showUserProfile(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _UserProfileSheet(
        rankedUser: rankedUser,
        rank: rank,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = rankedUser.ranking;

    return ListTile(
      onTap: () => _showUserProfile(context),
      leading: _RankBadge(rank: rank),
      title: Row(
        children: [
          _Avatar(avatarUrl: rankedUser.avatarUrl, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rankedUser.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  r.currentTitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF1565C0),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            sortBy.trailingValue(rankedUser),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (sortBy != RankingSortBy.visitCount)
            Text(
              '訪問 ${r.visitCount}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFF757575)),
            ),
        ],
      ),
    );
  }
}

// ── 順位バッジ ────────────────────────────────────────────────────────────────

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    if (rank == 1) return const _MedalIcon(emoji: '🥇', size: 36);
    if (rank == 2) return const _MedalIcon(emoji: '🥈', size: 36);
    if (rank == 3) return const _MedalIcon(emoji: '🥉', size: 36);
    return SizedBox(
      width: 36,
      child: Text(
        '$rank',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF757575),
        ),
      ),
    );
  }
}

class _MedalIcon extends StatelessWidget {
  const _MedalIcon({required this.emoji, required this.size});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Text(
        emoji,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size * 0.7),
      ),
    );
  }
}

// ── アバター ──────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.radius});

  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: const Color(0xFFE3F2FD),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE3F2FD),
      child: Icon(
        Icons.person,
        size: radius,
        color: const Color(0xFF1565C0),
      ),
    );
  }
}

// ── ミニ統計表示 ──────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF757575)),
        ),
      ],
    );
  }
}

// ── データクラス ──────────────────────────────────────────────────────────────

class _PointRule {
  const _PointRule({
    required this.icon,
    required this.color,
    required this.label,
    required this.category,
    required this.points,
    required this.unit,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String category;
  final int points;
  final String unit;
}

class _TitleMilestone {
  const _TitleMilestone({required this.visits, required this.title});

  final int visits;
  final String title;
}
