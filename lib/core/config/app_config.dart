// lib/core/config/app_config.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Google Maps
  static String get googleMapsKey {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return dotenv.env['GOOGLE_MAPS_KEY_IOS'] ?? dotenv.env['GOOGLE_MAPS_KEY'] ?? '';
    } else {
      return dotenv.env['GOOGLE_MAPS_KEY_ANDROID'] ?? dotenv.env['GOOGLE_MAPS_KEY'] ?? '';
    }
  }

  // AdMob 広告ユニットID
  static String get admobBannerId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return dotenv.env['ADMOB_BANNER_IOS'] ?? '';
    } else {
      return dotenv.env['ADMOB_BANNER_ANDROID'] ?? '';
    }
  }

  static String get admobRewardedId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return dotenv.env['ADMOB_REWARDED_IOS'] ?? '';
    } else {
      return dotenv.env['ADMOB_REWARDED_ANDROID'] ?? '';
    }
  }

  // Sentry DSN（空欄の場合はSentryを無効化）
  static String get sentryDsn => dotenv.env['SENTRY_DSN'] ?? '';
  static bool get isSentryEnabled => sentryDsn.isNotEmpty;

  static bool isConfigValid() {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        googleMapsKey.isNotEmpty;
  }

  static void validateAndLog() {
    final missingVars = <String>[];

    if (supabaseUrl.isEmpty) missingVars.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missingVars.add('SUPABASE_ANON_KEY');
    if (googleMapsKey.isEmpty) missingVars.add('GOOGLE_MAPS_KEY_IOS / GOOGLE_MAPS_KEY_ANDROID');

    if (missingVars.isNotEmpty) {
      throw Exception(
        'Missing environment variables: ${missingVars.join(', ')}\n'
        'Please check your .env file and ensure all required variables are set.',
      );
    }
  }
}
