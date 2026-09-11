# AAR Evidence Completeness Score & Pre-Analysis Checklist — Implementation Plan

## Goal

Ship QUEUED.md P1 "AAR evidence completeness score and pre-analysis checklist" as a presentation-and-policy milestone over data Milestone 2 already produces: compute a deterministic, explainable 0–100 score from five evidence dimensions, render a prioritized checklist that tells the user which single action would most improve the next AAR, gate the "Analyze With AI" call with a non-blocking warning/advisory, and surface re-analysis when evidence improves. No new data sources, no new SDE work, no prompt-schema change.

## Success Criteria

- Opening an encounter shows **Evidence Completeness 0–100%** with band label (Low/Partial/Good/Complete, " (capped)" suffix when structural limits apply) and a **headline** explaining what the current evidence can/cannot conclude, before any LLM spend.
- Five dimension rows render (pilot fit 30, combat log 20, opponent identity 15, opponent fit 20, damage profile 15) with status ∈ {Complete, Partial, Inferred, Missing, Unavailable}, credit {1.0, 0.5, 0.3, 0.0, excluded}, detail text, `+N pts` projection on Missing rows, and inline CTAs that call the **existing** handlers.
- Rows sort by actionability then impact: Missing (weight desc) → Partial → Inferred → Complete → Unavailable; `topGap` is the highest-weight improvable row; S1 (49 Partial) pilot-fit `+30 pts` projects to `79 Good`.
- Pre-analysis gate is **never blocking**: `<40` warns, `40–74` advises, `≥75` shows a quiet `score% band` chip; button stays enabled and no dialog appears at any score.
- Post-analysis report carries `evidenceAtGeneration: AarEvidenceSnapshot?` (inside `analysisJson`, `CombatAarReport.version` stays 3); a banner reads "generated at N%" and offers **Re-analyze** when `current − recorded ≥ 10`.
- Structural-limit section always lists *Engagement range is not recorded in EVE combat logs*; range never enters earned/available and never prevents 100%.
- `aarEvidenceAssessmentProvider` recomposes on enrichment/pilot-fit/killmail change without a reload or navigation; `skipLoadingOnReload: true` keeps the prior assessment on screen.
- `flutter analyze` clean, `flutter test` (full suite including new groups A–I) green; all new public methods log `[AAR.EVIDENCE]` / `[COMBAT.UI]` per CLAUDE.md.

## Context And Current Facts

**Sources inspected for this plan:** `docs/specs/aar-evidence-completeness-score.md` (Product, spec, 2026-09-11), `docs/specs/aar-evidence-completeness-score-design.md` (Arch HOW, same date, §0 C1–C12 + §2–§9), `lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart` (1,812 lines: `_buildAnalyzePrompt` at :228 is a centred empty state with no evidence card; evidence card + three-button `Wrap` at :616–628 live only in `_buildAnalysisContent`; `_captureCurrentFit` / `_showImportFitDialog` exist), `lib/features/combat_analyzer/domain/combat_enrichment.dart` (`CombatEnrichment` has `status/source/killmailId/victim*/destroyedFit/pilotFitEvidence/victimFitEvidence/matchConfidence/matchReason` but no `killmailSearchCompleted`), `lib/features/combat_analyzer/domain/combat_evidence_ledger.dart` (`EvidenceSource` 6 values, no `dogmaDerivation` needed here but scorer imports it; `AarUnknownCategory` 7 values, no `skills` pair beyond enrichment), `lib/features/combat_analyzer/domain/combat_aar_report.dart` (`version = 3`; report is output, prompt is built from `encounter + enrichment + derivation` in `codex_analysis_client.dart`, so a nullable field on the report cannot alter the prompt — C9), `lib/features/combat_analyzer/domain/combat_damage_profile.dart` (`totalProfiledDamage` sums resolved only; `unknownWeapons` present; `resolvedWeapons` absent — C6), `lib/features/combat_analyzer/data/combat_providers.dart` (`combatEnrichmentProvider` only loads cached row; `combatDamageProfileProvider`/`combatIncomingDamageProfileProvider` exist; `aarFitDerivationsProvider` short-circuits to `AarDerivationBundle.empty()` with no row), `lib/features/combat_analyzer/data/combat_analysis_service.dart` / `codex_analysis_client.dart` (`analyzeEncounter` stage 4 enrich, stage 5 derive → LLM; schema `mimir.combat_aar_input.v4`; `stageCount 9` at develop:855ba5b), `lib/features/fitting/domain/aar_fit_derivation.dart` / `aar_evidence_scorer` (does not yet exist — this plan creates it), `docs/engineering-journal/QUEUED.md` (P1 entry describes the checklist need and "worth it when" Milestone 2 ships — now shipped at f1225a9/855ba5b).

