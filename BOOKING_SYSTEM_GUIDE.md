# Comprehensive Booking System & Multi-Time Slot Selection Guide

This guide details the complete architecture, data models, slot algorithms, conflict detection, pricing engine, and UI patterns used in the booking system. You can adapt this architecture directly to other mobile (Flutter/React Native) or web (Next.js/React/Vue) applications.

---

## Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [Data Models & Schema](#2-data-models--schema)
3. [Time Slot Grid & Multi-Selection Engine](#3-time-slot-grid--multi-selection-engine)
4. [Availability & Conflict Detection Algorithm](#4-availability--conflict-detection-algorithm)
5. [Dynamic Pricing & Rate Engine (Peak / Off-Peak)](#5-dynamic-pricing--rate-engine-peak--off-peak)
6. [Realtime Synchronization & Race Condition Prevention](#6-realtime-synchronization--race-condition-prevention)
7. [UI/UX Interaction & Accessibility Blueprint](#7-uiux-interaction--accessibility-blueprint)
8. [Portable Implementation Boilerplate](#8-portable-implementation-boilerplate)

---

## 1. Architecture Overview

The system uses a **discrete interval slot model** (e.g., 1-hour fixed blocks) coupled with **set-based index tracking** for flexible single or contiguous multi-hour bookings.

```mermaid
flowchart TD
    A[User Selects Date & Court] --> B[Fetch Booked Slots for Date]
    B --> C[Compute Slot Availability Grid]
    C --> D[User Selects Time Slot(s)]
    D --> E[Multi-Slot Index Tracker (Set&lt;int&gt;)]
    E --> F[Auto-compute Start/End DateTime & Duration]
    E --> G[Live Pricing Engine (Base + Peak + Addons)]
    G --> H[Proceed to Review / Checkout]
    H --> I[Transient Lock / DB Insertion with Exclusion Constraint]
    I --> J[Supabase Realtime Broadcast to All Clients]
```

### Key Highlights
- **Discrete Granularity:** 1-hour slots from `06:00` (6:00 AM) to `22:00` (10:00 PM) represented as a fixed array of `TimeOfDay` indices `0..15`.
- **Set-Based State:** Selected slots are maintained in a `Set<int>` (`_selectedSlotIndices`) allowing $O(1)$ lookup, dynamic additions, removals, and contiguous duration calculation.
- **Half-Open Intervals:** All overlap calculations use the mathematical standard $[start, end)$ to seamlessly support back-to-back bookings (e.g., 8:00–9:00 AM and 9:00–10:00 AM).
- **Reactive Realtime:** Live PostgreSQL channel updates reflect instantly on all connected client grids when another user books a slot.

---

## 2. Data Models & Schema

### PostgreSQL Database Schema

To prevent double-booking at the database engine level, use a Postgres `btree_gist` extension with an `EXCLUDE` constraint on timestamps:

```sql
-- Enable btree_gist extension for timestamp exclusion
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Courts / Resources Table
CREATE TABLE IF NOT EXISTS public.courts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) DEFAULT 'indoor', -- 'indoor' | 'outdoor' | 'cushioned'
    hourly_rate NUMERIC(10,2) NOT NULL DEFAULT 300.00,
    peak_hourly_rate NUMERIC(10,2) NOT NULL DEFAULT 350.00,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bookings / Reservations Table
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    court_id UUID NOT NULL REFERENCES public.courts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    duration_hours NUMERIC(4,2) NOT NULL,
    total_amount NUMERIC(10,2) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'confirmed', -- 'confirmed' | 'pending_payment' | 'cancelled' | 'expired'
    paddle_rental BOOLEAN DEFAULT FALSE,
    ball_thrower_rental BOOLEAN DEFAULT FALSE,
    guest_email VARCHAR(255),
    payment_reference VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure start is strictly before end
    CONSTRAINT check_booking_times CHECK (start_time < end_time),
    
    -- Prevent double booking for active/confirmed reservations on the same court
    CONSTRAINT exclude_overlapping_bookings EXCLUDE USING gist (
        court_id WITH =,
        tsrange(start_time, end_time, '[)') WITH &&
    ) WHERE (status NOT IN ('cancelled', 'expired', 'void'))
);

CREATE INDEX idx_bookings_court_date ON public.bookings (court_id, start_time, end_time);
CREATE INDEX idx_bookings_user ON public.bookings (user_id);
```

### Core Dart / TypeScript Entities

#### Resource / Court Model
```dart
class CourtModel {
  final String id;
  final String name;
  final String type;
  final double hourlyRate;
  final double peakHourlyRate;
  final bool isActive;

  CourtModel({
    required this.id,
    required this.name,
    required this.type,
    required this.hourlyRate,
    this.peakHourlyRate = 300.0,
    this.isActive = true,
  });
}
```

#### Booking Entity
```dart
class BookingModel {
  final String id;
  final String courtId;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final double totalAmount;
  final String status;

  BookingModel({
    required this.id,
    required this.courtId,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.totalAmount,
    required this.status,
  });
}
```

---

## 3. Time Slot Grid & Multi-Selection Engine

### Slot Array Representation
Operating hours (e.g., 6:00 AM to 10:00 PM) are defined as a list of `TimeOfDay` starting points:

```dart
static const List<TimeOfDay> allStartTimes = [
  TimeOfDay(hour: 6, minute: 0),  // Index 0: 6:00 AM - 7:00 AM
  TimeOfDay(hour: 7, minute: 0),  // Index 1: 7:00 AM - 8:00 AM
  TimeOfDay(hour: 8, minute: 0),  // Index 2: 8:00 AM - 9:00 AM
  TimeOfDay(hour: 9, minute: 0),  // Index 3: 9:00 AM - 10:00 AM
  TimeOfDay(hour: 10, minute: 0), // Index 4: 10:00 AM - 11:00 AM
  TimeOfDay(hour: 11, minute: 0), // Index 5: 11:00 AM - 12:00 PM
  TimeOfDay(hour: 12, minute: 0), // Index 6: 12:00 PM - 1:00 PM
  TimeOfDay(hour: 13, minute: 0), // Index 7: 1:00 PM - 2:00 PM
  TimeOfDay(hour: 14, minute: 0), // Index 8: 2:00 PM - 3:00 PM
  TimeOfDay(hour: 15, minute: 0), // Index 9: 3:00 PM - 4:00 PM
  TimeOfDay(hour: 16, minute: 0), // Index 10: 4:00 PM - 5:00 PM
  TimeOfDay(hour: 17, minute: 0), // Index 11: 5:00 PM - 6:00 PM (Peak)
  TimeOfDay(hour: 18, minute: 0), // Index 12: 6:00 PM - 7:00 PM (Peak)
  TimeOfDay(hour: 19, minute: 0), // Index 13: 7:00 PM - 8:00 PM (Peak)
  TimeOfDay(hour: 20, minute: 0), // Index 14: 8:00 PM - 9:00 PM (Peak)
  TimeOfDay(hour: 21, minute: 0), // Index 15: 9:00 PM - 10:00 PM (Peak)
];
```

### Multi-Slot Selection Modes

You can handle slot selection in two primary ways depending on business rules:

#### Mode A: Contiguous Range Expansion (e.g. In Modal / Quick Picker)
When user selects a starting slot and specifies duration $N$:
```dart
void selectContiguousRange(int startSlotIndex, int durationHours) {
  final maxIndex = allStartTimes.length - 1;
  final clampedDuration = durationHours.clamp(1, allStartTimes.length);
  
  setState(() {
    _selectedSlotIndices = {
      for (int i = 0; i < clampedDuration; i++)
        (startSlotIndex + i).clamp(0, maxIndex)
    };
  });
}
```

#### Mode B: Independent / Additive Multi-Slot Toggle (e.g. 4x4 Quick Grid)
Allows the user to tap individual slots directly to add or remove them from the selection:
```dart
void toggleSlot(int slotIndex) {
  if (isSlotBooked(slotIndex)) return; // Disallow booked slots

  setState(() {
    if (_selectedSlotIndices.contains(slotIndex)) {
      // Prevent emptying selection completely if at least 1 slot is required
      if (_selectedSlotIndices.length > 1) {
        _selectedSlotIndices.remove(slotIndex);
      }
    } else {
      _selectedSlotIndices.add(slotIndex);
    }
  });
}
```

### Deriving Overall Start, End, and Duration
Given `_selectedSlotIndices`:

```dart
int get earliestSlotIndex =>
    _selectedSlotIndices.isEmpty ? 0 : _selectedSlotIndices.reduce((a, b) => a < b ? a : b);

int get latestSlotIndex =>
    _selectedSlotIndices.isEmpty ? 0 : _selectedSlotIndices.reduce((a, b) => a > b ? a : b);

int get totalDurationHours => _selectedSlotIndices.length;

DateTime get calculatedStartDateTime {
  final time = allStartTimes[earliestSlotIndex];
  return DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    time.hour,
    time.minute,
  );
}

DateTime get calculatedEndDateTime {
  final latestTime = allStartTimes[latestSlotIndex];
  // End time is the conclusion of the latest 1-hour slot
  return DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    latestTime.hour + 1,
    latestTime.minute,
  );
}
```

---

## 4. Availability & Conflict Detection Algorithm

### Half-Open Interval Overlap Formula
To determine if a candidate slot overlaps with an existing reservation:

$$\text{Overlap} \iff \text{newStart} < \text{existingEnd} \land \text{newEnd} > \text{existingStart}$$

```dart
class Validators {
  /// Validates half-open time interval overlaps: [newStart, newEnd) vs [existingStart, existingEnd).
  ///
  /// Back-to-back bookings (e.g. 8:00-9:00 AM and 9:00-10:00 AM) where
  /// `newStart == existingEnd` or `newEnd == existingStart` evaluate to FALSE (no overlap / valid).
  static bool hasTimeOverlap({
    required DateTime newStart,
    required DateTime newEnd,
    required DateTime existingStart,
    required DateTime existingEnd,
  }) {
    return newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
  }
}
```

### Slot Availability Check Function

Each slot on the grid checks 3 conditions:
1. **Closing Hour Boundary:** Does the slot exceed facility hours ($hour + 1 > 22$)?
2. **Past Time Check:** If `selectedDate == today`, is `slotStart < DateTime.now()`?
3. **Existing Reservations:** Does $[slotStart, slotEnd)$ overlap with any confirmed booking in `bookedSlotsForDay`?

```dart
bool isSlotBooked(int slotIndex, DateTime selectedDate, List<BookingModel> existingBookings) {
  if (slotIndex >= allStartTimes.length) return true;
  final time = allStartTimes[slotIndex];

  // 1. Operating boundary
  if (time.hour + 1 > 22) return true;

  final slotStart = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    time.hour,
    time.minute,
  );
  final slotEnd = slotStart.add(const Duration(hours: 1));

  // 2. Past time for today
  final now = DateTime.now();
  final isToday = selectedDate.year == now.year &&
      selectedDate.month == now.month &&
      selectedDate.day == now.day;
  if (isToday && slotStart.isBefore(now)) {
    return true;
  }

  // 3. Check overlaps against active database bookings
  for (final b in existingBookings) {
    if (b.status == 'cancelled' || b.status == 'expired' || b.status == 'void') {
      continue;
    }

    if (Validators.hasTimeOverlap(
      newStart: slotStart,
      newEnd: slotEnd,
      existingStart: b.startTime,
      existingEnd: b.endTime,
    )) {
      return true;
    }
  }
  return false;
}
```

---

## 5. Dynamic Pricing & Rate Engine (Peak / Off-Peak)

### Peak vs Off-Peak Logic
Many booking apps charge different rates depending on peak hours (e.g., 5:00 PM – 10:00 PM).

```dart
bool isPeakHour(TimeOfDay time, {int peakStart = 17, int peakEnd = 22}) {
  return time.hour >= peakStart && time.hour < peakEnd;
}

double getSlotRate(
  TimeOfDay time, {
  required double standardRate,
  required double peakRate,
}) {
  return isPeakHour(time) ? peakRate : standardRate;
}
```

### Cumulative Price Computation with Add-Ons

When multiple slots are selected, iterate across all chosen slots to sum exact slot rates + fixed or hourly equipment fees:

```dart
double calculateTotalPrice({
  required Set<int> selectedSlotIndices,
  required List<TimeOfDay> allTimes,
  required double standardRate,
  required double peakRate,
  bool paddleRental = false,       // e.g. Flat +₱150
  bool ballThrowerRental = false,  // e.g. +₱150/hr
}) {
  // Sum individual slot rates (accounting for peak hours)
  double courtSubtotal = selectedSlotIndices.fold(0.0, (sum, idx) {
    final time = allTimes[idx.clamp(0, allTimes.length - 1)];
    return sum + getSlotRate(time, standardRate: standardRate, peakRate: peakRate);
  });

  final durationHours = selectedSlotIndices.length;
  double flatAddons = paddleRental ? 150.0 : 0.0;
  double hourlyAddons = ballThrowerRental ? (150.0 * durationHours) : 0.0;

  return courtSubtotal + flatAddons + hourlyAddons;
}
```

---

## 6. Realtime Synchronization & Race Condition Prevention

### Supabase Realtime Listener Pattern
When User A confirms a booking, User B's screen should immediately disable that slot without requiring a manual page refresh.

```dart
// Subscribe to postgres table changes on public:bookings
void initRealtimeBookings(String currentCourtId, DateTime selectedDate, VoidCallback onUpdateNeeded) {
  supabase.channel('public:bookings')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'bookings',
      callback: (PostgresChangePayload payload) {
        final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
        final courtId = record['court_id'];
        final startTimeStr = record['start_time'];
        
        if (startTimeStr != null) {
          final startTime = DateTime.parse(startTimeStr);
          if (courtId == currentCourtId &&
              startTime.year == selectedDate.year &&
              startTime.month == selectedDate.month &&
              startTime.day == selectedDate.day) {
            onUpdateNeeded(); // Refresh availability cache & setState()
          }
        }
      },
    )
    .subscribe();
}
```

### 5-Minute Transient Lock Flow
To avoid checkout collisions:
1. User confirms time slot $\rightarrow$ Insert record with `status = 'pending_payment'`.
2. Attach `expires_at = NOW() + INTERVAL '5 minutes'`.
3. Other users' availability queries treat `pending_payment` with `expires_at > NOW()` as unavailable.
4. If payment completes $\rightarrow$ update to `status = 'confirmed'`.
5. Background cron / Edge function voids expired locks:
   ```sql
   UPDATE public.bookings 
   SET status = 'expired' 
   WHERE status = 'pending_payment' AND created_at < NOW() - INTERVAL '5 minutes';
   ```

---

## 7. UI/UX Interaction & Accessibility Blueprint

### 4x4 Grid UI Architecture

```
+-------------------------------------------------------------+
| SCHEDULE MATCH TIME                         [Reset Choices] |
| [<]                Mon, Sep 14, 2026                    [>] |
+-------------------------------------------------------------+
| [ 6:00 AM ]   [ 7:00 AM ]   [ 8:00 AM*]   [ 9:00 AM*]       |
| [10:00 AM ]   [11:00 AM ]   [12:00 PM ]   [ 1:00 PM ]       |
| [ 2:00 PM ]   [ 3:00 PM ]   [ 4:00 PM ]   [ 5:00 PM(P)]     |
| [ 6:00 PM(P)] [ 7:00 PM(P)] [~8:00 PM~]   [ 9:00 PM(P)]     |
+-------------------------------------------------------------+
| (V) 8:00 AM – 10:00 AM (2h)                         ₱600    |
+-------------------------------------------------------------+
| [            RESERVE COURT • ₱600             ]             |
+-------------------------------------------------------------+
(* = Selected, (P) = Peak, ~Strikethrough~ = Booked)
```

### Visual Token State Matrix

| State | Background | Border | Text Style | Accessibility Semantics |
| :--- | :--- | :--- | :--- | :--- |
| **Available** | `surfaceHighlight` | `borderSubtle` (1.0px) | `textPrimary`, w600 | `enabled: true`, `selected: false` |
| **Selected** | `textPrimary` (Neon) | `textPrimary` (1.5px) | `background` (contrast), w800 | `enabled: true`, `selected: true` |
| **Peak Hour** | `amber.withAlpha(40)` | `amber.withAlpha(90)` | `amberAccent`, w700 | Label: `"6:00 PM, Peak Rate"` |
| **Booked / Past**| `borderSubtleAlpha50` | `Colors.transparent` | `textMuted`, Strikethrough | `enabled: false`, Label: `"Booked"` |

### Accessibility (WCAG AAA) Requirements
1. **Target Dimensions:** Ensure each slot button maintains a minimum of `48x48dp` tap target area.
2. **Haptic Feedback:** Trigger `HapticFeedback.selectionClick()` on every slot toggle.
3. **Screen Reader Traits:** Wrap in `Semantics(button: true, selected: isSelected, enabled: !isBooked, label: '$timeFormatted, $status')`.

---

## 8. Portable Implementation Boilerplate

Here is a ready-to-use, standalone Flutter widget module implementing the entire multi-selection time slot grid:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StandaloneMultiTimeSlotPicker extends StatefulWidget {
  final DateTime selectedDate;
  final List<TimeOfDay> operatingSlots;
  final List<DateTimeRange> bookedIntervals;
  final double standardHourlyRate;
  final double peakHourlyRate;
  final int peakStartHour;
  final int peakEndHour;
  final void Function(DateTime start, DateTime end, double totalFee) onSelectionChanged;

  const StandaloneMultiTimeSlotPicker({
    super.key,
    required this.selectedDate,
    required this.operatingSlots,
    required this.bookedIntervals,
    this.standardHourlyRate = 300.0,
    this.peakHourlyRate = 350.0,
    this.peakStartHour = 17,
    this.peakEndHour = 22,
    required this.onSelectionChanged,
  });

  @override
  State<StandaloneMultiTimeSlotPicker> createState() => _StandaloneMultiTimeSlotPickerState();
}

class _StandaloneMultiTimeSlotPickerState extends State<StandaloneMultiTimeSlotPicker> {
  final Set<int> _selectedIndices = {};

  bool _isPeak(TimeOfDay time) =>
      time.hour >= widget.peakStartHour && time.hour < widget.peakEndHour;

  double _getSlotRate(TimeOfDay time) =>
      _isPeak(time) ? widget.peakHourlyRate : widget.standardHourlyRate;

  bool _isSlotBooked(int index) {
    if (index >= widget.operatingSlots.length) return true;
    final time = widget.operatingSlots[index];

    final slotStart = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      time.hour,
      time.minute,
    );
    final slotEnd = slotStart.add(const Duration(hours: 1));

    // Past time check
    if (slotStart.isBefore(DateTime.now())) return true;

    // Overlap check [start, end)
    for (final booked in widget.bookedIntervals) {
      if (slotStart.isBefore(booked.end) && slotEnd.isAfter(booked.start)) {
        return true;
      }
    }
    return false;
  }

  void _notifyParent() {
    if (_selectedIndices.isEmpty) return;

    final earliestIdx = _selectedIndices.reduce((a, b) => a < b ? a : b);
    final latestIdx = _selectedIndices.reduce((a, b) => a > b ? a : b);

    final startTimeOfDay = widget.operatingSlots[earliestIdx];
    final latestTimeOfDay = widget.operatingSlots[latestIdx];

    final start = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      startTimeOfDay.hour,
      startTimeOfDay.minute,
    );
    final end = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      latestTimeOfDay.hour + 1,
      latestTimeOfDay.minute,
    );

    final totalFee = _selectedIndices.fold<double>(
      0.0,
      (sum, idx) => sum + _getSlotRate(widget.operatingSlots[idx]),
    );

    widget.onSelectionChanged(start, end, totalFee);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.operatingSlots.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (context, idx) {
            final time = widget.operatingSlots[idx];
            final booked = _isSlotBooked(idx);
            final selected = _selectedIndices.contains(idx);
            final peak = _isPeak(time);

            Color bg = const Color(0xFF1E2923);
            Color textCol = Colors.white;
            Color border = Colors.white24;

            if (booked) {
              bg = Colors.black26;
              textCol = Colors.white38;
              border = Colors.transparent;
            } else if (selected) {
              bg = const Color(0xFFCCFF00); // Brand Neon Accent
              textCol = Colors.black;
              border = const Color(0xFFCCFF00);
            } else if (peak) {
              border = Colors.amber.withOpacity(0.5);
            }

            final timeLabel = '${time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour)}:00 ${time.hour >= 12 ? 'PM' : 'AM'}';

            return InkWell(
              onTap: booked
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_selectedIndices.contains(idx)) {
                          if (_selectedIndices.length > 1) {
                            _selectedIndices.remove(idx);
                          }
                        } else {
                          _selectedIndices.add(idx);
                        }
                      });
                      _notifyParent();
                    },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border, width: selected ? 1.5 : 1.0),
                ),
                child: Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: textCol,
                    decoration: booked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
```

---

## 9. Summary & Adaptation Checklist for Another App

When integrating this into a new app:
- [ ] **Define slot interval & boundary:** E.g., 30-min vs 60-min slots; set daily start & end time limits.
- [ ] **Implement Half-Open Overlap Check:** Always use $newStart < existingEnd \land newEnd > existingStart$.
- [ ] **Use Set<int> for selection:** Keeps multi-selection flexible, high-performance, and contiguous.
- [ ] **Enforce DB-level exclusion constraint:** Use PostgreSQL `EXCLUDE USING gist (resource_id WITH =, tsrange(start, end) WITH &&)` to guarantee zero race-condition double bookings.
- [ ] **Subscribe to Realtime Events:** Broadcast new bookings to instantly update the slot grid for other active users.
