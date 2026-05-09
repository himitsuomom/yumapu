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
                  facility.name,
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

// ── 検索履歴パネル ────────────────────────────────────────────────────────────

/// 検索バーにフォーカスが当たり、テキストが空のときに表示する検索履歴リスト。
class _RecentSearchesPanel extends StatelessWidget {
  const _RecentSearchesPanel({
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(Icons.history, size: 14,
                    color: colorScheme.onSurfaceVariant),
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

