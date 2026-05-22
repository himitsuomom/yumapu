// lib/domain/repositories/i_post_repository.dart
import 'dart:io';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/models/post.dart';

abstract interface class IPostRepository {
  Future<Result<List<Post>>> fetchFeed({
    String? facilityIdFilter,
    bool followingOnly = false,
    String? cursorCreatedAt,
    int offset = 0,
    int limit = 20,
  });
  Future<Result<Post>> getPostById(String postId);
  Future<Result<Post>> createPost({
    required String content,
    String? facilityId,
    List<File> images = const [],
  });
  Future<Result<void>> deletePost(String postId);
  Future<Result<void>> likePost(String postId);
  Future<Result<void>> unlikePost(String postId);
  Future<Result<Set<String>>> getLikedPostIds(List<String> postIds);
  Future<Result<List<String>>> uploadPostImages(List<File> images);
}
