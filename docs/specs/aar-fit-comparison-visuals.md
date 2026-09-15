# AAR fit comparison visuals — Product specification

**Priority:** P2

**Status:** Product specification complete; implementation and verification pending.

**Date:** 2026-09-15

**Grounding:** `develop` at `d1114f7`, after Milestone 5 and the fit import/capture UI work shipped.

**Audience:** Plan, Test-Author, implementation, review and QA.

## 1. Product perspective and scope

### 1.1 Problem

After an engagement, a pilot needs to connect advice to equipment: what they flew,
what they fly now, what the killmail records, and what a proposed change would do.
The AAR currently presents fit inventories, derived statistics and fitting advice
as separate sections. The pilot has to remember module lists, infer replacements,
and mentally compare figures calculated for different purposes. Prose such as
“improve the tank” is particularly hard to turn into an equipment decision.

Putting four pictures next to each other is insufficient. A current snapshot may
postdate the fight, a victim fit may belong to the pilot or an opponent, a killmail
may omit information, and a recommendation may name a class rather than an exact
module. A visually confident comparison can otherwise convert uncertain evidence
into an apparently verified fit or shopping list.

**Governing principle:** Every fit, difference, statistic and material requirement
must identify its source and comparison baseline. Actual evidence and proposals
remain distinct. Derived comparisons use the same declared assumptions.

### 1.2 Outcome and release scope

The pilot can answer:

1. “What changed between the fit used for this report and my current snapshot?”
2. “Which modules and quantities does this proposal change?”
3. “Under the same skills and incoming damage profile, what improves and what gets worse?”
4. “What does the victim fit actually show, and what remains unknown?”
5. “What is the estimated value of the added equipment or a full replacement,
   and which items appear in my cached assets?”

This initiative includes a read-only comparison workspace, durable source
snapshots, deterministic diffs and statistics, structured proposal support,
user-selected saved/EFT reference fits, and a bill of materials (BOM). It includes
the data-contract work needed to make these visuals truthful. Existing reports
remain usable without regeneration.

Release success is demonstrated by the acceptance criteria and scenario matrix in
§8–§9. No improvement in fight outcomes, application accuracy or market purchase
price is claimed by this feature.

### 1.3 Current capabilities and required additions

| Seam at the grounding commit | Existing behavior | Product consequence |
|---|---|---|
| [AnalysisMultiPaneScreen](../../lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart) | Post-analysis Fits tab lists pilot/victim equipment, derived panels and prose advice; evidence controls also exist before analysis. | Build one comparison workspace with access before and after analysis. Preserve advice and evidence actions. |
| [CombatEnrichment](../../lib/features/combat_analyzer/domain/combat_enrichment.dart) and [enrichment service](../../lib/features/combat_analyzer/data/combat_enrichment_service.dart) | A single `pilotFitEvidence` field holds either manual import or current capture; victim evidence has a separate packet. | Current-for-comparison needs separate storage. Calling the existing unconfirmed capture path would replace pilot evidence. |
| [AarDerivationBundle / AarFitDerivation](../../lib/features/combat_analyzer/domain/aar_fit_derivation.dart) | Self/opponent stats, coverage and assumptions; `aarFitSnapshotProvider` returns derivations. `baseline` in a derivation means bare hull. | These are not persisted inventories. No `AarFitSnapshot` domain class exists today. Introduce source snapshots; distinguish the comparison baseline from bare-hull stats. |
| [CombatAarReport](../../lib/features/combat_analyzer/domain/combat_aar_report.dart) | Report v3; `evidenceAtGeneration` stores evidence score/dimensions, not the fit. `fitAdvice` contains prose and item/class strings. | Store the fit used at generation for new reports. Add optional structured candidates; legacy strings cannot establish an exact fit. |
| [Fitting models](../../lib/features/fitting/domain/models.dart), [editor](../../lib/features/fitting/presentation/widgets/fitting_editor.dart), [stats panel](../../lib/features/fitting/presentation/widgets/stats_panel.dart) | Reusable vocabulary and models, but editor/panel are bound to mutable active-fitting providers. Occupied slots lack a completeness marker. | Reuse visual primitives in parameterized read-only widgets. Add provenance/completeness around inventories. |
| [CombatFitDeriver](../../lib/features/combat_analyzer/domain/combat_fit_deriver.dart), [DogmaEngine](../../lib/features/fitting/domain/dogma_engine.dart), [stats inputs](../../lib/features/fitting/data/fitting_stats_inputs.dart) | Local deterministic calculation supports many requested metrics, with material limits in §5. | Use a shared calculation context. Show unavailable metrics explicitly; AI cannot supply them. |
| [Market providers](../../lib/features/market/data/market_providers.dart), [asset repository](../../lib/features/assets/data/asset_repository.dart) | Cached ESI average/adjusted prices with timestamps; character-scoped cached assets without freshness/completeness metadata. | BOM values are estimates and cached ownership is qualified. Default stat cost fields do not represent prices. |

Related contracts remain authoritative for their existing behavior:
[fit evidence attachment and UI tests](aar-fit-import-capture-ui-tests.md),
[attachment technical design](aar-fit-import-capture-ui-tests-design.md),
[fit simulation design](aar-fit-simulation-and-defense-profiles-design.md), and
[per-attacker matchup](aar-per-attacker-matchup.md). This specification adds
comparison behavior without relabeling those historical milestones as pending.

## 2. User stories and operational workflows

### S1 — Compare the fight fit with the current snapshot

**Story:** As a pilot reviewing a completed fight, I want to see what I changed
since the fit used in the report, so I can evaluate my adjustments.

Open Fits → baseline is **Fit used for this report** when recorded → choose
**Capture current for comparison** → current snapshot appears beside the baseline
with capture time, pilot and hull → inspect changes and common-context stat deltas.

Capture is explicit and character-scoped. It does not certify that this was the
fight fit or replace attached evidence. If the current hull differs, the UI says
**Different hulls** and compares group inventories and stats without pretending
that slot 1 on one hull replaces slot 1 on the other. Recapture replaces only the
current comparison snapshot after a successful save. A failed capture retains the
previous snapshot. Changing the active app character does not retarget the AAR.

### S2 — Evaluate AI advice as a concrete proposed fit

**Story:** As a pilot receiving fitting advice, I want to see the exact proposed
equipment, tradeoffs and materials before acting on it.

Choose an advice card with a validated structured candidate → Proposed column
shows its source, rationale, confidence and baseline → inspect added/removed/configuration
badges, stat deltas and BOM → switch between alternative candidates without
merging their changes. A proposal can increase EHP while reducing DPS or speed;
the UI displays both effects without declaring an overall winner.

Advice containing only “use a better tank” or class names remains readable prose.
Show **No structured proposed fit** with actions to select a saved reference or
import a proposed EFT fit. Do not derive exact modules, quantities or prices from
that prose. A candidate targeting an older baseline is labeled **Based on an
earlier fit**; viewing it against another baseline does not rewrite its origin.

### S3 — Compare a saved doctrine or imported proposal

**Story:** As a pilot following a doctrine, I want to compare a specific saved or
imported fit against my fight fit without changing my active fitting editor.

Choose **Select saved fit** or **Import proposed fit** → copy that fit into a
proposal snapshot → label it **Saved reference** or **Imported proposal**, with
the user-provided name → inspect the comparison and materials. Shared and
character-owned saved fits retain their reference provenance. Later edits to the
original saved fit do not silently change the snapshot. A saved fit is not deemed
an authoritative doctrine unless explicitly identified as such by its source.

