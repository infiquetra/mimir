# Fitting Module Completion — Product Spec & Acceptance Criteria

**Scope.** Two queued gaps that finish the Fitting module's simulation fidelity:

1. **Skill cycle-time bonuses** — Rapid Firing, Missile Launcher Operation,
   and the missile specialisations (QUEUED P2).
2. **Fighter support** — fighter bay, launch tubes, and abilities (QUEUED P3).

**Sources.** `mimir-context-library/platform-specs/03-feature-modules/fitting/specification.md`;
`docs/engineering-journal/QUEUED.md`; `docs/engineering-journal/LEARNINGS.md`
(2026-09-08 `modifierInfo stops at item boundaries`).

**Audience.** The planner (scoping and sequencing) and the test author
(writing the cases below verbatim).

---

> **Status: Completed & Shipped (2026-09-11).**
> This specification has been fully implemented, reviewed, and verified end-to-end.
> During architectural analysis and SDE cross-validation, ten corrections (C1–C10) were established in [`fitting-completion-skill-rof-and-fighters-design.md`](fitting-completion-skill-rof-and-fighters-design.md) (§0) and superseded earlier assumptions:
> - **C1/C3 (Dogma Routing & Skill Filters):** Category 16 (Skill) is bundled into `dogma.json` and `effect_modifiers.json`. SDE published `LocationRequiredSkillModifier` entries resolve directly on skill types; all 780 weapons directly list Gunnery (3300) or MLO (3319) across the six required skill slots `{182, 183, 184, 1285, 1289, 1290}` with 0 transitive-only, eliminating the need for a transitive closure graph.
> - **C2 (Effect 1851):** Sub-capital missile specialisations publish empty `modifierInfo` in SDE; handled via a curated fallback table matching published 6577/6578 shape.
> - **C4 (Gunnery Attr 441):** Gunnery cycle bonus is attribute 441 (`turretSpeeBonus`, -2%/lvl), compounding with Rapid Firing (attr 293) for 0.72x cycle at all-V.
> - **C5 (Ship Attributes):** Correct carrier attributes are 2055 (bay), 2216 (tubes), 2217 (light), 2218 (support), 2219 (heavy) instead of 908/1547.
> - **C6 (Fighter Abilities):** Attack ability (6465) uses 2227–2230 damage, 2226 multiplier, and 2233 duration in milliseconds (divided by 1000.0). Damage ability (6431 Missiles) serves as fallback for Gram / bombers.
> - **C7/C8 (DDAs & Fighter Bonuses):** DDA (6556), FSU (6566), fighter skills (6560, 6563, 6570, 6663, 12844..12848), and carrier hull bonuses are published `charID` dogma modifiers and apply with standard stacking penalties.
> - **C9 (Squadron Sizes):** Attribute 2215 provides authoritative squadron size (6 light/heavy, 3 support, 12 space superiority).
> - **C10 (Bay Over-Capacity):** Reported as used/max without truncating DPS; rendered in `EveColors.error` when used > max.

---

## 0. Investigation result that unblocks Work Item 1

QUEUED gated the skill-ROF work on "an in-game or pyfa-diff cross-check of
the target filters", because the 2026-09-08 investigation concluded no
data-driven filter could be derived. **That conclusion was too strong, and
this spec supersedes it.** The blocker was a *direct* required-skill check;
a **transitive** required-skill closure resolves every case cleanly.

Probes against `scripts/sde/*.csv` (the same dump that feeds
`assets/sde/dogma.json`) on 2026-09-11:

| Probe | Result |
|---|---|
| Skills carry `rofBonus` (293) | Rapid Firing `-4`, MLO `-2`, every missile specialisation `-2`. **Turret specialisations carry none** (Small Autocannon Spec has only attr 292) — the bonus set is exactly 15 skills |
| Modules requiring Light Missile Specialization (20210) | `Light Missile Launcher II`, `Rapid Light Missile Launcher II`, + 8 advanced ammo types (no RoF) |
| Same shape for Rocket / Heavy / HAM / Cruise / Torpedo specs | Exactly the T2 launchers of that class, nothing else |
| Launchers whose skill closure contains MLO (3319) | All 9 missile launcher groups, 100% |
| Turrets (attr 64 + 51) whose closure contains Gunnery (3300) | 619/637 direct; the 18 stragglers (Quad 800mm Repeating Cannon II, Quad Mega Pulse Laser II) resolve **transitively**; Vorton Projectors correctly resolve `False` |
| **Whole-rule sweep over all 799 published weapons with a cycle time** | 622 get Rapid Firing only; 133 MLO only; 14 MLO + one specialisation; 30 get nothing (Vorton, Defender/Festival/probe/bomb launchers — all correct). **Zero weapons receive both Rapid Firing and MLO**, and zero receive two specialisations |

