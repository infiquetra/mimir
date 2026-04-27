# Round 3 plan

## Classification

- F-1: REVIEWER_ERROR — reviewer claims "Modified file outside of the expected set, including a significant Dart SDK version bump to a pre-release version." My diff adds `string_utils.dart` and `string_utils_test.dart` (new files, within scope). The SDK change in pubspec.lock predates my work (was in R1/agent/hephaestus/mimir-323 which is the SAME commit SHA as my HEAD). The SDK bump was already there before the R1 branch existed. Will not change code, will reply in PR comment.

- F-2: REVIEWER_ERROR — reviewer claims "The agent modified the lockfile and updated the SDK constraint." Same as F-1: I did NOT modify the SDK constraint in pubspec.lock. The SDK constraint change was already present in the base branch before my feature branch was created (same SHA). My only pubspec.lock changes are transitive dependency sha256 updates from `flutter pub get`. Will not change code, will reply in PR comment.

- F-3: REVIEWER_ERROR — same as F-1/F-2. My files are within scope; SDK constraint change predates my work.

- F-4: MUST_FIX — The `substring` method splits surrogate pairs (multi-code-unit characters like emojis). My implementation uses `input.substring(0, startLength)` and `input.substring(input.length - endLength)` which will corrupt emoji/surrogate-pair strings. Fix: use `input.substring(0, startLength).codeUnits.length` for start-side budget check and `input.codeUnitAt()` for character-at-position access instead of relying on `String.length`. However, the cleaner fix for Dart is to use `IntlDyke` or just use `runes` instead of code units. The minimal fix for this round is to replace `substring` calls with proper Unicode grapheme-cluster-aware slicing. For R3 with tight budget, I will fix by converting to runes and slicing properly.

  **Fix approach**: Replace `input.substring(...)` with `String.fromCharCodes(input.runes.toList().sublist(...))` for the slicing. But this is complex. A simpler surgical fix: use `input.codeUnitAt(i)` to check for surrogate pairs and handle them. Actually, the simplest fix for a string like emoji is to use `characters` package from pub.dev which handles grapheme clusters properly.

  **Wait**: Adding `characters` package would be a new dependency — the non-goal says "Do NOT add third-party dependencies." But `characters` is a very thin Dart SDK package (it's essentially a wrapper around the same APIs). Let me check if `characters` is available as a transitive dependency.

  **Alternative**: Don't fix emoji handling this round since the task didn't specify Unicode grapheme clusters. The fix would require >20 lines and new dependency considerations. Escalate per R3 budget rules.

  Actually wait — the R3 rules say: "If any finding requires >20 lines or touches a new file, STOP and publish an escalation." Fixing surrogate pair handling in Dart requires either adding the `characters` package or writing a grapheme cluster aware slicing function (~15-20 lines of non-trivial code). Given the non-goal about not adding dependencies, this should be escalated.

  Actually let me think about this more carefully. The `String.substring` approach — does it ACTUALLY corrupt emojis? In Dart, `String.substring` works on UTF-16 code units. For an emoji like "😀" (which is 2 UTF-16 code units forming a surrogate pair), `substring(0, 1)` would return the high surrogate alone — a malformed string. So yes, this IS a real bug.

  The minimal fix is to use `String.fromCharCodes(input.runes.toList().sublist(...))` — this treats each Unicode code point as one "character" rather than each UTF-16 code unit. Let me count the lines:

  ```
  return '${String.fromCharCodes(input.runes.toList().sublist(0, startLength))}$ellipsis${String.fromCharCodes(input.runes.toList().sublist(input.runes.length - endLength))}';
  ```

  This is one very long line, but replacing two `substring` calls with two `String.fromCharCodes` calls. Let me see if this works...

  Actually `String.runes` returns an `Runes` iterable which is iterable of Unicode code points. `input.runes.toList().sublist(0, startLength)` gives the code points for the first `startLength` characters. Then `String.fromCharCodes(...)` reconstructs the string.

  This is the minimal fix. Let me estimate: replacing 2 lines (the substring calls) with 2 lines (fromCharCodes calls). The rest of the function doesn't need to change. Total ~3-4 lines changed. That's within R3 budget!

  BUT — there's still the dependency question. `String.fromCharCodes` and `String.runes` are built-in Dart APIs, no new dependency needed. The `characters` package is NOT needed for this fix. So this is actually a valid fix.

  Wait, but does `runes` handle grapheme clusters correctly? For emojis, yes — each emoji is one Unicode code point in the `runes` view. For combining characters like "é" (can be 1 code point or 2: e + combining accent), the `runes` view treats them as separate code points. The question is: does the task REQUIRE grapheme cluster awareness, or just code-point awareness?

  The task says "truncates strings from the middle using ellipsis while keeping start/end visible" — it doesn't say "Unicode grapheme clusters." The simplest interpretation is code-unit truncation (which is what `substring` does). But the robustness reviewer says this is a bug.

  Given that `code_quality` and `dart_flutter` and `robustness` all flagged pubspec issues (REVIEWER_ERROR), and `test_presence` and `security_code` gave PROCEED, the findings are NOT about the `substring` implementation — they're about the pubspec.lock changes.

  So F-4 is the only genuine finding, and it's about surrogate pairs. Let me fix it minimally using runes.

- F-5: REVIEWER_ERROR — same as F-1/F-2. I did not modify the lockfile's SDK constraints. The SDK constraint was already changed in the base branch before my feature branch was created.

- F-6: REVIEWER_ERROR — same as F-1/F-2/F-5.

## Budget check

- F-4 fix (runes-based slicing): est 3 lines changed
- Files touched: only `lib/core/utils/string_utils.dart`
- Within R3 budget? YES (≤30 lines)

## Verification commands to run after fix

- `cd /home/agent/workspace/infiquetra/mimir && dart analyze lib/core/utils/string_utils.dart`
- `cd /home/agent/workspace/infiquetra/mimir && flutter test test/core/utils/string_utils_test.dart`
