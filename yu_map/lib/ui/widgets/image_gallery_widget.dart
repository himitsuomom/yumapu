// lib/ui/widgets/image_gallery_widget.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageGalleryWidget extends StatelessWidget {
  final List<String> images;
  final int initialIndex;
  final String? title;

  const ImageGalleryWidget({
    Key? key,
    required this.images,
    this.initialIndex = 0,
    this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? '画像ギャラリー'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        itemCount: images.length,
        onPageChanged: (index) {},
        itemBuilder: (context, index) {
          return Hero(
            tag: 'image_$index',
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          );
        },
      ),
    );
  }
}