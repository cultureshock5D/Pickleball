import 'package:flutter/material.dart';
import '../core/pagination/pagination_controller.dart';
import '../core/pagination/pagination_state.dart';
import '../core/theme/app_theme.dart';
import 'neon_button.dart';
import 'skeleton_loader.dart';

/// Full-screen error presentation used when initial page loading fails.
/// Provides high-visibility error icon, descriptive message, and actionable retry.
class PaginationFullScreenErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const PaginationFullScreenErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      key: const Key('pagination_fullscreen_error'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: colors.errorRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Data',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            NeonButton(
              text: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-blocking inline footer retry card used when a subsequent chunk fetch fails.
/// Strictly preserves all loaded memory items while offering an inline retry trigger.
class PaginationInlineChunkErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const PaginationInlineChunkErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      key: const Key('pagination_inline_chunk_error'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.errorRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colors.errorRed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: colors.neonLime,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Reusable paginated list view connecting to a [PaginationController].
/// Handles 6-state pagination, scroll prefetching, zero-CLS skeleton loading,
/// and distinct error presentations (full-screen initial vs non-blocking inline footer).
class PaginatedListView<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context, int index)? skeletonBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Widget Function(BuildContext context, String message, VoidCallback onRetry)?
      fullScreenErrorBuilder;
  final Widget Function(BuildContext context, String message, VoidCallback onRetry)?
      inlineChunkErrorBuilder;
  final EdgeInsetsGeometry padding;
  final int initialSkeletonCount;
  final bool enablePullToRefresh;
  final Widget? header;

  const PaginatedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.skeletonBuilder,
    this.emptyBuilder,
    this.fullScreenErrorBuilder,
    this.inlineChunkErrorBuilder,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.initialSkeletonCount = 4,
    this.enablePullToRefresh = true,
    this.header,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    widget.controller.attachScrollController(_scrollController);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final colors = context.colors;

        if (state is PaginationInitialLoading<T>) {
          return _buildSkeletonList();
        }

        if (state is PaginationFullScreenError<T>) {
          if (widget.fullScreenErrorBuilder != null) {
            return widget.fullScreenErrorBuilder!(
              context,
              state.message,
              () => widget.controller.retryInitial(),
            );
          }
          return PaginationFullScreenErrorView(
            message: state.message,
            onRetry: () => widget.controller.retryInitial(),
          );
        }

        final items = state.currentItems;

        if (items.isEmpty && state is! PaginationFetchingNextChunk<T>) {
          if (widget.emptyBuilder != null) {
            return widget.emptyBuilder!(context);
          }
          return _buildDefaultEmptyState(colors);
        }

        Widget listView = ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: widget.padding,
          itemCount: items.length + (widget.header != null ? 1 : 0) + 1,
          itemBuilder: (context, index) {
            int adjustedIndex = index;
            if (widget.header != null) {
              if (index == 0) return widget.header!;
              adjustedIndex = index - 1;
            }

            if (adjustedIndex < items.length) {
              return widget.itemBuilder(context, items[adjustedIndex], adjustedIndex);
            }

            // Footer item
            return _buildFooter(state, colors);
          },
        );

        if (widget.enablePullToRefresh) {
          return RefreshIndicator(
            color: colors.neonLime,
            backgroundColor: colors.surfaceElevated,
            onRefresh: () => widget.controller.refresh(),
            child: listView,
          );
        }

        return listView;
      },
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: widget.padding,
      itemCount: widget.initialSkeletonCount + (widget.header != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (widget.header != null && index == 0) {
          return widget.header!;
        }
        final skeletonIndex = widget.header != null ? index - 1 : index;
        if (widget.skeletonBuilder != null) {
          return widget.skeletonBuilder!(context, skeletonIndex);
        }
        return const SkeletonReservationCard();
      },
    );
  }

  Widget _buildDefaultEmptyState(AppPalette colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 48,
              color: colors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No items found',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(PaginationState<T> state, AppPalette colors) {
    if (state is PaginationFetchingNextChunk<T>) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(colors.neonLime),
          ),
        ),
      );
    }

    if (state is PaginationInlineChunkError<T>) {
      if (widget.inlineChunkErrorBuilder != null) {
        return widget.inlineChunkErrorBuilder!(
          context,
          state.message,
          () => widget.controller.retryNextChunk(),
        );
      }
      return PaginationInlineChunkErrorView(
        message: state.message,
        onRetry: () => widget.controller.retryNextChunk(),
      );
    }

    if (state is PaginationExhausted<T> && state.items.length > 5) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: Text(
          'All reservations loaded',
          style: TextStyle(
            color: colors.textMuted.withValues(alpha: 0.5),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return const SizedBox(height: 16);
  }
}
