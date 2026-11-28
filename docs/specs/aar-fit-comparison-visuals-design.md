# AAR Fit Comparison Visuals — Technical Architecture and Design

**Status:** Architecture complete; implementation and runtime verification pending.
**Date:** 2026-09-15.
**Author:** Technical Architect.
**Grounding:** `develop` at `2fe995c`, containing the
[Product specification](aar-fit-comparison-visuals.md), after attachment hardening shipped.
**Delivery:** Models, persistence and calculation contracts, read-only UI seams, and
TDD ownership covering Product AC1–AC30, S1–S6 and all 46 D/P/U cases.

## 1. Executive summary and governing decisions

Build a read-only comparison workspace over **preserved source inputs**, not four
instances of the mutable fitting editor. Store current comparison capture and the
user's copied proposal separately from `pilotFitEvidence`; preserve the actual fit
inputs on each new report. Derive every visible column under one explicit context,
then calculate objective inventory differences and qualified material estimates.

This release includes the contracts needed to make the visuals truthful. It is not
only widget composition. Source inspection found that existing derivations embed
evidence provenance, reports retain scores rather than inventories, and the asset
cache cannot establish fresh ownership. Those boundaries are addressed below.

### 1.1 Architecture invariants

| Invariant | Contract |
| --- | --- |
| Evidence isolation | Comparison capture/import/selection never changes pilot/victim evidence, ledger facts, completeness scoring, attribution or the active editor. Never call `captureCurrentPilotFit(confirmed: false)` to save a comparison. |
| Historical truth | New report snapshots are copied from the actual prepared input before AI dispatch. Later attachment and visual recalculation cannot rewrite them. Legacy reports explicitly lack this history. |
| Source identity | Victim inventory, subject identity and selected killmail stay together. Unknown victim identity is not the pilot by elimination. A reference/proposal never becomes confirmed historical evidence. |
| Exact inventory | Duplicate matching and quantities are deterministic; unknown entries remain occupied/unknown. Physical slot identity is different from EFT's compact ordering. |
| Neutral calculation | Reuse the Dogma/input pipeline without creating fake `FitEvidence` for proposals or writing comparison calculations to the evidence ledger. |
| Common assumptions | All columns use one frozen skill context, normalized damage profile and local SDE/calculator revision. No old values beneath a new source/context header. |
| Qualified materials | Changes and Full replacement are separate calculations. Unknown counts/prices/cache eligibility are not zero. Lost equipment and removals are not ownership or guaranteed resale. |
| Local view | Reading stored fits, diffing, deriving and reading price/asset caches make no AI, asset/order sync or killmail-discovery requests. Optional name/icon fetching cannot gate comparison. |
| Commit semantics | Publish success only after committed storage. Field-scoped preconditions reject stale same-field results; independent fields preserve one another. |
| Compatibility | Report v3 and input `mimir.combat_aar_input.v4` remain; new fields are optional and independently versioned. Unknown candidate versions do not discard narrative. |

Keep existing [M5](aar-per-attacker-matchup-design.md) and
[attachment](aar-fit-import-capture-ui-tests-design.md) contracts for their shipped
behavior. Do not change correlation confidence, per-attacker/unattributed/NPC
conservation, score weights, nonblocking analysis, or the evidence import dialog's
close-before-parse policy. This initiative adds a different proposal dialog.

**Upgrade terminology:** Product §4.3 governs the requested difference representation.
Objective kinds are Added, Removed, Modified and Unchanged. An optional proposal
annotation can say its intent is an upgrade, with rationale; it does not create an
automatic `upgraded` outcome based on price, meta level or a larger statistic.

### 1.2 Grounded seams and required additions

| Existing seam | Reuse and specific addition |
| --- | --- |
| `AnalysisMultiPaneScreen` | Reuse encounter/generation guards, evidence actions and report Fits navigation. Add a parameterized workspace and a full-width pre-analysis entry; current prompt is constrained to 720px. |
| `CombatEnrichment` | Add an owned comparison state field and explicit evidence-presence semantics for a comparison-only row. Extend every constructor/copy/serializer/refresh path. |
| `CombatEnrichmentRepository.mutateEnrichment` | Reuse atomic load/precondition/transform/save and `written/unchanged/preconditionFailed`; add external-change observation and bounded lock retry, not a private service lock. |
| `CombatEnrichmentService` | Preserve comparison fields in evidence writes; share capture reads without sharing evidence persistence. Its commit callback exists but is not wired by the production provider at this baseline. |
| `CombatAnalysisService` | Existing wait-for-attachment and three-attempt stale-input preparation remain. Return exact selected fit inputs with derivation and freeze a generation record before AI. |
| `CombatAarReport` / `CodexAnalysisClient` | Add optional generation record and versioned candidates; raw candidate failures are scoped, not whole-report repair failures. |
| `AarFitImportParser` | Reuse strict parsing; expose its source manifest/knowledge alongside the fitting without changing existing `parse` behavior. |
| `FittingRepository` | Add read-only reference records retaining ownership/timestamps, which current fitting-only results discard. |
| `CombatFitDeriver`, `DogmaEngine`, `FittingStatsInputs` | Extract neutral computation and diagnostic availability. Keep compatibility wrappers and one set of simulation formulas. |
| Market/asset repositories | Batch cached prices; price-only explicit refresh; encounter-scoped cached assets with conservative location and overlap eligibility. |

Source references: [screen](../../lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart),
[enrichment](../../lib/features/combat_analyzer/domain/combat_enrichment.dart),
[repository](../../lib/features/combat_analyzer/data/combat_enrichment_repository.dart),
[service](../../lib/features/combat_analyzer/data/combat_enrichment_service.dart),
[analysis](../../lib/features/combat_analyzer/data/combat_analysis_service.dart),
[report](../../lib/features/combat_analyzer/domain/combat_aar_report.dart),
[client](../../lib/features/combat_analyzer/data/codex_analysis_client.dart).

## 2. Immutable domain contracts

Use Freezed for serialized snapshot/candidate values, following
[`Fitting`](../../lib/features/fitting/domain/models.dart); plain immutable records
are sufficient for derived rows and operation results. Explicitly deep-copy lists,
maps and nested items at snapshot construction. Freezed's unmodifiable getters alone
do not prevent mutation through a caller's original list reference.

Suggested files under `lib/features/combat_analyzer/domain/`:

- `aar_fit_snapshot.dart`: inventories, source provenance and completeness.
- `aar_fit_comparison.dart`: source selection, context, metrics and deltas.
- `aar_fit_proposal.dart`: raw/validated candidate envelopes and origin bindings.
- `aar_fit_inventory_diff.dart`: pure matching and explanation rows.
- `aar_fit_bom.dart`: pure physical requirements, price and asset annotations.

### 2.1 Snapshot envelope

`AarFitSnapshot` is new; the existing `aarFitSnapshotProvider` returns a derivation
bundle, not this model. Avoid renaming that shipped provider during this initiative.

| Field | Contract |
| --- | --- |
| `schemaVersion` | 1 for this envelope. Unknown versions are unsupported source content, not empty fits. |
| `snapshotId` | Unique immutable client ID for persisted captures/copies; deterministic source-qualified ID for a read-only legacy evidence projection. |
| `encounterId` | Required parsed encounter association, validated at every write. |
| `contentFingerprint` | Versioned SHA-256 of canonical semantic content described below. Client computed, never accepted from generated claims. |
| `fitting` | Full deep-copied `Fitting`: all five slot groups, drones, fighters, cargo, states and charge identities. |
| `source` | Typed `AarFitSource`: evidence attachment, comparison capture, killmail victim, saved reference, imported proposal or AI proposal. |
| `subject` | Known character ID or explicit unknown, plus relation pilot/victim/reference. User references can name an intended pilot without claiming historical use. |
| `sourceRef` | Typed attachment/report-generation/killmail/saved-fit reference. Saved ownership is character-owned or shared, not guessed from current selection. |
| `confidence` | Client-owned evidence confidence where applicable; otherwise explicit reference/proposal status. AI rationale confidence is separate. |
| `recordedAt` / `evidenceAt` | Time the snapshot was captured/imported/copied versus known source evidence time. Both UTC; unknown evidence time remains null. |
| `knowledge` | Per-group completeness/applicability, slot-position meaning, unresolved occupants, state/deployment assumptions and charge knowledge. |
| `sourceItemIds` | Optional instance IDs from a current capture, for containment/overlap checks only; never user-facing labels. Historical/manual sources usually lack them. |
| `limitations` | Stable codes plus human-readable details; no inferred timestamps, completeness or ownership. |

`sourceRef` preserves a selected victim packet's killmail ID, victim identity and
evidence time together. It is not a link to mutable fields that may later change.
The full inventory and source metadata needed to render a report are embedded in its
generation record, so old reports do not depend on the live enrichment row.

### 2.2 Inventory knowledge is independent of the fitting lists

Define these independent dimensions:

```dart
enum FitInventoryGroup { high, mid, low, rigs, subsystems, drones, fighters, cargo }
enum InventoryCompleteness { recordedComplete, partial, unknown }
enum GroupApplicability { applicable, notApplicable, unknown }
enum SlotPositionMeaning { recorded, orderOnly }
enum ChargeKnowledge { recordedAbsent, recordedIdentity, unknown }
enum StateKnowledge { recorded, assumed }
```

`FitGroupKnowledge` holds completeness, applicability, positions, any explicitly
recorded empty slots, and unresolved occupied entries. Each occupant has a stable
source-entry key, any known type ID, quantity or quantity-unknown marker, original
group/physical index when known, and a safe stored label. Do not synthesize type ID 0
as a real item or merge two unknown labels as identical equipment.

