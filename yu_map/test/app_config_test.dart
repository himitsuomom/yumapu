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

    test('AdMob test IDs are set by default', () {
      expect(AppConfig.adMobBannerIdAndroid, contains('ca-app-pub-3940256099942544'));
      expect(AppConfig.adMobBannerIdIos, contains('ca-app-pub-3940256099942544'));
      expect(AppConfig.adMobRewardedIdAndroid, contains('ca-app-pub-3940256099942544'));
      expect(AppConfig.adMobRewardedIdIos, contains('ca-app-pub-3940256099942544'));
    });
  });
}
