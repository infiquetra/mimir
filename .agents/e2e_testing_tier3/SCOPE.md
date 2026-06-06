# Scope: Tier 3 Tests (Cross-Feature Combinations)

## Architecture
- Methodology: Implement opaque-box test specs for Tier 3 (Pairwise combinations of features).
- Minimum: Pairwise coverage across all 8 features (F1-F8).
- Format: Markdown checklist of test cases in `integration_test/specs/tier3.md`.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 3.1 | Pairwise combinations | Define Tier 3 tests for feature interactions | none | PLANNED |

## Interface Contracts
- Write the tests as clear, step-by-step opaque-box scenarios that combine two or more features.
- Do not write Dart code. Output to `integration_test/specs/tier3.md`.
