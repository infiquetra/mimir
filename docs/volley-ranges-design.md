# Volley and turret ranges (base values) — design

Status: locked for implementation. Base: `develop` at `88e6e25`
(the shipped base damage-per-second block, pull request for issue
598), clean. Slice branch: `feat/rust-volley-ranges`. Discovery: two
read-only reports (Q1: the Flutter volley and range engine at
`ed698d3` plus current Rust seams; Q2: a scripted data audit of
attributes 54 and 158 over the committed caches and the pinned zip),
re-verified during design against `docs/fitting-dps-design.md`,
`src/fitting/dps.rs`, `src/ui/fittings.rs`,
`src/names/fitting_types.rs`,
`scripts/sde/generate_fitting_types_sde.py`,
`assets/sde/fitting_types.json`, `assets/demo/fittings.json`, and a
fresh scripted join of `scripts/sde/dgmTypeAttributes.csv.bz2` to
the committed catalogue (every count and oracle value in section 3
was reproduced by that join during design). No formula in this
document is recalled; each is quoted from the Flutter engine body
named beside it. This design supersedes exactly one lock in
`docs/fitting-dps-design.md`: its section 10 exclusion of volley,
optimal-range, and falloff lines and its section 2.1 listing of
attributes 54 and 158 as never-emitted decoys. Every other lock in
that document stands unchanged.

## 1. Goal, surface verdicts, and value ranking

Goal: inside the shipped base damage-per-second (DPS) block, add a
base **volley** line (turret plus launcher damage in one firing
cycle) and base **turret optimal range** and **turret falloff
range** lines (volley-weighted averages of attributes 54 and 158,
shown in kilometres), exactly where the underlying turret and
launcher DPS inputs already exist under the shipped charge rules,
and nowhere else.

| Line | Saved (ESI) detail | DNA import detail | EFT import detail |
|---|---|---|---|
| Volley | No line | No line | Line (present zero allowed) |
| Turret optimal range | No line | No line | Line only under section 4 completeness |
| Turret falloff range | No line | No line | Line only under section 4 completeness |

The surface rule is inherited, not re-decided: turret and launcher
DPS exists only on the imported-EFT detail, because only imported
EFT text pairs a loaded charge with a weapon
(`docs/fitting-dps-design.md` sections 2.3 and 4). Volley and
ranges are computed from those same pairings, so saved and DNA
fittings gain no new lines and no partial volley or range is ever
labelled complete. Drones and fighters never contribute to any of
the three lines (section 2.2), on any surface, even though their
DPS lines render.

Value ranking, inherited from the DPS slice, in order when rules
appear to conflict:

1. **Never show a volley or range from an assumed charge, a subset
   of the counted turrets silently treated as all of them, or a
   source other than the locked one.** A missing line beats a
   plausible number.
2. **Correctness.** Formulas are Flutter's, quoted in section 2.2,
   at base values only.
3. **Reuse.** The lines live inside the shipped DPS block, reuse
   its pure function, its charge gate, its excluded and unloaded
   disclosures, and the `format_fitting_amount` formatter. Where
   this slice deliberately departs from Flutter or from the DPS
   slice's own precedents, the divergence is named in section 2.4
   and is not to be "fixed" back.

## 2. Sources and grounding (inspected bodies only)

### 2.1 Attribute truth for 54 and 158

From `dogmaAttributes.jsonl` and `dogmaUnits.jsonl` in the pinned
zip (`scripts/sde/eve-online-static-data-3503375-jsonl.zip`),
quoted through discovery Q2:

| Id | Dogma name | Display name | Unit | Default | Role |
|---|---|---|---|---|---|
| 54 | `maxRange` | Optimal Range | 1 (metre) | 0.0 | Turret optimal range, metres. Flutter calls it `optimalRange`; the catalogue key is the dogma name (section 3) |
| 158 | `falloff` | Accuracy falloff | 1 (metre) | 1.0 | Turret falloff range, metres |

The 158 default of 1.0 is load-bearing: unlike the damage
components (default 0.0, where the DPS slice reads absence as a
known zero), **an absent 158 is not a known 0 and is not a known
1.0 for display purposes in this slice** — absence means the
catalogue carries no falloff for that type, and section 4's
completeness rule treats it as missing data. Decoys that must
never be emitted or read for these lines: 76 `maxTargetRange`
(ship targeting range, already shipped under that name on ships),
160 `trackingSpeed` (tracking, section 10), 243
`maxRangeMultiplier` and 517 `fallofMultiplier` (bonus multipliers;
bonuses are out of scope), and every electronic-warfare, scanning,
drone, and fighter range attribute. Only 54 and 158 feed Flutter's
volley-weighted display.

Per-type values come only from the committed cache the generator
already reads (`dgmTypeAttributes.csv.bz2`), never from the zip.

### 2.2 Formulas, quoted from the Flutter engine at `ed698d3`

In `DogmaEngine.calculateDetailedStats`
(`lib/features/fitting/domain/dogma_engine.dart`), the offense
loop runs per online fitted module with a loaded damaging charge
(the guard chain the Rust weapon pass already mirrors). With Σ the
charge damage sum over attributes 114, 116, 117, 118:

