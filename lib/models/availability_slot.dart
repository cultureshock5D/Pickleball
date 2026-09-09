import 'package:flutter/material.dart';

class AvailabilitySlot {
  final int hour24;
  final bool available;
  final double price;
  final String? bookingId;
  final bool isHeld; // pending_payment with active 5-min timer
  final bool isPast;

  const AvailabilitySlot({
    required this.hour24,
    required this.available,
    this.price = 300.0,
    this.bookingId,
    this.isHeld = false,
    this.isPast = false,
  });

  TimeOfDay get startTime => TimeOfDay(hour: hour24, minute: 0);
  TimeOfDay get endTime => TimeOfDay(hour: (hour24 + 1) % 24, minute: 0);

  String get timeLabel {
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final h12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    return '$h12:00 $period';
  }

  String get timeRangeLabel {
    final endHour = hour24 + 1;
    final startPeriod = hour24 >= 12 ? 'PM' : 'AM';
    final endPeriod = endHour >= 12 ? 'PM' : 'AM';
    final startH12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final endH12 = endHour == 0 ? 12 : (endHour > 12 ? endHour - 12 : endHour);
    return '$startH12:00 $startPeriod - $endH12:00 $endPeriod';
  }
}
