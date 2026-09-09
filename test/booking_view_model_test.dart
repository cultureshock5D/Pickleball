import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/availability_slot.dart';
import 'package:pickleball_app/models/court_model.dart';
import 'package:pickleball_app/view_models/booking_view_model.dart';
import 'package:pickleball_app/view_models/dashboard_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookingViewModel Unit Tests', () {
    late BookingViewModel viewModel;

    setUp(() {
      viewModel = BookingViewModel();
    });

    test('Initial state has default values', () {
      expect(viewModel.durationHours, 1);
      expect(viewModel.paddleRental, isFalse);
      expect(viewModel.ballThrowerRental, isFalse);
      expect(viewModel.selectedSlot, isNull);
      expect(viewModel.totalPrice, 300.0);
    });

    test('Selecting duration updates total price', () {
      viewModel.selectDuration(2);
      expect(viewModel.durationHours, 2);
      expect(viewModel.courtSubtotal, 600.0);
      expect(viewModel.totalPrice, 600.0);
    });

    test('Toggling add-on rentals recalculates price accurately', () {
      viewModel.selectDuration(2); // ₱600
      viewModel.togglePaddleRental(true); // +₱150
      expect(viewModel.paddleFee, 150.0);
      expect(viewModel.totalPrice, 750.0);

      viewModel.toggleBallThrowerRental(true); // +₱150 * 2 = +₱300
      expect(viewModel.ballThrowerFee, 300.0);
      expect(viewModel.totalPrice, 1050.0);

      viewModel.togglePaddleRental(false); // -₱150
      expect(viewModel.totalPrice, 900.0);
    });

    test('Selecting court updates rate and court reference', () {
      const courtPremium = CourtModel(
        id: 'court-tour-2',
        name: 'Court 2 — Indoor (Tour Spec)',
        hourlyRate: 350.0,
      );

      viewModel.selectCourt(courtPremium);
      expect(viewModel.selectedCourt?.id, 'court-tour-2');
      expect(viewModel.currentHourlyRate, 350.0);
      expect(viewModel.totalPrice, 350.0);
    });

    test('Selecting available slot updates selectedSlot', () {
      const openSlot = AvailabilitySlot(
        hour24: 9,
        available: true,
      );
      const bookedSlot = AvailabilitySlot(
        hour24: 10,
        available: false,
      );

      viewModel.selectSlot(openSlot);
      expect(viewModel.selectedSlot?.hour24, 9);

      // Selecting booked slot should be ignored
      viewModel.selectSlot(bookedSlot);
      expect(viewModel.selectedSlot?.hour24, 9);
    });
  });

  group('DashboardViewModel Unit Tests', () {
    test('Filter tab switches properly', () {
      final dashboardVM = DashboardViewModel();
      expect(dashboardVM.activeTab, DashboardTab.upcoming);

      dashboardVM.setTab(DashboardTab.history);
      expect(dashboardVM.activeTab, DashboardTab.history);

      dashboardVM.setTab(DashboardTab.settings);
      expect(dashboardVM.activeTab, DashboardTab.settings);
    });
  });
}
