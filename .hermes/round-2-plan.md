# Round 2 plan

## Classification

- F1: MUST_FIX — The FormatException messages don't consistently include the full bad input string in the human-readable message portion. Need to modify exception messages in `_parseSemVer` function to include the full version string in the message text, not just as the source parameter. → file(s): lib/core/utils/semver.dart, est lines: 6
- F2: REVIEWER_ERROR — The implementation does correctly pass the version string as the second parameter to FormatException (which is the source parameter), but the reviewer claims this isn't sufficient. Will address the actual issue of message clarity rather than what the reviewer misinterpreted.
- F3: MUST_FIX — The malformed-input handling requires that the FormatException messages clearly name the full bad input string, which is currently not happening. Need to adjust the exception messages. → file(s): lib/core/utils/semver.dart, est lines: 6
- F4: MUST_FIX — Similar to other findings, the FormatException messages at lines 56, 72, and 78 do not include the full bad input string in the message text itself, despite passing it as the source parameter. → file(s): lib/core/utils/semver.dart, est lines: 6
- F5: REVIEWER_ERROR — This finding states that AC1 is only partially met, but examining the code shows that the implementation correctly throws FormatExceptions for malformed inputs. The issue is with the message content, not the existence of the exceptions.
- F6: MUST_FIX — Confirms that the FormatException messages do not name the full bad input string in the message text, only pass it as the source parameter. Need to modify the message strings. → file(s): lib/core/utils/semver.dart, est lines: 6
- F7: MUST_FIX — While the tests cover the scenarios, they don't fully verify that the FormatException messages include the full bad input string in the message text itself. However, this finding is about test verification, but our fix is in the implementation, not tests. → file(s): lib/core/utils/semver.dart, est lines: 6

Actually, reviewing more carefully, F1, F3, F4, F6, and F7 are all pointing to the same core issue: the FormatException messages need to include the full bad input string in the message text, not just as the source parameter.

## Budget check

- Total est lines: 6 (only fixing the message content in 3 exception messages)
- Files touched: lib/core/utils/semver.dart
- Within R2 budget? YES

## Verification commands to run after fix

- flutter test test/core/utils/semver_test.dart
- dart analyze lib/core/utils/semver.dart