# Round 3 plan

## Classification

- **F-1**: MUST_FIX — Remove `import 'package:flutter/foundation.dart'` and replace all 6 `debugPrint(` calls with `print()`. This is a pure-Dart logic calculator; `print()` needs zero imports and is equivalent for console output. → file(s): `lib/features/market/calculators/margin_calculator.dart`, est lines: ~13
- **F-2**: REVIEWER_ERROR — Reviewer claims "project's standard Log utility" exists, but `lib/core/logging/logger.dart` does not exist in the repo (verified via `git ls-files 'lib/core/'` returns empty, and content search for `class Log` and `logger.dart` returns zero results). No Log utility to bypass. Will not change code; will note in PR comment.
- **F-3**: REVIEWER_ERROR — Plan-required file `mimir/core/logging/logger.dart` does not exist in the repo. The fix for F-1 (plain `print()`) addresses the underlying logging concern without depending on a non-existent file. Reviewer's factual premise (that the plan-required file exists and is importable) is incorrect.
- **F-4**: REVIEWER_ERROR — `Log.d` utility does not exist anywhere in the repo. Same root cause as F-2. Reviewer's factual claim about the codebase is incorrect.
- **F-5**: REVIEWER_ERROR — Plan Step 2 cannot be executed because the target file `mimir/core/logging/logger.dart` does not exist. The implementation already handles logging via `print()` (after F-1 fix) which is the correct zero-dependency approach for a pure Dart logic calculator. Reviewer's claim that a "core logger" exists in the repo is factually incorrect.

## Budget check

- Total est lines: ~13 (all from F-1 fix)
- Files touched: `lib/features/market/calculators/margin_calculator.dart`
- Within R3 budget? YES (single finding, ~13 lines, well under 20-line per-finding cap)

## Verification commands to run after fix

- `dart analyze lib/features/market/calculators/margin_calculator.dart` — must show zero issues
- `dart format lib/features/market/calculators/margin_calculator.dart` — must be already-formatted
