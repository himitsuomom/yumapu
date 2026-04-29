// lib/features/ranking/screens/ranking_screen.dart
//
// ランキング画面
// ユーザーの総得点ランキングを表示する。
// 自分の順位はページ上部のカードで常に確認できる。
// UX改善:
//   - AppBar の「？」ボタンからポイント獲得ルールをダイアログ表示（Task#3）
//   - ランキング行タップで他ユーザーのプロフィールをボトムシート表示（Task#5）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/follow_provider.dart';
import 'package:yu_map/providers/ranking_provider.dart';

// ランキング並び替えフィルターの表示順
const _sortOptions = [
  RankingSortBy.totalPoints,
  RankingSortBy.explorerPoints,
  RankingSortBy.socialPoints,
  RankingSortBy.visitCount,
];

// ── ポイントルール定義 ─────────────────────────────────────────────────────────

/// ポイント獲得ルールをまとめた定数。DB の ranking_triggers.sql と一致させること。
const _pointRules = [
  _PointRule(
    icon: Icons.hot_tub,
    color: Color(0xFF1565C0),
    label: '施設へのチェックイン',
    category: '探索PT',
    points: 100,
    unit: '1回ごと',
  ),
  _PointRule(
    icon: Icons.rate_review_outlined,
    color: Color(0xFF2E7D32),
    label: 'レビューを投稿',
    category: '社交PT',
    points: 50,
    unit: '1件ごと',
  ),
  _PointRule(
    icon: Icons.edit_outlined,
    color: Color(0xFF6A1B9A),
    label: 'フィードに投稿',
    category: '社交PT',
    points: 30,
    unit: '1件ごと',
  ),
];

/// 称号の昇格条件（訪問回数のしきい値と称号名）
const _titleMilestones = [
  _TitleMilestone(visits: 5, title: '湯めぐり見習い'),
  _TitleMilestone(visits: 10, title: '湯めぐり経験者'),
  _TitleMilestone(visits: 20, title: '湯めぐり中級者'),
  _TitleMilestone(visits: 50, title: '温泉通'),
  _TitleMilestone(visits: 100, title: '温泉愛好家'),
  _TitleMilestone(visits: 200, title: '温泉上級者'),
  _TitleMilestone(visits: 500, title: '温泉マスター'),
  _TitleMilestone(visits: 1000, title: '湯めぐり王'),
];

// ── ランキング画面 ─────────────────────────────────────────────────────────────

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {

  /// ポイント獲得ルールのダイアログを表示する（Task#3）
  void _showPointRulesDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('ポイント獲得ルール'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ポイント獲得方法 ───────────────────────────────
                const Text(
                  '何をするとポイントが貯まる？',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...(_pointRules.map((rule) => _PointRuleRow(rule: rule))),

                const Divider(height: 24),

                // ── ポイントの種類の説明 ─────────────────────────
                const Text(
                  'ポイントの種類',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                _PointTypeRow(
                  color: const Color(0xFF1565C0),
                  label: '探索PT',
                  description: 'チェックインで増える。訪問施設の多さを示す。',
                ),
                const SizedBox(height: 6),
                _PointTypeRow(
                  color: const Color(0xFF2E7D32),
                  label: '社交PT',
                  description: 'レビュー・投稿で増える。コミュニティへの貢献度を示す。',
                ),
                const SizedBox(height: 6),
                _PointTypeRow(
                  color: const Color(0xFF6A1B9A),
                  label: '合計PT',
                  description: '探索PT + 社交PT の合計。ランキングはこの値で決まる。',
                ),

                const Divider(height: 24),

                // ── 称号昇格条件 ──────────────────────────────────
                const Text(
                  '称号（チェックイン回数で変わる）',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ..._titleMilestones.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Text('♨️ ', style: TextStyle(fontSize: 13)),
                        Text(
                          '${m.visits}回〜  ',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF757575),
                          ),
                        ),
                        Text(
                          m.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final sortBy = ref.watch(rankingSortByProvider);
    final rankingAsync = ref.watch(rankingListProvider);
    final myRankingAsync = ref.watch(myRankingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ランキング'),
        actions: [
          // UX-V13-3: フィードへの動線（みんなの投稿を見る）
          TextButton.icon(
            icon: const Icon(Icons.dynamic_feed_outlined, size: 18),
            label: const Text('投稿', style: TextStyle(fontSize: 13)),
            onPressed: () => Navigator.of(context).pushNamed('/feed'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          // ポイントルール説明ボタン（Task#3）
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'ポイントのルールを見る',
            onPressed: () => _showPointRulesDialog(context),
          ),
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
            // ── ソート切り替えチップ ──────────────────────────────────────
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: _sortOptions.map((option) {
                    final isSelected = sortBy == option;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(option.label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            ref
                                .read(rankingSortByProvider.notifier)
                                .state = option;
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

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
                      // セクションヘッダー（ソート種別を表示）
                      if (index == 0) {
                        return _SectionHeader(
                          title: 'TOP 50 — ${sortBy.label}順',
                        );
                      }
                      final rank = index; // 1-indexed rank
                      final user = list[index - 1];
                      return _RankRow(
                        rank: rank,
                        rankedUser: user,
                        sortBy: sortBy,
                      );
                    },
                    childCount: list.length + 1, // ヘッダー分 +1
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.signal_wifi_off_outlined,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'ランキングの取得に失敗しました',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ネットワーク接続を確認してください',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('再読み込み'),
                          onPressed: () => ref.invalidate(rankingListProvider),
                        ),
                      ],
                    ),
                  ),
                ),
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
            const SizedBox(height: 8),
            // 地図タブへ誘導するボタン（NavigationBarのタブ0へ戻す）
            TextButton.icon(
              icon: const Icon(Icons.map_outlined, size: 16),
              label: const Text('地図で施設を探す'),
              onPressed: () {
                // BottomNavigationBar は HomeScreen で管理されているため
                // pop で戻ってタブを切り替えるより、pushNamed でルートに戻る方が安全。
                // 画面スタックが深い場合に備えて popUntil で一番上まで戻る。
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

  /// 他ユーザーのプロフィールをボトムシートで表示する（Task#5）
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
      // タップで他ユーザーのプロフィールを表示（Task#5）
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
          // ソートが訪問数以外の場合は訪問数をサブテキストで表示
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

// ── ユーザープロフィール ボトムシート ─────────────────────────────────────────

/// ランキング行タップ時に表示する他ユーザーのプロフィールシート（Task#5）
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
            // ドラッグハンドル
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
            _Avatar(avatarUrl: rankedUser.avatarUrl, radius: 36),
            const SizedBox(height: 12),

            // 名前
            Text(
              rankedUser.displayName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // 称号と順位
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

            // ポイント内訳（横並び4列）
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

            // フォロー/アンフォローボタン（自分自身以外に表示）
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
                                    content: Text('操作に失敗しました。もう一度お試しください。')),
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

// ── ポイントルール説明ダイアログの部品 ───────────────────────────────────────

/// ポイントルール1行の表示ウィジェット
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
                Text(
                  rule.label,
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  rule.unit,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF757575)),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

/// ポイント種別の説明行
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

// ── データクラス（const で使えるよう冗長な形式で定義） ───────────────────────

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
