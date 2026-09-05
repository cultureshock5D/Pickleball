# Comprehensive Technical Survey: Backend, Security, Payments & Player Analytics
**Repository:** `cultureshock5D/Pickleball`  
**Explorer:** `explorer_survey_2` (Backend, Security, Payments & Stats Explorer)  
**Date:** 2026-09-03  
**Status:** Completed  

---

## Executive Summary

This survey provides an in-depth architectural and implementation audit across four core domains:
1. **Supabase & Database (Domain 2)**: Relational schema alignment, PostgREST query joins, data models, and zero-latency offline cache fallback.
2. **Security & NIST Hardening (Domain 3)**: Anchored input validation, NIST SP 800-63B password bounds, Trojan Source unicode defenses, auth lifecycle, and credential isolation.
3. **Payments & Check-In (Domain 4)**: PayMongo multi-channel payment flows (GCash, Maya, GrabPay, Cards), itemized checkout breakdown, dynamic 30-second rolling QR gate passes, and RFC 5545 multi-calendar deep links.
4. **Player Stats & Analytics (Domain 7)**: Multi-horizon period filtering, court utilization telemetry, DUPR rating computation models, and athletic performance tracking.

---

## 1. Domain 2: Supabase & Database Architecture

### 1.1 Relational Queries & PostgREST Joins
The application utilizes `supabase_flutter` with structured PostgREST relational queries located in `lib/services/booking_service.dart`:

- **Venue & Court Joins**:
  - In `BookingService.fetchActiveCourts({String? venueId})`:
    ```dart
    response = await _supabase!
        .from('courts')
        .select('*, venues(name)')
        .eq('status', 'active')
        .eq('venue_id', venueId);
    ```
    - The join `courts(*, venues(name))` retrieves foreign key relational data from `venues`.
    - Deserialization in `CourtModel.fromJson` (`lib/models/court_model.dart`, lines 73–76):
      ```dart
      String? parsedVenueName = json['venue_name'] as String?;
      if (parsedVenueName == null && json['venues'] != null && json['venues'] is Map) {
        parsedVenueName = json['venues']['name'] as String?;
      }
      ```
  - In `BookingService.fetchCustomerBookings()`:
    ```dart
    response = await _supabase!
        .from('bookings')
        .select('*, courts(name)')
        .eq('customer_id', user.id)
        .order('start_time', ascending: false);
    ```
    - Resolves court display names via nested `courts(name)` join.
    - Deserialized cleanly in `BookingModel.fromJson` (`lib/models/booking_model.dart`, lines 25–30).
  - In `BookingService.fetchCourtBookingsForDate(String courtId, DateTime date)`:
    - Filters by date bounds using ISO-8601 UTC timestamps with `gte` and `lte` filters:
      ```dart
      .gte('start_time', startOfDay.toUtc().toIso8601String())
      .lte('start_time', endOfDay.toUtc().toIso8601String())
      ```

### 1.2 Model Alignment & Gaps
The models in `lib/models/` map to database tables as follows:

| Model | Target DB Table | Current Fields | Missing / Desirable Sports-Tech Fields |
|---|---|---|---|
| `CourtModel` | `public.courts` | `id`, `name`, `status`, `hourlyRate`, `peakHourlyRate`, `peakStartHour`, `peakEndHour`, `surfaceType`, `courtType`, `venueId`, `venueName` | Peak schedule calendar rules, maintenance blackout periods, lighting status |
| `BookingModel` | `public.bookings` | `id`, `customerId`, `courtId`, `startTime`, `endTime`, `status`, `totalAmount`, `createdAt`, `courtName` | `payment_method`, `payment_reference` (PayMongo `pm_pi_...`), `check_in_time`, `check_out_time`, `overtime_minutes` |
| `UserProfile` | `public.profiles` | `id`, `fullName`, `role`, `createdAt` | `dupr_rating`, `dupr_singles`, `dupr_doubles`, `membership_tier`, `match_count`, `win_count`, `loss_count`, `avatar_url` |
| `VenueModel` | `public.venues` | `id`, `name`, `city`, `address`, `rating`, `reviewCount`, `amenities`, `courtCount`, `priceStartingAt`, `tag`, `courtType` | Coordinates (`latitude`, `longitude`), operating hours range (`open_time`, `close_time`), contact telephone |