Charge knowledge is per module occurrence. A recorded type with unknown round count
is distinct from no recorded charge and from proven absence. Current `FittedModule`
has no charge quantity; this release preserves that fact in the sidecar. A future
known-quantity extension must explicitly distinguish loaded units from cargo units.

| Source | Initial knowledge policy |
| --- | --- |
| New complete ESI capture | Record the successfully fetched ship-inventory scope after all pages. Physical indices are recorded. Module activation/history remains assumed; unknown flags or ambiguous nested contents make affected groups partial. |
| Existing/manual `FitEvidence` | Use new optional `inventoryKnowledge` metadata when present; absent legacy metadata stays unknown. No retroactive completeness from an empty list or source name. |
| Strict EFT/DNA import | The parser manifest proves supplied entries survived; explicit empty markers prove stated absence. Positions remain order-only. Omitted groups remain unknown unless the source manifest actually declares completeness. |
| Saved fit | Copy known saved metadata; legacy fitting JSON's defaulted empty lists do not prove completeness. A valid reference may remain partial. |
| Killmail victim | Preserve raw item-key presence and recorded slots; absent/legacy defaulted items are unknown. Recognized supplied entries can be shown without claiming full historical inventory/state. |
| Structured candidate | Validate group presence/status before `Fitting.fromJson`. Explicit empty group is complete; N/A requires trusted hull metadata; omitted required group is incomplete/invalid for a complete candidate. |

Add optional `FitEvidence.inventoryKnowledge` for future evidence captures/imports
and preserve it through existing serializers. Do not alter confidence or scoring
because it was added. Legacy evidence remains readable without rewriting its JSON.
The proposal workflow does not add a new mandatory confirmation just to mark unknown
groups complete. An entirely specified synthetic fixture can declare completeness
explicitly; this is why Product F1/F2 can have exact full-inventory oracles.

Implement raw-source adapters before information is lost: `adaptCurrentCapture`
receives the complete ship/assets response, `adaptVictimPacket` receives raw killmail
item-key presence and nested items, and strict/saved adapters receive raw group
presence or their validated manifest. The current mappers drop unknown flags or place
them in cargo and choose the first nested charge. Their output alone cannot establish
knowledge. Add detailed mapping results with compatibility wrappers for existing
evidence callers. Comparison results retain unmapped occupants as snapshot-level
`unplacedEntries`; do not invent their group. Ambiguous nested charge choices remain
charge-unknown, with no arbitrary first child sent to simulation. Include unplaced
entries in fingerprints/coverage; count a known physical item once in BOM only if its
identity, quantity and non-duplication are established, otherwise keep it unquantified.

**Not applicable** requires positive hull capability evidence, not a missing or zero
default. In particular, `AarFitCoverage.subsystemSlots` is currently hardcoded zero;
it is not an applicability source. Keep observed subsystem entries visible.

### 2.3 Fingerprints and source identity

Canonicalize objects by fixed field/key order and enums by stable wire names. Sort
unordered inventory records by type/configuration tuple and preserve multiplicity;
use actual physical indices only when positions are recorded. Ignore compact EFT
list indices for equipment equivalence. Do not merge deployment groups whose separate
configuration changes engine behavior.

The semantic fingerprint includes hull, subject, all explicit quantities, charge
identity/knowledge, module state/knowledge, deployment tuples and inventory knowledge,
including unresolved occupants and recorded physical positions. It excludes snapshot
UUID, fitting display name, resolved names/icons, display timestamps, locale and
market/asset observations. Source identity is retained separately even when two
content fingerprints match. A name-resolution recovery cannot produce a fit change.

Keep two cache keys where useful:

- `contentFingerprint`: full source semantics for origin/staleness/coverage.
- `calculationFingerprint`: canonical equipment/configuration plus relevant knowledge
  consumed by computation; includes any supported attribute overrides actually read
  by the engine. Generated attribute/stat bags are never such overrides.

Version the canonicalizer, test JSON round trips and permutations, and compare full
keys rather than human names. A metadata-only source change can refresh provenance
without pretending that physical modules were purchased.

### 2.4 Selection and baseline contracts

`AarComparisonSources` exposes role-qualified entries, including the report generation
source, currently attached fit, current capture, victim and each alternative proposal.
Deduplicate aliases only when they refer to the **same snapshot/source**, such as an
own-loss victim also supplying the baseline. Equal loadouts from different sources
remain selectable.

Default selection order:

1. Report's recorded self baseline, with its true evidence/reference label.
2. Before analysis or for legacy history: attached historical pilot evidence, then
   identified own-loss victim evidence. Show the legacy generation notice where needed.
3. If no historical baseline exists, retain available inventories and request explicit
   selection. A reference fit remains available as Pilot reference fit, not an inferred
   historical fallback.

`AarComparisonSelection` contains baseline source ID, visible comparison IDs, selected
proposal ID, BOM mode, skill/profile choice, expanded groups and diff filter. Keep
it encounter-scoped in memory, stable through refresh/resizing; resolve IDs against
the newly loaded source set. If a selected source disappears, disclose that change
and require/reapply the documented fallback, never silently relabel another source.
Durable snapshots survive reopen; this release does not require a preference/history
browser. Selecting an existing source is not a snapshot write.

If reference evidence was actually supplied as the report's self fit, label it
**Reference used for this report**. The record still has no confirmed fight fit.
Expose Currently attached fight fit separately when its content differs. Unknown
victim identity cannot satisfy the own-loss fallback.

## 3. Persistence, field ownership and generation binding

### 3.1 Storage decision: separate owned JSON fields, no new table

Add optional `CombatEnrichment.fitComparison` with schema 1:

```json
{
  "schemaVersion": 1,
  "currentSnapshot": null,
  "userProposal": null
}
```

Values are full snapshot/proposal envelopes when present. Keep one latest current
capture and one user-selected saved/imported proposal per encounter; AI alternatives
belong to the report that generated them. No automatic union or unbounded capture
history. A new current capture replaces only `currentSnapshot`; copying/importing a
user reference replaces only `userProposal` after successful validation and commit.

This is separate storage from `pilotFitEvidence`, not a new evidence role. It uses
the existing `normalized_evidence_json` column and needs no Drift migration. Explicit
copy-with-clear flags/sentinels distinguish omitted update from setting a new optional
field to null; existing null-coalescing `copyWith` cannot clear fields by itself.

Extend `CombatEnrichment` constructor, `fromJson`, `toJson`, `copyWith`, service `_copy`,
both `_mergeRefresh` branches, victim-retention construction, and every evidence
mutation to retain the latest comparison state. Never spread comparison state into
`toPromptJson`, `derivationInputKey` or the evidence ledger. The explicit report-input
extension in §4 is the only new generation contract.

Unknown comparison schema versions retain their bounded raw payload when rewriting
unrelated evidence, but expose an unsupported source state. Malformed payloads must
not be treated as an absent slot that a stale operation can overwrite. Preserve the
readable evidence/report and require an explicit supported replacement or retry.

### 3.2 Comparison-only rows must not create evidence

Creating a neutral enrichment row when none existed is observably different today:
the scorer distinguishes null/no-character from a log-only row. Therefore add optional
`evidencePacketPresent`, absent in legacy JSON meaning true. A newly created row whose
only content is comparison data sets it false and has no manufactured baseline ledger,
search completion or fit evidence.

The raw repository/comparison reader sees the row. The service's public evidence
projection returns null when `evidencePacketPresent == false`, so existing score,
checklist and prompt consumers see exactly the prior absence of evidence. Discovery
cache-hit logic requires a real evidence packet; a comparison-only row must not prevent
an explicit search/analysis. A later real evidence mutation creates its normal evidence
packet, sets the flag true and retains comparison fields from the transaction's latest
row. Legacy rows and existing constructors default to true.

For that false→true transition, treat the evidence projection as null: build the
ordinary `_emptyEnrichment`/baseline ledger packet appropriate to the evidence action,
then graft in the latest comparison state. Merely flipping the flag on the raw row
would omit the normal evidence initialization.

Test first-ever proposal save on a no-character encounter with no enrichment row:
all evidence dimension statuses/actions/denominator and ledger remain identical. This
projection is an isolation adapter, not a scoring-rule change. Invalid combinations
(false plus actual evidence) fail validation or preserve the actual evidence rather
than silently hiding it.

### 3.3 Field-scoped compare-and-swap

Use the existing `mutateEnrichment(encounterId, transform, precondition: ...)`.
Before asynchronous capture/import, read the expected snapshot ID for the **owned
slot**, or an explicit absent token. After all external/parsing work succeeds:

1. Start the short repository transaction and load its latest raw row.
2. Compare only the expected current-snapshot ID for capture, or user-proposal ID
   for proposal save. Do not compare the entire enrichment JSON.
3. Transform the latest row by changing that field alone and preserving all evidence,
   other comparison fields and unknown supported payloads.
4. Return the committed value/status. Publish only `written`; do not show success on
   `preconditionFailed` or database error.

Snapshot IDs are unique per committed replacement, preventing an ABA fit-content cycle
from passing an old expectation. Concurrent same-field writers are first-successful-
commit-wins, not global latest-click order. Return typed conflict with retry feedback;
never silently retry a failed precondition using a new expectation. Independent current,
proposal and evidence operations can all commit without invalidating each other's slot.

SQLite is shared across independent window connections. On retryable busy/locked
errors, retry the entire short transaction at most three times with bounded backoff,
retaining the original slot expectation. Do not replay an old serialized object, wait
on HTTP/completers inside SQL, or claim a service-local lock is cross-window protection.

