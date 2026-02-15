// lib/core/config/app_config.dart
class AppConfig {
  // Replace with actual environment variables or configuration logic
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://your-project.supabase.co');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'your-anon-key');
  static const String googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_KEY', defaultValue: 'your-google-maps-key');
}
