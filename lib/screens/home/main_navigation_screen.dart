import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_top_app_bar.dart';
import '../analytics/analytics_screen.dart';
import '../booking/booking_screen.dart';
import '../booking/my_bookings_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService.instance;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
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
        return 'Court Reservation';
      case 1:
        return 'Performance Hub';
      case 2:
        return 'My Reservations';
      case 3:
        return 'Account & Profile';
      default:
        return 'SmashCourt';
    }
  }

  String get _currentTabSubtitle {
    switch (_currentIndex) {
      case 0:
        return 'Court Schedule';
      case 1:
        return 'Analytics & Insights';
      case 2:
        return 'Active Bookings';
      case 3:
        return 'Preferences';
      default:
        return 'Finance';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CustomTopAppBar(
        title: _currentTabTitle,
        subtitle: _currentTabSubtitle,
        userProfile: _userProfile,
        userEmail: user?.email,
        onQuickAddPressed: () {
          // Switch to Court Booking tab
          setState(() => _currentIndex = 0);
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
          // Switch to Profile Tab
          setState(() => _currentIndex = 3);
        },
      ),
      // Preserves full widget and scroll state across tab switches
      body: IndexedStack(
        index: _currentIndex,
        children: [
          BookingScreen(
            onViewBookings: () {
              setState(() => _currentIndex = 2);
            },
          ),
          AnalyticsScreen(
            onBookCourtPressed: () {
              setState(() => _currentIndex = 0);
            },
          ),
          MyBookingsScreen(
            onBookCourtPressed: () {
              setState(() => _currentIndex = 0);
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
            icon: Icons.sports_tennis_outlined,
            activeIcon: Icons.sports_tennis_rounded,
            label: 'Booking',
          ),
          CustomBottomNavItem(
            icon: Icons.insights_outlined,
            activeIcon: Icons.insights_rounded,
            label: 'Insights',
          ),
          CustomBottomNavItem(
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_month_rounded,
            label: 'Schedule',
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
