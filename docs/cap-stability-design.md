# Base capacitor stability — design

Status: locked for the `feat/rust-cap-stability` slice. Base:
`develop` at `ce9b0e7`, clean, 824 tests (stated; not re-run in the
design commit). Slice branch: `feat/rust-cap-stability`. Discovery:
two read-only reports — Flutter capacitor simulator at `ed698d3`
(full-body reads of `cap_simulator.dart`, `dogma_attributes.dart`,
`dogma_engine.dart` capacitor blocks, `cap_simulator_test.dart`,
`stats_panel.dart`) and Rust data seams (sources, committed SDE
caches, pinned zip, shipped catalogue, demo fittings, all scripted).
Every formula, attribute id, and number below traces to an inspected
body named beside it. No EVE formula here is recalled.

**Grounded verdict up front:** the simulator core ports honestly at
base values; its Flutter *inputs* do not. This slice therefore
replicates the event-driven closed-form simulator exactly (section
2) over **base inputs only**, with **no capacitor boosters anywhere**
(section 9 records why boosters ship nothing). Where a module's base
need or cycle cannot be proven it is excluded with a disclosed
count, never treated as free.

## 1. Goal and value ranking

Show, for the selected saved fitting and for the imported fitting in
the Fittings view, a base capacitor-stability statement: whether
the fitted modules that can be proven to use capacitor, cycling
continuously at their base rates, deplete the bare hull's base
capacitor, and if not, at what charge level the capacitor settles.

Value ranking (locked, in order):

1. **Never a stability verdict without its assumptions on screen.**
   Base values, all counted modules cycling continuously, no
   boosters, excluded-module count. A bare "Stable 77%" that reads
   like an in-game value while silently ignoring modifiers and
   excluded modules is the failure this slice exists to avoid.
2. **Grounded math only.** The algorithm is Flutter's, quoted in
   section 2; every input is a base catalogue value section 3
   names. Anything ungrounded (boosters, section 9) ships nothing
   rather than an approximation.
3. **Reuse.** Ship inputs and peak recharge ship already (#578,
   #581, peak slice); mirror the `dps.rs` / `resources.rs`
   pure-module shape, the additive generator extension pattern,
   and the `format_fitting_amount` formatter.

## 2. Simulation algorithm (locked — replicate Flutter exactly)

The port implements `CapSimulator.run()` at `ed698d3`
(`lib/features/fitting/domain/cap_simulator.dart`, read in full)
with the injector paths removed (section 9) and base inputs
substituted (section 4). What is replicated, verbatim:

- **Closed-form recharge, event queue — no time-stepping.** Between
  events, charge advances by pyfa's closed form (`_recharge`,
  lines 272–275; doc lines 73–75):

  ```text
  cap = ((1 + (sqrt(cap/C) − 1) × exp(−dt/tau))²) × C,  tau = rechargeMs / 5.0
  ```

  `dt` is the exact gap to the next event (`tNow − tLast`, lines
  195–197). There is no step size to lock; a fixed-step port would
  be a *different* algorithm and must not claim these oracles.
- **Events.** Each drain `(durationMs, capNeed, count)` seeds at
  `t = 0`; identical drains stagger pyfa-style as `duration/count`
  floored (lines 122–124). `period = LCM(all durations)`
  (`_lcm` rounds durations to integers first, lines 278–289).
  Charge starts full at capacity (line 148).
- **Equilibrium (stability) definition.** At an event falling on a
  whole LCM period (`tNow == tWrap`), if `cap >= capWrap` (the
  charge at the previous period boundary) the fitting is stable
  (lines 200–210; `tWrap` advances by `period`, line 213).
  Flutter additionally requires the postponed-injector signature
  to repeat (lines 157–161); with no injectors that term is
  vacuously equal, and the condition reduces to the charge
  comparison alone. A closed-form equilibrium shortcut (for
  example "stable iff average use/s ≤ peak") is **not** locked:
  no inspected body proves it equivalent to this discrete-event
  equilibrium — periodic large spends can dip to empty where an
  average-rate check passes — so the event simulation runs as
  written and section 7's use/s figure is reported only as a
  supporting number, never as the verdict.
