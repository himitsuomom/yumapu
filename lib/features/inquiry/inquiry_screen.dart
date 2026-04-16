// lib/features/inquiry/inquiry_screen.dart
//
// 問い合わせフォーム画面。
// 「営業時間変更を報告」と「未登録施設を追加申請」の2種類に対応。
// 送信先: Supabase の inquiries テーブル（誰でも送信可・ログイン不要）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// 問い合わせ種別
enum InquiryType {
  hoursChange, // 営業時間・定休日の変更報告
  addFacility, // 未登録施設の追加申請
}

/// InquiryScreen — 施設詳細から呼び出す問い合わせフォーム
class InquiryScreen extends ConsumerStatefulWidget {
  /// 問い合わせ種別（タイトルや説明文が変わる）
  final InquiryType type;

  /// 施設詳細から開く場合は施設名を渡す（省略可能）
  final String? initialFacilityName;

  const InquiryScreen({
    super.key,
    required this.type,
    this.initialFacilityName,
  });

  @override
  ConsumerState<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends ConsumerState<InquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _facilityNameCtrl;
  final TextEditingController _messageCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _facilityNameCtrl =
        TextEditingController(text: widget.initialFacilityName ?? '');
  }

  @override
  void dispose() {
    _facilityNameCtrl.dispose();
    _messageCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  // ── 問い合わせ種別ごとの設定値 ──────────────────────────────────────────

  String get _title => widget.type == InquiryType.hoursChange
      ? '営業時間変更を報告'
      : '未登録施設を追加申請';

  String get _description => widget.type == InquiryType.hoursChange
      ? '営業時間・定休日が変わっていることを教えてください。\n運営チームが確認して更新します。'
      : '地図に載っていない銭湯・サウナ・温泉の情報を教えてください。\n審査のうえ追加します。';

  String get _facilityNameHint => widget.type == InquiryType.hoursChange
      ? '例: 〇〇温泉'
      : '例: △△銭湯（新規）';

  String get _messageHint => widget.type == InquiryType.hoursChange
      ? '変更内容（例: 月曜定休になった、朝10時〜22時になった）'
      : '施設の住所・電話番号・営業時間など分かる範囲でご記入ください';

  String get _typeValue => widget.type == InquiryType.hoursChange
      ? 'hours_change'
      : 'add_facility';

  // ── フォーム送信 ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // async 前に context 依存オブジェクトを確保（非同期ギャップ後の context 使用を回避）
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);

    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) throw Exception('サーバーに接続できません');

      // ログイン済みなら user_id も保存する（RLSで自分の問い合わせを閲覧できる）
      final userId = ref.read(sessionProvider)?.user.id;

      await client.from('inquiries').insert({
        'type': _typeValue,
        'facility_name': _facilityNameCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        if (_contactCtrl.text.trim().isNotEmpty)
          'contact': _contactCtrl.text.trim(),
        if (userId != null) 'user_id': userId,
      });

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('送信しました。ご協力ありがとうございます！'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('送信に失敗しました。通信環境を確認して再度お試しください。'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 説明文
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 施設名（必須）
              _RequiredLabel(label: '施設名'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _facilityNameCtrl,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(_facilityNameHint),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '施設名を入力してください' : null,
              ),
              const SizedBox(height: 20),

              // 本文（必須）
              _RequiredLabel(label: '詳細・内容'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageCtrl,
                minLines: 4,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                decoration: _inputDecoration(_messageHint),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '内容を入力してください' : null,
              ),
              const SizedBox(height: 20),

              // 連絡先メール（任意）
              const Text(
                '連絡先メール（任意）',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _contactCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: _inputDecoration('example@mail.com'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final emailRegex =
                      RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
                  return emailRegex.hasMatch(v.trim())
                      ? null
                      : '正しいメールアドレスを入力してください';
                },
              ),
              const SizedBox(height: 32),

              // 送信ボタン
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text(
                    '送信する',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '必須',
            style: TextStyle(fontSize: 11, color: Colors.red.shade600),
          ),
        ),
      ],
    );
  }
}
