# Handoff Report: M1 Log Ingestion & Parsing Strategy

## 1. Observation
- `test/features/combat_analyzer/fixtures/merlin_combat_log.txt` contains combat entries formatted with rich text tags, e.g.:
  `[ 2026.05.20 18:32:15 ] (combat) <color=0xccff0000><b>120</b> <color=0x77ffffff><font size=10>to</font>...`
- The file begins with a `Listener: [Name]` header, allowing character association.
- Tests confirm that removing HTML tags via `RegExp(r'<[^>]*>')` successfully produces clean, token-efficient text like `120 to State Protector Merlin - Light Neutron Blaster II - Penetrates`.
- Tests confirm that regex `^(\d+) (to|from) (.*?) - (.*?) - (.*)$` successfully extracts quantitative damage metrics from the cleaned text.
- The app is macOS Sandboxed (`macos/Runner/DebugProfile.entitlements` has `com.apple.security.app-sandbox` set to `true`). Direct access to `~/Documents/EVE/logs/Gamelogs/` may result in a permission denied error without explicit user action or sandbox removal.
- Neither `file_picker` nor `file_selector` are currently in `pubspec.yaml`.

## 2. Logic Chain
1. **Directory Scanning (`LogScanner`)**: The scanner should first attempt to read from standard paths (`~/Documents/EVE/logs/Gamelogs/` for native Mac and Wine crossover paths). Because of App Sandboxing, if `Directory(path).existsSync()` fails or throws a permission error, the system must prompt the user to select the log directory using a folder picker. The implementer must add `file_picker` or `file_selector` to `pubspec.yaml` and save the selected path to a local setting (e.g., via SharedPreferences or Drift).
2. **Log Pre-processing & Token Optimization (`CombatLogParser`)**: To drastically reduce the payload sent to the LLM (and thus save costs/context window), the parser must:
   - Identify the character via the `Listener: ` prefix.
   - Filter out empty lines.
   - Strip all HTML-like tags using `line.replaceAll(RegExp(r'<[^>]*>'), '')`.
   - Remove the repetitive `(combat)` string and the date portion of the timestamp, leaving only time `[HH:MM:SS]`.
   - Implement a run-length encoding (grouping) algorithm for identical consecutive events (such as repeated drone misses). The algorithm tracks `lastActionText`, increments a counter, and emits a grouped string when the action changes (e.g., `[18:32:30 - 18:32:34] 3x Warrior II misses you completely`).
3. **Metrics Extraction**: The parser must calculate metrics locally to populate the "Metrics" UI pane without LLM processing. Using the cleaned string, it matches against the damage regex to increment `totalDamageDealt` (if direction is "to") and `totalDamageReceived` (if direction is "from").
4. **Data Modeling**: The parser should return a structured domain model (e.g., `ParsedCombatEncounter` using `freezed`) containing the `characterName`, the `llmPayloadString` (the optimized log text), and the numerical metrics.

## 3. Caveats
- If the app is distributed strictly outside the Mac App Store, developers might choose to disable `com.apple.security.app-sandbox` entirely in `macOS/Runner/*.entitlements` to allow direct, seamless access to the Documents folder. However, building the fallback folder picker is safer and more robust.
- Time parsing currently relies on local timezone interpretation unless explicitly parsed as UTC. EVE logs are in UTC, so the parser should account for this if exact timezone matching with the ESI API is required.

## 4. Conclusion
The implementation of M1 is clearly defined and validated via regex tests. 

### Implementation Plan:
1. **Setup**: Add `file_selector` (or `file_picker`) to `pubspec.yaml` to handle directory selection.
2. **Models**: Create `ParsedCombatEncounter` using `@freezed` in `lib/features/combat_analyzer/domain/` to hold the optimized string and metrics.
3. **Parser (`CombatLogParser`)**: Implement the parser in the domain layer. It must strip HTML tags, group consecutive identical events, and sum up damage dealt/received.
4. **Scanner (`LogScanner`)**: Implement in the data layer. It should try default paths first, catch permission exceptions, and expose a method to trigger a system folder picker.
5. **Logging**: Ensure all parsing and scanning activities use `Log.d` or `Log.i` with a `[COMBAT]` tag as per `GEMINI.md`.

## 5. Verification Method
- **Parsing Verification**: Create `test/features/combat_analyzer/domain/combat_log_parser_test.dart` using the `merlin_combat_log.txt` fixture. Assert that the `totalDamageDealt` is `525` and `totalDamageReceived` is `457`.
- **Optimization Verification**: In the same test, assert that the optimized string does not contain `<color` tags, has short timestamps `[HH:MM:SS]`, and that consecutive identical lines are collapsed into an `Nx` multiplier format.
- **Scanner Verification**: Run the app locally on macOS. Verify that if the default path is inaccessible due to Sandbox, the UI (in future milestones) or the console logs prompt for user folder selection.
