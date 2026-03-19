// lib/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<Result<void>> logScreenView(String screenName) async {
    return runCatching(() => _analytics.logScreenView(screenName: screenName));
  }

  Future<Result<void>> logFacilityView({
    required String facilityId,
    required String facilityName,
    required String facilityType,
    required Duration viewDuration,
  }) async {
    return runCatching(() => _analytics.logEvent(
      name: 'facility_view',
      parameters: {
        'facility_id': facilityId,
        'facility_name': facilityName,
        'facility_type': facilityType,
        'view_duration_seconds': viewDuration.inSeconds,
      },
    ));
  }

  Future<Result<void>> logAdWatch({
    required String facilityId,
    required bool completed,
    required int watchDurationSeconds,
  }) async {
    return runCatching(() => _analytics.logEvent(
      name: 'ad_watch',
      parameters: {
        'facility_id': facilityId,
        'completed': completed ? 1 : 0,
        'duration_seconds': watchDurationSeconds,
      },
    ));
  }

  Future<Result<void>> logReviewSubmit({
    required String facilityId,
    required int rating,
    required int contentLength,
    required int photoCount,
  }) async {
    return runCatching(() => _analytics.logEvent(
      name: 'review_submit',
      parameters: {
        'facility_id': facilityId,
        'rating': rating,
        'content_length': contentLength,
        'photo_count': photoCount,
      },
    ));
  }
}
