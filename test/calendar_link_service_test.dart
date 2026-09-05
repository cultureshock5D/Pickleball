import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/services/calendar_link_service.dart';
import 'package:pickleball_app/widgets/booking_success_modal.dart';
import 'package:pickleball_app/widgets/reservation_card.dart';

void main() {
  group('CalendarLinkService Unit Tests - Google Calendar', () {
    test('formatUtcDateTime formats exact UTC ISO 8601 template strings (YYYYMMDDTHHmmSSZ)', () {
      final dateTime = DateTime.utc(2026, 8, 29, 5);
      final formatted = CalendarLinkService.formatUtcDateTime(dateTime);

      expect(formatted, equals('20260829T050000Z'));
    });

    test('formatUtcDateTime converts local time to UTC properly', () {
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
      final start = DateTime.utc(2026, 8, 29, 5);
      final end = DateTime.utc(2026, 8, 29, 7);

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
      final start = DateTime.utc(2026, 8, 29, 13);
      final end = DateTime.utc(2026, 8, 29, 15);

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

    test('buildGoogleCalendarUri sanitizes control characters and clamps lengths', () {
      final start = DateTime.utc(2026, 8, 29, 8);
      final end = DateTime.utc(2026, 8, 29, 10);
      const overlyLongTitle =
          'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      const dirtyLocation = 'Venue\u0000\u001F Name';

      final uri = CalendarLinkService.buildGoogleCalendarUri(
        title: overlyLongTitle,
        startTime: start,
        endTime: end,
        location: dirtyLocation,
      );

      expect(uri.queryParameters['text']?.length, equals(120));
      expect(uri.queryParameters['location'], equals('Venue Name'));
    });
  });

  group('CalendarLinkService Unit Tests - RFC 5545 ICS Generator', () {
    test('buildIcsCalendarData generates standard RFC 5545 VCALENDAR and VEVENT payload', () {
      final start = DateTime.utc(2026, 8, 29, 6);
      final end = DateTime.utc(2026, 8, 29, 8);

      final ics = CalendarLinkService.buildIcsCalendarData(
        title: 'SmashCourt Championship',
        startTime: start,
        endTime: end,
        details: 'Booking Ref: BK-1001',
        location: 'Center Court',
        uid: 'UID-12345-TEST',
        status: 'TENTATIVE',
      );

      expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(ics, contains('VERSION:2.0\r\n'));
      expect(ics, contains('PRODID:-//Pickleball App//EN\r\n'));
      expect(ics, contains('CALSCALE:GREGORIAN\r\n'));
      expect(ics, contains('BEGIN:VEVENT\r\n'));
      expect(ics, contains('UID:UID-12345-TEST\r\n'));
      expect(ics, contains('DTSTART:20260829T060000Z\r\n'));
      expect(ics, contains('DTEND:20260829T080000Z\r\n'));
      expect(ics, contains('SUMMARY:SmashCourt Championship\r\n'));
      expect(ics, contains('DESCRIPTION:Booking Ref: BK-1001\r\n'));
      expect(ics, contains('LOCATION:Center Court\r\n'));
      expect(ics, contains('STATUS:TENTATIVE\r\n'));
      expect(ics, endsWith('END:VEVENT\r\nEND:VCALENDAR'));
    });

    test('buildIcsCalendarData generates fallback UID when none provided', () {
      final start = DateTime.utc(2026, 8, 29, 6);
      final end = DateTime.utc(2026, 8, 29, 8);

      final ics = CalendarLinkService.buildIcsCalendarData(
        title: 'Morning Practice',
        startTime: start,
        endTime: end,
      );

      expect(ics, contains('UID:'));
      expect(ics, contains('@smashcourt.app'));
    });

    test('buildIcsCalendarData sanitizes control characters and clamps fields', () {
      final start = DateTime.utc(2026, 8, 29, 9);
      final end = DateTime.utc(2026, 8, 29, 11);
      const dirtyTitle = 'Court\u0000 1\u200E \u202A';
      const dirtyDetails = 'Details\u001F here';

      final ics = CalendarLinkService.buildIcsCalendarData(
        title: dirtyTitle,
        startTime: start,
        endTime: end,
        details: dirtyDetails,
        status: 'confirmed',
      );

      expect(ics, contains('SUMMARY:Court 1'));
      expect(ics, contains('DESCRIPTION:Details here'));
      expect(ics, contains('STATUS:CONFIRMED'));
    });
  });

  group('CalendarLinkService Unit Tests - Apple Calendar', () {
    test('buildAppleCalendarUrl creates RFC 5545 compliant data URL with encoded ICS', () {
      final start = DateTime.utc(2026, 8, 29, 14);
      final end = DateTime.utc(2026, 8, 29, 16);

      final url = CalendarLinkService.buildAppleCalendarUrl(
        title: 'Pickleball Match',
        startTime: start,
        endTime: end,
        details: 'Court 3 VIP',
        location: 'Barcelona Smash Club',
      );

      expect(url, startsWith('data:text/calendar;charset=utf8,'));
      final encodedPayload = url.substring('data:text/calendar;charset=utf8,'.length);
      final decoded = Uri.decodeComponent(encodedPayload);

      expect(decoded, contains('BEGIN:VCALENDAR'));
      expect(decoded, contains('SUMMARY:Pickleball Match'));
      expect(decoded, contains('LOCATION:Barcelona Smash Club'));
      expect(decoded, contains('DTSTART:20260829T140000Z'));
      expect(decoded, contains('DTEND:20260829T160000Z'));
      expect(decoded, contains('END:VCALENDAR'));
    });
  });

  group('CalendarLinkService Unit Tests - Outlook Calendar', () {
    test('buildOutlookCalendarUrl constructs Outlook Live compose deep link', () {
      final start = DateTime.utc(2026, 8, 29, 10);
      final end = DateTime.utc(2026, 8, 29, 12);

      final url = CalendarLinkService.buildOutlookCalendarUrl(
        title: 'Semifinals Match',
        startTime: start,
        endTime: end,
        details: 'Ref: BK-9988',
        location: 'Court 2',
      );

      expect(url, startsWith('https://outlook.live.com/calendar/0/deeplink/compose?'));
      final uri = Uri.parse(url);

      expect(uri.host, equals('outlook.live.com'));
      expect(uri.path, equals('/calendar/0/deeplink/compose'));
      expect(uri.queryParameters['path'], equals('/calendar/action/compose'));
      expect(uri.queryParameters['rru'], equals('addevent'));
      expect(uri.queryParameters['startdt'], equals('2026-08-29T10:00:00.000Z'));
      expect(uri.queryParameters['enddt'], equals('2026-08-29T12:00:00.000Z'));
      expect(uri.queryParameters['subject'], equals('Semifinals Match'));
      expect(uri.queryParameters['body'], equals('Ref: BK-9988'));
      expect(uri.queryParameters['location'], equals('Court 2'));
    });

    test('buildOutlookCalendarUrl omits empty optional parameters', () {
      final start = DateTime.utc(2026, 8, 29, 10);
      final end = DateTime.utc(2026, 8, 29, 12);

      final url = CalendarLinkService.buildOutlookCalendarUrl(
        title: 'Quick Match',
        startTime: start,
        endTime: end,
      );

      final uri = Uri.parse(url);
      expect(uri.queryParameters.containsKey('body'), isFalse);
      expect(uri.queryParameters.containsKey('location'), isFalse);
    });

    test('buildOutlookCalendarUrl sanitizes control characters', () {
      final start = DateTime.utc(2026, 8, 29, 10);
      final end = DateTime.utc(2026, 8, 29, 12);

      final url = CalendarLinkService.buildOutlookCalendarUrl(
        title: 'Match\u0000\u001F #5',
        startTime: start,
        endTime: end,
        details: 'Sanitized\u0000 Details',
        location: 'Court\u200E #1',
      );

      final uri = Uri.parse(url);
      expect(uri.queryParameters['subject'], equals('Match #5'));
      expect(uri.queryParameters['body'], equals('Sanitized Details'));
      expect(uri.queryParameters['location'], equals('Court #1'));
    });
  });

  group('CalendarLinkService Unit Tests - Link Launcher', () {
    test('launchCalendarLink handles invalid URL safely', () async {
      final result = await CalendarLinkService.launchCalendarLink('::not-a-valid-uri::');
      expect(result, isFalse);
    });
  });

  group('Booking Confirmation Widget Tests', () {
    final testBooking = BookingModel(
      id: 'BK-9999-TEST',
      customerId: 'user-123',
      courtId: 'court-1',
      courtName: 'Court 1 - Center Championship',
      startTime: DateTime(2026, 8, 29, 13),
      endTime: DateTime(2026, 8, 29, 15),
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
