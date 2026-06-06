# Scope: Milestone 2: State & Storage Tests

## Architecture
- Module boundaries: Create integration tests for F4 (API Key management) and F6 (Local caching) across Tiers 1-4.
- Target paths: `integration_test/screens/combat_analyzer/` and `test/features/combat_analyzer/`
- Mocking ESI and LLM services in `test_utils`.
- All Tiers (1-4) for the assigned features must be created in this milestone.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | F4 Tests | Tier 1 & 2 tests for F4 (API Key management) | none | PLANNED |
| 2 | F6 Tests | Tier 1 & 2 tests for F6 (Local caching) | none | PLANNED |
| 3 | Integration Scenarios | Tier 3 (interactions) & Tier 4 (Scenario 2, Scenario 3, Scenario 5) involving F4 and F6 | M1, M2 | PLANNED |

## Interface Contracts
- Tests must use the `TestApp` wrapper.
