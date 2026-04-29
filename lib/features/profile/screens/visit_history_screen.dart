// lib/features/profile/screens/visit_history_screen.dart
//
// 訪問履歴の全件表示画面（UX-V7-1対応）。
//
// プロフィール画面の「すべて見る →」からナビゲートされる。
// 月別にグループ化して表示し、施設タイルをタップすると施設詳細に遷移する。
//
// 修正履歴:
//   Bug-42: RefreshIndicator 追加（チェックイン後に手動リフレッシュ可能に）
//   Bug-44: エラー時にリトライボタンを表示（EmptyWidget→エラー専用UI）
//   Bug-28: 訪問日で降順ソート後にグループ化し月の表示順が崩れないよう保証

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
        // Bug-44: EmptyWidget（onRetry なし）をリトライボタン付きエラーUIに変更
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                const Text(
                  '訪問履歴の取得に失敗しました',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ネットワーク接続を確認してください',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('再読み込み'),
                  // ref.refresh で Provider を再実行してデータを再取得する
                  onPressed: () => ref.refresh(visitAllProvider),
                ),
              ],
            ),
          ),
        ),
        data: (visits) {
          if (visits.isEmpty) {
            return const EmptyWidget(
              icon: Icons.place_outlined,
              message: 'まだ訪問記録がありません',
            );
          }

          // Bug-28: 訪問日で降順ソートしてから月グループ化する。
          // Dart の Map は挿入順を保持するため、降順ソート後に挿入すれば
          // monthKeys は自動的に「新しい月→古い月」の順になる。
          final sortedVisits = [...visits]
            ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));

          final grouped = <String, List<Visit>>{};
          for (final visit in sortedVisits) {
            final monthKey = _monthFormat.format(visit.visitedAt);
            grouped.putIfAbsent(monthKey, () => []).add(visit);
          }

          final monthKeys = grouped.keys.toList();

          // Bug-42: RefreshIndicator でプルダウンリフレッシュを有効化する。
          // onRefresh は Future を返す必要があるため visitAllProvider.future を使う。
          return RefreshIndicator(
            onRefresh: () => ref.refresh(visitAllProvider.future),
            child: ListView.builder(
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        monthKey,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
            ),
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
