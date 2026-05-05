# Round 2 plan

## Classification

- F1: MUST_FIX — Add `import` of `core/logging/logger.dart` and `Log.d` entry/exit calls to `calculateMargin` and `breakEvenSellPrice` per approved plan. My R1 assessment was wrong: the logger module DOES exist at `lib/core/logging/logger.dart` and is used extensively across the codebase (30+ files). → file(s): `lib/features/market/calculators/margin_calculator.dart`, est lines: ~8

## Budget check

- Total est lines: ~8
- Files touched: 1
- Within R2 budget? YES (≤30 lines)

## Verification commands to run after fix

- `flutter test test/features/market/calculators/margin_calculator_test.dart`
- `dart analyze lib/features/market/calculators/margin_calculator.dart`
