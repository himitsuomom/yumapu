import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/app.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/services/analytics_service.dart';
import 'package:yu_map/services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Supabase — skipped when credentials are not provided via --dart-define.
  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  // 2. AdMob — skipped when ad unit IDs are not provided.
  if (AppConfig.isAdMobConfigured) {
    await MobileAds.instance.initialize();
  }

  // 3. SubscriptionService — always called; becomes a no-op when RevenueCat
  //    keys are absent.
  await SubscriptionService().initialize();

  // 4. AnalyticsService — always called; becomes a no-op when Firebase is
  //    not configured.
  AnalyticsService.instance.initialise();

  // 5. Sentry — wraps runApp when DSN is provided so all errors are captured.
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
