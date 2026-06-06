# Project: Mimir - AI Battle Analyzer
Date: 2026-05-20
Checkpoint: 2026-05-20-18-00

## Overview
We are implementing the **AI Combat/Battle Analyzer** directly within Mimir's desktop Flutter context. This features local EVE log directory scanning, segmenting long gamelogs into individual PvP fights (by idle time gap), caching the combat summaries and LLM feedbacks inside a new Drift SQLite table (v18 schema bump) to ensure analyzed fights are never re-sent to LLM, and rendering a highly detailed multi-pane layout featuring tactical improvements and a custom-painted Cumulative Damage dealt/received chart.

## Phase: Research & Planning
- [x] Analyze existing log scanner and parser placeholders
- [x] Research Mimir's multi-window routing and Drift schema
- [x] Create formal `implementation_plan.md` and check in with user
- [x] [CHECKPOINT] User requested implementation of the Hermes-style Codex auth plan

## Phase: Implementation

### Parallel Group 1: Core Database & Log Logic [P1]
- [x] [P1] Bump Drift schemaVersion to 18 in `app_database.dart`
- [x] [P1] Add `CombatEncounters` table and LLM configuration settings columns
- [x] [P1] Implement schema v18 migration logic in `onUpgrade`
- [x] [P1] Run build_runner to regenerate database wrappers
- [x] [P1] Fix `log_scanner.dart` text filename filters to support actual timestamp files

### Sequential Tasks: Log Segmenting & Parsing [SEQ]
- [x] [SEQ] Update `combat_log_parser.dart` to segment single gamelogs into encounters (threshold: 45s idle gap)
- [x] [SEQ] Add tests in `combat_log_parser_test.dart` to verify segmentation and parsing
- [x] [SEQ] Save checkpoint and verify tests pass

### Sequential Tasks: Mimir-Owned Codex Auth & Window Hook [SEQ]
- [x] [SEQ] Replace generic in-app device OAuth with Hermes-style Codex device auth and Mimir-owned `auth.json`
- [x] [SEQ] Add Codex token refresh, owner-only auth file writes, and optional import from valid Codex CLI credentials
- [x] [SEQ] Create `combat_analysis_service.dart` support for the Codex Responses backend, structured JSON output, timeout handling, and local SQLite caching
- [x] [SEQ] Hook up `WindowType.combatAnalyzer` (ID 13) in `window_types.dart`, `sub_window_app.dart`, and `tray_service.dart`

### Parallel Group 2: UI Presentation & Custom Chart [P2]
- [ ] [P2] Build EVE-style `EncounterListScreen` with opponent list, win/loss stats, and API settings popup
- [ ] [P2] Build `AnalysisMultiPaneScreen` with Markdown feedback panes ("What went wrong", "Piloting improvement", "Fits")
- [ ] [P2] Implement `CustomPainter` to draw gorgeous neon glowing line/area charts of cumulative damage over time
- [ ] [P2] Write comprehensive widget and golden tests for the analyzer panels

### Sequential Tasks: AAR Evidence Enrichment [SEQ]
- [x] [SEQ] Add an evidence ledger to track confirmed facts, inferred facts, reference data, and unresolved unknowns
- [x] [SEQ] Capture pilot fit evidence from manual EFT/DNA import and current active ship assets
- [x] [SEQ] Carry killmail victim fit evidence into enrichment and the AAR prompt payload
- [x] [SEQ] Upgrade the structured AAR prompt/report contract to v3 for evidence-aware analysis
- [x] [SEQ] Add domain foundations for current-ship asset snapshot mapping and damage-vs-defense matchup classification
- [x] [SEQ] Improve EFT parsing so ship and module names resolve through SDE when available
- [ ] [SEQ] Derive richer hull/module/rig/drone/charge defense profiles from SDE and dogma data
- [ ] [SEQ] Add pyfa-grade fit simulation for EHP, resists, range envelopes, capacitor pressure, speed, signature, and application
- [ ] [SEQ] Correlate zKill/ESI attackers with combat-log actors to reduce opponent loadout unknowns
- [ ] [SEQ] Add evidence completeness scoring and a pre-analysis checklist
- [ ] [SEQ] Add fit comparison visuals for current fit, fight-time fit, killmail victim fit, and recommended deltas

## Phase: Review & Finalization
- [ ] Self Code review
- [ ] Verify clean compilation (`flutter analyze`)
- [ ] Update README.md with Combat Analyzer documentation
- [ ] Create detailed walkthrough.md

## Notes
- Keep every code change as simple and clear as possible.
- Avoid external charting libraries; utilize Flutter's CustomPainter for a beautiful customized pixel-perfect look.
- Strict caching rule: Never send an encounter to the LLM if it's already cached in Drift.
