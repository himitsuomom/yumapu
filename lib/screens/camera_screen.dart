// lib/screens/camera_screen.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yu_map/widgets/hexagon_logo.dart';

/// Yu-Map カスタムカメラ画面
/// カメラプレビュー上に「湯マ」六角形ロゴをオーバーレイして撮影できる
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;
  bool _isCapturing = false;
  int _currentCameraIndex = 0;

  // ロゴの位置（ドラッグで変更可能）
  Offset _logoPosition = const Offset(16, 16);
  // ロゴのサイズ
  double _logoSize = 80;

  // RepaintBoundaryのキー（カメラ＋ロゴを1枚にするため）
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() => _isInitializing = true);
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _isInitializing = false);
        return;
      }
      await _startCamera(_cameras![_currentCameraIndex]);
    } catch (e) {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  /// 前面カメラと背面カメラを切り替え
  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    await _controller?.dispose();
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;
    await _startCamera(_cameras![_currentCameraIndex]);
  }

  /// カメラプレビュー＋ロゴオーバーレイを1枚の画像としてキャプチャ
  Future<File?> _captureWithOverlay() async {
    final boundary =
        _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    // Flutterウィジェットツリーを画像に変換（高解像度）
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/yumap_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _onCapture() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final file = await _captureWithOverlay();
      if (!mounted) return;
      if (file != null) {
        Navigator.of(context).pop(file);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('撮影に失敗しました')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // カメラプレビュー＋ロゴオーバーレイ
            Positioned.fill(
              child: _isInitializing
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : _controller == null ||
                          !(_controller!.value.isInitialized)
                      ? const Center(
                          child: Text(
                            'カメラを利用できません',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : _buildCameraWithOverlay(),
            ),

            // 上部コントロール
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopControls(),
            ),

            // 下部コントロール（シャッター等）
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  /// カメラプレビュー + ドラッグ可能なロゴオーバーレイ
  Widget _buildCameraWithOverlay() {
    final controller = _controller!;
    return RepaintBoundary(
      key: _captureKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // カメラプレビュー（画面いっぱいに表示）
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.previewSize!.height,
                  height: controller.value.previewSize!.width,
                  child: CameraPreview(controller),
                ),
              ),

              // ドラッグで位置を変えられる「湯マ」ロゴ
              Positioned(
                left: _logoPosition.dx,
                top: _logoPosition.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final newX = (_logoPosition.dx + details.delta.dx)
                          .clamp(0.0, constraints.maxWidth - _logoSize);
                      final newY = (_logoPosition.dy + details.delta.dy)
                          .clamp(0.0, constraints.maxHeight - _logoSize);
                      _logoPosition = Offset(newX, newY);
                    });
                  },
                  child: Column(
                    children: [
                      HexagonLogo(size: _logoSize),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Yu Map',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 閉じるボタン
          _CircleButton(
            icon: Icons.close,
            onTap: () => Navigator.of(context).pop(),
          ),

          // ロゴサイズ調整
          Row(
            children: [
              _CircleButton(
                icon: Icons.remove,
                onTap: () => setState(() {
                  _logoSize = (_logoSize - 10).clamp(40.0, 160.0);
                }),
              ),
              const SizedBox(width: 8),
              const Text('ロゴサイズ',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              const SizedBox(width: 8),
              _CircleButton(
                icon: Icons.add,
                onTap: () => setState(() {
                  _logoSize = (_logoSize + 10).clamp(40.0, 160.0);
                }),
              ),
            ],
          ),

          // カメラ切り替え
          _CircleButton(
            icon: Icons.flip_camera_ios,
            onTap: _switchCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black54],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // シャッターボタン
          GestureDetector(
            onTap: _onCapture,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                color: _isCapturing ? Colors.grey : Colors.white24,
              ),
              child: _isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt,
                      color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black45,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
