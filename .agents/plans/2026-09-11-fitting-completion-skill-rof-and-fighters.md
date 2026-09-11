# Fitting Module Completion — Implementation Plan

## Goal

Finish the Fitting module's simulation fidelity by shipping two queued gaps as one feature:

1. **Skill cycle-time bonuses** — Gunnery, Rapid Firing, Missile Launcher Operation, Rapid Launch, XL specs, and the six sub-capital missile specialisations (QUEUED P2).
2. **Fighter support** — bay, launch tubes, per-class caps, squadron DPS, and ability modelling (QUEUED P3, promoted to P2 by spec).

Success is measured by DPS/cap parity with pyfa and bundled SDE data within rounding, plus a non-blank capital offense panel.

## Success Criteria

- Turret and launcher cycles shorten at the trained skill level via published dogma modifiers, not hard-coded constants; volley unchanged.
- Rifter/Tristan and carrier fits evaluated at all-V match an independent recompute from bundled `dogma.json` / `effect_modifiers.json` attributes to `closeTo(0.01)`.
- Carrier fit (Thanatos/Nyx) renders `dpsFighters`, `fighterBayUsed/Max`, `fighterTubesUsed/Max`, and per-class usage; `dpsTotal` sums once; drone stats bit-identical.
- Non-carrier hulls render no fighter section; over-bay-capacity shows used/max in error colour without truncating DPS.
- `flutter test` and `flutter analyze` clean; every new public method logs `[DOGMA]`/`[FITTING]`/`[SDE]` per `CLAUDE.md`.
- `docs/engineering-journal/QUEUED.md` entries moved to `ARCHIVE.md` as SHIPPED, `LEARNINGS.md` 2026-09-08 corrected inline, old text to `ARCHIVE.md` as SUPERSEDED.

## Context And Current Facts

**Sources inspected for this plan:** `docs/specs/fitting-completion-skill-rof-and-fighters.md` (product spec, WHAT), `docs/specs/fitting-completion-skill-rof-and-fighters-design.md` (architecture + contracts, HOW), `lib/features/fitting/domain/dogma_engine.dart` (401-line engine: `shipID`/`charID` routing, `modulePercent`/`chargePercent` stacking, `shipSkillLevel` from single required-skill slot, `capDrains`/`capInjectors`), `lib/features/fitting/domain/dogma_attributes.dart` (48 constants, no fighter attrs), `lib/features/fitting/domain/models.dart` (`Fitting`/`FittingStats`/`ShipType`/`ModuleType` — no fighter fields), `lib/core/sde/sde_service.dart` / `sde_database.dart` (schema v6, `initialize()` gates on `hasDogmaData()`, `getModuleType` does 4-5 queries, `ensureEffectModifiers` merges bundled + Drift + ESI), `scripts/sde/generate_dogma_sde.py` (`TARGET_CATEGORIES = {6,7,8,18,20,22,32}`, parses `dgmEffects.modifierInfo`), `lib/features/fitting/presentation/fitting_providers.dart` (`fittingStatsProvider` resolves module/charge/drone types one-by-one, builds `effectIds` from `moduleTypes` only), `test/features/fitting/domain/dogma_engine_test.dart` / `real_sde_weapon_test.dart` (existing fixture pattern), `docs/engineering-journal/QUEUED.md` and `LEARNINGS.md` (2026-09-08 entries gated skill-ROF on a pyfa cross-check and claimed no data-driven filter).

**Spec conflict resolved:** The product spec's §0 (transitive `requiresSkill` closure over 15 `rofBonus` skills, 18 turrets transitive, bay 908 / tubes 1547, fighter attack via 2128 s / 2131..2134 / 2226, DDA does not apply) is **superseded** by the design doc's §0 corrections C1–C10, which were verified against raw fuzzwork CSVs and pyfa master on 2026-09-11:

- C1/C2/C3: Published `LocationRequiredSkillModifier` on skill types themselves (effects 582, 414, 1763, 6577/6578) already filter correctly; only effect 1851 (six sub-capital missile specs) is empty and needs one curated supplement. All 780 published weapons require Gunnery or MLO directly via the six slots `{182,183,184,1285,1289,1290}` — zero transitive-only.
- C4: Gunnery adds turret cycle via attr 441 (`-2%/lvl`, effect 414); all-V turret cycle is `×0.72` (Gunnery ×0.90 × Rapid Firing ×0.80), not ×0.80.
- C5/C6: Correct fighter attrs are `2055` bay, `2216` tubes, `2217/2218/2219` caps; attack DPS uses `2227..2230` / `2226` / `2233 ms` (not 2128/2131).
- C7/C8: DDA 6556 **does** boost fighters (penalised `charID` on 2226/2178/2130 via 1255, filter 23069); fighter skills + hull bonuses (6560, 6563, 6570, 6663, 12844..12848, 6601 etc.) are published `charID`/`shipID` modifiers — include them, or understate Thanatos ~2.3×.
- C9/C10: Squadron sizes vary (3/6/9/12); bay over-capacity reports used/max, no truncation, no `FittingError` mechanism.

