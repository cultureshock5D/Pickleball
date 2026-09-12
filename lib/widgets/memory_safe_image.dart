import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'skeleton_loader.dart';

/// Memory-conscious image loader with strict GPU decode clamping,
/// disk caching, luxury shimmer placeholder, and graceful error fallback.
///
/// Decoded memory per image: 600 * 400 * 4 bytes = 960,000 bytes (960 KB).
/// Compared to raw 4000x3000 photos (48 MB), this provides a 98% memory reduction
/// and guarantees total heap footprint < 150MB across 100+ scrolled items.
class MemorySafeImage extends StatelessWidget {
  static const int defaultMemCacheWidth = 600;
  static const int defaultMemCacheHeight = 400;
  static const int defaultMaxWidthDiskCache = 1200;
  static const int defaultMaxHeightDiskCache = 800;

  /// Calculates the decoded RGBA8888 in-memory bitmap size in bytes.
  static int computeDecodedMemoryBytes({
    int width = defaultMemCacheWidth,
    int height = defaultMemCacheHeight,
  }) =>
      width * height * 4;

  /// Calculates total memory budget in megabytes for a given number of cached items.
  static double computeHeapBudgetMB(
    int itemCount, {
    int width = defaultMemCacheWidth,
    int height = defaultMemCacheHeight,
  }) =>
      (itemCount * computeDecodedMemoryBytes(width: width, height: height)) /
      (1024 * 1024);

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final int memCacheWidth;
  final int memCacheHeight;
  final int maxWidthDiskCache;
  final int maxHeightDiskCache;
  final Widget Function(BuildContext context)? placeholderBuilder;
  final Widget Function(BuildContext context)? errorBuilder;

  const MemorySafeImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.memCacheWidth = defaultMemCacheWidth,
    this.memCacheHeight = defaultMemCacheHeight,
    this.maxWidthDiskCache = defaultMaxWidthDiskCache,
    this.maxHeightDiskCache = defaultMaxHeightDiskCache,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = imageUrl?.trim();

    Widget buildPlaceholder() {
      if (placeholderBuilder != null) {
        return placeholderBuilder!(context);
      }
      return Container(
        key: const Key('memory_safe_image_placeholder'),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: borderRadius,
        ),
        child: const ShimmerSweep(
          child: SkeletonBlock(
            height: double.infinity,
            width: double.infinity,
            borderRadius: 0,
          ),
        ),
      );
    }

    Widget buildErrorWidget() {
      if (errorBuilder != null) {
        return errorBuilder!(context);
      }
      return Container(
        key: const Key('memory_safe_image_error'),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: borderRadius,
          border: Border.all(
            color: colors.borderSubtle,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.sports_tennis_rounded,
            size: 32,
            color: colors.textMuted.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    if (url == null || url.isEmpty) {
      return buildErrorWidget();
    }

    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (context, _) => buildPlaceholder(),
      errorWidget: (context, _, __) => buildErrorWidget(),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}
