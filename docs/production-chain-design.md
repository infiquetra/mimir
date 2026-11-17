# Production chain builder — design

Status: locked for the `feat/rust-production-chain` slice.
Base: `develop` at `d907731` (970 tests stated at slice
start; this design commit re-runs the section 10 gates).
Slice branch: `feat/rust-production-chain`.
This slice is the future slice named by
`docs/industry-calculators-design.md` section 9 and by
`docs/industry-reaction-design.md` section 11, which
deferred the production chain for four named reasons:
(a) the bundled industry loader retained only activity 11,
not the activity-1 manufacturing rows the traversal needs;
(b) walking from a product to the blueprint that makes it
needs a reverse product-to-blueprint index with a
multiple-blueprints rule, which the retired Flutter
builder never built; (c) batch arithmetic was undecided in
every inspected body, because Flutter multiplies material
quantities straight down the tree ignoring per-run product
batch sizes; (d) Flutter recurses with no cycle or depth
guard and its visualizer renders an invented dummy tree,
while the Rust tree had no locked tree display. Each
reason is decided in sections 2–7 of this design from
inspected evidence, and none is settled by inventing an
EVE rule.

Discovery: two read-only reports — the retired Flutter
chain builder and visualizer at `ed698d3` against the
shipped `assets/sde/industry.json`, and the Rust loader,
Industry view seams, draft state, and line-helper
precedent. During design the bodies were re-read directly
(the Flutter `production_chain_builder.dart` and its one
test at `ed698d3`; the Rust bodies
`src/names/industry_ref.rs`, `src/reaction_calculator.rs`,
`src/invention_calculator.rs`, `src/ui/industry.rs`,
`src/app/state.rs`, `src/app/shell.rs`, and `src/lib.rs`),
both prior industry designs were re-read in full, and the
shipped `assets/sde/industry.json` and
`assets/sde/fitting_types.json` were re-counted and
re-traversed by script, including the whole reverse
graph, its cycle structure, its ambiguous products, and
the exact tree literals pinned in section 10. No EVE
quantity, batch, or traversal rule here is recalled from
outside those bodies.

**Grounded verdict up front:**

- **The chain traversal ships in this slice.** The shipped
  file already contains every row it needs (26,806
  activity-1 material rows and 4,805 activity-1 product
  rows beside the retained activity-11 set, section 2),
  so the loader widening is a scope change with its own
  locked counts and invariants (section 3), not new data.
- **Flutter's traversal is corrected, not ported.** Its
  probe treats each material type as if it were its own
  blueprint type (`getIndustryMaterials(materialTypeId,
  …)`); scripted against the shipped file, zero products
  and zero materials are also blueprint types, so that
  probe classifies every real item as a raw leaf and the
  recursion never traversed real data at all (section 6).
  What ports is the tree shape, the manufacturing-before-
  reaction probe order in the one place it survives, file
  order for children, and the single Tritanium test
  oracle. The product-to-blueprint step uses the reverse
  index section 11(b) of the reaction design named.
- **Quantities are whole-run arithmetic derived from the
  shipped data, never Flutter's straight multiplication.**
  The shipped reaction slice already fixed the meaning of
  both quantity fields — materials are per-run inputs and
  the product quantity is per-run output
  (`docs/industry-reaction-design.md` sections 2 and 6) —
  so the runs needed for a wanted quantity are the
  smallest whole number of runs making at least that
  quantity, and inputs scale by runs (section 6). The
  straight multiplication is recorded with its scripted
  cost (one pinned root overstates a leaf 1,005-fold) and
  rejected; no efficiency adjustment of any kind is
  applied, and the disclosure says so in words
  (section 9).
- **Ambiguous and cyclic items are shown, never silently
  resolved.** Five shipped products are made by more than
  one buildable blueprint, and their candidate blueprints
  carry different material lists (section 2), so no
  tie-break could be grounded: such an item cannot be
  chosen and appears inside a chain as an unexpanded
  line. Fifty-one shipped items are their own sole
  material; an ancestor guard renders the repeat once and
  never expands it again (section 6).

## 1. Goal and value ranking

Add a Production Chain Calculator block to the Industry
view, beside the shipped Invention and Reaction blocks:
the reader chooses a buildable item by its resolved name
from the bundled industry data, types how many they want,
and sees the item's full production chain by name — every
makeable item expanded into the materials the whole runs
for that quantity need, down to the raw materials the
bundled data cannot make.

Value ranking (locked, in order):

1. **Never a plausible-looking quantity from an absent,
   invented, ambiguous, or overflowed input.** No item
   chosen means no quantities at all; an item made by
   more than one blueprint is never expanded as if one
   recipe were the recipe; every multiplication is
   checked, so a huge quantity yields no result instead
   of a wrapped total; and the traversal can never hang
   or silently cut a chain (sections 4, 6, 7).
2. **Names, never numbers.** Every chosen item and every
   chain node the reader sees is a resolved EVE name or
   the honest word fallback `Unknown Item`; numeric type
   IDs exist only as internal lookup keys, in tests, and
   in this design's evidence (section 4).
3. **Grounded data and arithmetic only.** Rows come from
   the shipped SDE (Static Data Export, EVE's published
   static game data) extract already on disk; the runs
   arithmetic is derived from the per-run meanings the
   shipped reaction slice locked, with the derivation
   written out in section 6; anything no body grounds —
   material efficiency, facility bonuses, skills,
   leftover netting, cross-branch totals — ships nothing
   (section 11).
4. **Reuse.** The loader extension copies the shipped
   activity-11 loader's own validate-then-dedup rules
   (section 3); the calculator copies the
   `src/reaction_calculator.rs` pure-module shape,
   session-only `String` drafts seeded from the pure
   module's constants, a pure `Vec<String>` line helper in
   the view, and verbatim wording in named constants.

## 2. The bundled industry data after widening (scripted)

All counts in this section were measured during design by
replicating the shipped loader's scope, validation, and
first-wins dedup logic
(`src/names/industry_ref.rs:66-94`) with the retained set
widened from activity 11 to activities 1 and 11 over the
shipped `assets/sde/industry.json` (5,094,242 bytes; the
section counts and generator provenance in
`docs/industry-reaction-design.md` section 2 are
unchanged). The file envelope the loader deserializes
already carries activity-1 rows in the same two vectors
(`IndustryFile { materials, products }`,
`industry_ref.rs:35-41`), so widening changes retention
only; the `activities`, `probabilities`, and `skills`
sections stay unloaded by name, for the reasons the
reaction design locked (no duration, probability, or
skill requirement is consumed or displayed by either
calculator).