This plan follows the design doc as the implementation contract and marks the product spec's superseded clauses in the journal/spec update step.

**Current engine gaps that block correctness:**
- `TARGET_CATEGORIES` excludes 16 (Skill) and 87 (Fighters) — so skill effects and all 94 fighter types are absent from `dogma.json` and `effect_modifiers.json`; `_skillModifiers` hardcodes seven ship attrs instead of routing published modifiers.
- `SdeService.initialize()` never re-imports dogma on existing installs (`hasDogmaData()` true → skip).
- `DogmaEngine._requiredSkillAttributes = {182,183,184}` missing `1285/1289/1290`; `shipSkillLevel` reads first slot only; `modulePercent`/`chargePercent` penalise every percent or none, not per-owner.
- No `getDogmaTypes` batch loader — skill routing would need ~500 queries per character.
- `Fitting`/`FittingStats` have no fighter fields; `StatsPanel`, EFT/ESI parsers, and snapshot/killmail mappers know nothing about fighters.

## Constraints And Non-goals

- No live ESI or in-game spot check required to ship; parity tests verify internal consistency against bundled SDE (spec R5 — record limitation in LEARNINGS).
- Infinite fighter reloads and infinite cap clip reloads in v1; shot/rearm tables recorded for queued work.
- No fighter/drone editing UI in the fitting editor — import/snapshot/killmail only; flag in QUEUED.
- No `dgmAttributeTypes.stackable` bundling in v1 — owner kind decides penalised vs unpenalised (design §1.4 shim).
- Must not change meaning of existing `FittingStats` fields; existing tests pass unmodified (if one needs editing, treat as regression).
- No raw EVE IDs rendered — names via existing providers.

## Key Decisions

