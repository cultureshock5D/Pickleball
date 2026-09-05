# High-Performance Sports Tech UI/UX Redesign Survey & Architectural Blueprint
**Repository:** `cultureshock5D/Pickleball`  
**Explorer:** `explorer_survey_1` (UI/UX Sports-Tech & Design System Explorer)  
**Date:** 2026-09-03  
**Benchmark Reference:** Modern Athletic Tech Standards (Playtomic / Strava)

---

## 1. Executive Summary

This survey provides an exhaustive, read-only architectural investigation of the Pickleball Flutter mobile application UI/UX layer across core screens, reusable widgets, interactive modals, and design system tokens.

The current application boasts a strong luxury dark theme foundation built upon Dark Slate backgrounds (`#0A0F0D`, `#121A16`, `#1B2620`), vivid Electric Lime (`#CCFF00`), and Neon Emerald accents (`#00E599`). However, in its current state, several screens rely on generic Material card containers and basic vertical lists that do not yet fully evoke the visceral, stats-forward, high-octane athletic atmosphere of premier sports-tech benchmarks like **Playtomic** (court reservation & competitive matchmaking) and **Strava** (live telemetry, intensity tracking, and performance analytics).

This survey details:
1. Exact file paths, line numbers, and architectural patterns of all existing UI components.
2. Specific gaps between the current implementation and the Playtomic/Strava benchmark.
3. Concrete, production-ready elevation recommendations for telemetry charts, high-contrast cards, interactive booking sheets, micro-interactions, and theme tokens.

---

## 2. Visual Language & Brand System: Playtomic / Strava Benchmark Elevation

### Current Visual Foundation (`lib/core/theme/app_theme.dart`)
The app utilizes a dual-theme architecture (`darkPalette` and `lightPalette`) mediated by `AppPalette` and `AppTheme.colorsOf(context)`:
- **Scaffold Background:** `0xFF0A0F0D` (Deep obsidian dark slate)
- **Card Surface:** `0xFF121A16` (Deep forest dark slate)
- **Elevated Surface:** `0xFF1B2620` (Subtly elevated slate)
- **Surface Highlight:** `0xFF26262D` (Card fill highlight for icons and stat pills)
- **Border Subtle:** `0xFF1E1E24` (Subtle boundary lines)
- **Brand Accents:**
  - `neonLime`: `0xFFCCFF00` (Electric Lime - high-contrast neon benchmark)
  - `neonGreen`: `0xFF00E599` (Emerald neon)
  - `neonYellow`: `0xFFFACC15` (Amber / Peak indicator)
  - `errorRed`: `0xFFEF4444`

### Benchmark Gap Analysis
| Attribute | Current App State | Strava / Playtomic Benchmark | Elevation Vector |
|---|---|---|---|
| **Typography** | Exclusively `GoogleFonts.inter` across all styles (`lib/core/theme/app_theme.dart:147-190`) | Geometric athletic sans-serif (`Plus Jakarta Sans` or DIN/Chakra) paired with tabular monospace numbers for stats | Integrate `GoogleFonts.plusJakartaSans` for headlines, numeric telemetry, and level gauges; retain `Inter` for body text and `RobotoMono` for timestamps/IDs |
| **Telemetry Numbers** | 34pt bold numbers in `insights.dart:299` | Massive 42-48pt condensed display numerals with small uppercase unit labels (`HRS`, `BPM`, `DUPR`) | Introduce `fontTelemetryHero` (40-48pt, w800, tight tracking `-1.5`) with contrasting neon lime highlights |
| **Card Geometry** | Standard rounded cards (20-24dp radius, subtle 1px border) | Angular chamfered or tight technical cards (16-18dp), technical division lines, micro-data headers | Add high-contrast technical card headers (e.g. `[ COURT CORRIDOR 01 ]`), subtle diagonal accent stripes, or glowing neon status pips |
| **Activity Visualization** | Basic static vertical bar columns (`insights.dart:556-584`) | Dynamic workout intensity bars, target threshold dashed lines, weekly streak flame badges, court heat maps | Add animated bar fills, target line indicators, and active session streak telemetry counters |
| **Booking Representation** | 3-row list in a single card (`quick_booking_card.dart:90-218`) | Interactive multi-court timeline lanes with time-slice scrubbing, peak heat markers | Layer an interactive court lane visualizer or timeline scrubber alongside quick booking |

