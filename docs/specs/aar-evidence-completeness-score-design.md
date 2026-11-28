# Design: AAR Evidence Completeness Score & Pre-Analysis Checklist

**Status.** Design for Plan.
**Author.** Arch.
**Date.** 2026-09-11.
**Companion to.** `docs/specs/aar-evidence-completeness-score.md` (Product, "the spec").
**Base.** `develop` at 855ba5b (Milestone 2 shipped: U0–U5, journal closed).
**Scope.** The spec's WHAT stands. This document is the HOW: exact data contracts,
scoring rules with worked numbers, provider composition, widget anatomy, test
specifications the test-author can transcribe, and a TDD unit breakdown for Plan.

---

## 0. Evidence that changes the product spec — read first

The spec's premise (§0.1: the score is computable from `aarFitDerivationsProvider`
with zero new I/O) holds. Reading the code the spec binds to shows eight places
where the spec's rules do not line up with what the models actually carry. None is
expensive; all are resolved below and carried into the tests.

| # | Spec claim | What the code says | Resolution |
|---|---|---|---|
| C1 | §4.1 "top of the evidence pane … in both pre-analysis and post-analysis states"; §4.1 "chip next to the button in `_buildAnalyzePrompt`" | Pre-analysis there **is no evidence pane**. `_buildAnalyzePrompt()` (`analysis_multipane_screen.dart:228-283`) is a centred empty state: icon, five stat chips, one `FilledButton`. The evidence card and the three fit buttons live only in `_buildAnalysisContent()` (post-analysis, line 363+). | The full checklist card renders in **both** places (§5.4). Pre-analysis it sits between the stat chips and the gate; the CTAs are most valuable there, which is the point of the milestone. |
| C2 | S1: before pressing anything, "Opponent identity — Complete · Killmail #1234567 matched" | `combatEnrichmentProvider` only **loads the cached row** (`combat_providers.dart`, `loadEnrichment`). The killmail search (`enrichEncounter`) runs only inside `analyzeEncounter()` stage 4. Before the first analysis the row does not exist, `aarFitDerivationsProvider` short-circuits to `AarDerivationBundle.empty()`, and there is no killmail. | D3 gets a **`notSearched`** state → `Missing` with a **"Search Killmails"** CTA that calls the existing `enrichEncounter()` on demand (user-initiated, so R2.2 holds). A new persisted flag `CombatEnrichment.killmailSearchCompleted` distinguishes "searched, nothing found" (`Unavailable`) from "never searched" (`Missing`) — today both are `logOnly` (§3.4, decision D5). |
| C3 | §3.6 D1 "Missing — derivation returned `AarFitDerivationFailed`" | `AarDerivationBundle` never carries the failure. `deriveForEncounter()` folds it into `bundle.unknowns` and leaves `self == null` (`combat_fit_derivation_service.dart:63-70`). | D1 detects failure as `evidence != null && bundle.self == null` and cites the matching `pilotFit` unknown's detail (§2.3). |
| C4 | §3.6 D1 reads `pilotFitEvidence` | For the pilot's **own loss**, the pilot's fit arrives as `victimFitEvidence` (killmail, `proven`) and the service derives `bundle.self` from it (`victimIsSelf`). `pilotFitEvidence` is null. | D1 evaluates the **self fit evidence**: `pilotFitEvidence`, else `victimFitEvidence` when `enrichment.victimCharacterId == encounter.characterId`. An own-loss killmail therefore scores D1 `Complete` (killmails list every fitted module, destroyed or dropped). |
| C5 | S1 is "a solo loss" whose rows show *Pilot fit: Missing* and *Opponent fit: Inferred · killmail shows destroyed modules* | On a loss the killmail's destroyed modules are the **pilot's**, not the opponent's (`fromKillmail` builds `victimFitEvidence`; the ledger already records the unknown *"Killmails do not expose full attacker fittings"*). The S1 rows describe a **kill** (victim ≠ pilot). | The S1 fixture is a kill. A loss is worked separately as **S1b** (§2.7). On a loss, D4 is `Unavailable` ("attacker fittings are not exposed by killmails"), not `Missing` — there is no in-app action that could supply it. |
| C6 | §3.6 D5 "≥ 70 % of profiled damage is typed" | `CombatDamageProfile.totalProfiledDamage` sums **resolved** weapons only; unknown-weapon damage is dropped, not counted (`combat_damage_profile_resolver.dart:80-125`). "N of M weapons" is also not derivable: the profile carries `unknownWeapons` but not the resolved names as a list. | Typed fraction = `totalProfiledDamage / encounter.totalDamageReceived` (incoming) and `/ totalDamageDealt` (outgoing), combined over both directions (§2.3 D5). Add `CombatDamageProfile.resolvedWeapons` (additive, default `const []`, two lines in the resolver). `CombatDamageConfidence` is always `sdeExact` today; `observed`/`modelInferred` are never produced — the rule keeps them for forward-compatibility. |
| C7 | §3.3 `Missing` = "obtainable but absent — **actionable**" vs §3.6 D4 `Missing` (opponent identified, no fit) and D5 `Missing` (nothing typed) | Neither has an in-app action: there is no opponent-fit import, and weapon names are what the log says. Both would be permanent red rows with a "+N points" promise the user cannot collect — the failure mode §0.5 warns about. | **Invariant I1: a row is `Missing` iff it carries at least one action.** D4 with no obtainable fit and D5 with nothing typeable are `Unavailable` with a stated reason (§2.3). Tested in T2.22. |
| C8 | §3.6 D3 "Inferred — opponent named from combat log actors only, no killmail" alongside "Unavailable — `logOnly` after a completed search" | Both describe the same state (a completed search that found nothing always still has log actor names). AC1.4/S6 require that state to be `Unavailable` (denominator 65). | D3 `Inferred` is **unreachable** in V1 and is dropped from the rule table. The enum keeps the value (it is a general status). |
| C9 | D2 (b) "field inside `CombatAarReport` … Arch should verify (b) does not alter the prompt payload" | The prompt is built from `(encounter, enrichment, derivation)` only (`codex_analysis_client.dart:170-235`); the report is the **output** and is never serialised into a prompt. Adding a nullable field to the report cannot change the payload. | Take (b): `CombatAarReport.evidenceAtGeneration: AarEvidenceSnapshot?`, attached **after** the LLM JSON is parsed, serialised into `analysisJson`. `version` stays 3; `_statusForRow` unaffected. No Drift migration (schema stays 20). T4.6 guards the payload. |
| C10 | §4.5 "Opponent identity (`logOnly`) → Search Killmails → existing enrichment refresh" | There is no enrichment refresh handler on the screen; the only search entry point is `CombatEnrichmentService.enrichEncounter()`. | Add `_searchKillmails()` to the screen (mirrors `_captureCurrentFit`: call service, invalidate `combatEnrichmentProvider(id)`, snackbar). Only the `notSearched` row carries it (C2). |
| C11 | §4.5 lists two pilot-fit CTAs; AC4.6 removes the three-button `Wrap` | The `Wrap` also holds **"Snapshot Current Fit"** (`_captureCurrentFit(confirmed: false)` → `reference` confidence → `Inferred`). No spec row carries it. | Removed with the `Wrap` (decision D6). The service method and its tests stay. Product should confirm; an overflow-menu placement is the fallback. |
| C12 | S3/AC3.3 "no full-screen spinner, same frame" | `ref.invalidate(combatEnrichmentProvider(id))` makes every dependent provider **reload**; with Riverpod 3 defaults `.when()` shows `loading` during a reload (`skipLoadingOnReload: false`). The card would flash to its skeleton on every fit attach. | The card's `.when()` passes `skipLoadingOnReload: true` (and the default `skipLoadingOnRefresh: true`), so the previous assessment stays on screen until the new one lands (§5.1). |

Everything else in the spec (R1–R6, S2–S7, AC1–AC7, §8 D1–D4, §10, §11)
stands. Acceptance and test IDs are kept below where they survive; corrected or
added cases are marked.

---

## 1. Architecture

### 1.1 Component boundaries

```
domain/                                    pure Dart, no I/O, no providers, no DateTime.now()
  aar_evidence_assessment.dart             enums, AarEvidenceRules (all constants), results, assessment, snapshot
  aar_evidence_scorer.dart                 AarEvidenceScorer: 5 dimension evaluators + combine()
  combat_aar_report.dart          (edit)   + evidenceAtGeneration: AarEvidenceSnapshot?
  combat_enrichment.dart          (edit)   + killmailSearchCompleted: bool
  combat_damage_profile.dart      (edit)   + resolvedWeapons: List<String>

data/                                      I/O and composition
  combat_providers.dart           (edit)   + aarEvidenceAssessmentProvider (family, composes 4 existing providers)
  combat_analysis_service.dart    (edit)   stage 5 also scores; snapshot attached to the report before save
  combat_enrichment_service.dart  (edit)   enrichEncounter() marks killmailSearchCompleted = true
  combat_damage_profile_resolver.dart (edit) fills resolvedWeapons

presentation/
  widgets/aar_evidence_checklist_card.dart     card (provider-aware) + body (pure) + row + limits section
  widgets/aar_pre_analysis_gate.dart           warning / advisory / chip + the analyze button
  widgets/aar_report_provenance_banner.dart    "generated at N%" + re-analyze prompt
  analysis_multipane_screen.dart  (edit)       both placements, Wrap removed, _searchKillmails()
```

Dependency direction is unchanged: presentation → data → domain. The scorer
depends on `combat_enrichment.dart`, `aar_fit_derivation.dart`,
`combat_damage_profile.dart`, `parsed_combat_encounter.dart` and nothing else.

### 1.2 Data flow

```
combatEnrichmentProvider(id)            CombatEnrichment?   (cached row; null = never searched)
aarFitDerivationsProvider(encounter)    AarDerivationBundle (self/opponent derivations + unknowns)
combatIncomingDamageProfileProvider     CombatDamageProfile (incoming)
combatDamageProfileProvider             CombatDamageProfile (outgoing)
            │
            ▼
aarEvidenceAssessmentProvider(encounter)
            │   AarEvidenceInputs(encounter, enrichment, bundle, incoming, outgoing)
            ▼
   const AarEvidenceScorer().assess(inputs)  ──►  AarEvidenceAssessment   (pure)
            │
            ├──► AarEvidenceChecklistCard   (pre- and post-analysis)
            ├──► AarPreAnalysisGate         (pre-analysis, above the button)
            └──► AarReportProvenanceBanner  (post-analysis: current vs recorded)

analyzeEncounter():  stage 4 enrichEncounter (search) → stage 5 derive + assess
                     → LLM → report.withEvidenceAtGeneration(assessment.toSnapshot()) → analysisJson
```

