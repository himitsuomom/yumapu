// lib/providers/plan_provider.dart
//
// 湯めぐりプランの状態管理。
// - 自分のプラン一覧取得
// - プランの作成
// - 施設をプランに追加 / 除去

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/models/onsen_plan.dart';
import 'package:yu_map/providers/auth_provider.dart';

// ── プラン一覧 ────────────────────────────────────────────────────────────────

/// ログイン中ユーザーの湯めぐりプラン一覧（更新日時降順）
final myPlansProvider =
    FutureProvider.autoDispose<List<OnsenPlan>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  if (client == null || session == null) return [];

  try {
    final data = await client
        .from('onsen_plans')
        .select()
        .eq('user_id', session.user.id)
        .order('updated_at', ascending: false);

    return (data as List)
        .map((e) => OnsenPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

// ── プラン操作 ────────────────────────────────────────────────────────────────

class PlanNotifier extends StateNotifier<AsyncValue<void>> {
  PlanNotifier(this._client, this._userId) : super(const AsyncData(null));

  final SupabaseClient? _client;
  final String? _userId;

  /// 新しいプランを作成する
  Future<OnsenPlan?> createPlan({
    required String title,
    String? description,
    bool isPublic = false,
  }) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      state = AsyncError('ログインが必要です', StackTrace.current);
      return null;
    }

    state = const AsyncLoading();
    try {
      final data = await client
          .from('onsen_plans')
          .insert({
            'user_id': userId,
            'title': title,
            if (description != null && description.isNotEmpty)
              'description': description,
            'is_public': isPublic,
            'facility_ids': [],
          })
          .select()
          .single();

      state = const AsyncData(null);
      return OnsenPlan.fromJson(data);
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// 施設をプランに追加する（重複追加を防ぐ）
  Future<void> addFacilityToPlan({
    required String planId,
    required String facilityId,
    required List<String> currentFacilityIds,
  }) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      state = AsyncError('ログインが必要です', StackTrace.current);
      return;
    }

    if (currentFacilityIds.contains(facilityId)) {
      // すでに追加済みなので何もしない
      return;
    }

    state = const AsyncLoading();
    try {
      final newIds = [...currentFacilityIds, facilityId];
      await client
          .from('onsen_plans')
          .update({'facility_ids': newIds})
          .eq('id', planId)
          .eq('user_id', userId);

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// 施設をプランから削除する
  Future<void> removeFacilityFromPlan({
    required String planId,
    required String facilityId,
    required List<String> currentFacilityIds,
  }) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      state = AsyncError('ログインが必要です', StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    try {
      final newIds =
          currentFacilityIds.where((id) => id != facilityId).toList();
      await client
          .from('onsen_plans')
          .update({'facility_ids': newIds})
          .eq('id', planId)
          .eq('user_id', userId);

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// プラン内の施設順序を並べ替える（UX-V11-4対応）。
  ///
  /// [newFacilityIds]: 並べ替え後の施設 ID リスト（全件 + 同じ施設が入っていること）
  Future<void> reorderFacilitiesInPlan({
    required String planId,
    required List<String> newFacilityIds,
  }) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      state = AsyncError('ログインが必要です', StackTrace.current);
      return;
    }

    try {
      await client
          .from('onsen_plans')
          .update({'facility_ids': newFacilityIds})
          .eq('id', planId)
          .eq('user_id', userId);

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// プランを完全に削除する
  Future<void> deletePlan(String planId) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      state = AsyncError('ログインが必要です', StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    try {
      await client
          .from('onsen_plans')
          .delete()
          .eq('id', planId)
          .eq('user_id', userId);

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final planNotifierProvider =
    StateNotifierProvider<PlanNotifier, AsyncValue<void>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionProvider);
  return PlanNotifier(client, session?.user.id);
});