Retained counts under the widened set (the shipped file
carries no invalid or duplicate rows at either activity
under the loader's logic, so retained equals present):

| Activity | Materials kept | Products kept | Blueprints with both |
|---|---|---|---|
| 1 Manufacturing | 26,806 over 4,811 blueprint types | 4,805 over 4,805 blueprint types | 4,788 (first 681, last 88734) |
| 11 Reaction | 384 over 112 blueprint types | 112 over 112 blueprint types | 112 (first 45732, last 57506) |
| Combined | 27,190 | 4,917 | 4,900 |

- Activity-1 orphans: 23 materials-only blueprint types
  and 17 products-only blueprint types sit outside the
  intersection (union 4,828). Activity 11 still has none.
  The manufacturing and reaction blueprint sets are
  disjoint (zero types in both intersections), as are the
  retained blueprint-type sets per activity.
- Exactly one product row per blueprint holds for every
  retained blueprint at both activities (distribution
  `{1: 4805}` at activity 1, `{1: 112}` at activity 11),
  so each buildable blueprint has exactly one per-run
  product quantity — the batch the section 6 arithmetic
  reads is never ambiguous on the shipped data.
  Materials per activity-1 blueprint range from 1 to 24
  (full distribution pinned in section 10); the
  activity-11 distribution `{2: 1, 3: 69, 4: 36, 5: 5,
  6: 1}` is unchanged. Distinct types: activity 1 has
  1,571 material types and 4,797 product types; activity
  11 has 111 and 111.
- Batch sizes (`products.quantity`, units per run):
  activity 1 has 4,443 blueprints at 1 and 362 not at 1
  (150 at 100, 126 at 5000, 27 at 500, the rest smaller;
  maximum 5000); activity 11 has 17 at 1 and 95 not at 1
  (26 at 200, 16 at 12, the rest spread; 4 at 10000).
  Ignoring batch would therefore misstate nearly every
  reaction node's inputs and 362 manufacturing nodes'
  (section 6).

**The reverse graph, scripted.** Keying retained product
rows by product type over buildable blueprints only —
blueprints in either activity's materials∩products
intersection — gives 4,891 buildable products (first 165,
last 88721): 4,886 made by exactly one blueprint (4,776
manufacturing, 110 reaction) and exactly 5 made by more
than one. Products-only orphan blueprints add no
candidate for any product, so the reverse index over
buildable blueprints and over all retained rows agree on
every candidate count in the shipped file. The five
ambiguous products, with their candidates (blueprint
names from `fitting_types.json`; an unnamed blueprint
renders here as a number because this is design evidence,
never UI):

- product 16672 `Tungsten Carbide` ← blueprints 45732
  (unnamed in the item catalogue; batch 20) and 46207
  `Tungsten Carbide Reaction Formula` (batch 10000); the
  two candidates share two materials but the named
  formula also needs a fuel block, and the batches differ
  five-hundred-fold.
- product 21527 `'Firewall' Signal Amplifier` ← five
  activity-1 blueprints (21522, 21524, 21526, 21528,
  21530); only 21528 (`'Firewall' Signal Amplifier
  Blueprint`) is named, and its material quantities
  differ from the unnamed candidates', which also differ
  among themselves.
- product 22925 `'Bootleg' Remote Sensor Booster` ← three
  blueprints (22926 named `… Blueprint`, 22940, 22942)
  with materially different material lists.
- product 23416 `'Peace' Large Remote Armor Repairer` ←
  two blueprints (22952, 23417 named `… Blueprint`) with
  different lists.
- product 37161 `Standup M-Set Equipment Manufacturing
  Time Efficiency II` ← two blueprints (37326, 44005
  named `… Blueprint`) with different lists.

Every candidate set sits inside one activity (four at
activity 1, one at activity 11), so the
manufacturing-before-reaction probe order never has to
choose between activities on the shipped data
(section 6). One ambiguous product, 16672 `Tungsten
Carbide`, is consumed as a material by 43 buildable
blueprints, so the ambiguous case is reachable inside
real chains and is pinned on real data (section 10); the
other four are chosen-item exclusions only.

**Cycles and tree shape, scripted.** On the correct
graph (product → its single buildable blueprint →
materials, ambiguous products unexpanded), a strongly
connected components pass finds zero multi-node cycles.
Exactly 51 products are self-referential, and all 51
share one shape: the blueprint's sole material is the
product itself at quantity 1, batch 1 (for example
product 12238 `Reprocessing Array` via blueprint 2769,
and product 25270 `Biochemical Silo` via blueprint
2742). Forty-one of the 51 are choosable roots
(section 4). Expanding every choosable root at quantity
1 with an ancestor guard and whole-run arithmetic gives:
maximum depth 7 edges below the root (distribution by
deepest edge `{1: 2261, 2: 681, 3: 141, 4: 283, 5: 728,
6: 197, 7: 8}` over choosable roots), and tree sizes from
2 nodes (the self-referential roots) to a worst case of
2,265 nodes (products 77288 `Valravn`, 77281 `Hubris`,
77284 `Karura`); 2,480 choosable roots expand to at most
10 nodes, 56 to more than 1,000. The product 28606
`Orca` expands to 510 nodes at depth 5. These bounds are
what make the section 6 safety caps pinnable as
unreachable on the shipped data, and they state plainly
that the largest rendered chain is 2,265 node lines
(section 9 accepts that bounded cost rather than capping
rendered lines and hiding quantities).

**Name coverage, scripted against
`assets/sde/fitting_types.json`** (25,818 types), using
the shipped chooser guard (a name that exists, is
non-empty after trimming, and does not parse as an
integer): of the 4,886 single-blueprint products, 4,299
carry a chooser name (4,189 manufacturing and all 110
reaction products) and 587 do not (first such product
165, made by blueprint 681). No two chooser names
collide. Section 4 locks the consequences, mirroring the
unnamed reaction formula 45732: an unnamed or ambiguous
item is in the loaded data but can never be chosen.

## 3. Loader extension (locked — widen retention, add the reverse index)

`IndustryRef` (`src/names/industry_ref.rs`) widens in
place; no second loader is added, because the two
retained sections, row structs (`IndustryMaterial`,
`IndustryProduct`, `industry_ref.rs:11-33`), envelope, and
startup wiring already exist and already serve the
Industry view (`MimirApp.industry_data`, loaded once in
`MimirApp::new`). New and changed surface, locked:

```rust
pub const MANUFACTURING_ACTIVITY_ID: i64 = 1; // beside REACTION_ACTIVITY_ID

impl IndustryRef {
    pub fn manufacturing_blueprint_count(&self) -> usize;
    pub fn manufacturing_blueprint_type_ids(&self) -> &[i64];
    pub fn is_manufacturing_blueprint(&self, type_id: i64) -> bool;
    pub fn manufacturing_materials(&self, type_id: i64) -> Option<Vec<&IndustryMaterial>>;
    pub fn manufacturing_products(&self, type_id: i64) -> Option<Vec<&IndustryProduct>>;
    pub fn buildable_product_count(&self) -> usize;
    pub fn buildable_product_type_ids(&self) -> &[i64];
    pub fn blueprints_producing(&self, product_type_id: i64) -> &[i64];
    pub fn product_row_for(
        &self,
        blueprint_type_id: i64,
        product_type_id: i64,
    ) -> Option<&IndustryProduct>;
}
```

Decisions locked:

- **The scope filter is the single chokepoint.** Both
  retention loops accept `activity_id` 1 or 11 in place
  of the shipped `!= REACTION_ACTIVITY_ID` tests
  (`industry_ref.rs:67, 82`); every other activity is
  still dropped uncounted, and validation among retained
  rows is unchanged (skip and count `type_id <= 0`,
  `material_type_id` / `product_type_id <= 0`,
  `quantity <= 0`). The public `materials` / `products`
  vectors now hold both activities, so
  `material_count()` / `product_count()` report combined
  retained totals (27,190 / 4,917 on the shipped file);
  section 10 updates their pins. The one-file parse cost
  was already paid — the shipped loader deserializes all
  42,459 rows of the two sections before dropping any —
  so widening adds index memory for the retained set, not
  a second parse; no startup-time figure is claimed
  anywhere in this design (no inspected body states one).
- **Dedup keys gain the activity.** The primary key the
  SDE (Static Data Export) tables carry is
  `(typeId, activityId, materialTypeId)` /
  `(typeId, activityId, productTypeId)`
  (`docs/industry-reaction-design.md` section 2); the
  shipped two-field keys were safe only because one
  activity was retained. The widened `seen` sets key on
  the full triple, still first-in-file wins. On the
  shipped file this changes nothing (no blueprint type
  appears at both retained activities, section 2).
- **Membership stays intersection-based, per activity.**
  `manufacturing_blueprints` mirrors the shipped
  `reaction_blueprints` construction
  (`industry_ref.rs:96-102`) over the activity-1 subsets:
  sorted ascending, binary-search membership, accessors
  returning `None` outside the intersection so no
  half-blueprint can be calculated. The existing
  `material_index` / `product_index` maps stay keyed by
  blueprint type over all retained rows, and **every**
  materials/products accessor (the two shipped reaction
  accessors included) filters the indexed rows to its
  own activity, so a fixture blueprint carrying rows at
  both activities can never leak manufacturing rows
  through `reaction_materials` or the reverse. Row order
  remains file order. Shipped reaction behaviour is
  unchanged because reaction blueprints carry only
  activity-11 rows.
- **The reverse index covers buildable blueprints
  only.** `blueprints_producing` is built from retained
  product rows whose blueprint is in either
  intersection — a products-only orphan proves no
  buildable path, and a materials-only orphan makes
  nothing — keyed by `product_type_id`, stored as a
  private `HashMap<i64, Vec<i64>>` plus the sorted key
  vector `buildable_product_type_ids` (4,891 keys on the
  shipped file, first 165, last 88721). Candidate lists
  sort by activity ascending, then blueprint type
  ascending: manufacturing before reaction is Flutter's
  probe order surviving in the one place an order is
  observable at all, and section 6 never picks among
  multiple candidates, so the order decides nothing on
  any data. An absent product returns an empty slice,
  never `None`: "no blueprint makes this" and "exactly
  these blueprints make this" are both answers the
  traversal branches on, and an empty slice is the total
  form of the first. `product_row_for` returns the
  retained row for a (blueprint, product) pair when the
  blueprint is buildable, giving the traversal both the
  batch (`quantity`) and the producing activity from the
  one row that created the candidate.
- **Failure behaviour.** `from_json` still returns `Err`
  on unparseable JSON (propagated with `?`, unchanged).
  The empty-catalogue rule becomes: `Err` only when
  **both** intersections are empty — no buildable
  blueprint at either retained activity — as
  `AppError::Message("[INDUSTRY] industry catalogue is
  empty")` (the shipped "reaction catalogue" wording
  updates with the widened scope; no test pins the old
  string — the shipped tests assert `is_err()` only,
  `industry_ref.rs:373-398`). A catalogue buildable at
  one activity only now loads: the other calculator then
  shows its choose-guidance over an empty choice list,
  which is honest for data that proves nothing buildable
  for it. Section 10 names the two shipped tests whose
  expectations flip under this rule.
- **Logging (startup only) grows with the scope.** The
  `from_json` info line becomes `[INDUSTRY] industry
  data loaded materials={} products={} manufacturing={}
  reactions={} skipped={}` with retained totals and both
  blueprint counts, in the shipped position (after
  filtering, before the empty check; Builder A). The
  shell helper line becomes `[INDUSTRY] bundled industry
  data loaded manufacturing={} reactions={}` beside its
  shipped failure line (`src/app/shell.rs:690-704`;
  Builder B with its shell test pin). No row contents,
  type numbers, or names are ever logged, and no lookup
  logs — the shipped render-cadence rule — for any of
  the new accessors. The module doc heading updates to
  name both retained activities and this design
  (Builder A).
- **No startup change.** `MimirApp::new` already loads
  `IndustryRef::load_bundled()` once and the Industry
  view already receives it; the widened catalogue flows
  through the shipped field with no new field, no new
  load, and no signature change anywhere in
  `src/app/shell.rs` beyond the one log line and its
  test pin.

## 4. Choosing an item and resolving names (locked)

Flutter never shipped this choice either: its visualizer
always renders a hard-coded dummy tree
(`production_chain_visualizer.dart` at `ed698d3`, marked
as dummy data for testing the UI) and never calls the
builder, so there is no Flutter chooser to port and the
dummy tree — its item names, quantities, and structure —
is never an oracle for anything. The choice copies the
shipped reaction chooser exactly, retargeted from
blueprints to the items the chain is about. The chosen
entity is the **product** (the item to make), matching
Flutter's `buildChain(typeId, quantity)` taking the item
type — its one test builds the chain for type 34,
Tritanium, an item, not a blueprint — and matching how a
reader asks the question ("what does an Orca need?", not
"what does Orca Blueprint need?"). Blueprint names are
never displayed anywhere in this block.

```rust
pub struct ChainChoiceRow {
    pub type_id: i64,   // product type, internal key only, never rendered
    pub name: String,
}

fn chain_choice_rows(
    industry_data: &IndustryRef,
    fitting_types: &FittingTypes,
    query: &str,
) -> Vec<ChainChoiceRow>;
```

- The universe is exactly
  `industry_data.buildable_product_type_ids()` filtered
  to products with
  `blueprints_producing(product).len() == 1` — items the
  loaded data proves buildable by exactly one blueprint.
  The five ambiguous products (section 2) never appear:
  choosing one could only render one candidate's recipe
  as if it were the item's, which is the invented
  blueprint-choice this slice refuses. No owned
  blueprint, job, asset, or character data widens or
  narrows the list; the reader need not own any
  blueprint in the chain.
- Each product's display name is
  `fitting_types.lookup_by_id(product)` with the shipped
  trim / empty / purely-numeric guard
  (`src/ui/industry.rs:592-597`); a product failing it
  does not appear at all, for the reaction design's
  reason: an `Unknown Item` row in a choice list cannot
  be told apart from any other unnamed item. On the
  shipped catalogues this leaves **4,299 choosable
  items** (section 2), no two names colliding; the first
  sorted rows are `'Abatis' 100mm Steel Plates`,
  `'Arquebus' Heavy Beam Laser I`, `'Atgeir' Explosive
  Disruptive Lance`, `'Augmented' Acolyte` (section 10).
  The disclosure states both exclusions in words,
  without a count or a number (section 9).
- Filtering, sorting, capping, and rendering mirror
  `reaction_choice_rows` and its block verbatim
  (`industry.rs:584-613, 756-772`):
  `widgets::matches_search` (case-insensitive substring,
  empty matches all), sort by lowercased name then name
  then the internal product type, at most
  `PRODUCTION_CHAIN_CHOICE_RENDER_MAX = 100`
  `selectable_label` rows with a
  `Showing {shown} of {total} items.` line above them
  when the filtered list is longer, and the no-match
  sentence (section 9) when it is empty. With 4,299
  choosable items the search box is how the list is
  used; the empty search shows the first 100 sorted
  names. Clicking stores the product type in session
  state (section 5), never rendered and never logged;
  the selection survives later searches because the line
  helper re-derives the chosen name from the catalogues
  every frame, exactly as the reaction block does.
- **Nothing is pre-chosen** (the reaction lock, same
  reasoning): the selection starts empty and the block
  shows its choose-guidance line. Pre-selecting the
  first sorted item would render a full chain the reader
  never asked for.
- **Node names reuse the shipped dual path.** Every
  chain node's display name comes from the existing
  `reaction_item_name` helper (`industry.rs:618-630`) —
  guarded `FittingTypes` name, else
  `NameResolver::name`, whose unresolved fallback is the
  word `Unknown Item` — called as-is, without rename, so
  the reaction block and its tests are untouched.
  Flutter's name order (skill name, then ship-type name,
  `production_chain_builder.dart:43-45`) is **not**
  ported: it could only name two narrow categories and
  silently produced nothing for most industry types,
  while the shipped Rust path resolves every activity-11
  material and product and 96.5% of activity-1 materials
  from the bundled catalogue (discovery-measured; the
  miss renders `Unknown Item` honestly beside a quantity
  that is still real data, exactly as the reaction
  design locked). The skills-only `Sde` is never
  consulted. No shell name-resolution scheduling is
  added (bundled coverage, the reaction precedent).
