# Peak recharge rates — design

Status: locked for the `feat/rust-peak-recharge-rates` slice. Base:
`develop` at `0813beb` (merge of #581). Inputs were shipped by #578
(hit points and capacitor capacity) and #581 (recharge durations in
seconds); this slice adds no catalogue data.

## 1. Goal and value ranking

Show two derived base rates in the existing "Ship (base values)" block:
the peak shield recharge rate in HP/s and the peak capacitor recharge
rate in GJ/s, computed from the bare hull's base capacity and base full
recharge duration only.

Ranking, in order: **never a peak rate presented without clear
base/peak labeling** (a peak is the maximum of a non-linear curve, not
an average or sustained rate, and both inputs are bare-hull values) >
**correctness** (every factor, guard, and unit traced to an inspected
body; nothing recalled) > **reuse** (the existing `ShipBaseStats`, the
`ship_stat_line` seam, the shared formatter, and the sibling pure-module
shape).

## 2. Formulas and grounding (inspected bodies only)

### 2.1 Shield — production body

Flutter at `ed698d3`, `lib/features/fitting/domain/dogma_engine.dart`
lines 891–894 (read via `git show`):

```dart
final shieldRecharge = attr(DogmaAttributes.shieldRechargeTime);
final peakShieldRecharge = shieldRecharge > 0
    ? 2.5 * shieldHp / (shieldRecharge / 1000)
    : 0.0;
```

with `shieldHp = attr(DogmaAttributes.shieldCapacity)` (line 852). The
Rust port at base values is therefore, with `T` already in seconds
(#581 converted catalogue milliseconds at `ship_stats.rs:84`):

```text
shield peak (HP/s) = 2.5 * shield_capacity / shield_recharge_secs
```

Flutter feeds post-modifier `attr()` values into this line; the Rust
port deliberately substitutes the #578/#581 base values instead (the
no-modifiers lock, section 9). Bare-oracle equivalence: Flutter test
E2.8 (`dogma_engine_test.dart:1485–1492`) uses an empty fitting with no
skills, so base and adjusted coincide there: shield 450, recharge
625000 ms, expected `closeTo(1.8, 1e-6)`.

### 2.2 Capacitor — simulator closed form plus explicit test statements

There is **no** capacitor peak-rate constant in any Flutter production
body: `dogma_engine.dart:914–933` is stability-only, and
`git grep "2.5"` over `lib/` at `ed698d3` hits only the shield line
above. The capacitor peak is therefore **not** grounded by analogy to
shield. It is grounded, independently, by the capacitor simulator's own
bodies, read in full at `ed698d3`:

- `cap_simulator.dart:73–75` (doc) and `:272–275` (`_recharge`): the
  closed form `cap = ((1 + (sqrt(cap/C) − 1) * exp(−dt/tau))²) * C`.
- `cap_simulator.dart:116`: `tau = rechargeMs / 5.0`.
- Differentiating that closed form: writing `y = sqrt(cap/C)`, the
  instantaneous rate is `(2C/tau) * y * (1 − y)`, maximized at
  `y = 1/2`, giving peak rate `C / (2·tau) = 0.5 * C / tau`. With
  `tau = T/5` for full recharge duration `T`, that is `2.5 * C / T`.
- Two explicit statements in `cap_simulator_test.dart` name this peak
  for the same fixture (capacity 1000 GJ, recharge 60000 ms): lines
  18–19, "a peak recharge of 2.5 * 1000 / 60 = 41.7 GJ/s", and line 75,
  "the peak recharge (0.5 * 1000 / 12s = 41.7 GJ/s)" — the `T` and
  `tau` parametrizations agreeing.

Locked capacitor formula at base values:

```text
capacitor peak (GJ/s) = 2.5 * capacitor_capacity / capacitor_recharge_secs
```

The numeric factor coincides with shield's, but the grounding routes
are different and each is recorded at its own constant (section 3) so
neither silently borrows the other's authority.

