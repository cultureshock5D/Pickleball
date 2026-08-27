import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/main_navigation_screen.dart';
import '../services/auth_service.dart';

/// AuthGate observes auth state changes and routes
/// between MainNavigationScreen (authenticated) and LoginScreen (unauthenticated).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService.instance;

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? authService.currentSession;

        if (session != null) {
          return const MainNavigationScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