- **Both catalogues are load-bearing**, as in the
  reaction block: if either failed to load, the block
  renders its fixed unavailable sentence and nothing
  else (section 9).

## 5. Quantity input and draft state (locked)

Exactly two reader inputs beyond the item choice: a
search text (section 4) and a quantity. Nothing is taken
from a loaded job, an owned blueprint, the character, or
any structure.

| Input | Meaning | Starting text | Valid range (section 7) |
|---|---|---|---|
| Item search | Filters the section 4 name list | empty | any text; empty matches all |
| Quantity | How many units of the chosen item are wanted | `1` | whole number, at least 1 |

- **Quantity is units wanted, not runs.** Flutter's
  builder documents its `quantity` as "The amount of the
  final product to build" and stores it as the root
  node's `quantityRequired`; its one test passes 1. The
  port keeps both: the root node shows the entered
  units, and section 6's whole-run arithmetic converts
  units to runs per blueprint. A runs field would be
  the wrong unit for a chain — every node has its own
  runs, derived — so no runs, batch, efficiency, or
  bonus field exists in this block.
- **The starting text is `1`** (Flutter's test quantity
  and the smallest honest want), so the first chain a
  reader sees after choosing is the single-item chain at
  face value — remembering that a batch node's subtree
  is one whole run's inputs even at quantity 1
  (section 6), which the disclosure states.
- **Text field, no widget invention:** the shipped
  parsers' shape (`parse_runs`,
  `src/reaction_calculator.rs:52-59`) with its own name,
  `parse_quantity`, because the value is units, not
  runs; the rules are identical (section 7). No upper
  bound at parse time; section 7's checked arithmetic
  rejects a quantity too large to calculate with.

Draft state (Builder A, section 13): three new fields on
`AppState` beside the reaction drafts
(`src/app/state.rs:803-806`):

```rust
pub industry_chain_search: String,
pub industry_chain_selected_type_id: Option<i64>,
pub industry_chain_quantity: String,
```

`AppState::new` seeds the quantity explicitly from the
pure module's `DEFAULT_QUANTITY` (section 8) beside the
reaction seeding — `DEFAULT_QUANTITY.to_string()` giving
`"1"` — while the search starts empty and the selection
`None` under the derived `Default`. The selection field's
comment states it holds a **product** type as an internal
catalogue key that is never rendered or logged. All
three are session-only: nothing is stored, and character
switching, blueprint filtering, industry refreshes, and
demo seeding never touch them — the survival the shipped
invention and reaction draft tests pin, extended to the
chain fields in section 10.

## 6. Traversal semantics (locked — Flutter corrected where the data proves it broken)

Flutter `production_chain_builder.dart` at `ed698d3`
(read in full during design, 116 lines). What it does,
verbatim in substance: `buildChain(typeId, quantity,
{activityId = 1})` looks up
`getIndustryMaterials(typeId, activityId)`; an empty
result returns a raw-material leaf holding `quantity`;
otherwise each material's child quantity is
`matQty = mat.quantity * quantity` (line 65), the child
is probed for its own materials at activity 1 first and
activity 11 second (lines 67-84), and the builder recurses
with no visited set, no cycle guard, and no depth limit.
Its one test mocks an empty materials result for type 34
and asserts a single raw node at quantity 1.

**Why the probe cannot port.** `getIndustryMaterials`
keys rows by **blueprint** type, so probing
`mat.materialTypeId` treats every material as if it were
its own blueprint. Scripted over the shipped file, the
intersection of {products} with {blueprint types} and of
{materials} with {blueprint types} are both empty — no
real item is ever its own blueprint (blueprints are
distinct types, e.g. item 28606 `Orca` is made by
blueprint 28607). On real data Flutter's builder
therefore returns every root, including the Orca, as an
immediate raw leaf; its recursion terminates only
because it never leaves the root, and its visualizer
never called it at all (section 4). Porting the probe
literally would ship a chain that expands nothing. The
correction is exactly the step the reaction design's
section 11(b) named as this slice's entry condition:
walk product → blueprint(s) through the section 3
reverse index, then blueprint → materials through the
per-activity accessors. Everything else Flutter decided
that the data does not refute is kept: the tree of
`ProductionNode`-shaped nodes, children in bundled-data
file order, manufacturing probed before reactions (in
candidate ordering, section 3 — on the shipped data no
product's candidates span both activities, so the order
is unobservable, recorded rather than silently dropped),
and the raw-leaf rule "no way to make it in the data
means a leaf holding the needed quantity".

**Batch arithmetic — derived, with the rejected
alternative priced.** Flutter's `mat.quantity * quantity`
treats the needed quantity as if each unit separately
consumed a full per-run material set. The shipped
reaction slice already locked what the two quantity
fields mean — material `quantity` is the per-run input
for one run of its blueprint and product `quantity` is
the per-run output of one run
(`docs/industry-reaction-design.md` sections 2 and 6,
implemented in `calculate_inputs` / `calculate_outputs`)
— and the widened rows are the same two sections, the
same generator, and the same row shapes at activity 1.
From those meanings alone, with runs whole numbers (the
reaction runs parser accepts only `i64` values of at
least 1; no inspected body admits a fractional run), the
arithmetic is forced:

```text
runs        = smallest whole number with runs * batch >= quantity_required
            = (quantity_required - 1) / batch + 1        (integer division)
child_qty   = per-run material quantity * runs           (checked, section 7)
```

