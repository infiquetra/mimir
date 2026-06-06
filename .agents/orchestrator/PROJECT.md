# Project: AI-Driven Battle Analyzer

## Architecture
- Module/package boundaries: A new feature module `lib/features/combat_analyzer/` for presentation and domain logic.
- Data flow: Local file system (combat logs) → Parser/Aggregator → Drift Database (cache) ↔ LLM Service (API) → Riverpod Providers → UI.
- `lib/core/database/app_database.dart` must be updated with new tables.
- LLM API Key must be stored securely (or via existing settings system).

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Log Ingestion & Parsing | Log discovery, parsing, and token optimization (filtering) | none | PLANNED |
| 2 | LLM Service & Database Caching | Drift schema updates, LLM API client, DB caching layer | M1 | PLANNED |
| 3 | UI & Metrics | Combat analyzer screens, multi-pane view, API key input, metrics charting | M1, M2 | PLANNED |

## Interface Contracts
### `combat_analyzer` ↔ `database`
- Drift DB will store `combat_encounters` (id, character_id, start_time, end_time, file_path)
- Drift DB will store `combat_analyses` (id, encounter_id, what_went_wrong, how_to_improve, fit_improvements, raw_metrics_json)

### `combat_analyzer` ↔ `llm_service`
- `LLMService.analyzeEncounter(String filteredLog)` -> returns structured analysis.

## Code Layout
- `lib/features/combat_analyzer/data/` (repositories, log scanner, parser)
- `lib/features/combat_analyzer/domain/` (models)
- `lib/features/combat_analyzer/presentation/` (screens, widgets)
- `lib/core/database/` (updated Drift schema)
- `test/features/combat_analyzer/` (unit tests)
- `integration_test/screens/combat_analyzer/` (UI tests)
