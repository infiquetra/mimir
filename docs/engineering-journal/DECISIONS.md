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

## 2026-11-16

### Rig calibration ships base-only in its own module and block, with rig cost gated on slot effect 2663 (feat/rust-rig-calibration)

**Author.** Muse Code (rig-calibration workflow, integrator)
**Decision.** Three choices ship together. First, calibration is a new pure sibling module `src/fitting/calibration.rs` (`CalibrationBudget{used, capacity, excluded_rigs}`, `CalibrationOutcome`, `rig_calibration`) and its own UI block `Rig calibration (base values)` between Fitting resources and Bays in both fitting details (`src/ui/fittings.rs:1631` `render_rig_calibration`, wired at `:1914` and `:2205`), rendering identically for every viewing character with no skill input. Second, the catalogue emits `upgradeCost` gated on rig slot effect 2663 (921 rigs including 279 category-66 structure rigs, every-rig invariant) and `upgradeCapacity` gated to category-6 ships when dogma 1132 exists (401 rows; 3 hulls absent and shown as unavailable, never zero). Base values only: no skill, implant, module, rig, subsystem, or ship-bonus modifiers, including calibration-reduction effects by name, with unknown-cost rigs excluded from the sum and disclosed by count. The catalogue grows from 3,148,744 to 3,176,352 bytes (+27,608), additive-only over the 25,818 existing rows.
**Rejected alternatives.** A third field on `FittingResources` / reusing `ResourceBudget`: the resources calculation is gated on both CPU and power grid outputs and carries skill scaling, so calibration would lose its numbers whenever CPU/power grid data is missing and would sit under the "(with skill bonuses)" heading when skills load, falsely labelling a base-only number; `ResourceBudget.output` also misnames a capacity. Gating `upgradeCost` on module category 7 (cloning the module-need gate): it would drop all 279 category-66 structure rigs, manufacturing false unknown-cost exclusions for real rigs. Porting Flutter's read (1153 as capacity behind a 400 fallback): wrong on every non-400 hull and never displayed even in Flutter; pinned as do-not-port by non-400 oracles.
**Rationale.** The bay-capacities slice already proved the separate-module, separate-block shape for an independently available base-value budget; calibration's facts (a ship capacity plus rig-slot costs) succeed or fail on their own catalogue rows, so coupling them to CPU/power grid availability or to a skill-labelled heading would only manufacture missing or mislabelled numbers. Effect 2663 is what makes a type a rig in the slot sense the sum counts (`RigSlot` flags), so emission keyed on the effect keeps "unknown cost" meaning genuinely unknown.
**Revisit when.** A grounded modifier pipeline (a skill, implant, or ship bonus that verifiably changes calibration capacity or rig costs in inspected bodies) exists — that reopens the base-only disclosure and the no-skill-input API together; or if a rig type appears whose calibration cost is consumed without effect 2663, which would re-ground the emission gate.
**Refs.** `docs/rig-calibration-design.md` sections 2.2, 4, 6, 9, 10; `src/fitting/calibration.rs`; `scripts/sde/generate_fitting_types_sde.py` (`CALIBRATION_ORACLES`); LEARNINGS 2026-11-16 Flutter 1153 entry above; DECISIONS 2026-11-16 bay-capacities entry below (the sibling-module precedent).

### Bay usage ships base-only: volume on every catalogue row, fighter bay included on its 2055 grounding, and flag-driven counting that mirrors the UI catch-all (feat/rust-bay-capacities)

