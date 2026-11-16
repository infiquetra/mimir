# Fitting skill resources (two trained-skill output bonuses) — design

Status: locked for the `feat/rust-fitting-skill-resources` slice.
Base: `develop` at `974f973` (verified clean before branching; the
base fitting-resources readout from
`docs/fitting-resources-design.md` is merged there). Slice branch:
`feat/rust-fitting-skill-resources`. This document is the single
design commit; builders and the integrator implement exactly what is
locked here and nothing else.

## 1. Goal and value ranking

Apply the two grounded resource skills to the fitting-resources
readout: CPU Management raises the ship's CPU output and Power Grid
Management raises the ship's power grid output, each by 5% per
trained level of the character who owns the fitting being shown.
Module needs (`used`) do not change. When that character's skill
data is not loaded, the current base-values block renders exactly as
it does today. No network, no ESI changes, no new scopes, no
persistence: trained levels come from the skills state already
loaded for the Skills view.

Value ranking (locked, in order):

1. **Never show an unlabeled partial total.** This outranks the rest
   by a wide margin. Every number says in the view itself which two
   skills at which levels raised which output, and what is still not
   applied (section 6). It includes never showing another
   character's levels and never silently assuming a level 0 or 5
   (section 3): a skill-applied number computed from the wrong
   character, or from no data, is the same failure as an unlabeled
   partial total.
2. **Correctness of the arithmetic.** The percent chain must be
   hand-verifiable against the inspected Flutter bodies and real
   catalogue rows (sections 2 and 7).
3. **Reuse.** The existing pure function, the Skills view's trained
   lookup shape, the SDE skill catalogue, and the switch-boundary
   reset pattern of the sibling views beat new machinery.

Non-goals are locked in section 9. In particular: no module need
reductions, no module/rig/subsystem/ship output bonuses, no
implants, no calibration, no DPS/tank/capacitor numbers, no editor.

## 2. Skill set and arithmetic (locked)

Every identifier and percent below traces to an inspected body at
Flutter commit `ed698d3` (via `git show`) or to the current Rust
tree. Nothing comes from memory.

| Skill | Skill ID | Ship attribute raised | Per level | Source |
|---|---|---|---|---|
| CPU Management | 3426 | 48 (`cpuOutput`) | +5% | `dogma_engine.dart:214-215` `_skillModifiers`; `dogma_attributes.dart:3` (`cpuOutput = 48`); name in `assets/sde/skills.json` (type 3426, Engineering group 1216) |
| Power Grid Management | 3413 | 11 (`powerOutput`) | +5% | `dogma_engine.dart:215`; `dogma_attributes.dart:4` (`powerOutput = 11`); name in `assets/sde/skills.json` (type 3413) |

