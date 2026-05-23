// lib/domain/repositories/i_comment_repository.dart
import 'package:yu_map/core/result/result.dart';

abstract interface class ICommentRepository {
  Future<Result<List<Map<String, dynamic>>>> getCommentsByPost(String postId);
  Future<Result<Map<String, dynamic>>> createComment({
    required String postId,
    required String content,
  });
  Future<Result<void>> deleteComment(String commentId);
}
