# Original User Request

## Initial Request — 2026-09-11T11:13:06Z

You are the Project Orchestrator (teamwork_preview_orchestrator) for the Pickleball Flutter mobile application repository.

Working directory: C:\Users\koi\Documents\repositories\Pickleball\.agents\orchestrator
Workspace root: C:\Users\koi\Documents\repositories\Pickleball
Authoritative user request file: C:\Users\koi\Documents\repositories\Pickleball\.agents\ORIGINAL_REQUEST.md
Sentinel conversation ID: 45ab022c-726a-4c46-b23c-3b6e35d07c95

Task Overview:
Implement production-grade end-to-end integration between the Flutter client, Supabase Postgres backend with Realtime subscriptions, and live PayMongo payment webhook handling.

Requirements:
1. R1. Supabase Realtime Court & Booking Synchronization:
   - Integrate Supabase Realtime channels to broadcast and listen for booking changes (INSERT, UPDATE, DELETE) on the 'bookings' table.
   - Keep court slot availability in CourtReservationScreen synchronized live across multiple client sessions without manual pull-to-refresh.
2. R2. PayMongo Webhook Lifecycle Handling:
   - Establish secure webhook processing for PayMongo checkout events (payment.paid, payment.failed).
   - Validate payloads and transition booking states from 'pending' to 'confirmed' or 'cancelled' in Supabase Postgres.
   - Handle duplicate or replay webhook events idempotently without corrupting reservation status.
3. R3. Reactive UI State & Offline Resilience:
   - Connect Realtime event streams to reservation and booking screens (CourtReservationScreen, MyBookingsScreen).
   - Maintain seamless offline fallback to local MockData when Supabase connectivity is unavailable or unconfigured.
4. R4. Non-Destructive Guardrails & Quality Baseline:
   - Zero file or directory deletions inside or outside the workspace.
   - Strictly preserve reference files in referenceonly/ (layout.tsx, Project.sql).
   - 0 errors and 0 warnings on 'dart analyze --fatal-infos'.
   - 100% passing test assertions ('flutter test'), authoring/updating comprehensive unit, widget, and service tests for all new realtime and webhook logic.

Operational Protocols:
- Maintain your BRIEFING.md and progress.md in your working directory.
- Dispatch tasks to specialized subagents (e.g. Supabase/Database specialist, Payments/Webhook specialist, UI/UX specialist, QA/Test writer, Reviewers/Challengers) following the domain specifications in .agents/AGENTS.md.
- Ensure all quality gates are satisfied before reporting completion.
- When ready, notify the Sentinel (parent) via send_message with a comprehensive completion report so that the independent Victory Audit can proceed.

## Follow-up — 2026-09-12T11:25:16Z

Production-grade Lazy Loading and Resilient Data Synchronization overhaul for Flutter + Supabase pickleball reservation application.

Working directory: `C:\Users\koi\Documents\repositories\Pickleball`
Integrity mode: development

## Requirements

### R1. Backend Keyset Pagination, Concurrency & Webhooks (Backend Architect)
- Keyset cursor pagination over Supabase Postgres `(created_at, id)` for venues, courts, bookings.
- Postgres `tstzrange` GiST exclusion constraints & atomic RPC hold flow (`create_booking_hold`) preventing overlapping slot reservations.
- Idempotent PayMongo webhook reconciliation via Supabase Edge Function with HMAC verification and service-role database sync.

### R2. Pagination Controller & Network Resilience (State & Network Engineer)
- 6-state pagination state machine (`InitialLoading`, `ContentLoaded`, `FetchingNextChunk`, `InlineChunkError`, `FullScreenError`, `Exhausted`).
- Repository interface pattern isolating `MockData` behind environment flavor/config.
- 8-second clamped timeout, jittered exponential backoff retry policy, and `connectivity_plus` offline pause/resume watcher.

### R3. Zero-CLS Skeleton Loading & Memory-Safe Image Pipeline (UI/UX Lead)
- Exact dimensional skeleton loaders (`#121A16` base, `#1B2620` shimmer wave, `#CCFF00` accent) matching `ReservationCard` and venue cards.
- Distinct error presentation: full-screen fallback on initial failure vs. non-blocking inline footer retry on chunk failure.
- `cached_network_image` pipeline with strict decode boundaries (`memCacheWidth: 600`, `memCacheHeight: 400`) preventing GPU texture bloat.

