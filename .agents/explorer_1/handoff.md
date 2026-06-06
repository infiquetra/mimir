# Handoff Report: E2E Test Design for M1 (F1 & F2)

## 1. Observation
- `TEST_INFRA.md` dictates an opaque-box, requirement-driven test philosophy using Category-Partition, Boundary Value Analysis (BVA), Pairwise, and Workload Testing.
- Tier 1 requires ≥5 tests per feature (happy path/boundaries).
- Tier 2 requires ≥5 tests per feature (negative/error/workload).
- Tier 3 requires pairwise coverage of major feature interactions.
- Feature 1 (F1): Automatic discovery/scanning of combat log directory.
- Feature 2 (F2): Parse `Listener: [Name]` for character association.
- `GEMINI.md` mandates integration tests be placed in `integration_test/screens/` and use a `TestApp` wrapper. It also requires testing of AsyncValue handling (loading/error/empty states) and ensuring no UI overflow.
- `original_prompt.md` AC requires the app to correctly handle cases where the log directory does not exist or is empty, and to successfully find and read a mock `.txt` combat log file.

## 2. Logic Chain
- **M1.1 (Tier 1)** focuses on expected behavior and basic boundary conditions. Tests must confirm that the app can find the directory, filter for `.txt` files, extract the `Listener` name, and accurately map the encounters to the currently selected character in Mimir.
- **M1.2 (Tier 2)** focuses on error states, invalid data, and stress testing. Tests must ensure the app does not crash when encountering missing directories, permission issues, zero-byte files, malformed headers, unknown (orphan) characters, or non-UTF-8 encodings. It also includes a workload test for directories with many files.
- **M1.3 (Tier 3)** requires pairwise testing to ensure that interactions between file discovery (F1) and parsing/association (F2) do not produce unexpected behavior. This involves combining directory states (single, multiple files) with log file states (valid, mixed valid/invalid, orphan characters).
- The integration test directory structure must mirror Mimir's feature module structure. The mock fixtures must represent the varying states of log files (valid, missing header, orphan character, invalid encoding) to support the opaque-box test scenarios.

## 3. Caveats
- Since this is an opaque-box design, the specific provider names for the log directory scanner and parser are assumed to follow Mimir conventions (e.g., `combatLogScannerProvider`, `encounterListProvider`), but the test design focuses on UI outcomes via the `TestApp` wrapper.
- The `TestApp` wrapper will need a way to mock the file system directory or the provider that yields the list of files, as integration tests cannot easily manipulate the real macOS file system across all test runners reliably.

## 4. Conclusion
The E2E tests for M1 (Ingestion & Optimization) should be implemented using the following test case matrix and file structure:

### Directory Structure Proposal
```
integration_test/
├── test_utils/
│   ├── fixtures/
│   │   └── combat_log_fixtures.dart       # Mock log strings and file system mocks
├── screens/
│   └── combat_analyzer/
│       ├── ingestion_tier1_test.dart      # M1.1 (F1 & F2 Happy Path)
│       ├── ingestion_tier2_test.dart      # M1.2 (F1 & F2 Error/Edge Cases)
│       └── ingestion_tier3_test.dart      # M1.3 (F1 & F2 Pairwise)
```

### Proposed `combat_log_fixtures.dart` Structure
```dart
class CombatLogFixtures {
  // Valid logs
  static const String validMerlinLog = '''
---------------------------------------------------------------
  Combat Log
  Listener: Jefcox
  Session Started: 2023.10.12 14:00:00
---------------------------------------------------------------
2023.10.12 14:01:00 (combat) 200 from State Protector Merlin - ...''';

  // Invalid / Edge Case logs
  static const String missingListenerLog = '''
---------------------------------------------------------------
  Combat Log
  Session Started: 2023.10.12 14:00:00
---------------------------------------------------------------''';

  static const String malformedListenerLog = '''
---------------------------------------------------------------
  Combat Log
  Listener: 
  Session Started: 2023.10.12 14:00:00
---------------------------------------------------------------''';

  static const String orphanCharacterLog = '''
---------------------------------------------------------------
  Combat Log
  Listener: UnknownAlt
  Session Started: 2023.10.12 14:00:00
---------------------------------------------------------------''';
}
```

### Test Case Matrix

**M1.1: Tier 1 (10 Tests)**
- *F1.1*: Directory exists, contains single valid `.txt` file -> Shows encounter list.
- *F1.2*: Directory exists, contains multiple valid `.txt` files -> Shows all encounters.
- *F1.3*: Directory contains non-txt files (e.g., `.log`, `.png`) -> Ignores them safely.
- *F1.4*: Directory is completely empty -> Shows empty state UI ("No encounters found").
- *F1.5*: Directory contains valid `.txt` inside a subdirectory -> Handled according to requirements (ignored or scanned).
- *F2.1*: Standard `Listener: [Name]` is parsed and matched perfectly.
- *F2.2*: UI correctly filters encounters when the active character is switched.
- *F2.3*: Listener name contains spaces/special characters -> Parsed correctly.
- *F2.4*: Listener name matched case-insensitively with DB character.
- *F2.5*: Single `.txt` file containing multiple `Session Started` headers yields multiple encounters.

**M1.2: Tier 2 (10 Tests)**
- *F1.6*: Log directory does not exist -> Handled gracefully (shows setup/empty state).
- *F1.7*: Log directory lacks read permissions (simulated) -> Shows appropriate error UI.
- *F1.8*: Workload: Directory contains 500+ log files -> UI remains responsive (loading indicator).
- *F1.9*: File is zero-bytes -> Skipped safely without crash.
- *F1.10*: File has corrupted/unreadable attributes -> Skipped safely.
- *F2.6*: Log missing `Listener:` header -> Skipped or flagged as unknown.
- *F2.7*: Log has malformed `Listener:` header (`Listener: `) -> Handled safely.
- *F2.8*: Orphan Log (Listener not in DB) -> Does not show for current active character.
- *F2.9*: Log has non-UTF-8 encoding -> Handled gracefully (parse failsafe).
- *F2.10*: Log is missing `Session Started:` -> Treated as invalid or handled safely.

**M1.3: Tier 3 Pairwise (5 Tests)**
- *PW.1*: Many files + Mixed validity + Match char -> Verifies only valid files for the char are shown.
- *PW.2*: Many files + All valid + Mixed chars -> Verifies cross-character filtering is robust.
- *PW.3*: Single file + Valid header + Orphan char -> Verifies empty state when active char doesn't match.
- *PW.4*: Many files + Missing headers + Active char -> Verifies empty state, no crashes during batch failure.
- *PW.5*: Valid file + Workload (large file size) + Active char -> Verifies parsing large file doesn't block UI.

## 5. Verification Method
1. Inspect the written `integration_test/screens/combat_analyzer/*` files to ensure they implement the exact test matrix above using the `TestApp` wrapper.
2. Run the integration tests with `flutter test integration_test/screens/combat_analyzer/` and confirm all cases pass.
3. Verify that `combat_log_fixtures.dart` contains the mock string formats that represent all variations of the EVE combat log header.
