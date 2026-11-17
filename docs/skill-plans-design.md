# Skill plans slice — locked design

Branch: `feat/rust-skill-plans`. Base: `develop` at
`61b2a2c` (merge of pull request #587, portraits; 676
tests green at base). This document locks the design for
local skill plans in the Rust app: a user creates named
plans per character, adds skills with target levels,
reorders and removes entries, sees per-entry and total
skill-point (SP) and training-time estimates, and has
plans persist locally in SQLite. The slice is read-only
against EVE: no new OAuth scopes, no EVE writes, no new
network calls. Where this document and an earlier
document disagree about plan behavior, this document
wins for plans only; every shipped read behavior (queue,
catalogue, character detail) stays exactly as shipped.

The one hard question this slice had to answer first is
whether the SP-per-level and training-speed formulas are
grounded in bodies inside this repository. They are, but
the repository contains **two conflicting SP formulas**,
and the wrong one is the one a porter would copy first.
Section 3 records the evidence, the verdict, and the
exact arithmetic every estimate and every test literal
must follow. Nothing in this slice may recall an EVE
formula from general knowledge: every constant below is
quoted from an inspected in-repo body in section 0.

## 0. Grounded evidence (inspected bodies)

Every formula, limit, table shape, and wording precedent
below traces to one of these sources, all read directly
this session (Rust sources at `61b2a2c`, Flutter via
`git show ed698d3:...`, bundled assets on disk).

