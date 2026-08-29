import '../models/booking_model.dart';
import '../models/court_model.dart';
import '../models/user_profile.dart';

/// Centralized repository for demo / mock data used strictly for
/// demo guest access and previewing the application.
class DemoData {
  DemoData._();

  static const String demoUserId = 'demo-user-12345';
  static const String demoEmail = 'customer@pickleball.com';

  static const UserProfile demoProfile = UserProfile(
    id: demoUserId,
    fullName: 'Alex Morgan',
    role: 'customer',
  );

  static final List<BookingModel> _demoBookings = [
    BookingModel(
      id: 'BK-9024',
      customerId: demoUserId,
      courtId: 'a1111111-1111-1111-1111-111111111111',
      courtName: 'SmashCourt - Court 1',
      startTime: DateTime.now().add(const Duration(hours: 3)),
      endTime: DateTime.now().add(const Duration(hours: 4)),
      status: 'confirmed',
      totalAmount: 120.00,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static List<BookingModel> get demoBookings => List.unmodifiable(_demoBookings);

  static void addDemoBooking(BookingModel booking) {
    _demoBookings.insert(0, booking);
  }

  static void cancelDemoBooking(String bookingId) {
    final index = _demoBookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _demoBookings[index] = _demoBookings[index].copyWith(status: 'cancelled');
    }
  }

  static const List<CourtModel> mockCourts = [
    CourtModel(
      id: 'a1111111-1111-1111-1111-111111111111',
      name: 'SmashCourt - Court 1',
      status: 'active',
      hourlyRate: 120.0,
      surfaceType: 'Pro-Cushion Hardcourt',
      courtType: 'Championship Indoor',
    ),
  ];

  static bool isDemoUser(String? userId) => userId == demoUserId;
}
