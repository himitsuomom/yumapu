import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/screens/camera_screen.dart';
import 'package:yu_map/screens/create_post_screen.dart';
import 'package:yu_map/screens/facility_screen.dart';
import 'package:yu_map/screens/favorites_screen.dart';
import 'package:yu_map/screens/map_screen.dart';
import 'package:yu_map/screens/profile_screen.dart';
import 'package:yu_map/screens/ranking_screen.dart';
import 'package:yu_map/screens/timeline_screen.dart';
import 'package:yu_map/services/platform_service.dart';
import 'package:yu_map/widgets/hexagon_logo.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Facility? _selectedFacility;

  // タブのインデックスに応じて画面を切り替え
  Widget _buildBody() {
    if (_selectedFacility != null) {
      return FacilityScreen(
        facility: _selectedFacility!,
        onBackPressed: () => setState(() => _selectedFacility = null),
      );
    }

    switch (_currentIndex) {
      case 0:
        return MapScreen(
          onFacilitySelected: (f) => setState(() => _selectedFacility = f),
        );
      case 1:
        return const TimelineScreen();
      case 2:
        return const RankingScreen();
      case 3:
        return FavoritesScreen(
          onFacilitySelected: (f) => setState(() => _selectedFacility = f),
        );
      case 4:
        return const ProfileScreen();
      default:
        return const Center(child: Text('Not Found'));
    }
  }

  void _onNavigate(int index) {
    setState(() {
      _selectedFacility = null; // タブ切り替え時は詳細画面を閉じる
      _currentIndex = index;
    });
  }

  /// カスタムカメラを開き、撮影後に施設選択→投稿画面へ遷移
  Future<void> _openCamera() async {
    // カメラ画面を開いて撮影結果を受け取る
    final capturedFile = await Navigator.of(context).push<File>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (capturedFile == null || !mounted) return;

    // 施設が選択済みであればそのまま投稿画面へ
    if (_selectedFacility != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreatePostScreen(
            facility: _selectedFacility!,
            initialImage: capturedFile,
          ),
        ),
      );
      return;
    }

    // 施設未選択の場合はスナックバーで案内
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('写真を撮りました！施設ページから「ここで投稿」で使えます'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLarge = PlatformService.isLargeScreen(context);

    if (isLarge) {
      // ===== デスクトップ / Web向けレイアウト (Side Navigation) =====
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onNavigate,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: HexagonLogo(size: 40),
              ),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.map),
                  label: Text('マップ'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.image),
                  label: Text('SNS'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.emoji_events),
                  label: Text('ランキング'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.favorite_border),
                  label: Text('お気に入り'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  label: Text('マイページ'),
                ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: FloatingActionButton(
                      onPressed: _openCamera,
                      backgroundColor: Colors.orange,
                      child: const Icon(Icons.camera_alt, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    } else {
      // ===== モバイル向けレイアウト (Bottom Navigation) =====
      return Scaffold(
        body: _buildBody(),
        floatingActionButton: FloatingActionButton(
          onPressed: _openCamera,
          backgroundColor: Colors.orange,
          child: const Icon(Icons.camera_alt, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.map, 'マップ', 0),
              _buildNavItem(Icons.image, 'SNS', 1),
              const SizedBox(width: 48), // FABのスペース
              _buildNavItem(Icons.emoji_events, 'ランキング', 2),
              _buildNavItem(Icons.person_outline, 'マイページ', 4),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Colors.lightBlue : Colors.grey;
    return InkWell(
      onTap: () => _onNavigate(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
