import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/utils/validators.dart';
import '../models/booking_model.dart';

/// Zero-Auth, Zero-API Deep Link and RFC 5545 Service for Multi-Calendar integration.
///
/// Constructs direct event creation URLs and RFC 5545 payloads for Google Calendar,
/// Apple Calendar, Outlook Online, and generic `.ics` files without requiring
/// external OAuth credentials, APIs, or client secrets.
class CalendarLinkService {
  CalendarLinkService._();

  static const String _googleCalendarBaseUrl = 'https://calendar.google.com/calendar/render';
  static const String _outlookCalendarBaseUrl = 'https://outlook.live.com/calendar/0/deeplink/compose';

  /// Converts a [DateTime] (local or UTC) into the UTC ISO 8601 template string
  /// format required by Google Calendar and RFC 5545: `YYYYMMDDTHHmmSSZ`.
  ///
  /// Example:
  /// Local: August 29, 2026 13:00:00 (UTC+8) -> `20260829T050000Z`
  static String formatUtcDateTime(DateTime dateTime) {
    final utc = dateTime.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');

    return '$year$month${day}T$hour$minute${second}Z';
  }

  /// Constructs the standard Google Calendar deep link [Uri].
  ///
  /// Enforces parameter sanitization and safe length boundaries to prevent URL overflow.
  /// Format:
  /// `https://calendar.google.com/calendar/render?action=TEMPLATE&text=[Title]&dates=[StartUTC]/[EndUTC]&details=[Details]&location=[Venue]`
  static Uri buildGoogleCalendarUri({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? details,
    String? location,
  }) {
    final startUtc = formatUtcDateTime(startTime);
    final endUtc = formatUtcDateTime(endTime);
    final dates = '$startUtc/$endUtc';

    final cleanTitle = Validators.sanitizeText(title, maxLength: 120);
    final cleanDetails = details != null && details.trim().isNotEmpty
        ? (details.trim().length > 1000 ? details.trim().substring(0, 1000) : details.trim())
        : null;
    final cleanLocation = location != null && location.trim().isNotEmpty
        ? Validators.sanitizeText(location, maxLength: 200)
        : null;

    final queryParameters = <String, String>{
      'action': 'TEMPLATE',
      'text': cleanTitle,
      'dates': dates,
      if (cleanDetails != null) 'details': cleanDetails,
      if (cleanLocation != null) 'location': cleanLocation,
    };

    return Uri.parse(_googleCalendarBaseUrl).replace(queryParameters: queryParameters);
  }

  /// Constructs the Google Calendar deep link URL string with properly encoded query parameters.
  static String buildGoogleCalendarUrl({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? details,
    String? location,
  }) {
    return buildGoogleCalendarUri(
      title: title,
      startTime: startTime,
      endTime: endTime,
      details: details,
      location: location,
    ).toString();
  }

  /// Generates a standard RFC 5545 `.ics` payload for calendar import.
  ///
  /// Payload includes `BEGIN:VCALENDAR`, `VERSION:2.0`, `PRODID:-//Pickleball App//EN`,
  /// `BEGIN:VEVENT`, `UID:`, `DTSTAMP:`, `DTSTART:`, `DTEND:`, `SUMMARY:`,
  /// `DESCRIPTION:`, `LOCATION:`, `STATUS:`, `END:VEVENT`, `END:VCALENDAR`.
  static String buildIcsCalendarData({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String details = '',
    String location = '',
    String? uid,
    String status = 'CONFIRMED',
  }) {
    final cleanTitle = Validators.sanitizeText(title, maxLength: 120);
    final cleanDetails = Validators.sanitizeText(details, maxLength: 1000);
    final cleanLocation = Validators.sanitizeText(location, maxLength: 200);
    final cleanStatus = Validators.sanitizeText(status, maxLength: 30).toUpperCase();

    final startUtc = formatUtcDateTime(startTime);
    final endUtc = formatUtcDateTime(endTime);
    final dtStamp = formatUtcDateTime(DateTime.now().toUtc());

    final cleanUid = (uid != null && uid.trim().isNotEmpty)
        ? Validators.sanitizeText(uid, maxLength: 120)
        : '${startTime.millisecondsSinceEpoch}-${cleanTitle.hashCode.abs()}@cjpickleball.app';

    final buffer = StringBuffer()
      ..write('BEGIN:VCALENDAR\r\n')
      ..write('VERSION:2.0\r\n')
      ..write('PRODID:-//Pickleball App//EN\r\n')
      ..write('CALSCALE:GREGORIAN\r\n')
      ..write('BEGIN:VEVENT\r\n')
      ..write('UID:$cleanUid\r\n')
      ..write('DTSTAMP:$dtStamp\r\n')
      ..write('DTSTART:$startUtc\r\n')
      ..write('DTEND:$endUtc\r\n')
      ..write('SUMMARY:$cleanTitle\r\n')
      ..write('DESCRIPTION:$cleanDetails\r\n')
      ..write('LOCATION:$cleanLocation\r\n')
      ..write('STATUS:$cleanStatus\r\n')
      ..write('END:VEVENT\r\n')
      ..write('END:VCALENDAR');

    return buffer.toString();
  }

