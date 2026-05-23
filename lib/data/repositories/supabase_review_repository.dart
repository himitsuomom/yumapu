// lib/data/repositories/supabase_review_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/domain/repositories/i_review_repository.dart';

class SupabaseReviewRepository implements IReviewRepository {
  SupabaseReviewRepository(this._client);
  final SupabaseClient _client;

  static const _selectFields =
      '*, users!user_id(display_name, avatar_url, is_premium)';

  @override
  Future<Result<List<Review>>> getReviewsByFacility(String facilityId,
          {int limit = 20, int offset = 0}) =>
      runCatching(() async {
        final rows = await _client
            .from('reviews')
            .select(_selectFields)
            .eq('facility_id', facilityId)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1) as List;
        return rows
            .map((r) => Review.fromJson(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<Result<Review?>> getUserReviewForFacility(String facilityId) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return null;
        final rows = await _client
            .from('reviews')
            .select(_selectFields)
            .eq('facility_id', facilityId)
            .eq('user_id', session.user.id)
            .limit(1) as List;
        if (rows.isEmpty) return null;
        return Review.fromJson(rows.first as Map<String, dynamic>);
      });

  @override
  Future<Result<Review>> createReview({
    required String facilityId,
    required double rating,
    required String content,
  }) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();

        // Pre-check for duplicate review
        final existing = await _client
            .from('reviews')
            .select('id')
            .eq('facility_id', facilityId)
            .eq('user_id', session.user.id)
            .limit(1) as List;
        if (existing.isNotEmpty) {
          throw const UniqueConstraintException(
              'この施設にはすでにレビューを投稿しています');
        }

        final result = await _client
            .from('reviews')
            .insert({
              'facility_id': facilityId,
              'user_id': session.user.id,
              'content': content,
              'rating': rating.toInt(),
            })
            .select(_selectFields)
            .single();
        return Review.fromJson(result);
      });

  @override
  Future<Result<void>> updateReview(String reviewId,
          {double? rating, String? content}) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        final patch = <String, dynamic>{};
        if (rating != null) patch['rating'] = rating.toInt();
        if (content != null) patch['content'] = content;
        if (patch.isEmpty) return;
        await _client
            .from('reviews')
            .update(patch)
            .eq('id', reviewId)
            .eq('user_id', session.user.id);
      });

  @override
  Future<Result<void>> deleteReview(String reviewId) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client
            .from('reviews')
            .delete()
            .eq('id', reviewId)
            .eq('user_id', session.user.id);
      });

  @override
  Future<Result<void>> likeReview(String reviewId) => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client.from('review_likes').insert({
          'review_id': reviewId,
          'user_id': session.user.id,
        });
      });

  @override
  Future<Result<void>> unlikeReview(String reviewId) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client
            .from('review_likes')
            .delete()
            .eq('review_id', reviewId)
            .eq('user_id', session.user.id);
      });
}
