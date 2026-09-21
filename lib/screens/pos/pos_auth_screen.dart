import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/validators.dart';
import '../../services/auth_service.dart';
import '../../widgets/brand_logo_painter.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/neon_button.dart';
import '../auth/login_screen.dart';
import 'pos_screen.dart';

class PosAuthScreen extends StatefulWidget {
  const PosAuthScreen({super.key});

  @override
  State<PosAuthScreen> createState() => _PosAuthScreenState();
}

class _PosAuthScreenState extends State<PosAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService.instance;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.block_flipped, color: Colors.redAccent, size: 24),
              const SizedBox(width: 10),
              Text(
                'Access Denied',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Access Denied: POS Register is strictly for Cashier staff only. '
            'Player accounts are strictly for booking court reservations on the web portal.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neonLime,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleStaffSignIn({
    String? overrideEmail,
    String? overridePassword,
    String? demoRole,
    String? demoName,
  }) async {
    final email = overrideEmail ?? _emailController.text;
    final password = overridePassword ?? _passwordController.text;

    if (overrideEmail == null && !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (demoRole != null) {
        // Simulated / demo staff authentication
        if (demoRole == 'player' || demoRole == 'client') {
          // Immediately reject, terminate session, show barrier dialog
          await _authService.signOut();
          if (mounted) {
            _showAccessDeniedDialog();
          }
          return;
        }

        // Staff approved
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PosScreen(
                cashierId: 'cashier-demo-01',
                cashierName: demoName ?? 'Cashier Staff',
                cashierRole: demoRole,
              ),
            ),
          );
        }
        return;
      }

      // Real Supabase Auth Flow
      final res = await _authService.signIn(email: email, password: password);
      final user = res.user;

      if (user == null) {
        throw const AuthException('Failed to authenticate cashier account.');
      }

      // Query public.profiles for role
      String userRole = 'client';
      String? fullName;

      if (_authService.isSupabaseReady) {
        try {
          final profileRes = await Supabase.instance.client
              .from('profiles')
              .select('role, full_name')
              .eq('id', user.id)
              .maybeSingle();

          if (profileRes != null) {
            userRole = (profileRes['role'] as String? ?? 'client').toLowerCase();
            fullName = profileRes['full_name'] as String?;
          }
        } catch (e) {
          debugPrint('Profile role query notice: $e');
        }
      }

      // Check: Is role one of ['owner', 'admin', 'cashier'] or is cashier@pickleball.com?
      final isCashierEmail = (user.email ?? '').trim().toLowerCase() == 'cashier@pickleball.com';
      const allowedRoles = ['owner', 'admin', 'cashier'];
      if (allowedRoles.contains(userRole) || isCashierEmail) {
        // YES: Grant access and navigate directly to POS Register screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PosScreen(
                cashierId: user.id,
                cashierName: fullName ?? user.email?.split('@').first ?? 'Cashier',
                cashierRole: isCashierEmail ? 'cashier' : userRole,
              ),
            ),
          );
        }
      } else {
        // NO (specifically for role == 'player' or other non-staff):
        // Immediately terminate session, deny access, show dialog
        await _authService.signOut();
        if (mounted) {
          _showAccessDeniedDialog();
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
      if (mounted) AppSnackBar.error(context, e.message);
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo & Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.neonLime.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.neonLime.withValues(alpha: 0.15),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const CustomPaint(
                          size: Size(44, 44),
                          painter: BrandLogoPainter(color: AppTheme.neonLime),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'C&J ARENA POS TERMINAL',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cashier & Pro Shop Staff Register Only',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Security Boundary Callout
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Player accounts are restricted to court reservations and cannot access this terminal.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email Field
                    CustomTextField(
                      controller: _emailController,
                      label: 'Staff Work Email',
                      hintText: 'cashier@cjarena.ph',
                      prefixIcon: Icons.badge_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hintText: 'Enter account password',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please enter your password'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Sign In Button
                    NeonButton(
                      text: _isLoading ? 'Authenticating Staff...' : 'Sign In to POS Register',
                      icon: Icons.login,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : () => _handleStaffSignIn(),
                    ),
                    const SizedBox(height: 20),

                    // Return to player portal link
                    Center(
                      child: TextButton.icon(
                        icon: Icon(Icons.arrow_back, size: 16, color: colors.textSecondary),
                        label: Text(
                          'Switch to Player Court Reservations',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