| # | Decision | Choice | Rejected alternative | Why |
|---|----------|--------|----------------------|-----|
| 1 | Filter model for skill cycle bonuses | Direct `requiresSkill` over six slots `{182,183,184,1285,1289,1290}` routed from published `LocationRequiredSkillModifier` / `OwnerRequiredSkillModifier` | Product spec's transitive closure over `skill→skill` prerequisites | Raw SDE sweep shows 0 transitive-only weapons; design C3 proves six-slot direct check matches dogma's `LocationRequiredSkillModifier` and pyfa's `Item.requiredSkills`. |
| 2 | Gunnery cycle bonus scope | Include effect 414 (`51 <- 441`, Gunnery) alongside 582 (Rapid Firing) | Product spec R1.1-only (Rapid Firing) | Bundled data: Gunnery carries `turretSpeeBonus` 441, not 293; omitting it understates all-V turret DPS by 38.9% vs 20% (C4). |
| 3 | Six missile specialisations with empty effect 1851 | One curated `EffectModifier` per skill (mirror 6577/6578 shape, `func LocationRequiredSkillModifier`, op 6, `51 <- 293`, `skillTypeId = owner`), applied only when bundled modifier list is empty | Hardcoding per-group logic or deriving from skill's own 182/183 | Empty `modifierInfo` is exactly where pyfa hardcodes `Effect1851: filteredItemBoost(requiresSkill(skill), 'speed', ...)`. Curated supplement matches `_expressionTreeSpeedEffects` pattern and is skipped when CCP publishes modifiers. |
| 4 | Stacking penalty | `_Bonus(factor, penalized)` buckets; evaluation: product of unpenalised × penalised>1 chain × penalised<1 chain with `exp(-(i/2.67)^2)`; penalised iff owner is fitted module/charge/drone/fighter; ship/skill-owned never penalised | Per-attribute `stackable` flag or penalising every percent | Owner kind matches pyfa `boost`/`multiply` defaults (`stackingPenalties=False` for ship/skill, `True` for module handlers like 6556/763/91); attribute `stackable` not yet bundled (follow-up in §7). Makes heat sinks/BCS/DDAs correctly penalised without extra data. |
| 5 | Ship bonus scaling | `bonusScale` map from ship's required skills (six slots) whose `skillTypes` carry `shipID/ItemModifier/280 <- ...`; ship-owned modifier value = `base × bonusScale[modifyingAttributeId]` | First-slot `shipSkillLevel` | First-slot scaling breaks carriers (182 = Capital Ships, 183 = racial carrier skill) and role bonuses. SDE encodes scaling explicitly via skillLevel attr 280 (C5). Compatibility shim: empty `skillTypes` → old rule, debug log. |
| 6 | Fighter representation | Distinct `FighterGroup {typeId, typeName, quantity, inSpace}` + `FighterSquadronStats` + `FighterAbilityKind` enum; `Fitting.fighters` list; `FittingStats` additions (`dpsFighters`, `fighterBayUsed/Max`, `fighterTubesUsed/Max`, per-class used/max, `fighterSquadrons`) | Reuse `DroneGroup` | Drones are bandwidth + bay-volume single units; fighters are squadron-count × size, tube-limited, ability-based, separate bay. Overloading `DroneGroup` is what makes R2.4 fragile (design R3). |
| 7 | Fighter ability selection | Pyfa parity: if 6465 `attack` exists, only attack DPS; else every damage ability except bomb/kamikaze; ability table curated by effect id, missile/bomb charges via 2324 | Model only attack | Gram (missiles-only) and 5 bomb-capable heavies would report 0 DPS incorrectly; ability effects publish no `modifierInfo`, so effect-id allowlist is the pyfa pattern. |
| 8 | Data gating | Bump `SdeService.bundledDogmaVersion = 2`, `SdeMetadata` key `dogma_version`; `initialize()` re-imports when `!hasDogmaData || getMetadata('dogma_version') != '$bundledDogmaVersion'` | Always re-import on launch | Idempotent upserts + version key gives deterministic migration without wiping user data; required because `hasDogmaData()` alone would strand existing installs without categories 16/87. |
| 9 | DDAs and fighter bonuses | Apply DDA 6556 and FSU 6566 as penalised `charID` on fighters; hull bonuses (6601 etc.) and fighter skills (6560/6563/12844…/6663/6570) via existing `charID`/`shipID` routing — no new engine branch | Product spec R2.6 exclusion | Design C7-C8: published modifiers exist and pyfa applies them; excluding them needs extra guard code and understates carriers ~2.3×. |

## Recommended Approach

**Phase data → engine core → skill bonuses + fighter I/O in parallel → fighter engine + UI → journal/spec closeout.** Land as one integration but keep the commit discipline below so `U0`/`U1` can be reviewed independently and `U2`/`U3` verified in parallel.

1. **Expand bundled SDE and its version gate** before any engine change — every later parity test depends on the real attributes being present.
2. **Harden the DogmaEngine core** (six-slot filter, `_Bonus` buckets, `bonusScale`, `getDogmaTypes`) as a pure-addition change that keeps all existing tests green via the fixture shim.
3. **Route skill-owned cycle bonuses through the existing modifier machinery** behind an allowlist + curated 1851 supplement, exposed via a new `fittingSkillTypesProvider` that `fittingStatsProvider` watches.
4. **Ship fighter types the same way** — `FighterGroup` on `Fitting`, bay/tube/ability contracts, EFT/ESI/killmail mappers — isolated from the engine so `U3` tests don't need `DogmaEngine`.
5. **Engage the fighter DPS path** inside `calculateStats` (`charID` target ids, tube/class activation, attack vs missiles, `dpsFighters` accumulation) and surface it in `StatsPanel`.
6. **Close the loop** by correcting `LEARNINGS.md`/`docs/specs/` and moving `QUEUED.md` → `ARCHIVE.md` in the same change set (AGENTS.md journal rule).

This order minimizes rework: `U0` unblocks `U1`–`U4` tests; `U1`’s shim lets `U2` land without touching fixture tests; `U3` is independent of `U1`; `U4` is the only step that touches both worlds.

## Work Plan

### [SEQ] U0 — Data: bundle skills + fighters, version gate, batch loader

**Owner:** `scripts/sde/generate_dogma_sde.py`, `assets/sde/dogma.json` + `effect_modifiers.json`, `lib/core/sde/sde_service.dart`, `lib/core/sde/sde_database.dart`

