# Milestone Spec: AAR Fit Simulation & Defense Profile Derivation

**Status.** Proposed — ready for Arch and Plan
**Source.** QUEUED.md P1 "AAR fit simulation and defense profile derivation"
**Author.** Product
**Date.** 2026-09-11
**Predecessor.** Fitting Module Completion (f1225a9) — skill ROF bonuses and fighters

---

## 0. Why this milestone, and why now

### 0.1 The decisive finding: this is an integration milestone, not a derivation milestone

QUEUED describes this as needing "deterministic derivation for EHP, resists, tank
layer, capacitor, range envelope, speed, signature, and damage application," and
estimates "several days to a week depending on whether the existing dogma engine
is sufficient or pyfa-grade behavior needs a deeper port."

Inspection of the code says the dogma engine is **already largely sufficient**:

| Quantity QUEUED calls for | State today | Location |
|---|---|---|
| Shield/armor/hull HP | Derived | `dogma_engine.dart` §3 |
| Resists (all 3 layers × 4 types) | Derived from resonance | `dogma_engine.dart:750-773` |
| EHP per layer + total | Derived | `dogma_engine.dart:775-800` |
| Capacitor (stability, %, time-to-empty) | Derived via `CapSimulator` | `dogma_engine.dart:801-820` |
| Range envelope (optimal, falloff) | Derived | `FittingStats.optimalRange/falloffRange` |
| Speed, align, warp, mass | Derived | `FittingStats.maxVelocity/alignTime/...` |
| Signature radius | Derived | `FittingStats.signatureRadius` |
| DPS (guns/missiles/drones/fighters) | Derived | `FittingStats.dpsTotal` + breakdown |
| Damage application (matchup vs resists) | **Written, tested, and wired to nothing** | `combat_damage_matchup.dart` |

The gap is **not** the physics. `CombatDamageMatchupAnalyzer.analyze()` exists,
takes a `DefenseProfile`, produces per-damage-type resist-hole assessments, and
has a passing unit test. Its only callers in the entire repository are that test
and itself. Likewise `combat_analyzer/domain/` imports `fitting/domain/models.dart`
in five files — it already speaks the fitting vocabulary — but **no file under
`lib/features/combat_analyzer/` references `DogmaEngine` or `FittingStats` at all.**

The Combat Analyzer holds `Fitting` objects (via `FitEvidence.fitting`) and never
turns them into stats. That is the milestone: **connect two finished subsystems
that were built to fit together and never joined.**

### 0.2 What this means for scope and risk

This reframes the work from "port pyfa-grade defense math" (high risk, unclear
ceiling) to "wire the derivation into the AAR pipeline and close three specific
correctness gaps" (bounded, verifiable). The engine work that remains is small
and precisely identifiable (§2.2). I estimate **3–5 days**, versus QUEUED's
"several days to a week," and with materially lower variance because the
uncertain part — whether the dogma engine was good enough — is now answered.

### 0.3 Why not the Exploration Module

Exploration is genuinely valuable and the spec is detailed (1,290 lines, five
phased weeks). I am recommending against it *for this milestone* on four grounds:

1. **It strands finished work.** The matchup analyzer and `DefenseProfile` are
   complete, tested, and dead. Every week they stay unwired is a week of paid-for
   capability delivering zero user value, and a week in which they can silently
   rot against engine changes. Shipping Exploration first means the fitting
   milestone we just closed does not reach a user through the AAR path at all.

2. **It is P2 versus P1, and the dependency runs one way.** QUEUED's P1 "AAR
   evidence completeness score" explicitly depends on knowing which derived
   quantities are available — it cannot be specified correctly until this ships.
   Exploration depends on neither.

