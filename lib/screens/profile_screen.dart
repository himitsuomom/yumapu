import 'package:flutter/material.dart' hide Badge;
import 'package:provider/provider.dart';
import 'package:yu_map/models/badge.dart';
import 'package:yu_map/models/user_ranking.dart';
import 'package:yu_map/providers/app_state.dart';

/// マイページ（プロフィール画面）
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.currentUser == null) {
        appState.loadUserProfile();
      }
      appState.loadFavorites();
      appState.loadMyRanking();
      appState.loadMyBadges();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'マイページ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final user = appState.currentUser;

          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // アバター
                CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(user.avatar),
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(height: 16),

                // 名前
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // ハンドル
                Text(
                  user.handle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),

                // 自己紹介
                if (user.bio.isNotEmpty)
                  Text(
                    user.bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),

                const SizedBox(height: 24),

                // ランキング・タイトルカード
                if (appState.myRanking != null) ...[
                  _RankingCard(ranking: appState.myRanking!),
                  const SizedBox(height: 16),
                ],

                // 統計カード
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.where_to_vote,
                        color: Colors.deepOrange,
                        label: 'チェックイン',
                        count: appState.myRanking?.visitCount ?? 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.article,
                        color: Colors.blue,
                        label: '投稿',
                        count: appState.myRanking?.reviewCount ?? 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.favorite,
                        color: Colors.red,
                        label: 'お気に入り',
                        count: appState.favoriteFacilities.length,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // バッジセクション
                _BadgeSection(
                  myBadges: appState.myBadges,
                  allBadges: appState.allBadges,
                ),

                const SizedBox(height: 32),

                // メニュー項目
                _MenuTile(
                  icon: Icons.favorite_border,
                  title: 'お気に入り一覧',
                  onTap: () {
                    // お気に入りタブに切り替え（親のMainScreenに通知が必要）
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('お気に入りタブから確認できます')),
                    );
                  },
                ),
                _MenuTile(
                  icon: Icons.settings,
                  title: '設定',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('この機能は準備中です')),
                    );
                  },
                ),
                _MenuTile(
                  icon: Icons.help_outline,
                  title: 'ヘルプ',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('この機能は準備中です')),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ログアウトボタン
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'ログアウト',
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: () async {
                      final appState = context.read<AppState>();
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('ログアウト'),
                          content: const Text('ログアウトしますか？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('キャンセル'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'ログアウト',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        if (!mounted) return;
                        await appState.signOut();
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _BadgeSection extends StatelessWidget {
  final List<UserBadge> myBadges;
  final List<Badge> allBadges;

  const _BadgeSection({required this.myBadges, required this.allBadges});

  @override
  Widget build(BuildContext context) {
    final earnedIds = myBadges.map((b) => b.badge.id).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'バッジ',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${myBadges.length} / ${allBadges.length}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (allBadges.isEmpty)
          const Text('バッジ情報を読み込み中...', style: TextStyle(color: Colors.grey))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: allBadges.map((badge) {
              final isEarned = earnedIds.contains(badge.id);
              return GestureDetector(
                onTap: () => _showBadgeDetail(context, badge, isEarned),
                child: Tooltip(
                  message: badge.nameJa,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isEarned
                          ? Colors.orange.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEarned
                            ? Colors.orange.shade300
                            : Colors.grey.shade200,
                        width: isEarned ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        badge.icon,
                        style: TextStyle(
                          fontSize: 26,
                          color: isEarned ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showBadgeDetail(BuildContext context, Badge badge, bool isEarned) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              badge.icon,
              style: TextStyle(
                fontSize: 48,
                color: isEarned ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.nameJa,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              badge.descriptionJa,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isEarned ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isEarned ? '✅ 獲得済み' : '🔒 未獲得',
                style: TextStyle(
                  color:
                      isEarned ? Colors.green.shade700 : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  final UserRanking ranking;

  const _RankingCard({required this.ranking});

  @override
  Widget build(BuildContext context) {
    final nextPoints = UserRanking.nextTitlePoints(ranking.totalPoints);
    final progress = nextPoints != null
        ? ranking.totalPoints / nextPoints
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE57373), Color(0xFFFF8A65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ranking.currentTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (ranking.rankPosition != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ranking.rankPosition}位',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${ranking.totalPoints} pt',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (nextPoints != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white30,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '次のタイトルまで ${nextPoints - ranking.totalPoints} pt',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ] else
            const Text(
              '最高ランク達成！',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