Import uses the strict AAR import validation contract in a proposal-specific flow.
Cancel/error leaves the last candidate intact. It never writes pilot fit evidence
or triggers analysis. An unresolvable structured AI candidate can retain advice,
but is not treated as a successfully validated imported fit.

### S4 — Inspect the killmail victim fit after a win or loss

**Story:** As a pilot, I want to distinguish what the killmail establishes about
the victim from my own fit and from any recommended fit.

In a win, show the identified victim as an opponent. Compare its recorded loadout
with the pilot baseline under the same hypothetical skill/profile assumptions.
These are fit comparisons, not a claim that the victim had the pilot's skills or
that a simulated duel predicts the result. In an own loss, the victim is the pilot;
the victim source may also supply the fight-fit fallback. Dedupe that identical
source by default and expose its dual role in a source chip/selector.

No attacker fit is inferred from a correlated ship name. Unknown victim identity
is displayed as unknown, never assigned to the pilot by elimination. A selected
killmail fit, victim identity and provenance always stay together.

### S5 — Plan changes or replace a destroyed fit

**Story:** As a pilot preparing to fly again, I want a materials list that makes
clear whether I am changing a surviving fit or replacing a lost ship.

Choose the proposed fit → inspect BOM mode: **Changes from baseline** or
**Full replacement** → review exact item quantities, configuration-only changes,
unquantified cargo advice and estimated values → optionally inspect eligible
cached assets for the encounter pilot. Default to Full replacement after a known
own loss or a hull change. The destroyed baseline is never credited as ownership.
Removal values are not subtracted as guaranteed resale income.

### S6 — Review incomplete or offline evidence

**Story:** As a pilot with a hull-only or partially resolved fit, or without a
network connection, I want to learn what the available data supports.

Open comparison using stored snapshots and local SDE → names and icons degrade
independently → missing groups, unresolved occupied modules and unknown charges
are visible → supported calculations are marked partial or unavailable → cached
prices show their age; absent prices and uncertain asset availability remain
unknown. An unavailable optional source never hides the columns that work.

## 3. Source model, evidence and lifecycle invariants

### 3.1 Four source roles

| Role | Eligible source | Label and limits |
|---|---|---|
| Fight fit | Immutable fit used for report generation; otherwise current attached pilot evidence eligible as historical evidence; otherwise identified own-loss victim fallback. | Source/confidence shown. A manual fit confirmed by the user is not an observed historical ESI snapshot. |
| Current snapshot | Explicit current capture for comparison, persisted independently. | **Current snapshot — captured …**; freshness is a timestamp, not a live guarantee. Never automatically confirmed as the fight fit. |
| Killmail victim | Recorded victim fit with selected killmail and victim identity. | **Victim: name**, hull, killmail/source and inference limitations. May be the pilot in a loss. |
| Proposed/reference | Validated structured AI candidate, copied saved fit, or strict imported EFT proposal. | **AI proposal**, **Saved reference**, or **Imported proposal**. Never evidence of equipment flown. |

For a new report with no historical fit, show **Fight fit not recorded**. A
reference-confidence `pilotFitEvidence` can be inspected as **Pilot reference fit**
and, when applicable, **Reference used for this report**. Do not promote it to a
confirmed fight fit. Keep the existing derivation precedence intact outside this
workspace; add truthful role labels and explicit baseline selection here.

### 3.2 Required snapshot contract

Introduce an immutable comparison snapshot envelope; `AarFitSnapshot` is a
suggested new name, not an existing class to reuse. Plan owns final storage and
type names. The product contract requires:

- Snapshot ID, stable content fingerprint and encounter association.
- Full copied `Fitting` inventory, hull, module state, charge identities and
  explicit drone/fighter/cargo quantities. Copy embedded collections as well.
- Source kind; subject character/role when known; source fit, report or killmail
  reference; provenance/confidence; captured/imported time and any known evidence
  time as separate concepts. Unknown times stay unknown.
- Group and inventory completeness: **recorded complete**, **partial**, or
  **unknown**; slot positions **recorded** or **order only**; unresolved occupied
  entries; known versus unknown charge quantities. Do not infer completeness
  merely because a list is empty or parsing succeeded.
- For proposals: candidate ID, original baseline snapshot/fingerprint, origin,
  rationale/confidence/limitations, validation state and schema version.
- For report generation: immutable fit snapshot references/content and the
  calculation context used with that report. The generation record must be
  durable, not a pointer to a mutable enrichment field.

The fingerprint covers quantities, charge identity, module state, source subject
and completeness metadata relevant to the comparison, not only hull/module IDs.
Changing a display name resolution must not count as an equipment change.

### 3.3 Baseline and report history

1. Default baseline: recorded fit used for this report. Before analysis or for a
   legacy report without that snapshot, use currently attached historical pilot
   fit or identified own-loss victim fallback, with the legacy notice below when
   applicable. If none exists, request a baseline selection and keep available
   inventories viewable.
2. Expose **Currently attached fight fit** separately when it differs from the
   report snapshot. For legacy reports show **Fit used at generation not recorded**;
   never reconstruct it from today's attachment or evidence score.
3. All visible delta badges and BOM headings name the selected baseline. A user
   can compare any available source as baseline, but a victim baseline keeps its
   victim identity. Changing baseline does not change the original candidate target.
4. Store source content at generation for new reports and mark advice stale when
   attachment content changes, even if the numerical evidence score is unchanged.
   Keep the old advice visible and offer the existing explicit re-analysis action.
5. Recalculate visual statistics under the currently selected common context and
   label them as such. They do not rewrite the historical prose or claim to be
   the historical numerical result when SDE or skill inputs have changed.
6. Duplicate columns referring to the same snapshot are collapsed by default;
   identical loadouts from different sources are not silently merged.

No new report-history browser is required. Explicit re-analysis may replace the
currently stored report under the existing retention policy. Its input snapshot
must remain immutable for that report's lifetime, including any older report the
application retains; replacing a report must bind the replacement to its own input.

### 3.4 Persistence and asynchronous safety

Comparison capture and proposal selection write only their owned fields. Viewing,
selecting a baseline, deriving stats, refreshing prices or choosing a proposal
does not change the evidence score/checklist, combat attribution, victim packet,
attached pilot evidence, saved fit, active editor or AI report.

Existing import/confirmed-capture evidence actions remain explicit and retain
their current contract. Any later promotion of a reference to historical evidence
must use that evidence workflow; this initiative adds no implicit promotion.

Extend every enrichment serializer, constructor/copy, refresh and merge path so
comparison snapshots survive re-analysis and concurrent attachment. Follow the
existing atomic load → precondition → transform → save pattern. Complete network,
parsing and operation waits before the local transaction. Publish only committed
changes; stale results cannot overwrite a newer source or another encounter.
Report generation must bind its snapshot to the actual prepared input, not a
later attachment read after the AI response.

On capture/import failure preserve the last committed snapshot. On navigation or
disposal, a committed save can remain durable, but there must be no stale snackbar,
cross-encounter state update or exception. Scope assets and capture to the AAR
character; authentication is required for capture, not for reading stored fits.

## 4. Visual presentation and deterministic differences

### 4.1 Placement and responsive layout

The post-analysis **Fits** tab contains the comparison workspace, with existing
fitting advice and evidence controls accessible beneath it or through clearly
labeled sections. Provide **Compare fits** before analysis when an encounter is
selected; rendering known fits must not require an AI call or a minimum evidence
score. Keep damage matchups in their existing Damage tab and link to the shared
incoming-profile choice when relevant.

