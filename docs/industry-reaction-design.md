# Industry reaction data and calculator — design

Status: locked for the `feat/rust-industry-reaction` slice.
Base: `develop` at `4984082` (937 tests stated at slice start;
this design commit re-runs the section 10 gates).
Slice branch: `feat/rust-industry-reaction`.
This slice is the future slice named by
`docs/industry-calculators-design.md` section 9, which deferred
the reaction calculator for exactly two missing pieces: a Rust
loader for the activity-11 tables in `assets/sde/industry.json`
and a way to choose a reaction blueprint by resolved name.

Discovery: two read-only reports — one on the retired Flutter
reaction bodies and the shipped `industry.json`, one on the
Rust bundled-data loaders and calculator seams. During design
the bodies were re-read directly (`git show ed698d3:` for
`lib/features/industry/domain/reaction_calculator.dart`,
40 lines, `reaction_calculator_panel.dart`, 272 lines,
`reaction_calculator_test.dart`, 52 lines, and
`production_chain_builder.dart` with its test; the Rust bodies
`src/names/fitting_types.rs`, `src/invention_calculator.rs`,
`src/trade_calculator.rs`, `src/ui/industry.rs`,
`src/app/state.rs`, `src/app/shell.rs`, `src/names/resolver.rs`,
`src/names/mod.rs`, and `src/lib.rs`), the shipped
`assets/sde/industry.json` and `assets/sde/fitting_types.json`
were re-counted by script, and every arithmetic literal in
sections 6 and 10 was cross-checked with a Rust probe. No EVE
bonus, quantity, or formula here is recalled from outside
those bodies. Two discovery details the design scripts
corrected, recorded so nobody re-derives them wrong: the 112
activity-11 skill rows are Reactions (skill 45746) at levels
1 to 5 (15 at level 1, 34 at 2, 34 at 3, 26 at 4, 3 at 5), not
levels 1 to 4; and activity-11 times are 10,800 seconds for
94 blueprints, 21,600 for 17, and 360 for one (type 45732),
not 10,800 for all but one. Neither table is loaded by this
slice (section 2), so neither correction changes any locked
behaviour; they matter only as evidence about the file.

**Grounded verdict up front:**

- **The industry data loader ships in this slice, narrow on
  purpose.** It deserializes only the `materials` and
  `products` sections of `assets/sde/industry.json` and
  retains only activity 11 (Reaction) rows: 384 material rows
  and 112 product rows over 112 reaction blueprints in the
  shipped file (section 2). The `activities`,
  `probabilities`, and `skills` sections and every
  non-reaction activity stay unloaded, by name.
- **The reaction calculator ships in this slice.** The reader
  chooses a reaction by its resolved name from a searchable
  list built only from blueprints the loaded data proves are
  reactions (111 of the 112 carry a name in the bundled item
  catalogue; the one without a name cannot be chosen,
  section 4), types runs and a facility material bonus
  percent (section 5), and sees input and output quantities
  by resolved item name, computed with the retired Flutter
  app's exact total-then-round formula and minimum-of-1 guard
  (section 6). No raw numeric ID is rendered anywhere.
- **The production chain ships nothing again (deferred).** It
  needs activity-1 materials this loader deliberately does
  not retain, a reverse product-to-blueprint index, a
  batch-size and cycle decision Flutter never made, and a
  tree display with no locked precedent (section 11).

## 1. Goal and value ranking

Add a Reaction Calculator block to the Industry view, beside
the shipped Invention Calculator, and the bundled-data loader
that makes it honest: the reader picks a named reaction
formula, enters how many runs and what facility material
bonus percent to assume, and sees how much of each named
input material those runs need and how much of the named
output product they make.

Value ranking (locked, in order):

1. **Never a plausible-looking quantity from an absent,
   invented, or overflowed input.** No reaction chosen means
   no quantities at all; Flutter's dummy material maps are
   never ported; an empty, invalid, or too-large field
   renders guidance, never a computed-looking `0`; and every
   multiplication is checked so a huge run count yields no
   result instead of a wrapped or float-shifted total
   (sections 4, 7).
2. **Names, never numbers.** Every blueprint, material, and
   product the reader sees is a resolved EVE name or the
   honest word fallback `Unknown Item`; numeric type IDs
   exist only as internal lookup keys, in tests, and in this
   design's evidence (section 4).
3. **Grounded data and math only.** Quantities come from the
   shipped SDE (Static Data Export, EVE's published static
   game data) extract already on disk, counted by script in
   section 2; the arithmetic is Flutter's, quoted in
   section 6 and pinned by its four test oracles plus
   real-data pins (section 10).
4. **Reuse.** The loader copies `FittingTypes`
   (`src/names/fitting_types.rs`), the shipped multi-megabyte
   bundled catalogue, not the skills-only `Sde` and not the
   strict `ExplorationRef` (section 3); the calculator copies
   the `src/invention_calculator.rs` / `src/trade_calculator.rs`
   pure-module shape, session-only `String` drafts in
   `AppState`, a pure line-building helper in the view, and
   verbatim wording in named constants.

## 2. The bundled industry data (scripted — what loads, what does not)

`assets/sde/industry.json` is 5,094,242 bytes, generated by
`scripts/sde/generate_industry_sde.py` from the Fuzzwork CSV
dumps with an unfiltered one-to-one column mapping (design
discovery read the generator in full). Its top-level keys are
exactly `activities`, `materials`, `probabilities`,
`products`, and `skills`, each a list of row objects whose
`typeId` is an integer field inside the row — not a
string-keyed map. Scripted counts in the shipped file:

| Section | Rows | Row shape | Activity-11 rows |
|---|---|---|---|
| `activities` | 19,023 | `{typeId, activityId, time}` | 112 |
| `materials` | 36,193 | `{typeId, activityId, materialTypeId, quantity}` | 384 |
| `probabilities` | 1,341 | `{typeId, activityId, productTypeId, probability}` | 0 |
| `products` | 6,266 | `{typeId, activityId, productTypeId, quantity}` | 112 |
| `skills` | 22,257 | `{typeId, activityId, skillId, level}` | 112 |

Per-activity row counts (activities / materials /
probabilities / products / skills): activity 1
Manufacturing 4,828 / 26,806 / 0 / 4,805 / 9,109; activity 3
time-efficiency research 4,326 / 2,401 / 0 / 0 / 3,693;
activity 4 material-efficiency research 4,326 / 2,576 / 0 /
0 / 3,806; activity 5 Copying 4,326 / 1,818 / 0 / 0 / 2,137;
activity 8 Invention 1,105 / 2,208 / 1,341 / 1,349 / 3,400;
activity 11 Reaction 112 / 384 / 0 / 112 / 112.

**Locked — the loader reads two sections, one activity:**

- **`materials` at activity 11** (384 retained rows): the
  per-run base inputs keyed by reaction blueprint type. This
  is one of the two quantity maps `industry-calculators-design.md`
  section 9 named as missing data (a).
- **`products` at activity 11** (112 retained rows): the
  per-run outputs keyed by the same blueprint type, the
  other missing map.

**Locked — what stays unloaded, and why:**

