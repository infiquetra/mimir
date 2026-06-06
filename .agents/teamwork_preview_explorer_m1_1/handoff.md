# Observation
- The mock combat log is located at `test/features/combat_analyzer/fixtures/merlin_combat_log.txt`.
- It contains header lines (e.g., `Listener: Test Character`, `Session Started: ...`) and combat lines in the format: `[ yyyy.MM.dd HH:mm:ss ] (combat) <message>`.
- Combat messages include incoming damage (`<amount> from <entity> - <weapon> - <quality>`), outgoing damage (`<amount> to <entity> - <weapon> - <quality>`), misses (`<entity> misses you completely - <weapon>`), and statuses (`Warp drive active`).
- The project follows a feature-first architecture (`lib/features/feature_name/`).
- Database logic is in `lib/core/database/`, but `ParsedCombatLog` does not need to be a Drift table yet since it is a transient domain representation before LLM analysis.
- `path_provider`'s `getApplicationDocumentsDirectory()` maps to `~/Documents` on macOS.

# Logic Chain
1. A new feature folder `lib/features/combat_analyzer/` must be created.
2. We need domain models `ParsedCombatLog` and `CombatMetric` in `domain/combat_log.dart` to represent the parsed results.
3. The `LogScanner` belongs in `data/log_scanner.dart`. It will use `path_provider` to locate the Mac OS EVE logs directory at `~/Documents/EVE/logs/Gamelogs`, list all `.txt` files, and sort them descending by last modified time.
4. The `CombatLogParser` belongs in `data/combat_log_parser.dart`. It reads a log file and applies:
   - **Metrics Extraction:** Regex matches on the combat messages to populate `CombatMetric` models.
   - **Token Optimization:** Strips out `(combat)`, dates, and dashed lines. Compresses consecutive identical messages (e.g. `[18:32:10] 2x State Protector Merlin misses you completely...`) using a buffer to dramatically reduce the text sent to the LLM.
5. Providers need to be created in `data/combat_analyzer_providers.dart` to expose these services via Riverpod.

# Caveats
- The EVE log path `~/Documents/EVE/logs/Gamelogs/` is correct for macOS but may differ if Windows support is added. `LogScanner` should gracefully return an empty list if the directory does not exist.
- The `merlin_combat_log.txt` fixture has limited edge cases (e.g., no outgoing misses). The metrics regex should safely ignore unmatched lines instead of crashing.
- Token optimization strips the date from timestamps (leaving only time). This is an acceptable tradeoff since combat encounters rarely span midnight and the `Session Started` line provides the day context.

# Conclusion
The worker agent should implement M1 by following these exact steps:

1. **Create Domain Models (`lib/features/combat_analyzer/domain/combat_log.dart`):**
   - Create `ParsedCombatLog` (properties: `characterName`, `sessionStarted`, `filteredText`, `metrics`).
   - Create `CombatMetric` (properties: `timestamp`, `entityName`, `damage`, `isIncoming`, `weapon`, `quality`).

2. **Implement LogScanner (`lib/features/combat_analyzer/data/log_scanner.dart`):**
   - Implement `Future<List<File>> getCombatLogs()`.
   - Retrieve `getApplicationDocumentsDirectory()`, append `EVE/logs/Gamelogs`, and filter for `.txt` files.
   - Return sorted by `statSync().modified` descending.

3. **Implement CombatLogParser (`lib/features/combat_analyzer/data/combat_log_parser.dart`):**
   - Implement `Future<ParsedCombatLog> parse(File file)`.
   - **Token Optimizer:** Skip `-----` and empty lines. Retain `Listener:` and `Session Started:`. For combat lines, extract the time (`HH:mm:ss`) and the message. If the message exactly matches the previous line's message, increment a counter. Otherwise, flush the previous message as `[Time] {count}x {message}` (or `[Time] {message}` if count=1).
   - **Metrics Extraction:** Use regex to parse incoming/outgoing damage (`^(\d+) (from|to) (.*?)\s+-\s+(.*?)\s+-\s+(.*)$`) and misses to populate `CombatMetric`. Make sure to parse the full timestamp for metrics.

4. **Add Tests:**
   - Create `test/features/combat_analyzer/data/combat_log_parser_test.dart`.
   - Test that `parse()` correctly extracts the character name "Test Character", produces the correct `filteredText` (with compressed messages), and extracts `metrics` matching the `merlin_combat_log.txt` fixture.

5. **Create Providers (`lib/features/combat_analyzer/data/combat_analyzer_providers.dart`):**
   - Create Riverpod providers for `LogScanner` and `CombatLogParser`.

# Verification Method
- The worker will run `flutter test test/features/combat_analyzer/data/combat_log_parser_test.dart` to verify that all metrics are accurately extracted and that token optimization accurately counts consecutive identical messages without crashing.
