# Module resistance bonuses (first modifier-pipeline slice) — design

Status: locked for the `feat/rust-resistance-bonuses` slice.
Base: `develop` at `3821a58` (1122 tests). Slice branch:
`feat/rust-resistance-bonuses`. This document is the single
design commit on that branch; builders and the integrator
implement exactly what is locked here and nothing else.

This is the first slice of the modifier pipeline: fitted-module
resistance bonuses applied to the shipped **base** resistances
(`docs/ship-resistances-design.md`, rendered by
`render_ship_resistances`). Everything else the pipeline will
eventually carry is deferred by name in section 10.

## 1. Goal and value ranking

Show a second resistances block, "Ship resistances (with fitted
module bonuses)", in both fitting details (the selected saved
fitting and the imported fitting in the Fittings view),
immediately after the shipped base-resistances block and before
the base-EHP block. The bonused block applies only the grounded
fitted-item resistance modifiers of section 2 to the hull's base
resonances: Damage Control multipliers and hardener/coating/rig
percent bonuses, with the stacking penalty exactly as the
Flutter oracle computes it. The base block and the base-EHP
block do not change in any byte (section 7 locks the EHP
decision). No network, no ESI changes, no new scopes, no
persistence, no new catalogue asset: the modifier data is joined
into the existing bundled fitting-types catalogue by its
existing generator (section 3).

Value ranking (locked, in order):

1. **Never show an unlabeled partial total, and never silently
   replace a base figure.** This outranks the rest, as in the
   ship skill-applied resources precedent
   (`docs/fitting-skill-resources-design.md` section 1, shipped
   through #577/#607). The bonused numbers live in their own
   block under their own heading; the base block above them is
   byte-identical to today. Every fitted item whose resistance
   bonus cannot be applied from the bundled data is counted in
   the view (section 4), and the disclosure states in plain
   words that every fitted module is counted as active, because
   the data carries no module state (section 6). A bonused
   resistance a reader mistakes for a complete fitted tank, or
   a module silently counted as zero bonus, is the failure this
   slice exists to avoid.
2. **Correctness of the arithmetic.** The operator set, the
   mul-before-percent order, the penalty chain (sort, indexing,
   constant), and the absent/zero-operand skip must be
   hand-verifiable against the inspected Flutter bodies and the
   scripted catalogue join (sections 2, 3, and 8). Where this
   slice deliberately diverges from Flutter (silent defaults,
   section 4), the divergence is stated and pinned, never
   smuggled.
3. **Reuse.** The catalogue generator's additive-emission
   pattern, the loader's optional-field shape, the existing
   `ShipResistances`/`ResistLayer` types and line renderer, the
   resources block's excluded-count shape, and the one fitting
   number formatter beat new machinery (sections 3–6).

Non-goals are locked in section 10. In particular: no EHP from
bonused resistances, no ship traits, no skills, no implants, no
non-resistance attributes, no module state (online/active)
modelling, no simulator language anywhere.

## 2. Modifier set and arithmetic (locked)

Every identifier, operator code, formula, and count below traces
to an inspected body: Flutter `dogma_engine.dart` /
`models.dart` / `dogma_attributes.dart` and its tests at commit
`ed698d3` (via `git show`), `dogmaEffects.jsonl` inside the
committed `scripts/sde/eve-online-static-data-3503375-jsonl.zip`,
the committed fuzzwork caches under `scripts/sde/*.csv.bz2`, or
the current Rust tree. Nothing comes from memory.

**Grounded modifier shape (locked — ships, the whole set).** A
fitted item contributes a resistance modifier only when all of
these hold:

- its catalogue row is category 7 (module; this includes rigs,
  which are category-7 rows with slot effect 2663 — resistance
  rigs are therefore in scope as fitted items, section 3);
- one of its effects (joined through `dgmTypeEffects.csv.bz2`)
  carries a modifier with `func == ItemModifier` and
  `domain == shipID`;
- that modifier's modified attribute is one of the twelve ship
  resonances (shield 271/274/273/272, armor 267/270/269/268,
  hull 113/110/109/111, EM/thermal/kinetic/explosive within each
  layer — `dogma_attributes.dart:14-31` at `ed698d3`, the same
  table the base slice locked);
- its operator is `0` (postMul) or `6` (postPercent);
- the operand — the item type's own `dgmTypeAttributes` value
  for the modifier's modifying attribute — is present and not
  `0.0`.

Scripted over the committed data during design (zip
`modifierInfo` ⋈ `dgmTypeEffects` ⋈ `dgmTypeAttributes` ⋈ the
current catalogue), this grounds **799 category-7 carrier
types**, of which **777 carry at least one applicable entry**,
for **1,332 applicable entries** total (288 operator-0 operands
in [0.475, 0.98]; 1,044 operator-6 operands in [−64.0, −9.84]).
No carrier type has two applicable entries on the same modified
attribute. Worked shapes: Damage Control II (2048, effect 2302)
→ twelve operator-0 entries (armor 0.85 ← attributes 267–270
self-mapped, shield 0.875 ← 271–274 self-mapped, hull 0.6 ←
974–977); Multispectrum Shield Hardener II (2281, effect 5230)
→ four operator-6 entries at −32.5 ← 984–987; EM Armor Hardener
II (11642, effect 5231) → one entry (−55.0 on armor EM), its
other three operands being explicit `0.0`; Large EM Armor
Reinforcer I (25736, rig, effect 2792) → one entry (−30.0 on
armor EM), its other three operands absent. Absent and explicit
-zero operands are therefore both normal SDE patterns for "no
bonus on this damage type" and are skipped identically —
Flutter skips both in one check (`base == null || base == 0`)
before any routing (`dogma_engine.dart` `routeOwnerModifiers`
at `ed698d3`). Section 3 locks how the two must nonetheless be
distinguished when **every** operand on a carrier is absent.

**Shapes that ship nothing (locked).** Everything outside the
shape above contributes no entry, and the reasons are data, not
taste:

- Any other `func`
  (`LocationRequiredSkillModifier`, `OwnerRequiredSkillModifier`,
  `LocationGroupModifier`, `LocationModifier`) or `domain`
  (`charID`, `itemID`, `otherID`, `structureID`, `targetID`):
  in the committed data every one of the resonance-targeting
  modifiers is `ItemModifier`; the eight `itemID` resonance
  entries (effect 7012, Assault Damage Control family) target
  the module itself and Flutter never routes `itemID` to the
  ship. One zip-only `LocationGroupModifier` effect (3160,
  hull, operator 0) exists in `dogmaEffects.jsonl`; it sits on
  no category-7 catalogue type with a present operand, so
  excluding the shape loses nothing today (scripted, section 3).
- Operators `-1, 2, 3, 4, 5, 9` on resonances: add/subtract
  (2/3) and postMulAlt (4) are defined by Flutter for other
  attributes but never target a resonance in the committed data
  or its tests; `-1`, `5`, `9` have no in-repo meaning at all.
- Operators `7`: present on resonances (zip: 32 `shipID`
  entries over effects 5983/5986/5994/5995/6348, plus the 8
  `itemID` entries of 7012), and **Flutter applies nothing for
  them**: the `ItemModifier`/`shipID` route falls through to
  `unsupportedOperators++` for any operator outside
  `{0, 2, 3, 4, 6}`. Parity therefore means *counted, not
  applied*: a carrier whose only present-operand resonance
  entries are operator 7 is the unapplied case of sections 3–6.
  Today that is exactly the twelve Polarized weapon types
  (34272–34294; twelve present operands each, values 1.0 and
  100.0). Inventing operator-7 math (whatever EVE does with it)
  would exceed what any inspected body grounds; silently
  dropping a fitted Polarized weapon's known resistance effect
  would breach rank 1. Counted-not-applied is the only honest
  middle state, and it mirrors Flutter's own counter.
- Carriers outside category 7: the same join finds 86
  category-6 (ship trait) and 10 category-20 (implant/booster)
  carrier rows in the catalogue. They are not fitted modules;
  ship traits and implants are deferred by name (section 10)
  and gain no emission.

**Arithmetic (locked, Flutter ship path verbatim).** For each
of the twelve resonances independently:

```text
bonused resonance = base resonance × Π (operator-0 operands)
                                   × percent_chain(operator-6 operands)
percent_chain(values):
    sort by |value| descending
    factor = Π over i (0-based) of (1 + (sorted[i] / 100) × penalty(i + 1))
    penalty(n) = 1.0 for n <= 1, else exp(-(((n - 1) / 2.67)²))
resist % = (1 − bonused resonance) × 100
```

Sources: operator codes `_postMul = 0`, `_postPercent = 6`
(`dogma_engine.dart:26-34`); ship final value
`(base + Σ adds) × Π mul × chain(percent)` — resonances take no
adds in any fixture or in the data, so the adds term is absent
here; `_percentChain` sorts `b.abs().compareTo(a.abs())` and
applies `getStackingPenalty(i + 1)` per item because exactly
the twelve resonances are `_nonStackableAttributes`
(`dogma_engine.dart:112-128, 162-178`); `toResist` is the base
slice's locked conversion (`dogma_engine.dart:856-858`).
Locked consequences builders must not "improve":

- **Mul is unpenalized and unsorted; percent is penalized.**
  Two Damage Controls multiply straight through; two hardeners
  take the chain. The separate penalized `>1`/`<1` mul chains
  in Flutter (`_applyBonuses`/`_penalizedChain`) serve
  module/charge attributes only and must not be used here.
- **Order is mul first, then the percent chain**, and within
  the chain, descending absolute value — a fit listing
  −25 before −55 computes as if −55 came first (section 8 pins
  both).
- **No clamping anywhere**, mirroring the base slice: a bonused
  resonance above 1 renders its true negative percentage; a
  computed resonance that is negative or non-finite, or whose
  percentage is non-finite, is no data for that one resistance
  (the base slice's `resonance_to_percent` rule, reused —
  section 4). On today's operands (mul in [0.475, 0.98],
  percent in [−64, −9.84], chain factors in (0, 1]) a negative
  bonused resonance is unreachable from a usable base; the rule
  exists for fixtures and future data, stated here so it is
  never a silent clamp.