- turret (module carries attribute 64): `volley = Σ × moduleAttr(64)`;
  `turretVolley += volley`; `optimalWeighted += moduleAttr(54) × volley`;
  `falloffWeighted += moduleAttr(158) × volley`.
- launcher (no attribute 64): `volley = Σ`; no range weight at all.
- both families: `volleyTotal += volley`.
- final: `optimalRange = turretVolley > 0 ? optimalWeighted / turretVolley : 0.0`,
  and the same shape for falloff. The denominator is turret volley
  only, never `volleyTotal`.

Drones and fighters are computed in separate engine blocks and
never touch `volleyTotal`, `turretVolley`, or either weight sum:
**volley is turret-plus-launcher by construction, and ranges are
turret-volley-weighted by construction.** A missile-only fit
therefore has a real volley and no ranges; a drone-only fit has a
volley of 0 in the Flutter panel and no ranges.

Flutter stores ranges in metres (`FittingStats.optimalRange` /
`falloffRange`, default 0.0) and renders them in
`stats_panel.dart` as `(v / 1000)` with one decimal and a `km`
unit, each only when the stored value is above 0. Volley renders
with zero decimals, unconditionally inside a visible offense
section. Section 6 keeps the metre-to-kilometre conversion and
one decimal, and names its departures from the Flutter panel
(section 2.4).

At base values — the only values this slice computes —
`moduleAttr` / `chargeAttr` bonus application drops away and what
remains is the arithmetic above over raw catalogue values. The
base-pure Flutter test oracles (from `dogma_engine_test.dart` at
`ed698d3`, quoted through discovery Q1) are: the untrained turret
fixture (charge kinetic 100, multiplier 2.0, cycle 4000 ms,
optimal 10000, falloff 5000) yields volley 200, optimal 10000,
falloff 5000; an unloaded weapon and an offline weapon each yield
volley 0; a rate-of-fire bonus changes DPS and never changes
volley. The trained-variant oracles — falloff 7500 (5000 × 1.5
skill-scaled ship bonus), the group-restricted weighted falloff
6250, missile volley 140 (a character bonus) — are
**effective-only**: they need the modifier engine Rust does not
have, and no Rust test may use them as expectations. Only the
weighted-average arithmetic in the 6250 case is base-pure;
section 8 re-derives a weighted average from base fixture values
instead of borrowing its number.

### 2.3 Where the inputs already sit in current Rust

The shipped weapon pass in `src/fitting/dps.rs` (the loop over
`slot_rows`, its successful-candidate add at line 253) already
derives, per counted row, `charge_sum` (base Σ), `multiplier`
(attribute 64 for turrets, the literal 1.0 for launchers), and
`cycle` (`row.speed`), and currently forms volley only inline:
`family.dps += charge_sum * multiplier / (cycle / 1000.0)`. The
drone pass and fighter pass each form their own volley-shaped
locals feeding only their family DPS; those values are **not**
inputs to this slice and stay exactly as they are. `FittingDps`
has no volley or range fields, and `dps_lines` in
`src/ui/fittings.rs` renders no volley or range lines. The DPS
add is **per slot row, not multiplied by the row quantity** (the
EFT parser's slot items are quantity 1; quantity units are used
only for the unloaded and excluded counts). Section 4 locks volley
and range weighting to the same per-row rule so the new lines can
never disagree with the DPS lines above them on any fixture.

The catalogue carries no 54 or 158 data today: verified during
design by a full key scan of `assets/sde/fitting_types.json`
(3,486,487 bytes, 25,818 rows) and by `src/names/fitting_types.rs`
having no fields for them, and the generator comment beside
`DPS_ATTR_IDS` states 54/158/160 "feed only Flutter's
volley-weighted display and are never read here either." Emitting
them is therefore a required part of this slice (section 3), not
an optional extra; without emission, ranges are ungrounded and
would have to be excluded entirely.

### 2.4 Deliberate divergences (do not "fix" back)

