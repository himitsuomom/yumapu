// lib/core/widgets/loading/shimmer_loading.dart
import 'package:flutter/material.dart';

/// List-type shimmer loading (adapts to each screen's layout via itemBuilder)
class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({
    super.key,
    required this.itemBuilder,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget Function(BuildContext context, int index) itemBuilder;
  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
