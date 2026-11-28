# Planetary Industry factory schematics — design

Status: locked for the `feat/rust-pi-schematics` slice.
Base: `develop` at `87333c1` (1107 tests stated at slice start;
this design commit re-runs the section 14 gates).
Slice branch: `feat/rust-pi-schematics`.

Discovery: two read-only reports — one scripting
`planetSchematics.jsonl` inside the pinned SDE archive, the
retired Flutter PI code at `ed698d3`, and the shipped demo
pins; one on the Rust planets detail, the `IndustryRef`
loader threading, name resolution, and the generator
precedents. During design the decisive bodies were re-read
or re-scripted directly: every count in section 2 was
recomputed from
`scripts/sde/eve-online-static-data-3503375-jsonl.zip`
(member `planetSchematics.jsonl`, plus `types.jsonl` lookups
for the pin-type and demo-name facts); the Rust bodies
`src/names/industry_ref.rs`, `src/names/exploration_ref.rs`
lines 257–420, `src/names/resolver.rs` lines 1–60 and
140–210, `src/ui/planets.rs` in full, `src/esi/models.rs`
lines 620–688, `src/app/shell.rs` lines 684–705, 862–985,
1015–1204, 3825–3845, and 4465–4490,
`scripts/sde/generate_exploration_sde.py` (header, lines
182–220, and 470–650), `src/demo/data.rs` (bundle parsing,
planets validation, demo-name seeding), and
`assets/demo/planets.json` and `assets/demo/names.json` in
full. No EVE behaviour here is recalled from outside those
bodies.

**Grounded verdict up front:**

- **Factory pins gain a resolved production line.** A new
  bundled extract, `assets/sde/planet_schematics.json`,
  generated from the one `planetSchematics.jsonl` member of
  the already-pinned SDE build 3503375 archive, carries all
  68 schematics (English name, cycle time, allowed pin
  types, inputs, and the single output). In the selected
  colony's detail, a new "Factories" section between
  "Extractors" and "Stored items" shows, for every pin
  carrying a positive `schematic_id`, the schematic's name,
  its per-cycle output and inputs with quantities, and its
  cycle time (sections 3–9).
- **Two name sources, never conflated.** The schematic's
  own name is the extract's bundled English string, shown
  verbatim. Every input/output/pin *type* name goes through
  `NameResolver::name` — the exact call stored items use —
  so an unresolved type reads `Unknown Item`, never a raw
  ID and never the schematic's name borrowed for its output
  (section 2 proves the two differ). Schematic IDs
  themselves stay unscheduled (section 8).
- **Absent and unlisted are stated, never guessed.** A pin
  whose schematic is not in the extract shows a fixed
  not-in-bundled-data line and no name; a pin whose type is
  not in its schematic's pin list still shows the full
  schematic plus one fixed line saying so (section 7). A
  failed extract load degrades the whole section to one
  fixed unavailable sentence, following `IndustryRef`
  (section 5).
- **Nothing is fetched, written, or modelled.**
  Planetary Industry management ships nothing, and no
  output-rate arithmetic (per-hour yields, colony
  throughput, factory completion times) ships: no inspected
  body grounds it (section 12). Per-cycle quantities and
  the cycle time are displayed as data, exactly as the
  Extractors section already displays its wire values.

## 1. Goal and value ranking

Today a factory pin is visible only as an opaque entry in
"Pin types" (`Demo Factory × 1` in demo terms):
`PlanetPin.schematic_id` is parsed and then, per its doc
comment at `src/esi/models.rs:639-640`, "carried but never
rendered, resolved, or computed with". The reader can see
what a colony extracts and what it stores, but not what its
factories are set up to make. This slice resolves the
already-carried `schematic_id` against bundled static data
and renders the recipe. It supersedes exactly one sentence
of `docs/pi-port-design.md` (the "never rendered/resolved"
rule for `schematic_id`); that design's read-only,
no-calculator, no-new-endpoint rules all stand.

Value ranking (locked, in order):

1. **Never a fabricated recipe.** Every rendered name,
   quantity, and cycle time traces to the pinned archive
   member or to a name the resolver actually holds. Absence
   is a stated sentence, never a guess, a nearest match, or
   a raw number (sections 5, 7).
2. **The extract is reproducible or it does not ship.** One
   pinned source member, fail-loud oracles, deterministic
   bytes, a hard byte budget; any drift stops generation
   with no output written (section 3).
3. **Follow the two shipped precedents exactly.** The
   generator copies `generate_exploration_sde.py`; the
   loader, startup storage, and view threading copy
   `IndustryRef` (`src/names/industry_ref.rs`,
   `industry_load()` at `src/app/shell.rs:690-705`). Where
   the two precedents differ, section 4 names the choice.
4. **Reuse the honest name path.** Type names resolve and
   schedule exactly like stored-item names do today; the
   only new bundled strings are the 68 schematic names,
   which have no ESI name path (sections 7, 8).
5. **Read-only stays read-only.** No fetch, no write, no
   scope, no state flag; the section is a pure derivation
   over pins already in memory plus the bundled extract.

## 2. Evidence: the data, the gap, and the demo fixtures

All figures below were scripted during design from the
pinned archive already in the tree,
`scripts/sde/eve-online-static-data-3503375-jsonl.zip`
(102 members; the only planet members are
`planetSchematics.jsonl`, `planetResources.jsonl`, and
`mapPlanets.jsonl`).

### 2.1 `planetSchematics.jsonl` (the one source member)

- 68 lines, 68 parsed objects, 0 malformed. Member size
  31,548 bytes; `sha256` of the member bytes is
  `938dcc38471e1fb6f2bcc22d66da214ecf66fd32392256376d161627152fcf4f`
  (Builder A re-verifies this before trusting the cache).
- Every row has exactly the keys
  `(_key, cycleTime, name, pins, types)`. There is no
  `schematicID` field: the schematic ID is `_key`. First
  row: `_key 65`, `name.en "Superconductors"`,
  `cycleTime 3600`,
  `pins [2470,2472,2474,2480,2484,2485,2491,2494]`,
  `types` = inputs `2389×40`, `3645×40`, output `9838×5`.
- Schematic IDs: 68 unique, minimum 65, maximum 135,
  missing in range exactly `{93, 101, 120}`. File order is
  ascending by `_key`; every `pins` list is ascending;
  every `types` list is ascending by entry `_key`.
- `name.en` is present and non-empty in 68/68 rows; every
  name map holds the same 8 languages
  `(de,en,es,fr,ja,ko,ru,zh)`. English names are unique
  (68/68), 5–30 characters, none purely numeric.
