// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/gen_l10n/app_localizations.dart';
import 'package:yu_map/screens/auth_screen.dart';
import 'package:yu_map/screens/main_screen.dart';
import 'package:yu_map/services/auth_service.dart';
import 'package:yu_map/providers/app_state.dart';

class YuMapApp extends StatelessWidget {
  const YuMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yu-Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // ロゴの赤系色調に合わせたテーマ設定
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE57373), // ロゴの赤系色
          primary: const Color(0xFFE57373),
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE57373), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
      ),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StreamBuilder<AuthState>(
        stream: AuthService.authStateChanges,
        builder: (context, snapshot) {
          // ローディング状態
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // 認証状態をチェック
          if (snapshot.hasData && snapshot.data?.session != null) {
            // ログイン済み：メイン画面を表示
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.read<AppState>().loadUserProfile();
              }
            });
            return const MainScreen();
          } else {
            // 未ログイン：ログイン画面を表示
            return const AuthScreen();
          }
        },
      ),
    );
  }
}
