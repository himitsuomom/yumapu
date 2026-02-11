// lib/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      // Log to crashlytics or other error reporting service if analytics fails
      print('Analytics error: $e');
    }
  }

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? 'Flutter',
      );
    } catch (e) {
      print('Analytics error: $e');
    }
  }

  Future<void> logFacilityView({
    required String facilityId,
    required String facilityName,
    String? facilityType,
    Duration? viewDuration,
  }) async {
    await logEvent('view_facility', parameters: {
      'facility_id': facilityId,
      'facility_name': facilityName,
      if (facilityType != null) 'facility_type': facilityType,
      if (viewDuration != null) 'view_duration_seconds': viewDuration.inSeconds,
    });
  }

  Future<void> logFacilitySearch({
    required String query,
    String? location,
    int? resultsCount,
    String? searchType = 'general',
  }) async {
    await logEvent('search_facilities', parameters: {
      'search_query': query,
      if (location != null) 'location': location,
      if (resultsCount != null) 'results_count': resultsCount,
      'search_type': searchType,
    });
  }

  Future<void> logAdWatch({
    required String facilityId,
    required bool completed,
    required int watchDurationSeconds,
  }) async {
    await logEvent('ad_watch', parameters: {
      'facility_id': facilityId,
      'completed': completed ? 1 : 0,
      'duration_seconds': watchDurationSeconds,
    });
  }

  Future<void> logReviewSubmit({
    required String facilityId,
    required int rating,
    int? contentLength = 0,
    int? photoCount = 0,
  }) async {
    await logEvent('review_submit', parameters: {
      'facility_id': facilityId,
      'rating': rating,
      'content_length': contentLength ?? 0,
      'photo_count': photoCount ?? 0,
    });
  }

  Future<void> logReviewSubmission({
    required String facilityId,
    required int rating,
    bool hasPhoto = false,
  }) async {
    await logEvent('submit_review', parameters: {
      'facility_id': facilityId,
      'rating': rating,
      'has_photo': hasPhoto,
    });
  }

  Future<void> logMapInteraction({
    required String interactionType,
    double? latitude,
    double? longitude,
    String? facilityId,
  }) async {
    await logEvent('map_interaction', parameters: {
      'interaction_type': interactionType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (facilityId != null) 'facility_id': facilityId,
    });
  }

  Future<void> logUserEngagement(String engagementType) async {
    await logEvent('user_engagement', parameters: {
      'engagement_type': engagementType,
    });
  }

  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      print('Analytics error: $e');
    }
  }

  Future<void> setUserProperty(String name, String value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      print('Analytics error: $e');
    }
  }

  Future<void> logLogin({String? loginMethod}) async {
    await logEvent('login', parameters: {
      if (loginMethod != null) 'method': loginMethod,
    });
  }

  Future<void> logSignUp({String? signUpMethod}) async {
    await logEvent('sign_up', parameters: {
      if (signUpMethod != null) 'method': signUpMethod,
    });
  }

  Future<void> logShare({
    required String contentType,
    String? itemId,
    String? method,
  }) async {
    await logEvent('share', parameters: {
      'content_type': contentType,
      if (itemId != null) 'item_id': itemId,
      if (method != null) 'method': method,
    });
  }

  FirebaseAnalyticsObserver getAnalyticsObserver() {
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

  Future<void> resetAnalyticsData() async {
    try {
      await _analytics.resetAnalyticsData();
    } catch (e) {
      print('Analytics error: $e');
    }
  }
}
