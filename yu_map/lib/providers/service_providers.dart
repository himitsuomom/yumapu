// lib/providers/service_providers.dart
//
// Riverpod providers for all services — single source of DI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yu_map/services/auth_service.dart';
import 'package:yu_map/services/facility_service.dart';
import 'package:yu_map/services/review_service.dart';
import 'package:yu_map/services/user_service.dart';
import 'package:yu_map/services/photo_service.dart';
import 'package:yu_map/services/visit_service.dart';
import 'package:yu_map/services/badge_service.dart';
import 'package:yu_map/services/favorite_service.dart';
import 'package:yu_map/services/map_clustering_service.dart';
import 'package:yu_map/services/analytics_service.dart';
import 'package:yu_map/services/ad_service.dart';
import 'package:yu_map/services/subscription_service.dart';

// ────────────────────────────────────────────────
// Supabase client (singleton)
// ────────────────────────────────────────────────

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

// ────────────────────────────────────────────────
// Services
// ────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(supabaseClientProvider)),
);

final facilityServiceProvider = Provider<FacilityService>(
  (ref) => FacilityService(ref.watch(supabaseClientProvider)),
);

final reviewServiceProvider = Provider<ReviewService>(
  (ref) => ReviewService(ref.watch(supabaseClientProvider)),
);

final userServiceProvider = Provider<UserService>(
  (ref) => UserService(ref.watch(supabaseClientProvider)),
);

final photoServiceProvider = Provider<PhotoService>(
  (ref) => PhotoService(ref.watch(supabaseClientProvider)),
);

final visitServiceProvider = Provider<VisitService>(
  (ref) => VisitService(ref.watch(supabaseClientProvider)),
);

final badgeServiceProvider = Provider<BadgeService>(
  (ref) => BadgeService(ref.watch(supabaseClientProvider)),
);

final favoriteServiceProvider = Provider<FavoriteService>(
  (ref) => FavoriteService(ref.watch(supabaseClientProvider)),
);

final mapClusteringServiceProvider = Provider<MapClusteringService>(
  (ref) => MapClusteringService(),
);

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(),
);

final adServiceProvider = Provider<AdService>(
  (ref) => AdService(),
);

final subscriptionServiceProvider = Provider<SubscriptionService>(
  (ref) => SubscriptionService(),
);
