# AAR Fit Simulation & Defense Profile Derivation — Implementation Plan

## Goal

Connect two finished subsystems that were built to fit together and never joined: derive `FittingStats`/`DefenseProfile` for every `FitEvidence` via the existing `DogmaEngine`, fix three engine correctness gaps, classify tank layer, match incoming damage against real resists, and surface the derived facts and specific unknowns in the AAR pipeline, Codex prompt, and UI. Success is an AAR whose quantitative claims are attributable to a derivation or explicitly labelled unknown (spec §1.2 — the Pathfinder rule).

## Success Criteria

- A `FitEvidence` with ≥1 resolvable module derives `FittingStats` byte-identical to the Fitting module for the same `Fitting` + skill context (one engine).
- Pilot fit with known character uses ESI-cached skills; victim/opponent fit uses All V labelled `assumes All V` with strictly lower `EvidenceConfidence`.
- EHP against a pure-damage profile on a 0/50/50/50 fit equals raw HP; omni (25/25/25/25) equals the current flat-average value — resist-hole claims use the **observed** profile, the summary row keeps the omni label.
- `effectiveArmorRepair`/`effectiveShieldBoost`/`effectiveHullRepair`/`peakShieldRecharge` non-zero when an active module of that layer is fitted; tank layer `Armor (active)` beats a larger shield buffer; reasoning is present in the derived fact.
- `CombatDamageMatchupAnalyzer` has a non-test caller in `lib/`; incoming vs outgoing profiles are distinct; unknown weapons excluded from percentages and surfaced.
- Derived facts (`source=dogmaDerivation`) and specific `AarUnknown`s reach the ledger, `derivedFits`/`damageMatchups` reach the Codex prompt (`mimir.combat_aar_input.v4`), and the multipane screen renders derived stats + matchup with `.when()` and resolves names via `itemNameProvider`.
- `flutter test` (full suite) and `flutter analyze` clean; all new public methods log `[AAR]`/`[COMBAT]`/`[FITTING]`; existing real-SDE parity and production-wiring tests pass unchanged except the three corrected skill IDs (§2.3).
- `QUEUED.md` P1 moved to `ARCHIVE.md` as SHIPPED; `LEARNINGS.md` / `DECISIONS.md` / `QUEUED.md` follow-ups from design §9 applied in the same change set.

## Context And Current Facts

**Sources inspected for this plan:** `docs/specs/aar-fit-simulation-and-defense-profiles.md` (product WHAT, 2026-09-11), `docs/specs/aar-fit-simulation-and-defense-profiles-design.md` (technical HOW, same date, §0 C1–C12 + §2–§9), `lib/features/fitting/domain/dogma_engine.dart` (~1,148 lines at f1225a9: operators 0/4/6 only, `_requiredSkillAttributes={182,183,184}`, hard-coded `_skillModifiers` with five wrong skill IDs, `calculateEhp` flat average, `addModifiers` absent, `effective*` fields never assigned), `lib/features/fitting/domain/dogma_attributes.dart` (no 72/1159/983/796/add attrs, hull resists point at 974–977 not 113/110/109/111), `lib/features/fitting/domain/models.dart` (`DefenseProfile` has `effectiveShieldBoost`/`effectiveArmorRepair` at 0, no `effectiveHullRepair`/`peakShieldRecharge`; `DamagePattern` does not exist), `lib/features/combat_analyzer/domain/combat_damage_matchup.dart` (`analyze` takes `defense` required, absolute resist assessment `≤20`/`≥60`, `_primaryLayer` raw-HP only, no `pattern`/`appliedPercent`/`ehpAgainstPattern`), `lib/features/combat_analyzer/domain/combat_evidence_ledger.dart` (`EvidenceSource` has no `dogmaDerivation`, `AarUnknownCategory` has no `skills`, `FitEvidence.toPromptJson` omits `fighters`), `lib/features/combat_analyzer/data/combat_damage_profile_resolver.dart` (only `resolveOutgoingProfile`, filters `isOutgoingDamage`), `lib/features/combat_analyzer/data/combat_analysis_service.dart` + `codex_analysis_client.dart` (prompt schema `mimir.combat_aar_input.v3`, stageCount 8, no derived fits), `lib/features/fitting/presentation/fitting_providers.dart` (type resolution spread across ~90 lines, no shared loader), `assets/sde/dogma.json` / `effect_modifiers.json` (bundled SDE probed 2026-09-11: `effect 21 op2 263<-72` MSE, `2837 op2 265<-1159` plate, `2302 op0 113<-974` hull DCU, skill effects `446->263`/`490->11`/…).

