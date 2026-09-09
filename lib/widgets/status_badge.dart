import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum BadgeVariant { success, neutral, alert, dark }

/// High-impact pill status badge for court availability, match state, and pricing tags.
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.fontSize = 10.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    Color border;

    switch (variant) {
      case BadgeVariant.success:
        bg = AppColors.softCloud;
        text = AppColors.courtSuccess;
        border = AppColors.courtSuccess.withValues(alpha: 0.3);
        break;
      case BadgeVariant.alert:
        bg = AppColors.softCloud;
        text = AppColors.saleRed;
        border = AppColors.saleRed.withValues(alpha: 0.3);
        break;
      case BadgeVariant.dark:
        bg = AppColors.ink;
        text = AppColors.canvas;
        border = AppColors.ink;
        break;
      case BadgeVariant.neutral:
        bg = AppColors.softCloud;
        text = AppColors.mute;
        border = AppColors.hairline;
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: border),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: text,
        ),
      ),
    );
  }
}
