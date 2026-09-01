import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/widgets/check_in_qr_modal.dart';
import 'package:pickleball_app/widgets/downloadable_receipt_modal.dart';

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

  group('New Feature Widgets Tests', () {
    testWidgets('CheckInQrModal renders gate pass details and toggle action', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInQrModal(booking: sampleBooking),
          ),
        ),
      );

      expect(find.text('Smart Court Gate QR Pass'), findsOneWidget);
      expect(find.text('SmashCourt - Center Arena'), findsOneWidget);
      expect(find.text('UPCOMING - READY FOR CHECK-IN'), findsOneWidget);
      expect(find.text('Simulate Gate Scan (Check-In)'), findsOneWidget);

      // Tap Check-In action button to test state toggle
      await tester.tap(find.text('Simulate Gate Scan (Check-In)'));
      await tester.pumpAndSettle();

      expect(find.text('CHECKED IN • SESSION IN PROGRESS'), findsOneWidget);
      expect(find.text('Simulate Gate Scan (Check-Out)'), findsOneWidget);
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
