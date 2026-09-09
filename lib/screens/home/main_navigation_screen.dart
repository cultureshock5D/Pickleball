import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_top_app_bar.dart';
import '../booking/court_reservation.dart';
import '../insights/insights.dart';
import '../profile/profile_screen.dart';
import 'landing_home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  final AuthService _authService = AuthService.instance;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      final profile = await _authService.fetchUserProfile(user.id);
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    }
  }

  String get _currentTabTitle {
    switch (_currentIndex) {
      case 0:
        return 'C&J Arena';
      case 1:
        return 'Court Reservation';
      case 2:
        return 'Performance Hub';
      case 3:
        return 'Account & Profile';
      default:
        return 'C&J Pickleball';
    }
  }

  String get _currentTabSubtitle {
    switch (_currentIndex) {
      case 0:
        return 'Championship Club';
      case 1:
        return 'Booking & Schedule';
      case 2:
        return 'Analytics & Insights';
      case 3:
        return 'Preferences & Membership';
      default:
        return 'Luxury Club';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: CustomTopAppBar(
        title: _currentTabTitle,
        subtitle: _currentTabSubtitle,
        userProfile: _userProfile,
        userEmail: user?.email,
        onQuickAddPressed: () {
          setState(() => _currentIndex = 1);
        },
        onNotificationPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications: No new alerts today.'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        onProfilePressed: () {
          setState(() => _currentIndex = 3);
        },
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          LandingHomeScreen(
            onBookCourtPressed: () {
              setState(() => _currentIndex = 1);
            },
          ),
          const CourtReservationScreen(),
          InsightsScreen(
            onBookCourtPressed: () {
              setState(() => _currentIndex = 1);
            },
          ),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          CustomBottomNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Arena',
          ),
          CustomBottomNavItem(
            icon: Icons.sports_tennis_outlined,
            activeIcon: Icons.sports_tennis_rounded,
            label: 'Reservation',
          ),
          CustomBottomNavItem(
            icon: Icons.insights_outlined,
            activeIcon: Icons.insights_rounded,
            label: 'Insights',
          ),
          CustomBottomNavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
