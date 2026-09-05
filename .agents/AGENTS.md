# Pickleball Flutter Application Agent Guide

This document provides the operational protocols, architectural rules, safety boundaries, and detailed folder-by-folder contexts for AI assistants and autonomous multi-agent systems working on the **Pickleball** repository (`cultureshock5D/Pickleball`).

The files `referenceonly/layout.tsx` and `referenceonly/Project.sql` are strictly for reference only.

---

## 1. Project Overview & Tech Stack

* **Repository:** `cultureshock5D/Pickleball`
* **Application:** Luxury Dark-Themed Pickleball Court Reservation & Club Management Mobile App
* **Tech Stack:**
  * **Frontend / Framework:** Flutter (Dart 3, null-safety)
  * **Backend / Database:** Supabase (Postgres, Supabase Auth, Realtime Channels, Edge Functions)
  * **Payments & Integrations:** PayMongo (GCash, Maya, GrabPay, Cards), Dynamic Calendar Deep Links (Google, Apple, Outlook, iCal)
  * **Typography & Design:** Google Fonts (`Inter`, `Plus Jakarta Sans`), Luxury Dark Theme with Electric Lime (`#CCFF00`) neon accents and dark slate backgrounds (`#0A0F0D`, `#121A16`, `#1B2620`).

---

## 2. Safety & File Modification Constraints (MANDATORY)

