# Scope: M1 - Log Ingestion & Parsing

## Architecture
- Module: `lib/features/combat_analyzer/data/log_scanner.dart` and `lib/features/combat_analyzer/data/log_parser.dart`
- Responsibilities: Find EVE local combat logs in standard directories. Parse `Listener: [Name]` to get the character name. Pre-process/filter the raw log (e.g., summarize repetitive drone misses) to reduce token usage. Calculate basic metrics (damage dealt, damage received).

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Log Ingestion & Parsing | Log discovery, parsing, and token optimization (filtering) | none | IN_PROGRESS |

## Acceptance Criteria
- A unit test successfully verifies that the log scanner can find and read a mock `.txt` combat log file.
- The application correctly handles cases where the log directory does not exist or is empty.
- Parses `Listener: [Name]` correctly.
- Filters/pre-processes log correctly (summarize repetitive entries).
- Extracts basic metrics (damage dealt/received over time).
