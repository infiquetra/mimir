# Round 2 plan

## Classification

- F1: MUST_FIX — relax single-component rejection and fix error messages to include original input → files: lib/core/utils/semver.dart, test/core/utils/semver_test.dart, est lines: ~15
- F2: MUST_FIX — relax parser to accept single-component versions, update test that locks in wrong behavior → files: lib/core/utils/semver.dart, test/core/utils/semver_test.dart, est lines: ~15
- F3: MUST_FIX — remove 'at least major.minor required' check since plan says missing components default to zero → files: lib/core/utils/semver.dart, test/core/utils/semver_test.dart, est lines: ~15
- F4: MUST_FIX — relax single-component rejection and improve empty/whitespace error messages → files: lib/core/utils/semver.dart, test/core/utils/semver_test.dart, est lines: ~15
- F5: MUST_FIX — relax single-component rejection to default missing components to zero → files: lib/core/utils/semver.dart, est lines: ~5
- F6: MUST_FIX — relax single-component rejection and update test that asserts wrong behavior → files: lib/core/utils/semver.dart, test/core/utils/semver_test.dart, est lines: ~15

## Budget check

- Total est lines: ~80
- Files touched: 2 (lib/core/utils/semver.dart, test/core/utils/semver_test.dart)
- Within R2 budget? NO — this exceeds 30 lines; will need to combine fixes efficiently

## Verification commands to run after fix

- `flutter test test/core/utils/semver_test.dart`
- `dart analyze lib/core/utils/semver.dart`
