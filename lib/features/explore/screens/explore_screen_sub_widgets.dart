part of 'explore_screen.dart';

// ── 人気施設セクション ─────────────────────────────────────────────────────────

/// 探す画面の施設リスト先頭に表示する「今週の人気施設」横スクロールカード群。
class _ExploreTrendingSection extends ConsumerWidget {
  const _ExploreTrendingSection({required this.onFacilityTap});

  final void Function(String facilityId) onFacilityTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingFacilitiesProvider);

    return trendingAsync.when(
      data: (facilities) {
        if (facilities.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    '今週の人気施設',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 130,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: facilities.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _ExploreTrendingCard(
                  facility: facilities[index],
                  onTap: () => onFacilityTap(facilities[index].id),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'すべての施設',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// 人気施設1件分のコンパクトカード（横スクロール用）。
class _ExploreTrendingCard extends StatelessWidget {
  const _ExploreTrendingCard({required this.facility, required this.onTap});

  final Facility facility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = switch (facility.facilityType) {
      'onsen' => '♨️',
      'sauna' => '🧖',
      'public_bath' => '🛁',
      _ => '🏠',
    };

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: SizedBox(
          width: 130,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  facility.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (facility.address != null && facility.address!.isNotEmpty)
                  Text(
                    facility.address!,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withAlpha(140),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── ソート行 ──────────────────────────────────────────────────────────────────

/// 施設リストのソート順変更チップ行 + フィルタークリアボタン。
class _ExploreSortRow extends StatelessWidget {
  const _ExploreSortRow({
    required this.params,
    required this.hasActiveFilters,
    required this.onSortChanged,
    required this.onClearFilters,
  });

  final FacilitySearchParams params;
  final bool hasActiveFilters;
  final void Function(FacilitySortBy) onSortChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.sort, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            const Text(
              '並び順:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            _ExploreChoiceChip(
              label: '品質順',
              selected: params.sortBy == FacilitySortBy.qualityScore,
              onSelected: (_) => onSortChanged(FacilitySortBy.qualityScore),
            ),
            const SizedBox(width: 6),
            _ExploreChoiceChip(
              label: '名前順',
              selected: params.sortBy == FacilitySortBy.name,
              onSelected: (_) => onSortChanged(FacilitySortBy.name),
            ),
            const SizedBox(width: 6),
            _ExploreChoiceChip(
              label: '距離順',
              selected: params.sortBy == FacilitySortBy.distance,
              onSelected: (_) => onSortChanged(FacilitySortBy.distance),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(width: 12),
              ActionChip(
                label: const Text(
                  'クリア',
                  style: TextStyle(fontSize: 12),
                ),
                avatar: const Icon(Icons.clear, size: 14),
                onPressed: onClearFilters,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 選択可能な小さなチップ（ChoiceChip ラッパー）。
class _ExploreChoiceChip extends StatelessWidget {
  const _ExploreChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final void Function(bool) onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── 施設ポップアップメニュー ─────────────────────────────────────────────────

/// 施設タイルの「⋮」メニュー（地図で見る / お気に入り / 詳細）。
///
/// 「地図で見る」は mapFlyToProvider に座標をセットするだけでよい。
/// ExploreScreen は地図と同一画面なので、タブ遷移は不要。
class _ExploreFacilityPopupMenu extends ConsumerWidget {
  const _ExploreFacilityPopupMenu({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(facility.id));

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
      tooltip: 'メニュー',
      onSelected: (value) async {
        switch (value) {
          case 'show_on_map':
            // 地図は同一画面なので mapFlyToProvider に座標をセットするだけでよい
            ref.read(mapFlyToProvider.notifier).state = (
              lat: facility.latitude,
              lng: facility.longitude,
            );
          case 'toggle_favorite':
            await ref.read(favoritesProvider.notifier).toggle(facility.id);
            if (!context.mounted) return;
            final now = ref.read(isFavoriteProvider(facility.id));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(now ? 'お気に入りに追加しました' : 'お気に入りを解除しました'),
                duration: const Duration(seconds: 2),
              ),
            );
          case 'open_detail':
            Navigator.of(context)
                .pushNamed('/facility', arguments: facility.id);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'show_on_map',
          child: Row(
            children: [
              Icon(Icons.map_outlined, size: 18),
              SizedBox(width: 8),
              Text('地図で見る'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle_favorite',
          child: Row(
            children: [
              Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: isFavorite ? Colors.red : null,
              ),
              const SizedBox(width: 8),
              Text(isFavorite ? 'お気に入りを解除' : 'お気に入りに追加'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'open_detail',
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18),
              SizedBox(width: 8),
              Text('詳細を見る'),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 検索履歴パネル ────────────────────────────────────────────────────────────

/// 探す画面の検索バーフォーカス時に表示する検索履歴パネル。
class _ExploreRecentSearchesPanel extends StatelessWidget {
  const _ExploreRecentSearchesPanel({
    required this.searches,
    required this.onTap,
    required this.onRemove,
  });

  final List<String> searches;
  final void Function(String query) onTap;
  final void Function(String query) onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(Icons.history,
                    size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  '最近の検索',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...searches.map(
            (q) => ListTile(
              dense: true,
              leading: const Icon(Icons.search, size: 18),
              title: Text(q,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: '削除',
                onPressed: () => onRemove(q),
              ),
              onTap: () => onTap(q),
            ),
          ),
        ],
      ),
    );
  }
}

// ── アメニティ選択ボトムシート ─────────────────────────────────────────────────

/// 探す画面で使用するアメニティ選択ボトムシート。
class _ExploreAmenityPickerSheet extends ConsumerStatefulWidget {
  const _ExploreAmenityPickerSheet({
    required this.selectedIds,
    required this.onChanged,
  });

  final List<String> selectedIds;
  final void Function(List<String> ids) onChanged;

  @override
  ConsumerState<_ExploreAmenityPickerSheet> createState() =>
      _ExploreAmenityPickerSheetState();
}

class _ExploreAmenityPickerSheetState
    extends ConsumerState<_ExploreAmenityPickerSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final amenitiesAsync = ref.watch(amenityOptionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
              child: Row(
                children: [
                  Text(
                    '設備・泉質で絞り込む',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _selected = []),
                      child: const Text('リセット'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: amenitiesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('読み込みエラー: $e')),
                data: (amenities) {
                  if (amenities.isEmpty) {
                    return const Center(child: Text('設備データがありません'));
                  }
                  final grouped = <String, List<AmenityOption>>{};
                  for (final a in amenities) {
                    final cat = a.category.isEmpty ? 'その他' : a.category;
                    grouped.putIfAbsent(cat, () => []).add(a);
                  }
                  final items = <_ExploreAmenityListItem>[];
                  for (final entry in grouped.entries) {
                    items.add(_ExploreAmenityCategoryHeader(entry.key));
                    for (final a in entry.value) {
                      items.add(_ExploreAmenityRowItem(a));
                    }
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      if (item is _ExploreAmenityCategoryHeader) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }
                      final row = item as _ExploreAmenityRowItem;
                      final isChecked = _selected.contains(row.amenity.id);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(row.amenity.name,
                            style: const TextStyle(fontSize: 14)),
                        value: isChecked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(row.amenity.id);
                            } else {
                              _selected.remove(row.amenity.id);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => widget.onChanged(_selected),
                    child: Text(
                      _selected.isEmpty
                          ? '絞り込まずに適用'
                          : '${_selected.length}件の設備で絞り込む',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

sealed class _ExploreAmenityListItem {
  const _ExploreAmenityListItem();
}

class _ExploreAmenityCategoryHeader extends _ExploreAmenityListItem {
  final String label;
  const _ExploreAmenityCategoryHeader(this.label);
}

class _ExploreAmenityRowItem extends _ExploreAmenityListItem {
  final AmenityOption amenity;
  const _ExploreAmenityRowItem(this.amenity);
}
