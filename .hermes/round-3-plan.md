# Round 3 plan

## Classification

- **F1**: REGRESSION — The reviewer claims `.hermes/round-2-plan.md` is still in the diff, but `git status` shows it was deleted (`deleted: .hermes/round-2-plan.md`) and was removed in R2 commit. This was a fix applied in round 2. **Not an issue anymore** — skip.

- **F2**: MUST_FIX — Comment noise in `lib/core/utils/string_utils.dart:22`. The comments at lines 20-22 ("Boundary validation", "Return unchanged if input is already short enough", "Calculate how many characters...") restate obvious code behavior. **Plan**: Remove these three comment lines. Est lines: 0 added, 3 removed.

- **F3**: MUST_FIX — The negative `maxLength` validation and test were added by this PR (in R2), not in the approved plan. The approved plan did not include this validation. **Plan**: Remove the negative validation from `truncateMiddle` and remove the corresponding test. Est lines: -20 (remove validation + test).

- **F4**: REVIEWER_ERROR — The reviewer claims the implementation uses code-unit truncation that can split emoji mid-character, but the current code (from R2) uses `characters` package correctly: `input.characters.length`, `input.characters.take()`, `input.characters.skip()`. This was fixed in R2. The reviewer's claim doesn't match reality — skip and rebut in PR comment.

- **F5**: REGRESSION — Same as F1: `.hermes/round-2-plan.md` was removed in R2 and is not in the diff anymore. Not an issue.

- **F6**: REVIEWER_ERROR — Same as F4. The reviewer flags Unicode handling as broken but it was fixed in R2 with the characters package. The current implementation is correct.

- **F7**: REGRESSION — Same as F1/F5: `.hermes/round-2-plan.md` is listed but it was deleted in R2. Not an issue.

## Budget check

Total est lines: 0 added, 23 removed (3 comment lines + 20 validation/test lines)
Files touched: 2 files (string_utils.dart, string_utils_test.dart)
Within R3 budget? YES — this is a net reduction, well under 20 lines.

## Verification commands to run after fix

- `flutter test test/core/utils/string_utils_test.dart`
- `dart analyze lib/core/utils/string_utils.dart`
- `git diff --stat origin/main...HEAD` (to confirm budget compliance)
