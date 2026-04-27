// lib/core/widgets/photo_gallery_viewer.dart
//
// 写真フルスクリーンビューワー。
// ピンチズーム・スワイプで複数枚の写真を閲覧できる。
// photo_view パッケージを使用（APIキー不要・完全無料）。
//
// 使い方:
//   PhotoGalleryViewer.show(
//     context,
//     photos: ['https://...', 'https://...'],
//     initialIndex: 0,
//   );

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// 写真URLリストとタップした写真インデックスを受け取り、
/// フルスクリーンのギャラリービューワーを表示する。
class PhotoGalleryViewer extends StatefulWidget {
  /// 表示する写真URLのリスト。
  final List<String> photos;

  /// 最初に表示する写真のインデックス（0始まり）。
  final int initialIndex;

  const PhotoGalleryViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  /// フルスクリーンダイアログとして表示する静的メソッド。
  /// [context] は Navigator.of(context) に渡す BuildContext。
  /// [photos] は表示する写真URLのリスト。
  /// [initialIndex] は最初に表示する写真のインデックス（デフォルト: 0）。
  static Future<void> show(
    BuildContext context, {
    required List<String> photos,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoGalleryViewer(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<PhotoGalleryViewer> createState() => _PhotoGalleryViewerState();
}

class _PhotoGalleryViewerState extends State<PhotoGalleryViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // ── アプリバー ──────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        // 「1 / 3」形式でページ数を表示
        title: widget.photos.length > 1
            ? Text(
                '${_currentIndex + 1} / ${widget.photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              )
            : null,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // ── フルスクリーン写真ギャラリー ────────────────────────────────────
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        scrollPhysics: const BouncingScrollPhysics(),
        itemCount: widget.photos.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            // CachedNetworkImageProvider でキャッシュを使いながら表示
            imageProvider: CachedNetworkImageProvider(widget.photos[index]),
            // ピンチズームの最小・最大倍率を設定
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4.0,
            // ダブルタップでズームイン
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes: PhotoViewHeroAttributes(
              tag: 'photo_${widget.photos[index]}',
            ),
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(
                Icons.image_not_supported,
                color: Colors.white54,
                size: 64,
              ),
            ),
          );
        },
        loadingBuilder: (_, event) => const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}