1. **SDE (Static Data Export) dogma attribute 275**,
   `skillTimeConstant`, inside the committed archive
   `scripts/sde/eve-online-static-data-3503375-jsonl.zip`
   → `dogmaAttributes.jsonl`, `_key 275`. Its
   `description` field reads verbatim: *"This attribute
   is a multiplier to the number of skill points required
   to train. Skill points required to train a skill =
   250 * skillTimeConstant * sqrt(32)^(skillLevel - 1)"*.
   The same file names attributes 164–168 (`charisma`,
   `intelligence`, `memory`, `perception`, `willpower`)
   and 180/181 (`primaryAttribute` /
   `secondaryAttribute`, each *"Only refers to another
   dogma attribute"*).
2. **Bundled skill extract** `assets/sde/skills.json`
   (495 types, 24 groups, 1 category) parsed by
   `SdeSkillType` (`src/names/sde.rs:27-42`): every one
   of the 495 types carries `rank`, `primaryAttribute`,
   and `secondaryAttribute` (verified by scan: 0 missing;
   ranks 1–16; test `rank_and_attributes_parse_from_extract`,
   `src/names/sde.rs:211-218`, pins Gunnery 3300 at rank 1,
   perception/willpower). Accessors reused below:
   `skill()` (line 105), `skill_name_quiet()` (123),
   `search_skills()` (163). 466 of 495 types also carry
   `prerequisites`, which no Rust code parses today
   (excluded, section 2).
3. **Demo fixtures** `assets/demo/skillqueue.json`:
   cumulative-SP witnesses — trained level 3 rows carry
   `skillpoints_in_skill: 8000`, level 4 rows `45255`,
   level 5 rows `256000`, and queue rows carry
   `level_start_sp`/`level_end_sp` pairs `8000→45255`
   and `45255→256000`. All rank-1 rows match source 1
   read as a cumulative total (section 3.1). Three
   rank-2 rows (3310, 3330, 3394) carry rank-1 SP
   values, so the fixtures are **not** evidence for rank
   scaling; they are invented sample rows and are used
   below only where they agree with source 1. Recorded
   honestly in section 15, item 2.
4. **Retired Flutter calculator**
   `lib/features/skills/domain/skill_training_calculator.dart`
   at `ed698d3`: training rate *"Primary attribute +
   (Secondary attribute / 2)"*, SP per minute equals that
   rate, time is `Duration(minutes: (SP / rate).ceil())`,
   levels outside 0–5 throw, `fromLevel >= toLevel`
   yields 0. Its SP-per-level formula (`250 × rank ×
   2^(level-1)`, summed) is **rejected** in section 3.
   Its fallbacks — default attributes 20/20 and rank 1
   for a skill with no SDE rank
   (`calculateSpRequiredFromSde`,
   `calculateTrainingTimeFromSde`) — are **rejected** in
   section 6. Its test file
   `test/features/skills/domain/skill_training_calculator_test.dart`
   pins the rejected arithmetic (rank-1 0→5 = 7,750 SP)
   and is evidence of the conflict, not an oracle.
5. **Retired Flutter attribute model**
   `CharacterAttributes.spPerHour` in
   `lib/core/network/esi_client.dart` at `ed698d3`:
   `(primary + secondary / 2.0) * 60.0`, with attribute
   ids 164–168 mapped to the same five names as source 1.
   Its test pins 20/20 → 1800 SP/hour. This is a second,
   independent in-repo witness for the rate shape in
   source 4.
6. **Retired Flutter plan feature** at `ed698d3`: Drift
   tables `SkillPlans(id, characterId, name,
   description?, createdAt, updatedAt)` and
   `SkillPlanEntries(id, planId, skillId, targetLevel
   1-5, sortOrder)` (`app_database.dart:392-433`);
   CRUD at `app_database.dart:1853-1973` (create returns
   the new id, delete is one transaction removing
   entries then the plan, plans list ordered by
   `updatedAt` descending, entries by `sortOrder`
   ascending, reorder rewrites `sortOrder` 0..n,
   remove-by-`(planId, skillId)`); editor validation
   name required/≤100 chars, description ≤500 chars
   (`skill_plan_editor.dart`); progress counts an entry
   complete when `trainedLevel >= targetLevel`, only
   incomplete entries contribute SP/time, per-entry
   times are summed, an empty plan is 100% complete
   (`skill_plan_providers.dart`,
   `skillPlanProgressProvider`); the detail screen
   reorders by drag and confirms entry removal
   (`skill_plan_detail_screen.dart`). Discovery child G1
   also verified the negatives in that codebase: no
   import/export, no queue interaction in progress, a
   prerequisite service that exists but is never called
   from the plan flow.
7. **Current Rust seams** at `61b2a2c`: storage
   mechanism (`src/storage/db.rs:9,83-101` —
   `SCHEMA_VERSION = 1`, `migrate()` runs the whole
   `schema.sql` batch of `CREATE TABLE IF NOT EXISTS`
   then stamps `PRAGMA user_version`); schema
   (`src/storage/schema.sql` — 11 tables, composite
   per-character keys, no foreign-key clauses anywhere);
   repositories (`replace_skill_queue` /
   `replace_character_skills` DELETE-then-INSERT inside
   `unchecked_transaction`, `src/storage/repositories.rs:275-370`;
   the explicit 7-table `delete_character` list, lines
   240-263); ESI models `Skill` / `CharacterSkills` /
   `SkillQueueItem` / `CharacterAttributes`
   (`src/esi/models.rs:34-100`) and endpoints
   `get_skills` / `get_skill_queue` / `get_attributes`
   (`src/esi/endpoints.rs:21-52`), all already fetched
   by shipped views; app state
   (`src/app/state.rs` — `SkillsData` lines 290-296 is a
   cross-builder contract: *"do not add fields here"*;
   attributes live in `character_details: LoadState<CharacterDetailData>`
   line 677 as `SectionResult<CharacterAttributes>` line
   323, one of seven tolerant sub-fetches; fittings-import
   and fittings-write fields lines 731-750 are the
   memory-only, cleared-on-switch precedent; switch and
   removal resets lines 860-1093); the Skills view
   (`src/ui/skills.rs` — queue plus searchable catalogue,
   `trained_levels()` lines 21-31, no attribute display);
   shared widgets (`src/ui/widgets.rs` — `format_sp`,
   `format_countdown`, `search_box`, `empty_panel`,
   `mode_notice`); the fittings-write confirmation idiom
   (`src/ui/fittings.rs:833-1044` — inline two-step
   confirms, stamped confirm records, staleness checks,
   the demo label constant) and its shell refusal
   decision (`src/app/shell.rs:268-355`,
   `decide_fitting_write_start`, demo first); demo
   handling (`src/app/shell.rs:804-811` — *"demo uses
   bundled in-memory data; live database untouched"*, plus
   the one-time polluted-database cleanup lines 816-836;
   demo attributes for both demo characters in
   `assets/demo/character_detail.json`, e.g. 90000001 at
   perception 25 / willpower 24); cached startup load
   (`load_cached_state`, `src/app/shell.rs:655+`, restores
   skills/wallet only — there is no attributes table); log
   tags (`LOG_TAGS`, `src/ui/settings.rs:7-22`); pure
   domain modules under `src/fitting/` (e.g.
   `resources.rs` — no egui, no state, no database) as
   the home precedent for new pure math. There is **no**
   training formula and **no** drag-and-drop anywhere in
   current Rust (both greps empty).

## 1. Value ranking (LOCKED)

When two choices conflict, the higher rank wins. Rules
below cite the rank that decided them where an inspected
body did not force the choice.

| Rank | Value | What it decides |
|---|---|---|
| 1 | No invented numbers | Every SP/time figure derives from a quoted in-repo formula or is shown as unavailable; no default attributes, no fallback rank, no partial total dressed as a total |
| 2 | User data is never lost silently | Plans are the app's first user-authored rows; every mutation is one transaction; a failed save leaves state unchanged and says so; destructive actions confirm first |
| 3 | Demo never reaches the real database | Demo plans live in memory only; the live-database path is unreachable while demo is on, by construction (pure routing decision, tested) |
| 4 | Character isolation | Every plan row, state field, queued action, and confirmation carries its character id; a switch or removal clears plan working state exactly like fittings state |
| 5 | Reuse of shipped machinery | Existing schema mechanism, replace-in-transaction writes, `LoadState`, inline confirms, search box, SP/countdown formatters, drain-in-shell request flags |
| 6 | Feature breadth | Create/rename/delete plans, add/remove/reorder entries, estimates and progress; nothing beyond the slice goal (section 2) |

## 2. Hard scope and explicit exclusions (LOCKED)

In scope: two new tables and a schema version bump
(section 5); the plan/entry model and its invariants
(section 4); pure SP/time/progress functions implementing
section 3 and nothing else (section 6); per-character
plan state and one queued-action channel (section 7); a
Skill plans section inside the existing Skills view with
plan list, plan detail, inline editor, inline confirms,
and a search picker (section 8); demo plans in memory
(section 9); `[PLANS]` logging (section 10); shell wiring
that routes, persists, and reloads (section 11).

Explicitly out, each with its ground:

- **EVE skill-queue writes or sync** (pushing a plan into
  the in-game queue): the slice goal is read-only against
  EVE; no inspected body in either codebase writes a
  queue.
- **Import/export of plans** (files, clipboard text,
  EVE's in-game plan format): G1 verified the Flutter app
  has none, so there is nothing grounded to port; greenfield
  formats are not invented here.
- **Prerequisite warnings or auto-adding prerequisites**:
  the data exists unparsed (section 0, source 2) and
  Flutter's prerequisite service was never wired into the
  plan flow (source 6). Adding the serde field later is
  trivial; this slice does not parse it.
- **Remap / implant / booster what-ifs**: estimates use
  the character's attributes exactly as loaded (section
  6). No inspected body models a hypothetical attribute
  set.
- **Queue-aware estimates**: Flutter progress ignores the
  training queue (source 6), and no other body defines
  how queued training should net against a plan. The UI
  discloses the omission in fixed words (section 8.4)
  instead of guessing.
- **Editing an entry's target level in place**: Flutter
  parity is add/remove/reorder only (source 6). Changing
  a target is remove plus re-add in this slice.
- **Drag-to-reorder**: there is no drag precedent in the
  Rust codebase (section 0, source 7). Reorder is
  Move up / Move down buttons (section 8.4).
- **Copying plans between characters**: no Flutter
  precedent; per-character keying (rank 4) makes a plan
  belong to exactly one character.
- **A new navigation view or key**: plans live inside
  `View::Skills` (Flutter parity: tabs inside its Skills
  screen, source 6). `View::ALL`, nav keys, and startup
  view persistence are untouched.
- **Persisting character attributes** to make estimates
  survive a restart: rejected in section 14. Estimates
  degrade honestly until attributes load (section 6.4).
- **Bundled demo plans**: demo starts with no plans; the
  demo user creates them in-session (section 9). No
  fixture file is added.

## 3. Formula verdict (LOCKED — read this before any estimate code)

### 3.1 SP per level: the SDE cumulative form wins; the Flutter form is rejected

Two in-repo formulas claim to give SP per skill level:

- **Flutter** (source 4): each level `L` costs
  `250 × rank × 2^(L-1)` SP, summed. Rank 1, level 0→5:
  `250 × (1+2+4+8+16) = 7,750` SP. Its tests pin 7,750,
  38,750 (rank 5), and 2,000 (rank 1, 3→4).
- **SDE attribute 275** (source 1): *"Skill points
  required to train a skill = 250 * skillTimeConstant *
  sqrt(32)^(skillLevel - 1)"*.

Read as the **cumulative SP total at which a level is
reached** (the quantity ESI reports as
`skillpoints_in_skill` and as queue `level_end_sp`), the
SDE text gives for rank 1: level 1 = 250, level 2 =
1,414.21… (250 × 5.656854249492381), level 3 = 8,000
(250 × 32), level 4 = 45,254.83… (250 ×
181.01933598375618), level 5 = 256,000 (250 × 1024).
Every rank-1 row in source 3 matches these values
rounded (8,000 / 45,255 / 256,000), and the queue
`level_start_sp→level_end_sp` pairs confirm the
cumulative reading: training to level 5 starts at the
level-4 total (45,255) and ends at the level-5 total
(256,000). Read as a per-level increment to be summed,
the same text gives level 3 = 250 + 1,414 + 8,000 =
9,664, which no fixture shows; the cumulative reading is
the only one the fixtures corroborate. The Flutter form
reproduces **none** of the fixture totals and understates
rank-1 0→5 by a factor of 33 (7,750 against 256,000).

**Locked:** cumulative SP at level `n` is
`round(250 × rank × sqrt(32)^(n-1))` for `n` in 1..=5,
and 0 for `n = 0`, where `rank` is the skill's
`skillTimeConstant` from the bundled extract (source 2)
and `round` is round-half-away-from-zero on the full
product, once (section 6.1). The Flutter `2^(L-1)` form
must not be copied, and its test numbers (7,750 and
family) must not appear as expectations anywhere in this
slice. Rank scaling rests on the SDE text itself
(`250 * skillTimeConstant * …`); source 3 neither proves
nor refutes it (section 15, item 2).

### 3.2 Training speed: primary + secondary/2 SP per minute, per entry

The rate formula has two independent in-repo witnesses
(sources 4 and 5) and no competitor: a skill trains at
`primary + secondary / 2` SP per minute, where primary
and secondary are **that skill's own** attribute pair
(source 2, resolving through attribute ids 164–168 in
source 1) read against the character's loaded attributes
(source 7). Time for one entry is
`ceil(SP remaining / rate)` whole minutes (source 4).
A plan total is the **sum of per-entry times**, each at
its own skill's rate — which is what Flutter's progress
provider actually did (source 6). Flutter's
`calculateTotalTrainingTime`, which priced a whole list
at one shared rate, is not the progress path and must
not be ported (section 14).

### 3.3 What "grounded" cost this slice (recorded, not worked around)

Because the SP formula, the rate formula, per-skill rank,
and per-skill attribute pairs are all grounded above,
this slice ships per-entry SP, per-entry time, and plan
totals. Had any leg been missing, section 6's unavailable
rules are the whole behavior for that leg — they are
locked anyway for the runtime cases (attributes not
loaded, rank absent, unknown attribute string) where a
grounded formula still has no grounded input. There are
no guessed defaults anywhere in this design: Flutter's
20/20 attribute default and rank-1 fallback (source 4)
are the exact failure mode rank 1 exists to prevent.

## 4. Plan and entry model (LOCKED)

New module `src/skills/` (`mod.rs`, `plans.rs`,
`training.rs`), registered as `pub mod skills;` in
`src/lib.rs`, following the `src/fitting/` pure-module
precedent (source 7): no egui, no `AppState`, no network,
no database handles. `plans.rs` owns the model and
validation; `training.rs` owns section 3 arithmetic and
progress (section 6).

```rust
// src/skills/plans.rs
#[derive(Debug, Clone, Default, PartialEq)]
pub struct SkillPlanEntry {
    pub skill_id: i64,
    pub target_level: i32, // 1..=5, invariant I2
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct SkillPlan {
    pub plan_id: i64,      // storage-assigned (live) or session-assigned (demo)
    pub character_id: i64,
    pub name: String,
    pub description: String, // "" = none; there is no Option in state
    pub created_at: String,  // RFC 3339 text, "" only pre-persist in a draft action
    pub updated_at: String,
    pub entries: Vec<SkillPlanEntry>, // index IS the sort position
}
```

Invariants, enforced by one pure validator
`validate_plan(plan: &SkillPlan) -> Result<(), PlanValidationError>`
that the storage layer calls before every write and the
demo applier calls before every mutation (section 9).
Invalid data never reaches SQLite and never renders as
valid:

- **I1 — one entry per skill per plan.** `skill_id` is
  unique within `entries`. Ground: Flutter's storage
  assumed it without enforcing it — remove and reorder
  both key on `(planId, skillId)` (source 6), so a
  duplicate row in Flutter was un-removable one-at-a-time
  and un-orderable. This slice enforces at validation,
  in the schema (`UNIQUE` index, section 5), and in the
  picker (already-in-plan rows offer no add, section 8.5).
- **I2 — target level in 1..=5.** Ground: Flutter's
  `targetLevel` column comment *"Target level for this
  skill (1-5)"* and its calculator throwing outside 0–5
  (sources 6, 4); the SDE formula is quoted for
  `skillLevel` 1–5 by the same bodies. A target of 0
  would mean "plan to not train", which no body models.
- **I3 — order is the vector.** There is no stored
  ordering field in the model; `entries[i]` is position
  `i`. Storage materializes `sort_position = i` (section
  5) and reloads `ORDER BY sort_position`. Flutter's
  `sortOrder` (source 6) is the same idea with the field
  exposed; keeping it implicit makes gaps and duplicates
  unrepresentable in memory.
- **I4 — name is trimmed, non-empty, ≤100 characters;
  description is trimmed, ≤500 characters.** Character
  counts are Unicode scalar counts (`.chars().count()`),
  following the fittings name rule's unit. Ground:
  Flutter editor validators (source 6). Normalization is
  one pure function
  `normalize_plan_text(name: &str, description: &str) -> Result<(String, String), &'static str>`
  returning the exact section 8.3 error strings, shared
  by the editor (live validity) and the action applier
  (defense in depth at rank 2).
- **I5 — entries may name skills absent from the bundled
  extract.** A stored `skill_id` is never rejected for
  being unknown to this build's SDE copy (the extract can
  lag the game). Such entries render as "Unknown Skill"
  with unavailable estimates (section 6.4), never as a
  raw id. The picker only offers extract skills, so this
  arises only for rows written by a newer build.
- **I6 — a plan belongs to exactly one character forever.**
  `character_id` is set at creation from the active
  character and no action mutates it (rank 4).

There is deliberately no entry count cap, plan count cap,
or name-uniqueness rule: no inspected body defines one
(Flutter enforces none), and inventing a limit would be
an ungrounded refusal. Duplicate plan names for one
character are legal, as in Flutter.