where `batch` is the producing row's product quantity
for the node's own product (section 3), exactly one per
buildable blueprint on the shipped data (section 2).
This is a derivation from locked per-run semantics, not
an invented EVE rule: it introduces no efficiency,
bonus, skill, or rounding — the only rounding is the
forced whole-run ceiling, stated in the disclosure as
"the whole runs needed to make at least the quantity
shown", with leftovers from a part-used run never
subtracted from other lines (each tree node is expanded
independently, which is Flutter's tree shape; netting
surplus across branches would be a second, ungrounded
aggregation rule, section 11). The rejected alternative,
porting the straight multiplication, is priced by script
on the pinned root 57453 `Carbon Fiber` at quantity 201
(section 10): whole-run leaves need 1 Robotics, 4
Enriched Uranium, 170 Heavy Water, 200 Hydrocarbons;
straight multiplication needs 1,005 Robotics, 4,020
Enriched Uranium, 170,850 Heavy Water, 20,100
Hydrocarbons — overstatements of 1,005×, 1,005×, 1,005×,
and 100.5× on the same tree. A knowingly hundred-to-
thousand-fold overstated table, however loudly
disclosed, is the plausible-looking wrong number this
view's first value exists to refuse; the arithmetic the
data itself grounds ships instead, and the disclosure
states plainly that quantities are the bundled per-run
amounts scaled by whole runs with **no efficiency
adjustment of any kind** (section 9).

**Node classification and expansion, locked in check
order.** The pure builder (section 8) walks depth-first,
children in file order, carrying the ancestor path (root
to parent product types), the depth (root = 0), and an
expansion budget. For a node `(product, quantity)`:

1. If `product` is already in the ancestor path, the
   node is a **Cycle** leaf: rendered once with its
   needed quantity, never expanded again. This is the
   guard Flutter never had; on the shipped data it fires
   exactly for the 51 sole-material-is-itself items
   (section 2), where the repeat is the item's only
   child. It is a termination rule for the shipped data,
   not a claim about EVE: the line says the item is
   already in this chain and is not expanded again
   (section 9).
2. `blueprints_producing(product)` empty → a
   **RawMaterial** leaf holding `quantity` (Tritanium
   and every material no buildable blueprint makes,
   including products of orphan blueprints — unprovable
   as buildable, section 3).
3. More than one candidate → a **MultipleBlueprints**
   leaf holding `quantity`, unexpanded. No tie-break is
   grounded: every candidate set on the shipped data
   carries different material lists or batches
   (section 2), so picking the lowest number, the named
   blueprint, or the first in file order would each
   present an invented recipe as the item's chain. The
   line says more than one blueprint makes the item and
   it is not expanded (section 9). This is the
   multiple-blueprints rule section 11(b) required:
   refuse, visibly.
4. Exactly one candidate → read its product row
   (batch + activity) and its materials for that
   activity. A missing row, a missing or empty materials
   result, or any non-positive id or quantity in those
   rows fails the **whole** build as `None` (section 7):
   the loader's intersection construction makes this
   unreachable for loaded catalogues, and a partial tree
   over inconsistent rows is never rendered.
5. If `depth == MAX_CHAIN_DEPTH` or the expansion budget
   is exhausted → a **Truncated** leaf holding
   `quantity`, carrying the producing activity, rendered
   as "chain limit reached; not expanded" (section 9) —
   never a silent cut. `MAX_CHAIN_DEPTH = 16` and
   `MAX_CHAIN_EXPANSIONS = 5_000` (counted per expanded
   produced node) are implementation safety bounds, not
   EVE rules; both sit above the shipped data's scripted
   maximum depth of 7 and worst tree of 2,265 nodes, and
   section 10 pins them unreachable over every buildable
   shipped product, reachable only in synthetic
   fixtures. Together with the ancestor guard they are
   the "never hang" contract: every recursion step
   either returns a leaf or consumes one budget unit
   before descending, and nesting never exceeds the
   depth cap, so the recursive implementation's stack is
   bounded by construction.
6. Otherwise the node is **Produced**: consume one
   budget unit, compute `runs` as above, and expand each
   material row in file order at `depth + 1` with
   `child_qty` and the path extended by `product`.

The root passes the same checks, so the pure API is
total over any product id: an unbuildable root is a
single RawMaterial node (Flutter's Tritanium oracle,
reached by the correct graph — no blueprint makes type
34 in the shipped file), an ambiguous root is a single
MultipleBlueprints node, and a self-referential root is
a Produced node whose only child is a Cycle node. The
view never selects such roots (section 4), but the pure
behaviour is pinned so no caller can meet an undefined
case (section 10). Quantity never changes which nodes
exist — only their quantities and run counts — so tree
shape, depth, and node count per root are quantity-
independent on any data.

## 7. Validation, invalid-input, and overflow behaviour (locked)

One pure parser (section 8), mirroring `parse_runs`
exactly: `parse_quantity(text)` trims whitespace, parses
as `i64`, accepts only a value of at least 1 — no comma
stripping (on a whole-number count a comma is a typo).
This rejects empty text, `0`, negatives, fractional text
such as `1.5`, and `1,000`; text beyond `i64` range fails
the parse itself; no upper bound at parse time.

`build_chain` returns `None` — the whole chain, never a
partial tree — when any of these holds. The full list,
no others:

- `product_type_id` is at or below 0, or `quantity` is
  below 1 (the `calculate_inputs` input-validation shape;
  Dart would have built a negative-quantity tree, which
  is deliberately not replicated);
- any row the expansion actually reads carries a
  non-positive blueprint, material, or product type, a
  non-positive material quantity, or a non-positive
  batch, or a single candidate's product row or
  materials cannot be read or are empty (section 6
  step 4 — unreachable through a catalogue `from_json`
  constructed, because the loader already drops
  non-positive rows and gates accessors on the
  intersection, and locked anyway so the pure function
  is total over any `IndustryRef` value, including a
  hand-built `Default`);
- any `runs` or child-quantity computation overflows
  `i64`. Runs are computed as
  `(quantity - 1) / batch + 1` on validated-positive
  operands, which cannot overflow (`quantity >= 1`,
  `batch >= 1`, the result is at most `quantity`);
  `child_qty = material_qty.checked_mul(runs)` uses
  `checked_mul` and propagates `None` — never wrapping,
  saturating, or `as`-cast arithmetic. There is no
  floating-point step anywhere in this module, so
  reaction's `2^53` exact-representation guard has no
  counterpart here and quantities stay exact to the
  `i64` limit (recorded so nobody ports that guard in).

Consequences, locked: no zero, negative, wrapped, or
float-shifted quantity can be produced; every rendered
quantity is at least 1 (all operands positive); presence
is decided by the `Option`, never by comparing a figure
to zero; and a cleared or invalid quantity field shows
guidance with no chain at all (section 9). Cycle,
ambiguous, and truncated nodes are **not** failures —
they are `Some` results carrying their honest leaf
lines — so the only `None` a valid selection can meet
is the too-large quantity, which is exactly what the
no-result guidance line says.

## 8. Pure API (locked)

New top-level module `src/production_chain.rs`,
registered in `src/lib.rs` in alphabetical position
(`pub mod production_chain;` between `portraits` and
`reaction_calculator`). It mirrors
`src/reaction_calculator.rs`: no egui (the immediate-mode
GUI library), no `AppState`, no network, no database, no
`include_str!`, and it logs nothing — it runs at render
cadence. Its module doc cites this design, the Flutter
builder at `ed698d3` with the probe correction, the
loader in `crate::names::industry_ref` as its data
source, the whole-run derivation, and the
ambiguous/cycle refusal rules. One shape decision
differs from the reaction module and is recorded: the
reaction math takes plain `(type_id, quantity)` pairs
because one formula over two flat maps is its whole
contract, but a traversal is inherently a sequence of
graph queries (reverse candidates, a product row, a
materials list, recursively), so `build_chain` takes
`&IndustryRef` and the tests build graphs through
`IndustryRef::from_json` fixtures — the same fixture
mechanism the shipped loader tests use — keeping the
module testable without the bundled file for every rule
except the section 10 real-data pins, which want the
bundled file by definition.

```rust
pub const DEFAULT_QUANTITY: i64 = 1;
pub const MAX_CHAIN_DEPTH: usize = 16;
pub const MAX_CHAIN_EXPANSIONS: usize = 5_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChainNodeKind {
    Produced,
    RawMaterial,
    Cycle,
    MultipleBlueprints,
    Truncated,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChainNode {
    pub type_id: i64,
    pub quantity_required: i64,
    pub production_activity_id: Option<i64>,
    pub kind: ChainNodeKind,
    pub dependencies: Vec<ChainNode>,
}

pub fn parse_quantity(text: &str) -> Option<i64>;

pub fn build_chain(
    industry_data: &IndustryRef,
    product_type_id: i64,
    quantity: i64,
) -> Option<ChainNode>;

pub fn production_chain_result(
    industry_data: &IndustryRef,
    product_type_id: i64,
    quantity_text: &str,
) -> Option<ChainNode>;
```

Decisions locked:

- The node mirrors Flutter's `ProductionNode` fields
  (`typeId`, `quantityRequired`, `productionActivityId`,
  `dependencies`) with names in the tree's snake case,
  minus `name` (the pure module has no names; the view
  resolves them, section 4), plus `kind`, which is what
  lets the renderer distinguish the five section 6 cases
  without re-deriving them. `production_activity_id` is
  `Some(activity)` exactly for `Produced` and
  `Truncated` nodes (a truncated node has a known single
  producer it did not expand) and `None` for
  `RawMaterial`, `Cycle`, and `MultipleBlueprints`;
  `dependencies` is non-empty exactly for `Produced`.
