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

## 2026-11-19

### Capacitor recharge bonuses scale a duration, and the power relay forces per-attribute classification — neither follows from the hit point leg

**Author.** Muse Code (fitted-module capacitor bonuses workflow, integrator)
**Context.** The capacitor-bonuses slice (`docs/cap-bonuses-design.md`) adds one bonused Capacitor block: the base block's use/peak/verdict recomputed with fitted modules' and rigs' bonuses to capacitor capacity (dogma 482) and capacitor recharge (dogma 55, shipped as `capacitor_recharge_rate` in milliseconds), following the #615 resistance / #617 hit point emission and computation precedents. Two plausibly-copied assumptions from those legs are false for this attribute pair, and only the inspected bodies and census show it.
**Evidence.** Design section 2 verifies attribute 55 is a duration in milliseconds, lower is faster: base stats divide it by 1000, peak is `2.5 × C / T`, and the simulator sets `tau = rechargeMs / 5.0`. Negative percents (Capacitor Control Circuit −15.0/−20.0) and sub-1.0 multipliers (Cap Recharger II 0.8) are therefore the improvement direction and are never absolutized, negated, or inverted — attribute 144's "Inversed Modifier Percent" unit name notwithstanding, the inspected Flutter ship route multiplies the millisecond value plainly. Oracles pin the sign: Rifter + Cap Recharger II gives recharge `Some(100000.0)` ms and peak 6.25 GJ/s; a −15 percent rig gives 106250 ms (negating it would give 143750 ms and fail). No stacking penalty applies to either attribute, re-verified per design section 2 (Flutter penalizes only the twelve resonances; two rigs compose `× 0.85 × 0.85` clean), and `bonused_capacitor` (`src/fitting/ship_resistances.rs:620`, order at `:212`) composes `(base + adds) × mul × percent` per attribute with `resistance_stacking_penalty`/`percent_chain` never called. The per-attribute split is forced by one census family: the 20 Capacitor Power Relay types are applicable on 55 with the 482 operand absent, so the #615/#617 per-type unapplied predicate on a single combined family would see the relay's recharge entry and silently drop its ungroundable capacity penalty. The generator therefore emits two independent families (`scripts/sde/generate_fitting_types_sde.py:290`, oracles at `:744`): capacity 182 keyed rows / 155 entries / 27 marked-empty, recharge 103 / 103 / 0; relay 1445 emits capacity empty+flag beside recharge `[[55, 4, 0.8]]` and is spot-pinned in the loader (`src/names/fitting_types.rs:140`). The bonused stability function (`src/fitting/ship_cap_stability.rs:548`, shared drain pass at `:369`) keeps module use base because it reuses the same `collect_drains` code as the base function, and feeds the bonused pair through `capacitor_peak_recharge` (`src/fitting/ship_peak_recharge.rs:82`) and the unchanged simulator with the base path's ms/1000 then ×1000 association so empty==base stays bit-exact. Catalogue: regenerated `assets/sde/fitting_types.json` at 3,874,268 bytes (+13,326 within the +20,000 budget), sha256 `11accfe2b941d2c86e7138d996347d63fb92c868a1644ff78c5828c0c0142c24`; integrator re-run twice byte-identical, and stripping the four new keys is byte-identical to the previous `c03d38f8…` catalogue. Commits `f20e8e1` (design), `1de002f` + `18e41fd` + `3070168` (Builder A), `59ec923` (Builder B).
**Mechanism.** Operator semantics ride on the modified attribute's meaning, not on the operator code: the same percent that grows capacity shrinks a recharge duration, so "bonus" direction must be read from what the attribute is (a duration the peak and simulator divide by), never from the word "recharge" or the operand's unit name. Likewise, absence is a property of one (type, attribute) pair: a type can be fully grounded on one attribute and ungroundable on a second, so any per-type predicate or summed count states a deficit no single dimension owns — the relay would have been counted as fully applied while its capacity penalty vanished. Only the catalogue-absent excluded count (no row at all, so no dimension can speak) is honestly shareable, and the four counts in the bonused block (drain-excluded, bonus-excluded, capacity-unapplied, recharge-unapplied) are disclosed separately, never summed.
**Generalizable rule.** When a new attribute pair reuses a shipped modifier pipeline, re-derive from the source body what each modified attribute is (amount vs. duration vs. resonance) before reading any operand's sign, and classify, emit, and count per attribute whenever one type can be grounded on one attribute and absent on another — a per-type collapse silently drops exactly the penalty that rides beside a grounded bonus.
**Refs.** `docs/cap-bonuses-design.md` sections 1–5, 7–10; `scripts/sde/generate_fitting_types_sde.py:290`, `:744`; `src/names/fitting_types.rs:140`; `src/fitting/ship_resistances.rs:212`, `:592`, `:620`; `src/fitting/ship_peak_recharge.rs:82`; `src/fitting/ship_cap_stability.rs:100`, `:369`, `:548`; `src/ui/fittings.rs:3207`, `:3217`, `:3279`, `:3323`; DECISIONS 2026-11-19 bonused-capacitor-stability entry below.

## 2026-11-19

### Hit point percent bonuses do not stacking-penalize — the plausible guess from resistances is wrong for hit points

**Author.** Muse Code (fitted-module hit point bonuses workflow, integrator)
**Context.** The hit-point-bonuses slice (`docs/hp-bonuses-design.md`) makes the bonused effective-hit-points block divide bonused hit points by bonused resonances: fitted shield extenders, armor plates, and kin now move the numerator, superseding #616's locked base-numerator policy. The natural implementation guess — chain hit point percent bonuses through the same stacking penalty the resistance leg applies — is false, and only the inspected reference body shows it.
**Evidence.** Design section 2 verifies from the retired Flutter engine (`dogma_engine.dart` at `ed698d3`): `_percentChain` applies `getStackingPenalty` only when the attribute is in `_nonStackableAttributes`, which is exactly the twelve resonances; hit point attributes 263 (`shieldCapacity`), 265 (`armorHP`), and 9 (`hp`) are not in that set, so every hit point percent factor uses penalty `1.0`. The shipped helper `bonused_hit_points` (`src/fitting/ship_resistances.rs:463`) composes `(base + adds) * mul * percent` at `:559` with `resistance_stacking_penalty` never called on this path, and Oracle 6 pins it (two Trimark rigs give `1.15 × 1.15 = 1.3225`, armor EHP 979.6296296; two extenders sum flat adds). The catalogue leg mirrors #615's honesty machinery on a second dimension: the generator emits `hitPointModifiers`/`hitPointModifiersUnapplied` on category-7 rows only (`scripts/sde/generate_fitting_types_sde.py:269`, oracles at `:678`, classification at `:1706`), 675 keyed rows / 643 entries / 32 marked-empty, regenerated `assets/sde/fitting_types.json` at 3,860,942 bytes (sha256 `c03d38f884900fc6659b45871e44f8ede7c01cf9e10e4de8e630271032158273`; integrator re-run byte-identical, and stripping the two new keys is semantically identical to develop's `a2577b6a…` catalogue). Counts stay per-dimension: `BonusedShipEhp.hit_point_unapplied_modules` (`src/fitting/ship_ehp.rs:94`, produced at `:281`) is disclosed beside, never summed with, the resistance-dimension count, and the excluded count is shared from `bonused_resonances` (`:279`). Two smaller findings rode along (Builder A notes): an `i64::MAX`-quantity Nanofiber mul run stalls at the smallest subnormal (~5e-321) rather than exactly `0.0`, so the hostile pin asserts a negligible-but-bounded prompt return; and an all-zero carrier that also carries a resistance entry must pin identity through the helper's `hit_points` equality, not whole-EHP equality. Integrator gates re-run fresh: `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test` (1140 + 12 + 13 + 5), `cargo build` all pass. Commits `0255286` (design), `7b903c2` + `d703a13` (Builder A), `53fa22d` (Builder B).
**Mechanism.** Stacking penalty in EVE dogma is a property of the *modified attribute*, not of the percent operator: the same operator-6 modifier penalizes on a resonance and chains clean on hit points. Porting the resistance leg's chain wholesale would have understated every multi-rig fit's armored EHP while looking exactly like the code beside it. The per-dimension counts follow the same shape: a module can be describable in one dimension and indescribable in the other, so a summed "unapplied" number would state a deficit no single dimension owns; only the excluded count (no catalogue row at all, so neither dimension can speak) is honestly shareable.
**Generalizable rule.** When a second attribute family reuses a shipped modifier pipeline, re-derive every operator semantic per modified attribute from the source body — stacking, ordering, and count dimensions ride on the target attribute, not on the operator or the neighbouring code — and keep unapplied counts per dimension, sharing only the count whose definition is dimension-free.
**Refs.** `docs/hp-bonuses-design.md` sections 2, 3, 4, 7, 8, 10; `scripts/sde/generate_fitting_types_sde.py:269`; `src/names/fitting_types.rs:122`, `:411`; `src/fitting/ship_resistances.rs:453`, `:463`; `src/fitting/ship_ehp.rs:94`, `:227`; `src/ui/fittings.rs:1950`, `:1958`, `:2040`, `:2054`, `:2563`; DECISIONS 2026-11-19 bonused-EHP-numerator entry below.

## 2026-11-19

### Divide in the space the catalogue stores — a shared resonance helper keeps bonused EHP exact where a percent round-trip would drift

**Author.** Muse Code (bonused effective hit points workflow, integrator)
**Context.** The bonused-EHP slice (`docs/bonused-ehp-design.md`) adds an omni effective-hit-points block whose denominator is the fitted-module bonused resonances shipped by #615, while the numerator stays the bare hull's base hit points. The #615 public API exposes only resistance percents, so EHP could have recovered each resonance by inverting the displayed percent.
**Evidence.** Design section 3 rejects that inverse with executed arithmetic: resonance `0.67` converts to percent `33.0` and back to `0.6700000000000002`. Builder A (`44b59c0`) instead factors the resonance-level computation into `pub(crate) BonusedResonances` / `bonused_resonances` (`src/fitting/ship_resistances.rs:270`, `:281`; product `base * mul_total * chain` at `:370`, usability filter at `:371`) and rebuilds `ship_resistances_with_module_bonuses` on it (`src/fitting/ship_resistances.rs:384`) with all 26 pre-existing resistance tests passing unmodified. The new pure function `ship_ehp_with_module_bonuses` (`src/fitting/ship_ehp.rs:217`) feeds helper positions 0-3/4-7/8-11 through the existing private `layer_ehp` (`src/fitting/ship_ehp.rs:116`) with the hull's base hit points, carries the helper's `excluded_modules`/`unapplied_modules` verbatim (`src/fitting/ship_ehp.rs:277`), and pins the hand-derived Oracle 1a values 709.3596059 / 784.3137255 / 870.6467662 / total 2364.3200976 plus an exact empty-fitting `assert_eq` against base EHP (design section 8). Builder B (`9255f1f`) renders it via `render_ship_ehp_with_module_bonuses` (`src/ui/fittings.rs:2531`) immediately after base EHP on both detail surfaces, reusing `ship_base_ehp_lines` and the bonused-resistances count helpers verbatim, under the heading at `src/ui/fittings.rs:1947` and disclosure at `:1956` whose first sentence names the bare-hull base-hit-point numerator; the #615 disclosure (`src/ui/fittings.rs:1914`) was revised in the same commit because its "effective hit points below still use only the base values" clause became false. Integrator gates re-run fresh: `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test` (1127 unit + 12 demo_seed + 13 esi_models + 5 storage), and `cargo build` all pass. Design commit `9827586`; no catalogue, generator, or `fitting_types.rs` file appears in the slice diff (design section 5).
**Mechanism.** Percents are a display projection of resonances; inverting them reintroduces the round-trip base EHP already rejected and destroys the strongest available regression pin — with no counted modifiers the shared path computes `base * 1.0 * 1.0`, which is bit-identical in IEEE arithmetic, so a hull-only fit's bonused EHP can be asserted *equal* to base EHP rather than merely close. One shared helper also makes the two bonused blocks' excluded/unapplied counts identical by construction, so no deficit can be disclosed in one block and silently dropped in the other. The numerator staying base is a wording obligation, not an arithmetic one: the block must name base hit points and name hit-point-adding modules as not applied, or a denominator-only bonus reads as a fitted total.
**Generalizable rule.** Compute derived figures from the stored quantity through one shared intermediate — never invert a display projection — so identity cases stay bit-exact and every consumer discloses the same counted deficits.
**Refs.** `docs/bonused-ehp-design.md` sections 2, 3, 4, 7, 8, 10; `src/fitting/ship_resistances.rs:270`, `:281`, `:384`; `src/fitting/ship_ehp.rs:77`, `:89`, `:116`, `:217`; `src/ui/fittings.rs:1914`, `:1947`, `:1956`, `:2531`; commits `9827586` (design), `44b59c0` (Builder A), `9255f1f` (Builder B); DECISIONS 2026-11-19 bonused-EHP entry below.

## 2026-11-19

### Present-zero is proven zero; all-absent on a known carrier is missing data — and only generation time can tell them apart

**Author.** Muse Code (module resistance bonuses workflow, integrator)
**Context.** The resistance-bonuses slice (`docs/resistance-bonuses-design.md` sections 2–3) applies fitted-module resistance modifiers from the bundled catalogue. Each carrier's modifying operand (the module type's own dogma attribute value in `dgmTypeAttributes`) appears in the committed SDE in three states: present and non-zero, present and exactly `0.0`, or absent entirely.
**Evidence.** The generator classifies every `ItemModifier`/`shipID` resonance modifier on a category-7 type as applicable, unsupported, zero, or absent (`scripts/sde/generate_fitting_types_sde.py:245`, classification and emission from `:1425`; oracles `RESIST_MODIFIER_ORACLES` at `:604`). Design-scripted counts over the committed join: 1,835 zero operands and 189 absent operands across 799 carrier types. EM Armor Hardener II (11642) carries three explicit `0.0` operands beside its one applicable entry, and the eight Layered Coating / Layered Energized Membrane types (1272 and kin) are all-zero carriers that emit neither new key (oracle-pinned). The two Abyssal Damage Controls (52227/52230) have all twelve operands absent — their per-item mutated values exist in no SDE type row — and emit an empty `resistanceModifiers` array beside `resistanceModifiersUnapplied: true`. Fifty-five rig types mix applicable entries with absent slots (the SDE's normal "not this damage type", read exactly as Flutter's `base == null || base == 0` skip reads it) and are not marked. The loader keeps the three runtime states distinct (`src/names/fitting_types.rs:108`): `None` = non-carrier or provably zero, `Some` entries = applicable, unapplied flag = carrier whose bonus the data cannot ground; invariants pin 791 keyed rows, 777 non-empty, 14 marked, 1,332 entries. At runtime `ship_resistances_with_module_bonuses` (`src/fitting/ship_resistances.rs:271`) counts marked rows in `unapplied_modules` and rows with no catalogue row in `excluded_modules`, never as zero bonus.
**Mechanism.** Present `0.0` is data: the SDE asserts the operand is zero, so "no bonus" is proven. All-absent on a type that provably carries the modifier shape is the opposite: the bonus exists but its value lives nowhere in the shipped files. After generation, both collapse to "no entry on this type" — no runtime signal can reconstruct which one it was, because the runtime deliberately never re-derives the operand (the catalogue bakes it in at generation; module rows do not even carry their modifying attributes). So the distinction must be decided while the join is still visible and carried as a generation-time mark, or the view silently counts a known carrier as zero bonus.
**Generalizable rule.** When source data distinguishes "present-zero" from "absent", never collapse both into "no entry" without checking whether absence on a known carrier means missing data: decide that distinction at extraction/generation time, where the join is still visible, and ship it as an explicit mark — at runtime the two are byte-identical and any later "detection" is invention.
**Refs.** `docs/resistance-bonuses-design.md` sections 2, 3, 4, 8; `scripts/sde/generate_fitting_types_sde.py:245`, `:604`, `:1425`; `src/names/fitting_types.rs:108`; `src/fitting/ship_resistances.rs:271`; commits `12a910b` (Builder A1), `ef8f4f2` (Builder A2), `17379b1` (Builder B); companion LEARNINGS and DECISIONS entries below.

## 2026-11-19

### An oracle's unsupported counter is a third honest state — counted, not applied

