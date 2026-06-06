# Original User Request

## Initial Request — 2026-05-20T21:34:55Z

Build an AI-driven battle analyzer integrated directly into the `mimir` Flutter application that automatically reads EVE Online local combat log files and uses an LLM to generate post-battle after-action reports for solo PvP players. The tool should identify tactical mistakes, highlight weaknesses in ship fits, and offer actionable advice for improvement based on the log data.

Working directory: /Users/jefcox/workspace/infiquetra/mimir
Integrity mode: development

## Verification Resources
- The example combat log (against the State Protector Merlin) provided by the user should be used as a test fixture to verify the LLM prompt's efficacy and the parsing logic.
- The repository's `GEMINI.md` file, which contains strict rules for Mimir's UI, AsyncValue handling, and database conventions.

## Requirements

### R1. Native Mimir Integration
The feature must be built as a native Dart/Flutter module. It must strictly follow Mimir's architectural standards: Riverpod for state management, go_router for navigation, and `EveColors` for UI aesthetic.

### R2. Smart Log Ingestion & Token Optimization
The tool must automatically locate and scan the standard EVE local combat log directory. It must:
- Parse the `Listener: [Name]` header to associate the log with the correct Mimir character.
- Pre-process/filter the raw log (e.g., summarizing repetitive drone misses) locally to reduce token usage *before* sending it to the LLM.

### R3. LLM Processing & Insights
The tool must allow the user to provide an LLM API key or use OAuth to authenticate. It should process the ingested combat logs and present a multi-pane analysis report.

### R4. UI Structure & Caching
The interface must present a list of detected combat encounters associated with the active character. Selecting an encounter should open a detailed analysis view with distinct panes. Once an encounter is analyzed, the response must be saved to Mimir's existing local SQLite `AppDatabase` (Drift) and loaded from memory on future visits to avoid duplicate API calls.

### R5. Analysis Dimensions
The analysis view must cover at least the following categories:
1. "What went wrong"
2. "How can I improve"
3. "Ship fit improvements"
4. Basic metric reports calculated directly from the raw log (e.g., damage dealt over time, damage received over time).

## Acceptance Criteria

### Log Detection
- [ ] A unit test successfully verifies that the log scanner can find and read a mock `.txt` combat log file.
- [ ] The application correctly handles cases where the log directory does not exist or is empty.

### LLM Processing & Insights
- [ ] An integration test verifies that a user can input and save their LLM API Key in the UI.
- [ ] A unit test successfully sends the sample Merlin combat log to a mock LLM endpoint and successfully parses the resulting analysis report.
- [ ] A unit test verifies that the system saves the LLM response to local storage, and a subsequent request for the same encounter fetches the cached data without triggering a new network request.
- [ ] The UI renders distinct panes for "What went wrong", "How to improve", "Fit improvements", and "Metrics" without overflow errors.
- [ ] The "Metrics" pane successfully displays accurate damage dealt and received over time based on local parsing of the combat log.
