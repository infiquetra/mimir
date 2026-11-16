# Ship base effective hit points (omni EHP) — design

Status: locked for the `feat/rust-ship-base-ehp` slice. Base:
`develop` at `6d084bd` (verified clean before branching). Slice
branch: `feat/rust-ship-base-ehp`. This document is the single
design commit; builders and the integrator implement exactly what
is locked here and nothing else. It extends the ship base stats
slice (`docs/ship-base-stats-design.md`, #578) and the ship
resistances slice (`docs/ship-resistances-design.md`, #579), and
deliberately reuses their shapes; where this document says
"mirrors #578/#579", that wording and structure are the precedent
and do not need relitigating. The #579 design's section 10
excluded effective hit points (EHP) from that slice; that remains
historically correct for #579 and is superseded for this slice by
this document. The #578 and #579 design documents are not edited.

Every formula, share, label, order, rounding rule, and oracle
number below traces to an inspected body: the retired Flutter app
at `ed698d3` (read with `git show`), the current Rust code at
`6d084bd`, or the bundled catalogue
(`assets/sde/fitting_types.json`). No EHP convention in this
design comes from EVE folklore or memory.

## 1. Goal and value ranking

Show a "Ship effective hit points (base values, omni
25/25/25/25)" block in both fitting details (the selected saved
fitting and the imported fitting in the Fittings view), after the
"Ship resistances (base values)" block shipped by #579. The block
lists per-layer base effective hit points (shield, armor, hull)
and a total, computed only from already-shipped base data: the
three base hit point values behind #578
(`src/fitting/ship_stats.rs` inputs) and the twelve base
resonances behind #579 (`src/names/fitting_types.rs:66-89`,
converted to percentages only in `src/fitting/ship_resistances.rs`).
No new catalogue data is needed (section 3). No network, no ESI
changes, no new scopes, no persistence.

Value ranking (locked, in order):

1. **Never show an EHP number without its damage profile named
   beside it.** An EHP figure is meaningless without the damage
   mix it assumes: the same hull has a different EHP against
   every mix. An EHP number that does not name its profile in
   the UI wording itself is a lie by omission, and it is the
   failure this slice exists to avoid. The heading names the
   profile and its shares, and the disclosure under every
   rendered block defines the mix in words and names everything
   not applied (fitted modules, rigs, subsystems, skills,
   implants, ship bonuses; section 6). This outranks
   correctness and reuse: an arithmetically perfect EHP a
   reader believes is profile-free, or mistakes for their
   fitted ship's tank, is still a failure. (The retired Flutter
   fitting panel broke exactly this rule — section 2 — and its
   bare label is not copied.)
2. **Correctness of the base values.** Every EHP must be
   hand-derivable from quoted hit point and resonance values
   (sections 7 and 8 oracles), computed from resonances at full
   `f64` precision (section 2), and absence must never render
   as a number: a layer whose hit points or any needed
   resonance is absent produces no EHP, and the total exists
   only when all three layers are computable — never a total
   that silently treats a missing layer as zero (section 4).
3. **Reuse.** The #578/#579 pure-function and renderer shapes,
   their availability and independence rules, and the one
   fitting number formatter beat new machinery (sections 3–6).

Non-goals are locked in section 10. In particular: base EHP only
(base hit points, base resonances); no modifiers of any kind
(hardeners, plates or extenders adding hit points, skills,
implants, ship bonuses); no recharge, passive regeneration, or
sustained tank; no DPS, capacitor, or speed changes; no editor.

The resources block, the #578 ship base values block, and the
#579 ship resistances block (their wording, arithmetic,
availability logic, and locked strings) are unchanged by this
slice. Nothing in `src/fitting/resources.rs`,
`src/fitting/ship_stats.rs`, `src/fitting/ship_resistances.rs`,
`src/names/fitting_types.rs`, the catalogue generator or asset,
`render_fitting_resources`, `render_ship_base_stats`,
`render_ship_resistances`, or their constants and helpers
appears in this slice's diff (sections 6 and 8 pin this as a
regression gate).

## 2. Damage profile and formula (locked)

### 2.1 The shipped profile is omni only (proven, not chosen)

The one damage profile this slice ships is **omni: equal
quarters of EM, thermal, kinetic, and explosive damage** —
shares EM 0.25, thermal 0.25, kinetic 0.25, explosive 0.25,
verbatim. The inspected bodies leave no other grounded choice
for a fitting readout:

- Flutter `lib/features/fitting/domain/damage_pattern.dart` at
  `ed698d3` (read in full, 102 lines) defines exactly one named
  preset: `DamagePattern.omni` with `em: 0.25, thermal: 0.25,
  kinetic: 0.25, explosive: 0.25` (label `omni`). No other
  preset exists in the file. `DamagePattern.fromAmounts` is not
  a preset: it normalizes observed combat amounts (label
  `observed`, null when the total is not positive) and serves
  the combat analyzer, which needs combat data a bare-hull
  base readout does not have.
- The fitting engine computes exactly one profile:
  `dogma_engine.dart` at `ed698d3` builds the defense profile
  and calls `defensesHp.ehpAgainst(DamagePattern.omni)` once,
  copying its shield, armor, hull, and total into
  `shieldEhp`/`armorEhp`/`hullEhp`/`totalEhp`.
- `models.dart` at `ed698d3` documents `DefenseProfile` the
  same way: "`shieldEhp`/`armorEhp`/`hullEhp`/`totalEhp` are
  omni (25/25/25/25); use `DefenseProfileEhp.ehpAgainst` for
  any other damage pattern." There is no per-damage-type EHP
  storage anywhere in the fitting model.
- No fitting UI shows per-damage-type EHP. The fitting stats
  panel (`stats_panel.dart` at `ed698d3`) shows one DEFENSE
  `EHP` row (the omni total) above raw hit point rows. Pure
  single-type and skewed patterns appear only in
  `damage_pattern_test.dart` unit tests of the general
  `ehpAgainst` function and in combat-analyzer per-attacker
  matchups — neither is a fitting base readout body.

**Per-damage-type EHP columns are therefore excluded**
(section 10): they have no Flutter fitting body to port (no
preset, no storage, no display) and would be new invention.
The general `ehpAgainst(any pattern)` capability is likewise
not ported; this slice hard-codes the one grounded profile and
names it everywhere (sections 4 and 6). Per-layer EHP plus a
total **is** grounded (`DefenseProfile` stores all four; the
engine fills all four from the omni call), even though the
Flutter fitting panel displayed only the total; showing the
stored per-layer values extends the grounded model, not the
formula.

**Total (locked): `total = shield + armor + hull`** — the sum
of the three per-layer omni EHP values, proven from the engine
body: `LayeredEhp.total => shield + armor + hull`
(`damage_pattern.dart`), copied into `totalEhp` by
`dogma_engine.dart`. No other total definition (weakest-layer,
resistance-pooled, hit-point-pooled) has a body, and none is
shipped.

### 2.2 Formula (locked)

Flutter `_layerEhp` (`damage_pattern.dart`, verbatim):