**Spec conflict resolved:** The spec (§0.1 + C1–C12) and the design doc agree the score is computable with zero new I/O; the design corrects twelve binding mismatches where spec rules read models they cannot carry. This plan adopts the design as contract: pre-analysis has no evidence pane so the checklist must render in **both** placements (C1); killmail search has not run before the first analysis so D3 needs `notSearched → Missing` + a persisted `killmailSearchCompleted` flag (C2/D5); `AarDerivationBundle` folds failures into unknowns (C3); own-loss killmail is the pilot fit (C4 → S1 is a kill, S1b is the loss); typed fraction redefined over `totalDamageReceived/Dealt` plus `resolvedWeapons` (C6); `Missing ⇔ actionable` invariant I1 makes D4-Missing and D5-Missing `Unavailable` (C7); D3 `Inferred` unreachable dropped (C8); report snapshot is the right storage (C9); `notSearched` CTA reuses `enrichEncounter()` (C10); unconfirmed-snapshot button retired with the `Wrap` (C11/D6); `skipLoadingOnReload: true` prevents skeleton flash (C12). Fixes are additive.

**What Milestone 2 gave us (spec §0.2):** `CombatEnrichment.pilotFitEvidence/victimFitEvidence/source/confidence`, `AarFitCoverage` (per-slot fitted/total + `unresolvedTypeIds`), `AarSkillContext.basis`, `CombatEnrichmentStatus + matchConfidence`, `AarDerivationBundle.opponent`, `CombatDamageProfile.entries/confidence/unknownWeapons/totalProfiledDamage`, `TankAssessment`, `AarDerivationBundle.unknowns` — all wired through `aarFitDerivationsProvider` independently of the LLM call. The score composes those four providers; an `AarEvidenceAssessment` is pure and synchronous.

## Constraints And Non-goals

- No new parsing, network calls, scrapers, or SDE work; reads what exists (spec §1.4, R2.2).
- No automatic killmail search on encounter open in V1 — user-initiated via the `notSearched` row (D5, revisit behind a settings toggle).
- No automatic re-analysis; banner offers **Re-analyze**, user decides (S5, R5.3).
- No re-scoring of historical reports on upgrade; `evidenceAtGeneration` absent → "not recorded" (R4.5).
- No change to prompt schema v4 or `CombatAarReport.version` (1.4, C9); no Drift migration (schema stays 20, field lives inside `analysisJson` JSON).
- No fix for range telemetry — displayed as a structural limit outside the denominator (0.5, R3.4).
- No `Missing` row without an action — `Unavailable` carries the reason instead (I1); never show a permanently stuck red row (0.5).
- Must not invent failures from file existence or byte sizes; bare opener "test"/"hi" is conversational, not a task.

## Key Decisions

