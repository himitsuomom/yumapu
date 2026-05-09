part of 'facility_preview_sheet.dart';

// ── ドラッグハンドル + 閉じるボタン ──────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Positioned(
          right: 4,
          top: 2,
          child: IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: Colors.grey[500],
            tooltip: '閉じる',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

// ── 写真プレースホルダー ────────────────────────────────────────────────────

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({
    required this.isLoading,
    required this.typeColor,
    required this.isUploading,
    required this.onAddPhoto,
  });

  final bool isLoading;
  final Color typeColor;
  final bool isUploading;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      color: typeColor.withValues(alpha: 0.06),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: typeColor),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined,
                      size: 44, color: typeColor.withValues(alpha: 0.4)),
                  const SizedBox(height: 6),
                  Text(
                    '写真はまだありません',
                    style:
                        TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  isUploading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: typeColor),
                        )
                      : FilledButton.tonalIcon(
                          onPressed: onAddPhoto,
                          icon: const Icon(
                              Icons.add_photo_alternate, size: 16),
                          label: const Text('写真を追加'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                ],
              ),
      ),
    );
  }
}

// ── 写真カルーセル ─────────────────────────────────────────────────────────

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({
    required this.urls,
    required this.typeColor,
    required this.isUploading,
    required this.onAddPhoto,
  });

  final List<String> urls;
  final Color typeColor;
  final bool isUploading;
  final VoidCallback onAddPhoto;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final typeColor = widget.typeColor;

    return SizedBox(
      height: 210,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => PhotoGalleryViewer.show(
                  context,
                  photos: urls,
                  initialIndex: _currentIndex,
                ),
                child: CachedNetworkImage(
                  imageUrl: urls[index],
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: typeColor.withValues(alpha: 0.08),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: typeColor),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[100],
                    child: Icon(Icons.broken_image,
                        color: Colors.grey[400], size: 36),
                  ),
                ),
              );
            },
          ),
          if (urls.length > 1)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${urls.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Positioned(
            left: 10,
            bottom: 10,
            child: widget.isUploading
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : GestureDetector(
                    onTap: widget.onAddPhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            '写真を追加',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

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
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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

// ── カラー・アイコンヘルパー ──────────────────────────────────────────────────

Color _colorForType(String? type) {
  switch (type?.toLowerCase()) {
    case 'onsen':
      return const Color(0xFFE53935);
    case 'public_bath':
      return const Color(0xFF1976D2);
    case 'sauna':
      return const Color(0xFF2E7D32);
    default:
      return const Color(0xFF7B1FA2);
  }
}

String _emojiForType(String? type) {
  switch (type?.toLowerCase()) {
    case 'onsen':
      return '♨';
    case 'public_bath':
      return '🛁';
    case 'sauna':
      return '🧖';
    default:
      return '♨';
  }
}