**Author.** Muse Code (bay-capacities workflow, integrator)
**Decision.** Three choices ship together. First, per-type `volume` goes on every one of the 25,818 catalogue rows, growing `assets/sde/fitting_types.json` from 2,762,636 to 3,148,744 bytes (+386,108, about +14.0%, inside the design's 3,200,000-byte budget), because cargo can be any inventory type and no inspected body grounds a smaller subset. Second, the fighter bay is included: dogma 2055 `fighterCapacity` is present on exactly 12 ships in `dgmTypeAttributes` (for example 23911 Thanatos `70000.0` in the current cache; Flutter's retired asset showing 75000 is SDE drift and loses), and fighter volume is the same `invTypes.volume` column as everything else, so the bay is computed independently of the drone bay (all 12 carriers also carry 283/1271 at `0.0`). Third, which bay an item counts toward is flag-driven, mirroring the grouped fitting list's section assignment (`src/fitting/bay_usage.rs:76` and `:97`): exact `DroneBay` and `FighterBay` flags select those bays, slot-prefixed flags count nowhere, and every other flag — the UI catch-all, including `Cargo`, `Invalid`, and `ServiceSlot*` — counts as cargo volume. Base values only throughout: no skill, module (cargo expanders named), rig, subsystem, implant, or ship capacity bonuses, and no specialized holds, with unknown-volume or unknown-bandwidth items excluded from the sums and disclosed by count, never zeroed.
**Rejected alternatives.** A volume subset (only categories "plausibly" carried): cargo in a saved or imported fitting can be any published type, so a subset would manufacture unknown-volume exclusions for real cargo and rest on an ungrounded category guess. Excluding the fighter bay until a later slice: the capacity attribute and used-volume semantics were both grounded in inspected bodies, so exclusion would have shipped carriers with silently missing bay numbers. Category-driven counting (drones by category 18, fighters by category 87, regardless of flag): it would disagree with the grouped list rendered directly above the numbers, so a user could see an item listed under Cargo while its volume was charged to the drone bay. Flutter's capped active-only drone bandwidth math: this slice shows plain fitted sums at base values, and the divergence is deliberate and disclosed.
**Rationale.** The volume-on-every-row cost is a one-time catalogue size decision that buys the honesty rule (unknown means genuinely absent from the data, not absent by our subset choice); the fighter bay costs one more sparse key on 12 rows once volume is universal; and flag-driven counting keeps the bay block consistent with the section list the user is already reading, at the stated cost that a `ServiceSlot*` item's volume is charged to cargo, the same over-count the catch-all section display already implies.
**Revisit when.** A grounded modifier pipeline (capacity bonuses or specialized holds) is inspected — that change reopens the base-only disclosure and the catch-all counting together; or when the catalogue size budget is next renegotiated, at which point the universal-volume choice is re-costed against measured exclusion rates rather than re-argued from categories.
**Refs.** `docs/bay-capacities-design.md` sections 2.3, 2.4, 3.2, 9 and 10; `scripts/sde/generate_fitting_types_sde.py:287` (`BAY_ORACLES`); `src/fitting/bay_usage.rs:119` (`bay_usage`) and its section-assignment and unknown-row pins; `src/ui/fittings.rs:1665` (`render_bay_usage`, wired into both fitting details); LEARNINGS 2026-11-16 "38" collision entry above.

### Base EHP ships omni-only, composed in resonance space in its own sibling module, with a total only when every layer is computable (feat/rust-ship-base-ehp)

**Author.** Muse Code (ship-base-ehp workflow, integrator)
**Decision.** Three composition choices ship together. First, the only damage profile is omni (equal quarters EM, thermal, kinetic, explosive; `OMNI_*_SHARE` constants at `src/fitting/ship_ehp.rs:31`), named in the heading and disclosure (`src/ui/fittings.rs:1200` and `:1208`). Second, EHP is computed in resonance space by the new sibling module `src/fitting/ship_ehp.rs` (`ship_base_ehp` at `:121`) doing its own catalogue lookup, with a per-layer denominator of share-weighted resonance and the retired engine's `denominator <= 0` guard returning raw hit points. Third, a layer's line is omitted when its base hit points or any of its four resonances is unusable, and the total appears only when all three layers are computable. The #578 decisions on self-labelling blocks and independent availability are followed, not re-decided: this block succeeds or fails on its own catalogue facts, independent of the resources, base-values, and resistances blocks.
**Rejected alternatives.** Per-damage-type EHP columns (pure EM/thermal/kinetic/explosive) or any profile picker: the retired fitting engine's sole preset, sole call, and sole stored profile is omni, so other profiles in a fitting view would be invention. Percent-space composition over the resistances block's `ShipResistances` values, and extending `ship_resistances` to expose resonances: the first round-trips display rounding into the division, the second widens a shipped sibling's API for one consumer when a self-contained lookup costs twelve field reads. Partial totals (summing whichever layers exist) and relabelled partial totals: a "total" that silently treats a missing layer as zero is exactly the dishonest fitted-looking number this slice forbids, under any label.
**Rationale.** Omni is the only profile grounded in an inspected fitting-display body, resonance space is the only space where the stored values divide without manufactured rounding, and total-only-when-complete is the only total whose label never overclaims. On shipped data the omission paths are again fixture-only (all 404 published ships are fully computable), which is precisely why they are pinned by fixtures rather than left implicit.
**Revisit when.** A grounded modifier pipeline (fitted modules, rigs, subsystems, skills, implants, ship bonuses) or a grounded fitting-display body for non-uniform damage profiles is inspected — either one reopens the profile set, the input space, and the disclosure in that change, not by silently widening this block.
**Refs.** `docs/ship-base-ehp-design.md` sections 2, 4-6, 9 and 10; `src/fitting/ship_ehp.rs:96` (denominator) and its missing-data/denominator-edge/independence pins; wording and omission pins in `src/ui/fittings.rs`; LEARNINGS 2026-11-16 ship-base-EHP profile-naming entry; DECISIONS 2026-11-16 self-labelling-blocks and base-values-first entries below.