Use a comparison operation coordinator keyed by `(encounterId, current|userProposal)`
for synchronous busy reservation and duplicate coalescing. It is independent of the
evidence attachment barrier: comparison writes do not become analysis evidence waits.
Settlement completes pending work after disposal without notifying disposed listeners.
Repository preconditions, not that coordinator, supply storage correctness.

### 3.4 Publication and multiple windows

Wire a stable application-scope commit publisher into production services. The
existing optional callback is not currently injected by `combatEnrichmentServiceProvider`;
implement that wiring, do not assume the previous design made it present. Publication
survives service recreation; only publisher-scope disposal suppresses notifications.
A publication error cannot relabel an already committed save as a failed save.

Add repository observation for visible encounter consumers:

- Read initial rows and respond immediately to local committed-row events.
- While visible, poll `PRAGMA data_version` on the same SQLite connection about once
  per second, and check on application resume. Compare a connection's token only with
  its own prior token. Reload selected rows when an external commit changes it.
- Emit only changed row content. Stop polling/subscriptions when no consumers remain.
  Drift invalidation alone is insufficient because windows open independent background
  connections; local writes still need the local publisher.
- Apply equivalent local/external revision observation to SDE and cached inputs needed
  by an active comparison. Polling is local I/O, never an implicit network refresh.

Close bootstrap/reload races: subscribe to local commits before loading, bracket the
initial and subsequent reads with same-connection `data_version` checks, and retry/
coalesce if an external commit intervenes. Serialize or generation-key reloads so an
older delayed read cannot publish after a newer result. These guards also apply to
SDE/cache observation, not only to the calculation frame.

Keep raw-row observation separate from the evidence projection. Downstream evidence
consumers use a canonical evidence-content key excluding comparison fields and
presence bookkeeping, not `CombatEnrichment`'s current identity equality. Comparison
commits signal the raw-row observer; do not unconditionally invalidate the public
evidence provider. Null→null emits no evidence event, so a comparison-only change does
not produce new evidence facts or spuriously restart analysis preparation. Test two real connections
to one temporary SQLite file, not only two repositories over one memory connection.

### 3.5 New report generation record

Add optional `CombatAarReport.fitComparisonAtGeneration`, schema 1:

- Client `generationId`, encounter ID and prepared-at time.
- Deep-copied supplied pilot/victim snapshots, including references and incomplete
  inputs that were actually sent; absent fits stay absent.
- `selfBaselineSnapshotId` and explicit selection reason; exact actual self/opponent
  derivation input references, not an inference from hull name or evidence score.
- Declared calculation record: actual self/opponent skill maps/bases used by the
  ordinary AAR flow, incoming/outgoing profiles, local input fingerprints and calculator
  revision. These historical contexts need not equal the workspace's common context.

Extend fit derivation with a result carrying the selected source inputs beside its
existing bundle. The existing public bundle-returning method can delegate for
compatibility. Record successful fallback selection explicitly: a failed pilot
derivation followed by own-victim derivation must point to the victim input, not to
the first non-null field. If no self derivation succeeds, preserve supplied sources
and label the chosen supplied baseline's stats unavailable; do not invent a result.

After the existing stale-input commit guard succeeds, construct one immutable
`PreparedAarComparisonInput`. Use it for the outgoing prompt, candidate origin checks
and the persisted generation record. Do this **before** the AI await. On response,
attach the client record to the new report; never reread the latest attachment to
populate it. A later F-new can remain attached while the report correctly binds F-old.

Keep the old report until a new report successfully saves. AI/candidate/stat failures
must not delete prior history. If the application retains an older report elsewhere,
its embedded record is self-contained. No new report-history browser or historical
engine/SDE replay is added.

Stale advice compares current attached-pilot fingerprint/presence with the generation
record's **supplied pilot attachment** fingerprint/presence, independently of numerical
evidence score. This is not necessarily the selected derivation baseline: pilot
derivation can fail and fall back to own-victim evidence without an attachment change.
Null→null remains fresh; null→new attachment or changed content marks advice stale.
Keep this check separate from candidate-origin versus selected-baseline warnings.
Preserve old prose, show origin
information and offer existing explicit Re-analyze. A mere name-resolution update
does not mark equipment stale. Visual stat recalculation is labeled current comparison
context and never presented as recovered historical numerical results.

## 4. Proposals, structured AI and source acquisition

### 4.1 Proposal representation and validation states

`AarFitProposal` contains schema version, client proposal ID, origin (`ai`, `savedReference`,
`importedReference`), target snapshot, original baseline snapshot ID/fingerprint,
client encounter/generation association, rationale, separate rationale confidence,
limitations, optional validated replacement annotations, and validation status.
The validated target is nullable for invalid/unsupported content; keep bounded raw
candidate diagnostics and safely readable entries separately, never synthesize an
empty successful `Fitting`. Record validator revision and SDE key beside cached status.

Use statuses `validated`, `partial`, `invalid`, `unsupportedVersion`, and
`localDataUnavailable`. Known fitting-budget violations are separate constraint
warnings, not structural invalidity. Invalid/unsupported AI candidates preserve
readable advice and any safely inspectable resolved entries, but cannot claim a
complete target, complete BOM or confident improvement. Failed strict user imports
do not save a partial replacement.

Keep AI alternatives as independent candidates. User-selected saved/imported references
are independent of generated candidate lists. Switching the displayed proposal never
unions their modules or rewrites their baseline origin.

### 4.2 Additive raw contract

Input v4 gets optional `fitComparisonInput` with `schemaVersion: 1`, client generation
and encounter references, prepared baseline snapshot/fingerprint, explicit inventory
knowledge, local known-type metadata and limitations. This is a separate top-level
input section, not evidence facts. With no baseline, omit the candidate-capable input
or declare baseline unavailable; the AAR still succeeds without a proposal.

Report v3 gets optional `fitCandidates`, each using this shape (illustrative keys):

```json
{
  "schemaVersion": 1,
  "candidateId": "alternative-a",
  "baselineSnapshotId": "supplied-baseline-id",
  "baselineFingerprint": "supplied-fingerprint",
  "encounterId": "supplied-encounter-id",
  "label": "Armor alternative",
  "rationale": "Trade speed for the stated tank objective.",
  "confidence": "medium",
  "target": {
    "shipTypeId": 587,
    "groups": {
      "high": {"status": "complete", "items": []},
      "mid": {"status": "complete", "items": []},
      "low": {"status": "complete", "items": []},
      "rigs": {"status": "complete", "items": []},
      "subsystems": {"status": "notApplicable", "items": []},
      "drones": {"status": "complete", "items": []},
      "fighters": {"status": "notApplicable", "items": []},
      "cargo": {"status": "complete", "items": []}
    }
  },
  "replacements": [],
  "limitations": []
}
```

The example's N/A declarations require local hull confirmation; generated assertions
are not proof. Module entries specify type, slot index/position meaning, state and
charge knowledge; inventory stacks specify exact type and positive quantity, plus
explicit deployment configuration when known. Declared unknown/omitted inventory
cannot silently default to a complete empty group.

Validate raw presence/types **before** `Fitting.fromJson` defaults erase omissions.
Then locally validate category-6 hull, module/subsystem slot identity, positive integer
quantities, unique physical slots, charge/category compatibility where known and
effective hull capacities. Do not trust generated attribute bags, stats, prices,
availability, evidence confidence, captured times or claimed validation status.

Structural errors include unknown types, incompatible groups, slot collisions and
known nonexistent slots. Known CPU/PG/calibration or deployment-budget excess retains
inspection and physical counts, with constraint warnings. Unknown capacity/legality
is a limitation, not permission to mark the fit fully validated/ready to fit.

Replacement annotations identify one baseline occurrence and one target occurrence,
with original baseline fingerprint. Validate endpoint membership, uniqueness and
same-hull compatibility; reject inconsistent annotations without inventing a pairing.
Never apply an origin's replacement annotation when comparing against another source.
Optional `intent: upgrade` remains a rationale label on a Modified row.

### 4.3 Client ownership and resilient parsing

Client-stamp proposal origin, encounter, generation and snapshot IDs after validation.
Returned baseline/encounter references must match the prepared request; unknown or
mismatched references make that candidate unavailable, not silently rebased. A later
user baseline selection leaves the valid original association untouched and shows
**Based on an earlier fit.** with both references when they differ.

Keep existing required report keys and `fitAdvice` strings unchanged. Parsing an
optional candidate is independently bounded and caught; it must not throw the whole
otherwise readable report into the client's repair request. Unknown versions keep
narrative plus an unsupported-candidate state. Supported new fields round-trip through
all report constructors/copy helpers, legacy conversion and storage.

Separate raw generated candidates from locally validated stored envelopes. Do not
accept generated `fitComparisonAtGeneration`: the analysis service overwrites/sets
that client-owned field from prepared inputs. Cache validation only with its validator
revision and local SDE key; changed local data can revalidate a candidate without
rewriting historical source content or treating AI numbers as statistics.

Prompt rules request complete targets only when exact supplied/local-known types can
support them; otherwise omit candidates and retain useful prose. Include a bounded
local type vocabulary: baseline/victim types first, then same-group local alternatives
ordered deterministically, up to 512 entries. This is a vocabulary, not a client-chosen
doctrine or best-module ranking. Mark truncation; do not invent missing data to fill it.
Candidate types must resolve locally. The 512-entry budget is not a validation
allowlist: compatible exact types outside it still undergo independent local
validation and may be labeled validated locally, not supplied in prompt. Unknown
types remain unavailable; the client never fills omitted exact types from generic prose.
Limit to eight candidates, 256 KiB per candidate, 4,096 expanded modules and signed
32-bit positive stack quantities; reject excess without truncating an accepted fit.

