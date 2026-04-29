// lib/features/profile/screens/badge_screen.dart
//
// バッジ一覧画面
// ユーザーが獲得したバッジをグリッド形式で表示する。
// 「全バッジ / 獲得済み」をタブで切り替えられる。
// 未獲得のバッジに進捗インジケーター（あとX回など）を表示する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yu_map/models/badge.dart';
import 'package:yu_map/providers/badge_provider.dart';
import 'package:yu_map/providers/visit_provider.dart';

class BadgeScreen extends ConsumerStatefulWidget {
  const BadgeScreen({super.key});

  @override
  ConsumerState<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends ConsumerState<BadgeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static final _dateFormat = DateFormat('yyyy/MM/dd');

  // 全バッジタブのカテゴリフィルター
  String? _selectedCategory; // null = すべて

  @override
  void initState() {
    super.initState();
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
    // チェックイン数（進捗表示に使用）
    final checkInCount = ref.watch(visitCountProvider).valueOrNull ?? 0;

    final myCount = myBadgesAsync.valueOrNull?.length ?? 0;
    final allCount = allBadgesAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('バッジ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '獲得済み${myCount > 0 ? " ($myCount)" : ""}'),
            const Tab(text: '全バッジ'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── 獲得進捗サマリーヘッダー ──────────────────────────────
          if (allCount > 0)
            _BadgeProgressHeader(
              earned: myCount,
              total: allCount,
              checkInCount: checkInCount,
            ),
          // ── タブコンテンツ ────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 獲得済みタブ
                myBadgesAsync.when(
                  data: (badges) => badges.isEmpty
                      ? const _EmptyBadgeView()
                      : _EarnedBadgeGrid(
                          badges: badges,
                          dateFormat: _dateFormat,
                          checkInCount: checkInCount,
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('取得エラー: $e')),
                ),

                // 全バッジタブ
                allBadgesAsync.when(
                  data: (allBadges) {
                    final earnedIds = myBadgesAsync.valueOrNull
                            ?.map((ub) => ub.badge.id)
                            .toSet() ??
                        {};
                    // カテゴリフィルター適用
                    final filtered = _selectedCategory == null
                        ? allBadges
                        : allBadges
                            .where((b) => b.category == _selectedCategory)
                            .toList();
                    return Column(
                      children: [
                        // カテゴリフィルターチップ
                        _CategoryFilterBar(
                          allBadges: allBadges,
                          selected: _selectedCategory,
                          onSelected: (cat) =>
                              setState(() => _selectedCategory = cat),
                        ),
                        Expanded(
                          child: _AllBadgeList(
                            allBadges: filtered,
                            earnedIds: earnedIds,
                            checkInCount: checkInCount,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('取得エラー: $e')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 獲得進捗サマリーヘッダー ─────────────────────────────────────────────────

class _BadgeProgressHeader extends StatelessWidget {
  const _BadgeProgressHeader({
    required this.earned,
    required this.total,
    required this.checkInCount,
  });

  final int earned;
  final int total;
  final int checkInCount;

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? earned / total : 0.0;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: colorScheme.primaryContainer.withAlpha(80),
      child: Row(
        children: [
          // 円形進捗インジケーター
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  strokeWidth: 5,
                  backgroundColor: colorScheme.outline.withAlpha(50),
                  color: colorScheme.primary,
                ),
                Center(
                  child: Text(
                    '${(ratio * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$earned / $total バッジ獲得',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  backgroundColor: colorScheme.outline.withAlpha(50),
                  color: colorScheme.primary,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 2),
                Text(
                  '合計チェックイン: $checkInCount 回',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withAlpha(160),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── カテゴリフィルターバー ──────────────────────────────────────────────────────

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.allBadges,
    required this.selected,
    required this.onSelected,
  });

  final List<AppBadge> allBadges;
  final String? selected;
  final void Function(String? category) onSelected;

  @override
  Widget build(BuildContext context) {
    // 存在するカテゴリの一意リストを順序付きで取得
    final seen = <String>{};
    final categories = allBadges
        .map((b) => b.category)
        .whereType<String>()
        .where(seen.add)
        .toList();

    return SizedBox(
      height: 44,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        children: [
          // 「すべて」チップ
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('すべて'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
              visualDensity: VisualDensity.compact,
            ),
          ),
          // カテゴリ別チップ
          ...categories.map((cat) {
            final label = AppBadge(
              id: '',
              code: '',
              nameJa: '',
              nameEn: '',
              category: cat,
              requirements: const {},
            ).categoryLabel;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(label),
                selected: selected == cat,
                onSelected: (_) =>
                    onSelected(selected == cat ? null : cat),
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
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
    required this.checkInCount,
  });

  final List<UserBadge> badges;
  final DateFormat dateFormat;
  final int checkInCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.8,
        ),
        itemCount: badges.length,
        itemBuilder: (context, index) {
          final ub = badges[index];
          return _BadgeTile(
            badge: ub.badge,
            earnedAt: ub.earnedAt,
            dateFormat: dateFormat,
            isEarned: true,
            checkInCount: checkInCount,
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
    required this.checkInCount,
  });

  final List<AppBadge> allBadges;
  final Set<String> earnedIds;
  final int checkInCount;

  @override
  Widget build(BuildContext context) {
    // カテゴリごとにグループ化
    final Map<String, List<AppBadge>> grouped = {};
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
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: entry.value.length,
              itemBuilder: (context, index) {
                final badge = entry.value[index];
                return _BadgeTile(
                  badge: badge,
                  earnedAt: null,
                  dateFormat: null,
                  isEarned: earnedIds.contains(badge.id),
                  checkInCount: checkInCount,
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
    required this.checkInCount,
  });

  final AppBadge badge;
  final DateTime? earnedAt;
  final DateFormat? dateFormat;
  final bool isEarned;
  final int checkInCount;

  @override
  Widget build(BuildContext context) {
    // visit_count 型のバッジについて進捗を計算する
    final progressInfo = _computeProgress();

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: AnimatedOpacity(
        opacity: isEarned ? 1.0 : 0.55,
        duration: const Duration(milliseconds: 200),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // アイコン表示（URL があれば画像、なければ絵文字）
                _BadgeIcon(badge: badge, size: 36),
                const SizedBox(height: 4),
                Text(
                  badge.nameJa,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // 獲得済みの場合は取得日を表示
                if (isEarned && earnedAt != null && dateFormat != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateFormat!.format(earnedAt!),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
                // 未獲得でvisit_count型の場合は進捗バーを表示
                if (!isEarned && progressInfo != null) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progressInfo.progressRatio.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF1565C0),
                    minHeight: 3,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    progressInfo.remainText,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF1565C0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                // 未獲得でvisit_count型以外の場合は獲得条件テキストを表示する。
                // badge.requirementText は Badge モデルが自動生成する人間が読めるテキスト。
                // 例: 「草津温泉を訪問」「お気に入りを10件追加」など
                if (!isEarned && progressInfo == null) ...[
                  const SizedBox(height: 4),
                  Text(
                    badge.requirementText,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF757575),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// visit_count 型バッジの進捗情報を返す。
  /// 他タイプのバッジは null を返す（進捗表示なし）。
  _ProgressInfo? _computeProgress() {
    if (isEarned) return null;
    final type = badge.requirements['type'] as String?;
    if (type != 'visit_count') return null;
    final required = (badge.requirements['count'] as num?)?.toInt() ?? 0;
    if (required <= 0) return null;

    final current = checkInCount.clamp(0, required);
    final remain = required - current;
    return _ProgressInfo(
      current: current,
      total: required,
      progressRatio: current / required,
      remainText: remain > 0 ? 'あと$remain回' : 'もうすぐ！',
    );
  }

  void _showDetail(BuildContext context) {
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
            // バッジの説明文（DBに登録されている場合）
            if (badge.descriptionJa != null && badge.descriptionJa!.isNotEmpty) ...[
              Text(badge.descriptionJa!),
              const SizedBox(height: 8),
            ],
            // 獲得条件（requirementsから生成）
            Text(
              '📋 獲得条件: ${badge.requirementText}',
              style: const TextStyle(fontSize: 13),
            ),
            // 進捗（visit_count型かつ未獲得の場合）
            if (!isEarned) ...[
              (() {
                final info = _computeProgress();
                if (info == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: info.progressRatio.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF1565C0),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '現在: ${info.current} / ${info.total} 回 (${info.remainText})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              })(),
            ],
            // カテゴリ
            const SizedBox(height: 8),
            Text(
              'カテゴリ: ${badge.categoryLabel}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF757575),
              ),
            ),
            // 獲得日（獲得済みの場合）
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
              const SizedBox(height: 4),
              const Text(
                '🔒 まだ獲得していません',
                style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
              ),
            ],
          ],
        ),
        actions: [
          // 獲得済みバッジはシェアボタンを表示する
          if (isEarned)
            TextButton.icon(
              icon: const Icon(Icons.share_outlined, size: 16),
              label: const Text('シェア'),
              onPressed: () {
                final msg = '湯マップで「${badge.nameJa}」バッジを獲得しました！\n'
                    '${badge.descriptionJa != null && badge.descriptionJa!.isNotEmpty ? badge.descriptionJa! : badge.requirementText}\n'
                    '#湯マップ #温泉 #サウナ';
                Share.share(msg);
              },
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

// ── 進捗情報 ──────────────────────────────────────────────────────────────────

class _ProgressInfo {
  const _ProgressInfo({
    required this.current,
    required this.total,
    required this.progressRatio,
    required this.remainText,
  });

  final int current;
  final int total;
  final double progressRatio;
  final String remainText;
}

// ── バッジアイコン ─────────────────────────────────────────────────────────────

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.badge, required this.size});

  final AppBadge badge;
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
