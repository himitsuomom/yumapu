// lib/services/supabase_service.dart
import 'dart:developer' as developer;
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/models/post.dart';
import 'package:yu_map/models/badge.dart';
import 'package:yu_map/models/user_ranking.dart';

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
        developer.log('No facilities found in Supabase');
        return [];
      }

      return (response as List)
          .map((json) => Facility.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error fetching facilities from Supabase: $e');
      return [];
    }
  }

  /// 投稿データ取得
  ///
  /// 投稿一覧と同時に、ログイン中ユーザーがいいねしている投稿IDも取得して
  /// [Post.isLiked] を正しく設定する。
  static Future<List<Post>> fetchPosts() async {
    try {
      // 投稿をユーザー情報つきで取得
      final response = await _client
          .from('posts')
          .select('*, users(display_name, username, avatar_url)')
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        developer.log('No posts found in Supabase');
        return [];
      }

      // ログイン中ユーザーがいいねしている投稿IDを取得
      final Set<String> likedIds = await _fetchLikedPostIds();

      return (response as List<dynamic>).map((json) {
        final postId = (json as Map<String, dynamic>)['id'] as String? ?? '';
        return Post.fromJson(json, isLiked: likedIds.contains(postId));
      }).toList();
    } catch (e) {
      developer.log('Error fetching posts from Supabase: $e');
      return [];
    }
  }

  /// ログイン中ユーザーがいいねした投稿IDのセットを返す
  static Future<Set<String>> _fetchLikedPostIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final rows = await _client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', userId) as List;
      return rows.map((r) => r['post_id'] as String).toSet();
    } catch (_) {
      return {};
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
      // likes_count はDB側デフォルト値(0)のため送らない
      // is_liked はDBカラムではなくクライアント側の状態のため送らない
      final response = await _client.from('posts').insert({
        'user_id': userId,
        'facility_id': facilityId,
        'content': content,
        'facility_name': facilityName,
        if (imageUrl != null) 'image_url': imageUrl,
      }).select('*, users(display_name, username, avatar_url)');

      if (response.isNotEmpty) {
        // 新規投稿は自分の投稿なのでisLiked=false確定
        return Post.fromJson(response.first as Map<String, dynamic>,
            isLiked: false);
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

  /// 表示範囲内の施設を取得（ビューポートクエリ）
  /// [swLat/swLng] 南西端、[neLat/neLng] 北東端
  static Future<List<Facility>> fetchFacilitiesInBounds({
    required double swLat,
    required double swLng,
    required double neLat,
    required double neLng,
  }) async {
    try {
      final response = await _client
          .from('facilities')
          .select()
          .gte('latitude', swLat)
          .lte('latitude', neLat)
          .gte('longitude', swLng)
          .lte('longitude', neLng);

      return (response as List<dynamic>)
          .map((json) => Facility.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error fetching facilities in bounds: $e');
      return [];
    }
  }

  /// 施設検索（名前 + 住所で検索）
  static Future<List<Facility>> searchFacilities(String query) async {
    try {
      final response = await _client
          .from('facilities')
          .select()
          .or('name.ilike.%$query%,address.ilike.%$query%');

      if (response.isEmpty) {
        return [];
      }

      return (response as List<dynamic>)
          .map((json) => Facility.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error searching facilities: $e');
      return [];
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

  // ===== 画像アップロード =====

  /// 画像ファイルをSupabase Storageにアップロードして公開URLを返す
  /// [imageFile] アップロードする画像ファイル
  /// 戻り値: 公開URL（失敗時は null）
  static Future<String?> uploadPostImage(File imageFile) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final ext = imageFile.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = '$userId/$fileName';

      await _client.storage.from('post-images').upload(
        storagePath,
        imageFile,
        fileOptions: FileOptions(
          contentType: _mimeType(ext),
          upsert: false,
        ),
      );

      final publicUrl =
          _client.storage.from('post-images').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      developer.log('Error uploading image: $e');
      return null;
    }
  }

  static String _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  // ===== ランキング関連 =====

  /// 自分のランキング情報を取得（なければ初期レコードを作成）
  static Future<UserRanking?> fetchMyRanking() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('user_rankings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // 初回はレコードを作成
        final inserted = await _client
            .from('user_rankings')
            .insert({'user_id': userId})
            .select()
            .single();
        return UserRanking.fromJson(inserted);
      }
      return UserRanking.fromJson(response);
    } catch (e) {
      developer.log('Error fetching ranking: $e');
      return null;
    }
  }

  /// ランキング上位ユーザー一覧取得
  static Future<List<RankingEntry>> fetchTopRankings({int limit = 50}) async {
    try {
      final response = await _client
          .from('user_rankings')
          .select('*, users(display_name, username, avatar_url)')
          .order('total_points', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .asMap()
          .entries
          .map((entry) {
            final json = Map<String, dynamic>.from(
                entry.value as Map<String, dynamic>);
            // rank_positionがnullの場合は順位を補完
            json['rank_position'] ??= entry.key + 1;
            return RankingEntry.fromJson(json);
          })
          .toList();
    } catch (e) {
      developer.log('Error fetching rankings: $e');
      return [];
    }
  }

  /// 施設にチェックイン（1日1回まで）
  /// 戻り値: チェックインできたか（重複の場合はfalse）
  static Future<bool> checkIn(String facilityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('ログインが必要です');

    try {
      // 既に今日チェックイン済みか確認（UTC基準で統一）
      final now = DateTime.now().toUtc();
      final todayStart = DateTime.utc(now.year, now.month, now.day)
          .toIso8601String();
      final tomorrowStart =
          DateTime.utc(now.year, now.month, now.day + 1).toIso8601String();

      final existing = await _client
          .from('visits')
          .select()
          .eq('user_id', userId)
          .eq('facility_id', facilityId)
          .gte('visited_at', todayStart)
          .lt('visited_at', tomorrowStart)
          .maybeSingle();

      if (existing != null) {
        return false; // 今日すでにチェックイン済み
      }

      // チェックイン記録を追加
      await _client.from('visits').insert({
        'user_id': userId,
        'facility_id': facilityId,
        'visited_at': DateTime.now().toIso8601String(),
      });

      // ランキングのポイントを更新
      await _addExplorerPoints(userId, 100);

      return true;
    } catch (e) {
      developer.log('Error checking in: $e');
      rethrow;
    }
  }

  /// 探索ポイントを加算
  static Future<void> _addExplorerPoints(String userId, int points) async {
    try {
      // user_rankingsが存在するか確認
      final existing = await _client
          .from('user_rankings')
          .select('explorer_points, visit_count, current_title, total_points')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        await _client.from('user_rankings').insert({
          'user_id': userId,
          'explorer_points': points,
          'visit_count': 1,
          'current_title': UserRanking.titleFromPoints(points),
        });
      } else {
        final newExplorer =
            ((existing['explorer_points'] as num?)?.toInt() ?? 0) + points;
        final newVisitCount =
            ((existing['visit_count'] as num?)?.toInt() ?? 0) + 1;
        await _client.from('user_rankings').update({
          'explorer_points': newExplorer,
          'visit_count': newVisitCount,
          'current_title': UserRanking.titleFromPoints(
            newExplorer +
                ((existing['total_points'] as num?)?.toInt() ?? 0) -
                ((existing['explorer_points'] as num?)?.toInt() ?? 0),
          ),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);
        // total_pointsはDB側の生成列なので直接更新不要（newTotal未使用）
      }
    } catch (e) {
      developer.log('Error adding explorer points: $e');
    }
  }

  /// ソーシャルポイントを加算（投稿・いいね獲得時）
  static Future<void> addSocialPoints(String userId, int points,
      {bool isReview = false}) async {
    try {
      final existing = await _client
          .from('user_rankings')
          .select('social_points, review_count, current_title, explorer_points')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        await _client.from('user_rankings').insert({
          'user_id': userId,
          'social_points': points,
          'review_count': isReview ? 1 : 0,
          'current_title': UserRanking.titleFromPoints(points),
        });
      } else {
        final newSocial =
            ((existing['social_points'] as num?)?.toInt() ?? 0) + points;
        final newReviewCount = isReview
            ? ((existing['review_count'] as num?)?.toInt() ?? 0) + 1
            : ((existing['review_count'] as num?)?.toInt() ?? 0);
        final explorerPts =
            (existing['explorer_points'] as num?)?.toInt() ?? 0;
        await _client.from('user_rankings').update({
          'social_points': newSocial,
          'review_count': newReviewCount,
          'current_title':
              UserRanking.titleFromPoints(explorerPts + newSocial),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);
      }
    } catch (e) {
      developer.log('Error adding social points: $e');
    }
  }

  // ===== バッジ関連 =====

  /// ユーザーの獲得済みバッジ一覧を取得
  static Future<List<UserBadge>> fetchMyBadges() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('user_badges')
          .select('*, badges(*)')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => UserBadge.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error fetching badges: $e');
      return [];
    }
  }

  /// 全バッジ定義を取得（表示目的のみ）
  static Future<List<Badge>> fetchAllBadges() async {
    try {
      final response = await _client
          .from('badges')
          .select()
          .order('category', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Badge.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error fetching all badges: $e');
      return [];
    }
  }

  /// DB の check_and_grant_badges RPC を呼び出してバッジを付与する。
  ///
  /// バッジ付与ロジックはすべて DB 側（check_and_grant_badges 関数）で管理。
  /// 通常のチェックイン後は visits INSERT トリガーで自動実行されるため、
  /// アプリ側から手動で再チェックしたい場合（例: 初回起動時）にのみ呼ぶ。
  ///
  /// 戻り値: 新たに付与されたバッジの code 一覧
  static Future<List<String>> checkAndAwardBadges() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final result = await _client.rpc(
        'check_and_grant_badges',
        params: {'p_user_id': userId},
      );
      if (result == null) return [];
      return (result as List<dynamic>).map((e) => e as String).toList();
    } catch (e) {
      developer.log('Error checking badges via RPC: $e');
      return [];
    }
  }

  // ===== 問い合わせ関連 =====

  /// 問い合わせをSupabaseの inquiries テーブルに送信する
  /// [type]     'hours_change'（営業時間変更報告）または 'add_facility'（未登録施設追加申請）
  /// [facilityName] 施設名（文字列）
  /// [message]  問い合わせ本文
  /// [contact]  連絡先メールアドレス（任意）
  /// 戻り値: 成功した場合 true、エラー時 false
  static Future<bool> submitInquiry({
    required String type,
    required String facilityName,
    required String message,
    String? contact,
  }) async {
    try {
      await _client.from('inquiries').insert({
        'type': type,
        'facility_name': facilityName,
        'message': message,
        'contact': contact,
        'user_id': _client.auth.currentUser?.id,
        'created_at': DateTime.now().toIso8601String(),
      });
      developer.log('Inquiry submitted: $type');
      return true;
    } catch (e) {
      developer.log('Error submitting inquiry: $e');
      return false;
    }
  }

  // ===== お気に入り関連 =====

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
