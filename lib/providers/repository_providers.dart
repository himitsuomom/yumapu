// lib/providers/repository_providers.dart
//
// DI wiring: Riverpod providers that expose all repository implementations.
// UI and notifiers should depend on these, not on supabaseClientProvider directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/data/repositories/supabase_auth_repository.dart';
import 'package:yu_map/data/repositories/supabase_badge_repository.dart';
import 'package:yu_map/data/repositories/supabase_comment_repository.dart';
import 'package:yu_map/data/repositories/supabase_facility_repository.dart';
import 'package:yu_map/data/repositories/supabase_favorite_repository.dart';
import 'package:yu_map/data/repositories/supabase_follow_repository.dart';
import 'package:yu_map/data/repositories/supabase_plan_repository.dart';
import 'package:yu_map/data/repositories/supabase_post_repository.dart';
import 'package:yu_map/data/repositories/supabase_ranking_repository.dart';
import 'package:yu_map/data/repositories/supabase_review_repository.dart';
import 'package:yu_map/data/repositories/supabase_visit_repository.dart';
import 'package:yu_map/domain/repositories/i_auth_repository.dart';
import 'package:yu_map/domain/repositories/i_badge_repository.dart';
import 'package:yu_map/domain/repositories/i_comment_repository.dart';
import 'package:yu_map/domain/repositories/i_facility_repository.dart';
import 'package:yu_map/domain/repositories/i_favorite_repository.dart';
import 'package:yu_map/domain/repositories/i_follow_repository.dart';
import 'package:yu_map/domain/repositories/i_plan_repository.dart';
import 'package:yu_map/domain/repositories/i_post_repository.dart';
import 'package:yu_map/domain/repositories/i_ranking_repository.dart';
import 'package:yu_map/domain/repositories/i_review_repository.dart';
import 'package:yu_map/domain/repositories/i_visit_repository.dart';
import 'package:yu_map/providers/auth_provider.dart';

final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase not configured');
  return SupabaseAuthRepository(client);
});

final facilityRepositoryProvider = Provider<IFacilityRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase not configured');
  return SupabaseFacilityRepository(client);
});

final postRepositoryProvider = Provider<IPostRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase not configured');
  return SupabasePostRepository(client);
});

final reviewRepositoryProvider = Provider<IReviewRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase not configured');
  return SupabaseReviewRepository(client);
});

final visitRepositoryProvider = Provider<IVisitRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase not configured');
  return SupabaseVisitRepository(client);
});

final favoritesRepositoryProvider = Provider<IFavoriteRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase not configured');
  return SupabaseFavoriteRepository(client);
});

final followRepositoryProvider = Provider<IFollowRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase not configured');
  return SupabaseFollowRepository(client);
});

final commentRepositoryProvider = Provider<ICommentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase not configured');
  return SupabaseCommentRepository(client);
});

final planRepositoryProvider = Provider<IPlanRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase not configured');
  return SupabasePlanRepository(client);
});

final rankingRepositoryProvider = Provider<IRankingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase not configured');
  return SupabaseRankingRepository(client);
});

final badgeRepositoryProvider = Provider<IBadgeRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase not configured');
  return SupabaseBadgeRepository(client);
});
