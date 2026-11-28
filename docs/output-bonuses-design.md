# Fitted-module output bonuses (CPU and power grid output) — design

Status: locked for the `feat/rust-output-bonuses` slice.
Base: `develop` at `ae17f41` (PRs #561–#619 merged).
Slice branch: `feat/rust-output-bonuses`. This document
is the single design commit; builders implement exactly
what is locked here and nothing else. It follows the
resistance bonuses slice
(`docs/resistance-bonuses-design.md`, #615), the hit
point bonuses slice (`docs/hp-bonuses-design.md`, #617),
the capacitor bonuses slice (`docs/cap-bonuses-design.md`,
#618), and the shield recharge bonuses slice
(`docs/shield-recharge-bonuses-design.md`, #619) for
emission and computation shape, and the three resource
slices (`docs/fitting-resources-design.md`,
`docs/fitting-skill-resources-design.md`,
`docs/fitting-need-reductions-design.md`) for the block,
the budgets, and the skill arithmetic being composed
with; where this document says "mirrors #618" or
"mirrors #619", that wording and structure are the
precedent and do not need relitigating. Unlike every
sibling, this slice changes the totals of an existing
block instead of adding a new one (section 1 locks why,
sections 6–8 inventory every sentence and test that
change touches). The earlier design documents are not
edited.

Every name, formula, count, and oracle number below
traces to an inspected body at `ae17f41` —
`src/fitting/resources.rs`,
`src/fitting/ship_resistances.rs`,
`src/names/fitting_types.rs`, `src/ui/fittings.rs`,
`src/fitting/mod.rs`,
`scripts/sde/generate_fitting_types_sde.py`, the design
documents above, `assets/demo/fittings.json`, the
committed subnormal fix `2ac348f` — or to a design-time
census over the committed SDE data (`dogmaEffects.jsonl`
inside
`scripts/sde/eve-online-static-data-3503375-jsonl.zip`
joined through the committed `scripts/sde/*.csv.bz2`
caches and the bundled catalogue; section 2 quotes its
counts, and the carrier status and operands of every
oracle type in section 8 were re-read from those bodies
at design time), or to the inspected Flutter bodies at
`ed698d3`
(`lib/features/fitting/domain/dogma_engine.dart`,
`dogma_attributes.dart`, `models.dart`, and the Flutter
engine tests), or to hand arithmetic over values those
bodies pin (shown in section 8). No convention here
comes from EVE folklore or memory. Raw EVE type IDs
never appear in any rendered string in this slice; type
IDs below are internal oracle pins only, as in #615.

## 1. Goal and value ranking

Apply fitted items' CPU output (dogma 48 `cpuOutput`)
and power grid output (dogma 11 `powerOutput`) bonuses —
Co-Processors, Reactor Control Units, Power Diagnostic
Systems, Micro Auxiliary Power Cores, output rigs, and
rig output drawbacks, the whole censused set of
section 2 — to the ship outputs the existing "Fitting
resources" block already shows, on both fitting detail
surfaces, composing with the shipped skill output
factors in Flutter order (section 2). Per dimension:

```text
bonused output = (hull output + Σ flat adds)
                 × Π multipliers
                 × Π (1 + percent / 100)
```

where the percent product is one chain containing the
fitted items' percent entries *and*, when skill levels
are supplied, the one skill percent entry per dimension
(CPU Management 3426 on 48, Power Grid Management 3413
on 11, shipped), exactly as Flutter composes them. Used
needs, need reductions, and every other block's numbers
do not move. No network, no ESI changes, no new scopes,
no persistence.

**The existing block changes; there is no new block
(locked, the deliberate divergence from the siblings).**
Every earlier bonused quantity got its own new block
(#615 resistances, #617 EHP, #618 capacitor, #619
shield peak) and left its base block byte-identical.
That shape does not fit this quantity, for three
reasons builders must not relitigate:

1. The block's figure is a *comparison* — used against
   output, with an over/under verdict (`resource_line`,
   `src/ui/fittings.rs:1988`). A second block would have
   to duplicate both used sums (which do not change) to
   show the two new outputs, and the reader would be
   handed two different "X tf left" figures for one
   fitting with no rule for which one judges the fit.
   The siblings' bonused figures are standalone
   quantities; this one is one side of a shipped
   comparison, so the comparison itself is what gets
   bonused.
2. The block already varies per viewing character (the
   skill-applied arm), and the need-reduction slice
   proved the in-block pattern for a moved figure: the
   changed figure in `resource_line`, the before-figure
   on its own always-rendered line (`base_need_line`,
   fittings.rs:2106). This slice is the output-side
   mirror of that precedent (section 6's
   before-module-bonuses line).
3. Module output bonuses are intrinsic to the fitting
   and the bundled catalogue — they need no character
   data — so they apply on **both** arms, with and
   without supplied skill levels (section 4). The
   rejected alternative, applying them only on the
   skill-applied arm to keep the no-skills arm
   byte-identical, would make a Reactor Control Unit's
   output contribution appear and vanish with an
   unrelated character-skills load, and no inspected
   body composes that way: Flutter applies module
   modifiers to 48/11 whether or not any skill level is
   known (section 2), and every sibling bonused block
   renders from fitting plus catalogue alone.

The cost of this decision is locked and inventoried,
not hidden: both headings and both disclosures of the
existing block change value (section 7), the budgets
gain two fields (section 4), one demo count moves
(section 8), and the skill-resources slice's
"None renders the base block byte-identically" lock is
superseded in the narrow form section 2 states. What
replaces that lock is stronger where it matters: a
fitting with **no output carrier counted** keeps
bit-identical outputs on both arms (sections 2 and 4,
pinned by `assert_eq` in section 8), so every fitting
this slice does not touch reads exactly as it read
before, and every fitting it does touch shows today's
output figure on its own line beside the new one.

Value ranking (locked, in order), extending the
resource slices':

1. **No output figure ever changes silently, and no
   output ever reads as complete when a counted
   carrier's bonus could not be applied.** The headings
   name the fitted-module bonuses on both arms; today's
   output (hull, resp. hull × skill factor) renders on
   its own line per dimension whenever the block
   renders numbers; and a carrier whose bonus the
   bundled data cannot ground raises a new
   per-dimension output-unapplied count (sections 4
   and 7). A fit judged "under" only because a flux
   coil's ungroundable power triple was quietly dropped
   is the failure this ranking exists to prevent.
2. **Correctness and exactness of the composition.**
   Adds before multipliers before percents, the skill
   percent inside the same percent chain (a Micro
   Auxiliary Power Core's flat megawatts *are* scaled
   by Power Grid Management and by a fitted Reactor
   Control Unit — section 8 pins the wrong-order
   mutant's different number), full `f64` precision,
   and the locked float association that keeps
   no-carrier outputs bit-identical to the shipped
   `output * (1 + 0.05 * level)` on both arms
   (section 2). Absence never renders as a number and
   never resurrects as zero (section 5); a positive
   subnormal bonused output is stall residue, not data
   (the `2ac348f` guard, sections 2 and 4).
3. **No deficit is silently dropped, in any dimension,
   and no two counts are ever summed.** The block
   already discloses four per-dimension counts (CPU and
   power grid excluded, CPU and power grid unreduced);
   this slice adds two more of the same shape (CPU and
   power grid output-unapplied) and widens the excluded
   counts' absent-row population by the one locked rule
   of section 4. Each count keeps its own line and its
   own meaning; none is ever added to another, in the
   API or the UI.
4. **Reuse.** The #615/#617/#618/#619 generator
   classification, catalogue tuple shape, loader shape,
   counted-item scan, and bounded run arithmetic; the
   shipped skill levels, clamp, and need machinery
   untouched; the shipped `resource_line`,
   `base_need_line`, and count-line shapes — all beat
   new machinery (sections 3, 4, 6).

Non-goals are locked in section 9. In particular: no
module need modifiers beyond the shipped skill
reductions, no implants, no ship traits, and no
subsystem output bonuses (category-32 carriers are
locked out exactly as in every sibling).

## 2. Modifier set, arithmetic, and supersession (locked)

**Supersession.** The fitting resources design
section 4 locked "base values only" as that slice's
modifier depth; the fitting skill resources design
sections 5–6 locked the two-arm rendering with the
no-skills arm byte-identical to the earlier base block
and named module bonuses not applied in both
disclosures; the fitting need reductions design
section 8 superseded the applied disclosure once
already while keeping "bonuses … from modules, rigs,
subsystems … not applied". This slice supersedes, as
slice boundaries: the base-outputs-only depth (→
sections 2–4 here); the two disclosures' and two
headings' wording (→ section 7 here, verbatim new
values, every affected test inventoried in section 8);
and the byte-identical-None-arm lock in exactly this
narrow form — the None arm's *outputs* are now bonused
(like the Some arm's), so its rendered bytes change for
carrier fittings, while `fitting_resources(f) ==
fitting_resources_with_skills(f, None)` stays true by
construction (one function, `resources.rs:400-402`) and
no-carrier fittings keep bit-identical outputs on both
arms. What is **not** superseded: the `ShipNoOutput`
gate and its rules (section 5); used sums, base_used,
excluded and unreduced semantics except the one
absent-row widening of section 4; `ResourceSkillLevels`,
its lookup, and its clamps; the twelve need-reduction
entries and their arithmetic; the unavailable sentences;
`#615/#617/#618/#619` semantics, counted-flag set,
bounded arithmetic, and the subnormal-rejection rule of
`2ac348f`; any number in any other block. A builder who
believes this design requires changing any of those
stops and records it against this document.

**Grounded modifier shape (locked — ships, the whole
set).** A fitted item contributes an output modifier
only when all of these hold, mirroring #618 section 2
with the output attribute pair substituted:

- its catalogue row is category 7 (module, including
  rigs — category-7 rows with slot effect 2663; output
  rigs and rigs carrying an output drawback are
  therefore in scope as fitted items);
- one of its effects (joined through
  `dgmTypeEffects.csv.bz2`) carries a modifier with
  `func == ItemModifier` and `domain == shipID`;
- that modifier's modified attribute is **48**
  (`cpuOutput`) or **11** (`powerOutput`) — Flutter
  `cpuOutput = 48`, `powerOutput = 11`
  (`dogma_attributes.dart:3-4` at `ed698d3`); the
  catalogue's `cpuOutput` / `powerOutput` keys, loaded
  as `cpu_output` / `power_output`
  (`src/names/fitting_types.rs:32-34`) — in that locked
  order, CPU before power grid, wherever an order is
  needed (justified under Emission order below);
- its operator is `2`, `4`, or `6` (below);
- the operand — the item type's own `dgmTypeAttributes`
  value for the modifier's modifying attribute — is
  present, finite, and not `0.0`.

**Emission order [48, 11] (locked, justified).** CPU
precedes power grid in every body this slice touches:
Flutter's attribute table (`dogma_attributes.dart:3-4`),
the catalogue keys and loader fields (`cpuOutput`
before `powerOutput`), `FittingType::cpu_output` before
`power_output` (fitting_types.rs:32-34),
`FittingResources::Available { cpu, power }`
(resources.rs:375-378), and the block's rendered line
order (CPU line before Power grid line, both arms).
`OUTPUT_MODIFIER_ORDER = [48, 11]` (section 3) and the
pure layer's accumulator positions (section 4) follow
that order, as `CAPACITOR_MODIFIER_ORDER = [482, 55]`
followed its block's order. The catalogue key placement
is after the shield recharge keys (section 3), the
append position every sibling leg has taken.

**Supported operations (locked, with evidence).**
Design-censused over the committed data, category-7
`ItemModifier`/`shipID` modifiers on {48, 11} exercise
exactly three operator codes, each grounded in the
inspected Flutter ship path (`routeOwnerModifiers`
routes `ItemModifier`/`shipID` by operator into
add/mul/percent accumulators; the final ship loop
composes them; `dogma_engine.dart:25-34, 109-110,
534-581, 806-823` at `ed698d3`):

- **Operator 2, modAdd — flat add.** Flutter
  `_modAdd = 2`. Census: (11 ← 549 `powerIncrease`,
  unit MW) via effect 627 on 6 applicable types (Micro
  Auxiliary Power Cores, operands 10.0–15.0 MW). **No
  operator-2 carrier targets 48 in the catalogue** (the
  one ship-path operator-2 effect on 48, effect 3783,
  has zero category-7 carriers). Grounded and emitted
  if present — exactly the #619 treatment of operator 2
  on 479 — never invented for rows that lack it.
- **Operator 4, postMulAlt — multiplier.** Flutter
  `_postMulAlt = 4`, one of `_isMul`. Census:
  (48 ← 202 `cpuMultiplier`) via effect 536 on 19 types
  (Co-Processors, operands 1.07–1.19); (11 ← 145
  `powerOutputMultiplier`) via effect 56 on 45
  applicable types (Reactor Control Units, Power
  Diagnostic Systems, and kin, operands 1.025–1.186).
- **Operator 6, postPercent — percent.** Flutter
  `_postPercent = 6`, chaining `1 + value/100`. Census:
  (48 ← 424 `cpuOutputBonus2`) via effect 397 on 8 types
  (Processor Overclocking Unit rigs, 7.1 / 9.6);
  (48 ← 1138 drawback) via effects 2713/6669–6671 on 64
  types (rig drawbacks, all −10.0 — a *smaller* CPU
  output, applied as written, section 8 Oracle 7);
  (11 ← 313 `powerEngineeringOutputBonus`) via effect
  490 on 8 types (Ancillary Current Router rigs,
  10.0 / 15.0).

Every applicable category-7 carrier today has **at most
one applicable entry per attribute**, no carrier has a
duplicated (modified, modifying, operator) triple on
either attribute, and no carrier is
mixed-classification *within* one attribute. Section 3
locks those as fail-loud generator invariants, not as
silent assumptions.

**Unsupported operations (locked: counted, never
guessed).** No category-7 output carrier in the
committed data uses any operator outside {2, 4, 6};
all 17 zip modifier rows touching {48, 11} are
`ItemModifier`/`shipID` with operators in {2, 4, 6}
(census). Operators `0` (postMul) and `3` (modSub) are
defined by Flutter for the ship path in general, but no
48/11 carrier, fixture, or test in any inspected body
exercises them on {48, 11}. This slice therefore
grounds exactly {2, 4, 6} — the hp/cap/shield operator
set, not resistance's {0, 6} — from census and
Flutter-route evidence only.
Operators outside {2, 4, 6} with a present non-zero
operand are classified **unsupported** by the generator
(section 3: marks the type unapplied *in that
attribute's family*, emits no entry) and guarded the
same way at runtime (section 4). The same
counted-not-applied treatment covers every shape outside
the grounded one, and carriers outside category 7 gain
no emission (section 9 defers each by name): the skills
themselves (3426 with 424 = 5.0, 3413 with 313 = 5.0,
via effects 397/490 — the skill path is the shipped
`ResourceSkillLevels` machinery, never a second
emission; Flutter likewise excludes effects 397/490
from its skill-effect allowlist and reaches 48/11 only
through its known-skill percent table); implants
(category 20 — Zainou/Squire, Genolution CA-1/CA-2,
Aurora Omega 24345, outlet chip 57283, all via
397/490); subsystems (category 32 — 45623/45626/45629/
45632 with 313 = 20.0, 45625/45628 with 424 = 25.0, via
397/490 — locked out like every sibling's category-32
carriers, even though subsystem slots are counted slots
at runtime); structures (category 66 via 56/536); the
unpublished category-17 rows behind effects 3782/3783
and 3886/3887/4260–4263, which are never in the
catalogue. Unpublished category-7 gaps (types the SDE
names but the catalogue generation excludes as
unpublished) likewise gain nothing; the census counts
below are catalogue counts, as in every sibling (the
482 calibration of #618: 242 SDE category-7 carriers vs
182 in the catalogue).

**Census (locked counts).** Scripted over the committed
data (zip `modifierInfo` ⋈ `dgmTypeEffects` ⋈
`dgmTypeAttributes` ⋈ the current catalogue, category 7
only, the four-way classification of section 3 applied
**per attribute**):

- **48 (CPU output):** 91 carrier types → **91
  applicable** (91 entries: 19 operator-4 via 536, 72
  operator-6 via 397 (8), 2713 (58), 6669–6671 (6); 0
  operator-2), 0 absent-only, 0 zero-only, 0
  unsupported-only. The CPU-dimension marked-unapplied
  set is empty today. Slot mix: 19 low-slot, 72 rigs.
- **11 (power grid output):** 85 carrier types → **59
  applicable** (59 entries: 45 operator-4 via 56, 8
  operator-6 via 490, 6 operator-2 via 627), **26
  absent-only** (all effect 56 with attribute 145
  absent — the same 26-type Capacitor Power Relay /
  Capacitor Flux Coil family that is absent-only in the
  hit point, capacitor capacity, and shield recharge
  censuses: 506, 509, 1246, 1248, 1445, 1447, 8133,
  8135, 8175, 8177, 14144, 14146, 15080, 15082, 15084,
  15086, 15088, 15090, 15092, 15094, 15437, 17510,
  17528, 23894, 23896, 28532), 0 zero-only, 0
  unsupported-only. The 26 absent-only types are the
  power-dimension marked-unapplied set — real on
  shipped data, so the power output-unapplied line
  renders on real fittings (section 8 Oracle 8). Slot
  mix: 77 low-slot, 8 rigs.
- Distinct carrier types across both attributes: **176,
  with an empty intersection** — no type carries both a
  48-effect and an 11-effect today. A combined
  single-family emission would therefore produce
  identical bytes today; the per-attribute two-family
  split is still locked (section 3), for the #618
  reason: classification, marking, and counting are per
  dimension (CPU vs power grid disclosures are separate
  lines in this block), and a combined family would let
  a future dual carrier's applicable entry on one
  attribute silently pardon its absent operand on the
  other — the exact power-relay row that forced #618's
  split. Total category-7 types in the catalogue: 3925;
  every carrier has slot effects. Cross-family rows
  remain the norm: every effect-56 carrier also carries
  the capacitor, hit point, and shield recharge
  families (Power Diagnostic System II 1541 today emits
  `[[482, 4, 1.05]]`, `[[55, 4, 0.915]]`,
  `[[263, 4, 1.05]]`, `[[479, 4, 0.915]]` and gains
  `[[11, 4, 1.06]]`); the 8 CPU rigs carry a shield
  recharge entry beside their new CPU entry (4399:
  `[[479, 4, 1.1]]` shipped, `[[48, 6, 9.6]]` new); the
  26 absent-only power types are already marked in
  three sibling families. Classification stays per
  family on every leg, undisturbed.

**Arithmetic (locked, Flutter ship path verbatim, with
the skill composition).** For each of the two attributes
independently:

```text
bonused output = (hull output + Σ operator-2 operands)
                 × Π operator-4 operands
                 × Π (1 + percent / 100)
```

where the percent product ranges over the fitted items'
operator-6 operands **and, when skill levels are
supplied and the dimension's clamped output-skill level
is above 0, the one skill percent entry** for that
dimension. Sources, all at `ed698d3`: operator codes
`_modAdd = 2`, `_postMulAlt = 4` (one of `_isMul`),
`_postPercent = 6` (dogma_engine.dart:25-34, 109-110);
the `ItemModifier`/`shipID` route summing adds and
collecting muls and percents with scale 1.0 (the
penalized bonus path is never taken for ship
attributes, `:534-581, 744-750`); the known-skill table
entries `(3426, cpuOutput, 0.05)` and
`(3413, powerOutput, 0.05)` (`:214-223`) pushed as
`perLevel * level * 100` into the **same**
`percentModifiers` list as the module percents, only
when the ship base carries the attribute and the level
is non-zero (`:796-804`, whose comment names the pyfa
order: base plus adds, then multipliers, then
percents); the final composition
`value = (base + Σ adds) × Π mul × _percentChain(percent)`
(`:806-823`), the chain sorting by absolute value
descending (`:168-179`). Effects 397/490 are absent
from Flutter's skill-effect allowlist (`:54-70`) and
skipped in its skill loop, so that table is Flutter's
*only* skill path for 48/11 — the shipped Rust factor
is its single-entry special case. No Flutter test
exercises a 48/11 module modifier (its engine tests pin
the skill alone: 3426 L5 → 125 × 1.25 on a synthetic
hull; the modifier tests never target 48/11), so the
composition below is locked from the engine bodies and
pinned by this design's own hand oracles (section 8) —
stated plainly so no builder hunts for a Flutter module
oracle that does not exist. Locked consequences
builders must not "improve":

- **The skill is a percent entry, not a pre-scaling of
  the hull.** Adds are summed *before* the percent
  chain, so a Micro Auxiliary Power Core's flat
  megawatts are scaled by Power Grid Management and by
  module multipliers and percents: (41 + 12) × 1.15 ×
  1.25 = 76.1875, not (41 × 1.25 + 12) × 1.15 = 72.7375
  (section 8 Oracle 5 kills the
  skill-scales-base-then-add mutant). The shipped
  `output * (1 + 0.05 * level)` at resources.rs:444-446
  survives only as the definition of `base_output`
  (section 4); it is no longer how `output` is
  computed when any module entry exists.
- **Exact float association (locked, so no-carrier
  fittings are bit-identical on both arms).** The
  computation is the siblings' run association
  (section 4): add runs summed as
  `operand × (count as f64)` in first-seen order from
  `0.0`; mul runs folded through the shared bounded
  `mul_product` from `1.0`; percent runs **sorted by
  absolute value descending** (stable sort, the
  siblings' `sort_by` on `total_cmp` of `abs`), each
  folded as `mul_product(1.0 + value / 100.0, count)`
  from `1.0`; then
  `(base + add_total) * mul_total * percent_total` in
  that association. The skill entry is one extra
  percent run `(skill_value, 1)` appended after the
  module runs and before the sort, never merged into a
  module run of equal value (provenance stays auditable;
  for equal absolute values the stable order is
  module-then-skill, and `mul_product` association
  makes merged-vs-adjacent runs of one value agree bit
  for bit, so the choice is unobservable in the result
  — locked anyway so no builder improvises it). The
  skill percent value is Flutter's spelling,
  `0.05 * clamped_level as f64 * 100.0`, present only
  when levels are supplied and the clamped level is
  above 0 (Flutter's non-zero gate; a level-0 entry
  would be the factor 1.0 in any case). Design-time
  verification over IEEE doubles: for every clamped
  level 0–5, `1.0 + (0.05 * level * 100.0) / 100.0` is
  **bit-identical** to the shipped factor
  `1.0 + 0.05 * level`. Therefore, with no module
  entry, the bonused output reduces to
  `(base + 0.0) * 1.0 * (1.0 * skill_factor)` on the
  Some arm and `(base + 0.0) * 1.0 * 1.0` on the None
  arm — `base * skill_factor` resp. `base`, equal under
  `==` to today's outputs for every usable base that is
  exact `0.0` or normal (the subnormal qualification
  below). Builders must not reassociate
  (`base * mul * percent + adds`, skill applied after
  the helper, percent via `powf`): each is equal almost
  everywhere and 1-ulp different somewhere, which is
  exactly what section 8's `assert_eq` identity pins
  exist to catch.
- **No stacking penalty on 48 or 11, in any class.**
  Verified from the inspected body, never assumed:
  Flutter's `_percentChain` applies
  `getStackingPenalty` only when the attribute is in
  `_nonStackableAttributes`, exactly the twelve
  resonances, whose comment names cpu/powergrid as
  stackable (`:112-128, 168-179`); the multiplier route
  is never penalized for ship attributes at all. Every
  fitted unit therefore contributes its full factor —
  two Reactor Control Unit IIs give × 1.15 × 1.15, and
  a quantity-`q` row contributes `q` factors (the run
  count). `resistance_stacking_penalty` and
  `percent_chain` are never called on this path. That
  repeated output modules multiply in full is a way
  these numbers can differ from the EVE client; it is
  the inspected Flutter order this slice locks, and the
  block's disclosure keeps its "can differ from EVE"
  sentence (section 7). Named here so review does not
  "fix" it toward folklore.
- **Bonuses can shrink the output, and nothing
  clamps.** Rig drawbacks subtract 10% of CPU output as
  written (130.0 → 117.0), so the bonused output can be
  *below* base and a fitted rig can move a budget from
  under to over. There is no floor at base, no ceiling,
  and no "bonus must help" filter — the #619
  slower-than-base rule on this pair.
- **Positive subnormal is no data — the `2ac348f`
  guard, from day one, per dimension.** The bonused
  result is filtered by the shipped predicate verbatim
  — `v.is_finite() && *v >= 0.0 && (*v == 0.0 ||
  v.is_normal())` (ship_resistances.rs:810, :951). A
  positive subnormal is stall residue from a
  hostile-quantity run underflowing toward zero; an
  exact `0.0` stays a real zero (a present-`0.0` hull
  output, or a fixture percent of −100, computes
  honestly and judges over/left against 0.0). A fixture
  base that is itself a positive subnormal passes the
  usability filter and is then rejected by the result
  filter, exactly as `bonused_capacitor` treats it;
  catalogue outputs are ordinary magnitudes, so the
  identity claims in section 8 are unconditional on
  shipped data. What a `None` bonused output does to
  the outcome is section 4's lock (whole result
  unavailable — a partial resource total is never
  shown complete beside a surviving dimension).
- **Absent base is never resurrected — the house
  divergence from Flutter, named again.** Flutter's
  base fallback (0.0 if add-only else 1.0) is *not*
  adopted: an absent, negative, or non-finite hull
  output makes the whole result `ShipNoOutput` under
  the shipped gate however many bonuses target it
  (section 5); a Micro Auxiliary Power Core never
  invents a power grid on a hull with no output data.
  A *present* `0.0` base is a real zero and bonuses
  apply to it normally ((0 + adds) × … — section 8
  pins a flat add raising a zero-output hull).
- **Counted vs consuming populations (locked — this
  slice's scan trap).** Used sums keep the shipped
  consuming population (Lo/Med/Hi slot flags only,
  resources.rs:387-389). Output bonuses use the
  siblings' counted population (Lo/Med/Hi **plus rig
  and subsystem** slot flags, `counted_flag`,
  ship_resistances.rs:269-275; Flutter's `allModules`
  is high+med+low+rig+subsystem): 80 of the 150
  applicable entries sit on rigs, which add 0 to used
  and all of their effect to output. A rig under any
  counted flag contributes; a carrier under a
  non-counted flag (cargo, drone bay, charges)
  contributes nothing and counts nowhere. Slot
  belonging is never judged, as shipped.
- **No module state**, as #615 locked: every counted
  fitted item contributes as if active. That assumption
  becomes user-visible wording in this block for the
  first time (section 7).

## 3. Catalogue extension (locked)

The bundled catalogue gains per-type output modifier
entries through its existing generator only, mirroring
#618 section 3 (the two-family shape) in every
particular this section does not state. Hand-editing
the JSON is forbidden. Catalogue today: 3,879,254
bytes, sha256
`aa5b41616741a6c081e8bf8bceb2104dc97c5518bb7948b1c4e278556d492414`
(`assets/sde/fitting_types.json`, re-hashed at design
time; the shield recharge slice's regenerated asset).

**Generator changes**
(`scripts/sde/generate_fitting_types_sde.py`). The
output legs reuse the inputs the resistance leg already
reads — `dogmaEffects.jsonl` from the committed zip
(fail-loud if missing or unreadable), `dgmTypeEffects`,
`dgmTypeAttributes`, and the category map — extending
the wanted-modifying-ids set to the output modifying
attributes so one operand pass serves all legs (the
wanted-set assembly at lines 1699–1733 gains a
`wanted_output_modifying_ids` set beside the shield
recharge one; the operand-label helper
`modifier_operand_label` at lines 1743–1760 gains an
"output modifier operand" label for ids wanted by this
leg alone — noting attributes 313 and 424 are also the
operand attributes of the skill rows, which changes
nothing in the label rule — and ids wanted by more than
one leg keep the generic label). No second zip read;
the generator still never downloads; the header comment
gains the output keys paragraph after the shield
recharge paragraph (the header's last paragraph today,
ending at line 184).

- Beside `SHIELD_RECHARGE_MODIFIER_ORDER` (line 313),
  add the locked constants with a provenance comment
  citing `dogmaEffects.jsonl`, the caches, and Flutter
  `dogma_engine.dart` / `dogma_attributes.dart` at
  `ed698d3` for the attribute ids, the operator codes,
  and the absent/zero skip:

  ```python
  OUTPUT_MODIFIER_ORDER = [48, 11]
  OUTPUT_MODIFIER_OPERATORS = {2, 4, 6}
  OUTPUT_MODIFIER_ATTRS = {48, 11}
  ```

  The order is CPU output before power grid output
  everywhere an order is needed (emission key order
  below, the pure layer's accumulator positions in
  section 4), justified in section 2; the operator set
  is section 2's grounded three.
- Build **two** per-type entry maps beside
  `shield_recharge_modifiers_by_type` (line 2111), one
  per attribute — `cpu_output_modifiers_by_type`
  (modified 48) and `power_output_modifiers_by_type`
  (modified 11) — each classifying every
  `ItemModifier`/`shipID` modifier on its attribute,
  category-7 types only, deduplicated by (modified,
  modifying, operator), as exactly one of (the #615
  four-way classification, applied per attribute per
  section 2's census finding):
  - **applicable**: operator in {2, 4, 6} and operand
    present, finite, and not `0.0` → an emitted entry;
  - **unsupported**: operator outside {2, 4, 6} and
    operand present and not `0.0` → no entry; marks the
    type unapplied *in that attribute's family* (zero
    types today);
  - **zero**: operand present and exactly `0.0` → no
    entry, no mark (provably no bonus; zero types
    today);
  - **absent**: operand not in the cache for this type →
    no entry; marks the type unapplied in that family
    **only if the type ends with no applicable entry
    and no zero classification in that family** (the
    #615 predicate, per family; the 26 absent-only
    power types of section 2, and no CPU types).
- Loud failures, house style (`fail(...)`, writes
  nothing), mirroring the capacitor and shield recharge
  legs: an unparseable or non-finite operand value on a
  classified modifier; a duplicated (modified,
  modifying, operator) triple on one type in either
  family; two applicable entries on one type sharing a
  modified attribute (in a single-attribute family: two
  applicable entries at all). All are zero on today's
  data (censused). Messages say "output modifier",
  never "capacitor modifier", "hit point modifier",
  "shield recharge modifier", or "resistance
  modifier". Deliberately **not** failures: operand
  values outside today's observed ranges (a negative
  add, a multiplier at or below `0`, a percent at or
  below −100 — arithmetic the locked formula defines
  and the pure layer guards, section 4), absent
  operands, and zero operands.
- **Emission (locked shape).** Additive and sparse,
  category 7 only, all existing keys byte-stable and
  every non-category-7 row byte-identical to today.
  Each family emits independently, exactly as if it
  were its own #619 leg: a carrier type emits
  `cpuOutputModifiers` iff it has at least one
  applicable CPU entry **or** is marked CPU-unapplied,
  and likewise `powerOutputModifiers` for power. Each
  value is a JSON array of `[modifiedAttributeId,
  operator, operand]` triples (numbers, compact
  separators; today at most one triple per family per
  type, its modified id the family's attribute), with
  the operand baked in at generation time — the
  modifying attribute id is deliberately not emitted,
  for the #615 reason. A type marked unapplied in a
  family additionally emits that family's
  `cpuOutputModifiersUnapplied: true` (resp.
  `powerOutputModifiersUnapplied: true`) beside the
  (possibly empty) array. An all-zero carrier in a
  family emits **neither of that family's keys**. The
  full unapplied predicate, per family (locked): a
  category-7 type with at least one
  `ItemModifier`/`shipID` modifier on the family's
  attribute is marked in that family iff (a) any such
  modifier classed unsupported, or (b) it has no
  applicable entry, no zero classification, and at
  least one absent classification in that family.
  Today that marks exactly **0 types in the CPU
  family** and **26 types in the power family** (all
  empty-array). The Capacitor Power Relay I row 1445
  is the shape to hold in mind: it already emits empty
  marked arrays in the hit point, capacitor capacity,
  and shield recharge families plus
  `capacitorRechargeModifiers: [[55, 4, 0.8]]`, and now
  also gains `powerOutputModifiers: []` with
  `powerOutputModifiersUnapplied: true` — and no CPU
  keys — five-plus families judged independently on
  one row. Key placement is immediately after the
  shield recharge modifier block (lines 3377–3388,
  before `types.append(entry)` at line 3389), in the
  order `cpuOutputModifiers`,
  `cpuOutputModifiersUnapplied`, `powerOutputModifiers`,
  `powerOutputModifiersUnapplied` — CPU before power
  per `OUTPUT_MODIFIER_ORDER`, and after the shield
  keys per the append-only rule — so pre-existing key
  order on every row is untouched, and a row like 1541
  carrying every family emits resistance (none), hit
  point, capacitor capacity, capacitor recharge,
  shield recharge, then power output keys.
- **Self-validation.** Two oracle lists beside
  `SHIELD_RECHARGE_MODIFIER_ORACLES` (line 822), same
  tuple shape `(type_id, expected_entries_or_None,
  expected_unapplied)` where `None` means neither of
  that family's keys may be present. Values are
  cache/zip reads from the section 2 census, re-read
  at design time (section 8 gives the arithmetic they
  feed):
  - `CPU_OUTPUT_MODIFIER_ORACLES`:
    - 3469 'Basic' Co-Processor: `[[48, 4, 1.07]]`;
      3888 Co-Processor II: `[[48, 4, 1.1]]` (the
      multiplier pins);
    - 4395 Medium Processor Overclocking Unit I:
      `[[48, 6, 7.1]]`; 4399 II: `[[48, 6, 9.6]]` (the
      CPU rig percent pins — beside their shipped
      shield entries `[[479, 4, 1.05]]` /
      `[[479, 4, 1.1]]`);
    - 25908 Large Drone Control Range Augmentor I:
      `[[48, 6, -10.0]]` (the drawback pin — the sign
      and the negative direction are the test);
    - 1355 Reactor Control Unit II: neither CPU key
      (power-only carrier); 1541 Power Diagnostic
      System II: neither CPU key (the
      disjointness pin); 2048 Damage Control II:
      neither (non-carrier); 587 Rifter (category 6),
      3426 CPU Management (category 16 — carries a real
      (48 ← 424) triple with operand 5.0 and gains
      nothing; the skill path stays
      `ResourceSkillLevels`), 24345 (category 20
      implant), and 45625 Tengu Core - Electronic
      Efficiency Gate (category 32 — carries a real
      (48 ← 424) triple with operand 25.0 and gains
      nothing, section 9): neither (the category-gate
      pins).
  - `POWER_OUTPUT_MODIFIER_ORACLES`:
    - 1353 Reactor Control Unit I: `[[11, 4, 1.1]]`;
      1355 II: `[[11, 4, 1.15]]`; 1537 'Basic' Power
      Diagnostic System: `[[11, 4, 1.025]]`; 1541 Power
      Diagnostic System II: `[[11, 4, 1.06]]` (the
      multiplier pins);
    - 11563 Micro Auxiliary Power Core I:
      `[[11, 2, 10.0]]`; 4254 Micro Auxiliary Power
      Core II: `[[11, 2, 12.0]]`; 31936 Navy Micro
      Auxiliary Power Core: `[[11, 2, 13.0]]` (the
      flat-add pins);
    - 25956 Large Ancillary Current Router I:
      `[[11, 6, 10.0]]`; 26370 II: `[[11, 6, 15.0]]`
      (the power rig percent pins);
    - 1445 Capacitor Power Relay I and 506 'Basic'
      Capacitor Power Relay: empty array, unapplied
      true (the absent-145 pins — both rows keep their
      other families' keys exactly as today);
    - 3888 Co-Processor II: neither power key (CPU-only
      carrier); 2048, 587, 3413 Power Grid Management
      (category 16), 45623 Legion Core - Augmented
      Antimatter Reactor (category 32 — carries a real
      (11 ← 313) triple with operand 20.0 and gains
      nothing): neither, as above.
- **Catalogue-wide invariants** beside the shield
  recharge checks (oracle/count validation after line
  3791 and counts at lines 3800–3821; the per-row
  invariant pass in its shield recharge shape), per
  family: every present family array is on a
  category-7 row; its entries' modified id is the
  family's attribute, operators in {2, 4, 6}, operands
  finite and not `0.0`, no duplicate modified id; each
  unapplied marker appears only beside its family's
  array and only as `true`; the counts equal the
  census values for today's data, as named constants
  in the `SHIELD_RECHARGE_MODIFIER_ROWS` pattern (lines
  854–857): CPU **91 rows with the key, 91 non-empty,
  0 marked, 91 entries**
  (`CPU_OUTPUT_MODIFIER_ROWS`,
  `CPU_OUTPUT_MODIFIER_NONEMPTY_ROWS`,
  `CPU_OUTPUT_MODIFIER_MARKED_ROWS`,
  `CPU_OUTPUT_MODIFIER_ENTRIES`); power **85 rows with
  the key (59 with entries plus 26 marked-empty), 26
  marked, 59 entries** (the `POWER_OUTPUT_MODIFIER_*`
  four). The summary print (beside lines 5105–5108)
  gains those counts.
- Determinism unchanged: types sorted by `typeId`,
  compact separators, trailing newline, no timestamps.
  Proof obligations for the catalogue commit (section
  8): run the generator twice → identical sha256;
  strip the four new keys from the regenerated file →
  byte-identical to today's `aa5b4161…`. Both proofs
  are run once and reported in the commit body, not
  committed as scripts.

**Size budget.** A simulation of the locked emission
over the census shape (176 keyed family-rows — 91 CPU
plus 85 power, on 176 distinct types — 150 triples, 26
unapplied markers, compact separators, the key names
above; an entry fragment
`,"cpuOutputModifiers":[[48,4,1.1]]` is 34 bytes, a
marked power fragment
`,"powerOutputModifiers":[],"powerOutputModifiersUnapplied":true`
is 65 bytes) adds ≈7,200 bytes (≈ +0.19%). Budget: the
regenerated file must land within **+10,000 bytes** of
today's 3,879,254; the catalogue commit body states the
exact new byte count. Anything over budget means the
emission rule drifted (for example emitting zero
operands, marking non-absent types, emitting the skill
or subsystem rows, or emitting on non-category-7 rows)
and stops the slice for review.

**Rust loader** (`src/names/fitting_types.rs`).
`FittingType` gains, immediately after the two shield
recharge modifier fields (lines 159–162), in the
capacitor fields' comment style:

```rust
#[serde(rename = "cpuOutputModifiers", default)]
pub cpu_output_modifiers: Option<Vec<OutputModifier>>,
#[serde(rename = "cpuOutputModifiersUnapplied", default)]
pub cpu_output_modifiers_unapplied: bool,
#[serde(rename = "powerOutputModifiers", default)]
pub power_output_modifiers: Option<Vec<OutputModifier>>,
#[serde(rename = "powerOutputModifiersUnapplied", default)]
pub power_output_modifiers_unapplied: bool,
```

with **one** new struct in the same module beside
`ShieldRechargeModifier` (line 529),
`OutputModifier { pub modified_attribute_id: i64, pub operator: i64, pub operand: f64 }`,
deserialized from the 3-element array by the same
manual tuple impl. One struct for both families,
deliberately, for the #618 reason: the two families
are one slice, one operator set, and one triple shape,
with the modified attribute id (48 or 11) carried in
every entry — there is no second slice boundary for a
second struct to mark, and reusing `CapacitorModifier`
or `ShieldRechargeModifier` would misname every
invariant and call site in this slice. Its doc comment
pins the semantics: entries are generation-time-proven
`ItemModifier`/`shipID` output bonuses on attribute 48
(CPU family) or 11 (power family) with the operand
baked in (operator 2 is modAdd, 4 is postMulAlt, 6 is
postPercent); operands can shrink the output (rig
drawbacks carry −10.0 percents) and are applied as
written; `Some(empty)` with the unapplied flag is a
carrier whose bonus *in that family* the bundled data
cannot ground and must be counted, never read as "no
bonus"; `None` is a non-carrier or an all-zero carrier
*in that family* — the other family is judged
independently. `#[serde(default)]` keeps old assets
and `from_json` fixtures loading as `None`/`false`.
Nothing is validated at load (the pure function guards
values, section 4; the invariants test proves the
shipped asset). Field placement note (locked, do not
"tidy"): the new fields sit after the shield recharge
fields, **not** beside `cpu_output`/`power_output` at
lines 32–34 — every modifier family has appended in
slice order, and moving the base output fields to
group them is churn this slice does not need.

**Invariants to add** to `bundled_catalogue_invariants`
(`src/names/fitting_types.rs`), beside the shield
recharge block (per-row checks in the shape of lines
1703–1740; counts and spot pins after the shield
recharge counts), all over the real bundled asset, per
family: the family array is `Some` only on category-7
rows; CPU exactly 91 rows carry it, 91 non-empty, 0
marked unapplied, 91 entries total; power exactly 85
rows, 59 non-empty, 26 marked, 59 entries; every
entry's modified id is the family's attribute (48
resp. 11) with no duplicate modified id per row,
operator is 2, 4, or 6, operand finite and `!= 0.0`;
each unapplied marker appears only beside its family's
`Some`; spot pins mirroring the generator oracles
(3469, 3888, 4395's `[[48, 6, 7.1]]`, 4399's
`[[48, 6, 9.6]]` beside its shipped
`shieldRechargeModifiers: [[479, 4, 1.1]]`, 25908's
`[[48, 6, -10.0]]`, 1355's `[[11, 4, 1.15]]` with CPU
`None`, 1541's `[[11, 4, 1.06]]` beside its shipped hit
point, both capacitor, and shield recharge families
with CPU `None`, 4254's `[[11, 2, 12.0]]`, 26370's
`[[11, 6, 15.0]]`, 1445 and 506 power-empty-with-flag
beside their shipped families unchanged, 3888 power
`None` beside CPU `[[48, 4, 1.1]]`, 2048 / 587 / 3413 /
3426 / 24345 / 45623 / 45625 `None` in both families
with flags false). The existing invariants pass
unmodified.

## 4. Pure API (locked)

**Placement (locked, justified): the bonused-output
helper lives in `src/fitting/ship_resistances.rs`, and
`src/fitting/resources.rs` consumes it.** The rejected
home is `resources.rs` itself. Four reasons, in the
siblings' stated form: (1) `ship_resistances.rs`
already owns the counted-item scan (`counted_flag`,
line 269), the bounded run arithmetic (`mul_product`,
line 283), and all three shipped bonused-attribute
helpers (`bonused_hit_points`, `bonused_capacitor`,
`bonused_shield_recharge_duration`, lines 502, 639,
849) — this helper is the fourth sibling of exactly
that family, differing only in the attribute pair and
the one skill percent run, and #617/#618/#619 each
placed theirs there rather than in the consumer's
module (`ship_cap_stability.rs` / `ship_peak_recharge.rs`
consume, never fork); (2) the scan this slice needs is
the counted scan (rig- and subsystem-inclusive,
section 2), which is *not* `resources.rs`'s consuming
scan — implementing it in `resources.rs` would fork
`counted_flag` and invite the two predicates to drift
on exactly the population distinction section 2 calls
this slice's trap; (3) `resources.rs`'s own independence
precedent (it tests ESI flag prefixes itself rather
than depending on a UI enum, header lines 27–33) is
about not depending on the UI, not about avoiding
crate-internal pure helpers — it already depends on
`FittingTypes`, and `ship_resistances.rs`'s tests
already depend on `resources::fitting_resources` for
independence pins, so the module graph gains no new
shape; (4) a generalized helper spanning all shipped
families is rejected for the siblings' reason: the
helpers differ exactly in the dimensions a generic
signature would have to parameterize (attribute set,
family split, excluded-count source, and here the
skill run), and refactoring shipped helpers onto a
shared engine would put every sibling literal at risk
for no behaviour this slice needs. What is shared is
what the siblings already share — `counted_flag` and
`mul_product` — reused, never forked. No new module.

**Bonused outputs helper** (`ship_resistances.rs`,
beside `bonused_shield_recharge_duration`). Names are
part of the lock:

```rust
/// Bonused CPU output (tf) and power grid output (MW),
/// composed with the two trained output-skill percents
/// when levels are supplied, plus the fitted-module
/// counts the caller must disclose beside any number
/// derived from them. The shared catalogue-absent
/// excluded count is deliberately not carried: the
/// sole caller discloses excluded rows per resource
/// dimension from its own scan (the
/// `bonused_hit_points` precedent).
pub(crate) struct BonusedOutputs {
    /// [cpu_output, power_output] in OUTPUT_ORDER
    /// position, each `None` exactly where the base
    /// value is absent, negative, or non-finite, or
    /// the bonused result is negative, non-finite, or
    /// a positive subnormal.
    pub values: [Option<f64>; 2],
    /// CPU-output-dimension count: counted fitted rows
    /// the catalogue marks as CPU output carriers whose
    /// bonus cannot be applied, in quantity units.
    /// Never summed with
    /// `power_output_unapplied_modules`.
    pub cpu_output_unapplied_modules: usize,
    /// Power-output-dimension count: same shape for the
    /// power family. Never summed with
    /// `cpu_output_unapplied_modules`.
    pub power_output_unapplied_modules: usize,
}

/// `None` only when the ship gate fails (`ship_type_id
/// <= 0`, no catalogue row, or the row is not category
/// 6). Otherwise `Some`, per-value `None` as documented
/// on `values`. `output_skill_levels` is
/// (cpu_management, power_grid_management) raw trained
/// levels — only the two output skills, so no
/// need-reduction concept can enter this module —
/// defensively clamped to 0..=5 inside; `None` composes
/// module bonuses with no skill entry.
pub(crate) fn bonused_outputs(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
    output_skill_levels: Option<(i32, i32)>,
) -> Option<BonusedOutputs>;
```

Locked helper semantics, mirroring `bonused_capacitor`
(lines 639–818) with the output pair and the skill run:

- **Ship gate and bases.** The siblings' gate verbatim.
  A new private constant beside `CAPACITOR_ORDER`
  (line 224) names the pair in locked position
  (`OUTPUT_ORDER: [i64; 2] = [48, 11]`), and a private
  `base_outputs` beside `base_capacitor` (line 261)
  reads `[ship.cpu_output, ship.power_output]`. Each
  base is under the same usability filter shape
  (present, finite, `>= 0.0`; present `0.0` is a real
  zero). Run lists are the siblings' per-index
  `Vec<(f64, u64)>` arrays-of-two (add/mul/percent).
- **Counted scan.** Identical item predicate and
  quantity-units handling to the siblings (`type_id >
  0`, positive quantity, `counted_flag`,
  `usize::try_from`, saturating adds). Per family it
  reads `cpu_output_modifiers` /
  `cpu_output_modifiers_unapplied` (resp. power) with
  the once-per-item `counted_unapplied` pattern exactly
  as `bonused_capacitor`'s two family blocks: the
  catalogue unapplied flag counts the item's units
  once in that dimension; an entry whose modified id
  is not the family's attribute, whose operator is
  outside {2, 4, 6}, or whose operand is non-finite or
  `0.0` counts the item once in that dimension (if not
  already counted) and is skipped — applicable entries
  on the same item are still applied. A family defect
  never counts in the other dimension, and no other
  family's fields are read. Catalogue-absent counted
  rows are **not** counted by this helper (see the
  resources-side excluded rule below); they contribute
  no runs.
- **Skill run (locked).** After the item scan, per
  dimension in `OUTPUT_ORDER` position: when
  `output_skill_levels` is `Some` and the dimension's
  level re-clamped to `0..=5` (a private two-line clamp
  in this module — the defensive re-clamp the siblings'
  helpers apply to their own inputs; `resources.rs`'s
  `clamp_level` is private to its module and is not
  reached into) is above 0, push the run
  `(0.05 * clamped_level as f64 * 100.0, 1)` onto that
  dimension's `percent_runs` — appended after the
  module runs, before the sort (section 2's association
  lock). `Some((0, 0))` is therefore identical to
  `None` in every value and count.
- **Run accumulation and bounded arithmetic.** Three run
  lists per dimension grouped by exact `==` operand
  value with saturating `u64` counts in first-seen
  order, composed in the siblings' exact association:

  ```text
  add_total     = Σ over add runs of operand × (count as f64)
  mul_total     = Π over mul runs of mul_product(operand, count)
  percent_total = Π over percent runs sorted by |value|
                  descending (skill run included), of
                  mul_product(1.0 + value / 100.0, count)
  bonused       = (base + add_total) × mul_total × percent_total
  ```

  `mul_product` is reused, not forked; **no stacking
  penalty** (section 2), so `percent_chain` is not
  called. The result is `Some(bonused)` filtered by
  the `2ac348f` predicate verbatim —
  `v.is_finite() && *v >= 0.0 && (*v == 0.0 ||
  v.is_normal())` — with the sibling's explanatory
  comment adapted in the same edit. A hostile quantity
  can therefore only yield the formula's own finite
  non-negative normal value, an exact `0.0`, or `None`
  — never a hang, never infinity, never a subnormal
  output passed downstream (section 8 pins each class,
  with the helper result asserted, never discarded).
- **Identity (locked, exact).** With no applicable
  module entry and a base that is exact `0.0` or
  normal: on `None` levels the value is
  `(base + 0.0) × 1.0 × 1.0` — the base, equal under
  `==`; on `Some` levels it is
  `(base + 0.0) × 1.0 × (1.0 × skill_factor)` with the
  skill factor bit-identical to the shipped
  `1.0 + 0.05 * level` for every level 0–5 (section
  2) — today's output, equal under `==`. A fixture
  base that is itself a positive subnormal is rejected
  by the result filter (section 2 qualification), as
  in `bonused_capacitor`.
- The helper is `pub(crate)`, never re-exported from
  `src/fitting/mod.rs` (the `pub use ship_resistances`
  list at mod.rs:49–53 does not change; the caller
  names it as
  `crate::fitting::ship_resistances::bonused_outputs`).
  The `ship_resistances.rs` module header gains a short
  paragraph naming it as the output sibling serving
  fitting resources under this document (section 7).
  No logging is added.

**Resources integration** (`src/fitting/resources.rs` —
the quantities' own module; the signatures of
`fitting_resources` and `fitting_resources_with_skills`
do not change). Locked changes, stated in full:

- `ResourceBudget` (lines 342–360) gains exactly two
  fields:
  - `pub base_output: f64` immediately after `output` —
    the output before fitted-module output bonuses:
    the hull output on the None path, and hull output
    × the shipped skill factor on the Some path. It is
    computed by the shipped expression verbatim
    (`output * (1.0 + 0.05 * clamp_level(level) as
    f64)`, the current lines 441–448), never re-derived
    from the helper, so it is bit-identical to today's
    `output` by construction on every fitting — the
    figure the block has always shown, kept visible
    (section 6). Equals `output` exactly when no output
    carrier is counted (asserted, section 8).
  - `pub output_unapplied_modules: usize` after
    `unreduced_modules` — counted rows the catalogue
    marks as carriers in this dimension whose output
    bonus cannot be applied, in quantity units, from
    `BonusedOutputs`; never summed with the other
    dimension's count, with `excluded_modules`, or
    with `unreduced_modules`. Unlike
    `unreduced_modules`, it is **not** gated on levels:
    module bonuses apply on both arms, so the count is
    computed and disclosed on both (it is non-zero on
    shipped data — section 2's 26-type power set — on
    either arm).
  Field doc comments mirror `base_used`'s and
  `unreduced_modules`' in shape. `FittingResources`'
  enum shape (`Available { cpu, power }` /
  `ShipNoOutput`) does not change, and no other public
  name is added (mod.rs:33–37 unchanged).
- **Composition point.** The ship gate (lines 421–437)
  is evaluated first and unchanged. The function then
  computes `base_output` per dimension by the shipped
  expression, calls `bonused_outputs(fitting,
  catalogue, levels.map(|l| (l.cpu_management,
  l.power_grid_management)))` exactly once, and takes
  each dimension's `output` from `values` in
  `OUTPUT_ORDER` position. It reads no output-modifier
  catalogue field itself. The helper can return `None`
  only on the ship gate both functions share (already
  passed), so a helper `None` here is unreachable by
  construction; the `else` arm nonetheless returns
  `ShipNoOutput` (no `unwrap`, no panic — the pure
  layer never panics).
- **Bonused `None` is whole-result unavailable
  (locked).** If either dimension's bonused value is
  `None` (negative, non-finite, or positive subnormal
  under the formula — unreachable on shipped catalogue
  operands at sane quantities; reachable by fixture
  operands and by hostile quantities of real carriers,
  section 8), the function returns
  `FittingResources::ShipNoOutput`. There is no
  per-dimension partial budget: the struct's outputs
  are plain `f64`, the two dimensions render as one
  used-vs-output judgment, and a surviving dimension
  beside a silently base-filled one would be a partial
  resource total shown complete — the coupled rule,
  stated for outputs as #619 states it for its pair.
  This adds no new *base* route to `ShipNoOutput`
  (section 5): the gate that decides "no numbers from
  base data" is byte-for-byte the shipped one, evaluated
  first; the bonused route exists only where base
  numbers *did* exist and the locked arithmetic then
  produced no honest output. The unavailable sentence
  it renders under is the shipped one, unedited
  (section 7 notes this as a deliberate non-change:
  the sentence is already the block's single
  no-numbers sentence, and the hostile route to it is
  not user-reachable on shipped data).
- **Excluded widening (locked, the one change to a
  shipped count definition).** In the item loop, a
  catalogue-absent counted row that is not consuming
  (rig or subsystem slot flag, `type_id > 0`, positive
  quantity) now adds its quantity units to **both**
  dimensions' `excluded_modules` — the same treatment
  a catalogue-absent consuming row already gets (lines
  475–479) — because such a row can no longer be
  dismissed as "rigs never affect this block": it may
  be an output rig the bundled data cannot describe,
  and the excluded lines' wording ("no CPU data" /
  "no power grid data") is already true of a wholly
  absent row in both dimensions. Present rig/subsystem
  rows change nothing in the need scan: they still
  neither consume nor exclude *for needs* (their
  carrier status is the helper's output-unapplied
  dimension). The flag test is local to `resources.rs`
  in its shipped independence style (`is_consuming_flag`
  gains no change; the loop tests the rig/subsystem
  prefixes where it currently `continue`s) — one
  two-prefix predicate, not a fork of the counted scan,
  which stays solely in the helper. Consequences are
  pinned, not incidental: an excluded row is never
  also output-unapplied (the helper never sees a row
  for it), exactly as excluded is checked before
  unreduced today; unknown rows under non-counted
  flags (DroneBay, Cargo, anything else) still count
  nowhere; and exactly one shipped demo number moves
  (section 8). No other count definition changes.
- Everything else in the function — used/base_used
  sums, `dimension_factor` reductions, the unprovable
  rules, saturating counts — is untouched. The module
  header (lines 1–25) and the `fitting_resources_with_skills`
  doc (lines 404–412) are revised as section 7 lists;
  no behaviour hides in those edits.

**Count inventory at the API surface (collected).**
Per dimension on `Available`, three deficit counts,
three definitions, no sums: `excluded_modules` (needs
unknown, plus the section-4 absent-counted widening),
`unreduced_modules` (reduction unprovable, Some-arm
only by its shipped rule), `output_unapplied_modules`
(output bonus ungroundeable, both arms). A single
fitted item can raise at most one of {excluded,
output-unapplied} per dimension (absent rows are
excluded; present marked carriers are unapplied), and
can raise unreduced independently of either — the
dimensions are disclosed, never merged.

## 5. Completeness and None rules (locked)

Collected in one place; sections 2 and 4 are normative
and this section adds nothing to them:

- **Output `None` rules are unchanged.** The result is
  `ShipNoOutput` for base reasons exactly where it is
  today: `ship_type_id <= 0`, no catalogue ship row,
  ship row not category 6, or either hull output
  absent, negative, or non-finite (`usable`,
  resources.rs:394–396) — on both arms, at every skill
  level, however many output carriers are fitted. A
  bonus never resurrects missing base output data in
  either dimension, and the gate still requires *both*
  dimensions: one usable output never renders beside a
  missing one (no partial resource totals, as shipped).
- The one additional route to `ShipNoOutput` is the
  bonused-`None` rule of section 4 (a bonused output
  that is negative, non-finite, or a positive
  subnormal): a property of the bonused arithmetic on
  otherwise usable base data, not a change to the base
  gate. An exact `0.0` bonused output is a real zero:
  present-`0.0` hull outputs still compute (and can be
  raised by a flat add), an output bonused to exactly
  `0.0` still renders and judges over/left against 0.0,
  and hull-only against `0.0` is still not over —
  every zero-output pin shipped today survives
  (section 8).
- Missing *module* data never zeroes a dimension: an
  absent need excludes (counted), an unprovable
  reduction keeps full need (counted), an ungroundeable
  output bonus leaves that carrier contributing nothing
  to output (counted) — each in its own count, never
  as a silent 0 in a sum or a silent identity in an
  output.
- Availability of this block says nothing about any
  sibling block, and vice versa, as shipped; the
  independence pins in sibling test modules that match
  `FittingResources::Available { .. }` /
  `ShipNoOutput` against partial catalogues keep their
  meaning because the base gate is unchanged (their
  fixtures fit no output carrier under a counted flag
  with hostile operands — section 8 keeps them as
  regression gates and names the one fixture class
  that would need care).

## 6. Display (locked)

No new block and no new renderer: the existing
`render_fitting_resources` (`src/ui/fittings.rs:2191`)
renders the bonused outputs through the shipped
`resource_line`, at its two existing call sites —
imported detail (line 4133) and saved detail (line
4446) — with no call-site edit (both already pass
`levels` from `resource_skill_levels` over the owning
character's ready skills; module bonuses need nothing
beyond fitting plus catalogue, so nothing about that
supply changes). Reading order of the detail surfaces
is unchanged. The block renders even when the fitting
has no items and even when every bonused output equals
its before-figure, as shipped. It depends only on
fitting, catalogue, and (unchanged) levels, logs
nothing, and shows no raw EVE ID.

Changes inside the renderer, and nowhere else in the
UI:

- **Heading values** change on both arms (section 7's
  verbatim strings; the constant *names*
  `FITTINGS_RESOURCES_HEADING` /
  `FITTINGS_RESOURCES_APPLIED_HEADING` are kept —
  renaming locked-wording constants for a value change
  is churn, and their doc comments carry the new
  meaning). The no-catalogue and `ShipNoOutput` arms
  keep rendering the base-arm heading over the shipped
  unavailable sentences, exactly as every sibling
  bonused block renders its bonused heading over its
  unavailable sentence; the applied heading is still
  chosen only for an `Available` result with supplied
  levels.
- **Before-module-bonuses output lines (new, always
  rendered in both arms).** A new pure helper,
  `base_output_line(label: &str, budget:
  &ResourceBudget, unit: &str) -> String` beside
  `base_need_line` (line 2106), renders one line per
  dimension from `budget.base_output` in
  `base_need_line`'s template (section 7). Always
  rendered — even when it equals the output in
  `resource_line` — for `base_need_line`'s stated
  reason: a bonused figure never replaces the figure
  the block has always shown *silently*, and a line
  that appears only when it differs would teach the
  reader that its absence means "no bonuses fitted",
  which an identity or drawback-cancelling fit would
  falsify. Placement: immediately after the two
  `resource_line`s in each arm, CPU then power grid.
- **Output-unapplied count lines (new).** Two new pure
  helpers, `cpu_output_unapplied_line(usize) ->
  Option<String>` and
  `power_grid_output_unapplied_line(usize) ->
  Option<String>` beside the unreduced pair (lines
  2148–2179), `None`-at-0 / singular / plural in the
  sibling count-line shape (section 7's strings).
  Placement in each arm: after the excluded lines and
  (Some arm) the unreduced lines, before the
  disclosure — the sibling order (the new dimension's
  line after the inherited ones, #617/#618/#619).
- **Disclosures** take section 7's verbatim new values;
  constant names kept as with the headings.

Locked line order, no-skills (None) arm: heading; CPU
`resource_line`; power grid `resource_line`; CPU
`base_output_line`; power grid `base_output_line`; CPU
excluded line if any; power grid excluded line if any;
CPU output-unapplied line if any; power grid
output-unapplied line if any; disclosure. Locked line
order, applied (Some) arm: heading; the two
`resource_line`s; the two `base_output_line`s; the two
output `skill_line`s (unchanged); the two
`base_need_line`s and five `need_reduction_line`s
(unchanged, in shipped order); excluded lines;
unreduced lines; output-unapplied lines; disclosure.
The over-budget red colour, the `0.0 left` shape, and
every shipped line's text are unchanged — only the
`output` each `resource_line` judges against moved,
which is the slice.

**No other surface changes.** Every other block keeps
its lines, counts, and numbers: in particular the Ship
(base values) block still shows hull values only (it
shows no CPU/power output lines today and gains none),
and the bonused EHP, capacitor, and shield-peak blocks'
shared excluded counts are untouched — a fitting can
legitimately disclose the same absent row in this block
(now including an absent rig) and in those blocks, each
against the number it shows, never summed across
blocks (#616 section 6 shape, inherited). No editor,
import, persistence, or other block changes.

## 7. UI wording (locked verbatim)

Changed and new strings in `src/ui/fittings.rs`, with
doc comments revised in the sibling style pointing at
this document. No string contains a raw EVE ID; every
module-bonus string says "output bonus" of a named
dimension, never a bare "bonus" a reader could take
for a need reduction.

- Base-arm heading (`FITTINGS_RESOURCES_HEADING`, new
  value): `Fitting resources (with fitted module bonuses)`
  — the shipped "(base values)" qualifier becomes false
  the moment outputs bonus, and the sibling qualifier
  "(with fitted module bonuses)" (#615/#618/#619) names
  exactly what changed. Needs on this arm stay base
  values; the disclosure says so (below), as the
  applied heading has never enumerated the need side
  either.
- Applied-arm heading
  (`FITTINGS_RESOURCES_APPLIED_HEADING`, new value):
  `Fitting resources (with skill and fitted module bonuses)`
  — both applied sets named; "bonuses" covers the need
  reductions as the shipped "(with skill bonuses)"
  already did.
- Base-arm disclosure (`FITTING_RESOURCES_DISCLOSURE`,
  new value, verbatim):

> Ship outputs include the fitted modules' and rigs' output bonuses from Mimir's bundled item data, and module needs are base values. Every fitted module is counted as active, because the fitting data does not say which modules are on. Skills, implants, and bonuses or reductions from subsystems and the ship itself are not applied, so these numbers can differ from EVE.

- Applied disclosure
  (`FITTING_RESOURCES_APPLIED_DISCLOSURE`, new value,
  verbatim):

> Ship outputs and module needs include only the skill bonuses and reductions above and the fitted modules' and rigs' output bonuses, from Mimir's bundled item data and this character's trained skill levels. Every fitted module is counted as active, because the fitting data does not say which modules are on. Implants, and bonuses and reductions from subsystems and the ship itself are not applied, so these numbers can differ from EVE.

  Wording notes (do not rephrase in review), applying
  to both: "the fitted modules' and rigs'" is the
  siblings' locked possessor for the counted
  population (subsystem-slot rows are counted, but no
  subsystem carrier gains emission — hence
  "subsystems" stays in the not-applied list, as every
  sibling discloses it); "counted as active" enters
  this block from #615's locked plain form because
  output bonuses are the first module-derived numbers
  this block shows (needs never depended on module
  state; outputs now do); "output bonuses" is always
  the full compound, never "bonuses from modules"
  alone, because this block also shows need reductions
  and the two must not blur; neither disclosure
  enumerates ship traits separately from "the ship
  itself", as shipped.
- Before-module-bonuses lines (`base_output_line`,
  section 6), templates verbatim:
  `CPU output before fitted module bonuses: {amount} tf.`
  and
  `Power grid output before fitted module bonuses: {amount} MW.`
  — `base_need_line`'s "before" template on the output
  side; on the applied arm the figure includes the
  skill factor (section 4), which the adjacent
  `skill_line`s already narrate ("CPU output includes
  CPU Management level 5 (+25%)"), so the line names
  only the boundary it marks. Display rounding is the
  shared formatter's tenth, unchanged, including at
  exact equality with the `resource_line` figure.
- Output-unapplied lines (section 6 helpers):
  - `cpu_output_unapplied_line(1)`:
    `1 fitted module has a CPU output bonus Mimir's bundled item data cannot describe, so that bonus is not applied.`
    Plural: `{n} fitted modules have CPU output bonuses Mimir's bundled item data cannot describe, so those bonuses are not applied.`
  - `power_grid_output_unapplied_line(1)`:
    `1 fitted module has a power grid output bonus Mimir's bundled item data cannot describe, so that bonus is not applied.`
    Plural: `{n} fitted modules have power grid output bonuses Mimir's bundled item data cannot describe, so those bonuses are not applied.`
  - Zero in any count renders no line for that count.
    (The singular/plural templates are the siblings'
    unapplied templates verbatim with the dimension's
    noun substituted, as #618/#619 derived theirs.)
- Unchanged verbatim, deliberately (each is a
  non-change review must not "fix"): both unavailable
  sentences (lines 1872–1874 — the bonused-`None` route
  of section 4 renders under the no-ship-output
  sentence; it is fixture/hostile-only on shipped data
  and inventing a third sentence for it would outrun
  every sibling's two-sentence shape); `resource_line`
  templates; both `skill_line` shapes; both
  `base_need_line` shapes; all five
  `need_reduction_line` shapes; both excluded lines
  (their "no CPU data" / "no power grid data" wording
  already covers the section-4 widening); both
  unreduced lines.

**Existing sentences and docs: the full inventory of
what this slice falsifies (locked).** Because existing
block totals change, every heading, disclosure, doc
comment, and design statement that locked base outputs
is inventoried here; anything not listed stays
byte-identical and true of its own block.

Rendered strings revised (values above, tests in
section 8):

- `FITTINGS_RESOURCES_HEADING` (line 1855) and
  `FITTINGS_RESOURCES_APPLIED_HEADING` (line 1861):
  "(base values)" / "(with skill bonuses)" become
  incomplete — revised.
- `FITTING_RESOURCES_DISCLOSURE` (line 1865):
  "bonuses from modules, rigs, subsystems … are not
  applied" becomes false for modules and rigs —
  revised.
- `FITTING_RESOURCES_APPLIED_DISCLOSURE` (line 1870):
  "include only the skill bonuses and reductions
  above" and "bonuses and reductions from modules,
  rigs … are not applied" both become false — revised.

Doc comments revised (no rendered string, no
behaviour):

- The four constants' doc comments (fittings.rs lines
  1854–1870) are rewritten to this document's locks in
  the same edit that changes the values.
- `render_fitting_resources`' doc (lines 2181–2190):
  "`None` renders the base block byte-identically to
  before" is superseded in section 2's narrow form —
  revised to state that module output bonuses render
  on both arms and the None arm remains the base needs
  arm.
- `src/fitting/resources.rs` module header (lines
  1–25): "bonuses or reductions from modules, rigs,
  subsystems … are not applied" becomes false for
  module/rig *output* bonuses — revised to name the
  applied output set (this document) and to keep the
  exclusions that stand (module need modifiers beyond
  the shipped skill reductions, subsystems, implants,
  ship bonuses). "The base function never scales
  anything" is revised to the precise statement:
  `fitting_resources` applies no *skill* scaling and
  remains identical to `fitting_resources_with_skills`
  at `None`.
- `fitting_resources_with_skills`' doc (lines 404–412)
  and `fitting_resources`' one-liner: "`output` scales
  by `1 + 0.05 * clamped_level`" is no longer the whole
  output rule — revised to the section-4 composition,
  keeping "`None` is exactly `fitting_resources`".
- `ResourceBudget`'s struct doc gains the two fields'
  docs (section 4); `base_used`'s doc ("Equals `used`
  when no levels are applied") is unchanged and stays
  true.
- `src/fitting/ship_resistances.rs` module header
  gains the `bonused_outputs` paragraph (section 4);
  its shipped paragraphs, including
  `bonused_capacitor`'s "…only", do not change.
- The generator header gains its output paragraph by
  addition (section 3).
- README resource wording and status/roadmap bullets
  that describe this block are updated in the
  documentation commit for this slice in the siblings'
  pattern (the `docs(fitting): document …` commit that
  closes each bonuses slice): any bullet stating
  outputs are base/hull×skill-only or that module
  bonuses are not applied to resources is revised to
  name fitted-module output bonuses as applied and the
  section-9 exclusions as not. Builders grep README
  for "output" beside "resources" and for this block's
  headings when writing that commit; this design does
  not quote README text it has not pinned.

Design-document statements superseded by reference
(section 2), not edited: fitting-resources section 4's
base-only depth and section 7's heading/disclosure
values; fitting-skill-resources sections 5–6 (the two
headings/disclosures and the byte-identical-None lock
in section 2's narrow form); fitting-need-reductions
section 8's applied disclosure value. Their remaining
locks (attribute set, level source, lookup, need
arithmetic, unavailable sentences, count meanings)
stand.

What a carrier fitting now shows, end to end (the
reviewer's picture; section 8 pins the strings): a
Rifter with a Reactor Control Unit II in a low slot,
no levels supplied, renders heading "Fitting resources
(with fitted module bonuses)", `Power grid: 0.0 MW of
47.1 MW used (47.1 MW left)` (41.0 × 1.15 at the
formatter's tenth), `Power grid output before fitted module
bonuses: 41.0 MW.`, and the new disclosure — today's
41.0 figure kept on its own line, the bonused figure
in the comparison line where fits are judged.

## 8. Test plan (locked)

Tolerance tiers follow the shipped tests: hand-derived
floats use absolute tolerance `1e-9` (the
`assert_close` pattern in `resources.rs` tests, line
578) with the multiplication shown; identities this
design calls exact use `assert_eq` (whole-outcome
`assert_eq` where the enum shape allows it, as the
shipped `none_equals_base…` pins do); helper values
exact in `f64` (47.15-class products are *not* — they
use `1e-9`; 143.0, 53.0, 117.0, 76.1875, 178.75 are
asserted by `1e-9` against the decimal shown or by
`assert_eq` against the shown product expression).
Fixture catalogues use the existing `from_json`
pattern; fixture modifier entries are written in the
shipped triple shape under the section 3 key names
(`cpuOutputModifiers` / `powerOutputModifiers` and
their unapplied markers). No test reads a raw EVE ID
into a rendered-string assertion beyond the fixture
inputs the sibling tests already use.

Base inputs for every oracle (pinned since the
resources slice; re-read from the cache at design
time): Rifter 587 CPU output (587, 48) = 130.0, power
output (587, 11) = 41.0; Punisher 597 = 140.0 / 67.0.
Module needs re-read the same way: 1355 Reactor
Control Unit II 22.0 CPU / 0.0 MW, 4254 Micro Auxiliary
Power Core II 18.0 / 0.0, 3888 Co-Processor II 0.0 /
1.0, 1541 Power Diagnostic System II 22.0 / 0.0, 1445
Capacitor Power Relay I 4.0 / 0.0. Operands:
`[[11, 4, 1.15]]` (1355), `[[11, 2, 12.0]]` (4254),
`[[48, 4, 1.1]]` (3888), `[[11, 4, 1.06]]` (1541),
`[[48, 6, 9.6]]` (4399), `[[11, 6, 15.0]]` (26370),
`[[48, 6, -10.0]]` (25908); (1445, 145) and (506, 145)
have no cache row (absent, verified). Items are fitted
in counted slots of the matching family (output
modules low, rigs rig-slot) at quantity 1 unless
stated. Each oracle pins, per dimension: `used`,
`output`, `base_output`, `remaining()`/`is_over()` where
they move, and all three deficit counts (excluded,
unreduced, output-unapplied) — zero where not stated —
on the None arm unless the oracle says otherwise, plus
the helper's `values` where section 4's composition is
the thing under test.

**Oracle 1 — RCU multiplier (the "percent" module in
player terms; operator 4 in the data).** Rifter + 1355
(`[[11, 4, 1.15]]`). Power output 41.0 × 1.15 =
**47.15**, `base_output` 41.0; CPU output 130.0 ==
`base_output`. Used 22.0 CPU / 0.0 MW; remaining 108.0
/ 47.15. Counts all zero. Two 1355 (two slots, then
one stacked quantity-2 row): 41.0 × 1.15 × 1.15 =
**54.2225** both ways — a penalised or counted-once
second unit lands elsewhere; the literal pins full
multiplication per unit (section 2).

**Oracle 2 — MAPC flat add (operator 2).** Rifter +
4254 (`[[11, 2, 12.0]]`). Power output 41.0 + 12.0 =
**53.0**; used 18.0 CPU. Quantity 2: 41.0 + 2 × 12.0 =
**65.0** (adds scale by count through the run, never
loop-multiply).

**Oracle 3 — Co-Processor (CPU dimension moves alone).**
Rifter + 3888 (`[[48, 4, 1.1]]`). CPU output 130.0 ×
1.1 = **143.0**, power output 41.0 == its
`base_output` under `==`; used 0.0 CPU / 1.0 MW;
remaining 143.0 / 40.0. The disjointness of section 2
in one fit: a CPU carrier never touches the power
value or the power output-unapplied count.

**Oracle 4 — PDS dual (the five-family row, and two
multipliers stacking).** (a) Rifter + 1541
(`[[11, 4, 1.06]]` new; shipped
`[[263, 4, 1.05]]`, `[[482, 4, 1.05]]`,
`[[55, 4, 0.915]]`, `[[479, 4, 0.915]]` not read here —
the sibling tests keep pinning them in their blocks).
Power output 41.0 × 1.06 = **43.46**; CPU output
130.0 == `base_output`; used 22.0 CPU. "Dual" is the
pin: one row, its power dimension bonused by the new
family while its CPU dimension — for which it carries
no triple at all (section 2's empty intersection) —
stays bit-exact, and neither output-unapplied count
moves. (b) 1541 + 1355 together: power 41.0 × 1.15 ×
1.06 = **49.979** (mul runs in first-seen order; the
reverse fit order agrees within `1e-9`), used 44.0 CPU
— two different multipliers from two modules, no
penalty, no dedupe by effect (both are effect 56).

**Oracle 5 — with-skills composition (adds before
skill percent; the headline hand values).** Fit: 1355
+ 3888 + 4254 on a Rifter. No levels (`None`, and
`Some` all-zero — asserted equal): used 40.0 CPU / 1.0
MW; CPU output 130.0 × 1.1 = **143.0** (103.0 left);
power output (41.0 + 12.0) × 1.15 = **60.95** (59.95
left); `base_output`s 130.0 / 41.0. With CPU Management
5 + Power Grid Management 5 (all need skills 0): CPU
130.0 × 1.1 × 1.25 = **178.75**; power (41.0 + 12.0) ×
1.15 × 1.25 = **76.1875** (renders 76.2 MW) —
the adds-first composition: the
skill-scales-base-then-adds mutant gives
(41.0 × 1.25 + 12.0) × 1.15 = 72.7375 (the
percent-chain association itself is pinned bit-exactly
by Oracle 9); `base_output`s
162.5 / 51.25 (today's outputs, bit-identical by
construction); used unchanged 40.0 / 1.0 with
`base_used` equal (no need skill matches at level 0 —
asserted, so the output composition is isolated from
the need machinery). Both helper values pinned through
`bonused_outputs` directly, `None` and `Some((5, 5))`
and `Some((0, 0))`.

**Oracle 6 — rig percents, no used change (counted vs
consuming).** (a) Rifter + 4399 in RigSlot0
(`[[48, 6, 9.6]]`): CPU output 130.0 × (1 + 9.6/100) =
**142.48**; used 0.0 both dimensions, excluded 0 both
(the rig is present in the catalogue: counted for
output, invisible to needs — the section-2 population
split in one row). Its shipped shield entry is not
read (the #619 tests keep pinning it). (b) Rifter +
26370 in RigSlot0 (`[[11, 6, 15.0]]`): power 41.0 ×
1.15 = **47.15** — the operator-6 route reaching
Oracle 1's operator-4 number by a different path.
(c) 26370 + 25956 (`[[11, 6, 10.0]]`) in two rig slots:
41.0 × 1.15 × 1.10 = **51.865**, percent runs sorted
15.0 before 10.0. (d) The same 4399 under `Cargo`:
outputs exactly base under `==`, counts all zero
(non-counted flags never contribute).

**Oracle 7 — drawback shrinks the output, and can flip
the judgment.** Rifter + 25908 in RigSlot0
(`[[48, 6, -10.0]]`): CPU output 130.0 × 0.9 = **117.0**
< `base_output` 130.0, applied as written; with
5 × 2048 fitted besides (used 150.0 CPU) `is_over()` is
true against 117.0, and at CPU Management 5 the output
is 117.0 × 1.25 = 146.25, *still* over — where the
same fit without the rig judges under at 162.5 (the
shipped over-flip pin). The negative direction reaches
the verdict, never floored at base.

**Oracle 8 — the absent-split pin (per-dimension
output-unapplied, exact identity under a marked
carrier).** Rifter + 1445 in a low slot. Its 145
operand is absent (section 3: power-empty, marked), so
power `output == base_output == 41.0` under `==` with
`power.output_unapplied_modules == 1`, CPU counts all
zero and CPU output `==` base; used 4.0 CPU / 0.0 MW;
excluded 0 on both arms (the count is unapplied, never
excluded — the row is present). Quantity 2 counts 2.
Asserted on the None arm *and* at `Some((5, 5))` levels
(power output then 51.25 == its `base_output`,
output-unapplied still 1): the count is not
level-gated. This is the row the separate dimension
exists for, on real shipped data.

**Oracle 9 — skill percent inside the sorted chain
(bit-exact association pins).** These three assert by
`assert_eq` against the locked association written out
in the test — `(base + 0.0) * 1.0 * ((1.0 *
mul_product_factor_1) * mul_product_factor_2)` in
sorted order — because at `1e-9` tolerance a
reassociated implementation (skill factor applied to
the helper's result, or factors folded in fit order)
can land within tolerance or even on the same bits by
accident on a given example; the written association
cannot. Design-verified: the locked power value below
differs by one ulp from the naïve reassociation
`41.0 * 1.25 * 1.15`, so the `assert_eq` form is load-
bearing, exactly as in the identity pins. (a) Rifter +
26370 (15.0) at Power Grid Management 5: percent runs
[25.0 (skill), 15.0] after the sort; power
`== (41.0 + 0.0) * 1.0 * ((1.0 * 1.25) * 1.15)`
(58.9375 at hand precision). (b) Rifter + 4399 (9.6)
at CPU Management 5: runs [25.0, 9.6]; CPU
`== (130.0 + 0.0) * 1.0 * ((1.0 * 1.25) * (1.0 + 9.6 /
100.0))` (178.1 at hand precision). (c) Drawback + skill at equal
magnitude ordering: 25908 (−10.0) at CPU Management 2
(skill value 10.0 — equal absolute values, stable
module-then-skill order): CPU 130.0 × 0.9 × 1.1 =
**128.7**; the pin asserts the value, and the design
note (section 2) records why run order cannot move it.

**Oracle 10 — over-flip against bonused output.**
5 × 2048 (150.0 CPU, the shipped over-budget fit) +
3888: CPU output 143.0, still over by 7.0
(`remaining() == -7.0` within `1e-9`); the same fit at
CPU Management 5 (178.75 with the co-processor… see
Oracle 5's factor) is not over. The verdict always
judges against `output`, never `base_output` — a
mutant judging against the before-figure flips Oracle
10's first half.

**Helper and pure-function pins:**

1. Oracles 1–10 above: budgets through
   `fitting_resources` /
   `fitting_resources_with_skills` on the bundled
   catalogue (in `resources.rs` tests), values and
   output-unapplied counts through `bonused_outputs`
   (in `ship_resistances.rs` tests beside the sibling
   helper pins), all counts each time.
2. **Empty == current, exactly, on both arms (the
   identity gate).** Whole-outcome `assert_eq` of
   `fitting_resources` and of
   `fitting_resources_with_skills(…, Some(levels))`
   against **literally constructed expected outcomes
   carrying today's numbers** (used, output,
   base_output == output, excluded, base_used,
   unreduced, output-unapplied == 0) for: hull-only
   Rifter and Punisher at levels None / 0 / the full
   0–5 table (130.0/41.0, 136.5/43.05, 143.0/45.1,
   149.5/47.15, 156.0/49.2, 162.5/51.25 — asserted by
   `assert_eq` against `base * (1.0 + 0.05 * level as
   f64)` evaluated in the test, so the bit-identity of
   section 2 is the thing under test, not the decimal
   literals, which the shipped `assert_close` table
   keeps pinning unmodified); only non-counted and
   non-consuming items (cargo/charge/drone flags,
   quantity 0, `type_id <= 0`); counted non-carriers
   (2048 in a low slot and in a rig slot — a resistance
   carrier that is an output non-carrier in this
   block's counted population too); the EFT sample-fit
   oracle (its Small Projectile Burst Aerator I rig
   31668 is design-verified **not** a 48/11 carrier,
   and its counted modules carry no output triple —
   used 114.0/31.0, outputs 130.0/41.0, remaining
   16.0/10.0 stand, with counts 0); and the three demo
   fittings (item-by-item design-checked against the
   census: Brawler 2048/2049/1225/2050/2050 counted
   plus rig 1535 and subsystem 28270, Mission Runner
   2048/2049, Demo Runner 2048/2050/1225 — none is a
   carrier in either family) reproducing their shipped
   outputs (130.0/41.0, 130.0/41.0, 140.0/67.0), on the
   None arm and at the demo characters' levels, subject
   to exactly the one count change in pin 4 below.
   The shipped `none_equals_base_on_real_and_no_output_fits`
   and the synthetic-Flutter oracle (125.0/37.0 →
   156.25/46.25) pass unmodified in spirit and
   assertion (their fixtures fit no carrier; the
   synthetic catalogue loads the new fields as
   `None`/`false`).
3. **`base_output` is today's output, always.** On
   every oracle and identity fit: `base_output` equals
   the shipped formula's value by `assert_eq` against
   `hull` (None) resp. `hull * (1.0 + 0.05 * clamped as
   f64)` (Some, including hand-built levels ±99
   re-clamped — the shipped pin's semantics for the new
   field), while `output` carries the bonuses; and
   `output == base_output` exactly on every no-carrier
   fit. Helper-side mirror: `bonused_outputs` at
   `Some((99, -1))` equals `Some((5, 0))` (the internal
   re-clamp), asserted on an Oracle 5 fit.
4. **Excluded widening (the one moved shipped
   number).** Unknown type 999999 at RigSlot0 and at
   SubSystemSlot0: both dimensions' `excluded_modules`
   +1 per unit (quantity 5 → 5), used/outputs
   untouched, output-unapplied 0; the same unknown at
   DroneBay/Cargo still 0 (the shipped pin stands);
   a present non-carrier rig (31668) still 0. Demo
   consequence, asserted in the demo-story tests:
   Demo Brawler's catalogue-absent rig 1535 moves its
   resources excluded counts from 2 to **3** on both
   dimensions (both arms); Mission Runner and Demo
   Runner (no absent counted rows) keep 1/1 and 1/1;
   no other demo number moves. This is the sole
   permitted edit to shipped count assertions (with
   the wording/value edits of pin 9).
5. **Partiality and zero rules.** Fixture hull with
   `powerOutput` absent, `cpuOutput` present, fixture
   MAPC-equivalent fitted → helper `values ==
   [Some(130.0), None]` (no resurrection), public
   result `ShipNoOutput` on both arms. Mirror with
   `cpuOutput` absent. Present-`0.0` outputs (the
   shipped Zephyr-shaped fixture): hull-only 0.0/0.0
   not over, +2048 over by 30.0/1.0 (shipped pins
   stand), and a fixture `[[11, 2, 12.0]]` module
   raises power output to **12.0** while CPU stays 0.0
   (application to a present zero ≠ resurrection of
   absence — both pinned); a fixture `[[11, 6, -100.0]]`
   on a 41.0 hull gives helper `Some(0.0)` — a real
   zero — and an `Available` budget judging over
   against 0.0 when anything consumes power.
6. **Hostile bounded (subnormal, zero, negative,
   overflow — every outcome asserted, never
   discarded).** On a fixture hull (130.0/41.0) with
   fixture entries in the shipped key shapes, plus
   real-carrier hostile quantities on the bundled
   catalogue. `let _ = …` is forbidden as a test
   outcome (the `2ac348f` precedent); each asserts the
   helper values **and** the public outcome:
   - quantity `i64::MAX` of a −20.0 percent fixture on
     11 (`powerOutputModifiers: [[11, 6, -20.0]]`, rig
     slot) → percent run stalls at a positive
     subnormal → helper `values[1] == None` asserted,
     `values[0]` asserted `Some(130.0)`, public result
     `ShipNoOutput` **asserted** on both arms, returns
     promptly;
   - quantity `i64::MAX` of the real 25908 (−10.0,
     rig slot) on the bundled catalogue → the 0.9 run
     stalls at a positive subnormal under the shipped
     `mul_product` stall rule (design-verified against
     that exact loop: the run product settles at
     `0x0.0000000000005p-1022`, and × 130.0 stays
     subnormal) → helper `values[0] == None` asserted,
     `values[1]` asserted `Some(41.0)`, public result
     `ShipNoOutput` asserted, promptly — a real carrier
     on shipped data reaching the subnormal route, not
     only a fixture;
   - quantity `i64::MAX` of real 1355 (1.15, low slot)
     → mul run overflows non-finite → helper
     `values[1] == None`, public `ShipNoOutput`,
     promptly (its used side stays the shipped
     finite-huge behaviour — the result is
     `ShipNoOutput`, so no budget exists to assert it
     on; the shipped non-carrier huge pin
     `huge_quantity_stays_finite_and_reports_over`
     passes unmodified and keeps covering used);
   - quantity `i64::MAX` of real 4254 (flat add) →
     helper power value is the locked formula's finite
     `(41.0 + 12.0 × (i64::MAX as f64))` asserted by
     `assert_eq` against that expression (adds never
     loop), public `Available`, `used` finite, `is_over`
     asserted from the shown numbers;
   - fixture percent −150 and fixture mul −1.15 on
     either dimension → negative result → helper
     `None` in that dimension, public `ShipNoOutput`;
   - fixture add `[[11, 2, -50.0]]` on the 41.0 hull →
     (41.0 − 50.0) negative → helper `None`, public
     `ShipNoOutput` (negative adds are arithmetic the
     formula defines and the guard rejects, never a
     negative output).
7. **Runtime guard counts.** Fixture rows beyond the
   generator's guarantees: marked-unapplied *with* an
   applicable `[[11, 4, 1.15]]` entry (counted once in
   power output-unapplied, entry still applied — the
   output proves it); entries with operators 0, 3, 5,
   and 7, a wrong modified id (a 482 or 479 triple
   inside `powerOutputModifiers`; an 11 triple inside
   `cpuOutputModifiers`), a zero operand, and a
   non-finite operand → each counts its item once **in
   that family's dimension only** (never twice for two
   bad entries on one item, never in the other
   dimension), applicable entries still applied, a
   guarded entry never contributes its operand, and
   none of it touches excluded or unreduced. An
   operator-2 fixture entry on 48 (`[[48, 2, 25.0]]` —
   the grounded-but-uncensused CPU add) applies as a
   flat add (130.0 + 25.0 = 155.0), composed with CPU
   Management 5 as (130.0 + 25.0) × 1.25 = 193.75 — if
   data ever carries it, it behaves as section 2
   locks.
8. **Need-side and sibling independence.** Fitting any
   oracle carrier leaves `used`/`base_used`/unreduced
   at their shipped oracles on the same fit (in
   particular the shipped need-table tests that fit
   1355 for its required-skill filter — Energy Grid
   Upgrades pin ca. resources.rs:1446 — keep their
   used numbers; their output assertions, where any,
   gain the bonused value only through new added
   assertions, never by editing a need literal); leaves
   `ship_base_stats`, base and bonused resistances,
   base and bonused EHP, both capacitor outcomes, the
   bonused shield peak, calibration, bay usage, DPS,
   slot layout, and navigation figures at their
   shipped oracles (a power-only carrier such as 4254,
   which is a non-carrier in every sibling family,
   moves no sibling figure or count; 1541 moves its
   sibling figures exactly as today and its power
   output here — the families never bleed, asserted
   per block as in #619). The cross-module independence
   pins that call `fitting_resources` against partial
   fixtures (`bay_usage`, `calibration`,
   `ship_nav_targeting`, `ship_resistances`, `ship_ehp`,
   `ship_stats`, `slot_layout` test modules) pass
   unmodified: their fixtures' ships fail or pass the
   unchanged base gate, fit no counted output carrier,
   and use `Available { .. }` / `ShipNoOutput` matching
   — the one fixture class that would need care (a
   partial-catalogue fixture fitting a counted carrier
   with an operand the formula rejects) does not exist
   among them; builders who find one stop against
   section 5 rather than editing the sibling pin.
9. **Permitted edits to pre-existing tests (the
   complete list; anything else failing stops against
   this document):** (a) mechanical `ResourceBudget`
   literal extension for the two new fields — the UI
   test helper `budget()` (fittings.rs:5706, in its
   established "mechanical extension" comment style:
   `base_output: output`, `output_unapplied_modules: 0`)
   and the two literals at fittings.rs:5940/5951
   likewise; (b) the four constant *values* asserted in
   `fitting_resource_unavailable_and_disclosure_wording`
   (heading + disclosure replaced by section 7's; the
   two unavailable sentences in the same test stay
   byte-identical) and in `fitting_resource_applied_wording`
   (applied heading + disclosure replaced; skill-line,
   base-need-line, and need-reduction-line assertions
   in the same test unmodified); (c) Demo Brawler's
   excluded counts 2 → 3 in both demo-story tests
   (`demo_fixture_resources_match_the_locked_demo_story`,
   `demo_fixture_applied_resources_match_the_locked_demo_story`),
   with their comments updated to name the absent rig —
   every other demo assertion unmodified, and new
   `base_output`/output-unapplied assertions *added*;
   (d) resources tests that fit a real carrier (1355
   at lines 711 and ca. 1449) gain added output
   assertions only where section 8's oracles require
   them — no shipped used/excluded literal there
   changes (1355's `explicit_zero_power_counts_as_real_zero`
   assertions stand: it asserts used 22.0/0.0 and
   excluded 0/0, all still true; the new output it also
   yields is pinned in Oracle 1's own test); (e) the
   doc-comment revisions of section 7, which no test
   asserts on.

**Regression gates (unmodified).** Every other existing
test in `resources.rs` (skill tables, lookup, clamp,
need-reduction tables and guards, huge-quantity,
zero-output ships, over-budget), `ship_resistances.rs`
(including the `2ac348f` subnormal pins and every helper
literal), `ship_ehp.rs`, `ship_cap_stability.rs`,
`ship_peak_recharge.rs`, the catalogue tests, and the
UI line/wording tests for every other block passes
**unmodified** — the identity association of section 2
is exactly the claim that makes this possible, and
these tests are its proof. If a no-carrier output moves
by one ulp, the association is wrong against this
document; fixing it by relaxing an assertion to a
tolerance is forbidden.

**Catalogue pins.** The section 3 loader invariants
(per family 91/91/0/91 and 85/59/26/59, modified ids,
operators, spot pins) join
`bundled_catalogue_invariants` over the real bundled
asset, plus a `from_json` pin that a row without the
new keys loads `None`/`false` in both families and a
row with them parses. The generator commit reports in
its body: twice-run identical sha256,
strip-the-four-new-keys byte-identity against
`aa5b4161…`, and the exact new byte count against the
+10,000 budget. Proofs are run once and reported, not
committed as scripts.

**UI pins (`src/ui/fittings.rs` tests):**

1. The two existing wording tests updated per pin 9(b)
   above pin section 7's four new values verbatim and
   keep the unavailable sentences; a new pin asserts
   `base_output_line` at the templates shown
   (`CPU output before fitted module bonuses: 130.0 tf.`,
   `Power grid output before fitted module bonuses:
   41.0 MW.`, and a bonused-budget pair at 162.5/51.25
   on the applied arm) through the extended `budget()`
   helper.
2. New count-helper pins: both output-unapplied helpers
   at 0 (`None`), 1 (singular), and 2 (plural) with
   section 7's exact strings.
3. Catalogue lines by construction: Rifter + 1355
   through the pure function renders `resource_line`
   `Power grid: 0.0 MW of 47.1 MW used (47.1 MW left)`
   (47.15 at the formatter's tenth) and
   `base_output_line` `Power grid output before fitted
   module bonuses: 41.0 MW.`; Rifter + 3888 renders
   `CPU: 0.0 tf of 143.0 tf used (143.0 tf left)`; the
   Oracle 5 fit at L5/L5 renders the power line's
   `76.2 MW` (76.1875); Rifter + 1445 renders the
   power output-unapplied singular line and no CPU
   one, with both `resource_line`s at base figures.
4. Demo-story tests per pin 9(c): outputs and
   `base_output`s equal on all three demo fittings
   (the visible form of the no-carrier identity),
   output-unapplied 0, Brawler excluded 3/3 with the
   excluded lines rendering `{3}` in both dimensions.

**Gates (all must pass for every implementation
commit):** `cargo fmt --check`, `cargo clippy
--all-targets -- -D warnings`, `cargo test`, `cargo
build`. Commits are small and atomic, `type(scope):
description`, with no attribution lines. Locked commit
sequence after this design commit (`docs(fitting):
design fitted-module output bonuses`): (1)
`feat(catalogue): emit fitted-module output modifiers`
(generator + regenerated asset, proof obligations in
the body); (2) `feat(fitting): load output modifiers
from the catalogue` (loader fields + invariants); (3)
`feat(fitting): apply fitted-module output bonuses to
fitting resources` (helper, resources integration,
budget fields, pure tests, the section-7 fitting-module
header revisions, and only the mechanical UI literal
extensions of pin 9(a) — heading and disclosure values
do not change in this commit, so the block is briefly
honest-by-numbers under its old words only inside the
branch); (4) `feat(fitting): show fitting resources
with fitted-module output bonuses` (headings,
disclosures, `base_output_line`, output-unapplied
lines and helpers, renderer line order, UI tests
including pin 9(b)/(c)); then the usual closing
`docs(fitting): document fitted-module output bonuses`
(README + decision record, section 10). Each commit
passes all four gates alone.

## 9. Exclusions (locked)

Out of this slice, by name: **module need modifiers
beyond the shipped skill reductions** — no fitted
module, rig, subsystem, or ship effect that modifies a
module's CPU need (50) or power grid need (30) is
emitted, read, or applied (the Powergrid Subroutine
Maximizer class of rig need effects and every
module-side need chain stay exactly where the
need-reductions design left them; this slice reads no
module-side attribute at all, and an output carrier's
*own* needs are still reduced only by the five shipped
skills); implants and boosters of every kind (category
20 — Zainou/Squire output implants, Genolution CA-1/
CA-2, Aurora Omega 24345, the outlet chip, and every
drug booster); ship (hull role/trait) bonuses to CPU
or power grid output — no category-6 carrier gains
emission, and hull output traits remain unapplied
exactly as the disclosures say; **subsystem output
bonuses** (category 32 — the strategic-cruiser cores
45623/45626/45629/45632 at 313 = 20.0 and
45625/45628 at 424 = 25.0 via effects 397/490, and any
other category-32 carrier): locked out like every
sibling's category-32 carriers, even though subsystem
slots are counted slots for the module families, and
disclosed by the word "subsystems" in both
disclosures; the unpublished category-17 subsystem
effects (3782/3783 passive output adds, 3886/3887/
4260–4263 subsystem output chains) and all
unpublished-row carriers of any category; structure
and NPC carriers (category 66 via 56/536 and any
`structureID` shape); skills by any second path — the
two output skills compose only through the shipped
`ResourceSkillLevels` table (no `cpuOutput…` /
`powerOutput…` emission on skill rows 3426/3413, no
runtime read of `dogma.json` or `effect_modifiers.json`,
mirroring the need-reductions lock), and no other skill
joins the percent chain; output changes from anything
outside this ship (fleet, environment, other ships);
module active/inactive or overheating state (every
fitted module counts as active, as #615 locked);
mutated (abyssal) per-item values — types whose real
bonuses the type rows do not carry ship
counted-not-applied by the same classification as the
siblings; any standalone "bonused outputs" readout,
block, or public API (the helper is `pub(crate)`; the
bonused outputs exist only as `ResourceBudget.output`
against its `base_output`); any change to used sums,
need reductions, slot layout or hardpoint budgets, rig
calibration, bay usage, resistances, EHP, capacitor,
shield peak, active repair, or DPS numbers or
emission; persistence, ESI, editor, and network
changes; new logging.

Operators outside {2, 4, 6} on 48/11 are not
deferred-silently: they are locked as unsupported →
unapplied-counted at generation and at runtime
(sections 2–4), which is this slice's complete answer
for them until a future design grounds one.

## 10. Decision record

When this slice merges, `DECISIONS.md` gains an entry
in the implementation PR (not this design commit):
"Fitted-module output bonuses: CPU and power grid
output in fitting resources" — recording the
supersession of the resources slices' base-outputs
boundary inside the *existing* block (the one bonused
quantity that changes a shipped comparison instead of
adding a block, with today's figure kept on its own
before-bonuses line per dimension), the census
(two per-attribute families in [48, 11] order after
the shield keys; operators {2, 4, 6}; 91 CPU carriers
all applicable including 64 rig drawbacks applied as
written; 85 power carriers with the relay family's
real 26-type marked-unapplied set; empty intersection,
per-attribute split locked anyway on the #618 reason),
the Flutter composition (adds, then multipliers, then
one percent chain holding the module percents and the
single skill percent per dimension — a flat power add
is scaled by skills and multipliers) with its exact
float association keeping no-carrier outputs
bit-identical on both arms, the no-stacking-penalty
verification for 48/11 (named as a possible difference
from the EVE client, kept under the disclosures'
"differ from EVE" sentence), the `2ac348f` subnormal
rule per dimension with bonused-`None` taking the
whole result unavailable (base `ShipNoOutput` rules
unchanged), the category-7-only gate with implants,
ship traits, subsystem outputs, and module need
modifiers deferred by name, and the three
per-dimension never-summed counts (excluded with its
one absent-counted widening, unreduced, new
output-unapplied). The entry is the implementation
PR's because it records what shipped; this document
records what was decided before building.
