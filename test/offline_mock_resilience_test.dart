import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/services/auth_service.dart';
import 'package:pickleball_app/services/booking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockData.resetToDefault();
    BookingService.instance.invalidateAvailabilityCache();
  });

  tearDown(() async {
    await AuthService.instance.signOut();
    BookingService.instance.disposeRealtimeSubscription();
  });

  group('MockData Offline Repository & In-Memory Store', () {
    test('defaultCourts contains 4 fully specified active courts', () {
      const courts = MockData.defaultCourts;
      expect(courts, hasLength(4));

      for (final court in courts) {
        expect(court.id, isNotEmpty);
        expect(court.name, isNotEmpty);
        expect(court.hourlyRate, greaterThan(0));
        expect(court.isActive, isTrue);
        expect(['indoor', 'outdoor'], contains(court.type));
      }

      final courtIds = courts.map((c) => c.id).toList();
      expect(
        courtIds,
        containsAll([
          'court-1-indoor-cushion',
          'court-2-indoor-tour',
          'court-3-outdoor-lighted',
          'court-4-outdoor-acrylic',
        ]),
      );
    });

    test('venues contains 2 realistic venues with complete attributes', () {
      const venues = MockData.venues;
      expect(venues, hasLength(2));

      final bgc = venues.firstWhere((v) => v.name.contains('BGC'));
      expect(bgc.city, contains('Taguig'));
      expect(bgc.courtCount, equals(4));
      expect(bgc.rating, greaterThanOrEqualTo(4.0));
      expect(bgc.amenities, isNotEmpty);

      final alabang = venues.firstWhere((v) => v.name.contains('Alabang'));
      expect(alabang.city, contains('Muntinlupa'));
      expect(alabang.courtCount, equals(6));
      expect(alabang.amenities, isNotEmpty);
    });

    test('mockUserProfile provides standard Alex Morgan player identity', () {
      const profile = MockData.mockUserProfile;
      expect(profile.id, equals('mock-user-alex'));
      expect(profile.fullName, equals('Alex Morgan'));
      expect(profile.email, equals('alex.morgan@pickleball.dev'));
      expect(profile.phone, equals('+63 917 555 0192'));
      expect(profile.role, equals('client'));
    });

    test('In-memory _mockBookings mutations persist and filter accurately', () {
      final initialCount = MockData.mockBookings.length;
      expect(initialCount, greaterThanOrEqualTo(3));

      final testDate = DateTime(2026, 11, 10, 14);
      final created = MockData.createMockBooking(
        courtId: 'court-1-indoor-cushion',
        startTime: testDate,
        endTime: testDate.add(const Duration(hours: 1)),
        totalAmount: 300.0,
        userId: 'user-offline-test',
        guestEmail: 'test.user@pickleball.dev',
        status: 'pending_payment',
      );

      expect(MockData.mockBookings.length, equals(initialCount + 1));
      expect(created.id, isNotEmpty);
      expect(created.status, equals('pending_payment'));

      // Filter by court and date
      final dateOnly = DateTime(2026, 11, 10);
      final forDate = MockData.getBookingsForCourtAndDate('court-1-indoor-cushion', dateOnly);
      expect(forDate.any((b) => b.id == created.id), isTrue);

      // Filter by user ID / email
      final userBookings = MockData.getMockUserBookings('user-offline-test');
      expect(userBookings.any((b) => b.id == created.id), isTrue);

      // Mark as paid
      final paidBooking = MockData.markMockBookingAsPaid(
        created.id,
        paymongoSessionId: 'cs_test_offline_mark',
      );
      expect(paidBooking, isNotNull);
      expect(paidBooking!.isPaid, isTrue);
      expect(paidBooking.status, equals('paid'));
      expect(paidBooking.paymongoCheckoutSessionId, equals('cs_test_offline_mark'));

      // Cancel booking
      final cancelledBooking = MockData.cancelMockBooking(created.id);
      expect(cancelledBooking, isNotNull);
      expect(cancelledBooking!.status, equals('cancelled'));

      // Reset to default
      MockData.resetToDefault();
      expect(MockData.mockBookings.length, equals(initialCount));
      expect(MockData.mockBookings.any((b) => b.id == created.id), isFalse);
    });
  });

  group('BookingService Offline Fallback Queries', () {
    test('fetchActiveCourts returns mock courts in offline mode', () async {
      final courts = await BookingService.instance.fetchActiveCourts();
      expect(courts, isNotEmpty);
      expect(courts.length, equals(MockData.defaultCourts.length));
      for (final court in courts) {
        expect(court.isActive, isTrue);
        expect(court.status, isNot('inactive'));
      }
    });

    test('fetchCourtBookingsForDate returns mock bookings and populates cache', () async {
      final date = DateTime.now();
      const courtId = 'court-1-indoor-cushion';

      final bookings = await BookingService.instance.fetchCourtBookingsForDate(courtId, date);
      expect(bookings, isA<List<BookingModel>>());

      final cached = BookingService.instance.getCachedAvailability(courtId, date);
      expect(cached, isNotNull);
      expect(cached!.length, equals(bookings.length));
    });
  });

  group('BookingService.createBooking Offline Execution', () {
    test('Successfully creates booking for available slot, persists and invalidates cache', () async {
      final futureDate = DateTime.now().add(const Duration(days: 14));
      final slotStart = DateTime(futureDate.year, futureDate.month, futureDate.day, 9);
      final slotEnd = slotStart.add(const Duration(hours: 1));
      const courtId = 'court-1-indoor-cushion';

      // Pre-populate cache to verify invalidation
      await BookingService.instance.fetchCourtBookingsForDate(courtId, slotStart);
      expect(BookingService.instance.getCachedAvailability(courtId, slotStart), isNotNull);

      final booking = await BookingService.instance.createBooking(
        courtId: courtId,
        startTime: slotStart,
        endTime: slotEnd,
        totalAmount: 300.0,
        guestName: 'Jordan Vance',
        guestEmail: 'jordan.vance@example.com',
        guestPhone: '+63 917 555 1234',
        notes: 'Offline resilience test booking',
      );

      expect(booking.id, isNotEmpty);
      expect(booking.courtId, equals(courtId));
      expect(booking.startTime, equals(slotStart));
      expect(booking.endTime, equals(slotEnd));
      expect(booking.totalPrice, equals(300.0));
      expect(booking.guestName, equals('Jordan Vance'));
      expect(booking.status, equals('confirmed'));

      // Verify cache was invalidated
      expect(BookingService.instance.getCachedAvailability(courtId, slotStart), isNull);

      // Verify persistence in subsequent fetch
      final refreshed = await BookingService.instance.fetchCourtBookingsForDate(courtId, slotStart);
      expect(refreshed.any((b) => b.id == booking.id), isTrue);
    });

    test('Prevents double-booking: rejecting overlapping interval with exception', () async {
      final futureDate = DateTime.now().add(const Duration(days: 15));
      final slotStart = DateTime(futureDate.year, futureDate.month, futureDate.day, 14);
      final slotEnd = slotStart.add(const Duration(hours: 2));
      const courtId = 'court-2-indoor-tour';

      // Initial booking: 2:00 PM to 4:00 PM
      await BookingService.instance.createBooking(
        courtId: courtId,
        startTime: slotStart,
        endTime: slotEnd,
        totalAmount: 700.0,
      );

      // Overlapping booking: 3:00 PM to 5:00 PM (overlaps by 1 hour)
      final overlappingStart = slotStart.add(const Duration(hours: 1));
      final overlappingEnd = overlappingStart.add(const Duration(hours: 2));

      expect(
        () => BookingService.instance.createBooking(
          courtId: courtId,
          startTime: overlappingStart,
          endTime: overlappingEnd,
          totalAmount: 700.0,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Slot No Longer Available: Time interval already booked'),
          ),
        ),
      );
    });

    test('Validates input bounds on createBooking parameters', () async {
      final now = DateTime.now();

      // Empty courtId
      expect(
        () => BookingService.instance.createBooking(
          courtId: '   ',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          totalAmount: 300.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // startTime after endTime
      expect(
        () => BookingService.instance.createBooking(
          courtId: 'court-1-indoor-cushion',
          startTime: now.add(const Duration(hours: 2)),
          endTime: now.add(const Duration(hours: 1)),
          totalAmount: 300.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative totalAmount
      expect(
        () => BookingService.instance.createBooking(
          courtId: 'court-1-indoor-cushion',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          totalAmount: -50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('BookingService.cancelBooking 24-Hour Policy Enforcement', () {
    test('Permits cancellation for confirmed bookings 24+ hours in advance', () async {
      final advanceTime = DateTime.now().add(const Duration(days: 3));
      final booking = MockData.createMockBooking(
        courtId: 'court-1-indoor-cushion',
        startTime: advanceTime,
        endTime: advanceTime.add(const Duration(hours: 1)),
        totalAmount: 300.0,
      );

      expect(booking.isCancellable, isTrue);

      await expectLater(
        BookingService.instance.cancelBooking(booking),
        completes,
      );

      final updated = MockData.mockBookings.firstWhere((b) => b.id == booking.id);
      expect(updated.status, equals('cancelled'));
      expect(updated.isCancelled, isTrue);
    });

    test('Rejects cancellation for bookings less than 24 hours in advance', () async {
      final soonTime = DateTime.now().add(const Duration(hours: 12));
      final booking = MockData.createMockBooking(
        courtId: 'court-1-indoor-cushion',
        startTime: soonTime,
        endTime: soonTime.add(const Duration(hours: 1)),
        totalAmount: 300.0,
      );

      expect(booking.isCancellable, isFalse);

      expect(
        () => BookingService.instance.cancelBooking(booking),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Cancellations are only permitted 24+ hours in advance'),
          ),
        ),
      );
    });

    test('Rejects cancellation for pending or unpaid bookings', () async {
      final advanceTime = DateTime.now().add(const Duration(days: 4));
      final unpaidBooking = MockData.createMockBooking(
        courtId: 'court-1-indoor-cushion',
        startTime: advanceTime,
        endTime: advanceTime.add(const Duration(hours: 1)),
        totalAmount: 300.0,
        status: 'pending_payment',
      );

      expect(unpaidBooking.isCancellable, isFalse);

      expect(
        () => BookingService.instance.cancelBooking(unpaidBooking),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AuthService Offline Guest & Profile Behavior', () {
    test('isSupabaseReady reflects unconfigured offline environment', () {
      expect(AuthService.instance.isSupabaseReady, isFalse);
    });

    test('signInAsGuest creates active mock session and emits signedIn auth state', () async {
      final authStates = <AuthState>[];
      final subscription = AuthService.instance.authStateChanges.listen(authStates.add);

      final response = AuthService.instance.signInAsGuest(
        email: 'demo.player@pickleball.dev',
        fullName: 'Demo Player',
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(response.session, isNotNull);
      expect(response.user, isNotNull);
      expect(AuthService.instance.isAuthenticated, isTrue);
      expect(AuthService.instance.currentUser?.email, equals('demo.player@pickleball.dev'));
      expect(AuthService.instance.currentSession?.accessToken, isNotEmpty);

      expect(authStates, isNotEmpty);
      expect(authStates.last.event, equals(AuthChangeEvent.signedIn));

      await subscription.cancel();
    });

    test('updateUserProfile mutates offline user metadata and returns updated profile', () async {
      AuthService.instance.signInAsGuest();

      final updated = await AuthService.instance.updateUserProfile(
        fullName: 'Alex Superstar',
        phone: '+63 917 888 7766',
      );

      expect(updated.fullName, equals('Alex Superstar'));
      expect(updated.phone, equals('+63 917 888 7766'));

      final fetched = await AuthService.instance.fetchUserProfile();
      expect(fetched, isNotNull);
      expect(fetched!.fullName, equals('Alex Superstar'));
      expect(fetched.phone, equals('+63 917 888 7766'));
    });

    test('signOut clears mock session and emits signedOut event', () async {
      AuthService.instance.signInAsGuest();
      expect(AuthService.instance.isAuthenticated, isTrue);

      final authStates = <AuthState>[];
      final subscription = AuthService.instance.authStateChanges.listen(authStates.add);

      await AuthService.instance.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(AuthService.instance.isAuthenticated, isFalse);
      expect(AuthService.instance.currentUser, isNull);
      expect(AuthService.instance.currentSession, isNull);

      expect(authStates, isNotEmpty);
      expect(authStates.last.event, equals(AuthChangeEvent.signedOut));

      await subscription.cancel();
    });

    test('signIn and signUp offline create genuine mock credentials without throwing', () async {
      final signUpRes = await AuthService.instance.signUp(
        email: 'newplayer@example.com',
        password: 'Password123!',
        fullName: 'New Player',
      );
      expect(signUpRes.user?.email, equals('newplayer@example.com'));
      expect(signUpRes.session, isNotNull);

      await AuthService.instance.signOut();

      final signInRes = await AuthService.instance.signIn(
        email: 'newplayer@example.com',
        password: 'Password123!',
      );
      expect(signInRes.user?.email, equals('newplayer@example.com'));
      expect(signInRes.session, isNotNull);
    });
  });
}