Invalidating `combatEnrichmentProvider(id)` (already done by `_captureCurrentFit`,
`_showImportFitDialog`, and `onAnalysisSaved`) cascades through
`aarFitDerivationsProvider` to the assessment; nothing new needs invalidating.

### 1.3 Resolution of the spec's decisions (§8) and new ones

| | Decision | Resolution |
|---|---|---|
| D1 | Can the gate block? | **No.** `AarPreAnalysisGate` always renders an enabled `FilledButton`; the message is a sibling widget, never a dialog. T7.4/T7.5 assert it at 0/30/64/79/100 and for loading/error inputs. |
| D2 | Where does the recorded score live? | **(b) on the report**, as `evidenceAtGeneration: AarEvidenceSnapshot?`. Proof it cannot alter the prompt: C9. Stored inside `analysisJson`; no schema migration; legacy/`fromLegacy` reports read back `null` → "not recorded" (R4.5). The snapshot stores score, band, capped and the five statuses only — not detail text (the text is re-derivable and would bloat every row). |
| D3 | Remove the old button cluster? | **Remove.** The `Wrap` at `analysis_multipane_screen.dart:616-635` and the `needsReauth` button at 606-614 both go; their handlers are invoked from checklist rows via `AarEvidenceActionHandlers`. |
| D4 | User-configurable weights? | **No.** All weights, credits, cut-offs and thresholds are `static const` on `AarEvidenceRules` (R1.3). |
| D5 *(new)* | Should the pre-analysis screen trigger the killmail search automatically? | **No in V1.** The search is ESI + zKill network I/O; running it on every encounter open changes the app's network profile silently. The `notSearched` row makes the search one click away and explains why it matters. Revisit as a settings toggle if users never press it. |
| D6 *(new)* | Keep "Snapshot Current Fit" (unconfirmed)? | **Drop from the UI** (C11). The `Inferred` status remains reachable for rows persisted earlier and for future callers. Flagged for Product. |
| D7 *(new)* | `Missing` ⇔ action (I1) | Adopted (C7). Makes "+N points" a promise the row can keep. |
| D8 *(new)* | Family key type | `ParsedCombatEncounter` (identity equality, no `==` override) — same as `aarFitDerivationsProvider`. The screen holds one instance; tests must reuse the same instance rather than `copyWith` between override and read. |

---

## 2. The scoring model — exact rules

### 2.1 Constants (`AarEvidenceRules`, one place, R1.3)

```dart
abstract final class AarEvidenceRules {
  static const Map<AarEvidenceDimension, int> weights = {
    AarEvidenceDimension.pilotFit: 30,
    AarEvidenceDimension.combatLog: 20,
    AarEvidenceDimension.opponentIdentity: 15,
    AarEvidenceDimension.opponentFit: 20,
    AarEvidenceDimension.damageProfile: 15,
  };                                                   // sums to 100 (T1.1)
  static const double creditComplete = 1.0;
  static const double creditPartial = 0.5;
  static const double creditInferred = 0.3;
  static const double creditMissing = 0.0;             // unavailable: excluded, no credit
  static const int bandCompleteMin = 90;
  static const int bandGoodMin = 75;
  static const int bandPartialMin = 40;                // below: low
  static const int minDamageEventsForComplete = 20;    // D2
  static const double matchConfidenceComplete = 0.8;   // D3
  static const double minTypedFractionForPartial = 0.7;// D5
  static const int reanalysisDelta = 10;               // R4.3
  static const int gateWarnBelow = 40;                 // S4
  static const int gateAdviseBelow = 75;               // S4
  static const int collapseAtOrAbove = 90;             // §4.6
}
```

### 2.2 Arithmetic (`AarEvidenceScorer.combine`)

```
scored     = dimensions where status != unavailable
earned     = Σ weight_d × credit(status_d)        over scored
available  = Σ weight_d                            over scored
score      = available == 0 ? 0 : (100 × earned / available).round()   // Dart round(): 48.5 → 49
capped     = any status_d == unavailable
band       = score >= 90 ? complete : score >= 75 ? good : score >= 40 ? partial : low
bandLabel  = capped ? '${band.label} (capped)' : band.label
```

Projection: `projectedScoreIf(d, status)` re-runs `combine` with one status swapped;
`pointsToComplete(d) = status == unavailable ? 0 : (weight_d × (1 − credit)).round()`.

Ordering (AC2.2): by `status.sortRank` (missing 0, partial 1, inferred 2,
complete 3, unavailable 4), then weight descending, then enum index (stable).

`topGap` = first ordered row whose status is `missing`, `partial` or `inferred`.

### 2.3 Per-dimension rules (ordered decision lists; first match wins)

Every rule reads only the inputs named; no rule reads another dimension's
*status* (spec risk R3). D3 and D4 share a private `_identityKind(inputs)`
helper that reads the same enrichment fields (they share inputs, not outputs).

#### Shared helpers

```
victimIsSelf   = enrichment?.victimCharacterId != null
                 && enrichment.victimCharacterId == encounter.characterId
selfEvidence   = enrichment?.pilotFitEvidence
                 ?? (victimIsSelf ? enrichment.victimFitEvidence : null)
identityKind   = enrichment == null && encounter.characterId == null → noCharacter
               | enrichment == null                                    → notSearched
               | status == needsReauth                                 → needsReauth
               | status == ambiguous                                   → ambiguous
               | status == killmailMatched && matchConfidence >= 0.8   → matchedHigh
               | status == killmailMatched                             → matchedLow
               | status == logOnly && !killmailSearchCompleted         → notSearched
               | status == logOnly && killmailSearchCompleted          → noKillmail
fitFailure(cat)= bundle.unknowns.firstWhereOrNull(u => u.category == cat
                 && (u.label == 'Ship type not in SDE' || u.label == 'Fit derivation failed'))
```

#### D1 — Pilot fit (30). Inputs: `selfEvidence`, `bundle.self`, `fitFailure(pilotFit)`

| # | Condition | Status | Detail (R3.2) | Actions |
|---|---|---|---|---|
| 1 | `selfEvidence == null` | Missing | `No pilot fit attached for this fight.` | useCurrentFit, importFit |
| 2 | `bundle.self == null` (derivation failed, C3) | Missing | `fitFailure.detail` e.g. `Ship type 12345 (Foo) is not in the bundled SDE.`; fallback `Fit derivation failed.` | useCurrentFit, importFit |
| 3 | `selfEvidence.confidence ∈ {derived, reference, unknown}` | Inferred | `Current ship snapshot captured <UTC time>, not confirmed for this fight.` (snapshot) / `<source label>, unconfirmed.` | useCurrentFit, importFit |
| 4 | `bundle.self.coverage.hasUnresolved` | Partial | `<source label>; N module(s) not in the SDE (<names>).` | — |
| 5 | `bundle.self.skills.basis == allFive` | Partial | `<source label>; skills assumed All V (trained skills not loaded for this character).` | — |
| 6 | otherwise | Complete | `<source label>` | — |

Source labels: `currentShipSnapshot`+`confirmed` → `Current ship snapshot, confirmed for this fight`;
`manualFitImport` → `Imported fit, user-confirmed`; `killmail` → `Own loss killmail #<id>: every fitted module proven`.
Detail always ends with `; slots High h/H, Mid m/M, Low l/L, Rig r/R` from `coverage.describe()` when derived.

#### D2 — Combat log (20). Inputs: `encounter.events`, `encounter.durationSeconds`

```
n        = events.where(e => e.kind == damage && e.amount > 0).length
incoming = events.any(isIncomingDamage);  outgoing = events.any(isOutgoingDamage)
dirs     = both ? 'both directions' : incoming ? 'incoming only' : outgoing ? 'outgoing only' : 'no damage events'
```

| # | Condition | Status | Detail |
|---|---|---|---|
| 1 | `n >= 20 && incoming && outgoing` | Complete | `<n> damage events over <duration>s, both directions` |
| 2 | otherwise | Partial | `<n> damage events over <duration>s, <dirs>` + ` (fewer than 20)` when `n < 20` |

Never Missing/Unavailable. Range is not read here (R3.4).

#### D3 — Opponent identity (15). Inputs: `identityKind`, `enrichment.{killmailId, matchConfidence, matchReason, victimName}`

| # | Kind | Status | Detail | Actions |
|---|---|---|---|---|
| 1 | matchedHigh | Complete | `Killmail #<id> matched (<pct>%)` + `, victim <victimName>` when known | — |
| 2 | matchedLow | Partial | `Killmail #<id> matched at low confidence (<pct>%): <matchReason>` | — |
| 3 | ambiguous | Partial | `Ambiguous killmail match: <matchReason>` | — |
| 4 | needsReauth | Missing | `Killmail scope is missing for this character; reauthorize to search ESI killmails.` | reauthorize |
| 5 | notSearched | Missing | `Killmail search has not run for this encounter.` | searchKillmails |
| 6 | noKillmail | Unavailable | `<matchReason>` (e.g. `No ESI or zKill killmail matched this encounter.`) | — |
| 7 | noCharacter | Unavailable | `This log is not linked to an authenticated character, so killmails cannot be searched.` | — |

`Inferred` is unreachable (C8). `pct = (matchConfidence × 100).round()`.

#### D4 — Opponent fit (20). Inputs: `identityKind`, `victimIsSelf`, `enrichment.{killmailId, victimFitEvidence}`, `bundle.opponent`, `fitFailure(opponentFit)`

| # | Condition | Status | Detail | Actions |
|---|---|---|---|---|
| 1 | kind ∈ {noKillmail, noCharacter} | Unavailable | `No opponent identified; there is no fit to derive.` | — |
| 2 | kind == ambiguous | Unavailable | `Ambiguous killmail match; no single destroyed fit can be attributed.` | — |
| 3 | kind == notSearched | Missing | `Opponent fit needs a matched killmail; run the killmail search.` | searchKillmails |
| 4 | kind == needsReauth | Missing | `Opponent fit needs a matched killmail; reauthorize to search.` | reauthorize |
| 5 | `bundle.opponent != null && opponent.fitSource == killmail` | Inferred | `Killmail #<id> shows destroyed and dropped modules only (<shipName>)` + `; N module(s) not in the SDE` when unresolved | — |
| 6 | `bundle.opponent != null && coverage.hasUnresolved` | Partial | `<source label>; N module(s) not in the SDE (<names>)` *(unreachable in V1: no opponent import)* | — |
| 7 | `bundle.opponent != null` | Complete | `<source label>` *(unreachable in V1)* | — |
| 8 | `victimIsSelf` (own loss, C5) | Unavailable | `Own loss killmail #<id>: attacker fittings are not exposed by killmails.` | — |
| 9 | `victimFitEvidence != null` (derivation failed) | Partial | `fitFailure.detail` e.g. `Ship type 12345 (Foo) is not in the bundled SDE.` | — |
| 10 | otherwise | Unavailable | `Killmail #<id> carries no destroyed fit.` | — |

