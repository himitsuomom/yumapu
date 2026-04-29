import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/theme/app_theme.dart';
import 'package:yu_map/core/widgets/offline_banner.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/features/auth/screens/login_screen.dart';
import 'package:yu_map/features/auth/screens/onboarding_screen.dart';
import 'package:yu_map/features/auth/screens/register_screen.dart';
import 'package:yu_map/features/feed/screens/feed_screen.dart';
import 'package:yu_map/features/facility/screens/facility_detail_screen.dart';
import 'package:yu_map/features/admin/screens/admin_owner_requests_screen.dart';
import 'package:yu_map/features/facility/screens/facility_report_screen.dart';
import 'package:yu_map/features/facility/screens/owner_facility_edit_screen.dart';
import 'package:yu_map/features/facility/screens/owner_registration_screen.dart';
import 'package:yu_map/features/home/home_shell.dart';
import 'package:yu_map/features/profile/screens/badge_screen.dart';
import 'package:yu_map/features/profile/screens/edit_profile_screen.dart';
import 'package:yu_map/features/profile/screens/profile_screen.dart';
import 'package:yu_map/features/favorites/favorites_screen.dart';
import 'package:yu_map/features/profile/screens/plan_detail_screen.dart';
import 'package:yu_map/features/profile/screens/plans_screen.dart';
import 'package:yu_map/features/profile/screens/visit_history_screen.dart';
import 'package:yu_map/models/onsen_plan.dart';
import 'package:yu_map/features/ranking/screens/ranking_screen.dart';
import 'package:yu_map/features/inquiry/inquiry_screen.dart';
import 'package:yu_map/features/settings/legal_screen.dart';
import 'package:yu_map/features/settings/settings_screen.dart';
import 'package:yu_map/core/navigation/app_navigator.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/connectivity_provider.dart';
import 'package:yu_map/providers/theme_provider.dart';
import 'package:yu_map/screens/subscription_screen.dart';
import 'package:yu_map/services/notification_service.dart';

class YuMapApp extends ConsumerWidget {
  const YuMapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    // D-2対応: ユーザーが選択したテーマモードを使用する（デフォルトはシステム追従）
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode, // D-2対応: themeModeProvider から取得
      debugShowCheckedModeBanner: false,
      // 通知サービスからContextなしで画面遷移するためのグローバルキー。
      // notification_service.dart の _handleNavigation がこのキー経由でナビゲートする。
      navigatorKey: appNavigatorKey,
      // Named routes for screens pushed via Navigator.pushNamed.
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/subscription': (_) => const SubscriptionScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/ranking': (_) => const RankingScreen(),
        '/badges': (_) => const BadgeScreen(),
        '/visit-history': (_) => const VisitHistoryScreen(),
        '/plans': (_) => const PlansScreen(),
        '/favorites': (_) => const FavoritesScreen(),
        // G-1対応: フィードはランキングタブ昇格に伴いルート直接アクセスに変更
        '/feed': (_) => const FeedScreen(),
        '/privacy-policy': (_) => const PrivacyPolicyScreen(),
        '/terms': (_) => const TermsScreen(),
      },
      // Routes that carry typed arguments use onGenerateRoute.
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/inquiry':
            final args = settings.arguments as Map<String, dynamic>?;
            final type = (args?['type'] as InquiryType?) ?? InquiryType.addFacility;
            final facilityName = args?['facilityName'] as String?;
            return MaterialPageRoute<void>(
              builder: (_) => InquiryScreen(
                type: type,
                initialFacilityName: facilityName,
              ),
            );
          case '/facility':
            final facilityId = settings.arguments as String;
            return MaterialPageRoute<void>(
              builder: (_) => FacilityDetailScreen(facilityId: facilityId),
            );
          case '/facility-report':
            final reportArgs = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute<void>(
              builder: (_) => FacilityReportScreen(
                facilityId: reportArgs['facilityId'] as String,
                facilityName: reportArgs['facilityName'] as String,
              ),
            );
          case '/owner-registration':
            final ownerArgs = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute<void>(
              builder: (_) => OwnerRegistrationScreen(
                facilityId: ownerArgs['facilityId'] as String,
                facilityName: ownerArgs['facilityName'] as String,
              ),
            );
          case '/admin/owner-requests':
            return MaterialPageRoute<void>(
              builder: (_) => const AdminOwnerRequestsScreen(),
            );
          case '/owner/facility-edit':
            final facility = settings.arguments as Facility;
            return MaterialPageRoute<bool>(
              builder: (_) => OwnerFacilityEditScreen(facility: facility),
            );
          // E-1修正: /review ルートは削除済み（レビュー投稿は ReviewBottomSheet 経由）
          // write_review_screen.dart は手動削除待ち（git rm で対応）
          case '/plan-detail':
            final plan = settings.arguments as OnsenPlan;
            return MaterialPageRoute<void>(
              builder: (_) => PlanDetailScreen(plan: plan),
            );
          case '/edit-profile':
            final user = settings.arguments as app.User;
            return MaterialPageRoute<void>(
              builder: (_) => EditProfileScreen(user: user),
            );
          default:
            return null;
        }
      },
      // Overlays OfflineBanner above all routes when the device is offline.
      builder: (context, child) {
        return Column(
          children: [
            if (!isOnline) const OfflineBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
      home: const _AuthGate(),
    );
  }
}

