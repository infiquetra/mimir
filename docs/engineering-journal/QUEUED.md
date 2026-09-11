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

### Clip reloads in the cap simulation (charge quantities)

**Author.** Qwen Code
**Priority.** P3
**Effort.** Half a day, gated on a fitting-model change.
**Worth it when.** Fittings carry charge quantities and users compare the
stability of ammo-limited cap modules against pyfa.
**Context.** Cap injectors shipped 2026-09-08 with infinite clips because a
fitting stores no charge quantities; pyfa's clip/reload accounting (shot
counters plus reload time between clips) stays unported.
**Refs.** ARCHIVE SHIPPED 2026-09-08 cap injectors entry.

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

### Missile and drone damage curated supplements (effects 660–668 and 1730)

**Author.** Antigravity / Lead Orchestrator
**Priority.** P3
**Effort.** Half-day to a day.
**Worth it when.** Missile or drone DPS is cross-checked against pyfa for weapon specialisations that publish empty `modifierInfo`.
**Context.** Like effect 1851 for sub-cap missile cycle time, effects 660–668 (sub-capital missile damage) and 1730 (drone damage specialisations) publish empty modifier lists in the SDE. Curating them following the 1851 pattern will bring 100% parity for missile and drone damage skills.
**Refs.** LEARNINGS 2026-09-11; design §7.

### Native dogma routing for basic ship skills (retire _skillModifiers table)

**Author.** Antigravity / Lead Orchestrator
**Priority.** P2
**Effort.** Half-day.
**Worth it when.** Refactoring DogmaEngine to eliminate hardcoded skill attribute tables.
**Context.** CPU Management, Power Grid Management, Navigation, etc., are currently hardcoded in `_skillModifiers`. Now that Category 16 (Skill) is bundled, their published dogma effects (446, 490, 394, 2432, 397, 271, 392, 486) can be routed natively under an expanded `skillEffectAllowlist`. The hardcoded table is currently an exclusion hazard where skills cannot be added to the allowlist without double-applying.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §2.3, §9.

### Turret tracking and missile application in AAR damage matchup

**Author.** Antigravity / Lead Orchestrator
**Priority.** P2
**Effort.** One to two days.
**Worth it when.** Matching weapon systems against fast or small targets where angular velocity, signature radius, or explosion radius/velocity reduce applied damage below nominal profile percentages.
**Context.** The current matchup uses nominal damage type distributions from logs/parser without factoring in tracking or missile application mechanics. Incorporating target signature radius and velocity vs attacker tracking/explosion velocity will make application analysis physically accurate.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §9, §10.

### Second-order module bonuses (compensation skills on passive hardeners)

**Author.** Antigravity / Lead Orchestrator
**Priority.** P2
**Effort.** Half-day.
**Worth it when.** Users fit passive armor or shield resistance platings/amplifiers with compensation skills trained.
**Context.** Armor and Shield Compensation skills modify a module's *bonus* attributes (984–987), which `routeOwnerModifiers` currently reads raw from baseAttributes. Reading modifying values via `moduleAttr` will allow compensation skill bonuses to flow into fitted modules.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §9.

### LLM prompt regression testing and verification (spec R4 follow-up)

**Author.** Antigravity / Lead Orchestrator
**Priority.** P2
**Effort.** One day.
**Worth it when.** Validating that Codex AAR outputs consistently adhere to the derived facts, avoid hallucinating resists/EHP, and correctly treat All V figures as upper bounds.
**Context.** Prompt schema v4 introduces `derivedFits` and `damageMatchups` with specific system prompt rules. Automated regression evaluations should verify that generated AARs cite `ev-derived-*` IDs and respect the "assumes All V" upper-bound constraints.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §4.5, §9.

### Ancillary repairer reload and module overheat in defense profiles

**Author.** Antigravity / Lead Orchestrator
**Priority.** P3
**Effort.** One day.
**Worth it when.** Modeling sustained active tank over extended engagements rather than single-cycle burst HP/s.
**Context.** Current active tank reflects burst single-cycle HP/s with Nanite Repair Paste loaded, without modeling the 60-second ancillary reload delay or overheat bonuses.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §2.5, §9.

### Dogma version stamping on derived facts

**Author.** Antigravity / Lead Orchestrator
**Priority.** P3
**Effort.** Half-day.
**Worth it when.** SDE dogma version changes require invalidating or distinguishing historical derived facts in the evidence ledger.
**Context.** Stamping `dogmaVersion` on `ev-derived-*` facts ensures historical ledger entries can be re-evaluated when the underlying dogma engine or SDE bundle updates.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §9.

### Bundle dgmAttributeTypes.stackable to replace owner-kind stacking heuristic

**Author.** Antigravity / Lead Orchestrator
**Priority.** P3
**Effort.** Half-day.
**Worth it when.** Modules with stackable attributes are fitted that should not be penalized despite being module-owned.
**Context.** Currently, fitted module/charge/drone/fighter owner kinds default to `penalized: true`. Bundling `dgmAttributeTypes.csv` `stackable` column will provide the authoritative CCP attribute flag for stacking penalties.
**Refs.** design §1.4, §7.

### Fighter ability activation / reload simulation (shot counters & rearm duration)

**Author.** Antigravity / Lead Orchestrator
**Priority.** P3
**Effort.** One to two days.
**Worth it when.** Sustained carrier DPS simulation across burst abilities (bombs, missiles) is needed.
**Context.** V1 assumes infinite ability charges and cap clips matching pyfa default fit DPS. Porting shot counts and rearm/refueling durations (`fighterRefuelingTime` 2426) will provide sustained DPS timelines.
**Refs.** design §3.4, §7.

### Fighter and drone editing UI in fitting editor

**Author.** Antigravity / Lead Orchestrator
**Priority.** P3
**Effort.** Two to three days.
**Worth it when.** Users create or edit carrier fits directly in Mimir's fitting editor rather than importing via EFT/ESI/killmail.
**Context.** Currently fighters and drones are populated via EFT import, clipboard paste, ESI, or killmails. Adding a dedicated interactive bay editor will allow full fit customization in the UI.
**Refs.** design §3.1, §7.

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