### A resonance above 1 renders its true signed percent; a negative resonance is invalid data (feat/rust-ship-resistances)

**Author.** Muse Code (ship-resistances workflow, integrator)
**Decision.** Base resistances apply no clamping and no upper bound anywhere: a present resonance above 1 converts by the same `(1 - resonance) * 100` and renders its true signed percent (1.1 renders -10.0%, 7.0 renders -600.0%), in the generator, the catalogue loader invariants, and `resonance_to_percent` (`src/fitting/ship_resistances.rs:66`). A negative resonance is instead invalid data: the generator fails on it and writes nothing, and a negative value reaching the pure function is no data for that one resistance only. A finite resonance whose computed percentage is non-finite is likewise no data, so it never reaches the formatter.
**Rejected alternatives.** Clamping rendered percentages into 0% to 100%: it silently rewrites a grounded value into a different one, the exact dishonesty this slice forbids. Failing generation on any resonance above 1: the cache scan sees unpublished NPC rows at 1.1, 1.2, and 7.0 today, so generation would fail on current data for rows the category-6 gate never emits.
**Rationale.** On shipped data the question is unreachable (all 4,848 ship resonances lie in 0.10 to 1.00), but a resonance above 1 is a real cache value shape and the retired Flutter engine rendered the signed result with no clamp, while a negative resonance exists nowhere in the cache and both precedents (generator failures on negative wanted values, the ship-base-stats usable rule) already treat negatives as invalid data. Each treatment follows its evidence instead of one blanket range rule.
**Revisit when.** A published ship ever carries a resonance outside [0, 1] in the cache — then re-decide from that row's provenance before rendering it, rather than extending this fixture-only rule by default.
**Refs.** `docs/ship-resistances-design.md` section 2 (out-of-range locks) and section 9; `scripts/sde/generate_fitting_types_sde.py:97` (`RESIST_ATTR_IDS`); signed/negative/overflow pins in `src/fitting/ship_resistances.rs`; LEARNINGS 2026-11-16 ship-resistances hull-set entry.

### Each base-attribute block ships as its own heading plus disclosure, available independently of its neighbours (feat/rust-ship-base-stats)

**Author.** Muse Code (ship-base-stats workflow, integrator)
**Decision.** The new "Ship (base values)" block (`src/ui/fittings.rs:1163`, rendered by `render_ship_base_stats` at `:1357` after the resources block in both fitting details) is its own heading with its own disclosure naming fitted modules, rigs, subsystems, skills, implants, and ship bonuses as not applied. Its availability is independent of the neighbouring resources block: `ship_base_stats` (`src/fitting/ship_stats.rs:56`) reads only the hull row and never the fitted items, so a ship with no usable CPU/power output can still show base values and the reverse. Each later base-attribute block follows the same shape rather than merging into one combined panel.
**Rejected alternatives.** Folding the five values into the resources block or its disclosure: one unavailable block would then hide or mislabel the other, and the skill-applied resources state would imply skills also adjust the ship values (they do not in this slice). Waiting for a full simulator panel: delays a provable base readout, against the base-values-first decision below.
**Rationale.** Implementation confirmed the two blocks fail and succeed on different catalogue facts (output rows versus the five base rows), and the bidirectional independence fixtures plus the real zero-output Echelon companion in `src/fitting/ship_stats.rs` prove neither block's availability implies the other's. Separate headings keep each disclosure exactly as wide as the numbers under it.
**Revisit when.** A grounded modifier pipeline begins adjusting these base values (skills, modules, rigs, subsystems, implants, or ship bonuses) — then the heading, disclosure, and availability contract for this block must be redesigned in that change, not silently widened.
**Refs.** `docs/ship-base-stats-design.md` sections 4, 6, and 9; `src/ui/fittings.rs:1169` (disclosure); LEARNINGS 2026-11-16 ship-base-attributes entry; DECISIONS 2026-11-16 base-values-first entry below.

### Two grounded skills join the resources readout; per-view character data resets at the switch boundary (feat/rust-fitting-skill-resources)

