import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/navigation/app_navigator.dart';
import 'package:yu_map/core/widgets/guest_restriction_dialog.dart';
import 'package:yu_map/features/explore/screens/explore_screen.dart';
import 'package:yu_map/features/favorites/favorites_screen.dart';
import 'package:yu_map/features/feed/screens/feed_screen.dart';
import 'package:yu_map/features/profile/screens/profile_screen.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/navigation_provider.dart';

/// Root shell for signed-in users.
///
/// Manages 4 tabs with [IndexedStack] so each tab retains its state across
/// switches. Favorites are loaded eagerly on first mount.
///
/// **タブ構成（#9統合）**: 探す(Explore) / ホーム / お気に入り / プロフィール
/// - 地図タブと検索タブを [ExploreScreen] に統合（#9 Phase A）。
/// - ExploreScreen: 地図全画面 + DraggableScrollableSheet で施設リスト表示。
///
/// **遅延ロード方式**: タブを初めて訪問したときにのみ画面を生成する。
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // マップタブ（index=0）をデフォルトにする。
  // OpenStreetMap に移行済みのため APIキー不要・クラッシュリスクなし。
  int _currentIndex = 0;

  // 訪問済みのタブ番号を記録する。
  // IndexedStack の子として SizedBox.shrink() を置いておき、
  // 初めて訪問したタイミングで実際の画面ウィジェットに差し替える。
  final Set<int> _visitedIndices = {0};

  /// タブ番号に対応する画面ウィジェットを返す。
  ///
  /// タブ構成: 0=探す(Explore) / 1=ホーム（フィード） / 2=お気に入り / 3=プロフィール
  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        // #9統合: 地図+検索を ExploreScreen に統合。
        return const ExploreScreen();
      case 1:
        return const FeedScreen();
      case 2:
        return const FavoritesScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void initState() {
    super.initState();
    // Eagerly fetch favorites so the icon badge and list are ready immediately.
    Future.microtask(() {
      if (mounted) ref.read(favoritesProvider.notifier).load();
    });
    // Bug-57修正: 通知サービスからのタブ切り替えリクエストを監視する。
    // notification_service.dart が pendingTabSwitch.value を更新すると
    // HomeShell が即座にタブを切り替え、BottomNavigationBar とも同期する。
    pendingTabSwitch.addListener(_onPendingTabSwitch);
  }

  @override
  void dispose() {
    pendingTabSwitch.removeListener(_onPendingTabSwitch);
    super.dispose();
  }

  /// [pendingTabSwitch] に値がセットされたときにタブを切り替える。
  ///
  /// 処理後に null へリセットして二重実行を防ぐ。
  void _onPendingTabSwitch() {
    final index = pendingTabSwitch.value;
    if (index == null) return;
    pendingTabSwitch.value = null; // リセット（二重処理防止）
    if (!mounted) return;
    setState(() {
      _visitedIndices.add(index);
      _currentIndex = index;
    });
    ref.read(homeTabIndexProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    // homeTabIndexProvider が外部（お気に入り画面など）から更新されたら
    // ボトムナビのタブを自動的に切り替える。
    // listen のみで state 変化時に setState を呼ぶことで IndexedStack も更新される。
    ref.listen<int>(homeTabIndexProvider, (previous, next) {
      if (next != _currentIndex) {
        setState(() {
          _visitedIndices.add(next);
          _currentIndex = next;
        });
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        // 訪問済みのタブだけ実際の画面を生成し、未訪問は空ウィジェットにする
        children: List.generate(4, (index) {
          if (!_visitedIndices.contains(index)) {
            return const SizedBox.shrink();
          }
          return _buildScreen(index);
        }),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final isGuestMode = ref.watch(guestModeProvider);
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) async {
              // ゲストモード時: お気に入り(2)・プロフィール(3) はモーダルで案内する
              if (isGuestMode && (index == 2 || index == 3)) {
                final tabName = index == 2 ? 'お気に入り' : 'プロフィール';
                final goLogin = await GuestRestrictionDialog.show(
                  context,
                  featureName: tabName,
                );
                if (goLogin == true && context.mounted) {
                  Navigator.of(context).pushNamed('/login');
                }
                return; // タブは切り替えない
              }
              setState(() {
                _visitedIndices.add(index);
                _currentIndex = index;
              });
              // homeTabIndexProvider を同期してお気に入り→地図などの
              // 外部からのタブ切り替えと状態を一致させる
              ref.read(homeTabIndexProvider.notifier).state = index;
            },
            // #9統合: 4タブ構成。type=fixed でラベルを常時表示。
            type: BottomNavigationBarType.fixed,
            items: [
              // 0: 探す（地図+検索統合）
              const BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: '探す',
              ),
              // 1: ホーム（フィード）
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'ホーム',
              ),
              // 2: お気に入り（ゲストモード時はロックバッジ）
              BottomNavigationBarItem(
                icon: _GuestLockIcon(
                  icon: Icons.favorite_border,
                  isLocked: isGuestMode,
                ),
                activeIcon: _GuestLockIcon(
                  icon: Icons.favorite,
                  isLocked: isGuestMode,
                ),
                label: 'お気に入り',
              ),
              // 3: プロフィール（ゲストモード時はロックバッジ）
              BottomNavigationBarItem(
                icon: _GuestLockIcon(
                  icon: Icons.person_outline,
                  isLocked: isGuestMode,
                ),
                activeIcon: _GuestLockIcon(
                  icon: Icons.person,
                  isLocked: isGuestMode,
                ),
                label: 'プロフィール',
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── ゲストモード用ロックバッジアイコン ──────────────────────────────────────────

/// ゲストモード時にアイコン右上に小さなロックアイコンを重ねて表示する。
/// [isLocked] が false の場合は通常アイコンをそのまま返す。
class _GuestLockIcon extends StatelessWidget {
  const _GuestLockIcon({
    required this.icon,
    required this.isLocked,
  });

  final IconData icon;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    if (!isLocked) {
      return Icon(icon);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        // 右上の小さなロックアイコン（ゲスト制限インジケーター）
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey[500],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock,
              size: 8,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
