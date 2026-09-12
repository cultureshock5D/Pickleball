import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Shimmer animation controller widget providing smooth luxury gradient sweeps.
/// Uses design tokens: Base #121A16, Shimmer #1B2620, Accent #CCFF00.
class ShimmerSweep extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color baseColor;
  final Color highlightColor;
  final Color accentColor;

  const ShimmerSweep({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor = const Color(0xFF121A16),
    this.highlightColor = const Color(0xFF1B2620),
    this.accentColor = const Color(0xFFCCFF00),
  });

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final double slide = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(slide - 1.0, -0.3),
              end: Alignment(slide + 1.0, 0.3),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.accentColor.withValues(alpha: 0.25),
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Generic skeleton block placeholder with rounded corners.
class SkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color color;

  const SkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.color = const Color(0xFF1B2620),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Zero-CLS Skeleton for [ReservationCard] with exact dimensional parity.
/// Card height: 179.4dp, Pitch: 191.4dp (179.4dp + 12.0dp spacing), CLS = 0.
class SkeletonReservationCard extends StatelessWidget {
  static const double cardHeight = 179.4;
  static const double cardPitch = 191.4;
  static const double verticalSpacing = 12.0;

  final double height;
  final EdgeInsetsGeometry? margin;

  const SkeletonReservationCard({
    super.key,
    this.height = cardHeight,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      margin: margin,
      height: height,
      child: ShimmerSweep(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.borderSubtle,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Header Row: Date Header & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SkeletonBlock(width: 140, height: 16, borderRadius: 4),
                  Container(
                    width: 80,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2620),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFCCFF00).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),

              // 2. Court Badge & Price Row
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2620),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFCCFF00).withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBlock(width: 130, height: 16, borderRadius: 4),
                        SizedBox(height: 6),
                        SkeletonBlock(width: 90, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SkeletonBlock(width: 70, height: 18, borderRadius: 4),
                      SizedBox(height: 6),
                      SkeletonBlock(width: 50, height: 12, borderRadius: 4),
                    ],
                  ),
                ],
              ),

              // 3. Divider & Quick Action Buttons
              Container(
                height: 1,
                color: colors.borderSubtle,
              ),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2620),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCCFF00).withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2620),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2620),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFCCFF00).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zero-CLS Skeleton for [VenueCard] with exact dimensional parity.
/// Card height: 130.0dp, Pitch: 140.0dp (130.0dp + 10.0dp spacing), CLS = 0.
class SkeletonVenueCard extends StatelessWidget {
  static const double cardHeight = 130.0;
  static const double cardPitch = 140.0;
  static const double verticalSpacing = 10.0;

  final double height;
  final EdgeInsetsGeometry? margin;

  const SkeletonVenueCard({
    super.key,
    this.height = cardHeight,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      margin: margin,
      height: height,
      child: ShimmerSweep(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Row 1: Icon container + Venue title/tag/address
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2620),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFCCFF00).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SkeletonBlock(width: 130, height: 16, borderRadius: 4),
                            SizedBox(width: 8),
                            SkeletonBlock(width: 40, height: 14, borderRadius: 6),
                          ],
                        ),
                        SizedBox(height: 6),
                        SkeletonBlock(width: 180, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),

              // Row 2: Badges row
              const Row(
                children: [
                  SkeletonBlock(width: 70, height: 18, borderRadius: 6),
                  SizedBox(width: 6),
                  SkeletonBlock(width: 65, height: 18, borderRadius: 6),
                  SizedBox(width: 6),
                  SkeletonBlock(width: 60, height: 18, borderRadius: 6),
                ],
              ),

              // Row 3: Bottom Rate & Select Action Row
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonBlock(width: 100, height: 14, borderRadius: 4),
                  SkeletonBlock(width: 75, height: 14, borderRadius: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
