import '../models/booking_model.dart';
import '../models/court_model.dart';
import '../models/user_profile.dart';
import '../models/venue_model.dart';

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
      courtName: 'SmashCourt - Center Arena',
      startTime: DateTime.now().add(const Duration(hours: 3)),
      endTime: DateTime.now().add(const Duration(hours: 4, minutes: 30)),
      status: 'confirmed',
      totalAmount: 180.00,
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

  static const List<VenueModel> mockVenues = [
    VenueModel(
      id: 'venue-bcn-1',
      name: 'Barcelona Smash Club',
      city: 'Barcelona',
      address: 'Passeig Marítim 42, Diagonal Mar',
      rating: 4.95,
      reviewCount: 148,
      courtCount: 4,
      priceStartingAt: 120.0,
      tag: 'FEATURED',
      courtType: 'Championship Indoor & Glass',
      amenities: [
        'Pro Cushioning',
        'LED Glow Lighting',
        'Player Lounge',
        'Valet Parking',
        'Pro Shop',
      ],
    ),
    VenueModel(
      id: 'venue-dtn-2',
      name: 'SmashCourt Central Arena',
      city: 'Downtown Hub',
      address: '742 Grand Olympic Ave',
      rating: 4.88,
      reviewCount: 112,
      courtCount: 3,
      priceStartingAt: 140.0,
      tag: 'PREMIUM',
      courtType: 'Ultra-Fast Acrylic Indoor',
      amenities: [
        'A/C Climate Control',
        'Smooth Surface',
        'Beverage Bar',
        'Locker Rooms',
      ],
    ),
    VenueModel(
      id: 'venue-sky-3',
      name: 'Skyline Rooftop Club',
      city: 'Marina Heights',
      address: '88 Pinnacle Sky Tower, Level 42',
      rating: 4.92,
      reviewCount: 96,
      courtCount: 2,
      priceStartingAt: 160.0,
      tag: 'ROOFTOP',
      courtType: 'Covered Rooftop Panorama',
      amenities: [
        '360° Panoramic View',
        'Sunset Glow Lamps',
        'VIP Lounge',
        'Cocktail Bar',
      ],
    ),
    VenueModel(
      id: 'venue-grn-4',
      name: 'Green Valley Country Club',
      city: 'Suburban North',
      address: '12 Forest Hill Boulevard',
      rating: 4.82,
      reviewCount: 74,
      courtCount: 3,
      priceStartingAt: 100.0,
      tag: 'OUTDOOR',
      courtType: 'All-Weather Championship',
      amenities: [
        'Scenic Forest View',
        'Outdoor Lighting',
        'Spa & Sauna',
        'Coaching Clinics',
      ],
    ),
  ];

  static const List<CourtModel> mockCourts = [
    CourtModel(
      id: 'a1111111-1111-1111-1111-111111111111',
      name: 'Center Championship Court',
      status: 'active',
      hourlyRate: 120.0,
      surfaceType: 'Pro-Cushion Hardcourt',
      courtType: 'Championship Indoor',
      venueId: 'venue-bcn-1',
      venueName: 'Barcelona Smash Club',
    ),
    CourtModel(
      id: 'a2222222-2222-2222-2222-222222222222',
      name: 'Neon Glow Arena 2',
      status: 'active',
      hourlyRate: 150.0,
      surfaceType: 'Ultra-Fast Acrylic',
      courtType: 'LED Glow Indoor',
      venueId: 'venue-bcn-1',
      venueName: 'Barcelona Smash Club',
    ),
    CourtModel(
      id: 'a3333333-3333-3333-3333-333333333333',
      name: 'Glass Wall Showcase Court',
      status: 'active',
      hourlyRate: 135.0,
      surfaceType: 'Tour Grade Pro-Turf',
      courtType: 'Glass Enclosed Indoor',
      venueId: 'venue-bcn-1',
      venueName: 'Barcelona Smash Club',
    ),
    CourtModel(
      id: 'a4444444-4444-4444-4444-444444444444',
      name: 'VIP Skybox Court 4',
      status: 'active',
      hourlyRate: 160.0,
      surfaceType: 'High-Impact Resin',
      courtType: 'VIP Private Court',
      venueId: 'venue-bcn-1',
      venueName: 'Barcelona Smash Club',
    ),
    // Downtown Arena Courts
    CourtModel(
      id: 'b1111111-1111-1111-1111-111111111111',
      name: 'Central Arena - Court 1',
      status: 'active',
      hourlyRate: 140.0,
      surfaceType: 'Ultra-Fast Acrylic',
      courtType: 'Championship Indoor',
      venueId: 'venue-dtn-2',
      venueName: 'SmashCourt Central Arena',
    ),
    CourtModel(
      id: 'b2222222-2222-2222-2222-222222222222',
      name: 'Central Arena - Court 2',
      status: 'active',
      hourlyRate: 140.0,
      surfaceType: 'Pro Cushion',
      courtType: 'Indoor Standard',
      venueId: 'venue-dtn-2',
      venueName: 'SmashCourt Central Arena',
    ),
    // Skyline Rooftop Courts
    CourtModel(
      id: 'c1111111-1111-1111-1111-111111111111',
      name: 'Panorama Rooftop Court A',
      status: 'active',
      hourlyRate: 160.0,
      surfaceType: 'All-Weather Surface',
      courtType: 'Rooftop Covered',
      venueId: 'venue-sky-3',
      venueName: 'Skyline Rooftop Club',
    ),
    CourtModel(
      id: 'c2222222-2222-2222-2222-222222222222',
      name: 'Sunset Vista Court B',
      status: 'active',
      hourlyRate: 175.0,
      surfaceType: 'High-Impact Resin',
      courtType: 'Rooftop Open',
      venueId: 'venue-sky-3',
      venueName: 'Skyline Rooftop Club',
    ),
    // Green Valley Courts
    CourtModel(
      id: 'd1111111-1111-1111-1111-111111111111',
      name: 'Pine Court 1',
      status: 'active',
      hourlyRate: 100.0,
      surfaceType: 'All-Weather Surface',
      courtType: 'Outdoor Lighted',
      venueId: 'venue-grn-4',
      venueName: 'Green Valley Country Club',
    ),
  ];

  static bool isDemoUser(String? userId) => userId == demoUserId;
}