- **No module state.** Flutter skips only `offline` modules
  (`ModuleState`, `models.dart:8`; engine gate at
  `dogma_engine.dart:687-750`) and treats online, active, and
  overloaded identically. Rust fitting rows carry no state
  field at all (`FittingItem { flag, quantity, type_id }`,
  `src/esi/models.rs`; `ImportedItem`, `src/fitting/eft.rs`),
  so this slice cannot gate hardeners (an activated module
  family — effect 5230 is `effectCategoryID 1` in the zip where
  the passive coating effect 2041 is `4`) by anything. Every
  counted fitted item contributes as if active. That assumption
  is user-visible wording, locked verbatim in section 6 — it is
  the single largest honesty load in this slice.

## 3. Catalogue extension (locked)

The bundled catalogue gains per-type resistance-modifier
entries through its existing generator only. Hand-editing the
JSON is forbidden, as with every generated asset in this repo.
Catalogue today: 3,798,320 bytes, sha256
`98917a44d0bc004c41b3ce5df064f383fee06eadbfa6a37d35457ee6aa765800`.

**New generator input (locked): the committed SDE zip.** The
effect→modifier leg exists in no committed fuzzwork cache (the
caches carry no `modifierInfo`); `generate_fitting_types_sde.py`
therefore gains one new read: `dogmaEffects.jsonl` inside
`scripts/sde/eve-online-static-data-3503375-jsonl.zip`
(`modifierInfo` entries keyed `domain`, `func`,
`modifiedAttributeID`, `modifyingAttributeID`, `operation` —
note the zip's spelling differs from the fuzzwork-derived
`assets/sde/effect_modifiers.json`). Reading that committed
zip is the established pattern of the sibling generators
(`generate_exploration_sde.py`,
`generate_planet_schematics_sde.py` read the same archive);
the generator still never downloads, and a missing or
unreadable zip is a loud `fail(...)` before anything is
written, as a missing cache already is. The header comment of
the generator must be updated to name the zip as an input for
this one leg.
`assets/sde/effect_modifiers.json` was considered and rejected
as the input: it is itself generated by
`scripts/sde/generate_dogma_sde.py` from a network download
whose CSVs are not committed, so the catalogue would stop
being regenerable from committed files alone. The two sources
were scripted against each other during design: the zip
carries 448 resonance-targeting entries to the fuzzwork
file's 304 (the 144 zip-only entries are operator
7/5/−1/4 shapes, the `LocationGroupModifier` effect 3160, and
NPC/structure operator-6 effects), and the **applicable set is
identical** — restricted to category-7 catalogue types with a
present, non-zero operand and operator in {0, 6}, zip and
fuzzwork yield the same entries for every one of the 777
types, zero differences. Choosing the zip therefore costs no
Flutter parity on today's data, and the generator oracles
below pin the join either way. The runtime still never reads
the zip, the caches, `effect_modifiers.json`, or `dogma.json`.