**Spec conflict resolved:** The product spec (§0 table) says HP/resists/EHP are "already derived" and the work is pure integration. The design doc's probed table (§0 C1–C3) proves the derivation is wrong for every buffer fit and every DCU fit underneath E1–E3, and inserts cheaper, higher-value engine fixes **E0a/E0b/E0c** before E1. This plan adopts the design doc as contract: E0a (operator 2/3 `modAdd`/`modSub`), E0b (hull resonance 113/110/109/111), E0c (five skill IDs) are P0 and gate correctness of every later EHP number. Product spec acceptance IDs are preserved where they survive; design-corrected cases are marked `*`.

**Current pipeline gap (acoustically verified):** `CombatDamageMatchupAnalyzer.analyze` exists and is tested, but its only callers are that test and itself. No file under `lib/features/combat_analyzer/` references `DogmaEngine` or `FittingStats`. `FitEvidence.fitting` objects transit the ledger and never become numbers.

## Constraints And Non-goals

- No clip reloads or ancillary reloads, no overheat, no turret-tracking / missile-application, no projection onto the matchup — queued as P3/follow-up (spec §2.3, design §10).
- No change to `CombatAarReport.version` (stays 3); prompt schema bumps to `v4` only.
- Infinite fighter/missile reloads stay infinite where they are; repair HP/s is single-cycle burst, no reload (design §2.5 limitation carried into the fact).
- No raw EVE IDs rendered — `itemNameProvider` for every `typeId` (CLAUDE.md).
- No new tables; Drift schema unchanged.
- Copy must not invent failures from the discovery the user asked for — file existence, `ls`, DOM, logs, or byte sizes are not evidence of a broken interaction; a bare opener like "test"/"hi" is conversational, not a task.

## Key Decisions

