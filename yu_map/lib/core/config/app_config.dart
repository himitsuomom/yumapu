// lib/core/config/app_config.dart

/// Centralized configuration for Yu-Map.
///
/// All values are injected at compile time via --dart-define.
/// Never commit real keys. Use .env.example as reference.
class AppConfig {
  AppConfig._();

  // Supabase
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Google Maps
  static const String googleMapsKeyAndroid = String.fromEnvironment(
    'GOOGLE_MAPS_KEY_ANDROID',
    defaultValue: '',
  );
  static const String googleMapsKeyIos = String.fromEnvironment(
    'GOOGLE_MAPS_KEY_IOS',
    defaultValue: '',
  );

  // RevenueCat
  static const String revenueCatKeyAndroid = String.fromEnvironment(
    'REVENUECAT_KEY_ANDROID',
    defaultValue: '',
  );
  static const String revenueCatKeyIos = String.fromEnvironment(
    'REVENUECAT_KEY_IOS',
    defaultValue: '',
  );

  // AdMob — test IDs used by default; replace with production IDs before release
  static const String adMobBannerIdAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String adMobBannerIdIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );
  static const String adMobRewardedIdAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const String adMobRewardedIdIos = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  // Sentry
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// True when real Supabase credentials are provided.
  static bool get isSupabaseConfigured =>
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project');

  /// True when RevenueCat keys are provided.
  static bool get isRevenueCatConfigured =>
      revenueCatKeyAndroid.isNotEmpty || revenueCatKeyIos.isNotEmpty;

  /// True when Sentry DSN is provided.
  static bool get isSentryConfigured => sentryDsn.isNotEmpty;
}
