# Handoff Report: M1 Log Ingestion & Parsing Strategy

## 1. Observation
- The `combat_analyzer` feature directory does not currently exist under `lib/features/`.
- Mock combat log at `test/features/combat_analyzer/fixtures/merlin_combat_log.txt` contains combat entries formatted as `[ YYYY.MM.DD HH:MM:SS ] (combat) ...` with specific damage and miss formats.
- EVE log files on macOS are typically stored in `~/Documents/EVE/logs/Gamelogs`.
- `intl` and `freezed` packages are available in `pubspec.yaml` to handle date parsing and immutable models.
- `GEMINI.md` mandates Riverpod for state, comprehensive debug logging via `Log`, and specific directory structures.

## 2. Logic Chain
1. **Log Discovery (`LogScanner`)**: We must locate combat logs on the user's local disk. On macOS, since desktop apps use standard user paths, we can construct the path using `Platform.environment['HOME']` + `Documents/EVE/logs/Gamelogs`. The scanner will filter for `.txt` files and sort them by modification date descending.
2. **Models (`ParsedCombatLog`, `CombatMetric`)**: We need domain models to represent the parsed data. Using `freezed` ensures immutability and JSON serialization, following the app's standard practices.
3. **Parsing & Token Optimization (`CombatLogParser`)**: 
   - A line-by-line parser using Regular Expressions will efficiently extract the character name (`Listener: <name>`), session start time, and individual combat metrics (incoming/outgoing damage and misses).
   - For token optimization (to reduce LLM costs), we can group consecutive identical messages (ignoring their timestamps) into a single line like `3x State Protector Merlin misses you completely`.
4. **Logging**: In accordance with `GEMINI.md`, the `[COMBAT]` tag will be used with `Log.d`, `Log.i`, and `Log.e` for operations like scanning the directory and parsing the log.

## 3. Caveats
- **macOS Sandboxing**: If the Mimir app is strictly sandboxed on macOS, direct access to `~/Documents` might require user permission or entitlements (`com.apple.security.files.user-selected.read-write`). For now, we assume standard read access is granted or will be requested via standard mechanisms.
- **Outgoing Misses**: The mock data does not contain an example of the player missing an enemy. The regex for outgoing misses (e.g., `You miss (.*?) completely`) should be added but might need fine-tuning if the exact string differs.
- **Timezones**: The logs use a specific format (`yyyy.MM.dd HH:mm:ss`) which is generally EVE Server Time (UTC). We parse it as local time by default with `intl`, which may need UTC conversion depending on UI needs.

## 4. Conclusion
The implementation of M1 requires creating the `combat_analyzer` feature structure and implementing the scanner and parser classes.

### Step-by-Step Implementation Strategy for Worker:
1. **Create Directories**: Create `lib/features/combat_analyzer/domain/` and `lib/features/combat_analyzer/data/`.
2. **Implement Models**:
   - Create `lib/features/combat_analyzer/domain/combat_metric.dart` using `@freezed`.
   - Create `lib/features/combat_analyzer/domain/parsed_combat_log.dart` using `@freezed`.
   - Run `dart run build_runner build -d` to generate the `.freezed.dart` and `.g.dart` files.
3. **Implement LogScanner**:
   - Create `lib/features/combat_analyzer/data/log_scanner.dart`
   - Implement `getDefaultLogDirectory()` using `Platform.environment['HOME']` for macOS.
   - Implement `getCombatLogs()` to return sorted `File` objects.
   - Add logging: `Log.d('[COMBAT]', 'Scanning directory: $dirPath')`.
4. **Implement LogParser**:
   - Create `lib/features/combat_analyzer/data/log_parser.dart`
   - Implement regexes for incoming/outgoing damage and misses.
   - Implement `parse(File file)` to extract `characterName`, filter empty lines, map damage entries to `CombatMetric` objects, and apply the "consecutive identical line grouping" logic for token optimization.
   - Add logging: `Log.i('[COMBAT]', 'Parsed log for $characterName with ${metrics.length} metrics')`.
5. **Implement Riverpod Providers**:
   - Create `lib/features/combat_analyzer/data/combat_analyzer_providers.dart`.
   - Provide instances of `LogScanner` and `CombatLogParser`.

## 5. Verification Method
- **Unit Tests**: The worker should write unit tests in `test/features/combat_analyzer/data/log_parser_test.dart` using the provided mock file (`merlin_combat_log.txt`).
- **Validation**: Verify that the parser correctly extracts `Test Character`, successfully maps all incoming and outgoing hits into `CombatMetric` instances, and condenses the multiple miss lines correctly if they occur consecutively.
- Run `flutter test test/features/combat_analyzer/data/log_parser_test.dart` to validate.
