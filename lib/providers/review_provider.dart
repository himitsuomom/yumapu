import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/providers/auth_provider.dart';
// ignore_for_file: avoid_manual_providers_as_generated_provider_dependency

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
/// サーバーサイドで COUNT(*) を実行するため、件数のみ転送されデータは転送されない。
/// [reviewListProvider] は最新 [AppConstants.pageSize] 件に制限されているため、
/// 正確な総件数はこのプロバイダーで別途取得する。
final reviewCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, facilityId) async {
  final client = ref.read(supabaseClientProvider);
  if (client == null) return 0;
  try {
    final response = await client
        .from('reviews')
        .select()
        .eq('facility_id', facilityId)
        .count(CountOption.exact);
    return response.count ?? 0;
  } catch (_) {
    return 0;
  }
});

/// 施設の平均評価（全レビューを対象にサーバーサイドで AVG 計算）。
///
/// [reviewListProvider] は最新 [AppConstants.pageSize] 件に LIMIT されているため、
/// レビューが多い施設では偏った平均になる（Bug-V7-2）。
/// この provider は Supabase RPC `get_facility_avg_rating` を呼び出し、
/// 全件に対する正確な平均を取得する。RPC 未デプロイ時は 0.0 を返す。
final facilityAvgRatingProvider =
    FutureProvider.autoDispose.family<double, String>((ref, facilityId) async {
  final client = ref.read(supabaseClientProvider);
  if (client == null) return 0.0;
  try {
    final result = await client
        .rpc('get_facility_avg_rating', params: {'p_facility_id': facilityId});
    if (result == null) return 0.0;
    return double.tryParse(result.toString()) ?? 0.0;
  } catch (_) {
    // RPC 未デプロイや一時エラーの場合は 0.0 を返してUIへの影響を最小化する
    return 0.0;
  }
});

/// レビュー集計（件数＋平均評価）を1回のRPC呼び出しで取得する統合プロバイダー。
///
/// [reviewCountProvider] と [facilityAvgRatingProvider] を統合し、
/// FacilityPreviewSheet の5並列APIを4並列に削減する。
///
/// 戻り値: Record ({int count, double avgRating})
///   count     ... 全レビュー件数
///   avgRating ... 全件平均評価（0件の場合は 0.0）
///
/// RPC `get_facility_review_summary` が未デプロイの場合は
/// フォールバックとして既存の reviewCountProvider + facilityAvgRatingProvider を使う。
final facilityReviewSummaryProvider =
    FutureProvider.autoDispose.family<({int count, double avgRating}), String>(
  (ref, facilityId) async {
  final client = ref.read(supabaseClientProvider);
  if (client == null) return (count: 0, avgRating: 0.0);

  try {
    // 1回のRPCでcount + avg_ratingを取得（APIコール削減）
    final result = await client
        .rpc('get_facility_review_summary', params: {'p_facility_id': facilityId});
    if (result == null) return (count: 0, avgRating: 0.0);

    final map = result as Map<String, dynamic>;
    final count = (map['count'] as num?)?.toInt() ?? 0;
    final avg = map['avg_rating'] == null
        ? 0.0
        : double.tryParse(map['avg_rating'].toString()) ?? 0.0;
    return (count: count, avgRating: avg);
  } catch (_) {
    // RPC未デプロイや一時エラーの場合: 既存プロバイダーにフォールバック
    try {
      final countResult = await client
          .from('reviews')
          .select()
          .eq('facility_id', facilityId)
          .count(CountOption.exact);
      final count = countResult.count ?? 0;

      double avg = 0.0;
      if (count > 0) {
        final avgResult = await client
            .rpc('get_facility_avg_rating', params: {'p_facility_id': facilityId});
        avg = avgResult == null ? 0.0 : (double.tryParse(avgResult.toString()) ?? 0.0);
      }
      return (count: count, avgRating: avg);
    } catch (_) {
      return (count: 0, avgRating: 0.0);
    }
  }
});

