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
      endTime: DateTime.now().add(const Duration(hours: 4, minutes: 30)),
      status: 'confirmed',
      totalAmount: 180.00,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    BookingModel(
      id: 'BK-8911',
      customerId: demoUserId,
      courtId: 'b2222222-2222-2222-2222-222222222222',
      courtName: 'Court 2 - Neon Arena (LED)',
      startTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
      endTime: DateTime.now().add(const Duration(days: 1, hours: 3, minutes: 30)),
      status: 'pending',
      totalAmount: 225.00,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    BookingModel(
      id: 'BK-7840',
      customerId: demoUserId,
      courtId: 'c3333333-3333-3333-3333-333333333333',
      courtName: 'Court 3 - Skyline Rooftop',
      startTime: DateTime.now().subtract(const Duration(days: 3, hours: 4)),
      endTime: DateTime.now().subtract(const Duration(days: 3, hours: 2, minutes: 30)),
      status: 'completed',
      totalAmount: 150.00,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  static List<BookingModel> get demoBookings => List.unmodifiable(_demoBookings);

  static void addDemoBooking(BookingModel booking) {
    _demoBookings.insert(0, booking);
  }

  static void cancelDemoBooking(String bookingId) {
    final index = _demoBookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final old = _demoBookings[index];
      _demoBookings[index] = BookingModel(
        id: old.id,
        customerId: old.customerId,
        courtId: old.courtId,
        courtName: old.courtName,
        startTime: old.startTime,
        endTime: old.endTime,
        status: 'cancelled',
        totalAmount: old.totalAmount,
        createdAt: old.createdAt,
      );
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
    CourtModel(
      id: 'b2222222-2222-2222-2222-222222222222',
      name: 'Court 2 - Neon Arena (LED)',
      status: 'active',
      hourlyRate: 150.0,
      surfaceType: 'Ultra-Fast Acrylic',
      courtType: 'LED Glow Indoor',
    ),
    CourtModel(
      id: 'c3333333-3333-3333-3333-333333333333',
      name: 'Court 3 - Skyline Rooftop',
      status: 'active',
      hourlyRate: 100.0,
      surfaceType: 'All-Weather Surface',
      courtType: 'Rooftop Covered',
    ),
  ];

  static bool isDemoUser(String? userId) => userId == demoUserId;
}