**Peak charge level:** no inspected body states in words at what
fraction of capacity either peak occurs, and shield has no curve body
at all. All user-facing wording therefore says "peak" with **no
percentage**. (The derivation above is used only for the rate factor,
which the two test statements corroborate explicitly; it is not used
to print a charge level.)

### 2.3 Guards

Flutter's shield guard is `shieldRecharge > 0`, else `0.0`, with no
capacity guard (capacity 0 yields 0.0 arithmetically) and missing
attributes defaulting to 0 (`attr` at `dogma_engine.dart:274`; E2.9
pins missing recharge → peak 0). Rust separates absent from zero
(#578: `usable` at `ship_stats.rs:55–57` keeps a present `0.0` as
`Some(0.0)`; absent/unusable is `None`, and the renderer omits `None`
lines rather than rendering a zero). Locked per-system outcome:

| capacity | recharge secs | peak |
|---|---|---|
| `Some(c)`, finite, `c ≥ 0` | `Some(t)`, finite, `t > 0` | `Some(2.5·c/t)` if finite, else `None` |
| `Some(0.0)` | `Some(t)`, finite, `t > 0` | `Some(0.0)` — honest zero, renders |
| any | `Some(0.0)` | `None` — no division; line omitted |
| any | `None` | `None` |
| `None` | any | `None` |

Recharge `Some(0.0)` maps to `None`, **not** to a rendered `0.0` rate:
Flutter's `0.0` there is a guard sentinel that also covers missing
data, and the #578 honesty rule forbids rendering a zero for something
that is not a known zero rate. Inputs arriving through
`ShipBaseStats` are already `usable`-filtered, but the pure function
re-checks finiteness/sign on both inputs and on the result anyway (the
`ship_ehp.rs:100–111` precedent), so direct construction in tests
cannot smuggle a NaN, infinity, or negative into a rendered rate.

## 3. Pure API

New sibling module `src/fitting/ship_peak_recharge.rs`, mirroring the
`ship_ehp.rs` pure-module shape (no egui, no state, no network, no
database, logs nothing — it runs at render cadence and the catalogue
load already logs counts once; no per-frame `[FITTING]` logging).
`ShipBaseStats` itself is **not** extended: it stores catalogue
values, and derived values live in their own module like EHP does.

```rust
pub struct ShipBasePeakRecharge {
    pub shield_hp_per_sec: Option<f64>,
    pub capacitor_gj_per_sec: Option<f64>,
}

pub fn ship_base_peak_recharge(stats: &ShipBaseStats) -> ShipBasePeakRecharge
```

Decisions locked:

- **Inputs come from `ShipBaseStats`, never a catalogue refetch.** All
  four inputs already ship on that struct (`shield_capacity`,
  `capacitor_capacity`, `shield_recharge_secs`,
  `capacitor_recharge_secs`). No `CharacterFitting`, no
  `lookup_by_id`, no category check in this module.
- **No `Outcome` enum.** The sibling `Available`/`Unavailable` enums
  exist because those modules do their own catalogue lookup and must
  report missing-ship failure. Peak recharge consumes an
  already-`Available` `ShipBaseStats`; its only failure mode is the
  per-system `None` of section 2.3.
- **Two named factor constants**, `SHIELD_PEAK_FACTOR: f64 = 2.5` and
  `CAPACITOR_PEAK_FACTOR: f64 = 2.5`, each carrying its section 2
  grounding in its doc comment, feeding one private
  `peak_rate(capacity, recharge_secs, factor)` helper that implements
  the section 2.3 guard table. Sharing the arithmetic is reuse;
  keeping the constants separate keeps the groundings separate.
- Re-exported from `src/fitting/mod.rs` like its siblings:
  `pub use ship_peak_recharge::{ship_base_peak_recharge, ShipBasePeakRecharge};`
  plus `pub mod ship_peak_recharge;` in alphabetical position.
