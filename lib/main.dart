// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/app.dart';
import 'providers/app_state.dart' as app_state;
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  AppConfig.validateAndLog();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // AdMob 初期化
  await MobileAds.instance.initialize();

  final app = provider_pkg.ChangeNotifierProvider(
    create: (_) => app_state.AppState(),
    child: const ProviderScope(child: YuMapApp()),
  );

  // Sentry 初期化（DSNが設定されている場合のみ有効）
  if (AppConfig.isSentryEnabled) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.tracesSampleRate = 0.2;
      },
      appRunner: () => runApp(app),
    );
  } else {
    runApp(app);
  }
}