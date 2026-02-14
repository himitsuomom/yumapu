// lib/ui/providers/review_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/services/review_service.dart';
import 'package:yu_map/services/supabase_service.dart';
import 'package:yu_map/ui/models/review_model.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ReviewService(supabaseService.client);
});

final reviewsForFacilityProvider = FutureProvider.family.autoDispose<List<ReviewModel>, String>((ref, facilityId) async {
  // Implementation will be added later
  return [];
});

final userLikedReviewsProvider = StateProvider<Map<String, bool>>((ref) {
  return {};
});

final currentReviewDraftProvider = StateNotifierProvider<ReviewDraftNotifier, ReviewDraftState>((ref) {
  return ReviewDraftNotifier();
});

class ReviewDraftState {
  final String content;
  final int rating;
  final List<String> photoUrls;
  final List<dynamic> localPhotos; // Using dynamic as placeholder for Image objects

  ReviewDraftState({
    this.content = '',
    this.rating = 0,
    this.photoUrls = const [],
    this.localPhotos = const [],
  });

  ReviewDraftState copyWith({
    String? content,
    int? rating,
    List<String>? photoUrls,
    List<dynamic>? localPhotos,
  }) {
    return ReviewDraftState(
      content: content ?? this.content,
      rating: rating ?? this.rating,
      photoUrls: photoUrls ?? this.photoUrls,
      localPhotos: localPhotos ?? this.localPhotos,
    );
  }
}

class ReviewDraftNotifier extends StateNotifier<ReviewDraftState> {
  ReviewDraftNotifier() : super(ReviewDraftState());

  void setContent(String content) {
    state = state.copyWith(content: content);
  }

  void setRating(int rating) {
    state = state.copyWith(rating: rating);
  }

  void addPhoto(dynamic photo) {
    state = state.copyWith(localPhotos: [...state.localPhotos, photo]);
  }

  void removePhoto(int index) {
    final newPhotos = List.from(state.localPhotos)..removeAt(index);
    state = state.copyWith(localPhotos: newPhotos);
  }

  void clear() {
    state = ReviewDraftState();
  }
}