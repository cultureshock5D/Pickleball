# DISPATCH — Remediation Worker (A11y Touch Targets, Layout Overflows & Semantics Polish)

## Date: 2026-09-05T03:05:00Z

## Role
You are the Remediation Worker (teamwork_preview_worker) responsible for surgically applying the 5 layout, touch target, and accessibility fixes identified by Challenger 2.

## Inputs
- `ORIGINAL_REQUEST.md`: C:\Users\koi\Documents\repositories\Pickleball\.agents\ORIGINAL_REQUEST.md
- `PROJECT.md`: C:\Users\koi\Documents\repositories\Pickleball\PROJECT.md
- `AGENTS.md`: C:\Users\koi\Documents\repositories\Pickleball\.agents\AGENTS.md
- `challenger_2/handoff.md`: C:\Users\koi\Documents\repositories\Pickleball\.agents\challenger_2\handoff.md
- `auditor_1/handoff.md`: C:\Users\koi\Documents\repositories\Pickleball\.agents\auditor_1\handoff.md

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Exclusive File Boundaries
You have exclusive write ownership of:
1. `lib/screens/booking/court_reservation.dart`
2. `lib/screens/booking/booking_review_screen.dart`
3. `lib/widgets/custom_bottom_nav_bar.dart`
4. `lib/widgets/downloadable_receipt_modal.dart`
Do NOT edit any files outside this list.

## Required Surgical Fixes

### 1. Fix Mode Tab Touch Target Height (>= 48dp) in `court_reservation.dart`
- Location: lines 423–509 in `_buildModeTab` and `_buildTopModeSwitcher`.
- The current tab hit target collapses to 19dp.
- Remedy: In `_buildTopModeSwitcher`, ensure the container has `height: 52` (or 54), and in `_buildModeTab`, ensure the `InkWell` fills the height with `height: double.infinity` or `constraints: const BoxConstraints(minHeight: 48)`, providing an explicit $\ge 48\times 48$dp hit area. Ensure `Semantics(button: true, label: ...)` wraps the interactive element cleanly.

### 2. Fix Timeline Lane Slot Bottom Overflow in `court_reservation.dart`
- Location: lines 727–827 in `_buildTimelineSlot`.
- The current slot strip is `SizedBox(height: 52)` with `padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5)`. Under 1.0 text scale, the inner `Column` requires ~65dp and overflows by 25px.
- Remedy: Increase the slot strip height to `SizedBox(height: 62)` (or wrap the inner content in `FittedBox` / adjust padding to `EdgeInsets.symmetric(horizontal: 4, vertical: 3)`), ensuring zero `RenderFlex` overflow under default 1.0 text scaling.

### 3. Fix Price Breakdown Row Horizontal Overflow in `booking_review_screen.dart`
- Location: lines 532–548 in `_buildPriceRow`.
- When court name is long (e.g. `'SmashCourt - Center Arena'`), the row overflows by 11px horizontally.
- Remedy: In `_buildPriceRow`, wrap `Text(label, ...)` in `Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, ...))` so long labels truncate gracefully without overflowing the Row.

### 4. Fix Bottom Nav Semantics Stutter in `custom_bottom_nav_bar.dart`
- Location: lines 99–114 in `_buildNavItem`.
- The item is wrapped in `Semantics(button: true, label: item.label)`, but the descendant `Text(item.label)` is also announced, causing VoiceOver/TalkBack to announce `"Home\nHome"`.
- Remedy: Wrap the child `Text(item.label, ...)` in `ExcludeSemantics(child: Text(item.label, ...))` so the parent Semantics node provides the single authoritative announcement.

### 5. Fix Duplicate Action Button Semantics in `downloadable_receipt_modal.dart`
- Location: lines 245–285.
- `OutlinedButton.icon` and `ElevatedButton.icon` already provide button semantics for "Download PDF" and "Share Receipt".
- Remedy: Remove the outer redundant `Semantics(button: true, label: 'Download PDF')` and `Semantics(button: true, label: 'Share Receipt')` wrappers from around these buttons.

## Verification
- Note: No live app is running, so skip DTD and hot reload.
- Run `dart analyze --fatal-infos` (must be 0 issues).
- Run `flutter test test/sports_tech_e2e_test.dart` (must pass 100%).
- Run `flutter test test/features_test.dart` (must pass 100%).
- Run `flutter test` (must pass 161/161 tests, 100%).
- Write `handoff.md` in your working directory and notify the parent orchestrator via `send_message`.

## 2026-09-05T03:03:18Z
You are worker_remediation (teamwork_preview_worker) for the Pickleball Flutter project.
Your working directory is: C:\Users\koi\Documents\repositories\Pickleball\.agents\worker_remediation
The original user request is at: C:\Users\koi\Documents\repositories\Pickleball\.agents\ORIGINAL_REQUEST.md
Your dispatch instructions are at: C:\Users\koi\Documents\repositories\Pickleball\.agents\worker_remediation\DISPATCH.md
Project plan: C:\Users\koi\Documents\repositories\Pickleball\PROJECT.md
Agent guide: C:\Users\koi\Documents\repositories\Pickleball\.agents\AGENTS.md
Challenger 2 handoff: C:\Users\koi\Documents\repositories\Pickleball\.agents\challenger_2\handoff.md

Scope & Tasks:
1. Exclusive write ownership of:
   - `lib/screens/booking/court_reservation.dart`
   - `lib/screens/booking/booking_review_screen.dart`
   - `lib/widgets/custom_bottom_nav_bar.dart`
   - `lib/widgets/downloadable_receipt_modal.dart`
2. Apply the 5 surgical remediations detailed in `DISPATCH.md` and `challenger_2/handoff.md`:
   - Mode tab touch target height >= 48dp in `court_reservation.dart`.
   - Timeline lane slot RenderFlex bottom overflow in `court_reservation.dart` under 1.0 text scaling.
   - Price breakdown row horizontal overflow in `booking_review_screen.dart` on long court names.
   - Bottom nav semantics stutter in `custom_bottom_nav_bar.dart` (wrap text in ExcludeSemantics).
   - Duplicate button semantics in `downloadable_receipt_modal.dart` (remove outer redundant Semantics wrappers).
3. Note: No live app is running, so skip DTD and hot reload.
4. Run `dart analyze --fatal-infos` (0 errors, 0 warnings).
5. Run `flutter test test/sports_tech_e2e_test.dart`, `flutter test test/features_test.dart`, and full `flutter test` (100% passing).
6. Write `handoff.md` in your working directory and notify the parent orchestrator via `send_message`.

