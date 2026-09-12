import '../../core/constants/app_flavor.dart';

export '../../core/pagination/keyset_cursor.dart';
import '../../data/mock_data.dart';
import '../../models/availability_slot.dart';
import '../../models/booking_model.dart';
import '../../models/booking_refund_model.dart';
import '../../models/court_model.dart';
import '../../models/venue_model.dart' hide KeysetCursor, PaginatedChunk, PageChunk;
import '../../services/booking_service.dart';

/// Clean repository contract abstracting court booking operations and keyset pagination.
abstract class BookingRepository {
  /// Factory resolving the concrete repository based on [AppDataFlavor].
  factory BookingRepository.forFlavor([AppDataFlavor? flavor]) {
    final activeFlavor = flavor ?? AppFlavorConfig.currentFlavor;
    if (activeFlavor == AppDataFlavor.mock) {
      return MockBookingRepository();
    }
    return SupabaseBookingRepository();
  }

  // --- Keyset Cursor Paginated Methods ---

  /// Fetches a keyset-paginated chunk of customer bookings sorted by (created_at DESC, id DESC).
  Future<PageChunk<BookingModel>> fetchPaginatedCustomerBookings({
    String? userId,
    String? userEmail,
    KeysetCursor? cursor,
    int pageSize = 10,
  });

  /// Fetches a keyset-paginated chunk of venues sorted by (created_at DESC, id DESC).
  Future<PageChunk<VenueModel>> fetchPaginatedVenues({
    KeysetCursor? cursor,
    int pageSize = 10,
  });

  /// Fetches a keyset-paginated chunk of courts sorted by (created_at DESC, id DESC).
  Future<PageChunk<CourtModel>> fetchPaginatedCourts({
    KeysetCursor? cursor,
    int pageSize = 10,
    bool activeOnly = true,
  });

  /// Creates an atomic temporary booking hold with GiST exclusion conflict trapping.
  Future<BookingModel> createBookingHold({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
    String guestName = '',
    String guestEmail = '',
    String guestPhone = '',
    String? notes,
    int holdDurationMinutes = 10,
  });

  // --- Core & Backwards Compatibility Methods ---

  Future<List<CourtModel>> getActiveCourts();

  Future<List<AvailabilitySlot>> getDaySlots({
    required String courtId,
    required DateTime date,
    int durationHours = 1,
    double hourlyRate = BookingService.defaultHourlyRate,
  });

  Future<bool> checkSlotAvailability({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
  });

  double calculateTotalPrice({
    required double hourlyRate,
    required int durationHours,
    required bool paddleRental,
    required bool ballThrowerRental,
  });

  Future<Map<String, dynamic>> createPayMongoCheckout({
    required String courtId,
    required DateTime date,
    required int hour24,
    required int durationHours,
    required String guestName,
    required String guestEmail,
    required String guestPhone,
    bool paddleRental = false,
    bool ballThrowerRental = false,
  });

  Future<BookingModel> createBooking({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
    String guestName = '',
    String guestEmail = '',
    String guestPhone = '',
    String? notes,
  });

  Future<List<BookingModel>> getCustomerBookings();

  Future<void> cancelBooking(BookingModel booking);

  Future<BookingRefundModel> requestRefund({
    required String bookingId,
    required double amount,
    required String walletType,
    required String accountName,
    required String accountNumber,
    String? reason,
  });

  Future<BookingModel?> pollBookingPaidStatus(
    String bookingId, {
    int maxAttempts = 15,
    Duration interval = const Duration(seconds: 2),
  });
}

/// Mock implementation of [BookingRepository] that completely isolates [MockData].
/// Supports synthetic generation of 100+ items for heap and infinite scroll testing.
class MockBookingRepository implements BookingRepository {
  final List<BookingModel> _generatedBookings = [];

  MockBookingRepository();

