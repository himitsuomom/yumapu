// test/helpers/mocks.dart
//
// Centralized mock definitions used across all test files.

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/services/auth_service.dart';
import 'package:yu_map/services/facility_service.dart';
import 'package:yu_map/services/review_service.dart';
import 'package:yu_map/services/user_service.dart';
import 'package:yu_map/services/visit_service.dart';
import 'package:yu_map/services/badge_service.dart';
import 'package:yu_map/services/favorite_service.dart';
import 'package:yu_map/services/photo_service.dart';

// ── Supabase Mocks ──
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}
class MockPostgrestTransformBuilder extends Mock implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {}

// ── Service Mocks ──
class MockAuthService extends Mock implements AuthService {}
class MockFacilityService extends Mock implements FacilityService {}
class MockReviewService extends Mock implements ReviewService {}
class MockUserService extends Mock implements UserService {}
class MockVisitService extends Mock implements VisitService {}
class MockBadgeService extends Mock implements BadgeService {}
class MockFavoriteService extends Mock implements FavoriteService {}
class MockPhotoService extends Mock implements PhotoService {}