**Why the old premise failed and the new rule holds.** The prior analysis
tested the *specialisation skill's own* attributes 182/183 (`Rocket
Specialization 183 = 3320` — a class skill shared by all rocket launchers,
hence over-application). The correct direction is the inverse: test the
**module's** requirement set for the specialisation skill itself. Only the
T2 launcher of a class requires its specialisation skill, so the filter is
exact by construction. This is `requiresSkill(skill)` — precisely what pyfa's
Effect1851 does — but recovered from SDE data rather than hardcoded.

**Consequences for the planner.**

- No curated per-effect handler table is needed for Work Item 1. The filter
  is three rules over data already loaded (`skillRequirements` + attributes
  182/183/184, both already populated by `SdeService.getModuleType`).
- The transitive closure must be computed over skill→skill prerequisites,
  not just the module's direct requirements. Vorton Projectors falling out
  as `False` is a **correctness signal**, not a miss: they take no Rapid
  Firing bonus in game.
- LEARNINGS must be corrected inline (its generalizable rule — "never derive
  the filter from adjacent attributes" — stands; the specific claim that *no*
  derivation exists does not). Old version moves to ARCHIVE as SUPERSEDED,
  per the journal's own protocol.

---

## Work Item 1 — Skill Cycle-Time Bonuses

### 1.1 Product perspective

Mimir's DPS numbers are the product. A user comparing a fit against pyfa or
the in-game fitting window and seeing a different number does not conclude
"Mimir omits three skills" — they conclude Mimir's simulator is wrong, which
discredits every other number on the panel. At all-V skills the understatement
is 20% on turrets (Rapid Firing alone — turret specialisations grant damage,
not cycle) and ~19% on missiles (MLO 10% compounded with a specialisation 10%).
QUEUED's "~25%" estimate assumed turret specialisations also shortened cycles;
they do not.

The bonuses are also *invisible* in the current UI: nothing tells the user
their skills were ignored, so the error is silent. This is the same class of
defect as the dead `effects` mapping the production-wiring test was written to
catch.

### 1.2 User scenarios

**S1.1 — Doctrine check against pyfa.** An FC builds a doctrine Hurricane in
Mimir with all-V gunnery and compares to pyfa before publishing. The DPS
figures agree within rounding. *Today they differ by ~25% and the FC stops
trusting Mimir.*

**S1.2 — Skill-plan payoff.** A player with Rapid Firing IV considers training
V. They see DPS rise when the fit is evaluated at the higher level, quantifying
the payoff before committing queue time.

**S1.3 — Specialisation scope is correct.** A player fits Rapid Light Missile
Launcher IIs with Light Missile Specialization V. The bonus applies (RLMLs
require that skill). They then fit Rocket Launcher IIs on the same character
and the light-missile bonus does *not* apply.

**S1.4 — No silent over-application.** A player with every specialisation at V
fits a T1 `Light Missile Launcher I`. Only MLO applies — T1 launchers require
no specialisation skill. A rule keyed on launcher *group* would wrongly boost it.

**S1.5 — Untrained baseline.** A fresh character with no gunnery skills sees
unmodified base cycle times, and DPS strictly below the trained character's.

### 1.3 Behavioural rules (normative)

Let `L(s)` be the character's trained level of skill `s` (0 if untrained), and
`closure(m)` the transitive set of skills module `m` requires, following
skill→skill prerequisites.

- **R1.1 Rapid Firing (3310).** If `3300 ∈ closure(m)`, cycle time is
  multiplied by `1 + (−4 × L(3310))/100`.
- **R1.2 Missile Launcher Operation (3319).** If `3319 ∈ closure(m)`, cycle is
  multiplied by `1 + (−2 × L(3319))/100`.
- **R1.3 Specialisations.** For each skill `s` with `rofBonus` (293) defined
  and `s ∈ closure(m)` — excluding 3310 and 3319, handled above — cycle is
  multiplied by `1 + (rofBonus(s) × L(s))/100`. In the current SDE this set is
  13 skills: the six missile specialisations, the two XL specialisations,
  Rapid Launch (`-3`), Doomsday Rapid Firing (`-4`), Breacher Pod Rapid Firing
  (`-10`), and the two ice-harvesting drone skills. **Turret specialisations
  are deliberately absent** — they carry no attribute 293 and grant damage
  (attr 292), not cycle time. Do not add them.
- **R1.4 Composition.** These bonuses are **multiplicative and unpenalised**
  (no stacking penalty), matching pyfa and the existing ship-trait ROF path.
- **R1.5 Per-level values come from SDE attribute 293**, never hardcoded.
  Adding a new specialisation skill to the SDE must require no code change.
- **R1.6 Scope.** Cycle time only. These skills carry no damage modifier;
  volley must not change.
- **R1.7 Cap interaction.** Weapon cycle shortening increases capacitor drain
  rate. The shortened cycle must reach `CapSimulator` via the same
  `moduleAttr(type, rateOfFire)` path, not a DPS-local variable.

**Explicit non-goals.** Vorton Projectors take no Rapid Firing bonus (their
closure excludes Gunnery — correct). Drones and fighters are out of scope for
this item; their cycle skills are separate.

### 1.4 Acceptance criteria

- [ ] **AC1.1** Turret cycle reflects Rapid Firing at the trained level for any
      module whose skill closure contains Gunnery.
- [ ] **AC1.2** Launcher cycle reflects MLO at the trained level for all nine
      missile launcher groups.
- [ ] **AC1.3** A specialisation applies only to modules that require that exact
      skill; T1 modules of the same class are unaffected.
- [ ] **AC1.4** Bonuses compose multiplicatively with each other and with
      existing ship-trait ROF bonuses; no stacking penalty is applied.
- [ ] **AC1.5** Per-level magnitudes are read from SDE attribute 293.
- [ ] **AC1.6** Volley damage is unchanged by these skills; only DPS moves.
- [ ] **AC1.7** Untrained characters see unmodified base cycle times.
- [ ] **AC1.8** Quad 800mm Repeating Cannon II receives Rapid Firing via
      transitive closure; Large Vorton Projector II does not.
- [ ] **AC1.9** Capacitor stability reflects the shortened cycle.
- [ ] **AC1.10** A real-SDE parity test computes expected DPS independently
      from raw bundled attributes and matches the engine.
- [ ] **AC1.11** `flutter analyze` clean; debug logging per CLAUDE.md records
      which skills applied to which module.

### 1.5 Test cases

Unit tests extend `test/features/fitting/domain/dogma_engine_test.dart`
(new group `DogmaEngine skill cycle bonuses`), using the existing fixture
helpers. Parity tests extend
`test/features/fitting/domain/real_sde_weapon_test.dart`.

| ID | Case | Setup | Expected |
|---|---|---|---|
| T1.1 | Rapid Firing shortens turret cycle | Turret `req 182=3300`, RoF 3000ms, Rapid Firing V | cycle `3000 × 0.80 = 2400ms`; DPS `= volley/2.4` |
| T1.2 | Rapid Firing scales with level | Same, level 3 | cycle `3000 × 0.88 = 2640ms` |
| T1.3 | Untrained Rapid Firing is a no-op | Same, no skills | cycle `3000ms`, DPS equals pre-change baseline |
| T1.4 | MLO shortens launcher cycle | Launcher `req 182=3319`, RoF 4000ms, MLO V | cycle `4000 × 0.90 = 3600ms` |
| T1.5 | Specialisation applies to its T2 launcher | Launcher `req {3319, 20209}`, Rocket Spec V, MLO 0 | cycle `× 0.90` |
| T1.6 | MLO + specialisation compose | Same, MLO V + Rocket Spec V | cycle `4000 × 0.90 × 0.90 = 3240ms` (not `× 0.80`) |
| T1.7 | Specialisation does not leak across classes | Launcher `req {3319, 20209}`; character has Light Missile Spec V only | cycle unchanged |
| T1.8 | Specialisation skips T1 of same class | Launcher `req {3319, 3320}` (no spec skill), Rocket Spec V | cycle unchanged |
| T1.9 | Rapid Firing does not touch launchers | Launcher `req 3319`, Rapid Firing V | cycle unchanged |
| T1.10 | MLO does not touch turrets | Turret `req 3300`, MLO V | cycle unchanged |
| T1.11 | Transitive closure resolves indirect Gunnery | Module `req 41403` → … → 3300, Rapid Firing V | bonus applies |
| T1.12 | Closure stops correctly | Module `req {55033, 54826}` (Vorton), Rapid Firing V | cycle unchanged |
| T1.13 | Composes with ship trait ROF | Rifter-style `−7.5%/lvl` trait at V + Rapid Firing V | cycle `base × 0.625 × 0.80`; multiplicative, unpenalised |
| T1.14 | No stacking penalty | Three ROF sources at once | product of factors exactly; no `getStackingPenalty` applied |
| T1.15 | Volley is unchanged | T1.1 setup | `stats.volley` equals untrained volley; only `dpsGuns` rises |
| T1.16 | Cap drain follows shortened cycle | Cap-hungry turret, Rapid Firing V, marginal fit | `isCapStable` flips true→false vs. untrained; drain key uses 2400ms |
| T1.17 | Offline modules unaffected | Offline turret, Rapid Firing V | contributes no DPS and no cap drain |
| T1.18 | Missing 293 attribute degrades safely | Skill fixture without attr 293 | no bonus, no crash, no `null` propagation |
| T1.19 | Level clamped to 0–5 | Skill recorded at level 7 | treated as 5 (or documented clamp), never `× 1.28` |
| T1.20 | **Parity (real SDE)** | `125mm Gatling AutoCannon I` + `Proton S`, Minmatar Frigate V + Rapid Firing V, bundled assets | expected cycle recomputed independently from raw attrs `51`, `293`; `closeTo(..., 0.01)` |
| T1.20b | Turret specialisation grants no cycle bonus | Same fit + Small Autocannon Specialization V | cycle identical to T1.20 — locks the "no attr 293" finding |
| T1.21 | **Parity (missiles)** | `Light Missile Launcher II` + ammo, MLO V + Light Missile Spec V | cycle `12800 × 0.90 × 0.90`; DPS matches independent recompute |
| T1.22 | **Production wiring** | Extend `fitting_stats_production_wiring_test.dart`: real SDE → Drift → `SdeService` → provider → `StatsPanel` with a skilled character | rendered DPS row strictly exceeds the untrained render |

**Fixture note for the test author.** Skill *types* are absent from
`assets/sde/dogma.json` (category 16 is excluded by
`scripts/sde/generate_dogma_sde.py`). T1.20/T1.21 therefore require attribute
293 to be available at runtime. See Risk R1 — resolve before writing parity
tests.

---

## Work Item 2 — Fighter Support

### 2.1 Product perspective

A capital pilot opening the Fitting screen today sees a Drone section reading
`0/0 MBit` and zero drone DPS, because fighters are neither drones nor modules.
For carriers, supercarriers, FAXes and the Rorqual, fighters *are* the weapon
system — so the offense panel is not merely incomplete, it is blank for the
entire capital line.

Fighters use a genuinely different model from drones: squadron-based (not
per-unit), tube-limited (not bandwidth-limited), ability-based (not a single
weapon), and volume-limited by a separate fighter bay. Reusing the drone path
would be wrong on all four axes.

**Priority note for the planner.** QUEUED lists this as P3 while the "AAR fit
simulation" work is P1 and explicitly depends on deterministic offense
derivation. Fighters are the *only* offense source for capitals, so any AAR
covering a capital engagement inherits this gap. Recommend promoting to P2 and
sequencing after Work Item 1 (which is smaller, higher-traffic, and shares the
cycle-time code path).

### 2.2 Data model (verified against raw SDE, 2026-09-11)

**Ship-side attributes:**

| Attr | Meaning | Thanatos | Nyx | Rorqual |
|---|---|---|---|---|
| 908 | Fighter bay capacity (m³) | 2,000,000 | 5,000,000 | 1,000,000 |
| 1547 | **Total launch tubes** | 4 | 4 | 4 |
| 2216 | Light squadron cap | 4 | 5 | — |
| 2217 | Support squadron cap | 3 | 3 | — |
| 2218 | Heavy squadron cap | 2 | 0 | — |

**Fighter-side attributes** (category 87; groups 1537 Support, 1652 Light,
1653 Heavy, + 4777–4779 structure variants; 94 published types):

| Attr | Meaning |
|---|---|
| 2215 | Squadron size (fighters per squadron, e.g. 6) |
| 2128 | Attack ability cycle time (s) |
| 2226 | Attack ability damage multiplier |
| 2131 / 2132 / 2133 / 2134 | Attack damage EM / Thermal / Kinetic / Explosive |
| 2228 / 2229 / 2230 | Missile-ability damage components |
| 2227 | Missile ability damage multiplier |
| 37 | Max velocity |
| 263 | Shield HP |

Racial spread confirmed: Templar I (Amarr) EM `2131=178.5`; Firbolg I
(Gallente) Thermal `2132=207.0`; Dragonfly I (Caldari) Kinetic `2133=196.5`;
Einherji I (Minmatar) Explosive `2134=169.5`.

**Ability effects carry no `modifierInfo`** — `fighterAbilityAttackM` (6465),
`fighterAbilityMissiles` (6431), `fighterAbilityMicroWarpDrive` (6441),
`fighterAbilityEvasiveManeuvers` (6439), `fighterAbilityTackle` (6464). Per
the LEARNINGS rule, these are **curated by effect ID** with the attribute
mapping recorded in a comment and cross-checked — the same pattern already
used for `_expressionTreeSpeedEffects`.

### 2.3 User scenarios

**S2.1 — Carrier offense is not blank.** A pilot fits a Thanatos with 3 Firbolg
squadrons and sees non-zero fighter DPS, bay usage, and tube usage.

**S2.2 — Tube limit binds.** They add a 5th squadron to a 4-tube hull. Only 4
launch; the panel shows `4/4 tubes` and DPS reflects 4 squadrons, not 5.

**S2.3 — Per-class caps.** A Nyx pilot (heavy cap 0) adds a heavy squadron and
sees it contribute nothing, with the reason visible rather than silent.

**S2.4 — Bay capacity.** Squadrons exceeding bay volume are flagged as an
invalid fit, consistent with existing CPU/PG over-capacity treatment.

**S2.5 — Drone section is not hijacked.** A Tristan pilot's drone numbers are
completely unaffected by fighter support.

**S2.6 — Non-carrier hulls.** A Rifter shows no fighter section at all.

### 2.4 Behavioural rules (normative)

- **R2.1 Squadron DPS.** `squadronSize(2215) × Σdamage(2131..2134) ×
  multiplier(2226) / cycle(2128)`. Note 2128 is **seconds**, unlike module
  attr 73/51 which are milliseconds — a units trap worth an explicit test.
- **R2.2 Launch limit.** Active squadrons `≤ 1547` **and** per-class
  `≤ 2216/2217/2218`. Both bind; the stricter wins.
- **R2.3 Bay usage.** `Σ (squadronSize × fighterVolume)` against attr 908.
  Over-capacity is a fit error, not a silent truncation.
- **R2.4 Separation from drones.** Fighter bay/tubes are reported in their own
  fields; `droneBandwidthUsed` / `droneBayUsed` must not change. A fighter must
  never be counted as a drone and must never consume drone bandwidth.
- **R2.5 Ability selection.** Ship 1 = attack ability. Missile, MWD, tackle and
  evasive abilities are modelled as **present but not contributing DPS** in
  this increment, and must be represented explicitly (not silently dropped).
- **R2.6 Damage amps do not apply.** Drone Damage Amplifiers filter on the
  Drones skill (3436); fighters require Fighters (23069). The existing
  `charID`-domain routing must not reach fighters.
- **R2.7 Graceful absence.** Hulls without attr 908 report no fighter capacity
  and render no fighter section.
- **R2.8 Fighter skills** (Fighters, Light/Heavy/Support Fighters, Fighter
  Hangar Management) are **out of scope** for this increment. They carry no
  `rofBonus`; their bonuses are separate attributes (2603, 2340, …). Record as
  a follow-up QUEUED entry rather than guessing.

### 2.5 Acceptance criteria

- [ ] **AC2.1** Fighter squadron DPS computed per R2.1 and surfaced as a
      dedicated stat distinct from `dpsDrones`.
- [ ] **AC2.2** Total launch tubes (1547) cap active squadrons.
- [ ] **AC2.3** Per-class caps (2216/2217/2218) independently cap each class.
- [ ] **AC2.4** Fighter bay usage tracked against 908; over-capacity surfaces
      as a fit error.
- [ ] **AC2.5** Drone stats are bit-for-bit unchanged by fighter support
      (regression-locked).
- [ ] **AC2.6** Non-fighter hulls render no fighter section.
- [ ] **AC2.7** `dpsTotal` includes fighter DPS exactly once.
- [ ] **AC2.8** Fighter types are available to the app (see Risk R2).
- [ ] **AC2.9** Non-attack abilities are represented without contributing DPS.
- [ ] **AC2.10** Drone Damage Amplifiers do not affect fighter damage.
- [ ] **AC2.11** Real-SDE parity test with an independently recomputed
      expected value.
- [ ] **AC2.12** `flutter analyze` clean; logging under a `[FITTING]`/`[DOGMA]`
      tag per CLAUDE.md.

### 2.6 Test cases

New unit group `DogmaEngine fighters` in `dogma_engine_test.dart`; parity in
`real_sde_weapon_test.dart`; UI in the production-wiring test.

| ID | Case | Setup | Expected |
|---|---|---|---|
| T2.1 | Squadron DPS baseline | 1 squadron, size 6, dmg 207 thermal, mult 1.0, cycle 5.5s | `6 × 207 / 5.5 ≈ 225.8` |
| T2.2 | Squadron size scales DPS | size 9 vs 6, else equal | DPS ratio exactly `1.5` |
| T2.3 | Damage multiplier applies | `2226 = 1.5` | DPS `× 1.5` |
| T2.4 | **Cycle is seconds, not ms** | cycle `2128 = 5.5` | DPS uses `/5.5`, not `/0.0055` — guards the units trap |
| T2.5 | All four damage components sum | EM 50 + Th 50 + Kin 50 + Exp 50 | volley `200 × size` |
| T2.6 | Total tube limit binds | 5 squadrons, `1547 = 4` | 4 active; DPS = 4 squadrons; `tubesUsed = 4` |
| T2.7 | Per-class cap binds | 3 heavy squadrons, `2218 = 2`, tubes 4 | 2 active |
| T2.8 | Zero class cap excludes entirely | 1 heavy squadron, `2218 = 0` (Nyx) | 0 active, 0 DPS |
| T2.9 | Stricter limit wins | tubes 4, light cap 5, 5 light squadrons | 4 active |
| T2.10 | Mixed classes share tubes | 2 light + 2 heavy + 2 support, tubes 4 | exactly 4 active, deterministic selection documented |
| T2.11 | Bay usage accumulates | 3 squadrons × size 6 × 1000 m³ | `bayUsed = 18000` |
| T2.12 | Bay over-capacity is an error | bay 908 = 10000, usage 18000 | fit reports error; does not silently truncate |
| T2.13 | **Drone stats untouched** | Fighter fit on a hull with drone attrs + drones fitted | `droneBandwidthUsed`/`droneBayUsed`/`dpsDrones` identical to pre-change values |
| T2.14 | Fighters never consume bandwidth | fighters only, hull has bandwidth 25 | `droneBandwidthUsed == 0` |
| T2.15 | `dpsTotal` sums once | guns + drones + fighters | `dpsTotal == dpsGuns + dpsMissiles + dpsDrones + dpsFighters` |
| T2.16 | Non-carrier hull | Rifter + fighters in fit | no fighter capacity; no crash |
| T2.17 | Missing fighter attributes degrade safely | fighter type missing 2215/2128 | contributes 0, no crash, no `null` |
| T2.18 | DDA does not boost fighters | DDA II fitted + fighter squadron | fighter DPS unchanged; drone DPS still boosted |
| T2.19 | Non-attack ability present, no DPS | Firbolg (attack + missile + MWD) | DPS from attack only; abilities enumerated |
| T2.20 | Racial damage types | Templar (EM) vs Einherji (Exp) | damage lands in the correct component |
| T2.21 | Structure fighter groups recognised | group 4777–4779 | handled as fighters, not unknown |
| T2.22 | **Parity (real SDE)** | Thanatos + 3 × Firbolg I from bundled assets | DPS recomputed independently from raw 2215/2132/2226/2128; `closeTo(..., 0.01)` |
| T2.23 | **Parity (tube limit, real SDE)** | Nyx (`2218 = 0`) + heavy squadron | 0 heavy active, matching in-game |
| T2.24 | **UI wiring** | Extend production-wiring test with a carrier fit | `StatsPanel` renders fighter bay/tube/DPS rows; a Tristan fit still renders drone rows unchanged |

---

## 3. Cross-cutting acceptance criteria

- [ ] **AC3.1** `flutter test` fully green; no skipped or ignored tests.
- [ ] **AC3.2** `flutter analyze` clean.
- [ ] **AC3.3** Every new public method logs entry/params per CLAUDE.md.
- [ ] **AC3.4** No raw EVE IDs rendered; names resolve via the correct provider.
- [ ] **AC3.5** Journal updated: QUEUED entries moved to ARCHIVE as SHIPPED;
      LEARNINGS corrected inline for the superseded filter conclusion (§0),
      with the old version moved to ARCHIVE as SUPERSEDED.
- [ ] **AC3.6** No hardcoded per-level magnitudes; all read from SDE.
- [ ] **AC3.7** Both items are pure additions to `FittingStats`; no existing
      field changes meaning. Existing tests pass unmodified — if one needs
      editing, that is a regression signal, not a test-maintenance task.

---

## 4. Risks and open questions — resolve before implementation

**R1 (blocking, Work Item 1). Skill attributes are not bundled.**
`generate_dogma_sde.py` excludes category 16, so attribute 293 is unavailable
at runtime; `assets/sde/skills.json` carries IDs and prerequisites but no
attributes. Options:

- **(a) Recommended** — add category 16 to `TARGET_CATEGORIES`, or extend the
  skills export with attributes 293/182/183/184. Keeps AC1.5 honest (data-
  driven) and makes T1.20/T1.21 possible. Cost: small asset-size increase;
  requires regenerating and committing `dogma.json`.
- **(b)** Curate a small constant table in code. Faster, but violates AC1.5
  and reintroduces exactly the hardcoding the LEARNINGS rule warns about.

Recommend (a). **Decision needed from the user before the test author starts**,
because it determines whether T1.20/T1.21 can be written against bundled data.

**R2 (blocking, Work Item 2). Fighters are not bundled.** Category 87 is
excluded, so all 94 fighter types are absent from `dogma.json`. AC2.8 cannot
pass without adding it. Same one-line change to `TARGET_CATEGORIES`; larger
asset impact than R1. No alternative — fighters cannot be curated by hand.

**R3 (design, Work Item 2). Squadron representation.** `DroneGroup` has
`quantity`/`inBay`/`inSpace`, which does not express squadrons. Recommend a
distinct `FighterSquadron` model rather than overloading `DroneGroup` —
overloading is what makes R2.4 fragile. Planner decision.

**R4 (behavioural, Work Item 2). Tube allocation order** when mixed classes
exceed total tubes (T2.10). Needs a documented deterministic rule; recommend
fit-declaration order, matching the existing drone path.

**R5 (verification).** Neither item has been cross-checked against a live
client or pyfa — §0 is an SDE-data argument, strong but not an in-game
observation. Parity tests (T1.20/T1.21/T2.22/T2.23) recompute from bundled
attributes, so they verify *internal consistency*, not ground truth. If the
user has pyfa access, spot-checking one turret and one carrier fit would close
this; otherwise ship with the limitation recorded in LEARNINGS.

---

## 5. Recommended sequencing

1. **Decide R1 and R2** (asset scope) — blocks everything.
2. **Work Item 1** — smaller, affects every subsonic combat fit, shares the
   cycle-time path that Work Item 2 also touches.
3. **Correct LEARNINGS** per §0 while the evidence is fresh.
4. **Work Item 2** — build on the settled cycle-time code.
5. **Re-evaluate QUEUED P1 AAR fit simulation**, which depends on both.
