import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/app.dart';
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

  // Initialize AdMob.
  unawaited(MobileAds.instance.initialize());

  // Initialize RevenueCat subscriptions.
  await SubscriptionService().initialize();

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
