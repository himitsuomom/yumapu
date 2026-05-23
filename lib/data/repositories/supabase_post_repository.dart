// lib/data/repositories/supabase_post_repository.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';
import 'package:yu_map/domain/repositories/i_post_repository.dart';
import 'package:yu_map/models/post.dart';

class SupabasePostRepository implements IPostRepository {
  SupabasePostRepository(this._client);
  final SupabaseClient _client;

  static const _pageSize = 20;

  @override
  Future<Result<List<Post>>> fetchFeed({
    String? facilityIdFilter,
    bool followingOnly = false,
    String? cursorCreatedAt,
    int offset = 0,
    int limit = _pageSize,
  }) =>
      runCatching(() async {
        final session = _client.auth.currentSession;

        // Following-only feed via RPC
        if (followingOnly && session != null) {
          final params = <String, dynamic>{
            'p_user_id': session.user.id,
            'p_limit': limit,
            if (cursorCreatedAt != null) 'p_cursor': cursorCreatedAt,
          };
          final rawData =
              await _client.rpc('get_following_posts', params: params);
          final dataList = List<Map<String, dynamic>>.from(
              (rawData as List)
                  .map((e) => Map<String, dynamic>.from(e as Map)));

          final postIds =
              dataList.map((e) => e['id'] as String).toList();
          Set<String> likedIds = {};
          if (postIds.isNotEmpty) {
            final likes = await _client
                .from('post_likes')
                .select('post_id')
                .eq('user_id', session.user.id)
                .inFilter('post_id', postIds);
            likedIds = (likes as List)
                .map((e) => e['post_id'] as String)
                .toSet();
          }

          return dataList.map((map) {
            final converted = Map<String, dynamic>.from(map);
            converted['users'] = {
              'display_name': converted.remove('display_name'),
              'username': converted.remove('username'),
              'avatar_url': converted.remove('avatar_url'),
            };
            return Post.fromJson(converted,
                isLiked: likedIds.contains(converted['id']));
          }).toList();
        }

        // Standard query
        var query = _client
            .from('posts')
            .select('*, users(display_name, username, avatar_url)');
        if (facilityIdFilter != null) {
          query = query.eq('facility_id', facilityIdFilter);
        }
        if (cursorCreatedAt != null) {
          query = query.lt('created_at', cursorCreatedAt);
        }

        final data = await query
            .order('created_at', ascending: false)
            .limit(limit);

        Set<String> likedIds = {};
        if (session != null) {
          final postIds =
              (data as List).map((e) => e['id'] as String).toList();
          if (postIds.isNotEmpty) {
            final likes = await _client
                .from('post_likes')
                .select('post_id')
                .eq('user_id', session.user.id)
                .inFilter('post_id', postIds);
            likedIds = (likes as List)
                .map((e) => e['post_id'] as String)
                .toSet();
          }
        }

        return (data as List).map((e) {
          final map = e as Map<String, dynamic>;
          return Post.fromJson(map, isLiked: likedIds.contains(map['id']));
        }).toList();
      });

  @override
  Future<Result<Post>> getPostById(String postId) => runCatching(() async {
        final session = _client.auth.currentSession;
        final row = await _client
            .from('posts')
            .select('*, users(display_name, username, avatar_url)')
            .eq('id', postId)
            .single();

        bool isLiked = false;
        if (session != null) {
          final like = await _client
              .from('post_likes')
              .select('post_id')
              .eq('user_id', session.user.id)
              .eq('post_id', postId)
              .maybeSingle();
          isLiked = like != null;
        }
        return Post.fromJson(row, isLiked: isLiked);
      });

  @override
  Future<Result<Post>> createPost({
    required String content,
    String? facilityId,
    List<File> images = const [],
  }) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();

        // Upload images if provided
        final imageUrls = <String>[];
        for (final image in images) {
          final url = await _uploadImage(image, session.user.id);
          imageUrls.add(url);
        }

        final firstImageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;

        final result = await _client
            .from('posts')
            .insert({
              'user_id': session.user.id,
              'content': content,
              if (facilityId != null) 'facility_id': facilityId,
              if (firstImageUrl != null && firstImageUrl.isNotEmpty)
                'image_url': firstImageUrl,
              if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
            })
            .select('*, users(display_name, username, avatar_url)')
            .single();

        return Post.fromJson(result);
      });

  @override
  Future<Result<void>> deletePost(String postId) => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();

        // Get post to check for images (both single and multi)
        final row = await _client
            .from('posts')
            .select('image_url, image_urls')
            .eq('id', postId)
            .eq('user_id', session.user.id)
            .maybeSingle();

        await _client
            .from('posts')
            .delete()
            .eq('id', postId)
            .eq('user_id', session.user.id);

        // Clean up all storage images
        if (row != null) {
          final urls = <String>[];
          final single = row['image_url'] as String?;
          if (single != null && single.isNotEmpty) urls.add(single);
          final multi =
              (row['image_urls'] as List?)?.whereType<String>().toList() ?? [];
          for (final u in multi) {
            if (!urls.contains(u)) urls.add(u);
          }
          for (final imageUrl in urls) {
            try {
              final uri = Uri.tryParse(imageUrl);
              if (uri != null) {
                final segments = uri.pathSegments;
                if (segments.length >= 2) {
                  final storagePath =
                      '${segments[segments.length - 2]}/${segments.last}';
                  await _client.storage
                      .from('post-images')
                      .remove([storagePath]);
                }
              }
            } catch (_) {
              // Storage deletion failure is non-fatal
            }
          }
        }
      });

  @override
  Future<Result<void>> likePost(String postId) => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client.from('post_likes').insert({
          'post_id': postId,
          'user_id': session.user.id,
        });
      });

  @override
  Future<Result<void>> unlikePost(String postId) => runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        await _client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', session.user.id);
      });

  @override
  Future<Result<Set<String>>> getLikedPostIds(List<String> postIds) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null || postIds.isEmpty) return <String>{};
        final likes = await _client
            .from('post_likes')
            .select('post_id')
            .eq('user_id', session.user.id)
            .inFilter('post_id', postIds);
        return (likes as List).map((e) => e['post_id'] as String).toSet();
      });

  @override
  Future<Result<List<String>>> uploadPostImages(List<File> images) =>
      runCatching(() async {
        final session = _client.auth.currentSession;
        if (session == null) throw const NotAuthenticatedException();
        final urls = <String>[];
        for (final image in images) {
          final url = await _uploadImage(image, session.user.id);
          urls.add(url);
        }
        return urls;
      });

  // ── Private helpers ───────────────────────────────────────────────────

  Future<String> _uploadImage(File image, String userId) async {
    final rawExt = image.path.split('.').last.toLowerCase();
    final safeExt =
        ['jpg', 'jpeg', 'png', 'webp'].contains(rawExt) ? rawExt : 'jpg';
    final fileName = '${const Uuid().v4()}.$safeExt';
    final storagePath = '$userId/$fileName';
    final bytes = await image.readAsBytes();
    await _client.storage.from('post-images').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$safeExt',
            upsert: false,
          ),
        );
    return _client.storage.from('post-images').getPublicUrl(storagePath);
  }
}
