import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class PerforatedTicketDivider extends StatelessWidget {
  final double cutoutRadius;
  final Color? backgroundColor;
  final Color? lineColor;

  const PerforatedTicketDivider({
    super.key,
    this.cutoutRadius = 12.0,
    this.backgroundColor,
    this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cutoutRadius * 2,
      child: CustomPaint(
        painter: PerforatedPainter(
          radius: cutoutRadius,
          backgroundColor: backgroundColor ?? AppColors.canvas,
          lineColor: lineColor ?? AppColors.hairline,
        ),
      ),
    );
  }
}

class PerforatedPainter extends CustomPainter {
  final double radius;
  final Color backgroundColor;
  final Color lineColor;

  PerforatedPainter({
    required this.radius,
    required this.backgroundColor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final dashPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Left semi-circle cutout
    canvas.drawCircle(Offset(0, size.height / 2), radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, size.height / 2), radius: radius),
      -1.57,
      3.14,
      false,
      borderPaint,
    );

    // Right semi-circle cutout
    canvas.drawCircle(Offset(size.width, size.height / 2), radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: radius),
      1.57,
      3.14,
      false,
      borderPaint,
    );

    // Center Dashed Line
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = radius + 4;
    final endX = size.width - radius - 4;

    while (startX < endX) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        dashPaint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant PerforatedPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.lineColor != lineColor;
}
