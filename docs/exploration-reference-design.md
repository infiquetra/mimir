# Exploration reference slice — design (locked)

Status: locked design for one small slice. Builders implement exactly
this; anything not listed here is out of scope (section 10).

## 1. What this slice is

One new view, **Exploration**: an offline, read-only wormhole reference
browser over bundled static tables, with text search. It ports only the
Flutter "Wormhole Database" destination of the old Exploration module
(Phase 4a, offline reference). It has no account data, no character
data, and no live data of any kind.

Value ranking for this slice (redefined because no EVE reference value
may be invented; see section 3):

1. Identify a wormhole by code while offline: destination, reliable
   lifetime, per-jump mass, total mass, regeneration, capital-size
   filter (Product story S1).
2. Understand a J-space or special system: category/class/security and
   its applied system effect (Product story S2, reference half only).
3. Browse the exact system-effect tables: six families, strengths 1-6,
   signed percentage vectors.

Everything else the Flutter module did — public Thera/Turnur highways,
the signature notebook, route planning — is excluded (section 10).

## 2. Authorities inspected (exact bodies)

Flutter code lives only in git history at `ed698d3`; read it with
`git show ed698d3:<path>`, never restore Dart files. Every design rule
below traces to one of these inspected bodies:

- Product spec (current tree): `docs/specs/exploration-module.md`
  section 3.1 (R1-R7), section 4.1 (entities, attribute table,
  baseline examples), section 4.2 (exact effect vectors and beacon
  IDs), section 6.2 (Wormhole Database UI contract).
- Flutter architecture spec (current tree):
  `docs/specs/exploration-module-design.md` section 2.1 (SDE tables,
  pinned CCP SDE 3503375, extraction rules), section 2.2 (validated
  import; initial release may ship no static assignments).
- Flutter domain (history): `lib/features/exploration/domain/exploration_reference.dart`
  (508 lines: `WormholeTypeReference`, `destinationLabel`,
  `capitalJumpThresholdKg = 1000000000.0`, `WormholeCodeGroup`,
  `SystemReference.classifySecurity`/`formatSecurity`, `SystemEffect`
  beacon index of 36 entries, resonance formula) and
  `exploration_reference_deriver.dart` (315 lines: `RawWormholeRecord`,
  `ReferenceDeriver.search` ranking, `EffectCatalog` vectors and
  Vorton effect IDs, `staticsDisclosure`, `staticsCreateRouteEdge`
  always false).
- Flutter view (history): `lib/features/exploration/presentation/wormhole_database_view.dart`
  (390 lines: Types/Systems selector, destination and Capital filter
  chips, type/group/system/effect detail fields and formatters,
  reference status strip).
- Flutter test fixtures (history):
  `test/features/exploration/fixtures/exploration_fixtures.dart`
  (F1/F2 oracles) and `test/features/exploration/domain/exploration_reference_test.dart`
  (D01-D07 contracts), `test/core/sde/exploration_reference_import_test.dart`
  (manifest rowCounts `wormholeTypes: 7, effects: 36` for the fixture
  bundle only).
- Rust seams (current tree, develop at `e9eec5f`): `src/app/state.rs`
  (`View` enum lines 15-75, `LoadState` lines 77-109, `AppState`
  fields lines 492-565, navigation test lines 847-877),
  `src/app/shell.rs` (`collect_keys` lines 2165-2215, view dispatch
  lines 2358-2371, rail lines 2341-2350, startup-view persistence by
  label string lines 392-399 and 2260-2274, bundled SDE load lines
  325-328), `src/names/sde.rs` (`Sde::load_bundled`/`from_json`
  include_str loader pattern), `src/ui/widgets.rs` (`matches_search`
  line 130, `search_box` line 184, `mode_notice` line 167,
  `format_countdown` line 57), `src/ui/settings.rs` (`LOG_TAGS`
  lines 7-21, keyboard line 115), `src/ui/assets.rs` (search-box
  idiom lines 220-229, `filter_groups` line 122),
  `scripts/sde/generate_dogma_sde.py` (build-time download-and-cache
  generator precedent), `docs/fittings-library-design.md` section 9.4
  (tenth-view key numbering precedent).

## 3. Data inventory — what is grounded, what is not

Hard rule: no wormhole class, effect, signature name, or number is
rendered unless it is mechanically traceable to a body in section 2.
Two consequences shape the whole slice:

- The full per-type wormhole catalogue and the J-space system list do
  **not** exist as rows in any inspected body. Flutter defined the
  table schemas and imported rows at runtime from a downloaded SDE
  bundle; the context-library spec defines field shapes only; the
  current Rust `assets/sde/dogma.json` contains zero group-988
  (wormhole), group-920 (effect beacon), or group-995 (secondary sun)
  types (verified by parsing it: 14,941 types, none in those groups,
  type IDs 30677/30831/92287/30844 all absent). The catalogue must
  therefore be produced by a build-time extractor over the pinned CCP
  SDE archive (section 4), exactly as both specs prescribe. If the
  pinned archive cannot be fetched in the build environment, Builder
  A stops and reports; shipping fixture rows instead is forbidden.
- The F1/F2 test fixtures contain synthetic rows (Q001/Q002 are
  literally named "Synthetic", the C729 fixture variants use invented
  type IDs 94001/94002, fixture systems use IDs 96001/96002/96013).
  The Product spec states these are "source fixtures, not hardcoded
  catalog replacements" and the architecture spec states "No
  fixture-only miniature catalog as a production asset." Fixture rows
  may appear only inside Rust unit tests, never in bundled data.

### 3.1 Bundled tables (the complete inventory)

One bundled file, `assets/sde/exploration.json`, with four tables plus
a manifest block. Nothing else is bundled.