### Directory Protection & Non-Destructive Operations
* **Strict Workspace Containment:** NEVER create, edit, overwrite, or delete files outside the project root directory (`C:\Users\koi\Documents\repositories\Pickleball`).
* **Zero External Destruction:** NEVER execute destructive shell commands (`del`, `rmdir`, `rm -rf`, `Remove-Item`) on parent, sibling, system, or home directories (`C:\`, `C:\flutter`, `C:\Users\koi`, `~`). External SDKs are strictly READ-ONLY.
* **Zero Whole-Folder Operations:** NEVER execute destructive shell commands (`rm -rf`, `rmdir`, `del /s /q`) on workspace root folders or core directories (`lib/`, `test/`, `android/`, `ios/`, etc.).
* **Targeted File Updates Only:** Never replace entire directories or broad modules to make single-feature additions. Modify or create target files explicitly one at a time.
* **Incremental Merging:** When integrating features into existing screens or widgets (e.g., adding calendar deep links into `MyBookingsScreen` or `BookingConfirmationDialog`), append or refactor only the relevant widget sub-tree. Preserve all existing business logic, styles, and imports.
* **Immutability Boundaries:**
  * Files in `referenceonly/` (e.g., `layout.tsx`, `Project.sql`) are strictly **reference only** — do not delete or modify unless explicitly instructed.
  * Do **NOT** run destructive git commands (`git reset --hard`, `git clean -f`).

---

## 3. Comprehensive Folder-by-Folder Context

```
Pickleball/
├── .agents/               # Agent configuration, guidelines, and skills
├── android/               # Android native configuration and Gradle files
├── assets/                # Asset manifests, images, and .env configuration
├── ios/                   # iOS Xcode workspace and Runner configuration
├── lib/                   # Main Flutter application source code
│   ├── core/              # Core foundational infrastructure (constants, theme, services, utils)
│   ├── data/              # Static data sources and offline mock datasets
│   ├── models/            # Data models and JSON serialization/deserialization
│   ├── screens/           # UI Page Screens grouped by domain feature
│   │   ├── auth/          # Authentication (Login, Signup, Forgot Password)
│   │   ├── booking/       # Court reservation and booking review flow
│   │   ├── home/          # Main root navigation shell and home tab
│   │   ├── insights/      # Analytics, play stats, and player progress
│   │   └── profile/       # User profile, preferences, and theme toggle
│   ├── services/          # Business logic, Supabase API client, and external services
│   ├── widgets/           # Reusable UI components, cards, modals, and buttons
│   └── main.dart          # Application bootstrap and root entry point
├── referenceonly/         # Reference UI mocks and Postgres SQL schemas
├── test/                  # Unit, widget, and feature test suites
└── web/                   # Web platform runner and HTML entry points
```

---

### Detailed Folder Responsibilities

#### `lib/` (Root App Logic)
* **`lib/main.dart`**: The app entrypoint. Initializes `.env` via `flutter_dotenv`, system orientations, Supabase client initialization (with safe offline fallback), system navigation bar styling, and launches `AuthGate` within `MaterialApp`.

#### `lib/core/` (Foundational Infrastructure)
* **`lib/core/constants/`**:
  * `supabase_config.dart`: Manages Supabase URL and anon key resolution from `.env` variables (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) with fallback validation.
* **`lib/core/services/`**:
  * `theme_service.dart`: Singleton `ChangeNotifier` controlling `ThemeMode` (dark, light, system) across the app.
* **`lib/core/theme/`**:
  * `app_theme.dart`: Central design system defining color palettes (Electric Lime `#CCFF00`, Dark Slate `#0A0F0D`, Emerald `#00E599`), typography (`GoogleFonts.inter`, `GoogleFonts.plusJakartaSans`), custom input decorations, card themes, and button styles.
* **`lib/core/utils/`**:
  * `snackbar_helper.dart`: Unified feedback system providing styled success, warning, error, and info snackbars.
  * `validators.dart`: Robust validation suite for email, password strength, full name formatting, phone numbers, and booking time intervals.

#### `lib/data/` (Data Sources & Mock Fallbacks)
* **`lib/data/mock_data.dart`**: Comprehensive mock database containing sample venues, court listings, mock reservations, and user stats. Used when running offline, in test mode, or when Supabase credentials are not configured.

#### `lib/models/` (Domain Entities)
* **`lib/models/court_model.dart`**: Court entity (`CourtModel`) holding court ID, venue ID, court number, surface type (indoor/outdoor/cushioned acrylic), hourly rates (standard vs. peak), and available amenities.
* **`lib/models/booking_model.dart`**: Reservation entity (`BookingModel`) capturing booking ID, court ID, user ID, start/end timestamps, total amount (PHP), status (`confirmed`, `pending`, `cancelled`), and payment reference.
* **`lib/models/user_profile.dart`**: User profile representation (`UserProfile`) with skill rating (DUPR), membership tier, match count, avatar URL, and contact details.
* **`lib/models/venue_model.dart`**: Club/venue entity (`VenueModel`) representing physical locations, addresses, court counts, and operating hours.

#### `lib/screens/` (UI Feature Screens)
* **`lib/screens/auth/`**:
  * `login_screen.dart`: Authentication screen supporting email/password login, biometric trigger, validation, and navigation to signup.
  * `signup_screen.dart`: Account registration screen with real-time password strength indicators, full name validation, and skill level picker.
* **`lib/screens/booking/`**:
  * `court_reservation.dart`: Interactive court selection screen with venue selector, date/time slot browser, and court filtering.
  * `booking_review_screen.dart`: Checkout overview screen detailing pricing breakdown (base + peak surcharge + tax), payment method selection (PayMongo GCash/Maya/Cards), and booking confirmation trigger.
* **`lib/screens/home/`**:
  * `main_navigation_screen.dart`: Root scaffold containing the persistent floating `CustomBottomNavBar` and index switching between Home, Courts, Bookings, Insights, and Profile.
* **`lib/screens/insights/`**:
  * `insights.dart`: Performance analytics dashboard showing court utilization, match statistics, win rates, and weekly activity charts.
* **`lib/screens/profile/`**:
  * `profile_screen.dart`: Player profile overview, membership perks, dark/light theme switcher, past booking history link, and account sign-out.

#### `lib/services/` (Data Access & Integrations)
* **`lib/services/auth_service.dart`**: Encapsulates Supabase Auth operations (`signUp`, `signInWithPassword`, `signOut`, `currentUser`, and `authStateChanges` streams).
* **`lib/services/booking_service.dart`**: Orchestrates court availability checks, booking insertions, cancellation mutations, and Supabase Realtime channel event listeners.
* **`lib/services/calendar_link_service.dart`**: Generates RFC 5545 compliant calendar export links and deep URLs for Google Calendar, Apple Calendar, Outlook, and downloadable `.ics` files.

#### `lib/widgets/` (Reusable Components & Modals)
* **`auth_gate.dart`**: Reactive auth state wrapper directing authenticated users to `MainNavigationScreen` and unauthenticated users to `LoginScreen`.
* **`neon_button.dart`**: Primary brand button featuring electric lime gradient, high-contrast typography, and loading spinner states.
* **`custom_text_field.dart`**: Themed text form field with prefix/suffix icons, obscure text toggles, and validation styling.
* **`custom_top_app_bar.dart`**: Standardized luxury top app bar with notification bell and profile triggers.
* **`custom_bottom_nav_bar.dart`**: Floating glassmorphic bottom navigation bar with active glow indicators.
* **`quick_booking_card.dart`**: Quick-action card for favorite and recently booked courts.
* **`reservation_card.dart`**: Interactive card displaying active/past bookings with QR check-in and calendar triggers.
* **`time_player_picker_modal.dart`**: Interactive time-slot grid and player count selector modal.
* **`date_range_picker_modal.dart`**: Themed bottom sheet for date range selection.
* **`venue_picker_modal.dart`**: Searchable modal for selecting club locations.
* **`check_in_qr_modal.dart`**: Dynamic high-contrast QR code display with live countdown timer for court kiosk entry.
* **`booking_success_modal.dart`**: Post-checkout confirmation modal with calendar sync and receipt download buttons.
* **`downloadable_receipt_modal.dart`**: Itemized transaction receipt modal with PDF/image sharing options.

#### `test/` (Automated Verification)
* **`test/calendar_link_service_test.dart`**: Unit tests verifying calendar deep links (Google, Apple, Outlook format and encoding).
* **`test/validators_test.dart` & `test/core/utils/validators_test.dart`**: Comprehensive unit tests covering all form and booking validator permutations.
* **`test/supabase_config_test.dart`**: Unit tests for configuration and environment fallback logic.
* **`test/features_test.dart` & `test/widget_test.dart`**: Widget and integration tests verifying UI rendering, interaction, and state flows.

#### `referenceonly/` (Reference Material)
* **`referenceonly/Project.sql`**: Complete Postgres database schema including `profiles`, `venues`, `courts`, `bookings` tables, RLS policies, indexes, and triggers.
* **`referenceonly/layout.tsx`**: UI structure reference mockup for screen composition and styling.

---

## 4. Multi-Agent Collaboration Protocol & Domain Specialization Matrix

To maximize parallelism and prevent merge conflicts or regression, agents operate across 9 distinct domain specializations with strict directory boundaries:

### Expanded Domain Subagents Roster

1. **🎨 UI/UX & Design System Specialist**
   * **Scope:** `lib/screens/`, `lib/widgets/`, `lib/core/theme/app_theme.dart`
   * **Responsibilities:** Screen layouts, micro-animations (`ScaleTransition`), dark theme tokens (`#0A0F0D`, `#CCFF00`, `#121A16`), glassmorphism, responsive viewports.
   * **Rule:** Never alter database schemas or network service layer directly.

2. **🗄️ Supabase & Database Specialist**
   * **Scope:** `lib/services/booking_service.dart`, `lib/models/`, `referenceonly/Project.sql`
   * **Responsibilities:** PostgREST relational queries, RPC joins (`courts(*, venues(name))`), Realtime subscriptions, database RLS policies, offline fallback to `MockData`.
   * **Rule:** Maintain sync with `referenceonly/Project.sql` schema definitions.

3. **🛡️ Security, Auth & NIST Hardening Specialist**
   * **Scope:** `lib/core/utils/validators.dart`, `lib/services/auth_service.dart`, `lib/core/constants/supabase_config.dart`
   * **Responsibilities:** Regex input sanitization (`^...$`), NIST SP 800-63B password bounds (8–128 chars), Trojan Source control character defense, token lifecycle, and session cache invalidation.
   * **Rule:** Zero hardcoded API secrets. Enforce `dotenv` and `--dart-define` resolution.

4. **💳 Payments, Checkout & External Integrations Specialist**
   * **Scope:** `lib/services/calendar_link_service.dart`, `lib/widgets/check_in_qr_modal.dart`, PayMongo integration
   * **Responsibilities:** PayMongo webhook & checkout APIs (GCash, Maya, GrabPay), RFC 5545 calendar deep links (Google, Apple, Outlook, `.ics`), dynamic gate pass QR generation.
   * **Rule:** Isolate payment credentials and validate interval times before link construction.

5. **⚡ Performance & Memory Profiling Specialist**
   * **Scope:** Repository-wide audit (`lib/`)
   * **Responsibilities:** Eliminating unnecessary widget rebuilds, ensuring clean `StreamSubscription` disposals, enforcing `const` constructor allocations, optimizing image asset caching.
   * **Rule:** Measure before and after refactoring using zero-allocation data structures.

6. **♿ Accessibility (A11y) & WCAG Compliance Specialist**
   * **Scope:** `lib/screens/`, `lib/widgets/` (using `flutter_a11y_agent` and `wcag-audit-patterns`)
   * **Responsibilities:** Minimum 48x48dp touch targets, semantic screen reader traits (`Semantics(button: true, label: ...)`), WCAG AAA neon lime (`#CCFF00`) contrast validation (≥ 16:1 on dark background).
   * **Rule:** Never remove visual design aesthetics; wrap existing widgets cleanly.

7. **📊 Analytics, Insights & Player Statistics Specialist**
   * **Scope:** `lib/screens/insights/insights.dart`, `lib/models/user_profile.dart`
   * **Responsibilities:** DUPR rating computation, court utilization metrics, match win/loss rates, historical period horizon filtering (Weekly/Monthly/Yearly).
   * **Rule:** Compute stats defensively without blocking the UI main thread.

8. **🚀 DevOps, GitHub Actions & CI/CD Specialist**
   * **Scope:** `.github/workflows/`, `scripts/`
   * **Responsibilities:** Free GitHub Actions automated CI matrix, PowerShell verification scripts (`scripts/verify.ps1`), pre-commit hooks.
   * **Rule:** Ensure CI runs `dart analyze --fatal-infos` and `flutter test --coverage` on all PRs.

9. **🧪 QA, Automated Testing & Self-Healing Orchestrator**
   * **Scope:** `test/` (Unit, Widget, Feature & A11y tests)
   * **Responsibilities:** Author test fixtures, run `dart analyze` & `flutter test`, read compiler and assertion stack traces, and coordinate surgical auto-repairs across domains until 100% pass.
   * **Rule:** Target only failing lines during repairs without scope creep.

---

### Quality Verification Gates
* **Static Analysis:** `dart analyze` (Must achieve 0 errors, 0 warnings).
* **Automated Test Suite:** `flutter test` (100% passing test assertions).
* **Conventional Commits:** Follow `feat:`, `fix:`, `refactor:`, `test:`, `perf:`, `ci:`.