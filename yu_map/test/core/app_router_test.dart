// test/core/app_router_test.dart
//
// Tests for AppRoutes constants and route configuration.

import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/core/router/app_router.dart';

void main() {
  group('AppRoutes constants', () {
    test('login route is /login', () {
      expect(AppRoutes.login, '/login');
    });

    test('signup route is /signup', () {
      expect(AppRoutes.signup, '/signup');
    });

    test('home route is /', () {
      expect(AppRoutes.home, '/');
    });

    test('facility detail route uses :id parameter', () {
      expect(AppRoutes.facilityDetail, '/facility/:id');
      expect(AppRoutes.facilityDetail, contains(':id'));
    });

    test('search route is /search', () {
      expect(AppRoutes.search, '/search');
    });

    test('review form route includes facility id', () {
      expect(AppRoutes.reviewForm, '/facility/:id/review');
      expect(AppRoutes.reviewForm, contains(':id'));
    });

    test('profile route is /profile', () {
      expect(AppRoutes.profile, '/profile');
    });

    test('edit profile route is /profile/edit', () {
      expect(AppRoutes.editProfile, '/profile/edit');
    });

    test('badges route is /badges', () {
      expect(AppRoutes.badges, '/badges');
    });

    test('leaderboard route is /leaderboard', () {
      expect(AppRoutes.leaderboard, '/leaderboard');
    });

    test('visit history route is /visits', () {
      expect(AppRoutes.visitHistory, '/visits');
    });

    test('password reset route is /password-reset', () {
      expect(AppRoutes.passwordReset, '/password-reset');
    });

    test('all routes start with /', () {
      final routes = [
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.home,
        AppRoutes.facilityDetail,
        AppRoutes.search,
        AppRoutes.reviewForm,
        AppRoutes.profile,
        AppRoutes.editProfile,
        AppRoutes.badges,
        AppRoutes.leaderboard,
        AppRoutes.visitHistory,
        AppRoutes.passwordReset,
      ];

      for (final route in routes) {
        expect(route, startsWith('/'), reason: '$route should start with /');
      }
    });

    test('there are exactly 12 routes defined', () {
      final routes = [
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.home,
        AppRoutes.facilityDetail,
        AppRoutes.search,
        AppRoutes.reviewForm,
        AppRoutes.profile,
        AppRoutes.editProfile,
        AppRoutes.badges,
        AppRoutes.leaderboard,
        AppRoutes.visitHistory,
        AppRoutes.passwordReset,
      ];

      expect(routes.length, 12);
    });

    test('all route paths are unique', () {
      final routes = [
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.home,
        AppRoutes.facilityDetail,
        AppRoutes.search,
        AppRoutes.reviewForm,
        AppRoutes.profile,
        AppRoutes.editProfile,
        AppRoutes.badges,
        AppRoutes.leaderboard,
        AppRoutes.visitHistory,
        AppRoutes.passwordReset,
      ];

      expect(routes.toSet().length, routes.length);
    });

    test('auth routes are identifiable', () {
      final authRoutes = {AppRoutes.login, AppRoutes.signup, AppRoutes.passwordReset};
      expect(authRoutes.length, 3);
      expect(authRoutes, contains('/login'));
      expect(authRoutes, contains('/signup'));
      expect(authRoutes, contains('/password-reset'));
    });
  });
}