### 1.3 Concurrency Control & Transient Slot Holding
- Currently, `BookingService.createBooking` performs a direct insert with `status: 'pending'`.
- Per `future.md` (Feature 2) and `MULTIAGENT_TASKS.md` (Workstream 1), the target enterprise pattern is a 5-minute transient lock using Postgres advisory locking (`fn_hold_court_slot`).

### 1.4 Offline Fallback & Cache Synchronization
`BookingService` implements a dual-layer caching and fallback system:
- **Bounded In-Memory Cache**:
  - Key: `${courtId}_YYYY-MM-DD`
  - Max entries: `_maxCacheEntries = 60` (FIFO eviction via `_courtAvailabilityCache.remove(_courtAvailabilityCache.keys.first)`).
  - Synchronous cache lookups via `getCachedAvailability(courtId, date)` for zero jank during date navigation.
  - Targeted cache invalidation on booking creation (`invalidateAvailabilityCache(courtId: courtId, date: startTime)`).
  - Complete cache clearance on `AuthService.signOut()` to prevent cross-account cache leakage.
- **Mock Data Fallback (`lib/data/mock_data.dart`)**:
  - When offline or when Supabase credentials are not supplied, all read/write operations seamlessly fall back to `MockData` (4 venues, 12 courts, pre-seeded active bookings, and demo user `Alex Morgan`).
  - `BookingService.createBooking` simulates network latency (150ms) and updates in-memory mock lists.

---

## 2. Domain 3: Security, Auth & NIST Hardening

### 2.1 Input Validation & Regex Anchoring
Located in `lib/core/utils/validators.dart`:
- **Strict Anchored Email Regex**:
  ```dart
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );
  ```
  - Begins with `^` and terminates with `$`.
  - Conforms to RFC 5322.
  - Enforces `maxEmailLength = 254` (RFC 5321 limit).
- **Full Name Boundaries**:
  - Length: `2 <= length <= 70` (`maxFullNameLength = 70`).
  - Strips leading/trailing whitespace.
  - Rejects newlines (`\n`, `\r`).

### 2.2 Trojan Source & Unicode Control Character Defense
- Regular expression:
  ```dart
  static final RegExp _controlCharRegex = RegExp(
    r"[\u0000-\u001F\u007F-\u009F\u200E\u200F\u202A-\u202E]",
  );
  ```
- Protects against:
  - C0 control codes (`\u0000` to `\u001F`)
  - C1 control codes and DEL (`\u007F` to `\u009F`)
  - Bi-directional marks (`\u200E`, `\u200F`)
  - Bi-directional overrides (`\u202A` through `\u202E`: LRE, RLE, PDF, LRO, RLO) preventing Trojan Source attacks (CVE-2021-42574).
- Generic sanitizer helper:
  - `Validators.sanitizeText(String? input, {int maxLength = 255})` strips control characters, trims, and truncates to safe bounds.

### 2.3 NIST SP 800-63B Password Bounds
- `minPasswordLength = 8`: Complies with NIST SP 800-63B Section 5.1.1.2 requirements.
- `maxPasswordLength = 128`: Prevents Hash DoS and ReDoS vulnerabilities in password hashing routines (bcrypt, Argon2, PBKDF2).
- `validatePassword`: Validates both lower and upper length bounds without arbitrary complexity rules that degrade user usability.

