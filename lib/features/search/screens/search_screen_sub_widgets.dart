part of 'search_screen.dart';

// ── 今週の人気施設セクション ─────────────────────────────────────────────────────

/// 検索画面上部に表示する横スクロール可能な「今週の人気施設」カードリスト。
/// trendingFacilitiesProvider から取得したデータを表示する。
/// フィルターなし・ページ0のときのみ表示される。
class _TrendingFacilitiesSection extends ConsumerWidget {
  const _TrendingFacilitiesSection({required this.onFacilityTap});

  final void Function(String facilityId) onFacilityTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingFacilitiesProvider);

    return trendingAsync.when(
      // データなし or 空 → セクションを非表示
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
                itemBuilder: (context, index) => _TrendingCard(
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
      // ロード中 → 小さなインジケーターだけ
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
      // エラー → 非表示（UX を壊さない）
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// 人気施設1件分のコンパクトなカード（横スクロール用）。
class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.facility, required this.onTap});

  final Facility facility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 施設タイプ別アイコン
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
                // タイプアイコン
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                // 施設名（最大2行）
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
                // 住所（1行）
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

// ── 都道府県フィルターチップ ─────────────────────────────────────────────────────

/// 検索画面に表示する都道府県フィルターのコンパクトな行。
/// - 未選択: 「都道府県を選ぶ」 グレーチップ → タップでピッカーを開く
/// - 選択中: 「東京都」 カラーチップ + 「×」ボタン → × でリセット / チップタップで変更
class _PrefectureFilterChip extends ConsumerWidget {
  const _PrefectureFilterChip({
    required this.currentPrefectureId,
    required this.onTap,
    required this.onClear,
  });

  final String? currentPrefectureId;
  final VoidCallback onTap;   // チップタップ → ピッカーを開く
  final VoidCallback onClear; // × ボタン → フィルターをリセット

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefecturesAsync = ref.watch(prefectureOptionsProvider);