- **`activities` (all 19,023 rows, including its 112
  activity-11 rows):** the calculator displays no duration
  (Flutter's panel displays none), and reaction membership
  needs no time row — section 3 defines a reaction blueprint
  as a type carrying both retained material rows and retained
  product rows at activity 11. The scripts prove the shipped
  file's activity-11 type set is identical across
  `activities`, `materials`, `products`, and `skills` (112
  types, zero symmetric difference), so the intersection
  definition names the same 112 blueprints today.
- **`probabilities` (1,341 rows, every one activity 8):**
  invention data. Reactions have no probability rows, and
  the shipped Invention Calculator deliberately takes its
  base probability from the reader, not this table
  (`industry-calculators-design.md` sections 3 and 9). This
  slice does not reopen that lock.
- **`skills` (22,257 rows, including its 112 activity-11
  rows):** the formula consumes no skill level, the block
  displays no skill requirement, and it never checks whether
  the reader can run the reaction — the disclosure says so
  (section 9). Loading requirements the block would only
  display next to a character it never reads would invite
  exactly the wrong-skill prefill the invention slice
  refused.
- **Every non-11 activity in the two loaded sections**
  (35,809 material rows and 6,154 product rows): manufacturing
  and research data for calculators that do not ship
  (section 11). The deserialized rows are dropped at index
  build; retained memory is the 496 activity-11 rows.

Activity-11 shape in the shipped file, scripted: exactly one
product row per reaction blueprint (distribution `{1: 112}`);
materials per blueprint `{2: 1, 3: 69, 4: 36, 5: 5, 6: 1}`;
111 distinct material types and 111 distinct product types;
retained quantities range from 1 to 10,000 in both sections;
no duplicate primary keys on `(typeId, activityId,
materialTypeId)` or `(typeId, activityId, productTypeId)`, and
no zero or negative quantities. (The unloaded `skills`
section does carry four duplicated primary keys elsewhere in
the file — one more reason it is not this slice's problem.)
Zero types appear at both activity 1 and activity 11, so no
manufacturing blueprint can be mistaken for a reaction.

**Name coverage, scripted against
`assets/sde/fitting_types.json`** (25,818 types): 111 of the
112 activity-11 blueprint types resolve to a name ending
`Reaction Formula` (for example type 46157,
`Methanofullerene Reaction Formula`, category 9), and all
111 material types and all 111 product types resolve. The
one blueprint without a name in that catalogue is type
45732 — also the file's lone 360-second activity outlier.
The skills-only extract (`assets/sde/skills.json`, 495 types)
and `assets/sde/dogma.json` resolve none of these. Section 4
locks the consequences: choice and display names come from
`FittingTypes`, and 45732 is in the loaded data but can never
be chosen, because a name-based choice cannot present a
formula it cannot name.

**Size consequence, stated plainly:** `include_str!` bakes
the whole 5,094,242-byte file into the binary no matter how
few rows the loader retains (the same trade
`docs/bay-capacities-design.md` records for the 3,622,804-byte
fitting-types catalogue), roughly doubling today's
approximately 4.7 MB of baked-in extracts. This slice accepts
that growth and adds no narrower extract generator and no
runtime file loading: the shipped file is the source of
truth Flutter loaded, and regenerating or subsetting it on
disk is a data-pipeline decision for its own slice, not a
silent side effect of this one. The load is one synchronous
parse in `MimirApp::new` alongside the existing three bundled
loads, exactly as `FittingTypes` loads — never in a render
path.

## 3. Loader API and behaviour (locked — the `FittingTypes` precedent)

New module `src/names/industry_ref.rs`, declared in
`src/names/mod.rs` as `pub mod industry_ref;` in alphabetical
position between `fitting_types` and `resolver`. It is not
re-exported from `mod.rs` — the `ExplorationRef` precedent
(`src/app/shell.rs` imports
`crate::names::exploration_ref::ExplorationRef` by full path)
— so call sites name `crate::names::industry_ref::IndustryRef`.
The type is `IndustryRef`, never `IndustryData`: that name is
already the per-character network bundle (`AppState::industry`,
jobs plus owned blueprints) and the two concepts must never
share a name, a field, or a `LoadState` match.

```rust
pub const REACTION_ACTIVITY_ID: i64 = 11;

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct IndustryMaterial {
    #[serde(rename = "typeId")]
    pub type_id: i64,
    #[serde(rename = "activityId")]
    pub activity_id: i64,
    #[serde(rename = "materialTypeId")]
    pub material_type_id: i64,
    #[serde(rename = "quantity")]
    pub quantity: i64,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct IndustryProduct {
    #[serde(rename = "typeId")]
    pub type_id: i64,
    #[serde(rename = "activityId")]
    pub activity_id: i64,
    #[serde(rename = "productTypeId")]
    pub product_type_id: i64,
    #[serde(rename = "quantity")]
    pub quantity: i64,
}

#[derive(Debug, Clone, Default)]
pub struct IndustryRef {
    pub materials: Vec<IndustryMaterial>,
    pub products: Vec<IndustryProduct>,
    // private: blueprint type -> row indices, file order
    // private: sorted Vec<i64> of reaction blueprint types
}

impl IndustryRef {
    pub fn load_bundled() -> AppResult<Self>;
    pub fn from_json(json: &str) -> AppResult<Self>;
    pub fn material_count(&self) -> usize;
    pub fn product_count(&self) -> usize;
    pub fn reaction_blueprint_count(&self) -> usize;
    pub fn reaction_blueprint_type_ids(&self) -> &[i64];
    pub fn is_reaction_blueprint(&self, type_id: i64) -> bool;
    pub fn reaction_materials(&self, type_id: i64) -> Option<Vec<&IndustryMaterial>>;
    pub fn reaction_products(&self, type_id: i64) -> Option<Vec<&IndustryProduct>>;
}
```

Decisions locked:

- **Row fields are required and `i64` end to end,** with
  `#[serde(rename)]` keeping the file's camelCase keys — the
  `FittingType` identity-field convention
  (`fitting_types.rs:21-28`). No field carries
  `#[serde(default)]`: a retained-section row missing a field
  or carrying a wrong-typed one fails the whole parse (below).
  IDs and quantities are `i64` because the tree's other EVE
  quantities are.
- **The private file envelope declares only the two loaded
  sections** (`#[serde(default)] materials`,
  `#[serde(default)] products`), so the three unloaded
  sections are never deserialized — serde skips unknown keys,
  and there is no `deny_unknown_fields`. A future section
  appearing in a regenerated file cannot break this loader,
  and garbage inside an unloaded section cannot either
  (section 10 pins this). Only the two envelopes' rows are
  ever validated.
- **Activity 11 is baked into the API names.** There is no
  generic `(typeId, activityId)` query like Flutter's
  `SdeService.getIndustryMaterials(typeId, activityId)`
  (`sde_service.dart` at `ed698d3`): this loader retains one
  activity, so a generic signature could only be asked the
  one question it can answer and would return empty-looking
  answers for every other activity. `REACTION_ACTIVITY_ID`
  names the constant; a future slice that needs activity 1
  widens the retained set and the API deliberately, in the
  open (section 11).
- **A reaction blueprint is the intersection:** a type with
  at least one retained material row and at least one
  retained product row. `reaction_blueprint_type_ids` is
  that set sorted ascending by type number (the loader has
  no names; section 4 sorts for display). Rows for a type in
  only one section stay in the public vectors — they are
  loaded data, honestly counted — but
  `reaction_materials` and `reaction_products` return `None`
  for any type outside the intersection, so no half-reaction
  can ever be calculated. In the shipped file there are no
  such orphan types (section 2).
- **Lookups return row references in file order** through the
  index maps (blueprint type to `Vec<usize>`), never a
  cloned row and never a freshly scanned vector. They log
  nothing — the `FittingTypes::lookup_by_id` precedent
  (`fitting_types.rs:422-430`) — because they run at render
  cadence and because the queried type number can ultimately
  derive from a reader's click.
- **Scope filter first, then value validation, then
  duplicate keys — in that order, all in `from_json`:**
  1. Rows whose `activity_id` is not 11 are out of scope:
     dropped, not stored, and **not** counted as skipped.
     Counting the 41,963 out-of-scope rows as "skipped" would
     make the shipped file look corrupt in every startup log.
  2. Among activity-11 rows, a row is skipped and counted
     (`saturating_add`, the `fitting_types.rs:366-372` shape)
     when `type_id <= 0`, `material_type_id <= 0` /
     `product_type_id <= 0`, or `quantity <= 0`. Skipping is
     per-row and never fails the catalogue.
  3. A later row repeating an already-kept primary key —
     `(type_id, material_type_id)` for materials,
     `(type_id, product_type_id)` for products, activity
     being fixed — is skipped and counted; the first row in
     file order wins, mirroring the `by_id`
     `entry().or_insert()` rule (`fitting_types.rs:340-343,
     393-396`). Duplicate `type_id`s with *different*
     material or product types are normal many-to-one data,
     never an error — the reason `ExplorationRef`'s
     duplicate rejection is not copied.
- **Failure behaviour — the full list.** `from_json` returns
  `Err` only when (a) the JSON does not parse, including a
  retained-section row with a missing or wrong-typed required
  field (`AppError` from `serde_json`, propagated with `?`),
  or (b) the reaction-blueprint intersection is empty after
  filtering — which covers an empty file, empty sections,
  all-rows-invalid, and materials-without-products — as
  `AppError::Message("[INDUSTRY] industry reaction catalogue
  is empty")`, mirroring the `FittingTypes` empty check and
  its message shape (`fitting_types.rs:378-384`). An empty
  catalogue is never presented as valid. `from_json` never
  panics and never returns a partial catalogue as an error
  side effect: on `Err` there is no `IndustryRef` at all.
- **Logging (startup only):** `load_bundled` emits
  `tracing::debug!("[INDUSTRY] loading bundled industry
  data")` then parses `include_str!("../../assets/sde/
  industry.json")`; `from_json` emits one info line,
  `[INDUSTRY] industry reaction data loaded materials={}
  products={} reactions={} skipped={}`, with retained counts
  — the `fitting_types.rs:373-377` position (after filtering,
  before the empty check). No row contents, type numbers, or
  names are ever logged.
- **Startup wiring (Builder B, section 13)** mirrors
  `fitting_types_load` (`src/app/shell.rs:666-680`): a helper
  `industry_load(result: AppResult<IndustryRef>) ->
  Option<Arc<IndustryRef>>` beside it, logging
  `[INDUSTRY] bundled industry data loaded reactions={}` at
  info on success and `[INDUSTRY] bundled industry data
  failed to load: {}` at warn on failure; a field
  `pub industry_data: Option<Arc<IndustryRef>>` on `MimirApp`
  beside `fitting_types` (`shell.rs:126`), assigned in
  `MimirApp::new` beside the fitting-types load
  (`shell.rs:849`) and in the `Self { … }` literal. The
  helper takes the `Result` as an argument so the shell test
  can pass `IndustryRef::from_json("{not json")` without
  touching the bundled file (the `shell.rs:4417-4423`
  precedent). Failure is `None` and the reaction block shows
  its fixed unavailable sentence while industry jobs and
  blueprints keep rendering (section 9) — the Fittings
  degradation mode, not `ExplorationRef`'s whole-view error
  and never `Sde`'s silent empty default.

## 4. Choosing a reaction and resolving names (locked)

Flutter never shipped this choice: its panel hard-codes dummy
maps (`{16641: 100, 16642: 100, 16643: 100}` to
`{16654: 10}`, `reaction_calculator_panel.dart:22-30`,
commented `// Dummy base inputs and outputs for testing`)
and renders every row as `Item #<id>`. Even its inline name
comments are wrong against the bundled catalogue (16641 /
16642 / 16643 are Chromium / Vanadium / Cadmium and 16654 is
Titanium Chromide in `fitting_types.json`, not the names the
comments claim). The dummy maps, their quantities, and their
comments are never ported, in whole or in part.

**The choice is a searchable name list over proven
reactions — locked.** A pure helper in `src/ui/industry.rs`
builds the choice rows so they are testable without an egui
(the immediate-mode GUI library) frame:

```rust
pub struct ReactionChoiceRow {
    pub type_id: i64,   // internal key only, never rendered
    pub name: String,
}

fn reaction_choice_rows(
    industry_data: &IndustryRef,
    fitting_types: &FittingTypes,
    query: &str,
) -> Vec<ReactionChoiceRow>;
```

- The universe is exactly
  `industry_data.reaction_blueprint_type_ids()` (section 3's
  intersection) — types the loaded data proves are reaction
  blueprints. No owned blueprint, job, or character data
  widens or narrows it; the reader need not own the formula.
- Each blueprint's display name is
  `fitting_types.lookup_by_id(type_id)` (synchronous,
  offline, logs nothing, `fitting_types.rs:426-430`). A
  blueprint whose lookup returns `None`, or whose name is
  empty after trimming or parses as an integer, **does not
  appear in the list at all** — the Market view's
  `candidate_word` guard (`src/ui/market.rs`) applied as an
  exclusion rather than a substitution, because an
  `Unknown Item` row in a choice list cannot be told apart
  from any other unnamed formula and would let the reader
  "choose" a reaction they cannot identify. In the shipped
  catalogues this excludes exactly one blueprint (45732) and
  leaves 111 choosable reactions, every name ending
  `Reaction Formula`, no two names colliding (scripted,
  section 2). The disclosure states the unnamed-formula
  exclusion in words without a count or a number (section 9).
- Rows are filtered by `widgets::matches_search(name, query)`
  (case-insensitive substring, the tree's one search rule,
  `src/ui/widgets.rs`) and sorted by lowercased name, then
  name, then — for stability only — the internal type
  number, mirroring `blueprint_rows` ordering
  (`src/ui/industry.rs`). The first rows in the shipped data
  are `Axosomatic Neurolink Enhancer Reaction Formula`,
  `C3-FTM Acid Reaction Formula`, `Caesarium Cadmide Reaction
  Formula`, `Carbon Fiber Reaction Formula` (section 10
  pins them).
- The block renders at most `REACTION_CHOICE_RENDER_MAX`
  rows as `selectable_label`s — the tree has no `ComboBox`
  precedent anywhere in `src/ui/` or `src/app/` (verified
  during design), and selectable labels are how the Industry
  view already renders its blueprint-kind choice. The cap is
  100, the value every other list in the tree uses
  (`BLUEPRINT_RENDER_MAX`, `ASSETS_RENDER_MAX`,
  `EXPLORATION_RENDER_MAX`, `FITTINGS_RENDER_MAX`, all 100);
  when the filtered list is longer, one line
  `Showing {shown} of {total} reactions.` precedes the rows,
  so an empty search shows the first 100 of 111 and typing
  reaches the rest. When the search matches nothing, the
  list is replaced by `No reactions match the search.`
  (mirroring `No blueprints match the search.`).
- Clicking a row stores its type number in session state
  (section 5). The stored number is an internal key: it is
  never rendered, never logged, and never leaves the app.
  The selection itself survives a later search that filters
  its row out of the visible cap, because the result lines
  re-derive the chosen name from the catalogue every frame
  (section 9) rather than trusting the visible list; while
  its row is visible it renders selected.
- **Nothing is pre-chosen.** The selection starts empty and
  the block shows its choose-guidance line (section 9).
  Flutter had no starting reaction to mirror — its starting
  state was the dummy map — and pre-selecting the
  alphabetically first formula would present a full quantity
  table the reader never asked for as if it were theirs.

**Material and product names — locked.** For each retained
material and product row the display name is, in order:
`fitting_types.lookup_by_id(id)` and its `name`, with the
same trim / empty / purely-numeric guard; failing that,
`resolver.name(id)` (`src/names/resolver.rs:166-174`), whose
unresolved word fallback is `Unknown Item`. The skills-only
`Sde` is never consulted for materials (it cannot resolve
them and its fallback words, `Unknown Skill`, would be the
wrong label). Scripts prove every shipped activity-11
material and product type resolves in `FittingTypes`, so
`Unknown Item` appears only if a future regenerated file
outruns the item catalogue — and then it appears honestly,
as a word, next to a quantity that is still real data. The
reverse name lookup (`FittingTypes::lookup`, normalized
exact) is not used anywhere in this slice: the choice starts
from proven IDs and resolves them forward, so no typed name
ever needs exact-match, ambiguity, or fuzzy rules. No shell
name-resolution scheduling is added for the fallback: bundled
coverage makes it unnecessary for the shipped data, and an
unresolved future ID renders `Unknown Item` rather than
triggering network work for a static catalogue.

**Both catalogues are load-bearing.** The block needs
`IndustryRef` for quantities and `FittingTypes` for names;
if either failed to load, the block renders its fixed
unavailable sentence and nothing else (section 9). Rendering
quantities against `Unknown Item` rows because the item
catalogue failed would reproduce Flutter's `Item #<id>` in
words.

## 5. Runs and facility bonus inputs (locked — every input is the reader's)

Exactly three reader inputs beyond the reaction choice: a
search text (section 4), a runs count, and a facility
material bonus percent. Nothing is taken from a loaded job,
an owned blueprint or formula, the character's skills or
assets, or any structure.

| Input | Meaning | Starting text | Valid range (section 7) |
|---|---|---|---|
| Reaction search | Filters the section 4 name list | empty | any text; empty matches all |
| Runs | Number of reaction runs | `1` | whole number, at least 1 |
| Facility material bonus percent | Structure material bonus as a percent: 4.8 means 4.8% | `0.0` | finite, at least 0, below 100 |

**Why text fields, decided from the bodies.** Flutter's
panel carries a runs slider (1 to 100, default 1, panel
lines 79-86) and a facility-bonus dropdown with seven
hard-coded choices (panel lines 115-144): `No Bonus (0%)`,
`Athanor (2%)`, `Athanor T1 Rig (2.4%)`, `Athanor T2 Rig
(2.8%)`, `Tatara (4%)`, `Tatara T1 Rig (4.8%)`, `Tatara T2 Rig
(5.6%)`, starting at `0.0`. Two Rust precedents in this same
view have already settled how such controls port: the
Invention Calculator replaced Flutter's sliders and its
five-entry decryptor dropdown with text fields and listed
the named choices in its disclosure
(`industry-calculators-design.md` section 3), and the Trade
Calculator replaced Flutter's percent sliders with text
percents (`parse_fee_percent`, `src/trade_calculator.rs:79-89`).
This slice follows both, for the reasons they recorded: the
tree has no slider or dropdown widget precedent to be
consistent with; a closed picker would present the seven
structure names as if Mimir had verified them against EVE
Live (their only source is panel code at `ed698d3`, live
accuracy unverified — section 9 of the earlier design said
the same); and a typed percent labelled
`(entered by you)` with the seven retired-app choices quoted
in the disclosure tells the reader exactly what to type
without claiming Mimir read their facility. Like the
decryptor multiplier before it, the text field widens what
can be typed beyond the seven values (any percent below 100
computes by the same formula); that widening is recorded
here, changes no formula, and the field's label and the
disclosure keep the source honest.

- **Runs starts at Flutter's `1`** and widens past the
  slider's 100: the slider bound is a widget choice, and no
  inspected body states an EVE rule capping reaction runs at
  100 (the same reasoning that widened the invention base
  probability past its slider). Huge run counts are not
  capped by fiat; section 7's checked arithmetic is what
  rejects a count too large to calculate with.
- **The bonus starts at Flutter's `0.0`** (No Bonus), so the
  first quantities a reader sees after choosing a reaction
  are the bundled per-run quantities at face value.
- **Percents at the text boundary, fractions inside** (the
  trade-calculator convention): the reader types `4.8`, the
  pure domain functions take Flutter's fraction `0.048`, and
  the one division by 100 happens in the combined result
  function (section 8). Section 10 pins that `"4.8"` parses
  and divides to the same `f64` as Flutter's `0.048` literal.

Draft state (Builder A, section 13): four new fields on
`AppState` beside the invention drafts
(`src/app/state.rs:786-790`):

```rust
pub industry_reaction_search: String,
pub industry_reaction_selected_type_id: Option<i64>,
pub industry_reaction_runs: String,
pub industry_reaction_facility_bonus_percent: String,
```

`AppState::new` seeds the two numeric drafts explicitly from
the pure module's constants (section 8) next to the invention
seeding (`state.rs:889-893`) — `DEFAULT_RUNS.to_string()`
giving `"1"`, `format!("{:.1}", DEFAULT_FACILITY_BONUS_PERCENT)`
giving `"0.0"` — while the search starts empty and the
selection `None` under the derived `Default`. The selection
field's comment states it is an internal catalogue key that
is never rendered or logged. All four are session-only:
nothing is stored, and character switching, blueprint
filtering, industry refreshes, and demo seeding never touch
them (section 10 pins the same survival the invention drafts
have).

## 6. Reaction math (locked — replicate Flutter)

Flutter `reaction_calculator.dart` at `ed698d3` (read in full
during design). The doc comments (lines 3-6) state the input
meanings: base inputs are "Map of typeId to base quantity
required per run", runs the "Number of runs for the job", and
the bonus the "Material efficiency bonus of the structure
(e.g., 0.02 for a 2% reduction)". The bodies, verbatim:

```dart
// EVE's math for ME reduction applies to the total base amount.
// round(runs * baseQty * (1.0 - facilityMaterialBonus))
final totalBaseQty = runs * baseQty;
final actualQty = (totalBaseQty * (1.0 - facilityMaterialBonus)).round();

// You can never use less than 1 if it requires it, ...
inputs[typeId] = actualQty > 0 ? actualQty : 1;
```

```dart
outputs[entry.key] = entry.value * runs;
```

Locked port, per material row, with operand order kept
exactly as written so floating-point association matches the
oracles:

```text
total_base_qty = runs * base_qty                     (checked, section 7)
actual_qty     = round(total_base_qty * (1.0 - facility_material_bonus))
input_qty      = actual_qty if actual_qty > 0, else 1
output_qty     = base_output_qty * runs              (checked, section 7)
```

Decisions locked:

- **The bonus applies to the multiplied total, then rounds
  once** — never per run. Flutter's oracle proves the two
  readings differ and picks the total: ten runs of 100 at
  4.8% gives `1000 * 0.952 = 952`, where per-run rounding
  would give `round(95.2) * 10 = 950`
  (`reaction_calculator_test.dart:32-33`).
- **Outputs get no bonus and no rounding:** exact integer
  multiplication by runs, as written. No facility bonus,
  skill, or time figure touches them.
- **Rounding ties follow Flutter.** Dart `double.round()`
  rounds half away from zero; Rust `f64::round` is also
  round-half-away-from-zero. A design-time Rust probe
  confirmed `2.5 → 3`, `4.5 → 5`, and the formula-level
  cases `5 * (1.0 - 0.5) = 2.5 → 3` and
  `25 * (1.0 - 0.02) = 24.5 → 25` (both products are exact
  in binary, so the tie rule — not a representation
  accident — is what decides). Section 10 pins both;
  `round_ties_even`, `ceil`, and `floor` are never used.
  This settles the question section 9 of the earlier design
  left open, from behaviour rather than assumption.
- **The minimum-of-1 guard applies once, to the total** —
  the code over its own comment. The comment muses about a
  "minimum of 1 per run", but the guard as written runs on
  the already-multiplied, already-rounded total: one unit
  per run at a 99% bonus over 10 runs is
  `round(10 * 0.01) = 0`, guarded to 1 — not 10. Section 10
  pins that literal so no builder "fixes" it to match the
  comment. With valid ranges the guard fires only when the
  rounded total is 0 (a small base quantity against a large
  typed bonus); section 7 makes the negative and `NaN`
  corners that could reach it in Dart unreachable.
- **No other figure exists.** No job duration (the
  `activities` time rows are unloaded, section 2), no
  per-run breakdown line, no totals row summed across
  different materials (summing unlike items would be a
  meaningless number), no cost, price, or ISK figure —
  Flutter computed none of them.
- Whether the bonus list and this rounding still match EVE
  Live is unverified — the only source is the retired code —
  and the disclosure says the numbers can differ from EVE
  (section 9).

## 7. Validation, invalid-input, and overflow behaviour (locked)

Flutter's slider and dropdown could only produce in-range
values and its domain validated nothing (zero or negative
runs, a bonus above 1, and overflowing products all produce
*some* map in Dart). The text fields need the rules the
widgets used to enforce, following the invention and trade
parser shapes. Two pure parsers (section 8):

- `parse_runs(text)`: trim whitespace, parse as `i64`,
  accept only a value of at least 1 — the
  `parse_skill_level` shape (`invention_calculator.rs:59-66`),
  with no comma stripping (on a whole-number count a comma
  is a typo, not a thousands separator). This rejects empty
  text, `0`, negatives, fractional text such as `1.5`, and
  `1,000`. No upper bound at parse time (section 5); the
  calculation's checked arithmetic below is what rejects a
  typed count too large to multiply. Text beyond `i64`
  range fails the parse itself.
- `parse_facility_bonus_percent(text)`: trim whitespace,
  remove one trailing `%` if present, strip commas, parse
  as `f64`, accept only a finite value of at least 0 and
  below 100 — the `parse_fee_percent` shape
  (`trade_calculator.rs:79-89`) with one boundary change:
  exactly 100 is rejected here rather than downstream,
  because a 100% bonus would zero every input into the
  minimum-of-1 guard and render `1` of everything at any run
  count, a plausible-looking table from a meaningless input.
  This rejects empty text, negatives, `100`, `100%`, and —
  because Rust's `f64` parser accepts them — `inf`, `-inf`,
  and `NaN` in any case. Scientific notation that parses to
  an in-range finite value is accepted as typed; no extra
  notation rules are invented.

`calculate_inputs` and `calculate_outputs` then return
`None` — the whole calculation, never a partial list — when
any of these holds. The full list, no others:

- runs is below 1;
- the facility bonus fraction is non-finite, below 0, or at
  or above 1 (inputs only; outputs take no bonus);
- the base slice is empty, any base type number is at or
  below 0, any base quantity is at or below 0, or the same
  type number appears twice in one slice (Dart's `Map`
  could not hold a duplicate key, and the loader's
  primary-key rule, section 3, means real rows never do —
  a duplicate is ambiguous data, and silently keeping both
  rows would print the same material twice unsummed);
- any `runs * base_qty` product overflows `i64`
  (`checked_mul` — never wrapping, saturating, or `as`-cast
  arithmetic). A wrapped negative total in Dart rounds and
  guards to a plausible `1`; here it is no result;
- any input total exceeds 9,007,199,254,740,992 (`2^53`),
  the largest integer up to which every integer is exactly
  representable in `f64`. Above it, converting the total to
  `f64` silently moves it to a neighbouring representable
  value (a design-time probe: `9,007,199,254,740,993 as f64`
  is `9,007,199,254,740,992`), so the rounded result would
  be wrong by whole units while looking exact — internally
  a private constant `MAX_EXACT_FLOAT_QUANTITY: i64 =
  9_007_199_254_740_992`. This guard applies to inputs only:
  outputs are pure integer multiplication and stay exact to
  the `checked_mul` limit;
- the rounded input value is non-finite, negative, or above
  that same exact bound — checked **before** the `as i64`
  cast, so the cast only ever sees a value already proven in
  range (unreachable given the guards above, and locked
  anyway so no refactor can drop one guard and keep the
  cast).

Consequences, locked:

- No negative, zero-quantity, wrapped, or float-shifted
  total can be produced: every rendered input is at least 1
  (the guard), every rendered output is at least its per-run
  quantity, and presence is decided by the `Option`, never
  by comparing a figure to zero. A cleared field shows
  guidance and no quantities (section 9) — there is no state
  in which the block renders a table of zeroes.
- Dart corners deliberately not replicated, recorded as
  replacements in the invention slice's style: runs of 0
  (Dart: every input guards to 1, every output 0), negative
  runs (Dart: negative outputs), a bonus at or above 1
  (Dart: zero or negative quantities guarded to 1), a
  negative bonus (Dart: inputs grow), and `NaN` or infinite
  bonuses (Dart: `round()` on them throws or propagates).
  Each is `None` here. Valid-range behaviour is bit-for-bit
  Flutter's.

## 8. Pure API (locked)

New top-level module `src/reaction_calculator.rs`, registered
in `src/lib.rs` in alphabetical position
(`pub mod reaction_calculator;` between `portraits` and
`skills`). It mirrors `src/invention_calculator.rs`: no egui,
no `AppState`, no network, no database, no `include_str!`,
and it logs nothing — it runs at render cadence. Its module
doc cites this design, the Flutter oracle at `ed698d3`, the
loader in `src/names/industry_ref.rs` as the source of its
base quantity slices, the user-entered runs and bonus, and
the section 11 production-chain deferral. It takes plain
`(type_id, quantity)` pairs rather than loader row types, so
the Flutter oracle maps are its direct test fixtures and the
math stays testable without either bundled file; the view
builds the pairs from loader rows in file order each frame
(at most six inputs and — in the shipped data — one output,
section 2).

```rust
pub const DEFAULT_RUNS: i64 = 1;
pub const DEFAULT_FACILITY_BONUS_PERCENT: f64 = 0.0;

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ReactionResult {
    pub inputs: Vec<(i64, i64)>,
    pub outputs: Vec<(i64, i64)>,
}

pub fn parse_runs(text: &str) -> Option<i64>;
pub fn parse_facility_bonus_percent(text: &str) -> Option<f64>;

pub fn calculate_inputs(
    base_inputs: &[(i64, i64)],
    runs: i64,
    facility_material_bonus: f64,
) -> Option<Vec<(i64, i64)>>;

pub fn calculate_outputs(
    base_outputs: &[(i64, i64)],
    runs: i64,
) -> Option<Vec<(i64, i64)>>;

pub fn reaction_calculator_result(
    base_inputs: &[(i64, i64)],
    base_outputs: &[(i64, i64)],
    runs_text: &str,
    facility_bonus_percent_text: &str,
) -> Option<ReactionResult>;
```

Decisions locked:

- The two constants are Flutter's starting values (panel
  `_runs = 1`, `_facilityMaterialBonus = 0.0`), each
  documented as the `AppState` draft seed, never a derived
  figure. The seven named facility choices are **not**
  constants here — as with the decryptor list, they live
  only in the disclosure wording (section 9), so no code
  path can treat them as verified structure data.
- Results are `Vec` in input-slice order, never a map: Dart
  returned insertion-ordered maps, the loader hands over
  file order, and the view prints that order. A `HashMap`
  return would reshuffle the rendered rows between frames.
- `calculate_inputs` takes the bonus as a **fraction**
  (`0.048`), exactly Flutter's parameter, with no default —
  Rust has no counterpart to Dart's
  `facilityMaterialBonus = 0.0` default argument, so nothing
  silently substitutes 0 for a cleared field; Flutter's
  default survives only as the seeded starting text.
- `reaction_calculator_result` is the renderer's one call:
  it parses both texts, divides the percent by `100.0`
  exactly once, and returns `Some` only when both
  calculations succeed — never inputs without outputs or
  the reverse. All functions are total: no panics, no
  indexing, no unwrap on hostile text, hostile floats, or
  hostile slices.
- Builder A also updates the now-stale deferral note in
  `src/invention_calculator.rs:21-23` in the same commit
  that adds this module, replacing it with: "The reaction
  calculator lives in `crate::reaction_calculator` over the
  bundled industry data in `crate::names::industry_ref`;
  there is still no production-chain calculator (see
  `docs/industry-reaction-design.md` section 11)." — the
  sentence stays true per-module without claiming the Rust
  tree still loads no industry tables.

## 9. UI placement and verbatim wording (locked)

`src/ui/industry.rs` `show()` gains two catalogue parameters
and passes them to a new block (Builder B also makes the one
call-site change in `src/app/shell.rs`, section 13):

```rust
pub fn show(
    ui: &mut egui::Ui,
    state: &mut AppState,
    resolver: &NameResolver,
    industry_data: Option<&IndustryRef>,
    fitting_types: Option<&FittingTypes>,
)
```

`show_reaction_calculator(ui, state, resolver, industry_data,
fitting_types)` is called immediately after
`show_invention_calculator(ui, state)` (`industry.rs:549`)
and **before** the no-character early return — the invention
placement and its reasoning, unchanged: both calculators are
character-independent, so the reaction block is available
with no character, while jobs load or fail, offline, and in
demo mode, and never only inside the `Ready` arm. It sets no
request flag, fetches nothing, and touches neither industry
section. The shell passes `self.industry_data.as_deref()`
and `self.fitting_types.as_deref()` (today's Fittings call at
`shell.rs:3799-3800` is the shape).

Render flow, locked in order:

1. The heading.
2. If `industry_data` is `None`, the no-industry-data
   sentence and nothing else; else if `fitting_types` is
   `None`, the no-item-data sentence and nothing else. Drafts
   render nothing in either state and are left untouched in
   `AppState`.
3. Otherwise: the reaction label and a plain
   `ui.text_edit_singleline` bound to
   `industry_reaction_search` (not `widgets::search_box` —
   the block never requests focus and never touches the `/`
   blueprint-search shortcut; `response.has_focus()` still
   feeds `state.text_input_focused`, as every invention field
   does), then the section 4 choice rows (with their
   showing / no-match lines), then the runs label and field,
   then the bonus label and field, then every line from the
   pure helper below. No Calculate button (egui recomputes
   every frame), no slider, dropdown, colour coding, or
   graphics.

Line-building is factored exactly as the invention block's
is, so every rendered string is assertable without an egui
frame:

```rust
fn reaction_calculator_lines(
    state: &AppState,
    industry_data: Option<&IndustryRef>,
    fitting_types: Option<&FittingTypes>,
    resolver: &NameResolver,
) -> Vec<String>;
```

It returns, by state, in this exact precedence (first match
wins):

1. `industry_data` is `None` → the no-industry-data sentence
   alone (no disclosure — its instructions would be
   impossible to follow).
2. `fitting_types` is `None` → the no-item-data sentence
   alone.
3. No selection, or the stored selection is not a reaction
   blueprint in this catalogue, or it has no chooser name
   under section 4's rule (the stored 45732 case a test
   fabricates) → the choose-guidance line, then the
   disclosure.
