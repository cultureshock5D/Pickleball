import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/validators.dart';
import '../models/booking_model.dart';
import '../models/court_model.dart';
import '../models/user_profile.dart';
import '../models/venue_model.dart';

/// Fallback mock repository providing realistic venues, courts, seed bookings,
/// and an in-memory mutable store for offline preview and resilient testing.
class MockData {
  MockData._();

  // --- Venues ---
  static const List<VenueModel> venues = [
    VenueModel(
      id: 'venue-bgc-prime',
      name: 'C&J Court — BGC Prime Club',
      city: 'Taguig, Metro Manila',
      address: '9th Ave & 28th St, Bonifacio Global City',
      rating: 4.95,
      reviewCount: 342,
      amenities: [
        'Pro Cushion Surface',
        'LED Tournament Lighting',
        'Player Lounge & Cafe',
        'Locker & Shower Facilities',
        'Equipment Pro Shop',
      ],
      priceStartingAt: 280.0,
      tag: 'PREMIUM',
      courtType: 'Indoor & Outdoor',
    ),
    VenueModel(
      id: 'venue-alabang-center',
      name: 'C&J Court — Alabang Sports Hub',
      city: 'Muntinlupa, Metro Manila',
      address: 'Commerce Ave, Filinvest City, Alabang',
      rating: 4.88,
      reviewCount: 184,
      amenities: [
        'Tour Spec Acrylic',
        'Covered Outdoor Courts',
        'Refreshment Bar',
        'Free Parking',
      ],
      courtCount: 6,
      priceStartingAt: 250.0,
      courtType: 'Championship Covered',
    ),
  ];

  // --- Courts ---
  static const List<CourtModel> defaultCourts = [
    CourtModel(
      id: 'court-1-indoor-cushion',
      name: 'Court 1 — Indoor (Pro Cushion)',
    ),
    CourtModel(
      id: 'court-2-indoor-tour',
      name: 'Court 2 — Indoor (Tour Spec)',
      hourlyRate: 350.0,
    ),
    CourtModel(
      id: 'court-3-outdoor-lighted',
      name: 'Court 3 — Outdoor (Lighted)',
      type: 'outdoor',
      hourlyRate: 280.0,
    ),
    CourtModel(
      id: 'court-4-outdoor-acrylic',
      name: 'Court 4 — Outdoor (Championship Acrylic)',
      type: 'outdoor',
      hourlyRate: 320.0,
    ),
  ];

  /// Active courts getter alias
  static List<CourtModel> get courts => getMockActiveCourts();

  /// Retrieve active courts
  static List<CourtModel> getMockActiveCourts() {
    return defaultCourts
        .where((c) => c.status == 'active' && c.isActive)
        .toList();
  }

  // --- User Profile ---
  static const UserProfile mockUserProfile = UserProfile(
    id: 'mock-user-alex',
    fullName: 'Alex Morgan',
    email: 'alex.morgan@pickleball.dev',
    phone: '+63 917 555 0192',
  );

