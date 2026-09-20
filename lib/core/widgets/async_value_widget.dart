import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'error_view.dart';
import 'empty_view.dart';
import 'loading_shimmer.dart';

/// A reusable widget that handles Riverpod AsyncValue states:
///   Loading → shimmer / progress indicator
///   Error   → retry view
///   Data    → builder callback
class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;
  final String? emptyMessage;
  final bool Function(T data)? isEmpty;

  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    this.emptyMessage,
    this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loading ?? const LoadingShimmer(),
      error: (error, _) => ErrorView(
        message: error.toString(),
        onRetry: onRetry,
      ),
      data: (d) {
        if (isEmpty != null && isEmpty!(d)) {
          return EmptyView(message: emptyMessage ?? 'No data available yet.');
        }
        return data(d);
      },
    );
  }
}

/// Sliver variant for use in CustomScrollView.
class SliverAsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  const SliverAsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => SliverToBoxAdapter(
        child: loading ?? const LoadingShimmer(),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: ErrorView(message: error.toString(), onRetry: onRetry),
      ),
      data: data,
    );
  }
}