- `generate_dogma_sde.py`: `TARGET_CATEGORIES += {16, 87}`; keep existing shape. Regenerate and commit artefacts. Cost ≈ +0.6 MB on `dogma.json` (511 skill types + 94 fighter types; effect ids 582/414/1763/1851/6560/6563/6570/6663/12844.. + 6465/6431/6485 now in `referenced_effects`/`effect_modifiers.json`; 1851 and ability effects present with empty `modifiers` list but name). Verify `dogma.json` contains `categoryId 16` and `87` groups and `effect_modifiers.json` keys for the allowlist.
- `sde_service.dart`: add `static const int bundledDogmaVersion = 2` + doc, add `SdeMetadata` key `dogma_version` handling, change `initialize()` to `if (!hasDogmaData || getMetadata('dogma_version') != '$bundledDogmaVersion') await _loadBundledDogma()` then `setMetadata('dogma_version', '$bundledDogmaVersion')`. `import` path: `_importSdeData` upserts with `insertAllOnConflictUpdate` — skills seeded earlier from `skills.json` must retain `rank`/`primaryAttribute`/`secondaryAttribute` (only set present columns). Document re-import as idempotent.
- `sde_service.dart` / `sde_database.dart`: add `Future<Map<int, ModuleType>> getDogmaTypes(Iterable<int> typeIds)` — 3 queries total (`types` + `attributes` + `effects`, each `WHERE typeId IN (…)`) chunked at 500 ids, returning `ModuleType` with `slotType: high`, `cpu/powergrid/calibration: 0`, `skillRequirements: []`, missing ids absent from result. Helper `getGroupIdsForTypes` chunking pattern already exists.
- Drift: no new tables; `SdeMetadata` already exists (schema v6) — add `dogma_version` row only.

**Depends on:** none. **Blocks:** U1–U4.

### [SEQ] U1 — Engine core: filter, buckets, scaling, signature

**Owner:** `lib/features/fitting/domain/dogma_engine.dart`, `lib/features/fitting/domain/dogma_attributes.dart`, `lib/core/sde/sde_service.dart`

- `dogma_attributes.dart`: add fighter + skill attrs from design §3.2 (`fighterCapacity` 2055, `fighterTubes` 2216, light/support/heavy slots 2217/2218/2219, `fighterSquadronMaxSize` 2215, `fighterSquadronIsLight/Support/Heavy` 2212/2213/2214, `fighterSquadronRole` 2270, attack 2226/2227..2230/2233, missiles 2130/2131..2134/2182, bomb 2324/2349, `fighterRefuelingTime` 2426). Add `skillLevel` 280, `turretSpeeBonus` 441, `rofBonus` 293, `fighterDamageMultiplier` aliases as needed.
- `dogma_engine.dart`: expand `_requiredSkillAttributes = {182,183,184,1285,1289,1290}`; add `requiresSkill(ModuleType, int)` helper used by every `Location*`/`Owner*` filter.
- Introduce `class _Bonus { final double factor; final bool penalized; }`; change `modulePercent`/`chargePercent`/`moduleMul`/`chargeMul` to `Map<int, Map<int, List<_Bonus>>>`.
- Rewrite `moduleAttr`/`chargeAttr` evaluation exactly as design §1.4: `value = base × product(unpenalised) × chain(penalised>1) × chain(penalised<1)` where each chain sorts `|f-1|` descending and multiplies `1 + (f-1) × exp(-(i/2.67)^2)` (`getStackingPenalty(i+1)`). Ship-level `percentModifiers`/`mulModifiers` keep current twelve-resonance rule; no penalty flag in this increment.
- Add `bonusScale: Map<int,double>` built from ship's six-slot required skills whose types are in `skillTypes` and whose modifiers carry `shipID/ItemModifier/modifiedAttribute + modifyingAttribute 280` (op 0/4). Then `ship-owned modifier value = base × (bonusScale[modifyingAttributeId] ?? 1.0)`. Compatibility shim: when `skillTypes` empty (hand-built fixtures), fall back to existing `shipSkillLevel` and `Log.d('DOGMA', 'using legacy shipSkillLevel fallback …')`; new tests pass skillTypes.
- Extend `calculateStats` signature with optional named param `Map<int, ModuleType> skillTypes = const {}`; pure addition — all existing call sites compile. Route owner modifiers via shared helper `routeOwnerModifiers(..., ownerIsShip, penalized)` respecting `_Bonus.penalized`.
- Add debug logging per `CLAUDE.md`: entry/params at `Log.d('DOGMA', …)` for `calculateStats`; per-skill modifier line `Log.d('DOGMA', 'Skill <id> L<level> effect <effectId>: <attr> op<op> <value> -> <n> targets')` and summary of ignored skill effects.

