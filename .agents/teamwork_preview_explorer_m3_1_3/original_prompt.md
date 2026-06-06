## 2026-05-20T21:31:04Z
You are an Explorer for the Mimir project (E2E Testing Track), focusing on Milestone M3.1.
Your working directory is: /Users/jefcox/workspace/infiquetra/mimir/.agents/teamwork_preview_explorer_m3_1_3

Scope: Design Tier 1 tests (happy-path, feature coverage) for features F4, F6, and F7, producing at least 5 test cases per feature (15 total).
- F4: Encounter List UI
- F6: Analysis Multi-Pane UI
- F7: Raw Metrics Calculation

Read `TEST_INFRA.md`, `GEMINI.md`, and the `ORIGINAL_REQUEST` embedded in `original_prompt.md`.
The tests should be opaque-box Flutter integration tests using the `TestApp` wrapper.
Because the implementation does not exist yet (we are the testing track), your test cases should define the intended interaction points (e.g., finding buttons by text or specific keys, using standard Flutter widgets) and specify what minimal UI stubs (like an empty `CombatAnalyzerScreen` or similar) will need to be created in `lib/features/combat_analyzer/presentation/` so that the test files can compile.

Deliver a `handoff.md` in your working directory with:
- The design for the 15 test cases (what each test does, inputs, expected outputs, what widgets it interacts with).
- The list of minimal stub files required in `lib/` to make the tests compile.
- Verification method for the test code.
