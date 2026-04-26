// lib/features/profile/screens/visit_history_screen.dart
//
// 訪問履歴の全件表示画面（UX-V7-1対応）。
//
// プロフィール画面の「すべて見る →」からナビゲートされる。
// 月別にグループ化して表示し、施設タイルをタップすると施設詳細に遷移する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/core/widgets/empty_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/providers/visit_provider.dart';

class VisitHistoryScreen extends ConsumerWidget {
  const VisitHistoryScreen({super.key});

  static final _dateFormat = DateFormat('yyyy/MM/dd');
  static final _monthFormat = DateFormat('yyyy年M月');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitAsync = ref.watch(visitAllProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('訪問履歴'),
      ),
      body: visitAsync.when(
        loading: () => const LoadingWidget(),
        error: (_, __) => const EmptyWidget(
          icon: Icons.error_outline,
          message: '訪問履歴の取得に失敗しました',
        ),
        data: (visits) {
          if (visits.isEmpty) {
            return const EmptyWidget(
              icon: Icons.place_outlined,
              message: 'まだ訪問記録がありません',
            );
          }

          // 月別にグループ化する（例: 「2026年4月」→ [Visit, Visit, ...]）
          final grouped = <String, List<Visit>>{};
          for (final visit in visits) {
            final monthKey = _monthFormat.format(visit.visitedAt);
            grouped.putIfAbsent(monthKey, () => []).add(visit);
          }

          // グループのキー一覧（順序を保持するため insertionOrder を使う）
          final monthKeys = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: monthKeys.length,
            itemBuilder: (context, sectionIndex) {
              final monthKey = monthKeys[sectionIndex];
              final monthVisits = grouped[monthKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 月ヘッダー
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      monthKey,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const Divider(height: 1, indent: 16),
                  // 月内の訪問一覧
                  ...monthVisits.map(
                    (visit) => _VisitTile(
                      visit: visit,
                      dateFormat: _dateFormat,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── 訪問タイル ─────────────────────────────────────────────────────────────────

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit, required this.dateFormat});

  final Visit visit;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final facilityName = visit.facilityName ?? visit.facilityId;

    return ListTile(
      leading: const Icon(Icons.place_outlined, color: Color(0xFF1565C0)),
      title: Text(
        facilityName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(dateFormat.format(visit.visitedAt)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: () => Navigator.of(context).pushNamed(
        '/facility',
        arguments: visit.facilityId,
      ),
    );
  }
}
