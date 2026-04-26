// lib/features/profile/screens/plan_detail_screen.dart
//
// プラン詳細画面。
// 湯めぐりプランに登録された施設の一覧を表示・削除・並べ替えできる。
// Bug-V11-2 / UX-V11-4 対応: 施設削除（トラッシュボタン）と並べ替え（ドラッグ）を追加。
// N+1修正: getFacilitiesByIds で1回のINクエリに変更。
// プラン地図表示: 施設が1件以上ある場合に OpenStreetMap でルートを表示する。

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/features/search/widgets/facility_list_tile.dart';
import 'package:yu_map/models/onsen_plan.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/plan_provider.dart';

// ── プロバイダー ──────────────────────────────────────────────────────────────

/// プランに含まれる施設 ID リストから施設オブジェクトを一括取得するプロバイダー。
///
/// [getFacilitiesByIds] を使って1回の IN クエリで全施設を取得する（N+1防止）。
/// [facilityIds] の順序を維持して返す。
final planFacilitiesProvider = FutureProvider.autoDispose
    .family<List<Facility>, List<String>>((ref, facilityIds) async {
  if (facilityIds.isEmpty) return [];

  final service = ref.watch(facilityServiceProvider);
  if (service == null) return [];

  // 1回の IN クエリで全件取得（N+1防止）
  return service.getFacilitiesByIds(facilityIds);
});

// ── 画面本体 ──────────────────────────────────────────────────────────────────

