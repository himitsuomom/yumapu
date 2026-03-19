import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yu_map/models/facility.dart';
import 'package:yu_map/providers/app_state.dart';
import 'package:yu_map/widgets/hexagon_logo.dart';
import 'package:yu_map/widgets/safe_network_image.dart';

/// MapScreen - Main map view with facility locations
class MapScreen extends StatefulWidget {
  final Function(Facility) onFacilitySelected;

  const MapScreen({super.key, required this.onFacilitySelected});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  void initState() {
    super.initState();
    // 初回表示時に施設データを読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadFacilities();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (appState.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  appState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('もう一度試す'),
                  onPressed: () {
                    context.read<AppState>().loadFacilities();
                  },
                ),
              ],
            ),
          );
        }

        final facilities = appState.facilities;

        return Stack(
          children: [
            // 背景のモックマップ
            const Positioned.fill(
              child: SafeNetworkImage(
                imageUrl:
                    'https://images.unsplash.com/photo-1524661135-423995f22d0b?q=80&w=1200&auto=format&fit=crop',
                fit: BoxFit.cover,
              ),
            ),
            // 白いオーバーレイ
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            // ヘッダー検索バー
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(
                    top: 40, left: 16, right: 16, bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const HexagonLogo(size: 32),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search, color: Colors.grey, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'エリア・施設名で検索',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.tune, color: Colors.lightBlue),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 施設ピンのモック
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    for (final f in facilities)
                      Positioned(
                        left: constraints.maxWidth * f.x - 20,
                        top: constraints.maxHeight * f.y - 20,
                        child: GestureDetector(
                          onTap: () => widget.onFacilitySelected(f),
                          child: Column(
                            children: [
                              ClipPath(
                                clipper: HexagonClipper(),
                                child: Container(
                                  width: 40,
                                  height: 34,
                                  color: Colors.orange,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '湯',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12, blurRadius: 2)
                                  ],
                                ),
                                child: Text(
                                  f.name,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            )
          ],
        );
      },
    );
  }
}