// ── 自分のレビュー（施設ごと）────────────────────────────────────────────────

/// ログイン中ユーザーが [facilityId] に既にレビューを投稿しているか確認する。
///
/// 将来の「投稿済みバナー」や「編集ショートカット」など施設詳細UIで
/// 自分のレビューを素早く取得したいときに使う。
/// 既存レビューがある場合は Review を返し、未投稿なら null を返す。
final myReviewForFacilityProvider =
    FutureProvider.autoDispose.family<Review?, String>((ref, facilityId) async {
  final client = ref.read(supabaseClientProvider);
  final session = ref.read(sessionProvider);
  if (client == null || session == null) return null;
  try {
    final rows = await client
        .from('reviews')
        .select('*, users!user_id(display_name, avatar_url, is_premium)')
        .eq('facility_id', facilityId)
        .eq('user_id', session.user.id)
        .limit(1) as List;
    if (rows.isEmpty) return null;
    return Review.fromJson(rows.first as Map<String, dynamic>);
  } catch (_) {
    return null;
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
      // 重複レビューの事前チェック（DB の UNIQUE 制約の前に確認してユーザーに分かりやすいエラーを返す）
      final existing = await client
          .from('reviews')
          .select('id')
          .eq('facility_id', facilityId)
          .eq('user_id', userId)
          .limit(1) as List;
      if (existing.isNotEmpty) {
        state = AsyncError(
          'この施設にはすでにレビューを投稿しています。\n投稿済みのレビューは施設詳細画面から削除できます。',
          StackTrace.current,
        );
        return;
      }
      await client.from('reviews').insert({
        'facility_id': facilityId,
        'user_id': userId,
        'content': content,
        'rating': rating,
      });
      state = const AsyncData(null);
    } on PostgrestException catch (e, st) {
      // DB の UNIQUE 制約違反（error code 23505）も同様のメッセージで返す
      if (e.code == '23505') {
        state = AsyncError(
          'この施設にはすでにレビューを投稿しています。\n投稿済みのレビューは施設詳細画面から削除できます。',
          st,
        );
      } else {
        state = AsyncError(e, st);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// 自分が投稿したレビューの内容と評価を更新する。
  ///
  /// RLS ポリシー "Users can update own reviews" により、
  /// auth.uid() = user_id の行のみ UPDATE が許可される。
  Future<void> editReview({
    required String reviewId,
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
      await client
          .from('reviews')
          .update({
            'content': content,
            'rating': rating,
          })
          .eq('id', reviewId)
          .eq('user_id', userId);
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

  /// Removes a like for [reviewId]. Silently ignores not-found errors.
  Future<void> unlikeReview(String reviewId) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return;
    try {
      await client
          .from('review_likes')
          .delete()
          .eq('review_id', reviewId)
          .eq('user_id', userId);
    } catch (_) {
      // Not liked or network error — no state change needed
    }
  }
}

final reviewNotifierProvider =
    StateNotifierProvider<ReviewNotifier, AsyncValue<void>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  return ReviewNotifier(client, session?.user.id);
});

/// ログイン中ユーザーがいいねしたレビューID一覧。
///
/// UX-V8-9: いいねトグルのために「自分がすでにいいねしているか」を判定する。
/// facilityId ごとに autoDispose で取得し、不要になったら自動破棄する。
final likedReviewIdsProvider =
    FutureProvider.autoDispose.family<Set<String>, String>(
        (ref, facilityId) async {
  final client = ref.read(supabaseClientProvider);
  final session = ref.read(sessionProvider);
  if (client == null || session == null) return {};
  try {
    // review_likes から自分がいいねしたレビューIDを取得する
    // review テーブルとの JOIN でこの施設のレビューに絞る
    final rows = await client
        .from('review_likes')
        .select('review_id, reviews!inner(facility_id)')
        .eq('user_id', session.user.id)
        .eq('reviews.facility_id', facilityId) as List;
    return rows.map((r) => r['review_id'] as String).toSet();
  } catch (_) {
    return {};
  }
});
