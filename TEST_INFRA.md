# E2E Test Infra: Pickleball Lazy Loading & Resilient Data Synchronization

## Test Philosophy
- Opaque-box, requirement-driven testing derived from `ORIGINAL_REQUEST.md` and user requirements.
- Systematic 4-tier testing methodology + Tier 5 adversarial coverage hardening:
  - **Tier 1 - Feature Coverage (>=5 per feature)**: Isolated happy-path tests for each inventoried feature.
  - **Tier 2 - Boundary & Corner Cases (>=5 per feature)**: Boundary values, zero/negative limits, offline drops, timeout boundaries, network jitter, cursor encoding edges.
  - **Tier 3 - Cross-Feature Combinations (Pairwise)**: Interaction between pagination state machine, realtime in-place patches, network reconnection, and tab lifecycle.
  - **Tier 4 - Real-World Application Scenarios**: End-to-end user workflows (e.g., continuous scrolling through 100+ items during active concurrent reservations, reconnecting from airplane mode, switching tabs back and forth).
  - **Tier 5 - Adversarial Coverage Hardening (White-box)**: Stress testing edge conditions, concurrency race conditions, memory heap pressure (<150MB across 100+ items), and sub-50ms latency assertions.

## Feature Inventory Coverage Map
| # | Feature | Requirement | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|-------------|:------:|:------:|:------:|:------:|
| 1 | Venues Table & Seed | R1 | 5 | 5 | ✓ | ✓ |
| 2 | GiST Exclusion Constraint (23P01) | R1 | 5 | 5 | ✓ | ✓ |
| 3 | Atomic Hold RPC (create_booking_hold) | R1 | 5 | 5 | ✓ | ✓ |
| 4 | Keyset Pagination (0 duplicates) | R1 | 5 | 5 | ✓ | ✓ |
| 5 | Edge Function Webhook (HMAC & Idempotency) | R1 | 5 | 5 | ✓ | ✓ |
| 6 | 6-State Pagination State Machine | R2 | 5 | 5 | ✓ | ✓ |
| 7 | Repository Pattern Isolating MockData | R2 | 5 | 5 | ✓ | ✓ |
| 8 | 8s Clamped Timeout & Backoff | R2 | 5 | 5 | ✓ | ✓ |
| 9 | Network Connectivity Watcher | R2 | 5 | 5 | ✓ | ✓ |
| 10 | Exact Dimensional Skeletons (CLS = 0) | R3 | 5 | 5 | ✓ | ✓ |
| 11 | Distinct Error UI (Full-screen vs Inline) | R3 | 5 | 5 | ✓ | ✓ |
| 12 | Memory-Safe Image Pipeline (<150MB heap) | R3 | 5 | 5 | ✓ | ✓ |
| 13 | Realtime In-Place Patching (<50ms) | R4 | 5 | 5 | ✓ | ✓ |
| 14 | Prefetch Scroll Window (extentAfter < 500dp) | R4 | 5 | 5 | ✓ | ✓ |
| 15 | Lazy Tab Initialization | R4 | 5 | 5 | ✓ | ✓ |

## Test Architecture
- Framework: Flutter Test (`flutter_test`), `package:test`.
- Test Suites:
  - `test/pagination_state_machine_test.dart`: 6-state transitions, state isolation, and UI event generation.
  - `test/keyset_pagination_test.dart`: Keyset cursor encoding/decoding, page chunks, 0-duplicate invariant across active writes.
  - `test/network_resilience_test.dart`: 8s timeout clamp, exponential backoff with jitter, offline drop and reconnect resume.
  - `test/dimensional_skeleton_test.dart`: Exact height matching (179.4dp for reservation, 130.0dp for venue), CLS = 0 verification.
  - `test/realtime_cache_patching_test.dart`: In-place mutation of memory lists (<50ms), status updates without full re-fetch.
  - `test/lazy_tab_lifecycle_test.dart`: Deferral of unvisited tabs in `MainNavigationScreen`, verification that queries don't fire eagerly.
  - `test/concurrency_hold_test.dart`: GiST exclusion constraint verification (code `23P01`), atomic hold RPC verification.
  - `test/paymongo_edge_webhook_test.dart`: Webhook HMAC-SHA256 signature verification, 300s freshness window, and idempotent replay suppression.
- Verification Commands:
  - Static Analysis: `dart analyze --fatal-infos` (0 warnings, 0 errors).
  - Test Suite: `flutter test` (100% passing tests).
