import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Analytics.
///
/// All methods are safe to call even when Firebase is not initialised —
/// they catch exceptions silently so the rest of the app never needs to
/// guard calls.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;
  bool _initialised = false;

  /// Call once during app startup. If Firebase is not configured the
  /// service stays in a no-op state for the lifetime of the process.
  void initialise() {
    try {
      _analytics = FirebaseAnalytics.instance;
      _initialised = true;
    } catch (e) {
      debugPrint('AnalyticsService: Firebase not available — disabled ($e)');
    }
  }

  // ── Core events ────────────────────────────────────────────────────

  Future<void> logAppOpen() => _log('app_open');

  Future<void> logLogin({String method = 'email'}) =>
      _log('login', {'method': method});

  Future<void> logSignUp({String method = 'email'}) =>
      _log('sign_up', {'method': method});

  Future<void> logScreenView(String screenName) async {
    if (!_initialised) return;
    try {
      await _analytics!.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('AnalyticsService: logScreenView failed ($e)');
    }
  }

  Future<void> logSearch(String query) =>
      _log('search', {'search_term': query});

  Future<void> logFacilityView({
    required String facilityId,
    required String facilityName,
  }) =>
      _log('facility_view', {
        'facility_id': facilityId,
        'facility_name': facilityName,
      });

  Future<void> logReviewSubmit({
    required String facilityId,
    required int rating,
    required int contentLength,
  }) =>
      _log('review_submit', {
        'facility_id': facilityId,
        'rating': rating,
        'content_length': contentLength,
      });

  Future<void> logFavoriteToggle({
    required String facilityId,
    required bool added,
  }) =>
      _log('favorite_toggle', {
        'facility_id': facilityId,
        'action': added ? 'add' : 'remove',
      });

  Future<void> logCheckIn({required String facilityId}) =>
      _log('check_in', {'facility_id': facilityId});

  // ── Internal ───────────────────────────────────────────────────────

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_initialised) return;
    try {
      await _analytics!.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('AnalyticsService: $name failed ($e)');
    }
  }
}
