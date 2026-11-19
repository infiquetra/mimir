# Fitted-module hit point bonuses (bonused hit points as the EHP numerator) — design

Status: locked for the `feat/rust-hp-bonuses` slice. Base:
`develop` at `dbfe9fc` (PRs #615 and #616 merged). Slice
branch: `feat/rust-hp-bonuses`. This document is the single
design commit; builders implement exactly what is locked here
and nothing else. It extends the resistance bonuses slice
(`docs/resistance-bonuses-design.md`, #615) and the bonused
effective hit points slice (`docs/bonused-ehp-design.md`,
#616), and reuses their shapes; where this document says
"mirrors #615" or "mirrors #616", that wording and structure
are the precedent and do not need relitigating. It supersedes
#616's base-numerator policy (section 2). The earlier design
documents are not edited.

Every name, formula, count, and oracle number below traces to
an inspected body at `dbfe9fc` — `src/fitting/ship_ehp.rs`,
`src/fitting/ship_resistances.rs`,
`src/names/fitting_types.rs`, `src/ui/fittings.rs`,
`scripts/sde/generate_fitting_types_sde.py`, the two design
documents above — or to a design-time script over the
committed SDE data (`dogmaEffects.jsonl` inside
`scripts/sde/eve-online-static-data-3503375-jsonl.zip` joined
through the committed `scripts/sde/*.csv.bz2` caches), or to
the inspected Flutter dogma engine bodies the earlier slices
cite, or to hand arithmetic over values those bodies pin
(shown in section 8). No convention here comes from EVE
folklore or memory. Raw EVE type IDs never appear in any
rendered string in this slice; type IDs below are internal
oracle pins only, as in #615.

## 1. Goal and value ranking

Make the existing "Ship effective hit points (with fitted
module resistance bonuses, omni 25/25/25/25)" block (#616)
honest about fitted hit points: its numerator becomes the
hull's **bonused hit points** — base hit points after the
fitted modules' and rigs' hit point bonuses (shield
extenders, armor plates, and kin: reinforced bulkheads,
hit-point rigs, flux coils, nanofibers, rig drawbacks) —
divided by the same share-weighted **bonused resonances**
#615/#616 already compute. No new block is added; the #616
block's numbers, heading, disclosure, and counts change
exactly as sections 4–7 lock. This is the slice #616
section 9 excluded by name ("hit-point modifiers of any kind
(shield extenders, armor plates, hit-point rigs, subsystem
hit points) — the numerator stays base"; subsystem hit
points stay excluded here too, section 9). No network, no
ESI changes, no new scopes, no persistence, no new public
API, and no bonused-hit-point readout anywhere else: the
bonused hit points exist only inside the EHP computation
(section 4), so `ship_base_stats` and its "Ship base values"
block keep showing base hit points and keep their disclosure
true.

Value ranking (locked, in order), extending #616's:

1. **Never show an EHP number without its damage profile and
   both of its bonus policies named beside it.** #616 rank 1
   is inherited and widened: now that numerator *and*
   denominator carry fitted-module bonuses, the heading and
   disclosure must name hit point bonuses as well as
   resistance bonuses, or the figure still reads as
   resistance-only (section 7 wording). An arithmetically
   perfect number a reader mistakes for their ship's full
   fitted tank — skills, ship bonuses, implants, and
   subsystems are still not applied — is still a failure.
2. **Correctness and exactness of the bonused hit points.**
   Every bonused hit point value must be hand-derivable from
   quoted base hit points and emitted operands (section 8),
   computed at full `f64` precision with the locked
   `(base + adds) × mul × percent` order (section 2).
   Absence never renders as a number and never resurrects as
   zero: per-layer completeness is identical in shape to
   base EHP (section 4).
3. **No deficit is silently dropped, in either dimension.**
   The resistance-dimension excluded/unapplied counts #616
   carries stay byte-identical in meaning, and hit-point
   carriers whose bonus cannot be applied get their own
   per-dimension unapplied count and line (sections 4 and
   7). The two dimensions' counts are never summed. A
   bonused EHP that quietly omits an extender the view
   counted as missing would cross-read as complete.
4. **Reuse.** The #615 generator classification, catalogue
   tuple shape, loader shape, counted-item scan, bounded
   run arithmetic, and count-line shapes, and the #616
   renderer and line helpers, beat new machinery (sections
   3, 4, 6).

Non-goals are locked in section 9. In particular: no ship
traits, skills, implants, boosters, or subsystem bonuses; no
capacitor modifiers; no repair or boost amounts; no
bonused-hit-point display outside the EHP numerator.

The base resistances block, the #615 bonused resistances
block (one disclosure clause excepted, section 7), the base
EHP block, and the ship base values block keep their
arithmetic, availability logic, headings, lines, and
numbers. `ship_base_ehp`, `ship_resistances`,
`ship_resistances_with_module_bonuses`, and
`ship_base_stats` do not change behaviour in any byte; their
existing tests are the regression gate (section 8).

## 2. Modifier set, arithmetic, and supersession (locked)

**Supersession.** #616 section 2 locked "Numerator: base hit
points only" and named its mitigation (wording) as the
interim answer until a hit-point-modifier pipeline shipped.
This slice is that pipeline, so the following #616 locks are
superseded as slice boundaries and replaced by the sections
named: section 1's "base hit points (the numerator,
unchanged)" and "no catalogue change" (→ sections 3–4
here); section 2's numerator lock (→ bonused numerator,
section 4); section 4's "layer fed with base hit points" and
its count set (→ bonused hit points plus the hit-point
unapplied count, section 4); section 5's no-extension lock
(→ section 3 here); section 7's heading, disclosure,
unavailable sentences, and its revision of the #615
disclosure (→ section 7 here, which revises that clause
again); section 8's demo-story expectation where it asserts
counts only (→ section 8 here; its three EHP oracles are
*not* superseded — they stay exact, section 8); section 9's
hit-point-modifier exclusion (→ section 9 here). What is
**not** superseded: #615's resistance semantics, counted-flag
set, stacking rules, and bounded arithmetic; #616's shared
resonance helper, per-layer completeness shape, total rule,
empty-fitting exactness requirement, and per-block count
disclosure shape. A builder who believes this design
requires changing any of those stops and records it against
this document.

**Grounded modifier shape (locked — ships, the whole set).**
A fitted item contributes a hit point modifier only when all
of these hold, mirroring #615 section 2 with the hit point
attribute set substituted:

- its catalogue row is category 7 (module, including rigs —
  category-7 rows with slot effect 2663; hit-point rigs are
  therefore in scope as fitted items);
- one of its effects (joined through
  `dgmTypeEffects.csv.bz2`) carries a modifier with
  `func == ItemModifier` and `domain == shipID`;
- that modifier's modified attribute is one of the three
  ship hit point attributes — **263 `shieldCapacity`, 265
  `armorHP`, 9 `hp`** (hull), the same three attributes the
  base slices locked as `shield_capacity` / `armor_hp` /
  `hull_hp` (`src/names/fitting_types.rs:39-50`);
- its operator is `2`, `4`, or `6` (below);
- the operand — the item type's own `dgmTypeAttributes`
  value for the modifier's modifying attribute — is present,
  finite, and not `0.0`.

**Supported operations (locked, with evidence).** Design-
scripted over the committed data, category-7
`ItemModifier`/`shipID` modifiers on {263, 265, 9} use
exactly three operator codes, and each is grounded in the
inspected Flutter ship path (`routeOwnerModifiers` routes
`ItemModifier`/`shipID` by operator into add/mul/percent
accumulators; the final ship loop composes them):

