import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  // 現在のユーザー取得
  static User? get currentUser => _client.auth.currentUser;
  
  // ログイン状態の監視
  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ユーザープロファイル取得
  static Future<UserProfile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      
      return UserProfile.fromJson(response);
    } catch (e) {
      // プロファイルが存在しない場合はデフォルトを作成
      return UserProfile(
        name: user.email?.split('@')[0] ?? 'ユーザー',
        handle: '@${user.email?.split('@')[0] ?? 'user'}',
        bio: '',
        avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=${user.id}',
      );
    }
  }

  // メール・パスワードでログイン
  static Future<void> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.user == null) {
      throw Exception('ログインに失敗しました');
    }
  }

  // メール・パスワードで新規登録
  static Future<void> signUp(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    
    if (response.user == null) {
      throw Exception('新規登録に失敗しました');
    }
  }

  // ログアウト
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