### 4.4 Current capture and saved/EFT reference services

Add `AarFitComparisonService` with methods conceptually:

```dart
Future<AarComparisonSaveResult> captureCurrentForComparison(ParsedCombatEncounter e);
Future<AarComparisonSaveResult> importProposal(ParsedCombatEncounter e, String text,
    AarBaselineReference? origin);
Future<AarComparisonSaveResult> copySavedReference(ParsedCombatEncounter e,
    SavedFittingReference reference, AarBaselineReference? origin);
```

An absent origin means an explicitly unbound user reference when no baseline exists;
the UI requests selection for deltas, not historical association by guesswork. AI
proposals require the prepared origin and cannot use this unbound shortcut.

Extract `CurrentShipFitReader` from the evidence service's fetch/map path: authenticate
the encounter character locally, fetch its ship and all assets pages, map, and return
copied fitting, raw-input knowledge, source instance IDs and capture time. Evidence
and comparison callers then persist through different owned-field methods. Preserve
the shipped evidence flow's feedback and confidence. Do not call `AssetSyncService`;
comparison capture must not populate the ownership cache as a side effect.

The current ESI ship getter collapses all Dio failures to null. Add an opt-in strict
read/method that preserves transport/auth errors for comparison while keeping existing
callers' default behavior. A real null ship gets the no-active-ship message; a network
failure gets comparison-save failure, not a guessed empty ship. All pages must succeed;
an empty successful response remains a qualified hull-only snapshot.

Saved selection uses a new read-only `SavedFittingReference` DTO/query returning the
fitting, source row ID, nullable owner, created/updated times and optional knowledge.
Scope to the encounter character plus shared records; null character permits shared
records only. Copy before validation/save and never mutate the saved row. Do not reuse
the active-character `SavedFittingsDialog` with its editor load/delete actions.

Proposal EFT import reuses `AarFitImportParser` and its faithful-content rules. Add
`parseWithKnowledge`/manifest result while preserving existing `parse` as its fitting
projection. The new proposal dialog owns its controller and **stays open** on parse
or save error, showing actionable inline detail. Disable duplicate submits and dialog
Cancel/barrier/Escape throughout one synchronously reserved `isSubmitting` phase
covering parse→validate→CAS save; restore them on inline failure. This avoids canceling
the dialog while a still-running parser later starts a write. Idle cancel has no
write. Successful commit
closes it and allows guarded parent feedback. Navigation/disposal follows §8.4.

## 5. Deterministic inventory differences

### 5.1 Difference records

`FitInventoryDiff` names baseline/candidate IDs/fingerprints, same/different hull,
group results, completeness and limitations. `FitChangeRow` has stable row ID,
objective kind, before/after occurrence references, explicit quantities, slot meaning,
charge/state/deployment details and reason/qualification. Unknown occupants use a
separate unresolved-row status rather than a false Unchanged match.

Stable row keys combine source IDs with canonical occurrence tuples and duplicate
ordinals. These ordinals distinguish interchangeable duplicates, not input-list order.
Display names can change row text/order without changing the semantic diff identity.

### 5.2 Matching algorithm

Run separately for each slot group. Do not expand stack quantities into per-round
objects; fitted module occurrences are bounded by accepted input limits.

1. Cancel exact `(type, charge knowledge/identity, state/knowledge)` occurrences
   one-for-one first, regardless of list order or physical movement.
2. For remaining same-type occurrences, pair equal recorded physical slots first
   when both sides have that meaning. Pair the rest after canonical sorting by
   charge knowledge/ID (`unknown` first, then `recordedAbsent`, then identity ordered
   by numeric ID), module-state enum order, recorded slot when meaningful, then
   stable remaining knowledge/tuple fields and duplicate ordinal. This is a total
   order even when both sides have null IDs or recorded/assumed equal states; input
   position is never a hidden tie-break.
3. Pair remaining different types only for equal recorded physical slots on the
   same hull, or a validated applicable origin replacement annotation. Different
   hulls never acquire synthetic slot-to-slot replacements.
4. Emit remaining Added/Removed rows, with deterministic internal type/source order.
   Explain physical moves separately without treating an unchanged moved module as
   a purchase. Across-group moves remain visible in both groups.

Exact matches always precede replacement annotations. Conflicting/consumed annotation
endpoints are not used to override a better exact match. Unknown identity occupants
remain unresolved; do not cancel them by a shared fallback display label.

For drones/fighters/cargo, compare total explicit quantity per exact type and show
deployment/configuration differences separately. Retain original deployment tuples
for calculation even when the UI groups physical counts. Quantity deltas use integer
arithmetic; show removed two drones as two units, not two entire group records.

An incomplete baseline/candidate changes Added/Removed wording to **Present only in
this record** / **Absent from supplied record** where a historical change is not
established. Preserve the known record difference without implying missing groups
were empty. Show all is default; Changes only collapses unchanged groups to counts,
and fully identical recorded inventories show **No recorded equipment changes**.

F1 must produce one unchanged A, one modified A, recorded B→C replacement, −2 D,
+50 Ammo and +20 Paste. Its order-only tie variant must pair X→W and Y→Z under all
input permutations. F2's cargo-to-slot A move affects group details but buys no A.
Add permutations pairing unknown versus proven-absent charge entries with two known
charges, and recorded versus assumed equal state, to prove the extended total order.

## 6. Neutral computation, shared context and metric deltas

### 6.1 Reuse without fabricated evidence

Extract a neutral computation from `CombatFitDeriver.derive`:

```dart
Future<CombatFitComputation> deriveFitting({
  required Fitting fitting,
  required FittingStatsInputs inputs,
  required AarSkillContext skills,
});
```

`CombatFitComputation` contains `stats`, `bareHullStats`, tank classification,
resolution coverage and diagnostics. Existing `derive(FitEvidence, ...)` delegates
and attaches its evidence-specific metadata; existing callers keep their behavior.
The comparison service uses the neutral method and never constructs proposal evidence.
The deriver's existing `baseline` means bare hull; call it `bareHullStats` in the new
neutral contract to avoid confusing it with the selected comparison baseline.

Add `DogmaEngine.calculateDetailedStats` returning stats plus diagnostic facts; keep
`calculateStats` as a compatibility wrapper returning `.stats`. Expose already
computed effective attributes/capacities and unsupported/missing input information,
not a second simulation. Reuse `loadFittingStatsInputs(...,
effectLookupPolicy: EffectLookupPolicy.localOnly)` for module/charge/drone/fighter,
bomb and skill dependencies. Cargo remains physical inventory, not an inferred Dogma
input or injector resource budget.

### 6.2 One comparison calculation frame

`AarComparisonContext` contains:

- Immutable common `AarSkillContext`, sorted skill-level map/fingerprint and basis.
- Selected profile: Omni, eligible M5 source, or explicitly labeled Aggregate blend;
  normalized fractions plus source/confidence/weapon coverage/conditional warnings.
- Module/state/deployment policy revision, SDE input revision/content key and calculator
  revision. Source fingerprints are part of the enclosing request key.

Default is Omni (25% each). Resolve cached pilot skills once for every column, including
victim/proposal. Empty/unavailable usable skill context falls back together to All V,
or the user explicitly chooses All V. Preserve partial-skill limitations. Do not reuse
ordinary opponent derivation's separate All V fallback for one comparison column.
Victim columns disclose **Modeled with comparison skills; opponent skills unknown**.

Build profile choices from canonical incoming allocation, already-persisted correlation
and local actor types, using the existing pure M5 grouping/eligibility rules. Do not
watch `combatAttackerCorrelationProvider` or the full `aarIncomingMatchupsProvider`
for this selector: the former can call `ensureAttackerCorrelation` and write the
ledger on view. Reuse/extract a pure profile-choice helper without backfill or fit
derivation. Missing legacy correlation leaves individual choices unavailable until
the existing explicit evidence workflow supplies it; Omni and an eligible labeled
aggregate can still be used. If a selected source becomes ineligible, show profile
unavailable and offer Omni explicitly rather than silently substituting a new profile.

Read skill inputs as one local app-DB snapshot and all visible fitting/SDE inputs under
one local SDE read snapshot. Capture revisions before/after multi-database preparation;
if relevant inputs changed, retry preparation up to three times, then expose loading/
unavailable rather than a mixed frame. Do not hold transactions across simulation,
remote calls or operation waits. Hash actual loaded types/attributes/effects when a
coarse bundled-version integer cannot identify changed local effect content.

Compute immutable `AarComparisonFrame` keyed by source fingerprints and context. Each
column result carries that key. Reject late results for prior keys; headers, inventory,
assumptions and numbers bind to the same frame. Same-key optional refresh may retain
old values with status. A new fit/profile/skill/revision shows scoped placeholders
until its numbers are ready, never old values under the new label.

Separate the expensive Dogma key (fit/configuration, skills, SDE, calculator) from
defense projection (that result plus normalized incoming profile). Changing only the
profile recomputes shared weighted defense, not turret/engine simulation. Cache in
memory for active encounter sources with bounded entries; do not persist live stats
as source evidence or retain obsolete fits indefinitely.

### 6.3 Engine diagnostics and availability

Introduce per-metric `available`, `partial`, `unavailable`, `notModeled`, with typed
units and nullable values. A separate value case represents an explicitly unbounded
model result; never serialize NaN/Infinity. Include limitation codes and relevant
input coverage per metric. Defaults in `FittingStats` are not availability flags.

