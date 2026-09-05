# Project: Pickleball High-Performance Sports Tech Mobile Application

## Architecture
- **Framework & Client**: Flutter (Dart 3, null-safety) mobile application featuring a high-performance sports tech interface inspired by Playtomic and Strava (stats-forward, telemetry charts, sleek high-contrast cards, fluid fast-booking sheets).
- **Design Foundations**: Dark Slate (`#0A0F0D`, `#121A16`, `#1B2620`), Electric Lime (`#CCFF00`, 16.8:1 contrast WCAG AAA), Emerald (`#00E599`), `Plus Jakarta Sans` display typography for athletic telemetry + `Inter` for crisp body labels.
- **Backend & Database**: Supabase (PostgREST relational queries with RPC joins `courts(*, venues(name))`, bounded 60-slot in-memory cache, and offline `MockData` fallback).
- **Security & Validation**: Anchored regex input sanitization, NIST SP 800-63B password bounds (8–128 chars), Trojan Source defense, and safe `.env`/`--dart-define` credential resolution.
- **Payments & Check-In**: PayMongo multi-channel options (GCash, Maya, GrabPay, Cards), RFC 5545 calendar links (Google, Apple, Outlook, `.ics`), and dynamic 30s rolling QR gate pass with laser sweep animation.
- **Performance & A11y**: `MediaQuery.sizeOf`/`paddingOf` fine-grained subscriptions, `RepaintBoundary` on animated charts & QR passes, >= 48x48dp touch targets, and full `Semantics` screen reader annotations.
- **DevOps & Testing**: GitHub Actions CI matrix (`.github/workflows/ci.yml`), PowerShell verification script (`scripts/verify.ps1`), unit, widget, and feature test suites with 100% assertion pass.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Athletic Typography & Sports Tech Tokens | Integrate `GoogleFonts.plusJakartaSans` display styling for athletic numerals, headers, and badges alongside `#CCFF00` Electric Lime tokens in `app_theme.dart` | M1 | Survey |
| 2 | Telemetry Activity Visuals & DUPR Progression | Add target threshold horizon line, player DUPR progression rating gauge, intensity load chips, and period filtering to `insights.dart` | M1 | Survey |
| 3 | Horizontal Multi-Court Visual Timeline | Implement interactive horizontal court lane visualizer (Court 1, 2, 3 with peak/off-peak heat strips & real-time occupancy) in `court_reservation.dart` | M1 | Survey |
| 4 | High-Contrast Sports Tech Cards | Polish `quick_booking_card.dart` and `reservation_card.dart` with high-contrast stats, action triggers, and tactile micro-interactions | M1 | Survey |
| 5 | Interactive QR Gate Pass with Laser Sweep | Add laser sweep / scan line animation, dynamic 30s rolling token, and `RepaintBoundary` to `check_in_qr_modal.dart` | M2 | Survey |
| 6 | Fluid Fast-Booking Sheet with Peak Ribbon | Add peak hour visual ribbon, smooth slot selection states, and fluid picker feedback to `time_player_picker_modal.dart` | M2 | Survey |
| 7 | Perforated Digital Ticket & PayMongo Flow | Add perforated ticket edges, barcode aesthetics, and PayMongo reference to `downloadable_receipt_modal.dart` and multi-channel selectors in `booking_review_screen.dart` | M2 | Survey |
| 8 | Success Modal & Calendar Deep Links | Polish `booking_success_modal.dart` scale/fade feedback and multi-calendar sync links (Google, Apple, Outlook, `.ics`) | M2 | Survey |
| 9 | Performance & A11y Fine-Grained Polish | Replace remaining `MediaQuery.of` instances with `paddingOf`/`platformBrightnessOf`, ensure `RepaintBoundary`, >=48x48dp targets, and `Semantics` | M2 | Survey |
| 10 | Comprehensive 4-Tier E2E Test Suite | Expand automated unit, widget, and feature tests across Tiers 1-4 covering all sports tech features, modals, payments, and validators | M3 | Survey |
| 11 | Static Analysis & Quality Gate Verification | Execute `dart analyze --fatal-infos` (0 errors, 0 warnings) and `flutter test` (100% pass) with Reviewer, Challenger, and Forensic Auditor gates | M3 | Survey |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Sports Tech UI/UX Redesign & Telemetry | Athletic typography (`Plus Jakarta Sans`), telemetry dashboard with DUPR progression in `insights.dart`, horizontal multi-court timeline in `court_reservation.dart`, high-contrast cards | None | DONE |
| 2 | M2: Interactive Modals, Payments & Performance Polish | Laser sweep QR gate pass (`check_in_qr_modal.dart`), fast-booking sheet (`time_player_picker_modal.dart`), perforated digital ticket (`downloadable_receipt_modal.dart`), PayMongo channels (`booking_review_screen.dart`), `booking_success_modal.dart`, performance `RepaintBoundary` & `MediaQuery` subscriptions | M1 | DONE |
| 3 | M3: E2E Test Suite, Quality Gates & Forensic Audit | 4-Tier test suite expansion in `test/`, static analysis (0 errors/warnings), 100% test pass, 2 Reviewers, 2 Challengers, and Forensic Auditor verification | M1, M2 | IN_PROGRESS |

## Interface Contracts
### `AppTheme` / `AppPalette`
- `background`: `Color(0xFF0A0F0D)` (Dark Slate)
- `surface`: `Color(0xFF121A16)`
- `surfaceElevated`: `Color(0xFF1B2620)`
- `neonLime`: `Color(0xFFCCFF00)` (Electric Lime)
- `neonGreen`: `Color(0xFF00E599)` (Emerald)
- `displayTypography`: `GoogleFonts.plusJakartaSans(...)` for telemetry numbers and section titles
- `bodyTypography`: `GoogleFonts.inter(...)` for body copy, labels, and forms

### `CalendarLinkService`
- `static String buildGoogleCalendarUrl(...)`: Google Calendar web template URL
- `static String buildAppleCalendarUrl(...)`: Apple Calendar web URL format
- `static String buildOutlookCalendarUrl(...)`: Outlook Online deep link URL
- `static String buildIcsCalendarData(...)`: RFC 5545 `.ics` payload
- `static Future<bool> launchCalendarLink(String url)`: URL launcher with fallback

## Code Layout & Write Ownership
- **Milestone 1 Owner**:
  - `lib/core/theme/app_theme.dart`
  - `lib/screens/insights/insights.dart`
  - `lib/screens/booking/court_reservation.dart`
  - `lib/widgets/quick_booking_card.dart`
  - `lib/widgets/reservation_card.dart`
- **Milestone 2 Owner**:
  - `lib/widgets/check_in_qr_modal.dart`
  - `lib/widgets/time_player_picker_modal.dart`
  - `lib/widgets/downloadable_receipt_modal.dart`
  - `lib/widgets/booking_success_modal.dart`
  - `lib/screens/booking/booking_review_screen.dart`
  - `lib/core/services/theme_service.dart`
- **Milestone 3 Owner**:
  - `test/` (Unit, Widget, and Feature tests)