### R4. Realtime Cache Coherence & Tab Lifecycle (Realtime Specialist)
- Fine-grained Supabase Realtime channel patching memory list in-place without triggering full re-fetch.
- Prefetch trigger window: 3–5 items (`extentAfter < 500dp`) before reaching viewport end.
- Lazy tab initialization preventing background tabs from eagerly querying pagination streams until focused.

## Acceptance Criteria

### Verification & Test Gates
- [ ] Keyset pagination query achieves 0 duplicate records across active writes/scrolling.
- [ ] Postgres GiST exclusion constraint rejects simultaneous overlapping booking holds with SQL code 23P01.
- [ ] Pagination state machine handles offline drop mid-scroll and resumes chunk fetch on reconnect.
- [ ] No layout shift (CLS = 0) during transition from skeleton placeholders to rendered cards.
- [ ] Memory footprint remains stable (<150MB heap) across 100+ scrolled items.
- [ ] Supabase Realtime event patches single court/booking item status in <50ms without full list invalidation.
- [ ] `dart analyze --fatal-infos` passes with 0 warnings/errors.
- [ ] 100% of automated tests in `test/` pass.

## Follow-up — 2026-09-12T12:09:43Z

CRITICAL USER INSTRUCTION: Limit concurrent agents to maximum 4 total across orchestrator, workers, and reviewers. Do not spawn more than 4 concurrent agents at any time. Scale down verification squads and worker dispatches to satisfy this hard cap.

## Follow-up — 2026-09-12T12:52:53Z

CRITICAL CONSTRAINT: Hard cap of MAXIMUM 3 CONCURRENT SUBAGENTS total across orchestrator, workers, reviewers, and auditors. Do not exceed 3 concurrent subagents at any time.

Production-grade Lazy Loading and Resilient Data Synchronization overhaul for Flutter + Supabase pickleball reservation application.

Working directory: `C:\Users\koi\Documents\repositories\Pickleball`
Integrity mode: development

## Requirements

### R1. Backend Keyset Pagination, Concurrency & Webhooks (Backend Architect)
- Keyset cursor pagination over Supabase Postgres `(created_at, id)` for venues, courts, bookings.
- Postgres `tstzrange` GiST exclusion constraints & atomic RPC hold flow (`create_booking_hold`) preventing overlapping slot reservations.
- Idempotent PayMongo webhook reconciliation via Supabase Edge Function with HMAC verification and service-role database sync.

### R2. Pagination Controller & Network Resilience (State & Network Engineer)
- 6-state pagination state machine (`InitialLoading`, `ContentLoaded`, `FetchingNextChunk`, `InlineChunkError`, `FullScreenError`, `Exhausted`).
- Repository interface pattern isolating `MockData` behind environment flavor/config.
- 8-second clamped timeout, jittered exponential backoff retry policy, and `connectivity_plus` offline pause/resume watcher.

### R3. Zero-CLS Skeleton Loading & Memory-Safe Image Pipeline (UI/UX Lead)
- Exact dimensional skeleton loaders (`#121A16` base, `#1B2620` shimmer wave, `#CCFF00` accent) matching `ReservationCard` and venue cards.
- Distinct error presentation: full-screen fallback on initial failure vs. non-blocking inline footer retry on chunk failure.
- `cached_network_image` pipeline with strict decode boundaries (`memCacheWidth: 600`, `memCacheHeight: 400`) preventing GPU texture bloat.

### R4. Realtime Cache Coherence & Tab Lifecycle (Realtime Specialist)
- Fine-grained Supabase Realtime channel patching memory list in-place without triggering full re-fetch.
- Prefetch trigger window: 3–5 items (`extentAfter < 500dp`) before reaching viewport end.
- Lazy tab initialization preventing background tabs from eagerly querying pagination streams until focused.

## Acceptance Criteria

### Verification & Test Gates
- [ ] Keyset pagination query achieves 0 duplicate records across active writes/scrolling.
- [ ] Postgres GiST exclusion constraint rejects simultaneous overlapping booking holds with SQL code 23P01.
- [ ] Pagination state machine handles offline drop mid-scroll and resumes chunk fetch on reconnect.
- [ ] No layout shift (CLS = 0) during transition from skeleton placeholders to rendered cards.
- [ ] Memory footprint remains stable (<150MB heap) across 100+ scrolled items.
- [ ] Supabase Realtime event patches single court/booking item status in <50ms without full list invalidation.
- [ ] `dart analyze --fatal-infos` passes with 0 warnings/errors.
- [ ] 100% of automated tests in `test/` pass.

