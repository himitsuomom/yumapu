// lib/features/facility/widgets/facility_info_section.dart
//
// 施設詳細：基本情報セクション（住所・営業時間・料金・電話・URL・地図リンク）

import 'package:flutter/material.dart';
import 'package:yu_map/core/utils/opening_hours_parser.dart';
import 'package:yu_map/domain/entities/facility.dart';

/// 施設詳細の基本情報（住所・営業時間・料金・電話・HP）を縦に並べるウィジェット。
/// 「地図で場所を確認」ボタンも含む。
class FacilityInfoSection extends StatelessWidget {
  const FacilityInfoSection({
    super.key,
    required this.facility,
    this.onPhone,
    this.onWebsite,
    this.onGoToMap,
  });

  final Facility facility;
  final VoidCallback? onPhone;
  final VoidCallback? onWebsite;

  /// タップで地図タブに遷移し、施設の位置にカメラを移動するコールバック。
  /// 座標が無効な場合は null を渡すことでボタンを非表示にする。
  final VoidCallback? onGoToMap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Facility type chip
          if (facility.hasFacilityType) ...[
            Chip(
              label: Text(facility.facilityTypeJa),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 8),
          ],
          // Address
          if (facility.address != null && facility.address!.isNotEmpty)
            FacilityInfoRow(
              icon: Icons.location_on_outlined,
              text: facility.address!,
              textStyle: textTheme.bodyMedium,
            ),
          // Opening hours（OSM形式を日本語に変換して表示）
          if (facility.openingHours != null)
            FacilityInfoRow(
              icon: Icons.access_time_outlined,
              text: parseOsmOpeningHours(facility.openingHours) ??
                  facility.openingHours!,
              textStyle: textTheme.bodyMedium,
            ),
          // Price（nullまたは0の場合は「料金不明」と表示。非表示にしない）
          FacilityInfoRow(
            icon: Icons.payments_outlined,
            text: (facility.price != null && facility.price! > 0)
                ? '入浴料 ¥${facility.price}'
                : '料金不明',
            textStyle: textTheme.bodyMedium?.copyWith(
              color: (facility.price == null || facility.price! == 0)
                  ? Colors.grey[400]
                  : null,
            ),
          ),
          // Phone
          if (facility.phone != null)
            FacilityInfoRow(
              icon: Icons.phone_outlined,
              text: facility.phone!,
              textStyle: textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              onTap: onPhone,
            ),
          // Website
          if (facility.website != null)
            FacilityInfoRow(
              icon: Icons.language_outlined,
              text: facility.website!,
              textStyle: textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              onTap: onWebsite,
            ),
          // 「地図で確認」ボタン（座標がある施設のみ表示）
          if (onGoToMap != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('地図で場所を確認'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.outline),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: onGoToMap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 施設情報の1行（アイコン + テキスト）。タップ可能。
class FacilityInfoRow extends StatelessWidget {
  const FacilityInfoRow({
    super.key,
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