3. **It adds two live third-party integrations.** EVE-Scout and Tripwire are
   external, unversioned, and auth-bearing. We have direct scar tissue here: the
   Pathfinder mock (QUEUED P2, removed 2026-09-07) shipped fabricated data behind
   a green "Connected" badge in an intel tool. Exploration's Tripwire integration
   is the same shape of risk, and that QUEUED entry states the precondition
   plainly — "worth it when a maintained public endpoint is identified and its
   auth model is understood." **That precondition is not yet met.** Starting
   Exploration now means starting with its riskiest dependency unresolved.

4. **Momentum and context.** The team just spent a milestone deep in the dogma
   engine, the SDE bundle, and fitting parity testing. That context is loaded and
   will be expensive to rebuild later.

**Recommended sequencing:** ship this milestone, then AAR evidence completeness
(P1, half-day to a day, trivially cheap once this lands), then Exploration Phase
4a (Wormhole Database) — which is the offline, SDE-backed, zero-third-party slice
and can proceed while someone resolves the EVE-Scout/Tripwire API contract question
out of band.

### 0.4 Honest counterargument

The strongest case for Exploration is user-facing novelty: this milestone makes an
existing screen *more correct*, while Exploration adds a capability users do not
have at all. If the goal were a demo or a release announcement, Exploration wins.
I am weighting toward AAR because QUEUED frames the trust question sharply —
"before presenting AAR recommendations as mechanically trustworthy fit advice
rather than AI coaching prose" — and shipping more surface area on top of an
untrustworthy analytical base compounds a problem rather than resolving it. If
the priority is breadth over trustworthiness, reverse this call; the analysis in
§0.1 stands either way and this spec keeps.

---

## 1. Product perspective

### 1.1 The problem in user terms

A pilot loses a fight, opens the AAR, and reads a competent-sounding narrative:
"your Thermal resist was your weak point; consider refitting." The pilot cannot
tell whether that sentence came from arithmetic or from an LLM's prior about
Gallente hulls. Both read identically.

Today it is **usually the latter**. The evidence ledger carries fits. The analyzer
turns fits into prose. Nothing turns fits into numbers along the way.

### 1.2 The product principle

> **Every quantitative claim in an AAR must be attributable to a derivation the
> user can inspect, or explicitly labelled as an unknown.**

This is the same principle that governed the Pathfinder removal: in an intel tool,
plausible-looking fabricated data is worse than a visible gap. An AAR that says
"Thermal was your hole (resist 24.3%, took 41% of incoming damage)" is a different
product from one that says "Thermal was probably your hole." The first is a tool.
The second is a chatbot with a EVE skin.

### 1.3 What changes for the user

- The AAR shows a **derived defense panel** for pilot and victim fits: EHP by
  layer, resists, tank type, capacitor, speed/sig, DPS.
- The **damage matchup becomes real**: incoming damage from the combat log, cross-
  referenced against derived resists, naming the actual resist hole with numbers.
- **Unknowns become explicit and specific**: not "opponent fit unknown" but
  "opponent armor resists unknown — no fit evidence; EHP range estimated from hull
  base only."
- The **LLM is given derived facts rather than asked to infer them**, which
  changes what it can plausibly assert.

### 1.4 Non-goals

- No new pyfa-grade features (no clip reloads — QUEUED P3; no ability reloads —
  QUEUED P3; no projection/tracking application to the matchup).
- No change to the LLM prompt's *narrative* structure beyond supplying derived facts.
- No fit *editing* from the AAR screen.
- No Exploration work.

---

## 2. Scope

### 2.1 In scope: the integration (the bulk of the work)