| # | Decision | Choice | Rejected alternative | Why |
|---|----------|--------|----------------------|-----|
| 1 | EHP model | `DamagePattern` (normalised fractions) + `LayeredEhp`; `DefenseProfile.ehpAgainst(pattern)` = `hp / Σ p_t(1−r_t)` per layer (pyfa `calculateEhp`); omni is just `Pattern(.25,.25,.25,.25)` | Keep flat `hp / (1−mean)` | Flat average is not EHP against any real distribution and hides the resist hole the AAR must surface; with `p=.25` the new formula collapses to the old value exactly, so AC2.2 holds for free. |
| 2 | HP-add modifiers | New `addModifiers` map for `op 2/3` on ship attributes, applied as `(base + Σadds) × Πmul × chain(pct)`; `_skillModifiers` appended to `percentModifiers` (+25 at V) sorted/penalised after adds | Keep pre-multiplying `base` by `_skillModifiers` and dropping `op2/3` as unsupported | Plates/extenders publish only as `op2` — dropping them makes every 1600mm plate 0 HP. Pyfa order is adds before percents; pre-multiplying breaks Shield Management + MSE (1,662.5 vs correct 1,937.5). |
| 3 | Hull resonances | Point `DogmaAttributes.hull*Resist` at 113/110/109/111 (`emDamageResonance`… stackable=0) | 974–977 | 974–977 are the DCU's own bonus attrs (stackable=1, never on hulls); ships carry 0.67 at 113/110/109/111 and DCU modifies that address. Rifter bare hull EHP 350→522.39, DCU 870.65. |
| 4 | Skill IDs | 3426 CPU Mgmt, 3413 Power Grid Mgmt, 3449 Navigation, 3418 Cap Mgmt, 3419 Shield Mgmt, 3416 Shield Operation (new) | Table as-shipped | Five IDs are wrong skills (SCIENCE for Engineering etc.); known-skills path is wrong, All-V coincidentally correct. Fix is the three test-ID edits named in §2.3. |
| 5 | Tank classification | `TankClassifier.classify(fit, baseline)` in analyzer domain; rule: active `max HP/s >0` → `argmax(active)` (ties: larger omni EHP → armor>shield>hull); else gain `fitOmniEhp−baselineOmniEhp >0.5` → `argmax(gain)`; else `argmax(omniEhp)` | Raw-HP `_primaryLayer` or role heuristic | Active tank must beat buffer; among buffer fits the investment is gain vs bare hull at same skills (two engine calls — design C12). Known DCU-only → hull(buffer) edge is surfaced via `reasoning` (design §3.2). |
| 6 | Derivation layering | Split pure `CombatFitDeriver` (domain, types injected — testable without DB) + `CombatFitDerivationService` (data, resolves SDE + skills, builds `AarDerivationBundle`) | Single service with DB inside | Keeps `AC1.5/T1.7` purity (no DB/network in domain tests); makes R1.4 "one engine" structural by extracting `loadFittingStatsInputs` from `fittingStatsProvider`. |
| 7 | Shared loader | `lib/features/fitting/data/fitting_stats_inputs.dart` `loadFittingStatsInputs`; SDE `getDogmaTypes` also populates `cpu/powergrid/calibration/slotType` | Duplicate loader per feature | Without it the AAR and Fitting screen can feed the engine different inputs; shared loader guarantees identical parity probe `T9.4b`. |
| 8 | Matchup assessment | Relative rule `hole if resist≤20 || resist≤mean−5`; `strong if resist≥mean+5`; else `neutral`; add `resistPercent?`, `appliedPercent`, `pattern`, `ehpAgainstPattern`, `primaryHole` | Absolute `≤20`/`≥60` only | 34.8% in a 0/20/40/50 fit is the hole by outgoing weight even though above 20% absolute; absolute rule misses S1. New rule keeps existing test green (Kin 70 strong, Exp 10 hole). |
| 9 | Incoming vs outgoing | Add `resolveIncomingProfile` (parameterised existing body) alongside `resolveOutgoingProfile`; self matchup uses incoming, opponent uses outgoing | Single profile | Defense must be measured against the damage it actually took/received; resolver already has the parser data (`weaponName` for both directions). |
| 10 | Persistence model | Merge **facts + unknowns** into the ledger (persisted — what the LLM saw); recompute structured `AarDerivationBundle` live via `aarFitDerivationsProvider` | Persist the bundle | Ledger facts are the auditable LLM input at analysis time; structured bundle must track engine changes, so it stays live. Deterministic `ev-derived-<subject>-<key>-<id>` ids make re-derivation idempotent (§3.1). |
| 11 | Skill basis for unknowns | `AarSkillContext(basis, skills, characterId)` with `knownCharacter` (`confidence=derived`) vs `allFive` (`reference` — strictly lower); victims always `allFive` | Silent All-V | R2/R5.3 (Pathfinder rule): a plausible upper-bound number without its assumption is fabricated data. |
| 12 | Sequencing and TDD gate | U0 → U1+U1b (parallel) → U2 → U3 → U4+U5 (parallel) → U6, with strict **test-author RED before dev GREEN** per unit (see Work Plan) | Big-bang branch | U0 is the correctness floor — if plates/DCU EHP is still zero, every matchup and tank number downstream is fiction; per-unit RED→GREEN keeps the design's `closeTo` values as the first signal, not the last. |

## Recommended Approach

