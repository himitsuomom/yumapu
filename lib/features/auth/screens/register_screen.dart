import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'メールアドレスを入力してください';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) return '正しいメールアドレスを入力してください';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'パスワードを入力してください';
    if (value.length < 6) return 'パスワードは6文字以上で入力してください';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return '確認用パスワードを入力してください';
    if (value != _passwordController.text) return 'パスワードが一致しません';
    return null;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _register() async {
    if (!AppConfig.isSupabaseConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('認証サービスが設定されていません'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref.read(authNotifierProvider.notifier).signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    authState.when(
      data: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('確認メールを送信しました。メールをご確認ください。'),
          ),
        );
        Navigator.of(context).pop();
      },
      loading: () {},
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AsyncLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'アカウントを作成',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'メールアドレスとパスワードを入力してください',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF757575),
                      ),
                ),
                const SizedBox(height: 32),
                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    labelText: 'パスワード（6文字以上）',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  enabled: !isLoading,
                  onFieldSubmitted: (_) => _register(),
                  decoration: InputDecoration(
                    labelText: 'パスワード（確認）',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 32),
                // Register button
                ElevatedButton(
                  onPressed: isLoading ? null : _register,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('アカウントを作成'),
                ),
                const SizedBox(height: 16),
                // Back to login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('すでにアカウントをお持ちの方'),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('ログイン'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
