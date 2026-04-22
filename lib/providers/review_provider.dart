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

/// 施設のレビュー総件数を正確に取得する。
///
/// [reviewListProvider] は表示用で上位 [AppConstants.pageSize] 件に制限されているため、
/// 21件以上の施設では件数が不正確になる。このプロバイダーは ID のみ取得して
/// 正確な総件数を返す（データ量が最小限で済む）。
final reviewCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, facilityId) async {
  final client = ref.read(supabaseClientProvider);
  if (client == null) return 0;
  try {
    final rows = await client
        .from('reviews')
        .select('id')
        .eq('facility_id', facilityId) as List;
    return rows.length;
  } catch (_) {
    return 0;
  }
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
