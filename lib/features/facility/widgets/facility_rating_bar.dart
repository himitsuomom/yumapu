// lib/features/facility/widgets/facility_rating_bar.dart
//
// 施設詳細：平均評価サマリーバー
// 施設名直下にスター評価と件数を表示する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/review_provider.dart' show facilityReviewSummaryProvider;

/// UX-V13-2: 施設名直下に平均評価スコアと件数を大きく表示するウィジェット。
///
/// facilityReviewSummaryProvider でサーバーサイドAVGを取得し、
/// ★評価を横並びで見やすく表示する。0件の場合は非表示。
class FacilityRatingBar extends ConsumerWidget {
  const FacilityRatingBar({super.key, required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(facilityReviewSummaryProvider(facilityId));

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.count == 0) return const SizedBox.shrink();

        final avg = summary.avgRating;
        final count = summary.count;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // 星アイコン（塗りつぶし）
              const Icon(Icons.star, color: Color(0xFFFFC107), size: 22),
              const SizedBox(width: 6),
              // 平均スコア（大きめのテキスト）
              Text(
                avg.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFC107),
                    ),
              ),
              const SizedBox(width: 8),
              // 星を5個並べる（半星対応）
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = avg - i;
                  if (filled >= 1) {
                    return const Icon(Icons.star,
                        color: Color(0xFFFFC107), size: 16);
                  } else if (filled >= 0.5) {
                    return const Icon(Icons.star_half,
                        color: Color(0xFFFFC107), size: 16);
                  } else {
                    return const Icon(Icons.star_border,
                        color: Color(0xFFFFC107), size: 16);
                  }
                }),
              ),
              const SizedBox(width: 8),
              // 件数テキスト
              Text(
                '($count件)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
