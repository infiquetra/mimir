# Scope: Milestone 3.3.1 - F8 Tests

## Architecture
- Module boundaries: Tests for LLM log processing (mocked) and result structure (Feature 8).
- Output: Unit tests in `test/features/combat_analyzer/` and/or integration tests in `integration_test/screens/combat_analyzer/` testing LLM API mock responses, structure of the result, etc.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | F8 Tier 1 | F8 Tier 1 (5 tests) | none | PLANNED |
| 2 | F8 Tier 2 | F8 Tier 2 (5 tests) | none | PLANNED |

## Interface Contracts
- Tests must use the `TestApp` wrapper for integration tests.
- Mocking ESI and LLM services in `test_utils`.