**Fix the floor before widening the building.** E0a/b/c make today's EHP honest; everything else stands on that number. So U0 ships first and alone — the fitting screen benefits even if the AAR wiring slips. Then active repair (U1) and the shared loader (U1b) land in parallel (no file overlap), after which the pure domain layer (U2: deriver + tank + facts + matchup) gates the data layer (U3: service + incoming resolver + enrichment merge + prompt v4), and finally the UI (U4) and journal (U5) run in parallel. U6 is the closing `analyze`+full-test + one manual pyfa spot-check gate. Within **each unit** the work is strictly **TDD: test-author writes intentionally failing tests (RED) → review → dev implements to GREEN**. Implementation work is forbidden until its unit's RED suite exists and is observed failing for the reason named in the test.

This is the order in design §8; the only addition here is the explicit TDD gate per unit.

## Work Plan

Units are **[SEQ] sequential** or **[P1]/[P2] parallel** as in design §8. Each lists (a) failing tests the test-author must land first, (b) dev implementation, (c) gate, (d) owner/area. Code must not be formatted, committed, or pushed during planning.

### [SEQ] U0 — Engine corrections E0a/E0b/E0c + E1 helper

**Tests first (test-author, PENDING → RED).** New/edited files `test/features/fitting/domain/dogma_engine_test.dart` (E0a.1–E0a.6, E0b.1–E0b.2, E0c.1–E0c.3) and `test/features/fitting/domain/damage_pattern_test.dart` (T3.1–T3.6, C.7–C.9). Assert the exact `closeTo` values in §7.1/§7.2 **before** the engine change so the suite fails: `shieldHp 450+1100→1550`, Shield Management V `1937.5 not 1662.5`, hull `522.39`, DCU `870.65/784.31/709.36`, EHP `1000/2000/1600/1538.46`. Gate: `flutter test` shows those cases RED for the reason named, existing suite otherwise green.

**Dev (engineer, RED → GREEN).** `lib/features/fitting/domain/{dogma_engine.dart,dogma_attributes.dart,models.dart,damage_pattern.dart}` per §2.1–§2.4: add `damage_pattern.dart` (`DamagePattern`/`LayeredEhp`/`ehpAgainst` with normalise-to-1 and `denom≤0 → hp` guard), point hull resists at 113/110/109/111, add `addModifiers` + `(base+adds)×Πmul×chain(pct)` finalisation and `shipID` `op2/3` branch, move `_skillModifiers` to `percentModifiers` (temporary — U1 adds Shield Operation and `peakShieldRecharge`), extend `DogmaAttributes` with add ids (72/1159/983/796). Edit three test IDs 3418→3426, 3455→3449, 3425→3419; no other existing assertion changes.

**Gate:** all existing fitting tests green with those three edits; new U0 cases GREEN; `DamagePattern.omni` `totalEhp` parity within `1e-9`.

**Owner:** fitting/domain. **Effort:** Opus.

### [P1] U1 — E2 Active repair + peak recharge

*Depends on U0 (needs add/percent order and hull ids correct). Parallel with U1b.*

**Tests first (RED).** Extend `dogma_engine_test.dart` with E2.1–E2.9 and `test/features/fitting/domain/real_sde_defense_test.dart` with T8.x per §7.1/§7.3. Expect `effectiveArmorRepair 61.333`, Myrmidon + skill 5342/272 `112.444`, SAAR `8.667/26.0`, `peakShieldRecharge 1.8/6.25`. RED requires `DefenseProfile.*Repair` still 0 and hull repair type absent.

**Dev (RED → GREEN).** `dogma_engine.dart` module loop + `models.dart` `DefenseProfile` fields + `dogma_attributes.dart` repair attrs (84/68/83/1886/28668/…); effect-sets `{27,5275}/{4,4936}/{26}`, per-layer burst `amount/(duration/1000)`, ancillary multiplier 1886 when paste 28668 loaded, use `moduleAttr` for both, skip `offline`, add `272 Repair Systems` to allowlist, compute `peakShieldRecharge = 2.5*C/(T/1000)`; add Shield Operation to `_skillModifiers` (design §2.3). Doc: burst, no reload/overheat; limitations carried.

