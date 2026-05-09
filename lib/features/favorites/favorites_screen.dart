// lib/features/favorites/favorites_screen.dart
//
// お気に入り施設一覧画面
//
// Bug-V9-5 対応:
//   favorites テーブルに対して直接 JOIN クエリを実行し、
//   全 ID を inFilter に渡す方式から切り替えた。
//   - favorites.user_id で絞り込み → facilities を JOIN
//   - created_at DESC でお気に入り追加順に表示
//
// UX-V8-3 対応:
//   - 施設名のインクリメンタル検索（ローカルフィルタ）
//   - ソート: 追加順（デフォルト） / 名前順 / 施設タイプ別

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/widgets/empty_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/features/facility/widgets/add_to_plan_sheet.dart'
    show showAddToPlanSheet;
import 'package:yu_map/features/search/widgets/facility_list_tile.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/navigation_provider.dart';

// ── ソート列挙 ────────────────────────────────────────────────────────────────

enum _FavoriteSortBy {
  /// お気に入り追加日時が新しい順（デフォルト）
  addedAt,

  /// 施設名のよみがな（name_kana）昇順。kana がない場合は name で代替。
  name,

  /// 施設タイプ別（温泉→銭湯→サウナ→その他）の順で並べ、タイプ内は名前順
  facilityType,
}

// ── 直接JOINクエリで施設リストを取得するプロバイダー ──────────────────────────
//
// favorites テーブルを user_id で絞り込み、facilities を JOIN して取得する。
// favoritesProvider（ID の Set）も watch することで、
// ハートトグル後に自動的にリストが更新される。

