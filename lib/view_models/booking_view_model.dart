import 'package:flutter/foundation.dart';
import '../data/repositories/booking_repository.dart';
import '../models/availability_slot.dart';
import '../models/booking_model.dart';
import '../models/court_model.dart';

/// ViewModel managing the entire court reservation flow, slot generation,
/// add-on rentals, and PayMongo checkout initiation.
class BookingViewModel extends ChangeNotifier {
  final BookingRepository _repository;

  BookingViewModel({BookingRepository? repository})
      : _repository = repository ?? SupabaseBookingRepository();

  List<CourtModel> _courts = [];
  List<CourtModel> get courts => _courts;

  CourtModel? _selectedCourt;
  CourtModel? get selectedCourt => _selectedCourt;

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  int _durationHours = 1;
  int get durationHours => _durationHours;

  List<AvailabilitySlot> _slots = [];
  List<AvailabilitySlot> get slots => _slots;

  AvailabilitySlot? _selectedSlot;
  AvailabilitySlot? get selectedSlot => _selectedSlot;

  bool _paddleRental = false;
  bool get paddleRental => _paddleRental;

  bool _ballThrowerRental = false;
  bool get ballThrowerRental => _ballThrowerRental;

  bool _isLoadingCourts = false;
  bool get isLoadingCourts => _isLoadingCourts;

  bool _isLoadingSlots = false;
  bool get isLoadingSlots => _isLoadingSlots;

  bool _isCheckingOut = false;
  bool get isCheckingOut => _isCheckingOut;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  double get currentHourlyRate => _selectedCourt?.hourlyRate ?? 300.0;

  double get totalPrice => _repository.calculateTotalPrice(
        hourlyRate: currentHourlyRate,
        durationHours: _durationHours,
        paddleRental: _paddleRental,
        ballThrowerRental: _ballThrowerRental,
      );

  double get courtSubtotal => currentHourlyRate * _durationHours;
  double get paddleFee => _paddleRental ? 150.0 : 0.0;
  double get ballThrowerFee => _ballThrowerRental ? (150.0 * _durationHours) : 0.0;

  Future<void> loadCourts() async {
    _isLoadingCourts = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.getActiveCourts();
      _courts = fetched;
      if (_courts.isNotEmpty && _selectedCourt == null) {
        _selectedCourt = _courts.first;
      }
      await refreshSlots();
    } catch (e) {
      _errorMessage = 'Failed to load courts: $e';
    } finally {
      _isLoadingCourts = false;
      notifyListeners();
    }
  }

  void selectCourt(CourtModel court) {
    if (_selectedCourt?.id == court.id) return;
    _selectedCourt = court;
    _selectedSlot = null;
    notifyListeners();
    refreshSlots();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    _selectedSlot = null;
    notifyListeners();
    refreshSlots();
  }

  void selectDuration(int hours) {
    if (hours < 1 || hours > 12) return;
    _durationHours = hours;
    _selectedSlot = null;
    notifyListeners();
    refreshSlots();
  }

  void selectSlot(AvailabilitySlot slot) {
    if (!slot.available) return;
    _selectedSlot = slot;
    notifyListeners();
  }

  void togglePaddleRental(bool value) {
    _paddleRental = value;
    notifyListeners();
  }

  void toggleBallThrowerRental(bool value) {
    _ballThrowerRental = value;
    notifyListeners();
  }

  Future<void> refreshSlots() async {
    if (_selectedCourt == null) return;
    _isLoadingSlots = true;
    notifyListeners();

    try {
      final generatedSlots = await _repository.getDaySlots(
        courtId: _selectedCourt!.id,
        date: _selectedDate,
        durationHours: _durationHours,
        hourlyRate: currentHourlyRate,
      );
      _slots = generatedSlots;

      // Retain selection if still valid
      if (_selectedSlot != null) {
        final matchIndex = _slots.indexWhere(
          (s) => s.hour24 == _selectedSlot!.hour24 && s.available,
        );
        _selectedSlot = matchIndex != -1 ? _slots[matchIndex] : null;
      }
    } catch (e) {
      _errorMessage = 'Failed to load slots: $e';
    } finally {
      _isLoadingSlots = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> initiatePayMongoCheckout({
    required String guestName,
    required String guestEmail,
    required String guestPhone,
  }) async {
    if (_selectedCourt == null || _selectedSlot == null) {
      throw StateError('Must select a court and available time slot.');
    }

    _isCheckingOut = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repository.createPayMongoCheckout(
        courtId: _selectedCourt!.id,
        date: _selectedDate,
        hour24: _selectedSlot!.hour24,
        durationHours: _durationHours,
        guestName: guestName,
        guestEmail: guestEmail,
        guestPhone: guestPhone,
        paddleRental: _paddleRental,
        ballThrowerRental: _ballThrowerRental,
      );
      return res;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isCheckingOut = false;
      notifyListeners();
    }
  }

  Future<BookingModel> createDirectBooking({
    required String guestName,
    required String guestEmail,
    required String guestPhone,
    String? notes,
  }) async {
    if (_selectedCourt == null || _selectedSlot == null) {
      throw StateError('Must select a court and available time slot.');
    }

    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedSlot!.hour24,
    );
    final end = start.add(Duration(hours: _durationHours));

    _isCheckingOut = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final booking = await _repository.createBooking(
        courtId: _selectedCourt!.id,
        startTime: start,
        endTime: end,
        totalAmount: totalPrice,
        guestName: guestName,
        guestEmail: guestEmail,
        guestPhone: guestPhone,
        notes: notes,
      );
      return booking;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isCheckingOut = false;
      notifyListeners();
    }
  }
}
