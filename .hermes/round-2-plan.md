# Round 2 plan

## Classification

- F1: MUST_FIX — Update `_normalizeVersion` to ignore components beyond index 2 and update whitespace error message to include original input verbatim. → file(s): lib/core/utils/semver.dart, test/core/utils/semver_test.dart, est lines: 10
- F2: MUST_FIX — Fix validation logic to ignore trailing components and update test to expect success for `1.2.3.alpha`. → file(s): lib/core/utils/semver.dart, test/core/utils/semver_test.dart, est lines: 5
- F3: MUST_FIX — Correct implementation to match plan (ignore components beyond patch). → file(s): lib/core/utils/semver.dart, est lines: 5
- F4: MUST_FIX — (Same as F1/F2) Ensure `1.2.3.alpha` is treated as `1.2.3`. → file(s): lib/core/utils/semver.dart, est lines: 0 (covered by F1)
- F5: MUST_FIX — (Same as F1/F2) Fix trailing component logic and whitespace message verbatim requirement. → file(s): lib/core/utils/semver.dart, est lines: 0 (covered by F1)
- F6: MUST_FIX — Strengthen test assertions for empty and whitespace-only inputs to strictly require the offending input in the message. → file(s): test/core/utils/semver_test.dart, est lines: 5

## Budget check

- Total est lines: ~25
- Files touched: lib/core/utils/semver.dart, test/core/utils/semver_test.dart
- Within R2 budget? YES

## Verification commands to run after fix

- flutter test test/core/utils/semver_test.dart
- dart analyze lib/core/utils/semver.dart