4. The runs or bonus draft fails its section 7 parser → the
   input-guidance line, then the disclosure.
5. Both drafts parse but `reaction_calculator_result`
   returns `None` (with locked loaders and parsers the only
   such case is a magnitude section 7 rejects) → the
   no-result-guidance line, then the disclosure.
6. Success → the result lines below, then the disclosure.

The helper makes the guidance choice by calling the pure
parsers again only where the precedence needs them; it never
duplicates the arithmetic. Quantity formatting is the plain
decimal integer (`3000`, never `3,000`) — Flutter's
`${e.value}` and the Industry view's own plain counts; no
grouping formatter is added. Result lines are in bundled-data
file order (section 8), not name order, and every name in
them comes from section 4's resolution order.

All wording is held in named `pub const`s in
`src/ui/industry.rs` beside the `INVENTION_CALCULATOR_*`
constants (`industry.rs:27-39`):
`REACTION_CALCULATOR_HEADING`,
`REACTION_CALCULATOR_INPUT_LABELS: [&str; 3]`,
`REACTION_CHOICE_RENDER_MAX: usize = 100`,
`REACTION_CALCULATOR_NO_INDUSTRY_DATA`,
`REACTION_CALCULATOR_NO_ITEM_DATA`,
`REACTION_CALCULATOR_CHOOSE_GUIDANCE`,
`REACTION_CALCULATOR_NO_MATCH`,
`REACTION_CALCULATOR_INPUT_GUIDANCE`,
`REACTION_CALCULATOR_NO_RESULT_GUIDANCE`, and
`REACTION_CALCULATOR_DISCLOSURE`.

