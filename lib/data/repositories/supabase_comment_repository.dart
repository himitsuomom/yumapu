// lib/data/repositories/supabase_comment_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';
import 'package:yu_map/domain/repositories/i_comment_repository.dart';

class SupabaseCommentRepository implements ICommentRepository {
  SupabaseCommentRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Result<List<Map<String, dynamic>>>> getCommentsByPost(
          String postId) =>
      runCatching(() async {
        final data = await _client
            .from('comments')
            .select()
            .eq('post_id', postId)
            .order('created_at', ascending: true);
        return (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });

  @override
  Future<Result<Map<String, dynamic>>> createComment({
    required String postId,
    required String content,
  }) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();

        // Fetch user profile for denormalized name/avatar
        final profile = await _client
            .from('users')
            .select('display_name, username, avatar_url')
            .eq('id', session.user.id)
            .maybeSingle();
        final userName = profile?['display_name'] as String? ??
            profile?['username'] as String? ??
            '匿名ユーザー';
        final userAvatar = profile?['avatar_url'] as String? ?? '';

        final trimmed = content.trim();
        final result = await _client
            .from('comments')
            .insert({
              'post_id': postId,
              'user_id': session.user.id,
              'user_name': userName,
              'user_avatar': userAvatar,
              'text': trimmed,
            })
            .select()
            .single();
        return Map<String, dynamic>.from(result as Map);
      });

  @override
  Future<Result<void>> deleteComment(String commentId) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client
            .from('comments')
            .delete()
            .eq('id', commentId)
            .eq('user_id', session.user.id);
      });
}
