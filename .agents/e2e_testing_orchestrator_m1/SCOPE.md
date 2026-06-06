# Scope: M1 (Ingestion & Optimization Tests)

## Architecture
- Module/package boundaries: Test suites in `test/features/combat_analyzer/` and `integration_test/screens/combat_analyzer/`
- Methodology: Implement opaque-box tests for F1, F2, F3 across Tiers 1-3.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1.1 | F1 Tests | Automatic discovery/scanning of combat log directory | none | PLANNED |
| 1.2 | F2 Tests | Parse `Listener: [Name]` for character association | none | PLANNED |
| 1.3 | F3 Tests | Local token optimization (filtering/summarizing logs) | none | PLANNED |
| 1.4 | M1 Pairwise Tests | Cross-Feature Combinations (Tier 3) for F1, F2, F3 | 1.1, 1.2, 1.3 | PLANNED |

## Interface Contracts
- `TEST_INFRA.md` rules apply. Create at least 5 tests for Tier 1 and 5 for Tier 2 per feature.
- Use `test/` for parsing tests if logic is isolated, otherwise `integration_test/`.