## 5. Storage schema and migration (LOCKED)

### 5.1 Schema (append to `src/storage/schema.sql`)

Following the file's exact conventions (source 7):
`CREATE TABLE IF NOT EXISTS`, `NOT NULL DEFAULT`,
composite per-character keys, no foreign-key clauses
(the file has none and `configure()` enables no
`foreign_keys` pragma, so an FK clause would be
decoration; cascades are explicit code, section 5.3).

```sql
-- User-authored skill plans (the app's first non-ESI rows;
-- see docs/skill-plans-design.md section 5). plan_id is
-- storage-assigned; entries carry character_id so
-- delete_character can cascade by its table list.
CREATE TABLE IF NOT EXISTS skill_plans (
    plan_id INTEGER PRIMARY KEY AUTOINCREMENT,
    character_id INTEGER NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT '',
    updated_at TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS skill_plan_entries (
    character_id INTEGER NOT NULL,
    plan_id INTEGER NOT NULL,
    sort_position INTEGER NOT NULL,
    skill_id INTEGER NOT NULL,
    target_level INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (character_id, plan_id, sort_position)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_skill_plan_entries_skill
    ON skill_plan_entries (character_id, plan_id, skill_id);
CREATE INDEX IF NOT EXISTS idx_skill_plans_character
    ON skill_plans (character_id, updated_at DESC);
```

`AUTOINCREMENT` (never reuse a deleted plan's id) is
chosen over plain rowid reuse so a stale stamped
confirmation can never accidentally match a newly created
plan that recycled the id (rank 2 interacting with
section 7's staleness rule). Denormalized `character_id`
on entries exists for exactly one reason: the
`delete_character` table-list cascade (section 5.3)
deletes `WHERE character_id = ?1` per table and cannot
join. It is written from the parent plan row in the same
transaction and never read independently of it.

### 5.2 Migration (the repo's exact mechanism, nothing new)

1. Append section 5.1 to `schema.sql` and add a header
   comment line recording the v2 addition (the file's
   header already narrates its additions; extend it, do
   not rewrite history wording for v1).
2. `SCHEMA_VERSION: i64 = 1` → `2` in `src/storage/db.rs:9`.
   `migrate()` itself is **unchanged**: it already runs
   the whole additive batch and stamps `user_version`,
   and its `current > SCHEMA_VERSION` branch already
   warns and continues. A v1 database gains empty plan
   tables; a v2 database re-running migrate is a no-op;
   a newer database opened by this build keeps its plan
   rows untouched (additive DDL only, no `DROP`, no
   `ALTER` anywhere in this slice).
3. Existing tests updated in the same commit:
   `migrate_is_idempotent_and_sets_version` asserts the
   literal `1` today (`db.rs:111`) and becomes `2`;
   `schema_creates_contract_tables_plus_f2_additions`
   keeps counting its named 11 (its list is not extended;
   a new test counts the two plan tables by name so both
   contracts stay readable).
4. New migration-from-v1 test (section 12, T11):
   simulate a v1 file (stamp `user_version = 1`, drop the
   plan tables, insert one character), run `migrate()`,
   assert version 2, both tables exist, and the character
   row survived. This is the only honest way to test an
   upgrade when `open_in_memory()` always migrates to
   current.

### 5.3 Repository API (`src/storage/repositories.rs`)

Functions take `&rusqlite::Connection` and the section 4
model types directly. Deviation from the file's `*Row`
struct habit, recorded: every existing `*Row` mirrors an
ESI wire shape into storage; plans have no wire shape, so
a parallel `SkillPlanRow` would be a field-for-field copy
with conversion boilerplate at every call site and no
second representation to justify it (rank 5 decides
against empty ceremony, not against the pattern where a
wire shape exists). Timestamps are caller-supplied
RFC 3339 text (`now: &str`) so repository tests are
deterministic; the module comment's rule (lexicographic
equals chronological for this text shape) already covers
ordering. The shell passes `Utc::now().to_rfc3339()`
(section 11). No function reads the clock, the SDE, or
`AppState`.

- `create_skill_plan(conn, character_id, name, description, now) -> AppResult<i64>`
  — one INSERT with `created_at = updated_at = now`;
  returns `last_insert_rowid()`. Validates via
  `normalize_plan_text` + I4 first; an invalid name is an
  `Err`, never a stored empty name.
- `update_skill_plan_text(conn, character_id, plan_id, name, description, now) -> AppResult<bool>`
  — UPDATE … `WHERE character_id = ?1 AND plan_id = ?2`
  (both keys, rank 4: a plan id alone never authorizes a
  cross-character write), sets `updated_at = now`;
  `false` when no row matched.
- `replace_skill_plan_entries(conn, character_id, plan_id, entries, now) -> AppResult<bool>`
  — the `replace_skill_queue` shape (source 7): inside
  one `unchecked_transaction`, verify the plan belongs
  to the character (0 rows → `false`, nothing written),
  DELETE its entries, INSERT `entries` at
  `sort_position` 0..n, stamp the plan's `updated_at`.
  Add, remove, and reorder are all this one function
  called with the full new vector (invariant I3 makes
  that safe and makes reorder atomic for free). Calls
  `validate_plan` on the assembled plan before opening
  the transaction.
- `delete_skill_plan(conn, character_id, plan_id) -> AppResult<bool>`
  — one transaction: entries first, then the plan row,
  both scoped by `(character_id, plan_id)` (Flutter's
  delete order, source 6); `false` when the plan row did
  not exist for that character.
- `list_skill_plans(conn, character_id) -> AppResult<Vec<SkillPlan>>`
  — plans `ORDER BY updated_at DESC, plan_id DESC`
  (Flutter's order, source 6, plus a pinned tiebreak
  because same-second text timestamps collide), each
  with entries `ORDER BY sort_position`. Two queries
  (plans, then all their entries) assembled in memory;
  entry rows whose plan vanished between the queries
  cannot occur under the single `Mutex<Connection>` the
  shell holds, and are dropped defensively if seen.
- `delete_character` gains `"skill_plan_entries"` and
  `"skill_plans"` in its table list (entries first in
  the list, cosmetic under one transaction). This is the
  character-removal cleanup: removing a character in the
  UI already routes to this function via the shell
  (section 11), so plans can never outlive their
  character in the database. The one-time demo-pollution
  cleanup (source 7) calls the same function, so any
  historically polluted demo plans would be cleaned by
  the same path — none can exist, since demo never
  writes (section 9).

Every function logs `[PLANS]` with ids and counts only
(section 10). Storage errors propagate as `AppResult`
errors; the repository never swallows a failure into an
empty vec (the shell decides how a load failure
renders, section 11).

## 6. Pure estimate functions (LOCKED)

All in `src/skills/training.rs`. Pure: inputs are values
(plus the bundled catalogue where noted), never
`AppState` or a database connection — the view
extracts plain inputs first (section 8.1), which is what
makes every literal in section 12 testable without a
frame. Every function is total: hostile or missing input
yields `None` / clamped values, never a panic, never a
guessed default.

### 6.1 Cumulative SP

```rust
/// Cumulative SP at which `level` is reached for a skill
/// of the given rank: round(250 * rank * sqrt(32)^(level-1)).
/// Provenance: SDE attribute 275 description (design 3.1).
pub fn cumulative_sp(rank: i64, level: i32) -> Option<i64>
```

- `rank <= 0` → `None` (the extract uses 0 for "omitted",
  `sde.rs:35`; there is no fallback rank — source 4's
  rank-1 fallback is rejected).
- `level` is clamped to `0..=5` (the clamp precedent in
  fitting resources, source 7); level 0 → `Some(0)`.
- Compute in `f64` as `250.0 * rank as f64 * 32f64.sqrt().powi(level - 1)`,
  then `.round() as i64` — **round once, on the full
  product**. Rounding a rank-1 base first and multiplying
  after gives different values at some ranks (rank 5,
  level 4: round-once 226,274 against 45,255 × 5 =
  226,275); the SDE text is one product, so one rounding.
  Section 12 pins both the rule and literals that
  distinguish it. The level-2 value (1,414.21… → 1,414)
  follows from the same rule; no fixture covers level 2,
  recorded in section 15, item 3.

### 6.2 SP remaining for one entry

```rust
pub struct TrainedSkill { pub trained_level: i32, pub skillpoints_in_skill: i64 }
pub fn sp_remaining(rank: i64, trained: Option<TrainedSkill>, target_level: i32) -> Option<i64>
```

- Effective current SP is
  `max(cumulative_sp(rank, trained_level), skillpoints_in_skill)`
  when a trained row exists, else 0 for an untrained
  skill. Using the loaded `skillpoints_in_skill`
  (source 7, `Skill` model) credits partial progress
  into the next level, which a level-only difference
  would overstate; the `max` with the level threshold
  means a stale or inconsistent SP figure can never move
  a character backwards below the level ESI already
  reports complete. (The same `max` masks the three
  rank-inconsistent demo fixture rows, section 15 item 2.)
- Remaining is `max(0, cumulative_sp(rank, target) - effective)`.
  `trained_level` clamps to `0..=5`; a negative stored
  `skillpoints_in_skill` clamps through the `max` and
  final floor. `None` propagates from `cumulative_sp`.
- Completion is a **level** fact, not an SP fact
  (Flutter parity, source 6): an entry is complete when
  clamped `trained_level >= target_level`, in which case
  remaining is `Some(0)` by the formula. Conversely,
  SP at or past the target threshold with the level not
  yet reported trained yields remaining 0 but **not**
  complete — the progress count follows levels, the SP
  figure follows SP, and neither impersonates the other.

### 6.3 Training time for one entry

```rust
pub fn attribute_value(attrs: &CharacterAttributes, attribute_name: &str) -> Option<i32>
pub fn training_minutes(sp_remaining: i64, primary: i32, secondary: i32) -> Option<i64>
```

- `attribute_value` matches the five lowercase extract
  strings exactly (`"charisma"`, `"intelligence"`,
  `"memory"`, `"perception"`, `"willpower"` — the full
  value set verified in source 2) to the five
  `CharacterAttributes` fields. Any other string → `None`.
  No case folding: the extract's vocabulary is fixed and
  verified, and silently accepting variants would hide
  extract drift (rank 1). Flutter's name-map (source 4,
  `_getAttributeValue`) is the shape precedent; its
  20/20 fallback on a miss is rejected.
