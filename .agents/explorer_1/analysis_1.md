# M1: Log Ingestion & Parsing - Strategy Report

**Summary:** The `combat_analyzer` feature will be structured as a native Flutter module under `lib/features/combat_analyzer/`, utilizing Drift for data persistence and Riverpod for state management. A log scanner will be responsible for locating macOS EVE logs, while a domain parser will extract and optimize token payloads from the combat logs.

## 1. Observation
- The `.agents/original_prompt.md` requires building a native module that parses EVE local combat logs, associates them with the correct character via the `Listener: [Name]` header, and optimizes the payload before sending it to an LLM. It also requires caching the encounter in local storage.
- An exploration of `lib/features/` shows that existing modules (e.g., `wallet`, `skills`, `fitting`) are consistently split into `data/`, `domain/`, and `presentation/` subdirectories.
- The `AppDatabase` class in `lib/core/database/app_database.dart` contains all existing local database tables (currently at schema version 17). There is currently no table for combat encounters.
- The test fixture was requested and has been successfully created with realistic rich text (color-tagged) EVE combat data at `test/features/combat_analyzer/fixtures/merlin_combat_log.txt`.

## 2. Logic Chain
- To adhere to Mimir's established architecture, the `combat_analyzer` module should follow the domain-driven file structure.
- **File IO / System Location**: The task of locating and reading local `.txt` files belongs in the data layer. Therefore, `LogScanner` should be implemented as `lib/features/combat_analyzer/data/combat_log_scanner.dart`.
- **Parsing / Business Logic**: Parsing the EVE combat log structure (extracting the listener, timestamp, target, and damage values) is pure business logic that needs to be highly testable. Thus, `CombatLogParser` should be implemented as `lib/features/combat_analyzer/domain/combat_log_parser.dart`.
- **Token Optimization**: The `CombatLogParser` can implement a summarization step (e.g., aggregating 10 misses into a single summary event) before returning the payload, thus addressing the token optimization requirement locally.
- **Caching to SQLite**: Because `AppDatabase` manages all persistence, a new `CombatEncounters` table must be added to `lib/core/database/app_database.dart`. A repository class (`lib/features/combat_analyzer/data/combat_analyzer_repository.dart`) will act as the intermediary to save and load encounters using Drift. 

## 3. Caveats
- EVE Online on macOS can be installed natively or via Wine/Crossover. The `LogScanner` will need to look in multiple potential paths (e.g., `~/Documents/EVE/logs/Gamelogs/` and `~/Library/Application Support/EVE Online/...`).
- A Drift schema migration will be required (incrementing from `schemaVersion => 17` to `18`), which involves writing an `onUpgrade` migration strategy in `app_database.dart`.
- We assume that `path_provider` can access the Documents directory on macOS without triggering sandbox permission issues, though sandbox entitlements may need to be verified.

## 4. Conclusion
**Proposed Strategy & Placement:**

1. **Database:** Add a `CombatEncounters` table to `lib/core/database/app_database.dart` with fields for `id`, `characterId`, `startTime`, `targetName`, `totalDamageDealt`, `totalDamageReceived`, and `llmAnalysisJson`.
2. **Domain Layer (`lib/features/combat_analyzer/domain/`):**
   - `combat_log_parser.dart`: Exposes `CombatLogParser` to take raw log text, identify `Listener: [Name]`, and return structured events.
   - `combat_models.dart`: Defines `CombatEncounter` and `CombatEvent`.
3. **Data Layer (`lib/features/combat_analyzer/data/`):**
   - `combat_log_scanner.dart`: Exposes `LogScanner` to find the correct macOS directory, scan for files, and stream new log contents.
   - `combat_analyzer_repository.dart`: Coordinates parsing the logs, finding the correct character via `Characters.name == Listener`, and saving/fetching the result to/from Drift.
   - `combat_analyzer_providers.dart`: Riverpod providers (e.g. `combatLogsProvider`) for UI consumption.
4. **Presentation Layer (`lib/features/combat_analyzer/presentation/`):**
   - UI widgets to be implemented in M2/M3.

## 5. Verification Method
- **Test Fixture:** The test fixture exists at `test/features/combat_analyzer/fixtures/merlin_combat_log.txt`.
- **Parsing Test:** Developers should create `test/features/combat_analyzer/domain/combat_log_parser_test.dart` and assert that the parser accurately extracts `Listener: Test Character` and aggregates damage output correctly using the fixture.
- **Database Build:** Developers should run `dart run build_runner build -d` after modifying `app_database.dart` to verify that `app_database.g.dart` regenerates without errors.
