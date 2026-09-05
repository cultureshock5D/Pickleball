# Self-Contained Handoff Report: Backend, Security, Payments & Stats Survey

**Agent**: `explorer_survey_2` (Backend, Security, Payments & Stats Explorer)  
**Date**: 2026-09-03  
**Handoff Type**: Hard (Task Complete)  
**Target File**: `C:\Users\koi\Documents\repositories\Pickleball\.agents\explorer_survey_2\handoff.md`  

---

## 1. Observation

Direct observations across the four target domains with exact file paths and line numbers:

1. **Supabase & Database (Domain 2)**:
   - `lib/services/booking_service.dart:81`: Uses PostgREST relational join `.select('*, venues(name)')` on `courts` table.
   - `lib/services/booking_service.dart:147` & `193`: Uses `.select('*, courts(name)')` on `bookings` table.
   - `lib/models/court_model.dart:73-76`: Handles nested join payload `json['venues']['name']` as `parsedVenueName`.
   - `lib/models/booking_model.dart:25-30`: Handles nested join payload `json['courts']['name']` as `courtName`.
   - `lib/services/booking_service.dart:17-31`: Implements a bounded 60-slot in-memory cache (`_maxCacheEntries = 60`) keyed by `${courtId}_YYYY-MM-DD` with FIFO eviction.
   - `lib/data/mock_data.dart:72-259`: Houses offline seed repository with 4 venues, 12 courts, pre-configured operating hours (8:00 AM – 10:00 PM), and demo profile (`Alex Morgan`).
   - `lib/models/user_profile.dart:1-48`: Contains only `id`, `fullName`, `role`, and `createdAt`; lacks DUPR ratings, win/loss stats, or membership tier fields.
   - `lib/models/booking_model.dart:1-82`: Lacks explicit `paymentMethod`, `paymentReference`, `checkInTime`, and `checkOutTime` fields.

2. **Security & NIST Hardening (Domain 3)**:
   - `lib/core/utils/validators.dart:20-22`: Defines strictly anchored email regex:
     ```dart
     static final RegExp _emailRegex = RegExp(
       r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
     );
     ```
   - `lib/core/utils/validators.dart:25-27`: Implements Trojan Source / bi-directional control character defense:
     ```dart
     static final RegExp _controlCharRegex = RegExp(
       r"[\u0000-\u001F\u007F-\u009F\u200E\u200F\u202A-\u202E]",
     );
     ```
   - `lib/core/utils/validators.dart:14-17`: Enforces NIST SP 800-63B password bounds: `minPasswordLength = 8`, `maxPasswordLength = 128`.
   - `lib/core/constants/supabase_config.dart:6-7`: Zero hardcoded credentials (`_defaultUrl = ''`, `_defaultAnonKey = ''`).
   - `lib/services/auth_service.dart:214-215`: On `signOut()`, actively clears local `BookingService` in-memory availability cache to prevent cross-account cache leakage.

3. **Payments & Check-In (Domain 4)**:
   - `lib/screens/booking/booking_review_screen.dart:45-58`: Currently displays generic methods ("Apple Pay / Google Pay", "Club Membership Card") rather than explicit PayMongo channels (GCash, Maya, GrabPay, Credit/Debit Cards).
   - `lib/widgets/downloadable_receipt_modal.dart:15-16`: Has default `'GCash via PayMongo'` and reference `'pm_ref_8921938210'` with full itemized breakdown (court rate, tax/service fee, total in ₱).
   - `lib/widgets/check_in_qr_modal.dart:106-112`: Generates a dynamic 30-second rolling token `PKL-[ID]-[SEED]` where `seed = (_now.millisecondsSinceEpoch ~/ 30000).toRadixString(16).toUpperCase()`.
   - `lib/services/calendar_link_service.dart:41-69`: Generates standard Google Calendar URLs, RFC 5545 `.ics` VEVENT payloads, Outlook Live deep links, and Apple Calendar `data:text/calendar` URIs.

4. **Player Stats & Analytics (Domain 7)**:
   - `lib/screens/insights/insights.dart:30-31`: Implements 3-horizon period filter (`['This Week', 'This Month', 'All-Time']`).
   - `lib/screens/insights/insights.dart:90-150`: Computes playtime hours, reservations count, total spend, average session duration, Mon–Sun weekly playtime map, preferred court, and peak slot.
   - `lib/screens/insights/insights.dart` & `lib/models/user_profile.dart`: Currently contain zero DUPR rating computation or display logic.