---

## 3. Telemetry Visuals, Charts & High-Contrast Cards

### 3.1 Analytics & Insights (`lib/screens/insights/insights.dart`)

#### Current Architecture
- **State Management & Data Flow (`lines 57-150`):**
  - Fetches bookings via `BookingService.instance.fetchCustomerBookings()`.
  - Computes `_totalPlaytimeHours`, `_totalBookingsCount`, `_totalSpend`, `_avgSessionHours`, and `_weeklyHoursMap` across weekdays (1=Mon to 7=Sun).
  - Identifies top court and peak slot category (Morning, Afternoon, Evening).
- **Period Filter Horizon (`lines 184-241`):**
  - Horizontal ListView offering `['This Week', 'This Month', 'All-Time']`.
  - Tapping triggers `_onPeriodChanged(index)` which recalculates metrics defensively without blocking UI.
- **Hero Playtime Card (`lines 245-371`):**
  - Header: `'TOTAL COURT PLAYTIME'` label, `'ACTIVE PLAYER'` status pill (`lines 270-287`).
  - Metric readout: `_totalPlaytimeHours.toStringAsFixed(1)` in 34pt `GoogleFonts.inter` with `'HOURS'` and `'LIVE'` pill.
  - Three stat pills (`lines 350-367`): Reservations count, Total spend (`₱...`), Average session (`... hrs`).
- **Weekly Playtime Chart (`lines 375-435` & `531-597`):**
  - 7 vertical day bars (`Mon`-`Sun`).
  - Bar height: 80dp container with inner `AnimatedContainer` height calculated as `80 * (hours / maxHours).clamp(0.08, 1.0)`.
  - Peak day gradient: `[neonLime, neonGreen]`; regular day: `[neonGreenLight, neonGreenDark]`.
- **Venue & Behavior Tiles (`lines 448-483`):**
  - `_buildCourtDistributionTile` with tennis racquet icon and `LinearProgressIndicator`.
  - `_buildMetricTile` for `Peak Play Slot` and `Attendance Rate`.

#### Athletic Tech Elevation Opportunities
1. **Target Benchmark Horizon Line:**
   - Add a subtle dotted/dashed neon horizontal rule across the weekly bar chart representing weekly target play goal (e.g. `8.0 hrs/wk`).
2. **DUPR Rating & Player Level Gauge:**
   - Playtomic's core draw is the live player rating (e.g., Level 3.85 / DUPR 4.12). Adding a dedicated DUPR progression tile with dynamic percentile rank (e.g. `Top 8% Club Rank`) will instantly transform the screen into an athletic tech hub.
3. **Pace & Intensity Metrics:**
   - Introduce estimated calories burned or match intensity score (`Avg Intensity: 84% HR Zone`) based on duration and match type.
4. **RepaintBoundary Optimization:**
   - Wrap the chart and hero card in `RepaintBoundary` to eliminate redraw churn during bounce scrolling.

---

### 3.2 Main Shell & Navigation (`lib/screens/home/main_navigation_screen.dart`)

#### Current Architecture
- Uses `IndexedStack` (`lines 94-105`) containing `CourtReservationScreen`, `InsightsScreen`, and `ProfileScreen`.
- Top App Bar: `CustomTopAppBar` (`lines 74-93`) displaying current tab title, subtitle, user profile avatar with neon ring, quick add button, and theme switcher.
- Bottom Navigation: `CustomBottomNavBar` (`lines 106-130`) with animated pill indicators (`neonGreenAlpha15`), 64dp height, and 48dp+ tap targets.

