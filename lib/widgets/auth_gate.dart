import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/main_navigation_screen.dart';
import '../screens/pos/pos_screen.dart';
import '../services/auth_service.dart';

/// AuthGate observes auth state changes and routes:
/// - Cashier account (`cashier@pickleball.com` or role `cashier`) -> `PosScreen` (Cashier POS Register ONLY)
/// - Players / Clients -> `MainNavigationScreen` (Player Court Reservation & Club Management)
/// - Unauthenticated -> `LoginScreen`
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
          final email = session.user.email?.trim().toLowerCase() ?? '';
          final role = (session.user.userMetadata?['role'] as String?)?.toLowerCase();
          final isCashier = email == 'cashier@pickleball.com' || role == 'cashier';

          if (isCashier) {
            final name = (session.user.userMetadata?['full_name'] as String?) ??
                (email.isNotEmpty ? email.split('@').first : 'Cashier Staff');
            return PosScreen(
              cashierId: session.user.id,
              cashierName: name,
            );
          }

          return const MainNavigationScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

