// lib/features/ranking/screens/ranking_screen.dart
//
// ランキング画面
// ユーザーの総得点ランキングを表示する。
// 自分の順位はページ上部のカードで常に確認できる。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/ranking_provider.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final rankingAsync = ref.watch(rankingListProvider);
    final myRankingAsync = ref.watch(myRankingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ランキング'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: () {
              ref.invalidate(rankingListProvider);
              ref.invalidate(myRankingProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        // 引っ張って更新（プルリフレッシュ）
        onRefresh: () async {
          ref.invalidate(rankingListProvider);
          ref.invalidate(myRankingProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── 自分の順位カード ─────────────────────────────────────────
            if (isSignedIn)
              SliverToBoxAdapter(
                child: myRankingAsync.when(
                  data: (my) => my == null
                      ? const _NoRankingCard()
                      : _MyRankCard(rankedUser: my),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const _NoRankingCard(),
                ),
              ),

            // ── トップ50リスト ─────────────────────────────────────────
            rankingAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('ランキングデータがありません')),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // セクションヘッダー
                      if (index == 0) {
                        return const _SectionHeader(title: 'TOP 50');
                      }
                      final rank = index; // 1-indexed rank
                      final user = list[index - 1];
                      return _RankRow(
                        rank: rank,
                        rankedUser: user,
                      );
                    },
                    childCount: list.length + 1, // ヘッダー分 +1
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('取得エラー: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            // ポイント内訳
            Row(
              children: [
                _MiniStat(
                    label: '合計PT', value: r.totalPoints.toString()),
                const SizedBox(width: 16),
                _MiniStat(
                    label: '探索PT', value: r.explorerPoints.toString()),
                const SizedBox(width: 16),
                _MiniStat(
                    label: '社交PT', value: r.socialPoints.toString()),
                const SizedBox(width: 16),
                _MiniStat(
                    label: '訪問数', value: r.visitCount.toString()),
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
  const _RankRow({required this.rank, required this.rankedUser});

  final int rank;
  final RankedUser rankedUser;

  @override
  Widget build(BuildContext context) {
    final r = rankedUser.ranking;

    return ListTile(
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
            '${r.totalPoints} PT',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
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
    // 1〜3位はゴールド・シルバー・ブロンズのアイコン
    if (rank == 1) {
      return const _MedalIcon(emoji: '🥇', size: 36);
    } else if (rank == 2) {
      return const _MedalIcon(emoji: '🥈', size: 36);
    } else if (rank == 3) {
      return const _MedalIcon(emoji: '🥉', size: 36);
    }
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