- **Operator 2, modAdd — flat add.** Flutter `_modAdd = 2`;
  the ship route sums operands into `addModifiers`. Census:
  (263 ← 72) on 33 types (shield extenders; Medium Shield
  Extender II operand 1100.0) and (265 ← 1159) on 48 types
  (armor plates; 1600mm Steel Plates II operand 4800.0).
  81 entries, operands in [175.0, 82500.0].
- **Operator 4, postMulAlt — multiplier.** Flutter
  `_postMulAlt = 4`, `_isMul` covers {0, 4}; the ship route
  collects operands into `mulModifiers` and multiplies.
  Census: (263 ← 146) on 51 types (shield flux family;
  0.7–0.95), (265 ← 148) on 353 types (armor coating/membrane
  family), (9 ← 150) on 22 types (bulkheads, nanofibers).
  426 entries, operands in [0.7, 1.27], of which 367 are
  exactly `1.0` (mostly the coating family's armor
  multiplier — present, non-zero, and therefore emitted
  like any other applicable entry; at runtime it is the
  identity, section 4).
- **Operator 6, postPercent — percent.** Flutter
  `_postPercent = 6`; the ship route collects operands into
  `percentModifiers` and chains `1 + value/100` factors.
  Census: (263 ← 337) on 8 types (Core Defense Field
  Extender rigs, +15.0/+20.0), (265 ← 335) on 8 types
  (Trimark rigs, +15.0/+20.0), (9 ← 327) on 8 types
  (Transverse Bulkhead rigs, +20.0/+25.0), and the rig
  drawback (263 ← 1138) on 64 types and (265 ← 1138) on 48
  types at −10.0. 136 entries, operands in [−10.0, 25.0].

Every applicable category-7 carrier today has **exactly one**
applicable entry (scripted max 1 of 643), no carrier has a
duplicated (modified, modifying, operator) triple, and none
has two applicable entries on the same modified attribute;
section 3 locks those as fail-loud generator invariants,
not as silent assumptions.

**Unsupported operations (locked: counted, never guessed).**
No category-7 hit point carrier in the committed data uses
any operator outside {2, 4, 6} — there is no unsupported
operator on hit points today. Operators `0` (postMul) and
`3` (modSub) are defined by Flutter for the ship path in
general, but no hit point carrier, fixture, or test in any
inspected body exercises them on {263, 265, 9}; operators
`-1, 5, 7, 9` have no ship-path meaning in Flutter at all
(the route falls through to `unsupportedOperators++`). This
slice therefore grounds exactly {2, 4, 6}: any other
operator with a present, non-zero operand is classified
**unsupported** by the generator (section 3: marks the type
unapplied, emits no entry) and guarded the same way at
runtime (section 4: counted once per item in the hit-point
unapplied count, applicable entries still applied). If a
future SDE refresh introduces one, it ships as
counted-not-applied until a later design grounds it — never
silently applied under a guessed meaning, never silently
dropped. The same counted-not-applied treatment covers
every shape outside the grounded one: any other `func` or
`domain` (the zip's remaining hit point modifiers are
`charID` drone/fighter bonuses and `structureID` structure
bonuses, which never modify the fitted ship), and carriers
outside category 7 — scripted: 17 category-6 ship-trait, 3
category-16 skill (Shield Management, Hull Upgrades,
Mechanics), 100 category-20 implant/booster, 12 category-32
subsystem, and 19 category-2 rows carry the same triples
and gain no emission (section 9 defers each by name).

**Census (locked counts).** Scripted over the committed
data (zip `modifierInfo` ⋈ `dgmTypeEffects` ⋈
`dgmTypeAttributes` ⋈ the current catalogue, category 7
only, the #615 four-way classification of section 3):
**759 carrier types**, of which **643 carry exactly one
applicable entry** (643 entries total: 81 operator-2, 426
operator-4, 136 operator-6), **84 are zero-only** (their
single triple's operand is present and exactly `0.0` — the
shield amplifier family, whose (263 ← 72) add operand is
`0.0`; provably no bonus, neither key, section 3), and
**32 are absent-only** (operand absent: 26 capacitor
power relay / capacitor flux coil types whose (263 ← 146)
multiplier operand has no cache row, and the 6 abyssal
extender/plate types 47800–47820 whose real bonuses are
mutated per-item values the SDE type rows do not carry).
The 32 absent-only types are the marked-unapplied set;
there are no unsupported-only and no mixed
applicable-plus-absent types today. Section 3 pins these
numbers as generator and loader invariants.

**Arithmetic (locked, Flutter ship path verbatim).** For
each of the three hit point attributes independently:

```text
bonused hit points = (base + Σ operator-2 operands)
                     × Π operator-4 operands
                     × Π (1 + operator-6 operand / 100)
```

Sources: operator codes `_modAdd = 2`, `_postMulAlt = 4`
(one of `_isMul`), `_postPercent = 6`
(`dogma_engine.dart:26-34, 109-110` at `ed698d3`); the
`ItemModifier`/`shipID` route summing adds, collecting
muls and percents (`routeOwnerModifiers`); the final ship
composition `value = (base + Σ adds) × Π mul ×
chain(percent)` over touched attributes. Locked
consequences builders must not "improve":

- **No stacking penalty on hit points, in any class.** This
  is verified from the inspected bodies, not assumed, and
  it corrects the plausible guess that hit point percent
  bonuses chain like resistances: Flutter's `_percentChain`
  applies `getStackingPenalty` only when the attribute is
  in `_nonStackableAttributes`, which is exactly the
  twelve resonances (`dogma_engine.dart:112-128, 168-179`);
  263, 265, and 9 are not in that set, so every hit point
  percent factor uses penalty `1.0`. Flat adds are summed,
  multipliers are multiplied straight through, percents
  chain unpenalised. Two Trimark I rigs give
  `1.15 × 1.15 = 1.3225`, not a penalised chain (section 8
  pins it). `resistance_stacking_penalty` is never called
  on this path.
- **Order is adds, then mul, then percent** — flat hit
  points land before multipliers and percents, so an
  extender's added hit points are themselves scaled by a
  fitted percent rig: (450 + 1100) × 1.15, not
  450 × 1.15 + 1100 (section 8 pins it). Flutter adds skill
  percents into the same percent accumulator after modules;
  skills are out of scope here (section 9), so nothing else
  enters the chain.
- **Bonuses can lower hit points, and nothing clamps.** 112
  of today's operator-6 entries are the −10.0 rig drawback
  and 20 operator-4 entries are below 1.0, so a layer's
  bonused EHP can be *below* its base EHP. A computed
  bonused value that is negative or non-finite is no data
  for that layer (section 4); a value of exactly `0.0` is a
  real zero, as everywhere in this codebase. On today's
  operands (adds ≥ 175.0, muls in [0.7, 1.27], percents in
  [−10.0, 25.0]) a negative bonused value is unreachable
  from a usable base; the rule exists for fixtures and
  future data.
- **Absent base is never resurrected — one deliberate
  divergence from Flutter, named.** Flutter's final loop
  substitutes base `0.0` for a touched attribute the ship
  lacks when an add exists, which would let an extender
  invent shield hit points on a hull with no shield data.
  This slice follows the house rule instead, as #615 did
  for resonances: an absent, negative, or non-finite base
  hit point field makes that layer's bonused hit points
  `None`, however many bonuses target it. A *present*
  `0.0` base is a real zero and bonuses apply to it
  normally ((0 + adds) × …), exactly as Flutter computes
  for a present attribute.
- **No module state**, as #615 locked: Rust fitting rows
  carry no state field, so every counted fitted item
  contributes as if active. That assumption is already
  user-visible wording in the block and stays verbatim
  (section 7).

## 3. Catalogue extension (locked)

The bundled catalogue gains per-type hit point modifier
entries through its existing generator only, mirroring #615
section 3 in every particular this section does not state.
Hand-editing the JSON is forbidden. Catalogue today:
3,836,770 bytes, sha256
`a2577b6ae0f64a59ebd110b377077efeda7c8250b319c613314169baefd06c88`.

**Generator changes** (`scripts/sde/generate_fitting_types_sde.py`).
The hit point leg reuses the inputs the resistance leg
already reads — `dogmaEffects.jsonl` from the committed
zip, `dgmTypeEffects`, `dgmTypeAttributes`, and the
category map — building its per-type map beside
`resist_modifiers_by_type` from the same parsed data (no
second zip read; the wanted-modifying-ids set is extended
to the hit point modifying attributes so one operand pass
serves both). The generator still never downloads; the
header comment gains the hit point keys beside the
resistance ones.

- Beside `RESIST_MODIFIER_ORDER`, add the locked constants
  with a provenance comment citing `dogmaEffects.jsonl`,
  the caches, and Flutter `dogma_engine.dart` at `ed698d3`
  for the operator codes and the absent/zero skip:

  ```python
  HIT_POINT_MODIFIER_ORDER = [263, 265, 9]
  HIT_POINT_MODIFIER_OPERATORS = {2, 4, 6}
  ```

  The order is the display order every slice uses (shield,
  armor, hull) and the emission sort; the operator set is
  section 2's grounded three, not #615's {0, 6}.
- Build the per-type entry map for category-7 types only,
  classifying every `ItemModifier`/`shipID` modifier on
  {263, 265, 9} of every effect on the type (deduplicated
  by (modified, modifying, operator)) as exactly one of:
  - **applicable**: operator in {2, 4, 6} and operand
    present, finite, and not `0.0` → an emitted entry;
  - **unsupported**: operator outside {2, 4, 6} and operand
    present and not `0.0` → no entry; marks the type
    unapplied (zero types today, section 2);
  - **zero**: operand present and exactly `0.0` → no entry,
    no mark (provably no bonus; the 84 amplifier types);
  - **absent**: operand not in the cache for this type → no
    entry; marks the type unapplied **only if the type ends
    with no applicable entry and no zero classification**
    (the #615 predicate verbatim; the 32 absent-only types
    of section 2).
- Loud failures, house style (`fail(...)`, writes nothing),
  mirroring the resistance leg: an unparseable or non-finite
  operand value on a classified modifier; a duplicated
  (modified, modifying, operator) triple on one type; two
  applicable entries on one type sharing a modified
  attribute. All are zero on today's data (scripted). A
  future SDE refresh that introduces one stops generation
  for review rather than shipping a doubled or ambiguous
  bonus. Messages say "hit point modifier", never
  "resistance modifier". Deliberately **not** failures:
  operand values outside today's observed ranges (a negative
  add or a percent below −100 is arithmetic the locked
  formula defines and the pure layer guards, section 4),
  absent operands, and zero operands.
