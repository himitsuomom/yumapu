import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/providers/auth_provider.dart';

// ── Visit count ──────────────────────────────────────────────────────────────

/// ログインユーザーの総チェックイン件数。
/// バッジ進捗表示・プロフィール統計に使用する。
/// COUNT クエリを使い全件取得を避ける。
final visitCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  if (client == null || session == null) return 0;
  try {
    final response = await client
        .from('visits')
        .select()
        .eq('user_id', session.user.id)
        .count(CountOption.exact);
    return response.count;
  } catch (_) {
    return 0;
  }
});

// ── Visit entity (defined here per spec) ────────────────────────────────────

class Visit extends Equatable {
  final String id;
  final String userId;
  final String facilityId;

  /// JOIN で取得した施設名。visitListProvider が facilities テーブルを
  /// 一括 JOIN するため N+1 クエリが発生しない。
  final String? facilityName;

  final String? note;
  final int? rating;
  final DateTime visitedAt;
  final DateTime createdAt;

  const Visit({
    required this.id,
    required this.userId,
    required this.facilityId,
    this.facilityName,
    this.note,
    this.rating,
    required this.visitedAt,
    required this.createdAt,
  });

  factory Visit.fromJson(Map<String, dynamic> json) {
    // visited_at は DB で DEFAULT NOW() なので基本は存在するが念のため
    final visitedAtStr = json['visited_at'] as String?;
    final createdAtStr = json['created_at'] as String?;
    final visitedAt = visitedAtStr != null
        ? DateTime.parse(visitedAtStr)
        : DateTime.now();

    // facilities は LEFT JOIN で取得したネストオブジェクト。
    // SELECT の形式: 'facilities(name)' → json['facilities'] が Map で届く。
    final facilitiesJson = json['facilities'] as Map<String, dynamic>?;

    return Visit(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      facilityId: json['facility_id'] as String,
      facilityName: facilitiesJson?['name'] as String?,
      note: json['note'] as String?,
      rating: json['rating'] as int?,
      visitedAt: visitedAt,
      // created_at は後から追加したカラムなので visited_at にフォールバック
      createdAt: createdAtStr != null
          ? DateTime.parse(createdAtStr)
          : visitedAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, facilityId, visitedAt];
}

// ── Visit list ───────────────────────────────────────────────────────────────

/// プロフィール画面用：最新 [AppConstants.pageSize] 件のみ取得（パフォーマンス優先）。
final visitListProvider =
    FutureProvider.autoDispose<List<Visit>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  if (client == null || session == null) return [];
  // facilities(name) を LEFT JOIN で一括取得することで N+1 クエリを防ぐ。
  // 施設名が存在しない場合は null になり、Visit.facilityId を表示する。
  final rows = await client
      .from('visits')
      .select('*, facilities(name)')
      .eq('user_id', session.user.id)
      .order('visited_at', ascending: false)
      .limit(AppConstants.pageSize) as List;
  return rows.map((r) => Visit.fromJson(r as Map<String, dynamic>)).toList();
});

/// 訪問履歴全件表示画面用：全件を月別表示のために取得する（UX-V7-1対応）。
/// プロフィール画面の「すべて見る」から遷移した場合に使用する。
final visitAllProvider =
    FutureProvider.autoDispose<List<Visit>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  if (client == null || session == null) return [];
  final rows = await client
      .from('visits')
      .select('*, facilities(name)')
      .eq('user_id', session.user.id)
      .order('visited_at', ascending: false) as List;
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
