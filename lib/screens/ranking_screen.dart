// lib/screens/ranking_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yu_map/models/user_ranking.dart';
import 'package:yu_map/providers/app_state.dart';

/// ランキング画面 - 全ユーザーのポイントランキングを表示
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.loadTopRankings();
      appState.loadMyRanking();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ランキング',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          return RefreshIndicator(
            onRefresh: () async {
              await appState.loadTopRankings();
              await appState.loadMyRanking();
            },
            child: CustomScrollView(
              slivers: [
                // 自分のランキングカード
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _MyRankingCard(ranking: appState.myRanking),
                  ),
                ),

                // ポイント説明
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PointGuide(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // ランキングヘッダー
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'トップランキング',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // ランキングリスト
                if (appState.topRankings.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'まだランキングデータがありません\n施設にチェックインしてポイントを獲得しよう！',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = appState.topRankings[index];
                        final isMe = entry.userId ==
                            appState.currentUser?.handle;
                        return _RankingListTile(
                          entry: entry,
                          isMe: isMe,
                        );
                      },
                      childCount: appState.topRankings.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 自分のランキングカード
class _MyRankingCard extends StatelessWidget {
  final UserRanking? ranking;

  const _MyRankingCard({required this.ranking});

  @override
  Widget build(BuildContext context) {
    if (ranking == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'ログインするとランキングに参加できます',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final nextPoints = UserRanking.nextTitlePoints(ranking!.totalPoints);
    final progress = nextPoints != null
        ? (ranking!.totalPoints / nextPoints).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE57373), Color(0xFFFF8A65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'あなたのランキング',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ranking!.currentTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (ranking!.rankPosition != null)
                Column(
                  children: [
                    Text(
                      '${ranking!.rankPosition}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      '位',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${ranking!.totalPoints} pt',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white30,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          nextPoints != null
              ? Text(
                  '次の称号まで ${nextPoints - ranking!.totalPoints} pt',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                )
              : const Text(
                  '最高ランク「湯マスター」達成！',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                  icon: Icons.where_to_vote,
                  label: 'チェックイン',
                  value: '${ranking!.visitCount}回'),
              const SizedBox(width: 16),
              _MiniStat(
                  icon: Icons.article,
                  label: '投稿',
                  value: '${ranking!.reviewCount}件'),
              const SizedBox(width: 16),
              _MiniStat(
                  icon: Icons.favorite,
                  label: 'いいね獲得',
                  value: '${ranking!.likesReceived}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}

/// ポイント獲得ガイド
class _PointGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ポイントの獲得方法',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          const _PointRow(icon: Icons.where_to_vote, text: 'チェックイン', points: '+100pt'),
          const _PointRow(icon: Icons.article, text: '投稿する', points: '+30pt'),
          const _PointRow(icon: Icons.favorite, text: 'いいねをもらう', points: '+10pt'),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String points;

  const _PointRow(
      {required this.icon, required this.text, required this.points});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13))),
          Text(
            points,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// ランキングリストの1行
class _RankingListTile extends StatelessWidget {
  final RankingEntry entry;
  final bool isMe;

  const _RankingListTile({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final rankColor = entry.rank == 1
        ? const Color(0xFFFFD700)
        : entry.rank == 2
            ? const Color(0xFFC0C0C0)
            : entry.rank == 3
                ? const Color(0xFFCD7F32)
                : Colors.grey.shade400;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isMe ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(color: Colors.orange.shade300, width: 1.5)
            : Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          alignment: Alignment.topRight,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: entry.userAvatar.isNotEmpty
                  ? NetworkImage(entry.userAvatar)
                  : null,
              backgroundColor: Colors.grey.shade200,
              child: entry.userAvatar.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: rankColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${entry.rank}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Text(
              entry.userName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.orange.shade800 : null,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'あなた',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          entry.currentTitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Text(
          '${entry.totalPoints} pt',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFFE57373),
          ),
        ),
      ),
    );
  }
}