- **Emission (locked shape).** Additive and sparse,
  category 7 only, all existing keys byte-stable and every
  non-category-7 row byte-identical to today. A carrier type
  emits the key `hitPointModifiers` iff it has at least one
  applicable entry **or** is marked unapplied. The value is
  a JSON array of `[modifiedAttributeId, operator,
  operand]` triples (numbers, compact separators), sorted
  by `HIT_POINT_MODIFIER_ORDER`, with the operand baked in
  at generation time — the modifying attribute id is
  deliberately not emitted, for the #615 reason: no runtime
  consumer may re-derive the operand. A type marked
  unapplied additionally emits
  `hitPointModifiersUnapplied: true` beside the (possibly
  empty) array. An all-zero carrier emits **neither key**
  (the 84 amplifiers: indistinguishable at runtime from a
  non-carrier, and counting it would be a false alarm).
  The full unapplied predicate (locked): a category-7 type
  with at least one `ItemModifier`/`shipID` hit point
  modifier is unapplied-marked iff (a) any modifier classed
  unsupported, or (b) it has no applicable entry, no zero
  classification, and at least one absent classification.
  Today that marks exactly **32 types**, all empty-array.
  A type with applicable entries plus an unsupported one
  would be marked (zero such types today; section 4 counts
  it while still applying its entries). Key placement is
  after the last existing per-type key block — today the
  resistance-modifier block — in the order
  `hitPointModifiers`, then `hitPointModifiersUnapplied`,
  so pre-existing key order on every row is untouched and
  type 1197-style rows carrying both modifier families emit
  resistance keys first, hit point keys second.
- **Self-validation.** A `HIT_POINT_MODIFIER_ORACLES` list
  beside `RESIST_MODIFIER_ORACLES`, same tuple shape
  `(type_id, expected_entries_or_None, expected_unapplied)`
  where `None` means neither hit point key may be present.
  Values are cache/zip reads from design (section 8 gives
  the arithmetic they feed):
  - 3831 Medium Shield Extender II: `[[263, 2, 1100.0]]`,
    unapplied false; 3841 Large Shield Extender II:
    `[[263, 2, 2600.0]]` (the flat-add pins).
  - 20353 1600mm Steel Plates II: `[[265, 2, 4800.0]]`;
    20349 400mm Steel Plates II: `[[265, 2, 1200.0]]`.
  - 1335 Reinforced Bulkheads II: `[[9, 4, 1.25]]`; 2605
    Nanofiber Internal Structure II: `[[9, 4, 0.8]]`; 1256
    Shield Flux Coil II: `[[263, 4, 0.85]]` (the multiplier
    pins, above and below 1.0).
  - 25894 Large Trimark Armor Pump I: `[[265, 6, 15.0]]`
    and 26302 II: `[[265, 6, 20.0]]`; 26088 Large Core
    Defense Field Extender I: `[[263, 6, 15.0]]`; 33898
    Large Transverse Bulkhead I: `[[9, 6, 20.0]]` (the
    percent pins, one per layer).
  - 26056 Large Dynamic Fuel Valve I: `[[265, 6, -10.0]]`
    (the rig-drawback pin).
  - 1197 EM Coating I: `[[265, 4, 1.0]]`, unapplied false
    (the identity-multiplier pin — this row also carries
    its `resistanceModifiers` entry, proving the two key
    families coexist independently).
  - 47804 Medium Abyssal Shield Extender and 47817 Medium
    Abyssal Armor Plates: empty array, unapplied true (the
    abyssal absent-operand pins).
  - 1447 Capacitor Power Relay II: empty array, unapplied
    true (the 26-type absent-146 family pin).
  - 1808 EM Shield Amplifier I: neither key (the all-zero
    pin — its (263 ← 72) operand is present `0.0`).
  - 2048 Damage Control II: neither key (a resistance
    carrier that is a hit point non-carrier).
  - 587 Rifter (category 6), 2456 Hobgoblin II (category
    18), and 45590 Tengu Defensive - Supplemental Screening
    (category 32): neither key (the category-gate pins —
    the subsystem row proves category-32 carriers with
    present operands gain nothing, section 9).
