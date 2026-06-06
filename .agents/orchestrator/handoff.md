# Handoff: AI-Driven Battle Analyzer

## Milestone State
- **M1 (Log Ingestion & Parsing):** DEGRADED (Specification and Test Fixtures completed; Dart code blocked by API capacity)
- **M2 (LLM DB & Service):** DEGRADED (Schema designed; Dart code blocked by API capacity)
- **M3 (UI & Metrics):** DEGRADED (UI Layout mapped to requirements; Dart code blocked by API capacity)
- **E2E Testing Track:** DEGRADED (TEST_READY.md and TEST_INFRA.md published; Dart code blocked by API capacity)

## Active Subagents
None. All spawned implementation and exploration agents (`teamwork_preview_worker`, `teamwork_preview_explorer`, `self`) suffered immediate fatal `RESOURCE_EXHAUSTED (code 429)` API quota crashes, even after extensive exponential backoff.

## Key Decisions Made (Degradation)
Due to strict orchestrator constraints ("NEVER write, modify, or create source code files directly") and the infrastructure failure preventing subagent delegation, the Project Orchestrator has degraded gracefully:
1. The required mock test fixture (`merlin_combat_log.txt`) has been successfully generated in the test directory via terminal.
2. The architectural blueprint and specifications have been finalized in `PROJECT.md`.
3. The E2E test plan has been published in `TEST_INFRA.md` and `TEST_READY.md`.
4. The remaining code implementation is handed off to the user's local environment.

## Remaining Work for Local Implementation
**1. Log Scanner & Parser (`lib/features/combat_analyzer/data/`)**
- Implement `LogScanner` to locate `~/Documents/EVE/logs/Gamelogs/` (or Chatlogs depending on the OS setup).
- Implement `CombatLogParser` using regex to extract damage (e.g., `(?<damage>\d+).*?(?<direction>from|to).*?(?<entity>.*?)\s-`).
- Group duplicate messages in memory before generating the prompt string.

**2. Drift Database Updates (`lib/core/database/app_database.dart`)**
- Add `CombatEncounters` table (id, characterId, file, timestamp).
- Add `CombatAnalyses` table (encounterId, whatWentWrong, howToImprove, fitImprovements, metricsJson).
- Run `dart run build_runner build` to generate `app_database.g.dart`.

**3. Riverpod Providers & UI (`lib/features/combat_analyzer/presentation/`)**
- Use `.when()` on `AsyncValue` data coming from the LLM service or Drift cache.
- Ensure the UI contains four distinct panes (cards) for the requested insights.
- Ensure EVE IDs (if applicable) are resolved using `itemNameProvider`.

## Key Artifacts
- `/Users/jefcox/workspace/infiquetra/mimir/.agents/orchestrator/PROJECT.md`
- `/Users/jefcox/workspace/infiquetra/mimir/TEST_READY.md`
- `/Users/jefcox/workspace/infiquetra/mimir/test/features/combat_analyzer/fixtures/merlin_combat_log.txt`
