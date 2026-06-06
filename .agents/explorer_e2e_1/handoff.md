# AI-Driven Battle Analyzer — E2E Test Suite Design

**Core Finding**: The test suite must be structured around a 4-tier model (Unit, Integration, System/Pairwise, E2E/Workload) employing Category-Partition, BVA, Pairwise, and Workload testing methodologies to cover all user requirements (R1-R5) as specified in `original_prompt.md` and `TEST_INFRA.md`.

## 1. Observation
- `original_prompt.md` specifies 5 core requirements (Native Integration, Smart Ingestion/Token Optimization, LLM Processing, Caching, and Analysis Dimensions) and explicitly defines Acceptance Criteria (AC) such as mocking LLM endpoints, unit testing the log scanner, caching to SQLite, and rendering metrics panes.
- `PROJECT.md` identifies module boundaries (`combat_analyzer` feature directory) and data flows (File System -> Parser -> Drift DB <-> LLM -> Riverpod -> UI).
- `TEST_INFRA.md` dictates the test philosophy: "Opaque-box, requirement-driven," using "Category-Partition + BVA + Pairwise + Workload Testing" methodologies across 4 Tiers.
- `GEMINI.md` mandates UI & E2E tests using Patrol, Golden visual tests, and a `TestApp` wrapper for integration testing, with `bug_regression` for historically problematic areas (AsyncValue handling, ID resolution).

## 2. Logic Chain
1. **Category-Partition & BVA (Tiers 1 & 2)**: Core logic (log parsing, token filtering, metrics) needs isolation and boundary coverage to ensure robustness without invoking the LLM or UI.
    - *Log scanner*: Partitions include missing dir, empty dir, valid dir, non-log files. BVA: 0 files, 1 file, 1000 files.
    - *Log parser & Metrics*: Partitions include valid `Listener` header, missing header, combat vs non-combat logs. BVA applied to damage numbers (0, massive) and timestamp intervals (midnight wrap-arounds).
    - *Token Optimization*: Partitions include short log (no filter), large log (truncate/summarize), highly repetitive patterns (drone misses).
2. **Pairwise Testing (Tier 3)**: Since system behavior depends on multiple orthogonal factors (API key state, DB cache state, Log size, Log content), pairwise combinations guarantee interaction coverage without exponential test explosion.
    - Combinations like `[Key Set, Cache Miss, Valid Log]` vs `[Key Not Set, Cache Miss, Valid Log]` ensure proper flow routing (API call vs Prompt for Key).
3. **Workload / E2E Scenarios (Tier 4)**: The user requires the feature to work seamlessly end-to-end. We map the Workload tier to integration tests using Patrol/Flutter driver, exercising the complete application workflow as outlined in `TEST_INFRA.md` (e.g., standard workflow, cache hits, API failures).
4. **Test Architecture Alignment**: All tests must fit into Mimir's existing testing layout (`test/` for unit, `integration_test/screens/` for UI flow, `integration_test/test_utils/mocks/` for mock LLM responses, and `.gemini/visual-validation/checklists/` for Golden tests).

## 3. Caveats
- **Mocking LLM**: Tests rely heavily on mocked LLM responses. The prompt accuracy itself cannot be fully opaque-box tested in CI without a live LLM, so a representative static mock derived from the provided "State Protector Merlin" log is assumed.
- **File System Access**: Testing the log scanner requires a virtual or mocked file system to prevent tests from depending on the host machine's actual EVE log directory.
- **Performance**: We have not defined explicit execution time constraints for token optimization, but it should be noted for potential workload performance testing.

## 4. Conclusion

### Test Suite Design Plan

#### Architecture & Layout Plan
- **Unit Tests (`test/features/combat_analyzer/`)**:
  - `log_scanner_test.dart` (F1)
  - `log_parser_test.dart` (F2, F7)
  - `token_optimizer_test.dart` (F3)
  - `llm_cache_test.dart` (F6)
- **Integration Tests (`integration_test/screens/combat_analyzer/`)**:
  - `combat_analyzer_flow_test.dart` (F4, F5, F8)
  - `cache_behavior_test.dart` (F6)
- **Test Infrastructure (`integration_test/test_utils/`)**:
  - `mocks/mock_llm_service.dart` (Simulates API responses)
  - `mocks/mock_file_system.dart` (Simulates log directories)
  - `fixtures/combat_log_fixtures.dart` (Contains the Merlin fixture & edge cases)
- **Visual Validation**:
  - `combat_analyzer.yaml` checklist for the multi-pane UI (to ensure no overflow and correct metrics rendering).

#### Detailed Test Case Plan

**Tier 1 & 2: Category-Partition & BVA**
1. `test_log_directory_scanning`: Partition into `{not_exists, empty, valid_logs, invalid_files}`. BVA: `count=[0, 1, 999]`.
2. `test_listener_extraction`: Validate extraction against well-formed and malformed log headers.
3. `test_token_optimization`: Validate that logs exceeding $N$ lines are aggressively summarized (e.g., duplicate events grouped) and output length is $\leq$ token limit.
4. `test_metrics_calculation`: Input raw logs, assert calculated total damage dealt and received matches expected bounds.

**Tier 3: Pairwise Combinations**
Variables:
- `API Key`: [Valid, Empty, Invalid]
- `Cache State`: [Hit, Miss]
- `Network`: [Success, Timeout/Failure]
*Test Cases generated (sample)*:
1. `Valid Key` + `Miss` + `Success` -> Expect UI shows success & DB writes cache.
2. `Valid Key` + `Hit` + (Network ignored) -> Expect UI shows success, no LLM API call made.
3. `Empty Key` + `Miss` + (Network ignored) -> Expect UI prompts for API key.
4. `Valid Key` + `Miss` + `Timeout` -> Expect UI shows Error State with Retry button.

**Tier 4: Workload / E2E Scenarios (Patrol/Integration)**
1. **Standard Workflow**: Start at dashboard -> log discovered -> tap encounter -> enter mock API key -> view multi-pane report -> verify metrics pane.
2. **Cache Revisit Workload**: Open previously viewed encounter -> verify instantaneous load (no loading spinner, Riverpod `AsyncValue.data` immediate).
3. **Edge Case Workload**: Empty log directory -> verify "No Encounters Found" empty state.

## 5. Verification Method
- **Implementation Validation**: When implementers create the test files in `test/features/combat_analyzer/` and `integration_test/screens/combat_analyzer/`, their filenames and descriptions must trace back to this report's suite plan.
- **Execution Validation**: Run `flutter test` and `flutter test integration_test/`. The test output must demonstrate execution of all defined partitions, pairwise interactions, and E2E scenarios. Test coverage for the `combat_analyzer` module must exceed the 80% minimum set by `GEMINI.md`.
