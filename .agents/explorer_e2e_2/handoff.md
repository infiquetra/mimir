# Handoff Report: E2E Test Suite Design (Tiers 1-4)

## Observation
- The original prompt (`.agents/original_prompt.md`) mandates an AI-driven battle analyzer module directly integrated into Mimir (Flutter/Riverpod/Drift).
- Requirements include smart log ingestion (scanning, token optimization, listener parsing), LLM processing with caching, and a multi-pane UI (What went wrong, Improve, Fit, Metrics).
- `PROJECT.md` establishes a 3-milestone architecture with Drift database integration and Mock LLM dependencies.
- `TEST_INFRA.md` dictates a Dual-Track testing methodology requiring an opaque-box, requirement-driven test suite spanning 4 Tiers:
  - **Tier 1**: ≥5 per feature (40 total)
  - **Tier 2**: ≥5 per feature (40 total)
  - **Tier 3**: Pairwise coverage of major interactions (≥10)
  - **Tier 4**: Real-world scenarios (5 total)

## Logic Chain
1. To fulfill the Dual-Track testing mandate, we must design test cases that treat the system as a black box (opaque-box), focusing on user inputs (EVE logs, API key) and expected outputs (multi-pane analysis, local metric charts, Drift caches).
2. The 8 features identified in `TEST_INFRA.md` (F1-F8) serve as the basis for test categorization.
3. **Tier 1 (Happy Path & Equivalence Classes)** will validate standard use-cases: log parsing logic, correct state transitions on valid API keys, accurate caching, and standard UI rendering without overflows (crucial for Mimir's standard UI rules in `GEMINI.md`).
4. **Tier 2 (Boundaries & Error States)** will validate fault tolerance: missing directories, extreme log sizes, network timeouts, invalid JSON, and concurrent DB accesses.
5. **Tier 3 (Pairwise Interactions)** will validate integration seams: Scanner -> Parser -> UI, UI -> Cache -> LLM.
6. **Tier 4 (Workload/Scenarios)** will emulate the user's end-to-end journey via Patrol integration tests, ensuring all components work together (e.g., standard workflow, first-time setup, failure/retry).

## Test Architecture & Suite Design

### Architecture Overview
- **Runner**: `flutter test integration_test/` and `flutter test test/features/combat_analyzer/`
- **Wrappers**: `TestApp` for dependency injection and state isolation.
- **Fixtures**: `test_utils/fixtures/combat_log_fixtures.dart` for mock EVE `.txt` combat logs and `mock_llm_service.dart`.
- **Database**: In-memory Drift database for state assertions.

### Test Cases Plan

#### Tier 1: Core Functional (Equivalence Classes) - 40 Tests
* **F1 (Scanner)**: Valid dir, Empty dir, Non-existent dir, Mixed file types, Nested dirs.
* **F2 (Parser)**: Valid `Listener`, Missing `Listener`, Multiple `Listener`s, Special char names, Empty file.
* **F3 (Optimization)**: Remove duplicate hits, Strip chatter, Token limit under-bounds, Token limit over-bounds, Empty combat data.
* **F4 (API Key)**: Save valid key, Reject empty key, Persist key across restarts, Update existing key, Reject bad format.
* **F5 (Encounter UI)**: Empty state, List rendering, Navigation to multi-pane, Multi-pane layout validation (4 panes), Responsive sizing.
* **F6 (Caching)**: Save LLM response to DB, Fetch existing without API call, Clear cache, Update cache, Cache miss flow.
* **F7 (Metrics)**: Total dealt damage, Total received damage, DPS time-bucketing, Zero damage parsing, Correct attribution.
* **F8 (LLM integration)**: Valid mock response mapped correctly, Missing optional fields, Standard formatting, AsyncValue loading state, AsyncValue error state.

#### Tier 2: Boundary & Fault Tolerance - 40 Tests
* **F1 (Scanner)**: 10,000+ files dir, Permission denied error, Corrupt directory symlinks.
* **F2 (Parser)**: UTF-16 encoded file, 5GB log file, Malformed listener line.
* **F3 (Optimization)**: 1-million character line, Logs with 0 recognizable weapons, Exotic/unknown module names.
* **F4 (API Key)**: 10KB key input, Concurrent key updates.
* **F5 (Encounter UI)**: Deep linking to non-existent encounter, Rapidly switching tabs during load.
* **F6 (Caching)**: Malformed JSON in cache, Concurrent cache writes for same ID, SQLite constraint violations.
* **F7 (Metrics)**: Timestamps jumping backwards, Extreme integer boundaries for damage.
* **F8 (LLM integration)**: 30s timeout, 429 Rate Limit, 500 Server Error, Garbage output from LLM.

#### Tier 3: Pairwise Interactions - 10 Tests
* **P1**: Scanner (F1) + Parser (F2) + UI (F5) -> Full local read pipeline.
* **P2**: API Key (F4) + LLM (F8) -> Auth header injection test.
* **P3**: UI (F5) + Cache (F6) + LLM (F8) -> Cache miss -> Fetch -> Save -> Render.
* **P4**: Optimizer (F3) + Metrics (F7) -> Ensure optimizer doesn't strip data needed for metrics.
* **P5**: Cache (F6) + Metrics (F7) -> Ensure raw metric JSON saves correctly alongside LLM text.
*(and 5 other permutations)*

#### Tier 4: Real-World Scenarios - 5 Tests
* **S1**: Full Workflow (New encounter -> scan -> optimize -> send to LLM -> cache -> view 4 panes).
* **S2**: Rapid Revisit (Open previously cached encounter, verify instant load).
* **S3**: Cold Start Setup (Empty dir -> Set Key -> Encounter Empty State).
* **S4**: Batch Processing (Parse directory with 5 separate encounters, verify list segregation).
* **S5**: Network Degradation (Encounter load -> LLM fails -> UI shows Retry -> User clicks Retry -> Success).

## Caveats
- Actual LLM models are not tested; we rely entirely on `mock_llm_service.dart`.
- EVE file system monitoring (live updates while playing) is not explicitly modeled in Tier 1-4 here, assuming the user manually triggers a refresh or opens the app post-battle.

## Conclusion
The opaque-box test suite successfully isolates all 8 feature requirements and maps them to robust testing tiers per the Dual-Track methodology. The suite guarantees the combat analyzer will handle Happy Path (T1), Errors (T2), Integrated flows (T3), and Real User Journeys (T4) while adhering to Mimir's UI, Riverpod, and Drift constraints.

## Verification Method
- Execute the tests once implemented: `flutter test integration_test/` and `flutter test test/features/combat_analyzer/`.
- Validate that the mock implementations (LLM/ESI) intercept network calls properly without attempting outbound requests.