- Rate is `primary as f64 + secondary as f64 / 2.0` SP
  per minute (section 3.2). Minutes are
  `(sp_remaining as f64 / rate).ceil() as i64`.
  `sp_remaining <= 0` → `Some(0)`. Rate `<= 0.0` → `None`:
  a partially defaulted attributes payload deserializes
  missing fields to 0 (source 7 models default every
  field), and 0/0 must read as unavailable, never as
  infinite or as a panic.

### 6.4 Plan progress (the only aggregation)

```rust
pub struct EntryEstimate {
    pub skill_id: i64,
    pub trained_level: Option<i32>, // None = skills not loaded
    pub complete: bool,
    pub sp_remaining: Option<i64>,
    pub minutes: Option<i64>,
}
pub struct PlanProgress {
    pub entries: Vec<EntryEstimate>, // plan order
    pub complete_count: usize,
    pub total_sp_remaining: Option<i64>,
    pub total_minutes: Option<i64>,
}
pub fn plan_progress(
    plan: &SkillPlan,
    sde: &Sde,
    trained: Option<&BTreeMap<i64, TrainedSkill>>,
    attributes: Option<&CharacterAttributes>,
) -> PlanProgress
```

(`&Sde` is the one catalogue dependency, taken the same
way fitting-resources takes `&FittingTypes`, source 7 —
bundled static data, not state.) Rules:

- `trained = None` (skills bundle not Ready): every
  entry gets `trained_level: None`, `complete: false`,
  SP/minutes `None`; totals `None`. The plan still
  renders and edits (section 8.4 exact words).
- `trained = Some(map)`: a missing key means untrained
  (level 0, 0 SP) — the catalogue's own `unwrap_or(0)`
  precedent (`src/ui/skills.rs:156`). Duplicate trained
  rows upstream have already collapsed last-wins in the
  `BTreeMap` the view builds (the `trained_levels`
  collect precedent).
- Unknown skill or rank ≤ 0 → that entry's SP and
  minutes are `None`; `trained_level`/`complete` still
  resolve (they need no rank).
- `attributes = None`, an unrecognized attribute string,
  or a non-positive rate → that entry's minutes are
  `None`; SP remaining is unaffected. Attributes come
  only from a Ready `character_details` whose attributes
  section is `Ok` (section 8.1) — **never** a default.
- **Totals are all-or-nothing (rank 1):** `total_sp_remaining`
  is `Some` only when every incomplete entry has `Some`
  SP; complete entries contribute 0 and never block a
  total. Same rule, independently, for `total_minutes`.
  A partial sum is never presented as a plan total.
- Empty plan: counts 0/0, totals `Some(0)`/`Some(0)`
  (vacuously complete, matching Flutter's empty-plan
  100%, source 6). The UI words this case separately
  (sections 8.2, 8.4) rather than claiming training finished.
- Percent complete is **not** returned. The UI renders
  the bar fraction as `complete_count / entries.len()`
  with the empty case worded, not bar-fed 1.0 (a
  presentation choice at the call site, mirroring how
  the queue progress bar consumes a plain fraction,
  source 7). No rounded percent figure exists to drift
  from the count it summarizes.

## 7. App state and the action channel (LOCKED)

Plan state is a new sibling field set on `AppState`
(`src/app/state.rs`), never an addition to `SkillsData`
(its field set is a cross-builder contract, source 7).
The view never mutates plans and never touches storage:
it stamps **one** queued action, the shell drains it
(section 11), storage (live) or the demo applier applies
it, and the shell reloads the authoritative list back
into state. This is the fittings-write request/drain/
reload honesty shape (source 7) at local-database scale:
the screen only ever shows what storage confirmed, so a
failed save cannot leave a phantom plan on screen
(rank 2).

```rust
// SkillPlanAction lives in src/skills/plans.rs (section 13);
// the two working-state enums live in src/app/state.rs.
#[derive(Debug, Clone, PartialEq)]
pub enum SkillPlanAction {
    Create { character_id: i64, name: String, description: String },
    UpdateText { character_id: i64, plan_id: i64, name: String, description: String },
    DeletePlan { character_id: i64, plan_id: i64 },
    ReplaceEntries { character_id: i64, plan_id: i64, entries: Vec<SkillPlanEntry> },
}

#[derive(Debug, Clone, PartialEq)]
pub enum SkillPlanConfirm {
    DeletePlan { character_id: i64, plan_id: i64 },
    RemoveEntry { character_id: i64, plan_id: i64, skill_id: i64 },
}

#[derive(Debug, Clone, PartialEq)]
pub enum SkillPlanEditor {
    Create { character_id: i64 },
    Edit { character_id: i64, plan_id: i64 },
}
```

New `AppState` fields (all beside the existing view-local
state, all memory-only except the loaded plans
themselves):

- `pub skill_plans: LoadState<Vec<SkillPlan>>` — the
  active character's plans as last confirmed by storage
  (or by the demo applier). `LoadState` is the per-view
  bundle precedent; `Error` carries the section 8.6 load
  failure words' key, rendered without Retry-into-ESI
  semantics (section 8.2).
- `pub skill_plans_owner: Option<i64>` — the character
  `skill_plans` was loaded for (the
  `fittings_import_owner` precedent). The view renders
  plans only when `skill_plans_owner == active_character_id`;
  otherwise it renders the loading words. A list can
  therefore never display under the wrong character even
  for one frame during a switch (rank 4).
- `pub selected_skill_plan_id: Option<i64>` — the plan
  whose detail is shown. Cleared whenever a reload no
  longer contains it (checked at render, section 8.2,
  and on reload, section 11).
