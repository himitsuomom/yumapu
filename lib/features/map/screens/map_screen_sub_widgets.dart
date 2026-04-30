part of 'map_screen.dart';

// ── 検索バー + フィルターバナー オーバーレイ ─────────────────────────────────

class _MapSearchOverlay extends ConsumerWidget {
  const _MapSearchOverlay({
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilityState = ref.watch(mapFacilityListProvider);
    final isLoading = facilityState is AsyncLoading;
    final params = ref.watch(mapSearchParamsProvider);
    final hasFilter = params.facilityTypeId != null ||
        params.amenityIds.isNotEmpty ||
        params.isOpenNow;
    final hasSearchQuery = params.searchQuery != null;

    final facilityTypeOptions =
        ref.watch(facilityTypeOptionsProvider).valueOrNull ?? [];
    final amenityOptions =
        ref.watch(amenityOptionsProvider).valueOrNull ?? [];

    String filterLabel() {
      final labels = <String>[];
      if (params.facilityTypeId != null) {
        final typeName = facilityTypeOptions
            .where((t) => t.id == params.facilityTypeId)
            .map((t) => t.name)
            .firstOrNull;
        if (typeName != null) labels.add(typeName);
      }
      if (params.isOpenNow) labels.add('今日営業中');
      for (final amenityId in params.amenityIds) {
        final amenityName = amenityOptions
            .where((a) => a.id == amenityId)
            .map((a) => a.name)
            .firstOrNull;
        if (amenityName != null) labels.add(amenityName);
      }
      return labels.isEmpty ? 'フィルター適用中' : labels.join(' · ');
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(28),
            shadowColor: Colors.black26,
            child: TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
              decoration: InputDecoration(
                hintText: '施設名・エリアで検索',
                prefixIcon: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
                suffixIcon: hasSearchQuery
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: '検索をクリア',
                        onPressed: onClearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          if (hasFilter) ...[
            const SizedBox(height: 6),
            Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        filterLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        ref.read(mapSearchParamsProvider.notifier).update(
                              (p) => p.copyWith(
                                clearFacilityType: true,
                                amenityIds: [],
                                isOpenNow: false,
                              ),
                            );
                      },
                      child: Icon(
                        Icons.close,
                        size: 15,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 件数バナー（フィルター / 検索ヒット件数）──────────────────────────────────

class _MapCountBanner extends ConsumerWidget {
  const _MapCountBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilityState = ref.watch(mapFacilityListProvider);
    final params = ref.watch(mapSearchParamsProvider);
    final isLoading = facilityState is AsyncLoading;
    final facilityCount = facilityState.valueOrNull?.length ?? 0;
    final hasFilter = params.facilityTypeId != null ||
        params.amenityIds.isNotEmpty ||
        params.isOpenNow;
    final hasSearchQuery = params.searchQuery != null;

    final show = facilityState.hasValue &&
        !isLoading &&
        facilityCount > 0 &&
        (hasFilter || hasSearchQuery) &&
        params.latitude != null;

    if (!show) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 72 + (hasFilter ? 44 : 0),
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withAlpha(230),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Text(
              '$facilityCount件見つかりました',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 空状態オーバーレイ（検索結果0件時）──────────────────────────────────────

class _MapEmptyState extends ConsumerWidget {
  const _MapEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilityState = ref.watch(mapFacilityListProvider);
    final params = ref.watch(mapSearchParamsProvider);
    final isLoading = facilityState is AsyncLoading;

    final show = facilityState.hasValue &&
        !isLoading &&
        (facilityState.valueOrNull?.isEmpty ?? false) &&
        params.latitude != null;

    if (!show) return const SizedBox.shrink();

    return Positioned(
      bottom: 160,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(237),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 36,
                color: Color(0xFF9E9E9E),
              ),
              SizedBox(height: 6),
              Text(
                '施設が見つかりません',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '検索条件を変えるか、別のエリアで試してください',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF757575),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 施設タイプ凡例カード ──────────────────────────────────────────────────────

class _MapLegendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white.withAlpha(230),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendRow(color: Color(0xFFE53935), emoji: '♨', label: '温泉'),
            SizedBox(height: 3),
            _LegendRow(color: Color(0xFF1976D2), emoji: '🛁', label: '銭湯'),
            SizedBox(height: 3),
            _LegendRow(color: Color(0xFF2E7D32), emoji: '🧖', label: 'サウナ'),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.emoji,
    required this.label,
  });

  final Color color;
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── フィルターボトムシート ────────────────────────────────────────────────────

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(mapSearchParamsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '絞り込み',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (params.facilityTypeId != null ||
                      params.amenityIds.isNotEmpty ||
                      params.isOpenNow)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(mapSearchParamsProvider.notifier)
                            .update(
                              (p) => p.copyWith(
                                clearFacilityType: true,
                                amenityIds: [],
                                isOpenNow: false,
                              ),
                            );
                        Navigator.of(context).pop();
                      },
                      child: const Text('リセット'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilterBar(
              selectedFacilityTypeId: params.facilityTypeId,
              selectedAmenityIds: params.amenityIds,
              isOpenNow: params.isOpenNow,
              onFacilityTypeChanged: (typeId) {
                ref.read(mapSearchParamsProvider.notifier).update(
                      (p) => typeId == null
                          ? p.copyWith(clearFacilityType: true, page: 0)
                          : p.copyWith(facilityTypeId: typeId, page: 0),
                    );
              },
              onAmenityToggled: (amenityId) {
                ref.read(mapSearchParamsProvider.notifier).update((p) {
                  final current = List<String>.from(p.amenityIds);
                  if (current.contains(amenityId)) {
                    current.remove(amenityId);
                  } else {
                    current.add(amenityId);
                  }
                  return p.copyWith(amenityIds: current, page: 0);
                });
              },
              onOpenNowChanged: (value) {
                ref.read(mapSearchParamsProvider.notifier).update(
                      (p) => p.copyWith(isOpenNow: value, page: 0),
                    );
              },
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('この条件で表示'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
