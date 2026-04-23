# Round 2 plan

## Classification

- F1: MUST_FIX — Fix whitespace FormatException message to include input verbatim and update test for whitespace-only input → file(s): lib/core/utils/semver.dart, test/core/utils/semver_test.dart, est lines: 5
- F2: MUST_FIX — Ensure components beyond PATCH are ignored and not validated → file(s): lib/core/utils/semver.dart, est lines: 2
- F3: MUST_FIX — Align implementation with approved plan to ignore components beyond patch → file(s): lib/core/utils/semver.dart, est lines: 2
- F4: MUST_FIX — Fix robustness bug where 1.2.3.alpha throws instead of being treated as 1.2.3 → file(s): lib/core/utils/semver.dart, est lines: 2
- F5: MUST_FIX — Fix trailing component validation and whitespace FormatException message → file(s): lib/core/utils/semver.dart, est lines: 5
- F6: MUST_FIX — Strengthen empty/whitespace message assertions in tests to prove verbatim input presence → file(s): test/core/utils/semver_test.dart, est lines: 10

*Note: F2, F3, F4, and F5 are largely the same issue (validating beyond PATCH). I will address them as one structural change to the validation loop.*

## Budget check

- Total est lines: ~25
- Files touched: lib/core/utils/semver.dart, test/core/utils/semver_test.dart
- Within R2 budget? YES

## Verification commands to run after fix

- flutter test test/core/utils/semver_test.dart
- dart analyze lib/core/utils/semver.dart