- **Catalogue-wide invariants** beside the resistance
  checks: every present `hitPointModifiers` value is on a
  category-7 row; its entries have modified ids in
  `HIT_POINT_MODIFIER_ORDER`, strictly sorted by that order
  with no duplicate modified id, operators in {2, 4, 6},
  operands finite and not `0.0`;
  `hitPointModifiersUnapplied` appears only beside
  `hitPointModifiers` and only as `true`; the counts equal
  the design-scripted values for today's data (**675 rows
  with the key** — 643 with entries plus 32 marked-empty;
  **32 marked; 643 entries**). The summary print gains
  those counts beside the resistance modifier print.
- Determinism unchanged: types sorted by `typeId`, compact
  separators, trailing newline, no timestamps. Proof
  obligations for the catalogue commit (section 8): run
  the generator twice → identical sha256; strip the two
  new keys from the regenerated file → byte-identical to
  today's `a2577b6a…`. Both proofs are run once and
  reported in the commit body, not committed as scripts.

**Size budget.** A simulation of the locked emission over
the real joined data (675 keyed rows, 643 triples, compact
separators, the key names above) adds ≈24,200 bytes
(≈ +0.6%). Budget: the regenerated file must land within
**+35,000 bytes** of today's 3,836,770; the catalogue
commit body states the exact new byte count. Anything over
budget means the emission rule drifted (for example
emitting zero operands, marking the 84 amplifier types, or
emitting on non-category-7 rows) and stops the slice for
review. The 367 identity (`1.0`) operator-4 entries are
inside the estimate and stay emitted: "present and
non-zero" is the #615 applicability test, and inventing a
second identity class for one operator would make the
catalogue's meaning depend on runtime arithmetic.

**Rust loader** (`src/names/fitting_types.rs`). `FittingType`
gains, immediately after the two resistance modifier fields
(lines 107–110), in the resistance fields' comment style:

```rust
#[serde(rename = "hitPointModifiers", default)]
pub hit_point_modifiers: Option<Vec<HitPointModifier>>,
#[serde(rename = "hitPointModifiersUnapplied", default)]
pub hit_point_modifiers_unapplied: bool,
```

with one new struct in the same module beside
`ResistanceModifier`,
`HitPointModifier { pub modified_attribute_id: i64, pub operator: i64, pub operand: f64 }`,
deserialized from the 3-element array by the same manual
tuple impl. Its doc comment pins the semantics: entries are
generation-time-proven `ItemModifier`/`shipID` hit point
bonuses on attributes 263/265/9 with the operand baked in
(operator 2 is modAdd, 4 is postMulAlt, 6 is postPercent);
`Some(empty)` with the unapplied flag is a carrier whose
bonus the bundled data cannot ground and must be counted,
never read as "no bonus"; `None` is a non-carrier or an
all-zero carrier. `#[serde(default)]` keeps old assets and
`from_json` fixtures loading as `None`/`false`. Nothing is
validated at load (the pure function guards values, section
4; the invariants test proves the shipped asset). No code
constructs `FittingType` literals, so no fixture churn.

**Invariants to add** to `bundled_catalogue_invariants`
(`src/names/fitting_types.rs`), beside the resistance block
(lines 1348–1398), all over the real bundled asset:
`hit_point_modifiers` is `Some` only on category-7 rows;
exactly 675 rows carry it, 643 non-empty, 32 marked
unapplied, 643 entries total; every entry's modified id is
one of 263/265/9, entries per row are in the locked order
with no duplicate modified id, operator is 2, 4, or 6,
operand finite and `!= 0.0`; the unapplied marker appears
only beside `Some`; spot pins mirroring the generator
oracles (3831, 20353, 1335, 25894, 26056, 1197's
`[[265, 4, 1.0]]` beside its resistance entry, 47804 and
1447 empty with flag true, 1808 `None`, 2048 `None`, 587
`None`, 45590 `None`). The existing invariants pass
unmodified.

## 4. Pure API (locked)

No new public API and no new module. The hit point helper
lives in `src/fitting/ship_resistances.rs` beside
`bonused_resonances`, because that module already owns the
counted-item scan (`counted_flag`) and the bounded run
arithmetic (`mul_product`) both helpers share; duplicating
either into `ship_ehp.rs` would fork the counted predicate
and put the count-merging rule below at risk. Its shape
mirrors `BonusedResonances` exactly (names are part of the
lock):

```rust
/// Bonused hit points per layer (shield, armor, hull) plus
/// the hit-point-dimension unapplied count the caller must
/// disclose beside any number derived from them.
pub(crate) struct BonusedHitPoints {
    pub hit_points: [Option<f64>; 3],
    pub hit_point_unapplied_modules: usize,
}

/// `None` only when the ship gate fails (`ship_type_id <= 0`,
/// no catalogue row, or the row is not category 6). Otherwise
/// `Some`, with each layer `None` exactly where the base hit
/// points are absent, negative, or non-finite, or the
/// bonused result is negative or non-finite.
pub(crate) fn bonused_hit_points(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> Option<BonusedHitPoints>;
```

Locked helper semantics:

- **Ship gate and bases.** The gate is `bonused_resonances`'
  verbatim. Bases are the ship row's `shield_capacity`,
  `armor_hp`, `hull_hp` in that position order, under a new
  private `HIT_POINT_ORDER: [i64; 3] = [263, 265, 9]`
  (position is the accumulator index, the `RESONANCE_ORDER`
  pattern). A base passes through the same usability filter
  shape as resonances (present, finite, `>= 0.0`; present
  `0.0` is a real zero).
- **Counted scan.** Identical item predicate to
  `bonused_resonances` (`type_id > 0`, positive quantity,
  `counted_flag`) and identical quantity-units handling
  (`usize::try_from(quantity)`, saturating adds). It reads
  `hit_point_modifiers` / `hit_point_modifiers_unapplied`
  where the sibling reads the resistance fields, with the
  same `counted_unapplied` once-per-item pattern: the
  catalogue unapplied flag counts the item's units once;
  an entry whose modified id is outside `HIT_POINT_ORDER`,
  whose operator is outside {2, 4, 6}, or whose operand is
  non-finite or `0.0` counts the item once (if not already
  counted) and is skipped — applicable entries on the same
  item are still applied. A counted row with **no catalogue
  row** contributes nothing here and is *not* counted by
  this helper: that deficit is the shared excluded count,
  owned by `bonused_resonances` (count-merging rule below).