**Gate:** `dogma_engine_test` E2 rows GREEN; `real_sde_defense_test` T8.1–T8.4 GREEN from bundled SDE.

**Owner:** fitting/domain. **Effort:** Opus.

### [P1] U1b — Shared loader + `getDogmaTypes` fill

*Depends on U0 (SDE types needed). Parallel with U1; no file overlap.*

**Tests first (RED).** A loader contract test (or `fitting_stats_production_wiring_test` extension) that calls `loadFittingStatsInputs` vs the inlined provider path and expects equality; plus a `getDogmaTypes` field test asserting `cpu/powergrid/calibration/slotType` populated where U1/U1b is not yet implemented — so `cpu 0` vs real `cpu` is the failure.

**Dev (RED → GREEN).** New `lib/features/fitting/data/fitting_stats_inputs.dart` (`FittingStatsInputs`, `loadFittingStatsInputs` extracted verbatim from `fittingStatsProvider`), refactor `fitting_providers.dart` to call it, merge `fittingSkillTypesProvider` into the loader's `skillTypes`; extend `lib/core/sde/sde_service.dart` `getDogmaTypes` to fill `cpu` (50)/`powergrid` (30)/`calibration` (1153)/`slotType` (effects 12/13/11/2663/3772). No schema migration.

**Gate:** `fitting_stats_production_wiring_test` unchanged and identical output (`T9.4b` equality holds); `loadFittingStatsInputs` returns non-null for Rifter fixture (T1.1).

**Owner:** fitting/data + core/sde. **Effort:** Sonnet.

### [SEQ] U2 — Domain: derivation, tank, facts, matchup (after U0+U1+U1b)

**Tests first (RED).** Four suites landed before any `lib/features/combat_analyzer/domain/` implementation: `tank_classifier_test.dart` (§7.4, T5.1–T5.9/E.10–E.12), `combat_fit_deriver_test.dart` (§7.5 Groups A/B — purity, parity T1.2 frozen equality, coverage, All-V vs known, limitations), `combat_damage_matchup_test.dart` (§7.6 extend — T4.1/4.2/4.7/D.8, D.9/D.10, percent sums to `1.0±1e-6`, `primaryHole`), `aar_derived_facts_test.dart` (§7.7 — fact count/source, unknowns, deterministic ids, allFive label, T7.5 cross-check via `AarDerivedStatsPanel` text walk). Gate: suites compile against the spec'd class shapes but fail because classes/methods are absent or return stubs.

**Dev (RED → GREEN).** Implement `lib/features/combat_analyzer/domain/{aar_fit_derivation.dart,tank_classifier.dart,combat_fit_deriver.dart,aar_derived_facts.dart}` and `damage_pattern_x.dart`, plus edits to `combat_damage_matchup.dart` (nullable `defense?`, `TankAssessment?` param, relative assessment, `appliedPercent`/`primaryHole`/`pattern`/`ehpAgainstPattern`/`ehpOmni`, JSON nullability) and `combat_evidence_ledger.dart` (`EvidenceSource.dogmaDerivation`, `AarUnknownCategory.skills`, `FitEvidence.toPromptJson` `fighters` line) per §3.1–§3.6. `TankClassifier` rule verbatim §3.2 (with `_minGainEhp 0.5`); `CombatFitDeriver.derive` two engine calls (fit + bare hull), limitations list, `[AAR.DERIVE]` logs; `AarDerivedFactsBuilder.facts/unknownsFor` with deterministic `ev-derived-<subject>-<key>-<encounterId>` ids. `build_runner` for freezed additions.

**Gate:** all four suites GREEN; existing `combat_damage_matchup_test` still byte-identical (D.8 checks preserve it); `AarDerivedStatsPanel` text walk (T7.5) matches fact values.

**Owner:** combat_analyzer/domain. **Effort:** Opus.

### [SEQ] U3 — Data: service, incoming resolver, enrichment merge, pipeline, prompt v4 (after U2)

