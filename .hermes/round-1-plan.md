# Round 1 plan

## Classification

- F1: MUST_FIX — Remove 9 extraneous files (6 issue templates, formatters changes, formatters test, PR template modification) that are outside the expected file set. Only `margin_calculator.dart` and `margin_calculator_test.dart` should remain in the diff. → file(s): all 9 extraneous, est lines: -1000+ (deletions only)

## Budget check

- Total est lines: 0 added, ~1040 deleted (pure removal)
- Files touched: 9 (all extraneous files being reverted/deleted)
- Within R1 budget? YES (deletions only, no new code)

## Verification commands to run after fix

- `git diff --stat origin/develop...HEAD` — should show only 2 files
- `flutter analyze` — no new warnings