**Author.** Muse Code (fitting-skill-resources workflow, integrator)
**Decision.** Ship outputs in the fitting-resources readout now include CPU Management (skill 3426, +5% per trained level to CPU output) and Power Grid Management (skill 3413, +5% per trained level to power grid output) from the owning character's `trained_skill_level`, only when that character's skills bundle is loaded (`Ready`); otherwise the base-values block renders unchanged. Module need reductions, implants, and module/rig/subsystem/ship output bonuses stay excluded and named in the view. To make `Ready` mean "belongs to the active character", `skills` resets to Loading on a real character switch and on removing the active character (`src/app/state.rs:892` and `:991`) — this reset-at-switch convention binds every later slice that derives numbers from a per-character bundle: either reset the state at the boundary or stamp it with its owner and check the stamp at use.
**Rejected alternatives.** Owner-stamping `SkillsData` for this slice: a cross-builder field contract the Skills view does not need and this slice cannot regress-test cheaply. Assuming level 0 or 5 when skills are unloaded, or reusing a stale bundle until refresh lands: each silently shows the wrong character's or an invented number. Applying the Weapon Upgrades need-reduction family in the same slice: the retired Flutter engine never applied need reductions to usage, so there is no grounded parity to claim.
**Rationale.** The two skills are the only output modifiers the retired Flutter engine both applied and oracle-pinned (unpenalized percent chain, level 5 = ×1.25); everything else stays in the disclosure, extending the base-values-first decision below rather than replacing it. Reset-at-switch matches the neighbouring resets (market, assets, fittings) and keeps the ordering invariant in one function.
**Revisit when.** A grounded modifier pipeline with oracle tests lands for module/rig/subsystem/ship output bonuses or need reductions; each newly applied class then leaves the disclosure wording in the same change. Revisit reset-vs-stamp when per-character stamping exists for another reason (offline caching per character), or when the same switch-boundary gap is closed for `wallet`, `dashboard`, or `character_detail` — then fix them by this same convention in one change.
**Refs.** `docs/fitting-skill-resources-design.md` sections 2-3 and 6; `src/fitting/resources.rs:133` (`fitting_resources_with_skills`); `src/ui/fittings.rs:1209` (`skill_line`); LEARNINGS 2026-11-16 skill-bundle entry; DECISIONS 2026-11-16 base-values-first entry below.

### Fitting numbers ship base-values-first, labelled in the view for exactly what they exclude (feat/rust-fitting-resources)

**Author.** Muse Code (fitting-resources workflow, integrator)
**Decision.** A fitting number may ship as soon as its base (unmodified) values are hand-verifiable from bundled data, provided the view itself labels it as base values and names every modifier class not applied. The first application is the CPU and power grid readout: base need sums against hull base output, under the heading "Fitting resources (base values)" and the disclosure at `src/ui/fittings.rs:1136`. The words "simulator" and "statistics" do not attach to base-only numbers in the view or the README.
**Rejected alternatives.** Waiting for the full modifier engine before showing any number: it delays a provable readout for an ungrounded one. Porting only the retired Flutter curated two-skill output table: still a partial total, with more inputs and the same disclosure duty.
**Rationale.** An unlabeled partial total that looks like an in-game total is the failure mode; a labeled base total is honest, testable against cache rows, and gives the next simulator slice a labelled baseline to extend rather than a silent behaviour change.
**Revisit when.** A grounded modifier pipeline with oracle tests for the outputs it changes lands; each newly applied modifier class then leaves the disclosure wording in the same change.
**Refs.** `docs/fitting-resources-design.md` sections 1 and 4; LEARNINGS 2026-11-16 missing-row entry.

### DNA link import takes its strictness from the AAR adapter, expressed through the per-segment report model (feat/rust-fittings-dna-import)

**Author.** Muse Code (fittings DNA-import workflow, integrator)
**Decision.** DNA strictness comes from the AAR adapter, expressed through the per-segment report model: every segment of a pasted DNA fitting link is accounted for as an imported item or a named issue with its segment position, numbers resolve only against the bundled catalogue (offline, no network, no EVE scope), and unresolvable segments are reported never displayed as numbers. Flutter's `generateDna` is not ported (dead and lossy in Flutter); copy-back stays EFT only.
**Rejected alternatives.** Base-parser tolerance (Flutter `parseDna` silently skips unknown items, defaults bad quantities, and fabricates ship names) — it loses user input without saying so, against the honesty model the EFT import already ships. Drone/cargo mapping for DNA segments — no grounded EVE DNA grammar represents drones or cargo in a fitting link, so mapping them would be guessing a slot; such segments are `UnsupportedDnaItem` issues instead.
**Rationale.** The strict AAR (after-action report) adapter was Flutter's own evidence that tolerant DNA parsing drops data; routing that strictness through the existing per-line report model (with `line` meaning segment position for DNA) gives one honesty contract for both import formats and lets display, EFT copy-back, and save-to-EVE work unchanged. Porting `generateDna` would add a lossy exporter no Flutter caller used.
**Revisit when.** A grounded EVE DNA grammar that represents drones or cargo is inspected, or a real caller needs DNA export and can ground its round-trip rules.
**Refs.** `docs/fittings-dna-import-design.md` (sections 9.3, 10 divergences D1–D12); `src/fitting/dna.rs`; `src/fitting/eft.rs` (`ImportFormat`); `src/names/fitting_types.rs` (`lookup_by_id`); `src/ui/fittings.rs` (`parse_import` call site).