**Wrong-ID trap (locked as a test pin).** Skill 3418 is Capacitor
Management (`dogma_engine.dart:218` maps it to capacitor capacity,
attribute 482; `assets/sde/skills.json` agrees). It must change
nothing in this slice. Flutter pins this as test E0c.2
(`dogma_engine_test.dart`, "leftover wrong ID 3418 does not raise
CPU": 3418 at level 5 leaves CPU output at its base 125).

**Arithmetic (locked).** Flutter pushes the skill value as one
percent entry, `perLevel * level * 100`
(`dogma_engine.dart:796-804`, comment "+5%/lvl becomes +25 at V"),
into `_percentChain` (`dogma_engine.dart:168-181`). Attributes 48
and 11 are not in `_nonStackableAttributes`
(`dogma_engine.dart:115-128`, exactly the 12 resistance
attributes; the comment at 112-114 says "Everything else ESI points
at (cpu, powergrid, velocity, ...) is stackable"), so the entry
passes unpenalized. The result per dimension is therefore:

```text
applied output = base output * (1 + 0.05 * level)
```

Level 5 is ×1.25. It is **not** compounding: `1.05^5 = 1.276…` is
the mutant the tests must kill (section 7). Any arithmetically
equal formulation in `f64` is acceptable; the locked display
strings (section 5) are the oracle, so a formulation that renders
`51.25` as `51.2` is a bug even if a float-tolerance test passes.

**Grounding notes builders must not "improve":**

- The bundled dogma effect modifiers 397 (on skill 3426) and 490
  (on skill 3413) are **not** used. They are absent from Flutter's
  `skillEffectAllowlist` (`dogma_engine.dart:54-70`), so Flutter
  skips them; the `_skillModifiers` table is the only path that
  raises 48/11. Do not read `assets/sde/effect_modifiers.json` or
  `assets/sde/dogma.json` for this slice.
- Flutter's table has six more entries (velocity, capacitor
  capacity, shield capacity, armor/hull hit points, shield
  recharge). They stay unapplied here (section 9).
- Module needs are raw sums in Flutter (`cpuUsed += type.cpu;
  powerUsed += type.powergrid`, `dogma_engine.dart:688-695`) and
  stay raw sums here. Only `output` scales; `used` and
  `excluded_modules` never do.
- Flutter keeps raw `double`s and rounds only in the readout
  (`toStringAsFixed(1)`). Rust already does the same through
  `format_fitting_amount` (`src/ui/widgets.rs:69-110`, one decimal,
  thousands-grouped, half away from zero). No new rounding.

**Level clamping (locked).** Each level is clamped to `0..=5`
before use. Flutter's table path does not clamp
(`dogma_engine.dart:799`), but its sibling skill-types path clamps
with `(skillLevels[skillId] ?? 0).clamp(0, 5)`
(`dogma_engine.dart:596`), and real ESI levels are 0–5. The clamp
is deliberate hardening against hostile remote JSON (levels arrive
as defaulted `i32`s from ESI/cache/demo data): negative levels
become 0, levels above 5 become 5, and `i32::MIN`/`i32::MAX` must
not panic or overflow (convert after clamping, never
`level * 100` in integer arithmetic).

## 3. Level source and ownership (locked)

**Field (locked): `trained_skill_level`.** Flutter maps the active
character's `trainedSkillLevel` into the engine
(`fitting_providers.dart:271-284`, `_trainedSkillsForActiveCharacter`),
and the Rust Skills view precedent reads the same field
(`trained_levels`, `src/ui/skills.rs:20-31`). The Rust payload is
`Skill { skill_id, active_skill_level, trained_skill_level }`
(`src/esi/models.rs:33-43`) inside `CharacterSkills.skills`
(`src/esi/models.rs:45-53`), carried by `SkillsData`
(`src/app/state.rs:290-296`) in `state.skills: LoadState<SkillsData>`.
`active_skill_level` is never read by this slice (while a skill
trains, the two fields can differ; trained is the grounded parity
field, and a test pins the choice, section 7).

**Absent row vs level 0 (locked).** ESI returns injected skills
only, so within a **loaded** bundle an absent row means not
injected, which is arithmetically level 0 — Flutter does exactly
this (`skillLevels[skillId] ?? 0`, then skip on 0,
`dogma_engine.dart:799-803`), and the Rust catalogue display does
the same (`unwrap_or(0)`, `src/ui/skills.rs:156`). This slice is
stricter than Flutter in one place only: a bundle that is **not
loaded** is never promoted to level 0. The distinction is carried
by `Option` (section 4): `None` = not loaded → base block;
`Some(levels)` with a 0 = loaded and untrained → applied block
whose numbers equal base, with wording that says so (section 6).
A present row with `trained_skill_level` 0 and an absent row are
the same case and use the same wording. If a loaded bundle repeats
a skill ID, the last row wins (the `BTreeMap::collect` precedent
in `trained_levels`); levels are clamped per section 2.

**Ownership proof (locked: reset skills at the switch boundary).**
`SkillsData` carries no owner ID, and today `set_active_character`
(`src/app/state.rs:838-942`) resets assets, character details,
market, industry, planetary, and fittings on a real switch — but
not `skills`. Between a switch and the refresh landing,
`state.skills` still holds the previous character's `Ready` bundle
(the landing itself is owner-gated, `src/app/shell.rs:1260-1267`),
and a failed refresh preserves that stale `Ready`
(`src/app/shell.rs:1415-1417` installs `Error` only
`if !skills.is_ready()`). `Ready` alone therefore does not prove
ownership mid-switch, and rank 1 cannot be enforced without a fix.
The locked fix is the sibling pattern, not an owner stamp:

- In `set_active_character`, inside the existing
  `previous_id != character_id` guard (so same-character reselect
  keeps the loaded rows, `src/app/state.rs:856-863` pattern), add
  `self.skills = LoadState::Loading;` with a `[SKILLS]` debug line
  in the style of the neighboring resets. This is also this
  slice's required `[FEATURE]` logging addition (section 4 bans
  new per-frame logging).
