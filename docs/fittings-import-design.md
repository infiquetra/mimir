# EFT fitting import slice — locked design

Branch: `feat/rust-fittings-import`. Base: `develop` at
`534cb1b` (merge of PR #570). This document locks the design
for local EFT (EVE Fitting Tool text format) import in the
existing Fittings view. It extends, and never contradicts,
`docs/fittings-library-design.md` (PR #569, the read-only
saved-fittings library with EFT clipboard export).

The user pastes or types EFT-format text. Mimir parses it
locally into a structured fitting with every ship, module,
charge, drone, fighter, and cargo name resolved against
bundled SDE (Static Data Export, CCP's published game-data
dump) data, displays it honestly including per-line
problems, and can copy it back as EFT through the existing
`fitting_to_eft` exporter. The imported fitting is local
working state only: it is never written to the local
database and never sent to ESI (EVE Swagger Interface, the
EVE Online API).

## 1. Value ranking (LOCKED)

When two choices conflict, the higher rank wins. Every
locked rule below cites the rank that decided it where the
choice was not forced by an inspected body.

| Rank | Value | What it decides |
|---|---|---|
| 1 | Honesty: never silently drop, guess, or misclassify a pasted line | Per-line issue list; no slot fallback; ambiguous names unresolved; charges disclosed, never stripped quietly |
| 2 | Round-trip fidelity with the PR #569 exporter (`fitting_to_eft`) | Slot identity from bundled dogma effects, not blank-line position; cargo accepted as stacked lines; subsystems accepted |
| 3 | Offline and demo-identical behaviour | Bundled name catalogue instead of live ESI name-to-ID lookup; zero network on the import path |
| 4 | Reuse of the shipped renderer and exporter unchanged | `ImportedFitting` synthesizes a `CharacterFitting` plus a local `NameResolver`; no edits to `fitting_to_eft` or `fitting_item_rows` semantics |
| 5 | Bounded work, no panics on any input | Byte/line/quantity caps; hand-rolled parsing with checked arithmetic; no new dependencies |
| 6 | Paste convenience | Case-insensitive and whitespace-tolerant name matching; CRLF tolerated; fit names may contain commas |

## 2. Hard scope and explicit non-goals

In scope: one multiline paste box in the Fittings view, a
pure EFT parser, a bundled reverse name-to-type catalogue,
an honest parse report, display of the imported fitting,
and copy-back through the existing exporter.

Explicitly out of scope (each is a future slice if ever):

- No ESI writes of any kind. No `POST`/`PUT`/`DELETE`
  fittings endpoint, no "save to EVE" button. Flutter's
  `EsiFittingExporter`, `saveCurrentToEve`, and
  `EsiClient.saveFittingToEve` (inspected at `ed698d3`)
  must not be ported.
- No new OAuth scopes. `EveConfig::FITTINGS_SCOPES`
  (`src/config.rs:101`) stays exactly
  `["esi-fittings.read_fittings.v1"]`. Import needs no
  token and no scope.
- No simulator statistics: no DPS, tank, capacitor,
  speed, CPU, or powergrid numbers, and no physical
  validity checks (slot counts per ship, module-to-ship
  compatibility, stacking legality). The bundled catalogue
  in section 4 carries no dogma attributes, so such checks
  cannot be done honestly in this slice.
- No persistence. No new database table, no repository
  function, no settings entry. The imported fitting lives
  in `AppState` memory only (section 6).
- No other formats. Discovery at `ed698d3` found exactly
  two import formats in Flutter's fitting feature: EFT
  text and DNA links (`format_parser.dart`, 410 lines).
  Pyfa XML has no Flutter body (grep found only comments
  in simulator code), so the brief's conditional inclusion
  does not trigger. DNA is excluded by the brief's
  EFT-only slice goal; a DNA string fails the header rule
  and is reported as malformed, never guessed at.
  Superseded for DNA by `docs/fittings-dna-import-design.md`: DNA links now route to a DNA parser instead of failing the header rule; every other exclusion in this section stands.
- No file picker and no clipboard read. Flutter shipped
  paste-string import only (`saved_fittings_dialog.dart`
  at `ed698d3`); egui's text box already accepts paste.
  No new crate dependencies at all: `Cargo.toml` has no
  `regex` crate and this slice adds none.
- No editing of the imported fitting beyond re-importing
  edited text, and no rename field. The fit name comes
  from the pasted header.

## 3. Evidence base (inspected bodies)

Flutter bodies were read with `git show ed698d3:<path>`.
Dart files must never be restored into the tree.

- `lib/features/fitting/domain/format_parser.dart` at
  `ed698d3`: header regex `^\[(.*),\s*(.*)\]$`,
  `_splitEftSections`, stacked regex `^(.+?) x(\d+)$`,
  `_moduleFromEftLine`, `_resolveTypeIdByName`,
  `_normalizeName`, `generateEft`.
- `lib/features/combat_analyzer/data/aar_fit_import_parser.dart`
  at `ed698d3` (the strict AAR — After Action Report —
  adapter): explicit empty-slot placeholder set, category
  constants (ship 6, module 7, subsystem 32, drone 18,
  fighter 87), resource limits (256 KiB, 4,096 expanded
  modules, signed-32-bit quantities), full-table exact
  name index (`_loadNameIndex`, `_uniqueName`), trimmed
  header groups, quantity rule `^[1-9][0-9]*$`, comma
  rejection for loaded ammunition.
- `lib/core/sde/sde_service.dart` at `ed698d3`:
  `_slotTypeFor` maps dogma effect IDs to slots in check
  order 12 high, 13 medium, 11 low, 2663 rig,
  3772 subsystem.
- `lib/core/sde/sde_database.dart` at `ed698d3`:
  `searchTypesByName` is a substring `LIKE '%query%'`
  with a caller limit; the base parser passes limit 20,
  which can miss an exact name (the bug the AAR
  full-table index exists to avoid).
- `test/features/fitting/domain/format_parser_test.dart`
  and `test/features/combat_analyzer/data/aar_fit_import_parser_test.dart`
  plus fixtures at `ed698d3` (the oracle cases ported in
  section 12; expected type IDs from Flutter's seeded
  test database are not real SDE IDs and must not be
  copied — section 12 gives the verified real ones).
- Current Rust: `src/ui/fittings.rs` (sections at
  lines 24-91, sanitizers 93-120, `fitting_item_rows`
  163-198, `fitting_to_eft` 219-402,
  `MAX_EFT_SLOT_REPEATS` = 16 at line 22,
  `FITTINGS_RENDER_MAX` = 100 at line 16, `show`
  449-614); `src/app/state.rs` (`FittingsData` 381-391
  with the do-not-add-fields contract at 377-380,
  fittings UI fields 624-626, `set_active_character`
  736-819, `remove_character` 842-902);
  `src/esi/models.rs` (`CharacterFitting` 698-710,
  `FittingItem` 717-725); `src/names/sde.rs`
  (skills-only: `load_bundled` 65-68, 495 types,
  category 16 only — it cannot resolve ships, modules,
  charges, drones, or cargo, which is the gap section 4
  closes); `src/names/resolver.rs` (`insert` rejects
  empty or purely numeric names, 84-99);
  `src/esi/endpoints.rs:703` (`resolve_ids`, the public
  `POST /universe/ids/` name-to-ID precedent, rejected
  for this slice in section 4.1); `src/app/shell.rs`
  (bundled-load pattern at 394-403, fittings view call
  at 2450, `MimirApp` fields 95-107);
  `src/storage/repositories.rs:859`
  (`search_universe_names`, substring `LIKE` — the wrong
  tool for import, it would guess);
  `src/ui/settings.rs:16` (`[FITTING]` already in
  `LOG_TAGS`); `assets/demo/fittings.json` and
  `assets/demo/names.json` (demo type 2048 is named
  "Demo Small Railgun" while real SDE 2048 is Damage
  Control II — the mismatch that forces the local
  resolver in section 5.3).
- Bundled data on disk, probed directly:
  `assets/sde/dogma.json` (12 MB, 14,941 types in
  categories 6/7/8/11/16/18/20/22/32/87, never loaded by
  Rust) and the Fuzzwork CSV caches
  `scripts/sde/invTypes.csv.bz2` (50,235 rows, 25,818
  published), `scripts/sde/invGroups.csv.bz2`,
  `scripts/sde/dgmTypeEffects.csv.bz2`. Verified facts
  used below: Rifter is type 587 category 6; Damage
  Control II is 2048, category 7, effect 11; Small
  Armor Repairer II is 1183, category 7, effect 11;
  1MN Afterburner II is 438, category 7, effect 13;
  Warp Scrambler II is 448, category 7, effect 13;
  200mm AutoCannon II is 2889, category 7, effect 12;
  Small Projectile Burst Aerator I is 31668,
  category 7, effect 2663; Hobgoblin II is 2456,
  category 18; EMP S is 185, category 8; Republic Fleet
  EMP S is 21898, category 8; Nanite Repair Paste is
  28668, category 8; Legion is 29986, category 6;
  "Legion Core - Augmented Antimatter Reactor" is 45623,
  category 32, effect 3772; Templar II is 40556,
  category 87; Tritanium is 34, category 4. No published
  ship name contains `,`, `[`, or `]`; no published type
  name ends in ` x<digits>`; no published type name is
  purely numeric; 17 published names contain a comma
  (none of them ships); exactly 12 normalized published
  names are duplicated (SKINs and crates) and therefore
  ambiguous under section 4 rules.
- Context library `platform-specs/03-feature-modules/fitting/specification.md`:
  a draft sketch parser only (header regex, `name,
  charge` split, `xN` suffix, `[Empty ` skip). It is
  evidence that the `Module, Charge` shape was intended
  product behaviour, never a grammar contract. Grammar
  is grounded in the Flutter bodies above, not here.

## 4. Name resolution: the bundled fitting-types catalogue

### 4.1 Why a new bundled catalogue (LOCKED)

The brief requires reverse lookup from the bundled SDE.
The existing Rust `Sde` (`src/names/sde.rs`) is a
skills-only extract with no ship, module, charge, drone,
fighter, or cargo types, no categories for them, and no
effect data — it cannot answer any import question. The
Market precedent (`resolve_ids`, public
`POST /universe/ids/`) returns only name-to-ID: it cannot
say which slot a module fits or whether a name is a ship,
so it cannot classify lines, and it needs the network,
which breaks the demo story (ranking 3). Slot identity
must come from dogma effects as it did in Flutter
(`sde_service.dart` `_slotTypeFor`), because the PR #569
exporter omits empty sections, so blank-line position
cannot recover slots on re-import (ranking 2).

Therefore this slice ships one new bundled extract:

- `assets/sde/fitting_types.json`, generated offline by
  a new script `scripts/sde/generate_fitting_types_sde.py`
  (name follows `generate_dogma_sde.py`,
  `generate_exploration_sde.py`,
  `generate_industry_sde.py`). The generator reads only
  the committed caches `invTypes.csv.bz2`,
  `invGroups.csv.bz2`, and `dgmTypeEffects.csv.bz2`
  under `scripts/sde/`, never the network, and fails
  loudly if a cache file is missing.
- Row rule: `published == 1`, `typeID > 0`, `typeName`
  non-empty after stripping. All categories are kept
  (cargo can be any inventory type; Tritanium category 4
  must resolve). `categoryId` is denormalized from
  `invGroups`; a type whose group is missing keeps
  `categoryId` 0 (it can then only ever classify as
  cargo or not-a-module, never as a ship or module) and
  the generator prints the count of such rows.
- `slotEffects` per type: the sorted, de-duplicated
  subset of its `dgmTypeEffects` rows in
  {11, 12, 13, 2663, 3772}.
- Output is deterministic: types sorted by `typeId`,
  `json.dump` with `separators=(",", ":")`, no
  timestamps. Shape:
  `{"types":[{"typeId":…,"typeName":…,"categoryId":…,"slotEffects":[…]},…]}`
  (camelCase keys match `assets/sde/skills.json`).
  Expected size at the current caches: 25,818 types,
  about 2.5 MB. The generator prints type count and
  duplicate-normalized-name count. Builder A runs it and
  commits both script and generated file; the file is
  never hand-edited.
- The 12 MB `assets/sde/dogma.json` is not loaded or
  parsed at runtime; it stays as-is.

### 4.2 Rust catalogue API (LOCKED, Builder A)

New file `src/names/fitting_types.rs`, mirroring the
`Sde::load_bundled` / `from_json` pattern:

```rust
pub struct FittingType {
    pub type_id: i64,        // serde "typeId"
    pub name: String,        // serde "typeName"
    pub category_id: i64,    // serde "categoryId"
    pub slot_effects: Vec<i64>, // serde "slotEffects"
}

pub enum NameLookup<'a> {
    Found(&'a FittingType),
    Unknown,
    Ambiguous,
}

impl FittingTypes {
    pub fn load_bundled() -> AppResult<Self>; // include_str! assets/sde/fitting_types.json
    pub fn from_json(json: &str) -> AppResult<Self>;
    pub fn lookup(&self, name: &str) -> NameLookup<'_>;
    pub fn type_count(&self) -> usize;
}

pub fn normalize_type_name(name: &str) -> String;
```

Rules:

- `normalize_type_name` is the Flutter `_normalizeName`
  rule: trim, collapse every whitespace run to one
  space, lowercase. Rust form:
  `name.split_whitespace().collect::<Vec<_>>().join(" ").to_lowercase()`.
  `split_whitespace` uses the Unicode White_Space
  property, so tabs and non-breaking spaces collapse
  too. Matching is exact on the normalized form:
  case-insensitive, never substring, prefix, fuzzy, or
  alias-based (Flutter has no alias table — not found).
- `FittingTypes` builds a full-table
  `HashMap<String, Vec<usize>>` from normalized name to
  type rows, de-duplicated by `type_id` (the AAR
  `_loadNameIndex` semantics). The base Flutter
  20-row substring search must not be replicated.
  `lookup` returns `Found` only when exactly one
  distinct `type_id` matches; zero is `Unknown`; more
  than one is `Ambiguous` (AAR `_uniqueName`,
  single-ID-only). An ambiguous name is never resolved
  to its first match.
- `from_json` skips rows with `type_id <= 0` or empty
  name, logs the skip count once with `[FITTING]`, and
  returns `Err` when no usable rows remain (the
  Exploration precedent: an empty catalogue presented
  as valid is the failure this forbids). Malformed
  JSON is `Err`, never a panic.
- The canonical display name of a resolved item is
  always the catalogue `typeName`, never the pasted
  spelling. A paste of `damage  control ii` displays
  and re-exports as `Damage Control II`.
- Category constants live in the parser (section 5),
  not here: ship 6, module 7, charge 8, drone 18,
  subsystem 32, fighter 87 (AAR constants at
  `aar_fit_import_parser.dart:57-61` plus charge 8 from
  `generate_dogma_sde.py` `TARGET_CATEGORIES` and the
  `dogma.json` categories list).

## 5. The EFT grammar (LOCKED)

Parser home: new pure module `src/fitting/` with
`src/fitting/mod.rs` and `src/fitting/eft.rs`, exposing
`parse_eft(text: &str, types: &FittingTypes) ->
EftImportOutcome`. No egui, no `AppState`, no network,
no database. `src/lib.rs` gains `pub mod fitting;`.
There is no `features/` tree in `src/`, so a top-level
`fitting` module matches the existing layout.

### 5.1 Pre-processing and line model

1. Enforce resource bounds (section 7) on the original
   string first.
2. Normalize line endings the AAR way: replace `\r\n`
   with `\n`, then lone `\r` with `\n`. CRLF pastes are
   a Flutter fixture case and must import. Rust
   `str::lines` alone would miss lone-`\r` separators.
3. Split on `\n` and number every resulting line from
   1, blank lines included, so report line numbers match
   what the user sees in the text box.
4. Trim each line with `str::trim` (Flutter trims every
   line in `parseEft`). Blank-after-trim lines are
   ignored entirely. Blank lines carry no meaning in
   this parser — see the section-inference lock in 5.4.
5. There is no comment syntax. No inspected body
   defines one, so a `# …` or `// …` line is an
   ordinary body line and will normally be reported as
   an unknown name. Recorded choice, per the brief's
   honest-behaviour rule.

### 5.2 Header

- The header is the first non-blank line. It must start
  with `[`, end with `]`, and contain a comma;
  otherwise the import fails fatally (section 5.7).
- Split the inner text at the **first** comma. Left of
  it, trimmed, is the ship name; right of it, trimmed,
  is the fitting name. This is a deliberate divergence
  from Flutter's greedy regex `^\[(.*),\s*(.*)\]$`
  (split at the *last* comma, groups untrimmed in the
  base parser, trimmed in AAR). Justification, from
  inspected data: no published ship name contains a
  comma, and the exporter strips commas from ship
  names (`sanitize_header_name`, `src/ui/fittings.rs:105-111`,
  applied at line 227), so a comma inside the ship part
  can never round-trip; splitting at the first comma
  preserves fit names that legitimately contain commas
  and colons (`[Rifter, PvP: Armor]`, a Flutter AAR
  fixture, keeps fit name `PvP: Armor`).
- An empty ship name after trimming is fatal
  `HeaderMalformed`. An empty fitting name is allowed
  and later displayed through the existing
  `fitting_display_name` fallback ("Unnamed fitting",
  `src/ui/fittings.rs:113-120`), exactly as saved
  fittings are.
- The ship name must resolve through
  `FittingTypes::lookup` to exactly one type with
  `category_id == 6`. Unknown, ambiguous, and non-ship
  headers are three distinct fatal outcomes (section
  5.7). This follows AAR (category-6 hull check) and
  rejects the base Flutter behaviour of continuing with
  `shipTypeId = 0`, which would render an unresolved
  ship. Nothing is imported when the header fails:
  a fitting without a known hull can neither render
  honestly nor export (`fitting_to_eft` returns `None`
  for an unresolved ship, lines 220-230).
- Header-only input (`[Rifter, Test]` with no body) is
  a valid empty fitting (Flutter AAR oracle T05).

### 5.3 Body line classification (LOCKED precedence)

Each non-blank body line is classified by the first
matching step. A line either contributes exactly as
specified, is an ignored placeholder, or produces
exactly one `ImportIssue` (section 5.6). There is no
silent drop anywhere (ranking 1). The invariant
`imported_lines + placeholder_lines + issues.len() ==
non-blank body lines` holds for every outcome and is
pinned by a test.

1. **Empty-slot marker.** If the trimmed line is
   exactly one of `[Empty Low slot]`, `[Empty Med
   slot]`, `[Empty High slot]`, `[Empty Rig slot]`,
   `[Empty Subsystem slot]` (case-sensitive; the AAR
   `_placeholders` set verbatim), it is ignored and
   counted as a placeholder line. The base Flutter
   blanket skip of every `[`-led line must not be
   replicated.
2. **Bracketed line.** Any other line starting with
   `[` (including a second header) is issue
   `BracketedLine`.
3. **Charge line.** If the line contains a comma, it
   is a `Module, Charge` line and never a stacked
   line. Split at the first comma; both parts trimmed.
   A second comma, an empty module part, or an empty
   charge part is issue `MalformedChargeLine`. The
   module part resolves and classifies exactly as a
   plain module line (step 5, including
   `NotAModule` and `NoSlotForModule`). The charge
   part resolves by the same lookup: `Unknown` is
   issue `UnknownCharge`, `Ambiguous` is
   `AmbiguousCharge`, a resolved type with
   `category_id != 8` is `NotACharge`. Any charge
   failure means the whole line contributes nothing
   (the module is not imported without its charge —
   a line that could not be fully resolved must not
   half-import). On success the module is imported
   with quantity 1 and its loaded charge stored on
   the item (section 6.1). Grounding: the base
   Flutter parser splits on comma and silently drops
   the charge; AAR rejects the whole fit; the context
   spec sketch keeps the charge; Flutter's
   `FittedModule` model carries `chargeTypeId` /
   `chargeName` (`models.dart:66-67`). Storing the
   resolved charge for display, and disclosing that
   copy-back omits it (sections 6.3, 8), is the
   honest middle the brief's "every charge name
   resolved" requires. A stacked suffix inside a
   charge line (`Module x2, Charge`) is part of the
   module name as written and will normally be
   `UnknownName` — deterministic, recorded.
4. **Stacked line.** The line matches the Flutter
   stacked form `^(.+?) x(\d+)$`. Without regex: find
   the last ` x` in the trimmed line; the suffix
   after it must be non-empty ASCII digits only and
   the part before must be non-empty. (Last-` x` is
   equivalent to the lazy regex: only the last
   candidate can have an all-digits tail.) If the
   suffix shape fails, the line is not stacked and
   falls to step 5. Quantity rules (AAR-strict):
   the first digit must be `1`-`9` (so `x0` and `x05`
   are issue `InvalidQuantity`; the base parser's
   acceptance of `x0` is not replicated), the digit
   string is at most 10 characters, and the value is
   at most `MAX_STACK_QUANTITY` = 2,147,483,647 (the
   AAR signed-32-bit cap); anything else is
   `InvalidQuantity`. The name part then resolves:
   `Unknown` → `UnknownName`, `Ambiguous` →
   `AmbiguousName`. Classification by category:
   18 → Drones, 87 → Fighters (the Flutter
   `absorbStackedLine` rule), 7 or 32 →
   `StackedModule` (modules are listed once per slot;
   Flutter silently dropped these, AAR rejected them),
   anything else → Cargo. Cargo-by-exclusion is the
   exact inverse of the exporter, which emits every
   Cargo-flagged saved item as `Name xTotal`
   (`src/ui/fittings.rs:331-371`); Flutter dropped
   cargo stacks silently, which rankings 1 and 2
   forbid here. Stacked lines of the same `type_id`
   in the same section merge by summing, keeping
   first-appearance order (the Flutter drone/fighter
   merge rule, extended to cargo so re-export through
   the aggregating exporter is stable). A line whose
   merge would push a total past `MAX_STACK_QUANTITY`
   is issue `QuantityTooLarge`; earlier lines stand.
5. **Plain line.** The whole trimmed line resolves by
   lookup. `Unknown` → `UnknownName`, `Ambiguous` →
   `AmbiguousName`. A resolved type classifies as:
   category 7 or 32 → module, section from slot
   effects (5.4); no slot effect →
   `NoSlotForModule`. Any other category →
   `NotAModule` (a plain drone, charge, ship, or
   mineral line needs the stacked form; Flutter's
   fallback of treating it as a high-slot module is
   a misclassification and is not replicated).
   Each imported plain line is one fitted slot with
   quantity 1; repeated lines are repeated slots and
   are never merged.

Item order inside the imported fitting is contribution
order (merged stacks sit at first appearance). Imported
items store the canonical catalogue name.

### 5.4 Slot inference (LOCKED)

Slot comes only from the type's `slotEffects`, checked
in Flutter `_slotTypeFor` order: 12 → High, 13 →
Medium, 11 → Low, 2663 → Rig, 3772 → Subsystem. The
first present effect in that check order wins (the
order matters only for a hypothetical multi-slot-effect
type).

Two Flutter behaviours are deliberately not replicated,
each recorded here:

- **No blank-line section fallback.** Base Flutter
  assigns fallback slots by blank-line section position
  (0 low, 1 med, 2 high, 3 rig, 4+ high) for modules
  whose SDE slot is unknown. In practice the effect
  slot overrode the fallback for every resolved module,
  so position mattered only when guessing. The PR #569
  exporter omits empty sections, so position cannot
  survive a round-trip (a med-only fit exports its med
  section first). Ranking 2 over 6: section position
  is never consulted; a module lands in its own slot
  wherever the line appears, and a module with no slot
  effect is `NoSlotForModule`, never guessed into a
  section.
- **No fallback-to-high.** `_slotTypeFor` returns high
  when no effect matches. That is a guess; replaced by
  `NoSlotForModule` above.

Subsystems are accepted (category 32 or effect 3772 →
Subsystem section), diverging from Flutter's EFT path
which silently dropped subsystem-slot modules
(`format_parser.dart` `case SlotType.subsystem: break`)
while its DNA path kept them. The Rust exporter emits a
Subsystem section, so acceptance is required for
round-trip (ranking 2).

No per-section slot-count validation exists. The
catalogue carries no ship slot layout, so Mimir cannot
honestly say a Rifter paste has too many low slots;
nine low-slot lines import as nine low slots. This is
the no-simulator scope line in section 2, stated in
the UI copy in section 8 by omission: import never
claims a fit is flyable.

### 5.5 What each section means in the parser

The parser's own section enum is named `ImportSection`
with variants `Low, Medium, High, Rig, Subsystem,
Drones, Fighters, Cargo`, independent of
`crate::ui::fittings::FittingSection` so the pure
parser never depends on the UI module. Section 6 maps
it onto ESI flags for the existing renderer.

### 5.6 Per-line reporting model (LOCKED)

```rust
pub struct ImportIssue {
    pub line: usize,          // 1-based, blank lines counted
    pub text: String,         // the trimmed original line
    pub kind: ImportIssueKind,
}

pub enum ImportIssueKind {
    UnknownName,
    AmbiguousName,
    BracketedLine,
    InvalidQuantity,
    QuantityTooLarge,
    StackedModule,
    NotAModule,
    NoSlotForModule,
    MalformedChargeLine,
    UnknownCharge,
    AmbiguousCharge,
    NotACharge,
}
```

`ImportIssueKind::reason(&self) -> &'static str` has
fixed wording, the complete list:

| Kind | Fixed reason text |
|---|---|
| `UnknownName` | `no item in Mimir's bundled data has this exact name` |
| `AmbiguousName` | `this name matches more than one item in Mimir's bundled data` |
| `BracketedLine` | `bracketed lines other than empty-slot markers are not part of a fitting` |
| `InvalidQuantity` | `the quantity must be a whole number from 1 to 2,147,483,647, written like x5` |
| `QuantityTooLarge` | `the combined quantity for this item would exceed 2,147,483,647` |
| `StackedModule` | `modules are listed once per fitted slot, without a quantity suffix like x5` |
| `NotAModule` | `this item is not a fitted module; drones, fighters, and cargo need a quantity suffix like x5` |
| `NoSlotForModule` | `Mimir's bundled data does not say which slot this module fits` |
| `MalformedChargeLine` | `a fitted module line may name one loaded charge, like Module Name, Charge Name` |
| `UnknownCharge` | `the loaded charge after the comma has no exact match in Mimir's bundled data` |
| `AmbiguousCharge` | `the loaded charge after the comma matches more than one item in Mimir's bundled data` |
| `NotACharge` | `the name after the comma is not a charge` |

Reasons never contain type IDs, category IDs, effect
IDs, or flag strings. The echoed `text` is the user's
own pasted line (required by the brief); it is user
text, not a rendered EVE ID.

The parse report rides on the imported fitting:

```rust
pub struct ImportReport {
    pub imported_lines: usize,
    pub placeholder_lines: usize,
    pub charges_noted: usize, // imported lines that carried a stored charge
    pub issues: Vec<ImportIssue>,
}
```

### 5.7 Fatal outcomes (LOCKED)

`EftImportOutcome::Failed(ImportFatal)` means no
fitting at all. `ImportFatal::message(&self) -> &'static
str` wording is fixed and complete:

| Variant | Trigger | Exact message |
|---|---|---|
| `Empty` | No non-blank lines | `Paste an EFT fitting first - the import box is empty.` |
| `TooLarge` | Input over `MAX_EFT_IMPORT_BYTES` | `That paste is too large to import (limit 64 KiB). Nothing was imported.` |
| `TooManyLines` | Input over `MAX_EFT_IMPORT_LINES` | `That paste has too many lines to import (limit 1,000 lines). Nothing was imported.` |
| `HeaderMalformed` | First non-blank line fails 5.2 shape, or empty ship name | `Could not import: the first line must look like [Ship name, Fitting name]. Nothing was imported.` |
| `ShipUnknown` | Ship lookup `Unknown` | `Could not import: Mimir's bundled data has no ship with that exact name. Nothing was imported.` |
| `ShipAmbiguous` | Ship lookup `Ambiguous` | `Could not import: that ship name matches more than one item in Mimir's bundled data. Nothing was imported.` |
| `ShipNotShip` | Ship resolves but `category_id != 6` | `Could not import: the first name in the header is not a ship. Nothing was imported.` |

Catalogue load failure never reaches the parser; it is
a UI state with its own fixed sentence in section 8.

A fitting whose body lines all fail is still a
successful import of an empty fitting with a full issue
list (header-only is valid, so all-failed-body is the
same shape with reasons attached). It is never
upgraded to a fatal.

## 6. Data model (LOCKED)

### 6.1 `ImportedFitting` (new, parser-owned)

```rust
pub struct ImportedCharge {
    pub type_id: i64,
    pub name: String, // canonical catalogue name
}

pub struct ImportedItem {
    pub type_id: i64,
    pub name: String, // canonical catalogue name
    pub section: ImportSection,
    pub quantity: i64, // always 1 for slot sections; merged total for Drones/Fighters/Cargo
    pub charge: Option<ImportedCharge>, // Some only on imported charge lines
}

pub struct ImportedFitting {
    pub name: String,      // header fitting name, trimmed, may be empty
    pub ship_type_id: i64, // > 0, category 6 (5.2 guarantees)
    pub ship_name: String, // canonical catalogue name
    pub items: Vec<ImportedItem>,
    pub report: ImportReport,
}
```

All parser types derive `Debug, Clone, PartialEq`
(items) / `Debug, Clone` (fitting, report) so they can
live in `AppState` (which derives `Debug`) and be
asserted on in tests.

Reusing `CharacterFitting` alone was rejected from the
inspected renderer: it has no charge field, no report,
and its items carry ESI flags the parser should not
invent as its primary model. The synthesis below gives
renderer and exporter reuse without losing the charge
or the report.

### 6.2 Synthesis for the existing renderer and exporter

`ImportedFitting::to_character_fitting(&self) ->
CharacterFitting` (locked mapping, charges excluded):

- `fitting_id: -1` (ESI IDs are positive; `-1` can
  never equal a saved fitting's ID, and the imported
  fitting is never placed in the saved list anyway).
- `name`: the header name as stored. `description:
  None`. `ship_type_id`: as parsed.
- Items in stored order, one `FittingItem` per
  `ImportedItem`. Flag by section with a per-section
  0-based counter in item order: Low → `LoSlot{n}`,
  Medium → `MedSlot{n}`, High → `HiSlot{n}`, Rig →
  `RigSlot{n}`, Subsystem → `SubSystemSlot{n}` (the
  ESI vocabulary `section_for_flag` already whitelists,
  `src/ui/fittings.rs:36-54`); Drones → `DroneBay`,
  Fighters → `FighterBay`, Cargo → `Cargo`.
- `quantity`: 1 for slot sections, merged total for
  stacked sections. `type_id`: as parsed.

With this synthesis, `fitting_item_rows` and
`fitting_to_eft` work **unchanged** — no signature or
semantics edits to either function, and all 30+
existing `src/ui/fittings.rs` tests keep passing
untouched. The one named minimal change in
`src/ui/fittings.rs` is a behaviour-preserving extract:
the selected-fitting item-section rendering loop
(lines 541-572 today) becomes
`fn render_fitting_items(ui: &mut egui::Ui, item_rows:
&[FittingItemRow])` called by both the saved detail
and the imported detail, so the two can never drift.

### 6.3 The local resolver (LOCKED)

`ImportedFitting::name_resolver(&self) -> NameResolver`
builds a fresh `NameResolver` and inserts the ship,
every item, and every stored charge by `type_id` with
canonical names. The imported detail and its copy
button run against this local resolver, never the app
resolver. This is forced by two inspected facts: the
app resolver in live mode may not know the imported
types yet (only saved-fitting IDs are scheduled for
resolution, `src/app/shell.rs:670-683`), so
`fitting_to_eft` against it would silently skip
everything as unknown; and the demo resolver renames
real types to demo fiction (2048 → "Demo Small
Railgun"), which would mislabel a pasted Damage
Control II. Building the local resolver is O(items)
per frame (at most 999 inserts by section 7 bounds);
Builder B may instead build it once per render of the
imported detail — that is the same thing; no caching
field is added. `NameResolver::insert` drops purely
numeric names (lines 84-99); verified no published
type name is purely numeric, and a catalogue test in
section 12 pins that so a future SDE refresh cannot
silently break the synthesis.

## 7. Resource bounds and no-panic rules (LOCKED)

Constants, defined in `src/fitting/eft.rs`:

| Constant | Value | Grounding |
|---|---|---|
| `MAX_EFT_IMPORT_BYTES` | 65,536 (64 KiB) | AAR caps at 256 KiB; a real EFT block is well under 4 KiB, and 64 KiB bounds every downstream allocation. Base Flutter had no cap — not replicated |
| `MAX_EFT_IMPORT_LINES` | 1,000 | Bounds imported items to at most 999, so no separate item cap is needed; the render cap (`FITTINGS_RENDER_MAX` 100 per section, with disclosure) already governs display |
| `MAX_STACK_QUANTITY` | 2,147,483,647 | AAR `maxQuantity` (signed 32-bit) verbatim |

Bounds are checked before any parsing (`TooLarge` on
`text.len()`, `TooManyLines` on the post-CR-normalize
split count). The user's text is never truncated to
fit: over-limit input is refused whole, text box
contents untouched.

Quantity expansion consistency: the parser never
expands stacked quantities into per-unit rows, and slot
items always carry quantity 1 into synthesis, so the
exporter's `MAX_EFT_SLOT_REPEATS` = 16 cap
(`src/ui/fittings.rs:22`) is never engaged by imported
data — an imported fitting re-exports every imported
slot line exactly once and stacked totals verbatim.
Total clipboard output from an imported fitting is
bounded by 999 item lines plus header by construction.

No-panic implementation rules for `src/fitting/eft.rs`
and `src/names/fitting_types.rs`:

- No `unwrap`/`expect`/indexing on user-derived data in
  non-test code. String slicing only at boundaries
  returned by `find(',')`, `rfind(" x")`,
  `strip_prefix('[')`, and `strip_suffix(']')` (all
  ASCII delimiters, always char-boundary safe).
- Quantity parsing: reject digit strings longer than
  10 characters before parsing, parse with checked
  conversion to `i64`, compare against the cap. A
  100-digit quantity is `InvalidQuantity`, never an
  overflow.
- All count arithmetic uses `saturating_add` or the
  explicit cap comparisons in 5.3.
- Any `&str` is valid input: empty, whitespace-only,
  NUL bytes and other control characters (they survive
  `trim` only at line edges; interior controls simply
  fail lookup as `UnknownName`), lone brackets,
  commas-only lines, emoji and other multi-byte
  Unicode in names or the header (header ship lookup
  fails honestly as `ShipUnknown`), and lines of
  65,536 bytes of one repeated character. Section 12
  pins an adversarial corpus that must return an
  outcome — never panic, never hang.

## 8. State and UI (LOCKED)

### 8.1 State fields (Builder B, `src/app/state.rs`)

`FittingsData` must not gain fields (do-not-add-fields
contract at `src/app/state.rs:377-380`; shell and demo
construct it literally). Four view-local fields go
beside `fittings_search` / `fittings_selected_fitting_id`
(lines 624-626), all free by `AppState`'s `Default`
derive:

```rust
pub fittings_import_text: String,
pub fittings_imported: Option<ImportedFitting>,
pub fittings_import_error: Option<String>,
pub fittings_import_owner: Option<i64>,
```

State transitions:

- **Import clicked** (view, synchronous pure parse; no
  request flag, no fetch): on `Imported`, set
  `fittings_imported`, clear `fittings_import_error`,
  stamp `fittings_import_owner` with the active
  character ID. On `Failed`, clear
  `fittings_imported` (a stale earlier import must not
  linger under a new failure), set
  `fittings_import_error` to the fixed message, stamp
  owner the same way. The paste text is left untouched
  either way so the user can fix lines and re-import.
- **Clear clicked**: text, imported, error, and owner
  all cleared.
- **Character switch to a different ID**
  (`set_active_character`, in the existing
  different-ID block beside the fittings reset at
  lines 808-814): imported, error, owner, **and text**
  cleared. The imported fitting is local working state
  shown inside a per-character view; carrying it across
  would present it as the new character's working fit.
  Same-character reselect keeps everything (the
  existing early-keep path).
- **Removal of the active character**
  (`remove_character`, beside lines 870-872) and
  **empty roster** (beside lines 898-899): same four
  cleared. Removal of a non-active character keeps
  import state (owner is the active character, who did
  not change).
- **Refresh/merge**: shell refresh and the fittings
  merge never touch import fields. The imported
  fitting is never inserted into `FittingsData`, never
  written through any repository, never scheduled for
  ESI name resolution, and
  `fittings_selected_fitting_id` is never set to `-1`
  or any imported identity. Selecting a saved fitting
  does not clear the imported one; both details can be
  on screen (imported above the saved list, per 8.2).
- **Demo**: identical behaviour. The catalogue is
  offline, so demo import needs no network and no
  demo-data special case beyond the sample button
  (8.3).
- **Render guard**: the imported detail renders only
  when `fittings_import_owner ==
  state.active_character_id` (both `Some`). The resets
  make this an invariant; the guard is
  defense-in-depth, and state tests pin the resets.

### 8.2 The import panel (Builder B, `src/ui/fittings.rs`)

`show` today takes `(ui, state, resolver)` and returns
early for no character, step-up, and empty saved list.
Locked placement: after `widgets::mode_notice` and the
active-character check, **before** the `LoadState`
match, call a new `fittings_import_panel(ui, state,
catalogue)`, then `ui.separator()`, then the existing
match unchanged. Import is therefore reachable while
saved fittings load, fail, or await a step-up grant —
it needs no ESI read scope, and hiding it behind the
fittings step-up would be a false coupling. The
signature becomes `show(ui, state, resolver,
fitting_types: Option<&FittingTypes>)` (integrator
updates the call site, section 10).

Panel contents, top to bottom, with exact strings:

1. Heading: `Import a fitting from EFT text`.
2. Helper label, always shown:
   `Paste an EFT block (the [Ship, Fitting name] text format). The imported fitting stays in Mimir on this device: it is not saved to EVE and is gone when you switch characters or close Mimir.`
3. When `fitting_types` is `None`, instead of the text
   box and buttons, exactly:
   `Could not import: Mimir's bundled item data failed to load. Restart Mimir and try again.`
4. `egui::TextEdit::multiline(&mut
   state.fittings_import_text)` with
   `.hint_text("Paste EFT text: [Ship, Fitting name] then one item per line")`,
   `.desired_rows(8)`, `.desired_width(f32::INFINITY)`.
   Focus bookkeeping mirrors the existing search box:
   `state.text_input_focused |= response.has_focus()`.
   The text is never truncated by the view; bounds are
   enforced at parse time with the section 5.7
   messages.
5. Button row:
   - `Import fitting`, enabled when the text is
     non-blank (`!fittings_import_text.trim().is_empty()`).
   - `Clear import`, enabled when text is non-empty
     or an imported fitting or error is present.
   - `Use sample EFT`, shown only when `state.demo`
     is true (8.3): replaces the text with the sample
     and clears imported/error/owner (the user still
     clicks Import, so the demo shows the same flow
     as live use).
6. Fatal error label when `fittings_import_error` is
   set: the message verbatim, nothing else.
7. Imported detail when an imported fitting is
   present and passes the owner guard:
   - Summary line, exact template:
     `Imported "{display_name}" ({ship_name}): {item_count} items from {imported_lines} lines.`
     where `display_name` is `fitting_display_name`
     of the header name, `item_count` is
     `items.len()` (merged stacks count once, the
     existing `FittingRow::item_count` convention),
     and `imported_lines` is from the report.
   - Label: `Imported fitting (not saved in EVE)`.
   - When `placeholder_lines > 0`:
     `1 empty-slot marker ignored.` /
     `{n} empty-slot markers ignored.`
   - When `charges_noted > 0`:
     `1 loaded charge is listed below the items. It is not included when you copy this fitting as EFT.` /
     `{n} loaded charges are listed below the items. They are not included when you copy this fitting as EFT.`
   - Item sections through the extracted
     `render_fitting_items` on rows from
     `fitting_item_rows(&synth, &local_resolver)`.
     An empty fitting shows the existing sentence
     `This fitting has no items to show.` (the same
     branch the extracted helper's caller already has
     for saved fittings — reuse it, do not reword).
   - Loaded-charges list when any item carries a
     charge: heading `Loaded charges`, then one row
     per charged item in item order,
     `{module_name} - {charge_name}` (canonical
     names), capped by `FITTINGS_RENDER_MAX` with the
     existing `Showing {shown} of {total} items.`
     disclosure label shape used by sections.
   - Issues when the report has any: heading
     `1 line could not be imported:` /
     `{n} lines could not be imported:`, then up to
     `IMPORT_ISSUES_RENDER_MAX` = 20 (new constant in
     `src/ui/fittings.rs`) rows, exact template:
     `Line {line}: "{text}" - {reason}.`
     `text` is truncated for display at 120
     characters: take `chars().take(120)`, append
     `...` if the line was longer. Over the cap,
     exactly:
     `...and {remaining} more lines that could not be imported. Fix the lines above and import again to see the rest.`
     (singular: `...and 1 more line that could not be
     imported. Fix the lines above and import again to
     see the rest.`)
   - `Copy imported fitting as EFT` button (label is
     distinct from the saved fitting's `Copy as EFT`
     so two copy buttons on screen are unambiguous).
     It runs `fitting_to_eft(&synth, &local_resolver)`.
     The `None` arm is unreachable by construction
     (the local resolver always knows the ship) but is
     handled by logging a `[FITTING]` warning and
     reusing the saved-fitting sentence verbatim:
     `That fitting cannot be copied yet: its ship name has not loaded. Refresh and try again.`
     On success, `ui.ctx().copy_text(export.text)` and
     status message by case:
     - no charges, no skips:
       `Copied "{display_name}" as EFT` (the existing
       saved-fitting template).
     - `charges_noted == 1`:
       `Copied "{display_name}" as EFT (1 loaded charge left out: copied EFT fittings do not store loaded charges)`
     - `charges_noted > 1`:
       `Copied "{display_name}" as EFT ({n} loaded charges left out: copied EFT fittings do not store loaded charges)`
     Exporter `skipped_unknown`/`skipped_empty` are 0
     by construction against the local resolver; if
     that invariant is ever violated, the status
     message appends nothing (the charge wording wins)
     and the counts go to the `[FITTING]` info log
     exactly like the saved-fitting copy log at lines
     600-606. Builder B asserts the zero invariant in
     a round-trip test (section 12) rather than in
     user-facing copy.

All template substitutions are counts, canonical
names, or sanitized display names. No type ID,
category ID, effect ID, `fitting_id`, or flag string
is ever rendered. Pasted line echoes in issue rows are
the user's own text (5.6).

Logging (`[FITTING]` only, no new tag): import click
logs input byte and line counts only — never the
pasted text (base Flutter logged the whole EFT string;
not replicated). Success logs counts
(items/issues/placeholders/charges). Failure logs the
`ImportFatal` variant name via `{:?}`, never user
text. Catalogue load logs its type count once
(section 10). No token, code, or authorize URL is ever
logged; this feature touches no auth surface.

### 8.3 Demo sample (Builder B)

A private constant `DEMO_SAMPLE_EFT` in
`src/ui/fittings.rs`, shown by the `Use sample EFT`
button in demo mode only. No demo fixture schema
changes (`src/demo/data.rs` and `assets/demo/` are
untouched). The sample uses real catalogue names
(verified in section 3), never demo-fiction names,
and parses with zero issues, one placeholder, and one
noted charge — pinned by a test (section 12):

```text
[Rifter, Sample Brawler]
Damage Control II
Small Armor Repairer II

1MN Afterburner II
Warp Scrambler II

200mm AutoCannon II, Republic Fleet EMP S
200mm AutoCannon II
200mm AutoCannon II

Small Projectile Burst Aerator I
[Empty Rig slot]

Hobgoblin II x2

EMP S x200
Nanite Repair Paste x8
```

## 9. Round-trip contract with `fitting_to_eft` (LOCKED)

Let `f` be a `CharacterFitting` for which
`fitting_to_eft(f, resolver)` is `Some` with
`skipped_unknown == 0` and `skipped_empty == 0`, where
every exported name resolves uniquely in the bundled
catalogue, every stacked total is at most
`MAX_STACK_QUANTITY`, and every fitted module's type
carries a slot effect. Then
`parse_eft(fitting_to_eft(f))` yields an
`ImportedFitting` equivalent to `f` in this sense:

- same `ship_type_id` (the exported ship name resolves
  uniquely back to that ID);
- same display name through `fitting_display_name` of
  the sanitized header name;
- for each slot section, the same multiset of type
  IDs, with multiplicity per saved item equal to
  `min(quantity, 16)` (the exporter's own repeat cap
  is the only lossy step, and it is the exporter's,
  disclosed there by `skipped_empty`);
- for Drones, Fighters, and Cargo, the same
  `(type_id, total)` pairs.

Re-exporting the imported fitting
(`fitting_to_eft(&imported.to_character_fitting(),
&imported.name_resolver())`) is byte-identical to the
original export when additionally no slot section has
more than 9 items and no exported name needed
sanitization beyond the exporter's own.

Documented asymmetries (each expected, none a defect):

1. Header sanitization is one-way. The exporter strips
   `[`, `]`, `,`, and control characters from ship and
   fitting names (`sanitize_header_name`). A fit name
   with commas imports intact (first-comma rule) but
   re-exports with commas removed. A digit-only fit
   name re-exports as `Unnamed fitting`.
2. Loaded charges are display-only. They appear in the
   imported detail and the report, never in copied
   EFT (the exporter has no charge output and ESI
   saved fittings carry charges as cargo). The copy
   status message discloses the count (8.2).
3. Empty sections vanish in export and stay vanished;
   slot recovery comes from dogma effects, not section
   position (5.4). Empty-slot marker lines are never
   produced by the exporter.
4. Order within a section: the exporter sorts slot
   rows by flag string then name, so paste order is
   preserved only up to `LoSlot9`; 10+ items in one
   section reorder lexicographically by synthetic flag
   (`LoSlot10` before `LoSlot2`). Stacked sections
   re-export sorted by name (exporter behaviour).
5. Items the exporter skipped (unresolved names,
   non-positive quantities, slot repeats past 16) are
   absent from the text and therefore from any import.
6. Cargo whose type is unpublished or absent from the
   bundled catalogue, and any item whose name is
   duplicated in the catalogue (12 known names),
   re-imports as an `UnknownName`/`AmbiguousName`
   issue row. The loss is disclosed per line, never
   silent.
7. `description` has no EFT representation and is
   never imported. Charges loaded in a saved EVE
   fitting are exported as cargo by ESI's own model
   and import as cargo.
8. Canonicalization: pasted case and spacing are
   replaced by catalogue names on display and
   re-export (4.2).

## 10. Integrator wiring (LOCKED list)

The integrator owns exactly:

- `src/app/shell.rs`: add
  `pub fitting_types: Option<Arc<FittingTypes>>` to
  `MimirApp` (beside `sde`/`resolver`, lines 95-107).
  Load once in `MimirApp::new` next to the `Sde` load
  (lines 394-397) with the Exploration rule, not the
  `Sde` fallback: success logs once,
  `[FITTING] bundled fitting types loaded types={n}`;
  failure logs a `[FITTING]` warning and stores `None`
  (the panel then shows the section 8.2 catalogue
  sentence — an empty catalogue is never presented as
  valid). Update the view call at line 2450 to pass
  `self.fitting_types.as_deref()`. Nothing else in the
  shell changes: no refresh-path, merge, demo-seed, or
  name-scheduling edits (imported IDs are never
  scheduled for resolution; the local resolver covers
  them).
- `README.md`: two claims change. Line 22's Fittings
  bullet: replace `no fitting can be created, edited,
  imported, or deleted` with wording to the effect of:
  fittings saved in EVE cannot be created, edited, or
  deleted from Mimir; EFT text can be pasted to view a
  local imported fitting (with per-line problems
  shown) and copied back as EFT, but the imported
  fitting is kept only in memory on this device and is
  never saved to EVE. Line 31's roadmap entry: EFT
  import moves out of "not implemented" (Pyfa import,
  the simulator, and fitting creation/editing stay).
  Final sentence-level wording is the integrator's;
  the claims above are locked.
- `src/ui/settings.rs`: no change. `[FITTING]` is
  already in `LOG_TAGS` (line 16); no new tag.
- A grep pass over `README.md`, `CLAUDE.md`, and
  `docs/` for stale "no import" claims about Fittings,
  fixing only claims this slice falsifies.
- Engineering journal: one `docs/engineering-journal/`
  `LEARNINGS.md` entry in the integration commit —
  slot identity must come from dogma effects because
  the exporter omits empty sections (blank-line
  position cannot round-trip) — with Evidence,
  Mechanism, and the generalizable rule, per repo
  practice. A `DECISIONS.md` entry is not required;
  this document is the decision record.
- Full gates (section 12) plus a demo smoke: run with
  `--demo`, open Fittings, `Use sample EFT`, Import,
  confirm the report shows one ignored marker and one
  loaded charge, copy, and confirm the status message
  discloses the charge left out.

Builder A owns the one-line module declarations that
make its own code compile: `pub mod fitting;` in
`src/lib.rs` and `pub mod fitting_types;` in
`src/names/mod.rs`. The integrator does not touch
either file.

## 11. Logging, safety, and repo rules

- Every new public function logs at debug with
  `[FITTING]` (the parser logs counts, not text).
- No raw EVE numeric ID is rendered anywhere this
  slice adds UI; issue rows echo user text only.
- No new dependency, no new OAuth scope, no new ESI
  endpoint, no database schema change, no settings
  change. Grep-level acceptance: the slice diff
  contains no `POST`, `public_post`, `repositories::`
  fitting write, or `FITTINGS_SCOPES` change.
- Commits are small and atomic in
  `type(scope): description` form with no attribution
  lines. Suggested split: this design; Builder A
  catalogue + generator; Builder A parser; Builder B
  state + UI; integrator wiring + README + journal.
  Builders do not push or merge.

## 12. Test plan (LOCKED)

Gates for every commit: `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`,
`cargo test`, `flutter`-era gates inapplicable. New
tests live beside their code (`#[cfg(test)] mod tests`
in `fitting_types.rs`, `eft.rs`, `state.rs`,
`fittings.rs`), following the literal-fixture style of
`src/names/sde.rs` tests.

### 12.1 Catalogue tests (Builder A, `src/names/fitting_types.rs`)

- Bundled load: `type_count() > 20_000`; lookup
  `Rifter` → 587 category 6; `Damage Control II` →
  2048 category 7 effects contain 11; `Hobgoblin II`
  → 2456 category 18; `EMP S` → 185 category 8;
  `Tritanium` → 34 category 4.
- Normalization: `damage  control ii`,
  ` DAMAGE CONTROL II `, and a tab-separated variant
  all `Found` the same row; `Damage Control` (prefix)
  and `Damage Control IIx` are `Unknown` (exact-only).
- Small `from_json` fixtures: duplicate names (two IDs
  one normalized name) → `Ambiguous`; duplicate rows
  with the same `type_id` → still `Found`; rows with
  `typeId <= 0` / empty name skipped; all-rows-invalid
  → `Err`; malformed JSON → `Err`, no panic.
- Bundled-data invariants: no catalogue name is purely
  numeric (protects the 6.3 local-resolver insert);
  every category-6 name is free of `,`, `[`, `]`
  (protects the 5.2 first-comma rule).

### 12.2 Parser tests (Builder A, `src/fitting/eft.rs`)

Most tests use a small hand-written catalogue JSON
fixture (one fake type per category/effect combination
needed), so grammar rules are pinned independent of
SDE contents; a handful use the bundled catalogue for
real-name oracles. Flutter oracle cases are ported by
**case**, with expected IDs verified against the real
SDE data in section 3 — Flutter's seeded IDs (e.g.
Afterburner 5973, Aerator 3117, Templar 23061 in some
fixtures) are test-database fiction and must not be
copied.

Ported oracles:

- Slot-typed full fitting (from AAR `kAarSupportedEft`
  shape): `[Rifter, Fight Fit]` with Damage Control II
  (low, 2048), 1MN Afterburner II (medium, 438),
  200mm AutoCannon II (high, 2889), Small Projectile
  Burst Aerator I (rig, 31668), `Hobgoblin II x5`
  (drones, 2456) — every section and quantity asserted,
  zero issues.
- Header-only `[Rifter, Test]` → valid empty fitting
  (AAR T05).
- Placeholders + CRLF throughout → the one real module
  imported, placeholders counted, zero issues (AAR T05
  shape).
- Colon fit name `[Rifter, PvP: Armor]` → name
  `PvP: Armor` (AAR T07); comma fit name →
  first-comma rule keeps `Brawl, v2` (divergence case,
  5.2).
- Broken headers (no brackets, no comma, empty ship),
  unknown ship, and non-ship header (`[Damage Control
  II, Fit]`) → the three distinct fatals (AAR T06
  shape).
- Unknown module among known: known lines import, the
  unknown line is one `UnknownName` issue with the
  right line number and text — explicitly not the base
  Flutter silent-skip oracle (`shared parser still
  skips unknown modules by default` must not be
  ported as behaviour).
- `x0`, `x-1` (not stacked shape → plain-line path),
  `x05`, `x99999999999999999999` → `InvalidQuantity`
  or the locked fall-through, each asserted (AAR T08
  shape).
- `Templar II x6` twice → fighters 40556 ×12 merged
  (base merge oracle); drones sort before fighters in
  section terms regardless of paste order.
- Charge line `200mm AutoCannon II, Republic Fleet
  EMP S` → module imported, charge stored (21898),
  `charges_noted == 1` — replacing the AAR T09
  whole-fit rejection with this slice's locked
  store-and-disclose rule; plus `UnknownCharge`,
  `NotACharge` (e.g. `, Tritanium`), and
  double-comma `MalformedChargeLine` cases.
- Subsystem line `Legion Core - Augmented Antimatter
  Reactor` under `[Legion, …]` → Subsystem section,
  45623 (the exporter-inverse case Flutter dropped).
- Cargo stack `Tritanium x500` and charge-as-cargo
  `EMP S x200` → Cargo with quantities (the case
  Flutter dropped).
- Stacked module `Damage Control II x2` →
  `StackedModule`; plain drone `Hobgoblin II` →
  `NotAModule`; a fake-fixture category-7 type with
  no slot effects → `NoSlotForModule`; bracketed
  junk `[Some note]` → `BracketedLine`; lowercase
  `[empty low slot]` → `BracketedLine` (case-sensitive
  placeholder lock).
- Blank-line independence: the full fitting pasted
  with no blank lines at all, and with sections in
  scrambled order, classifies identically (5.4).
- Report invariant: `imported + placeholders +
  issues == non-blank body lines` across the above.

Adversarial / bounds corpus (each must return an
outcome, no panic): empty string; whitespace only;
`[`; `[]`; `[,]`; `[Rifter]`; a DNA string
`587:2048;1::` → `HeaderMalformed`; NUL and control
characters inside lines; emoji ship name; a line of
10,000 `a`s; 1,001 lines → `TooManyLines`; 65,537
bytes → `TooLarge`; exactly 65,536 bytes and exactly
1,000 lines accepted; `,,,`; ` x5`; `Module x`;
merged stacks crossing `MAX_STACK_QUANTITY` →
`QuantityTooLarge` on the crossing line only.

Round-trip (Builder A, using `fitting_to_eft`):
build a `CharacterFitting` from real catalogue types
covering every section (including subsystem and
Tritanium cargo), export with a resolver built from
the catalogue, import, and assert section-9
equivalence; then re-export the synthesis and assert
byte-identity. A second case pins one documented
asymmetry end-to-end: a fit name containing a comma
imports intact and re-exports sanitized.

### 12.3 State and UI tests (Builder B)

- State mirrors of the existing fittings reset tests
  (`src/app/state.rs` tests near the patterns at lines
  995-1100): different-ID switch clears all four
  import fields; same-ID reselect keeps them; removing
  the active character clears them; removing a
  non-active character keeps them; empty roster clears
  them.
- Pure UI helpers: issue-row formatting (exact
  template, 120-char truncation over a 200-char line,
  singular/plural headings, over-cap disclosure with
  25 issues) and report summary lines — factored as
  pure `fn`s in `src/ui/fittings.rs` so they are
  testable without egui, in the style of
  `fitting_rows`/`fitting_item_rows` tests.
- `DEMO_SAMPLE_EFT` parses against the bundled
  catalogue with zero issues, `placeholder_lines ==
  1`, `charges_noted == 1`; its synthesis exported
  through its local resolver re-imports to zero
  issues.
- A grep-level test already exists for log tags;
  assert nothing: `LOG_TAGS` is untouched (no new
  test needed, diff-verified).

The existing full test suite must pass unmodified;
in particular every `src/ui/fittings.rs` exporter test
(lines 839-1036+) is a regression oracle for the
extract-only change in 6.2.

## 13. Ownership and sequence (LOCKED)

- **Builder A — parser core and reverse lookup.**
  Owns: `scripts/sde/generate_fitting_types_sde.py`,
  `assets/sde/fitting_types.json` (generated),
  `src/names/fitting_types.rs`, `src/names/mod.rs`
  (one line), `src/fitting/mod.rs`,
  `src/fitting/eft.rs`, `src/lib.rs` (one line), and
  their tests. Delivers the frozen APIs of sections
  4.2, 5.6, 5.7, and 6 (`FittingTypes`, `NameLookup`,
  `parse_eft`, `ImportedFitting` +
  `to_character_fitting` + `name_resolver`,
  `ImportIssueKind::reason`, `ImportFatal::message`,
  the section 7 constants). Two commits suggested:
  catalogue + generator, then parser.
- **Builder B — state, UI, demo.** Owns:
  `src/app/state.rs` (fields, resets, tests) and
  `src/ui/fittings.rs` (panel, `render_fitting_items`
  extract, imported detail, copy button,
  `DEMO_SAMPLE_EFT`, formatting helpers, tests). Codes
  against Builder A's frozen API; sequence after A.
- **Integrator.** Owns `src/app/shell.rs` wiring
  (field, load, call site), `README.md` claims, the
  stale-claim grep pass, the journal entry, full
  gates, and the demo smoke. No other files.
- Nobody edits `fitting_to_eft`, `fitting_item_rows`
  semantics, `FittingsData`, `EveConfig` scopes,
  `src/demo/data.rs`, `assets/demo/`, or
  `src/ui/settings.rs`. Any discovered need to do so
  is a design amendment, raised before the edit.

## 14. Recorded choices where sources disagreed or were silent

Complete list; each names the source behaviour
replaced and the ranking that decided it.

| Topic | Sources | Locked choice |
|---|---|---|
| Unknown body line | Base: silent drop. AAR: reject whole fit | Import the rest, report the line (rank 1) |
| Ship unresolved | Base: `shipTypeId = 0`, continue. AAR: fatal | Fatal, three distinct messages (rank 1) |
| Header comma | Both Flutter parsers: last comma, greedy | First comma; fit names may contain commas (rank 2 + verified data) |
| Header trimming | Base: raw groups. AAR: trimmed | Trimmed (AAR) |
| Slot fallback | Base: blank-line position, then high | None; `NoSlotForModule` (ranks 1, 2) |
| Subsystems in EFT | Base EFT: dropped. DNA: kept. Exporter: emitted | Accepted (rank 2) |
| Cargo stacks | Base: dropped silently. AAR: rejected. Exporter: emitted as `xN` | Cargo section (ranks 1, 2) |
| Stacked module | Base: dropped silently. AAR: rejected fit | `StackedModule` issue (rank 1) |
| Loaded charge | Base: stripped silently. AAR: rejected fit. Spec sketch + model: stored | Stored, displayed, disclosed as omitted on copy (brief + rank 1) |
| Empty-slot markers | Base: any `[` line skipped. AAR: explicit five | AAR five, exact and case-sensitive; other bracketed lines are issues (rank 1) |
| Quantity `x0`, `x05` | Base: accepted. AAR: rejected | AAR rule, `InvalidQuantity` |
| Name search limit | Base: substring, limit 20. AAR: full-table exact | Full-table exact index; ambiguity is unresolved |
| Input size limits | Base: none. AAR: 256 KiB / 4,096 / i32 | 64 KiB / 1,000 lines / i32 quantities (rank 5) |
| Comments | No source defines any | No comment syntax; such lines are ordinary lines |
| Name source | Market: live ESI `resolve_ids`. Brief: bundled SDE | Bundled catalogue with categories and slot effects (ranks 2, 3) |
| Whole-paste logging | Base logged the full EFT string | Counts only, never pasted text |

## 15. End-to-end flow (one paragraph)

The user opens Fittings for any character (live or
demo, scoped or not) and sees the import panel above
the saved-fittings area; they paste an EFT block and
click Import; `parse_eft` resolves the header ship and
every body line against the bundled fitting-types
catalogue in memory — no network, no token, no
database — and the panel shows the imported fitting
grouped by section with canonical names, its loaded
charges listed below the items, and every line that
could not be imported named with its line number,
original text, and fixed reason; from there the user
can copy the fitting back as EFT through the unchanged
PR #569 exporter (with any loaded charges disclosed as
left out), edit the text and re-import, or switch
characters and lose it, because the imported fitting
exists only as this character's in-memory working
state and is never persisted or sent to EVE.
