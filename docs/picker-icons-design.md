# Skill type icons in the skill-plan picker — design

Base: `develop` at `8fc586a` (796 tests, post skill-catalogue-icons
merge [#596](https://github.com/infiquetra/mimir/pull/596)).
Branch: `feat/rust-picker-icons`. Slice goal: show each rendered
add-skill picker row's skill type icon in the Skills view
(`show_skill_picker`, `src/ui/skills.rs:966-1060`) through the
shipped `ImageKind::Type` pipeline, reusing the bundled
skill-catalogue guard #596 installed.

This slice's design question is the volume bound, not the widget
and not the guard. The picker is the one surface the
skill-icons design named and excluded on purpose:
`docs/skill-icons-design.md` sections 8–9 say picker icons need
their own design because the picker result list is uncapped, and
the 2026-11-17 skill-icons entry in
`docs/engineering-journal/DECISIONS.md` repeats that the installed
guard set existing is "explicitly not authorization to add
ensures elsewhere." This document is that design. Verdict:
**ship, UI-only, builder B only** — the guard reading (section 3)
settles to "every picker row id is already authorized, no guard
text changes," and the whole design work is the picker-local
100-row render cap locked in section 2. If that bound had not
been honest, this design would ship nothing; section 2 shows why
it is.

Locked in one paragraph: a new separate constant
`SKILL_PICKER_RENDER_MAX = 100` caps picker rows actually
rendered per frame (filter before the cap, one disclosure line
when suppressed); the single icon ensure sits inside that capped
set; rows draw the shipped 20-point `TYPE_ICON_PX` icon left of
the unchanged label; the `PortraitImageCache` the Skills `show`
already owns is threaded through exactly two intermediate
functions to the picker; no file outside `src/ui/skills.rs`
changes in the builder commit.

Standing rules for the whole slice: verify from bodies read this
session, literal test expectations, the user interface never shows
raw ids, `[PORTRAIT]` logs carry kind and id only (never a URL, a
name, pasted text, or an error body), small atomic commits
`type(scope): description` with no attribution, no push or merge
(the parent owns the branch after the design commit), gates
(`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
`cargo test`, `cargo build`) pass at every commit. Demo makes zero
network calls.

Evidence in this document comes from bodies re-read during this
design session on the `8fc586a` tree, plus the two read-only
discovery passes run for this slice (picker structure, guard and
prune audit), whose load-bearing claims were re-read from bodies
here: `src/ui/skills.rs` (module head and
`SKILLS_CATALOGUE_RENDER_MAX` at 1–24, `picker_row_label` and the
prerequisite and warning lines at 189–239, stale sweeps at
259–309, `show` at 333–537 with the catalogue budget at 447–522,
`show_plans_section` at 548–672, `show_plan_detail` at 679–874,
`show_plan_editor` at 880–960, `show_skill_picker` at 966–1060,
the picker wording pins in `plan_wording_matches_design_strings`
at 1269–1277, and the catalogue queue and demo tests at
1449–1618), `src/names/sde.rs:180-191` (`search_skills`),
`src/app/state.rs` (`skill_catalogue_type_ids` at 731–734, the
picker fields at 802–813, the character-switch picker reset at
1049–1058, `image_id_known` and the installer at 1339–1417,
`request_portrait` at 1451–1488, `SkillsData` at 325–328),
`src/app/shell.rs` (`decide_portrait_start` at 379–387,
`apply_portrait_landing` at 452–485, the installer call at 860,
`start_portrait_fetches` at 2216–2283, the Skills dispatch at
3777–3779), `src/ui/portraits.rs:36-47` (sizes), 78–88 (prune),
189–211 (the ensure delegations), and 266–298 (the blank box and
`show_type_icon`), `src/skills/plans.rs:34-43` (`SkillPlan`),
`src/esi/models.rs:33-53` (`Skill`, `CharacterSkills`),
`src/demo/data.rs:1274-1371` (`seed_demo_state`),
`docs/skill-icons-design.md` in full, the 2026-11-17
skill-icons `DECISIONS.md` entry (lines 29–36), and the bundled
`assets/sde/skills.json` (counted this session, section 1).

## 1. Current state (verified)

- `show_skill_picker(ui, state, sde, active_id, plan, trained)`
  (`src/ui/skills.rs:966-973`) takes **no**
  `PortraitImageCache`. The call chain is `show` (333) →
  `show_plans_section` (548, called at 536) →
  `show_plan_detail` (679, called at 660–668) → the picker,
  gated by `state.skill_plan_picker_open` at 750–752. `show`
  already takes `cache: &mut PortraitImageCache` and prunes at
  336, before the no-character return, and the shell dispatch
  already passes it (`src/app/shell.rs:3777-3779`) — both landed
  in #596. The two middle functions do not take the cache, so a
  picker icon requires threading it through exactly those two
  (section 4). No shell change is needed in this slice.
- The picker opens with `widgets::search_box(..., "Search
  skills to add", false)` (976–982; `grab_focus = false`, so the
  `/` shortcut stays with the catalogue box above it), returns
  early with the unavailable panel when `sde.groups.is_empty()`
  (983–986), then computes
  `let results = sde.search_skills(&query);` (987–988) and
  returns the "No skills match the search." panel when that is
  empty (989–991). Otherwise it renders every result, in
  `search_skills` order, inside its own
  `ScrollArea` (`skill_picker_scroll`, `max_height` 320.0, at
  993–996, nested inside the shell outer scroll exactly like the
  catalogue scroll) with a plain `for skill in &results` loop
  (997). There is no `RENDER_MAX`, no `take`, no `show_rows` —
  **the picker is provably unbounded today**, unlike the shipped
  catalogue cap `SKILLS_CATALOGUE_RENDER_MAX = 100` in the same
  file (24).
- Per-row construction (997–1058), the behaviour this slice must
  keep unchanged apart from the icon cell (section 4):
  `trained_level` from the `trained` map clamped to 0–5
  (998–1002); `in_plan` by scanning `plan.entries` (1003);
  `picker_row_label` — `"{name} — trained level {level}"` or
  `"… — trained level unavailable"` (191–196) — plus the suffix
  `" — already in this plan"` (1006) or
  `" — already trained to level 5"` (1007–1008), drawn today as
  a bare `ui.label(text)` (1010); the `prerequisite_line`
  "Requires: …" (206–216) as a second label (1011–1013); the
  unmet warning (220–239) as a third label, only when `trained`
  is `Some` (1014–1019); and level buttons 1–5 in a horizontal
  (1021–1056) only when `!in_plan && trained_level != Some(5)`,
  each disabled when `level <= current` and all enabled when
  skills are not loaded (`None => true`, 1027–1030). A click
  appends a `SkillPlanEntry` and stamps one `ReplaceEntries`
  action only when the one-slot `skill_plan_action.is_none()`
  (1036–1053), leaving the picker open for the next add.
- `Sde::search_skills` (`src/names/sde.rs:181-191`) lowercases
  the query, substring-filters `self.types` by `type_name`,
  sorts by `type_name`, and allocates a fresh `Vec` every frame.
  It logs `query_len` only (182) — never the text. An empty
  query matches every bundled type, and
  `state.skill_plan_picker_search` defaults to `""`
  (`src/app/state.rs:810-811`), so **first open with an empty
  search is the worst case, and it is the common case**. That
  inverts the catalogue, whose first frame at an empty search
  renders zero rows because every group starts collapsed.
- **Counts, scripted this session from
  `assets/sde/skills.json`** (495 types, 495 distinct positive
  `typeId`, minimum 2403, no duplicate names, 24 groups, 1
  category 16 "Skill"): picker results per query — `""` 495,
  `"e"` 447, `" "` 447, `"a"` 404, `"pe"` 101, `"ro"` 100,
  `"ship"` 31, `"x"` 16, `"turret"` 12, `"gunnery"` 1,
  `"zzzz"` 0. In the picker's name-sorted order the empty
  query begins 60381 "Abyssal Ore Processing", 3452
  "Acceleration Control", 16622 "Accounting"; position 100 is
  21666 "Capital Hybrid Turret", position 101 is 28585 "Capital
  Industrial Reconfiguration" (the unique match for its own
  name), and position 495 is 23124 "Yan Jung Technology".
  Section 6 pins these literals.
- The plans section renders in **every** skills load state:
  `show` calls `show_plans_section` unconditionally after the
  skills match (533–536), and `trained` derives only from
  `skills.as_ready()` (577–591), so with skills Loading, Empty,
  or Error the picker still lists bundled results with
  "trained level unavailable" labels and every level button
  enabled. The catalogue, by contrast, renders only in the
  `Ready` arm (342–344). Picker icons therefore queue in a
  state where catalogue icons do not. That is a stated
  divergence of the shipped plans design, not a guard bug —
  section 3 settles it.
- Character switch closes the picker:
  `set_active_character`, when the character changes, resets
  the plan list and owner and sets `skill_plan_picker_open =
  false` with `skill_plan_picker_search.clear()`
  (`src/app/state.rs:1049-1058`). Portrait state and requests
  are keyed by `(kind, id)` and are never cleared by a switch,
  so an icon fetched under one character is correct art under
  every character (the image names the skill type).
- Everything downstream of an ensure already exists and is
  keyed by the same `(ImageKind::Type, type_id)` the catalogue
  uses: `ensure_type_icon_requested` queues only a
  `NotRequested` key and silently refuses non-positive ids
  (`src/ui/portraits.rs:189-211`); `request_portrait` re-checks
  the one guard and dedupes (`src/app/state.rs:1451-1488`); the
  shell drain re-checks the guard at spawn, fetches at
  `TYPE_ICON_SIZE = 64` under the app-wide 4-fetch semaphore,
  cache-first (`src/app/shell.rs:2216-2283`); the landing
  inserts only while the guard holds (452–485); texture prune
  retains by the same guard (`src/ui/portraits.rs:78-88`).
  A `Failed` key never re-queues from the render path.
- **Unprobed, inherited from #596 and stated plainly:** no body
  proves all 495 bundled skill types return an icon at
  `types/{id}/icon`. An icon-less skill keeps the shipped blank
  faint box beside its correct resolved name forever, at most
  one failed request per app run — the failure shape the
  skill-icons design section 3(b) already accepted for the
  catalogue. This slice neither probes nor improves it.

## 2. The volume bound (locked)

Four mechanisms were considered. One is honest for this
surface; if none had been, this design would ship nothing.

**No cap, ensure every rendered row. Rejected.** First open is
495 rows (section 1), so one click on "Add skills..." would
queue up to 495 distinct keys in a single frame — five times
the catalogue's global budget — spawning up to 495 drain tasks
behind the semaphore, about 1.6–3.3 MB of image traffic, for a
list the user may close immediately. Unlike the catalogue, no
collapsed-header default softens this: the worst case is the
default case. Naming "495 per frame" as an honest bound would
be honest but pointless: it bounds nothing the 495-id guard set
did not already bound, and no shipped icon surface opens with
its full session budget.

**`ScrollArea::show_rows` virtualization. Rejected**, for the
three reasons the catalogue design section 2 recorded, each
re-verified here: picker rows are non-uniform (one to three
labels plus an optional buttons row per skill, 997–1058), so
the view would have to flatten into fake uniform rows; the
picker scroll is already nested inside the shell outer scroll;
and, load-bearing, virtualization bounds widgets per frame but
**not** fetches per session — scrolling the picker still
ensures all 495 over time, so presenting it as the fetch bound
would be dishonest. (The retired Flutter browser search did
virtualize with `ListView.builder`; precedent is not a bound.)

**Expanded-only (catalogue option B). Inapplicable.** The
picker has no collapsing headers, so the "collapsed renders
nothing" half of the catalogue hybrid does not transfer. Any
bound here must be numeric.

**A picker-local global render cap (the locked shape).**
Mirror the shipped caps — every capped view in the tree carries
its own named 100 (`ASSETS_RENDER_MAX`, `FITTINGS_RENDER_MAX`,
`EXPLORATION_RENDER_MAX`, `BLUEPRINT_RENDER_MAX`, the planets
caps, and `SKILLS_CATALOGUE_RENDER_MAX` in this same file) —
with filtering before the cap and one disclosure line. Locked
mechanism, in `src/ui/skills.rs`:

```rust
pub const SKILL_PICKER_RENDER_MAX: usize = 100;
```

- **Separate constant, locked — not a reuse of
  `SKILLS_CATALOGUE_RENDER_MAX`.** The value is the shipped 100,
  but the picker and the catalogue are different surfaces with
  different row orders, different row contents, and no reason
  their tunings must move together; sharing the catalogue
  constant would make a catalogue cap change silently move the
  picker disclosure. Every shipped precedent gives each surface
  its own named constant, and section 6 pins this one at 100
  with its own literal test.
- **Independent budget, locked — not a frame budget shared with
  the catalogue.** Both surfaces can render in one `show` frame
  (catalogue in the `Ready` arm, picker under the selected
  plan). Sharing one budget would let an expanded broad
  catalogue spend all 100 and leave the picker rendering
  nothing — including no level buttons — which breaks picker
  behaviour, not merely its icons; it would also thread a
  `remaining` counter out of a `ScrollArea` closure in the
  `Ready` arm down through the plans section for no benefit any
  shipped surface claims. Each surface keeps its own 100. The
  combined claim is stated plainly below.
- The flat picker list needs no `remaining` variable: inside
  the existing `skill_picker_scroll` closure, iterate
  `results.iter().take(SKILL_PICKER_RENDER_MAX)`. The `take`
  **is** the budget. A skill row beyond it renders nothing —
  no icon, no label, no "Requires:" line, no warning, no level
  buttons — exactly as a capped catalogue row renders nothing
  including its prerequisite line, so the cap can never orphan
  a prerequisite, warning, or button under the wrong skill,
  and the ensure inside the loop (section 4) can never reach
  a capped row.
- The cap suppressing the whole row — buttons included — is a
  real, stated behaviour change, not a cosmetic one: at an
  empty or broad search, skills past row 100 in name order are
  not addable until the search narrows. That is the same cost
  the catalogue cap already charges its rows, and the picker
  search box sits directly above the list for exactly this.
  Filtering runs before the cap (`search_skills` returns the
  already-filtered, already-sorted list), so any skill is at
  most its own name's substring away from the rendered window;
  section 6 pins a beyond-cap skill becoming addable-visible
  under its own name. The alternative — rendering every row's
  text and buttons but ensuring icons only for the first 100 —
  was rejected: rows past 100 would draw a blank box that
  never loads while the search stays broad, indistinguishable
  from a failed fetch, with no disclosure to explain it.
- When `results.len() > SKILL_PICKER_RENDER_MAX`, draw exactly
  one disclosure label inside the scroll closure, after the
  loop, in the catalogue's exact wording shape:

  ```rust
  ui.label(format!(
      "Showing {} of {} skills.",
      SKILL_PICKER_RENDER_MAX,
      results.len()
  ));
  ```

  At exactly 100 results nothing is suppressed and no
  disclosure draws (section 6 pins `"ro"` at exactly 100). The
  empty-results early return at 989–991 stays ahead of the
  scroll, so the disclosure never draws over the "No skills
  match" panel, and the unavailable-SDE return at 983–986 is
  likewise untouched.

What the bound does and does not claim, plainly:

- Per frame, picker: at most 100 picker rows render, at most
  100 icon ensures run, each queueing at most once per state of
  its key (`ensure` queues only `NotRequested`;
  `request_portrait` dedupes). One full picker window is at
  most about 0.7 MB of image traffic at the shipped 64-pixel
  fetch, at most 4 in flight app-wide.
- Per `show` frame, both surfaces: at most 200 ensures (100
  catalogue + 100 picker, independent budgets), at most 200
  distinct new keys, fewer when the windows overlap — overlap
  dedupes by construction because both ensure the same
  `(Type, id)` keys and only `NotRequested` queues.
- Per session: at most **495** distinct skill icons can ever
  fetch from the Skills view as a whole — the whole bundled
  catalogue, unchanged from #596 — each only because its row
  rendered in one surface or the other, never from a
  background walk. The picker adds **no** new retained worst
  case: same 495 keys, about 7.7 MiB of GPU textures and a
  few MB of disk at the catalogue design's constants.
- First picker open, empty search: exactly 100 rows, 100
  ensures ("Showing 100 of 495 skills."). Steady state after
  any window has rendered: 0 new queues until the search
  reveals a row whose key is still `NotRequested`.

## 3. Guard verdict (locked): already authorized, nothing changes

The skill-icons design (section 8) and the `DECISIONS.md`
entry both require a separate guard reading before any picker
ensure exists. Run from bodies this session, the reading
settles without any guard change:

- `MimirApp::new` installs the guard set once, copying every
  `sde.types` `type_id` through
  `install_skill_catalogue_type_ids(&Sde)`
  (`src/app/state.rs:1411-1417`, called at
  `src/app/shell.rs:860`); an SDE that failed to load installs
  an empty set. `Sde::search_skills` iterates that same
  `self.types` (`src/names/sde.rs:184-188`), and the picker
  renders only `search_skills` results
  (`src/ui/skills.rs:988`), so **every picker `skill.type_id`
  is in the installed 495-set by construction**. The picker
  early-returns when `sde.groups.is_empty()` (983–986),
  exactly the empty-install case: nothing renders, nothing
  needs authorizing. Views read the same `app.sde` the
  installer copied from, so no second install path can
  diverge.
- The `Type` arm of the one guard therefore already admits
  every picker row through its fourth clause,
  `skill_catalogue_type_known` (`src/app/state.rs:1358-1363`,
  1402–1404). **This slice adds no arm, no helper, no field,
  no installer call, and no doc edit to the guard:** the
  `image_id_known` doc and the `ensure_type_icon_requested`
  doc (`src/ui/portraits.rs:201-211`) already name "the bundled
  skill catalogue's skill types" as the source, and picker
  rows are those types. `src/app/state.rs`,
  `src/app/shell.rs`, `src/ui/portraits.rs`, and
  `src/names/sde.rs` are untouched by the builder commit —
  that untouched-guard fact is what makes this slice
  builder-B-only (section 5).
- Provenance is the catalogue's, inherited unchanged: the
  authorized set is the closed, compile-time-fixed 495 bundled
  skill ids, and the only user input on the surface,
  `skill_plan_picker_search`, is consumed solely as a
  substring filter over bundled names — never parsed as or
  resolved to an id. Search text can choose which bundled
  rows are visible (and therefore, within the cap, which
  ensure), the same visibility choice every shipped icon
  surface's search already makes; it cannot name a fetch
  target outside the installed set.
- Prune, landing, drain, and removal need no reading of their
  own: all four consult the same unchanged guard, so picker
  icons inherit the catalogue-static app-lifetime retention
  #596 locked (prune keeps them across switches and searches;
  the last-character clear-all is the sole exception, with the
  disk cache-first path covering the return), and a landing
  queued before a character switch still lands after it — the
  picker is closed by the switch (section 1), but the image
  names a skill type, not a character, so there is no stale
  owner to protect.
- The skills-not-loaded divergence (section 1) is accepted as
  designed: the plans section — picker included — is visible
  and editable in every skills load state by the shipped
  skill-plans design, and the static guard authorizes bundled
  types regardless of character state by the shipped #596
  design. A picker opened before skills load queues icons for
  its rendered window while the catalogue above it shows a
  loading panel. Both behaviours are their designs working;
  section 6 pins the picker side literally so the divergence
  is tested, not accidental.

## 4. Row layout, ensure site, cache threading, demo, logs

**Render size: `TYPE_ICON_PX = 20.0`, reused, no new constant**
(`src/ui/portraits.rs:36-41`). The retired Flutter skill
browser dialog drew its picker icons at 40 against a checkbox
row with 12-point padding (discovery verified this at the
retired tree); the Rust picker is a dense text list with
prerequisite and warning lines between rows, the shipped Rust
row precedent is 20 across fittings, assets, and the catalogue
one screen above the picker, and the catalogue design section
5 already rejected 32 in favour of 20 for the adjacent surface.
Locking 20 keeps the two skill surfaces in one view visually
consistent. 64 (`MARKET_TYPE_ICON_PX`) is a detail header, not
a row, and is not reused. Fetch 64 → render 20 keeps the
shipped downscale.

**Row layout.** Only the first line of each rendered picker
row changes: the bare `ui.label(text)` at 1010 becomes the
catalogue's exact horizontal shape (487–497), with the ensure
immediately before it:

```rust
ensure_type_icon_requested(state, skill.type_id);
ui.horizontal(|ui| {
    show_type_icon(ui, cache, state, skill.type_id, TYPE_ICON_PX);
    ui.label(text);
});
```

**Ensure site: exactly one, inside the capped set.** That
single `ensure_type_icon_requested(state, skill.type_id)`,
inside the `take(SKILL_PICKER_RENDER_MAX)` loop, run for every
rendered skill row regardless of its `in_plan` or
trained-level-5 state — the icon is row furniture, not an
add-eligibility signal, and gating it on eligibility would
make the ensure set depend on plan contents for no bound gain
(the cap already bounds it). No ensure anywhere else in this
slice: none for capped-off rows, none in the "Requires:" or
warning lines (they name other skills in text but carry no
icon, exactly as in the catalogue), none in the level-button
row, none in the plan list, plan detail entries, editor,
confirmations, or training queue (section 7), no prefetch.
The ensure set therefore equals the rendered picker set by
construction. The label string is the current `text` built at
1004–1009, byte-for-byte: `picker_row_label` plus both
suffixes are untouched, `skill.type_id` is never formatted
into any string, and the resolved bundled name in the label
carries the meaning while the icon loads or after it fails.
Everything below the first line — prerequisite line
(1011–1013), warning line (1014–1019), level buttons with
their enable rule and `ReplaceEntries` stamping (1020–1057) —
is untouched code, outside the new horizontal, in the same
order. Apart from the icon cell and the section 2 cap, picker
behaviour is byte-identical: same strings, same states, same
buttons, same one-slot guard, picker still open after an add.
The placeholder for every non-`Ready` state is the shipped
blank faint box in the same 20-point slot, so rows never
change height as icons land; the first line's height becomes
the 20-point slot height, the same cost catalogue rows already
pay. No new carry-through struct is needed: the loop already
holds `skill: &SdeSkillType` with its `type_id`, unlike the
catalogue rows #596 had to teach.

**Cache threading (exact).** `cache: &mut PortraitImageCache`
is added immediately after `sde` — the argument order `show`
already uses (333) — at exactly three private functions, with
their single call sites updated and nothing else reordered:

- `show_plans_section(ui, state, sde, cache)` (548; call site
  536 becomes `show_plans_section(ui, state, sde, cache);`)
- `show_plan_detail(ui, state, sde, cache, active_id, trained,
  attributes, plan)` (679–687; call site 660–668)
- `show_skill_picker(ui, state, sde, cache, active_id, plan,
  trained)` (966–973; call site 750–752)

`show`'s own signature, its prune at 336 (already before the
no-character return, so picker textures prune on frames that
render no rows, normally a no-op under the static arm), the
shell dispatch, and every other caller are unchanged — each
threaded function has exactly one call site in this file, all
verified this session. `ensure_type_icon_requested`,
`show_type_icon`, `TYPE_ICON_PX`, and `PortraitImageCache` are
already imported at the module head (8–10); no import changes.

