// lib/ui/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Define theme mode enum
enum AppThemeMode { light, dark, system }

// Define language enum
enum AppLanguage { japanese, english }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // State variables for settings
  AppThemeMode _selectedThemeMode = AppThemeMode.system;
  double _fontSizeScale = 1.0;
  AppLanguage _selectedLanguage = AppLanguage.japanese;
  bool _highContrast = false;
  bool _reduceMotion = false;
  bool _screenReaderOptimized = false;
  
  // Notification settings
  bool _allowNotifications = true;
  bool _allowPromotional = false;
  bool _allowReminders = true;
  bool _allowWeeklySummary = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('テーマ'),
          _buildThemeSelection(),
          
          _buildSectionHeader('表示'),
          _buildFontSizeSlider(),
          _buildLanguageSelector(),
          
          _buildSectionHeader('アクセシビリティ'),
          _buildAccessibilityOptions(),
          
          _buildSectionHeader('通知'),
          _buildNotificationSettings(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildThemeSelection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'テーマ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            RadioListTile<AppThemeMode>(
              title: const Text('ライト'),
              value: AppThemeMode.light,
              groupValue: _selectedThemeMode,
              onChanged: (AppThemeMode? value) {
                setState(() {
                  _selectedThemeMode = value!;
                });
              },
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('ダーク'),
              value: AppThemeMode.dark,
              groupValue: _selectedThemeMode,
              onChanged: (AppThemeMode? value) {
                setState(() {
                  _selectedThemeMode = value!;
                });
              },
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('システムに合わせる'),
              value: AppThemeMode.system,
              groupValue: _selectedThemeMode,
              onChanged: (AppThemeMode? value) {
                setState(() {
                  _selectedThemeMode = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeSlider() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'フォントサイズ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('小'),
                Expanded(
                  child: Slider(
                    value: _fontSizeScale,
                    min: 0.85,
                    max: 1.3,
                    divisions: 9,
                    label: (_fontSizeScale).toStringAsFixed(2),
                    onChanged: (double value) {
                      setState(() {
                        _fontSizeScale = value;
                      });
                    },
                  ),
                ),
                const Text('大'),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'プレビュー: フォントサイズ調整のプレビューです',
                style: TextStyle(fontSize: 16 * _fontSizeScale),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '言語',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            RadioListTile<AppLanguage>(
              title: const Text('日本語'),
              value: AppLanguage.japanese,
              groupValue: _selectedLanguage,
              onChanged: (AppLanguage? value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
            ),
            RadioListTile<AppLanguage>(
              title: const Text('English'),
              value: AppLanguage.english,
              groupValue: _selectedLanguage,
              onChanged: (AppLanguage? value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityOptions() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'オプション',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('高コントラストモード'),
              value: _highContrast,
              onChanged: (bool value) {
                setState(() {
                  _highContrast = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('動きの軽減'),
              value: _reduceMotion,
              onChanged: (bool value) {
                setState(() {
                  _reduceMotion = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('画面読み上げ最適化'),
              value: _screenReaderOptimized,
              onChanged: (bool value) {
                setState(() {
                  _screenReaderOptimized = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '通知',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('通知を許可'),
              value: _allowNotifications,
              onChanged: (bool value) {
                setState(() {
                  _allowNotifications = value;
                });
              },
            ),
            Opacity(
              opacity: _allowNotifications ? 1.0 : 0.5,
              child: SwitchListTile(
                title: const Text('プロモーション通知'),
                subtitle: const Text('新機能やキャンペーン情報など'),
                value: _allowPromotional,
                onChanged: _allowNotifications 
                    ? (bool value) {
                        setState(() {
                          _allowPromotional = value;
                        });
                      }
                    : null,
              ),
            ),
            Opacity(
              opacity: _allowNotifications ? 1.0 : 0.5,
              child: SwitchListTile(
                title: const Text('リマインダー通知'),
                subtitle: const Text('お気に入りの施設に関する更新'),
                value: _allowReminders,
                onChanged: _allowNotifications 
                    ? (bool value) {
                        setState(() {
                          _allowReminders = value;
                        });
                      }
                    : null,
              ),
            ),
            Opacity(
              opacity: _allowNotifications ? 1.0 : 0.5,
              child: SwitchListTile(
                title: const Text('週間サマリー'),
                subtitle: const Text('今週の活動まとめ'),
                value: _allowWeeklySummary,
                onChanged: _allowNotifications 
                    ? (bool value) {
                        setState(() {
                          _allowWeeklySummary = value;
                        });
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}