- **Run accumulation and bounded arithmetic.** Per layer
  index, three run lists group operands by exact `==`
  value with saturating `u64` counts, in first-seen order
  (the sibling's run shape): operator-2 into `add_runs`,
  operator-4 into `mul_runs`, operator-6 into
  `percent_runs`. Per usable base, in this exact
  association:

  ```text
  add_total     = Σ over add runs of operand × (count as f64)
  mul_total     = Π over mul runs of mul_product(operand, count)
  percent_total = Π over percent runs, sorted by |value|
                  descending, of mul_product(1.0 + value / 100.0, count)
  bonused       = (base + add_total) × mul_total × percent_total
  ```

  `mul_product` is reused, not forked (its 1.0 identity,
  −1.0 parity, stall, zero, and non-finite stops are the
  locked bounded-hostile-quantity arithmetic for mul and
  percent runs alike); adds need no loop at all, since a
  run's contribution is one multiplication. The percent
  sort mirrors Flutter's chain order so float association
  is deterministic; **no stacking penalty is applied**
  (section 2), so `percent_chain` and
  `resistance_stacking_penalty` are not called. The layer
  result is `Some(bonused)` filtered finite and `>= 0.0`,
  exactly as the sibling filters resonances. A hostile
  quantity can therefore only yield the formula's own
  finite value or `None` — never a hang, never infinity
  (section 8 pins each class).
- **Identity (locked, exact).** With no applicable hit
  point entry on a layer, `add_total` is `0.0` and both
  products are `1.0`, so the bonused value is `(base +
  0.0) × 1.0 × 1.0` — the base value, equal under `==`
  (IEEE addition of `0.0` and multiplication by `1.0` are
  exact for every usable non-negative base). An identity
  operator-4 operand of `1.0` (the 367 coating entries)
  takes `mul_product`'s identity early return and likewise
  changes nothing, bit for bit.
- The helper is `pub(crate)`, never re-exported from
  `src/fitting/mod.rs`: bonused hit points stay an
  internal quantity of the EHP computation, exactly as
  resonances already are. The `ship_resistances.rs` module
  header gains a short paragraph naming the helper as an
  internal sibling serving the EHP numerator under this
  document; the header's statements about the two public
  functions do not change. No logging is added.

**EHP changes** (`src/fitting/ship_ehp.rs`).
`ship_ehp_with_module_bonuses` keeps its name, signature,
and outcome type; `BonusedShipEhp` gains one field and its
docs lose the base-numerator claim:

```rust
/// Bonused omni effective hit points plus the fitted-module
/// counts the caller must disclose beside them. Both the
/// hit points (numerator) and the resistances (denominator)
/// carry fitted-module bonuses.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BonusedShipEhp {
    pub ehp: ShipBaseEhp,
    /// Counted fitted rows with no catalogue row at all, so
    /// neither a resistance nor a hit point bonus can be
    /// proven or disproven for them. Same definition,
    /// units, and source as
    /// `BonusedShipResistances::excluded_modules`.
    pub excluded_modules: usize,
    /// Resistance-dimension count: same definition, units,
    /// and source as
    /// `BonusedShipResistances::unapplied_modules`.
    pub unapplied_modules: usize,
    /// Hit-point-dimension count: counted fitted rows the
    /// catalogue marks as hit point carriers whose bonus
    /// cannot be applied from the bundled data, in quantity
    /// units. Their applicable entries, if any, are still
    /// applied. Never summed with `unapplied_modules`.
    pub hit_point_unapplied_modules: usize,
}
```

The `BonusedShipEhpOutcome::Unavailable` doc loses the word
"base" ("No complete hit point and bonused-resonance data
…"), the function doc and the module header (lines 19–23
today) are rewritten to state that fitted-module hit point
bonuses apply to the numerator and resistance bonuses to
the denominator under this document, and `ship_base_ehp`'s
own docs and behaviour do not change. No re-export changes
are needed (`src/fitting/mod.rs` already exports the three
names).

Locked EHP semantics, stated as the delta from #616
section 4 (everything not mentioned is inherited
unchanged):

- **Inputs.** The function calls both crate-internal
  helpers — `bonused_resonances` for the twelve resonances
  and the shared excluded count, `bonused_hit_points` for
  the three bonused hit point values and the hit-point
  unapplied count — and does **no hull lookup of its own**
  (today's lookup for the base hit point fields goes away;
  the hit point helper owns it). It still never reads
  `fitting.items` itself, never calls `ship_base_stats`,
  `ship_resistances`, or
  `ship_resistances_with_module_bonuses`, and never
  consumes a percent.
- **Numerator.** Each layer's `layer_ehp` call receives
  that layer's bonused hit points (`hit_points[0]` shield,
  `[1]` armor, `[2]` hull) where today it receives
  `ship.shield_capacity` / `armor_hp` / `hull_hp`.
  `layer_ehp`, `usable_hit_points`, `usable_resonance`,
  and the four omni share constants are reused unchanged,
  so the bonused value passes through the same usability
  filter a base value does.
- **Per-layer completeness — identical in shape to base
  EHP.** A layer is `Some` exactly when its bonused hit
  points are usable and all four bonused resonances are
  usable, the denominator is finite, the
  `denominator <= 0.0` guard returns the (bonused) hit
  points, and otherwise the quotient is finite. One absent
  or unusable input makes that one layer `None` and never
  blanks the other layers. In particular, a bonus can
  never resurrect a layer whose base hit points or base
  resonance is absent (both helpers already return `None`
  there), and a bonused hit point value of exactly `0.0`
  (a present zero base with no adds, a multiplier run that
  reaches `0.0`, a fixture percent of −100) is a real zero
  that yields a `Some(0.0)` layer, never an omission.
- **Total — identical to base EHP.** `Some(shield + armor
  + hull)` in that order from unrounded values exactly
  when all three layers are `Some`; a non-finite sum is
  `None` for the total only. Never a partial sum, never
  zero-filled.
- **Availability.** `Unavailable` when either helper
  returns `None` (the shared ship gate, so both fail
  together) **or when no layer is computable**. Otherwise
  `Available`, carrying all three counts. Counts exist
  only on `Available`; `Unavailable` carries and renders
  none — the #615/#616 shape.
- **Empty-fitting identity (locked, exact).** For a
  fitting with no counted items, and equally for counted
  items carrying neither resistance nor applicable hit
  point entries (including all-zero hit point carriers,
  whose rows carry neither key, and identity-`1.0`
  operator-4 carriers), the result is `Available` exactly
  when `ship_base_ehp` is, with `ehp` **equal under `==`**
  to the base result — the compound of #616's resonance
  identity (`× 1.0 × 1.0`) and section 4's hit point
  identity (`(+ 0.0) × 1.0 × 1.0`). Section 8 pins this
  with `assert_eq` on the whole `ShipBaseEhp`, not a
  tolerance. Counts are zero unless a counted row is
  excluded or unapplied in either dimension.
- **Count-merging rule (locked).** The two helpers scan
  the same counted items under the same predicate, and
  their counts merge by dimension, never by addition:
  - `excluded_modules` is **shared**: a counted row with
    no catalogue row can prove neither dimension's bonus,
    so there is one excluded count, taken from
    `bonused_resonances` (the hit point helper does not
    count excluded rows at all). It is disclosed once per
    block with wording covering both dimensions in this
    block (section 7) and with the resistance wording in
    the resistances block, as today; per-block disclosures
    of one deficit are never summed across blocks (#616
    section 6, inherited).
  - `unapplied_modules` stays the **resistance-dimension**
    count, byte-identical in definition and source to
    #615/#616, so #616's count identity with
    `ship_resistances_with_module_bonuses` keeps holding
    for both `excluded_modules` and `unapplied_modules`
    (pinned, section 8).
  - `hit_point_unapplied_modules` is the separate
    **hit-point-dimension** count from `bonused_hit_points`.
    One fitted item can be counted in both unapplied
    counts (once per dimension, in quantity units) or in
    neither; the two are **never summed** into a combined
    figure, in the API or in the UI — the
    per-dimension-count precedent of the resources block
    (CPU and power grid excluded counts are disclosed
    separately, never added).
- **Independence.** Bonused EHP availability keys off
  per-layer bonused hit point plus bonused-resonance
  completeness; neither EHP function consults the other,
  nor resources, base stats, or either resistances
  outcome. Bonused resistances can render while bonused
  EHP is `Unavailable` (resonances without hit points),
  and bonused EHP can be partial while every sibling block
  renders in full. The function never panics; there is no
  error channel; nothing logs.

## 5. Completeness and Unavailable rules (locked)

Collected in one place; sections 2 and 4 are the normative
statements and this section adds nothing to them:

