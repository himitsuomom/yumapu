// lib/core/widgets/guest_restriction_dialog.dart
//
// ゲストモードで制限機能にアクセスしたときに表示するモーダル。
//
// 使い方:
//   final goLogin = await GuestRestrictionDialog.show(context);
//   if (goLogin == true && context.mounted) {
//     Navigator.of(context).pushNamed('/login');
//   }
//
// 戻り値: true = ログイン画面に遷移する / false/null = 閉じるのみ

import 'package:flutter/material.dart';

/// ゲストモードでログインが必要な機能をタップしたとき表示するモーダルダイアログ。
///
/// [featureName] に機能名（例: 'お気に入り'）を渡すと、
/// 「○○を使うにはログインが必要です」というメッセージになる。
class GuestRestrictionDialog extends StatelessWidget {
  const GuestRestrictionDialog({
    super.key,
    this.featureName,
  });

  /// 制限された機能名（例: 'お気に入り', 'チェックイン'）
  /// null の場合は汎用メッセージを表示する。
  final String? featureName;

  /// ダイアログを表示する静的ヘルパー。
  ///
  /// 戻り値: true ならログイン画面に遷移する意図、false/null なら閉じるのみ。
  static Future<bool?> show(
    BuildContext context, {
    String? featureName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => GuestRestrictionDialog(featureName: featureName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title =
        featureName != null ? '$featureName はログインが必要です' : 'ログインが必要です';

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Column(
        children: [
          // 鍵アイコン（アクセント色）
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_open_outlined,
              size: 36,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '湯マップに登録（無料）すると、以下の機能が使えます。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // 機能リスト
          _FeatureRow(
            icon: Icons.favorite,
            color: Colors.redAccent,
            label: 'お気に入り施設を保存',
          ),
          _FeatureRow(
            icon: Icons.where_to_vote,
            color: Colors.teal,
            label: 'チェックインでバッジを獲得',
          ),
          _FeatureRow(
            icon: Icons.rate_review,
            color: Colors.amber[700]!,
            label: 'クチコミを投稿・編集',
          ),
          _FeatureRow(
            icon: Icons.leaderboard,
            color: Colors.indigo,
            label: 'ランキングに参加',
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        // ログイン/登録ボタン（メインアクション）
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('ログイン / 新規登録'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
        const SizedBox(height: 8),
        // ゲストのまま続ける
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ゲストのまま続ける'),
          ),
        ),
      ],
    );
  }
}

// ── 機能紹介の行コンポーネント ─────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
