import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/providers/auth_provider.dart';

// ── Review list (per facility) ───────────────────────────────────────────────

final reviewListProvider =
    FutureProvider.autoDispose.family<List<Review>, String>((ref, facilityId) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return [];
  final rows = await client
      .from('reviews')
      .select('*, users!user_id(display_name, avatar_url, is_premium)')
      .eq('facility_id', facilityId)
      .order('created_at', ascending: false)
      .limit(AppConstants.pageSize) as List;
  return rows.map((r) => Review.fromJson(r as Map<String, dynamic>)).toList();
});

// ── Review actions ───────────────────────────────────────────────────────────

class ReviewNotifier extends StateNotifier<AsyncValue<void>> {
  ReviewNotifier(this._client, this._userId) : super(const AsyncData(null));

  final SupabaseClient? _client;
  final String? _userId;

  Future<void> postReview({
    required String facilityId,
    required String content,
    required int rating,
  }) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      state = AsyncError('ログインが必要です', StackTrace.current);
      return;
    }
    state = const AsyncLoading();
    try {
      await client.from('reviews').insert({
        'facility_id': facilityId,
        'user_id': userId,
        'content': content,
        'rating': rating,
      });
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> deleteReview(String reviewId) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return;
    state = const AsyncLoading();
    try {
      await client
          .from('reviews')
          .delete()
          .eq('id', reviewId)
          .eq('user_id', userId);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Inserts a like for [reviewId]. Silently ignores duplicate-like errors.
  Future<void> likeReview(String reviewId) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return;
    try {
      await client.from('review_likes').insert({
        'review_id': reviewId,
        'user_id': userId,
      });
    } catch (_) {
      // Already liked or network error — no state change needed
    }
  }
}

final reviewNotifierProvider =
    StateNotifierProvider<ReviewNotifier, AsyncValue<void>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  return ReviewNotifier(client, session?.user.id);
});