  /// Generates [count] synthetic mock bookings with deterministic descending timestamps
  /// for stress testing keyset pagination and memory limits (>100 items).
  List<BookingModel> generateMockBookings(
    int count, {
    String? userId,
    String? userEmail,
  }) {
    final now = DateTime.now();
    final list = <BookingModel>[];

    for (int i = 1; i <= count; i++) {
      final createdTime = now.subtract(Duration(minutes: i * 15));
      final startTime = now.add(Duration(days: (i % 30) + 1, hours: 8 + (i % 10)));
      final id = 'mock-generated-booking-${i.toString().padLeft(4, '0')}';
      final booking = BookingModel(
        id: id,
        courtId: 'court-cushion-${(i % 4) + 1}',
        userId: userId ?? 'user-mock-123',
        guestName: 'Mock Player $i',
        guestEmail: userEmail ?? 'player$i@pickleball.dev',
        guestPhone: '+63917000${i.toString().padLeft(4, '0')}',
        startTime: startTime,
        endTime: startTime.add(const Duration(hours: 1)),
        totalPrice: 300.0 + (i % 3) * 150.0,
        status: i % 5 == 0 ? 'cancelled' : 'confirmed',
        createdAt: createdTime,
      );
      list.add(booking);
    }

    _generatedBookings.addAll(list);
    return list;
  }

  /// Clears synthetically generated bookings.
  void clearGeneratedBookings() {
    _generatedBookings.clear();
  }

