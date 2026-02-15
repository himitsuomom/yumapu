// lib/presentation/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yu_map/core/router/app_router.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/providers/auth_providers.dart';
import 'package:yu_map/providers/user_providers.dart';
import 'package:yu_map/providers/favorite_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push(AppRoutes.editProfile),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('ログアウト'),
                  content: const Text('ログアウトしてもよろしいですか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('ログアウト'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) context.go(AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('プロフィールが見つかりません'));
          }
          return _ProfileBody(user: user);
        },
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final app.User user;

  const _ProfileBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 48,
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? const Icon(Icons.person, size: 48)
                : null,
          ),
          const SizedBox(height: 12),

          // Display name
          Text(
            user.displayName ?? user.username ?? 'ユーザー',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (user.username != null)
            Text(
              '@${user.username}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          const SizedBox(height: 8),

          // Bio
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            Text(user.bio!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
          ],

          // Premium badge
          if (user.isPremium)
            Chip(
              avatar: const Icon(Icons.star, color: Colors.amber, size: 18),
              label: const Text('プレミアム会員'),
              backgroundColor: Colors.amber.shade50,
            ),

          const SizedBox(height: 24),

          // Ranking card (Riverpod)
          _RankingCard(userId: user.id),

          const SizedBox(height: 16),

          // Stats row (Riverpod)
          _StatsRow(userId: user.id),

          const SizedBox(height: 24),

          // Quick action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _QuickAction(
                icon: Icons.military_tech,
                label: 'バッジ',
                onTap: () => context.push(AppRoutes.badges),
              ),
              _QuickAction(
                icon: Icons.leaderboard,
                label: 'ランキング',
                onTap: () => context.push(AppRoutes.leaderboard),
              ),
              _QuickAction(
                icon: Icons.history,
                label: '訪問履歴',
                onTap: () => context.push(AppRoutes.visitHistory),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Favorites section (Riverpod)
          const _FavoritesSection(),
        ],
      ),
    );
  }
}

class _RankingCard extends ConsumerWidget {
  final String userId;

  const _RankingCard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(userRankingProvider(userId));

    return rankingAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (ranking) {
        if (ranking == null) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  ranking.currentTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (ranking.rankPosition != null)
                  Text(
                    '全体ランキング: ${ranking.rankPosition}位',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PointBadge(
                      label: '探検',
                      points: ranking.explorerPoints,
                      icon: Icons.explore,
                    ),
                    _PointBadge(
                      label: 'ソーシャル',
                      points: ranking.socialPoints,
                      icon: Icons.people,
                    ),
                    _PointBadge(
                      label: '合計',
                      points: ranking.totalPoints,
                      icon: Icons.emoji_events,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PointBadge extends StatelessWidget {
  final String label;
  final int points;
  final IconData icon;

  const _PointBadge({
    required this.label,
    required this.points,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          '$points',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatsRow extends ConsumerWidget {
  final String userId;

  const _StatsRow({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitCountAsync = ref.watch(userVisitCountProvider(userId));
    final reviewCountAsync = ref.watch(userReviewCountProvider(userId));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(
          label: '訪問',
          value: visitCountAsync.when(
            data: (count) => '$count',
            loading: () => '-',
            error: (_, __) => '-',
          ),
          icon: Icons.place,
        ),
        _StatItem(
          label: 'レビュー',
          value: reviewCountAsync.when(
            data: (count) => '$count',
            loading: () => '-',
            error: (_, __) => '-',
          ),
          icon: Icons.rate_review,
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _FavoritesSection extends ConsumerWidget {
  const _FavoritesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteFacilitiesProvider);

    return favoritesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (favorites) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'お気に入り (${favorites.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (favorites.isEmpty)
              const Text(
                'まだお気に入りの施設がありません',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...favorites.take(5).map((f) => ListTile(
                    leading: const Icon(Icons.hot_tub),
                    title: Text(f.name),
                    subtitle: Text(f.address ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/facility/${f.id}'),
                  )),
          ],
        );
      },
    );
  }
}
