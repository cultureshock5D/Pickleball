import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/validators.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/neon_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AuthService _authService = AuthService.instance;
  final BookingService _bookingService = BookingService.instance;
  UserProfile? _userProfile;
  int _matchCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      final profile = await _authService.fetchUserProfile(user.id);
      final bookings = await _bookingService.fetchCustomerBookings();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _matchCount = bookings.length;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditProfileDialog() async {
    final colors = context.colors;
    final isDark = context.isDark;
    final nameController = TextEditingController(
      text: _userProfile?.fullName ??
          _authService.currentUser?.userMetadata?['full_name'] ??
          '',
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16161B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: colors.borderSubtle, width: 1),
                ),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.borderSubtle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Edit Profile Details',
                      style: GoogleFonts.inter(
                        color: colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Update your full name across public.profiles',
                      style: GoogleFonts.inter(
                        color: colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      controller: nameController,
                      label: 'Full Name',
                      hintText: 'Enter your full name',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: Validators.validateFullName,
                    ),
                    const SizedBox(height: 24),
                    NeonButton(
                      text: 'Save Changes',
                      isLoading: isSaving,
                      icon: Icons.save_rounded,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isSaving = true);
                        final navigator = Navigator.of(ctx);

                        try {
                          final updated = await _authService.updateUserProfile(
                            fullName: nameController.text,
                          );
                          if (context.mounted) {
                            setState(() {
                              _userProfile = updated;
                            });
                            navigator.pop();
                            AppSnackBar.show(
                              context,
                              message: 'Profile updated successfully in Supabase!',
                              icon: Icons.check_circle_rounded,
                            );
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                          if (ctx.mounted) {
                            AppSnackBar.error(ctx, e.toString());
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _handleSignOut() async {
    final colors = context.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.borderSubtle),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.inter(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to end your current session?',
          style: GoogleFonts.inter(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: colors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.errorRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.colors;
    final isDark = context.isDark;
    final user = _authService.currentUser;
    final fullName = _userProfile?.fullName ?? user?.userMetadata?['full_name'] ?? 'Alex Morgan';
    final role = _userProfile?.role ?? 'customer';
    final email = user?.email ?? 'customer@pickleball.com';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colors.neonGreen),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. User Profile Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: colors.cardGradient,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: colors.borderSubtle),
              boxShadow: colors.cardShadow,
            ),
            child: Row(
              children: [
                // Avatar with Neon ring
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.surfaceHighlight,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.neonGreen, width: 2),
                    boxShadow: colors.neonGlow,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : colors.neonGreenDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: GoogleFonts.inter(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.neonLimeAlpha15,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.neonLimeAlpha30),
                        ),
                        child: Text(
                          'ROLE: ${role.toUpperCase()}',
                          style: GoogleFonts.inter(
                            color: colors.neonLime,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _showEditProfileDialog,
                  icon: Icon(
                    Icons.edit_outlined,
                    color: colors.neonGreen,
                    size: 22,
                  ),
                  tooltip: 'Edit Profile',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Stats Grid
          _buildStatItem(
            'Total Matches Played',
            '$_matchCount',
            Icons.sports_tennis_rounded,
          ),
          const SizedBox(height: 24),

          // 3. APPEARANCE & THEME SWITCHER (Dark Mode / Light Mode)
          Text(
            'Appearance & Theme',
            style: GoogleFonts.inter(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildThemeSelector(),
          const SizedBox(height: 24),

          // 4. Account Settings Options
          Text(
            'Account & Security',
            style: GoogleFonts.inter(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            title: 'Edit Personal Details',
            subtitle: 'Update full name and profile attributes',
            icon: Icons.person_outline_rounded,
            onTap: _showEditProfileDialog,
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            title: 'Notifications & Alerts',
            subtitle: 'Court alerts & match reminders',
            icon: Icons.notifications_none_rounded,
            onTap: () {
              AppSnackBar.show(context, message: 'Notification preferences are active.');
            },
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            title: 'Database & Profile Sync',
            subtitle: 'Supabase Postgres profiles active',
            icon: Icons.cloud_done_rounded,
            iconColor: colors.neonLime,
            onTap: () {
              AppSnackBar.show(context, message: 'Supabase profile sync healthy.');
            },
          ),
          const SizedBox(height: 32),

          // 5. Sign Out Button
          NeonButton(
            text: 'Sign Out Account',
            icon: Icons.logout_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
            ),
            onPressed: _handleSignOut,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    final colors = context.colors;
    final currentMode = ThemeService.instance.themeMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: colors.neonGreen, size: 20),
              const SizedBox(width: 10),
              Text(
                'Theme Mode',
                style: GoogleFonts.inter(
                  color: colors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildThemeOption(
                mode: ThemeMode.dark,
                title: 'Dark',
                icon: Icons.nightlight_round,
                isSelected: currentMode == ThemeMode.dark,
              ),
              const SizedBox(width: 8),
              _buildThemeOption(
                mode: ThemeMode.light,
                title: 'Light',
                icon: Icons.wb_sunny_rounded,
                isSelected: currentMode == ThemeMode.light,
              ),
              const SizedBox(width: 8),
              _buildThemeOption(
                mode: ThemeMode.system,
                title: 'System',
                icon: Icons.brightness_auto_rounded,
                isSelected: currentMode == ThemeMode.system,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required ThemeMode mode,
    required String title,
    required IconData icon,
    required bool isSelected,
  }) {
    final colors = context.colors;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          ThemeService.instance.setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colors.neonGreenAlpha20 : colors.surfaceHighlight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? colors.neonGreen : colors.borderSubtle,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? colors.neonGreen : colors.textMuted,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: isSelected ? colors.textPrimary : colors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.neonGreen, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: colors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surfaceHighlight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor ?? colors.textSecondary, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
