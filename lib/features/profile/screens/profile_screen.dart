import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/core/widgets/empty_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/visit_provider.dart';
import 'package:yu_map/widgets/crown_badge.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static final _dateFormat = DateFormat('yyyy/MM/dd');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);

    if (!isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('プロフィール')),
        body: EmptyWidget(
          icon: Icons.person_outline,
          message: 'プロフィールを見るにはログインしてください',
          action: ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            child: const Text('ログイン'),
          ),
        ),
      );
    }

    final userAsync = ref.watch(currentUserProfileProvider);
    final visitAsync = ref.watch(visitListProvider);
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール')),
      body: userAsync.when(
        data: (user) => _buildContent(context, ref, user, visitAsync, favoritesAsync),
        loading: () => const LoadingWidget(),
        error: (_, __) => _buildContent(context, ref, null, visitAsync, favoritesAsync),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    app.User? user,
    AsyncValue<List<Visit>> visitAsync,
    AsyncValue<Set<String>> favoritesAsync,
  ) {
    final visitCount = visitAsync.valueOrNull?.length ?? 0;
    final favoriteCount = favoritesAsync.valueOrNull?.length ?? 0;
    final recentVisits = visitAsync.valueOrNull?.take(5).toList() ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Avatar & name ──────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              UserAvatarWithCrown(
                isPremium: user?.isPremium ?? false,
                radius: 48,
                avatarUrl: user?.avatarUrl,
              ),
              const SizedBox(height: 12),
              Text(
                user?.displayName ?? user?.username ?? 'ユーザー',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (user?.email != null) ...[
                const SizedBox(height: 4),
                Text(
                  user!.email!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF757575),
                      ),
                ),
              ],
              if (user?.isPremium == true) ...[
                const SizedBox(height: 8),
                const PremiumChip(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Stats cards ────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.place_outlined,
                label: '訪問数',
                value: visitAsync.isLoading ? '…' : '$visitCount',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.favorite_outline,
                label: 'お気に入り',
                value: favoritesAsync.isLoading ? '…' : '$favoriteCount',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Recent visits ──────────────────────────────────────────────
        Text(
          '最近の訪問',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (visitAsync.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (recentVisits.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'まだ訪問記録がありません',
              style: TextStyle(color: Color(0xFF757575)),
            ),
          )
        else
          ...recentVisits.map(
            (visit) => _VisitRow(
              visit: visit,
              dateFormat: _dateFormat,
            ),
          ),

        // ── Edit profile link ──────────────────────────────────────────
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
          child: const Text('設定'),
        ),
      ],
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

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
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF757575),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Visit row ─────────────────────────────────────────────────────────────────

class _VisitRow extends ConsumerWidget {
  const _VisitRow({required this.visit, required this.dateFormat});

  final Visit visit;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilityAsync = ref.watch(facilityDetailProvider(visit.facilityId));
    final facilityName =
        facilityAsync.valueOrNull?.name ?? visit.facilityId;

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
