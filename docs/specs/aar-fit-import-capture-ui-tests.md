# AAR Fit Import and Capture UI Tests — Product Contract

**Status.** Ready for Test-Author and Plan; tests and associated fixes pending.
**Author.** Product.
**Date.** 2026-09-14.
**Priority.** P2, [queued item](../engineering-journal/QUEUED.md#aar-fit-import-and-capture-ui-tests).
**Grounding.** `develop` at `7db3630`; Milestone 5 is verified and merged.
**Deliverable.** Product expectations, 24 acceptance criteria, and 36 test scenarios.

## 1. Product perspective

Attaching a fit is how a pilot turns a log-based AAR into a comparison against their
own ship's defenses. The user is making a consequential evidence statement: **“Use
this fit for this fight.”** A successful interaction must mean the intended fit was
saved to the right encounter, its evidence status reflects what is actually known,
and subsequent analysis uses it.

The risk is a plausible success message over an incomplete workflow: discarded EFT
lines, a snapshot of the wrong character's ship, an unchanged checklist, or a
re-analysis that overwrites the newly attached evidence. Existing tests cover several
buttons and domain helpers, but do not establish the complete journey.

**Governing contract:** accepted fit content must survive from user action through
enrichment storage, live evidence/defense refresh, and explicit re-analysis. Failed
attachment must preserve prior evidence and provide useful feedback. Attachment never
automatically spends an AI request.

This is a test-led hardening item, not a new fit editor. Some acceptance tests should
expose current defects. Plan must include the smallest fixes needed for the contracts
below instead of making tests bless data loss. The queue's half-day-to-one-day estimate
covers a small coverage addition; it must be reconsidered if the identified defects
require additional implementation work.

## 2. Grounding in the current implementation

### 2.1 Live controls and reachable states

The authoritative screen is
[`AnalysisMultiPaneScreen`](../../lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart).
The checklist and action model are
[`AarEvidenceChecklistCard`](../../lib/features/combat_analyzer/presentation/widgets/aar_evidence_checklist_card.dart)
and [`AarEvidenceAction`](../../lib/features/combat_analyzer/domain/aar_evidence_assessment.dart).

| Control/path | Shipped behavior | Test consequence |
| --- | --- | --- |
| Pilot-fit checklist row → **Import Fit** | `onImportFit: _showImportFitDialog` | Exercise the real dialog through the row action in pre-analysis and cached-report views. |
| Pilot-fit row → **Use Current Fit** | Calls `_captureCurrentFit(confirmed: true)` | This is already an explicit confirmation that the current ship is the fight fit. There is no second confirmation modal. |
| `_captureCurrentFit(confirmed: false)` | Method branch remains, but **no current UI control invokes it** | Cover the service mode and previously persisted reference evidence. Do not resurrect or expect **Snapshot Current Fit** in a widget test. |
| Missing/Inferred pilot fit | Both attachment actions are supplied, including after derivation failure | Seed these states to reach the dialog/capture path. |
| Partial/Complete pilot fit | Current scorer supplies no attachment actions | Do not invent a replacement button in these states. Service replacement tests can run directly; UI retry/replacement fixtures must start from a reachable Missing/Inferred state. |
| Checklist score ≥90 | Collapsed by default unless the user has toggled it | Expand the actual checklist when needed; do not assume the actions are initially visible. |
| Cached-report **Re-analyze** | Command-strip button always exists; provenance banner can add a second button | Scope finders to the intended control. Both call `_startAnalysis(forceRefresh: true)`. |

The unconfirmed snapshot button was deliberately removed in
[evidence-checklist design D6](aar-evidence-completeness-score-design.md#13-resolution-of-the-specs-decisions-8-and-new-ones).
The queued description predates that change. Reference capture remains a compatibility
contract, not a missing screen control to restore.

### 2.2 Manual import: actual sequence and validation limits

1. The dialog title is **Import Pilot Fit**, with a multiline `TextField`, EFT hint
   `[Rifter, Fight Fit]\nDamage Control II\n...`, and **Cancel**/**Import** actions.
2. Cancel/dismiss returns null. Import closes the dialog with its text **before parsing
   or saving**. Empty/whitespace input returns without a service call or snackbar.
3. Nonempty text goes to `CombatEnrichmentService.importPilotFit(encounter, rawFit)`.
4. The service currently selects DNA whenever the trimmed string contains `:`;
   otherwise it calls `FittingFormatParser.parseEft`.
5. Its explicit validation is only `fitting != null && fitting.shipTypeId > 0`.
6. Accepted evidence is role `pilot`, source `manualFitImport`, confidence `confirmed`,
   UTC capture time, and limitation **User-confirmed manual fit import.**
7. It loads/copies existing enrichment, updates `pilotFitEvidence`, replaces the
   `ev-pilot-fit-<encounter.id>` ledger fact, removes pilot-fit unknowns, then saves.
8. After the awaited save, the screen invalidates
   `combatEnrichmentProvider(encounter.id)`, displays success, and rebuilds. This should
   propagate to live evidence and Milestone 5 defenses without regenerating AI prose.

Sources: [enrichment service](../../lib/features/combat_analyzer/data/combat_enrichment_service.dart),
[format parser](../../lib/features/fitting/domain/format_parser.dart),
[repository](../../lib/features/combat_analyzer/data/combat_enrichment_repository.dart).

**The current dialog has no inline validation/error area.** Service errors are caught
after it closes and surfaced in a snackbar. Keep this interaction for this item:
tests must not require an inline error label or automatic reopening. The user can reopen
the dialog and submit corrected text.

Known gaps from source inspection:

- `[Rifter, PvP: Armor]` is valid EFT header text but takes the DNA branch.
- Unknown module and stacked drone/fighter lines may be silently skipped. A known hull
  plus corrupt content can therefore be saved as confirmed evidence.
- The EFT module parser currently ignores a comma-separated loaded-ammunition suffix.
- A positive generic SDE type lookup is not explicit validation that the header is a ship.
- A known hull with no module lines is accepted, and an existing service test relies
  on it. An intentionally empty fit is distinct from a fit made empty by discarded lines.

### 2.3 Current-ship snapshot: actual sequence and limitations

`captureCurrentPilotFit` uses **`encounter.characterId`**, not the globally selected
character. It fetches the current ship, fetches all assets pages using `x-pages`, then
maps assets parented to that ship's `shipItemId`. Nested assets under fitted modules
provide loaded charges. Existing mapper logic also covers drones, fighters, and cargo.
See [snapshot mapper](../../lib/features/combat_analyzer/domain/combat_fit_snapshot_mapper.dart).

| Mode | Saved source/confidence | Meaning |
| --- | --- | --- |
| `confirmed: true` | `currentShipSnapshot` / `confirmed` | User states this current snapshot was the fight fit. It is user-confirmed, not independently proven history. |
| `confirmed: false` | `currentShipSnapshot` / `reference` | Snapshot is current reference evidence, not a confirmed historical fit. |

Both modes save role `pilot`, UTC evidence time, the fitting, source-specific limitations,
and one pilot-fit ledger fact. A later **Use Current Fit** action fetches a **new current
snapshot** with confirmation; it does not merely relabel the old stored reference.

- Missing `encounter.characterId` throws a `FormatException` before ESI calls.
- Null current ship throws a `FormatException` before assets are fetched.
- Missing tokens can throw `EsiException`; some ship request `DioException`s are caught
  by the ESI client and returned as null, losing the distinction between auth/network/no ship.
- Asset-page failures propagate before any fitting is saved. Partial pagination must
  never become a successful partial inventory snapshot.
- A **successful empty assets response**, or no children of the current ship, currently
  maps and saves a hull-only fit. It is not an existing “missing assets” exception.
- The mapper carries fallback type labels such as `Type #…`; UI tests must distinguish
  internal identifiers from the repository's requirement to display resolved names.

### 2.4 Evidence score, checklist refresh, and re-analysis

[`AarEvidenceScorer.pilotFit`](../../lib/features/combat_analyzer/domain/aar_evidence_scorer.dart)
evaluates evidence **and** a derivation, rather than marking every save Complete:

| Fit evidence and local derivation | Pilot-fit status | Earned contribution out of weight 30 |
| --- | --- | ---: |
| No evidence, or derivation failed/unavailable | Missing | 0 |
| Reference/derived/unknown confidence with usable derivation | Inferred | 9 |
| Confirmed/proven with unresolved modules or All V fallback skills | Partial | 15 |
| Confirmed/proven, resolved fit, known-character skills | Complete | 30 |

Overall score is `round(100 × earned / available)`. Unavailable dimensions are excluded
from `available`, so an attachment does not always increase the displayed score by 30.
No scoring weights or thresholds change in this item. Inferred/Partial are honest
outcomes, and successful persistence can coexist with a later derivation failure.
An accepted SDE name/type whose simulation attributes are unavailable is a derivation
coverage issue; it is distinct from a supplied item name that cannot be resolved and
would otherwise be dropped during parsing.

The current [provider chain](../../lib/features/combat_analyzer/data/combat_providers.dart)
re-evaluates enrichment, fit derivation, and evidence assessment after invalidation.
The Milestone 5 defense path must also see the new evidence while retaining its incoming
damage allocation. Tests must demonstrate an actual dependency update, not inject the
expected score directly after tapping a button.

[`AarReportProvenanceBanner`](../../lib/features/combat_analyzer/presentation/widgets/aar_report_provenance_banner.dart)
offers its additional **Re-analyze** action only when current score minus recorded score
is **at least 10 percentage points**. A +9 improvement, same-score fit replacement, or
unknown recorded score does not add that banner action. The command-strip action remains
available. Legacy reports say **Evidence at generation: not recorded**.

**Critical retention gap, source-evidenced rather than test-reproduced:**
[`CombatAnalysisService.analyzeEncounter`](../../lib/features/combat_analyzer/data/combat_analysis_service.dart)
forwards `forceRefresh: true` to enrichment. The refresh path constructs fresh enrichment
and `_save` upserts it without retaining the previously attached `pilotFitEvidence`.
This can discard the fit before derivation/prompt generation. A mock that only records
`forceRefresh: true` will miss the bug. Preserving the fit across explicit re-analysis
is a release requirement of this item.

### 2.5 What existing tests already prove

| Existing suite | Reuse | Missing proof this item adds |
| --- | --- | --- |
| [Screen evidence tests](../../test/features/combat_analyzer/presentation/analysis_multipane_evidence_test.dart), T8.3/T8.4, H.7–H.9 | Confirmed capture dispatch, fake score update, banner/legacy behavior | Real dialog, real capture/import persistence, snackbars, errors, and fit surviving re-analysis |
| [Checklist tests](../../test/features/combat_analyzer/presentation/aar_evidence_checklist_card_test.dart) | Action visibility/callbacks and refresh presentation | Screen operation and service/storage consequence |
| [Enrichment service tests](../../test/features/combat_analyzer/data/combat_enrichment_service_test.dart), D.9 | Import preserves killmail search state | Validation, asset errors, metadata, replacement, refresh retention |
| [Snapshot mapper tests](../../test/features/combat_analyzer/domain/combat_fit_snapshot_mapper_test.dart) | Slots, nested charges, drones/cargo, fighters | ESI pagination and the live save/reload path |
| [Fitting parser tests](../../test/features/fitting/domain/format_parser_test.dart) | Supported format examples | AAR acceptance/rejection, no silent loss, and user feedback |

The current screen fake manufactures complete evidence/derivation on capture. It
bypasses ESI, SDE, mapping, and storage, and cannot prove the end-to-end contract.

## 3. Product decisions and user scenarios

### 3.1 Decisions that bound the tests

1. **Test the two live actions.** Keep reference capture at the service/legacy-data layer.
   Do not restore removed controls or add fit replacement buttons to Complete/Partial rows.
2. **AAR import must be faithful or rejected.** Accept known ship headers and supported
   entries, including intentional empty slots/hull-only fits. Reject unknown/non-ship
   headers, unresolved supplied entries, and malformed nonempty content before saving.
   A typo must not silently become an absent module. Do not guess missing items.
3. **No parser feature expansion is required.** Keep existing supported EFT/DNA behavior.
   Fix EFT/DNA selection so a colon in a bracketed EFT header is not a DNA discriminator.
   For currently unsupported loaded-ammunition suffixes, reject the AAR import with a
   clear explanation rather than silently dropping the charge. Adding charge parsing
   itself can remain a separate fitting-parser task. These guards can live at the AAR
   boundary without making every shared parser consumer strict.
4. **Empty inventory is distinct from failed inventory.** After all pages succeed, a
   hull-only snapshot is allowed, with a visible and persisted limitation: **No fitted
   modules were returned for the current ship.** Keep normal scoring rules; “Complete”
   concerns the returned evidence/derivation, not proof that an inventory snapshot is
   exhaustive historical telemetry. Failed/incomplete asset reads never save.
5. **Use local import as the fallback.** Manual EFT import requires local SDE data, not
   an authenticated character or character-assets scope. Capture uses the encounter's
   character and may fail gracefully. It never silently switches to another character.
6. **Save then refresh then offer analysis.** Success means persistence completed. Local
   evidence/defense refresh occurs automatically; AI analysis requires an explicit
   action. Preserve the attached fit through all enrichment-refresh branches.
7. **One attachment operation at a time per encounter.** While import/capture saves,
   prevent competing attachments and repeated saves; show a scoped busy state. This is
   a fit-action constraint, not an evidence-score restriction on **Analyze With AI**.
   If the user explicitly requests analysis while an attachment is pending, wait for
   that operation to settle before taking the analysis evidence snapshot. Use the new
   fit after success, or the previous saved evidence after attachment failure while
   retaining its error feedback. Enrichment refresh must not overwrite a later saved
   pilot fit with an older copy. This remains an explicit analysis request, not an
   automatic analysis triggered by attachment.
8. **Keep errors understandable.** Preserve the normal success strings below. Classify
   failures into concise feedback; do not freeze raw `DioException`, token, numeric
   character-ID, or stack-trace strings into UI goldens. Existing handler catch/log
   paths remain useful, but error presentation needs hardening.

Decisions 2–4, 6–8 include desired behavior beyond what the baseline guarantees. Plan
must separate those regression-driven fixes from tests that already pass. They are
not claims that the current application already implements the contract.

### 3.2 Scenarios and expectations

| Scenario | User action/context | Expected outcome |
| --- | --- | --- |
| S1 — Attach a manual fight fit | Missing pilot fit; paste supported EFT and Import | Dialog closes, one fit saves to this encounter, success snackbar appears after save, checklist/defense refresh, no automatic AI request. |
| S2 — Abandon or correct input | Cancel/dismiss, submit blank, or submit malformed text | Cancel/blank are silent no-ops. Malformed nonempty input shows failure after dialog dismissal and changes no evidence. Reopen and correct it successfully. |
| S3 — Capture current fit | Use Current Fit with matched encounter character and readable inventory | Fetch that character's current ship and all assets pages, save confirmed evidence with correct modules/charges, show success and updated evidence. |
| S4 — Inspect/upgrade legacy reference | A persisted unconfirmed snapshot is loaded; then Use Current Fit | Usable reference is Inferred with capture time/qualification. Action captures the current ship afresh and saves confirmed evidence; no legacy snapshot button appears. |
| S5 — Capture is unavailable | No character match, null ship, denied/failed ESI, or failing asset page | Explain failure; preserve prior fit/report/score; do not fabricate a hull from a failed response. Manual import remains possible when its checklist action is available. |
| S6 — Inventory succeeds but is empty | Current ship exists; complete inventory has no fitted modules for it | Save a hull-only snapshot with an explicit empty-modules limitation and qualified success feedback, not an invented full fit. |
| S7 — Refresh evidence on a cached AAR | Import/capture from a reachable row; cached report already exists | Current evidence and M5 defense update. Recorded report snapshot/prose remain historical. Banner prompts only at +10 or more; command-strip re-analysis remains available. |
| S8 — Re-analyze with attached evidence | User explicitly chooses Re-analyze | The saved pilot fit survives refresh and is supplied to actual derivation and the AI boundary. AI failure preserves the prior report and saved fit. |
| S9 — Pending work or navigation | Slow parse/save/assets, repeated clicks, or leave the screen | No premature success or duplicate/competing saves. Completion cannot update a disposed/new encounter screen or use the wrong encounter key. |

### 3.3 Snackbar and feedback contract

**Existing successful messages: retain exact text for normal cases.**

| Event | Message | Scope |
| --- | --- | --- |
| Manual import saved | `Pilot fit imported. Re-analyze to include it.` | Reachable UI, including pre-analysis; the wording does not imply AI has run |
| Confirmed snapshot saved | `Current fit confirmed for this AAR. Re-analyze to include it.` | Reachable Use Current Fit |
| Unconfirmed snapshot saved | `Current fit snapshot saved as reference evidence.` | Existing unreachable screen branch; document it, do not invent a widget action to test it |
| Confirmed hull-only snapshot saved | `Current fit confirmed for this AAR. No fitted modules were returned. Re-analyze to include it.` | Required qualified variant for S6 |

The service's current validation exceptions contain these exact messages; keep direct
service assertions distinct from UI formatting:

- `Unable to resolve the pasted fit. Paste an EFT fit with a known ship and modules.`
- `Current fit snapshot requires an authenticated character match.`
- `ESI did not return a current ship.`

Today the screen interpolates `Unable to import fit: $e` or `Unable to capture fit: $e`.
This includes `FormatException:` or raw transport diagnostics. The following **desired
UI messages** make the new error tests stable and user-facing; they may require fixes.

| Failure category | Required user feedback |
| --- | --- |
| Malformed EFT, unknown/non-ship hull | `Unable to import fit: Check the EFT header and item names, then try again.` |
| Supplied unresolved entries | `Unable to import fit: Some fit entries could not be resolved. Check the item names.` |
| Unsupported loaded-ammunition suffix | `Unable to import fit: Loaded ammunition in EFT is not supported by this import.` |
| Local fitting data unavailable | `Unable to import fit: Local fitting data is unavailable. Try again after it loads.` |
| Import persistence/unclassified failure | `Unable to import fit: The fit could not be saved. Try again.` |
| Capture with no matched character | `Unable to capture fit: This log is not linked to an authenticated character.` |
| Explicit auth/permission error available from ESI | `Unable to capture fit: Reauthorize this character and try again.` |
| ESI returns no ship, including a transport error collapsed to null | `Unable to capture fit: ESI did not return a current ship. Try again or import a fit.` |
| Assets request/page failure | `Unable to capture fit: Character assets could not be loaded. Try again or import a fit.` |
| Capture persistence/unclassified failure | `Unable to capture fit: The snapshot could not be saved. Try again.` |

Do not claim the UI can infer an auth failure after the client has collapsed it to null.
No auto-reauthorization or new auth workflow is required; where **Reauthorize Character**
is already supplied by the checklist, preserve its existing auth-controller dispatch.
On retry, previous failure feedback must not remain as the current operation's status.
The dialog need not retain a failed draft or reopen automatically in this item.

## 4. Acceptance criteria

These **24 criteria** are the release contract for this queued item. A criterion marked
by a baseline gap is still required; identify the failing test and plan a narrow fix.
They are separate from Milestone 5's prior AC1–AC28.

| ID | Required behavior | Tests |
| --- | --- | --- |
| AC1 | Exercise Import Fit and confirmed Use Current Fit from live Missing/Inferred checklist rows in both screen states; no unconfirmed snapshot button is introduced. | T01, T13, T19, T20, T36 |
| AC2 | Dialog exposes the current title, multiline EFT field, Cancel/Import actions, and usable keyboard/focus behavior. | T01, T32 |
| AC3 | Cancel, dismissal, Escape, empty and whitespace submissions perform no save, success notification, evidence change, or AI request. | T02, T03 |
| AC4 | Supported EFT saves the intended hull and every supported supplied item with role pilot, manualFitImport source, confirmed confidence and UTC provenance. Intentional hull-only fits remain valid. | T04, T05 |
| AC5 | Manual import works without an authenticated encounter character when local SDE is available; capture never falls back to another selected character. | T05, T14, T16 |
| AC6 | Malformed/non-ship/unknown hull input and local-data failures never persist confirmed evidence or display success. | T06, T10 |
| AC7 | Valid bracketed EFT headers containing colons are parsed as EFT; existing actual DNA import compatibility remains intact. | T07 |
| AC8 | Unresolved supplied entries and unsupported ammunition syntax cannot be silently dropped from a successful AAR import. | T08, T09 |
| AC9 | Confirmed capture uses the encounter character, current ship item ID, every required asset page, and the existing mapper's slots/nested-charge/drone/fighter/cargo semantics. | T13, T14 |
| AC10 | Missing character/ship, auth denial, failed inventory, and later-page failures leave previous evidence intact and report failure with no partial save. | T15, T16, T17 |
| AC11 | A successful hull-only inventory snapshot is distinguishable from a failed read and carries the empty-modules limitation and qualified success message. | T18 |
| AC12 | Reference capture retains reference confidence/limitations; legacy rows are Inferred when derivable; confirmation captures fresh current data rather than relabeling an old snapshot. | T19, T20 |
| AC13 | No success is shown before persistence completes. Failed writes preserve prior evidence; a subsequent derivation failure is reported separately from the successful save. | T04, T11, T13, T24 |
| AC14 | Saved fits round-trip under the correct encounter key; attachment/replacement preserves killmail, victim fit, correlation and search state, with one current pilot-fit ledger fact. | T21, T22 |
| AC15 | Pilot-fit status and overall score follow actual derivation coverage/skills and existing denominator rules; saving is not an automatic Complete or fixed +30 score. | T23 |
| AC16 | Real provider invalidation refreshes the checklist and M5 pilot defense coherently while retaining observed incoming damage and exposing unavailable calculations honestly. | T24, T28 |
| AC17 | Fit attachment causes no automatic AI analysis or killmail search. Historical report provenance stays unchanged; the additional banner prompt uses the ≥10-point rule. | T25, T35 |
| AC18 | Explicit re-analysis retains imported/captured pilot evidence through matched, no-match, and no-character enrichment refresh paths and supplies it to the AI boundary. | T26 |
| AC19 | Failed re-analysis preserves the prior cached report and the newly attached fit; retry can use that evidence. | T27 |
| AC20 | Expected success and categorized error messages follow §3.3; a corrected retry clears the failure state and can succeed. | T12, T34 |
| AC21 | Pending attachment shows a scoped busy state and prevents duplicate/competing fit saves; explicitly requested analysis waits for it and refresh cannot lose the final saved fit. | T30 |
| AC22 | Navigation/disposal during dialog or async work produces no framework/ref-after-dispose errors, late snackbar on another screen, or cross-encounter mutation. | T29 |
| AC23 | Fit-related identity/provenance and errors show names or honest unknown labels, never raw numeric EVE type/character IDs or transport traces. | T33, T34 |
| AC24 | Loading/error checklist states, 360px and desktop layouts, 200% text, and long EFT content remain usable; evidence quality never disables the existing Analyze With AI gate. | T31, T32, T36 |

## 5. Test scenario matrix

**Layers:** W = real screen/widget interaction; I = service/provider/storage integration;
D = focused domain/service compatibility. A W+I case must cross the real persistence
boundary, not replace the operation with a counter-only fake. **Gap** indicates a known
or likely baseline deficiency from source inspection, not an executed failure report.

### 5.1 Manual import — T01–T12

| ID | Trigger and fixture | Required observation | Layer / baseline note |
| --- | --- | --- | --- |
| T01 | Missing/Inferred row, before analysis and on cached AAR; tap Import Fit | Real Import Pilot Fit dialog, EFT hint, multiline entry and buttons; correct encounter target | W |
| T02 | Type text, then Cancel; separately barrier-dismiss/Escape | No service call/save/snackbar or evidence/report mutation | W |
| T03 | Submit empty, spaces, tabs/newlines | Dialog closes; no import call or notification; original evidence remains | W |
| T04 | Known hull plus supported modules/drone entries; delayed save | Before completion no success; after real save, exact fit metadata/content, success snackbar and provider refresh | W+I |
| T05 | Leading/trailing whitespace and CRLF; intentional blank slots/header-only; encounter has no character ID | Supported fits persist correctly using local SDE; no auth/assets prerequisite; empty fit is not a parser-loss case | W+I, parameterized |
| T06 | Missing/broken header, unknown hull, resolved non-ship type as header | Failure feedback, no saved fit, prior reference/failed-fit evidence unchanged | W+I; non-ship validation Gap |
| T07 | `[Rifter, PvP: Armor]`; control fixture with supported DNA string | EFT reaches EFT parser and saves correct name/content; real DNA still works | W+I; EFT routing Gap |
| T08 | Known hull plus mixed known/unknown modules, all unknown modules, or unknown/malformed stacked entries | Reject the attachment; no discarded supplied items disguised as a confirmed fit; useful message | W+I; validation Gap |
| T09 | Known module with `, Ammo` suffix currently ignored by parser | Reject unsupported loaded-ammunition input before saving, with specified explanation; no silent charge loss | W+I; validation Gap |
| T10 | Missing/unready/failing local SDE or parser dependency | No crash/save/success; local-data or validation error according to available cause; usable retry after recovery | W+I |
| T11 | Valid input with repository save failure; existing evidence seeded | Failure snackbar, no success or false score change; old row remains loadable | W+I |
| T12 | Invalid nonempty submit followed by reopening dialog and valid submit | Dialog is closed on first error; corrected attempt saves once, shows success, and supersedes stale failure feedback | W+I |

### 5.2 Snapshot capture and reference compatibility — T13–T20

| ID | Trigger and fixture | Required observation | Layer / baseline note |
| --- | --- | --- | --- |
| T13 | Tap Use Current Fit in both pre-analysis and cached-report views; current ship with fitted assets, drones/fighters/cargo; delayed responses | Confirmed evidence maps supplied snapshot faithfully, saves once, and emits exact normal success after save | W+I |
| T14 | Assets on two pages, nested charge on later page, unrelated ships/characters; global selected character differs | Requests use encounter character and every page; only current ship contents map; nested charge retained | W+I |
| T15 | Asset first-page or later-page exception | No partial fit save; existing evidence untouched; asset failure feedback; no success | W+I |
| T16 | Encounter has null character ID while another character is selected | Capture fails before ESI calls with matched-character feedback; Import Fit still works with local SDE | W+I |
| T17 | Null ship, explicit missing-token/401/403 error, or ship-client transport failure collapsed to null | Correct distinct message where cause exists; no assets request after ship failure; preserve prior fit | W+I; error-format Gap |
| T18 | Complete successful inventory is empty or contains no modules parented to current ship | Hull-only snapshot, explicit persisted limitation and qualified success; never treated as request failure | W+I; empty-feedback Gap |
| T19 | Direct service `confirmed:false`; reopen seeded reference evidence on live screen | Reference source/confidence/timestamp/limitation round-trip; Inferred when derivable; both live attachment CTAs; no legacy snapshot button | I+D+W; no call to private false handler |
| T20 | Stored reference for ship A; current ESI ship now B; tap Use Current Fit | New confirmed snapshot is ship B with new provenance; old snapshot is not simply relabeled | W+I |

### 5.3 Persistence, reactive evidence, and re-analysis — T21–T30

| ID | Trigger and fixture | Required observation | Layer / baseline note |
| --- | --- | --- | --- |
| T21 | Import/capture, dispose provider scope, recreate it over persisted test storage; second encounter seeded | Fit source/confidence/content reload; second encounter unchanged; no auto AI or discovery | W+I |
| T22 | Replace an existing fit in service, and through reachable Missing/Inferred UI; enrichment has killmail/victim/correlation/search fields | Pilot fit and single stable pilot-fit fact update; unrelated facts/unknowns and enrichment fields survive | I + W where reachable |
| T23 | Real scorer after Missing→confirmed known skills, All V, unresolved dogma module, and reference capture | Complete/Partial/Partial/Inferred with 30/15/15/9 earned fit points; declared overall score oracle, not an arbitrary +30 assertion | I+W |
| T24 | Save succeeds, then derivation/provider refresh is delayed or fails | Save success remains truthful; refreshing/failed evidence is separate; no fabricated Complete/0% or stuck stale success state | W+I |
| T25 | Cached report, fit attachment improves score; boundary +9/+10; same-score fit change; legacy snapshot absent | Original report snapshot unchanged; extra banner only at ≥10; command-strip action still works in all cached cases | W+I for attachment, W for threshold boundaries |
| T26 | Real explicit re-analysis after manual import with matched/no-match/no-character outcomes; after confirmed capture with matched/no-match outcomes | Updated fit survives forced enrichment refresh in storage, derivation inputs, and fake AI client's actual received evidence; null-character variant applies only to manual import | W+I; critical retention Gap |
| T27 | Same lifecycle, but fake AI returns failure, then success on retry | New fit retained, old cached report retained after failure, retry uses fit and replaces report only on success | W+I |
| T28 | M5 incoming cards already present; import/capture changes pilot defense | Same incoming amounts/vectors and source attribution; EHP/fit provenance update from newly persisted pilot evidence without AI | W+I; do not override final matchup/assessment results |
| T29 | Leave route while dialog, asset fetch, or save is pending; open another encounter | No disposed-controller/ref/setState errors or late snackbar on new route; a started save retains its original encounter key only | W+I; lifecycle Gap to probe |
| T30 | Slow save; repeated/competing attachment; separately request analysis while save is pending and interleave enrichment refresh | One in-flight attachment, no premature success; requested analysis waits and consumes new fit on success or previous evidence on failure; delayed refresh cannot overwrite final pilot fit | W+I; concurrency Gap |

### 5.4 Presentation and availability — T31–T36

| ID | Trigger and fixture | Required observation | Layer / baseline note |
| --- | --- | --- | --- |
| T31 | Initial checklist loading/error and reload with prior assessment | Existing skeleton/unavailable/refresh behavior; no invented actions or scores; Analyze With AI gate remains available | W |
| T32 | Import dialog at 360px/desktop, 200% text, long multiline EFT; keyboard focus/Tab/Escape | No overflow or inaccessible actions; scrollable/editable input, working focus and cancellation | W |
| T33 | Snapshot types/names resolve, load, fail, recover; unresolved module details | Fit-related UI uses names or Unknown ship/item; no `Type #…` or numeric character fallback in exercised surfaces | W+I; existing raw-label Gap |
| T34 | Known FormatException, explicit auth error, assets transport failure, and unknown save error | §3.3 categorized feedback, no raw IDs/transport traces; error logged via shared feature logger; no success notification | W |
| T35 | Open checklist, import, capture, reload, expand M5 details without Analyze/Re-analyze | Zero AI-analysis/killmail-discovery calls caused by these actions; normal asset calls occur only on capture | W+I |
| T36 | Missing/Inferred/Partial/Complete states and default score ≥90 collapse on both screen views | Actions match shipped state policy; user can expand checklist; no resurrected controls; low score does not block analysis | W |

## 6. Handoff to Test-Author and Plan

### 6.1 Fixture and override strategy

- Use the real `AnalysisMultiPaneScreen`, checklist, `CombatEnrichmentService`,
  `CombatEnrichmentRepository`, and in-memory Drift/SDE databases for the core journeys.
  Seed known ship/module/group/dogma records and deterministic skill data. Use a known
  fitted module whose SDE data materially changes defense so T28 detects stale inputs.
- Fake ESI responses at the client boundary: current ship, asset pages, explicit errors,
  and discovery outcomes. Keep asset mapping and persistence real. Never use live
  OAuth, credentials, ESI, zKill, or AI in these automated tests.
- A fake analysis service is sufficient for a dispatch-only test. T26/T27 require the
  **real analysis/enrichment refresh flow** with a fake Codex client that records the
  actual fit it receives and returns deterministic success/failure.
- Override upstream data and expensive unrelated services, not the final
  `aarEvidenceAssessmentProvider`/`aarIncomingMatchupsProvider` when testing refresh.
  Controlled derivation fakes can isolate score combinations in T23, but T04/T13/T28
  need a representative real SDE/derivation path. Do not manufacture a Complete result
  merely because a callback was invoked.
- Reuse the exact `ParsedCombatEncounter` instance for Riverpod family overrides.
  Current family keys use object identity. Hold persistence independent of provider
  scope when testing reopen; after disposal, recreate providers over the same test DB.
- Use completers and explicit pumps for delayed states. Do not use unbounded
  `pumpAndSettle` while an indeterminate spinner or unresolved future is intentional.
  Dispose screens before closing their databases, and check `tester.takeException()`.
- Test missing auth separately from missing encounter identity, empty inventory,
  partial pagination, and unresolved presentation names. They are different failures.
  For error mapping, fake a cause the actual client can provide rather than claiming
  it can recover a cause already collapsed to null.

**Score oracle:** with all dimensions available and all other dimensions fixed at
Complete, Missing pilot fit yields 70%, Inferred 79%, Partial 85%, Complete 100%.
These are overall scores; the fit's earned contributions are 0/9/15/30. A second
fixture with unavailable dimensions must use the reduced denominator. The existing
49→79 screen fixture can remain a compatibility test; it is not the universal outcome.

### 6.2 Suggested work split and dependency order

| Unit | Responsibility | Dependencies / parallelism |
| --- | --- | --- |
| U0 | Review this product contract; establish common fixtures and expected RED cases from source gaps | Sequential prerequisite for shared harness changes |
| U1 [P1] | Import dialog and AAR input acceptance coverage, T01–T12 | Can run alongside U2 after fixture interfaces stabilize |
| U2 [P1] | Capture/assets/reference integration coverage, T13–T20 | Separate file ownership from U1 |
| U3 [SEQ] | Persistence, provider refresh, and real re-analysis tests, T21–T30 | Uses U0 fixtures and settled service behavior; retention fix must precede final green verification |
| U4 [P2] | Presentation/lifecycle/accessibility coverage and existing-suite regression integration, T31–T36 | Can run alongside stable U3 cases; coordinate shared screen fixtures |
| U5 [SEQ] | Resolve exposed defects, independent review, focused tests/analyze, macOS spot-check, journal closeout | All required tests pass; failures are not converted into expected behavior |

Suggested test home:
`test/features/combat_analyzer/presentation/analysis_multipane_fit_evidence_test.dart`
for the new screen journeys, plus focused additions to existing service/persistence
suites. Reuse current mapper/parser unit suites rather than duplicating every mapping
permutation in the widget suite. Names and file boundaries are Plan's responsibility;
assign ownership before parallel editing of shared helpers.

**Known likely RED work for Plan:** EFT-vs-DNA routing; accepting dropped entries or
non-ship hulls; unsupported charge rejection; empty-snapshot notice; categorized errors;
attachment concurrency/lifecycle guards; fit preservation through forced enrichment
refresh. Keep fixes scoped to these journeys. Source inspection has not established
which lifecycle cases fail at runtime; Test-Author must verify, not pre-label them green.

### 6.3 Scope limits and completion evidence

This item does not add an editor, multi-fit comparison, a new snapshot UI, a new auth
flow, automatic re-analysis, new evidence weights, or a new prompt/DB schema. Full
fitting-language support and a repository-wide raw-ID cleanup are separate work;
the exercised fit-attachment surfaces still must meet the name-resolution contract.
An explicitly empty fit is supported; a silently truncated fit is not.

The RED handoff lists test IDs, expected failures and grounded reasons, plus any
missing production seams. GREEN evidence records focused Flutter tests, related
existing evidence/parser/mapper/service regressions, and `flutter analyze`. Confirm
critical save-failure, retention, no-auto-analysis, and encounter-isolation paths rather
than chasing assertion counts. Honor the repository's coverage requirements and run
broader suites when shared parser/provider changes warrant them. Spot-check dialog,
snackbar, and checklist behavior on macOS.

Keep the queued item open until those tests and necessary fixes are verified. A product
handoff alone does not close it. Capture confirmed parser/cache findings in the journal
with this specification; archive the queued item as SHIPPED only with implementation
and verification evidence. This document reports source review, not executed test results.