| Table | Contents | Source body | Row-count expectation |
|---|---|---|---|
| `manifest` | `sdeBuild`, `datasetSchema`, `sourceFiles` (name + sha256 each), `rowCounts` per table, `generatedBy` | `ReferenceManifest` in `exploration_reference.dart` lines 18-75; Product section 4.1 | Exactly 1 object; `sdeBuild` = 3503375 |
| `types` | One row per SDE type ID in group 988, unpublished included | Extractor over pinned archive (section 4); field set from `RawWormholeRecord`/`WormholeTypeReference` | Equals the group-988 row count the extractor records in `manifest.rowCounts.types`; structural invariants in section 3.2 (no total is invented here) |
| `systems` | One row per solar system whose inherited class is special (1-6, 12, 13, 14-18, 25) | Extractor over pinned archive; field set from `SystemReference` lines 265-324 | Equals `manifest.rowCounts.systems`; class-13 subset is exactly 25 (Product section 4.2) |
| `effects` | One row per (family, strength): beacon type ID, modifier rows | `EffectCatalog.beacons`/`_vectors` in deriver lines 221-292 cross-checked against Product section 4.2 tables | Exactly 36 rows, unique (family, strength) |
| `statics` | Per-system static assignments | No grounded dataset exists in any inspected body | Exactly 0 rows in this slice; every system renders "Static information unavailable" (architecture spec 2.2 permits an initial release with no assignments) |

Deliberately not bundled:

- Stargates / gate topology: excluded. No jump graph exists in this
  slice, so no route computation is possible or attempted.
- Known-space (highsec/lowsec/nullsec) systems: excluded. The systems
  table covers only special-class systems, which are the ones with a
  wormhole class or a system effect. Known-space system names in live
  views remain the name resolver's job, unchanged.
- Signature-type vocabulary (Unknown/Wormhole/Data/Relic/Gas/Combat/Ore
  from the notebook domain): excluded. It has no render surface
  without the notebook, which is out of scope.
- Any static "highway" list: excluded. No grounded static list exists;
  Thera/Turnur connections are live reported data, not reference data.

### 3.2 Structural invariants (golden expectations, all inspected)

These are the only numeric expectations the design asserts. Each one
is stated in an inspected body; the extractor and the Rust golden
test both enforce them, so a truncated or wrong extraction fails
loudly instead of shipping short data.

- Effects: exactly 36 (family, strength) combinations, 6 families x
  strengths 1-6 (`EffectCatalog.combinations`, Product section 4.2).
  Beacon IDs by family and strength 1-6: Pulsar 30844, 30865, 30866,
  30867, 30868, 30869; Black Hole 30845, 30850, 30851, 30852, 30853,
  30854; Cataclysmic Variable 30846, 30880, 30881, 30884, 30883,
  30882 (strengths 4-6 deliberately not in ascending ID order);
  Magnetar 30847, 30860, 30861, 30862, 30863, 30864; Red Giant 30848,
  30870, 30871, 30872, 30873, 30874; Wolf-Rayet 30849, 30875, 30876,
  30877, 30878, 30879. Same table in `SystemEffect._beaconIndex`,
  deriver `EffectCatalog.beacons`, fixtures `F2Oracle`, and Product
  section 4.2 — four inspected copies that agree.
