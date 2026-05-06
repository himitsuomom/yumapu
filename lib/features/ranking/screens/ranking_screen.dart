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

part 'ranking_screen_sub_widgets.dart';
part 'ranking_screen_sections.dart';

// ランキング並び替えフィルターの表示順
const _sortOptions = [
  RankingSortBy.totalPoints,
  RankingSortBy.explorerPoints,
  RankingSortBy.socialPoints,
  RankingSortBy.visitCount,
];

// ランキング期間フィルターの表示順
const _periodOptions = [
  RankingPeriod.allTime,
  RankingPeriod.monthly,
  RankingPeriod.weekly,
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
                const _PointTypeRow(
                  color: Color(0xFF1565C0),
                  label: '探索PT',
                  description: 'チェックインで増える。訪問施設の多さを示す。',
                ),
                const SizedBox(height: 6),
                const _PointTypeRow(
                  color: Color(0xFF2E7D32),
                  label: '社交PT',
                  description: 'レビュー・投稿で増える。コミュニティへの貢献度を示す。',
                ),
                const SizedBox(height: 6),
                const _PointTypeRow(
                  color: Color(0xFF6A1B9A),
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
    final period = ref.watch(rankingPeriodProvider);
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
              // ランキングリストと自分の順位を再取得する
              ref.invalidate(rankingListProvider);
              ref.invalidate(myRankingProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        // 引っ張って更新（プルリフレッシュ）— ランキングリストと自分の順位を再取得
        onRefresh: () async {
          ref.invalidate(rankingListProvider);
          ref.invalidate(myRankingProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── 期間フィルター（累計 / 今月 / 今週）─────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    // 「期間」ラベル
                    Text(
                      '期間:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF757575),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    // 期間ChoiceChip群
                    ..._periodOptions.map((p) {
                      final isSelected = period == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            p.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: isSelected,
                          visualDensity: VisualDensity.compact,
                          onSelected: (selected) {
                            if (selected) {
                              ref.read(rankingPeriodProvider.notifier).state = p;
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

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
                        // shortLabel を使い、括弧書きで各ソートの意味を補足する。
                        // 例: 「探索PT（訪問）」→ チェックイン回数が多いほど有利とわかる。
                        label: Text(option.shortLabel),
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
                          title: 'TOP 50 — ${period.label} / ${sortBy.label}順',
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

