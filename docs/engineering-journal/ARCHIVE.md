# Archive - Shipped + Rejected + Superseded Items

> **Terminal history for queued, learning, and decision items.** When something
> from `QUEUED.md` ships, move it here as SHIPPED. When something is consciously
> rejected, move it here as REJECTED. When a learning or decision is invalidated,
> move the pre-correction version here as SUPERSEDED.
>
> Append newest entries to the top. Preserve history; never silently delete.

---

### SHIPPED 2026-09-15: AAR Fit Import and Capture UI Tests and Defect Remediation

**Author.** Antigravity / Lead Orchestrator
**Shipped as.** Completed comprehensive end-to-end delivery of the AAR fit import and capture UI testing and contract hardening (satisfying AC1–AC24 across all 36 test cases T01–T36 and fixing the three core defects: colon-based EFT/DNA dispatch, silent-loss import validation, and forced-refresh fit eviction):
- Real test harness (U0): `FitEvidenceHarness` owning real in-memory `AppDatabase` and `SdeDatabase` outside widget scope, scripted Dio ESI client, controlled discovery and Codex AI clients, clean teardown ordering (`disposeWidgets` -> `disposeEsiWatch` -> DB close), and assertion guards against unintended network I/O or background timers.
- Faithful import adapter (U1): `AarFitImportParser` implementing strict structural validation, exact SDE lookups, bounds enforcement (256 KiB, 4096 modules, int32 quantities), grammar disambiguation distinguishing colon EFT headers `[Hull, Fit: Sub]` from DNA syntax, and additive `FittingFormatParser` seams preserving tolerant behavior elsewhere.
- Fail-closed capture and typed error taxonomy (U2): Hardened `captureCurrentPilotFit` with multi-page asset pagination (`x-pages` header validation), complete inventory assembly before saving, qualified empty-inventory handling (`pilotFitNoModules` distinct from unconfirmed reference), and truthful user-facing error messages matching direct ESI failures.
- Atomic enrichment retention and analysis barrier (U3): Introduced `CombatEnrichmentRepository.mutateEnrichment` routing all mutations through SQLite transactions with ledger fact/unknown tracking (`ev-pilot-fit-<id>`); `AarEvidenceOperationCoordinator` double-tap guard and operation serialization; and `AarEvidenceCommitPublisher` publishing commits across provider lifecycles. Ensured manual, captured, and victim fits survive forced re-analysis, AI retry, and scope recreation without stale overwrite or data loss.
- UI lifecycle and live evidence integration (U4): Extracted `ImportPilotFitDialog` owning its controller with scrollable constraints, autofocus, Escape/barrier dismissal, and cancel no-ops; added generation/route guards (`_screenGeneration`, `_hostRoute`, `_canPublishUi`) preventing stale post-await setState or snackbars across route transitions; disambiguated command strip keys (`aar-command-strip-reanalyze`) and overview chip labels (`Enrichment`); and validated live EHP defense deltas, score thresholds (+10 banner), and 360px/200% responsive layouts without raw numeric IDs.
- Full verification (U5): All 951 tests passing (`flutter test`), static analysis clean (`flutter analyze`), formatting verified (`dart format`), and cross-agent sign-offs obtained from `reviewer` (Muse) and `tester` (Codex).
**Refs.** LEARNINGS 2026-09-15; DECISIONS 2026-09-15; docs/specs/aar-fit-import-capture-ui-tests.md; docs/specs/aar-fit-import-capture-ui-tests-design.md; .agents/plans/2026-09-15-aar-fit-import-capture-ui-tests.md.

### SHIPPED 2026-09-15: Per-Attacker Incoming Damage Profile and Defense Matchup

