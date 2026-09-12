import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/constants/app_flavor.dart';
import 'package:pickleball_app/data/repositories/booking_repository.dart';
import 'package:pickleball_app/models/court_model.dart';
import 'package:pickleball_app/services/booking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingRepository repository;

  setUp(() {
    repository = SupabaseBookingRepository();
  });

  tearDown(() {
    AppFlavorConfig.setFlavorOverride(null);
  });

  group('BookingRepository Core Unit Tests', () {
    test('calculateTotalPrice computes court subtotal, paddle fee and ball thrower fee', () {
      // 1 hour, standard rate, no add-ons
      final total1 = repository.calculateTotalPrice(
        hourlyRate: 300.0,
        durationHours: 1,
        paddleRental: false,
        ballThrowerRental: false,
      );
      expect(total1, 300.0);

      // 2 hours + paddle bundle (+₱150)
      final total2 = repository.calculateTotalPrice(
        hourlyRate: 300.0,
        durationHours: 2,
        paddleRental: true,
        ballThrowerRental: false,
      );
      expect(total2, 600.0 + 150.0); // ₱750

      // 2 hours + paddle bundle (+₱150) + ball thrower (+₱150/hr * 2 = ₱300)
      final total3 = repository.calculateTotalPrice(
        hourlyRate: 300.0,
        durationHours: 2,
        paddleRental: true,
        ballThrowerRental: true,
      );
      expect(total3, 600.0 + 150.0 + 300.0); // ₱1050
    });

    test('Court pricing constants match C&J UI-Context rules', () {
      expect(BookingService.defaultHourlyRate, 300.0);
      expect(BookingService.paddleRentalFee, 150.0);
      expect(BookingService.ballThrowerHourlyFee, 150.0);
    });

    test('CourtModel serialization and helper properties', () {
      const court = CourtModel(
        id: 'court-cushion-1',
        name: 'Court 1 — Indoor (Pro Cushion)',
      );

      expect(court.isIndoor, isTrue);
      expect(court.isOutdoor, isFalse);
      expect(court.isAvailableForBooking, isTrue);
      expect(court.surfaceDescription, 'Pro Cushion Surface');
      expect(court.courtBadge, 'Indoor Championship');

      final json = court.toJson();
      final fromJson = CourtModel.fromJson(json);
      expect(fromJson.id, court.id);
      expect(fromJson.hourlyRate, 300.0);
      expect(fromJson.name, court.name);
    });
  });

  group('BookingRepository Abstraction & Flavor Switching', () {
    test('Factory returns MockBookingRepository when flavor is AppDataFlavor.mock', () {
      final repo = BookingRepository.forFlavor(AppDataFlavor.mock);
      expect(repo, isA<MockBookingRepository>());
    });

    test('Factory returns SupabaseBookingRepository when flavor is AppDataFlavor.supabase', () {
      final repo = BookingRepository.forFlavor(AppDataFlavor.supabase);
      expect(repo, isA<SupabaseBookingRepository>());
    });

    test('AppFlavorConfig runtime override switches active repository dynamically', () {
      AppFlavorConfig.setFlavorOverride(AppDataFlavor.mock);
      expect(AppFlavorConfig.isMock, isTrue);
      expect(BookingRepository.forFlavor(), isA<MockBookingRepository>());

      AppFlavorConfig.setFlavorOverride(AppDataFlavor.supabase);
      expect(AppFlavorConfig.isSupabase, isTrue);
      expect(BookingRepository.forFlavor(), isA<SupabaseBookingRepository>());
    });
  });

  group('MockBookingRepository Keyset Pagination & Stress Testing', () {
    late MockBookingRepository mockRepo;

    setUp(() {
      mockRepo = MockBookingRepository();
    });

    test('Keyset paginates customer bookings without duplicates', () async {
      // Fetch Page 1 with limit 2
      final page1 = await mockRepo.fetchPaginatedCustomerBookings(pageSize: 2);
      expect(page1.items.length, 2);
      expect(page1.hasMore, isTrue);
      expect(page1.nextCursor, isNotNull);

      // Fetch Page 2 with limit 2 using cursor
      final page2 = await mockRepo.fetchPaginatedCustomerBookings(
        cursor: page1.nextCursor,
        pageSize: 2,
      );
      expect(page2.items.isNotEmpty, isTrue);

      // Invariant: Zero duplicate bookings across pagination chunks
      final page1Ids = page1.items.map((b) => b.id).toSet();
      for (final b in page2.items) {
        expect(page1Ids.contains(b.id), isFalse, reason: 'Duplicate ID detected in next chunk: ${b.id}');
      }
    });

    test('Stress test: 100+ generated bookings traversed with 0 duplicate records', () async {
      // Generate 120 deterministic mock bookings
      final generated = mockRepo.generateMockBookings(120);
      expect(generated.length, 120);

      final collectedIds = <String>{};
      KeysetCursor? cursor;
      int chunkCount = 0;
      bool hasMore = true;

      while (hasMore) {
        final chunk = await mockRepo.fetchPaginatedCustomerBookings(
          cursor: cursor,
          pageSize: 25,
        );
        chunkCount++;

        for (final b in chunk.items) {
          final added = collectedIds.add(b.id);
          expect(added, isTrue, reason: 'Keyset pagination produced duplicate booking: ${b.id}');
        }

        hasMore = chunk.hasMore;
        cursor = chunk.nextCursor;

        if (chunkCount > 20) {
          fail('Infinite pagination loop detected');
        }
      }

      // 120 generated + default seed bookings
      expect(collectedIds.length, greaterThanOrEqualTo(120));
    });

    test('fetchPaginatedVenues and fetchPaginatedCourts keyset contracts', () async {
      final venuesChunk = await mockRepo.fetchPaginatedVenues(pageSize: 5);
      expect(venuesChunk.items.isNotEmpty, isTrue);

      final courtsChunk = await mockRepo.fetchPaginatedCourts(pageSize: 5);
      expect(courtsChunk.items.isNotEmpty, isTrue);
    });

    test('createBookingHold creates valid hold with pending_payment status', () async {
      final now = DateTime.now();
      final hold = await mockRepo.createBookingHold(
        courtId: 'court-cushion-1',
        startTime: now.add(const Duration(days: 1, hours: 2)),
        endTime: now.add(const Duration(days: 1, hours: 3)),
        totalAmount: 300.0,
        guestName: 'Carlos Alcaraz',
        guestEmail: 'carlos@padel.pro',
      );

      expect(hold.id, isNotEmpty);
      expect(hold.courtId, 'court-cushion-1');
      expect(hold.status, 'pending_payment');
      expect(hold.guestName, 'Carlos Alcaraz');
    });
  });
}
