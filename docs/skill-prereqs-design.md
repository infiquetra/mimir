# Skill prerequisites slice — locked design

Branch: `feat/rust-skill-prereqs`. Base: `develop` at
`27f79d2` (merge of the skill-plans slice; 700 tests
green at base). This document locks the design for using
the already-bundled skill-prerequisite data in the Rust
app: parse the `prerequisites` field that
`assets/sde/skills.json` already carries on 466 of its
495 skill types, show each skill's prerequisites in the
Skills catalogue and in the skill-plan picker, and warn
on skill-plan entries whose prerequisites the character
has not trained. Warnings are advisory only: nothing in
this slice blocks adding, keeping, or reordering a plan
entry. The slice is read-only against EVE: no new OAuth
scopes, no new network calls, no storage schema change.
Where this document and an earlier document disagree
about prerequisite behaviour, this document wins for
prerequisites only; every shipped behaviour (queue,
catalogue rows, skill plans and their estimates) stays
exactly as shipped except for the additive labels
locked in section 8.

The one hard question this slice had to answer first is
what "prerequisites are unmet" means: trained levels
only, or trained levels plus earlier entries in the
same plan; direct prerequisites only, or the whole
transitive chain. Section 3 records the evidence and
the verdict — **trained-only, direct-only** — and the
exact comparison every warning and every test literal
must follow. The verdict rests on the retired Flutter
prerequisite service, whose semantics body is evidence
(section 0) even though its plan-flow warning dialog
was never shown to a user in Flutter and therefore
supplies no display precedent (sections 3 and 8.1).

## 0. Grounded evidence (inspected bodies)

Every field shape, count, comparison, and wording
precedent below traces to one of these sources, all
read directly this session (Rust sources at `27f79d2`,
Flutter via `git show ed698d3:...`, bundled assets on
disk verified by scan).

1. **Bundled skill extract** `assets/sde/skills.json`
   (495 types, 24 groups, 167,138 bytes). 466 of 495
   types carry a `prerequisites` array; 29 omit the key
   entirely (it is never `null` and never an empty
   array). Every one of the 749 prerequisite edges has
   exactly two keys, `skillId` (integer) and `level`
   (integer). All 749 levels lie in 1..=5 (level 1: 87,
   level 2: 57, level 3: 178, level 4: 138, level 5:
   289). Fan-out is at most 3 direct prerequisites per
   skill (0 edges: 29 types, 1: 226, 2: 197, 3: 43).
   Every edge's `skillId` resolves to a type in the
   same file (196 distinct targets); no type lists the
   same prerequisite twice, no skill requires itself,
   and a full depth-first walk of all 495 nodes finds
   no cycle. The longest chain is 6 edges (13 skills,
   including all four Titans). Witness rows quoted in
   section 12: Medium Hybrid Turret (3304) requires
   Gunnery (3300) level 3 and Small Hybrid Turret
   (3301) level 3; Small Hybrid Turret (3301) requires
   Gunnery (3300) level 1; Gallente Titan (3344)
   requires Capital Ships (20533) level 5, Gallente
   Battleship (3336) level 3, and Leadership (3348)
   level 5, in that file order; Gunnery (3300) carries
   no `prerequisites` key.
2. **Current Rust SDE parser** `src/names/sde.rs`.
   `SdeSkillType` (lines 27–42) deserializes `typeId`,
   `typeName`, `groupId`, `rank`, `primaryAttribute`,
   and `secondaryAttribute`, each with
   `#[serde(default)]`, so a missing key degrades to a
   zero value rather than failing the load; there is
   no `prerequisites` field, so serde silently drops
   the source-1 data today (no match for
   `prereq` anywhere in `src/`). Load path:
   `Sde::load_bundled()` → `include_str!` →
   `Sde::from_json` → `serde_json::from_str::<SdeFile>`
   → `by_id` / `group_by_id` indexes, one parse per
   process (lines 64–93). Accessors reused below:
   `skill()` (line 105), `skill_name()` (111, warns on
   a miss), `skill_name_quiet()` (123, silent on a
   miss, for per-frame rows); both name accessors fall
   back to the literal string `"Unknown Skill"` so a
   raw numeric EVE id never renders. The bundled-load
   invariant test `bundled_sde_loads_and_resolves_known_skills`
   (lines 181–188) asserts count > 400 and pins
   Gunnery 3300 and Small Hybrid Turret 3301.
3. **Retired Flutter prerequisite service**
   `lib/features/skills/domain/skill_prerequisite_service.dart`
   at `ed698d3` (read in full). Two distinct methods
   that must not be conflated:
   `getUnmetPrerequisites` checks **direct
   prerequisites only** — one SDE (Static Data Export)
   lookup, no descent — comparing each edge's required
   level against `skillRepository.getTrainedLevel`
   (a skill absent from the character's trained rows
   reads as level 0), returning one
   `PrerequisiteRequirement{skillId, skillName,
   requiredLevel, trainedLevel}` per edge with
   `trainedLevel < requiredLevel`.
   `getAllPrerequisites` walks **recursively** behind a
   single `visited` set of skill ids, recursing before
   appending so dependencies precede dependents, and
   returns only unmet nodes carrying `depth` (0 =
   direct) and `forSkillId`. `canTrainSkill` is
   `getUnmetPrerequisites(...).isEmpty`. The
   `targetLevel` parameter of all three methods is
   accepted and logged but **never read in any
   comparison**. `filterPrerequisitesNotInPlan`
   filters by skill-id presence only, ignoring plan
   target levels entirely. A prerequisite whose name
   lookup fails falls back to the string
   `'Skill #${id}'`. `PrerequisiteRequirement`
   exposes `isUntrained` (`trainedLevel == 0`) and
   `description` (`'$skillName (need level
   $requiredLevel, have $trainedLevel)'`).
4. **Retired Flutter wiring** at `ed698d3` (call-site
   greps over `lib/`, `test/`, `integration_test/`).
   `getAllPrerequisites` and
   `filterPrerequisitesNotInPlan` have **zero
   production call sites** (service unit test only).
   The plan flow (`add_to_plan_dialog.dart` and the
   plan screens/providers) contains **zero**
   prerequisite references: adding to a plan went
   straight to `addSkillToPlan` with no check, no
   warning, and no auto-add. The service was live in
   exactly the catalogue: two filter modes
   (`canTrain`, `havePrereqs`) that are byte-identical
   loops over `canTrainSkill`, and a per-row catalogue
   check that dimmed the row, disabled its Add button,
   and tooltiped `'Cannot train (prerequisites not
   met)'`, defaulting to trainable while loading.