- `pub skill_plan_editor: Option<SkillPlanEditor>` plus
  `pub skill_plan_name_draft: String` and
  `pub skill_plan_description_draft: String` — drafts
  are seeded once when the editor opens (blank for
  Create; the plan's current text for Edit) and are
  user text: never logged (section 10), never persisted
  except through a confirmed action.
- `pub skill_plan_confirm: Option<SkillPlanConfirm>` —
  the armed inline confirmation, stamped with character
  and plan like `FittingWriteConfirm`. It is stale —
  and cleared before render — when the stamped character
  is not active, the stamped plan is not in the loaded
  list, or (RemoveEntry) the stamped skill is not in
  that plan: *a confirmation never outlives the thing it
  confirms* (the fittings-write rule, source 7).
- `pub skill_plan_action: Option<SkillPlanAction>` —
  the one-slot drain channel. The view sets it only
  when it is `None`; a click that finds it occupied is
  ignored that frame (the shell drains every frame
  before render tests run, so occupancy is a one-frame
  condition, and dropping beats queueing two mutations
  built from the same stale snapshot).
- `pub skill_plan_picker_open: bool` and
  `pub skill_plan_picker_search: String` — picker state
  for the selected plan. A separate search string from
  `state.skill_search` (the catalogue's), because both
  boxes live in the same view and must not filter each
  other.
- Demo only: `pub demo_skill_plans: HashMap<i64, Vec<SkillPlan>>`
  and `pub demo_next_plan_id: i64` (section 9).

Add, remove, and reorder in the view each build the full
replacement `entries` vec from the currently rendered
plan and stamp `ReplaceEntries`. There is no per-operation
action vocabulary beyond the four above: whole-vec
replacement is what storage does anyway (section 5.3),
so the channel matches the write shape exactly and there
is one mutation semantic to validate, log, and test.

**Reset rules** (Builder B, mirroring the fittings blocks
at source 7 lines 954-970 / 1042-1051 / 1083-1090, with a
`[PLANS]` debug line at each site like its neighbors):
on character switch, on removal of the active character,
and in the no-characters-remain branch —
`skill_plans = Loading` (or `Empty` in the last branch),
`skill_plans_owner = None`, selection/editor/drafts/
confirm/action/picker all cleared. Same-character
reselect clears nothing. `demo_skill_plans` is keyed by
character and is **not** cleared on switch (the
`summaries`/`portraits` keyed-map precedent); removing a
demo character drops its map entry. An action stamped
for a character who is no longer active when drained is
dropped whole by the shell (section 11) — the reset
clearing the slot makes this belt-and-suspenders, and
both layers are locked.

## 8. UI surfaces and exact wording (LOCKED)

All in `src/ui/skills.rs`, inside the existing Skills
view. Every user-visible string in this section is
verbatim-locked; builders implement them as small pure
`fn`s or `const`s (the fittings-write wording-function
precedent, source 7) so section 12 can pin them without
a frame. Skill names always resolve through
`Sde` (`skill_name_quiet` for per-frame rows); a raw
numeric skill id never renders. Numbers render through
`widgets::format_sp` and durations through
`widgets::format_countdown(minutes * 60)`.

### 8.1 Placement and estimate inputs

`show()` keeps its current structure and early return
(no character → `no_character_panel`). The plans section
renders **after** the existing `state.skills` match, so
plans are visible and editable in every skills load
state; only their estimates degrade. Before rendering,
the view derives estimate inputs once per frame:

- trained map: `Some(BTreeMap<skill_id, TrainedSkill>)`
  from a Ready skills bundle (`trained_skill_level` and
  `skillpoints_in_skill` per row; `active_skill_level`
  is never read — the parity rule in fitting
  resources, source 7), else `None`;
- attributes: `Some(&CharacterAttributes)` only from a
  Ready `character_details` with `attributes: Ok(..)`,
  else `None`.

The section heading is `Skill plans`, preceded by a
separator, matching the view's section idiom. Demo adds
exactly one extra line under the heading (section 9);
`widgets::mode_notice` at the top of the view is
unchanged and is not duplicated.

### 8.2 Plan list

By `skill_plans` state (owner guard first, section 7):

- Owner mismatch or `Loading`:
  `Loading skill plans...` (loading panel).
- `Error`: `Skill plans could not be loaded from local storage.`
  via `error_panel` (no Retry button — nothing here is
  retryable into ESI, and the next character switch or
  restart reloads; section 11 records how this state is
  set). No create affordance renders in this state:
  inventing plans over an unreadable store would risk
  overwriting them on the next successful load (rank 2).
- `Empty`, or Ready with zero plans (both render the
  same): `No skill plans yet for this character.`
  followed by the create affordance.
- Ready with plans: above the rows, a button
  `New skill plan` opening the section 8.3 editor in
  Create mode. (In the zero-plans state the same button
  label is used, so there is one create string in the
  app.) Then one block per plan, in loaded order
  (most recently updated first, section 5.3):
  - a selectable button label of exactly `{name}`, which
    selects/deselects that plan's detail (section 8.4),
    followed by the summary line from that plan's
    `PlanProgress`:
    - trained loaded, non-empty plan:
      `{complete} of {total} complete` plus, when
      `total_sp_remaining` is `Some` and > 0,
      ` — {sp} remaining` (via `format_sp`), plus, when
      `total_minutes` is `Some` and > 0,
      ` — about {countdown}`;
    - when either total is `None` for a non-empty plan,
      the affected part is simply omitted from the list
      summary (the detail carries the exact unavailable
      words, section 8.4) — the list never shows a
      partial total and never explains at length;
    - empty plan: `No skills in this plan yet.`;
    - trained not loaded: `{total} skills` when total is
      not 1, `1 skill` when it is (no completion claim).
  - a progress bar (`egui::ProgressBar`) only when
    trained is loaded and the plan is non-empty,
    fraction `complete_count / entries.len()` as `f32`,
    text `"{:.0}%"` of the fraction (the queue bar's
    format, source 7). No bar otherwise — a bar over an
    unknown or an empty denominator would claim a
    measurement that does not exist (rank 1; this is
    where this design deliberately differs from
    Flutter's empty-plan 100% rendering while keeping
    its 100% arithmetic internally, section 6.4).

Selection validity is re-checked every frame: a
`selected_skill_plan_id` absent from the loaded list is
cleared and the picker closed, before anything renders
under it.

### 8.3 Create and rename editor (one inline block)

An inline block in the plans section (never a modal —
the fittings-write rejection of modal dialogs stands,
rank 5). Opened by `New skill plan` (Create) and by the
detail's `Rename plan...` (Edit, section 8.4). Drafts
seed once on open. Contents:

- Heading: `Create skill plan` (Create) or
  `Rename skill plan` (Edit).
- Label `Plan name` and a single-line text edit bound to
  the name draft; label `Description (optional)` and a
  multiline text edit bound to the description draft.
  (Flutter's field labels, source 6.)
- Validation runs every frame through
  `normalize_plan_text` (section 4, I4); on `Err` the
  exact message renders in the error color and the save
  button is disabled:
  - `Plan name is required`
  - `Plan name must be 100 characters or less`
  - `Description must be 500 characters or less`
- Buttons: `Create plan` / `Save name` (enabled only
  when valid and, for Edit, only this — there is no
  "unchanged" special case; saving identical text is a
  legal no-content update that re-stamps `updated_at`)
  and `Cancel` (always enabled). A save click stamps
  `Create`/`UpdateText` with the **normalized** strings,
  closes the editor, and clears the drafts; the new or
  renamed plan appears only when the shell reloads it
  (sections 7, 11). On successful Create the shell
  selects the new plan (section 11, the one place
  selection is set outside the view, because only
  storage knows the new id).
- The editor is stale — cleared before render — when
  its stamped character is not active or (Edit) its plan
  left the loaded list. Opening the editor clears any
  armed confirmation, and arming a confirmation closes
  the editor: one pending intent at a time.

Text-entry focus integrates like every other box in the
app: focus state OR-s into `state.text_input_focused`
(the `search_box` return precedent) so single-key
navigation stays suppressed while typing a plan name.

### 8.4 Plan detail (the selected plan)

Rendered directly under the list when a plan is
selected, full width (this app has no navigation stack;
the fittings detail is the shape precedent):

- Heading: `Plan: {name}`.
- The description, verbatim as stored, on its own line —
  only when non-empty.
- Buttons row: `Rename plan...` (opens the editor),
  `Add skills...` / `Hide skill picker` (toggles
  section 8.5), `Delete plan...` (arms the confirmation
  below). Arm buttons use the trailing-`...` idiom of
  the shipped `Delete character...` button.
- Delete confirmation block (armed state replaces the
  buttons row; fittings delete-confirm shape, local
  words — this deletes from this device, not from EVE):
  - heading `Delete plan "{name}"?`
  - summary `"{name}" and its {n} entries will be deleted from this device. This cannot be undone.`
    with `{n}` the entry count (`1 entry` is **not**
    special-cased: the fittings copy precedent uses a
    bare count with a plural noun, and one format string
    is one string to pin). Empty plans use the same
    sentence with `0 entries`.
  - `Confirm delete` → stamps `DeletePlan`, clears the
    confirmation and the selection; `Cancel` → clears
    the confirmation only.
- Entry rows, in plan order, inside a vertical
  `ScrollArea` with `max_height(320.0)` (the catalogue's
  bound). Row text, exactly:
  - base: `{position}. {skill name} — target level {target}`
    with `{position}` 1-based;
  - complete: base + ` — trained level {trained}, complete`;
  - incomplete, full estimate: base +
    ` — trained level {trained}, {sp} remaining, about {countdown}`;
  - incomplete, SP only: base +
    ` — trained level {trained}, {sp} remaining, training time unavailable`;
  - incomplete, no SP (unknown skill/rank): base +
    ` — trained level {trained}, estimate unavailable`;
  - skills not loaded: base + ` — trained level unavailable`.
- Per-row buttons: `Move up` (disabled on the first
  row), `Move down` (disabled on the last), `Remove...`.
  Move buttons stamp `ReplaceEntries` with the two
  entries swapped — no confirmation (reorder is
  non-destructive and instantly reversible). `Remove...`
  arms the entry confirmation (Flutter confirmed
  removal, source 6; deletion of user data confirms in
  this app, rank 2), rendered as one block under the
  entry list so rows do not move while confirming:
  - heading `Remove "{skill name}" from "{plan name}"?`
  - summary `"{skill name}" will be removed from this plan. Trained levels in EVE are not changed.`
  - `Confirm remove` → stamps `ReplaceEntries` without
    that skill; `Cancel` clears.
- Totals block under the entries, exactly one of:
  - full: `Total remaining: {sp} — about {countdown}`
  - SP only: `Total remaining: {sp} — training time unavailable: character attributes are not loaded.`
  - any incomplete SP unknown:
    `Total remaining: unavailable (one or more skills could not be estimated).`
  - skills not loaded:
    `Estimates will appear when trained skills are loaded.`
  - all complete (non-empty): `All target levels reached.`
  - empty plan: `No skills in this plan yet. Add skills to get started.`
  The SP-only sentence names the attributes reason
  because that is the only way SP can be `Some` while
  minutes are `None` for **every** contributing entry
  through the attributes path; when minutes are `None`
  for a per-skill reason (unrecognized attribute string,
  non-positive rate) the same sentence is used — the
  per-entry rows already say only "training time
  unavailable", and distinguishing sub-reasons in the UI
  would require wording no body grounds. Recorded in
  section 15, item 4.
- Disclosure line, always under the totals for any
  non-empty plan when skills are loaded:
  `Estimates use this character's current attributes as loaded. They ignore the training queue and any future attribute remap.`
  Omitted only with the "skills not loaded" totals
  line, which already says estimates are absent. No
  claim is made about implants: whether the loaded
  attribute values already include them is not stated by
  any inspected body, so the words stay at "as loaded".

### 8.5 Add-skill picker (plans working state only)

Under the detail buttons row when open, for the selected
plan:

- One `widgets::search_box` bound to
  `skill_plan_picker_search` with hint
  `Search skills to add` and `grab_focus = false` (the
  `/` focus shortcut belongs to the catalogue box in
  this view; the picker never steals it). Its focus
  feeds `text_input_focused` like section 8.3.
- Results from `sde.search_skills(query)` (empty query →
  all 495, sorted by name — the accessor's contract),
  in a `ScrollArea` with `max_height(320.0)`. No virtual
  windowing: 495 label rows is the catalogue's own
  per-frame scale and needs no new machinery.
- No matches: `No skills match the search.` (the
  catalogue's exact string, `src/ui/skills.rs:171`).
- Each result row: `{skill name} — trained level {n}`
  with `{n}` from the trained map (`0` when untrained;
  the whole `— trained level {n}` suffix becomes
  `— trained level unavailable` when skills are not
  loaded), then exactly one of:
  - skill already in this plan: ` — already in this plan`
    and no buttons (invariant I1 at the surface);
  - skills loaded and trained level is 5:
    ` — already trained to level 5` and no buttons;
  - otherwise five small buttons labelled `1` `2` `3`
    `4` `5`, each `add_enabled(level > trained_level)`
    (when skills are not loaded, all five enabled —
    there is no trained fact to disable against, and
    adding at any target is still a legal plan). A click
    stamps `ReplaceEntries` appending
    `{skill_id, target_level: level}` at the end
    (Flutter appended at the next sort order, source 6)
    and leaves the picker open for the next add.
- The picker renders nothing when no plan is selected
  or plans are not Ready for the active character —
  adds target the rendered plan or nothing.

### 8.6 Empty states, all collected

| Case | Exact rendering |
|---|---|
| No active character | whole view: shipped `no_character_panel` (unchanged) |
| Plans loading / wrong owner | `Loading skill plans...` |
| Plans load error | `Skill plans could not be loaded from local storage.` |
| Zero plans | `No skill plans yet for this character.` + `New skill plan` |
| Empty selected plan | `No skills in this plan yet. Add skills to get started.` (+ list-summary form `No skills in this plan yet.`) |
| Picker, no search matches | `No skills match the search.` |
| Bundled catalogue empty | picker shows `Bundled skill catalogue is unavailable.` (the catalogue section's exact string, `src/ui/skills.rs:143`) and no rows |

### 8.7 Status messages (set by the shell on drain, section 11)

- Create ok: `Skill plan created.`
- Rename ok: `Skill plan renamed.`
- Delete ok: `Skill plan deleted.`
- Entries ok (add/remove/reorder share one message —
  the user can see the change on screen):
  `Skill plan updated.`
- Any storage failure:
  `Skill plan could not be saved. Nothing was changed.`
- Action for a plan/character no longer present
  (repository `false`):
  `That skill plan is no longer there. Nothing was changed.`

No status message contains a plan name or description
(user text stays out of status strings and logs,
section 10).

## 9. Demo behavior (LOCKED)

Decision: **demo plans work, in memory only.** The
precedent split in source 7 resolves cleanly: what demo
refuses is writes *to EVE* (fittings-write:
*"Demo mode uses sample data. Saving or deleting fittings
in EVE is disabled."*); what demo allows is local working
state (fittings-import: paste, parse, render — memory
only, never persisted). Plans are purely local user data,
never EVE writes, so they follow the import precedent —
with the hard rank-3 guard that demo plan data can never
reach the live database:

- Demo plans live in
  `state.demo_skill_plans: HashMap<i64, Vec<SkillPlan>>`
  keyed by demo character id, plus a session counter
  `demo_next_plan_id` starting at 1. There are no bundled
  fixture plans; both demo characters start at the
  zero-plans empty state.
- The view is mode-blind: it stamps the same
  `SkillPlanAction`s and renders the same
  `state.skill_plans`. Routing happens in exactly one
  place, the shell drain, through a pure decider in
  `src/app/shell.rs` in the `decide_fitting_write_start`
  shape (source 7):

  ```rust
  enum SkillPlanRoute { DemoMemory, LiveDatabase, Unavailable }
  fn decide_skill_plan_route(demo: bool, backends_wired: bool) -> SkillPlanRoute
  ```

  `demo == true` → `DemoMemory` regardless of backends
  (demo is checked **first**, so the live-database arm is
  unreachable in demo even when a database is open for
  name hydration, source 7); live with backends →
  `LiveDatabase`; live without backends → `Unavailable`
  (action dropped, status `Skill plan could not be saved. Nothing was changed.`).
- In `DemoMemory`, the shell applies the action with a
  pure function in `src/skills/plans.rs`,
  `apply_demo_action(plans: &mut Vec<SkillPlan>, next_plan_id: &mut i64, action: &SkillPlanAction, now: &str) -> DemoApplyOutcome`,
  which takes **no connection** — demo persistence is
  impossible by signature, not by discipline. It runs
  the same `normalize_plan_text`/`validate_plan` checks,
  stamps `created_at`/`updated_at` from `now`, allocates
  ids from the counter, keeps list order most-recently-
  updated-first to match the live ordering, and reports
  the same outcome vocabulary as storage (created id /
  applied / not-found / invalid) so the shell sets the
  same status strings in both modes. After applying, the
  shell copies the character's vec into
  `state.skill_plans` (the same reload step as live).
- Character switching in demo loads the newly active
  demo character's vec (or empty) into `skill_plans` at
  the shell's existing demo `apply_character` point
  (section 11). Demo→live and live→demo transitions
  reload from the destination mode's source; demo plans
  are left in the map (session-scoped) and never copied
  to SQLite, and live plans are never copied into the
  demo map.
- The one demo label for plans, rendered under the
  section heading whenever `state.demo`, verbatim:
  `Demo mode: skill plans are kept in memory for this session and are not saved.`
  It renders in place of nothing (an extra line);
  estimates in demo are fully live, because demo carries
  trained skills and attributes (source 3, source 7) and
  section 6 needs no mode knowledge.

## 10. Logging (LOCKED)

New tag `[PLANS]`, following the repository's
`[FEATURE]`-tagged `tracing` discipline. Logs carry
feature tags, character ids, plan ids, and counts —
**never** plan names, descriptions, search text, or any
other user-entered or user-chosen text, and never tokens
(this slice touches none). Skill ids are also kept out
of plan logs: "counts only" is the slice rule, and an
estimate problem is diagnosable from the SDE-miss
warnings the catalogue already emits. Locked call sites
(builders may add `debug` entry lines in the same shape,
never new payload):

- Repositories (`debug` entry, like its neighbors):
  `[PLANS] create_skill_plan character_id={}`,
  `[PLANS] update_skill_plan_text character_id={} plan_id={}`,
  `[PLANS] replace_skill_plan_entries character_id={} plan_id={} count={}`,
  `[PLANS] delete_skill_plan character_id={} plan_id={}`,
  `[PLANS] list_skill_plans character_id={}`.
  (`delete_character` keeps its existing `[CHAR]` line;
  no second line for the new tables.)
- Pure layer (`debug`, counts only, and only at
  function entry — the fitting pure-module restraint):
  `validate_plan` failures log the error kind without
  text: `[PLANS] plan rejected reason=duplicate_skill|bad_target|bad_text`.
  Estimate functions log nothing per call (they run per
  frame per plan; the portraits slice's per-frame log
  bug is the standing warning).
- State resets (`debug`, beside each `[FITTING]` neighbor):
  `[PLANS] clearing skill plans on character switch from={} to={}`
  and the removal/empty variants in the same words as
  their neighboring lines.
- View (`info` on confirmed user intent, mirroring
  `[FITTING] save confirmed … kept={} dropped={}`):
  `[PLANS] create requested character_id={}`,
  `[PLANS] rename requested character_id={} plan_id={}`,
  `[PLANS] delete confirmed character_id={} plan_id={} entries={}`,
  `[PLANS] entries replace requested character_id={} plan_id={} count={}`.
- Shell drain (`info` outcome / `warn` failure):
  `[PLANS] action applied route={demo|live} character_id={} plan_id={} plans={}`,
  `[PLANS] action dropped character_id={} reason=not_active|not_found|unavailable`,
  `[PLANS] plans loaded character_id={} plans={} entries={}`,
  `[PLANS] plans load failed character_id={} error={}`
  (the error is an `AppError` display string, never user
  text).
- `[PLANS]` joins `LOG_TAGS` in `src/ui/settings.rs`
  (array grows 14 → 15) so the in-app log filter can
  select it.

## 11. Integrator wiring (LOCKED)

All in `src/app/shell.rs` unless noted. The feature is
inert until this lands (Builder B's view compiles and
stamps actions nobody drains) — the accepted cost of a
zero-overlap split, recorded in section 13.

### 11.1 Loading plans into state (one helper, four call points)

```rust
fn load_skill_plans_into_state(&mut self)
```

Reads the active character (none → `skill_plans = Empty`,
owner `None`, return), then by route (section 9 decider):
demo → clone the character's demo vec (or empty) in;
live with backends → `list_skill_plans` under
`backends.db.lock()` (the shell's existing lock idiom);
live without backends → `skill_plans = Empty` with a
`debug` line (the shell already runs backend-less in
tests; emptiness, not error, is that mode's honest
state). On `Ok`: set `skill_plans = Ready(plans)`,
`skill_plans_owner = Some(active)`, drop a selection the
list no longer contains, log the loaded line. On `Err`:
`skill_plans = Error(...)` carrying only the key the
view maps to its fixed words (the view never renders a
raw storage error), owner set to the active character
(so the error states itself instead of spinning as
Loading), `warn` log. Call points, all existing seams:

1. Startup live path, immediately after
   `load_cached_state` for the active character — plans
   are local data and must be present before first
   render, offline included (no network is involved at
   any point in this slice).
2. The `last_active_id` change block: in the demo arm
   after `apply_character`, in the live arm beside
   `request_refresh("character-switch")`. Plans load
   synchronously here; they never wait for the refresh.
3. Demo entry/exit (the `seed_demo_state` path): after
   seeding, load from the now-current mode's source.
4. After every drained plan action (section 11.2):
   reload, so state always shows storage-confirmed data.

Plans are **not** part of the refresh persist block and
are never written by any ESI landing: the refresh code
gains no plan lines, and a refresh can neither create nor
delete a plan. `load_cached_state` itself is unchanged.

### 11.2 Draining `skill_plan_action`

In the shell's per-frame drain sequence (beside the
fittings-write drain), `take()` the action, then:

1. **Identity guard:** the stamped `character_id` must
   equal the current active character and name a known
   character; otherwise drop whole, log
   `reason=not_active`, no status change (the user who
   clicked is no longer looking at that character — the
   fittings landing rule at local scale).
2. **Route** via `decide_skill_plan_route` (section 9).
3. **Apply:** live → the matching section 5.3 call under
   one `db.lock()` with `now = Utc::now().to_rfc3339()`;
   demo → `apply_demo_action`. No async, no spawn: local
   SQLite under the already-held pattern (startup and
   refresh-landings already do synchronous writes under
   this lock; a plan write is smaller than a wallet
   upsert).
4. **Reload and report:** on success reload (11.1 point
   4) and set the matching section 8.7 status; a Create
   success also sets `selected_skill_plan_id` to the new
   id and closes the picker. On `Err` set the failure
   status and leave `skill_plans` exactly as it was (no
   reload — state must keep showing the last confirmed
   truth). On repository `false` set the no-longer-there
   status and reload (state disagreed with storage;
   storage wins).
5. A second action can only be stamped after this drain
   (section 7's occupied-slot rule), so mutations are
   strictly serialized one per frame at most.

Character deletion needs no new shell code: the existing
delete path (`delete_requested_id` → shell
`delete_character`) already calls the repository
function whose table list section 5.3 extends, and
`AppState::remove_character` gains only Builder B's
reset lines. The integrator verifies the call chain
end-to-end once (section 12, T21) rather than assuming
it — this sentence is the checklist item, not the
verification.

### 11.3 What the integrator does not do

No new scopes (`src/config.rs` untouched), no new ESI
endpoints, no refresh changes, no `View` changes, no
demo fixture changes (`src/demo/data.rs` untouched —
demo plans need no seeding hook because the map starts
empty), no settings persistence for selection or picker
state (session-only UI state, like every other view's).

### 11.4 Docs sweep (integrator commit)

- `README.md`: one line in the feature summary —
  `Local skill plans per character with SP and training-time estimates (stored on this device; never sent to EVE).`
  placed with the existing Skills feature wording;
  adjust to the file's exact format at integration time.
- `docs/engineering-journal/LEARNINGS.md`: one dated
  entry recording the section 3.1 conflict (Evidence:
  SDE attribute 275 + demo fixtures against the Flutter
  `2^(L-1)` formula; Mechanism: the Flutter calculator
  summed per-level increments of the wrong geometric
  ratio; Rule: *a ported formula is a claim — check it
  against committed data fixtures before shipping its
  numbers*).
- `docs/engineering-journal/DECISIONS.md`: one entry for
  "first user-authored rows: replace-whole-entries in a
  transaction, storage-confirmed reload, demo in memory"
  with rationale, the rejected alternatives from
  section 14, and revisit-when: *a second user-authored
  entity (notes, watchlists) should re-evaluate a shared
  CRUD shape*.

## 12. Test plan (LOCKED)

All expectations are hand-derived literals with the
arithmetic in a comment beside each assertion (standing
repo rule). No test may compute its expectation by
calling the function under test or by re-implementing
section 3 inline. Gates per commit, no exceptions:
`cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`,
`cargo test`, `cargo build`. Test names below are
locked; file placement follows the owner table.

**Pure SP/time (`src/skills/training.rs` tests):**

- T1 `cumulative_sp_matches_sde_formula_literals` —
  rank 1: L0 `0`, L1 `250` (250×1×1), L2 `1414`
  (250 × 5.656854249492381 = 1414.21… → round → 1414),
  L3 `8000` (250 × 32), L4 `45255`
  (250 × 181.01933598375618 = 45254.83… → 45255),
  L5 `256000` (250 × 1024). These four non-trivial
  values are exactly the demo-fixture witnesses of
  source 3 — the test comment says so.
- T2 `cumulative_sp_scales_by_rank_rounding_once` —
  rank 5 L3 `40000` (250×5×32), rank 5 L5 `1280000`,
  rank 5 L4 `226274`
  (250×5×181.01933598375618 = 226274.16… → 226274;
  comment: rank-1-base × 5 would give 226275 — this
  assertion is what pins round-once, section 6.1),
  rank 16 L5 `4096000` (250×16×1024), rank 2 L4 `90510`
  (500 × 181.019… = 90509.66… → 90510).
- T3 `cumulative_sp_rejects_missing_rank_and_clamps_level` —
  rank 0 → `None`, rank −1 → `None` (any level);
  level −3 behaves as 0 (`Some(0)` at rank 1), level 9
  behaves as 5 (`Some(256000)` at rank 1).
- T4 `sp_remaining_credits_partial_progress` —
  rank 1 untrained → L1 `250`; rank 1 trained 4 with
  45255 SP → L5 `210745` (256000 − 45255); rank 1
  trained 3 with 10000 SP → L4 `35255`
  (45255 − 10000: the 2000 SP past the level-3 threshold
  is credited); trained 3 with a stale 100 SP → L4
  `37255` (45255 − 8000: the level threshold wins over
  the stale figure, section 6.2); trained 5 → L5 `0`;
  trained 4 → target 3 `0`; rank 0 → `None`.
- T5 `training_minutes_ceilings_and_unavailable` —
  900 SP at 20/20 → `30` (rate 20 + 20/2 = 30; 900/30 =
  30 exactly — formula-shape witness shared with
  sources 4/5, comment notes 1800 SP/hour equivalence);
  50 SP at 20/20 → `2` (50/30 = 1.66… → ceil 2);
  210745 SP at 25/20 → `6022`
  (rate 35; 210745/35 = 6021.28… → 6022);
  210745 SP at 25/24 → `5696`
  (rate 25 + 12 = 37; 210745/37 = 5695.81… → 5696 —
  demo character 90000001's perception/willpower,
  source 7); 0 SP → `Some(0)`; rate at 0/0 → `None`;
  negative attribute pair → `None`.
- T6 `attribute_value_maps_the_five_extract_names_only` —
  the five exact strings map to their fields (distinct
  sentinel values per field); `"Perception"`, `""`, and
  `"luck"` → `None`.

**Progress aggregation (`src/skills/training.rs` tests,
bundled SDE via `Sde::load_bundled()` like its existing
tests):**

- T7 `plan_progress_sums_per_entry_times` — a plan with
  Gunnery (3300, rank 1, perception/willpower) trained 4
  (45255 SP) → target 5, and a second rank-1 entry built
  to distinguish per-entry ceiling from sum-then-ceil:
  assert the total equals the sum of the two per-entry
  minutes computed by hand in comments, and assert the
  per-entry values individually. (Builder A picks the
  second skill from the bundled extract and shows its
  arithmetic; the distinguishing property — total equals
  ceil-then-sum, not sum-then-ceil — must be visible in
  the literals, e.g. two 31-SP remainders at rate 30
  give 2 + 2 = 4, not ceil(62/30) = 3. If no bundled
  skill yields a 31-SP remainder naturally, synthesize
  it via `skillpoints_in_skill` one point below a
  threshold — partial SP is an input, section 6.2.)
- T8 `plan_progress_totals_are_all_or_nothing` — one
  entry with an unknown skill id (e.g. 999999) makes
  `total_sp_remaining` and `total_minutes` `None` while
  the known entry keeps its own `Some` values; making
  the unknown entry complete (trained row present at
  target) restores both totals (complete entries never
  block).
- T9 `plan_progress_without_inputs_is_unavailable_not_zero` —
  `trained: None` → all entries unavailable, totals
  `None`, `complete_count` 0; `attributes: None` with
  trained present → SP present, minutes `None` per
  entry and in total; empty plan → counts 0, totals
  `Some(0)`.
- T10 `plan_validation_enforces_invariants` (in
  `plans.rs`) — duplicate skill rejected; target 0 and
  target 6 rejected; empty/whitespace name → the exact
  `Plan name is required`; 101-char name and 501-char
  description → their exact strings (built with
  `"a".repeat(..)`, counted in comments); trimming
  normalizes (`"  PvP  "` accepted as stored `"PvP"`);
  a 100-char name and 500-char description accepted
  (boundary inclusive).

**Storage (`src/storage/` tests):**

- T11 `migrate_from_v1_adds_plan_tables_and_keeps_rows`
  (db.rs, per section 5.2 step 4) plus the updated
  version literal and a by-name plan-table count test.
- T12 `skill_plan_round_trip_preserves_order_and_text` —
  create → replace entries (3 entries) → list returns
  the plan with entries in insertion order, text
  fields and timestamps verbatim; second replace
  (reordered + one removed) lists exactly the new
  vector; update-text renames; delete removes plan and
  entries (list empty; direct count query on
  `skill_plan_entries` = 0 so orphans cannot hide).
- T13 `skill_plans_are_isolated_per_character` — plans
  for characters 1 and 2; listing each returns only its
  own; update/replace/delete scoped to the wrong
  character return `false` and change nothing;
  `delete_character(1)` removes character 1's plans and
  entries and leaves character 2's intact (extends the
  existing cascade test's shape).
- T14 `skill_plan_writes_validate_before_storing` —
  duplicate-skill entries and an out-of-range target
  are `Err` and store nothing (list still shows the
  prior entries); empty-name create is `Err`.
- T15 `skill_plans_list_most_recently_updated_first` —
  two plans with caller-supplied timestamps list
  newest-first; touching the older via replace-entries
  with a later `now` moves it first; equal timestamps
  fall back to higher `plan_id` first.

**State (`src/app/state.rs` tests, Builder B):**

- T16 `switching_character_clears_skill_plan_state`,
  `removing_active_character_clears_skill_plan_state`,
  `removing_last_character_empties_skill_plan_state` —
  the three reset sites, in the shape of the existing
  character-details reset tests; includes selection,
  editor, drafts, confirm, action, and picker clearing,
  and `skill_plans_owner` reset. Companion:
  `reselecting_same_character_keeps_skill_plan_state`.
- T17 `demo_plans_survive_demo_character_switch` (state
  level: keyed map untouched by switch; removed demo
  character's entry dropped).

**Wording + demo + routing:**

- T18 `plan_wording_matches_design_strings` (`src/ui/skills.rs`)
  — the wording `fn`s/`const`s pinned verbatim: delete
  heading/summary (with a sample name and count substituted,
  asserted as full expected strings), remove heading/
  summary, totals variants (full / SP-only / unavailable /
  skills-not-loaded / all-complete / empty), disclosure
  line, demo label, editor error strings via
  `normalize_plan_text` already covered in T10 (assert
  the UI reuses those values, not copies — one source).
- T19 `demo_action_applier_mutates_memory_only` (`plans.rs`)
  — create/rename/replace/delete through
  `apply_demo_action` produce the expected vec and ids
  allocate 1, 2, …; invalid input reports invalid and
  mutates nothing. (Taking no connection is the type-
  level proof; this test pins the semantics.)
- T20 `skill_plan_route_prefers_demo_memory` (`shell.rs`,
  integrator) — the full 2×2: (demo, backends) →
  DemoMemory in both demo cells; (live, backends) →
  LiveDatabase; (live, none) → Unavailable. Named so a
  future reorder of the checks fails loudly.
- T21 integrator end-to-end checklist (manual, recorded
  in the integrator commit message, not a unit test):
  delete a character in the running app's storage layer
  path and confirm plan rows are gone via T13's live
  equivalent already covered at repository level — the
  manual item is only the shell call-chain check of
  section 11.2's final paragraph (view Remove →
  `delete_requested_id` → repository `delete_character`
  with the extended list).

**What is deliberately not tested by new tests:** egui
rendering itself (no frame harness exists in this repo
for any view; wording and progress are pinned below the
render layer, T18/T7-T9), and live-EVE correctness of
the SP table (section 15, item 1).

## 13. Ownership split and commit plan (LOCKED)

Zero file overlap between builders. Shared contracts:
`SkillPlan` / `SkillPlanEntry` / `TrainedSkill` /
`PlanProgress` / `plan_progress` / `normalize_plan_text`
(section 4, 6); `SkillPlanAction` (section 7);
repository signatures (section 5.3);
`apply_demo_action` / `DemoApplyOutcome` (section 9).
Builder B compiles against A's contracts; the shell
compiles against both.

| Owner | Files | Commits (each gated by section 12's commands) |
|---|---|---|
| Builder A (storage + pure) | `src/skills/mod.rs`, `src/skills/plans.rs`, `src/skills/training.rs`, `src/lib.rs`, `src/storage/schema.sql`, `src/storage/db.rs`, `src/storage/repositories.rs` | `feat(skills): add grounded training estimates and plan model` (T1-T10, T19) · `feat(storage): add skill plan tables at schema v2` (T11) · `feat(storage): persist skill plans per character` (T12-T15) |
| Builder B (UI) | `src/app/state.rs`, `src/ui/skills.rs`, `src/ui/settings.rs` | `feat(plans): add skill plan state and action channel` (T16-T17, `LOG_TAGS`) · `feat(plans): manage skill plans in the Skills view` (T18) |
| Integrator | `src/app/shell.rs`, `README.md`, `docs/engineering-journal/` | `feat(plans): route, persist, and reload skill plans` (T20, section 11) · `docs(plans): disclose skill plans and record the formula lesson` (11.4) |

Builder order: A first (all three commits), B second,
integrator last. `SkillPlanAction` is defined by Builder
A in `src/skills/plans.rs` (it is part of the pure
mutation vocabulary the demo applier consumes);
`src/app/state.rs` imports it — section 7 shows it beside
the state types for readability, but its home is A's file,
which keeps the dependency direction state → skills and
never skills → state. Likewise `SkillPlanConfirm` and
`SkillPlanEditor` are Builder B's, in `state.rs`, since
nothing outside state and the view consumes them.
Commit format `type(scope): description`, small and
atomic, no attribution lines. Nobody pushes or merges;
the parent does.

## 14. Rejected alternatives (LOCKED)

- **Porting the Flutter SP formula** (`250 × rank ×
  2^(L-1)`): rejected on evidence, section 3.1 — it
  contradicts committed fixture data by 33× at rank 1.
  Fidelity to a retired bug is not parity.
- **Default 20/20 attributes / rank-1 fallback**
  (Flutter's behavior): rejected (rank 1). An estimate
  from invented attributes is indistinguishable on
  screen from a real one; unavailable words are honest
  and recoverable (attributes load on refresh).
- **Persisting character attributes** so estimates work
  before the first refresh after restart: rejected for
  this slice (rank 5 blast radius): it adds an
  ESI-mirror table, refresh-persist writes, and a
  staleness question ("attributes as of when?") to fix
  a seconds-long window that already ends with the
  startup refresh. The degraded wording (section 8.4)
  covers the window. Revisit if users report planning
  offline against cached characters as a real workflow.
- **Optimistic UI mutation** (view edits state, shell
  persists best-effort): rejected (rank 2). The
  storage-confirmed reload costs one small query per
  action and makes "on screen" mean "saved".
- **Granular entry actions** (AddEntry / RemoveEntry /
  MoveEntry verbs end to end): rejected (rank 5).
  Storage replaces the whole vector in one transaction
  regardless (the `replace_skill_queue` precedent);
  granular verbs would be three validation orderings
  for one write shape.
- **Flutter's shared-rate total**
  (`calculateTotalTrainingTime`): rejected (section
  3.2) — skills in one plan train at different attribute
  pairs, and Flutter's own progress path already summed
  per-entry times.
- **Percent-complete as a stored/returned figure**:
  rejected (section 6.4) — a rounded percent drifts
  from the count beside it; the bar consumes the raw
  fraction.
- **Duplicates allowed, Flutter-literal**: rejected
  (invariant I1). Flutter's own remove/reorder keying
  proves duplicates were assumed away; enforcing the
  assumption is the bug fix, not a behavior change
  anyone could rely on.
- **Foreign keys with `ON DELETE CASCADE`**: rejected
  (rank 5) — the schema file and connection setup have
  no FK machinery; one slice does not retrofit it for
  two tables. Explicit transactional cascades are the
  house style and are tested as such (T12/T13).
- **Demo plans cleanly unavailable** (the other
  permitted reading of the slice goal): rejected in
  favor of section 9. The refusal precedent governs
  EVE writes; plans write nothing to EVE, and the demo
  is the app's try-before-sign-in surface. The cost —
  one pure applier and a routing decider — is small and
  buys a fully exercisable feature with no account.
- **A separate Plans view**: rejected (rank 5, Flutter
  parity): a new `View` variant churns nav keys, `ALL`
  ordering tests, and startup-view persistence for a
  section that belongs beside the queue and catalogue
  it summarizes.

## 15. Discrepancies and open risks (recorded honestly)

1. **Nothing here is live-verified against EVE.** The
   SP table rests on the SDE description plus invented
   demo fixtures that agree with it at rank 1. A real
   character's `skillpoints_in_skill` at a known level
   (visible in the shipped Skills view after any
   refresh) settles it definitively; until someone
   checks, estimates are marked "about" in the UI and
   this item stays open. If live data contradicts
   section 3, the fix is one function and its literals
   (T1/T2 localize the blast radius by design).
2. **Demo fixtures are rank-inconsistent.** Three
   rank-2 demo skills (3310, 3330, 3394) carry rank-1
   SP totals (verified by scan against the bundled
   extract). Consequences: fixtures are used as
   cumulative-shape evidence only (section 3.1); in
   demo, estimates for those three skills will show SP
   remaining computed from the level threshold (the
   section 6.2 `max` rule), which is self-consistent
   but will not match the fixture's own SP figure if a
   user compares screens. Fixtures are not modified in
   this slice (they are other slices' test data);
   flagged for whoever next regenerates demo data.
3. **Level-2 rounding has no fixture witness.** Level 2
   is 1414 under round-once and would be 1415 under
   always-ceil; fixtures cover only levels 3/4/5, where
   round and ceil agree. The worst case is a 1-SP
   error in estimates crossing level 2 (≤1 minute of
   displayed time). Round-once is the natural reading
   of a formula whose other values land on integers;
   item 1's live check resolves this too.
4. **The SP-only totals sentence names one reason.**
   Minutes can be `None` from unloaded attributes, an
   unrecognized attribute string, or a non-positive
   rate; the totals line says "character attributes
   are not loaded" for all three (section 8.4). The
   first is the only reachable one with the committed
   extract (all 495 attribute strings verified,
   attribute values come from ESI/demo and are positive
   in every inspected payload), so the sentence is
   accurate for every case this build can produce; if
   the extract ever emits a sixth attribute name, the
   wording becomes wrong while the math stays safe.
   The extract-regeneration hazard in discovery (the
   stale `skills.py` extractor would strip rank and
   attributes if re-run) compounds this: a regenerated
   `skills.json` without rank degrades every estimate
   to unavailable rather than to wrong numbers — the
   designed failure direction (rank 1) — but the
   generator fix itself is out of this slice's scope.
5. **Whole-vec replacement rewrites rows on every
   reorder.** A plan with hundreds of entries rewrites
   hundreds of rows per move-click. Bounded harm (local
   SQLite, one transaction, human click rate) and the
   same shape as queue persistence; a per-row order
   update is the obvious optimization if plan sizes
   ever make it matter.
6. **`updated_at` ordering granularity.** Timestamps are
   second-resolution RFC 3339 text; the `plan_id DESC`
   tiebreak (section 5.3) means two edits inside one
   second order by creation sequence, which may not be
   edit sequence. Cosmetic only — list order carries no
   semantics.
7. **Attributes section tolerance cuts both ways.**
   `character_details` is fetched tolerantly (source 7):
   if only the attributes sub-fetch fails, every other
   section renders and plan times quietly become
   unavailable until the next successful refresh. That
   is the designed degradation, but nothing in the
   Skills view today surfaces *why* attributes are
   missing (the Character view owns section errors).
   The totals sentence tells the user the fact; the
   cause lives one view away. Accepted, recorded.
