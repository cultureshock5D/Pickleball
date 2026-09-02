import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Validators {
  Validators._();

  /// Maximum allowed length for email addresses per RFC 5321/5322 specifications.
  static const int maxEmailLength = 254;

  /// Maximum allowed length for user full names.
  static const int maxFullNameLength = 70;

  /// Maximum password length to prevent Hash DoS / ReDoS attacks on bcrypt/argon2.
  static const int maxPasswordLength = 128;

  /// Minimum password length aligned with modern NIST SP 800-63B standards.
  static const int minPasswordLength = 8;

  /// Strict anchored RFC-5322 compatible email regular expression.
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  /// Pattern to detect forbidden ASCII/Unicode control characters and bidirectional control spoofing.
  static final RegExp _controlCharRegex = RegExp(
    r"[\u0000-\u001F\u007F-\u009F\u200E\u200F\u202A-\u202E]",
  );

  /// Validates user full name with length boundaries and control character prevention.
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (trimmed.length > maxFullNameLength) {
      return 'Name cannot exceed $maxFullNameLength characters';
    }
    if (_controlCharRegex.hasMatch(trimmed) || trimmed.contains('\n') || trimmed.contains('\r')) {
      return 'Name contains invalid control characters';
    }
    return null;
  }

  /// Validates email with strict bounded regex matching and length limits.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    final trimmed = value.trim();
    if (trimmed.length > maxEmailLength) {
      return 'Email address cannot exceed $maxEmailLength characters';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates password meeting NIST 8-character minimum and 128-character bound.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    if (value.length > maxPasswordLength) {
      return 'Password cannot exceed $maxPasswordLength characters';
    }
    return null;
  }

  /// Confirms password match against original entry.
  static String? validateConfirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != originalPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Sanitizes generic text inputs by stripping control characters and clamping length.
  static String sanitizeText(String? input, {int maxLength = 255}) {
    if (input == null) return '';
    final cleaned = input.replaceAll(_controlCharRegex, '').trim();
    if (cleaned.length > maxLength) {
      return cleaned.substring(0, maxLength);
    }
    return cleaned;
  }

  /// Validates half-open time interval overlaps: [newStart, newEnd) vs [existingStart, existingEnd).
  ///
  /// An overlap exists if and only if:
  /// `newStart < existingEnd` AND `newEnd > existingStart`
  ///
  /// Back-to-back bookings (e.g., 8:00 AM - 9:00 AM and 9:00 AM - 10:00 AM) where
  /// `newStart == existingEnd` or `newEnd == existingStart` evaluate to FALSE (no overlap / allowed).
  static bool hasTimeOverlap({
    required DateTime newStart,
    required DateTime newEnd,
    required DateTime existingStart,
    required DateTime existingEnd,
  }) {
    return newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
  }

  /// Formats time slot concisely into the exact standard: "FROM [START TIME] TO [END TIME]"
  /// (e.g., "FROM 8:00 AM TO 9:00 AM")
  static String formatTimeSlotRange(DateTime start, DateTime end) {
    final startStr = DateFormat('h:mm a').format(start);
    final endStr = DateFormat('h:mm a').format(end);
    return 'FROM $startStr TO $endStr';
  }

  /// Formats TimeOfDay slot concisely into "FROM [START TIME] TO [END TIME]"
  static String formatTimeOfDaySlotRange(TimeOfDay start, TimeOfDay end) {
    final startHour = start.hourOfPeriod == 0 ? 12 : start.hourOfPeriod;
    final startMinute = start.minute.toString().padLeft(2, '0');
    final startPeriod = start.period == DayPeriod.am ? 'AM' : 'PM';

    final endHour = end.hourOfPeriod == 0 ? 12 : end.hourOfPeriod;
    final endMinute = end.minute.toString().padLeft(2, '0');
    final endPeriod = end.period == DayPeriod.am ? 'AM' : 'PM';

    return 'FROM $startHour:$startMinute $startPeriod TO $endHour:$endMinute $endPeriod';
  }
}

