import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// Reviews for a specific facility.
final facilityReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, facilityId) async {
  final client = ref.read(supabaseClientProvider);
  final data = await client
      .from('reviews')
      .select()
      .eq('facility_id', facilityId)
      .order('created_at', ascending: false);
  return (data as List).map((r) => Review.fromJson(r)).toList();
});

/// Submit a review.
class ReviewSubmitNotifier extends StateNotifier<AsyncValue<void>> {
  ReviewSubmitNotifier(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  Future<bool> submitReview({
    required String facilityId,
    required String content,
    required int rating,
  }) async {
    state = const AsyncLoading();
    try {
      final client = _ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        state = AsyncError('ログインが必要です', StackTrace.current);
        return false;
      }
      await client.from('reviews').insert({
        'user_id': userId,
        'facility_id': facilityId,
        'content': content,
        'rating': rating,
      });
      // Invalidate the reviews cache for this facility.
      _ref.invalidate(facilityReviewsProvider(facilityId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final reviewSubmitProvider =
    StateNotifierProvider<ReviewSubmitNotifier, AsyncValue<void>>((ref) {
  return ReviewSubmitNotifier(ref);
});