| Metrics | Shared result and availability contract |
| --- | --- |
| Layer HP/resists | Engine defenses plus known-required-attribute diagnostics. A missing resonance defaulted to zero is not known zero resistance. |
| Layer/total selected EHP | Shared `DefenseProfile` weighted calculation; never use stored omni EHP for a non-omni profile. Missing layer remains unavailable/partial, not zero. |
| DPS and Weapon volley | `dpsGuns`, `dpsMissiles`, `dpsDrones`, `dpsFighters`, `dpsTotal`, `volley`. Volley is loaded turret/launcher only. Unknown charges qualify offense, not observed zero damage. |
| Speed/align/signature | `maxVelocity`, `alignTime`, `signatureRadius` with input diagnostics. Missing/invalid mass/inertia cannot appear as meaningful zero align time. |
| Capacitor | Tagged stable-percent/depleting-seconds/unavailable result, capacity GJ, 3600-second horizon and infinite-injector-clip limitation. Do not interpret the overloaded `capacitorStable` scalar without `isCapStable`. |
| Burst tank | Existing `effectiveShieldBoost`, `effectiveArmorRepair`, `effectiveHullRepair` are raw HP/s, not EHP/s or sustained repair. |
| Passive/sustained tank | `peakShieldRecharge` is Peak passive shield HP/s. Sustained repair is always Not modeled in this release. |
| Constraints | CPU, PG, calibration and proven deployment/capacity demand; known violations warn, never certify comprehensive game legality. |

Only offline modules are excluded by current engine state semantics. Online/active/
overloaded labels do not prove distinct activation or heat simulation. Preserve source
state plus the shared limitation. Unknown contributing modules conservatively affect
all potentially impacted tactical metrics; do not call their omission a guaranteed
EHP/DPS floor. Missing effects/unsupported operators are diagnostics, not silent success.

Before deltas, run `qualifyComputation(snapshot, computation, context)` in the
comparison domain. Neutral `FittingStats`/`AarFitCoverage` cannot detect omitted or
default-empty groups. Unknown/partial applicable module groups or unplaced potential
modules qualify every potentially affected tactical metric; absent drone/fighter
knowledge qualifies corresponding and total DPS. Missing cargo alone does not qualify
Dogma stats, since cargo is not simulated. Charge/state/deployment knowledge applies
its specific limitations. Test a legacy default-empty low-slot list with no unresolved
type IDs: it must not produce a fully available bare-hull-to-target uplift claim.

Expose `effectiveSlotCapacities`, missing structural attributes, unavailable effects,
unsupported modifier count, requested deployment demand and capacitor limitations
from the existing attribute pipeline. Tengu-like hulls can gain slots from subsystems:
raw base slot counts of zero must not reject all modules. Subsystem capacity is unknown
unless separately validated local metadata supports it; neither hardcoded coverage
zero nor exporter limits establish N/A. Known nonexistent physical slots are invalid;
unknown capacity makes structural certainty partial, not falsely complete.

The engine currently allocates drone/fighter capacity in list order. For comparison,
canonical-sort deep-copied deployment groups by type and deployment/quantity tuple
before calculation; disclose deterministic modeled priority if capacity constrains
output. Do not merge `(quantity=5, inSpace=0)` with `(quantity=5, inSpace=1)`: current
engine defaults make that change deployment semantics. Requested demand diagnostics
must be measured before engine clamping; already capped `Used` fields cannot detect
all requested overcapacity. BOM always retains full explicit inventory quantities.

### 6.4 Delta arithmetic and numeric oracles

Use the existing domain weighted EHP implementation for each layer:
`H / Σ p[t](1-r[t])`, total as the sum of layers. If its current finite-denominator
guard hides a degenerate denominator, expose a shared diagnostic/typed evaluation
alongside the existing compatibility API; widgets must not implement another formula.
Invalid/nonfinite inputs yield unavailable, and a zero valid denominator may be labeled
unbounded in the model with no percentage badge.

For two comparable finite values: native delta is target − baseline; percentage
delta is optional and only allowed for strictly positive finite baseline. Resist
delta is `(targetFraction − baselineFraction) * 100` percentage points. Round only
in presentation. If either side is partial, show qualified known values but suppress
confident improvement badges. Price, stronger EHP or faster speed never determines an
overall winner.

Capacitor uses a tagged comparison: stable→stable compares pp, depleting→depleting
compares seconds, cross-state displays **Depleting → Modeled stable** (or reverse).
Never subtract stable percent from depletion seconds. Always expose the simulator
horizon, and infinite clips where applicable; sustained repair remains Not modeled.

Product F3 oracle before rounding:

| Profile | Baseline total EHP | Target total EHP | Delta | Relative delta |
| --- | --- | --- | --- | --- |
| EM 100% | 6,000 | 7,500 | 1,500 | 25% |
| Omni | 4,285.714285… | 4,615.384615… | 329.670329… | 7.692307…% |

Both use three 1,000 HP layers; EM resist changes by +10 pp per layer. Test the shared
domain calculation at precision first, then locale-aware text separately. F4's
120 seconds→stable 35% is a transition, not −85; burst 100 and peak passive 20 remain
HP/s. These are synthetic fixtures, not current EVE performance claims.

## 7. Bill of materials, asset annotations and estimated values

### 7.1 Pure physical requirements

`FitBillOfMaterials` records target and baseline IDs/fingerprints, mode, overall
completeness, exact/unknown requirement lines, removals, configuration-only changes,
unquantified charge/cargo advice and limitations. `FitBomLine` contains type ID,
known target count, observed record difference, nullable proven required count and
its knowledge/reason. A missing count is never serialized or rendered as zero.

Build physical type counts across **all** groups before subtraction: one hull, every
module occurrence including offline, explicit drones/fighters/cargo quantities. Use
checked integer or BigInt totals and never expand ammunition stacks into objects.
Loaded charge identities without recorded quantity do not enter physical counts.

- Changes: `required[t] = max(0, target[t] - baseline[t])` only when both counts are
  provable. Keep removals separately as `max(0, baseline[t] - target[t])`.
- Full replacement: `required[t] = target[t]`, including hull, with no baseline credit.
- Same-type cargo-to-slot movement cancels in the global physical count even though
  group/location/configuration diffs remain visible.
- Different-hull Changes is still a net type-count comparison, including added new
  hull and removed old hull; it establishes neither possession nor physical reuse.
- Default Full replacement for a known own loss or hull change. A likely-outcome log
  hint alone is not proof of a destroyed baseline; use identified own-victim evidence
  or equivalent explicit known-loss state. User may switch modes for information.

Incomplete baseline groups may contain apparent additions, especially cargo. A type's
delta is exact only if every unknown group is provably unable to contain it. Otherwise
keep the observed difference but set required quantity unknown, label **Incomplete
change list** / **Not present in baseline record**, and suppress exact shortfall/value
for that line. An entirely unknown occupant can taint all possible types; do not guess
it is unrelated. A complete target's Full replacement remains exact regardless of
baseline completeness; a partial target always makes the overall BOM incomplete.

Loaded identities appear under **Charge quantity not recorded**. Explicit cargo ammo
is counted once; neither a clip nor one round is inferred from `chargeTypeId`.
Keep generic cargo prose in **Unquantified recommendations**. A quantified advice
line needs an exact resolved type, positive integer quantity and provenance, and must
be part of the target's explicit cargo inventory to enter its BOM. Advice does not
silently append inventory or merge alternative proposals.

### 7.2 Cached asset matching is a separate annotation

`AarCachedAssetMatch` contains observed count, eligible-loose count when established,
eligibility/overlap status, selected location references and nullable estimated
shortfall. It annotates requirements; it never changes their physical arithmetic.

Create an encounter-character family over `AssetRepository.watchAssets(characterId)`
and cached location reads. Do not watch global `assetsProvider`/`groupedAssetsProvider`
or invoke a sync service. Null encounter character means availability unknown. The
cache has no freshness/completeness timestamp: always show **Asset freshness unknown**.

Credit only rows with all of these positively established:

1. The exact encounter character and positive valid quantity.
2. Direct location ID equal to an explicitly selected cached station/structure.
3. Recognized loose-hangar flag, no parent-asset relationship and no contradictory
   containment. `containedInId == null` is not proof: the current sync writes null
   even for contained assets.
4. Not another ship's fittings, cargo, drone/fighter bay, nested container, ambiguous
   or unknown-location stock. Such observations remain informational only.
5. In Changes mode, disjointness from baseline counts already subtracted. Where
   source instance IDs plus coherent same-observation provenance or another verified
   exclusion relationship prove disjointness, use them. Different IDs across unrelated
   snapshots alone do not prove it: stacks can split/merge or items be repackaged.
   Otherwise a manual/historical
   baseline's A modules could now be the loose A in cache after stripping: A shortfall
   stays unknown. Types provably absent from the complete baseline can qualify.

Full replacement credits no baseline, so it avoids that particular overlap question;
it still needs eligible stock. Never credit the victim's other-character assets or
destroyed baseline equipment. Partial/ambiguous observations do not establish zero
ownership. A missing/empty cache gives Availability unknown; Not found in cached assets
is a statement about the cache, not a verified shortage.

For a line with exact required quantity and established disjoint eligible cached
units, `estimatedShortfall = max(0, required - eligibleLooseCount)`. This estimate is
against those cached observations, not fresh ownership. Unknown eligibility/quantity
produces null, not a guessed subtraction. Zero means covered by eligible cached stock,
never **ready to fit here**. Unknown extra/remote stock remains disclosed separately.

