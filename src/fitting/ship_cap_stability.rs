//! Pure base capacitor stability calculation over the bundled
//! catalogue.
//!
//! [`fitting_cap_stability`] decides, for one [`CharacterFitting`],
//! whether the fitted modules whose base capacitor need and
//! cycle are proven in the bundled catalogue — cycling
//! continuously at their base rates — deplete the bare hull's
//! base capacitor, and if not, at what charge level the
//! capacitor settles. The simulation replicates Flutter's
//! `CapSimulator` at `ed698d3`
//! (`lib/features/fitting/domain/cap_simulator.dart`): an
//! event-driven simulation with pyfa's closed-form recharge
//! between events (`cap = ((1 + (sqrt(cap/C) - 1) *
//! exp(-dt/tau))^2) * C` with `tau = rechargeMs / 5.0`), no
//! time-stepping, LCM-period equilibrium detection, water-mark
//! stable percent, event-quantized seconds to empty, and a
//! 3600 s horizon. See `docs/cap-stability-design.md`.
//!
//! No modifier of any kind is applied by `fitting_cap_stability`:
//! fitted modules, rigs, subsystems, skills, implants, and ship
//! bonuses contribute nothing beyond each module's base need and
//! cycle, so the values describe the bare hull and can differ
//! from EVE. [`fitting_cap_stability_with_module_bonuses`] adds
//! fitted-module capacitor capacity and recharge bonuses to the
//! same pair under `docs/cap-bonuses-design.md`.
//! Capacitor boosters ship nothing: saved items carry no
//! charge linkage and no fitting shape holds a charge count,
//! so a booster model cannot be grounded (design section 9).
//! Drained-from and transferred-to effects on other ships
//! (neutralizers, NOS, remote repairers) are likewise
//! unmodelled: every counted module drains only its own ship.
//!
//! The module is pure computation over the bundled catalogue —
//! no egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] and [`FittingTypes`], the same
//! dependencies `resources.rs` takes. It logs nothing: it runs
//! at render cadence, so per-frame `[FITTING]` logging would
//! spam the log; the catalogue load already logs counts once.

use std::collections::BTreeMap;

use crate::esi::models::CharacterFitting;
use crate::fitting::ship_peak_recharge::{capacitor_peak_recharge, ship_base_peak_recharge};
use crate::fitting::ship_resistances::bonused_capacitor;
use crate::fitting::ship_stats::{ship_base_stats, ShipBaseStatsOutcome};
use crate::names::fitting_types::FittingTypes;

/// Simulation horizon in seconds (Flutter
/// `CapSimulator.maxSeconds`, `cap_simulator.dart` at
/// `ed698d3`). The port keeps it unlabelled on screen; it
/// only bounds the event loop.
const MAX_SECONDS: f64 = 3600.0;

/// Base capacitor-stability outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum CapStabilityOutcome {
    /// The capacitor settles into a repeating cycle; `percent`
    /// is the water-mark midpoint percent of capacity.
    Stable { percent: f64 },
    /// The capacitor empties; `seconds` is the event time of
    /// the activation that could not be paid, quantized to
    /// event boundaries, never an interpolated instant.
    Depletes { seconds: f64 },
    /// The ship row is missing, not category 6, or its base
    /// capacitor capacity / recharge rate is absent,
    /// non-finite, or zero, so no honest numbers exist.
    /// For `fitting_cap_stability_with_module_bonuses` this
    /// also carries its bonused capacity / recharge is
    /// absent, non-finite, zero, or negative.
    Unavailable,
}

/// Base capacitor-stability figures for one fitting.
/// `total_use_per_sec` is the exact average
/// `Σ quantity·capNeed/(cycleMs/1000)` over counted drains —
/// a supporting figure only, never the verdict.
/// `peak_recharge_per_sec` is the shipped
/// `ship_base_peak_recharge` capacitor rate; it labels the
/// comparison, never decides `Stable`/`Depletes`. Both are
/// `None` when the outcome is `Unavailable`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FittingCapStability {
    pub outcome: CapStabilityOutcome,
    pub total_use_per_sec: Option<f64>,
    pub peak_recharge_per_sec: Option<f64>,
    /// Fitted slot-module units that drain (quantity units,
    /// saturating). Known-zero rows (present `0.0` need)
    /// contribute neither here nor to `excluded_modules`.
    pub counted_modules: u64,
    /// Fitted slot-row units whose base need or cycle
    /// cannot be proven — unknown type ids, absent
    /// `capacitorNeed`, a positive need with no cycle, or an
    /// unusable value — in quantity units (the `resources.rs`
    /// units precedent: a stacked slot row of five uncounted
    /// modules reports five), never silently zero.
    pub excluded_modules: u64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BonusedFittingCapStability {
    pub outcome: CapStabilityOutcome,
    pub total_use_per_sec: Option<f64>,
    pub peak_recharge_per_sec: Option<f64>,
    /// Same definition, units, and source as
    /// `FittingCapStability::counted_modules`.
    pub counted_modules: u64,
    /// Drain-dimension count: same definition, units,
    /// and source as
    /// `FittingCapStability::excluded_modules` (pinned
    /// equal, design section 8).
    pub excluded_modules: u64,
    /// Bonus-dimension excluded count: counted fitted
    /// rows with no catalogue row, from
    /// `bonused_capacitor`. A subset of the rows behind
    /// `excluded_modules` on any real fitting, disclosed
    /// separately with its own wording — never summed
    /// with it.
    pub bonus_excluded_modules: usize,
    /// Capacity-dimension unapplied count, from
    /// `bonused_capacitor`. Never summed with
    /// `capacitor_recharge_unapplied_modules` or any
    /// resistance/hit-point count.
    pub capacitor_capacity_unapplied_modules: usize,
    /// Recharge-dimension unapplied count, from
    /// `bonused_capacitor`. Never summed with
    /// `capacitor_capacity_unapplied_modules`.
    pub capacitor_recharge_unapplied_modules: usize,
}

/// One repeating drain: a cycle and a need shared by `count`
/// identical modules (Flutter `CapDrain`).
#[derive(Debug, Clone, Copy)]
struct CapDrain {
    duration_ms: f64,
    cap_need: f64,
    count: u64,
}

/// One queued activation (Flutter `_CapEvent`, drains only).
#[derive(Debug, Clone, Copy)]
struct CapEvent {
    t: f64,
    duration: f64,
    cap_need: f64,
}

/// Simulator result (Flutter `CapSimResult`, drains only).
#[derive(Debug, Clone, Copy)]
struct CapSimResult {
    is_stable: bool,
    stable_percent: f64,
    seconds_to_empty: f64,
}

/// Whether a saved-fitting flag is a slot-section flag,
/// following the `dps.rs` `is_slot_flag` shape: the `LoSlot` /
/// `MedSlot` / `HiSlot` / `RigSlot` / `SubSystemSlot`
/// prefixes count as slots; every other flag — including
/// `DroneBay`, `FighterBay`, `Cargo`, `Invalid`, `""`, and
/// any unknown flag — does not. The flag is the only
/// section test; slot belonging is never judged against the
/// row's own slot effect (`resources.rs` precedent).
fn is_slot_flag(flag: &str) -> bool {
    flag.starts_with("LoSlot")
        || flag.starts_with("MedSlot")
        || flag.starts_with("HiSlot")
        || flag.starts_with("RigSlot")
        || flag.starts_with("SubSystemSlot")
}

/// A catalogue value is usable only when present, finite, and
/// non-negative. A present `0.0` stays a real zero; anything
/// else is treated as no data for that computation.
fn usable(value: Option<f64>) -> Option<f64> {
    value.filter(|v| v.is_finite() && *v >= 0.0)
}

/// Greatest common divisor of two non-negative integers
/// (Euclidean loop, `_lcm`'s inner `while (y != 0)`).
fn gcd(mut x: u64, mut y: u64) -> u64 {
    while y != 0 {
        let t = y;
        y = x % y;
        x = t;
    }
    x
}

/// Least common multiple of two already-rounded integers, or
/// `None` on overflow (Flutter `_lcm` is unbounded 64-bit
/// arithmetic; the Rust port uses checked arithmetic and, on
/// overflow, the caller keeps simulating without a period
/// check — the outcome then comes from depletion or the
/// horizon, design section 2). The `x == 0 || y == 0`
/// early return keeps Flutter's shape; callers only pass
/// non-zero values.
fn lcm(a: f64, b: f64) -> Option<f64> {
    let x = a.round() as i64;
    let y = b.round() as i64;
    if x == 0 || y == 0 {
        return Some(a);
    }
    let g = gcd(x.unsigned_abs(), y.unsigned_abs());
    // `x / g` is exact; multiplying after dividing leaves the
    // most overflow headroom before the checked multiply.
    (x / g as i64).checked_mul(y).map(|value| value as f64)
}

/// Closed-form recharge between events (Flutter `_recharge`,
/// `cap_simulator.dart` lines 272–275): `dt` is the exact gap
/// to the next event; there is no step size.
fn recharge(cap: f64, dt_ms: f64, tau: f64, capacity: f64) -> f64 {
    let ratio = cap / capacity;
    let factor = 1.0 + (ratio.sqrt() - 1.0) * (-dt_ms / tau).exp();
    factor * factor * capacity
}

/// Midpoint of the cycle's water marks in percent of
/// capacity (Flutter `_stablePercent`, lines 269–270).
fn stable_percent(low: f64, high: f64, capacity: f64) -> f64 {
    ((low + high) / (2.0 * capacity)) * 100.0
}

