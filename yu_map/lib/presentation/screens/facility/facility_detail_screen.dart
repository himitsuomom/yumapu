// lib/presentation/screens/facility/facility_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/providers/facility_providers.dart';
import 'package:yu_map/providers/review_providers.dart';
import 'package:yu_map/providers/favorite_providers.dart';
import 'package:yu_map/providers/service_providers.dart';
import 'package:yu_map/presentation/widgets/review_card.dart';
import 'package:image_picker/image_picker.dart';

/// Photos for a specific facility.
final _facilityPhotosProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, facilityId) async {
  final photoService = ref.watch(photoServiceProvider);
  return photoService.getPhotosForFacility(facilityId);
});

class FacilityDetailScreen extends ConsumerWidget {
  final String facilityId;

  const FacilityDetailScreen({super.key, required this.facilityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilityAsync = ref.watch(facilityDetailProvider(facilityId));
    final reviewsAsync = ref.watch(facilityReviewsProvider(facilityId));
    final avgRatingAsync =
        ref.watch(facilityAverageRatingProvider(facilityId));
    final isFavAsync = ref.watch(isFavoriteProvider(facilityId));

    return Scaffold(
      body: facilityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (facility) {
          if (facility == null) {
            return const Center(child: Text('施設が見つかりません'));
          }
          return CustomScrollView(
            slivers: [
              // ── Hero header ──
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    facility.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha(153), // ~60% opacity
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.hot_tub, size: 80, color: Colors.white70),
                    ),
                  ),
                ),
                actions: [
                  // Favorite button
                  isFavAsync.when(
                    data: (isFav) => IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : null,
                      ),
                      onPressed: () {
                        ref.read(favoriteNotifierProvider.notifier).toggle(
                              facilityId,
                              currentlyFavorited: isFav,
                            );
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),

              // ── Info section ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating summary
                      avgRatingAsync.when(
                        data: (avg) => Row(
                          children: [
                            RatingBarIndicator(
                              rating: avg,
                              itemBuilder: (_, __) =>
                                  const Icon(Icons.star, color: Colors.amber),
                              itemCount: 5,
                              itemSize: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              avg.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),

                      // Address
                      if (facility.address != null) ...[
                        _InfoRow(
                          icon: Icons.location_on,
                          text: facility.address!,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Phone
                      if (facility.phone != null) ...[
                        _InfoRow(icon: Icons.phone, text: facility.phone!),
                        const SizedBox(height: 8),
                      ],

                      // Website
                      if (facility.website != null) ...[
                        _InfoRow(icon: Icons.language, text: facility.website!),
                        const SizedBox(height: 8),
                      ],

                      const Divider(height: 32),

                      // Amenity tags
                      Text(
                        'アメニティ',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _AmenityChips(amenities: facility.amenities),

                      const Divider(height: 32),

                      // Photos section
                      _PhotoSection(facilityId: facilityId),

                      const Divider(height: 32),

                      // Check-in button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(visitServiceProvider)
                                  .checkIn(facilityId: facilityId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('チェックインしました!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('チェックインする'),
                        ),
                      ),

                      const Divider(height: 32),

                      // Reviews header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'レビュー',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                context.push('/facility/$facilityId/review'),
                            icon: const Icon(Icons.rate_review, size: 18),
                            label: const Text('レビューを書く'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Reviews list ──
              reviewsAsync.when(
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('まだレビューがありません'),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ReviewCard(review: reviews[index]),
                      ),
                      childCount: reviews.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Error: $e')),
                ),
              ),

              // Bottom padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _AmenityChips extends StatelessWidget {
  final Map<String, dynamic> amenities;

  const _AmenityChips({required this.amenities});

  static const _labels = {
    'sauna': 'サウナ',
    'tattoo_friendly': 'タトゥーOK',
    'outdoor_bath': '露天風呂',
    'cold_plunge': '水風呂',
    'natural_hot_spring': '天然温泉',
    'parking': '駐車場',
    'lodging': '宿泊可',
    'mixed_bath': '混浴',
    'stone_sauna': '岩盤浴',
  };

  @override
  Widget build(BuildContext context) {
    final active = amenities.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    if (active.isEmpty) {
      return const Text('情報なし', style: TextStyle(color: Colors.grey));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: active.map((code) {
        return Chip(
          label: Text(_labels[code] ?? code),
          avatar: const Icon(Icons.check_circle, size: 16),
        );
      }).toList(),
    );
  }
}

class _PhotoSection extends ConsumerWidget {
  final String facilityId;

  const _PhotoSection({required this.facilityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(_facilityPhotosProvider(facilityId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('写真', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: () => _uploadPhoto(context, ref),
              icon: const Icon(Icons.add_a_photo, size: 18),
              label: const Text('写真を追加'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        photosAsync.when(
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (photos) {
            if (photos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'まだ写真がありません',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            return SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final url = photos[index]['public_url'] as String?;
                  if (url == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _uploadPhoto(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final fileName = image.name;

      if (!context.mounted) return;

      // Show upload progress
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真をアップロード中...')),
      );

      await ref.read(photoServiceProvider).uploadPhoto(
            fileBytes: bytes,
            fileName: fileName,
            facilityId: facilityId,
          );

      // Refresh photos
      ref.invalidate(_facilityPhotosProvider(facilityId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写真をアップロードしました!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('アップロード失敗: $e')),
        );
      }
    }
  }
}
