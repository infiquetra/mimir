# Scope: Milestone 3 - UI & Metrics Tests

## Architecture
- Module boundaries: Integration tests per TEST_INFRA.md in `integration_test/screens/combat_analyzer/` and unit tests in `test/features/combat_analyzer/`
- Target features: F5, F7, F8

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 3.1 | F5 Tests | F5 (Multi-pane UI) Tiers 1-2 & relevant Tier 4 scenarios | none | PLANNED |
| 3.2 | F7 Tests | F7 (Metrics calc) Tiers 1-2 & relevant Tier 4 scenarios | none | PLANNED |
| 3.3 | F8 & Tier 3 Tests | F8 (LLM parsing) Tiers 1-2, Tier 3 (Cross-feature) & remaining Tier 4 scenarios | none | PLANNED |

## Interface Contracts
- Tests must use the `TestApp` wrapper.
- Mocking ESI and LLM services in `test_utils`.
- All Tiers (1-4) for the assigned features must be created across these sub-milestones.