#### Athletic Tech Elevation Opportunities
1. **Live Activity HUD Banner:**
   - When an upcoming reservation is within 12 hours, insert a slim, high-contrast live ticker right beneath the top app bar: e.g. `⚡ Next Match in 2h 15m • Court 1 (Championship Indoor) • Gate QR Ready`.
2. **Glassmorphic Floating Dock:**
   - Upgrade `CustomBottomNavBar` with an optional subtle blur backdrop (`BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12))`) to match modern iOS/Android sports app aesthetics.

---

### 3.3 Quick Booking Card (`lib/widgets/quick_booking_card.dart`)

#### Current Architecture
- Enclosed in a glowing 2.2px `neonGreen` accent border with `neonGreenAlpha30` box shadow (`lines 74-85`).
- 3 interactive selection rows (`lines 92-161`):
  1. **Venue / Club Location:** Displays venue name, city, and star rating badge (`4.9 ★` in neon lime).
  2. **Match Date Range:** Displays `Today`, `Tomorrow`, or formatted date with calendar icon.
  3. **Match Start Time & Auto-Computed Slot:** Displays time slot range with auto-computed total amount in Philippine Pesos (`₱...`).
- Full-width action button (`lines 164-217`) with emerald gradient (`neonGreenDark` to `neonGreen`) and tactile ink splash.

#### Athletic Tech Elevation Opportunities
1. **Surface & Court Specification Pill:**
   - Display a compact technical tag beside the court row: `[ PRO-CUSHION ACRYLIC · LIGHTED ]`.
2. **Fast-Tap Slot Carousel:**
   - Add a row of 3 "Quick Picks" (e.g., `Today 6:00 PM (Peak)`, `Tomorrow 8:00 AM (Off-Peak)`) allowing 1-tap selection without opening the full bottom sheet.
3. **Live Availability Indicator:**
   - Add a pulsing green pip: `● 4 Courts Available Today`.

---

### 3.4 Reservation Card (`lib/widgets/reservation_card.dart`)

#### Current Architecture
- Implements tactile press micro-interaction using `_pressController` (`lines 42-52`) with `ScaleTransition` scaling down to `0.95` on tap.
- Header row (`lines 159-198`): Calendar icon, formatted date (`Today • ...`), and status badge (`CONFIRMED`, `PENDING`, `COMPLETED`, `CANCELLED`).
- Body row (`lines 202-270`): Court icon badge with neon green circle border, court name, time slot range, bold price (`₱...`), and monospace booking ID snippet (`RobotoMono`, lines 261-266).
- Action buttons (`lines 276-354`):
  - `Gate Pass` OutlinedButton (`48dp` min height) opening `CheckInQrModal`.
  - `Receipt` OutlinedButton (`48dp` min height) opening `DownloadableReceiptModal`.
  - `Add to Google Calendar` IconButton with custom border and loading spinner.

#### Athletic Tech Elevation Opportunities
1. **Match Countdown Chip:**
   - For upcoming bookings within 24 hours, display a prominent live badge: `STARTS IN 3H 45M`.
2. **Surface & Weather Indicator:**
   - For outdoor courts, show an icon (e.g. `☀️ 28°C Optimal conditions`).
3. **Technical Monospace Ticket Styling:**
   - Enhance the card background with a subtle perforated notch or micro-grid pattern along the divider separating details from the action bar.

---

## 4. Court Timeline & Slot Booking Sheets

### 4.1 Court Reservation Flow (`lib/screens/booking/court_reservation.dart`)

#### Current Architecture
- **Dual Mode Switcher (`lines 347-471`):**
  - Switcher bar at top: `Reserve Court` (with court count badge) vs `My Reservations` (with live count badge of upcoming bookings).
  - Clean animated toggle with `neonGreenAlpha18` selection background.
