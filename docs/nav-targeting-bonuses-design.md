# Fitted-module navigation and targeting bonuses — design

Status: locked for the `feat/rust-nav-targeting-bonuses`
slice. Base: `develop` at `5cd2e0d` (PRs #561–#620
merged). Slice branch: `feat/rust-nav-targeting-bonuses`.
This document is the single design commit; builders
implement exactly what is locked here and nothing else.
It extends the shipped base block of
`docs/nav-targeting-design.md` ("Ship navigation and
targeting (base values)") and follows the resistance
bonuses slice (`docs/resistance-bonuses-design.md`,
#615), the hit point bonuses slice
(`docs/hp-bonuses-design.md`, #617), the capacitor
bonuses slice (`docs/cap-bonuses-design.md`, #618), the
shield recharge bonuses slice
(`docs/shield-recharge-bonuses-design.md`, #619), and the
output bonuses slice (`docs/output-bonuses-design.md`,
#620) for emission and computation shape; where this
document says "mirrors #618" or "mirrors #620", that
wording and structure are the precedent and do not need
relitigating. The earlier design documents are not
edited.

Every name, formula, count, and oracle number below
traces to an inspected body at `5cd2e0d` —
`src/fitting/ship_nav_targeting.rs`,
`src/fitting/ship_resistances.rs`,
`src/fitting/ship_stats.rs`,
`src/names/fitting_types.rs`, `src/ui/fittings.rs`,
`src/fitting/mod.rs`,
`scripts/sde/generate_fitting_types_sde.py`, the design
documents above, `assets/demo/fittings.json`, the
committed subnormal fix `2ac348f` — or to a design-time
census over the committed SDE data (`dogmaEffects.jsonl`
and `dogmaAttributes.jsonl` inside
`scripts/sde/eve-online-static-data-3503375-jsonl.zip`
joined through the committed `scripts/sde/*.csv.bz2`
caches and the bundled catalogue; section 2 quotes its
counts, and every oracle operand in sections 3 and 8 was
re-read from those bodies at design time and the census
counts independently recomputed), or to the inspected
Flutter bodies at `ed698d3`
(`lib/features/fitting/domain/dogma_engine.dart`,
`dogma_attributes.dart`, `models.dart`,
`stats_panel.dart`, and the Flutter engine tests), or to
hand arithmetic over values those bodies pin (shown in
section 8). No convention here comes from EVE folklore or
memory. Raw EVE type IDs never appear in any rendered
string in this slice; type IDs below are internal oracle
pins only, as in #615.

## 1. Goal and value ranking

Apply fitted items' navigation and targeting bonuses to
eleven of the twelve candidate dogma attributes — warp
speed multiplier (600), agility (70), mass (4), signature
radius (552), max target range (76), scan resolution
(564), the four sensor strengths (208, 209, 210, 211),
and max locked targets (192) — and show the result in one
new block, "Ship navigation and targeting (with fitted
module bonuses)", on both fitting detail surfaces
(imported and saved), immediately after the shipped base
block. Per attribute:

```text
bonused value = (hull base + Σ flat adds)
                × Π multipliers
                × Π (1 + percent / 100)
```

Align time is re-derived from the bonused agility and
bonused mass by the shipped closed form (section 2);
targeting range converts metres to kilometres after the
bonus; the locked-target count converts by the
Flutter-grounded rule of section 2. The twelfth
candidate, max velocity (dogma 37), is **locked out of
this slice entirely** — no emission, no bonused line, no
count — because its dominant carriers are invisible to
the plain modifier path (section 2, "Max velocity (37)
is deferred"). No network, no ESI changes, no new scopes,
no persistence.

**A new block; the base block is byte-identical
(locked).** This slice follows #615/#617/#618/#619, not
#620's in-place divergence, for #620's own stated reason:
#620 changed an existing block because its figure is one
side of a shipped used-vs-output comparison. Every
navigation and targeting figure is a standalone quantity
exactly like a resistance or a hit point total, the base
block's disclosure promises fitted bonuses are not
applied to *its* numbers, and that promise stays true and
unedited (section 7 inventories every shipped sentence
this slice touches or deliberately leaves alone). The
bonused block renders even when its numbers equal the
base block's, as every sibling bonused block does.

**One generalized leg and one generalized helper
(locked).** The attributable set is wide — eleven
attributes, 367 distinct category-7 carrier types — but
every attribute takes the identical grounded shape
(plain category-7 `ItemModifier`/`shipID`, operators
{2, 4, 6}, the section-2 formula). This slice therefore
ships **one** generator leg driven by a single locked
attribute-order constant, emitting eleven per-attribute
families mechanically (section 3); **one** Rust modifier
struct; and **one** generalized pure helper iterating the
same order over `[Option<f64>; 11]` bases and per-index
run lists (section 4). Per-attribute bespoke emission or
computation code — eleven hand-copied legs, eleven
helpers — is rejected: it would replicate the #618
two-family code eleven times to no behavioural end and
invite exactly the copy drift (a fixed guard applied to
ten copies) the siblings' shared `counted_flag` /
`mul_product` reuse exists to prevent. What stays
per-attribute is only what honesty requires per
attribute: its own catalogue keys, its own marked set,
its own unapplied count, and its own oracle set (the
cross-pardon evidence of section 2 forbids merging those
even into one combined family).

Value ranking (locked, in order), extending the
siblings':

1. **No bonused figure ever reads as complete when a
   counted carrier's bonus could not be applied, and no
   attributable bonus is silently dropped.** Each of the
   eleven attributes carries its own unapplied count,
   disclosed on its own line (sections 4, 6, 7); a
   carrier the bundled data cannot ground in one
   attribute never has that defect forgiven by its
   applicable bonus in another. The same ranking is what
   locks max velocity out rather than shipping it
   plain-only (section 2): a silently base max speed on
   an afterburner fit, with no possible count, is the
   failure this ranking exists to prevent.
2. **Correctness and exactness of the composition.**
   Adds before multipliers before percents, in catalogue
   units, at full `f64` precision, in the siblings' locked
   float association, so a fitting with no counted
   carrier yields a bonused struct bit-identical to the
   shipped base struct (sections 2, 4, 8). Absence never
   renders as a number and never resurrects as zero
   (section 5); a positive subnormal bonused value is
   stall residue, not data (the `2ac348f` guard); the
   integer count converts by the inspected Flutter rule
   and by no other (section 2).
3. **No deficit is silently dropped, in any dimension,
   and no two counts are ever summed.** One shared
   excluded count (catalogue-absent counted rows) and
   eleven per-attribute unapplied counts, each on its own
   line, each `None` at zero (sections 6, 7). Eleven
   counts are not eleven noise lines: on shipped data
   seven of the eleven marked sets are empty, and the
   worst case is bounded and inventoried in section 6.
4. **Reuse.** The #615/#617/#618/#619/#620 generator
   classification, catalogue tuple shape, loader shape,
   counted-item scan, and bounded run arithmetic; the
   shipped `ShipNavTargeting` struct, line builders, and
   align helper consumed unchanged; the shipped
   count-line sentence shapes — all beat new machinery
   (sections 3, 4, 6).

Non-goals are locked in section 9. In particular: no
propulsion (afterburner/microwarpdrive) velocity, no
script or charge effects, no skills, no ship traits, no
implants, and no subsystem bonuses (category-32 carriers
are locked out exactly as in every sibling, even though
subsystem slots are counted slots at runtime). Each of
those exclusions is named in the block's own disclosure
(section 7), not only here.

## 2. Modifier set, arithmetic, and supersession (locked)

**Supersession.** The navigation and targeting design
locked "bare-hull base values only, no modifier of any
kind" as that slice's depth and barred the modifier-input
attributes (`massAdd 796`, `signatureRadiusAdd 983`, and
kin) as value sources in a base-only slice (its sections
2.4, 2.7, 10). This slice supersedes, as slice
boundaries: that base-only depth for the eleven
attributes below (→ sections 2–4 here), and the
base-only bar on those modifier inputs *as modifier
operands* (they are read by the generator exactly as
every sibling reads its modifying attributes, section 3).
What is **not** superseded: the base block, its heading,
its disclosure, and every number in it; dogma 4 as a
*value source* (mass base stays the `invTypes` column,
below); the 1281 warp tripwire; the agility-has-no-line
rule; the sensor joined-line presentation; the range
`/ 1000` conversion; every #615–#620 semantic (counted-flag
set, bounded arithmetic, the `2ac348f` subnormal rule);
Max speed in the #578 "Ship (base values)" block; any
number in any other block. A builder who believes this
design requires changing any of those stops and records it
against this document.

**Grounded modifier shape (locked — ships, the whole
set).** A fitted item contributes a navigation or
targeting modifier only when all of these hold, mirroring
#618 section 2 with the eleven-attribute set substituted:

- its catalogue row is category 7 (module, including
  rigs — category-7 rows with slot effect 2663);
- one of its effects (joined through
  `dgmTypeEffects.csv.bz2`) carries a modifier with
  `func == ItemModifier` and `domain == shipID` — the
  plain self-to-ship path only; every filtered, remote,
  charge-mediated, or expression-tree shape is section
  9's, by name;
- that modifier's modified attribute is one of the eleven
  in the locked order below;
- its operator is `2`, `4`, or `6` (below);
- the operand — the item type's own `dgmTypeAttributes`
  `valueFloat` for the modifier's modifying attribute —
  is present, finite, and not `0.0`.

**Emission order `[600, 70, 4, 552, 76, 564, 208, 209,
210, 211, 192]` (locked, justified).** This is the
shipped display order everywhere an order is needed:
`ShipNavTargeting` field order (warp, align, agility,
mass, signature, range, scan, sensors, locks —
`ship_nav_targeting.rs:44-72`), the rendered line order
(`ship_nav_targeting_lines`, `fittings.rs:2855-2869`, with
mass the third line and agility its align-input
predecessor), and the base design's section-2 table. The
align pair (agility 70, mass 4) therefore sits adjacently
at positions 2–3 even though the *base* catalogue keys
emit `mass` last (its `invTypes` provenance, base design
section 3): the modifier families are new keys with no
append-only history of their own, and the accumulator
positions, key order, count fields, and count lines of
this slice all follow the one display order rather than
splitting the align inputs across the sensor block.

| Pos | Attr | Dogma name | Base source (shipped) | Unit |
|---|---|---|---|---|
| 0 | 600 | `warpSpeedMultiplier` | catalogue `warpSpeedMultiplier` under the 1281 invariant | AU/s (base design §2.1) |
| 1 | 70 | `agility` | catalogue `agility` | `x` — align input, no line |
| 2 | 4 | `mass` | `invTypes` column via catalogue `mass` (below) | kg |
| 3 | 552 | `signatureRadius` | catalogue `signatureRadius` | m |
| 4 | 76 | `maxTargetRange` | catalogue `maxTargetRange`, raw m | m → km after bonus |
| 5 | 564 | `scanResolution` | catalogue `scanResolution` | mm |
| 6 | 208 | `scanRadarStrength` | catalogue `scanRadarStrength` | points |
| 7 | 209 | `scanLadarStrength` | catalogue `scanLadarStrength` | points |
| 8 | 210 | `scanMagnetometricStrength` | catalogue `scanMagnetometricStrength` | points |
| 9 | 211 | `scanGravimetricStrength` | catalogue `scanGravimetricStrength` | points |
| 10 | 192 | `maxLockedTargets` | catalogue `maxLockedTargets` | bare count |

**Mass base (locked, restated so no builder goes hunting
for dogma 4 rows).** Dogma 4 has zero rows on catalogue
ships (base design section 2.4); the bonused-mass formula
applies dogma-4-*targeted* modifiers to the shipped
catalogue `mass` field (the `invTypes` column, loaded as
`FittingType::mass`), which is precisely Flutter's own
route: its generator injects the `invTypes` mass as
attribute 4 ("mass lives in the invTypes column, not in
dgmTypeAttributes, but dogma consumers (align time) need
it as attribute 4", quoted in the base design), after
which plate `massAdd 796` operands add to it in kg. The
modified attribute id in every emitted mass triple is
therefore `4`, and the base it modifies is never a dogma
read.

**Supported operations (locked, with evidence).** All
eleven attributes take the siblings' hp/capacitor/shield/
output operator set {2, 4, 6} — not resistance's {0, 6} —
each code grounded in the inspected Flutter ship path
(`routeOwnerModifiers` routes `ItemModifier`/`shipID` by
operator into add/mul/percent accumulators with scale
1.0 for fitted items; the final loop composes them;
`dogma_engine.dart:25-34, 109-110, 534-581, 806-823` at
`ed698d3`), and every attribute's censused category-7
carrier population exercises only codes in that set
applicably:

- **Operator 2, modAdd — flat add.** Flutter `_modAdd =
  2`. Census carriers: mass plates (48 entries via 796
  `massAddition`, 20,000–88,000,000 kg); signature shield
  extenders (32 entries via 983 `signatureRadiusAdd`,
  2.0–1,200.0 m); warp accelerators (3 entries via 1950,
  0.2/0.25/0.3); locked targets (all 15 entries via 235,
  1.0–5.0). Grounded and emitted wherever present on any
  of the eleven, exactly the #619 treatment — never
  invented for attributes whose carriers lack it today
  (600's three and 192's fifteen are real; 70/76/564/208–
  211 have no applicable operator-2 entry today).
- **Operator 4, postMulAlt — multiplier.** Flutter
  `_postMulAlt = 4`, one of `_isMul`. Census carriers:
  mass cores (11 entries via 1471, ×10.0); signature
  suppressors (10 entries via 3113/3114, 0.2–0.9 — the
  dual-entry case below); scan-resolution cloaks and
  stabilizers (24 entries via 565, 0.5–0.78).
- **Operator 6, postPercent — percent.** Flutter
  `_postPercent = 6`, chaining `1 + value/100`. Census
  carriers: all 98 agility entries (via 151/169/1138,
  −55.0 to +5.0); 95 of the signature entries (inertial
  stabilizers via 554 and every rig's +10.0 drawback via
  1138); all 43 targeting-range entries (via 309, −50.0
  to +39.0); 32 scan-resolution entries (via 566, up to
  the Networked Sensor Array's 500.0); all 100 sensor
  entries (via 1027–1030, 36.0–100.0); warp rigs (12
  entries via 624/1138); Higgs/Zero-Point mass percents
  (5 entries via 1131).

**The one dual-entry case (locked).** Every applicable
category-7 carrier has at most one applicable entry per
attribute, with exactly five censused exceptions, all in
the signature family: the Signature Radius Suppressors
4409, 83643, 83644, 83660, 83661 each carry two distinct
`ItemModifier`/`shipID` triples on
552 — via 3113 and via 3114, both operator 4 (4409:
`[[552, 4, 0.9], [552, 4, 0.3]]`). Both entries emit and
both apply (the no-module-state rule: the fitting data
does not say which state the module is in, and Flutter's
per-effect routing collects both multipliers into the
same product). Section 3 relaxes the siblings'
duplicate-modified loud failure for the signature family
only, to at most two entries; a third, or a second entry
in any other family, still stops generation. No type in
any family has a duplicated (modified, modifying,
operator) triple (censused, and locked as a loud failure
in section 3 — a duplicated triple would double-apply in
Flutter's per-effect routing and is never deduped away).

**Unsupported operations (locked: counted, never
guessed).** Operators outside {2, 4, 6} with a present
non-zero operand are classified **unsupported**:
generator marks the type unapplied *in that attribute's
family* and emits no entry for that triple (section 3);
the pure layer guards identically (section 4). On shipped
data exactly one such population exists, and it is locked
by name because it is this slice's one deliberate Flutter
divergence: **scan resolution (564) operator 0
(postMul).** Four category-7 types carry an operator-0
triple on 564 via 565 — Triage Module I/II 27951/4294 at
10.0, Capital Industrial Core I/II 28583/42890 at
2.0/2.2. Flutter's `_isMul` includes 0, so Flutter applies
a ×10.0 scan resolution to a triage fit; every shipped
Rust sibling on the {2, 4, 6} path would count it instead.
This slice counts it: the four types are the scan
resolution family's marked set, their scan bonus is not
applied, and the block says so on the scan resolution
count line. Grounding operator 0 for this family alone —
a fourth operator admitted for one attribute on four
types, with no sibling precedent for a mixed set and no
Flutter test pinning the triage figure — is rejected in
favour of the uniform censused set plus an honest count;
a future slice that wants the ×10.0 reopens exactly this
paragraph with its own census. Every other operator
outside {2, 4, 6} on the eleven attributes (the zip's
operator −1/5/7 rows, operator 3) has zero category-7
carriers today and takes the same counted treatment if
one ever appears.

**Census (locked counts).** Scripted over the committed
data (zip `modifierInfo` ⋈ `dgmTypeEffects` ⋈
`dgmTypeAttributes` ⋈ the bundled catalogue, category 7
only — 3,925 catalogue rows — the four-way classification
of section 3 applied **per attribute**), and independently
recomputed at design time with identical results:

| Attr | Carriers | Applicable types | Entries | Marked | Zero-only |
|---|---|---|---|---|---|
| 600 warp | 15 | 15 | 15 (12 op6, 3 op2) | 0 | 0 |
| 70 agility | 98 | 98 | 98 (all op6) | 0 | 0 |
| 4 mass | 68 | 64 | 64 (48 op2, 11 op4, 5 op6) | 4 | 0 |
| 552 signature | 138 | 132 | 137 (32 op2, 10 op4, 95 op6) | 3 | 3 |
| 76 range | 49 | 43 | 43 (all op6) | 6 | 0 |
| 564 scan res | 60 | 56 | 56 (24 op4, 32 op6) | 4 | 0 |
| 208 RADAR | 25 | 25 | 25 (all op6) | 0 | 0 |
| 209 Ladar | 25 | 25 | 25 (all op6) | 0 | 0 |
| 210 Magnetometric | 25 | 25 | 25 (all op6) | 0 | 0 |
| 211 Gravimetric | 25 | 25 | 25 (all op6) | 0 | 0 |
| 192 locks | 15 | 15 | 15 (all op2) | 0 | 0 |

540 family-rows carry a key (applicable or marked), 528
entries in total, 17 marked family-rows, on 367 distinct
category-7 types. The marked sets, named because their
count lines render on real fittings: mass — the abyssal
plates 47812, 47817, 47820 (796 absent) and Abyssal Siege
Module 56313 (1471 absent); signature — the abyssal shield
extenders 47800, 47804, 47808 (983 absent), beside three
zero-only extenders (8427, 20627, 28742 at 983 = 0.0, which
emit neither signature key); range — the Auto Targeting
family 1182, 1436, 6041, 6043, 6045, 6047 (237 absent on an
operator-4 triple); scan resolution — the operator-0
population above. The four sensor carrier sets are
identical type-for-type (the carrying effects hold four
parallel triples, via 1030/1028/1029/1027 respectively, and
the operands co-vary: Sensor Booster II and Signal
Amplifier II at 48.0 each, Bastion Module I at 100.0 each);
they are still four families, because counting is per
dimension and a future single-sensor carrier must not be
pardoned by its neighbours. Published ECCM and sensor rigs
contribute nothing: the ECCM module family and the Sensor
Strength Rigs are unpublished in the SDE, so they have
zero catalogue carriers — the sensor families' 25 carriers
are sensor boosters, signal amplifiers, and kin only.

**Per-attribute families are forced, not chosen
(locked).** 66 of the 367 carrier types carry triples on
more than one of the eleven attributes, and the shipped
data contains both cross-pardon shapes the #618 split
exists to prevent. Auto Targeting System I 1182 is
applicable on 192 (`[[192, 2, 2.0]]`) and absent-only on 76:
a combined family would see the applicable entry and
silently forgive the missing range operand. Triage Module
I 27951 is applicable on 4 (`[[4, 4, 10.0]]`) and 192
(`[[192, 2, 4.0]]`) and unsupported on 564: a combined
family would forgive the operator-0 triple the same way.
A single combined emission with one unapplied marker is
therefore rejected on shipped data, not on hypothesis; a
combined emission carrying a per-attribute unapplied id
list is likewise rejected as a shape with no sibling
precedent, new counting semantics, and no saving worth
either. Classification, marking, and counting are per
attribute on every leg; cross-family rows (Signal
Amplifier II 1987 carrying seven families, Small Higgs
Anchor I 34266 carrying warp/agility/mass) are the norm
and are judged independently per family, undisturbed.

**Arithmetic (locked, Flutter ship path verbatim).** For
each of the eleven attributes independently, in catalogue
units:

```text
bonused = (hull base + Σ operator-2 operands)
          × Π operator-4 operands
          × Π (1 + percent / 100)
```

Sources, all at `ed698d3`: operator codes `_modAdd = 2`,
`_postMulAlt = 4` (one of `_isMul`), `_postPercent = 6`
(`dogma_engine.dart:25-34, 109-110`); the
`ItemModifier`/`shipID` route summing adds and collecting
muls and percents at scale 1.0 for fitted items
(`:534-581`); the final composition `value = (base + Σ
adds) × Π mul × _percentChain(percent)` over every touched
attribute (`:806-823`), the chain sorting by absolute
value descending (`:168-179`). Locked consequences builders
must not "improve":

- **Exact float association (locked, so no-carrier
  fittings are bit-identical to base).** The siblings' run
  association (section 4): add runs summed as `operand ×
  (count as f64)` in first-seen order from `0.0`; mul runs
  folded through the shared bounded `mul_product` from
  `1.0`; percent runs **sorted by absolute value
  descending** (stable sort, the siblings' `sort_by` on
  `total_cmp` of `abs`), each folded as `mul_product(1.0 +
  value / 100.0, count)` from `1.0`; then `(base +
  add_total) * mul_total * percent_total` in that
  association. With no entry, each attribute reduces to
  `(base + 0.0) * 1.0 * 1.0` — the base, equal under `==`
  for every usable base that is exact `0.0` or normal (the
  subnormal qualification below). Section 8 pins the whole
  struct by `assert_eq` against the shipped base function.
- **No stacking penalty on any of the eleven, in any
  class.** Verified from the inspected body, never
  assumed: Flutter's `_percentChain` applies
  `getStackingPenalty` only when the attribute is in
  `_nonStackableAttributes` — exactly the twelve
  resonances, whose comment reads "Everything else ESI
  points at (cpu, powergrid, velocity, ...) is stackable"
  (`:112-128, 168-179`); none of the eleven is in that set.
  Every fitted unit contributes its full factor, and a
  quantity-`q` row contributes `q` factors (the run count).
  `resistance_stacking_penalty` and `percent_chain` are
  never called on this path. The percent sort is kept
  anyway: without a penalty it cannot change which factors
  apply, but it fixes the fold order the identity pins
  rely on. Named here so review does not "fix" it toward
  folklore; the block's disclosure keeps its "can differ
  from EVE" sentence (section 7).
- **Bonuses can shrink every value, and nothing clamps.**
  Warp Core Stabilizers cut targeting range by 50 as
  written, cloaks multiply scan resolution by 0.5, Higgs
  Anchors cut warp by 10 and raise mass by 100, bulkheads
  *raise* agility (worse align) by up to 5. There is no
  floor at base, no ceiling, and no "bonus must help"
  filter — the #619 slower-than-base rule on all eleven.
- **Positive subnormal is no data — the `2ac348f` guard,
  from day one, per attribute.** Each bonused result is
  filtered by the shipped predicate verbatim — `v.is_finite()
  && *v >= 0.0 && (*v == 0.0 || v.is_normal())`
  (`ship_resistances.rs:837, 978, 1207`). A positive
  subnormal is stall residue from a hostile-quantity run
  underflowing toward zero; an exact `0.0` stays a real
  zero (a present-`0.0` base, or a −100 percent, computes
  honestly to `Some(0.0)` and renders). A fixture base that
  is itself a positive subnormal passes the usability
  filter and is then rejected by the result filter for
  that attribute only, exactly as `bonused_capacitor`
  treats it; catalogue values are ordinary magnitudes, so
  the identity claims in section 8 are unconditional on
  shipped data. What a per-attribute `None` does to the
  block is section 5's lock (that field's line is omitted;
  every computable field still renders).
- **Absent base is never resurrected — the house divergence
  from Flutter, named again.** Flutter's base fallback (0.0
  if add-only else 1.0, `:806-823`) is *not* adopted: an
  attribute whose hull base is absent, negative, or
  non-finite stays `None` however many bonuses target it.
  A sensor booster never invents a sensor on a hull whose
  strength row is missing; a plate never invents a mass.
  A *present* `0.0` base is a real zero and bonuses apply
  to it normally ((0 + adds) × … — section 8 pins a flat
  signature add and a target add landing on zero bases).
- **Conversions happen after the bonus, in the wrapper,
  exactly where the base block converts (locked).** The
  helper works in raw catalogue units on all eleven
  (metres for 76, an `f64` for 192). Targeting range
  converts `/ 1000.0` once, after bonusing — never bonus
  the kilometre figure, so a future flat metre add cannot
  land a thousand-fold large. The count converts by the
  integer rule below. Warp needs no conversion: the
  bonused 600 value *is* the warp speed in AU/s under the
  shipped 1281 invariant (the generator tripwire is
  unchanged and still fails generation before any wrong
  number can render; no 1281 value is emitted or read).
- **Align time is re-derived, never bonused (locked,
  bit-association).** No dogma attribute carries align
  time. The bonused block feeds the bonused agility and
  bonused mass `Option`s back into the shipped private
  helper `align_time_secs` (`ship_nav_targeting.rs:115-124`)
  — the same function body, whose expression
  `ALIGN_TIME_FACTOR * agility * mass / 1_000_000.0`
  associates left-to-right as `((FACTOR × agility) × mass)
  / 1e6` with `FACTOR = 1.3862943611198906` (`-ln(0.25)`).
  Builders must not re-inline or reassociate it: the helper
  re-guards both inputs finite and `> 0` and the result
  finite, so a bonused agility or mass of exact `0.0`, or
  either input `None`, yields align `None` while the mass
  line still renders. Flutter cross-pins survive: its
  plate test (Rifter + 1600mm plates, mass 1,067,000 →
  4,817,000, align `closeTo(21.369, 0.01)`) and extender
  test (signature 35 → 42) are reproduced as Rust oracles
  in section 8 from the same catalogue operands.
- **Counted vs consuming populations (locked).** The
  bonused scan is the siblings' counted population
  (`counted_flag`: Lo/Med/Hi plus rig and subsystem slot
  flags, `ship_resistances.rs:296-302`), never
  `resources.rs`'s consuming scan: most agility, warp, and
  signature-drawback carriers are rigs. A carrier under a
  non-counted flag (cargo, drone bay, charges — including
  sensor scripts, section 9) contributes nothing and
  counts nowhere. Slot belonging is never judged, as
  shipped.
- **No module state**, as #615 locked: every counted
  fitted item contributes as if active, including both
  suppressor multipliers and every cloak's penalties.
  That assumption is user-visible wording in the block's
  disclosure (section 7).

**Max locked targets: the integer rule (locked, from the
inspected Flutter body — never guessed).** The base count
is integral-or-`None` (`usable_count`,
`ship_nav_targeting.rs:100-104`: finite, `>= 0.0`,
`fract() == 0.0`, `<= 2^53`, never rounded or clamped),
and no shipped Rust body floors a dogma count. The bonused
conversion is therefore grounded where post-modifier
semantics live: Flutter computes `attr(192)` through the
same generic `(base + adds) × mul × percent` composition
as every other attribute and then reads the stat as
`maxLockedTargets: attr(192).toInt()` (final stats block,
`dogma_engine.dart` at `ed698d3`; `models.dart` carries it
as an `int`; `stats_panel.dart` renders the bare integer).
Dart `double.toInt()` truncates toward zero. Locked rule:
the bonused `f64` — after the section-2 result filter
(finite, `>= 0.0`, exact `0.0` or normal) and the base
rule's `<= 2^53` cast-safety bound — converts to `i64` by
**truncation toward zero**; anything failing those guards
is `None`, never a rounded, clamped, or saturated count.
Two recorded qualifications keep this honest rather than
clever. First, on shipped data the rule is the identity:
every censused applicable 192 entry is operator 2 with an
integral operand in {1.0, 2.0, 3.0, 4.0, 5.0} and every
hull base is integral (the shipped generator fails loud on
a non-integral base), so no real fitting's count is ever
truncated — truncation is reachable only by fixture or
future operands, where section 8 pins it as asserted
behaviour (a fixture 4.5 renders 4, and the test comment
names this paragraph as its authority, not folklore).
Second, the divergence from the base block's
integral-or-`None` is deliberate and narrow: a non-integral
*catalogue* count is corrupt data and stays `None`; a
non-integral *computed* count has an inspected engine rule
and follows it. A negative computed count is filtered to
`None` before conversion (it never truncates up to 0), and
a computed exact `0.0` is `Some(0)`. Had the Flutter body
carried no conversion — had 192 been display-only or
absent there — this design would have locked 192 out with
37; it carries one, so 192 ships.

**Max velocity (37) is deferred (locked out, with the
evidence that forces it).** The plain census on 37 is real
— 82 category-7 carriers, 75 applicable types (overdrives
and nanofibers via 1076, thruster rigs via 315, cloaks and
expanded cargoholds via 306 at multipliers down to 0.1,
siege-class −100.0 percents via 20) — and on its own it
would pass every gate above. It is locked out because the
plain path is *incomplete in a way it cannot disclose*:
afterburners and microwarpdrives, the dominant velocity
bonus on real fittings, carry **no** zip modifier rows at
all. Their effects 6730/6731 return empty modifier lists
(their bonus lives in a dogma expression tree ESI does not
publish as modifiers — Flutter's inspected comment,
`dogma_engine.dart:134-142` at `ed698d3`, "verified live on
2026-09-07"), and Flutter grounds them only through a
curated table, `_expressionTreeSpeedEffects = {6730: (37,
20), 6731: (37, 20)}`, reading each type's `speedFactor`
(20) operand (Afterburner I/II 115/135, Microwarpdrive I/II
500/510 — factors ×2.15 to ×6.1) into the same percent
accumulator. At design time the 73 catalogue carriers of
6730 and 75 of 6731 (e.g. 5MN Microwarpdrive I 434, 1MN
Afterburner II 438) were re-verified to carry zero
`ItemModifier`/`shipID` triples on 37: a plain-only
emission cannot see them, cannot mark them, and therefore
cannot count them — it would render base max speed on a
microwarpdrive fit, short by up to ×6.1, under a
"(with fitted module bonuses)" heading with every count at
zero. That is a deficit silently dropped, which ranking 1
forbids. Locked instead: no velocity family, no emission,
no bonused max speed anywhere; `Ship (base values)` and
its `Max speed: … m/s` line are byte-identical to today,
and the new block's disclosure states plainly that max
speed is not included and afterburner/microwarpdrive
bonuses are not applied anywhere (section 7). A future
velocity slice must first design the effect-detection leg
the census cannot ground — effects 6730/6731 membership
plus a `speedFactor` operand pass, with its own
unapplied/count semantics for propulsion modules whose
operand is absent — and only then add the twelfth family
to the order below under its own design. Nothing in this
slice pre-emits, half-emits, or reserves a key for it.

## 3. Catalogue extension (locked)

The bundled catalogue gains per-type navigation and
targeting modifier entries through its existing generator
only, mirroring #618 section 3 (the two-family shape)
generalized to eleven families in every particular this
section does not state. Hand-editing the JSON is
forbidden. Catalogue today: 3,886,379 bytes, sha256
`ee17d56abc663ea7b6b4bce7df12676d53d07b9b2c238207e1b0f14e019fc5c3`
(`assets/sde/fitting_types.json`, re-hashed at design
time; the output bonuses slice's regenerated asset).

**Generator changes**
(`scripts/sde/generate_fitting_types_sde.py`). One
generalized leg, not eleven: the leg reuses the inputs the
resistance leg already reads — `dogmaEffects.jsonl` from
the committed zip (fail-loud if missing or unreadable),
`dgmTypeEffects`, `dgmTypeAttributes`, and the category
map — extending the wanted-modifying-ids assembly (lines
1780–1819) with a `wanted_nav_targeting_modifying_ids` set
beside the output one, so one operand pass serves all
legs; the operand-label helper (`modifier_operand_label`,
line 1830) gains a "navigation and targeting modifier
operand" label for ids wanted by this leg alone, and ids
wanted by more than one leg keep the generic label (1138,
the shared rig drawback, is one). No second zip read; the
generator still never downloads; the header comment gains
the navigation and targeting keys paragraph after the
output paragraph.

- Beside `OUTPUT_MODIFIER_ORDER` (line 337), add the
  locked constants with a provenance comment citing
  `dogmaEffects.jsonl`, `dogmaAttributes.jsonl`, the
  caches, and Flutter `dogma_engine.dart` /
  `dogma_attributes.dart` at `ed698d3` for the attribute
  ids, the operator codes, and the absent/zero skip:

  ```python
  NAV_TARGETING_MODIFIER_ORDER = [600, 70, 4, 552, 76, 564, 208, 209, 210, 211, 192]
  NAV_TARGETING_MODIFIER_OPERATORS = {2, 4, 6}
  NAV_TARGETING_MODIFIER_ATTRS = {600, 70, 4, 552, 76, 564, 208, 209, 210, 211, 192}
  NAV_TARGETING_MODIFIER_KEYS = {
      600: "warpSpeedMultiplierModifiers",
      70: "agilityModifiers",
      4: "massModifiers",
      552: "signatureRadiusModifiers",
      76: "maxTargetRangeModifiers",
      564: "scanResolutionModifiers",
      208: "scanRadarStrengthModifiers",
      209: "scanLadarStrengthModifiers",
      210: "scanMagnetometricStrengthModifiers",
      211: "scanGravimetricStrengthModifiers",
      192: "maxLockedTargetsModifiers",
  }
  ```

  Each key is the attribute's full dogma name plus
  `Modifiers` (the `capacitorCapacityModifiers`
  precedent); each family's marker key is its array key
  plus `Unapplied`. The order is section 2's, everywhere
  an order is needed.
- Build **eleven** per-type entry maps in one loop over
  `NAV_TARGETING_MODIFIER_ORDER` beside the output maps
  (the per-family construction at lines 2270–2421 is the
  shape, driven by the order constant instead of copied
  eleven times), each classifying every
  `ItemModifier`/`shipID` modifier on its attribute,
  category-7 types only, deduplicated by (modified,
  modifying, operator), as exactly one of (the #615
  four-way classification, per family):
  - **applicable**: operator in {2, 4, 6} and operand
    present, finite, and not `0.0` → an emitted entry;
  - **unsupported**: operator outside {2, 4, 6} and
    operand present and not `0.0` → no entry; marks the
    type unapplied *in that family* (the 4 scan-resolution
    types of section 2, and no others today);
  - **zero**: operand present and exactly `0.0` → no
    entry, no mark (the 3 signature extenders of section
    2, and no others today);
  - **absent**: operand not in the cache for this type →
    no entry; marks the type unapplied in that family
    **only if the type ends with no applicable entry and
    no zero classification in that family** (the 4 mass,
    3 signature, and 6 range types of section 2).
- Loud failures, house style (`fail(...)`, writes
  nothing), mirroring the capacitor/shield/output legs:
  an unparseable or non-finite operand value on a
  classified modifier; a duplicated (modified, modifying,
  operator) triple on one type in any family; two
  applicable entries on one type sharing a modified
  attribute in any family **except** signature (552),
  where the limit is two entries and a third fails — the
  section-2 dual-entry allowance, keyed to attribute 552
  in the check itself, never a blanket relaxation. All
  are zero on today's data beyond the five censused
  suppressors. Messages say "navigation and targeting
  modifier", never a sibling family's words. Deliberately
  **not** failures: operand values outside today's observed
  ranges (a negative add, a multiplier at or below `0`, a
  percent at or below −100, a non-integral or
  non-operator-2 entry on 192 — arithmetic the locked
  formula, the section-2 integer rule, and the pure-layer
  guards already define), absent operands, and zero
  operands.
- **Emission (locked shape).** Additive and sparse,
  category 7 only, all existing keys byte-stable and every
  non-category-7 row byte-identical to today. Each family
  emits independently, exactly as if it were its own #619
  leg: a carrier type emits the family's array key iff it
  has at least one applicable entry in that family **or**
  is marked unapplied in it, and the family's
  `…Unapplied: true` marker beside the (possibly empty)
  array iff marked. An all-zero carrier in a family emits
  **neither of that family's keys** (8427 in signature is
  the pin). Each value is a JSON array of
  `[modifiedAttributeId, operator, operand]` triples
  (numbers, compact separators; at most one triple per
  family per type except signature's two), operand baked
  in at generation time — the modifying attribute id is
  deliberately not emitted, for the #615 reason. Triples
  sort by the generator's existing sorted-triple order
  within a family (on the suppressors, modifying 3113's
  0.9-class operand precedes 3114's). The full unapplied
  predicate, per family (locked): a category-7 type with
  at least one `ItemModifier`/`shipID` modifier on the
  family's attribute is marked in that family iff (a) any
  such modifier classed unsupported, or (b) it has no
  applicable entry, no zero classification, and at least
  one absent classification in that family. Key placement
  is immediately after the power output modifier block
  (ending at line 3674, before `types.append(entry)` at
  line 3676), in `NAV_TARGETING_MODIFIER_ORDER`, each key
  followed by its marker when present —
  `warpSpeedMultiplierModifiers`,
  `warpSpeedMultiplierModifiersUnapplied`,
  `agilityModifiers`, …, `maxLockedTargetsModifiers`,
  `maxLockedTargetsModifiersUnapplied` — so pre-existing
  key order on every row is untouched.
- **Self-validation.** One oracle table beside
  `POWER_OUTPUT_MODIFIER_ORACLES` (line 907):
  `NAV_TARGETING_MODIFIER_ORACLES`, a dict keyed by
  modified attribute id whose values are lists in the
  sibling tuple shape `(type_id,
  expected_entries_or_None, expected_unapplied)` where
  `None` means neither of that family's keys may be
  present. Values are cache/zip reads from the section 2
  census, re-read at design time (section 8 gives the
  arithmetic they feed):
  - **600:** 26322 Large Hyperspatial Velocity Optimizer
    II `[[600, 6, 25.0]]`; 26068 I `[[600, 6, 20.0]]`;
    33985 Prototype Hyperspatial Accelerator
    `[[600, 2, 0.3]]`; 33981 Limited `[[600, 2, 0.2]]`;
    34266 Small Higgs Anchor I `[[600, 6, -10.0]]` (the
    drawback pin); 3117 (category 20 — carries a real
    (600 ← percent) triple at 8.0 and gains nothing, the
    category gate).
  - **70:** 1405 Inertial Stabilizers II
    `[[70, 6, -20.0]]`; 2605 Nanofiber Internal Structure
    II `[[70, 6, -15.75]]`; 26310 Large Low Friction Nozzle
    Joints II `[[70, 6, -14.0]]`; 34266 `[[70, 6, -55.0]]`;
    1240 'Basic' Reinforced Bulkheads `[[70, 6, 1.0]]`
    (the positive, agility-worsening pin); 3093 (category
    20, real triple at −2.0, gains nothing).
  - **4:** 20353 1600mm Steel Plates II
    `[[4, 2, 3750000.0]]`; 27951 Triage Module I
    `[[4, 4, 10.0]]`; 34266 `[[4, 6, 100.0]]`; 49099
    Zero-Point Mass Entangler `[[4, 6, -80.0]]`; 47812 and
    56313 empty array, unapplied true (the absent pins).
  - **552:** 3831 Medium Shield Extender II
    `[[552, 2, 7.0]]`; 3841 Large II `[[552, 2, 25.0]]`;
    1405 `[[552, 6, 11.0]]`; 4409 Signature Radius
    Suppressor I `[[552, 4, 0.9], [552, 4, 0.3]]` (the
    dual-entry pin — both triples, in this order); 47800
    empty, unapplied true; 8427 neither key (the zero-only
    pin).
  - **76:** 1952 Sensor Booster II `[[76, 6, 30.0]]`;
    1987 Signal Amplifier II `[[76, 6, 30.0]]`; 10998 Warp
    Core Stabilizer I `[[76, 6, -50.0]]` (the shrink pin);
    1182 empty, unapplied true (the split pin — applicable
    on 192 below).
  - **564:** 1952 `[[564, 6, 30.0]]`; 11370 Prototype
    Cloaking Device I `[[564, 4, 0.5]]`; 41411 Networked
    Sensor Array `[[564, 6, 500.0]]`; 27951 and 4294 empty,
    unapplied true (the operator-0 pins).
  - **208/209/210/211:** in each family, 1987
    `[[<attr>, 6, 48.0]]` and 33400 Bastion Module I
    `[[<attr>, 6, 100.0]]`; 208 additionally pins 41411
    `[[208, 6, 50.0]]`.
  - **192:** 1987 `[[192, 2, 2.0]]`; 1182
    `[[192, 2, 2.0]]`; 1436 Auto Targeting System II
    `[[192, 2, 3.0]]`; 4294 `[[192, 2, 5.0]]`; 45600 Legion
    Offensive - Support Processor neither key (category 32
    — carries a real (192 ← adds) triple at 1.0 and gains
    nothing, section 9).
  - **Every family:** 2048 Damage Control II neither key
    (non-carrier) and 587 Rifter neither key (category 6).
- **Catalogue-wide invariants** beside the output checks,
  per family, in the sibling shape: every present family
  array is on a category-7 row; its entries' modified id
  is the family's attribute, operators in {2, 4, 6},
  operands finite and not `0.0`; no duplicate modified id
  except signature's at-most-two; each marker only beside
  its family's array and only as `true`; the counts equal
  the census values for today's data, as four dict
  constants keyed by attribute id in the
  `POWER_OUTPUT_MODIFIER_ROWS` pattern
  (`NAV_TARGETING_MODIFIER_ROWS` {600: 15, 70: 98, 4: 68,
  552: 135, 76: 49, 564: 60, 208: 25, 209: 25, 210: 25,
  211: 25, 192: 15}; `…_NONEMPTY_ROWS` {600: 15, 70: 98,
  4: 64, 552: 132, 76: 43, 564: 56, 208–211: 25, 192: 15};
  `…_MARKED_ROWS` {4: 4, 552: 3, 76: 6, 564: 4, all others
  0}; `…_ENTRIES` {600: 15, 70: 98, 4: 64, 552: 137, 76:
  43, 564: 56, 208–211: 25, 192: 15}). The summary print
  gains those counts.
- Determinism unchanged: types sorted by `typeId`, compact
  separators, trailing newline, no timestamps. Proof
  obligations for the catalogue commit (section 8): run
  the generator twice → identical sha256; strip the
  twenty-two new keys from the regenerated file →
  byte-identical to today's `ee17d56a…`. Both proofs are
  run once and reported in the commit body, not committed
  as scripts.

**Size budget.** A simulation of the locked emission over
the census shape (540 keyed family-rows, 528 triples, 17
markers, compact separators, the key names above) adds
≈22,200 bytes (≈ +0.57%). Budget: the regenerated file
must land within **+25,000 bytes** of today's 3,886,379;
the catalogue commit body states the exact new byte count.
Anything over budget means the emission rule drifted (for
example emitting zero operands, marking non-absent types,
emitting a velocity family, or emitting on
non-category-7 rows) and stops the slice for review.

**Rust loader** (`src/names/fitting_types.rs`).
`FittingType` gains, immediately after the two power
output modifier fields (lines 181–184), twenty-two fields
in `NAV_TARGETING_MODIFIER_ORDER`, in the capacitor
fields' comment style — per family, the pair:

```rust
#[serde(rename = "warpSpeedMultiplierModifiers", default)]
pub warp_speed_multiplier_modifiers: Option<Vec<NavTargetingModifier>>,
#[serde(rename = "warpSpeedMultiplierModifiersUnapplied", default)]
pub warp_speed_multiplier_modifiers_unapplied: bool,
// agility_modifiers …, and likewise through
// max_locked_targets_modifiers_unapplied.
```

with **one** new struct beside `OutputModifier`
(line 593), `NavTargetingModifier { pub
modified_attribute_id: i64, pub operator: i64, pub operand:
f64 }`, deserialized from the 3-element array by the same
manual tuple impl. One struct for all eleven families,
deliberately, for the #618 reason generalized: the
families are one slice, one operator set, and one triple
shape, with the modified attribute id carried in every
entry; eleven structs would mark eleven slice boundaries
that do not exist, and reusing a sibling struct would
misname every invariant and call site here. Its doc
comment pins the semantics: entries are
generation-time-proven `ItemModifier`/`shipID` navigation
and targeting bonuses with the operand baked in (operator
2 is modAdd, 4 is postMulAlt, 6 is postPercent); operands
can shrink the value and are applied as written; the
signature family alone may carry two entries on one type;
`Some(empty)` with the unapplied flag is a carrier whose
bonus *in that family* the bundled data cannot ground and
must be counted, never read as "no bonus"; `None` is a
non-carrier or an all-zero carrier *in that family* — the
other ten families are judged independently.
`#[serde(default)]` keeps old assets and `from_json`
fixtures loading as `None`/`false`. Nothing is validated
at load (the pure function guards values, section 4; the
invariants test proves the shipped asset). Field placement
note (locked, do not "tidy"): the new fields sit after the
output fields, not beside the eleven base fields at lines
254–275 — every modifier family has appended in slice
order.

**Invariants to add** to `bundled_catalogue_invariants`
(`src/names/fitting_types.rs`), beside the output block,
all over the real bundled asset, per family: the family
array is `Some` only on category-7 rows; rows / non-empty
/ marked / entries equal the section-3 dict counts (warp
15/15/0/15, agility 98/98/0/98, mass 68/64/4/64, signature
135/132/3/137, range 49/43/6/43, scan 60/56/4/56, sensors
25/25/0/25 each, locks 15/15/0/15); every entry's modified
id is the family's attribute with no duplicate modified id
per row except signature's at-most-two (both 552),
operator is 2, 4, or 6, operand finite and `!= 0.0`; each
marker only beside its family's `Some`; 192 operands
integral on shipped data (the census fact the integer-rule
identity rests on — as an invariant over today's asset,
not a generator failure for tomorrow's); spot pins
mirroring the generator oracles (26322, 2605, 20353, 3831,
4409's dual entry, 1952 across its six families, 1987
across its seven, 1182 range-empty-with-flag beside
`[[192, 2, 2.0]]`, 27951 scan-empty-with-flag beside
`[[4, 4, 10.0]]` and `[[192, 2, 4.0]]`, 47812/47800/56313
marked-empty in their families, 8427 signature `None`,
34266's three families, 2048 / 587 / 3117 / 3093 / 45600
`None` in all eleven with flags false). The existing
invariants pass unmodified.

## 4. Pure API (locked)

**Placement (locked, justified): one generalized
`pub(crate)` helper in `src/fitting/ship_resistances.rs`,
and the public bonused function in
`src/fitting/ship_nav_targeting.rs` beside its base
sibling.** The helper joins the shipped family
(`bonused_resonances`, `bonused_hit_points`,
`bonused_capacitor`, `bonused_shield_recharge_duration`,
`bonused_outputs`) for the siblings' stated reasons: that
module owns `counted_flag` (line 296) and `mul_product`
(line 310), and forking either into the consumer invites
drift on the counted population and the bounded
arithmetic. The public function lives in the quantity's
own module, mirroring `ship_ehp_with_module_bonuses` and
`ship_shield_peak_recharge_with_module_bonuses`, because
only it may call the private `align_time_secs` and build
the shipped struct the bonused values are assembled into
— moving the align helper or widening its visibility to
serve a caller in `ship_resistances.rs` is rejected churn.
A generalized cross-family engine refactoring the five
shipped helpers is rejected for #620's reason (it would
put every sibling literal at risk for no behaviour this
slice needs); within this slice, eleven per-attribute
helper copies are rejected for section 1's reason. What is
shared is what the siblings already share, reused, never
forked. No new module.

**Helper** (`ship_resistances.rs`, beside
`bonused_outputs`). Names are part of the lock:

```rust
/// Bonused navigation and targeting values in raw
/// catalogue units (targeting range in metres, locked
/// targets still an `f64`) plus the counts the caller
/// must disclose beside any number derived from them.
pub(crate) struct BonusedNavTargetingValues {
    /// [600, 70, 4, 552, 76, 564, 208, 209, 210, 211, 192]
    /// in NAV_TARGETING_ORDER position, each `None`
    /// exactly where the base value is absent, negative,
    /// or non-finite, or the bonused result is negative,
    /// non-finite, or a positive subnormal.
    pub values: [Option<f64>; 11],
    /// Counted fitted rows with no catalogue row at all,
    /// in quantity units. Same definition and source
    /// predicate as `BonusedResonances::excluded_modules`
    /// (pinned equal, section 8).
    pub excluded_modules: usize,
    /// Per-attribute unapplied counts in
    /// NAV_TARGETING_ORDER position: counted fitted rows
    /// the catalogue marks as carriers in that attribute
    /// whose bonus cannot be applied, in quantity units.
    /// Never summed across positions.
    pub unapplied_modules: [usize; 11],
}

/// `None` only when the ship gate fails (`ship_type_id
/// <= 0`, no catalogue row, or the row is not category
/// 6). Otherwise `Some`, per-value `None` as documented
/// on `values`.
pub(crate) fn bonused_nav_targeting(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> Option<BonusedNavTargetingValues>;
```

The `[usize; 11]` array — where #618/#620 used named count
fields for two families — is the one deliberate shape
adaptation to eleven dimensions: eleven near-identical
named fields would be transcribed, indexed, and tested by
position in every consumer anyway, and the position's
meaning is the module's own `NAV_TARGETING_ORDER`
constant, documented on the field. The public struct
below unpacks them into named fields (the API surface a
reader greps stays explicit, as in every sibling); the
unpacking is eleven straight-line assignments in order,
pinned field-by-field in section 8 so a transposition
cannot pass silently.

Locked helper semantics, mirroring `bonused_capacitor` /
`bonused_outputs` generalized over the order:

- **Ship gate, order, and bases.** The siblings' gate
  verbatim (`ship_type_id > 0`, catalogue lookup,
  `category_id == 6`). A new private constant beside
  `OUTPUT_ORDER` (line 246):
  `NAV_TARGETING_ORDER: [i64; 11] = [600, 70, 4, 552, 76,
  564, 208, 209, 210, 211, 192]`; position is the
  accumulator index everywhere below. A private
  `base_nav_targeting` beside `base_outputs` reads, in
  that position: `[ship.warp_speed_multiplier,
  ship.agility, ship.mass, ship.signature_radius,
  ship.max_target_range, ship.scan_resolution,
  ship.scan_radar_strength, ship.scan_ladar_strength,
  ship.scan_magnetometric_strength,
  ship.scan_gravimetric_strength,
  ship.max_locked_targets]` — raw values, **no `/ 1000`,
  no integer conversion** (the wrapper converts). Each
  base is under the siblings' usability shape (present,
  finite, `>= 0.0`; present `0.0` is a real zero). One
  recorded subtlety: the 192 base enters as its raw `f64`
  under that filter, not through `usable_count` — a
  fixture base of 4.5 therefore flows into the formula and
  truncates in the wrapper, where the shipped base
  function returns `None` for the same row; on shipped
  data bases are integral (generator fail-loud) and the
  two coincide, and section 8 pins the fixture behaviour
  as the section-2 rule working as locked, not as an
  accident. Run lists are per-index `Vec<(f64, u64)>`
  arrays-of-eleven (add/mul/percent).
- **Counted scan.** Identical item predicate and
  quantity-units handling to the siblings (`type_id > 0`,
  positive quantity, `counted_flag`, `usize::try_from`,
  saturating adds). A counted row with no catalogue row
  adds its units to `excluded_modules` and is read no
  further (it is never also unapplied in any position).
  Per family position — one loop over eleven
  (array, flag) field pairs, written once, not eleven
  copied blocks — the once-per-item `counted_unapplied`
  pattern exactly as `bonused_outputs`' family blocks:
  the catalogue marker counts the item's units once in
  that position; an entry whose modified id is not the
  family's attribute, whose operator is outside
  {2, 4, 6}, or whose operand is non-finite or `0.0`
  counts the item once in that position (if not already
  counted) and is skipped; applicable entries on the same
  item — including both signature entries — are still
  applied. A defect in one position never counts in
  another, and no other slice's fields are read.
- **Run accumulation and bounded arithmetic.** Three run
  lists per position grouped by exact `==` operand value
  with saturating `u64` counts in first-seen order,
  composed in the siblings' exact association:

  ```text
  add_total     = Σ over add runs of operand × (count as f64)
  mul_total     = Π over mul runs of mul_product(operand, count)
  percent_total = Π over percent runs sorted by |value|
                  descending, of mul_product(1.0 + value / 100.0, count)
  bonused       = (base + add_total) × mul_total × percent_total
  ```

  `mul_product` is reused, not forked; **no stacking
  penalty** (section 2), so `percent_chain` is not called.
  Each result is `Some(bonused)` filtered by the `2ac348f`
  predicate verbatim — `v.is_finite() && *v >= 0.0 &&
  (*v == 0.0 || v.is_normal())` — with the sibling's
  explanatory comment adapted in the same edit. A hostile
  quantity can therefore only yield, per attribute, the
  formula's own finite non-negative normal value, an exact
  `0.0`, or `None` — never a hang, never infinity, never a
  subnormal passed downstream (section 8 pins each class
  with the result asserted, never discarded).
- **Identity (locked, exact).** With no applicable entry
  in a position and a base that is exact `0.0` or normal,
  the value is `(base + 0.0) * 1.0 * 1.0` — the base, equal
  under `==`. A fixture base that is itself a positive
  subnormal is rejected by the result filter (section 2
  qualification), as in `bonused_capacitor`.
- The helper is `pub(crate)`, never re-exported from
  `src/fitting/mod.rs` (the `pub use ship_resistances` list
  at mod.rs:53–54 does not change; the caller names it as
  `crate::fitting::ship_resistances::bonused_nav_targeting`).
  The `ship_resistances.rs` module header gains a short
  paragraph naming it as the navigation and targeting
  sibling serving `ship_nav_targeting` under this document
  (section 7). No logging is added.

**Public API** (`src/fitting/ship_nav_targeting.rs`,
below the shipped base function, which is not modified in
behaviour, signature, or tests). Names are part of the
lock:

```rust
/// Bonused navigation and targeting values plus the
/// counts the caller must disclose beside them.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BonusedShipNavTargeting {
    pub targeting: ShipNavTargeting,
    /// Counted fitted rows with no catalogue row at all,
    /// so no navigation or targeting bonus can be proven
    /// or disproven for them, in quantity units.
    pub excluded_modules: usize,
    /// Warp-speed-dimension count …, in quantity units.
    /// Never summed with any other count.
    pub warp_speed_unapplied_modules: usize,
    pub agility_unapplied_modules: usize,
    pub mass_unapplied_modules: usize,
    pub signature_radius_unapplied_modules: usize,
    pub max_target_range_unapplied_modules: usize,
    pub scan_resolution_unapplied_modules: usize,
    pub sensor_radar_unapplied_modules: usize,
    pub sensor_ladar_unapplied_modules: usize,
    pub sensor_magnetometric_unapplied_modules: usize,
    pub sensor_gravimetric_unapplied_modules: usize,
    pub max_locked_targets_unapplied_modules: usize,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BonusedShipNavTargetingOutcome {
    Available(BonusedShipNavTargeting),
    Unavailable,
}

pub fn ship_nav_targeting_with_module_bonuses(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> BonusedShipNavTargetingOutcome;
```

(Every count field carries the full sibling doc shape —
"counted fitted rows the catalogue marks as \<dimension\>
carriers whose bonus cannot be applied, in quantity
units; never summed with any other count" — abbreviated
above only to keep this listing readable.) Locked wrapper
semantics, mirroring the shipped base function field by
field:

- Calls `bonused_nav_targeting` once; helper `None`
  (the shared ship gate) → `Unavailable`.
- Assembles a plain `ShipNavTargeting` — the shipped
  struct, so the shipped line builders render the bonused
  block unchanged (section 6): `warp_speed` = value[600];
  `agility` = value[70]; `mass` = value[4];
  `signature_radius` = value[552];
  `max_target_range_km` = value[76] `.map(|m| m / 1000.0)`
  (the base function's conversion, applied once, after
  bonusing); `scan_resolution` = value[564]; sensors =
  values[208–211]; `max_locked_targets` = value[192]
  through a new private `bonused_count` beside
  `usable_count` implementing section 2's rule verbatim
  (filter finite, `>= 0.0`, exact `0.0` or normal,
  `<= 9_007_199_254_740_992.0`, then `as i64` truncation
  toward zero — its doc comment cites the Flutter
  `.toInt()` body and states the deliberate divergence
  from `usable_count`; `usable_count` itself is not
  modified); `align_time_secs` =
  `align_time_secs(agility, mass)` over the two *bonused*
  fields, the shipped helper, never re-inlined.
- **Availability mirrors base exactly:** `Unavailable`
  iff all eleven catalogue-backed bonused fields are
  `None` (the shipped eleven-way `is_none` conjunction,
  align derived and never counting separately); otherwise
  `Available` with each surviving field rendered and each
  `None` field's line omitted (section 5). Counts ride
  along on `Available` only, unpacked from
  `unapplied_modules` in order into the eleven named
  fields.
- **Identity (locked, exact).** With no counted carrier,
  `targeting` equals the shipped
  `ship_nav_targeting(fitting, catalogue)` result struct
  under `assert_eq` — including the align literal and the
  integer count (integral base → identical `f64` →
  truncation back to the identical `i64`) — and every
  count is 0 except `excluded_modules`, which counts
  catalogue-absent counted rows exactly as the sibling
  helpers' does (section 8). Availability coincides with
  base on every fitting the helper's result filter does
  not newly reject — on shipped data, always.
- `src/fitting/mod.rs` gains the three new names in the
  existing `pub use ship_nav_targeting::{…}` line
  (mod.rs:48). The module header of
  `ship_nav_targeting.rs` gains a bonused paragraph in the
  shipped style (section 7); the base function's docs and
  body do not change. The module still logs nothing.

**Count inventory at the API surface (collected).** On
`Available`: one shared `excluded_modules`
(catalogue-absent counted rows, quantity units) and eleven
per-attribute unapplied counts — twelve counts, twelve
definitions, no sums. A single fitted item can raise the
excluded count *or* any subset of the eleven unapplied
counts (one per family it is marked or defective in), never
both sides; the same physical module appearing in two
counts is two true statements about two dimensions, which
is why the UI keeps each on its own line (section 6).

## 5. Completeness and None rules (locked)

Collected in one place; sections 2 and 4 are normative and
this section adds nothing to them:

- **Per-field completeness, like base (locked — the
  deliberate divergence from #620).** A bonused field that
  is `None` — base absent/negative/non-finite, or bonused
  result negative, non-finite, or a positive subnormal —
  omits exactly its own line; every computable field still
  renders, exactly as the shipped base block renders a
  partial hull. #620's whole-result-unavailable rule does
  **not** carry over: its justification was a two-dimension
  used-vs-output *judgment* whose struct fields are plain
  `f64` with no honest partial form. These eleven are
  independent `Option` quantities whose base block already
  ships the partial form; suppressing ten computable values
  because the eleventh underflowed would destroy honest
  numbers to protect a coupling that does not exist. The
  all-`None` conjunction (→ `Unavailable`, the fixed
  sentence) is the only whole-block rule, and it is the
  base function's own.
- **Missing never becomes zero, in either direction.** An
  absent base is never resurrected by a bonus (section 2);
  a present `0.0` base bonused by percent stays an honest
  rendered `0.0` (a booster on a hull with no RADAR sensor
  leaves `RADAR 0.0 points`, never inventing a strength and
  never dropping the segment); a bonused exact `0.0` (a
  present-zero base, a −100 percent, a multiplier run that
  reaches `0.0`) renders like any value; a `None` never
  renders as `0.0`, a dash, or placeholder words. All four
  sensor fields `None` omits the joined line; any one
  `Some` renders the segments that exist, present zeros
  included (the shipped join, unedited).
- **Derived-field rules.** Align is `Some` only when both
  bonused inputs are `Some`, finite, and `> 0` under the
  shipped helper (a bonused agility or mass of `Some(0.0)`
  renders its own state honestly — mass line `0.0 kg`, no
  align line). Locks are `Some` only under section 2's
  guarded truncation. Range conversion cannot un-`None` or
  re-`None` a value.
- **Missing *module* data never zeroes a dimension:** a
  catalogue-absent counted row excludes (counted, shared);
  an ungroundeable carrier contributes nothing in its
  family (counted, per attribute); a non-carrier
  contributes nothing and counts nowhere. No silent 0 in
  any sum, no silent identity in any value.
- Availability of this block says nothing about any sibling
  block, and vice versa — it keys off the same eleven base
  fields as the base block plus counted items, and the
  shipped neighbour-independence pins keep their meaning
  (section 8 adds the bonused mirrors).

## 6. Display (locked)

One new block, rendered by one new function
`render_ship_nav_targeting_with_module_bonuses` in
`src/ui/fittings.rs`, mirroring
`render_ship_resistances_with_module_bonuses`
(lines 2669–2698) in every particular this section does
not state. It is called on **both** detail surfaces
(imported synth site and saved selected site) immediately
after `render_ship_nav_targeting`, extending the shipped
shared order to: … resistances (bonused) → EHP (base) →
EHP (bonused) → navigation/targeting (base) →
**navigation/targeting (bonused)** → …. Nothing moves;
no existing renderer
changes behaviour.

- Catalogue `None` → heading + the no-catalogue sentence.
  `Available(bonused)` → heading, then the number lines,
  then the excluded line (if any), then the unapplied
  lines in `NAV_TARGETING_ORDER` (each if any), then the
  disclosure. `Unavailable` → heading + the no-ship-data
  sentence. The heading always renders, so the view never
  silently omits the feature; the block renders even when
  the fitting has no items and even when every bonused
  number equals its base (the siblings' rule).
- **Number lines reuse the shipped builder verbatim:**
  `ship_nav_targeting_lines(&bonused.targeting)` (line
  2855) over the inner `ShipNavTargeting` — the same eight
  lines in the same order with the same labels, units,
  formatter (`widgets::format_fitting_amount`, one decimal,
  grouped), sensor join, and bare-`{}` count, fed bonused
  values. No line builder, segment helper, or formatter is
  edited or forked; agility still has no line; there is
  deliberately **no max-speed line** (section 2).
- **Count-line strategy (locked): one excluded line and
  up to eleven unapplied lines, each `None` at zero, never
  summed, never merged.** This is the only honest shape
  under ranking 3 — the eleven counts have eleven meanings
  and the data proves they move independently (section 2's
  splits) — and its cost is inventoried, not feared: seven
  of the eleven marked sets are empty on shipped data, so
  a real fitting can raise at most the mass, signature,
  range, and scan-resolution lines beyond fixture-defective
  catalogue data, and only by actually fitting an abyssal
  plate/extender, an Auto Targeting System, or a
  triage/industrial core. The eleven-line rendering is a
  hostile-catalogue bound, pinned in section 8 precisely so
  it is a tested bound rather than a surprise. Alternatives
  rejected, with reasons: one combined navigation
  unapplied line (sums dimensions by another name and tells
  the reader neither which number is short nor by how
  many modules); grouping the four sensors into one count
  (their carrier sets are identical *today*, so the four
  counts are equal on shipped data, but they are four
  dimensions and the API counts them separately — merging
  them in prose would be a sum whenever they differ); a
  "some bonuses could not be applied" summary line (a
  twelfth count in disguise).
- The eleven unapplied lines are built by **one** new
  helper, `bonused_nav_targeting_unapplied_line(noun: &str,
  unapplied: usize) -> Option<String>`, in the count-helper
  cluster beside `power_grid_output_unapplied_line` (line
  2227), called eleven times with the section-7 nouns in
  order — one sentence shape for eleven dimensions, where
  the two-family slices wrote two helpers. The excluded
  line is one new helper
  `bonused_nav_targeting_excluded_line` in the same cluster,
  in the resistance line's shape. Both are pure, return
  `None` at 0, and carry singular/plural pairs (section 7).
- No colour, no icons, no new widget, render code logs
  nothing. Depends only on fitting + catalogue, so both
  surfaces and every viewing character see identical bytes.

## 7. UI wording (locked verbatim)

New constants in `src/ui/fittings.rs` beside the base
block's (lines 1981–1992), each with the shipped
locked-wording doc-comment shape:

```text
FITTINGS_SHIP_NAV_TARGETING_WITH_BONUSES_HEADING =
  "Ship navigation and targeting (with fitted module bonuses)"
FITTING_SHIP_NAV_TARGETING_WITH_BONUSES_DISCLOSURE =
  "These navigation and targeting values add the fitted modules' and rigs' navigation and targeting bonuses from Mimir's bundled item data to the base values above. Align time follows from the bonused agility and mass. Every fitted module is counted as active, because the fitting data does not say which modules are on. Ship bonuses, subsystems, skills, implants, loaded scripts, and navigation or targeting changes from anything outside this ship are not applied, and max speed is not included: it is a base value in the Ship block above, and afterburner and microwarpdrive speed bonuses are not applied anywhere, so these numbers can differ from EVE."
FITTING_SHIP_NAV_TARGETING_WITH_BONUSES_NO_CATALOGUE =
  "Ship navigation and targeting with fitted module bonuses unavailable: Mimir's bundled item data failed to load."
FITTING_SHIP_NAV_TARGETING_WITH_BONUSES_NO_SHIP_DATA =
  "Ship navigation and targeting with fitted module bonuses unavailable: Mimir's bundled item data has no navigation or targeting data for this fitting's ship."
```

The disclosure is load-bearing phrase by phrase: "add …
to the base values above" (the bonused-block promise,
siblings' form); "Align time follows from the bonused
agility and mass" (the one derived line, whose inputs have
no display of their own for agility); the counted-as-active
sentence verbatim from #615; the exclusion list naming
every section-9 non-goal a reader might otherwise assume —
ship bonuses, subsystems, skills, implants, loaded scripts,
outside-ship changes; and the max-speed sentence, which is
this slice's section-2 deferral made user-visible (no
reader of a "(with fitted module bonuses)" navigation
block should have to guess why their microwarpdrive did
nothing, or go looking for a bonused max speed that does
not exist). No sentence names a dogma attribute, an effect,
or stacking: there is no stacking penalty to disclose on
these attributes (section 2), and the resistance block's
"with stacking penalties" clause is deliberately absent —
copying it here would be a false sentence.

Excluded line (locked verbatim, singular/plural):

```text
"1 fitted module is not in Mimir's bundled item data, so any navigation or targeting bonus from it is not counted."
"{n} fitted modules are not in Mimir's bundled item data, so any navigation or targeting bonuses from them are not counted."
```

Unapplied template (locked verbatim) with the noun per
attribute in `NAV_TARGETING_ORDER`:

```text
"1 fitted module has a {noun} bonus Mimir's bundled item data cannot describe, so that bonus is not applied."
"{n} fitted modules have {noun} bonuses Mimir's bundled item data cannot describe, so those bonuses are not applied."
```

| Pos | `{noun}` |
|---|---|
| 600 | warp speed |
| 70 | agility |
| 4 | mass |
| 552 | signature radius |
| 76 | targeting range |
| 564 | scan resolution |
| 208 | RADAR sensor strength |
| 209 | Ladar sensor strength |
| 210 | Magnetometric sensor strength |
| 211 | Gravimetric sensor strength |
| 192 | max locked targets |

The nouns are the block's own line vocabulary (line labels
lower-cased, sensor segment names as shipped), never a
dogma name or raw id. "Agility" is used although agility
has no display line: it is the attribute the bonus actually
targets, the disclosure sentence ties it to align time, and
calling it an "align time bonus" would be false (nothing
bonuses align directly). Number lines are the shipped eight
verbatim from the base design's section 6 (`Warp speed: …
AU/s`, `Align time: … s`, `Mass: … kg`, `Signature radius:
… m`, `Targeting range: … km`, `Scan resolution: … mm`, the
joined `Sensor strength: … points` line, `Max locked
targets: {n}`), produced by the unedited shipped builder.

**False-sentence inventory (locked — every shipped
sentence this slice makes true, keeps true, or must not
touch):**

- `FITTING_SHIP_NAV_TARGETING_DISCLOSURE` ("Fitted
  modules, rigs, subsystems, skills, implants, and ship
  bonuses are not applied") — **unedited and still true**:
  it scopes to the base block's own numbers ("These are
  the bare hull's base … values"), exactly as the base
  resistances disclosure survived #615. Builders must not
  "fix" it to mention the bonused block (the bonused
  resistances precedent deliberately added such a pointer
  only because EHP below it *consumes* the bonused values;
  nothing consumes bonused navigation values, so no shipped
  disclosure gains a pointer sentence in this slice).
- `FITTING_SHIP_BASE_STATS_DISCLOSURE` ("Base ship values …
  Fitted modules … are not applied") — **unedited and
  still true**, including of `Max speed`: section 2 defers
  velocity precisely so this sentence needs no edit and no
  reader is told max speed is bonused anywhere.
- The resources, resistances, EHP, shield-peak, and
  capacitor disclosures (base and bonused) — untouched;
  no number they describe moves.
- `ship_nav_targeting.rs` module header ("No modifier of
  any kind is applied") — becomes false **of the module**
  the moment the bonused function lands, so the integrator
  edit is locked here: the header gains a second paragraph
  in the same register naming
  `ship_nav_targeting_with_module_bonuses` as applying the
  fitted modules' and rigs' plain catalogue bonuses on the
  eleven attributes under this document, with max velocity,
  skills, implants, subsystems, ship bonuses, and scripts
  excluded; the base function's own doc comment ("The
  fitting's items are never read") stays attached to the
  base function and stays true. Likewise
  `ship_resistances.rs`'s header gains its one-paragraph
  sibling note (section 4). No behaviour hides in either
  comment edit, and section 8 pins that the base function's
  tests pass unmodified.
- No new sentence anywhere claims completeness: the heading
  says "(with fitted module bonuses)", never "fitted
  values" plain; the disclosure's last clause keeps "so
  these numbers can differ from EVE" — true for at least
  the no-stacking-penalty order, the counted-as-active
  suppressor/cloak treatment, the unscripted sensor-booster
  percents, and the deferred propulsion/skill/implant
  worlds.

**Demo consequence (locked, inventoried):** the demo bundle
(`assets/demo/fittings.json`, unmodified) fits no counted
navigation carrier (Damage Control II, the multispectrum
hardener, and the placeholder rows carry no family keys),
so both Rifter fittings and the Punisher render the base
numbers in the bonused block. Exactly one new line appears
across the demo: Demo Brawler's counted `RigSlot0` row
(type 1535) has no catalogue row, so its bonused block
renders the excluded line at 1. Mission Runner and Demo
Runner (all counted rows present in the catalogue) render
no count line. Section 8 pins all three.

## 8. Hand oracles and test plan (locked)

All literals below are hand arithmetic over the catalogue
bases and section-3 operands, shown in comments in the
tests and never built from the constants under test.
`f64` bonused oracles assert within `1e-9` (the align
precedent) except the identity pins, which are `assert_eq`
on whole structs, and integer/rendered pins, which are
exact. Rifter 587 base (shipped oracles): warp 5.0,
agility 3.2, mass 1,067,000, signature 35.0, range 22,500
m, scan 660.0, sensors 0/8/0/0, locks 4, align
4.733363466607754. Punisher 597: warp 5.0, agility 2.9,
mass 1,190,000, signature 37.0, range 25,000 m, scan
640.0, sensors 10/0/0/0, locks 4.

**Per-family hand oracles** (one real carrier each, on
Rifter unless stated; formula `(base + adds) × mul ×
percent` in each comment):

1. **Warp percent:** + Large Hyperspatial Velocity
   Optimizer II 26322 `[[600, 6, 25.0]]` (RigSlot):
   `5.0 × 1.25 = 6.25` AU/s.
2. **Warp add:** + Prototype Hyperspatial Accelerator
   33985 `[[600, 2, 0.3]]`: `5.0 + 0.3 = 5.3` AU/s.
3. **Agility → align:** + Nanofiber Internal Structure II
   2605 `[[70, 6, -15.75]]`: agility `3.2 × 0.8425 =
   2.696`; align `1.386294… × 2.696 × 1,067,000 / 1e6 =
   3.9878587206170333` s.
4. **Mass add → align (Flutter cross-pin):** + 1600mm
   Steel Plates II 20353 `[[4, 2, 3750000.0]]`: mass
   `4,817,000.0` kg; align `= 21.36889580004644` s —
   Flutter's plate test expects `closeTo(21.369, 0.01)` on
   the same operands; the comment cross-pins both.
5. **Both align inputs (single-input mutant killer):**
   2605 + 20353 together: align over bonused 2.696 and
   bonused 4,817,000 `= 18.003294711539127` s (bonusing
   only agility gives oracle 3, only mass oracle 4).
6. **Signature add (Flutter cross-pin):** + Medium Shield
   Extender II 3831 `[[552, 2, 7.0]]`: `35.0 + 7.0 = 42.0`
   m (Flutter E0a.1: 35 → 42).
7. **Signature order (add-before-percent mutant killer):**
   3831 + Inertial Stabilizers II 1405 `[[552, 6, 11.0]]`:
   `(35.0 + 7.0) × 1.11 = 46.62` m — the reassociated
   mutant `35.0 × 1.11 + 7.0 = 45.85` must fail.
8. **Signature dual multiplier:** + Signature Radius
   Suppressor I 4409 `[[552, 4, 0.9], [552, 4, 0.3]]`:
   `35.0 × 0.9 × 0.3 = 9.45` m (both entries, one product).
9. **Range percent + conversion:** + Sensor Booster II
   1952 `[[76, 6, 30.0]]`: `22,500 × 1.3 = 29,250 m →
   29.25 km` (conversion after bonus, in the comment).
10. **Range shrink (no-clamp pin):** + Warp Core
    Stabilizer I 10998 `[[76, 6, -50.0]]`: `11.25 km`,
    below base, rendered as written.
11. **Scan mul × percent:** 1952 `[[564, 6, 30.0]]` +
    Prototype Cloaking Device I 11370 `[[564, 4, 0.5]]`:
    `660.0 × 0.5 × 1.3 = 429.0` mm.
12. **Sensors:** Punisher + Signal Amplifier II 1987
    (`48.0` on each of 208–211): RADAR `10.0 × 1.48 =
    14.8`, the three present zeros stay `Some(0.0)` and
    render as `0.0 points` segments; Rifter cross-check:
    Ladar `8.0 × 1.48 = 11.84`.
13. **Locks add:** 1987 on Rifter: `4 + 2 = Some(6)`,
    rendered `Max locked targets: 6` by `{}`, never the
    amount formatter.
14. **Multi-family row:** Small Higgs Anchor I 34266 on
    Rifter: warp `5.0 × 0.9 = 4.5`, agility
    `3.2 × 0.45 = 1.44`, mass `1,067,000 × 2.0 =
    2,134,000.0`, align `= 4.260027119946979` s, all other
    fields base, all counts 0.
15. **Split pin 1 (range marked, locks applied):** Auto
    Targeting System I 1182 on Rifter: locks `Some(6)`,
    range still `22.5 km`,
    `max_target_range_unapplied_modules == 1`, every other
    unapplied count 0 — in both the helper array (position
    of 76) and the unpacked public fields.
16. **Split pin 2 (scan marked, mass/locks applied):**
    Triage Module I 27951 on Rifter: mass
    `1,067,000 × 10.0 = 10,670,000.0`, locks `Some(8)`,
    scan still `660.0`,
    `scan_resolution_unapplied_modules == 1`, others 0 —
    the operator-0 lock working as designed.
17. **Marked-with-nothing-applied:** abyssal plate 47812
    (mass 1, mass/align base) and abyssal extender 47800
    (signature 1, signature base), each quantity 2 →
    count 2 (quantity units, counted once per unit).

**Identity and population pins:**

18. `no_counted_items_equals_base` (sibling name shape):
    empty fitting, non-counted flags only (DroneBay,
    Cargo, FighterBay) with carrier cargo, zero/negative
    quantities, and a counted non-carrier (Damage Control
    II 2048) each yield `targeting == ship_nav_targeting(…)`
    by `assert_eq`, all twelve counts 0; a counted
    catalogue-absent type yields base values with
    `excluded_modules == quantity` and unapplied all 0;
    `excluded_modules` equals `bonused_resonances`' on the
    same fitting (the shared-definition pin).
19. Rig/subsystem counting: oracle 1's rig under RigSlot
    applies; the same type under Cargo does not apply and
    counts nowhere; a subsystem-slot carrier
    (catalogue category 7 type under SubSystemSlot)
    applies — while a category-32 subsystem type itself
    (45600) carries no keys and contributes nothing under
    any flag.
20. Present-zero and absent bases: Capsule 670 (shipped
    pins: range `Some(0.0)`, locks `Some(0)`, scan `None`)
    + 3831 → signature `25.0 + 7.0 = 32.0`, range stays
    `Some(0.0)` km under a fitted 1952 percent, locks
    `Some(2)` under 1987's add on a zero base, scan stays
    `None` under 1952 (absent never resurrected), align
    still derives — each field independently, block
    `Available` throughout.
21. Per-field guards (synthetic catalogue, base-design
    shape): negative/NaN/infinite base per field → that
    field `None`, neighbours untouched; non-ship / unknown
    id / `ship_type_id <= 0` → `Unavailable`; all-eleven-
    `None` synthetic → `Unavailable` even with counted
    carriers fitted (bonuses never resurrect availability).
22. Neighbour independence (base mirrors): bonused
    `Available` while resources are `ShipNoOutput`, and a
    full-#578-stats ship with no nav fields leaves this
    block `Unavailable` and #578 untouched; the base
    function's shipped tests pass unmodified.

**Hostile asserted pins** (every result asserted, none
discarded; the run completing is part of the pin):

23. Quantity `i64::MAX` of Prototype Cloaking Device I
    (mul 0.5 on 564): completes via the bounded stall;
    scan is the asserted exact `Some(0.0)`; every other
    field base. Quantity `i64::MAX` of a percent carrier
    (10998 at −50): range asserted `Some(0.0)` km, no hang.
24. Subnormal: synthetic fixture entry with operand
    `5e-324` (min positive subnormal) operator 4 on 600 →
    `warp_speed == None` (line omitted), the other ten
    fields base-`Some` (per-field completeness, section
    5); a positive-subnormal fixture *base* on 552 →
    signature `None`, neighbours `Some`.
25. Exact-zero survival: fixture −100.0 percent on 600 →
    `Some(0.0)`, rendered `Warp speed: 0.0 AU/s` — the
    `2ac348f` zero kept, never confused with absence.
26. Negative result: fixture percent −150.0 on 76 →
    range `None` (never a negative kilometre), others
    base; fixture multiplier −1.0 at odd quantity on 564 →
    scan `None` (parity branch, never a hang).
27. Integer rule, hostile side: fixture percent 12.5 on
    192 over base 4 (`4 × 1.125 = 4.5`) → `Some(4)` by
    truncation toward zero, comment citing section 2's
    Flutter rule — and the same fixture through the *base*
    path remains integral-or-`None` (base 4.5 → locks
    `None`, shipped test unmodified). Fixture bonused
    count above 2^53 and negative bonused count → `None`.
28. Defective-entry guards (fixture rows violating section
    3): entry with another family's modified id, operator
    0/5, operand `0.0`/NaN — each counts its item once in
    that family only, applies nothing for that entry, and
    still applies a second good entry on the same row
    (signature dual-entry fixture with one bad leg).

**UI pins (`fittings.rs`):**

29. Line templates: a full synthetic bonused struct renders
    the eight shipped lines verbatim through the unedited
    builder (one-decimal, grouped mass `4,817,000.0 kg`
    from oracle 4, joined sensors, bare count); `None`
    fields omit exactly their lines; `Some(0.0)` warp
    renders `Warp speed: 0.0 AU/s`; there is no max-speed
    line and no agility line.
30. Wording pins: heading, disclosure, both unavailable
    constants equal section 7 verbatim; excluded singular/
    plural; the unapplied template instantiated for all
    eleven nouns, singular and plural asserted for at
    least warp speed and max locked targets and `None` at
    0 for all; count-line order after the numbers, before
    the disclosure, in `NAV_TARGETING_ORDER`.
31. All-eleven-lines bound: a synthetic struct with every
    unapplied count at 1 renders exactly eleven unapplied
    lines (plus excluded at 1 → twelve count lines),
    pinning section 6's hostile bound as tested behaviour.
32. Demo pins over the real bundle: Demo Brawler and
    Mission Runner render the base Rifter numbers in the
    bonused block, Brawler with the excluded line at 1,
    Mission Runner with none; Demo Runner renders the base
    Punisher numbers with no count line — in both detail
    views' line order, bonused block immediately after the
    base block.
33. No-regression: every shipped wording test for the base
    blocks passes without edit; the only edited shipped
    strings are none (section 7's inventory is comment-only
    in the two module headers).

**Catalogue commit proofs (run once, reported in the
commit body, not committed as scripts):** generator run
twice → identical sha256; strip-the-twenty-two-new-keys
byte-identity against `ee17d56a…`; exact new byte count
against the +25,000 budget; generator self-validation
(oracles, dict counts, 1281 tripwire) green. Gates per
commit: `cargo fmt --check`, `cargo clippy --all-targets
-- -D warnings`, `cargo test`, `cargo build`. Commits
small and atomic, `type(scope): description`, no
attribution lines. Sequence: docs (this file) → catalogue
(generator + JSON + loader, tests in `fitting_types.rs`) →
pure (helper in `ship_resistances.rs`, API in
`ship_nav_targeting.rs`, `mod.rs` re-exports) → UI
(constants, line helpers, renderer, both call sites).

## 9. Exclusions (locked)

Each excluded by name, with its evidence; each is named in
the block's disclosure (section 7) where a user could
meet it:

- **Max velocity (37), whole attribute** — propulsion's
  expression-tree invisibility makes the plain path
  undisclosably incomplete (section 2, the full evidence).
  Includes the plain-path carriers (overdrives, nanofiber
  velocity percents, thruster rigs, cloak multipliers):
  shipping them without afterburners under a bonused
  heading is the rejected half-measure, so no velocity
  number in either block changes.
- **Propulsion thrust/mass mechanics wholesale** — nothing
  in this slice models thrust, propulsion signature bloom,
  or microwarpdrive mass addition; no zip `shipID` triple
  on the eleven attributes carries them, and no inspected
  Flutter body applies such a triple to these stats.
- **Scripts and charges** — Targeting Range / Scan
  Resolution / ECCM scripts (29009, 29011, 41155, kin)
  modify their host module's input attributes via
  `ItemModifier`/`otherID`, never the ship; Flutter drops
  `otherID` from the ship computation identically. They
  are category 8, sit under non-counted flags, gain no
  emission, and raise no count; the unscripted booster
  percents apply as written (disclosed as "loaded scripts
  … are not applied").
- **All other modifier domains/functions** —
  `LocationGroupModifier`, `LocationRequiredSkillModifier`,
  `OwnerRequiredSkillModifier` (including its 75 velocity
  rows and the sensor rows via 23069), `targetID` remote
  effects (sensor dampeners/projectors strengthen or weaken
  *another* ship), `itemID`/`otherID` self-input streams
  (script capacity and kin): none is the plain self-to-ship
  path; Flutter routes each elsewhere or drops it for ship
  stats. Excluded at the generator's `func`/`domain` test,
  never approximated.
- **Skills** — including Navigation 3449's velocity percent
  (irrelevant here; 37 is out) and every skill-carried
  triple on the eleven: category 16 gains no emission, and
  no skill percent joins any chain (there is no shipped
  per-character input to this block and none is added).
- **Ship traits / role bonuses** — category-6 carrier rows
  (the hulls' own triples on these attributes) gain no
  emission; base values already *are* the hull, and trait
  scaling is no inspected body in this codebase's bonused
  path.
- **Implants and boosters** — category 20 (the censused
  warp/agility/sensor implant sets, e.g. 3117/3093 oracles):
  locked out as in every sibling; no character implant
  data reaches a fitting block.
- **Subsystems** — category 32 (e.g. 45600's real
  locked-target triple): locked out exactly as in every
  sibling, even though subsystem slot flags are counted at
  runtime — a fitted subsystem contributes no runs and no
  count. Their hull-base coverage (Legion-class oracle rows
  in the base design) is untouched.
- **Structures** — category 66 rigs (112 censused
  range/scan/lock carriers): not modules, never fitted to
  a ship fitting; no emission.
- **Scan-resolution operator 0** — counted, never applied
  (section 2's named divergence): the four triage/industrial
  types disclose on the scan count line rather than applying
  Flutter's ×10.0/×2.0 under a Rust operator set that has
  never admitted postMul outside resistances.
- **Any stacking penalty** on the eleven — forbidden by
  the inspected `_nonStackableAttributes` body (section
  2); inventing one from general EVE knowledge is the
  folklore fix this design exists to pre-empt.
- **An agility display line** — still none (base design
  section 2.3 stands: no Flutter row to mirror, the shared
  one-decimal formatter would render real values as
  `0.0 x`); agility ships as align input and count
  dimension only.
- **Sensor presentation changes** — no strongest-only or
  per-sensor lines; the shipped joined line carries the
  bonused values unchanged. Flutter's absence of any sensor
  field is recorded (its engine computes the same generic
  touched-attribute values and discards them); the Rust
  display is the shipped base block's, grounded in the SDE
  bodies, and bonusing it needs no Flutter display
  precedent beyond the engine formula — stated plainly so
  no builder hunts for a Flutter sensor oracle that does
  not exist.
- **Module state, overheating, and anything outside this
  ship** — fleet boosts, remote assistance, system effects:
  no inspected body in scope; the disclosure's
  outside-this-ship clause covers them in words.

## 10. Decision record

- **Eleven attributes ship; max velocity (37) is deferred
  whole** — the plain census cannot see, mark, or count
  afterburner/microwarpdrive carriers (empty zip modifiers
  on effects 6730/6731), so plain-only velocity would
  silently understate the most common speed fit by up to
  ×6.1 with every count at zero. Rejected: shipping 37
  plain-only with a disclosure sentence (a sentence does not
  fix a wrong number under a bonused heading; the siblings
  count what they cannot apply, and here counting is
  impossible without a new effect leg). The future slice's
  required first step is named in section 2.
- **Eleven per-attribute families, one generalized leg /
  struct / helper** — per-attribute marking is forced by
  shipped cross-pardon rows (1182, 27951); per-attribute
  *code* is not. Rejected: one combined family (pardons);
  combined-with-id-list (unprecedented counting semantics);
  eleven copied legs/helpers (drift surface for no
  behaviour).
- **Operator set {2, 4, 6} uniformly; 564's operator 0
  counted, not applied** — house set on every non-resistance
  sibling, one named Flutter divergence (triage ×10.0),
  disclosed by count. Rejected: admitting 0 for 564 alone.
- **Signature dual entry allowed (≤ 2, 552 only), both
  multipliers applied** — five censused suppressor types;
  single-entry invariants elsewhere and duplicate-triple
  failure everywhere stand. Rejected: picking one state
  (unstatable from fitting data), marking the five unapplied
  (both operands are perfectly grounded).
- **192 converts by truncation toward zero** — Flutter's
  inspected `attr(192).toInt()`, guarded by the subnormal
  filter and the 2^53 bound; identity on all shipped data.
  Rejected: integral-or-`None` for the computed value (a
  future percent carrier would silently blank the line
  where the inspected engine defines a count); locking 192
  out (the evidence this design required exists); floor /
  round (no body anywhere — guessing).
- **Per-field completeness** — the base block's partial
  rendering, not #620's coupled unavailable rule (section 5
  states why the coupling does not exist here).
- **New block, base byte-identical** — #615–#619 shape;
  #620's in-place exception was for a comparison side, which
  none of these quantities is.
- **Helper in `ship_resistances.rs`, public API in
  `ship_nav_targeting.rs`, one `[usize; 11]` count array
  unpacked into eleven named public fields** — counted-scan
  and bounded-arithmetic ownership, private-align-helper
  ownership, and grep-able API, in that order of reasons.

Nothing in the candidate list was left ungrounded without
a recorded reason: warp, agility, mass, signature radius,
targeting range, scan resolution, all four sensor
strengths, and max locked targets ground to inspected
bodies as locked in section 2; max velocity is excluded on
the recorded expression-tree evidence with its future path
named, rather than shipped incomplete.






