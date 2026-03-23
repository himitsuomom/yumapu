import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/app.dart';
import 'package:yu_map/services/analytics_service.dart';
import 'package:yu_map/services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if configured.
  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  // Initialize AdMob only when the current platform's ad unit IDs are
  // configured.  On iOS the SDK requires GADApplicationIdentifier in
  // Info.plist; calling initialize() without it throws
  // GADInvalidInitializationException.
  final isAdMobReady = Platform.isAndroid
      ? AppConfig.adMobBannerIdAndroid.isNotEmpty
      : Platform.isIOS
          ? AppConfig.adMobBannerIdIos.isNotEmpty
          : false;
  if (isAdMobReady) {
    unawaited(MobileAds.instance.initialize());
  }

  // Configure the RevenueCat SDK globally (safe no-op when unconfigured).
  // The Riverpod-managed SubscriptionProvider handles state separately.
  await SubscriptionService().initialize();

  // Initialize Firebase Analytics (safe — no-ops if Firebase is not configured).
  AnalyticsService.instance.initialise();
  AnalyticsService.instance.logAppOpen();

  // Launch app — with or without Sentry.
  if (AppConfig.isSentryConfigured) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.tracesSampleRate = 0.2;
      },
      appRunner: () => runApp(const ProviderScope(child: YuMapApp())),
    );
  } else {
    runApp(const ProviderScope(child: YuMapApp()));
  }
}