- In `remove_character`, in the removed-active-character block
  (`src/app/state.rs:969-1011`, beside the assets reset), add the
  same `Loading` reset so a replacement active character never
  inherits the removed character's levels. The empty-list branch
  already sets `Empty` (`src/app/state.rs:1022`) and keeps doing
  so.
- Stamping `SkillsData` with a `character_id` was considered and
  rejected: `SkillsData`'s field set is a cross-builder contract
  ("do not add fields here", `src/app/state.rs:290-291`) and every
  constructor site would churn for what the reset already proves.
- After this fix, `state.skills` `Ready` under the current
  `active_character_id` proves the bundle belongs to that
  character: any switch or removal passes through `Loading` until
  the owner-gated landing or the startup cache rebuild
  (`src/app/shell.rs:578-612`) installs that character's bundle.
  A `Ready` bundle with an empty `skills` vec still counts as
  loaded (it was installed by a landing or the cache rebuild);
  its levels are 0/0 and it renders the applied block.
- Demo mode is unaffected: `apply_character`
  (`src/demo/data.rs:1075-1110`) synchronously installs the
  switched-to demo character's `Ready` skills, and the shell calls
  it after the switch (`src/app/shell.rs:1624-1630`), so the new
  reset is overwritten in the same drain. A test pins the order
  (section 7).
- `wallet`, `dashboard`, and `character_detail` have the same
  pre-existing gap. Fixing them is out of scope (section 9); only
  `skills` gates numbers in this slice.

**Which character's levels (locked).** Always the fitting-owning
character, which both details already enforce: the saved detail
renders under the active character's fittings list (`show`
early-returns with no active character,
`src/ui/fittings.rs:1514-1517`; the list resets on switch), and
the imported detail renders only when
`fittings_import_owner == active_character_id`
(`src/ui/fittings.rs:1323-1328`). So both call sites use the
active character's levels; for an imported fitting that is its
import owner by the gate. A switch mid-render cannot mix: egui
renders one frame from one state, and after a switch `skills` is
`Loading` (base block) until the new character's bundle lands.

## 4. Pure API (locked)

All new computation lives in `src/fitting/resources.rs` beside the
existing pure function, re-exported from `src/fitting/mod.rs`. The
existing `fitting_resources(fitting, catalogue)`
(`src/fitting/resources.rs:69`) keeps its signature and its exact
base-only semantics — its locked tests pass unmodified — and
becomes the `None` case of the skill-aware entry point, so there
is one computation core and the base output stays recoverable by
calling it. Applied outputs are computed inside the pure module;
the UI never multiplies.

```rust
/// CPU Management: +5% ship CPU output (attribute 48) per level.
/// Provenance: Flutter `dogma_engine.dart` `_skillModifiers` at
/// `ed698d3`; name in the bundled skills catalogue.
pub const CPU_MANAGEMENT_SKILL_ID: i64 = 3426;

/// Power Grid Management: +5% ship power output (attribute 11)
/// per level. Same provenance. (3418 is Capacitor Management
/// and must never appear here.)
pub const POWER_GRID_MANAGEMENT_SKILL_ID: i64 = 3413;

/// Trained levels of the two resource skills, already clamped
/// to `0..=5` by [`resource_skill_levels`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ResourceSkillLevels {
    pub cpu_management: i32,
    pub power_grid_management: i32,
}

/// Both trained levels from one loaded skills payload. Absent
/// rows and present level-0 rows both yield 0; duplicate rows
/// yield the last row; every value is clamped to `0..=5`.
pub fn resource_skill_levels(skills: &CharacterSkills) -> ResourceSkillLevels;

/// Base resources, with ship outputs raised by the two skills
/// when `levels` is `Some`. `None` is exactly
/// [`fitting_resources`]. Only `output` scales.
pub fn fitting_resources_with_skills(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
    levels: Option<ResourceSkillLevels>,
) -> FittingResources;
```

Locked semantics:

- `fitting_resources(f, c) == fitting_resources_with_skills(f, c, None)`
  for every input (pinned by test, section 7). All `ShipNoOutput`,
  excluded-count, quantity, and guard semantics of the base design
  are unchanged; skills never resurrect a `ShipNoOutput` (scaling
  happens only in the `Available` arm) and a `0.0` output stays
  `0.0`.
