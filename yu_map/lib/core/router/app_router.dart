// lib/core/router/app_router.dart
//
// GoRouter configuration with auth-aware redirect.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yu_map/providers/auth_providers.dart';

import 'package:yu_map/presentation/screens/auth/login_screen.dart';
import 'package:yu_map/presentation/screens/auth/signup_screen.dart';
import 'package:yu_map/presentation/screens/home/home_screen.dart';
import 'package:yu_map/presentation/screens/facility/facility_detail_screen.dart';
import 'package:yu_map/presentation/screens/search/search_screen.dart';
import 'package:yu_map/presentation/screens/review/review_form_screen.dart';
import 'package:yu_map/presentation/screens/profile/profile_screen.dart';
import 'package:yu_map/presentation/screens/profile/edit_profile_screen.dart';
import 'package:yu_map/presentation/screens/badge/badge_screen.dart';
import 'package:yu_map/presentation/screens/leaderboard/leaderboard_screen.dart';
import 'package:yu_map/presentation/screens/visit/visit_history_screen.dart';
import 'package:yu_map/presentation/screens/auth/password_reset_screen.dart';

/// Route path constants.
class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/';
  static const String facilityDetail = '/facility/:id';
  static const String search = '/search';
  static const String reviewForm = '/facility/:id/review';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String badges = '/badges';
  static const String leaderboard = '/leaderboard';
  static const String visitHistory = '/visits';
  static const String passwordReset = '/password-reset';
}

/// Creates the GoRouter instance, provided via Riverpod.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.passwordReset;

      // Not signed in → force login
      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.login;
      }

      // Already signed in → redirect away from auth pages
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.home;
      }

      return null; // no redirect
    },
    routes: [
      // ── Auth ──
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),

      // ── Home (tabs: Map / Search / Profile) ──
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),

      // ── Facility detail ──
      GoRoute(
        path: AppRoutes.facilityDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FacilityDetailScreen(facilityId: id);
        },
      ),

      // ── Search ──
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const SearchScreen(),
      ),

      // ── Review form ──
      GoRoute(
        path: AppRoutes.reviewForm,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReviewFormScreen(facilityId: id);
        },
      ),

      // ── Profile ──
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),

      // ── Badges ──
      GoRoute(
        path: AppRoutes.badges,
        builder: (context, state) => const BadgeScreen(),
      ),

      // ── Leaderboard ──
      GoRoute(
        path: AppRoutes.leaderboard,
        builder: (context, state) => const LeaderboardScreen(),
      ),

      // ── Visit History ──
      GoRoute(
        path: AppRoutes.visitHistory,
        builder: (context, state) => const VisitHistoryScreen(),
      ),

      // ── Password Reset ──
      GoRoute(
        path: AppRoutes.passwordReset,
        builder: (context, state) => const PasswordResetScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