- Modifier vectors are built only from four inspected sequences:
  plus30 = [30, 44, 58, 72, 86, 100], plus15 = [15, 22, 29, 36, 43,
  50], minus15 = [-15, -22, -29, -36, -43, -50], Wolf-Rayet small =
  [60, 88, 116, 144, 172, 200] (deriver lines 221-224; Product
  section 4.2 tables row by row). Attribute-to-vector assignment per
  family is deriver `_vectors` lines 242-292; the human-readable
  modifier label for each attribute ID is the Product section 4.2 row
  heading (for example attribute 146 "Shield capacity", 1500
  "Capacitor recharge time", 1493 "Small weapon damage"). Resonance
  ranges 1465-1468 and 1489-1492 are one rendered row each ("Armor
  damage resonance, all types" / "Shield damage resonance, all
  types"), matching the Product tables; the bundled file stores them
  as four attribute rows with that shared label, and the view renders
  the label once per effect (section 8).
- Vorton scope: effect IDs {11946, 11947, 11948, 11953}
  (`EffectCatalog.vortonEffectIds`, deriver line 219), returned as
  the scope set for Wolf-Rayet only (deriver `scopes` lines 311-314).
- Types: the code group `C729` has exactly 28 variants (Product
  section 4.1: "The 28 C729 type variants share a code"; architecture
  spec 2.1: "Preserve every type ID, including 28 C729 variants").
- Types: K162, type ID 30831, is present, is unpublished, and has no
  dogma values — lifetime, jump mass, total mass, and regeneration
  are all null, never zero (deriver line 54; Product section 4.1;
  fixture `k162Raw`).
- Types: B274, type ID 30677, raw target class 7, raw stable time
  1440 minutes (86400 seconds after conversion), total mass
  2,000,000,000 kg, jump mass 375,000,000 kg (Product section 4.1
  baseline examples; `F1Oracle` agrees). I078, type ID 92287, raw
  stable time 270 minutes (16200 seconds), raw target class 25
  (Product section 4.1; fixture `i078Raw`).
- Systems: exactly 25 class-13 systems, all applied effect
  Wolf-Rayet strength 6 (Product section 4.2). Regression systems:
  J005926 resolves to Red Giant strength 1 and J010569 to Wolf-Rayet
  strength 1 through the applied beacon, not the visual sun (Product
  section 4.2; `F2Fixtures` use synthetic IDs for these names, so the
  golden test keys on the system **names** in extracted data, never
  on fixture IDs).
- Types and systems totals: not asserted here. The architecture spec
  forbids inventing production row counts ("Manifest
  counts/checksums must be generated from the full pinned archive";
  "this architecture does not invent production row counts"). The
  extractor writes the true counts into the manifest; the loader
  rejects the file if the parsed counts differ (section 5).

## 4. Mechanical extraction (Builder A)

New build-time script `scripts/sde/generate_exploration_sde.py`,
following the existing generator precedent
(`scripts/sde/generate_dogma_sde.py`: download once, cache under
`scripts/sde/`, reuse the cache on later runs). Network exists only
inside this script at asset-generation time; the shipped app performs
zero network work for this view.

Source: the pinned CCP archive named in both specs, SDE build
3503375, `https://developers.eveonline.com/static-data/tranquility/eve-online-static-data-3503375-jsonl.zip`.
The script records the sha256 of every input JSONL file it reads into
`manifest.sourceFiles`. No other data source is permitted: no
Fuzzwork "latest" (the architecture spec forbids mixing releases),
no hand-typed rows, no values from memory or from the fixture file.

Extraction rules (each from architecture spec 2.1 or the deriver):

1. Types: select every type whose group is 988, **including
   unpublished** types (K162). Code and name come from the type
   record. Dogma attributes are read individually: 1381 target
   system class, 1382 max stable time (**minutes**, stored raw; the
   x60 conversion happens in Rust, mirroring
   `WormholeTypeReference.fromRaw`), 1383 max stable mass kg, 1384
   mass regeneration kg/cycle, 1385 max jump mass kg, 1457 target
   distribution (Product section 4.1 attribute table). Missing
   attributes stay absent in JSON (null), never 0.
2. Systems: read regions, constellations, and solar systems from the
   same archive. Inherited class is system, then constellation, then
   region (`ReferenceDeriver.inheritClass`), recording which level
   supplied it. Keep only systems whose raw or inherited class is in
   {1-6, 12, 13, 14-18, 25} (the special set in
   `SystemReference._isSpecialClass`). Applied effect identity comes
   from the secondary-sun record's effect beacon type ID, never the
   visual sun and never the system class; both beacon and visual IDs
   are stored for diagnostics, and `effect_verified_absent` is true
   only when a secondary-sun record exists with an empty beacon
   column.
3. Effects: emit the 36 (family, strength, beaconTypeId) rows and
   their modifier rows from the inspected vector tables (section
   3.2), which the script carries as constants transcribed from
   deriver `EffectCatalog` and Product section 4.2 — these two
   inspected copies must agree; the script also cross-checks that
   every one of the 36 beacon type IDs exists in the archive's types
   (group 920). Do not derive percentages from dogma multipliers at
   extraction time: the specs forbid one global transform, and the
   Product tables are already exact percentage changes. Modifier
   labels are transcribed from the Product section 4.2 row headings
   only.
4. Statics: emit an empty list. The extractor never synthesizes a
   typical-class assignment.
5. Self-validation before writing output: the script exits nonzero
   unless every invariant in section 3.2 that is checkable at
   extraction time holds (36 beacons present, C729 group = 28 rows,
   K162 present with no dogma, B274/I078 baseline values, 25
   class-13 systems, J005926/J010569 beacon resolution, no duplicate
   type IDs, no negative or non-finite masses, every system's
   constellation/region names resolved inside the same archive).
6. Deterministic output: rows sorted by type ID (types), system name
   then system ID (systems), family order as in `EffectFamily` then
   strength (effects); stable JSON formatting so re-running the
   script on the same archive produces a byte-identical file.

The generated `assets/sde/exploration.json` is committed by Builder A
together with the script, like the existing generated SDE assets.

## 5. Data model and loader (Builder A)

New module `src/names/exploration_ref.rs`, registered in
`src/names/mod.rs` as `pub mod exploration_ref;` — a sibling of
`src/names/sde.rs`, following its loader pattern exactly:
`include_str!("../../assets/sde/exploration.json")`, a public
`load_bundled() -> AppResult<Self>` that logs with the `[EXPLORE]`
tag, and a public `from_json(&str) -> AppResult<Self>` so tests can
feed malformed input. New logging tag: `[EXPLORE]` (the settings
`LOG_TAGS` update is the integrator's, section 9).

### 5.1 Structs (serde, camelCase renames like `sde.rs`)

- `ExplorationRef { manifest: ReferenceManifest, types: Vec<WormholeType>, systems: Vec<RefSystem>, effects: Vec<RefEffect>, statics: Vec<StaticAssignment> }`
  plus private lookup indexes built in `from_json` (type by ID,
  types grouped by code, system by ID, effect by beacon ID).
- `ReferenceManifest { sde_build: i64, dataset_schema: i64, source_files: Vec<SourceFile>, row_counts: BTreeMap<String, usize> }`
  mirroring the Dart `ReferenceManifest` fields this slice uses.
- `WormholeType` — the bundled row: `type_id: i64, code: String,
  name: String, published: bool, raw_target_class: Option<i64>,
  raw_target_distribution: Option<i64>,
  raw_max_stable_time_minutes: Option<i64>, raw_total_mass_kg:
  Option<f64>, raw_jump_mass_kg: Option<f64>, raw_regen_kg:
  Option<f64>` (field-for-field `RawWormholeRecord`). Derived, never
  stored: `lifetime_seconds() = raw_max_stable_time_minutes * 60`,
  `destination_label()` (section 7), `is_capital_size()`.
- `CodeGroup` — derived by `group_by_code`, mirroring
  `WormholeCodeGroup`: `code, variants: Vec<usize>` (indexes into
  `types`), `shared_lifetime_seconds: Option<i64>`,
  `shared_jump_mass_kg: Option<f64>`, `jump_varies: bool`. Shared
  values are computed from **all** variants of the code, never from
  search-matched variants only (architecture spec 2.1).
- `RefSystem` — `system_id: i64, name: String, constellation_name:
  Option<String>, region_name: Option<String>, raw_security:
  Option<f64>, raw_class: Option<i64>, inherited_class: Option<i64>,
  inheritance_source: Option<String>, effect_beacon_type_id:
  Option<i64>, visual_sun_type_id: Option<i64>,
  effect_verified_absent: bool` (field-for-field
  `SystemReference` minus embedded statics, which stay a separate
  table). Derived: `category()`, `security_display()`,
  `security_label()`, `effect_state()` (section 7).
- `RefEffect { family: EffectFamily, strength: u8, beacon_type_id:
  i64, modifiers: Vec<RefModifier> }` and
  `RefModifier { attribute_id: i64, label: String, percent: f64 }`.
  `EffectFamily` is an enum with the six Dart variants in Dart order
  (Pulsar, BlackHole, CataclysmicVariable, Magnetar, RedGiant,
  WolfRayet) and a `label()` returning the Product table headings
  ("Pulsar", "Black Hole", "Cataclysmic Variable", "Magnetar",
  "Red Giant", "Wolf-Rayet").
- `StaticAssignment { system_id: i64, code: Option<String>,
  type_id: Option<i64>, meaning: String, source: String,
  confidence: String }` (field-for-field the Dart class). The table
  is empty in this slice but the type and the honest-unavailable
  rule ship now.

Optional columns use `#[serde(default)]` so an absent key is `None`.
A present-but-wrong-typed value is a parse error, never coerced.
Missing dogma is never coerced to zero anywhere (deriver rule).

### 5.2 Validation and failure behavior (whole-view, never partial)

`from_json` is all-or-nothing. It returns `Err` — and the view shows
one whole-view error — when any of these holds:

- JSON does not parse, or the manifest block is missing.
- `manifest.row_counts` disagrees with the parsed lengths of
  `types`, `systems`, `effects`, or `statics` (this is the
  truncation catch: a short file can never render as a short but
  plausible catalogue).
- `effects` is not exactly 36 rows with unique (family, strength),
  or any strength is outside 1-6 (spec: "No unknown strength coerced
  into 1 or 6").
- Duplicate `type_id`, duplicate `system_id`, or duplicate
  `beacon_type_id`.
- Any mass or regeneration value is negative or non-finite; any
  lifetime minutes value is negative.
- Any type row has an empty `code` or empty `name`; any system row
  has an empty `name` (names are the render identity; raw IDs are
  never rendered as a fallback).

There is no per-row skipping, no `unwrap_or_default` empty catalogue,
and no panic path: parse and validation failures become
`AppError` via the existing `serde_json` conversion used by
`sde.rs`, with a message that contains no row content beyond counts.
On error the load is logged once at startup
(`[EXPLORE] bundled exploration reference failed to load: ...`) and
`AppState.exploration` becomes `LoadState::Error` carrying the fixed
user-facing sentence in section 8.4 — the rest of the app is
unaffected (the Flutter rule that an exploration reference failure
must not block other features).

Load timing: once, in `MimirApp::new` beside the existing
`Sde::load_bundled()` call (integrator wiring, section 9). The result
is stored in `AppState` as `LoadState<ExplorationData>` (section 7.1),
so the view never touches disk, never re-parses per frame, and
renders identically in live and demo modes (section 8.5).

## 6. View placement and the 11-view keyboard decision

### 6.1 Placement (Builder B: `src/app/state.rs`)

`Exploration` is **appended after `Settings`** as view 11 of 11:

- `View` gains `Exploration` after `Settings`; `View::ALL` becomes
  `[View; 11]` with the same append; `label()` returns
  `"Exploration"`. The enum doc comment becomes "The eleven views
  (keys 1-9, 0 and E in the shell)."
- Consequences, all locked: `from_index(9)` stays Settings,
  `from_index(10)` becomes Exploration, `from_index(11)` is `None`;
  `Settings.next()` becomes Exploration, `Exploration.next()` wraps
  to Dashboard, `Dashboard.previous()` becomes Exploration,
  `Exploration.previous()` is Settings, `Fittings.next()` and
  `Settings.previous()` are unchanged. Every existing index 0-9 is
  unchanged, so no current key changes meaning.
- The `view_navigation_wraps_and_indexes` test is updated to assert
  the new links plus `Exploration.index() == 10` and
  `View::ALL.len() == 11`, keeping all existing assertions.

Appending (rather than inserting before Settings) is the decision
because inserting would move Settings from index 9 to 10: the `Num0`
arm (`from_index(9)`) would silently open Exploration, and Settings
would need a new key — breaking the muscle memory the fittings
design section 9.4 deliberately preserved. Appending changes no
existing key.

### 6.2 Keys (integrator: `src/app/shell.rs`)

All ten digit keys are taken (Num1-Num9 for indices 0-8, Num0 for
index 9). The eleventh view takes a mnemonic letter:

- **Exploration: `E`** (`egui::Key::E`). **Settings stays `0`**
  (`egui::Key::Num0` → `from_index(9)`, unchanged code).
- In `collect_keys`, after the Num0 arm and under the same guards
  (not typing — the existing early return covers this; no
  command/ctrl modifier):
  `if i.key_pressed(egui::Key::E) && !i.modifiers.command && !i.modifiers.ctrl { actions.switch_view = Some(View::Exploration); }`
  `Key::E` is otherwise unused in `collect_keys` (only R with a
  modifier, F5, digits, PageUp/PageDown, and `/` text are handled).
- The side rail can no longer derive its digit from
  `(idx + 1) % 10` (index 10 would print "1", colliding with
  Dashboard). The integrator adds a pure helper in the shell,
  `fn view_key_hint(view: View) -> &'static str`, returning "1"-"9"
  for indices 0-8, "0" for Settings, and "E" for Exploration, and
  the rail renders `format!("{} {}", view_key_hint(*view), view.label())`.

### 6.3 Hint strings (all sites, grep-verified list)

A `grep -rn "1-9" src/ README.md` at design time returns exactly six
lines. All six change in the integrator commit (plus the state doc
comment, which is Builder B's):

| Site | Current | New |
|---|---|---|
| `src/app/state.rs:15` doc (Builder B) | "The ten views (keys 1-9 and 0 in the shell)." | "The eleven views (keys 1-9, 0 and E in the shell)." |
| `src/app/shell.rs` rail heading | `Views (keys 1-9, 0)` | `Views (keys 1-9, 0, E)` |
| `src/app/shell.rs` status bar | `Keys: 1-9, 0 views, Ctrl+R refresh, / search, PgUp/PgDn character` | `Keys: 1-9, 0, E views, Ctrl+R refresh, / search, PgUp/PgDn character` |
| `src/ui/widgets.rs` `no_character_panel` | `Keys: 1-9, 0 switch views, PageUp/PageDown switch character.` | `Keys: 1-9, 0, E switch views, PageUp/PageDown switch character.` |
| `src/ui/settings.rs` keyboard line | `1-9, 0 views \| Ctrl/Cmd+R refresh \| / focus search \| PgUp/PgDn character \| Up/Down table rows` | `1-9, 0, E views \| Ctrl/Cmd+R refresh \| / focus search \| PgUp/PgDn character \| Up/Down table rows` |
| `README.md` Settings bullet | "keyboard shortcuts (1-9, 0 views, ..." | "keyboard shortcuts (1-9, 0, E views, ..." |

After the change, the same grep must return only updated lines.

### 6.4 Persisted `startup_view` label safety

No migration. The startup view is persisted as the `label()` string
(`repositories::set_setting("startup_view", ...)`) and restored by
`View::ALL.iter().find(|v| v.label() == saved)` in
`MimirApp::new`, falling back to the default Dashboard when no label
matches. Appending `"Exploration"` cannot reinterpret any saved
string: all ten existing labels resolve to the same views, an unknown
future label still falls back to Dashboard, and selecting Exploration
as the startup view persists the new string with no schema change.
The Settings startup-view row already iterates `View::ALL`, so the
new choice appears with no settings code change beyond section 6.3
and the `[EXPLORE]` log tag (section 9).

## 7. State and search semantics (Builder B)

### 7.1 `AppState` additions (`src/app/state.rs`)

Following the existing per-view field blocks (market, industry,
planetary, fittings precedents):

- `pub exploration: LoadState<ExplorationData>` where
  `ExplorationData { reference: ExplorationRef }` is defined in
  `state.rs` next to the other per-view data structs. It starts as
  `LoadState::Loading` and is set exactly once by the integrator at
  startup (Ready or Error). It is never refetched; there is no
  request flag for this view.
- `pub exploration_search: String`
- `pub exploration_section: ExplorationSection` — new enum
  `#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]` with
  `#[default] Types`, `Systems`, `Effects`.
- `pub exploration_destination: Option<DestinationFilter>` — new enum
  with `Highsec`, `Lowsec`, `Nullsec`, `Pochven`, `JSpace` (the five
  Flutter filter chips) and a `label()` returning the chip text.
- `pub exploration_capital_only: bool`
- Selection by stable key, never by row index (Product section 6.1:
  navigation state must not depend on row indices):
  `pub exploration_selected_code: Option<String>` (a wormhole code),
  `pub exploration_selected_system_id: Option<i64>`,
  `pub exploration_selected_family: Option<EffectFamily>` plus
  `pub exploration_selected_strength: u8` (default 1, clamped 1-6).

No field is persisted to the database. There are no new ESI calls, no
new scopes, no request flags, and no character dependency: the view
works with zero characters signed in.

### 7.2 Pure logic location

Data-shaping pure functions live in `src/names/exploration_ref.rs`
(Builder A, with the fixture tests), because they are deriver ports:
`group_by_code`, `search_types`, `destination_label`,
`is_capital_size`, `classify_security`, `format_security`,
`security_label`, `far_side` mapping used by the destination filter,
`effect_for_system`, `statics_label`. Rendering formatters
(`format_kg`, `format_regen`, `format_lifetime`, `format_percent`)
live in `src/ui/exploration.rs` (Builder B), mirroring the Flutter
view's private formatters. Every function is total (no panics on
None, empty, or malformed values).

### 7.3 Search semantics (deriver port, not substring-only)

The search box reuses `widgets::search_box` with the standard
four-line idiom (assets/fittings precedent) and the `/` focus path.
Matching itself ports `ReferenceDeriver.search` + `_typeMatches` +
`_textRank` exactly; `widgets::matches_search` (case-insensitive
substring, empty needle matches all) is the per-field primitive,
matching how `filter_groups` builds on it in assets:

- The needle is trimmed once; an empty needle matches everything.
- Types section: variants are filtered first, then regrouped by
  code for display, so destination + mass conditions must hold on
  the **same variant** (D03 contract). Text matches a variant when
  the needle is a case-insensitive substring of its code, its name,
  **or its destination label**. Ranking for non-empty text: exact
  field match (rank 0), then field prefix (rank 1), then field
  substring (rank 2), then code A-Z (`_textRank`). With empty text,
  display order is code A-Z, then type ID (a deterministic display
  rule; the deriver returned insertion order, which the bundled
  file's type-ID sort would make non-alphabetical — this design
  locks the alphabetical display order as a pure function
  `sorted_groups` so tests can pin it).
- Destination filter: a variant passes when its
  `destination_label()` equals the chip label, except `JSpace`,
  which passes labels `C1`-`C6` (the Flutter chip "J-space" has no
  single destination label; the Flutter view's exact-match against
  "J-space" could never match a type, so this design defines the
  chip as the six J-space class labels and tests it — a deliberate,
  documented deviation from a dead Flutter behaviour).
- Capital filter: `is_capital_size` is
  `raw_jump_mass_kg >= 1_000_000_000.0` (`capitalJumpThresholdKg`);
  a variant with unknown jump mass never passes (K162 is excluded by
  any mass condition, D03). Unlike the Flutter view, turning Capital
  on does **not** clear the search text: filters combine with AND
  (Product R7). This deviation is deliberate and tested.
- Systems section: substring match on the system name only
  (Flutter `_filteredSystems`), case-insensitive, trimmed; display
  order is name A-Z then system ID (pure function
  `sorted_systems`). The destination and capital chips are not shown
  in this section (Flutter hides type filters for Systems).
- Effects section: no text filtering of the 36 rows (the table is
  small and complete); the search box filters families by family
  label substring so the box is never dead UI. Display order is the
  `EffectFamily` declaration order, strengths 1-6 inside each
  family (pure function `sorted_effects`).

### 7.4 Derived mappings (exact ports, Builder A)

- `destination_label(raw_target_class)`: 7 Highsec, 8 Lowsec, 9
  Nullsec, 12 Thera, 25 Pochven, -1 Varies, 1-6 `C<n>`, 14-18
  Drifter, 13 Shattered, anything else (including None) Unknown.
  Class -1 is special C729 behaviour, not a missing-value sentinel
  (Product section 4.1) — it renders "Varies", never "Unknown".
- `classify_security(x)`: None → Unknown; `x >= 0.45` → Highsec;
  `x > 0` → Lowsec; otherwise Nullsec. `format_security(x)`: None →
  "Unknown"; `x <= 0` → "0.0"; `x < 0.05` → "0.1"; otherwise one
  decimal, rounded. A system whose raw class is special
  (1-6/12/13/25/14-18) is always category Special regardless of
  security (`SystemReference.category`), so Thera and Pochven with
  negative security never render as Nullsec (D07).
- `security_label(system)`: Highsec/Lowsec/Nullsec/Unknown by
  category; for Special: class 12 Thera, 25 Pochven, 13 Shattered,
  1-6 J-space, otherwise Special (Flutter `_securityLabel`).
- `effect_for_system(system, reference)`: keeps the Dart three-state
  result (`Applied`/`None`/`Unknown`, `SystemEffectState`) and never
  collapses Unknown into "no effect". Resolution order: the applied
  beacon ID wins; if it is absent, the visual sun ID is tried as the
  beacon (Dart `beacon ?? visual`); a candidate ID that exists in
  the 36-row table → `Applied` with that family/strength; a
  candidate ID that is **not** in the table → `Unknown` (a deliberate
  deviation from the Dart fallback, which defaulted an unrecognised
  beacon to Pulsar strength 1 — Product section 4.1 forbids coercing
  an unknown strength). Both IDs absent → `Unknown` (data missing),
  unless the extractor set `effect_verified_absent` (a secondary-sun
  record exists for the system and its beacon column is empty), in
  which case → `None`.
- `statics_label(reference, system_id)`: returns the constant
  "Static information unavailable" when the statics table has no
  assignments for the system (always, in this slice); the general
  form joins assignment codes with ", " when a future dataset
  exists. No route edge is ever derived from statics
  (`staticsCreateRouteEdge` is false in all branches; there is no
  graph here at all).
- Resonance helper `apply_resonance(old_resist, percent) =
  1 - (1 - old_resist) * (1 + percent / 100)` is ported as a pure
  function with its F2 test (50% resist with +50% resonance → 25%)
  because the Effects section renders the explanatory sentence that
  depends on it (section 8.3). It is reference logic, not a fitting
  calculation.

## 8. What renders (Builder B: `src/ui/exploration.rs`)

New file `src/ui/exploration.rs`, registered by Builder B in
`src/ui/mod.rs` as `pub mod exploration;` (alphabetical, after
`dashboard`). Signature: `pub fn show(ui: &mut egui::Ui, state: &mut
AppState)` — no resolver parameter; every rendered string comes from
the bundled reference, so no name resolution exists in this view.

Layout follows the Flutter Wormhole Database: reference status strip,
search box, section selector, (Types only) filter chips, then list +
detail stacked in the central scroll area like every other view (no
master-detail breakpoint logic; the shell gives one column).

### 8.1 Common chrome

- Heading "Exploration".
- Reference strip (port of `_ReferenceStatusStrip`): when Ready,
  `Reference data: CCP SDE {sde_build} (bundled, offline)`. This
  strip is shown in live and demo modes alike (section 8.5). There
  is no refresh button and no live-update control (Product section
  6.2: "Local reference browsing has no fake live refresh control").
- Search box hint per section: Types —
  "Filter by wormhole code, name or destination (press / to focus)";
  Systems — "Filter systems by name (press / to focus)"; Effects —
  "Filter effects by family (press / to focus)".
- Section selector: three selectable labels "Types", "Systems",
  "Effects" (Flutter had Types/Systems; Effects is added because
  Product R5 requires browsing all 36 combinations, which Flutter
  only reached through a system selection).

### 8.2 Types section

Filter chips (selectable labels): "Highsec", "Lowsec", "Nullsec",
"Pochven", "J-space", and "Capital-size". Selecting a destination
chip again clears it. Directly under the chips, one fixed
qualification line (Product R7; also answers section 6.2's "Do not
label the capital mass shortcut Capitals OK"):
"Capital-size means a nominal per-jump mass limit of at least
1,000,000,000 kg. It does not guarantee a ship can use a connection."

Result count label: `{n} code groups` (plus `{m} types` in
parentheses when any group has more than one variant — counts are
computed from loaded data, never literals).

Each group renders as one selectable row: the code, then
" · {destination label}" when all variants share one destination
label, then " · {k} variants" when k > 1. Selecting a row sets
`exploration_selected_code`.

Detail for the selected group (every field traceable; unknown values
render the word "Unknown", never 0 and never a placeholder number):

- Heading: the code (for example "B274").
- When variants agree: "Reliable lifetime {format_lifetime}",
  "Jump mass {format_kg}", "Total mass {format_kg}", "Regen
  {format_regen}", "Destination {label}" (the Flutter `_typeDetail`
  field set, in that order).
- When variants disagree on jump mass: "Jump mass Varies"
  (`_groupDetail`); lifetime likewise shows the shared value or
  "Varies". Below, one line per variant: "{name}: lifetime {...},
  jump {...}, total {...}, regen {...}, destination {label}".
  Variant **names** are rendered; variant type IDs are never
  rendered (Product R3: "Do not expose raw variant IDs as
  user-facing names"; repo rule: resolved names only, never raw
  IDs).
- K162 detail shows "Unknown" for lifetime and all masses. No
  originating type is ever guessed for it.

Formatters (pure, tested): `format_lifetime(None)` → "Unknown";
`Some(seconds)` → "{seconds}s ({format_countdown})" reusing
`widgets::format_countdown`, so B274 reads "86400s (1d 0h 0m)" —
the exact seconds satisfy Product R2's "Exact kg and duration values
must be available in details". `format_kg(None)` → "Unknown";
`Some(kg)` → thousands-grouped integer when the value is integral,
otherwise the plain decimal, plus " kg" (Flutter `_number`
semantics with grouping). `format_regen` is the same with
" kg/cycle" (never kg/s).

### 8.3 Systems and Effects sections

Systems section: one selectable row per system: "{name} ·
{security_label}". Detail for the selected system (Flutter
`_systemDetail` field set):

- Hierarchy heading "{name} → {constellation} → {region}", omitting
  absent levels.
- "{security_label}" and "Security {security_display}".
- Effect block: when the applied effect resolves, "Effect {family
  label} {strength}" followed by the same modifier lines as the
  Effects detail below; when state is None, "No system effect"; when Unknown,
  "System effect unknown". Missing data never renders as "no
  effect" (Product R5).
- Statics line: `statics_label` output — in this slice always
  "Static information unavailable".

Effects section: six family headings in `EffectFamily` order; under
each, six selectable strength rows "Strength {n}". Selecting a
family/strength shows its detail: "Effect {family label} {strength}"
then one line per distinct modifier label: "{label}
{format_percent}", with `format_percent` rendering an explicit sign
("+30%", "-15%", "0%"). Resonance attribute rows sharing one label
render once. Two fixed explanatory sentences render under every
effect detail (static UI text from Product section 4.2, not data):
"Increased damage resonance worsens resistance: a 50% resistance
with +50% resonance becomes 25%, not 0%." and, for Wolf-Rayet only,
"Scope includes Vorton projector effects." (from
`EffectCatalog.scopes`). Beacon type IDs and dogma attribute IDs are
never rendered — they are raw EVE IDs; family + strength + label is
the identity.

Wording guards from Product section 4.2, locked: capacitor rows keep
the word "time" ("Capacitor recharge time"); no benefit/harm colour
coding is added (a positive percentage is not styled green); the
labels "Small weapon damage" and the smartbomb labels carry their
own scope and are not generalised.

### 8.4 Empty and error states (exact strings)

- Loading (only before the one-time startup load lands):
  `widgets::loading_panel` with "Loading exploration reference...".
- Whole-view error (any section 5.2 failure):
  `widgets::error_panel` (not the retry variant — nothing can be
  retried; the data is bundled) with exactly:
  "Exploration reference data could not be loaded. The bundled data
  is missing or damaged; reinstalling the app restores it." The
  search box and chips are not rendered in this state.
- Ready but a section's table is empty (defensive; validation makes
  this unreachable for effects): `widgets::empty_panel` with "No
  wormhole reference data." / "No system reference data." / "No
  effect reference data."