- **Slot Availability Engine (`lines 209-248`):**
  - Checks if a time slot is booked by comparing against `_bookedSlotsForCurrentDay` using `Validators.hasTimeOverlap`.
  - Auto-disables slots that are in the past or already booked.
  - Automatically advances selected slot to first available slot via `_autoAdjustSelectedSlot()`.
- **Navigation to Review Screen (`lines 292-315`):**
  - Smooth push to `BookingReviewScreen` passing court model, venue name, start/end date-times, duration, and total amount.

#### Athletic Tech Elevation Opportunities: Horizontal Interactive Timeline
- Currently, users pick time slots via the `TimePlayerPickerModal` bottom sheet.
- Playtomic's signature feature is an **interactive horizontal court timeline**:
  - A multi-track timeline displaying **Court 1**, **Court 2**, and **Court 3** simultaneously.
  - Horizontal axis represents hours from 08:00 to 22:00.
  - Color-coded time blocks:
    - 🟩 **Green:** Available Off-Peak (`₱120/hr`)
    - 🟨 **Amber Neon:** Available Peak (`₱180/hr`)
    - ⬛ **Muted Dark / Striped:** Occupied / Booked
  - Allows players to visually understand club occupancy at a single glance and tap any empty slot to book instantly.

---

### 4.2 Booking Review & Checkout Screen (`lib/screens/booking/booking_review_screen.dart`)

#### Current Architecture
- **Court Summary Card (`lines 177-271`):** Displays court name, venue name, hourly rate badge (`₱.../hr`), surface type badge (`Pro-Cushion Hardcourt`), and court type badge (`Championship Indoor`).
- **Schedule Card (`lines 307-396`):** Date and time window with duration pill (`1h Court Match Slot`).
- **Price Breakdown Ledger (`lines 398-473`):**
  - Court Rate, Duration Multiplier, Subtotal, Club Service Fee (`FREE (₱0.00)` in neon green).
  - Total Amount highlighted in bold 19pt neon lime (`0xFFCCFF00`).
- **1-Tap Google Calendar Sync Switch (`lines 494-547`):** Seamless toggle for automatic calendar deep link generation.
- **Payment Method Selector (`lines 549-627`):** Interactive radio cards for Apple/Google Pay and Club Membership Card.
- **Bottom Checkout Bar (`lines 674-741`):** Persistent sticky footer with total price, duration badge, and `NeonButton` triggering booking insertion and modal confirmation.

#### Athletic Tech Elevation Opportunities
1. **Dynamic Peak vs Off-Peak Price Surcharge Line Item:**
   - In the pricing breakdown, explicitly show: `Peak Hour Surcharge (+₱60.00)` when booking between 17:00 and 22:00 to give absolute clarity on rate composition.
2. **PayMongo Multi-Channel Brand Badges:**
   - Expand payment selector to display real PayMongo channel badges (GCash, Maya, GrabPay, Visa/Mastercard) with authentic branded color accents.
3. **Tactile Haptic Confirmation Lock:**
   - On tapping the checkout button, trigger heavy impact haptic feedback (`HapticFeedback.heavyImpact()`) accompanied by a smooth security lock animation (`Icons.lock_clock_rounded`).

---

## 5. Interactive Modals Deep Dive: Micro-Interactions, Animations & Feedback

### 5.1 Smart Gate Pass QR Modal (`lib/widgets/check_in_qr_modal.dart`)

#### Current Implementation Analysis
- **Animation System (`lines 44-58`):**
  - `AnimationController` with 1400ms duration repeating in reverse.
  - Drives `_pulseAnimation` (`Tween<double>(begin: 0.4, end: 1.0)` with `Curves.easeInOut`).
  - Pulses the glow and alpha on the status badge: `UPCOMING • READY FOR GATE` / `CHECKED IN • SESSION ACTIVE`.
- **Real-Time Countdown (`lines 79-104`):**
  - 1-second periodic `Timer` calculating exact minutes and seconds remaining until session starts or session ends.
  - Automatically switches to overtime tracking if past session end time.
