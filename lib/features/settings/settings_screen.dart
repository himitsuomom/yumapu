import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/features/inquiry/inquiry_screen.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/subscription_provider.dart';
import 'package:yu_map/providers/theme_provider.dart';
import 'package:yu_map/services/notification_service.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final subscriptionState = ref.watch(subscriptionProvider);
    // 管理者チェック（非同期。取得中はfalseとして扱う）
    final isAdminAsync = ref.watch(isAdminProvider);
    final isAdmin = isAdminAsync.valueOrNull ?? false;
    // ログインユーザーのメールアドレス（プロフィール画面から移動。設定画面のみに表示）
    final userAsync = ref.watch(currentUserProfileProvider);

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
            // ログイン中ユーザーのメールアドレスを表示（プライバシー保護のため設定画面のみ）
            if (userAsync.valueOrNull?.email != null)
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('メールアドレス'),
                subtitle: Text(userAsync.value!.email!),
                dense: true,
              ),
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

          // ── 危険な操作セクション（アカウントを持つユーザーのみ表示）────────────
          // Tier1 必須: App Store / Google Play 審査要件
          // アカウントを持つユーザーはアプリ内から削除できなければならない
          // ログアウトボタンと視覚的に分離して誤タップを防ぐ
          if (isSignedIn) ...[
            const _SectionHeader(label: '危険な操作'),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'アカウントを削除',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('すべてのデータが完全に削除されます'),
              onTap: () => _showDeleteAccountDialog(context, ref),
            ),
            const Divider(height: 1),
          ],

          // ── 管理者セクション（is_admin = true のユーザーのみ表示）─────────
          if (isAdmin) ...[
            const _SectionHeader(label: '管理者メニュー'),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined,
                  color: Colors.deepOrange),
              title: const Text(
                'オーナー申請管理',
                style: TextStyle(color: Colors.deepOrange),
              ),
              subtitle: const Text('申請の承認・却下を行います'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.of(context).pushNamed('/admin/owner-requests'),
            ),
            const Divider(height: 1),
          ],

          // ── 通知 section ────────────────────────────────────────────────
          // UX-62: 設定画面に通知オン/オフUIを追加する
          // UX-66: 通知を一度断ったユーザーへの再許可導線を追加する
          if (isSignedIn) ...[
            const _SectionHeader(label: '通知'),
            const _NotificationSettingsSection(),
            const Divider(height: 1),
          ],

          // ── テーマ section ─────────────────────────────────────────────
          // D-2対応: ユーザーがダーク/ライト/システムを選択できる
          // UX-V22対応: 「表示」→「外観」に変更してiOS/Android標準UIに合わせる
          const _SectionHeader(label: '外観'),
          const _ThemeModeSelector(),
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
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('バグを報告する'),
            subtitle: const Text('不具合・動作がおかしい場合はこちら'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(
              '/inquiry',
              arguments: {
                'type': InquiryType.bugReport,
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('お問い合わせ'),
            subtitle: const Text('機能要望・ご意見など'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(
              '/inquiry',
              arguments: {
                'type': InquiryType.general,
              },
            ),
          ),
          // D-4対応: ユーザーが App Store / Google Play でレビューを投稿できるリンク
          // AppConstants にストアURL が設定されている場合のみ表示する
          if (AppConstants.appStoreUrl.isNotEmpty ||
              AppConstants.googlePlayUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('アプリを評価する'),
              subtitle: const Text('App Store / Google Play でレビューをお願いします'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                // iOS は App Store、Android は Google Play の URL を開く
                // どちらも設定されている場合は App Store を優先する
                final urlStr = AppConstants.appStoreUrl.isNotEmpty
                    ? AppConstants.appStoreUrl
                    : AppConstants.googlePlayUrl;
                final uri = Uri.tryParse(urlStr);
                if (uri == null) return;
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('ストアを開けませんでした。')),
                  );
                }
              },
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
          // Imp-1修正: バージョン番号を表示（サポート時に「バージョンを教えて」が不要に）
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('バージョン'),
            trailing: Text(
              AppConstants.appVersion,
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

  /// アカウント削除の2段階確認ダイアログを表示する。
  ///
  /// 誤削除を防ぐため、最初の確認 → 最終確認（「削除する」と入力） の
  /// 2段階で確認する。
  Future<void> _showDeleteAccountDialog(
      BuildContext context, WidgetRef ref) async {
    // ── ステップ1: 最初の確認 ──────────────────────────────────────────
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('アカウントを削除しますか？'),
        content: const Text(
          '以下のすべてのデータが完全に削除されます。\n\n'
          '・チェックイン履歴\n'
          '・クチコミ・評価\n'
          '・お気に入りリスト\n'
          '・バッジ・プラン\n'
          '・その他すべての投稿\n\n'
          'この操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('次へ'),
          ),
        ],
      ),
    );
    if (step1 != true || !context.mounted) return;

    // ── ステップ2: 最終確認（誤操作防止） ──────────────────────────────
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('本当に削除しますか？'),
        content: const Text('アカウントとすべてのデータを完全に削除します。\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('完全に削除する'),
          ),
        ],
      ),
    );
    if (step2 != true || !context.mounted) return;

    // ── 削除実行 ──────────────────────────────────────────────────────
    await ref.read(authNotifierProvider.notifier).deleteAccount();

    if (!context.mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('削除に失敗しました。時間をおいて再試行してください。'),
          backgroundColor: Colors.red,
        ),
      );
    }
    // 削除成功時は authNotifier.deleteAccount() 内で signOut() が呼ばれ、
    // _AuthGate が自動的にログイン画面へ遷移する。
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

