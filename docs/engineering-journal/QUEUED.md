# Queued Work - Mimir

> **Future-work items by priority with explicit worth-it-when triggers.** When a
> promising idea surfaces but we do not build it right now, it goes here.
>
> Format:
>
> ```markdown
> ### Short title
>
> **Author.** {agent-name}
> **Priority.** P0 / P1 / P2 / P3 / Maybe.
> **Effort.** Rough estimate.
> **Worth it when.** Specific trigger that makes this pressing.
> **Context.** What surfaced this and what should be remembered.
> **Refs.** Related entries, files, tests, plans, issues, or PRs.
> ```
>
> When work ships, move the entry to `ARCHIVE.md` as SHIPPED. When consciously
> rejected, move it to `ARCHIVE.md` as REJECTED. Never silently delete.

---

## P0 - Must Ship Before Next Release

<!-- P0 entries go here. -->

## P1 - Urgent

### AAR fit simulation and defense profile derivation

**Author.** Codex
**Priority.** P1
**Effort.** Several days to a week depending on whether the existing dogma
engine is sufficient or pyfa-grade behavior needs a deeper port.
**Worth it when.** Before presenting AAR recommendations as mechanically
trustworthy fit advice rather than AI coaching prose.
**Context.** The evidence ledger can now carry pilot and victim fits, but Mimir
still needs deterministic derivation for EHP, resists, tank layer, capacitor,
range envelope, speed, signature, and damage application. Without this, the AI
can discuss fits but cannot reliably quantify why one fit wins a matchup.
**Refs.** [LEARNINGS 2026-05-21](LEARNINGS.md#combat-logs-are-a-primary-source-but-not-a-complete-aar-evidence-source);
`lib/features/combat_analyzer/domain/combat_damage_matchup.dart`;
`lib/features/fitting/domain/dogma_engine.dart`;
`.codex/plans/2026-05-21-combat-analyzer-aar.md`.

### AAR evidence completeness score and pre-analysis checklist

**Author.** Codex
**Priority.** P1
**Effort.** Half-day to a day.
**Worth it when.** As soon as users routinely re-analyze reports after adding
fits or killmail evidence.
**Context.** The analyzer should tell the user what evidence is missing before
spending AI time: pilot fit, killmail match, opponent fit, range telemetry
limitations, tank profile, and confidence level. This makes unknowns actionable
instead of burying them in prose.
**Refs.** `lib/features/combat_analyzer/domain/combat_evidence_ledger.dart`;
`lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart`.

## P2 - Important

### Cap injectors and reloads in the cap simulation (remaining capSim parity)

**Author.** Qwen Code
**Priority.** P3
**Effort.** One day.
**Worth it when.** Users fit cap boosters or ammo-consuming cap modules and
compare stability against pyfa.
**Context.** The shipped CapSimulator ports pyfa's event loop for repeating
drains only; injectors (deferred usage, top-up logic) and clip reloads are
omitted and documented as such. Align/warp/cap-stable all shipped 2026-09-07;
DPS/volley/optimal/falloff shipped 2026-09-08 from bundled resolved modifiers
(see ARCHIVE SHIPPED 2026-09-08).
**Refs.** LEARNINGS 2026-09-07 cap-simulation entry.

### Unsupported dogma operators beyond postPercent/postMul

**Author.** Qwen Code
**Priority.** P2
**Effort.** Half a day, gated on knowing which operators matter.
**Worth it when.** A displayed row is traced to a modifier with operator 2
(preMul family, e.g. missile specialisation's
`characterMissileDamageMultiply`) and users compare against pyfa.
**Context.** Operator 4 shipped 2026-09-08 as a second postMul (heat sinks,
magnetic field stabilizers, ballistic control systems; pyfa Effect91/763).
The engine applies 6 (postPercent), 0 and 4 (postMul), and counts the rest
in a debug log instead of guessing semantics.
**Refs.** LEARNINGS 2026-09-08 modifierInfo and skill-filter entries.

### Fighter support (fighter bay, abilities, fighter-domain bonuses)

**Author.** Qwen Code
**Priority.** P3
**Effort.** Two to three days.
**Worth it when.** Users fit capital/supercapital or fighter-bonus ships and
ask why the drone section ignores their fighters.
**Context.** The 2026-09-08 drone pass covers combat drones (bandwidth,
bay volume, damage amps via charID modifiers filtered by the Drones skill).
Fighters use separate ability multipliers (attributes 2226/2178/2130 in the
DDA modifier list) and fighter bay bandwidth, a distinct model.
**Refs.** ARCHIVE SHIPPED 2026-09-08 drone DPS entry.

### Real wormhole-mapper integration (replaces the removed Pathfinder mock)

**Author.** Qwen Code
**Priority.** P2
**Effort.** Two to four days, dominated by finding a stable public mapper API
contract; the UI shell already existed.
**Worth it when.** A maintained public endpoint for live chain maps is
identified and its auth model is understood.
**Context.** Until 2026-09-07 `MapperSyncCard` connected to
`https://pathfinder.example.com` with `test-api-key` and rendered a hardcoded
`J210333` payload on a 30s timer behind a green "Connected to Pathfinder"
badge. That was fabricated data in an intel tool, so it was deleted outright
(card, `mapper_client.dart`, and `mapperClientProvider`) rather than gated.
A future implementation must derive its connection state from a real socket
and render an explicit disconnected state when there is none.
**Refs.** commit removing `lib/features/intel/data/mapper_client.dart`;
`lib/features/intel/presentation/kill_feed_screen.dart`.

### AAR fit import and capture UI tests

**Author.** Codex
**Priority.** P2
**Effort.** Half-day to a day.
**Worth it when.** Before making further AAR UI changes around evidence,
re-analysis, or fit comparison.
**Context.** The domain and parser tests cover evidence ledger, snapshot
mapping, matchup classification, and EFT parsing. The UI controls for manual
fit import, current fit snapshot, and "use current fit for this fight" still
need provider-overridden widget coverage that exercises ESI assets, SDE, and
enrichment storage together.
**Refs.** `lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart`;
`test/features/combat_analyzer/domain/combat_fit_snapshot_mapper_test.dart`;
`.codex/plans/2026-05-21-combat-analyzer-aar.md`.

### Correlate zKill attackers with combat-log actors

**Author.** Codex
**Priority.** P2
**Effort.** One to two days.
**Worth it when.** AARs frequently include multiple opponents or when the same
named actor appears across combat logs and killmails.
**Context.** Killmails expose attackers, ships, weapons, and damage done. The
combat log exposes local observed actors and timings. Correlating those sources
can reduce opponent-fit unknowns and make ship-vs-ship diagrams more useful.
**Refs.** `lib/features/combat_analyzer/domain/combat_killmail_matcher.dart`;
`lib/features/combat_analyzer/domain/combat_killmail_fit_mapper.dart`.

### Fit comparison visuals for AAR reports

**Author.** Codex
**Priority.** P2
**Effort.** One to three days.
**Worth it when.** Fit evidence and derived fit stats are available enough to
make visual deltas more accurate than prose.
**Context.** The user wants AARs to show current fit, fight-time fit, killmail
victim fit, and recommended changes side by side with module icons, stats, and
bill-of-materials style recommendations.
**Refs.** `lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart`;
`lib/features/fitting/presentation/widgets/fitting_editor.dart`.

## P3 - Nice To Have

<!-- P3 entries go here. -->

## Maybe

### Skill-queue push, if ESI ever gains a write endpoint

**Author.** Qwen Code
**Priority.** Maybe
**Effort.** One to two days once the endpoint exists.
**Worth it when.** The live OpenAPI spec shows a POST/PUT under
`/characters/{character_id}/skillqueue` or a manage-skills scope.
**Context.** Requested in the 2026-09-07 trust pass and verified impossible on
that date (LEARNINGS 2026-09-07). Do not re-plan it without re-checking the
spec first.
**Refs.** LEARNINGS 2026-09-07 "ESI cannot write the skill queue".

### Discord Rich Presence

**Author.** Qwen Code
**Priority.** Maybe
**Effort.** One to two days once a Dart Discord RPC transport is chosen.
**Worth it when.** Users ask to broadcast their in-game status from Mimir.
**Context.** `discord_rpc_service.dart` was a log-only mock ("Initializing
Discord RPC Mock") whose provider nothing watched; it was deleted with the
Pathfinder mock on 2026-09-07. Re-adding needs a real transport, not a stub.
**Refs.** commit removing `lib/features/intel/domain/discord_rpc_service.dart`.
