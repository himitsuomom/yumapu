import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/widgets/banner_ad_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/features/facility/widgets/review_card.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/review_provider.dart';
import 'package:yu_map/providers/visit_provider.dart';
import 'package:yu_map/services/analytics_service.dart';

class FacilityDetailScreen extends ConsumerStatefulWidget {
  const FacilityDetailScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  ConsumerState<FacilityDetailScreen> createState() =>
      _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends ConsumerState<FacilityDetailScreen> {
  bool _analyticsLogged = false;

  // ── URL helpers ───────────────────────────────────────────────────────────

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リンクを開けませんでした')),
      );
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('電話を発信できませんでした')),
      );
    }
  }

  // ── Check-in dialog ───────────────────────────────────────────────────────

  Future<void> _showCheckinDialog(Facility facility) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('チェックイン'),
        content: Text('${facility.name}にチェックインしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('チェックイン'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref
        .read(visitNotifierProvider.notifier)
        .logVisit(facilityId: facility.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('チェックインしました')),
    );
  }

  // ── Review sheet ──────────────────────────────────────────────────────────

  void _showReviewSheet(Facility facility) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ReviewSheet(
        facilityId: facility.id,
        onSubmitted: () {
          ref.invalidate(reviewListProvider(facility.id));
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Log analytics once when facility data becomes available
    ref.listen(facilityDetailProvider(widget.facilityId), (_, next) {
      if (_analyticsLogged) return;
      next.whenData((facility) {
        if (facility != null) {
          _analyticsLogged = true;
          AnalyticsService.instance.logFacilityView(
            facilityId: facility.id,
            facilityName: facility.name,
          );
        }
      });
    });

    final facilityAsync = ref.watch(facilityDetailProvider(widget.facilityId));

    return facilityAsync.when(
      data: (facility) {
        if (facility == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('施設詳細')),
            body: const AppErrorWidget(message: '施設が見つかりませんでした'),
          );
        }
        return _buildScaffold(facility);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('施設詳細')),
        body: const LoadingWidget(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('施設詳細')),
        body: AppErrorWidget(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(facilityDetailProvider(widget.facilityId)),
        ),
      ),
    );
  }

  Widget _buildScaffold(Facility facility) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final isFavorite = ref.watch(isFavoriteProvider(facility.id));
    final reviewAsync = ref.watch(reviewListProvider(facility.id));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Map header ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                facility.name,
                style: const TextStyle(
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: facility.hasValidLocation
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target:
                            LatLng(facility.latitude, facility.longitude),
                        zoom: AppConstants.detailZoom,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId(facility.id),
                          position:
                              LatLng(facility.latitude, facility.longitude),
                          infoWindow: InfoWindow(title: facility.name),
                        ),
                      },
                      scrollGesturesEnabled: false,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                    )
                  : ColoredBox(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.map_outlined,
                            size: 80, color: Colors.grey),
                      ),
                    ),
            ),
            actions: [
              // Favorite button — login only
              if (isSignedIn)
                IconButton(
                  tooltip: isFavorite ? 'お気に入りを解除' : 'お気に入りに追加',
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: () =>
                      ref.read(favoritesProvider.notifier).toggle(facility.id),
                ),
            ],
          ),

          // ── Facility info ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _FacilityInfoSection(
              facility: facility,
              onPhone: facility.phone != null
                  ? () => _launchPhone(facility.phone!)
                  : null,
              onWebsite: facility.website != null
                  ? () => _launchUrl(facility.website!)
                  : null,
            ),
          ),

          // ── Action buttons (login only) ────────────────────────────────
          if (isSignedIn)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('チェックイン'),
                        onPressed: () => _showCheckinDialog(facility),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('レビューを書く'),
                        onPressed: () => _showReviewSheet(facility),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Reviews header ─────────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'レビュー',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // ── Review list ────────────────────────────────────────────────
          reviewAsync.when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('まだレビューはありません')),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => ReviewCard(
                    review: reviews[i],
                    onLike: isSignedIn
                        ? () => ref
                            .read(reviewNotifierProvider.notifier)
                            .likeReview(reviews[i].id)
                        : null,
                  ),
                  childCount: reviews.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: AppErrorWidget(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(reviewListProvider(facility.id)),
              ),
            ),
          ),

          // ── Banner ad ──────────────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: BannerAdWidget()),
            ),
          ),

          // Bottom padding for safe area
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Facility info section ─────────────────────────────────────────────────────

class _FacilityInfoSection extends StatelessWidget {
  const _FacilityInfoSection({
    required this.facility,
    this.onPhone,
    this.onWebsite,
  });

  final Facility facility;
  final VoidCallback? onPhone;
  final VoidCallback? onWebsite;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Facility type chip
          if (facility.facilityType != null) ...[
            Chip(
              label: Text(facility.facilityType!),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 8),
          ],
          // Address
          if (facility.address != null)
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: facility.address!,
              textStyle: textTheme.bodyMedium,
            ),
          // Phone
          if (facility.phone != null)
            _InfoRow(
              icon: Icons.phone_outlined,
              text: facility.phone!,
              textStyle: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              onTap: onPhone,
            ),
          // Website
          if (facility.website != null)
            _InfoRow(
              icon: Icons.language_outlined,
              text: facility.website!,
              textStyle: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              onTap: onWebsite,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.textStyle,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final TextStyle? textStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF757575)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: textStyle)),
          ],
        ),
      ),
    );
  }
}

// ── Review bottom sheet ───────────────────────────────────────────────────────

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.facilityId, required this.onSubmitted});

  final String facilityId;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _rating = 3;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(reviewNotifierProvider.notifier).postReview(
          facilityId: widget.facilityId,
          content: _contentController.text.trim(),
          rating: _rating,
        );
    if (!mounted) return;
    final reviewState = ref.read(reviewNotifierProvider);
    reviewState.whenOrNull(
      data: (_) {
        widget.onSubmitted();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('レビューを投稿しました')),
        );
      },
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(reviewNotifierProvider) is AsyncLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'レビューを書く',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Star rating selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFFFC107),
                    size: 32,
                  ),
                  onPressed: () => setState(() => _rating = star),
                );
              }),
            ),
            const SizedBox(height: 12),
            // Review text field
            TextFormField(
              controller: _contentController,
              maxLines: 5,
              maxLength: AppConstants.maxReviewLength,
              enabled: !isLoading,
              decoration: const InputDecoration(
                hintText: '施設の感想をお書きください（10文字以上）',
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().length < AppConstants.minReviewLength) {
                  return '${AppConstants.minReviewLength}文字以上で入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('投稿する'),
            ),
          ],
        ),
      ),
    );
  }
}
