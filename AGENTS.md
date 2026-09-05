# AGENTS.md - Pickleball Flutter App

## Project Overview
Flutter 3.x / Dart 3.x mobile app with Supabase Auth + Postgres backend. Dark-themed sports-tech UI. Offline-first with mock data fallback when Supabase not configured.

## Key Commands
```powershell
# Full quality gate (run before PR/commit)
.\scripts\verify.ps1

# Individual steps
flutter pub get
dart analyze --fatal-infos    # 0 warnings/errors required
flutter test                  # 146 tests must pass
```

## Architecture Notes
- **Entry**: `lib/main.dart` → `AuthGate` → `MainNavigationScreen` (5 tabs)
- **State**: `ThemeService` (ChangeNotifier) for theme; services use async/await
- **Data**: `BookingService`/`AuthService` auto-fall back to `MockData` if Supabase unconfigured
- **Env**: Load `.env` via `flutter_dotenv`; copy `.env.example` → `.env` for Supabase/PayMongo keys

## Testing
- **Location**: `test/` (7 suites: validators, calendar, security, features, config, widget smoke, core utils)
- **Run single**: `flutter test test/validators_test.dart`
- **Coverage**: 146 tests, must pass 100%
- **Fixtures**: None; mock data in `lib/data/mock_data.dart`

## Conventions (Non-Default)
- **Validators**: NIST SP 800-63B passwords (8-128 chars, 4 char classes), anchored regex (`^...$`) for injection prevention
- **Theme**: Electric Lime `#CCFF00` on Dark Slate `#0A0F0D` (16.8:1 WCAG AAA); `PlusJakartaSans` display, `Inter` body
- **Performance**: `MediaQuery.sizeOf/paddingOf` over `MediaQuery.of`; `RepaintBoundary` on heavy widgets; `const` constructors
- **Disposal**: All `Timer`/`AnimationController`/`StreamSubscription` disposed in `State.dispose()`
- **A11y**: 48×48dp touch targets; semantic labels on modals/buttons

## Folder Structure
```
lib/
├── core/           # Theme, constants, validators, snackbar helper
├── data/           # MockData (offline fallback)
├── models/         # Court, Booking, Venue, UserProfile
├── screens/        # Feature screens (auth/, booking/, home/, insights/, profile/)
├── services/       # Supabase API, Auth, CalendarLinkService
├── widgets/        # Reusable: modals, cards, nav bar, form fields
└── main.dart       # Bootstrap, Supabase init, AuthGate
```

## CI/CD
- GitHub Actions in `.github/workflows/` (matrix: analyze, test)
- Quality gate: `dart analyze --fatal-infos` + `flutter test`

## Gotchas
- App runs fully offline without `.env` (mock data only)
- PayMongo keys only needed for real checkout testing
- Windows dev: `scripts/verify.ps1` expects Flutter at `C:\flutter\bin` or in PATH
- No code generation (build_runner, freezed, etc.) — plain Dart