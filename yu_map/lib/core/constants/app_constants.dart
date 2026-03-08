/// App-wide constants for Yu-Map.
class AppConstants {
  AppConstants._();

  static const String appName = '湯マップ';
  static const String appNameEn = 'Yu-Map';

  // Map defaults (centered on Japan)
  static const double defaultLat = 36.2048;
  static const double defaultLng = 138.2529;
  static const double defaultZoom = 5.0;
  static const double detailZoom = 15.0;

  // Pagination
  static const int pageSize = 20;

  // Rating
  static const int maxRating = 5;
  static const int minRating = 1;

  // Review
  static const int minReviewLength = 10;
  static const int maxReviewLength = 2000;
}
