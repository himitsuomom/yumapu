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
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  // All screens are kept alive via IndexedStack — no state is lost on tab switch.
  static const List<Widget> _screens = [
    MapScreen(),
    SearchScreen(),
    FeedScreen(),
    FavoritesScreen(),
    ProfileScreen(),
  ];

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
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
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
