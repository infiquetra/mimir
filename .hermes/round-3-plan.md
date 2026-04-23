# Round 3 plan

## Classification

- F1: MUST_FIX — Remove out-of-scope planning file `.hermes/round-2-plan.md` → file(s): `.hermes/round-2-plan.md`, est lines: -1
- F2: MUST_FIX — Remove out-of-scope planning file and fix indentation in `test/core/utils/semver_test.dart` → file(s): `.hermes/round-2-plan.md`, `test/core/utils/semver_test.dart`, est lines: -1, 2
- F3: MUST_FIX — Remove out-of-scope planning file `.hermes/round-2-plan.md` → file(s): `.hermes/round-2-plan.md`, est lines: -1
- F4: MUST_FIX — Remove out-of-scope planning file `.hermes/round-2-plan.md` → file(s): `.hermes/round-2-plan.md`, est lines: -1
- F5: MUST_FIX — Remove out-of-scope planning file `.hermes/round-2-plan.md` → file(s): `.hermes/round-2-plan.md`, est lines: -1
- F6: MUST_FIX — Remove out-of-scope planning file `.hermes/round-2-plan.md` → file(s): `.hermes/round-2-plan.md`, est lines: -1
- F7: MUST_FIX — Update the empty-string FormatException test to assert that the message contains exactly the offending input (or a specific descriptive string) instead of just `contains('')` → file(s): `test/core/utils/semver_test.dart`, est lines: 2

## Budget check

- Total est lines: 4 (mostly removals and minor tweaks)
- Files touched: `.hermes/round-2-plan.md`, `test/core/utils/semver_test.dart`
- Within R3 budget? YES

## Verification commands to run after fix

- flutter test test/core/utils/semver_test.dart
- dart analyze lib/core/utils/semver.dart test/core/utils/semver_test.dart