### 2.4 Auth Lifecycle & Credential Isolation
Located in `lib/services/auth_service.dart` and `lib/core/constants/supabase_config.dart`:
- **Separation of Concerns**:
  - Clearly differentiates mock demo sessions (`isDemoMode`, `isDemoLoggedIn`) from live Supabase accounts (`isLiveUser`).
  - Real user profiles are fetched strictly from `public.profiles`. If no row exists yet, fallback profile is generated from live user metadata (`metaName`, `emailPrefix`), never demo data.
- **Sign-Out Teardown**:
  - Invalidates in-memory booking availability cache.
  - Emits `AuthChangeEvent.signedOut` event.
  - Disposes demo session state.
- **Zero Hardcoded Secrets (`SupabaseConfig`)**:
  - `_defaultUrl = ''` and `_defaultAnonKey = ''`.
  - Resolution order: `flutter_dotenv` -> `String.fromEnvironment` (`--dart-define`) -> empty string fallback.
  - `isConfigured` checks that URL has scheme/host, is not `'your-project'`, and anon key is not empty and not `'your-anon-key'`.
  - `.env` and `referenceonly/` are explicitly listed in `.gitignore`.

---

## 3. Domain 4: Payments & Check-In Systems

### 3.1 PayMongo Multi-Channel Payment Integration
- **Current UI State (`lib/screens/booking/booking_review_screen.dart`)**:
  - The payment method section currently displays generic options: "Apple Pay / Google Pay" and "Club Membership Card".
  - **Identified Elevation Need**: Expand the selection to include PayMongo's prominent Philippine payment channels:
    1. **GCash** (Mobile Wallet - PayMongo Source/PaymentIntent)
    2. **Maya** (Digital Bank / Wallet)
    3. **GrabPay** (E-Wallet)
    4. **Credit / Debit Cards** (Visa, Mastercard, JCB via PayMongo Checkout)
- **Itemized Ledger in `BookingReviewScreen`**:
  - Details Court Base Rate, Duration, Subtotal, Service Fee (`FREE ₱0.00`), and Total in Philippine Pesos (`₱`).
  - Surcharge visibility: Can be enhanced to visually isolate Peak Hour Surcharges dynamically when slots overlap with peak hours (5:00 PM – 10:00 PM).

### 3.2 Official Downloadable Receipt Manager (`lib/widgets/downloadable_receipt_modal.dart`)
- Clean luxury invoice modal displaying:
  - Booking ID, Court Name, Reserved Slot Date/Time.
  - Payment Method: Default `'GCash via PayMongo'`.
  - Transaction Reference: Default `'pm_ref_8921938210'`.
  - Itemized calculation: Court hourly rate, hours duration, tax & service fee.
  - Total Paid in `₱`.
  - Interactive triggers: "Download PDF" and "Share Receipt" with user feedback.

### 3.3 Dynamic Gate Pass QR Generation (`lib/widgets/check_in_qr_modal.dart`)
- **30-Second Rolling Token**:
  - Formula: `seed = (_now.millisecondsSinceEpoch ~/ 30000).toRadixString(16).toUpperCase();`
  - Token: `'PKL-[ID]-[SEED]'` (prevents replay and static screenshot sharing).
- **Session Telemetry & Countdown**:
  - 1-second periodic timer calculating remaining session minutes/seconds or time until session opens.
  - Handles overtime detection (`Overtime: +Xm Ys`).
- **Interactive State Machine**:
  - Visual status transitions: `UPCOMING • READY FOR GATE` -> `CHECKED IN • SESSION ACTIVE` -> `CHECKED OUT • CONCLUDED`.
  - Pulsing animated badge with glow effects.
  - Interactive gate scan simulation toggle for kiosk testing.

