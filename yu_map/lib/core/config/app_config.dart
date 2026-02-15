// lib/core/config/app_config.dart

/// Application configuration loaded from compile-time environment variables.
///
/// Build with:
/// ```
/// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=eyJ... \
///             --dart-define=GOOGLE_MAPS_KEY=AIza...
/// ```
class AppConfig {
  AppConfig._(); // prevent instantiation

  static const String _supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _googleMapsKey =
      String.fromEnvironment('GOOGLE_MAPS_KEY');
  static const String _revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const String _revenueCatIosKey =
      String.fromEnvironment('REVENUECAT_IOS_KEY');

  /// Returns the Supabase project URL.
  /// Throws [StateError] if not configured via --dart-define.
  static String get supabaseUrl {
    if (_supabaseUrl.isEmpty) {
      throw StateError(
        'SUPABASE_URL is not set. '
        'Please provide it via --dart-define=SUPABASE_URL=<url>',
      );
    }
    return _supabaseUrl;
  }

  /// Returns the Supabase anonymous key.
  /// Throws [StateError] if not configured via --dart-define.
  static String get supabaseAnonKey {
    if (_supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY is not set. '
        'Please provide it via --dart-define=SUPABASE_ANON_KEY=<key>',
      );
    }
    return _supabaseAnonKey;
  }

  /// Returns the Google Maps API key.
  /// Throws [StateError] if not configured via --dart-define.
  static String get googleMapsKey {
    if (_googleMapsKey.isEmpty) {
      throw StateError(
        'GOOGLE_MAPS_KEY is not set. '
        'Please provide it via --dart-define=GOOGLE_MAPS_KEY=<key>',
      );
    }
    return _googleMapsKey;
  }

  /// Returns the RevenueCat Android API key (empty string if not configured).
  static String get revenueCatAndroidKey => _revenueCatAndroidKey;

  /// Returns the RevenueCat iOS API key (empty string if not configured).
  static String get revenueCatIosKey => _revenueCatIosKey;

  /// Validates that all required configuration values are present.
  /// Call this early in app startup to fail fast.
  static void validate() {
    // Accessing each getter triggers the StateError if missing.
    supabaseUrl;
    supabaseAnonKey;
    googleMapsKey;
  }
}
