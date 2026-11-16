# Learnings - Mimir

> **Empirical findings + mechanisms + fixes + validations.** When something
> turns out to be true that was not obvious about Mimir, Flutter, EVE APIs,
> combat logs, SDE, zKill, Codex/AI integration, or local macOS behavior, it
> goes here.
>
> **Append new entries to the top.** Most-recent first. Format:
>
> ```markdown
> ## YYYY-MM-DD
>
> ### Short descriptive title
>
> **Author.** {agent-name}
> **Context.** One paragraph framing the situation.
> **Evidence.** Specific file, test, command, log excerpt, issue, commit, or plan.
> **Mechanism.** Why it happened or why it is true.
> **Fix (or queued).** Concrete action, commit hash, or QUEUED.md ref.
> **Validation.** What proved the fix.
> **What surprised.** Optional note on the mistaken prior assumption.
> **Generalizable rule.** The lesson stripped from this specific incident.
> **Refs.** Cross-links to DECISIONS / QUEUED / narratives / related entries.
> ```
>
> Not every entry needs every subheader, but evidence and mechanism matter.
> If a prior learning is invalidated, correct it inline and move the old version
> to `ARCHIVE.md` as SUPERSEDED. Never silently overwrite history.

---

## 2026-11-16

### An assumption about generated data belongs in the generated-data invariant test, not in the design prose

**Author.** Muse Code (parent repair pass over the DNA-import workflow)
**Context.** DNA import classifies bare type ids into slots with the shared first-match slot helper. The design recorded that this is safe because no bundled catalogue row carries more than one slot effect — and then nothing enforced that fact.
**Evidence.** `assets/sde/fitting_types.json` (25,818 rows; reviewer scripted the whole file: 0 rows with more than one slot effect, all 48 subsystem-category rows carry exactly effect 3772, 0 module-category rows carry 3772); `src/fitting/dna.rs` (classification accepts any module/subsystem row whose effects yield any slot, where the strict Flutter adapter additionally required unanimity and a subsystem slot for subsystems); `src/names/fitting_types.rs` (`bundled_catalogue_invariants` pinned only name shape before this repair).
**Mechanism.** Data a script regenerates will eventually change under the code that consumes it. An assumption written only in a design document decays silently: the next SDE refresh could introduce a dual-slot-effect type and every importer would quietly change its slot, with all tests green because the tests use the same regenerated file. The invariant has to live where regeneration is checked.
**Fix (or queued).** `bundled_catalogue_invariants` now asserts at most one slot effect per row, subsystem rows carry only effect 3772 (or none), and module rows never carry 3772 — so a future catalogue that breaks the assumption fails tests loudly at regeneration time. The same repair dropped a byte-order mark after leading whitespace in both parsers and the format router, matching Dart `trim()` semantics the Flutter parsers relied on.
**Validation.** Extended `bundled_catalogue_invariants` and `routing_colon_in_fit_name_and_no_fallback` (padded-BOM cases for both routes), full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-fittings-dna-import`, and a parent-inspected demo Fittings screenshot.
**Generalizable rule.** Every "the data never does X" claim a design relies on gets an assertion in the generated-data invariant test in the same change; prose records why, the test enforces it.
**Refs.** `docs/fittings-dna-import-design.md`; `src/names/fitting_types.rs` (`bundled_catalogue_invariants`); `src/fitting/dna.rs`.

### A refusal table inline in an imperative shell function is correct code with no test that can catch its deletion

**Author.** Muse Code (parent repair pass over the fittings-write workflow)
**Context.** The fittings-write adversarial review mutation-tested the slice and killed the landing identity guard, the transport classification, and the first-sign-in scope wall — then found three guards no test could kill: disabling the single-flight refusal, the token-metadata scope pre-check, or the demo refusal in `start_fitting_write` left all 401 library tests passing.
**Evidence.** Review finding F1 in the fittings-write workflow synthesis (each guard gated with `false &&`, full suite green each time); `src/app/shell.rs` (`start_fitting_write` held seven early-return refusals inline, reachable only through a fully wired shell — the same reason every prior slice's shell logic that mattered was extracted into pure helpers like `decide_fitting_write_landing`, which the mutations did kill).
**Mechanism.** Guards written as sequential early returns inside a method that needs live backends, a runtime, and a database lock cannot be unit-tested as a table, so their only coverage is inspection — and inspection does not survive refactoring. The three unkillable guards were precisely the slice's headline invariants (at most one write per confirmation, zero HTTP without the scope, demo cannot write), so the most safety-critical code had the weakest proof.
**Fix (or queued).** The refusal decision is now the pure `decide_fitting_write_start` over a captured input struct, with locked wording on the refusal enum; the shell computes inputs (reading token metadata only after the pre-scope refusals pass) and a table test pins every refusal kind plus precedence. The same pass fixed the review's rate-limit nit: a missing reset header arrives as 0 and no longer renders "wait 0 seconds".
**Validation.** New tests `fitting_write_start_refusals_follow_design_order` and the zero-reset rate-limit pin in `src/app/shell.rs`, full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-fittings-write`, and a parent-inspected demo Fittings screenshot. Live write behavior remains unverified against a real EVE account.
**Generalizable rule.** Any ordered refusal/precedence table that guards a side effect belongs in a pure function over plain inputs, table-tested per row; if deleting a guard leaves the suite green, the guard is documentation, not protection.
**Refs.** `docs/fittings-write-design.md` section 7.2; `src/app/shell.rs` (`decide_fitting_write_start`, `FittingWriteRefusal`, `start_fitting_write`).

### First ESI writes: an unanswered write is an unknown outcome

