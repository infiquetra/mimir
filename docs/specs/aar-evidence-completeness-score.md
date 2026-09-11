# Milestone Spec: AAR Evidence Completeness Score & Pre-Analysis Checklist

**Status.** Draft for Arch.
**Author.** Product.
**Date.** 2026-09-11.
**Priority.** P1 (QUEUED.md).
**Estimated effort.** One to two days (revised up from QUEUED's "half-day to a day"; see §0.2).
**Depends on.** Milestone 2 (AAR Fit Simulation & Defense Profile Derivation), merged to `develop`.
**Refs.** `docs/specs/aar-fit-simulation-and-defense-profiles.md`;
`lib/features/combat_analyzer/domain/combat_evidence_ledger.dart`;
`lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart`.

---

## 0. Grounding: what already exists

### 0.1 The enabling finding

The pre-analysis requirement — *score the evidence before spending AI tokens* — is
achievable today with **zero new data sources and zero token spend**, because
`aarFitDerivationsProvider` (`lib/features/combat_analyzer/data/combat_providers.dart:58`)
already runs the full derivation pipeline **independently of the LLM call**:

```
aarFitDerivationsProvider
  -> combatEnrichmentProvider        (killmail match, pilot/victim fit evidence)
  -> combatIncomingDamageProfileProvider
  -> combatDamageProfileProvider     (outgoing)
  -> CombatFitDerivationService.deriveForEncounter(...)
       -> AarDerivationBundle { self, opponent, selfMatchup, opponentMatchup, unknowns }
```

`CombatAnalysisService.analyzeEncounter()` calls the same service at
`combat_analysis_service.dart:255`, but it is not the only caller. **The score can be
computed from the provider path alone, before the user ever presses "Analyze With AI".**

This is the whole reason this milestone is cheap. It is a *presentation and policy*
milestone over data that Milestone 2 already produces.

### 0.2 What Milestone 2 already gives us

Every scoring dimension the QUEUED entry names has a concrete, already-populated source:

| Evidence dimension | Existing source | File |
| --- | --- | --- |
| Pilot fit present | `CombatEnrichment.pilotFitEvidence` (`FitEvidence`) | `combat_enrichment.dart` |
| Pilot fit provenance | `FitEvidence.source` / `.confidence` | `combat_evidence_ledger.dart` |
| Fit completeness (slots) | `AarFitCoverage` — per-slot fitted/total + `unresolvedTypeIds` | `aar_fit_derivation.dart` |
| Skill basis | `AarSkillContext.basis` (`knownCharacter` / `allFive`) | `aar_fit_derivation.dart` |
| Killmail match | `CombatEnrichmentStatus` + `matchConfidence` | `combat_enrichment.dart` |
| Opponent identity | `victimCharacterId` / `victimName` / `victimShipTypeId` | `combat_enrichment.dart` |
| Opponent fit derivation | `AarDerivationBundle.opponent` | `aar_fit_derivation.dart` |
| Damage profile quality | `CombatDamageProfile.entries[].confidence`, `.unknownWeapons` | `combat_damage_profile.dart` |
| Tank layer | `TankAssessment` (`layer`, `mode`) | `tank_classifier.dart` |
| Open unknowns | `AarDerivationBundle.unknowns`, `CombatEvidenceLedger.unknowns` | `combat_evidence_ledger.dart` |

**No new parsing, no new network calls, no new SDE work.** The milestone reads what
exists and renders a judgement about it.

### 0.3 The three CTAs already exist

`analysis_multipane_screen.dart:616-628` already renders exactly the three buttons the
brief asks for:

- "Import Pilot Fit" → `_showImportFitDialog()` (line 617)
- "Snapshot Current Fit" → `_captureCurrentFit(confirmed: false)` (line 622)
- "Use Current Fit For This Fight" → `_captureCurrentFit(confirmed: true)` (line 627)

They sit unconditionally in the evidence pane, below the killmail chips, with no
indication of *whether the user needs them*. A user with a complete AAR sees the same
three buttons as a user with no fit at all.

**The gap is not capability. It is that nothing tells the user which of these actions
would actually improve their analysis, or by how much.** That reframes the milestone:
we are adding *judgement and prioritisation* over existing affordances, not new
affordances.

### 0.4 Why the estimate moved from half-a-day to one-to-two days

QUEUED estimated half-a-day to a day. I am raising it to one to two days, because the
brief asks for four things beyond a checklist widget: a weighted scoring model with
defined statuses (§3), a pre-analysis gate with warn/advise behaviour (§2 S4), dynamic
recomputation (§2 S3), and re-analysis triggers driven by staleness (§2 S5). The
scoring model needs unit tests independent of UI, and the gate needs a decision about
whether it can ever *block*. Still a small milestone — but not a widget.

### 0.5 One structural limit, stated up front

**Range telemetry cannot be scored as "missing" and then fixed, because it is not
obtainable.** `CombatEvent` (`parsed_combat_encounter.dart`) carries `timestamp`,
`second`, `direction`, `kind`, `amount`, `targetName`, `weaponName`, `hitQuality`, and
`rawLine` — and no distance field. A grep for `range|distance|optimal` across the parser
and encounter model returns nothing. EVE's combat log format does not emit engagement
range.

This matters for the scoring model's integrity. If range were scored as a *missing item*
alongside "pilot fit", the checklist would show a permanently unfixable red row, and a
score that can never reach 100%. That trains users to ignore the score — the precise
failure mode this milestone exists to prevent.

**Rule:** range is a **structural limitation**, displayed in a separate "Known limits"
section, excluded from the denominator. See R3.4.

---

## 1. Product perspective

### 1.1 The problem in user terms

A user opens an encounter and presses "Analyze With AI". Thirty seconds and some tokens
later they get back coaching prose that says things like "consider whether your tank was
appropriate for the damage you faced" — vague, hedged, and unsatisfying.

The reason is usually knowable *before the call was made*: there was no pilot fit
attached, so the analyzer had no EHP, no resists, and no tank layer to reason about. The
user had a one-click "Use Current Fit For This Fight" button sitting right there, and
nothing told them it mattered.

So the user pays twice: once in tokens for a weak analysis, and once in effort
re-analyzing after they figure out what was missing. Worse, some users never figure it
out — they conclude the feature is mediocre and stop using it.

### 1.2 The governing principle

Milestone 2 established:

> Every quantitative claim in an AAR must be attributable to a derivation the user can
> inspect, or explicitly labelled as an unknown.

This milestone extends it forward in time:

> **The user must be able to see what the analysis will and will not be able to
> conclude — before they spend anything on it — and must be told which single action
> would most improve it.**

The emphasis on *which single action* is deliberate. A checklist that lists six missing
things is a to-do list, and users don't do to-do lists. A checklist that says "attaching
your fit would take this from 45% to 80%" is a recommendation, and users act on
recommendations.

### 1.3 What changes for the user

**Before:** Open encounter → "Analyze With AI" → get prose → maybe notice unknowns
buried at the bottom → maybe find the fit buttons → re-analyze.

**After:** Open encounter → see "Evidence 45% — Partial" with a checklist showing
*Pilot fit: Missing* as the top-ranked gap and a button right on that row → attach fit →
watch the score move to 80% → analyze once, with confidence about what you'll get.

### 1.4 Non-goals

- **Not** blocking analysis. The user may always analyze at any score (D1).
- **Not** a new evidence source. No new parsing, network calls, or scrapers.
- **Not** re-scoring historical reports retroactively on upgrade (R4.5 covers display).
- **Not** changing the LLM prompt schema. Prompt v4 stays as shipped in Milestone 2.
- **Not** automatic re-analysis. Staleness is surfaced; the user decides (S5).
- **Not** fixing range telemetry (§0.5).

---

## 2. User scenarios

### S1 — Initial encounter review, before any AI spend

Jeff opens a solo loss from last night. Before pressing anything, the top of the evidence
pane shows:

> **Evidence completeness: 45% — Partial**
> Analysis will be able to name what killed you, but not whether your tank was the
> problem.

Below it, a checklist:

- ✅ **Combat log** — Complete · 412 events, 6 damage types resolved
- ✅ **Opponent identity** — Complete · Killmail #1234567 matched (92% confidence)
- ⚠️ **Damage profile** — Partial · 2 of 14 weapons unresolved
- ❌ **Pilot fit** — Missing · *[Use Current Fit] [Import Fit]*
- ⚠️ **Opponent fit** — Inferred · Killmail shows destroyed modules only

He can see, without spending anything, that the single highest-value action is attaching
his fit.

**Acceptance.** AC1.1, AC1.2, AC2.1, AC4.1, AC4.2.

### S2 — Resolving the top-ranked gap

Jeff clicks **[Use Current Fit]** directly on the "Pilot fit" row — he doesn't have to
hunt for a button elsewhere in the pane. The row changes to:

- ✅ **Pilot fit** — Complete · Current ship snapshot, confirmed for this fight

and the header moves to **80% — Good**. The "Opponent fit" row stays at Inferred, with
its detail text explaining this is a killmail limit, not something he can fix.

**Acceptance.** AC2.2, AC3.1, AC3.2, AC4.3.

### S3 — The score updates without a reload

The recomputation in S2 happens because the underlying providers invalidate, not because
the user refreshed. Attaching a fit, matching a killmail, or importing EFT all move the
score within the same screen session, with no full-screen spinner and no navigation.

**Acceptance.** AC3.1, AC3.3, AC5.4.

### S4 — The pre-analysis gate

Three cases, all non-blocking:

**Low (< 40%).** The "Analyze With AI" button is still enabled, but a warning sits
immediately above it:

> ⚠️ Analysis at 25% evidence will produce general coaching, not specific fit advice.
> Attaching your fit would raise this to about 60%.

**Partial (40–74%).** An advisory, not a warning:

> Analysis will cover damage and timeline. Fit-specific conclusions will be limited.

**Good (≥ 75%).** No interruption. The button reads "Analyze With AI" with the score
shown as a quiet chip.

At every band the user can proceed in one click. The warning never becomes a
confirmation dialog (D1).

**Acceptance.** AC5.1, AC5.2, AC5.3.

### S5 — Post-analysis review and re-analysis triggers

Jeff analyzed at 45%, then attached his fit afterward. The completed report now shows:

> This report was generated at 45% evidence. Evidence is now 80%. **[Re-analyze]**

The stored report keeps the score it was generated at — that figure is a property of the
report, not of the encounter's current state. The delta is what prompts re-analysis.

If evidence has not changed since generation, no prompt appears.

**Acceptance.** AC6.1, AC6.2, AC6.3.

### S6 — The genuinely irreducible encounter

A log-only encounter with no killmail, an unknown opponent, and an unresolvable ship.
The score reaches 50% and stops. Rather than showing three red rows the user cannot fix,
the checklist marks the opponent rows as **Unavailable** with reasons, and the header
reads:

> **Evidence completeness: 50% — Partial (capped)**
> No killmail exists for this encounter. Opponent details cannot be recovered.

The user learns the ceiling is a fact about the fight, not their negligence.

**Acceptance.** AC1.4, AC4.4, R3.5.

### S7 — The complete case

Pilot fit confirmed, killmail matched, opponent derived, all weapons resolved, ESI
skills present. Score reads **100% — Complete**. The checklist collapses to a single
summary row by default (expandable), so the user with good evidence isn't nagged.

**Acceptance.** AC1.3, AC4.5.

---

## 3. The completeness scoring model

### 3.1 Design constraints

1. **Deterministic.** Same inputs → same score, always. No randomness, no LLM.
2. **Explainable.** Every point is attributable to a named dimension. A user asking
   "why 45%?" must be able to read the answer off the checklist.
3. **Monotonic.** Adding evidence never lowers the score (R3.3).
4. **Bounded honestly.** Structural limits shrink the denominator rather than parking
   the score below 100% forever (R3.4, R3.5).

### 3.2 Dimensions and weights

Five dimensions, 100 points total:

| # | Dimension | Weight | Rationale |
| --- | --- | --- | --- |
| D1 | **Pilot fit** | 30 | The single largest determinant of analysis quality. Without it there is no EHP, no resists, no tank layer, no cap. |
| D2 | **Combat log telemetry** | 20 | Always present (the encounter exists because a log was parsed), but quality varies with event count and duration. |
| D3 | **Opponent identity** | 15 | Killmail match. Establishes who, what ship, and the fight's outcome framing. |
| D4 | **Opponent fit** | 20 | Enables the matchup — what the pilot's damage was actually up against. |
| D5 | **Damage profile** | 15 | Resolution of weapon → damage type. Drives resist-hole analysis. |

**Why pilot fit is weighted highest.** Milestone 2's entire value — EHP against the
actual incoming profile, tank classification, cap simulation — is unreachable without it.
An AAR without a pilot fit cannot answer "should I have survived this?", which is the
question users are actually asking.

**Why opponent fit (20) outranks opponent identity (15).** Knowing it was a Hurricane is
worth less than knowing the Hurricane's resists. Identity is a prerequisite, but the fit
is what feeds the matchup.

### 3.3 Statuses

Each dimension resolves to exactly one status, with a fixed credit fraction:

| Status | Credit | Meaning | Example |
| --- | --- | --- | --- |
| **Complete** | 100% | Direct evidence, high confidence | Pilot fit confirmed for this fight |
| **Partial** | 50% | Evidence present but incomplete or low-confidence | Fit attached but 3 slots unresolved in SDE |
| **Inferred** | 30% | Derived from indirect evidence; usable but assumption-laden | Victim fit from killmail (destroyed/dropped only); All V skills |
| **Missing** | 0% | Obtainable but absent — **actionable** | No pilot fit attached |
| **Unavailable** | excluded | Not obtainable for this encounter — **not actionable** | No killmail exists; range telemetry |

**Unavailable is the important one.** It removes the dimension's weight from the
denominator entirely rather than scoring zero. This is what makes S6's "capped" case
honest: a user whose fight has no killmail is not penalised for a fact about the universe.

### 3.4 Computation

```
earned     = Σ (weight_d × credit(status_d))   for d where status_d ≠ Unavailable
available  = Σ  weight_d                        for d where status_d ≠ Unavailable
score      = round(100 × earned / available)    // 0 if available == 0
capped     = any status_d == Unavailable
```

### 3.5 Confidence bands

| Band | Range | Label | Meaning for the user |
| --- | --- | --- | --- |
| **Complete** | 90–100 | Complete | Fit-specific, quantitative conclusions available |
| **Good** | 75–89 | Good | Most conclusions supported; minor gaps |
| **Partial** | 40–74 | Partial | Damage and timeline solid; fit conclusions limited |
| **Low** | 0–39 | Low | General coaching only |

When `capped` is true, the band label gains the suffix " (capped)" (S6).

### 3.6 Per-dimension status rules

**D1 — Pilot fit (30)**

- **Complete** — `pilotFitEvidence != null` AND `confidence` ∈ {`proven`, `confirmed`}
  AND derivation succeeded AND `coverage.hasUnresolved == false`.
- **Partial** — fit present and derived, but `coverage.hasUnresolved == true`, or
  `AarSkillBasis.allFive` for the pilot's own fit (skills are knowable via ESI).
- **Inferred** — fit present with `confidence == derived`/`reference` (e.g. unconfirmed
  snapshot taken at a different time than the fight).
- **Missing** — `pilotFitEvidence == null`, or derivation returned
  `AarFitDerivationFailed`.
- **Unavailable** — never. A pilot fit is always in principle obtainable.

**D2 — Combat log telemetry (20)**

- **Complete** — parsed encounter with ≥ 20 damage events AND both incoming and
  outgoing damage present.
- **Partial** — parsed but one-directional, or < 20 damage events.
- **Missing** — never (the encounter would not exist).
- **Unavailable** — never.

*Note:* range is **not** part of D2's score. See R3.4.

**D3 — Opponent identity (15)**

- **Complete** — `status == killmailMatched` AND `matchConfidence >= 0.8`.
- **Partial** — `killmailMatched` with `matchConfidence < 0.8`, or `ambiguous`.
- **Inferred** — opponent named from combat log actors only, no killmail.
- **Missing** — `needsReauth` (actionable: the user can reauthorize).
- **Unavailable** — `logOnly` after a completed search found no candidate killmail.

**D4 — Opponent fit (20)**

- **Complete** — `bundle.opponent != null` AND derived from a non-killmail source with
  full slot coverage (rare; e.g. a manually imported known opponent fit).
- **Inferred** — `bundle.opponent != null` derived from killmail (the common good case).
  Killmails prove destroyed and dropped items only, so this is capped at Inferred by
  construction.
- **Partial** — opponent ship type known but fit derivation failed or coverage is thin.
- **Missing** — opponent identified but no fit evidence and no killmail fit.
- **Unavailable** — D3 is Unavailable (no opponent to have a fit).

**D5 — Damage profile (15)**

- **Complete** — `unknownWeapons.isEmpty` AND all entries have `confidence` ∈
  {`observed`, `sdeExact`}.
- **Partial** — `unknownWeapons.isNotEmpty` but ≥ 70% of profiled damage is typed, or
  entries include `modelInferred`.
- **Inferred** — < 70% of damage typed.
- **Missing** — `hasKnownDamageTypes == false`.
- **Unavailable** — never.

### 3.7 Worked example (S1)

| Dimension | Status | Weight | Credit | Earned |
| --- | --- | --- | --- | --- |
| D1 Pilot fit | Missing | 30 | 0% | 0 |
| D2 Combat log | Complete | 20 | 100% | 20 |
| D3 Opponent identity | Complete | 15 | 100% | 15 |
| D4 Opponent fit | Inferred | 20 | 30% | 6 |
| D5 Damage profile | Partial | 15 | 50% | 7.5 |
| | | **100** | | **48.5** |

`score = round(100 × 48.5 / 100) = 49` → **Partial**.

After S2 (pilot fit → Complete, +30): `78.5` → **79 — Good**. This is the projection the
S1 checklist must show on the pilot-fit row ("would raise this to about 79%").

---

## 4. UI/UX requirements

All UI lands in `lib/features/combat_analyzer/presentation/`.

### 4.1 Placement

A new `AarEvidenceChecklistCard` widget, rendered at the **top of the evidence pane** in
`analysis_multipane_screen.dart`, above the existing killmail chips (currently ~line 560).
It appears in both pre-analysis and post-analysis states.

The score also appears as a compact chip next to the "Analyze With AI" button in
`_buildAnalyzePrompt()` (~line 273), so a user on the empty-state screen sees it without
scrolling.

### 4.2 Card anatomy

```
┌────────────────────────────────────────────────────────┐
│ Evidence Completeness              [ 49% ] Partial      │
│ ████████████░░░░░░░░░░░░░░                              │
│ Analysis will cover damage and timeline. Fit-specific   │
│ conclusions will be limited.                            │
├────────────────────────────────────────────────────────┤
│ ❌ Pilot fit            Missing                          │
│    No fit attached for this fight. +30 points           │
│    [Use Current Fit]  [Import Fit]                      │
│ ⚠️ Damage profile       Partial                          │
│    2 of 14 weapons unresolved                           │
│ ⚠️ Opponent fit         Inferred                         │
│    Killmail shows destroyed and dropped modules only    │
│ ✅ Opponent identity    Complete                         │
│    Killmail #1234567 matched (92%)                      │
│ ✅ Combat log           Complete                         │
│    412 events over 96s, both directions                 │
├────────────────────────────────────────────────────────┤
│ Known limits                                            │
│ • Engagement range is not recorded in EVE combat logs.  │
└────────────────────────────────────────────────────────┘
```

### 4.3 Ordering

Rows sort by **actionability, then impact**: `Missing` first (descending weight), then
`Partial`, then `Inferred`, then `Complete`, then `Unavailable`. The user's most valuable
next action is always the top row.

### 4.4 Visual cues

Use `EveColors` (matching `aar_derived_stats_panel.dart`):

| Status | Icon | Colour |
| --- | --- | --- |
| Complete | `Icons.check_circle` | `EveColors.success` |
| Partial | `Icons.warning_amber` | `EveColors.warning` |
| Inferred | `Icons.help_outline` | `EveColors.warning` |
| Missing | `Icons.cancel_outlined` | `EveColors.error` |
| Unavailable | `Icons.block` | `EveColors.textSecondary` |

Progress bar colour follows the band: Low → error, Partial → warning, Good/Complete →
success.

### 4.5 Actions

Action buttons render **inline on the row they fix** — not in a separate button cluster.
They reuse the existing handlers unchanged:

| Row | Buttons | Existing handler |
| --- | --- | --- |
| Pilot fit (Missing/Inferred) | "Use Current Fit", "Import Fit" | `_captureCurrentFit(confirmed: true)`, `_showImportFitDialog()` |
| Opponent identity (Missing/needsReauth) | "Reauthorize Character" | `authControllerProvider.notifier.startAuthFlow()` |
| Opponent identity (logOnly) | "Search Killmails" | existing enrichment refresh |

The existing three-button `Wrap` at lines 616-628 is **removed** once its actions are
reachable from the checklist, to avoid two competing affordances for the same thing (D3).

### 4.6 Collapse behaviour

At **Complete** (≥ 90%) the row list collapses by default to just the header and an
expand affordance (S7). Below 90% it is expanded by default. User expand/collapse state
is per-screen-session only; not persisted.

### 4.7 Loading and error states

Per CLAUDE.md, the card watches an `AsyncValue` and MUST use `.when(data:, loading:,
error:)`:

- **loading** — skeleton card with an indeterminate progress bar and "Assessing
  evidence…". Never a bare spinner that hides the pane.
- **error** — the card renders with the header reading "Evidence assessment
  unavailable" and does **not** block or disable the analyze button. A scoring failure
  must never prevent analysis.

---

## 5. Normative rules

### R1 — Determinism and purity

- **R1.1** The scoring model MUST live in `domain/` as a pure function of already-derived
  inputs. No I/O, no provider reads, no `DateTime.now()` inside the scorer.
- **R1.2** The same `(CombatEnrichment, AarDerivationBundle, CombatDamageProfile ×2,
  ParsedCombatEncounter)` tuple MUST always produce an identical `AarEvidenceAssessment`.
- **R1.3** Weights and thresholds MUST be named constants in one place, not literals
  scattered across the scorer.

### R2 — Zero-cost pre-analysis

- **R2.1** Computing the score MUST NOT trigger an LLM call.
- **R2.2** Computing the score MUST NOT trigger new network I/O beyond what
  `aarFitDerivationsProvider` already performs for the screen.
- **R2.3** The score MUST be available before the user presses "Analyze With AI".

### R3 — Honest accounting

- **R3.1** Every dimension's status MUST be traceable to a named field on an existing
  model (§0.2 table). No heuristic that cannot be pointed at a source.
- **R3.2** Detail text on each row MUST cite the concrete evidence ("Killmail #1234567
  matched (92%)"), never a bare status word.
- **R3.3** **Monotonicity:** adding evidence MUST NOT lower the score. Any change that
  could (e.g. attaching a fit that reveals unresolved modules) MUST resolve upward —
  a newly-attached fit with unresolved slots is `Partial` (15 pts), never worse than
  `Missing` (0 pts).
- **R3.4** Structural limitations (range telemetry) MUST NOT appear as scored rows. They
  appear in a "Known limits" section and are excluded from the denominator.
- **R3.5** `Unavailable` MUST reduce the denominator, and the band label MUST carry the
  "(capped)" suffix so a user never reads a capped 100% as equivalent to a true 100%.

### R4 — Report provenance

- **R4.1** A generated report MUST record the completeness score at generation time.
- **R4.2** The recorded score MUST NOT be recomputed on display; it is a historical fact.
- **R4.3** Re-analysis MUST be offered when current score exceeds recorded score by
  ≥ 10 points.
- **R4.4** Re-analysis MUST NOT be automatic.
- **R4.5** Reports generated before this milestone have no recorded score. They MUST
  display "Evidence at generation: not recorded" and MUST NOT be presented as 0%.

### R5 — Non-blocking

- **R5.1** No score value may disable the "Analyze With AI" button.
- **R5.2** No score value may introduce a confirmation dialog.
- **R5.3** A scoring error MUST NOT block analysis (§4.7).

### R6 — Logging

- **R6.1** Per CLAUDE.md, every public method entry logs with tag `[AAR.EVIDENCE]`.
- **R6.2** The computed score, band, and per-dimension statuses MUST be logged at
  `Log.i` on each computation, so a user-reported "why is my score 45%?" is diagnosable
  from logs alone.

---

## 6. Acceptance criteria

### AC1 — Scoring model

- **AC1.1** Given the S1 evidence state, the scorer returns 49 and band `Partial`.
- **AC1.2** Each of the five dimensions returns a status from the §3.3 enum and a detail
  string citing concrete evidence.
- **AC1.3** Given full evidence (S7), the scorer returns 100 and band `Complete`.
- **AC1.4** Given `logOnly` with no killmail (S6), D3 and D4 are `Unavailable`, the
  denominator is 65, and `capped == true`.
- **AC1.5** The scorer is a pure function: no I/O, no provider reads, callable from a
  plain Dart unit test with no Flutter binding.
- **AC1.6** Weights sum to exactly 100.

### AC2 — Checklist display

- **AC2.1** The card renders at the top of the evidence pane, above the killmail chips.
- **AC2.2** Rows are ordered Missing → Partial → Inferred → Complete → Unavailable, with
  descending weight inside each group.
- **AC2.3** Each row shows icon, dimension name, status word, and detail text.
- **AC2.4** `Missing` rows show a point-gain projection ("+30 points").
- **AC2.5** The "Known limits" section lists range telemetry and is visually separated
  from the scored rows.

### AC3 — Dynamic update

- **AC3.1** Attaching a pilot fit updates the score without navigation or a full reload.
- **AC3.2** The pilot-fit row transitions Missing → Complete and moves to the bottom
  group.
- **AC3.3** The progress bar and band label update in the same frame as the rows.
- **AC3.4** Monotonicity holds: no evidence-adding action lowers the displayed score.

### AC4 — Actions

- **AC4.1** "Use Current Fit" and "Import Fit" render inline on a Missing pilot-fit row.
- **AC4.2** Those buttons invoke the existing handlers with unchanged behaviour.
- **AC4.3** After the action succeeds, the buttons disappear from the row.
- **AC4.4** `Unavailable` rows render no action buttons and state why.
- **AC4.5** At ≥ 90% the row list is collapsed by default and expandable.
- **AC4.6** The old three-button `Wrap` at lines 616-628 no longer renders.

### AC5 — Pre-analysis gate

- **AC5.1** Below 40%, a warning renders directly above the analyze button naming the
  highest-value missing evidence and its projected gain.
- **AC5.2** At 40–74%, an advisory renders describing what analysis will and will not
  cover.
- **AC5.3** At ≥ 75%, no warning or advisory renders; a quiet score chip appears.
- **AC5.4** At every band, the analyze button is enabled and reachable in one click.

### AC6 — Post-analysis and re-analysis

- **AC6.1** A completed report displays the score recorded at generation time.
- **AC6.2** When current score ≥ recorded + 10, a re-analyze prompt appears showing both
  figures.
- **AC6.3** When current score < recorded + 10, no prompt appears.
- **AC6.4** Pre-milestone reports show "not recorded", not 0%.

### AC7 — Regression

- **AC7.1** All existing combat_analyzer tests pass unchanged.
- **AC7.2** `flutter analyze` is clean.
- **AC7.3** Prompt v4 schema is unchanged — verified by the existing prompt tests.
- **AC7.4** `analyzeEncounter()` behaviour is unchanged except for recording the score.

---

## 7. Test cases

Following the Milestone 2 layering: pure unit → wiring → UI.

### Group A — Scoring model (pure unit, no Flutter binding)

`test/features/combat_analyzer/domain/aar_evidence_scorer_test.dart`

- **T1.1** Weights sum to 100.
- **T1.2** All-Complete → 100, band `Complete`, `capped == false`.
- **T1.3** S1 fixture → 49, band `Partial`.
- **T1.4** S1 + pilot fit Complete → 79, band `Good`.
- **T1.5** All-Missing (D1, D3, D4, D5 Missing; D2 Complete) → 20, band `Low`.
- **T1.6** D3 + D4 Unavailable → denominator 65; pilot fit Complete + log Complete +
  profile Complete → 100, `capped == true`, band label ends "(capped)".
- **T1.7** All dimensions Unavailable → score 0, no divide-by-zero.
- **T1.8** Determinism: 100 invocations on the same input return identical results.
- **T1.9** Monotonicity: for each dimension, upgrading its status never lowers the total.
- **T1.10** Credit fractions match §3.3 exactly (Complete 1.0, Partial 0.5, Inferred 0.3,
  Missing 0.0).

### Group B — Per-dimension status rules

`test/features/combat_analyzer/domain/aar_evidence_dimensions_test.dart`

- **T2.1** D1 Complete: `pilotFitEvidence.confidence == confirmed`, derivation present,
  `coverage.hasUnresolved == false`.
- **T2.2** D1 Partial: fit derived with `unresolvedTypeIds.isNotEmpty`.
- **T2.3** D1 Partial: pilot fit derived under `AarSkillBasis.allFive`.
- **T2.4** D1 Missing: `pilotFitEvidence == null`.
- **T2.5** D1 Missing: derivation returned `AarFitDerivationFailed`.
- **T2.6** D2 Complete: 25 damage events, both directions.
- **T2.7** D2 Partial: outgoing damage only.
- **T2.8** D2 Partial: 8 damage events.
- **T2.9** D3 Complete: `killmailMatched`, `matchConfidence = 0.92`.
- **T2.10** D3 Partial: `killmailMatched`, `matchConfidence = 0.55`.
- **T2.11** D3 Partial: `ambiguous`.
- **T2.12** D3 Missing: `needsReauth` (actionable).
- **T2.13** D3 Unavailable: `logOnly`.
- **T2.14** D4 Inferred: `bundle.opponent` derived from killmail evidence.
- **T2.15** D4 Missing: opponent identified, no fit.
- **T2.16** D4 Unavailable: D3 Unavailable.
- **T2.17** D5 Complete: `unknownWeapons` empty, all entries `sdeExact`.
- **T2.18** D5 Partial: 2 of 14 unknown, 85% of damage typed.
- **T2.19** D5 Inferred: 60% of damage typed.
- **T2.20** D5 Missing: `hasKnownDamageTypes == false`.
- **T2.21** Every status carries non-empty detail text citing concrete evidence (R3.2).

### Group C — Range exclusion

`test/features/combat_analyzer/domain/aar_evidence_limits_test.dart`

- **T3.1** No scored dimension references range.
- **T3.2** The assessment exposes a `structuralLimits` list containing the range entry.
- **T3.3** Range never affects `earned` or `available`.
- **T3.4** A 100% assessment still lists the range limit.

### Group D — Report provenance

`test/features/combat_analyzer/data/combat_analysis_service_test.dart` (extend)

- **T4.1** `analyzeEncounter()` records the score on the stored report.
- **T4.2** The recorded score is not recomputed on load.
- **T4.3** A report loaded without a recorded score reports "not recorded", not 0.
- **T4.4** Re-analysis offered when current ≥ recorded + 10.
- **T4.5** Not offered at recorded + 9.
- **T4.6** Prompt v4 payload is byte-identical to pre-milestone output for the same input
  (AC7.3).

### Group E — Provider wiring

`test/features/combat_analyzer/data/aar_evidence_provider_test.dart`

- **T5.1** The assessment provider resolves from `aarFitDerivationsProvider` +
  `combatEnrichmentProvider` without invoking the analysis client.
- **T5.2** A mock analysis client records **zero** calls during scoring (R2.1).
- **T5.3** Invalidating the enrichment provider recomputes the assessment.
- **T5.4** Scoring succeeds for an encounter with no enrichment row
  (`AarDerivationBundle.empty()`).

### Group F — Checklist widget

`test/features/combat_analyzer/presentation/aar_evidence_checklist_card_test.dart`

- **T6.1** Renders five rows for a fully-scored assessment.
- **T6.2** Row order matches AC2.2.
- **T6.3** A Missing pilot-fit row renders "Use Current Fit" and "Import Fit".
- **T6.4** A Complete pilot-fit row renders no buttons.
- **T6.5** An Unavailable row renders no buttons and shows its reason.
- **T6.6** Point projection renders on Missing rows.
- **T6.7** At 100% the list is collapsed; tapping expands it.
- **T6.8** Loading state renders the skeleton, not a bare spinner (§4.7).
- **T6.9** Error state renders the card and does not disable analysis (R5.3).
- **T6.10** "Known limits" section renders the range entry.
- **T6.11** Progress bar colour matches the band.

### Group G — Gate behaviour

`test/features/combat_analyzer/presentation/aar_pre_analysis_gate_test.dart`

- **T7.1** At 25%, a warning renders above the analyze button naming pilot fit.
- **T7.2** At 55%, an advisory renders, not a warning.
- **T7.3** At 85%, neither renders; the score chip does.
- **T7.4** The analyze button is enabled at 0%, 25%, 55%, 85%, and 100%.
- **T7.5** No confirmation dialog appears at any score (R5.2).

### Group H — Screen integration

`test/features/combat_analyzer/presentation/analysis_multipane_evidence_test.dart`

- **T8.1** The card renders above the killmail chips.
- **T8.2** The old three-button `Wrap` no longer renders (AC4.6).
- **T8.3** Tapping "Use Current Fit" on the row invokes the existing capture path.
- **T8.4** After capture, the score rises and the row moves.
- **T8.5** The score chip renders next to the analyze button in the empty state.

### Group I — Logging

- **T9.1** Scoring emits `Log.i` with tag `[AAR.EVIDENCE]` including score, band, and
  per-dimension statuses (R6.2).

---

## 8. Decisions for Arch

### D1 — Can the gate ever block? **Recommend: no.**

A hard block would be defensible (it saves tokens) but wrong here. The user may
legitimately want general coaching on a fight where evidence is irrecoverable (S6), and
a tool that refuses to run is a tool users route around. Warn clearly, never block.
Encoded as R5.1–R5.3 — Arch should flag if they disagree before implementing.

### D2 — Where does the recorded score live? **Recommend: on the report.**

Options: (a) a column on the stored analysis row, (b) a field inside `CombatAarReport`,
(c) recompute-on-load. (c) violates R4.2 — it would rewrite history every time evidence
changed. Between (a) and (b), (b) keeps the score travelling with the report through
serialization, but touches the report model that prompt v4 consumes. Arch should verify
(b) does not alter the prompt payload (T4.6 guards this); if it does, take (a).

### D3 — Remove the old button cluster, or keep both? **Recommend: remove.**

Two affordances for the same action, one of which knows whether you need it and one of
which doesn't, is worse than either alone. AC4.6 asserts removal. The risk is muscle
memory for existing users — acceptable, since the new location is strictly more
discoverable (it sits on the row explaining why you'd want it).

### D4 — Should weights be user-configurable? **Recommend: no, not in V1.**

Tempting, but a configurable score is not comparable across encounters and invites
users to tune away inconvenient gaps. Revisit only if users report the weighting
mismatches their play style.

---

## 9. Risks

### R1 — The score becomes a target rather than a signal

Users may chase 100% for its own sake, attaching a stale current-ship snapshot to a
week-old fight just to clear the red row. This produces *worse* analysis than an honest
Missing, because the derivation would then be confidently wrong.

**Mitigation.** The `Inferred` status exists precisely for this. An unconfirmed snapshot
scores 30%, not 100%, and its detail text says why. AC1.2 and R3.2 require the row to
name the provenance. Arch should ensure `_captureCurrentFit(confirmed: false)` maps to
`Inferred`, not `Complete`.

### R2 — Weight calibration is a product judgement, not a measurement

The 30/20/15/20/15 split is reasoned (§3.2) but not empirically validated. We have no
data showing a 79% analysis is meaningfully better than a 49% one.

**Mitigation.** Accept for V1; the bands are coarse enough that modest weight errors do
not change the band. R6.2's logging gives us the data to recalibrate later. Do not
present the number as more precise than it is — this is why bands are labelled in words
in the header, with the percentage secondary.

### R3 — Monotonicity has a real failure mode

Attaching a pilot fit that contains modules missing from the bundled SDE moves D1 from
Missing (0 pts) to Partial (15 pts) — fine. But it could also, in principle, change D5 or
D4 if the scorer read fit data into those dimensions.

**Mitigation.** Keep dimensions strictly independent: no dimension may read another's
inputs. T1.9 tests this exhaustively per dimension.

### R4 — "Capped" is a subtle concept

A capped 100% and a true 100% mean different things, and the distinction is carried by a
parenthetical suffix.

**Mitigation.** R3.5 plus AC1.4. If Arch finds the suffix too subtle in practice, a
distinct band colour for capped states is an acceptable alternative — flag it rather
than dropping the distinction.

---

## 10. Sequencing for Plan

Steps 1 and 2 are parallelisable; the rest are sequential.

1. **[P1] Domain scorer.** `AarEvidenceAssessment`, `AarEvidenceDimension`,
   `AarEvidenceStatus`, and the pure `AarEvidenceScorer`. Groups A, B, C.
2. **[P1] Report provenance.** Recorded-score field per D2, plus re-analysis threshold
   logic. Group D.
3. **[SEQ] Provider wiring.** `aarEvidenceAssessmentProvider` composed from existing
   providers. Group E. *Depends on 1.*
4. **[SEQ] Checklist card.** `AarEvidenceChecklistCard` + row widget. Group F.
   *Depends on 3.*
5. **[SEQ] Gate and screen integration.** Warning/advisory above the analyze button,
   card placement, removal of the old `Wrap`. Groups G, H. *Depends on 4.*
6. **[SEQ] Logging and regression.** Group I, AC7 sweep, `flutter analyze`.

---

## 11. Journal protocol on ship

- Move the QUEUED P1 entry "AAR evidence completeness score and pre-analysis checklist"
  to `ARCHIVE.md` as SHIPPED, noting the revised effort (§0.4) and the range finding
  (§0.5).
- Record a LEARNINGS entry for §0.5: EVE combat logs carry no engagement range, so range
  is a structural limit rather than a fixable gap. This constrains any future
  range-dependent analysis (notably the QUEUED P2 "Turret tracking and missile
  application in AAR damage matchup", which will need a different basis for target
  distance).
- Queue as P3: weight recalibration from logged score distributions (R2).
- Queue as P3: persisting checklist expand/collapse preference (§4.6).