    return prefecturesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (prefectures) {
        if (prefectures.isEmpty) return const SizedBox.shrink();

        // 選択中の都道府県名を取得する（IDから名前に変換）
        final selectedName = currentPrefectureId == null
            ? null
            : prefectures
                .where((p) => p.id == currentPrefectureId)
                .map((p) => p.name)
                .firstOrNull;
        final isSelected = currentPrefectureId != null;
        final colorScheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              const Text(
                'エリア:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              // メインチップ: 未選択 = グレー, 選択中 = プライマリカラー
              ActionChip(
                avatar: Icon(
                  Icons.place,
                  size: 14,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                ),
                label: Text(
                  isSelected ? (selectedName ?? '都道府県') : '都道府県を選ぶ',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                ),
                backgroundColor: isSelected
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                // 選択済み・未選択どちらもタップでピッカーを開く（変更も可能）
                onPressed: onTap,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              // 選択中のとき「×」クリアボタンを横に表示する
              if (isSelected) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.cancel,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── 都道府県ピッカーボトムシート ──────────────────────────────────────────────────

/// 都道府県一覧をボトムシートで表示する。
/// 「全国」(null) + 47都道府県を地域別に区切り線を入れて表示する。
class _PrefecturePickerSheet extends ConsumerWidget {
  const _PrefecturePickerSheet({
    required this.currentPrefectureId,
    required this.onSelected,
  });

  final String? currentPrefectureId;

  /// 都道府県IDを引数として呼ばれる。null は「全国」を意味する。
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
            // ── ドラッグハンドル ────────────────────────────────────────────
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
            // ── タイトル ────────────────────────────────────────────────────
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
            // ── 都道府県リスト ─────────────────────────────────────────────
            Expanded(
              child: prefecturesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('読み込みエラー: $e')),
                data: (prefectures) {
                  // 「全国」オプション + 47都道府県を地域でグループ分けして表示する。
                  // 地域の順番: 北海道→東北→関東→中部→近畿→中国→四国→九州・沖縄
                  final regions = <String>[
                    '北海道', '東北', '関東', '中部', '近畿', '中国', '四国', '九州・沖縄',
                  ];

                  // 地域別にグループ化する
                  final byRegion = <String, List<PrefectureOption>>{};
                  final noRegion = <PrefectureOption>[];
                  for (final p in prefectures) {
                    if (p.region != null && regions.contains(p.region)) {
                      byRegion.putIfAbsent(p.region!, () => []).add(p);
                    } else {
                      noRegion.add(p);
                    }
                  }

                  // 表示するアイテムリスト（ヘッダーと施設をフラットにまとめる）
                  final items = <_ListItem>[];

                  // 「全国」行（フィルターをクリアする）
                  items.add(const _PrefectureItem(null, '全国（絞り込みなし）'));

                  // 地域別グループを順番通りに追加する
                  for (final region in regions) {
                    final group = byRegion[region];
                    if (group == null || group.isEmpty) continue;
                    items.add(_RegionHeader(region));
                    for (final p in group) {
                      items.add(_PrefectureItem(p.id, p.name));
                    }
                  }

                  // 地域未設定の都道府県（DBデータが不完全な場合の安全網）
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
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }
                      final prefItem = item as _PrefectureItem;
                      final isSelected = prefItem.id == currentPrefectureId ||
                          (prefItem.id == null && currentPrefectureId == null);
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
                                color: Theme.of(context).colorScheme.primary,
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

// ── ピッカー内部用の sealed リスト項目 ────────────────────────────────────────

/// ピッカーリストのアイテム基底クラス（ヘッダー or 都道府県行）
sealed class _ListItem {
  const _ListItem();
}

class _RegionHeader extends _ListItem {
  final String label;
  const _RegionHeader(this.label);
}

class _PrefectureItem extends _ListItem {
  final String? id; // null = 「全国」
  final String label;
  const _PrefectureItem(this.id, this.label);
}

// ── アメニティ選択ボトムシート ─────────────────────────────────────────────────

/// アメニティをカテゴリ別に表示し、チェックボックスで複数選択できるボトムシート。
/// 選択結果は「適用」ボタンで [onChanged] に渡される。
class _AmenityPickerSheet extends ConsumerStatefulWidget {
  const _AmenityPickerSheet({
    required this.selectedIds,
    required this.onChanged,
  });

  final List<String> selectedIds;
  final void Function(List<String> ids) onChanged;

  @override
  ConsumerState<_AmenityPickerSheet> createState() =>
      _AmenityPickerSheetState();
}

class _AmenityPickerSheetState extends ConsumerState<_AmenityPickerSheet> {
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
            // ── ドラッグハンドル ────────────────────────────────────────────
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
            // ── ヘッダー ────────────────────────────────────────────────────
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
            // ── アメニティリスト（カテゴリ別）─────────────────────────────
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

                  // カテゴリ別にグループ化
                  final grouped = <String, List<AmenityOption>>{};
                  for (final a in amenities) {
                    final cat = a.category.isEmpty ? 'その他' : a.category;
                    grouped.putIfAbsent(cat, () => []).add(a);
                  }

                  // ヘッダーと行をフラットリストに展開
                  final items = <_AmenityListItem>[];
                  for (final entry in grouped.entries) {
                    items.add(_AmenityCategoryHeader(entry.key));
                    for (final a in entry.value) {
                      items.add(_AmenityRowItem(a));
                    }
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      if (item is _AmenityCategoryHeader) {
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
                      final row = item as _AmenityRowItem;
                      final isChecked = _selected.contains(row.amenity.id);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(
                          row.amenity.name,
                          style: const TextStyle(fontSize: 14),
                        ),
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
            // ── 適用ボタン ──────────────────────────────────────────────────
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

sealed class _AmenityListItem {
  const _AmenityListItem();
}

class _AmenityCategoryHeader extends _AmenityListItem {
  final String label;
  const _AmenityCategoryHeader(this.label);
}

class _AmenityRowItem extends _AmenityListItem {
  final AmenityOption amenity;
  const _AmenityRowItem(this.amenity);
}

// ── 距離フィルター行 ────────────────────────────────────────────────────────────

/// 現在地からの距離で施設を絞り込むチップ行。
/// 現在地が未取得（currentLocationProvider == null）の場合はヒントを表示する。
class _DistanceFilterRow extends ConsumerWidget {
  const _DistanceFilterRow({
    required this.selectedRadiusMeters,
    required this.onDistanceChanged,
  });

  final double? selectedRadiusMeters;
  final void Function(double? radiusMeters) onDistanceChanged;

  static const _options = [
    (label: '1km', meters: 1000.0),
    (label: '3km', meters: 3000.0),
    (label: '5km', meters: 5000.0),
    (label: '10km', meters: 10000.0),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(currentLocationProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.near_me_outlined, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          const Text(
            '距離:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          if (location == null)
            Expanded(
              child: Text(
                '地図タブを開くと距離で絞り込めます',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SortChip(
                      label: '全国',
                      selected: selectedRadiusMeters == null,
                      onSelected: (_) => onDistanceChanged(null),
                    ),
                    ..._options.map(
                      (o) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _SortChip(
                          label: o.label,
                          selected: selectedRadiusMeters == o.meters,
                          onSelected: (_) => onDistanceChanged(o.meters),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── ソートチップ ──────────────────────────────────────────────────────────────

/// 選択可能な小さなチップ。ChoiceChipをコンパクトにラップする。
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

// ── 検索リスト用ポップアップメニュー ──────────────────────────────────────────

/// 検索結果タイルの「⋮」ポップアップメニュー。
/// 「地図で見る」「お気に入りに追加/解除」「詳細を見る」の3項目を提供する。
/// ConsumerWidget にすることで isFavoriteProvider を watch できる。
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
            await ref
                .read(favoritesProvider.notifier)
                .toggle(facility.id);
            if (!context.mounted) return;
            final now = ref.read(isFavoriteProvider(facility.id));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(now ? 'お気に入りに追加しました' : 'お気に入りを解除しました'),
                duration: const Duration(seconds: 2),
              ),
            );
          case 'open_detail':
            Navigator.of(context).pushNamed(
              '/facility',
              arguments: facility.id,
            );
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

/// 検索バーにフォーカスが当たり、テキストが空のときに表示する検索履歴リスト。
///
/// 最大5件の直近検索ワードを表示し、タップで再検索・×ボタンで削除できる。
/// Material の Card + ListTile で実装し、検索フィールドの直下に自然に溶け込む。
class _RecentSearchesPanel extends StatelessWidget {
  const _RecentSearchesPanel({
    required this.searches,
    required this.onTap,
    required this.onRemove,
  });

  /// 表示する検索履歴（最大5件、最新順）
  final List<String> searches;

  /// 履歴キーワードをタップしたときのコールバック
  final void Function(String query) onTap;

  /// 特定の履歴を削除するコールバック
  final void Function(String query) onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
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
          // 検索履歴リスト
          ...searches.map(
            (q) => ListTile(
              dense: true,
              leading: const Icon(Icons.search, size: 18),
              title: Text(
                q,
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
