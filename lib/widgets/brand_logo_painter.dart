import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// CustomPainter rendering the C&J court monogram:
/// Geometric pickleball court outline with dashed kitchen lines,
/// diagonal 45° strike line, and center sweetspot circle.
class BrandLogoPainter extends CustomPainter {
  final Color color;
  final bool inverted;

  const BrandLogoPainter({
    this.color = AppColors.ink,
    this.inverted = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeColor = inverted ? AppColors.canvas : color;

    final borderPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final netPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final dashedPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final slashPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.square;

    final dotPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    // 1. Outer Court Boundary
    canvas.drawRect(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      borderPaint,
    );

    // 2. Net Center Line
    canvas.drawLine(
      Offset(2, size.height * 0.5),
      Offset(size.width - 2, size.height * 0.5),
      netPaint,
    );

    // 3. Kitchen Boundary Lines (dashed simulation)
    _drawDashedLine(
      canvas,
      Offset(2, size.height * 0.34),
      Offset(size.width - 2, size.height * 0.34),
      dashedPaint,
    );
    _drawDashedLine(
      canvas,
      Offset(2, size.height * 0.66),
      Offset(size.width - 2, size.height * 0.66),
      dashedPaint,
    );

    // 4. Diagonal 45° Strike Line
    canvas.drawLine(
      Offset(size.width * 0.27, size.height * 0.77),
      Offset(size.width * 0.73, size.height * 0.23),
      slashPaint,
    );

    // 5. Center Sweetspot Dot
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      3.5,
      dotPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = p1.dx;
    while (startX < p2.dx) {
      canvas.drawLine(
        Offset(startX, p1.dy),
        Offset(startX + dashWidth, p1.dy),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official C&J Brand Logotype Widget rendering 'cashier_pos/cj-logo.png'.
class CjLogoWidget extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool inPill;

  const CjLogoWidget({
    super.key,
    this.height = 32.0,
    this.width,
    this.borderRadius,
    this.padding,
    this.inPill = true,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'cashier_pos/cj-logo.png',
      height: height,
      width: width,
      fit: BoxFit.contain,
    );

    if (!inPill) {
      return image;
    }

    return Container(
      height: height,
      width: width,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: image,
      ),
    );
  }
}

class BrandLogoWidget extends StatelessWidget {
  final double size;
  final Color color;
  final bool inverted;
  final bool withSubtitle;
  final bool showText;
  final bool useAssetLogo;

  const BrandLogoWidget({
    super.key,
    this.size = 36.0,
    this.color = AppColors.ink,
    this.inverted = false,
    this.withSubtitle = false,
    this.showText = false,
    this.useAssetLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    if (useAssetLogo) {
      return CjLogoWidget(height: size);
    }

    final primaryColor = inverted ? AppColors.canvas : color;
    final secondaryColor = inverted ? AppColors.hairline : AppColors.mute;

    final logoPaint = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: BrandLogoPainter(color: color, inverted: inverted),
      ),
    );

    if (!showText && !withSubtitle) {
      return logoPaint;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoPaint,
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'C&J',
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: size * 0.7,
                    letterSpacing: -0.8,
                    height: 0.9,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'COURTS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            if (withSubtitle)
              Text(
                'PICKLEBALL ARENA',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: (size * 0.22).clamp(7, 10),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: secondaryColor,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

