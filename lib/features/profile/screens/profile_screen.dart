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
    // visitCountProvider で正確な総件数を取得する（visitListProvider は上限20件）
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
    // 正確な総件数（COUNT クエリ）。取得中は visitList の length をフォールバックに使う
    final visitCount = visitCountAsync.valueOrNull
        ?? visitAsync.valueOrNull?.length
        ?? 0;
    final favoriteCount = favoritesAsync.valueOrNull?.length ?? 0;
    final recentVisits = visitAsync.valueOrNull?.take(5).toList() ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Avatar & name ──────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              // アバターをタップで編集画面へ遷移する（標準的なSNSのUX）
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
                    // カメラアイコンをアバター右下に重ねて「変更可能」を示す
                    // UX-V24-6: 14px → 18px に拡大。初見ユーザーが変更可能と気づきやすくなる。
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
              // メールアドレスはプライバシー保護のため設定画面のみに表示する。
              // プロフィール画面ではユーザー名（displayName）のみ表示する。
              if (user?.isPremium == true) ...[
                const SizedBox(height: 8),
                const PremiumChip(),
              ],
              // UX-V26-1: フォロワー数・フォロー中数を自分のプロフィールにも表示。
              // SNSとして「自分のフォロワーが何人いるか」は重要な社会的指標。
              if (user != null) ...[
                const SizedBox(height: 12),
                _OwnFollowCountsRow(userId: user.id),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── ランキング情報 ──────────────────────────────────────────────
        if (AppConfig.isRankingEnabled && myRankingAsync.valueOrNull != null)
          _RankingBanner(rankedUser: myRankingAsync.value!),
        if (AppConfig.isRankingEnabled && myRankingAsync.valueOrNull != null)
          const SizedBox(height: 16),

        // ── Stats cards ────────────────────────────────────────────────
        Row(
          children: [
            if (AppConfig.isCheckinEnabled) ...[
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'チェックイン数',
                  value: visitCountAsync.isLoading ? '…' : '$visitCount',
                  onTap: visitCount > 0
                      ? () => Navigator.of(context)
                          .pushNamed('/visit-history')
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

        // ── バッジ・ランキングへのリンク（G-1改善：stat cards直下に移動して発見性向上）──
        // 以前は最近の訪問リストより下にあったが、スクロールしないと見えなかったため
        // stat cards の直下（=スクロールゼロで見える位置）に引き上げた。
        const _GamificationCards(),

        const SizedBox(height: 24),

        // ── Recent visits ──────────────────────────────────────────────
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
            // UX-V7-1対応: 5件を超える訪問がある場合に「すべて見る →」を表示
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

        // ── 湯めぐりプランへのリンク ────────────────────────────────────
        const SizedBox(height: 24),
        _PlansLinkCard(plansAsync: plansAsync),

        // ── Edit profile / Settings links ──────────────────────────────
        // UX-V28-1: _RankingLinkCard は _GamificationCards にランキングカードが
        // 既に含まれているため重複。削除してプロフィール画面をすっきりさせた。
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

// ── Ranking banner ────────────────────────────────────────────────────────────

class _RankingBanner extends StatelessWidget {
  const _RankingBanner({required this.rankedUser});

  final RankedUser rankedUser;

  @override
  Widget build(BuildContext context) {
    final r = rankedUser.ranking;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.leaderboard, color: Color(0xFF1565C0)),
        title: Text(
          r.currentTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${r.totalPoints} PT'
            '  ·  ${r.rankPosition != null ? '${r.rankPosition}位' : '圏外'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed('/ranking'),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;

  /// タップ時のコールバック。null の場合はタップ不可（インジケーターなし）。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF757575),
                      ),
                ),
                // タップ可能なカードには矢印アイコンを表示して遷移できることを示す
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: Color(0xFF757575),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    // onTap が指定されている場合は InkWell でラップしてタップ可能にする
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }
    return card;
  }
}

// ── Plans link card ───────────────────────────────────────────────────────────
// UX-V8-1: プラン一覧へのリンクカード。プラン数を表示し、タップで /plans へ遷移する。

class _PlansLinkCard extends StatelessWidget {
  const _PlansLinkCard({required this.plansAsync});

  final AsyncValue<List<OnsenPlan>> plansAsync;

  @override
  Widget build(BuildContext context) {
    final planCount = plansAsync.valueOrNull?.length ?? 0;
    final isLoading = plansAsync.isLoading;

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/plans'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.route_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '湯めぐりプラン',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                isLoading ? '…' : '$planCount 件',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Visit row ─────────────────────────────────────────────────────────────────
// N+1を避けるため ConsumerWidget をやめて StatelessWidget に変更。
// 施設名は visitListProvider が JOIN で一括取得した visit.facilityName を使う。

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit, required this.dateFormat});

  final Visit visit;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    // facilityName が null の場合は facilityId をフォールバック表示する。
    final facilityName = visit.facilityName ?? visit.facilityId;

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

// ── ゲーミフィケーションカード（G-1改善）──────────────────────────────────────

/// バッジ・ランキングへのクイックアクセスカード。
///
/// G-1対応: 以前の小さなOutlinedButtonから、獲得バッジ数とランク情報を
/// 表示する目立つカード形式に変更した。ユーザーの現在の状態を可視化して
/// 「もっと集めたい」モチベーションを高める。
class _GamificationCards extends ConsumerWidget {
  const _GamificationCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myBadgesAsync = ref.watch(myBadgesProvider);
    final myRankingAsync = ref.watch(myRankingProvider);

    final badgeCount = myBadgesAsync.valueOrNull?.length ?? 0;
    final ranking = myRankingAsync.valueOrNull?.ranking;

    return Row(
      children: [
        // ── バッジカード ──────────────────────────────────────────
        Expanded(
          child: _GamificationCard(
            onTap: () => Navigator.of(context).pushNamed('/badges'),
            backgroundColor: const Color(0xFFFFF8E1),
            borderColor: const Color(0xFFFFD54F),
            icon: const Text('🏅', style: TextStyle(fontSize: 28)),
            title: 'バッジ',
            subtitle: myBadgesAsync.isLoading
                ? '読込中...'
                : badgeCount > 0
                    ? '$badgeCount 枚獲得！'
                    : 'まだ獲得なし',
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
        // ── ランキングカード ──────────────────────────────────────
        if (AppConfig.isRankingEnabled) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _GamificationCard(
              onTap: () => Navigator.of(context).pushNamed('/ranking'),
              backgroundColor: const Color(0xFFE3F2FD),
              borderColor: const Color(0xFF90CAF9),
              icon: const Icon(Icons.leaderboard, size: 28, color: Color(0xFF1565C0)),
              title: 'ランキング',
              subtitle: myRankingAsync.isLoading
                  ? '読込中...'
                  : ranking != null
                      ? (ranking.rankPosition != null
                          ? '${ranking.rankPosition}位'
                          : ranking.currentTitle)
                      : '記録なし',
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ],
      ],
    );
  }
}

class _GamificationCard extends StatelessWidget {
  const _GamificationCard({
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Widget icon;
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // ダークモード時はコンテナ色を調整
    final bgColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : backgroundColor;
    final bdColor = isDark
        ? Theme.of(context).colorScheme.outline
        : borderColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bdColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? Theme.of(context).colorScheme.onSurface.withAlpha(178) // 0.7 * 255 ≈ 178
                    : const Color(0xFF757575),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '詳細 →',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── フォロワー数・フォロー中数（自分のプロフィール用） ──────────────────────────────

/// UX-V26-1: 自分のプロフィール画面にフォロワー数・フォロー中数を表示する。
///
/// SNSとして「自分のフォロワーが何人いるか」は重要な社会的指標であり、
/// 他ユーザーのプロフィール底シートには表示されているのに
/// 自分のプロフィール画面にないのはUXの不整合だった。
class _OwnFollowCountsRow extends ConsumerWidget {
  const _OwnFollowCountsRow({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(followCountsProvider(userId));

    return countsAsync.when(
      data: (counts) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FollowCountBadge(
            label: 'フォロワー',
            count: counts.followersCount,
          ),
          const SizedBox(width: 32),
          _FollowCountBadge(
            label: 'フォロー中',
            count: counts.followingCount,
          ),
        ],
      ),
      // UX-V28-3: ロード中・エラー時も「-」でフォールバック表示してレイアウト崩れを防ぐ。
      // SizedBox.shrink()だとプロフィール画面でスペースが急にできてガタつく。
      loading: () => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _FollowCountBadge(label: 'フォロワー', count: -1),
          SizedBox(width: 32),
          _FollowCountBadge(label: 'フォロー中', count: -1),
        ],
      ),
      error: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _FollowCountBadge(label: 'フォロワー', count: -1),
          SizedBox(width: 32),
          _FollowCountBadge(label: 'フォロー中', count: -1),
        ],
      ),
    );
  }
}

/// フォロワー数・フォロー中数を縦並びで表示するバッジ。
///
/// [count] に -1 を渡すとロード中・エラーを示す「-」を表示する。
class _FollowCountBadge extends StatelessWidget {
  const _FollowCountBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          // UX-V28-3: -1 はロード中・エラーの sentinel値。「-」で表示してUIのガタつきを防ぐ
          count < 0 ? '-' : '$count',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: const Color(0xFF757575)),
        ),
      ],
    );
  }
}