### 3.4 RFC 5545 Multi-Calendar Deep Links (`lib/services/calendar_link_service.dart`)
- **Zero-Auth Integration**:
  - `buildGoogleCalendarUri` / `buildGoogleCalendarUrl`: Constructs Google Calendar web template URL with start/end UTC timestamps formatted as `YYYYMMDDTHHmmSSZ`.
  - `buildAppleCalendarUrl`: Constructs RFC 5545 `data:text/calendar;charset=utf8,...` payload.
  - `buildOutlookCalendarUrl`: Constructs Outlook Online compose URL.
  - `buildIcsCalendarData`: Full RFC 5545 VCALENDAR/VEVENT payload with UID, DTSTAMP, DTSTART, DTEND, SUMMARY, DESCRIPTION, LOCATION, and STATUS.
- **Safe Launching**:
  - `launchCalendarLink` verifies URI parsing and invokes `url_launcher` in `LaunchMode.externalApplication`.

---

## 4. Domain 7: Player Stats & Analytics

### 4.1 Period Horizon Filtering (`lib/screens/insights/insights.dart`)
- Three distinct horizons:
  - **This Week**: `b.startTime.isAfter(now.subtract(const Duration(days: 7)))`
  - **This Month**: `b.startTime.isAfter(now.subtract(const Duration(days: 30)))`
  - **All-Time**: Complete booking history.
- Horizontally scrollable period pills with full WCAG Semantics (`Semantics(button: true, selected: ...)`).

### 4.2 Court Utilization & Habit Metrics
Currently calculated dynamically on horizon switch:
- **Total Court Playtime**: Total minutes converted to hours.
- **Reservations**: Total booking count.
- **Total Spend**: Total expenditure in ₱.
- **Average Session Duration**: Total hours divided by bookings.
- **Weekly Playtime Distribution**: Day-of-week hour accumulation (Mon–Sun) displayed in an interactive vertical bar chart with peak indicator.
- **Court Distribution**: Identifies most frequented court and percentage of total playtime.
- **Peak Play Slot**: Categorized into Morning (<12:00), Afternoon (<17:00), or Evening (>=17:00).
- **Attendance Rate**: Currently static 100% (0 Cancellations).

### 4.3 DUPR Rating & Performance Telemetry Analysis
- **Current Gap**: Neither `UserProfile` nor `InsightsScreen` currently stores or renders a DUPR (Dynamic Universal Pickleball Rating) score.
- **Target Sports-Tech Specification (Playtomic / Strava benchmark)**:
  1. **DUPR Score Card**:
     - Player rating (e.g., `3.84 ± 0.12`).
     - Singles vs Doubles rating breakdown.
     - Skill Tier Badge: e.g., "Intermediate (3.5 - 4.0)" or "Advanced (4.0+)".
  2. **Match Record & Win Rate Telemetry**:
     - Win/Loss record (e.g., `18W - 6L` • `75% Win Rate`).
     - Point differential telemetry.
  3. **Court Utilization Efficiency**:
     - Hours utilized vs weekly target (e.g., `6.5 / 8.0 hrs` target gauge).

---

## 5. Architectural Recommendations for Phase 1 Elevation

1. **Database & Models**:
   - Extend `UserProfile` to include `double? duprRating`, `int matchCount`, `int winCount`, `String? skillLevel`.
   - Extend `BookingModel` to include `String? paymentMethod`, `String? paymentReference`, `DateTime? checkInTime`.
2. **Payments UI**:
   - Add PayMongo channels (GCash, Maya, GrabPay, Cards) to `BookingReviewScreen` with branded luxury icons and badges.
   - Forward selected payment method to `DownloadableReceiptModal` and `BookingSuccessModal`.
3. **Sports-Tech Analytics UI**:
   - Incorporate DUPR Rating hero telemetry card in `InsightsScreen`.
   - Add match win/loss and efficiency counters to provide a Strava/Playtomic-style competitive experience.
   - Wrap intensive charts in `RepaintBoundary` for 60/120 FPS render performance.
4. **Security Hardening**:
   - Maintain strict `Validators` sanitization on all new text and query inputs.

---
*Report authored by `explorer_survey_2` for multi-agent synchronization.*