### 7.3 Cached estimates and refresh

Use `MarketPrices.averagePrice`, not adjusted price or Dogma cost defaults. Add batch
read/watch by the BOM's distinct type IDs to `MarketRepository`; avoid N per-row queries
and compute each subtotal from one coherent cached-price batch. Keep the existing
single-item providers for other consumers.

`AarPriceEstimate` contains type ID, optional nonnegative finite average price,
`lastUpdated`, stale flag and source label **ESI average price estimate**. Exactly
24 hours old is stale under an injected clock. Preserve stale quotes with **Stale
estimate** and **Cache refreshed at …**; the latter is local cache age, not quote time.
Future-dated cache timestamps are flagged uncertain rather than silently fresh.

Multiply known required quantity by the unit estimate and sum gross requirements.
Do not deduct removed-item values, insurance, salvage, transport or taxes. An optional
shortfall estimate is separate and uses only known eligible shortfalls. Stored valid
zero is **0 ISK estimate**, not free; absent, negative, nonfinite or adjusted-only is
**Price unavailable**.

For deterministic arithmetic, represent the stored finite quote's canonical decimal
value as coefficient/scale and multiply by integer quantity before final display
rounding. A small immutable `IskEstimateAmount` suffices; do not couple money to the
combat damage rational type. No rounding per intermediate unit/subtotal. Convert only
at the `formatIsk` display boundary with finite/range checks. Preserve priced-line
coverage and unknown quantities rather than allowing overflow to produce infinity.

Only an exact complete requirement set with every line priced can show a gross
required-item estimate. Otherwise label **Priced subtotal**, with priced type-line
count, total known type-line count, unknown quantities and unquantified exclusions.
Never call a partial sum Total cost. A valid zero-requirement complete Changes list
can show no equipment required; an unknown requirement set cannot.

Explicit Refresh prices calls `marketSyncServiceProvider.syncPrices()` only. Do not
call `syncMarketProvider` (which also fetches active-character orders), market history
on read, or asset sync. Track refresh progress/error separately from cached rows so
failure retains prior estimates. Public price refresh does not require authentication.

Product F2 exact oracles:

| Output | Known required types | Priced result |
| --- | --- | --- |
| Changes | C×1, Ammo×50, Paste×20 | 2,000,500 ISK priced subtotal; 2/3 type lines priced |
| Full replacement | H×1, A×2, C×1, Ammo×150, Paste×20 | 104,001,500 ISK priced subtotal; 4/5 lines priced |
| Qualified Changes shortfall | C×0, Ammo×20, Paste×15 | 200 ISK priced shortfall subtotal; Paste excluded |

These fixtures explicitly establish complete inventories and disjoint eligible stock.
Repeat with H2, incomplete baseline, empty/ambiguous asset cache, missing/zero prices
and exact-24h age. No A purchase follows the cargo-to-slot move.

## 8. Riverpod composition and reusable presentation

### 8.1 Provider graph and dependency isolation

Keep comparison providers in `aar_fit_comparison_providers.dart` with plain service
providers, asynchronous source/input preparation and pure derived providers. Suggested
definitions name dependencies rather than binding widgets to an active fitting:

| Provider | Kind / dependencies | Responsibility |
| --- | --- | --- |
| `aarComparisonStoreProvider(encounterId)` | Stream of raw owned comparison state via repository observation | Durable current/user proposal content; unsupported/read-error state scoped here. |
| `aarComparisonSourcesProvider(encounter)` | Async composition of comparison store, evidence projection and actual stored report | Immutable role/source choices and generation history; no capture or discovery on watch. |
| `aarComparisonSelectionProvider(encounterId)` | Encounter-scoped controller | IDs, layout selections, common context choice, filter and expansions. No evidence/editor mutation. |
| `aarComparisonContextProvider(encounter)` | Async cached skills/SDE/profile composition | One declared common context with real revision/content keys. |
| `aarComparisonFrameProvider(requestKey)` | Async prepared-input/calculation service | Per-fit neutral computation; current-key result validation and partial metrics. |
| `aarFitDiffProvider(pairKey)` | Pure provider | Canonical inventory matching and group knowledge. |
| `aarFitBomProvider(targetBaselineModeKey)` | Pure provider | Physical exact/unknown requirement set, independent of prices/assets. |
| `aarComparisonAssetsProvider(characterId)` | Cache-only stream plus cached locations | Character-bound observations, never global selection/sync. |
| `aarBomPricesProvider(typeSetKey)` | Batch cached-price stream | Timestamped unit estimates; separate explicit refresh controller. |
| `aarBomAnnotationsProvider(requestKey)` | Pure composition | Cached-spares qualifications and estimated values/coverage. |
| `aarComparisonOperationProvider(encounterId, slot)` | Disposable UI observation of stable coordinator | Busy/result feedback, not storage lock or evidence score. |

Use the actual report loaded for the encounter, not just advice strings passed through
a stale widget constructor. An explicit newly saved report replaces its source list;
an old in-flight read cannot replace the current report ID/generation in the workspace.
Proposal validation depends on local type/revision availability and remains independent
of price/icon data. Shared lookup batches should include all displayed inventory types.

Use Riverpod `.when()` and `skipLoadingOnReload: true` where the **same semantic key**
is reloading cached source/prices and previous data is truthful; retain a visible refresh
indicator/error annotation. For a changed fit/context/pair key, discard old numeric
projection or show loading for that row. Do not rely on skip-loading flags alone to
prevent stale values: compare the returned frame key with current headers/assumptions.
An optional source failure cannot replace the whole workspace with an error.

### 8.2 Widget hierarchy

```text
AnalysisMultiPaneScreen
  pre-analysis Compare fits entry / post-analysis Fits tab
    AarFitComparisonWorkspace(encounter)
      AarComparisonSourceSelector + baseline picker
      AarComparisonAssumptionsBar (skills, profile, revisions)
      AarComparisonColumns
        AarFitSourceHeader (role, subject, hull, provenance, time)
        AarFitInventoryView
          AarFitGroupSection × eight groups
            AarFitDiffRow + EveTypeIcon + accessible item details
        AarFitStatDeltaCards (same ordered metric descriptors)
      AarFitBomCard
        mode/target/baseline header
        AarFitBomTable or narrow stacked rows
        removals/configuration, unknown charges/cargo, cache/price coverage
      Existing fitting advice and evidence actions
```

Pure inventory/stat/BOM widgets take values and callbacks. Only thin name/icon/provider
adapters watch Riverpod. Reuse `EveTypeIcon`, theme, formatters and visual primitives;
do not embed `FittingEditor`, `StatsPanel` or `SavedFittingsDialog` bound to mutable
`activeFittingProvider`. Expose all eight groups, including subsystems/fighters/cargo.

### 8.3 Responsive and accessible behavior

Use `LayoutBuilder` at the workspace content boundary after sidebar/padding, not
window width. At normal text size: ≥1440 four total source columns, 1000–1439 baseline
plus two, 720–999 baseline plus one, below 720 a visible baseline summary with source
tabs and vertically stacked baseline/candidate groups/stat rows. Dedup can reduce
actual populated columns; every hidden/missing role remains available in the picker.

At enlarged text, calculate a conservative effective width using scaled body text
and reduce columns further, then allow wrapping/stacking. A 320px viewport at 200%
must not horizontally scroll the page. Preserve selected source IDs, group expansion
and scroll anchors across resizing, keyed by encounter/source/group rather than
column position. Keep keyboard and touch alternatives to hover/swipe-only access.

The existing pre-analysis prompt is width-limited and report tabs have a 520px height
constraint. Provide a full-width comparison route/panel from Compare fits and a
scrollable Fits workspace inside the actual tab. Do not force the entire multi-column
workspace into the narrow prompt or an unbounded nested `Column`; each host must have
one clear vertical scroll owner and bounded tab content.

Headers show source/role, named subject, named hull, confidence/reference/proposal,
capture time separately from evidence time, and partial/stale warnings. Use
`itemNameProvider` with local SDE/stored safe-name fallback; sanitize mapper labels
such as `Type #…` and `Ship #…`. Unknown hull/module becomes **Unknown ship** /
**Unresolved module**, not a numeric ID. Do not reuse `AarSkillContext.label` or
coverage `describe()` raw-ID strings verbatim in comparison UI. Character/location
labels similarly use resolved or honest unknown text. User fit names with ordinary
numbers are not automatically IDs; only known generated placeholder patterns are
rejected. Killmail links can say View killmail without displaying a raw ID.

Rows retain fixed-size icon placeholders on loading/error, full text/details available
by focus and tap, quantity/state/charge/source/slot meaning, and explanation of changes.
Use text and distinct icons with badges, not color alone. Synchronized group expansion
and shared metric row descriptors align columns; narrow layouts repeat baseline context
beside the selected candidate. CPU/PG/capacity warnings are not ready-to-fit badges.

### 8.4 Lifecycle and exact action feedback

Reuse the screen's captured encounter, `_screenGeneration` and `_canPublishUi` pattern.
Capture service/slot expectation before awaits; never read a new `widget.encounter`
after completion to decide the write key. A disposed/navigated screen can leave a
successful original-encounter save durable, but cannot show a late snackbar or update
another encounter. Old calculation/capture/proposal results must pass source/key or
slot-precondition checks. All busy indicators and errors are scoped and accessible.