- Search or filters match nothing: `widgets::empty_panel` with
  "No wormhole types match." / "No systems match." / "No effects
  match." — distinct from the empty-table strings, so a filtered
  empty never looks like missing data.
- Nothing selected yet in Types/Systems: "Select a wormhole code
  for details." / "Select a system for details."

### 8.5 Demo story (no demo edits)

Bundled reference data is real SDE data and is **identical in live
and demo modes**. Therefore:

- The Exploration view does **not** call `widgets::mode_notice`:
  its demo text ("Demo data: invented sample rows...") would be
  false here. The view shows the reference strip of section 8.1 in
  both modes. The shell top bar still shows "[DEMO] Demo mode"
  globally in demo mode, which is accurate for the app as a whole.
- Builder B makes **zero** edits to `src/demo/data.rs` and adds no
  file under `assets/demo/`. The demo loader injects per-character
  ESI-shaped data; this view has no per-character data to inject.
- Proof it is not demo-only content: the test plan (section 11)
  loads the bundled reference with `AppState::new(false)` (demo off)
  and with demo on, and asserts the same loaded catalogue both ways.

## 9. Integrator wiring

In `src/app/shell.rs`:

- Load once in `MimirApp::new` beside `Sde::load_bundled()`:
  `ExplorationRef::load_bundled()` → on Ok, set
  `state.exploration = LoadState::Ready(ExplorationData { reference })`
  and log loaded counts with `[EXPLORE]`; on Err, log the warning of
  section 5.2 and set `LoadState::Error` with the section 8.4
  sentence. Unlike the Sde load, there is no `unwrap_or_default`:
  an empty reference presented as valid data is exactly the failure
  this slice forbids.