The following widths refer to the workspace's usable content width, not the window
width. The sidebar must not cause incorrect column-count selection.

| Available width at normal text size | Layout |
|---|---|
| ≥1440 logical pixels | Four equal columns: Fight, Current, Victim, Proposed, subject to source deduplication. |
| 1000–1439 | Baseline plus two chosen comparison columns; source picker exposes remaining roles. |
| 720–999 | Baseline plus one chosen comparison column. |
| <720 | Baseline summary remains visible above candidate tabs; stack the selected baseline and candidate groups/stat rows vertically. |

Preserve selection, expansion and scroll intent during resizing. At enlarged text
sizes, reduce column count/stack further to avoid clipping. A 320-pixel viewport
with 200% text must remain usable without horizontal page scrolling. Source
selection cannot be reachable only by swiping or hovering. Show missing roles as
actionable source states in the picker, not invented populated fits.

### 4.2 Column and module content

Each column header shows role, pilot/victim name when known, hull name, source
badge, confidence or reference/proposal status, timestamp, and any partial/stale
warning. Hull names use `itemNameProvider` with local SDE/stored-name fallback;
never expose numeric IDs or `Type #…` placeholder strings as names. Unknown names
read **Unknown ship** or **Unresolved module** while retaining the inventory entry.

Group inventory as **High**, **Mid**, **Low**, **Rigs**, **Subsystems** where
applicable, **Drones**, **Fighters** and **Cargo**. Cargo is distinct from fitted
modules and deployed drones/fighters. Do not drop subsystems or fighters because
the current fitting wheel lacks those groups.

Module rows use `EveTypeIcon`, resolved text, quantity where relevant, charge and
module-state indicators. The same detail is available via tooltip, keyboard focus
and tap/expanded details: full name, group, recorded slot if known, state, charge,
quantity, source, change reason and limitations. Offline modules remain visible.
Icon loading/failure uses a stable-size placeholder and never hides the row.

Show groups across columns in the same order with synchronized expansion and stat
row alignment where space permits. Distinguish:

- **Empty**: known slot/group recorded empty within a complete source.
- **Not recorded**: incomplete or absent inventory data.
- **Unresolved**: an occupied entry exists, but its exact SDE type cannot resolve.
- **Not applicable**: group is unsupported by known hull metadata.

Do not infer that subsystems are inapplicable from today's derivation coverage
field, which does not supply their capacity. Hull-only fits retain their hull and
limitations; a legacy empty killmail item list is unknown unless completeness was
recorded separately.

### 4.3 Diff contract

All changes describe **selected candidate relative to selected baseline**.
Use text/icon badges plus color: **Added** (green), **Removed** (red),
**Modified** (amber), **Unchanged** (neutral). Color is supplementary. No automatic
“best fit” or “upgrade” judgment follows from price, meta level or a larger number.
A source can recommend an upgrade, but the objective badge remains Modified or
Added/Removed and the rationale names the metric/tradeoff.

Deterministic matching order within each group:

1. Match identical type, charge and state occurrences first, regardless of list
   ordering. Cancel duplicate occurrences one-for-one before finding additions.
2. Match remaining occurrences of the same type as configuration changes, with
   explicit old/new charge, state or quantity details. First pair recorded equal
   physical slots when both sources support that meaning. For the rest, sort each
   side by charge type ID (unknown first), module-state enum order, then recorded
   slot index where available; pair in that canonical order. Identical remaining
   occurrences are interchangeable. Never use input-list order as the tie-break.
   This pairing explains inventory configuration differences, not an inferred move
   between unknown physical slots.
3. Pair different types as a replacement only when both sources preserve the
   same physical slot on the same hull, or a validated proposal explicitly names
   that replacement. Otherwise show Added/Removed without inventing a pairing.
4. Use stable type/name/source ordering for remaining rows. Recorded slot moves
   may appear in details, but moving an unchanged module is not a purchase.