| # | Decision | Choice | Rejected alternative | Why |
|---|----------|--------|----------------------|-----|
| 1 | Where the score lives | Report field `CombatAarReport.evidenceAtGeneration: AarEvidenceSnapshot?` inside `analysisJson`, nullable, `version` stays 3 | (a) column on `CombatEnrichment`/ledger or Drift migration | Proven it cannot alter the prompt: prompt is built from `(encounter, enrichment, derivation)` only, report is the LLM's parsed output (C9). Snapshot inside the report keeps re-analysis provenance without a migration; `T4.6` lists the payload's top-level keys as guard. |
| 2 | Pre-analysis killmail state | New `CombatEnrichment.killmailSearchCompleted: bool` (default false), plus `uncachedMatchReason` constant; `D3 notSearched → Missing` with Search CTA | Score from enrichment alone and auto-run `enrichEncounter()` on screen open | Before the first analysis the enrichment row does not exist; scoring would always be `Missing` with no way to act. Auto-search is network I/O on every encounter open (D5); single-click row CTA is explicit and explainable; flag separates "never searched" from "searched, nothing found" so denominator is honest (C2, S6). |
| 3 | Gate behaviour | `AarPreAnalysisGate` always enables the button; `<40` warning, `40–74` advisory, `≥75` quiet chip; never a dialog (D1, R5.3) | Blocking dialog or disabled button below a threshold | The spec's governing principle is pre-spend transparency, not gating; blocking would prevent low-evidence coaching users asked for. |
| 4 | Remove the old button cluster | Delete `analysis_multipane_screen.dart:616-635 Wrap` and the `needsReauth` button at 606-614; route via `AarEvidenceActionHandlers` rows (D3, C10, C11) | Keep both clusters | Two competing affordances for the same action splits user attention and duplicates the primary fix (top-gap) signal. "Snapshot Current Fit" (unconfirmed → `Inferred`) is retired from the UI with the Wrap; the method and tests stay (D6). |
| 5 | In both panes, not just post-analysis | Full `AarEvidenceChecklistCard` at top of evidence pane **and** between stat chips and gate in `_buildAnalyzePrompt` (C1, R5.1) | Empty state chip only | The CTA is most valuable pre-analysis — where the user decides to spend tokens — and S2/S3 require same-frame recomputation there. |
| 6 | `Missing ⇔ actionable` invariant (I1) | A dimension scores `Missing` iff it carries ≥1 action; otherwise `Unavailable` with reason | Three separate `Missing` causes for opponent fit / damage profile that have no button | A `+N pts` projection on a row the user cannot fix is a false promise and teaches score distrust — the §0.5 failure mode (C7, D7, T2.22). |
| 7 | Structural limit outside the score | `AarStructuralLimit.range` in a fixed footer; D5 never scores range; five dimensions only | Add "Range" as sixth dimension weighted in denominator | Range cannot be obtained for any encounter (parser carries no distance field, logs carry none); a permanent incomplete row caps every encounter below 100% (R3.4). |
| 8 | Live computation, persisted provenance | `aarEvidenceAssessmentProvider = Family<ParsedCombatEncounter>` composes four existing providers and calls pure `AarEvidenceScorer.assess`; banner compares `recorded.shouldOfferReanalysis(current)` (delta ≥10, R4.3) | Persist the live assessment with the encounter | Live provider guarantees the checklist always reflects current enrichment/skills without a new store; persisted snapshot keeps what the model saw, so drift is visible (S5) without re-scoring history. |
| 9 | Fix reload flash | Card `.when(skipLoadingOnReload: true)` and `skipLoadingOnRefresh: true` on the assessment provider (C12) | Show skeleton during every `ref.invalidate` | Historic providers default to `false`; every fit attach would flash the card to skeleton — S3/S4's "same frame" expectation. |
| 10 | Provider key type | `ParsedCombatEncounter` identity (no `==` override) for `aarEvidenceAssessmentProvider` like `aarFitDerivationsProvider` | Encounter id string | Avoids re-keying when the encounter object gains new fields; screen holds one instance, provider-family tests reuse the same instance (D8). |

## Recommended Approach

