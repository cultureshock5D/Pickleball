import '../../models/availability_slot.dart';
import '../../models/booking_model.dart';
import '../../models/booking_refund_model.dart';
import '../../models/court_model.dart';
import '../../services/booking_service.dart';

abstract class BookingRepository {
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

class SupabaseBookingRepository implements BookingRepository {
  final BookingService _service;

  SupabaseBookingRepository({BookingService? service})
      : _service = service ?? BookingService.instance;

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