**Depends on:** U0 (skill types/attrs present, but tests can also pass synthetic `skillTypes` map). **Blocks:** U2, U4. Keeps existing `dogma_engine_test.dart` green unmodified via shim.

### [P1] U2 — Skill cycle-time bonuses (allowlist + curated 1851 + provider)

**Owner:** `lib/features/fitting/domain/dogma_engine.dart`, `lib/features/fitting/presentation/fitting_providers.dart`, `assets/sde/effect_modifiers.json` (already from U0)

- `dogma_engine.dart`: add `static const Set<int> skillEffectAllowlist = {414,582,1763,6577,6578,6560,6563,6570,6663,12844,12846,12847,12848}` gated to cycle work (+ fighter skills for U4 — split allowlist constant if preferred) and `Map<int, List<EffectModifier>> _curatedSkillModifiers` for the six 1851 entries (owner skills `20209,20210,20211,25718,20212,20213` → `EffectModifier(effectId:1851, func:'LocationRequiredSkillModifier', operator:6, modifiedAttributeId:51, modifyingAttributeId:293, domain:'shipID', skillTypeId: owner)`). Routing in `calculateStats`: for each `skillTypes[typeId]` with `level = clamp(L,0,5) > 0`, compute `skillValue(attr) = type.baseAttributes[attr] × level` (and 280 = level), iterate its effects, skip if `effectId ∉ allowlist` (count for summary), look up `effectModifiers[effectId]` otherwise (`_bundled` or curated fallback when empty), feed to `routeLocationModifier` with `ownerIsShip:false, penalized:false` (skill-owned never penalised).
- Curated guard: if bundled modifier list for 1851 on a given skill is non-empty, do **not** apply curated entry (design C2).
- `fitting_providers.dart`: add `fittingSkillTypesProvider = FutureProvider<Map<int, ModuleType>>` — ids = `trainedSkillsProvider` (level>0) `∪` `shipType.baseAttributes` over six slots filtered where value != null → `sde.getDogmaTypes(ids)` (cached by Riverpod). Extend `fittingStatsProvider` to: watch `fittingSkillTypesProvider`, resolve fighter types + bomb charge 2324 into `moduleTypes`, union all effect ids (modules + charges + drones + fighters + skillTypes) for `ensureEffectModifiers`, pass `skillTypes` to `engine.calculateStats`. Document provider dependencies.
- Technical standard: no closing tag in work plan; original mod is `</select>`; fix in code.

**Depends on:** U0 + U1 (independent of U3). **Validated by:** §4.1 + §4.3 parity T1.20/T1.21/T1.26/T1.27 + production wiring T1.22.

### [P1] U3 — Fighter models, parsers, mappers, export

**Owner:** `lib/features/fitting/domain/models.dart` (+ generated), `lib/features/fitting/domain/format_parser.dart`, `lib/features/combat_analyzer/domain/combat_fit_snapshot_mapper.dart`, `lib/features/combat_analyzer/domain/combat_killmail_fit_mapper.dart`, `lib/features/fitting/domain/esi_fitting_export.dart`, `lib/core/sde/sde_database.dart` (read-only helpers)

- `models.dart`: add `FighterGroup {typeId, typeName, quantity, inSpace=0}`, `fighterAbilityKind` enum (13 kinds), `FighterSquadronStats {typeId, typeName, squadronSize, squadrons, activeSquadrons, abilities, activeAbility?, dps}`, extend `Fitting` with `@Default([]) List<FighterGroup> fighters`, extend `FittingStats` with `dpsFighters`, `fighterBayUsed/Max`, `fighterTubesUsed/Max`, `fighterLightUsed/Max`, `fighterSupportUsed/Max`, `fighterHeavyUsed/Max`, `fighterSquadrons`. Run `dart run build_runner build`.
- `format_parser.dart`: EFT `parseEft` — per-line `^(.+?) x(\d+)$` whose resolved type is category 18 → `DroneGroup`, category 87 → `FighterGroup`; merge same-type lines by summing quantity; also fix pre-existing silent drop of `Hobgoblin II xN`. `generateEft` — after rigs blank line, drone lines, blank line, fighter lines `Name xN` (pyfa order light/heavy/support). Category from `database.getGroup(groupId).categoryId`; need `getGroupIdsForTypes` batch helper or per-type fetch for small fits.
- Snapshot mapper: `locationFlag FighterBay → FighterGroup(quantity)`, `FighterTube0..4 → inSpace += quantity` merged by type; `DroneBay` unchanged.
- Killmail mapper: flag 158 bay, 159..163 tubes; 87 still drone. **Data step:** confirm 158..163 from official SDE `invFlags.yaml` or a carrier killmail on zKillboard before locking expected values — fuzzwork `invFlags.csv` is header-only.
- ESI export: `FighterBay` items with carried quantity per group; modules unchanged; drop list unchanged. Optionally emit `DroneBay` sibling (one line) — planner decision.
- Persistence: saved-fitting JSON gains `fighters`; absent key → `[]` (freezed default); confirm Drift JSON column round-trips.

