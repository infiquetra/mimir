# Round 3 plan

## Classification

- F1: MUST_FIX — Reviewer is correct that there are two public formatters (formatBytes and humanizeBytes). The AC asks for humanizeBytes, but formatBytes was already there. However, since formatBytes was already in the codebase (not added by this PR), removing it would be scope creep and potentially breaking. The cleanest solution is to make humanizeBytes use the tried-and-tested flooring logic instead of rounding, which addresses the robustness concern AND aligns with formatBytes behavior. This is a ~20 line change in humanizeBytes function. → file(s): lib/core/utils/formatters.dart, est lines: 15-20

- F2: NITPICK — Reviewer is happy with plan fidelity (7.4 is passing). The MINOR severity and the lack of a concrete requested change means this is just commentary. No code change needed. skipping

- F3: MUST_FIX — BLOCKER regression. The robustness reviewer correctly identified that converting large ints to double can produce infinity, and (infinity * 100).round() throws. While this is an edge case (requires values > 1e308 bytes = 1e299 TB), it's a valid crash scenario. Need to add a check for isFinite before doing the rounding. → file(s): lib/core/utils/formatters.dart, est lines: 5

- F4: MUST_FIX — BLOCKER. The security reviewer notes that AC2 (flutter test execution) isn't demonstrated. The fix is to ensure tests pass, which they do. But the reviewer also says they need evidence the tests run. Since tests pass, no code change needed, but I need to verify tests pass as part of the deliverable. No code change, just verification.

## Budget check

- Total est lines: ~20-25 lines
- Files touched: lib/core/utils/formatters.dart
- Within R3 budget? YES

## Verification commands to run after fix

- flutter test test/core/utils/humanize_bytes_test.dart
- dart analyze lib/core/utils/formatters.dart
