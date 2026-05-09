// lib/providers/badge_provider.dart
//
// バッジ機能のデータ管理
// user_badges テーブルと badges テーブルを JOIN して取得する

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/models/badge.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// 自分が獲得したバッジ一覧（取得日時降順）
///
/// Bug-55 修正: catch(_){return [];} を廃止し、エラーを rethrow する。
/// BadgeScreen の .when(error:...) でリトライUIが表示できるようになる。
final myBadgesProvider =
    FutureProvider.autoDispose<List<UserBadge>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final client = ref.read(supabaseClientProvider);
  if (client == null) return [];
  final data = await client
      .from('user_badges')
      .select('*, badges(*)')
      .eq('user_id', session.user.id)
      .order('earned_at', ascending: false);
  return (data as List)
      .map((e) => UserBadge.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// 全バッジ定義一覧（カテゴリ・名前順）
/// 未獲得バッジも含めて表示する場合に使用する
///
/// Bug-55 修正: エラーを rethrow して AsyncError として伝播させる。
final allBadgesProvider =
    FutureProvider.autoDispose<List<AppBadge>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  if (client == null) return [];
  final data = await client
      .from('badges')
      .select()
      .order('category')
      .order('name_ja');
  return (data as List)
      .map((e) => AppBadge.fromJson(e as Map<String, dynamic>))
      .toList();
});