```dart
double _layerEhp(double hp, ResistProfile r, DamagePattern p) {
  final denom =
      p.em * (1 - r.em / 100) +
      p.thermal * (1 - r.thermal / 100) +
      p.kinetic * (1 - r.kinetic / 100) +
      p.explosive * (1 - r.explosive / 100);
  return denom <= 0 ? hp : hp / denom;
}
```

`r.*` are resistance **percents**, produced by the engine as
`(1.0 - resonance) * 100` (`dogma_engine.dart` `toResist`; the
identical conversion #579 shipped as `resonance_to_percent`,
`src/fitting/ship_resistances.rs:66-74`). Substituting that
definition, `(1 - r / 100)` is the resonance itself, so the
denominator is the share-weighted resonance. The Rust port is
locked in **resonance space**, computing directly from the
catalogue resonances at full precision:

```text
denominator = 0.25 * em_resonance
            + 0.25 * thermal_resonance
            + 0.25 * kinetic_resonance
            + 0.25 * explosive_resonance
layer EHP   = denominator <= 0.0 ? hit_points
                                 : hit_points / denominator
total EHP   = shield EHP + armor EHP + hull EHP
```

Lock details:

- **Resonances, not percents, and never rounded values.** The
  bundled catalogue stores resonances
  (`src/names/fitting_types.rs:66-89`: "Fields hold
  resonances, never pre-converted percentages"), and #579's
  `ShipResistances` percentages exist for display. Computing
  EHP from `ResistLayer` percents
  (`Σ 0.25 * (1 - percent / 100)`) would round-trip every
  resonance through the percent conversion and, worse, invite
  the catastrophic version — computing from the *rendered*
  one-decimal percents on screen. Neither is shipped. The pure
  function (section 4) reads the twelve catalogue resonance
  fields itself. (For the shipped catalogue values the two
  spaces agree to float dust, far inside the section 8
  tolerances; resonance space is locked because it is the
  exact stored quantity, not because percent space measures
  differently at display precision.)
- **The `denominator <= 0` guard is preserved verbatim:** when
  the denominator is zero or negative, the layer EHP is the
  raw hit points, never infinity, NaN, or a panic. This is the
  Flutter body's own behavior, pinned by its
  `damage_pattern_test.dart` C.8 (100% resistance on every
  type — resonances all 0.0 — returns raw hit points). In
  resonance space with the section 4 usability rule
  (resonances are finite and non-negative), a negative
  denominator is unreachable and a zero denominator happens
  exactly when all four resonances are 0.0; the `<=` form is
  kept so the port states the same rule as the body it ports.
  No shipped ship reaches it (section 3); it is fixture-pinned
  (section 8).
- **Term and summation order are locked** so the arithmetic is
  reproducible and reviewable: denominator terms in EM,
  thermal, kinetic, explosive order (the `_layerEhp` term
  order, and the `ResistLayer`/`ResistProfile` field order);
  total as shield, then armor, then hull (the `LayeredEhp`
  field order). The four omni shares are applied as explicit
  per-type multiplications, never collapsed to a
  divide-by-four mean: the shares are the profile, and the
  code must show them (section 4 names them as constants).
- **Out-of-range resonances follow #579 exactly, with no
  clamping.** A resonance above 1.0 is usable data (#579
  renders its true signed negative percent); in EHP it simply
  contributes more than its share to the denominator, so the
  layer EHP can fall below the raw hit points. That is the
  grounded arithmetic, never clamped back to the hit points.
  A negative, absent, or non-finite resonance is no data,
  which makes its layer non-computable (sections 4 and 2.3) —
  the same treatment #579 gives it, not Flutter's silent
  default below.
- Attribute identity is already settled and is not relitigated:
  the twelve resonance attributes are #579 section 2's set
  (shield 271/274/273/272, armor 267/270/269/268, hull
  113/110/109/111 — the `emDamageResonance` family, **not**
  the Damage Control bonus attributes 974–977), and the three
  hit point attributes are #578 section 2's (shield capacity
  263, armor hit points 265, hull/structure hit points 9).
  Flutter `dogma_attributes.dart` at `ed698d3` carries the
  same numbers, including the verbatim 974–977 warning. No
  builder reads attribute numbers at runtime; the catalogue
  fields already encode them (section 3).

### 2.3 What is deliberately not copied from Flutter

- **The missing-resonance default.** The Flutter engine reads
  resonances through `attr(id, 1.0)`, so an absent resonance
  silently becomes 0% resistance and an EHP always comes out.
  Rust's shipped honesty rules forbid this: #578 treats an
  absent hit point value as no data (`ship_stats.rs` `usable`)
  and #579 treats an absent resonance as no data
  (`resonance_to_percent` returns `None`). Base EHP follows
  the Rust rules (section 4), never the Flutter default.
- **The always-total.** Because Flutter defaults every input,
  its `totalEhp` always exists. Here the total exists only
  when all three layers are computable (section 4); a partial
  total that treats a missing layer as zero is a smaller
  number wearing the total's label, and a relabeled partial
  sum ("total of shown layers") would still be read as the
  ship's total. Both are rejected; per-layer values render
  and the total line is omitted (section 6).
- **The bare `EHP` label.** `stats_panel.dart` renders the row
  label `EHP` with no profile named anywhere on screen — the
  profile exists only in code comments. That is the rank-1
  failure (section 1). The Rust block names omni and its
  shares in the heading and defines the mix in the disclosure
  (section 6). The grounded wording precedent for naming it
  is Flutter's own combat analyzer, which does label its
  derived numbers: `EHP (omni) <total>` and `<total> EHP
  (shield <s> / armor <a> / hull <h>)`
  (`aar_derived_stats_panel.dart` at `ed698d3`) and `Derived
  EHP (omni 25/25/25/25)` (`aar_derived_facts.dart` at
  `ed698d3`). Those bodies ground the *vocabulary* (`omni`,
  `25/25/25/25`, per-layer breakdown) only; their values are
  fitted-ship derivations and are never oracles here.
- **Integer rounding.** Flutter renders EHP as integers
  (`toStringAsFixed(0)` in the stats panel, `.round()` in the
  combat analyzer). The Rust panel renders fitting amounts at
  one decimal throughout; section 5 locks one decimal for EHP
  with the #579 section 5 reasoning, and names the difference
  instead of hiding it.
- **Adjusted-fit oracles.** Flutter test values that depend on
  fitted modules, skills, or effect modifiers are not base
  oracles and are never ported: Damage Control II hull 59.8%
  / 870.65 EHP (`dogma_engine_test.dart` E0b.2,
  `real_sde_defense_test.dart` T8.2), shield extender plus
  Shield Management hit points (T8.1b), the fitted Myrmidon
  repair case (T8.3), and the Damage Control engine-parity
  case (`damage_pattern_test.dart` C.9). Section 8 names the
  only reusable oracles.

## 3. Catalogue: no extension (locked)

**This slice adds no catalogue data.** Everything section 2
needs already ships:

- Hit points: `shield_capacity`, `armor_hp`, `hull_hp`
  (`src/names/fitting_types.rs:45-54`, shipped by #578). The
  other two #578 fields (`capacitor_capacity`, `max_velocity`)
  are never read by this slice (section 4 pins this).
- Resonances: all twelve `*_resonance` fields
  (`src/names/fitting_types.rs:66-89`, shipped by #579),
  holding resonances, never pre-converted percentages.
- The loader invariants already assert the coverage this slice
  depends on: every category-6 (ship) row carries all five
  base stats (`fitting_types.rs:447-456`) and all twelve
  resonances (`fitting_types.rs:505-521`), every present value
  is finite and non-negative, and non-ship rows carry none of
  them. A future catalogue refresh that drops a needed field
  therefore fails those tests loudly instead of blanking an
  EHP layer.

Design-time scan of the bundled catalogue (computed over
`assets/sde/fitting_types.json` at `6d084bd`, category-6 rows,
using the section 2 formula): **404 ships; every ship has all
three layers computable; the smallest layer denominator is
0.10; zero layers have a zero denominator; zero computed EHP
values are non-finite; the largest single-layer EHP is
1,407,407.4.** So on shipped data every real ship renders three
layer lines and a total (section 6), the section 2 guard and
every missing-data path are fixture-only (section 8) —
mirroring #578/#579, whose absent paths are likewise
unreachable on today's catalogue — and EHP magnitudes stay
inside the one fitting formatter's ordinary range
(section 5).

Locked consequences:

- `assets/sde/fitting_types.json`, its generator
  (`scripts/sde/generate_fitting_types_sde.py`), and
  `src/names/fitting_types.rs` **must not appear in this
  slice's diff at all** — no new fields, no regenerated asset,
  no new invariants. Existing fixture JSON without any new
  keys is all there is; nothing to stay compatible with.
- If a builder believes a needed field is absent, that
  contradicts the invariants above: stop and record it against
  this document instead of improvising catalogue work. No
  builder adds data in this slice under any circumstances.
- The `FittingType` spot pins for Rifter and Punisher hit
  points and resonances already shipped with #578/#579 tests
  and are reused as-is; section 8's EHP oracles quote the same
  values and show the division.

## 4. Pure API (locked)

New module `src/fitting/ship_ehp.rs`, declared and re-exported
from `src/fitting/mod.rs` beside `ship_resistances` and
`ship_stats` (which are not modified). A **sibling outcome, not
an extension** of `ShipBaseStats` or `ShipResistances` — the
#578 decision recorded in
`docs/engineering-journal/DECISIONS.md` (each base-attribute
block ships as its own heading plus disclosure, available
independently of its neighbours) decides this in advance, and
extending a sibling struct would break section 8's gate that
the #578/#579 blocks and their APIs stay untouched. The module
header follows the house pattern: pure computation over the
bundled catalogue — no egui, no state, no network, no database.
It depends on `CharacterFitting` and `FittingTypes`, the same
dependencies its siblings take, so both fitting details reach it
through the same one code path, and it must state in its header
that the values are base omni EHP with no modifier of any kind
applied, pointing at this document (mirroring the sibling
headers).

```rust
/// One hull's base omni effective hit points, per layer and
/// total. Each field is full-precision `f64` hit points
/// against omni damage (equal EM/thermal/kinetic/explosive
/// quarters) from base hit points and base resonances only;
/// `None` means that layer (or the total) cannot honestly be
/// computed from the catalogue data: the caller omits it,
/// never renders a zero. `total` is `Some` only when all
/// three layers are `Some`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ShipBaseEhp {
    pub shield: Option<f64>,
    pub armor: Option<f64>,
    pub hull: Option<f64>,
    pub total: Option<f64>,
}

/// Base omni effective hit points outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ShipBaseEhpOutcome {
    Available(ShipBaseEhp),
    /// The catalogue has no complete base hit point and
    /// resonance data for any layer of this fitting's ship,
    /// so no honest numbers exist.
    Unavailable,
}

pub fn ship_base_ehp(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> ShipBaseEhpOutcome;
```

Field order shield, armor, hull, total mirrors `LayeredEhp`
and `DefenseProfile` (`models.dart` at `ed698d3`) — labels and
order only; the values are base omni EHP, never Flutter's
adjusted totals. Fields hold **hit points at full `f64`
precision**; all rounding is the renderer's (section 5).

Locked semantics:

- **How resonances reach the function.** `ship_base_ehp` does
  its own catalogue lookup (the sibling pattern: `resources`,
  `ship_base_stats`, and `ship_resistances` each look up the
  hull row themselves) and reads the three hit point fields
  and twelve resonance fields directly from the `FittingType`
  row. It never calls `ship_base_stats` or `ship_resistances`,
  never consumes their outcome structs, and `ship_resistances`
  gains no resonance-exposing API: composing over the siblings
  would either compute from percents (rejected, section 2.2)
  or force an API change to a shipped module (rejected,
  section 8 regression gate), and it would couple this block's
  availability to theirs (rejected below). The extra lookup is
  one by-ID hash-map lookup per detail render, the same cost
  each sibling block already pays.
- **Omni shares are named constants** in the module
  (`OMNI_EM_SHARE`, `OMNI_THERMAL_SHARE`, `OMNI_KINETIC_SHARE`,
  `OMNI_EXPLOSIVE_SHARE`, each `0.25`), used as the four
  per-type multipliers in that order (section 2.2). Because
  all four shares are equal, no EHP value can detect a share
  wired to the wrong damage type — any permutation of equal
  shares gives the same denominator — so section 8 pins each
  constant's value and their exact sum (1.0) directly. The
  constants are module-private; the renderer names the profile
  in locked strings (section 6) and needs no share values.
- **Per-layer computability.** A layer is computable exactly
  when its hit point value is usable **and** all four of its
  resonances are usable. Usable mirrors the siblings: hit
  points use the #578 rule (present, finite, non-negative; a
  present 0.0 is a real zero), resonances use the #579 rule
  (present, finite, non-negative, **no upper bound**). One
  absent, negative, or non-finite input makes that one layer
  `None` and never blanks the other layers. Capacitor capacity
  and max velocity are never read: a row carrying only those
  is `Unavailable` here (pinned, section 8).
- **Per-layer arithmetic.** For a computable layer, in order:
  form the denominator from the four shares and resonances
  (section 2.2 order); if the denominator is `<= 0.0`, the
  layer EHP is the hit points (the locked guard); otherwise
  divide. A non-finite denominator, or a non-finite quotient
  (a tiny positive denominator under huge hit points can
  overflow the division), is **no data for that layer**
  (`None`) — the resonance-space analogue of #579's
  overflowing-percentage rule — so a false infinity or a
  false 0.0 never reaches the formatter, whose non-finite
  fallback would print `0.0 HP`. (A share-weighted mean of
  finite non-negative resonances cannot exceed the largest
  resonance mathematically; the denominator finiteness check
  is locked anyway so the rule is stated once and holds even
  at the `f64` ceiling.) The function never panics; there is
  no error channel.
- **Total composition.** `total` is `Some(shield + armor +
  hull)` (section 2.2 order) exactly when all three layers are
  `Some`, and `None` otherwise. Never a sum of the available
  layers, never zero-filled (section 2.3). A non-finite sum
  (three finite huge layers can overflow the addition) is
  `None` for the total only; the layers still render. The
  total is summed from the **unrounded** layer values; section
  5 names the visible consequence.
- **Availability.** `Unavailable` when `ship_type_id <= 0`,
  when the catalogue has no row for it, when the row is not
  category 6, **or when no layer is computable** (mirroring
  the siblings' all-absent collapse: an `Available` value with
  nothing renderable would put a heading over nothing).
  Otherwise `Available`, with each non-computable layer `None`
  and the total per the rule above — so a ship with one or two
  computable layers still shows those honest layers, exactly
  as a partial #578/#579 block shows its available values.
- The fitting's items are **never read**. Fitted modules
  (including Damage Control and its 974–977 inputs, hardeners,
  plates, extenders), rigs, subsystems, skills, implants, and
  ship bonuses contribute nothing — there is no modifier,
  stacking, or excluded-module concept in this API. A hull-only
  fitting and a fully fitted one return identical results for
  the same ship (pinned, section 8, with Damage Control II
  itself among the fitted items, mirroring #579's trap test).
- **Independence from resources, base stats, and resistances
  (locked, in all directions, per the #578 DECISIONS
  precedent).** Availability here keys off three hit point
  fields plus twelve resonance fields, with per-layer
  completeness; `ship_base_stats` keys off any of five fields,
  `ship_resistances` off any of twelve resonances, and
  `FittingResources` off the output fields. No block's
  function calls or consults another's, so every combination
  is possible and each is fixture-pinned (section 8): EHP
  `Unavailable` while resistances render (resonances without
  hit points), EHP `Unavailable` while base stats render (hit
  points without resonances, or capacitor alone), EHP
  `Available` while resources are `ShipNoOutput`, EHP partial
  (one layer, no total) while both sibling blocks render in
  full, and the resistances block showing three segments of a
  layer whose fourth resonance is absent while that layer's
  EHP and the total are withheld. On today's catalogue every
  ship is fully available in all four blocks (section 3), so
  independence is fixture-proven, as in #578/#579.
- **No logging in the pure function or the renderer**, exactly
  as in #578/#579: both run at render cadence, and the slice
  rule is `[FITTING]` counts-only logging, never per rendered
  frame. This slice adds no runtime log lines; its only
  observable output is the rendered block. The repo rule that
  every change adds `[FEATURE]` debug logging is recorded here
  as deliberately not applicable, for the same render-cadence
  reason #578 and #579 give; reviewers who disagree should
  challenge it on this document, not by adding per-frame logs.
  Flutter's `ehpAgainst` debug log line is likewise not ported.

Unit tests live in the module beside the code (section 8),
against both hand-built `FittingTypes::from_json` fixtures and
the real bundled catalogue. `src/fitting/ship_stats.rs`,
`src/fitting/ship_resistances.rs`, and
`src/fitting/resources.rs` are not modified at all; the private
layer helper's name and signature are Builder A's within the
semantics above, and its in-module tests pin the non-finite and
guard cases JSON cannot spell (the siblings' private-helper
precedent).

## 5. Number formatting (locked)

EHP values render through the one existing fitting amount
formatter with the hit point unit, exactly as the #578 block
renders its hit point lines (`ship_base_stat_lines`,
`src/ui/fittings.rs:1353-1364`, unit `"HP"`):

```rust
widgets::format_fitting_amount(value, "HP")  // src/ui/widgets.rs:69-102
```

That is thousands-grouped with exactly one decimal:
`620.7 HP`, `1,809.7 HP`, `2,760,593.6 HP`. **No new formatter
or helper is added** (unlike #579's percent adapter, EHP needs
no unit-spelling change), and `format_fitting_amount` itself is
not modified; `src/ui/widgets.rs` must not appear in this
slice's diff. The unit is `"HP"` because effective hit points
are hit points — the `EHP` in each line's label (section 6)
says *effective*, the unit says the quantity — and because it
is the #578 block's unit for the same three layers' raw values
one block above, so raw and effective values read in the same
terms.

Why one decimal, not Flutter's integers (section 2.3), decided
with the #579 section 5 reasoning: the Rust fitting panel is
one-decimal throughout (`114.0 tf`, `450.0 HP`, `33.0%`), and
one precision in one panel is one precision of truth. Rendering
EHP as integers here would make this block look coarser than
every block around it for no grounded reason — Flutter's
integer choice belonged to a different panel whose hit point
rows were also integers. The pure API keeps full `f64` (section
4); only the rendered string rounds, exactly as #578 accepted
for `218.75` → `218.8 GJ`. Section 8 pins API values with
tolerances and rendered strings exactly, separately, so the
display rounding can never masquerade as the value.

**The rendered total can differ by a tenth from the sum of the
rendered layers — this is locked and named, not a bug to fix.**
The total is summed from unrounded layers and then formatted
(section 4). The Rifter proves it: layers render `620.7`,
`666.7`, `522.4` (which sum to 1809.8) while the true total
1809.7444… renders `1,809.7` (section 7). Summing rounded
layers to force the digits to agree would print a total that
is not the section 2 total. Builders must not "correct" this;
section 8 pins the Rifter strings as written.

Magnitudes are tame on shipped data (section 3: largest layer
1,407,407.4, every total finite), far inside the formatter's
grouped range. Its huge-magnitude and non-finite guards are
inherited for free but unreachable from this API, because
section 4 filters every non-finite result to `None` before the
renderer can see it. No bars, no colour coding (a bare hull
value has no over/under state), no additional derived lines
(section 10).

## 6. UI block in both fitting details (locked)

One shared renderer in `src/ui/fittings.rs`, directly beside
`render_ship_resistances` (line 1452), called from both details
with the fitting and `fitting_types: Option<&FittingTypes>`:

```rust
fn render_ship_base_ehp(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
)
```

No skill levels and no SDE handle: the block never depends on
the viewing character, needs no name resolution (`Shield`,
`Armor`, `Hull`, `Total` are locked label constants, not EVE
type names), and no EVE numeric ID appears in any string.

**Placement (locked).** Immediately **after** the ship
resistances block in both details: in the imported detail after
`render_ship_resistances` (line 1603), in the saved detail
after it (line 1891), always before the sections that follow
today (loaded charges and import issues in the imported detail,
the copy/save/delete actions in the saved detail). Both details
therefore read items → fitting resources → ship base values →
ship base resistances → ship base effective hit points →
actions, with no per-detail fork. EHP sits after both of its
inputs (hit points, then resistances) and below the
fit-decision resources readout. Folding these lines into either
sibling block was rejected (section 4): it would rewrite a
locked #578/#579 disclosure and couple the blocks'
availability. The new calls are additional statements after the
two existing `render_ship_resistances` calls; that plus the new
renderer, line helper, and constants is the entire
`fittings.rs` diff. The block renders even when the fitting has
no items, and even when a neighbouring block renders an
unavailable sentence, and vice versa (section 4 independence).
It renders in demo mode identically; the existing demo banner
already owns the "invented sample rows" disclosure.

**Locked strings.** Constants beside the ship resistances
constants (lines 1178–1191), in the same style
(`FITTINGS_SHIP_BASE_EHP_HEADING`,
`FITTING_SHIP_BASE_EHP_DISCLOSURE`,
`FITTING_SHIP_BASE_EHP_NO_CATALOGUE`,
`FITTING_SHIP_BASE_EHP_NO_SHIP_DATA`, following the house
`FITTINGS_`/`FITTING_` split of the sibling constants):

- Heading, via `ui.heading`, always (so the view never
  silently omits the feature). It carries **both** qualifiers
  — base values, so no number reads as a fitted total, and the
  named profile with its shares, so no number reads as
  profile-free (rank 1, section 1). "(base values)" alone
  would not satisfy the profile rule; it names the base/fitted
  distinction, not the damage mix:

  > Ship effective hit points (base values, omni 25/25/25/25)

  "Effective hit points" is spelled out here on first use; the
  lines below use its short form `EHP`, defined by this
  heading and again in the disclosure. `25/25/25/25` is
  Flutter's own model/combat-analyzer vocabulary for the omni
  shares (section 2.3); because the shares are equal, their
  order cannot misstate the arithmetic, and the disclosure
  spells out which quarter is which damage type.

- Unavailable, catalogue failed to load (`fitting_types` is
  `None`):

  > Ship effective hit points unavailable: Mimir's bundled
  > item data failed to load.

- Unavailable, no computable layer (section 4 `Unavailable`).
  The sentence must not claim which input is missing (hit
  points or resonances, or both), so it names the combined
  data need:

  > Ship effective hit points unavailable: Mimir's bundled
  > item data has no complete base hit point and resistance
  > data for this fitting's ship.

- Disclosure, verbatim, always last when numbers render. It
  defines the short form and the damage mix (profile name,
  equal shares, damage types in share order), names every
  unapplied modifier class in the siblings' exact terms, and
  states that a different mix changes the numbers — the three
  facts without which an EHP number misleads:

  > These are the bare hull's base effective hit points (EHP)
  > from Mimir's bundled item data, against omni damage:
  > equal quarters (25% each) of EM, thermal, kinetic, and
  > explosive damage. Fitted modules, rigs, subsystems,
  > skills, implants, and ship bonuses are not applied, and a
  > different damage mix would give different numbers, so
  > these numbers can differ from EVE.

  Each named class maps to a grounded exclusion: fitted
  modules (hardeners, Damage Control, plates, shield
  extenders), rigs, subsystems, skills, implants (the fitting
  model holds none), and ship bonuses (role and trait bonuses;
  this app holds no data for them). The sentence is this
  block's own, parallel to but not shared with the #578/#579
  disclosures above it — each block is self-labeling, and none
  may be read as covering another.

**Layer and total lines (locked).** One line per computable
layer in shield, armor, hull order, then the total line last
(after its summands; Flutter's total-first panel ordering mixed
the total with raw hit point rows and is not a precedent here —
section 2.3). Each template is
`{label} EHP: {format_fitting_amount(value, "HP")}` (section 5).
Verbatim:

| Template | Example (Rifter 587) |
|---|---|
| `Shield EHP: {amount} HP` | `Shield EHP: 620.7 HP` |
| `Armor EHP: {amount} HP` | `Armor EHP: 666.7 HP` |
| `Hull EHP: {amount} HP` | `Hull EHP: 522.4 HP` |
| `Total EHP: {amount} HP` | `Total EHP: 1,809.7 HP` |

Lines are produced by a small pure helper beside the renderer
(the `ship_base_stat_lines` / `ship_resistance_lines`
precedent), e.g. `ship_base_ehp_lines(&ShipBaseEhp) ->
Vec<String>`, so every exact string is unit-test pinned without
an egui harness. All lines use the normal label colour. The
block is at most a heading, four lines, and the disclosure,
and needs no windowing.

**Missing-data rule (locked).** A layer whose field is `None`
contributes **no line** — omitted, not zeroed, not dashed, not
replaced with words. The total line follows the same rule:
when `total` is `None` there is simply no total line, with no
placeholder or explanation line in its place (the sibling
precedent is omit-never-placeholder, and the disclosure below
promises no total). The remaining lines still render, and the
disclosure still renders last. Only when no layer is
computable (section 4 `Unavailable`) does the fixed
unavailable sentence replace all lines and the disclosure. On
today's catalogue this rule is unreachable for real ships
(section 3); it exists so a future catalogue gap degrades one
layer (and withholds the total) instead of printing a false
number, and it is proven by fixtures (section 8). A present
0.0 EHP (zero hit points, section 4) renders `0.0 HP` like any
other value.

The renderer logs nothing itself (section 4).
`render_fitting_resources`, `render_ship_base_stats`,
`render_ship_resistances`, their helpers, constants, and call
sites are untouched.

## 7. Demo story (locked)

The demo hulls are real catalogue ships
(`assets/demo/fittings.json`, read in full during design), so
every demo fit shows honest, hand-computed base omni EHP for
its actual ship. No demo data changes in this slice. Inputs are
the #578/#579 pinned values (hit points from
`ship_stats.rs:124-151` oracles; resonances from
`ship_resistances.rs:200-217` oracles, each EM/thermal/kinetic/
explosive). Each denominator is
`0.25·em + 0.25·thermal + 0.25·kinetic + 0.25·explosive`
(section 2.2); the division is shown for every layer, totals
are summed before rounding (section 5), and rendered values are
one decimal (section 5).

**Rifter 587** — hit points 450 / 450 / 350; shield resonances
1.0/0.8/0.6/0.5, armor 0.4/0.65/0.75/0.9, hull 0.67×4:

- Shield: denominator `0.25(1.0) + 0.25(0.8) + 0.25(0.6) +
  0.25(0.5) = 0.725`; EHP `450 / 0.725 = 620.6897` → `620.7 HP`.
- Armor: denominator `0.25(0.4) + 0.25(0.65) + 0.25(0.75) +
  0.25(0.9) = 0.675`; EHP `450 / 0.675 = 666.6667` → `666.7 HP`.
- Hull: denominator `0.67`; EHP `350 / 0.67 = 522.3881` →
  `522.4 HP`.
- Total: `620.6897 + 666.6667 + 522.3881 = 1809.7444` →
  `1,809.7 HP` (not 1809.8 — section 5's rendered-sum note).

Demo Brawler and Mission Runner (both Rifter 587) therefore
show, followed by the section 6 disclosure:

```text
Ship effective hit points (base values, omni 25/25/25/25)
Shield EHP: 620.7 HP
Armor EHP: 666.7 HP
Hull EHP: 522.4 HP
Total EHP: 1,809.7 HP
```

The invented module rows in these fits (including a Damage
Control II, type 2048, in both) change none of these numbers,
because the pure function never reads items (section 4) — which
the identical blocks on both Rifter fits demonstrate. This is
also the hull tripwire carried over from #579: a wrong-set
implementation reading the decoy 974–977 rows (1.0) would show
hull EHP 350.0 here instead of 522.4.

**Punisher 597** — hit points 350 / 500 / 450; shield
resonances 1.0/0.8/0.6/0.5, armor 0.5/0.65/0.75/0.8, hull
0.67×4:

- Shield: denominator `0.725`; EHP `350 / 0.725 = 482.7586` →
  `482.8 HP`.
- Armor: denominator `0.25(0.5) + 0.25(0.65) + 0.25(0.75) +
  0.25(0.8) = 0.675`; EHP `500 / 0.675 = 740.7407` → `740.7 HP`.
- Hull: denominator `0.67`; EHP `450 / 0.67 = 671.6418` →
  `671.6 HP`.
- Total: `482.7586 + 740.7407 + 671.6418 = 1895.1412` →
  `1,895.1 HP`.

Demo Runner (Punisher 597) shows:

```text
Ship effective hit points (base values, omni 25/25/25/25)
Shield EHP: 482.8 HP
Armor EHP: 740.7 HP
Hull EHP: 671.6 HP
Total EHP: 1,895.1 HP
```

The demo sample import ("Use sample EFT" / "Use sample DNA",
both the `[Rifter, Sample Brawler]` fit; `DEMO_SAMPLE_EFT` and
`DEMO_SAMPLE_DNA` at `src/ui/fittings.rs:632-657`, the DNA
sample starting `587:2048:…`) shows the same Rifter block in
the imported detail, identically under either demo character:
base EHP never depends on who is viewing. This is the clean
no-account walkthrough: demo → Fittings → Use sample EFT →
Import fitting, then scroll.

**Visibility expectation (locked wording for reviewers).** The
Fittings view renders inside the shell's vertical scroll area,
and this block sits below the item sections, the resources
block, the ship base values block, and the ship resistances
block in both details. It will therefore normally sit **below
the fold**, exactly as those blocks do today: a reviewer must
scroll to see it, and a screenshot of just the first screenful
must not be graded as "block missing". The integrator's visual
pass (section 9) scrolls to it in both details.

## 8. Test plan (locked)

Test comments must quote the hit point and resonance literals
and show the division for every expected EHP (the resources /
base-stat / resistance test-comment precedent). An expected
number with no quoted inputs and no shown arithmetic is not an
oracle.

**Oracles and tolerances (locked).** EHP values are computed
`f64` quotients: resonances like 0.67 and denominators like
0.725 are not binary-exact, and division amplifies the dust, so
`assert_eq!` on a general quotient is wrong. Three tiers, each
used only where it is honest:

1. **Exact `assert_eq!`, only where the result is exactly
   representable:** the omni share constants (0.25 is a binary
   fraction; their sum is exactly 1.0); denominator-1.0 layers
   (resonances 1.0×4 → EHP equals the hit points); the guard
   (resonances 0.0×4 → EHP equals the hit points); binary-exact
   denominators with exact quotients (the 1600 and 1200 fixture
   cases and the Legion shield case below); present-zero hit
   points (`Some(0.0)`); and every rendered string (strings are
   exact by construction).
2. **Hand-derived catalogue oracles with absolute tolerance
   `1e-6`:** expected values written as hand-derived decimals
   from the quoted literals, carrying at least seven decimal
   places (for example Rifter shield `620.6896552`, hull
   `522.3880597`, total `1809.7443815`) so the literal's own
   truncation stays well inside the tolerance — the
   four-decimal values in section 7 are presentation, and a
   test literal copied at four decimals would fail its own
   tolerance. `1e-6` is locked, not #579's percent `1e-9`,
   because EHP magnitudes run to ~1.4e6 on shipped data
   (section 3), where a fixed `1e-9` absolute band is only a
   few `f64` units in the last place after a division; `1e-6`
   sits comfortably above that dust at every catalogue
   magnitude while staying more than four orders of magnitude
   below the 0.05 display-rounding half-step, so it can never
   hide a wrong rendered digit.
3. **Flutter bare-hull parity pins with tolerance `0.01`**,
   mirroring the Flutter assertions' own `closeTo(..., 0.01)`
   verbatim: Rifter hull EHP `522.388` and total EHP
   `1809.744`. These prove the resonance-space port lands on
   the percent-space engine's bare-hull numbers.

The only reusable Flutter oracles (inspected at `ed698d3`; all
are bare-hull `calculateStats` calls with no modules, no
skills, and no effect modifiers):

- `real_sde_defense_test.dart` **T8.1** (real bundled SDE
  Rifter): `hullEhp closeTo(expectedHull, 0.01)` where the
  expectation is recomputed in the test from raw resonances,
  and `totalEhp closeTo(1809.744, 0.01)`. Best oracle: its
  inputs are identical to the Rust catalogue rows (hit points
  450/450/350; shield resonances 1.0/0.8/0.6/0.5; armor
  0.4/0.65/0.75/0.9; hull 0.67×4), and section 7's hand
  derivation reproduces 522.3881 / 1809.7444 from them.
- `dogma_engine_test.dart` **E0b.1** (synthetic Rifter fixture
  with the same hit points and resonances as the real ship,
  including decoy 974–977 rows at 1.0): `hullEhp
  closeTo(522.388, 0.01)`, `totalEhp closeTo(1809.744, 0.01)`.
  Same pins as T8.1; either citation satisfies tier 3.
- `damage_pattern_test.dart` **T3.3** (omni against percents
  0/50/50/50 — resonances 1.0/0.5/0.5/0.5 — on 1000 hit points
  is exactly 1600), **T3.5** (zero resistance — resonances
  1.0×4 — equals raw hit points), and **C.8** (100% resistance
  — resonances 0.0×4 — returns raw hit points, finite). These
  become tier-1 exact fixture pins in resonance space.

Explicitly **not** oracles, and test comments must not cite
them as such: the `dogma_engine_test.dart` "base EHP …
without modules" case (a stale synthetic fixture — shield 350,
armor 400, hull resonances 1.0×4, expecting shield EHP 482.75 —
none of which matches the shipped Rifter); every adjusted-fit
case in section 2.3; `damage_pattern_test.dart` T3.1/T3.2
(pure single-type patterns) and T3.4 (a skewed observed
pattern), which test profiles this slice does not ship; and
every combat-analyzer EHP figure.

Real-catalogue oracle inputs beyond section 7 (hit points
shield/armor/hull; resonances EM/thermal/kinetic/explosive per
layer; EHP hand-derived as in section 7):

- Legion 29986: hit points 1800/2900/1800; shield
  1.0/0.8/0.45/0.25 → denominator 0.625 (binary-exact), shield
  EHP `1800 / 0.625 = 2880.0` **exact** (tier 1 on real data);
  armor 0.5/0.65/0.5625/0.4 → denominator 0.528125, EHP
  `2900 / 0.528125 = 5491.1243`; hull 0.67×4 → `1800 / 0.67 =
  2686.5672`; total `11057.6914` (tiers 2).
- Raven 638 (grouping-scale oracle): hit points
  7700/6380/7040; shield 1.0/0.8/0.6/0.5 → `7700 / 0.725 =
  10620.6897`; armor 0.5/0.55/0.75/0.9 → `6380 / 0.675 =
  9451.8519`; hull 0.67×4 → `7040 / 0.67 = 10507.4627`; total
  `30580.0042` (tier 2; rendered `30,580.0 HP`).

**Pure calculation** (`src/fitting/ship_ehp.rs`, Builder A):

- Share pins: each omni share constant is exactly 0.25 and the
  four sum to exactly 1.0 (`assert_eq!`; section 4 explains
  why values alone cannot pin the wiring).
- Oracle ships over the bundled catalogue: Rifter and Punisher
  return `Available` with all three layers and the total at
  section 7's hand-derived values (tier 2), plus the tier-3
  Flutter parity pins on the Rifter (hull ≈ 522.388, total ≈
  1809.744 within 0.01); Legion shield is exactly
  `Some(2880.0)` (tier 1) with its other values at tier 2;
  Raven values at tier 2. Rifter hull ≈ 522.3881 is the
  974–977 tripwire as a test (the decoy set would give 350.0).
- Items are ignored: a Rifter fitted with Damage Control II
  (2048) plus an unknown type and a stacked quantity returns a
  result equal to the hull-only Rifter (the no-modifiers lock
  as a test, mirroring the siblings).
- Ship failures: unknown ship ID (999999), non-ship ship ID
  (2048), `ship_type_id` 0 and −1 all return `Unavailable`.
- Missing-data matrix (fixture catalogues; shipped data has no
  partial ship — section 3): full row → all layers and total
  `Some`; exactly one complete layer → `Available` with that
  layer `Some`, the other two and the total `None`; hit points
  present with one armor resonance absent → armor `None`,
  total `None`, shield and hull unaffected; resonances
  complete with armor hit points absent → armor `None`, total
  `None`; one negative resonance → that layer `None` only; one
  negative hit point value → that layer `None` only;
  resonances-only row → `Unavailable`; hit-points-only row →
  `Unavailable`; row with none of the fifteen keys →
  `Unavailable`; present-zero hit points on one layer with
  complete resonances → that layer `Some(0.0)` and the total
  still computed over all three.
- Denominator edges (fixtures plus the private layer helper):
  resonances 0.0×4 with 1000 hit points → exactly 1000.0 (the
  guard; finite, never infinity); resonances 1.0×4 → exactly
  the hit points; resonances 1.0/0.5/0.5/0.5 with 1000 hit
  points → exactly 1600.0; one resonance 0.0 with the rest 1.0
  and 900 hit points → denominator 0.75 → exactly 1200.0;
  resonances above 1 render unclamped arithmetic (mirroring
  #579's signed fixture values 1.1/7.0/0.6/0.5 on 450 hit
  points: denominator `0.25(1.1) + 0.25(7.0) + 0.25(0.6) +
  0.25(0.5) = 2.3`, EHP `450 / 2.3 = 195.6522`, below the raw
  hit points and never clamped up); non-finite hit points or
  resonances rejected through the private helper (JSON cannot
  spell NaN — the siblings' symmetry); a quotient that
  overflows (huge hit points, 1e308, over tiny positive
  resonances, 1e-300) → that layer `None`; three finite huge
  layers whose sum overflows (hit points 1e308, resonances
  1.0×4 per layer) → layers `Some`, total `None`.
- Independence (fixtures, all directions — reusing the sibling
  fixture shapes and calling all four pure functions as the
  #579 independence test does): resistances-only row → EHP
  `Unavailable`, resistances `Available`, base stats
  `Unavailable`, resources `ShipNoOutput`; hit-points-only row
  → EHP `Unavailable`, base stats `Available`, resistances
  `Unavailable`; capacitor-only row → EHP `Unavailable`, base
  stats `Available` (proves capacitor and velocity are never
  read); outputs-only row → resources `Available`, EHP
  `Unavailable`; one-complete-layer row → EHP `Available`
  (partial, no total), resources `ShipNoOutput`, both sibling
  blocks `Available`; a row whose armor layer lacks exactly
  one resonance → resistances `Available` (that layer merely
  loses a segment there) while armor EHP and the total are
  `None` here.

**Catalogue** (no builder): there are no catalogue tests to add
— the asserted invariants this slice relies on already ship
(section 3). The regression gate below requires the existing
ones to pass unmodified, which is itself the check that no
catalogue drift slipped in.

**UI wording, formatting, demo** (`src/ui/fittings.rs`,
Builder B), string-exact through the pure line helper
(section 6):

- The four Rifter lines and four Punisher lines from sections
  6–7, built from real `ship_base_ehp` results over the bundled
  catalogue — including the Rifter total `1,809.7 HP` sitting
  under layers summing to 1809.8 (section 5, pinned as
  written).
- Formatting pins: thousands grouping at Raven scale (`Total
  EHP: 30,580.0 HP`) and at capital scale (Komodo 45649 — hit
  points 950000/450000/525000; shield resonances
  1.0/0.8/0.6/0.5 → `950000 / 0.725 = 1310344.8276`; armor
  0.5/0.55/0.75/0.9 → `450000 / 0.675 = 666666.6667`; hull
  0.67×4 → `525000 / 0.67 = 783582.0896`; rendered `Shield EHP:
  1,310,344.8 HP` and `Total EHP: 2,760,593.6 HP`); the exact
  Legion shield rendering `Shield EHP: 2,880.0 HP`; a
  present-zero layer rendering `0.0 HP` (fixture).
- Omission pins: the one-complete-layer fixture produces
  exactly one line, with an assertion that no line starts with
  the missing layers' labels and no line starts with `Total`
  (assertion on absence, not on placeholder text); a two-layer
  fixture likewise has no `Total` line.
- The heading, both unavailable sentences, and the disclosure,
  verbatim, following the
  `ship_base_stats_unavailable_and_disclosure_wording`
  precedent. The heading pin must fail if the profile or its
  shares ever leave the heading (rank 1 as a test).
- Demo story: all three demo fits yield section 7's exact
  blocks, built from the real demo fixture
  (`assets/demo/fittings.json` through the shipped
  `DEMO_FITTINGS_JSON` test pattern) over the real catalogue,
  so fixture or catalogue drift fails here; the imported path
  through `parse_eft` on `DEMO_SAMPLE_EFT` →
  `to_character_fitting()` → `ship_base_ehp` yields the Rifter
  block, and likewise through `parse_import` on
  `DEMO_SAMPLE_DNA` (mirroring the #578/#579 sample pins for
  both importers).

**Regression gate (both builders).** Every existing resources,
ship base stats, and ship resistances test in `src/fitting/`,
`src/names/fitting_types.rs`, and `src/ui/fittings.rs` passes
**unmodified**; the rendered resources, ship base values, and
ship resistances blocks are byte-identical to `6d084bd`.
`src/fitting/resources.rs`, `src/fitting/ship_stats.rs`,
`src/fitting/ship_resistances.rs`,
`src/names/fitting_types.rs`, `assets/sde/fitting_types.json`,
the generator script, `src/ui/widgets.rs` (`format_fitting_amount`
and `format_fitting_percent` included),
`render_fitting_resources`, `render_ship_base_stats`,
`render_ship_resistances`, their helpers, and their constants
must not appear in this slice's diff at all. In
`src/fitting/mod.rs` the diff is added lines only (the new
module declaration and re-export), and in `src/ui/fittings.rs`
the only permitted touch to existing code is the two added
`render_ship_base_ehp` call statements after the existing
resistances calls (section 6).

**Gates at every commit** (repo standard): `cargo test`,
`cargo clippy --all-targets -- -D warnings`, `cargo fmt
--check`.

## 9. Integrator list (locked)

The integrator (not the builders) makes these changes after
both builders land:

- **README** — three sites (line numbers at `6d084bd`), all
  keeping the rule that base omni EHP is not a fitting
  statistic: the words "simulator" and "statistics" must not
  attach to the new numbers, and no sentence may imply fitted
  totals or a profile-free EHP. Wherever EHP is named it is
  named as base effective hit points against the omni damage
  mix, in the same breath as the not-applied classes — never a
  bare "effective hit points" claim.
  1. The Fittings bullet (line 22): **the closing denial must
     be corrected.** Today it reads: "There are still no DPS
     or tank numbers — no effective hit points, and no recharge
     or capacitor-stability figures, and no adjusted fitting
     totals of any kind." The clause "no effective hit points"
     (left by #579) becomes false the moment this slice lands,
     and the unqualified "no … tank numbers" framing becomes
     contestable beside a base EHP readout. The bullet gains a
     joined sentence for the base effective hit points readout
     in the honesty terms of its neighbours (bare hull base
     hit points and resistances from the bundled item data,
     against omni damage — equal quarters EM, thermal,
     kinetic, explosive — with fitted modules, rigs,
     subsystems, skills, implants, and ship bonuses not
     applied, and a different damage mix giving different
     numbers), and the denial narrows to what stays true: no
     DPS, no recharge or capacitor-stability figures, no
     sustained-tank figures, and no adjusted (fitted) totals
     of any kind — without denying the base omni EHP the
     previous sentence just described. The "not been
     live-verified" caveat stays.
  2. The Roadmap Fitting bullet (line 31): the parenthetical
     gains the base effective hit points (omni) readout beside
     the base resistances readout; "ship fitting simulator
     with fitting statistics" stays listed as not implemented.
  3. The Status paragraph (line 37): the "only fitting
     features" enumeration gains the base effective hit points
     (omni) readout; "the fitting simulator is not present
     yet" stays true.
  No other README sentence makes an EHP claim (verified by
  search during design: line 22 is the only "effective hit
  points" site). The historical exclusions in
  `docs/ship-base-stats-design.md` and
  `docs/ship-resistances-design.md` are **not** edited — they
  were true for their slices, and this document supersedes
  them for this one.
- **Engineering journal** — in the same change set (repo rule),
  kept short: a dated `LEARNINGS.md` entry with Evidence
  (file:line), Mechanism, and a one-line generalizable rule,
  covering the profile-naming trap (the retired fitting panel
  rendered a bare `EHP` total whose omni profile existed only
  in code comments, so the port grounds its wording in the
  combat analyzer's labelled `EHP (omni)` / `omni 25/25/25/25`
  bodies instead) and the two precision findings (EHP is
  composed in resonance space from stored resonances, never
  from displayed percents; and a total summed from unrounded
  layers can differ by a tenth from the sum of its rendered
  layers — the Rifter's 1,809.7 under 620.7 + 666.7 + 522.4 —
  so rendered strings are pinned as computed, never adjusted
  to agree). Plus a short `DECISIONS.md` entry for the three
  composition decisions — omni-only (the sole grounded fitting
  profile; per-damage-type columns rejected as invention),
  resonance-space computation in a new sibling module (percent
  composition over `ShipResistances` and extending
  `ship_resistances` rejected), and total-only-when-every-layer
  (partial and relabeled-partial totals rejected) — with
  rejected alternatives and a "revisit when" condition (a
  grounded modifier pipeline or a grounded fitting-display
  body for non-uniform profiles is inspected). The #578
  decisions on self-labeling blocks and independent
  availability are followed, not re-decided.
- Confirm the slice diff contains no ESI, scope, persistence,
  network, demo-asset, catalogue, generator, resources-stack,
  base-stats-stack, resistances-stack, or formatter changes
  (section 8 regression gate), and run a demo-mode visual pass
  over the section 7 demo story (all three demo fits plus both
  sample imports), scrolling to the block in both details per
  section 7's below-the-fold expectation and checking every
  rendered number against section 7's hand-derived values,
  before reporting done.

## 10. Exclusions (locked)

Out of this slice, by name: every damage profile other than
omni — per-damage-type EHP columns or lines (pure EM, pure
thermal, pure kinetic, pure explosive), skewed or observed
profiles, `fromAmounts`-style normalization, any profile picker
or label plumbing, and any `ehpAgainst(pattern)` general API;
shield recharge and passive regeneration in every form (rates,
times, peak recharge), active repair and boost rates, and any
sustained-tank or tank-per-second figure; all modifier
application — fitted modules (hardeners, Damage Control
including any read of attributes 974–977, plates and shield
extenders adding hit points, resistance rigs), rigs,
subsystems, ship role and trait bonuses, implants, and skills
(including the trained-skill inputs the resources block takes —
this block takes none); stacking penalties and modifier
chaining of any kind; DPS, volley, capacitor capacity/recharge/
stability changes, speed changes, and every other fitting
statistic; weakest-resistance or "resist hole" callouts,
omni/average-resistance helpers, and any total other than
section 2.1's (including any partial-layer total); the fitting
editor and any fitting mutation; bars, sparklines, and colour
coding; any change to the resources, ship base values, or ship
resistances blocks' behavior, wording, or availability logic,
or to the catalogue, its generator, or the fitting number
formatter; ESI calls, scopes, and stored data; demo fixture
changes. Anything on this list appearing in a builder commit is
a design breach, not a bonus.

## 11. Ownership (locked)

Small atomic commits, `type(scope): description`, no
attribution. Nobody pushes or merges; the parent does that.

- **Builder A — pure calculation.** (1)
  `src/fitting/ship_ehp.rs` with its tests (section 8 pure
  calculation), wired in `src/fitting/mod.rs` (added lines
  only). No catalogue-adjacent API is needed or permitted:
  `ship_ehp.rs` reads existing catalogue fields through the
  shipped `FittingTypes` lookup and nothing else (section 4);
  if a needed field appears absent, stop against section 3
  instead of improvising. Commit (1) must compile and pass
  gates with no UI change (dead-code warnings handled by the
  re-export, not by `#[allow]`, mirroring the siblings).
  Builder A touches no `src/ui/` files, no
  `src/fitting/ship_stats.rs`, no
  `src/fitting/ship_resistances.rs`, no
  `src/fitting/resources.rs`, and no catalogue or generator
  files.
- **Builder B — UI and demo pins.** (2) `render_ship_base_ehp`,
  its line helper, its locked-string constants, and both call
  sites in `src/ui/fittings.rs`, with the section 8 wording,
  formatting, omission, and demo pins. Builder B adds **no**
  formatter and changes nothing in `src/ui/widgets.rs` (section
  5); if a change to `format_fitting_amount` seems necessary,
  stop and take it back to this document. Builder B changes no
  `src/fitting/`, catalogue, generator, or demo files, and must
  not modify `render_fitting_resources`,
  `render_ship_base_stats`, `render_ship_resistances`, their
  helpers, or any of their constants — the call-site diffs are
  added statements after the two existing resistances calls
  (section 6).
- **Integrator.** (3) README + engineering journal (section
  9), any cross-builder seam fix the two halves reveal
  (signature drift between sections 4 and 6 is the
  integrator's to reconcile back to this document, not to
  whichever builder wrote first), final gates, and the demo
  visual pass including the below-the-fold scroll check and
  the section 7 number check (sections 7 and 9).

Sequencing: A(1) → B(2) → integrator (3). B(2) needs A(1)'s
API; nothing else in the slice has slack to reorder. There is
no catalogue step to sequence (section 3).