  /// Constructs RFC 5545 compliant Apple Calendar web/URL format using a `data:text/calendar` URI.
  static String buildAppleCalendarUrl({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String details = '',
    String location = '',
  }) {
    final icsContent = buildIcsCalendarData(
      title: title,
      startTime: startTime,
      endTime: endTime,
      details: details,
      location: location,
    );

    return 'data:text/calendar;charset=utf8,${Uri.encodeComponent(icsContent)}';
  }

  /// Constructs Outlook Live compose deep link URL:
  /// `https://outlook.live.com/calendar/0/deeplink/compose?path=%2Fcalendar%2Faction%2Fcompose&rru=addevent&startdt=...&enddt=...&subject=...&body=...&location=...`
  static String buildOutlookCalendarUrl({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String details = '',
    String location = '',
  }) {
    final cleanTitle = Validators.sanitizeText(title, maxLength: 120);
    final cleanDetails = Validators.sanitizeText(details, maxLength: 1000);
    final cleanLocation = Validators.sanitizeText(location, maxLength: 200);

    final queryParameters = <String, String>{
      'path': '/calendar/action/compose',
      'rru': 'addevent',
      'startdt': startTime.toUtc().toIso8601String(),
      'enddt': endTime.toUtc().toIso8601String(),
      'subject': cleanTitle,
      if (cleanDetails.isNotEmpty) 'body': cleanDetails,
      if (cleanLocation.isNotEmpty) 'location': cleanLocation,
    };

    final uri = Uri.parse(_outlookCalendarBaseUrl).replace(queryParameters: queryParameters);
    return uri.toString();
  }

  /// Launches any calendar URL in an external application or system browser.
  static Future<bool> launchCalendarLink(
    String url, {
    BuildContext? context,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (context != null && context.mounted) {
        AppSnackBar.error(context, 'Invalid calendar URL format.');
      }
      return false;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        debugPrint('Warning: url_launcher returned false for: $url');
        if (context != null && context.mounted) {
          AppSnackBar.error(
            context,
            'Could not open calendar automatically. Please try again.',
          );
        }
        return false;
      }

      if (context != null && context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Opening calendar to save your booking...',
          icon: Icons.event_available_rounded,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Exception opening calendar URL ($url): $e');
      if (context != null && context.mounted) {
        AppSnackBar.error(
          context,
          'Unable to launch calendar: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
      return false;
    }
  }

  /// Launches the Google Calendar deep link in an external application / browser tab.
  static Future<bool> openGoogleCalendar({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? details,
    String? location,
    BuildContext? context,
  }) async {
    final url = buildGoogleCalendarUrl(
      title: title,
      startTime: startTime,
      endTime: endTime,
      details: details,
      location: location,
    );

    return launchCalendarLink(url, context: context);
  }

  /// Convenience wrapper to build and launch a Google Calendar entry for a [BookingModel].
  static Future<bool> addBookingToCalendar(
    BookingModel booking, {
    BuildContext? context,
    String? venueName,
  }) {
    final court = booking.courtName ?? 'C&J Pickleball - Court 1';
    final venue = venueName ?? 'C&J Pickleball Court • $court';

    final dateFormat = DateFormat('EEEE, MMMM d, y');
    final formattedDate = dateFormat.format(booking.startTime);
    final formattedTime = Validators.formatTimeSlotRange(booking.startTime, booking.endTime);

    final details = StringBuffer()
      ..writeln('🏓 C&J Pickleball Court Reservation')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('📍 Venue: $venue')
      ..writeln('🏟️ Court: $court')
      ..writeln('📅 Date: $formattedDate')
      ..writeln('⏰ Slot: $formattedTime')
      ..writeln('💰 Total Paid: ₱${booking.totalAmount.toStringAsFixed(2)}')
      ..writeln('🔖 Status: ${booking.status.toUpperCase()}')
      ..writeln('🆔 Booking Reference: ${booking.id}')
      ..writeln()
      ..writeln('Please arrive 10 minutes prior to your session for court check-in.')
      ..writeln('Managed via C&J Pickleball App.');

    return openGoogleCalendar(
      title: 'Pickleball @ $court',
      startTime: booking.startTime,
      endTime: booking.endTime,
      details: details.toString(),
      location: venue,
      context: context,
    );
  }
}