**Depends on:** U0 (category ids present for EFT classification, but unit tests can inject `groupId` maps). **Independent of U1/U2.** **Validated by:** §4.5 + persistence round-trip.

### [SEQ] U4 — Fighter engine + allowlist additions + StatsPanel

**Owner:** `lib/features/fitting/domain/dogma_engine.dart`, `lib/features/fitting/presentation/widgets/stats_panel.dart`, `lib/features/fitting/presentation/fitting_providers.dart` (fighter type resolution)

- `dogma_engine.dart` — fighter classification F1: type is fighter iff `baseAttributes.containsKey(2215)`; class = first true of `2212/2213/2214` else standup flags → unlaunchable. Add fighter type ids to `charTargetIds` and to exclusion set of `shipID` module loop (like drones).
- F2 squadrons: `maxSize = attr(2215)`, `launched = inSpace>0 ? min(inSpace,quantity) : quantity`, `squadrons = ceil(launched/maxSize)` with remainder; bay usage = `Σ quantity × volume(38)` (all carried, not just launched).
- F3 activation (deterministic, spec R4): iterate `fitting.fighters` in declaration order; squadron activates iff `tubesLeft>0 && classLeft(class)>0`; caps from `shipType.baseAttributes.containsKey(id) ? attr(id) : 0` for 2216..2219 and 2055 (guards the `ItemModifier + shipID` phantom 2055=1.05).
- F4 abilities: curated table by effect id (6465 attack 2226/2227..2230/2233, 6431 missiles 2130/2131..2134/2182 with role 2270 shot table, 6485 bomb 2324/2349 role 5 only, 6554 kamikaze one-shot, plus 6441/6440/6442/6439/6464/6435/6436/6434/6437 as represented non-DPS). Active ability: if 6465 present → attack; else every damage ability except bomb/kamikaze (Gram missiles-only). Infinite reloads in v1; shot/rearm table recorded in constant.
- F5 DPS: `components_i = chargeAttr(fighter, dmgAttr_i)` (after `charID` bonuses §3.6), `mult = chargeAttr(fighter, multAttr)` default 1.0, `durationMs = chargeAttr(fighter, durationAttr)`, `squadronVolley = sum(components) × mult × squadronSize`, `squadronDps = volley / (durationMs/1000)`; sum over active squadrons → `dpsFighters`. Missing attrs → 0, log, never throw.
- F6 bay/tubes: `fighterBayMax = attr(2055)` after ship `percentModifiers` (6570 +5%/lvl); `fighterTubesMax = attr(2216)`; used from F3; over-capacity reported, never truncated.
- F7 isolation: drones vs fighters separate loops; `droneBandwidthUsed/BayUsed/dpsDrones` untouched; regression lock T2.13/T2.14.
- §3.6 bonuses: fighters already in `charTargetIds`, so DDA 6556 / FSU 6566 (penalised, owner module) and hull 6601 / skill 6560/6563/12844../6663 (unpenalised) apply with no new branch beyond allowlist additions. Note 6663 also boosts drones — production wiring test must keep seeded character without it or re-baseline.
- `fitting_providers.dart`: ensure fighter types and their bomb charge (2324) are resolved into `moduleTypes` before `ensureEffectModifiers`.
- `stats_panel.dart`: OFFENSE row `Fighters` when `dpsFighters>0` (beside `Drones`); new `FIGHTERS` section when `fighterTubesMax>0 || fighterBayUsed>0`: `Tubes used/max`, `Bay used/max m3` (error colour when `used>max`), `Light a/b`, `Support a/b`, `Heavy a/b`, one row per `fighterSquadrons`. Hulls without tubes/bay render no section.
- Logging: `[DOGMA]` for fighter classification/activation, missing-attr degradation.

**Depends on:** U1 (bonus buckets + `bonusScale` for 2055), U2 (shared `charID` path), U3 (models/mappers). **Validated by:** §4.2 + §4.3 fighter parity T2.22/T2.22s/T2.23/T2.29 + widget T2.24.

### [SEQ] U5 — Journal, spec corrections, verification, handoff

