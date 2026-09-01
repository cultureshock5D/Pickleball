import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/services/calendar_link_service.dart';
import 'package:pickleball_app/widgets/booking_success_modal.dart';
import 'package:pickleball_app/widgets/reservation_card.dart';

void main() {
  group('CalendarLinkService Unit Tests', () {
    test('formatUtcDateTime formats exact UTC ISO 8601 template strings (YYYYMMDDTHHmmSSZ)', () {
      final dateTime = DateTime.utc(2026, 8, 29, 5, 0, 0);
      final formatted = CalendarLinkService.formatUtcDateTime(dateTime);

      expect(formatted, equals('20260829T050000Z'));
    });

    test('formatUtcDateTime converts local time to UTC properly', () {
      // Create a local time with known UTC conversion
      final localDateTime = DateTime(2026, 8, 29, 13, 30, 45);
      final expectedUtc = localDateTime.toUtc();
      final expectedString =
          '${expectedUtc.year.toString().padLeft(4, '0')}'
          '${expectedUtc.month.toString().padLeft(2, '0')}'
          '${expectedUtc.day.toString().padLeft(2, '0')}T'
          '${expectedUtc.hour.toString().padLeft(2, '0')}'
          '${expectedUtc.minute.toString().padLeft(2, '0')}'
          '${expectedUtc.second.toString().padLeft(2, '0')}Z';

      final result = CalendarLinkService.formatUtcDateTime(localDateTime);
      expect(result, equals(expectedString));
    });

    test('buildGoogleCalendarUri constructs zero-auth deep link with query parameters', () {
      final start = DateTime.utc(2026, 8, 29, 5, 0, 0);
      final end = DateTime.utc(2026, 8, 29, 7, 0, 0);

      final uri = CalendarLinkService.buildGoogleCalendarUri(
        title: 'Pickleball @ SmashCourt - Court 1',
        startTime: start,
        endTime: end,
        details: 'Reservation ID: BK-9024\nPrice: ₱67.50',
        location: 'SmashCourt Arena - Center Championship',
      );

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('calendar.google.com'));
      expect(uri.path, equals('/calendar/render'));
      expect(uri.queryParameters['action'], equals('TEMPLATE'));
      expect(uri.queryParameters['text'], equals('Pickleball @ SmashCourt - Court 1'));
      expect(uri.queryParameters['dates'], equals('20260829T050000Z/20260829T070000Z'));
      expect(uri.queryParameters['details'], contains('BK-9024'));
      expect(uri.queryParameters['location'], equals('SmashCourt Arena - Center Championship'));
    });

    test('buildGoogleCalendarUrl generates valid URL string with encoded parameters', () {
      final start = DateTime.utc(2026, 8, 29, 13, 0, 0);
      final end = DateTime.utc(2026, 8, 29, 15, 0, 0);

      final url = CalendarLinkService.buildGoogleCalendarUrl(
        title: 'Court Match #1',
        startTime: start,
        endTime: end,
      );

      expect(url, startsWith('https://calendar.google.com/calendar/render?'));
      expect(url, contains('action=TEMPLATE'));
      expect(url, contains('text=Court+Match+%231'));
      expect(url, contains('dates=20260829T130000Z%2F20260829T150000Z'));
    });
  });

  group('Booking Confirmation Widget Tests', () {
    final testBooking = BookingModel(
      id: 'BK-9999-TEST',
      customerId: 'user-123',
      courtId: 'court-1',
      courtName: 'Court 1 - Center Championship',
      startTime: DateTime(2026, 8, 29, 13, 0),
      endTime: DateTime(2026, 8, 29, 15, 0),
      status: 'confirmed',
      totalAmount: 67.50,
      createdAt: DateTime(2026, 8, 27),
    );

    testWidgets('BookingSuccessModal renders reservation details and Google Calendar button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingSuccessModal(
              booking: testBooking,
              venueName: 'SmashCourt Arena',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and court details
      expect(find.text('Reservation Confirmed!'), findsOneWidget);
      expect(find.text('Court 1 - Center Championship'), findsOneWidget);
      expect(find.text('SmashCourt Arena'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('₱67.50'), findsOneWidget);
      expect(find.text('BK-9999-TEST'), findsOneWidget);

      // Check Primary & Secondary CTA Buttons
      expect(find.text('Add to Google Calendar'), findsOneWidget);
      expect(find.text('Done • View My Bookings'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    });

    testWidgets('ReservationCard renders quick action buttons and Google Calendar action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReservationCard(
              booking: testBooking,
              isUpcoming: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Court 1 - Center Championship'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('₱67.50'), findsOneWidget);
      expect(find.text('Gate Pass'), findsOneWidget);
      expect(find.text('Receipt'), findsOneWidget);
      expect(find.byIcon(Icons.event_available_rounded), findsOneWidget);
    });
  });
}
