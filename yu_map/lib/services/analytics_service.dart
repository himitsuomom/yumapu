// lib/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logFacilityView({
    required String facilityId,
    required String facilityName,
    required String facilityType,
    required Duration viewDuration,
  }) async {
    await _analytics.logEvent(
      name: 'facility_view',
      parameters: {
        'facility_id': facilityId,
        'facility_name': facilityName,
        'facility_type': facilityType,
        'view_duration_seconds': viewDuration.inSeconds,
      },
    );
  }

  Future<void> logAdWatch({
    required String facilityId,
    required bool completed,
    required int watchDurationSeconds,
  }) async {
    await _analytics.logEvent(
      name: 'ad_watch',
      parameters: {
        'facility_id': facilityId,
        'completed': completed ? 1 : 0,
        'duration_seconds': watchDurationSeconds,
      },
    );
  }

  Future<void> logReviewSubmit({
    required String facilityId,
    required int rating,
    required int contentLength,
    required int photoCount,
  }) async {
    await _analytics.logEvent(
      name: 'review_submit',
      parameters: {
        'facility_id': facilityId,
        'rating': rating,
        'content_length': contentLength,
        'photo_count': photoCount,
      },
    );
  }
}
