import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/providers/auth_provider.dart';

// ── Visit entity (defined here per spec) ────────────────────────────────────

class Visit extends Equatable {
  final String id;
  final String userId;
  final String facilityId;
  final String? note;
  final int? rating;
  final DateTime visitedAt;
  final DateTime createdAt;

  const Visit({
    required this.id,
    required this.userId,
    required this.facilityId,
    this.note,
    this.rating,
    required this.visitedAt,
    required this.createdAt,
  });

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      facilityId: json['facility_id'] as String,
      note: json['note'] as String?,
      rating: json['rating'] as int?,
      visitedAt: DateTime.parse(json['visited_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, userId, facilityId, visitedAt];
}

// ── Visit list ───────────────────────────────────────────────────────────────

final visitListProvider =
    FutureProvider.autoDispose<List<Visit>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  if (client == null || session == null) return [];
  final rows = await client
      .from('visits')
      .select()
      .eq('user_id', session.user.id)
      .order('visited_at', ascending: false)
      .limit(AppConstants.pageSize) as List;
  return rows.map((r) => Visit.fromJson(r as Map<String, dynamic>)).toList();
});

// ── Visit actions ────────────────────────────────────────────────────────────

class VisitNotifier extends StateNotifier<AsyncValue<void>> {
  VisitNotifier(this._client, this._userId) : super(const AsyncData(null));

  final SupabaseClient? _client;
  final String? _userId;

  Future<void> logVisit({
    required String facilityId,
    String? note,
    int? rating,
    DateTime? visitedAt,
  }) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      state = AsyncError('ログインが必要です', StackTrace.current);
      return;
    }
    state = const AsyncLoading();
    try {
      await client.from('visits').insert({
        'facility_id': facilityId,
        'user_id': userId,
        if (note != null) 'note': note,
        if (rating != null) 'rating': rating,
        'visited_at': (visitedAt ?? DateTime.now()).toIso8601String(),
      });
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> deleteVisit(String visitId) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return;
    state = const AsyncLoading();
    try {
      await client
          .from('visits')
          .delete()
          .eq('id', visitId)
          .eq('user_id', userId);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final visitNotifierProvider =
    StateNotifierProvider<VisitNotifier, AsyncValue<void>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  return VisitNotifier(client, session?.user.id);
});
