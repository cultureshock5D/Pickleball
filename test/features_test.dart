import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/models/court_model.dart';
import 'package:pickleball_app/widgets/check_in_qr_modal.dart';
import 'package:pickleball_app/widgets/downloadable_receipt_modal.dart';
import 'package:pickleball_app/widgets/reservation_card.dart';
import 'package:pickleball_app/widgets/time_player_picker_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleBooking = BookingModel(
    id: 'BK-TEST-100',
    userId: 'cust-1',
    courtId: 'court-1',
    courtName: 'C&J Pickleball - Court 1',
    startTime: DateTime(2025, 5, 20, 10),
    endTime: DateTime(2025, 5, 20, 11),
    status: 'confirmed',
    totalPrice: 300.00,
    createdAt: DateTime.now(),
  );

  group('CourtModel Pricing & Cancellation Logic Tests', () {
    test('Calculates court rates and cancellation eligibility accurately', () {
      const court = CourtModel(
        id: 'court-1',
        name: 'Court 1',
      );

      expect(court.hourlyRate, 300.0);
      expect(court.type, 'indoor');

      final cancellableBooking = BookingModel(
        id: 'BK-CANCEL-1',
        courtId: 'court-1',
        startTime: DateTime.now().add(const Duration(hours: 48)),
        endTime: DateTime.now().add(const Duration(hours: 49)),
        status: 'confirmed',
        totalPrice: 300.0,
      );
      expect(cancellableBooking.isCancellable, isTrue);

      final nonCancellableBooking = BookingModel(
        id: 'BK-CANCEL-2',
        courtId: 'court-1',
        startTime: DateTime.now().add(const Duration(hours: 12)),
        endTime: DateTime.now().add(const Duration(hours: 13)),
        status: 'confirmed',
        totalPrice: 300.0,
      );
      expect(nonCancellableBooking.isCancellable, isFalse);
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
      expect(find.text('C&J Pickleball - Court 1'), findsOneWidget);
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
      expect(selection!.totalAmount, 300.0);
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
      expect(find.text('₱300.00'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);
      expect(find.text('Share Receipt'), findsOneWidget);
    });

    testWidgets('ReservationCard renders booking details and actions correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReservationCard(
              booking: sampleBooking,
            ),
          ),
        ),
      );

      expect(find.text('C&J Pickleball - Court 1'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('₱300.00'), findsOneWidget);
      expect(find.text('Gate Pass'), findsOneWidget);
      expect(find.text('Receipt'), findsOneWidget);
      expect(find.byIcon(Icons.event_available_rounded), findsOneWidget);

      // Verify tap on ReservationCard scales and responds
      await tester.tap(find.byType(ReservationCard));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    });
  });
}