- A layer computes only from complete present data: usable
  base hit points (present, finite, non-negative; present
  `0.0` is real), a finite non-negative bonused result,
  and four usable bonused resonances with a finite
  denominator and quotient. Missing data is `None` for
  that layer only — never rendered as zero, never filled
  from another layer, never blanking sibling layers.
- A bonus never resurrects missing base data, in either
  dimension: absent base hit points stay `None` under any
  extender, absent base resonances stay `None` under any
  hardener.
- The total exists only when all three layers exist; a
  partial block renders its available layers with no
  total line.
- The block is `Unavailable` — heading plus the
  no-ship-data sentence, no numbers, no count lines — when
  the ship gate fails (`ship_type_id <= 0`, no catalogue
  row, not category 6) or no layer is computable; the
  heading plus the no-catalogue sentence when the
  catalogue itself failed to load. Unavailable in this
  block says nothing about any sibling block, and vice
  versa.
- Counts exist only on `Available`. Excluded rows (no
  catalogue row) and unapplied carriers (catalogue-marked
  or runtime-unguarded entries) are counted in quantity
  units and disclosed with wording (sections 4 and 7);
  nothing fitted is silently dropped, and nothing missing
  is silently zeroed.

## 6. Display (locked)

No new renderer and no new block. The existing
`render_ship_ehp_with_module_bonuses` (`src/ui/fittings.rs`)
keeps its two insertion points (immediately after
`render_ship_base_ehp` on both detail surfaces), its
heading-always-renders rule, and its arm structure; the
reading order on both surfaces is unchanged. Locked
changes inside it:

- The heading, disclosure, and unavailable sentences take
  section 7's replacement strings (same constant names).
- `Available` arm line order becomes: heading, the EHP
  lines, the excluded line if any, the resistance
  unapplied line if any, the hit point unapplied line if
  any, then the disclosure last. `Unavailable` renders
  heading plus the no-ship-data sentence and no count
  line, as today.
- **Line helpers.** `ship_base_ehp_lines(&bonused.ehp)` and
  `ship_ehp_line` are reused unchanged. The resistance
  unapplied line reuses `bonused_resistances_unapplied_line`
  verbatim (the deficit it names is unchanged). Two new
  pure line helpers beside it, same `None`-at-0 / singular /
  plural shape (strings locked in section 7):
  `bonused_ehp_excluded_line` for the shared excluded
  count — this block can no longer reuse
  `bonused_resistances_excluded_line`, whose "any
  resistance bonus" wording would understate the deficit
  now that an excluded row's hit point bonus is also
  uncounted; the resistances block keeps using the
  existing helper unchanged — and
  `bonused_ehp_hit_point_unapplied_line` for the new count.
- The renderer doc comment is revised in the same edit to
  describe the numerator change and the three count lines,
  pointing at this document. It renders even when the
  bonused numbers equal the base numbers, and logs nothing,
  as today.

**No other surface changes.** `ship_base_stats` and its
"Ship base values" block (including its Shield/Armor/Hull
HP lines) stay base-only: bonused hit points are shown
nowhere as hit points, only inside these EHP numbers. That
keeps that block's disclosure true, avoids a second set of
headings, disclosures, counts, and oracles for a readout
nobody asked the EHP slice to provide, and keeps
`ship_base_ehp_lines` reuse intact. A bonused-hit-points
readout, if ever wanted, is its own future slice against
this document's helper (which would then need a public
shape designed there, not smuggled here).

## 7. UI wording (locked verbatim)

Same constant names in `src/ui/fittings.rs`, replacement
values. No string calls these numbers fitting "statistics",
a "simulation", or a "tank", and none contains a raw EVE
ID. The doc comments above each constant are revised in
the same edit to describe the new text and point at this
document.

- Heading (`FITTINGS_SHIP_EHP_WITH_BONUSES_HEADING`), today
  "…(with fitted module resistance bonuses, …)":
  `Ship effective hit points (with fitted module resistance and hit point bonuses, omni 25/25/25/25)`
  Both qualifiers are load-bearing: "resistance and hit
  point bonuses" names everything that is applied and
  keeps the block from reading as resistance-only, as
  base, or as a complete fitted total; the named omni
  profile is inherited verbatim from #616.
- Disclosure (`FITTING_SHIP_EHP_WITH_BONUSES_DISCLOSURE`,
  verbatim, always last in the `Available` arm):

> These effective hit points (EHP) use the hull's hit points with the fitted modules' and rigs' hit point bonuses applied, with the fitted modules' and rigs' resistance bonuses above, against omni damage: equal quarters (25% each) of EM, thermal, kinetic, and explosive damage. Every fitted module is counted as active, because the fitting data does not say which modules are on. Ship bonuses, subsystems, skills, implants, and resistance or hit point changes from anything outside this ship are not applied, and a different damage mix would give different numbers, so these numbers can differ from EVE.

  Wording notes (do not rephrase in review): the two
  #616 phrases that become false — "the bare hull's base
  hit points" in the first sentence and "Modules that add
  hit points" heading the not-applied list — are gone, and
  the first sentence now names the hit point bonuses
  before the resistance bonuses because the numerator is
  what changed; "subsystems" stays in the not-applied list
  because category-32 hit point bonuses are not applied in
  this slice (section 9) — that word is the disclosure
  that keeps a fitted subsystem from being silently
  read as counted; "counted as active" is #615's locked
  plain form, repeated verbatim.
- Unavailable sentences (the sibling templates with this
  block's new name; the no-ship-data sentence also drops
  the now-false word "base"):
  - `Ship effective hit points with fitted module resistance and hit point bonuses unavailable: Mimir's bundled item data failed to load.`
  - `Ship effective hit points with fitted module resistance and hit point bonuses unavailable: Mimir's bundled item data has no complete hit point and resistance data for this fitting's ship.`
- Count lines in this block (section 6 helpers):
  - `bonused_ehp_excluded_line(1)`:
    `1 fitted module is not in Mimir's bundled item data, so any resistance or hit point bonus from it is not counted.`
    Plural: `{n} fitted modules are not in Mimir's bundled item data, so any resistance or hit point bonuses from them are not counted.`
  - The resistance unapplied line is
    `bonused_resistances_unapplied_line` verbatim, as
    today.
  - `bonused_ehp_hit_point_unapplied_line(1)`:
    `1 fitted module has a hit point bonus Mimir's bundled item data cannot describe, so that bonus is not applied.`
    Plural: `{n} fitted modules have hit point bonuses Mimir's bundled item data cannot describe, so those bonuses are not applied.`
  - Zero in any count renders no line for that count. The
    three lines are separate per-dimension disclosures;
    no combined "modules not counted" line is added
    anywhere.

**Revision to the #615 disclosure (locked).**
`FITTING_SHIP_RESISTANCES_WITH_BONUSES_DISCLOSURE`
currently ends "…and the effective hit points below are
shown both from the base values and with these resistance
bonuses, so these numbers can differ from EVE." (#616's
revision). The EHP clause is replaced so the constant
reads verbatim:

> These resistances add the fitted modules' and rigs' resistance bonuses from Mimir's bundled item data to the base values above, with stacking penalties where modules of the same kind pile up. Every fitted module is counted as active, because the fitting data does not say which modules are on. Ship bonuses, subsystems, skills, implants, and resistance changes from anything outside this ship are not applied, and the effective hit points below are shown both from the base values and with these resistance bonuses and fitted hit point bonuses, so these numbers can differ from EVE.