- **Stable percent.** Midpoint of the cycle's water marks,
  `((low + high) / (2·capacity)) × 100` (`_stablePercent`, lines
  269–270; `capLowest` post-spend minimum, `capLowestPre`
  pre-event minimum, lines 198–199, 234–243).
- **Depletion.** Post-spend `cap < 0.0` ends the run unstable with
  `secondsToEmpty = tLast/1000.0` (lines 235–241) — the event time
  of the activation that could not be paid, quantized to event
  times, never an interpolated root. The UI wording (section 6)
  must not imply sub-event precision.
- **Horizon.** `maxSeconds = 3600` (line 87); reaching it returns
  stable with the water-mark percent (lines 187–193). The port
  keeps 3600 s unlabelled as a constant with its doc citation.
- **Edge guards (ported, mapped to Rust outcomes in section 5).**
  `capacity ≤ 0 || rechargeMs ≤ 0` returns without simulating
  (lines 97–103); no drains returns stable 100% (lines 108–114).
- **LCM bound.** Flutter's `_lcm` is unbounded and cache durations
  reach 600,000 ms with 180,000 ms reloads, so `period` can be
  astronomical. That is safe to replicate: `period` only gates
  the period-boundary check while the queue advances by event
  times and is capped by the 3600 s horizon. The Rust port uses
  checked integer arithmetic for the LCM; on overflow it keeps
  simulating to the horizon without a period check (outcome then
  comes from depletion or the horizon rule) rather than panicking
  or wrapping.

## 3. Attribute set and catalogue emission (locked)

| Role | Attribute | Source of the number | Catalogue today |
|---|---|---|---|
| Ship capacity | 482 `capacitorCapacity`, unit 114 (GJ) | Pinned zip `dogmaAttributes.jsonl`; Flutter `dogma_attributes.dart:5–6` | Ships (`capacitorCapacity`, 404 category-6 rows) |
| Ship recharge time | 55 `rechargeRate`, unit 101 (ms) | Same | Ships (`rechargeRate`, 404 rows) |
| Module need per activation | 6 `capacitorNeed`, unit 114 (GJ), default 0.0 | Zip `_key` 6; Flutter `dogma_attributes.dart:7` (`capacitorNeed = 6`) | **Absent** (0 keys in 25,818 rows) |
| Module cycle | 73 `duration`, unit 101 (ms), default 0.0 | Zip `_key` 73; Flutter `:8` (`duration = 73`) | **Absent** |
| Weapon cycle fallback | 51 `speed`, unit 101 (ms) | Zip `_key` 51; Flutter `:53` (`rateOfFire = 51`) | Ships (`speed`, 873 rows) |
| Reactivation delay | 1795 `reloadTime`, unit 101 (ms), **SDE default 10000.0** | Zip `_key` 1795; Flutter `:10` (`reactivationDelay = 1795`) | **Absent** |
| Booster gain | 67 `capacitorBonus`, unit 114 (GJ) | Zip `_key` 67; Flutter `:9` | Absent; **never emitted** (section 9) |

Scripted cache facts (committed `scripts/sde/dgmTypeAttributes.csv.bz2`,
612,816 rows, generator-eligible 25,818 types): attribute 6 on
2,116 types (1,858 `> 0`, 258 `== 0.0`); 73 on 1,570 (all `> 0`);
51 on 946; 1795 on 990. Under section 4's rule, **1,838 eligible
types** (1,814 category 7, 24 category 66; cycle from 73 only:
1,368; from 51 only: 470; both: 0). 609 eligible types carry a
present 1795; 1,229 do not.