**Generator changes** (`scripts/sde/generate_fitting_types_sde.py`,
3,607 lines today):

- Beside `RESIST_ATTR_IDS`, add the locked ordering list (the
  base slice's display order — shield, armor, hull; EM,
  thermal, kinetic, explosive within a layer) and a provenance
  comment citing `dogmaEffects.jsonl`, the two caches, and
  Flutter `dogma_engine.dart` at `ed698d3` for the operator
  codes and the absent/zero skip:

  ```python
  RESIST_MODIFIER_ORDER = [271, 274, 273, 272, 267, 270, 269, 268,
                           113, 110, 109, 111]
  RESIST_MODIFIER_OPERATORS = {0, 6}
  ```

- Build the per-type entry map from the three joined sources,
  for category-7 types only, classifying every
  `ItemModifier`/`shipID` resonance modifier of every effect
  on the type (deduplicated by (modified, modifying,
  operator)) as exactly one of:
  - **applicable**: operator in {0, 6} and operand present,
    finite, and not `0.0` → an emitted entry;
  - **unsupported**: operator outside {0, 6} and operand
    present and not `0.0` → no entry; marks the type
    unapplied (below);
  - **zero**: operand present and exactly `0.0` → no entry,
    no mark (provably no bonus; Flutter skips it identically);
  - **absent**: operand not in the cache for this type → no
    entry; marks the type unapplied **only if the type ends
    with no applicable entry and no zero classification**
    (below).