  @override
  Future<PageChunk<BookingModel>> fetchPaginatedCustomerBookings({
    String? userId,
    String? userEmail,
    KeysetCursor? cursor,
    int pageSize = 10,
  }) async {
    if (pageSize <= 0) pageSize = 10;

    final allBookings = <BookingModel>[
      ...MockData.getMockUserBookings(userId, userEmail),
      ..._generatedBookings.where((b) {
        if (userId != null && b.userId != userId) return false;
        if (userEmail != null &&
            b.guestEmail.toLowerCase() != userEmail.toLowerCase()) {
          return false;
        }
        return true;
      }),
    ];

    // Stable keyset sorting: (created_at DESC, id DESC)
    allBookings.sort((a, b) {
      final aDate = a.createdAt ?? a.startTime;
      final bDate = b.createdAt ?? b.startTime;
      final cmp = bDate.compareTo(aDate);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });

    List<BookingModel> candidates = allBookings;
    if (cursor != null) {
      candidates = candidates.where((b) {
        final bDate = b.createdAt ?? b.startTime;
        if (bDate.isBefore(cursor.createdAt)) return true;
        if (bDate.isAtSameMomentAs(cursor.createdAt)) {
          return b.id.compareTo(cursor.id) < 0;
        }
        return false;
      }).toList();
    }

    final hasMore = candidates.length > pageSize;
    final pageItems = candidates.take(pageSize).toList();
    KeysetCursor? nextCursor;
    if (hasMore && pageItems.isNotEmpty) {
      final last = pageItems.last;
      nextCursor = KeysetCursor(
        createdAt: last.createdAt ?? last.startTime,
        id: last.id,
      );
    }

    return PageChunk<BookingModel>(
      items: pageItems,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  @override
  Future<PageChunk<VenueModel>> fetchPaginatedVenues({
    KeysetCursor? cursor,
    int pageSize = 10,
  }) async {
    return MockData.fetchPaginatedVenues(cursor: cursor, pageSize: pageSize);
  }

  @override
  Future<PageChunk<CourtModel>> fetchPaginatedCourts({
    KeysetCursor? cursor,
    int pageSize = 10,
    bool activeOnly = true,
  }) async {
    return MockData.fetchPaginatedCourts(
      cursor: cursor,
      pageSize: pageSize,
      activeOnly: activeOnly,
    );
  }

  @override
  Future<BookingModel> createBookingHold({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
    String guestName = '',
    String guestEmail = '',
    String guestPhone = '',
    String? notes,
    int holdDurationMinutes = 10,
  }) async {
    return MockData.createMockBookingHold(
      courtId: courtId,
      startTime: startTime,
      endTime: endTime,
      totalAmount: totalAmount,
      guestName: guestName.isNotEmpty ? guestName : 'Mock Player',
      guestEmail: guestEmail.isNotEmpty ? guestEmail : 'player@pickleball.dev',
      guestPhone: guestPhone,
      notes: notes,
      holdDurationMinutes: holdDurationMinutes,
    );
  }

  @override
  Future<List<CourtModel>> getActiveCourts() async =>
      MockData.getMockActiveCourts();

  @override
  Future<List<AvailabilitySlot>> getDaySlots({
    required String courtId,
    required DateTime date,
    int durationHours = 1,
    double hourlyRate = BookingService.defaultHourlyRate,
  }) async {
    return BookingService.instance.generateDaySlots(
      courtId: courtId,
      date: date,
      durationHours: durationHours,
      hourlyRate: hourlyRate,
    );
  }

  @override
  Future<bool> checkSlotAvailability({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final mockAvailable = MockData.checkMockCourtAvailability(
      courtId: courtId,
      startTime: startTime,
      endTime: endTime,
    );
    if (!mockAvailable) return false;

    final startUtc = startTime.toUtc();
    final endUtc = endTime.toUtc();
    for (final b in _generatedBookings) {
      if (b.courtId == courtId &&
          (b.status == 'confirmed' ||
              b.status == 'pending' ||
              b.status == 'paid' ||
              b.status == 'pending_payment')) {
        final bStart = b.startTime.toUtc();
        final bEnd = b.endTime.toUtc();
        if (startUtc.isBefore(bEnd) && endUtc.isAfter(bStart)) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  double calculateTotalPrice({
    required double hourlyRate,
    required int durationHours,
    required bool paddleRental,
    required bool ballThrowerRental,
  }) {
    return BookingService.calculateTotalPrice(
      hourlyRate: hourlyRate,
      durationHours: durationHours,
      paddleRental: paddleRental,
      ballThrowerRental: ballThrowerRental,
    );
  }

  @override
  Future<Map<String, dynamic>> createPayMongoCheckout({
    required String courtId,
    required DateTime date,
    required int hour24,
    required int durationHours,
    required String guestName,
    required String guestEmail,
    required String guestPhone,
    bool paddleRental = false,
    bool ballThrowerRental = false,
  }) async {
    return {
      'checkout_url': 'https://checkout.paymongo.mock/session-12345',
      'reference_number': 'REF-MOCK-CHECKOUT-001',
    };
  }

  @override
  Future<BookingModel> createBooking({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
    String guestName = '',
    String guestEmail = '',
    String guestPhone = '',
    String? notes,
  }) async {
    return MockData.createMockBooking(
      courtId: courtId,
      startTime: startTime,
      endTime: endTime,
      totalAmount: totalAmount,
      guestName: guestName,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
      notes: notes,
    );
  }

  @override
  Future<List<BookingModel>> getCustomerBookings() async {
    return [
      ...MockData.getMockUserBookings(),
      ..._generatedBookings,
    ];
  }

  @override
  Future<void> cancelBooking(BookingModel booking) async {
    MockData.cancelMockBooking(booking.id);
  }

  @override
  Future<BookingRefundModel> requestRefund({
    required String bookingId,
    required double amount,
    required String walletType,
    required String accountName,
    required String accountNumber,
    String? reason,
  }) async {
    return BookingRefundModel(
      id: 'mock-refund-${DateTime.now().millisecondsSinceEpoch}',
      bookingId: bookingId,
      amount: amount,
      walletType: walletType,
      accountName: accountName,
      accountNumber: accountNumber,
      reason: reason,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<BookingModel?> pollBookingPaidStatus(
    String bookingId, {
    int maxAttempts = 15,
    Duration interval = const Duration(seconds: 2),
  }) async {
    final bookings = await getCustomerBookings();
    final match = bookings.where((b) => b.id == bookingId).firstOrNull;
    if (match != null) {
      return match.copyWith(status: 'confirmed');
    }
    return null;
  }
}

/// Supabase implementation of [BookingRepository] delegating to [BookingService]
/// PostgREST keyset pagination and Realtime queries.
class SupabaseBookingRepository implements BookingRepository {
  final BookingService _service;

  SupabaseBookingRepository({BookingService? service})
      : _service = service ?? BookingService.instance;

  @override
  Future<PageChunk<BookingModel>> fetchPaginatedCustomerBookings({
    String? userId,
    String? userEmail,
    KeysetCursor? cursor,
    int pageSize = 10,
  }) {
    return _service.fetchPaginatedCustomerBookings(
      userId: userId,
      userEmail: userEmail,
      cursor: cursor,
      pageSize: pageSize,
    );
  }

  @override
  Future<PageChunk<VenueModel>> fetchPaginatedVenues({
    KeysetCursor? cursor,
    int pageSize = 10,
  }) {
    return _service.fetchPaginatedVenues(
      cursor: cursor,
      pageSize: pageSize,
    );
  }

  @override
  Future<PageChunk<CourtModel>> fetchPaginatedCourts({
    KeysetCursor? cursor,
    int pageSize = 10,
    bool activeOnly = true,
  }) {
    return _service.fetchPaginatedCourts(
      cursor: cursor,
      pageSize: pageSize,
      activeOnly: activeOnly,
    );
  }

  @override
  Future<BookingModel> createBookingHold({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
    String guestName = '',
    String guestEmail = '',
    String guestPhone = '',
    String? notes,
    int holdDurationMinutes = 10,
  }) {
    return _service.createBookingHold(
      courtId: courtId,
      startTime: startTime,
      endTime: endTime,
      totalAmount: totalAmount,
      guestName: guestName,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
      notes: notes,
      holdDurationMinutes: holdDurationMinutes,
    );
  }

  @override
  Future<List<CourtModel>> getActiveCourts() => _service.fetchActiveCourts();

  @override
  Future<List<AvailabilitySlot>> getDaySlots({
    required String courtId,
    required DateTime date,
    int durationHours = 1,
    double hourlyRate = BookingService.defaultHourlyRate,
  }) {
    return _service.generateDaySlots(
      courtId: courtId,
      date: date,
      durationHours: durationHours,
      hourlyRate: hourlyRate,
    );
  }

  @override
  Future<bool> checkSlotAvailability({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    return _service.checkSlotAvailability(
      courtId: courtId,
      startTime: startTime,
      endTime: endTime,
    );
  }

  @override
  double calculateTotalPrice({
    required double hourlyRate,
    required int durationHours,
    required bool paddleRental,
    required bool ballThrowerRental,
  }) {
    return BookingService.calculateTotalPrice(
      hourlyRate: hourlyRate,
      durationHours: durationHours,
      paddleRental: paddleRental,
      ballThrowerRental: ballThrowerRental,
    );
  }

  @override
  Future<Map<String, dynamic>> createPayMongoCheckout({
    required String courtId,
    required DateTime date,
    required int hour24,
    required int durationHours,
    required String guestName,
    required String guestEmail,
    required String guestPhone,
    bool paddleRental = false,
    bool ballThrowerRental = false,
  }) {
    return _service.createPayMongoCheckout(
      courtId: courtId,
      date: date,
      hour24: hour24,
      durationHours: durationHours,
      guestName: guestName,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
      paddleRental: paddleRental,
      ballThrowerRental: ballThrowerRental,
    );
  }

  @override
  Future<BookingModel> createBooking({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
    String guestName = '',
    String guestEmail = '',
    String guestPhone = '',
    String? notes,
  }) {
    return _service.createBooking(
      courtId: courtId,
      startTime: startTime,
      endTime: endTime,
      totalAmount: totalAmount,
      guestName: guestName,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
      notes: notes,
    );
  }

  @override
  Future<List<BookingModel>> getCustomerBookings() =>
      _service.fetchCustomerBookings();

  @override
  Future<void> cancelBooking(BookingModel booking) =>
      _service.cancelBooking(booking);

  @override
  Future<BookingRefundModel> requestRefund({
    required String bookingId,
    required double amount,
    required String walletType,
    required String accountName,
    required String accountNumber,
    String? reason,
  }) {
    return _service.requestRefund(
      bookingId: bookingId,
      amount: amount,
      walletType: walletType,
      accountName: accountName,
      accountNumber: accountNumber,
      reason: reason,
    );
  }

  @override
  Future<BookingModel?> pollBookingPaidStatus(
    String bookingId, {
    int maxAttempts = 15,
    Duration interval = const Duration(seconds: 2),
  }) {
    return _service.pollBookingPaidStatus(
      bookingId,
      maxAttempts: maxAttempts,
      interval: interval,
    );
  }
}
