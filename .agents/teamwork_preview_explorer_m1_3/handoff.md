# Handoff Report

## Observation
- **Architecture rules**: `PROJECT.md` specifies `lib/features/combat_analyzer/data/` for the log scanner and parser, and `lib/features/combat_analyzer/domain/` for models. Drift DB schema updates are explicitly deferred to M2.
- **Log Location**: EVE Online places logs on macOS in `~/Documents/EVE/logs/Gamelogs/`. This is verified by `SCOPE.md`.
- **Log Structure**: The mock log at `test/features/combat_analyzer/fixtures/merlin_combat_log.txt` contains:
  - Header: `Listener: Test Character`, `Session Started: 2026.05.20 18:30:00`
  - Combat lines: `[ 2026.05.20 18:32:15 ] (combat) 120 to State Protector Merlin - ...` (damage dealt)
  - Combat lines: `[ 2026.05.20 18:32:16 ] (combat) 65 from State Protector Merlin - ...` (damage taken)
  - Other lines: `[ 2026.05.20 18:32:10 ] (combat) State Protector Merlin misses you completely - ...`
- **Token Optimization Rule**: `SCOPE.md` asks to group repeated messages and remove empty lines to save LLM context window space.

## Logic Chain
1. **Model Definition**: We need a `ParsedCombatLog` model in `domain/models/` to hold `characterName`, `startTime`, `endTime`, `metrics`, and `filteredText`. We also need a `CombatMetrics` model holding `totalDamageDealt` and `totalDamageTaken`.
2. **Scanner Implementation**: The `LogScanner` in `data/log_scanner.dart` will use `dart:io` and `Platform.environment['HOME']` to construct the path `~/Documents/EVE/logs/Gamelogs/` and list `.txt` files.
3. **Parser Implementation**: The `CombatLogParser` in `data/combat_log_parser.dart` will read a `File` line by line.
   - It will match `Listener: (.*)` to get the character name.
   - It will match `Session Started: (.*)` for the start time.
   - It will extract timestamps from lines starting with `[ ` to find the last timestamp for `endTime`.
   - It will match `(\d+) to ` and `(\d+) from ` to sum damage metrics.
   - It will strip the `[ TIMESTAMP ] (combat) ` prefix from each line to extract the core event.
   - It will group consecutively identical event strings to save LLM tokens (e.g. "3x State Protector Merlin misses you completely").
   - It will ignore fluff lines (`---------------------------------------------------------------` and empty lines).
4. **Testing**: We have a fixture `merlin_combat_log.txt` to test the parser. The tests should go in `test/features/combat_analyzer/data/combat_log_parser_test.dart`.

## Caveats
- **macOS Sandbox**: Mimir runs with the macOS App Sandbox enabled (`macos/Runner/DebugProfile.entitlements` has `com.apple.security.app-sandbox` set to `true`). Directly reading `~/Documents/EVE/logs/Gamelogs/` using `Platform.environment['HOME']` might fail during execution without the `com.apple.security.files.user-selected.read-only` entitlement and a folder picker fallback. The Worker should implement the direct file system check first, but we may need to add a directory picker UI later if sandbox permissions block access.
- **Log Formatting**: The datetime format in the log `2026.05.20 18:30:00` uses dots. We will need a simple string replacement (`replaceAll('.', '-')`) to parse it with `DateTime.parse()`.

## Conclusion
The implementation of M1 requires creating domain models for the parsed log, a `LogScanner` to discover files in `~/Documents/EVE/logs/Gamelogs/`, and a `CombatLogParser` that parses the file, aggregates metrics, and token-optimizes the text for LLMs. No Drift DB updates are needed yet as they belong to M2.

## Verification Method
Run `flutter test test/features/combat_analyzer/data/combat_log_parser_test.dart` to verify that `CombatLogParser.parse(File('test/features/combat_analyzer/fixtures/merlin_combat_log.txt'))` returns:
   - `characterName == 'Test Character'`
   - `metrics.totalDamageDealt == 525` (120+130+125+150)
   - `metrics.totalDamageTaken == 457` (42+65+70+80+200)
   - `filteredText` excludes empty lines, `---` dividers, and has the timestamp prefix removed.

---

## Step-by-Step Implementation Strategy for Worker

**Step 1: Create Domain Models (`lib/features/combat_analyzer/domain/models/parsed_combat_log.dart`)**
- Create `CombatMetrics` class with `totalDamageTaken` and `totalDamageDealt` (both `int`).
- Create `ParsedCombatLog` class with `characterName` (String), `startTime` (DateTime), `endTime` (DateTime?), `filteredText` (String), and `metrics` (CombatMetrics).

**Step 2: Implement LogScanner (`lib/features/combat_analyzer/data/log_scanner.dart`)**
- Create `LogScanner` class with `Future<List<File>> getCombatLogs()`.
- Use `Platform.environment['HOME']` to build the path `$home/Documents/EVE/logs/Gamelogs`.
- Check if directory exists; if not, return empty list.
- Return all `.txt` files in that directory.
- Add standard Mimir logging (`Log.d('[COMBAT_ANALYZER]', ...)`).

**Step 3: Implement CombatLogParser (`lib/features/combat_analyzer/data/combat_log_parser.dart`)**
- Create `CombatLogParser` class with `Future<ParsedCombatLog> parse(File file)`.
- **Regex Patterns**:
  - Listener: `RegExp(r'^Listener:\s*(.*)')`
  - Session Started: `RegExp(r'^Session Started:\s*(.*)')`
  - Combat Line: `RegExp(r'^\[\s*(.*?)\s*\] \((.*?)\)\s*(.*)')`
  - Damage To: `RegExp(r'^(\d+)\s+to\s+')`
  - Damage From: `RegExp(r'^(\d+)\s+from\s+')`
- **Parsing Logic**:
  - Sum `totalDamageDealt` and `totalDamageTaken`.
  - Extract `startTime` from Session Started. Replace `.` with `-` for `DateTime.parse`.
  - Extract `endTime` from the last combat line timestamp.
- **Token Optimization**:
  - Skip lines containing `---------------------------------------------------------------` and empty lines.
  - Strip the `[ TIME ] (combat) ` prefix to get the raw event text.
  - Keep track of the `previousEventText` and a `count`. If the current event text exactly matches the previous, increment `count`. If it differs, append `count > 1 ? "${count}x $previousEventText" : previousEventText` to the `filteredText` buffer.

**Step 4: Write Unit Tests (`test/features/combat_analyzer/data/combat_log_parser_test.dart`)**
- Test against the existing fixture `test/features/combat_analyzer/fixtures/merlin_combat_log.txt`.
- Assert `characterName`, `totalDamageDealt`, `totalDamageTaken`, and that `filteredText` has no timestamps.
- Mock a string with consecutive duplicate lines to test the grouping logic (e.g. 3 consecutive misses).