Heading and input labels, verbatim and in order:

```text
Reaction Calculator
Reaction (chosen by you)
Runs (entered by you)
Facility Material Bonus Percent (entered by you)
```

The nouns are Flutter's (`Runs:`, `Facility Bonus:`, panel
lines 72 and 106) extended with the honest source exactly as
the invention labels extend theirs; `Reaction` names the
choice Flutter never had. `Facility Material Bonus` spells
out the domain parameter's name (`facilityMaterialBonus`)
and the label says `Percent` because the field is a percent
at the text boundary (section 5). The choice-list line and
the unavailable, guidance, and no-match sentences, verbatim
(the showing line is a template):

```text
Reaction calculator unavailable: Mimir's bundled industry data failed to load.
Reaction calculator unavailable: Mimir's bundled item data failed to load.
Choose a reaction above to see its materials.
No reactions match the search.
Showing {shown} of {total} reactions.
Enter runs of at least 1 and a facility material bonus percent of at least 0 and below 100, to see the result.
No result: the entered values are too large to calculate with.
```

The unavailable sentences adapt the Fittings fixed sentence
(`Fitting resources unavailable: Mimir's bundled item data
failed to load.`, `src/ui/fittings.rs`) per catalogue; the
no-result sentence reuses the invention block's words
exactly, because it is the same reader situation. None of
these lines contains a draft value, a computed figure, or a
numeric ID; the only numbers in them are the fixed bounds in
their own wording and the showing counts.

