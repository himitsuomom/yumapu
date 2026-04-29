part of 'facility_preview_sheet.dart';

// ── お気に入りボタン ──────────────────────────────────────────────────────────

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton(
      {required this.facilityId, required this.isFav});

  final String facilityId;
  final bool isFav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () =>
          ref.read(favoritesProvider.notifier).toggle(facilityId),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(isFav),
          color: isFav ? Colors.red[400] : Colors.grey[400],
          size: 28,
        ),
      ),
      tooltip: isFav ? 'お気に入りから外す' : 'お気に入りに追加',
    );
  }
}

// ── 星評価表示 ────────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  const _StarRating({
    required this.avg,
    required this.count,
    required this.color,
  });

  final double avg;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < avg.floor()) {
            return Icon(Icons.star, size: 14, color: color);
          } else if (i < avg) {
            return Icon(Icons.star_half, size: 14, color: color);
          } else {
            return Icon(Icons.star_border,
                size: 14, color: Colors.grey[400]);
          }
        }),
        const SizedBox(width: 4),
        Text(
          avg.toStringAsFixed(1),
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color),
        ),
        const SizedBox(width: 3),
        Text(
          '($count件)',
          style:
              TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

// ── 情報行 ────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.isUnknown = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  /// true のとき値テキストをグレーで表示する（「料金不明」などデータ欠損を示す場合）
  final bool isUnknown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18,
              color: isUnknown ? Colors.grey[400] : iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: isUnknown ? Colors.grey[400] : null,
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

// ── アクションチップ ──────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── クチコミ1件タイル ─────────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: Colors.grey[200],
                backgroundImage: review.authorAvatarUrl != null
                    ? CachedNetworkImageProvider(
                        review.authorAvatarUrl!)
                    : null,
                child: review.authorAvatarUrl == null
                    ? Icon(Icons.person,
                        size: 14, color: Colors.grey[500])
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.authorDisplayName ?? '匿名ユーザー',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star
                        : Icons.star_border,
                    size: 11,
                    color: const Color(0xFFFFC107),
                  ),
                ),
              ),
            ],
          ),
          if (review.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.content,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Divider(height: 14),
        ],
      ),
    );
  }
}
