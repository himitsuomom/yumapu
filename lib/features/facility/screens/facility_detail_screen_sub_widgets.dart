part of 'facility_detail_screen.dart';

// ── ヘッダー背景（写真カルーセル / 地図 / プレースホルダー）────────────────────

class _FacilityHeaderBackground extends StatelessWidget {
  const _FacilityHeaderBackground({
    required this.photos,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.facility,
  });

  final List<String> photos;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final Facility facility;

  @override
  Widget build(BuildContext context) {
    if (photos.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: controller,
            itemCount: photos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => PhotoGalleryViewer.show(
                context,
                photos: photos,
                initialIndex: currentIndex,
              ),
              child: Image.network(
                photos[i],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.image_not_supported,
                        size: 48, color: Colors.grey),
                  ),
                ),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : ColoredBox(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              ),
            ),
          ),
          if (photos.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  photos.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: currentIndex == i ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: currentIndex == i ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.zoom_in, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${currentIndex + 1}/${photos.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (facility.hasValidLocation) {
      return FlutterMap(
        options: MapOptions(
          initialCenter: ll.LatLng(facility.latitude, facility.longitude),
          initialZoom: AppConstants.detailZoom,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.yumap.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: ll.LatLng(facility.latitude, facility.longitude),
                width: 44,
                height: 44,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1565C0),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('♨️', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return ColoredBox(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.map_outlined, size: 80, color: Colors.grey),
      ),
    );
  }
}

// ── 固定チェックインバー ───────────────────────────────────────────────────────

class _StickyCheckinBar extends StatelessWidget {
  const _StickyCheckinBar({
    required this.facility,
    required this.isSignedIn,
    required this.isCheckingIn,
    required this.onCheckin,
  });

  final Facility facility;
  final bool isSignedIn;
  final bool isCheckingIn;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: isSignedIn
              ? FilledButton.icon(
                  icon: isCheckingIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('チェックイン'),
                  onPressed: isCheckingIn ? null : onCheckin,
                )
              : OutlinedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('ログインしてチェックイン'),
                  onPressed: () async {
                    final goLogin = await GuestRestrictionDialog.show(
                      context,
                      featureName: 'チェックイン',
                    );
                    if (goLogin == true && context.mounted) {
                      Navigator.of(context).pushNamed('/login');
                    }
                  },
                ),
        ),
      ),
    );
  }
}

// ── アクションボタン行（レビュー / プランに追加）──────────────────────────────

class _FacilityActionButtons extends StatelessWidget {
  const _FacilityActionButtons({
    required this.onPlan,
    this.onReview,
  });

  final VoidCallback onPlan;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (onReview != null) ...[
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('レビューを書く'),
                onPressed: onReview,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.playlist_add_outlined),
              label: const Text('プランに追加'),
              onPressed: onPlan,
            ),
          ),
        ],
      ),
    );
  }
}

// ── オーナー編集ボタン ─────────────────────────────────────────────────────────

class _OwnerEditButton extends ConsumerWidget {
  const _OwnerEditButton({
    required this.facilityId,
    required this.onEdit,
  });

  final String facilityId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner =
        ref.watch(isApprovedOwnerProvider(facilityId)).valueOrNull ?? false;
    if (!isOwner) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: FilledButton.icon(
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('施設情報を編集する'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }
}

// ── 施設情報改善セクション ────────────────────────────────────────────────────

class _FacilityImproveSection extends StatelessWidget {
  const _FacilityImproveSection({
    required this.onReport,
    required this.onOwner,
  });

  final VoidCallback onReport;
  final VoidCallback onOwner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '施設情報の改善に協力する',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.flag_outlined, size: 17),
                  label: const Text('情報を報告する'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: onReport,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.business_outlined, size: 17),
                  label: const Text('オーナー登録'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: onOwner,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── レビュー未投稿ビュー ──────────────────────────────────────────────────────

class _EmptyReviewView extends StatelessWidget {
  const _EmptyReviewView({
    required this.isSignedIn,
    required this.onWrite,
    required this.onLogin,
  });

  final bool isSignedIn;
  final VoidCallback onWrite;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'まだクチコミがありません',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'あなたが最初にクチコミを書いてみましょう！',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          if (isSignedIn)
            FilledButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('最初のクチコミを書く'),
              onPressed: onWrite,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.login, size: 18),
              label: const Text('ログインしてクチコミを書く'),
              onPressed: onLogin,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ── レビューフッター（ローディング / 全件表示済み）────────────────────────────

class _ReviewFooter extends StatelessWidget {
  const _ReviewFooter({
    required this.loadingMore,
    required this.hasMore,
    required this.reviewCount,
  });

  final bool loadingMore;
  final bool hasMore;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!hasMore && reviewCount > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'すべてのレビューを表示しました（$reviewCount件）',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
