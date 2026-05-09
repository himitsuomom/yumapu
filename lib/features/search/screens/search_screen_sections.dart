part of 'search_screen.dart';

// ── 都道府県ピッカーボトムシート ──────────────────────────────────────────────────

/// 都道府県一覧をボトムシートで表示する。
/// 「全国」(null) + 47都道府県を地域別に区切り線を入れて表示する。
class _PrefecturePickerSheet extends ConsumerWidget {
  const _PrefecturePickerSheet({
    required this.currentPrefectureId,
    required this.onSelected,
  });

  final String? currentPrefectureId;
  final void Function(String? id) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefecturesAsync = ref.watch(prefectureOptionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text(
                    '都道府県を選ぶ',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: prefecturesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('読み込みエラー: $e')),
                data: (prefectures) {
                  final regions = <String>[
                    '北海道', '東北', '関東', '中部', '近畿', '中国', '四国', '九州・沖縄',
                  ];
                  final byRegion =
                      <String, List<PrefectureOption>>{};
                  final noRegion = <PrefectureOption>[];
                  for (final p in prefectures) {
                    if (p.region != null && regions.contains(p.region)) {
                      byRegion.putIfAbsent(p.region!, () => []).add(p);
                    } else {
                      noRegion.add(p);
                    }
                  }
                  final items = <_ListItem>[];
                  items.add(const _PrefectureItem(null, '全国（絞り込みなし）'));
                  for (final region in regions) {
                    final group = byRegion[region];
                    if (group == null || group.isEmpty) continue;
                    items.add(_RegionHeader(region));
                    for (final p in group) {
                      items.add(_PrefectureItem(p.id, p.name));
                    }
                  }
                  if (noRegion.isNotEmpty) {
                    items.add(const _RegionHeader('その他'));
                    for (final p in noRegion) {
                      items.add(_PrefectureItem(p.id, p.name));
                    }
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      if (item is _RegionHeader) {
                        return Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(context).colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }
                      final prefItem = item as _PrefectureItem;
                      final isSelected =
                          prefItem.id == currentPrefectureId ||
                              (prefItem.id == null &&
                                  currentPrefectureId == null);
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(
                          prefItem.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color:
                                    Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () => onSelected(prefItem.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

sealed class _ListItem {
  const _ListItem();
}

class _RegionHeader extends _ListItem {
  final String label;
  const _RegionHeader(this.label);
}

class _PrefectureItem extends _ListItem {
  final String? id;
  final String label;
  const _PrefectureItem(this.id, this.label);
}

// ── ソートチップ ──────────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  const _SortChip({
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
          color: selected
              ? colorScheme.onPrimary
              : colorScheme.onSurface,
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

// ── ソートセクション ──────────────────────────────────────────────────────────

class _SortSection extends StatelessWidget {
  const _SortSection({
    required this.params,
    required this.hasLocation,
    required this.onSortChanged,
  });

  final FacilitySearchParams params;
  final bool hasLocation;
  final void Function(FacilitySortBy) onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
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
                _SortChip(
                  label: '品質順',
                  selected:
                      params.sortBy == FacilitySortBy.qualityScore,
                  onSelected: (_) =>
                      onSortChanged(FacilitySortBy.qualityScore),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: '名前順',
                  selected: params.sortBy == FacilitySortBy.name,
                  onSelected: (_) => onSortChanged(FacilitySortBy.name),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: hasLocation ? '距離順' : '距離順 📍',
                  selected:
                      params.sortBy == FacilitySortBy.distance,
                  onSelected: (_) =>
                      onSortChanged(FacilitySortBy.distance),
                ),
              ],
            ),
          ),
        ),
        if (params.sortBy == FacilitySortBy.distance && !hasLocation)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.location_off,
                  size: 14,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  '位置情報を取得中です。地図タブを開くと近い順に並びます。',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── 施設リスト ────────────────────────────────────────────────────────────────

class _FacilityResultList extends StatelessWidget {
  const _FacilityResultList({
    required this.facilityAsync,
    required this.hasActiveFilters,
    required this.showTrending,
    required this.accumulatedFacilities,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onClearFilters,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onRetry,
  });

  final AsyncValue<List<Facility>> facilityAsync;
  final bool hasActiveFilters;
  final bool showTrending;
  final List<Facility> accumulatedFacilities;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onClearFilters;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  Widget _buildFooter(BuildContext context) {
    if (facilityAsync.isLoading && isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.expand_more, size: 18),
            label: Text(
              'もっと見る（${accumulatedFacilities.length}件表示中）',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      );
    }
    if (accumulatedFacilities.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '${accumulatedFacilities.length}件をすべて表示しました',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (facilityAsync.isLoading && accumulatedFacilities.isEmpty) {
      return const LoadingWidget();
    }
    if (facilityAsync.hasError && accumulatedFacilities.isEmpty) {
      return AppErrorWidget(
        message: facilityAsync.error.toString(),
        onRetry: onRetry,
      );
    }
    if (accumulatedFacilities.isEmpty) {
      return EmptyWidget(
        icon: Icons.search_off,
        message: '施設が見つかりませんでした',
        action: hasActiveFilters
            ? TextButton(
                onPressed: onClearFilters,
                child: const Text('フィルターをクリア'),
              )
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: accumulatedFacilities.length + (showTrending ? 2 : 1),
        itemBuilder: (context, i) {
          if (showTrending && i == 0) {
            return _TrendingFacilitiesSection(
              onFacilityTap: (facilityId) => Navigator.of(context)
                  .pushNamed('/facility', arguments: facilityId),
            );
          }
          final listIndex = showTrending ? i - 1 : i;
          if (listIndex == accumulatedFacilities.length) {
            return _buildFooter(context);
          }
          final facility = accumulatedFacilities[listIndex];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FacilityListTile(
                      facility: facility,
                      onTap: () => Navigator.of(context).pushNamed(
                        '/facility',
                        arguments: facility.id,
                      ),
                    ),
                  ),
                  _FacilityPopupMenu(facility: facility),
                ],
              ),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }
}

// ── 検索リスト用ポップアップメニュー ──────────────────────────────────────────

class _FacilityPopupMenu extends ConsumerWidget {
  const _FacilityPopupMenu({required this.facility});

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
            ref.read(mapFlyToProvider.notifier).state = (
              lat: facility.latitude,
              lng: facility.longitude,
            );
            ref.read(homeTabIndexProvider.notifier).state = 0;
          case 'toggle_favorite':
            await ref.read(favoritesProvider.notifier).toggle(facility.id);
            if (!context.mounted) return;
            final now = ref.read(isFavoriteProvider(facility.id));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    now ? 'お気に入りに追加しました' : 'お気に入りを解除しました'),
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
