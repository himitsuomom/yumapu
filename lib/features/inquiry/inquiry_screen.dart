// lib/features/inquiry/inquiry_screen.dart
//
// 問い合わせフォーム画面。
// 「営業時間変更を報告」「未登録施設を追加申請」「バグ報告」「一般問い合わせ」に対応。
// 送信先: Supabase の inquiries テーブル（誰でも送信可・ログイン不要）
//
// 修正履歴:
//   UX-60: バグ報告時にOS・アプリバージョン情報を自動添付（package_info_plus 不要）

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// 問い合わせ種別
enum InquiryType {
  hoursChange, // 営業時間・定休日の変更報告
  addFacility, // 未登録施設の追加申請
  bugReport,   // バグ・不具合の報告（D-3対応）
  general,     // 一般的なご意見・機能要望（D-3対応）
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

  String get _title {
    switch (widget.type) {
      case InquiryType.hoursChange:
        return '営業時間変更を報告';
      case InquiryType.addFacility:
        return '未登録施設を追加申請';
      case InquiryType.bugReport:
        return 'バグを報告する';
      case InquiryType.general:
        return 'お問い合わせ';
    }
  }

  String get _description {
    switch (widget.type) {
      case InquiryType.hoursChange:
        return '営業時間・定休日が変わっていることを教えてください。\n運営チームが確認して更新します。';
      case InquiryType.addFacility:
        return '地図に載っていない銭湯・サウナ・温泉の情報を教えてください。\n審査のうえ追加します。';
      case InquiryType.bugReport:
        return '不具合・動作がおかしい場合にご報告ください。\nできるだけ再現手順を詳しく書いていただけると助かります。';
      case InquiryType.general:
        return '機能要望・ご意見・その他のお問い合わせをお気軽にお送りください。';
    }
  }

  String get _facilityNameHint {
    switch (widget.type) {
      case InquiryType.hoursChange:
        return '例: 〇〇温泉';
      case InquiryType.addFacility:
        return '例: △△銭湯（新規）';
      case InquiryType.bugReport:
        return '（任意）どの画面で問題が発生しましたか？';
      case InquiryType.general:
        return '（任意）関連する施設や機能があればご記入ください';
    }
  }

  String get _messageHint {
    switch (widget.type) {
      case InquiryType.hoursChange:
        return '変更内容（例: 月曜定休になった、朝10時〜22時になった）';
      case InquiryType.addFacility:
        return '施設の住所・電話番号・営業時間など分かる範囲でご記入ください';
      case InquiryType.bugReport:
        return 'どんな操作をしたか・何が起きたか・再現手順など詳しく教えてください';
      case InquiryType.general:
        return 'ご自由にご記入ください';
    }
  }

  String get _typeValue {
    switch (widget.type) {
      case InquiryType.hoursChange:
        return 'hours_change';
      case InquiryType.addFacility:
        return 'add_facility';
      case InquiryType.bugReport:
        return 'bug_report';
      case InquiryType.general:
        return 'general';
    }
  }

  /// バグ報告・一般問い合わせは施設名が任意（必須バリデーションを外す）
  bool get _isFacilityNameRequired =>
      widget.type == InquiryType.hoursChange ||
      widget.type == InquiryType.addFacility;

  // ── フォーム送信 ──────────────────────────────────────────────────────────

  /// バグ報告時に自動添付する端末・アプリ情報を組み立てる（UX-60対応）。
  ///
  /// package_info_plus は使わず、dart:io の Platform と AppConstants.appVersion で
  /// OS種別・バージョン・アプリバージョンを取得する。
  String _buildDeviceInfo() {
    final os = Platform.isIOS
        ? 'iOS ${Platform.operatingSystemVersion}'
        : Platform.isAndroid
            ? 'Android ${Platform.operatingSystemVersion}'
            : Platform.operatingSystem;
    return '[端末情報]\nOS: $os\nアプリ: v${AppConstants.appVersion}\n\n';
  }

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

      // UX-60: バグ報告の場合は端末情報を本文の先頭に自動付与する。
      // ユーザーが書いた内容をそのまま添付するため、改行でつなぐ。
      final userMessage = _messageCtrl.text.trim();
      final messageToSend = widget.type == InquiryType.bugReport
          ? '${_buildDeviceInfo()}$userMessage'
          : userMessage;

      await client.from('inquiries').insert({
        'type': _typeValue,
        'facility_name': _facilityNameCtrl.text.trim(),
        'message': messageToSend,
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

              // 施設名（必須 or 任意：種別による）
              if (_isFacilityNameRequired)
                _RequiredLabel(label: '施設名')
              else
                const Text(
                  '関連する施設・機能（任意）',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _facilityNameCtrl,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(_facilityNameHint),
                validator: (v) => _isFacilityNameRequired &&
                        (v == null || v.trim().isEmpty)
                    ? '施設名を入力してください'
                    : null,
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
              // UX-60: バグ報告の場合、端末情報が自動添付されることをユーザーに伝える。
              if (widget.type == InquiryType.bugReport) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'OS・アプリバージョンが自動で添付されます',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
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
