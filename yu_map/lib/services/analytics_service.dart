// lib/services/analytics_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Wrapper around Firebase Analytics with graceful error handling.
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Firebase Analytics observer for auto-tracking route changes.
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('AnalyticsService.logScreenView error: $e');
    }
  }

  Future<void> logFacilityView({
    required String facilityId,
    required String facilityName,
    required String facilityType,
    required Duration viewDuration,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'facility_view',
        parameters: {
          'facility_id': facilityId,
          'facility_name': facilityName,
          'facility_type': facilityType,
          'view_duration_seconds': viewDuration.inSeconds,
        },
      );
    } catch (e) {
      debugPrint('AnalyticsService.logFacilityView error: $e');
    }
  }

  Future<void> logAdWatch({
    required String facilityId,
    required bool completed,
    required int watchDurationSeconds,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ad_watch',
        parameters: {
          'facility_id': facilityId,
          'completed': completed ? 1 : 0,
          'duration_seconds': watchDurationSeconds,
        },
      );
    } catch (e) {
      debugPrint('AnalyticsService.logAdWatch error: $e');
    }
  }

  Future<void> logReviewSubmit({
    required String facilityId,
    required int rating,
    required int contentLength,
    required int photoCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'review_submit',
        parameters: {
          'facility_id': facilityId,
          'rating': rating,
          'content_length': contentLength,
          'photo_count': photoCount,
        },
      );
    } catch (e) {
      debugPrint('AnalyticsService.logReviewSubmit error: $e');
    }
  }

  Future<void> logSearch({
    required String searchTerm,
    int? resultCount,
  }) async {
    try {
      await _analytics.logSearch(
        searchTerm: searchTerm,
        numberOfResults: resultCount,
      );
    } catch (e) {
      debugPrint('AnalyticsService.logSearch error: $e');
    }
  }
}