Its doc comment is revised in the same edit to describe
the new clause and point at this document. The base
resistances, base EHP, and ship base values disclosures do
not assert anything this slice falsifies and **stay
byte-identical**; the base EHP block's "Fitted modules …
are not applied" stays true of that block, and the base
values block's "not applied" sentence stays true because
bonused hit points are never shown there (section 6).
Only the two disclosures above change, and section 8 names
the existing pins that move with them.

## 8. Test plan (locked)

Tolerance tiers follow the shipped tests: hand-derived
catalogue oracles use absolute tolerance `1e-6` with
literals carrying at least seven decimal places (the
`assert_ehp_close` pattern in `ship_ehp.rs` tests);
identities this design calls exact use `assert_eq`.
Fixture catalogues use the existing `from_json` pattern.
Fixture `hitPointModifiers` entries are written in the
shipped triple shape; no test reads a raw EVE ID into a
rendered-string assertion beyond the fixture inputs the
sibling tests already use.

Base inputs for every oracle below (pinned since earlier
slices): Rifter hit points 450/450/350, base denominators
shield 0.725, armor 0.675, hull 0.67; Punisher hit points
350/500/450, denominators shield 0.725, armor 0.675, hull
0.67. Each oracle shows its division in the test comment,
as the shipped oracles do. Types are fitted in counted
slots of the matching family (extender medium, plate low,
rig rig-slot) at quantity 1 unless stated.

**Oracle 1 — shield extender, flat add (primary).** Rifter
+ Medium Shield Extender II (`[[263, 2, 1100.0]]`). Bonused
shield hit points `450 + 1100 = 1550`; no resistance entry,
so denominators stay base:

| Layer | Bonused HP | EHP |
|---|---|---|
| Shield | 1550 | 1550 / 0.725 = 2137.9310345 |
| Armor | 450 | 450 / 0.675 = 666.6666667 |
| Hull | 350 | 350 / 0.67 = 522.3880597 |
| Total | — | 3326.9857609 |

Counts: excluded 0, resistance unapplied 0, hit point
unapplied 0.

**Oracle 2 — armor plate, flat add.** Punisher + 400mm
Steel Plates II (`[[265, 2, 1200.0]]`). Bonused armor hit
points `500 + 1200 = 1700`: shield 350 / 0.725 =
482.7586207, armor 1700 / 0.675 = 2518.5185185, hull
450 / 0.67 = 671.6417910, total 3672.9189303. Counts all
zero.

**Oracle 3 — adds land before percent.** Rifter + Medium
Shield Extender II + Large Core Defense Field Extender I
(`[[263, 6, 15.0]]`). Bonused shield hit points
`(450 + 1100) × 1.15 = 1782.5` (the wrong association
`450 × 1.15 + 1100 = 1617.5` is the failure this pin
exists to catch): shield 1782.5 / 0.725 = 2458.6206897,
total 3647.6754160 with armor/hull at Oracle 1's values.

**Oracle 4 — multipliers, both directions.** Rifter +
Reinforced Bulkheads II (`[[9, 4, 1.25]]`): hull hit points
`350 × 1.25 = 437.5`, hull EHP 437.5 / 0.67 = 652.9850746.
Second fit, Rifter + Nanofiber Internal Structure II
(`[[9, 4, 0.8]]`): hull `350 × 0.8 = 280`, hull EHP
280 / 0.67 = 417.9104478 — below the base hull EHP
522.3880597, pinning that nothing clamps or floors at
base. A percent-direction companion: Rifter + Large
Transverse Bulkhead I (`[[9, 6, 20.0]]`): hull
`350 × 1.20 = 420`, hull EHP 626.8656716.

**Oracle 5 — numerator and denominator both bonused.**
Rifter + Damage Control II + Medium Shield Extender II.
The extender sets shield hit points 1550; #616's Oracle 1
bonused denominators (shield 0.634375, armor 0.57375, hull
0.402) apply unchanged: shield 1550 / 0.634375 =
2443.3497537, armor 784.3137255, hull 870.6467662, total
4098.3102454. Damage Control II is a hit point non-carrier
(section 3 pin), so armor/hull hit points stay base;
counts all zero.

**Oracle 6 — no stacking penalty, repeated carriers.** Two
fits: Rifter with two Medium Shield Extender IIs in two
medium slots — shield hit points `450 + 1100 + 1100 =
2650`, shield EHP 2650 / 0.725 = 3655.1724138 (adds sum);
Punisher with two Large Trimark Armor Pump Is — armor hit
points `500 × 1.15 × 1.15 = 661.25`, armor EHP 661.25 /
0.675 = 979.6296296. A penalised second rig would give
`1 + 0.15 + 0.15 × penalty(2)` compounding below 1.3225;
the literal pins penalty-freedom (section 2). A stacked
quantity-2 row of one extender equals the two-slot result
(runs are counted in units).

**Helper and pure-function pins:**

1. Oracles 1–6 above, through
   `ship_ehp_with_module_bonuses` on the bundled catalogue,
   including all three counts each time.
2. **Empty fitting equals base EHP, exactly** — `assert_eq`
   on the whole `ShipBaseEhp` against `ship_base_ehp`, all
   counts zero — for: hull-only Rifter and one other
   bundled hull; only non-counted items (cargo/charge
   flags, quantity 0, `type_id <= 0`); a counted
   non-carrier; an all-zero hit point carrier (EM Shield
   Amplifier I: row carries neither hit point key, hit
   point unapplied stays 0); an identity carrier (EM
   Coating I: armor hit points pass through `× 1.0`,
   `ehp` still `assert_eq` base once its resistance entry
   is accounted for — pin through the helper's
   `hit_points` equality or a fixture row with only the
   `[[265, 4, 1.0]]` entry so the whole-EHP `assert_eq`
   applies).
3. **Existing #616 oracles unchanged, exact.** The three
   shipped bonused-EHP oracle fits (Damage Control II,
   total 2364.3200976; Multispectrum Shield Hardener II,
   total 2108.5949563; 2× EM Armor Hardener II, armor
   751.8931661) pin identical literals: none of those
   types carries a hit point triple (Damage Control II is
   a section 3 neither-key pin; the hardener types have no
   hit point modifier in the census), so nothing about
   their numerators changes. Their count assertions gain
   `hit_point_unapplied_modules == 0`. Any drift in these
   literals is a defect in this slice, never licence to
   edit an expectation.
4. **Partial layers.** Fixture with one base hit point
   field absent and a fitted extender targeting that
   layer → layer `None`, total `None`, other two layers
   `Some` and bonused where bonused (no resurrection);
   fixture with one resonance absent mirrors #616's pin
   unchanged; present `0.0` base hit points with an
   extender fitted → layer computes from `(0 + adds)`
   (resurrection of absence and application to a present
   zero are different rules — both pinned).
5. **Unavailable.** Unknown ship id, non-ship row,
   `ship_type_id` 0 and negative; resonances-without-hit-
   points fixture → bonused EHP `Unavailable` while
   bonused resistances are `Available`; hit-points-
   without-resonances → `Unavailable`; helper-level:
   `bonused_hit_points` is `None` exactly on the ship
   gate, `Some` with per-layer `None` otherwise.