Result lines, verbatim templates in order:

```text
Reaction: {chosen reaction name}
Input Materials
{material name}: {input quantity}
Output Products
{product name}: {output quantity}
```

`Input Materials` and `Output Products` are Flutter's card
headings (`INPUT MATERIALS`, `OUTPUT PRODUCTS`) in the view's
sentence case, as `Invention Chance` adapted `INVENTION
CHANCE`; the `Reaction:` echo line follows the view's
`Label: value` shape and exists because the chosen row can
be scrolled or filtered out of the choice list while its
table is on screen. There is no `With entered …` second
line: Flutter's reaction panel has no such sentence to
adapt, and the disclosure carries the entered-values clause.

**Disclosure**, rendered verbatim under the result or
guidance lines in every state except the two unavailable
states:

> Estimate for the reaction you chose, using the per-run
> materials and products in Mimir's bundled industry data
> and only the runs and facility material bonus percent you
> entered. The starting values (1 run, 0.0% facility
> material bonus) are starting values to replace with your
> own: Mimir does not read the facility bonus from any
> structure you use, and it does not check that you own the
> reaction formula, have the materials, or can run the
> reaction. The facility choices in the retired app were No
> Bonus 0%, Athanor 2%, Athanor T1 Rig 2.4%, Athanor T2 Rig
> 2.8%, Tatara 4%, Tatara T1 Rig 4.8%, and Tatara T2 Rig
> 5.6%; type the percent for the facility you mean. The
> facility bonus applies to the total input amount for all
> runs, each input is rounded to a whole number with a
> minimum of 1, and outputs are the per-run amount times
> runs with no bonus. A reaction formula with no name in
> Mimir's bundled item data cannot be chosen. There is no
> production-chain calculator. These numbers can differ from
> EVE.

