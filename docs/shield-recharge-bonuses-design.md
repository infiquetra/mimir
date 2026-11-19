# Fitted-module shield recharge bonuses (bonused peak shield recharge) — design

Status: locked for the `feat/rust-shield-recharge-bonuses`
slice. Base: `develop` at `09a9d77` (PRs #561–#618
merged). Slice branch: `feat/rust-shield-recharge-bonuses`.
This document is the single design commit; builders
implement exactly what is locked here and nothing else.
It follows the resistance bonuses slice
(`docs/resistance-bonuses-design.md`, #615), the hit
point bonuses slice (`docs/hp-bonuses-design.md`, #617),
and the capacitor bonuses slice
(`docs/cap-bonuses-design.md`, #618) for emission and
computation shape, and the peak recharge slice
(`docs/peak-recharge-rates-design.md`) for the quantity
being bonused; where this document says "mirrors #617"
or "mirrors #618", that wording and structure are the
precedent and do not need relitigating. It supersedes
the earlier slices' no-shield-bonuses boundaries for the
one new modifier family only (section 2). The earlier
design documents are not edited.

Every name, formula, count, and oracle number below
traces to an inspected body at `09a9d77` —
`src/fitting/ship_peak_recharge.rs`,
`src/fitting/ship_resistances.rs`,
`src/fitting/ship_stats.rs`,
`src/fitting/ship_cap_stability.rs`,
`src/fitting/ship_ehp.rs`,
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
counts), or to the inspected Flutter bodies at `ed698d3`
(`lib/features/fitting/domain/dogma_engine.dart`,
`dogma_attributes.dart`), or to hand arithmetic over
values those bodies pin (shown in section 8). No
convention here comes from EVE folklore or memory. Raw
EVE type IDs never appear in any rendered string in this
slice; type IDs below are internal oracle pins only, as
in #615.

## 1. Goal and value ranking

Add **one** new block, "Shield peak recharge (with
fitted module bonuses)", immediately after the existing
"Ship (base values)" block on both fitting detail
surfaces. It shows exactly one derived number — the peak
passive shield recharge rate in HP/s — computed as

```text
bonused shield peak (HP/s)
    = 2.5 × bonused shield hit points
      / bonused shield recharge duration (seconds)
```

where the numerator is the shield layer of the #617
`bonused_hit_points` helper (dogma 263 `shieldCapacity`
after fitted-module hit point bonuses, already shipped)
and the denominator is the hull's shield recharge
duration (dogma 479, shipped in the catalogue as
`shieldRechargeRate`, loaded as `shield_recharge_rate`,
raw milliseconds) after the fitted modules' and rigs'
shield recharge bonuses — the one modifier family this
slice newly emits (section 3) and applies (section 4).
Flutter feeds post-modifier values into this exact line
(`dogma_engine.dart:891-894`, section 2); every earlier
Rust slice deliberately substituted base values. This
slice closes that gap for the shield pair, category-7
fitted items only.

The base shield peak line keeps rendering inside the
Ship (base values) block from base values, byte-identical
(`src/ui/fittings.rs:2324`); `ship_base_peak_recharge`
and `ship_base_stats` do not change behaviour in any
byte, and their existing tests are the regression gate
(section 8). This is the slice the capacitor bonuses
design section 9 deferred by name ("a bonused shield
peak is a future slice against its own census") and the
peak recharge design section 9 / hit point bonuses
design section 9 excluded as slice boundaries. No
network, no ESI changes, no new scopes, no persistence.

**Its own block, not a line inside bonused EHP
(locked).** The bonused EHP block (`src/ui/fittings.rs:1950`,
renderer `:2564`) is an omni-profile tank figure whose
heading names only resistance and hit point bonuses and
which already discloses three count dimensions (shared
excluded, resistance-unapplied, hit-point-unapplied).
Passive peak recharge is profile-free, is not EHP, and
needs a fourth, new count dimension (shield recharge);
folding it in would conflate tank with passive recharge,
force that count into an EHP disclosure, and falsify the
EHP heading. The precedent is one block per bonused
quantity family (#615 resistances, #617 EHP, #618
capacitor). Bonused shield hit points and bonused shield
recharge duration themselves are shown **nowhere** as
standalone lines in this slice: they exist only inside
the bonused peak, as bonused capacitor capacity and
recharge exist only inside the bonused capacitor peak
and verdict (#618 section 1) and bonused hit points
exist only inside EHP (#617 section 6). The Ship (base
values) block keeps showing base shield hit points and
base shield recharge duration, so its disclosure stays
true.

Value ranking (locked, in order), extending #618's:

1. **Never show a bonused shield number without its
   bonus policy named beside it, and never let a peak
   read as a sustained or average rate or as active
   repair.** The heading says "peak", and the disclosure
   must name the shield hit point and shield recharge
   bonuses applied *and* state that shield boosters and
   other repair are not included, or the figure reads as
   the ship's usable tank — skills, ship bonuses,
   implants, and subsystems are still not applied
   (section 7 wording). The peak recharge design's rank
   1 ("never a peak rate presented without clear
   base/peak labeling") is inherited.
2. **Correctness and exactness of the coupled pair.**
   The bonused peak is one quantity of two inputs; both
   must be hand-derivable from quoted base values and
   emitted operands (section 8), computed at full `f64`
   precision with the locked `(base + adds) × mul ×
   percent` order per input (section 2), and fed to the
   *existing* guarded peak formula unchanged. Absence
   never renders as a number and never resurrects as
   zero, in either input (section 5). In particular a
   bonused shield recharge duration of `0`, negative, or
   non-finite never renders and never divides — there is
   no "instant recharge" reading — and a positive
   subnormal bonused input on either side is stall
   residue, not data (the `2ac348f` guard, sections 2
   and 4).
3. **No deficit is silently dropped, in any dimension.**
   Catalogue-absent rows get the shared excluded count;
   hit-point carriers whose bonus cannot be applied keep
   the #617 hit-point-dimension count, reused verbatim
   from the existing helper; and shield recharge carriers
   whose bonus cannot be applied get a **new, separate**
   shield-recharge-dimension unapplied count (sections 4
   and 7). No two of these counts are ever summed, and
   none is ever summed with the resistance or capacitor
   counts in their blocks. A bonused peak that quietly
   omits a capacitor power relay's ungroundable shield
   recharge triple would cross-read as complete.
4. **Reuse.** The #615/#617/#618 generator
   classification, catalogue tuple shape, loader shape,
   counted-item scan, bounded run arithmetic, and
   count-line shapes; the existing `bonused_hit_points`
   numerator (never recomputed, never forked); the
   existing `peak_rate` guard and `ship_stat_line` seam —
   all beat new machinery (sections 3, 4, 6).

Non-goals are locked in section 9. In particular: no
ship traits, skills, implants, or subsystem bonuses; no
shield boost (active repair) amounts; no modifiers to
module capacitor need or cycle; no sustained tank,
average rate, curve, or charge-level percentage.

## 2. Modifier set, arithmetic, and supersession (locked)

**Supersession.** The peak recharge design section 9
locked "no modifiers of any kind" for both peak inputs
as that slice's boundary; the hit point bonuses design
section 9 excluded "shield recharge or capacitor
recharge changes, passive/peak recharge rates" and
sections 6/9 confined bonused hit points to the EHP
numerator; the capacitor bonuses design sections 4 and
9 kept "the shield peak never bonused" and deferred the
shield 263/479 pair to a future slice against its own
census. This slice is that future slice. Superseded as
slice boundaries, replaced by the sections named: the
no-modifiers boundary for the shield peak's two inputs
(→ sections 2–4 here); the EHP-numerator-only confinement
of `bonused_hit_points`, whose shield layer now also
feeds this peak (→ section 4; bonused hit points are
still shown nowhere as standalone hit point lines).
What is **not** superseded: the peak factor derivation
and the no-charge-level-percentage lock; the
`peak_rate` guard table; #615/#617/#618 semantics,
counted-flag set, bounded arithmetic, and the
subnormal-rejection rule of `2ac348f`; base-statistics,
base-EHP, capacitor, and active-repair numbers anywhere.
A builder who believes this design requires changing
any of those stops and records it against this document.

**Grounded modifier shape (locked — ships, the whole
set).** A fitted item contributes a shield recharge
modifier only when all of these hold, mirroring #617
section 2 with the single shield recharge attribute
substituted:

- its catalogue row is category 7 (module, including
  rigs — category-7 rows with slot effect 2663; shield
  recharge rigs are therefore in scope as fitted items);
- one of its effects (joined through
  `dgmTypeEffects.csv.bz2`) carries a modifier with
  `func == ItemModifier` and `domain == shipID`;
- that modifier's modified attribute is **479**
  (SDE name `shieldRechargeRate`; Flutter
  `shieldRechargeTime = 479`,
  `dogma_attributes.dart:13` at `ed698d3`; the
  catalogue's `shieldRechargeRate` key, loaded as
  `shield_recharge_rate` —
  `src/names/fitting_types.rs:56-60`);
- its operator is `2`, `4`, or `6` (below);
- the operand — the item type's own `dgmTypeAttributes`
  value for the modifier's modifying attribute — is
  present, finite, and not `0.0`.

The numerator's grounded shape is not restated or
changed: it is #617's, and this slice consumes its
shield layer only (section 4).

**Recharge duration semantics (locked, verified — this
slice's sign trap, the #618 trap on the sibling
attribute).** Attribute 479 is a **duration in
milliseconds**: the time to recharge from empty to full
(SDE `dogmaAttributes.jsonl`: unitID 101 Milliseconds,
`highIsGood` false, `stackable` true). Lower is faster.
The shipped code already depends on this reading:
`ship_base_stats` converts it to `shield_recharge_secs`
(ms / 1000, `src/fitting/ship_stats.rs:84`), and the
base shield peak is `2.5 × C / T` with `T` that duration
(`src/fitting/ship_peak_recharge.rs:24-33, 94-98`).
Flutter's production line is the same shape over
post-modifier values: `2.5 * shieldHp / (shieldRecharge
/ 1000)` guarded by `shieldRecharge > 0`
(`dogma_engine.dart:852, 891-894`). A modifier on 479
therefore scales a duration: an operand below the
identity (a multiplier `< 1.0`, a percent `< 0`) makes
the shield recharge **faster**, and one above makes it
slower. The operand data confirms the reading: every
Shield Recharger and Shield Flux Coil carries multiplier
attribute 134 below 1.0 (Shield Recharger II 0.85, Dread
Guristas Shield Flux Coil 0.69), every Shield Power
Relay and Core Defense Field Purger carries percent
attribute 338 negative (−15.0 to −26.0) — whose only
coherent effect under the locked formula `1 + value/100`
is a shorter duration — and Processor Overclocking Unit
rigs carry 134 *above* 1.0 (1.05/1.10), a slower recharge
trade-off applied as written. Locked consequences
builders must not "fix":

- Percent operands keep their sign. `−20.0` on 479 is
  the factor `0.8`; it is never absolutized, never
  negated, and never read as "+20% recharge rate"
  converted by inversion (`1 / 1.2` is a different
  number and appears in no inspected body).
- Multiplier operands multiply the duration directly.
  Attribute 134's SDE name is
  `shieldRechargeRateMultiplier` with unit 111
  "Inversed Modifier Percent", but the inspected Flutter
  ship route treats operator 4 on attribute 479 as a
  plain multiply of the attribute's millisecond value
  (`routeOwnerModifiers` collects it into the mul
  accumulator; the final loop multiplies). No operand
  is inverted anywhere in this slice, whatever its unit
  is called — the #618 attribute-144 finding verbatim.
- The numerator's direction is the ordinary #617 one
  (adds add hit points, multipliers above 1.0 grow them,
  flux coils' 0.85 shrinks them). Both inputs use the
  *same* arithmetic; only the physical reading of the
  duration differs, and that reading is already fixed
  by the peak code the result feeds.

**Supported operations (locked, with evidence).**
Design-censused over the committed data, category-7
`ItemModifier`/`shipID` modifiers on 479 exercise
exactly two operator codes today, and the slice grounds
the same three-code set as every sibling family — each
code grounded in the inspected Flutter ship path
(`routeOwnerModifiers` routes `ItemModifier`/`shipID`
by operator into add/mul/percent accumulators; the final
ship loop composes them; `dogma_engine.dart:25-34,
109-110, 534-575` and the final composition loop at
`ed698d3`):

- **Operator 2, modAdd — flat add.** Flutter
  `_modAdd = 2`. Census: **no category-7 carrier**
  exercises it on 479 in this SDE snapshot (the one
  ship-path operator-2 effect on 479, effect 3856
  `(479 ← 479)`, appears only on unpublished category-17
  subsystem rows). Grounded and emitted if present —
  exactly the #618 treatment of operator 2 on attribute
  55, which likewise has no category-7 carrier — never
  invented for rows that lack it.
- **Operator 4, postMulAlt — multiplier.** Flutter
  `_postMulAlt = 4`, one of `_isMul`. Census:
  (479 ← 134 `shieldRechargeRateMultiplier`) on 63
  applicable types, operands in [0.69, 1.10] (shield
  rechargers 0.84–0.90 and shield flux coils 0.69–0.81
  via effect 50; power diagnostic systems 0.915–0.95;
  Reactor Control Unit I at exactly 1.0 — present,
  non-zero, therefore emitted, the #617 identity rule;
  Processor Overclocking Units 1.05/1.10 via effect
  4911 — a *slower* recharge, applied as written).
- **Operator 6, postPercent — percent.** Flutter
  `_postPercent = 6`, chaining `1 + value/100`. Census:
  (479 ← 338 `rechargeratebonus`) on 14 applicable
  types, operands in [−26.0, −15.0] (Shield Power Relays
  via effect 5461; Core Defense Field Purger rigs via
  effect 486 at −20.0/−25.0, slot effect 2663).

Every applicable category-7 carrier today has **at most
one applicable entry** on 479, no carrier has a
duplicated (modified, modifying, operator) triple, and
no carrier is mixed-classification on 479. Section 3
locks those as fail-loud generator invariants, not as
silent assumptions.

**Unsupported operations (locked: counted, never
guessed).** No category-7 shield recharge carrier in
the committed data uses any operator outside {2, 4, 6}.
Operators `0` (postMul) and `3` (modSub) are defined by
Flutter for the ship path in general, but no 479
carrier, fixture, or test in any inspected body
exercises them on 479; operator `5` appears in the zip
exactly once toward 479 (effect 12767, `(479 ← 6057)`)
on zero types; operators `-1, 7, 9` have no ship-path
meaning in Flutter at all (the route falls through to
`unsupportedOperators++`). This slice therefore grounds
exactly {2, 4, 6} — supported operators come from census
and Flutter-route evidence only: any other operator with
a present, non-zero operand is classified
**unsupported** by the generator (section 3: marks the
type unapplied in this family, emits no entry) and
guarded the same way at runtime (section 4). The same
counted-not-applied treatment covers every shape outside
the grounded one: any other `func` or `domain` (the
zip's eight rows touching 479 are seven
`ItemModifier`/`shipID` plus one
`OwnerRequiredSkillModifier`/`charID`; there are no
`Location*`/`Owner*`/`structureID` rows on 479), and
carriers outside category 7 — skill carrier 3416 Shield
Operation (category 16) and seven category-20 implants
(3088/3089/3092/13263/16248/27107/32255, the Zainou
'Gnome' SP-90x family, all via effect 486) — there are
**no** category-6 ship-trait carriers on 479 — gain no
emission (section 9 defers each by name). The two
remaining shipID effects, 3856 (operator 2) and 6043
(operator 6, `(479 ← 1516)`), appear only on unpublished
category-17 subsystem rows and so have no published
carrier of any category.

**Census (locked counts).** Scripted over the committed
data (zip `modifierInfo` ⋈ `dgmTypeEffects` ⋈
`dgmTypeAttributes` ⋈ the current catalogue, category 7
only, the four-way classification of section 3): **103
carrier types** on (479, `ItemModifier`/`shipID`) →
**77 applicable** (77 entries: 63 operator-4, 14
operator-6, 0 operator-2), **26 absent-only** (the
Capacitor Power Relay / Capacitor Flux Coil family —
506, 509, 1246, 1248, 1445, 1447, 8133, 8135, 8175,
8177, 14144, 14146, 15080, 15082, 15084, 15086, 15088,
15090, 15092, 15094, 15437, 17510, 17528, 23894, 23896,
28532 — whose (479 ← 134) operand has no cache row; the
same 26-type set whose (263 ← 146) operand is absent in
the hit point census), 0 zero-only, 0
unsupported-only. The 26 absent-only types are the
shield-recharge marked-unapplied set. For scale, the
same-method sibling counts: 479's 103 carriers mirror
attribute 55's 103 carriers, but where 55 is 103/103
applicable with an empty unapplied set, 479 is
77 applicable / 26 marked — the marked set is real on
this attribute and its count line will render on real
fittings (section 8 Oracle 7). Cross-family rows are
the norm, not the exception, and are why classification
stays per family in every leg: Shield Flux Coils carry
an applicable hit point entry and an applicable shield
recharge entry on one row (1256: `[[263, 4, 0.85]]` and
`[[479, 4, 0.7]]`); Shield Power Relays carry a capacitor
recharge entry and a shield recharge entry (2331:
`[[55, 4, 1.3]]` and `[[479, 6, -20.0]]`); Power
Diagnostic Systems and Reactor Control Units carry all
four families (263, 479, 482, 55); Capacitor Power Relay
I 1445 is unapplied in three families at once (hit
point, capacitor capacity, shield recharge) while
applicable in capacitor recharge. Only Shield Rechargers
(393, 394, 6485, 37805), Core Defense Field Purgers (8
rigs), and Processor Overclocking Units (8 types) are
479-only rows; today they carry no modifier keys at all,
and 479 has no key in the catalogue yet. Total
category-7 types in the catalogue: 3925; every carrier
has slot effects.

**Arithmetic (locked, Flutter ship path verbatim).** For
attribute 479, exactly as the siblings compute each of
their attributes:

```text
bonused duration (ms) = (base (ms) + Σ operator-2 operands)
                        × Π operator-4 operands
                        × Π (1 + operator-6 operand / 100)
```

Sources: operator codes `_modAdd = 2`, `_postMulAlt = 4`
(one of `_isMul`), `_postPercent = 6`
(`dogma_engine.dart:25-34, 109-110`); the
`ItemModifier`/`shipID` route summing adds, collecting
muls and percents (`routeOwnerModifiers`); the final
ship composition `value = (base + Σ adds) × Π mul ×
chain(percent)`. The numerator's arithmetic is #617's,
unchanged. Locked consequences builders must not
"improve":

- **No stacking penalty on 479, in any class.** Verified
  from the inspected body, never assumed: Flutter's
  `_percentChain` applies `getStackingPenalty` only
  when the attribute is in `_nonStackableAttributes`,
  which is exactly the twelve resonances
  (`dogma_engine.dart:115-128, 167-179`); 479 is not in
  that set (the SDE row's `stackable: true` agrees), so
  every shield recharge percent factor uses penalty
  `1.0` — the #617/#618 finding, re-verified for this
  attribute. Two Core Defense Field Purger I rigs give
  duration `× 0.8 × 0.8` (section 8 pins it).
  `resistance_stacking_penalty` and `percent_chain` are
  never called on this path.
- **Order is adds, then mul, then percent**, per
  attribute, the siblings' locked association. Flutter
  additionally folds a known-skill percent for Shield
  Operation into the same chain after modules
  (`(3416, shieldRechargeTime, -0.05)` in its skill
  table); skills are out of scope here (section 9), so
  nothing else enters the chain.
- **Bonuses can slow the recharge, shrink the numerator,
  and nothing clamps.** 479 multipliers run up to 1.10
  and the #617 numerator can shrink (flux coils), so the
  bonused peak can be *below* base. A computed bonused
  duration that is negative or non-finite is no data
  (section 4); a bonused duration of exactly `0.0` is a
  real zero at the helper level but unusable for a peak
  — the coupled consumer rejects it and the block goes
  `Unavailable` (sections 4–5), because the peak divides
  by it. A bonused shield hit point value of exactly
  `0.0` is a real zero that yields an honest `0.0 HP/s`
  peak when the duration is positive — the shipped
  `peak_rate` guard table's asymmetry (zero capacity
  renders, zero duration omits), inherited, not new.
  On today's operands (muls in [0.69, 1.10], percents in
  [−26.0, −15.0], no adds) a non-positive bonused
  duration is unreachable from a usable base at any sane
  quantity; the rule exists for fixtures, hostile
  quantities, and future data (section 8 pins each
  route to it).
- **Positive subnormal is no data — the `2ac348f` guard,
  on both inputs from day one.** `bonused_capacitor`
  rejects a positive subnormal result as stall residue
  from a hostile-quantity run underflowing toward zero
  (`src/fitting/ship_resistances.rs:785-791`, commit
  `2ac348f`), keeping exact `0.0` as a real zero. The
  shield path applies the identical predicate —
  `v.is_finite() && *v >= 0.0 && (*v == 0.0 ||
  v.is_normal())` — to the bonused duration inside the
  new helper and to the bonused shield hit points at
  the coupled consumer (section 4). The numerator needs
  the consumer-side form because #617's helper predates
  the guard (`ship_resistances.rs:580` filters only
  finite `>= 0.0`) and this slice does not change that
  helper's behaviour for its EHP caller. A subnormal
  duration would otherwise produce a huge or
  void peak through the division, and a subnormal
  numerator a tiny fake peak; both become no-data here.
- **Absent base is never resurrected — the house
  divergence from Flutter, named again.** An absent,
  negative, or non-finite base shield hit point value
  or base shield recharge duration makes that bonused
  input `None` however many bonuses target it; an
  extender never invents shield hit points and a
  recharger never invents a duration on a hull without
  the data. A *present* `0.0` base is a real zero and
  bonuses apply to it normally at helper level
  ((0 + adds) × …).
- **Units stay catalogue units through the helpers.**
  Bonused shield hit points are HP (#617); bonused
  shield recharge is **milliseconds** (the base field's
  unit), converted to seconds only where the base path
  converts (section 4). No consumer bonusing in
  seconds: a percent or multiplier is unitless so the
  choice is invisible except for float association, and
  section 4 locks the association that keeps empty
  fittings bit-exact against base.
- **No module state**, as #615 locked: every counted
  fitted item contributes as if active. That assumption
  is user-visible wording in the new block (section 7).

## 3. Catalogue extension (locked)

The bundled catalogue gains per-type shield recharge
modifier entries through its existing generator only,
mirroring #617 section 3 (the single-family shape) in
every particular this section does not state.
Hand-editing the JSON is forbidden. Catalogue today:
3,874,268 bytes, sha256
`11accfe2b941d2c86e7138d996347d63fb92c868a1644ff78c5828c0c0142c24`
(`assets/sde/fitting_types.json`, re-hashed at design
time).

**Generator changes**
(`scripts/sde/generate_fitting_types_sde.py`). The
shield recharge leg reuses the inputs the resistance
leg already reads — `dogmaEffects.jsonl` from the
committed zip (fail-loud if missing or unreadable,
lines 1589–1626), `dgmTypeEffects`,
`dgmTypeAttributes`, and the category map — extending
the wanted-modifying-ids set to the shield recharge
modifying attributes so one operand pass serves all
legs (lines 1627–1660; the operand-label helper at
lines 1670–1680 gains a "shield recharge modifier
operand" label for ids wanted by this leg alone, the
same way it gained the hit point and capacitor ones;
ids wanted by more than one leg keep the generic
label). No second zip read; the generator still never
downloads; the header comment (lines 135–172) gains the
shield recharge keys after the capacitor paragraph.

- Beside `CAPACITOR_MODIFIER_ORDER` (line 290), add the
  locked constants with a provenance comment citing
  `dogmaEffects.jsonl`, the caches, and Flutter
  `dogma_engine.dart` at `ed698d3` for the operator
  codes and the absent/zero skip, and naming 479 a
  millisecond duration, lower is faster (section 2):

  ```python
  SHIELD_RECHARGE_MODIFIER_ORDER = [479]
  SHIELD_RECHARGE_MODIFIER_OPERATORS = {2, 4, 6}
  SHIELD_RECHARGE_MODIFIER_ATTRS = {479}
  ```

  The order list has one attribute because the family
  has one attribute — it exists so the leg's emission
  sort and catalogue-wide invariant read in the sibling
  shape, not to suggest a second attribute is pending;
  the operator set is section 2's grounded three.
- Build **one** per-type entry map beside
  `capacitor_recharge_modifiers_by_type` —
  `shield_recharge_modifiers_by_type` (modified 479) —
  classifying every `ItemModifier`/`shipID` modifier on
  479, category-7 types only, deduplicated by
  (modified, modifying, operator), as exactly one of
  (the #615 four-way classification, single-family form
  as in #617 — with one attribute, per-type and
  per-family are the same predicate, so the #618
  two-family split does not arise):
  - **applicable**: operator in {2, 4, 6} and operand
    present, finite, and not `0.0` → an emitted entry;
  - **unsupported**: operator outside {2, 4, 6} and
    operand present and not `0.0` → no entry; marks the
    type unapplied (zero types today);
  - **zero**: operand present and exactly `0.0` → no
    entry, no mark (provably no bonus; zero types
    today);
  - **absent**: operand not in the cache for this type →
    no entry; marks the type unapplied **only if the
    type ends with no applicable entry and no zero
    classification** (the #615 predicate; the 26
    absent-only types of section 2).
- Loud failures, house style (`fail(...)`, writes
  nothing), mirroring the capacitor recharge leg (lines
  1954–2025): an unparseable or non-finite operand
  value on a classified modifier; a duplicated
  (modified, modifying, operator) triple on one type;
  two applicable entries on one type (in a
  single-attribute family: two applicable entries at
  all, i.e. sharing the modified attribute 479). All
  are zero on today's data (censused). Messages say
  "shield recharge modifier", never "capacitor
  modifier", "hit point modifier", or "resistance
  modifier". Deliberately **not** failures: operand
  values outside today's observed ranges (a negative
  add, a multiplier at or below `0`, a percent at or
  below −100 — arithmetic the locked formula defines
  and the pure layer guards, section 4), absent
  operands, and zero operands.
- **Emission (locked shape).** Additive and sparse,
  category 7 only, all existing keys byte-stable and
  every non-category-7 row byte-identical to today. A
  carrier type emits `shieldRechargeModifiers` iff it
  has at least one applicable entry **or** is marked
  unapplied. The value is a JSON array of
  `[modifiedAttributeId, operator, operand]` triples
  (numbers, compact separators; today at most one
  triple per type, its modified id 479), with the
  operand baked in at generation time — the modifying
  attribute id is deliberately not emitted, for the
  #615 reason. A type marked unapplied additionally
  emits `shieldRechargeModifiersUnapplied: true` beside
  the (possibly empty) array. An all-zero carrier emits
  **neither key**. The full unapplied predicate
  (locked): a category-7 type with at least one
  `ItemModifier`/`shipID` modifier on 479 is marked iff
  (a) any such modifier classed unsupported, or (b) it
  has no applicable entry, no zero classification, and
  at least one absent classification. Today that marks
  exactly **26 types**, all empty-array. The Capacitor
  Power Relay I row 1445 is the shape to hold in mind:
  it already emits `hitPointModifiers: []` with its
  unapplied marker, `capacitorCapacityModifiers: []`
  with its marker, and `capacitorRechargeModifiers:
  [[55, 4, 0.8]]`, and now also gains
  `shieldRechargeModifiers: []` with
  `shieldRechargeModifiersUnapplied: true` — four
  families judged independently on one row. Key
  placement is immediately after the capacitor modifier
  block (lines 3198–3209, before `types.append(entry)`),
  in the order `shieldRechargeModifiers`,
  `shieldRechargeModifiersUnapplied`, so pre-existing
  key order on every row is untouched, and a row like
  1537 carrying every family emits resistance (none),
  hit point, capacitor capacity, capacitor recharge,
  then shield recharge keys.
- **Self-validation.** One oracle list beside
  `CAPACITOR_RECHARGE_MODIFIER_ORACLES` (line 763), same
  tuple shape `(type_id, expected_entries_or_None,
  expected_unapplied)` where `None` means neither new
  key may be present. Values are cache/zip reads from
  the section 2 census (section 8 gives the arithmetic
  they feed):
  - `SHIELD_RECHARGE_MODIFIER_ORACLES`:
    - 393 Shield Recharger I: `[[479, 4, 0.9]]`; 394
      Shield Recharger II: `[[479, 4, 0.85]]`; 6485 M51
      Benefactor Compact Shield Recharger:
      `[[479, 4, 0.875]]`; 37805 Republic Fleet Shield
      Recharger: `[[479, 4, 0.84]]` (the recharger
      multiplier pins).
    - 37825 Dread Guristas Shield Flux Coil:
      `[[479, 4, 0.69]]` (the fastest operand); 1256
      Shield Flux Coil II: `[[479, 4, 0.7]]`; 1537
      'Basic' Power Diagnostic System:
      `[[479, 4, 0.95]]`; 1541 Power Diagnostic System
      II: `[[479, 4, 0.915]]`; 1353 Reactor Control Unit
      I: `[[479, 4, 1.0]]`, false (multipliers below
      1.0 through the identity pin).
    - 4395 Medium Processor Overclocking Unit I:
      `[[479, 4, 1.05]]`; 4399 II: `[[479, 4, 1.1]]`
      (the slower-than-base pins — above 1.0 is applied,
      never clamped).
    - 1419 'Basic' Shield Power Relay:
      `[[479, 6, -15.0]]`; 2331 Shield Power Relay I:
      `[[479, 6, -20.0]]`; 1422 Shield Power Relay II:
      `[[479, 6, -25.0]]`; 37820 Caldari Navy Shield
      Power Relay: `[[479, 6, -26.0]]` (the
      negative-percent pins — the sign is the test).
    - 26084 Large Core Defense Field Purger I:
      `[[479, 6, -20.0]]`; 26450 II:
      `[[479, 6, -25.0]]` (the rig percent pins).
    - 1445 Capacitor Power Relay I and 509 'Basic'
      Capacitor Flux Coil: empty array, unapplied true
      (the absent-134 pins — both rows keep their other
      families' keys exactly as today).
    - 3831 Medium Shield Extender II: neither key (a
      hit-point-only carrier; the numerator side of
      section 8's extender oracles); 2048 Damage
      Control II: neither (non-carrier); 587 Rifter
      (category 6), 3416 Shield Operation (category 16),
      3088 Zainou 'Gnome' Shield Operation SP-902
      (category 20), and 45623 Legion Core - Augmented
      Antimatter Reactor (category 32): neither (the
      category-gate pins — the skill and implant rows
      carry a real (479 ← 338) triple with a present
      operand and gain nothing, section 9).
- **Catalogue-wide invariants** beside the capacitor
  recharge checks (oracle/count validation after line
  3575 and the per-row invariant pass after the
  capacitor recharge block near line 3926): every
  present `shieldRechargeModifiers` value is on a
  category-7 row; its entries' modified id is 479,
  operators in {2, 4, 6}, operands finite and not
  `0.0`, no duplicate modified id;
  `shieldRechargeModifiersUnapplied` appears only
  beside `shieldRechargeModifiers` and only as `true`;
  the counts equal the census values for today's data,
  as named constants in the `CAPACITOR_*_MODIFIER_ROWS`
  pattern (lines 784–791): **103 rows with the key**
  (77 with entries plus 26 marked-empty), **26 marked,
  77 entries** (`SHIELD_RECHARGE_MODIFIER_ROWS`,
  `SHIELD_RECHARGE_MODIFIER_NONEMPTY_ROWS`,
  `SHIELD_RECHARGE_MODIFIER_MARKED_ROWS`,
  `SHIELD_RECHARGE_MODIFIER_ENTRIES`). The summary
  print (beside lines 4791–4795) gains those counts.
- Determinism unchanged: types sorted by `typeId`,
  compact separators, trailing newline, no timestamps.
  Proof obligations for the catalogue commit (section
  8): run the generator twice → identical sha256; strip
  the two new keys from the regenerated file →
  byte-identical to today's `11accfe2…`. Both proofs
  are run once and reported in the commit body, not
  committed as scripts.

**Size budget.** A simulation of the locked emission
over the census shape (103 keyed rows — 77 with one
triple each, 26 marked-empty — compact separators, the
key names above; an entry fragment
`,"shieldRechargeModifiers":[[479,4,0.915]]` is 42
bytes, a marked fragment
`,"shieldRechargeModifiers":[],"shieldRechargeModifiersUnapplied":true`
is 69 bytes at the longest operand shape censused) adds
≈5,300 bytes (≈ +0.14%). Budget: the regenerated file
must land within **+8,000 bytes** of today's 3,874,268;
the catalogue commit body states the exact new byte
count. Anything over budget means the emission rule
drifted (for example emitting zero operands, marking
non-absent types, or emitting on non-category-7 rows)
and stops the slice for review. The identity (`1.0`)
operator-4 entry (Reactor Control Unit I and kin) is
inside the estimate and stays emitted, for the #617
reason.

**Rust loader** (`src/names/fitting_types.rs`).
`FittingType` gains, immediately after the two capacitor
recharge modifier fields (lines 143–146), in the
capacitor fields' comment style:

```rust
#[serde(rename = "shieldRechargeModifiers", default)]
pub shield_recharge_modifiers: Option<Vec<ShieldRechargeModifier>>,
#[serde(rename = "shieldRechargeModifiersUnapplied", default)]
pub shield_recharge_modifiers_unapplied: bool,
```

with **one** new struct in the same module beside
`CapacitorModifier` (line 473),
`ShieldRechargeModifier { pub modified_attribute_id: i64, pub operator: i64, pub operand: f64 }`,
deserialized from the 3-element array by the same
manual tuple impl. A new struct, deliberately, not a
reuse of `CapacitorModifier`: that struct's locked
meaning is the capacitor families (482/55) of one
slice, and every earlier slice boundary has its own
triple struct (`ResistanceModifier`,
`HitPointModifier`); reusing the capacitor name for a
shield duration would misname every invariant and call
site in this slice. Its doc comment pins the semantics:
entries are generation-time-proven
`ItemModifier`/`shipID` shield recharge bonuses on
attribute 479 with the operand baked in (operator 2 is
modAdd, 4 is postMulAlt, 6 is postPercent); attribute
479 is a millisecond duration, lower is faster (this
document section 2); `Some(empty)` with the unapplied
flag is a carrier whose shield recharge bonus the
bundled data cannot ground and must be counted, never
read as "no bonus"; `None` is a non-carrier or an
all-zero carrier. `#[serde(default)]` keeps old assets
and `from_json` fixtures loading as `None`/`false`.
Nothing is validated at load (the pure function guards
values, section 4; the invariants test proves the
shipped asset).

**Invariants to add** to `bundled_catalogue_invariants`
(`src/names/fitting_types.rs`), beside the capacitor
blocks (per-row checks in the shape of lines 1602–1640;
counts and spot pins after the capacitor recharge
counts at lines 2765–2792), all over the real bundled
asset: `shield_recharge_modifiers` is `Some` only on
category-7 rows; exactly 103 rows carry it, 77
non-empty, 26 marked unapplied, 77 entries total; every
entry's modified id is 479 with no duplicate modified
id per row, operator is 2, 4, or 6, operand finite and
`!= 0.0`; the unapplied marker appears only beside
`Some`; spot pins mirroring the generator oracles (393,
394, 37825's `[[479, 4, 0.69]]`, 1353's
`[[479, 4, 1.0]]`, 4399's `[[479, 4, 1.1]]`, 2331's
`[[479, 6, -20.0]]` beside its shipped
`capacitorRechargeModifiers: [[55, 4, 1.3]]`, 26084's
`[[479, 6, -20.0]]`, 1256's `[[479, 4, 0.7]]` beside its
shipped `hitPointModifiers: [[263, 4, 0.85]]`, 1537's
`[[479, 4, 0.95]]` beside its shipped hit point and both
capacitor families, 1445 empty-with-flag beside its
three shipped families unchanged, 509 empty-with-flag,
3831 / 2048 / 587 / 3416 / 3088 / 45623 `None` with flag
false). The existing invariants pass unmodified.

## 4. Pure API (locked)

Two crate-internal helpers are consumed, not one new
computation: the numerator comes from the shipped
`bonused_hit_points`, read once, and the denominator
from **one new dedicated helper** for the single
attribute 479. A generalized helper spanning all
families is rejected, for the siblings' stated reasons:
`bonused_hit_points` (three layers, no excluded count),
`bonused_capacitor` (two families with per-family
counted flags plus its own excluded count), and this
helper (one family plus its own excluded count) differ
exactly in the dimensions a generic signature would
have to parameterize, and refactoring the shipped
helpers onto a shared engine would put every #617/#618
literal in the regression gate at risk for no behaviour
this slice needs. What is shared is what the siblings
already share — `counted_flag`
(`src/fitting/ship_resistances.rs:250`) and
`mul_product` (`:264`) — reused, never forked; the
per-slice scan beside them is the established shape.

**Numerator — no recomputation (locked).** Shield hit
points are `bonused_hit_points(fitting,
catalogue).hit_points[0]` — `HIT_POINT_ORDER =
[263, 265, 9]` position 0 (`ship_resistances.rs:207,
235-236`), computed by the shipped helper
(`:483-586`) under #617's locked rules. This slice adds
no second shield-hit-point arithmetic anywhere: the
bonused shield HP that feeds EHP and the bonused shield
HP that feeds this peak are the same call on the same
fitting (the public function below calls the helper
exactly once), so the two blocks cannot diverge. The
hit-point unapplied count is likewise
`BonusedHitPoints::hit_point_unapplied_modules`,
verbatim — including its whole-dimension meaning (a
carrier unapplied on any of 263/265/9 counts there;
section 6 discloses it as written and section 8 pins
the consequence). `bonused_hit_points` is not edited in
this slice: its result filter (`:580`) and every EHP
literal stay exactly as shipped. The one consumption
rule this slice adds is the consumer-side subnormal
rejection of section 2, applied below to
`hit_points[0]` only.

**Bonused shield recharge duration helper**
(`src/fitting/ship_resistances.rs`, beside
`bonused_capacitor` — that module owns the counted-item
scan and bounded arithmetic all helpers share, the
#617/#618 placement argument). No new module. Names are
part of the lock:

```rust
/// Bonused shield recharge duration (milliseconds, the
/// catalogue unit; lower is faster) plus the
/// fitted-module counts the caller must disclose beside
/// any number derived from it.
pub(crate) struct BonusedShieldRechargeDuration {
    /// Bonused shield recharge duration in raw
    /// milliseconds; `None` exactly where the base
    /// value is absent, negative, or non-finite, or
    /// the bonused result is negative, non-finite, or
    /// a positive subnormal.
    pub recharge_ms: Option<f64>,
    /// Counted fitted rows with no catalogue row at
    /// all, so no hit point or shield recharge bonus
    /// can be proven or disproven for them, in quantity
    /// units. Same definition and source predicate as
    /// `BonusedResonances::excluded_modules` (pinned
    /// equal, section 8).
    pub excluded_modules: usize,
    /// Shield-recharge-dimension count: counted fitted
    /// rows the catalogue marks as shield recharge
    /// carriers whose bonus cannot be applied, in
    /// quantity units. Never summed with any other
    /// dimension's count.
    pub shield_recharge_unapplied_modules: usize,
}

/// `None` only when the ship gate fails (`ship_type_id
/// <= 0`, no catalogue row, or the row is not category
/// 6). Otherwise `Some`, with `recharge_ms` as
/// documented on the field.
pub(crate) fn bonused_shield_recharge_duration(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> Option<BonusedShieldRechargeDuration>;
```

Locked helper semantics, mirroring `bonused_capacitor`
(lines 620–799) reduced to one attribute:

- **Ship gate and base.** The gate is the siblings'
  verbatim. The base is the ship row's
  `shield_recharge_rate` (**raw milliseconds**, never
  converted in the helper), under the same usability
  filter shape (present, finite, `>= 0.0`; present
  `0.0` is a real zero at this level). A new private
  constant beside `CAPACITOR_ORDER` names the single
  modified attribute
  (`SHIELD_RECHARGE_MODIFIED_ATTRIBUTE_ID: i64 = 479`);
  with one attribute there is no accumulator index, so
  the run lists are scalar `Vec<(f64, u64)>` triples
  (add/mul/percent), not arrays-of-one — imitating the
  multi-attribute array shape would add a dimension
  this family does not have.
- **Counted scan.** Identical item predicate and
  quantity-units handling to the siblings (`type_id >
  0`, positive quantity, `counted_flag`,
  `usize::try_from`, saturating adds). It reads
  `shield_recharge_modifiers` /
  `shield_recharge_modifiers_unapplied` per row with
  the once-per-item `counted_unapplied` pattern: the
  catalogue unapplied flag counts the item's units
  once; an entry whose modified id is not 479, whose
  operator is outside {2, 4, 6}, or whose operand is
  non-finite or `0.0` counts the item once (if not
  already counted) and is skipped — applicable entries
  on the same item are still applied. No other family's
  fields are read: a hit point or capacitor defect on
  the same row never counts here.
- **Excluded count — the `bonused_capacitor`
  divergence, restated.** `bonused_hit_points` counts
  no excluded rows because its EHP caller takes the
  shared count from `bonused_resonances` in the same
  call. This slice's public caller calls
  `bonused_hit_points` and this helper — neither
  supplies an excluded count — so this helper counts
  counted rows with no catalogue row into its own
  `excluded_modules`, under the identical predicate and
  units as `bonused_resonances` and `bonused_capacitor`
  — pinned equal to both in tests (section 8), so the
  shared definition cannot drift. It is a *shared*
  count in meaning (a catalogue-absent row can prove no
  bonus in any dimension), disclosed once per block in
  each block that shows it, never summed across blocks
  (#616 section 6, inherited).
- **Run accumulation and bounded arithmetic.** Three
  run lists grouped by exact `==` operand value with
  saturating `u64` counts in first-seen order
  (operator-2 → `add_runs`, operator-4 → `mul_runs`,
  operator-6 → `percent_runs`), composed in the
  siblings' exact association:

  ```text
  add_total     = Σ over add runs of operand × (count as f64)
  mul_total     = Π over mul runs of mul_product(operand, count)
  percent_total = Π over percent runs, sorted by |value|
                  descending, of mul_product(1.0 + value / 100.0, count)
  bonused       = (base + add_total) × mul_total × percent_total
  ```

  `mul_product` is reused, not forked; **no stacking
  penalty** (section 2), so `percent_chain` is not
  called. The result is `Some(bonused)` filtered by the
  `2ac348f` predicate verbatim —
  `v.is_finite() && *v >= 0.0 && (*v == 0.0 ||
  v.is_normal())` — with the sibling's explanatory
  comment adapted in the same edit: a positive
  subnormal is stall residue, no data; an exact `0.0`
  stays a real zero (the coupled consumer rejects it
  for the peak, below). A hostile quantity can
  therefore only yield the formula's own finite
  non-negative normal value, an exact `0.0`, or `None`
  — never a hang, never infinity, never a subnormal
  duration passed downstream (section 8 pins each
  class, with the helper result asserted, never
  discarded).
- **Identity (locked, exact).** With no applicable
  entry and a base that is exact `0.0` or normal, the
  bonused duration is `(base + 0.0) × 1.0 × 1.0` — the
  base, equal under `==`; an identity `1.0` multiplier
  (1353) likewise changes nothing bit for bit. The
  qualification matters only off-catalogue: a fixture
  base that is itself a positive subnormal passes the
  usability filter but is then rejected by the result
  filter above, exactly as `bonused_capacitor` treats
  it (the filter has no access to which factor produced
  the subnormal, and inventing one would be a second
  rule). Catalogue durations are integral milliseconds,
  so every identity set in section 8 uses normal bases
  and the claim there is unconditional.
- The helper is `pub(crate)`, never re-exported from
  `src/fitting/mod.rs`. The `ship_resistances.rs`
  module header gains a short paragraph naming it as
  the shield recharge sibling serving the bonused
  shield peak block under this document, and its
  `bonused_hit_points` paragraph is revised (section
  7). No logging is added.

**Bonused peak wrapper** (`src/fitting/ship_peak_recharge.rs`).
The bonused shield peak is the existing guarded formula
at bonused inputs, exposed like #618's capacitor
wrapper without inventing a second peak API:

```rust
/// Shield peak recharge in HP/s for one (shield hit
/// points, recharge duration in seconds) pair under
/// the shipped guards (`peak_rate` with
/// `SHIELD_PEAK_FACTOR`): `None` unless capacity is
/// finite `>= 0`, recharge is finite `> 0`, and the
/// rate is finite.
pub(crate) fn shield_peak_recharge(
    capacity: Option<f64>,
    recharge_secs: Option<f64>,
) -> Option<f64>;
```

`ship_base_peak_recharge` is refactored to call it for
its shield field (its capacitor field already calls
`capacitor_peak_recharge`, lines 99–102); its behaviour
and tests are unchanged in every byte. The rejected
alternative — building a modified `ShipBaseStats` copy
and reading
`ship_base_peak_recharge(&copy).shield_hp_per_sec` — is
#618's rejected alternative for the same reason: it
would couple the bonused path to six fields it does not
use and invite a reader to treat the copy as bonused
base stats. The wrapper names exactly the pair it
consumes and is `pub(crate)`, never re-exported
(`capacitor_peak_recharge` precedent, `mod.rs:49`).

**Bonused shield peak recharge (public)**
(`src/fitting/ship_peak_recharge.rs` — the quantity's
own module, as the bonused capacitor function's module
is the capacitor stability one). Shapes mirror
`BonusedShipEhp` / `BonusedShipEhpOutcome`
(`src/fitting/ship_ehp.rs:77-105`), the house shape for
a bonused quantity with no verdict enum:

```rust
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BonusedShieldPeakRecharge {
    /// Peak passive shield recharge in HP/s from
    /// bonused shield hit points over bonused shield
    /// recharge duration. A plain `f64`: an `Available`
    /// result always carries the peak it exists to
    /// show, including an honest `0.0` from a real-zero
    /// bonused numerator over a positive duration.
    pub shield_hp_per_sec: f64,
    /// Counted fitted rows with no catalogue row at
    /// all, from `bonused_shield_recharge_duration`.
    /// Same definition, units, and source predicate as
    /// `BonusedShipEhp::excluded_modules` (pinned
    /// equal, section 8).
    pub excluded_modules: usize,
    /// Hit-point-dimension count, verbatim from
    /// `bonused_hit_points`. Whole-dimension (any of
    /// shield/armor/hull), as that helper defines it;
    /// never summed with
    /// `shield_recharge_unapplied_modules`.
    pub hit_point_unapplied_modules: usize,
    /// Shield-recharge-dimension count, from
    /// `bonused_shield_recharge_duration`. Never summed
    /// with `hit_point_unapplied_modules` or any
    /// resistance/capacitor count.
    pub shield_recharge_unapplied_modules: usize,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BonusedShieldPeakRechargeOutcome {
    Available(BonusedShieldPeakRecharge),
    /// The ship gate failed, or either bonused input is
    /// absent, negative, non-finite, or a positive
    /// subnormal, or the bonused shield recharge
    /// duration is zero, or the peak rate is
    /// non-finite, so no honest number exists.
    Unavailable,
}

pub fn ship_shield_peak_recharge_with_module_bonuses(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> BonusedShieldPeakRechargeOutcome;
```

Re-exports from `src/fitting/mod.rs` gain exactly the
three new names beside line 49
(`ship_shield_peak_recharge_with_module_bonuses`,
`BonusedShieldPeakRecharge`,
`BonusedShieldPeakRechargeOutcome`); the wrapper and
both helpers stay unexported. Locked semantics, stated
in full:

- **Inputs, by construction.** The function calls
  `bonused_hit_points` once and
  `bonused_shield_recharge_duration` once and reads no
  catalogue field and no fitting item itself. Either
  helper returning `None` (the shared ship gate — both
  fail together) → `Unavailable`.
- **Numerator consumption (locked).** The shield hit
  points fed to the peak are
  `hit_points[0].filter(|v| v.is_finite() && *v >= 0.0
  && (*v == 0.0 || v.is_normal()))` — the helper's
  value under the `2ac348f` predicate of section 2.
  The finite/non-negative clauses repeat the helper's
  own filter (`:580`) and are restated so the consumed
  predicate is auditable in one place; the
  normal-or-zero clause is this slice's addition. A
  positive subnormal numerator (hostile run residue)
  is no data: `Unavailable`, never a tiny fake peak.
  Exact `0.0` passes and can yield `Some(0.0)` HP/s.
- **Denominator consumption (locked).** The bonused
  duration passes the consumer filter finite and
  `> 0.0` milliseconds — otherwise `Unavailable`. This
  is the gate that makes a duration bonused to `0`
  (fixture percent −100, a present-`0.0` base, a
  hostile run reaching exact `0.0`) **never divide and
  never render**: `shield_peak_recharge` is not called
  with it. Negative and non-finite durations never
  leave the helper at all; the filter restates the
  consumer rule the way the capacitor consumer does
  (`ship_cap_stability.rs:565-566, 579-591`).
- **Conversion association (locked for bit-exact
  identity).** `recharge_secs = bonused_recharge_ms /
  1000.0`; the peak is `shield_peak_recharge(shield_hp,
  Some(recharge_secs))` — the base path's exact
  association (base: `ship_base_stats` divides
  catalogue milliseconds by 1000 at `ship_stats.rs:84`,
  `peak_rate` divides by the seconds value). Computing
  `2.5 × hp × 1000.0 / ms` instead would be equal
  *almost* everywhere and 1-ulp different somewhere,
  breaking the empty-fitting identity below; builders
  must not "simplify" it. (Flutter's `/(shieldRecharge
  / 1000)` is this same association.)
- **Coupled completeness (locked).** Shield peak
  recharge is one quantity of the pair. Helper-`None`,
  unusable, or (for the duration) zero input on
  **either** side → `Unavailable`, with no peak and no
  counts — unlike EHP there is no per-layer partial
  result to show, and unlike the Ship (base values)
  block this block has no other line to render beside
  a missing peak (section 5). Per-input partiality
  still exists and is pinned at the helper level
  (section 8). A non-finite peak *rate* on otherwise
  usable inputs (overflow through `peak_rate`) is also
  `Unavailable`: this block exists to show the peak,
  and an `Available` block with counts and a disclosure
  but no number would be a shell (the capacitor block
  can show a verdict without its peak; there is no
  second figure here).
- **Empty-fitting identity (locked, exact).** For a
  fitting with no applicable entry on either input —
  hull-only, only non-counted items, counted
  non-carriers, identity-`1.0` carriers
  (1353 in both dimensions) — on a hull whose base
  shield peak is `Some`, the outcome is `Available`
  with `shield_hp_per_sec` **equal under `==`** to the
  `shield_hp_per_sec` of `ship_base_peak_recharge` over
  the same fitting's `Available` `ship_base_stats`:
  both helpers' identities make
  the pair bit-equal to base, the conversion
  association is the base path's, and the wrapper is
  the same `peak_rate`. Section 8 pins this with
  `assert_eq` (comparing `Some(bonused.shield_hp_per_sec)`
  to the base `Option` where the shapes need it),
  including on the three demo fittings, none of which
  carries a hit point or shield recharge carrier in a
  counted slot (design-checked against
  `assets/demo/fittings.json` and the census families:
  Demo Brawler's counted rows are 2048/2049/1225/2050/
  2050/1535/28270 — 1535 catalogue-absent, the rest
  non-carriers in both dimensions — so its peak stays
  the base Rifter 1.8 HP/s with `excluded_modules == 1`;
  Mission Runner and Demo Runner counted rows are
  likewise non-carriers with every row in the
  catalogue, peaks 1.8 and 1.4, all counts 0).
- **Count rule (locked, collected).** Three deficit
  counts on `Available`, three definitions, no sums:
  excluded (shared definition, from the duration
  helper), hit-point-unapplied (whole hit-point
  dimension, verbatim from `bonused_hit_points` — a
  counted row unapplied only for armor or hull raises
  it here too, the disclosed consequence of never
  forking the helper's scan; section 8 pins it),
  shield-recharge-unapplied (new dimension). The
  resistance and capacitor counts in their blocks are
  untouched by this slice and are never added to any
  of these, in the API or the UI. Counts exist only on
  `Available`; `Unavailable` carries and renders none —
  the #615/#616 shape for outcome enums.
- **Independence.** Availability keys off the coupled
  bonused pair only; the function never consults
  `ship_base_peak_recharge`'s outcome (beyond sharing
  `peak_rate`), `ship_base_stats` as a gate, resources,
  resistances, EHP, or either capacitor function. Base
  can render while bonused is `Unavailable` (a fixture
  driving bonused duration to `0` on a hull with usable
  base — section 8 pins that split) and bonused EHP can
  be `Available` while this is `Unavailable` (a hull
  with hit points but no shield recharge data) and vice
  versa. The function never panics; there is no error
  channel; nothing logs.

## 5. Completeness and Unavailable rules (locked)

Collected in one place; sections 2 and 4 are normative
and this section adds nothing to them:

- The peak computes only from a complete bonused pair:
  usable base shield hit points and shield recharge
  duration (present, finite, non-negative; present
  `0.0` real at helper level), finite non-negative
  bonused results that are exact `0.0` or normal, a
  bonused duration then `> 0`, and a finite rate.
  Missing data on **either** input is `Unavailable` for
  the whole block — never a peak line, never rendered
  as zero, never filled from the base block's numbers,
  never half-shown. (The one asymmetry is inherited
  from `peak_rate`: a real-zero *numerator* over a
  positive duration is the honest number `0.0 HP/s`
  and renders; a zero *duration* is no data at all.)
- A bonus never resurrects missing base data, in
  either input: absent base shield hit points stay
  `None` under any extender; absent base shield
  recharge duration stays `None` under any recharger.
- A positive subnormal on either input is no data at
  the point it is consumed (duration helper, numerator
  consumer), however it arose; negative or non-finite
  bonused values never leave their helpers. An exact
  `0.0` is a real zero everywhere the helpers speak.
- The block is `Unavailable` — heading plus the
  no-ship-data sentence, no number, no count lines, no
  disclosure — when the ship gate fails
  (`ship_type_id <= 0`, no catalogue row, not category
  6) or either input is unusable under the rules
  above, or the rate overflows; heading plus the
  no-catalogue sentence when the catalogue itself
  failed to load. Unavailable in this block says
  nothing about any sibling block, and vice versa.
- Counts render only beside an `Available` peak.
  Excluded, hit-point-unapplied, and
  shield-recharge-unapplied rows are counted in
  quantity units and disclosed with their own wording
  (sections 4 and 7); nothing fitted is silently
  dropped, nothing missing is silently zeroed, and no
  two counts are ever added together anywhere.

## 6. Display (locked)

One new block, one new renderer in `src/ui/fittings.rs`,
placed immediately after `render_ship_base_stats`
(lines 2345–2368) as one contiguous group — heading and
disclosure constants, the two new count helpers, the
pure line composer, and the renderer — the contiguity
the bonused capacitor block uses (lines 3202–3347).
`render_ship_shield_peak_recharge_with_module_bonuses`
mirrors `render_ship_base_stats` and
`render_ship_ehp_with_module_bonuses` (line 2564) in
shape: no-catalogue arm (heading plus the no-catalogue
sentence), otherwise
`ship_shield_peak_recharge_with_module_bonuses`;
`Unavailable` renders heading plus the no-ship-data
sentence and nothing else; `Available` renders heading,
the block's lines, then the disclosure last. It is
called immediately after `render_ship_base_stats` at
**both** existing call sites — imported detail (line
4012) and saved detail (line 4324) — both in the same
edit; a half-wired slice showing the block on one
surface only is a defect. Reading order is otherwise
unchanged: Ship (base values) — which keeps its base
shield peak line — then this bonused block, then the
resistances blocks (the sibling placement rule: a
bonused block follows the base block its figure derives
from). The block renders even when the bonused peak
equals the base peak, and even when the fitting has no
items, as its siblings do. It depends only on the
fitting and the catalogue, logs nothing, and shows no
raw EVE ID.

Line order in the `Available` arm (locked): the peak
line, then the three count lines that apply —
excluded, hit-point-unapplied, shield-recharge-
unapplied — then the disclosure. The peak line reuses
`ship_stat_line` (line 2305) with the base block's
exact label and unit — `ship_stat_line("Shield peak
recharge", Some(peak), "HP/s")`, i.e. the rendered
template `Shield peak recharge: {amount} HP/s` — as the
bonused capacitor block reuses its base peak label
(`cap_stability_peak_line`); only the input changed,
and the heading carries the bonused qualifier. A new
pure composer,
`ship_shield_peak_recharge_with_bonuses_lines(&BonusedShieldPeakRecharge)
-> Vec<String>`, builds the ordered lines like
`cap_stability_with_bonuses_lines` (it takes the
`Available` payload, so there is no `Unavailable` case
to empty out — the renderer branches on the outcome
enum first, the EHP renderer's shape).

**Count lines — reuse and the no-confusion rule
(locked).** Three lines, three definitions, never
summed, in the locked order above:

- **Excluded** — a new pure helper,
  `bonused_shield_peak_excluded_line(usize) ->
  Option<String>`, `None`-at-0 / singular / plural like
  its siblings, with new wording naming *both* input
  dimensions (section 7). The existing excluded
  wordings cannot be reused: the resistances one names
  only resistance bonuses, the EHP one resistance-or-
  hit-point, the capacitor one capacitor — each would
  understate what a catalogue-absent row cannot prove
  for *this* peak (a hit point bonus or a shield
  recharge bonus). The count value is the shared
  definition, pinned equal to the sibling blocks'
  (section 8); only the sentence is this block's.
- **Hit-point-unapplied** — the existing
  `bonused_ehp_hit_point_unapplied_line` (line 2055)
  reused **verbatim**, string and helper both (the
  #617 EHP block likewise reuses
  `bonused_resistances_unapplied_line` verbatim for its
  resistance dimension). The count is the helper's
  whole-dimension value (sections 4 and 8): one
  authored sentence for one count, shown in the two
  blocks that disclose it, never summed across blocks
  and never relabelled as shield-specific. Its wording
  says "hit point bonus", which is exactly the deficit
  it names; it does not claim every counted row is a
  shield carrier, and this block adds no second,
  shield-only hit point count beside it (that would
  require the forked scan section 4 forbids).
- **Shield-recharge-unapplied** — a new pure helper,
  `bonused_shield_recharge_unapplied_line(usize) ->
  Option<String>`, same shape, for the new dimension,
  placed last (the sibling order: the new dimension's
  line goes after the inherited ones, #617's hit point
  line after resistance, #618's recharge after
  capacity).

No combined "modules not counted" line is added
anywhere. A fitting can legitimately show, for the
same fitted item, an excluded or unapplied line here
and its counterparts in the EHP and capacitor blocks
(Capacitor Power Relay I 1445 does — section 8 Oracle
7): each block discloses the deficit against the
number *it* shows, per-block disclosures of one deficit
are the shipped shape (#616 section 6), and the reader
is never handed a sum to misread as distinct modules.

**No other surface changes.** The Ship (base values)
block keeps its base Shield, Shield recharge, and
Shield peak recharge lines (`ship_base_stat_lines`,
lines 2314–2333) byte-identical; bonused shield hit
points and bonused shield recharge duration are
rendered nowhere as standalone numbers; the bonused EHP
block keeps its lines, counts, and numbers (its
numerator already included shield extenders since
#617 — this slice moves no EHP figure); the active
repair block is untouched. No editor, import,
persistence, or other block changes.

## 7. UI wording (locked verbatim)

New constants in `src/ui/fittings.rs` with the new block
(section 6), with doc comments in the sibling style
pointing at this document. No string calls this number
a "tank", a "simulation", a sustained or average rate,
or a repair rate, none states a charge-level percentage
(no body states one — peak recharge design section
2.2), and none contains a raw EVE ID.

- Heading
  (`FITTINGS_SHIELD_PEAK_RECHARGE_WITH_BONUSES_HEADING`):
  `Shield peak recharge (with fitted module bonuses)`
  — the base line's label ("Shield peak recharge",
  line 2324) promoted to a heading with the sibling
  qualifier, parallel to `Capacitor (with fitted
  module bonuses)`. "Peak" is load-bearing and stays
  (value ranking 1).
- Disclosure
  (`FITTING_SHIELD_PEAK_RECHARGE_WITH_BONUSES_DISCLOSURE`,
  verbatim, always last in the `Available` arm):

> This number adds the fitted modules' and rigs' shield hit point and shield recharge bonuses from Mimir's bundled item data to the base values above. Every fitted module is counted as active, because the fitting data does not say which modules are on. This is the peak of passive shield recharge only: shield boosters and other repair are not included. Ship bonuses, subsystems, skills, implants, and shield changes from anything outside this ship are not applied, so this number can differ from EVE.

  Wording notes (do not rephrase in review): "base
  values above" is true on both surfaces — this block
  immediately follows Ship (base values), whose Shield
  and Shield recharge lines are the two bases named;
  "counted as active" is #615's locked plain form; the
  passive-only sentence is this block's load-bearing
  honesty line, separating the peak from the shield
  boost figures in the Active repair block (which are
  base repair amounts and are not summed with this
  number anywhere); "subsystems" is in the not-applied
  list because non-category-7 shield recharge carriers
  gain no emission even though subsystem slots are
  counted slots (section 9); the singular "this
  number" matches the one derived figure shown (the
  count lines are disclosures, not figures).
- Unavailable sentences (the sibling templates with
  this block's name):
  - `Shield peak recharge with fitted module bonuses unavailable: Mimir's bundled item data failed to load.`
  - `Shield peak recharge with fitted module bonuses unavailable: Mimir's bundled item data has no complete shield hit point and shield recharge data for this fitting's ship.`
- Peak line (section 6 composer, via `ship_stat_line`):
  `Shield peak recharge: {amount} HP/s` — including
  `Shield peak recharge: 0.0 HP/s` for the real-zero
  numerator case (section 5). Display rounding is the
  shared formatter's tenth, unchanged; the stored rate
  stays full-precision.
- Count lines in this block (section 6 helpers):
  - `bonused_shield_peak_excluded_line(1)`:
    `1 fitted module is not in Mimir's bundled item data, so any hit point or shield recharge bonus from it is not counted.`
    Plural: `{n} fitted modules are not in Mimir's bundled item data, so any hit point or shield recharge bonuses from them are not counted.`
  - The hit point unapplied line is
    `bonused_ehp_hit_point_unapplied_line` verbatim:
    `1 fitted module has a hit point bonus Mimir's bundled item data cannot describe, so that bonus is not applied.`
    Plural: `{n} fitted modules have hit point bonuses Mimir's bundled item data cannot describe, so those bonuses are not applied.`
  - `bonused_shield_recharge_unapplied_line(1)`:
    `1 fitted module has a shield recharge bonus Mimir's bundled item data cannot describe, so that bonus is not applied.`
    Plural: `{n} fitted modules have shield recharge bonuses Mimir's bundled item data cannot describe, so those bonuses are not applied.`
  - Zero in any count renders no line for that count.
    (Wording uses "shield recharge bonus", never
    "recharge rate bonus" with a number attached:
    attribute 479 is a duration and no rate figure for
    a single module's bonus exists to print — the #618
    note verbatim.)

**Existing sentences: what becomes false, what does not
(locked).** Every rendered string in every existing
block stays **byte-identical and true of its own
block**; none is edited in this slice:

- The Ship (base values) disclosure (line 1882) — "Fitted
  modules, rigs, subsystems, skills, implants, and ship
  bonuses are not applied" — stays true: that block's
  shield lines stay base. It does **not** gain a
  pointer sentence to the bonused block: it narrates no
  sibling today, and heading adjacency does the
  pointing (#618's deliberate non-change for its base
  disclosure).
- The bonused EHP disclosure (line 1959) and its
  heading make no shield recharge or peak claim and
  stay true; EHP numbers do not move.
- The Active repair disclosure (line 3363) says
  "Passive shield recharge is shown as shield peak
  recharge in the Ship block and is not included here".
  Both clauses stay true — the base shield peak line
  remains in the Ship block, and no passive recharge
  of either kind is included in active repair; the
  sentence does not say "only". It is **not** edited to
  narrate the new block (its load-bearing clause is
  the exclusion, and rewriting a locked sibling string
  to chase a neighbouring feature is how disclosures
  drift). Noted as a deliberate non-change so review
  does not "fix" it.
- The base and bonused capacitor disclosures (lines
  3085, 3217) name capacitor quantities only and are
  untouched.

The sentences that **would** become false and are
therefore revised in the implementation commits (doc
comments only, no rendered string, no behaviour):

- `src/fitting/ship_resistances.rs` module header
  (lines 24–29) — "`bonused_hit_points` … produce
  bonused shield/armor/hull hit points for
  `ship_ehp_with_module_bonuses` only" becomes false
  the moment the shield peak consumes the same helper.
  The paragraph is revised to name both consumers (EHP
  numerator under #617; shield layer for the bonused
  shield peak under this document), and a sibling
  paragraph names `bonused_shield_recharge_duration`
  (section 4). The header's other statements —
  including `bonused_capacitor`'s "for
  `fitting_cap_stability_with_module_bonuses` only" —
  do not change.
- `src/fitting/ship_peak_recharge.rs` module header
  (lines 1–15) — already scoped by #618 to
  `ship_base_peak_recharge` by name; it gains a short
  paragraph naming `shield_peak_recharge` as the
  shared guarded shield formula and
  `ship_shield_peak_recharge_with_module_bonuses` as
  the bonused consumer under this document.
  `ShipBasePeakRecharge`'s own doc stays as written (it
  still describes base stats only).
- `src/ui/fittings.rs` doc comment above
  `bonused_ehp_hit_point_unapplied_line` (lines
  2051–2054) — "…disclosure for the bonused EHP block"
  becomes incomplete when this block reuses the helper
  verbatim; the comment is revised to name both
  blocks. The helper name and strings do not change
  (renaming a locked-wording helper for one more
  caller is churn the siblings avoided — the EHP block
  reuses `bonused_resistances_unapplied_line` under its
  resistances name today).

No other header, doc comment, or rendered string in
the codebase asserts anything this slice falsifies:
`ship_cap_stability`'s shipped "shield peak stays
base" test pins `ship_base_peak_recharge`'s base field,
which stays base; `ship_ehp`'s header claims nothing
about exclusive use of its helper; the generator's
header gains its paragraph by addition (section 3).
The earlier *design documents'* no-shield-bonuses
statements are historical slice boundaries, superseded
by reference in section 2, not edited.

## 8. Test plan (locked)

Tolerance tiers follow the shipped tests: hand-derived
floats use absolute tolerance `1e-9` with the division
shown (the `assert_rate_close` pattern in
`ship_peak_recharge.rs` tests, lines 138–146),
asserting against the unrounded shown quotient where a
decimal literal would invite drift; identities this
design calls exact use `assert_eq`; helper millisecond
values that are exact in `f64` (625000.0, 531250.0,
500000.0) use `assert_eq`. Fixture catalogues use the
existing `from_json` pattern; fixture modifier entries
are written in the shipped triple shape under the
section 3 key names (`shieldRechargeModifiers` /
`shieldRechargeModifiersUnapplied`, and the shipped
`hitPointModifiers` keys for numerator fixtures). No
test reads a raw EVE ID into a rendered-string
assertion beyond the fixture inputs the sibling tests
already use.

Base inputs for every oracle (pinned since earlier
slices): Rifter 587 shield hit points 450.0, shield
recharge 625000.0 ms = 625.0 s, base shield peak 2.5 ×
450 / 625 = 1.8 HP/s (the Flutter E2.8 bare oracle);
Punisher 597 shield 350.0, recharge 625.0 s, base peak
2.5 × 350 / 625 = 1.4 HP/s. Items are fitted in counted
slots of the matching family (recharger/extender
medium, relay/flux/power-diagnostic/reactor-control
low, purger/overclocking rig-slot) at quantity 1
unless stated. Each oracle pins all three counts
(excluded, hit-point-unapplied,
shield-recharge-unapplied) — zero where not stated —
and the duration helper's `recharge_ms` where the
denominator moves, so the bonused pair is hand-derived
even before the division.

**Oracle 1 — recharge multiplier only (duration
semantics, primary).** Rifter + Shield Recharger II
394 (`[[479, 4, 0.85]]`; a 479-only row — numerator
untouched). Bonused duration 625000 × 0.85 = 531250.0
ms = 531.25 s — the helper pins `Some(531250.0)`
milliseconds, proving lower-is-faster is applied to
the *duration*, never inverted. Peak 2.5 × 450 /
531.25 = 1125 / 531.25 = **2.1176470588235294 HP/s**.
Counts all zero.

**Oracle 2 — percent only, sign included (relay and
purger).** (a) Rifter + Shield Power Relay I 2331
(`[[479, 6, -20.0]]`): duration 625000 × 0.8 = 500000.0
ms = 500.0 s (negating or absolutizing the operand
gives 750000.0 ms and fails this pin); the row's
capacitor entry `[[55, 4, 1.3]]` is not read here (the
capacitor tests keep pinning it there). Peak 1125 /
500 = **2.25 HP/s**. (b) Rifter + Large Core Defense
Field Purger I 26084 (`[[479, 6, -20.0]]`, rig slot):
the same pair, peak **2.25 HP/s** — a second carrier
family reaching the same quotient by the same operand.
(c) Two 26084 in two rig slots: duration 625 × 0.8 ×
0.8 = **400.0 s**, peak 1125 / 400 = **2.8125 HP/s** —
a penalised second rig lands strictly below this; the
literal pins penalty-freedom (section 2). A stacked
quantity-2 row of one purger equals the two-slot
result (runs counted in units).

**Oracle 3 — flux coil combo (both inputs move on one
item, numerator down).** Rifter + Shield Flux Coil II
1256. Numerator through the shipped helper:
`[[263, 4, 0.85]]` → 450 × 0.85 = 382.5 HP (asserted
through `bonused_hit_points`, the same value the EHP
numerator consumes). Denominator: `[[479, 4, 0.7]]` →
625000 × 0.7 = 437500.0 ms = 437.5 s. Peak 2.5 × 382.5
/ 437.5 = 956.25 / 437.5 = **2.1857142857142855 HP/s**
(asserted within `1e-9` of the quotient) — above base
despite a *smaller* shield, because the duration
shrinks faster; nothing floors either input at base.
Counts all zero.

**Oracle 4 — extender combos (numerator only, then
both).** (a) Rifter + Medium Shield Extender II 3831
(`[[263, 2, 1100.0]]`; neither shield recharge key —
section 3 pin): numerator 450 + 1100 = 1550, duration
base-exact (`recharge_ms == Some(625000.0)` under
`==`), peak 2.5 × 1550 / 625 = 3875 / 625 = **6.2
HP/s**. (b) 3831 + 394 together: numerator 1550,
duration 531.25 s, peak 3875 / 531.25 =
**7.294117647058823 HP/s** — the coupled pair is the
composition of Oracles 1 and 4a and of nothing else.
(c) Punisher + 394 (second hull): duration 531.25 s,
peak 875 / 531.25 = **1.6470588235294117 HP/s**.

**Oracle 5 — slower than base, applied as written.**
Rifter + Medium Processor Overclocking Unit II 4399
(`[[479, 4, 1.1]]`): duration 625000 × 1.1 = 687500.0
ms = 687.5 s, peak 1125 / 687.5 =
**1.6363636363636365 HP/s** — strictly below the 1.8
base. No clamp, no floor, no "bonus must help" filter.

**Oracle 6 — four-family row reads only its two shield
families.** Rifter + Power Diagnostic System II 1541:
numerator `[[263, 4, 1.05]]` → 472.5; duration
`[[479, 4, 0.915]]` → 571875.0 ms = 571.875 s; peak
2.5 × 472.5 / 571.875 = 1181.25 / 571.875 =
**2.0655737704918034 HP/s**. The row's capacitor
entries are not read (capacitor tests keep pinning
them there), and its resistance profile (none) is
irrelevant — the peak is raw HP/s, never
resonance-divided.

**Oracle 7 — the absent-split pin (per-dimension
counts, exact identity under marked carriers).**
Rifter + Capacitor Power Relay I 1445. Its shield
recharge operand is absent (section 3: empty array,
marked), so the duration stays exactly base
(`recharge_ms == Some(625000.0)`) with
`shield_recharge_unapplied_modules == 1`; its hit
point operand is likewise absent (#617's set), so
`hit_point_unapplied_modules == 1` and the numerator
stays 450.0. Outcome `Available`, peak **equal under
`==`** to the base 1.8 path (compared as in the identity
pin below — never against the non-representable `1.8`
literal by `assert_eq`), `excluded_modules == 0`.
Quantity 2 counts 2 in *each* unapplied dimension
separately — asserted per dimension, never against
their sum. This is the row the separate dimensions
exist for: one fitted item, two honest one-module
lines (section 6), no combined figure.

**Helper and pure-function pins:**

1. Oracles 1–7 above: peaks through
   `ship_shield_peak_recharge_with_module_bonuses` on
   the bundled catalogue (in `ship_peak_recharge.rs`
   tests), denominator values through
   `bonused_shield_recharge_duration` and numerator
   values through `bonused_hit_points` (in
   `ship_resistances.rs` tests beside the sibling
   helper pins), all three counts each time.
2. **Empty == base, exactly.** `Available` with
   `assert_eq` of `Some(shield_hp_per_sec)` against the
   shield field of `ship_base_peak_recharge` over the
   same fitting's `Available` `ship_base_stats`, all
   counts zero except where
   stated, for: hull-only Rifter and Punisher; only
   non-counted items (cargo/charge/drone flags,
   quantity 0, `type_id <= 0`); a counted double
   non-carrier (2048 — resistance carrier, neither hit
   point nor shield recharge carrier); an identity
   carrier in both dimensions (1353 Reactor Control
   Unit I — `[[263, 4, 1.0]]` and `[[479, 4, 1.0]]`);
   and the three demo fittings, reproducing peaks 1.8
   / 1.8 / 1.4 through the base function exactly, with
   `excluded_modules == 1` on Demo Brawler (type 1535
   catalogue-absent) and 0 with all unapplied counts 0
   on Mission Runner and Demo Runner (section 4's
   design check; asserted per fitting, not by
   assumption).
3. **Shared-count equalities.** On every oracle and
   fixture fit: `excluded_modules` equals
   `ship_resistances_with_module_bonuses`'
   `excluded_modules` wherever that outcome is
   `Available`, and equals
   `bonused_capacitor(...).excluded_modules` — the
   anti-drift pins for the shared predicate, mirroring
   #618 — and the public struct's
   `hit_point_unapplied_modules` equals
   `bonused_hit_points(...).hit_point_unapplied_modules`
   and `ship_ehp_with_module_bonuses`' same-named field
   wherever that outcome is `Available` (one helper,
   two disclosures, no divergence). The shield recharge
   count is asserted separately and never against a
   sum. A fit carrying a capacitor-unapplied carrier
   with no shield recharge entry (the section 6
   dimension guards; fixture row with only
   `capacitorCapacityModifiersUnapplied`) leaves this
   block's counts at their own values, and vice versa
   — dimensions never bleed.
4. **Whole-dimension hit point count, disclosed as
   defined.** Rifter + Medium Abyssal Armor Plates
   47817 (hit-point absent pin, armor layer only):
   peak equals base exactly, `excluded_modules == 0`,
   `shield_recharge_unapplied_modules == 0`,
   `hit_point_unapplied_modules == 1` — the pinned,
   deliberate consequence of consuming
   `bonused_hit_points` verbatim (sections 4 and 6): an
   armor-only unapplied carrier raises the hit point
   line in this block while the shield numerator is
   untouched. Over-disclosure by dimension, never
   under-disclosure, and never a forked shield-only
   recount.
5. **Partial (helper level) and coupled Unavailable.**
   Fixture hull with `shieldCapacity` absent,
   `shieldRechargeRate` present, fixture extender +
   fixture recharger fitted →
   `bonused_hit_points(...).hit_points[0] == None` (no
   resurrection), `bonused_shield_recharge_duration
   (...).recharge_ms == Some(531250.0)` (the duration
   still bonuses), public outcome `Unavailable`, base
   shield peak `None`. Mirror with the duration absent
   and shield capacity present → numerator
   `Some(1550.0)`, duration `None`, public
   `Unavailable`. Present `0.0` shield capacity with
   fixture extender → numerator computes from
   (0 + 1100), peak computes (application to a present
   zero ≠ resurrection of absence — both pinned).
   Present-`0.0` shield capacity with *no* extender but
   a positive duration → `Available` with
   `shield_hp_per_sec == 0.0` by `assert_eq` (the
   honest zero; 2.5 × 0 / t is exactly 0). Present
   `0.0` duration (with or without recharger,
   0 × 0.85 = 0) → helper `Some(0.0)`, public
   **and base** shield peak absent/`Unavailable`.
6. **Hostile bounded (subnormal, zero, negative,
   overflow — every outcome asserted, never
   discarded).** On the fixture hull (450.0 /
   625000.0 ms), fixture entries in the shipped key
   shapes. No hostile case may be smoke-run and thrown
   away (`let _ = …` is forbidden as a test outcome —
   the `2ac348f` repair in the capacitor tests is the
   precedent, not a style hint); each asserts the
   helper value **and** the public outcome:
   - duration percent −100 (`[[479, 6, -100.0]]`) →
     helper `recharge_ms == Some(0.0)` (a real zero at
     helper level), public `Unavailable`, base shield
     peak still `Some` 1.8-tier — the base/bonused
     availability split;
   - duration percent −150 → helper `None`, public
     `Unavailable`; duration mul −0.85 → negative
     duration → helper `None`, public `Unavailable`;
   - quantity `i64::MAX` of a −20.0 percent fixture rig
     → percent run stalls at a positive subnormal →
     helper `recharge_ms == None` **asserted**, public
     `Unavailable` **asserted**, returns promptly;
   - quantity `i64::MAX` of a 0.85 mul fixture
     recharger → helper `None`, public `Unavailable`,
     promptly (the shipped capacitor fixtures at
     `ship_cap_stability.rs:1973-1998` prove these two
     stall shapes through the same `mul_product`);
   - numerator-side mirror: quantity `i64::MAX` of a
     −15.0 percent fixture on 263
     (`hitPointModifiers: [[263, 6, -15.0]]`), duration
     untouched → `bonused_hit_points(...).hit_points[0]`
     is a **positive subnormal** (asserted as `> 0.0 &&
     !is_normal()` — the shipped helper still returns
     it, EHP behaviour untouched) and the public
     outcome is `Unavailable` — the consumer-side
     rejection of section 4 is the thing under test, so
     both sides of it are asserted;
   - numerator exact-zero companion: quantity 1 of a
     −100.0 percent fixture on 263 → helper numerator
     `Some(0.0)`, public `Available` with peak `0.0` —
     subnormal and exact zero take different routes on
     the numerator too, mirroring the duration's
     `None`-vs-`Some(0.0)` split at helper level;
   - quantity `i64::MAX` of an op-2 fixture add on 479
     (`[[479, 2, 1000.0]]`) → helper duration is the
     locked formula's finite
     `625000 + 1000.0 × (i64::MAX as f64)` (adds never
     loop; pinned through the helper, mirroring the
     capacitor battery-add pins);
   - rate overflow: fixture hull `shieldCapacity:
     1e308`, `shieldRechargeRate: 1.0` (0.001 s) →
     `2.5 × 1e308 / 0.001` non-finite → wrapper `None`,
     public `Unavailable` (usable pair, no honest
     rate — section 4). The wrapper's own guard matrix
     (absent/zero/negative/NaN/infinite per input,
     overflow) is already pinned for the shield field
     through `ship_base_peak_recharge` and passes
     unmodified after the refactor; one direct
     `shield_peak_recharge` pin per guard-corner class
     is added in the same test module for the new name
     (zero capacity `Some(0.0)`, zero recharge `None`,
     overflow `None`).
7. **Runtime guard counts.** Fixture rows beyond the
   generator's guarantees: marked-unapplied *with* an
   applicable `[[479, 4, 0.85]]` entry (counted once,
   entry still applied — duration proves it); entries
   with operators 0, 3, 5, and 7, a wrong modified id
   (a 263 or 482 triple inside
   `shieldRechargeModifiers`), a zero operand, and a
   non-finite operand → each counts its item once in
   `shield_recharge_unapplied_modules` (never twice
   for two bad entries on one item), applicable entries
   still applied, a guarded entry never contributes its
   operand, and none of it touches the hit point or
   excluded counts. An operator-2 fixture entry
   (`[[479, 2, -50000.0]]`) applies as a flat add
   (duration 575000.0 ms) — the grounded-but-uncensused
   operator behaves as section 2 locks if data ever
   carries it.
8. **Base independence regression.** Fitting any oracle
   carrier changes the bonused function and leaves
   `ship_base_peak_recharge` (Rifter shield 1.8,
   capacitor 5.0), `ship_base_stats`,
   `ship_ehp_with_module_bonuses` (a 479-only carrier —
   394 — moves no EHP figure or count),
   `ship_resistances_with_module_bonuses`, and both
   capacitor stability functions at their shipped
   oracles on the same fitting. Fitting 3831 moves the
   EHP numerator and this peak *together* by the same
   1550 numerator (the no-divergence pin across the two
   blocks).
9. **Unavailable shapes.** Unknown ship id, non-ship
   row, `ship_type_id` 0 and negative → `Unavailable`;
   helper-level: `bonused_shield_recharge_duration` is
   `None` exactly on the ship gate, `Some` with
   `recharge_ms: None` otherwise where the base is
   unusable.

**Regression gates (unmodified).** Every existing test
in `ship_peak_recharge.rs` (oracles, guard matrix,
overflow, independence), `ship_stats.rs`,
`ship_resistances.rs`, `ship_ehp.rs`,
`ship_cap_stability.rs` (including every simulator
literal and the `2ac348f` subnormal pins), the
catalogue tests, and the UI line/wording tests for
every existing block passes **unmodified** — the
`shield_peak_recharge` extraction is behaviour-
preserving and these tests are the proof; the only
permitted edits to pre-existing test-adjacent text are
the three doc-comment revisions of section 7, which no
test asserts on. If the extraction cannot be done
without moving a base literal, stop against this
document.

**Catalogue pins.** The section 3 loader invariants
(103/77/26/77, modified id, operators, spot pins) join
`bundled_catalogue_invariants` over the real bundled
asset, plus a `from_json` pin that a row without the
new keys loads `None`/`false` and a row with them
parses. The generator commit reports in its body:
twice-run identical sha256, strip-the-two-new-keys
byte-identity against `11accfe2…`, and the exact new
byte count against the +8,000 budget. Proofs are run
once and reported, not committed as scripts.

**UI pins (`src/ui/fittings.rs` tests):**

1. New wording test pinning section 7's heading,
   disclosure, and both unavailable sentences
   verbatim; the existing ship base, EHP, capacitor,
   and active repair wording tests pass unmodified
   (base strings byte-identical — pinned by non-edit).
2. New count-helper pins: the two new helpers at 0
   (`None`), 1 (singular), and 2 (plural) with section
   7's exact strings; the reused hit point helper's
   existing pins (lines 8096–8102 region) stand.
3. Lines by construction: a
   `BonusedShieldPeakRecharge` fixture with every count
   non-zero renders through
   `ship_shield_peak_recharge_with_bonuses_lines` as
   exactly [peak, excluded, hit-point-unapplied,
   shield-recharge-unapplied] in that order, the peak
   in the base block's template; each zero count omits
   only its own line; a `0.0` peak renders
   `Shield peak recharge: 0.0 HP/s`.
4. Catalogue lines: Rifter + 394 renders exactly
   `Shield peak recharge: 2.1 HP/s` through the
   composer (2.117… at the formatter's tenth), while
   `ship_base_stat_lines` on the same fitting still
   ends `Shield peak recharge: 1.8 HP/s` (lines
   6390–6423 templates unmodified) — base and bonused
   forms of the same label, in adjacent blocks, from
   one fitting.
5. Demo-story test: for the three demo fittings the
   bonused lines are the single base peak line
   (`1.8` / `1.8` / `1.4 HP/s`) plus exactly the
   excluded line on Demo Brawler
   (`1 fitted module is not in Mimir's bundled item
   data, so any hit point or shield recharge bonus
   from it is not counted.`) — the visible form of the
   empty==base identity with honest counts, mirroring
   the capacitor demo test (line 6853).

**Gates (all must pass for every implementation
commit):** `cargo fmt --check`, `cargo clippy
--all-targets -- -D warnings`, `cargo test`, `cargo
build`. Commits are small and atomic, `type(scope):
description`, with no attribution lines. Locked commit
sequence after this design commit (`docs(fitting):
design fitted-module shield recharge bonuses`):
(1) `feat(catalogue): emit fitted-module shield
recharge modifiers` (generator + regenerated asset,
proof obligations in the body); (2) `feat(fitting):
load shield recharge modifiers from the catalogue`
(loader fields + invariants); (3) `feat(fitting):
compute shield peak recharge with fitted module
bonuses` (duration helper, peak wrapper extraction,
public function, pure tests, the fitting-module
doc-comment revisions of section 7); (4)
`feat(fitting): show shield peak recharge with fitted
module bonuses` (renderer, wording, line and count
helpers, UI tests, both call sites, the reused-line
doc revision of section 7). Each commit passes all
four gates alone.

## 9. Exclusions (locked)

Out of this slice, by name: ship (hull role/trait)
bonuses (no category-6 carrier on 479 exists to defer,
and none gains emission if the data grows one without
a new design); character skills in any form (Shield
Operation 3416, category 16, and Flutter's known-skill
percent table that would join the same chain —
including its `(3416, shieldRechargeTime, -0.05)`
entry); implants and boosters (category 20 — the seven
Zainou 'Gnome' shield operation implants 3088/3089/
3092/13263/16248/27107/32255 and every drug booster);
subsystem bonuses (effects 3856 and 6043 on
unpublished category-17 rows and any category-32
carrier — none gains emission even though subsystem
slots are counted slots, disclosed by the word
"subsystems" in the new block, as every sibling
discloses it); structure and NPC carriers and the one
`OwnerRequiredSkillModifier`/`charID` row on 479;
shield changes from anything outside the ship (fleet,
environment, remote shield transfers, effects on other
ships); **shield boost and repair amounts** — attribute
68 `shieldBonus`, booster cycles, ancillary loading,
and the whole active-repair computation stay exactly
as shipped in their own block, and no passive peak is
ever added to a boost rate or vice versa (there is no
sustained/burst tank figure in this slice);
**capacitor-need and cycle modifiers on modules** — no
modifier targeting a fitted module's own
`capacitorNeed` (6), `duration` (73), `speed` (51), or
`reactivationDelay` (1795) is emitted, read, or
applied by this slice (#618's exclusions stand; this
slice reads no module-side attribute at all);
resonance application to the peak (the figure is raw
HP/s — no effective or resisted passive tank, no
damage profile); any recharge curve over time,
charge-level percentage, average recharge rate
(capacity ÷ duration is a different, unlabelled
number), or time-to-full readout; module
active/inactive or overheating state (every fitted
module counts as active, as #615 locked); mutated
(abyssal) per-item values — types whose real bonuses
the type rows do not carry ship counted-not-applied by
the same classification as the siblings; any
bonused-hit-point or bonused-duration readout outside
this peak and the shipped EHP numerator (no
`ship_base_stats` change, no public bonused-pair API —
the duration helper is `pub(crate)`); any change to
base peaks, base or bonused EHP, resistances,
capacitor stability, active repair, resources, or DPS
numbers or emission; persistence, ESI, editor, and
network changes; new logging.

Operators outside {2, 4, 6} on 479 are not
deferred-silently: they are locked as unsupported →
unapplied-counted at generation and at runtime
(sections 2–4) — including operator 5, present in the
data definition on zero types — which is this slice's
complete answer for them until a future design grounds
one.

## 10. Decision record

When this slice merges, `DECISIONS.md` gains an entry
in the implementation PR (not this design commit):
"Bonused shield peak recharge: fitted-module shield hit
point and shield recharge bonuses" — recording the
supersession of the peak slice's no-modifiers boundary
and the capacitor slice's shield-pair deferral, the
duration-semantics finding (479 is milliseconds, lower
is faster; negative percents and sub-1.0 multipliers
are the improvement direction and are never inverted),
the no-stacking-penalty verification and the census
(operator set {2, 4, 6} with category-7 exercising
{4, 6}; a real 26-type marked-unapplied set), the
dedicated single-attribute duration helper with the
#617 numerator consumed — never recomputed — under a
consumer-side subnormal rejection (the `2ac348f` rule
on both inputs; positive subnormal is no data, exact
`0.0` is real), the coupled-pair completeness rule
(either input unusable → no peak, block `Unavailable`),
the category-7-only gate with skills, implants, and
subsystems deferred, and the three-count never-summed
disclosure (shared excluded with this block's own
wording, whole-dimension hit-point-unapplied reused
verbatim, new shield-recharge-unapplied). The entry is
the implementation PR's because it records what
shipped; this document records what was decided before
building.

