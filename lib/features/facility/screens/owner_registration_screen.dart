// lib/features/facility/screens/owner_registration_screen.dart
//
// オーナー登録申請画面
//
// 施設のオーナー・管理者が「自分がこの施設の管理者です」と
// 申請するためのフォーム画面。
// 送信先: Supabase の owner_registrations テーブル
// ※ログイン必須（申請者の身元を管理するため）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// オーナー登録申請画面
///
/// [facilityId]   : 申請対象の施設 ID（必須）
/// [facilityName] : 施設名（AppBar と説明文に使用）
class OwnerRegistrationScreen extends ConsumerStatefulWidget {
  const OwnerRegistrationScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  final String facilityId;
  final String facilityName;

  @override
  ConsumerState<OwnerRegistrationScreen> createState() =>
      _OwnerRegistrationScreenState();
}

class _OwnerRegistrationScreenState
    extends ConsumerState<OwnerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameCtrl = TextEditingController();
  final _ownerEmailCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _ownerEmailCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  // ── フォーム送信 ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // 非同期処理前に context 依存オブジェクトを確保
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);

    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) throw Exception('サーバーに接続できません');

      final userId = ref.read(sessionProvider)?.user.id;
      if (userId == null) throw Exception('ログインが必要です');

      await client.from('owner_registrations').insert({
        'facility_id': widget.facilityId,
        'user_id': userId,
        'owner_name': _ownerNameCtrl.text.trim(),
        'owner_email': _ownerEmailCtrl.text.trim(),
        if (_ownerPhoneCtrl.text.trim().isNotEmpty)
          'owner_phone': _ownerPhoneCtrl.text.trim(),
        if (_messageCtrl.text.trim().isNotEmpty)
          'message': _messageCtrl.text.trim(),
      });

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('申請を送信しました。審査結果をお待ちください。'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      navigator.pop();
    } on Exception catch (e) {
      if (!mounted) return;

      // 重複申請（UNIQUE制約違反）のときは専用メッセージを表示
      final msg = e.toString();
      final isDuplicate =
          msg.contains('owner_registrations_no_duplicate_idx') ||
          msg.contains('duplicate key');

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isDuplicate
                ? 'この施設にはすでに申請済みです。審査結果をお待ちください。'
                : '送信に失敗しました。通信環境を確認して再度お試しください。',
          ),
          backgroundColor: isDuplicate ? Colors.orange : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);

    // ログインしていない場合はログイン促進画面を表示
    if (!isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('オーナー登録')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                const Text(
                  'オーナー登録にはログインが必要です',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '申請者の身元を確認するためにアカウントが必要です。',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/login'),
                  child: const Text('ログインする'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('オーナー登録')),
      body: SingleChildScrollView(
        // キーボードが出たとき、下余白をキーボードの高さ分だけ増やす。
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 説明バナー ──────────────────────────────────────────────
              _InfoBanner(
                text:
                    '「${widget.facilityName}」のオーナー・管理者として登録を申請します。\n\n'
                    '運営チームが確認後、施設情報の管理権限をお渡しします。'
                    '審査には数日かかる場合があります。',
              ),
              const SizedBox(height: 24),

              // ── 代表者名（必須）────────────────────────────────────────
              _RequiredLabel(label: '代表者名（担当者名）'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _ownerNameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '例: 山田 太郎',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return '代表者名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── メールアドレス（必須）──────────────────────────────────
              _RequiredLabel(label: 'メールアドレス'),
              const SizedBox(height: 4),
              Text(
                '審査結果の通知先になります',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _ownerEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '例: owner@example.com',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  // 簡易メール形式チェック
                  if (!RegExp(r'^[\w\-\.]+@[\w\-\.]+\.\w+$')
                      .hasMatch(v.trim())) {
                    return '正しいメールアドレスを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── 電話番号（任意）────────────────────────────────────────
              const _OptionalLabel(label: '電話番号（任意）'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _ownerPhoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '例: 03-1234-5678',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // ── 備考・証明（任意）──────────────────────────────────────
              const _OptionalLabel(label: '備考・証明方法（任意）'),
              const SizedBox(height: 4),
              Text(
                'オーナーであることの証明方法や、申請理由をご記入ください\n'
                '例: 施設の看板に連絡先として記載されています',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: '任意でご記入ください',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // ── 注意事項 ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '虚偽の申請は登録の取り消しとアカウント停止の対象になる場合があります。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── 送信ボタン ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.business_outlined),
                  label: Text(_isSubmitting ? '送信中...' : 'オーナー登録を申請する'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 共通ウィジェット ────────────────────────────────────────────────────────────

/// 説明バナー
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.business_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 必須フィールドのラベル（赤い * 付き）
class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
        children: [
          TextSpan(text: label),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }
}

/// 任意フィールドのラベル
class _OptionalLabel extends StatelessWidget {
  const _OptionalLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