Use typed comparison errors (`authUnavailable`, `noShip`, `captureFailure`,
`invalidProposal`, `saveFailure`, `conflict`) and one presentation formatter. Keep
transport/SQL details in tagged logs, not snackbars. For proposal parser errors reuse
strict actionable validation detail inside the still-open dialog. Cancel before an
operation starts is a no-op; once persistence is underway, navigation may remove the
view but cannot imply that a committed save was canceled.

| Trigger | Exact Product feedback |
| --- | --- |
| Current comparison committed | Current fit saved for comparison. |
| No authenticated encounter pilot | Sign in with this pilot to capture the current fit. |
| Strict ship read returns no ship | No active ship is available for this pilot. |
| Capture/network/save failure | Could not save the current fit for comparison. Try again. |
| Saved/EFT proposal committed | Proposed fit saved for comparison. |
| Proposal storage failure | Could not save the proposed fit. Try again. |
| Different candidate origin | Based on an earlier fit. |
| Legacy/no usable structured candidate | No structured proposed fit. |
| Price refresh committed | Price estimates refreshed. |
| Price refresh failure with cache | Could not refresh prices. Showing cached estimates. |
| Price refresh failure without cache | Could not refresh prices. Price estimates are unavailable. |
| Column calculation failure | Stats unavailable for this fit. |

CAS conflict preserves the committed snapshot and uses the relevant save-failure
message plus scoped actionable detail that another save changed this source; retry
must be an explicit new operation. No success before commit, no success for cancel,
no UI inference that proposals affect completeness. Preserve the separate shipped
evidence action messages/dialog policy unchanged.

## 9. Implementation units, TDD ownership and release gates

### 9.1 Work units and dependency order

Every unit has Test-Author RED, developer GREEN, reviewer and independent tester
ownership. RED means a relevant failing behavioral assertion for a new requirement,
not merely an uncompilable import; existing compatible behavior can start green.
Commit bounded units and their evidence. Re-estimate the feature against these data
contracts rather than the queue's old visual-only estimate.

| Unit | Owned files/responsibility | RED / GREEN / review-test gate |
| --- | --- | --- |
| W0 — Contracts and fixture harness | New snapshot/proposal/context models, F1–F5 fixtures, serialization tests and production-composition harness additions. | Test-Author pins deep-copy/fingerprint/knowledge and legacy cases; developer adds types; reviewer checks no fabricated evidence; tester proves genuine repository round trips. |
| W1 — Owned storage and source acquisition | Enrichment/model projections and retention, repository CAS/observation, publisher/coordinator, shared read-only capture, saved-reference query, strict import manifest. | RED P01/P03/P04/P06/P08/P09/P11 and first-comparison-row isolation; GREEN independent fields and truthful source metadata; two-connection tester gate plus existing evidence regressions. |
| W2 — Generation and proposal contract | Analysis prepared-input selection, report/client additive schemas, local candidate validation and origin binding. | RED D15/D16/P02/P13/P14, including malformed optional candidate not triggering report repair; GREEN frozen history and optional valid candidates; reviewer checks client authority and report-failure retention. |
| W3 — Pure diff and BOM | Inventory diff, physical quantities, qualified requirements and F1/F2 pure fixtures. | RED permutations, incomplete cross-group counts and both hull modes; GREEN exact deterministic rows/counts; reviewer rejects upgrade inference and unknown-as-zero; tester checks all quantity oracles. |
| W4 — Neutral calculation and metrics | Shared Dogma diagnostics/compatibility wrapper, neutral deriver, common context/frame caching and delta math. | RED F3/F4, unknown inputs, dynamic slots, deployment permutation and stale-frame races; GREEN shared engine results with availability; reviewer rejects duplicate math; tester runs fitting and M5 regressions. |
| W5 — Prices and cached spares | Batch market reads, price-only refresh state, encounter asset/location adapters and pure annotations. | RED F2 values, 24h boundary, invalid prices, containment/overlap and wrong-character cases; GREEN qualified independent data; tester asserts no order/asset sync and cache-retaining errors. |
| W6 — Read-only workspace and dialogs | New parameterized widgets/providers, screen hosts, selector/proposal dialogs and feedback. | RED actual pre/post reachability, breakpoints, accessibility, scoped errors and unchanged editor/evidence; GREEN composition over W1–W5; reviewer and tester inspect desktop/narrow renderings and real actions. |
| W7 — Integration and closeout | Cross-unit regression, documentation/journal and queued disposition after delivery. | All AC/case/scenario receipts, full relevant suites/static analysis, real UI/storage and two-window evidence; no shipped claim with unresolved critical gates. |

Use W-prefix for implementation units to avoid confusion with Product's U01–U16 UI
test IDs and the previous initiative's U0–U5. Sequence W0 first; W1 and W2 can author
tests in parallel but one integrator owns shared enrichment/analysis serialization
edits. W3 and W4 run independently after W0; W5 pure annotations can run alongside
them. W6 isolated widget authoring can proceed on agreed typed fixtures, but real
journey GREEN follows W1–W5. W7 is sequential. Workers must preserve others' edits;
do not assign concurrent uncoordinated edits to shared models/provider/service files.

### 9.2 Test harness and boundary requirements

Extend the shipped `test/features/combat_analyzer/fixtures/fit_evidence_harness.dart`:
real App/SDE databases owned outside widgets, real parser/mapper/repository/scorer/
neutral calculation, ScriptedEsiAdapter and gated mutation delegating to real SQL.
Add a production-provider-composition variant: the existing fixed enrichment-service
override and fixed SDE/skill streams cannot prove publication or live revision behavior.

Override only upstream network/auth and fixture inputs for journey tests; do not
manufacture comparison sources, BOM results, stat frames or successful saves in a
fake service. Pure math/widget presentation tests may supply typed values, but those
do not satisfy P-series persistence or U-series real navigation obligations.

Use actual saved-fitting updates and cached asset/market rows, encounter pilot P with
globally active Q, and recorded pre/post evidence/editor/report JSON. Gate before SQL,
inject one real SQLite failure after seeding, and verify no publication/success and
previous content retained. Test two separately opened connections to one temporary
database file for external observation and field CAS; initialize schema before races.

For generation tests, the recording external AI fake captures the actual prepared
snapshot/input; attach F-new while its response is pending and inspect persisted
F-old content after success. Include failed pilot derivation→own-victim fallback
without false initial staleness, and same-score attachment replacement afterward.
Optional candidate failures must leave prose/report intact with zero extra repair
request attributable only to that candidate.

For frame tests, change each semantic input and resolve old work last. Assert no
old numbers under the new header, including skill/SDE updates from another connection.
For layouts, test actual workspace usable widths after sidebar/padding, not only a
standalone four-column fixture at nominal window width.

Inject clock, observer ticks and completers. Avoid `pumpAndSettle` while deliberately
holding a spinner; assert intermediate states, release the boundary, then settle.
Dispose views/provider scopes, operation observers and ESI subscriptions before closing
databases. Assert no `tester.takeException()`, late snackbar or orphaned poll timer.
Real network/market/AI is forbidden in deterministic fixtures.

Add targeted isolation subcases: open/change a profile on legacy enrichment that
would otherwise need correlation backfill and assert zero mutations (U15/P12);
attempt Cancel/barrier/Escape while proposal parsing is gated and prove it cannot
dismiss or save after an apparent cancellation (P08/U12); and split/repackage a
baseline-present stack into a different cached instance ID, preserving unknown
shortfall without coherent overlap proof (D14/W5).

### 9.3 Complete Product test execution index

Each row includes the full parameterizations in Product §9, not just one happy-path
example. D = pure domain/contract; P = real provider/repository/service composition;
U = real screen/interaction with applicable lower layers intact.

