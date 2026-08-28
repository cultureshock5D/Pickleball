import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/neon_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService.instance;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
      );

      if (mounted) {
        // If Supabase has email confirmation enabled, inform the user
        if (response.session == null) {
          AppSnackBar.show(
            context,
            message: 'Account created! Please check your email to confirm your account.',
            icon: Icons.check_circle_outline,
          );
          Navigator.of(context).pop();
        } else {
          // If session is active immediately, pop back to trigger AuthGate redirect
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
      if (mounted) {
        AppSnackBar.error(context, e.message);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred during registration.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Top Header Row with back button and avatar pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.surfaceElevated,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppTheme.borderSubtle),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.neonGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Role',
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  'Join SmashCourt',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create Account',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign up to book courts, track your balance, and manage transactions.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Form Fields
                CustomTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hintText: 'Alex Morgan',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: Validators.validateFullName,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hintText: 'alex@example.com',
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hintText: '••••••••',
                  prefixIcon: Icons.lock_clock_outlined,
                  isPassword: true,
                  validator: (val) => Validators.validateConfirmPassword(
                    val,
                    _passwordController.text,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSignUp(),
                ),
                const SizedBox(height: 16),

                // Error message banner if any
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRedAlpha12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.errorRedAlpha30),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.errorRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                              color: AppTheme.errorRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),
                NeonButton(
                  text: 'Create Account',
                  isLoading: _isLoading,
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: _handleSignUp,
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.inter(
                          color: AppTheme.neonGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
