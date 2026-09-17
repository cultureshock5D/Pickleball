import 'package:flutter/material.dart';

/// Supported event session packages.
enum EventPackageType {
  customHourly,
  halfDayMorning,
  halfDayAfternoon,
  halfDayEvening,
  fullDay,
}

extension EventPackageTypeExtension on EventPackageType {
  String get label {
    switch (this) {
      case EventPackageType.customHourly:
        return 'Custom Hourly';
      case EventPackageType.halfDayMorning:
        return 'Half-Day Morning';
      case EventPackageType.halfDayAfternoon:
        return 'Half-Day Afternoon';
      case EventPackageType.halfDayEvening:
        return 'Half-Day Evening';
      case EventPackageType.fullDay:
        return 'Full-Day Championship';
    }
  }

  String get timeFrame {
    switch (this) {
      case EventPackageType.customHourly:
        return 'Flexible hours (min. 2 hrs)';
      case EventPackageType.halfDayMorning:
        return '8:00 AM – 12:00 PM (4 Hours)';
      case EventPackageType.halfDayAfternoon:
        return '1:00 PM – 5:00 PM (4 Hours)';
      case EventPackageType.halfDayEvening:
        return '6:00 PM – 10:00 PM (4 Hours)';
      case EventPackageType.fullDay:
        return '9:00 AM – 5:00 PM (8 Hours)';
    }
  }

  int get defaultDurationHours {
    switch (this) {
      case EventPackageType.customHourly:
        return 2;
      case EventPackageType.halfDayMorning:
      case EventPackageType.halfDayAfternoon:
      case EventPackageType.halfDayEvening:
        return 4;
      case EventPackageType.fullDay:
        return 8;
    }
  }

  TimeOfDay get defaultStartTime {
    switch (this) {
      case EventPackageType.customHourly:
      case EventPackageType.halfDayMorning:
        return const TimeOfDay(hour: 8, minute: 0);
      case EventPackageType.halfDayAfternoon:
        return const TimeOfDay(hour: 13, minute: 0);
      case EventPackageType.halfDayEvening:
        return const TimeOfDay(hour: 18, minute: 0);
      case EventPackageType.fullDay:
        return const TimeOfDay(hour: 9, minute: 0);
    }
  }
}

/// Model representing a bookable event space or hall.
class EventSpaceModel {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final int capacityMin;
  final int capacityMax;
  final double hourlyRate;
  final double halfDayRate;
  final double fullDayRate;
  final List<String> amenities;
  final List<String> tags;
  final int accentColorValue;
  final int courtCount;
  final String surface;
  final int? areaSqm;
  final String? levelInfo;
  final String? contactPhone;
  final bool isOcularAvailable;
  final bool isMessageFirst;

  const EventSpaceModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.capacityMin,
    required this.capacityMax,
    required this.hourlyRate,
    required this.halfDayRate,
    required this.fullDayRate,
    required this.amenities,
    required this.tags,
    this.accentColorValue = 0xFFCCFF00,
    this.courtCount = 2,
    this.surface = 'Dual Tournament Cushioned Acrylic',
    this.areaSqm,
    this.levelInfo,
    this.contactPhone,
    this.isOcularAvailable = false,
    this.isMessageFirst = false,
  });

  Color get accentColor => Color(accentColorValue);

  double calculateBasePrice({
    required EventPackageType package,
    required int customHours,
  }) {
    switch (package) {
      case EventPackageType.customHourly:
        return hourlyRate * customHours.clamp(2, 12);
      case EventPackageType.halfDayMorning:
      case EventPackageType.halfDayAfternoon:
      case EventPackageType.halfDayEvening:
        return halfDayRate;
      case EventPackageType.fullDay:
        return fullDayRate;
    }
  }
}

/// Additional equipment and concierge services for events.
class EventAddon {
  final String id;
  final String name;
  final String description;
  final double price;
  final bool isPerSession; // true = flat rate per session, false = per hour
  final IconData icon;

  const EventAddon({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.isPerSession = true,
    required this.icon,
  });

  double calculateCost(int durationHours) {
    if (isPerSession) {
      return price;
    }
    return price * durationHours;
  }
}

/// An in-memory event booking record.
class EventBookingModel {
  final String id;
  final String spaceId;
  final String spaceName;
  final String eventType;
  final EventPackageType packageType;
  final DateTime date;
  final TimeOfDay startTime;
  final int durationHours;
  final int guestCount;
  final List<EventAddon> selectedAddons;
  final String organizerName;
  final String organizerEmail;
  final String organizerPhone;
  final String specialInstructions;
  final double basePrice;
  final double addonsPrice;
  final double securityDeposit;
  final double totalAmount;
  final bool isMessageFirst;
  final String status;
  final DateTime createdAt;

  const EventBookingModel({
    required this.id,
    required this.spaceId,
    required this.spaceName,
    required this.eventType,
    required this.packageType,
    required this.date,
    required this.startTime,
    required this.durationHours,
    required this.guestCount,
    required this.selectedAddons,
    required this.organizerName,
    required this.organizerEmail,
    required this.organizerPhone,
    required this.specialInstructions,
    required this.basePrice,
    required this.addonsPrice,
    required this.securityDeposit,
    required this.totalAmount,
    this.isMessageFirst = false,
    this.status = 'confirmed',
    required this.createdAt,
  });

  TimeOfDay get endTime {
    final endHour = (startTime.hour + durationHours).clamp(0, 24);
    return TimeOfDay(hour: endHour % 24, minute: startTime.minute);
  }
}