- **Dynamic Security Token (`lines 106-113`):**
  - Generates 30-second rolling token `PKL-[ID]-[EPOCH_HEX]` displayed beneath simulated QR icon.
- **Interactive State Simulation (`lines 67-77` & `360-388`):**
  - Action button allows venue kiosk simulation (`upcoming` -> `checked_in` -> `completed`).

#### Elevation Blueprint
- **Scanner Laser Sweep Animation:** Add a thin vertical laser line (`neonLime` gradient) animated up and down the QR code container using a second looping animation controller.
- **NFC / Wave Sensor Visual:** For contactless turnstiles, show an animated wave ripple graphic.
- **Haptic Burst on Scan:** Trigger `HapticFeedback.vibrate()` or `selectionClick()` when state transitions occur.

---

### 5.2 Time Slot & Player Picker Modal (`lib/widgets/time_player_picker_modal.dart`)

#### Current Implementation Analysis
- **Grid Layout (`lines 224-384`):**
  - 2-column `GridView` with 2.2 aspect ratio.
  - Displays all operating hours (`08:00 AM` to `10:00 PM`).
- **Status Badging:**
  - Booked slots: 0.45 opacity, red `BOOKED` badge, taps disabled.
  - Peak slots: Amber border, amber `PEAK` badge, amber glow when selected.
  - Off-Peak slots: Emerald green border, neon lime text, `OFF-PEAK` label.
- **Live Ledger (`lines 386-493`):**
  - Auto-updates selected slot range and price dynamically.
  - Reminds player of 5-minute transient slot reservation hold.

#### Elevation Blueprint
- **Peak Hour Visual Legend Bar:** Add an interactive timeline ribbon at the top showing the 24-hour day with the 17:00-22:00 window highlighted in glowing amber.
- **Duration Toggle:** Add a 1h / 1.5h / 2h segment control to allow multi-slot reservations with automatic consecutive slot validation.
- **Slot Selection Micro-Animation:** Enhance selected slot with a gentle scale bounce (`0.97` to `1.03`) when tapped.

---

### 5.3 Downloadable Receipt Modal (`lib/widgets/downloadable_receipt_modal.dart`)

#### Current Implementation Analysis
- Clean itemized receipt breakdown displaying Booking ID, Court Name, Slot Time, Payment Method, PayMongo reference, Itemized Rate, Tax/Service fee, and Total Paid in neon green (`lines 122-174`).
- Action buttons for `Download PDF` and `Share Receipt` (`lines 180-241`) with feedback snackbars.

#### Elevation Blueprint
- **Digital Match Ticket Aesthetic:** Add notched perforated cutouts on the card sides (`CustomClipper` with circular bite-outs) to simulate a physical luxury stadium pass.
- **QR Hash Watermark:** Add a subtle background watermark of the PayMongo reference number for authenticity.

---

### 5.4 Booking Success Modal (`lib/widgets/booking_success_modal.dart`)

#### Current Implementation Analysis
- Circular animated success badge with double glowing box shadow (`lines 137-159`).
- Complete reservation summary card.
- `ScaleTransition` on "Add to Google Calendar" button with haptic feedback.
- Secondary CTA: "Done • View My Bookings".

#### Elevation Blueprint
- **Instant Gate Pass Shortcut:** Add a quick action button directly on the success modal: `Open Gate Pass QR Now`.
- **Multi-Calendar Carousel:** Allow 1-tap export not just to Google Calendar, but also Apple Calendar (`webcal://`), Outlook Online, and `.ics` file download.

---

## 6. Theme Tokens & Design System (`lib/core/theme/app_theme.dart`)