**Author.** Muse Code (module resistance bonuses workflow, integrator)
**Context.** Operator 7 modifiers target ship resonances in the committed SDE (32 `shipID` entries; on today's catalogue exactly the twelve Polarized weapon types, 34272–34294, twelve present operands each). No inspected body defines what operator 7 computes.
**Evidence.** In the retired Flutter engine (`dogma_engine.dart` at `ed698d3`, inspected during design), the `ItemModifier`/`shipID` route applies operators `{0, 2, 3, 4, 6}` and falls through to `unsupportedOperators++` for anything else — the oracle itself counts operator 7 rather than applying or ignoring it. The slice mirrors that third state end to end: the generator classes a present-operand operator outside `{0, 6}` as unsupported, emits no entry, and marks the type unapplied (`scripts/sde/generate_fitting_types_sde.py:245`, Polarized oracle pin at `:604`); the pure function counts marked fitted rows in `unapplied_modules` while still applying any grounded entries beside them (`src/fitting/ship_resistances.rs:308`); the view renders the locked count line ("has a resistance bonus Mimir's bundled item data cannot describe, so that bonus is not applied") rather than a number (`src/ui/fittings.rs:2403`). One design contradiction surfaced during implementation and was recorded in Builder A2's commit body (`ef8f4f2`): the design's quantity-8 equality pin for the hostile-quantity bound contradicts the penalty arithmetic (the penalty reaches exactly `0.0` only at n=74, so quantity 8 ≠ `i64::MAX`); Builder A pinned quantity-100 equality, following the arithmetic over the literal pin.
**Mechanism.** Inventing operator-7 math from EVE lore would state a number no inspected source grounds; silently dropping a fitted Polarized weapon would show resistances the fit's own data says are wrong. The oracle's counter proves a third state exists in the reference behavior itself — known, named, and deliberately not applied — and a port can carry that state to the user as a disclosed count instead of collapsing it into either a fabricated number or silence.
**Generalizable rule.** When a reference implementation counts an input as unsupported, parity means counted-not-applied: ship the count as a disclosed state, never invent the missing semantics and never silently omit a known effect — and when a locked test pin contradicts the arithmetic it pins, follow the arithmetic and record the contradiction in the commit body.
**Refs.** `docs/resistance-bonuses-design.md` sections 2, 3, 4, 6, 8; `scripts/sde/generate_fitting_types_sde.py:604`; `src/fitting/ship_resistances.rs:174` (penalty), `:271`, `:308`; `src/ui/fittings.rs:2403`; commits `12a910b`, `ef8f4f2`, `17379b1`; companion LEARNINGS entry above and DECISIONS entry below.

## 2026-11-19

### A bundled catalogue of IDs is only half a feature — bundle the name with no ESI path, schedule every name that has one, and join-check demo fixtures against the extract's namespace

**Author.** Muse Code (factory schematics workflow, integrator)
**Context.** The factory-schematics slice (`docs/pi-schematics-design.md`) resolves the already-carried `PlanetPin.schematic_id` against a new bundled extract (`assets/sde/planet_schematics.json`, all 68 schematics from the one `planetSchematics.jsonl` member of the pinned SDE build 3503375 archive) and renders each factory pin's recipe in a new Factories section of the colony detail, between Extractors and Stored items. Its locked ranking puts "never a fabricated recipe" first: every rendered name, quantity, and cycle time traces to the pinned archive member or to a name the resolver actually holds, and absence is a stated sentence, never a guess.
**Evidence.** The two names on a resolved row have different provenances, and the design's section 2.1 scripting shows why they must: the schematic's own name has no ESI name path (schematic IDs are never scheduled, design section 8), and it cannot be derived from its output type's resolved name because exactly 3 of 68 differ (89 "Ukomi Superconductor" vs type 17136 "Ukomi Superconductors", 94 and 108 the same singular/plural split) — so the 68 English schematic names are the extract's only bundled strings, shown verbatim (`factory_pin_rows`, `src/ui/planets.rs:219`), while every input/output/pin type name goes through `NameResolver::name`, the exact call stored items use, with the shell scheduling the *resolved schematics' type IDs* (never the schematic IDs) so those names can fill in instead of reading `Unknown Item` forever. The extract itself is pinned end to end: the generator (`scripts/sde/generate_planet_schematics_sde.py`, `2c25b6d`) reads exactly one archive member under fail-loud exact-count oracles and seven spot rows, and the generated file is 31,999 bytes (budget 40,000), sha256 `9d6ded19d42d733f742d8027ccc48826a55516006543a6fe43b90eba0f9aac5a` — the integrator re-ran the generator and got a byte-identical file with `git diff` clean. The loader (`PlanetSchematicsRef`, `src/names/planet_schematics.rs:60`) follows `IndustryRef` for startup degradation to `None` plus a fixed unavailable sentence (`src/ui/planets.rs:479`), but whole-file manifest validation with no per-row skipping: a partially loaded table would misreport present schematics as absent. Absent and unlisted are stated, never guessed: a schematic not in the extract shows the fixed not-in-bundled-data line and no name, quantity, or raw ID (`src/ui/planets.rs:481`), and a pin whose type is not in its schematic's pin list still shows the full recipe plus one fixed line saying so (`:483`) — never hidden or worded as an EVE verdict. The demo fixtures prove the namespace trap: the four shipped schematic pins carried `15462`/`17361`, written before any extract existed, with `{15462, 17361} ∩ {65…135} = ∅` (design section 2.3), so they became the demo's honest absent material and two additive pins with real schematic IDs (65 on pin type 2480, 121 on 2481, colony `700000001` only, `d2b2cac`) were required for the demo to show a resolved line at all. Two builder deviations are recorded in their commit bodies: the loader's manifest struct omits the unread `sdeBuild`/`sourceFiles`/`generatedBy` keys (carrying `sdeBuild` tripped `-D warnings` dead-code and the design forbids allow-papering; serde ignores the keys, so no build gate exists either way), and `tests/demo_seed.rs`'s pin-type count on colony `700000001` went 2 → 4 because the locked new pins add honest new pin types (2480/2481), with the eight shipped pins byte-identical.
**Mechanism.** An ID-only catalogue renders nothing honest by itself: each ID it carries needs a name source, and the sources differ per ID kind. Type IDs already have one — the scheduled resolver — so bundling type names would duplicate it and drift; schematic IDs have none, so their names must ride in the extract, and borrowing the output type's name as a stand-in would be wrong on exactly the 3 of 68 rows nobody spot-checks. Scheduling is the other half of the same join: an extract that only feeds the renderer but never the scheduler leaves every type name at `Unknown Item` permanently, so the resolved schematic's type IDs join the same per-pin scheduling stored items use, while the schematic ID itself stays unscheduled because no honest fill exists for it. Demo fixtures written before an extract exists silently live in a different ID namespace for the same reason — nothing ever joined them against the real key set — and a set-intersection check during design catches that in seconds, where a visual demo check would only ever show plausible-looking rows.
**Fix (or queued).** Generator, extract, loader, and loader tests 1–3 (`2c25b6d`); `factory_pin_rows`, the Factories block and its four locked constants, startup wiring (`planet_schematics_load`, `src/app/shell.rs:715`), scheduling of resolved schematic type IDs, demo fixtures, and tests 4–14 (`d2b2cac`). Nothing is fetched, written, or modelled: no per-hour yield, throughput, or factory completion arithmetic ships, because no inspected body grounds a rate rule (design section 12); per-cycle quantities and cycle time display as data. The colony summary gains no factory count, by the same section's deferral.
**Validation.** 1,122 tests pass at the integrator state (1,092 library plus 0/12/13/5/0 in the other test binaries, 0 failed; 1,107 at slice base plus this slice's 15 new tests — design section 10 cases 1–14 and the extended demo-seed pin), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator, and the generator re-run byte-identical (31,999 bytes, sha256 above, `git diff` clean). A fresh demo screenshot of the Planets view (`Xvfb` + `scrot -o` to a fresh `/tmp/mimir-planets-schematics.png`, removed first, `startup_view` set to `Planets` in `app_settings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows colony `700000001` (Jita — Temperate) selected with `Active Pins: 6`, the two new facility pin types in Pin types, and the Factories section fully resolved: Superconductors (40 × Plasmoids + 40 × Water → 5 × Superconductors, 3600 seconds) and Water (3000 × Aqueous Liquids → 20 × Water, 1800 seconds); the run log shows `[STARTUP] applying saved startup view Planets`, `[PI] planet schematics loaded schematics=68 type_entries=203`, and `[PI] factory pin rows=4 resolved=2 not_in_extract=2 unlisted_pin=0 skipped=0`. The two Demo Extractor absent rows sit below the screenshot's fold and no other colony was clicked in the captured run — the absent arm, the unlisted-pin arm, sort order, and the demo end-to-end count are covered by the headless pins in `src/ui/planets.rs` and `tests/demo_seed.rs`, not by the image. Nothing here is live-verified against EVE (the Planets path's standing not-live-verified note covers this section too, including whether live ESI sends any `factory_details` object, which this slice neither needs nor parses).
**Generalizable rule.** A bundled catalogue of IDs is only half a feature: for every ID kind it carries, name its name source — bundle the string when no resolution path exists (and never borrow a neighbouring entity's name, which differs on exactly the unspot-checked rows), schedule through the existing resolver when one does, and never schedule an ID kind no fill can answer — then join-check every pre-existing fixture's IDs against the extract's key set before building on them, because fixtures written before the extract live in a namespace only an intersection test can see.
**Refs.** `docs/pi-schematics-design.md` sections 1, 2.1, 2.3, 3–9, 12, 13; `src/names/planet_schematics.rs:60`; `src/ui/planets.rs:219`, `:479`, `:481`, `:483`; `src/app/shell.rs:715`, `:4524`; commits `50ce2f5` (design), `2c25b6d` (Builder A), `d2b2cac` (Builder B).

## 2026-11-19

### Charge fit is provable as a group join and not provable as a size rule — ship the proved half and name the unproved one in the standing note

**Author.** Muse Code (editing loaded charges workflow, integrator)
**Context.** The charge-editing slice (`docs/charge-editing-design.md`) lets a fitting draft's module rows set, change, and clear a loaded charge by exact catalogue name, closing the editor design's named deferral ("no charge-group compatibility in the catalogue seams used here"). Its locked ranking puts "never claim a check that does not run" first: exactly one compatibility fact is checked, and the wording names the second check it deliberately does not make.
**Evidence.** The group join is proved end to end from committed files (design section 2.3): dogma attributes 604, 605, 606, 609, 610 (`chargeGroup1`–`chargeGroup5`) in the pinned SDE zip, module values in `scripts/sde/dgmTypeAttributes.csv.bz2`, and each charge's own group as its `groupID` in `scripts/sde/invTypes.csv.bz2`. Builder A emits `chargeGroupIds` on exactly the 980 slot-proven category-7-or-32 rows carrying 1,489 values and `chargeGroupId` on all 1,005 category-8 rows (`785f58e`; regenerated `assets/sde/fitting_types.json` is 3,798,320 bytes, sha256 `98917a44d0bc004c41b3ce5df064f383fee06eadbfa6a37d35457ee6aa765800`, within the 3,815,000 budget, with twice-run determinism and strip-two-keys byte identity against the base sha256 `69967d0030457087e88b9b88ebe9bdc0292d44c4a60cf75c8b58f048145db772` in that commit's body — the integrator re-verified the current byte count, sha256, key counts (980/1,489/1,005), and the textual strip-two-keys proof independently). The loader adds `charge_group_ids`/`charge_group_id` as default fields with bundled invariants and oracle spot pins (`src/names/fitting_types.rs:338`, invariants from `:1256`, `88d353d`), deliberately under a charge-scoped key rather than the need slices' locked `groupId`, whose present/absent meaning feeds the resources unprovable-reduction count. The size half (attribute 128 `chargeSize`) is contradicted by the same data: present 0.0 module sizes on 32774, 41480, and 88717 would accept nothing under equality, capacitor-booster group 87 mixes sized and size-less charges for the same carriers, and no body in the repository (SDE, cache, Rust, or retired Flutter) states a reconciling rule — so nothing emits or consults a size, test 8 pins a wrong-size same-group charge (Radio M in a small laser) as accepted, and the editor note ends "the charge's size is not checked" (`src/ui/fittings.rs:1399`). Flutter held nothing to borrow: its `acceptedChargeGroups` was dead data assigned `[]` everywhere. One design sentence needed care rather than literalism: section 2.3's "all 147 `launcherFitted` rows" is true of cache datum presence, but only 143 launchers sit inside the 980-row emission scope — the other 4 are category-66 rows the locked scope deliberately excludes beside the 89 published category-23/66 carriers that gain no key (Builder A's flag, followed per the locked emission scope).
**Mechanism.** A compatibility rule is shippable only when the committed data states it without exception rows that need an invented scope to survive. The group join has that property (every emitted value resolves to a category-8 group, every accepted group holds at least one catalogue charge, loader invariants pin both); size equality does not, and scoping it by marker (turrets only) would make the check's presence itself indescribable in honest wording. So the slice's refusal surface delegates three wordings verbatim to the importer and adds exactly one new sentence for the one new condition ("Mimir's bundled data does not list this charge as one this module can be loaded with"), and any unprovable membership — absent keys on an old asset, no catalogue row for the draft row's type number — refuses rather than guesses.
**Fix (or queued).** Generator emission with oracles, expected counts, and fail-loud invariants (`785f58e`); loader fields and invariants (`88d353d`); pure `set_charge`/`clear_charge` with `ChargeRefusal` (`src/fitting/editor.rs:89`, `:563`, `:626`, `7d28bde`), including the exhaustive test that every one of the 980 carriers accepts its first listed catalogue charge. Not shipped, by design (section 12): the charge-size check, import-time compatibility, exporting charges in copied EFT, a charge picker, loaded counts, and charge effects on capacitor/repair figures.
**Validation.** 1,107 tests pass at the integrator state (1,077 library — 1,061 at design base plus Builder A's 1, Builder B1's 9, B2's 3, and B3's 3 — plus 0/12/13/5/0 in the other test binaries, 0 failed; 1,091 at base plus exactly this slice's 16 new tests, no base test modified beyond the fixture extensions and the two wording literals the design names), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. A fresh demo screenshot of the Fittings view (`Xvfb` + `scrot -o` to a fresh `/tmp/mimir-fittings-charge-editing.png`, removed first, `startup_view` set to `Fittings` in `app_settings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the top of the view in demo mode — the import heading and the "Start a new fitting" chooser with `Showing 100 of 404 ships.` — and the run log shows `[STARTUP] applying saved startup view Fittings`, `[FITTING] fitting types loaded types=25818 skipped=0`, and `[FITTING] ship candidates built rows=404`. The screenshot does not show any charge box, `Set charge`/`Clear charge` button, or refusal: those render only on an installed draft's item rows below the captured scroll position, and no draft was installed or charge typed in the captured run — the set/change/clear, refusal-ordering, exhaustive-980, and DPS-transition behavior is covered by the headless pins in `src/fitting/editor.rs`, `src/fitting/dps.rs`, and `src/ui/fittings.rs`, not by the image. Nothing here is live-verified against EVE (charge editing is local and in-memory, and charges are still excluded from the pre-existing, separately unverified save path).
**Generalizable rule.** When committed data proves half a rule and contradicts the other half, ship only the proved half, pin the unproved half's acceptance with a test so it cannot be silently "fixed" without a design, and say in the standing wording exactly which check does not run — an invented scope for the exception rows is a claim the data never made.
**Refs.** `docs/charge-editing-design.md` sections 1, 2.3, 3, 4, 8, 11 (tests 1–10), 12, 13; `src/names/fitting_types.rs:338`; `src/fitting/editor.rs:89`, `:563`, `:626`; commits `7b5ad77` (design), `785f58e`/`88d353d` (Builder A), `7d28bde` (B1); companion LEARNINGS entry below.

## 2026-11-19

### The DPS pairing surface is a property of the draft's current rows, and the editor checks fit precisely because import only transcribes

**Author.** Muse Code (editing loaded charges workflow, integrator)
**Context.** Before this slice, turret/launcher DPS existed only on imported-EFT drafts, because only EFT text could record a module–charge pairing; created, copied, and DNA drafts could never show it. The panel half adds per-row charge controls (`e649480`), and the DPS half (`3015155`) had to decide what makes the turret/launcher families exist at all once any draft can record a charge.
**Evidence.** `fitting_dps` (`src/fitting/dps.rs:176`) now derives `has_pairing_surface` (`:199`) as imported-`Some` and (format `Eft` or any item carrying a charge); every use of the old format-only gate keeps its meaning against the new definition (family initialization, the not-on-surface unloaded branch, the volley/optimal/falloff finals at `:325`). Tests pin both directions: a created Rifter computes turrets `None` before any set, `Some(12.7512)` with volley `Some(47.817)` after setting Republic Fleet EMP S, and `None` again after clearing its only charge; the shipped demo-DNA pin (no charges, three unloaded) passes unmodified, and a non-weapon charge (a script on a Sensor Booster II) changes no DPS figure. The editor/import asymmetry is deliberate (design section 4.4): `set_charge` runs the importer's lookup and category proofs plus the one new group-membership proof, while EFT/DNA import still records pairings unchecked — an imported pairing on a module listing nothing stays shown, DPS-counted exactly as recorded (the replaced disclosure sentence at `src/ui/fittings.rs:2738`), and clearable, but once cleared it cannot be set back from the item row. Panel bookkeeping inherits wholesale: a successful set/clear routes through `note_successful_edit`, so the edited suffix appears and any armed save confirmation disarms — load-bearing because the confirmation re-renders its charges-not-sent count from the live draft — while a refused set touches nothing but the editor error (`src/ui/fittings.rs:1661`) and the typed per-row draft survives for correction (`fittings_editor_charge`, `src/app/state.rs:850`, cleared at the same sites as the quantity drafts). Copy and save still exclude every charge, editor-set ones included, with the recounted `charges_noted` keeping those disclosures truthful (round-trip test 10: re-import of copied text reports `charges_noted` 0).
**Mechanism.** The old gate keyed on format because format was a perfect proxy for "a pairing can exist"; the moment the editor can create pairings on any provenance, the proxy breaks and the gate must read the thing itself — the draft's current rows — or it becomes a sticky flag that survives clearing the last charge. The same reasoning splits transcription from construction: import's job is to record the author's text faithfully (changing its grammar would move issue and invariant accounting this slice does not own), while the editor's job is to help build a new pairing, where accepting one the bundled data contradicts would manufacture a DPS number EVE cannot hold. Because every consumer already derives per frame from `ImportedItem.charge` plus the recount, mutate-and-recount is the whole integration — no cached pairing can drift.
**Fix (or queued).** The pairing-surface gate and its doc updates with tests 11–14 (`3015155`); the row controls, intents, refusal template, extended editor note, replaced DPS disclosure, per-row draft state with its resets, and tests 15–18 (`e649480`). Only the three locked `[FITTING]` editor lines were added (set at `src/fitting/editor.rs:614`, cleared at `:648`, refused at `:113`); no render path logs. Deferred by design: import-time refusal of incompatible pairings and carrying charges into copied EFT text (design section 12).
**Validation.** The integrator's fresh gate (1,107 tests; see the companion entry above) includes the created/DNA/EFT DPS transition pins, the surface-from-rows clear pin, row-derivation pins (autocannon rows offer controls, listing-nothing rows none unless already charged, stacked rows none), all four full refusal literals with the three delegated ones asserted string-equal to the importer's reasons, and both demo pins passing unmodified. The demo screenshot was captured at the top of the Fittings view with no draft installed, so it shows neither the charge controls nor a charged draft's DPS; those paths are pinned headlessly, and the controls' rendering position (on each slot row, label → charge box → `Set charge` → `Clear charge` → `Remove`) follows the shipped row layout they were inserted into.
**Generalizable rule.** When a format or provenance flag was only ever a proxy for a property of the data, replace the proxy with the property read from the current data the moment a new path can create that property — and keep transcription surfaces faithful while construction surfaces proof-check, recording the asymmetry instead of "consistently" breaking one of them.
**Refs.** `docs/charge-editing-design.md` sections 4.4, 5, 6, 7, 8.4, 9, 10, 11 (tests 11–18), 13; `src/fitting/dps.rs:176`, `:199`; `src/ui/fittings.rs:1661`, `:2738`; `src/app/state.rs:850`; commits `3015155` (B2), `e649480` (B3); companion LEARNINGS entry above.

## 2026-11-19

### Changing a draft's ship assigns only the re-validated pair — the import report is history, so no recount, and a synthesized name cannot be told from a typed one, so no retitle

**Author.** Muse Code (changing a draft's ship workflow, integrator)
**Context.** The change-ship slice (`docs/change-ship-design.md`) closes a deferral named by three earlier designs: any existing in-memory draft — imported (`Eft`/`Dna`), created (`Created`), or copied (`Copied`) — can move onto another choosable ship while keeping everything else. The locked ranking puts "only the ship changes" first, "the fitting name never changes silently" second, and "fitment is disclosed, never enforced" third: items are never re-proven against the new hull, removed, or blocked, and overflow appears in the shipped over-capacity lines.
**Evidence.** The pure operation `change_ship` (`src/fitting/editor.rs:438`, outcomes `ShipChangeOutcome {Changed, SameShip, Refused}` at `:411`, commit `de140ad`) validates exactly as `new_fitting` does — `lookup_by_id`, category 6, `output_usable` on both outputs, trimmed catalogue name equal to the row name — before the same-ship check, so a forged row carrying the current type number under a wrong name is `Refused`, never blessed as a no-op. On `Changed` it assigns exactly two fields from the catalogue row (`ship_type_id`, `ship_name`, `:456-457`) and logs one debug line (`[FITTING] editor ship changed ship={} items={}`, `:459`). It deliberately does not call `recount_charges`, departing from the other four edit operations: they can change which rows carry a charge, a hull change cannot, so any effect of a recount here would silently rewrite a counter this operation has no business rewriting — the pair-only test pins `name`, `format`, every `ImportedItem` row for row (charges included), and the whole `ImportReport` field by field on a draft whose every report field is non-trivial. The exhaustive pin composes listing proof with change proof over all 404 candidates from an item-carrying draft (every row but its own yields `Changed`, its own yields `SameShip`), and fixture-catalogue rows (category 7, absent number, negative-output hull) each yield `Refused` with the draft field-for-field unchanged. The name never follows on any provenance: a `new_fitting` draft still titled `New Rifter Fit` changed to a Punisher still reads `New Rifter Fit`, an imported draft hand-renamed to that exact string also keeps it, and copy equivalence is pinned after a change (literal `[Punisher, {unchanged name}]` EFT header, DNA leading with the new type number, both re-importing to the same item count, empty created drafts included). No `ImportFormat` variant, no `eft.rs` derive, and no `mod.rs` re-export were added; the target set stays the shipped 404, so a draft on a non-candidate hull can always change away but never back to it (re-import or re-copy is the way back).
**Mechanism.** Detecting "this name is still the synthesized `New {ship} Fit`" would mean inferring provenance from a value (`format == Created && name == "New {old ship} Fit"`), and the shipped `rename` stores any trimmed text including that exact string — nothing records whether the current name was synthesized, typed, or typed back. The same inference was already rejected once when a created draft was not recognized by all-zero counters (a header-only import is all-zero too). The report has the symmetric property: its counters describe the original parse, and an operation that cannot change parse history must leave them byte-identical, disclosed as frozen by the edited suffix rather than "fixed up" on the way past. Downstream needs no parallel rule because every consumer already derives per frame from the draft, so a consistent pair assignment is the whole integration.
**Fix (or queued).** `ShipChangeOutcome` and `change_ship` beside `new_fitting`, the one locked log line, and 6 pure tests (`de140ad`); the editor block, apply bookkeeping, and resets are the companion entry below (`a9f802d`). Not shipped, by design: fitment-guarded change, auto-removal, charge compatibility, subsystem-aware recomputation, a current-hull listing exception, and changing to a non-candidate hull (design sections 2.2 and 12).
**Validation.** 1,091 tests pass at the integrator state (1,061 library — 1,051 at design base plus Builder A's 6 and Builder B's 4 — plus 12 `demo_seed`, 13 `esi_models`, and 5 `storage_roundtrip`, 0 failed; 1,081 at base plus exactly this slice's 10 new tests, no base test modified beyond the fixture extensions the design names), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. A fresh demo screenshot of the Fittings view (`Xvfb` + `scrot -o` to a fresh `/tmp/mimir-fittings-changeship.png`, removed first, `startup_view` set to `Fittings` in `app_settings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the top of the view in demo mode — the import heading and the "Start a new fitting" chooser with `Showing 100 of 404 ships.` — and the run log shows `[STARTUP] applying saved startup view Fittings`, `[FITTING] fitting types loaded types=25818 skipped=0`, and `[FITTING] ship candidates built rows=404`. The screenshot does not show the "Change ship" block: it renders only inside the editor, below the captured scroll position, when a draft is installed, and no draft was installed or ship clicked in the captured run — the pure change, exhaustive 404 pin, refusal ordering, no-retitle pins, and copy equivalence are covered by the headless pins in `src/fitting/editor.rs`, not by the image. Nothing here is live-verified against EVE (changing ship is local and in-memory; the only EVE write remains the pre-existing, separately unverified save path).
**Generalizable rule.** An operation that changes one field pair must leave every value it cannot affect byte-identical — never recompute a counter whose inputs the operation cannot move, and never retitle from an equality test that cannot distinguish a synthesized value from one the user typed; ground a provenance detection exactly or do not do it.
**Refs.** `docs/change-ship-design.md` sections 1, 3, 4, 8, 10, 11 (tests 1–6), 13; `src/fitting/editor.rs:411`, `:438`, `:459`; commits `54175cc` (design), `de140ad` (Builder A), `a9f802d` (Builder B); companion LEARNINGS entry below; the `Created`/`Copied` provenance entries below.

## 2026-11-19

### Two choosers, never one with a mode — and a same-ship click must not disarm a save, because the mapping it confirms is bit-for-bit unchanged

**Author.** Muse Code (changing a draft's ship workflow, integrator)
**Context.** The panel half of the slice adds a second ship block, "Change ship", inside the fitting editor (after the rename row, before the typed add row), while the shipped "Start a new fitting" chooser above the paste box keeps its replace-with-empty meaning byte-for-byte. One block with a create/change mode was rejected in the design: the same 404 rows carrying opposite consequences (discard everything vs keep everything) behind a mode toggle is a data-loss trap for one forgotten mode.
**Evidence.** `apply_ship_change` (`src/ui/fittings.rs:1607`, commit `a9f802d`) runs the pure change on the editor's working clone and books it by outcome: `Changed` calls the shipped `note_successful_edit` (edited flag set, editor error and quantity drafts cleared, `fittings_write_confirm` cleared whole — load-bearing because the armed confirmation re-renders each frame from the current draft, so without disarm it would silently refill with the new hull and be confirmable unread); `SameShip` does nothing at all, leaving the edited flag, the quantity drafts, and any armed save confirmation untouched; `Refused` only warns (`[FITTING] ship change refused unlisted ship row`, `:1617`), with no name, number, or search text. The by-outcome panel pin seeds paste text, an editor error, a quantity draft, both ship searches, and an armed save, then asserts each outcome's bookkeeping, including that a successful change clears neither search (the block stays filtered so a nearby hull can be picked, as a browser add leaves its search standing). A change is not an install: it never calls `clear_editor_state`, never clears paste text, import error, owner, rename draft, or the module-browser cache (whose candidates are keyed by section, never per ship). Both choosers share the one shipped row cache (`fittings_ship_rows`/`fittings_ship_rows_built`, built and logged at most once per clear cycle) but keep separate search strings (`fittings_ship_change_search`, `src/app/state.rs:877`, the slice's only new state) — one shared string in two simultaneously visible boxes would let a search typed to start a fitting silently narrow the list used to change one. The new search resets beside the shipped one in `clear_editor_state` (`src/ui/fittings.rs:1671`) and at the three `AppState` reset sites (`src/app/state.rs:1171`, `:1388`, `:1457`), with the isolation fixtures extended to seed and assert it, including the same-character-reselect and non-active-removal survival cases. Heading and standing note are locked constants (`FITTINGS_SHIP_CHANGE_HEADING`/`NOTE`, `src/ui/fittings.rs:1633` and `:1637`; block at `:3390`), asserted byte-for-byte with no `587`/`597` text, and the disclosure is pinned at the statistic layer: demo-sample Rifter → Punisher/Echelon/Tengu slot-layout literals (Echelon's five over-capacity lines flagged, Tengu's tech-3 suppression), and a copied Demo Brawler keeping all 11 items — including its Subsystems row — across changes to both Tengu (subsystem line shown) and Echelon (row kept in `items`, subsystem dimension `None`), the never-auto-remove pin.
**Mechanism.** Whether a click must disarm an armed confirmation turns on whether the mapping that confirmation would send changed, not on whether a click happened. `Changed` changes that mapping's hull, so it inherits exactly the shipped edit bookkeeping; `SameShip` leaves the draft bit-for-bit identical, so disarming would punish a no-op and error wording would report a result the user already sees. Placement carries the same logic spatially: a click's meaning should be readable from where it was clicked — above the paste box it starts over, inside the editor beside the fitting it keeps everything — so neither chooser needs a mode field, a per-mode reset story, or two standing notes where one unambiguous sentence ("Starting a new fitting replaces the fitting below, if there is one") already stands.
**Fix (or queued).** The `editor_change_ship` import, `apply_ship_change` with its refusal warning, the two wording constants, the second chooser block over the shared cache with its own search and the shipped match/cap/empty/overflow rules, the `clear_editor_state` line, the state field with its three resets and fixture extensions, and 4 new panel/state tests beside the extended install and clear fixtures (`a9f802d`). Nothing behaviour is queued behind this beyond the design's named deferrals (fitment-guarded change, subsystem-aware statistics, charge compatibility, draft persistence).
**Validation.** The integrator's fresh gate (1,091 tests; see the companion entry above) includes the shipped top-chooser, summary, install, and reset tests passing unmodified beside the new pins: wording literals, the `Eft` (` Edited since import.`) and `Created` (`Created "New Rifter Fit" (Punisher): 0 items. Edited.`) changed-summary literals, by-outcome apply bookkeeping, slot-layout disclosure pins, and the demo pins (404 candidates with Rifter/Punisher/Echelon/Tengu named, Demo Brawler keep-rows). The demo screenshot was captured at the top of the Fittings view with no draft installed, so it shows neither the "Change ship" block nor a changed draft; the click path is pinned headlessly, and the block's rendering position (inside the editor, after the rename row and before the typed add row, so its new hull feeds the same frame's resolver, statistics, copy, and save derivations) follows the shipped editor layout it was inserted into.
**Generalizable rule.** When one list must serve two opposite consequences, render two spatially separate blocks over one shared cache rather than one block behind a mode, keep their filters separate, and book every outcome by whether the confirmable mapping actually changed — a proven no-op neither marks edited nor disarms anything.
**Refs.** `docs/change-ship-design.md` sections 2.1, 5, 6, 7.1, 9, 10, 11 (tests 7–11), 13; `src/ui/fittings.rs:1607`, `:1617`, `:1633`, `:1637`, `:1671`, `:3390`; `src/app/state.rs:877`, `:1171`, `:1388`, `:1457`; commits `de140ad` (Builder A), `a9f802d` (Builder B); companion LEARNINGS entry above.

## 2026-11-18

### A saved fitting converts for editing by its saved flag and the names on screen — a row an edited copy cannot hold is a named skip, not a refusal of the whole fitting

**Author.** Muse Code (editing a copy of a saved fitting workflow, integrator)
**Context.** The edit-a-copy slice (`docs/edit-saved-copy-design.md`) adds a third door into the shipped fitting editor: selecting a saved fitting in the Fittings view offers "Edit a copy in Mimir", which converts that saved fitting into a new in-memory draft the editor and module browser can edit. The saved fitting in EVE is never overwritten — EVE's fitting service (ESI, EVE's public API) offers create and delete only — so a saved-back copy is always a new fitting. The locked value ranking puts no-silent-loss first, then honest provenance: a copied draft is never described as imported or created.
**Evidence.** The pure converter `convert_saved_fitting` (`src/fitting/saved_copy.rs:122`, outcomes at `:24` and `:32`, commit `508fa73`) takes the selected saved fitting and the app name resolver only — deliberately not the bundled catalogue. Section comes from the saved flag string alone, by exact match against the write mapper's ESI enum table minus its service row: `ServiceSlot0`–`ServiceSlot7` are counted skips because a draft has no service section, and routing one to Cargo (where the saved view happens to display it) would save a fitted service module back as carried cargo. Both rejected mappings are pinned by test: the saved view's prefix whitelist would resurrect rows the save path already drops (`LoSlot8`, `HiSlot00`, `loslot0`, `DroneBayExtra`), and dogma-derived sectioning would move or drop items EVE already placed whenever the catalogue lags — the shipped demo pins this, because Mission Runner's railgun and afterburner sit in sections their catalogue dogma disagrees with and both convert by flag (4 items, 0 skips). Names likewise come from the resolver the saved detail displayed, not the catalogue: in demo mode the shipped fixtures pair invented display names ("Demo Small Railgun") with unrelated published type numbers, and two demo item numbers (1535, 636) have no catalogue row at all, so catalogue names would rename or refuse the fitting on screen. Each row is decided in one fixed six-step order (saveable type, holdable section, holdable quantity — exactly 1 for slots, never forced or expanded; first claim wins a duplicate slot; resolved name required so the `Unknown Item` placeholder is never baked into a draft; stacked rows merge per (section, type), never by type alone, with the crossing row skipped on overflow), so a row with two faults counts exactly once under a deterministic kind. The five new skip kinds (`src/fitting/eft.rs:100`, reasons at `:163`) ride on the draft as issues under copied wording — the demo's headline fitting, Demo Brawler, converts to 11 items plus one named skip, its `Invalid`-flagged Pyerite row — while whole-conversion refusal is reserved for the ship gate alone (`ship_type_id <= 0`, or the ship name has not loaded), the only case where no draft can be titled honestly; under a refuse-on-any-bad-row model that headline demo fitting would be uneditable over one sample junk row. Provenance gets its own value again: `ImportFormat` gains a fourth variant, `Copied` (`src/fitting/eft.rs:266`), extending the `Created` rule from the entry below — a copied draft also has all-zero parse counters, yet its items came from EVE, so its summary reads `Copied "{name}" ({ship}) from your saved fittings: {n} items.` with the created arm's ` Edited.` suffix and neutral copy/save buttons. The round-trip invariant is pinned against a hand-written normalization (never derived by calling the converter): a converted draft synthesizes back to the source with skips dropped, stacked rows merged, and slot flags renumbered from 0 within each section, maps to a save request with zero dropped items, and converting that synthesis again yields identical items with zero skips, so edit-a-copy of a saved-back copy is loss-free. Logging follows the pure layer's counts-only rule: exactly two converter lines (`[FITTING] saved copy converted items={items} skipped={skipped}` at `src/fitting/saved_copy.rs:245`; `[FITTING] saved copy refused reason={reason:?}` at `:128`), with no fitting name, flag string, or type number ever logged.
**Mechanism.** EVE already placed every item, so the saved flag is the authority on where it sits — exactly as the write mapper and the saved statistic blocks already trust it — and re-deriving placement or names from bundled data would let catalogue gaps silently shrink a real fitting or rename it against what the user is looking at. A display grouping is not a saveability claim: one mapping (the converter's, derived from the save mapper's enum) must own the question "can a draft hold this row", because a draft row is a claim that will be saved back. The counted-skip tier is the import posture — partial success with a named, counted remainder — applied to a new source; it discloses strictly more than refusing the whole fitting, and the skips ride on the draft for its whole life, through every edit and at save time, rather than being disclosed once on a screen the user has left.
**Fix (or queued).** `convert_saved_fitting` with `SavedCopyOutcome`/`SavedCopyRefusal`, the `Copied` format, the five copied-only issue kinds with locked reasons, and 17 pure tests (`508fa73`); the control, install, and save-confirmation wording are the companion entry below (`1ce943e`). Not carried, by design: the original's EVE fitting identity (synthesis stamps `fitting_id: -1`, so a copy can only ever create), its description (no provenance carries one), and its slot indices and gaps (renumbered by definition). A service-slot section, carrying descriptions, and editing a saved fitting in place ship nothing (design section 11).
**Validation.** 1,080 tests pass at the integrator state (1,050 library — 1,026 at design base plus Builder A's 17 and Builder B's 7 — plus 12 `demo_seed`, 13 `esi_models`, and 5 `storage_roundtrip`, 0 failed), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. A fresh demo screenshot of the Fittings view (`Xvfb` + `scrot -o` to a fresh `/tmp/mimir-fittings-editcopy.png`, removed first, `startup_view` set to `Fittings` in `app_settings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the top of the view in demo mode — the import heading and the "Start a new fitting" chooser with `Showing 100 of 404 ships.` — and the run log shows `[STARTUP] applying saved startup view Fittings` and `[FITTING] fitting types loaded types=25818 skipped=0`. The screenshot does not show the "Edit a copy in Mimir" button: it renders inside the selected saved fitting's detail below the import panel, off the captured scroll position, and no saved row was clicked in the captured run — conversion, the demo pins (Demo Brawler 11 items plus the Pyerite skip, Mission Runner 4/0, Demo Runner 5/0), install and disarm, refusal, and every copied wording literal are covered by the headless pins in `src/fitting/saved_copy.rs`, `src/fitting/eft.rs`, and `src/ui/fittings.rs`, not by the image. Nothing in this slice is live-verified against EVE (converting and editing are local and in-memory; the only EVE write remains the pre-existing, separately unverified save path, still create-only).
**Generalizable rule.** When converting data an external authority already placed, trust the authority's placement field and the names the user already sees; never re-derive placement or names from bundled data that can lag that authority — and make per-row losses counted, named skips carried on the result, reserving whole-operation refusal for the case where no honest result can be titled at all.
**Refs.** `docs/edit-saved-copy-design.md` sections 1, 3, 4, 6, 9, 10, 13; `src/fitting/saved_copy.rs:24`, `:32`, `:122`, `:128`, `:245`; `src/fitting/eft.rs:100`, `:163`, `:266`; `src/ui/fittings.rs:1711`, `:3890`; commits `0b188bd` (design), `508fa73` (Builder A), `1ce943e` (Builder B); companion LEARNINGS entry below; the `Created` provenance entry below.

## 2026-11-18

### Installing a copy must disarm confirmations aimed at the original by construction — a staleness sweep cannot catch a target that is still selected

**Author.** Muse Code (editing a copy of a saved fitting workflow, integrator)
**Context.** Clicking "Edit a copy in Mimir" installs the converted draft above the saved list, exactly as creating a fitting from the ship chooser installs its empty draft — owner stamped from the active character, paste text and import error cleared, editor/browser/ship state reset. The difference is what an already-armed confirmation can be pointing at: the saved fitting's own save-a-copy and delete confirmations target the very fitting the user just chose to work from.
**Evidence.** `install_copied_fitting` (`src/ui/fittings.rs:1711`, commit `1ce943e`) clears the whole `fittings_write_confirm` field by one assignment, disarming all three shipped confirmations — a draft save armed for the draft being replaced, and the original's own save-a-copy and delete — while the original stays selected below for comparison and its controls re-arm one click away. Relying on the shipped staleness sweep instead would fail precisely here: the fitting is still selected and still in the list, so `write_confirm_is_stale` keeps an armed delete of it renderable and confirmable on the next frame. The install test pins this in three separate runs, seeding each confirmation variant stamped for the fitting being copied and asserting the field is `None` after install, alongside owner, cleared paste text and error, cleared editor/browser/ship fields, an unchanged saved selection, and the status template for 0, 1, and many skips. The refusal branch is the mirror discipline: `apply_copied_refusal` (`src/ui/fittings.rs:1697`) sets only the refusal status, and its test asserts the prior draft, paste text, editor state, selection, and armed confirmation are all untouched — a refusal the user fixes by waiting for names must never cost them the draft they already had. Two smaller locks ride with the install: alone among the three draft doors it sets a status message (`Editing a copy of "{name}" above. The saved fitting in EVE is unchanged.`, plus the skip count), because the click happens below where its result appears; and the save confirmation gains a third summary selection (`save_confirmation_copied`, `src/ui/fittings.rs:1053`) stating the saved fitting it was copied from stays as it is, while both shipped summaries stay byte-identical. The slice adds no state field at all — skips ride on the draft's existing report and provenance on its format — so character switch, character removal, replacement by any other door, and Clear cover a copied draft through the shipped resets with no new clearing site. Exactly one new log line ships here, counts-only at `src/ui/fittings.rs:1713`: `[FITTING] saved copy installed items={items} skipped={skipped} charges=0`.
**Mechanism.** A staleness check proves a confirmation's target still exists; it cannot prove the user's intent still points at it. Replacing the object the user is working on invalidates intent for every armed action in the surface at once, including actions whose target is unchanged and fully valid — here, a delete of the fitting the user has just said they want to work from. Clearing the whole field at install time makes disarm a property of the replacement itself rather than a coincidence of what happens to render next frame, and writing it as one assignment means a future fourth confirmation variant is disarmed by construction, with no per-variant list to forget to extend.
**Fix (or queued).** The "Edit a copy in Mimir" button and standing note after "Copy as DNA" (`src/ui/fittings.rs:3890`, gated only on the catalogue and an active character — not a write affordance, fully usable in demo), `install_copied_fitting` and `apply_copied_refusal`, the converted/refusal statuses, the copied save-confirmation summary, the install log line, and 7 panel tests (`1ce943e`). No behaviour is queued behind this: ship change on an existing draft and draft persistence remain deferred unchanged (design section 11).
**Validation.** The integrator's fresh gate (1,080 tests; see the companion entry above) includes the shipped import/creation install and wording tests passing unmodified beside the 7 new pins: copied summary/label/note literals, skip wording, the copied save summary for a renamed edited draft, install-and-total-disarm in the three confirmation variants, refusal-as-no-op for both refusals, and the demo pins against the shipped fixtures. The demo screenshot was captured at the top of the Fittings view before any saved row was selected or the button clicked, so it shows neither the button nor an installed copy; the click path is pinned headlessly, and the button's rendering position (inside the selected saved detail, after "Copy as DNA", before the write affordances) follows the shipped detail layout it was inserted into.
**Generalizable rule.** Any action that replaces the object the user is working on must clear every armed confirmation in that surface by direct assignment at replacement time; a staleness sweep only proves the old target still exists, never that the user's intent survived the replacement.
**Refs.** `docs/edit-saved-copy-design.md` sections 2.1, 5, 6.1, 6.3, 8, 10 (tests 9–14); `src/ui/fittings.rs:1053`, `:1697`, `:1711`, `:1713`, `:3890`; commits `508fa73` (Builder A), `1ce943e` (Builder B); companion LEARNINGS entry above.

## 2026-11-18

### Provenance that counters cannot express needs its own value — a zero-item draft made without parsing is not an import with zero lines

**Author.** Muse Code (new fitting from scratch workflow, integrator)
**Context.** The new-fitting slice (`docs/new-fitting-design.md`) adds a second door into the shipped fitting editor: under "Start a new fitting" in the Fittings view, the user searches the bundled ship list by name, clicks a hull, and lands in the editor and module browser with an empty draft named `New {ship} Fit`. Importing EFT or DNA text is unchanged. The locked value ranking puts honest provenance first: a created draft is never described as imported, and imported drafts keep every shipped string byte-for-byte.
**Evidence.** `ImportFormat` gains a third variant, `Created` (`src/fitting/eft.rs:242`, commit `17c2d1a`), because the alternative — recognising a created draft by its all-zero import counters — is false on shipped data: a header-only EFT import and a hull-only DNA import are also all-zero, and both were imported. The pure constructor `new_fitting` (`src/fitting/editor.rs:362`) builds the draft directly with `format: Created`, no items, and an all-zero report; it never synthesises import text and never calls a parser, so the zero counters mean "nothing was parsed" rather than "a parse read nothing". Every user-visible provenance string selects on the format value: `Created "{name}" ({ship}): {n} items.` with no "from 0 lines" clause, ` Edited.` instead of ` Edited since import.`, `Created fitting`, an editor note differing from the shipped note only by dropping the word "imported", and neutral copy and save buttons (design section 7.2; helpers and the chooser in `src/ui/fittings.rs:263`, `:1520`, `:1573`, `:3034`, commit `d2ea8db`). The three import-issue wording matches gain `Created` arms byte-identical to their EFT arms, unreachable because a created draft's issue list is empty at construction and the editor never pushes issues. Listing and construction compose as two proofs: `ship_candidates` (`src/fitting/editor.rs:303`, rows at `:288`) lists a hull only when it is category 6, its trimmed name is non-empty and non-numeric, its normalised name maps to exactly one type number, and both CPU and power-grid outputs are present (presence, never greater than zero — the Zephyr and Echelon carry real `0.0 / 0.0` outputs and list), which pins exactly 404 ships over the bundled catalogue; `new_fitting` then re-validates the clicked row by type number instead of trusting the caller, and an exhaustive test constructs a draft for every one of the 404 candidates. The ship name always comes from the catalogue row keyed by type number, never from text held beside the number: the retired Flutter ship browser hand-paired type numbers with names and three of its six pairs named the wrong hull (603 labelled Incursus where the catalogue says Merlin; design section 5.2), a failure this shape makes structurally impossible.
**Mechanism.** Counters record what a process did; provenance records which process ran. When two origins produce the same counter state — here, parsing empty text and not parsing at all — any wording derived from the counters must eventually lie about one of them, and the lie is user-visible ("imported" for a fitting the user just created by clicking). Giving provenance its own value at the construction site, where the origin is known for certain, keeps every later wording decision a lookup instead of an inference. The listing-then-revalidate split is the same discipline as the module browser's, one level up: the listing proves a click can succeed for the whole catalogue, and the constructor proves identity, category, and stat presence for the one row it is handed, so neither proof has to trust the other's caller. Requiring output presence (not positivity) for listing, while import keeps its looser shipped admission, is deliberate asymmetry: an empty draft's main content is its bare-hull statistics, so a choosable ship must prove the resources block can print numbers — but a future output-less hull can still be imported and will show the honest no-output sentence.
**Fix (or queued).** The `Created` variant, `ShipRow`, `ship_candidates`, `new_fitting`, and five pure tests (`17c2d1a`); the always-expanded chooser above the paste box (name search, 100-row cap with `Showing {shown} of {total} ships.`, name-only rows, no type number rendered or searched), the three memory-only ship state fields cleared at every editor and character reset site (`src/app/state.rs:874`), creation installing exactly as a successful import plus clearing the paste text and disarming any armed save, replacement with no confirmation (disclosed by the standing note, mirroring import), the created wording column, and exactly three new `[FITTING]` log lines (cache build with row count only at `src/ui/fittings.rs:3044`, creation with the catalogue ship name, and the unreachable-refusal warning with no name or number; search text is never logged) (`d2ea8db`). Ship change on an existing draft, editing a copy of a saved fitting, and draft persistence ship nothing (design section 12).
**Validation.** 1,056 tests pass at the integrator state (1,026 library plus 12 `demo_seed`, 13 `esi_models`, and 5 `storage_roundtrip`, 0 failed; 1,047 at design base plus Builder A's 5 and Builder B's 4), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. A fresh demo screenshot of the Fittings view (`Xvfb` + `scrot -o` to a fresh `/tmp/mimir-fittings-newfitting.png`, removed first, `startup_view` set to `Fittings` in `app_settings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the "Start a new fitting" heading, its standing note disclosing replacement and the memory-only contract, the `Search by name` box, `Showing 100 of 404 ships.`, and name-only rows starting Abaddon, Absolution, Adrestia; the run log shows `[FITTING] ship candidates built rows=404`, confirming the chooser renders with no draft present (unlike the module browser, it sits outside the draft guard because creating the draft is its purpose). The screenshot does not show a created draft, because no row was clicked in the captured run — creation, install and disarm, the created wording literals, search pins, and reset behaviour are covered by the headless pins in `src/fitting/editor.rs`, `src/ui/fittings.rs`, and `src/app/state.rs`, not by the image. Nothing in this slice is live-verified against EVE (creating and editing are local and in-memory; the only EVE write remains the pre-existing, separately unverified save and delete path, and an empty created draft reaches it only after an item is added).
**Generalizable rule.** When two origins can produce identical process counters, provenance must be stored as its own value at the site that knows the origin — never inferred later from the counters — and a chooser that feeds a constructor should prove listability for the whole set while the constructor re-proves the one chosen element by its stable key, taking every displayed name from the keyed row rather than from text carried beside the key.
**Refs.** `docs/new-fitting-design.md` sections 1, 3, 5–7, 10, 13; `src/fitting/eft.rs:242`; `src/fitting/editor.rs:288`, `:303`, `:362`; `src/ui/fittings.rs:263`, `:1520`, `:1573`, `:3034`, `:3044`; `src/app/state.rs:874`; commits `15203ac` (design), `17c2d1a` (Builder A), `d2ea8db` (Builder B); companion LEARNINGS entry below; the module browser picker entry below.

## 2026-11-18

### A created empty draft is not a new downstream case when both parsers already produce one

**Author.** Muse Code (new fitting from scratch workflow, integrator)
**Context.** A fitting started from the ship chooser holds zero items. The temptation when adding a new way to reach an empty structure is to add empty-case guards at each consumer; this slice (design section 8) instead records the shipped decision every consumer already makes and adds no new guard, refusal, or silent path.
**Evidence.** Both shipped parsers already produce valid zero-item drafts — header-only EFT and hull-only DNA — so every downstream consumer has existing, tested zero-item behaviour: the editor and module browser are fully usable from the first click, all 11 statistic blocks render bare-hull values, the loaded-charge and issue blocks hide behind their shipped non-zero and non-empty guards, copying is allowed (header-only EFT `[Rifter, New Rifter Fit]` and hull-only DNA `587::` re-import cleanly, pinned by a round-trip test through `parse_import`), and saving to EVE is refused by the shipped `unsaveable_label` guard because EVE's fitting service (ESI, EVE's public API) requires at least one item. The retired Flutter app sent an empty item list to EVE for a blank hull; the Rust guard refusing is a deliberate locked deviation, so a builder must not "fix" it by allowing empty saves. Likewise the damage-per-second surface check (`format == Eft`) is left untouched: a created draft takes the non-EFT branch, which correctly models it, because editor adds never carry a loaded charge, so its weapons are unloaded by construction.
**Mechanism.** The empty state was already inside the shipped contract, reached by parsing minimal text; creating it directly changes only the door, not the state. Re-deriving rules per consumer would have produced a second, diverging empty-contract (the obvious failure: refusing to copy a created empty draft while an identical header-only import copies freely, punishing the honest provenance the slice exists to provide). The design work was therefore an audit table, not new branches: enumerate every consumer, cite the shipped guard, and lock "unchanged" against each one so any new refusal has to argue against a recorded decision.
**Fix (or queued).** No downstream guard changed (`17c2d1a`, `d2ea8db`). The pure round-trip and exhaustive-construction tests pin the copy decisions and the construction invariant at the layer that owns them; the install test pins that replacement disarms an armed save explicitly, by construction, rather than relying on the empty draft dropping the confirmation next frame through the save guard — the one place the slice strengthens a downstream coincidence into a construction invariant.
**Validation.** The integrator's fresh gate (1,056 tests; see the companion entry above) includes the shipped zero-item parser and consumer tests passing unmodified, the created-draft EFT/DNA round trip, and the install-and-disarm test seeding a dirty draft with an armed save confirmation and asserting the created draft installed with paste text, error, and confirmation cleared. The demo screenshot was taken before any row click, so it shows no created draft and no statistic blocks; bare-hull rendering of a created draft is pinned by the same shipped tests that cover header-only imports, plus the listing proof that every choosable hull carries the output pair the resources block needs.
**Generalizable rule.** Before adding an empty-state guard for a new entry point, check whether an existing path already produces that state; if it does, the work is an audit that records each consumer's shipped decision, and the only new rules allowed are ones that turn a downstream coincidence into a construction invariant.
**Refs.** `docs/new-fitting-design.md` sections 5.1, 6, 8, 11 (tests 3, 4, 10); `src/fitting/editor.rs:362`; `src/ui/fittings.rs:1573`; commits `17c2d1a` (Builder A), `d2ea8db` (Builder B); companion LEARNINGS entry above.

## 2026-11-17

### A picker that lists only what the add path would accept must re-prove membership with the classifier's own predicates — and a section defined by elimination cannot be browsed

**Author.** Muse Code (fitting module browser workflow, integrator)
**Context.** The module browser slice (`docs/fitting-module-browser-design.md`) adds a second door into the fitting editor: seven section tabs (High, Med, Low, Rig, Subsystems, Drones, Fighters) inside the import panel list catalogue rows, and clicking a row adds it to the imported draft. The typed exact-name box stays unchanged. The value ranking puts one property first: every listed row is addable by construction, so the browser never sets up a classification refusal the editor then has to deliver.
**Evidence.** The pure builder `browser_candidates` (`src/fitting/editor.rs:208`, rows at `src/fitting/editor.rs:191`, commit `54876f6`) lists a row only when three proofs hold in order: its normalized name maps to exactly one type number (a multiplicity map over the shipped `normalize_type_name`, first row winning — deliberately not one `FittingTypes::lookup` call per row, because each lookup emits a debug log line and 25,818 of them per candidate build is not acceptable), the trimmed name passes the shipped non-empty and non-numeric chooser guard, and the editor classifier's own section predicates hold (category 7 or 32 plus `slot_section` for slot tabs; category 18 for drones; category 87 for fighters). Slot proof without category is not enough on real data: 330 bundled structure-module rows (category 66) carry slot effects — Standup Anticapital Missile Launcher I carries effect 12 — and every one would refuse at add time. The bundled-catalogue pins are 1,371 / 903 / 1,005 / 642 / 48 / 129 / 94 rows per tab, with exhaustive tests adding every listed candidate by name and asserting success in the tab's section (design section 10 tests 3 and 4). Cargo gets no tab and `browser_candidates` returns an empty list for it: the editor routes a name to Cargo by elimination (anything that is not a drone, fighter, module, or subsystem), so a Cargo listing would be 21,594 catch-all rows across 33 categories that the data cannot distinguish as cargo candidates. The panel (commit `765e0be`) applies a click through the verbatim typed-add match — the same `editor_add_item` call, `note_successful_edit` on success, and `add_refusal_message` wording on refusal — so the only refusals a click can still meet come from typed quantity state on the stacked tabs, never from the row. Because the bundled catalogue holds 25,818 rows while the shipped choosers rebuild per frame over about a hundred, candidates are cached per tab in state and rebuilt only when the cached section differs, with the slice's single new log line at `src/ui/fittings.rs:3079` (`[FITTING] module browser candidates built section={:?} rows={count}`) making each build auditable; the catalogue is a bundled asset loaded once per process, so the cache cannot go stale, and it is still cleared at every editor reset site so its lifetime matches the draft's.
**Mechanism.** A listing and an admission check that each derive "what belongs in this section" separately drift at exactly the rows neither test samples: the browser would eventually offer a row the add path refuses, and the user meets a refusal the interface itself set up. Running the classifier's predicates verbatim at list time makes addability a property of shared code, and the exhaustive per-candidate add tests pin the agreement so a future catalogue or classifier change fails a test instead of surprising a user. The Cargo absence is the same discipline from the other side: a section the editor defines only by what it is not has no positive membership to prove, so there is nothing honest to list — the typed path, which classifies one named item at a time, keeps working because it never needed the listing. The per-tab cache follows from scale, not preference: the shipped choosers' rebuild-per-frame pattern is sound at a hundred rows and wrong at 25,818, and the one log line per build is what makes a rebuild-per-frame regression visible instead of silent.
**Fix (or queued).** `BrowserRow` and `browser_candidates` with the locked membership order and the industry sort (`54876f6`); the seven tabs, name search, 100-row render cap with the shipped showing line, click-to-add through the typed-add match, the four browser state fields cleared at every editor reset site, and the single cache-build log line (`765e0be`). Drag and drop, double-click to add, a Cargo tab, a ship browser, and charge editing ship nothing (design section 12). Row labels print CPU and power grid figures only when the catalogue carries them and never a type number; search matches names only, never the formatted label, so searching a figure cannot find a module by its CPU value.
**Validation.** 1,047 tests pass at the integrator state (1,017 library plus 12 `demo_seed`, 13 `esi_models`, and 5 `storage_roundtrip`, 0 failed; 1,038 at design base plus Builder A's 7 and Builder B's 2), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. A fresh demo screenshot of the Fittings view (`Xvfb` + `scrot -o` to a fresh `/tmp/mimir-fittings-browser.png`, removed first, `startup_view` set to `Fittings` in `app_settings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows Aria Voss's Demo Brawler selected under the import panel with its `Use sample EFT` / `Use sample DNA` buttons; the browser block renders only while an imported draft is shown (design section 2.1), so with no draft imported it does not appear in that screenshot and no candidates-built log line fires — the tabs, search, labels, click routing, and reset behavior are covered by the headless pins in `src/fitting/editor.rs`, `src/ui/fittings.rs`, and `src/app/state.rs`. The run log shows `[FITTING] fitting types loaded types=25818 skipped=0` and `[STARTUP] applying saved startup view Fittings`. Nothing in this slice is live-verified against EVE (browsing and editing are local and in-memory; the only EVE write remains the pre-existing, separately unverified save and delete path).
**Generalizable rule.** A picker may list only what it can prove the consuming operation will accept, proven with that operation's own predicates and pinned by exhaustively running the operation over every listed candidate — and a category defined by elimination has no browsable membership, so it ships no tab rather than a catch-all listing the data cannot support.
**Refs.** `docs/fitting-module-browser-design.md` sections 1–3, 6–8; `src/fitting/editor.rs:191`, `:208`; `src/ui/fittings.rs:254`, `:261`, `:3079`; commits `c39a993` (design), `54876f6` (Builder A), `765e0be` (Builder B); companion LEARNINGS entry below.

## 2026-11-17

### Hand-pinned "next row" literals must be scripted through the actual sort, punctuation included — and a locked field in a derived-Default struct locks a Default on its type

**Author.** Muse Code (fitting module browser workflow, integrator)
**Context.** Design section 10 test 9 pinned the browser search by example: `damage control` over the Low candidates yields 25 rows "starting `'Basic' Damage Control` then `Damage Control I`". Builder B's test failed on the second name. Separately, design section 8 locked a new `AppState` field of type `ImportSection` with initial value High, and section 11.2 locked Builder B to two files (`src/app/state.rs`, `src/ui/fittings.rs`).
**Evidence.** The count (25) and first row (`'Basic' Damage Control`) reproduce exactly, but under the locked section 3.4 sort (lowercased name, then name, then type number — a byte order) both apostrophe-prefixed names sort before every letter-starting name: the true second row is `'Radical' Damage Control`, and `Damage Control I` sits at index 10. Builder B verified this independently of the failing assertion with a Python replication of the loader filter, the section 3 predicates, and the shipped sort over `assets/sde/fitting_types.json`, then pinned the true second row plus the presence of `Damage Control I` (`src/ui/fittings.rs:8648` onward, assertion at `:8652`) with the discrepancy documented in a test comment and flagged in the builder report — no sort or search behavior was changed to fit the design's example. The state field needed a third file: `AppState` derives `Default`, so a field of type `ImportSection` with a High initial value requires `ImportSection: Default`; Builder B added the two-line derive (`src/fitting/eft.rs:58`, `High` marked `#[default]`) — behavior-free, outside section 11.2's two-file list, and flagged the same way. The alternative, an orphan-style manual construction inside `state.rs`, was judged worse than the derive on the type that owns the default.
**Mechanism.** Both slips are the same shape: a design states a consequence in prose ("then Damage Control I", "a field with initial High") without running the mechanism that produces it. A human reading a sorted list groups the apostrophe variants with their base names and expects the plain name next; byte order puts the apostrophe (0x27) before every letter, so every quoted variant precedes every unquoted one — the example was derived by eye from the name family, not by executing the locked sort. The derive slip is the type-level twin, and the same family as the fitting editor slice's missed `pub(crate)` constants (see the 2026-11-17 editor entry): what a locked surface needs includes what its own machinery reads — a derived `Default` reads a `Default` on every field type, none of which appear in the field list itself.
**Fix (or queued).** The test pins the true order with the discrepancy in a comment (`765e0be`), and this entry records that design section 10 test 9's second-row literal is wrong as written while its count, first row, and intent hold. The `Default` derive lands in the same commit. No behavior change in either case: the sort stays the shipped industry order the design locked in section 3.4, and `ImportSection::default()` is High exactly as section 8 requires.
**Validation.** The integrator's fresh gate (1,047 tests; see the companion entry) includes `browser_search_filters_names_only` passing with the corrected second-row pin, the upper-cased needle yielding identical results, an empty needle yielding all candidates, and a search for `30.0` matching no row. The derive is proven by compilation under `cargo clippy --all-targets -- -D warnings` and by the reset fixtures asserting the browser section returns to High at every clearing site.
**Generalizable rule.** Every ordered literal in a design or test plan must be produced by running the exact comparator over the exact data, including punctuation-prefixed names — never by reading the family and writing the expected next member — and a locked field addition must be checked against every derive the containing struct carries, because each derive silently requires the corresponding impl on the new field's type.
**Refs.** `docs/fitting-module-browser-design.md` sections 3.4, 8, 10 (test 9), 11.2; `src/fitting/eft.rs:58`; `src/ui/fittings.rs:8648`, `:8652`; commit `765e0be` (Builder B); companion LEARNINGS entry above; the fitting editor slice's visibility-list entry below.

## 2026-11-17

### A second writer to the same structure must call the first writer's classifier — slot proof is a refusal, and a locked visibility list can miss the constants the shared rule reads

**Author.** Muse Code (fitting editor workflow, integrator)
**Context.** The fitting editor slice (`docs/fitting-editor-design.md`) adds four operations on the in-memory import draft `AppState.fittings_imported` — add an item by exact catalogue name, remove a row, set a stacked row's quantity, and rename — so an imported fitting can be changed before the existing copy and save paths consume it. The tempting implementation is a fresh, simpler classification for "what may be added"; the design instead requires the editor to reuse the EFT (EVE Fitting Tool) importer's name lookup, slot proof, stacked-item classification, and quantity bounds verbatim, with refusals worded by the importer's own `ImportIssueKind::reason()` strings.
**Evidence.** The pure core in `src/fitting/editor.rs` (commit `1187cba`) calls the importer's `classify_module`, `parse_stack_quantity`, and `absorb_stack` from `src/fitting/eft.rs`, and `EditRefusal::reason()` delegates to `ImportIssueKind::reason()` — pinned by a test asserting all seven refusal strings equal the importer wording, plus the renderer's `Could not add: {reason}.` / `Could not set the quantity: {reason}.` templates pinned string-equal against the same function. A fitted item enters a slot section only when `slot_section(&row.slot_effects)` proves the slot from bundled dogma effects 12/13/11/2663/3772; that refusal path is reachable on real data — "Lux Kontos" (type 34580, category 7, empty `slotEffects` in `assets/sde/fitting_types.json`; three more such rows exist) is pinned by literal name refusing `NoSlotForModule` and changing nothing, and ambiguity is likewise real ("Spiked Quafe" names two bundled rows, types 21661 and 54165, refusing `AmbiguousName` with and without a quantity). The design's section 8.1 locked four symbols to make `pub(crate)` in `eft.rs` but omitted `CATEGORY_DRONE` (18) and `CATEGORY_FIGHTER` (87), which the shared stacked-classification rule reads (`src/fitting/editor.rs:139` and `:140`); Builder A made both `pub(crate)` too (`src/fitting/eft.rs:34` and `:36`) — a visibility-only delta, flagged in the builder report, with no behavior change. Report counters split the same way as the proof split: `charges_noted` is recounted from the current draft on every successful edit because it feeds live disclosures (the charges note, both copy statuses, the save confirmation's charges line), while `imported_lines`, `placeholder_lines`, and `issues` stay frozen as parse history, which is why the summary gains the suffix ` Edited since import.` instead of the counters being rewritten to pretend the paste said something else.
**Mechanism.** Two writers to one grammar drift at exactly the untested joint: an editor that re-derived slot placement would eventually guess a slot the importer would refuse, and refusal wording copied into editor strings would diverge from the import issues list on the next wording change. Calling the classifier makes "never guess a slot" a property of shared code rather than of two parallel implementations — and the bundled catalogue proves the refusal is not theoretical, because published category-7 rows exist whose slot no shipped effect proves. The visibility slip is the same lesson in miniature: a design that enumerates which private symbols a shared rule needs can miss the constants that rule reads internally, because they never appear in the rule's signature. The counter split follows the same ownership line — a counter that describes the current draft must be recounted; a counter that describes the parse must not be touched, and the honest fix for the summary line is a disclosure suffix, not rewritten history.
**Fix (or queued).** The pure editor core `src/fitting/editor.rs` with `add_item` / `remove_item` / `set_quantity` / `rename`, the six locked `[FITTING]` log lines (counts and fixed tokens only, canonical catalogue names of successful adds, refused typed names never logged), charges recounted on every successful edit, and the visibility-only `pub(crate)` widening in `src/fitting/eft.rs` (`1187cba`). Ship change, new-from-scratch fittings, editing a copy of a saved fitting, charge editing, reorder/move/duplicate, undo, any item picker beyond the exact-name box, and any new blocking validation (capacity, hardpoints, groups, skills) ship nothing (design sections 2.2 and 11) — the editor never writes a flag string, because `to_character_fitting` assigns slot flags by per-section counters on the next synthesis, so removing a row renumbers survivors exactly as a shorter paste already did.
**Validation.** 1,038 tests pass at the integrator state (1,008 library plus 12 `demo_seed`, 13 `esi_models`, and 5 `storage_roundtrip`, 0 failed; 1,019 at design base plus Builder A's 13 and Builder B's 6), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. The editor pins run against `FittingTypes::bundled()` with no synthetic catalogue, including the round trip: an edited draft copied through `fitting_to_eft` re-imports to the same item multiset (charges excluded, as copy already discloses). A fresh demo screenshot of the Fittings view (`Xvfb` + `scrot -o` to a fresh `/tmp/mimir-fittings-editor.png`, `startup_view` set to `Fittings` in `app_settings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows Aria Voss's Demo Brawler selected under the import panel with its `Use sample EFT` / `Use sample DNA` buttons; the `Edit this fitting` block renders only while an imported draft is shown, so with no draft imported it does not appear in that screenshot — its controls, the edited suffix, the refusal templates, and the disarm rule are covered by the headless pins in `src/ui/fittings.rs` and `src/app/state.rs`. The run log shows `[FITTING] fitting types loaded types=25818 skipped=0` and `[STARTUP] applying saved startup view Fittings`. Nothing in this slice is live-verified against EVE (editing is local and in-memory; the only EVE write remains the pre-existing, separately unverified save and delete path).
**Generalizable rule.** When a second surface writes to a structure an importer already builds, it must call the importer's classifier and reuse its refusal wording rather than re-derive either — one grammar for what may enter — and a design's locked list of symbols to share must be checked against every constant the shared rule reads, not only its signature; counters that describe the current state are recounted on edit, counters that describe the parse are frozen and disclosed, never rewritten.
**Refs.** `docs/fitting-editor-design.md` sections 3–5, 7–9; `src/fitting/editor.rs:23`, `:139`, `:140`, `:358`, `:380`; `src/fitting/eft.rs:34`, `:36`; commits `e0bb572` (design), `1187cba` (Builder A), `907aa0c` (Builder B); companion LEARNINGS entry below.

## 2026-11-17

### Per-row edit boxes in an immediate-mode panel need per-row draft storage — and the draft must be written back before anything derives from it

**Author.** Muse Code (fitting editor workflow, integrator)
**Context.** Builder B puts the section 6 controls inside `fittings_import_panel` (`src/ui/fittings.rs`): a rename row, an add row, a per-row `Remove` button, and a per-stacked-row quantity box with `Set quantity`. The design locked exactly four new `AppState` fields beside the import fields (`fittings_editor_add_name`, `fittings_editor_add_quantity`, `fittings_editor_error`, `fittings_import_edited`). That is enough for the rename and add rows, but not for quantity boxes on rows whose count and order change as the fitting is edited.
**Evidence.** Builder B added one functional extra beyond the locked four, `fittings_editor_quantity: HashMap<usize, String>` (`src/app/state.rs:848`), holding each stacked row's typed quantity text by row index — in egui's immediate mode there is nowhere else for half-typed per-row text to live across frames, and binding the box straight to the row's stored quantity would rewrite the fitting on every keystroke. The rename box needed no fifth field, by contrast, because it binds directly to the working clone's `name` under the panel's existing clone discipline. The index key is the hazard: removing a row shifts every later index, so Builder B drops all quantity drafts on any successful edit, and all five editor fields are cleared at the three existing reset sites (character switch, character removal, empty roster — pinned by extending the existing switch test through its shared seed/assert helpers) plus Clear import, both demo-sample buttons, and both new-import outcomes. Edits mutate the per-frame working clone with intents recorded during row rendering, and the draft is written back *before* the statistics, copy, and save code derives from it, so every pure statistics block recomputes from the edited fitting the same frame (the design requires visibility by the next frame; same-frame is a superset) with no statistic function changed. The one new downstream rule is the disarm: any successful edit sets `fittings_write_confirm = None`, because although the armed save confirmation recomputes its mapping per frame and could never send stale bits, a user must never confirm one fitting and send an edited other. Imported row rendering mirrors `fitting_item_rows` order exactly — including the lexicographic flag sort past `LoSlot10`, where `LoSlot10` sorts before `LoSlot2` — proven by a 12-item parity test, so the index a row control acts on is the index the saved-detail ordering shows.
**Mechanism.** Immediate-mode rendering has no persistent widget state: any text the user has typed but not applied must live in application state keyed by the row it belongs to, and a design that counts editor fields by rows on screen ("one quantity box") undercounts by the number of rows the box repeats on. Keying those drafts by position is only safe if position changes invalidate them, because a draft that survives a removal silently attaches to a different item. The write-back ordering is the same discipline one level up: the panel already re-synthesizes `to_character_fitting()` every frame for all eleven statistics blocks, so an edit is free everywhere at once *only* if the mutated clone becomes the draft before any of those derivations run — write back after rendering and the statistics would show the pre-edit fitting beside post-edit rows. The disarm rule closes the human version of the same gap: correctness of the sent bytes was never at risk (the confirmation recomputes), but consent was, because the confirmation text the user read described a fitting that no longer exists.
**Fix (or queued).** The fifth field with drop-on-any-successful-edit semantics, all editor state cleared at every draft-clearing site, clone write-back before derivation, the ` Edited since import.` suffix gated on `fittings_import_edited`, the disarm-on-edit rule, and row-order parity with `fitting_item_rows` land in `907aa0c` (`src/app/state.rs`, `src/ui/fittings.rs`). One edit intent is applied per frame — simultaneous row clicks in one frame collapse to the first — which is invisible at panel frame rates and keeps index arithmetic single-stepped. Saved-fitting detail rendering (`render_fitting_items`) and every statistics block are untouched, and the panel adds no log lines of its own (the six locked `[FITTING]` editor lines live in the pure core).
**Validation.** The integrator's fresh gate (1,038 tests; see the companion entry) includes Builder B's six new pins: editor fields cleared on switch, removal, and empty roster; the edited suffix present only after a successful edit; the refusal templates string-equal to `ImportIssueKind::reason()`; arming the save confirmation then editing disarms it; editor state cleared on Clear import and new import; and the 12-item row-order parity pin past `LoSlot10`. An unedited import renders as before (design section 9 regression terms) because the editor block only adds controls around the existing summary, item list, statistics, and copy/save order, which are unchanged.
**Generalizable rule.** In an immediate-mode UI (user interface), budget draft state per editable row, not per control kind — typed-but-unapplied text needs application-owned storage keyed by row, invalidated whenever row identity shifts — and when one draft feeds many per-frame derivations, write the edit back before any derivation runs and re-ask for consent (disarm the confirmation) whenever the thing consented to changes, even if the machinery would have recomputed the right bytes anyway.
**Refs.** `docs/fitting-editor-design.md` sections 4.1, 5, 6, 8.2, 9; `src/app/state.rs:848`; `src/ui/fittings.rs:1190`, `:1198`, `:1336`; commit `907aa0c` (Builder B); companion LEARNINGS entry above.

## 2026-11-17

### Behavior beyond the reference app ships only when the data triple and a generic-machinery oracle both exist — what ported was the chain, not the behavior

**Author.** Muse Code (fitting need-reductions workflow, integrator)
**Context.** The need-reductions slice (`docs/fitting-need-reductions-design.md`) reduces counted module CPU and power grid needs by five trained skills (Weapon Upgrades, Advanced Weapon Upgrades, Energy Grid Upgrades, Electronics Upgrades, Shield Upgrades) in the fitting resources block. The retired Flutter app — this repo's usual behavior oracle — never applied these skills at all, so for once there was no reference behavior to port, only a formula to justify.
**Evidence.** Design section 1 records the Flutter counter-evidence by read at `ed698d3`: usage is a raw sum (`cpuUsed += type.cpu; powerUsed += type.powergrid`, `dogma_engine.dart:688-695`), no `moduleAttr` call reads attributes 50/30, and no fitting test pins any need changing with skill level. What does exist is the full modifier triple in the committed SDE files — the scripted scan in design section 2.1 finds attributes 310/323 (`cpuNeedBonus`/`powerNeedBonus`) on exactly five published skills, with the resolved `modifierInfo` entries (source skill, per-level value attribute, operation 6, modified attribute, target filter) in `dogmaEffects.jsonl` — plus Flutter's *generic* machinery: per-level scaling (`attr.value * level`, `dogma_engine.dart:596-612`), filter evaluation (`routeLocationModifier`, required-skill and group matching), operation-6 post-percent storage, and the unpenalized product in `_applyBonuses`, ending in one exercised oracle — Repair Systems (skill 3393, test E2.7) running the identical chain onto a module attribute. The Rust side is the twelve-entry private table `NEED_REDUCTION_ENTRIES` (`src/fitting/resources.rs:136`, provenance comment at `src/fitting/resources.rs:124` naming effect 672 as deliberately absent) behind the five skill-ID constants (`src/fitting/resources.rs:54` onward), with `base_used` kept beside `used` so no base figure is ever replaced silently, and the applied lines in `src/ui/fittings.rs:1341` ("need before skill reductions") and the honest disclosure at `src/ui/fittings.rs:1199`. Everything short of that evidence bar ships nothing, by name (design section 2.3): effect 672 (item-domain, skipped outright by Flutter's skill loop, so no inspected body defines it), the 132/211/246 boost chain (the client spelling of the ×level scaling the formula already applies once — counting them again would double-scale), the three unpublished Advanced siblings, and every non-skill 310/323 carrier (implants, modules, rigs, subsystems, ship).
**Mechanism.** A reference implementation grounds two different things that are easy to conflate: the *behavior* (which it exercises end to end) and the *machinery* (generic code paths whose arithmetic is defined for inputs the reference never feeds them). New behavior can ride the machinery honestly only when a committed data file supplies the complete input triple for exactly the entry being added and at least one exercised oracle runs the same chain with different parameters — otherwise the percent, the filter, or the scaling gets invented at exactly the joint the data stops. The same joint discipline decides the deferrals: effect 672 fails the oracle test, and the boost effects fail the apply-once test, so both are named absences in code comments rather than silent gaps.
**Fix (or queued).** The generator extension emitting `groupId` and `requiredSkillIds` on exactly the 3,183 cpu/power catalogue rows with fail-loud oracles (`5a27ae0`), the loader fields (`src/names/fitting_types.rs:325` and `:327`) with the population invariants (`d0f40de`), the pure reduction arithmetic with the wrong-ID traps (filter skill never looked up for a level) and the compounding-killing level pins (`a3d17bf`), and the rendered before-reduction lines, five named reduction lines, and replaced disclosure (`a1d622f`). No general modifier pipeline was built (see the DECISIONS entry on the locked entries table).
**Validation.** 1,019 tests pass at the integrator state (989 library plus 12 `demo_seed`, 13 `esi_models`, and 5 `storage_roundtrip`, 0 failed), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. The regenerated catalogue is 3,754,697 bytes (sha256 `69967d00…`, inside the design's 3,770,000 budget): the integrator re-ran the generator and got a byte-identical file (`cmp` clean, summary `need_filter_keys groupId=3183 requiredSkillIds=3183 requiredSkillValues=4306`), and a textual strip of the two new keys across all 3,183 rows reproduces the 3,622,804-byte base exactly (sha256 `e12703…`), so the asset diff is additive-only. A fresh demo screenshot of the Fittings view (`Xvfb` + `scrot -o` to a fresh `/tmp/mimir-fittings-need-reductions.png`, `startup_view` set to `Fittings` in `app_settings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows Aria Voss's Demo Brawler selected with its slot sections; the resources block sits below that screenshot's fold and is covered by the headless demo pins — neither demo character trains any of the five skills, so the demo used/output figures stay the shipped applied story (84.0/130.0 CPU, 3.0/51.3 power) while the block gains before-reduction lines equal to the used figures and five level-0 lines, with Aria's Gunnery level 4 pinned as reducing nothing. Nothing in this slice is live-verified against EVE (it reads only bundled data and the already-loaded skills state).
**What surprised.** The most natural "port" move — model every effect the five skills carry — would have been the wrong one twice over: the item-domain boost effects are the same ×level scaling the owner-attributes step already performs, so completeness would have doubled every reduction.
**Generalizable rule.** Behavior the reference app never had may still ship when a committed data file carries the full modifier triple for that exact entry *and* an inspected generic-machinery body plus one exercised oracle define the arithmetic — and any entry failing either test ships nothing and is named absent in the code, because what ports is the verified chain, never the value at its end.
**Refs.** `docs/fitting-need-reductions-design.md` sections 1–4, 6, 9–12; `src/fitting/resources.rs:124` and `:136`; DECISIONS 2026-11-17 entries-table entry; commits `12f65a1` (design), `5a27ae0` + `d0f40de` (Builder A), `a3d17bf` + `a1d622f` (Builder B).

## 2026-11-17

### Counted-but-unprovable needs its own count — and that requires present-empty to differ from absent

**Author.** Muse Code (fitting need-reductions workflow, integrator)
**Context.** The same slice must answer, per counted module, three distinct questions: is the need usable, does a skill reduction apply, and — the new one — can that second answer even be proven from the catalogue row in hand. The shipped catalogue always carries the proof; stale or hand-built catalogues may not, and a mixed reduced-plus-unprovable total must never present as fully reduced.
**Evidence.** The generator emits `requiredSkillIds` always-present on the 3,183 need rows, **including as an empty list** (3,175 non-empty, 8 empty, 4,306 values — design section 4), and the loader mirrors that distinction with `#[serde(default)]` `Option` fields (`src/names/fitting_types.rs:325` and `:327`): `Some([])` means filter data present, module requires no skills; `None` means this catalogue carries no filter data for the row. The pure layer keeps the two counts disjoint by construction — `excluded_modules` (need unusable, contributes 0, checked first) versus the new `unreduced_modules` (need counted at full value in both `used` and `base_used`) which increments only when levels are loaded, at least one source skill for that dimension is above 0, and the filter data that dimension needs is absent (`required_skill_ids` `None`, or CPU-only `group_id` `None`). The renderer discloses it per dimension at `src/ui/fittings.rs:1386` ("counts {n} fitted modules at full need: Mimir's bundled item data has no skill-reduction data for them."). On the shipped regenerated catalogue the count is provably always 0 (section 5 invariants pin `Some` on exactly the need rows, `src/names/fitting_types.rs:1192` onward), so the whole rule is pinned by labelled synthetic `from_json` fixtures — the only catalogues where it can be nonzero.
**Mechanism.** The interesting sub-rule is the gating on level: when every relevant source skill is level 0, the factor is provably 1 whatever the missing filters would say, so an absent-filter row is *proven unreduced*, not unprovable, and disclosing it would cry wolf on every stale catalogue forever. Absence of data is only an honesty problem when the missing data could have changed the number. None of this is implementable if the loader conflates "proven empty" with "not in this file" — a plain defaulted `Vec` (the `slot_effects` shape) erases exactly the bit the count needs — which is why the always-present emission (sparse-when-empty was rejected in design section 4 for the same conflation) and the `Option<Vec<…>>` loader shape are one decision, not two. The same reasoning family as the sustained-tank repair markers, now applied to list emptiness.
**Fix (or queued).** Always-present emission with the 4306-value generator census (`5a27ae0`), the `Option` loader fields with population/shape/count invariants (`d0f40de`), the excluded-first unreduced counting contract with quantity-unit increments (`a3d17bf`), and the per-dimension unreduced lines that coexist with excluded lines in one render (`a1d622f`). The lines never render on the shipped catalogue by construction — they exist so the number stays honest if a future cache ever breaks the invariant at runtime.
**Validation.** The integrator's fresh gate run (1,019 tests; see the companion entry) includes the synthetic-fixture pins: a keyless module at Weapon Upgrades 5 counted at full need with `unreduced_modules` equal to its quantity, the same fixture at all-zero levels counting 0, `required_skill_ids` present with `group_id` absent unreduced in CPU only, `Some([])` proven with 0 unreduced, a quantity-3 row counting 3, and the rendered singular/plural lines beside excluded lines. The shipped-catalogue proof is the invariant side: `group_id`/`required_skill_ids` `Some` on exactly the 3,183 need rows and `None` elsewhere, re-derived by the integrator's generator rerun (`need_filter_keys groupId=3183 requiredSkillIds=3183 requiredSkillValues=4306`).
**Generalizable rule.** Any "counted but the modifier cannot be proven" disclosure requires the data model to distinguish proven-empty from absent (`Some([])` vs `None`, decided at emission, not at render), and the count must be gated on the missing data being able to matter — provably-irrelevant absence is proven, not undisclosed.
**Refs.** `docs/fitting-need-reductions-design.md` sections 4–6 and 8; `src/names/fitting_types.rs:325`, `:327`, `:1192`; `src/ui/fittings.rs:1386`; companion LEARNINGS entry above; DECISIONS 2026-11-17 entries-table entry.

## 2026-11-17

### A traversal can be well-tested and still never traverse — and an ambiguity rule can be a refusal

**Author.** Muse Code (industry production-chain workflow, integrator)
**Context.** The production-chain slice (`docs/production-chain-design.md`) adds the Production Chain Calculator the invention and reaction slices deferred: the bundled industry loader is widened from activity 11 (Reaction) to activities 1 (Manufacturing) and 11, a reverse product-to-blueprint index is added, and a pure chain builder expands a chosen item into the materials its whole runs need. The natural starting point was the retired Flutter builder, which has a test.
**Evidence.** Design sections 4 and 6: Flutter's `production_chain_builder.dart` (at `ed698d3`) probes `getIndustryMaterials(materialTypeId, …)` — it treats each material's item type as if it were that item's blueprint type. Scripted against the shipped `assets/sde/industry.json`, zero product types and zero material types are also blueprint types, so that probe finds no materials for any real item, every real root is an immediate raw leaf, and the recursion never traversed real data at all. Its one test mocks exactly that leaf (type 34, Tritanium) and passes. The loader widening in `src/names/industry_ref.rs` (commit `2013aa6`) retains 27,190 material rows and 4,917 product rows (4,788 manufacturing blueprints beside the 112 reaction blueprints) and builds the reverse index the earlier designs named: 4,891 buildable products, 4,886 made by exactly one blueprint and exactly 5 made by more than one. Design section 2 shows those five candidates carry genuinely different material lists and batch sizes (for example product 16672 `Tungsten Carbide` ← batch 20 versus batch 10000, one also needing a fuel block), so no inspected body grounds any tie-break; a second data fact — 51 items are their own sole material at quantity 1, batch 1 — is what the builder's ancestor guard renders once without re-expanding.
**Mechanism.** A key-domain error can make a whole traversal dead code that looks alive: keying by the wrong id space (item type where a blueprint type belongs) turns every lookup into a miss, and a miss is indistinguishable from the legitimate "raw material" answer, so the recursion, its missing cycle guard, and its batch-blind arithmetic were all unreachable while the test suite stayed green — because the only test exercised the one case (an unmakeable leaf) that the broken probe and a correct probe answer identically. Once the reverse index supplies the real product→blueprint step, the per-run meanings the reaction slice had already locked (materials are per-run inputs, the product quantity is per-run output) force the arithmetic: runs are the smallest whole number making at least the wanted quantity and inputs scale by runs, where Flutter's straight multiplication down the tree overstates one pinned leaf 1,005-fold (design sections 2 and 6). The ambiguity rule then turns out to be a refusal, not a preference: with the candidates carrying genuinely different recipes, any tie-break (lowest id, named blueprint, first in file) would have been an invented answer wearing the data's clothes, so such an item cannot be chosen and renders unexpanded inside a chain.
**Fix (or queued).** The widened loader with per-activity intersection membership, activity-aware dedup keys, filtered accessors, and the reverse index (`2013aa6`), the pure builder `src/production_chain.rs` with checked whole-run arithmetic, the ancestor-cycle node, the multiple-blueprints node, and depth/expansion caps pinned unreachable on the shipped data (maximum depth 7, worst tree 2,265 nodes) (`ab0199f`), session-only drafts (`bffbe93`), and the renderer with the 4,299-name choice, the two disclosure sentences deleting "There is no production-chain calculator.", and guidance instead of any quantity for no choice / invalid / too-large input (`6425097`). Aggregation, leftover netting, efficiency and bonus application, and any blueprint picker for ambiguous items ship nothing (design section 11).
**Validation.** 996 tests pass at the integrator state (966 library plus 12 demo_seed, 13 esi_models, and 5 storage_roundtrip, 0 failed), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. A fresh demo screenshot of the Industry view (`Xvfb` + `scrot -o` to a fresh `/tmp/mimir-industry-production-chain.png`, `startup_view` set to `Industry` in `app_settings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the Invention Calculator at `39.0%` above the Reaction Calculator with `Showing 100 of 111 reactions.`, and the run log shows `[INDUSTRY] industry data loaded materials=27190 products=4917 manufacturing=4788 reactions=112 skipped=0` and `[INDUSTRY] bundled industry data loaded manufacturing=4788 reactions=112`. The production-chain block sits below that screenshot's fold (under the reaction block's 100-row list) and is covered by the headless whole-vector pins in `src/ui/industry.rs` and `src/production_chain.rs`: the choose-guidance over the demo bundle, the Small Blaster Battery starting block, the Carbon Fiber batch block at quantities 1 and 201, the Reprocessing Array cycle line, and the Orca root rendered in full at 512 lines. Nothing in this slice is live-verified against EVE (the calculator reads only bundled data and entered values).
**Generalizable rule.** When a traversal's miss case is also a legitimate answer, a passing leaf test proves nothing about the recursion: script the probe against the real data's id spaces and pin at least one root that must expand, or the traversal can stay dead while looking tested — and when the data gives several genuinely different recipes for one item, the honest resolution rule is a refusal, because picking one silently is an invented answer wearing the data's clothes.
**Refs.** `docs/production-chain-design.md` sections 2–4, 6, 10–13; commits `cdbf204` (design), `2013aa6` + `ab0199f` + `bffbe93` (Builder A), `6425097` (Builder B).

## 2026-11-17

### A loader should retain only what its one consumer can use honestly — and an integer formula through f64 needs an exact bound, not only checked multiplication

**Author.** Muse Code (industry reaction workflow, integrator)
**Context.** The industry reaction slice (`docs/industry-reaction-design.md`) adds the Reaction Calculator the invention slice deferred: a Rust loader for the activity-11 (Reaction) tables in the shipped `assets/sde/industry.json`, a pure calculator porting the retired Flutter reaction formula, and a name-based reaction choice in the Industry view.
**Evidence.** The bundled file carries 85,080 rows across five sections; the loader in `src/names/industry_ref.rs` (commit `b8b26e0`) deserializes only `materials` and `products` and retains only activity-11 rows — 384 materials and 112 products, 496 rows — and defines a reaction blueprint as the intersection of those two retained sections (112 types), so the unloaded `activities`, `probabilities`, and `skills` sections are never deserialized (a fixture with garbage in them still loads, pinned in the loader tests). Of the 112, exactly one blueprint (type 45732) has no name in `assets/sde/fitting_types.json`; it stays in the loaded data but the choice list in `src/ui/industry.rs` (commit `439803b`) excludes any blueprint whose catalogue name is missing, empty, or numeric, leaving 111 choosable reactions. In `src/reaction_calculator.rs` (commit `e626bad`), inputs reject any total above 9,007,199,254,740,992 (2^53, the largest integer up to which every integer is exact in `f64`) in addition to `checked_mul`, with the boundary pinned (2^53 computes; 2^53+1 gives no result for inputs but stays valid for the pure-integer outputs), and Flutter's minimum-of-1 guard is applied once to the multiplied, rounded total — as its code does — not per run as its comment says (pinned: 10 runs of 1 at 99% gives 1, never 10).
**Mechanism.** Retaining more than the one consumer can use would make sections the calculator never reads able to fail, skew, or bless its data, and a generic activity query could only return empty-looking answers for activities never retained; intersection membership means no half-reaction (materials without products, or the reverse) can ever be calculated. The unnamed blueprint fails differently: a name-based choice presented as `Unknown Item` cannot be told apart from any other unnamed formula, so it would reproduce Flutter's raw-ID panel in words. The float bound closes the last gap: above 2^53, converting a checked integer total to `f64` silently moves it to a neighbouring representable value, so `checked_mul` alone still lets a rounded result be wrong by whole units while looking exact.
**Fix (or queued).** The narrow two-section, one-activity loader (`b8b26e0`), the pure calculator with checked multiplication plus the 2^53 bound and the total-level minimum-of-1 (`e626bad`), session-only drafts (`ac363af`), startup loading that degrades to a fixed unavailable sentence (`526a7d3`), and the renderer with the 111-name choice, guidance instead of any quantity for no choice / invalid / too-large input, and the amended invention disclosure sentence (`439803b`). The production chain ships nothing again (design section 11): it needs the activity-1 widening, a reverse product-to-blueprint index, a batch-size rule, and a cycle guard, none of which any inspected body decides.
**Validation.** 970 tests pass at the integrator state (940 library plus 12 demo_seed, 13 esi_models, and 5 storage_roundtrip, 0 failed), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. A fresh demo screenshot of the Industry view (`Xvfb` + `scrot -o` to a fresh `/tmp/mimir-industry-reaction.png`, `startup_view` set to `Industry` in `app_settings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the Invention Calculator at `39.0%` and, below it, `Reaction Calculator`, `Showing 100 of 111 reactions.`, and the first named formulas (Axosomatic Neurolink Enhancer, C3-FTM Acid, Caesarium Cadmide, Carbon Fiber); the run log shows `[INDUSTRY] industry reaction data loaded materials=384 products=112 reactions=112 skipped=0`. The runs and bonus fields, choose-guidance, disclosure, and the Carbon Fiber starting block sit below that 100-row list's fold in the screenshot and are covered by the headless whole-vector pins in `src/ui/industry.rs`. Nothing in this slice is live-verified against EVE (the calculator reads only bundled data and entered values).
**Generalizable rule.** Retain only what the one consumer can use honestly and define catalogue membership as the intersection of the sections actually loaded, so unloaded data cannot fail or bless a result; exclude (do not placeholder) any entry a name-based choice cannot name; and any integer formula that passes through `f64` needs the 2^53 exact-representation bound in addition to `checked_mul` before its totals can be called exact — porting the code's guard, not its comment, when the two disagree.
**Refs.** `docs/industry-reaction-design.md` sections 2–4, 6, 7, 12; commits `242f40c` (design), `b8b26e0` + `e626bad` + `ac363af` (Builder A), `526a7d3` + `439803b` (Builder B).

## 2026-11-17

### Data the app has is not data a calculator may use — and Flutter's cap test turns an infinite product into a plausible 100% unless finiteness is checked first

**Author.** Muse Code (industry calculators workflow, integrator)
**Context.** The industry calculators slice (`docs/industry-calculators-design.md`) ports the retired Flutter invention calculator to the Industry view: five user-entered scalars (base probability as a fraction, three skill levels, and a decryptor multiplier). Three stronger behaviours were tempting: auto-filling the base probability or skill levels from data already on disk or loaded, porting the reaction and production-chain "calculators" alongside it, and keeping Flutter's cap behaviour when the product overflows.
**Evidence.** Design sections 3 and 9: the bundled `assets/sde/industry.json` carries a `probabilities` table (1,341 rows) and a `skills` table (22,257 rows), but no Rust code loads that file (`src/names/sde.rs` loads only `assets/sde/skills.json`); the app loads character skills (`SkillsData`), but no inspected Flutter or Rust body says which skill types count as the encryption and two datacore skills for a given invention; and a delivered invention job's carried `probability` field (demo job 710000203 at 0.4) is documented as parsed and carried but "never rendered and never enter[s] any computation", with nothing equating a past job's probability to a new calculation's base. Flutter's reaction panel hard-codes dummy maps marked `// Dummy base inputs and outputs for testing` and renders raw `Item #<id>` rows, and its production-chain visualizer renders an invented dummy tree, both over SDE industry tables Rust never loads. Design sections 2 and 4: Flutter's domain function validates nothing — an infinite product returns 1.0 through its `> 1.0` cap test — while the port in `src/invention_calculator.rs` checks `raw_chance` finiteness *before* the cap and returns `None` for the pinned overflow case (`1.0, 5, 5, 5, 1.5e308`), and the renderer in `src/ui/industry.rs` shows guidance plus the disclosure with no percentage in that state.
**Mechanism.** Each nearby data source is one loader, mapping, or meaning short of the figure it resembles: a bundled-but-unloaded table cannot supply a value honestly, a readable skill level cannot be matched to the right skill without a per-blueprint mapping, and a past job's probability is not defined as a future attempt's base. Using any of them would present an invented input as read data. The reaction and production-chain panels fail further out: they were never calculations over real inputs in Flutter at all — dummy data over an unloaded graph — so only the closed scalar formula could ship. The overflow corner is the same failure inside the arithmetic: a capped-looking `100.0%` manufactured from a non-finite product looks computed but carries no usable number, so presence has to be decided by finiteness before the cap can turn infinity into a plausible result.
**Fix (or queued).** The pure module (`src/invention_calculator.rs`, commit `d0a956c`) keeps all five inputs explicit with Flutter's starting values (0.30, each skill level 4, decryptor multiplier 1.0) seeded only as editable draft text in `AppState` (commit `f31408d`); the renderer (commit `df71b26`) labels each field "(entered by you)", shows `Invention Chance: 39.0%` at the starting values, and shows guidance instead of any figure when a field is empty, invalid, or too large to calculate with. Reaction and production-chain calculators, any SDE industry loader, every auto-fill, and every derived figure ship nothing (design section 9); a future reaction or chain slice needs the named loader, blueprint choice by resolved name, and cycle decision first.
**Validation.** 937 tests pass at the integrator state (907 library plus 12 demo_seed, 13 esi_models, and 5 storage_roundtrip; 917 stated at slice start plus Builder A's 14 and Builder B's 6), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. A fresh demo screenshot of the Industry view (`Xvfb` + `scrot -o` to a fresh file, `startup_view` set to `Industry` in the app-settings table for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the Invention Calculator block with the five starting drafts (0.30 / 4 / 4 / 4 / 1.0), `Invention Chance: 39.0%`, `With entered skills and decryptor`, and the full disclosure above the demo industry jobs; the cleared-field guidance state is covered by the headless whole-vector pins in `src/ui/industry.rs`. Nothing in this slice is live-verified against EVE (the calculator reads no network, character, blueprint, or job data at all).
**Generalizable rule.** Data the app *has* is not data a calculator may *use*: a bundled-but-unloaded table, a readable level, and a carried probability are each one loader, mapping, or meaning short of the figure they resemble, so the input stays labelled and user-entered — and when porting a cap, check finiteness *before* the cap, or an overflow becomes a plausible-looking maximum.
**Refs.** `docs/industry-calculators-design.md` sections 2–4, 7, 9–11; commits `b0380c3` (design), `d0a956c` + `f31408d` (Builder A), `df71b26` (Builder B).

## 2026-11-17

### A readable skill level does not make the fee percent it implies knowable — and Flutter's "Infinity ISK" break-even is where an Option plus guidance replaces a plausible-looking non-number

**Author.** Muse Code (market trade calculator workflow, integrator)
**Context.** The trade calculator slice (`docs/market-trade-calculator-design.md`) ports the retired Flutter per-unit calculator to the Market view: four user-entered numbers (buy price, sell price, broker-fee percent, sales-tax percent), broker fee on both orders, sales tax on the sell order only. Two stronger behaviours were tempting: deriving the fee percents from the active character's loaded skills, and keeping Flutter's break-even behaviour when the fees take the whole sale.
**Evidence.** Design sections 3 and 9: the app loads character skills (`SkillsData`) and the bundled skill catalogue names Broker Relations (type 3446), Advanced Broker Relations (type 16597), and Accounting (type 16622), but no inspected Flutter or Rust body states a base broker-fee or sales-tax percent, a per-level reduction, a standing term, or a structure term — Flutter's panel is mounted as "pure client-side, no character needed" and never looks a skill up. Design sections 2 and 4: Flutter's `breakEvenSellPrice` returns `double.infinity` when the denominator is at or below zero and its panel renders that as the literal text "Infinity ISK"; the port returns `Option<f64>` in `src/trade_calculator.rs` and renders no figure for `None`, and `calculate_margin` returns `None` when the two percents sum to 100 or more or any computed output is non-finite. The shipped renderer in `src/ui/market.rs` shows input or no-result guidance plus the disclosure in the `None` state, with no ISK figure of any kind.
**Mechanism.** A skill level is one input to an effective fee rate, not the rate itself: without the complete formula (base, skills, standings, and the station or structure term together), any derived percent would be an invented rate wearing the character's name. The break-even corner fails the same way in the opposite direction: "Infinity ISK" looks like a computed quote but carries no usable number, and the existing `widgets::format_isk` renders non-finite input as `0.00 ISK`, which would be a second false quote; presence has to be decided by the `Option`, never by formatting a non-finite or absent value.
**Fix (or queued).** The pure module (`src/trade_calculator.rs`, commits `b54a14e` and `e5061c6`) keeps both percents as explicit inputs with Flutter's starting values 1.0% and 2.0% seeded only as editable draft text in `AppState`, labelled "Broker Fee % (entered by you)" and "Sales Tax % (entered by you)"; the renderer (commit `8dd332e`) routes every ISK figure through `price_label`, omits the break-even line when it is `None`, and shows guidance instead of any figure when no result exists. Skill-derived, standing-derived, and structure-derived rates, relist fees, and quantity totals ship nothing (design section 9); a future derivation needs an inspected formula body for the complete rate, not for one term of it.
**Validation.** 916 tests pass at the integrator state (886 library plus 12 demo_seed, 13 esi_models, and 5 storage_roundtrip; 898 stated at slice start plus Builder A's 13 and Builder B's 5), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. A fresh demo screenshot of the Market view (`Xvfb` + `scrot -o` to a fresh file, `startup_view` set to `Market` in the app-settings table for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the Trade Calculator block with empty price fields, the seeded 1.0 and 2.0 fee drafts, the input guidance, and the full disclosure, above the demo Tritanium bundle (best sell 5.75 ISK, best buy 5.50 ISK); the typed Tritanium case (5.50 / 5.75 rendering PROFITABLE, 0.02 ISK, 0.4% margin) is covered by the headless demo-independence pin in `src/ui/market.rs`. Nothing in this slice is live-verified against EVE (the calculator reads no network, character, or market data at all).
**Generalizable rule.** If only one term of a rate formula is readable, the rate stays a labelled user input; and when a ported calculation can produce a non-finite or absent result, carry it as an `Option` and render guidance, never a formatted non-number or a computed-looking zero.
**Refs.** `docs/market-trade-calculator-design.md` sections 2–4, 7, 9–11; commits `ea03542` (design), `b54a14e` + `e5061c6` (Builder A), `8dd332e` (Builder B).

## 2026-11-17

### A repair rate over raw cycle time is a while-cycling burst rate, not sustained tank — and no inspected body divides repair by a resistance

**Author.** Muse Code (sustained-tank workflow, integrator)
**Context.** The base active-repair slice (`docs/sustained-tank-design.md`) shows, for saved and imported fittings, raw base hit points per second per hit-point layer from the fitted shield boosters, armor repairers, and hull repairers. The issue name ("sustained tank") invited two stronger claims: averaging ancillary (charge-fed) repairers over their reload time, and dividing each layer's rate by that layer's resistances to give an effective tank.
**Evidence.** Design sections 2.2 and 2.4, grounded in the retired Flutter `dogma_engine` repair block read during design: the rate is amount over raw attribute 73 (`duration`) with a comment that reload (attribute 1795) is never added — the ancillary armor literal is 52/6, not 52/66, and the ancillary shield literal is 52/2 = 26.0 hit points per second with its reload row ignored (pinned in `src/fitting/active_repair.rs` and rendered in `src/ui/fittings.rs`). No inspected body divides a repair rate by a resistance: the Flutter damage-pattern code divides buffer hit points only, and the after-action report's sustained-repair label is the literal "Not modeled". The loaded Nanite Repair Paste multiplier (attribute 1886) is likewise never emitted or read — the integrator confirmed no such key exists anywhere in the shipped catalogue — so ancillary repairers use their dry (unloaded) amounts on every surface, matching the capacitor-booster ship-nothing precedent.
**Mechanism.** A burst rate while a module cycles and a long-run average over charge reloads are different numbers with different conditions; labelling the burst rate "sustained" would promise the average. Effective tank fails for a different reason: with no inspected body performing the division, any resistance combination would be invented math, and the shipped base resistances belong to the bare hull, not to the fitted ship the repair modules sit on.
**Fix (or queued).** Raw base active repair per layer ships in `src/fitting/active_repair.rs` (quantity times base amount over raw duration in seconds, no reload, no ship input, no total across layers) under the heading "Active repair (base values)" in both fitting detail views, with a disclosure stating the continuous-cycling, dry-ancillary, no-reload-average terms and that the repairers' capacitor cost is the existing capacitor block's statement, not re-simulated. Effective/resistance-applied tank, effective hit points per second, loaded-paste amounts, reload-averaged rates, and any passive-plus-active sum ship nothing.
**Validation.** 898 tests pass at the integrator state (868 library plus 30 integration; base 863 plus Builder A's 28 and Builder B's 7), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. Catalogue byte-identity was re-proven fresh: stripping exactly the eight new keys from the regenerated `assets/sde/fitting_types.json` (3,622,804 bytes, SHA-256 `e1270322…`; 25,818 rows) and re-dumping compactly reproduces the `35a37a4` catalogue byte for byte (3,611,903 bytes, SHA-256 `c4c0e127…`, trailing newline included). The boundary diff against `35a37a4` touches seven files (design, generator, catalogue, loader, `src/fitting/active_repair.rs`, `src/fitting/mod.rs`, `src/ui/fittings.rs`) with zero deleted lines under `src/` and `scripts/`. A fresh demo screenshot of the Fittings view (`Xvfb` + `scrot -o`, `startup_view` set to `Fittings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the selected "Demo Brawler" saved fitting; the active-repair block sits below the scroll fold in that harness, so its lines are covered by the headless demo pins in `src/ui/fittings.rs` (Demo Brawler three 0.0 hit-point-per-second lines plus one disclosed exclusion; Mission Runner and Demo Runner three zeros with no exclusion sentence; real-type renderings 61.3 / 34.7 / 1.3 / 15.3 / 26.0 / 8.7 hit points per second). The run log shows `fitting types loaded types=25818 skipped=0` and `portrait fetches suppressed in demo mode count=12`. Nothing in this slice is live-verified against EVE (all inputs are bundled data and pasted text).
**Generalizable rule.** If the inspected bodies compute only a while-cycling burst rate and never combine it with resistances, ship the raw rate under its own name or ship nothing; an issue title like "sustained tank" is not evidence for math no body performs.
**Refs.** `docs/sustained-tank-design.md` sections 2–11; commits `a8aaddb` (design), `32ec411` + `d80768c` (Builder A), `842b847` (Builder B); the effect-gating entry directly below.

## 2026-11-17

### When self and remote modules share the same repair attributes, classification must be gated by effect at generation time — and a missing-data population needs an effect marker to be counted

**Author.** Muse Code (sustained-tank workflow, integrator)
**Context.** The same slice needed each self-repair module's base repair amount: attribute 68 (`shieldBonus`), 84 (`armorDamageAmount`), or 83 (`structureDamageAmount`). Remote (logistics) repairers aimed at other ships carry those exact same attributes, and a further population of abyssal repairers carries the repair effects but no amount rows at all.
**Evidence.** Design section 3, re-counted from the committed data caches during design and Builder A, and confirmed by the integrator on the shipped catalogue: ungated emission would have put the amount keys on 145 / 161 / 33 types (self plus remote mixed), while gating by the self-repair effects ({4, 4936} shield, {27, 5275} armor, {26} hull) yields 99 / 109 / 25, and the remote proof types gain no repair keys. The five effect-name boolean markers land on 94 / 14 / 105 / 12 / 25 rows (`shieldBoosting`, `fueledShieldBoosting`, `armorRepair`, `fueledArmorRepair`, `structureRepair` — integrator catalogue counts in that key order: amounts 99 / 109 / 25, markers 94 / 14 / 105 / 12 / 25), and the 17 abyssal repairers are marker-only, which is what makes them visible to the runtime as candidates without usable data.
**Mechanism.** An attribute says how much a module repairs, not whom it repairs; that distinction lives only in the module's effects. Emitting amounts ungated would have counted incoming logistics as the fitted ship's own tank, and emitting amounts alone (no markers) would have made the no-data repairers indistinguishable from non-repair modules, so they could neither be counted nor disclosed — they would silently read as zero repair.
**Fix (or queued).** The generator (`scripts/sde/generate_fitting_types_sde.py`) emits the three amount keys only under the self-repair effect gate (with catalogue self-validation of the expected counts and remote-absence oracles), and emits the five markers keyed by effect name regardless of amount presence. At runtime in `src/fitting/active_repair.rs`, a marker or amount makes a fitted module a candidate: a usable amount and cycle counts it, a present 0.0 amount is known-zero (none ship), and a candidate without usable data — including every marker-only abyssal repairer and any unknown type — is excluded with a disclosed count in quantity units, never counted as zero. Remote repairers count in neither bucket on any surface.
**Validation.** Covered by the same fresh integrator run as the entry above: 898 tests green across all four gates, catalogue byte-identity after stripping exactly the eight new keys, all eight catalogue counts reproduced above from the shipped file, and headless demo and real-type pins for the counted, known-zero, and excluded paths in `src/fitting/active_repair.rs` and `src/ui/fittings.rs`.
**Generalizable rule.** When one attribute set serves two module roles, gate emission by effect at generation time; and any population defined by missing data needs a positive marker emitted alongside, or honest excluded-with-count reporting is impossible.
**Refs.** `docs/sustained-tank-design.md` sections 3, 5, 8, 10; `scripts/sde/generate_fitting_types_sde.py`; `src/names/fitting_types.rs`; the burst-rate entry directly above.

## 2026-11-17

### Capacitor equilibrium is a discrete-event property, not an average-rate comparison — "stable if use per second is at or below peak recharge" was rejected

**Author.** Muse Code (cap-stability workflow, integrator)
**Context.** The base capacitor-stability slice (`docs/cap-stability-design.md`) shows, for saved and imported fittings, whether the fitted modules whose base capacitor use is in the bundled item data, cycling continuously, settle or empty the bare hull's base capacitor. The tempting shortcut was to compare total module capacitor use per second against the ship's already-shipped base peak recharge rate and call the fitting stable when use is at or below peak.
**Evidence.** Design section 2, grounded in the retired Flutter `CapSimulator` body read during design and Builder A: recharge is applied in closed form between discrete module-activation events (`cap = ((1+(sqrt(cap/C)-1)*exp(-dt/tau))^2)*C`, `tau = rechargeMs/5`), identical drains are grouped and staggered by `duration/count`, equilibrium is detected over the least-common-multiple period (`cap >= capWrap`), the stable level is a water-mark midpoint, and time-to-empty is event-quantized (`secondsToEmpty = tLast/1000`) within a 3600-second horizon. No inspected body proves that shortcut equivalent to that simulation, and Builder A's grouping regression shows the event shape changes the answer: the demo pair ungrouped depletes at 192.0 seconds, grouped and staggered at 234.0 seconds (`identical_drains_group_into_one_staggered_stream` in `src/fitting/ship_cap_stability.rs`).
**Mechanism.** Capacitor recharge rate depends on the current charge level, and modules remove capacitor in discrete chunks at their cycle times, so whether the level recovers over a repeating cycle depends on when activations land, not only on the average drain. An average-rate comparison can therefore name a fitting stable or unstable for a reason the underlying event sequence does not support, and it cannot produce the event-quantized depletion time at all.
**Fix (or queued).** The full event-driven simulator ports at base values in `src/fitting/ship_cap_stability.rs` (closed-form recharge between events, grouped staggering, least-common-multiple equilibrium with a checked-overflow fallback to the horizon, water-mark stable percent, event-quantized seconds); total use per second and peak recharge (via the shipped `ship_base_peak_recharge`) render as supporting lines only in the new "Capacitor (base values)" block in `src/ui/fittings.rs`, never as the verdict. Modules without usable capacitor-need or cycle data are excluded with a disclosed count in quantity units, never counted as zero; a present need of 0.0 is known-zero (neither counted nor excluded).
**Validation.** 863 tests pass at the integrator state (833 library plus 30 integration; Builders A and B reported 34 and 4 new library tests respectively), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. Catalogue byte-identity was re-proven fresh: stripping exactly `capacitorNeed`, `duration`, and `reloadTime` from the regenerated `assets/sde/fitting_types.json` (3,611,903 bytes, SHA-256 `c4c0e127…`; 25,818 rows, counts 2,095 / 1,489 / 986, `capacitorBonus` on 0 rows) reproduces the `ce9b0e7` catalogue byte for byte (3,519,738 bytes, SHA-256 `e25bc796…`). The boundary diff against `ce9b0e7` touches seven files (design, generator, catalogue, loader, `src/fitting/ship_cap_stability.rs`, `src/fitting/mod.rs`, `src/ui/fittings.rs`) with zero deleted lines under `src/` and `scripts/`. A fresh demo screenshot of the Fittings view (`Xvfb` + `scrot -o`, `startup_view` set to `Fittings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the selected "Demo Brawler" saved fitting; the capacitor block sits below the scroll fold in that harness, so its lines are covered by the headless demo pins in `src/ui/fittings.rs` (Demo Brawler 5.3 GJ/s, "Depletes in about 234s"; Mission Runner 0.0 GJ/s, "Stable at 100%"; Demo Runner 2.7 GJ/s against 6.3 peak, "Stable at 77%"; sample EFT 10.1 GJ/s, "Depletes in about 36s"; saved and imported details identical). The run log shows `fitting types loaded types=25818 skipped=0` and `portrait fetches suppressed in demo mode count=12` with no fetch-started line. Nothing in this slice is live-verified against EVE (all inputs are bundled data and pasted text).
**Generalizable rule.** When a shipped simulator decides by discrete events, port the event simulation or ship nothing; an average-rate shortcut is a different claim wearing the simulator's name unless an inspected body proves them equivalent.
**Refs.** `docs/cap-stability-design.md` sections 2–11; commits `0cc9291` (design), `f606c8a` + `5fd843b` (Builder A), `6be4afb` (Builder B); the reloadTime/booster entry directly below.

## 2026-11-17

### An SDE attribute default must never stand in for an absent row — `reloadTime`'s 10000.0 default, and why capacitor boosters ship nothing

**Author.** Muse Code (cap-stability workflow, integrator)
**Context.** The same slice needed each counted module's cycle time: attribute 73 (`duration`) when present, else attribute 51 (`speed`), plus attribute 1795 (`reloadTime`) only when a row is actually present. It also had to decide whether capacitor boosters (injectors) could appear anywhere in the stability figure.
**Evidence.** Design sections 3, 4, and 9: the SDE (Static Data Export) default for `reloadTime` is 10000.0, but the retired Flutter engine adds 0.0 when the row is absent, and 1,229 types would gain a fabricated 10-second reload if the default were substituted. For boosters, Flutter builds injectors from a module's loaded charge type plus charge attribute 67 (`capacitorBonus`), assuming infinite clips ("Capacitor horizon 3600s; injector clips are infinite."); Rust saved fittings carry no such charge linkage (loaded booster charges sit as unlinked cargo) and no fitting shape holds a charge count. The shipped catalogue confirms the emission side: the integrator counted `capacitorNeed` on 2,095 rows, `duration` on 1,489, `reloadTime` on 986, and `capacitorBonus` on 0 of 25,818 rows.
**Mechanism.** A dogma default describes what the game engine assumes when code asks for the attribute; it is not evidence that the type carries that value, and substituting it silently lengthens over a thousand cycle times and understates their capacitor use per second. Boosters fail differently: the saved-fitting shape cannot say which charge is loaded, so any booster model would either guess the charge or exist only on the imported surface, branching the meaning of the same labelled line by surface; the infinite-clip assumption would additionally overstate endurance for a finite stock no shape can count.
**Fix (or queued).** `reloadTime` is emitted and added only when a row is present (never the 10000.0 default), pinned by an absent-row case in `src/fitting/ship_cap_stability.rs` (`15000 + 10000 = 25000` ms only with a present row). Capacitor boosters ship nothing on any surface: attribute 67 is never emitted or read, and the rendered disclosure states boosters are not modelled. Cross-ship effects (energy neutralizers and nosferatu drain or gain, remote capacitor transfer) are likewise unmodelled and disclosed; such modules count only their own-ship drain.
**Validation.** Covered by the same fresh integrator run as the entry above: 863 tests green across all four gates, catalogue byte-identity after stripping exactly the three new keys, and headless demo pins for the rendered disclosure wording in `src/ui/fittings.rs`. Builder A's shipped counts also corrected five design-text figures with inspected evidence (exclusions count quantity units not rows; gated catalogue counts 240/17 rather than cache totals 258/20; Demo Brawler excluded 5 not 3; known-zero neither counted nor excluded; counts stay populated when the outcome is unavailable) — recorded in Builder A's result, not by editing the design after the fact.
**Generalizable rule.** An absent attribute row means "not in the data," never "use the dogma default"; and when one surface's data shape cannot carry an input another surface could, ship the feature on neither rather than letting one label mean two things.
**Refs.** `docs/cap-stability-design.md` sections 3, 4, 9, 10; `scripts/sde/generate_fitting_types_sde.py`; `src/names/fitting_types.rs`; the equilibrium entry directly above.

## 2026-11-17

### A weighted turret range is only honest if every counted turret carries that range — 34 Entropic Disintegrators carry optimal with no falloff row at all

**Author.** Muse Code (volley-ranges workflow, integrator)
**Context.** The volley and turret-ranges slice (`docs/volley-ranges-design.md`) adds one volley line (turret plus launcher damage in one firing cycle) and volley-weighted turret optimal and falloff lines to the shipped base damage-per-second block. It had to decide what a fitted turret with no row for a range attribute contributes to a weighted average of that attribute over the fitted turrets.
**Evidence.** Design sections 2 and 3, corroborated from the committed `dgmTypeAttributes` cache during design and re-checked on the shipped catalogue by the integrator: of 636 true turrets, 34 Entropic Disintegrators carry attribute 54 (dogma name `maxRange`, display "Optimal Range", retired Flutter field `optimalRange` — one attribute, three names; the catalogue key follows the dogma name) with no attribute 158 (`falloff`) row at all, so the missing-falloff case is shipped-data behaviour, not a fixture edge. The shipped catalogue carries `maxRange` on 1,157 category-7 rows and `falloff` on 681, including type 47272 with `maxRange` only, type 447 with a present-zero `falloff` of 0.0, and type 484 at 800 / 4300 (generator oracles in `scripts/sde/generate_fitting_types_sde.py`; pure rules and tests in `src/fitting/dps.rs`).
**Mechanism.** An average over "the turrets that have the attribute" is a different number from an average over the counted fitted turrets, and counting a missing row as 0 (the retired Flutter weighting) drags the average toward zero by a turret whose range is in fact unknown. A row that is present at 0.0 is data and counts with full weight; a missing row is not zero, it is absent. Only a turret that actually contributes volley can make a range incomplete; a turret that contributes none (zero-damage charge, zero multiplier, unloaded, or excluded) has no share of the average to withhold.
**Fix (or queued).** Strict per-attribute completeness ships: any counted turret (volley above zero) lacking a usable 54 or 158 suppresses only that range line (the other range, the volley, and every damage-per-second line still show), a present-but-unusable value marks that range incomplete without touching any excluded-item count, and weightless turrets cannot suppress anything. Both ranges stay hidden when there is no turret volley or the average is not positive, and all three new lines exist only where the underlying turret and launcher damage inputs exist — imported EFT (EVE Fitting Tool text format) pairings only; saved and DNA surfaces get none of them (design sections 4 and 6).
**Validation.** 824 tests pass at the integrator state (814 at base `88e6e25` plus ten new: nine pure, one rendering), with `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` all green, re-run fresh by the integrator. Catalogue byte-identity was re-proven fresh: stripping exactly `maxRange` and `falloff` from the regenerated `assets/sde/fitting_types.json` (3,519,738 bytes, SHA-256 `e25bc796…`) reproduces the `88e6e25` catalogue byte for byte (3,486,487 bytes, SHA-256 `904e7385…`; 25,818 rows, counts 1,157 / 681). The boundary diff against `88e6e25` touches six files (design, generator, catalogue, loader, `src/fitting/dps.rs`, `src/ui/fittings.rs`), and the deleted lines in the rendering file are confined to the replaced disclosure string, its doc comment, and the two test expectations that pin them. A fresh demo screenshot of the Fittings view (`Xvfb` + `scrot -o`, `startup_view` set to `Fittings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the selected "Demo Brawler" saved fitting; the damage block sits below the scroll fold in that harness and the new lines render only on the imported-EFT detail, so they are covered by the headless demo pins in `src/ui/fittings.rs` (sample EFT: `Volley: 47.8 damage`, `Turret optimal range: 1.2 km`, `Turret falloff range: 5.2 km`; saved and DNA demos gain no lines). The run log shows `fitting types loaded types=25818 skipped=0` and `portrait fetches suppressed in demo mode count=12` with no fetch-started line. Nothing in this slice is live-verified against EVE (all inputs are bundled data and pasted text).
**Generalizable rule.** An average over "the rows that have the attribute" is a different number from an average over the fitted set; pick one, say which in the disclosure, and never let a missing row stand in as zero.
**Refs.** `docs/volley-ranges-design.md` sections 2–11; DECISIONS 2026-11-17 volley-ranges entry.

## 2026-11-17

### A damage rate needs the ammunition paired, not merely present — only imported EFT text pairs a charge with a weapon, and the fighter cache disagrees with the SDE zip

**Author.** Muse Code (fitting-dps workflow, integrator)
**Context.** The base damage-per-second slice (`docs/fitting-dps-design.md`) had to decide where turret and launcher damage could honestly come from. A turret or launcher on its own carries a cycle time (and, for turrets, a damage multiplier) but no damage numbers; the damage lives on the loaded charge. So the whole question became whether any fitting shape Mimir holds actually pairs a specific charge with a specific weapon.
**Evidence.** Design sections 2.3 and 4, from bodies read during design and re-verified by the builders: saved fittings from EVE carry charges as unlinked cargo rows with no pointer to a weapon, DNA fitting links hold fitted modules only, and only imported EFT (EVE Fitting Tool text format) text pairs a charge with a weapon on the same line, read in the shipped code as `ImportedItem.charge` where the imported detail already holds the `ImportedFitting` (`src/fitting/dps.rs:157` `fitting_dps`, wired with `Some(&imported)` at `src/ui/fittings.rs:2342` and with `None` at the saved detail, `src/ui/fittings.rs:2648`). The shipped demo pins state the asymmetry numerically: the sample EFT import renders turret damage from its one listed charge plus a 2-unloaded line, while the sample DNA import renders a 3-unloaded line and no turret or launcher line at all. Separately, the fighter data source disagreed with itself: Firbolg I (type 23059) carries squadron size 9 and thermal damage 75 in the committed `dgmTypeAttributes` cache the generator reads, against size 6 and thermal 112.5 in the SDE zip's `typeDogma` for the same type (design sections 2.2 and 3.2, cache values pinned as generator oracles). A third source surprise of the same kind: the cache carries six negative damage source rows, including published type 53343 (Yoiul Festival Snowball) with a sole thermal row of -10.0, so the shipped `thermalDamage` count is 897, not the design-time 898 — the generator skips negative rows at load and counts them (`scripts/sde/generate_fitting_types_sde.py`), and the integrator amended design section 3.1 to say so.
**Mechanism.** Presence is not pairing. A charge sitting in a saved fitting's cargo proves the pilot owns that ammunition; it does not prove which weapon it was loaded in, or that it was loaded at all, so joining weapons to charges on cargo presence (or inventing a default charge) would manufacture a damage number from a guess and present it as data. The honest reading differs by surface because the pairing evidence differs by surface, which is why the same weapon yields a damage line on the imported-EFT detail and an unloaded count everywhere else. The cache-versus-zip drift is the same lesson inside the data layer: two bundled copies of nominally one dataset can carry different values for one type, so a generator must name one source as authoritative (here the committed cache, the same file already read for the `turretFitted` and `launcherFitted` markers) and pin the chosen values as oracles, never blend sources silently.
**Fix (or queued).** No default or cargo-inferred charge anywhere; turret and launcher damage ships only from an EFT-listed pairing, saved and DNA surfaces show an unloaded-weapons count instead, and no charge storage was added to saved fittings, synthesis, export, save, or delete (design sections 9 and 10). The cache is the named winner over the zip wherever they drift, with the Firbolg values locked as oracles.
**Validation.** 814 tests pass at the integrator commit (`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, `cargo build` all green, re-run fresh by the integrator: 799 at the base commit `82617be` plus 15 new). The catalogue byte-identity proof was re-run fresh by the integrator: stripping exactly the 28 new keys from the regenerated `assets/sde/fitting_types.json` (3,486,487 bytes, SHA-256 `904e7385…`) reproduces the base catalogue byte for byte (SHA-256 `b0b952cc…`), and a recount on the shipped file confirms 25,818 rows with `thermalDamage` on 897. The boundary diff against `82617be` is seven files with zero deleted lines under `src/`, so every existing fitting block and test is byte-identical. The integrator's fresh demo screenshot (`Xvfb` + `scrot -o`, Fittings view, `startup_view` set to `Fittings` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the demo Fittings view with the selected "Demo Brawler" fitting and its item rows; the damage block sits below the scroll fold in that harness and was not visually verified (no input automation), so it is covered by the headless demo pins in `src/ui/fittings.rs` instead, per the demo-screenshot entry below; the run log shows `fitting types loaded types=25818 skipped=0`, queues twelve `kind=type` requests drained under `portrait fetches suppressed in demo mode count=12`, and shows no fetch-started line, confirming demo still spawns nothing. Nothing in this slice is live-verified against EVE (all inputs are bundled data and pasted text), and `README.md` states the base-values limits.
**Generalizable rule.** A damage rate needs the ammunition paired, not merely present: never join a weapon to a charge on cargo presence, never invent a default charge, and when two bundled copies of one dataset disagree, name the winner and pin its values as oracles instead of blending them.
**Refs.** `docs/fitting-dps-design.md` sections 2.2, 2.3, 3.1–3.4, 7, 9, 10; `src/fitting/dps.rs`; DECISIONS 2026-11-17 fitting-dps entry.

## 2026-11-17

### A second surface on the same authorized set still needs its own budget — picker rows carry actions, so its cap cannot be shared with a display surface

**Author.** Muse Code (picker-icons workflow, integrator)
**Context.** The skill catalogue and the add-skill picker in the Skills view list the same 495 bundled skill types through the same search, so adding picker icons looked like a copy of the catalogue slice: same guard set, same 100-row cap shape. The guard half did copy exactly — the picker was already authorized by the catalogue's installed set and needed no guard change at all — but the budget half did not, because the two surfaces' rows do different things.
**Evidence.** `skill_picker_queues_icons_for_rendered_rows_only` (`src/ui/skills.rs`) pins the picker bound with hand literals from the bundled extract: a closed picker queues 0, `"turret"` queues exactly the sorted 12 ids (with Gunnery's absence proving queue rows, plan entry rows, and prerequisite lines still ensure nothing), a trained-to-5 row still queues its icon, an empty search queues exactly 100 of 495 and a narrowed search then reveals a beyond-cap row (101 total), `"ro"` at exactly 100 results queues all 100, `"pe"` at 101 queues its first 100, and a `Failed` icon leaves 99. The fixture's catalogue-isolation rule is what makes those counts attributable: with the catalogue search left empty on a fresh context, every catalogue group starts collapsed and queues 0, so every queued key in the test is provably the picker's even though both surfaces render in the same `show` call. The boundary diff against `8fc586a` is the design doc plus `src/ui/skills.rs` only, and its five deleted lines are the threaded call and signature lines, the uncapped iterator, and the plain first-line label — no test line deleted, no guard file touched.
**Mechanism.** A catalogue row is display only, so capping it costs a visible row; a picker row also carries the level buttons that add the skill to a plan, so the same whole-row cap costs an action until the search narrows, and a budget shared with the catalogue would let catalogue display spend silently remove those buttons. That asymmetry, not the icon volume, is what forced an independent picker-local `SKILL_PICKER_RENDER_MAX = 100` with the combined claim stated as a sum (200 ensures per frame, 495 distinct per session). It also flipped the empty-search reading: for the catalogue, empty search queues 0 because groups start collapsed, but the picker has no groups, so its empty search is the 495-row common case the cap exists for.
**Fix (or queued).** Independent picker cap with filter-before-cap ordering and the one "Showing 100 of N skills." disclosure, as designed in `docs/picker-icons-design.md` section 2; raising the cap or virtualizing is queued behind section 8's revisit conditions if users routinely lose a skill past row 100.
**Validation.** 799 tests pass at the integrator commit (`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, `cargo build` all green, re-run fresh by the integrator; the shipped catalogue, guard, prune, and landing tests named in design section 6 pass unmodified in that full run). The integrator's fresh demo screenshot (`Xvfb` + `scrot -o`, Skills view, `startup_view` set to `Skills` for the run and restored to `Dashboard` after, verified by re-reading the setting) shows the demo Skills view with the training queue text-only, the catalogue groups collapsed, and no skill plans in the demo seed, so the picker itself never opens in that harness — picker placeholder boxes were not visually verified (no input automation) and are covered by the headless queue tests instead, per the demo-screenshot entry below; the run log shows the one `[SKILLS] skill catalogue guard installed count=495` line and zero `kind=type` requests, confirming a closed picker and collapsed groups queue nothing and demo spawns nothing. Live verification of a fetched skill icon, and which bundled skills have icons at all, remain outstanding and are stated as such in `README.md`.
**Generalizable rule.** When a second surface reuses an existing authorization set, re-derive its volume budget from what its rows do, not from the first surface's numbers: a cap on rows that carry actions suppresses the actions too, and two surfaces sharing one budget can starve each other's controls.
**Refs.** `docs/picker-icons-design.md` sections 2, 3, 7, 8; DECISIONS 2026-11-17 picker-icons entry; LEARNINGS 2026-11-17 skill-icons static-arm and asset-icons volume-bound entries below.

### A guard arm backed by static data inverts the switch semantics the loaded arms trained us to expect — and the coverage question is the one thing membership cannot answer

**Author.** Muse Code (skill-icons workflow, integrator)
**Context.** Every earlier arm of the image fetch guard reads loaded character state, so "knowledge" is character-keyed: switching characters revokes asset and fitting knowledge until reload, mid-fetch landings drop after a switch, and prune keyed off the same guard drops those textures. The Skills catalogue has no loaded state to read — its rows are the bundled SDE extract's 495 skill types — so its arm is installed once at startup from static bundled data, and every one of those trained expectations flips.
**Evidence.** The shipped tests pin the inverted outcomes with the opposite locked expectations to their assets-side mirrors: `skill_catalogue_knowledge_survives_character_switch` and `skill_type_icon_landing_survives_character_switch` (a landing after a switch replaces the image instead of dropping it), `prune_keeps_skill_catalogue_type_icon_across_switch` (same texture handle across a switch and a search change; only a state with nothing installed drops it), and `removing_character_retains_skill_catalogue_icon` (active removal keeps both the entry and a still-true guard, where the assets retain test asserts the guard reads false afterwards). `skill_catalogue_membership_authorizes_only_bundled_skill_types` pins the boundary that matters instead of per-character loading: set length exactly 495, `34` and `999999` queue nothing, an uninstalled state and the search text `"3300"` authorize nothing. `skills_show_queues_icons_for_rendered_rows_only` pins the bound numerically (empty search exactly 0 because all groups start collapsed, `"e"` exactly 100 distinct keys including the 100th walk row and excluding a beyond-cap row, a `Failed` icon leaving exactly 99). Separately, no probe in the design or build shows which of the 495 skill types return an icon from EVE's image service — membership proves the id is a bundled skill, never that an icon exists — so icon-less skills sit at the shipped `Failed` blank box forever, named in design section 3(b) and the section 9 revisit triggers.
**Mechanism.** The guard's four arms now span two provenance classes with opposite lifetimes: per-character loaded state, whose revocation on switch is the privacy mechanism (nothing one character loaded authorizes a fetch under another), and app-lifetime static reference data, which names no character, arrives identically in demo and live modes, and is safe to share precisely because the set is closed at compile time and no user input can add to it. The fittings-catalogue rejection in the type-icons design was never "catalogues are barred" — its load-bearing reasons were per-surface facts (pasted text becomes ids there; the catalogue is 25,818 wide with unknown coverage), and only the coverage reason transfers to skills, in weakened blank-box form. Treating a prior rejection as a category ban would have shipped nothing; treating the assets arm as a template would have imported character-keyed revocation that is meaningless for static data.
**Fix (or queued).** The static arm as designed (installer, app-lifetime retention, removal-retain mirror, last-character clear-all as the one stated exception), with the coverage gap queued behind design section 9: a probe finding many icon-less skills makes the arm need an allowlist or removal.
**Validation.** 796 tests pass at the integrator commit (`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, `cargo build` all green, re-run fresh by the integrator; the ten shipped guard and prune tests named in design section 6 pass unmodified — the boundary diff against `d456f38` deletes no test line and touches none of the design section 6 explicitly-untouched files). The integrator's fresh demo screenshot (`Xvfb` + `scrot -o`, Skills view, `startup_view` set to `Skills` for the run and restored to `Dashboard` after) shows the catalogue's groups all collapsed with no skill rows visible — placeholder boxes inside expanded groups were not visually verified (no input automation in that harness) and are covered by the headless queue tests instead; the run log shows the one `[SKILLS] skill catalogue guard installed count=495` line and zero `kind=type` requests, confirming collapsed groups queue nothing and demo spawns nothing. Live verification of a fetched skill icon, and which bundled skills have icons at all, remain outstanding and are stated as such in `README.md`.
**Generalizable rule.** When a guard grows a source from a new provenance class, re-derive the lifetime semantics (revocation, landing, retention) from that class instead of copying the existing arms' behavior — and read a prior rejection's stated reasons one by one: the ones that still apply travel, the ones that were per-surface facts do not.
**Refs.** `docs/skill-icons-design.md` sections 3, 4, 7, 9; DECISIONS 2026-11-17 skill-icons entry; LEARNINGS 2026-11-17 asset-icons entry below (the fetch-bound half of this slice's bound) and market-icon prune entry below (the superset argument this arm extends to app lifetime).

## 2026-11-17

### A widget bound is not a fetch bound — virtualization would have let scrolling and re-filtering walk the whole asset list

**Author.** Muse Code (asset-icons workflow, integrator)
**Context.** The asset-icons design had to bound image fetches on the first icon surface whose row count is unbounded: a character's holdings can run to thousands of rows across many locations. The obvious egui answer is row virtualization, and the obvious cap shape is per location group; the design rejected both and shipped one global 100-row render cap instead.
**Evidence.** `docs/asset-icons-design.md` section 2, from the vendored egui 0.29.1 `ScrollArea::show_rows` body: uniform row height is assumed (this view interleaves location headings), the assets list already renders inside the shell's outer scroll area, and `show_rows` bounds only the widgets built per frame — scrolling and re-filtering would still ensure (and fetch) icons for every row ever scrolled past in the load, so "only visible rows fetch" would be true per frame and false per load. The shipped headless test `assets_show_queues_icons_for_rendered_rows_only` (`src/ui/assets.rs`) pins the honest claims numerically: 125 rows queue exactly 100, a second frame queues nothing new, 60 + 60 rows across two groups still queue exactly 100 (a per-group cap would queue 120 and fail), and a search for the 125th row queues exactly one more key because filtering runs before the cap.
**Mechanism.** A fetch bound must constrain the set of ids that can reach the network over the data's lifetime, not the number of widgets a frame builds; those coincide only when ensure equals the rendered set and the rendered set itself is capped. Two separate claims keep the slice honest: per frame, the capped iterator bounds ensures at 100 rows; per load, the guard is a superset (all loaded types), so an explicit re-filter can legitimately fetch icons beyond the first window — stated plainly in the design instead of claimed away as a hard per-session 100.
**Fix (or queued).** Global `ASSETS_RENDER_MAX = 100` with one shared remaining budget, filter-before-cap ordering, and a "Showing 100 of N items." disclosure (design sections 2 and 9 revisit the cap if real holdings make the window feel wrong; any virtualization follow-up must re-derive a per-load fetch bound).
**Validation.** 788 tests pass at the integrator commit (`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, `cargo build` all green; the five shipped guard tests named in design section 6 pass unmodified, and all nine new asset-icon tests pass). The integrator's fresh demo screenshot (`Xvfb` + `scrot -o`, Assets view, `startup_view` set to `Assets` for the run and restored to `Dashboard` after) shows a faint blank placeholder box left of each of the six demo rows under three text-only location headings, with no raw item numbers and no "Showing" line — placeholder-path evidence only, per the demo-screenshot entry below; the run log queues exactly five `kind=type` requests (ids 587, 36, 34, 681, 35), drains them under `portrait fetches suppressed in demo mode count=5`, and shows no fetch-started line, confirming demo still spawns nothing. Live verification of a fetched asset type icon against the real service remains outstanding and is stated as such in `README.md`.
**Generalizable rule.** When a bound is claimed for a side effect (fetches), measure the set that can trigger the side effect over the data's whole lifetime, not per frame; a rendering optimization that only defers the triggers is not a bound on their total.
**Refs.** `docs/asset-icons-design.md` sections 2, 7, 9; DECISIONS 2026-11-17 asset-icons entry; LEARNINGS 2026-11-17 market-icon prune entry below (the same superset argument on a one-icon surface).

## 2026-11-17

### Prune drops only the texture, never the image — reselecting a market item re-uploads once and refetches never

**Author.** Muse Code (market-icon workflow, integrator)
**Context.** The market-icon design had to prove the new one-icon header would not thrash: the Market view now prunes the shared texture cache every frame and ensures exactly one type icon, so the obvious worry is prune evicting the selected icon's texture and the next frame re-uploading or refetching it forever — and the symmetrical worry that selecting another item and coming back costs a network fetch.
**Evidence.** `docs/market-icon-design.md` section 3: `PortraitImageCache::prune` (`src/ui/portraits.rs`) retains textures by the same `image_id_known` union the fetch guard uses, which is a superset of the header's one-icon ensure set, and prune removes only the cache's GPU texture entry — the decoded `Ready` image stays in `AppState::portraits`. The shipped test `prune_keeps_selected_market_type_icon_across_switch` (`src/ui/portraits.rs`) pins both directions by texture handle identity: the same handle survives prune across a fittings selection change and a character switch while the item stays selected (no re-upload), and selecting another item empties the cache on the next prune; coming back to the first item then re-uploads from the retained `Ready` image with no new request queued.
**Mechanism.** The pipeline keeps two lifetimes that are easy to conflate: the image bytes in app state (kept while any guard source still knows the id, dropped only by character-removal retain) and the GPU texture in the view cache (pruned per frame by the same guard). Because both lifetimes key off the one guard, prune can never be narrower than ensure, so no per-frame cycle exists; and because texture upload is derived from state, losing a texture is cheap and losing bytes is the only event that could ever refetch. The one asymmetry the design records honestly instead of claiming away: a fetch that lands after its id stopped being known is dropped whole while the key is still `Loading`, and ensure queues only `NotRequested` keys, so that key can sit `Loading` with nothing in flight — inherited shipped semantics for every image kind, named in the design's revisit conditions, not silently fixed by this slice.
**Fix (or queued).** No fix needed for the thrash question — the superset proof plus the handle-identity test is the fix's evidence. The stuck-`Loading` asymmetry stays queued behind the design's revisit clause: a general fix (for example clearing a `Loading` entry when its landing is dropped as unknown) changes every kind's landing semantics and wants its own design.
**Validation.** 779 tests pass at the integrator commit (`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, `cargo build` all green; the three shipped fittings type-icon tests pass unmodified). The integrator's demo screenshot (headless `xvfb-run` + `scrot`, Market view, `startup_view` restored to `Dashboard` after) shows the blank 64pt placeholder box left of the demo selection's heading "Tritanium" with "Region: The Forge" as its second line and Refresh below, while the quick-pick list above stays text-only — placeholder-path evidence only, per the demo-screenshot entry below; the run log queues exactly one `kind=type id=34` request, drains it under `portrait fetches suppressed in demo mode count=1`, and shows no fetch-started line, confirming the demo selection spawns nothing. Live verification of a fetched market type icon against the real service remains outstanding and is stated as such in `README.md`.
**Generalizable rule.** When a per-frame prune and a per-frame ensure share one guard, state the superset relation explicitly and pin it by resource identity (same handle), not by absence of visible flicker; and keep "texture dropped" and "bytes dropped" as separate claims, because only one of them can cost a network fetch.
**Refs.** `docs/market-icon-design.md` sections 2, 3, 9; DECISIONS 2026-11-17 market-icon entry; LEARNINGS 2026-11-17 shared-renderer entry below (the fittings-side guard lesson this slice mirrors on the market side).

## 2026-11-17

### A shared renderer is a guard bypass waiting to happen — the fittings item renderer's second caller renders user-pasted ids

**Author.** Muse Code (type-icons workflow, integrator)
**Context.** The type-icons slice adds icon ensures to the fitting item rows. The obvious edit is inside `render_fitting_items` (`src/ui/fittings.rs`), the one function that draws those rows — which is also called for the imported fitting built from user-pasted EFT or DNA text, a caller neither discovery pass had flagged.
**Evidence.** `docs/type-icons-design.md` sections 3 and 6: the imported detail reuses the saved detail's row renderer, so an ensure placed in the shared body would queue fetches for whatever type ids a pasted fitting names, even though the state guard (`fitting_type_known`, loaded saved fittings only) would reject most of them — and would silently admit any pasted id that happened to match a saved fitting. The shipped gate is structural: `render_fitting_items` takes `type_icons: Option<(&mut AppState, &mut PortraitImageCache)>`, the saved caller passes `Some`, the imported caller passes `None` and renders byte-identical text rows.
**Mechanism.** A fetch guard checks whether an id may be asked for; it cannot check why the code is asking. When one renderer serves both an EVE-sourced surface and a user-input surface, "the guard will sort it out" quietly turns user input into a fetch source for the intersection set, and the volume bound ("only what saved fittings name") stops being a property of the surface and becomes a coincidence of the data.
**Fix (or queued).** Gate at the call site, not only at the guard: the `None` path never ensures, and headless tests pin both directions — rendered-rows-only ensures exactly `[(Type, 2048), (Type, 34)]` through `Some`, an empty queue and cache through `None`, and exactly 100 queued from 101 rows at the render cap (`src/ui/fittings.rs`).
**Validation.** 771 tests pass at the integrator commit. The integrator's demo screenshot (headless `xvfb-run` + `scrot`, Fittings view, `startup_view` restored to `Dashboard` after) shows blank placeholder boxes left of the selected "Demo Brawler" ship line ("Rifter") and its item rows while the fittings list above stays text-only — placeholder-path evidence only, per the demo-screenshot entry below; the run log queues twelve `kind=type` requests (ids 587, 2048, 2049, 1225, 2050, 1535, 28270, 2456, 2457, 636, 34, 35), drains them under `portrait fetches suppressed in demo mode count=12`, and shows no fetch-started line, confirming demo still spawns nothing. Live verification of a fetched type icon against the real service remains outstanding and is stated as such in `README.md`.
**Generalizable rule.** Before adding a side effect to a shared renderer, enumerate its callers and classify each one's input provenance; a downstream guard is a second line of defense, never a substitute for not asking on behalf of user-pasted input.
**Refs.** `docs/type-icons-design.md` sections 3, 5, 6; DECISIONS 2026-11-17 type-icons entry above; LEARNINGS 2026-11-17 image-service-fallback entry below (the guard this gate sits in front of).

## 2026-11-17

### A kind key names the entity kind, not the endpoint it happens to fetch from — faction logos sharing the corporations endpoint still got their own kind

**Author.** Muse Code (standing-icons workflow, builder B)
**Context.** The standings list renders rows keyed by an ESI `from_type` string (`faction`, `npc_corp`, `corporation`, `agent`, `alliance`, empty). Faction ids are served real logos by the image service's corporations endpoint (admitted in the retired Flutter app's `FactionLogo`), so the cheapest implementation keyed faction standings as `ImageKind::Corporation`: same endpoint, same bytes, zero new match arms. Design had to settle whether the kind names the entity or the fetch path.
**Evidence.** `src/portraits.rs`: the kind is part of every cache/texture/log key; a comment states the same number in two kinds is two different entities. The one piece of live proof is disjointness today: faction ids at 500001–500002 against corporation ids at 1000006/1000125/1000166 — an allocation observation, not a contract anything enforces. The branch cost of a fourth kind is bounded and compiler-checked: 8 exhaustive-match arms.
**Mechanism.** Reusing `Corporation` stores faction bytes under `corp-500001_64.png` and logs `kind=corporation id=500001` — false statements about what the bytes depict, baked into cache files that outlive the code. And guard precision degrades in the same direction: every current and future corporation source would equally authorize a faction number, because the guard cannot tell the two apart once the key conflates them. Disjoint numeric ranges made the collision impossible today and silent tomorrow.
**Fix (or queued).** New `ImageKind::Faction` with its own key, cache file (`faction-{id}_64.png`), texture name, and standings-only guard arm; the URL helper is faction-named but corporations-pathed, with a doc comment saying so, so a future real factions endpoint is a one-body change and no cache file ever moves.
**Validation.** Design sections 3–5 with the rejection reasoning; tests pin the four-kind cache distinctness, the corporations-path faction fetch, cross-kind cache isolation, the guard truth table with cross-kind rejection, and same-number texture separation (`src/portraits.rs`, `src/app/state.rs`, `src/app/shell.rs`, `src/ui/portraits.rs`); 752 tests pass at the integrator commit. The integrator's demo screenshots (headless `xvfb-run` + `scrot`, Characters view, both demo characters, `startup_view` restored to `Dashboard` after) show blank placeholder boxes left of "Caldari State" and "CONCORD" for both characters while the second character's "Demo Alliance" row under Other stays flush-left text-only with no box — placeholder-path evidence only, per the demo-screenshot entry below; the run log queues `kind=faction id=500001` and `kind=corporation id=1000125`, drains them under `portrait fetches suppressed in demo mode count=5`, and shows no fetch-started or landed line, confirming demo still spawns nothing. Live verification of a fetched standings icon against the real service remains outstanding and is stated as such in `README.md`.
**What surprised.** That the strongest argument was not a bug: with today's id ranges reuse is observationally identical. The decision paid a one-time mechanical cost to avoid a permanent dishonesty in keys, logs, and the guard's meaning.
**Generalizable rule.** When a key system's name doubles as a truth claim, keep the key honest about the entity, not the transport: a shared endpoint never justifies conflating two entity kinds, and numeric-range luck is never a contract.
**Refs.** `docs/standing-icons-design.md` sections 3–5; LEARNINGS 2026-11-17 image-service-fallback entry (the guard this kind extends).

## 2026-11-17

### The EVE image service never errors on an unknown id — it returns 200 with a shared fallback — so logo honesty must be enforced at the request, not read off the response

**Author.** Muse Code (logos workflow, integrator)
**Context.** The logos slice repeats the portraits honesty rule for corporation and alliance logos: show only the exact entity's real logo, otherwise an honest placeholder. The natural implementation reads failure off the response (error status, undecodable body), which is exactly how the shipped portrait pipeline already decides `Failed`.
**Evidence.** The design probe against the live image service (`docs/logos-design.md` sections 4–5, observed during design, never re-probed in tests): `corporations/999999999/logo?size=256` returned HTTP 200 with a 12,832-byte PNG byte-identical to `corporations/999999998/...`; `alliances/999999999/logo?size=256` returned 200 with a 13,097-byte PNG byte-identical to the demo-fixture alliance id `99000001`. Unknown ids get one shared fallback image per kind, not a 404. The same probe grounds the rest of the shape: logos are `image/png` with real alpha (corporation 1000166 at 256px: 46,012 fully transparent of 65,536 pixels), and a dense alliance logo measures 8,807 bytes at size 64 against 1,052,037 bytes at 512 — over the pipeline's 1 MiB cap.
**Mechanism.** A fallback that arrives as a successful, decodable response is indistinguishable from a real logo by anything in the response itself. Any code path that can request an arbitrary id (typed, searched, stale, or invented) can therefore receive the shared fallback and present it as that entity's logo — a fabricated attribution produced by correct-looking success handling. Status-code honesty works for portraits only because portrait requests were already restricted to known character rows; the restriction, not the status check, was doing the work all along.
**Fix (or queued).** The slice makes the restriction explicit and kind-aware in one place: `AppState::image_id_known` (`src/app/state.rs`) is the single definition of a fetchable id (a known character row, or the loaded active-character public info; ids at or below zero ignored), shared by the request queue and the shell landing, with no bypass. For ids that pass it, the 200 answer is authoritative for that exact id; hash-pinning the fallback artwork and pre-flight existence checks were considered and rejected (design section 5). No test asserts that an unknown live id fails, because it does not — the mock-server 404 test documents only the status mapping, with a comment saying so.
**Validation.** Unit tests pin the guard by source (row vs loaded detail vs neither), same-numeric-id independence across kinds, wrong-kind and unreferenced landing rejection, oversized and poisoned bodies, and RGBA alpha survival through decode (`src/portraits.rs`, `src/app/state.rs`, `src/app/shell.rs`, `src/ui/portraits.rs`); 739 tests pass at the integrator commit. The integrator's demo screenshot (headless `xvfb-run` + `scrot`, Characters view, `startup_view` restored to `Dashboard` after) shows the blank placeholder box left of "Demo Defense League" and no alliance row — placeholder-path evidence only, per the demo-screenshot entry below; its log queues `kind=corporation id=1000166` and shows no fetch-started or landed line, confirming demo still spawns nothing. Live verification of a fetched logo against the real service remains outstanding and is stated as such in `README.md`.
**What surprised.** That the failure mode to design against was success: every other hazard in the pipeline (oversized, undecodable, poisoned cache) announces itself, while the one that would put a wrong logo on screen returns 200 with valid PNG bytes.
**Generalizable rule.** For any external service, probe the unknown-key case before designing the error path: if the service answers unknown keys with a successful generic payload, honesty becomes a request-provenance property, and the fix is one guard on which keys may be asked for — not any amount of response inspection.
**Refs.** `docs/logos-design.md` sections 4, 5, 6, 12, 14; DECISIONS 2026-11-17 corporation-and-alliance-logos entry above; LEARNINGS 2026-11-17 demo-screenshot entry below (the portraits precedent for what a demo screenshot can prove).

### An unwired service's body is evidence for its core predicate only — its never-called variants carry no shipped semantics

**Author.** Muse Code (skill-prereqs workflow, integrator)
**Context.** The skill-prerequisites slice had to decide warning semantics: trained levels only, or trained plus earlier plan entries; direct edges only, or the full transitive closure; and what to do about cycles. The retired Flutter app (commit `ed698d3`) contained a `SkillPrerequisiteService` that looked like the obvious porting source for all three questions.
**Evidence.** `docs/skill-prereqs-design.md` sections 2–3, from bodies read during design via `git show ed698d3:`: the service existed but was never wired into the Flutter UI, and its warning dialog was never instantiated. Inside it, `getUnmetPrerequisites` states the core predicate (trained level below required level, missing trained row = 0, and a `targetLevel` parameter it accepts and ignores); `filterPrerequisitesNotInPlan` (plan-order crediting) is level-blind and untested; `getAllPrerequisites` (transitive closure) has zero production call sites. The shipped Rust `plan_progress` independently uses the same trained-map rule (missing = 0).
**Mechanism.** Code that never ran in production has never been corrected by production: its edge cases (levels, cycles, ordering) were never exercised by a user, a test, or a caller, so its variants record what someone once sketched, not what the product decided. Only the parts corroborated by a second, shipped witness — here the core predicate, matched by `plan_progress` — carry semantics safe to port.
**Fix (or queued).** `src/skills/prereqs.rs` implements exactly the corroborated core: trained-only, direct-only, no `target_level` parameter, cycle safety by construction (no recursion, no visited set). Plan-order crediting and transitive closure are recorded as rejected in design sections 14–15, revisit-able only under a separately grounded design.
**Validation.** Tests E1–E9 in `src/skills/prereqs.rs` pin the core and the exclusions (including the direct-only proof that a transitive ancestor is never reported, and target-level invariance); the integrator boundary diff against 27f79d2 confirms no `add_enabled`, `SkillPlanAction`, `validate_plan`, or `plan_progress` line changed; all 718 tests pass at the integrator commit.
**What surprised.** The presence of a complete-looking service suggested a straight port. Its completeness was the trap: the most elaborate variants were precisely the ones with no production witness.
**Generalizable rule.** When porting from dead or unwired code, grade each behaviour by its witnesses — production call sites, tests, a second shipped implementation — and port only the graded core; treat never-called variants as unmade decisions, not as precedent.
**Refs.** `docs/skill-prereqs-design.md` sections 2, 3, 14, 15; `src/skills/prereqs.rs`; DECISIONS 2026-11-17 skill-prerequisite-warnings entry above.

### The retired Flutter app's skill-point formula understates rank-1 training by 33x; the SDE cumulative form is the one the committed fixtures prove

**Author.** Muse Code (skill-plans workflow, integrator)
**Context.** The skill-plans slice shows per-entry and total training-time estimates, so it needs skill points per level and a training rate. The retired Flutter app (commit `ed698d3`) carried both formulas, and porting them unchanged was the obvious-looking move.
**Evidence.** `docs/skill-plans-design.md` sections 3.1–3.3, from bodies read during design: Flutter priced each level at `250 × rank × 2^(L-1)` SP summed, giving 7,750 SP for rank 1 level 0→5, and its tests pin that family (7,750 / 38,750 / 2,000). SDE dogma attribute 275 instead states skill points as `250 * skillTimeConstant * sqrt(32)^(skillLevel - 1)`, which read as the cumulative total at which a level is reached gives rank-1 levels of 250 / 1,414 / 8,000 / 45,255 / 256,000 SP. Every rank-1 row in the committed demo fixtures matches the SDE cumulative values (8,000 / 45,255 / 256,000), and the queue `level_start_sp`→`level_end_sp` pairs confirm the cumulative reading — so Flutter reproduces none of the fixture totals and understates rank-1 0→5 by a factor of 33 (7,750 against 256,000).
**Mechanism.** The Flutter calculator summed per-level increments of the wrong geometric ratio: doubling per level instead of multiplying by `sqrt(32)` per level, and treating the result as increments to sum rather than the cumulative total ESI reports. Its own tests pinned the wrong numbers, so the test suite could never catch it — the tests encoded the formula, not the game.
**Fix (or queued).** The Rust slice implements the SDE cumulative form with round-once-on-the-full-product (`src/skills/training.rs`), bans the Flutter literals from test expectations, and derives every test expectation by hand from the SDE text with the arithmetic in comments. The training rate (primary + secondary/2 SP per minute, ceiling to whole minutes, per entry at its own attribute pair, totals as the sum of per-entry times) is kept because two independent in-repo witnesses agree on it; Flutter's 20/20 attribute default and rank-1 fallback are rejected, so missing inputs show estimates as unavailable instead of guessed.
**Validation.** T1–T9 in `src/skills/training.rs` pin the SDE literals (including the round-once distinguisher: rank-5 level 4 is 226,274, where rank-1-base-times-5 would give 226,275), and all 699 tests pass at the integrator commit. Live verification of the SP table against a real EVE account has not happened and stays recorded as an open risk in design section 15.
**Generalizable rule.** A ported formula is a claim — check it against committed data fixtures before shipping its numbers, especially when the old code's tests pin the formula's own outputs and so cannot falsify it.
**Refs.** `docs/skill-plans-design.md` sections 3, 6, 14, 15; `src/skills/training.rs`; DECISIONS 2026-11-17 skill-plans entry below.

### A demo-mode screenshot of a network-backed visual feature proves only the placeholder path, never the fetched rendering

**Author.** Muse Code (portraits workflow, integrator)
**Context.** The portraits slice renders EVE character portraits fetched from the public image service, with demo mode deliberately making zero network calls. The integrator verification included a headless screenshot (`xvfb-run` + `scrot`) of the Characters view in `--demo` mode, with `startup_view` set to `Characters` in `~/.local/share/mimir/mimir.db` for the run and restored to `Dashboard` after.
**Evidence.** The screenshot (2026-11-17 integrator run) shows the switcher list initials (A / M), the detail 96px initial, and the status line "Portraits are not fetched in demo mode." — every one of those is the placeholder path by design. The run log shows `[PORTRAIT] portrait fetches suppressed in demo mode count=2` and no fetch, decode, cache, or texture-upload lines, because the shell drain never spawns in demo mode (`decide_portrait_start`, `src/app/shell.rs`). The fetched rendering path (mock-server fetch, decode caps, cache-first second fetch, keyed landing, upload-once texture) is instead proven by the unit tests in `src/portraits.rs`, `src/app/state.rs`, `src/app/shell.rs`, and `src/ui/portraits.rs` — 675 tests total at the integrator commit.
**Mechanism.** Demo mode's zero-network guarantee and the honesty rule (only `Ready` for that exact character id renders an image) together mean a demo screenshot structurally cannot contain a real portrait. It can prove the placeholder layout, the status wording, and that suppression fired; it says nothing about whether a live fetch decodes, lands, and uploads correctly.
**Fix (or queued).** None needed: report the screenshot as placeholder-path evidence only, and cite the mock-server and headless-render tests for the fetched path. Live verification against the real EVE image service remains outstanding and is stated as such in `README.md`.
**Validation.** Screenshot inspected directly this session; `startup_view` confirmed restored to `Dashboard` in the database after the run; all four gates green (`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, `cargo build`).
**Generalizable rule.** Match the visual evidence to the mode that can produce it: a screenshot taken in a no-network mode is evidence about placeholders and suppression, not about the fetched rendering, and presenting it as the latter overclaims exactly the path the mode disables.
**Refs.** `docs/portraits-design.md` sections 3, 5, 6, 9; DECISIONS 2026-11-17 character-portraits entry above.

### A dogma attribute can carry negative modifier values on non-ship rows, so a global negative check in the catalogue generator is not safe for every attribute set

**Author.** Muse Code (nav-targeting workflow, integrator)
**Context.** The navigation and targeting slice adds dogma attributes 600, 70, 552, 76, 564, 208–211, and 192 to the bundled fitting-types catalogue. The design said the generator's fail-loud checks (a negative or non-integral value aborts regeneration) should follow the existing shape, which checked every row in the cache globally because no earlier slice had ever hit a negative.
**Evidence.** `docs/nav-targeting-design.md` section 3, and the catalogue builder's report during the slice: attribute 76 `maxTargetRange` carries `-20000.0` on four category-32 subsystem rows (45610, 45613, 45616, 45619). Those rows are subsystem modifiers, never emitted as ship values, but a global negative check fails regeneration on them. A scan during the slice verified every earlier slice's wanted set contains zero negatives across the whole cache, which is why the global shape never failed before. Integrator re-run this session: the regenerator reports `nav_targeting_keys warpSpeedMultiplier=404 agility=404 signatureRadius=404 maxTargetRange=404 scanResolution=390 scanRadarStrength=404 scanLadarStrength=404 scanMagnetometricStrength=404 scanGravimetricStrength=404 maxLockedTargets=404 mass=404` and reproduces the committed catalogue byte-identically (SHA-256 `b0b952cc…`, 3,341,334 bytes).
**Mechanism.** The same attribute id means a base value on a published ship row and a modifier on a subsystem row; the sign is legitimate on the modifier row. A validation that ignores which rows can actually be emitted therefore rejects good data, while a validation scoped to emittable rows still fails loud on anything that could render.
**Fix (or queued).** In `scripts/sde/generate_fitting_types_sde.py` the negative and integral checks for the navigation set are gated on published category-6 membership; duplicate, unparseable, and non-finite checks stay global. Every row that can be emitted is validated exactly as before.
**Validation.** Regeneration succeeds and is byte-identical to the committed catalogue; the loader invariants in `src/names/fitting_types.rs` (finite, `>= 0.0`, integral max locked targets, category-6-only) hold over the bundled catalogue in the Rust test suite.
**Generalizable rule.** Scope a fail-loud data check to the rows that can reach the output: an attribute's values on rows outside the emission set can be legitimate modifiers with different sign and shape, and a global check that was safe for earlier attribute sets is an assumption to re-verify per set, not a precedent to copy.
**Refs.** `docs/nav-targeting-design.md` sections 2–4; DECISIONS 2026-11-17 navigation-and-targeting entry below.

### Dogma attribute 47 `slots` looks like a hardpoint signal but disagrees with the fitted effects on both sides

**Author.** Muse Code (slot-layout workflow, integrator)
**Context.** The slot-layout slice shows turret and launcher hardpoints used against the hull's base hardpoints. Deciding which fitted modules consume a hardpoint needed a grounded signal: dogma attribute 47 `slots` is the obvious-looking candidate, and effects 40 `launcherFitted` / 42 `turretFitted` ("Requires a … hardpoint") are the alternative.
**Evidence.** `docs/slot-layout-design.md` section 2, from bodies read during design against the pinned SDE and committed CSV caches: attribute 47 has 853 published carriers but 51 false positives (Bomb Launcher I among them — a launcher by name that consumes no launcher hardpoint) and 3 false negatives against the effect sets; effects 40/42 have 147/658 published carriers, every one also carrying high-slot effect 12, with zero overlap between them. Integrator re-run this session: the regenerator reports `turretFitted=658 launcherFitted=147` and reproduces the committed catalogue byte-identically (SHA-256 `f54481d1…`, 3,234,754 bytes).
**Mechanism.** Attribute 47 is a legacy generic slot count that CCP still stamps on types whose fitting behaviour moved to effects; it neither implies nor is implied by hardpoint consumption. Name-based guessing fails the same way (Bomb Launcher I). Only effect membership states the requirement the game enforces.
**Fix (or queued).** The catalogue emits sparse true-only booleans `turretFitted` (effect 42) and `launcherFitted` (effect 40) with no category gate, so the 4 category-66 Standup launchers count; attribute 47 is never read (barred in `src/fitting/slot_layout.rs:28` and `src/names/fitting_types.rs:134`), and extending `slotEffects` to carry 40/42 was rejected because the loader invariant `slot_effects.len() <= 1` would break. A high-slot module missing from the catalogue is excluded from both hardpoint counts with a disclosed count, never treated as using no hardpoint.
**Validation.** Generator oracles pin the marker sets (including the category-66 carriers); `src/fitting/slot_layout.rs` test `hardpoint_counting_follows_markers` and the DEMO/DNA pins (DNA `587:2889;2:499;1::` → high 3, turret 2, launcher 1) prove the marker path end to end; all 630 tests pass at the integrator commit.
**Generalizable rule.** When an attribute and an effect both look like the signal for the same fact, measure the disagreement in both directions before choosing: false positives and false negatives against the enforced mechanism (the effect) disqualify the attribute, however suggestive its name.
**Refs.** `docs/slot-layout-design.md` sections 2, 3, 10; DECISIONS 2026-11-17 slot-layout entry below.

## 2026-11-16

### Flutter read the rig-cost attribute 1153 as the ship calibration capacity, so a magic 400 fallback silently won on every hull

**Author.** Muse Code (rig-calibration workflow, integrator)
**Context.** The rig-calibration slice shows base rig calibration used against the ship's base calibration output in both fitting details. The retired Flutter app computed calibration but never displayed it, and its capacity number was wrong on every hull whose real capacity is not 400.
**Evidence.** `docs/rig-calibration-design.md` section 2.3, from bodies read directly during design: at `ed698d3`, `lib/features/fitting/domain/dogma_attributes.dart:73` defines only `upgradeLoad = 1153` (the per-rig cost) with no constant for 1132 anywhere in the tree; `lib/features/fitting/domain/dogma_engine.dart:837` computes the ship's `calibrationMax` by reading that same 1153 on the ship with a magic `400` fallback, so the fallback won on every hull; `lib/core/sde/sde_service.dart:1062,1095-1097` reads 1153 as each type's cost (the correct side) with absent silently defaulted to 0; no display exists (`stats_panel.dart` has no calibration row, `fitting_editor.dart:397-427` documents a calibration readout it never builds) and no Flutter test asserts the used/max values. In the current SDE caches, dogma 1132 `upgradeCapacity` is present nonzero on 381 ships — `400.0` on 327, `350.0` on 41, `1.0` on 12 shuttles/prototypes, `300.0` on 635 Opux Luxury Yacht — with a present explicit `0.0` on 20 more ships (588 Reaper among them) and no row at all on exactly 3; dogma 1153 `upgradeCost` is the per-rig cost; dogma 560 is a decoy and is never read.
**Mechanism.** One attribute was used for both sides of a used/capacity pair, and ships carry no 1153 row, so the read always missed and the `400` fallback always supplied the "capacity". Because 400 is also the modal true capacity (327 of 381 ships), the wrong number looked right almost everywhere — and because the value was computed but never displayed, nobody ever saw the cases (350, 300, 1, 0) where it was wrong. A fallback equal to the most common true value makes a wrong-side read indistinguishable from truth on casual checks.
**Fix (or queued).** The Rust slice reads capacity only from dogma 1132 `upgradeCapacity` (category-6 ships, sparse key, absent stays absent — no fallback of any kind) and cost only from dogma 1153 `upgradeCost` (rig-slot effect 2663), sums base costs in `src/fitting/calibration.rs`, and displays the block in both fitting details with unknown-cost rigs excluded with a disclosed count, never zeroed.
**Validation.** The generator validates `CALIBRATION_ORACLES` including non-400 pins (350.0/300.0/1.0 and the present explicit 0.0 on 588) and fails without writing on any mismatch; re-running it reproduces `assets/sde/fitting_types.json` byte-identically (SHA-256 `26e587e6…`, 3,176,352 bytes); hand-derived oracles in `src/fitting/calibration.rs` pin the same non-400 capacities end to end.
**Generalizable rule.** An attribute used for both sides of a used/capacity pair hides a wrong-side read behind its own fallback. Pin a non-modal capacity value (350.0/1.0/0.0) as the oracle, because the modal 400.0 cannot distinguish truth from fallback — and treat any "capacity" that equals its fallback on every input as unproven, not as correct.
**Refs.** `docs/rig-calibration-design.md` sections 2, 3, 9; DECISIONS 2026-11-16 rig-calibration entry below.

### The "38" collision: dogma attribute 38 `capacity` has zero per-type rows, Flutter's key 38 was synthesized item volume, and dogma 161 `volume` is a decoy

**Author.** Muse Code (bay-capacities workflow, integrator)
**Context.** The bay-capacities slice shows cargo, drone, and fighter bay usage against base ship capacities in both fitting details. Three different things share nearby numbers, and confusing them is the slice's one real correctness trap: dogma attribute 38 is named `capacity`, the retired Flutter app stored item volume under a synthesized dogma key 38, and dogma attribute 161 is named `volume`.
**Evidence.** `docs/bay-capacities-design.md` section 2.2, from bodies read directly during design: `dgmTypeAttributes.csv.bz2` contains zero rows with attribute id 38 anywhere, while every one of the 404 category-6 (ship) catalogue rows has an `invTypes.capacity` value (587 Rifter `140.0`, 638 Raven `830.0`, three present-zero `"0E-10"` rows including 670 Capsule); dogma 161 has only 6 `dgmTypeAttributes` rows (structure/container types), none in the catalogue; Flutter at `ed698d3` stored `invTypes.volume` under a synthesized key 38 (`dogma_attributes.dart:47`, generator comment "drone bay usage needs it as attribute 38"). Ship drone capacity (283), drone bandwidth (1271), fighter capacity (2055), and per-drone bandwidth cost (1272) are genuine `dgmTypeAttributes` rows. The generator pins these facts with `BAY_ORACLES` (`scripts/sde/generate_fitting_types_sde.py:287`, checked at `:826`), and `src/fitting/bay_usage.rs:119` (`bay_usage`) reads only the catalogue keys built from those sources.
**Mechanism.** An attribute's name in `dogmaAttributes.jsonl` proves the attribute exists as a definition; it does not prove any type carries a value for it. Ship cargo capacity lives in the `invTypes` table as a column, not in dogma at all, and per-type volume likewise. Flutter's key 38 made the trap worse: the same number meant item volume in its synthesized map and `capacity` in the dogma definition list, so a reader who trusted either name or number alone would read volume as capacity or look for capacity rows that do not exist.
**Fix (or queued).** The generator reads ship cargo capacity only from `invTypes.capacity` and per-type volume only from `invTypes.volume`, each under its own catalogue key; dogma 38 and 161 are never read. Absent stays distinct from present `0.0` throughout (2863 Primae has no 283/1271 rows and shows no drone bay numbers, not zeros).
**Validation.** `BAY_ORACLES` present and absent pins pass at generation time; re-running the generator reproduces `assets/sde/fitting_types.json` byte-identically (SHA-256 `999f8d62…`); the hand-derived oracles in `src/fitting/bay_usage.rs` (for example Tristan with five Warrior II at 25/40 m3 and 25/25 Mbit/sec) pass in the test suite.
**Generalizable rule.** A named attribute with zero per-type rows is not a data source. Before trusting an attribute name, count its `dgmTypeAttributes` rows and check the `invTypes` columns — EVE keeps some first-class per-type facts as table columns, and a synthesized key in a retired implementation can reuse a real attribute's number for a different fact.
**Refs.** `docs/bay-capacities-design.md` sections 2.2, 3.3 and 9; DECISIONS 2026-11-16 bay-capacities entry below.

### A coinciding constant is not a shared grounding: the capacitor peak factor comes from differentiating the simulator's own closed form, not from the shield line

**Author.** Muse Code (peak-recharge-rates workflow, integrator)
**Context.** The peak recharge rates slice adds base peak shield recharge (HP/s) and peak capacitor recharge (GJ/s) to the existing "Ship (base values)" block, computed only from the bare hull's base capacity and base full recharge duration shipped by the earlier base-stats and recharge-duration slices, with no fitted modifiers, no recharge curve, and no capacitor stability simulation.
**Evidence.** `docs/peak-recharge-rates-design.md` section 2 (the retired Flutter app at `ed698d3` has a production shield peak, `dogma_engine.dart:891-894`, `2.5 * shieldHp / (shieldRecharge / 1000)`, but no capacitor peak constant anywhere in production code — `dogma_engine.dart:914-933` is stability-only and a `2.5` grep over `lib/` hits only the shield line); `cap_simulator.dart:73-75` and `:272-275` (closed form `cap = ((1 + (sqrt(cap/C) − 1) * exp(−dt/tau))²) * C`) with `tau = rechargeMs / 5.0` at `:116`; `cap_simulator_test.dart:18-19` ("a peak recharge of 2.5 * 1000 / 60 = 41.7 GJ/s") and `:75` ("the peak recharge (0.5 * 1000 / 12s = 41.7 GJ/s)"); `src/fitting/ship_peak_recharge.rs:31` (`SHIELD_PEAK_FACTOR`) and `:46` (`CAPACITOR_PEAK_FACTOR`), each carrying its own grounding in its doc comment, and `:78` (`ship_base_peak_recharge`); `src/ui/fittings.rs:1385` (the two appended peak lines).
**Mechanism.** Differentiating the simulator's closed form gives an instantaneous rate of `(2C/tau) * y * (1 − y)` with `y = sqrt(cap/C)`, maximized at `y = 1/2`, so the peak is `0.5 * C / tau = 2.5 * C / T` for full recharge duration `T` — numerically the shield factor, but reached through the capacitor simulator's own mathematics and corroborated by its two explicit test statements, not borrowed from the shield line by analogy. Borrowing would have been silently wrong to trust: nothing in the shield body says the capacitor curve shares its shape. Separately, no inspected body states in words at what fraction of capacity either peak occurs, so all wording says "peak" with no charge-level percentage, even though the derivation locates the maximum internally.
**Fix (or queued).** Two separately grounded factor constants feed one private guarded helper in `src/fitting/ship_peak_recharge.rs`; the capacitor comment fixture (1000 GJ, 60 s) is asserted against `2500.0 / 60.0`, never the comments' rounded 41.7; no percentage is printed anywhere.
**Validation.** Hand-derived bundled-catalogue oracles with divisions shown (Rifter 1.8 HP/s / 5.0 GJ/s, Punisher 1.4 HP/s / 6.25 GJ/s) and the full guard matrix in `src/fitting/ship_peak_recharge.rs`; locked line templates and absence matrix in `src/ui/fittings.rs`; full gates on branch `feat/rust-peak-recharge-rates`.
**Generalizable rule.** When two systems end up with the same numeric constant, ground each one in its own authoritative body and record the grounding at each constant — a shared value proved twice is evidence, while a value copied by analogy is a guess wearing a citation.
**Refs.** `docs/peak-recharge-rates-design.md` sections 2, 3 and 9.

### An EHP number without its damage profile named beside it is a lie by omission; compose it in resonance space and never adjust a rendered total to match its rendered layers

**Author.** Muse Code (ship-base-ehp workflow, integrator)
**Context.** The ship base effective hit points (EHP) slice adds per-layer (shield, armor, hull) and total base EHP to saved and imported fitting details, composed only from the bare hull's base hit points and base resistances already in the bundled catalogue, with no fitted modifiers, recharge, or sustained tank.
**Evidence.** `docs/ship-base-ehp-design.md` sections 2 and 9 (the retired Flutter fitting panel rendered a bare `EHP` total whose omni profile existed only in code comments, while its combat analyzer labelled `EHP (omni)` / `omni 25/25/25/25` in the view itself); `src/fitting/ship_ehp.rs:31` (named `OMNI_*_SHARE` constants, each 0.25), `:96` (share-weighted resonance denominator), and `:121` (`ship_base_ehp`); `src/ui/fittings.rs:1200` (heading "Ship effective hit points (base values, omni 25/25/25/25)"), `:1208` (disclosure naming the equal-quarters mix and every not-applied class), and `:4048` (the Rifter rendering pin: unrounded total 1809.7443815 renders 1,809.7 even though the rendered layers 620.7 + 666.7 + 522.4 sum to 1809.8).
**Mechanism.** EHP is meaningless without the damage mix it assumes, so copying the retired panel's bare label would have shipped a number whose premise lived only in comments; the labelled analyzer wording is the grounded precedent. Two precision traps sit under that label: composing from the resistances block's displayed percents would round-trip through `(1 - resonance) * 100` and back, compounding display rounding into the division, so the computation reads stored resonances directly in resonance space; and a total summed from unrounded layers can differ by a tenth from the sum of its one-decimal rendered layers, which is correct arithmetic, not a display bug to "fix" by nudging either string.
**Fix (or queued).** Heading and disclosure name the omni 25/25/25/25 profile in the view itself; `ship_ehp.rs` does its own resonance-space catalogue lookup with no percent round-trip; rendered strings are pinned exactly as computed (Rifter total 1,809.7) in `src/ui/fittings.rs`, with no adjustment to make them agree.
**Validation.** Hand-derived bundled-catalogue oracles and Flutter bare-hull parity (Rifter hull 522.388, total 1809.744 within 0.01) in `src/fitting/ship_ehp.rs`; locked wording, omission, and demo-story pins in `src/ui/fittings.rs`; full gates on branch `feat/rust-ship-base-ehp`.
**Generalizable rule.** Every derived number carries its premises (profile, base-vs-fitted, not-applied classes) in the visible label, is composed from stored source values never from displayed ones, and its rendered total is pinned as computed even when displayed parts appear to disagree by a rounding tenth.
**Refs.** `docs/ship-base-ehp-design.md` sections 2, 4-6 and 9; DECISIONS 2026-11-16 ship-base-EHP composition entry below.

### Two hull-resistance attribute sets share display names; coverage plus the retired app's constants pick 109-113 over the Damage Control bonus set 974-977

**Author.** Muse Code (ship-resistances workflow, integrator)
**Context.** The ship resistances slice shows the bare hull's base shield, armor, and hull resistances (EM, thermal, kinetic, explosive) in saved and imported fitting details, converted from catalogue resonances by `(1 - resonance) * 100`, with no fitted modifiers, effective hit points, or recharge.
**Evidence.** `docs/ship-resistances-design.md` section 2 (coverage audit over `dgmTypeAttributes.csv.bz2`: hull attributes 113/110/109/111, the `emDamageResonance` family, are present on all 404 published category-6 ships at 0.67, while 974-977, the `hullEmDamageResonance` family, are present on only 9 of 404 ships at 1.0 and are a fitted Damage Control's bonus inputs per the retired Flutter constants; both families share identical English display names); `scripts/sde/generate_fitting_types_sde.py:97` (`RESIST_ATTR_IDS`, category-6-only emission keeping 53,981 non-ship wanted rows out); `src/names/fitting_types.rs:338` (`bundled_catalogue_invariants` proves all twelve resonances `Some` on every ship and none outside category 6); `src/fitting/ship_resistances.rs:66` (`resonance_to_percent`) and `:81` (`ship_resistances`); `src/ui/fittings.rs:1452` (`render_ship_resistances`).
**Mechanism.** The SDE display name cannot arbitrate which attribute set is ship data, because both sets are named the same; only the attribute names, the retired app's constants, and cache coverage distinguish them. Emitting 974-977 would have shown an invented 0% hull resistance on nine ships (the Rifter carries both sets, 0.67 and 1.0) and no hull line on 395. And because all 404 ships carry all twelve resonances with none absent, the absent-versus-present-1.0 honesty path (absent omits its segment; a present 1.0 renders a real 0.0%) again ships proven only by fixtures.
**Fix (or queued).** Emit only the 109-113 hull family, pin the Rifter 33% hull tripwire and absent/1.0/0.0 fixtures in `src/fitting/ship_resistances.rs` and `src/ui/fittings.rs`, and keep category-6-only sparse emission in the generator.
**Validation.** `bundled_catalogue_invariants` plus literal oracles (Rifter, Punisher, Mimir 32209, Legion, Falcon) in `src/fitting/ship_resistances.rs`; regeneration byte-identity proofs in the catalogue commit; full gates on branch `feat/rust-ship-resistances`.
**Generalizable rule.** When two dogma attribute sets share a display name, never arbitrate by the display name — coverage over the target category plus a proven consumer's constants decide which set is ship data.
**Refs.** `docs/ship-resistances-design.md` sections 2-4 and 9; DECISIONS 2026-11-16 ship-resistances out-of-range entry below.

### All 404 published ships carry all five base attributes; the category gate is what keeps 40,923 non-ship rows out

**Author.** Muse Code (ship-base-stats workflow, integrator)
**Context.** The ship base-values slice reads base shield, armor, hull, capacitor capacity, and maximum velocity (dogma attributes 263, 265, 9, 482, 37) from the bundled fitting-types catalogue and shows them in saved and imported fitting details, with no modifiers applied.
**Evidence.** `docs/ship-base-stats-design.md` sections 2-3 (coverage audit over `dgmTypeAttributes.csv.bz2` rows: all 404 published category-6 ships carry all five attributes, with no absent or explicit-zero rows; 40,923 wanted rows sit on non-ships); `scripts/sde/generate_fitting_types_sde.py:68` (`BASE_STAT_ATTR_IDS`) and `:320` (category-6-only emission); `src/names/fitting_types.rs:303` (`bundled_catalogue_invariants` proves all five `Some` on every ship row and none outside category 6); `src/fitting/ship_stats.rs:27` (five `Option<f64>` fields) and `:56` (`ship_base_stats`); SDE unit rows read at design time: hit points and capacitor use units 113/114, while maximum velocity (attribute 37) carries unit 11, named "Acceleration" and described in metres per second squared, yet holding a speed value.
**Mechanism.** Because real data has no absent or zero base values, the honesty path that distinguishes a missing value (line omitted, or the block unavailable when all five are missing) from a present `0.0` (a real zero that renders) ships unexercised by real ships and is proven only by fixtures. Without the category-6 emission gate, the same attribute ids on modules, rigs, and other non-ships would enter the catalogue and could be mistaken for ship values. The unit-11 quirk means a unit's name or description cannot be trusted to label a velocity; the rendered string is locked as `m/s` (the retired Flutter display) over the English `m/sec` from the SDE unit row.
**Fix (or queued).** Category-6-only sparse emission in the generator, optional fields end to end, fixture pins for absent-versus-zero in `src/fitting/ship_stats.rs` and `src/ui/fittings.rs`, and the `m/s` string locked in the renderer.
**Validation.** `bundled_catalogue_invariants` plus literal oracles (Rifter, Punisher, Legion, Raven and fractional pins) in `src/fitting/ship_stats.rs`; regeneration byte-identity proofs in the catalogue commit; full gates on branch `feat/rust-ship-base-stats`.
**Generalizable rule.** When real data happens to be complete, fixture-prove the missing-data path anyway, and gate generated attribute emission by category — an attribute id alone does not say which rows are ships, and an SDE unit's name does not prove the displayed unit string.
**Refs.** `docs/ship-base-stats-design.md` sections 2-4 and 9; DECISIONS 2026-11-16 ship-base-values entry below.

### Tests built from the constants under test cannot catch a constant swap

**Author.** Muse Code (parent repair pass over the fitting-skill-resources workflow)
**Context.** Adversarial review mutation-tested the skill slice and found the arithmetic, ownership, and honesty claims all held — except that swapping the two skill-id constants (CPU Management 3426, Power Grid Management 3413) failed only three demo-fixture tests, none of the pure lookup tests.
**Evidence.** Review finding F1 in the fitting-skill-resources synthesis (swap in a temp clone: 469 passed, 3 failed); `src/fitting/resources.rs` (the lookup tests built their skill rows with `skill(CPU_MANAGEMENT_SKILL_ID, …)` — the very constants being mutated — so test and code moved together; only the demo-story and wording tests, which flow through the real `skillqueue.json` rows and SDE name lookup, caught it).
**Mechanism.** A test that constructs its inputs from the implementation's own named constants proves the logic downstream of the constant, never the constant's value. Identifier constants are exactly where a transposition is cheapest to make and hardest to see in review, so they need at least one test written against the literal external value.
**Fix (or queued).** Lookup-test rows now use the literal ids 3426/3413, plus `skill_id_constants_are_the_grounded_ids` pins the constants themselves; the demo/name tests remain the second net.
**Validation.** Full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-fitting-skill-resources` after the repair, and a parent-inspected demo Fittings screenshot. The reviewer's unobserved compounding mutant (1.05^level) is covered analytically by the L2/L5 literal pins (143.0/162.5 at 1e-9 tolerance vs the compounded 143.325/165.917).
**Generalizable rule.** For every externally-grounded identifier constant (skill ids, attribute ids, scope strings), at least one test must spell the literal value; tests built from the constant prove everything except the constant.
**Refs.** `docs/fitting-skill-resources-design.md`; `src/fitting/resources.rs` (`resource_skill_levels`, lookup tests).

### "No skill row" means untrained only inside a loaded, owner-proven skill bundle; before the first skill-consuming feature you find the switch-boundary gap

**Author.** Muse Code (fitting-skill-resources workflow, integrator)
**Context.** The second resources slice applies CPU Management (skill 3426) and Power Grid Management (skill 3413) to ship CPU and power grid output. Two questions had to be decided from bodies: whether a missing skill row means level 0, and whether the `Ready` skills bundle ever survives a character switch.
**Evidence.** `docs/fitting-skill-resources-design.md` section 3 (the retired Flutter lookup conflates "no bundle loaded" with "row absent", defaulting both to 0); `src/fitting/resources.rs:58` (`resource_skill_levels` reads `trained_skill_level` inside a loaded bundle only, absent row reads as 0 there) and `:133` (`fitting_resources_with_skills` takes `Option`, `None` renders the base block); `src/ui/fittings.rs:1428` and `:1714` (both details derive levels from `state.skills.as_ready()`); `src/app/state.rs:892` and `:991` (the new `skills = LoadState::Loading` resets on real switch and removed-active).
**Mechanism.** An absent row in a loaded trained-skills bundle genuinely means untrained (level 0), but when no bundle is loaded for the owning character the level is unknown — rendering level 0 there would mislabel a possibly trained output as base, and rendering a prior bundle would be another character's skills. The `Ready` bundle carried no owner stamp, and before this slice nothing forced the distinction because no feature rendered one character's skills inside another character's owning context; the stale bundle survived switch and removal exactly like the known wallet/dashboard gap, but a *calculated number* would have silently consumed it instead of a visibly-wrong skill list.
**Fix (or queued).** `Option<ResourceSkillLevels>` carries loaded-vs-untrained (`None` = byte-identical base block); `set_active_character`/`remove_character` reset `skills` to Loading so a `Ready` bundle is owner-proven for the active character; wallet/dashboard gaps stay out of scope by design.
**Validation.** Pure pins in `src/fitting/resources.rs` (absent-row, present-0, trained-vs-active, the 3418 Capacitor Management no-op trap, clamp bounds) and ownership tests in `src/app/state.rs` (switch/same-id/removal/demo order); existing base-block tests unmodified as the byte-identical gate; full gates on branch `feat/rust-fitting-skill-resources`.
**Generalizable rule.** Absence means zero only inside a loaded, owner-proven bundle: model "not loaded" as a distinct `None` all the way to the render, and audit every `Ready` state for owner staleness the first time a new feature derives numbers from it.
**Refs.** `docs/fitting-skill-resources-design.md` sections 2-3; DECISIONS 2026-11-16 skill-resources entry below; LEARNINGS 2026-11-16 missing-row entry below for the sibling catalogue rule.

### In dgmTypeAttributes, a missing row does not mean zero, and subsystem output rows are not ship output

**Author.** Muse Code (fitting-resources workflow, integrator)
**Context.** The first fitting-resources slice shows base CPU and power grid used against the ship's base output for saved and imported fittings, computed only from the bundled catalogue.
**Evidence.** `docs/fitting-resources-design.md` sections 2-4 (cache facts read from `scripts/sde/dgmTypeAttributes.csv.bz2`: genuine zero-cost passive modules and Abyssal modules both have no 50/30 rows, while type 1355 carries a present power `0.0`; twelve offensive subsystems 45598-45609 carry 11/48 output rows); `src/names/fitting_types.rs:32` and `:36` (the four resource fields are `Option<f64>`); `src/fitting/resources.rs:30` (`excluded_modules`), `:65` (`usable`), `:97` (hull output only); `src/ui/fittings.rs:1136` (the in-view disclosure that skills, implants, and module, rig, subsystem, and ship bonuses are not applied).
**Mechanism.** Absence in the static data export conflates "costs nothing" with "no base value exists" (per-item mutated Abyssal modules), so treating absence as `0.0` would silently understate some fits while looking exact. Present explicit `0.0` is different data and counts as a real zero. Subsystem output rows likewise exist in the data but reach a fitting total only through effect modifiers — the retired Flutter engine seeded ship attributes from the hull alone — so adding them to a base-only total would claim a modifier this slice does not apply.
**Fix (or queued).** The catalogue keeps absence as `None`; the pure computation counts an absent or unusable dimension as an excluded row per dimension and the view names that count, and it reads output from the category-6 hull row only. Subsystem output rows are not emitted into the catalogue at all.
**Validation.** `bundled_catalogue_invariants` in `src/names/fitting_types.rs` and the oracle tests in `src/fitting/resources.rs` (present-zero type 1355 counts with no exclusion, data-less rows exclude per dimension); full gates on branch `feat/rust-fitting-resources`.
**Generalizable rule.** For SDE attribute data, missing is not zero: keep absence optional end to end, disclose what a total could not count, and never promote a data row into a total without the modifier path that grounds it.
**Refs.** `docs/fitting-resources-design.md`; DECISIONS 2026-11-16 base-values-first entry.

### A formatter is part of the hostile-input surface, and a guard keyed into the wrong map is no guard

**Author.** Muse Code (parent repair pass over the fitting-resources workflow)
**Context.** The resources calculator was deliberately hardened against hostile remote quantities (saturating sums, finite totals proven by test). Adversarial review then fed the *result* of that hardening into the one-decimal amount formatter and reproduced a panic.
**Evidence.** `src/ui/widgets.rs` (`format_fitting_amount` split a finite total via `abs.floor() as i64`, which saturates at `i64::MAX`, then `whole += 1` on the rounding carry overflowed: review probe `format_fitting_amount(30.0 * i64::MAX as f64, "tf")` panicked in debug and printed a negative garbage number in release; the committed huge-quantity test in `src/fitting/resources.rs` proved the total finite but never formatted it); `scripts/sde/generate_fitting_types_sde.py` (the duplicate-row guard tested a `(type_id, attribute_id)` tuple for membership in a dict keyed by `type_id` alone, so it could never fire — a five-line replication silently overwrote 130.0 with 999.0; the shipped catalogue was unaffected, verified duplicate-free over all 612,816 cache rows).
**Mechanism.** Hardening stops at layer boundaries unless someone composes the layers: the calculator's output domain (any finite f64) was wider than the formatter's input assumption (fits in i64 after flooring), and each layer's tests stayed inside its own domain. The generator guard failed the same way one level down — the check and the store used different key shapes, so the check was structurally incapable of firing, and only a mutation-style probe (feed it a duplicate) could notice.
**Fix (or queued).** Both amount formatters render magnitudes at or above 9.0e18 through the f64's own decimal string with grouped digits (and saturating carries below that), with regression pins at the reviewer's exact reproduction value. The generator now tracks seen `(type_id, attribute_id)` pairs in their own set (regeneration byte-identical, proving no behavior change on today's caches). The same pass counted excluded modules in units rather than rows and removed per-frame debug logging from the pure resource calculation, which is called from the render path.
**Validation.** New pins in `src/ui/widgets.rs` (huge positive/negative fitting amounts and ISK) and `src/fitting/resources.rs` (`excluded_counts_modules_not_rows_for_stacked_rows`), generator re-run with a zero-line catalogue diff, full `cargo test` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` on branch `feat/rust-fitting-resources`, and a parent-inspected demo Fittings screenshot.
**Generalizable rule.** Test the composition, not only the layers: feed each hardened producer's extreme outputs through its actual consumer (formatter, exporter, writer) in one test, and prove every guard by feeding it the exact input it exists to reject.
**Refs.** `docs/fitting-resources-design.md`; `src/ui/widgets.rs` (`format_fitting_amount`, `format_isk`); `scripts/sde/generate_fitting_types_sde.py`; `src/fitting/resources.rs`.

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

## 2026-11-17 — Nested egui ScrollAreas need explicit id_salt

**Evidence:** Demo screenshots of the Skills view showed egui debug overlays ("First/Second use of ScrollArea ID 3D09", "Second use of widget ID C6B2") reproduced on the base commit and on the skill-plans slice (integrator note on #588; parent re-verified before/after this fix).
**Mechanism:** The shell wraps every view in one outer `ScrollArea::vertical()`; inner scroll areas without an explicit salt derive colliding IDs, so egui shares their scroll state and (in debug builds) paints clash warnings over real content.
**Generalizable rule:** Every `ScrollArea` nested inside another must carry a distinct `.id_salt(...)`; treat a screenshot-visible ID-clash overlay as a defect, not cosmetics, because shared scroll state is user-visible.

## 2026-11-17 — A source UI's label is not its semantics ("Active Pins")

**Evidence:** Retired Flutter colony card at `ed698d3` (`lib/features/pi/presentation/widgets/colony_card.dart` lines 40–126, re-read during design in `docs/pi-colony-summary-design.md` section 2) versus the Rust port in `src/ui/planets.rs` (`colony_summary`, commits `367979b` and `0035355` on `feat/rust-pi-colony-summary`).
**Mechanism:** Flutter's "Active Pins" row renders the stored colony `num_pins` field from ESI (EVE's API), never an activity count and never the length of the loaded pins list. Activity and next completion derive only from extractor pins — pins carrying a positive product ID — whose expiry is strictly in the future; a non-extractor pin with a future expiry can never make a colony active. Flutter also collapsed three distinct honest states (no extractors, no parseable expiry data, all expiries in the past) into one `Idle` plus `N/A`.
**Generalizable rule:** Read the derivation behind a source UI's label before porting it, keep the stored-field meaning even when the label suggests a computed count, and let the states the source collapsed be named by the port rather than merged — a port that trusts the label ships a plausible number meaning the wrong thing.
