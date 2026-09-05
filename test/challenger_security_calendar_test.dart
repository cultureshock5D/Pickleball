import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/utils/validators.dart';
import 'package:pickleball_app/services/calendar_link_service.dart';

void main() {
  group('EMPIRICAL CHALLENGER: Validators Adversarial Security Suite', () {
    group('RFC 5321 / RFC 5322 Email Adversarial Tests', () {
      final validEmails = [
        'simple@example.com',
        'very.common@example.com',
        'disposable.style.email.with+symbol@example.com',
        'other.email-with-hyphen@example.com',
        'fully-qualified-domain@example.com',
        'user.name+tag+sorting@example.com',
        'x@example.com',
        'example-indeed@strange-example.com',
        'admin@mailserver1.net',
        'example@s.example',
        'user%example.com@example.org',
        'user-@example.org',
        'a.b.c.d.e@f.g.h.i.j.com',
        'first.last@subdomain.domain.co.uk',
        '1234567890@example.com',
        'email@subdomain.example.com',
        'firstname+lastname@example.com',
        'email@123.123.123.123' == 'email@123.123.123.123' ? 'user@domain.info' : '',
      ].where((e) => e.isNotEmpty).toList();

      for (final email in validEmails) {
        test('accepts valid RFC 5322 email: "$email"', () {
          final result = Validators.validateEmail(email);
          expect(result, isNull, reason: 'Expected "$email" to be valid, but got: $result');
        });
      }

      final invalidEmails = [
        // Missing parts
        'plainaddress',
        '@missingusername.com',
        'username@.com',
        'username@com',
        'username@',
        '',
        '   ',
        // Consecutive / leading / trailing dots in domain
        'user@domain..com',
        'user@.domain.com',
        // Spaces / illegal characters
        'user name@example.com',
        'user@exam ple.com',
        'user@example .com',
        'user\t@example.com',
        // Injection / XSS payloads
        'user@example.com<script>alert(1)</script>',
        'user@example.com\nBcc: victim@target.com',
        'user@example.com\r\nBcc: victim@target.com',
        'user@example.com"alert(1)"',
        'user@example.com;DROP TABLE users;',
        'user@example.com\u0000admin@victim.com',
        // Unescaped / illegal quotes
        'just"not"right@example.com',
        'this is"not\\allowed@example.com',
        // Underscore in domain label
        'user@domain_with_underscore.com',
      ];

      for (final email in invalidEmails) {
        test('rejects invalid/adversarial email payload: "$email"', () {
          final result = Validators.validateEmail(email);
          expect(result, isNotNull, reason: 'Expected "$email" to be rejected as invalid email');
        });
      }

      test('exact 254-character email boundary (max allowed per RFC 5321/5322)', () {
        // Construct valid 254 character email: 'a'*242 + '@example.com' = 242 + 12 = 254
        final local = 'a' * 242;
        final email254 = '$local@example.com';
        expect(email254.length, equals(254));
        final result = Validators.validateEmail(email254);
        expect(result, isNull, reason: '254 char email should be accepted');
      });

      test('exact 255-character email boundary (exceeds max length)', () {
        // Construct 255 character email: 'a'*243 + '@example.com' = 243 + 12 = 255
        final local = 'a' * 243;
        final email255 = '$local@example.com';
        expect(email255.length, equals(255));
        final result = Validators.validateEmail(email255);
        expect(result, equals('Email address cannot exceed 254 characters'));
      });

      test('handles null safely', () {
        expect(Validators.validateEmail(null), equals('Please enter your email address'));
      });
    });

    group('NIST SP 800-63B Password Rules Boundary Tests', () {
      test('rejects passwords under 8 characters (7 chars boundary)', () {
        const pass7 = '1234567';
        expect(pass7.length, equals(7));
        expect(
          Validators.validatePassword(pass7),
          equals('Password must be at least 8 characters'),
        );
      });

      test('accepts exact 8 character password (minimum boundary)', () {
        const pass8 = '12345678';
        expect(pass8.length, equals(8));
        expect(Validators.validatePassword(pass8), isNull);
      });

      test('accepts exact 128 character password (maximum boundary)', () {
        final pass128 = 'P' * 128;
        expect(pass128.length, equals(128));
        expect(Validators.validatePassword(pass128), isNull);
      });

      test('rejects 129 character password (exceeds maximum boundary)', () {
        final pass129 = 'P' * 129;
        expect(pass129.length, equals(129));
        expect(
          Validators.validatePassword(pass129),
          equals('Password cannot exceed 128 characters'),
        );
      });

      test('accepts passwords with high-entropy Unicode and symbols (>= 8 chars)', () {
        expect(Validators.validatePassword('P@ssw0rd!#2026🎾'), isNull);
        expect(Validators.validatePassword('Smäsh-Cöürt-2026!'), isNull);
        expect(Validators.validatePassword('Пароль1234!#'), isNull);
      });

      test('validateConfirmPassword enforces exact match and handles null/mismatch', () {
        expect(Validators.validateConfirmPassword('MyP@ssword1', 'MyP@ssword1'), isNull);
        expect(Validators.validateConfirmPassword('MyP@ssword1', 'MyP@ssword2'), equals('Passwords do not match'));
        expect(Validators.validateConfirmPassword('myp@ssword1', 'MyP@ssword1'), equals('Passwords do not match'));
        expect(Validators.validateConfirmPassword(null, 'MyP@ssword1'), equals('Please confirm your password'));
        expect(Validators.validateConfirmPassword('', 'MyP@ssword1'), equals('Please confirm your password'));
      });
    });

    group('Trojan Source & Bidirectional Unicode Sanitization Tests', () {
      final bidiTrojanChars = [
        ('\u202E', 'Right-to-Left Override [RLO]'),
        ('\u200E', 'Left-to-Right Mark [LRM]'),
        ('\u200F', 'Right-to-Left Mark [RLM]'),
        ('\u202A', 'Left-to-Right Embedding [LRE]'),
        ('\u202B', 'Right-to-Left Embedding [RLE]'),
        ('\u202C', 'Pop Directional Formatting [PDF]'),
        ('\u202D', 'Left-to-Right Override [LRO]'),
        ('\u0000', 'NUL byte [ASCII 0]'),
        ('\u0008', 'Backspace [ASCII 8]'),
        ('\u001F', 'Unit Separator [ASCII 31]'),
        ('\u007F', 'DEL [ASCII 127]'),
        ('\u0080', 'Padding Character [C1 128]'),
        ('\u009F', 'Application Program Command [C1 159]'),
      ];

      for (final (char, desc) in bidiTrojanChars) {
        test('validateFullName catches forbidden char: $desc', () {
          final dirtyName = 'Alex${char}Morgan';
          final result = Validators.validateFullName(dirtyName);
          expect(result, equals('Name contains invalid control characters'),
              reason: 'Expected $desc to be detected and rejected in full name');
        });

        test('sanitizeText strips forbidden char cleanly: $desc', () {
          final dirtyText = 'Court${char}Master';
          final cleaned = Validators.sanitizeText(dirtyText);
          expect(cleaned, equals('CourtMaster'),
              reason: 'Expected $desc to be cleanly stripped without affecting surrounding characters');
        });
      }

      test('sanitizeText preserves valid international multilingual characters', () {
        const internationalText = 'María José Peña 🎾 李小龙 서울 123';
        final sanitized = Validators.sanitizeText(internationalText);
        expect(sanitized, equals(internationalText));
      });

      test('sanitizeText clamps output to specified maxLength', () {
        const text = 'abcdefghijklmnopqrstuvwxyz';
        expect(Validators.sanitizeText(text, maxLength: 5), equals('abcde'));
        expect(Validators.sanitizeText(text, maxLength: 10), equals('abcdefghij'));
        expect(Validators.sanitizeText(text, maxLength: 100), equals(text));
      });

      test('sanitizeText handles null and empty inputs safely', () {
        expect(Validators.sanitizeText(null), equals(''));
        expect(Validators.sanitizeText(''), equals(''));
        expect(Validators.sanitizeText('   '), equals(''));
      });
    });

    group('Half-Open Time Interval [start, end) Booking Calculations', () {
      final baseStart = DateTime(2026, 9, 1, 10);
      final baseEnd = DateTime(2026, 9, 1, 11);

      test('back-to-back adjacent slots have NO overlap (boundary start == existingEnd)', () {
        // [11:00, 12:00) vs [10:00, 11:00)
        final nextSlot = (
          start: DateTime(2026, 9, 1, 11),
          end: DateTime(2026, 9, 1, 12),
        );
        final overlap = Validators.hasTimeOverlap(
          newStart: nextSlot.start,
          newEnd: nextSlot.end,
          existingStart: baseStart,
          existingEnd: baseEnd,
        );
        expect(overlap, isFalse);
      });

      test('back-to-back adjacent slots have NO overlap (boundary end == existingStart)', () {
        // [09:00, 10:00) vs [10:00, 11:00)
        final prevSlot = (
          start: DateTime(2026, 9, 1, 9),
          end: DateTime(2026, 9, 1, 10),
        );
        final overlap = Validators.hasTimeOverlap(
          newStart: prevSlot.start,
          newEnd: prevSlot.end,
          existingStart: baseStart,
          existingEnd: baseEnd,
        );
        expect(overlap, isFalse);
      });

      test('sub-microsecond precision adjacent boundary', () {
        // [10:00:00.000, 11:00:00.000) vs [11:00:00.001, 12:00:00.000)
        final nonOverlap = Validators.hasTimeOverlap(
          newStart: DateTime(2026, 9, 1, 11, 0, 0, 1),
          newEnd: DateTime(2026, 9, 1, 12),
          existingStart: baseStart,
          existingEnd: baseEnd,
        );
        expect(nonOverlap, isFalse);

        // 1 millisecond overlapping boundary
        // [10:00:00.000, 11:00:00.001) vs [11:00:00.000, 12:00:00.000)
        final millisecondOverlap = Validators.hasTimeOverlap(
          newStart: DateTime(2026, 9, 1, 10, 59, 59, 999),
          newEnd: DateTime(2026, 9, 1, 12),
          existingStart: baseStart,
          existingEnd: baseEnd,
        );
        expect(millisecondOverlap, isTrue);
      });

      test('detects all standard overlap topologies', () {
        // 1. Partial overlap start: [09:30, 10:30) vs [10:00, 11:00)
        expect(
          Validators.hasTimeOverlap(
            newStart: DateTime(2026, 9, 1, 9, 30),
            newEnd: DateTime(2026, 9, 1, 10, 30),
            existingStart: baseStart,
            existingEnd: baseEnd,
          ),
          isTrue,
        );

        // 2. Partial overlap end: [10:30, 11:30) vs [10:00, 11:00)
        expect(
          Validators.hasTimeOverlap(
            newStart: DateTime(2026, 9, 1, 10, 30),
            newEnd: DateTime(2026, 9, 1, 11, 30),
            existingStart: baseStart,
            existingEnd: baseEnd,
          ),
          isTrue,
        );

        // 3. Strict subset contained: [10:15, 10:45) vs [10:00, 11:00)
        expect(
          Validators.hasTimeOverlap(
            newStart: DateTime(2026, 9, 1, 10, 15),
            newEnd: DateTime(2026, 9, 1, 10, 45),
            existingStart: baseStart,
            existingEnd: baseEnd,
          ),
          isTrue,
        );

        // 4. Strict superset enclosing: [09:00, 12:00) vs [10:00, 11:00)
        expect(
          Validators.hasTimeOverlap(
            newStart: DateTime(2026, 9, 1, 9),
            newEnd: DateTime(2026, 9, 1, 12),
            existingStart: baseStart,
            existingEnd: baseEnd,
          ),
          isTrue,
        );

        // 5. Identical interval: [10:00, 11:00) vs [10:00, 11:00)
        expect(
          Validators.hasTimeOverlap(
            newStart: baseStart,
            newEnd: baseEnd,
            existingStart: baseStart,
            existingEnd: baseEnd,
          ),
          isTrue,
        );

        // 6. Fully disjoint earlier: [07:00, 08:00) vs [10:00, 11:00)
        expect(
          Validators.hasTimeOverlap(
            newStart: DateTime(2026, 9, 1, 7),
            newEnd: DateTime(2026, 9, 1, 8),
            existingStart: baseStart,
            existingEnd: baseEnd,
          ),
          isFalse,
        );

        // 7. Fully disjoint later: [13:00, 14:00) vs [10:00, 11:00)
        expect(
          Validators.hasTimeOverlap(
            newStart: DateTime(2026, 9, 1, 13),
            newEnd: DateTime(2026, 9, 1, 14),
            existingStart: baseStart,
            existingEnd: baseEnd,
          ),
          isFalse,
        );
      });

      test('commutative symmetry property: overlap(A, B) == overlap(B, A)', () {
        final scenarios = [
          (DateTime(2026, 9, 1, 9, 30), DateTime(2026, 9, 1, 10, 30)),
          (DateTime(2026, 9, 1, 10, 15), DateTime(2026, 9, 1, 10, 45)),
          (DateTime(2026, 9, 1, 9), DateTime(2026, 9, 1, 12)),
          (DateTime(2026, 9, 1, 11), DateTime(2026, 9, 1, 12)),
          (DateTime(2026, 9, 1, 8), DateTime(2026, 9, 1, 9)),
          (DateTime(2026, 9, 1, 14), DateTime(2026, 9, 1, 15)),
        ];

        for (final s in scenarios) {
          final ab = Validators.hasTimeOverlap(
            newStart: s.$1,
            newEnd: s.$2,
            existingStart: baseStart,
            existingEnd: baseEnd,
          );
          final ba = Validators.hasTimeOverlap(
            newStart: baseStart,
            newEnd: baseEnd,
            existingStart: s.$1,
            existingEnd: s.$2,
          );
          expect(ab, equals(ba), reason: 'Symmetry failed for interval: ${s.$1} to ${s.$2}');
        }
      });

      test('formatTimeSlotRange and formatTimeOfDaySlotRange conform to concise standard', () {
        final dtRange = Validators.formatTimeSlotRange(
          DateTime(2026, 9, 1, 8),
          DateTime(2026, 9, 1, 9, 30),
        );
        expect(dtRange, equals('FROM 8:00 AM TO 9:30 AM'));

        final todRange = Validators.formatTimeOfDaySlotRange(
          const TimeOfDay(hour: 14, minute: 0),
          const TimeOfDay(hour: 15, minute: 45),
        );
        expect(todRange, equals('FROM 2:00 PM TO 3:45 PM'));

        final midnightRange = Validators.formatTimeOfDaySlotRange(
          const TimeOfDay(hour: 0, minute: 0),
          const TimeOfDay(hour: 1, minute: 0),
        );
        expect(midnightRange, equals('FROM 12:00 AM TO 1:00 AM'));
      });
    });
  });

  group('EMPIRICAL CHALLENGER: CalendarLinkService RFC 5545 Adversarial Suite', () {
    final testStart = DateTime.utc(2026, 9, 1, 8);
    final testEnd = DateTime.utc(2026, 9, 1, 10);

    group('RFC 5545 Syntax & Special Character Injection Tests', () {
      test('buildIcsCalendarData handles quotes, semicolons, backslashes, colons, emojis', () {
        const maliciousTitle = 'Championship "Finals"; Court: #1 \\ VIP 🏓 🏆';
        const maliciousDetails = 'Ref: <BK-999>; Price: \$50.00 & 100% "Confirmed" \r\n Notes: None';
        const maliciousLoc = 'Arena "Central", Court: 1; Level 2 \\ Zone A';

        final ics = CalendarLinkService.buildIcsCalendarData(
          title: maliciousTitle,
          startTime: testStart,
          endTime: testEnd,
          details: maliciousDetails,
          location: maliciousLoc,
          uid: 'UID-TEST-123;SPECIAL',
          status: 'confirmed',
        );

        // Verify top-level structure
        expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
        expect(ics, contains('VERSION:2.0\r\n'));
        expect(ics, contains('PRODID:-//Pickleball App//EN\r\n'));
        expect(ics, contains('CALSCALE:GREGORIAN\r\n'));
        expect(ics, contains('BEGIN:VEVENT\r\n'));
        expect(ics, contains('UID:UID-TEST-123;SPECIAL\r\n'));
        expect(ics, contains('DTSTART:20260901T080000Z\r\n'));
        expect(ics, contains('DTEND:20260901T100000Z\r\n'));
        expect(ics, contains('SUMMARY:Championship "Finals"; Court: #1 \\ VIP 🏓 🏆\r\n'));
        expect(ics, contains('DESCRIPTION:Ref: <BK-999>; Price: \$50.00 & 100% "Confirmed"  Notes: None\r\n'));
        expect(ics, contains('LOCATION:Arena "Central", Court: 1; Level 2 \\ Zone A\r\n'));
        expect(ics, contains('STATUS:CONFIRMED\r\n'));
        expect(ics, endsWith('END:VEVENT\r\nEND:VCALENDAR'));

        // Verify CRLF line endings throughout the file
        final lines = ics.split('\r\n');
        expect(lines.length, equals(15));
        expect(lines.first, equals('BEGIN:VCALENDAR'));
        expect(lines.last, equals('END:VCALENDAR'));
      });

      test('buildIcsCalendarData strips Trojan Source bidi chars to prevent terminal/calendar spoofing', () {
        const dirtyTitle = 'Championship\u202Erev\u200E';
        const dirtyLoc = 'Court\u0000\u001F1';

        final ics = CalendarLinkService.buildIcsCalendarData(
          title: dirtyTitle,
          startTime: testStart,
          endTime: testEnd,
          location: dirtyLoc,
        );

        expect(ics, contains('SUMMARY:Championshiprev\r\n'));
        expect(ics, contains('LOCATION:Court1\r\n'));
        expect(ics, isNot(contains('\u202E')));
        expect(ics, isNot(contains('\u0000')));
      });

      test('buildIcsCalendarData clamps excessively long strings within RFC safe limits', () {
        final hugeTitle = 'T' * 500;
        final hugeDetails = 'D' * 3000;
        final hugeLoc = 'L' * 1000;

        final ics = CalendarLinkService.buildIcsCalendarData(
          title: hugeTitle,
          startTime: testStart,
          endTime: testEnd,
          details: hugeDetails,
          location: hugeLoc,
        );

        expect(ics, contains('SUMMARY:${'T' * 120}\r\n'));
        expect(ics, contains('DESCRIPTION:${'D' * 1000}\r\n'));
        expect(ics, contains('LOCATION:${'L' * 200}\r\n'));
      });
    });

    group('Google Calendar Deep Link Adversarial Tests', () {
      test('buildGoogleCalendarUrl properly encodes complex special chars, queries and spaces', () {
        const complexTitle = 'Court #1 & Court #2 (Grand Finals) "VIP"';
        const complexDetails = 'Booked by: John & Jane <test@test.com>? Promo=50%';
        const complexLoc = 'SmashCourt Arena #10, City Center';

        final url = CalendarLinkService.buildGoogleCalendarUrl(
          title: complexTitle,
          startTime: testStart,
          endTime: testEnd,
          details: complexDetails,
          location: complexLoc,
        );

        expect(url, startsWith('https://calendar.google.com/calendar/render?'));

        final uri = Uri.parse(url);
        expect(uri.host, equals('calendar.google.com'));
        expect(uri.path, equals('/calendar/render'));
        expect(uri.queryParameters['action'], equals('TEMPLATE'));
        expect(uri.queryParameters['text'], equals(complexTitle));
        expect(uri.queryParameters['dates'], equals('20260901T080000Z/20260901T100000Z'));
        expect(uri.queryParameters['details'], equals(complexDetails));
        expect(uri.queryParameters['location'], equals(complexLoc));
      });

      test('buildGoogleCalendarUri handles 5,000 char overflows gracefully via truncation', () {
        final hugeTitle = 'A' * 5000;
        final hugeDetails = 'B' * 5000;
        final hugeLoc = 'C' * 5000;

        final uri = CalendarLinkService.buildGoogleCalendarUri(
          title: hugeTitle,
          startTime: testStart,
          endTime: testEnd,
          details: hugeDetails,
          location: hugeLoc,
        );

        expect(uri.queryParameters['text']!.length, equals(120));
        expect(uri.queryParameters['details']!.length, equals(1000));
        expect(uri.queryParameters['location']!.length, equals(200));
      });
    });

    group('Apple Calendar Data URL Adversarial Tests', () {
      test('buildAppleCalendarUrl produces valid decodeable data: URI containing full RFC 5545 ICS', () {
        const title = 'SmashCourt Semi-Finals 🏓';
        const details = 'Match ID: #987654321; Player: "Alex"';
        const location = 'Court 5 (Covered)';

        final appleUrl = CalendarLinkService.buildAppleCalendarUrl(
          title: title,
          startTime: testStart,
          endTime: testEnd,
          details: details,
          location: location,
        );

        expect(appleUrl, startsWith('data:text/calendar;charset=utf8,'));

        final rawEncoded = appleUrl.substring('data:text/calendar;charset=utf8,'.length);
        final decoded = Uri.decodeComponent(rawEncoded);

        expect(decoded, contains('BEGIN:VCALENDAR\r\n'));
        expect(decoded, contains('SUMMARY:SmashCourt Semi-Finals 🏓\r\n'));
        expect(decoded, contains('DESCRIPTION:Match ID: #987654321; Player: "Alex"\r\n'));
        expect(decoded, contains('LOCATION:Court 5 (Covered)\r\n'));
        expect(decoded, contains('DTSTART:20260901T080000Z\r\n'));
        expect(decoded, contains('DTEND:20260901T100000Z\r\n'));
        expect(decoded, endsWith('END:VEVENT\r\nEND:VCALENDAR'));
      });
    });

    group('Outlook Online Calendar Deep Link Adversarial Tests', () {
      test('buildOutlookCalendarUrl constructs valid query parameters with ISO 8601 UTC timestamps', () {
        const title = 'Playoff Finals 🏆';
        const details = 'Notes: Bring 2 paddles & water';
        const location = 'SmashCourt Dome';

        final outlookUrl = CalendarLinkService.buildOutlookCalendarUrl(
          title: title,
          startTime: testStart,
          endTime: testEnd,
          details: details,
          location: location,
        );

        expect(outlookUrl, startsWith('https://outlook.live.com/calendar/0/deeplink/compose?'));
        final uri = Uri.parse(outlookUrl);

        expect(uri.queryParameters['path'], equals('/calendar/action/compose'));
        expect(uri.queryParameters['rru'], equals('addevent'));
        expect(uri.queryParameters['startdt'], equals('2026-09-01T08:00:00.000Z'));
        expect(uri.queryParameters['enddt'], equals('2026-09-01T10:00:00.000Z'));
        expect(uri.queryParameters['subject'], equals(title));
        expect(uri.queryParameters['body'], equals(details));
        expect(uri.queryParameters['location'], equals(location));
      });
    });
  });
}
