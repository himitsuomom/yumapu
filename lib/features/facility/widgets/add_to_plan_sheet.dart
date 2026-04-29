// lib/features/facility/widgets/add_to_plan_sheet.dart
//
// 施設詳細：「湯めぐりプランに追加」ボトムシート
// 既存プラン一覧を表示し、タップで追加。新規プラン作成フォームも含む。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/models/onsen_plan.dart';
import 'package:yu_map/providers/plan_provider.dart';

/// 施設詳細画面や外部画面から「プランに追加」ボトムシートを表示する公開ヘルパー。
///
/// 使用例（お気に入り画面など）:
/// ```dart
/// showAddToPlanSheet(context, facility);
/// ```
Future<void> showAddToPlanSheet(
    BuildContext context, Facility facility) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => AddToPlanSheet(facility: facility),
  );
}

/// 湯めぐりプランに施設を追加するボトムシート本体。
/// 既存プラン一覧を表示し、タップで追加。新規プラン作成フォームも含む。
class AddToPlanSheet extends ConsumerStatefulWidget {
  const AddToPlanSheet({super.key, required this.facility});

  final Facility facility;

  @override
  ConsumerState<AddToPlanSheet> createState() => _AddToPlanSheetState();
}

class _AddToPlanSheetState extends ConsumerState<AddToPlanSheet> {
  bool _showCreateForm = false;
  final _titleCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(myPlansProvider);
    final planState = ref.watch(planNotifierProvider);
    final isLoading = planState is AsyncLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ドラッグハンドル
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

          Text(
            '湯めぐりプランに追加',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // プラン一覧
          plansAsync.when(
            data: (plans) {
              if (plans.isEmpty && !_showCreateForm) {
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'プランがまだありません。\n新しいプランを作成しましょう！',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('新しいプランを作成'),
                      onPressed: () => setState(() => _showCreateForm = true),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...plans.map((plan) {
                    final alreadyAdded =
                        plan.containsFacility(widget.facility.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.hot_tub_outlined),
                      title: Text(plan.title),
                      subtitle: Text(
                        '${plan.facilityIds.length}施設',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: alreadyAdded
                          ? const Icon(Icons.check_circle,
                              color: Colors.green)
                          : const Icon(Icons.add_circle_outline),
                      onTap: alreadyAdded || isLoading
                          ? null
                          : () => _addToPlan(plan),
                    );
                  }),

                  const Divider(height: 24),

                  // 新規プラン作成ボタン
                  if (!_showCreateForm)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('新しいプランを作成'),
                      onPressed: () => setState(() => _showCreateForm = true),
                    ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const Text('プランの取得に失敗しました'),
          ),

          // 新規プラン作成フォーム
          if (_showCreateForm) ...[
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _titleCtrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'プラン名',
                  hintText: '例: 東京銭湯めぐり',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'プラン名を入力してください' : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showCreateForm = false),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isLoading ? null : _createPlanAndAdd,
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('作成して追加'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addToPlan(OnsenPlan plan) async {
    await ref.read(planNotifierProvider.notifier).addFacilityToPlan(
          planId: plan.id,
          facilityId: widget.facility.id,
          currentFacilityIds: plan.facilityIds,
        );

    if (!mounted) return;

    final state = ref.read(planNotifierProvider);
    if (state is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('追加に失敗しました: ${state.error}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ref.invalidate(myPlansProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${plan.title}」に追加しました'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _createPlanAndAdd() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newPlan = await ref.read(planNotifierProvider.notifier).createPlan(
          title: _titleCtrl.text.trim(),
        );

    if (!mounted) return;
    if (newPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('プランの作成に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await ref.read(planNotifierProvider.notifier).addFacilityToPlan(
          planId: newPlan.id,
          facilityId: widget.facility.id,
          currentFacilityIds: newPlan.facilityIds,
        );

    if (!mounted) return;

    ref.invalidate(myPlansProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${newPlan.title}」を作成して追加しました'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }
}
