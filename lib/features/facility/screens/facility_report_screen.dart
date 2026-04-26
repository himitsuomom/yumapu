// lib/features/facility/screens/facility_report_screen.dart
//
// 施設情報報告画面
//
// ユーザーが「この施設の情報が違う」と気づいたときに
// カテゴリを選択して報告できるフォーム画面。
// 送信先: Supabase の facility_reports テーブル
// ログイン不要（ゲストユーザーでも送信可能）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// 報告種別の定義
enum FacilityReportType {
  hoursWrong,   // 営業時間・定休日が違う
  closed,       // 閉業・閉鎖している
  addressWrong, // 住所が違う
  phoneWrong,   // 電話番号が違う
  priceWrong,   // 料金が違う
  other,        // その他
}

extension FacilityReportTypeEx on FacilityReportType {
  String get label {
    switch (this) {
      case FacilityReportType.hoursWrong:
        return '営業時間・定休日が違う';
      case FacilityReportType.closed:
        return '閉業・閉鎖している';
      case FacilityReportType.addressWrong:
        return '住所が違う';
      case FacilityReportType.phoneWrong:
        return '電話番号が違う';
      case FacilityReportType.priceWrong:
        return '料金が違う';
      case FacilityReportType.other:
        return 'その他';
    }
  }

  IconData get icon {
    switch (this) {
      case FacilityReportType.hoursWrong:
        return Icons.schedule_outlined;
      case FacilityReportType.closed:
        return Icons.cancel_outlined;
      case FacilityReportType.addressWrong:
        return Icons.location_off_outlined;
      case FacilityReportType.phoneWrong:
        return Icons.phone_disabled_outlined;
      case FacilityReportType.priceWrong:
        return Icons.money_off_outlined;
      case FacilityReportType.other:
        return Icons.edit_note_outlined;
    }
  }

  /// DB の report_type カラムに保存する文字列
  String get dbValue {
    switch (this) {
      case FacilityReportType.hoursWrong:
        return 'hours_wrong';
      case FacilityReportType.closed:
        return 'closed';
      case FacilityReportType.addressWrong:
        return 'address_wrong';
      case FacilityReportType.phoneWrong:
        return 'phone_wrong';
      case FacilityReportType.priceWrong:
        return 'price_wrong';
      case FacilityReportType.other:
        return 'other';
    }
  }
}

/// 施設情報報告画面
///
/// [facilityId] : 報告対象の施設 ID（必須）
/// [facilityName] : 施設名（AppBar と確認メッセージに使用）
class FacilityReportScreen extends ConsumerStatefulWidget {
  const FacilityReportScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  final String facilityId;
  final String facilityName;

  @override
  ConsumerState<FacilityReportScreen> createState() =>
      _FacilityReportScreenState();
}

class _FacilityReportScreenState extends ConsumerState<FacilityReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  FacilityReportType? _selectedType;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  // ── フォーム送信 ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // 報告種別が未選択ならバリデーションエラー
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('報告内容を選択してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    // 非同期処理前に context 依存オブジェクトを確保（非同期ギャップ後の使用を防ぐ）
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);

    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) throw Exception('サーバーに接続できません');

      // ログイン済みなら user_id も保存（自分の報告履歴を確認できるようにするため）
      final userId = ref.read(sessionProvider)?.user.id;

      await client.from('facility_issue_reports').insert({
        'facility_id': widget.facilityId,
        'report_type': _selectedType!.dbValue,
        if (_detailCtrl.text.trim().isNotEmpty)
          'detail': _detailCtrl.text.trim(),
        if (_contactCtrl.text.trim().isNotEmpty)
          'contact': _contactCtrl.text.trim(),
        if (userId != null) 'user_id': userId,
      });

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('報告を送信しました。ご協力ありがとうございます！'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('送信に失敗しました。通信環境を確認して再度お試しください。'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
      appBar: AppBar(title: const Text('情報を報告する')),
      body: SingleChildScrollView(
        // キーボードが出たとき、下余白をキーボードの高さ分だけ増やす。
        // これにより送信ボタンまでスクロールできるようになる。
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
                    '「${widget.facilityName}」の情報で、実際と違う点を教えてください。\n'
                    '運営チームが確認して修正します。',
              ),
              const SizedBox(height: 24),

              // ── 報告種別の選択 ──────────────────────────────────────────
              const _SectionLabel(label: '報告内容 *'),
              const SizedBox(height: 8),
              ..._buildReportTypeItems(),
              const SizedBox(height: 24),

              // ── 詳細テキスト（任意）────────────────────────────────────
              const _SectionLabel(label: '詳細（任意）'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _detailCtrl,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: '具体的な内容があればご記入ください\n'
                      '例: 月曜日が定休日になりました\n'
                      '例: 2026年3月に閉店しました',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // ── 連絡先（任意）──────────────────────────────────────────
              const _SectionLabel(label: '連絡先（任意）'),
              const SizedBox(height: 4),
              Text(
                '確認が必要な場合にご連絡させていただく場合があります',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _contactCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'メールアドレスなど（省略可）',
                  border: OutlineInputBorder(),
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
                      : const Icon(Icons.send_outlined),
                  label: Text(_isSubmitting ? '送信中...' : '報告を送信する'),
                ),
              ),
              const SizedBox(height: 16),

              // ── 注記 ────────────────────────────────────────────────────
              Text(
                'この報告は施設情報の改善にのみ使用します。\n'
                '返信をご希望の場合は連絡先をご記入ください。',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 報告種別の選択肢リスト ──────────────────────────────────────────────────

  List<Widget> _buildReportTypeItems() {
    return FacilityReportType.values.map((type) {
      final isSelected = _selectedType == type;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  type.icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ── 共通ウィジェット ────────────────────────────────────────────────────────────

/// 説明バナー（青背景のインフォメーションボックス）
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
            Icons.info_outline,
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

/// セクション見出しラベル
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

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
