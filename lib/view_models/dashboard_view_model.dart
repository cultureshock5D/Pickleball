import 'package:flutter/foundation.dart';
import '../data/repositories/booking_repository.dart';
import '../models/booking_model.dart';
import '../models/booking_refund_model.dart';

enum DashboardTab { upcoming, history, settings }

/// ViewModel managing the player portal / dashboard state,
/// match history filtering, session telemetry, and cancellation/refund actions.
class DashboardViewModel extends ChangeNotifier {
  final BookingRepository _repository;

  DashboardViewModel({BookingRepository? repository})
      : _repository = repository ?? SupabaseBookingRepository();

  List<BookingModel> _bookings = [];
  List<BookingModel> get bookings => _bookings;

  DashboardTab _activeTab = DashboardTab.upcoming;
  DashboardTab get activeTab => _activeTab;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isProcessingAction = false;
  bool get isProcessingAction => _isProcessingAction;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<BookingModel> get upcomingBookings {
    final now = DateTime.now();
    return _bookings.where((b) {
      final isConfirmed = b.status == 'paid' ||
          b.status == 'checked_in' ||
          b.status == 'confirmed' ||
          b.status == 'walk_in';
      return isConfirmed && b.startTime.isAfter(now);
    }).toList();
  }

  List<BookingModel> get pastBookings {
    final now = DateTime.now();
    return _bookings.where((b) {
      return b.endTime.isBefore(now) &&
          b.status != 'cancelled' &&
          b.status != 'cancelled_refund_pending';
    }).toList();
  }

  List<BookingModel> get cancelledBookings {
    return _bookings.where((b) {
      return b.status == 'cancelled' ||
          b.status == 'cancelled_refund_pending' ||
          b.status == 'expired';
    }).toList();
  }

  int get totalSessions => _bookings.where((b) => b.isPaid || b.isCheckedIn).length;

  int get totalCourtHours => _bookings
      .where((b) => b.isPaid || b.isCheckedIn)
      .fold<int>(0, (sum, b) => sum + b.durationHours);

  void setTab(DashboardTab tab) {
    if (_activeTab == tab) return;
    _activeTab = tab;
    notifyListeners();
  }

  Future<void> loadBookings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await _repository.getCustomerBookings();
      _bookings = list;
    } catch (e) {
      _errorMessage = 'Failed to load bookings: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelBooking(BookingModel booking) async {
    _isProcessingAction = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.cancelBooking(booking);
      await loadBookings();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isProcessingAction = false;
      notifyListeners();
    }
  }

  Future<BookingRefundModel> requestRefund({
    required String bookingId,
    required double amount,
    required String walletType,
    required String accountName,
    required String accountNumber,
    String? reason,
  }) async {
    _isProcessingAction = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final refund = await _repository.requestRefund(
        bookingId: bookingId,
        amount: amount,
        walletType: walletType,
        accountName: accountName,
        accountNumber: accountNumber,
        reason: reason,
      );
      await loadBookings();
      return refund;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isProcessingAction = false;
      notifyListeners();
    }
  }
}
