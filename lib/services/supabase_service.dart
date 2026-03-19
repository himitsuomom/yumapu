// lib/services/supabase_service.dart
// lib/services/supabase_service.dart
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/models/facility.dart';
import 'package:yu_map/models/post.dart';
import 'package:yu_map/data/mock_data.dart';

/// Supabase データベースサービス
/// Supabase接続エラー時はモックデータにフォールバック
class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// 施設データ取得（エラー時はmockFacilitiesにフォールバック）
  static Future<List<Facility>> fetchFacilities() async {
    try {
      final response = await _client
          .from('facilities')
          .select()
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        developer.log('No facilities found in Supabase, using mock data');
        return mockFacilities;
      }

      return (response as List)
          .map((json) => Facility.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error fetching facilities from Supabase: $e');
      developer.log('Falling back to mock data');
      return mockFacilities;
    }
  }

  /// 投稿データ取得（エラー時はmockPostsにフォールバック）
  static Future<List<Post>> fetchPosts() async {
    try {
      final response = await _client
          .from('posts')
          .select('*, users(*), facilities(*)')
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        developer.log('No posts found in Supabase, using mock data');
        return mockPosts;
      }

      return (response as List<dynamic>)
          .map((json) => Post.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error fetching posts from Supabase: $e');
      developer.log('Falling back to mock data');
      return mockPosts;
    }
  }

  /// 投稿を作成
  static Future<Post?> createPost({
    required String userId,
    required String facilityId,
    required String content,
    required String facilityName,
    String? imageUrl,
  }) async {
    try {
      final response = await _client.from('posts').insert({
        'user_id': userId,
        'facility_id': facilityId,
        'content': content,
        'facility_name': facilityName,
        'image_url': imageUrl,
        'likes_count': 0,
        'is_liked': false,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (response.isNotEmpty) {
        return Post.fromJson(response.first);
      }
      return null;
    } catch (e) {
      developer.log('Error creating post: $e');
      return null;
    }
  }

  /// 投稿にいいね
  static Future<bool> likePost({
    required String postId,
    required String userId,
  }) async {
    try {
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      developer.log('Error liking post: $e');
      return false;
    }
  }

  /// 投稿のいいねを解除
  static Future<bool> unlikePost({
    required String postId,
    required String userId,
  }) async {
    try {
      await _client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      developer.log('Error unliking post: $e');
      return false;
    }
  }

  /// コメント追加
  static Future<bool> addComment({
    required String postId,
    required String userId,
    required String text,
    required String userName,
    required String userAvatar,
  }) async {
    try {
      await _client.from('comments').insert({
        'post_id': postId,
        'user_id': userId,
        'user_name': userName,
        'user_avatar': userAvatar,
        'text': text,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      developer.log('Error adding comment: $e');
      return false;
    }
  }

  /// 施設検索（名前で検索）
  static Future<List<Facility>> searchFacilities(String query) async {
    try {
      final response = await _client
          .from('facilities')
          .select()
          .ilike('name', '%$query%');

      if (response.isEmpty) {
        return [];
      }

      return (response as List<dynamic>)
          .map((json) => Facility.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error searching facilities: $e');
      // モックデータから検索
      return mockFacilities
          .where((f) => f.name.contains(query))
          .toList();
    }
  }

  /// 現在のユーザー取得
  static String? getCurrentUserId() {
    try {
      return _client.auth.currentUser?.id;
    } catch (e) {
      developer.log('Error getting current user: $e');
      return null;
    }
  }

  /// ユーザーがログイン中かチェック
  static bool isUserLoggedIn() {
    try {
      return _client.auth.currentUser != null;
    } catch (e) {
      developer.log('Error checking user login status: $e');
      return false;
    }
  }

  /// いいね機能：状態を切り替え
  static Future<void> toggleLike(String postId, bool currentState) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('ログインが必要です');

    try {
      if (currentState) {
        // いいねを削除
        await _client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        developer.log('Like removed for post: $postId');
      } else {
        // いいねを追加
        await _client.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        developer.log('Like added for post: $postId');
      }
    } catch (e) {
      developer.log('Error toggling like: $e');
      rethrow;
    }
  }

  /// お気に入り機能：状態を切り替え
  static Future<void> toggleFavorite(String facilityId, bool currentState) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('ログインが必要です');

    try {
      if (currentState) {
        // お気に入りを削除
        await _client
            .from('favorites')
            .delete()
            .eq('facility_id', facilityId)
            .eq('user_id', userId);
        developer.log('Favorite removed for facility: $facilityId');
      } else {
        // お気に入りを追加
        await _client.from('favorites').insert({
          'facility_id': facilityId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        developer.log('Favorite added for facility: $facilityId');
      }
    } catch (e) {
      developer.log('Error toggling favorite: $e');
      rethrow;
    }
  }

  /// お気に入り一覧取得
  static Future<List<Facility>> fetchFavorites() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('favorites')
          .select('facilities(*)')
          .eq('user_id', userId);

      if (response.isEmpty) {
        developer.log('No favorites found for user: $userId');
        return [];
      }

      return (response as List<dynamic>)
          .map((item) {
            final facilityData = item['facilities'] as Map<String, dynamic>;
            return Facility.fromJson(facilityData);
          })
          .toList();
    } catch (e) {
      developer.log('Error fetching favorites: $e');
      return [];
    }
  }
}