- The module doc cites this design and states the no-modifiers lock
  and the logs-nothing rule, in the sibling modules' words.

## 4. Availability

- Per-system and per-line: each peak needs **both** its capacity and
  its recharge duration usable (section 2.3). Shield peak availability
  never affects capacitor peak availability or vice versa.
- Peaks have **no block of their own** and no block-level unavailable
  state. They render only inside the existing ship-stats block's
  `Available` branch; when ship stats are `Unavailable`, the existing
  no-ship-data sentence already covers the whole block.
- Independent of resources, resistances, and EHP outcomes by
  construction: the peak function reads only `ShipBaseStats` fields,
  and ship-stats availability is already independent of those blocks
  (`ship_stats.rs:298–354`). A hull whose only usable stat is a
  recharge duration shows that duration line and no peak line; a hull
  with capacity but no duration shows the capacity line and no peak
  line.

## 5. UI

Placement: **two new lines appended at the end of the existing block**,
after `Capacitor recharge`, inside `ship_base_stat_lines`
(`src/ui/fittings.rs:1374–1387`) via the unchanged `ship_stat_line`
seam. Rejected: a parenthetical on the duration lines (needs a new
two-value formatter and couples two independently-available values
into one line with four presence combinations) and a new sibling block
with its own heading (a second heading/disclosure for two lines
derived from values already in this block). Appending also matches
the #581 precedent of growing this block at its end.

Verbatim templates (label, value via
`widgets::format_fitting_amount(v, unit)` at `src/ui/widgets.rs:69`,
unit) — "peak" in every label, no charge-level percentage anywhere,
per sections 1 and 2.2:

```text
Shield peak recharge: {amount} HP/s
Capacitor peak recharge: {amount} GJ/s
```

i.e. `ship_stat_line("Shield peak recharge", peaks.shield_hp_per_sec,
"HP/s")` and `ship_stat_line("Capacitor peak recharge",
peaks.capacitor_gj_per_sec, "GJ/s")` as the last two entries of the
existing array, where `peaks = ship_base_peak_recharge(stats)`.
`None` omits the line exactly as today; a `Some(0.0)` renders
`0.0 HP/s` / `0.0 GJ/s`. No formatter change: `HP/s` and `GJ/s` are
plain unit strings on the same code path as `HP`, `GJ`, `s`, and
`m/s`.

Disclosure: the peak lines **ride the existing disclosure unchanged**
(`FITTING_SHIP_BASE_STATS_DISCLOSURE`, `src/ui/fittings.rs:1173`):
"Base ship values from Mimir's bundled item data. Fitted modules,
rigs, subsystems, skills, implants, and ship bonuses are not applied,
so these numbers can differ from EVE." The peaks are arithmetic on
those same base values, the heading already reads "Ship (base
values)", and each label says "peak" — no constant is added or
reworded. (Flutter precedent for the rates themselves: the fitting
stats panel never displayed any peak — `stats_panel.dart:54–71` shows
capacitor Capacity/Recharge/Stable only — so there is no Flutter
label to inherit; the wording above is this slice's own.)

`render_ship_base_stats`, the resources block, the resistances block,
and the EHP block are untouched. The renderer gains no logging.

## 6. Demo story and float exactness

Hand-derived from the pinned #578/#581 inputs (Rifter 587: shield
450.0 HP, capacitor 250.0 GJ, shield recharge 625.0 s, capacitor
recharge 125.0 s; Punisher 597: 350.0, 400.0, 625.0 s, 160.0 s —
`ship_stats.rs:137–139, 167–179`), divisions shown:

- Rifter shield peak: `2.5 × 450.0 / 625.0 = 1125.0 / 625.0 = 1.8 HP/s`
  (equals the Flutter E2.8 oracle).
- Rifter capacitor peak: `2.5 × 250.0 / 125.0 = 625.0 / 125.0 = 5.0 GJ/s`.
- Punisher shield peak: `2.5 × 350.0 / 625.0 = 875.0 / 625.0 = 1.4 HP/s`.
- Punisher capacitor peak: `2.5 × 400.0 / 160.0 = 1000.0 / 160.0 = 6.25 GJ/s`.