#### D5 — Damage profile (15). Inputs: `encounter.{totalDamageReceived, totalDamageDealt}`, `incoming`, `outgoing`

```
for d in {incoming (T = totalDamageReceived), outgoing (T = totalDamageDealt)}:
  skip d if T == 0
  profiled_d = profile_d.totalProfiledDamage
typed        = Σ profiled_d / Σ T_d                         (clamped to [0, 1]; 0 if nothing scored)
unknown      = incoming.unknownWeapons ∪ outgoing.unknownWeapons        (set of names; 'Unknown' counts once)
resolved     = incoming.resolvedWeapons ∪ outgoing.resolvedWeapons
m            = |resolved ∪ unknown|;  u = |unknown|;  pct = (typed × 100).round()
inferredOnly = any entry.confidence == modelInferred (never true today, C6)
```

| # | Condition | Status | Detail |
|---|---|---|---|
| 1 | both directions skipped | Unavailable | `No damage recorded in either direction.` |
| 2 | `typed == 0` | Unavailable | `None of the <m> weapons in this log resolve to SDE damage attributes (<names>).` |
| 3 | `u == 0 && !inferredOnly` | Complete | `All <m> weapons resolved; 100% of damage typed from SDE attributes.` |
| 4 | `typed >= 0.7` | Partial | `<u> of <m> weapons unresolved (<names>); <pct>% of damage typed.` (or `All weapons resolved; damage types model-inferred.` when `u == 0`) |
| 5 | `typed < 0.7` | Inferred | `<u> of <m> weapons unresolved (<names>); <pct>% of damage typed.` |

Rows 1–2 replace the spec's `Missing` (C7): nothing in-app can rename a weapon.

### 2.4 Headline copy (domain, so it is unit-testable)

`AarEvidenceAssessment.headline`:

| band | text |
|---|---|
| low | `Analysis at <score>% evidence will produce general coaching, not specific fit advice.` + ` <hint> would raise this to about <projected>%.` when `topGap != null` |
| partial | `Analysis will cover damage and timeline. Fit-specific conclusions will be limited.` |
| good | `Most conclusions are supported; minor gaps remain.` |
| complete | `Fit-specific, quantitative conclusions are available.` |

`hint` comes from the top gap's first action: `useCurrentFit`/`importFit` →
`Attaching your fit`; `searchKillmails` → `Searching for the killmail`;
`reauthorize` → `Reauthorizing this character`; no action → `Resolving <dimension label>`.
`projected = projectedScoreIf(topGap.dimension, complete)`.

When `capped`, a second sentence is appended from the first `Unavailable` row's
detail (S6: "No killmail exists for this encounter…").

### 2.5 Worked example — S1 (a kill; C5)

| Dimension | Inputs | Status | Weight | Credit | Earned |
|---|---|---|---|---|---|
| D1 | no `pilotFitEvidence`; victim 777 ≠ pilot 42 | Missing | 30 | 0 | 0 |
| D2 | 24 damage events, both directions, 96 s | Complete | 20 | 1.0 | 20 |
| D3 | killmailMatched, 0.92, #1234567 | Complete | 15 | 1.0 | 15 |
| D4 | `bundle.opponent` from killmail | Inferred | 20 | 0.3 | 6 |
| D5 | incoming 850/1000 typed, 2 of 14 unresolved; outgoing 1000/1000 | Partial | 15 | 0.5 | 7.5 |
| | | | **100** | | **48.5** |

`score = round(48.5) = 49`, band **Partial**, `capped = false`. Row order:
Pilot fit (Missing 30), Damage profile (Partial 15), Opponent fit (Inferred 20),
Combat log (Complete 20), Opponent identity (Complete 15). Pilot-fit row shows
`+30 pts`; `projectedScoreIf(pilotFit, complete) = round(78.5) = 79`.

After S2 (confirmed snapshot, no unresolved, character skills loaded): D1 Complete →
`78.5 → 79`, **Good** (AC1.1, T1.3, T1.4).

### 2.6 Worked example — S6 (irreducible) and S7

