// lib/features/facility/screens/owner_facility_edit_screen.dart
//
// 施設情報編集画面（オーナー専用）
//
// 承認済みオーナーが自分の施設の情報を編集できる画面。
// Supabase の facilities テーブルを直接 UPDATE する。
// RLS ポリシーにより、承認済みオーナー以外の UPDATE は DB 側で拒否される。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// 施設情報編集画面
///
/// [facility] : 編集対象の施設（現在の値をフォームの初期値に使用）
class OwnerFacilityEditScreen extends ConsumerStatefulWidget {
  const OwnerFacilityEditScreen({super.key, required this.facility});

  final Facility facility;

  @override
  ConsumerState<OwnerFacilityEditScreen> createState() =>
      _OwnerFacilityEditScreenState();
}

class _OwnerFacilityEditScreenState
    extends ConsumerState<OwnerFacilityEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // フォームコントローラー（各入力欄に現在の値を初期セット）
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _businessHoursCtrl;
  late final TextEditingController _priceInfoCtrl;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final f = widget.facility;

    _nameCtrl = TextEditingController(text: f.name);
    _addressCtrl = TextEditingController(text: f.address ?? '');
    _phoneCtrl = TextEditingController(text: f.phone ?? '');
    _websiteCtrl = TextEditingController(text: f.website ?? '');

    // business_hours の description キーがあれば初期値に使う
    final hoursDescription =
        f.businessHours['description'] as String? ?? f.openingHours ?? '';
    _businessHoursCtrl = TextEditingController(text: hoursDescription);

    // price_info の description キーがあれば初期値に使う
    final priceDescription = f.priceInfo['description'] as String? ?? '';
    _priceInfoCtrl = TextEditingController(text: priceDescription);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _businessHoursCtrl.dispose();
    _priceInfoCtrl.dispose();
    super.dispose();
  }

  // ── フォーム送信 ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);

    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) throw Exception('サーバーに接続できません');

      // 変更内容を Map にまとめる
      // business_hours / price_info は JSONB なので
      // {description: "テキスト"} の形式で保存する
      final Map<String, dynamic> updates = {
        'name': _nameCtrl.text.trim(),
      };

      if (_addressCtrl.text.trim().isNotEmpty) {
        updates['address'] = _addressCtrl.text.trim();
      }

      if (_phoneCtrl.text.trim().isNotEmpty) {
        updates['phone'] = _phoneCtrl.text.trim();
      } else {
        updates['phone'] = null;
      }

      if (_websiteCtrl.text.trim().isNotEmpty) {
        updates['website'] = _websiteCtrl.text.trim();
      } else {
        updates['website'] = null;
      }

      if (_businessHoursCtrl.text.trim().isNotEmpty) {
        updates['business_hours'] = {
          'description': _businessHoursCtrl.text.trim(),
        };
      }

      if (_priceInfoCtrl.text.trim().isNotEmpty) {
        updates['price_info'] = {
          'description': _priceInfoCtrl.text.trim(),
        };
      }

      await client
          .from('facilities')
          .update(updates)
          .eq('id', widget.facility.id);

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('施設情報を更新しました'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // 前の画面に戻る（施設詳細画面はリフレッシュが必要）
      navigator.pop(true); // true = 更新があったことを呼び出し元に伝える
    } on Exception catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('更新に失敗しました: $e'),
          backgroundColor: Colors.red,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('施設情報を編集'),
        actions: [
          // 保存ボタンをAppBarにも配置（スクロールしなくても押せる）
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 注意バナー ──────────────────────────────────────────────
              _InfoBanner(
                text: '「${widget.facility.name}」の情報を編集します。\n'
                    '正確な情報を入力してください。変更はすぐに反映されます。',
              ),
              const SizedBox(height: 24),

              // ── 施設名 ─────────────────────────────────────────────────
              const _FieldLabel(label: '施設名', required: true),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '例: 新宿温泉',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return '施設名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── 住所 ───────────────────────────────────────────────────
              const _FieldLabel(label: '住所', required: false),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '例: 東京都新宿区西新宿1-1-1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // ── 電話番号 ───────────────────────────────────────────────
              const _FieldLabel(label: '電話番号', required: false),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '例: 03-1234-5678',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // ── ウェブサイト ───────────────────────────────────────────
              const _FieldLabel(label: 'ウェブサイト URL', required: false),
              const SizedBox(height: 6),
              TextFormField(
                controller: _websiteCtrl,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '例: https://example.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // ── 営業時間・定休日 ───────────────────────────────────────
              const _FieldLabel(label: '営業時間・定休日', required: false),
              const SizedBox(height: 4),
              Text(
                '自由形式で入力できます',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _businessHoursCtrl,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: '例: 月〜金 10:00〜22:00\n土日祝 9:00〜23:00\n毎週水曜定休',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // ── 料金情報 ───────────────────────────────────────────────
              const _FieldLabel(label: '料金情報', required: false),
              const SizedBox(height: 4),
              Text(
                '大人・子供・会員など区分がある場合はまとめて記入できます',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _priceInfoCtrl,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: '例: 大人 500円、子供（小学生以下）200円\n回数券あり、タオル別途100円',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),

              // ── 保存ボタン ─────────────────────────────────────────────
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
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSubmitting ? '保存中...' : '変更を保存する'),
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
            Icons.edit_outlined,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.required});
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    if (required) {
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
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