Rendered lines appended to the current seven (Demo Brawler and
Mission Runner are Rifter 587; Demo Runner is Punisher 597 — the
existing demo test at `src/ui/fittings.rs:3718`):

```text
Shield peak recharge: 1.8 HP/s
Capacitor peak recharge: 5.0 GJ/s
```

```text
Shield peak recharge: 1.4 HP/s
Capacitor peak recharge: 6.3 GJ/s
```

Note the display rounding: 6.25 renders as `6.3` because
`format_fitting_amount` rounds the tenth with `f64::round`
(half away from zero) at `src/ui/widgets.rs:88`; the stored rate stays
6.25 exactly. This is display-only, like the existing
187.5-exact / 218.75→218.8 pins.

**Float exactness, locked:** 1.8 and 1.4 are not exactly representable
in `f64`, so `assert_eq!` against those literals would fail on correct
arithmetic. All pure-rate assertions use one absolute tolerance of
`1e-9` (the resistances precedent; comfortably above the ~1e-16
representation error here, far below any real regression) — uniformly,
including for 5.0 and 6.25, which happen to be exact: no test may
special-case them into `assert_eq!`, so the tolerance discipline
cannot silently rot. `assert_eq!` is reserved for `None` outcomes,
the `Some(0.0)` zero-capacity outcome (2.5 × 0 / t is exactly 0), and
rendered line strings.

Capacitor comment fixture as a second pure oracle: capacity 1000.0 GJ,
recharge 60.0 s → `2.5 × 1000.0 / 60.0 = 2500.0 / 60.0 = 41.666… GJ/s`,
asserted within `1e-9` of `2500.0 / 60.0` (the comments' rounded
41.7 is never asserted as a literal).

## 7. Test plan

**Builder A — pure module tests** (`ship_peak_recharge.rs`), built by
constructing `ShipBaseStats` directly (its fields are public) plus one
real-catalogue pass through `ship_base_stats`:

- Oracles at tolerance `1e-9`: Rifter 1.8 HP/s / 5.0 GJ/s and Punisher
  1.4 HP/s / 6.25 GJ/s from the bundled catalogue (the Rifter shield
  value is the Flutter E2.8 bare oracle — a bare Flutter oracle exists
  for shield and this is it); the capacitor comment fixture
  1000.0/60.0 s → `2500.0/60.0` GJ/s by direct construction. No bare
  Flutter *assertion* exists for a capacitor peak number, so the
  comment fixture is asserted against the section 2.2 formula, never
  against the rounded 41.7.
- Guard matrix, one case per section 2.3 row, per system: capacity
  `None`; recharge `None`; recharge `Some(0.0)` → `None`; capacity
  `Some(0.0)` with positive recharge → `Some(0.0)` by `assert_eq!`;
  negative, NaN, and infinite capacity or recharge (direct
  construction) → `None`; overflow to a non-finite rate (huge capacity,
  tiny positive recharge) → `None`.
- Per-system independence: shield inputs complete with capacitor
  inputs absent (and the mirror) yields exactly one `Some`.
- All other `ShipBaseStats` fields (armor, hull, max velocity) varied
  or absent: peaks unchanged.

**Builder B — renderer tests** (`src/ui/fittings.rs`):

- `ship_base_stat_lines_match_the_locked_templates`: Rifter and
  Punisher expectations grow from seven lines to the nine of
  section 6, in order — **the one deliberate expectation change in
  this slice**, recorded here like #581 recorded its two-line growth.
- `demo_fixture_ship_stats_match_the_locked_demo_story`: both demo
  blocks grow by the same two lines; Demo Brawler and Mission Runner
  stay identical.
