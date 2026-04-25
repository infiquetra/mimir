# Round 2 plan

## Classification

- **F1**: MUST_FIX - Add test for maxLength shorter than multi-character ellipsis (truncate ellipsis to maxLength). Tests need to prove ellipsis-only branch when maxLen < ellipsisLen. → file(s): test/core/utils/string_utils_test.dart, est lines: 3-5

- **F2**: MUST_FIX - The implementation deviates from plan. Current code has `if (visibleLength < 2)` but plan said `if (visibleLength <= 0)`. This changes behavior for maxLength=2 from split-budget (1+1) to ellipsis-only. Need to change condition to `<= 0` and update affected tests. → file(s): lib/core/utils/string_utils.dart, test/core/utils/string_utils_test.dart, est lines: 10-15

- **F3**: NITPICK - Unicode handling concern. While valid for emoji, this is out of scope for the current PR which targets ASCII strings. The PROCEED reviewers (code_quality, security_code, dart_flutter) blessed the current implementation. Adding grapheme-aware handling would require new dependencies and significantly expand scope. Skipping per round 2 budget guidance. → skip

- **F4**: MUST_FIX - Same root issue as F1. Need test proving "return ellipsis alone, truncated" behavior when maxLength < ellipsis.length. The existing multi-character ellipsis test uses maxLength=6 which is > ellipsis.length=3. Need test with maxLength < 3. → file(s): test/core/utils/string_utils_test.dart, est lines: 3-5 (same fix as F1)

## Budget check

- Total est lines: ~20 lines
- Files touched: lib/core/utils/string_utils.dart, test/core/utils/string_utils_test.dart
- Within R2 budget? YES (≤30 lines)

## Verification commands to run after fix

- dart analyze lib/core/utils/string_utils.dart test/core/utils/string_utils_test.dart
- flutter test test/core/utils/string_utils_test.dart
