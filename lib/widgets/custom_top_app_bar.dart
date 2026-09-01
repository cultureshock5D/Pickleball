import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/theme_service.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';

class CustomTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final UserProfile? userProfile;
  final String? userEmail;
  final VoidCallback? onQuickAddPressed;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onProfilePressed;

  const CustomTopAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.userProfile,
    this.userEmail,
    this.onQuickAddPressed,
    this.onNotificationPressed,
    this.onProfilePressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(84);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final displayName = userProfile?.fullName ?? userEmail?.split('@').first ?? 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(
            color: colors.borderSubtle,
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Left Action Icon (+)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onQuickAddPressed?.call();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: colors.textPrimary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Header Title / Subtitle
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Right Action Icons (Theme Mode Toggle, Notifications Bell, User Avatar)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Theme Mode Switcher (Moon / Sun)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ThemeService.instance.toggleTheme();
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => RotationTransition(
                        turns: anim,
                        child: ScaleTransition(scale: anim, child: child),
                      ),
                      child: Icon(
                        isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                        key: ValueKey(isDark),
                        color: isDark ? const Color(0xFFFACC15) : colors.neonGreenDark,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Notifications Bell with neon badge
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onNotificationPressed?.call();
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        child: Icon(
                          Icons.notifications_none_rounded,
                          color: colors.textPrimary,
                          size: 19,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.neonGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 3. User Avatar / Initials Badge with neon ring
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onProfilePressed?.call();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceHighlight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.neonGreen,
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.neonGreenAlpha30,
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : colors.neonGreenDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