  // --- In-Memory Mutable Bookings Store ---
  static final List<BookingModel> _mockBookings = [];
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (!_initialized) {
      resetToDefault();
    }
  }

  /// Reset in-memory booking store to initial seed state
  static void resetToDefault() {
    _mockBookings.clear();
    _mockBookings.addAll(_generateSeedBookings());
    _initialized = true;
  }

  /// Generate realistic seed bookings for past, present, and upcoming dates
  static List<BookingModel> _generateSeedBookings() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));

    final court1 = defaultCourts[0];
    final court2 = defaultCourts[1];
    final court3 = defaultCourts[2];

    return [
      // Today: 8:00 AM - 9:00 AM (Court 1, Paid/Confirmed) - Alex Morgan
      BookingModel(
        id: 'seed-bk-today-0800',
        courtId: court1.id,
        court: court1,
        courtName: court1.name,
        userId: mockUserProfile.id,
        guestName: mockUserProfile.fullName ?? 'Alex Morgan',
        guestEmail: mockUserProfile.email ?? 'alex.morgan@pickleball.dev',
        guestPhone: mockUserProfile.phone ?? '+63 917 555 0192',
        startTime: today.add(const Duration(hours: 8)),
        endTime: today.add(const Duration(hours: 9)),
        totalPrice: court1.hourlyRate,
        status: 'confirmed',
        notes: 'Morning singles training',
        createdAt: yesterday,
      ),

      // Today: 2:00 PM - 3:00 PM (Court 1, Paid) - Other player (Occupies slot)
      BookingModel(
        id: 'seed-bk-today-1400',
        courtId: court1.id,
        court: court1,
        courtName: court1.name,
        userId: 'player-marcus-02',
        guestName: 'Marcus Brody',
        guestEmail: 'marcus.brody@example.com',
        startTime: today.add(const Duration(hours: 14)),
        endTime: today.add(const Duration(hours: 15)),
        totalPrice: court1.hourlyRate,
        status: 'paid',
        createdAt: yesterday,
      ),

      // Today: 6:00 PM - 8:00 PM (Court 2, 2 hours, Confirmed) - Elena Torres
      BookingModel(
        id: 'seed-bk-today-1800',
        courtId: court2.id,
        court: court2,
        courtName: court2.name,
        userId: 'player-elena-03',
        guestName: 'Elena Torres',
        guestEmail: 'elena.t@example.com',
        startTime: today.add(const Duration(hours: 18)),
        endTime: today.add(const Duration(hours: 20)),
        durationHours: 2,
        totalPrice: court2.hourlyRate * 2,
        status: 'confirmed',
        notes: 'Doubles league preparation',
        createdAt: yesterday,
      ),

      // Tomorrow: 10:00 AM - 11:00 AM (Court 1, Paid) - Alex Morgan
      BookingModel(
        id: 'seed-bk-tomorrow-1000',
        courtId: court1.id,
        court: court1,
        courtName: court1.name,
        userId: mockUserProfile.id,
        guestName: mockUserProfile.fullName ?? 'Alex Morgan',
        guestEmail: mockUserProfile.email ?? 'alex.morgan@pickleball.dev',
        guestPhone: mockUserProfile.phone ?? '+63 917 555 0192',
        startTime: tomorrow.add(const Duration(hours: 10)),
        endTime: tomorrow.add(const Duration(hours: 11)),
        totalPrice: court1.hourlyRate,
        status: 'paid',
        createdAt: today,
      ),

      // Tomorrow: 4:00 PM - 5:00 PM (Court 3, Confirmed) - Alex Morgan
      BookingModel(
        id: 'seed-bk-tomorrow-1600',
        courtId: court3.id,
        court: court3,
        courtName: court3.name,
        userId: mockUserProfile.id,
        guestName: mockUserProfile.fullName ?? 'Alex Morgan',
        guestEmail: mockUserProfile.email ?? 'alex.morgan@pickleball.dev',
        guestPhone: mockUserProfile.phone ?? '+63 917 555 0192',
        startTime: tomorrow.add(const Duration(hours: 16)),
        endTime: tomorrow.add(const Duration(hours: 17)),
        totalPrice: court3.hourlyRate,
        status: 'confirmed',
        createdAt: today,
      ),

      // Yesterday: 9:00 AM - 10:00 AM (Court 1, Checked In) - Alex Morgan
      BookingModel(
        id: 'seed-bk-yesterday-0900',
        courtId: court1.id,
        court: court1,
        courtName: court1.name,
        userId: mockUserProfile.id,
        guestName: mockUserProfile.fullName ?? 'Alex Morgan',
        guestEmail: mockUserProfile.email ?? 'alex.morgan@pickleball.dev',
        guestPhone: mockUserProfile.phone ?? '+63 917 555 0192',
        startTime: yesterday.add(const Duration(hours: 9)),
        endTime: yesterday.add(const Duration(hours: 10)),
        totalPrice: court1.hourlyRate,
        status: 'checked_in',
        createdAt: yesterday.subtract(const Duration(days: 1)),
      ),
    ];
  }

  /// All current in-memory mock bookings (read-only copy)
  static List<BookingModel> get mockBookings {
    _ensureInitialized();
    return List.unmodifiable(_mockBookings);
  }

  /// Query bookings for a specific court and calendar date
  static List<BookingModel> getBookingsForCourtAndDate(
    String courtId,
    DateTime date,
  ) {
    _ensureInitialized();
    return _mockBookings.where((b) {
      if (b.courtId != courtId) return false;
      if (b.isCancelled || b.isHoldExpired || b.isVoid) {
        return false;
      }

      final start = b.startTime;
      return start.year == date.year &&
          start.month == date.month &&
          start.day == date.day;
    }).toList();
  }

  /// Query all bookings for a user by user ID or email
  static List<BookingModel> getMockUserBookings([
    String? userId,
    String? userEmail,
  ]) {
    _ensureInitialized();
    final uid = userId?.trim();
    final email = userEmail?.trim().toLowerCase();

    final userList = _mockBookings.where((b) {
      if (uid != null && uid.isNotEmpty && b.userId == uid) return true;
      if (email != null && email.isNotEmpty && b.guestEmail.toLowerCase() == email) {
        return true;
      }
      if (uid == null && (email == null || email.isEmpty)) {
        // Default to demo user's bookings
        return b.userId == mockUserProfile.id ||
            b.guestEmail.toLowerCase() == mockUserProfile.email!.toLowerCase();
      }
      return false;
    }).toList();

    // Sort descending by start time
    userList.sort((a, b) => b.startTime.compareTo(a.startTime));
    return userList;
  }

  /// Create and persist an in-memory mock booking
  static BookingModel createMockBooking({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
    String guestName = '',
    String guestEmail = '',
    String guestPhone = '',
    String? userId,
    String? paymongoCheckoutSessionId,
    String? notes,
    String status = 'confirmed',
    String paymentMethod = 'paymongo',
  }) {
    _ensureInitialized();

    final court = defaultCourts.firstWhere(
      (c) => c.id == courtId,
      orElse: () => CourtModel(
        id: courtId,
        name: 'Pickleball Court',
        hourlyRate: totalAmount > 0 ? totalAmount : 300.0,
      ),
    );

    final durationHours = endTime.difference(startTime).inHours;
    final booking = BookingModel(
      id: 'mock-bk-${DateTime.now().millisecondsSinceEpoch}',
      courtId: courtId,
      court: court,
      courtName: court.name,
      userId: userId ?? mockUserProfile.id,
      guestName: guestName.isNotEmpty
          ? guestName
          : (mockUserProfile.fullName ?? 'Player'),
      guestEmail: guestEmail.isNotEmpty
          ? guestEmail
          : (mockUserProfile.email ?? 'player@pickleball.dev'),
      guestPhone: guestPhone.isNotEmpty
          ? guestPhone
          : (mockUserProfile.phone ?? ''),
      startTime: startTime,
      endTime: endTime,
      durationHours: durationHours > 0 ? durationHours : 1,
      totalPrice: totalAmount,
      status: status,
      paymentMethod: paymentMethod,
      paymongoCheckoutSessionId: paymongoCheckoutSessionId,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _mockBookings.add(booking);
    return booking;
  }

  /// Cancel an in-memory mock booking
  static BookingModel? cancelMockBooking(String bookingId) {
    _ensureInitialized();
    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final updated = _mockBookings[index].copyWith(
        status: 'cancelled',
        updatedAt: DateTime.now(),
      );
      _mockBookings[index] = updated;
      return updated;
    }
    return null;
  }

  /// Mark an in-memory mock booking as paid
  static BookingModel? markMockBookingAsPaid(
    String bookingId, {
    String? paymongoSessionId,
    String status = 'paid',
  }) {
    _ensureInitialized();
    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final current = _mockBookings[index];

      // Check if another booking was already paid for this exact court & overlapping time
      final alreadyPaidOverlap = _mockBookings.any((b) =>
          b.id != current.id &&
          b.courtId == current.courtId &&
          b.isPaid &&
          Validators.hasTimeOverlap(
            newStart: current.startTime,
            newEnd: current.endTime,
            existingStart: b.startTime,
            existingEnd: b.endTime,
          ));

      if (alreadyPaidOverlap) {
        // Someone booked and paid faster -> this booking is VOID
        final voided = current.copyWith(
          status: 'void',
          notes: 'Slot was secured and paid by another player first.',
          updatedAt: DateTime.now(),
        );
        _mockBookings[index] = voided;
        return voided;
      }

      final updated = current.copyWith(
        status: status,
        paymongoCheckoutSessionId:
            paymongoSessionId ?? current.paymongoCheckoutSessionId,
        updatedAt: DateTime.now(),
      );
      _mockBookings[index] = updated;

      // Void any other pending bookings for the same court and overlapping time
      for (int i = 0; i < _mockBookings.length; i++) {
        final b = _mockBookings[i];
        if (b.id != updated.id &&
            b.courtId == updated.courtId &&
            (b.status == 'pending_payment' || b.status == 'pending') &&
            Validators.hasTimeOverlap(
              newStart: updated.startTime,
              newEnd: updated.endTime,
              existingStart: b.startTime,
              existingEnd: b.endTime,
            )) {
          _mockBookings[i] = b.copyWith(
            status: 'void',
            notes: 'Slot was secured and paid by another player first.',
            updatedAt: DateTime.now(),
          );
        }
      }
      return updated;
    }
    return null;
  }

  /// Create and persist an in-memory mock booking hold with 23P01 concurrency check
  static BookingModel createMockBookingHold({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
    String guestName = '',
    String guestEmail = '',
    String guestPhone = '',
    String? userId,
    String? notes,
    int holdDurationMinutes = 10,
  }) {
    _ensureInitialized();

    if (courtId.trim().isEmpty) {
      throw ArgumentError.value(courtId, 'courtId', 'Court ID cannot be empty');
    }
    if (!startTime.isBefore(endTime)) {
      throw ArgumentError('startTime must be before endTime');
    }
    if (totalAmount < 0) {
      throw ArgumentError.value(totalAmount, 'totalAmount', 'Total amount must be non-negative');
    }

    final now = DateTime.now();

    // 1. Lazy cleanup of expired holds on this court
    for (int i = 0; i < _mockBookings.length; i++) {
      final b = _mockBookings[i];
      if (b.courtId == courtId &&
          (b.status == 'pending' || b.status == 'pending_payment') &&
          b.expiresAt != null &&
          b.expiresAt!.isBefore(now)) {
        _mockBookings[i] = b.copyWith(
          status: 'expired',
          updatedAt: now,
        );
      }
    }

    // 2. Check for overlapping active reservations on this court
    // (status NOT IN ('cancelled', 'cancelled_refund_pending', 'expired'))
    final hasOverlap = _mockBookings.any((b) {
      if (b.courtId != courtId) return false;
      if (b.status == 'cancelled' ||
          b.status == 'cancelled_refund_pending' ||
          b.status == 'expired') {
        return false;
      }
      return Validators.hasTimeOverlap(
        newStart: startTime,
        newEnd: endTime,
        existingStart: b.startTime,
        existingEnd: b.endTime,
      );
    });

    if (hasOverlap) {
      throw const PostgrestException(
        message: 'Slot is no longer available: Another player has reserved this time.',
        code: '23P01',
        details: 'GiST exclusion constraint violation on court slot interval.',
      );
    }

    // 3. Create the hold booking
    final court = defaultCourts.firstWhere(
      (c) => c.id == courtId,
      orElse: () => CourtModel(
        id: courtId,
        name: 'Pickleball Court',
        hourlyRate: totalAmount > 0 ? totalAmount : 300.0,
      ),
    );

    final durationHours = endTime.difference(startTime).inHours;
    final expiresAt = now.add(Duration(minutes: holdDurationMinutes));

    final hold = BookingModel(
      id: 'mock-hold-${now.millisecondsSinceEpoch}',
      courtId: courtId,
      court: court,
      courtName: court.name,
      userId: userId ?? mockUserProfile.id,
      guestName: guestName.isNotEmpty
          ? guestName
          : (mockUserProfile.fullName ?? 'Player'),
      guestEmail: guestEmail.isNotEmpty
          ? guestEmail
          : (mockUserProfile.email ?? 'player@pickleball.dev'),
      guestPhone: guestPhone.isNotEmpty
          ? guestPhone
          : (mockUserProfile.phone ?? ''),
      startTime: startTime,
      endTime: endTime,
      durationHours: durationHours > 0 ? durationHours : 1,
      totalPrice: totalAmount,
      expiresAt: expiresAt,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    _mockBookings.add(hold);
    return hold;
  }

  /// Keyset paginated customer bookings sorted by (created_at DESC, id DESC)
  static PaginatedChunk<BookingModel> fetchPaginatedCustomerBookings({
    String? userId,
    String? userEmail,
    KeysetCursor? cursor,
    int pageSize = 10,
  }) {
    _ensureInitialized();
    final allUserBookings = getMockUserBookings(userId, userEmail);

    // Stable keyset sorting: created_at DESC, id DESC
    allUserBookings.sort((a, b) {
      final aDate = a.createdAt ?? a.startTime;
      final bDate = b.createdAt ?? b.startTime;
      final cmp = bDate.compareTo(aDate);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });

    List<BookingModel> candidates = allUserBookings;
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
    final items = candidates.take(pageSize).toList();
    KeysetCursor? nextCursor;
    if (hasMore && items.isNotEmpty) {
      final last = items.last;
      nextCursor = KeysetCursor(
        createdAt: last.createdAt ?? last.startTime,
        id: last.id,
      );
    }

    return PaginatedChunk<BookingModel>(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  /// Keyset paginated venues sorted by (created_at DESC, id DESC)
  static PaginatedChunk<VenueModel> fetchPaginatedVenues({
    KeysetCursor? cursor,
    int pageSize = 10,
  }) {
    final list = List<VenueModel>.from(venues);
    list.sort((a, b) {
      final aDate = _effectiveVenueCreatedAt(a);
      final bDate = _effectiveVenueCreatedAt(b);
      final cmp = bDate.compareTo(aDate);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });

    List<VenueModel> candidates = list;
    if (cursor != null) {
      candidates = candidates.where((v) {
        final vDate = _effectiveVenueCreatedAt(v);
        if (vDate.isBefore(cursor.createdAt)) return true;
        if (vDate.isAtSameMomentAs(cursor.createdAt)) {
          return v.id.compareTo(cursor.id) < 0;
        }
        return false;
      }).toList();
    }

    final hasMore = candidates.length > pageSize;
    final items = candidates.take(pageSize).toList();
    KeysetCursor? nextCursor;
    if (hasMore && items.isNotEmpty) {
      final last = items.last;
      nextCursor = KeysetCursor(
        createdAt: _effectiveVenueCreatedAt(last),
        id: last.id,
      );
    }

    return PaginatedChunk<VenueModel>(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  /// Keyset paginated courts sorted by (created_at DESC, id DESC)
  static PaginatedChunk<CourtModel> fetchPaginatedCourts({
    KeysetCursor? cursor,
    int pageSize = 10,
    bool activeOnly = true,
  }) {
    var list = defaultCourts.toList();
    if (activeOnly) {
      list = list.where((c) => c.status == 'active' && c.isActive).toList();
    }

    list.sort((a, b) {
      final aDate = _effectiveCourtCreatedAt(a);
      final bDate = _effectiveCourtCreatedAt(b);
      final cmp = bDate.compareTo(aDate);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });

    List<CourtModel> candidates = list;
    if (cursor != null) {
      candidates = candidates.where((c) {
        final cDate = _effectiveCourtCreatedAt(c);
        if (cDate.isBefore(cursor.createdAt)) return true;
        if (cDate.isAtSameMomentAs(cursor.createdAt)) {
          return c.id.compareTo(cursor.id) < 0;
        }
        return false;
      }).toList();
    }

    final hasMore = candidates.length > pageSize;
    final items = candidates.take(pageSize).toList();
    KeysetCursor? nextCursor;
    if (hasMore && items.isNotEmpty) {
      final last = items.last;
      nextCursor = KeysetCursor(
        createdAt: _effectiveCourtCreatedAt(last),
        id: last.id,
      );
    }

    return PaginatedChunk<CourtModel>(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  static DateTime _effectiveVenueCreatedAt(VenueModel v) {
    if (v.createdAt != null) return v.createdAt!;
    switch (v.id) {
      case 'venue-bgc-prime':
        return DateTime.utc(2026, 8, 1, 10);
      case 'venue-alabang-center':
        return DateTime.utc(2026, 8, 5, 12);
      default:
        return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  static DateTime _effectiveCourtCreatedAt(CourtModel c) {
    if (c.createdAt != null) return c.createdAt!;
    switch (c.id) {
      case 'court-1-indoor-cushion':
        return DateTime.utc(2026, 8, 1, 8);
      case 'court-2-indoor-tour':
        return DateTime.utc(2026, 8, 1, 9);
      case 'court-3-outdoor-lighted':
        return DateTime.utc(2026, 8, 1, 10);
      case 'court-4-outdoor-acrylic':
        return DateTime.utc(2026, 8, 1, 11);
      default:
        return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  /// Add a mock booking directly into the in-memory store (useful for tests)
  static void addMockBooking(BookingModel booking) {
    _ensureInitialized();
    _mockBookings.add(booking);
  }

  /// Clear all mock bookings
  static void clearMockBookings() {
    _mockBookings.clear();
    _initialized = true;
  }

  /// Check if a court slot is available (no confirmed or pending overlapping bookings)
  static bool checkMockCourtAvailability({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    _ensureInitialized();
    final startUtc = startTime.toUtc();
    final endUtc = endTime.toUtc();
    for (final b in _mockBookings) {
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
}