5. **Retired Flutter warning dialog**
   `lib/features/skills/presentation/widgets/prerequisite_warning_dialog.dart`
   at `ed698d3` (read in full). It has **zero
   production instantiations** — its only references
   outside itself are its widget test — so it was
   never shown to any user and is strings-only
   evidence, not a shipped pattern. Its strings:
   `'Unmet Prerequisites'`, `'This skill requires the
   following prerequisites to be trained first:'`,
   `'Missing Prerequisites'`, `'Target: Level
   $targetLevel'`, `'Need level $requiredLevel
   (untrained)'` / `'Need level $requiredLevel (have
   $trainedLevel)'`, and three buttons `'Add with
   Prerequisites (Recommended)'`, `'Add Anyway'`,
   `'Cancel'` returning a three-way result enum.
   Nowhere in the Flutter catalogue, skill list, or
   plan detail was a prerequisite *list* (names and
   levels) ever rendered; the catalogue showed only
   the boolean of source 4.
6. **Retired Flutter tests** at `ed698d3`.
   `skill_prerequisite_service_test.dart` pins:
   can-train true with no prerequisites; false at
   trained 3 against required 5; true at 5 against 5;
   an unmet list of Weapon Upgrades (3318, need 5,
   have 3, not untrained) plus Spaceship Command
   (3327, need 3, have 0, untrained); unknown id 9999
   named `'Skill #9999'`; the recursive walk excluding
   an already-met node; a 100→101→100 cycle completing
   non-empty without looping. It contains no oracle
   for `targetLevel` (because the parameter is
   ignored), none for diamond dependencies, and none
   at all for `filterPrerequisitesNotInPlan`.
   `prerequisite_warning_dialog_test.dart` pins the
   source-5 header and need-level strings.
7. **Current Rust plan model** at `27f79d2`.
   `src/skills/plans.rs`: `SkillPlanEntry{skill_id:
   i64, target_level: i32}`; `validate_plan` enforces
   invariants I1 (one entry per skill), I2 (target
   1..=5), and I4 (name/description limits); invariant
   I5 makes entries naming skills absent from the
   extract **legal** — they render as `"Unknown
   Skill"`; invariant I3 makes the `entries` vector
   index the display order. `src/skills/mod.rs`
   registers `pub mod plans; pub mod training;` under
   `pub mod skills;` in `src/lib.rs`, following the
   `src/fitting/` pure-module precedent: no egui, no
   `AppState`, no network, no database handles.
8. **Current Rust estimate seam** `src/skills/training.rs`.
   `plan_progress(plan, sde, trained:
   Option<&BTreeMap<i64, TrainedSkill>>, attributes)`
   (lines 189–299) is the established pure-function
   pattern this slice mirrors: `TrainedSkill{
   trained_level, skillpoints_in_skill}` (lines
   52–56); `trained = None` (skills bundle not ready)
   degrades every entry to unknown levels and
   unavailable estimates while the plan still renders
   and edits; `trained = Some(map)` reads the level
   as `map.get(...).map(|t|
   t.trained_level.clamp(0, 5)).unwrap_or(0)` (lines
   199–203), so a missing key means untrained level
   0; `active_skill_level` is never read; result
   `PlanProgress.entries` is a `Vec` parallel to
   `plan.entries` (lines 168–173).
9. **Current Rust Skills view** `src/ui/skills.rs`
   (1142 lines). The catalogue loop (lines 368–396)
   builds one row string per skill,
   `format!("{} — trained level {}", skill.type_name,
   level)` (line 380), grouped under collapsing
   headers. The plan section derives
   `trained: Option<BTreeMap<i64, TrainedSkill>>`
   once per frame from the ready skills bundle
   (lines 451–465) and passes `trained.as_ref()` to
   `plan_progress` and to `show_plan_detail` (lines
   512, 534–542). In plan detail (lines 553–735) each
   entry emits `ui.label(entry_row_text(idx + 1,
   ...))` (line 633) followed by one horizontal row
   of Move up / Move down / Remove buttons (lines
   634–684), then `plan_totals_line` (line 728) and
   the verbatim-locked `SKILL_PLANS_DISCLOSURE`
   (lines 48, 732–734). The picker
   `show_skill_picker` (lines 827–912) already
   receives `trained: Option<&BTreeMap<...>>`; its
   row label is `picker_row_label(skill_name,
   trained_level)` (lines 170–175) with
   already-in-plan and already-trained-to-5 suffixes
   (lines 864–870), and level buttons 1..=5 whose
   `enabled` is `level > trained_level`, or all
   enabled when skills are not loaded (lines
   873–908). Small pure helpers `plan_list_summary`,
   `plan_totals_line`, `entry_row_text`, and
   `picker_row_label` carry every locked string, and
   the tests module (lines 914+) pins them without a
   frame. Demo plans are memory-only under the
   verbatim-locked `SKILL_PLANS_DEMO_LABEL` (lines
   46–47, 475–477); demo characters share the same
   ready-skills bundle shape (demo skill data keyed
   90000001 / 90000002 in
   `assets/demo/skillqueue.json`).