Every clause carries one locked decision: chosen reaction
plus entered runs and bonus only, with Flutter's starting
values named and every un-read source named (sections 4, 5);
Flutter's seven facility choices quoted as typed references,
never an owned-structure picker (section 5); total-then-round
with the minimum of 1 and bonus-free outputs (section 6);
the unnamed-formula exclusion (section 4); the still-deferred
production chain (section 11); and the unverified-against-Live
caveat.

**One existing sentence changes.** The shipped invention
disclosure (`INVENTION_CALCULATOR_DISCLOSURE`,
`industry.rs:39`) says "There are no reaction or
production-chain calculators." Builder B replaces that one
sentence with "There is no production-chain calculator." and
updates its byte-exact test; no other invention wording,
constant, or expectation changes.

Logging: the renderer emits one
`tracing::debug!("[INDUSTRY] reaction calculator input
changed")` when any of the three text fields reports
`changed()`, and one `tracing::debug!("[INDUSTRY] reaction
calculator reaction chosen")` when a choice row is clicked.
No draft contents, search text, chosen name, type number, or
computed quantity is ever logged, and the pure helpers
(`reaction_choice_rows`, `reaction_calculator_lines`, and
the section 4 name resolution, which uses the log-free
`lookup_by_id`) log nothing — noting only that the fallback
`resolver.name` retains its own existing one-line miss debug,
which is that type's shipped behaviour, not new logging in
this slice.

## 10. Demo pins and test plan (locked literals)

**Flutter test oracles exist and govern.** All four cases in
`reaction_calculator_test.dart` at `ed698d3` were verified
during design. Every pure-module literal below is one of
those oracles, a real-data pin scripted from the shipped
`industry.json`, or derived during design from section 6's
formula with its arithmetic shown — each cross-checked by
the design-time Rust probe. Results are integers and
`assert_eq!` throughout; there is no float tolerance anywhere
in this slice's oracles (rounding to a whole number is the
formula's own last step).

**Demo mode:** no demo data changes. Both bundled catalogues
load identically in demo and live modes (the Fittings and
Exploration startup paths already do), and no demo job or
blueprint (demo blueprint types 681, 682, 683; no demo
reaction formula exists) feeds the choice, the selection, or
either draft. Demo pins: a demo-seeded state leaves all four
reaction fields exactly as constructed (selection empty),
renders the choose-guidance lines, and — once a test chooses
Carbon Fiber Reaction Formula in that state at the starting
texts — renders the same block as live mode (below).

**Builder A — loader tests** (`src/names/industry_ref.rs`):

Bundled-catalogue pins against the shipped file:

```text
material_count() = 384, product_count() = 112
reaction_blueprint_count() = 112
reaction_blueprint_type_ids().first() = 45732, .last() = 57506
is_reaction_blueprint(57490) = true; (681) = (34) = (0) = (-1) = false
```