/// Watches [isSignedInProvider] and shows either [HomeShell] or [LoginScreen].
///
/// 初回起動時のみ [OnboardingScreen] を表示する（UX-V7-5対応）。
/// flutter_secure_storage の 'onboarding_completed' フラグで判定する。
///
/// When the auth state changes (login / logout) any screens pushed on top of
/// this gate are popped so the user always sees the correct root view.
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  // null = 確認中, true = 完了済み, false = 未完了（初回起動）
  bool? _onboardingCompleted;

  static const _storage = FlutterSecureStorage();
  static const _guestModeKey = 'guest_mode';

  // Deep Linking: app_links によるURL受信サブスクリプション
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initStorage();
    _initDeepLinks();
    // cold start（アプリ終了状態からの通知タップ）による保留ナビゲーションを実行する。
    // この時点では Navigator はまだ構築済みのため、postFrameCallback 経由で安全に遷移できる。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.drainPendingNavigation();
    });
  }

  /// Deep Link（カスタムURLスキーム）の受信を開始する。
  ///
  /// 対応URL形式:
  ///   yumap://facility/{facilityId}
  ///   https://yumap.app/facility/{facilityId}  ← Universal Links / App Links（将来対応）
  ///
  /// アプリが既に起動している場合: uriLinkStream でストリーム受信
  /// アプリが起動していなかった場合: getInitialLink() で起動時URIを取得
  Future<void> _initDeepLinks() async {
    // アプリ起動直後のリンク（cold start）を処理する
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {
      // 取得失敗は無視（通常起動と同じ動作をする）
    }

    // アプリが前面にある状態でリンクを受信する（warm start）
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (_) {}, // エラーは無視
    );
  }

  /// 受信したURIを解析して、対応する画面に遷移する。
  ///
  /// 例: yumap://facility/abc-123 → FacilityDetailScreen(facilityId: 'abc-123')
  void _handleDeepLink(Uri uri) {
    // scheme: 'yumap' または host が 'yumap.app'
    final isCustomScheme = uri.scheme == AppConstants.deepLinkScheme;
    final isUniversalLink =
        uri.host == 'yumap.app' || uri.host == 'www.yumap.app';

    if (!isCustomScheme && !isUniversalLink) return;

    final segments = uri.pathSegments;
    // yumap://facility/{id}  → pathSegments = ['facility', '{id}']
    // https://yumap.app/facility/{id} → pathSegments = ['facility', '{id}']
    if (segments.length >= 2 && segments[0] == 'facility') {
      final facilityId = segments[1];
      if (facilityId.isNotEmpty && mounted) {
        // Navigator がスタックに積まれていることを前提に pushNamed する。
        // まだ HomeShell が表示される前（_onboardingCompleted == null）の場合は
        // 少し待ってから再実行する。
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushNamed('/facility', arguments: facilityId);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  /// オンボーディング完了フラグとゲストモードフラグを並行して読み込む。
  ///
  /// Bug-V9-4対応: ゲストモードを flutter_secure_storage で永続化する。
  /// アプリ再起動後も「ゲストとして閲覧」を選んだ状態を維持できる。
  Future<void> _initStorage() async {
    // 2つのストレージ読み込みを並行実行して待ち時間を最小化する
    final results = await Future.wait<bool>([
      isOnboardingCompleted(),
      _storage.read(key: _guestModeKey).then((v) => v == 'true'),
    ]);
    if (!mounted) return;

    final onboardingDone = results[0];
    final guestMode = results[1];

    // ゲストモードが保存されていればプロバイダーに反映する
    if (guestMode) {
      ref.read(guestModeProvider.notifier).state = true;
    }
    setState(() => _onboardingCompleted = onboardingDone);
  }

  @override
  Widget build(BuildContext context) {
    // Bug-V9-4対応: ゲストモードの変化をストレージに即時反映する。
    // これにより次回起動時も同じモードで起動できる。
    ref.listen<bool>(guestModeProvider, (_, value) {
      if (value) {
        _storage.write(key: _guestModeKey, value: 'true');
      } else {
        _storage.delete(key: _guestModeKey);
      }
    });

    ref.listen<bool>(isSignedInProvider, (previous, next) {
      if (previous != null && previous != next) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        // Bug-V6-2修正: ゲストモードからログインした場合にゲストフラグをクリアする。
        // これにより isGuestMode が stale に残る状態不整合を防ぐ。
        if (next) {
          ref.read(guestModeProvider.notifier).state = false;
        }
      }
    });

    // フラグ確認中はスプラッシュ代わりに空白を表示
    if (_onboardingCompleted == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 初回起動 → オンボーディング画面へ
    if (_onboardingCompleted == false) {
      return const OnboardingScreen();
    }

    final isSignedIn = ref.watch(isSignedInProvider);
    final isGuestMode = ref.watch(guestModeProvider);

    // ログイン済み、またはゲストモードならホーム画面を表示
    return (isSignedIn || isGuestMode) ? const HomeShell() : const LoginScreen();
  }
}
