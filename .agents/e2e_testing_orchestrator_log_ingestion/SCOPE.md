# Scope: Log Ingestion Tests (F1, F2, F3)

## Architecture
- Module boundaries: Tests covering F1, F2, and F3 as defined in TEST_INFRA.md.
- Fixtures: Create `integration_test/test_utils/fixtures/combat_log_fixtures.dart`.
- Unit tests: `test/features/combat_analyzer/log_ingestion_test.dart`
- Integration tests: `integration_test/screens/combat_analyzer/log_ingestion_test.dart`

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Infrastructure & F1 | Setup fixtures, implement F1 Tier 1 & 2 tests | none | PLANNED |
| 2 | F2 Tests | Implement F2 (Parsing Listener) Tier 1 & 2 tests | SM1 | IN_PROGRESS |
| 3 | F3 Tests | Implement F3 (Token optimization) Tier 1 & 2 tests | SM1 | IN_PROGRESS |
| 4 | Integration & Tier 3/4 | Implement Tier 3 (Cross-Feature) and Tier 4 (App Scenarios 1 & 3) for F1/F2/F3 | SM1 | IN_PROGRESS |

## Interface Contracts
- Tests must use the `TestApp` wrapper.
- All files must be placed in appropriate test directories.
