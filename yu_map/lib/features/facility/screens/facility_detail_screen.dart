import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/review_provider.dart';
import 'package:yu_map/providers/visit_provider.dart';
import 'package:yu_map/features/reviews/screens/write_review_screen.dart';
import 'package:yu_map/features/facility/widgets/review_card.dart';
import 'package:yu_map/core/widgets/banner_ad_widget.dart';
import 'package:yu_map/services/analytics_service.dart';

class FacilityDetailScreen extends ConsumerWidget {
  const FacilityDetailScreen({super.key, required this.facilityId});
  final String facilityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilityAsync = ref.watch(facilityDetailProvider(facilityId));
    final reviewsAsync = ref.watch(facilityReviewsProvider(facilityId));
    final favIds = ref.watch(favoritesProvider).valueOrNull ?? {};
    final isFavorite = favIds.contains(facilityId);
    final isSignedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      body: facilityAsync.when(
        loading: () => const LoadingWidget(message: '施設情報を読み込み中...'),
        error: (e, _) => AppErrorWidget(
          message: '施設情報の取得に失敗しました',
          onRetry: () => ref.invalidate(facilityDetailProvider(facilityId)),
        ),
        data: (facility) {
          if (facility == null) {
            return const AppErrorWidget(message: '施設が見つかりませんでした');
          }
          AnalyticsService.instance.logFacilityView(
            facilityId: facility.id,
            facilityName: facility.name,
          );
          return CustomScrollView(
            slivers: [
              // App bar with map
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    facility.name,
                    style: const TextStyle(
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 8)],
                    ),
                  ),
                  background: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(facility.latitude, facility.longitude),
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: MarkerId(facility.id),
                        position: LatLng(facility.latitude, facility.longitude),
                      ),
                    },
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    // liteModeEnabled is Android-only; omitted for cross-platform safety.
                  ),
                ),
                actions: [
                  if (isSignedIn)
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.white,
                      ),
                      onPressed: () =>
                          ref.read(favoritesProvider.notifier).toggle(facilityId),
                    ),
                ],
              ),

              // Info section
              SliverToBoxAdapter(
                child: _InfoSection(facility: facility, ref: ref),
              ),

              // Action buttons
              if (isSignedIn)
                SliverToBoxAdapter(
                  child: _ActionButtons(
                    facilityId: facilityId,
                    ref: ref,
                    context: context,
                  ),
                ),

              // Reviews header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'レビュー',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (isSignedIn)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WriteReviewScreen(
                                  facilityId: facilityId,
                                  facilityName: facility.name,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('レビューを書く'),
                        ),
                    ],
                  ),
                ),
              ),

              // Reviews list
              reviewsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: LoadingWidget(),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: AppErrorWidget(
                    message: 'レビューの取得に失敗しました',
                    onRetry: () =>
                        ref.invalidate(facilityReviewsProvider(facilityId)),
                  ),
                ),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'まだレビューがありません',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => ReviewCard(review: reviews[i]),
                      childCount: reviews.length,
                    ),
                  );
                },
              ),

              // Banner ad
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: BannerAdWidget()),
                ),
              ),

              // Bottom padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.facility, required this.ref});
  final Facility facility;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (facility.nameKana != null) ...[
            Text(
              facility.nameKana!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 4),
          ],
          if (facility.address != null) ...[
            _infoRow(Icons.location_on, facility.address!),
            const SizedBox(height: 8),
          ],
          if (facility.phone != null) ...[
            _infoRow(Icons.phone, facility.phone!, onTap: () {
              launchUrl(Uri.parse('tel:${facility.phone}'));
            }),
            const SizedBox(height: 8),
          ],
          if (facility.website != null) ...[
            _infoRow(Icons.language, facility.website!, onTap: () {
              launchUrl(Uri.parse(facility.website!));
            }),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: onTap != null ? Colors.blue : null,
                decoration: onTap != null ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.facilityId,
    required this.ref,
    required this.context,
  });
  final String facilityId;
  final WidgetRef ref;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    final checkInState = ref.watch(checkInProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: checkInState is AsyncLoading
                  ? null
                  : () async {
                      final success = await ref
                          .read(checkInProvider.notifier)
                          .checkIn(facilityId);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('チェックインしました！')),
                        );
                      }
                    },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('チェックイン'),
            ),
          ),
        ],
      ),
    );
  }
}
