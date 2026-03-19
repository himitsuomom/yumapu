// lib/core/widgets/async_state_view.dart
import 'package:flutter/material.dart';
import 'loading/shimmer_loading.dart';
import 'loading/shimmer_box.dart';
import 'error/common_error_view.dart';
import 'empty/common_empty_view.dart';

/// Unified handler for async data states (Loading / Error / Empty / Success)
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.data,
    required this.isEmpty,
    required this.builder,
    this.shimmerBuilder,
    this.onRetry,
    this.emptyMessage = 'No data available',
    this.itemCount = 6,
  });

  final bool isLoading;
  final String? errorMessage;
  final T? data;
  final bool isEmpty;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context, int index)? shimmerBuilder;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final int itemCount; // Number of shimmer items to show

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ShimmerLoading(
        itemCount: itemCount,
        itemBuilder: shimmerBuilder ?? _defaultShimmerBuilder,
      );
    }
    if (errorMessage != null) {
      return CommonErrorView(message: errorMessage!, onRetry: onRetry);
    }
    if (isEmpty || data == null) {
      return CommonEmptyView(message: emptyMessage);
    }
    return builder(context, data as T);
  }

  // Default shimmer builder when none is provided
  static Widget _defaultShimmerBuilder(BuildContext context, int index) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ShimmerBox(width: double.infinity, height: 20),
          SizedBox(height: 8),
          ShimmerBox(width: double.infinity, height: 80),
        ],
      ),
    );
  }
}
