// lib/features/profile/screens/plans_screen.dart
//
// 湯めぐりプラン一覧画面。
// ログイン中ユーザーが作成したプランを一覧表示し、
// プランの作成・削除ができる。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/models/onsen_plan.dart';
import 'package:yu_map/providers/plan_provider.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  static final _dateFormat = DateFormat('yyyy/MM/dd', 'ja');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(myPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('湯めぐりプラン'),
      ),
      // FloatingActionButton でプラン新規作成
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePlanDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('プランを作成'),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('読み込みに失敗しました', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(myPlansProvider),
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'プランがまだありません',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '行きたい施設をまとめてプランを作ろう',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final plan = plans[index];
              return _PlanCard(
                plan: plan,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/plan-detail',
                  arguments: plan,
                ),
                onDelete: () => _confirmDelete(context, ref, plan),
              );
            },
          );
        },
      ),
    );
  }

  // ── プラン作成ダイアログ ────────────────────────────────────────────────────

  Future<void> _showCreatePlanDialog(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新しいプランを作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'プラン名',
                hintText: '例: 週末の日帰り温泉',
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
              maxLength: 50,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                hintText: '例: 友達と行く予定',
              ),
              maxLines: 2,
              maxLength: 200,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('作成'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final title = titleController.text.trim();
    if (title.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プラン名を入力してください')),
        );
      }
      return;
    }

    final plan = await ref.read(planNotifierProvider.notifier).createPlan(
          title: title,
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
        );

    if (!context.mounted) return;
    if (plan != null) {
      ref.invalidate(myPlansProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${plan.title}」を作成しました')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('作成に失敗しました。もう一度お試しください')),
      );
    }
  }

  // ── プラン削除確認 ─────────────────────────────────────────────────────────

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, OnsenPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('プランを削除'),
        content: Text('「${plan.title}」を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(planNotifierProvider.notifier).deletePlan(plan.id);

    if (!context.mounted) return;
    ref.invalidate(myPlansProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${plan.title}」を削除しました')),
    );
  }
}

// ── プランカード ───────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.onDelete,
    required this.onTap,
  });

  final OnsenPlan plan;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 削除ボタン
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.grey[500],
                  tooltip: '削除',
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                plan.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${plan.facilityIds.length}施設',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Text(
                  PlansScreen._dateFormat.format(plan.updatedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}
