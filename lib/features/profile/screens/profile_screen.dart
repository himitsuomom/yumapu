import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/core/widgets/empty_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/models/onsen_plan.dart';
import 'package:yu_map/providers/follow_provider.dart';
import 'package:yu_map/providers/plan_provider.dart';
import 'package:yu_map/providers/badge_provider.dart';
import 'package:yu_map/providers/ranking_provider.dart';
import 'package:yu_map/providers/visit_provider.dart';
import 'package:yu_map/widgets/crown_badge.dart';

part 'profile_screen_sub_widgets.dart';

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
    final visitCountAsync = ref.watch(visitCountProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final myRankingAsync = ref.watch(myRankingProvider);
    final plansAsync = ref.watch(myPlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール')),
      body: userAsync.when(
        data: (user) => _buildContent(
            context, ref, user, visitAsync, visitCountAsync,
            favoritesAsync, myRankingAsync, plansAsync),
        loading: () => const LoadingWidget(),
        error: (_, __) => _buildContent(
            context, ref, null, visitAsync, visitCountAsync,
            favoritesAsync, myRankingAsync, plansAsync),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    app.User? user,
    AsyncValue<List<Visit>> visitAsync,
    AsyncValue<int> visitCountAsync,
    AsyncValue<Set<String>> favoritesAsync,
    AsyncValue<RankedUser?> myRankingAsync,
    AsyncValue<List<OnsenPlan>> plansAsync,
  ) {
    final visitCount = visitCountAsync.valueOrNull
        ?? visitAsync.valueOrNull?.length
        ?? 0;
    final favoriteCount = favoritesAsync.valueOrNull?.length ?? 0;
    final recentVisits = visitAsync.valueOrNull?.take(5).toList() ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: user != null
                    ? () => Navigator.of(context)
                        .pushNamed('/edit-profile', arguments: user)
                    : null,
                child: Stack(
                  children: [
                    UserAvatarWithCrown(
                      isPremium: user?.isPremium ?? false,
                      radius: 48,
                      avatarUrl: user?.avatarUrl,
                    ),
                    if (user != null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1565C0),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user?.displayName ?? user?.username ?? 'ユーザー',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (user?.isPremium == true) ...[
                const SizedBox(height: 8),
                const PremiumChip(),
              ],
              if (user != null) ...[
                const SizedBox(height: 12),
                _OwnFollowCountsRow(userId: user.id),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (AppConfig.isRankingEnabled && myRankingAsync.valueOrNull != null)
          _RankingBanner(rankedUser: myRankingAsync.value!),
        if (AppConfig.isRankingEnabled && myRankingAsync.valueOrNull != null)
          const SizedBox(height: 16),

        Row(
          children: [
            if (AppConfig.isCheckinEnabled) ...[
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'チェックイン数',
                  value: visitCountAsync.isLoading ? '…' : '$visitCount',
                  onTap: visitCount > 0
                      ? () => Navigator.of(context).pushNamed('/visit-history')
                      : null,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _StatCard(
                icon: Icons.favorite_outline,
                label: 'お気に入り',
                value: favoritesAsync.isLoading ? '…' : '$favoriteCount',
                onTap: favoriteCount > 0
                    ? () => Navigator.of(context).pushNamed('/favorites')
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        const _GamificationCards(),

        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '最近の訪問',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (visitCount > 5)
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/visit-history'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'すべて見る →',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
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

        const SizedBox(height: 24),
        _PlansLinkCard(plansAsync: plansAsync),

        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined),
          label: const Text('プロフィールを編集'),
          onPressed: user == null
              ? null
              : () => Navigator.of(context).pushNamed(
                    '/edit-profile',
                    arguments: user,
                  ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.settings_outlined),
          label: const Text('設定'),
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ],
    );
  }
}