- Loud failures, house style (`fail(...)`, writes nothing): an
  unparseable or non-finite operand value on a classified
  modifier; a duplicated (modified, modifying, operator)
  triple on one type; two applicable entries on one type
  sharing a modified attribute. The last two are zero on
  today's data (scripted); Flutter would silently double-apply
  a duplicated triple, and this slice follows the house
  precedent instead — a future SDE refresh that introduces one
  stops generation for review rather than shipping a doubled
  or ambiguous bonus. Messages say "resistance modifier",
  never "resource" or "base stat". Deliberately **not**
  failures: operand values outside today's observed ranges
  (a positive percent operand or a mul operand above 1 is
  arithmetic the locked formulas already define), absent
  operands (189 on today's carriers), and zero operands
  (1,835).
- **Emission (locked shape).** Additive and sparse, category 7
  only, all existing keys byte-stable and every non-category-7
  row byte-identical to today. A carrier type emits the key
  `resistanceModifiers` iff it has at least one applicable
  entry **or** is marked unapplied. The value is a JSON array
  of `[modifiedAttributeId, operator, operand]` triples
  (numbers, compact separators), sorted by
  `RESIST_MODIFIER_ORDER`, with the operand baked in at
  generation time — the modifying attribute id is deliberately
  not emitted: no runtime consumer may re-derive the operand
  (module rows do not carry their 984–987/974–977 attributes,
  and the catalogue is the one place the join is proven). A
  type marked unapplied additionally emits
  `resistanceModifiersUnapplied: true` beside the (possibly
  empty) array. A carrier whose modifiers are all classed
  zero — today the ten Layered Coating / Layered Energized
  Membrane types (1272/1274/1276, 11235/11237/11239, 16345,
  16423, and kin), whose resonance operands are explicitly
  `0.0` — emits **neither key**: its bonus is provably zero
  from present data, indistinguishable at runtime from a
  non-carrier, and counting it as unapplied would be a false
  alarm. The full unapplied predicate (locked): a category-7
  type with at least one `ItemModifier`/`shipID` resonance
  modifier is unapplied-marked iff (a) any modifier classed
  unsupported, or (b) it has no applicable entry, no zero
  classification, and at least one absent classification.
  Today that marks exactly **14 types** — the twelve Polarized
  weapons (unsupported, operator 7) and the two Abyssal
  Damage Controls 52227/52230 (all twelve operands absent:
  their real bonuses are mutated per-item values the SDE type
  rows do not carry, which is precisely the "modifier data is
  absent" case rank 1 names). A type with applicable entries
  plus absent ones (today exactly 55 types, all of them rigs)
  is **not**
  marked: the absent slots are the SDE's normal way of saying
  "not this damage type", exactly as Flutter reads them. A
  type with applicable entries plus an unsupported one would
  be marked (zero such types today; the rule is locked anyway,
  and section 4 counts it while still applying its entries).
  Key placement follows the generator's locked construction
  order: after the last existing per-type key block, so
  pre-existing key order on every row is untouched.
- **Self-validation.** A `RESIST_MODIFIER_ORACLES` list beside
  `RESIST_ORACLES` (line 535), tuple shape
  `(type_id, expected_entries_or_None, expected_unapplied)`
  where `None` means neither key may be present. Values are
  cache/zip reads from design (section 8 gives the arithmetic
  they feed):
  - 2048 Damage Control II: the twelve operator-0 entries
    (shield 0.875 ×4, armor 0.85 ×4, hull 0.6 ×4), unapplied
    false.
  - 2281 Multispectrum Shield Hardener II: four entries,
    `[shield attrs, 6, -32.5]`; 578 (I): `-25.0`.
  - 1306 Multispectrum Coating II: four armor entries at
    `-15.36`; 1197 EM Coating I: one entry `[267, 6, -24.32]`
    (the zero-operand skip pin).
  - 11642 EM Armor Hardener II: one entry `[267, 6, -55.0]`.
  - 25736 Large EM Armor Reinforcer I: one entry
    `[267, 6, -30.0]`, unapplied false (the absent-operand
    partial-carrier pin).
  - 2050 Gistum C-Type Multispectrum Shield Hardener: four
    shield entries at `-37.5` (the demo pin, section 8).
  - 34272 Polarized Small Focused Pulse Laser: empty array,
    unapplied true (the operator-7 pin).
  - 52227 Abyssal Damage Control and 52230 Abyssal Assault
    Damage Control: empty array, unapplied true (the
    all-operands-absent pin).
  - 1272 'Basic' Layered Coating: neither key (the all-zero
    pin).
  - 587 Rifter (category 6) and 2456 Hobgoblin II
    (category 18): neither key (the category-gate pin — the
    Rifter row proves ship-trait carriers gain nothing).
- **Catalogue-wide invariants** beside the resist checks
  (around line 2674): every present `resistanceModifiers`
  value is on a category-7 row; its entries have modified ids
  in `RESIST_MODIFIER_ORDER`, strictly sorted by that order
  with no duplicate modified id, operators in {0, 6}, operands
  finite and not `0.0`; `resistanceModifiersUnapplied` appears
  only beside `resistanceModifiers` and only as `true`; the
  counts of rows carrying entries, rows marked unapplied, and
  total entries equal the design-scripted values for today's
  data (791 rows with the key — 777 with entries plus 14
  marked-empty; 14 marked; 1,332 entries). The summary print
  gains those three counts beside the resist print.
- Determinism unchanged: types sorted by `typeId`, compact
  separators, trailing newline, no timestamps. Proof
  obligations for Builder A (section 8): run the generator
  twice → identical sha256; strip the two new keys →
  byte-identical to today's `98917a44…`. Both proofs are run
  once and reported in the commit body, not committed as
  scripts.

**Size budget.** A simulation of the locked emission over the
real joined data (791 keyed rows, 1,332 triples, compact
separators) adds ≈38,000 bytes (≈ +1.0%). Budget: the
regenerated file must land within **+50,000 bytes** of today's
3,798,320; Builder A states the exact new byte count in the
commit body. Verbatim modifier objects (+376,860 measured
during discovery) and a `modified → value` map (which cannot
express the operator, the one fact the math needs) were both
rejected; the triple array is the cheapest shape that carries
exactly the locked semantics. Anything over budget means the
emission rule drifted (for example emitting zero operands —
1,835 wait — or emitting on non-category-7 rows) and stops
the slice for review.

**Rust loader** (`src/names/fitting_types.rs`). `FittingType`
gains, after the twelve resonance fields:

```rust
#[serde(rename = "resistanceModifiers", default)]
pub resistance_modifiers: Option<Vec<ResistanceModifier>>,
#[serde(rename = "resistanceModifiersUnapplied", default)]
pub resistance_modifiers_unapplied: bool,
```

with one new tuple struct in the same module,
`ResistanceModifier { pub modified_attribute_id: i64, pub operator: i64, pub operand: f64 }`,
deserialized from the 3-element array. A doc comment pins the
semantics: entries are generation-time-proven
`ItemModifier`/`shipID` resonance bonuses with the operand
baked in; `Some(empty)` with the unapplied flag is a carrier
whose bonus the bundled data cannot ground and must be
counted, never read as "no bonus"; `None` is a non-carrier or
an all-zero carrier. `#[serde(default)]` keeps old assets and
`from_json` fixtures loading as `None`/`false`. Nothing is
validated at load (the pure function guards values, section 4;
the invariants test proves the shipped asset), matching every
sibling field. No code constructs `FittingType` literals, so
no fixture churn.

**Invariants to add** to `bundled_catalogue_invariants`
(`src/names/fitting_types.rs:589`), all over the real bundled
asset: `resistance_modifiers` is `Some` only on category-7
rows; exactly 791 rows carry it, 777 non-empty, 14 marked
unapplied, 1,332 entries total; every entry's modified id is
one of the twelve resonances, entries per row are in the
locked order with no duplicate modified id, operator is 0 or
6, operand finite and `!= 0.0`; spot pins mirroring the
generator oracles (2048's twelve entries in order, 2281 at
−32.5, 1197's single entry, 25736's single entry with flag
false, 2050 at −37.5, 34272 and 52227/52230 empty with flag
true, 1272 `None`, 587 `None`). The existing invariants pass
unmodified.

## 4. Pure API (locked)

All new computation lives in `src/fitting/ship_resistances.rs`
beside the base function — it reuses `ResistLayer`,
`ShipResistances`, and the private `resonance_to_percent`, and
a second module would force an artificial resonance/percent
split. Re-exported from `src/fitting/mod.rs` beside
`ship_resistances`. The existing `ship_resistances(fitting,
catalogue)` keeps its signature and its exact base-only
semantics — its locked tests pass unmodified. The module
header docs must be updated: the current header says "No
modifier of any kind is applied", which becomes false for the
new entry point; the rewrite states both entry points
precisely (base function unchanged; bonused function applies
only the section 2 fitted-item entries), in the pattern of the
resources header rewrite locked by the skill-resources design.

```rust
/// Bonused resistances plus the fitted-module counts the
/// caller must disclose beside them.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BonusedShipResistances {
    pub resistances: ShipResistances,
    /// Counted fitted rows with no catalogue row at all, so
    /// no resistance bonus can be proven or disproven for
    /// them. Counted in quantity units, never silently zero.
    pub excluded_modules: usize,
    /// Counted fitted rows the catalogue marks as resistance
    /// carriers whose bonus cannot be applied from the
    /// bundled data (unsupported operator with a present
    /// operand, or every operand absent), in quantity units.
    /// Their applicable entries, if any, are still applied.
    pub unapplied_modules: usize,
}

/// Bonused resistances outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BonusedShipResistancesOutcome {
    Available(BonusedShipResistances),
    /// The catalogue has no usable resistance data for this
    /// fitting's ship, so no honest numbers exist.
    Unavailable,
}

pub fn ship_resistances_with_module_bonuses(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> BonusedShipResistancesOutcome;

/// Stacking penalty for the n-th (1-indexed) percent modifier
/// on one resonance: 1.0 for n <= 1, else
/// exp(-(((n - 1) / 2.67)²)). Provenance: Flutter
/// `getStackingPenalty` at `ed698d3`.
pub fn resistance_stacking_penalty(n: usize) -> f64;
```

The entry-point name follows the shipped parallel
(`fitting_resources_with_skills`); the penalty helper is
public for the same reason Flutter's is tested directly (its
table is an oracle, section 8). Locked semantics:

- `Unavailable` exactly when `ship_resistances` is
  `Unavailable`: `ship_type_id <= 0`, no catalogue row, row
  not category 6, or every one of the twelve **bonused**
  resistances unusable (the all-absent collapse evaluated
  after bonuses; on any input where bonuses change nothing
  this coincides with the base collapse). No error channel;
  the function never panics.
- Per-resistance computation: start from the ship row's base
  resonance. A base resonance that is absent, non-finite, or
  negative yields `None` for that resistance **even if a
  fitted module modifies it** — Flutter's engine defaults a
  missing ship resonance to 1.0 (`attr(id, 1.0)`) and would
  bonus the invented value; the base slice already rejected
  that silent default and this slice keeps the rejection
  (stated divergence, fixture-pinned). Otherwise:
  `base × Π operator-0 operands × percent_chain(...)` per
  section 2, then the existing `resonance_to_percent` on the
  result — so a negative or non-finite bonused resonance is
  `None` for that one resistance, exactly the base guard.
  Per-resistance independence otherwise holds: one unusable
  resonance never blanks the other eleven.
- **Counted items.** An item is counted when `type_id > 0`,
  `quantity.max(0) > 0`, and its flag starts with `LoSlot`,
  `MedSlot`, `HiSlot`, `RigSlot`, or `SubSystemSlot` — the
  resources consuming-flag rule widened by the two fitted
  sections Flutter's `Fitting.allModules` also iterates (rigs
  carry real entries; subsystem rows carry none today but
  counting the flag keeps the rule equal to "every fitted
  section", so a future subsystem entry cannot slip past
  silently). Charges, drones, fighters, cargo, and every
  other flag never count. Items with `type_id <= 0` or
  `quantity <= 0` are skipped and counted nowhere (the
  resources precedent verbatim).