**Owner:** `docs/engineering-journal/LEARNINGS.md`, `docs/engineering-journal/QUEUED.md`, `docs/engineering-journal/ARCHIVE.md`, `docs/engineering-journal/DECISIONS.md`, `docs/specs/fitting-completion-skill-rof-and-fighters*.md`

- Correct `LEARNINGS.md` 2026-09-08 "modifierInfo stops at item boundaries" inline: skills were not bundled; most skill effects publish `modifierInfo`; empty ones are `1851, 660/661/662/668, 1730`; generalizable rule stands. Move old text to `ARCHIVE.md` as SUPERSEDED per journal protocol.
- Apply design §0 C1..C10 to product spec (or mark `fitting-completion-skill-rof-and-fighters.md` superseded by `…-design.md` with correction table).
- `DECISIONS.md`: add entries for allowlist+curated supplement, owner-kind penalty, fighter counts not squadron objects, infinite reloads.
- `QUEUED.md`: move both entries (skill cycle-time bonuses P2, fighter support P3→P2) to `ARCHIVE.md` as SHIPPED; add follow-ups from design §7 (missile/drone damage curated supplements, retire `_skillModifiers` table, bundle `stackable`, add `skillTypeId` to `SdeEffectModifiers`, fighter reloads, editor UI, pyfa spot check).
- Run `flutter analyze`, `flutter test`, `dart format .` verification and regenerate goldens if `StatsPanel` changes affect any golden.

**Depends on:** U0–U4. Blocks HANDOFF.

## Validation Plan

Each work unit owns its tests; no unit is done until its rows pass. Existing tests are regression-locked — if one needs editing, file as bug.

| Unit | Command | Expected evidence |
|------|---------|-------------------|
| U0 data | `flutter test test/core/sde/sde_service_test.dart` (new cases §4.4) | `dogma.json` contains categories 16 & 87; `effect_modifiers.json` contains 582/414/1763/6577/6578/6560/6563/6570/6663/6465/6431/6485; `SdeService.initialize()` re-imports on `dogma_version` mismatch and skips on match; seeded skills keep `rank` after dogma import; `getDogmaTypes([3310,23055,999999])` returns 2 entries in 3 queries; `getModulesBySlotType` never returns skill/fighter |
| U1 core | `flutter test test/features/fitting/domain/dogma_engine_test.dart` existing suite | All existing 400+ tests green unmodified (shim path); new coverage: six-slot `requiresSkill` (1285/1289/1290), `_Bonus` chain `×0.869` second-item penalty, ship `bonusScale` via 280 (Thanatos Gallente Carrier III → fighter mult ×1.15) |
| U2 skills | `flutter test test/features/fitting/domain/dogma_engine_test.dart` `–name "skill cycle"` + `flutter test test/features/fitting/domain/real_sde_weapon_test.dart` + `flutter test test/features/fitting/presentation/fitting_stats_production_wiring_test.dart` | T1.1–T1.3, T1.1g, T1.4, T1.4r, T1.5–T1.8, T1.9/T1.10, T1.11/T1.12, T1.13/T1.14/T1.14m, T1.15–T1.19, T1.23–T1.25 green; T1.20 `125mm Gatling AutoCannon I` cycle `51×0.625×0.90×0.80` `closeTo(0.01)` and volley unchanged; T1.20b identical; T1.21 `12800×0.9×0.9×0.85`; T1.26 curated guard empty; T1.27 bundled shapes present; T1.22 production wiring Tristan DPS row strictly exceeds untrained |
| U3 fighter I/O | `flutter test test/features/fitting/domain/format_parser_test.dart` + new mapper/export tests | Pyfa EFT `Hobgoblin II x5` + `Templar II x6 ×2` → drones `[x5]`, fighters `[x12]` round-trip; snapshot `FighterBay x12 + FighterTube0 x6` → `FighterGroup(18, inSpace 6)`; killmail 158/159..163; ESI export `FighterBay` items; saved JSON without `fighters` loads `[]` |
| U4 fighter engine | `flutter test test/features/fitting/domain/dogma_engine_test.dart` `–name "fighters"` + `real_sde_weapon_test.dart` (fighter parity) + `fitting_stats_production_wiring_test.dart` | T2.1 `6×207/5=248.4`, T2.2–T2.5 ratios, T2.4 ms→s guard, T2.6–T2.10 tube/class/mixed-order, T2.6q quantity 14→6/6/2, T2.6s `inSpace` isolation, T2.11/T2.12 bay `18000/10000` no truncation, T2.13/T2.14 drone isolation, T2.15 `dpsTotal` sum, T2.16 non-carrier 0, T2.17 degrade safely, T2.18 inverted DDA ×1.205 (+ penalised pair), T2.19/19g/19b abilities, T2.20 racial, T2.21 standup 0, T2.25 `×1.15`, T2.26 role raw, T2.27 `×1.25×1.25×1.205`, T2.28 bay `×1.25`; T2.22 `Thanatos+3×Firbolg 405.0` + T2.22s skilled `×1.25×1.5×1.25`; T2.23 `Nyx 2218=0`; T2.29 every bundled fighter classifies; T2.24 widget renders `FIGHTERS` header, tubes/bay/ per-class + Fighter DPS row |
| U5 closeout | `flutter analyze`, `flutter test`, `dart format .` | Zero analyzer issues; full suite green; no skipped tests; logs present |