- Dispatch: one new arm in the central view match, after Settings:
  `View::Exploration => ui::exploration::show(ui, &mut self.state),`
- Keys and rail: the `E` arm and `view_key_hint` of section 6.2.
- Texts: the four shell/widgets strings of section 6.3.
- `src/ui/settings.rs`: `LOG_TAGS` grows from 13 to 14 entries with
  `"[EXPLORE]"` inserted after `"[FITTING]"` (feature tags stay
  grouped); the keyboard line of section 6.3; the existing settings
  test gains `assert!(LOG_TAGS.contains(&"[EXPLORE]"));`.
- `README.md`: one new bullet after Fittings —
  "**Exploration**: read-only offline wormhole reference (types by
  code with destination and mass limits, J-space and special
  systems, and the six system-effect families) from bundled CCP SDE
  data. It needs no sign-in and no EVE scope, makes no network
  calls, and stores nothing. Live connection feeds, a signature
  notebook, and route planning are not implemented." — plus the
  Settings-bullet keyboard text of section 6.3, and one Not-yet line
  mirroring the existing style if the Fittings bullet pattern
  requires it.

## 10. Explicit exclusions

None of the following is implemented, stubbed with fake data, or
prepared with persistence in this slice:

- No ESI endpoints and no new EVE SSO scopes. No network at runtime
  (the only network step is Builder A's build-time extractor).
- No database schema migration and no persistence of any kind: no
  signature notebook, no notes, no saved filters or selections
  beyond in-memory `AppState` fields, no new tables, no settings
  keys beyond the existing label-based `startup_view`.
- No route planning and no jump graph: no stargates table, no
  Dijkstra, no nearest-entrance computation, no static highway list.
- No live mapping or signature tracking: no EVE-Scout feed, no
  scanner-paste import, no character location use, no connection
  state. (Scanner import was inspected only to confirm it is
  notebook persistence and therefore excluded.)
- No application of system effects to fittings or any other view
  (Product section 4.2 scope note).
- No reference-data update/repair workflow: the bundled file is the
  only source; a newer SDE means re-running the extractor and
  updating the golden invariants in the same change.
- No new window, icon, or tray work (the exploration icons already
  in `assets/icons/` are unused by this slice).

## 11. Test plan

### 11.1 Builder A — loader, golden, and fixture tests (`src/names/exploration_ref.rs`)

- `bundled_exploration_loads_and_matches_manifest`: `load_bundled`
  succeeds; parsed lengths equal `manifest.row_counts` for every
  table (the row-count/golden test that catches data truncation at
  extraction: a shortened `exploration.json` fails here even before
  semantic checks).
- `golden_invariants_from_pinned_sde`: effects = 36 unique
  (family, strength); beacon ID for each family/strength equals the
  section 3.2 table; `C729` group has 28 variants; K162 (found by
  code) has all dogma fields None; B274 has lifetime 86400 s, total
  2,000,000,000 kg, jump 375,000,000 kg, destination "Highsec";
  I078 has lifetime 16200 s and destination "Pochven"; exactly 25
  class-13 systems and every one resolves to Wolf-Rayet 6; systems
  named J005926 and J010569 resolve to Red Giant 1 and Wolf-Rayet 1;
  pulsar strength-6 capacitor-recharge-time percent is -50 and
  Wolf-Rayet strength-6 small-weapon percent is +200 (F2 oracle
  spot checks at the vector ends).
- `malformed_and_truncated_json_is_an_error_not_a_panic`:
  `from_json("{not json")` errs; a JSON document whose manifest
  claims more rows than its arrays hold errs; a document with 35
  effects errs; duplicate type IDs err; a negative mass errs.
  (Construct these by string-editing small hand-built JSON
  documents in the test, never by editing the bundled file.)
- F1/F2 fixture ports (synthetic rows built in the test, mirroring
  `exploration_fixtures.dart`): minutes-to-seconds conversion;
  capital boundary (jump mass exactly 1,000,000,000 → capital-size
  true; 999,999,999 → false); code grouping with agreeing variants
  (shared jump mass set, `jump_varies` false) and conflicting
  variants (`jump_varies` true, shared jump mass None); search
  ranking (" b274 " trims and matches B274; exact beats prefix beats
  substring); destination + capital AND on the same variant; K162
  excluded by a mass condition; the 8-row F2 security table
  (category and display for -0.01, 0, 0.0001, 0.049, 0.05,
  0.449999, 0.45, None); Thera/Pochven category is Special, not
  Nullsec; beacon-beats-visual resolution; unknown vs none effect
  states; `statics_label` with an empty table returns "Static
  information unavailable"; `apply_resonance(0.50, 50.0) == 0.25`.
- Extractor gate: Builder A's evidence includes the extractor's own
  validation output (section 4 rule 5) from the run that produced
  the committed JSON; CI coverage is the Rust golden test above, so
  a future short regeneration fails `cargo test` without needing
  Python in CI.

### 11.2 Builder B — state and view-logic tests

- `view_navigation_wraps_and_indexes` updated per section 6.1.
- Pure view functions: `sorted_groups`/`sorted_systems`/
  `sorted_effects` orderings; section filtering (destination chip
  including J-space = C1-C6; capital chip does not clear search
  text); formatters (`format_kg(None) == "Unknown"`,
  `format_kg(Some(2_000_000_000.0)) == "2,000,000,000 kg"`,
  `format_regen` suffix, `format_lifetime(Some(86400)) ==
  "86400s (1d 0h 0m)"`, `format_percent` signs).
- Demo parity: with `AppState::new(false)` and `AppState::new(true)`,
  loading the bundled reference yields the same type/system/effect
  counts (proves the data is not demo-mode-only content).

### 11.3 Integrator — shell and settings tests

- `view_key_hint` unit test: Dashboard "1", Fittings "9", Settings
  "0", Exploration "E"; all eleven hints unique.
- Settings test: `LOG_TAGS` contains "[EXPLORE]" and still contains
  every previously asserted tag.
- Startup-view label safety: every current label round-trips
  through the find-by-label restore, including the new
  "Exploration"; an unknown saved label falls back to Dashboard
  (extends the existing shell test pattern).
- Grep gate in evidence: `grep -rn "1-9" src/ README.md` returns
  only the updated lines of section 6.3.

### 11.4 Whole-slice gates (observed, not assumed)

`cargo fmt --check`, `cargo clippy --all-targets` (pedantic, per repo
configuration), `cargo test`, and `cargo build` all pass on the
integrated branch. The app is run once in demo mode and once signed
out (no characters) to confirm the view renders bundled data with no
character and no network; log excerpts show `[EXPLORE]` load counts
and no ESI traffic from this view.

## 12. File ownership summary

| Owner | Files |
|---|---|
| Builder A (data) | `scripts/sde/generate_exploration_sde.py`, `assets/sde/exploration.json` (generated), `src/names/exploration_ref.rs` (structs, loader, validation, deriver-port pure functions, all section 11.1 tests), `src/names/mod.rs` (one `pub mod` line) |
| Builder B (state + view) | `src/app/state.rs` (View append, `ExplorationData`, section/state fields, navigation test), `src/ui/exploration.rs` (view, formatters, section 11.2 tests), `src/ui/mod.rs` (one `pub mod` line). No demo edits |
| Integrator (shell) | `src/app/shell.rs` (one-time load, dispatch arm, `E` key, `view_key_hint`, rail/heading/status texts), `src/ui/widgets.rs` (one hint line), `src/ui/settings.rs` (`[EXPLORE]` in `LOG_TAGS`, keyboard line, test), `README.md` (Exploration bullet, keyboard text) |

Build order note: adding the `View` variant (Builder B) makes the
shell's view match non-exhaustive until the integrator adds the
dispatch arm, so the integrated branch is the first point where the
full binary builds; Builder A is independent throughout. No push and
no merge are part of this slice's design step.