**Demo: zero network, no change needed.** Demo installs
`Ready` skills and an active character from bundled data
(`seed_demo_state`, `src/demo/data.rs:1274-1351`), startup
installs the catalogue guard set before seeding
(`src/app/shell.rs:860`), and demo plans load through the
shipped demo route into the same `skill_plans` state. A demo
picker therefore behaves as the live `Ready` case: ensures
queue keys for its rendered window and
`decide_portrait_start` refuses every spawn kind-agnostically
in demo (379–387, applied at 2222–2228; the shipped
decision-table test pins `decide_portrait_start(true, _) ==
Some(Demo)`), so keys stay `Loading`, blank boxes render, and
no network call is made. No demo-specific guard, no fixture
edit, no `src/demo/data.rs` change.

**Logs: no new line.** The render path stays log-free per the
`src/ui/portraits.rs:12-17` convention (up to 100 picker rows
per frame). The whole log surface of this slice is the
shipped `[PORTRAIT]` transitions — request, drain, landing,
upload, prune, each kind+id only — plus the existing
`[PLANS]` action lines and `search_skills`' `query_len` debug
line, all unchanged. No log may gain a picker search string, a
skill name, a plan name, or an id list.

## 5. Builder split (B only) and integrator list

**There is no builder A in this slice.** In #596, builder A
owned the guard and installer (`src/app/state.rs`); section 3
verifies that work already authorizes every picker row and
must not be touched, so the A slot is empty and inventing A
work would be scope creep. The commit sequence is: this
design commit, one builder B commit, one integrator commit.