Real-data spot pins (file order; the names in parentheses are
the `fitting_types.json` resolutions the renderer will show,
asserted in Builder B's tests):

```text
57490 (Carbon Fiber Reaction Formula)
  materials: (4246 Hydrogen Fuel Block, 5),
             (16633 Hydrocarbons, 100),
             (16635 Evaporite Deposits, 100)
  products:  (57453 Carbon Fiber, 200)
46209 (Fulleride Reaction Formula)
  materials: (4051 Nitrogen Fuel Block, 5),
             (16659 Carbon Polymers, 100),
             (16662 Platinum Technite, 100)
  products:  (16679 Fullerides, 3000)
46157 (Methanofullerene Reaction Formula)
  materials: (4246, 5), (30372 Fullerite-C70, 100),
             (30373 Fullerite-C72, 100), (37 Isogen, 300)
  products:  (30306 Methanofullerene, 160)
45732 (no name in fitting_types.json)
  materials: (16657 Rolled Tungsten Alloy, 100),
             (16661 Sulfuric Acid, 100)
  products:  (16672 Tungsten Carbide, 20)
```

Invariants over every retained row of the shipped file, in
the `bundled_catalogue_invariants` style: `activity_id` is
11 on every row; every type number and quantity is above 0;
no duplicate `(type_id, material_type_id)` or
`(type_id, product_type_id)` keys; materials per blueprint
distribution exactly `{2: 1, 3: 69, 4: 36, 5: 5, 6: 1}`;
products per blueprint exactly 1 for all 112; 111 distinct
material types and 111 distinct product types; sorted type
list strictly ascending.

`from_json` fixture cases (following
`invalid_rows_are_skipped_and_empty_or_malformed_fails`,
`fitting_types.rs:512-531`):

- Scope: valid activity-1 and activity-8 rows are dropped,
  valid activity-11 rows kept; a fixture whose unloaded
  sections contain non-list garbage (`"activities":
  "junk"`, `"skills": 7`) still loads from its valid
  `materials` / `products` — pinning that unloaded sections
  are never deserialized.
- Skips: activity-11 rows with type 0 or negative, material
  or product type 0, and quantity 0 or negative are skipped
  while valid sibling rows load (assert retained counts).
- Duplicates: a repeated primary key keeps the first row's
  quantity and skips the later one; the same blueprint type
  with a *different* material keeps both rows.
- Failure: `"not json"`, `{}`, both sections empty, only
  out-of-scope rows, materials with no matching product
  (empty intersection), and a row missing `quantity` each
  return `Err`.
- Accessors: `reaction_materials(681)` is `None` even when
  the fixture carries activity-1 rows for 681; a
  materials-only orphan type yields `None` from both
  accessors while its rows still count in `materials`.

**Builder A — pure calculator tests**
(`src/reaction_calculator.rs`):

Flutter oracle 1 (test lines 6-13; bonus passed explicitly
as 0.0 per section 8):

```text
calculate_inputs([(16641, 100), (16642, 100)], 1, 0.0)
    = [(16641, 100), (16642, 100)]
```

Flutter oracle 2 (lines 18-27):

```text
// 100 * (1 - 0.048) = 95.2 -> round to 95
calculate_inputs([(16641, 100), (16642, 100)], 1, 0.048)
    = [(16641, 95), (16642, 95)]
```

Flutter oracle 3 (lines 32-42, total-then-round):

```text
// 10 runs = 1000 base; 1000 * (1 - 0.048) = 952
calculate_inputs([(16641, 100), (16642, 100)], 10, 0.048)
    = [(16641, 952), (16642, 952)]
```

Flutter oracle 4 (lines 44-50, outputs):

```text
calculate_outputs([(16654, 10)], 5) = [(16654, 50)]
```

Design-derived cases, each with its arithmetic in a comment:
small-quantity rounding `5 * (1 - 0.048) = 4.76 → 5` and
`50 * (1 - 0.048) = 47.6 → 48` (the Carbon Fiber fuel-block
row below); ties `5 * (1 - 0.5) = 2.5 → 3` and
`25 * (1 - 0.02) = 24.5 → 25` (section 6); minimum guard
`1 * (1 - 0.99) = 0.01 → 0 → 1` and the guard-on-total case
`10 * 1 * (1 - 0.99) = 0.1 → 0 → 1` (never 10); outputs at
runs 1 are the base quantities unchanged, and outputs ignore
any bonus by construction (no parameter).

Validation and overflow matrix, one assertion per section 7
rule: runs `0` and `-1`; bonus `-0.01`, `1.0`, `1.1`, `NaN`,
`INFINITY`, `NEG_INFINITY`; empty slice; type number `0` and
`-1`; quantity `0` and `-5`; duplicated type number in one
slice — each `None` from the relevant function. Overflow:
`calculate_inputs([(16641, i64::MAX)], 2, 0.0)` and
`calculate_outputs([(16654, i64::MAX)], 2)` are `None`;
precision boundary `calculate_inputs([(37,
9_007_199_254_740_992)], 1, 0.0)` is
`Some([(37, 9_007_199_254_740_992)])` while quantity
`9_007_199_254_740_993` is `None`; the same `2^53 + 1`
quantity through `calculate_outputs` at runs 1 **is** `Some`
(integer-exact — pinning that the float guard does not leak
into outputs).

Parser cases: `parse_runs`: `"1"` → 1, `" 10 "` → 10,
`"101"` → 101 (past Flutter's slider, section 5),
`"9223372036854775807"` → `i64::MAX` (parses; the
calculation rejects it); `""`, `"0"`, `"-1"`, `"1.5"`,
`"1,000"`, `"abc"` → `None`. `parse_facility_bonus_percent`:
`"0"` → 0.0, `"0.0"` → 0.0, `"4.8"` → 4.8, `"4.8%"` → 4.8,
`" 5.6 "` → 5.6, `"99.9"` → 99.9 (Flutter's dropdown values
among them); `""`, `"-0.1"`, `"100"`, `"100%"`, `"NaN"`,
`"inf"` → `None`; and the divide pin
`parse_facility_bonus_percent("4.8") / 100.0 == 0.048`
exactly. `reaction_calculator_result` cases: the four oracles
replayed through texts (`"1"` / `"0.0"`, `"1"` / `"4.8"`,
`"10"` / `"4.8"` with outputs `[(16654, 10)]` giving 100);
any one invalid text gives `None`; runs `"9223372036854775807"`
with base quantity 100 gives `None` though both texts parse.
Defaults: `DEFAULT_RUNS = 1`,
`DEFAULT_FACILITY_BONUS_PERCENT = 0.0`.

**Builder A — state tests** (`src/app/state.rs`):
`AppState::new(false)` has `industry_reaction_search = ""`,
`industry_reaction_selected_type_id = None`,
`industry_reaction_runs = "1"`, and
`industry_reaction_facility_bonus_percent = "0.0"` (formatted
from the constants); `set_active_character` across a switch
leaves all four unchanged (set to non-default values first,
the invention-survival test shape).

**Builder B — choice, renderer, and shell tests**
(`src/ui/industry.rs`, `src/app/shell.rs`):

- Verbatim heading, the three input labels, all six fixed
  sentences, `REACTION_CHOICE_RENDER_MAX = 100`, and the
  disclosure constant (byte-exact against section 9), plus
  the amended invention disclosure's replaced sentence.
- Choice rows over both bundled catalogues: 111 rows; the
  first four names exactly section 4's list; no row carries
  internal type 45732; every name ends
  `Reaction Formula`; search `"carbon fiber"` yields exactly
  `Carbon Fiber Reaction Formula` and
  `Reinforced Carbon Fiber Reaction Formula` in that order;
  search `"FULLERIDE"` yields exactly
  `Fulleride Reaction Formula` (case-insensitive substring,
  not prefix); a nonsense search yields no rows. A small
  dual-fixture case (both catalogues from `from_json`) pins
  that a blueprint with no item row and another whose item
  name is purely numeric are both excluded while a named
  third remains.
- Starting-text result (selection 57490 set by the test,
  drafts `1` / `0.0`): exactly

  ```text
  Reaction: Carbon Fiber Reaction Formula
  Input Materials
  Hydrogen Fuel Block: 5
  Hydrocarbons: 100
  Evaporite Deposits: 100
  Output Products
  Carbon Fiber: 200
  ```

  followed by the disclosure.
- Bonus and runs result (same selection, drafts `10` /
  `4.8`): inputs `Hydrogen Fuel Block: 48` (`50 * 0.952 =
  47.6 → 48`), `Hydrocarbons: 952`, `Evaporite Deposits:
  952` (the oracle-3 arithmetic on real rows), output
  `Carbon Fiber: 2000`, then the disclosure; at drafts `1` /
  `4.8` the fuel block stays `5` (`4.76 → 5`) while the two
  hundreds become `95` (oracle 2 on real rows).
- Second real-data result (selection 46157, drafts `5` /
  `2.8`): inputs `Hydrogen Fuel Block: 24` (`25 * 0.972 =
  24.3 → 24`), `Fullerite-C70: 486`, `Fullerite-C72: 486`,
  `Isogen: 1458` (`1500 * 0.972`), output
  `Methanofullerene: 800`, then the disclosure.
- Unknown fallback: a dual fixture whose product type is
  absent from the item fixture, with an empty
  `NameResolver`, renders that row as `Unknown Item: {qty}`
  by whole-vector equality, and no rendered line in any
  success or guidance case equals or contains a bare type
  number used by the fixtures (asserted on the joined
  lines against the fixture ID spellings, quantities in the
  fixtures chosen to not collide with them).
- Guidance precedence, whole-vector equality per case:
  `industry_data = None` (with and without fitting types) →
  `[no-industry-data]`; fitting types `None` alone →
  `[no-item-data]`; no selection → `[choose, disclosure]`;
  fabricated selection 45732 → `[choose, disclosure]` (the
  unnamed blueprint is never shown as chosen); fabricated
  selection 681 → `[choose, disclosure]`; selection 57490
  with runs `""`, `"0"`, or `"1.5"`, or bonus `""`, `"100"`,
  or `"-1"` (one case per field) → `[input guidance,
  disclosure]`; selection 57490 with runs
  `"9223372036854775807"` and bonus `"0.0"` →
  `[no-result guidance, disclosure]`. No quantity line
  appears in any guidance state.
- Shell startup (mirroring
  `fitting_types_startup_load_is_catalogue_or_none`):
  `industry_load(IndustryRef::load_bundled())` yields a
  catalogue with `reaction_blueprint_count() = 112`, and
  `industry_load(IndustryRef::from_json("{not json"))` is
  `None`.
- Demo independence (the invention test's shape):
  `seed_demo_state` leaves the four reaction fields exactly
  as constructed, the seeded state renders
  `[choose, disclosure]` over the bundled catalogues, and
  choosing 57490 in that state renders the starting-text
  block above unchanged.
- Regression: every existing industry test passes with only
  the one invention-disclosure sentence updated — this slice
  inserts one block after the invention block, widens
  `show()`'s signature, and rewords no other existing line.

**Gates (every commit):** `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`,
`cargo build`.

## 11. Deferrals and exclusions (locked — ship-nothing lines are explicit)

- **Production chain: deferred again, ships nothing.** This
  slice's loader makes the deferral a choice, not an
  accident, and it does not fit here for four named reasons,
  each a design problem of its own rather than missing rows:
  (a) the chain is a recursive traversal over activity-1
  manufacturing materials (26,806 rows) as well as activity
  11, and this loader deliberately retains only activity 11
  (section 2) — widening it needs its own scope, count, and
  invariant decisions; (b) walking from a product to the
  blueprint that makes it needs a reverse
  product-type-to-blueprint index with a multiple-blueprints
  rule — Flutter's builder never built one (it probes
  `getIndustryMaterials(materialTypeId, …)`, treating a
  material type as if it were its own blueprint type,
  `production_chain_builder.dart:48-91`), so there is no
  grounded behaviour to port, only a traversal that happens
  to stop early on real data; (c) batch arithmetic is
  undecided in every inspected body — Flutter multiplies
  `mat.quantity * quantity` straight down the tree, ignoring
  per-run product batch sizes (a reaction yielding 200 per
  run does not need its inputs times 200), bonuses, and
  rounding at each level — and this slice invents none of
  it; (d) Flutter recurses with no cycle or depth guard and
  its visualizer renders an invented dummy tree, while the
  Rust tree has no locked tree display for the result.
  Flutter's single chain oracle (a mocked empty-materials
  Tritanium node) is recorded in the earlier design and
  remains the next slice's starting point, with the loader
  widening, reverse index, batch rule, and cycle guard named
  here as its entry conditions. The disclosures say the
  production-chain calculator does not exist (section 9).
- **No manufacturing calculator.** No activity-1 rows are
  retained, no owned blueprint's material or time efficiency
  is applied to any material list, and the reaction rounding
  rule is never generalized to manufacturing (unchanged from
  the earlier design's section 9).
- **No invention auto-fill.** The `probabilities` and
  `skills` sections stay unloaded (section 2); the shipped
  Invention Calculator keeps its five reader-entered inputs
  and gains no blueprint probability, no character skill
  level, and no picker from this slice's loader.
- **No requirement or ownership claims.** No skill
  requirement line, no check that the reader owns the
  formula or the materials, no facility detection, no job
  duration or finish time, and nothing reads the loaded jobs,
  blueprints, assets, or skills for this block. The choice
  list is the bundled catalogue's reactions whether or not
  the reader holds any of them.
- **No editing of base quantities.** Per-run quantities come
  only from the loaded data (Flutter's panel never let the
  reader edit its lists either); runs and the bonus percent
  are the only numeric inputs. No multi-reaction shopping
  list, no aggregation of the same material across reactions,
  no comparison view.
- **No derived figures.** No cost, price, profit, or ISK
  figure; no "materials saved by the bonus" line; no per-run
  echo of the base quantities beside the totals.
- **No persistence and no writes.** The four reaction fields
  live only for the session; no job can be started,
  cancelled, or delivered; the view sets no new request flag
  and needs no new EVE SSO (single sign-on) scope, character,
  or network for the block. No shell name-resolution
  scheduling is added (section 4).
- **No asset or generator change.** `assets/sde/industry.json`
  is loaded as shipped; `generate_industry_sde.py` is
  untouched; no narrower reaction extract is generated
  (section 2's size trade is accepted, not solved here).
- No change to `IndustryData`, `industry_job_rows`,
  `blueprint_rows`, the blueprint filter, the step-up panel,
  ESI (the EVE Swagger Interface) endpoints or models, demo
  JSON, or the invention calculator beyond the one disclosure
  sentence and the one module-doc note (sections 8, 9).

## 12. Integrator list

- **README** (Industry bullet, line 20): replace "There are
  no reaction or production-chain calculators, and no
  production, cost, or profit calculator." with "The view
  also carries a reaction calculator: you choose a reaction
  formula by name from Mimir's bundled industry data (one
  bundled formula has no name in the item data and cannot be
  chosen), type the runs and a facility material bonus
  percent (starting values 1 and 0.0%, never read from a
  structure you use, a formula or materials you own, or your
  character, and never checked against them), and it shows
  each input material and the output product by name, the
  bonus applied to the total input amount and rounded with a
  minimum of 1, outputs at the per-run amount times runs; no
  chosen reaction, an empty or invalid field, or a run count
  too large to calculate with shows guidance instead of any
  quantity. There is no production-chain calculator, and no
  production, cost, or profit calculator." No other README
  bullet changes: the roadmap list carries no
  industry-calculator bullet to amend (verified during the
  earlier design and unchanged at this base).
- **Engineering journal**
  (`docs/engineering-journal/LEARNINGS.md`, integrator's
  commit): one entry with Evidence / Mechanism /
  generalizable rule — a loader should retain only what its
  one consumer can use honestly: of 85,080 bundled industry
  rows, the reaction calculator needs 496, and membership in
  its catalogue is the intersection of the two sections it
  loads, so the three sections it does not load cannot fail,
  skew, or bless its data (sections 2, 3); the one blueprint
  the item catalogue cannot name (45732) is present in the
  loaded data yet unchoosable, because a name-based choice
  over an unnamed entry reproduces the raw-ID panel in
  words (section 4); and integer formulas that pass through
  `f64` need an exact-representation bound (`2^53`), not only
  `checked_mul`, before their totals can be called exact
  (section 7) — alongside the Flutter minimum-of-1 guard
  whose code applies once to the total while its comment
  says "per run" (section 6).
- Nothing else: no HANDOFF change beyond what the parent
  directs, no demo-data, ESI, scope, storage, generator, or
  SDE-asset change. If build discovery contradicts any
  literal in section 10, the slice stops rather than growing
  scope.

## 13. Ownership and commit split

- **Design (this commit):** `docs/industry-reaction-design.md`
  only. Commit:
  `docs(industry): design industry data loader and reaction calculator`.
- **Builder A — data, pure calculation, and draft state:**
  new `src/names/industry_ref.rs` and its `src/names/mod.rs`
  declaration; new `src/reaction_calculator.rs`, its
  `src/lib.rs` registration, and the section 8 module-doc
  replacement in `src/invention_calculator.rs`; the four
  `AppState` reaction fields and their seeding in
  `src/app/state.rs`; and the section 10 Builder-A tests.
  Commits:
  `feat(industry): add bundled industry reaction data loader`,
  `feat(industry): add pure reaction calculator`,
  `feat(industry): add reaction calculator draft state`.
- **Builder B — startup wiring and render:** first the
  `industry_load` helper, the `MimirApp.industry_data`
  field, and its `MimirApp::new` load in `src/app/shell.rs`
  (the startup commit — the `View::Industry` call is
  untouched there); then the block, choice helper, line
  helper, constants, the one invention disclosure sentence,
  and the section 10 Builder-B tests in `src/ui/industry.rs`
  together with the widened `View::Industry` call in
  `src/app/shell.rs` that its new `show()` signature needs
  (the render commit). Commits:
  `feat(industry): load bundled industry data at startup`,
  `feat(industry): show reaction calculator in industry view`.
- **Integrator:** README and journal per section 12, full
  gates, and a demo-mode check that the block shows the
  choose-guidance with the demo bundle loaded (reaction
  fields untouched by seeding) and the Carbon Fiber starting
  block (section 10) once that formula is chosen. Commit:
  `docs(industry): document reaction calculator`.

Builder B touches no `src/names/`, `src/reaction_calculator.rs`,
`src/lib.rs`, or `src/app/state.rs` file and codes against
sections 3, 5, and 8's locked APIs, field names, and
section 9's wording; Builder A touches no `src/ui/` or
`src/app/shell.rs` file. The shell startup commit lands
before the render commit, so the catalogue field exists
(unused by any view) for exactly one commit rather than the
signature and its argument landing on opposite sides of a
builder boundary. Small atomic commits,
`type(scope): description`, no attribution lines. Nobody
pushes or merges; the parent does that.