- `DEFAULT_QUANTITY = 1` is Flutter's test quantity,
  documented as the `AppState` draft seed, never a
  derived figure. The two `MAX_` constants are the
  section 6 safety bounds, each documented as an
  implementation limit above the shipped data's scripted
  maxima, never an EVE rule.
- `production_chain_result` is the renderer's one call:
  it parses the quantity text and returns `Some` only
  when the parse and the build both succeed. All
  functions are total: no panics, no indexing, no unwrap
  on hostile text, hostile quantities, or hostile
  catalogues.
- Builder A also updates the two now-stale deferral
  notes in the same commit that adds this module.
  In `src/invention_calculator.rs:21-24`, replace "The
  reaction calculator lives in
  `crate::reaction_calculator` over the bundled industry
  data in `crate::names::industry_ref`; there is still
  no production-chain calculator (see
  `docs/industry-reaction-design.md` section 11)." with
  "The reaction calculator lives in
  `crate::reaction_calculator` and the production-chain
  calculator in `crate::production_chain`, both over the
  bundled industry data in `crate::names::industry_ref`
  (see `docs/production-chain-design.md`)."
  In `src/reaction_calculator.rs:18-20`, replace "There
  is no production-chain calculator (see
  `docs/industry-reaction-design.md` section 11)." with
  "The production-chain calculator lives in
  `crate::production_chain` over the same bundled data
  (see `docs/production-chain-design.md`)."

## 9. UI placement and verbatim wording (locked)

`show_production_chain_calculator(ui, state, resolver,
industry_data, fitting_types)` in `src/ui/industry.rs` is
called from `show()` immediately after
`show_reaction_calculator` (`industry.rs:800`) and
**before** the no-character early return
(`industry.rs:801-804`) — the shipped placement and its
reasoning unchanged: the block reads only bundled
catalogues plus drafts, so it is available with no
character, while jobs load or fail, offline, and in demo
mode, and never only inside the `LoadState::Ready` arm.
`show()`'s signature does not change: the call already
receives `industry_data` and `fitting_types` for the
reaction block. The block sets no request flag, fetches
nothing, and touches neither industry section.

