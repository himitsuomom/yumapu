import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/features/favorites/favorites_screen.dart';
import 'package:yu_map/features/feed/screens/feed_screen.dart';
import 'package:yu_map/features/map/screens/map_screen.dart';
import 'package:yu_map/features/profile/screens/profile_screen.dart';
import 'package:yu_map/features/search/screens/search_screen.dart';
import 'package:yu_map/providers/favorites_provider.dart';

/// Root shell for signed-in users.
///
/// Manages 5 tabs with [IndexedStack] so each tab retains its state across
/// switches. Favorites are loaded eagerly on first mount.
///
/// **遅延ロード方式**: タブを初めて訪問したときにのみ画面を生成する。
/// これにより MapScreen（Google Maps SDK）が起動直後にビルドされず、
/// Maps SDK の APIキー検証クラッシュをタップ時まで遅延できる。
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
  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const MapScreen();
      case 1:
        return const SearchScreen();
      case 2:
        return const FeedScreen();
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() {
          _visitedIndices.add(index); // 訪問済みとしてマーク
          _currentIndex = index;
        }),
        // 5タブ以上は type を fixed にしないとラベルが消える
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: '地図',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '検索',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed_outlined),
            activeIcon: Icon(Icons.dynamic_feed),
            label: 'フィード',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'お気に入り',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'プロフィール',
          ),
        ],
      ),
    );
  }
}