final _favoriteFacilitiesProvider =
    FutureProvider.autoDispose<List<Facility>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  if (client == null || session == null) return [];

  // favoritesProvider を watch してトグル時に自動再フェッチ
  // （ID の Set が変わった = お気に入りの追加/削除があった）
  ref.watch(favoritesProvider);

  // favorites → facilities の直接 JOIN クエリ。
  // added_at 順で返し、施設データを一括取得する（N+1 なし）。
  final rows = await client
      .from('favorites')
      .select(
        'created_at, '
        'facilities('
        'id, name, name_kana, latitude, longitude, '
        'address, phone, website, prefecture_id, facility_type_id, '
        'facility_types(code), '
        'business_hours, price_info, hours, price, '
        'data_source, data_quality_score'
        ')',
      )
      .eq('user_id', session.user.id)
      .order('created_at', ascending: false) as List;

  return rows
      .map((r) {
        final fJson = r['facilities'] as Map<String, dynamic>?;
        if (fJson == null) return null;
        return Facility.fromJson(fJson);
      })
      .whereType<Facility>()
      .toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _FavoriteSortBy _sortBy = _FavoriteSortBy.addedAt;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── ローカルフィルタ + ソート ───────────────────────────────────────────────

  /// フェッチ済みリストに検索ワードを適用してローカルフィルタリングする。
  List<Facility> _filter(List<Facility> all) {
    final q = _searchQuery.trim().toLowerCase();
    var result = q.isEmpty
        ? all
        : all
            .where((f) =>
                f.name.toLowerCase().contains(q) ||
                (f.nameKana?.toLowerCase().contains(q) ?? false) ||
                (f.address?.toLowerCase().contains(q) ?? false))
            .toList();

    // ソート（_addedAt はサーバー側で created_at DESC 済みなので追加処理不要）
    switch (_sortBy) {
      case _FavoriteSortBy.addedAt:
        // すでに追加順（サーバーソート済み）
        break;
      case _FavoriteSortBy.name:
        result = List.of(result)
          ..sort((a, b) {
            final ka = a.nameKana ?? a.name;
            final kb = b.nameKana ?? b.name;
            return ka.compareTo(kb);
          });
      case _FavoriteSortBy.facilityType:
        // 温泉=0, 銭湯=1, サウナ=2, その他=3 の順。タイプ内は名前順。
        const typeOrder = {
          'onsen': 0,
          'public_bath': 1,
          'sauna': 2,
        };
        result = List.of(result)
          ..sort((a, b) {
            final oa = typeOrder[a.facilityType] ?? 3;
            final ob = typeOrder[b.facilityType] ?? 3;
            if (oa != ob) return oa.compareTo(ob);
            return (a.nameKana ?? a.name).compareTo(b.nameKana ?? b.name);
          });
    }
    return result;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);

    // 未ログイン時はベネフィット訴求付きでログインを促す
    if (!isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('お気に入り')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withAlpha(180),
                ),
                const SizedBox(height: 20),
                Text(
                  'お気に入りに登録しよう',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '行きたい温泉・銭湯・サウナを\nハートで保存すれば、次から\nすぐに見つけられます。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(160),
                        height: 1.6,
                      ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/login'),
                    child: const Text('ログイン / 新規登録'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final facilitiesAsync = ref.watch(_favoriteFacilitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('お気に入り')),
      body: Column(
        children: [
          // ── 検索バー ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: '施設名・住所で絞り込み',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),

          // ── ソートチップ ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
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
                  label: '追加順',
                  selected: _sortBy == _FavoriteSortBy.addedAt,
                  onSelected: (_) =>
                      setState(() => _sortBy = _FavoriteSortBy.addedAt),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: '名前順',
                  selected: _sortBy == _FavoriteSortBy.name,
                  onSelected: (_) =>
                      setState(() => _sortBy = _FavoriteSortBy.name),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: 'タイプ別',
                  selected: _sortBy == _FavoriteSortBy.facilityType,
                  onSelected: (_) =>
                      setState(() => _sortBy = _FavoriteSortBy.facilityType),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          const Divider(height: 1),

          // ── 施設リスト ────────────────────────────────────────────────
          Expanded(
            child: facilitiesAsync.when(
              data: (all) {
                final facilities = _filter(all);

                if (all.isEmpty) {
                  return const EmptyWidget(
                    icon: Icons.favorite_border,
                    message: 'お気に入りはまだありません\n施設を探してお気に入りに追加しましょう',
                  );
                }

                if (facilities.isEmpty) {
                  return EmptyWidget(
                    icon: Icons.search_off,
                    message: '「$_searchQuery」に一致する施設はありません',
                    action: TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Text('検索をクリア'),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: facilities.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final facility = facilities[i];
                    return Dismissible(
                      key: Key(facility.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red.shade400,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        ref
                            .read(favoritesProvider.notifier)
                            .toggle(facility.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('${facility.displayName}をお気に入りから削除しました'),
                            action: SnackBarAction(
                              label: '元に戻す',
                              onPressed: () => ref
                                  .read(favoritesProvider.notifier)
                                  .toggle(facility.id),
                            ),
                          ),
                        );
                      },
                      // UX-V13-5: 施設タイルの右にプラン追加・その他メニューを配置
                      child: Row(
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
                          // ポップアップメニュー: 「地図で見る」「プランに追加」「削除」
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.grey, size: 20),
                            tooltip: 'メニュー',
                            onSelected: (value) {
                              if (value == 'show_on_map') {
                                // mapFlyToProvider に座標をセット → MapScreen がカメラを移動する
                                ref.read(mapFlyToProvider.notifier).state = (
                                  lat: facility.latitude,
                                  lng: facility.longitude,
                                );
                                // homeTabIndexProvider を 0（地図タブ）に切り替える
                                ref.read(homeTabIndexProvider.notifier).state =
                                    0;
                              } else if (value == 'add_to_plan') {
                                showAddToPlanSheet(context, facility);
                              } else if (value == 'remove') {
                                // お気に入りから削除（スワイプ削除と同じ動作）
                                ref
                                    .read(favoritesProvider.notifier)
                                    .toggle(facility.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${facility.displayName}をお気に入りから削除しました'),
                                    action: SnackBarAction(
                                      label: '元に戻す',
                                      onPressed: () => ref
                                          .read(favoritesProvider.notifier)
                                          .toggle(facility.id),
                                    ),
                                  ),
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
                              const PopupMenuItem(
                                value: 'add_to_plan',
                                child: Row(
                                  children: [
                                    Icon(Icons.playlist_add_outlined,
                                        size: 18),
                                    SizedBox(width: 8),
                                    Text('プランに追加'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(Icons.favorite_border,
                                        size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('お気に入りから削除',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => AppErrorWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(_favoriteFacilitiesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