**Highest-risk validation:** real-SDE parity `T1.20`/`T2.22` — if `TARGET_CATEGORIES` or `dogma_version` gating is off by one, every later calculation is silently wrong and only these tests fail.

## Risks / Rollback

- **R1/R2 blocking — bundled data missing (U0).** If carrier or skill types fail to regenerate (fuzzwork 404, `csv/` layout drift), `T1.20/T2.22` cannot run. *Mitigation:* verifier in CI asserts `dogma.json` categories and `effect_modifiers.json` keys before tests; keep generator's cached CSV fallback. *Rollback:* revert `TARGET_CATEGORIES` and asset commit; engine shim keeps behaviour identical to today.
- **Existing installs stranded (U0).** `hasDogmaData()` true would skip the new categories forever. *Mitigation:* `dogma_version` gate; import is upsert-only so re-import is safe. *Rollback:* bump version back.
- **Stacking penalty regression (U1).** Second gyro/BCS/DDA now penalised — numbers move vs today. *Mitigation:* design quarantines the change to module-owned `charID`/`shipID` bonuses; single-module tests unaffected. If owner insists on preserving today's numbers, flip one line `penalized:false` for `op 0/4 module` bonuses and file parity fix in QUEUED (design §1.4 note).
- **Ship `bonusScale` misfire (U1).** Thanatos/Nyx fighter bonuses would scale with Capital Ships instead of racial carrier skill. *Mitigation:* `bonusScale` keyed by `modifyingAttributeId` 280 path; T2.25 pins the correct skill. *Rollback:* shim fallback preserves old `shipSkillLevel` for fixture tests.
- **Fighter `containsKey` guard (U4).** `ItemModifier` on 2055/2216 writes phantom attrs on hulls without them. *Mitigation:* every hull read guarded by `baseAttributes.containsKey(id)`; T2.16/T2.28 cover it. *Rollback:* disable fighter engine loop behind early return.
- **Killmail flag uncertainty (U3).** 158/159..163 not confirmed from fuzzwork (header-only). *Mitigation:* data step must confirm from official SDE `invFlags.yaml` or a carrier killmail; test named `killmail_flags_pending_confirmation` until then.
- **External validation gap (R5).** Parity proves internal consistency, not ground truth. *Mitigation:* record as known limitation; if user has pyfa, spot-check one turret and one carrier fit and file deltas.
- **Journal protocol.** AGENTS.md requires journal writes in the same change set — don't defer LEARNINGS/QUEUED→ARCHIVE to a follow-up PR.

## Open Questions

- **Asset size budget.** `TARGET_CATEGORIES += {16,87}` adds ~0.6 MB to `dogma.json` (design measurement). Confirm acceptable for macOS + future mobile bundle; if not, split fighter SDE into a lazy asset (spec proposes eager bundle).
- **DroneBay ESI export sibling.** Should `esi_fitting_export.dart` also emit `DroneBay` items for drones (currently not exported) as the design's one-line fix suggests, or keep scope strictly to fighters?
- **Killmail flag source of truth for 158..163.** Must confirm from official SDE YAML vs zKillboard sample before locking mapper tests; until confirmed, keep flag mapping behind a named constant with TODO.
- **Widget golden churn.** `StatsPanel` gains a `FIGHTERS` section — existing goldens that render `StatsPanel` will need baseline regeneration; owner approval on the new baselines is required in PR review.

---
*Plan file:* `.agents/plans/2026-09-11-fitting-completion-skill-rof-and-fighters.md` — canonical body is the reply above. Reviewer prompts: check `containsKey` guards on hull fighter attrs, that fighters never enter the `shipID` module loop, and that no non-allowlisted skill effect changes numbers (T1.24).
