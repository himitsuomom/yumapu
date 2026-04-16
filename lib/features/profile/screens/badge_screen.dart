// lib/features/profile/screens/badge_screen.dart
//
// バッジ一覧画面
// ユーザーが獲得したバッジをグリッド形式で表示する。
// 「全バッジ / 獲得済み」をタブで切り替えられる。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/models/badge.dart';
import 'package:yu_map/providers/badge_provider.dart';

class BadgeScreen extends ConsumerStatefulWidget {
  const BadgeScreen({super.key});

  @override
  ConsumerState<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends ConsumerState<BadgeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static final _dateFormat = DateFormat('yyyy/MM/dd');

  @override
  void initState() {
    super.initState();
    // TabController = タブの切り替えを管理するコントローラー
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myBadgesAsync = ref.watch(myBadgesProvider);
    final allBadgesAsync = ref.watch(allBadgesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('バッジ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '獲得済み'),
            Tab(text: '全バッジ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── 獲得済みタブ ──────────────────────────────────────────────
          myBadgesAsync.when(
            data: (badges) => badges.isEmpty
                ? const _EmptyBadgeView()
                : _EarnedBadgeGrid(
                    badges: badges,
                    dateFormat: _dateFormat,
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('取得エラー: $e')),
          ),

          // ── 全バッジタブ ──────────────────────────────────────────────
          allBadgesAsync.when(
            data: (allBadges) {
              // 獲得済み badge の ID セットを使ってロック状態を判定
              final earnedIds = myBadgesAsync.valueOrNull
                      ?.map((ub) => ub.badge.id)
                      .toSet() ??
                  {};
              return _AllBadgeList(
                allBadges: allBadges,
                earnedIds: earnedIds,
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('取得エラー: $e')),
          ),
        ],
      ),
    );
  }
}

// ── 獲得済みバッジのグリッド ───────────────────────────────────────────────────

class _EarnedBadgeGrid extends StatelessWidget {
  const _EarnedBadgeGrid({
    required this.badges,
    required this.dateFormat,
  });

  final List<UserBadge> badges;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,       // 3列
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,  // 縦長にしてテキストを収める
        ),
        itemCount: badges.length,
        itemBuilder: (context, index) {
          final ub = badges[index];
          return _BadgeTile(
            badge: ub.badge,
            earnedAt: ub.earnedAt,
            dateFormat: dateFormat,
            isEarned: true,
          );
        },
      ),
    );
  }
}

// ── 全バッジのカテゴリ別リスト ─────────────────────────────────────────────────

class _AllBadgeList extends StatelessWidget {
  const _AllBadgeList({
    required this.allBadges,
    required this.earnedIds,
  });

  final List<Badge> allBadges;
  final Set<String> earnedIds;

  @override
  Widget build(BuildContext context) {
    // カテゴリごとにグループ化
    final Map<String, List<Badge>> grouped = {};
    for (final badge in allBadges) {
      final cat = badge.categoryLabel;
      grouped.putIfAbsent(cat, () => []).add(badge);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1565C0),
                    ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,     // ListView の子として使うために必要
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: entry.value.length,
              itemBuilder: (context, index) {
                final badge = entry.value[index];
                return _BadgeTile(
                  badge: badge,
                  earnedAt: null,
                  dateFormat: null,
                  isEarned: earnedIds.contains(badge.id),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}

// ── バッジタイル（グリッドの1マス） ─────────────────────────────────────────────

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.earnedAt,
    required this.dateFormat,
    required this.isEarned,
  });

  final Badge badge;
  final DateTime? earnedAt;
  final DateFormat? dateFormat;
  final bool isEarned;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: AnimatedOpacity(
        // 未獲得バッジは半透明でグレーアウト表示
        opacity: isEarned ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 200),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // アイコン表示（URL があれば画像、なければ絵文字）
                _BadgeIcon(badge: badge, size: 40),
                const SizedBox(height: 6),
                Text(
                  badge.nameJa,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (earnedAt != null && dateFormat != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateFormat!.format(earnedAt!),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    // タップで詳細ダイアログを表示
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            _BadgeIcon(badge: badge, size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text(badge.nameJa)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge.descriptionJa != null) ...[
              Text(badge.descriptionJa!),
              const SizedBox(height: 8),
            ],
            Text(
              'カテゴリ: ${badge.categoryLabel}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF757575),
              ),
            ),
            if (isEarned && earnedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '取得日: ${dateFormat?.format(earnedAt!) ?? ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1565C0),
                ),
              ),
            ] else if (!isEarned) ...[
              const SizedBox(height: 8),
              const Text(
                '🔒 まだ獲得していません',
                style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

// ── バッジアイコン ─────────────────────────────────────────────────────────────

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.badge, required this.size});

  final Badge badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = badge.iconUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _EmojiIcon(
          text: badge.displayIcon,
          size: size,
        ),
      );
    }
    return _EmojiIcon(text: badge.displayIcon, size: size);
  }
}

class _EmojiIcon extends StatelessWidget {
  const _EmojiIcon({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(text, style: TextStyle(fontSize: size * 0.7)),
      ),
    );
  }
}

// ── バッジ未獲得の空表示 ──────────────────────────────────────────────────────

class _EmptyBadgeView extends StatelessWidget {
  const _EmptyBadgeView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏅', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'まだバッジを獲得していません',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '施設を訪問・レビューしてバッジをゲットしよう！',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color(0xFF757575)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