**Policy before pixels.** Land the pure scoring model and its snapshot/flag storage first — they are the only judgement in the milestone and every UI string depends on their exact cut-offs (`40/75/90`, `0.8`, `0.7`, `10`). Once `AarEvidenceScorer` and `AarEvidenceAssessment` are unit-locked (S1 49→79, S6 capped 100, S1b loss 91), the data plumbing is a thin composition (provider + report snapshot + enrichment flag + resolver's `resolvedWeapons`), and the widgets are a faithful render of `assessment.dimensions/ordered/topGap/band/capped/headline`. This is Milestone 2's proven layering (pure unit → wiring → widget → screen) with two parallel cuts — scorer and snapshot/flag in parallel, then widgets and screen integration after the provider lands — so no branch carries a spec ambiguity.

## Work Plan

Units are **[SEQ]** sequential or **[P1]/[P2]** parallel as in `docs/specs/aar-evidence-completeness-score-design.md:8`. Each lists **RED→GREEN→REFACTOR** TDD; the test-author must land the RED suite and observe it failing **for the named reason** before the dev branch starts. Commits are atomic per unit (`type(scope): description`, no attribution lines).

### [P1] U1 — Domain scorer

**Tests first (RED).** Write `test/features/combat_analyzer/fixtures/aar_evidence_fixtures.dart` (helpers `encounterWith`/`profile`/`fitEvidence`/`derivation`/`enrichment`/`s1Inputs`/`s1bInputs`/`s6Inputs`/`s7Inputs`/`row`/`rows` per §7.0), then Groups A (§7.1, `aar_evidence_scorer_test.dart` T1.1–T1.10 + A.11–A.16), B (§7.2, `aar_evidence_dimensions_test.dart` T2.1–T2.5 + B.5a–B.5c, T2.6–T2.13 + B.13a–B.13c, T2.14–T2.20 + B.16a–B.16d, B.20a–B.20b + T2.21–T2.22 + B.23), C (§7.3, `aar_evidence_limits_test.dart` T3.1–T3.4), and Group I T9.1 (`aar_evidence_logging_test.dart`). All fail to compile — contracts not yet present.

**Dev (RED → GREEN).** Create `lib/features/combat_analyzer/domain/aar_evidence_assessment.dart` (`AarEvidenceDimension` 5 weights 30/20/15/20/15, `AarEvidenceStatus` 5 credits/sortRanks, `AarEvidenceBand`, `AarEvidenceAction`, `AarEvidenceRules` constants, `AarStructuralLimit.range`, `AarEvidenceDimensionResult`, `AarEvidenceAssessment` with `combine/projectedScoreIf/ordered/topGap/pointsToComplete/headline/bandLabel/capped/collapsedByDefault/toSnapshot/logLine`, `AarEvidenceSnapshot`, `formatAarUtcMinute`), `aar_evidence_scorer.dart` (`AarEvidenceInputs`, `AarEvidenceScorer.assess` + five static evaluators D1–D5 per §2.3 incl. `selfEvidence/victimIsSelf/identityKind/fitFailure` helpers, typed fraction `Σprofiled/ΣT` via `totalDamageReceived/Dealt`, ordering `Missing(0)→Partial(1)→Inferred(2)→Complete(3)→Unavailable(4)` weight-desc, `Log.i [AAR.EVIDENCE] <logLine>`), and model edits adding `resolvedWeapons: const []` to `CombatDamageProfile` and `killmailSearchCompleted = false` + `uncachedMatchReason` to `CombatEnrichment`.

**Refactor.** Hoist per-dimension detail builders; hard-assert no rule reads another dimension's `status` (B.23).

**Gate:** Groups A/B/C/I RED→GREEN; `T1.3 49 Partial`, `T1.4 →79 Good`, `T1.6 100 (capped)`, `A.11` order, `A.13 +30/+8`, `A.16` headlines, `T2.22 I1` (`Missing ⇔ actionable`); `Log` line T9.1 exact.

**Owner:** `domain/` — Opus. **Surfaces:** `domain/aar_evidence_assessment.dart`, `domain/aar_evidence_scorer.dart`, `domain/combat_damage_profile.dart`, `domain/combat_enrichment.dart`.

### [P1] U2 — Report provenance and enrichment flag

*Parallel with U1 (no file overlap with the scorer).*

**Tests first (RED).** Group D model rows (`domain/combat_aar_report_test.dart` D.1/D.3/D.2/T4.3–T4.5/D.3, `domain/combat_enrichment_test.dart` D.4–D.7, `data/combat_enrichment_service_test.dart` D.9). Expect `fromJson` null on missing key, round-trip of snapshot inside `analysisJson`, `toPromptJson` equality across flag values, `killmailSearchCompleted == true` after `enrichEncounter()` and `false` from `_loadOrCreateEnrichment` — all fail because fields/methods absent.

**Dev (RED → GREEN).** `CombatAarReport.evidenceAtGeneration: AarEvidenceSnapshot?` (`withEvidenceAtGeneration`, `toJson` conditional, `fromJson` via `AarEvidenceSnapshot.fromJson`, `fromLegacy` null, `version` stays 3), `CombatEnrichment.killmailSearchCompleted + copyWith + toJson/fromJson + legacy inference` (missing key ⇒ `false` when `status==logOnly && reason==uncachedMatchReason` else `true`; `toPromptJson()` unchanged — T4.7 deep-equality guard), `combat_enrichment_service.dart` (`enrichEncounter` every terminal return `→ _save(...copyWith(killmailSearchCompleted:true))`; `_loadOrCreateEnrichment` and screen `_logOnlyEnrichment` use `uncachedMatchReason` and leave false; `importPilotFit`/`captureCurrentPilotFit` preserve via `copyWith`), resolver `_resolve` collects `resolvedWeapons = damageByWeapon.keys ∖ unknownWeapons`, sorted.

**Gate:** Group D GREEN; `T4.3` null, `D.2` omit-key, `D.7` prompt unchanged, `D.9` flag true after search/false without; resolver tests still green (new field defaults).

**Owner:** `domain/combat_aar_report.dart`, `domain/combat_enrichment.dart`, `domain/combat_damage_profile.dart`, `data/combat_enrichment_service.dart`, `data/combat_damage_profile_resolver.dart` — Sonnet.

### [SEQ after U1, U2] U3 — Provider and service wiring

**Tests first (RED).** Group E (`data/aar_evidence_provider_test.dart` T5.1–T5.4 + E.5), Group D service rows T4.1/T4.2/T4.6/D.8 (`data/combat_analysis_service_test.dart`), Group I I.2/I.3 (`domain/aar_evidence_logging_test.dart`). Fail because `aarEvidenceAssessmentProvider`/`resolvedWeapons`/`evidenceAtGeneration` not wired: `T5.1` counter not incremented, `T4.1` analysisJson has no snapshot, `T4.6` string `killmailSearchCompleted`.

**Dev (RED → GREEN).** `data/combat_providers.dart` — `aarEvidenceAssessmentProvider = FutureProviderFamily<AarEvidenceAssessment, ParsedCombatEncounter>` composing `combatEnrichmentProvider(id) + aarFitDerivationsProvider(encounter) + combatIncomingDamageProfileProvider + combatDamageProfileProvider` into `AarEvidenceScorer().assess(...)` (profiles watched directly so null enrichment still scores — T5.4). `combat_analysis_service.dart` — stage 5 derive + assess + `Log.i [AAR.EVIDENCE] recording <scoreLabel>` + `report.withEvidenceAtGeneration(assessment.toSnapshot())` before `jsonEncode`; detail text `'Running dogma derivation, damage matchups, and evidence scoring.'`; `analysisJson` now carries the snapshot.

**Gate:** Group E GREEN (T5.2 zero `analyzeEncounter` calls, T5.3 invalidate→79, T5.4 null enrichment, E.5 AsyncError), Group D T4.1/T4.2/T4.6/D.8 GREEN; T9.1 scoped logging verified.

**Owner:** `data/combat_providers.dart`, `data/combat_analysis_service.dart` — Sonnet.

### [SEQ after U3] U4 — Widgets

**Tests first (RED).** Group F (`presentation/aar_evidence_checklist_card_test.dart` T6.1–T6.11 + F.12–F.14) and Group G (`presentation/aar_pre_analysis_gate_test.dart` T7.1–T7.5 + G.6). Fail because `AarEvidenceChecklistCard/Body/Row/LimitsSection`/`AarPreAnalysisGate`/`AarReportProvenanceBanner` not yet present: no `aar-evidence-row-*` keys, gate warning absent, skeleton missing.

**Dev (RED → GREEN).** `presentation/widgets/aar_evidence_checklist_card.dart` (`AarEvidenceActionHandlers`, `AarEvidenceChecklistCard` as `ConsumerStatefulWidget` owning `skipLoadingOnReload:true` `.when` (+ skeleton `Key('aar-evidence-skeleton')` / text `Assessing evidence…` indeterminate bar, unavailable card), `AarEvidenceChecklistBody` pure rendering (`LinearProgressIndicator` `Key('aar-evidence-progress')` colour by band, chip `Key('aar-evidence-score-chip')`, headline, toggle `Key('aar-evidence-toggle')`), `AarEvidenceChecklistRow` (`Key('aar-evidence-row-<dim>')` + `aar-evidence-gain-<dim>` + `aar-evidence-action-<action>-<dim>` `OutlinedButton.icon`, `dimension.label/status.label/detail`, projection `+N pts`), `AarEvidenceLimitsSection` (`Key('aar-evidence-limits')`), per-widget `collapsed` default `score ≥ 90`. `aar_pre_analysis_gate.dart` (warning `Key('aar-gate-warning')` / advisory `aar-gate-advisory` sibling above `FilledButton.icon` `Key('aar-analyze-button')` never disabled, no dialog, chip `aar-gate-chip`). `aar_report_provenance_banner.dart` (`AarReportProvenanceBanner` with `recorded/current/currentScore` + `Keys 'aar-provenance-recorded/not-recorded/reanalyze'` and `shouldOfferReanalysis`).

**Gate:** Groups F/G GREEN; `T6.7` collapsed-expand, `T6.8` skeleton, `T7.1` low projects `60%`, `T7.4` enabled at `0/30/64/79/100/null`; no `AlertDialog`.

**Owner:** `presentation/widgets/` — Sonnet (share `EveColors` icon/colour map between row and header in REFACTOR).

### [SEQ after U4] U5 — Screen integration

**Tests first (RED).** Group H (`presentation/analysis_multipane_evidence_test.dart` T8.1–T8.5 + H.6–H.10). Fail because placements absent and old `Wrap` still renders: `T8.1 dy` order wrong, `T8.2` finds `Import Pilot Fit` text outside a checklist row, no pre-analysis card.

**Dev (RED → GREEN).** `analysis_multipane_screen.dart` six edits: (1) add `_searchKillmails()` (`enrichEncounter` → invalidate provider → snackbar, `Log.i [COMBAT.UI]`); (2) `AarEvidenceActionHandlers get _evidenceHandlers` (`useCurrentFit→_captureCurrentFit(confirmed:true)`, `importFit→_showImportFitDialog`, `searchKillmails→_searchKillmails`, `reauthorize→authControllerProvider.notifier.startAuthFlow()`); (3) `_buildAnalyzePrompt` → `SingleChildScrollView > ConstrainedBox(720) > Column[icon, stat chips, AarEvidenceChecklistCard, AarPreAnalysisGate(.when→null fallback)]` removing the bare `FilledButton`; (4) `_buildAnalysisContent` inserts `AarEvidenceChecklistCard` + spacer before the evidence card (above killmail chips); (5) `_buildCommandStrip` adds `AarReportProvenanceBanner` under the headline row; (6) `_buildEvidenceCard` deletes the `needsReauth` block and the three-button `Wrap` (616–635); `_logOnlyEnrichment` uses `uncachedMatchReason`; `Log.d [COMBAT.UI]` on panel build.

**Gate:** Group H GREEN; `T8.4` after tap `79%` rises without leaving screen (`skipLoadingOnReload` keeps prior), `H.6` pre-analysis has both card + gate, `H.7/H.8` threshold `10`, `H.9` legacy "not recorded".

**Owner:** `presentation/analysis_multipane_screen.dart` — Opus. **Commit:** `feat(combat): surface evidence checklist and gate in the AAR screen; retire the fit button cluster`.

### [P2 after U5] U6 — Journal

**Tests:** none — verified by file content review.

**Dev.** As in `aar-evidence-completeness-score-design.md:9`: `ARCHIVE.md` → QUEUED P1 as SHIPPED (noting revised effort §0.4 + range finding §0.5); `LEARNINGS.md` → four entries (no range in logs; `Missing ⇔ actionable`; killmail search must be triggered explicitly; report-output extension safe with payload-key guard T4.6); `DECISIONS.md` → D5/D6/D7; `QUEUED.md` → P3 follow-ups (weight recalibration from `[AAR.EVIDENCE]` distributions; persist checklist collapse; automatic killmail search behind setting; opponent-fit manual import). Same change set per `AGENTS.md`.

**Gate:** `git diff --stat docs/engineering-journal/` shows `QUEUED.md` P1 removed, `ARCHIVE.md` SHIPPED, `LEARNINGS.md` four entries.

**Owner:** `docs/engineering-journal/` — Sonnet.

### [SEQ] U7 — Closing gate

**Dev.** `flutter analyze` clean, full `flutter test` green, `dart format .`; manual check on macOS per design §7 (§7.8's `flutter test` layering): fresh encounter → `Opponent identity Missing` with `Search Killmails`; press it → row changes without navigation; attach current fit → score moves in place with no skeleton flash (C12).

**Gate:** `analyze` + `test` logs pasted into HANDOFF; LEARNINGS notes manual check done or deferred; no Drift migration (schema stays 20).

**Owner:** repo root — Sonnet.

## Validation Plan

Each unit's gate is **RED before GREEN** — implementation is blocked until the unit's test-author suite is observed failing for the named reason. Existing tests are regression-locked: no edits to existing expectations except the listed `EDIT` test files gaining cases.

| Unit | RED suite (test-author lands first) | GREEN implementation check | Exact command / expected evidence |
|------|--------------------------------------|----------------------------|-----------------------------------|
| U1 | `aar_evidence_scorer_test` Groups A/B/C + `aar_evidence_logging_test` T9.1 — fail: contracts missing | Scorer + per-dimension evaluators | `flutter test test/features/combat_analyzer/domain/aar_evidence_scorer_test.dart test/features/combat_analyzer/domain/aar_evidence_dimensions_test.dart test/features/combat_analyzer/domain/aar_evidence_limits_test.dart test/features/combat_analyzer/domain/aar_evidence_logging_test.dart` → all `RED→GREEN`; `T1.3 49 Partial` / `T1.4 →79 Good` / `T1.6 65 available 100 capped` / `A.16` headline with `60%`; `B.23` no cross-dimension read |
| U2 | `combat_aar_report_test` D.1/D.2/T4.3–T4.5/D.3 + `combat_enrichment_test` D.4–D.7 + `combat_enrichment_service_test` D.9 — fail: fields/methods absent | Snapshot + enrichment flag + resolver field | `flutter test test/features/combat_analyzer/domain/combat_aar_report_test.dart test/features/combat_analyzer/domain/combat_enrichment_test.dart test/features/combat_analyzer/data/combat_enrichment_service_test.dart test/features/combat_analyzer/domain/combat_damage_profile_test.dart` → GREEN; `D.7` `toPromptJson` deep-equal across flag values |
| U3 | `aar_evidence_provider_test` Group E + `combat_analysis_service_test` Group D service rows — fail: provider/service not wired | Provider + report snapshot at stage 5 | `flutter test test/features/combat_analyzer/data/aar_evidence_provider_test.dart test/features/combat_analyzer/data/combat_analysis_service_test.dart` → GREEN; `T4.1` `analysisJson.evidenceAtGeneration.score` present, `T4.2` re-read unchanged, `T4.6` top-level keys ⊆ allow-list + `schema v4` no `evidence*` strings; grep `lib/features/combat_analyzer/data/combat_fit_derivation_service.dart` never throws in scorer |
| U4 | `aar_evidence_checklist_card_test` Group F + `aar_pre_analysis_gate_test` Group G — fail: widgets/keys absent | Three widgets | `flutter test test/features/combat_analyzer/presentation/aar_evidence_checklist_card_test.dart test/features/combat_analyzer/presentation/aar_pre_analysis_gate_test.dart` → GREEN; `T6.5` unavailable-no-button + `aar-evidence-limits` range entry, `T7.1` low warning hints `60%`, `T7.4` enabled at `0/30/64/79/100/null` |
| U5 | `analysis_multipane_evidence_test` Group H — fail: old `Wrap` texts found outside a row, no pre-analysis card | Screen placements + flag | `flutter test test/features/combat_analyzer/presentation/analysis_multipane_evidence_test.dart` → GREEN; `T8.4` post-capture `79%`, `H.6` pre-analysis full card, `H.7` `reanalyze` when `49→79`, `H.8` absent when `79→85`, `H.9` `not recorded` |
| U2+U3+U4+U5 cross | — | No payload/key regression | `flutter test test/features/combat_analyzer` full suite GREEN with no edits to existing expectations; `T4.6` guards `killmailSearchCompleted`/`evidenceAtGeneration` never reach the prompt |
| U6/U7 | — | Journal + closing | `git diff --stat docs/engineering-journal/` shows P1 removed/`ARCHIVE` SHIPPED/`LEARNINGS` four entries; `flutter analyze` clean; `flutter test` full suite GREEN; pasted logs + manual macOS spot-check notes in HANDOFF |

**Highest-risk validation:** `aarevidencescorer` S1→79 and S6 capped 100 — if typed-fraction denominator or `Unavailable`-excluded denominator is off by one, every band and every `+N pts` projection is silently wrong and only these scorer tests (hand-built rows, no mocks) fail. Second-risk: `T4.6` payload allow-list — the snapshot lives in the report, so a regression that serializes it into the prompt is the most damaging silent fault.

## Risks / Rollback

- **Scorer arithmetic drift (U1).** Five `credits` + three `band` cut-offs + `0.7` typed threshold touch every score. *Mitigation:* `AarEvidenceRules` single-source constants + `T1.1–T1.10` + `T1.15` half-up + `A.14` throws on missing dimension; output is deterministic with `T1.8`. Rollback: caller still shows checklist with stale scorer — snapshot's `band` is recomputed on read via `of(score)`, no migration.
- **Forgotten `killmailSearchCompleted` flag (U2/U3).** Legacy rows map to `false` only when `logOnly + uncachedMatchReason`, else `true` — a second case that misses the flag would flip every fresh encounter to `Unavailable` (capped) when it should be `Missing` (actionable). *Mitigation:* `D.5/D.6` legacy inference cases + `T2.13/B.13a/B.13b` boundary trio; flag preserved by `copyWith` in `attachDerivedEvidence`/`importPilotFit`. Rollback: field defaults to `false`; recomputing with a corrected scorer fixes display, no data loss.
- **Prompt-guard breach (U3).** Snapshot or flag serialised into `mimir.combat_aar_input.v4` would change model input without version bump. *Mitigation:* `T4.6` allow-list of top-level keys + deep-equality of `toPromptJson()` across flag values; report output never feeds prompt input. Rollback: remove `derivedFits` guard — not applicable; this milestone adds no prompt keys (C9 audit).
- **Reload flash regressing S3 (U4/U5 C12).** Removing `skipLoadingOnReload: true` would flash the card to its skeleton on every fit attach. *Mitigation:* `F.13` holds prior text during a single `pump()` before settle; reviewer prompt checks `.when` params.
- **`ParsedCombatEncounter` identity pitfall (U3/U5 D8).** Family keyed by identity equality, not `id` — using `copyWith` between override and read would duplicate the provider and show stale state. *Mitigation:* Group E/H tests use the **same `encounter` instance** for override and read; documented in fixtures. Rollback: key by `id` string — heavier but not needed.
- **Own-loss S1 vs S1b confusion (C4/C5).** Loss's destroyed fit is the pilot's, so D1 is `Complete` and D4 is `Unavailable (attacker fittings not exposed)`, not S1's kill-row set. *Mitigation:* split fixtures `s1Inputs` vs `s1bInputs` plus `B.5b/B.16a` cover own-loss; S1 comment cites C5.
- **Raw IDs leakage (U4).** `itemNameProvider` must resolve every ship `typeId` in checklist/stats rows. *Mitigation:* checklist never formats `typeId` directly; screen tests assert `find.textContaining('Item #')` finds nothing when provider is overridden.

## Open Questions

None after local discovery — every question in spec §8 was closed by design §0–§5 contracts and the `main` probed tables at `develop:855ba5b`. Remaining product-confirmation item (`D6` snapshot-button retirement) is carried as a follow-up QUEUED P3 item, not a blocker.

---
*Plan file:* `.agents/plans/2026-09-11-aar-evidence-completeness-score.md` — canonical body is the reply above. Reviewer prompts: verify `Missing ⇔ actionable` (T2.22), `combine` denominator excludes `Unavailable`, `skipLoadingOnReload: true` on the assessment card, `T4.6` prompt-key allow-list, and `killmailSearchCompleted` legacy inference.
