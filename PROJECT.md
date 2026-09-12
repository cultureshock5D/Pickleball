# Project: Pickleball Lazy Loading & Resilient Data Synchronization Overhaul

## Architecture
- **Backend & Storage**: Supabase Postgres with `btree_gist` extension, GiST exclusion constraints on `court_id` + `tstzrange(start_time, end_time, '[)')` for atomic slot conflict prevention (SQL error code `23P01`), atomic PL/pgSQL RPC `create_booking_hold`, keyset pagination composite indexes `(created_at DESC, id DESC)`, and Supabase Edge Function `paymongo-webhook` (Deno/TypeScript) with Web Crypto HMAC-SHA256 signature verification and idempotent reconciliation.
- **Client Architecture & State Machine**:
  - `PaginationState<T>` 6-state sealed hierarchy (`InitialLoading`, `ContentLoaded`, `FetchingNextChunk`, `InlineChunkError`, `FullScreenError`, `Exhausted`).
  - Clean Repository interface pattern (`BookingRepository`, `VenueRepository`, `CourtRepository`) isolating `MockData` behind `AppDataFlavor` (`mock` vs `supabase`).
  - Network resilience: 8-second clamped timeout, jittered exponential backoff retry policy, and `NetworkConnectivityWatcher` supporting offline drop and auto-resume on reconnection.
- **UI/UX & Image Pipeline**:
  - Dimensional skeleton placeholders with 0 Cumulative Layout Shift (CLS = 0) matching `ReservationCard` (179.4dp, 191.4dp pitch) and `VenueCard` (130.0dp, 140.0dp pitch).
  - Design tokens: Base `#121A16`, Shimmer `#1B2620`, Accent `#CCFF00`.
  - Distinct error presentation: full-screen fallback on initial failure vs non-blocking inline footer retry card on chunk failure.
  - Memory-safe image pipeline (`cached_network_image` with decode bounds `memCacheWidth: 600`, `memCacheHeight: 400`) capping decoded image memory to 960KB (98% reduction) and keeping total heap <150MB across 100+ items.
- **Realtime & Lifecycle**:
  - Fine-grained Realtime memory patching in-place (`indexWhere`, `insert`, `removeAt`, `copyWith`) executing in <50ms without firing full REST re-fetch.
  - Scroll prefetch trigger window: `extentAfter < 500dp` (triggering 2.6–3.6 items before viewport bottom).
  - Lazy tab mounting in `MainNavigationScreen` deferring instantiation until tab focus.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Venues Table & Seed | PostgreSQL table `public.venues` with RLS, Realtime publication, and composite index `(created_at DESC, id DESC)` | M1 | Survey R1 |