**W1. `FitEvidence` → `FittingStats` derivation service.**
A service in `combat_analyzer/domain/` (or `data/`, Arch's call) that takes a
`FitEvidence` and returns derived stats, resolving `ModuleType`/`ShipType` from
`SdeService` and applying character skills where known.

**W2. Skill context resolution.** The dogma engine applies skill bonuses. A victim
fit from a killmail has **no known pilot skills**. This must be an explicit,
labelled assumption, not a silent default. See R2.3.

**W3. Wire `CombatDamageMatchupAnalyzer` into the AAR pipeline**, fed by the
already-working `CombatDamageProfileResolver` (incoming damage by type) plus the
derived `DefenseProfile`.

**W4. Derived facts into the evidence ledger** as `CombatEvidenceFact` entries with
correct `EvidenceSource` and `EvidenceConfidence`, so they flow to the LLM and the UI.

**W5. UI surface** in `analysis_multipane_screen.dart`: a derived-stats panel per
fit role, and the matchup rendered with numbers.

**W6. Specific unknowns** replacing generic ones in `AarUnknown`.

### 2.2 In scope: three engine correctness gaps

These are small, real, and this milestone is the right time to fix them.

**E1. EHP uses a flat resist average — this is wrong.** `dogma_engine.dart:776-781`
computes `hp / (1 - avgResist)` where `avgResist` is the arithmetic mean of the
four resists. That is not EHP against any real damage profile, and it is
systematically optimistic when resists are uneven (which is nearly always — that
is the entire point of a resist hole). A 0/20/40/50 profile averages to 27.5%,
but against pure EM the effective figure is 0%.

*Required:* EHP against an explicit damage profile. Keep an omni/even-split figure
for the summary row, but the matchup and any resist-hole claim must use the
**actual incoming profile** from the combat log. This is the single highest-value
correctness fix in the milestone, because the flat average actively hides exactly
the thing the AAR is trying to surface.

**E2. `effectiveShieldBoost` and `effectiveArmorRepair` are declared and never set.**
`models.dart:211-212` — both fields exist on `DefenseProfile` and no code in `lib/`
assigns them. QUEUED explicitly names "tank layer" as in scope. Active tank
representation is required for the tank-layer classification to be honest:
`_primaryLayer()` currently picks by raw HP, which misclassifies an active-armor
Myrmidon with a large shield buffer.

**E3. Tank-layer classification should account for active tank.** Follows from E2.

### 2.3 Explicitly out of scope

- Clip reloads (QUEUED P3), fighter ability reloads (QUEUED P3).
- Turret tracking / missile application to the matchup — the matchup answers
  "what resist did the damage hit," not "did the shot land." Worth queuing.
- Curated missile/drone damage supplements (QUEUED P3, effects 660–668, 1730).
- Retiring `_skillModifiers` (QUEUED P3).

---

## 3. User scenarios

### S1 — The resist hole, named with numbers
Pilot loses a Vexor to a Caracal, imports their fit, opens the AAR. The defense
panel shows Armor 8,412 EHP with EM 52.4% / Therm 34.8% / Kin 63.1% / Exp 71.2%.
The matchup shows 78% of incoming damage was Kinetic against 63.1% resist, flagged
`strongResist`, and 19% Thermal against 34.8%, flagged `resistHole`. The AAR states
the Thermal gap with those figures.
*Value:* the pilot learns a specific, checkable fact.

### S2 — The victim fit with unknown skills
Pilot analyses a killmail for an opponent they beat. Fit comes from the killmail;
pilot skills are unknowable. The panel shows derived stats labelled **"assumes All
V"** with `EvidenceConfidence` reduced accordingly, and an `AarUnknown` stating
that opponent skills are unknown and figures are an upper bound.
*Value:* the number is useful and its uncertainty is legible — the §1.2 principle.

### S3 — The partial fit
Killmail shows high slots and one mid; rigs destroyed and unrecoverable. Derivation
runs on what is present; the panel marks the fit incomplete and names which slots
are missing; EHP is presented as a floor.
*Value:* no silent fabrication of a complete fit.

### S4 — Cap-out as a derived cause
Combat log shows the pilot's repper stopping mid-fight. Cap simulation shows the
fit unstable at 47s to empty. The AAR links the observed event to the derived
figure.
*Value:* a mechanical explanation replaces a guess.

### S5 — Active versus buffer tank classification
Pilot flies an active-armor Myrmidon with a shield extender. Tank layer classifies
as **Armor (active)**, citing effective armor repair, not the larger shield buffer.
*Value:* E2/E3 made visible; matchup is computed against the right layer.

### S6 — No fit evidence at all
No fit for either party. No derived panel is shown. `AarUnknown` entries state
precisely what could not be derived and what evidence would unlock it.
*Value:* the completeness-score P1 work has a real signal to consume.

### S7 — Two fits, side by side
Pilot has both their fight-time fit and the victim's. Both panels render; the AAR
can compare EHP, DPS, and cap.
*Value:* foundation for QUEUED P2 "Fit comparison visuals."

---

## 4. Normative rules

**R1 — Derivation**
- **R1.1** Any `FitEvidence` with ≥1 resolvable module MUST derive `FittingStats`.
- **R1.2** Derivation MUST NOT invent modules, charges, or slots not in evidence.
- **R1.3** Derivation failure MUST produce an `AarUnknown`, never a zeroed panel
  presented as fact.
- **R1.4** Derived values MUST be identical to those the Fitting module would
  produce for the same `Fitting` + skill context. One engine, one answer.

**R2 — Skills and confidence**
- **R2.1** Pilot's own fit for a known character: use that character's actual skills.
- **R2.2** Pilot's fit, skills unavailable: All V, labelled.
- **R2.3** Any non-pilot fit (killmail victim, opponent): All V, labelled
  "assumes All V", `EvidenceConfidence` MUST be reduced below the
  known-skills case.
- **R2.4** The skill assumption MUST be visible in the UI and present in the
  ledger fact, not buried in code.

**R3 — EHP and matchup**
- **R3.1** Any EHP figure used in a resist-hole claim MUST be computed against the
  actual incoming damage profile, not a flat resist average. *(Fixes E1.)*
- **R3.2** A summary EHP MAY use an even split, and MUST be labelled as such.
- **R3.3** The matchup MUST run against the derived layer from R4, using real
  resists.
- **R3.4** Incoming damage with unresolvable weapon types MUST appear in
  `unknownWeapons` and be excluded from percentages, not silently dropped.

**R4 — Tank layer**
- **R4.1** Classification MUST consider both buffer HP and active repair. *(E2/E3.)*
- **R4.2** Where active and buffer disagree, the rule MUST be deterministic and
  documented.
- **R4.3** Classification MUST be exposed as a derived fact with its reasoning.

**R5 — Evidence and honesty**
- **R5.1** Every derived quantity reaching the LLM MUST be a `CombatEvidenceFact`
  with source and confidence.
- **R5.2** Derived facts MUST carry `EvidenceSource` distinguishing them from
  observed (log/killmail) facts.
- **R5.3** No derived quantity may be presented without its assumptions. **This is
  the Pathfinder rule: a plausible number with a hidden assumption is fabricated
  data.**
- **R5.4** `AarUnknown` entries MUST name the specific missing quantity and the
  evidence that would resolve it.

---

## 5. Acceptance criteria

### Derivation
- **AC1.1** A `FitEvidence` with a resolvable ship and ≥1 module yields non-zero
  `FittingStats`.
- **AC1.2** Derived stats for a given `Fitting` + skill context are byte-identical
  to the Fitting module's output for the same inputs.
- **AC1.3** Unresolvable ship type → `AarUnknown`, no panel, no exception.
- **AC1.4** Partial fit derives from present modules only; missing slots named.
- **AC1.5** Derivation is pure and synchronous given resolved SDE types
  (testable without network or DB).

### Skills
- **AC1.6** Pilot fit with known character uses that character's skills.
- **AC1.7** Victim fit uses All V and is labelled "assumes All V".
- **AC1.8** Confidence for an All-V-assumed fit is strictly lower than for a
  known-skills fit.

### EHP and matchup
- **AC2.1** EHP against a pure-EM profile on a 0% EM / 50% others fit equals raw
  HP (within 0.01). *Fails today.*
- **AC2.2** EHP against an even split equals the current flat-average result
  (within 0.01) — the summary row is preserved.
- **AC2.3** Matchup identifies the lowest-resist type carrying material incoming
  damage as `resistHole`.
- **AC2.4** Matchup percentages sum to 100% across resolved types.
- **AC2.5** Unresolvable weapons appear in `unknownWeapons` and are excluded from
  percentages.
- **AC2.6** Matchup is reachable from the AAR pipeline — `CombatDamageMatchupAnalyzer`
  has a non-test caller in `lib/`. *(Currently it has none.)*

### Tank layer
- **AC2.7** Active-armor fit with a larger shield buffer classifies as Armor.
- **AC2.8** Pure-buffer shield fit classifies as Shield.
- **AC2.9** `effectiveArmorRepair` / `effectiveShieldBoost` are non-zero for a fit
  with a working active module. *Fails today — never assigned.*
- **AC2.10** Classification reasoning is present in the derived fact.

### Capacitor
- **AC3.1** Cap-stable fit reports stable with a percentage.
- **AC3.2** Unstable fit reports seconds-to-empty.
- **AC3.3** Fit with no cap attributes renders a dash, not 0 — existing behaviour
  preserved.

### Evidence and UI
- **AC4.1** Every derived quantity shown in the UI has a corresponding ledger fact.
- **AC4.2** Derived facts are distinguishable from observed facts by source.
- **AC4.3** No-fit-evidence case shows no panel and ≥1 specific `AarUnknown`.
- **AC4.4** Both pilot and victim panels render when both fits are present.
- **AC4.5** The skill assumption is visible in the UI for any All-V-assumed fit.
- **AC4.6** Panel renders correctly in loading, error, and data states using
  `.when()` — never `.value ?? default` (CLAUDE.md).

### Regression
- **AC5.1** All existing fitting tests pass unchanged, including the
  real-SDE parity suite and production-wiring test.
- **AC5.2** All existing combat-analyzer tests pass; the matchup test still passes
  against any refactor.
- **AC5.3** `flutter analyze` clean.
- **AC5.4** All new code carries `Log.d/i/w/e` with `[AAR]` or `[FITTING]` tags
  (CLAUDE.md mandatory logging).

---

## 6. Test cases

Layering follows the pattern established by the fitting milestone: pure unit tests,
real-SDE parity tests, and production-wiring tests.

### Group A — Derivation service (unit)
| ID | Case | Setup | Expected |
|---|---|---|---|
| T1.1 | Full fit derives | Rifter + 3× 200mm AC + MSE | non-zero EHP, DPS, cap |
| T1.2 | Parity with Fitting module | Same `Fitting`, same skills, both paths | identical `FittingStats` (AC1.2) |
| T1.3 | Unresolvable ship | typeId not in SDE | `AarUnknown`; no throw |
| T1.4 | Empty fit | Hull only | base hull stats; no module contribution |
| T1.5 | Partial fit | Highs + 1 mid; rigs absent | derives; names missing slots |
| T1.6 | Unresolvable module | One bad typeId among good | others derive; bad one named |
| T1.7 | Purity | Pre-resolved types, no DB/network | returns synchronously |

### Group B — Skill context
| ID | Case | Setup | Expected |
|---|---|---|---|
| T2.1 | Known pilot skills | Character with real skills | uses them |
| T2.2 | Victim fit | Killmail-sourced | All V; labelled |
| T2.3 | Confidence ordering | Same fit, both contexts | known > assumed |
| T2.4 | Label reaches ledger | Victim fit | fact text contains the assumption |
| T2.5 | Skill effect is real | Same fit at All 0 vs All V | All V strictly higher EHP/DPS |

### Group C — EHP against a profile *(the E1 fix)*
| ID | Case | Setup | Expected |
|---|---|---|---|
| T3.1 | Pure EM vs zero EM resist | 0/50/50/50, 1000 armor HP, 100% EM incoming | EHP == 1000 (AC2.1) |
| T3.2 | Pure Exp vs 50% Exp | same fit, 100% Exp incoming | EHP == 2000 |
| T3.3 | Even split | same fit, 25/25/25/25 | == current flat-average result (AC2.2) |
| T3.4 | Realistic skew | 0/20/40/50, 78% kin / 19% therm / 3% em | computed per weighted profile; regression-locked |
| T3.5 | Zero resists | all 0 | EHP == raw HP for any profile |
| T3.6 | Summary is labelled | any fit | omni figure carries its label (AC2.2/R3.2) |

### Group D — Damage matchup
| ID | Case | Setup | Expected |
|---|---|---|---|
| T4.1 | Hole identified | resists 10/60/60/60, incoming mostly EM | EM == `resistHole` |
| T4.2 | Strong resist | resists 10/60/60/60, incoming mostly Kin | Kin == `strongResist` |
| T4.3 | Neutral | flat resists, even incoming | all `neutral` |
| T4.4 | No defense evidence | null defense | `unknown`; no fabricated entry |
| T4.5 | Percentages sum | mixed profile | sums to 100% ± 0.01 (AC2.4) |
| T4.6 | Unknown weapons excluded | one unresolvable weapon | in `unknownWeapons`, out of percentages (AC2.5) |
| T4.7 | Runs against derived layer | active-armor fit | uses armor resists, not shield (R3.3) |

### Group E — Tank layer *(E2/E3)*
| ID | Case | Setup | Expected |
|---|---|---|---|
| T5.1 | Active armor beats shield buffer | Myrmidon, LAR + LSE | Armor (AC2.7) |
| T5.2 | Pure shield buffer | 2× LSE, no active | Shield (AC2.8) |
| T5.3 | Active shield | Shield booster | Shield (active) |
| T5.4 | Dual tank | active armor + active shield | deterministic, documented (R4.2) |
| T5.5 | Hull tank | bulkheads only | Hull |
| T5.6 | Repair non-zero | any active module | `effectiveArmorRepair` > 0 (AC2.9) |
| T5.7 | Offline module excluded | active rep offline | repair == 0 |
| T5.8 | Reasoning present | any fit | classification fact carries reasoning (AC2.10) |

### Group F — Capacitor
| ID | Case | Setup | Expected |
|---|---|---|---|
| T6.1 | Stable | light fit | stable + percent (AC3.1) |
| T6.2 | Unstable | heavy fit | seconds-to-empty (AC3.2) |
| T6.3 | No cap attributes | capless hull | dash, not 0 (AC3.3) |
| T6.4 | Injectors | cap booster fitted | existing behaviour preserved |

### Group G — Evidence ledger
| ID | Case | Setup | Expected |
|---|---|---|---|
| T7.1 | Facts emitted | derived fit | ≥1 derived `CombatEvidenceFact` |
| T7.2 | Source distinguishes | derived + observed present | sources differ (AC4.2) |
| T7.3 | No fit → unknowns | no fit evidence | ≥1 specific `AarUnknown` (AC4.3) |
| T7.4 | Unknowns are specific | partial fit | names the missing quantity (R5.4) |
| T7.5 | Facts match UI | rendered panel | every shown value has a fact (AC4.1) |

### Group H — Real-SDE parity
| ID | Case | Setup | Expected |
|---|---|---|---|
| T8.1 | Known fit EHP | real SDE, fixed fit, All V | independently recomputed from raw attributes, `closeTo(0.01)` |
| T8.2 | Known fit resists | same | recomputed from resonance attrs |
| T8.3 | Known fit cap | same | matches `CapSimulator` |
| T8.4 | Carrier fit | fighters from prior milestone | fighter DPS present in derived stats |

### Group I — Production wiring
| ID | Case | Setup | Expected |
|---|---|---|---|
| T9.1 | Matchup has a live caller | grep `lib/` | non-test caller exists (AC2.6) |
| T9.2 | AAR pipeline derives | end-to-end with fit evidence | derived facts present in report input |
| T9.3 | Pipeline survives no fit | no evidence | completes; unknowns emitted |
| T9.4 | One engine | derivation path | routes through `DogmaEngine`, not a copy (R1.4) |

### Group J — UI
| ID | Case | Setup | Expected |
|---|---|---|---|
| T10.1 | Panel renders | fit evidence present | EHP/resists/cap/DPS visible |
| T10.2 | Loading state | delayed provider | spinner; no crash (AC4.6) |
| T10.3 | Error state | failing provider | error UI; no crash (AC4.6) |
| T10.4 | Absent when no fit | no evidence | no panel (AC4.3) |
| T10.5 | Both roles | pilot + victim | both panels (AC4.4) |
| T10.6 | Skill label visible | victim fit | "assumes All V" shown (AC4.5) |
| T10.7 | Names resolved | any fit | `itemNameProvider`, no raw "Item #1234" (CLAUDE.md) |

---

## 7. Risks and decisions needed

**D1 — Where does the derivation service live?** `combat_analyzer/data/` (it
resolves SDE types, so it is I/O-adjacent) versus `combat_analyzer/domain/` with
pre-resolved types injected. *Recommend the latter*: keeps it pure and matches
T1.7/AC1.5. **Arch's call.**

**D2 — Dual-tank classification rule (R4.2).** Needs a deterministic tiebreak.
*Recommend* highest effective sustained repair per layer, falling back to buffer
HP when neither layer is active. **Arch's call, must be documented.**

**D3 — Does the summary EHP row change?** E1 fixes profile-weighted EHP; the
existing flat-average figure remains valid as an omni-damage summary. *Recommend*
keeping it, labelled, so AC2.2 preserves the current UI row and the fix is additive.

**R1 — E1 is a behaviour change with user-visible effects.** Resist-hole claims
will move. That is the point, but any existing snapshot expectations will shift.
Mitigated by AC2.2 (summary row preserved) and AC5.1.

**R2 — All V for victim fits is an upper bound, and users will read it as fact.**
R2.3/R5.3 and AC1.7/AC4.5 exist specifically to counter this. Treat the labelling
as a correctness requirement, not a UI nicety.

**R3 — No ground truth.** Same limitation recorded in the fitting milestone: no
local pyfa to diff against. Parity tests verify internal consistency. A single
manual spot-check of one fit's EHP against pyfa or in-game would close this
cheaply, if the user has access.

**R4 — LLM prompt regression.** Supplying derived facts changes the input
distribution. The LLM may still assert unquantified claims. Out of scope to fully
solve; worth queuing a prompt-side follow-up.

---

## 8. Sequencing for Plan

1. **E1 + E2 + E3** — engine correctness fixes with Group C and E tests. Self-
   contained, no integration dependency, highest correctness value. Start here.
2. **W1 + W2** — derivation service + skill context, Groups A and B.
3. **W3 + W4** — matchup wiring + ledger facts, Groups D and G.
4. **W5** — UI panel, Group J.
5. **W6** — specific unknowns, remaining Group G.
6. **Parity + wiring** — Groups H and I as the closing gate.

Steps 1 and 2 are parallelisable. Step 3 depends on both.

---

## 9. Journal protocol on ship

- Move QUEUED P1 "AAR fit simulation and defense profile derivation" to
  `ARCHIVE.md` as SHIPPED.
- Record a LEARNINGS entry for the E1 finding — flat-average EHP hides resist
  holes — as a generalizable rule about averaging away the signal you are
  measuring.
- Queue: turret tracking / missile application in the matchup; LLM prompt
  follow-up (R4).
- Re-check QUEUED P1 "AAR evidence completeness score" — this milestone should
  make it substantially cheaper.