1. **Strict range completeness, against Flutter's absent-is-zero
   weighting.** Flutter's `moduleAttr` reads an absent 54 or 158
   as a 0.0 contribution to the weight numerator while the
   turret's full volley still lands in the denominator, silently
   dragging the average toward zero. In the shipped data this is
   a real case, not a fixture edge: of the 636 catalogue turrets
   carrying both `speed` and `damageMultiplier`, all 636 carry
   attribute 54 but only 602 carry attribute 158; the 34 without
   158 are the Entropic Disintegrator line (for example 47272
   Light Entropic Disintegrator I, `maxRange` 6000.0, no falloff
   row). Section 4 locks instead: a range average is shown only
   when **every counted turret** (defined in section 4) carries a
   usable value for that attribute; otherwise that range line is
   absent while the other range and the volley still show. A
   weighted average over only the turrets that happen to carry the
   attribute, presented as the fitting's range, is the "partial
   silently labelled complete" outcome ranking rule 1 forbids, and
   the 158 default of 1.0 (section 2.1) gives absence no known
   value to substitute. Rejected alternatives: Flutter parity
   (absence as a zero-weight drag), and a subset average plus a
   new "does not count" count line (new disclosure surface for
   what is, on shipped data, one weapon line's honest absence).
2. **One combined volley line (Flutter), not per-family volleys
   (the DPS slice's split).** The DPS slice split turret and
   launcher DPS and forbade any total, because a total could
   silently omit an unknown drone or fighter family. Volley is
   different in exactly one respect: its two inputs share one
   surface gate, one charge rule, and one weapon pass, and both
   are present together whenever volley is present at all, so no
   silent omission can occur *between them*; its exclusion of
   drone and fighter damage is definitional and stated in the
   locked disclosure (section 6). Volley is a bounded subtotal of
   one firing cycle, never a damage-per-second total, and the
   disclosure's final sentence is reworded to say so (section 6).
   Per-family volley lines were rejected: Flutter defines volley
   as the combined cycle damage, and two more lines would restate
   numbers the reader can already derive from the family DPS
   lines and cycle times no more honestly.
3. **Absent ranges on zero turret volley, present-zero volley on
   the EFT surface.** Flutter hides a range at exactly 0 and shows
   `Volley 0` inside any visible offense section. This slice keeps
   the substance in pure-layer form: ranges are `None` whenever
   turret volley is not above 0 or the weighted average is not
   above 0 (on shipped data the smallest turret 54 is 800.0 and
   the smallest turret 158 is 1000.0, so a zero average means no
   positive range data, not a point-blank weapon), while volley
   is `Some(0.0)` on every EFT surface, mirroring the shipped
   present-zero family DPS lines.
4. **Labels and formatting follow the shipped block, not the
   Flutter panel.** Range lines are prefixed `Turret` because
   only turrets are weighted; a bare `Optimal` would claim more
   than the number covers. Volley formats through
   `format_fitting_amount` (one decimal, grouped digits, the
   huge-magnitude guard) with the unit word `damage`, where
   Flutter renders zero decimals with no unit; ranges format
   through the same formatter with `km`, matching Flutter's
   one-decimal kilometre rendering through the shipped formatter
   instead of a bespoke format string.
5. **Category-7-only emission, against the DPS slice's 7-and-18
   gate for `speed` and `damageMultiplier`.** Those two keys ride
   on drones because drone DPS reads them. Nothing in this slice
   reads a drone's 54 or 158 (drones are excluded from volley and
   weighting by section 2.2), so emitting the 119 / 76 drone rows
   would ship dead data a later reader could mistake for an input.
   Category 32 (the other half of the candidate-pass bound)
   carries zero 54 and zero 158 rows over the catalogue, so the
   7-only gate also matches the shipped data exactly; a future
   subsystem weapon would surface as an incomplete range under
   rule 1, never as a silently wrong one. Within category 7 the
   gate is category-only, not "true turrets only" (636 rows):
   the generator's precedent is category gates, and the 521
   other category-7 rows carrying 54 (scramblers, miners,
   remote boosters) are inert because the pure layer reads
   ranges only on the turret branch of a charge-paired weapon
   candidate. The
   byte difference is roughly eleven kilobytes (section 3).
6. **Per-row volley weight, matching the shipped per-row DPS
   add** (section 2.3). Multiplying volley and weights by row
   quantity while DPS does not would make the lines contradict
   each other on any quantity-above-1 fixture. "Fixing" the DPS
   add to multiply by units is out of scope: it would change
   shipped numbers, and the EFT parser's quantity-1 invariant for
   slot items makes the two rules identical on every real import.

## 3. Catalogue extension

Generator-driven and additive, in
`scripts/sde/generate_fitting_types_sde.py`, cloning the DPS
emission pattern (sorted by `typeId`, compact separators,
fail-loud with exit 1 and nothing written on duplicate,
unparseable, non-finite, or negative values; the cache carries
zero negative rows for 54 or 158, verified during design, and the
invariant is enforced anyway). Keys use the dogma names verbatim:
attribute 54 is emitted as `maxRange`, never as Flutter's
`optimalRange`; no key is emitted under two names. Values stay in
raw metres; nothing converts at load or in the catalogue.

### 3.1 New keys, emission rules, and expected counts

Counts were scripted during design over the cache joined to the
committed catalogue (25,818 rows) and are stop-and-report values.

| Catalogue key | Rust field (`FittingType`) | Source | Emitted on | Count |
|---|---|---|---|---|
| `maxRange` | `max_range` | dgm 54 | Category 7, sparse | 1,157 |
| `falloff` | `falloff` | dgm 158 | Category 7, sparse | 681 (every 158 row also carries 54) |

Rules:

- Sparse means a key is present exactly when a source row exists,
  including a present `0.0` (447 Warp Scrambler I carries
  `falloff` 0.0; section 3.2 pins it). Absence is never rewritten
  as an emitted zero.
- Implementation shape, locked: add `54` and `158` to
  `DPS_ATTR_IDS` with named constants (`MAX_RANGE_ATTR = 54`,
  `FALLOFF_ATTR = 158`, in the existing constant-block style),
  emit `maxRange` then `falloff` — in that order, appended after
  the existing DPS emission so they are the last keys in any row
  that carries them — under a category-7-only gate (a separate
  gate from the `(7, 18)` `speed` / `damageMultiplier` block, per
  divergence 5), and amend the `DPS_ATTR_IDS` comment so 54 and
  158 are documented as read here for this slice while 160 stays
  documented as never read. Key counts extend
  `DPS_EXPECTED_COUNTS` (`"maxRange": 1157`, `"falloff": 681`);
  oracles extend `DPS_ORACLES` (section 3.2). No new oracle-list
  type is introduced, so the existing validation loops cover the
  new keys without new plumbing.

Simulated size (scripted `,"key":value` append against the
committed catalogue during design): the two keys add 33,251
bytes, from 3,486,487 to **3,519,738 bytes** (+0.95%). **Size
budget: the DPS slice's 3,550,000-byte ceiling is retained
unchanged**; Builder A reports the actual byte count in the
commit. Over budget is a stop-and-report event, not a reason to
quietly subset keys.

### 3.2 Generator oracles

Added to `DPS_ORACLES` in its `(typeId, key, expected)` shape,
with `None` an absence oracle. Every value was read from
`dgmTypeAttributes.csv.bz2` during design:

Present-value oracles:

- (484 125mm Gatling AutoCannon I, `maxRange`, 800.0),
  (484, `falloff`, 4300.0)
- (2889 200mm AutoCannon II, `maxRange`, 1200.0),
  (2889, `falloff`, 5160.0)
- (565 150mm Railgun I, `maxRange`, 12000.0),
  (565, `falloff`, 6000.0)
- (47272 Light Entropic Disintegrator I, `maxRange`, 6000.0)
- (447 Warp Scrambler I, `maxRange`, 7500.0),
  (447, `falloff`, 0.0) — present zero on an inert non-weapon
  row (no `speed`, never a weapon candidate), pinning both the
  category-only gate and sparse-present-zero in one row

Absence oracles:

- (47272, `falloff`) — the 54-only disintegrator case that drives
  section 4 completeness on real fittings
- (2404 Light Missile Launcher II, `maxRange`),
  (2404, `falloff`) — launchers carry neither key
- (2488 Warrior II, `maxRange`), (2488, `falloff`) — the cache
  carries 2100.0 / 2000.0 for this category-18 drone; neither is
  emitted (divergence 5)
- (587 Rifter, `maxRange`), (587, `falloff`) — ships carry
  neither key (76 `maxTargetRange` must not leak into either)

### 3.3 Invariants (generator self-validation and loader test)

Both assert, for the shipped catalogue: every present `maxRange`
and `falloff` value is finite and ≥ 0.0; the two keys appear only
on category-7 rows; the summary key counts match section 3.1
exactly; absence stays distinct from `0.0` (the 447 present-zero
and 47272 absent-falloff oracles pin both sides).

Loader: two new `Option<f64>` fields with
`#[serde(rename = "…", default)]`, placed after the existing DPS
fields in `FittingType`, named exactly `max_range` and `falloff`.
Old fixture JSON without the new keys must keep parsing. The new
fields join the existing finite-and-non-negative loader check and
gain the category-7-only check beside the existing
`speed` / `damage_multiplier` category check. The load log line
is unchanged; no logging is added (section 11).

### 3.4 Determinism proofs (Builder A, same commit as the catalogue)

1. Run the generator twice into two outputs; SHA-256 hashes are
   identical.
2. Strip exactly the two new keys (`maxRange`, `falloff`) from
   the regenerated catalogue; the result is byte-identical to the
   committed pre-slice `fitting_types.json` at `88e6e25`.
3. Generator self-validation (oracles + invariants + counts)
   passes, and the regenerated size is within the section 3.1
   budget.

## 4. Pure additions

Purely additive changes to `src/fitting/dps.rs`, inside the
existing `fitting_dps` weapon pass. No new module, no new
function signature, no egui, no logging — the shipped design's
constraints stand. `FittingDps` gains exactly three fields:

```rust
pub struct FittingDps {
    // … existing fields unchanged …
    /// Combined turret + launcher damage in one firing cycle
    /// (drones and fighters excluded). `Some` exactly on the
    /// EFT surface, mirroring `turrets` / `launchers`; `None`
    /// on saved/DNA surfaces. A present 0.0 is a real zero.
    pub volley: Option<f64>,
    /// Turret-volley-weighted average of attribute 54, in
    /// metres. `Some` only under the completeness rule below.
    pub optimal_range: Option<f64>,
    /// Turret-volley-weighted average of attribute 158, in
    /// metres. Completeness is per attribute.
    pub falloff_range: Option<f64>,
}
```

The two range fields carry **metres** (catalogue units, the units
Flutter stores); conversion to kilometres is a UI formatting step
(section 6) and never happens in the pure layer. Computed values
are unrounded `f64`s, exactly like family DPS.

**Accumulation, locked.** At the shipped successful-candidate add
(after the charge-sum check, where line 253 adds DPS today), the
pass binds `let volley = charge_sum * multiplier;` — the launcher
branch already carries `multiplier` 1.0, so the shipped DPS add
becomes `family.dps += volley / (cycle / 1000.0)` with no
numerical change — and then:

- `volley_total += volley` for both families;
- on the turret branch only, when `volley > 0.0` (such a turret is
  a **counted turret** for range purposes): `turret_volley +=
  volley`, and independently per range attribute,
  `usable(row.max_range)` / `usable(row.falloff)` (the shipped
  finite-and-non-negative helper) either adds `value × volley`
  to that attribute's weighted sum or marks that attribute
  **incomplete** (`optimal_complete = false` /
  `falloff_complete = false`).

Working names above (`volley_total`, `turret_volley`, the
weighted sums, the completeness flags) are local-variable names
for the builder to follow in spirit; the locked surface is the
three struct fields and the rules below.

**Final values, locked.** After the weapon pass (drone and
fighter passes untouched):

- `volley` is `Some(volley_total)` on the EFT surface
  (`is_eft.then_some(…)`), `None` otherwise. An EFT fitting with
  no damaging pairing therefore carries `Some(0.0)`.
- `optimal_range` is `Some(optimal_weighted / turret_volley)`
  only when all four hold: EFT surface; `optimal_complete`;
  `turret_volley > 0.0`; the quotient is `> 0.0`. Otherwise
  `None`. `falloff_range` is the same shape with its own flag and
  sum. The two ranges never share a completeness flag: a
  disintegrator-only fit shows optimal and honestly lacks
  falloff.

**What accumulation must never do, locked** (each is pinned by a
section 8 test):

- A candidate that leaves the pass before the successful add —
  unloaded, excluded (catalogue-absent charge, unusable
  component, unusable multiplier), or the known-zero charge sum
  (Σ ≤ 0) — contributes no volley, no weight, and **no
  incompleteness**: a zero-damage turret missing falloff cannot
  suppress the falloff of the turrets that deal damage, exactly
  as its zero weight cannot move the Flutter average. A turret
  reaching the add with volley exactly 0.0 (a present, usable
  multiplier of 0.0) is likewise weightless and cannot mark
  incompleteness; the counted-turret definition above covers
  this by its `volley > 0.0` condition.
- A present-but-unusable `max_range` or `falloff` (non-finite or
  negative; fixture catalogues only, since the generator and
  loader bar them from the shipped catalogue) marks that range
  incomplete. It does **not** add to the turret family's
  `excluded_items`: the weapon's damage data is usable and its
  DPS and volley are honest, so the shipped "does not count N
  items with no damage data" sentence would be false for it. The
  range line is simply absent.
- A present `0.0` range value is usable and counts with full
  weight (zero in the numerator, the turret's volley in the
  denominator). Absence and present-zero stay distinct end to
  end.
- Row quantity multiplies nothing (divergence 6): volley,
  `turret_volley`, and both weighted sums add once per counted
  row, exactly as family DPS does; quantity units continue to
  serve only the unloaded and excluded counts.
- The `Unavailable` rule is byte-identical to the shipped one
  (all four families `None` and `unloaded_weapons` 0). Volley
  being `Some` on every EFT surface cannot rescue an outcome,
  because both weapon families are already `Some` there; on
  saved and DNA surfaces all three new fields are `None`.

## 5. Availability rules (summary lock)

- **Volley** is available exactly where turret and launcher DPS
  are available: the imported-EFT detail. Present zero renders.
- **Each range** is independently available only on that same
  surface, only with at least one counted turret (`turret_volley
  > 0.0`), only when every counted turret carries a usable value
  for that attribute, and only when the weighted average is
  above 0. Missile-only, drone-only, and fighter-only EFT
  fittings therefore show volley and no ranges.
- A `None` new field contributes no line — never a zero, a dash,
  or placeholder words (the shipped missing-family rule).
- Excluded and unloaded weapons are disclosed by the block's
  existing lines, which stand for volley and ranges as well as
  DPS because all three are computed from the same counted rows:
  a weapon counted nowhere in the weapon pass is in no volley
  and in no weight. The locked disclosure (section 6) states
  this sharing explicitly, and no new count lines are added.

## 6. UI

### 6.1 Placement

Inside the shipped DPS block in `src/ui/fittings.rs`, in
`dps_lines`, which stays the only line builder for the block.
Locked order: the four family DPS lines as shipped, then the
volley line, then the optimal-range line, then the
falloff-range line, then the shipped excluded-item lines, then
the shipped unloaded-weapon line, then the disclosure (rendered
as today, outside `dps_lines`). Heading, unavailable sentences,
both render sites, and `render_fitting_dps` callers are unchanged.
No new block, no new heading. The function logs nothing, as today.

### 6.2 Verbatim templates

Each new line renders only when its field is `Some`, formatted
with `widgets::format_fitting_amount` exactly as the family lines:

- `Volley: {amount}` where `amount` is
  `format_fitting_amount(volley, "damage")`, for example
  `Volley: 47.8 damage` and, at present zero,
  `Volley: 0.0 damage`.
- `Turret optimal range: {amount} km` — `amount` from
  `format_fitting_amount(optimal_range / 1000.0, "km")`, for
  example `Turret optimal range: 1.2 km`.
- `Turret falloff range: {amount} km` — `amount` from
  `format_fitting_amount(falloff_range / 1000.0, "km")`, for
  example `Turret falloff range: 5.2 km`.

(The templates above name the formatter output including its
unit; builders follow the `dps_family_line` shape —
`format!("{label}: {amount}")` with `amount` the full formatter
result — so no template carries the unit twice.)

Disclosure (locked replacement for `FITTING_DPS_DISCLOSURE`; the
two new middle sentences define volley and ranges and bind them
to the same counted rows as the DPS lines, the unapplied-terms
sentence drops "range, falloff" because base ranges are now
shown while damage is still counted at full value at every
range, and the final sentence is reworded per divergence 2):

> `Base damage per second from Mimir's bundled item data: base charge, drone, and fighter damage per firing cycle, with no skill, implant, ship, module, rig, or subsystem bonuses applied. Turret and launcher damage counts only a loaded charge listed after the module in imported EFT text, exactly as listed; saved and DNA fittings list no loaded charges, and no charge is assumed. Volley is the turret and launcher damage in one firing cycle from those same listed charges; drone and fighter damage is not in the volley. Turret optimal and falloff ranges are averages of the fitted turrets' base ranges, weighted by each turret's share of the turret volley, and each is shown only when every counted turret has that range in the bundled data. Fitted weapons are treated as online, drones and fighters as launched up to the ship's base drone bandwidth and fighter tubes, and every shot is counted at full damage, with no tracking, missile application, reload time, or flight time applied. No combined damage-per-second total is shown, because any family's damage can be unknown while another's is counted.`

No other string in the block changes. In particular the shipped
unloaded-weapon line ("…so they are not counted above") already
covers volley and ranges truthfully, since both sit above it in
the locked order and neither counts an unloaded weapon; it is
not reworded. No line in the block is ever rendered in the
over-capacity red, as shipped. Resolved names only: the new
lines render no type names or ids at all.

## 7. Demo story (hand-derived from quoted rows)

Demo data is not modified by this slice. Inputs are the shipped
DPS demo derivation (`docs/fitting-dps-design.md` section 7) plus
the section 3.2 oracle rows for 2889 200mm AutoCannon II
(`maxRange` 1200.0, `falloff` 5160.0).

Saved demo fittings (saved detail, `imported` is `None`): all
three — "Demo Brawler", "Mission Runner", "Demo Runner" — render
exactly the shipped lines (heading, `Drone DPS: 0.0 DPS`). The
saved surface gains no volley and no range lines; the only
change in the rendered block is the section 6.2 disclosure
wording.

Sample EFT import (`DEMO_SAMPLE_EFT`, Rifter, EFT surface): one
200mm AutoCannon II lists Republic Fleet EMP S (the other two are
unloaded). The counted turret's volley is 13.8 × 3.465 = 47.817
(the shipped section 7 arithmetic), which is also the whole
turret volley, so both weighted averages are that turret's own
ranges. The block renders, in locked order:

- `Turret DPS: 12.8 DPS` (shipped; 47.817 / 3.75 = 12.7512)
- `Launcher DPS: 0.0 DPS` (shipped)
- `Drone DPS: 0.0 DPS` (shipped)
- `Volley: 47.8 damage` (47.817 at one decimal)
- `Turret optimal range: 1.2 km` (1200.0 m / 1000 = 1.2)
- `Turret falloff range: 5.2 km` (5160.0 m / 1000 = 5.16,
  rendering 5.2 at one decimal)
- `2 fitted weapons have no loaded charge listed, so they are
  not counted above.` (shipped wording; now also covers the
  three new lines, section 6.2)

Sample DNA import (`DEMO_SAMPLE_DNA`): DNA behaves as saved — no
turret, launcher, volley, or range lines; the shipped
`Drone DPS: 0.0 DPS` and the 3-unloaded-weapons line stand, with
only the disclosure wording changed.

## 8. Test plan

Literal expectations with the arithmetic in comments, in the
shipped test shapes: bundled catalogue plus small fixture
catalogues via `FittingTypes::from_json` for the pure layer,
fixtures carrying the new `maxRange` / `falloff` keys where a
test needs them. Computed `f64` values are pinned in the pure
layer, rendered strings separately in the UI tests. No test may
use the effective-only Flutter numbers (7500, 6250, 140) as
expectations (section 2.2).

Pure layer (`src/fitting/dps.rs`, Builder A) — new tests
alongside the shipped ones, whose expectations do not move:

1. **Flutter base cross-check.** The shipped synthetic turret
   fixture (`speed` 4000.0, `damageMultiplier` 2.0, charge
   kinetic 100.0) with `maxRange` 10000.0 and `falloff` 5000.0
   added to the module row: volley = 100 × 2.0 = 200.0;
   optimal = 200 × 10000 / 200 = 10000.0; falloff = 5000.0;
   turret DPS still 50.0. These are the untrained-fixture
   literals of section 2.2.
2. **Weighted average over two turrets, base-derived.** Turret
   A: charge 100 × multiplier 2.0 = volley 200, `maxRange`
   10000.0, `falloff` 5000.0. Turret B: charge 50 × multiplier
   2.0 = volley 100, `maxRange` 4000.0, `falloff` 8000.0.
   Optimal = (200×10000 + 100×4000) / 300 = 2,400,000 / 300 =
   8000.0. Falloff = (200×5000 + 100×8000) / 300 = 1,800,000 /
   300 = 6000.0. Volley = 300.0.
3. **Launcher volley counts, launcher ranges never do.** Real:
   2404 Light Missile Launcher II with 210 Scourge Light Missile
   through `parse_eft` (the shipped pairing test): volley =
   83.0; both ranges `None`; launcher DPS still 6.484375.
   Mixed fixture: test 1's turret plus a launcher with charge
   100 → volley = 200 + 100 = 300.0, ranges exactly the
   turret's (the denominator is turret volley 200, not 300).
4. **Real turret.** 484 with 180 Proton S: Σ = 5.0; volley =
   5.0 × 2.0625 = 10.3125; optimal 800.0; falloff 4300.0;
   DPS still 3.4375.
5. **Strict completeness, per attribute.** Real: 47272 Light
   Entropic Disintegrator I paired as listed with 180 Proton S
   (compatibility is never checked, the shipped rule): volley =
   5.0 × 0.8 = 4.0; optimal `Some(6000.0)`; falloff `None`.
   Fixture: test 2's turret A plus a counted turret carrying
   `maxRange` but no `falloff` → falloff `None`, optimal still
   the two-turret weighted value. Fixture mirror: a counted
   turret with a present-but-unusable `falloff` (negative) →
   falloff `None`, turret `excluded_items` unchanged at 0,
   DPS and volley unchanged.
6. **Present zero counts with weight.** Two fixture turrets at
   volley 100 each, falloffs 0.0 (present) and 6000.0: falloff
   = (100×0 + 100×6000) / 200 = 3000.0, `Some`. A single counted
   turret with both ranges present at 0.0 → both averages 0.0 →
   both fields `None` (divergence 3).
7. **Weightless turrets cannot suppress.** Test 1's turret plus
   (a) a turret whose paired charge sums to 0 and which carries
   no `falloff` → falloff still `Some(5000.0)`; (b) a turret
   with multiplier 0.0 (present, usable) and no `falloff`,
   paired with the damaging charge → same; (c) an unloaded and
   an excluded-charge turret with no `falloff` → same, with the
   shipped unloaded / excluded counts unchanged.
8. **Surfaces.** The shipped charge-surface cases extended: the
   same weapon rows as saved and as DNA → all three new fields
   `None`; EFT with no damaging pairing → volley `Some(0.0)`,
   ranges `None`. Drone damage never enters volley: a fitting
   whose only damage is drones (benchmark: Tristan with five
   Warrior II at drone DPS 39.0 in the shipped tests) on the
   saved surface → volley `None`; the same rows through an EFT
   import → volley `Some(0.0)`, ranges `None`. Fighter-only
   damage (the shipped Thanatos case) likewise leaves volley at
   its surface value, never the fighter cycle damage.
9. **Per-row parity.** A counted slot row with quantity 3
   (fixture `ImportedFitting`) adds its volley and weight once,
   identical to the shipped DPS expectation for that row shape;
   the unloaded count for the same row unpaired still counts
   units (shipped behaviour, pinned unchanged).

Generator and loader (Builder A gates, section 3.4): double-run
SHA-256 equality; strip-two-keys byte-identity against the
`88e6e25` catalogue; section 3.2 oracles present and absent;
expected counts 1157 / 681 and the 3,550,000-byte budget; loader
invariants extended per section 3.3; old-shape fixture JSON
still parses; loader value spot-checks mirroring the oracle rows
(484 both keys, 47272 falloff absent, 2488 both absent, 447
present-zero falloff).

UI (`src/ui/fittings.rs` tests, Builder B):

10. New line templates byte-exact, including rounding exhibits:
    computed volley 47.817 → `Volley: 47.8 damage`;
    1200.0 m → `Turret optimal range: 1.2 km`; 5160.0 m →
    `Turret falloff range: 5.2 km`; 800.0 m / 4300.0 m (484) →
    `0.8 km` / `4.3 km`; volley present zero → `Volley: 0.0
    damage`. Line order pinned: family lines, volley, optimal,
    falloff, excluded, unloaded. `None` fields contribute no
    line (missile-only shape: volley line present, no ranges).
11. The section 6.2 disclosure byte-exact (replacing the shipped
    string; this is the one shipped UI string whose test
    expectation moves). Heading and both unavailable sentences
    byte-identical to shipped.
12. Demo pins: the three saved demo fittings and the DNA sample
    render no volley or range lines; the EFT sample renders
    exactly the section 7 lines. `FittingDps` literals in tests
    gain the three new fields as scaffolding only — every
    shipped expectation for family, excluded, and unloaded
    lines is unchanged.
13. **Existing blocks byte-identical gate:** every other
    pre-existing UI test passes unmodified; the only render
    changes in either detail are the three conditional lines
    inside the DPS block and the disclosure wording.

Gates at every commit: `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`,
`cargo build`. Nothing is live-verified against EVE by this
slice (all inputs are bundled data and pasted text).

## 9. Integrator list

- `README.md`: extend the existing fitting damage-per-second
  sentence — do not add a second feature claim — to cover volley
  (turret plus launcher, one cycle, the same listed EFT charges)
  and volley-weighted turret optimal/falloff ranges, keeping the
  no-bonuses, no-application, and no-combined-DPS-total
  qualifications in the same words the disclosure uses.
- `docs/fitting-dps-design.md`: one amendment only — the
  section 10 bullet excluding volley / optimal-range / falloff
  lines gains a pointer to this design as superseding it. No
  other line of that document moves, so it stays the accurate
  record of the shipped slice.
- `docs/engineering-journal/LEARNINGS.md`: dated entry for (a)
  the Entropic Disintegrator falloff absence (34 of 636 true
  turrets carry 54 with no 158) making strict per-attribute
  completeness a shipped-data behaviour, not a fixture edge, and
  (b) attribute 54's triple naming (dogma `maxRange`, display
  "Optimal Range", Flutter `optimalRange`) with the catalogue
  following the dogma name. Evidence, Mechanism, and the
  generalizable rule (an average over "the rows that have the
  attribute" is a different number from an average over the
  fitted set; pick one and say which).
