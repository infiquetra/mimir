# Combat Analyzer Commander AAR

Goal: implement a tactical MVP of the Commander AAR plan for the combat analyzer.

Current phase: implemented and locally verified.

Planned changes:
- Add rich parsed encounter/domain data with stable ids, event telemetry, aggregates, and outcome confidence.
- Add parsed encounter cache persistence and additive Drift migration.
- Filter/sort/group encounters by active character, timeline, and outcome.
- Replace prose-only Codex reports with structured AAR JSON plus legacy fallback.
- Render a richer AAR screen with command summary, timeline, damage report, ranked mistakes, improvements, and fit advice.
- Add focused parser, cache, provider, Codex client, and UI tests.

Constraints:
- Preserve existing user/worktree changes.
- Do not require zKillboard or ESI enrichment for the first implementation.
- Keep analysis explicit; list loading must not send logs to Codex.

Completed:
- Rich parser/domain data with events, stable ids, aggregates, outcome confidence, and JSON.
- Drift schema version 19 with parsed encounter cache and structured analysis fields.
- Parsed encounter cache keyed by file path, mtime, size, and parser version.
- Active-character filtered encounter list with scope, grouping, and sort controls.
- Structured Codex AAR report contract with legacy report fallback.
- Commander AAR screen with summary, timeline, damage breakdowns, ranked mistakes, improvements, and fit advice.

Checks run:
- `dart run build_runner build --delete-conflicting-outputs`
- `flutter analyze lib/features/combat_analyzer lib/core/database/app_database.dart test/features/combat_analyzer`
- `flutter test test/features/combat_analyzer`
- `flutter test test/core/database/app_database_test.dart`

## 2026-05-21 AAR UX + Damage Evidence Update

Completed:
- Renamed combat reports in the UI to After Action Reports with UTC AAR titles.
- Added cached AAR markers for ready, legacy, and unanalyzed encounters.
- Added staged analysis progress with progress text and timing logs.
- Replaced the simple damage chart with an axis-labeled UTC timeline, key-moment markers, and legends.
- Added parser-derived application metrics and confidence-labeled SDE damage type resolution.
- Extended structured AAR JSON to v2 with key-moment categories and damage analysis.
- Reworked the damage tab around metric cards, application rates, damage type profile, and defense limitations.

Checks run:
- `flutter analyze lib/features/combat_analyzer test/features/combat_analyzer`
- `flutter test test/features/combat_analyzer`

## 2026-05-21 AAR Evidence Enrichment Update

Completed:
- Added an evidence ledger model so each AAR can distinguish confirmed facts, inferred facts, reference data, and open unknowns.
- Added pilot-fit evidence paths: manual EFT/DNA import, current active ship snapshot, and explicit current-fit confirmation.
- Added killmail victim-fit evidence into enrichment and prompt payloads so destroyed ship context is preserved.
- Extended structured AAR input/output to v3 with evidence ledger, pilot fit evidence, and victim fit evidence.
- Added focused domain foundations for current-ship asset snapshot mapping and damage-vs-defense matchup classification.
- Improved EFT import parsing so ship and module names resolve through SDE when reverse lookup data is available.
- Added AAR evidence UI controls and evidence/unknown chips to make missing context actionable before re-analysis.

Queued follow-ups:
- Derive richer defense/tank profiles from ship hull, modules, rigs, charges, drones, and character skills instead of relying only on supplied LLM text.
- Add pyfa-grade or dogma-engine-backed fit simulation for EHP, resist holes, range envelopes, capacitor pressure, speed, signature, and damage application.
- Correlate zKill/ESI killmail attackers with combat-log actors to reduce opponent ship/loadout unknowns.
- Build an explicit "evidence completeness" score and pre-analysis checklist so the user knows which imports would improve the report.
- Add fit comparison visuals that show current fit, fight-time fit, killmail victim fit, and recommended deltas side by side.
- Add tests for the new fit import/capture UI flow once provider overrides exist for ESI assets, SDE, and enrichment storage together.

Checks run:
- `flutter test test/features/combat_analyzer/domain/combat_evidence_ledger_test.dart test/features/combat_analyzer/domain/combat_fit_snapshot_mapper_test.dart test/features/combat_analyzer/domain/combat_damage_matchup_test.dart test/features/fitting/domain/format_parser_test.dart test/features/combat_analyzer/domain/combat_aar_report_test.dart`
- `dart analyze lib/features/combat_analyzer lib/features/fitting/domain/format_parser.dart test/features/combat_analyzer test/features/fitting/domain/format_parser_test.dart`
- `flutter test test/features/combat_analyzer test/features/fitting/domain/format_parser_test.dart`