// ── 通知設定セクション ────────────────────────────────────────────────────────
//
// UX-62: 通知のオン/オフをアプリ内から切り替えられるUIを追加。
// UX-66: 通知を一度断ったユーザーが再許可するための「アプリ設定を開く」導線を追加。
//
// 実装方針:
// - 通知の有効状態は permission_handler パッケージで取得する代わりに
//   NotificationService.isEnabled() を使う（iOS/Android 共通）。
// - 許可状態が 'denied' の場合はトグルで再許可できないため、
//   OS のアプリ設定画面に誘導するボタンを表示する。

class _NotificationSettingsSection extends ConsumerStatefulWidget {
  const _NotificationSettingsSection();

  @override
  ConsumerState<_NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<_NotificationSettingsSection>
    with WidgetsBindingObserver {
  /// null = 読み込み中
  bool? _isEnabled;
  /// OSレベルで拒否されているか（= アプリ内トグルでは変更不可）
  bool _isDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// アプリがフォアグラウンドに戻ったとき、OS設定変更を反映する（UX-66）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    final svc = NotificationService.instance;
    final enabled = await svc.isNotificationEnabled();
    final denied = await svc.isNotificationDenied();
    if (!mounted) return;
    setState(() {
      _isEnabled = enabled;
      _isDenied = denied;
    });
  }

  Future<void> _toggle(bool value) async {
    if (_isDenied) {
      // OS設定画面に誘導（UX-66）
      await _openAppSettings();
      return;
    }
    final svc = NotificationService.instance;
    if (value) {
      await svc.requestPermissionLazily();
    } else {
      // 通知を無効化する（iOS は直接無効化できないためOS設定に誘導）
      await _openAppSettings();
      return;
    }
    await _loadStatus();
  }

  Future<void> _openAppSettings() async {
    // iOS/Android のアプリ通知設定画面を開く
    // url_launcher で app-settings:// スキームを使う
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定アプリを開けませんでした')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 読み込み中
    if (_isEnabled == null) {
      return const ListTile(
        leading: Icon(Icons.notifications_outlined),
        title: Text('プッシュ通知'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // OS レベルで拒否済み → トグル無効 + 設定誘導ボタン
    if (_isDenied) {
      return Column(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined,
                color: Color(0xFF9E9E9E)),
            title: const Text('プッシュ通知'),
            subtitle: const Text('通知が拒否されています'),
            trailing: Switch(
              value: false,
              onChanged: (_) => _openAppSettings(),
            ),
          ),
          // UX-66: 再許可の導線
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: Color(0xFF757575)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'アプリの設定から通知を許可できます',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(140),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openAppSettings,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('設定を開く',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 通常のトグル
    return SwitchListTile(
      secondary: Icon(
        _isEnabled!
            ? Icons.notifications_active_outlined
            : Icons.notifications_outlined,
      ),
      title: const Text('プッシュ通知'),
      subtitle: Text(
        _isEnabled! ? 'チェックイン・バッジ・フォロー通知が届きます' : 'オフになっています',
      ),
      value: _isEnabled!,
      onChanged: _toggle,
    );
  }
}

// ── テーマ選択ウィジェット ─────────────────────────────────────────────────────

/// テーマモードを選択するセグメントコントロール。
///
/// D-2対応: 「システム」「ライト」「ダーク」の3択をインラインで表示する。
/// 変更は themeModeProvider 経由で即座にアプリ全体に反映される。
class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.brightness_medium_outlined, color: Color(0xFF757575)),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'テーマ',
              style: TextStyle(fontSize: 16),
            ),
          ),
          SegmentedButton<ThemeMode>(
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('自動', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.brightness_auto, size: 16),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('ライト', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.light_mode, size: 16),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('ダーク', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.dark_mode, size: 16),
              ),
            ],
            selected: {currentMode},
            onSelectionChanged: (selected) {
              if (selected.isNotEmpty) {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(selected.first);
              }
            },
          ),
        ],
      ),
    );
  }
}