- `cycleTime` distribution: `3600: 53`, `1800: 15`, no
  other values, all positive integers.
- `types`: 203 entries total, every entry exactly
  `(_key, isInput, quantity)` with positive integers.
  Per-schematic `(inputs, outputs)` counts are
  `(1,1): 15`, `(2,1): 39`, `(3,1): 14` — **every schematic
  has exactly one output** and 1–3 inputs (135 inputs +
  68 outputs = 203). No schematic repeats a type entry,
  and no type is both an input and the output of the same
  schematic. The output entry is *not* reliably last (its
  index is 0 in 13 rows, 1 in 26, 2 in 26, 3 in 3), so
  `isInput` — never position — decides direction.
- Input quantities are exactly `{6, 10, 40, 3000}`;
  output quantities exactly `{1, 3, 5, 20}`. 83 distinct
  type IDs appear across all entries (minimum 44,
  maximum 28974).
- `pins`: flat integer lists, sizes `{8: 60, 2: 8}`, no
  duplicates within a row. The 18-ID universe is exactly
  `[2469,2470,2471,2472,2473,2474,2475,2480,2481,2482,2483,2484,2485,2490,2491,2492,2493,2494]`,
  in three sets tied 1:1 to `cycleTime`: the 8 basic
  facilities `(2469,2471,2473,2481,2483,2490,2492,2493)` on
  the 15 `1800`-second schematics (IDs 121–135), the 8
  advanced facilities
  `(2470,2472,2474,2480,2484,2485,2491,2494)` on 45
  schematics (65–111), and `(2475,2482)` on 8 schematics
  (112–119). In `types.jsonl` these 18 IDs are the
  planet-flavoured Basic/Advanced Industry Facilities and
  High-Tech Production Plants (e.g. 2480 "Temperate
  Advanced Industry Facility", 2481 "Temperate Basic
  Industry Facility", 2475 "Barren High-Tech Production
  Plant", 2482 "Temperate High-Tech Production Plant") —
  i.e. one schematic lists the *same facility kind across
  planet flavours*, which is what section 7's membership
  rule must respect.
- Schematic name vs output type name (`types.jsonl`
  `name.en` for the output `_key`): identical for 65/68,
  different for exactly 3 — 89 "Ukomi Superconductor" vs
  type 17136 "Ukomi Superconductors", 94 "High-Tech
  Transmitter" vs 17898 "High-Tech Transmitters", 108
  "Transcranial Microcontroller" vs 12836 "Transcranial
  Microcontrollers". The schematic name therefore cannot
  be derived from the output type's resolved name; it must
  be bundled (section 3) and the two strings rendered from
  their own sources (section 7).

`planetResources.jsonl` is explicitly out: 25,798 rows in
a `40,013,180…40,328,345` key namespace with zero overlap
against the 83 schematic type IDs (discovery, scripted) —
live per-planet power/workforce/reagent state, not
schematic data. No generator or extract for schematics
exists today: `assets/sde/` holds exactly the six shipped
extracts, and no `scripts/sde/` script mentions planets.

### 2.2 The Rust gap today

- `PlanetPin` (`src/esi/models.rs:644-665`) has no
  `factory_details` field — exhaustive search finds no such
  identifier anywhere — so factory lines can only derive
  from `schematic_id: Option<i64>` (`:660`) plus the
  bundled table. Whether live ESI also sends a
  `factory_details` object is unverifiable from the repo;
  serde ignores unknown fields, so this slice neither
  needs nor parses one (section 12).
- Factory pins currently render only inside
  `pin_type_counts()` (`src/ui/planets.rs:70-101`).
  `extractor_product_rows()` (`:112-140`) requires
  extractor details, `colony_summary()` (`:215-306`) counts
  extractors only, and `storage_content_rows()`
  (`:149-184`) aggregates contents. Detail order in
  `show_detail_section()` (`:442-528`) is Colony summary,
  Pin types, Extractors, Stored items.
- Retired Flutter at `ed698d3` holds nothing to port: it
  parsed `schematicId` from ESI, stored it in one Drift
  column, dropped it from its domain `Pin` model, and
  never resolved or displayed it; its SDE had no
  schematics table (discovery, `git grep` at `ed698d3`).
  The semantics in sections 6–7 are therefore defined
  here from the wire field and the SDE member, not ported.

### 2.3 Demo fixtures as shipped

`assets/demo/planets.json` holds 8 pins. Four carry a
non-null `schematic_id` — `15462` (pins 700000011,
700000021, 700000111) and `17361` (pin 700000012) — one
carries explicit `null`, three omit the key. Two
namespace facts, scripted during design:

- Neither demo schematic ID is an SDE schematic:
  `{15462, 17361} ∩ {65…135} = ∅`. (15462 is the
  `types.jsonl` type "Strong Frentix Booster"; 17361 is
  not a type in the pinned archive at all.) The demo
  values are placeholders from before any extract existed.
- Every schematic-bearing demo pin is pin type `20001`
  ("Demo Extractor") and *also* carries
  `extractor_details` — the fixture conflates extractor and
  factory shapes on one pin. No demo pin type
  (`20001/20002/20003`) appears in any schematic's pin
  list, and no schematic input/output type (the 83 IDs)
  or pin type (the 18 IDs) has a demo name in
  `assets/demo/names.json` (41 entries today).

Consequences, locked in sections 7 and 11: row membership
is defined by `schematic_id` alone (a pin with both
extractor details and a schematic appears in both
sections — no inspected body makes them exclusive, and
suppressing either would invent a rule); the four shipped
schematic pins become the demo's honest
not-in-the-extract material; and two *additional* demo
pins with real schematic IDs are required for the demo to
show a resolved line at all.

## 3. The generator (locked)

New file `scripts/sde/generate_planet_schematics_sde.py`,
copying `generate_exploration_sde.py`'s contract and
mechanisms (the precedent; `generate_industry_sde.py` —
Fuzzwork "latest", no manifest, no validation — is
explicitly not). Locked:

- **Source.** The pinned CCP archive only:
  `SDE_BUILD = 3503375`, the same `ARCHIVE_URL`,
  `CACHE_NAME`, `cache_path()`, `ensure_archive()`,
  `sha256_of_member()`, `iter_jsonl()`, and `fail()`
  (stderr + `sys.exit(1)`) copied in shape from
  `generate_exploration_sde.py:37-43,182-219`. The script
  reads exactly one member, `planetSchematics.jsonl`. It
  never reads `types.jsonl` (type names are the resolver's
  job, section 8), never reads Fuzzwork, and never
  hand-carries rows. Network exists only inside this
  script at generation time, and only on a cache miss; the
  shipped app does zero network work (`include_str!`,
  section 4). The header docstring states this contract,
  including: if the archive cannot be fetched or any
  validation fails, the script exits nonzero and writes
  no output.
- **Output.** `assets/sde/planet_schematics.json`, written
  only after every validation below passes, as
  `json.dump(document, fh, indent=2, sort_keys=True,
  ensure_ascii=False)` plus one trailing newline
  (`generate_exploration_sde.py:625-628`). Exact emitted
  shape — no other keys, English names only:

  ```json
  {
    "manifest": {
      "sdeBuild": 3503375,
      "datasetSchema": 1,
      "sourceFiles": [
        {"name": "planetSchematics.jsonl", "sha256": "<member sha256>"}
      ],
      "rowCounts": {"schematics": 68, "typeEntries": 203, "inputs": 135, "outputs": 68},
      "generatedBy": "scripts/sde/generate_planet_schematics_sde.py"
    },
    "schematics": [
      {
        "schematicId": 65,
        "name": "Superconductors",
        "cycleTime": 3600,
        "pins": [2470, 2472, 2474, 2480, 2484, 2485, 2491, 2494],
        "inputs": [
          {"typeId": 2389, "quantity": 40},
          {"typeId": 3645, "quantity": 40}
        ],
        "output": {"typeId": 9838, "quantity": 5}
      }
    ]
  }
  ```

  `name` is `name.en` verbatim (the other seven languages
  are dropped; the app renders English throughout).
  `output` is a single object, not a list, because
  section 2.1 proves exactly one output per schematic —
  the shape itself then enforces the invariant.
  Ordering is part of the shape: `schematics` ascending by
  `schematicId`, `pins` ascending, `inputs` ascending by
  `typeId`. (Key order inside objects is `sort_keys`, as
  in the precedent; the sketch above shows reading order,
  not byte order.)
- **Fail-loud validation** (a `problems`-collecting block
  in the shape of `generate_exploration_sde.py:513-623`,
  run before any write; every count is an exact oracle, so
  SDE drift stops the slice instead of silently shipping):
  member present; 68 rows exactly, every non-blank line
  parsing (any malformed line fails); every row's key set
  exactly `(_key,cycleTime,name,pins,types)`; schematic
  IDs unique with set exactly `{65…135} \ {93,101,120}`;
  `name.en` present, non-empty after stripping, and unique
  across rows (68 unique); `cycleTime` a positive integer
  with distribution exactly `{1800: 15, 3600: 53}`; every
  type entry exactly `(_key,isInput,quantity)` with
  positive integers, 203 entries total, 83 distinct type
  IDs; per-schematic `(inputs,outputs)` distribution
  exactly `{(1,1):15, (2,1):39, (3,1):14}` (135 inputs,
  68 outputs); input quantity set exactly
  `{6,10,40,3000}`, output set exactly `{1,3,5,20}`; no
  repeated type within a schematic and inputs disjoint
  from the output; every `pins` list non-empty, strictly
  ascending positive integers, sizes exactly `{8:60,
  2:8}`, universe exactly the 18 IDs of section 2.1, and
  the three pin-set counts exactly 45/15/8; manifest
  `rowCounts` equal to the computed counts. Booleans are
  not integers: `isInput` must be a JSON bool and numeric
  fields must not be (Python `bool` subclasses `int`; the
  check excludes it explicitly).
- **Spot oracles** (full-row equality after the
  inputs/output split, chosen to pin each trap in
  section 2.1):
  65 Superconductors, 3600, inputs `[(2389,40),(3645,40)]`,
  output `(9838,5)`;
  75 Enriched Uranium, 3600, inputs
  `[(2399,40),(2400,40)]`, output `(44,5)` (output first
  in the source list — proves `isInput` drives the split);
  89 Ukomi Superconductor, 3600, inputs
  `[(3691,10),(9838,10)]`, output `(17136,3)` (singular
  schematic name, section 2.1);
  95 Gel-Matrix Biopaste, 3600, inputs
  `[(2317,10),(2329,10),(9838,10)]`, output `(2348,3)`
  (three inputs, output mid-list);
  112 Organic Mortar Applicators, 3600, pins `[2475,2482]`,
  inputs `[(2344,6),(2393,40),(9848,6)]`, output
  `(2870,1)` (mixed 6/40 quantities, two-pin set);
  121 Water, 1800, inputs `[(2268,3000)]`, output
  `(3645,20)` (raw-resource shape);
  135 Industrial Fibers, 1800, inputs `[(2305,3000)]`,
  output `(2397,20)` (last row).
- **Byte budget and determinism.** The emitted shape
  measures ~32 KB (31,761 bytes scripted during design for
  schematics plus a stub manifest). Locked budget: the
  generated file must be **at most 40,000 bytes**; the
  generator fails rather than writes past it. Builder A
  runs the generator twice and proves byte-identity
  (`sha256` equal across runs, second run leaving
  `git diff` clean), and records the actual byte count and
  output `sha256` in its commit body.
- **Stdout summary**, mirroring
  `generate_exploration_sde.py:629-641`: `wrote <path>`,
  one `manifest rowCounts …` line, `sha256(output)=…`, and
  one spot line naming schematics 65 and 121 by ID and
  English name.

## 4. The loader (locked API)

New module `src/names/planet_schematics.rs`, registered as
`pub mod planet_schematics;` in `src/names/mod.rs` between
`industry_ref` and `resolver` (the file's alphabetical
order). It follows `IndustryRef` for envelope, startup
degradation, and empty-is-an-error, and `ExplorationRef`
for whole-file manifest validation — the split is locked
here because the two precedents differ: `IndustryRef`
skips individual bad rows with a `skipped` counter
(`industry_ref.rs:79-105`) because its file interleaves
activities it must filter, while this file is
single-purpose and machine-generated under section 3, so
**any invalid row fails the whole load**. A partially
loaded schematic table would misreport present schematics
as absent (section 7), which is exactly the dishonesty
this slice forbids; there is no `skipped` counter.

```rust
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct SchematicTypeQty {
    #[serde(rename = "typeId")] pub type_id: i64,
    pub quantity: i64,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct PlanetSchematic {
    #[serde(rename = "schematicId")] pub schematic_id: i64,
    pub name: String,
    #[serde(rename = "cycleTime")] pub cycle_time: i64,
    pub pins: Vec<i64>,
    pub inputs: Vec<SchematicTypeQty>,
    pub output: SchematicTypeQty,
}

impl PlanetSchematic {
    pub fn allows_pin_type(&self, pin_type_id: i64) -> bool; // binary search
}

pub struct PlanetSchematicsRef {
    pub schematics: Vec<PlanetSchematic>, // ascending by schematic_id
    // private: nothing else needed; lookup binary-searches
}

impl PlanetSchematicsRef {
    pub fn load_bundled() -> AppResult<Self>;
    pub fn from_json(json: &str) -> AppResult<Self>;
    pub fn schematic_count(&self) -> usize;
    pub fn type_entry_count(&self) -> usize; // inputs + outputs
    pub fn schematic(&self, schematic_id: i64) -> Option<&PlanetSchematic>;
}
```

Locked behaviour:

- `load_bundled()` mirrors `industry_ref.rs:60-63`: a
  `tracing::debug!("[PI] loading bundled planet
  schematics")` line, then
  `Self::from_json(include_str!("../../assets/sde/planet_schematics.json"))`.
  The tag is `[PI]` throughout this slice (the planets
  feature tag; no new tag is introduced).
- `from_json()` deserializes a private file envelope
  `{manifest, schematics}`. The manifest is **required**
  (`ExplorationRef` at `exploration_ref.rs:265-267`):
  absence is `Err(AppError::Message("[PI] planet
  schematics manifest is missing"))`. `datasetSchema`
  must equal `1` and every `rowCounts` value
  (`schematics`, `typeEntries`, `inputs`, `outputs`) must
  equal the parsed counts, each mismatch its own `[PI]`
  `AppError::Message` in the shape of
  `exploration_ref.rs:327-346`. `sdeBuild` is carried in
  the manifest struct but not gated: a future pinned
  build regenerates data and updates tests, not loader
  code.
- **Empty is a hard error**, mirroring
  `industry_ref.rs:205-209`: zero schematics returns
  `Err(AppError::Message("[PI] planet schematics catalogue
  is empty"))`. There is no empty-default fallback
  anywhere in this slice.
- **Pinned invariants**, each failing the whole load with
  an `[PI]` `AppError::Message` (messages name the rule,
  never echo row contents beyond the schematic ID where
  the precedent does): schematic IDs strictly ascending
  in file order (which also proves uniqueness);
  `schematic_id > 0`; `name` non-empty after trimming;
  `cycle_time > 0`; `pins` non-empty and strictly
  ascending with every entry `> 0`; `inputs` length in
  `1..=3` (the range section 2.1 proves; a future SDE
  widening it must revisit this design, not pass
  silently); every input/output `type_id > 0` and
  `quantity > 0`; input type IDs strictly ascending (the
  emitted order), and the output type ID distinct from
  every input. Exactly-one-output needs no runtime check:
  the emitted single-object shape makes serde enforce it.
  Exact distributions (68 rows, cycle-time and quantity
  sets, pin universe) are *test* pins (section 10), not
  loader logic, mirroring how `IndustryRef`'s loader stays
  structural while `bundled_catalogue_pins` pins 27190 /
  4917 / 4788 / 112.
- On success, one info line mirroring
  `industry_ref.rs:196-203`:
  `tracing::info!("[PI] planet schematics loaded schematics={} type_entries={}", …)`.
- `schematic(id)` binary-searches the ascending vec;
  `id <= 0` returns `None` without searching.
  `allows_pin_type` binary-searches `pins`;
  `pin_type_id <= 0` returns `false`. No method resolves
  names, schedules anything, or touches the network.

## 5. Startup wiring and view threading (locked)

Five edits, each beside its `IndustryRef` precedent:

1. **Load helper** beside `industry_load()`
   (`src/app/shell.rs:690-705`), with the same doc-comment
   contract (success stores the validated catalogue;
   failure stores `None` so the view shows its fixed
   unavailable sentence instead of treating an empty
   catalogue as valid):

   ```rust
   fn planet_schematics_load(
       result: crate::error::AppResult<PlanetSchematicsRef>,
   ) -> Option<Arc<PlanetSchematicsRef>> {
       match result {
           Ok(catalogue) => {
               tracing::info!(
                   "[PI] bundled planet schematics loaded schematics={}",
                   catalogue.schematic_count()
               );
               Some(Arc::new(catalogue))
           }
           Err(e) => {
               tracing::warn!("[PI] bundled planet schematics failed to load: {}", e);
               None
           }
       }
   }
   ```

2. **Field** `pub planet_schematics:
   Option<Arc<PlanetSchematicsRef>>` on `MimirApp` beside
   `industry_data` (`shell.rs:128`), constructed beside
   `shell.rs:875`
   (`let planet_schematics =
   planet_schematics_load(PlanetSchematicsRef::load_bundled());`)
   and moved in beside `shell.rs:971`. Construction sits
   before the demo branch, so demo and live modes load the
   identical catalogue exactly once, zero-network, like
   `state.exploration` at `shell.rs:881`.
3. **View signature**: `ui::planets::show(ui, state,
   resolver, planet_schematics:
   Option<&PlanetSchematicsRef>)` (was
   `src/ui/planets.rs:532`), threaded unchanged into
   `show_detail_section(ui, state, bundle, resolver,
   planet_schematics, panel_shown)` (`:420-426`).
   `show_colonies_section` does not take it.
4. **Shell call** at `shell.rs:3837` becomes
   `ui::planets::show(ui, &mut self.state, &self.resolver,
   self.planet_schematics.as_deref())`, mirroring the
   Industry call at `:3830-3836`.
5. **Startup test** beside
   `industry_startup_load_is_catalogue_or_none`
   (`shell.rs:4470-4478`):
   `planet_schematics_startup_load_is_catalogue_or_none`
   asserting the bundled load yields `schematic_count()
   == 68` and
   `planet_schematics_load(PlanetSchematicsRef::from_json("{not json"))`
   is `None`.

Failure consequence, locked: `None` reaches the view,
which renders section 7's fixed unavailable sentence for
any colony that has factory pins. The rest of the Planets
view (colonies, summary, pin types, extractors, stored
items) is unaffected — the extract gates only the new
section, exactly as `industry_data: None` gates only the
reaction/production calculators.

## 6. Factory rows: the pure function (locked API)

In `src/ui/planets.rs`, beside its three sibling row
builders, with the same `pub` visibility and
`#[derive(Debug, Clone, PartialEq)]` style:

```rust
pub struct FactoryTypeRow {
    pub type_id: i64,
    pub type_name: String,
    pub quantity: i64,
}

pub enum FactoryResolution {
    Resolved {
        schematic_name: String,
        cycle_time: i64,
        output: FactoryTypeRow,
        inputs: Vec<FactoryTypeRow>,
        pin_listed: bool,
    },
    NotInExtract,
}

pub struct FactoryPinRow {
    pub pin_id: i64,
    pub pin_type_name: String,
    pub resolution: FactoryResolution,
}

pub fn factory_pin_rows(
    pins: &[PlanetPin],
    schematics: &PlanetSchematicsRef,
    resolver: &NameResolver,
) -> Vec<FactoryPinRow>
```

Semantics, locked step by step:

- **Membership is by `schematic_id` alone.** A pin yields
  a row iff `pin.schematic_id` is `Some(id)` with
  `id > 0`. `None` (no schematic installed — the normal
  state of extractors, storage, and command pins) yields
  no row and no "no schematic" noise. `Some(id <= 0)`
  yields no row and increments a `skipped` counter,
  mirroring `pin_type_counts`' treatment of non-positive
  type IDs (`planets.rs:74-77`) and `missing()`'s
  `id <= 0` skip (`resolver.rs:191`). Extractor details,
  contents, expiry, and pin type play no part in
  membership (section 2.3): a pin with both extractor
  details and a schematic appears in both sections.
- **Resolution.** `schematics.schematic(id)`:
  `Some(s)` → `Resolved` with `schematic_name =
  s.name.clone()` (bundled English, verbatim — never the
  resolver), `cycle_time = s.cycle_time`, output and
  inputs mapped 1:1 from `s.output` / `s.inputs` in
  extract order (type-ID ascending, section 3; the order
  is stable across frames because it never depends on
  names that fill in later), each `type_name =
  resolver.name(type_id)`, and `pin_listed =
  s.allows_pin_type(pin.type_id)`. `None` →
  `NotInExtract`, carrying no name, quantity, or cycle
  time of any kind.
- **`pin_type_name`** is `resolver.name(pin.type_id)` on
  every row, the same call as `planets.rs:83`.
- **Sort.** Resolved rows first, by schematic name
  (lowercase, then exact — the sibling comparator shape at
  `planets.rs:130-137` — then pin type name, then
  `pin_id`); `NotInExtract` rows after all resolved rows
  (they have no name to sort by, and interleaving them
  under a placeholder would imply one), among themselves
  by pin type name (lowercase, then exact), then
  `pin_id`. `pin_id` remains an invisible tie-break only,
  as its model doc states. Output is independent of input
  pin order.
- **Logging.** One debug line per call, counts only, no
  pin, schematic, or type ID (the `planets.rs` sibling
  rule, `pi-colony-summary-design.md` section 8):
  `tracing::debug!("[PI] factory pin rows={} resolved={} not_in_extract={} unlisted_pin={} skipped={}", …)`
  where `unlisted_pin` counts resolved rows with
  `pin_listed == false`.

The module doc at `planets.rs:1-6` already states the rule
this function obeys: every rendered string is a resolved
EVE name, a whitelist word, a fetched date, or a row
count — the one addition is the bundled schematic name, a
static-data string in the same standing as the SDE skill
names the app already shows, never a numeric ID.

## 7. Rendering: placement and verbatim wording (locked)

**Placement.** A new block inside `show_detail_section`'s
`Ok(detail)` arm, **after the Extractors block and before
"Stored items"** (between today's `planets.rs:511` and
`:512`): extraction, then production, then storage — the
order materials move. The colony summary block above it
(`planets.rs:452-470`, locked by
`docs/pi-colony-summary-design.md`) is **unchanged**: it
keeps its Flutter-locked extractor semantics, gains no
factory count, and its `NoExtractors` note ("No extractor
pins were reported, so nothing is extracting.") stays
true verbatim on a factory-only colony. A summary-level
factory count is deferred (section 12): a bare count
there would need extract-aware wording (resolved vs
absent vs extract-unavailable) that the four-line summary
has no room to state honestly.

**Fixed strings**, as `pub const`s in `planets.rs` beside
the render caps (mirroring
`REACTION_CALCULATOR_NO_INDUSTRY_DATA` at
`src/ui/industry.rs:54-55`), verbatim:

```rust
pub const FACTORY_RENDER_MAX: usize = 100;
pub const FACTORY_SCHEMATICS_UNAVAILABLE: &str =
    "Factory schematics unavailable: Mimir's bundled planet schematic data failed to load.";
pub const FACTORY_SCHEMATIC_NOT_IN_EXTRACT: &str =
    "Installed schematic is not in Mimir's bundled planet schematics.";
pub const FACTORY_PIN_NOT_LISTED: &str =
    "This pin's type is not listed for this schematic in Mimir's bundled data.";
```

**Section logic**, in order (the renderer counts
schematic-bearing pins itself — `Some(id > 0)` — because
that count is wire truth and must not depend on the
extract having loaded):

1. Heading `"Factories"`, always rendered (like
   "Extractors" and "Stored items").
2. No schematic-bearing pins →
   `"No factory pins were reported for this colony."`
   (mirroring `:490`), regardless of extract state.
3. Schematic-bearing pins exist but
   `planet_schematics` is `None` → one label,
   `FACTORY_SCHEMATICS_UNAVAILABLE`, and no rows. Never
   an empty section presented as "no factories".
4. Otherwise `factory_pin_rows(...)`, with the sibling
   cap pattern (`"Showing {} of {} factories."` when over
   `FACTORY_RENDER_MAX`, then `.take(FACTORY_RENDER_MAX)`).

**Per resolved row** (formats reuse the sibling blocks'
exact shapes — `\u{2014}` separator from `:500-503`,
`{qty} × {name}` `\u{00d7}` from `:525`, cycle wording
from `:508`):

```
{schematic_name} — {pin_type_name}
Output per cycle: {output.quantity} × {output.type_name}
Input per cycle: {quantity} × {type_name}      (one line per input, 1–3)
Cycle time: {cycle_time} seconds
```

plus, only when `pin_listed` is false, one final line:
`FACTORY_PIN_NOT_LISTED`. One line per input (never a
comma join) so repeated `Unknown Item` names stay
attributable to their own quantity. Quantities and cycle
time render as the plain integers they are (row counts
and fetched values, per the module doc); no per-hour or
per-day figure is derived (section 12).

**Per `NotInExtract` row**, exactly two lines:

```
{pin_type_name}
Installed schematic is not in Mimir's bundled planet schematics.
```

Never a guessed name, never the raw `schematic_id`,
never the output type name borrowed as a stand-in
(section 2.1's three mismatches forbid the shortcut in
both directions).

**Extract-membership honesty (`pin_listed`).** Decided
from section 2.1's data: a schematic's `pins` list names
the facility kinds that run it across planet flavours, so
on consistent live data a factory pin's type is expected
in its schematic's list — but the bundled list is the
*only* source Mimir holds, and no inspected body states
what EVE enforces. The rule is therefore *show and say*:
the full recipe renders (the wire's `schematic_id` is the
claim; the extract resolves it), and the fixed
`FACTORY_PIN_NOT_LISTED` line states the one checkable
fact — the bundled data does not list this pin type for
this schematic. The row is never hidden, demoted in sort
order, or worded as "cannot run" / "invalid": SDE drift,
a stale extract, or a placeholder fixture (all four
shipped demo schematic pins are unlisted by construction)
must not read as an EVE verdict.

**Doc updates in the same builder commit.** The
`PlanetPin` doc (`src/esi/models.rs:639-640`) stops saying
"never rendered, resolved, or computed with" and instead
states that `schematic_id` is resolved against the bundled
planet schematics in the colony detail and is itself never
rendered or name-scheduled; the `no calculator` clause
stands. The renderer adds no logging of its own (the
sibling blocks log nothing; all `[PI]` lines for this
slice are in sections 4–6 and 9).

## 8. Name scheduling (locked)

Type names reach the screen only if the shell schedules
them — the trap discovery named: an extract carrying IDs
alone would render `Unknown Item` forever. The planetary
block of `schedule_name_resolution()`
(`src/app/shell.rs:1153-1182`) gains, inside its existing
per-pin loop over the selected detail's pins (`:1171-1179`),
beside the pin-type, extractor-product, and content pushes:

```rust
if let (Some(schematic_id), Some(schematics)) =
    (pin.schematic_id, self.planet_schematics.as_deref())
{
    if let Some(schematic) = schematics.schematic(schematic_id) {
        ids.push(schematic.output.type_id);
        ids.extend(schematic.inputs.iter().map(|input| input.type_id));
    }
}
```

Locked consequences:

- **The same honest path stored items use**: item-path
  `ids` → `resolver.missing()` dedup (`resolver.rs:187-199`,
  which itself skips `id <= 0` and known IDs) → batched
  fill. No structure guard (these are item types, not
  locations, like content type IDs at `:1176-1178`), no
  new endpoint, no bundled type-name table.
- **Schematic IDs are still never scheduled.** The block
  comment at `shell.rs:1153-1158` is updated in the same
  commit to keep that sentence true while naming the new
  pushes (schematic input/output *type* IDs, resolved
  through the bundled extract first). Only a schematic
  the extract actually resolves contributes IDs; an
  absent schematic contributes none (nothing honest can
  be scheduled from it) and a failed load (`None`)
  contributes none.
- **Scope stays the selected detail's pins**, the block's
  existing boundary — at most four IDs per factory pin
  (≤3 inputs + 1 output, section 4), deduplicated by
  `missing()`. Colonies without a loaded detail schedule
  nothing new, and demo mode still returns before the
  block (`shell.rs:1016-1018`); demo names come from
  section 11's seeded fixtures instead.
- Until a fill lands, rows show `Unknown Item` with
  correct quantities — the shipped behaviour for every
  other unresolved type in this view. No loading spinner
  or pending state is added.

## 9. Logging (locked register)

`[PI]` everywhere; counts only; no schematic, pin, or
type ID and no name string in any new line:

- Loader (`planet_schematics.rs`): debug
  `"[PI] loading bundled planet schematics"` on entry
  (section 4); info
  `"[PI] planet schematics loaded schematics={} type_entries={}"`
  once per successful `from_json`.
- Startup (`shell.rs`): info
  `"[PI] bundled planet schematics loaded schematics={}"`
  / warn
  `"[PI] bundled planet schematics failed to load: {}"`
  once per launch (section 5).
- Rows (`planets.rs`): debug
  `"[PI] factory pin rows={} resolved={} not_in_extract={} unlisted_pin={} skipped={}"`
  once per `factory_pin_rows` call (section 6).
- Renderer and scheduling: no new lines. An absent
  schematic or an unlisted pin type is normal data
  (section 7), counted in the rows line, never warned.

## 10. Tests (locked)

Every assertion compares full fields or whole structs,
never a substring (the `planets.rs` house rule). Builder A
owns the loader tests; Builder B owns the rows, startup,
and demo tests.

**Loader (`src/names/planet_schematics.rs` tests):**

1. `bundled_catalogue_pins` on `load_bundled()`:
   `schematic_count() == 68`, `type_entry_count() == 203`
   (135 inputs + 68 outputs, recomputed by iteration);
   first ID 65, last ID 135; `schematic(93)`,
   `schematic(101)`, and `schematic(120)` are `None`
   (the three gaps); `schematic(0)` and `schematic(-1)`
   are `None`; an exhaustive loop proving every schematic
   has 1–3 inputs, `cycle_time ∈ {1800, 3600}` with counts
   15/53, input quantities ⊆ `{6,10,40,3000}`, output
   quantities ⊆ `{1,3,5,20}`, and the pin universe
   exactly the 18 IDs of section 2.1.
2. `bundled_real_data_spot_pins`: whole-struct equality
   for section 3's seven oracles (65, 75, 89, 95, 112,
   121, 135) — name, cycle time, pins, inputs, output —
   plus `allows_pin_type` true/false arms on 65
   (`2480` true, `2481` false, `2475` false, `0` false).
3. `from_json` rejection cases, each a minimal mutation
   of a small valid literal and each `is_err()`: `"{not
   json"`; `"schematics": []` (empty is a hard error);
   manifest absent; `datasetSchema != 1`; each
   `rowCounts` value off by one; duplicate schematic ID;
   IDs out of ascending order; `schematic_id == 0`; name
   `""` / `"  "`; `cycle_time == 0`; pins `[]`, unsorted,
   duplicated, or containing `0`; inputs `[]` and 4
   inputs; an input or the output with `quantity == 0` or
   `type_id <= 0`; inputs unsorted; output type repeated
   as an input.

**Rows (`src/ui/planets.rs` tests).** One local helper is
locked: `schematic_pin(pin_id, type_id, schematic_id)`
building a `PlanetPin` with `..Default::default()`
elsewhere, beside the existing `pin` / `extractor_pin`
helpers. The catalogue under test is the real extract
(`PlanetSchematicsRef::load_bundled()`), and the existing
test `resolver()` gains the six real names section 11
locks (`2389 Plasmoids`, `3645 Water`, `9838
Superconductors`, `2268 Aqueous Liquids`, `2480 Temperate
Advanced Industry Facility`, `2481 Temperate Basic
Industry Facility`) — the test then pins the whole
pipeline, extract included, like `IndustryRef`'s
real-data spots:

4. **Resolved listed**: pin `(700000915, 2480, Some(65))`
   → one `Resolved` row: name `"Superconductors"`, cycle
   3600, output `(9838, "Superconductors", 5)`, inputs
   `[(2389, "Plasmoids", 40), (3645, "Water", 40)]` in
   that (extract) order, `pin_listed: true`, pin type
   name `"Temperate Advanced Industry Facility"`. (Pin
   IDs in tests use the `7000009xx` range so no literal
   collides with fixture or sibling-test IDs.)
5. **Resolved basic**: pin `(700000916, 2481, Some(121))`
   → `"Water"`, 1800, output `(3645, "Water", 20)`, one
   input `(2268, "Aqueous Liquids", 3000)`, listed true.
6. **Unlisted still resolves**: pin `(700000917, 2481,
   Some(65))` → the full case-4 recipe with
   `pin_listed: false` (2481 is a basic facility; 65
   lists advanced facilities only).
7. **Absent**: pins with `Some(15462)` and `Some(93)` →
   `NotInExtract` rows carrying only pin ID and pin type
   name (15462 is the shipped demo placeholder; 93 is a
   true SDE gap — both absent, neither guessed).
8. **No-row arms**: `schematic_id` `None`, `Some(0)`, and
   `Some(-2)` yield no rows; an empty pin list yields no
   rows.
9. **Both-sections pin**: a pin with extractor details
   (product 34) *and* `Some(65)` appears in both
   `extractor_product_rows` and `factory_pin_rows` for
   the same input slice (the shipped fixture shape,
   section 2.3).
10. **Unknown Item honesty**: case 4 against an empty
    `NameResolver::new()` → output and input names all
    `"Unknown Item"`, schematic name still
    `"Superconductors"` (bundled), quantities intact, and
    no rendered field parses as the raw type or schematic
    ID (the whitelist-test shape at `planets.rs:864-867`).
11. **Sort**: a mixed set (65 on 2480, 121 on 2481, a
    second 65 on 2480 with a larger pin ID, one
    `Some(15462)`, one `Some(93)`) → Superconductors rows
    first in pin-ID order, then Water, then the two
    `NotInExtract` rows; reversed input yields an equal
    vec.
12. **Verbatim consts**: the four section 7 constants
    asserted character-for-character (the industry
    const-pin precedent).

**Startup and demo:**

13. `planet_schematics_startup_load_is_catalogue_or_none`
    per section 5.
14. A demo test in `src/demo/data.rs` (or `planets.rs`,
    Builder B's choice of home, one only) proving the
    section 11 fixtures end to end: `load_demo_bundle()`
    + `demo_resolver()` + bundled extract over colony
    `700000001`'s six detail pins yields exactly 4 factory
    rows — 2 resolved (65 and 121, both listed, every type
    name resolved, none `Unknown Item`) followed by 2
    `NotInExtract` (the shipped pins 700000011/700000012).
    The other two shipped schematic pins (700000021,
    700000111) sit on other colonies and are integrator
    demo-check material, not unit literals. (Builder B
    recounts from the fixture at build time; any
    disagreement with this paragraph stops the slice
    rather than fudging the fixture.)

Builder B adds no renderer tests beyond case 12: every
rendered string is a field or const asserted above, and
the renderer's remaining moves (placement, cap, the
`None`-extract branch) are covered by compile, review,
and the integrator's demo check, as with sibling blocks.
The scheduling edit (section 8) is likewise covered by
compile and review, like every existing block of
`schedule_name_resolution`.

## 11. Demo pins (locked fixture change)

Builder B edits exactly two demo files, additively. The
eight shipped pins are untouched — colony-summary counts,
extractor rows, and stored items all depend on them — and
their placeholder schematic IDs become the demo's
`NotInExtract` material (shown, stated, never "fixed" by
inventing a mapping; section 2.3 proves no mapping
exists). Added, to the demo-selected temperate colony
`700000001` only (flavour-consistent facility kinds, no
extractor details — the pure factory wire shape — empty
contents so Stored items is undisturbed):

```json
{"pin_id": 700000015, "type_id": 2480, "latitude": 0.35, "longitude": 0.15, "install_time": "2026-11-02T08:00:00Z", "last_cycle_start": "2026-11-14T10:00:00Z", "schematic_id": 65, "contents": []}
{"pin_id": 700000016, "type_id": 2481, "latitude": -0.3, "longitude": -0.2, "install_time": "2026-11-02T08:00:00Z", "last_cycle_start": "2026-11-14T09:30:00Z", "schematic_id": 121, "contents": []}
```

and that colony's `num_pins` goes 4 → 6 (the stored count
must stay the honest pin total the summary renders;
`docs/pi-colony-summary-design.md` section 9's demo
literals are in-code pins with `reported_pins: Some(4)`
passed explicitly, so no shipped test moves — Builder B
greps `num_pins` and pin-count assertions before landing
and stops if anything contradicts this). Pin IDs
700000015/700000016 are free in the fixture (sibling unit
tests reuse the numbers as literals in their own scope,
which is the file's existing convention). Demo validation
(`validate_bundle`) needs no new rule: it already requires
unique pin IDs per detail, and schematic-bearing demo
pins are deliberately *not* required to resolve — the
absent arm must stay representable in fixtures.

`assets/demo/names.json` gains exactly six entries, real
SDE English names copied from `types.jsonl` (scripted
during design), all `"category": "inventory_type"`, in the
file's existing style: `2268 Aqueous Liquids`,
`2389 Plasmoids`, `3645 Water`, `9838 Superconductors`,
`2480 Temperate Advanced Industry Facility`,
`2481 Temperate Basic Industry Facility` (41 → 47
entries; no test pins the count — Builder B re-greps).
These seed both the new pins' pin-type names and
schematics 65/121's input/output names, so demo mode —
which never schedules (section 8) — shows fully resolved
factory lines. The unlisted-pin arm is not added to the
demo: it is pinned by test case 6, and the demo keeps one
shape per arm it does show (resolved 3600/two-input,
resolved 1800/one-input, absent).

## 12. Deferred — named, not built

- **Planetary Industry management ships nothing.** No
  colony edit, schematic install/change, extractor
  restart, routing, or any write: no endpoint, button,
  state flag, or scope change. The planets module doc's
  read-only contract (`planets.rs:1-6`) stands verbatim.
- **Extractor-cycle output-rate modelling ships nothing —
  and neither does any factory rate.** Grounding check,
  performed during design: the wire carries extractor
  `qty_per_cycle` / `cycle_time` (`ExtractorDetails`,
  `models.rs:671-678`) and this slice displays schematic
  per-cycle quantities plus `cycleTime` as data — but no
  inspected body (retired Flutter `colony_card.dart`,
  which persisted these fields and never derived from
  them, per `pi-colony-summary-design.md` section 11; the
  Rust planets module; the SDE members read) states a
  rate rule, a cycle-chaining rule
  (`last_cycle_start + cycleTime` as a factory completion
  time), an input-sufficiency rule against pin contents,
  or a colony throughput aggregation. Inventing any of
  that arithmetic is out of scope: no per-hour/per-day
  figure, no factory next-completion, no colony-summary
  throughput line ships. If a later slice wants rates, it
  must first ground the arithmetic in an inspected body.
- **`factory_details` parsing.** No such field exists in
  the model or fixtures (section 2.2); if live ESI sends
  one, it is ignored today and any future use is its own
  slice with a captured wire sample. The README's "not
  live-verified" note for Planets covers this section
  too.
- **Colony-summary factory count** (section 7): deferred
  until summary wording can distinguish resolved, absent,
  and extract-unavailable without misleading.
- **Schematic browser / PI production-chain or profit
  calculators, market pricing of inputs/outputs**: the
  pi-port design's no-calculator rule stands; browsing
  schematics with no colony context is a different view.
- **`planetResources.jsonl`** (section 2.1): not read by
  the generator, not bundled, not modelled.
- **Non-English schematic names**: the extract is
  English-only by section 3 lock, matching the app's
  English-only rendering today.

## 13. Integrator list

- **README** (Planets bullet, `README.md:21`): after
  "extractor products," insert "what each factory pin is
  set up to make — the installed schematic's name with its
  per-cycle output, inputs, and cycle time from Mimir's
  bundled planet schematics (a schematic the bundled data
  does not contain is shown as such rather than guessed),
  and" so the bullet's summary list stays grammatical;
  the bullet's closing "there is no production or setup
  calculator" and the not-live-verified sentence stay
  true and unchanged, as does the Planetary Industry
  not-implemented bullet (`README.md:30`), whose
  parenthetical gains "factory schematics" in its list of
  what the read-only view shows. Integrator keeps exact
  wording judgement at merge time; the facts it must
  state are these.
- **Engineering journal**
  (`docs/engineering-journal/LEARNINGS.md`, integrator's
  commit): one entry with Evidence / Mechanism /
  generalizable rule — a bundled catalogue of IDs is only
  half a feature: the schematic name had to be bundled
  (no ESI name path exists for schematic IDs, and 3 of 68
  schematic names differ from their output type's name,
  so deriving it from the resolver would have been wrong
  on exactly the rows nobody spot-checks), while every
  type name still had to flow through the scheduled
  resolver (scheduling the resolved schematics' type IDs,
  never the schematic IDs); and demo fixtures written
  before an extract exists silently live in a different
  ID namespace (`15462`/`17361` vs `{65…135}`), which a
  join-check catches in seconds and a visual demo check
  never would.
- **Demo check**: `--demo`, character `90000001`, colony
  `700000001` → Factories shows Superconductors (Plasmoids
  + Water → Superconductors, 3600 seconds) and Water
  (Aqueous Liquids → Water, 1800 seconds) fully resolved,
  then two "Demo Extractor" rows each stating the
  installed schematic is not in the bundled planet
  schematics; colonies `700000002` and `700000101` each
  show their one absent row; Colony summary still reads
  Extractors as before with `Active Pins: 6` on the first
  colony. Nothing else changes: no ESI, scope, storage,
  or other asset change. If build discovery contradicts
  any literal in sections 2, 10, or 11, the slice stops
  rather than growing scope.

## 14. Ownership, commit split, and gates

- **Design (this commit):** `docs/pi-schematics-design.md`
  only. Commit: `docs(planets): design factory schematic resolution`.
- **Builder A — generator, extract, loader:**
  `scripts/sde/generate_planet_schematics_sde.py`,
  `assets/sde/planet_schematics.json` (generated, never
  hand-edited; twice-run byte-identity, actual byte count
  ≤ 40,000 and output `sha256` recorded in the commit
  body), `src/names/planet_schematics.rs` with section 10
  cases 1–3, and the `src/names/mod.rs` registration. No
  UI or shell change: the loader is `pub` in a `pub`
  module like its siblings, so an unused warning cannot
  arise — if `dead_code` disagrees, Builder A stops and
  the split is revisited rather than papering with
  `allow`. Commit:
  `feat(planets): add bundled planet schematics data`.
- **Builder B — resolution, rendering, wiring, demo**
  (after A; depends on the section 4 API):
  `src/ui/planets.rs` (section 6 rows, section 7 block
  and consts, test cases 4–12 and 14 if homed there),
  `src/app/shell.rs` (section 5 wiring, section 8
  scheduling, test case 13), the `PlanetPin` doc in
  `src/esi/models.rs`, `assets/demo/planets.json` and
  `assets/demo/names.json` (section 11), and the demo
  test. No generator or extract change: if the extract
  contradicts a section 10 literal, that is Builder A's
  stop condition, never a fixture fudge. Commit:
  `feat(planets): resolve factory schematics in colony detail`.
- **Integrator:** README and journal per section 13, full
  gates, and the demo check. Commit:
  `docs(planets): document factory schematic resolution`.

Gates for every commit in the slice, in this order:
`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
`cargo test`, `cargo build`. This design commit runs them
on the unchanged base code and records the observed test
count in its report; Builder A's new tests must pass
without Builder B's UI present, and Builder B re-runs the
generator once to confirm `git diff` stays clean on the
committed extract before building on it. Nothing is
pushed by any builder; the branch is
`feat/rust-pi-schematics` throughout.
