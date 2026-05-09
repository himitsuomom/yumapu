part of 'facility_preview_sheet.dart';

// ── URL ランチャーヘルパー ─────────────────────────────────────────────────────

Future<void> _launchPhone(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  try {
    await launchUrl(uri);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('電話を発信できませんでした')),
    );
  }
}

Future<void> _launchWeb(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ウェブサイトを開けませんでした')),
    );
  }
}

Future<void> _launchMap(
  BuildContext context,
  double lat,
  double lng, {
  required String name,
}) async {
  final encodedName = Uri.encodeComponent(name);
  final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedName)');
  final appleMapsUri =
      Uri.parse('https://maps.apple.com/?ll=$lat,$lng&q=$encodedName');
  try {
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    } else {
      await launchUrl(appleMapsUri,
          mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('地図アプリを開けませんでした')),
    );
  }
}

// ── 施設情報カード（名前・評価・アメニティ・アクション）────────────────────────

class _FacilityInfoCard extends ConsumerWidget {
  const _FacilityInfoCard({
    required this.facility,
    required this.typeColor,
    required this.onShare,
  });

  final Facility facility;
  final Color typeColor;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(isFavoriteProvider(facility.id));
    final reviewSummaryAsync =
        ref.watch(facilityReviewSummaryProvider(facility.id));
    final reviewsAsync = ref.watch(reviewListProvider(facility.id));
    final amenitiesAsync =
        ref.watch(facilityAmenitiesProvider(facility.id));

    final summary = reviewSummaryAsync.valueOrNull;
    final reviewCount = summary?.count ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (facility.hasFacilityType)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _emojiForType(facility.facilityType),
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            facility.facilityTypeJa,
                            style: TextStyle(
                              fontSize: 11,
                              color: typeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    facility.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  if (reviewCount == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'クチコミなし',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400]),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _StarRating(
                        avg: _resolveAvgRating(summary, reviewsAsync),
                        count: reviewCount,
                        color: typeColor,
                      ),
                    ),
                  amenitiesAsync.whenOrNull(
                        data: (amenities) {
                          if (amenities.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: amenities.map((amenity) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: typeColor
                                        .withValues(alpha: 0.08),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: typeColor
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    amenity.nameJa,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: typeColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ) ??
                      const SizedBox.shrink(),
                  if (facility.phone != null &&
                          facility.phone!.isNotEmpty ||
                      facility.website != null &&
                          facility.website!.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 8, bottom: 4),
                      child: Row(
                        children: [
                          if (facility.phone != null &&
                              facility.phone!.isNotEmpty) ...[
                            _ActionChip(
                              icon: Icons.phone_outlined,
                              label: '電話',
                              color: typeColor,
                              onTap: () => _launchPhone(
                                  context, facility.phone!),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (facility.website != null &&
                              facility.website!.isNotEmpty)
                            _ActionChip(
                              icon: Icons.language_outlined,
                              label: 'ウェブ',
                              color: typeColor,
                              onTap: () => _launchWeb(
                                  context, facility.website!),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _ActionChip(
                    icon: Icons.near_me_outlined,
                    label: 'ナビ',
                    color: typeColor,
                    onTap: () => _launchMap(
                      context,
                      facility.latitude,
                      facility.longitude,
                      name: facility.name,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onShare,
                  icon: Icon(
                    Icons.share_outlined,
                    color: Colors.grey[500],
                    size: 24,
                  ),
                  tooltip: 'シェア',
                ),
                _FavoriteButton(
                    facilityId: facility.id, isFav: isFav),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

double _resolveAvgRating(
  ({int count, double avgRating})? summary,
  AsyncValue<List<Review>> reviewsAsync,
) {
  if (summary != null && summary.avgRating > 0) return summary.avgRating;
  final reviews = reviewsAsync.valueOrNull ?? [];
  if (reviews.isEmpty) return 0.0;
  return reviews.map((r) => r.rating).fold(0, (a, b) => a + b) /
      reviews.length;
}

// ── 基本情報行（料金・営業時間・住所）────────────────────────────────────────

class _BasicInfoSection extends StatelessWidget {
  const _BasicInfoSection({
    required this.facility,
    required this.typeColor,
  });

  final Facility facility;
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.payments_outlined,
            iconColor: typeColor,
            label: '入浴料金',
            value: (facility.price != null && facility.price! > 0)
                ? '¥${facility.price}'
                : '料金不明',
            isUnknown:
                facility.price == null || facility.price! == 0,
          ),
          if (facility.openingHours != null &&
              facility.openingHours!.isNotEmpty)
            _InfoRow(
              icon: Icons.access_time_outlined,
              iconColor: typeColor,
              label: '営業時間',
              value:
                  parseOsmOpeningHours(facility.openingHours) ??
                      facility.openingHours!,
            ),
          if (facility.address != null &&
              facility.address!.isNotEmpty)
            _InfoRow(
              icon: Icons.location_on_outlined,
              iconColor: typeColor,
              label: '住所',
              value: facility.address!,
            ),
        ],
      ),
    );
  }
}

// ── クチコミプレビュー（最新2件）─────────────────────────────────────────────

class _ReviewPreviewSection extends ConsumerWidget {
  const _ReviewPreviewSection({required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewListProvider(facilityId));
    final reviewSummaryAsync =
        ref.watch(facilityReviewSummaryProvider(facilityId));

    return reviewsAsync.whenOrNull(
          data: (reviews) {
            if (reviews.isEmpty) return const SizedBox.shrink();
            final preview = reviews.take(2).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.rate_review_outlined,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'クチコミ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${reviewSummaryAsync.valueOrNull?.count ?? reviews.length}件)',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                ...preview.map((r) => _ReviewTile(review: r)),
              ],
            );
          },
        ) ??
        const SizedBox.shrink();
  }
}

// ── ボトムアクション（チェックイン・クチコミ・詳細）────────────────────────────

class _BottomActionSection extends ConsumerWidget {
  const _BottomActionSection({
    required this.facility,
    required this.typeColor,
    required this.isCheckingIn,
    required this.onCheckin,
    required this.onOpenDetail,
  });

  final Facility facility;
  final Color typeColor;
  final bool isCheckingIn;
  final VoidCallback onCheckin;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        if (AppConfig.isCheckinEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: FilledButton.icon(
              onPressed: isCheckingIn ? null : onCheckin,
              icon: isCheckingIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                isCheckingIn ? 'チェックイン中...' : 'チェックイン',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: typeColor,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              16, AppConfig.isCheckinEnabled ? 4 : 12, 16, 24),
          child: Row(
            children: [
              if (AppConfig.isReviewEnabled) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final isSignedIn =
                          ref.read(isSignedInProvider);
                      if (!isSignedIn) {
                        final goLogin =
                            await GuestRestrictionDialog.show(
                          context,
                          featureName: 'クチコミ',
                        );
                        if (goLogin == true && context.mounted) {
                          Navigator.of(context)
                              .pushNamed('/login');
                        }
                        return;
                      }
                      if (!context.mounted) return;
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                        builder: (_) => ReviewBottomSheet(
                          facilityId: facility.id,
                          onSubmitted: () {
                            ref.invalidate(
                                reviewListProvider(facility.id));
                            ref.invalidate(
                                facilityReviewSummaryProvider(
                                    facility.id));
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.rate_review_outlined,
                        size: 16),
                    label: const Text(
                      'クチコミ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: typeColor,
                      side: BorderSide(
                          color: typeColor.withValues(alpha: 0.5)),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text(
                    '詳細',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[400]!),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
