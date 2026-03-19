import 'package:flutter/material.dart';

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    // 六角形の頂点座標を計算
    path.moveTo(width * 0.5, 0); // 上部中央
    path.lineTo(width, height * 0.25); // 右上
    path.lineTo(width, height * 0.75); // 右下
    path.lineTo(width * 0.5, height); // 下部中央
    path.lineTo(0, height * 0.75); // 左下
    path.lineTo(0, height * 0.25); // 左上
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class HexagonLogo extends StatelessWidget {
  final double size;

  const HexagonLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: HexagonClipper(),
      child: Container(
        width: size,
        height: size * 0.85,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.lightBlue, Colors.orange]),
        ),
        alignment: Alignment.center,
        child: Text(
          '湯マ',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.3,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