**Tests first (RED).** `combat_fit_derivation_service_test.dart` (service RED: `AarFitDerivationFailed` vs struct field), `combat_damage_profile_resolver_test` incoming case (Scourge Rocket + Mystery Gun), `combat_enrichment_service_test` (attach idempotence G.7), `combat_analysis_service_test` (prompt captures `mimir.combat_aar_input.v4` + ledger facts + stage label) per §7.6/§7.8 — fail because `resolveIncomingProfile`/`deriveForEncounter`/`attachDerivedEvidence` missing and `analyzeEncounter` still 8 stages/v3.

**Dev (RED → GREEN).** `lib/features/combat_analyzer/data/{combat_fit_derivation_service.dart` (`skillContextFor` with `app_database.CharacterSkill` prefix mapping + `getAllSkills→All V` cached, `deriveEvidence` via `loadFittingStatsInputs`, `deriveForEncounter` bundle with self→incoming/opponent→outgoing + subject resolution §3.1, `evidence ledger notitiation`), `combat_damage_profile_resolver.dart` (`resolveIncomingProfile`/`combatIncomingDamageProfileProvider`, parameterised `_resolve` per C4), `combat_enrichment_service.dart` (`attachDerivedEvidence` + `_mergeLedgers` dedup by `(category,label)` + remove `skills` category), `combat_analysis_service.dart` (stage 5/9 Deriving, new ctor deps), `codex_analysis_client.dart` (`mimir.combat_aar_input.v4` with `derivedFits`/`damageMatchups` + system prompt rules §4.5), `combat_providers.dart` (`aarFitDerivationsProvider`) per §4.2–§4.6.

**Gate:** data suites GREEN; `T9.1` non-test caller grep passes; `T9.2` end-to-end prompt capture shows `v4` + one `derivedFits` entry + `ev-derived-*` facts; `T9.3` survives no-fit evidence.

**Owner:** combat_analyzer/data. **Effort:** Opus (prompt rules) + Sonnet (resolvers).

### [P2] U4 — UI panel + matchup section + screen wiring (after U3)

*Parallel with U5.*

**Tests first (RED).** `test/features/combat_analyzer/presentation/aar_derived_stats_panel_test.dart` (§7.9) with `ProviderScope` overrides — expect panel text `EHP (omni)`/`Tank` chip/`Stable 41%`, loading/error states via `.when`, empty-bundle no-panel, both-roles two panels, `assumes All V` badge, `itemNameProvider → Rifter`, unknown-defense `Resist profile unknown`. RED because widgets/providers not yet wired.

**Dev (RED → GREEN).** `lib/features/combat_analyzer/presentation/widgets/aar_derived_stats_panel.dart` + `aar_matchup_section.dart` + `analysis_multipane_screen.dart` edits per §5.1–§5.3: skill badge amber vs neutral, `EveTypeIcon` + `itemNameProvider.when`, DEFENSE/CAPACITOR/OFFENSE/MOBILITY/footer sections, matchup rows colour + applied share + header `EHP vs incoming / omni / layer`, `aarFitDerivationsProvider.when` (never `.value ??`), placeholder + error card, `[COMBAT.UI]` logs, no `.value ?? default`.

**Gate:** UI suite GREEN; T7.5 fact↔UI value walk passes; no bare opener like `"test"` is treated as a fitting task.

**Owner:** combat_analyzer/presentation. **Effort:** Sonnet.

### [P2] U5 — Journal (after U3, parallel with U4)

**Tests:** none — verified by file content review.

**Dev.** `docs/engineering-journal/{ARCHIVE,LEARNINGS,DECISIONS,QUEUED}.md` per design §9: move QUEUED P1 to `ARCHIVE` as SHIPPED, add LEARNINGS entries (flat-average EHP hides holes; `modAdd` silently ignored plates/extenders → surface unsupported operators; hull 113/110/109/111 vs 974–977; five wrong skill IDs because tests copied the table not the SDE), `DECISIONS.md` entry for derivation layering + tank rule + shared loader, `QUEUED.md` follow-ups (tracking/application, LLM prompt regression, retire `_skillModifiers`, compensation-skill second-order bonuses, ancillary reload/overheat, `dogmaVersion` on facts). Must land in the same change set (AGENTS.md).

