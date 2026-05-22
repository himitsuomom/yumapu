// lib/data/repositories/supabase_plan_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';
import 'package:yu_map/domain/repositories/i_plan_repository.dart';
import 'package:yu_map/models/onsen_plan.dart';

class SupabasePlanRepository implements IPlanRepository {
  SupabasePlanRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Result<List<OnsenPlan>>> getPlans() => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) return <OnsenPlan>[];
        final data = await _client
            .from('onsen_plans')
            .select()
            .eq('user_id', session.user.id)
            .order('updated_at', ascending: false);
        return (data as List)
            .map((e) => OnsenPlan.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<Result<OnsenPlan>> createPlan({
    required String name,
    required String description,
    required List<String> facilityIds,
  }) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        final data = await _client
            .from('onsen_plans')
            .insert({
              'user_id': session.user.id,
              'title': name,
              if (description.isNotEmpty) 'description': description,
              'is_public': false,
              'facility_ids': facilityIds,
            })
            .select()
            .single();
        return OnsenPlan.fromJson(data);
      });

  @override
  Future<Result<void>> updatePlan(
    String planId, {
    String? name,
    String? description,
    List<String>? facilityIds,
  }) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        final patch = <String, dynamic>{};
        if (name != null) patch['title'] = name;
        if (description != null) patch['description'] = description;
        if (facilityIds != null) patch['facility_ids'] = facilityIds;
        if (patch.isEmpty) return;
        await _client
            .from('onsen_plans')
            .update(patch)
            .eq('id', planId)
            .eq('user_id', session.user.id);
      });

  @override
  Future<Result<void>> deletePlan(String planId) => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client
            .from('onsen_plans')
            .delete()
            .eq('id', planId)
            .eq('user_id', session.user.id);
      });
}