- `Some(levels)` scales each dimension independently by
  `1 + 0.05 * clamped_level` (section 2). `used`,
  `excluded_modules`, `remaining()` inputs, and the `is_over()`
  comparison all follow the applied output, because
  `remaining`/`is_over` read `output` (`src/fitting/resources.rs:33-41`):
  over-budget is judged against the applied output, so an
  over-budget base fit can become under-budget (section 7 pins
  both a flip and a stays-over case).
- Defensive clamp: `fitting_resources_with_skills` clamps again
  internally, so a hand-built `ResourceSkillLevels { cpu_management: 99, .. }`
  cannot exceed ×1.25 even if a caller bypasses
  `resource_skill_levels`.
- The module header docs must be updated: the current header
  (`src/fitting/resources.rs:1-16`) says skills are not applied,
  which becomes false for the new entry point. The rewrite states
  both entry points precisely (base function unchanged; skill-aware
  function applies only the two output skills) and keeps the
  not-applied remainder (need reductions, implants, module/rig/
  subsystem/ship bonuses).
- **No new logging in the pure module or the renderer.** Both run
  at render cadence; the repo rule is `[FITTING]` counts only and
  never per rendered frame. This slice's logging addition is the
  `[SKILLS]` switch/removal reset lines (section 3), which fire
  on user actions, not frames.

**Name resolution (locked: SDE plumbing, no constants).** The
applied wording names both skills (section 6). Names come from
the bundled SDE catalogue through `Sde::skill_name_quiet`
(`src/names/sde.rs:121-128`, the silent per-frame variant; the
loud `skill_name` would warn per frame on a miss). `assets/sde/skills.json`
carries 3413 → "Power Grid Management" and 3426 → "CPU
Management" (verified by read). `ui::fittings::show` today
receives `(resolver, fitting_types)` (`src/ui/fittings.rs:1506-1511`,
called once at `src/app/shell.rs:3218-3223` where `self.sde` is in
scope); it gains `sde: &Sde`, threaded through
`fittings_import_panel` into `render_fitting_resources`. Locked
constant name strings were rejected: they duplicate the catalogue
as a second source of truth. A raw skill ID is never rendered;
an SDE miss degrades to "Unknown Skill", never a number.

## 5. When applied vs base renders (locked)

`render_fitting_resources` (`src/ui/fittings.rs:1190-1226`) gains
the skill levels and the SDE handle. The branch is decided once,
from state the caller already holds:

```rust
let levels = state.skills.as_ready()
    .map(|data| resource_skill_levels(&data.skills));
```

- `Some(levels)` **and** the result is `Available` → applied block
  (section 6 wording), even when both levels are 0 and the numbers
  equal base: loaded-and-untrained is a fact the view can state,
  and silently falling back to the base wording ("Skills … are not
  applied") would misdescribe it.
- `None` (`Loading` / `Empty` / `Error` skills: never refreshed,
  mid-switch after the section 3 reset, failed refresh with no
  bundle, no active character) → **base block, byte-identical to
  today**: same heading, same lines, same disclosure, same
  unavailable sentences.
- Unavailable states (`fitting_types` is `None`, or
  `ShipNoOutput`) render exactly as today regardless of skills —
  the applied heading must never sit over an unavailable sentence.
  Implementation consequence: the heading is chosen after the
  outcome is known (applied heading only for
  `Available` + `Some`), not unconditionally as today.
- Both details share this renderer (saved call site
  `src/ui/fittings.rs:1628`, imported `src/ui/fittings.rs:1347`);
  there is no second code path and no per-detail wording fork.

**Demo behavior (locked numbers).** Demo skills are seeded split
(`assets/demo/skillqueue.json`, verified by read): Aria Voss
(90000001) has 3413 at trained level 5 and no 3426 row; Marcus
Hale (90000002) has 3426 at trained level 5 and no 3413 row.
Neither fixture changes in this slice. Demo always has `Ready`
skills, so the demo view switches to the applied block. Hand-derived
from the base design's locked demo numbers (Rifter 130.0/41.0,
Punisher 140.0/67.0 — `assets/sde/fitting_types.json` types
587/597, verified by read) through `format_fitting_amount`
(41.0 × 1.25 = 51.25 renders `51.3 MW`; remainders likewise):

- Demo Brawler (Aria, PG L5 only): `CPU: 84.0 tf of 130.0 tf used
  (46.0 tf left)`; `Power grid: 3.0 MW of 51.3 MW used (48.3 MW
  left)`; excluded lines 2/2.
