import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/utils/validators.dart';
import 'package:pickleball_app/services/booking_service.dart';
import 'package:pickleball_app/services/calendar_link_service.dart';

void main() {
  group('Validators Security & Input Validation Tests', () {
    group('Email Validation', () {
      test('accepts valid email addresses', () {
        expect(Validators.validateEmail('player@pickleball.com'), isNull);
        expect(Validators.validateEmail('alex.morgan+test@championship.club.org'), isNull);
        expect(Validators.validateEmail('user_123@domain.co.uk'), isNull);
      });

      test('rejects empty and whitespace-only email', () {
        expect(Validators.validateEmail(null), isNotNull);
        expect(Validators.validateEmail(''), isNotNull);
        expect(Validators.validateEmail('   '), isNotNull);
      });

      test('rejects unanchored injections and malicious payloads', () {
        // Prevents trailing XSS / header injection bypasses
        expect(Validators.validateEmail('user@domain.com<script>alert(1)</script>'), isNotNull);
        expect(Validators.validateEmail('user@domain.com\nBcc: victim@example.com'), isNotNull);
        expect(Validators.validateEmail('user@domain.com something_else'), isNotNull);
        expect(Validators.validateEmail('plainaddress'), isNotNull);
        expect(Validators.validateEmail('@missingusername.com'), isNotNull);
        expect(Validators.validateEmail('user@.com'), isNotNull);
      });

      test('rejects emails exceeding maximum length of 254 chars', () {
        final longPrefix = 'a' * 245;
        final longEmail = '$longPrefix@domain.com';
        expect(Validators.validateEmail(longEmail), isNotNull);
      });
    });

    group('Full Name Validation & Sanitization', () {
      test('accepts valid full names', () {
        expect(Validators.validateFullName('Alex Morgan'), isNull);
        expect(Validators.validateFullName('Jean-Luc Picard'), isNull);
        expect(Validators.validateFullName("O'Connor"), isNull);
      });

      test('rejects names under 2 characters or empty', () {
        expect(Validators.validateFullName(null), isNotNull);
        expect(Validators.validateFullName(''), isNotNull);
        expect(Validators.validateFullName('A'), isNotNull);
      });

      test('rejects names exceeding 70 characters', () {
        final longName = 'A' * 71;
        expect(Validators.validateFullName(longName), isNotNull);
      });

      test('rejects names with hidden control characters or newlines', () {
        expect(Validators.validateFullName('Alex\u0000Morgan'), isNotNull);
        expect(Validators.validateFullName('Alex\nLine2'), isNotNull);
        expect(Validators.validateFullName('Alex\u202EReverse'), isNotNull);
      });

      test('sanitizeText strips control characters and clamps maximum length', () {
        const raw = 'Hello\u0000\u001F World\n';
        final sanitized = Validators.sanitizeText(raw);
        expect(sanitized, equals('Hello World'));

        final clamped = Validators.sanitizeText('1234567890', maxLength: 5);
        expect(clamped, equals('12345'));
      });
    });

    group('Password Validation (NIST SP 800-63B Standards)', () {
      test('accepts passwords with 8 or more characters', () {
        expect(Validators.validatePassword('password123'), isNull);
        expect(Validators.validatePassword('P@ssw0rd!#2026'), isNull);
        expect(Validators.validatePassword('8chars!1'), isNull);
      });

      test('rejects passwords shorter than 8 characters', () {
        expect(Validators.validatePassword(null), isNotNull);
        expect(Validators.validatePassword(''), isNotNull);
        expect(Validators.validatePassword('1234567'), isNotNull);
      });

      test('rejects passwords exceeding 128 characters', () {
        final hugePassword = 'P' * 129;
        expect(Validators.validatePassword(hugePassword), isNotNull);
      });

      test('validateConfirmPassword enforces match', () {
        expect(Validators.validateConfirmPassword('secret123', 'secret123'), isNull);
        expect(Validators.validateConfirmPassword('secret123', 'mismatch'), isNotNull);
        expect(Validators.validateConfirmPassword(null, 'secret123'), isNotNull);
      });
    });
  });

  group('Service Defensive Validation Tests', () {
    test('BookingService createBooking throws on invalid inputs', () async {
      final bookingService = BookingService.instance;
      final now = DateTime.now();

      // Empty courtId
      expect(
        () => bookingService.createBooking(
          courtId: '  ',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          totalAmount: 50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Start time not before end time
      expect(
        () => bookingService.createBooking(
          courtId: 'court-1',
          startTime: now.add(const Duration(hours: 2)),
          endTime: now.add(const Duration(hours: 1)),
          totalAmount: 50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative or invalid amount
      expect(
        () => bookingService.createBooking(
          courtId: 'court-1',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          totalAmount: -10.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('CalendarLinkService truncates excessively long strings for URL safety', () {
      final now = DateTime.utc(2026, 8, 30, 10);
      final hugeDetails = 'D' * 2000;
      final uri = CalendarLinkService.buildGoogleCalendarUri(
        title: 'Title',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        details: hugeDetails,
      );

      expect(uri.queryParameters['details']!.length, lessThanOrEqualTo(1000));
    });
  });

  group('Time Slot Overlap & Range Formatting Tests', () {
    final slot8to9 = (
      start: DateTime(2026, 8, 30, 8),
      end: DateTime(2026, 8, 30, 9),
    );
    final slot9to10 = (
      start: DateTime(2026, 8, 30, 9),
      end: DateTime(2026, 8, 30, 10),
    );
    final slot7to8 = (
      start: DateTime(2026, 8, 30, 7),
      end: DateTime(2026, 8, 30, 8),
    );
    final slot830to930 = (
      start: DateTime(2026, 8, 30, 8, 30),
      end: DateTime(2026, 8, 30, 9, 30),
    );
    final slot815to845 = (
      start: DateTime(2026, 8, 30, 8, 15),
      end: DateTime(2026, 8, 30, 8, 45),
    );
    final slot10to11 = (
      start: DateTime(2026, 8, 30, 10),
      end: DateTime(2026, 8, 30, 11),
    );

    test('allows back-to-back adjacent bookings using half-open intervals [start, end)', () {
      // Slot 9:00 - 10:00 immediately following 8:00 - 9:00
      final overlapAdjacentNext = Validators.hasTimeOverlap(
        newStart: slot9to10.start,
        newEnd: slot9to10.end,
        existingStart: slot8to9.start,
        existingEnd: slot8to9.end,
      );
      expect(overlapAdjacentNext, isFalse, reason: '9:00 AM start must NOT overlap with an 8:00-9:00 AM booking');

      // Slot 7:00 - 8:00 immediately preceding 8:00 - 9:00
      final overlapAdjacentPrev = Validators.hasTimeOverlap(
        newStart: slot7to8.start,
        newEnd: slot7to8.end,
        existingStart: slot8to9.start,
        existingEnd: slot8to9.end,
      );
      expect(overlapAdjacentPrev, isFalse, reason: '7:00-8:00 AM slot must NOT overlap with an 8:00-9:00 AM booking');
    });

    test('detects actual overlapping and intersecting time intervals', () {
      // Partial overlap 8:30 - 9:30 vs 8:00 - 9:00
      final overlapPartial = Validators.hasTimeOverlap(
        newStart: slot830to930.start,
        newEnd: slot830to930.end,
        existingStart: slot8to9.start,
        existingEnd: slot8to9.end,
      );
      expect(overlapPartial, isTrue);

      // Sub-interval containment 8:15 - 8:45 vs 8:00 - 9:00
      final overlapContained = Validators.hasTimeOverlap(
        newStart: slot815to845.start,
        newEnd: slot815to845.end,
        existingStart: slot8to9.start,
        existingEnd: slot8to9.end,
      );
      expect(overlapContained, isTrue);

      // Exact matching interval 8:00 - 9:00 vs 8:00 - 9:00
      final overlapExact = Validators.hasTimeOverlap(
        newStart: slot8to9.start,
        newEnd: slot8to9.end,
        existingStart: slot8to9.start,
        existingEnd: slot8to9.end,
      );
      expect(overlapExact, isTrue);

      // Disjoint separate interval 10:00 - 11:00 vs 8:00 - 9:00
      final overlapDisjoint = Validators.hasTimeOverlap(
        newStart: slot10to11.start,
        newEnd: slot10to11.end,
        existingStart: slot8to9.start,
        existingEnd: slot8to9.end,
      );
      expect(overlapDisjoint, isFalse);
    });

    test('formats time slot range in the exact concise format FROM [START] TO [END]', () {
      final formatted = Validators.formatTimeSlotRange(
        DateTime(2026, 8, 30, 8),
        DateTime(2026, 8, 30, 9),
      );
      expect(formatted, equals('FROM 8:00 AM TO 9:00 AM'));
    });
  });
}
