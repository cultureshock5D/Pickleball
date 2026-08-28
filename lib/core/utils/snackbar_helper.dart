import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Centralized styled SnackBar helper that eliminates 80+ lines of
/// duplicated SnackBar construction across login, signup, booking review,
/// profile, and calendar link screens.
class AppSnackBar {
  AppSnackBar._();

  /// Shows a themed floating SnackBar with an icon, styled border, and message.
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    IconData? icon,
    Duration? duration,
  }) {
    final effectiveIcon = icon ??
        (isError ? Icons.error_outline_rounded : Icons.check_circle_rounded);
    final accentColor = isError ? AppTheme.errorRed : AppTheme.neonGreen;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.surfaceElevated,
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
                  color: Colors.white,
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

  /// Convenience: show a success-themed SnackBar.
  static void success(BuildContext context, String message) {
    show(context, message: message, isError: false);
  }

  /// Convenience: show an error-themed SnackBar.
  static void error(BuildContext context, String message) {
    show(context, message: message, isError: true);
  }
}
