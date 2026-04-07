import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yu_map/providers/app_state.dart';
import 'package:yu_map/screens/sign_up_screen.dart';
import 'package:yu_map/services/auth_service.dart';
import 'package:yu_map/widgets/hexagon_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// メールアドレスのバリデーション
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'メールアドレスを入力してください';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return '有効なメールアドレスを入力してください';
    }
    return null;
  }

  /// パスワードのバリデーション
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'パスワードを入力してください';
    }
    if (value.length < 6) {
      return 'パスワードは6文字以上で入力してください';
    }
    return null;
  }

  /// ログイン処理
  Future<void> _handleAuthenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      await AuthService.signIn(
        _emailController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ログインに成功しました！'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      if (mounted) {
        context.read<AppState>().loadFacilities();
        context.read<AppState>().loadPosts();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // gray-50相当
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ロゴセクション
                    _buildLogoSection(),
                    
                    const SizedBox(height: 40),
                    
                    // メールアドレス入力
                    _buildEmailField(),
                    
                    const SizedBox(height: 24),
                    
                    // パスワード入力
                    _buildPasswordField(),
                    
                    const SizedBox(height: 32),
                    
                    // 実行ボタン
                    _buildSubmitButton(),
                    
                    const SizedBox(height: 32),

                    // ソーシャルログインセクション
                    _buildSocialLoginSection(),
                    
                    const SizedBox(height: 32),
                    
                    // 切り替えボタン
                    _buildToggleButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ロゴセクションの構築
  Widget _buildLogoSection() {
    return Column(
      children: [
        const HexagonLogo(size: 100),
        const SizedBox(height: 24),
        const Text(
          'Yu-Map',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'アカウントにログインする',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// メールアドレス入力フィールドの構築
  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'メールアドレス',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
          decoration: const InputDecoration(
            hintText: 'example@mail.com',
            prefixIcon: Icon(Icons.mail_outline, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  /// パスワード入力フィールドの構築
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'パスワード',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          validator: _validatePassword,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 実行ボタンの構築
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleAuthenticate,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE57373),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE57373).withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'ログイン',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  /// 新規登録画面への切り替えボタン
  Widget _buildToggleButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'アカウントをお持ちでない方',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SignUpScreen()),
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            '新規登録はこちら',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE57373),
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFFE57373),
            ),
          ),
        ),
      ],
    );
  }

  /// ソーシャルログイン処理（Google / Apple）
  Future<void> _handleSocialLogin(String provider) async {
    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      if (provider == 'Google') {
        await AuthService.signInWithGoogle();
      } else if (provider == 'Apple') {
        await AuthService.signInWithApple();
      }
      // OAuth はブラウザ経由のリダイレクトで完了するため、
      // ここでは特にスナックバーを表示しない
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$providerログインエラー: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ソーシャルログインセクションの構築
  Widget _buildSocialLoginSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'または',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 24),
        _buildSocialButton(
          icon: _buildGoogleIcon(),
          label: 'Googleで続ける',
          onPressed: _isLoading ? null : () => _handleSocialLogin('Google'),
        ),
        const SizedBox(height: 12),
        _buildSocialButton(
          icon: _buildAppleIcon(),
          label: 'Appleで続ける',
          onPressed: _isLoading ? null : () => _handleSocialLogin('Apple'),
        ),
      ],
    );
  }

  /// Google公式アイコン（ネットワーク画像）
  Widget _buildGoogleIcon() {
    return Image.network(
      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        // ネットワークエラー時のフォールバック
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'G',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        );
      },
    );
  }

  /// Apple公式アイコン（ネットワーク画像）
  Widget _buildAppleIcon() {
    return Image.network(
      'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Apple_logo_black.svg/24px-Apple_logo_black.svg.png',
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        // ネットワークエラー時のフォールバック
        return const Icon(Icons.apple, color: Colors.black, size: 24);
      },
    );
  }

  /// 個別のソーシャルログインボタン構築
  Widget _buildSocialButton({
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