**Author.** Antigravity / Lead Orchestrator
**Shipped as.** Split the aggregate incoming damage profile into per-attacker damage profiles and defense matchups using Milestone 4's attacker correlation in Combat Analyzer:
- Exact rational allocation: `DamageQuantity` reduced BigInt rationals (GCD in factory, lossless fraction arithmetic, SDE decimal parsing without float inaccuracy), `IncomingDamageVector`, and `IncomingDamageAllocator` guaranteeing exact damage conservation (`C_a + C_X + C_N == C_aggregate` and `sum(C) + U == T`).
- Pure domain partition and deriver: `AarAttackerMatchupDeriver`, `IncomingDamageMatchup`, and `AarIncomingMatchupBundle`. Only Confirmed and Probable attackers receive discrete matchup cards; shipType actors capped at Probable; Possible matches placed in Unattributed (X) residual bucket without mutating Milestone 4 correlation; NPC actors placed in NPC (N) residual bucket; unobserved killmail participants retained in dedicated footer.
- Defense matchup derivation: each card compares the specific attacker's incoming profile against the pilot's fit defense snapshot (`AarDerivationBundle.self`), calculating layered EHP, omni reference, and primary resist hole. Rejected the averaged EHP fallacy (weighted average of attacker EHPs is mathematically distinct from aggregate EHP).
- Local-only data pipeline: `CombatDamageProfileResolver.resolveIncomingAllocation` with per-distinct-weapon memoization; `CombatFitDerivationService.deriveFitsForEncounter` and `composeMatchups` decoupling fit derivation from damage profile loading; `EffectLookupPolicy.localOnly` on fitting input loading preventing network I/O during snapshot evaluation; single-write concurrency guard in `ensureAttackerCorrelation`.
- Additive prompt v4: `CodexAnalysisClient` adds optional `damageMatchups.perAttackerIncoming` JSON block with rational string numerators/denominators, finite doubles for derived EHP, and updated system instructions recognizing M5 fields without output schema mutations.
- Presentation: `AarIncomingMatchupsSection` and `AarAttackerMatchupCard` providing one unified incoming ranking with stable encounter-scoped expansion state; overview panel with total incoming T, coverage K/T, attributed share, and global U; collapsed aggregate defense reference with blend advisory when positive sources > 1; report-optional Damage tab pre-analysis; responsive 2-column layout for >=720px; zero raw EVE numeric IDs.
**Refs.** LEARNINGS 2026-09-15; DECISIONS 2026-09-15; QUEUED.md; docs/specs/aar-per-attacker-matchup.md; docs/specs/aar-per-attacker-matchup-design.md; .agents/plans/2026-09-14-aar-per-attacker-matchup.md.

### SHIPPED 2026-09-14: Correlate zKill Attackers with Combat-Log Actors

**Author.** Antigravity / Lead Orchestrator
**Shipped as.** Implemented multi-signal correlation between local combat-log actors (`incomingBySource`) and killmail participants (attackers and victim) in Combat Analyzer:
- Bundled category 11 (Entity) type names in SDE with `bundledDogmaVersion = 3` (+0.77 MB asset growth) enabling pure local NPC classification so NPC actors land in NPC buckets and never mistakenly correlate to players.
- Pure domain pipeline: `CombatActorClassifier` (exact normalized matching, class priority: NPC > shipType > ambiguous > player > unnamed), `CombatAttackerCorrelator` with 6 weighted signals (`name: 0.75`, `ship: 0.30`, `weapon: 0.20`, `damage: 0.20`, `timing: 0.15`, `sole: 0.10`), ceilings/caps (`shipType` capped at `probable`), and 0.10 `ambiguityMargin`.
- Strictly enforced damage invariant: `correlatedIncomingDamage + unattributedIncomingDamage + npcIncomingDamage == totalIncomingDamage` (`accountsForAllDamage`).
- Preserved JSON caching integrity: parsed `character_name` and `faction_id` in `EsiKillmailAttacker/Victim.fromJson`, persisting `attackerCorrelation` on `CombatEnrichment`.
- Lazy backfill on cached enrichments: `ensureAttackerCorrelation` in `CombatEnrichmentService` and stage 4 analysis pipeline writes once without hot-looping or failing enrichment.
- D3 opponent identity detail suffix: enumerates correlated attackers and confidence levels with loss fight hulls-known / fits-not-exposed disclaimer, preserving Invariant I1 and score weights.
- Presentation: `AarAttackerCorrelationSection` and `AarAttackerCorrelationBody` with confidence badges, `itemNameProvider` ship resolution, expandable toggle for uncorrelated killmail participants, distinct NPC/unattributed buckets, `AarMatchupSection` blend advisory when $\ge 2$ attackers correlate, and clean replacement of legacy `Incoming Sources` breakdown.
**Refs.** LEARNINGS 2026-09-14; DECISIONS 2026-09-14; QUEUED.md; docs/specs/aar-zkill-attacker-correlation.md; docs/specs/aar-zkill-attacker-correlation-design.md; .agents/plans/2026-09-11-aar-zkill-attacker-correlation.md.

### SHIPPED 2026-09-11: AAR evidence completeness score and pre-analysis checklist