S6: fit confirmed (D1 30), log Complete (20), searched/no killmail (D3, D4
Unavailable), profile Complete (15): `65 / 65 = 100`, **Complete (capped)** (T1.6).
Without the fit: `35 / 65 = 53.8 → 54`, **Partial (capped)** (the spec's "50 %").

S7: all Complete → `100 / 100`, **Complete**, not capped (T1.2).

### 2.7 Worked example — S1b (own loss, C4/C5)

Killmail #2000 matched 0.9, victim == pilot, character skills loaded, no unresolved:
D1 Complete 30 (killmail source), D2 Complete 20, D3 Complete 15, D4 **Unavailable**
(attacker fit), D5 Partial 7.5 → `72.5 / 80 = 90.6 → 91`, **Complete (capped)**.
Same fight with All V skills: D1 Partial 15 → `57.5 / 80 = 71.9 → 72`, **Partial (capped)**.

### 2.8 Monotonicity (R3.3)

Over the credit order Missing < Inferred < Partial < Complete, raising one
dimension with the others fixed never lowers `score` (T1.9). `Unavailable` sits
outside the order (it changes the denominator) and is excluded from T1.9. Every
real transition is still upward: attaching a fit moves D1 up; running the search
moves D3 from Missing to {Complete, Partial, Missing, Unavailable} and D4 from
Missing to {Inferred, Partial, Unavailable}; the Unavailable case removes two
zero-credit rows from the denominator, which can only raise the ratio.

---

## 3. Domain contracts (`lib/features/combat_analyzer/domain`)

### 3.1 `aar_evidence_assessment.dart`

```dart
enum AarEvidenceDimension {
  pilotFit, combatLog, opponentIdentity, opponentFit, damageProfile;
  int get weight => AarEvidenceRules.weights[this]!;
  String get label;   // 'Pilot fit' | 'Combat log' | 'Opponent identity' | 'Opponent fit' | 'Damage profile'
}

enum AarEvidenceStatus {
  complete, partial, inferred, missing, unavailable;
  double? get credit;   // 1.0 | 0.5 | 0.3 | 0.0 | null (excluded)
  int get sortRank;     // missing 0, partial 1, inferred 2, complete 3, unavailable 4
  String get label;     // 'Complete' | 'Partial' | 'Inferred' | 'Missing' | 'Unavailable'
}

enum AarEvidenceBand {
  low, partial, good, complete;
  static AarEvidenceBand of(int score);   // §2.2 cut-offs
  String get label;                        // 'Low' | 'Partial' | 'Good' | 'Complete'
  String get description;                  // §2.4 sentence (without the low-band projection)
}

enum AarEvidenceAction {
  useCurrentFit, importFit, searchKillmails, reauthorize;
  String get buttonLabel; // 'Use Current Fit' | 'Import Fit' | 'Search Killmails' | 'Reauthorize Character'
  String get hint;        // 'Attaching your fit' | 'Attaching your fit' | 'Searching for the killmail' | 'Reauthorizing this character'
}

/// Domain-side UTC formatter ('2026-09-10 18:00 UTC') used by D1 detail text; the
/// screen's private `_formatAarDateUtc` produces the same shape.
String formatAarUtcMinute(DateTime value);

abstract final class AarEvidenceRules { /* §2.1 */ }

class AarStructuralLimit {
  const AarStructuralLimit({required this.label, required this.detail});
  final String label;
  final String detail;
  static const range = AarStructuralLimit(
    label: 'Engagement range',
    detail: 'Engagement range is not recorded in EVE combat logs.',
  );
}

class AarEvidenceDimensionResult {
  const AarEvidenceDimensionResult({
    required this.dimension,
    required this.status,
    required this.detail,          // non-empty (T2.21)
    this.actions = const [],
  });
  final AarEvidenceDimension dimension;
  final AarEvidenceStatus status;
  final String detail;
  final List<AarEvidenceAction> actions;

  int get weight => dimension.weight;
  double get earned => status.credit == null ? 0 : weight * status.credit!;
  int get pointsToComplete => status == AarEvidenceStatus.unavailable ? 0 : (weight - earned).round();
  bool get isActionable => actions.isNotEmpty;
}

class AarEvidenceAssessment {
  const AarEvidenceAssessment({
    required this.dimensions,      // exactly 5, enum order
    required this.score,
    required this.band,
    required this.capped,
    required this.earned,
    required this.available,
    this.structuralLimits = const [AarStructuralLimit.range],
  });
  final List<AarEvidenceDimensionResult> dimensions;
  final int score;
  final AarEvidenceBand band;
  final bool capped;
  final double earned;
  final int available;
  final List<AarStructuralLimit> structuralLimits;

  String get bandLabel;                                   // 'Partial' | 'Complete (capped)'
  String get scoreLabel => '$score% $bandLabel';
  List<AarEvidenceDimensionResult> get ordered;           // §2.2
  AarEvidenceDimensionResult? get topGap;
  AarEvidenceDimensionResult operator [](AarEvidenceDimension d);
  int projectedScoreIf(AarEvidenceDimension d, AarEvidenceStatus s);
  String get headline;                                    // §2.4
  bool get collapsedByDefault => score >= AarEvidenceRules.collapseAtOrAbove;
  AarEvidenceSnapshot toSnapshot();
  String get logLine;  // 'score=49 band=partial capped=false pilotFit=missing combatLog=complete ...' (R6.2)
}

class AarEvidenceSnapshot {
  const AarEvidenceSnapshot({
    required this.score,
    required this.band,
    required this.capped,
    required this.statuses,        // Map<AarEvidenceDimension, AarEvidenceStatus>
  });
  final int score;
  final AarEvidenceBand band;
  final bool capped;
  final Map<AarEvidenceDimension, AarEvidenceStatus> statuses;

  String get label => capped ? '$score% ${band.label} (capped)' : '$score% ${band.label}';
  bool shouldOfferReanalysis(int currentScore) => currentScore - score >= AarEvidenceRules.reanalysisDelta;

  Map<String, dynamic> toJson();
  // {'score': 49, 'band': 'partial', 'capped': false,
  //  'statuses': {'pilotFit': 'missing', 'combatLog': 'complete', ...}}
  static AarEvidenceSnapshot? fromJson(Object? json);   // null when not a Map or score missing; unknown names skipped
}
```

### 3.2 `aar_evidence_scorer.dart`

```dart
class AarEvidenceInputs {
  const AarEvidenceInputs({
    required this.encounter,
    required this.enrichment,      // null = no cached row
    required this.bundle,
    required this.incoming,
    required this.outgoing,
  });
  final ParsedCombatEncounter encounter;
  final CombatEnrichment? enrichment;
  final AarDerivationBundle bundle;
  final CombatDamageProfile incoming;
  final CombatDamageProfile outgoing;
}

class AarEvidenceScorer {
  const AarEvidenceScorer();

  /// Logs `[AAR.EVIDENCE] ℹ️ <assessment.logLine>` once per call (R6.2).
  AarEvidenceAssessment assess(AarEvidenceInputs inputs);

  // Dimension evaluators are public statics so Group B tests hit them directly.
  static AarEvidenceDimensionResult pilotFit(AarEvidenceInputs inputs);
  static AarEvidenceDimensionResult combatLog(ParsedCombatEncounter encounter);
  static AarEvidenceDimensionResult opponentIdentity(AarEvidenceInputs inputs);
  static AarEvidenceDimensionResult opponentFit(AarEvidenceInputs inputs);
  static AarEvidenceDimensionResult damageProfile(AarEvidenceInputs inputs);

  /// Pure arithmetic over any five results (Group A hands it hand-built rows).
  static AarEvidenceAssessment combine(List<AarEvidenceDimensionResult> results);
}
```

`assess` = `combine([pilotFit(i), combatLog(i.encounter), opponentIdentity(i), opponentFit(i), damageProfile(i)])`.
`combine` throws `ArgumentError` unless exactly one result per dimension is present.

### 3.3 `combat_aar_report.dart` (edit)

```dart
class CombatAarReport {
  const CombatAarReport({ ...existing..., this.evidenceAtGeneration });
  final AarEvidenceSnapshot? evidenceAtGeneration;     // null = not recorded (R4.5)
  CombatAarReport withEvidenceAtGeneration(AarEvidenceSnapshot snapshot);
  // toJson(): adds 'evidenceAtGeneration': snapshot.toJson() only when non-null. 'version' stays 3.
  // fromJson(): reads AarEvidenceSnapshot.fromJson(json['evidenceAtGeneration']). fromLegacy(): null.
}
```

### 3.4 `combat_enrichment.dart` (edit)

```dart
class CombatEnrichment {
  static const String uncachedMatchReason = 'No killmail evidence is cached for this AAR.';
  const CombatEnrichment({ ...existing..., this.killmailSearchCompleted = false });
  final bool killmailSearchCompleted;
  // toJson(): 'killmailSearchCompleted': bool.   toPromptJson(): UNCHANGED (T4.6).
  // copyWith(): + bool? killmailSearchCompleted.
  // fromJson(): json['killmailSearchCompleted'] as bool?
  //   ?? (status != CombatEnrichmentStatus.logOnly || matchReason != uncachedMatchReason)   // legacy rows
}
```

The legacy inference is exact for rows written before this milestone: every
`enrichEncounter()` outcome has a status other than `logOnly` or one of two
specific reasons; only `_loadOrCreateEnrichment()` writes `uncachedMatchReason`.

### 3.5 `combat_damage_profile.dart` (edit)

```dart
class CombatDamageProfile {
  const CombatDamageProfile({ ...existing..., this.resolvedWeapons = const [] });
  final List<String> resolvedWeapons;   // weapon names that resolved to SDE damage attributes, sorted
}
```

---

## 4. Data layer

### 4.1 `combat_providers.dart` — `aarEvidenceAssessmentProvider`

```dart
final aarEvidenceAssessmentProvider =
    FutureProvider.family<AarEvidenceAssessment, ParsedCombatEncounter>((ref, encounter) async {
  Log.d('AAR.EVIDENCE', 'aarEvidenceAssessmentProvider(encounter=${encounter.id}) - START');
  final enrichment = await ref.watch(combatEnrichmentProvider(encounter.id).future);
  final bundle = await ref.watch(aarFitDerivationsProvider(encounter).future);
  final incoming = await ref.watch(combatIncomingDamageProfileProvider(encounter).future);
  final outgoing = await ref.watch(combatDamageProfileProvider(encounter).future);
  return const AarEvidenceScorer().assess(AarEvidenceInputs(
    encounter: encounter, enrichment: enrichment, bundle: bundle,
    incoming: incoming, outgoing: outgoing,
  ));
});
```

Profiles are watched directly (not through the bundle) so a null enrichment still
scores D2/D5 (T5.4). No service, no client, no `DateTime.now()` (R2.1, T5.2).

### 4.2 `combat_analysis_service.dart` — record the score

In `analyzeEncounter()`, stage 5, after `derivation` and before the LLM call:

```dart
final assessment = const AarEvidenceScorer().assess(AarEvidenceInputs(
  encounter: encounter, enrichment: enrichment, bundle: derivation,
  incoming: incoming, outgoing: outgoing,
));
Log.i('AAR.EVIDENCE', 'analyzeEncounter(${encounter.id}) recording ${assessment.scoreLabel}');
```

After the LLM returns: `final report = analysis.report.withEvidenceAtGeneration(assessment.toSnapshot());`
and `analysisJson: Value(jsonEncode(report.toJson()))`. The `_codexClient.analyzeEncounter(...)`
call and its arguments are unchanged (AC7.4). Stage count stays 9; the stage-5
detail becomes `'Running dogma derivation, damage matchups, and evidence scoring.'`.

The `enrichment` scored here is the post-search one from stage 4, so the recorded
score is the evidence the model actually saw.

### 4.3 `combat_enrichment_service.dart` — mark the search

Every terminal return in `enrichEncounter()` passes through
`_save(x.copyWith(killmailSearchCompleted: true))`: the no-character branch, the
ESI match, the zKill match, and the final `logOnly`/`needsReauth` fallback.
`_loadOrCreateEnrichment()` and the screen's `_logOnlyEnrichment()` use
`CombatEnrichment.uncachedMatchReason` and leave the flag `false`.
`attachDerivedEvidence`, `importPilotFit`, `captureCurrentPilotFit` use `copyWith`
and therefore preserve the flag.

### 4.4 `combat_damage_profile_resolver.dart` — expose resolved names

In `_resolve`, collect `resolvedWeapons` = `damageByWeapon.keys` minus those added
to `unknownWeapons`, sorted; pass to the constructor. Both existing resolver tests
stay green (new field defaults).

---

## 5. Presentation (`lib/features/combat_analyzer/presentation`)

### 5.1 `widgets/aar_evidence_checklist_card.dart`

```dart
class AarEvidenceActionHandlers {
  const AarEvidenceActionHandlers({this.onUseCurrentFit, this.onImportFit, this.onSearchKillmails, this.onReauthorize});
  final VoidCallback? onUseCurrentFit, onImportFit, onSearchKillmails, onReauthorize;
  VoidCallback? operator [](AarEvidenceAction action);
}

/// Provider-aware shell: watches aarEvidenceAssessmentProvider(encounter), owns collapse state.
class AarEvidenceChecklistCard extends ConsumerStatefulWidget {
  const AarEvidenceChecklistCard({super.key, required this.encounter, required this.handlers});
}
// build():
//   final async = ref.watch(aarEvidenceAssessmentProvider(widget.encounter));
//   return async.when(
//     skipLoadingOnReload: true,                       // C12
//     data: (a) => AarEvidenceChecklistBody(assessment: a, handlers: widget.handlers,
//                    collapsed: _collapsed ?? a.collapsedByDefault, onToggle: ...),
//     loading: () => const AarEvidenceSkeletonCard(),  // Key('aar-evidence-skeleton'), indeterminate bar, 'Assessing evidence…'
//     error: (e, s) => const AarEvidenceUnavailableCard(),  // header 'Evidence assessment unavailable', nothing else
//   );

/// Pure rendering (Groups F/H test this directly).
class AarEvidenceChecklistBody extends StatelessWidget { assessment, handlers, collapsed, onToggle }
class AarEvidenceChecklistRow extends StatelessWidget { row, handlers, projectedScore }   // Key('aar-evidence-row-<dimension.name>')
class AarEvidenceLimitsSection extends StatelessWidget { limits }                         // Key('aar-evidence-limits')
```

Header: title `Evidence Completeness`, chip `<score>%` (Key `aar-evidence-score-chip`),
band label text, `LinearProgressIndicator(value: score/100)` (Key `aar-evidence-progress`)
coloured by band (low → `EveColors.error`, partial → `EveColors.warning`,
good/complete → `EveColors.success`), headline text, toggle
`IconButton` (Key `aar-evidence-toggle`, `expand_more`/`expand_less`).

Row: icon + colour per §4.4 (`check_circle`/success, `warning_amber`/warning,
`help_outline`/warning, `cancel_outlined`/error, `block`/textSecondary),
`dimension.label`, `status.label`, detail text, and on Missing rows the projection
`+<pointsToComplete> pts` (Key `aar-evidence-gain-<dimension.name>`). Action
buttons are `OutlinedButton.icon`s with Key
`aar-evidence-action-<action.name>-<dimension.name>`; a button renders only when
the row lists the action **and** the handler is non-null.

Collapsed body renders the header only. `_collapsed` is per-widget-instance state
(not persisted, §4.6); it resets to `collapsedByDefault` when the band crosses 90 in
either direction so a newly complete card folds and a degraded one unfolds.

Every `build` logs `Log.d('COMBAT.UI', ...)` like `AarDerivedStatsPanel`.

### 5.2 `widgets/aar_pre_analysis_gate.dart`

```dart
class AarPreAnalysisGate extends StatelessWidget {
  const AarPreAnalysisGate({super.key, required this.assessment, required this.onAnalyze});
  final AarEvidenceAssessment? assessment;   // null while loading or on error → button only (R5.3)
  final VoidCallback onAnalyze;
}
```

Renders, top to bottom:
- `score < 40`: warning box (Key `aar-gate-warning`, `Icons.warning_amber`, `EveColors.warning`) with `assessment.headline`.
- `40 ≤ score < 75`: advisory text (Key `aar-gate-advisory`, `EveColors.textSecondary`) with `assessment.headline`.
- `score ≥ 75`: `AarEvidenceScoreChip` (Key `aar-gate-chip`, `'<score>% <bandLabel>'`) in a row with the button.
- always: `FilledButton.icon(onPressed: onAnalyze, icon: auto_awesome, label: 'Analyze With AI')` (Key `aar-analyze-button`), never disabled, never behind a dialog.

### 5.3 `widgets/aar_report_provenance_banner.dart`

```dart
class AarReportProvenanceBanner extends StatelessWidget {
  const AarReportProvenanceBanner({super.key, required this.recorded, required this.current, required this.onReanalyze});
  final AarEvidenceSnapshot? recorded;        // from report.evidenceAtGeneration
  final AarEvidenceAssessment? current;       // from the provider; null while loading/error
  final VoidCallback onReanalyze;
}
```

- `recorded == null` → `Evidence at generation: not recorded` (Key `aar-provenance-not-recorded`).
- else → `This report was generated at <recorded.label> evidence.` (Key `aar-provenance-recorded`);
  when `current != null && recorded.shouldOfferReanalysis(current.score)` append
  ` Evidence is now <current.score>%.` and an `OutlinedButton.icon` `Re-analyze`
  (Key `aar-provenance-reanalyze`). Otherwise no prompt (AC6.3).

### 5.4 `analysis_multipane_screen.dart` (edit)

1. **State**: add `Future<void> _searchKillmails()` — `enrichEncounter(widget.encounter)`
   via `combatEnrichmentServiceProvider`, then `ref.invalidate(combatEnrichmentProvider(id))`,
   snackbar `Killmail search complete.` / `Killmail search failed: $e`, `Log.i('COMBAT.UI', ...)`.
   Add `AarEvidenceActionHandlers get _evidenceHandlers` wiring
   `onUseCurrentFit: () => _captureCurrentFit(confirmed: true)`,
   `onImportFit: _showImportFitDialog`, `onSearchKillmails: _searchKillmails`,
   `onReauthorize: () => ref.read(authControllerProvider.notifier).startAuthFlow()`.
2. **`_buildAnalyzePrompt`** becomes `SingleChildScrollView > Center > ConstrainedBox(maxWidth: 720) > Column[` icon, title, stat chips, `AarEvidenceChecklistCard(encounter, handlers)`, `AarPreAnalysisGate(assessment: ref.watch(aarEvidenceAssessmentProvider(encounter)).when(data: (a) => a, loading: () => null, error: (_, _) => null), onAnalyze: _startAnalysis)` `]`. The bare `FilledButton` is removed (the gate owns it).
3. **`_buildAnalysisContent`**: insert `AarEvidenceChecklistCard(...)` + 16 px spacer **before** the evidence card (`_buildEvidenceLoadingCard`/`_buildEvidenceCard`), i.e. above the killmail chips (AC2.1).
4. **`_buildCommandStrip`**: under the headline row add `AarReportProvenanceBanner(recorded: report.evidenceAtGeneration, current: <same .when as above>, onReanalyze: () => _startAnalysis(forceRefresh: true))`.
5. **`_buildEvidenceCard`**: delete the `needsReauth` `OutlinedButton` block (606-614) and the three-button `Wrap` (616-635). Everything else in the card stays.
6. `_logOnlyEnrichment` uses `CombatEnrichment.uncachedMatchReason`.

---

## 6. File layout

```
lib/features/combat_analyzer/
  domain/aar_evidence_assessment.dart              NEW
  domain/aar_evidence_scorer.dart                  NEW
  domain/combat_aar_report.dart                    EDIT  evidenceAtGeneration
  domain/combat_enrichment.dart                    EDIT  killmailSearchCompleted, uncachedMatchReason
  domain/combat_damage_profile.dart                EDIT  resolvedWeapons
  data/combat_providers.dart                       EDIT  aarEvidenceAssessmentProvider
  data/combat_analysis_service.dart                EDIT  score + snapshot at stage 5/8
  data/combat_enrichment_service.dart              EDIT  flag on search completion
  data/combat_damage_profile_resolver.dart         EDIT  resolvedWeapons
  presentation/widgets/aar_evidence_checklist_card.dart     NEW
  presentation/widgets/aar_pre_analysis_gate.dart           NEW
  presentation/widgets/aar_report_provenance_banner.dart    NEW
  presentation/analysis_multipane_screen.dart      EDIT  §5.4

test/features/combat_analyzer/
  fixtures/aar_evidence_fixtures.dart              NEW   shared builders (§7.0)
  domain/aar_evidence_scorer_test.dart             NEW   Group A
  domain/aar_evidence_dimensions_test.dart         NEW   Group B
  domain/aar_evidence_limits_test.dart             NEW   Group C
  domain/combat_aar_report_test.dart               EDIT  snapshot round-trip (Group D model rows)
  domain/combat_enrichment_test.dart               NEW   flag round-trip + legacy inference (Group D)
  data/combat_analysis_service_test.dart           EDIT  Group D service rows
  data/aar_evidence_provider_test.dart             NEW   Group E
  presentation/aar_evidence_checklist_card_test.dart        NEW   Group F
  presentation/aar_pre_analysis_gate_test.dart              NEW   Group G
  presentation/analysis_multipane_evidence_test.dart        NEW   Group H
  domain/aar_evidence_logging_test.dart            NEW   Group I
```

---

## 7. Test specifications

Layering as in Milestone 2: pure unit → wiring → widget → screen. Every test
name below is the `test(...)`/`testWidgets(...)` description to use verbatim.

### 7.0 Fixtures — `test/features/combat_analyzer/fixtures/aar_evidence_fixtures.dart`

```dart
/// Parser-built encounter. Lines follow CombatLogParser._damageRegex: '<n> (to|from) <target> - <weapon> - <quality>'.
ParsedCombatEncounter encounterWith({
  int incomingEvents = 12, int outgoingEvents = 12, int amount = 100,
  int? characterId = 42, String weapon = 'Railgun', int spacingSeconds = 4,
});
// e.g. '[ 2026.05.20 20:00:04 ] (combat) 100 from Enemy - Railgun - Hits' (incoming)
//      '[ 2026.05.20 20:00:08 ] (combat) 100 to Enemy - Railgun - Hits'   (outgoing)
// Returns parseLines([...]).single.copyWith(characterId: characterId). Duration = (events-1) × spacing.

CombatDamageProfile profile({
  required int profiled, List<String> resolved = const ['Railgun'],
  List<String> unknown = const [], CombatDamageConfidence confidence = CombatDamageConfidence.sdeExact,
});  // one 'kinetic' entry carrying `profiled` when profiled > 0; entries empty when 0

FitEvidence fitEvidence({
  FitEvidenceRole role = FitEvidenceRole.pilot,
  EvidenceSource source = EvidenceSource.currentShipSnapshot,
  EvidenceConfidence confidence = EvidenceConfidence.confirmed,
  int shipTypeId = 587, DateTime? evidenceTime,
});

AarFitDerivation derivation({
  AarFitSubject subject = AarFitSubject.self,
  EvidenceSource fitSource = EvidenceSource.currentShipSnapshot,
  AarSkillBasis basis = AarSkillBasis.knownCharacter,
  List<int> unresolvedTypeIds = const [],
});  // FittingStats/TankAssessment copied from aar_derived_stats_panel_test.dart; coverage High 3/3 Mid 3/3 Low 3/3 Rig 3/3

CombatEnrichment enrichment({
  CombatEnrichmentStatus status = CombatEnrichmentStatus.killmailMatched,
  double matchConfidence = 0.92, int? killmailId = 1234567,
  int? victimCharacterId = 777, String? victimName = 'Target Pilot',
  FitEvidence? pilotFitEvidence, FitEvidence? victimFitEvidence,
  bool killmailSearchCompleted = true, String matchReason = 'ESI recent killmail within the encounter window.',
});

/// §2.5 exactly: kill, no pilot fit, opponent from killmail, 24 damage events, D5 partial (typed 0.925, 2 unknown of 14).
AarEvidenceInputs s1Inputs({ParsedCombatEncounter? encounter});
/// §2.7: own loss.
AarEvidenceInputs s1bInputs({AarSkillBasis basis = AarSkillBasis.knownCharacter});
/// §2.6: searched, no killmail, fit confirmed, profile complete.
AarEvidenceInputs s6Inputs({bool withPilotFit = true});
/// Every dimension Complete.
AarEvidenceInputs s7Inputs();

/// Hand-built rows for Group A.
AarEvidenceDimensionResult row(AarEvidenceDimension d, AarEvidenceStatus s, {List<AarEvidenceAction> actions = const []});
List<AarEvidenceDimensionResult> rows({required AarEvidenceStatus d1, d2, d3, d4, d5});
// rows() gives Missing rows their canonical actions so headline/topGap tests read naturally:
//   pilotFit → [useCurrentFit, importFit]; opponentIdentity, opponentFit → [searchKillmails]; others → [].
```

`s1Inputs`: `encounterWith(incomingEvents: 12, outgoingEvents: 12)` → received 1200,
dealt 1200; `incoming = profile(profiled: 900, resolved: 9 names, unknown: ['Unknown', 'Civilian Gatling Railgun'])`,
`outgoing = profile(profiled: 1200, resolved: 3 names)` → typed `2100/2400 = 0.875`,
`u = 2`, `m = 14` → Partial. Bundle: `opponent: derivation(subject: opponent, fitSource: killmail)`.
Enrichment: defaults, `victimFitEvidence: fitEvidence(role: victim, source: killmail, confidence: proven)`.

### 7.1 Group A — `domain/aar_evidence_scorer_test.dart` (pure; `combine` with hand-built rows)

- **T1.1** `weights sum to 100` — `AarEvidenceRules.weights.values.sum == 100`; `AarEvidenceDimension.values.length == 5`.
- **T1.2** `all Complete → 100, Complete, not capped` — `combine(rows(all complete))`: `score 100`, `band complete`, `capped false`, `bandLabel 'Complete'`, `available 100`.
- **T1.3** `S1 fixture → 49 Partial` — `const AarEvidenceScorer().assess(s1Inputs())`: `score 49`, `band partial`, `earned 48.5`, `available 100`, statuses `[missing, complete, complete, inferred, partial]` in enum order.
- **T1.4** `S1 + pilot fit Complete → 79 Good` — `assess(s1Inputs()).projectedScoreIf(pilotFit, complete) == 79`; and `combine(rows(d1: complete, d2: complete, d3: complete, d4: inferred, d5: partial)).score == 79`, `band good`.
- **T1.5** `all Missing except log → 20 Low` — `rows(d1: missing, d2: complete, d3: missing, d4: missing, d5: missing)` → `20`, `low`.
- **T1.6** `D3+D4 Unavailable → denominator 65, 100 capped` — `rows(complete, complete, unavailable, unavailable, complete)` → `available 65`, `earned 65`, `score 100`, `capped true`, `bandLabel 'Complete (capped)'`.
- **T1.7** `all Unavailable → 0, no divide-by-zero` — `available 0`, `score 0`, `capped true`, `band low`.
- **T1.8** `determinism over 100 invocations` — `assess(s1Inputs())` ×100 → identical `score`, `bandLabel`, `ordered.map((r) => (r.dimension, r.status, r.detail))`.
- **T1.9** `monotonic per dimension over Missing<Inferred<Partial<Complete` — for each dimension, for each base combination of the other four over the same four statuses (4⁴ = 256), for each adjacent upgrade of the dimension: `score(after) >= score(before)`.
- **T1.10** `credits match §3.3` — `complete.credit 1.0`, `partial 0.5`, `inferred 0.3`, `missing 0.0`, `unavailable.credit == null`.
- **A.11** `ordering: Missing → Partial → Inferred → Complete → Unavailable, weight desc inside` — `combine(rows(d1: missing, d2: partial, d3: missing, d4: complete, d5: unavailable)).ordered.map(dimension)` == `[pilotFit, opponentIdentity, combatLog, opponentFit, damageProfile]`.
- **A.12** `topGap is the highest-weight Missing row` — S1 → `topGap.dimension == pilotFit`; S7 → `topGap == null`.
- **A.13** `pointsToComplete` — S1: pilotFit 30, damageProfile 8 (`15 × 0.5 = 7.5 → 8`), opponentFit 14, combatLog 0; unavailable rows 0.
- **A.14** `combine rejects duplicate or missing dimensions` — `throwsArgumentError` for 4 rows and for two `pilotFit` rows.
- **A.15** `rounding is half-up` — `rows(missing, complete, complete, inferred, partial)` earned 48.5 → 49; `rows(complete, complete, complete, inferred, partial)` 78.5 → 79.
- **A.16** `headline copy per band` — low: `rows(missing, complete, missing, partial, missing)` → 30; `headline` starts `'Analysis at 30% evidence will produce general coaching, not specific fit advice.'` and contains `'Attaching your fit would raise this to about 60%.'` (the spec's S4 example). Partial (S1): equals the §2.4 partial sentence. Good (`rows(complete, complete, complete, inferred, partial)` → 79) and complete (S7): exact §2.4 sentences. Capped (S6 via `assess(s6Inputs())`): headline ends with the first Unavailable row's detail.

### 7.2 Group B — `domain/aar_evidence_dimensions_test.dart` (pure; static evaluators)

Each test asserts `status`, that `detail` is non-empty, and the exact `actions` list.

- **T2.1** `D1 Complete: confirmed snapshot, derived, no unresolved` — `pilotFitEvidence: fitEvidence(confidence: confirmed)`, `bundle.self = derivation()` → `complete`, actions `[]`, detail starts `'Current ship snapshot, confirmed for this fight'`.
- **T2.2** `D1 Partial: unresolved modules` — `derivation(unresolvedTypeIds: [99991, 99992])` → `partial`, detail contains `'2 modules not in the SDE'`.
- **T2.3** `D1 Partial: All V skills` — `derivation(basis: allFive)` → `partial`, detail contains `'skills assumed All V'`.
- **T2.4** `D1 Missing: no pilot fit` — `enrichment(pilotFitEvidence: null)`, victim ≠ pilot → `missing`, actions `[useCurrentFit, importFit]`, detail `'No pilot fit attached for this fight.'`.
- **T2.5** `D1 Missing: derivation failed` — evidence present, `bundle = AarDerivationBundle(unknowns: [AarUnknown(pilotFit, 'Ship type not in SDE', 'Ship type 12345 (Foo) is not in the bundled SDE.')])` → `missing`, detail equals the unknown's detail, actions `[useCurrentFit, importFit]`.
- **B.5a** `D1 Inferred: unconfirmed snapshot` — `fitEvidence(confidence: reference, evidenceTime: DateTime.utc(2026, 9, 10, 18))`, `bundle.self = derivation()` → `inferred`, detail contains `'2026-09-10 18:00 UTC'` and `'not confirmed'`, actions `[useCurrentFit, importFit]`.
- **B.5b** `D1 Complete: own-loss killmail is the pilot fit (C4)` — `pilotFitEvidence: null`, `victimCharacterId: 42`, encounter characterId 42, `victimFitEvidence: fitEvidence(role: victim, source: killmail, confidence: proven)`, `bundle.self = derivation(fitSource: killmail)` → `complete`, detail starts `'Own loss killmail #1234567'`.
- **B.5c** `D1 Missing when enrichment is null` — `enrichment: null` → `missing`, actions `[useCurrentFit, importFit]`.
- **T2.6** `D2 Complete: 25 damage events, both directions` — `encounterWith(incomingEvents: 13, outgoingEvents: 12)` → `complete`, detail `'25 damage events over 96s, both directions'`.
- **T2.7** `D2 Partial: outgoing only` — `encounterWith(incomingEvents: 0, outgoingEvents: 25)` → `partial`, detail ends `'outgoing only'`.
- **T2.8** `D2 Partial: 8 damage events` — `encounterWith(incomingEvents: 4, outgoingEvents: 4)` → `partial`, detail contains `'(fewer than 20)'`.
- **T2.9** `D3 Complete: matched 0.92` → `complete`, detail `'Killmail #1234567 matched (92%), victim Target Pilot'`.
- **T2.10** `D3 Partial: matched 0.55` → `partial`, detail starts `'Killmail #1234567 matched at low confidence (55%)'`.
- **T2.11** `D3 Partial: ambiguous` — `enrichment(status: ambiguous, killmailId: null, victimCharacterId: null, matchReason: 'Two killmails within 60s.')` → `partial`, detail `'Ambiguous killmail match: Two killmails within 60s.'`.
- **T2.12** `D3 Missing: needsReauth` — → `missing`, actions `[reauthorize]`.
- **T2.13** `D3 Unavailable: logOnly after a completed search` — `enrichment(status: logOnly, killmailId: null, victimCharacterId: null, killmailSearchCompleted: true, matchReason: 'No ESI or zKill killmail matched this encounter.')` → `unavailable`, detail equals matchReason, actions `[]`.
- **B.13a** `D3 Missing: not searched (null enrichment)` — `enrichment: null`, characterId 42 → `missing`, actions `[searchKillmails]`, detail `'Killmail search has not run for this encounter.'`.
- **B.13b** `D3 Missing: logOnly row written before any search` — `enrichment(status: logOnly, killmailSearchCompleted: false, matchReason: CombatEnrichment.uncachedMatchReason)` → `missing`, actions `[searchKillmails]`.
- **B.13c** `D3 Unavailable: no authenticated character` — `enrichment: null`, `encounterWith(characterId: null)` → `unavailable`, actions `[]`.
- **T2.14** `D4 Inferred: opponent derived from killmail` — S1 → `inferred`, detail starts `'Killmail #1234567 shows destroyed and dropped modules only'`.
- **T2.15** `D4 Missing: identity not searched` (replaces "opponent identified, no fit", C7) — `enrichment: null` → `missing`, actions `[searchKillmails]`.
- **T2.16** `D4 Unavailable: D3 Unavailable` — the T2.13 enrichment → `unavailable`, detail `'No opponent identified; there is no fit to derive.'`.
- **B.16a** `D4 Unavailable: own loss (attacker fit not exposed)` — B.5b inputs → `unavailable`, detail starts `'Own loss killmail #1234567: attacker fittings'`.
- **B.16b** `D4 Partial: opponent ship not in SDE` — kill, `victimFitEvidence` present, `bundle.opponent == null`, `unknowns: [AarUnknown(opponentFit, 'Ship type not in SDE', 'Ship type 12345 (Foo) is not in the bundled SDE.')]` → `partial`, detail equals the unknown's detail.
- **B.16c** `D4 Unavailable: ambiguous` — T2.11 enrichment → `unavailable`.
- **B.16d** `D4 Missing: needsReauth` — → `missing`, actions `[reauthorize]`.
- **T2.17** `D5 Complete: no unknown weapons, all sdeExact` — `encounterWith(12, 12)`, `incoming = profile(profiled: 1200, resolved: ['Railgun'])`, `outgoing = profile(profiled: 1200, resolved: ['Hobgoblin II'])` → `complete`, detail `'All 2 weapons resolved; 100% of damage typed from SDE attributes.'`.
- **T2.18** `D5 Partial: 2 of 14 unresolved, 85% typed` — `encounterWith(incomingEvents: 10, outgoingEvents: 10)` (1000/1000), `incoming = profile(profiled: 700, resolved: 9 names, unknown: ['Unknown', 'Civilian Gatling Railgun'])`, `outgoing = profile(profiled: 1000, resolved: 3 names)` → typed `1700/2000 = 0.85` → `partial`, detail `'2 of 14 weapons unresolved (Civilian Gatling Railgun, Unknown); 85% of damage typed.'`.
- **T2.19** `D5 Inferred: 60% typed` — `incoming = profile(profiled: 200, resolved: ['Railgun'], unknown: ['Unknown'])`, `outgoing = profile(profiled: 1000, resolved: ['Railgun'])` → `1200/2000 = 0.6` → `inferred`.
- **T2.20** `D5 Unavailable: nothing typed` (replaces Missing, C7) — both profiles `profile(profiled: 0, resolved: [], unknown: ['Unknown'])`, `hasKnownDamageTypes == false` → `unavailable`, detail starts `'None of the 1 weapons in this log resolve'`, actions `[]`.
- **B.20a** `D5 Unavailable: no damage in either direction` — encounter built from a single miss line → `unavailable`, detail `'No damage recorded in either direction.'`.
- **B.20b** `D5 skips a direction with zero damage` — `encounterWith(incomingEvents: 10, outgoingEvents: 0)`, `incoming = profile(profiled: 1000)`, `outgoing = profile(profiled: 0, resolved: [])` → `complete`.
- **T2.21** `every status carries non-empty detail` — run all five evaluators over `[s1Inputs(), s1bInputs(), s6Inputs(), s6Inputs(withPilotFit: false), s7Inputs(), inputs with enrichment null]`; every `detail.trim().isNotEmpty`.
- **T2.22** `invariant I1: Missing ⇔ actionable` — over the same input set: `status == missing` iff `actions.isNotEmpty`; every `unavailable` row has `actions.isEmpty`.
- **B.23** `no dimension reads another's status` — `pilotFit(inputs)` result is identical when the enrichment's `status` toggles between `killmailMatched` and `needsReauth` with the pilot fit fixed; `damageProfile(inputs)` identical when `bundle` toggles between empty and S1.

### 7.3 Group C — `domain/aar_evidence_limits_test.dart`

- **T3.1** `no scored dimension references range` — `AarEvidenceDimension.values.map(label)` contains no `'range'`/`'Range'`; `assess(s7Inputs()).dimensions.every((r) => !r.detail.toLowerCase().contains('range'))`.
- **T3.2** `structuralLimits contains the range entry` — `assess(s1Inputs()).structuralLimits.contains(AarStructuralLimit.range)`.
- **T3.3** `range never affects earned or available` — `assess(s7Inputs())`: `available 100`, `earned 100`; `combine(rows(all complete))` equals regardless of `structuralLimits`.
- **T3.4** `a 100% assessment still lists the range limit` — S7 → `score 100` and `structuralLimits.length == 1`.

### 7.4 Group D — report provenance

`domain/combat_aar_report_test.dart` (extend):
- **D.1** `evidenceAtGeneration round-trips through toJson/fromJson` — snapshot `{49, partial, false, S1 statuses}` → `toJson()['evidenceAtGeneration']` present → `fromJson` returns equal snapshot; `toJson()['version'] == 3`.
- **T4.3** `report without a recorded score reads null, not 0` — `fromJson` of a v3 map lacking the key → `evidenceAtGeneration == null`; `fromLegacy(...)` → null.
- **D.2** `toJson omits the key when null` — `!toJson().containsKey('evidenceAtGeneration')`.
- **T4.4** `re-analysis offered at recorded + 10` — `AarEvidenceSnapshot(score: 45, ...).shouldOfferReanalysis(55) == true`.
- **T4.5** `not offered at recorded + 9` — `shouldOfferReanalysis(54) == false`; also `shouldOfferReanalysis(30) == false`.
- **D.3** `snapshot fromJson tolerates unknown names` — `{'score': 60, 'band': 'good', 'capped': false, 'statuses': {'pilotFit': 'missing', 'bogus': 'complete', 'combatLog': 'weird'}}` → statuses `{pilotFit: missing}`; `fromJson('nope') == null`; `fromJson({'band': 'good'}) == null`.

`domain/combat_enrichment_test.dart` (new):
- **D.4** `killmailSearchCompleted round-trips` — `toJson()['killmailSearchCompleted']` true/false → `fromJson` equal.
- **D.5** `legacy row without the key: logOnly + uncached reason → false` — map without key, `status 'logOnly'`, `matchReason: CombatEnrichment.uncachedMatchReason` → `false`.
- **D.6** `legacy row without the key: logOnly + search reason → true`; `killmailMatched` → true; `needsReauth` → true.
- **D.7** `toPromptJson never contains killmailSearchCompleted` — for both flag values `toPromptJson()` maps are deep-equal and lack the key.

`data/combat_analysis_service_test.dart` (extend, same harness as T9.2):
- **T4.1** `analyzeEncounter records the evidence score on the stored report` — seed the T9.2 enrichment (pilot fit confirmed, logOnly, `killmailSearchCompleted: true`); run; decode `analysisJson`; `evidenceAtGeneration` is a Map with `score` an int in 0..100, `statuses['pilotFit']` in `{complete, partial}`, `band` a valid name; `version == 3`.
- **T4.2** `recorded score is not recomputed on load` — after T4.1, save a second enrichment with `pilotFitEvidence: null`, reload the row via `getCachedAnalysis` → `CombatAarReport.fromJson(...).evidenceAtGeneration.score` unchanged.
- **T4.6** `prompt v4 payload is unchanged` — capture `fake.capturedPrompt`; `jsonDecode` top-level keys ⊆ `{schema, pilot, startTime, endTime, durationSeconds, outcomeHint, outcomeEvidence, aggregates, events, eventOmittedCount, killmailEvidence, evidenceLedger, pilotFitEvidence, victimFitEvidence, derivedFits, damageMatchups, compactEvidence}`; `schema == 'mimir.combat_aar_input.v4'`; the prompt string contains neither `'killmailSearchCompleted'` nor `'evidenceAtGeneration'` nor `'evidenceScore'`; `payload['killmailEvidence']` equals `enrichment.toPromptJson()` for the enrichment passed to the client.
- **D.8** `progress stage 5 label unchanged, detail mentions scoring` — labels list still has 9 stages with `'Deriving fit statistics'` at index 4.
- **D.9** `enrichEncounter marks killmailSearchCompleted` (`data/combat_enrichment_service_test.dart`, extend) — an encounter with `characterId: null` → saved row has `status logOnly` and `killmailSearchCompleted == true`; `importPilotFit` on an encounter with no row → `false` and `matchReason == uncachedMatchReason`; `importPilotFit` after a completed search preserves `true`.

### 7.5 Group E — `data/aar_evidence_provider_test.dart` (`ProviderContainer`, no widgets)

Overrides used throughout: `combatEnrichmentProvider(encounter.id).overrideWith((ref) async => holder.enrichment)`,
`aarFitDerivationsProvider(encounter).overrideWith((ref) async => holder.bundle)`,
`combatIncomingDamageProfileProvider(encounter).overrideWith((ref) async => holder.incoming)`,
`combatDamageProfileProvider(encounter).overrideWith((ref) async => holder.outgoing)`,
`codexAnalysisClientProvider.overrideWithValue(CountingCodexClient(...))` (subclass whose
`analyzeEncounter` increments a counter and throws). `holder` is a mutable fixture object.
The same `encounter` instance is used for override and read (D8).

- **T5.1** `assessment resolves from the four providers without the analysis client` — S1 holder → `await container.read(aarEvidenceAssessmentProvider(encounter).future)` → `score 49`.
- **T5.2** `zero analysis client calls during scoring` — `counter == 0` after T5.1; also `combatAnalysisServiceProvider` is never read (override it with a throwing provider).
- **T5.3** `invalidating the enrichment provider recomputes` — set `holder.enrichment = enrichment(pilotFitEvidence: fitEvidence())`, `holder.bundle = bundle with self`; `container.invalidate(combatEnrichmentProvider(encounter.id))`; re-read → `score 79`.
- **T5.4** `scores with no enrichment row` — `holder.enrichment = null`, `holder.bundle = const AarDerivationBundle.empty()` → completes; `[pilotFit].status missing`, `[opponentIdentity].status missing` with `[searchKillmails]`, `[combatLog].status complete`.
- **E.5** `provider error surfaces as AsyncError, not a throw in the scorer` — profile override throws `StateError` → `container.read(provider)` after awaiting is `AsyncError`; no assertion in the scorer fires.

### 7.6 Group F — `presentation/aar_evidence_checklist_card_test.dart`

Pump `MaterialApp(home: Scaffold(body: AarEvidenceChecklistBody(assessment: a, handlers: h, collapsed: false, onToggle: ...)))`
for rendering tests; pump `ProviderScope(overrides: [aarEvidenceAssessmentProvider(encounter).overrideWith(...)], child: MaterialApp(home: Scaffold(body: AarEvidenceChecklistCard(encounter: encounter, handlers: h))))` for state tests.
`h = AarEvidenceActionHandlers(onUseCurrentFit: () => calls.add('use'), onImportFit: ..., onSearchKillmails: ..., onReauthorize: ...)`.

- **T6.1** `renders five rows for a fully-scored assessment` — S1 → `find.byKey(Key('aar-evidence-row-<d>'))` ×5.
- **T6.2** `row order matches AC2.2` — S1 → the five row widgets' `dy` ascend in the order pilotFit, damageProfile, opponentFit, combatLog, opponentIdentity.
- **T6.3** `Missing pilot-fit row renders Use Current Fit and Import Fit` — keys `aar-evidence-action-useCurrentFit-pilotFit`, `aar-evidence-action-importFit-pilotFit`; tapping each calls its handler once.
- **T6.4** `Complete pilot-fit row renders no buttons` — S7 → `find.byType(OutlinedButton)` inside row pilotFit is `findsNothing`.
- **T6.5** `Unavailable row renders no buttons and shows its reason` — S6 → opponentIdentity row has no button; `find.text('No ESI or zKill killmail matched this encounter.')`.
- **T6.6** `point projection renders on Missing rows` — S1 → `find.byKey(Key('aar-evidence-gain-pilotFit'))` with text `'+30 pts'`; no gain key on combatLog.
- **T6.7** `at 100% the list is collapsed; tapping expands it` — S7 via the provider path → rows absent, `aar-evidence-toggle` present; tap → five rows.
- **T6.8** `loading renders the skeleton, not a bare spinner` — override with a never-completing `Completer` → `find.byKey(Key('aar-evidence-skeleton'))`, `find.text('Assessing evidence…')`, `find.byType(CircularProgressIndicator)` findsNothing, `LinearProgressIndicator` with `value == null`.
- **T6.9** `error renders the card without throwing` — override throws → `find.text('Evidence assessment unavailable')`; no exception in `tester.takeException()`.
- **T6.10** `Known limits section renders the range entry` — `aar-evidence-limits` present; `find.text('Engagement range is not recorded in EVE combat logs.')`.
- **T6.11** `progress bar colour matches the band` — S1 (partial) → `LinearProgressIndicator.color == EveColors.warning`; S7 → `EveColors.success`; a 20-score assessment → `EveColors.error`.
- **F.12** `buttons are hidden when the handler is null` — S1 with `const AarEvidenceActionHandlers()` → no action buttons; row still renders.
- **F.13** `previous assessment stays visible during a reload` — provider path with a `holder`; first read S1; change holder to S1+fit and `container.invalidate(combatEnrichmentProvider(...))` (override the four upstream providers as in Group E, not the assessment itself); `pump()` once (no settle) → `find.text('49%')` still present and no skeleton; `pumpAndSettle()` → `find.text('79%')`.
- **F.14** `each row shows icon, name, status word, and detail` — S1: for every row find `dimension.label`, `status.label`, and the detail string.

### 7.7 Group G — `presentation/aar_pre_analysis_gate_test.dart`

Pump `AarPreAnalysisGate(assessment: a, onAnalyze: () => taps++)` inside `MaterialApp`. Assessments come from `combine(rows(...))`: **low 30** = `rows(missing, complete, missing, partial, missing)`; **partial 64** = `rows(partial, complete, complete, inferred, partial)`; **good 79** = `rows(complete, complete, complete, inferred, partial)`; **0** = all missing; **100** = all complete; `s6Inputs()` for the capped chip.

- **T7.1** `low band renders a warning naming pilot fit above the button` — score 30 → `aar-gate-warning` present, its text contains `'Attaching your fit would raise this to about 60%.'`; warning `dy` < button `dy`.
- **T7.2** `partial band renders an advisory, not a warning` — score 64 → `aar-gate-advisory` present, `aar-gate-warning` absent, text equals the §2.4 partial sentence.
- **T7.3** `good band renders neither; the chip does` — score 79 → no warning/advisory; `aar-gate-chip` with `'79% Good'`.
- **T7.4** `analyze button enabled at 0, 30, 64, 79, 100 and for null` — for each: `tester.widget<FilledButton>(find.byKey(Key('aar-analyze-button'))).enabled`; tap → `taps` increments.
- **T7.5** `no dialog at any score` — after each tap `find.byType(AlertDialog)` and `find.byType(Dialog)` are `findsNothing`.
- **G.6** `capped label survives in the chip` — S6 assessment → chip `'100% Complete (capped)'`.

### 7.8 Group H — `presentation/analysis_multipane_evidence_test.dart`

Pump `AnalysisMultiPaneScreen(encounter: encounter)` inside `ProviderScope` with:
`combatAnalysisServiceProvider.overrideWithValue(FakeAnalysisService(cached: null | row))`
(subclass overriding `getCachedAnalysis` and `analyzeEncounter`), the four upstream
providers as in Group E, `combatEnrichmentServiceProvider.overrideWithValue(FakeEnrichmentService(holder))`
(subclass whose `captureCurrentPilotFit` sets `holder.enrichment`/`holder.bundle` and returns it),
`itemNameProvider` overrides for ship ids used, and `sdeInitializerProvider.overrideWith((ref) async {})`
if reached. Use `tester.view.physicalSize = Size(1400, 1000)`.

- **T8.1** `card renders above the killmail chips post-analysis` — cached row present (analysisJson = a v3 report with a snapshot) → `find.byType(AarEvidenceChecklistCard)` `dy` < `find.text('Evidence')` (the evidence card title) `dy`.
- **T8.2** `old three-button Wrap no longer renders` — `find.text('Import Pilot Fit')`, `find.text('Snapshot Current Fit')`, `find.text('Use Current Fit For This Fight')`, `find.text('Reauthorize Character')` outside a checklist row: all `findsNothing`.
- **T8.3** `tapping Use Current Fit on the row invokes the capture path` — pre-analysis; tap `aar-evidence-action-useCurrentFit-pilotFit` → `FakeEnrichmentService.captureCalls == [(encounter.id, confirmed: true)]`.
- **T8.4** `after capture the score rises and the row moves` — continue: `pumpAndSettle` → `find.text('79%')`, pilotFit row `dy` now greater than damageProfile row `dy`, no action buttons on it (AC4.3).
- **T8.5** `score chip renders next to the analyze button in the empty state` — pre-analysis with a good-band holder → `aar-gate-chip` and `aar-analyze-button` share a `Row` ancestor.
- **H.6** `pre-analysis renders the full checklist card` (C1) — pre-analysis → `find.byType(AarEvidenceChecklistCard)` and `find.byType(AarPreAnalysisGate)`.
- **H.7** `provenance banner: recorded 49, current 79 → re-analyze prompt` — cached row snapshot score 49, holder at 79 → `aar-provenance-recorded` text contains `'generated at 49% Partial evidence'` and `'Evidence is now 79%'`; `aar-provenance-reanalyze` present; tap → `FakeAnalysisService.analyzeCalls.last.forceRefresh == true`.
- **H.8** `provenance banner: recorded 79, current 85 → no prompt` — `aar-provenance-reanalyze` absent.
- **H.9** `legacy report shows "not recorded"` — cached row with `analysisJson: null` and legacy text columns → `find.text('Evidence at generation: not recorded')`; no `'0%'` text.
- **H.10** `Search Killmails row action calls enrichEncounter and invalidates` — `holder.enrichment = null` → tap `aar-evidence-action-searchKillmails-opponentIdentity` → `FakeEnrichmentService.enrichCalls.length == 1`; after settle the D3 row reflects the holder's new enrichment.

### 7.9 Group I — `domain/aar_evidence_logging_test.dart`

Capture `debugPrint` (`final prior = debugPrint; debugPrint = (m, {wrapWidth}) => lines.add(m ?? '');` restore in `tearDown`).

- **T9.1** `assess emits [AAR.EVIDENCE] info with score, band, and statuses` — `assess(s1Inputs())` → some line matches `RegExp(r'^\[AAR\.EVIDENCE\] ℹ️ score=49 band=partial capped=false pilotFit=missing combatLog=complete opponentIdentity=complete opponentFit=inferred damageProfile=partial$')`.
- **I.2** `provider logs a START line` — Group E container read → a line starting `'[AAR.EVIDENCE] aarEvidenceAssessmentProvider(encounter='`.
- **I.3** `service logs the recorded score` — in T4.1, a line matching `'[AAR.EVIDENCE] ℹ️ analyzeEncounter(<id>) recording '`.

### 7.10 Regression (AC7)

- `flutter test test/features/combat_analyzer` all green with no edits to existing expectations; the only existing files touched are the three `EDIT` test files in §6, which gain cases.
- `flutter analyze` clean.
- T4.6 is the AC7.3 guard; `analysis_multipane_screen.dart` diff removes lines and adds the §5.4 items only (AC7.4 is guarded by T4.6 plus D.8).

---

## 8. Unit breakdown for Plan (TDD; RED → GREEN → REFACTOR)

Tiering by work shape: judgement/design → Opus; mechanical/deterministic → Sonnet.
Each unit ends with `flutter analyze` clean and its own tests green; commits are
atomic per unit (`type(scope): description`, no attribution lines).

**U1 [P1] Domain scorer** — Opus.
- RED: write `fixtures/aar_evidence_fixtures.dart`, then Groups A, B, C (§7.1–7.3) and Group I T9.1. All fail to compile.
- GREEN: `aar_evidence_assessment.dart`, `aar_evidence_scorer.dart`; add `resolvedWeapons` to `CombatDamageProfile` and `killmailSearchCompleted`/`uncachedMatchReason` to `CombatEnrichment` (model fields only, needed by the fixtures).
- REFACTOR: hoist detail-string builders into private helpers; confirm no rule reads another dimension's status (B.23).
- Commit: `feat(combat): add pure AAR evidence completeness scorer`.

**U2 [P1] Report provenance and enrichment flag** — Sonnet.
- RED: Group D model rows (D.1–D.7, T4.3–T4.5) in `combat_aar_report_test.dart` and new `combat_enrichment_test.dart`; D.9 in `combat_enrichment_service_test.dart`.
- GREEN: `CombatAarReport.evidenceAtGeneration` + `withEvidenceAtGeneration`; `CombatEnrichment` JSON/copyWith/legacy inference; `enrichEncounter()` sets the flag; `_loadOrCreateEnrichment` uses the constant; resolver fills `resolvedWeapons`.
- REFACTOR: none expected.
- Commit: `feat(combat): record evidence snapshot on AAR reports; mark killmail search completion`.

**U3 [SEQ after U1, U2] Provider and service wiring** — Sonnet.
- RED: Group E (§7.5); Group D service rows T4.1, T4.2, T4.6, D.8; Group I I.2, I.3.
- GREEN: `aarEvidenceAssessmentProvider`; `analyzeEncounter()` scores at stage 5 and attaches the snapshot before save.
- REFACTOR: none.
- Commit: `feat(combat): score AAR evidence before analysis and persist it with the report`.

**U4 [SEQ after U3] Widgets** — Sonnet.
- RED: Group F (§7.6) and Group G (§7.7).
- GREEN: `aar_evidence_checklist_card.dart`, `aar_pre_analysis_gate.dart`, `aar_report_provenance_banner.dart`.
- REFACTOR: share the status icon/colour map between row and header.
- Commit: `feat(combat): add AAR evidence checklist card, pre-analysis gate, and provenance banner`.

**U5 [SEQ after U4] Screen integration** — Opus (the removal touches live handlers; judgement on layout).
- RED: Group H (§7.8).
- GREEN: §5.4 items 1–6; delete the `Wrap` and the reauth button; `_searchKillmails()`.
- REFACTOR: `_buildAnalyzePrompt` and `_buildAnalysisContent` share the `.when(... => null)` helper for the gate/banner input.
- Commit: `feat(combat): surface evidence checklist and gate in the AAR screen; retire the fit button cluster`.

**U6 [P2 after U5] Journal** — Sonnet. §9. Commit: `docs(journal): closeout AAR evidence completeness score`.

**U7 [SEQ] Closing gate** — Sonnet. `flutter analyze`; full `flutter test`; manual check on macOS: open a fresh encounter (no row) → checklist shows Opponent identity Missing with "Search Killmails"; press it → row changes without navigation; attach current fit → score moves in place with no skeleton flash.

U1 and U2 run in parallel; U3 is the join. U4 can start against U1's contracts
while U3 is in flight if Plan wants to shorten the critical path (the widgets take
`AarEvidenceAssessment`, not the provider, except the card shell).

---

## 9. Journal protocol on ship (spec §11 plus)

- ARCHIVE: QUEUED P1 "AAR evidence completeness score and pre-analysis checklist" as SHIPPED, noting the revised effort (spec §0.4) and the range finding (spec §0.5).
- LEARNINGS: (1) *EVE combat logs carry no engagement range* (spec §0.5) — constrains the QUEUED P2 tracking/application work; (2) *`Missing` must mean "there is a button"* (I1) — a score that carries unfixable red rows trains users to ignore it; (3) *the killmail search only runs inside analysis* — anything that wants killmail evidence before the LLM call must trigger the search explicitly; (4) *report-output models are safe to extend without touching the prompt* — the prompt is built from inputs, the report is parsed from output, and a test that lists the payload's top-level keys is the cheap guard.
- DECISIONS: D5 (no automatic pre-analysis search), D6 (unconfirmed snapshot button retired), D7 (I1).
- QUEUE P3: weight recalibration from `[AAR.EVIDENCE]` score distributions (spec R2); persist checklist expand/collapse (spec §4.6); automatic killmail search on encounter open behind a setting (D5); opponent-fit manual import (would make D4 rows 6–7 reachable).

---

## 10. Out of scope, stated

Blocking analysis at any score; changing prompt schema v4 or `CombatAarReport.version`;
automatic re-analysis; automatic killmail search; new evidence sources; a Drift
migration (none needed); range telemetry; re-scoring historical reports.