- **Per counted item**, in quantity units
  (`usize::try_from(quantity).unwrap_or(0)`, saturating adds —
  the resources precedent):
  - no catalogue row → `excluded_modules += units`;
  - row with `resistance_modifiers_unapplied` →
    `unapplied_modules += units` (checked before applying,
    so a future mixed carrier is both applied-where-grounded
    and counted — an excluded/unapplied row is never double-
    counted across the two counters, mirroring resources'
    "excluded first" rule);
  - row's entries (if any) contribute **once per quantity
    unit** — a stacked row of two identical hardeners chains
    two instances, as two rows would. A row that exists but
    carries no key (non-carrier, all-zero carrier, or any
    non-category-7 row fitted in a counted flag — a blueprint
    in a mid slot) contributes nothing and is counted nowhere:
    absence of the key is the catalogue's proven "no grounded
    bonus", not missing data. This is a deliberate divergence
    from the resources rule (where a present row with no `cpu`
    value is excluded): a CPU need exists for every consuming
    module, but most modules honestly have no resistance
    bonus, and counting them all as excluded would make the
    disclosure noise. Stated here, pinned in section 8.
  - Defensive operand guard: an entry whose operand is
    non-finite or exactly `0.0`, or whose operator is not 0
    or 6 (all impossible on the shipped asset by the section
    3 invariants; reachable through `from_json` fixtures or a
    future malformed asset), marks that item unapplied
    (counted once per unit, not once per bad entry) and that
    entry is skipped; the item's remaining entries still
    apply. An entry whose modified id is not one of the
    twelve is skipped and likewise marks the item unapplied.
    The pure layer never trusts the asset's invariants for
    correctness, only for the counts being zero in production.
- **Bounded hostile quantity.** Contribution expansion must
  not allocate or loop per unit without bound: the percent
  chain accumulates (value, count) runs over sorted distinct
  values and may stop once `resistance_stacking_penalty`
  reaches exactly `0.0` in `f64` (every later factor is then
  exactly `1.0` for any finite value — this is the locked
  arithmetic, not an approximation); the mul product
  multiplies per unit but stops once the running product is
  `0.0` or non-finite (the result is already decided:
  `0.0` resonance or the no-data guard). A fixture with
  `quantity = i64::MAX` returns promptly (section 8).
- With no counted items, or counted items carrying no
  entries, `Available` resistances equal the base function's
  percentages exactly (same conversion path) — the bonused
  block renders base numbers with bonused wording rather than
  vanishing (section 5).
- **No logging in the pure function**, as in every sibling:
  render cadence, `[FITTING]` counts-only. This slice adds no
  runtime log lines anywhere; its observables are the rendered
  block, the generator prints, and the catalogue-load counts
  that already exist.

## 5. Display (locked)

A new renderer `render_ship_resistances_with_module_bonuses`
in `src/ui/fittings.rs`, beside `render_ship_resistances`
(line 2322), sharing `ship_resistance_lines` unchanged — the
bonused `ShipResistances` feeds the same line templates, so
segment order, omission of `None` segments, and
`format_fitting_percent` rendering are identical by
construction. It is called at both existing detail sites
(saved `src/ui/fittings.rs:3979`, imported `:3670` area)
**immediately after** `render_ship_resistances` and
**immediately before** `render_ship_base_ehp`, so the reading
order is base resistances → bonused resistances → base EHP.
No existing renderer, heading, disclosure, or call order
changes; the base block's tests pass unmodified.

Rendering rules, mirroring the sibling blocks:

- The heading always renders (never silently omit the
  feature). `fitting_types` `None` → heading + the bonused
  no-catalogue sentence (section 6). `Unavailable` → heading
  + the bonused no-ship-data sentence. `Available` → heading,
  the resistance lines, the excluded line if any, the
  unapplied line if any, then the disclosure last.
- `Available` renders **even when the bonused numbers equal
  the base numbers** (hull-only fit, or no fitted carrier):
  the skill-resources precedent (applied block at level 0)
  locked that a computed-and-checked state is a fact the view
  can state, and quietly dropping the block would leave the
  base disclosure's "fitted modules … are not applied" as the
  last word on a fit whose modules were in fact checked.
  Suppressing the duplicate-looking lines was considered and
  rejected for exactly that reason.
- Excluded/unapplied lines are pure helpers in the
  `cpu_excluded_line` pattern (`src/ui/fittings.rs:1952`):
  `None` at 0, singular at 1, plural above (section 6).