EFT parser indices may compact occupied slots; they are **order only**, not proof
of physical slot identity. Different hulls do not have slot-to-slot replacements.
Across-group moves remain visible in group diffs; BOM reconciles physical item
counts across groups. Unknown source completeness changes the wording to
**Present only in this record**/**Absent from supplied record**, not a verified
historical addition/removal. Unresolved occupied entries cannot become empty slots.

Drone, fighter and cargo quantities compare by exact type; deployment/bay changes
are configuration details. Loaded charge identity changes are visible, but a
missing charge quantity is never interpreted as one round or one full clip.
Provide **Show all** (default) and **Changes only**; unchanged groups collapse to a
count in Changes only, and **No recorded equipment changes** is an explicit state.

## 5. Tactical statistics and shared assumptions

### 5.1 Fair calculation context

Every column in a comparison uses one explicit context:

- **Skills:** encounter pilot's usable locally cached skill context for all
  columns; if unavailable, All V for all with **Assumes All V**. Allow an explicit
  All V comparison option. Do not combine one fit at All V with another at known
  skills. Partial skill data must expose the deriver's limitations. Opponent
  columns say **Modeled with comparison skills; opponent skills unknown**.
- **Incoming profile:** default **Omni (25% each)**. Allow eligible resolved
  Confirmed/Probable per-attacker profiles from Milestone 5, preserving confidence,
  coverage and conditional-profile warnings. Apply the identical normalized
  profile to every defense column. A multi-attacker aggregate, if selected, is
  explicitly **Aggregate blend** with its existing advisory. Never substitute
  the victim's incoming/outgoing profile implicitly.
- **State assumptions:** recorded module states/charges and explicit drone/fighter
  quantities, with disclosure of engine limits. Only offline modules are currently
  excluded; online/active/overloaded labels do not prove different activation or
  heat simulation. Missing historical state is assumed, not observed.
- **Calculation inputs:** one SDE/effect-data revision and calculator revision,
  source fingerprints, common skill fingerprint and profile. Use the local AAR
  stats-input path (`EffectLookupPolicy.localOnly`) and isolate calculation from
  the mutable global fitting editor.

Cache by content and calculation context. A changed fit, quantity, charge, state,
skill basis, profile or SDE input invalidates affected results. Do not flash old
numbers under a new fit header while a calculation completes.

### 5.2 Required stat rows and truthful labels

| Section | Rows | Meaning and limitations |
|---|---|---|
| Defense | Shield/armor/hull HP, each layer's EHP, total EHP; EM/Thermal/Kinetic/Explosive resists per layer | EHP uses the shared selected profile. Resists remain intrinsic per-layer values. Show missing layer/input as unavailable, not zero. |
| Offense | Turret, missile, drone, fighter and total DPS; **Weapon volley** | Theoretical output. Volley covers loaded turrets/launchers only. No applied tracking, range, signature, missile flight or actual combat DPS claim. |
| Mobility | Maximum speed, align time, signature radius | Modeled fit values under stated module assumptions, not observed movement. Lower signature/align can be desirable; greater speed is not a universal winner. |
| Capacitor | Capacity, modeled stability level or time to depletion, relevant limits | Stable percentage and depletion seconds are different units. Finite simulation and injector limitations must be visible. |
| Tank | Shield/armor/hull **Burst repair HP/s**, **Peak passive shield HP/s**, **Sustained repair: Not modeled** | Current `effective…Repair/Boost` fields are raw burst HP/s, not EHP/s. Burst excludes reload/resource endurance. Peak passive recharge is not constant regeneration. |
| Fitting constraints | CPU, powergrid, calibration and known drone/fighter capacity limits | Mark modeled over-capacity conditions. These checks do not certify every skill, module restriction or game fitting rule. |

Known limitations required near the relevant row or accessible details:

- Unloaded weapons can calculate zero. If charges were not recorded, label offense
  incomplete; do not conclude that the pilot dealt no damage.
- Drone/fighter DPS depends on modeled quantities/deployment and engine capacity
  limits; it does not prove which units were deployed during the fight.
- Cap simulation has a 3600-second horizon and injectors currently assume infinite
  clips. Display **Modeled stable** with these qualifications where applicable;
  never promise indefinite stability with the shown cargo supply.
- Sustained active repair is unavailable in the current engine. Shipping a visible
  **Not modeled** row satisfies this release; adding a new sustained-tank simulator
  is a separate product/engineering decision.

### 5.3 Delta arithmetic and confidence

For layer HP `H`, normalized damage fractions `p[t]` and resist fractions `r[t]`:
`EHP = H / sum(p[t] * (1 - r[t]))`; total EHP is the sum of the modeled layers.
Use the same profile for baseline and candidates. The existing domain calculation
is authoritative; do not build a second formula in a widget.

Display candidate minus baseline in native units; optionally percentage change
only when baseline is finite and strictly positive. Resist changes are percentage
**points**: 50% → 60% = **+10 pp**, not “+10%.” A cap transition reads
**Depleting → Modeled stable**, not seconds subtracted from a stability percentage.
Zero/nonfinite denominators yield a meaningful unavailable/unbounded label and no
NaN/infinity percentage badge. Round only at presentation; no rounded-value math.

Unknown/unresolved contributing equipment marks affected metrics partial. Known
portions may be displayed with their coverage, but suppress confident improvement
badges for incomplete comparisons. Do not assume which metrics an entirely unknown
module cannot affect. All tactical numbers come from deterministic local inputs;
AI narrative cannot supply missing stats. Changes in evidence confidence do not
make theoretical metrics observed measurements.

## 6. Bill of materials and price/inventory semantics

### 6.1 Two explicit modes

The selected proposal has one BOM card with a named target and selected baseline.
It remains usable without asset or price data.

| Mode | Required items | Default |
|---|---|---|
| **Changes from baseline** | Positive target-minus-baseline physical item counts. Removals and configuration changes listed separately. | Same-hull comparison when an own loss is not established. Heading says this is a change list, not proof that the baseline items are owned. |
| **Full replacement** | Every target physical item, including one hull. No credit for the baseline. | Known own loss or different hull. User can switch to Changes to understand edits, without converting lost items into ownership. |

Count exact type IDs: one hull; each module occurrence including offline; explicit
drone/fighter/cargo quantities. Aggregate physical counts across slots and cargo
before subtraction, so moving a spare module from cargo to a slot does not buy a
second module. Equal-type equipment is fungible for this count only; diff details
still preserve location/state. Across different hulls, Changes still computes an
informational net type-count diff, including the new hull and removed old hull.
Subtracting common modules describes inventory differences, not proof of ownership
or physical reuse. Full replacement always counts every target item.

If baseline inventory is incomplete/unresolved, Changes is **Incomplete change
list**: qualify affected lines as **Not present in baseline record**, with their
change quantity and shortfall unknown where omitted entries could change the
answer. Do not treat unrecorded baseline groups as zero. Exact unaffected groups
may retain known deltas only when cross-group item accounting remains provable.
Full replacement can still give exact counts for a complete target independently
of baseline completeness. Partial target inventory makes both modes incomplete.

Loaded charges are configuration identities with unknown quantity in today's
`FittedModule`. Show them under **Charge quantity not recorded** and exclude their
unknown units from exact totals. Explicit cargo ammunition quantities remain
countable. Do not invent clip sizes, hidden reserves, or quantities for prose
cargo recommendations. Any future known loaded quantities must be distinguished
from cargo units to avoid double counting.

Generic cargo suggestions remain in an **Unquantified recommendations** list.
Quantified cargo requires resolved type, positive integer quantity and source.
An invalid/partial proposal is visibly incomplete and cannot produce a complete
materials or improvement claim; resolved lines may still be inspected.

### 6.2 Cached assets and “missing” items

Inventory is optional, scoped to the encounter pilot and user-selected locations.
Read character-scoped repository data; do not use the active-character global
`assetsProvider`. Report **Observed in cached assets**, **Not found in cached
assets**, or **Availability unknown**. The asset cache currently has no stored
sync timestamp or completeness marker, so always disclose **Asset freshness
unknown**. Never equate an empty cache with verified zero ownership.

Distinguish loose stock whose location/availability can be established from items
fitted to another ship, remote/unknown containment, or ambiguous entries. Only
unambiguously eligible loose stock may be credited in a separate **Estimated
shortfall against cached spares** column. Baseline equipment and loose-stock credit
must be disjoint. When eligibility cannot be established, shortfall is **Unknown**;
an observed count elsewhere is informational and not a spare. A shortfall of zero
means only covered by eligible cached stock, not “ready to fit here.”

For valid eligible cache inputs, `shortfall[type] = max(0, required[type] -
eligibleLooseStock[type])`. Do not subtract the destroyed fit, credit a victim's
inventory to the pilot, or merge other characters' assets. No implicit inventory
sync or asset mutation occurs on view, source capture or proposal selection.

### 6.3 Estimated values

Use cached `MarketPrices.averagePrice` through the market price providers and
label it **ESI average price estimate**, with **Cache refreshed at …** from
`lastUpdated`. That is local cache age, not an exchange quote's observation time.
This is not a station/region quote or executable buy order. `adjustedPrice` is not a fallback
purchase price. Dogma's default zero cost fields are not a free fit.

The BOM shows quantity × unit estimate per priced line and gross required-item
estimate for the selected mode. No removed-item resale credit, insurance, taxes,
transport cost or guaranteed salvage recovery is applied. An optional estimated
shortfall value is separate, labeled, and only uses eligible known shortfalls.

If any line has no usable nonnegative finite average price, show **Price
unavailable** and a **Priced subtotal** with priced-line coverage and excluded
unknown quantities/lines. Do not label a partial subtotal “Total cost.” A stored
valid zero quote must be labeled **0 ISK estimate**, never “free”; absent/default
values remain unknown. Quotes older than 24 hours are **Stale estimate**, measured
against an injected clock; retain them with their age. Exactly 24 hours is stale.

An explicit **Refresh prices** action may invoke the price-only market sync.
Do not invoke the combined market sync that also fetches active-character orders.
Loading/failure leaves the cached estimate visible with status; offline, missing
prices or missing authentication must not block local inventory/stat comparison.
Use the app's ISK formatting. Icons, prices and local SDE calculations fail
independently rather than replacing the entire workspace with an error.

## 7. Proposal contract, evidence ledger and feedback

### 7.1 Deterministic client work versus generated content

Snapshots, matching/diffs, all stat calculations, BOM quantities, asset annotations
and price arithmetic are deterministic client-side work. A proposal is an input
to those calculations, not evidence and not an AI-provided statistical result.
Do not add proposal-derived facts to the combat evidence ledger or increase its
score. Existing actual-fit derivation/evidence behavior remains intact.

Current `fitAdvice.observedItems`/`recommendedItems` strings can name item classes.
They remain narrative fields. Add optional structured `fitCandidates` to the
report contract for new reports. Each candidate must describe a complete target
fit with exact resolvable types, integer quantities, supported slot groups,
configuration, original baseline fingerprint and rationale/limitations. Prefer
full candidate content over ambiguous natural-language patch operations. Explicit
replacement annotations may supplement it for diff explanation.
Require explicit group inventories, including declared empty groups, and record
unsupported groups as not applicable using hull metadata. Validate this presence
before the existing `Fitting.fromJson` defaults can turn omitted lists into empty
ones. An omitted group is incomplete input, not a fully specified empty group.

Validate candidate identity, hull/category, module-slot compatibility, duplicate
physical slots, quantities and known capacity constraints locally. Structural
errors (unresolved types, invalid quantities, incompatible slot categories or
duplicate/nonexistent physical slots) make the candidate unavailable for complete
comparison. A structurally readable fit that exceeds modeled CPU, powergrid,
calibration or deployment budgets remains inspectable with an explicit constraint
warning, qualified stats and its physical BOM; it is not labeled ready to fit.
Apply this distinction to AI, saved and imported proposals consistently. Unknown
game legality remains a warning, not a false certification. A failed candidate
must not discard the otherwise readable report. Preserve prose and a scoped
validation message, suppress unsupported comparisons, and offer reference selection.
Client-stamped source and validation status cannot be overridden by generated
“confirmed” labels. Raw generated numbers are never accepted as derived stats.
The encounter, report and original baseline association are also client-owned:
bind candidates to the prepared baseline supplied in that generation request.
Reject/disclose unknown or mismatched returned baseline/encounter references;
never silently rebase generated content. The earlier-fit warning applies to a
valid saved association when the user later changes the comparison selection.

### 7.2 Compatibility decision

Retain report **v3** and input **`mimir.combat_aar_input.v4`** for this additive
iteration: add optional versioned comparison/candidate fields and explicit prompt
rules; keep legacy required keys and existing advice fields unchanged. The input
extension supplies the exact baseline snapshot/fingerprint, known type IDs and
uncertainties when available. Tell generation to omit a concrete candidate when
it cannot provide one supported by the supplied input. Do not require a candidate
for a successful AAR.

The reader treats absent fields as no recorded comparison/candidate, not an empty
fit. An unknown candidate schema version leaves narrative readable and that
candidate unavailable. Round trips must retain supported new fields. If Plan
discovers a strict external consumer that cannot accept additive fields, version
that contract explicitly before shipping; never silently redefine an existing key.
This scope includes contract/parser/prompt regression tests, not a broad prompt
rewrite or mandatory regeneration of old reports.

### 7.3 Required feedback

These strings define new comparison flows; existing evidence import/capture strings
remain governed by the shipped [attachment contract](aar-fit-import-capture-ui-tests.md).
Use inline persistent states for missing/partial data and snackbars for completed
user actions. Announce status accessibly and do not show success before commit.

| Trigger | Required feedback and state |
|---|---|
| Comparison capture saved | Snackbar: **Current fit saved for comparison.** Header retains capture time. |
| No authenticated AAR pilot for capture | Inline: **Sign in with this pilot to capture the current fit.** Capture unavailable; stored comparisons remain readable. |
| No active ship returned | **No active ship is available for this pilot.** Preserve prior snapshot. |
| Capture/network/save failure | **Could not save the current fit for comparison. Try again.** Preserve prior snapshot; actionable categorized detail may follow. |
| Saved/EFT proposed fit saved | Snackbar: **Proposed fit saved for comparison.** No evidence-score or report change. |
| Invalid proposal import | Dialog stays open with strict parser's actionable validation error; no success or partial save. |
| Stored proposal save failure | **Could not save the proposed fit. Try again.** Keep prior candidate. |
| Baseline differs from candidate origin | Inline: **Based on an earlier fit.** Show original and selected baseline references; offer explicit re-analysis or a new proposal. |
| Legacy prose-only advice | **No structured proposed fit.** Preserve prose and reference/import actions. |
| Price refresh success | **Price estimates refreshed.** Replace estimates only after cache commit. |
| Price refresh failure | **Could not refresh prices. Showing cached estimates.** If none exist: **Could not refresh prices. Price estimates are unavailable.** |
| Local derivation failure | Column/row: **Stats unavailable for this fit.** Keep inventory, reason and retry when relevant inputs become available. |

Cancellation has no success snackbar or write. Empty successful ship capture is
a hull-only snapshot with limitations; an asset-page failure is an error, not a
successful empty fit. Duplicate taps are coalesced/disabled while saving, and late
results may not update the wrong encounter.

## 8. Acceptance criteria

### Functional and evidence integrity

- **AC1 — Reachability:** Comparison is accessible before analysis and in the
  post-analysis Fits tab without an AI call to render available data.
- **AC2 — Roles and identity:** All four source roles are represented accurately,
  including own-loss victim deduplication, opponent victory case and unknown identity.
- **AC3 — Independent persistence:** Comparison captures/proposals persist across
  reload and re-analysis without overwriting attached pilot evidence, victim packet,
  saved fits, editor state, report or evidence score.
- **AC4 — Historical baseline:** New reports retain the actual fit input used at
  generation; attachment changes preserve that snapshot and mark stale advice even
  at the same evidence score. Legacy reports disclose missing generation snapshots.
- **AC5 — Selection semantics:** Baseline and candidate selections are explicit and
  stable. Alternative proposals never merge; changing comparison baseline preserves
  candidate origin. Copying a saved reference isolates later edits.
- **AC6 — Completeness:** Empty, not recorded, unresolved and not applicable are
  distinguishable. Hull-only and legacy incomplete data never imply full knowledge.
- **AC7 — Capture/import failure:** Authentication, missing ship, asset-page failure,
  strict EFT rejection, cancellation and save failure retain prior committed state
  and give the §7.3 feedback without a false success notification.
- **AC8 — Concurrency:** Atomic field ownership, generation-input binding and stale
  completion guards preserve both concurrent evidence and comparison changes across
  refresh, double taps, navigation and disposal.
- **AC9 — Proposal validation:** Only locally validated structured content produces
  a complete proposed fit/BOM. Generic advice, malformed candidates and unsupported
  versions preserve the report and disclose candidate unavailability.
- **AC10 — Compatibility:** Existing report v3/input v4 behavior remains valid with
  absent optional fields; supported new fields round-trip and no AI statistic or
  proposed item becomes an evidence fact.

### Quantitative and deterministic behavior

- **AC11 — Stable diffs:** Exact duplicate matching precedes replacement pairing;
  reordered/EFT-compacted entries do not invent changes. Matching is deterministic.
- **AC12 — Configuration and quantities:** State, charge, deployment and quantity
  changes show correct details; moves do not create material purchases and unknown
  charge quantities remain unquantified.
- **AC13 — Hull and incomplete diffs:** Different hulls have no synthetic slot
  replacements; incomplete records use qualified presence/absence wording and retain
  unresolved occupied entries.
- **AC14 — Common context:** Every column uses one declared skill basis, incoming
  profile and calculation revision, including opponent/reference columns; changing
  any calculation input cannot leave stale figures under a new header.
- **AC15 — Defense math:** Layer/total EHP use the identical selected profile; resist
  deltas use percentage points. The numeric fixtures in §9.1 hold before rounding.
- **AC16 — Offense and mobility:** Requested rows use deterministic engine values,
  distinguish theoretical DPS from observed combat output, label Weapon volley
  correctly and expose missing-charge/deployment assumptions.
- **AC17 — Cap and tank limits:** Cap units/transitions remain meaningful, simulation
  limits are visible, burst and peak passive HP/s are correctly labeled, and
  sustained repair is explicitly Not modeled.
- **AC18 — Partial/invalid stats:** Unknown inputs and failed derivation cannot show
  confident improvement badges, fake zeroes or NaN/infinity percentages. Known
  capacity warnings never imply comprehensive fitting legality.
- **AC19 — BOM arithmetic:** Changes and Full replacement modes produce exact type
  counts across hull/modules/drones/fighters/cargo, aggregate moves across groups,
  and never deduct destroyed baseline ownership or guaranteed removal resale.
- **AC20 — Cargo and loaded charges:** Only explicit quantities enter exact BOM
  totals; generic cargo suggestions and unknown loaded units appear separately.
- **AC21 — Asset claims:** Cached ownership is scoped to the encounter pilot,
  includes freshness/eligibility limits, and credits only disjoint eligible loose
  stock. Empty, ambiguous, remote and other-ship assets cannot prove local availability.
- **AC22 — Prices:** BOM uses valid cached ESI average estimates with timestamps,
  ≥24h stale indication, gross values and priced coverage. Missing/adjusted-only
  prices and default cost zeroes cannot make an item free or a partial subtotal total.
- **AC23 — Independent optional data:** Local fit/stat comparison works offline;
  explicit price-only refresh, price failure, authentication absence and icon errors
  do not remove available inventory or initiate unrelated asset/order sync.

### Presentation and interaction

- **AC24 — Responsive layout:** §4.1 column counts, source access and selection
  persistence work at boundary widths; 320 pixels/200% text remain usable without
  horizontal page overflow.
- **AC25 — Identity headers:** Headers show source, subject, named hull, confidence,
  capture/evidence time distinction and relevant partial/stale/reference warnings;
  raw EVE IDs are never user-facing substitutes for names.
- **AC26 — Complete module presentation:** High/Mid/Low/Rigs/Subsystems/Drones/Fighters/
  Cargo groups, quantities, charges and offline states remain discoverable with
  icons, stable placeholders and resolved/local fallback text.
- **AC27 — Accessible diffs:** Added/Removed/Modified/Unchanged use text and icons as
  well as color; keyboard/touch exposes tooltip detail and source selectors. Changes
  only works for identical fits and all changes without losing source context.
- **AC28 — Stat readability:** Comparable stat rows align or stack as specified,
  shared assumptions/profile remain visible, native units and tradeoffs are clear,
  and no overall winner or unsupported upgrade claim appears.
- **AC29 — Actionable BOM:** Target, baseline, mode, counts, removals, charge/cargo
  unknowns, cache shortfall qualifications and price coverage are readable together;
  known loss/hull-change defaults choose Full replacement.
- **AC30 — Feedback and isolation:** Exact §7.3 action feedback follows committed
  outcomes, busy/error states are accessible and scoped, and all read-only
  interactions leave evidence and active editor state unchanged.

## 9. Test scenarios and matrix for Test-Author and Plan

### 9.1 Controlled fixtures and numerical oracles

All values below are synthetic, seeded test inputs, not current EVE item stats or
market quotations. Test-Author maps symbolic types A/B/C/H to distinct fixture SDE
types with known names, categories and slot metadata. Use injected time, local SDE,
deterministic skill maps, a recording fake external boundary and real repository
round trips for persistence paths. Never use live ESI/market/AI for these assertions.

**F1 — Duplicate modules, configuration and quantities.** Complete same-hull
baseline: high `[A(active, charge X), A(active, charge X)]`; mid `[B(active)]`;
drones `D ×5`; cargo `Ammo ×100`. Target: reordered high
`[A(offline, charge Y), A(active, charge X)]`; mid `[C(active)]`; drones `D ×3`;
cargo `Ammo ×150, Paste ×20`. Physical slot provenance is recorded for the mids.
Expect one unchanged A, one modified A (state/charge), B→C replacement, two removed
drones, +50 Ammo and +20 Paste. Changes BOM: `C ×1, Ammo ×50, Paste ×20`; removals
`B ×1, D ×2`; no A purchase, and Y loaded quantity unknown. With order-only mids,
render separate B removed/C added rather than an asserted slot replacement.

Tie-break variant, order-only positions: baseline A configurations `(active, X)`
and `(offline, Y)`; target `(online, Z)` and `(overloaded, W)`, with seeded charge
IDs ordered W < X < Y < Z. There are no exact matches. Expect canonical pairs
X→W and Y→Z under §4.3 regardless of permutations of either input list; neither
pair is a claim about physical slot history.

**F2 — Cross-group reuse and replacement value.** Baseline same hull H: fitted
`A ×1`, cargo `A ×1, Ammo ×100`. Target H: fitted `A ×2, C ×1`, cargo
`Ammo ×150, Paste ×20`. Changes BOM is `C ×1, Ammo ×50, Paste ×20`, with no A.
Full replacement is `H ×1, A ×2, C ×1, Ammo ×150, Paste ×20`.
Prices: H=100,000,000 ISK; A=1,000,000; C=2,000,000; Ammo=10; Paste unavailable.
Changes priced subtotal = **2,000,500 ISK**, 2 of 3 required type lines priced.
Replacement priced subtotal = **104,001,500 ISK**, 4 of 5 lines priced. Neither is
a total. Eligible, disjoint loose stock `C ×1, Ammo ×30, Paste ×5` gives Changes
shortfall `C ×0, Ammo ×20, Paste ×15`; priced shortfall subtotal **200 ISK**, with
Paste excluded. A destroyed baseline gives no stock credit in either mode.

Different-hull variant: change target hull H to H2 while keeping target equipment
above. Changes contains `H2 ×1, C ×1, Ammo ×50, Paste ×20` and removed `H ×1`;
common A contributes no net addition. Full replacement contains `H2 ×1, A ×2,
C ×1, Ammo ×150, Paste ×20`. Neither result establishes possession of the A modules.

**F3 — Common-profile EHP and deltas.** Each of three layers has 1,000 HP.
Baseline resists EM/Thermal/Kinetic/Explosive are 50/20/40/10 percent; target
60/20/50/10. At 100% EM, baseline EHP is 2,000 per layer, 6,000 total; target
2,500 per layer, 7,500 total: **+1,500 EHP (+25%)**, EM resist **+10 pp** per
layer. At Omni, baseline is `3000 / 0.7 = 4285.714285…`; target is
`3000 / 0.65 = 4615.384615…`; delta `329.670329…` (**7.692307…%**). Assert at
domain precision, then separately assert locale-aware rounded presentation.

**F4 — Cap and tank limits.** Stub modeled baseline time-to-empty 120 seconds;
candidate stable at 35%. Expect **Depleting → Modeled stable**, not “−85” or a
percent change. Candidate raw shield repair 100 HP/s, peak passive 20 HP/s;
Sustained repair remains Not modeled. With injector flag, expose infinite-clip
limitation; with horizon-derived stability, expose the 3600-second horizon.

**F5 — Identity, history and partial evidence.** Encounter pilot P, victim Q
for a win; victim P for a loss; unknown identity case; immutable generation fit
F-old and current attachment F-new with the same evidence score. Partial variant
has an unresolved occupied mid, unknown charges and absent victim `items` key.
Reference variant uses currentShipSnapshot/reference pilot evidence. Verify role
labels, separate source storage, qualified stats and unchanged historical snapshot.

### 9.2 Domain and contract cases

| ID | Input/action | Expected result | AC |
|---|---|---|---|
| D01 | Identical complete same-hull fits, shuffled module list order. | All unchanged; empty Changes BOM; stable result independent of input order. | AC11, AC19 |
| D02 | F1 duplicates and its two-unmatched-configuration variant; permute both inputs. | Exact matches first; expected B/C/quantity deltas; canonical X→W/Y→Z pairs invariant to order. | AC11, AC12 |
| D03 | EFT indices compact after an empty placeholder; same multiset as baseline. | No fictitious replacement/addition; order-only provenance retained. | AC6, AC11 |
| D04 | F1 mids recorded slot versus order-only; then change hull. | Replacement only in recorded same-hull case; Added/Removed otherwise; Different hulls flag. | AC11, AC13 |
| D05 | F2 moves cargo A into a high slot; state also changes; repeat with target hull H2. | No net A addition; group/configuration details and both same/different-hull BOM oracles hold. | AC12, AC19 |
| D06 | Drone/fighter quantities and in-space configuration differ; loaded Y has no quantity. | Quantity/configuration details separated; explicit units counted, loaded Y unquantified. | AC12, AC20 |
| D07 | Synthetic hull-only inventory with explicit completeness, legacy absent items, unresolved occupied mid; complete target against partial baseline. | Empty/unknown/unresolved differ; Changes incomplete where baseline affects counts; complete target replacement still exact. | AC6, AC13, AC19 |
| D08 | F3 at EM and Omni, including a selected M5 attacker profile. | Exact layer/total EHP and pp deltas; same profile applied to every fit. | AC14, AC15 |
| D09 | No usable pilot skills, then known pilot skills, including victim column. | All columns fall back together to All V or use one known context; opponent qualification retained. | AC14 |
| D10 | Weapon-only volley plus drones/fighters; unloaded weapons with unknown charges. | Volley excludes drone/fighter contribution; DPS split theoretical; unknown charge output marked incomplete. | AC16, AC18 |
| D11 | F4 plus zero/nonfinite baseline values. | Correct cap transition and tank labels; no mixed-unit math or NaN/infinity percentages. | AC17, AC18 |
| D12 | Fit exceeds seeded CPU/PG/drone limits; another has unknown module. | Constraint warning for known excess; affected unknown metrics partial with no confident uplift. | AC18 |
| D13 | F2 prices; missing and adjusted-only Paste; stale and exact-24h quotes; valid zero average. | Exact subtotals/coverage; no adjusted fallback/free claim; stale boundary and explicit zero estimate. | AC19, AC22 |
| D14 | F2 eligible loose cache, empty cache, other character/ship and ambiguous location stock. | Exact qualified shortfall only for eligible stock; other cases unknown/informational; no lost-fit credit. | AC21 |
| D15 | Full candidate, omitted versus explicitly empty groups, prose only, unknown type, bad quantity, slot collision, unsupported version, wrong baseline/encounter; over-budget valid fit. | Structural/association failures preserve prose and suppress complete candidate/BOM; budget excess retains inspection with warning. | AC9, AC10, AC18 |
| D16 | Snapshot serialization with states, quantities, completeness and old/new report JSON. | New data round-trips; missing keys stay absent; legacy report loads; name-resolution changes do not change equipment fingerprint. | AC4, AC6, AC10 |

### 9.3 Provider, repository and service cases

| ID | Input/action | Expected result | AC |
|---|---|---|---|
| P01 | Persist historical pilot evidence, then comparison current capture and proposal; reload/re-analyze. | All sources retained independently; evidence score/victim packet/editor unchanged. | AC3, AC10 |
| P02 | Generate with F-old; attach F-new while response pending, same score. | Report binds F-old prepared input; F-new remains attached; stale advice detected by fingerprint. | AC4, AC8 |
| P03 | Concurrent refresh, attachment and comparison save in reversed completion orders. | Field-owned atomic results preserve all latest valid sources; victim identity/content stay coherent. | AC3, AC8 |
| P04 | Double capture/selection, navigation to another encounter, dispose during save. | Coalesced/bounded operations; no stale overwrite/UI publication; committed storage follows encounter identity. | AC8, AC30 |
| P05 | F5 own loss, win, unknown victim and reference-confidence pilot fit. | Correct subject roles/fallback/dedup; no reference promotion or fabricated attacker fit. | AC2, AC6 |
| P06 | Choose saved fit, edit original afterward; change selected baseline and alternate proposals. | Copied proposal stable; original target preserved; no union of alternatives or editor mutation. | AC3, AC5 |
| P07 | Change each fingerprint input: module/charge/state/quantity, skill, profile, SDE; race old result. | Appropriate recalculation; no old stats published under new source/context. | AC14, AC18 |
| P08 | Strict invalid/corrupt proposal EFT, cancel, repository save failure. | No partial write; prior candidate retained; parser/save error distinguished. | AC7, AC9 |
| P09 | Comparison capture: authenticated success, no auth, missing ship, failed asset page, successful empty assets. | Only successful complete fetches save; empty result is labeled hull-only; failures retain prior fit. | AC6, AC7 |
| P10 | Offline with local SDE and stored fits, missing SDE, failed icon/price dependencies. | Available inventory/stats survive independently; unavailable rows explicit; no AI/ESI requirement for local comparison. | AC18, AC23 |
| P11 | Encounter P while active app character Q; fetch cached assets, trigger capture. | P remains subject; Q assets never credited; wrong-character capture cannot attach. | AC2, AC21 |
| P12 | Render and explicitly refresh prices with recording network fakes. | Render uses cache; refresh calls price-only sync; no order/asset sync; cache retained on failure. | AC22, AC23 |
| P13 | Legacy report and optional structured contract; generated “confirmed”/numeric fields and mismatched baseline/encounter refs. | Narrative loads; client provenance/association authoritative; mismatched candidates rejected; no generated stats/evidence facts. | AC9, AC10 |
| P14 | Same-score fit replacement followed by explicit re-analysis; new derivation revision. | Old generation content preserved for its report; new report binds new fit; current-context stats labeled separately. | AC4, AC8, AC14 |

### 9.4 Screen, interaction and accessibility cases

| ID | Input/action | Expected result | AC |
|---|---|---|---|
| U01 | Open pre-analysis encounter with one fit, then an existing report's Fits tab. | Compare fits reachable in both; no AI call on view; available roles visible. | AC1, AC2 |
| U02 | Usable widths 719/720, 999/1000 and 1439/1440; resize with selected candidate. | 1 stacked pair/2/3/4-column behavior at thresholds; hidden roles selectable; selection retained. | AC24 |
| U03 | 320px width, 200% text, keyboard and touch navigation. | No page overflow/clipped required text; baseline context and source choices reachable; focus order meaningful. | AC24, AC27 |
| U04 | F5 own loss/win/unknown/reference/legacy variants. | Correct headers, source/confidence/time warnings, dedup chip and legacy generation notice. | AC2, AC4, AC25 |
| U05 | Fit contains every group, offline module, charges, fighters and unresolved module; icon failure. | Complete grouping/details; stable icon fallback and names; no raw type/character IDs. | AC6, AC25, AC26 |
| U06 | F1 diff in color-independent rendering; Show all/Changes only; identical fits. | Badges and details understandable without color; counts/no-changes state correct. | AC11, AC12, AC27 |
| U07 | F3/F4 with common controls; proposal improves EHP but lowers DPS. | Aligned/stacked rows, +10 pp, proper cap/tank labels, both tradeoffs, no winner claim. | AC15, AC16, AC17, AC28 |
| U08 | Source loading, SDE error, partial unresolved fit, retry after local data arrives. | Inventory retained; scoped skeleton/error and partial labels; no confident uplift or stale numbers. | AC18, AC23, AC28 |
| U09 | F2 BOM in surviving-fit and known-loss/hull-change modes. | Correct default/mode headings, counts/subtotals/coverage; no destroyed-fit/resale credit. | AC19, AC20, AC22, AC29 |
| U10 | Eligible/unknown/other-ship cached assets; quantified and generic cargo advice. | Qualified shortfall and freshness text; unknown quantities separate; no “ready to fit” claim. | AC20, AC21, AC29 |
| U11 | Successful capture and proposed save; reload; repeated taps while saving. | Exact success snackbars after commit; busy state accessible; independent sources survive. | AC3, AC7, AC30 |
| U12 | No auth, missing active ship, capture error, bad EFT, cancel, proposal save error. | Exact applicable §7.3 feedback; dialog state recoverable; old fit/candidate retained; no false success. | AC7, AC30 |
| U13 | Legacy prose, invalid structured candidate, alternative candidates and saved reference; baseline changes. | Advice readable; no structured fit state/actions; baseline-origin warning; no merged proposals. | AC5, AC9, AC10, AC30 |
| U14 | Price refresh success/failure with and without cache, offline icon failure. | Correct price messages/age/coverage; fits/stats persist; no unrelated sync. | AC22, AC23, AC30 |
| U15 | Evidence checklist/score and active editor recorded before all read-only interactions. | Identical evidence/editor state afterward; only explicit comparison saves change comparison storage. | AC3, AC10, AC30 |
| U16 | Attach F-new at same score to report generated with F-old; navigate during async completion. | Historical baseline persists; stale advice shown; re-analysis is explicit; no snackbar in another encounter. | AC4, AC8, AC25, AC30 |

### 9.5 Test authoring and plan handoff

The matrix has **46 cases**: 16 domain/contract, 14 provider/repository/service and
16 screen/accessibility. These are verification obligations, not existing passing
tests. Parameterized subcases must cover the variants listed in each row. Unit
tests alone cannot satisfy persistence, actual Fits-tab navigation or interaction
criteria; use real serialization/repositories and the real screen with controlled
external boundaries for those rows. A screenshot alone cannot prove source safety.

Plan should sequence implementation as follows, assigning files and test ownership
before concurrent work:

1. **Source/data contract:** snapshot identity/completeness, separate persistence,
   generation binding, additive proposal contract and lifecycle protection.
2. **Deterministic comparisons:** diff/BOM and shared calculation context. Pure
   domain tests and provider integration precede visual badges.
3. **Read-only workspace:** responsive columns/source controls, module/stat rows,
   accessibility and pre-analysis entry; do not embed mutable editor state.
4. **Proposal and material workflows:** strict reference import, validated AI
   candidates, cached assets/prices and feedback.
5. **Integration and release review:** all scenarios S1–S6, AC1–AC30 and D/P/U
   cases mapped to passing evidence; static analysis and focused relevant Flutter
   suites. Run broader regression when model/serialization changes justify it.

Review evidence must include desktop and narrow/text-scaled renderings, numerical
oracles, new/legacy report round trips, concurrent-save and same-score history
tests, and proof that optional network failures do not erase local comparison.
Use feature-tagged shared debug logging for future code changes, including source
IDs/operation outcomes and derivation status without raw EFT or character asset
dumps. This documentation change itself does not implement or run those tests.

## 10. Product decisions, edge cases and non-goals

### 10.1 Decisions

| Decision | Rationale / revisit condition |
|---|---|
| D1: Four source roles with immutable copied snapshots and separate current/proposal storage. | Prevent evidence overwrite and allow genuine historical comparison. Revisit retention limits if report storage becomes material. |
| D2: Preserve generation-time fit content; visual recalculation uses labeled current context. | Evidence scores cannot identify the exact fit or reproduce old stats. Historical numerical replay would need versioned engine/SDE retention and is separate. |
| D3: Validated full candidates plus saved/EFT proposals; additive optional schemas. | Existing prose is insufficient for exact slots/quantities. Omission is better than an invented fit; structured AI candidates are optional, not an AAR success requirement. |
| D4: Deterministic multiset diff before physical-slot replacement. | Tolerates duplicates and EFT compact indices; prevents invented upgrades and purchases. |
| D5: Common pilot skills/All V fallback and selected defense profile. | Isolates equipment tradeoffs. Opponent comparisons are hypothetical, with explicit unknown actual skills. |
| D6: Burst/peak tank displayed; sustained active tank Not modeled. | Current engine lacks a resource/reload-aware sustained model. Revisit with that separate engine work. |
| D7: Changes and Full replacement are separate BOM modes; cached availability is qualified. | Losses invalidate baseline ownership; the cache lacks freshness/completeness. Revisit authoritative availability only with metadata and containment support. |
| D8: Cached ESI average estimates, partial coverage and price-only refresh. | Existing data cannot promise local purchase cost. Revisit regional quotes and logistics as their own scope. |
| D9: Read-only widgets with explicit comparison actions. | AAR inspection must not mutate the shared fitting editor, evidence or analysis state. |

### 10.2 Edge-case release policy

| Condition | Required behavior |
|---|---|
| No fits anywhere | Explain each missing source; offer existing evidence import, comparison capture and reference selection where available. No empty zero-stat comparison. |
| Hull only / missing slot data | Show hull, source completeness and bare-hull/partial calculations labeled accordingly; never assert all omitted slots were empty. |
| SDE/module/name unresolved | Preserve occupied entry and stored identity internally; human-readable unresolved label; affected stats/BOM coverage qualified. |
| Different hulls | Compare group inventories and shared-context stats; no inferred slot upgrades; default replacement BOM. |
| Same loadout, different time/source | Preserve distinct provenance even if every equipment diff is Unchanged. |
| Legacy report without candidate or generation fit | Preserve prose; no synthetic candidate or reconstructed historical snapshot; offer explicit reference workflow. |
| Wrong/no authenticated character | Stored fits and local derivation remain readable; capture asks for the encounter pilot and cannot attach another pilot's assets. |
| Empty/unknown asset cache | Availability unknown, never “you own zero”; no inventory-based savings claim. |
| Offline/local-only | Stored content and available SDE math work; missing names/icons/prices are independent fallbacks; no automatic remote dependency. |
| Unmodeled module/charge/state effects | Expose limitations and partial metrics; no fabricated application, overheat, sustained tank or legality guarantee. |
| Interrupted or competing actions | Keep last committed snapshot, field ownership and encounter isolation; no success before persistence. |

### 10.3 Non-goals

- Automatically applying a proposed fit, purchasing items, selling removals,
  moving assets, updating EVE fittings, or mutating the active editor on preview.
- Inferring attacker modules from a correlated hull, reconstructing unrecorded
  fight-time fits, or upgrading reference/proposal confidence to observed evidence.
- A new doctrine discovery service, doctrine compliance certification, or automatic
  exact-module selection from generic advice. User-selected references are in scope.
- New turret/missile application simulation, combat outcome prediction, heat/reload
  timelines, cap-injector charge budgets or sustained active-tank modeling.
- Full fitting legality certification, guaranteed “best fit,” or identical historical
  numerical replay across changed SDE/engine revisions.
- Regional/station market order quotes, guaranteed acquisition costs, taxes,
  logistics, resale proceeds, or fresh inventory assertions from unqualified cache data.
- Rewriting old AI reports on view, mandatory regeneration, changing the shipped
  evidence scoring weights, or replacing Milestone 5's attacker-matchup rules.

The roadmap item remains queued until implementation, test evidence and signoff
satisfy this specification. The earlier one-to-three-day queue estimate predates
these identified data-contract requirements; Plan must re-estimate the complete
scope rather than assuming the existing visual seams already provide them.
