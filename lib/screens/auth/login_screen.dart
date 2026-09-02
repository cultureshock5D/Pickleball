import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/validators.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/neon_button.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
      if (mounted) {
        AppSnackBar.error(context, e.message);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
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
    final colors = context.colors;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  32,
            ),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        // Top mini bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.surfaceElevated,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.borderSubtle),
                              ),
                              child: Icon(
                                Icons.bolt_rounded,
                                color: colors.textPrimary,
                                size: 18,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceElevated,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: colors.borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: colors.neonLime,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Online',
                                    style: GoogleFonts.inter(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // App Header & Title
                        Text(
                          'Welcome to SmashCourt',
                          style: GoogleFonts.inter(
                            color: colors.neonGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Account Access',
                          style: GoogleFonts.inter(
                            color: colors.textPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // About Application Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: colors.cardGradient,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: colors.borderSubtle),
                            boxShadow: colors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: colors.neonGreenAlpha15,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.sports_tennis_rounded,
                                      color: colors.neonGreen,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Championship Club Suite',
                                          style: GoogleFonts.inter(
                                            color: colors.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Pickleball Club System',
                                          style: GoogleFonts.inter(
                                            color: colors.textMuted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Instant court reservations, performance analytics, and member management powered by Supabase.',
                                style: GoogleFonts.inter(
                                  color: colors.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.errorRedAlpha12,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: colors.errorRedAlpha30),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: colors.errorRed,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.inter(
                                      color: colors.errorRed,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Form Fields
                        CustomTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hintText: 'player@pickleball.com',
                          prefixIcon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email, AutofillHints.username],
                          validator: Validators.validateEmail,
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hintText: 'Enter secure password',
                          prefixIcon: Icons.lock_outline_rounded,
                          isPassword: true,
                          autofillHints: const [AutofillHints.password],
                          validator: Validators.validatePassword,
                          onFieldSubmitted: (_) => _handleSignIn(),
                        ),
                        const SizedBox(height: 24),

                        NeonButton(
                          text: 'Sign In to Account',
                          isLoading: _isLoading,
                          icon: Icons.login_rounded,
                          onPressed: _handleSignIn,
                        ),
                      ],
                    ),

                    // Bottom Sign Up Switch
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 8),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: GoogleFonts.inter(
                                color: colors.textMuted,
                                fontSize: 13.5,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Sign Up',
                                style: GoogleFonts.inter(
                                  color: colors.neonGreen,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
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
