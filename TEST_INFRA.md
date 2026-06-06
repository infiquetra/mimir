# E2E Test Infra: AI-Driven Battle Analyzer

## Test Philosophy
- Opaque-box, requirement-driven. No dependency on implementation design.
- Methodology: Category-Partition + BVA + Pairwise + Workload Testing.

## Feature Inventory
| # | Feature | Source (requirement) | Tier 1 | Tier 2 | Tier 3 |
|---|---------|---------------------|:------:|:------:|:------:|
| 1 | Automatic discovery/scanning of combat log directory | ORIGINAL_REQUEST R2 & AC | 5 | 5 | ✓ |
| 2 | Parse `Listener: [Name]` for character association | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ |
| 3 | Local token optimization (filtering/summarizing logs) | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ |
| 4 | LLM API key input and secure storage | ORIGINAL_REQUEST R3 & AC | 5 | 5 | ✓ |
| 5 | Encounter list UI and multi-pane analysis view | ORIGINAL_REQUEST R4 & AC | 5 | 5 | ✓ |
| 6 | Local caching (Drift) of LLM responses | ORIGINAL_REQUEST R4 & AC | 5 | 5 | ✓ |
| 7 | Local parsing metrics (damage dealt/received over time) | ORIGINAL_REQUEST R5 & AC | 5 | 5 | ✓ |
| 8 | LLM log processing (mocked) and result structure | ORIGINAL_REQUEST R3, R5, AC | 5 | 5 | ✓ |

## Test Architecture
- Test runner: `flutter test integration_test/`
- Test case format: Flutter integration tests and unit tests as specified in `GEMINI.md`.
- Directory layout:
  - `integration_test/screens/combat_analyzer/` for UI and flow tests
  - `integration_test/test_utils/fixtures/combat_log_fixtures.dart` for sample logs
  - `test/features/combat_analyzer/` for unit tests required by AC

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Full standard workflow with existing logs | F1, F2, F3, F4, F5, F8 | High |
| 2 | Encounter revisit (cache hit) | F5, F6 | Medium |
| 3 | First-time setup with empty log directory | F1, F4, F5 | Low |
| 4 | Processing multiple diverse encounters | F2, F3, F5, F7, F8 | High |
| 5 | Handling LLM API failure & retry | F4, F5, F6, F8 | Medium |

## Coverage Thresholds
- Tier 1: ≥5 per feature (40 total)
- Tier 2: ≥5 per feature (40 total)
- Tier 3: pairwise coverage of major feature interactions (≥10)
- Tier 4: ≥5 realistic application scenarios (5 total)
