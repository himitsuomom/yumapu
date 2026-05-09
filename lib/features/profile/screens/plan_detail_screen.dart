// lib/features/profile/screens/plan_detail_screen.dart
//
// プラン詳細画面。
// 湯めぐりプランに登録された施設の一覧を表示・削除・並べ替えできる。

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/features/search/widgets/facility_list_tile.dart';
import 'package:yu_map/models/onsen_plan.dart';
import 'package:yu_map/providers/facility_provider.dart';
import 'package:yu_map/providers/plan_provider.dart';

part 'plan_detail_screen_sub_widgets.dart';

// ── プロバイダー ──────────────────────────────────────────────────────────────

final planFacilitiesProvider = FutureProvider.autoDispose
    .family<List<Facility>, List<String>>((ref, facilityIds) async {
  if (facilityIds.isEmpty) return [];

  final service = ref.watch(facilityServiceProvider);
  if (service == null) return [];

  return service.getFacilitiesByIds(facilityIds);
});

// ── 画面本体 ──────────────────────────────────────────────────────────────────

class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({super.key, required this.plan});

  final OnsenPlan plan;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  List<Facility>? _localFacilities;
  bool _isUpdating = false;
  bool _mapExpanded = true;

  void _sharePlan(List<Facility> facilities) {
    if (facilities.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('🗺️ 湯めぐりプラン「${widget.plan.title}」');
    buffer.writeln();
    for (var i = 0; i < facilities.length; i++) {
      final f = facilities[i];
      buffer.write('${i + 1}. ${f.name}');
      if (f.address != null && f.address!.isNotEmpty) {
        buffer.write('（${f.address}）');
      }
      buffer.writeln();
    }
    buffer.writeln();
    buffer.write('#湯マップ #温泉 #湯めぐり');

    Share.share(buffer.toString(), subject: '湯めぐりプラン「${widget.plan.title}」');
  }

  @override
  Widget build(BuildContext context) {
    final facilitiesAsync =
        ref.watch(planFacilitiesProvider(widget.plan.facilityIds));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.title),
        actions: _localFacilities != null && _localFacilities!.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.ios_share_outlined),
                  tooltip: 'プランを共有',
                  onPressed: () => _sharePlan(_localFacilities!),
                ),
              ]
            : null,
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
          if (_localFacilities == null && facilities.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _localFacilities = List.of(facilities));
            });
          }

          final displayFacilities = _localFacilities ?? facilities;

          if (widget.plan.facilityIds.isEmpty) {
            return _buildEmptyState(context);
          }

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
              _PlanMapSection(
                facilities: displayFacilities,
                expanded: _mapExpanded,
                onToggle: () =>
                    setState(() => _mapExpanded = !_mapExpanded),
              ),
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
                  buildDefaultDragHandles: false,
                  itemCount: displayFacilities.length,
                  itemBuilder: (context, index) {
                    final facility = displayFacilities[index];
                    return _FacilityReorderItem(
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

  Future<void> _deleteFacility(Facility facility) async {
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

    final preRemovalIds = _localFacilities?.map((f) => f.id).toList()
        ?? widget.plan.facilityIds;
    final removedFacility = facility;

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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_localFacilities == null) return;

    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;

    final updated = List<Facility>.of(_localFacilities!);
    final item = updated.removeAt(oldIndex);
    updated.insert(adjustedNew, item);

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
