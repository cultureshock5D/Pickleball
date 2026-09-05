import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    IconData? icon,
    Duration? duration,
  }) {
    final colors = context.colors;
    final effectiveIcon = icon ??
        (isError ? Icons.error_outline_rounded : Icons.check_circle_rounded);
    final accentColor = isError ? colors.errorRed : colors.neonGreen;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentColor, width: 1.2),
        ),
        duration: duration ?? Duration(seconds: isError ? 4 : 2),
        content: Row(
          children: [
            Icon(effectiveIcon, color: accentColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void success(BuildContext context, String message) {
    show(context, message: message);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, isError: true);
  }
}
