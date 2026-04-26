/// App-wide constants for Yu-Map.
class AppConstants {
  AppConstants._();

  static const String appName = '湯マップ';
  static const String appNameEn = 'Yu-Map';

  /// pubspec.yaml の version フィールドに合わせて手動で更新する。
  /// package_info_plus を使わずに静的定数で管理する（ビルド依存を減らすため）。
  static const String appVersion = '1.0.0';

  // Map defaults (centered on Tokyo — GPS取得前の初期表示)
  static const double defaultLat = 35.6762;
  static const double defaultLng = 139.6503;
  static const double defaultZoom = 13.0;
  static const double detailZoom = 15.0;

  // Pagination
  static const int pageSize = 20;

  // Rating
  static const int maxRating = 5;
  static const int minRating = 1;

  // Review
  static const int minReviewLength = 10;
  static const int maxReviewLength = 2000;

  // Store URLs (D-4対応: アプリ評価リンク)
  // App Store / Google Play に公開後に実際の URL を設定する。
  // 空文字のままの場合は設定画面に「アプリを評価する」ボタンが表示されない。
  static const String appStoreUrl = '';       // 例: 'https://apps.apple.com/jp/app/yu-map/id1234567890'
  static const String googlePlayUrl = '';     // 例: 'https://play.google.com/store/apps/details?id=com.yumap.app'
}