**Gate:** journal files reviewed; `QUEUED.md` P1 gone; ARCHIVE entry cites this plan's commit.

**Owner:** docs/engineering-journal. **Effort:** Sonnet.

### [SEQ] U6 — Closing gate

**Dev.** `flutter analyze` clean, full `flutter test` green, `dart format .`. One manual spot-check if pyfa/in-game access exists: Rifter + MSE II + Shield Management V EHP/recharge vs bundled recompute (design §2.1 → `1937.5`), otherwise record `spec R3` limitation in LEARNINGS.

**Gate:** `analyze` + `test` evidence pasted into HANDOFF; LEARNINGS notes manual check done or deferred; `CombatAarReport.version` still 3.

**Owner:** repo root. **Effort:** verification.

## Validation Plan

Each unit's TDD gate is **RED before GREEN** — implementation is blocked until its unit's test-author suite is observed failing for the reason named.

| Unit | RED suite (test-author lands first) | GREEN implementation check | Exact command / expected evidence |
|------|--------------------------------------|----------------------------|-----------------------------------|
| U0 | `damage_pattern_test` T3.1–T3.6/C.7–C.9 + `dogma_engine_test` E0a.1–E0a.6/E0b.1–E0b.2/E0c.1–E0c.3 — fail: `1550 vs 450`, `1937.5 vs 1662.5`, `522.39 vs 350`, `ehpAgainst not found` | Engine + pattern | `flutter test test/features/fitting/domain/damage_pattern_test.dart test/features/fitting/domain/dogma_engine_test.dart` → all RED→GREEN; `flutter test test/features/fitting/domain/real_sde_defense_test.dart --run-skipped` (not yet; U1 adds file) fails to find module; `flutter test` otherwise GREEN with the three ID edits only |
| U1 | Same `dogma_engine_test` E2.1–E2.9 + `real_sde_defense_test` T8.1–T8.4 — fail: `effectiveArmorRepair 0 vs 61.333`, `peakShieldRecharge 0` | Repair + peak | `flutter test test/features/fitting/domain/dogma_engine_test.dart` (E2 filter) + `flutter test test/features/fitting/domain/real_sde_defense_test.dart` → GREEN; `T8.3` cap stability matches in-test `CapSimulator` with `400/11250ms` |
| U1b | Loader equality test + `getDogmaTypes` cpu/pg/cal/slotType — fail: `cpu 0 vs 15` etc. | Shared loader | `flutter test test/features/fitting/presentation/fitting_stats_production_wiring_test.dart` → still GREEN and `T9.4b` equality future (U3) not yet; `loadFittingStatsInputs` returns identical map to inlined provider path |
| U2 | `tank_classifier_test` T5.1–T5.9/E.10–E.12 + `combat_fit_deriver_test` A/B + `combat_damage_matchup_test` T4.1/4.2/4.7/D.8–D.10 + `aar_derived_facts_test` T7.1–T7.4/G.6 — fail: class/method not found, `primaryHole null`, `appliedPercent null` | Domain | `flutter test test/features/combat_analyzer/domain/tank_classifier_test.dart test/features/combat_analyzer/domain/combat_fit_deriver_test.dart test/features/combat_analyzer/domain/combat_damage_matchup_test.dart test/features/combat_analyzer/domain/aar_derived_facts_test.dart` → all RED→GREEN; existing matchup test unchanged |
| U3 | `combat_damage_profile_resolver_test` incoming + `combat_fit_derivation_service_test` T9.* + `combat_enrichment_service_test` G.7 + `combat_analysis_service_test` T9.2/9.3 prompt CAPTURE — fail: `resolveIncomingProfile not found`, `v4 not found`, `Deriving fit statistics` not in progress labels | Data + prompt v4 | `flutter test test/features/combat_analyzer/data/combat_fit_derivation_service_test.dart test/features/combat_analyzer/data/combat_analysis_service_test.dart test/features/combat_analyzer/domain/combat_damage_profile_test.dart` → GREEN; grep `lib/features/combat_analyzer/data/combat_fit_derivation_service.dart` for `CombatDamageMatchupAnalyzer.analyze(` (T9.1) |
| U4 | `aar_derived_stats_panel_test` T10.1–T10.7/J.8 + T7.5 — fail: widget not found, `.value ??` still present | UI | `flutter test test/features/combat_analyzer/presentation/aar_derived_stats_panel_test.dart` → GREEN; `flutter test test/features/combat_analyzer/domain/aar_derived_facts_test.dart --name T7.5` → fact values contain every panel text |
| U5 | — (docs review) | Journal | `git diff --stat docs/engineering-journal/` shows `QUEUED.md` P1 removed, `ARCHIVE.md` SHIPPED, `LEARNINGS.md` E0/E1/E2/E3 entries |
| U6 | — | Closing | `flutter analyze` clean; `flutter test` full suite GREEN; HANDOFF pastes both logs + manual check note |