/// Event-driven capacitor simulation over one set of drains —
/// a drains-only port of Flutter's `CapSimulator.run()` with
/// the injector paths removed (no boosters are ever built;
/// the postponed-booster signature condition is therefore
/// vacuously equal, and equilibrium reduces to the charge
/// comparison at whole LCM periods).
fn run_simulator(capacity: f64, recharge_ms: f64, drains: &[CapDrain]) -> CapSimResult {
    // Flutter edge guards (`run()` lines 97–114).
    if capacity <= 0.0 || recharge_ms <= 0.0 {
        return CapSimResult {
            is_stable: true,
            stable_percent: 0.0,
            seconds_to_empty: 0.0,
        };
    }
    let active: Vec<CapDrain> = drains
        .iter()
        .filter(|drain| drain.cap_need > 0.0 && drain.duration_ms > 0.0)
        .copied()
        .collect();
    if active.is_empty() {
        return CapSimResult {
            is_stable: true,
            stable_percent: 100.0,
            seconds_to_empty: 0.0,
        };
    }

    let tau = recharge_ms / 5.0;
    let max_ms = MAX_SECONDS * 1000.0;

    // Seed the queue (lines 122–140): identical drains
    // stagger pyfa-style as `duration / count` floored; the
    // LCM period folds with the same rounded durations.
    // `period: None` marks an overflowed LCM (checked
    // arithmetic); the loop then runs without period checks.
    let mut queue: Vec<CapEvent> = Vec::new();
    let mut period: Option<f64> = Some(1.0);
    for drain in &active {
        let (duration, cap_need) = if drain.count > 1 {
            let staggered = drain.duration_ms / drain.count as f64;
            if staggered >= 1.0 {
                (staggered.floor(), drain.cap_need)
            } else if staggered > 0.0 {
                (1.0, drain.cap_need / staggered)
            } else {
                continue;
            }
        } else {
            (drain.duration_ms, drain.cap_need)
        };
        if !duration.is_finite() || duration <= 0.0 || !cap_need.is_finite() || cap_need <= 0.0 {
            continue;
        }
        queue.push(CapEvent {
            t: 0.0,
            duration,
            cap_need,
        });
        period = period.and_then(|p| lcm(p, duration));
    }

    const MAX_SIM_ITERATIONS: usize = 200_000;
    let mut cap = capacity;
    let mut cap_lowest = capacity;
    let mut cap_lowest_pre = capacity;
    let mut cap_wrap = capacity;
    let mut t_last = 0.0;
    let mut t_wrap = period;
    let mut iterations = 0usize;
    while !queue.is_empty() {
        iterations += 1;
        if iterations > MAX_SIM_ITERATIONS {
            tracing::warn!("[FITTING] cap simulator reached iteration bound");
            return CapSimResult {
                is_stable: true,
                stable_percent: stable_percent(cap_lowest, cap_lowest_pre, capacity),
                seconds_to_empty: 0.0,
            };
        }
        // Earliest event wins; ties break by insertion order
        // (Flutter sorts the queue by time each iteration, so
        // the stable-sort tie order is insertion order).
        let mut min_index = 0;
        for (index, event) in queue.iter().enumerate().skip(1) {
            if event.t < queue[min_index].t {
                min_index = index;
            }
        }
        let event = queue.remove(min_index);
        let t_now = event.t;
        if t_now >= max_ms {
            return CapSimResult {
                is_stable: true,
                stable_percent: stable_percent(cap_lowest, cap_lowest_pre, capacity),
                seconds_to_empty: 0.0,
            };
        }

        if t_now > t_last {
            cap = recharge(cap, t_now - t_last, tau, capacity);
        }
        if t_now != t_last {
            if cap < cap_lowest_pre {
                cap_lowest_pre = cap;
            }
            // Drains only: the awaiting-signature term is
            // vacuous (always empty), so equilibrium is the
            // charge comparison alone (lines 200–210).
            if let Some(wrap) = t_wrap {
                if t_now == wrap {
                    if cap >= cap_wrap {
                        return CapSimResult {
                            is_stable: true,
                            stable_percent: stable_percent(cap_lowest, cap_lowest_pre, capacity),
                            seconds_to_empty: 0.0,
                        };
                    }
                    cap_wrap = cap;
                    if let Some(period_ms) = period {
                        t_wrap = Some(wrap + period_ms);
                    }
                }
            }
        }
        t_last = t_now;

        cap -= event.cap_need;
        if cap > capacity {
            cap = capacity;
        }
        if cap < cap_lowest {
            if cap < 0.0 {
                return CapSimResult {
                    is_stable: false,
                    stable_percent: 0.0,
                    seconds_to_empty: t_last / 1000.0,
                };
            }
            cap_lowest = cap;
        }

        // Reschedule (lines 170–174): no reload time beyond
        // the event's own duration — the cycle already
        // carries any present 1795.
        let t_next = t_now + event.duration;
        if !t_next.is_finite() || t_next <= t_now {
            tracing::warn!("[FITTING] cap simulator aborted on non-advancing event time");
            break;
        }
        queue.push(CapEvent {
            t: t_next,
            duration: event.duration,
            cap_need: event.cap_need,
        });
    }

    // Unreachable with drains only (queued events always
    // reschedule); kept for shape parity with Flutter's
    // post-loop return.
    CapSimResult {
        is_stable: true,
        stable_percent: stable_percent(cap_lowest, cap_lowest_pre, capacity),
        seconds_to_empty: 0.0,
    }
}

/// Shared drain collection for both stability entry points.
/// Extracted so module needs and cycles are base in both
/// blocks by construction (the same code), not by parallel
/// discipline.
fn collect_drains(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> (Vec<CapDrain>, u64, u64, f64) {
    // Module pass first: availability never depends on the
    // module side, so the counts below are populated on every
    // path, and the module pass never reads ship state.
    let mut counted_modules: u64 = 0;
    let mut excluded_modules: u64 = 0;
    let mut total_use: f64 = 0.0;
    // Drains grouped like Flutter's `capDrains` map
    // (`dogma_engine.dart`:714–724): key
    // `"${cycleMs.round()}:${capNeed.toStringAsFixed(3)}"`,
    // duration and need by last write, count in units.
    // Drains-only outcomes are insensitive to seeding order
    // for simultaneous events, so the map's key order is
    // immaterial; the key itself is load-bearing (a pair of
    // modules whose exact cycles differ only below the
    // rounded key must share one staggered stream).
    let mut groups: BTreeMap<(i64, String), CapDrain> = BTreeMap::new();
    for item in &fitting.items {
        // Rows with `type_id <= 0` are ignored entirely —
        // never counted, never excluded (`resources.rs`
        // `consuming_item` precedent).
        if item.type_id <= 0 || !is_slot_flag(&item.flag) {
            continue;
        }
        // Quantity clamped at zero; a zero-quantity row
        // contributes and excludes nothing
        // (`resources.rs:176` precedent).
        let quantity = item.quantity.max(0);
        if quantity == 0 {
            continue;
        }
        let quantity_units = quantity as u64;
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            // A catalogue-absent row cannot contribute a
            // drain; excluded-with-count, never silent
            // (`resources.rs:184–188` precedent).
            excluded_modules = excluded_modules.saturating_add(quantity_units);
            continue;
        };
        let Some(need) = usable(row.capacitor_need) else {
            // Absent or unusable need (`usable` maps both to
            // `None`): absence is not "known free" — a
            // present zero is data, an absent row is not.
            excluded_modules = excluded_modules.saturating_add(quantity_units);
            continue;
        };
        if need == 0.0 {
            // Known zero (projectile turrets are free to
            // fire): contributes 0 GJ/s, neither counted nor
            // excluded (resources' explicit-`0.0` precedent).
            continue;
        }
        // Cycle: 73 if present else 51, plus present 1795
        // else 0 — the `hasCapNeed`/`cycleAttrId` presence
        // pick from `dogma_engine.dart:701–713`, with the
        // bonus pipeline removed (at base values there are
        // no bonuses). The SDE default 10000.0 for 1795 is
        // never substituted. A present-but-unusable value
        // (non-finite or negative — impossible in the
        // shipped catalogue, proven by the loader
        // invariants) invalidates the row outright.
        let Some(base) = row.duration.or(row.speed) else {
            excluded_modules = excluded_modules.saturating_add(quantity_units);
            continue;
        };
        if !base.is_finite() || base < 0.0 {
            excluded_modules = excluded_modules.saturating_add(quantity_units);
            continue;
        }
        let reload = row.reload_time.unwrap_or(0.0);
        if !reload.is_finite() || reload < 0.0 {
            excluded_modules = excluded_modules.saturating_add(quantity_units);
            continue;
        }
        let cycle_ms = base + reload;
        if !cycle_ms.is_finite() || cycle_ms <= 0.0 {
            // A known cost with no rate is never zero-cost.
            excluded_modules = excluded_modules.saturating_add(quantity_units);
            continue;
        }
        counted_modules = counted_modules.saturating_add(quantity_units);
        total_use += quantity as f64 * need / (cycle_ms / 1000.0);
        let key = (cycle_ms.round() as i64, format!("{need:.3}"));
        let group = groups.entry(key).or_insert(CapDrain {
            duration_ms: cycle_ms,
            cap_need: need,
            count: 0,
        });
        group.duration_ms = cycle_ms;
        group.cap_need = need;
        group.count = group.count.saturating_add(quantity_units);
    }
    let drains: Vec<CapDrain> = groups.into_values().collect();
    (drains, counted_modules, excluded_modules, total_use)
}