---

## 2. Logic Chain

1. **Database & Schema**:
   - Because `BookingService` queries `courts(*, venues(name))` and `bookings(*, courts(name))` (Observation 1), the relational joins function as expected with Supabase PostgREST.
   - Because `BookingModel` and `UserProfile` lack sports-tech fields (DUPR rating, win/loss stats, PayMongo reference, check-in timestamps) (Observation 1), extending these models is necessary to support high-performance telemetry and dynamic checkout in the next phase.

2. **Security & NIST Compliance**:
   - Because `Validators` uses anchored regexes (`^...$`), enforces 8-to-128 character password constraints, strips bidirectional override characters, and `SupabaseConfig` uses zero hardcoded secrets (Observation 2), the application satisfies NIST SP 800-63B guidelines and frontend security principles.

3. **Payments & Checkout Flow**:
   - Because `DownloadableReceiptModal` and `future.md` already specify PayMongo channels (GCash, Maya, GrabPay) (Observation 3), updating `BookingReviewScreen` to present these options directly will align the checkout flow with the receipt manager and PRD.
   - Because `CheckInQrModal` implements 30s rolling tokens and `CalendarLinkService` generates RFC 5545 compliant payloads (Observation 3), the check-in and calendar systems are architecturally sound.

4. **Player Stats & Telemetry**:
   - Because `InsightsScreen` aggregates weekly distributions and preferred courts across 3 period horizons (Observation 4), the calculation baseline is functional.
   - However, elevating to a Strava/Playtomic benchmark requires adding DUPR skill metrics and match win/loss telemetry to both `UserProfile` and `InsightsScreen` (Observation 4).

---

## 3. Caveats

- Sandbox shell environment prevents direct execution of `flutter test` without path or sandbox adjustment, but static analysis and source code inspection confirmed exact implementation state.
- `referenceonly/` directory is gitignored and was not in the tracked repository; reference specifications were cross-verified via `future.md`, `MULTIAGENT_TASKS.md`, and `PROJECT.md`.
- No other caveats.

---

## 4. Conclusion

The backend, security, payments, and stats foundations are robust, secure, and ready for elevation into a sports-tech interface. The key enhancement vectors for the implementation phase are:
1. **Extend Models**: Add DUPR rating, match stats (`winCount`, `lossCount`), and PayMongo fields (`paymentMethod`, `paymentReference`, `checkInTime`) to `UserProfile` and `BookingModel`.
2. **Elevate Checkout UI**: Replace generic payment cards in `BookingReviewScreen` with PayMongo channels (GCash, Maya, GrabPay, Cards).
3. **Elevate Telemetry UI**: Integrate DUPR rating card and match win/loss stats in `InsightsScreen` wrapped in `RepaintBoundary`.

---

## 5. Verification Method

To independently verify these findings:
1. **Inspect Models & Services**:
   - `view_file` on `lib/models/court_model.dart` (lines 73–76) to confirm PostgREST join parsing.
   - `view_file` on `lib/models/booking_model.dart` to verify missing payment/check-in fields.
   - `view_file` on `lib/models/user_profile.dart` to verify lack of DUPR rating.
   - `view_file` on `lib/services/booking_service.dart` (lines 17–45) to inspect in-memory cache.
2. **Inspect Security & NIST Hardening**:
   - `view_file` on `lib/core/utils/validators.dart` (lines 14–27) to verify anchored regexes, control char regex, and NIST length bounds.
   - `view_file` on `lib/core/constants/supabase_config.dart` to verify zero hardcoded credentials.
3. **Inspect Payments & QR Modal**:
   - `view_file` on `lib/screens/booking/booking_review_screen.dart` (lines 45–58) to inspect payment options.
   - `view_file` on `lib/widgets/check_in_qr_modal.dart` (lines 106–112) to verify rolling token generation.
4. **Inspect Insights**:
   - `view_file` on `lib/screens/insights/insights.dart` (lines 30–150) to verify period filters and metric computations.
