# DISPATCH — worker_m2
Role: Interactive Modals, Payments & Performance Worker
Working Directory: C:\Users\koi\Documents\repositories\Pickleball\.agents\worker_m2

## 2026-09-03T15:14:42Z
You are worker_m2 (Interactive Modals, Payments & Performance Worker).
Your working directory is: C:\Users\koi\Documents\repositories\Pickleball\.agents\worker_m2

You MUST read the original user request at: C:\Users\koi\Documents\repositories\Pickleball\.agents\ORIGINAL_REQUEST.md
Also read:
- C:\Users\koi\Documents\repositories\Pickleball\PROJECT.md
- C:\Users\koi\Documents\repositories\Pickleball\.agents\AGENTS.md
- C:\Users\koi\Documents\repositories\Pickleball\.agents\skills\flutter-expert\SKILL.md
- C:\Users\koi\Documents\repositories\Pickleball\.agents\skills\surgical-patch\SKILL.md
- C:\Users\koi\Documents\repositories\Pickleball\.agent\skills\payment-integration\SKILL.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your Exclusive File Ownership:
- `lib/widgets/check_in_qr_modal.dart`
- `lib/widgets/time_player_picker_modal.dart`
- `lib/widgets/downloadable_receipt_modal.dart`
- `lib/widgets/booking_success_modal.dart`
- `lib/screens/booking/booking_review_screen.dart`
- `lib/core/services/theme_service.dart`

DO NOT modify files outside this list.

Milestone 2 Scope & Implementation Tasks:
1. `lib/widgets/check_in_qr_modal.dart`:
   - Add an animated laser sweep / scan line overlay across the QR code with Electric Lime `#CCFF00` glow.
   - Wrap the animated QR and laser sweep area in a `RepaintBoundary` to optimize GPU repainting during the 1400ms pulse and 1s countdown.
   - Retain dynamic 30-second rolling token `PKL-[ID]-[SEED]`, live countdown timer, and clean timer cancellation.
   - PRESERVE ALL existing text labels and semantics (`'Smart Court Gate QR Pass'`, `'Simulate Gate Scan (Check-In)'`, `'Simulate Gate Exit (Check-Out)'`, etc.) to ensure 100% test compatibility.

2. `lib/widgets/time_player_picker_modal.dart`:
   - Implement fast-booking sheet visual polish: add peak hour visual ribbon/indicator across time slot cards (distinguishing Peak vs Off-Peak rates).
   - Smooth slot selection states with high-contrast borders and fluid picker feedback.
   - Ensure minimum 48x48dp touch targets and `Semantics` annotations.
   - PRESERVE existing text labels (`'Select Match Time Slot'`, `'Court Match Duration'`, etc.).

3. `lib/widgets/downloadable_receipt_modal.dart`:
   - Implement perforated digital ticket styling with ticket notches, receipt barcode aesthetics, and high-contrast dark slate / electric lime accents.
   - Support PayMongo multi-channel reference display (`GCash via PayMongo`, `Maya via PayMongo`, `GrabPay via PayMongo`, `Card via PayMongo`), payment reference, and price breakdown.
   - PRESERVE existing text labels (`'Official Court Reservation Receipt'`, etc.).

4. `lib/widgets/booking_success_modal.dart`:
   - Polish micro-interactions (smooth scale/fade transition, glowing checkmark, tactile feedback).
   - Support multi-calendar deep sync actions (Google, Apple, Outlook, `.ics`).
   - Replace any remaining non-optimal `MediaQuery.of(context)` with `MediaQuery.paddingOf(context)` or `MediaQuery.sizeOf(context)`.

5. `lib/screens/booking/booking_review_screen.dart`:
   - Add multi-channel PayMongo payment selectors: GCash, Maya, GrabPay, Credit/Debit Cards, alongside Club Membership Card.
   - High-contrast pricing breakdown card (base court rate, peak surcharge, club fee, total in Electric Lime).
   - 1-tap auto-sync calendar switch.

6. `lib/core/services/theme_service.dart`:
   - Replace any `MediaQuery.of(context)` with `MediaQuery.platformBrightnessOf(context)` for fine-grained subscriptions.

Verification & Delivery:
- Run `dart analyze --fatal-infos` (must exit 0 with 0 issues and 0 warnings).
- Run `flutter test` (must pass 100% of tests).
- Write your detailed implementation report to: `C:\Users\koi\Documents\repositories\Pickleball\.agents\worker_m2\changes.md`
- Write your self-contained handoff report to: `C:\Users\koi\Documents\repositories\Pickleball\.agents\worker_m2\handoff.md`
- Send a completion message to the orchestrator with verification results.