**Highest-risk validation:** real-SDE `T8.1–T8.4` (bundled `dogma.json` recompute) and `T1.2`/`T9.4b` parity — if `op2` routing or hull IDs are off by one, every derived EHP, tank gain, and matchup `ehpAgainstPattern` downstream is silently wrong and only these tests fail.

## Risks / Rollback

- **E0a order bug (U0).** Adds before percents vs after is 1,937.5 vs 1,662.5 for MSE+Shield Mgmt V — the discriminating case. *Mitigation:* E0a.2 locks the order; rollback to pre-add multiply breaks only the adds-cases.
- **Hull ID churn (U0 E0b).** 113/110/109/111 vs 974–977 touches `_nonStackableAttributes`. *Mitigation:* E0b.2 DCU II locks hull `59.8%/870.65`; old 974 hull stays 0% with DCU.
- **Skill ID churn (U0 E0c).** Only three existing assertions change (3418→3426, 3455→3449, 3425→3419); E0c.2 locks that wrong IDs do nothing. Rollback: revert three lines.
- **Fallback in matchup (U2).** `_primaryLayer` stays as `defense`-only fallback so the existing matchup test is untouched; new path is gated on `TankAssessment?` param presence.
- **Provider keying (U3).** `aarFitDerivationsProvider` keyed by `ParsedCombatEncounter` identity like `combatDamageProfileProvider`; screen holds one instance. Rollback: provider returns `AarDerivationBundle.empty()` with unknowns.
- **Ledger dedup (U3).** `_mergeLedgers` dedup by `(category,label)` + skills-category purge prevents fact/unknown duplication on re-analysis; PATHOLOGY is a second run doubling the `skills` unknown.
- **Prompt versioning (U3).** Bump `mimir.combat_aar_input.v3→v4` is additive; `CombatAarReport.version` stays 3 (output unchanged); old enrichments without `v4` fields still load via `fromJson` fallbacks (C6/C10).
- **Second-order module bonuses (not in U0–U3).** Compensation skills modify 984–987 which `routeOwnerModifiers` reads raw — queued as follow-up P2; no silent mis-calculation in buffer-only fits.

## Open Questions

None after local discovery — every question in spec §7 was answered by the design doc §3–§4 contracts and the probed SDE tables. Remaining intent check is the manual pyfa/in-game spot-check of Rifter+MSE II EHP (spec R3) in U6; until it runs, LEARNINGS carries the `No ground truth` limitation already recorded for the fitting milestone.

---
*Plan file:* `.agents/plans/2026-09-11-aar-fit-simulation-and-defense-profiles.md` — canonical body is the reply above. Reviewer prompts: verify `addModifiers` evaluation order `(base+adds)×mul×pct`, hull IDs 113/110/109/111, and matchup `appliedPercent` vs `percent`.