### The fittings write scope is its own step-up group, never folded into the read group (feat/rust-fittings-write)

**Author.** Muse Code (fittings-write workflow, integrator)
**Decision.** Saving or deleting a character fitting requires `esi-fittings.write_fittings.v1` from a new `FITTINGS_WRITE_SCOPES` group in `src/config.rs`, granted only through the step-up flow and checked from stored token metadata before any write request is sent. The read group `FITTINGS_SCOPES` and first sign-in (`FIRST_AUTH_SCOPES`) are unchanged, so holding read permission says nothing about write permission.
**Rejected alternatives.** Folding the write scope into the existing read group: every character that re-ran the read step-up would silently gain write permission, and "has the fittings group" would stop being evidence about which permission was actually granted. Adding the write scope to first sign-in was never in contention; it breaks least-privilege first auth for a feature most sign-ins never use.
**Rationale.** Each step-up group in this app names exactly one permission (the player-structure name lookup set the precedent), which keeps the token-metadata pre-check, the re-authorize offer, and the audit question "could this token write?" answerable from one constant. Writes are also the first irreversible actions in the app, so their permission gets its own explicit grant moment in the browser.
**Revisit when.** EVE merges the read and write fittings scopes, a second fittings-write feature needs a different scope, or live use shows the extra step-up round trip is the dominant friction and a combined ask at write time (still never at first sign-in) is demonstrably clearer.
**Refs.** `docs/fittings-write-design.md` sections 3 and 15; `src/config.rs` (`FITTINGS_WRITE_SCOPES`); `src/app/shell.rs` (`fittings_write_stepup_observed`, `start_fitting_write`); LEARNINGS 2026-11-16 first-writes entry.

## 2026-11-15

### EVE access tokens are signature-verified with jsonwebtoken (rust_crypto) before any claims are trusted (feat/jwt-signature-verification)

