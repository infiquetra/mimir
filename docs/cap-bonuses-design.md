# Fitted-module capacitor bonuses (bonused capacitor capacity, recharge, peak, and stability) — design

Status: locked for the `feat/rust-cap-bonuses` slice. Base:
`develop` at `29b356b` (PRs #561–#617 merged). Slice branch:
`feat/rust-cap-bonuses`. This document is the single design
commit; builders implement exactly what is locked here and
nothing else. It follows the resistance bonuses slice
(`docs/resistance-bonuses-design.md`, #615) and the hit
point bonuses slice (`docs/hp-bonuses-design.md`, #617) for
emission and computation shape, and the capacitor stability
slice (`docs/cap-stability-design.md`) and peak recharge
slice (`docs/peak-recharge-rates-design.md`) for the
quantities being bonused; where this document says "mirrors
#615" or "mirrors #617", that wording and structure are the
precedent and do not need relitigating. It supersedes the
capacitor stability slice's no-modifiers boundary for the
two ship capacitor attributes only (section 2). The earlier
design documents are not edited.

Every name, formula, count, and oracle number below traces
to an inspected body at `29b356b` —
`src/fitting/ship_cap_stability.rs`,
`src/fitting/ship_peak_recharge.rs`,
`src/fitting/ship_resistances.rs`,
`src/fitting/ship_stats.rs`, `src/fitting/ship_ehp.rs`,
`src/names/fitting_types.rs`, `src/ui/fittings.rs`,
`scripts/sde/generate_fitting_types_sde.py`, the four
design documents above, `assets/demo/fittings.json` — or
to a design-time script over the committed SDE data
(`dogmaEffects.jsonl` inside
`scripts/sde/eve-online-static-data-3503375-jsonl.zip`
joined through the committed `scripts/sde/*.csv.bz2`
caches; the census in section 2 was re-run at design time
and its counts are quoted from that run), or to the
inspected Flutter bodies at `ed698d3`
(`lib/features/fitting/domain/dogma_engine.dart`,
`cap_simulator.dart`, `dogma_attributes.dart`), or to hand
arithmetic over values those bodies pin (shown in section
8; simulator literals there were produced by an independent
line-by-line Python translation of the shipped Rust
simulator core, validated against two shipped literals —
the method the shipped simulator tests already use). No
convention here comes from EVE folklore or memory. Raw EVE
type IDs never appear in any rendered string in this slice;
type IDs below are internal oracle pins only, as in #615.

## 1. Goal and value ranking

Add **one** new block, "Capacitor (with fitted module
bonuses)", immediately after the existing "Capacitor (base
values)" block on both fitting detail surfaces. It shows
the same three quantities as the base block — module
capacitor use, capacitor peak recharge, and the
stable/depletes verdict — with the fitted modules' and
rigs' bonuses to the hull's **capacitor capacity** (dogma
482 `capacitorCapacity`) and **capacitor recharge duration**
(dogma 55, shipped in the catalogue as `rechargeRate`,
loaded as `capacitor_recharge_rate`, raw milliseconds)
applied to the capacitor side of the computation. Module
capacitor use stays at base values in both blocks: this
slice bonuses the ship's capacitor, never a module's need
or cycle (section 9). The base Capacitor block, the Ship
(base values) block (including its own capacitor peak
recharge line), and every other block keep their
arithmetic, availability logic, headings, lines, and
numbers byte-identical; `fitting_cap_stability`,
`ship_base_peak_recharge`, and `ship_base_stats` do not
change behaviour in any byte, and their existing tests are
the regression gate (section 8). This is the slice the
capacitor stability design section 9 excluded by name ("No
modifiers of any kind: capacity, recharge, module needs,
and cycles stay base"); module needs and cycles stay
excluded here too. No network, no ESI changes, no new
scopes, no persistence.

One combined bonused block, not two (one for peak, one for
stability): peak recharge and the stability verdict are
two readings of the same bonused (capacity, recharge)
pair against the same drains, exactly as the base block
already combines them, and the bonused EHP precedent
(#616/#617) is one block per bonused quantity family, not
one per derived line. Bonused capacitor capacity and
bonused recharge duration themselves are shown **nowhere**
as standalone lines in this slice: they exist only inside
the bonused peak and verdict, as bonused hit points exist
only inside EHP (#617 section 6). The Ship (base values)
block keeps showing base capacitor capacity and recharge,
so its disclosure stays true.

Value ranking (locked, in order), extending #617's:

1. **Never show a bonused capacitor number without its
   bonus policy named beside it.** The heading and
   disclosure must name fitted-module capacitor bonuses
   *and* state that module use stays base, or the verdict
   reads as a complete fitted simulation — skills, ship
   bonuses, implants, subsystems, boosters, and need/cycle
   modifiers are still not applied (section 7 wording). An
   arithmetically perfect "Stable" a reader mistakes for
   their ship's real cap life is still a failure.
2. **Correctness and exactness of the bonused pair.**
   Every bonused capacity and recharge value must be
   hand-derivable from quoted base values and emitted
   operands (section 8), computed at full `f64` precision
   with the locked `(base + adds) × mul × percent` order
   per attribute (section 2), and fed to the *existing*
   simulator and peak formula unchanged. Absence never
   renders as a number and never resurrects as zero:
   completeness is the base block's shape (section 5). In
   particular a bonused recharge duration driven to `0`,
   negative, or non-finite never renders and never
   simulates — the block goes `Unavailable` (sections 4–5);
   there is no "instant recharge" reading.
3. **No deficit is silently dropped, in any dimension.**
   The base block's drain-dimension excluded count carries
   over byte-identical in meaning; catalogue-absent rows
   get a bonus-dimension excluded count; and carriers
   whose capacity bonus cannot be applied and carriers
   whose recharge bonus cannot be applied get **separate**
   per-dimension unapplied counts and lines (sections 4
   and 7). No two of these counts are ever summed, and
   none is ever summed with the resistance or hit-point
   counts in the blocks above. A bonused verdict that
   quietly omits a power relay's ungroundable capacity
   penalty would cross-read as complete.
4. **Reuse.** The #615/#617 generator classification,
   catalogue tuple shape, loader shape, counted-item scan,
   bounded run arithmetic, and count-line shapes; the
   existing drain collection, `run_simulator`, peak-rate
   guard, and line helpers — all beat new machinery
   (sections 3, 4, 6). The simulator takes bonused inputs
   through its existing parameters; it is not forked.

Non-goals are locked in section 9. In particular: no ship
traits, skills, implants, or subsystem bonuses; no
capacitor boosters or injectors; no shield capacity/recharge
pairing (the shield peak line stays base everywhere it
appears); no modifiers to module capacitor need or cycle.

## 2. Modifier set, arithmetic, and supersession (locked)

**Supersession.** The capacitor stability design section 9
locked "No modifiers of any kind" as that slice's boundary
and the peak recharge design computed peaks from base
values only. This slice supersedes those as slice
boundaries for the two ship capacitor attributes, replaced
by the sections named: capacity and recharge modifiers
(→ sections 2–4 here); the bonused peak (→ section 4);
the bonused verdict (→ section 4). What is **not**
superseded: the no-boosters lock and its ship-nothing
reasoning (capacitor stability design section 9, first
bullet — boosters still ship nothing, section 9 here);
base needs and cycles (still base, both blocks); the
simulator core, its event quantization, horizon, and
water-mark percent; the peak factor derivation; #615's
and #617's semantics, counted-flag set, and bounded
arithmetic. A builder who believes this design requires
changing any of those stops and records it against this
document.

**Grounded modifier shape (locked — ships, the whole
set).** A fitted item contributes a capacitor modifier
only when all of these hold, mirroring #617 section 2 with
the capacitor attribute set substituted:

- its catalogue row is category 7 (module, including rigs
  — category-7 rows with slot effect 2663; capacitor rigs
  are therefore in scope as fitted items);
- one of its effects (joined through
  `dgmTypeEffects.csv.bz2`) carries a modifier with
  `func == ItemModifier` and `domain == shipID`;
- that modifier's modified attribute is **482
  `capacitorCapacity`** or **55 `rechargeRate`** (Flutter
  `capacitorRechargeTime`; the catalogue's `rechargeRate`
  key, loaded as `capacitor_recharge_rate` —
  `src/names/fitting_types.rs:51-62`), in that locked
  order wherever an order is needed;
- its operator is `2`, `4`, or `6` (below);
- the operand — the item type's own `dgmTypeAttributes`
  value for the modifier's modifying attribute — is
  present, finite, and not `0.0`.

**Recharge duration semantics (locked, verified — this is
the slice's sign trap).** Attribute 55 is a **duration in
milliseconds**: the time to recharge from empty to full.
Lower is faster. The shipped code already depends on this
reading in three places: `ship_base_stats` converts it to
`capacitor_recharge_secs` (ms / 1000,
`src/fitting/ship_stats.rs:84-85`); peak recharge is
`2.5 × C / T` with `T` that duration
(`src/fitting/ship_peak_recharge.rs:33-46`); and the
simulator sets `tau = rechargeMs / 5.0`
(`src/fitting/ship_cap_stability.rs:214`, Flutter
`cap_simulator.dart:116`). A modifier on 55 therefore
scales a duration: an operand below the identity (a
multiplier `< 1.0`, a percent `< 0`) makes the capacitor
recharge **faster**, and one above makes it slower. The
operand data confirms the reading: every Cap Recharger
carries multiplier attribute 144 below 1.0 (Cap Recharger
II 0.8) and every Capacitor Control Circuit carries
percent attribute 314 at −15.0/−20.0 — negative percents
whose only coherent effect under the locked formula
`1 + value/100` is a shorter duration. Locked consequences
builders must not "fix":

- Percent operands keep their sign. `−15.0` on 55 is the
  factor `0.85`; it is never absolutized, never negated,
  and never read as "+15% recharge rate" converted by
  inversion (`1 / 1.15` is a different number and appears
  in no inspected body).
- Multiplier operands multiply the duration directly.
  Attribute 144's SDE name is
  `capacitorRechargeRateMultiplier` with unit 111
  "Inversed Modifier Percent", but the inspected Flutter
  ship route treats operator 4 on attribute 55 as a plain
  multiply of the attribute's millisecond value
  (`routeOwnerModifiers` collects it into `mulModifiers`;
  the final loop multiplies). No operand is inverted
  anywhere in this slice, whatever its unit is called.
- On 482 the direction is the ordinary one: adds add
  gigajoules, multipliers above 1.0 and percents above 0
  grow the capacitor. The two attributes use the *same*
  formula; only the physical reading of the result
  differs, and that reading is already fixed by the peak
  and simulator code the results feed.

**Supported operations (locked, with evidence).**
Design-scripted over the committed data, category-7
`ItemModifier`/`shipID` modifiers on {482, 55} use exactly
three operator codes, each grounded in the inspected
Flutter ship path (`routeOwnerModifiers` routes
`ItemModifier`/`shipID` by operator into add/mul/percent
accumulators; the final ship loop composes them;
`dogma_engine.dart:25-34, 550-575, 812-823` at `ed698d3`):

- **Operator 2, modAdd — flat add.** Flutter `_modAdd = 2`.
  Census: (482 ← 67 `capacitorBonus`) on 30 types (capacitor
  batteries; Large Capacitor Battery II operand 1625.0 GJ),
  27 with a present operand, operands in [60.0, 19600.0].
  No operator-2 entry targets 55 on a category-7 carrier
  (the ship-path operator-2 effect on 55, effect 3853,
  appears on no category-7 type in this SDE snapshot).
- **Operator 4, postMulAlt — multiplier.** Flutter
  `_postMulAlt = 4`, one of `_isMul`. Census: (482 ← 147
  `capacitorCapacityMultiplier`) on 144 types, 120 with a
  present operand in [0.75, 1.07] (flux coils at 0.8,
  power diagnostic systems above 1.0, reactor control
  units at exactly 1.0 — present, non-zero, therefore
  emitted, the #617 identity rule); (55 ← 144) on 95
  types, operands in [0.61, 1.35] (rechargers and flux
  coils below 1.0, a minority above 1.0 — a *slower*
  recharge, applied as written).
- **Operator 6, postPercent — percent.** Flutter
  `_postPercent = 6`, chaining `1 + value/100`. Census:
  (482 ← 1079 `capacitorCapacityBonus`) on 8 types
  (Semiconductor Memory Cell rigs, +15.0/+20.0); (55 ← 314
  `capRechargeBonus`) on 8 types (Capacitor Control
  Circuit rigs, −15.0/−20.0).

Every applicable category-7 carrier today has **at most
one applicable entry per attribute** (71 types carry one
entry on each attribute; none carries two on the same
attribute), no carrier has a duplicated (modified,
modifying, operator) triple on either attribute, and no
carrier is mixed-classification *within* one attribute.
Section 3 locks those as fail-loud generator invariants,
not as silent assumptions.

**Unsupported operations (locked: counted, never
guessed).** No category-7 capacitor carrier in the
committed data uses any operator outside {2, 4, 6}.
Operators `0` (postMul) and `3` (modSub) are defined by
Flutter for the ship path in general, but no capacitor
carrier, fixture, or test in any inspected body exercises
them on {482, 55}; operators `-1, 5, 7, 9` have no
ship-path meaning in Flutter at all (the route falls
through to `unsupportedOperators++`). This slice therefore
grounds exactly {2, 4, 6} — supported operators come from
census evidence only: any other operator with a present,
non-zero operand is classified **unsupported** by the
generator (section 3: marks the type unapplied *for that
attribute's dimension*, emits no entry) and guarded the
same way at runtime (section 4). The same
counted-not-applied treatment covers every shape outside
the grounded one: any other `func` or `domain` (all 30
committed-zip effect rows touching {482, 55} are
`ItemModifier` — 27 `shipID`, 3 `structureID` structure
bonuses that never modify the fitted ship; there are no
`Location*`/`Owner*` rows on either attribute), and
carriers outside category 7 — ship-trait carriers
(category 6: only 4 ship types), skill carriers (3417
Capacitor Systems Operation, 3418 Capacitor Management),
implants (category 20), and subsystem carriers (category
32, including the four strategic-cruiser cores 45623 /
45626 / 45629 / 45632 carrying a flat 482 add) gain no
emission (section 9 defers each by name).

**Census (locked counts).** Scripted over the committed
data (zip `modifierInfo` ⋈ `dgmTypeEffects` ⋈
`dgmTypeAttributes` ⋈ the current catalogue, category 7
only, the four-way classification of section 3 applied
**per attribute**):

- **482:** 182 carrier types → **155 applicable** (155
  entries: 27 operator-2, 120 operator-4, 8 operator-6),
  **27 absent-only** (20 Capacitor Power Relay types
  missing attribute 147, 4 abyssal microwarpdrives —
  47408, 47740, 47745, 56306 — missing 147, 3 abyssal
  capacitor batteries — 48431, 48435, 48439 — missing 67;
  the abyssals' real bonuses are mutated per-item values
  the SDE type rows do not carry), 0 zero-only, 0
  unsupported-only. The 27 absent-only types are the
  capacity-dimension marked-unapplied set.
- **55:** 103 carrier types → **103 applicable** (103
  entries: 95 operator-4, 8 operator-6), 0 absent, 0
  zero, 0 unsupported. The recharge-dimension
  marked-unapplied set is empty today.
- Distinct carrier types across both attributes: 214 (71
  carry a triple on each attribute, 111 only on 482, 32
  only on 55). Of the 71 dual-triple types, 51 are
  applicable on both attributes and 20 — the power relay
  family — are applicable on 55 with the 482 operand
  absent. That family is why classification, emission,
  and counting in this slice are **per attribute, not per
  type**: the #615/#617 per-type unapplied predicate
  ("no applicable entry and an absent one") applied to a
  single combined capacitor family would see the relay's
  applicable recharge entry and silently drop its
  ungroundable capacity penalty. Section 3 therefore
  emits two modifier families, one per attribute, each
  with its own unapplied marker — the one deliberate
  structural divergence from #617, forced by this census
  row. Total category-7 types in the catalogue: 3925;
  every carrier has slot effects.

**Arithmetic (locked, Flutter ship path verbatim).** For
each of the two attributes independently:

```text
bonused value = (base + Σ operator-2 operands)
                × Π operator-4 operands
                × Π (1 + operator-6 operand / 100)
```

Sources: operator codes `_modAdd = 2`, `_postMulAlt = 4`
(one of `_isMul`), `_postPercent = 6`
(`dogma_engine.dart:25-34`); the `ItemModifier`/`shipID`
route summing adds, collecting muls and percents
(`routeOwnerModifiers`); the final ship composition
`value = (base + Σ adds) × Π mul × chain(percent)`. Locked
consequences builders must not "improve":

- **No stacking penalty on either capacitor attribute, in
  any class.** Verified from the inspected body, never
  assumed: Flutter's `_percentChain` applies
  `getStackingPenalty` only when the attribute is in
  `_nonStackableAttributes`, which is exactly the twelve
  resonances (`dogma_engine.dart:115-128, 167-179`); 482
  and 55 are not in that set, so every capacitor percent
  factor uses penalty `1.0` — the #617 hit point finding,
  re-verified for this attribute pair. Two Capacitor
  Control Circuit I rigs give duration `× 0.85 × 0.85`
  (section 8 pins it). `resistance_stacking_penalty` and
  `percent_chain` are never called on this path.
- **Order is adds, then mul, then percent** — a battery's
  flat gigajoules are themselves scaled by a fitted
  percent rig: (250 + 150) × 1.15 = 460, not
  250 × 1.15 + 150 (section 8 pins it). Flutter adds
  skill percents into the same accumulator after modules
  (Capacitor Management is in its known-skill table);
  skills are out of scope here (section 9), so nothing
  else enters the chain.
- **Bonuses can shrink the capacitor or slow its recharge,
  and nothing clamps.** 482 multipliers run down to 0.75
  and 55 multipliers up to 1.35, so the bonused peak can
  be *below* base and a base-stable fit can deplete when
  bonused. A computed bonused capacity that is negative
  or non-finite is no data (section 4); a bonused
  recharge duration that is `<= 0` or non-finite is
  likewise unusable — never rendered, never simulated,
  block `Unavailable` — because both consumers divide by
  it or exponentiate over it. A bonused capacity of
  exactly `0.0` is a real zero at the helper level, but
  stability still treats zero capacity as no honest
  verdict, exactly as the base path does (its `> 0`
  filter, `ship_cap_stability.rs:448-462`); section 5
  collects the rule. On today's operands (adds ≥ 60.0,
  capacity muls in [0.75, 1.07], recharge muls in
  [0.61, 1.35], percents in [−20.0, 20.0]) a non-positive
  bonused duration is unreachable from a usable base at
  any sane quantity; the rule exists for fixtures,
  hostile quantities, and future data (section 8 pins
  each route to it).
- **Absent base is never resurrected — the #617 house
  divergence from Flutter, named again.** An absent,
  negative, or non-finite base capacity or recharge makes
  that bonused value `None` however many bonuses target
  it; a battery never invents a capacitor on a hull with
  no capacitor data. A *present* `0.0` base is a real
  zero and bonuses apply to it normally at the helper
  level ((0 + adds) × …).
- **Units stay catalogue units through the helper.**
  Bonused capacity is gigajoules; bonused recharge is
  **milliseconds** (the base field's unit), converted to
  seconds only where the base paths convert (section 4).
  No consumer bonusing in seconds: a percent or
  multiplier is unitless so the choice is invisible
  except for float association, and section 4 locks the
  association that keeps empty fittings bit-exact against
  base.
- **No module state**, as #615 locked: every counted
  fitted item contributes as if active. That assumption
  is user-visible wording in the new block (section 7).

## 3. Catalogue extension (locked)

The bundled catalogue gains per-type capacitor modifier
entries through its existing generator only, mirroring
#617 section 3 in every particular this section does not
state. Hand-editing the JSON is forbidden. Catalogue
today: 3,860,942 bytes, sha256
`c03d38f884900fc6659b45871e44f8ede7c01cf9e10e4de8e630271032158273`.

**Generator changes**
(`scripts/sde/generate_fitting_types_sde.py`). The
capacitor legs reuse the inputs the resistance leg already
reads — `dogmaEffects.jsonl` from the committed zip
(fail-loud if missing or unreadable, lines 1508–1545),
`dgmTypeEffects`, `dgmTypeAttributes`, and the category
map — extending the wanted-modifying-ids set to the
capacitor modifying attributes so one operand pass serves
all legs (lines 1546–1622; the operand-label helper gains
the "capacitor modifier operand" label the same way it
gained the hit point one). No second zip read; the
generator still never downloads; the header comment gains
the capacitor keys beside the hit point ones.

- Beside `HIT_POINT_MODIFIER_ORDER`, add the locked
  constants with a provenance comment citing
  `dogmaEffects.jsonl`, the caches, and Flutter
  `dogma_engine.dart` at `ed698d3` for the operator codes
  and the absent/zero skip:

  ```python
  CAPACITOR_MODIFIER_ORDER = [482, 55]
  CAPACITOR_MODIFIER_OPERATORS = {2, 4, 6}
  CAPACITOR_MODIFIER_ATTRS = {482, 55}
  ```

  The order is capacity before recharge everywhere an
  order is needed (emission key order below, the pure
  layer's accumulator positions in section 4); the
  operator set is section 2's census-grounded three.
- Build **two** per-type entry maps beside
  `hit_point_modifiers_by_type`, one per attribute —
  `capacitor_capacity_modifiers_by_type` (modified 482)
  and `capacitor_recharge_modifiers_by_type` (modified
  55) — each classifying every `ItemModifier`/`shipID`
  modifier on its attribute, category-7 types only,
  deduplicated by (modified, modifying, operator), as
  exactly one of (the #615 four-way classification,
  applied per attribute per section 2's census finding):
  - **applicable**: operator in {2, 4, 6} and operand
    present, finite, and not `0.0` → an emitted entry;
  - **unsupported**: operator outside {2, 4, 6} and
    operand present and not `0.0` → no entry; marks the
    type unapplied *in that attribute's family* (zero
    types today);
  - **zero**: operand present and exactly `0.0` → no
    entry, no mark (provably no bonus; zero types today);
  - **absent**: operand not in the cache for this type →
    no entry; marks the type unapplied in that family
    **only if the type ends with no applicable entry and
    no zero classification in that family** (the #615
    predicate, per family; the 27 absent-only capacity
    types of section 2, and no recharge types).
- Loud failures, house style (`fail(...)`, writes
  nothing), mirroring the hit point leg (lines 1700–1778):
  an unparseable or non-finite operand value on a
  classified modifier; a duplicated (modified, modifying,
  operator) triple on one type in either family; two
  applicable entries on one type sharing a modified
  attribute (in a single-attribute family: two applicable
  entries at all). All are zero on today's data
  (scripted). Messages say "capacitor modifier", never
  "resistance modifier" or "hit point modifier".
  Deliberately **not** failures: operand values outside
  today's observed ranges (a negative add, a percent at
  or below −100 — arithmetic the locked formula defines
  and the pure layer guards, section 4), absent operands,
  and zero operands.
- **Emission (locked shape).** Additive and sparse,
  category 7 only, all existing keys byte-stable and
  every non-category-7 row byte-identical to today. Each
  family emits independently, exactly as if it were its
  own #617 leg: a carrier type emits
  `capacitorCapacityModifiers` iff it has at least one
  applicable capacity entry **or** is marked
  capacity-unapplied, and likewise
  `capacitorRechargeModifiers` for recharge. Each value
  is a JSON array of `[modifiedAttributeId, operator,
  operand]` triples (numbers, compact separators; today
  at most one triple per family per type, its modified id
  the family's attribute), with the operand baked in at
  generation time — the modifying attribute id is
  deliberately not emitted, for the #615 reason. A type
  marked unapplied in a family additionally emits that
  family's `capacitorCapacityModifiersUnapplied: true`
  (resp. `capacitorRechargeModifiersUnapplied: true`)
  beside the (possibly empty) array. An all-zero carrier
  in a family emits **neither of that family's keys**.
  The full unapplied predicate, per family (locked): a
  category-7 type with at least one
  `ItemModifier`/`shipID` modifier on the family's
  attribute is marked in that family iff (a) any such
  modifier classed unsupported, or (b) it has no
  applicable entry, no zero classification, and at least
  one absent classification in that family. Today that
  marks exactly **27 types in the capacity family** (all
  empty-array) and **0 in the recharge family**. The
  power relay row 1445 is the shape to hold in mind: it
  emits `capacitorCapacityModifiers: []` with
  `capacitorCapacityModifiersUnapplied: true` **and**
  `capacitorRechargeModifiers: [[55, 4, 0.8]]` with no
  recharge marker. Key placement is immediately after the
  hit point modifier block (lines 2913–2922), in the
  order `capacitorCapacityModifiers`,
  `capacitorCapacityModifiersUnapplied`,
  `capacitorRechargeModifiers`,
  `capacitorRechargeModifiersUnapplied` — capacity before
  recharge per `CAPACITOR_MODIFIER_ORDER` — so
  pre-existing key order on every row is untouched, and a
  row like 1537 carrying all three modifier families
  emits hit point keys first, then capacitor keys.
- **Self-validation.** Two oracle lists beside
  `HIT_POINT_MODIFIER_ORACLES`, same tuple shape
  `(type_id, expected_entries_or_None,
  expected_unapplied)` where `None` means neither of that
  family's keys may be present. Values are cache/zip
  reads from design (section 8 gives the arithmetic they
  feed):
  - `CAPACITOR_CAPACITY_MODIFIER_ORACLES`:
    - 522 'Micro' Cap Battery: `[[482, 2, 60.0]]`, false;
      3488 Small Cap Battery II: `[[482, 2, 150.0]]`;
      2020 Large Cap Battery I: `[[482, 2, 1300.0]]`;
      3504 Large Cap Battery II: `[[482, 2, 1625.0]]`
      (the flat-add pins).
    - 509 'Basic' Capacitor Flux Coil: `[[482, 4, 0.8]]`;
      1541 Power Diagnostic System II: `[[482, 4, 1.05]]`;
      1353 Reactor Control Unit I: `[[482, 4, 1.0]]`,
      false (the multiplier pins — below 1.0, above 1.0,
      and the identity pin).
    - 25954 Large Semiconductor Memory Cell I:
      `[[482, 6, 15.0]]`; 26376 II: `[[482, 6, 20.0]]`
      (the percent pins).
    - 1445 Capacitor Power Relay I and 48431 Small
      Abyssal Cap Battery and 47408 50MN Abyssal
      Microwarpdrive: empty array, unapplied true (the
      absent pins — relay family, abyssal battery,
      abyssal microwarpdrive).
    - 421 'Basic' Capacitor Recharger: neither capacity
      key (recharge-only carrier); 2048 Damage Control
      II: neither (non-carrier); 587 Rifter (category 6)
      and 45623 Legion Core - Augmented Antimatter
      Reactor (category 32): neither (the category-gate
      pins — the subsystem core carries a real flat-add
      triple with a present operand and gains nothing,
      section 9).
  - `CAPACITOR_RECHARGE_MODIFIER_ORACLES`:
    - 421: `[[55, 4, 0.88]]`; 1195 Cap Recharger I:
      `[[55, 4, 0.85]]`; 2032 Cap Recharger II:
      `[[55, 4, 0.8]]`; 509: `[[55, 4, 0.66]]`; 1541:
      `[[55, 4, 0.915]]`; 1353: `[[55, 4, 1.0]]`, false
      (the multiplier pins, fastest to identity).
    - 31370 Small Capacitor Control Circuit I:
      `[[55, 6, -15.0]]`; 26374 Large Capacitor Control
      Circuit II: `[[55, 6, -20.0]]` (the negative-percent
      pins — the sign is the test).
    - 1445: `[[55, 4, 0.8]]`, unapplied **false** (the
      per-dimension pin: the same row is
      capacity-unapplied and recharge-applicable).
    - 522: neither recharge key (capacity-only carrier);
      2048, 587, 45623: neither, as above.
- **Catalogue-wide invariants** beside the hit point
  checks, per family: every present family array is on a
  category-7 row; its entries' modified id is the
  family's attribute, operators in {2, 4, 6}, operands
  finite and not `0.0`, no duplicate modified id; each
  unapplied marker appears only beside its family's array
  and only as `true`; the counts equal the
  design-scripted values for today's data, as named
  constants in the `HIT_POINT_MODIFIER_ROWS` pattern:
  capacity **182 rows with the key** (155 with entries
  plus 27 marked-empty), **27 marked, 155 entries**;
  recharge **103 rows**, **0 marked, 103 entries**. The
  summary print gains those counts beside the hit point
  modifier print.
- Determinism unchanged: types sorted by `typeId`,
  compact separators, trailing newline, no timestamps.
  Proof obligations for the catalogue commit (section 8):
  run the generator twice → identical sha256; strip the
  four new keys from the regenerated file → byte-identical
  to today's `c03d38f8…`. Both proofs are run once and
  reported in the commit body, not committed as scripts.

**Size budget.** A simulation of the locked emission over
the real joined data (285 keyed family-rows — 182 capacity
plus 103 recharge, on 214 distinct types — 258 triples,
27 unapplied markers, compact separators, the key names
above) adds ≈14,000 bytes (≈ +0.4%). Budget: the
regenerated file must land within **+20,000 bytes** of
today's 3,860,942; the catalogue commit body states the
exact new byte count. Anything over budget means the
emission rule drifted (for example emitting zero operands,
marking non-absent types, or emitting on non-category-7
rows) and stops the slice for review. The identity (`1.0`)
operator-4 entries (reactor control units and kin) are
inside the estimate and stay emitted, for the #617 reason.

**Rust loader** (`src/names/fitting_types.rs`).
`FittingType` gains, immediately after the two hit point
modifier fields (lines 121–124), in the hit point fields'
comment style:

```rust
#[serde(rename = "capacitorCapacityModifiers", default)]
pub capacitor_capacity_modifiers: Option<Vec<CapacitorModifier>>,
#[serde(rename = "capacitorCapacityModifiersUnapplied", default)]
pub capacitor_capacity_modifiers_unapplied: bool,
#[serde(rename = "capacitorRechargeModifiers", default)]
pub capacitor_recharge_modifiers: Option<Vec<CapacitorModifier>>,
#[serde(rename = "capacitorRechargeModifiersUnapplied", default)]
pub capacitor_recharge_modifiers_unapplied: bool,
```

with **one** new struct in the same module beside
`HitPointModifier`,
`CapacitorModifier { pub modified_attribute_id: i64, pub operator: i64, pub operand: f64 }`,
deserialized from the 3-element array by the same manual
tuple impl. One struct for both families, deliberately:
the two families are one slice, one operator set, and one
triple shape, with the modified attribute id (482 or 55)
carried in every entry — unlike resistance vs hit points,
there is no second slice boundary for a second struct to
mark. Its doc comment pins the semantics: entries are
generation-time-proven `ItemModifier`/`shipID` capacitor
bonuses on attribute 482 (capacity family) or 55 (recharge
family) with the operand baked in (operator 2 is modAdd, 4
is postMulAlt, 6 is postPercent); attribute 55 is a
millisecond duration, lower is faster (this document
section 2); `Some(empty)` with the unapplied flag is a
carrier whose bonus *in that family* the bundled data
cannot ground and must be counted, never read as "no
bonus"; `None` is a non-carrier or an all-zero carrier *in
that family* — the other family is judged independently.
`#[serde(default)]` keeps old assets and `from_json`
fixtures loading as `None`/`false`. Nothing is validated
at load (the pure function guards values, section 4; the
invariants test proves the shipped asset).

**Invariants to add** to `bundled_catalogue_invariants`
(`src/names/fitting_types.rs`), beside the hit point block
(lines 1450–1493), all over the real bundled asset, per
family: the family array is `Some` only on category-7
rows; capacity exactly 182 rows carry it, 155 non-empty,
27 marked unapplied, 155 entries total; recharge exactly
103 rows, 103 non-empty, 0 marked, 103 entries; every
entry's modified id is the family's attribute (482 resp.
55) with no duplicate modified id per row, operator is 2,
4, or 6, operand finite and `!= 0.0`; each unapplied
marker appears only beside its family's `Some`; spot pins
mirroring the generator oracles (522, 3504, 509 in both
families, 1541 in both families, 1353 `[[482, 4, 1.0]]`
and `[[55, 4, 1.0]]`, 25954, 2032, 31370's
`[[55, 6, -15.0]]`, 1445 capacity-empty-with-flag beside
recharge `[[55, 4, 0.8]]` without flag, 48431
capacity-empty-with-flag, 421 capacity `None` beside
recharge `[[55, 4, 0.88]]`, 2048 / 587 / 45623 `None` in
both families; 1537 keeps its `hitPointModifiers`
`[[263, 4, 1.02]]` beside its two capacitor families,
proving the families coexist independently). The existing
invariants pass unmodified.

## 4. Pure API (locked)

**Bonused capacitor helper**
(`src/fitting/ship_resistances.rs`, beside
`bonused_hit_points` — that module already owns the
counted-item scan (`counted_flag`) and the bounded run
arithmetic (`mul_product`) all three helpers share;
duplicating either into `ship_cap_stability.rs` would fork
the counted predicate, the #617 argument verbatim). No new
module. Names are part of the lock:

```rust
/// Bonused capacitor capacity (GJ) and recharge duration
/// (milliseconds, the catalogue unit; lower is faster)
/// plus the fitted-module counts the caller must disclose
/// beside any number derived from them.
pub(crate) struct BonusedCapacitor {
    /// [capacity_gj, recharge_ms] in CAPACITOR_ORDER
    /// position, each `None` exactly where the base value
    /// is absent, negative, or non-finite, or the bonused
    /// result is negative or non-finite.
    pub values: [Option<f64>; 2],
    /// Counted fitted rows with no catalogue row at all,
    /// so no capacitor bonus can be proven or disproven
    /// for them, in quantity units. Same definition and
    /// source predicate as
    /// `BonusedResonances::excluded_modules` (pinned
    /// equal, section 8).
    pub excluded_modules: usize,
    /// Capacity-dimension count: counted fitted rows the
    /// catalogue marks as capacity carriers whose bonus
    /// cannot be applied, in quantity units. Never summed
    /// with `capacitor_recharge_unapplied_modules`.
    pub capacitor_capacity_unapplied_modules: usize,
    /// Recharge-dimension count: same shape for the
    /// recharge family. Never summed with
    /// `capacitor_capacity_unapplied_modules`.
    pub capacitor_recharge_unapplied_modules: usize,
}

/// `None` only when the ship gate fails (`ship_type_id
/// <= 0`, no catalogue row, or the row is not category
/// 6). Otherwise `Some`, per-value `None` as documented
/// on `values`.
pub(crate) fn bonused_capacitor(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> Option<BonusedCapacitor>;
```

Locked helper semantics, mirroring `bonused_hit_points`
(lines 463–566) with the capacitor substitutions:

- **Ship gate and bases.** The gate is the siblings'
  verbatim. Bases in `CAPACITOR_ORDER: [i64; 2] = [482,
  55]` position (a new private constant beside
  `HIT_POINT_ORDER`): the ship row's `capacitor_capacity`
  (GJ) and `capacitor_recharge_rate` (**raw
  milliseconds**, never converted in the helper), each
  under the same usability filter shape (present, finite,
  `>= 0.0`; present `0.0` is a real zero at this level).
- **Counted scan.** Identical item predicate and
  quantity-units handling to the siblings (`type_id > 0`,
  positive quantity, `counted_flag`, `usize::try_from`,
  saturating adds). It reads **both** capacitor families
  per row, each with its own once-per-item
  `counted_unapplied` pattern *per family*: a family's
  catalogue unapplied flag counts the item's units once
  in that family's count; an entry in a family whose
  modified id is not that family's attribute, whose
  operator is outside {2, 4, 6}, or whose operand is
  non-finite or `0.0` counts the item once in *that
  family's* count (if not already counted there) and is
  skipped — applicable entries in either family are still
  applied, and a defect in one family never counts in the
  other. One fitted item can therefore be counted in
  both unapplied counts, in one, or in neither; the
  counts are never summed (below).
- **Excluded count — one stated divergence from
  `bonused_hit_points`.** That helper counts no excluded
  rows because its sole caller takes the shared count
  from `bonused_resonances` in the same call. The
  capacitor helper's caller (the bonused stability
  function below) has no resonances call to take it from,
  so this helper counts counted rows with no catalogue
  row into its own `excluded_modules`, under the identical
  predicate and units as `bonused_resonances` — pinned
  equal to it in tests (section 8), so the shared
  definition cannot drift. It is a *shared* count in
  meaning (a catalogue-absent row can prove no bonus in
  any dimension), disclosed once per block in each block
  that shows it, never summed across blocks (#616
  section 6, inherited).
- **Run accumulation and bounded arithmetic.** Per
  attribute index, three run lists grouped by exact `==`
  operand value with saturating `u64` counts in
  first-seen order (operator-2 → `add_runs`, operator-4 →
  `mul_runs`, operator-6 → `percent_runs`), composed in
  the hit point helper's exact association:

  ```text
  add_total     = Σ over add runs of operand × (count as f64)
  mul_total     = Π over mul runs of mul_product(operand, count)
  percent_total = Π over percent runs, sorted by |value|
                  descending, of mul_product(1.0 + value / 100.0, count)
  bonused       = (base + add_total) × mul_total × percent_total
  ```

  `mul_product` is reused, not forked; **no stacking
  penalty** (section 2), so `percent_chain` is not
  called. The result is `Some(bonused)` filtered finite
  and `>= 0.0`, per attribute. A hostile quantity can
  therefore only yield the formula's own finite
  non-negative value or `None` — never a hang, never
  infinity, never a negative duration passed downstream
  (section 8 pins each class, including recharge driven
  to exactly `0.0`, which the consumers below reject).
- **Identity (locked, exact).** With no applicable entry
  on an attribute the bonused value is `(base + 0.0) ×
  1.0 × 1.0` — the base, equal under `==`; an identity
  `1.0` multiplier likewise changes nothing bit for bit
  (the #617 argument).
- The helper is `pub(crate)`, never re-exported from
  `src/fitting/mod.rs`. The `ship_resistances.rs` module
  header gains a short paragraph naming it as the
  capacitor sibling serving the bonused capacitor block
  under this document; the header's statements about the
  public functions do not change. No logging is added.

**Bonused peak recharge** (`src/fitting/ship_peak_recharge.rs`).
The bonused capacitor peak is the existing guarded
formula at bonused inputs, exposed to the bonused
stability path without inventing a second peak API:

```rust
/// Capacitor peak recharge in GJ/s for one (capacity,
/// recharge duration in seconds) pair under the shipped
/// guards (`peak_rate` with `CAPACITOR_PEAK_FACTOR`):
/// `None` unless capacity is finite `>= 0`, recharge is
/// finite `> 0`, and the rate is finite.
pub(crate) fn capacitor_peak_recharge(
    capacity: Option<f64>,
    recharge_secs: Option<f64>,
) -> Option<f64>;
```

`ship_base_peak_recharge` is refactored to call it for its
capacitor field (its shield field keeps calling
`peak_rate` with `SHIELD_PEAK_FACTOR` directly); its
behaviour and tests are unchanged in every byte. The
rejected alternative — building a modified `ShipBaseStats`
copy and reading `ship_base_peak_recharge(&copy).capacitor_gj_per_sec`
— would couple the bonused path to seven fields it does
not use and invite a reader to treat the copy as bonused
base stats; the wrapper names exactly the pair it
consumes. The shield peak is never bonused anywhere in
this slice: no shield capacity/recharge pair
(263/479) emission or computation is added (section 9),
and every shield peak line keeps reading base stats.

**Bonused capacitor stability**
(`src/fitting/ship_cap_stability.rs`). One new public
function and outcome struct, shapes mirroring
`FittingCapStability` so the renderer reuses the base
block's line helpers unchanged:

```rust
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BonusedFittingCapStability {
    pub outcome: CapStabilityOutcome,
    pub total_use_per_sec: Option<f64>,
    pub peak_recharge_per_sec: Option<f64>,
    /// Same definition, units, and source as
    /// `FittingCapStability::counted_modules`.
    pub counted_modules: u64,
    /// Drain-dimension count: same definition, units,
    /// and source as
    /// `FittingCapStability::excluded_modules` (pinned
    /// equal, section 8).
    pub excluded_modules: u64,
    /// Bonus-dimension excluded count: counted fitted
    /// rows with no catalogue row, from
    /// `bonused_capacitor`. A subset of the rows behind
    /// `excluded_modules` on any real fitting, disclosed
    /// separately with its own wording — never summed
    /// with it.
    pub bonus_excluded_modules: usize,
    /// Capacity-dimension unapplied count, from
    /// `bonused_capacitor`. Never summed with
    /// `capacitor_recharge_unapplied_modules` or any
    /// resistance/hit-point count.
    pub capacitor_capacity_unapplied_modules: usize,
    /// Recharge-dimension unapplied count, from
    /// `bonused_capacitor`. Never summed with
    /// `capacitor_capacity_unapplied_modules`.
    pub capacitor_recharge_unapplied_modules: usize,
}

pub fn fitting_cap_stability_with_module_bonuses(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> BonusedFittingCapStability;
```

Count types are locked as written, each matching its
source precedent: `u64` for the two counts the base
struct carries (so the shared fields compare equal
without conversion), `usize` for the three bonus counts
(the resistances/hit-point helper precedent). The mixed
types in one struct are deliberate and documented on the
fields; no conversion helper is added. Re-exports from
`src/fitting/mod.rs` gain exactly
`fitting_cap_stability_with_module_bonuses` and
`BonusedFittingCapStability` (beside line 40); the outcome
enum is the existing `CapStabilityOutcome`, reused, not
duplicated — its `Unavailable` doc is widened in the same
edit to name the bonused reading ("or its bonused
capacity / recharge is absent, non-finite, zero, or
negative" for the bonused function), and the
`CapStabilityOutcome`/module-header statements are scoped
so "base" claims attach to `fitting_cap_stability` by
name (section 7 lists the sentences that would otherwise
become false).

Locked bonused-stability semantics, stated as the delta
from `fitting_cap_stability` (lines 334–496; everything
not mentioned is inherited unchanged):

- **Drains are identical, by construction.** The existing
  module pass (slot-flag predicate, need/cycle proof,
  grouping, `counted_modules`, drain `excluded_modules`,
  `total_use`) is extracted into one private helper —
  `collect_drains(fitting, catalogue) -> (Vec<CapDrain>,
  u64, u64, f64)` returning (drains, counted, excluded,
  total_use) — called by both entry points. This internal
  refactor is the only change to the base function's
  body; its behaviour is byte-identical and every
  existing base test passes **unmodified** (section 8).
  Duplicating the pass instead would let the two blocks'
  drain sets drift apart silently, which is the failure
  this rule exists to prevent: module needs and cycles
  are base in both blocks *because they are the same
  code*, not by parallel discipline. A fitted capacitor
  carrier (battery, recharger…) has no proven need
  (batteries ship no `capacitorNeed`) and so typically
  appears in this pass as drain-excluded, exactly as
  today; that count and the bonus counts describe
  different deficits of the same item and are both
  disclosed, never merged.
- **Ship side comes from the helper, not
  `ship_base_stats`.** `bonused_capacitor` returning
  `None` (ship gate) → `Unavailable` with
  `total_use_per_sec`/`peak_recharge_per_sec` `None` and
  the three bonus counts `0` (unrendered on
  `Unavailable`, as the base renderer's counts are). The
  two bonused values then pass the base path's ship-side
  filter, applied to bonused values: capacity must be
  `Some`, finite, and `> 0`; recharge must be `Some`,
  finite, and `> 0` **milliseconds** — otherwise
  `Unavailable` the same way. This is the gate that makes
  a recharge duration bonused to `0`, negative (already
  `None` from the helper), or non-finite (already `None`)
  **never simulate and never render**: `run_simulator`
  is not called, no peak is computed, and the renderer
  shows only the fixed unavailable sentence (sections
  6–7). Helper-`None` in *either* value is likewise
  `Unavailable`: capacitor stability is one coupled
  quantity of the pair, not two independent layers, so
  unlike EHP there is no partial verdict — a hull with a
  bonused capacity but no usable recharge has no more a
  bonused stability than a base hull missing one field
  has a base one. (Per-value partiality still exists and
  is pinned at the helper level, section 8.)
- **Conversion association (locked for bit-exact
  identity).** `recharge_secs = bonused_recharge_ms /
  1000.0`; the simulator is called as
  `run_simulator(capacity, recharge_secs * 1000.0,
  &drains)` and the peak as `capacitor_peak_recharge(
  Some(capacity), Some(recharge_secs))` — the base path's
  exact association (base: `ship_base_stats` divides by
  1000, the stability function multiplies back for the
  simulator, lines 479/465). Passing the helper's
  milliseconds to the simulator directly would be
  equal *almost* everywhere and 1-ulp different on some
  hull, breaking the empty-fitting identity below;
  builders must not "simplify" it.
- **Simulator and verdict.** `run_simulator` is reused
  **unchanged** — it is already parameterized on
  `(capacity, recharge_ms, drains)` (line 192); no
  signature change, no fork, no injector paths return.
  The drains-empty Stable-at-100% early return, the
  `total_use_per_sec` finiteness rule, and the
  Stable/Depletes mapping are the base code's lines
  463–488 with the bonused pair substituted. (Factoring
  those lines into a shared private tail is permitted if
  the base tests pass unmodified; duplicating the
  simulator is not.)
- **Peak.** `peak_recharge_per_sec` is the bonused peak
  from `capacitor_peak_recharge` above — it labels the
  comparison, never decides the verdict, exactly as in
  the base struct. It is `None` whenever the outcome is
  `Unavailable`, and otherwise `None` only where the
  peak's own overflow guard fires on a usable pair (a
  non-finite rate) — a real verdict with no peak line,
  the base shape.
- **Empty-fitting identity (locked, exact).** For a
  fitting with no applicable capacitor entry on either
  attribute — hull-only, only non-counted items, counted
  non-carriers, identity-`1.0` carriers (1353 in both
  families) — the bonused function's `outcome`,
  `total_use_per_sec`, `peak_recharge_per_sec`,
  `counted_modules`, and `excluded_modules` are **equal
  under `==`** to `fitting_cap_stability`'s on the same
  fitting: same drains from the same pass, bonused pair
  bit-equal to base by the helper identity, same
  conversion association, same simulator. Section 8 pins
  this field-by-field with `assert_eq`, including on the
  three demo fittings and the shipped EFT oracle, none of
  which carries a capacitor carrier in a counted slot
  (design-checked against `assets/demo/fittings.json`:
  Demo Brawler's counted rows are 2048/2049/1225/2050/
  2050/1535/28270 — 1535 catalogue-absent, the rest
  non-carriers — so its 234.0 s depletion, Demo Runner's
  76.95496917307892%, and the EFT sample's 36.0 s
  reproduce exactly, with `bonus_excluded_modules == 1`
  on the Brawler for 1535 while its drain-excluded stays
  5).
- **Count rule (locked, collected).** Four deficit
  counts, four definitions, no sums: drain-excluded
  (`u64`, base definition), bonus-excluded (`usize`,
  catalogue-absent counted rows — the *shared* excluded
  definition, taken from `bonused_capacitor`, pinned
  equal to `bonused_resonances`'), capacity-unapplied,
  recharge-unapplied. The resistance and hit-point
  unapplied counts in the EHP/resistances blocks are
  untouched by this slice and are never added to any of
  these, in the API or the UI. Counts are populated on
  every path as the base struct's are, and rendered only
  in the Available (Stable/Depletes) arm (section 6).
- **Independence.** The bonused function's availability
  keys off the bonused pair only; it never consults
  `fitting_cap_stability`'s outcome, resources, base
  stats as a gate, resistances, or EHP. Base can render
  while bonused is `Unavailable` (a fixture driving
  bonused recharge to `0` on a hull with usable base —
  section 8 pins that split) and vice versa is impossible
  only because the ship gate is shared. The function
  never panics; there is no error channel; nothing logs.

## 5. Completeness and Unavailable rules (locked)

Collected in one place; sections 2 and 4 are normative
and this section adds nothing to them:

- The verdict and peak compute only from a complete
  bonused pair: usable base capacity and recharge
  (present, finite, non-negative; present `0.0` real at
  helper level), finite non-negative bonused results,
  and then the ship-side `> 0` requirement on **both**
  bonused values. Missing data is `Unavailable` for the
  block — never rendered as zero, never filled from the
  base block's numbers, never half-shown.
- A bonus never resurrects missing base data, in either
  dimension: absent base capacity stays `None` under any
  battery; absent base recharge stays `None` under any
  recharger.
- A bonused recharge duration of `0`, or a bonused
  capacity of `0`, yields `Unavailable` — not Stable, not
  a `0.0` line. (At helper level both remain `Some(0.0)`;
  the distinction is pinned in tests so the two levels
  cannot be confused.) Negative or non-finite bonused
  values never leave the helper at all.
- The block is `Unavailable` — heading plus the
  no-ship-data sentence, no numbers, no count lines —
  when the ship gate fails (`ship_type_id <= 0`, no
  catalogue row, not category 6) or either bonused value
  is unusable under the rules above; heading plus the
  no-catalogue sentence when the catalogue itself failed
  to load. Unavailable in this block says nothing about
  any sibling block, and vice versa.
- Counts render only beside a Stable/Depletes verdict.
  Drain-excluded, bonus-excluded, capacity-unapplied,
  and recharge-unapplied rows are counted in quantity
  units and disclosed with their own wording (sections 4
  and 7); nothing fitted is silently dropped, nothing
  missing is silently zeroed, and no two counts are ever
  added together anywhere.

## 6. Display (locked)

One new block, one new renderer, beside the existing
capacitor stability block in `src/ui/fittings.rs`.
`render_fitting_cap_stability_with_module_bonuses` mirrors
`render_fitting_cap_stability` (lines 3175–3199) in shape:
no-catalogue arm (heading plus the no-catalogue sentence),
otherwise `fitting_cap_stability_with_module_bonuses`;
`Unavailable` renders heading plus the no-ship-data
sentence and nothing else; Stable/Depletes renders
heading, the block's lines, then the disclosure last. It
is called immediately after `render_fitting_cap_stability`
at **both** existing call sites — imported detail (line
3860) and saved detail (line 4171) — both in the same
edit; a half-wired slice showing the block on one surface
only is a defect. Reading order is otherwise unchanged:
base Capacitor block, then the bonused Capacitor block
(the bonused resistances / bonused EHP placement rule:
bonused follows its base). The block renders even when
the bonused numbers equal the base numbers, and even when
the fitting has no items, as the base block does. It
depends only on the fitting and the catalogue, logs
nothing, and shows no raw EVE ID.

Line order in the Stable/Depletes arm (locked): module
capacitor use, capacitor peak recharge, outcome, then the
four count lines that apply — drain-excluded,
bonus-excluded, capacity-unapplied, recharge-unapplied —
then the disclosure. The first three reuse the base
block's helpers **verbatim** (`cap_stability_use_line`,
`cap_stability_peak_line`, `cap_stability_outcome_line`,
lines 3091–3117): the labels and formats are identical to
the base block's because only the inputs changed, and the
shared `cap_stability_excluded_line` (lines 3124–3137)
renders the drain-excluded count with its existing
wording — the deficit it names (base capacitor use not in
the bundled data) is unchanged in this block. A new pure
`cap_stability_with_bonuses_lines(&BonusedFittingCapStability)
-> Vec<String>` composes them like `cap_stability_lines`
(and returns empty for `Unavailable`, same shape). Three
new pure count helpers beside the existing ones, same
`None`-at-0 / singular / plural shape (strings locked in
section 7): `bonused_capacitor_excluded_line(usize)`,
`bonused_capacitor_capacity_unapplied_line(usize)`, and
`bonused_capacitor_recharge_unapplied_line(usize)`.

**No other surface changes.** The Ship (base values)
block keeps its base capacitor capacity, base recharge,
and base capacitor peak recharge lines
(`ship_base_peak_recharge` at its existing call site,
line 2323–2328); bonused capacity and bonused recharge
duration are rendered nowhere as standalone numbers; the
shield peak line stays base. The base Capacitor block is
byte-untouched. No editor, import, persistence, or other
block changes.

## 7. UI wording (locked verbatim)

New constants in `src/ui/fittings.rs` beside the base
capacitor block's (lines 3077–3089), with doc comments in
the same style pointing at this document. No string calls
these numbers a fitting "simulation" of the real ship,
"cap life", or a "tank", and none contains a raw EVE ID.

- Heading (`FITTINGS_CAP_STABILITY_WITH_BONUSES_HEADING`):
  `Capacitor (with fitted module bonuses)` — parallel to
  `Ship resistances (with fitted module bonuses)` and to
  the base block's `Capacitor (base values)`.
- Disclosure
  (`FITTING_CAP_STABILITY_WITH_BONUSES_DISCLOSURE`,
  verbatim, always last in the Stable/Depletes arm):

> Assumes every counted module keeps cycling continuously. These numbers add the fitted modules' and rigs' capacitor capacity and recharge bonuses from Mimir's bundled item data to the base values above. Every fitted module is counted as active, because the fitting data does not say which modules are on. Module capacitor use stays at base values: bonuses to how much capacitor a module needs or how fast it cycles are not applied. Ship bonuses, subsystems, skills, implants, and capacitor changes from anything outside this ship are not applied. Capacitor boosters and effects on other ships (such as energy neutralizers and remote repairers) are not modelled, so these numbers can differ from EVE.

  Wording notes (do not rephrase in review): the first
  sentence is the base block's continuous-cycling
  assumption verbatim; "counted as active" is #615's
  locked plain form; the module-use sentence is this
  block's load-bearing honesty line, because the "Module
  capacitor use" figure above it is identical in both
  blocks; "subsystems" is in the not-applied list because
  category-32 capacitor bonuses (the strategic-cruiser
  cores) are not applied even though subsystem slots are
  counted slots (section 9).
- Unavailable sentences (the sibling templates with this
  block's name):
  - `Capacitor with fitted module bonuses unavailable: Mimir's bundled item data failed to load.`
  - `Capacitor with fitted module bonuses unavailable: Mimir's bundled item data has no capacitor data for this fitting's ship.`
- Count lines in this block (section 6 helpers):
  - The drain-excluded line is `cap_stability_excluded_line`
    verbatim, as in the base block.
  - `bonused_capacitor_excluded_line(1)`:
    `1 fitted module is not in Mimir's bundled item data, so any capacitor bonus from it is not counted.`
    Plural: `{n} fitted modules are not in Mimir's bundled item data, so any capacitor bonuses from them are not counted.`
  - `bonused_capacitor_capacity_unapplied_line(1)`:
    `1 fitted module has a capacitor capacity bonus Mimir's bundled item data cannot describe, so that bonus is not applied.`
    Plural: `{n} fitted modules have capacitor capacity bonuses Mimir's bundled item data cannot describe, so those bonuses are not applied.`
  - `bonused_capacitor_recharge_unapplied_line(1)`:
    `1 fitted module has a capacitor recharge bonus Mimir's bundled item data cannot describe, so that bonus is not applied.`
    Plural: `{n} fitted modules have capacitor recharge bonuses Mimir's bundled item data cannot describe, so those bonuses are not applied.`
  - Zero in any count renders no line for that count. The
    four lines are separate per-dimension disclosures; no
    combined "modules not counted" line is added
    anywhere. (Wording uses "capacitor recharge bonus",
    never "recharge rate bonus" with a number attached:
    attribute 55 is a duration and no rate figure for a
    single module's bonus exists to print.)

**Existing sentences: what becomes false, what does not
(locked).** The base blocks' disclosures all stay
**byte-identical and true of their own blocks**, and none
is edited in this slice:

- The base Capacitor disclosure — "Fitted modules, rigs,
  subsystems, skills, implants, and ship bonuses are not
  applied to the capacitor, recharge, or module use"
  (`FITTING_CAP_STABILITY_DISCLOSURE`, line 3084) — stays
  true of the base block. It does **not** gain a pointer
  sentence to the bonused block in this slice: the
  resistances disclosure gained one in #616 because that
  sentence already narrated the EHP blocks below it; this
  base disclosure narrates no sibling, and heading
  adjacency does the pointing. (Noted as a deliberate
  non-change so review does not "fix" it asymmetrically.)
- The Ship (base values) disclosure (line 1881) stays
  true: that block's capacitor lines stay base.
- The resistances-with-bonuses and EHP-with-bonuses
  disclosures (lines 1915, 1958) make no capacitor
  claim and are untouched.

The sentences that **would** become false and are
therefore revised in the implementation commits (doc
comments only, no rendered string):

- `src/fitting/ship_cap_stability.rs` module header
  (lines 19–22) — "No modifier of any kind is applied"
  is scoped to `fitting_cap_stability` by name, with a
  short paragraph naming
  `fitting_cap_stability_with_module_bonuses` and this
  document; `CapStabilityOutcome::Unavailable`'s doc
  (lines 60–63, "base capacitor capacity / recharge
  rate") is widened per section 4, since the enum now
  serves both functions.
- `src/fitting/ship_peak_recharge.rs` module header
  (lines 10–13) — the same scoping for
  `ship_base_peak_recharge`, naming
  `capacitor_peak_recharge` as the shared guarded
  formula. `ShipBasePeakRecharge`'s own doc stays as
  written (it still describes base stats only).

No other header, doc comment, or rendered string in the
codebase asserts anything this slice falsifies (the
capacitor stability and peak recharge *design documents'*
no-modifier statements are historical slice boundaries,
superseded by reference in section 2, not edited).

## 8. Test plan (locked)

Tolerance tiers follow the shipped tests: hand-derived
floats use absolute tolerance `1e-9` with the division
shown (the `assert_close` / `assert_rate_close` pattern in
`ship_cap_stability.rs` / `ship_peak_recharge.rs` tests);
identities this design calls exact use `assert_eq`.
Fixture catalogues use the existing `from_json` pattern;
fixture modifier entries are written in the shipped triple
shape under the section 3 key names. Simulator stable
literals below come from an independent line-by-line
Python translation of the shipped `run_simulator`,
validated at design time against the shipped literals
98.72790372802693 (light drain) and 67.76238466310953
(heavy drain) bit-for-bit at print precision — the shipped
tests' own provenance method. Every literal shows its
inputs so the bonused (capacity, recharge) pair is
hand-derived even where the percent is simulator-derived.

Base inputs for every oracle (pinned since earlier
slices): Rifter 587 capacity 250.0 GJ, recharge 125000.0
ms = 125.0 s, base peak 2.5 × 250 / 125 = 5.0 GJ/s;
Punisher 597 capacity 400.0, recharge 160.0 s, peak 6.25.
The standing real-catalogue drain is type 2050 (the demo
fittings' hardener: need 32.0 GJ, cycle 12000.0 ms, use
32/12 = 2.666… GJ/s, medium slot). Items are fitted in
counted slots of the matching family (battery/recharger
medium, relay/flux/PDS/RCU low, rigs rig-slot) at quantity
1 unless stated. Every capacitor carrier named below
ships no `capacitorNeed`, so each fitted carrier
contributes exactly 1 to the *drain*-excluded count in
both blocks (pinned, not assumed away) while contributing
its bonus here — that double appearance is the honest
shape, and the oracles pin both sides of it.

**Oracle 1 — capacity flat add (primary).** Rifter + 2050
+ Small Cap Battery II 3488 (`[[482, 2, 150.0]]`).
Bonused pair: capacity 250 + 150 = 400 GJ, recharge
125.0 s. Peak 2.5 × 400 / 125 = **8.0 GJ/s**. Verdict:
Stable at **82.18512646407277%** (base on the same drains
is Stable 70.3386537337493% — also pinned, through
`fitting_cap_stability`, so the oracle proves the delta
came from the bonus). Use unchanged 32/12. Counts:
counted 1, drain-excluded 1 (the battery), bonus-excluded
0, capacity-unapplied 0, recharge-unapplied 0.

**Oracle 2 — recharge multiplier (duration semantics).**
Rifter + 2050 + Cap Recharger II 2032 (`[[55, 4, 0.8]]`).
Bonused pair: 250 GJ, 125000 × 0.8 = 100000 ms = 100.0 s
— the helper pins `Some(100000.0)` milliseconds, proving
lower-is-faster is applied to the *duration*, never
inverted. Peak 2.5 × 250 / 100 = **6.25 GJ/s**. Stable at
**76.58610664009886%**. Counts as Oracle 1 with the
recharger as the drain-excluded row.

**Oracle 3 — both dimensions together.** Rifter + 2050 +
3488 + 2032: pair (400, 100.0 s), peak 2.5 × 400 / 100 =
**10.0 GJ/s**, Stable **85.7658359519556%**,
drain-excluded 2, all bonus counts 0.

**Oracle 4 — percents, sign included.** Helper-and-peak
pins (no drain fitted; verdict Stable 100% both blocks):
(a) Rifter + Small Capacitor Control Circuit I 31370
(`[[55, 6, -15.0]]`): recharge 125000 × 0.85 = 106250 ms
= 106.25 s (negating or absolutizing the operand gives
143750 ms and fails this pin); peak 2.5 × 250 / 106.25 =
**5.882352941176471 GJ/s**. (b) Rifter + Large
Semiconductor Memory Cell I 25954 (`[[482, 6, 15.0]]`):
capacity 250 × 1.15 = 287.5, peak 2.5 × 287.5 / 125 =
**5.75 GJ/s**. (c) Punisher + Large Cap Battery I 2020
(`[[482, 2, 1300.0]]`): capacity 1700, peak 2.5 × 1700 /
160 = **26.5625 GJ/s** (second hull, second add size).

**Oracle 5 — adds land before percent; no stacking
penalty.** (a) Rifter + 3488 + 25954: capacity
(250 + 150) × 1.15 = **460.0** (the wrong association
250 × 1.15 + 150 = 437.5 is the failure this pin catches;
peak 2.5 × 460 / 125 = 9.2). (b) Rifter + two 31370 in
two rig slots: recharge 125 × 0.85 × 0.85 = **90.3125 s**
— a penalised second rig lands strictly above this; the
literal pins penalty-freedom (section 2). (c) Rifter +
two 25954: capacity 250 × 1.15 × 1.15 = **330.625**.
Helper-level `values` pins with peaks through
`capacitor_peak_recharge`; a stacked quantity-2 row of
one rig equals the two-slot result (runs counted in
units).

**Oracle 6 — bonuses can shrink/slow; the per-dimension
relay.** (a) Rifter + Capacitor Flux Coil I 1246
(`[[482, 4, 0.8]]`, `[[55, 4, 0.64]]`): pair (200.0 GJ,
80.0 s), peak 2.5 × 200 / 80 = 6.25 GJ/s — capacity
*below* base, applied as written. (b) Rifter + Power
Diagnostic System II 1541 (`[[482, 4, 1.05]]`,
`[[55, 4, 0.915]]`): pair (262.5, 114.375 s), peak
2.5 × 262.5 / 114.375 = **5.737704918032787 GJ/s**, and
the row's hit point entry `[[263, 4, 1.05]]` is not read
here (EHP tests keep pinning it there). (c) **The relay
pin:** Rifter + Capacitor Power Relay I 1445: recharge
bonuses to 100.0 s and peak to 6.25 GJ/s; capacity stays
exactly 250.0 (`==` base through the helper) with
`capacitor_capacity_unapplied_modules == 1` and
`capacitor_recharge_unapplied_modules == 0` — the
per-dimension split this slice's emission shape exists
for. Quantity 2 counts 2 in the capacity dimension only.

**Oracle 7 — depletes-seconds change, then depletes →
stable (fixture catalogue).** Extend the shipped fixture
(hull 42: 250.0 GJ / 125000.0 ms; drain 112: 100.0 GJ /
11000.0 ms) with two fixture carrier rows in the shipped
shapes — battery `capacitorCapacityModifiers:
[[482, 2, 150.0]]`, recharger
`capacitorRechargeModifiers: [[55, 4, 0.8]]` (fixture
rows may be added beside 101–112; existing fixture rows
are not edited). One 112 fitted: base **Depletes 33.0 s**
(both functions agree pre-bonus by the identity rule);
with the fixture recharger (pair 250 / 100.0 s) bonused
**Depletes 44.0 s** — event-quantized seconds moving is
the proof the bonused duration reached the simulator;
with battery and recharger (pair 400 / 100.0 s) bonused
**Stable 40.73402144558326%** while base still depletes
at 33.0 s on the same fitting.

**Helper and pure-function pins:**

1. Oracles 1–7 above: peaks and verdicts through
   `fitting_cap_stability_with_module_bonuses` on the
   bundled catalogue (1–6) and the fixture catalogue (7),
   helper `values` through `bonused_capacitor` (in
   `ship_resistances.rs` tests beside the sibling helper
   pins), all five counts each time.
2. **Empty == base, exactly.** Field-by-field `assert_eq`
   of the five shared fields against
   `fitting_cap_stability`, bonus-unapplied counts 0, for:
   hull-only Rifter and Punisher; only non-counted items
   (cargo/charge/drone flags, quantity 0, `type_id <=
   0`); a counted non-carrier (2048); an identity carrier
   (1353 Reactor Control Unit I — `1.0` in both families;
   note it also carries `[[263, 4, 1.0]]` hit points,
   irrelevant here); and the three demo fittings plus the
   shipped EFT sample through `to_character_fitting()`,
   reproducing 234.0 s / 100%-with-excluded /
   76.95496917307892% / 36.0 s exactly, with
   `bonus_excluded_modules == 1` on Demo Brawler (type
   1535 catalogue-absent; its drain-excluded stays 5) and
   0 on the other demo fits where every counted row has a
   catalogue row (assert per-fit from the catalogue, not
   by assumption).
3. **Shared-count equalities.** On every fixture and
   oracle fit: drain-excluded and counted equal
   `fitting_cap_stability`'s (same pass);
   `bonus_excluded_modules` equals
   `ship_resistances_with_module_bonuses`'
   `excluded_modules` on the same fitting wherever that
   outcome is Available (same predicate, two helpers —
   the anti-drift pin for section 4's counted-excluded
   divergence); capacity/recharge unapplied asserted
   separately and never against a sum. A fit carrying a
   hit-point-unapplied carrier with no capacitor entry
   (1447 is both; use a fixture row with only
   `hitPointModifiersUnapplied`) leaves both capacitor
   unapplied counts 0, and vice versa — dimensions never
   bleed.
4. **Partial (helper level) and coupled Unavailable.**
   Fixture hull with capacity absent, recharge present,
   battery + recharger fitted → helper `values ==
   [None, Some(100000.0)]` (no resurrection, recharge
   still bonuses), bonused function `Unavailable`, base
   function `Unavailable`; mirror with recharge absent →
   `[Some(400.0), None]`, both `Unavailable`. Present
   `0.0` capacity with battery → helper `Some(150.0)`,
   bonused computes from (0 + 150) (application to a
   present zero ≠ resurrection of absence — both pinned).
   Present `0.0` recharge (with or without recharger,
   0 × 0.8 = 0) → helper `Some(0.0)`, bonused **and base**
   `Unavailable`.
5. **Hostile bounded (the `<= 0` / non-finite
   recharge battery).** Fixture entries on hull 42:
   recharge percent −100 → helper recharge `Some(0.0)`,
   bonused `Unavailable`, base still computes its verdict
   (the base/bonused availability split); recharge
   percent −150 → helper `None`, `Unavailable`; recharge
   mul operand −0.8 → negative duration → `None`,
   `Unavailable`; quantity `i64::MAX` of a −15 percent
   rig → `mul_product` run reaches `0.0` → helper
   `Some(0.0)`, `Unavailable`, returns promptly; quantity
   `i64::MAX` of a +20 percent capacity rig → run goes
   non-finite → capacity `None`, `Unavailable`, promptly;
   quantity `i64::MAX` of a 0.8 recharge mul → run
   reaches `0.0` → `Unavailable`; quantity `i64::MAX` of
   a capacity battery add → capacity is the locked
   formula's finite `250 + operand × (i64::MAX as f64)`
   (adds never loop; pinned through the helper, and the
   peak through its overflow guard — if the resulting
   rate is non-finite the peak is `None` with the verdict
   still computed, mirroring the base overflow pin in
   `ship_peak_recharge.rs` tests); capacity mul exactly
   `0.0`-producing fixture (percent −100 on 482) → helper
   `Some(0.0)`, bonused `Unavailable` (zero capacity is
   no verdict, section 5). In every `Unavailable` case:
   `total_use_per_sec` and `peak_recharge_per_sec` are
   `None` — the "never renders" half of the rule, since
   the renderer prints only the fixed sentence there
   (item 8 below).
6. **Runtime guard counts.** Fixture rows beyond the
   generator's guarantees: marked-unapplied *with* an
   applicable entry in the same family (counted in that
   family, entry still applied; other family untouched);
   entries with operators 0, 3, and 7, the wrong family's
   modified id (a 55 triple inside
   `capacitorCapacityModifiers` and vice versa), an
   unknown modified id, a zero operand, and a non-finite
   operand → each counts its item once in *that family's*
   unapplied (never twice for two bad entries in one
   family on one item — the once-per-item-per-family pin;
   a bad entry in each family on one item counts once in
   **each**), applicable entries still applied, and a
   guarded entry never contributes its operand.
7. **Base independence regression.** Fitting any oracle
   carrier changes the bonused function and leaves
   `fitting_cap_stability`, `ship_base_peak_recharge`
   (Rifter capacitor 5.0, shield 1.8), `ship_base_stats`,
   `ship_ehp_with_module_bonuses`, and
   `ship_resistances_with_module_bonuses` at their shipped
   oracles on the same fitting; the shield peak stays
   base with a full capacitor fit (the no-shield-pairing
   pin).
8. **Unavailable shapes.** Unknown ship id, non-ship row,
   `ship_type_id` 0 and negative → `Unavailable` with the
   base struct's field shape (`None` use/peak, drain
   counts still populated from the pass, bonus counts 0);
   helper-level: `bonused_capacitor` is `None` exactly on
   the ship gate.

**Regression gates (unmodified).** Every existing test in
`ship_cap_stability.rs` (including all simulator-core
literals, the demo pins, and the inclusion matrix),
`ship_peak_recharge.rs`, `ship_stats.rs`,
`ship_resistances.rs`, `ship_ehp.rs`, and the catalogue
tests passes **unmodified** — the `collect_drains`
extraction and the `capacitor_peak_recharge` refactor are
behaviour-preserving and these tests are the proof; the
only permitted existing-test edits are additive fixture
rows (Oracle 7) and none. If the extraction cannot be
done without moving a base literal, stop against this
document.

**Catalogue pins.** The section 3 loader invariants
(capacity 182/155/27/155, recharge 103/103/0/103, order,
operators, spot pins) join `bundled_catalogue_invariants`
over the real bundled asset. The generator commit reports
in its body: twice-run identical sha256, strip-the-four-
new-keys byte-identity against `c03d38f8…`, and the exact
new byte count against the +20,000 budget. Proofs are run
once and reported, not committed as scripts.

**UI pins (`src/ui/fittings.rs` tests):**

1. New wording test pinning section 7's heading,
   disclosure, and both unavailable sentences verbatim;
   the existing capacitor wording test passes unmodified
   (base strings byte-identical — pinned by
   non-edit).
2. New count-helper pins: the three new helpers at 0
   (`None`), 1 (singular), and 2 (plural) with section
   7's exact strings.
3. Lines by construction: a `BonusedFittingCapStability`
   fixture with every count non-zero renders through
   `cap_stability_with_bonuses_lines` as exactly
   [use, peak, outcome, drain-excluded, bonus-excluded,
   capacity-unapplied, recharge-unapplied] in that order
   with the base helpers' formats for the first four;
   each zero count omits only its own line; `Unavailable`
   yields no lines.
4. Demo-story test: for the three demo fittings the
   bonused lines equal the base lines (`cap_stability_lines`
   output) plus exactly the bonus-excluded line on Demo
   Brawler — the visible form of the empty==base identity
   with honest counts.

**Gates (all must pass for every implementation commit):**
`cargo fmt --check`, `cargo clippy --all-targets -- -D
warnings`, `cargo test`, `cargo build`. Commits are small
and atomic, `type(scope): description`, with no
attribution lines. Locked commit sequence after this
design commit (`docs(fitting): design fitted-module
capacitor bonuses`): (1) `feat(catalogue): emit
fitted-module capacitor modifiers` (generator +
regenerated asset, proof obligations in the body);
(2) `feat(fitting): load capacitor modifiers from the
catalogue` (loader fields + invariants); (3)
`feat(fitting): compute capacitor stability with fitted
module bonuses` (helper, drain-pass extraction, peak
wrapper, bonused function, pure tests, header scoping
from section 7); (4) `feat(fitting): show capacitor
bonuses in capacitor stability` (renderer, wording, line
and count helpers, UI tests, both call sites). Each
commit passes all four gates alone.

## 9. Exclusions (locked)

Out of this slice, by name: ship (hull role/trait)
bonuses (the 4 category-6 ship carriers); character
skills in any form (Capacitor Systems Operation 3417 and
Capacitor Management 3418, and Flutter's known-skill
percent table that would join the same percent chain —
including its `(3418, capacitorCapacity, 0.05)` entry);
implants (category 20) and **boosters of every kind** —
drug boosters and, distinctly, **capacitor boosters /
injectors**: the injector model stays ship-nothing for
the capacitor stability design section 9 reasons (no
charge linkage on saved items, no charge count in any
fitting shape, no infinite-clip assumption imported),
`run_simulator` gains no injector paths, and attribute 67
is read **only** as the capacitor-battery flat-add
operand it is in section 2's census — never as a booster
gain; subsystem capacitor bonuses (category-32 carriers,
including the four strategic-cruiser cores with a
present flat-add operand, gain no emission even though
subsystem slots are counted slots — disclosed by the word
"subsystems" in the bonused block, as the #617 subsystem
deferral was); structure and NPC carriers (the 3
`structureID` effects); capacitor changes from anything
outside the ship (fleet, environment, neutralizers/NOS
draining this ship, remote transfers — unmodelled in the
base block and unchanged here); **the shield recharge
pair** — no modifiers on shield capacity (263) for peak
purposes and none on shield recharge rate (479) at all:
shield peak stays base in every block, and a bonused
shield peak is a future slice against its own census, not
an extension of `CAPACITOR_MODIFIER_ORDER`; **capacitor-
need and cycle modifiers on modules** — no modifier
targeting a fitted module's own `capacitorNeed` (6),
`duration` (73), `speed` (51), or `reactivationDelay`
(1795) is emitted, read, or applied in either block (the
bonused block's disclosure states this in so many words,
section 7), and no charge-attribute path exists; module
active/inactive or overheating state (every fitted module
counts as active, as #615 locked); mutated (abyssal)
per-item values — those types ship counted-not-applied;
any bonused-capacity or bonused-recharge readout outside
the peak and verdict (no `ship_base_stats` change, no
public bonused-pair API — the helper is `pub(crate)`); any
change to base capacitor stability, base peaks,
resistances, EHP, resources, or DPS numbers or emission;
persistence, ESI, editor, and network changes; new
logging.

Operators outside {2, 4, 6} on the capacitor attributes
are not deferred-silently: they are locked as
unsupported → unapplied-counted (in the affected family
only) at generation and at runtime (sections 2–4), which
is this slice's complete answer for them until a future
design grounds one.

## 10. Decision record

When this slice merges, `DECISIONS.md` gains an entry in
the implementation PR (not this design commit): "Bonused
capacitor stability: fitted-module capacitor capacity and
recharge bonuses" — recording the supersession of the
capacitor stability slice's no-modifiers boundary for
attributes 482/55 only (needs, cycles, and boosters stay
excluded), the duration-semantics finding (55 is
milliseconds, lower is faster; negative percents and
sub-1.0 multipliers are the improvement direction and are
never inverted), the no-stacking-penalty verification for
this attribute pair, the per-attribute two-family
emission forced by the power relay census row, the
category-7-only gate with subsystems deferred, and the
four-count never-summed disclosure rule. The entry is the
implementation PR's because it records what shipped; this
document records what was decided before building.
