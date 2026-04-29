import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/app.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/firebase_options.dart';
import 'package:yu_map/services/analytics_service.dart';
import 'package:yu_map/services/notification_service.dart';
import 'package:yu_map/services/subscription_service.dart';

Future<void> main() async {
  // A-1対応: スプラッシュ画面を初期化が完了するまで保持する。
  // ensureInitialized() の前に呼ぶ必要がある。
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 0. 日付フォーマット（intl）の日本語ロケールデータを初期化
  //    DateFormat('yyyy/MM/dd', 'ja') などを使う前に必ず呼ぶ必要がある。
  await initializeDateFormatting('ja');

  // 1. Firebase — must be initialized before any Firebase service (Analytics等).
  //    GoogleService-Info.plist / google-services.json が存在すれば初期化する。
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase の設定が不完全な場合はスキップして続行する。
    debugPrint('Firebase init skipped: $e');
  }

  // 2. Supabase — skipped when credentials are not provided via --dart-define.
  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  // 3. AdMob — skipped when ad unit IDs are not provided.
  if (AppConfig.isAdMobConfigured) {
    await MobileAds.instance.initialize();
  }

  // 4. SubscriptionService — always called; becomes a no-op when RevenueCat
  //    keys are absent.
  await SubscriptionService().initialize();

  // 5. AnalyticsService — no-op when Firebase is not initialized.
  AnalyticsService.instance.initialise();

  // 6. NotificationService — FCM 初期化と通知ハンドラー設定。
  //    Firebase が初期化済みの場合のみ有効。ログイン後に registerToken() を呼ぶ。
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('NotificationService init skipped: $e');
  }

  // A-1対応: 全ての初期化が完了したのでスプラッシュ画面を解除する。
  // これを呼ぶまでネイティブのスプラッシュ（ロゴ入り）が表示され続ける。
  FlutterNativeSplash.remove();

  // 6. Sentry — wraps runApp when DSN is provided so all errors are captured.
  if (AppConfig.isSentryConfigured) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.tracesSampleRate = 0.5;
      },
      appRunner: () => runApp(const ProviderScope(child: YuMapApp())),
    );
  } else {
    runApp(const ProviderScope(child: YuMapApp()));
  }
}
