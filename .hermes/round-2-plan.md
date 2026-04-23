# Round 2 plan

## Classification

- **F1**: MUST_FIX — Test at line 40 claims to test maxLength < ellipsis but uses maxLength=2 with default ellipsis (length 1), which doesn't actually test ellipsis truncation. Need to add proper test case. → Files: test/core/utils/string_utils_test.dart, est lines: 10
- **F2**: REVIEWER_ERROR — Test at line 24 `expect(truncateMiddle('abcdef', 0), '')` DOES verify maxLength < ellipsis (0 < 1). Reviewer citation is incorrect. Will not change.
- **F3**: MUST_FIX — Negative maxLength is silently accepted and violates length contract. Need to add check that throws ArgumentError. → Files: lib/core/utils/string_utils.dart, est lines: 8
- **F4**: MUST_FIX — Same as F1, will be fixed when F1 is addressed. No additional lines needed.

## Budget check

- Total est lines: 18
- Files touched: test/core/utils/string_utils_test.dart, lib/core/utils/string_utils.dart
- Within R2 budget? YES (18 < 30)

## Verification commands to run after fix

- `flutter test test/core/utils/string_utils_test.dart`
- `dart analyze lib/core/utils/string_utils.dart test/core/utils/string_utils_test.dart`
