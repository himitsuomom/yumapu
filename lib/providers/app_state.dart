import 'package:flutter/foundation.dart';
import '../models/facility.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../data/mock_data.dart';

class AppState extends ChangeNotifier {
  // 状態変数
  List<Facility> _facilities = mockFacilities;
  List<Post> _posts = mockPosts;
  List<Facility> _favoriteFacilities = [];
  Set<String> _favoriteFacilityIds = {};
  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Facility> get facilities => _facilities;
  List<Post> get posts => _posts;
  List<Facility> get favoriteFacilities => _favoriteFacilities;
  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 施設がお気に入りかチェック
  bool isFavorite(String facilityId) => _favoriteFacilityIds.contains(facilityId);

  // 施設データ読み込み
  Future<void> loadFacilities() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _facilities = await SupabaseService.fetchFacilities();
    } catch (e) {
      _errorMessage = 'データの読み込みに失敗しました';
      _facilities = mockFacilities; // 安全なフォールバック
    }

    _isLoading = false;
    notifyListeners();
  }

  // 投稿データ読み込み
  Future<void> loadPosts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _posts = await SupabaseService.fetchPosts();
    } catch (e) {
      _errorMessage = 'データの読み込みに失敗しました';
      _posts = mockPosts; // 安全なフォールバック
    }

    _isLoading = false;
    notifyListeners();
  }

  // エラーメッセージをクリア
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ユーザープロファイル読み込み
  Future<void> loadUserProfile() async {
    try {
      _currentUser = await AuthService.getCurrentProfile();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'ユーザー情報の読み込みに失敗しました';
      notifyListeners();
    }
  }

  // ログアウト
  Future<void> signOut() async {
    try {
      await AuthService.signOut();
      _currentUser = null;
      _favoriteFacilities = [];
      _favoriteFacilityIds = {};
      notifyListeners();
    } catch (e) {
      _errorMessage = 'ログアウトに失敗しました';
      notifyListeners();
    }
  }

  /// いいね切り替え（楽観的UI更新）
  Future<void> togglePostLike(String postId) async {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = _posts[postIndex];
    final previousState = post.isLiked;
    final previousCount = post.likes;

    // 即座にUI更新
    post.isLiked = !post.isLiked;
    post.likes += post.isLiked ? 1 : -1;
    notifyListeners();

    try {
      await SupabaseService.toggleLike(postId, previousState);
    } catch (e) {
      // エラー時は元に戻す
      post.isLiked = previousState;
      post.likes = previousCount;
      _errorMessage = 'いいねに失敗しました';
      notifyListeners();
    }
  }

  /// お気に入り読み込み
  Future<void> loadFavorites() async {
    try {
      _favoriteFacilities = await SupabaseService.fetchFavorites();
      _favoriteFacilityIds = _favoriteFacilities.map((f) => f.id).toSet();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'お気に入りの読み込みに失敗しました';
      notifyListeners();
    }
  }

  /// お気に入り切り替え（楽観的UI更新）
  Future<void> toggleFacilityFavorite(String facilityId) async {
    final previousState = _favoriteFacilityIds.contains(facilityId);

    // 楽観的UI更新
    if (previousState) {
      _favoriteFacilityIds.remove(facilityId);
      _favoriteFacilities.removeWhere((f) => f.id == facilityId);
    } else {
      _favoriteFacilityIds.add(facilityId);
      final facility = _facilities.firstWhere((f) => f.id == facilityId);
      _favoriteFacilities.add(facility);
    }
    notifyListeners();

    try {
      await SupabaseService.toggleFavorite(facilityId, previousState);
    } catch (e) {
      // エラー時は元に戻す
      if (previousState) {
        _favoriteFacilityIds.add(facilityId);
        final facility = _facilities.firstWhere((f) => f.id == facilityId);
        _favoriteFacilities.add(facility);
      } else {
        _favoriteFacilityIds.remove(facilityId);
        _favoriteFacilities.removeWhere((f) => f.id == facilityId);
      }
      _errorMessage = 'お気に入りの更新に失敗しました';
      notifyListeners();
    }
  }

  /// 投稿を作成
  Future<bool> createPost({
    required String facilityId,
    required String content,
    required String facilityName,
    String? imageUrl,
  }) async {
    final userId = SupabaseService.getCurrentUserId();
    if (userId == null) {
      _errorMessage = 'ログインが必要です';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newPost = await SupabaseService.createPost(
        userId: userId,
        facilityId: facilityId,
        content: content,
        facilityName: facilityName,
        imageUrl: imageUrl,
      );

      if (newPost != null) {
        _posts.insert(0, newPost);
        notifyListeners();
        _isLoading = false;
        return true;
      } else {
        _errorMessage = '投稿作成に失敗しました';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = '投稿作成に失敗しました: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
