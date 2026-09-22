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
  final VoidCallback? onProfilePressed;

  const CustomTopAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.userProfile,
    this.userEmail,
    this.onQuickAddPressed,
    this.onProfilePressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(116);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final displayName = userProfile?.fullName ?? userEmail?.split('@').first ?? 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Brand Logo on Left, Action Icons on Right
            Row(
              children: [
                // Official C&J Brand Logo
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'cashier_pos/cj-logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const Spacer(),

                // Right Action Icons (Theme Mode Toggle, User Avatar)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Theme Mode Switcher (Moon / Sun)
                    Semantics(
                      button: true,
                      label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ThemeService.instance.toggleTheme();
                        },
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          alignment: Alignment.center,
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
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. User Avatar / Initials Badge with neon ring
                    Semantics(
                      button: true,
                      label: 'Profile: $displayName',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onProfilePressed?.call();
                        },
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          alignment: Alignment.center,
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
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Row 2: Subtitle & Title (Switched down below logo)
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
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