**Emission (locked).** The generator (`scripts/sde/generate_fitting_types_sde.py`)
emits three new sparse keys — `capacitorNeed` (6), `duration` (73),
`reloadTime` (1795) — for category-7/66 rows carrying a slot effect
(generator `SLOT_EFFECT_IDS = {11,12,13,2663,3772}`, line 106),
appended in locked key order after `falloff`, with the house
fail-loud loader checks (duplicate / unparseable / non-finite /
negative; `dps`-load precedent lines 1350–1381) and oracle counts
(`CAP_EXPECTED_COUNTS`). Scripted size: **+92,165 bytes over the
shipped 3,519,738-byte catalogue → 3,611,903**. Ship keys 482/55
and weapon-cycle key 51 are unchanged; no `ShipBaseStats` change.
`capacitorBonus` (67) is not emitted: its only consumers are
booster injectors, which ship nothing (section 9), and its battery
rows (for example type 522, 67 = 60.0, no 6/73/51) are decoys that
must never be read as drains. The catalogue file is generated;
never hand-edit it.

**Loader.** `src/names/fitting_types.rs` gains three
`#[serde(rename, default)] Option<f64>` fields in the existing
shape, plus `bundled_catalogue_invariants` pins in the `speed`
precedent (finite `≥ 0`, category-7/66 + slot-effect presence
only, spot values from section 7).

**Reload rule (locked).** Present 1795 is added to the cycle
(Flutter `dogma_engine.dart:697–700`: "pyfa adds the
reactivation delay … to the cycle", confirmed by the booster
oracle 15000 + 10000 = 25000 ms). **Absent 1795 adds 0; the SDE
default of 10000.0 is never substituted** — Flutter's
`moduleAttr` returns 0.0 for a missing base row, and substituting
the default would lengthen 1,229 cycles by 10 s and understate
use/s. Omitting a *present* reload overstates turret use/s by
roughly 2× (type 561 Gatling Rail I: 2600 + 5000 ms).

## 4. Module inclusion rules (locked)

Grid: **slot rows only** — saved fittings by ESI flag prefix
(`LoSlot`/`MedSlot`/`HiSlot`/`RigSlot`/`SubSystemSlot`, the
`dps.rs is_slot_flag` shape at `dps.rs:94–100`), imported fittings
by slot section via the `to_character_fitting()` synthesis
(`eft.rs:278–326`), one code path. Scope mirrors Flutter's
`Fitting.allModules` (high+med+low+rigs+subsystems;
`dogma_engine.dart:686` loop; drones, fighters, cargo never
contribute). Rigs/subsystems are in scope for parity but are a
proven no-op today (0 rows with only slot effect 2663/3772 carry
`6 > 0`). One catalogue lookup per row; quantity clamped
`max(0)` (`resources.rs:176` precedent); rows with `type_id ≤ 0`
ignored entirely. No `category_id` bound beyond the slot gate:
the eligible set spans categories 7 and 66, and category-18 EC
drones fall out by having no cycle, not by category.

Per slot row, from base catalogue values only (Flutter's
`moduleAttr` bonus pipeline is **not** ported; at base values
bonuses are absent, so `cycle = cycleAttr + (1795 if present
else 0)`):

