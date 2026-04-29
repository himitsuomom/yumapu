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

  // AdMob
  static const String adMobBannerIdAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: '',
  );
  static const String adMobBannerIdIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: '',
  );
  static const String adMobRewardedIdAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: '',
  );
  static const String adMobRewardedIdIos = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: '',
  );

  // Sentry
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  // ── Feature flags (default off — enable via --dart-define) ──────────────
  static const bool isCheckinEnabled = bool.fromEnvironment(
    'FEATURE_CHECKIN',
    defaultValue: false,
  );
  static const bool isReviewEnabled = bool.fromEnvironment(
    'FEATURE_REVIEW',
    defaultValue: false,
  );
  static const bool isRankingEnabled = bool.fromEnvironment(
    'FEATURE_RANKING',
    defaultValue: false,
  );

  /// True when real Supabase credentials are provided.
  static bool get isSupabaseConfigured =>
      supabaseAnonKey.isNotEmpty && !supabaseUrl.contains('your-project');

  /// True when RevenueCat keys are provided.
  static bool get isRevenueCatConfigured =>
      revenueCatKeyAndroid.isNotEmpty || revenueCatKeyIos.isNotEmpty;

  /// True when AdMob ad unit IDs are provided (at least one banner ID).
  static bool get isAdMobConfigured =>
      adMobBannerIdAndroid.isNotEmpty || adMobBannerIdIos.isNotEmpty;

  /// True when Sentry DSN is provided.
  static bool get isSentryConfigured => sentryDsn.isNotEmpty;
}
