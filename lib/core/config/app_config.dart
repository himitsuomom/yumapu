// lib/core/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Supabase Configuration
  // Load from .env file: SUPABASE_URL and SUPABASE_ANON_KEY
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Google Maps Configuration
  // Load from .env file: GOOGLE_MAPS_KEY
  static String get googleMapsKey => dotenv.env['GOOGLE_MAPS_KEY'] ?? '';

  // Validation method to check if all required environment variables are set
  static bool isConfigValid() {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        googleMapsKey.isNotEmpty;
  }

  // Debug method to display configuration status
  static void validateAndLog() {
    final missingVars = <String>[];

    if (supabaseUrl.isEmpty) missingVars.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missingVars.add('SUPABASE_ANON_KEY');
    if (googleMapsKey.isEmpty) missingVars.add('GOOGLE_MAPS_KEY');

    if (missingVars.isNotEmpty) {
      throw Exception(
        'Missing environment variables: ${missingVars.join(', ')}\n'
        'Please check your .env file and ensure all required variables are set.',
      );
    }
  }
}
