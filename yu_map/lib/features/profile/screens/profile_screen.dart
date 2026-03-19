import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/visit_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/features/settings/settings_screen.dart';
import 'package:yu_map/widgets/crown_badge.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final visitsAsync = ref.watch(userVisitsProvider);
    final favIds = ref.watch(favoritesProvider).valueOrNull ?? {};
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar & name
            profileAsync.when(
              loading: () => const LoadingWidget(),
              error: (_, __) => _buildProfileHeader(
                context,
                displayName: session?.user.email ?? 'ユーザー',
                email: session?.user.email,
              ),
              data: (user) => _buildProfileHeader(
                context,
                displayName: user?.displayName ?? user?.username ?? session?.user.email ?? 'ユーザー',
                email: session?.user.email,
                avatarUrl: user?.avatarUrl,
                bio: user?.bio,
                isPremium: user?.isPremium ?? false,
              ),
            ),
            const SizedBox(height: 24),

            // Stats cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.location_on,
                    label: '訪問',
                    value: visitsAsync.when(
                      data: (v) => '${v.length}',
                      loading: () => '...',
                      error: (_, __) => '-',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.favorite,
                    label: 'お気に入り',
                    value: '${favIds.length}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent visits
            _buildSectionTitle(context, '最近の訪問'),
            const SizedBox(height: 8),
            visitsAsync.when(
              loading: () => const LoadingWidget(),
              error: (_, __) => const Text('訪問履歴の取得に失敗しました'),
              data: (visits) {
                if (visits.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'まだ訪問した施設はありません',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return Column(
                  children: visits.take(5).map((visit) {
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(visit.facilityName ?? visit.facilityId),
                      subtitle: Text(
                        '${visit.visitedAt.year}/${visit.visitedAt.month}/${visit.visitedAt.day}',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context, {
    required String displayName,
    String? email,
    String? avatarUrl,
    String? bio,
    bool isPremium = false,
  }) {
    return Column(
      children: [
        UserAvatarWithCrown(
          isPremium: isPremium,
          radius: 40,
          avatarUrl: avatarUrl,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (isPremium) ...[
              const SizedBox(width: 8),
              const PremiumChip(),
            ],
          ],
        ),
        if (email != null)
          Text(
            email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