- **Builder B — picker surface** (owns only
  `src/ui/skills.rs`; B's tests land in the same commit as
  B's code, section 6):
  - `SKILL_PICKER_RENDER_MAX = 100` with a doc comment in the
    `SKILLS_CATALOGUE_RENDER_MAX` shape (19–24), naming the
    picker-local independent budget.
  - The `take(SKILL_PICKER_RENDER_MAX)` cap and the single
    "Showing …" disclosure in `show_skill_picker` (section
    2), the single in-cap ensure and 20-point horizontal first
    line (section 4).
  - The three `cache` parameters and their three call sites
    (section 4). Nothing else in the file moves: catalogue
    code, plan list and detail entries, editor, confirmations,
    and queue rows are byte-identical outside those signature
    lines.
- **Integrator** (after B): full four gates; verify by diff
  that B touched only `src/ui/skills.rs` (a one-line
  `git diff --stat` check — any other file in B's commit is a
  design violation, since the untouched guard is section 3's
  whole claim); confirm the shipped guard, prune, landing,
  and catalogue tests pass unmodified (named in section 6);
  journal entries in `docs/engineering-journal/` (`DECISIONS.md`
  for the picker-local cap and the already-authorized reading,
  `LEARNINGS.md` if the build surfaces a non-obvious
  mechanism); no merge or push.

Explicitly untouched by both: `src/app/state.rs`,
`src/app/shell.rs`, `src/ui/portraits.rs`, `src/portraits.rs`,
`src/config.rs`, `src/names/sde.rs`, `src/esi/`,
`src/demo/data.rs`, `assets/demo/`, `assets/sde/`,
`src/skills/`, and every other view. Every commit passes the
four gates; the clippy gate includes `--all-targets` (a prior
slice shipped test-code lints by running clippy without it).

## 6. Test plan (all expectations literal)

All new tests are builder B's, in `src/ui/skills.rs`, in the
same commit as the code. Test names are locked; every expected
count and id below was scripted from the bundled extract this
session (section 1) and is a hand literal in the test, never
recomputed by calling the code under test.

**Fixture (locked shape, mirroring the shipped catalogue
fixture `ready_catalogue_state` at 1457–1470).**
`Sde::load_bundled()`; `AppState::new(false)` with one
character row (id 1, "Test Pilot") set active;
`install_skill_catalogue_type_ids(&sde)`;
`skills = LoadState::Ready(SkillsData::default())` unless a
scenario says otherwise (`SkillsData` fields are public,
`src/app/state.rs:325-328`, so scenarios set `queue` and
trained `skills.skills` — entries are
`crate::esi::models::Skill { skill_id, trained_skill_level,
..Default::default() }`, `src/esi/models.rs:33-43` — directly);
`skill_plans = LoadState::Ready(vec![plan])` with one
`SkillPlan { plan_id: 7, character_id: 1, name: "PvP",
description: "", created_at: "2026-11-15T00:00:00Z",
updated_at: "2026-11-15T00:00:00Z", entries: … }` (the
verbatim plan-literal precedent at 1415–1426);
`skill_plans_owner = Some(1)`; `selected_skill_plan_id =
Some(7)`; `skill_plan_picker_open = true`;
`skill_plan_picker_search` per scenario; and
**`skill_search` left at its default `""` in every scenario** —
the catalogue-isolation rule: on a fresh `egui::Context` the
catalogue groups all start collapsed at an empty search, so
the catalogue queues exactly 0 (pinned by the shipped
catalogue test) and every queued key in a scenario is
provably the picker's. A fresh `egui::Context` and fresh
fixture state per scenario, except where a scenario explicitly
runs a second frame on the same context; renders run through
`show` headlessly exactly as the shipped catalogue test does
(1480–1486).

- `skill_picker_render_max_is_100`:
  `SKILL_PICKER_RENDER_MAX == 100` (the catalogue/assets
  precedent, 1449–1452).
- `skill_picker_queues_icons_for_rendered_rows_only` — cases in
  order:
  1. **Picker closed queues nothing.** Fixture with
     `skill_plan_picker_open = false`, picker search `"e"`: one
     frame ⇒ `portrait_requests` empty, cache empty. (The
     detail still renders; only the picker is gated.)
  2. **Exact small set; three exclusion pins in one frame.**
     Picker search `"turret"` (12 results); plan entries
     `[{3300, target 5}, {3301, target 3}]`; queue
     `[item(0, 3300)]` using the existing test helper
     (1069–1076); trained list empty. One frame ⇒ exactly 12
     queued keys, all `(Type, id)`, and the sorted queued ids
     equal the hand literal
     `[3301, 3302, 3303, 3304, 3305, 3306, 3307, 3308, 3309,
     20327, 21666, 21667]`. This one assertion pins: 3300
     ("Gunnery") absent although a training-queue row, a
     plan-entry row, and a "Requires:" prerequisite line all
     name it in the same frame (queue rows, entry rows, and
     prerequisite lines ensure nothing); 3301 present although
     its picker row is the already-in-this-plan row with no
     buttons (in-plan rows still ensure); cache empty
     (blank-box path); `skill_plan_action` still `None` and
     `skill_plan_picker_open` still `true` (a render frame
     stamps nothing and closes nothing). A second frame on the
     same context ⇒ still exactly 12 (every key has left
     `NotRequested`).
  3. **Trained-to-5 row still ensures.** Picker search
     `"gunnery"`; trained list
     `[Skill { skill_id: 3300, trained_skill_level: 5, .. }]`;
     entries empty. One frame ⇒ queued keys are exactly
     `[(ImageKind::Type, 3300)]` — the
     "already trained to level 5" row, which draws no buttons,
     still ensures its icon.
  4. **Empty search caps at 100; boundaries literal.** Picker
     search `""`, entries empty. One frame ⇒ exactly 100
     queued keys, 100 distinct after sort+dedup, including
     `(Type, 60381)` (row 1, "Abyssal Ore Processing") and
     `(Type, 21666)` (row 100, "Capital Hybrid Turret"),
     excluding `(Type, 28585)` (row 101, "Capital Industrial
     Reconfiguration") and `(Type, 23124)` (row 495); cache
     empty. Second frame ⇒ still 100. Then picker search
     `"Capital Industrial Reconfiguration"` (unique match) ⇒
     exactly 101 queued and `(Type, 28585)` present —
     filter-before-cap reveals the beyond-cap row.
  5. **Boundary counts.** Picker search `"ro"` (exactly 100
     results) ⇒ exactly 100 queued, including `(Type, 55033)`
     ("Vorton Projector Operation", its row 100) — at exactly
     the cap nothing is suppressed. Fresh fixture, picker
     search `"pe"` (exactly 101 results) ⇒ exactly 100 queued,
     including `(Type, 41409)` ("XL Torpedo Specialization",
     row 100), excluding `(Type, 21668)` ("XL Torpedoes",
     row 101); then picker search `"XL Torpedoes"` ⇒ one
     additional key, `(Type, 21668)`.
  6. **Skills not loaded still queues (the section 3
     divergence, pinned).** Fixture with
     `skills = LoadState::Empty`, picker search `"gunnery"`,
     entries empty ⇒ exactly `[(ImageKind::Type, 3300)]`
     queued. The catalogue renders nothing in this state; the
     plans section and picker do. The test name and a comment
     must say this is the locked design, not an oversight.
  7. **No active character queues nothing.** Bare
     `AppState::new(false)` with the guard installed (no
     characters): `show` returns at the no-character panel
     after prune ⇒ queue empty, cache empty.
  8. **Nothing installed queues nothing.** Full fixture but
     `install_skill_catalogue_type_ids` never called, picker
     search `""` ⇒ queue empty — the picker renders its window
     of blank boxes but the unchanged guard refuses every key,
     proving the picker has no authorization path of its own.
  9. **A `Failed` picker icon never re-queues.** Fixture,
     picker search `""`, `(Type, 60381)` seeded `Failed` ⇒
     exactly 99 queued, `(Type, 60381)` absent, its state still
     `Failed`, cache empty (the catalogue test's 99/100 shape
     at 1559–1582).
- `skill_picker_demo_queues_types_but_never_ready`, mirroring
  `skills_demo_queues_catalogue_types_but_never_ready`
  (1585–1618): `AppState::new(true)`, `seed_demo_state`, guard
  installed from the bundled SDE, demo `Ready` skills asserted;
  then — `seed_demo_state` seeds no skill plans, so the
  fixture sets the public plan fields directly against the
  demo active character (`state.active_character_id` read
  after seeding): `skill_plans` `Ready` with one empty-entries
  plan owned by that character, `skill_plans_owner` and
  `selected_skill_plan_id` matching, picker open, picker
  search `""`, catalogue `skill_search` left `""` (the
  isolation rule above). One headless `show` frame ⇒ exactly
  100 queued keys, 100 distinct, including `(Type, 60381)`,
  cache empty, and no queued key `Ready`;
  `decide_portrait_start(true, _) == Some(Demo)` is already
  pinned by the shipped decision-table test, so no spawn can
  follow and demo makes zero network calls. No demo fixture
  file is edited.

**Picker-behaviour-unchanged pins.** No widget-text or
click-simulation harness is invented — the shipped caps meet
the same standard (catalogue design section 7). Byte-identical
behaviour apart from the icon cell and the cap is pinned by:
the shipped `plan_wording_matches_design_strings` literals for
both `picker_row_label` forms (1269–1277) passing unmodified;
`prerequisite_line_wording`,
`unmet_warning_line_have_and_untrained`,
`unmet_warning_line_unknown_never_raw_id`,
`prereq_disclosure_verbatim`, and
`plan_warning_text_end_to_end` passing unmodified (the
warning and prerequisite text paths the picker renders);
cases 2, 3, and 6 above, which exercise the in-plan,
trained-5, and not-loaded row states through the real render
path and assert no action is stamped and the picker stays
open; and code review of B's diff confirming lines 997–1057
outside the `take`, the ensure, the horizontal, and the
disclosure are unchanged (button enable rule, `ReplaceEntries`
stamping, and the one-slot guard are untouched text). The
"Showing …" disclosure's draw conditions are pinned by the
queue counts in cases 4 and 5 (100-of-100 queues all 100 with
nothing suppressed; 101 queues exactly its first 100) plus
review of the `results.len() > SKILL_PICKER_RENDER_MAX`
guard; its wording is locked in section 2.

**Shipped tests the integrator confirms pass unmodified**
(none is edited by this slice): the catalogue queue and demo
tests (`skills_show_queues_icons_for_rendered_rows_only`,
`skills_demo_queues_catalogue_types_but_never_ready`,
`skills_catalogue_render_max_is_100`), the guard tests
(`skill_catalogue_membership_authorizes_only_bundled_skill_types`,
`skill_catalogue_knowledge_survives_character_switch`,
`removing_character_retains_skill_catalogue_icon`,
`switching_character_revokes_fitting_type_knowledge`,
`market_selection_authorizes_only_the_selected_type`,
`asset_holdings_authorize_only_held_types`), the prune tests
(`prune_keeps_skill_catalogue_type_icon_across_switch`,
`prune_keeps_type_icon_across_selection_change`,
`prune_keeps_held_asset_type_icon_within_one_load`), and the
landing tests (`skill_type_icon_landing_survives_character_switch`,
`asset_type_icon_landing_drops_after_switch`,
`market_type_icon_landing_drops_after_deselect`,
`assets_show_queues_icons_for_rendered_rows_only`).

## 7. Exclusions (follow-ups, each needs its own design)

- **Training-queue row icons** (`src/ui/skills.rs:388-421`).
  Queue rows name ESI-loaded skill ids — a loaded-state
  surface whose ids are not necessarily bundled catalogue
  types — so they need their own guard reading (the static arm
  would silently refuse a queue id outside the 495 and paint a
  permanent blank box) and their own row budget. This slice
  adds no ensure there; case 2 of section 6 pins that a queue
  row queues nothing.
- **Plan-entry row icons** (`src/ui/skills.rs:758-766`, the
  `entry_row_text` list). Entry counts are user-grown and
  uncapped today, and an entry's `skill_id` comes from local
  plan storage, not from iterating the bundled set — a
  different provenance reading, a different budget, its own
  design. This slice adds no ensure there; case 2 pins that
  an entry row queues nothing.
- **Market order-row icons, and market candidate and
  quick-pick row icons.** Named in this slice only to exclude
  them: the Market view is untouched, and each of those row
  sets needs its own guard source and volume bound, never a
  widening of the one-id market arm or of this picker cap.
- **Per-prerequisite icons** inside "Requires:" and warning
  lines (picker, catalogue, entries): one line names several
  skills in one string; inventing per-prerequisite icon cells
  is a different surface.
- Force-opening catalogue groups on query change, any change
  to `SKILLS_CATALOGUE_RENDER_MAX` or catalogue behaviour, a
  raise of `SKILL_PICKER_RENDER_MAX`, picker sorting changes
  (`search_skills` order is shipped and untouched),
  `show_rows` virtualization (section 2), a probe or allowlist
  of which of the 495 skills have icons, a retry affordance
  for a `Failed` icon, any eviction policy for the retained
  495-texture worst case, and generalizing the catalogue guard
  arm to any other catalogue (the 25,818-id fitting-types
  catalogue and the name-resolver cache remain barred on the
  type-icons reasons, exactly as #596 left them).

## 8. Revisit conditions

- Users routinely open the picker and cannot find or add a
  skill because it sits past row 100 of a broad search, or
  report the disclosure unclear: raising
  `SKILL_PICKER_RENDER_MAX` or virtualizing then earns its
  own design, with the fetch bound re-derived (bound fetches
  per frame **and** per session, not only widgets per frame).
- Combined catalogue-plus-picker frames prove measurably heavy
  on target hardware at 200 ensures: the independent-budget
  choice (section 2) must be re-derived, without ever letting
  catalogue spend suppress picker level buttons.
- A probe of the bundled 495 shows icon-less skills are common
  rather than rare: the inherited accepted-blank-box stance
  (section 1) stops being honest on both skill surfaces, and
  the guard arm needs an allowlist or removal.
- The bundled skill extract stops being a closed skill-only
  set, `search_skills` stops iterating exactly the installed
  `sde.types`, or picker rows gain any path by which user text
  resolves to an id: section 3's "already authorized by
  construction" claim breaks and the guard verdict must be
  re-derived **before** such a change ships.
- Plan entries gain a hard cap, or the picker gains collapsing
  or grouping: the entry-row exclusion and the numeric-cap
  choice should both be re-read against the new shape.
- The training queue, plan entries, market order rows, or any
  new surface wants type icons: its own design, per section
  7. This picker ensure existing is explicitly not
  authorization to add ensures elsewhere, exactly as #596's
  catalogue ensure was not authorization for this picker.
