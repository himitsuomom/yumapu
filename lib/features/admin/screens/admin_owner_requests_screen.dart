// lib/features/admin/screens/admin_owner_requests_screen.dart
//
// 管理者専用 — オーナー申請一覧・承認/却下画面
//
// ログイン中ユーザーが is_admin = true の場合にのみ
// 設定画面から遷移できる。
// Supabase の owner_registrations テーブルを操作する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/providers/auth_provider.dart';

// ── データモデル ────────────────────────────────────────────────────────────────

/// オーナー申請 1 件のデータ
class _OwnerRequest {
  final String id;
  final String facilityId;
  final String facilityName;
  final String userId;
  final String ownerName;
  final String ownerEmail;
  final String? ownerPhone;
  final String? message;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime createdAt;

  const _OwnerRequest({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.userId,
    required this.ownerName,
    required this.ownerEmail,
    this.ownerPhone,
    this.message,
    required this.status,
    required this.createdAt,
  });

  factory _OwnerRequest.fromJson(Map<String, dynamic> json) {
    // facilities テーブルをJOINした結果（facilities(name)）を取得する
    final facilityMap =
        json['facilities'] as Map<String, dynamic>? ?? {};

    return _OwnerRequest(
      id: json['id'] as String,
      facilityId: json['facility_id'] as String,
      facilityName: facilityMap['name'] as String? ?? '（施設名不明）',
      userId: json['user_id'] as String,
      ownerName: json['owner_name'] as String,
      ownerEmail: json['owner_email'] as String,
      ownerPhone: json['owner_phone'] as String?,
      message: json['message'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ── 申請一覧プロバイダー ────────────────────────────────────────────────────────

final _ownerRequestsProvider =
    FutureProvider.autoDispose<List<_OwnerRequest>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  if (client == null) return [];

  final data = await client
      .from('owner_registrations')
      .select('*, facilities(name)')
      .order('created_at', ascending: false);

  return (data as List<dynamic>)
      .map((e) => _OwnerRequest.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── 画面本体 ────────────────────────────────────────────────────────────────────

/// 管理者専用のオーナー申請一覧画面
class AdminOwnerRequestsScreen extends ConsumerStatefulWidget {
  const AdminOwnerRequestsScreen({super.key});

  @override
  ConsumerState<AdminOwnerRequestsScreen> createState() =>
      _AdminOwnerRequestsScreenState();
}

class _AdminOwnerRequestsScreenState
    extends ConsumerState<AdminOwnerRequestsScreen> {

  // ── ステータス変更（承認 or 却下）────────────────────────────────────────────

  Future<void> _updateStatus(String requestId, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;

    try {
      await client
          .from('owner_registrations')
          .update({'status': newStatus})
          .eq('id', requestId);

      if (!mounted) return;

      final label = newStatus == 'approved' ? '承認' : '却下';
      messenger.showSnackBar(
        SnackBar(
          content: Text('$labelしました'),
          backgroundColor:
              newStatus == 'approved' ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );

      // リストを再取得して最新状態に更新する
      ref.invalidate(_ownerRequestsProvider);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('更新に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── 確認ダイアログ ─────────────────────────────────────────────────────────

  Future<void> _confirmAndUpdate(
    BuildContext context,
    _OwnerRequest request,
    String newStatus,
  ) async {
    final isApprove = newStatus == 'approved';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? '承認する' : '却下する'),
        content: Text(
          '「${request.facilityName}」の${request.ownerName}さんの申請を'
          '${isApprove ? "承認" : "却下"}しますか？\n\n'
          '${isApprove ? "承認するとオーナーが施設情報を編集できるようになります。" : "この操作は取り消せます（後から変更可能）。"}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isApprove ? Colors.green : Colors.orange,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isApprove ? '承認する' : '却下する'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus(request.id, newStatus);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(_ownerRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('オーナー申請管理'),
        actions: [
          // 手動リフレッシュ
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_ownerRequestsProvider),
            tooltip: '更新',
          ),
        ],
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'データの取得に失敗しました\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Text('申請がありません'),
            );
          }

          // pending（審査待ち）を先頭に、その後 approved・rejected の順で表示
          final sorted = [...requests]..sort((a, b) {
              const order = {'pending': 0, 'approved': 1, 'rejected': 2};
              final oa = order[a.status] ?? 99;
              final ob = order[b.status] ?? 99;
              if (oa != ob) return oa.compareTo(ob);
              return b.createdAt.compareTo(a.createdAt);
            });

          final pendingCount = requests.where((r) => r.status == 'pending').length;

          return Column(
            children: [
              // ── 統計バー ──────────────────────────────────────────────────
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  '全${requests.length}件 ｜ 審査待ち: $pendingCount件',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),

              // ── 申請リスト ────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _RequestCard(
                      request: sorted[index],
                      onApprove: () =>
                          _confirmAndUpdate(context, sorted[index], 'approved'),
                      onReject: () =>
                          _confirmAndUpdate(context, sorted[index], 'rejected'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── 申請カードウィジェット ──────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final _OwnerRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPending = request.status == 'pending';
    final isApproved = request.status == 'approved';

    // ステータスに応じた色とラベルを決定
    final (statusColor, statusLabel) = switch (request.status) {
      'approved' => (Colors.green, '承認済み'),
      'rejected' => (Colors.orange, '却下'),
      _ => (colorScheme.primary, '審査待ち'),
    };

    return Card(
      elevation: isPending ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPending
            ? BorderSide(color: colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ヘッダー行（施設名 + ステータスバッジ）──────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.facilityName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── 申請者情報 ────────────────────────────────────────────────
            _InfoRow(icon: Icons.person_outline, text: request.ownerName),
            const SizedBox(height: 4),
            _InfoRow(icon: Icons.email_outlined, text: request.ownerEmail),
            if (request.ownerPhone != null) ...[
              const SizedBox(height: 4),
              _InfoRow(icon: Icons.phone_outlined, text: request.ownerPhone!),
            ],
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.message!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 8),

            // ── 申請日時 ───────────────────────────────────────────────────
            Text(
              '申請日: ${DateFormat('yyyy/MM/dd HH:mm', 'ja').format(request.createdAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),

            // ── 承認/却下ボタン（pending のときのみ表示）───────────────────
            if (isPending) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('却下'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('承認する'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── 承認済みの場合は取り消しボタンを表示 ──────────────────────
            if (isApproved) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('承認を取り消す'),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 情報行ウィジェット ──────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
