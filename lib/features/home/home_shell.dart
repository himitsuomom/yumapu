import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/features/favorites/favorites_screen.dart';
import 'package:yu_map/features/map/screens/map_screen.dart';
import 'package:yu_map/features/profile/screens/profile_screen.dart';
import 'package:yu_map/features/ranking/screens/ranking_screen.dart';
import 'package:yu_map/features/search/screens/search_screen.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/providers/navigation_provider.dart';

/// Root shell for signed-in users.
///
/// Manages 5 tabs with [IndexedStack] so each tab retains its state across
/// switches. Favorites are loaded eagerly on first mount.
///
/// **タブ構成（G-1対応）**: 地図 / 検索 / ランキング / お気に入り / プロフィール
/// - ランキング（ゲーミフィケーション）をフィードより優先して2タップ不要で到達できるようにした。
/// - フィードは プロフィール画面 → 「みんなの投稿」カード から1タップで開ける。
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
  /// タブ構成: 0=地図 / 1=検索 / 2=ランキング / 3=お気に入り / 4=プロフィール
  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const MapScreen();
      case 1:
        return const SearchScreen();
      case 2:
        // G-1対応: ランキングをフィードの代わりにボトムナビに昇格。
        // フィードは /feed ルートまたはプロフィール画面からアクセス可能。
        return const RankingScreen();
      case 3:
        return const FavoritesScreen();
      case 4:
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
        children: List.generate(5, (index) {
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
            onTap: (index) {
              setState(() {
                _visitedIndices.add(index);
                _currentIndex = index;
              });
              // homeTabIndexProvider を同期してお気に入り→地図などの
              // 外部からのタブ切り替えと状態を一致させる
              ref.read(homeTabIndexProvider.notifier).state = index;
            },
            // 5タブ以上は type を fixed にしないとラベルが消える
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: '地図',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: '検索',
              ),
              // G-1対応: ランキングをフィードの代わりにタブに昇格。
              // ゲーミフィケーション機能を1タップで到達できる位置に置く。
              const BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard_outlined),
                activeIcon: Icon(Icons.leaderboard),
                label: 'ランキング',
              ),
              // UX-V7-6対応: ゲストモード時はロックバッジを表示して利用制限を事前に示す
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
