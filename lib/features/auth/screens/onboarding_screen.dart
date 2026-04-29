// lib/features/auth/screens/onboarding_screen.dart
//
// 初回起動時のみ表示するオンボーディング画面（UX-V7-5対応）。
//
// 目的: 初めてアプリを開いたユーザーに「湯マップとは何か」を伝え、
//       登録・ゲスト閲覧のどちらかを選んでもらう。
//
// フロー:
//   初回起動 → オンボーディング画面（3枚スライド）
//   →「はじめる」→ LoginScreen
//   →「ゲストとして見る」→ ゲストモードで HomeShell
//
// 2回目以降:
//   flutter_secure_storage の 'onboarding_completed' フラグが true のため
//   _AuthGate でスキップして直接 LoginScreen / HomeShell を表示する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// オンボーディング完了フラグのストレージキー。
const _kOnboardingKey = 'onboarding_completed';

/// flutter_secure_storage のシングルトンインスタンス。
const _storage = FlutterSecureStorage();

/// オンボーディングが完了済みかどうかを確認する。
/// 完了済み = true を返す。
Future<bool> isOnboardingCompleted() async {
  final value = await _storage.read(key: _kOnboardingKey);
  return value == 'true';
}

/// オンボーディング完了をストレージに記録する。
Future<void> markOnboardingCompleted() async {
  await _storage.write(key: _kOnboardingKey, value: 'true');
}

// ── オンボーディングデータ ────────────────────────────────────────────────────

class _OnboardingPage {
  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.description,
    required this.backgroundColor,
  });

  final String emoji;
  final String title;
  final String description;
  final Color backgroundColor;
}

const _pages = [
  _OnboardingPage(
    emoji: '♨️',
    title: '全国の温泉・銭湯・サウナを地図で探せる',
    description: '現在地周辺の施設をマップ上に表示。\nマーカーをタップするだけで料金・営業時間・クチコミをすぐに確認できます。',
    backgroundColor: Color(0xFFFFF3E0),
  ),
  _OnboardingPage(
    emoji: '🏅',
    title: 'チェックインしてバッジを集めよう',
    description: '施設に行ったらチェックイン！\n温泉マスターや銭湯達人など、訪問数に応じたバッジが獲得できます。',
    backgroundColor: Color(0xFFE8F5E9),
  ),
  _OnboardingPage(
    emoji: '💬',
    title: 'クチコミで情報をシェアしよう',
    description: 'ひとこと感想や星評価を投稿して、\n他のユーザーのお風呂探しを助けましょう。',
    backgroundColor: Color(0xFFE3F2FD),
  ),
  // UX-V13-6: 湯めぐりプラン機能の紹介（アプリの差別化ポイント）
  _OnboardingPage(
    emoji: '🗺️',
    title: '湯めぐりプランを作ろう',
    description: '行きたい施設をまとめて「湯めぐりプラン」に登録。\n地図でルートを確認して、旅行の計画をスムーズに立てられます。',
    backgroundColor: Color(0xFFF3E5F5),
  ),
];

// ── メインウィジェット ────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 「はじめる」ボタン押下時: フラグを保存して LoginScreen へ遷移
  Future<void> _onGetStarted() async {
    await markOnboardingCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  // 「ゲストとして見る」ボタン押下時: フラグを保存してゲストモードで HomeShell へ
  Future<void> _onGuestMode() async {
    await markOnboardingCompleted();
    if (!mounted) return;
    ref.read(guestModeProvider.notifier).state = true;
    // guestModeProvider が true になれば _AuthGate が HomeShell を表示する
    // Navigator スタックを全てクリアしてアプリのルートに戻す
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// 最終ページへスキップ（スキップボタン押下時）。
  /// 最終ページにジャンプして「はじめる」「ゲストとして見る」を即座に選べる状態にする。
  void _onSkip() {
    // UX-V24-5: スキップ時も最終ページへ飛ぶので位置情報許可を事前リクエスト。
    _requestLocationPermissionIfNeeded();
    _controller.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  /// UX-V24-5: 最終ページ到達時に位置情報許可を事前リクエストする。
  ///
  /// 「この周辺の温泉を今すぐ探す」体験をスムーズにするため、
  /// 地図を開く前に許可をもらっておく。すでに許可済みの場合は何もしない。
  /// ユーザーが拒否しても正常に次へ進める（エラーを出さない）。
  Future<void> _requestLocationPermissionIfNeeded() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // 未決定 → ダイアログを表示してリクエスト
        await Geolocator.requestPermission();
      }
      // denied forever / granted / whileInUse はそのまま何もしない
    } catch (_) {
      // 位置情報が無効な環境では例外が出ることがある。
      // オンボーディングの進行をブロックしないため無視する。
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: page.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── スキップボタン（最終ページ以外で右上に表示） ───────────────
            SizedBox(
              height: 40,
              child: !isLastPage
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text(
                          'スキップ',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── ページコンテンツ ────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  // UX-V24-5: 最終ページに到達したとき位置情報許可を事前リクエスト。
                  // 地図画面を開く前に許可を取得しておくと「突然ダイアログが出る」感が消える。
                  if (index == _pages.length - 1) {
                    _requestLocationPermissionIfNeeded();
                  }
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final p = _pages[index];
                  return _OnboardingPageView(page: p);
                },
              ),
            ),

            // ── ページインジケーター ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? const Color(0xFF1565C0)
                          : Colors.grey[400],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // ── ボタンエリア ────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  // メインボタン
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: isLastPage
                          ? _onGetStarted
                          : () => _controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isLastPage ? 'はじめる（無料登録）' : '次へ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // UX-57: ゲストボタンは2ページ目以降のみ表示する。
                  // 1ページ目はアプリの価値（バッジ・プラン等）を見せてから
                  // ゲスト選択肢を提示することで早期離脱を抑制する。
                  if (_currentPage >= 1) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _onGuestMode,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'ゲストとして見る',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ゲストはお気に入り・クチコミ・チェックインを\nご利用いただけません',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 各スライドのコンテンツ ──────────────────────────────────────────────────────

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 絵文字アイコン
          Text(
            page.emoji,
            style: const TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 32),
          // タイトル
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.4,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 16),
          // 説明文
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
