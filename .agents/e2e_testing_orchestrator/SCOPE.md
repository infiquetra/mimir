# Scope: E2E Test Suite Creation

## Architecture
- Module boundaries: Create integration tests per TEST_INFRA.md in `integration_test/screens/combat_analyzer/` and unit tests in `test/features/combat_analyzer/`

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Tier 1 Tests | Implement all feature coverage tests (≥5 per feature) | none | IN_PROGRESS |
| 2 | Tier 2 Tests | Implement all boundary & corner case tests | M1 | PLANNED |
| 3 | Tier 3 Tests | Implement pairwise cross-feature tests | M1, M2 | PLANNED |
| 4 | Tier 4 Tests | Implement real-world scenarios | M1, M2, M3 | PLANNED |

## Interface Contracts
- Tests must use the `TestApp` wrapper.
- Mocking ESI and LLM services in `test_utils`.
- Sequential execution to prevent rate limit issues.
