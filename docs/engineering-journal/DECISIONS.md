# Decisions - Mimir

> **Architecture, prompt-design, and process decisions.** When we commit to a
> path over alternatives, capture the rationale, rejected alternatives, and
> revisit conditions.
>
> **Append new entries to the top.** Format:
>
> ```markdown
> ## YYYY-MM-DD
>
> ### Short title (commit hash or pending)
>
> **Author.** {agent-name}
> **Decision.** What we picked.
> **Rejected alternatives.** What we considered and did not pick.
> **Rationale.** Why this won.
> **Revisit when.** Conditions that would change the decision.
> **Refs.** Related files, tests, plans, issues, PRs, LEARNINGS, or QUEUED entries.
> ```
>
> If new evidence invalidates a decision, update it inline and move the
> pre-correction version to `ARCHIVE.md` as SUPERSEDED.

---

## 2026-09-15

### AAR fit comparisons preserve source snapshots and shared calculation assumptions

**Author.** Product.
**Decision.** Adopt the [fit comparison Product specification](../specs/aar-fit-comparison-visuals.md):
independent current/proposal snapshots; immutable generation-fit provenance;
validated optional structured candidates alongside legacy prose; deterministic
module diffs and common-context stats. Separate Changes and Full replacement BOMs,
qualify cached availability/ESI average values, and label sustained repair Not modeled.
**Rejected alternatives.** Reusing the single pilot evidence field for all sources;
reconstructing report history from its evidence score; parsing generic advice into
exact equipment; comparing different skill/damage assumptions; crediting lost fits
as owned stock or presenting partial prices as a total.
**Rationale.** Visual precision must preserve source uncertainty and engine limits.
The existing models need additional source/contract support before these visuals
can support reliable equipment decisions.
**Revisit when.** Sustained-tank calculation, authoritative inventory metadata,
regional market quotes or historical engine/SDE replay become separately supported.
**Refs.** [Queued initiative](QUEUED.md#fit-comparison-visuals-for-aar-reports).
Specification delivery only; implementation and the 46 verification cases remain pending.

### AAR attachment validation and refresh use explicit ownership boundaries

**Author.** Technical Architect.
**Decision.** Adopt the [technical design](../specs/aar-fit-import-capture-ui-tests-design.md):
strict AAR-only manifest validation with opt-in shared-parser lookup/error seams;
atomic, field-owned enrichment mutations; a shared encounter operation coordinator;
and a stable post-commit publisher. Test the real screen, services, derivation and
Drift storage, controlling external ESI/discovery/AI and seeded local SDE inputs.
**Rejected alternatives.** Making the shared tolerant parser globally strict; copying
a fit read at refresh start; private service locks as storage protection; manufactured
scores or successful saves in journey tests; disposing publication with a recreatable service.
**Rationale.** Complete supplied content and the latest committed fit must survive
into analysis. Victim evidence must retain its owning identity, and stale derived
facts cannot be attached to a newer fit. Narrow seams preserve other fitting callers
and prompt v4 without a database migration.
**Revisit when.** Product adds supported import syntax or explicit killmail replacement,
or durable multi-process operation coordination becomes necessary.
**Refs.** [Product contract](../specs/aar-fit-import-capture-ui-tests.md);
[ARCHIVE entry](ARCHIVE.md#shipped-2026-09-15-aar-fit-import-and-capture-ui-tests-and-defect-remediation).
Shipped 2026-09-15 across Units U0–U5 with all 36 test cases passing.

## 2026-09-14

### Fit attachment test contract targets live controls and faithful saved evidence

**Author.** Product.
**Decision.** Adopt the [UI-test product contract](../specs/aar-fit-import-capture-ui-tests.md).
Cover Import Fit and confirmed Use Current Fit through the live screen, and unconfirmed
snapshots through service/legacy fixtures. Require faithful-or-rejected AAR imports,
qualified empty-inventory capture, save-before-success feedback, coherent local refresh,
and retention through explicit re-analysis. Tests and narrow fixes are pending.
**Rejected alternatives.** Restoring a retired snapshot button for coverage; treating
discarded EFT entries as valid empty slots; asserting a fixed score increase; mocking
away persistence and the final analysis input.
**Rationale.** The queued description predates the checklist controls, and source review
found validation and refresh paths that counter-only widget fakes cannot protect.
**Revisit when.** The shared fitting parser supports additional syntax, or Product
introduces a new fit-editing/reference workflow.
**Refs.** [Queued item](QUEUED.md#aar-fit-import-and-capture-ui-tests);
[retention finding](LEARNINGS.md#fit-attachment-mocks-do-not-prove-re-analysis-retains-the-fit).

## 2026-09-15

### Milestone 5 canonical allocation, per-attacker defense matchup, and UI integration (commits: 699df14, 1554125, 19cc519)

**Author.** Antigravity / Lead Orchestrator
**Decision.**
1. **Exact rational allocation & pure deriver:** Plain immutable Dart domain models using `DamageQuantity` reduced BigInt rational components canonicalized from SDE decimal values without floating-point drift. Strict conservation: `C_a + C_X + C_N == C_aggregate` and `sum(C) + U == T`.
2. **Attacker eligibility & partition:** Confirmed and Probable sources receive individual matchup cards; `shipType` actors capped at Probable; Possible matches placed in Unattributed (X) without mutating M4 correlation; NPC actors placed in NPC (N); unobserved killmail participants retained in footer.
3. **Defense derivation & anti-average:** Pilot fit defense snapshot (`AarDerivationBundle.self`) compared against each attacker's incoming profile. Rejects the averaged EHP fallacy.
4. **Local-only composition & additive prompt:** Local SDE and database queries only via `EffectLookupPolicy.localOnly` on fitting loader; single-write concurrency guard on `ensureAttackerCorrelation`. Optional additive `damageMatchups.perAttackerIncoming` in prompt schema v4 without output schema mutation.
5. **Unified UI & report-optional Damage tab:** `AarIncomingMatchupsSection` replaces standalone correlation ranking as the single incoming source ranking; Damage tab available pre-analysis; overview with aggregate reference and positiveSources > 1 blend advisory; 2-column responsive layout >=720px; zero raw EVE IDs.
**Rejected alternatives.** Rounded integer components as calculation inputs; separate aggregate/source resolvers; per-card fitting derivation; persisted live M5 bundles; network fallback during quantitative local views; assigning aggregate blend profiles to named attackers.
**Rationale.** Preserves exact conservation, independent identity and coverage confidence, coherent fit provenance, and historical AI reports.
**Revisit when.** Additional telemetry supports attribution or durable derived-result caching is justified.
**Refs.** [Technical contracts and TDD gates](../specs/aar-per-attacker-matchup-design.md); [Product contract](../specs/aar-per-attacker-matchup.md); [Implementation plan](../../.agents/plans/2026-09-14-aar-per-attacker-matchup.md); ARCHIVE SHIPPED 2026-09-15.

### 2026-09-14

### Attacker correlation architecture, signal weights, participant pool, and UI placement (commit: 3ab988a)

**Author.** Antigravity / Lead Orchestrator
**Decision.**
1. **Replace Incoming Sources breakdown (D5):** Remove the redundant `_BreakdownSection(title: 'Incoming Sources', ...)` in `AnalysisMultiPaneScreen` and replace it with `AarAttackerCorrelationSection(encounter)`. When correlation is null or unperformed, the section falls back to rendering the same plain actor rows with the title `Incoming Sources`.
2. **Names-only Category 11 bundling in SDE (D6):** Bundle EVE SDE Category 11 (Entity) type names without published filtering or dogma attributes (`NAME_ONLY_CATEGORIES = {11}`). Bump `bundledDogmaVersion = 3` (+0.77 MB asset growth). This enables exact local SDE normalization and classification of NPC combat-log actors without introducing network calls or SDE bloat.
3. **Corrected signal weights and confidence thresholds (D7):** Calibrate multi-signal weights to `name: 0.75`, `ship: 0.30`, `weapon: 0.20`, `damage: 0.20`, `timing: 0.15`, `sole: 0.10` with confidence thresholds `Confirmed >= 0.75`, `Probable >= 0.50`, `Possible >= 0.30`, and `ambiguityMargin: 0.10`. Damage ratio tiers award full weight (+0.20) at $\ge 0.60$ and half weight (+0.10) at $\ge 0.35$. Cap shipType actors at `Probable` (never `Confirmed`).
4. **Participant pool includes the victim and excludes the user (D8):** Form the participant pool as `attackers ∪ victim \ {user}`. On a kill, incoming combat-log damage was inflicted by the killmail victim, not the attackers. The victim participant has `damageDone = null` and cannot score on damage.
**Rejected alternatives.**
- Displaying both Incoming Sources and Attacker Correlation on the Damage tab: Rejected because competing lists of the same actors create visual confusion and duplicate rankings.
- Hard-coding regex patterns or heuristics for NPC names: Rejected because EVE's NPC name taxonomy is large and irregular; only local SDE lookup provides sound classification.
- Using 0.60/0.25 printed spec weights: Rejected because name alone would fail to reach Confirmed, ship+damage would fail to reach Probable, and solo kill scenario S1 would fail to reach 0.85.
- Attacker-only participant pool: Rejected because incoming damage on kills would be completely uncorrelatable.
**Rationale.** Establishes an attribution framework grounded in ground-truth combat logs and verified killmails. Enforces strict damage accounting (`correlated + unattributed + npc == totalIncomingDamage`) while preventing fabricated or ungrounded correlations.
**Revisit when.** Per-attacker damage profiles or ESI `inventory_type` fallbacks are introduced.
**Refs.** LEARNINGS 2026-09-14; ARCHIVE SHIPPED 2026-09-14; docs/specs/aar-zkill-attacker-correlation.md; docs/specs/aar-zkill-attacker-correlation-design.md; .agents/plans/2026-09-11-aar-zkill-attacker-correlation.md.

### 2026-09-11

### AAR evidence completeness score, provenance snapshot, and pre-analysis gate (commit: 506a371)

**Author.** Antigravity / Lead Orchestrator
**Decision.**
1. **Non-blocking pre-analysis gate (D1):** `AarPreAnalysisGate` renders an enabled `FilledButton` ("Analyze Encounter with AI") regardless of score (0, 30, 75, or 100). If score is in Low band (< 40), it renders a non-blocking warning sibling widget ("Analysis will contain significant unknowns"); in Partial band (< 75), an advisory message. It never modal-blocks or disables AI analysis.
2. **Evidence snapshot stored on report (D2):** Store `AarEvidenceSnapshot?` directly on `CombatAarReport` (`evidenceAtGeneration`) serialized inside `analysisJson`. This records score, band, capped status, and dimension statuses at time of generation with zero DB schema changes, leaving prompt schema v4 untouched.
3. **Retire old fit button cluster (D3):** Completely remove the legacy `Wrap` of fit buttons (`Snapshot Current Fit`, `Use Current Fit For Fight`, `Import EFT Fit`, `Re-authenticate with ESI`) from `AnalysisMultiPaneScreen`. Replace them with structured action buttons inside the relevant checklist rows (`AarEvidenceChecklistCard`) wired through `AarEvidenceActionHandlers`.
4. **User-initiated pre-analysis killmail search (D5):** Do not automatically execute ESI/zKill network requests when opening an encounter. Present an explicit "Search Killmails" CTA in the checklist when `killmailSearchCompleted` is false.
5. **Retire unconfirmed snapshot button (D6):** Drop the "Snapshot Current Fit" button that created unconfirmed reference fits without binding to the fight. Fits attached to an encounter should be confirmed for that specific fight.
6. **Invariant I1: Missing ⇔ actionable (D7):** A dimension is marked `Missing` (0% credit, in denominator) if and only if an actionable user CTA exists. Unresolvable gaps (e.g. unknown opponent fit on own loss, unsearched killmail when offline) evaluate to `Unavailable` with an explanatory reason string and are excluded from the score denominator ($\text{earned} / \text{available} \times 100$).
**Rejected alternatives.**
- Blocking the analysis button below a score threshold: Rejected because users may intentionally run quick analyses on partial data or offline logs (user autonomy principle).
- Storing evidence snapshot in a new database table or altering prompt schema: Rejected to avoid database migrations and prompt token bloat.
- Auto-searching killmails on encounter open: Rejected to prevent unintended network requests and battery/data drain.
- Marking unfixable gaps as "Missing": Rejected because permanently red checklist rows with no button create learned helplessness.
**Rationale.** Delivers transparent and actionable pre-analysis evidence guidance, ensures user agency with one-click fixes for true gaps, preserves historical analysis provenance, and avoids degrading the core AI analysis flow.
**Revisit when.** Settings are introduced for auto-fetching killmails or manual opponent EFT import is built.
**Refs.** LEARNINGS 2026-09-11; ARCHIVE SHIPPED 2026-09-11; docs/specs/aar-evidence-completeness-score-design.md; .agents/plans/2026-09-11-aar-evidence-completeness-score.md.

### AAR fit simulation, derivation layering, tank classification, and shared loader (commit: 6be5eb7)

**Author.** Antigravity / Lead Orchestrator
**Decision.**
1. **Derivation Layering:** Split derivation into pure domain `CombatFitDeriver` (injected with `DogmaEngine`, synchronous-style async, zero I/O, unit-testable without database) and data layer `CombatFitDerivationService` (resolving SDE types, character skills via ESI cache or cached All V, building `AarDerivationBundle`).
2. **Shared Loader:** Extract `loadFittingStatsInputs` into `lib/features/fitting/data/fitting_stats_inputs.dart` as the single shared loader for both the Fitting screen (`fittingStatsProvider`) and AAR derivation (`CombatFitDerivationService`), guaranteeing identical inputs and 100% parity across both subsystems.
3. **Tank Classification Rule:** Implement deterministic 4-step hierarchy in `TankClassifier`: (a) if active repair/boost HP/s > 0, pick layer with highest rate (ties: larger layer omni EHP, then armor/shield/hull); (b) else if omni EHP gain vs bare-hull baseline > 0.5, pick layer with largest gain (mode: buffer); (c) else pick layer with largest total EHP (mode: unfitted); (d) if zero HP, unknown/unfitted.
4. **Relative Damage Matchup Assessment:** Replace absolute ≤20/≥60 threshold with relative rule against layer mean resist: `resistHole` if resist ≤ 20 or resist ≤ mean − 5; `strongResist` if resist ≥ mean + 5; neutral otherwise. Calculate `appliedPercent` post-resist damage fraction $p_t(1 - r_t)/\sum p_u(1 - r_u)$ and identify `primaryHole`.
5. **Persistence Model:** Persist derived facts and specific unknowns into `CombatEvidenceLedger` (preserving what the LLM analysis saw at analysis time); recompute structured `AarDerivationBundle` live via `aarFitDerivationsProvider` so UI stats reflect current engine math.
6. **Skill Basis Transparency:** Require explicit `AarSkillContext` (`knownCharacter` with derived confidence vs `allFive` with reference confidence strictly lower). Never silently present All V stats without labeling `assumes All V`.
**Rejected alternatives.**
- Single monolithic service with embedded DB queries: Rejected to maintain AC1.5/T1.7 test purity without mocking SQLite.
- Separate SDE loaders in Fitting and Combat Analyzer: Rejected because differing loader rules would violate the "one engine, one answer" requirement.
- Raw-HP or role-based tank heuristic: Rejected because active repair must beat buffer, and buffer investment is accurately measured as gain over bare hull.
- Persisting structured derivation bundle: Rejected to prevent stale serialized state when engine attributes or algorithms evolve.
**Rationale.** Establishes clean architectural boundaries between pure dogma calculations and data resolution, guarantees cross-feature stat parity, and ensures all AAR metrics are mathematically grounded and transparent about skill assumptions.
**Revisit when.** Turret tracking or missile application mechanics are ported to the matchup analyzer.
**Refs.** LEARNINGS 2026-09-11; ARCHIVE SHIPPED 2026-09-11; docs/specs/aar-fit-simulation-and-defense-profiles-design.md; .agents/plans/2026-09-11-aar-fit-simulation-and-defense-profiles.md.


### Published dogma modifier routing for skills and fighters, curated 1851 fallback, and owner-kind stacking penalties (commit: pending)

**Author.** Antigravity / Lead Orchestrator
**Decision.**
1. Bundle category 16 (Skill) and category 87 (Fighter) in `scripts/sde/generate_dogma_sde.py` `TARGET_CATEGORIES`, bumping `SdeService.bundledDogmaVersion = 2` with an `SdeMetadata` table check to trigger an idempotent database reload.
2. Route published skill-owned dogma modifiers through DogmaEngine via `skillEffectAllowlist` (Gunnery 414, Rapid Firing 582, MLO/Rapid Launch 1763, XL specs 6577/6578, DDA 6556, FSU 6566, fighter skills 6560/6563/6570/6663/12844..12848).
3. Provide a single curated fallback table for effect 1851 (six sub-capital missile specialisations: Rockets, Light, Heavy, HAM, Torpedoes, Cruise) matching the published 6577/6578 shape, since CCP publishes effect 1851 with an empty `modifierInfo`.
4. Filter module targets using the six direct required skill attribute slots `{182, 183, 184, 1285, 1289, 1290}`, matching CCP `LocationRequiredSkillModifier` semantics and pyfa `requiresSkill(skill)`.
5. Gate stacking penalties on modifier owner kind: skill and character bonuses are unpenalized; fitted modules, charges, drones, and fighters are penalized.
6. Calculate fighter squadron stats using attribute 2215 for squadron capacity, attribute 2233 normalized from milliseconds for attack ability (6465) duration with damage ability (6431) fallback, and enforce launch tube and class caps (light/support/heavy) in declaration order. Over-capacity bay volume is displayed in error styling without truncating DPS.
**Rejected alternatives.**
- Transitive required-skill tree closure: Rejected because all 780 weapons directly list Gunnery or MLO in one of their six required skill slots (zero transitive-only).
- Hardcoding skill cycle bonuses in Dart tables: Rejected because CCP's published SDE already contains resolved modifiers on skill types.
- Excluding carrier fighter skills / hull bonuses: Rejected because routing them through the standard `charID` path applies naturally and gives exact pyfa parity.
- `FittingError` exception on bay overflow: Rejected to match CPU/PG pattern (report used/max, style in `EveColors.error`).
**Rationale.** Leverages published SDE dogma modifiers as the single source of truth, minimizing bespoke Dart logic while achieving 100% pyfa parity for cycle times, fighter DPS, and carrier hull/module bonuses.
**Revisit when.** CCP publishes `dgmAttributeTypes.csv` `stackable` attribute bundled in Mimir, or when missile/drone damage specialisation effects (660–668, 1730) are curated.
**Refs.** LEARNINGS 2026-09-11; ARCHIVE SHIPPED 2026-09-11; `docs/specs/fitting-completion-skill-rof-and-fighters-design.md`; `.agents/plans/2026-09-11-fitting-completion-skill-rof-and-fighters.md`.


### 2026-09-08

### Bundled resolved modifiers are the modifier source of truth; offense rows at pyfa parity (commit: pending)

**Author.** Qwen Code
**Decision.** `assets/sde/effect_modifiers.json` (generated from the SDE's
`dgmEffects.modifierInfo`) loads on every launch and answers
`ensureEffectModifiers` first; Drift cache and public ESI remain fallbacks for
effects the bundle does not cover. DogmaEngine routes modifiers by func and
domain (ship / fitted modules / loaded charges) and computes turret and
missile DPS, volley, optimal and falloff pyfa-style: turret volley = charge
damage components (114/116/117/118) times damage modifier 64, cycle from
rate-of-fire 51, launchers contribute charge damage alone, ranges
volley-weighted across turrets.
**Rejected alternatives.** Porting a dogma expression-tree evaluator (the
expression table is retired; resolved modifiers supersede it); keeping ESI as
primary source (network-dependent, and the same data ships in the SDE);
showing estimated DPS for unloaded weapons (would fabricate numbers).
**Rationale.** CCP's resolved modifiers include skill linkage and group
restrictions, making racial bonuses correct by construction and offline;
unloaded weapons contributing zero matches an unloaded gun in game.
**Revisit when.** Drone DPS is needed (drone-domain bonuses are a separate
routing case), or operators beyond postPercent/postMul (e.g. missile
specialisation's preMul) matter for a row we display.
**Update 2026-09-08 (same day).** Drone DPS shipped: charID modifiers also
reach fitted drones; drone damage amps apply raw, filtered by the target's
required skill, while ship-owned racial bonuses scale with the ship's
required skill (modifierInfo's skillTypeID is a filter, per pyfa). Operator 4
joined 0 as postMul (damage-module family), and BCS-style charID modifiers on
212 multiply loaded missile damage components. See LEARNINGS 2026-09-08
skill-filter entry.
**Refs.** LEARNINGS 2026-09-08 modifierInfo and dead-effects entries;
QUEUED drone DPS and unsupported-operator entries.

### Fitting tank math is data-driven from cached ESI modifiers (commit: pending)

**Author.** Qwen Code
**Decision.** New `SdeEffectModifiers` Drift table (SDE schema v6) plus
`SdeService.ensureEffectModifiers`, which fetches missing effect modifiers
from public ESI and tolerates failure; DogmaEngine applies operator 6 as
postPercent (stacking-penalised on resonances) and operator 0 as postMul.
**Rejected alternatives.** Hardcoded per-module bonus constants (breaks on
every balance change, and our first guess was wrong by two orders of
magnitude); a full expression-tree engine (ESI publishes expression IDs only).
**Rationale.** CCP's published modifiers make hardener and Damage Control
math correct by construction and cacheable for offline use.
**Revisit when.** ESI publishes effect expressions, or Mimir bundles the full
SDE dogma expression tables.
**Update 2026-09-08.** Superseded as primary source: Mimir now bundles the
SDE's resolved modifiers (`effect_modifiers.json`); ESI is fallback only.
See DECISIONS 2026-09-08 bundled-modifiers entry above.
**Refs.** LEARNINGS 2026-09-07 operator-semantics entry.

### Phase 6 writes: fittings and autopilot, behind confirmation (commit: pending)

**Author.** Qwen Code
**Decision.** Add `esi-fittings.write_fittings.v1` and
`esi-ui.write_waypoint.v1` (EveConfig.phase6WriteScopes). Every game-affecting
call goes through `confirmAction`, and a 403 response is surfaced as
"re-authorize Mimir" because tokens issued before the scope addition lack it.
**Rejected alternatives.** Skill-queue push (verified impossible, LEARNINGS
2026-09-07); performing writes without confirmation.
**Rationale.** The user chose these two after learning the skill queue cannot
be written. Confirmation matters because these calls change a running game
client or the character's in-game fitting list.
**Revisit when.** CCP adds a skill-queue write endpoint to ESI, or users ask
for mail/contacts/fleet writes (all present in the spec).
**Refs.** lib/core/widgets/confirm_action_dialog.dart;
lib/features/fitting/domain/esi_fitting_export.dart.

## 2026-09-07

### Fabricated intel data is deleted, not gated (59f031b, d903ff9)

**Author.** Qwen Code
**Decision.** Remove MapperSyncCard, PathfinderClient and DiscordRpcService
outright; record the real-integration intent in QUEUED.md instead.
**Rejected alternatives.** Gating the mock behind a dev flag; keeping the card
with an honest "not connected" state.
**Rationale.** In an intel tool a confidently false "Connected to Pathfinder"
badge is worse than no card. A permanently disabled card is clutter, and a flag
invites the mock back into production builds.
**Revisit when.** A maintained public wormhole-mapper API with a understood auth
model exists (QUEUED.md P2 entry).
**Refs.** 59f031b; QUEUED.md "Real wormhole-mapper integration".

### SDE updates replace only the skill slice (e6c7837)

**Author.** Qwen Code
**Decision.** `SdeDatabase.deleteSkillSlice` (skill types by group plus their
prerequisites) runs inside the update transaction; `clearAll()` is gone from the
update path, and `sdeServiceProvider` is invalidated on apply.
**Rejected alternatives.** clearAll + re-import; keeping clearAll and refetching
dogma/industry from somewhere (no source exists in the payload).
**Rationale.** The update payload carries skills only. Wiping the dogma and
industry tables it cannot restore left Ship Fitting at zeros and Industry
lookups empty until restart.
**Revisit when.** Update payloads start carrying dogma/industry data.
**Refs.** e6c7837; test/core/sde/sde_database_skill_slice_test.dart.

### Dead inferior UI is deleted; dead valuable UI is wired (34b0f4c, 8e99f4f)

**Author.** Qwen Code
**Decision.** Wire OverviewTab into the Characters window as an Overview tab;
delete PriceCheckerPanel.
**Rejected alternatives.** Wiring both; deleting both.
**Rationale.** OverviewTab carries information nowhere else in the app (current
ship, location, online status, clone summary). PriceCheckerPanel's only unique
behaviour was asking for a raw numeric Type ID — the anti-pattern the project
rule forbids — duplicating what MarketBrowserPanel already does by name.
**Revisit when.** Price checking needs a flow the Browser cannot express.
**Refs.** 8e99f4f; 34b0f4c.

### Saved fittings resolve the character with a one-shot read (959808b)

**Author.** Qwen Code
**Decision.** `FittingController.saveCurrent` calls
`characterRepository.getActiveCharacter()`; the dialog streams
`savedFittingsProvider(characterId)`, which includes character-null shared fits.
**Rejected alternatives.** Awaiting `activeCharacterProvider.future` in the
write path.
**Rationale.** A write must not hold a stream subscription, and that stream
never settles outside a widget tree (LEARNINGS 2026-09-07).
**Revisit when.** Cross-character fit sharing grows a UI of its own.
**Refs.** 959808b.

## 2026-05-21

### Combat analysis is explicit and cache-first; list loading must not call AI (commit: pending)

**Author.** Codex
**Decision.** Opening Combat Analyzer or loading the encounter list must only
scan and parse local logs. AI analysis happens only when the user clicks the
analyze/re-analyze action, and cached AARs are displayed without resending the
encounter.

**Rejected alternatives.**
- Auto-analyze every discovered encounter. This risks surprise token use,
  privacy leakage, long startup times, and repeated AI calls over historical
  logs.
- Re-analyze whenever a parsed encounter is opened. This makes cached reports
  meaningless and hides cost/latency behind navigation.

**Rationale.** Combat logs can contain a large history. The correct user model
is browse locally first, then choose which fight deserves AI time. Cache state
also lets the UI mark which encounters already have AARs.

**Revisit when.** Only if Mimir adds a clearly labeled batch-analysis workflow
with limits, progress, cancellation, and an explicit cost/privacy confirmation.

**Refs.** `.codex/plans/2026-05-20-combat-analyzer-recovery.md`;
`.codex/plans/2026-05-21-combat-analyzer-aar.md`.

### AI auth is Mimir-owned app auth, not Codex CLI mutation (commit: pending)

**Author.** Codex
**Decision.** Mimir owns its own `auth.json` for AI/Codex login, following the
Hermes-style provider shape, refresh logic, owner-only file permissions, and
Codex-specific device flow. Codex CLI credentials may be imported only as an
optional migration path.

**Rejected alternatives.**
- Write directly to `~/.codex/auth.json`. This risks refresh-token rotation
conflicts with the CLI and makes app behavior depend on another tool's store.
- Store Codex access tokens as a generic `llmApiKey`. That conflates ChatGPT
device OAuth with normal OpenAI API keys and breaks refresh semantics.
- Use normal `/v1/chat/completions` request shape for Codex. That produced
HTTP 400s and does not match the backend contract used by Codex/Hermes.

**Rationale.** App-owned credentials make lifecycle, permissions, and refresh
behavior auditable. The Codex backend needs Codex-specific headers and streamed
Responses handling, so it should be modeled as a distinct AI provider path.

**Revisit when.** OpenAI publishes a stable app-OAuth API or Codex backend
contract for third-party clients. Keep direct OpenAI API-key support separate
from ChatGPT/Codex device OAuth.

**Refs.** `.codex/plans/2026-05-20-combat-analyzer-recovery.md`;
`test/features/combat_analyzer/codex_auth_service_test.dart`.

### Combat AAR v3 uses evidence ledger and fit evidence before deeper simulation (commit: pending)

**Author.** Codex
**Decision.** The combat analyzer AAR contract now sends an explicit evidence
ledger plus pilot/victim fit evidence to the AI. The report version moved to
v3, and the UI exposes fit import/current-fit snapshot actions before
re-analysis.

**Rejected alternatives.**
- Keep pushing all unknown-resolution into prompt prose. That would make the
  model guess about missing fit/range/tank facts and would be hard to audit.
- Jump straight to pyfa-grade fit simulation before the evidence model exists.
  That would create a larger implementation with weak provenance and no clear
  way to distinguish confirmed, reference, and inferred inputs.
- Treat current ship snapshot as proven fight-time fit. That is incorrect
  unless the user confirms the snapshot represents the fight.

**Rationale.** Evidence provenance is the base layer. Once every fact has a
source and confidence, later SDE/dogma simulation can enrich the AAR without
erasing the difference between combat-log proof, killmail proof, user-confirmed
fit, and inference.

**Revisit when.** If Mimir gains reliable historical fitting data or a full
dogma simulation engine, add deterministic derived facts to the ledger but keep
the provenance model. Do not collapse back to unstructured prompt-only evidence.

**Refs.** `lib/features/combat_analyzer/domain/combat_evidence_ledger.dart`;
`lib/features/combat_analyzer/data/codex_analysis_client.dart`;
`test/features/combat_analyzer/domain/combat_evidence_ledger_test.dart`;
[LEARNINGS 2026-05-21](LEARNINGS.md#combat-logs-are-a-primary-source-but-not-a-complete-aar-evidence-source);
[QUEUED AAR fit simulation](QUEUED.md#p1--aar-fit-simulation-and-defense-profile-derivation).
