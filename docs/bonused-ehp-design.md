# Bonused effective hit points (omni EHP with fitted-module resistance bonuses) — design

Status: locked for the `feat/rust-bonused-ehp` slice. Base:
`develop` at `890813a` (PR #615 merged). Slice branch:
`feat/rust-bonused-ehp`. This document is the single design
commit; builders implement exactly what is locked here and
nothing else. It extends the ship base EHP slice
(`docs/ship-base-ehp-design.md`) and the resistance bonuses
slice (`docs/resistance-bonuses-design.md`, #615), and reuses
their shapes; where this document says "mirrors base EHP" or
"mirrors #615", that wording and structure are the precedent
and do not need relitigating. The #615 design's section 7
deferred EHP-from-bonused-resistances and its section 10
excluded it from that slice; both remain historically correct
for #615 and are superseded as a slice boundary by this
document (section 2). The earlier design documents are not
edited.

Every name, formula, and oracle number below traces to an
inspected body at `890813a`: `src/fitting/ship_ehp.rs`,
`src/fitting/ship_resistances.rs`, `src/fitting/mod.rs`,
`src/ui/fittings.rs`, the two design documents above, or hand
arithmetic over values those bodies pin (shown in section 8).
No convention here comes from EVE folklore or memory. Raw EVE
type IDs never appear in any rendered string in this slice.

## 1. Goal and value ranking

Show a "Ship effective hit points (with fitted module
resistance bonuses, omni 25/25/25/25)" block in both fitting
details (the selected saved fitting and the imported fitting
in the Fittings view), immediately after the existing base EHP
block. The block lists per-layer omni effective hit points
(shield, armor, hull) and a total, computed from the hull's
**base hit points** (the numerator, unchanged from base EHP)
divided by share-weighted **bonused resonances** (the
denominator: the base resonances after the fitted modules'
resistance bonuses shipped by #615). This completes the parity
item "effective (resistance-applied) tank": resistance-applied
is the operative qualifier, and no string in this slice uses
the word "tank". No new catalogue data is needed (section 5).
No network, no ESI changes, no new scopes, no persistence.

Value ranking (locked, in order), extending base EHP's:

1. **Never show an EHP number without its damage profile and
   its numerator policy named beside it.** Base EHP's rank 1
   (profile named in heading and disclosure) is inherited
   verbatim. This slice adds the second half: because only the
   resistances are bonused and the hit points stay base,
   heading and disclosure must say so, or the figure reads as
   a fitted total (section 7 wording). An arithmetically
   perfect number a reader mistakes for their fitted ship's
   full tank is still a failure.
2. **Correctness and exactness of the bonused resonances.**
   Every EHP must be hand-derivable from quoted hit point and
   bonused-resonance values (section 8), computed in resonance
   space at full `f64` precision from the same intermediate
   #615 already computes (section 3) — never by inverting
   displayed percents. Absence never renders as a number:
   per-layer completeness and the total rule are identical to
   base EHP (section 4).
3. **No deficit is silently dropped.** The excluded and
   unapplied fitted-module counts #615 computes are carried
   through this API and disclosed in this block with the same
   wording (sections 4 and 7). A bonused EHP that quietly
   omits a module the resistances block counted as missing
   would cross-read as complete.
4. **Reuse.** The base-EHP pure-function and renderer shapes,
   the #615 bonused outcome and count shapes, the shared line
   and count helpers, and the one fitting number formatter
   beat new machinery (sections 4, 6, 7).

Non-goals are locked in section 9. In particular: base hit
points only in the numerator (no hit-point modifiers of any
kind); no ship bonuses, skills, implants, subsystem bonuses,
or anything from outside the ship; no recharge, repair, DPS,
or capacitor changes; no catalogue or generator change.

The base resistances block, the #615 bonused resistances
block, and the base EHP block keep their arithmetic,
availability logic, headings, lines, and numbers. The single
wording change outside the new block is the #615 disclosure's
forward-reference clause, which becomes false the moment this
block exists; section 7 locks its replacement verbatim and
section 8 pins the one existing test that changes.

## 2. Superseding the #615 deferral (locked)

#615 section 7 deferred this exact computation for three
recorded reasons: (1) bonused denominator over base hit points
reads as a fitted tank total; (2) the every-module-counted-as-
active assumption compounds invisibly inside one number; (3)
house precedent ships one honest block at a time. It also
recorded that formula parity was not in dispute (Flutter
recomputes EHP from bonused resonances through the same
`_layerEhp` base EHP ported) and preserved the Flutter E0b
bonused-EHP oracle "so the future slice starts grounded"
(section 8 uses it). This slice is that future slice, taken
deliberately **before** any hit-point-modifier pipeline ships,
so the numerator policy is locked here instead of left open:

- **Numerator (locked): base hit points only** — the same
  three catalogue fields base EHP reads. Modules that add hit
  points contribute nothing; no hit-point modifier data exists
  in the bundled catalogue and none is added (section 5).
- Reason (1) is **mitigated, never eliminated**, and the
  mitigation is wording, not arithmetic: the heading qualifies
  the bonuses as *resistance* bonuses, and the disclosure's
  first sentence names the bare hull's base hit points as the
  numerator and names hit-point-adding modules among what is
  not applied (section 7). Review must not soften either.
- Reason (2) is mitigated the same way #615 mitigated it: the
  counted-as-active sentence is repeated verbatim in this
  block's disclosure, and the bonused resistances block
  directly above remains the sanity-checkable source of the
  denominator.
- Reason (3) is satisfied by this slice being exactly one new
  block: one pure function, one renderer, one heading plus
  disclosure, available independently of its neighbours.

What is **not** superseded: #615's modifier semantics,
counted-flag set, stacking rules, excluded/unapplied
definitions, and bounded-quantity arithmetic are inherited
unchanged (section 3). A builder who believes this design
requires changing any of them stops and records it against
this document.

## 3. Resonance source decision (locked: shared resonance helper)

`ship_resistances_with_module_bonuses`
(`src/fitting/ship_resistances.rs:271-393`) already computes,
per resonance position, the exact quantity EHP needs:
`bonused_resonance = base * mul_total * chain` (line 362,
from `mul_product` runs and the stacking-penalised
`percent_chain`), then immediately converts it through the
private `resonance_to_percent` (lines 75-83) and discards the
resonance. The public `BonusedShipResistances` therefore
exposes only percents plus the two counts. Two ways to feed
EHP were considered:

- **Percent inverse (rejected):** recover each resonance in
  `ship_ehp.rs` as `1.0 - percent / 100.0` from
  `BonusedShipResistances::resistances`. Algebraically exact,
  floating-point inexact: resonance `0.67` converts to percent
  `33.0` and back to `0.6700000000000002` (verified by
  execution at design time). Three consequences kill it.
  First, base EHP section 2.2 already locked resonance-space
  computation and rejected percent composition, because the
  catalogue stores resonances and percents exist for display;
  inverting reintroduces the rejected round-trip one slice
  later. Second, it destroys the empty-fitting identity this
  design locks (section 4): with no counted modifiers the
  shared path yields `base * 1.0 * 1.0`, which is the base
  resonance bit-for-bit (IEEE multiplication by `1.0` is
  exact), so bonused EHP can equal base EHP under `assert_eq`;
  the round-trip's dust would force a tolerance where an exact
  equality is available and would let the two blocks disagree
  in the last bits for a hull-only fit. Third, it needs a new
  public inverse convention and still leaves the counts to be
  fetched from the bonused outcome separately.
- **Shared resonance helper (locked):** factor the bonused
  computation in `ship_resistances.rs` so the resonance-level
  result is available inside the crate, and have both public
  functions build on it. Locked shape (names are part of the
  lock):

```rust
/// Bonused resonances in `RESONANCE_ORDER` position plus the
/// fitted-module counts the caller must disclose beside any
/// number derived from them.
pub(crate) struct BonusedResonances {
    pub resonances: [Option<f64>; 12],
    pub excluded_modules: usize,
    pub unapplied_modules: usize,
}

/// `None` only when the ship gate fails (`ship_type_id <= 0`,
/// no catalogue row, or the row is not category 6). Otherwise
/// `Some`, with each resonance `None` exactly where the base
/// resonance is absent, negative, or non-finite, or the
/// bonused product is negative or non-finite.
pub(crate) fn bonused_resonances(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> Option<BonusedResonances>;
```

Locked refactor semantics:

- The helper owns everything the current function does before
  percent conversion: the ship gate, the counted-item scan
  (`type_id > 0`, positive quantity, `counted_flag`), the
  excluded/unapplied counting with saturating adds, the
  run-length `mul_runs`/`percent_runs` accumulation, and the
  per-position product `base * mul_total * chain` in
  `RESONANCE_ORDER` position (shield EM/thermal/kinetic/
  explosive at 0-3, armor at 4-7, hull at 8-11). A position's
  resonance is `Some(bonused)` exactly when the current code
  would pass `Some(bonused)` to `resonance_to_percent` **and**
  the bonused value is finite and non-negative — i.e. the
  helper applies the usability half of `resonance_to_percent`
  (present, finite, `>= 0.0`, no upper bound) in resonance
  space, so a forced-negative or non-finite product is `None`
  at the source, never a value a caller must re-guard for
  sign. (Callers still pass values through their own locked
  usability filters; section 4.)
- `ship_resistances_with_module_bonuses` is rebuilt on the
  helper: `None` → `Unavailable`; otherwise map each resonance
  through `resonance_to_percent` unchanged, all-twelve-`None`
  → `Unavailable`, else `Available` with the helper's counts.
  **Its observable behaviour is byte-identical**, including the
  percent-overflow guard (a finite resonance so large that
  `(1.0 - r) * 100.0` overflows still yields a `None` percent
  there). Every existing #615 test passes unmodified; that is
  the refactor's regression gate (section 8). The helper is
  `pub(crate)`, never re-exported from `src/fitting/mod.rs`:
  resonances stay an internal quantity, exactly as
  `resonance_to_percent` and `RESONANCE_ORDER` already are.
- The EHP function (section 4) consumes the helper's
  resonances directly. One deliberate, inherited divergence is
  named, not hidden: EHP usability is base EHP's rule (finite,
  non-negative resonance; finite denominator and quotient), so
  a fixture-only resonance whose *percent* would overflow can
  still produce an EHP layer while its percent segment is
  omitted — the identical relationship base EHP already has to
  base resistances. No shipped catalogue row reaches it.
- The stacking penalty, `mul_product` early stops, and
  `percent_chain` run handling are **not** duplicated anywhere.
  `ship_ehp.rs` gains no modifier logic at all.

## 4. Pure API (locked)

No new module. The bonused API lives in
`src/fitting/ship_ehp.rs` beside `ship_base_ehp`, reusing its
private `layer_ehp`, `usable_hit_points`, `usable_resonance`,
and the four private `OMNI_*_SHARE` constants (each `0.25`,
EM/thermal/kinetic/explosive term order — the omni profile is
reused, never re-derived or re-parametrised). Names follow the
two precedents mechanically: `ShipBaseEhp` /
`ShipBaseEhpOutcome` / `ship_base_ehp` for the EHP half, and
`BonusedShipResistances` / `BonusedShipResistancesOutcome` /
`ship_resistances_with_module_bonuses` for the bonused half:

```rust
/// Bonused omni effective hit points plus the fitted-module
/// counts the caller must disclose beside them. The hit
/// points are the hull's base hit points; only the
/// resistances carry fitted-module bonuses.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BonusedShipEhp {
    pub ehp: ShipBaseEhp,
    /// Same definition, units, and source as
    /// `BonusedShipResistances::excluded_modules`.
    pub excluded_modules: usize,
    /// Same definition, units, and source as
    /// `BonusedShipResistances::unapplied_modules`.
    pub unapplied_modules: usize,
}

/// Bonused omni effective hit points outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BonusedShipEhpOutcome {
    Available(BonusedShipEhp),
    /// No complete base hit point and bonused-resonance data
    /// for any layer of this fitting's ship, so no honest
    /// numbers exist.
    Unavailable,
}

pub fn ship_ehp_with_module_bonuses(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> BonusedShipEhpOutcome;
```

`BonusedShipEhp` wraps `ShipBaseEhp` (mirroring
`BonusedShipResistances` wrapping `ShipResistances`) so the UI
line helper consumes `bonused.ehp` unchanged (section 7).
Re-export the three new names from `src/fitting/mod.rs` on the
existing `ship_ehp` line. The module header of
`ship_ehp.rs` is extended to state that the bonused function
applies fitted-module resistance bonuses to the denominator
only, with base hit points in the numerator, pointing at this
document; `ship_base_ehp`'s own docs and behaviour do not
change. No logging is added (render cadence, as in every
sibling).

Locked semantics:

- **Inputs.** The function does its own hull lookup for the
  three hit point fields (the sibling pattern; the helper does
  its own for resonances — the extra by-ID lookup per render
  is the cost each sibling block already pays) and calls
  `bonused_resonances` (section 3) for the twelve bonused
  resonances and both counts. It never reads
  `fitting.items` itself, never calls `ship_base_stats`,
  `ship_resistances`, or
  `ship_resistances_with_module_bonuses`, and never consumes a
  percent.
- **Per-layer completeness — identical to base EHP.** Shield
  uses helper positions 0-3, armor 4-7, hull 8-11, each fed to
  the existing `layer_ehp` with that layer's base hit points.
  A layer is `Some` exactly when its hit points are usable
  (present, finite, non-negative; present `0.0` is a real
  zero) and all four bonused resonances are usable (present,
  finite, non-negative, no upper bound, never clamped), the
  share-weighted denominator (EM, thermal, kinetic, explosive
  order) is finite, the `denominator <= 0.0` guard returns the
  hit points, and otherwise the quotient is finite. One absent
  or unusable input makes that one layer `None` and never
  blanks the other layers. Because the helper already returns
  `None` for an absent base resonance, a bonus can never
  resurrect a missing resonance into a computable layer.
- **Total — identical to base EHP.** `total` is
  `Some(shield + armor + hull)` (that order, from unrounded
  values) exactly when all three layers are `Some`, `None`
  otherwise; a non-finite sum is `None` for the total only.
  Never a partial sum, never zero-filled.
- **Availability.** `Unavailable` when the helper returns
  `None` (ship gate: `ship_type_id <= 0`, no row, not
  category 6), when the hull lookup fails the same gate, **or
  when no layer is computable**. Otherwise `Available`,
  carrying the helper's counts verbatim. Counts exist only on
  `Available`; `Unavailable` carries none and renders none
  (section 7) — the same shape as #615.
- **Empty-fitting identity (locked, exact).** For a fitting
  with no counted items (hull-only, or only non-counted flags
  / non-positive quantities / non-positive type IDs), and
  equally for counted items that carry no resistance
  modifiers, `ship_ehp_with_module_bonuses` returns
  `Available` exactly when `ship_base_ehp` does, with `ehp`
  **equal under `==`** to the base result (section 3: every
  resonance passes through `* 1.0 * 1.0`) and counts from the
  helper (zero unless a counted row is excluded or unapplied).
  Section 8 pins this with `assert_eq`, not a tolerance.
- **Count identity (locked).** For the same fitting and
  catalogue, `Available` counts here equal the counts from
  `ship_resistances_with_module_bonuses` whenever that
  function is `Available` — by construction (one helper), and
  pinned by test (section 8) so the two blocks can never
  disclose different deficits.
- **Independence.** Availability keys off three hit point
  fields plus per-layer bonused-resonance completeness;
  neither EHP function consults the other, nor resources, base
  stats, or either resistances outcome. In particular bonused
  EHP is `Unavailable` while bonused resistances render
  (resonances without hit points), and bonused EHP can be
  partial (layers, no total) while every sibling block renders
  in full. The function never panics; there is no error
  channel.

## 5. Catalogue: no extension (locked)

**This slice adds no catalogue data.** Everything above
already ships: the three hit point fields (#578), the twelve
resonance fields (#579), and the per-module
`resistance_modifiers` / `resistance_modifiers_unapplied`
data (#615). Locked consequences, mirroring base EHP section
3: `assets/sde/fitting_types.json`, its generator
(`scripts/sde/generate_fitting_types_sde.py`), and
`src/names/fitting_types.rs` **must not appear in this slice's
diff at all**. If a builder believes a needed field is absent,
that contradicts the shipped invariants those slices assert:
stop and record it against this document instead of
improvising catalogue work.

## 6. Display (locked)

One new renderer in `src/ui/fittings.rs`,
`render_ship_ehp_with_module_bonuses(ui, fitting,
fitting_types)`, beside `render_ship_base_ehp` and mirroring
it and `render_ship_resistances_with_module_bonuses` exactly:
it takes only the fitting and the catalogue (no skill levels,
no SDE handle), so it renders identically for every viewing
character on both surfaces.

- **Both surfaces, one insertion point each.** Call it
  immediately after `render_ship_base_ehp` and immediately
  before `render_ship_nav_targeting` in (1) the
  imported-details sequence (on the synthesised fitting,
  currently `render_ship_base_ehp` at `src/ui/fittings.rs`
  line 3759) and (2) the saved-details sequence (on the
  selected fitting, currently line 4069). The reading order
  on both surfaces becomes: base stats → base resistances →
  bonused resistances → base EHP → bonused EHP → navigation
  and targeting. The bonused EHP block is never inserted
  between bonused resistances and base EHP; the base→bonused
  pairing stays adjacent, as with resistances. No existing
  call moves.
- **Rendering rules.** The heading always renders (never
  silently omit the feature). `fitting_types` `None` →
  heading + this block's no-catalogue sentence. `Unavailable`
  → heading + this block's no-ship-data sentence, and neither
  count line. `Available` → heading, the EHP lines, the
  excluded line if any, the unapplied line if any, then the
  disclosure last. It renders even when the bonused numbers
  equal the base numbers (hull-only fit), for the reason #615
  section 5 locked: a computed-and-checked state is a fact the
  view can state. It logs nothing.
- **Line helpers are reused, not forked.**
  `ship_base_ehp_lines(&bonused.ehp)` and `ship_ehp_line`
  produce the lines unchanged (`Shield/Armor/Hull/Total EHP:
  {formatted} HP`, shield/armor/hull/total order, `None`
  omits, present `0.0` renders, the one
  `format_fitting_amount` formatter). No new line function, no
  formatting change.
- **Count helpers are reused verbatim.**
  `bonused_resistances_excluded_line` and
  `bonused_resistances_unapplied_line` render inside the
  `Available` arm exactly as in
  `render_ship_resistances_with_module_bonuses` (`None` at 0,
  singular at 1, plural above — no line at 0). Verbatim reuse
  is locked over EHP-noun rewording: the deficit being
  disclosed *is* a resistance-bonus deficit, the counts are
  the same helper counts by construction (section 4), and one
  wording for one deficit cannot drift into two. The lines in
  the two bonused blocks are per-block disclosures of the same
  deficit beside the numbers it lowers — they are never
  summed, and no combined "modules not counted" line is added
  anywhere.

## 7. UI wording (locked verbatim)

New constants beside the base EHP constants in
`src/ui/fittings.rs`, following their naming. No string calls
these numbers fitting "statistics", a "simulation", or a
"tank", and none contains a raw EVE ID.

- Heading (`FITTINGS_SHIP_EHP_WITH_BONUSES_HEADING`):
  `Ship effective hit points (with fitted module resistance bonuses, omni 25/25/25/25)`
  Both qualifiers are load-bearing: "with fitted module
  resistance bonuses" names what is applied (resistances only)
  and keeps the block from reading as base or as a complete
  fitted total; the named omni profile with its shares keeps
  every number from reading as profile-free (base EHP rank 1).
- Disclosure (`FITTING_SHIP_EHP_WITH_BONUSES_DISCLOSURE`,
  verbatim, always last in the `Available` arm):

> These effective hit points (EHP) use the bare hull's base hit points with the fitted modules' and rigs' resistance bonuses above, against omni damage: equal quarters (25% each) of EM, thermal, kinetic, and explosive damage. Every fitted module is counted as active, because the fitting data does not say which modules are on. Modules that add hit points, ship bonuses, subsystems, skills, implants, and resistance changes from anything outside this ship are not applied, and a different damage mix would give different numbers, so these numbers can differ from EVE.

  Wording notes (do not rephrase in review): "the bare hull's
  base hit points" is the numerator policy of section 2 and
  must stay in the first sentence; "Modules that add hit
  points" names extenders/plates/rigs without EVE jargon and
  heads the not-applied list because it is the gap a reader is
  most likely to assume is covered; "counted as active" and
  "resistance changes from anything outside this ship" are
  #615's locked plain forms, repeated verbatim.
- Unavailable sentences (the sibling templates with this
  block's own name):
  - `Ship effective hit points with fitted module resistance bonuses unavailable: Mimir's bundled item data failed to load.`
  - `Ship effective hit points with fitted module resistance bonuses unavailable: Mimir's bundled item data has no complete base hit point and resistance data for this fitting's ship.`

**Revision to the #615 disclosure (locked).**
`FITTING_SHIP_RESISTANCES_WITH_BONUSES_DISCLOSURE`
(`src/ui/fittings.rs:1910`) currently ends "…are not applied,
and the effective hit points below still use only the base
values, so these numbers can differ from EVE." The EHP clause
becomes false when this block ships and is replaced so the
constant reads verbatim:

> These resistances add the fitted modules' and rigs' resistance bonuses from Mimir's bundled item data to the base values above, with stacking penalties where modules of the same kind pile up. Every fitted module is counted as active, because the fitting data does not say which modules are on. Ship bonuses, subsystems, skills, implants, and resistance changes from anything outside this ship are not applied, and the effective hit points below are shown both from the base values and with these resistance bonuses, so these numbers can differ from EVE.

Its doc comment (currently "…and the effective hit points
below still using only the base values (design section 6)")
is revised in the same edit to describe the new clause and
point at this document. The base resistances disclosure and
the base EHP disclosure do not assert the EHP-uses-base claim
and **stay byte-identical**; the base EHP block's own "Fitted
modules … are not applied" sentence stays true of that block.
Only the bonused resistances block's forward reference
changes, and section 8 names the single existing pin that
moves with it.

## 8. Test plan (locked)

Tolerance tiers follow the shipped tests: hand-derived
catalogue oracles use absolute tolerance `1e-6` with literals
carrying at least seven decimal places (the `assert_ehp_close`
pattern in `ship_ehp.rs` tests); identities this design calls
exact use `assert_eq`. Fixture catalogues use the existing
`from_json` pattern of the sibling tests. No test reads a raw
EVE ID into a rendered string assertion beyond the type-ID
fixture inputs the sibling tests already use.

**Oracle 1 — hull + hardener-suite module (primary).** Rifter
(`ship_type_id` in existing test fixtures) with Damage
Control II fitted in a counted low slot, bundled catalogue.
Base inputs (pinned since #578/#579 and #615 section 8): hit
points shield 450 / armor 450 / hull 350; base resonances
shield 1.0/0.8/0.6/0.5, armor 0.4/0.65/0.75/0.9, hull 0.67×4
(EM/thermal/kinetic/explosive). #615 pins the bonused
*percents* for this fit (shield 12.5/30.0/47.5/56.25, armor
66.0/44.75/36.25/23.5, hull 59.8×4); the corresponding
bonused resonances and hand divisions are:

| Layer | Bonused resonances | Denominator | EHP |
|---|---|---|---|
| Shield | 0.875 / 0.70 / 0.525 / 0.4375 | 0.634375 | 450 / 0.634375 = 709.3596059 |
| Armor | 0.34 / 0.5525 / 0.6375 / 0.765 | 0.57375 | 450 / 0.57375 = 784.3137255 |
| Hull | 0.402 ×4 | 0.402 | 350 / 0.402 = 870.6467662 |
| Total | — | — | 2364.3200976 |

Each denominator is `0.25 ×` the resonance sum (e.g. shield
`0.25 × 2.5375`). These agree with the Flutter E0b bonused-EHP
literals #615 section 8 preserved for this slice (hull
870.65, armor 784.31, shield 709.36). The test pins all four
values and counts `excluded_modules == 0`,
`unapplied_modules == 0`. A second case pins one hardener:
Rifter + Multispectrum Shield Hardener II scales every shield
resonance by 0.675 (#615 shield percents 32.5/46.0/59.5/
66.25), so shield EHP is `450 / (0.725 × 0.675) = 450 /
0.489375 = 919.5402299` while armor, hull, and their share of
the total stay at the base values (666.6666667 +
522.3880597; total 2108.5949563 by the same hand sum — the
builder shows the addition in the test comment). A stacking
case pins the penalised chain end-to-end: Rifter + 2× EM
Armor Hardener II gives armor EM percent 90.60428781 (#615),
resonance 0.0939571219, armor denominator `0.25 × (0.0939571219
+ 0.65 + 0.75 + 0.9) = 0.5984892805`, armor EHP `450 /
0.5984892805 = 751.8931661`.

**Pure-function pins (`ship_ehp.rs` tests):**

1. Oracle 1 above (three fits), including counts.
2. **Empty fitting equals base EHP, exactly:** hull-only
   Rifter and one other bundled hull — `assert_eq` on the
   whole `ShipBaseEhp` against `ship_base_ehp`, counts zero.
   Same assertion with only non-counted items fitted (cargo /
   charge flags, quantity 0, `type_id <= 0`) and with a
   counted non-carrier module fitted.
3. **Partial layer:** fixture with one resonance absent in
   one layer → that layer `None`, total `None`, the other two
   layers `Some` and bonused where a carrier is fitted;
   fixture with one hit point field absent → same shape. A
   fitted carrier modifying the incomplete layer does not
   resurrect it.
4. **Unavailable:** unknown ship id, non-ship row,
   `ship_type_id` 0 and negative; resonances-without-hit-
   points fixture → bonused EHP `Unavailable` while
   `ship_resistances_with_module_bonuses` is `Available`
   (independence); hit-points-without-resonances fixture →
   `Unavailable`.
5. **Non-finite / hostile:** forced-negative bonused product
   (the #615 operand −150 fixture pattern) → that resonance's
   layer `None`, total `None`; non-finite/overflowing quotient
   and overflowing total fixtures mirror base EHP's (layer or
   total `None`, never infinity); denominator guard with four
   bonused 0.0 resonances → layer EHP equals base hit points;
   quantity `i64::MAX` of one carrier equals the quantity-100
   result and returns promptly (bounded arithmetic inherited
   from the helper, pinned once at this level); a resonance
   above 1.0 bonused further stays unclamped (EHP below raw
   hit points).
6. **Counts pinned:** counted row with no catalogue row →
   `excluded_modules` in quantity units (quantity 2 counts
   2); carrier marked unapplied and carrier with an
   unsupported/unknown-attribute entry → `unapplied_modules`,
   applicable entries still applied (mirror #615 cases at EHP
   level); on every fixture in this list, counts equal those
   from `ship_resistances_with_module_bonuses` (section 4
   count identity).
7. **Base independence regression:** fitting Damage Control
   II changes this function and leaves `ship_base_ehp` on the
   same fitting at the base oracles (620.6896552 /
   666.6666667 / 522.3880597, total 1809.7443815).

**Helper refactor regression:** every existing
`ship_resistances.rs` test passes **unmodified** — oracles,
penalty pins, hostile-quantity, excluded/unapplied, and
independence cases. Any failure there is a refactor defect,
never licence to edit an expectation.

**UI pins (`src/ui/fittings.rs` tests), mirroring the base EHP
and bonused resistances suites:**

1. Wording test pinning the new heading, disclosure, and both
   unavailable sentences verbatim (section 7).
2. The one changed existing pin:
   `bonused_resistances_wording_and_count_helpers` is updated
   to the revised #615 disclosure string (section 7) — the
   only existing expectation in the slice's diff.
3. Lines-formatting and present-zero/omission pins by
   construction: a `BonusedShipEhp` fixture rendered through
   `ship_base_ehp_lines(&bonused.ehp)` matches the locked
   templates, `None` layers/total omit, present `0.0` renders.
4. Count-line reuse: excluded 1 / plural and unapplied 1 /
   plural lines appear with the section 6 helpers' exact
   strings; zero counts render no line.
5. Demo-story test mirroring
   `demo_fixture_ship_base_ehp_match_the_locked_demo_story`
   and the #615 demo test: the demo fitting's bonused EHP
   layers are each `>=` the base layers with at least one
   strictly greater, the total is the unrounded sum, and
   counts match the bonused resistances demo pins
   (excluded 1, unapplied 0) — including through the imported
   EFT/DNA synthesis seam both detail surfaces share.

**Gates (all must pass for the implementation commits):**
`cargo fmt --check`, `cargo clippy --all-targets -- -D
warnings`, `cargo test`, `cargo build`. Base resistances,
base EHP, catalogue, resources, and demo tests pass
unmodified apart from the single disclosure pin in item 2
above. Commits are small and atomic, `type(scope):
description`, with no attribution lines; this design lands as
`docs(fitting): design bonused effective hit points`.

## 9. Exclusions (locked)

Out of this slice, by name: hit-point modifiers of any kind
(shield extenders, armor plates, hit-point rigs, subsystem hit
points) — the numerator stays base; ship (hull role) bonuses;
character skills; implants and boosters; subsystem resistance
bonuses beyond what #615 already counts as fitted rows;
resistance changes from anything outside the ship (fleet,
environment); module active/inactive or overheating state
(every fitted module counts as active, as #615 locked); any
damage profile other than the shipped omni (no per-damage-
type EHP, no custom profiles); shield recharge, passive or
active repair, sustained tank, DPS, capacitor, or speed
changes; any catalogue, generator, or `fitting_types.rs`
change (section 5); any change to base EHP, base resistances,
or #615 bonused resistances arithmetic, availability, or
numbers; any new public resonance or percent-inverse API (the
helper is `pub(crate)`); persistence, ESI, editor, and
network changes; new logging.

## 10. Decision record

When this slice merges, `DECISIONS.md` gains an entry in the
implementation PR (not this design commit): "Bonused EHP:
base hit points over fitted-module bonused resonances" —
recording the section 2 numerator policy, the section 3
shared-resonance-helper choice with the float-exactness
reason, and the supersession of #615 section 7's deferral as
a slice boundary (its formula oracle is consumed by section
8). The entry is the implementation PR's because it records
what shipped; this document records what was decided before
building.