- Mission Runner (Aria): `CPU: 30.0 tf of 130.0 tf used (100.0 tf
  left)`; `Power grid: 1.0 MW of 51.3 MW used (50.3 MW left)`;
  excluded 1/1.
- Demo Runner (Marcus, CPU L5 only): `CPU: 57.0 tf of 175.0 tf
  used (118.0 tf left)`; `Power grid: 2.0 MW of 67.0 MW used
  (65.0 MW left)`; excluded 1/1.
- Demo sample EFT import (used 114.0/31.0): imported by Aria →
  `CPU: 114.0 tf of 130.0 tf used (16.0 tf left)`,
  `Power grid: 31.0 MW of 51.3 MW used (20.3 MW left)`; imported
  by Marcus → `CPU: 114.0 tf of 162.5 tf used (48.5 tf left)`,
  `Power grid: 31.0 MW of 41.0 MW used (10.0 MW left)`. Tests pin
  both importers (section 7). The existing base demo test
  (`demo_fixture_resources_match_the_locked_demo_story`) keeps
  pinning the base function and passes unmodified; the applied
  demo numbers are new pins, not edits to it.

## 6. UI wording (locked verbatim)

Flutter labels nothing about skills in its readout
(`fitting_editor.dart:397-471` at `ed698d3` shows only `CPU` /
`Power Grid` values), so the applied wording below is new, written
in the view's existing plain voice. Both states are complete here;
no other string may wrap these numbers.

**Base state (`None`, and all unavailable states) — byte-identical
to today.** Heading `Fitting resources (base values)`, the two
`resource_line` lines (`CPU`, `Power grid`; over-budget in
`egui::Color32::LIGHT_RED`), the per-dimension excluded lines, and
the disclosure, all exactly as pinned now
(`src/ui/fittings.rs:1131-1140`):

> Base values from Mimir's bundled item data. Skills, implants, and
> bonuses from modules, rigs, subsystems, and the ship itself are not
> applied, so these numbers can differ from EVE.

Unavailable sentences also unchanged:
`Fitting resources unavailable: Mimir's bundled item data failed to load.`
and `Fitting resources unavailable: Mimir's bundled item data has no ship output data for this fitting's ship.`

**Applied state (`Available` + `Some(levels)`).** Lines render in
this order:

1. Heading: `Fitting resources (with skill bonuses)`
2. CPU line and Power grid line, same `resource_line` templates
   and over-budget colour as base, outputs now the applied outputs.
   Only the applied output is shown (not base beside it): the skill
   lines below state the percent, and the base value stays
   recoverable through the base function, not the view. Showing
   both numbers per line was rejected as clutter that buries the
   one honest total.
3. CPU skill line, from a pure helper (unit-pinned without egui,
   like `resource_line`). Templates, `{name}` =
   `sde.skill_name_quiet(CPU_MANAGEMENT_SKILL_ID)`,
   `{pct}` = `level * 5`:
   - level > 0: `CPU output includes {name} level {level} (+{pct}%).`
     — e.g. `CPU output includes CPU Management level 5 (+25%).`
   - level 0: `CPU output includes no bonus: {name} is level 0.`
     — e.g. `CPU output includes no bonus: CPU Management is level 0.`
4. Power grid skill line, same templates with `Power grid output`
   and the 3413 name — e.g. `Power grid output includes Power Grid
   Management level 5 (+25%).`
5. Excluded-module lines, unchanged per-dimension templates.
6. Applied disclosure, verbatim, always last:

> Ship outputs include only the two skill bonuses above, from
> Mimir's bundled item data and this character's trained skill
> levels. Module need reductions, implants, and bonuses from
> modules, rigs, subsystems, and the ship itself are not applied,
> so these numbers can differ from EVE.

Every still-excluded class the base disclosure named stays named,
and module need reductions (the Weapon Upgrades family, which
Flutter never applied to usage) are now named explicitly because a
reader who sees one skill family applied will assume the other
was too. No string in this slice calls these numbers fitting
"statistics" or a "simulator" result.

## 7. Test plan (locked)

Oracle sources: Flutter `dogma_engine_test.dart` at `ed698d3`
uses a **synthetic** Rifter (outputs 125.0/37.0, helper at
`4335-4380`); its pins are `125 * 1.25 = 156.25` for 3426 at
level 5 ("character skills modify ship attributes postMul" and
E0c.1) and E0c.2's `3418 at level 5 leaves CPU at 125`. Rust
tests recompute on the **real** bundled rows (Rifter 587:
130.0/41.0; Punisher 597: 140.0/67.0) and label any synthetic
reproduction as synthetic in the test comment, per the base
design's convention. Real-row table (×(1 + 0.05·level)):