**Author.** Mimir JWT verification workflow (designer, two builders, integrator)
**Decision.** Every EVE access token is verified before its claims drive any local decision: at first sign-in, at step-up sign-in, and on token refresh. Verification uses one new runtime dependency, `jsonwebtoken` version 12 with the `rust_crypto` backend only (RSA and P-256 through the RustCrypto crates, no OpenSSL-linked dependency, matching the existing reqwest rustls choice). The signing algorithm is pinned by the selected JWKS (JSON Web Key Set, EVE's published signing keys) key's type, never by the token header; issuer must be an accepted spelling of `login.eveonline.com`; audience must contain both the client id and `EVE Online`, checked in our own code because the library checks only one audience value; an unknown `kid` (key id) triggers exactly one JWKS refetch. Any failure rejects the token and saves nothing. An expired JWKS cache whose refetch fails also rejects rather than using stale keys. Test keys are generated in code inside `#[cfg(test)]` using dev-only `rsa` and `p256`, both already transitive through the chosen backend; no key material is committed.
**Rejected alternatives.** Hand-rolled JWS (JSON Web Signature) verification over direct `rsa` plus `p256` runtime dependencies (two dependencies and hand-written signature parsing for no gain); the `biscuit` crate and JWKS-helper crates (extra surface, weaker fit); the `aws_lc_rs` backend (a BoringSSL fork, outside the rustls/ring/RustCrypto constraint in spirit and review surface); trusting refreshed tokens without verification as lower risk (refresh persists rotated tokens, so the saves-nothing-on-failure guarantee would be false on the most common path); runtime SSO (single sign-on) metadata discovery (the JWKS address is a config constant instead, with the metadata address recorded beside it).
**Rationale.** Before this slice the character id, granted scopes, and expiry all came from an unverified token payload, so a forged token response could make Mimir save tokens under an arbitrary character. One audited verification library with a pure-RustCrypto backend closes that at every token-receipt point while keeping the dependency and no-OpenSSL constraints provable with `cargo tree`.
**Revisit when.** CCP starts issuing ES256 (ECDSA P-256) tokens live, the first live-account sign-in and refresh matrix has run, `jsonwebtoken` changes its validation or clock behaviour in a new major, or runtime metadata discovery becomes necessary because EVE moves its JWKS address.
**Refs.** `docs/jwt-verification-design.md` (decisions J1 to J7); `src/auth/jwt_verify.rs`; `src/app/shell.rs` and `src/esi/client.rs` (verify-before-save sites); LEARNINGS jsonwebtoken system-clock entry; `docs/rust-rewrite-design.md` named-gap line now marked done.

### Step-up sign-in asks for granted ∪ requested scopes and validates the character before saving anything (feat/stepup-oauth)

**Author.** Mimir step-up workflow (designer, two builders, integrator)
**Decision.** Granting a post-first-sign-in scope (today only `esi-assets.read_assets.v1` from the Assets view) re-runs EVE SSO (EVE's single sign-on login service) asking for the union of already-granted and requested scopes. After the code exchange, the returned claims must name the character the flow was started for and must actually contain the requested scope; either check failing aborts before `TokenStore::save` or `set_token_meta`, leaving the old tokens untouched. First sign-in (`FIRST_AUTH_SCOPES`, `start_login`) is not widened or refactored, and a `token_meta` pre-check skips the browser entirely when the scope is already granted.
**Rejected alternatives.** Asking only for the new scope (would mint a replacement token stripped of skills/wallet scopes); widening first authorization (breaks the least-privilege decision in `docs/rust-rewrite-design.md`); reusing `BackendMsg::LoggedIn` for step-up completion (would steal the active character if the user switched mid-flow); saving first and validating after (a browser approved as a different character would overwrite the clicked character's working tokens).
**Rationale.** An EVE token carries exactly the scopes requested at authorize time, and the person approving in the browser can be any EVE account. Union preserves the existing grant; validate-before-save makes every failure mode leave the previous working state intact.
**Revisit when.** A third scoped flow appears (then extract the duplicated callback/exchange tail shared by `start_login` and `start_stepup_login`), JWT signature verification lands, or CCP changes scope-grant semantics.
**Refs.** `docs/stepup-oauth-design.md` (decisions S1–S10); `src/auth/oauth.rs` (`union_scopes`, `validate_expected_character`); `src/app/shell.rs` (`start_stepup_login`); LEARNINGS 2026-11-15 request_refresh entry.

### Flutter app replaced by a single-window Rust/egui app (rust-rewrite)

**Author.** Mimir conversion workflow (design + four builders + integrator)
**Decision.** Mimir ships as one Rust binary: eframe/egui single window with a character rail and five views (Dashboard, Characters, Skills, Wallet, Settings), tokio + reqwest (rustls) for EVE SSO (EVE's single sign-on login service) PKCE (Proof Key for Code Exchange) and ESI (EVE Swagger Interface, CCP's API), rusqlite (bundled SQLite) for the cache, OS keyring with a 0600-file fallback for tokens, and a bundled `--demo` mode. All Dart/Flutter sources, platform runners, and pubspec files are deleted on this branch; git history keeps them recoverable.
**Rejected alternatives.** Keeping Flutter (the conversion goal itself); iced (more boilerplate per view); Slint/Dioxus/Tauri (markup, JavaScript, or WebView surface); raw winit+wgpu (weeks of work); JSON files instead of SQLite (every wallet aggregate becomes bespoke scanning code); replicating Flutter's tray host and 16 desktop windows in the first increment (highest-risk chrome; content parity first).
**Rationale.** egui renders identically on Linux and macOS with no retained widget tree, SQLite already proved itself under Drift in the Flutter app, and the localhost PKCE path ports exactly. Tokens never enter SQLite: a `token_meta` table holds scopes and expiry only.
**Revisit when.** A deferred feature (tray/multi-window, corporation window, market/fitting) becomes the priority, the first macOS run shows an egui/keyring problem this Linux host cannot see, or egui's immediate-mode tables stop scaling to wallet history sizes.
**Refs.** `docs/rust-rewrite-design.md` (decisions table, parity map, deletion list); `src/main.rs`; `src/app/shell.rs`; commits on branch `rust-rewrite`.

## 2026-09-16

### Presentation Views Strictly Evaluate Pure Domain Models Rather Than Mock Lookups

**Author.** Antigravity / Lead Orchestrator
**Decision.** Mandate that all Corporation presentation views (`CorporationAssetsView`, `CorporationWalletsView`, `CorporationStructuresView`, `OverviewRosterView`) compute their displayed totals, valuations, and fuel warnings dynamically from domain calculators (`CorporationAssetValuation`, `CorporationAssetGraph`, `CorporationWalletCalculator`, `CorporationFuelCalculator`).
**Rejected alternatives.** Presentation-layer heuristic shortcuts or static mapping dictionaries tied to test oracle values.
**Rationale.** Ties presentation fidelity directly to pure domain models, ensuring that arbitrary live ESI data renders with exact precision and proper hierarchy, while preventing false-positive test passes on static lookup tables.
**Revisit when.** Presentation requirements necessitate complex server-side pre-aggregated rollups.
**Refs.** [Release Evidence](../verification/corporation-module/RELEASE_EVIDENCE.md), [LEARNINGS 2026-09-16](LEARNINGS.md#dynamic-domain-derivation-in-presentation-layers).

## 2026-09-15

### Corporation authority is durable, fenced and separate from request eligibility

**Author.** Technical Architect.
**Decision.** Adopt the [Corporation technical design](../specs/corporation-module-design.md).
AppDatabase 22 stores character incarnations, actual grant revisions, endpoint
capabilities, complete snapshots and logical refresh/alert claims. Separate first
request eligibility from read permits; ordinary refreshable token expiry does not
shorten an unexpired offline access lease. Fence publication and deletion across
independent engines. Preserve exact raw decimal values and keep reported expiry,
observed fuel and manual/model estimates separate. Window 15 consumes guarded
Riverpod 3 view models through the actual SubWindowApp.
**Rejected alternatives.** Corporation-only caches, per-provider request locks,
page-only refresh ownership, float-based wallet/asset totals, inferred service
module identities, retained previous-owner UI and treating notification claims as
guaranteed OS delivery.
**Rationale.** Request permission, data visibility, source freshness and lifecycle
ownership are distinct facts. A durable claim can prevent duplicate native
handoffs but cannot transact with OS delivery; ambiguous crash claims are not
automatically replayed. In-app episodes remain available without native opt-in.
**Revisit when.** ESI/SSO contracts change, a reviewed fuel manifest expands model
support, or a notification API supplies stronger delivery semantics. Architecture
completion does not waive C0–C10 implementation and runtime gates.
**Refs.** [Implementation queue](QUEUED.md#corporation-module),
[source findings](LEARNINGS.md#corporation-shared-seams-need-explicit-production-contracts),
[checkpoint](../../.codex/checkpoints/2026-09-15-corporation-module-design.md).

### Corporation data follows character capabilities and bounded offline authority

**Author.** Product.
**Decision.** Adopt the [Corporation Product specification](../specs/corporation-module.md).
Use tray window 15 with four adaptive views. Gate each private endpoint by the
selected character's actual scopes, applicable roles and server authorization;
private offline access expires within one hour and known denial takes precedence.
Scope private payloads/names/derivatives by owner and grant generation. Ordinary
token refresh preserves generation; same-owner reauthorization can rebind retained
unaffected history only after fresh authorization. Fuel quantities, reported expiry
and dated modeled stock endurance remain distinct. Wallet accounting uses exact
decimal values and explicit history coverage.
**Rejected alternatives.** One Director toggle for all panels, automatic alt-token
fallback, indefinite private-cache visibility, service-name guesses for fuel burn,
and journal/trade totals used as a current wallet balance.
**Rationale.** The endpoint permissions differ from in-game role descriptions,
and independent cached observations cannot justify precise current-state claims.
**Revisit when.** CCP changes the pinned contract or a separate shared-corporation
authorization/management feature is approved.
**Refs.** [Queued implementation](QUEUED.md#corporation-module);
[verified contract findings](LEARNINGS.md#corporation-esi-contracts-require-role-and-source-specific-adapters).

### Exploration uses versioned data, scoped transactions and tuple routing

**Author.** Technical Architect.
**Decision.** Adopt the [Exploration technical design](../specs/exploration-module-design.md):
SDE7 validated exploration slice and AppDatabase21 scoped tables; millisecond
timestamps; a fenced SQLite request lease shared with Intel; explicit notebook
episodes, revision-checked imports and durable operation receipts; exact tuple-cost
Dijkstra over directed gates and eligible wormholes. Add window ID14 and adaptive
module navigation without a global shell migration. Keep reference readiness,
public observations and derived route eligibility separate.
**Rejected alternatives.** Provider-local refresh locks across independent engines;
partial feed acceptance; default-second timestamps for millisecond boundaries;
signature-code ownership across retired episodes; first-visit BFS or scalar
highsec penalties; persisting calculated routes as current.
**Rationale.** Provenance, time, scope and request ordering are independent dimensions.
SQLite is the durable authority; events only prompt rereads. Formula-free views
consume qualified snapshots, and stale Current origins require explicit action.
**Revisit when.** Upstream contracts add authoritative observations, a different
window/database transport is adopted, or separately approved mapper integration
changes ownership. Any change preserves Product acceptance behavior or revises it
explicitly first.
**Refs.** [Product](../specs/exploration-module.md),
[queued implementation](QUEUED.md#exploration-module),
[checkpoint](../../.codex/checkpoints/2026-09-15-exploration-module-design.md).
Shipped 2026-09-15 across Units X0–X10 with 1,258 passing tests and full tester sign-off (see ARCHIVE.md).

### Exploration uses a dedicated window and explicit observation freshness

**Author.** Product.
**Decision.** Adopt the [Exploration specification](../specs/exploration-module.md).
The user selected a tray-launched window with separate adaptive module navigation
and character selection. Deliver reference, public highways, local signatures and
routing in phases 4a–4d. Keep static facts, public observations and private verified
links distinct; derive route eligibility from source, age and status. Public mass
state remains Unknown when absent. Notebook import uses an atomic scoped preview;
only explicitly verified destinations create local route edges.
**Rejected alternatives.** Migrating the whole app to the old blueprint's global
shell; treating K162 as a fixed-capacity type; inventing public mass states; making
scanner names or system statics into live route edges; sharing private scan data.
**Rationale.** The current runtime uses independent window engines, and exploration
decisions depend on both data provenance and time. A route is a result over eligible
known edges, not proof of traversal or safety.
**Revisit when.** A separate app-wide navigation initiative is approved, or a verified
upstream contract adds authoritative mass observations or mapper synchronization.
**Refs.** [Queued implementation](QUEUED.md#exploration-module);
[source findings](LEARNINGS.md#exploration-reference-and-feed-contracts-differ-from-the-old-blueprint).

### Implementation and delivery of fit comparison visuals (Units W0–W7)

**Author.** Antigravity / Lead Orchestrator
**Decision.** Complete and verify the implementation of all seven units W0–W7 for the fit comparison visuals feature:
- Unit W0: snapshot and proposal contracts, content and calculation fingerprints (`AarFitFingerprint`), immutable deep copying, F1–F5 fixtures.
- Unit W1: owned storage on `CombatEnrichment.fitComparison` with field-scoped CAS, `CurrentShipFitReader` with strict pagination, `AarFitComparisonService`, and evidence isolation (`evidencePacketPresent` prevents score corruption).
- Unit W2: `CombatAarReport.fitComparisonAtGeneration` + `fitCandidates`, `PreparedAarComparisonInput` frozen before AI await, local structural candidate validation.
- Unit W3: `FitInventoryDiff` and `FitBillOfMaterials`, §5.2 matching algorithm, cross-group netting, physical counts, unquantified advice list, H/H2 oracles.
- Unit W4: `CombatFitDeriver.deriveFitting` neutral computation without fake evidence, `DogmaEngine.calculateDetailedStats`, common `AarComparisonContext`, `AarComparisonFrame` with late-result rejection, F3/F4 oracles at domain precision.
- Unit W5: `MarketRepository` batch methods, `AarPriceEstimate` (averagePrice only, stale quotes >= 24h), `IskEstimateAmount`, `AarCachedAssetMatch` loose hangar stock matching with baseline exclusion, price-only refresh without asset sync.
- Unit W6: `AarFitComparisonWorkspace`, `AarFitComparisonCard`, `AarFitComparisonTable`, `AarFitBomView`, `AarProposalDialog` wired to `AnalysisMultiPaneScreen` pre-analysis and post-analysis; `LayoutBuilder` on usable content width; zero horizontal overflow at 320px/200%; non-color badges; formula-free UI; exact §8.4 snackbar copy.
- Unit W7: Full verification across 1,070 passing (+14 skipped; 1 pre-existing Skills golden failure, also failing on develop), static analysis clean, formatting clean.
**Rejected alternatives.** In-line widget stat calculations; storing comparison data in the pilot evidence ledger; mutating evidence on comparison views; skipping pagination validation during capture.
**Rationale.** Strict separation of evidence from comparison, domain-level neutral calculations, and immutable input freezes ensure historical truth, multi-character safety, and resilient desktop and mobile UI rendering.
**Refs.** LEARNINGS 2026-09-15; ARCHIVE 2026-09-15; docs/specs/aar-fit-comparison-visuals.md; docs/specs/aar-fit-comparison-visuals-design.md; .agents/plans/2026-09-15-aar-fit-comparison-visuals.md.


### Fit comparison architecture separates source storage, evidence projection and computation

**Author.** Technical Architect.
**Decision.** Adopt the [technical design](../specs/aar-fit-comparison-visuals-design.md):
owned comparison JSON slots with field-scoped CAS; explicit evidence projection for
comparison-only rows; immutable report input records and locally validated optional
candidates; neutral Dogma computation qualified by source knowledge; pure multiset
diffs and physical BOMs with separate cached-price/asset annotations. Wire stable
commit publication and local cross-window observation; profile selection stays read-only.
**Rejected alternatives.** Reusing pilot evidence for current/reference snapshots;
deriving source completeness from empty Freezed lists or default stats; attributing
proposal calculations as evidence; treating service-local locks as cross-window
storage protection; using different asset IDs alone as proof of disjoint spare stock.
**Rationale.** Source history, deterministic values and availability claims have
different authorities. Preserve report v3/input v4 without a Drift migration while
preventing comparison-only writes from changing evidence or scoring.
**Revisit when.** Historical numerical replay, authoritative inventory provenance,
new parser syntax or independent durable comparison history becomes required.
**Refs.** [Product contract](../specs/aar-fit-comparison-visuals.md);
[queued initiative](QUEUED.md#fit-comparison-visuals-for-aar-reports).
Architecture delivery only; W0–W7 and runtime verification remain pending.

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