## 6. UI wording (locked verbatim)

Flutter labels nothing about its fitted resistances, so this
wording is new, in the view's existing plain voice. No string
in this slice calls these numbers fitting "statistics", a
"simulation", or a "tank".

- Heading: `Ship resistances (with fitted module bonuses)`
- Excluded line (helper, `n = excluded_modules`):
  - 1: `1 fitted module is not in Mimir's bundled item data, so any resistance bonus from it is not counted.`
  - n: `{n} fitted modules are not in Mimir's bundled item data, so any resistance bonuses from them are not counted.`
- Unapplied line (helper, `n = unapplied_modules`):
  - 1: `1 fitted module has a resistance bonus Mimir's bundled item data cannot describe, so that bonus is not applied.`
  - n: `{n} fitted modules have resistance bonuses Mimir's bundled item data cannot describe, so those bonuses are not applied.`
- Disclosure (verbatim, always last in the `Available` arm):

> These resistances add the fitted modules' and rigs' resistance bonuses from Mimir's bundled item data to the base values above, with stacking penalties where modules of the same kind pile up. Every fitted module is counted as active, because the fitting data does not say which modules are on. Ship bonuses, subsystems, skills, implants, and resistance changes from anything outside this ship are not applied, and the effective hit points below still use only the base values, so these numbers can differ from EVE.

- Unavailable sentences (the sibling templates with this
  block's own name, so no heading ever sits over another
  block's sentence):
  - `Ship resistances with fitted module bonuses unavailable: Mimir's bundled item data failed to load.`
  - `Ship resistances with fitted module bonuses unavailable: Mimir's bundled item data has no resistance data for this fitting's ship.`

Wording notes (load-bearing, do not rephrase in review):
"counted as active" is the plain form of section 2's module-state
assumption — it must stay in the disclosure, not a tooltip;
"resistance changes from anything outside this ship" names
fleet/environment effects without EVE jargon; the EHP clause
is required by section 7 and must name the below block so the
two number sets are never cross-read.

## 7. EHP decision (locked: EHP stays base in this slice)

`ship_base_ehp` and its block are **unchanged**: same function,
same heading ("base values, omni 25/25/25/25"), same
disclosure, same numbers. A bonused-resistances EHP was
considered and deferred by name (section 10), for three
recorded reasons:

1. **It would be a partial total of the exact kind rank 1
   forbids.** EHP divides hit points by weighted resonances.
   This slice bonuses only the denominator; the numerator
   would remain bare-hull HP (shield extenders, armor plates,
   HP rigs, and subsystem HP all modify *different* attributes
   through the same pipeline, none of them grounded or emitted
   here). A single "EHP" figure mixing bonused resistances
   with base HP reads as a fitted tank total no matter how it
   is labelled — worse than either honest input alone.
2. **The active-module assumption would compound invisibly.**
   In the bonused block the assumption is stated beside twelve
   percentages a reader can sanity-check against the base
   block above; folded into one EHP number it becomes
   unrecoverable.
3. **House precedent ships one honest block at a time.** The
   #578 decision (each attribute block is its own heading plus
   disclosure, available independently) and the skill-resources
   slice (outputs applied, needs left for their own slice)
   both chose the smaller true statement over the bigger mixed
   one. Flutter does recompute EHP from bonused resonances
   (`dogma_engine.dart:881-904` feeding `damage_pattern.dart`
   `_layerEhp`), and its E0b oracle (section 8) is recorded
   here so the future slice starts grounded — parity of the
   *formula* is not in dispute, only the slice boundary.

Consequence for the view: the bonused disclosure (section 6)
must say the EHP below still uses only base values; the EHP
block's own disclosure already says fitted modules are not
applied, which stays true word-for-word. When the deferred
slice ships HP-modifying pipeline data, EHP-from-bonused gets
its own design and its own block; nothing here pre-commits its
wording.

## 8. Test plan (locked)

Oracle sources, labelled as the sibling designs require:
Flutter `dogma_modifiers_test.dart` / `dogma_engine_test.dart`
at `ed698d3` use a **synthetic** Rifter fixture (shield
resonances 1.0/0.5/0.6/0.8 EM/thermal/kinetic/explosive in
test-helper order, armor 0.4/0.9/0.75/0.65, hull 1.0×4 — note
its explosive/kinetic helper ordering differs from the real
catalogue rows; transcribe per-attribute, never positionally);
Rust pins reproduce the synthetic cases through `from_json`
fixtures labelled synthetic, and pin the **real** bundled rows
separately. Flutter's `real_sde_defense_test.dart` T8.2 and
E0b use real SDE values that match this catalogue's Rifter
(587: shield 1.0/0.8/0.6/0.5, armor 0.4/0.65/0.75/0.9 EM/
thermal/kinetic/explosive, hull 0.67×4).

**Penalty oracle** (`dogma_engine_test.dart:17-24`, locked
literals): n = 1…6 → 1.0, 0.869, 0.571, 0.283, 0.106, 0.030.
Pin `resistance_stacking_penalty` to those within 1e-3, and
n = 2 exactly: `exp(-(1/2.67)^2) = 0.86911998…` within 1e-9.
n = 0 behaves as n <= 1 (Flutter's guard; pinned so the Rust
signature taking `usize` cannot drift).

**Synthetic Flutter oracles** (via fixtures carrying
`resistanceModifiers` triples directly, labelled synthetic;
floats within 1e-9 unless a string pin is stated):

- Single hardener: base shield EM 1.0 with entry
  `[271, 6, -55.0]` → `1.0 × (1 − 0.55) = 0.45` → **55.0%**;
  untouched thermal 0.5 → 50.0% (`dogma_modifiers_test.dart:56-100`).
- Single Damage Control: armor EM 0.4 × 0.85 = 0.34 →
  **66.0%** (`:102-152`).
- Stacked hardeners −55, −50 on 1.0: chain
  `(1 − 0.55) × (1 − 0.50 × 0.86911998…) = 0.25444800…` →
  **74.5552%** (design-computed; Flutter asserts the range
  (55.0, unpenalized cap), Rust pins the exact value its
  formula produces) (`:154-239`).