- Absence matrix at the line level, via fixture catalogues in the
  existing style: capacity present without its recharge attribute →
  capacity line, no peak line; recharge present without capacity →
  duration line, no peak line; present-zero capacity with a positive
  recharge → the `0.0 HP/s` / `0.0 GJ/s` line renders; recharge
  `0.0` → duration line renders `0.0 s` (unchanged #581 behavior) and
  no peak line appears.
- Formatter behaviour is pinned through the lines themselves (1.8,
  5.0, 1.4, and the 6.25→`6.3` rounding); `format_fitting_amount`
  gains no new tests and no changes.
- Regression: `ship_base_stats_unavailable_and_disclosure_wording`
  passes **unmodified** (heading, sentences, disclosure byte-identical),
  and the resources, resistances, and EHP line tests pass unmodified —
  their rendered blocks are byte-identical after this slice.

**Gates (every commit):** `cargo test`, `cargo clippy`, and
`cargo fmt --check` per the repo's configured checks; the pure module
and renderer add no logging, so no log assertions exist to write.

## 8. Integrator list

- **README** (Fittings bullet): the recharge figures now exist as
  durations *and* peak rates. In the sentence "…also show the ship's
  base shield, armor, hull, capacitor capacity, max speed, and
  shield/capacitor recharge times from Mimir's bundled item data…",
  extend the list to "…, shield/capacitor recharge times, and peak
  shield/capacitor recharge rates from Mimir's bundled item data…".
  The closing sentence "There are still no DPS numbers, no
  capacitor-stability figures, no sustained-tank figures, and no
  adjusted (fitted) fitting totals of any kind." stays **verbatim**:
  a peak rate is neither a stability figure nor a sustained-tank
  figure.
- **Engineering journal** (`docs/engineering-journal/LEARNINGS.md`, in
  the integrator's commit): the capacitor factor's grounding route —
  derivative of the simulator's inspected closed form plus its two
  explicit test statements, deliberately not the shield constant by
  analogy — and the decision to print no peak charge-level percentage
  because no body states one. Evidence cites this design and the
  `ed698d3` bodies above.
- Nothing else: no catalogue regeneration, no `fitting_types.rs`, no
  `ship_stats.rs` change, no ESI/scope/storage change anywhere in the
  slice. If discovery of any missing input contradicts section 3
  during the build, the slice stops rather than growing scope.

## 9. Exclusions

No recharge curve over time and no charge-level percentages; no
capacitor stability simulation, stable percentage, or time-to-empty
(the whole `CapSimulator` behaviour stays unported); no module
capacitor consumption or injector modelling; no sustained or burst
tank figures; no modifiers of any kind — fitted modules, rigs,
subsystems, skills (including Flutter's 3416/3418/3419
shield/capacitor skill rows), implants, and ship bonuses are not
applied to the rates **or to their capacity and recharge-time
inputs**, which remain the #578/#581 base values; no average recharge
rate (capacity ÷ duration is a different, unlabelled number and is
not shown); no new ESI scopes, storage, or catalogue fields.

## 10. Ownership and commit split

- **Design (this commit):** `docs/peak-recharge-rates-design.md` only.
- **Builder A — pure peak calculation:** new
  `src/fitting/ship_peak_recharge.rs` plus the `src/fitting/mod.rs`
  module/re-export lines, with the section 7 pure tests. Commit:
  `feat(fitting): add pure base peak recharge rates`.
- **Builder B — render and demo pins:** `src/ui/fittings.rs` only
  (the two appended lines in `ship_base_stat_lines` and the section 7
  renderer tests). Commit:
  `feat(fittings): show base peak shield and capacitor recharge rates`.
- **Integrator:** README and journal per section 8, full gates, demo
  check. Commit: `docs(fittings): document peak recharge rates`.

Builders touch disjoint files; Builder B depends on Builder A's
public API exactly as locked in section 3 and changes nothing in
`src/fitting/`. Small atomic commits, `type(scope): description`, no
attribution lines. Nobody pushes or merges; the parent does that.