| Case | Units | Required evidence | AC |
| --- | --- | --- | --- |
| D01 | W3 | Identical/shuffled complete inventories, unchanged diff, empty Changes BOM. | AC11, AC19 |
| D02 | W3 | F1 duplicates and canonical X→W/Y→Z under both input permutations. | AC11, AC12 |
| D03 | W0/W3 | EFT compact positions remain order-only, no fictitious purchase/replacement. | AC6, AC11 |
| D04 | W3 | Recorded slot replacement versus order-only and different hull. | AC11, AC13 |
| D05 | W3 | F2 cargo reuse and H/H2 quantity oracles, configuration preserved. | AC12, AC19 |
| D06 | W3/W4 | Drone/fighter explicit quantities and deployment separate; loaded units unknown. | AC12, AC20 |
| D07 | W0/W3 | Complete empty, unknown and unresolved source distinctions; qualified Changes. | AC6, AC13, AC19 |
| D08 | W4 | F3 EM/Omni/M5 profile, exact layer EHP and pp deltas. | AC14, AC15 |
| D09 | W4 | One known/all-V context across pilot/victim/reference columns. | AC14 |
| D10 | W4 | Weapon-only volley, split theoretical DPS and unknown-charge coverage. | AC16, AC18 |
| D11 | W4 | F4 cap/tank transitions, zero/nonfinite denominator handling. | AC17, AC18 |
| D12 | W2/W4 | Known constraint excess inspectable; unknown module suppresses confident uplift. | AC18 |
| D13 | W5 | F2 price coverage; adjusted-only/missing/zero/stale/exact-24h cases. | AC19, AC22 |
| D14 | W5 | Eligible/disjoint cache versus empty/other-character/other-ship/ambiguous stock. | AC21 |
| D15 | W2 | Complete/omitted groups, versions, type/slot/count/origin errors, over-budget warning. | AC9, AC10, AC18 |
| D16 | W0/W2 | Deep immutable snapshot round trips, legacy report, name-stable fingerprint. | AC4, AC6, AC10 |
| P01 | W1 | Independent actual snapshots through reload/re-analysis; unchanged evidence/editor. | AC3, AC10 |
| P02 | W2 | F-old prepared, F-new attached during AI; report binding and staleness correct. | AC4, AC8 |
| P03 | W1 | Reversed independent-field completion, retained victim ownership and all sources. | AC3, AC8 |
| P04 | W1/W6 | Duplicate/CAS conflict, two scopes/connections, navigation/disposal. | AC8, AC30 |
| P05 | W0/W1 | Own loss/win/unknown/reference selection and truthful dedup/fallback. | AC2, AC6 |
| P06 | W1/W2 | Saved row edited after copy; stable snapshot and origin across alternatives. | AC3, AC5 |
| P07 | W4 | Every content/context revision invalidates; late old result rejected. | AC14, AC18 |
| P08 | W1/W6 | Strict proposal rejection/cancel/SQL failure retains prior candidate. | AC7, AC9 |
| P09 | W1 | Auth/ship/page/empty capture paths with real mapper and commit. | AC6, AC7 |
| P10 | W4/W5/W6 | Offline/local-SDE and independent optional failures preserve available content. | AC18, AC23 |
| P11 | W1/W5 | Encounter P versus active Q for capture and cache ownership. | AC2, AC21 |
| P12 | W5 | Cache-only render; explicit price-only refresh, no asset/order sync. | AC22, AC23 |
| P13 | W2 | Legacy/optional generated contract; client provenance/origin; no generated stats/facts. | AC9, AC10 |
| P14 | W2/W4 | Same-score replacement/re-analysis and changed revision with preserved history. | AC4, AC8, AC14 |
| U01 | W6 | Real pre-analysis entry and report Fits tab, no view-triggered AI. | AC1, AC2 |
| U02 | W6 | 719/720, 999/1000, 1439/1440 usable widths and stable selection. | AC24 |
| U03 | W6 | 320px/200%, keyboard/touch, no horizontal page overflow. | AC24, AC27 |
| U04 | W6 | F5 role/confidence/time/legacy headers and source dedup. | AC2, AC4, AC25 |
| U05 | W6 | All eight groups, offline/charges/unresolved entries, icon/name fallback. | AC6, AC25, AC26 |
| U06 | W6 | Non-color badges, Show all/Changes only and no-change state. | AC11, AC12, AC27 |
| U07 | W6 | F3/F4 aligned/stacked stat tradeoffs, no overall winner. | AC15, AC16, AC17, AC28 |
| U08 | W6 | Scoped source/SDE loading/error/retry, partial and current-key numbers. | AC18, AC23, AC28 |
| U09 | W6 | F2 and known-loss/hull-change BOM modes, counts and price coverage. | AC19, AC20, AC22, AC29 |
| U10 | W6 | Asset freshness/eligibility and quantified versus generic cargo. | AC20, AC21, AC29 |
| U11 | W1/W6 | Capture/proposal exact success after real commit, reload and duplicates. | AC3, AC7, AC30 |
| U12 | W1/W6 | Auth/ship/network/import/cancel/save failures and recoverable dialog. | AC7, AC30 |
| U13 | W2/W6 | Legacy/invalid candidates, alternatives/reference, original-baseline warning. | AC5, AC9, AC10, AC30 |
| U14 | W5/W6 | Price refresh feedback with/without cache and independent icon failure. | AC22, AC23, AC30 |
| U15 | W1/W6 | Actual evidence/checklist/editor unchanged after every comparison interaction. | AC3, AC10, AC30 |
| U16 | W2/W6 | Same-score stale advice, retained generation fit and safe late completion. | AC4, AC8, AC25, AC30 |

### 9.4 Acceptance-criterion traceability

| Product AC | Primary units | Verification cases |
| --- | --- | --- |
| AC1 — Reachability | W6 | U01 |
| AC2 — Roles and identity | W0/W1/W5/W6 | P05, P11, U01, U04 |
| AC3 — Independent persistence | W1/W2/W6 | P01, P03, P06, U11, U15 |
| AC4 — Historical baseline | W0/W2/W4/W6 | D16, P02, P14, U04, U16 |
| AC5 — Selection semantics | W1/W2/W6 | P06, U13 |
| AC6 — Completeness | W0/W1/W2/W3/W6 | D03, D07, D16, P05, P09, U05 |
| AC7 — Capture/import failure | W1/W6 | P08, P09, U11, U12 |
| AC8 — Concurrency | W1/W2/W4/W6 | P02, P03, P04, P14, U16 |
| AC9 — Proposal validation | W1/W2/W6 | D15, P08, P13, U13 |
| AC10 — Compatibility | W0/W1/W2/W6 | D15, D16, P01, P13, U13, U15 |
| AC11 — Stable diffs | W0/W3/W6 | D01, D02, D03, D04, U06 |
| AC12 — Configuration and quantities | W3/W4/W6 | D02, D05, D06, U06 |
| AC13 — Hull and incomplete diffs | W0/W3 | D04, D07 |
| AC14 — Common context | W2/W4 | D08, D09, P07, P14 |
| AC15 — Defense math | W4/W6 | D08, U07 |
| AC16 — Offense and mobility | W4/W6 | D10, U07 |
| AC17 — Cap and tank limits | W4/W6 | D11, U07 |
| AC18 — Partial/invalid stats | W2/W4/W5/W6 | D10, D11, D12, D15, P07, P10, U08 |
| AC19 — BOM arithmetic | W0/W3/W5/W6 | D01, D05, D07, D13, U09 |
| AC20 — Cargo and loaded charges | W3/W4/W6 | D06, U09, U10 |
| AC21 — Asset claims | W1/W5/W6 | D14, P11, U10 |
| AC22 — Prices | W5/W6 | D13, P12, U09, U14 |
| AC23 — Independent optional data | W4/W5/W6 | P10, P12, U08, U14 |
| AC24 — Responsive layout | W6 | U02, U03 |
| AC25 — Identity headers | W2/W6 | U04, U05, U16 |
| AC26 — Complete module presentation | W6 | U05 |
| AC27 — Accessible diffs | W6 | U03, U06 |
| AC28 — Stat readability | W6 | U07, U08 |
| AC29 — Actionable BOM | W6 | U09, U10 |
| AC30 — Feedback and isolation | W1/W2/W5/W6 | P04, U11, U12, U13, U14, U15, U16 |

### 9.5 Workflow and release evidence

| Product workflow | Integration spine |
| --- | --- |
| S1 — Compare the fight fit with the current snapshot | P01/P02/P09/P14, U01/U04/U11/U16 |
| S2 — Evaluate AI advice as a concrete proposed fit | D15, P13, U07/U13 |
| S3 — Compare a saved doctrine or imported proposal | P06/P08, U11/U12/U13/U15 |
| S4 — Inspect the killmail victim fit after a win or loss | P05/P11, U04/U05 |
| S5 — Plan changes or replace a destroyed fit | D05/D13/D14, P12, U09/U10/U14 |
| S6 — Review incomplete or offline evidence | D07/D10/D11, P10, U05/U08/U14 |

The two traceability tables preserve Product's case-to-AC mappings in both directions.
W7 attaches passing receipts for **each AC1–AC30**, not just a total test count.
No domain-only test or screenshot substitutes for actual persistence/navigation.

Required gates after implementation include focused snapshot/diff/BOM/derivation,
report/prompt, provider/repository, real-screen and prior attachment tests, plus:

```bash
flutter test test/features/combat_analyzer
flutter test test/features/fitting
flutter test test/features/assets
flutter test test/features/market
flutter analyze
```

Run the full `flutter test` suite because shared models/engine/serialization change;
report unrelated baseline failures explicitly. Format/check changed Dart files and
run code generation for Freezed additions. Coverage target is ≥80% of new logic and
100% of critical isolation, quantity, validation and race branches, with exclusions
documented. Independent tester verifies desktop and narrow/text-scaled renderings,
keyboard/touch semantics, new/legacy report round trips, same-score history, and
optional-data isolation. Record real two-connection evidence for multiwindow claims.

Use shared feature-tagged logging for future code: `[AAR.COMPARE]`, `[AAR.COMPARE.DIFF]`,
`[AAR.COMPARE.BOM]` and existing repository/network tags. Log source keys/counts,
context revisions, mutation outcomes and errors/stacks; no raw EFT, tokens, full
asset dumps or generated payload dumps. Persist durable findings in the engineering
journal with the implementation commits.

## 10. Non-goals and handoff boundaries

- No applying proposals to the active editor/EVE, purchases, sales, asset movement,
  doctrine discovery, compliance certification or automatic evidence promotion.
- No reconstructing old report inventories from today's attachment or score, mandatory
  report regeneration, new history browser, or exact historical engine/SDE replay.
- No inference of attacker modules from hull correlation or actual opponent skills
  from a common hypothetical comparison context.
- No new application/tracking/range/heat/reload simulation, finite injector inventory
  budget, sustained active-tank model, or comprehensive fitting-legality guarantee.
- No station/region executable quotes, adjusted-price purchase fallback, fresh-ownership
  guarantee, removed-item resale credit or destroyed-baseline stock credit.
- No global strict-parser behavior change, evidence score adjustment, altered M5 math,
  or mutable fitting editor embedded for read-only preview.

This document delivery changes no application code and runs no runtime suites. Plan
and Test-Author take the specified units to RED/GREEN; keep the
[queued initiative](../engineering-journal/QUEUED.md#fit-comparison-visuals-for-aar-reports)
open until implementation, independent verification and signoff satisfy Product.