- Sort pin (mutation-sensitive): the same two entries fitted
  in reverse item order [−25 module first, −55 second] on
  base 1.0 → chain `0.35222400…` → **64.7776%**, identical to
  fitting them in the other order; an insertion-order chain
  gives a different number and must fail this pin.
- Unpenalized mul pin: two modules each `[267, 0, 0.85]` on
  armor EM 0.4 → `0.4 × 0.85 × 0.85 = 0.289` → **71.1%**; any
  penalty on the mul path fails this.
- No-modifier fit: bonused == base, counts 0 (the
  `:241-263` offline-data shape).

**Real-row pins** (`src/fitting/ship_resistances.rs`, Builder
A; Rifter 587 unless stated):

- Rifter + Damage Control II (2048) in `LoSlot0`: shield
  12.5/30.0/47.5/56.25, armor 66.0/44.75/36.25/23.5, hull
  59.8×4 — hull EM cross-checks Flutter's real-SDE T8.2
  (**59.8%**) and E0b. Counts 0/0.
- Rifter + Multispectrum Shield Hardener II (2281): shield
  32.5/46.0/59.5/66.25; armor and hull equal base.
- Rifter + two EM Armor Hardener II (11642): armor EM
  `0.4 × 0.45 × (1 − 0.55 × 0.86911998…) = 0.093957…` →
  **90.6043%** (chain over two identical values); other armor
  resistances equal base. The same fit with the two hardeners
  as one row of quantity 2 gives the identical result and
  identical counts (the quantity-expansion pin).
- Rifter + Large EM Armor Reinforcer I (25736) in `RigSlot0`:
  armor EM `0.4 × 0.70 = 0.28` → **72.0%**, counts 0/0 (the
  partial-carrier rig pin: absent operands for the other
  damage types are not unapplied).
- Counts: Rifter + Abyssal Damage Control (52227) → bonused
  == base, excluded 0, **unapplied 1**; + Polarized Small
  Focused Pulse Laser (34272) in `HiSlot0` → unapplied 1; +
  'Basic' Layered Coating (1272) → counts 0/0 (all-zero
  carrier is honest zero); + type 999999 (no row) in
  `LoSlot0` → excluded 1; the same unknown type in `Cargo`
  → counted nowhere; quantity 3 of 52227 in one row →
  unapplied 3; quantity 0 and −5 of 2048 → skipped entirely;
  type_id 0 and −1 rows → skipped entirely.
- Flag gates: 2048 under each of `LoSlot0/MedSlot0/HiSlot0/
  RigSlot0/SubSystemSlot0` contributes; under `DroneBay`,
  `Cargo`, `FighterBay`, `Invalid` it does not (and is
  counted nowhere). A non-carrier module row (e.g. 2456-fit
  via `from_json`, or real 2049 blueprint in `MedSlot0`)
  contributes nothing and is counted nowhere.
- Guards (fixtures): ship with one absent resonance that a
  fitted module modifies → that resistance stays `None`,
  others bonus normally (the rejected-Flutter-default pin);
  entry operand `f64::NAN` / `0.0`, operator 7, modified id
  999 → item counted unapplied once per unit, other entries
  of the same item still apply; bonused resonance forced
  negative by a fixture percent operand of −150 → that
  resistance `None`; `quantity = i64::MAX` of 2281 returns
  (bounded-loop pin; value asserted equal to the quantity-8
  result, since penalties have underflowed).
- Independence: `ship_resistances` output on every fixture
  above is unchanged by items (already pinned by its own
  tests; restated as a gate, not re-pinned), and
  `Unavailable` coincides between the two functions on
  ship-missing / non-category-6 / all-absent fixtures.

**Catalogue and generator** (Builder A): the section 3
oracles and invariants run inside the generator itself; the
Rust `bundled_catalogue_invariants` additions pin counts
(791 keyed rows, 777 non-empty, 14 marked, 1,332 entries)
and the spot rows. Proof obligations reported in the commit
body: two generator runs → identical sha256; new file within
+50,000 bytes of 3,798,320 with the exact count stated;
stripping `resistanceModifiers`/`resistanceModifiersUnapplied`
→ byte-identical to sha256 `98917a44…`.

**UI wording and demo pins** (`src/ui/fittings.rs`, Builder
B; string-exact; percentages through the real
`format_fitting_percent`, one decimal, half away from zero):

- Existing base-block and EHP-block pins pass **unmodified**
  (the byte-identical-base gate, stated as a gate).
- New constants pinned verbatim (heading, disclosure, both
  unavailable sentences); excluded/unapplied helpers pinned
  at 0 (no line), 1 (singular), 2 (plural).
- Demo story, computed from the real `assets/demo/fittings.json`
  through the new pure function (never hand-typed tuples) —
  demo fixtures do not change in this slice:
  - **Demo Brawler** (Rifter; DC II + two Gistum C-Type
    hardeners at −37.5, chain factor
    `0.625 × (1 − 0.375 × 0.86911998…) = 0.42130…`; rig type
    1535 has no catalogue row):
    `Shield resistances: EM 63.1%, Thermal 70.5%, Kinetic 77.9%, Explosive 81.6%`;
    `Armor resistances: EM 66.0%, Thermal 44.8%, Kinetic 36.3%, Explosive 23.5%`;
    `Hull resistances: EM 59.8%, Thermal 59.8%, Kinetic 59.8%, Explosive 59.8%`;
    excluded line at 1 (the 1535 rig), no unapplied line.
    The MedSlot blueprint (2049), MedSlot Crokite (1225),
    subsystem-slot drone (28270), drones, fighters, and
    cargo contribute and count nothing.
  - **Mission Runner** (Rifter; DC II recorded in `HiSlot0`
    — the flag rule counts it; slot validity is not judged,
    as in every sibling): the Rifter + DC II lines above
    (`Shield … EM 12.5%, Thermal 30.0%, Kinetic 47.5%,
    Explosive 56.3%` — note 56.25 renders `56.3%`), armor
    `66.0/44.8/36.3/23.5`, hull `59.8×4`; no count lines.
  - **Demo Runner** (Punisher 597; DC II + one Gistum):
    shield `EM 45.3%, Thermal 56.3%, Kinetic 67.2%, Explosive 72.7%`;
    armor `EM 57.5%, Thermal 44.8%, Kinetic 36.3%, Explosive 32.0%`;
    hull `59.8×4`; no count lines.
  Asserting floats alone is insufficient; the rendered
  strings are the oracle, including the `56.3%`/`44.8%`/`36.3%`
  half-away pins.