10. **Logging convention.** `LOG_TAGS`
    (`src/ui/settings.rs:7-23`) already contains
    `[SKILLS]` and `[PLANS]`. The SDE load logs
    counts only (`[SKILLS] SDE loaded skills={} ...
    `, `src/names/sde.rs:80-85`); plan actions log ids
    and counts (e.g. `[PLANS] entries replace
    requested character_id={} plan_id={} count={}`).
    Standing rule: logs carry counts and ids only,
    never skill names or user text. The skill-plans
    design explicitly excluded prerequisite warnings
    as a later slice (`docs/skill-plans-design.md`
    section 2, noting the unparsed data and that
    Flutter's service was never wired into plans);
    this document is that later slice and supersedes
    only that exclusion.

## 1. Value ranking (LOCKED)

When two choices conflict, the higher rank wins.

| Rank | Value | What it decides |
|---|---|---|
| 1 | Honest claims only | A warning claims what trained levels prove, nothing else; unknown trained state renders no warning rather than a guessed one; a plan entry is intent, never reported as trained |
| 2 | Advisory, never blocking | No warning disables, hides, confirms, or alters any add/remove/reorder action, in any load state |
| 3 | No invented semantics | The comparison, the 0-for-untrained rule, and target-level independence come from inspected bodies; anything with no inspected body and no honest derivation is excluded (section 2) |
| 4 | Names, never raw ids | Every prerequisite a user sees is resolved through `Sde::skill_name_quiet`; the fallback is `"Unknown Skill"`, never Flutter's `'Skill #id'` |
| 5 | Reuse of shipped machinery | The `plan_progress` pure-function shape, the per-frame trained map, the locked-string helper pattern, existing log tags, the existing SDE indexes |
| 6 | Smallest surface | Direct prerequisites only, three locked label forms, no new state, storage, scopes, views, or filters |

## 2. Hard scope and explicit exclusions (LOCKED)

In scope: one additive serde field and one new edge
struct in `src/names/sde.rs` (section 4); one new pure
module `src/skills/prereqs.rs` holding the evaluation
of section 3 and nothing else (section 5); additive
labels in exactly three places in `src/ui/skills.rs` —
the catalogue rows, the picker rows, and the plan-
detail entry list, plus one warning-count line and one
disclosure constant in plan detail (section 8); one
extended `[SKILLS]` load log (section 10); the test
plan of section 12. No other file changes except the
one-line module registration in `src/skills/mod.rs`.

Explicitly out, each with its ground:

- **Auto-adding prerequisites to a plan.** The only
  body that ever proposed it is the never-shown dialog
  (source 5), and its helper
  `filterPrerequisitesNotInPlan` (source 3) filters by
  skill-id presence while ignoring levels, so copying
  it would silently treat a plan entry targeting level
  1 as satisfying a level-5 requirement. It has zero
  production call sites and zero tests (sources 4, 6).
  A correct level-aware auto-add is greenfield product
  design (which targets, in which order, past which
  existing entries) and is not invented here.
- **Blocking or confirming an add** (the dialog's
  Cancel / Add Anyway / Add with Prerequisites flow,
  or Flutter's catalogue Add-button disable, sources
  4–5). The slice goal is advisory warnings;
  section 7 is the guarantee.
- **Crediting plan entries as trained** (the
  "trained-plus-earlier-plan-entries" semantics).
  Decided against in section 3.2; the plan-detail
  disclosure in section 8.4 states the rule in fixed
  words so the user is never misled by its absence.
- **Transitive (recursive) prerequisite warnings or
  chain display.** `getAllPrerequisites` (source 3)
  never ran in production (source 4). Section 3.3
  locks direct-only; the catalogue lets a user walk a
  chain one honest hop at a time.
- **Catalogue filter modes** (Flutter's `canTrain` /
  `havePrereqs`, source 4). The two Flutter modes are
  one duplicated predicate under two names, and no
  Rust surface asks for a filter. This slice adds
  labels, not modes.
- **Queue-aware crediting.** Skills in the training
  queue do not count as trained here, exactly as plan
  progress already ignores the queue and discloses
  the omission in `SKILL_PLANS_DISCLOSURE` (source 9).
- **Target-level-dependent checks.** Section 3.4:
  the entry's `target_level` plays no role. Flutter's
  ignored `targetLevel` parameter is not ported as a
  parameter at all.
- **Storage, schema, or scope changes.** A warning is
  derived at render time from bundled data plus the
  already-loaded trained map (sources 1, 8, 9); no
  column is needed, and the "no schema change unless
  proven" bar is therefore met by proving the
  negative: nothing in sections 4–8 persists.
- **New app state, views, or navigation.** Warnings
  recompute every frame from inputs the view already
  holds (source 9), mirroring `plan_progress`; no
  `AppState` field, no new `View`, no persisted
  toggle.
- **Sorting, deduplicating, or validating the bundled
  edges at load.** Field order is display order
  (section 4); the bundled file's cleanliness is
  pinned by tests (section 12), not enforced by
  rejecting a load at runtime.
- **Colour, icons, dimming, or tooltips** for warning
  labels. Flutter's dim-plus-tooltip-plus-disable
  idiom (source 4) is inseparable from its blocking
  behaviour, and the Rust view has no warning-colour
  precedent for advisory text (its one
  `LIGHT_RED` use is the plan editor's validation
  error). Warning labels are plain `ui.label` text;
  styling is a later, separately-grounded decision.
- **Regenerating the extract.** The script's field
  naming produced the bytes this slice parses
  (source 1); `assets/sde/skills.json` is untouched.

## 3. Semantics verdict (LOCKED — read before any evaluation code)

### 3.1 The comparison: trained level below required level, per edge

For one skill S with direct prerequisite edges
`(P, r)` — prerequisite skill P at required level r,
from S's SDE row (source 1) — edge `(P, r)` is
**unmet** exactly when `trained_level(P) < r`, where
`trained_level(P)` is the character's loaded trained
level clamped to 0..=5, and a skill with no loaded
trained row reads as level 0. This is verbatim the
inspected Flutter rule (source 3, `trainedLevel <
prereq.requiredLevel`, missing row → 0) and the
inspected Rust trained-map rule (source 8, clamp
0..=5, missing key → 0). S can be trained exactly
when no edge is unmet. Skill points never participate
(the check is a level fact, matching how progress
completion is a level fact in source 8), and
`active_skill_level` is never read.

### 3.2 Trained-only wins; plan entries earn no credit

The competing reading credits earlier entries of the
same plan: when checking entry *i*, treat each earlier
entry's target level as if trained. It is
**rejected**, on three grounds, any one of which
suffices:

1. **No inspected body does it.** Every Flutter check
   that ever ran is trained-only (sources 3–4). The
   single plan-adjacent helper,
   `filterPrerequisitesNotInPlan`, was never wired,
   never tested, and is level-blind (sources 3, 4,
   6); a level-aware version would be an invented
   semantic with no oracle anywhere in the
   repository, against rank 3.
2. **Crediting intent as achievement is dishonest.**
   A plan entry records what the user hopes to
   train. Reporting its prerequisite as met would
   claim the character can train the skill in EVE
   today, which is false until the earlier entries
   actually finish (rank 1). The existing product
   already takes this side: plan progress counts an
   entry *complete* only at a trained level, never
   because another entry precedes it (source 8).
3. **Order-dependent warnings lie by rearrangement.**
   Under plan-order crediting, dragging an entry one
   position makes warnings appear and vanish with no
   change to the character. Trained-only warnings
   are a stable function of the character and the
   plan's *contents*, independent of `entries` order
   (I3), and are therefore testable with order-free
   literals (section 12).

The honest cost is accepted and disclosed, not
hidden: a perfectly ordered plan still warns until
the character trains. Section 8.4 locks the fixed
words that say so, shown whenever a warning shows.

### 3.3 Direct-only wins; no recursion in this slice

The competing reading reports the transitive closure
(Flutter's `getAllPrerequisites`, source 3). It is
**rejected**: the recursive method never ran in
production (source 4), the only warning surface
Flutter ever designed (the dialog, source 5) listed
the direct result of `getUnmetPrerequisites`, and a
closure view would repeat the same missing skill
under several plan entries with depth bookkeeping no
inspected Rust surface can render. Direct-only also
bounds every label: at most 3 edges per skill in the
bundled data (source 1).

**Cycle safety follows by construction:** evaluation
iterates one skill's edge list once and never
descends, so it terminates in O(edges) on any input,
including hypothetical future extracts containing a
cycle or a self-requirement (the bundled file has
neither, source 1). No `visited` set, no depth cap,
and no recursion are needed, and none may be added in
this slice; a self-requiring edge, if one ever
appears, is evaluated literally against the trained
map like any other edge. Flutter's `visited` guard
(source 3) is evidence that recursion needs a guard,
not a reason to recurse.

### 3.4 Target level plays no role

Prerequisites gate training a skill *at all*; the SDE
row carries one edge list per skill, with no
per-target variation (source 1), and Flutter's
service accepted `targetLevel` without ever reading
it (sources 3, 6). Accordingly no Rust function in
this slice takes a target-level parameter, and a plan
entry targets level 1 and level 5 under exactly the
same warning. Copying Flutter's call-site habit of
passing `trainedLevel + 1` is explicitly forbidden:
it would reintroduce a parameter whose only observed
behaviour is to be ignored.

### 3.5 Unknown skills, both directions

- **The checked skill is unknown** (`sde.skill(id)`
  is `None`, entry invariant I5, source 7): there is
  no edge list to check, so the entry carries **no
  warning**. Claiming its prerequisites are met or
  unmet would invent data this build does not have
  (rank 1). Its row, estimates, and totals behave
  exactly as shipped ("Unknown Skill", unavailable
  estimates).
- **A prerequisite skill id is unknown** (impossible
  in the bundled file, source 1, but possible in a
  future extract): the edge is still evaluated
  literally — trained level 0 if untrained, unmet if
  below required — and renders by name as
  `"Unknown Skill"` (source 2). Dropping the edge
  would silently understate requirements; rendering
  Flutter's `'Skill #id'` would break rank 4. The
  parser tolerates the id (section 4) for the same
  reason.

## 4. Parser (LOCKED)

Additive change to `src/names/sde.rs` only, following
the struct's existing accept-or-default convention
(source 2):

```rust
/// One direct prerequisite edge from the bundled
/// extract: another skill and the level it must be
/// trained to before the owning skill can train.
#[derive(Debug, Clone, Default, Deserialize, PartialEq)]
pub struct SdePrerequisite {
    #[serde(rename = "skillId", default)]
    pub skill_id: i64,
    #[serde(default)]
    pub level: i32,
}
```

and one field on `SdeSkillType`:

```rust
    /// Direct prerequisites, in extract file order.
    /// Empty for the 29 root skills whose JSON omits
    /// the key.
    #[serde(default)]
    pub prerequisites: Vec<SdePrerequisite>,
```

Locked parser rules:

- **Types** are `i64` / `i32`, matching `typeId` and
  the codebase's level fields (`target_level`,
  `trained_level`, sources 7–8). Field names are the
  file's exact `skillId` / `level` (source 1); no
  rename beyond the `skillId` → `skill_id` case
  mapping.
- **Absent key means empty.** `#[serde(default)]`
  maps the 29 keyless root skills (source 1) to an
  empty `Vec`, exactly as a missing `rank` maps to 0
  today (source 2). There is no `Option<Vec<...>>`:
  "no key" and "no prerequisites" are the same fact
  for every consumer in this slice.
- **Missing fields inside an edge default to 0**
  (per-field `default`, source 2 convention). A
  syntactically valid but partial edge degrades; it
  never fails the whole SDE load. Malformed JSON as
  a whole remains an error, as today
  (`malformed_json_is_an_error_not_a_panic`).
- **Order is file order.** The `Vec` preserves the
  JSON array order verbatim; no sort (Flutter's
  database ordered by required level, which is
  arbitrary and is not copied), no deduplication, no
  merging of repeated ids. Consumers and tests rely
  on this order (sections 8, 12).
- **Unknown prerequisite ids are tolerated.** The
  parser stores every edge verbatim, including an
  edge whose `skill_id` names no type in the file.
  Filtering at parse time would silently understate
  requirements (section 3.5). No load-time
  resolvability check is added; the bundled file's
  full resolvability is a *test* invariant
  (section 12), not a runtime rejection.
- **Levels are stored verbatim.** The parser neither
  clamps nor validates `level`: 1..=5 is a bundled-
  data fact (source 1) pinned by test, not a runtime
  gate. Evaluation gives out-of-range values their
  literal meaning (section 5), so a future extract
  mistake surfaces as a visible warning or a
  trivially-met edge, never as a failed catalogue.
- **No new index.** Edges are read through the
  existing `skill(id) -> Option<&SdeSkillType>`
  accessor and its `by_id` index (source 2); 749
  small structs ride the existing vector. Parse cost
  is one pass over the unchanged 167,138-byte file at
  startup (source 1) — no measurement or caching
  work is added.

## 5. Pure evaluation (LOCKED)

New module `src/skills/prereqs.rs`, registered as
`pub mod prereqs;` in `src/skills/mod.rs`, under the
pure-module rule of source 7: no egui, no `AppState`,
no network, no database, no logging (the module is
deterministic and called per frame; section 10).
It mirrors the `plan_progress` shape (source 8).

```rust
// src/skills/prereqs.rs
use std::collections::BTreeMap;

use crate::names::sde::Sde;

use super::plans::SkillPlan;
use super::training::TrainedSkill;

/// One direct prerequisite the character has not
/// trained to the required level. Carries ids and
/// levels only: the interface resolves `skill_id`
/// to a display name, so a raw id never becomes
/// user-facing text inside this type.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct UnmetPrerequisite {
    pub skill_id: i64,
    pub required_level: i32,
    pub trained_level: i32, // clamped 0..=5; 0 = untrained
}
```

Two functions, exactly these signatures:

```rust
pub fn unmet_prerequisites(
    sde: &Sde,
    skill_id: i64,
    trained: &BTreeMap<i64, TrainedSkill>,
) -> Vec<UnmetPrerequisite>

pub fn plan_prerequisite_warnings(
    plan: &SkillPlan,
    sde: &Sde,
    trained: Option<&BTreeMap<i64, TrainedSkill>>,
) -> Vec<Vec<UnmetPrerequisite>>
```

Locked behaviour:

- `unmet_prerequisites` reads `sde.skill(skill_id)`;
  `None` yields an empty vector (unknown checked
  skill, section 3.5). Otherwise it filters that
  skill's `prerequisites` **in file order**, keeping
  edge `(p, r)` when `level_of(p) < r`, where
  `level_of(p) = trained.get(&p).map(|t|
  t.trained_level.clamp(0, 5)).unwrap_or(0)` (the
  source-8 expression). The kept edge emits
  `UnmetPrerequisite{skill_id: p, required_level: r,
  trained_level: level_of(p)}`. It takes the trained
  map by shared reference without `Option`: "are the
  prerequisites met" is only a question once trained
  levels exist, and callers that lack them must not
  ask (section 8 gates every call site).
- `plan_prerequisite_warnings` returns a vector
  **parallel to `plan.entries`** (the
  `PlanProgress.entries` precedent, source 8):
  element *i* is `unmet_prerequisites` for
  `plan.entries[i].skill_id`. Its `trained`
  parameter is `Option` to mirror `plan_progress`'s
  call site: `None` yields one empty vector per
  entry. An empty inner vector therefore means
  *either* met *or* unknown trained state; the view
  distinguishes by `trained.is_some()` exactly as it
  already does for totals (source 9), and section
  8.4 forbids rendering warnings from the `None`
  case. An empty plan yields an empty outer vector.
- **No target level, ever** (section 3.4): neither
  function reads `entry.target_level`.
- **Out-of-range required levels are literal:** `r
  <= 0` is met by any clamped trained level
  (including untrained 0, since `0 < r` is false);
  `r > 5` is unmet even at trained 5. Neither case
  occurs in the bundled file (source 1); both are
  pinned by synthetic tests (section 12) so a future
  extract behaves predictably instead of panicking.
- **No sorting, no deduplication.** Output order is
  the edges' file order; a repeated prerequisite in
  a future extract would emit one row per stored
  edge (faithful, visible, testable), matching the
  parser rule in section 4.
- `UnmetPrerequisite` deliberately carries **no
  skill name**. Flutter's requirement carried one
  and filled misses with `'Skill #id'` (source 3);
  here the name is resolved once, in the view, via
  `skill_name_quiet` (rank 4). No `is_untrained` or
  `description` helper is added to the pure type:
  untrained is `trained_level == 0` at the single
  place that formats words (section 8.1).

## 6. Worked chains (LOCKED oracles' raw material)

Quoted verbatim from the bundled file (source 1);
section 12 derives every literal from these by hand.
Builders copy expectations from section 12, never
from observed test output.

**Chain A (two hops, the direct-only witness).**
Small Hybrid Turret (3301) requires Gunnery (3300)
level 1. Medium Hybrid Turret (3304) requires Gunnery
(3300) level 3, then Small Hybrid Turret (3301) level
3, in that file order. Gunnery (3300) requires
nothing (key absent).

**Chain B (fan-out 3, the parser witness).**
Gallente Titan (3344) requires Capital Ships (20533)
level 5, then Gallente Battleship (3336) level 3,
then Leadership (3348) level 5, in that file order.
Capital Ships (20533) itself requires Advanced
Spaceship Command (20342) level 5 — relevant only as
proof that checking the Titan must not report
Advanced Spaceship Command (direct-only, section
3.3).

## 7. Advisory-only guarantee (LOCKED)

Warnings are derived labels. This slice must not
change the behaviour of any of the following, in any
skills load state and whether prerequisites are met,
unmet, or unknown:

- `validate_plan` and invariants I1–I6 (source 7):
  prerequisite state is never a validation input.
- Every `SkillPlanAction` (`Create`, `UpdateText`,
  `DeletePlan`, `ReplaceEntries`) and every site that
  stamps one: the picker still appends on a level-
  button click, Move up / Move down still swap,
  Remove still arms its shipped confirmation.
- The picker level buttons' `enabled` expression
  (`level > trained_level`, all enabled when skills
  are not loaded, source 9): prerequisite state is
  never an input to `add_enabled` for these buttons.
- The already-in-plan and already-trained-to-level-5
  picker suffixes and their no-button rows
  (source 9): unchanged, and no third no-button case
  is added.
- Plan estimates, totals, list summaries, and the
  progress bar (`plan_progress`, `plan_totals_line`,
  `plan_list_summary`): `prereqs.rs` output never
  feeds a number anywhere.
- The catalogue: it has no buttons today and gains
  none; no row is dimmed, hidden, or reordered.

No confirmation, modal, or dialog is added at any
point. The pure functions of section 5 have no side
effects, and the view consumes their output only
through the label helpers of section 8. Reviewers
verify this section by diff inspection plus the
unchanged-behaviour pin of section 12 (U7): there
is deliberately no runtime flag to test, because
there is nothing to switch off.

## 8. Surfaces and verbatim wording (LOCKED)

All changes are inside `src/ui/skills.rs`. Every new
user-visible string is produced by one of the pure
helpers below and pinned by section 12 without a
frame (the source-9 pattern). Labels are plain
`ui.label(...)` (section 2). Skill names in every
helper come from `sde.skill_name_quiet(...)`
per-frame, never from `skill_name(...)` (whose
per-miss warning would repeat every frame, source 2)
and never from a raw id.

### 8.1 Shared wording helpers

```rust
const PREREQ_DISCLOSURE: &str =
    "Prerequisite warnings use trained levels only. \
     Skills already in this plan are not counted as trained.";

fn prerequisite_line(sde: &Sde, skill: &SdeSkillType) -> Option<String>
fn unmet_warning_line(sde: &Sde, unmet: &[UnmetPrerequisite]) -> Option<String>
fn prerequisite_count_line(warnings: &[Vec<UnmetPrerequisite>]) -> Option<String>
```

- `prerequisite_line` returns `None` when
  `skill.prerequisites` is empty. Otherwise it
  returns the requirement fact, all edges in file
  order, with no trained-level information (it must
  be honest even while skills are loading):

  `Requires: {name} level {required}` joined by
  `, ` — e.g. for Medium Hybrid Turret (chain A)
  exactly `Requires: Gunnery level 3, Small Hybrid
  Turret level 3`.

- `unmet_warning_line` returns `None` when `unmet`
  is empty. Otherwise it returns the unmet subset
  with trained-state, adapting the never-shown
  dialog's need/have fragments (source 5) to one
  advisory sentence — lowercase `need`, because the
  fragment now follows a name mid-sentence, and no
  "cannot train" claim, because adding stays allowed
  (section 7):

  `Prerequisites not met: {segments}` where each
  segment is `{name} — need level {required}
  (untrained)` when `trained_level == 0`, else
  `{name} — need level {required} (have {trained})`,
  segments joined by `; ` — e.g. exactly
  `Prerequisites not met: Gunnery — need level 3
  (have 1); Small Hybrid Turret — need level 3
  (untrained)`. Segment order is the input order
  (file order, section 5). The word `Prerequisites`
  is used at every count including one, following
  the shipped bare-number copy precedent for counts
  (`delete_plan_summary`, source 9).

- `prerequisite_count_line` takes the parallel
  warnings of section 5, counts entries with a
  non-empty inner vector as `warned`, and returns
  `None` when `warned == 0` (including the empty
  plan). Otherwise it returns exactly `Prerequisite
  warnings: {warned} of {total} entries have unmet
  prerequisites.` where `total` is the outer length.
  The words `entries` and `have` are fixed at every
  count including one, per the same shipped copy
  precedent; section 12 pins the singular-count
  sentence verbatim so the choice is reviewed, not
  accidental.

- `PREREQ_DISCLOSURE` is the trained-only rule of
  section 3.2 in fixed words. It is rendered only in
  plan detail, only alongside at least one warning
  (section 8.4). The shipped `SKILL_PLANS_DISCLOSURE`
  constant and its rendering condition are untouched.

### 8.2 Catalogue rows (surface a)

In the catalogue loop (source 9, lines 368–396), each
skill keeps its existing row string byte-for-byte
(`{name} — trained level {level}`). When
`prerequisite_line` returns `Some`, that string is
pushed as **one additional row immediately after**
the skill's row, inside the same group, subject to
the same search match as its skill (filtering stays
on `type_name` only; a search never matches on
prerequisite text, and a matched skill's prerequisite
row is never suppressed by the query). No indent
characters are added to the string. The catalogue
shows requirements in every skills load state in
which it renders today, because the line states an
SDE fact, not a trained fact. It never shows
`unmet_warning_line`: the catalogue's job in this
slice is to show prerequisites, and have/need
judgements belong to the plan surfaces (sections
8.3–8.4), where a decision is being made.

### 8.3 Picker rows (surfaces a and b)

In `show_skill_picker` (source 9, lines 827–912),
each result row keeps `picker_row_label` and its two
shipped suffixes byte-for-byte. Two additive labels
follow the row label, in this order:

1. The `prerequisite_line` label, when `Some`, for
   **every** result row — including already-in-plan
   and already-trained-to-5 rows (the requirement
   fact is useful for reading the plan, and hiding
   it on exactly the rows already chosen would be
   arbitrary).
2. The `unmet_warning_line` label, only when trained
   levels are loaded (`trained` argument is `Some`),
   computed by `unmet_prerequisites(sde,
   skill.type_id, trained_map)` for that row, and
   only when the helper returns `Some`. It renders
   on every row case alike — including
   already-in-plan rows (the entry is in the plan and
   unmet) — and the helper alone decides from data;
   no row case suppresses it by assumption.

Both labels render before the level-button row on
addable rows, so the warning is read before the
click it advises about — but the buttons, their
`enabled` expression, and the append behaviour are
untouched (section 7). When skills are not loaded,
only the requirement line shows; assuming trainable
while loading (Flutter's `?? true`, source 4) is
explicitly not copied, and no "prerequisites
unavailable" label is added either: the row already
says trained level is unavailable.

### 8.4 Plan-detail entry warnings (surface b)

In `show_plan_detail` (source 9, lines 553–735),
compute `let warnings = plan_prerequisite_warnings(
plan, sde, trained);` once per frame next to the
existing `plan_progress` call (line 562). Then:

- For entry *i*, immediately after its
  `entry_row_text` label (line 633) and **before**
  its Move up / Move down / Remove row, render
  `unmet_warning_line(sde, &warnings[i])` as one
  `ui.label` when it returns `Some` **and**
  `trained.is_some()`. The `trained.is_some()` gate
  is what stops the empty-vectors-of-the-unknown-case
  (section 5) from being read as "met": with skills
  not loaded, no per-entry warning, no count line,
  and no disclosure renders at all, and the shipped
  `Estimates will appear when trained skills are
  loaded.` totals line remains the only
  not-loaded words. `entry_row_text` itself is not
  modified.
- After the totals label (line 728), render
  `prerequisite_count_line(&warnings)` when `Some`
  and `trained.is_some()`, then `PREREQ_DISCLOSURE`
  under exactly the same condition (count line
  present implies at least one warning). Order under
  the entry list is therefore: totals line, count
  line, prerequisite disclosure, and the shipped
  estimates disclosure under its own untouched
  condition (lines 732–734). The plan **list**
  (`plan_list_summary`, line 521) is not a surface in
  this slice: list rows gain no warning text, so
  scanning plans stays as shipped.

### 8.5 Per-surface truth table

| Surface | Requirement line | Warning line | Trained not loaded |
|---|---|---|---|
| Catalogue row | when edges exist | never | requirement line still shows |
| Picker row | when edges exist, every row case | when unmet and trained loaded | requirement line only |
| Plan entry | never (the picker/catalogue carry the fact) | when unmet and trained loaded | nothing new renders |
| Plan totals block | count line + disclosure when warned ≥ 1 and trained loaded | — | nothing new renders |

An entry whose skill is unknown to the extract
(section 3.5) shows no requirement or warning line
anywhere; an entry already complete
(`trained_level >= target_level`) can still warn if
its prerequisites are below required — completion is
about the entry's own level (source 8), prerequisites
about other skills, and conflating them would hide a
true fact about the character.

## 9. Demo behaviour (LOCKED)

Demo is not a special case. Demo characters load the
same bundled `Sde` and a ready skills bundle of the
same shape (source 9), and demo plans are the same
`SkillPlan` values held in memory. Therefore:

- Catalogue and picker requirement lines render from
  the bundled extract identically in demo and live.
- Picker and plan-detail warnings compute from the
  demo trained map identically; a demo plan warns
  exactly when the same plan would warn live for a
  character with the demo trained levels.
- Nothing about warnings persists in either mode
  (section 2), so the demo guarantee — plans kept in
  memory, live database untouched, per the unchanged
  `SKILL_PLANS_DEMO_LABEL` — needs no new mechanism
  and no new words. No demo fixture file changes, and
  no demo-specific branch (`state.demo` check) is
  added anywhere in this slice.

## 10. Logging (LOCKED)

Counts and ids only, never skill names or user text
(source 10). Exactly one log change:

- The SDE load line in `Sde::from_json`
  (`src/names/sde.rs:80-85`) gains one count field:
  `[SKILLS] SDE loaded skills={} groups={}
  categories={} prerequisites={}` where the new value
  is the total edge count summed over all types
  (749 on the bundled file). The tag, level (`info`),
  and existing fields are unchanged.

No other logging is added. `src/skills/prereqs.rs`
logs nothing (it is pure and runs per frame; Flutter's
per-check debug lines and its log of skill *names*,
source 3, are explicitly not copied). The view logs
nothing per warning and nothing per frame; the
shipped `[PLANS]` action logs are untouched. No new
entry in `LOG_TAGS` — `[SKILLS]` and `[PLANS]` already
exist (source 10).

## 11. State, storage, and wiring (LOCKED: none)

There is no wiring section because there is nothing
to wire: no `AppState` field, no `LoadState`, no
queued action, no shell drain, no repository, no
schema, no `SCHEMA_VERSION` change, no scope, no
endpoint. The view already holds `&Sde` and derives
`trained` once per frame (source 9); sections 5 and 8
consume exactly those. Any builder diff touching
`src/app/`, `src/storage/`, `src/esi/`, or
`assets/` is out of design and must be rejected in
review.

## 12. Test plan (LOCKED, hand-derived literals)

Every expectation below is derived by hand from
chains A and B (section 6) and from the source-1
scan counts, before any code exists. Builders write
these literals into tests verbatim; copying observed
test *output* into expectations is forbidden. Test
function names are locked so the integrator can audit
coverage by name. In `TrainedSkill` literals the
`skillpoints_in_skill` field is 0 unless the case
says otherwise (section 3.1: skill points never
participate).

### 12.1 Parser tests (`src/names/sde.rs` tests, Builder A)

- **P1 `prerequisites_parse_in_file_order`** (bundled
  load): skill 3304's edges are exactly
  `[(3300, 3), (3301, 3)]` as `(skill_id, level)`
  pairs in order (chain A); skill 3301's are exactly
  `[(3300, 1)]`; skill 3344's are exactly
  `[(20533, 5), (3336, 3), (3348, 5)]` (chain B).
- **P2 `root_skills_empty_and_bundled_edges_resolve`**
  (bundled load): skill 3300's `prerequisites` is
  empty; the total edge count over all types is
  exactly 749; exactly 466 types have a non-empty
  vector; every edge's `level` is in 1..=5; every
  edge's `skill_id` satisfies `sde.contains(...)`.
  (Counts and bounds from the source-1 scan; this
  test is what turns "the file is clean" from a
  runtime assumption into a pinned invariant.)
- **P3 `prerequisites_default_on_partial_json`**
  (`Sde::from_json` on a synthetic literal with
  empty `categories`/`groups`): a type with no
  `prerequisites` key parses to an empty vector; an
  edge `{"skillId": 3300}` parses to
  `(skill_id: 3300, level: 0)`; an edge
  `{"level": 2}` parses to `(skill_id: 0, level: 2)`;
  the load succeeds throughout (section 4).

### 12.2 Evaluation tests (`src/skills/prereqs.rs` tests, Builder A)

Bundled-load cases use chains A/B; `trained` maps list
only the keys present (absent key = untrained).

- **E1 `unmet_lists_both_edges_in_file_order`**:
  skill 3304, trained {3300: level 1} → exactly
  `[{3300, req 3, have 1}, {3301, req 3, have 0}]`
  in that order (chain A: 1 < 3, and absent 3301 is
  0 < 3).
- **E2 `met_at_and_above_required_is_empty`**: skill
  3304, trained {3300: 3, 3301: 3} → `[]`; trained
  {3300: 5, 3301: 4} → `[]`.
- **E3 `only_the_short_edge_is_reported`**: skill
  3304, trained {3300: 3, 3301: 2} → exactly
  `[{3301, req 3, have 2}]`.
- **E4 `direct_only_never_descends`**: skill 3344,
  trained {} → exactly
  `[{20533, req 5, have 0}, {3336, req 3, have 0},
  {3348, req 5, have 0}]`, and no element has
  `skill_id == 20342` (Advanced Spaceship Command is
  Capital Ships' prerequisite, chain B; a descendant
  walk would report it, direct-only must not).
- **E5 `unknown_and_root_skills_have_no_warnings`**:
  skill 999999, trained {} → `[]`; skill 3300,
  trained {} → `[]` (sections 3.5, 4).
- **E6 `trained_level_clamps_and_sp_is_ignored`**:
  skill 3301 (needs Gunnery 3300 level 1): trained
  {3300: level 9} → `[]` (clamped to 5, and 5 ≥ 1);
  trained {3300: level -2} → `[{3300, req 1, have
  0}]` (clamped to 0); trained {3300: level 0,
  `skillpoints_in_skill: 999999`} → `[{3300, req 1,
  have 0}]` (skill points never participate,
  section 3.1).
- **E7 `plan_warnings_parallel_and_none_is_empty`**:
  plan with entries `[(3304, target 3), (3300,
  target 5), (999999, target 2)]`, trained
  `Some({3300: 1})` → exactly
  `[[{3300, 3, 1}, {3301, 3, 0}], [], []]` (root
  skill and unknown skill both silent, section 3.5);
  `trained: None` on the same plan → `[[], [], []]`;
  an empty plan → `[]` for both `trained` cases.
- **E8 `target_level_does_not_change_warnings`**:
  two one-entry plans `[(3304, target 1)]` and
  `[(3304, target 5)]`, trained `Some({3300: 1})` →
  both yield `[[{3300, 3, 1}, {3301, 3, 0}]]`,
  asserted as equal literals, not merely equal to
  each other (section 3.4).
- **E9 `synthetic_bounds_unknown_and_cycles`** (two
  `Sde::from_json` literals): (i) skill 1 with edges
  `[(2, 0), (3, 6), (999999, 2)]` and types 2, 3
  present: trained {3: level 5} → exactly
  `[{3, req 6, have 5}, {999999, req 2, have 0}]`
  (level-0 edge met untrained, level-6 edge unmet
  at 5, unknown prerequisite evaluated literally,
  sections 3.5, 5); trained {3: 5, 999999: 2} →
  exactly `[{3, req 6, have 5}]`. (ii) skill 1 with
  edge `[(2, 1)]` and skill 2 with edges `[(1, 1),
  (2, 2)]` (a cycle plus a self-edge): checking
  skill 2 with trained {2: level 1} completes with
  exactly `[{1, req 1, have 0}, {2, req 2, have 1}]`
  (termination by construction, section 3.3).

### 12.3 Wording tests (`src/ui/skills.rs` tests, Builder B)

- **U1 `prerequisite_line_wording`**: bundled load —
  skill 3304 → `Some("Requires: Gunnery level 3,
  Small Hybrid Turret level 3")`; skill 3301 →
  `Some("Requires: Gunnery level 1")`; skill 3344 →
  `Some("Requires: Capital Ships level 5, Gallente
  Battleship level 3, Leadership level 5")`; skill
  3300 → `None` (chains A/B, section 8.1).
- **U2 `unmet_warning_line_have_and_untrained`**:
  input `[{3300, 3, 1}, {3301, 3, 0}]` →
  `Some("Prerequisites not met: Gunnery — need
  level 3 (have 1); Small Hybrid Turret — need level
  3 (untrained)")`; input `[{3301, 3, 2}]` →
  `Some("Prerequisites not met: Small Hybrid Turret
  — need level 3 (have 2)")`; input `[]` → `None`.
- **U3 `unmet_warning_line_unknown_never_raw_id`**:
  input `[{999999, 2, 0}]` →
  `Some("Prerequisites not met: Unknown Skill — need
  level 2 (untrained)")`, and the returned string
  does not contain `"999999"` (rank 4).
- **U4 `prerequisite_count_line_counts`**: warnings
  `[[one edge], [], [two edges]]` →
  `Some("Prerequisite warnings: 2 of 3 entries have
  unmet prerequisites.")`; `[[one edge]]` →
  `Some("Prerequisite warnings: 1 of 1 entries have
  unmet prerequisites.")` (fixed plural wording at
  count one, section 8.1 — asserted verbatim so the
  choice is reviewed); `[[], []]` → `None`; `[]` →
  `None`.
- **U5 `prereq_disclosure_verbatim`**:
  `PREREQ_DISCLOSURE` equals exactly `"Prerequisite
  warnings use trained levels only. Skills already
  in this plan are not counted as trained."` (one
  space after the period; this also pins the
  line-continuation spelling of the constant).
- **U6 `plan_warning_text_end_to_end`**: bundled SDE,
  plan `[(3304, target 5)]`, trained `Some({3300:
  level 1})`: `plan_prerequisite_warnings` fed to
  `unmet_warning_line` yields the U2 two-segment
  literal, and fed to `prerequisite_count_line`
  yields the U4 one-of-one literal. This is the
  cross-builder seam test (A's functions, B's words)
  and lives in B's file.
- **U7 shipped strings untouched:** every pre-existing
  `src/ui/skills.rs` test passes with its
  expectations unmodified — in particular the
  `entry_row_text`, `picker_row_label`,
  `plan_totals_line`, `plan_list_summary`, and
  disclosure pins (source 9). The integrator checks
  that B's test-module diff is additions only.

### 12.4 Gates

Per commit (design, A, B, integrator): `cargo fmt
--check`, `cargo clippy --all-targets -- -D warnings`,
`cargo test`, `cargo build`, all green. Builders add a
debug log only where section 10 puts one (the extended
`[SKILLS]` load line, Builder A); the repo rule that
code changes carry `[FEATURE]` logging is satisfied by
that line plus the rationale for silence elsewhere
(pure per-frame code, section 10) — reviewers check
nobody "helpfully" adds per-frame logs.

## 13. Builder split (LOCKED, zero overlap)

Two builder commits after this design commit, in
order. File sets are disjoint; the integrator rejects
any commit whose `git diff --name-only` escapes its
set.

- **Builder A — parser plus pure evaluation.**
  Files: `src/names/sde.rs` (section 4 struct and
  field, section 10 log field, tests P1–P3),
  `src/skills/prereqs.rs` (new file: section 5 type,
  functions, tests E1–E9), `src/skills/mod.rs` (the
  single added line `pub mod prereqs;`). A touches no
  `src/ui/` file. Suggested message:
  `feat(skills): parse prerequisites and evaluate unmet edges`.
- **Builder B — interface surfaces.** Files:
  `src/ui/skills.rs` only (section 8 helpers and
  labels, tests U1–U6). B consumes exactly A's locked
  public surface — `SdeSkillType.prerequisites`,
  `SdePrerequisite{skill_id, level}`,
  `crate::skills::prereqs::{UnmetPrerequisite,
  unmet_prerequisites, plan_prerequisite_warnings}` —
  and the shipped `Sde::skill_name_quiet`. Suggested
  message: `feat(skills): show prerequisites and warn on unmet plan entries`.

B starts only after A's commit lands, because B's code
names A's types. If B finds the locked surface
insufficient, B stops and reports; the fix is a design
amendment commit, never a B edit to A's files (and
never a duplicate evaluation inside the view).

**Integrator list.** The integrator owns no feature
file. It (1) lands commits in order design → A → B;
(2) runs the section-12.4 gates after each; (3)
verifies disjoint diffs and that `src/app/`,
`src/storage/`, `src/esi/`, `src/lib.rs`, and
`assets/` are untouched by A and B; (4) audits test
names P1–P3, E1–E9, U1–U6 and the additions-only rule
of U7; (5) spot-checks section 7 by confirming no
`add_enabled`, `SkillPlanAction`, `validate_plan`, or
`plan_progress` line changed in either diff; and (6)
records the slice in `docs/HANDOFF.md` and, if a
non-obvious lesson emerged during building, the
engineering journal, in its own commit. Push and
merge stay with the parent, as usual.

## 14. Rejected alternatives (recorded)

- **Plan-order-aware crediting** — rejected in
  section 3.2 (unwired, untested, level-blind
  precedent; intent is not achievement; order-
  dependent warnings).
- **Transitive closure with depth** (porting
  `getAllPrerequisites`) — rejected in section 3.3
  (never ran in production; repeats missing skills
  across entries; needs the cycle guard direct-only
  makes unnecessary).
- **`Option<Vec<SdePrerequisite>>`** — rejected in
  section 4: no consumer distinguishes "key absent"
  from "no prerequisites", and the existing struct's
  convention is default-not-optional.
- **Names inside `UnmetPrerequisite`** (Flutter's
  `skillName` field) — rejected in section 5: one
  resolution site in the view, no `'Skill #id'`
  fallback can exist in the pure layer.
- **A `target_level` parameter kept for parity** —
  rejected in section 3.4: a parameter whose only
  observed behaviour is being ignored is a trap for
  the next reader.
- **Ordering edges by required level** (Flutter's
  database order) — rejected in section 4: arbitrary;
  file order is the extract's own statement and the
  order tests pin.
- **Warning text starting "Cannot train"** (Flutter's
  catalogue tooltip) — rejected in section 8.1:
  false under the advisory guarantee.
- **Warnings in the catalogue and plan list** —
  rejected in sections 8.2 and 8.4: have/need
  judgements belong where a decision is made (picker,
  plan detail); the catalogue carries the requirement
  fact only.
- **A `can_train` filter or dimmed catalogue rows** —
  rejected in section 2: Flutter's two filter names
  are one duplicated predicate, and dimming without
  the levels explains nothing.

## 15. Recorded limitations (honest, not worked around)

1. **A correctly ordered plan still warns** until the
   character trains (section 3.2). This is the price
   of trained-only honesty; the disclosure (section
   8.4) says so in fixed words. Revisit only with a
   separately-grounded design for level-aware plan
   crediting, including its own oracles.
2. **Warnings ignore the training queue:** a
   prerequisite currently training still warns. The
   shipped totals disclosure already states that
   estimates ignore the queue (source 9); prerequisite
   warnings inherit the same boundary.
3. **Several unknown prerequisites are
   indistinguishable.** If a future extract ever
   carried two edges to ids this build cannot name
   (impossible in today's file, source 1), both render
   as `Unknown Skill` segments. Naming them by id
   would break rank 4; the counts and levels still
   read true.
4. **The extract can lag the game.** A skill added by
   EVE after this extract was cut is unknown here and
   carries no warning (section 3.5) — silence, never
   a fabricated requirement. Regenerating the extract
   is its own slice (section 2).
5. **Catalogue height grows.** Up to 466 additional
   requirement rows ride the existing scroll area
   (source 9); no paging or collapsing change is made
   in this slice, and the 320-point scroll cap is
   unchanged.