| Base data on the row's type | Treatment |
|---|---|
| `capacitorNeed = Some(n)`, `n > 0`, cycle `> 0` (73 if present else 51, plus present 1795) | **Counted drain** `(durationMs = cycleMs, capNeed = n)`, grouped by `"${cycleMs.round()}:${capNeed.toFixed(3)}"` into `(durationMs, capNeed, count)` exactly as `dogma_engine.dart:714–724`; each quantity unit increments `count` |
| `capacitorNeed = Some(0.0)` (258 types — projectile turrets: free to fire) | **Known zero**: contributes 0 GJ/s, *not* excluded — a present zero is data, like the resources slice's explicit `0.0` needs |
| `capacitorNeed = Some(n)`, `n > 0`, but no cycle (neither 73 nor 51) — 20 types (burst projectors, Interdiction Nullifiers, EC drones, …) | **Excluded with count** — a known cost with no rate is never zero-cost |
| `capacitorNeed` absent (1,854 category-7 slot types, e.g. Damage Control II 2048) | **Excluded with count** — absence is not "known free" (Flutter's `hasCapNeed = false` path drops silently; Rust counts, per every base slice since resources) |
| Cycle or need value non-finite or negative (impossible in the shipped catalogue; invariants in section 3 prove it) | Excluded with count (defense in depth) |
| Type absent from the catalogue | Excluded with count (`resources.rs:184–188` precedent, *not* the `dps.rs:217–220` silent skip — the slice rule "never zero-cost" governs) |

`excluded_modules` counts **rows** (not units), mirroring
`resources.rs`. Non-slot rows (drones, fighters, cargo, catch-all
flags) are never counted and never excluded.

**Module state.** Neither Rust shape carries online/offline state
(`FittingItem { flag, quantity, type_id }`, `src/esi/models.rs:721–728`;
`ImportedItem`, `src/fitting/eft.rs:245–266`), so Flutter's
offline-skip (`dogma_engine.dart:687–688`) has no counterpart:
every counted module is assumed cycling continuously, and
section 6's wording says exactly that. Nobody later "fixes" this
by inventing a state.

**NOS, energy neutralizers, remote repairers, capacitor
batteries.** No special cases. Flutter's loop counts any module
with `6 > 0` and a cycle as a drain on its own ship and nothing
else; this slice does the same at base values. Capacitor drained
from or transferred to another ship, incoming NOS gain, and
battery capacity bonuses need target/effect modelling no
inspected body provides at base values — the disclosure names
effects on other ships as unmodelled (section 6). Capacitor
batteries carry no 6 (only the 67 decoy), so they land in the
absent-6 excluded count, which is honest: their in-game benefit
(capacity modifiers) is exactly what a base slice never applies.

**Charges, drones, fighters** never produce drains (0 eligible
types; section 3). Loaded-charge pairing is irrelevant to drains:
a turret's need and cycle live on the module type, so — unlike
turret/launcher DPS — this slice is **symmetric across saved,
DNA, and EFT surfaces**. There is no unloaded/loaded distinction
to disclose.

## 5. Pure API (locked)

New sibling module `src/fitting/ship_cap_stability.rs`, mirroring
`dps.rs` (no egui, no state, no network, logs nothing — render
cadence; the catalogue load already logs counts once). One
entry point over the synthesized `CharacterFitting`, the
`resources.rs:126` shape (drains need no charge pairing, so the
`dps.rs` `(fitting, imported, catalogue)` triple is unnecessary):

```rust
pub enum CapStabilityOutcome {
    Stable { percent: f64 },
    Depletes { seconds: f64 },
    Unavailable,
}

pub struct FittingCapStability {
    pub outcome: CapStabilityOutcome,
    pub total_use_per_sec: Option<f64>, // Σ quantity·capNeed/(cycleMs/1000)
    pub peak_recharge_per_sec: Option<f64>, // shipped 2.5·C/T, via ship_peak_recharge
    pub counted_modules: u64,
    pub excluded_modules: u64,
}

pub fn fitting_cap_stability(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> FittingCapStability
```

Decisions locked:

- **`Unavailable` iff** the ship row is missing, not category 6,
  or its base `capacitorCapacity` / `capacitorRechargeRate` is
  absent, non-finite, or ≤ 0 after `usable()`-style filtering
  (`ship_stats.rs:55–57`). Ship inputs are read through the
  existing `ship_base_stats` (`ship_stats.rs:63–98`) — base
  capacity `capacitor_capacity` (GJ) and `capacitor_recharge_secs`
  (already seconds, `ship_stats.rs:84–85`); the simulator works
  in milliseconds (`rechargeMs = secs × 1000`) to keep Flutter's
  arithmetic shape. Flutter's guard (section 2) returns a fake
  stable/0 there; Rust must not: zero-capacity is not a known
  "stable". `total_use_per_sec` and `peak_recharge_per_sec` are
  `None` when `Unavailable`, whatever the module side computed.
- **No counted drains → `Stable { percent: 100.0 }`** (Flutter
  lines 108–114), with `total_use_per_sec = Some(0.0)`. This holds
  even when `excluded_modules > 0`; the excluded count is what
  keeps the line honest (section 6 renders it verbatim).
- **`total_use_per_sec`** is the exact average
  `Σ quantity·capNeed/(cycleMs/1000)` over counted drains in
  `f64` (phase/staggering cannot change an average). Known-zero
  rows add 0. It is a supporting figure only — never the verdict
  (section 2) — and is `None` if the sum is non-finite.
- **`peak_recharge_per_sec`** is the shipped
  `ship_base_peak_recharge(&stats).capacitor_gj_per_sec`
  (`ship_peak_recharge.rs:78–91`; `2.5·C/T`, independently
  grounded by differentiating section 2's closed form:
  `(2C/tau)·y·(1−y)` peaks at `0.5·C/tau = 2.5·C/T` — see
  `docs/peak-recharge-rates-design.md` section 2.2). It labels
  the comparison; it never decides `Stable`/`Depletes`.
- Re-exported from `src/fitting/mod.rs` alphabetically like its
  siblings. The module doc cites this design, the no-modifiers
  lock, and the logs-nothing rule in the siblings' words.
- The function is total: saturating counts, no panic on hostile
  saved data, LCM overflow handled per section 2.

## 6. UI (locked — new sibling block)

This block depends on fitted modules, so it cannot ride the
"Ship (base values)" block or its disclosure. It mirrors
`render_fitting_dps` (`src/ui/fittings.rs:2064`) /
`render_fitting_resources` (`src/ui/fittings.rs:1337`): new
`render_fitting_cap_stability` in `src/ui/fittings.rs`, called
from the saved detail (fitting only; `src/ui/fittings.rs:2682`
area) and the imported detail via its synthesized
`CharacterFitting` (`src/ui/fittings.rs:2376` area). Heading
verbatim:

```text
Capacitor (base values)
```

Lines, in order — amounts via `widgets::format_fitting_amount`
(`src/ui/widgets.rs:69`) with unit `GJ/s`; percent and seconds
as whole numbers with `f64::round` (Flutter
`stats_panel.dart:54–71` renders `toStringAsFixed(0)`, e.g.
`87%` / `42s`); module names are never shown, only counts, so
no raw id can appear:

```text
Module capacitor use: {amount} GJ/s            [Some(total_use_per_sec) only]
Capacitor peak recharge: {amount} GJ/s          [Some(peak_recharge_per_sec) only;
                                                  same label/route as Ship block]
Stable at {percent}%                             [outcome Stable]
Depletes in about {seconds}s                     [outcome Depletes]
{count} fitted modules are not counted because   [excluded_modules > 0]
their base capacitor use is not in Mimir's
bundled item data.
```

`Capacitor peak recharge` is repeated from the Ship block so
this block reads standalone against `Module capacitor use`;
it is the same shipped value via the same `ship_stat_line`
seam (`src/ui/fittings.rs:1417–1419`), not a second
calculation. "about" on the depletion line is locked wording:
section 2 quantizes the time to event boundaries, so the
figure is the failing activation's time, not a measured
empty-instant.

**Unavailable** (section 5) renders this sentence verbatim
under the heading and nothing else (the Ship block's
no-ship-data precedent):

```text
No capacitor data is available for this ship in Mimir's bundled item data.
```

**Disclosure**, rendered verbatim under every available block
(new constant `FITTING_CAP_STABILITY_DISCLOSURE`; the
continuous-cycling assumption is stated here, not implied):

> Assumes every counted module keeps cycling continuously.
> Base values from Mimir's bundled item data. Fitted modules,
> rigs, subsystems, skills, implants, and ship bonuses are not
> applied to the capacitor, recharge, or module use. Capacitor
> boosters and effects on other ships (such as energy
> neutralizers and remote repairers) are not modelled, so
> these numbers can differ from EVE.

The renderer gains no logging beyond the house `[FITTING]`
count-only precedent of its sibling blocks (module names and
ids are never logged).

## 7. Demo numbers (hand-derived; divisions shown)

Ship inputs already pinned (#578/#581: `ship_stats.rs`):
Rifter 587 — capacity 250.0 GJ, recharge 125.0 s, peak
`2.5 × 250.0 / 125.0 = 5.0 GJ/s`. Punisher 597 — 400.0 GJ,
160.0 s, peak `2.5 × 400.0 / 160.0 = 6.25 GJ/s`. Module cache
values read during discovery: type 2050 (Gistum C-Type Shield
Hardener) `6 = 32.0`, `73 = 12000.0`, no 1795 → cycle 12.0 s →
`32.0 / 12.0 = 2.666… GJ/s` each.

- **Demo Brawler (fitting 1, Rifter):** 2× type 2050 (HiSlot0,
  HiSlot1). Use `2 × (32.0/12.0) = 5.333… GJ/s` vs peak 5.0 —
  average use already exceeds peak, so no equilibrium exists
  and the event simulation must deplete; hand-replication of
  section 2 puts the failing activation at **about 234 s**.
  Excluded counted: Damage Control II 2048 (6 absent) and the
  two non-module slot rows (2049, 1225) per section 4. The
  builder re-derives the depletion second by running the port
  against the section 8 Flutter fixtures first and pins the
  resulting literal with its arithmetic in a comment.
- **Mission Runner (fitting 2, Rifter):** no counted drains →
  `Stable at 100%`, use `0.0 GJ/s`, 2 excluded (2048, 2049).
- **Demo Runner (fitting 10, Punisher):** 1× type 2050 →
  `32.0/12.0 = 2.666… GJ/s` vs peak 6.25; hand-replication
  settles at **about 77%**; builder pins the exact literal the
  same way. Excluded: 2048, 1225.
- **EFT sample oracle** (`resources.rs:296–329` synthesis; cache
  values): 1183 (`6 = 40.0, 73 = 6000.0` → `40.0/6.0 = 6.6667`)
  \+ 438 (`22.0/10.0 = 2.2`) + 448 (`6.0/5.0 = 1.2`) + 3× 2889
  (`6 = 0.0`, known zero → 0.0) → **10.0667 GJ/s** vs Rifter
  peak 5.0 → depletes; hand-replication puts the failing
  activation at about **36 s**.

## 8. Test plan (locked literals; Flutter oracle cross-checks)

**Flutter base-pure oracles.** The `CapSimulator` body is pure
arbitration over `(capacity, rechargeMs, drains, maxSeconds)`,
so `cap_simulator_test.dart` fixtures (capacity 1000 GJ,
recharge 60000 ms, peak `2.5 × 1000 / 60 = 41.666… GJ/s`) port
1:1 as unit tests on the Rust simulator core — this is the one
place Flutter numbers *are* base numbers:

- No drains → stable, `closeTo(100, 0.001)` (test lines 6–15).
- Light drain 10 GJ / 10000 ms → stable, percent in (80, 100]
  (lines 17–29). Hand-replication: ~98.7.
- Overwhelming drain 1000 GJ / 1000 ms → unstable,
  `secondsToEmpty` in (0, 60) (lines 31–41): the second
  activation overspends (capacity starts full at 1000 GJ; the
  `t = 0` spend plus 1 s of closed-form recharge leaves far
  under the 1000 GJ needed at `t = 1.0 s`) → literal `1.0`.
- Stagger equivalence: (20000·… ) — (20 GJ, 10000 ms, count 2) ≡
  (20 GJ, 5000 ms, count 1), percents within 0.001 (lines
  43–57).
- Monotonicity: need 20 < 60 < 120 at 5000 ms, strictly
  decreasing percent (lines 59–72). Hand-replication:
  ~95.1 / ~84.8 / ~67.8.
- Engine-level fixture (1000/60000 ship, one 60 GJ / 5000 ms
  module, `dogma_engine_test.dart:352–396`) → stable in
  (0, 100]. Hand-replication: ~84.8 (the 60-GJ monotonicity
  point above), confirming engine and simulator agree at base
  values where the engine's bonuses are zero.

Builders **pin the exact `f64` literals their faithful port
produces** for the light-drain, monotonicity, and demo cases,
each with the section 7 arithmetic in a comment, at tolerance
`1e-9` (peak-slice precedent; `assert_eq!` only for `Unavailable`,
zero-outcomes, counts, event-quantized `seconds` that are exact
integer seconds like `1.0`, and rendered line strings).

**Builder A — pure module + catalogue tests:**

- The six oracle groups above, plus: depletion quantized to an
  event time (a drain that fails mid-gap reports the event
  second, never an interpolation); 3600 s horizon returns
  stable; LCM-overflow inputs still terminate via horizon or
  depletion.
- Inclusion matrix, one test per section 4 row — eligible
  (73-cycle, 51-cycle, with/without present 1795 — pin the
  15000 + 10000 = 25000 ms shape and the never-substituted
  default by an absent-1795 case), known-zero `6 = 0.0`
  (counts zero, excluded stays 0), `6 > 0` without cycle,
  absent 6, unknown type id (excluded, not silent), non-slot
  rows (neither counted nor excluded), quantity `max(0)`,
  `type_id ≤ 0` ignored, identical drains grouped (the
  `"12000:32.000"` key, count 2 for the demo pair).
- Availability: missing ship; non-category-6 ship; each input
  `None` / `Some(0.0)` / negative → `Unavailable` while counted
  modules exist (availability never depends on module data).
- Bundled-catalogue pins: section 3 counts (1,838 eligible,
  258 known-zero, 20 no-cycle), spot literals for 2050/1183/438/
  448/2889 need+cycle, demo fittings 1/2/10 and the EFT oracle
  use/s (`2 × (32.0/12.0)`, `0.0`, `32.0/12.0`, `10.0667`) at
  `1e-9` with outcome/stable/depletes pinned.

**Builder B — renderer tests:**

- Verbatim line sets for the three demo outcomes (stable
  percent, depletes "about", stable-100-with-no-drains), with
  and without the excluded-count sentence (wording byte-exact,
  including the disclosure constant).
- Unavailable sentence alone; `None` use/peak lines omitted,
  never rendered zeros; saved and imported details show the
  same block for the synthesized fitting (surface symmetry,
  section 4).
- Regression: resources, DPS, ship-stat, and other blocks'
  line tests pass unmodified — this slice appends one block
  and rewords none of theirs.

**Generator tests** follow the shipped pattern: oracle counts
per `CAP_EXPECTED_COUNTS`, fail-loud cases (duplicate /
unparseable / negative / non-finite), shipped-catalogue
invariants. The regenerated catalogue byte count is pinned at
integrator time against section 3's scripted 3,611,903.

**Gates (every commit):** `cargo fmt --check`, `cargo clippy
--all-targets -- -D warnings`, `cargo test`, `cargo build`.

## 9. Exclusions (locked — ship-nothing lines are explicit)

- **No capacitor boosters, on any surface.** Flutter builds
  injectors from `module.chargeTypeId` + charge attribute 67
  (`dogma_engine.dart:726–742`). Rust saved items carry no
  charge linkage (loaded booster charges sit as unlinked
  cargo), so a faithful port cannot exist on the saved surface,
  and an EFT-only booster model would branch saved-vs-imported
  meaning on the same labelled line. Rather than ship that
  asymmetry, this slice ships drains only, everywhere, and
  says "Capacitor boosters … are not modelled" in the view.
  Flutter's infinite-clip assumption ("Capacitor horizon
  3600s; injector clips are infinite.", `dogma_engine.dart:1223–1225`)
  is a second, independent reason: no fitting shape holds a
  charge count, so a finite-stock model is ungrounded today.
  `capacitorBonus` (67) is therefore never emitted or read.
- **No modifiers of any kind**: capacity, recharge, module
  needs, and cycles stay base. Flutter feeds *adjusted* values
  (`moduleAttr`/`chargeAttr` bonuses, Capacitor Management
  3418 at 5%/level on 482, cycle-shortening skill evidence in
  `dogma_engine_test.dart:2970–2989`); none of it is applied,
  exactly like resources/DPS/peak slices, and the disclosure
  names it.
- **No cross-ship effects**: incoming/outgoing neutralizer and
  NOS drain/gain, remote capacitor transfer (section 4).
- No module state (online/offline/overheated), no pulsing or
  staggered-activation tactics beyond Flutter's identical-drain
  stagger in section 2, no starting at partial charge.
- No average-recharge line and no "stable iff use/s ≤ peak"
  shortcut verdict (section 2). No sustained/burst tank. No
  new ESI scopes, storage, or EFT/DNA format changes.

## 10. Integrator list

- **README** (Fittings bullet): add capacitor stability to the
  base-values sequence in the same voice ("…also show a base
  capacitor-stability figure — whether the fitted modules
  whose base capacitor use is in Mimir's bundled item data,
  cycling continuously, settle or empty the bare hull's base
  capacitor — with capacitor boosters, skills, implants, and
  bonuses from modules, rigs, subsystems, and the ship itself
  not applied; modules whose base capacitor use is not in the
  bundled data are left out with a disclosed count, never
  counted as zero") and delete "no capacitor-stability
  figures," from the closing denial, leaving "…still no
  sustained-tank figures, and no adjusted (fitted) fitting
  totals of any kind" intact.
- **Engineering journal** (`docs/engineering-journal/LEARNINGS.md`,
  integrator's commit): two entries with Evidence/Mechanism/rule
  — (a) equilibrium is a discrete-event property, not an
  average-rate comparison (the rejected use/s ≤ peak shortcut
  and the failing-activation quantization), citing section 2
  bodies; (b) the SDE default 10000.0 for `reloadTime` must
  never substitute for an absent row (Flutter 0.0 evidence,
  1,229 affected types), and the booster ship-nothing decision
  (saved-shape charge-linkage absence + infinite clips).
- Nothing else: no `ship_stats.rs` / `ship_peak_recharge.rs`
  change (consume both as-is), no fitting-format or ESI change.
  If build discovery contradicts any count in section 3/8, the
  slice stops rather than growing scope.

## 11. Ownership and commit split

- **Design (this commit):** `docs/cap-stability-design.md` only.
  Commit: `docs(fitting): design base capacitor stability`.
- **Builder A — data + pure calculation:** generator
  (`scripts/sde/generate_fitting_types_sde.py`), regenerated
  `assets/sde/fitting_types.json`, loader
  (`src/names/fitting_types.rs`), new
  `src/fitting/ship_cap_stability.rs`, `src/fitting/mod.rs`
  wiring, section 8 Builder-A/generator tests. Commits:
  `feat(sde): emit module capacitor need and cycle attributes`,
  `feat(fitting): add pure base capacitor stability`.
- **Builder B — render:** `src/ui/fittings.rs` only, section 8
  Builder-B tests. Commit:
  `feat(fittings): show base capacitor stability in fitting details`.
- **Integrator:** README + journal per section 10, full gates,
  demo check, catalogue byte-count verification (section 3).
  Commit: `docs(fittings): document base capacitor stability`.

Builder B touches no `src/fitting/` file and codes against
section 5's locked API. Small atomic commits,
`type(scope): description`, no attribution lines. Nobody
pushes or merges; the parent does that.