| Level | CPU (base 130.0) | Power grid (base 41.0) |
|---|---|---|
| 0 | 130.0 | 41.0 |
| 1 | 136.5 | 43.05 |
| 2 | 143.0 | 45.1 |
| 3 | 149.5 | 47.15 |
| 4 | 156.0 | 49.2 |
| 5 | 162.5 | 51.25 |

**Pure calculation** (`src/fitting/resources.rs`, Builder A),
floats within `1e-9` unless a string pin is stated:

- Both dimensions at levels 0, 1, 2, and 5 on the real Rifter
  (table above). Level 2 (143.0, not 143.325) and level 5
  (162.5, not 130 × 1.05⁵ = 165.916…) are the mutation-sensitive
  pins: they fail under per-level compounding. Dimensions are
  independent (CPU L5 + PG L0 scales CPU only, and vice versa).
- Synthetic Flutter oracle via a `FittingTypes::from_json`
  fixture (125.0/37.0): 3426 L5 → 156.25 (labelled synthetic).
- `None` equals base: `fitting_resources_with_skills(f, c, None)
  == fitting_resources(f, c)` on a real fit and on a
  `ShipNoOutput` fit.
- Lookup (`resource_skill_levels`): absent rows → 0/0; present
  rows read `trained_skill_level` (a row with active 5, trained 2
  yields 2); present 0 → 0; 3418 at level 5 (the E0c.2 trap) →
  0/0 and applied output equals base; duplicate rows → last wins;
  levels −3, 7, `i32::MIN`, `i32::MAX` clamp to 0, 5, 0, 5 with
  no panic; a hand-built `ResourceSkillLevels` above 5 is also
  clamped inside `fitting_resources_with_skills`.
- Only `output` scales: `used` and `excluded_modules` identical
  between base and applied on a fit with excluded rows;
  `ShipNoOutput` stays `ShipNoOutput` at L5/L5; zero-output ship
  fixture stays 0.0/0.0 (not over hull-only, over with a module).
- Over-budget against applied output (Rifter + Damage Control II
  rows at 30.0 CPU each): 5 rows = 150.0 used is over base 130.0
  and under applied 162.5 at CPU L5 (the flip); 6 rows = 180.0
  stays over at L5 (remaining exactly −17.5).

**Ownership** (`src/app/state.rs`, Builder B), mirroring
`switching_character_clears_stale_assets`:

- `Ready` skills + switch to another character → `Loading`;
  same-character reselect keeps `Ready`.
- Remove the active character with a replacement present →
  replacement does not inherit `Ready` skills (`Loading` until a
  landing); remove the last character → `Empty`.
- Demo switch still lands `Ready` (seed, switch, `apply_character`
  order) with the switched-to character's rows.

**UI wording and demo pins** (`src/ui/fittings.rs`, Builder B),
string-exact:

- Existing base pins (`fitting_resource_unavailable_and_disclosure_wording`,
  `demo_fixture_resources_match_the_locked_demo_story`, formatter
  tests) pass **unmodified** — this is the byte-identical-base
  gate, stated as a gate rather than re-pinned.
- New applied pins: heading, disclosure, and skill-line helpers
  at level 5 (`+25%`), level 1 (`+5%`), and level 0 (no-bonus
  template), with names resolved through the real bundled SDE
  ("CPU Management", "Power Grid Management" — pinning the
  resolved strings, never 3426/3413).
- Applied demo story, levels taken from the real
  `assets/demo/skillqueue.json` through `resource_skill_levels`
  (not hand-typed tuples): the section 5 strings for Demo
  Brawler, Mission Runner, Demo Runner, and the sample import
  under **both** importers, including the `51.3 MW` / `48.3 MW` /
  `50.3 MW` / `20.3 MW` rounding pins (51.25 → 51.3, half away
  from zero). Asserting floats alone is insufficient here; the
  rendered strings are the oracle.

**Gates at every commit** (repo standard): `cargo test`,
`cargo clippy --all-targets -- -D warnings`, `cargo fmt --check`.
Existing skills, state, fitting, import, export, and demo tests
pass unmodified except where this design explicitly adds pins.

