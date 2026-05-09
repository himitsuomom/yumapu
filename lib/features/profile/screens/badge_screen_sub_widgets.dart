part of 'badge_screen.dart';

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
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('すべて'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
              visualDensity: VisualDensity.compact,
            ),
          ),
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
                onSelected: (_) => onSelected(selected == cat ? null : cat),
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

// ── エラー表示（リトライ付き）─────────────────────────────────────────────────

class _RetryView extends StatelessWidget {
  const _RetryView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: Color(0xFF9E9E9E)),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF757575)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('もう一度試す'),
            ),
          ],
        ),
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