**Author.** Antigravity / Lead Orchestrator
**Shipped as.** Implemented deterministic 0–100 evidence completeness assessment, pre-analysis gate, post-analysis provenance banner, and unified evidence checklist in Combat Analyzer:
- Pure domain scorer `AarEvidenceScorer` and `AarEvidenceAssessment` evaluating five dimensions: Pilot fit (30), Combat log (20), Opponent identity (15), Opponent fit (20), Damage profile (15).
- Invariant I1 (`Missing ⇔ actionable`): dimensions only score `Missing` when actionable CTAs exist; unfixable gaps score `Unavailable` and shrink the denominator (`earned / available * 100`).
- Range is classified as a structural limit (`AarStructuralLimit.range`) because EVE combat logs omit spatial telemetry, keeping it out of the score denominator.
- `CombatEnrichment.killmailSearchCompleted` distinguishes unexecuted search (`Missing` with "Search Killmails" action) from searched-with-no-match (`Unavailable`).
- Report provenance via `CombatAarReport.evidenceAtGeneration` snapshot stored in `analysisJson` without touching prompt schema v4.
- Synchronous `aarEvidenceAssessmentProvider(encounter)` composing enrichment, derivation, and damage profile providers with zero new I/O.
- Presentation widgets: `AarEvidenceChecklistCard` (progress bar, dimension rows with CTAs, known limits, no reload flash via `skipLoadingOnReload`), `AarPreAnalysisGate` (always-enabled button with non-blocking warning/advisory), and `AarReportProvenanceBanner` (provenance comparison and re-analysis advisory on +10 score delta).
- Screen integration in `AnalysisMultiPaneScreen`: retired legacy button cluster and reauth button, wired inline actions for fit attachment, killmail search, and re-analysis.
**Refs.** LEARNINGS 2026-09-11; DECISIONS 2026-09-11; docs/specs/aar-evidence-completeness-score-design.md; .agents/plans/2026-09-11-aar-evidence-completeness-score.md.

### SHIPPED 2026-09-11: AAR fit simulation and defense profile derivation

**Author.** Antigravity / Lead Orchestrator
**Shipped as.** Connected the DogmaEngine to Combat Analyzer for deterministic derivation of EHP, resists, active tank layer, capacitor, speed/sig, and damage matchups for pilot and victim fits:
- Fixed three engine floor defects: E0a (`modAdd`/`modSub` operator 2/3 routed before multipliers and percents so plates and shield extenders add HP), E0b (hull resonances pointed at 113/110/109/111 so DCU II adds 59.8% hull resist and 870.65 EHP), E0c (corrected five wrong skill IDs in `_skillModifiers` table: 3426 CPU, 3413 PG, 3449 Nav, 3418 Cap, 3419 Shield, plus 3416 Shield Operation).
- E1 `DamagePattern` and `LayeredEhp`: pyfa `ehpAgainst(pattern) = hp / Σ p_t(1 - r_t)` per layer; collapses to omni flat-average with 25/25/25/25 while accurately modeling holes.
- E2 active repair and peak shield recharge: modeled burst HP/s across armor ({27, 5275}), shield ({4, 4936}), and hull ({26}) repairers, including Nanite Repair Paste (28668) multiplier (1886) and skill 3393 bonused duration (allowlisted effect 272).
- U1b shared loader: `FittingStatsInputs` and `loadFittingStatsInputs` extracted for single-engine parity between Fitting screen and AAR; `SdeService.getDogmaTypes` enriched with CPU, powergrid, calibration, and slotType.
- Pure `CombatFitDeriver` with two engine calls (evidence fit + bare hull baseline) and `TankClassifier` (active HP/s > buffer gain > unfitted raw HP).
- Relative damage matchup assessment (`resistHole` if resist ≤ 20 or resist ≤ mean − 5; `strongResist` if resist ≥ mean + 5; `appliedPercent` weighted post-resist share; `primaryHole`).
- Pipeline Stage 5/9 "Deriving fit statistics", prompt schema `mimir.combat_aar_input.v4` with `derivedFits` and `damageMatchups`, and persistent `ev-derived-*` ledger facts + specific unknowns.
- Presentation: `AarDerivedStatsPanel`, `AarMatchupSection`, and multipane screen wiring using `.when()`.
**Refs.** LEARNINGS 2026-09-11; DECISIONS 2026-09-11; docs/specs/aar-fit-simulation-and-defense-profiles-design.md; .agents/plans/2026-09-11-aar-fit-simulation-and-defense-profiles.md.

### SHIPPED 2026-09-11: Skill cycle-time bonuses (Rapid Firing, Gunnery, MLO, Rapid Launch, XL specs, missile specialisations)

**Author.** Antigravity / Lead Orchestrator
**Shipped as.** Published skill-owned dogma modifiers routed through DogmaEngine:
Gunnery (effect 414, attr 441, -2%/lvl), Rapid Firing (effect 582, attr 293, -4%/lvl),
MLO & Rapid Launch (effect 1763, attr 293, -2% and -3%/lvl), XL Torpedo & Cruise Spec
(effects 6578/6577, attr 293, -2%/lvl), plus a curated Effect1851 fallback for the
six sub-capital missile specialisations. Multiplicative, unpenalized (owner is skill),
volley unchanged, six-slot direct filter `{182, 183, 184, 1285, 1289, 1290}`, and weapon
cap drain duration falls back to rateOfFire so capacitor stability updates.
**Refs.** LEARNINGS 2026-09-11; DECISIONS 2026-09-11; `.agents/plans/2026-09-11-fitting-completion-skill-rof-and-fighters.md`.