6. **Non-finite / hostile (bounded quantities).** Fixture
   percent operand −150 → bonused hit points negative →
   layer `None`, total `None`; percent −100 → bonused
   `0.0` → layer `Some(0.0)`; quantity `i64::MAX` of a
   Trimark rig → percent run goes non-finite through
   `mul_product`'s stop → layer `None`, returns promptly;
   quantity `i64::MAX` of a Nanofiber (mul 0.8) → run
   reaches `0.0` → layer `Some(0.0)`; quantity `i64::MAX`
   of a Medium Shield Extender II → shield hit points are
   the locked formula's `450 + 1100.0 × (i64::MAX as f64)`
   (finite; pinned through the resulting EHP division,
   returns promptly — adds never loop over units);
   non-finite quotient and overflowing total fixtures
   mirror base EHP's; denominator guard with four bonused
   `0.0` resonances → layer EHP equals the *bonused* hit
   points (with an extender fitted, so the pin can tell
   numerator policies apart).
7. **Counts pinned.** Counted row with no catalogue row →
   `excluded_modules` in quantity units (quantity 2
   counts 2), hit point unapplied unchanged; Medium
   Abyssal Shield Extender fitted → `hit_point_unapplied`
   in quantity units, shield layer stays base-numerator
   arithmetic, excluded and resistance unapplied
   unchanged; Capacitor Power Relay II fitted → hit point
   unapplied 1 (the absent-146 family at runtime);
   fixture row marked hit-point-unapplied *with* an
   applicable entry → counted, entry still applied;
   fixture entries with an unsupported operator (0, 3,
   and 7), an unknown modified id, a zero operand, and a
   non-finite operand → each counts its item once in hit
   point unapplied (never twice for two bad entries on
   one item — the once-per-item pin), applicable entries
   still applied; on every fixture here,
   `excluded_modules` and `unapplied_modules` equal those
   from `ship_resistances_with_module_bonuses` (#616's
   `assert_counts_match_resistances` keeps passing; the
   hit point count is asserted separately and is never
   compared to a sum).
8. **Base independence regression.** Fitting an extender
   changes this function and leaves `ship_base_ehp` on the
   same fitting at the base oracles (620.6896552 /
   666.6666667 / 522.3880597, total 1809.7443815) and
   `ship_base_stats` at base hit points.

**Regression gates (unmodified).** Every existing
`ship_resistances.rs`, base-EHP, base-resistances,
resources, and catalogue test passes **unmodified** apart
from the named expectation changes below. The new helper
is additive inside `ship_resistances.rs`; no refactored
shared code may move a #615 literal. Existing bonused-EHP
tests change only where their fit gains a hit point entry
(none of the three oracle fits does — item 3), where they
construct or destructure `BonusedShipEhp` (new field), or
where they pin section 7 wording.

**Catalogue pins.** The section 3 loader invariants
(counts 675/643/32/643, order, operators, spot pins) are
added to `bundled_catalogue_invariants` over the real
bundled asset. The generator commit reports in its body:
twice-run identical sha256, strip-the-two-new-keys
byte-identity against `a2577b6a…`, and the exact new byte
count against the +35,000 budget. Proofs are run once and
reported, not committed as scripts (the #615 pattern).

**UI pins (`src/ui/fittings.rs` tests):**

1. The existing bonused-EHP wording test is updated to pin
   section 7's heading, disclosure, and both unavailable
   sentences verbatim (same constants, new values).
2. `bonused_resistances_wording_and_count_helpers` is
   updated to the revised #615 disclosure string (section
   7) — that constant's second and, for this slice, only
   move.
3. New count-helper pins: `bonused_ehp_excluded_line` and
   `bonused_ehp_hit_point_unapplied_line` at 0 (`None`), 1
   (singular), and 2 (plural) with section 7's exact
   strings; the existing resistance helper pins stand.
4. Lines by construction, as #616: a `BonusedShipEhp`
   fixture (with a non-zero hit point unapplied count)
   rendered through `ship_base_ehp_lines(&bonused.ehp)`
   matches the locked templates; `None` layers omit,
   present `0.0` renders.
5. Demo-story test: the shipped
   `demo_fixture_ship_ehp_with_module_bonuses_match_the_locked_demo_story`
   keeps its `>=`-base-with-one-strictly-greater shape and
   unrounded-sum assertion (design-scripted: none of the
   three demo fittings, nor the EFT/DNA demo samples,
   carries a hit point carrier in a counted slot, so their
   numerators and directions are unchanged), gains
   `hit_point_unapplied_modules == 0` on each checked fit,
   and keeps excluded/resistance-unapplied equality with
   the bonused resistances demo pins.

**Gates (all must pass for every implementation commit):**
`cargo fmt --check`, `cargo clippy --all-targets -- -D
warnings`, `cargo test`, `cargo build`. Commits are small
and atomic, `type(scope): description`, with no
attribution lines. Locked commit sequence after this
design commit (`docs(fitting): design fitted-module hit
point bonuses`): (1) `feat(catalogue): emit fitted-module
hit point modifiers` (generator + regenerated asset, proof
obligations in the body); (2) `feat(fitting): load hit
point modifiers from the catalogue` (loader fields +
invariants); (3) `feat(fitting): compute bonused hit
points for effective hit points` (helper + EHP numerator +
pure tests); (4) `feat(fitting): show hit point bonuses in
effective hit points` (wording, count lines, UI tests).
Each commit passes all four gates alone.

## 9. Exclusions (locked)

Out of this slice, by name: ship (hull role/trait) bonuses
(the 17 category-6 carriers); character skills in any form
(the 3 category-16 carriers — Shield Management, Hull
Upgrades, Mechanics — and Flutter's known-skill percent
table that would join the same percent chain); implants
and boosters (the 100 category-20 carriers); subsystem
hit point and resistance bonuses (the 12 category-32
carriers gain no emission even though subsystem slots are
counted slots — a fitted subsystem is disclosed by the
word "subsystems" in both bonused blocks' not-applied
lists, as today, and grounding its flat-plus-percent
same-attribute pairs is a future design's work, not an
extension of the category-7 predicate here); structure
and NPC carriers; hit point changes from anything outside
the ship (fleet, environment, system effects — the zip's
`system*`/`structureID` shapes); capacitor modifiers of
any kind (attribute 482 is not in the set even where the
same modifier families target it — capacitor batteries and
relays contribute nothing to hit points here beyond the
relay family's own counted shield triple); repair and
boost amounts, shield recharge or capacitor recharge
changes, passive/peak recharge rates, and sustained tank
(no other block's numbers move because hit points grew);
module active/inactive or overheating state (every fitted
module counts as active, as #615 locked); mutated
(abyssal) per-item values — those types ship
counted-not-applied; any damage profile other than the
shipped omni; any bonused-hit-point readout outside the
EHP numerator (no `ship_base_stats` change, no new block,
no public hit point API — the helper is `pub(crate)`);
any change to base EHP, base resistances, #615 bonused
resistances arithmetic or numbers, or the resistance
modifiers' own emission; persistence, ESI, editor, and
network changes; new logging.

Operators outside {2, 4, 6} on hit point attributes are
not deferred-silently: they are locked as
unsupported → unapplied-counted at generation and at
runtime (sections 2–4), which is this slice's complete
answer for them until a future design grounds one.

## 10. Decision record

When this slice merges, `DECISIONS.md` gains an entry in
the implementation PR (not this design commit): "Bonused
EHP numerator: fitted-module bonused hit points" —
recording the section 2 supersession of #616's
base-numerator policy, the no-stacking-penalty finding
with its `_nonStackableAttributes` evidence (the one place
this slice checked a plausible EVE assumption against the
inspected body and found it wrong for hit points), the
category-7-only emission with subsystems deferred, and
the per-dimension count rule (shared excluded, separate
unapplied, never summed). The entry is the implementation
PR's because it records what shipped; this document
records what was decided before building.