## 8. Integrator list (locked)

The integrator (not the builders) makes these changes after both
builders land:

- **README** — three sites, keeping the rule that resources are
  not fitting statistics and never attaching "simulator" or
  "statistics" to the new numbers:
  1. The Fittings bullet (line 22): the resources sentence gains
     the applied state in the view's honesty terms — ship outputs
     include CPU Management and Power Grid Management at the
     owning character's trained levels when that character's
     skill data is loaded (base values otherwise), with module
     need reductions, implants, and module/rig/subsystem/ship
     bonuses still not applied — and still states there are no
     DPS, tank, capacitor, or speed numbers.
  2. The Roadmap Fitting bullet (line 31): the parenthetical's
     "base CPU and power grid readout" gains the two-skill
     application; "ship fitting simulator with fitting
     statistics" stays not implemented.
  3. The Status paragraph (line 37): the "only fitting features"
     enumeration's readout phrase updates the same way; "the
     fitting simulator is not present yet" stays true.
- **Engineering journal** — dated entries in the same change set
  (repo rule): a `LEARNINGS.md` entry with Evidence (file:line),
  Mechanism, and a one-line generalizable rule for (a) the
  loaded-vs-untrained distinction (absent ≡ 0 only inside a
  loaded, owner-proven bundle; Flutter conflates the two), and
  (b) the stale-skills ownership gap found and fixed in section 3
  (a `Ready` bundle with no owner stamp survives a switch and a
  failed refresh). Plus a short `DECISIONS.md` entry if the
  reset-at-switch-for-skills convention should bind later slices
  (it should: state the revisit condition).
- Confirm the slice diff contains no ESI, scope, persistence,
  network, catalogue, generator, or demo-asset changes, and run a
  demo-mode visual pass over the section 5 demo story (all three
  demo fits as both characters where ownership allows, plus the
  sample import) before reporting done.

## 9. Exclusions (locked)

Out of this slice, by name: module need reductions (Weapon
Upgrades family and every other need-side skill — Flutter never
applied them to usage, so applying them now would exceed grounded
parity); module, rig, subsystem, and ship output bonuses
(Co-Processor / Reactor Control Unit class effects, ship role and
trait bonuses — Flutter engine-supported but test-unexercised; a
later slice); the six other `_skillModifiers` entries (velocity,
capacitor capacity, shield capacity/operation, armor/hull hit
points); implants; calibration; DPS, volley, tank/EHP, capacitor,
speed/navigation, targeting, and every other fitting statistic;
stacking penalties of any kind; effect modifiers 397/490 and any
runtime use of `dogma.json` / `effect_modifiers.json`; the fitting
editor and any fitting mutation; per-module resource itemization;
percentages and bars; ESI calls, scopes, stored data, catalogue
or generator changes, and demo fixture changes; owner-stamping
`SkillsData`; fixing the same switch-boundary gap for `wallet`,
`dashboard`, or `character_detail` (recorded in section 3, not
this slice). Anything on this list appearing in a builder commit
is a design breach, not a bonus.

## 10. Ownership (locked)

Small atomic commits, `type(scope): description`, no attribution.
Nobody pushes or merges; the parent does that.

- **Builder A — pure calculation.** (1) `src/fitting/resources.rs`:
  skill-ID constants, `ResourceSkillLevels`, `resource_skill_levels`,
  `fitting_resources_with_skills` with `fitting_resources` as its
  `None` case, header rewrite, pure tests; re-exports in
  `src/fitting/mod.rs`. One commit, compiling and passing gates
  with no UI change.
- **Builder B — ownership fix and render wiring.** (2)
  `src/app/state.rs`: skills reset on switch and on
  removed-active, with state tests (own commit: it changes Skills
  view behavior on switch and must be reviewable alone).
  (3) `src/ui/fittings.rs` + the one `src/app/shell.rs` call site:
  `sde: &Sde` threading, branch decision, applied heading/disclosure/
  skill-line helpers, both call sites, wording and demo pins.
  Builder B changes no `src/fitting/`, catalogue, or demo files.
- **Integrator.** (4) README + engineering journal (section 8),
  any cross-builder seam fix the two halves reveal (signature
  drift between sections 4 and 5 is reconciled back to this
  document, not to whichever builder wrote first), final gates,
  and the demo visual pass.

Sequencing: A(1) and B(2) are independent and may land in either
order; B(3) needs both; integrator (4) last.