/// プラン詳細画面。
///
/// 施設一覧の表示・施設の削除・並べ替えができる。
/// ローカル状態で施設リストを管理し、操作の即時反映とDB同期を両立する。
class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({super.key, required this.plan});

  final OnsenPlan plan;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  /// ローカルで管理する施設リスト（削除・並べ替えの即時反映用）。
  /// null = まだ初期化されていない（ローディング中）
  List<Facility>? _localFacilities;

  /// DB 書き込み中フラグ（二重操作防止）
  bool _isUpdating = false;

  /// 地図セクションの表示/非表示フラグ
  bool _mapExpanded = true;

  // ── ビルド ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final facilitiesAsync =
        ref.watch(planFacilitiesProvider(widget.plan.facilityIds));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.title),
        bottom: widget.plan.facilityIds.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${_localFacilities?.length ?? widget.plan.facilityIds.length}施設',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ),
              ),
      ),
      body: facilitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                '施設の読み込みに失敗しました',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref
                    .invalidate(planFacilitiesProvider(widget.plan.facilityIds)),
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
        data: (facilities) {
          // 初回データ取得時にローカルリストを初期化する
          if (_localFacilities == null && facilities.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _localFacilities = List.of(facilities));
            });
          }

          final displayFacilities = _localFacilities ?? facilities;

          // 施設未追加の空状態
          if (widget.plan.facilityIds.isEmpty) {
            return _buildEmptyState(context);
          }

          // ID はあるが施設データが取得できなかった場合
          if (displayFacilities.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_outlined,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    '施設情報を取得できませんでした',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(
                        planFacilitiesProvider(widget.plan.facilityIds)),
                    child: const Text('再試行'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // ── 地図セクション（1件以上の施設がある場合に表示）────────────
              _PlanMapSection(
                facilities: displayFacilities,
                expanded: _mapExpanded,
                onToggle: () =>
                    setState(() => _mapExpanded = !_mapExpanded),
              ),
              // 操作ヒントバー
              Container(
                width: double.infinity,
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.drag_handle,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      '長押しして順番を変更できます',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  // Flutter 標準のドラッグハンドルは使わず、独自ハンドルを使う
                  buildDefaultDragHandles: false,
                  itemCount: displayFacilities.length,
                  itemBuilder: (context, index) {
                    final facility = displayFacilities[index];
                    return _FacilityReorderItem(
                      // key は並べ替えアニメーションに必須
                      key: ValueKey(facility.id),
                      facility: facility,
                      index: index,
                      isUpdating: _isUpdating,
                      onDelete: () => _deleteFacility(facility),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/facility',
                        arguments: facility.id,
                      ),
                    );
                  },
                  onReorder: _onReorder,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── 空状態ウィジェット ─────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_location_alt_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'まだ施設が追加されていません',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '施設詳細画面の「プランに追加」から登録できます',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── 施設削除 ──────────────────────────────────────────────────────────────

  Future<void> _deleteFacility(Facility facility) async {
    // 削除確認ダイアログを表示する
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('施設を削除'),
        content: Text('「${facility.name}」をプランから削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 削除前の施設 ID リストを記録する（楽観的更新後でも正しい差分を DB に送るため）
    // widget.plan.facilityIds は画面遷移時点で固定されるため、
    // 複数回削除するときは _localFacilities を使わないと古いリストで上書きしてしまう。
    final preRemovalIds = _localFacilities?.map((f) => f.id).toList()
        ?? widget.plan.facilityIds;
    final removedFacility = facility;

    // 即時 UI に反映してからDBを更新する（楽観的更新）
    setState(() {
      _isUpdating = true;
      _localFacilities?.removeWhere((f) => f.id == removedFacility.id);
    });

    try {
      await ref.read(planNotifierProvider.notifier).removeFacilityFromPlan(
            planId: widget.plan.id,
            facilityId: removedFacility.id,
            currentFacilityIds: preRemovalIds,
          );
    } catch (_) {
      // DB 更新失敗時はローカルリストをリセットして再取得する
      if (mounted) {
        setState(() => _localFacilities = null);
        ref.invalidate(planFacilitiesProvider(widget.plan.facilityIds));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除に失敗しました。再度お試しください')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ── 並べ替え ──────────────────────────────────────────────────────────────

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_localFacilities == null) return;

    // ReorderableListView は「後ろに移動」するとき newIndex が +1 される仕様のため補正
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;

    final updated = List<Facility>.of(_localFacilities!);
    final item = updated.removeAt(oldIndex);
    updated.insert(adjustedNew, item);

    // 即時 UI に反映してからDBを更新する（楽観的更新）
    setState(() {
      _isUpdating = true;
      _localFacilities = updated;
    });

    try {
      await ref.read(planNotifierProvider.notifier).reorderFacilitiesInPlan(
            planId: widget.plan.id,
            newFacilityIds: updated.map((f) => f.id).toList(),
          );
    } catch (_) {
      if (mounted) {
        setState(() => _localFacilities = null);
        ref.invalidate(planFacilitiesProvider(widget.plan.facilityIds));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('並べ替えに失敗しました。再度お試しください')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }
}

// ── プラン地図セクション ──────────────────────────────────────────────────────

/// プランに含まれる施設をOpenStreetMapで表示する折りたたみ可能なセクション。
///
/// 施設が1件以上ある場合に表示する。複数施設がある場合は全施設が収まる
/// ズームレベルに自動フィットする。
class _PlanMapSection extends StatelessWidget {
  const _PlanMapSection({
    required this.facilities,
    required this.expanded,
    required this.onToggle,
  });

  final List<Facility> facilities;
  final bool expanded;
  final VoidCallback onToggle;

  /// UX-V13-4: Google Maps でルートを開く。
  /// 施設が1件の場合は目的地を指定、複数の場合は経由地を含むルート URL を生成する。
  Future<void> _openGoogleMaps() async {
    if (facilities.isEmpty) return;
    final Uri uri;
    if (facilities.length == 1) {
      final f = facilities.first;
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${f.latitude},${f.longitude}'
        '&travelmode=driving',
      );
    } else {
      // 先頭を出発地、末尾を目的地、中間を経由地とするルート
      final origin = facilities.first;
      final dest = facilities.last;
      final waypoints = facilities.length > 2
          ? facilities
              .sublist(1, facilities.length - 1)
              .map((f) => '${f.latitude},${f.longitude}')
              .join('|')
          : null;
      final waypointParam =
          waypoints != null ? '&waypoints=$waypoints' : '';
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${origin.latitude},${origin.longitude}'
        '&destination=${dest.latitude},${dest.longitude}'
        '$waypointParam'
        '&travelmode=driving',
      );
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// 全施設が収まる中心点とズームレベルを計算する。
  /// 施設が1件の場合は固定ズーム13で表示する。
  ({ll.LatLng center, double zoom}) _computeBounds() {
    if (facilities.isEmpty) {
      return (center: ll.LatLng(35.6812, 139.7671), zoom: 10.0); // 東京（フォールバック）
    }
    if (facilities.length == 1) {
      return (
        center: ll.LatLng(facilities[0].latitude, facilities[0].longitude),
        zoom: 13.0,
      );
    }

    // 全施設の緯度・経度の範囲を計算する
    final lats = facilities.map((f) => f.latitude).toList()..sort();
    final lngs = facilities.map((f) => f.longitude).toList()..sort();
    final minLat = lats.first;
    final maxLat = lats.last;
    final minLng = lngs.first;
    final maxLng = lngs.last;

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // 範囲の広さに基づいてズームレベルを決定する（大きいほどズームアウト）
    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;

    double zoom;
    if (maxSpan < 0.01) {
      zoom = 14.0; // 1km 未満
    } else if (maxSpan < 0.05) {
      zoom = 13.0; // 5km 未満
    } else if (maxSpan < 0.2) {
      zoom = 11.0; // 20km 未満
    } else if (maxSpan < 1.0) {
      zoom = 9.0;  // 100km 未満
    } else {
      zoom = 7.0;  // 100km 以上
    }

    return (center: ll.LatLng(centerLat, centerLng), zoom: zoom);
  }

  /// 施設タイプに応じたマーカー色を返す
  static Color _colorForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'onsen':
        return const Color(0xFFE53935);
      case 'public_bath':
        return const Color(0xFF1976D2);
      case 'sauna':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF7B1FA2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 地図セクションのヘッダー（タップで展開/折りたたみ）
        InkWell(
          onTap: onToggle,
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'ルートマップ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                // UX-V13-4: Google Maps でルート案内を開くボタン
                GestureDetector(
                  onTap: _openGoogleMaps,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ナビ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),
        // 地図本体（AnimatedContainer でスムーズに展開/折りたたみ）
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: expanded ? 200.0 : 0.0,
          child: expanded
              ? _buildMap()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMap() {
    final bounds = _computeBounds();
    return FlutterMap(
      options: MapOptions(
        initialCenter: bounds.center,
        initialZoom: bounds.zoom,
        interactionOptions: const InteractionOptions(
          // プラン詳細のリストとスクロールが競合しないようにマップ内操作のみ有効
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        // OpenStreetMap タイルレイヤー
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.yumap.app',
        ),
        // 施設マーカー
        MarkerLayer(
          markers: facilities.asMap().entries.map((entry) {
            final index = entry.key;
            final facility = entry.value;
            final color = _colorForType(facility.facilityType);
            return Marker(
              point: ll.LatLng(facility.latitude, facility.longitude),
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ピン本体
                  Icon(Icons.location_pin, color: color, size: 36),
                  // 順番番号バッジ（1-indexed）
                  Positioned(
                    top: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: color,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── 施設リストアイテム（ドラッグハンドル＋削除ボタン付き）──────────────────────

/// プラン詳細用の施設リストアイテム。
///
/// 左端のドラッグハンドル（≡アイコン）で並べ替え、右端のゴミ箱ボタンで削除できる。
class _FacilityReorderItem extends StatelessWidget {
  const _FacilityReorderItem({
    super.key,
    required this.facility,
    required this.index,
    required this.isUpdating,
    required this.onDelete,
    required this.onTap,
  });

  final Facility facility;
  final int index;

  /// DB 書き込み中フラグ。true の間は操作を無効化する。
  final bool isUpdating;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── ドラッグハンドル ──────────────────────────────────────────────
        // ReorderableDragStartListener でラップすることで、
        // このアイコンを長押しするとドラッグ開始できる
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Icon(
              Icons.drag_handle,
              color: isUpdating ? Colors.grey[300] : Colors.grey[500],
            ),
          ),
        ),
        // ── 施設情報タイル ────────────────────────────────────────────────
        Expanded(
          child: FacilityListTile(
            facility: facility,
            onTap: isUpdating ? null : onTap,
          ),
        ),
        // ── 削除ボタン ────────────────────────────────────────────────────
        IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: isUpdating ? Colors.grey[300] : Colors.red[300],
          ),
          tooltip: '施設を削除',
          onPressed: isUpdating ? null : onDelete,
        ),
      ],
    );
  }
}
