# Scope: Milestone 3.3: F8 & Tier 3 Tests

## Architecture
- Module boundaries: Integration tests per TEST_INFRA.md in `integration_test/screens/combat_analyzer/` and unit tests in `test/features/combat_analyzer/`
- Target features: F8 (LLM log processing and result structure) + cross-feature for F5/F7/F8, and Tier 4 scenarios 1, 2, 5.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 3.3.1 | F8 Tests | F8 Tier 1 (5 tests) & F8 Tier 2 (5 tests) | none | PLANNED |
| 3.3.2 | Tier 3 Tests | Tier 3 Cross-feature for F5/F7/F8 (>=10 tests) | none | PLANNED |
| 3.3.3 | Tier 4 Scenarios | Tier 4 Scenarios 1, 2, and 5 (3 tests) | none | PLANNED |

## Interface Contracts
- Tests must use the `TestApp` wrapper.
- Mocking ESI and LLM services in `test_utils`.
