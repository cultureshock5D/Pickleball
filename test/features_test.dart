import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/models/court_model.dart';
import 'package:pickleball_app/widgets/check_in_qr_modal.dart';
import 'package:pickleball_app/widgets/downloadable_receipt_modal.dart';
import 'package:pickleball_app/widgets/time_player_picker_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleBooking = BookingModel(
    id: 'BK-TEST-100',
    customerId: 'cust-1',
    courtId: 'court-1',
    courtName: 'SmashCourt - Center Arena',
    startTime: DateTime(2025, 5, 20, 10, 0),
    endTime: DateTime(2025, 5, 20, 11, 30),
    status: 'confirmed',
    totalAmount: 180.00,
    createdAt: DateTime.now(),
  );

  group('CourtModel Peak Pricing Logic Tests', () {
    test('Calculates peak vs off-peak rates accurately', () {
      const court = CourtModel(
        id: 'court-1',
        name: 'Championship Arena',
        hourlyRate: 120.0,
        peakHourlyRate: 180.0,
        peakStartHour: 17,
        peakEndHour: 22,
      );

      expect(court.isPeakHour(10), isFalse);
      expect(court.rateForHour(10), 120.0);

      expect(court.isPeakHour(17), isTrue);
      expect(court.rateForHour(17), 180.0);

      expect(court.isPeakHour(21), isTrue);
      expect(court.rateForHour(21), 180.0);

      expect(court.isPeakHour(22), isFalse);
      expect(court.rateForHour(22), 120.0);
    });
  });

  group('New Feature Widgets Tests', () {
    testWidgets('CheckInQrModal renders gate pass details, countdown and toggle action', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInQrModal(booking: sampleBooking),
          ),
        ),
      );

      expect(find.text('Smart Court Gate QR Pass'), findsOneWidget);
      expect(find.text('SmashCourt - Center Arena'), findsOneWidget);
      expect(find.text('UPCOMING • READY FOR GATE'), findsOneWidget);
      expect(find.text('Simulate Gate Scan (Check-In)'), findsOneWidget);

      // Tap Check-In action button to test state toggle
      await tester.tap(find.text('Simulate Gate Scan (Check-In)'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CHECKED IN • SESSION ACTIVE'), findsOneWidget);
      expect(find.text('Simulate Gate Scan (Check-Out)'), findsOneWidget);
    });

    testWidgets('TimePlayerPickerModal renders peak and off-peak badges', (WidgetTester tester) async {
      MatchTimeSelection? selection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimePlayerPickerModal(
              availableTimes: const [
                TimeOfDay(hour: 10, minute: 0),
                TimeOfDay(hour: 18, minute: 0),
              ],
              initialTimeSlotIndex: 0,
              hourlyRate: 120.0,
              peakHourlyRate: 180.0,
              peakStartHour: 17,
              peakEndHour: 22,
              onSelectionConfirmed: (sel) => selection = sel,
            ),
          ),
        ),
      );

      expect(find.text('Select Match Time Slot'), findsOneWidget);
      expect(find.text('PEAK'), findsOneWidget);
      expect(find.text('Off-Peak'), findsOneWidget);
      expect(find.text('Confirm Match Time Slot'), findsOneWidget);

      await tester.tap(find.text('Confirm Match Time Slot'));
      expect(selection, isNotNull);
      expect(selection!.totalAmount, 120.0);
    });

    testWidgets('DownloadableReceiptModal renders invoice breakdown and download CTA', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadableReceiptModal(booking: sampleBooking),
          ),
        ),
      );

      expect(find.text('Official Payment Receipt'), findsOneWidget);
      expect(find.text('PayMongo Transaction Confirmed'), findsOneWidget);
      expect(find.text('BK-TEST-100'), findsOneWidget);
      expect(find.text('TOTAL PAID'), findsOneWidget);
      expect(find.text('₱180.00'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);
      expect(find.text('Share Receipt'), findsOneWidget);
    });
  });
}