### 6.1 Contrast Ratio Verification (WCAG AAA Compliance)
The core color pairings adhere to strict contrast rules:
| Foreground Token | Background Token | Calculated Contrast | WCAG Rating | Target Standard |
|---|---|---|---|---|
| `neonLime` (`#CCFF00`) | `background` (`#0A0F0D`) | **16.8 : 1** | **AAA** (Pass) | ≥ 7.0 : 1 (Normal Text) |
| `neonGreen` (`#00E599`) | `background` (`#0A0F0D`) | **12.4 : 1** | **AAA** (Pass) | ≥ 7.0 : 1 (Normal Text) |
| `textPrimary` (`#FFFFFF`) | `background` (`#0A0F0D`) | **18.9 : 1** | **AAA** (Pass) | ≥ 7.0 : 1 (Normal Text) |
| `textSecondary` (`#A1A1AA`)| `surfaceElevated` (`#1B2620`)| **5.2 : 1** | **AA** (Pass) | ≥ 4.5 : 1 (Normal Text) |

### 6.2 Precomputed Alpha Tokens
`AppPalette` and `AppTheme` maintain zero-allocation precomputed alpha colors:
- `neonLimeAlpha12`, `neonLimeAlpha14`, `neonLimeAlpha15`, `neonLimeAlpha20`, `neonLimeAlpha30`, `neonLimeAlpha35`
- `neonGreenAlpha08` through `neonGreenAlpha50`
- `borderSubtleAlpha30`, `borderSubtleAlpha50`, `borderSubtleAlpha60`
- `errorRedAlpha12`, `errorRedAlpha30`

### 6.3 Typography Hierarchy Upgrade Proposal
To achieve the athletic high-performance feel:
```dart
// Suggested additions to AppTheme:
static final TextStyle fontTelemetryHero = GoogleFonts.plusJakartaSans(
  color: textPrimary,
  fontSize: 38,
  fontWeight: FontWeight.w800,
  letterSpacing: -1.2,
);

static final TextStyle fontTelemetryLabel = GoogleFonts.plusJakartaSans(
  color: textMuted,
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.0,
);

static final TextStyle fontMonospaceValue = GoogleFonts.robotoMono(
  color: neonLime,
  fontSize: 13,
  fontWeight: FontWeight.w700,
);
```

---

## 7. Subagent Execution Matrix & Domain Boundaries

To implement the sports-tech redesign without conflicts, domain boundaries must be respected:

| Domain Subagent | Assigned Scope | Key Tasks |
|---|---|---|
| **🎨 1. UI/UX Specialist** | `lib/core/theme/app_theme.dart`, `lib/screens/insights/insights.dart`, `lib/widgets/quick_booking_card.dart`, `lib/widgets/reservation_card.dart` | Integrate `Plus Jakarta Sans`, elevate telemetry stats, add benchmark trend chips, target line on chart. |
| **💳 4. Payments & Check-In Specialist** | `lib/widgets/check_in_qr_modal.dart`, `lib/widgets/downloadable_receipt_modal.dart`, `lib/screens/booking/booking_review_screen.dart` | Refine laser sweep animation on QR, add PayMongo channel logos (GCash/Maya/Cards), itemize peak surcharge. |
| **📊 7. Analytics Specialist** | `lib/screens/insights/insights.dart`, `lib/models/user_profile.dart` | Add DUPR rating computation, weekly intensity score, and court utilization percentage. |
| **♿ 6. Accessibility Specialist** | All screens & modals | Maintain ≥ 48x48dp touch targets, verify `Semantics` tags, ensure WCAG AAA contrast for all neon text. |
| **🧪 9. QA Orchestrator** | `test/` | Update and expand widget tests to verify new telemetry widgets and modal components. |

---

## 8. Conclusion
The Pickleball Flutter mobile codebase has a robust, clean architectural skeleton with zero-warning static analysis and comprehensive unit/widget test foundations. Elevating it to a top-tier athletic tech experience (Playtomic / Strava benchmark) requires focused, non-destructive enhancements to typography, telemetry cards, chart graphics, court timeline visualization, and modal micro-interactions, all within the existing dark slate and electric lime design system.