Render flow mirrors `show_reaction_calculator`
(`industry.rs:732-788`) in order: the heading; the two
early-return unavailable sentences when either
catalogue is `None`; otherwise the item label and a
plain `ui.text_edit_singleline` bound to
`industry_chain_search` (`response.has_focus()` feeding
`state.text_input_focused`, no focus ever requested, the
blueprint `/` shortcut untouched), the section 4 choice
rows with their showing / no-match lines, the quantity
label and field, then every line from the pure helper
below as one `ui.label` each. No Calculate button, no
slider or dropdown, no colour coding, no graphics — and
specifically no Tree / `2D Canvas` toggle and no
drag-and-drop placeholder: the Flutter visualizer's
canvas was an unimplemented stub ("coming in next
iteration") and ships nothing here, not even as a
disabled control. **Rendered node lines are not
capped.** The shipped worst case is 2,265 node lines
(section 2), bounded and pinned; a render cap with a
showing-line would hide real quantities mid-tree to save
scrolling, which trades the block's core job away,
whereas the choice list's cap hides only rows a search
reaches. The accepted cost is a long scroll on capital-
class roots in demo and live alike, exercised by the
integrator's demo check (section 12).

Line-building is factored exactly as the shipped blocks':

```rust
fn production_chain_calculator_lines(
    state: &AppState,
    industry_data: Option<&IndustryRef>,
    fitting_types: Option<&FittingTypes>,
    resolver: &NameResolver,
) -> Vec<String>;
```

It returns, by state, in this exact precedence (first
match wins, mirroring `reaction_calculator_lines`,
`industry.rs:637-730`):

1. `industry_data` is `None` → the no-industry-data
   sentence alone (no disclosure).
2. `fitting_types` is `None` → the no-item-data sentence
   alone.
3. No selection, or the stored selection does not have
   exactly one producing blueprint in this catalogue, or
   it has no chooser name under section 4's guard → the
   choose-guidance line, then the disclosure. (The
   cases a test fabricates: ambiguous product 21527,
   unbuildable 34, single-but-unnamed product 165.)
4. The quantity draft fails `parse_quantity` → the
   input-guidance line, then the disclosure.
5. The quantity parses but `production_chain_result`
   returns `None` (with locked loaders the only such
   case is overflow, section 7) → the
   no-result-guidance line, then the disclosure.
6. Success → the header line, one line per tree node in
   pre-order (root first, children in file order), then
   the disclosure last, always.

All wording is held in named `pub const`s in
`src/ui/industry.rs` beside the `REACTION_CALCULATOR_*`
constants (`industry.rs:46-63`):
`PRODUCTION_CHAIN_HEADING`,
`PRODUCTION_CHAIN_INPUT_LABELS: [&str; 2]`,
`PRODUCTION_CHAIN_CHOICE_RENDER_MAX: usize = 100`,
`PRODUCTION_CHAIN_NO_INDUSTRY_DATA`,
`PRODUCTION_CHAIN_NO_ITEM_DATA`,
`PRODUCTION_CHAIN_CHOOSE_GUIDANCE`,
`PRODUCTION_CHAIN_NO_MATCH`,
`PRODUCTION_CHAIN_INPUT_GUIDANCE`,
`PRODUCTION_CHAIN_NO_RESULT_GUIDANCE`, and
`PRODUCTION_CHAIN_DISCLOSURE`.

Heading and input labels, verbatim and in order:

```text
Production Chain Calculator
Item (chosen by you)
Quantity (entered by you)
```

`Production Chain` is the Flutter visualizer's own
heading (`PRODUCTION CHAIN`) in the view's calculator
naming pattern; the labels extend the nouns with the
honest source exactly as the reaction labels do
(`Reaction (chosen by you)`, `Runs (entered by you)`).
The unavailable, guidance, and no-match sentences,
verbatim (the showing line is a template, rendered by
the block, not the line helper — the reaction precedent):

```text
Production chain calculator unavailable: Mimir's bundled industry data failed to load.
Production chain calculator unavailable: Mimir's bundled item data failed to load.
Choose an item above to see its production chain.
No items match the search.
Showing {shown} of {total} items.
Enter a quantity of at least 1, to see the result.
No result: the entered values are too large to calculate with.
```

The no-result sentence reuses the shipped invention and
reaction words exactly (same reader situation); none of
these lines contains a draft value, a computed figure,
or a numeric ID beyond the fixed bound and showing
counts in their own wording.

Result lines, verbatim templates in order. The header
follows the reaction echo shape; each node line is the
node's depth times two spaces, then the resolved name,
the plain decimal quantity (never grouped — the
shipped quantity format), and a parenthetical kind
word. `Manufacturing`, `Reaction`, and `Raw Material`
are the Flutter visualizer's chip words for the same
three node classes (its labels are wording precedent;
its dummy quantities are not):

```text
Production Chain: {chosen item name}
{indent}{item name}: {quantity} (Manufacturing)
{indent}{item name}: {quantity} (Reaction)
{indent}{item name}: {quantity} (Raw Material)
{indent}{item name}: {quantity} (already in this chain; not expanded again)
{indent}{item name}: {quantity} (more than one blueprint makes this item; not expanded)
{indent}{item name}: {quantity} (chain limit reached; not expanded)
```

The first node line is the root (indent empty) and
repeats the header's name with the entered quantity and
its producing activity — recorded as a decision: the
header survives scrolling like the reaction echo line,
and the root line is a tree node like every other. A
`Truncated` node renders only the chain-limit form (its
activity is not also rendered — one parenthetical per
line, and the limit is the fact the reader needs). The
same item appearing in several branches renders once
per branch with that branch's quantity; lines are never
summed across branches (section 11).

**Disclosure**, rendered verbatim under the result or
guidance lines in every state except the two unavailable
states:

> Estimate for the item and quantity you chose, using
> the per-run materials and products in Mimir's bundled
> industry data. Each item the bundled data can make is
> expanded into the materials for the whole runs needed
> to make at least the quantity shown, so a run that
> makes more than the chain needs can leave items over,
> and leftovers are not subtracted from other lines.
> Quantities are the bundled per-run amounts with no
> efficiency adjustment: Mimir does not apply blueprint
> material efficiency, facility bonuses, or skills, and
> it does not check that you own the blueprints or
> materials or can run the jobs. The starting quantity
> (1) is a starting value to replace with your own. An
> item with no name in Mimir's bundled item data, or
> made by more than one bundled blueprint, cannot be
> chosen, and where such an item appears inside a chain
> it is shown without expansion. An item that appears
> inside its own chain is shown once without being
> expanded again. These numbers can differ from EVE.

Every clause carries one locked decision: chosen item
and entered quantity only over bundled per-run data;
whole runs with leftovers named and never netted
(section 6); no efficiency adjustment of any kind, with
every un-read source named; the starting quantity as a
value to replace; both choice exclusions extended to
their in-chain form (sections 4, 6); the cycle rule in
words; and the unverified-against-Live caveat. Whether
the bundled extract still matches EVE Live is
unverified — its only source is the shipped generated
file — and the last sentence says so without claiming
otherwise.

**Two existing sentences change.** Both shipped
disclosures say "There is no production-chain
calculator." Builder B deletes that one sentence from
`INVENTION_CALCULATOR_DISCLOSURE` and from
`REACTION_CALCULATOR_DISCLOSURE` (`industry.rs:44, 63`)
and updates their byte-exact tests; no other shipped
wording, constant, or expectation changes in this slice
beyond the loader pins section 10 names.

Logging: the renderer emits one
`tracing::debug!("[INDUSTRY] production chain calculator
input changed")` when either text field reports
`changed()`, and one `tracing::debug!("[INDUSTRY]
production chain calculator item chosen")` when a choice
row is clicked — the `[INDUSTRY]` tag and shape of the
shipped blocks, satisfying the repo's rule that every
code change carries debug logging. No draft contents,
search text, chosen name, type number, or computed
quantity is ever logged, and the pure helpers
(`chain_choice_rows`, `production_chain_calculator_lines`,
and the reused `reaction_item_name`) log nothing beyond
the resolver's own shipped miss debug.

## 10. Demo pins and test plan (locked literals)

**One Flutter test oracle exists and is honoured.** The
single case in `production_chain_builder_test.dart` at
`ed698d3` (empty materials for type 34 named Tritanium →
one raw node, quantity 1, no dependencies) is matched on
**real** data by the corrected graph: no buildable
blueprint in the shipped file makes type 34, so
`build_chain(bundled, 34, 1)` is that same single raw
node without any mock. Every other literal below is a
real-data pin scripted from the shipped
`industry.json` / `fitting_types.json` during design, or
a synthetic `from_json` fixture whose arithmetic is
shown. Results are integers and `assert_eq!`
throughout; trees are asserted as whole structures or
whole pre-order projections, never sampled lines where
a stray line could hide.

**Demo mode:** no demo data changes. Both bundled
catalogues load identically in demo and live modes, as
they already do for the reaction block, and no demo job
or blueprint (demo blueprint types 681, 682, 683) feeds
the choice, the selection, or the quantity. Demo pins: a
demo-seeded state leaves all three chain fields exactly
as constructed (selection empty), renders the
choose-guidance lines, and — once a test chooses Small
Blaster Battery in that state at the starting quantity —
renders the same block as live mode (below).

**Builder A — loader tests** (`src/names/industry_ref.rs`).
The shipped reaction pins inside `bundled_catalogue_pins`,
`bundled_real_data_spot_pins`, and the activity-11 half
of the invariants keep their exact literals; what
changes is named here, everything else passes
unmodified.

Combined and manufacturing pins against the shipped file:

```text
material_count() = 27190, product_count() = 4917   (combined retained totals)
reaction_blueprint_count() = 112                    (unchanged)
manufacturing_blueprint_count() = 4788
manufacturing_blueprint_type_ids().first() = 681, .last() = 88734
is_manufacturing_blueprint(681) = is_manufacturing_blueprint(2813) = true
is_manufacturing_blueprint(57490) = (34) = (0) = (-1) = false
is_reaction_blueprint(681) = false                  (unchanged literal, new reason)
buildable_product_count() = 4891
buildable_product_type_ids().first() = 165, .last() = 88721
blueprints_producing(57453 Carbon Fiber) = [57490]
blueprints_producing(17404 Small Blaster Battery) = [2813]
blueprints_producing(34) = [] ; blueprints_producing(0) = []
blueprints_producing(16672) = [45732, 46207]
blueprints_producing(21527) = [21522, 21524, 21526, 21528, 21530]
the products with blueprints_producing(p).len() > 1, over all
buildable products, are exactly {16672, 21527, 22925, 23416, 37161}
product_row_for(57490, 57453) = activity 11, quantity 200
product_row_for(2813, 17404) = activity 1, quantity 1
product_row_for(57490, 17404) = None
```

Manufacturing spot pins (file order; names in
parentheses are the `fitting_types.json` resolutions
Builder B asserts):

```text
2813 (Small Blaster Battery Blueprint)
  materials: (2872 Self-Harmonizing Power Core, 1), (564 Light Neutron Blaster I, 1)
  products:  (17404 Small Blaster Battery, 1)
1115 (Light Neutron Blaster I Blueprint)
  materials: (34 Tritanium, 1596), (35 Pyerite, 690), (36 Mexallon, 144)
  products:  (564, 1)
4316 (Hydrogen Fuel Block Blueprint)
  materials: (9848 Robotics, 1), (44 Enriched Uranium, 4),
             (3689 Mechanical Parts, 4), (9832 Coolant, 9),
             (16275 Strontium Clathrates, 20), (3683 Oxygen, 22),
             (16272 Heavy Water, 170), (16273 Liquid Ozone, 350),
             (17889 Hydrogen Isotopes, 450)
  products:  (4246 Hydrogen Fuel Block, 40)
2769 (Reprocessing Array Blueprint)
  materials: (12238 Reprocessing Array, 1)
  products:  (12238, 1)
```

Invariants, split per activity over the retained rows
(the shipped single-activity test becomes two halves
with the same assertion shapes): every retained row's
`activity_id` is 1 or 11 as filtered; no duplicate
`(type_id, activity_id, material/product)` keys;
products per blueprint exactly 1 for all 4,805
activity-1 and all 112 activity-11 blueprints;
materials-per-blueprint distribution at activity 1
exactly `{1: 346, 2: 231, 3: 862, 4: 769, 5: 656,
6: 415, 7: 499, 8: 140, 9: 236, 10: 199, 11: 273,
12: 33, 13: 33, 14: 12, 15: 50, 16: 5, 17: 6, 18: 12,
19: 15, 20: 3, 21: 9, 22: 2, 23: 3, 24: 2}` and at
activity 11 unchanged `{2: 1, 3: 69, 4: 36, 5: 5, 6: 1}`;
distinct material / product types 1,571 / 4,797 at
activity 1 and 111 / 111 at activity 11; both blueprint
lists and the buildable-product list strictly ascending;
the two blueprint intersections disjoint.

`from_json` fixture cases (the shipped test bodies
adapted, flips marked):

- **Scope (flips):** valid activity-1 and activity-11
  rows are both kept, activity-8 dropped; a fixture
  whose unloaded sections contain garbage still loads
  (unchanged pin). The shipped case asserting an
  activity-1-only catalogue is `Err` flips: it loads
  with `manufacturing_blueprint_count() = 1` and
  `reaction_blueprint_count() = 0`; the mirror
  activity-11-only case loads likewise.
- **Dedup with activity (new):** the same
  `(typeId, materialTypeId)` at activities 1 and 11 are
  both kept with their own quantities; the same triple
  repeated still keeps the first row only (shipped
  duplicate pins replayed per activity).
- **Skips / failure (unchanged shapes):** non-positive
  ids or quantities skipped at both activities; `"not
  json"`, `{}`, both sections empty, only out-of-scope
  rows, materials with no matching products at **either**
  activity, and a row missing `quantity` each return
  `Err`.
- **Accessors (updated):** a manufacturing blueprint
  yields `None` from both reaction accessors and a
  reaction blueprint `None` from both manufacturing
  accessors; the shipped 681 fixture case updates to
  assert `reaction_materials(681)` is `None` because 681
  is not a reaction blueprint (its activity-1
  materials-only fixture rows make it a manufacturing
  orphan, so `manufacturing_materials(681)` is also
  `None` while the rows still count); a fixture
  blueprint carrying rows at both activities returns
  only its own activity's rows from each accessor; an
  orphan blueprint's product yields
  `blueprints_producing(product) = []`, and a buildable
  blueprint in the same fixture yields its product.

**Builder A — pure chain tests** (`src/production_chain.rs`).
Synthetic graph fixture (one `from_json` string; ids are
fixture-local): blueprint 100 (activity 1) materials
`[(200, 2), (34, 5)]`, product `(300, 1)`; blueprint 101
(activity 11) materials `[(34, 7)]`, product `(200, 10)`;
blueprint 102 materials `[(401, 1)]`, product `(400, 1)`;
blueprint 103 materials `[(400, 3), (34, 2)]`, product
`(401, 1)`; blueprint 104 materials `[(500, 1), (34, 3)]`,
product `(500, 1)`; blueprints 105 (materials `[(34, 1)]`)
and 106 (materials `[(34, 9)]`) both product `(600, 1)`;
blueprint 107 materials `[(600, 2), (34, 1)]`, product
`(700, 1)`; blueprint 108 materials `[(34, 2)]`, product
`(800, 1)`; blueprint 109 materials `[(34, 1)]`, product
`(900, 1)`; unspecified activities are activity 1.
Assertions, each with its arithmetic in a comment:

```text
build_chain(fx, 300, 1):
  300 Produced act 1 qty 1, runs 1
    200 Produced act 11 qty 2        // runs = ceil(2/10) = 1: batch, not 2
      34 RawMaterial qty 7           // 7 * 1 run; straight multiplication gives 14
    34 RawMaterial qty 5
build_chain(fx, 300, 6):
  200 child qty 12, its 34 child qty 14   // runs = ceil(12/10) = 2; 7 * 2
  direct 34 child qty 30                 // 5 * 6 runs of the root
build_chain(fx, 200, 10): 34 child qty 7  // exactly one batch: runs 1
build_chain(fx, 200, 11): 34 child qty 14 // one unit over: runs 2
build_chain(fx, 400, 1):
  401 Produced qty 1; its children are 400 Cycle qty 3, then 34 RawMaterial qty 2
build_chain(fx, 500, 1): children are 500 Cycle qty 1, then 34 RawMaterial qty 3
build_chain(fx, 600, 4): single MultipleBlueprints node, qty 4, no dependencies
build_chain(fx, 700, 1): children are 600 MultipleBlueprints qty 2, then 34 RawMaterial qty 1
build_chain(fx, 34, 1): single RawMaterial node (the Flutter oracle shape, on fixture data)
build_chain(IndustryRef::default(), 300, 1): single RawMaterial node (total over any catalogue)
```

Generated fixtures (the test builds the JSON in a loop —
no 16-row literal is hand-typed): a 20-deep linear chain
(blueprints 1000+i making product 2000+i from product
2001+i ×1, product 2020 unmade) gives 17 nodes: depths
0–15 `Produced`, depth 16 `Truncated` with
`production_activity_id = Some(1)`, 16 expansions; a
shared-level fan-out (root product 3000 needing products
3100–3109 ×1 each; each 31xx needing 3200–3209; each
32xx needing 3300–3309; each 33xx needing 3400–3409;
each 34xx needing 34 ×1 — 41 blueprints, 11,111 would-be
expansions) gives `Some` with exactly
`MAX_CHAIN_EXPANSIONS` (5,000) `Produced` nodes and at
least one `Truncated` node. Validation and overflow
matrix, one assertion per section 7 rule:
`build_chain(fx, 0, 1)`, `(fx, -1, 1)`, `(fx, 300, 0)`,
`(fx, 300, -1)` are `None`;
`build_chain(fx, 800, i64::MAX)` is `None` (child
`2 * i64::MAX` overflows) while `build_chain(fx, 900,
i64::MAX)` is `Some` with child quantity `i64::MAX` and
`build_chain(fx, 34, i64::MAX)` is `Some` raw at
`i64::MAX` (no multiplication exists to overflow — the
exactness-to-`i64` pin). Parser cases mirror
`parse_runs` exactly: `"1"` → 1, `" 10 "` → 10,
`"9223372036854775807"` → `i64::MAX`; `""`, `"0"`,
`"-1"`, `"1.5"`, `"1,000"`, `"abc"` → `None`.
`production_chain_result` cases: `(fx, 300, "1")` replays
the first tree; `(fx, 300, "")` and `(fx, 300, "0")` are
`None`; `(fx, 800, "9223372036854775807")` is `None`
though the text parses. Defaults: `DEFAULT_QUANTITY = 1`,
`MAX_CHAIN_DEPTH = 16`, `MAX_CHAIN_EXPANSIONS = 5_000`.

Real-data pins over the bundled catalogue (pre-order
projections of `(type_id, quantity_required, kind,
production_activity_id)`; names are Builder B's):

```text
build_chain(34, 1) = [(34, 1, RawMaterial, None)]        // Flutter oracle, real data
build_chain(17404 Small Blaster Battery, 1) =
  (17404, 1, Produced, 1)
    (2872, 1, RawMaterial, None)
    (564, 1, Produced, 1)
      (34, 1596, RawMaterial), (35, 690, RawMaterial), (36, 144, RawMaterial)
build_chain(17404, 3): same shape, quantities 3; 3; 3; 4788; 2070; 432
build_chain(57453 Carbon Fiber, 1) =
  (57453, 1, Produced, 11)                    // batch 200: 1 run
    (4246 Hydrogen Fuel Block, 5, Produced, 1) // batch 40: 1 run for 5
      (9848, 1), (44, 4), (3689, 4), (9832, 9), (16275, 20),
      (3683, 22), (16272, 170), (16273, 350), (17889, 450)   // all RawMaterial
    (16633, 100, RawMaterial), (16635, 100, RawMaterial)
build_chain(57453, 201): root runs 2 → (4246, 10) with the identical
  1-run subtree above (its own batch 40 still gives 1 run),
  (16633, 200), (16635, 200); 13 nodes in both trees
build_chain(12238 Reprocessing Array, 1) =
  [(12238, 1, Produced, 1), (12238, 1, Cycle, None)]
build_chain(11543 Tungsten Carbide Armor Plate, 1): 39 nodes;
  node at depth 1 first child = (16672, 44, MultipleBlueprints, None);
  second child = (16678 Sylramic Fibers, 11, Produced, 11)
build_chain(16672, 1) = [(16672, 1, MultipleBlueprints, None)]  // ambiguous root
build_chain(77288 Valravn, 1): 2265 nodes, maximum depth 7
```

Caps-unreachable invariant over the whole shipped
catalogue (the section 2 bounds, executable): for every
product in `buildable_product_type_ids()`,
`build_chain(bundled, product, 1)` is `Some`, contains
no `Truncated` node, and the maxima over all of them are
exactly depth 7 and 2,265 nodes; exactly 51 of those
trees contain a `Cycle` node and each such node is its
parent's only child at quantity 1.

**Builder A — state tests** (`src/app/state.rs`):
`AppState::new(false)` has `industry_chain_search = ""`,
`industry_chain_selected_type_id = None`,
`industry_chain_quantity = "1"` (formatted from the
constant); `set_active_character` across a switch leaves
all three unchanged (set to non-default values first,
the shipped survival shape).

**Builder B — choice, renderer, and shell tests**
(`src/ui/industry.rs`, `src/app/shell.rs`):

- Verbatim heading, the two input labels, all six fixed
  sentences, `PRODUCTION_CHAIN_CHOICE_RENDER_MAX = 100`,
  and the disclosure constant (byte-exact against
  section 9), plus the two amended disclosures with the
  production-chain sentence deleted and every other
  character unchanged.
- Choice rows over both bundled catalogues: 4,299 rows;
  the first four names exactly section 4's list; no row
  carries internal product 21527, 22925, 23416, 37161,
  or 16672 (ambiguous) or 165 (unnamed); search
  `"carbon fiber"` yields exactly `Carbon Fiber` and
  `Reinforced Carbon Fiber` in that order; search
  `"ORCA"` yields exactly `Orca` (case-insensitive
  substring, not prefix); a nonsense search yields no
  rows. A dual-fixture case (both catalogues from
  `from_json`, the shipped reaction test's shape) pins
  all three exclusions at once: a named
  single-blueprint product remains while an ambiguous
  product, a product with no item row, and a product
  whose item name is purely numeric are each excluded.
- Starting-quantity result (selection 17404 set by the
  test, quantity draft `1`), whole-vector equality:

  ```text
  Production Chain: Small Blaster Battery
  Small Blaster Battery: 1 (Manufacturing)
    Self-Harmonizing Power Core: 1 (Raw Material)
    Light Neutron Blaster I: 1 (Manufacturing)
      Tritanium: 1596 (Raw Material)
      Pyerite: 690 (Raw Material)
      Mexallon: 144 (Raw Material)
  ```

  followed by the disclosure. At quantity `3` the same
  vector with quantities 3, 3, 3, 4788, 2070, 432
  (1596×3, 690×3, 144×3 at batch 1 throughout).
- Batch results (selection 57453, the reaction slice's
  Carbon Fiber product). At quantity `1`, whole-vector:

  ```text
  Production Chain: Carbon Fiber
  Carbon Fiber: 1 (Reaction)
    Hydrogen Fuel Block: 5 (Manufacturing)
      Robotics: 1 (Raw Material)
      Enriched Uranium: 4 (Raw Material)
      Mechanical Parts: 4 (Raw Material)
      Coolant: 9 (Raw Material)
      Strontium Clathrates: 20 (Raw Material)
      Oxygen: 22 (Raw Material)
      Heavy Water: 170 (Raw Material)
      Liquid Ozone: 350 (Raw Material)
      Hydrogen Isotopes: 450 (Raw Material)
    Hydrocarbons: 100 (Raw Material)
    Evaporite Deposits: 100 (Raw Material)
  ```

  followed by the disclosure — one whole run for a
  quantity of 1 against batch 200, and one fuel-block
  run (batch 40) for the 5 needed. At quantity `201`
  the root takes 2 runs: the vector is identical except
  root quantity 201, `Hydrogen Fuel Block: 10` with the
  same 1-run subtree quantities (10 still fits one
  batch-40 run — the nested-ceiling pin), and
  `Hydrocarbons: 200`, `Evaporite Deposits: 200`.
- Cycle result (selection 12238, quantity `1`),
  whole-vector: header `Production Chain: Reprocessing
  Array`, root `Reprocessing Array: 1 (Manufacturing)`,
  child `  Reprocessing Array: 1 (already in this
  chain; not expanded again)`, then the disclosure.
- Ambiguous-in-chain and unknown-name lines by dual
  fixture (industry fixture: blueprints 105/106 both
  making product 600 as in Builder A's fixture,
  blueprint 107 making product 700 from `(600, 2)` and
  `(999, 3)`; item fixture naming 700 `Thingamajig` and
  600 `Doohickey`, with 999 absent and an empty
  `NameResolver`), selection 700 at quantity `1`,
  whole-vector: header `Production Chain: Thingamajig`,
  `Thingamajig: 1 (Manufacturing)`, `  Doohickey: 2
  (more than one blueprint makes this item; not
  expanded)`, `  Unknown Item: 3 (Raw Material)`, then
  the disclosure; and no rendered line in any success
  or guidance case contains a bare type number used by
  the fixtures (asserted on the joined lines, fixture
  quantities chosen to not collide, the shipped shape).
- Uncapped rendering pin: selection 28606 `Orca` at
  quantity `1` gives exactly 512 lines (header + 510
  node lines + disclosure) — node lines are never
  render-capped (section 9).
- Guidance precedence, whole-vector equality per case:
  `industry_data = None` (with and without fitting
  types) → `[no-industry-data]`; fitting types `None`
  alone → `[no-item-data]`; no selection → `[choose,
  disclosure]`; fabricated selections 21527 (ambiguous),
  34 (unbuildable), and 165 (single but unnamed) →
  `[choose, disclosure]` each; selection 17404 with
  quantity `""`, `"0"`, or `"1.5"` → `[input guidance,
  disclosure]`; selection 17404 with quantity
  `"9223372036854775807"` → `[no-result guidance,
  disclosure]` (its batch-1 chain multiplies by runs of
  `i64::MAX`). No quantity line appears in any guidance
  state.
- Shell startup: the shipped
  `industry_load(IndustryRef::load_bundled())` test gains
  `manufacturing_blueprint_count() = 4788` beside its
  unchanged `reaction_blueprint_count() = 112` (and the
  malformed-JSON `None` case unchanged).
- Demo independence: `seed_demo_state` leaves the three
  chain fields exactly as constructed, the seeded state
  renders `[choose, disclosure]` over the bundled
  catalogues, and choosing 17404 in that state renders
  the starting-quantity block above unchanged.
- Regression: every existing industry test passes with
  only the named changes (the two disclosure sentences
  here; the loader pins are Builder A's) — this slice
  inserts one block after the reaction block and
  rewords no other existing line.

**Gates (every commit):** `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`,
`cargo build`.

## 11. Deferrals and exclusions (locked — ship-nothing lines are explicit)

- **No efficiency or bonus of any kind.** No owned
  blueprint's material or time efficiency is applied
  (the blueprint library's loaded efficiency values are
  never read by this block), no facility or structure
  bonus — the reaction block's bonus field does not
  reach into the chain, and the reaction rounding rule
  is never generalized to chain nodes — no skill effect,
  and no activity time, job duration, or finish-time
  figure (`activities` rows stay unloaded). The shipped
  "no manufacturing calculator over owned blueprints"
  line survives in this form: the chain is a traversal
  of bundled catalogue data at face-value per-run
  quantities, never a calculation over a blueprint the
  reader owns, and no owned blueprint is read even when
  the reader holds the very blueprint a node expands.
- **No aggregation, netting, or shopping list.** The
  same item in several branches renders per branch and
  is never summed; there is no raw-materials totals
  section, no surplus or leftover line beyond what the
  disclosure states, and leftovers from one node's
  part-used run never reduce another node's need.
  Summing like items and netting leftovers are each a
  second rule over the tree that no inspected body
  makes; a future slice would need to lock them as its
  own decisions, including how ambiguous and cycle
  leaves total.
- **No derived figures.** No cost, price, profit, or ISK
  figure of any kind; no runs or batch line per node
  (runs are internal arithmetic, section 6 — the node's
  quantity and producing activity are the rendered
  facts); no "materials you already own" subtraction
  against loaded assets; no comparison across items.
- **No blueprint display or choice.** Blueprint type
  names (`… Blueprint`, `… Reaction Formula`) never
  render in this block; the reader chooses items, and
  the producing blueprint's identity is internal. There
  is no per-node blueprint picker for ambiguous items —
  offering one would need a grounded reason to prefer a
  candidate, and section 2 shows the candidates are
  genuinely different recipes with no inspected
  preference among them. There is no editing of any
  per-run or per-node quantity (Flutter's panels never
  allowed it either); the quantity is the only numeric
  input.
- **No canvas or interactive tree.** The Flutter
  visualizer's Tree / `2D Canvas` toggle and its
  drag-and-drop placeholder ship nothing and are not
  recreated, even disabled (the calculators design's
  lock, carried forward). No collapsing or expanding
  controls, icons, or colour coding
  (`Icons.category` / `Icons.precision_manufacturing`
  have no counterpart locked here): the block is plain
  indented labels, all of them pinned as strings.
- **No invention change.** The `probabilities` and
  `skills` sections stay unloaded and activity 8 stays
  out of scope; the shipped Invention Calculator gains
  no autofill from this slice's widened loader.
- **No requirement or ownership claims.** No skill
  requirement line, no check that the reader owns the
  blueprints or materials or can run any job in the
  chain, nothing read from loaded jobs, blueprints,
  assets, or skills. The choice list is the bundled
  catalogue's buildable items whether or not the reader
  holds any of them.
- **No persistence and no writes.** The three chain
  fields live only for the session; no job can be
  started, cancelled, or delivered; the view sets no
  new request flag and needs no new EVE SSO (single
  sign-on) scope, character, or network. No shell
  name-resolution scheduling is added (section 4).
- **No asset or generator change.** `assets/sde/
  industry.json` loads as shipped; no narrower extract
  is generated. Retaining 27,190 rows instead of 384
  grows only runtime index memory — the 5,094,242-byte
  file was already baked into the binary whole by the
  reaction slice.
- No change to `IndustryData`, `industry_job_rows`,
  `blueprint_rows`, the blueprint filter, the step-up
  panel, ESI (the EVE Swagger Interface) endpoints or
  models, demo JSON, or the invention and reaction
  calculators beyond the two module-doc notes
  (section 8), the two disclosure sentences
  (section 9), and the loader's widened retention with
  its activity-filtered accessors (section 3), which
  leave every shipped reaction result byte-identical.

## 12. Integrator list

- **README** (Industry bullet, line 20): replace "There
  is no production-chain calculator, and no production,
  cost, or profit calculator." with "The view also
  carries a production-chain calculator: you choose an
  item by name from Mimir's bundled industry data (an
  item with no name in the item data, or made by more
  than one bundled blueprint, cannot be chosen), type
  how many you want (starting value 1, never read from
  a blueprint you own or your character, and never
  checked against them), and it shows the item's full
  chain by name, each makeable item expanded into the
  materials for the whole runs needed to make at least
  the quantity shown, leftovers from a part-used run
  not subtracted from other lines, items made by more
  than one blueprint and items appearing inside their
  own chain shown without expansion, and no blueprint
  material efficiency, facility bonus, or skill
  applied; no chosen item, an empty or invalid
  quantity, or a quantity too large to calculate with
  shows guidance instead of any quantity. There is no
  cost or profit calculator." No other README bullet
  changes: the roadmap list carries no
  industry-calculator bullet to amend (verified in the
  earlier designs and unchanged at this base), and the
  Planets bullet's "no production or setup calculator"
  is about Planetary Industry, untouched.
- **Engineering journal**
  (`docs/engineering-journal/LEARNINGS.md`, integrator's
  commit): one entry with Evidence / Mechanism /
  generalizable rule — a traversal can be well-tested
  and still never traverse: Flutter's probe keyed
  materials by material type instead of by the blueprint
  that makes the material, the shipped data's zero
  overlap between item types and blueprint types makes
  every real root an immediate leaf, and the only test
  mocked exactly that leaf, so the recursion, its
  missing cycle guard, and its batch-blind arithmetic
  were all dead code that looked alive (sections 4, 6);
  correcting it needed the reverse index the earlier
  designs named, after which the per-run meanings an
  earlier slice had already locked forced the whole-run
  arithmetic (straight multiplication overstates one
  pinned leaf 1,005-fold) and the ambiguity rule turned
  out to be a refusal, because the five multi-blueprint
  products' candidates carry genuinely different
  recipes, so any tie-break would have been an invented
  answer wearing the data's clothes (sections 2, 6).
- Nothing else: no HANDOFF change beyond what the parent
  directs, no demo-data, ESI, scope, storage, generator,
  or SDE-asset change. The integrator's demo-mode check
  covers the choose-guidance with the demo bundle loaded
  (chain fields untouched by seeding), the Small Blaster
  Battery starting block, the Carbon Fiber batch block
  at quantities 1 and 201, the Reprocessing Array cycle
  line, and one capital-class root (Orca) rendered in
  full. If build discovery contradicts any literal in
  section 10, the slice stops rather than growing scope.

## 13. Ownership and commit split

- **Design (this commit):** `docs/production-chain-design.md`
  only. Commit:
  `docs(industry): design production chain builder`.
- **Builder A — loader, pure chain, and draft state:**
  the section 3 widening, reverse index, module doc, and
  loader tests in `src/names/industry_ref.rs`; new
  `src/production_chain.rs`, its `src/lib.rs`
  registration, the section 8 module-doc replacements in
  `src/invention_calculator.rs` and
  `src/reaction_calculator.rs`, and the pure tests; the
  three `AppState` chain fields and their seeding in
  `src/app/state.rs` with the state tests. Commits:
  `feat(industry): retain manufacturing industry data with reverse product index`,
  `feat(industry): add pure production chain builder`,
  `feat(industry): add production chain draft state`.
- **Builder B — render and shell log:** the block, choice
  helper, line helper, constants, the two disclosure
  sentence deletions, and the Builder-B tests in
  `src/ui/industry.rs`, together with the one
  `industry_load` log line and its added count pin in
  `src/app/shell.rs` (no shell signature or call-site
  change exists to split out — `show()` already receives
  both catalogues). Commit:
  `feat(industry): show production chain calculator in industry view`.
- **Integrator:** README and journal per section 12,
  full gates, and the section 12 demo-mode check.
  Commit: `docs(industry): document production chain calculator`.

Builder B touches no `src/names/`,
`src/production_chain.rs`, `src/lib.rs`, or
`src/app/state.rs` file and codes against sections 3, 5,
and 8's locked APIs and field names and section 9's
wording; Builder A touches no `src/ui/` file and no
`src/app/shell.rs` file. The one deliberate overlap in
time is the shell log line, which lands with Builder B;
between Builder A's loader commit and Builder B's
commit the startup log still names only the reaction
count — incomplete for the widened catalogue, never
wrong — rather than splitting one log line across a
builder boundary. Small atomic commits,
`type(scope): description`, no attribution lines. Nobody
pushes or merges; the parent does that.
