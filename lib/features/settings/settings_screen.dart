import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/features/inquiry/inquiry_screen.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/subscription_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final subscriptionState = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // ── Premium section (hidden when RevenueCat is not configured) ─
          if (AppConfig.isRevenueCatConfigured) ...[
            const _SectionHeader(label: 'プレミアム'),
            if (subscriptionState.isPremium)
              const ListTile(
                leading: Icon(Icons.workspace_premium, color: Color(0xFFDAA520)),
                title: Text('プレミアム会員'),
                subtitle: Text('有効'),
              )
            else
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('プレミアムにアップグレード'),
                subtitle: const Text('広告非表示・すべての機能が使えます'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed('/subscription'),
              ),
            const Divider(height: 1),
          ],

          // ── Account section ────────────────────────────────────────────
          const _SectionHeader(label: 'アカウント'),
          if (isSignedIn) ...[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('プロフィール'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed('/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('ログアウト', style: TextStyle(color: Colors.red)),
              onTap: () => _showLogoutDialog(context, ref),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('ログイン'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed('/login'),
            ),
          ],
          const Divider(height: 1),

          // ── お問い合わせ section ────────────────────────────────────────
          const _SectionHeader(label: 'フィードバック'),
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: const Text('施設の追加を申請する'),
            subtitle: const Text('地図にない温泉・銭湯・サウナを教えてください'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(
              '/inquiry',
              arguments: {
                'type': InquiryType.addFacility,
              },
            ),
          ),
          const Divider(height: 1),

          // ── App info section ───────────────────────────────────────────
          const _SectionHeader(label: 'アプリ情報'),
          const ListTile(
            leading: Icon(Icons.hot_tub_outlined),
            title: Text(AppConstants.appName),
            trailing: Text(
              AppConstants.appNameEn,
              style: TextStyle(color: Color(0xFF757575)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/privacy-policy'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('利用規約'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/terms'),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(authNotifierProvider.notifier).signOut();
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