**Gates at every commit** (repo standard): `cargo test`,
`cargo clippy --all-targets -- -D warnings`,
`cargo fmt --check`, `cargo build`. Existing fitting,
catalogue, demo, resources, EHP, and UI tests pass unmodified
except where this design explicitly adds pins. For the
recorded future slice: Flutter E0b's bonused-EHP literals on
the same Rifter + DC II fit are hull EHP 870.65, armor
784.31, shield 709.36 (`dogma_engine_test.dart:1022-1048`) —
quoted here only as provenance for section 7's deferral; no
test in this slice computes them.

## 9. Integrator list (locked)

The integrator (not the builders) makes these changes after
both builders land:

- **README** — three sites, keeping the rule that no readout
  is called fitting "statistics" or a "simulator" result:
  1. The Fittings bullet (line 22): after the base-resistances
     sentence, state that the same details also show the
     resistances with fitted module and rig resistance bonuses
     applied (stacking penalties where modules of the same
     kind pile up; every fitted module counted as active;
     ship bonuses, subsystems, skills, and implants not
     applied; modules whose bonus the bundled data cannot
     describe left out with a disclosed count). The sentence
     "There are still no adjusted (fitted) fitting totals of
     any kind" must be re-scoped in the same edit so it stays
     true: the bonused resistances are the one adjusted
     readout and must be carved out by name, with EHP and all
     other figures still base-only.
  2. The Roadmap Fitting bullet (line 31): the enumeration's
     "the base resistances readout" gains "the resistances
     readout with fitted module bonuses"; "ship fitting
     simulator with fitting statistics" stays not implemented.
  3. The Status paragraph (line 37): the "only fitting
     features" enumeration gains the bonused readout the same
     way; "the fitting simulator is not present yet" stays.
- **Engineering journal** — dated entries in the same change
  set (repo rule): a `LEARNINGS.md` entry with Evidence
  (file:line), Mechanism, and a one-line generalizable rule
  for (a) the three-way operand distinction (present-zero is
  proven zero bonus; all-absent on a known carrier is missing
  data and must be marked at generation time, because at
  runtime the two are indistinguishable without the mark),
  and (b) the operator-7 counted-not-applied middle state
  (parity with an oracle's unsupported counter beats both
  inventing math and silent omission). Plus a short
  `DECISIONS.md` entry for "EHP stays base until HP modifiers
  ship" with its revisit condition (a slice grounding fitted
  HP modifiers), so the next pipeline slice inherits the
  boundary instead of relitigating it.
- Confirm the slice diff contains no ESI, scope, persistence,
  network, demo-asset, base-block, or EHP-block changes; run
  the full gates once on the integrated branch; and do a
  demo-mode visual pass over all three demo fits (section 8)
  plus one imported fit carrying a Polarized weapon and an
  Abyssal Damage Control, checking both count lines render.

## 10. Exclusions (locked)

Out of this slice, by name: EHP (or any other figure) computed
from bonused resistances (section 7); hit-point modifiers of
every kind (extenders, plates, HP rigs, subsystem HP);
ship trait and role bonuses (category-6 carriers, including
skill-scaled traits); character skills of every kind (no
resistance skill is routed by Flutter either); implants and
boosters (category-20 carriers); subsystem bonuses beyond
counting the flag; operator 7 application (counted, section
2); operators 2/3/4/5/−1/9 on resistances; every
non-`ItemModifier` function and non-`shipID` domain, including
the group/skill-filtered shapes and their `groupId`/
`skillTypeId` data; all non-resistance attributes (CPU/power
outputs and needs keep their shipped paths; velocity,
capacitor, repair, damage, and every other modifier target
stays unapplied); module online/active/overloaded state
modelling or any new field on fitting rows; overheating;
mutated (Abyssal) per-item attribute values from any source;
fleet, environment, and structure effects; damage profiles
other than the shipped base-EHP omni (which does not change);
per-module resistance itemization in the view; percentages or
bars beyond the shipped line format; the fitting editor and
any fitting mutation; runtime reads of the SDE zip, the
fuzzwork caches, `effect_modifiers.json`, or `dogma.json`;
catalogue emission for any purpose beyond the two locked keys.
Anything on this list appearing in a builder commit is a
design breach, not a bonus.

## 11. Ownership (locked)

Small atomic commits, `type(scope): description`, no
attribution. Nobody pushes or merges; the parent does that.
Each commit keeps `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`, and
`cargo build` green on its own.

- **Builder A — catalogue and pure calculation.**
  (1) `feat(fitting): emit fitted-module resistance modifiers in the bundled catalogue`
  — `scripts/sde/generate_fitting_types_sde.py` (zip read,
  classification, emission, oracles, invariants, header and
  summary updates) plus the regenerated
  `assets/sde/fitting_types.json`; commit body carries the
  section 3 byte count and both determinism/strip proofs.
  (2) `feat(fitting): apply fitted-module resistance bonuses to ship resistances`
  — `src/names/fitting_types.rs` (loader fields, invariants),
  `src/fitting/ship_resistances.rs` (bonused function, penalty
  helper, header rewrite, pure tests), `src/fitting/mod.rs`
  re-exports. Compiling and passing gates with no UI change.
- **Builder B — render wiring.**
  (3) `feat(fitting): show ship resistances with fitted module bonuses`
  — `src/ui/fittings.rs` only: locked constants, count-line
  helpers, the new renderer, both detail call sites, wording
  and demo pins. Builder B changes no `src/fitting/`,
  `src/names/`, catalogue, generator, or demo files.
- **Integrator.**
  (4) `docs(fitting): document module resistance bonuses`
  — README and engineering journal (section 9), any
  cross-builder seam fix reconciled back to this document
  (not to whichever builder wrote first), final gates, and
  the demo visual pass.

Sequencing: A(1) → A(2) → B(3) → integrator (4). A(1) and the
`from_json`-fixture half of A(2)'s tests are independent, but
the commits land in the order above so every commit's
invariants describe the asset it ships beside.