**Author.** Muse Code (fittings-write workflow, integrator)
**Context.** Saving and deleting character fittings are Mimir's first writes to EVE's ESI API (the game's public API). Every earlier call was a read, where a lost response costs nothing but a repeat.
**Evidence.** `docs/fittings-write-design.md` sections 7.4 and 9.1; implementing commits `4de5a75` (`src/esi/endpoints.rs` `classify_write_error`, `save_character_fitting`, `delete_character_fitting`), `5c49e4c` and `30e69b9` (`src/app/shell.rs` `start_fitting_write` and the `FittingWriteDone` landing, `src/ui/fittings.rs` confirmations) on branch `feat/rust-fittings-write`; mock request-capture tests prove the POST body bytes and the DELETE 204 handling, and that a 500, transport failure, or malformed 201 classifies as unknown rather than failed.
**Mechanism.** Reads can be repeated harmlessly, so "no answer" and "refused" collapse into one retryable failure. A POST whose response was lost may already have committed on the server: there is no idempotency key in this API, so an automatic retry is a duplicate-fitting generator, and reporting flat failure would be a lie the user then acts on by saving again by hand. Transport, 5xx, and success-body decode failures on a write therefore form a third class beside success and refusal — outcome unknown — which is never retried automatically and is reconciled only by refreshing server state through the existing read path and letting the user look.
**Fix (or queued).** `classify_write_error` maps every typed error arm to NotSent, Definitive, Unknown, AlreadyGone (delete 404), or RateLimited; the shell runs one write at a time globally, drops a result whole if the active character changed while it was in flight, and refreshes the fittings list after success, already-gone, and unknown outcomes instead of editing the list locally. Success is claimed only from the 201 receipt's returned fitting id.
**Validation.** Full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` / `cargo build` and a bounded headless demo smoke on the branch; the write path itself has not been live-verified against a real EVE account (the README says so).
**Generalizable rule.** For any non-idempotent write, "we did not hear back" is its own outcome class, distinct from refusal: never auto-retry it, never report it as failure, and reconcile by re-reading server state.
**Refs.** `docs/fittings-write-design.md` sections 7.4, 9.1, 9.2; `src/esi/endpoints.rs` (`classify_write_error`); `src/app/shell.rs` (`decide_fitting_write_landing`); DECISIONS 2026-11-16 write-scope entry.

### The pinning table must enumerate every typed refusal, or the missing one becomes head-of-line blocking

**Author.** Muse Code (parent repair pass over the structure-names workflow)
**Context.** The entry below locked which structure-lookup failures may pin an id: scope-present 403 and non-displayable names pin; 401 and transport failures abort unpinned. Adversarial review then probed the one typed refusal the design table never listed — 404.
**Evidence.** `src/error.rs` (`EsiError::from_status` maps 404 to `EsiError::NotFound`); `src/names/resolver.rs` and `src/app/shell.rs` (both structure loops matched only `Reauthorize` as pin-and-continue, so a 404 fell into the abort arm: the pass stopped, the id stayed unpinned, and because batches are ascending the same lowest 404 id was retried first on every pass while larger ids were never attempted — the reviewer's probe made exactly 1 request for 2 ids); `src/ui/assets.rs` (asset items inside ships/containers carry parent item ids as `location_id`, and any such id at or above `STRUCTURE_ID_MIN` is looked up as a structure, so 404-class ids are routine input, not exotic).
**Mechanism.** The design reasoned about failures by story ("denied", "token-class", "transport") instead of by enumerating the typed error variants the client can actually return. An unlisted variant silently inherits the abort arm, and abort-without-pin plus deterministic ascending order converts one permanently failing id into a permanent gate in front of every other id — the precise dual of the stale-pin trap in the entry below.
**Fix (or queued).** 404 is now a definitive per-id refusal (pin and continue) in both loops, like 403; destroyed structures and parent item ids stay "Unknown Location" without blocking siblings. The same repair closed two persist-side gaps the review noted: batch `/universe/names/` answers are filtered by `is_displayable_name` before the `universe_names` upsert, and a lone `+`/`-` is no longer displayable.
**Validation.** New regression tests `structure_not_found_pins_and_continues_to_siblings` (observed failing first: 1 request instead of 2) and `numeric_batch_name_is_not_persisted`, extended `displayable_name_matrix`, full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-structure-names`, and a parent-inspected demo Assets screenshot. Whether live ESI returns 404 or 403 for invalid/destroyed ids is unobservable here; the code is now safe under either.
**Generalizable rule.** When a pass classifies failures into pin/abort/retry, enumerate the client's typed error variants exhaustively in the design table; any variant left to a default arm must be proven safe under both pinning choices, because deterministic ordering turns one wrong default into permanent blocking.
**Refs.** `docs/structure-names-design.md` section 6.3; `src/names/resolver.rs`; `src/app/shell.rs`; `src/error.rs` (`EsiError::from_status`).

### A failed lookup caused by the caller's missing permission must not be pinned as a fact about the id

**Author.** Muse Code (structure-names workflow, integrator)
**Context.** Player-structure locations always read "Unknown Location": `src/names/resolver.rs` routed structure ids through an unauthenticated public structure lookup that EVE's ESI API (the game's public API) rejects, while the authenticated per-character lookup `get_structure_for_character` in `src/esi/endpoints.rs` had zero callers and no scope group in `src/config.rs` contained `esi-universe.read_structures.v1`. Fixing the endpoint alone would still have left a quieter trap: the resolver records ids it cannot resolve in a session pin set so it does not retry them every frame.
**Evidence.** `docs/structure-names-design.md` sections 3, 6, and 16 (endpoint and scope grounded in the retired Flutter sources at ed698d3, plus the pinning table); `src/names/resolver.rs` (`resolve_missing_esi(..., structure_character_id: Option<i64>)`, `mark_unresolved`, `forget_unresolved_structures`, `MAX_STRUCTURE_LOOKUPS_PER_PASS`); `src/app/shell.rs` (`BackendMsg::StructuresResolved` identity guard, both `forget_unresolved_structures` re-arm hooks at character switch and step-up login); the stale-unresolved regression test (a pass with no structure character makes zero requests and leaves the id offered, then a pass with one resolves it).
**Mechanism.** A pin set treats "we could not resolve this" as a property of the id, but some failures are properties of the caller at that moment — no active character, the structures scope not yet granted, a dead token, a network error. Pinning those makes a later permission grant appear to do nothing: the user approves the step-up, yet every structure stays "Unknown Location" until restart, because nothing ever retries the pinned ids. Only failures that are genuinely about the id — the character holds the scope and ESI still refuses (403, cannot dock there), or the returned name is empty or numeric — may be pinned; every caller-context failure must leave the id eligible for the next pass, and known context changes (character switch, completed step-up) must clear structure pins so denied ids get one fresh attempt under the new context.
**Fix (or queued).** Branch `feat/rust-structure-names` (commits `45753fb`, `2ab761e`, `efa8456`, `335f293`): the unauthenticated `get_structure` is deleted and structures resolve through the authenticated lookup bounded to 10 per pass, pinning only on scope-present 403 and non-displayable names, with a token-metadata pre-check that makes zero HTTP calls when the scope is absent and shows the step-up offer from Assets instead. Resolved names persist in the existing `universe_names` cache under category `structure`; first sign-in scopes are untouched.
**Validation.** Full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` / `cargo build` on the branch, mock-HTTP tests for the pinned/unpinned matrix and the 12-id/10-request fan-out bound, and a bounded headless `--demo` smoke. The live step-up path has not been verified against a real EVE account.
**Generalizable rule.** Negative caches must record only failures that are facts about the key; a failure caused by the caller's context (permissions, identity, connectivity) is a fact about the moment, and pinning it silently disables the very recovery the user is later offered.
**Refs.** `docs/structure-names-design.md`; `src/names/resolver.rs`; `src/app/shell.rs`; `src/config.rs` (`EveConfig::STRUCTURE_SCOPES`).

### Delimiter heuristics lose to exact catalogue names, and trim parity includes the byte-order mark

**Author.** Muse Code (parent repair pass over the fittings-import workflow)
**Context.** Adversarial review of the EFT importer scanned the bundled catalogue end to end and found real item names colliding with the parser's punctuation rules, plus one invisible character where Rust and Dart whitespace rules disagree.
**Evidence.** `assets/sde/fitting_types.json` (25,818 types; 17 published names contain a comma, for example `Exotic Dancers, Male`, and one starts with `[`: `[CNS] Kiirasha Final Broadcast Fragment`); `src/fitting/eft.rs` (`parse_eft` treated any comma as a loaded-charge separator and any leading `[` as a bracketed line before name lookup, so `Exotic Dancers, Male x5` reported "no item has this exact name" about an item in the bundled data; and Rust `trim()` keeps U+FEFF while Dart `trim()` strips it — verified against the installed Dart runtime and both Flutter parser bodies at ed698d3 — so a byte-order-mark paste the Flutter parsers accept was rejected whole with an invisible cause); `src/ui/fittings.rs` (the fatal-error label rendered ahead of the per-character owner guard its own comment describes).
**Mechanism.** Grammar heuristics classify by shape, but the catalogue is the authority on what names exist: when the two disagree, shape-based classification produces a confidently wrong reason, which is worse than an unresolved line because it tells the user the item does not exist. Separately, porting "trim each line" across languages is not semantics-preserving until each language's whitespace set is checked; U+FEFF is whitespace to Dart and not to Rust.
**Fix (or queued).** A line (or its stacked name part) that resolves exactly in the catalogue bypasses the comma and bracket heuristics and takes the stacked/plain path; a leading U+FEFF is stripped once before parsing, matching Dart trim semantics (a BOM-only paste is now the honest "empty" failure); `x-1`/`x+5`/non-ASCII-digit quantities after a resolvable name now report the quantity reason instead of "unknown name"; the view's error label renders only for its owner. The exporter's pre-existing comma/bracket stripping of item names is unchanged, so those 18 names still do not round-trip through Mimir's own export; that asymmetry is named in the pull request rather than silently kept.
**Validation.** New parser tests `leading_byte_order_mark_is_dropped` and `exact_names_with_delimiters_import_as_cargo` (including a duplicate body header still reporting as bracketed), extended `quantity_rules_are_strict`, full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-fittings-import`, and a parent-inspected demo Fittings screenshot.
**Generalizable rule.** In any name-based format, try the exact-name dictionary before punctuation heuristics, and verify whitespace definitions per language when porting trim-like calls; a heuristic may classify only what the dictionary does not claim.
**Refs.** `docs/fittings-import-design.md`; `src/fitting/eft.rs` (`parse_eft`, `name_resolves`, `looks_like_bad_quantity`); `src/ui/fittings.rs`.

### EFT slot identity must come from dogma effects, never from blank-line position

**Author.** Muse Code (fittings-import workflow, integrator)
**Context.** The retired Flutter importer inferred a module's slot from which blank-line-separated EFT section it sat in, falling back to high slot when position said nothing. The Rust EFT import had to round-trip with this repo's own EFT exporter, which forced a different rule.
**Evidence.** `docs/fittings-import-design.md` sections 5.4 and 9 (exporter omits empty sections, so section position is not preserved across an export); `src/fitting/eft.rs` (slot inferred only from the bundled catalogue's dogma slot effects, in the Flutter `_slotTypeFor` order; a blank-line-independence test imports one fit with no blank lines and with scrambled sections to identical results); `src/names/fitting_types.rs` and `assets/sde/fitting_types.json` (per-type slot-effect subset bundled for exactly this).
**Mechanism.** An exporter that omits empty sections makes section position a lossy signal: a fit with no rigs re-imports with every later section shifted up one group, so position-based slot inference silently reassigns modules. Dogma effects are a property of the type itself, so they survive any section layout the pasted text happens to use.
**Fix (or queued).** Import classifies each module line by its catalogue slot effects only; a module with no slot effect is reported as a per-line issue instead of being guessed into a slot, and blank lines carry no meaning at all.
**Validation.** Parser tests for blank-line independence and scrambled section order, plus the byte-identical export-to-import-to-export round-trip test, all pass on branch `feat/rust-fittings-import` under full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check`.
**Generalizable rule.** When an import format must round-trip with your own exporter, derive identity from data the exporter preserves verbatim; any signal the exporter is allowed to drop (empty sections, ordering, case) cannot carry meaning on the way back in.
**Refs.** `docs/fittings-import-design.md`; `src/fitting/eft.rs`; `src/ui/fittings.rs` (`fitting_to_eft`).

### A malformed-data test whose fixture is itself invalid proves nothing about the validations it names

**Author.** Muse Code (parent repair pass over the Exploration workflow)
**Context.** Adversarial review of the Exploration reference slice proved the bundled data clean by independent re-extraction, then falsified its own malformed-input test: the test fixture computed effect beacon IDs from family-name lengths, and two families share length 8, so the fixture failed the loader's duplicate-beacon check before any mutation was applied.
**Evidence.** Review probes in the Exploration workflow synthesis (an unmutated copy of the fixture was rejected with `duplicate effect beacon id`); `src/names/exploration_ref.rs` (`minimal_valid_json` used `90000 + s * 100 + fam.len()`, `from_json` duplicate checks precede `validate()` row-count, effects-count, and mass checks, and the truncated case used a string replace that the compact JSON never matched). The same pass probe-confirmed `i64::MAX` lifetime minutes passing validation and panicking in `lifetime_seconds`, an empty catalogue loading as valid, and a roughly 2.4 ms double deep clone of the 2,631-system catalogue per frame in `src/ui/exploration.rs`.
**Mechanism.** Error-path tests assert only "is an error"; when the baseline fixture already errors for an unrelated reason, every subcase stays green even if the validation it names is deleted. Validation order turns a fixture bug into silent coverage loss, and nothing fails loudly because the test's only oracle is the error bit.
**Fix (or queued).** The fixture now enumerates families for unique beacon IDs and the test first asserts the unmutated fixture loads, each mutation goes through `serde_json::Value` (the 35-effects case sets agreeing row counts so only the effects-must-be-36 check can reject it), lifetime minutes above `i64::MAX / 60` are rejected in `validate()` while `lifetime_seconds` saturates, empty types/systems catalogues are rejected, destination chips narrow groups to matching variants only, and the catalogue is shared behind `Arc` so frames clone a handle, not the data.
**Validation.** New tests `lifetime_seconds_saturates_instead_of_overflowing` and `destination_narrowing_drops_non_matching_variants_of_a_code`, extended `malformed_and_truncated_json_is_an_error_not_a_panic`, full `cargo test` (320 passed) / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-exploration-reference`, plus a parent-inspected demo Exploration screenshot (102 code groups, C729 at the archive-true 27 variants).
**Generalizable rule.** Every mutation-based rejection test must first assert its unmutated fixture is accepted; otherwise it cannot distinguish "rejected for the named reason" from "rejected for any reason at all".
**Refs.** `docs/exploration-reference-design.md`; `src/names/exploration_ref.rs`; `src/ui/exploration.rs`; `src/app/state.rs` (`ExplorationData`).

### Clipboard formats are a trust boundary: sanitize every interpolated name, cap every expansion

**Author.** Muse Code (parent repair pass over the saved-fittings workflow)
**Context.** Adversarial review falsified the new EFT exporter twice, both probe-confirmed: a resolved ship name containing brackets, a comma, and a newline corrupted the `[ship, fit name]` header structure, and a hostile slot quantity of 100,000 expanded into that many module lines on the Copy-as-EFT click (`i64::MAX` would hang the UI thread). No raw IDs leaked — the failures were structural, not naming.
**Evidence.** Review probes in the saved-fittings workflow synthesis; `src/ui/fittings.rs` (`fitting_to_eft` interpolated the ship name with only single-line collapsing, while the fitting name already went through header-grade sanitization, and the slot loop repeated each module line `0..clamped` times with no upper bound).
**Mechanism.** Export text is parsed by other tools exactly like rendered UI is read by people: every interpolated remote string is a framing risk, and every remote count is a resource bound. Sanitizing one field of a header, or clamping a count for display, does not bound the sibling field or the expansion site that repeats it.
**Fix (or queued).** Ship and item names in EFT output now get the same header-grade sanitization as fitting names (brackets and commas stripped, controls collapsed, digit-only ship names rejected), and slot-line expansion is capped at `MAX_EFT_SLOT_REPEATS` (16) per row with truncated rows disclosed once through the existing skipped counter.
**Validation.** New regression tests `eft_ship_and_item_names_cannot_corrupt_structure` and `eft_slot_quantity_expansion_is_capped` in `src/ui/fittings.rs`, plus full `cargo test` (292 passed) / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-fittings-library` in the repair commit, and a parent-inspected demo Fittings screenshot.
**Generalizable rule.** Any text built for another parser gets the same audit as rendered UI: sanitize at every interpolation site, and cap every repetition driven by a remote count, disclosing truncation through the channel the format already has.
**Refs.** `docs/fittings-library-design.md`; `src/ui/fittings.rs` (`fitting_to_eft`, `sanitize_header_name`, `MAX_EFT_SLOT_REPEATS`).

### Observed 403s outrank stored grant metadata, and every verbatim remote string needs its own rendering rule

**Author.** Muse Code (parent repair pass over the Planetary Industry workflow)
**Context.** Adversarial review found the Market-era stale-metadata trap one layer deeper: when persisted token metadata already claimed the planets scope, the PI Re-authorize button only ever took the already-granted shortcut and could never reopen the browser. The same review probe-confirmed two rendering leaks: an unparseable colony `last_update` rendered verbatim through a shared date helper, and an all-digit universe name longer than the `i64` range bypassed the numeric-name guard added for Market.
**Evidence.** Probe results in the PI workflow synthesis (already-granted trace through `src/app/shell.rs` `start_stepup_login`; `format_date_short("700000001")` and a 20-digit resolver name both rendered verbatim); `src/ui/widgets.rs` (`format_date_short` fell back to a truncated copy of its input), `src/names/resolver.rs` (`insert_with_category` rejected only names that *parsed* as `i64`), `src/demo/data.rs` (the demo seed failure branch never set the planetary load state).
**Mechanism.** Three different trust lessons share one shape: a stored claim, an input validation rule, and a rendering fallback were each treated as equivalent to observed behavior. Stored scope claims are a cache, not an observation; parseability is not the same as display-safety for either numbers or dates; and a field is only guarded at the exact sites where the guard is applied.
**Fix (or queued).** The already-granted shortcut is bypassed whenever a section for one of the requested scope groups has already returned 403 this session, so the browser flow the user asked for always remains reachable. Unparseable dates render the fixed words `date unavailable`. The resolver now rejects digit names of any length (including a sign prefix) instead of only `i64`-parseable ones. The demo seed failure branch sets the planetary error like every sibling section.
**Validation.** Extended regression tests `insert_rejects_numeric_names_so_lookup_never_returns_a_raw_id` (beyond-i64 and signed numerics) and the `format_date_short` cases in `src/ui/widgets.rs`, plus full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-pi-port` in the repair commit. Shell sign-in flows have no test harness in this repo, so the bypass condition is code-inspected with log evidence.
**Generalizable rule.** When stored claims contradict observed responses, observed responses win; when input must never render raw, validate the rendered *form* (all digits, any length; a parsed date), not one parse path that happens to reject today's examples.
**Refs.** `docs/pi-port-design.md`; `src/app/shell.rs`; `src/ui/widgets.rs`; `src/names/resolver.rs`; `src/demo/data.rs`.

### A boundary fix does not sanitize the fan-out paths that reuse the original error value

**Author.** Muse Code (parent repair pass over the Industry workflow)
**Context.** Adversarial review found two blockers in the Industry slice the green suite missed: a negative successful-runs count rendered raw, and server error text still reaching the Industry whole-view error panel even though per-section industry errors were already fixed wording.
**Evidence.** Review findings in the Industry workflow synthesis; `src/ui/industry.rs` (row construction clamped runs and efficiencies but copied `successful_runs` verbatim), `src/app/shell.rs` (the whole-refresh failure arm assigned the unchanged remote error message to the industry load state, while the two industry sub-fetches already used fixed wording).
**Mechanism.** Fixes applied at one construction boundary or one field do not propagate: every sibling field decoded from the same untrusted payload and every other apply path that forwards the same error value keeps the original defect until each is audited individually.
**Fix (or queued).** Successful runs clamp at row construction like their sibling counters, and the whole-refresh industry assignment uses fixed wording with the full error kept in the existing `[ESI]` warn log.
**Validation.** New unit test `job_rows_clamp_negative_successful_runs` in `src/ui/industry.rs` plus full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-industry-port` in the repair commit. Shell drain paths have no test harness in this repo, so the fixed-wording arm is code-inspected with log evidence.
**Generalizable rule.** When a review finds one untrusted field or error path, grep for every sibling field and every assignment of the same value before calling the class fixed.
**Refs.** `docs/industry-port-design.md`; `src/ui/industry.rs`; `src/app/shell.rs`.

### Category-only errors belong at every construction site, and a short-circuit must still drive the state it gates

**Author.** Muse Code (parent repair pass over the Market workflow)
**Context.** Adversarial review found one blocker and two raw ID minors in the Market slice: when stored scope metadata already claimed the market scope, the Re-authorize panel could loop forever, server error text could still reach Market section panels through SectionError messages, and numeric resolver names could render verbatim.
**Evidence.** Review findings in the Market workflow synthesis; `src/app/shell.rs` (the already-granted shortcut in `start_stepup_login` queued only the main refresh, which never touches market state; market and detail section errors were built as `message: e.to_string()`), `src/names/resolver.rs` (`insert_with_category` rejected only empty names), `src/ui/market.rs` (character-order remaining volumes were displayed unclamped).
**Mechanism.** A short circuit that skips the browser also skips the completion path that normally queues follow-up work, so gated state must be driven explicitly on every exit path. Sanitising one error type at the client boundary does not help when callers re-wrap the full error text per section, and any remote string accepted into a name cache becomes display text wherever that cache is read.
**Fix (or queued).** The already-granted shortcut now also queues the market refetch when a type is selected; all market, assets, and character-detail section errors use fixed per-section wording with full detail kept in `[MARKET]`/`[CHAR]`/`[ASSETS]` warn logs; purely numeric remote names are rejected at resolver insert so word fallbacks render; negative remaining volumes clamp at both the shared helper and the row display.
**Validation.** New unit tests `insert_rejects_numeric_names_so_lookup_never_returns_a_raw_id` and `character_order_rows_clamp_negative_remaining` plus full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-market-port` in the repair commit. Shell flows have no test harness in this repo, so the refetch wiring is code-inspected with log evidence.
**Generalizable rule.** Audit every construction and ingestion site, not just the boundary that was fixed last time, and make every early-return path drive the same downstream state as the path it replaces.
**Refs.** `docs/market-port-design.md`; `src/app/shell.rs`; `src/names/resolver.rs`; `src/ui/market.rs`.

### Error strings are UI strings, and late async results need identity checks at apply time

**Author.** Muse Code (parent repair pass over the character-detail workflow)
**Context.** Adversarial review falsified the character-detail slice in three places the green suite missed: detail-section errors rendered verbatim in the Characters view could embed the raw numeric character ID, a late whole-refresh failure carried no character identity and overwrote the newly active character's detail error state, and a late successful refresh reinserted a removed character's dashboard summary (which the combined-wallet total then summed).
**Evidence.** Reviewer probe in the character-detail workflow synthesis drove the real `get_location`/`get_ship` endpoints and found the fictional ID 90000001 in every error string; `src/error.rs` (`NoTokens` display interpolated the ID), `src/esi/client.rs` (`send()` converted reqwest errors with URLs intact and prefixed decode errors with the request path), `src/app/shell.rs` (`BackendMsg::RefreshFailed` had no `character_id`; the `Refreshed` summary insert preceded the inactive-character guard and never checked the character still exists).
**Mechanism.** Error `Display` text crosses into load-state UI panels unchanged, so anything interpolated at construction (paths, request URLs, entity IDs) becomes user-visible. Separately, any asynchronous result applied without re-checking its subject at drain time applies to whatever state exists then — success and failure messages are symmetric hazards.
**Fix (or queued).** IDs and URLs are stripped at the single error-construction boundary in the ESI client (`without_url`, path-free decode message, generic no-tokens display); `RefreshFailed` now carries `character_id` and is ignored unless that character is active; summary insertion is skipped when the character no longer exists.
**Validation.** New `ui_facing_error_text_never_embeds_raw_character_id` unit test in `src/error.rs` plus full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/character-detail` in the repair commit. Shell drain paths have no test harness in this repo, so the identity guards are code-inspected with log evidence, not unit-proven.
**Generalizable rule.** Sanitise at construction, not at render: every error type whose text can reach a screen gets category-only display strings, and every late-arriving result re-validates its subject still exists and is current before mutating keyed or active state.
**Refs.** `docs/character-detail-design.md`; `src/error.rs`; `src/esi/client.rs`; `src/app/shell.rs`.

### Unverified token headers are log input, not log text

**Author.** Muse Code (parent hardening pass over the JWT verification review)
**Context.** Adversarial review of the JWT slice found zero bypasses but flagged that the token header's key id (`kid`) — attacker-influenced before any signature check — was interpolated raw into twelve tracing lines, so a `kid` containing newlines could forge additional log lines and an unbounded value could bloat them.
**Evidence.** Review observations in the JWT workflow synthesis; `src/auth/jwt_verify.rs` pre-fix `kid={}` interpolations in `usable_key` and `verify_with_keys` (duplicate/unknown/mismatch/verify-failure/issuer/audience/expiry paths).
**Mechanism.** Structured surrounding log text does not sanitize its interpolated values: any pre-authentication field reaches log files with whatever control characters it carries, and log consumers downstream cannot distinguish forged lines from real ones.
**Fix (or queued).** Every `kid` log site now renders through `kid_for_log` (debug-escaped, capped at 64 characters); key lookup still uses the original value, so verification behavior is unchanged.
**Validation.** New unit test `kid_for_log_escapes_and_caps_untrusted_kid` in `src/auth/jwt_verify.rs` plus full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/jwt-signature-verification` in the hardening commit.
**Generalizable rule.** Anything read before trust is established — headers, key ids, remote names — only reaches logs through an escaping, length-capped rendering; the raw value stays in logic paths where equality matters.
**Refs.** `docs/jwt-verification-design.md`; `src/auth/jwt_verify.rs` (`kid_for_log`).

### jsonwebtoken 12 validates expiry against the system clock only, so time rules must move into the caller when "now" is injected

**Author.** Mimir JWT verification workflow (Builder A, recorded by the integrator)
**Context.** The JWT design requires the pure verification core to evaluate `exp` (expiry) and `nbf` (not-before) at an injected `now` so tests can pin the 60-second leeway boundaries exactly, with no sleeps and no dependence on the host clock.
**Evidence.** `src/auth/jwt_verify.rs:297-303` sets `validation.validate_exp = false` and `validation.validate_nbf = false` with a comment recording why; boundary tests in the same file assert both sides of the leeway (`expired_and_leeway_boundary`, nbf exactly at now plus leeway accepted).
**Mechanism.** `jsonwebtoken` version 12 reads the system clock inside its own validation and offers no parameter to supply the current time. Leaving its time checks enabled would make the core's result depend on wall time, so boundary cases could not be tested deterministically and could disagree with the design formulas. The library still verifies the signature and enforces required-claim presence, issuer, and the client-id audience; the caller then applies the expiry and not-before formulas at the injected time.
**Fix (or queued).** Library time validation disabled, design time formulas applied in `verify_with_keys` immediately after decode (`src/auth/jwt_verify.rs:340-353`). A related version fact: an `alg=none` header surfaces as malformed rather than invalid-signature in this version, which the design test matrix permits.
**Validation.** The jwt_verify test module covers both sides of each boundary with fixed timestamps; full `cargo test` green on `feat/jwt-signature-verification`.
**Generalizable rule.** When a validation library owns a hidden input such as the system clock, either wrap that input or move the affected check into your own code; never let a library default silently own a boundary your design specifies.
**Refs.** `docs/jwt-verification-design.md` Sections 5 and 9; `src/auth/jwt_verify.rs`; DECISIONS 2026-11-15 JWT verification entry.

### A step-up grant is proven by the next successful data fetch, never by login alone; in-flight sign-in outlives UI intentions

**Author.** Muse Code (parent repair pass over the step-up OAuth workflow)
**Context.** Adversarial review of the scoped step-up sign-in confirmed three blockers the green suite missed: the Assets re-authorize panel cleared at login success before any refresh proved the grant, the returned token was checked only for the newly requested scope (so a previously granted scope could be silently dropped on save), and deleting a character during the up-to-300-second browser wait let the callback save fresh tokens for the removed character.
**Evidence.** Review traces in the step-up workflow synthesis; `src/app/shell.rs` (`StepUpLoggedIn` arm clearing `assets_needs_reauthorize`, scope-gain check against `requested_scopes` only, spawned callback task saving with no still-present re-check), `src/ui/characters.rs` (logout/delete buttons enabled while authentication (auth) is busy).
**Mechanism.** Each step was locally correct — login succeeded, the requested scope arrived, deletion deleted — but correctness lives in the ordering across an asynchronous gap: user intent (delete) and external results (token, refresh) can arrive in either order, and every consumer must re-validate its preconditions at apply time against the full expected end state, not just the delta it asked for.
**Fix (or queued).** The grant flag now clears only in the refresh-proven arm; returned scopes are validated against granted union requested before anything is saved; logout/delete are disabled and drain-guarded while auth is busy, and the callback task re-checks the character still exists in the database before saving tokens.
**Validation.** New unit test in `src/auth/oauth.rs` pins dropped-grant detection against the union; full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/stepup-oauth` in the repair commit. Shell and egui paths have no test harness in this repo, so the flag-timing and race guards are code-inspected with log evidence, not unit-proven.
**Generalizable rule.** For any multi-step external grant: validate the returned end state in full before persisting, clear "needs action" only when the protected operation succeeds, and re-check that the subject still exists at save time — or block destructive actions for the whole in-flight window.
**Refs.** `docs/stepup-oauth-design.md`; `src/app/shell.rs`; `src/auth/oauth.rs`; `src/ui/characters.rs`.

### Tolerant per-character sub-fetches must be reset at the switch boundary, and decoded quantities are untrusted arithmetic

**Author.** Muse Code (parent repair pass over the Assets workflow)
**Context.** Adversarial review of the Assets slice confirmed two blockers the green test suite missed: after switching characters, the previous character's assets could render as the new character's with a success status, and summing decoded quantities with plain `sum()` panicked on overflow in debug builds.
**Evidence.** Review probes in the Assets workflow synthesis; `src/app/state.rs` (`set_active_character` cleared nothing), `src/app/shell.rs` (tolerant assets error arm keeps `Ready` rows; `Refreshed` applied per-view data without checking `character_id` against the active character), `src/ui/assets.rs` (`group_assets`/`filter_groups` plain `Iterator::sum` over remote-decoded `i64` quantities; reviewer probe with two `i64::MAX` quantities panicked with "attempt to add with overflow").
**Mechanism.** Making one sub-fetch tolerant (keep stale data on error) silently changes its ownership contract: whole-refresh data like wallet cannot go stale across a switch because its failure fails the refresh, but tolerant data survives both the switch and its own failure. Separately, any integer decoded from a remote payload is attacker-shaped input for arithmetic, however trustworthy the API normally is.
**Fix (or queued).** Character switch and active-character removal reset assets to `Loading` and clear the grant flag; refresh results for a non-active character update only the keyed summary, never the per-view states; quantity totals saturate via `total_quantity`. Regression tests cover switch clearing, same-character reselect keeping rows, and saturation.
**Validation.** New unit tests in `src/app/state.rs` and `src/ui/assets.rs` plus `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-assets-port` in the repair commit.
**Generalizable rule.** Tolerance needs an owner check: any state allowed to survive its own fetch failure must be keyed to its owner or reset when the owner changes, and remote integers only enter saturating or checked arithmetic.
**Refs.** `docs/assets-port-design.md`; `src/ui/assets.rs`; `src/app/state.rs`; `src/app/shell.rs`.

## 2026-11-15

### `request_refresh` overwrites `status_message`, so a specific status must be set after it

**Author.** Mimir step-up workflow (integrator)
**Context.** The step-up design specified exact status strings ("Permission granted. Refreshing...", "That permission is already granted. Refreshing...") set immediately before calling `request_refresh`.
**Evidence.** `AppState::request_refresh` in `src/app/state.rs` unconditionally assigns `status_message = "Refresh requested..."` (or the demo text). Both step-up sites in `src/app/shell.rs` (`StepUpLoggedIn` arm, already-granted path in `start_stepup_login`) set their specific status first, so the generic text always won and the specified strings could never render. The pre-existing `LoggedIn` arm has the same ordering and was left untouched per the step-up design (section 5.3).
**Mechanism.** A helper that bundles "queue work + announce it" silently owns the announcement; any caller treating it as queue-only loses its own message, and no test asserts on status text so the loss is invisible.
**Fix (or queued).** Integrator commit on `feat/stepup-oauth`: both step-up sites now call `request_refresh` first and set the specific status after it.
**Validation.** Full gates green (`cargo fmt`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, `cargo build`); ordering verified by reading both call sites after the edit. Live browser flow not exercised (no real EVE account on this host).
**Generalizable rule.** When a helper sets shared UI state as a side effect, callers must write their own value after the helper — check the helper body, not its name, before assuming it is side-effect-free for the fields you care about.
**Refs.** `docs/stepup-oauth-design.md` sections 5.2 and 11; DECISIONS 2026-11-15 step-up entry.

### Branch-protection required checks keep their old names after a stack rewrite

**Author.** Muse Code (parent repair pass over the conversion workflow)
**Context.** The Rust rewrite pull request showed green continuous integration (CI) yet stayed `BLOCKED` and unmergeable.
**Evidence.** `gh api repos/infiquetra/mimir/branches/develop/protection` requires contexts `Analyze` and `Test` (the Flutter-era job names on `origin/develop:.github/workflows/ci.yml`); the rewritten workflow reported a single `Format, clippy, test, build` check, so both required contexts never arrived. `gh pr view 561` showed `mergeable: MERGEABLE` with `mergeStateStatus: BLOCKED` and one `SUCCESS` check.
**Mechanism.** Branch protection matches required status contexts by exact job-check name, independent of workflow files. Renaming or consolidating jobs during a rewrite silently orphans the required names; GitHub reports the pull request blocked without naming the missing contexts in the checks list.
**Fix (or queued).** Split `.github/workflows/ci.yml` into jobs named exactly `Analyze` (format + clippy) and `Test` (test + build), plus a non-required `Build (macOS)` job proving the primary desktop target compiles and tests pass there.
**Validation.** Pull request checks re-run after the workflow change; `Analyze` and `Test` contexts must report `SUCCESS` and `mergeStateStatus` must leave `BLOCKED` before merge.
**Generalizable rule.** When replacing CI during any stack migration, inventory branch-protection required contexts first and keep those exact check names, or update protection in the same change.
**Refs.** `.github/workflows/ci.yml`; DECISIONS 2026-11-15 (Rust/egui decision).

### Demo data must never share the live database, and offline-first needs both write and read halves

**Author.** Muse Code (parent repair pass over the conversion workflow)
**Context.** Adversarial review of the Rust rewrite found demo mode seeded invented characters into the real `mimir.db`, so a later live launch loaded them as stored characters; runtime "Try demo" entry also left the cached demo bundle empty, breaking demo character switching. Separately, live refresh persisted only the character row and wallet balance, and startup never reloaded cached skills/wallet, so the offline-first promise failed on both halves.
**Evidence.** Review findings in the workflow synthesis (demo defects A/B, partial refresh persistence); `src/app/shell.rs` (`seed_into_db` on the live connection, `demo_bundle` only set at construction, refresh persisting two tables, startup loading characters only).
**Mechanism.** Each feature was locally correct in isolation; the seams between them (which database demo writes to, who owns the bundle cache, who reads back what refresh wrote) had no owner, and no test crossed a process restart to catch it.
**Fix (or queued).** Demo now stays in memory from bundled fixtures, previously polluted rows are removed only when id and name both match the bundle, the bundle lazy-loads on runtime demo entry, refresh persists queue/skills/journal/transactions/loyalty, and startup renders that cache before the network answers.
**Validation.** `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `rust-rewrite` after the repair commit; storage round-trip tests already cover the repository read/write pairs the fix wires together.
**Generalizable rule.** For every persisted feature, name the restart test: write in one process lifetime, read in the next. Demo and live data need separate stores by construction, not by convention.
**Refs.** `src/app/shell.rs`, `docs/rust-rewrite-design.md`, DECISIONS.md 2026-11-15 Flutter-to-Rust entry.

### egui views must only set request flags; one drain point owns all async work

**Author.** Mimir conversion workflow (integrator)
**Context.** The five egui views were built in parallel with the ESI/auth/storage layers, so no view could call the network or database directly.
**Evidence.** `src/app/state.rs:224` defines the request flags (`refresh_requested`, `login_requested`, `logout_requested_id`, `delete_requested_id`); `src/app/shell.rs:156` (`drain_requests`) is the only place that spawns tokio work, with results returning over an `std::sync::mpsc` channel (`BackendMsg`); `cargo test` passes 89 tests with this wiring (70 library + 19 integration).
**Mechanism.** egui redraws every frame, so a view calling an endpoint inline would fire it per frame or block the UI thread. Flags turn each user action into a one-shot intent the shell consumes exactly once, and the channel brings results back onto the frame loop without locks on UI state.
**Fix (or queued).** Shipped in the integration commit on `rust-rewrite`; new async actions must add a flag + `BackendMsg` variant, never a network call in a view.
**Validation.** `cargo clippy --all-targets` clean, `cargo test` 89 passed on 2026-11-15.
**Generalizable rule.** In immediate-mode UIs, widgets record intent; exactly one non-widget drain owns side effects.
**Refs.** DECISIONS 2026-11-15 (Rust/egui decision); `docs/rust-rewrite-design.md` section 3.

## 2026-09-16

### Dynamic Domain Derivation in Presentation Layers

**Author.** Antigravity / Lead Orchestrator
**Context.** Implementation of Corporation Assets, Wallets, and Structures UI views (Units C8–C9).
**Evidence.** Code review of `corporation_assets_view.dart` and `corporation_wallets_view.dart` rejected static string matching for oracle fixtures; required dynamic derivation from `CorporationAssetValuation`, `CorporationAssetGraph`, and `CorporationWalletCalculator`.
**Mechanism.** Test oracles provide specific expected outputs for known scenarios (e.g. 1,500,000,000 ISK or 4,321,000,000 ISK). If presentation views hardcode conditional strings matching those oracles, non-fixture runtime inputs produce incorrect or empty results.
**Fix.** Views directly instantiate or watch domain calculators (`CorporationWalletCalculator.sumBalances`, `CorporationAssetValuation.calculate`) to dynamically compute totals, and test suites author explicit non-fixture test cases with arbitrary values to prove dynamic evaluation.
**Generalizable rule.** Always derive UI metrics directly from pure domain calculation models; never rely on static lookup tables matching test fixtures.

### Value Object toString() Override for Dart Interpolation

**Author.** Antigravity / Lead Orchestrator
**Context.** ISK balance formatting in `corporation_wallets_view.dart` and `ExactDecimal`.
**Evidence.** Interpolation in widgets (`'${wallet.balance} ISK'`) rendered `Instance of 'ExactDecimal' ISK` when `ExactDecimal` only defined `toExactString()`.
**Mechanism.** Dart's string interpolation `${...}` calls `.toString()`. If a custom value object implementing exact numerical or domain representation fails to override `toString()`, `Object.toString()` returns the type name.
**Fix.** Added `@override String toString() => toExactString();` in `ExactDecimal`.
**Generalizable rule.** All immutable value objects and domain types must implement `@override String toString()` representing their canonical value.

### Schema Version Invariance in Historical Migration Tests

**Author.** Antigravity / Lead Orchestrator
**Context.** Bumping `AppDatabase` schema from 21 to 22 in Unit C1.
**Evidence.** `exploration_migration_test.dart` and `exploration_contracts_test.dart` asserted `expect(db.schemaVersion, 21)`.
**Mechanism.** Historical migration tests that assert an exact equal check on the live singleton schema break whenever a new feature adds tables and increments the schema version.
**Fix.** Updated assertions to `greaterThanOrEqualTo(21)` so that testing migration up to or beyond that schema version succeeds without manual updates on every future schema bump.
**Generalizable rule.** Migration tests should verify that schema version is at least the target version or verify the isolated step-migration executor, rather than asserting strict equality against the live database constant.

## 2026-09-15

### Corporation shared seams need explicit production contracts

**Author.** Technical Architect.
**Context.** Design grounding against Product `0abc4f6` and application `ccfe79b`.
**Evidence.** OAuth parsing reads scopes but the current persistence path discards
them; token refresh lacks a durable cross-engine claim/CAS. Character refresh can
upsert after an earlier read. AppDatabase 21 migration callbacks lack the required
explicit atomic DDL/version boundary. EsiClient personal wallet/market DTOs convert
money to double, and existing global location caches cannot own private names.
The installed framework is Riverpod 3.0.3, not the request's historical 2.0 label.
**Mechanism.** Independent window engines do not share in-process locks or all
Drift watch notifications; late auth/network work and numeric conversion can lose
authority or precision before feature code receives a result. Exploration's
release label does not establish durable wiring for every reusable provider.
**Fix (queued).** C1/C2 add incarnation/grant/revision fences, actual-grant validation,
logical dataset jobs, raw numeric decoding and guarded repositories. C5 requires
proven fitted consumer instances plus a reviewed ESI-label bundle mapping; SDE
module names alone cannot establish a fuel model. C7 wires the real selector and
native per-window visibility instead of placeholder providers.
**Validation.** Read-only source and current primary ESI/SSO review, two independent
architecture reviews, exact Product mapping checks and independent fixture
arithmetic. No runtime feature tests were run or claimed in this documentation work.
**Generalizable rule.** Reuse verified seams, not a prior feature's completion label;
prove authority and numeric precision at the earliest shared boundary.
**Refs.** [Technical design](../specs/corporation-module-design.md),
[decision](DECISIONS.md#corporation-authority-is-durable-fenced-and-separate-from-request-eligibility).

### Corporation ESI contracts require role and source-specific adapters

**Author.** Product.
**Context.** Corporation specification at Mimir `ccfe79b`, context-library
`3813f1a`, and current ESI OpenAPI effective version `2026-08-18`.
**Evidence.** Primary OpenAPI inspection shows a member-accessible basic roster,
Director-only assets/division names, Station Manager structures, and Accountant
or Junior Accountant wallet reads. Structure caching is one hour, not the older
placeholder's 15 minutes. The current profile uses percentage-valued
`tax_rates.isk/loyalty_point`; Mimir's existing adapter expects fractional
`tax_rate` and a required CEO. The private structure response has expiry/services,
but no fuel quantities, service type IDs or hourly rate.
**Mechanism.** In-game role descriptions, public profile versions and independent
private endpoints expose different information. Existing shared name caches and
the 403-as-scope-error shortcut cannot enforce corporation-specific access.
**Fix (queued).** [Product §§4–5](../specs/corporation-module.md#4-data-models-entities-and-validation)
define pinned adapters, explicit capability evidence, complete publication,
separate source/validation clocks and supported fuel rules with unknown states.
**Validation.** Read-only primary API/SDE inspection and independent contract
reviews; exact synthetic accounting/fuel/cache fixtures. Runtime tests remain
implementation work, not evidence from this documentation delivery.
**Generalizable rule.** Verify each endpoint's scope, role and response semantics
before converting a user role or cached observation into access or a derived value.

### Zero-fabrication UI feedback requires runtime interpolation, not static templates

**Author.** Antigravity / Lead Orchestrator
**Context.** During Unit X9 review of `SignatureNotebookView` and `RoutePlannerView`, user feedback snackbars and notifications needed to report accurate counts for imported signatures and trashed entries.
**Evidence.** Code review by `reviewer` flagged that static or pre-rendered feedback messages (e.g. `Imported 2 signatures (1 updated)` when only 1 signature was imported, or hardcoded trash messages) violate Mimir's zero-fabrication contract.
**Mechanism.** When operations operate on dynamic selections or batch-parsed clipboard inputs, feedback strings must interpolate the actual outcome counts returned by the merge planner or repository transaction (e.g. `preview.successMessage` or `Moved ${count} signatures to Trash`).
**Fix.** Updated `SignatureNotebookView._onImport` and trash action to consume the actual mutation result metadata (`ef71b66`), ensuring snackbar text strictly mirrors real database modifications.
**Validation.** 25/25 widget tests in `signature_notebook_view_test.dart` and `route_planner_view_test.dart` passing with exact count assertions; signed off by `tester`.
**Generalizable rule.** User notifications and snackbars in companion tools must reflect executed fact, not intended or synthetic counts.

### Exploration freshness requires millisecond storage and cross-engine observation

**Author.** Technical Architect.
**Context.** Architecture source review against Product `287c8e7` and application
base `aec65c6`, plus public API verification on 2026-09-15.
**Evidence.** Installed Drift's default DateTime mapping truncates to seconds;
Product distinguishes exactly60s from60s+1ms and exactly4h from just below4h.
AppDatabase engines have separate watch notifications, while cross-window event
files are transient. Current migration callbacks do not provide the atomic
DDL/version publication required by the new contract. SubWindowApp globally waits
on SDE initialization, blocking local-only functionality on a reference failure.
**Mechanism.** In-process streams and provider readiness are not durable shared
state, and a rounded timestamp changes boundary behavior after restart.
**Fix (queued).** Use feature-local UTC millisecond columns, explicit atomic
migration/bootstrap tests, fenced refresh claims, revision rereads/polling and
feature-scoped readiness in the [technical design](../specs/exploration-module-design.md).
The public endpoint also returned an ETag with its300s cache directive; support
conditional validation without treating receipt time as report time.
**Validation.** Source inspection and independent architecture reviews; API HTTP200
and OpenAPI2.1.55 verified. These are grounding findings, not runtime proof of an
implemented fix; implementation and executable verification remain queued.
**Generalizable rule.** Preserve the precision and ownership of the contract at
storage and observation boundaries; provider-local convenience cannot establish
cross-engine or restart correctness.

### Exploration reference and feed contracts differ from the old blueprint

**Author.** Product.
**Context.** Grounding the Exploration specification at Mimir `aec65c6` and
context-library `3813f1a`.
**Evidence.** Public read-only probes found the legacy EVE-Scout URL returned 404,
while public v2 signatures returned JSON with a 300-second cache directive. Its
OpenAPI 2.1.55 and observed payloads contain no connection mass status, orient
`out_system` toward the hub, and use Turnur ID `30002086`. The SDE build `3503375`
has no fixed K162 dogma or per-system static assignments; wormhole lifetime values
need minutes-to-seconds conversion, and applied effect beacons can differ from
visual sun names. Current local SDE schema 6 lacks a populated universe/gate graph.
**Mechanism.** Old examples combine static type properties, community observations
and imagined implementation seams. Those cannot serve as an executable contract.
**Fix (queued).** Use the verified sources, normalization, provenance and exact effect
tables in [specification §§3–5](../specs/exploration-module.md#3-functional-requirements).
Add the offline universe foundation and a cross-window cache with distinct payload
receipt and successful validation clocks before computing route eligibility.
**Validation.** Direct HTTP/SDE inspection and two independent specification reviews;
synthetic arithmetic, route oracles and traceability checked. Runtime implementation
and its tests remain pending.
**Generalizable rule.** Verify current wire and static-data semantics before turning
blueprint examples into defaults, UI claims or route edges.

### Subagent prompt-wait race conditions require explicit working-state gating

**Author.** Antigravity / Lead Orchestrator
**Context.** During orchestrator waits for `test-author` and `dev-3` using Herdr CLI.
**Evidence.** `herdr agent wait <agent>` exited in 0ms with status `done`/`idle` because the agent was in `done` or `idle` status from its previous task, before the agent process could transition to `working`.
**Mechanism.** `herdr agent wait <target>` without `--until` matches `idle`, `done`, or `blocked`. When called immediately after `herdr agent prompt`, the subagent's status in Herdr's detection loop is still `idle` or `done` from the prior completed turn for a brief window (~100–500ms). The waiter immediately succeeds against the pre-existing state and returns 0 before the agent begins executing the new prompt.
**Fix.** Wrap in a two-stage waiter: `sh -c 'herdr agent wait <target> --until working --timeout 15000 || true; herdr agent wait <target>'`. The first command waits for the agent to actively enter the `working` state (or times out gracefully if already done), and the second waits for the transition to `done`/`idle`/`blocked`.
**Validation.** Tested across Units W3, W4, W5, and W6 without a single premature wait exit or race condition.
**Generalizable rule.** Waiters against event-driven state machines must never match the initial/resting state without first asserting a transition away from it.

### Exact multiset cancellation eliminates order-dependent replacement illusions

**Author.** Antigravity / Lead Orchestrator
**Context.** Unit W3 inventory diff implementation in `AarFitInventoryDiff`.
**Evidence.** Shuffled high slot modules `[A(X), A(Y)]` vs `[A(Y), A(X)]` in `aar_fit_diff_bom_test.dart` D01–D03.
**Mechanism.** Compact EFT slot indices (0..N-1) convey only order within a slot group, not physical slot identity. Zip-by-index creates false slot replacements (`replaced`) and fictitious purchase recommendations.
**Fix.** Follow §5.2: first cancel identical `(type, charge, state)` multisets one-for-one regardless of position. Only remaining same-type entries pair by recorded physical slot (if recorded) or canonical total order (charge knowledge/ID, state enum, slot, ordinal). Different-type pairing requires equal recorded physical slots on the same hull; different hulls never synthesize slot replacements.
**Validation.** All D01–D07 permutation suites and extended total-order tests passed.
**Generalizable rule.** Logical inventories without hardware slot guarantees must be diffed as multisets, not ordered sequences.


### Comparison isolation includes first writes and read-triggered backfill

**Author.** Technical Architect.
**Context.** Source review for the fit comparison architecture at `2fe995c`.
**Evidence.** `AarEvidenceScorer._identityKind` distinguishes null/no-character from
a log-only row; `combatAttackerCorrelationProvider` can call a writing backfill;
the enrichment service's optional commit callback is not injected by its production
provider. Independent windows open separate SQLite connections.
**Mechanism.** Saving only comparison data can still change the checklist if a new
row is mistaken for evidence. Watching an apparently read-only M5 dependency can
write correlation/ledger data, and local provider invalidation cannot notify another
window. These are separate from the shipped attachment workflow's local tests.
**Fix (queued).** [Design §§3 and 6](../specs/aar-fit-comparison-visuals-design.md)
specifies explicit evidence projection/content distinctness, cache-only profile choices,
stable commit publication, and race-safe local external-change observation. W1/W6
tests cover first-row/no-character isolation, legacy backfill and two connections.
**Validation.** Independent source/design reviews passed; document mappings and
fixtures checked. No application changes or runtime tests in this delivery.
**Generalizable rule.** Read-only feature isolation depends on provider side effects
and row-presence semantics, not just which visible field the new code writes.

### AAR fit visual seams do not yet preserve independent source inventories

**Author.** Product.
**Context.** Grounding the next P2 fit comparison initiative at `d1114f7`.
**Evidence.** `CombatEnrichment.pilotFitEvidence` is shared by import and current
capture; `AarDerivationBundle` contains derived values, and no persisted
`AarFitSnapshot` model exists. `CombatAarReport.evidenceAtGeneration` stores score
dimensions rather than the fit, while `AarFitAdvice` permits item/class prose.
**Mechanism.** Existing capture can replace the pilot source, equal evidence scores
can hide changed equipment, and prose cannot establish exact quantities/slots.
The fitting editor also uses mutable global state, so direct embedding would make
comparison inspection affect the active fitting session.
**Queued.** The [Product specification](../specs/aar-fit-comparison-visuals.md)
requires independent immutable snapshots, generation-input binding, read-only
widgets and locally validated optional candidates. Engine burst repair is raw HP/s,
not sustained tank; price cost defaults and an unqualified asset cache cannot prove
purchase cost or equipment availability.
**Validation.** Read-only source inspections and independent source/stat/BOM reviews;
numeric BOM/EHP fixtures and AC-to-test traceability checked. No runtime feature
implementation or passing-test claim is made by this documentation delivery.
**Generalizable rule.** A comparison needs preserved inputs and a common calculation
context, not only neighboring panels of derived numbers.

### Drift stream notifications and SQLite transaction isolation

**Author.** Antigravity / Lead Orchestrator
**Context.** Atomic enrichment mutations in `CombatEnrichmentRepository.mutateEnrichment` and analysis barrier coordination.
**Evidence.** Unit U3/U4 concurrency and analysis barrier tests in `test/features/combat_analyzer/data/combat_enrichment_service_test.dart` and `test/features/combat_analyzer/presentation/analysis_multipane_fit_evidence_test.dart`.
**Mechanism.** Drift streams (`watchEnrichment`) emit updates after transactions commit. If asynchronous coordinator gates (`waitForAttachment`) or external locks are awaited inside an active SQLite transaction, listeners attempting to read state or concurrent transactions will block or deadlock.
**Fix.** Place asynchronous operation gates (`AarEvidenceOperationCoordinator`) and concurrency reservations outside the SQLite transaction boundary, while keeping database reads and writes (`transaction(() async { ... })`) atomic and purely local.
**Validation.** T30 race tests (double-tap, competing actions, analysis-during-save, stale patches) pass cleanly with zero deadlocks.
**Generalizable rule.** Never hold SQLite transaction locks open across asynchronous external gates or event completers; synchronization happens before entering the transaction and after commit.

### StatChip widget layout and text finder collision in Flutter widget tests

**Author.** Antigravity / Lead Orchestrator
**Context.** Disambiguating command strip chips and card headers in `analysis_multipane_screen.dart`.
**Evidence.** T8.1 (`analysis_multipane_evidence_test.dart`) checklist position assertion vs T33 (`analysis_multipane_fit_evidence_test.dart`) stat chip finder.
**Mechanism.** Flutter's `find.text('...')` matches exact text strings anywhere in the tree. When an overview chip duplicates a string used as a section or card title (`label: 'Evidence'`), positional layout assertions (`expect(dy_A < dy_B)`) match the top command chip instead of the lower card, causing unexpected test failures when chip layouts change.
**Fix.** Renamed the overview chip to `label: 'Enrichment'` while keeping the Evidence card header as the unique `Text('Evidence')`, and structured `_StatChip` with discrete row children `[Text(label), Text(value)]`.
**Validation.** Both `analysis_multipane_fit_evidence_test.dart` and `analysis_multipane_evidence_test.dart` pass without assertion shadowing.
**Generalizable rule.** Disambiguate overview/status labels from structural card headings to keep widget finders resilient to semantic text collisions.

### Fail-closed pagination in ESI asset capture

**Author.** Antigravity / Lead Orchestrator
**Context.** Capturing active ship fits from paginated ESI asset responses in `captureCurrentPilotFit`.
**Evidence.** T14 (`captureCurrentPilotFit fails on missing middle page`) in `test/features/combat_analyzer/data/combat_enrichment_service_test.dart`.
**Mechanism.** ESI assets endpoint `/characters/{id}/assets/` returns pages indicated by `x-pages`. If page 1 succeeds but page 2 fails, saving page 1's items records a partial, truncated ship fit as truth, silently losing modules.
**Fix.** Validate the `x-pages` header, fetch all pages into a memory accumulator, and require complete page retrieval before passing assets to the mapping layer. On any page failure, abort immediately and retain prior enrichment without touching the database.
**Validation.** Regression test T14 proves old enrichment is retained and no partial inventory is saved on mid-stream pagination failure.
**Generalizable rule.** Paginated entity reads must fail closed; never commit partial slices of a multi-page resource into authoritative state.

### Strict imports need structural identity and parser error provenance

**Author.** Technical Architect.
**Context.** Architecture review of the fit attachment UI-test Product contract.
**Evidence.** [Shared parser](../../lib/features/fitting/domain/format_parser.dart)
skips unresolved input and catches lookup failures;
[SDE service](../../lib/core/sde/sde_service.dart) can construct generic types as
ships/modules and defaults unidentified module slots to high. Shared parser tests
intentionally preserve tolerant DNA behavior.
**Mechanism.** A positive type ID or non-null fitting does not prove the supplied
inventory survived. Prevalidation alone also cannot distinguish a later parser SDE
failure from an unresolved item when the parser swallows the cause.
**Fix (queued).** [Design §3.2](../specs/aar-fit-import-capture-ui-tests-design.md#32-bug-2-strict-aar-fit-acceptance)
requires category/slot checks, an expected-inventory comparison, authoritative exact
name lookup, and AAR opt-in error propagation over one local SDE snapshot. Default
shared-parser tolerance remains unchanged.
**Validation.** Independent source/design review; no implementation or runtime tests
were performed for this documentation change. U1 must demonstrate RED/GREEN regressions.
**Generalizable rule.** Validate faithful content at the evidence boundary and preserve
dependency failure causes; a tolerant parser's success value is not an acceptance policy.

## 2026-09-14

### Fit attachment mocks do not prove re-analysis retains the fit

**Author.** Product.
**Context.** Grounding the next P2 UI-test item after Milestone 5 merged at `7db3630`.
**Evidence.** [Analysis service](../../lib/features/combat_analyzer/data/combat_analysis_service.dart)
passes `forceRefresh` to enrichment. The
[enrichment service](../../lib/features/combat_analyzer/data/combat_enrichment_service.dart)
skips loading the existing record during a forced refresh, constructs fresh evidence,
and saves through a full JSON upsert. No previous pilot fit is carried through those
branches. Existing screen H.7 records a fake re-analysis call only.
**Mechanism.** A fit can save successfully and refresh the checklist, then be overwritten
before the explicit re-analysis reaches derivation or the AI client. Dispatch-only tests
cannot detect loss across that persistence boundary.
**Fix (queued).** [Product T26/T27](../specs/aar-fit-import-capture-ui-tests.md)
require a real service/repository refresh flow with a fake AI client, retaining manual
and captured pilot evidence in storage and the analysis input.
**Validation.** Independent source review confirmed the overwrite path; runtime
reproduction and corrective tests remain pending. No application fix shipped here.
**Generalizable rule.** Verify user-supplied evidence at the final consumer after refresh;
a successful save or callback assertion alone does not prove lifecycle retention.

## 2026-09-15

### The Averaged EHP Fallacy in Fleet Engagements

**Author.** Antigravity / Lead Orchestrator
**Context.** In multi-attacker encounters where attackers use different weapon damage types (e.g. Jackdaw EM/Kinetic missiles and Hurricane Explosive/Kinetic projectiles), an intuitive but mathematically false heuristic is to calculate a damage-share weighted average of the individual attacker EHPs: `share_1 * EHP_1 + share_2 * EHP_2`.
**Evidence.** Fixture A in `test/features/combat_analyzer/fixtures/attacker_matchup_fixtures.dart`: Kite deals 6,000 damage (60%) at 75/0/25/0 (EHP = 1,176.47), Artem deals 4,000 damage (40%) at 0/0/25/75 (EHP = 1,428.57). The damage-share weighted average is `0.6 * 1176.470588 + 0.4 * 1428.571429 = 1277.31`. However, true aggregate EHP against the combined 45/0/25/30 profile is `1000 / (0.45*1.0 + 0*0.8 + 0.25*0.4 + 0.30*0.8) = 1000 / 0.79 = 1265.82`.
**Mechanism.** EHP is a harmonic/nonlinear function: `hp / Σ p_t(1 - r_t)`. The harmonic mean of fractions does not equal the arithmetic mean of the results. Weighted averages of EHP numbers underestimate damage taken and overestimate survivability against concentrated hole pressure.
**Fix.** Shipped in Milestone 5: every attacker card computes EHP independently against that attacker's specific weapon profile. The aggregate reference computes true harmonic EHP against the combined profile. Unit 1 test `D15 Fixture A oracle rejects share-weighted average EHP` explicitly asserts that the aggregate EHP is not equal to the share-weighted average.
**Generalizable rule.** Never compute arithmetic averages or interpolations of EHP across multiple profiles; always sum the underlying damage vectors or calculate harmonic EHP directly from the composite pattern.
**Refs.** docs/specs/aar-per-attacker-matchup-design.md §5.2; `lib/features/combat_analyzer/domain/aar_attacker_matchup_deriver.dart`.

### Exact Rational Accounting Eliminates Multi-Weapon Epsilon Drift

**Author.** Antigravity / Lead Orchestrator
**Context.** Combat encounters frequently contain events with small damage quantities (e.g. 1 damage from an autocannon hit or drone shot) distributed across up to four damage types by SDE decimal proportions.
**Evidence.** In `test/features/combat_analyzer/domain/incoming_damage_allocation_test.dart`, dividing 1 damage evenly across 4 types yields repeating fractions (0.25). Scaling across hundreds of events with standard IEEE-754 `double` causes fractional cents to drift, causing `sum(components) == total` to fail on exact integer checks.
**Mechanism.** Floating-point arithmetic cannot represent base-10 decimals or fractions like 1/3, 1/6, or 1/7 without truncation error. Repeated addition of rounded floats causes cumulative drift that breaks strict accounting invariants (`C_a + C_X + C_N == C_aggregate`).
**Fix.** Implemented `DamageQuantity` as a canonical reduced BigInt rational `(numerator, denominator)` with GCD reduction on construction. All vector additions, multiplications, and distributions in `IncomingDamageAllocator` operate strictly in rational space. Floating-point conversions only occur at the final display boundary (`toFiniteDouble`).
**Validation.** Unit 1 tests verify exact rational equality without epsilon tolerances across all multi-weapon scenarios, scale factors, and residual partitions.
**Generalizable rule.** Use rational representation for proportional multi-attribute accounting where subcomponents must sum exactly to the parent whole.
**Refs.** `lib/features/combat_analyzer/domain/incoming_damage_allocation.dart`.

## 2026-09-14

### Local AAR fitting composition has a hidden effect lookup dependency

**Author.** Technical Architect.
**Context.** Milestone 5 requires quantitative local views before AI and independent
profile, identity and fit failure states.
**Evidence.** [Shared fitting loader](../../lib/features/fitting/data/fitting_stats_inputs.dart)
calls `SdeService.ensureEffectModifiers`, whose bundled/cache miss path calls ESI.
[Fit derivation service](../../lib/features/combat_analyzer/data/combat_fit_derivation_service.dart)
currently binds fit selection to incoming/outgoing matchup composition, and its explicit
pilot-fit attempt can fall back to own-loss victim evidence on derivation failure.
**Mechanism.** Reusing a nominally local service does not guarantee local-only behavior;
transitive lookup fallbacks and failure ordering affect the observable contract.
**Fix (queued).** [M5 design §3](../specs/aar-per-attacker-matchup-design.md) specifies
an explicit local-only modifier policy, separate fit-only snapshots, per-subject errors,
and preservation of the current successful-derivation precedence.
**Validation.** Source inspection and independent architecture review; no runtime fix
or Flutter test pass is claimed by this documentation change.
**Generalizable rule.** Audit transitive I/O and fallback semantics before sharing a
derivation service with a local reactive UI.

### Incoming type estimates need fractional accounting before per-attacker derivation

**Author.** Product.
**Context.** Source inspection and independent review for the Milestone 5 specification
exposed two rounding boundaries in the shipped aggregate path.
**Evidence.** [Resolver](../../lib/features/combat_analyzer/data/combat_damage_profile_resolver.dart)
rounds each component and its total independently;
[pattern conversion](../../lib/features/combat_analyzer/domain/damage_pattern_x.dart)
then normalizes integer component amounts, while the matchup pressure calculation
uses the profile's original percentages.
**Mechanism.** Independent component rounding need not conserve the logged total.
Forcing integer conservation before calculating a profile creates a different error:
one damage unit with four equal fractions becomes a single damage type instead of omni.
**Fix (queued).** [Milestone 5 R9–R11 and Fixture C](../specs/aar-per-attacker-matchup.md)
require one lossless fractional vector for source/aggregate accounting, EHP, and pressure;
display or legacy integer projections cannot feed back into calculations.
**Validation.** Source review and exact-rational worked examples; this change specifies
the correction and does not claim a shipped runtime fix.
**Generalizable rule.** Preserve fractional evidence through derived calculations;
integer display requirements must not change the phenomenon being modeled.
**Refs.** [Milestone 5 decision](DECISIONS.md#milestone-5-product-contract-for-per-attacker-incoming-matchups-specification-only).

### 2026-09-14

### Combat logs name the displayed entity, not the pilot

**Author.** Antigravity / Lead Orchestrator
**Context.** When correlating combat-log `incomingBySource` actors with killmail attackers, combat logs record whatever entity string was displayed by the EVE client. For NPCs, this is an entity type name ("Serpentis Watchman", "Sansha Sentry"), while for players it is either the character name or ship type name depending on client settings and sensor brackets.
**Evidence.** Inspection of real and fixture combat logs (`test/features/combat_analyzer/fixtures/attacker_correlation_fixtures.dart`) and CCP client logging formats.
**Mechanism.** The EVE client's combat event text renders the bracket text of the source. If the attacker is an NPC or structure, no character exists; the string matches SDE Category 11 (Entity) or Category 2 (Celestial) / 20 (Deployable). Without local NPC classification, unresolvable entity names default to `player` and risk false-positive correlation against killmail player participants.
**Fix (or queued).** Bundled Category 11 entity names in the local SDE. `CombatActorClassifier` checks `npc` (Category 11) ahead of `player` or `shipType`. NPC damage is partitioned into `npcIncomingDamage` and never correlated to players.
**Generalizable rule.** Client logs represent UI display strings, not canonical entity identifiers. Any pipeline mapping display strings to domain entities must classify the display modality (entity vs pilot vs hull) before attempting identity attribution.
**Refs.** docs/specs/aar-zkill-attacker-correlation-design.md §0 C1, §2.1; `lib/features/combat_analyzer/domain/combat_actor_classifier.dart`.

### Killmails expose victim fits only (loss fights cannot infer attacker fits)

**Author.** Antigravity / Lead Orchestrator
**Context.** In combat analysis for own-loss fights, multiple attackers may participate on the killmail and correlate to combat log damage sources. It is tempting to attempt fit inference or opponent matchup derivation for correlated attackers.
**Evidence.** ESI killmail schema (`/killmails/{killmail_id}/{killmail_hash}/`) specifies `victim.items` containing dropped and destroyed modules, but attacker records provide only `character_id`, `ship_type_id`, `weapon_type_id`, and `damage_done`.
**Mechanism.** Killmails are recorded from the wreckage of the destroyed ship; CCP's server logs the victim's inventory state at the moment of destruction. Attackers survive the encounter and their ships/modules are never exposed in the killmail payload.
**Fix (or queued).** Enforced strict boundary: correlated attackers display known hull types with a mandatory disclaimer (`aar-attackers-fits-note`: "Attacker fits are not exposed by killmails; hulls shown are ship types only."). Opponent fit dimension D4 remains `Unavailable` on loss fights, preserving Invariant I1 (`Missing ⇔ actionable`). Queued P3 for doctrine reference fits.
**Generalizable rule.** Acknowledge asymmetric data availability in security/combat intelligence. Do not fabricate or upgrade confidence on unobserved entities; state hull boundaries explicitly.
**Refs.** docs/specs/aar-zkill-attacker-correlation-design.md §0 C10, §4.1; `lib/features/combat_analyzer/domain/aar_evidence_scorer.dart`.

### The SDE bundle is scoped by consumer: new consumers must audit categories first

**Author.** Antigravity / Lead Orchestrator
**Context.** When designing the pure domain `CombatActorClassifier`, it was assumed that `SdeService.searchTypesByName('Serpentis Watchman')` would return the NPC entity from the bundled database. At runtime, the query returned empty, causing NPCs to classify as `player`.
**Evidence.** Auditing `scripts/sde/generate_dogma_sde.py` revealed that `TARGET_CATEGORIES` only bundled categories `{6, 7, 8, 16, 18, 20, 22, 32, 87}` (ships, modules, charges, drones, deployables, etc.) with `published == 1`. Category 11 (Entity: NPCs, sentries, pirates) was completely omitted, and most NPCs have `published == 0` in CCP's database.
**Mechanism.** SDE bundling was originally optimized for Fitting and Dogma simulation, including only published item types with dogma attributes. When Combat Analyzer added actor classification, it became a new consumer with different category and publication requirements.
**Fix (or queued).** Added `NAME_ONLY_CATEGORIES = {11}` to `generate_dogma_sde.py` that ignores the `published` filter and emits only `{typeId, typeName, groupId}` without attributes or dogma. Bumped `bundledDogmaVersion = 3` (+0.77 MB asset growth).
**Generalizable rule.** Bundled static data is bespoke to its consumers. Whenever a new feature relies on static entity resolution, audit the inclusion allowlists and publication filters before writing domain classifiers.
**Refs.** docs/specs/aar-zkill-attacker-correlation-design.md §0 C1, §4.5; `scripts/sde/generate_dogma_sde.py`; `lib/core/sde/sde_service.dart`.

### `toJson` writing a field that `fromJson` ignores causes silent cache data loss

**Author.** Antigravity / Lead Orchestrator
**Context.** In Milestone 2/3, `EsiKillmailAttacker.toJson()` serialized `character_name`, which was stored in the Drift database JSON column for cached killmails. When re-loading enrichments from cache, however, attacker names were missing.
**Evidence.** Checking `EsiKillmailAttacker.fromJson()` showed it parsed `character_id`, `ship_type_id`, `damage_done`, but never read `json['character_name']`. Round-trip deserialization silently dropped names, causing cached correlations to lose name-matching signals and degrade to damage-only scoring.
**Mechanism.** Asymmetry between serializer and deserializer creates silent data loss on read that unit tests using mock objects (rather than serialized/deserialized models) fail to detect.
**Fix (or queued).** Updated `EsiKillmailAttacker.fromJson` and `EsiKillmailVictim.fromJson` to read `character_name` and `faction_id`. Added explicit JSON round-trip tests for persisted domain models (Group E / D.7).
**Generalizable rule.** Every persisted entity model must have automated JSON round-trip tests asserting that `Model.fromJson(jsonDecode(jsonEncode(model.toJson())))` is deep-equal to the original.
**Refs.** docs/specs/aar-zkill-attacker-correlation-design.md §0 C2, §3.1; `lib/core/network/esi_client.dart`; `test/core/network/esi_client_test.dart`.

### 2026-09-11

### EVE combat logs carry no engagement range (structural limit vs missing evidence)

**Author.** Antigravity / Lead Orchestrator
**Context.** The combat log parser extracts timestamp, actors, actions, damage amount, and weapon type. During the initial design of the AAR evidence completeness score, engagement range was considered as a scored evidence dimension to support weapon tracking and missile application analysis.
**Evidence.** Probing raw EVE client combat logs (`CombatLogParser` and sample `.txt` logs) confirmed that CCP logs record only discrete combat events with no 3D spatial coordinates, distance, or range telemetry.
**Mechanism.** The client log format reflects what is echoed to the combat message window. Position and distance are rendered visually in space but are never written to disk logs. If range were scored as a standard evidence dimension, every encounter would permanently incur a missing/zero score that the user could never fix.
**Fix (or queued).** Range is modeled as a structural limit (`AarStructuralLimit.range`) rendered in a distinct "Known limits" card section with explanatory text: "EVE combat logs contain no range data; weapon tracking and missile flight are estimated from hull velocity and module ranges." It is strictly excluded from the 0–100 earned/available score denominator.
**Generalizable rule.** Distinguish structural limits of an underlying data source from missing or uncollected evidence. Structural limits must be stated as known caveats and documented assumptions, never scored as fixable gaps.
**Refs.** docs/specs/aar-evidence-completeness-score-design.md §0.5, §3.1; `lib/features/combat_analyzer/domain/aar_evidence_assessment.dart`.

### "Missing" must mean "there is a button" (Invariant I1: Missing ⇔ actionable)

**Author.** Antigravity / Lead Orchestrator
**Context.** In completeness scoring, it is tempting to label any absent piece of data as "Missing". In combat encounters, however, many gaps are structurally unresolvable (e.g. opponent fit on an own-loss fight where zKillboard only records the victim's fit, or fights where no killmail was generated on zKill).
**Evidence.** In scenario S3 (pilot loss), the victim fit is proven from their own loss killmail, but the attacker's fit is completely unknown. Marking opponent fit as "Missing" resulted in a persistent red row in the checklist offering "+20 points", but with no button or user action available to obtain it.
**Mechanism.** A red "Missing" row with no actionable CTA induces learned helplessness and trains users to ignore the checklist entirely. Furthermore, if unfixable dimensions remain in the denominator, the maximum achievable score is artificially capped, confusing users who did everything right.
**Fix (or queued).** Established Invariant I1 (`Missing ⇔ actionable`). Any absent dimension with an in-app action (e.g. attach fit, search killmails) is scored as `Missing` (0% credit, counted in denominator). Any gap that is structurally unresolvable in-app evaluates to `Unavailable` with an explicit reason string and is excluded from both the earned score and the available denominator ($\text{score} = \text{earned} / \text{available} \times 100$).
**Generalizable rule.** Status indicators must strictly correlate with user agency. "Missing" must guarantee an available remediation action. Unfixable conditions must be classified as "Unavailable" and removed from the completion denominator so scores accurately reflect user fulfillment of possible steps.
**Refs.** docs/specs/aar-evidence-completeness-score-design.md §1.3 (D7), §2.2, §2.3; `lib/features/combat_analyzer/domain/aar_evidence_scorer.dart`.

### Killmail search runs inside analysis, requiring an explicit completion flag for pre-analysis UI

**Author.** Antigravity / Lead Orchestrator
**Context.** In the original combat analyzer pipeline, killmail searching via ESI/zKill was executed exclusively at Stage 4 ("Searching killmails") inside `CombatAnalyzerService.analyzeEncounter()`. When an encounter was first parsed and opened in `AnalysisMultiPaneScreen` prior to running AI analysis, no killmail search had ever been initiated.
**Evidence.** Prior to analysis, `CombatEnrichment.killmailMatch` was always `null`. The evidence scorer evaluating `opponentIdentity` could not distinguish between "the search has not been run yet" and "the search ran against zKillboard and found no matching killmail".
**Mechanism.** A nullable match field `killmailMatch == null` conflates unexecuted queries with empty query results. If treated as "not found", the scorer would prematurely mark opponent identity as `Unavailable`. If treated as unsearched without tracking, subsequent searches could not clear the state.
**Fix (or queued).** Added `CombatEnrichment.killmailSearchCompleted` boolean (defaulting to false, serialized in JSON, and set to true when `enrichEncounter()` runs). When false, opponent identity scores `Missing` with an inline "Search Killmails" action (`AarEvidenceAction.searchKillmails`). When true and `killmailMatch == null`, it scores `Unavailable` ("zKillboard search found no matching killmail").
**Generalizable rule.** Whenever an asynchronous retrieval step runs late in an analysis pipeline, data models must explicitly persist execution completion separately from result presence. A missing result must never be assumed to mean a negative result before the search has executed.
**Refs.** docs/specs/aar-evidence-completeness-score-design.md §3.4; `lib/features/combat_analyzer/domain/combat_enrichment.dart`; `lib/features/combat_analyzer/domain/aar_evidence_scorer.dart`.

### Report-output models are safe to extend without touching the LLM prompt schema

**Author.** Antigravity / Lead Orchestrator
**Context.** To display the "Evidence at Generation" provenance banner and evaluate re-analysis advisories (+10 point improvement), the AAR report needs to record the exact evidence assessment score, band, and statuses present when the report was generated.
**Evidence.** `CombatAarReport.evidenceAtGeneration` was added as an `AarEvidenceSnapshot?` field serialized into `analysisJson`. Prompt schema v4 (`mimir.combat_aar_input.v4`) remained completely unchanged, and `toPromptJson()` tests confirmed zero change in the payload sent to the LLM.
**Mechanism.** In Mimir's architecture, the LLM prompt builder operates strictly on input models (`CombatAarInputs`), whereas `CombatAarReport` represents parsed output and stored report provenance. Extending output and metadata models does not alter prompt structure, token count, or API contracts as long as input serializers are separate from domain entity persistence.
**Fix (or queued).** Stored `AarEvidenceSnapshot` inside `analysisJson` on `CombatAarReport`. Guarded by unit test `combat_aar_report_test.dart` verifying all top-level keys in prompt and report serialization.
**Generalizable rule.** Decouple LLM prompt input builders from saved report persistence entities. Stored report entities can freely accumulate application-level provenance, audit trails, and UI state without impacting LLM token usage or invalidating prompt schemas.
**Refs.** docs/specs/aar-evidence-completeness-score-design.md §1.3 (D2), §3.3; `lib/features/combat_analyzer/domain/combat_aar_report.dart`; `test/features/combat_analyzer/domain/combat_aar_report_test.dart`.

### Flat-average EHP hides resist holes; profile-weighted EHP is required for tactical AAR analysis

**Author.** Antigravity / Lead Orchestrator
**Context.** The dogma engine previously computed layer EHP as `hp / (1 - meanResist)`, which evaluates EHP against a theoretical flat-omni damage profile. When analyzing tactical combat encounters, this flat number completely obscures whether a victim or pilot died because incoming damage concentrated in their primary resist hole.
**Evidence.**
- A 1,000 HP shield layer with resists 0% EM, 50% Thermal, 50% Kinetic, 50% Explosive (mean resist 37.5%) reports 1,600 omni EHP. Against pure EM damage, real EHP is exactly 1,000 HP.
- In S1, a victim with armor resists 52.4% EM / 34.8% Thermal / 63.1% Kinetic / 71.2% Explosive faced 78% Kinetic and 19% Thermal incoming damage. The 34.8% Thermal resist is the relative resist hole by incoming weight even though it is above 20% absolute.
**Mechanism.** EHP is inherently path-dependent: $\text{Layer EHP} = \frac{\text{hp}}{\sum_t p_t (1 - r_t)}$ where $p_t$ is the normalized incoming damage fraction. With $p_t = 0.25$, it collapses to flat-average $hp / (1 - \text{mean})$, but against any real distribution it measures true survivability.
**Generalizable rule.** Never use flat arithmetic averages for defense metrics where the incoming distribution is known. Profile-weighted EHP preserves the omni collapse for general stats while accurately computing matchup survivability.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §0 C7, §2.4, §9; test/features/fitting/domain/damage_pattern_test.dart.

### Operator 2/3 (modAdd/modSub) was discarded as unsupported; shield extenders and plates contributed 0 HP

**Author.** Antigravity / Lead Orchestrator
**Context.** The DogmaEngine supported operators 0/4 (multiply) and 6 (percent), counting operator 2 (`modAdd`) and operator 3 (`modSub`) as unsupported and dropping them. Consequently, Medium/Large Shield Extenders and 400mm/800mm/1600mm Armor Plates added zero HP, signature radius, or mass to any fitted ship.
**Evidence.**
- Medium Shield Extender II publishes `effect 21: ItemModifier / op 2 / 263 <- 72 / shipID` (+1,100 HP) and `effect 2029: 552 <- 983` (+7m sig). 1600mm Steel Plates II publishes `effect 2837: op 2 / 265 <- 1159` (+4,800 HP) and `effect 1959: 4 <- 796` (+3,750,000 kg mass).
- A 1600mm-plated Rifter reported 450 armor HP instead of 5,250 HP and base align time (4.73s) instead of 21.37s.
- Pyfa attribute evaluation order is: $\text{value} = (\text{base} + \sum \text{adds}) \times \prod \text{multipliers} \times \text{chain}(\text{percents})$. Pre-multiplying base before adds yields incorrect results (e.g. Shield Management V on MSE II: $(450 + 1100) \times 1.25 = 1,937.5$, whereas pre-add multiply yields $1,662.5$).
**Mechanism.** Modifier routing engines must support additive operators on base attributes before applying multiplicative and percent chains.
**Generalizable rule.** A modifier routing engine must count and surface unsupported operators *per attribute* and log them as actionable errors during test discovery, rather than quietly swallowing them under an aggregate debug counter.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §0 C1, §2.1, §9; commit cc693c6.

### Hull resonance attribute IDs are 113/110/109/111; 974–977 are Damage Control bonus attributes

**Author.** Antigravity / Lead Orchestrator
**Context.** `DogmaAttributes.hull*Resist` were pointed at 974–977 (`hullEmDamageResonance` etc.). Probing the bundled SDE revealed that ships carry their natural hull resonances at attributes 113 (EM), 110 (Thermal), 109 (Kinetic), and 111 (Explosive), with stackable=0 and base value 0.67 (33% natural resist) on every ship.
**Evidence.**
- Attributes 974–977 are the Damage Control's own bonus attributes (`stackable=1`, never present on hull types). Ships publish 974–977 = 1.0 (0% resist).
- Damage Control II publishes `effect 2302` which modifies 113/110/109/111 on the ship (`op 0, factor 0.60`).
- Because constants pointed to 974–977, bare hulls reported 0% hull resist (350 EHP for Rifter instead of 522.39 EHP), and DCU II hull resist bonus never applied.
**Mechanism.** CCP dogma separates a module's modifying attribute from the target item's modified attribute. Damage Control units carry bonus attributes 974–977 to scale effect 2302, but the target attributes on the ship are 113/110/109/111.
**Generalizable rule.** Verify both sides of a dogma modifier: the modifying attribute on the module and the modified attribute on the target ship. Do not conflate module bonus attributes with ship state attributes.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §0 C2, §2.2, §9; commit cc693c6.

### `_skillModifiers` carried five wrong skill IDs because tests copied the table not the SDE

**Author.** Antigravity / Lead Orchestrator
**Context.** DogmaEngine's hardcoded `_skillModifiers` table mapped five of seven skill IDs incorrectly: 3418 was labeled CPU Management (actually Capacitor Management; CPU is 3426), 3402 was labeled Power Grid Management (actually Science; PG is 3413), 3455 was labeled Navigation (actually Warp Drive Operation; Nav is 3449), 3424 was labeled Cap Management (actually Energy Grid Upgrades), and 3425 was labeled Shield Management (actually Shield Upgrades; Shield Mgmt is 3419).
**Evidence.**
- All V derivations masked this because All V loaded all skills at level 5. Known-character skill derivations, however, read the wrong skills from the character's ESI cache.
- Unit tests encoded the exact same wrong IDs (e.g. asserting `CharacterSkill(3418, 5)` gave CPU bonuses). The tests were green because both the engine and tests shared the mistaken ID.
**Mechanism.** Circular verification: when test fixtures copy constants or IDs from the code under test instead of an independent external authority (the bundled SDE), bugs become self-validating specifications.
**Generalizable rule.** Fixture IDs and test expected values must be sourced directly from bundle JSON or official data exports, never copied from the implementation under test.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §0 C3, §2.3, §9; commit cc693c6.

### SDE Categories 16 (Skill) & 87 (Fighter) publish dogma modifiers; version gating prevents stranded installs

**Author.** Antigravity / Lead Orchestrator
**Context.** The 2026-09-08 premise that "modifierInfo stops at item boundaries" proved to be an artifact of SDE extraction filtering: category 16 (Skill) and category 87 (Fighter) were excluded from `TARGET_CATEGORIES` in `generate_dogma_sde.py`. Once bundled, published `LocationRequiredSkillModifier` entries on skill types directly model weapon cycle-time bonuses (Gunnery, Rapid Firing, MLO, Rapid Launch, XL specs) and carrier/fighter interactions.
**Evidence.**
- Bundling categories 16 and 87 expanded `dogma.json` by +0.71 MB (+511 skills, +94 fighters) and `effect_modifiers.json` by +139 KB (2,596 effects total).
- All 780 published weapons with a cycle time directly require Gunnery or MLO via six slots `{182, 183, 184, 1285, 1289, 1290}` (zero transitive-only).
- Gunnery grants -2%/level turret cycle via attribute 441 (`turretSpeeBonus`), compounding with Rapid Firing (-4%/level via 293) for 0.72x cycle at all-V.
- Only effect 1851 (six sub-capital missile specialisations) publishes empty `modifierInfo` and requires a single curated fallback.
- `SdeService.bundledDogmaVersion = 2` coupled with `SdeMetadata` key `dogma_version` triggers idempotent re-import without wiping user data or seeded skill ranks.
**Mechanism.** CCP's published SDE encodes skill-to-module bonuses as resolved dogma modifiers on the skill types themselves using domain `shipID` and operator 6 (`postPercent`). When consumer category filters omit Skills, those modifiers never reach the bundled JSON.
**Generalizable rule.** Always check raw SDE source tables across all categories before assuming CCP does not publish cross-item modifiers. Version data migrations deterministically with schema/bundle version metadata keys.
**Refs.** LEARNINGS 2026-09-08 (corrected inline below); DECISIONS 2026-09-11; ARCHIVE SHIPPED 2026-09-11; `.agents/plans/2026-09-11-fitting-completion-skill-rof-and-fighters.md`.

### 2026-09-08

### modifierInfo stops at item boundaries: skill-to-module bonuses are pyfa-hardcoded

> **Correction (2026-09-11).** The premise that "modifierInfo stops at item boundaries" was incorrect; Category 16 (Skills) was simply excluded from the bundled SDE generation (`TARGET_CATEGORIES`). Most skill-to-module bonuses (Rapid Firing 582, Gunnery 414, MLO/Rapid Launch 1763, XL specs 6577/6578, DDA 6556 on fighters) are fully published. Only effect 1851 and drone/missile damage effects (660–668, 1730) publish empty modifier lists. See LEARNINGS 2026-09-11 above and ARCHIVE SUPERSEDED.

**Author.** Qwen Code
**Context.** The queued "operator 2 (missile specialisation)" item promised
the last missile DPS fidelity gap; investigating it before implementing
showed the premise was wrong and uncovered a different, real gap.
**Evidence.** Op-2 modifiers on attribute 212 belong to implants/NPCs
(`characterMissileDamageMultiply` on "Three Dimensional Thinking Bonus",
`npcBehaviorSiege`), not skills. Missile specialisation skills carry no
damage modifiers at all in the current SDE; their bonus is cycle time
(attribute 293 `rofBonus`, e.g. -4 Rapid Firing, -2 MLO/specialisations),
published only as skill-internal `itemID` modifiers (effects 163/1851) that
resolve nothing cross-item. pyfa implements the cross-item part with
hardcoded handlers: Effect582 (Rapid Firing -> modules requiring Gunnery),
Effect1851 (specialisations -> requiresSkill(skill)), plus MLO-family
handlers; the SDE gives no field that reproduces those filters, and
derived rules fail (Rocket Specialization's own 183 = 3320 would boost every
launcher; HAM Specialization's 182 = 3319 would boost rocket launchers).
**Mechanism.** CCP's resolved modifiers describe effects whose targets are
reachable by domain/group; skill aura bonuses encode their target set in the
effect identity itself, which only a handler table (pyfa) or the client knows.
**Fix.** None shipped: implementing a guessed filter would silently misapply
bonuses across weapon classes. Queued as P2 with the evidence and the pyfa
handler references, gated on an in-game/pyfa-diff cross-check.
**Validation.** Data probes across invTypes/dgmTypeAttributes/dgmTypeEffects/
dgmEffects (owners, required skills, modifier payloads) plus pyfa source.
**What surprised.** A queued item's premise can invert under investigation:
the "missing operator" was a red herring; the real gap publishes no data.
**Generalizable rule.** When the reference implementation hardcodes per-effect
filters, treat the filter as part of the effect's identity — curate and
cross-check it, never derive it from adjacent attributes.
**Refs.** QUEUED skill cycle-time bonuses entry; pyfa eos/effects.py
Effect582/Effect1851.

### Cap boosters fire on demand, not on a cadence (pyfa capSim injector port)

**Author.** Qwen Code
**Context.** Cap stability was wrong for booster fits: the simulator ignored
cap gains, so a fit that stays alive on Cap Booster 400s read as unstable.
**Evidence.** pyfa `eos/capSim.py`: injector activations are popped like any
module but postponed into `awaitingInjectors` when `cap - capNeed > capacity`
(overshoot), fired the moment a drain cannot be paid (`capNeed > cap`), and
used to top up after spending; gains travel as negative capNeed. The SDE
keeps the gain on the charge (capacitorBonus 67, e.g. 400 GJ) and the reload
on the module (reactivation delay 1795, 10s on cap boosters), and pyfa adds
that delay to every module's cycle time.
**Mechanism.** Boosters are reserve capacity, not repeating supply: firing
them on a cadence wastes gains to overshoot and misreports stability.
**Fix.** CapSimulator gained `injectors` with postpone/fire/top-up logic and
an awaiting-set signature inside the period-wrap stability check; DogmaEngine
collects injectors from fitted booster charges and adds 1795 to every cycle.
Clips stay infinite (fittings carry no charge quantities) — documented.
**Validation.** cap_simulator_test (60 GJ/s drain unstable alone, stable with
a 400 GJ/10s booster; boosters alone hold 100%) and dogma_engine_test (a
loaded booster stabilizes an otherwise unstable drain); 433 tests green.
**What surprised.** The gain/reload split across charge and module, and that
reactivation delay joins every module's cycle, not just boosters'.
**Generalizable rule.** Port reserve-resource semantics (on-demand firing)
before cadence semantics, and check where each number lives in the SDE.
**Refs.** ARCHIVE SHIPPED 2026-09-08 cap injectors entry; QUEUED clip reloads.

### Production-wiring widget tests need runAsync for Drift isolates and a grown test surface

**Author.** Qwen Code
**Context.** Locking the fitting-stats chain (SdeService -> providers ->
engine -> StatsPanel) against the dead-`effects` bug class required a widget
test that uses the real Drift-backed service instead of fixtures.
**Evidence.** First attempt hung with no output: `SdeDatabase`'s
`NativeDatabase.memory()` answers from a background isolate, and port
replies never reach a future that started inside the widget-test FakeAsync
zone (provider futures kick off during `pumpWidget`). A later failure showed
the lazy `ListView` in StatsPanel stopping mid-section: Scaffold bodies give
tight window-height constraints, so an oversized `SizedBox` is ignored and
only ~600px of rows build.
**Mechanism.** FakeAsync pumps virtual time but does not turn the real event
loop, so isolate/port and sqflite work must run inside `tester.runAsync`;
and lazy slivers only build children within viewport+cacheExtent of the
real surface size.
**Fix.** Resolve the provider chain in a bare `ProviderContainer` inside one
`runAsync` block, then render StatsPanel against the resolved stats with
`tester.view.physicalSize` grown (1200x2400) so every row lays out.
**Validation.** `fitting_stats_production_wiring_test.dart`: Tristan with
loaded autocannon + Warriors + DDA II yields dps 50.4 (guns 3.4, drones 47.0)
and renders OFFENSE/DRONES rows; 430 tests green.
**What surprised.** A fit that looks fine in fixtures can be correctly
rejected by the engine: Warriors on a Rifter produce 0 drone DPS because the
Rifter's drone bandwidth is 0 — the test had to move to a Tristan.
**Generalizable rule.** Widget tests over real services: wrap isolate-backed
async in runAsync before pumpWidget, and size the surface for lazy lists.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry; HANDOFF next step.

### modifierInfo's skillTypeID is a target filter, not the scaling skill

**Author.** Qwen Code
**Context.** The first drone/amp increment scaled every skill-linked modifier
by the linked skill's level, which made Rifter's racial bonus scale with
Small Projectile Turret instead of Minmatar Frigate (a character with SPT V
and MF 0 would have gotten the full bonus).
**Evidence.** Bundled data: Rifter effect 7248 carries `skillTypeID: 3302`,
and 3302 is Small Projectile Turret (skills.json), while the Rifter's own
required skill (attribute 182) is 3329 = Minmatar Frigate; the turret's
attribute 182 is 3302. pyfa's handlers confirm the split: `Effect7248`
filters `requiresSkill('Small Projectile Turret')` and scales with
`skill='Minmatar Frigate'`, while `Effect6556` (drone damage amp) and
`Effect3656`/`Effect889` filter by skill and apply the value raw.
**Mechanism.** CCP's resolved modifiers publish one skill link — the skill
targets must require (pyfa's filter). Ship-owned racial bonuses scale with
the ship's own required skill (attributes 182/183/184); module-owned bonuses
(amps, enhancers, BCS rof) apply raw.
**Fix.** DogmaEngine routes with `ownerIsShip`: ship-owned modifiers scale
with `shipSkillLevel` (from the ship's required-skill attributes),
module-owned apply raw; `skillTypeID` filters targets via their required
skills. Operator 4 joined 0 as postMul (heat sink/BCS family, pyfa
Effect91/763 multiply handlers), and BCS-style `charID` modifiers on 212
multiply loaded missile damage components like pyfa's filteredChargeMultiply.
**Validation.** `dogma_engine_test.dart` (filter vs scaling, amp raw, heat
sink op 4, BCS missile multiply) and `real_sde_weapon_test.dart` (Rifter at
Minmatar Frigate V from bundled data; Warrior II + DDA II = 47 DPS);
429 tests green.
**What surprised.** One field serving as filter while the scaling skill lives
only on the owner ship — the data alone is ambiguous without pyfa.
**Generalizable rule.** When two publishers disagree in shape, use the
reference implementation's handlers to disambiguate field semantics.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry; LEARNINGS 2026-09-08
modifierInfo entry.

### The SDE publishes resolved dogma modifiers; dgmExpressions is retired and fuzzwork moved to csv/

**Author.** Qwen Code
**Context.** Unlocking DPS/volley/optimal needed ship weapon bonuses, which
were assumed to live in dogma expression trees (the plan was to bundle
`dgmExpressions` and evaluate them pyfa-style).
**Evidence.** fuzzwork `csv/dgmExpressions.csv` is header-only (1 row);
`csv/dgmEffects.csv` carries a `modifierInfo` column with CCP's resolved
modifiers, e.g. Rifter effect 5779:
`{"domain": "shipID", "func": "LocationRequiredSkillModifier", "modifiedAttributeID": 158, "modifyingAttributeID": 587, "operation": 6, "skillTypeID": 3302}`.
Separately, the old flat `*.csv.bz2` URLs 404 since the dump moved to `csv/`
plain files (verified 2026-09-08), which would have broken regeneration.
**Mechanism.** CCP replaced expression-tree publication with pre-resolved
modifier lists per effect, including skill linkage (`skillTypeID`) and group
restrictions (`groupID`); func + domain encode the routing: `ItemModifier` +
`shipID` = owner modifies the ship (hardeners, damage control), `Location*`/
`Owner*` + `shipID` = owner modifies fitted modules (racial weapon bonuses,
tracking enhancers), `charID` = owner modifies loaded charges (missile
damage bonuses), `itemID` = self only.
**Fix.** `scripts/sde/generate_dogma_sde.py` fetches the new `csv/` layout and
bundles `assets/sde/effect_modifiers.json` (2090 effects, 1984 with
modifiers); DogmaEngine routes by func/domain instead of evaluating trees.
**Validation.** `test/features/fitting/domain/real_sde_weapon_test.dart`
loads the bundled assets from disk and reproduces Rifter's traits
(-7.5%/level rof, +10%/level falloff at skill 3302) end to end.
**What surprised.** The expression-tree port was unnecessary: the retired
table's replacement is strictly better data (resolved, skill-aware).
**Generalizable rule.** Re-check the data source before porting an
evaluation engine; publishers sometimes replace trees with resolved facts.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry; QUEUED drone DPS.

### Production fitting stats silently ignored every module bonus (effects never populated)

**Author.** Qwen Code
**Context.** While wiring ship bonuses I traced why the engine's module
modifier loop could never fire in the app although tests passed.
**Evidence.** `SdeService.getModuleType` built `ModuleType` without `effects`
(model default `[]`), so `fittingStatsProvider`'s `effectIds` list was always
empty and `ensureEffectModifiers([])` returned `{}`; only hand-built test
fixtures had effects.
**Mechanism.** The Drift table `SdeTypeEffects` was seeded and read for slot
detection (`getTypeEffects`), but nobody mapped those rows into the model, so
hardener/damage-control/propulsion bonuses were absent from real stats while
every unit test constructed modules with effects and stayed green.
**Fix.** `getModuleType`/`getShipType` now populate `effects` (names from the
bundled effect metadata); the stats provider also resolves charge types so
missile/turret damage has its source data.
**Validation.** `test/core/sde/sde_service_test.dart` asserts seeded effect
rows surface on `ShipType.effects` with bundled names; full suite 422 green.
**What surprised.** A test suite can be fully green while a production path
is dead, when fixtures bypass the very mapping that is missing.
**Generalizable rule.** Fixture-built tests must be paired with at least one
test that walks the real repository/service mapping.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry.

### Capacitor stability is an event simulation, not a formula (pyfa eos/capSim.py port)

**Author.** Qwen Code
**Context.** The stats panel's "Stable" row needed cap stability, which has no
closed form once module cycles repeat against the recharge curve.
**Evidence.** pyfa's `eos/capSim.py` (fetched 2026-09-07): recharge between
events is `cap = ((1 + (sqrt(cap/C) - 1) * exp(-dt/tau))^2) * C` with
`tau = rechargeTime / 5`; identical modules are staggered as one activation
every duration/count; stability is detected when the cap at a whole LCM period
is no lower than at the previous one; negative cap ends the sim as unstable
with time-to-empty.
**Mechanism.** The recharge curve is nonlinear, so average-rate maths cannot
answer "does this fit hold cap"; only stepping through activations can.
**Fix.** `lib/features/fitting/domain/cap_simulator.dart` ports that algorithm
(repeating drains only: no cap injectors, no reloads — documented in the
class); DogmaEngine feeds it per-module capacitorNeed (6) and duration (73,
milliseconds) and reports stable percent or seconds-to-empty; the panel shows
percent when stable, seconds when not, dash when unmodelled.
**Validation.** Five simulator tests (empty, light, overwhelming, stagger
equivalence, monotonic stability) plus two engine-level tests.
**Generalizable rule.** When a reference implementation exists (pyfa), port
its algorithm and pin behaviour with tests rather than re-deriving approximations.
**Refs.** QUEUED 2026-09-07 cap-stable entry (now shipped).

### Dogma operator semantics come from live ESI; some bonuses hide in expression trees

**Author.** Qwen Code
**Context.** Making module resist/EHP modification real required knowing how
each effect transforms ship attributes, which the bundled SDE does not store
(it carries effect IDs only).
**Evidence.** Live `GET /dogma/effects/{id}/` on 2026-09-07: effect 5230
(EM Shield Hardener II) uses operator 6 with modifying attributes 984-987 whose
local values are percent units (-55); effect 2302 (Damage Control) uses
operator 0 mapping module resonances onto ship resonances (0.85); effect 6731
(moduleBonusAfterburner) returns an EMPTY modifier list while the module's
speedFactor attribute is 135 on a 1MN AB II.
**Mechanism.** Operator 6 is postPercent (confirmed by the percent-unit bonus
attributes); operator 0 must be postMul, since postPercent would make a 0.85
resonance bonus a no-op and assignment would overwrite better base resonances.
Effects with empty modifier lists encode their bonus in pre/post expression
trees, which ESI does not publish (only expression IDs), so they cannot be
derived from ESI alone.
**Fix.** Engine applies cached ESI modifiers (new SdeEffectModifiers table,
SDE schema v6) with {6: postPercent + stacking penalty on resonances,
0: postMul}; the earlier guessed `speedFactor` multiplication was removed —
with the real value of 135 it would have multiplied speed by 136. Propulsion
is nonetheless modelled via a small curated map for the two expression-tree
effects (6730 MWD, 6731 AB): speedFactor is percent units and the bundled SDE
values (AB I 115, AB II 135, MWD I 500, MWD II 510) match the in-game
multipliers x2.15/x2.35/x6/x6.1. Unknown propulsion-style effects are ignored
rather than guessed. (Amended inline 2026-09-07; earlier text said velocity
stays base+skills.)
**Validation.** Engine tests pin postPercent, postMul, stacking-penalty and
domain-filtering maths; three consecutive full-suite runs green (404 tests).
**Generalizable rule.** Check a dogma attribute's units and operator against
live data before applying any "attribute times factor" maths.
**Refs.** DECISIONS 2026-09-07 "Fitting tank math is data-driven";
QUEUED P2 expression-tree entry.

### ESI cannot write the skill queue — verified against the live OpenAPI spec

**Author.** Qwen Code
**Context.** The 2026-09-07 audit listed "zero authenticated ESI writes" as the
top capability gap and proposed pushing skill plans to the game.
**Evidence.** `https://esi.evetech.net/meta/openapi.json` fetched 2026-09-07:
34 write operations in total, none under `/characters/{id}/skillqueue` or
`/characters/{id}/skills` (both GET-only), and the only skill scopes are
`esi-skills.read_skills.v1` and `esi-skills.read_skillqueue.v1`.
**Mechanism.** CCP never exposed skill-queue management over ESI, so every EVE
companion app — not just Mimir — is read-only for skills. The audit item was a
platform property misread as a product gap.
**Fix.** Shipped the writes ESI does support instead: save-fitting-to-EVE and
autopilot waypoints, both behind an explicit confirmation dialog.
**Generalizable rule.** Verify a capability against the live spec before
planning a feature around it; a missing endpoint is invisible from the client.
**Refs.** DECISIONS 2026-09-07 "Phase 6 writes"; QUEUED Maybe entry.

## 2026-09-07

### ESI removed GET /search/; POST /universe/ids/ is the supported replacement

**Author.** Qwen Code
**Context.** The Market Browser's default tab could never return a result, and
the Intel watch-list dialog had no way to resolve names at all.
**Evidence.** `curl 'https://esi.evetech.net/latest/search/?categories=inventory_type&search=tritanium'`
returns 404. `POST /universe/ids/` with `["Jita","Amarr"]` returns
`{"systems":[{"id":30000142,"name":"Jita"},...]}`; with `["Tritanium"]` it
returns `inventory_types:[{"id":34,...}]`.
**Mechanism.** The standalone public search route was withdrawn from ESI.
`/universe/ids/` is the supported public name-resolution endpoint and returns
category-keyed maps; it matches whole names, not substrings.
**Fix.** 6b2e06d (market search: SDE substring first, `/universe/ids/` to
augment), d903ff9 (watch-list name resolution).
**Validation.** Provider tests plus live curl against the running endpoint.
**What surprised.** The solar-system key is `systems`, not `solar_systems`.
**Generalizable rule.** Verify an EVE endpoint against the live service before
building on it; a 404 can sit behind a green build for months.
**Refs.** DECISIONS 2026-09-07 "Dead inferior UI..."; QUEUED P2 mapper entry.

### Golden tests race async providers; pin the providers, do not add a tolerance

**Author.** Qwen Code
**Context.** The Skills goldens failed roughly half of full-suite runs with
"Pixel test failed, 0.00%, 3px diff" yet passed every time in isolation.
**Evidence.** The isolated diff image contained a single speck at the top bar,
where the unallocated-SP value renders; `unallocatedSpProvider` logs showed it
resolving during the capture window.
**Mechanism.** FutureProviders resolve on a pump phase that shifts with the
tests that ran earlier in the same process, so the capture sometimes caught the
top bar mid-resolution.
**Fix.** ce94c20 pins unallocatedSp, totalSkillPoints and queueStats to fixed
AsyncValues for both Skills goldens.
**Validation.** Ten consecutive full-suite runs green.
**What surprised.** A `LocalFileComparator` subclass with a percentage tolerance
made *every* golden fail with "Could not be compared against non-existent
file": the wrapper's `getGoldenBytes` threw before its tolerance logic ran.
That attempt was reverted.
**Generalizable rule.** Make golden inputs deterministic at the provider level;
comparison tolerances treat the symptom and can break golden path resolution.
**Refs.** ce94c20.

### Drift watch() streams do not emit inside bare test() containers here

**Author.** Qwen Code
**Context.** Provider-level tests for saved fittings awaited
`savedFittingsProvider(null).future` and timed out at 30s, while the identical
providers behave under `testWidgets`.
**Evidence.** TimeoutException plus "StreamProvider ... disposed during loading
state, yet no value could be emitted" in
test/features/fitting/presentation/fitting_save_load_test.dart before the fix.
**Mechanism.** Not fully root-caused; the first stream emission never arrives
under the plain test zone in this project's setup.
**Fix.** 959808b asserts persistence through one-shot repository reads
(`getFittings`), and `saveCurrent` resolves the active character with
`characterRepository.getActiveCharacter()` instead of the character stream.
**Validation.** Six fast, stable provider tests.
**Generalizable rule.** In provider unit tests prefer one-shot reads; keep
stream assertions in widget tests where a binding drives the loop.
**Refs.** 959808b.

### ReorderableListView.onReorderItem pre-adjusts newIndex

**Author.** Qwen Code
**Context.** Migrating off the deprecated `onReorder` looked mechanical.
**Evidence.** Flutter SDK reorderable_list.dart: the `onReorder` path passes the
raw drop index while `onReorderItem` passes the index computed after removing
the dragged item.
**Mechanism.** Keeping the app's historical `if (newIndex > oldIndex) newIndex -= 1`
correction on top of the pre-adjusted index shifts every downward drag one slot
early, silently corrupting plan order.
**Fix.** 9d221e2 removes the manual correction with a comment saying why.
**Generalizable rule.** When a deprecation changes a callback's parameter
semantics, read the SDK call site before migrating.
**Refs.** 9d221e2.

### TestApp rendered Flutter's default light theme while the app ships dark

**Author.** Qwen Code
**Context.** Every golden and integration test rendered a theme no user sees.
**Evidence.** sub_window_app.dart hardcodes `AppTheme.darkTheme()`; the
regenerated light-theme Industry golden showed a white-on-white "No Industry
Jobs" empty state.
**Mechanism.** TestApp's MaterialApp declared no theme, so tests got Flutter's
light default.
**Fix.** 9d221e2 sets `AppTheme.darkTheme()` in TestApp and regenerates all
baselines in the shipped theme.
**Validation.** Dark baselines reviewed visually; contrast problems became
visible instead of hidden.
**Generalizable rule.** A test harness must render the shipped theme, or the
suite validates a product that does not exist.
**Refs.** 9d221e2.

## 2026-05-21

### macOS Flutter sub-windows need explicit plugin and config boundaries

**Author.** Codex
**Context.** Combat Analyzer runs as a desktop sub-window. Several failures
looked like UI or scanner bugs, but the root cause was sub-window/plugin
boundary behavior on macOS.

**Evidence.** The recovery checkpoint recorded two concrete faults:
`shared_preferences` produced a sub-window plugin-channel error, and the folder
picker did nothing until native plugin registration was added for
`desktop_multi_window` sub-windows. The scanner later moved selected directory
state into app-support `combat_analyzer.json` instead of relying on
`SharedPreferences`.

**Mechanism.** Each desktop sub-window has its own Flutter engine. Plugins that
work in the main engine are not automatically safe in sub-windows unless the
native side registers them for that engine. Config needed by sub-windows should
also live in a file/database surface the sub-window can read directly.

**Fix.** Register generated plugins for macOS sub-windows and use
app-support JSON for Combat Analyzer config.

**Validation.** Folder selection started working from the Combat Analyzer
window, and scanner state loaded from the saved config instead of getting stuck
behind "scanner not ready" behavior.

**Generalizable rule.** For multi-window Flutter desktop features, assume
plugin registration and state access are per-engine concerns. Prefer database
or app-support files for cross-window state, and verify native plugin
registration for any UI action launched from a sub-window.

**Refs.** `.codex/plans/2026-05-20-combat-analyzer-recovery.md`.

### EVE gamelog folders are mostly non-combat and need cached classification

**Author.** Codex
**Context.** The initial log scanner found many files but either showed
non-combat events or appeared empty depending on directory and parser readiness.

**Evidence.** The recovery checkpoint recorded
`/Users/jefcox/Documents/EVE/logs/Gamelogs` with 1,419 timestamped gamelog
files, but only 56 classified as combat logs and 1,363 classified as
non-combat. Those 56 combat logs produced 295 displayable encounters.

**Mechanism.** EVE gamelogs include timestamped files for many client events,
not just combat. Filename shape proves "EVE gamelog", not "combat log".
Scanning every historical file on startup is wasteful, and showing every
timestamped file pollutes the AAR list with skill redemption and other
non-combat events.

**Fix.** Filter by actual combat-damage content and persist a classification
cache keyed by file path, modified time, and size. Cap initial scans to newest
files and recheck changed files.

**Validation.** Combat Analyzer loaded only combat-bearing logs, and unchanged
non-combat files were skipped on refresh without rereading their contents.

**Generalizable rule.** Treat game-log filename patterns as a broad source
filter only. Use content classification plus a file fingerprint cache before
building UI or sending data to AI.

**Refs.** `.codex/plans/2026-05-20-combat-analyzer-recovery.md`;
`tasks/todo.md`.

### Combat logs are a primary source but not a complete AAR evidence source

**Author.** Codex
**Context.** The combat analyzer initially produced useful AAR prose from EVE
combat logs, but reports still had many unknowns even after zKill/killmail
matching. The user wanted a path to resolve those unknowns instead of having
the AI guess.

**Evidence.** AAR enrichment implementation added
`lib/features/combat_analyzer/domain/combat_evidence_ledger.dart`,
`combat_fit_snapshot_mapper.dart`, `combat_damage_matchup.dart`, and v3 prompt
payload support in `lib/features/combat_analyzer/data/codex_analysis_client.dart`.
Focused checks passed:
`flutter test test/features/combat_analyzer test/features/fitting/domain/format_parser_test.dart`
and
`dart analyze lib/features/combat_analyzer lib/features/fitting/domain/format_parser.dart test/features/combat_analyzer test/features/fitting/domain/format_parser_test.dart`.

**Mechanism.** EVE combat logs prove event timing, damage lines, hits, misses,
weapons, and actors seen by the local client. They do not contain range,
transversal, tank layer depletion, pilot intent, historical pilot fit, full
opponent fit, or all ship/dogma modifiers. Killmails add destroyed-fit and
attacker/victim context, but they still do not prove the surviving pilot's fit
or the live range/application situation.

**Fix.** Added an evidence ledger and fit evidence model so AARs can separate
proven facts, user-confirmed facts, reference snapshots, derived facts, and
open unknowns. Added manual EFT/DNA fit import and current active ship snapshot
capture as explicit evidence-gathering paths.

**Validation.** Domain tests cover ledger serialization, current-ship asset
snapshot mapping, damage matchup classification, and SDE-backed EFT parsing.
Combat analyzer tests plus fitting parser tests pass.

**What surprised.** zKill/killmail enrichment reduced some unknowns but did
not eliminate the highest-value one for learning: the pilot's actual fit at
fight time.

**Generalizable rule.** Treat each EVE source as evidence with scope and
confidence. Do not let the AI collapse "unknown" into narrative certainty;
surface the missing evidence and give the user a way to resolve it.

**Refs.** [DECISIONS 2026-05-21](DECISIONS.md#combat-aar-v3-uses-evidence-ledger-and-fit-evidence-before-deeper-simulation);
[QUEUED AAR simulation work](QUEUED.md#p1--aar-fit-simulation-and-defense-profile-derivation);
[AAR plan checkpoint](../../.codex/plans/2026-05-21-combat-analyzer-aar.md).