/// Base capacitor stability for one fitting. The entry point
/// runs over the synthesized [`CharacterFitting`] (saved rows
/// by ESI flag prefix, imported rows by slot section via
/// `to_character_fitting()` — one code path, since need and
/// cycle live on the module). The function is total:
/// saturating counts, no panic on hostile saved data, and
/// LCM overflow handled by the simulator core.
pub fn fitting_cap_stability(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> FittingCapStability {
    let (drains, counted_modules, excluded_modules, total_use) = collect_drains(fitting, catalogue);

    // Ship availability: through `ship_base_stats` (base
    // capacity and recharge already in seconds), with the
    // design section 5 `> 0` filter on top. Flutter returns a
    // fake stable/0 for a zero-capacity ship; Rust never
    // does — zero capacity is not a known "stable".
    let stats = match ship_base_stats(fitting, catalogue) {
        ShipBaseStatsOutcome::Available(stats) => stats,
        ShipBaseStatsOutcome::Unavailable => {
            return FittingCapStability {
                outcome: CapStabilityOutcome::Unavailable,
                total_use_per_sec: None,
                peak_recharge_per_sec: None,
                counted_modules,
                excluded_modules,
            };
        }
    };
    let capacity = stats
        .capacitor_capacity
        .filter(|value| value.is_finite() && *value > 0.0);
    let recharge_secs = stats
        .capacitor_recharge_secs
        .filter(|value| value.is_finite() && *value > 0.0);
    let (Some(capacity), Some(recharge_secs)) = (capacity, recharge_secs) else {
        return FittingCapStability {
            outcome: CapStabilityOutcome::Unavailable,
            total_use_per_sec: None,
            peak_recharge_per_sec: None,
            counted_modules,
            excluded_modules,
        };
    };

    let total_use_per_sec = total_use.is_finite().then_some(total_use);
    let peak_recharge_per_sec = ship_base_peak_recharge(&stats).capacitor_gj_per_sec;
    if drains.is_empty() {
        // Flutter no-drains early return (lines 108–114):
        // stable at 100% with `total_use_per_sec = Some(0.0)`
        // — holds even with excluded modules; the excluded
        // count is what keeps the line honest.
        return FittingCapStability {
            outcome: CapStabilityOutcome::Stable { percent: 100.0 },
            total_use_per_sec: Some(0.0),
            peak_recharge_per_sec,
            counted_modules,
            excluded_modules,
        };
    }
    let result = run_simulator(capacity, recharge_secs * 1000.0, &drains);
    let outcome = if result.is_stable {
        CapStabilityOutcome::Stable {
            percent: result.stable_percent,
        }
    } else {
        CapStabilityOutcome::Depletes {
            seconds: result.seconds_to_empty,
        }
    };
    FittingCapStability {
        outcome,
        total_use_per_sec,
        peak_recharge_per_sec,
        counted_modules,
        excluded_modules,
    }
}

pub fn fitting_cap_stability_with_module_bonuses(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> BonusedFittingCapStability {
    let (drains, counted_modules, excluded_modules, total_use) = collect_drains(fitting, catalogue);
    let Some(bonused) = bonused_capacitor(fitting, catalogue) else {
        return BonusedFittingCapStability {
            outcome: CapStabilityOutcome::Unavailable,
            total_use_per_sec: None,
            peak_recharge_per_sec: None,
            counted_modules,
            excluded_modules,
            bonus_excluded_modules: 0,
            capacitor_capacity_unapplied_modules: 0,
            capacitor_recharge_unapplied_modules: 0,
        };
    };
    let capacitor_capacity = bonused.values[0].filter(|value| value.is_finite() && *value > 0.0);
    let recharge_ms = bonused.values[1].filter(|value| value.is_finite() && *value > 0.0);
    let (Some(capacity), Some(recharge_ms)) = (capacitor_capacity, recharge_ms) else {
        return BonusedFittingCapStability {
            outcome: CapStabilityOutcome::Unavailable,
            total_use_per_sec: None,
            peak_recharge_per_sec: None,
            counted_modules,
            excluded_modules,
            bonus_excluded_modules: bonused.excluded_modules,
            capacitor_capacity_unapplied_modules: bonused.capacitor_capacity_unapplied_modules,
            capacitor_recharge_unapplied_modules: bonused.capacitor_recharge_unapplied_modules,
        };
    };
    let recharge_secs = recharge_ms / 1000.0;
    if !recharge_secs.is_finite() || recharge_secs <= 0.0 {
        return BonusedFittingCapStability {
            outcome: CapStabilityOutcome::Unavailable,
            total_use_per_sec: None,
            peak_recharge_per_sec: None,
            counted_modules,
            excluded_modules,
            bonus_excluded_modules: bonused.excluded_modules,
            capacitor_capacity_unapplied_modules: bonused.capacitor_capacity_unapplied_modules,
            capacitor_recharge_unapplied_modules: bonused.capacitor_recharge_unapplied_modules,
        };
    }
    let total_use_per_sec = total_use.is_finite().then_some(total_use);
    let peak_recharge_per_sec = capacitor_peak_recharge(Some(capacity), Some(recharge_secs));
    if drains.is_empty() {
        return BonusedFittingCapStability {
            outcome: CapStabilityOutcome::Stable { percent: 100.0 },
            total_use_per_sec: Some(0.0),
            peak_recharge_per_sec,
            counted_modules,
            excluded_modules,
            bonus_excluded_modules: bonused.excluded_modules,
            capacitor_capacity_unapplied_modules: bonused.capacitor_capacity_unapplied_modules,
            capacitor_recharge_unapplied_modules: bonused.capacitor_recharge_unapplied_modules,
        };
    }
    let result = run_simulator(capacity, recharge_secs * 1000.0, &drains);
    let outcome = if result.is_stable {
        CapStabilityOutcome::Stable {
            percent: result.stable_percent,
        }
    } else {
        CapStabilityOutcome::Depletes {
            seconds: result.seconds_to_empty,
        }
    };
    BonusedFittingCapStability {
        outcome,
        total_use_per_sec,
        peak_recharge_per_sec,
        counted_modules,
        excluded_modules,
        bonus_excluded_modules: bonused.excluded_modules,
        capacitor_capacity_unapplied_modules: bonused.capacitor_capacity_unapplied_modules,
        capacitor_recharge_unapplied_modules: bonused.capacitor_recharge_unapplied_modules,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::eft::{parse_eft, EftImportOutcome};
    use crate::fitting::ship_resistances::bonused_capacitor;
    use crate::fitting::ship_resistances::ship_resistances_with_module_bonuses;

    fn fitting(ship_type_id: i64, items: Vec<FittingItem>) -> CharacterFitting {
        CharacterFitting {
            fitting_id: 1,
            name: "test".to_string(),
            description: None,
            ship_type_id,
            items,
        }
    }

    fn item(flag: &str, quantity: i64, type_id: i64) -> FittingItem {
        FittingItem {
            flag: flag.to_string(),
            quantity,
            type_id,
        }
    }

    fn bundled() -> FittingTypes {
        FittingTypes::load_bundled().expect("bundled catalogue loads")
    }

    fn drain(duration_ms: f64, cap_need: f64, count: u64) -> CapDrain {
        CapDrain {
            duration_ms,
            cap_need,
            count,
        }
    }

    /// Hand-derived float with the division shown; uniform
    /// `1e-9` absolute tolerance (design section 8).
    fn assert_close(actual: f64, expected: f64, label: &str) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "{label}: expected {expected}, got {actual}"
        );
    }

    fn stable_percent_of(result: &FittingCapStability) -> f64 {
        match result.outcome {
            CapStabilityOutcome::Stable { percent } => percent,
            other => panic!("expected Stable, got {other:?}"),
        }
    }

    fn depletes_seconds_of(result: &FittingCapStability) -> f64 {
        match result.outcome {
            CapStabilityOutcome::Depletes { seconds } => seconds,
            other => panic!("expected Depletes, got {other:?}"),
        }
    }

    fn use_of(result: &FittingCapStability, label: &str) -> f64 {
        match result.total_use_per_sec {
            Some(value) => value,
            None => panic!("{label}: expected Some use, got None"),
        }
    }

    fn peak_of(result: &FittingCapStability, label: &str) -> f64 {
        match result.peak_recharge_per_sec {
            Some(value) => value,
            None => panic!("{label}: expected Some peak, got None"),
        }
    }

    fn stable_percent_of_bonused(result: &BonusedFittingCapStability) -> f64 {
        match result.outcome {
            CapStabilityOutcome::Stable { percent } => percent,
            other => panic!("expected Stable, got {other:?}"),
        }
    }

    fn depletes_seconds_of_bonused(result: &BonusedFittingCapStability) -> f64 {
        match result.outcome {
            CapStabilityOutcome::Depletes { seconds } => seconds,
            other => panic!("expected Depletes, got {other:?}"),
        }
    }

    fn use_of_bonused(result: &BonusedFittingCapStability, label: &str) -> f64 {
        match result.total_use_per_sec {
            Some(value) => value,
            None => panic!("{label}: expected Some use, got None"),
        }
    }

    fn peak_of_bonused(result: &BonusedFittingCapStability, label: &str) -> f64 {
        match result.peak_recharge_per_sec {
            Some(value) => value,
            None => panic!("{label}: expected Some peak, got None"),
        }
    }

    // --- Simulator-core oracles: Flutter `cap_simulator_test.dart`
    // fixtures (capacity 1000 GJ, recharge 60000 ms; peak
    // `2.5 * 1000 / 60 = 41.666... GJ/s`). The `CapSimulator`
    // body is pure arbitration over these inputs, so the
    // fixtures port 1:1 as unit tests on the Rust core. Every
    // literal below was first produced by an independent
    // line-by-line Python translation of the Dart body and
    // cross-checked against Flutter's own assertions in the
    // test file (stability booleans, percent bounds, strict
    // monotonic ordering, stagger equivalence within 0.001).

    #[test]
    fn no_drains_is_fully_stable() {
        let result = run_simulator(1000.0, 60000.0, &[]);
        assert!(result.is_stable);
        assert_close(result.stable_percent, 100.0, "no-drain percent");
        assert_close(result.seconds_to_empty, 0.0, "no-drain seconds");
    }

    #[test]
    fn light_drain_settles_high() {
        // 10 GJ every 10 s = 1 GJ/s against a peak recharge of
        // 2.5 * 1000 / 60 = 41.666... GJ/s.
        let result = run_simulator(1000.0, 60000.0, &[drain(10000.0, 10.0, 1)]);
        assert!(result.is_stable);
        assert!(result.stable_percent > 80.0);
        assert!(result.stable_percent <= 100.0);
        assert_close(result.stable_percent, 98.72790372802693, "light percent");
    }

    #[test]
    fn overwhelming_drain_empties_at_event_second() {
        // 1000 GJ every 1 s: the `t = 0` spend leaves cap = 0;
        // one second of closed-form recharge regains far
        // under 1000 GJ, so the `t = 1.0 s` activation cannot
        // be paid. The result is the event time, never an
        // interpolated root (Flutter only asserts the (0, 60)
        // interval; the port pins the exact event second).
        let result = run_simulator(1000.0, 60000.0, &[drain(1000.0, 1000.0, 1)]);
        assert!(!result.is_stable);
        assert_eq!(result.seconds_to_empty, 1.0);
    }

    #[test]
    fn staggered_identical_modules_match_halved_cycle() {
        // (20 GJ, 10000 ms, count 2) ≡ (20 GJ, 5000 ms,
        // count 1): the count-2 stream staggers to a 5000 ms
        // interval (floor(10000/2)), i.e. the identical
        // simulation, so the percents agree far inside
        // Flutter's 0.001 tolerance.
        let staggered = run_simulator(1000.0, 60000.0, &[drain(10000.0, 20.0, 2)]);
        let halved = run_simulator(1000.0, 60000.0, &[drain(5000.0, 20.0, 1)]);
        assert_eq!(staggered.is_stable, halved.is_stable);
        assert!(
            (staggered.stable_percent - halved.stable_percent).abs() < 0.001,
            "stagger equivalence: {} vs {}",
            staggered.stable_percent,
            halved.stable_percent
        );
        assert_close(
            staggered.stable_percent,
            95.0710367210495,
            "staggered percent",
        );
        assert_close(halved.stable_percent, 95.0710367210495, "halved percent");
    }

    #[test]
    fn stability_falls_as_drain_rises() {
        // Need 20 < 60 < 120 GJ at 5000 ms: strictly
        // decreasing stable percent (Flutter monotonicity
        // ordering), with the port's exact literals pinned.
        // Hand-simulation of section 2 gives ~95.1 / ~84.8 /
        // ~67.8.
        let light = run_simulator(1000.0, 60000.0, &[drain(5000.0, 20.0, 1)]);
        let medium = run_simulator(1000.0, 60000.0, &[drain(5000.0, 60.0, 1)]);
        let heavy = run_simulator(1000.0, 60000.0, &[drain(5000.0, 120.0, 1)]);
        assert!(light.is_stable && medium.is_stable && heavy.is_stable);
        assert!(light.stable_percent > medium.stable_percent);
        assert!(medium.stable_percent > heavy.stable_percent);
        assert_close(light.stable_percent, 95.0710367210495, "light percent");
        assert_close(medium.stable_percent, 84.78945064947486, "medium percent");
        assert_close(heavy.stable_percent, 67.76238466310953, "heavy percent");
    }

    #[test]
    fn overspend_at_t_zero_depletes_at_zero_seconds() {
        // 120 GJ every 10 s on a 100 GJ capacitor: the
        // `t = 0` spend already overspends, so the run ends
        // at exactly 0.0 s — again the event time.
        let result = run_simulator(100.0, 60000.0, &[drain(10000.0, 120.0, 1)]);
        assert!(!result.is_stable);
        assert_eq!(result.seconds_to_empty, 0.0);
    }

    #[test]
    fn depletion_is_quantized_to_event_times() {
        // 100 GJ every 1 s on a 100 GJ capacitor: `t = 0`
        // leaves cap = 0, one second of recharge regains
        // ~0.64 GJ, and the `t = 1.0 s` activation cannot be
        // paid. Any sub-event interpolation of the empty
        // instant would report a different figure.
        let result = run_simulator(100.0, 60000.0, &[drain(1000.0, 100.0, 1)]);
        assert!(!result.is_stable);
        assert_eq!(result.seconds_to_empty, 1.0);
    }

    #[test]
    fn horizon_returns_stable_without_period_alignment() {
        // A 1000.5 ms cycle rounds to LCM period 1000 ms,
        // which no event time ever hits exactly, so no
        // period-boundary equilibrium can trigger: the run
        // reaches the 3600 s horizon and returns stable with
        // the water-mark percent (1 GJ every ~1 s against a
        // 41.666... GJ/s peak never depletes).
        let result = run_simulator(1000.0, 60000.0, &[drain(1000.5, 1.0, 1)]);
        assert!(result.is_stable);
        assert_close(result.stable_percent, 98.79626687547004, "horizon percent");
    }

    #[test]
    fn lcm_overflow_falls_back_to_horizon_or_depletion() {
        // LCM(4294967296, 4294967295) = 18446744069414584320
        // ms (coprime: 2^32 and 2^32 − 1) overflows `i64`:
        // the port drops the period check and the outcome
        // comes from depletion or the horizon. Two 1 GJ
        // drains on 1000 GJ never deplete, and the next
        // activations (~4.29e9 ms) sit past the 3,600,000 ms
        // horizon, so the run ends there: water marks are
        // post-spend 998 GJ and pre-event 1000 GJ →
        // (998+1000)/2000*100 = 99.9.
        let stable = run_simulator(
            1000.0,
            60000.0,
            &[drain(4294967296.0, 1.0, 1), drain(4294967295.0, 1.0, 1)],
        );
        assert!(stable.is_stable);
        assert_close(stable.stable_percent, 99.9, "overflow horizon percent");
        // The depletion half proves the same fallback
        // terminates via depletion: 150 GJ owed at `t = 0`
        // on a 100 GJ capacitor ends the run at 0.0 s.
        let depleted = run_simulator(100.0, 60000.0, &[drain(4294967296.0, 150.0, 1)]);
        assert!(!depleted.is_stable);
        assert_eq!(depleted.seconds_to_empty, 0.0);
        // The checked LCM helper itself.
        assert_eq!(lcm(1.0, 10000.0), Some(10000.0));
        assert_eq!(lcm(6.0, 8.0), Some(24.0));
        assert_eq!(lcm(1.0, 0.0), Some(1.0));
        assert_eq!(lcm(4294967296.0, 4294967295.0), None);
    }

    #[test]
    fn nonpositive_inputs_return_without_simulating() {
        // Flutter guards (callers never pass these; the core
        // matches the body for direct calls).
        for (capacity, recharge_ms) in [(0.0, 60000.0), (1000.0, 0.0), (-1.0, -1.0)] {
            let result = run_simulator(capacity, recharge_ms, &[drain(1000.0, 10.0, 1)]);
            assert!(result.is_stable);
            assert_close(result.stable_percent, 0.0, "guard percent");
            assert_close(result.seconds_to_empty, 0.0, "guard seconds");
        }
    }

    // --- Inclusion matrix against a fixture catalogue
    // (design section 4, one test per row; the fictional
    // ship mirrors the Rifter's 250 GJ / 125 s).
    fn fixture_catalogue() -> FittingTypes {
        FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},
                {"typeId":101,"typeName":"73-Cycle Drain","categoryId":7,"slotEffects":[13],"capacitorNeed":32.0,"duration":12000.0},
                {"typeId":102,"typeName":"51-Cycle Drain","categoryId":7,"slotEffects":[13],"capacitorNeed":20.0,"speed":5000.0},
                {"typeId":103,"typeName":"Reload Drain","categoryId":7,"slotEffects":[13],"capacitorNeed":50.0,"duration":15000.0,"reloadTime":10000.0},
                {"typeId":104,"typeName":"51 Reload Drain","categoryId":7,"slotEffects":[13],"capacitorNeed":8.0,"speed":2000.0,"reloadTime":2000.0},
                {"typeId":105,"typeName":"Known Zero","categoryId":7,"slotEffects":[12],"capacitorNeed":0.0,"speed":3750.0,"reloadTime":10000.0},
                {"typeId":106,"typeName":"No Cycle","categoryId":7,"slotEffects":[13],"capacitorNeed":15.0},
                {"typeId":107,"typeName":"Absent Need","categoryId":7,"slotEffects":[13],"speed":3000.0},
                {"typeId":108,"typeName":"Rig Drain","categoryId":7,"slotEffects":[2663],"capacitorNeed":10.0,"duration":10000.0},
                {"typeId":109,"typeName":"Subsystem Drain","categoryId":7,"slotEffects":[3772],"capacitorNeed":5.0,"duration":10000.0},
                {"typeId":110,"typeName":"Duration Preferred","categoryId":7,"slotEffects":[13],"capacitorNeed":30.0,"duration":10000.0,"speed":999999.0},
                {"typeId":111,"typeName":"Half Cycle","categoryId":7,"slotEffects":[13],"capacitorNeed":32.0,"duration":6000.0},
                {"typeId":112,"typeName":"LX Energy Neutralizer","categoryId":7,"slotEffects":[13],"capacitorNeed":100.0,"duration":11000.0}]}"#,
        )
        .expect("fixture catalogue parses")
    }

    fn slot_result(catalogue: &FittingTypes, items: Vec<FittingItem>) -> FittingCapStability {
        fitting_cap_stability(&fitting(42, items), catalogue)
    }

    #[test]
    fn eligible_73_cycle_drain_counts() {
        let catalogue = fixture_catalogue();
        // 32.0 GJ per 12.0 s = 32.0 / 12.0 = 2.666... GJ/s.
        let result = slot_result(&catalogue, vec![item("HiSlot0", 1, 101)]);
        assert_close(use_of(&result, "73-cycle use"), 32.0 / 12.0, "73-cycle use");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
        let percent = stable_percent_of(&result);
        assert!(
            percent > 0.0 && percent <= 100.0,
            "73-cycle percent {percent}"
        );
    }

    #[test]
    fn eligible_51_cycle_drain_counts() {
        let catalogue = fixture_catalogue();
        // 20.0 GJ per 5.0 s = 20.0 / 5.0 = 4.0 GJ/s.
        let result = slot_result(&catalogue, vec![item("HiSlot0", 1, 102)]);
        assert_close(use_of(&result, "51-cycle use"), 4.0, "51-cycle use");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn present_reload_extends_duration_cycle() {
        let catalogue = fixture_catalogue();
        // 50.0 GJ per (15000.0 + 10000.0) ms = 50.0 / 25.0
        // = 2.0 GJ/s: the present 1795 row is added to the
        // cycle (Flutter `dogma_engine.dart`:697–700).
        let result = slot_result(&catalogue, vec![item("HiSlot0", 1, 103)]);
        assert_close(use_of(&result, "reload use"), 2.0, "reload use");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn present_reload_extends_speed_cycle() {
        let catalogue = fixture_catalogue();
        // 8.0 GJ per (2000.0 + 2000.0) ms = 8.0 / 4.0
        // = 2.0 GJ/s.
        let result = slot_result(&catalogue, vec![item("HiSlot0", 1, 104)]);
        assert_close(use_of(&result, "speed+reload use"), 2.0, "speed+reload use");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn absent_reload_never_substitutes_default() {
        let catalogue = fixture_catalogue();
        // Type 101 carries no 1795 row: the cycle is the
        // bare 12000.0 ms. Substituting the SDE default
        // 10000.0 would lengthen it to 22000.0 ms and cut use
        // to 32.0 / 22.0 = 1.454... — the pin below fails
        // under substitution.
        let result = slot_result(&catalogue, vec![item("HiSlot0", 1, 101)]);
        assert_close(
            use_of(&result, "absent-reload use"),
            32.0 / 12.0,
            "absent-reload use",
        );
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn duration_is_preferred_over_speed_when_both_present() {
        let catalogue = fixture_catalogue();
        // The `cycleAttrId` presence pick (73 before 51):
        // 30.0 GJ per 10.0 s = 3.0 GJ/s, not the
        // 999999.0 ms speed fallback.
        let result = slot_result(&catalogue, vec![item("HiSlot0", 1, 110)]);
        assert_close(
            use_of(&result, "duration-preferred use"),
            3.0,
            "duration-preferred use",
        );
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn known_zero_need_counts_nothing_and_excludes_nothing() {
        let catalogue = fixture_catalogue();
        // A present `0.0` need is data (free to fire): zero
        // use, neither counted nor excluded — and a fitting
        // of only known-zero modules is stable at 100%.
        let result = slot_result(&catalogue, vec![item("HiSlot0", 1, 105)]);
        assert_close(stable_percent_of(&result), 100.0, "known-zero percent");
        assert_close(use_of(&result, "known-zero use"), 0.0, "known-zero use");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 0);
        // Mixed with a counted drain, known-zero units do
        // not inflate the counted total or the excluded
        // count; the use is the counted drain alone.
        let mixed = slot_result(
            &catalogue,
            vec![item("HiSlot0", 1, 101), item("HiSlot1", 3, 105)],
        );
        assert_close(use_of(&mixed, "mixed use"), 32.0 / 12.0, "mixed use");
        assert_eq!(mixed.counted_modules, 1);
        assert_eq!(mixed.excluded_modules, 0);
    }

    #[test]
    fn need_without_cycle_is_excluded() {
        let catalogue = fixture_catalogue();
        // 15.0 GJ with neither 73 nor 51: a known cost with
        // no rate is excluded-with-count, never zero-cost.
        let result = slot_result(&catalogue, vec![item("HiSlot0", 1, 106)]);
        assert_close(stable_percent_of(&result), 100.0, "no-cycle percent");
        assert_close(use_of(&result, "no-cycle use"), 0.0, "no-cycle use");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 1);
    }

    #[test]
    fn absent_need_is_excluded() {
        let catalogue = fixture_catalogue();
        // No `capacitorNeed` row: absence is not "known
        // free" (Flutter's `hasCapNeed = false` path drops
        // silently; Rust counts).
        let result = slot_result(&catalogue, vec![item("HiSlot0", 1, 107)]);
        assert_close(stable_percent_of(&result), 100.0, "absent-need percent");
        assert_close(use_of(&result, "absent-need use"), 0.0, "absent-need use");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 1);
    }

    #[test]
    fn unknown_type_id_is_excluded_in_quantity_units() {
        let catalogue = fixture_catalogue();
        // A catalogue-absent row is excluded-with-count
        // (`resources.rs:184–188` precedent, not the `dps.rs`
        // silent skip), in quantity units: a stacked row of
        // three reports three.
        let result = slot_result(&catalogue, vec![item("LoSlot0", 3, 999999)]);
        assert_close(use_of(&result, "unknown-type use"), 0.0, "unknown-type use");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 3);
    }

    #[test]
    fn slot_flag_prefixes_count_regardless_of_module() {
        let catalogue = fixture_catalogue();
        // Every slot-section prefix is in scope (the
        // `dps.rs` flag shape), including rigs and
        // subsystems — in scope for parity even though the
        // shipped catalogue carries no rig/subsystem drain
        // (fixtures can still prove the wiring).
        for flag in [
            "LoSlot0",
            "MedSlot7",
            "HiSlot3",
            "RigSlot0",
            "SubSystemSlot0",
        ] {
            let result = slot_result(&catalogue, vec![item(flag, 1, 101)]);
            assert_eq!(result.counted_modules, 1, "flag {flag}");
            assert_eq!(result.excluded_modules, 0, "flag {flag}");
        }
        // Rig and subsystem rows carrying drains count
        // through their flags, not through any category
        // test: 108/109 rows under their own prefixes.
        let rig = slot_result(&catalogue, vec![item("RigSlot0", 1, 108)]);
        assert_eq!(rig.counted_modules, 1);
        assert_close(use_of(&rig, "rig use"), 10.0 / 10.0, "rig use");
        let subsystem = slot_result(&catalogue, vec![item("SubSystemSlot0", 1, 109)]);
        assert_eq!(subsystem.counted_modules, 1);
        assert_close(
            use_of(&subsystem, "subsystem use"),
            5.0 / 10.0,
            "subsystem use",
        );
    }

    #[test]
    fn non_slot_rows_neither_count_nor_exclude() {
        let catalogue = fixture_catalogue();
        // Drones, fighters, cargo, catch-all flags, and
        // loaded charges never produce drains — including
        // an unknown type id under those flags.
        for flag in [
            "DroneBay",
            "FighterBay",
            "Cargo",
            "Invalid",
            "ServiceSlot0",
            "",
            "Foo",
        ] {
            let result = slot_result(&catalogue, vec![item(flag, 1, 101)]);
            assert_close(use_of(&result, "non-slot use"), 0.0, "non-slot use");
            assert_eq!(result.counted_modules, 0, "flag {flag}");
            assert_eq!(result.excluded_modules, 0, "flag {flag}");
        }
        let result = slot_result(&catalogue, vec![item("DroneBay", 1, 999999)]);
        assert_close(
            use_of(&result, "non-slot unknown use"),
            0.0,
            "non-slot unknown use",
        );
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn quantity_clamps_at_zero_and_nonpositive_type_ids_are_ignored() {
        let catalogue = fixture_catalogue();
        // Quantity `max(0)` (`resources.rs:176` precedent):
        // zero and negative quantities neither count nor
        // exclude.
        for quantity in [0, -5] {
            let result = slot_result(&catalogue, vec![item("HiSlot0", quantity, 101)]);
            assert_close(
                use_of(&result, "zero-quantity use"),
                0.0,
                "zero-quantity use",
            );
            assert_eq!(result.counted_modules, 0);
            assert_eq!(result.excluded_modules, 0);
        }
        // Rows with `type_id <= 0` are ignored entirely.
        for type_id in [0, -1] {
            let result = slot_result(&catalogue, vec![item("HiSlot0", 1, type_id)]);
            assert_close(
                use_of(&result, "nonpositive-type use"),
                0.0,
                "nonpositive-type use",
            );
            assert_eq!(result.counted_modules, 0);
            assert_eq!(result.excluded_modules, 0);
        }
    }

    #[test]
    fn identical_drains_group_into_one_staggered_stream() {
        let catalogue = fixture_catalogue();
        // Two units of the 32 GJ / 12000 ms module group
        // into one (12000 ms, 32 GJ, count 2) drain under
        // the `"12000:32.000"` key, staggering to a 6000 ms
        // interval — the identical simulation to one unit of
        // the 32 GJ / 6000 ms module. Both deplete the
        // 250 GJ / 125 s hull at the same event second:
        // 2 * (32.0 / 12.0) = 64.0 / 12.0 = 5.333... GJ/s
        // average already exceeds the 5.0 GJ/s peak, and
        // the port lands on 234.0 s (the Demo Brawler
        // literal below). Without grouping, two ungrouped
        // streams would both fire at `t = 0` and fail at
        // 192.0 s instead — this test would catch a missing
        // grouping.
        let pair = slot_result(
            &catalogue,
            vec![item("HiSlot0", 1, 101), item("HiSlot1", 1, 101)],
        );
        let single = slot_result(&catalogue, vec![item("HiSlot0", 1, 111)]);
        assert_eq!(pair.counted_modules, 2);
        assert_eq!(single.counted_modules, 1);
        assert_eq!(depletes_seconds_of(&pair), 234.0);
        assert_eq!(depletes_seconds_of(&single), 234.0);
        assert_close(use_of(&pair, "pair use"), 64.0 / 12.0, "pair use");
        assert_close(use_of(&single, "single use"), 32.0 / 6.0, "single use");
    }

    #[test]
    fn neutralizer_counts_as_ordinary_own_ship_drain() {
        let catalogue = fixture_catalogue();
        // No special cases: any module with a proven need
        // and cycle drains its own ship. Cross-ship effects
        // (what the neutralizer does to its target) are
        // unmodelled by design and appear in no number.
        // 100.0 GJ per 11.0 s = 100.0 / 11.0 GJ/s.
        let result = slot_result(&catalogue, vec![item("HiSlot0", 1, 112)]);
        assert_close(
            use_of(&result, "neutralizer use"),
            100.0 / 11.0,
            "neutralizer use",
        );
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn engine_fixture_matches_simulator_core() {
        // The `dogma_engine_test.dart` base-pure fixture
        // (1000/60000 ship, one 60 GJ / 5000 ms module)
        // through the fitting API: the engine and the
        // simulator agree at base values where the engine's
        // bonuses are zero. Use 60.0 / 5.0 = 12.0 GJ/s;
        // peak 2.5 * 1000.0 / 60.0 = 2500.0 / 60.0 GJ/s.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":43,"typeName":"Fixture Oracle Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":1000.0,"rechargeRate":60000.0},
                {"typeId":201,"typeName":"Fixture Oracle Module","categoryId":7,"slotEffects":[11],"capacitorNeed":60.0,"duration":5000.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let result = fitting_cap_stability(&fitting(43, vec![item("LoSlot0", 1, 201)]), &catalogue);
        assert_close(use_of(&result, "engine use"), 12.0, "engine use");
        assert_close(
            peak_of(&result, "engine peak"),
            2500.0 / 60.0,
            "engine peak",
        );
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
        // Identical to the simulator-core medium literal.
        assert_close(
            stable_percent_of(&result),
            84.78945064947486,
            "engine percent",
        );
    }

    // --- Availability (design section 5; never depends on
    // the module side).

    #[test]
    fn missing_ship_is_unavailable_with_counts_but_no_figures() {
        let catalogue = fixture_catalogue();
        // Counted modules exist, yet the figures are `None`:
        // availability never depends on module data.
        let result =
            fitting_cap_stability(&fitting(999999, vec![item("HiSlot0", 1, 101)]), &catalogue);
        assert_eq!(
            result.outcome,
            CapStabilityOutcome::Unavailable,
            "missing ship"
        );
        assert_eq!(result.total_use_per_sec, None);
        assert_eq!(result.peak_recharge_per_sec, None);
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn non_category_6_ship_is_unavailable() {
        let catalogue = fixture_catalogue();
        // A module row as the ship: the catalogue lookup
        // succeeds, but the row is not category 6.
        let result =
            fitting_cap_stability(&fitting(101, vec![item("HiSlot0", 1, 102)]), &catalogue);
        assert_eq!(
            result.outcome,
            CapStabilityOutcome::Unavailable,
            "non-ship row"
        );
        assert_eq!(result.total_use_per_sec, None);
    }

    #[test]
    fn each_unusable_capacitor_input_is_unavailable() {
        // Each of the two ship inputs absent / present-zero /
        // negative collapses to `Unavailable` (JSON cannot
        // spell NaN/Infinity, so the non-finite half rides on
        // the shared `usable` rule `ship_stats.rs` already
        // pins directly).
        let cases = [
            (
                "absent capacity",
                r#"{"types":[{"typeId":44,"typeName":"Bare Hull","categoryId":6,"slotEffects":[],"rechargeRate":125000.0}]}"#,
            ),
            (
                "zero capacity",
                r#"{"types":[{"typeId":44,"typeName":"Dead Battery","categoryId":6,"slotEffects":[],"capacitorCapacity":0.0,"rechargeRate":125000.0}]}"#,
            ),
            (
                "negative capacity",
                r#"{"types":[{"typeId":44,"typeName":"Bad Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":-1.0,"rechargeRate":125000.0}]}"#,
            ),
            (
                "absent recharge",
                r#"{"types":[{"typeId":44,"typeName":"No Recharge","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0}]}"#,
            ),
            (
                "zero recharge",
                r#"{"types":[{"typeId":44,"typeName":"Instant Recharge","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":0.0}]}"#,
            ),
            (
                "negative recharge",
                r#"{"types":[{"typeId":44,"typeName":"Bad Recharge","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":-1.0}]}"#,
            ),
        ];
        for (label, json) in cases {
            let catalogue = FittingTypes::from_json(json).expect("fixture catalogue parses");
            let result =
                fitting_cap_stability(&fitting(44, vec![item("HiSlot0", 1, 101)]), &catalogue);
            // Type 101 is absent from these catalogues, so
            // the counted side is one excluded unknown row
            // — availability still does not depend on it.
            assert_eq!(result.outcome, CapStabilityOutcome::Unavailable, "{label}");
            assert_eq!(result.total_use_per_sec, None, "{label}");
            assert_eq!(result.peak_recharge_per_sec, None, "{label}");
            assert_eq!(result.counted_modules, 0, "{label}");
            assert_eq!(result.excluded_modules, 1, "{label}");
        }
    }

    #[test]
    fn empty_fitting_with_no_ship_data_is_unavailable() {
        let catalogue = fixture_catalogue();
        let result = fitting_cap_stability(&fitting(999999, vec![]), &catalogue);
        assert_eq!(
            result.outcome,
            CapStabilityOutcome::Unavailable,
            "empty fitting"
        );
        assert_eq!(result.total_use_per_sec, None);
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 0);
    }

    // --- Bundled-catalogue pins (design section 7). Demo
    // fittings replicate `assets/demo/fittings.json` rows
    // (verified at build time): Demo Brawler 1 (Rifter 587),
    // Mission Runner 2 (Rifter 587), Demo Runner 10
    // (Punisher 597). Ship inputs are the #578/#581 pins:
    // Rifter 250.0 GJ / 125.0 s → peak 2.5 * 250.0 / 125.0
    // = 625.0 / 125.0 = 5.0 GJ/s; Punisher 400.0 GJ /
    // 160.0 s → peak 2.5 * 400.0 / 160.0 = 1000.0 / 160.0
    // = 6.25 GJ/s. Type 2050 (Gistum C-Type Multispectrum
    // Shield Hardener) carries need 32.0 GJ and duration
    // 12000.0 ms with no 1795 row → 32.0 / 12.0
    // = 2.666... GJ/s per module. Outcome literals are the
    // port's exact outputs, cross-checked against an
    // independent Python translation of the Flutter body
    // and the design's hand-simulated values (~234 s,
    // ~77%, ~36 s).

    #[test]
    fn demo_brawler_depletes_at_pinned_second() {
        let catalogue = bundled();
        // Fitting 1: 2× type 2050 → 2 * (32.0 / 12.0)
        // = 64.0 / 12.0 = 5.333... GJ/s average, already
        // above the 5.0 GJ/s peak, so no equilibrium
        // exists and the event simulation depletes at the
        // failing activation, about 234 s.
        let fit = fitting(
            587,
            vec![
                item("LoSlot0", 1, 2048),
                item("MedSlot0", 1, 2049),
                item("MedSlot1", 1, 1225),
                item("HiSlot0", 1, 2050),
                item("HiSlot1", 1, 2050),
                item("RigSlot0", 1, 1535),
                item("SubSystemSlot0", 1, 28270),
                item("DroneBay", 5, 2456),
                item("FighterBay", 2, 2457),
                item("Cargo", 500, 34),
                item("Cargo", 200, 636),
                item("Invalid", 2, 35),
            ],
        );
        let result = fitting_cap_stability(&fit, &catalogue);
        assert_eq!(result.counted_modules, 2);
        // Excluded slot rows (units; all quantity 1):
        // Damage Control II 2048 (absent 6), the two
        // non-module slot rows 2049/1225 (absent 6), the
        // catalogue-absent rig row 1535, and the subsystem-
        // flagged cat-18 drone 28270 (absent 6). Drones,
        // fighters, and cargo never count or exclude.
        assert_eq!(result.excluded_modules, 5);
        assert_close(use_of(&result, "brawler use"), 64.0 / 12.0, "brawler use");
        assert_close(peak_of(&result, "brawler peak"), 5.0, "brawler peak");
        assert_eq!(depletes_seconds_of(&result), 234.0);
    }

    #[test]
    fn mission_runner_is_stable_at_100_with_excluded_count() {
        let catalogue = bundled();
        // Fitting 2: no counted drains → stable at 100%
        // with 0.0 GJ/s, even though the Damage Control II
        // and blueprint rows are excluded — the excluded
        // count is what keeps the line honest.
        let fit = fitting(
            587,
            vec![
                item("HiSlot0", 1, 2048),
                item("LoSlot0", 1, 2049),
                item("DroneBay", 3, 2456),
                item("Cargo", 10, 37),
            ],
        );
        let result = fitting_cap_stability(&fit, &catalogue);
        assert_close(stable_percent_of(&result), 100.0, "mission percent");
        assert_close(use_of(&result, "mission use"), 0.0, "mission use");
        assert_close(peak_of(&result, "mission peak"), 5.0, "mission peak");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 2);
    }

    #[test]
    fn demo_runner_settles_at_pinned_percent() {
        let catalogue = bundled();
        // Fitting 10: 1× type 2050 → 32.0 / 12.0
        // = 2.666... GJ/s against the 6.25 GJ/s peak; the
        // hand-replication of section 2 settles at about
        // 77%; the port's exact literal is pinned.
        let fit = fitting(
            597,
            vec![
                item("LoSlot0", 1, 2048),
                item("HiSlot0", 1, 2050),
                item("MedSlot0", 1, 1225),
                item("DroneBay", 3, 2456),
                item("Cargo", 20, 36),
            ],
        );
        let result = fitting_cap_stability(&fit, &catalogue);
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 2);
        assert_close(use_of(&result, "runner use"), 32.0 / 12.0, "runner use");
        assert_close(peak_of(&result, "runner peak"), 6.25, "runner peak");
        assert_close(
            stable_percent_of(&result),
            76.95496917307892,
            "runner percent",
        );
    }

    #[test]
    fn eft_oracle_matches_via_synthesis() {
        // The `resources.rs` sample-EFT oracle through
        // `to_character_fitting()`: 1183 (40.0/6.0
        // = 6.666...) + 438 (22.0/10.0 = 2.2) + 448
        // (6.0/5.0 = 1.2) + 3× 2889 (6 = 0.0, known zero)
        // = 10.066... GJ/s vs the Rifter 5.0 GJ/s peak →
        // depletes at about 36 s.
        let sample = concat!(
            "[Rifter, Sample Brawler]\n",
            "Damage Control II\n",
            "Small Armor Repairer II\n",
            "\n",
            "1MN Afterburner II\n",
            "Warp Scrambler II\n",
            "\n",
            "200mm AutoCannon II, Republic Fleet EMP S\n",
            "200mm AutoCannon II\n",
            "200mm AutoCannon II\n",
            "\n",
            "Small Projectile Burst Aerator I\n",
            "[Empty Rig slot]\n",
            "\n",
            "Hobgoblin II x2\n",
            "\n",
            "EMP S x200\n",
            "Nanite Repair Paste x8"
        );
        let catalogue = bundled();
        let synth = match parse_eft(sample, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("sample EFT must import: {fatal:?}"),
        };
        let result = fitting_cap_stability(&synth, &catalogue);
        assert_eq!(result.counted_modules, 3);
        // Damage Control II 2048 and the rig 31668 (rig
        // flags are slot rows, unlike the resources
        // consuming sections); the empty-rig marker
        // creates no item.
        assert_eq!(result.excluded_modules, 2);
        assert_close(
            use_of(&result, "eft use"),
            40.0 / 6.0 + 22.0 / 10.0 + 6.0 / 5.0,
            "eft use",
        );
        assert_close(peak_of(&result, "eft peak"), 5.0, "eft peak");
        assert_eq!(depletes_seconds_of(&result), 36.0);
    }

    fn fixture_bonused_catalogue() -> FittingTypes {
        // Extends the shipped fixture (hull 42: 250.0 GJ /
        // 125000.0 ms; drain 112: 100.0 GJ / 11000.0 ms) with
        // two fixture carriers in the shipped triple shape
        // for Oracle 7. Existing rows 101-112 are not edited.
        FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},
                {"typeId":101,"typeName":"73-Cycle Drain","categoryId":7,"slotEffects":[13],"capacitorNeed":32.0,"duration":12000.0},
                {"typeId":112,"typeName":"LX Energy Neutralizer","categoryId":7,"slotEffects":[13],"capacitorNeed":100.0,"duration":11000.0},
                {"typeId":201,"typeName":"Fixture Battery","categoryId":7,"slotEffects":[13],"capacitorCapacityModifiers":[[482,2,150.0]]},
                {"typeId":202,"typeName":"Fixture Recharger","categoryId":7,"slotEffects":[13],"capacitorRechargeModifiers":[[55,4,0.8]]}]}"#,
        )
        .expect("fixture catalogue parses")
    }

    // --- Bonused capacitor oracles (docs/cap-bonuses-design.md section 8)

    #[test]
    fn oracle1_capacity_flat_add() {
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![item("HiSlot0", 1, 2050), item("MedSlot0", 1, 3488)],
        );
        let base = fitting_cap_stability(&fit, &catalogue);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        // Helper pins: capacity 250+150=400, recharge 125000 ms.
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[0], Some(400.0));
        assert_eq!(helper.values[1], Some(125000.0));
        assert_eq!(helper.excluded_modules, 0);
        assert_eq!(helper.capacitor_capacity_unapplied_modules, 0);
        assert_eq!(helper.capacitor_recharge_unapplied_modules, 0);
        // Peak 2.5*400/125 = 8.0, Stable 82.185... (base 70.338...)
        assert_close(peak_of_bonused(&bonused, "o1 peak"), 8.0, "o1 peak");
        assert_close(
            stable_percent_of_bonused(&bonused),
            82.18512646407277,
            "o1 percent",
        );
        assert_close(
            stable_percent_of(&base),
            70.3386537337493,
            "o1 base percent",
        );
        assert_close(use_of_bonused(&bonused, "o1 use"), 32.0 / 12.0, "o1 use");
        assert_eq!(bonused.counted_modules, 1);
        assert_eq!(bonused.excluded_modules, 1);
        assert_eq!(bonused.bonus_excluded_modules, 0);
        assert_eq!(bonused.capacitor_capacity_unapplied_modules, 0);
        assert_eq!(bonused.capacitor_recharge_unapplied_modules, 0);
        assert_eq!(base.counted_modules, 1);
        assert_eq!(base.excluded_modules, 1);
    }

    #[test]
    fn oracle2_recharge_multiplier_duration_semantics() {
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![item("HiSlot0", 1, 2050), item("MedSlot0", 1, 2032)],
        );
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[0], Some(250.0));
        assert_eq!(helper.values[1], Some(100000.0));
        assert_close(peak_of_bonused(&bonused, "o2 peak"), 6.25, "o2 peak");
        assert_close(
            stable_percent_of_bonused(&bonused),
            76.58610664009886,
            "o2 percent",
        );
        assert_eq!(bonused.counted_modules, 1);
        assert_eq!(bonused.excluded_modules, 1);
    }

    #[test]
    fn oracle3_both_dimensions_together() {
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![
                item("HiSlot0", 1, 2050),
                item("MedSlot0", 1, 3488),
                item("MedSlot1", 1, 2032),
            ],
        );
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_close(peak_of_bonused(&bonused, "o3 peak"), 10.0, "o3 peak");
        assert_close(
            stable_percent_of_bonused(&bonused),
            85.7658359519556,
            "o3 percent",
        );
        assert_eq!(bonused.excluded_modules, 2);
    }

    #[test]
    fn oracle4_percents_sign_included() {
        let catalogue = bundled();
        // (a) Small Capacitor Control Circuit I -15%
        let fit = fitting(587, vec![item("RigSlot0", 1, 31370)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[1], Some(106250.0));
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_close(
            peak_of_bonused(&bonused, "o4a peak"),
            5.882352941176471,
            "o4a peak",
        );
        assert_close(stable_percent_of_bonused(&bonused), 100.0, "o4a percent");
        // (b) Large Semiconductor Memory Cell I +15%
        let fit = fitting(587, vec![item("RigSlot0", 1, 25954)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[0], Some(287.5));
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_close(peak_of_bonused(&bonused, "o4b peak"), 5.75, "o4b peak");
        // (c) Punisher + Large Cap Battery I
        let fit = fitting(597, vec![item("MedSlot0", 1, 2020)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[0], Some(1700.0));
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_close(peak_of_bonused(&bonused, "o4c peak"), 26.5625, "o4c peak");
    }

    #[test]
    fn oracle5_adds_before_percent_no_stacking_penalty() {
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![item("MedSlot0", 1, 3488), item("RigSlot0", 1, 25954)],
        );
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_close(helper.values[0].expect("Some"), 460.0, "o5a capacity");
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_close(peak_of_bonused(&bonused, "o5a peak"), 9.2, "o5a peak");
        let fit = fitting(
            587,
            vec![item("RigSlot0", 1, 31370), item("RigSlot1", 1, 31370)],
        );
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_close(helper.values[1].expect("Some"), 90312.5, "o5b recharge");
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_close(
            peak_of_bonused(&bonused, "o5b peak"),
            2.5 * 250.0 / 90.3125,
            "o5b peak",
        );
        let fit = fitting(
            587,
            vec![item("RigSlot0", 1, 25954), item("RigSlot1", 1, 25954)],
        );
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_close(helper.values[0].expect("Some"), 330.625, "o5c capacity");
        let stacked = fitting(587, vec![item("RigSlot0", 2, 31370)]);
        let one = bonused_capacitor(&stacked, &catalogue).expect("stacked");
        assert_close(one.values[1].expect("Some"), 90312.5, "stacked recharge");
    }

    #[test]
    fn oracle6_shrink_slow_and_relay_per_dimension() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 1246)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[0], Some(200.0));
        assert_eq!(helper.values[1], Some(80000.0));
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_close(peak_of_bonused(&bonused, "o6a peak"), 6.25, "o6a peak");
        let fit = fitting(587, vec![item("LoSlot0", 1, 1541)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[0], Some(262.5));
        assert_eq!(helper.values[1], Some(114375.0));
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_close(
            peak_of_bonused(&bonused, "o6b peak"),
            5.737704918032787,
            "o6b peak",
        );
        // Relay pin: capacity stays 250.0, recharge 100.0s,
        // capacity unapplied 1, recharge 0
        let fit = fitting(587, vec![item("LoSlot0", 1, 1445)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[0], Some(250.0));
        assert_eq!(helper.values[1], Some(100000.0));
        assert_eq!(helper.capacitor_capacity_unapplied_modules, 1);
        assert_eq!(helper.capacitor_recharge_unapplied_modules, 0);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_close(peak_of_bonused(&bonused, "o6c peak"), 6.25, "o6c peak");
        assert_eq!(bonused.capacitor_capacity_unapplied_modules, 1);
        assert_eq!(bonused.capacitor_recharge_unapplied_modules, 0);
        let fit = fitting(587, vec![item("LoSlot0", 2, 1445)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.capacitor_capacity_unapplied_modules, 2);
        assert_eq!(helper.capacitor_recharge_unapplied_modules, 0);
        assert_eq!(helper.values[0], Some(250.0));
    }

    #[test]
    fn oracle7_fixture_depletes_to_stable() {
        let catalogue = fixture_bonused_catalogue();
        let fit = fitting(42, vec![item("HiSlot0", 1, 112)]);
        let base = fitting_cap_stability(&fit, &catalogue);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_eq!(depletes_seconds_of(&base), 33.0);
        assert_eq!(depletes_seconds_of_bonused(&bonused), 33.0);
        let fit = fitting(42, vec![item("HiSlot0", 1, 112), item("MedSlot0", 1, 202)]);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_eq!(depletes_seconds_of_bonused(&bonused), 44.0);
        let fit = fitting(
            42,
            vec![
                item("HiSlot0", 1, 112),
                item("MedSlot0", 1, 201),
                item("MedSlot1", 1, 202),
            ],
        );
        let base = fitting_cap_stability(&fit, &catalogue);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_eq!(depletes_seconds_of(&base), 33.0);
        assert_close(
            stable_percent_of_bonused(&bonused),
            40.73402144558326,
            "o7 stable",
        );
    }

    #[test]
    fn empty_equals_base_exactly() {
        let catalogue = bundled();
        // hull-only Rifter and Punisher
        for ship in [587, 597] {
            let fit = fitting(ship, vec![]);
            let base = fitting_cap_stability(&fit, &catalogue);
            let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
            assert_eq!(bonused.outcome, base.outcome);
            assert_eq!(bonused.total_use_per_sec, base.total_use_per_sec);
            assert_eq!(bonused.peak_recharge_per_sec, base.peak_recharge_per_sec);
            assert_eq!(bonused.counted_modules, base.counted_modules);
            assert_eq!(bonused.excluded_modules, base.excluded_modules);
            assert_eq!(bonused.bonus_excluded_modules, 0);
            assert_eq!(bonused.capacitor_capacity_unapplied_modules, 0);
            assert_eq!(bonused.capacitor_recharge_unapplied_modules, 0);
        }
        // only non-counted items
        let fit = fitting(
            587,
            vec![
                item("Cargo", 1, 2048),
                item("DroneBay", 1, 2048),
                item("HiSlot0", 0, 2048),
                item("HiSlot0", 1, 0),
                item("HiSlot0", 1, -1),
            ],
        );
        let base = fitting_cap_stability(&fit, &catalogue);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_eq!(bonused.outcome, base.outcome);
        assert_eq!(bonused.total_use_per_sec, base.total_use_per_sec);
        assert_eq!(bonused.peak_recharge_per_sec, base.peak_recharge_per_sec);
        // counted non-carrier
        let fit = fitting(587, vec![item("LoSlot0", 1, 2048)]);
        let base = fitting_cap_stability(&fit, &catalogue);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_eq!(bonused.outcome, base.outcome);
        assert_eq!(bonused.peak_recharge_per_sec, base.peak_recharge_per_sec);
        // identity carrier 1353
        let fit = fitting(587, vec![item("LoSlot0", 1, 1353)]);
        let base = fitting_cap_stability(&fit, &catalogue);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_eq!(bonused.outcome, base.outcome);
        assert_eq!(bonused.total_use_per_sec, base.total_use_per_sec);
        assert_eq!(bonused.peak_recharge_per_sec, base.peak_recharge_per_sec);
        assert_eq!(bonused.capacitor_capacity_unapplied_modules, 0);
        assert_eq!(bonused.capacitor_recharge_unapplied_modules, 0);
    }

    #[test]
    fn demo_fittings_empty_equals_base() {
        let catalogue = bundled();
        // Demo Brawler: 2048/2049/1225/2050/2050/1535/28270
        let brawler = fitting(
            587,
            vec![
                item("LoSlot0", 1, 2048),
                item("LoSlot1", 1, 2049),
                item("HiSlot0", 1, 1225),
                item("HiSlot1", 1, 2050),
                item("HiSlot2", 1, 2050),
                item("MedSlot0", 1, 1535),
                item("RigSlot0", 1, 28270),
            ],
        );
        let base = fitting_cap_stability(&brawler, &catalogue);
        let bonused = fitting_cap_stability_with_module_bonuses(&brawler, &catalogue);
        assert_eq!(depletes_seconds_of(&base), 234.0);
        assert_eq!(depletes_seconds_of_bonused(&bonused), 234.0);
        assert_eq!(bonused.bonus_excluded_modules, 1);
        assert_eq!(base.excluded_modules, 5);
        assert_eq!(bonused.excluded_modules, 5);
        assert_eq!(bonused.capacitor_capacity_unapplied_modules, 0);
        assert_eq!(bonused.capacitor_recharge_unapplied_modules, 0);
        // Demo Runner: 76.95496917307892%
        let runner = fitting(
            597,
            vec![
                item("LoSlot0", 1, 2048),
                item("HiSlot0", 1, 2050),
                item("MedSlot0", 1, 1225),
            ],
        );
        let base = fitting_cap_stability(&runner, &catalogue);
        let bonused = fitting_cap_stability_with_module_bonuses(&runner, &catalogue);
        assert_close(stable_percent_of(&base), 76.95496917307892, "runner base");
        assert_close(
            stable_percent_of_bonused(&bonused),
            76.95496917307892,
            "runner bonused",
        );
        assert_eq!(bonused.bonus_excluded_modules, 0);
        // EFT sample via synthesis: 36.0 s
        let sample = concat!(
            "[Rifter, Sample Brawler]\n",
            "Damage Control II\n",
            "Small Armor Repairer II\n",
            "\n",
            "1MN Afterburner II\n",
            "Warp Scrambler II\n",
            "\n",
            "200mm AutoCannon II, Republic Fleet EMP S\n",
            "200mm AutoCannon II\n",
            "200mm AutoCannon II\n",
            "\n",
            "Small Projectile Burst Aerator I\n",
            "[Empty Rig slot]\n",
            "\n",
            "Hobgoblin II x2\n",
            "\n",
            "EMP S x200\n",
            "Nanite Repair Paste x8"
        );
        let synth = match parse_eft(sample, &catalogue) {
            EftImportOutcome::Imported(f) => f.to_character_fitting(),
            EftImportOutcome::Failed(f) => panic!("{f:?}"),
        };
        let base = fitting_cap_stability(&synth, &catalogue);
        let bonused = fitting_cap_stability_with_module_bonuses(&synth, &catalogue);
        assert_eq!(depletes_seconds_of(&base), 36.0);
        assert_eq!(depletes_seconds_of_bonused(&bonused), 36.0);
        assert_eq!(bonused.bonus_excluded_modules, 0);
    }

    #[test]
    fn shared_count_equalities() {
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![item("HiSlot0", 1, 2050), item("MedSlot0", 1, 3488)],
        );
        let base = fitting_cap_stability(&fit, &catalogue);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_eq!(bonused.counted_modules, base.counted_modules);
        assert_eq!(bonused.excluded_modules, base.excluded_modules);
        // bonus_excluded equals resistances excluded where Available
        let fit = fitting(587, vec![item("LoSlot0", 1, 999999)]);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        let resistances = ship_resistances_with_module_bonuses(&fit, &catalogue);
        if let crate::fitting::ship_resistances::BonusedShipResistancesOutcome::Available(r) =
            resistances
        {
            assert_eq!(bonused.bonus_excluded_modules, r.excluded_modules);
        }
        // Hit-point unapplied does not bleed into capacitor counts
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},
                {"typeId":101,"typeName":"HP Only Unapplied","categoryId":7,"slotEffects":[13],"hitPointModifiers":[],"hitPointModifiersUnapplied":true}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting(42, vec![item("HiSlot0", 1, 101)]);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_eq!(bonused.capacitor_capacity_unapplied_modules, 0);
        assert_eq!(bonused.capacitor_recharge_unapplied_modules, 0);
    }

    #[test]
    fn partial_and_coupled_unavailable() {
        // capacity absent, recharge present
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"No Cap Hull","categoryId":6,"slotEffects":[],"rechargeRate":125000.0},
                {"typeId":101,"typeName":"Battery","categoryId":7,"slotEffects":[13],"capacitorCapacityModifiers":[[482,2,150.0]]},
                {"typeId":102,"typeName":"Recharger","categoryId":7,"slotEffects":[13],"capacitorRechargeModifiers":[[55,4,0.8]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 101), item("MedSlot1", 1, 102)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values, [None, Some(100000.0)]);
        assert_eq!(
            fitting_cap_stability_with_module_bonuses(&fit, &catalogue).outcome,
            CapStabilityOutcome::Unavailable
        );
        assert_eq!(
            fitting_cap_stability(&fit, &catalogue).outcome,
            CapStabilityOutcome::Unavailable
        );
        // mirror: recharge absent
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"No Recharge Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0},
                {"typeId":101,"typeName":"Battery","categoryId":7,"slotEffects":[13],"capacitorCapacityModifiers":[[482,2,150.0]]},
                {"typeId":102,"typeName":"Recharger","categoryId":7,"slotEffects":[13],"capacitorRechargeModifiers":[[55,4,0.8]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 101), item("MedSlot1", 1, 102)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values, [Some(400.0), None]);
        assert_eq!(
            fitting_cap_stability_with_module_bonuses(&fit, &catalogue).outcome,
            CapStabilityOutcome::Unavailable
        );
        // present 0.0 capacity with battery -> 150.0, bonused computes
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Zero Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":0.0,"rechargeRate":125000.0},
                {"typeId":101,"typeName":"Battery","categoryId":7,"slotEffects":[13],"capacitorCapacityModifiers":[[482,2,150.0]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 101)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[0], Some(150.0));
        // present 0.0 recharge -> helper Some(0.0), bonused Unavailable, base Unavailable
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Zero Recharge Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":0.0},
                {"typeId":102,"typeName":"Recharger","categoryId":7,"slotEffects":[13],"capacitorRechargeModifiers":[[55,4,0.8]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 102)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[1], Some(0.0));
        assert_eq!(
            fitting_cap_stability_with_module_bonuses(&fit, &catalogue).outcome,
            CapStabilityOutcome::Unavailable
        );
        assert_eq!(
            fitting_cap_stability(&fit, &catalogue).outcome,
            CapStabilityOutcome::Unavailable
        );
    }

    #[test]
    fn hostile_bounded() {
        let json = r#"{"types":[{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"capacitorRechargeModifiers":[[55,6,-100.0]]}]}"#;
        // recharge percent -100 -> helper Some(0.0), bonused Unavailable, base still computes
        let catalogue = FittingTypes::from_json(json).expect("fixture parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 101)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[1], Some(0.0));
        assert_eq!(
            fitting_cap_stability_with_module_bonuses(&fit, &catalogue).outcome,
            CapStabilityOutcome::Unavailable
        );
        // base still computes (hull 42 has usable base)
        let base_result = fitting_cap_stability(&fit, &catalogue);
        assert_ne!(
            base_result.outcome,
            CapStabilityOutcome::Unavailable,
            "base should still compute"
        );
        // -150 -> helper None
        let json2 = r#"{"types":[{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"capacitorRechargeModifiers":[[55,6,-150.0]]}]}"#;
        let catalogue = FittingTypes::from_json(json2).expect("fixture parses");
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[1], None);
        // mul -0.8 -> None
        let json3 = r#"{"types":[{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"capacitorRechargeModifiers":[[55,4,-0.8]]}]}"#;
        let catalogue = FittingTypes::from_json(json3).expect("fixture parses");
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[1], None);
        // i64::MAX quantities
        let fit_max = fitting(42, vec![item("MedSlot0", i64::MAX, 101)]);
        let json4 = r#"{"types":[{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"capacitorRechargeModifiers":[[55,6,-15.0]]}]}"#;
        let catalogue = FittingTypes::from_json(json4).expect("fixture parses");
        let helper = bonused_capacitor(&fit_max, &catalogue).expect("helper Some");
        // Percent factor at MAX underflows to a subnormal
        // stall residue, rejected as no data (design
        // section 8 hostile pin, reviewer claim 6).
        assert_eq!(helper.values[1], None);
        assert_eq!(
            fitting_cap_stability_with_module_bonuses(&fit_max, &catalogue).outcome,
            CapStabilityOutcome::Unavailable
        );
        let json5 = r#"{"types":[{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"capacitorCapacityModifiers":[[482,6,20.0]]}]}"#;
        let catalogue = FittingTypes::from_json(json5).expect("fixture parses");
        let fit_max = fitting(42, vec![item("RigSlot0", i64::MAX, 101)]);
        let helper = bonused_capacitor(&fit_max, &catalogue).expect("helper Some");
        assert_eq!(helper.values[0], None);
        let json6 = r#"{"types":[{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"capacitorRechargeModifiers":[[55,4,0.8]]}]}"#;
        let catalogue = FittingTypes::from_json(json6).expect("fixture parses");
        let fit_max = fitting(42, vec![item("MedSlot0", i64::MAX, 101)]);
        let helper = bonused_capacitor(&fit_max, &catalogue).expect("helper Some");
        assert_eq!(helper.values[1], None);
        assert_eq!(
            fitting_cap_stability_with_module_bonuses(&fit_max, &catalogue).outcome,
            CapStabilityOutcome::Unavailable
        );
        let json7 = r#"{"types":[{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"capacitorCapacityModifiers":[[482,2,150.0]]}]}"#;
        let catalogue = FittingTypes::from_json(json7).expect("fixture parses");
        let fit_max = fitting(42, vec![item("MedSlot0", i64::MAX, 101)]);
        let helper = bonused_capacitor(&fit_max, &catalogue).expect("helper Some");
        // capacity is finite 250 + 150*(MAX as f64)
        assert!(helper.values[0].unwrap().is_finite());
        // percent -100 on 482 -> Some(0.0), Unavailable
        let json8 = r#"{"types":[{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"capacitorCapacityModifiers":[[482,6,-100.0]]}]}"#;
        let catalogue = FittingTypes::from_json(json8).expect("fixture parses");
        let fit = fitting(42, vec![item("RigSlot0", 1, 101)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[0], Some(0.0));
        assert_eq!(
            fitting_cap_stability_with_module_bonuses(&fit, &catalogue).outcome,
            CapStabilityOutcome::Unavailable
        );
    }

    #[test]
    fn runtime_guard_counts_and_base_independence() {
        // marked-unapplied with applicable entry same family
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},
                {"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[13],"capacitorCapacityModifiers":[[482,7,150.0],[55,4,0.8]],"capacitorCapacityModifiersUnapplied":true,"capacitorRechargeModifiers":[[999,4,0.8],[55,4,0.8]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 101)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        // capacity bad entry counts capacity unapplied, recharge wrong id counts recharge unapplied
        assert_eq!(helper.capacitor_capacity_unapplied_modules, 1);
        assert_eq!(helper.capacitor_recharge_unapplied_modules, 1);
        // recharge applicable still applied
        assert_eq!(helper.values[1], Some(100000.0));
        // once per item per family, not twice
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"capacitorCapacity":250.0,"rechargeRate":125000.0},
                {"typeId":101,"typeName":"Bad2","categoryId":7,"slotEffects":[13],"capacitorCapacityModifiers":[[482,0,150.0],[482,3,150.0]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 101)]);
        let helper = bonused_capacitor(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.capacitor_capacity_unapplied_modules, 1);
        // base independence: cap carriers don't change base
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![item("MedSlot0", 1, 3488), item("LoSlot0", 1, 2032)],
        );
        let base = fitting_cap_stability(&fit, &catalogue);
        let bonused = fitting_cap_stability_with_module_bonuses(&fit, &catalogue);
        assert_ne!(bonused.peak_recharge_per_sec, base.peak_recharge_per_sec);
        // shield peak stays base with capacitor fit
        use crate::fitting::ship_peak_recharge::ship_base_peak_recharge;
        use crate::fitting::ship_stats::{ship_base_stats, ShipBaseStatsOutcome};
        let stats = match ship_base_stats(&fit, &catalogue) {
            ShipBaseStatsOutcome::Available(s) => s,
            ShipBaseStatsOutcome::Unavailable => panic!("stats available"),
        };
        let peaks = ship_base_peak_recharge(&stats);
        assert_close(peaks.shield_hp_per_sec.unwrap(), 1.8, "shield stays base");
    }

    #[test]
    fn unavailable_shapes() {
        let catalogue = fixture_catalogue();
        for ship in [999999, 101, 0, -1] {
            let result = fitting_cap_stability_with_module_bonuses(
                &fitting(ship, vec![item("HiSlot0", 1, 101)]),
                &catalogue,
            );
            assert_eq!(result.outcome, CapStabilityOutcome::Unavailable);
            assert_eq!(result.total_use_per_sec, None);
            assert_eq!(result.peak_recharge_per_sec, None);
            assert_eq!(result.capacitor_capacity_unapplied_modules, 0);
            assert_eq!(result.capacitor_recharge_unapplied_modules, 0);
            // helper None exactly on ship gate
            assert!(bonused_capacitor(&fitting(ship, vec![]), &catalogue).is_none());
        }
    }

    #[test]
    fn high_count_staggered_and_tiny_cap_need_drains_terminate_cleanly() {
        // When count > duration_ms (e.g. 2500 units at 2000ms), flooring
        // duration/count used to produce 0.0ms and spin in place (Bug #9).
        let heavy = run_simulator(
            100_000.0,
            125_000.0,
            &[CapDrain {
                cap_need: 0.5243,
                duration_ms: 2000.0,
                count: 2500,
            }],
        );
        assert!(heavy.seconds_to_empty.is_finite());
        if !heavy.is_stable {
            assert!(
                heavy.seconds_to_empty > 0.0,
                "depletion time must advance past 0s, got {}",
                heavy.seconds_to_empty
            );
        }

        // Sub-ULP cap_need must not spin forever at t = 0.0 even with count > duration_ms.
        let sub_ulp = run_simulator(
            1_000_000.0,
            100_000.0,
            &[CapDrain {
                cap_need: 1e-18,
                duration_ms: 1500.0,
                count: 2000,
            }],
        );
        assert!(sub_ulp.is_stable);
        assert!(sub_ulp.stable_percent.is_finite());
    }
}
