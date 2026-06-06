# Scope: M3 (UI & Metrics Tests)

## Architecture
- Module/package boundaries: Test suites in `test/features/combat_analyzer/` and `integration_test/screens/combat_analyzer/`
- Methodology: Implement opaque-box tests for F5, F7 across Tiers 1-3.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 3.1 | F5 Tests | Encounter list UI and multi-pane analysis view | none | PLANNED |
| 3.2 | F7 Tests | Local parsing metrics (damage dealt/received over time) | none | PLANNED |
| 3.3 | M3 Pairwise Tests | Cross-Feature Combinations (Tier 3) for F5, F7 | 3.1, 3.2 | PLANNED |

## Interface Contracts
- `TEST_INFRA.md` rules apply. Create at least 5 tests for Tier 1 and 5 for Tier 2 per feature.
- Use `test/` for parsing tests if logic is isolated, otherwise `integration_test/`.
