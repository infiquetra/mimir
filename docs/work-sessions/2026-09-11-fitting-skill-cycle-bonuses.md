# Work session: Fitting skill cycle-time bonuses (U0–U2)

Date: 2026-09-11
Plan: `.agents/plans/2026-09-11-fitting-completion-skill-rof-and-fighters.md`
Branch: `feature/fitting-skill-cycle-bonuses`
Backend: inline (U0 → U1 → U2 share `dogma_engine.dart` / `sde_service.dart`; sequential)

## Built

- **U0** Bundled SDE now includes category 16 (Skill) and 87 (Fighter). `SdeService.bundledDogmaVersion = 2` re-imports on mismatch. `getDogmaTypes` loads types/attributes/effects in 3 chunked IN queries (500 ids).
- **U1** Six-slot `requiresSkill`, `_Bonus` buckets with owner-kind stacking, `bonusScale` from skillLevel (280), `calculateStats(..., skillTypes:)` with empty-map legacy shim.
- **U2** Skill effect allowlist + curated Effect1851 for the six sub-capital missile specs. `fittingSkillTypesProvider` feeds trained ∪ hull-required skills into `fittingStatsProvider`.

## change_kinds

behavior, data

## Checks run

- `flutter test test/core/sde/sde_service_test.dart` — 10 passed
- `flutter test test/features/fitting/domain/dogma_engine_test.dart --name "skill cycle"` — 26 passed
- `flutter test test/features/fitting/domain/dogma_engine_test.dart` — 52 passed
- `flutter analyze` — no issues

## U3–U4 (this session)

- **U3** EFT `Name xN` lines classify as drones (cat 18) or fighters (cat 87) and merge by type. `generateEft` emits drones then fighters after rigs. Snapshot `FighterBay`/`FighterTube0..4` and killmail flags 158/159–163 map onto `FighterGroup`. ESI export writes `FighterBay` items.
- **U4** DogmaEngine classifies on attr 2215, activates squadrons in declaration order under tube/class caps, and sums attack (6465) or missiles (6431) DPS via `charID` bonuses. `dpsTotal` includes `dpsFighters`. StatsPanel shows OFFENSE `Fighters` and a FIGHTERS section (error colour when bay used > max). Hulls without tubes/bay omit the section.
- Skill catalogue perf test now sets `dogma_version` so dummy dogma still skips bundled re-import.

## Checks run (U3–U4)

- `flutter test test/features/fitting/domain/format_parser_test.dart` — passed
- `flutter test test/features/combat_analyzer/domain/combat_fit_snapshot_mapper_test.dart` — passed
- `flutter test test/features/fitting/domain/dogma_engine_test.dart --name "fighters"` — 34 passed
- `flutter test test/features/fitting/presentation/widgets/stats_panel_test.dart` — 2 passed
- `flutter test` — 506 passed, 14 skipped
- `flutter analyze` — no issues

## Next step

Implement U5 (journal, spec corrections, verification, handoff) from the same plan.
