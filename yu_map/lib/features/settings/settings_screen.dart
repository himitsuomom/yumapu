import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/subscription_provider.dart';
import 'package:yu_map/features/auth/screens/login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // Premium section — only shown when RevenueCat is configured.
          if (AppConfig.isRevenueCatConfigured) ...[
            _sectionHeader(context, 'プレミアム'),
            _PremiumTile(),
            const Divider(),
          ],

          // Account section
          _sectionHeader(context, 'アカウント'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('ログアウト'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('ログアウト'),
                  content: const Text('ログアウトしますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('ログアウト'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              }
            },
          ),
          const Divider(),

          // App info section
          _sectionHeader(context, 'アプリについて'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('バージョン'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {
              // TODO: Replace with actual privacy policy URL
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('プライバシーポリシーURLは準備中です')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('利用規約'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {
              // TODO: Replace with actual terms URL
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('利用規約URLは準備中です')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('お問い合わせ'),
            onTap: () {
              // TODO: Replace with actual support email
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('お問い合わせ先は準備中です')),
              );
            },
          ),
          const Divider(),

          // Legal
          _sectionHeader(context, 'ライセンス'),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('オープンソースライセンス'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: '1.0.0',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// Premium subscription tile — shows current status and upgrade option.
class _PremiumTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premiumAsync = ref.watch(isPremiumProvider);

    return premiumAsync.when(
      loading: () => const ListTile(
        leading: Icon(Icons.workspace_premium),
        title: Text('プレミアム'),
        subtitle: Text('読み込み中...'),
      ),
      error: (_, __) => ListTile(
        leading: const Icon(Icons.workspace_premium),
        title: const Text('プレミアム'),
        subtitle: const Text('広告なし・全機能利用可能'),
        trailing: ElevatedButton(
          onPressed: () async {
            await ref.read(subscriptionServiceProvider).purchasePremium();
            ref.invalidate(isPremiumProvider);
          },
          child: const Text('アップグレード'),
        ),
      ),
      data: (isPremium) {
        if (isPremium) {
          return const ListTile(
            leading: Icon(Icons.workspace_premium, color: Colors.amber),
            title: Text('プレミアム会員'),
            subtitle: Text('ご利用ありがとうございます'),
          );
        }
        return ListTile(
          leading: const Icon(Icons.workspace_premium),
          title: const Text('プレミアム'),
          subtitle: const Text('広告なし・全機能利用可能'),
          trailing: ElevatedButton(
            onPressed: () async {
              await ref.read(subscriptionServiceProvider).purchasePremium();
              ref.invalidate(isPremiumProvider);
            },
            child: const Text('アップグレード'),
          ),
        );
      },
    );
  }
}