- `docs/engineering-journal/DECISIONS.md`: dated entry covering
  (a) one combined volley against the no-total rule, (b) strict
  completeness against Flutter's absent-is-zero weighting, (c)
  category-7-only emission against the 7-and-18 DPS gate, each
  with rationale, rejected alternatives, and a revisit
  condition.
- This design file is the design commit; no other docs move in
  builder commits.

## 10. Exclusions (explicitly not in this slice)

- **Tracking and every form of damage application:** attribute
  160 `trackingSpeed` is never emitted or read; no tracking
  formula, no hit-chance, no range or falloff damage curve, no
  target signature, velocity, or resistance term. The range
  lines are unapplied base attributes averaged as section 4
  locks — they change no damage number.
- Per-weapon, per-turret, or per-family volley and range lines.
- Drone and fighter volley, optimal, and falloff, including
  sentry-drone ranges — even though the cache carries 54 / 158
  rows for drones; likening a drone firing cycle to the
  ship's volley has no quoted body behind it.
- Missile range of any kind (flight time, missile velocity):
  launchers carry neither 54 nor 158 and Flutter shows no
  launcher range; a missile-only fit's missing range lines are
  honest absence, not a gap to fill schematically.
- Skills, implants, ship bonuses, module and rig range or
  damage bonuses, and every other modifier; attributes 243 and
  517 are never emitted or read. The effective-only Flutter
  oracles stay unimplemented with the modifier engine they need.
