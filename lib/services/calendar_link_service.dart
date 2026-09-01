import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/utils/snackbar_helper.dart';
import '../models/booking_model.dart';

/// Zero-Auth, Zero-API Deep Link Service for Google Calendar integration.
///
/// Constructs direct Google Calendar event creation URLs without requiring
/// Google Cloud Console APIs, OAuth 2.0 scopes, credentials, or client secrets.
class CalendarLinkService {
  CalendarLinkService._();

  static const String _calendarBaseUrl = 'https://calendar.google.com/calendar/render';

  /// Converts a [DateTime] (local or UTC) into the UTC ISO 8601 template string
  /// format required by Google Calendar: `YYYYMMDDTHHmmSSZ`.
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

    final queryParameters = <String, String>{
      'action': 'TEMPLATE',
      'text': title,
      'dates': dates,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      if (location != null && location.trim().isNotEmpty) 'location': location.trim(),
    };

    return Uri.parse(_calendarBaseUrl).replace(queryParameters: queryParameters);
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

  /// Launches the Google Calendar deep link in an external application / browser tab.
  ///
  /// Uses [LaunchMode.externalApplication] to ensure the native Google Calendar app
  /// or system browser opens cleanly without embedding restrictions.
  ///
  /// Displays a modern, floating fallback SnackBar if the link cannot be launched.
  static Future<bool> openGoogleCalendar({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? details,
    String? location,
    BuildContext? context,
  }) async {
    final uri = buildGoogleCalendarUri(
      title: title,
      startTime: startTime,
      endTime: endTime,
      details: details,
      location: location,
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        debugPrint('Warning: url_launcher returned false for: $uri');
        if (context != null && context.mounted) {
          AppSnackBar.error(
            context,
            'Could not open Google Calendar automatically. Please try again.',
          );
        }
        return false;
      }

      if (context != null && context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Opening Google Calendar to save your booking...',
          icon: Icons.event_available_rounded,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Exception opening Google Calendar URL ($uri): $e');
      if (context != null && context.mounted) {
        AppSnackBar.error(
          context,
          'Unable to launch Google Calendar: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
      return false;
    }
  }

  /// Convenience wrapper to build and launch a Google Calendar entry for a [BookingModel].
  static Future<bool> addBookingToCalendar(
    BookingModel booking, {
    BuildContext? context,
    String? venueName,
  }) {
    final court = booking.courtName ?? 'SmashCourt Center Championship';
    final venue = venueName ?? 'SmashCourt Arena • $court';

    final dateFormat = DateFormat('EEEE, MMMM d, y');
    final timeFormat = DateFormat('h:mm a');
    final formattedDate = dateFormat.format(booking.startTime);
    final formattedTime = '${timeFormat.format(booking.startTime)} - ${timeFormat.format(booking.endTime)}';

    final details = StringBuffer()
      ..writeln('🏓 SmashCourt Court Reservation')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('📍 Venue: $venue')
      ..writeln('🏟️ Court: $court')
      ..writeln('📅 Date: $formattedDate')
      ..writeln('⏰ Slot: $formattedTime')
      ..writeln('💰 Total Paid: ₱${booking.totalAmount.toStringAsFixed(2)}')
      ..writeln('🔖 Status: ${booking.status.toUpperCase()}')
      ..writeln('🆔 Booking Reference: ${booking.id}')
      ..writeln('')
      ..writeln('Please arrive 10 minutes prior to your session for court check-in.')
      ..writeln('Managed via SmashCourt App.');

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
