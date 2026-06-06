# Scope: M2 (LLM & Caching Tests)

## Architecture
- Module/package boundaries: Test suites in `test/features/combat_analyzer/` and `integration_test/screens/combat_analyzer/`
- Methodology: Implement opaque-box tests for F4, F6, F8 across Tiers 1-3.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 2.1 | F4 Tests | LLM API key input and secure storage | none | IN_PROGRESS |
| 2.2 | F6 Tests | Local caching (Drift) of LLM responses | none | IN_PROGRESS |
| 2.3 | F8 Tests | LLM log processing (mocked) and result structure | none | IN_PROGRESS |
| 2.4 | M2 Pairwise Tests | Cross-Feature Combinations (Tier 3) for F4, F6, F8 | 2.1, 2.2, 2.3 | IN_PROGRESS |

## Interface Contracts
- `TEST_INFRA.md` rules apply. Create at least 5 tests for Tier 1 and 5 for Tier 2 per feature.
- Use `integration_test/specs/` for markdown checklists of test cases.
