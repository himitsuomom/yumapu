import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('isSupabaseConfigured is false with default values', () {
      // Default values have empty anonKey and placeholder URL
      expect(AppConfig.isSupabaseConfigured, false);
    });

    test('isRevenueCatConfigured is false with default values', () {
      expect(AppConfig.isRevenueCatConfigured, false);
    });

    test('isSentryConfigured is false with default values', () {
      expect(AppConfig.isSentryConfigured, false);
    });

    test('AdMob IDs are empty by default (ads disabled until configured)', () {
      expect(AppConfig.adMobBannerIdAndroid, isEmpty);
      expect(AppConfig.adMobBannerIdIos, isEmpty);
      expect(AppConfig.adMobRewardedIdAndroid, isEmpty);
      expect(AppConfig.adMobRewardedIdIos, isEmpty);
      expect(AppConfig.isAdMobConfigured, false);
    });
  });
}
