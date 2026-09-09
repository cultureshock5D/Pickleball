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

class BrandLogoWidget extends StatelessWidget {
  final double size;
  final Color color;
  final bool inverted;

  const BrandLogoWidget({
    super.key,
    this.size = 36.0,
    this.color = AppColors.ink,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: BrandLogoPainter(color: color, inverted: inverted),
      ),
    );
  }
}