| 2 | GiST Exclusion Constraint | Constraint `exclude_overlapping_court_bookings` over `court_id` and `tstzrange(start_time, end_time, '[)')` rejecting simultaneous overlaps with SQL code `23P01` | M1 | Survey R1 |
| 3 | Atomic Hold RPC | PL/pgSQL function `create_booking_hold` lazily purging expired holds, creating slot reservation, and trapping conflict | M1 | Survey R1 |
| 4 | Keyset Pagination Indexes | Composite B-Tree indexes on `venues`, `courts`, and `bookings` on `(created_at DESC, id DESC)` | M1 | Survey R1 |
| 5 | Edge Function Webhook | Deno/TypeScript edge function `paymongo-webhook` with HMAC-SHA256 verification (300s window), service-role client, and idempotency | M1 | Survey R1 |
| 6 | Keyset Models & Service Query | `VenueModel` `createdAt`, `KeysetCursor`, `PageChunk`, and keyset pagination query in `BookingService` | M1 | Survey R1 |
| 7 | 6-State Pagination Machine | Sealed hierarchy (`InitialLoading`, `ContentLoaded`, `FetchingNextChunk`, `InlineChunkError`, `FullScreenError`, `Exhausted`) | M2 | Survey R2 |
| 8 | Repository Abstraction | Abstract `BookingRepository` with keyset methods isolating `MockData` behind `AppDataFlavor` | M2 | Survey R2 |
| 9 | Clamped 8s Timeout & Backoff | Network resilience pipeline with 8s clamped timeout and jittered exponential backoff for transient network errors | M2 | Survey R2 |
| 10 | Connectivity Watcher | Offline pause/resume watcher with stream fake for deterministic testing | M2 | Survey R2 |
| 11 | Dependencies Update | Add `connectivity_plus` and `cached_network_image` to `pubspec.yaml` | M2 | Survey R2 |
| 12 | Exact Dimensional Skeletons | Shimmer skeleton loaders matching `ReservationCard` (179.4dp) and `VenueCard` (130dp) with tokens `#121A16`, `#1B2620`, `#CCFF00` (CLS = 0) | M3 | Survey R3 |
| 13 | Distinct Error Presentation | Full-screen error on initial load failure vs inline footer retry on chunk failure | M3 | Survey R3 |
| 14 | Memory-Safe Image Pipeline | `cached_network_image` decode boundaries `memCacheWidth: 600`, `memCacheHeight: 400` preventing GPU texture bloat (<150MB heap) | M3 | Survey R3 |
| 15 | In-Place Realtime Patching | Patch memory list in-place upon Realtime change event in <50ms without REST roundtrip | M4 | Survey R4 |
| 16 | Prefetch Trigger Window | Scroll listener triggering chunk fetch when `extentAfter < 500dp` (3–5 items before end) | M4 | Survey R4 |
| 17 | Lazy Tab Initialization | Defer background tab widget mounting in `MainNavigationScreen` until focused | M4 | Survey R4 |
| 18 | E2E & Adversarial Hardening | Comprehensive test suite covering Tiers 1–5, 0 duplicates, 23P01 rejection, offline pause/resume, and forensic integrity audit | M5 | Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|--------------|--------|
| M1 | Backend Keyset Pagination, Concurrency & Webhooks | SQL migration (venues table, btree_gist, GiST exclusion constraint, `create_booking_hold` RPC, composite indexes), Supabase Edge Function `paymongo-webhook`, Model & Service keyset query contracts | none | DONE |
| M2 | Pagination Controller & Network Resilience | 6-state pagination state machine, Repository abstraction with `AppDataFlavor`, 8s clamped timeout, jittered backoff, connectivity watcher, pubspec update | M1 contracts | DONE |
| M3 | Zero-CLS Skeleton Loading & Memory-Safe Image Pipeline | Exact dimensional skeleton loaders (`ReservationCard` & `VenueCard`), distinct error UI (full-screen vs inline footer retry), `cached_network_image` with decode boundaries | M2 | IN_PROGRESS |
| M4 | Realtime Cache Coherence & Tab Lifecycle | In-place Realtime list patching (<50ms), prefetch scroll listener (`extentAfter < 500dp`), lazy tab mounting in `MainNavigationScreen` | M2, M3 | PLANNED |
| M5 | E2E Test Suite Pass & Adversarial Coverage Hardening | Dual-track test suite: Tiers 1-4 tests passing, Tier 5 white-box adversarial stress testing, 0 analyze warnings/errors, 100% tests passing, clean audit | M1, M2, M3, M4 | PLANNED |

## Code Layout
- `supabase/migrations/20260912_keyset_concurrency_webhooks.sql`: Database schema, indexes, constraints, RPC.
- `supabase/functions/paymongo-webhook/index.ts`: Supabase Edge Function for webhook processing.
- `lib/core/constants/app_flavor.dart`: Application data flavor definition.
- `lib/core/pagination/`: Keyset cursor, chunk models, 6-state machine, and pagination controller.
- `lib/core/network/`: Clamped timeout, exponential backoff, and network connectivity watcher.
- `lib/data/repositories/`: Abstract repositories and implementations (`MockBookingRepository`, `SupabaseBookingRepository`).
- `lib/widgets/skeletons/`: Dimensional skeletons for reservation and venue cards (`#121A16`, `#1B2620`, `#CCFF00`).
- `lib/widgets/memory_safe_image.dart`: Bounded decode image component (`memCacheWidth: 600`, `memCacheHeight: 400`).
- `lib/screens/booking/court_reservation.dart`: Integrated with pagination controller, in-place realtime patching, and prefetch scroll listener.
- `lib/screens/home/main_navigation_screen.dart`: Lazy tab mounting with state preservation.
- `test/`: Unit, widget, and integration tests verifying all 4 requirements and quality gates.
