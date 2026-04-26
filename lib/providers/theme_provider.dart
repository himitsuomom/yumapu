// lib/providers/theme_provider.dart
//
// テーマモード（ライト/ダーク/システム）の状態管理プロバイダー。
// flutter_secure_storage でユーザーの選択を永続化する。
// D-2対応: 設定画面でテーマを切り替えられるようにする。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kThemeModeKey = 'theme_mode';

/// ThemeMode の文字列 ↔ 列挙型 変換
ThemeMode _themeModeFromString(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String _themeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

/// テーマモードの状態を管理する Notifier。
///
/// 初期値は ThemeMode.system（OS設定に追従）。
/// [setThemeMode] で変更すると flutter_secure_storage にも書き込む。
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();

  @override
  ThemeMode build() {
    // 初期値は system。非同期でストレージから読み込む。
    _loadThemeMode();
    return ThemeMode.system;
  }

  Future<void> _loadThemeMode() async {
    final stored = await _storage.read(key: _kThemeModeKey);
    if (stored != null) {
      state = _themeModeFromString(stored);
    }
  }

  /// テーマモードを変更してストレージに保存する。
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _kThemeModeKey, value: _themeModeToString(mode));
  }
}

/// アプリ全体で使うテーマモードプロバイダー。
///
/// `ref.watch(themeModeProvider)` で ThemeMode を取得できる。
/// `ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark)` で変更。
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