- Any change to shipped DPS values, the charge rules, family
  availability, the excluded / unloaded counting, or the
  `Unavailable` rule; any charge storage, compatibility check,
  demo-data, ESI, scope, or storage change.
- Volley and range on the saved or DNA surfaces by any means,
  including joining cargo charges (forbidden by the shipped
  design and by ranking rule 1 here).

## 11. Ownership and commit split

Small atomic commits, `type(scope): description`, no attribution
lines. Nothing is pushed or merged by builders; the parent does
that. Resolved names only in UI text (the new lines render no
type names). No new log lines anywhere in this slice: the pure
function and the render function run at render cadence and log
nothing (the shipped block's precedent), the loader's counts
line is unchanged, and generator counts print through the
existing summary. Where the repo rule calls for debug logging
with a `[FEATURE]` tag, the shipped render-cadence exemption for
this exact block is the standing decision and builders do not
invent per-frame logging.

1. **Design (this commit):** `docs(dps): design base volley and
   turret ranges` — only `docs/volley-ranges-design.md`.
2. **Builder A — data and pure layer, zero `src/ui/` changes:**
   (a) `feat(sde): emit turret range attributes for fitting
   types` — generator extension + regenerated catalogue with the
   section 3.4 proofs and actual byte count in the commit body;
   (b) `feat(fitting): add base volley and turret ranges to dps
   calculation` — loader fields/invariants + the section 4
   additions to `src/fitting/dps.rs` with their tests
   (section 8 tests 1–9). Builder A owns
   `scripts/sde/generate_fitting_types_sde.py`,
   `assets/sde/fitting_types.json`, `src/names/fitting_types.rs`,
   `src/fitting/dps.rs`. No `src/fitting/mod.rs` change is
   expected (no new module); any needed API change beyond
   section 4 goes back through this design (amend this file in
   its own commit), never a silent rendezvous edit.
3. **Builder B — rendering, zero generator/catalogue/loader/
   pure changes:** `feat(fittings): show base volley and turret
   ranges in fitting details` — the three conditional lines, the
   placement order, and the replacement disclosure in
   `src/ui/fittings.rs` only, with UI tests (section 8 tests
   10–13), including the `FittingDps` test-literal scaffolding
   for the three new fields. Depends on Builder A's public API
   exactly as locked in section 4.
4. **Integrator:** README + the one-line DPS-design pointer +
   engineering journal (section 9) as
   `docs(dps): document base volley and turret ranges`; final
   full gate run (`cargo fmt --check`, `cargo clippy
   --all-targets -- -D warnings`, `cargo test`, `cargo build`);
   demo smoke of both details against section 7; confirmation
   that existing blocks are byte-identical apart from the
   disclosure wording.




