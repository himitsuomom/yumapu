import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/auth_provider.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class FacilityTypeOption {
  final String id;
  final String name;
  const FacilityTypeOption({required this.id, required this.name});
}

class AmenityOption {
  final String id;
  final String name;
  const AmenityOption({required this.id, required this.name});
}

/// 都道府県フィルター用のデータモデル。
class PrefectureOption {
  final String id;
  final String name;
  final String? region;
  const PrefectureOption({required this.id, required this.name, this.region});
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// 都道府県一覧を取得するプロバイダー。
/// 地域（region）でグルーピングして表示するために region も取得する。
/// autoDispose なしで保持するのは、検索画面を行き来するたびに再取得しないためのキャッシュ最適化。
final prefectureOptionsProvider =
    FutureProvider<List<PrefectureOption>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return [];
  final rows = await client
      .from('prefectures')
      .select('id, name, region')
      .order('name') as List;
  return rows
      .map((r) => PrefectureOption(
            id: r['id'] as String,
            name: r['name'] as String,
            region: r['region'] as String?,
          ))
      .toList();
});

final facilityTypeOptionsProvider =
    FutureProvider.autoDispose<List<FacilityTypeOption>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return [];
  final rows = await client
      .from('facility_types')
      .select('id, name_ja')
      .order('name_ja') as List;
  return rows
      .map((r) => FacilityTypeOption(
            id: r['id'] as String,
            name: r['name_ja'] as String,
          ))
      .toList();
});

final amenityOptionsProvider =
    FutureProvider.autoDispose<List<AmenityOption>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return [];
  // value_type=number（サウナ温度・水風呂温度）はチェックボックス型ではないので除外。
  // 泉質（spring_type）は含める。
  final rows = await client
      .from('amenities')
      .select('id, name_ja, category')
      .not('value_type', 'eq', 'number')
      .order('name_ja') as List;
  return rows
      .map((r) => AmenityOption(
            id: r['id'] as String,
            name: r['name_ja'] as String,
          ))
      .toList();
});

// ── Widget ────────────────────────────────────────────────────────────────────

/// Horizontal scrolling chip rows for facility type, "open now", and amenity filtering.
///
/// Each amenity chip is independently toggleable: selecting or deselecting one
/// does not affect the others (existing selections are preserved via
/// [onAmenityToggled]).
class FilterBar extends ConsumerWidget {
  const FilterBar({
    super.key,
    required this.selectedFacilityTypeId,
    required this.selectedAmenityIds,
    required this.onFacilityTypeChanged,
    required this.onAmenityToggled,
    this.isOpenNow = false,
    this.onOpenNowChanged,
  });

  final String? selectedFacilityTypeId;
  final List<String> selectedAmenityIds;

  /// Called with the new facility type ID, or null to clear the filter.
  final void Function(String? id) onFacilityTypeChanged;

  /// Called with the toggled amenity ID. The parent is responsible for
  /// adding or removing it from the current selection list.
  final void Function(String id) onAmenityToggled;

  /// 「今日営業中」フィルターが ON かどうか。
  final bool isOpenNow;

  /// 「今日営業中」チップが切り替えられたときに呼ばれる。
  /// null の場合はチップを非表示にする。
  final void Function(bool)? onOpenNowChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(facilityTypeOptionsProvider);
    final amenitiesAsync = ref.watch(amenityOptionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Facility type + "今日営業中" row ──────────────────────────────
        // UX-V28-2: 「今日営業中」チップを施設タイプより先頭に配置。
        // 以前は施設タイプ一覧の末尾に置かれていたため、スクロールしないと見えない
        // 可能性があった。最も便利なフィルターを即座に使えるよう先頭に移動した。
        typesAsync.when(
          data: (types) {
            if (types.isEmpty) return const SizedBox.shrink();
            return _ChipRow(
              children: [
                // ── 「今日営業中」チップ（先頭に配置して視認性向上）────────────
                if (onOpenNowChanged != null)
                  FilterChip(
                    avatar: const Icon(Icons.access_time, size: 16),
                    label: const Text('今日営業中'),
                    selected: isOpenNow,
                    onSelected: onOpenNowChanged,
                  ),
                // "すべて" chip clears the facility type filter
                FilterChip(
                  label: const Text('すべて'),
                  selected: selectedFacilityTypeId == null,
                  onSelected: (_) => onFacilityTypeChanged(null),
                ),
                ...types.map((t) => FilterChip(
                      label: Text(t.name),
                      selected: selectedFacilityTypeId == t.id,
                      onSelected: (selected) =>
                          onFacilityTypeChanged(selected ? t.id : null),
                    )),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        // ── Amenity row ────────────────────────────────────────────────────
        amenitiesAsync.when(
          data: (amenities) {
            if (amenities.isEmpty) return const SizedBox.shrink();
            return _ChipRow(
              children: amenities
                  .map((a) => FilterChip(
                        label: Text(a.name),
                        selected: selectedAmenityIds.contains(a.id),
                        // Toggle only this amenity; others are unaffected
                        onSelected: (_) => onAmenityToggled(a.id),
                      ))
                  .toList(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Internal helper ───────────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}