### SHIPPED 2026-09-11: Fighter support (fighter bay, launch tubes, squadron DPS, ability selection, StatsPanel UI)

**Author.** Antigravity / Lead Orchestrator
**Shipped as.** Complete fighter modeling across all layers:
`FighterGroup`, `FighterSquadronStats`, `FighterAbilityKind` Freezed models; EFT parser
distinguishing category 18 (drones) and 87 (fighters) with quantity summing; combat
snapshot and killmail mappers for FighterBay (158) and tubes (159..163); ESI export;
DogmaEngine classification (attr 2215), squadron counts with remainders, launch tube
and class caps (light/support/heavy) enforced in declaration order; Attack (6465) and
missile fallback ability DPS calculation normalized from millisecond durations (attr 2233);
DDA (6556) and FSU (6566) stacking penalties; carrier hull bonus scaling via attribute 280;
StatsPanel OFFENSE row and dynamic `FIGHTERS` section with bay over-capacity error styling.
**Refs.** LEARNINGS 2026-09-11; DECISIONS 2026-09-11; `.agents/plans/2026-09-11-fitting-completion-skill-rof-and-fighters.md`.

### SUPERSEDED 2026-09-11: modifierInfo stops at item boundaries: skill-to-module bonuses are pyfa-hardcoded (2026-09-08)

**Author.** Qwen Code (superseded by Antigravity / Architect 2026-09-11)
**Original premise.** "The SDE's modifierInfo does not publish skill cycle bonuses as
resolvable modifiers... pyfa implements the cross-item part with hardcoded handlers...
derived rules fail."
**Why superseded.** The premise was an artifact of SDE extraction: Category 16 (Skill)
was simply excluded from `generate_dogma_sde.py`'s `TARGET_CATEGORIES`. Once bundled,
CCP's published `LocationRequiredSkillModifier` on skill types resolve directly. Only
effect 1851 (six sub-cap missile specs) and damage effects 660–668/1730 publish empty
modifier lists; all other skill cycle bonuses resolve natively from data.
**Refs.** LEARNINGS 2026-09-11; DECISIONS 2026-09-11.

### SHIPPED 2026-09-08: Cap injectors in the cap simulation

**Author.** Qwen Code
**Shipped as.** CapSimulator injectors ported from pyfa capSim: boosters are
postponed while their gain would overshoot capacity, fire on demand when a
drain cannot be paid, and top the capacitor up after spending; the stability
wrap check now also compares the postponed-injector set. DogmaEngine collects
injectors from fitted cap booster charges (capacitorBonus 67) and adds the
reactivation delay (1795) to every module cycle, like pyfa. Clips are
infinite because fittings carry no charge quantities; reload accounting
remains queued (P3).
**Refs.** LEARNINGS 2026-09-08 cap-injector entry; QUEUED clip reloads.

### SHIPPED 2026-09-08: Drone DPS and drone-domain bonuses

**Author.** Qwen Code
**Shipped as.** Drone pass in DogmaEngine: active drones = in-space count or
fitted count (pyfa-style), capped by ship drone bandwidth (attribute 1272 per
drone); volley = damage components times the drone's damage modifier after
charID-domain bonuses; bay usage from the newly bundled volume attribute 38.
Drone damage amplifiers apply raw, filtered to drones requiring the linked
skill (pyfa Effect6556). Panel gained DRONES bandwidth/bay rows and a Drones
DPS row. Fighters remain queued (P3).
**Refs.** LEARNINGS 2026-09-08 skill-filter entry; QUEUED fighter support.

### SHIPPED 2026-09-08: Model dogma expression trees for bonuses ESI hides

**Author.** Qwen Code
**Shipped as.** Propulsion speed bonuses (effects 6730/6731) via a curated,
cross-checked map (2026-09-07); turret/missile DPS, volley, optimal and
falloff via the SDE's resolved `dgmEffects.modifierInfo` bundled as
`assets/sde/effect_modifiers.json` (2026-09-08). The expression-tree evaluator
itself was never built: `dgmExpressions` is retired in the SDE and the
resolved modifier list supersedes it, skill linkage and group restrictions
included.
**Refs.** LEARNINGS 2026-09-08 modifierInfo entry; DECISIONS 2026-09-08
bundled-modifiers entry.

<!-- First archived entry goes above this line. Keep newest-first. -->
