//! Pure ship resistances calculation over the bundled catalogue.
//!
//! [`ship_resistances`] reads the hull's base damage resistance
//! percentages for shield, armor, and hull against EM, thermal,
//! kinetic, and explosive damage for one [`CharacterFitting`]
//! from base (unmodified) dogma resonances only. Each percentage
//! is `(1.0 - resonance) * 100.0` for one catalogue resonance
//! (unit 108 "Inverse Absolute Percent": "Used for resistance.
//! 0.0 = 100% 1.0 = 0%"). No modifier of any kind is applied:
//! fitted modules, rigs, subsystems, skills, implants, and ship
//! bonuses contribute nothing, so the values describe the bare
//! hull and can differ from EVE. See
//! `docs/ship-resistances-design.md`.
//!
//! [`ship_resistances_with_module_bonuses`] applies the
//! grounded fitted-item resistance modifiers of
//! `docs/resistance-bonuses-design.md` section 2 on top of the
//! same base resonances: operator-0 (postMul) operands
//! multiply unpenalized, operator-6 (postPercent) operands
//! chain with the Flutter stacking penalty, mul first. Ship
//! bonuses, subsystems, skills, implants, and everything
//! else the design defers contribute nothing.
//!
//! The crate-internal `bonused_hit_points` helper is the
//! hit-point sibling serving the EHP numerator under
//! `docs/hp-bonuses-design.md` section 4 and, after
//! `docs/shield-recharge-bonuses-design.md`, the shield
//! layer for the bonused shield peak under that document:
//! the same counted-item scan and bounded run arithmetic
//! produce bonused shield/armor/hull hit points for
//! `ship_ehp_with_module_bonuses` and
//! `ship_shield_peak_recharge_with_module_bonuses`.
//!
//! The crate-internal `bonused_capacitor` helper is the
//! capacitor sibling serving the bonused capacitor block
//! under `docs/cap-bonuses-design.md` section 4: the same
//! counted-item scan and bounded run arithmetic produce
//! bonused capacity (GJ) and recharge duration (raw
//! milliseconds) for `fitting_cap_stability_with_module_bonuses`
//! only.
//!
//! The crate-internal `bonused_shield_recharge_duration`
//! helper is the shield recharge sibling serving the
//! bonused shield peak under
//! `docs/shield-recharge-bonuses-design.md` section 4: the
//! same counted-item scan and bounded run arithmetic
//! produce the bonused shield recharge duration in raw
//! milliseconds for
//! `ship_shield_peak_recharge_with_module_bonuses` only.
//!
//! The crate-internal `bonused_outputs` helper is the
//! output sibling serving fitting resources under
//! `docs/output-bonuses-design.md` section 4: the same
//! counted-item scan and bounded run arithmetic produce
//! bonused CPU output (tf) and power grid output (MW),
//! composed with the two trained output-skill percents when
//! levels are supplied, for
//! `crate::fitting::resources::fitting_resources_with_skills`
//! only.
//!
//! The crate-internal `bonused_nav_targeting` helper is the
//! navigation and targeting sibling serving
//! `ship_nav_targeting_with_module_bonuses` under
//! `docs/nav-targeting-bonuses-design.md` section 4: the
//! same counted-item scan and bounded run arithmetic produce
//! bonused navigation and targeting values in raw catalogue
//! units plus the counts the caller must disclose beside any
//! number derived from them, for the bonused navigation and
//! targeting block only.
//!
//! The module is pure computation over the bundled catalogue — no
//! egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] and [`FittingTypes`], the same
//! dependencies `ship_stats.rs` takes. It logs nothing: it runs
//! at render cadence, so per-frame `[FITTING]` logging would spam
//! the log; the catalogue load already logs counts once.

use crate::esi::models::CharacterFitting;
use crate::names::fitting_types::FittingTypes;

/// One layer's base damage resistance percentages, in
/// EM/thermal/kinetic/explosive order. Each field is
/// `(1.0 - resonance) * 100.0` for a usable catalogue
/// resonance; `None` means no data for that damage type:
/// the caller omits it, never renders a zero. A present
/// resonance of 1.0 is `Some(0.0)`; a resonance above 1.0
/// is a true negative percentage.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ResistLayer {
    pub em: Option<f64>,
    pub thermal: Option<f64>,
    pub kinetic: Option<f64>,
    pub explosive: Option<f64>,
}

/// One hull's base damage resistances, by layer.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ShipResistances {
    pub shield: ResistLayer,
    pub armor: ResistLayer,
    pub hull: ResistLayer,
}

/// Base resistances outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ShipResistancesOutcome {
    Available(ShipResistances),
    /// The catalogue has no usable resistance data for this
    /// fitting's ship, so no honest numbers exist.
    Unavailable,
}

/// Convert one catalogue resonance to its resistance
/// percentage with the locked formula `(1.0 - resonance) *
/// 100.0` (`dogmaUnits.jsonl` unit 108; `dogma_engine.dart` at
/// `ed698d3` lines 856-858 identical). A resonance is usable
/// only when present, finite, and non-negative — there is no
/// upper bound, so a resonance above 1 is a true negative
/// percentage, never clamped — and a non-finite percentage
/// result is no data (the `f64` overflow guard). Absent is no
/// data, never a silent zero.
fn resonance_to_percent(value: Option<f64>) -> Option<f64> {
    let resonance = value.filter(|v| v.is_finite() && *v >= 0.0)?;
    let percent = (1.0 - resonance) * 100.0;
    if percent.is_finite() {
        Some(percent)
    } else {
        None
    }
}

/// Base resistances for one fitting. The fitting's items are
/// never read, and availability is independent of
/// [`crate::fitting::resources::FittingResources`] and
/// [`crate::fitting::ship_stats::ShipBaseStats`]: this function
/// keys off the twelve resonance fields only.
pub fn ship_resistances(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> ShipResistancesOutcome {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        return ShipResistancesOutcome::Unavailable;
    };
    if ship.category_id != 6 {
        return ShipResistancesOutcome::Unavailable;
    }
    let resistances = ShipResistances {
        shield: ResistLayer {
            em: resonance_to_percent(ship.shield_em_resonance),
            thermal: resonance_to_percent(ship.shield_thermal_resonance),
            kinetic: resonance_to_percent(ship.shield_kinetic_resonance),
            explosive: resonance_to_percent(ship.shield_explosive_resonance),
        },
        armor: ResistLayer {
            em: resonance_to_percent(ship.armor_em_resonance),
            thermal: resonance_to_percent(ship.armor_thermal_resonance),
            kinetic: resonance_to_percent(ship.armor_kinetic_resonance),
            explosive: resonance_to_percent(ship.armor_explosive_resonance),
        },
        hull: ResistLayer {
            em: resonance_to_percent(ship.hull_em_resonance),
            thermal: resonance_to_percent(ship.hull_thermal_resonance),
            kinetic: resonance_to_percent(ship.hull_kinetic_resonance),
            explosive: resonance_to_percent(ship.hull_explosive_resonance),
        },
    };
    if resistances.shield.em.is_none()
        && resistances.shield.thermal.is_none()
        && resistances.shield.kinetic.is_none()
        && resistances.shield.explosive.is_none()
        && resistances.armor.em.is_none()
        && resistances.armor.thermal.is_none()
        && resistances.armor.kinetic.is_none()
        && resistances.armor.explosive.is_none()
        && resistances.hull.em.is_none()
        && resistances.hull.thermal.is_none()
        && resistances.hull.kinetic.is_none()
        && resistances.hull.explosive.is_none()
    {
        return ShipResistancesOutcome::Unavailable;
    }
    ShipResistancesOutcome::Available(resistances)
}

/// Bonused resistances plus the fitted-module counts the
/// caller must disclose beside them.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BonusedShipResistances {
    pub resistances: ShipResistances,
    /// Counted fitted rows with no catalogue row at all, so
    /// no resistance bonus can be proven or disproven for
    /// them. Counted in quantity units, never silently zero.
    pub excluded_modules: usize,
    /// Counted fitted rows the catalogue marks as resistance
    /// carriers whose bonus cannot be applied from the
    /// bundled data (unsupported operator with a present
    /// operand, or every operand absent), in quantity units.
    /// Their applicable entries, if any, are still applied.
    pub unapplied_modules: usize,
}

/// Bonused resistances outcome for one fitting.
#[allow(clippy::large_enum_variant)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BonusedShipResistancesOutcome {
    Available(BonusedShipResistances),
    /// The catalogue has no usable resistance data for this
    /// fitting's ship, so no honest numbers exist.
    Unavailable,
}

/// Stacking penalty for the n-th (1-indexed) percent modifier
/// on one resonance: 1.0 for n <= 1, else
/// exp(-(((n - 1) / 2.67)²)). Provenance: Flutter
/// `getStackingPenalty` at `ed698d3`.
pub fn resistance_stacking_penalty(n: usize) -> f64 {
    if n <= 1 {
        1.0
    } else {
        let scaled = (n - 1) as f64 / 2.67;
        (-(scaled * scaled)).exp()
    }
}

/// Catalogue resonance attribute ids in the locked display
/// order (shield, armor, hull; EM, thermal, kinetic,
/// explosive within a layer). Position is the accumulator
/// index used below.
const RESONANCE_ORDER: [i64; 12] = [271, 274, 273, 272, 267, 270, 269, 268, 113, 110, 109, 111];

/// Catalogue hit point attribute ids in the locked order
/// (shield 263, armor 265, hull 9). Position is the
/// accumulator index used below.
const HIT_POINT_ORDER: [i64; 3] = [263, 265, 9];

/// Catalogue capacitor attribute ids in the locked order
/// (capacitorCapacity 482, rechargeRate 55). Position is
/// the accumulator index used below.
const CAPACITOR_ORDER: [i64; 2] = [482, 55];

/// The single shield recharge modified attribute
/// (dogma 479 `shieldRechargeRate`, a millisecond
/// duration, lower is faster). With one attribute there
/// is no accumulator index, so the run lists below are
/// scalar `Vec<(f64, u64)>` triples, not arrays.
const SHIELD_RECHARGE_MODIFIED_ATTRIBUTE_ID: i64 = 479;

/// Catalogue output attribute ids in the locked order
/// (cpuOutput 48, powerOutput 11). Position is the
/// accumulator index used below.
const OUTPUT_ORDER: [i64; 2] = [48, 11];

/// Catalogue navigation and targeting attribute ids in
/// the locked display order (600, 70, 4, 552, 76, 564,
/// 208, 209, 210, 211, 192). Position is the accumulator
/// index used below.
const NAV_TARGETING_ORDER: [i64; 11] = [600, 70, 4, 552, 76, 564, 208, 209, 210, 211, 192];

/// The twelve base resonances of a ship row in
/// `RESONANCE_ORDER` position.
fn base_resonances(ship: &crate::names::fitting_types::FittingType) -> [Option<f64>; 12] {
    [
        ship.shield_em_resonance,
        ship.shield_thermal_resonance,
        ship.shield_kinetic_resonance,
        ship.shield_explosive_resonance,
        ship.armor_em_resonance,
        ship.armor_thermal_resonance,
        ship.armor_kinetic_resonance,
        ship.armor_explosive_resonance,
        ship.hull_em_resonance,
        ship.hull_thermal_resonance,
        ship.hull_kinetic_resonance,
        ship.hull_explosive_resonance,
    ]
}

/// The three base hit points of a ship row in
/// `HIT_POINT_ORDER` position (shield, armor, hull).
fn base_hit_points(ship: &crate::names::fitting_types::FittingType) -> [Option<f64>; 3] {
    [ship.shield_capacity, ship.armor_hp, ship.hull_hp]
}

/// The two base capacitor values of a ship row in
/// `CAPACITOR_ORDER` position (capacity GJ, recharge raw
/// milliseconds).
fn base_capacitor(ship: &crate::names::fitting_types::FittingType) -> [Option<f64>; 2] {
    [ship.capacitor_capacity, ship.capacitor_recharge_rate]
}

/// The two base outputs of a ship row in `OUTPUT_ORDER`
/// position (CPU output tf, power grid output MW).
fn base_outputs(ship: &crate::names::fitting_types::FittingType) -> [Option<f64>; 2] {
    [ship.cpu_output, ship.power_output]
}

/// The eleven base navigation and targeting values of a
/// ship row in `NAV_TARGETING_ORDER` position, in raw
/// catalogue units (targeting range in metres, locked
/// targets still an `f64`): the wrapper converts.
fn base_nav_targeting(ship: &crate::names::fitting_types::FittingType) -> [Option<f64>; 11] {
    [
        ship.warp_speed_multiplier,
        ship.agility,
        ship.mass,
        ship.signature_radius,
        ship.max_target_range,
        ship.scan_resolution,
        ship.scan_radar_strength,
        ship.scan_ladar_strength,
        ship.scan_magnetometric_strength,
        ship.scan_gravimetric_strength,
        ship.max_locked_targets,
    ]
}

/// Defensive re-clamp for the output-skill levels: a
/// hand-built pair cannot exceed ×1.25.
fn clamp_output_level(level: i32) -> i32 {
    level.clamp(0, 5)
}

/// Fitted sections whose items commit to the ship's bonuses:
/// low/medium/high slots, rigs, subsystems. Charges, drones,
/// fighters, cargo, and every other flag never count (design
/// section 4).
fn counted_flag(flag: &str) -> bool {
    flag.starts_with("LoSlot")
        || flag.starts_with("MedSlot")
        || flag.starts_with("HiSlot")
        || flag.starts_with("RigSlot")
        || flag.starts_with("SubSystemSlot")
}

/// Product of one run of `count` multiplications by
/// `operand`, stopping once the running product is decided
/// (`0.0`, non-finite, or stalled). An operand of exactly 1.0
/// is the identity and contributes nothing. The stop is the
/// locked bounded-hostile-quantity arithmetic, not an
/// approximation: later factors cannot change the result.
fn mul_product(operand: f64, count: u64) -> f64 {
    if operand == 1.0 {
        return 1.0;
    }
    if operand == -1.0 {
        // Sign flips forever without stalling, reaching
        // 0.0, or going non-finite, so the loop below would
        // run `count` times; the product is decided by
        // parity alone.
        return if count.is_multiple_of(2) { 1.0 } else { -1.0 };
    }
    let mut product = 1.0;
    for _ in 0..count {
        let next = product * operand;
        if next == product {
            // Stall guard (covers 0.0 once reached): the next
            // multiplication cannot move the product.
            return product;
        }
        product = next;
        if product == 0.0 || !product.is_finite() {
            return product;
        }
    }
    product
}

/// Percent chain over sorted (value, count) runs: stable
/// sort by absolute value descending, penalty 1-indexed per
/// instance, stopping a run once the penalty underflows to
/// exactly `0.0` (every later factor is then exactly `1.0`).
fn percent_chain(runs: &mut [(f64, u64)]) -> f64 {
    runs.sort_by(|a, b| b.0.abs().total_cmp(&a.0.abs()));
    let mut factor = 1.0;
    let mut n: usize = 0;
    for (value, count) in runs.iter() {
        for _ in 0..*count {
            n += 1;
            let penalty = resistance_stacking_penalty(n);
            if penalty == 0.0 {
                return factor;
            }
            factor *= 1.0 + (value / 100.0) * penalty;
        }
    }
    factor
}

/// Bonused resonances in `RESONANCE_ORDER` position plus the
/// fitted-module counts the caller must disclose beside any
/// number derived from them.
pub(crate) struct BonusedResonances {
    pub resonances: [Option<f64>; 12],
    pub excluded_modules: usize,
    pub unapplied_modules: usize,
}

/// `None` only when the ship gate fails (`ship_type_id <= 0`,
/// no catalogue row, or the row is not category 6). Otherwise
/// `Some`, with each resonance `None` exactly where the base
/// resonance is absent, negative, or non-finite, or the
/// bonused product is negative or non-finite.
pub(crate) fn bonused_resonances(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> Option<BonusedResonances> {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let ship = ship_row?;
    if ship.category_id != 6 {
        return None;
    }
    let mut excluded_modules: usize = 0;
    let mut unapplied_modules: usize = 0;
    let mut mul_runs: [Vec<(f64, u64)>; 12] = Default::default();
    let mut percent_runs: [Vec<(f64, u64)>; 12] = Default::default();
    for item in &fitting.items {
        if item.type_id <= 0 {
            continue;
        }
        if item.quantity.max(0) <= 0 {
            continue;
        }
        if !counted_flag(&item.flag) {
            continue;
        }
        let units = usize::try_from(item.quantity).unwrap_or(0);
        let units_u64 = units as u64;
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            excluded_modules = excluded_modules.saturating_add(units);
            continue;
        };
        let mut counted_unapplied = false;
        if row.resistance_modifiers_unapplied {
            unapplied_modules = unapplied_modules.saturating_add(units);
            counted_unapplied = true;
        }
        let Some(modifiers) = &row.resistance_modifiers else {
            continue;
        };
        for modifier in modifiers {
            let Some(index) = RESONANCE_ORDER
                .iter()
                .position(|id| *id == modifier.modified_attribute_id)
            else {
                if !counted_unapplied {
                    unapplied_modules = unapplied_modules.saturating_add(units);
                    counted_unapplied = true;
                }
                continue;
            };
            if !modifier.operand.is_finite()
                || modifier.operand == 0.0
                || !matches!(modifier.operator, 0 | 6)
            {
                if !counted_unapplied {
                    unapplied_modules = unapplied_modules.saturating_add(units);
                    counted_unapplied = true;
                }
                continue;
            }
            let runs = if modifier.operator == 0 {
                &mut mul_runs[index]
            } else {
                &mut percent_runs[index]
            };
            if let Some((_, count)) = runs
                .iter_mut()
                .find(|(existing, _)| existing == &modifier.operand)
            {
                *count = count.saturating_add(units_u64);
            } else {
                runs.push((modifier.operand, units_u64));
            }
        }
    }
    let bases = base_resonances(ship);
    let mut resonances: [Option<f64>; 12] = [None; 12];
    for index in 0..12 {
        let Some(base) = bases[index].filter(|v| v.is_finite() && *v >= 0.0) else {
            continue;
        };
        let mut mul_total = 1.0;
        for (operand, count) in &mul_runs[index] {
            mul_total *= mul_product(*operand, *count);
        }
        let mut percent_runs_clone = percent_runs[index].clone();
        let chain = percent_chain(&mut percent_runs_clone);
        let bonused_resonance = base * mul_total * chain;
        resonances[index] = Some(bonused_resonance).filter(|v| v.is_finite() && *v >= 0.0);
    }
    Some(BonusedResonances {
        resonances,
        excluded_modules,
        unapplied_modules,
    })
}

/// Bonused resistances for one fitting
/// (`docs/resistance-bonuses-design.md` section 4). Never
/// panics; a catalogue row that violates the section 3
/// invariants at load is guarded here, never trusted.
pub fn ship_resistances_with_module_bonuses(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> BonusedShipResistancesOutcome {
    let Some(bonused) = bonused_resonances(fitting, catalogue) else {
        return BonusedShipResistancesOutcome::Unavailable;
    };
    let mut percents: [Option<f64>; 12] = [None; 12];
    for (slot, resonance) in percents.iter_mut().zip(bonused.resonances.iter().copied()) {
        *slot = resonance_to_percent(resonance);
    }
    if percents.iter().all(Option::is_none) {
        return BonusedShipResistancesOutcome::Unavailable;
    }
    let resistances = ShipResistances {
        shield: ResistLayer {
            em: percents[0],
            thermal: percents[1],
            kinetic: percents[2],
            explosive: percents[3],
        },
        armor: ResistLayer {
            em: percents[4],
            thermal: percents[5],
            kinetic: percents[6],
            explosive: percents[7],
        },
        hull: ResistLayer {
            em: percents[8],
            thermal: percents[9],
            kinetic: percents[10],
            explosive: percents[11],
        },
    };
    BonusedShipResistancesOutcome::Available(BonusedShipResistances {
        resistances,
        excluded_modules: bonused.excluded_modules,
        unapplied_modules: bonused.unapplied_modules,
    })
}

/// Bonused hit points per layer (shield, armor, hull) plus
/// the hit-point-dimension unapplied count the caller must
/// disclose beside any number derived from them.
pub(crate) struct BonusedHitPoints {
    pub hit_points: [Option<f64>; 3],
    pub hit_point_unapplied_modules: usize,
}

/// `None` only when the ship gate fails (`ship_type_id <= 0`,
/// no catalogue row, or the row is not category 6). Otherwise
/// `Some`, with each layer `None` exactly where the base hit
/// points are absent, negative, or non-finite, or the
/// bonused result is negative or non-finite.
pub(crate) fn bonused_hit_points(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> Option<BonusedHitPoints> {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let ship = ship_row?;
    if ship.category_id != 6 {
        return None;
    }
    let mut hit_point_unapplied_modules: usize = 0;
    let mut add_runs: [Vec<(f64, u64)>; 3] = Default::default();
    let mut mul_runs: [Vec<(f64, u64)>; 3] = Default::default();
    let mut percent_runs: [Vec<(f64, u64)>; 3] = Default::default();
    for item in &fitting.items {
        if item.type_id <= 0 {
            continue;
        }
        if item.quantity.max(0) <= 0 {
            continue;
        }
        if !counted_flag(&item.flag) {
            continue;
        }
        let units = usize::try_from(item.quantity).unwrap_or(0);
        let units_u64 = units as u64;
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            continue;
        };
        let mut counted_unapplied = false;
        if row.hit_point_modifiers_unapplied {
            hit_point_unapplied_modules = hit_point_unapplied_modules.saturating_add(units);
            counted_unapplied = true;
        }
        let Some(modifiers) = &row.hit_point_modifiers else {
            continue;
        };
        for modifier in modifiers {
            let Some(index) = HIT_POINT_ORDER
                .iter()
                .position(|id| *id == modifier.modified_attribute_id)
            else {
                if !counted_unapplied {
                    hit_point_unapplied_modules = hit_point_unapplied_modules.saturating_add(units);
                    counted_unapplied = true;
                }
                continue;
            };
            if !modifier.operand.is_finite()
                || modifier.operand == 0.0
                || !matches!(modifier.operator, 2 | 4 | 6)
            {
                if !counted_unapplied {
                    hit_point_unapplied_modules = hit_point_unapplied_modules.saturating_add(units);
                    counted_unapplied = true;
                }
                continue;
            }
            let runs = match modifier.operator {
                2 => &mut add_runs[index],
                4 => &mut mul_runs[index],
                _ => &mut percent_runs[index],
            };
            if let Some((_, count)) = runs
                .iter_mut()
                .find(|(existing, _)| existing == &modifier.operand)
            {
                *count = count.saturating_add(units_u64);
            } else {
                runs.push((modifier.operand, units_u64));
            }
        }
    }
    let bases = base_hit_points(ship);
    let mut hit_points: [Option<f64>; 3] = [None, None, None];
    for index in 0..3 {
        let Some(base) = bases[index].filter(|v| v.is_finite() && *v >= 0.0) else {
            continue;
        };
        let mut add_total = 0.0;
        for (operand, count) in &add_runs[index] {
            add_total += operand * (*count as f64);
        }
        let mut mul_total = 1.0;
        for (operand, count) in &mul_runs[index] {
            mul_total *= mul_product(*operand, *count);
        }
        let mut sorted_percent = percent_runs[index].clone();
        sorted_percent.sort_by(|a, b| b.0.abs().total_cmp(&a.0.abs()));
        let mut percent_total = 1.0;
        for (value, count) in &sorted_percent {
            percent_total *= mul_product(1.0 + value / 100.0, *count);
        }
        let bonused = (base + add_total) * mul_total * percent_total;
        hit_points[index] = Some(bonused).filter(|v| v.is_finite() && *v >= 0.0);
    }
    Some(BonusedHitPoints {
        hit_points,
        hit_point_unapplied_modules,
    })
}

/// Bonused capacitor capacity (GJ) and recharge duration
/// (milliseconds, the catalogue unit; lower is faster)
/// plus the fitted-module counts the caller must disclose
/// beside any number derived from them.
pub(crate) struct BonusedCapacitor {
    /// [capacity_gj, recharge_ms] in CAPACITOR_ORDER
    /// position, each `None` exactly where the base value
    /// is absent, negative, or non-finite, or the bonused
    /// result is negative or non-finite.
    pub values: [Option<f64>; 2],
    /// Counted fitted rows with no catalogue row at all,
    /// so no capacitor bonus can be proven or disproven
    /// for them, in quantity units. Same definition and
    /// source predicate as
    /// `BonusedResonances::excluded_modules` (pinned
    /// equal, design section 8).
    pub excluded_modules: usize,
    /// Capacity-dimension count: counted fitted rows the
    /// catalogue marks as capacity carriers whose bonus
    /// cannot be applied, in quantity units. Never summed
    /// with `capacitor_recharge_unapplied_modules`.
    pub capacitor_capacity_unapplied_modules: usize,
    /// Recharge-dimension count: same shape for the
    /// recharge family. Never summed with
    /// `capacitor_capacity_unapplied_modules`.
    pub capacitor_recharge_unapplied_modules: usize,
}

/// `None` only when the ship gate fails (`ship_type_id
/// <= 0`, no catalogue row, or the row is not category
/// 6). Otherwise `Some`, per-value `None` as documented
/// on `values`.
pub(crate) fn bonused_capacitor(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> Option<BonusedCapacitor> {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let ship = ship_row?;
    if ship.category_id != 6 {
        return None;
    }
    let mut excluded_modules: usize = 0;
    let mut capacitor_capacity_unapplied_modules: usize = 0;
    let mut capacitor_recharge_unapplied_modules: usize = 0;
    let mut add_runs: [Vec<(f64, u64)>; 2] = Default::default();
    let mut mul_runs: [Vec<(f64, u64)>; 2] = Default::default();
    let mut percent_runs: [Vec<(f64, u64)>; 2] = Default::default();
    for item in &fitting.items {
        if item.type_id <= 0 {
            continue;
        }
        if item.quantity.max(0) <= 0 {
            continue;
        }
        if !counted_flag(&item.flag) {
            continue;
        }
        let units = usize::try_from(item.quantity).unwrap_or(0);
        let units_u64 = units as u64;
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            excluded_modules = excluded_modules.saturating_add(units);
            continue;
        };
        // Capacity family (482)
        let mut counted_capacity_unapplied = false;
        if row.capacitor_capacity_modifiers_unapplied {
            capacitor_capacity_unapplied_modules =
                capacitor_capacity_unapplied_modules.saturating_add(units);
            counted_capacity_unapplied = true;
        }
        if let Some(modifiers) = &row.capacitor_capacity_modifiers {
            for modifier in modifiers {
                let Some(index) = CAPACITOR_ORDER
                    .iter()
                    .position(|id| *id == modifier.modified_attribute_id)
                else {
                    if !counted_capacity_unapplied {
                        capacitor_capacity_unapplied_modules =
                            capacitor_capacity_unapplied_modules.saturating_add(units);
                        counted_capacity_unapplied = true;
                    }
                    continue;
                };
                if index != 0 {
                    if !counted_capacity_unapplied {
                        capacitor_capacity_unapplied_modules =
                            capacitor_capacity_unapplied_modules.saturating_add(units);
                        counted_capacity_unapplied = true;
                    }
                    continue;
                }
                if !modifier.operand.is_finite()
                    || modifier.operand == 0.0
                    || !matches!(modifier.operator, 2 | 4 | 6)
                {
                    if !counted_capacity_unapplied {
                        capacitor_capacity_unapplied_modules =
                            capacitor_capacity_unapplied_modules.saturating_add(units);
                        counted_capacity_unapplied = true;
                    }
                    continue;
                }
                let runs = match modifier.operator {
                    2 => &mut add_runs[index],
                    4 => &mut mul_runs[index],
                    _ => &mut percent_runs[index],
                };
                if let Some((_, count)) = runs
                    .iter_mut()
                    .find(|(existing, _)| existing == &modifier.operand)
                {
                    *count = count.saturating_add(units_u64);
                } else {
                    runs.push((modifier.operand, units_u64));
                }
            }
        }
        // Recharge family (55)
        let mut counted_recharge_unapplied = false;
        if row.capacitor_recharge_modifiers_unapplied {
            capacitor_recharge_unapplied_modules =
                capacitor_recharge_unapplied_modules.saturating_add(units);
            counted_recharge_unapplied = true;
        }
        if let Some(modifiers) = &row.capacitor_recharge_modifiers {
            for modifier in modifiers {
                let Some(index) = CAPACITOR_ORDER
                    .iter()
                    .position(|id| *id == modifier.modified_attribute_id)
                else {
                    if !counted_recharge_unapplied {
                        capacitor_recharge_unapplied_modules =
                            capacitor_recharge_unapplied_modules.saturating_add(units);
                        counted_recharge_unapplied = true;
                    }
                    continue;
                };
                if index != 1 {
                    if !counted_recharge_unapplied {
                        capacitor_recharge_unapplied_modules =
                            capacitor_recharge_unapplied_modules.saturating_add(units);
                        counted_recharge_unapplied = true;
                    }
                    continue;
                }
                if !modifier.operand.is_finite()
                    || modifier.operand == 0.0
                    || !matches!(modifier.operator, 2 | 4 | 6)
                {
                    if !counted_recharge_unapplied {
                        capacitor_recharge_unapplied_modules =
                            capacitor_recharge_unapplied_modules.saturating_add(units);
                        counted_recharge_unapplied = true;
                    }
                    continue;
                }
                let runs = match modifier.operator {
                    2 => &mut add_runs[index],
                    4 => &mut mul_runs[index],
                    _ => &mut percent_runs[index],
                };
                if let Some((_, count)) = runs
                    .iter_mut()
                    .find(|(existing, _)| existing == &modifier.operand)
                {
                    *count = count.saturating_add(units_u64);
                } else {
                    runs.push((modifier.operand, units_u64));
                }
            }
        }
    }
    let bases = base_capacitor(ship);
    let mut values: [Option<f64>; 2] = [None, None];
    for index in 0..2 {
        let Some(base) = bases[index].filter(|v| v.is_finite() && *v >= 0.0) else {
            continue;
        };
        let mut add_total = 0.0;
        for (operand, count) in &add_runs[index] {
            add_total += operand * (*count as f64);
        }
        let mut mul_total = 1.0;
        for (operand, count) in &mul_runs[index] {
            mul_total *= mul_product(*operand, *count);
        }
        let mut sorted_percent = percent_runs[index].clone();
        sorted_percent.sort_by(|a, b| b.0.abs().total_cmp(&a.0.abs()));
        let mut percent_total = 1.0;
        for (value, count) in &sorted_percent {
            percent_total *= mul_product(1.0 + value / 100.0, *count);
        }
        let bonused = (base + add_total) * mul_total * percent_total;
        // A positive subnormal is stall residue from a
        // hostile-quantity run underflowing toward zero,
        // not an honest capacity or duration: reject it
        // as no data so downstream never simulates or
        // renders it. An exact 0.0 stays a real zero.
        values[index] =
            Some(bonused).filter(|v| v.is_finite() && *v >= 0.0 && (*v == 0.0 || v.is_normal()));
    }
    Some(BonusedCapacitor {
        values,
        excluded_modules,
        capacitor_capacity_unapplied_modules,
        capacitor_recharge_unapplied_modules,
    })
}

/// Bonused shield recharge duration in milliseconds (the
/// catalogue unit; lower is faster) plus the fitted-module
/// counts the caller must disclose beside any number
/// derived from it.
pub(crate) struct BonusedShieldRechargeDuration {
    /// Bonused shield recharge duration in raw
    /// milliseconds; `None` exactly where the base value
    /// is absent, negative, or non-finite, or the bonused
    /// result is negative, non-finite, or a positive
    /// subnormal.
    pub recharge_ms: Option<f64>,
    /// Counted fitted rows with no catalogue row at all,
    /// so no shield recharge bonus can be proven or
    /// disproven for them, in quantity units. Same
    /// definition and source predicate as
    /// `BonusedCapacitor::excluded_modules`.
    pub excluded_modules: usize,
    /// Shield-recharge-dimension count: counted fitted
    /// rows the catalogue marks as shield recharge
    /// carriers whose bonus cannot be applied, in quantity
    /// units. Never summed with any other dimension's
    /// count.
    pub shield_recharge_unapplied_modules: usize,
}

/// `None` only when the ship gate fails (`ship_type_id
/// <= 0`, no catalogue row, or the row is not category
/// 6). Otherwise `Some`, with `recharge_ms` as documented
/// on the field.
pub(crate) fn bonused_shield_recharge_duration(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> Option<BonusedShieldRechargeDuration> {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let ship = ship_row?;
    if ship.category_id != 6 {
        return None;
    }
    let mut excluded_modules: usize = 0;
    let mut shield_recharge_unapplied_modules: usize = 0;
    let mut add_runs: Vec<(f64, u64)> = Vec::new();
    let mut mul_runs: Vec<(f64, u64)> = Vec::new();
    let mut percent_runs: Vec<(f64, u64)> = Vec::new();
    for item in &fitting.items {
        if item.type_id <= 0 {
            continue;
        }
        if item.quantity.max(0) <= 0 {
            continue;
        }
        if !counted_flag(&item.flag) {
            continue;
        }
        let units = usize::try_from(item.quantity).unwrap_or(0);
        let units_u64 = units as u64;
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            excluded_modules = excluded_modules.saturating_add(units);
            continue;
        };
        let mut counted_unapplied = false;
        if row.shield_recharge_modifiers_unapplied {
            shield_recharge_unapplied_modules =
                shield_recharge_unapplied_modules.saturating_add(units);
            counted_unapplied = true;
        }
        let Some(modifiers) = &row.shield_recharge_modifiers else {
            continue;
        };
        for modifier in modifiers {
            if modifier.modified_attribute_id != SHIELD_RECHARGE_MODIFIED_ATTRIBUTE_ID {
                if !counted_unapplied {
                    shield_recharge_unapplied_modules =
                        shield_recharge_unapplied_modules.saturating_add(units);
                    counted_unapplied = true;
                }
                continue;
            }
            if !modifier.operand.is_finite()
                || modifier.operand == 0.0
                || !matches!(modifier.operator, 2 | 4 | 6)
            {
                if !counted_unapplied {
                    shield_recharge_unapplied_modules =
                        shield_recharge_unapplied_modules.saturating_add(units);
                    counted_unapplied = true;
                }
                continue;
            }
            let runs = match modifier.operator {
                2 => &mut add_runs,
                4 => &mut mul_runs,
                _ => &mut percent_runs,
            };
            if let Some((_, count)) = runs
                .iter_mut()
                .find(|(existing, _)| existing == &modifier.operand)
            {
                *count = count.saturating_add(units_u64);
            } else {
                runs.push((modifier.operand, units_u64));
            }
        }
    }
    let base = ship
        .shield_recharge_rate
        .filter(|v| v.is_finite() && *v >= 0.0);
    let recharge_ms = base.and_then(|base| {
        let mut add_total = 0.0;
        for (operand, count) in &add_runs {
            add_total += operand * (*count as f64);
        }
        let mut mul_total = 1.0;
        for (operand, count) in &mul_runs {
            mul_total *= mul_product(*operand, *count);
        }
        let mut sorted_percent = percent_runs.clone();
        sorted_percent.sort_by(|a, b| b.0.abs().total_cmp(&a.0.abs()));
        let mut percent_total = 1.0;
        for (value, count) in &sorted_percent {
            percent_total *= mul_product(1.0 + value / 100.0, *count);
        }
        let bonused = (base + add_total) * mul_total * percent_total;
        // A positive subnormal is stall residue from a
        // hostile-quantity run underflowing toward zero,
        // not an honest duration: reject it as no data so
        // downstream never renders it. An exact 0.0 stays
        // a real zero.
        Some(bonused).filter(|v| v.is_finite() && *v >= 0.0 && (*v == 0.0 || v.is_normal()))
    });
    Some(BonusedShieldRechargeDuration {
        recharge_ms,
        excluded_modules,
        shield_recharge_unapplied_modules,
    })
}

/// Bonused CPU output (tf) and power grid output (MW),
/// composed with the two trained output-skill percents
/// when levels are supplied, plus the fitted-module
/// counts the caller must disclose beside any number
/// derived from them. The shared catalogue-absent
/// excluded count is deliberately not carried: the
/// sole caller discloses excluded rows per resource
/// dimension from its own scan (the
/// `bonused_hit_points` precedent).
pub(crate) struct BonusedOutputs {
    /// [cpu_output, power_output] in OUTPUT_ORDER
    /// position, each `None` exactly where the base
    /// value is absent, negative, or non-finite, or
    /// the bonused result is negative, non-finite, or
    /// a positive subnormal.
    pub values: [Option<f64>; 2],
    /// CPU-output-dimension count: counted fitted rows
    /// the catalogue marks as CPU output carriers whose
    /// bonus cannot be applied, in quantity units.
    /// Never summed with
    /// `power_output_unapplied_modules`.
    pub cpu_output_unapplied_modules: usize,
    /// Power-output-dimension count: same shape for the
    /// power family. Never summed with
    /// `cpu_output_unapplied_modules`.
    pub power_output_unapplied_modules: usize,
}

/// `None` only when the ship gate fails (`ship_type_id
/// <= 0`, no catalogue row, or the row is not category
/// 6). Otherwise `Some`, per-value `None` as documented
/// on `values`. `output_skill_levels` is
/// (cpu_management, power_grid_management) raw trained
/// levels — only the two output skills, so no
/// need-reduction concept can enter this module —
/// defensively clamped to 0..=5 inside; `None` composes
/// module bonuses with no skill entry.
pub(crate) fn bonused_outputs(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
    output_skill_levels: Option<(i32, i32)>,
) -> Option<BonusedOutputs> {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let ship = ship_row?;
    if ship.category_id != 6 {
        return None;
    }
    let mut cpu_output_unapplied_modules: usize = 0;
    let mut power_output_unapplied_modules: usize = 0;
    let mut add_runs: [Vec<(f64, u64)>; 2] = Default::default();
    let mut mul_runs: [Vec<(f64, u64)>; 2] = Default::default();
    let mut percent_runs: [Vec<(f64, u64)>; 2] = Default::default();
    for item in &fitting.items {
        if item.type_id <= 0 {
            continue;
        }
        if item.quantity.max(0) <= 0 {
            continue;
        }
        if !counted_flag(&item.flag) {
            continue;
        }
        let units = usize::try_from(item.quantity).unwrap_or(0);
        let units_u64 = units as u64;
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            continue;
        };
        // CPU family (48)
        let mut counted_cpu_unapplied = false;
        if row.cpu_output_modifiers_unapplied {
            cpu_output_unapplied_modules = cpu_output_unapplied_modules.saturating_add(units);
            counted_cpu_unapplied = true;
        }
        if let Some(modifiers) = &row.cpu_output_modifiers {
            for modifier in modifiers {
                let Some(index) = OUTPUT_ORDER
                    .iter()
                    .position(|id| *id == modifier.modified_attribute_id)
                else {
                    if !counted_cpu_unapplied {
                        cpu_output_unapplied_modules =
                            cpu_output_unapplied_modules.saturating_add(units);
                        counted_cpu_unapplied = true;
                    }
                    continue;
                };
                if index != 0 {
                    if !counted_cpu_unapplied {
                        cpu_output_unapplied_modules =
                            cpu_output_unapplied_modules.saturating_add(units);
                        counted_cpu_unapplied = true;
                    }
                    continue;
                }
                if !modifier.operand.is_finite()
                    || modifier.operand == 0.0
                    || !matches!(modifier.operator, 2 | 4 | 6)
                {
                    if !counted_cpu_unapplied {
                        cpu_output_unapplied_modules =
                            cpu_output_unapplied_modules.saturating_add(units);
                        counted_cpu_unapplied = true;
                    }
                    continue;
                }
                let runs = match modifier.operator {
                    2 => &mut add_runs[index],
                    4 => &mut mul_runs[index],
                    _ => &mut percent_runs[index],
                };
                if let Some((_, count)) = runs
                    .iter_mut()
                    .find(|(existing, _)| existing == &modifier.operand)
                {
                    *count = count.saturating_add(units_u64);
                } else {
                    runs.push((modifier.operand, units_u64));
                }
            }
        }
        // Power family (11)
        let mut counted_power_unapplied = false;
        if row.power_output_modifiers_unapplied {
            power_output_unapplied_modules = power_output_unapplied_modules.saturating_add(units);
            counted_power_unapplied = true;
        }
        if let Some(modifiers) = &row.power_output_modifiers {
            for modifier in modifiers {
                let Some(index) = OUTPUT_ORDER
                    .iter()
                    .position(|id| *id == modifier.modified_attribute_id)
                else {
                    if !counted_power_unapplied {
                        power_output_unapplied_modules =
                            power_output_unapplied_modules.saturating_add(units);
                        counted_power_unapplied = true;
                    }
                    continue;
                };
                if index != 1 {
                    if !counted_power_unapplied {
                        power_output_unapplied_modules =
                            power_output_unapplied_modules.saturating_add(units);
                        counted_power_unapplied = true;
                    }
                    continue;
                }
                if !modifier.operand.is_finite()
                    || modifier.operand == 0.0
                    || !matches!(modifier.operator, 2 | 4 | 6)
                {
                    if !counted_power_unapplied {
                        power_output_unapplied_modules =
                            power_output_unapplied_modules.saturating_add(units);
                        counted_power_unapplied = true;
                    }
                    continue;
                }
                let runs = match modifier.operator {
                    2 => &mut add_runs[index],
                    4 => &mut mul_runs[index],
                    _ => &mut percent_runs[index],
                };
                if let Some((_, count)) = runs
                    .iter_mut()
                    .find(|(existing, _)| existing == &modifier.operand)
                {
                    *count = count.saturating_add(units_u64);
                } else {
                    runs.push((modifier.operand, units_u64));
                }
            }
        }
    }
    // One skill percent run per dimension, appended after
    // the module runs and before the sort: Flutter's
    // `0.05 * level * 100` spelling, only when the clamped
    // level is above 0. `Some((0, 0))` is therefore
    // identical to `None` in every value and count.
    if let Some((cpu_level, power_level)) = output_skill_levels {
        let cpu_level = clamp_output_level(cpu_level);
        if cpu_level > 0 {
            percent_runs[0].push((0.05 * cpu_level as f64 * 100.0, 1));
        }
        let power_level = clamp_output_level(power_level);
        if power_level > 0 {
            percent_runs[1].push((0.05 * power_level as f64 * 100.0, 1));
        }
    }
    let bases = base_outputs(ship);
    let mut values: [Option<f64>; 2] = [None, None];
    for index in 0..2 {
        let Some(base) = bases[index].filter(|v| v.is_finite() && *v >= 0.0) else {
            continue;
        };
        let mut add_total = 0.0;
        for (operand, count) in &add_runs[index] {
            add_total += operand * (*count as f64);
        }
        let mut mul_total = 1.0;
        for (operand, count) in &mul_runs[index] {
            mul_total *= mul_product(*operand, *count);
        }
        let mut sorted_percent = percent_runs[index].clone();
        sorted_percent.sort_by(|a, b| b.0.abs().total_cmp(&a.0.abs()));
        let mut percent_total = 1.0;
        for (value, count) in &sorted_percent {
            percent_total *= mul_product(1.0 + value / 100.0, *count);
        }
        let bonused = (base + add_total) * mul_total * percent_total;
        // A positive subnormal is stall residue from a
        // hostile-quantity run underflowing toward zero,
        // not an honest output: reject it as no data so
        // downstream never renders it. An exact 0.0 stays
        // a real zero.
        values[index] =
            Some(bonused).filter(|v| v.is_finite() && *v >= 0.0 && (*v == 0.0 || v.is_normal()));
    }
    Some(BonusedOutputs {
        values,
        cpu_output_unapplied_modules,
        power_output_unapplied_modules,
    })
}

/// Bonused navigation and targeting values in raw
/// catalogue units (targeting range in metres, locked
/// targets still an `f64`) plus the counts the caller
/// must disclose beside any number derived from them.
pub(crate) struct BonusedNavTargetingValues {
    /// [600, 70, 4, 552, 76, 564, 208, 209, 210, 211, 192]
    /// in NAV_TARGETING_ORDER position, each `None`
    /// exactly where the base value is absent, negative,
    /// or non-finite, or the bonused result is negative,
    /// non-finite, or a positive subnormal.
    pub values: [Option<f64>; 11],
    /// Counted fitted rows with no catalogue row at all,
    /// in quantity units. Same definition and source
    /// predicate as `BonusedResonances::excluded_modules`
    /// (pinned equal, section 8).
    pub excluded_modules: usize,
    /// Per-attribute unapplied counts in
    /// NAV_TARGETING_ORDER position: counted fitted rows
    /// the catalogue marks as carriers in that attribute
    /// whose bonus cannot be applied, in quantity units.
    /// Never summed across positions.
    pub unapplied_modules: [usize; 11],
}

/// `None` only when the ship gate fails (`ship_type_id
/// <= 0`, no catalogue row, or the row is not category
/// 6). Otherwise `Some`, per-value `None` as documented
/// on `values`.
pub(crate) fn bonused_nav_targeting(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> Option<BonusedNavTargetingValues> {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let ship = ship_row?;
    if ship.category_id != 6 {
        return None;
    }
    let mut excluded_modules: usize = 0;
    let mut unapplied_modules: [usize; 11] = [0; 11];
    let mut add_runs: [Vec<(f64, u64)>; 11] = Default::default();
    let mut mul_runs: [Vec<(f64, u64)>; 11] = Default::default();
    let mut percent_runs: [Vec<(f64, u64)>; 11] = Default::default();
    for item in &fitting.items {
        if item.type_id <= 0 {
            continue;
        }
        if item.quantity.max(0) <= 0 {
            continue;
        }
        if !counted_flag(&item.flag) {
            continue;
        }
        let units = usize::try_from(item.quantity).unwrap_or(0);
        let units_u64 = units as u64;
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            excluded_modules = excluded_modules.saturating_add(units);
            continue;
        };
        let families: [(
            &Option<Vec<crate::names::fitting_types::NavTargetingModifier>>,
            bool,
        ); 11] = [
            (
                &row.warp_speed_multiplier_modifiers,
                row.warp_speed_multiplier_modifiers_unapplied,
            ),
            (&row.agility_modifiers, row.agility_modifiers_unapplied),
            (&row.mass_modifiers, row.mass_modifiers_unapplied),
            (
                &row.signature_radius_modifiers,
                row.signature_radius_modifiers_unapplied,
            ),
            (
                &row.max_target_range_modifiers,
                row.max_target_range_modifiers_unapplied,
            ),
            (
                &row.scan_resolution_modifiers,
                row.scan_resolution_modifiers_unapplied,
            ),
            (
                &row.scan_radar_strength_modifiers,
                row.scan_radar_strength_modifiers_unapplied,
            ),
            (
                &row.scan_ladar_strength_modifiers,
                row.scan_ladar_strength_modifiers_unapplied,
            ),
            (
                &row.scan_magnetometric_strength_modifiers,
                row.scan_magnetometric_strength_modifiers_unapplied,
            ),
            (
                &row.scan_gravimetric_strength_modifiers,
                row.scan_gravimetric_strength_modifiers_unapplied,
            ),
            (
                &row.max_locked_targets_modifiers,
                row.max_locked_targets_modifiers_unapplied,
            ),
        ];
        let mut counted_unapplied: [bool; 11] = [false; 11];
        for (index, (modifiers, unapplied)) in families.iter().enumerate() {
            if *unapplied {
                unapplied_modules[index] = unapplied_modules[index].saturating_add(units);
                counted_unapplied[index] = true;
            }
            let Some(modifiers) = modifiers else {
                continue;
            };
            for modifier in modifiers {
                if modifier.modified_attribute_id != NAV_TARGETING_ORDER[index] {
                    if !counted_unapplied[index] {
                        unapplied_modules[index] = unapplied_modules[index].saturating_add(units);
                        counted_unapplied[index] = true;
                    }
                    continue;
                }
                if !modifier.operand.is_finite()
                    || modifier.operand == 0.0
                    || !matches!(modifier.operator, 2 | 4 | 6)
                {
                    if !counted_unapplied[index] {
                        unapplied_modules[index] = unapplied_modules[index].saturating_add(units);
                        counted_unapplied[index] = true;
                    }
                    continue;
                }
                let runs = match modifier.operator {
                    2 => &mut add_runs[index],
                    4 => &mut mul_runs[index],
                    _ => &mut percent_runs[index],
                };
                if let Some((_, count)) = runs
                    .iter_mut()
                    .find(|(existing, _)| existing == &modifier.operand)
                {
                    *count = count.saturating_add(units_u64);
                } else {
                    runs.push((modifier.operand, units_u64));
                }
            }
        }
    }
    let bases = base_nav_targeting(ship);
    let mut values: [Option<f64>; 11] = [None; 11];
    for index in 0..11 {
        let Some(base) = bases[index].filter(|v| v.is_finite() && *v >= 0.0) else {
            continue;
        };
        let mut add_total = 0.0;
        for (operand, count) in &add_runs[index] {
            add_total += operand * (*count as f64);
        }
        let mut mul_total = 1.0;
        for (operand, count) in &mul_runs[index] {
            mul_total *= mul_product(*operand, *count);
        }
        let mut sorted_percent = percent_runs[index].clone();
        sorted_percent.sort_by(|a, b| b.0.abs().total_cmp(&a.0.abs()));
        let mut percent_total = 1.0;
        for (value, count) in &sorted_percent {
            percent_total *= mul_product(1.0 + value / 100.0, *count);
        }
        let bonused = (base + add_total) * mul_total * percent_total;
        // A positive subnormal is stall residue from a
        // hostile-quantity run underflowing toward zero,
        // not an honest navigation or targeting value:
        // reject it as no data so downstream never renders
        // it. An exact 0.0 stays a real zero.
        values[index] =
            Some(bonused).filter(|v| v.is_finite() && *v >= 0.0 && (*v == 0.0 || v.is_normal()));
    }
    Some(BonusedNavTargetingValues {
        values,
        excluded_modules,
        unapplied_modules,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::resources::fitting_resources;
    use crate::fitting::ship_stats::ship_base_stats;

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

    fn available(result: ShipResistancesOutcome) -> ShipResistances {
        match result {
            ShipResistancesOutcome::Available(resistances) => resistances,
            ShipResistancesOutcome::Unavailable => panic!("expected Available, got Unavailable"),
        }
    }

    fn assert_percent(actual: Option<f64>, expected: Option<f64>, label: &str) {
        match (actual, expected) {
            (None, None) => {}
            (Some(actual), Some(expected)) => assert!(
                (actual - expected).abs() < 1e-9,
                "{label}: expected {expected}, got {actual}"
            ),
            _ => panic!("{label}: expected {expected:?}, got {actual:?}"),
        }
    }

    fn assert_layer(actual: &ResistLayer, expected: (f64, f64, f64, f64), label: &str) {
        assert_percent(actual.em, Some(expected.0), &format!("{label} EM"));
        assert_percent(
            actual.thermal,
            Some(expected.1),
            &format!("{label} Thermal"),
        );
        assert_percent(
            actual.kinetic,
            Some(expected.2),
            &format!("{label} Kinetic"),
        );
        assert_percent(
            actual.explosive,
            Some(expected.3),
            &format!("{label} Explosive"),
        );
    }

    // Oracle resonance rows read from scripts/sde/dgmTypeAttributes.csv.bz2
    // (every row has valueInt None, valueFloat shown):
    // Rifter 587: shield 1.0/0.8/0.6/0.5, armor 0.4/0.65/0.75/0.9,
    // hull 0.67 x4 (974-977 decoy rows at 1.0 never emitted).
    // Punisher 597: shield 1.0/0.8/0.6/0.5, armor 0.5/0.65/0.75/0.8,
    // hull 0.67 x4. Mimir 32209: shield 1.0/0.8/0.6/0.5, armor
    // 0.1/0.325/0.75/0.9, hull 0.67 x4. Legion 29986: shield
    // 1.0/0.8/0.45/0.25, armor 0.5/0.65/0.5625/0.4, hull 0.67 x4.
    // Falcon 11957 armor kinetic 0.46875, armor thermal 0.20625.
    // Nemesis 11377 armor thermal 0.56875, armor kinetic 0.4875.
    // Percentages are (1 - resonance) * 100 hand-derived.
    #[test]
    fn oracle_ships_return_all_twelve_literal_percentages() {
        let catalogue = bundled();
        let rifter = available(ship_resistances(&fitting(587, vec![]), &catalogue));
        assert_layer(&rifter.shield, (0.0, 20.0, 40.0, 50.0), "Rifter shield");
        assert_layer(&rifter.armor, (60.0, 35.0, 25.0, 10.0), "Rifter armor");
        assert_layer(&rifter.hull, (33.0, 33.0, 33.0, 33.0), "Rifter hull");

        let punisher = available(ship_resistances(&fitting(597, vec![]), &catalogue));
        assert_layer(&punisher.shield, (0.0, 20.0, 40.0, 50.0), "Punisher shield");
        assert_layer(&punisher.armor, (50.0, 35.0, 25.0, 20.0), "Punisher armor");
        assert_layer(&punisher.hull, (33.0, 33.0, 33.0, 33.0), "Punisher hull");

        let mimir = available(ship_resistances(&fitting(32209, vec![]), &catalogue));
        assert_layer(&mimir.shield, (0.0, 20.0, 40.0, 50.0), "Mimir shield");
        assert_layer(&mimir.armor, (90.0, 67.5, 25.0, 10.0), "Mimir armor");
        assert_layer(&mimir.hull, (33.0, 33.0, 33.0, 33.0), "Mimir hull");
    }

    #[test]
    fn legion_and_falcon_nemesis_fractional_pins() {
        let catalogue = bundled();
        let legion = available(ship_resistances(&fitting(29986, vec![]), &catalogue));
        assert_layer(&legion.shield, (0.0, 20.0, 55.0, 75.0), "Legion shield");
        assert_layer(&legion.armor, (50.0, 35.0, 43.75, 60.0), "Legion armor");
        assert_layer(&legion.hull, (33.0, 33.0, 33.0, 33.0), "Legion hull");

        let falcon = available(ship_resistances(&fitting(11957, vec![]), &catalogue));
        assert_percent(falcon.armor.kinetic, Some(53.125), "Falcon armor Kinetic");
        assert_percent(falcon.armor.thermal, Some(79.375), "Falcon armor Thermal");

        let nemesis = available(ship_resistances(&fitting(11377, vec![]), &catalogue));
        assert_percent(nemesis.armor.thermal, Some(43.125), "Nemesis armor Thermal");
        assert_percent(nemesis.armor.kinetic, Some(51.25), "Nemesis armor Kinetic");
    }

    // The no-modifiers lock as a test: fitted modules — including
    // the Damage Control II whose own 974-977 bonus attributes
    // are the decoy hull set — plus an unknown type and a stacked
    // quantity change nothing.
    #[test]
    fn fitted_items_are_ignored() {
        let catalogue = bundled();
        let hull_only = ship_resistances(&fitting(587, vec![]), &catalogue);
        let fitted = ship_resistances(
            &fitting(
                587,
                vec![
                    item("LoSlot0", 1, 2048),
                    item("MedSlot0", 3, 1183),
                    item("HiSlot0", 1, 999999),
                ],
            ),
            &catalogue,
        );
        assert_eq!(fitted, hull_only);
    }

    #[test]
    fn ship_failures_are_unavailable() {
        let catalogue = bundled();
        for ship_type_id in [999999, 2048, 0, -1] {
            let result = ship_resistances(&fitting(ship_type_id, vec![]), &catalogue);
            assert_eq!(
                result,
                ShipResistancesOutcome::Unavailable,
                "ship {ship_type_id}"
            );
        }
    }

    // Absent versus present values, via fixture catalogue:
    // shipped data has no such ship (all 404 ships carry all
    // twelve), so only fixtures can exercise the distinction.
    // Shield EM present as 1.0 is a real 0.0; one resonance
    // present as 0.0 is a real 100.0; absent keys are None.
    #[test]
    fn absent_is_none_and_present_one_and_zero_render() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldEmDamageResonance":1.0,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.0,"armorThermalDamageResonance":0.65,
                 "armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        let resistances = available(ship_resistances(&fitting(42, vec![]), &catalogue));
        assert_percent(resistances.shield.em, Some(0.0), "Fixture shield EM");
        assert_percent(resistances.shield.thermal, None, "Fixture shield Thermal");
        assert_percent(
            resistances.shield.kinetic,
            Some(40.0),
            "Fixture shield Kinetic",
        );
        assert_percent(
            resistances.shield.explosive,
            Some(50.0),
            "Fixture shield Explosive",
        );
        assert_percent(resistances.armor.em, Some(100.0), "Fixture armor EM");
        assert_percent(
            resistances.armor.thermal,
            Some(35.0),
            "Fixture armor Thermal",
        );
        assert_percent(
            resistances.armor.kinetic,
            Some(25.0),
            "Fixture armor Kinetic",
        );
        assert_percent(
            resistances.armor.explosive,
            Some(10.0),
            "Fixture armor Explosive",
        );
        assert_layer(&resistances.hull, (33.0, 33.0, 33.0, 33.0), "Fixture hull");
    }

    #[test]
    fn all_absent_collapses_to_unavailable_and_partial_stays_available() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Bare Hull","categoryId":6,"slotEffects":[]},
                {"typeId":43,"typeName":"Lone Segment","categoryId":6,"slotEffects":[],"shieldEmDamageResonance":1.0},
                {"typeId":44,"typeName":"Shield Only","categoryId":6,"slotEffects":[],
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5}]}"#,
        )
        .expect("fixture catalogue parses");
        assert_eq!(
            ship_resistances(&fitting(42, vec![]), &catalogue),
            ShipResistancesOutcome::Unavailable
        );
        let lone = available(ship_resistances(&fitting(43, vec![]), &catalogue));
        assert_percent(lone.shield.em, Some(0.0), "Lone shield EM");
        assert_percent(lone.shield.thermal, None, "Lone shield Thermal");
        assert_percent(lone.shield.kinetic, None, "Lone shield Kinetic");
        assert_percent(lone.shield.explosive, None, "Lone shield Explosive");
        assert_percent(lone.armor.em, None, "Lone armor EM");
        assert_percent(lone.armor.thermal, None, "Lone armor Thermal");
        assert_percent(lone.armor.kinetic, None, "Lone armor Kinetic");
        assert_percent(lone.armor.explosive, None, "Lone armor Explosive");
        assert_percent(lone.hull.em, None, "Lone hull EM");
        assert_percent(lone.hull.thermal, None, "Lone hull Thermal");
        assert_percent(lone.hull.kinetic, None, "Lone hull Kinetic");
        assert_percent(lone.hull.explosive, None, "Lone hull Explosive");

        let shield_only = available(ship_resistances(&fitting(44, vec![]), &catalogue));
        assert_layer(
            &shield_only.shield,
            (0.0, 20.0, 40.0, 50.0),
            "Shield-only shield",
        );
        assert_percent(shield_only.armor.em, None, "Shield-only armor EM");
        assert_percent(shield_only.armor.thermal, None, "Shield-only armor Thermal");
        assert_percent(shield_only.armor.kinetic, None, "Shield-only armor Kinetic");
        assert_percent(
            shield_only.armor.explosive,
            None,
            "Shield-only armor Explosive",
        );
        assert_percent(shield_only.hull.em, None, "Shield-only hull EM");
        assert_percent(shield_only.hull.thermal, None, "Shield-only hull Thermal");
        assert_percent(shield_only.hull.kinetic, None, "Shield-only hull Kinetic");
        assert_percent(
            shield_only.hull.explosive,
            None,
            "Shield-only hull Explosive",
        );
    }

    // Out-of-range and guard pins: a present resonance above 1
    // renders its true signed percent, never clamped; a negative
    // resonance is no data for that field only; non-finite values
    // and overflowing percentages are no data. JSON cannot spell
    // NaN, so the non-finite half is pinned through the private
    // conversion rule (the ship_stats `usable` symmetry).
    #[test]
    fn above_one_renders_signed_and_negative_is_no_data_for_one_field_only() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldEmDamageResonance":1.1,"shieldThermalDamageResonance":7.0,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":-1.0,"armorThermalDamageResonance":0.65,
                 "armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        let resistances = available(ship_resistances(&fitting(42, vec![]), &catalogue));
        assert_percent(resistances.shield.em, Some(-10.0), "Fixture shield EM 1.1");
        assert_percent(
            resistances.shield.thermal,
            Some(-600.0),
            "Fixture shield Thermal 7.0",
        );
        assert_percent(
            resistances.shield.kinetic,
            Some(40.0),
            "Fixture shield Kinetic",
        );
        assert_percent(
            resistances.shield.explosive,
            Some(50.0),
            "Fixture shield Explosive",
        );
        assert_percent(resistances.armor.em, None, "Fixture armor EM negative");
        assert_percent(
            resistances.armor.thermal,
            Some(35.0),
            "Fixture armor Thermal",
        );
        assert_percent(
            resistances.armor.kinetic,
            Some(25.0),
            "Fixture armor Kinetic",
        );
        assert_percent(
            resistances.armor.explosive,
            Some(10.0),
            "Fixture armor Explosive",
        );
        assert_layer(&resistances.hull, (33.0, 33.0, 33.0, 33.0), "Fixture hull");
    }

    #[test]
    fn conversion_rule_rejects_non_finite_negative_and_overflow() {
        assert_percent(resonance_to_percent(None), None, "None");
        assert_percent(resonance_to_percent(Some(1.0)), Some(0.0), "1.0");
        assert_percent(resonance_to_percent(Some(0.0)), Some(100.0), "0.0");
        assert_percent(resonance_to_percent(Some(0.67)), Some(33.0), "0.67");
        assert_percent(resonance_to_percent(Some(1.1)), Some(-10.0), "1.1");
        assert_percent(resonance_to_percent(Some(7.0)), Some(-600.0), "7.0");
        assert_percent(resonance_to_percent(Some(-1.0)), None, "-1.0");
        assert_percent(resonance_to_percent(Some(f64::INFINITY)), None, "infinity");
        assert_percent(
            resonance_to_percent(Some(f64::NEG_INFINITY)),
            None,
            "negative infinity",
        );
        assert_percent(resonance_to_percent(Some(f64::NAN)), None, "NaN");
        assert_percent(resonance_to_percent(Some(1e308)), None, "1e308 overflow");
    }

    // Independence from base stats and resources, in both
    // directions (fixtures): resonances without stats or
    // outputs give resistances Available and the other two
    // unavailable; stats without resonances or outputs give
    // base stats Available and the other two unavailable;
    // outputs without resonances or stats give resources
    // Available and the other two unavailable. The real
    // catalogue has no such ship; fixtures only.
    #[test]
    fn availability_is_independent_of_stats_and_resources() {
        let resistances_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Resistances Only","categoryId":6,"slotEffects":[],
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.65,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        assert!(matches!(
            ship_resistances(&fit, &resistances_only),
            ShipResistancesOutcome::Available(_)
        ));
        assert_eq!(
            ship_base_stats(&fit, &resistances_only),
            crate::fitting::ship_stats::ShipBaseStatsOutcome::Unavailable
        );
        assert_eq!(
            fitting_resources(&fit, &resistances_only),
            crate::fitting::resources::FittingResources::ShipNoOutput
        );

        let stats_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Stats Only","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0,"capacitorCapacity":250.0,"maxVelocity":365.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        assert_eq!(
            ship_resistances(&fit, &stats_only),
            ShipResistancesOutcome::Unavailable
        );
        assert!(matches!(
            ship_base_stats(&fit, &stats_only),
            crate::fitting::ship_stats::ShipBaseStatsOutcome::Available(_)
        ));
        assert_eq!(
            fitting_resources(&fit, &stats_only),
            crate::fitting::resources::FittingResources::ShipNoOutput
        );

        let outputs_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Outputs Only","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        assert_eq!(
            ship_resistances(&fit, &outputs_only),
            ShipResistancesOutcome::Unavailable
        );
        assert_eq!(
            ship_base_stats(&fit, &outputs_only),
            crate::fitting::ship_stats::ShipBaseStatsOutcome::Unavailable
        );
        assert!(matches!(
            fitting_resources(&fit, &outputs_only),
            crate::fitting::resources::FittingResources::Available { .. }
        ));
    }

    fn bonused_available(
        fit: &CharacterFitting,
        catalogue: &FittingTypes,
    ) -> BonusedShipResistances {
        match ship_resistances_with_module_bonuses(fit, catalogue) {
            BonusedShipResistancesOutcome::Available(bonused) => bonused,
            BonusedShipResistancesOutcome::Unavailable => {
                panic!("expected Available, got Unavailable")
            }
        }
    }

    // Penalty oracle (design section 8): n = 1..6, plus
    // n = 2 exact and the n = 0 guard pin.
    #[test]
    fn stacking_penalty_oracle() {
        let expected = [1.0, 0.869, 0.571, 0.283, 0.106, 0.030];
        for (index, expected_value) in expected.iter().enumerate() {
            let actual = resistance_stacking_penalty(index + 1);
            assert!(
                (actual - expected_value).abs() < 1e-3,
                "n = {}: expected {expected_value}, got {actual}",
                index + 1
            );
        }
        assert!(
            (resistance_stacking_penalty(2) - (-((1.0f64 / 2.67) * (1.0 / 2.67))).exp()).abs()
                < 1e-9
        );
        assert_eq!(resistance_stacking_penalty(0), 1.0);
        assert_eq!(resistance_stacking_penalty(1), 1.0);
    }

    // Synthetic Flutter oracles via from_json fixtures
    // carrying resistanceModifiers triples directly
    // (design section 8). Ship type 42: shield EM 1.0,
    // shield thermal 0.5, armor EM 0.4, hull all 0.67.
    fn synthetic_catalogue(modules_json: &str) -> FittingTypes {
        let json = format!(
            r#"{{"types":[
                {{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.5,
                 "shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.65,
                 "armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,
                 "kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}},
                {modules_json}]}}"#
        );
        FittingTypes::from_json(&json).expect("fixture catalogue parses")
    }

    #[test]
    fn synthetic_single_hardener() {
        let catalogue = synthetic_catalogue(
            r#"{"typeId":101,"typeName":"Hardener","categoryId":7,"slotEffects":[13],"resistanceModifiers":[[271,6,-55.0]]}"#,
        );
        let bonused = bonused_available(&fitting(42, vec![item("MedSlot0", 1, 101)]), &catalogue);
        assert_percent(
            bonused.resistances.shield.em,
            Some(55.0),
            "single hardener shield EM",
        );
        assert_percent(
            bonused.resistances.shield.thermal,
            Some(50.0),
            "single hardener shield Thermal",
        );
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
    }

    #[test]
    fn synthetic_single_damage_control() {
        let catalogue = synthetic_catalogue(
            r#"{"typeId":102,"typeName":"Damage Control","categoryId":7,"slotEffects":[11],"resistanceModifiers":[[267,0,0.85]]}"#,
        );
        let bonused = bonused_available(&fitting(42, vec![item("LoSlot0", 1, 102)]), &catalogue);
        assert_percent(
            bonused.resistances.armor.em,
            Some(66.0),
            "single DC armor EM",
        );
    }

    #[test]
    fn synthetic_stacked_hardener_chain() {
        let catalogue = synthetic_catalogue(
            r#"{"typeId":101,"typeName":"Hardener A","categoryId":7,"slotEffects":[13],"resistanceModifiers":[[271,6,-55.0]]},
                {"typeId":103,"typeName":"Hardener B","categoryId":7,"slotEffects":[13],"resistanceModifiers":[[271,6,-50.0]]}"#,
        );
        let bonused = bonused_available(
            &fitting(42, vec![item("MedSlot0", 1, 101), item("MedSlot1", 1, 103)]),
            &catalogue,
        );
        // (1 - 0.55) * (1 - 0.50 * exp(-(1/2.67)^2)) = 0.25444800...
        assert_percent(
            bonused.resistances.shield.em,
            Some(74.555199568),
            "stacked chain shield EM",
        );
    }

    #[test]
    fn synthetic_chain_sorts_by_absolute_value() {
        // Fitted in reverse item order (-25 first, -55 second)
        // must compute as if -55 came first.
        let catalogue = synthetic_catalogue(
            r#"{"typeId":104,"typeName":"Weak","categoryId":7,"slotEffects":[13],"resistanceModifiers":[[271,6,-25.0]]},
                {"typeId":105,"typeName":"Strong","categoryId":7,"slotEffects":[13],"resistanceModifiers":[[271,6,-55.0]]}"#,
        );
        let bonused = bonused_available(
            &fitting(42, vec![item("MedSlot0", 1, 104), item("MedSlot1", 1, 105)]),
            &catalogue,
        );
        // (1 - 0.55) * (1 - 0.25 * exp(-(1/2.67)^2)) = 0.35222400...
        assert_percent(
            bonused.resistances.shield.em,
            Some(64.777599784),
            "sorted chain shield EM",
        );
        let forward = bonused_available(
            &fitting(42, vec![item("MedSlot0", 1, 105), item("MedSlot1", 1, 104)]),
            &catalogue,
        );
        assert_eq!(forward.resistances.shield.em, bonused.resistances.shield.em);
    }

    #[test]
    fn synthetic_mul_is_unpenalized() {
        let catalogue = synthetic_catalogue(
            r#"{"typeId":102,"typeName":"Damage Control","categoryId":7,"slotEffects":[11],"resistanceModifiers":[[267,0,0.85]]}"#,
        );
        let bonused = bonused_available(
            &fitting(42, vec![item("LoSlot0", 1, 102), item("LoSlot1", 1, 102)]),
            &catalogue,
        );
        assert_percent(
            bonused.resistances.armor.em,
            Some(71.1),
            "two muls armor EM",
        );
    }

    // Real-row pins (design section 8): Rifter 587.
    #[test]
    fn real_rifter_damage_control() {
        let catalogue = bundled();
        let bonused = bonused_available(&fitting(587, vec![item("LoSlot0", 1, 2048)]), &catalogue);
        assert_layer(
            &bonused.resistances.shield,
            (12.5, 30.0, 47.5, 56.25),
            "DC shield",
        );
        assert_layer(
            &bonused.resistances.armor,
            (66.0, 44.75, 36.25, 23.5),
            "DC armor",
        );
        assert_layer(
            &bonused.resistances.hull,
            (59.8, 59.8, 59.8, 59.8),
            "DC hull",
        );
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
    }

    #[test]
    fn real_rifter_hardener() {
        let catalogue = bundled();
        let bonused = bonused_available(&fitting(587, vec![item("MedSlot0", 1, 2281)]), &catalogue);
        assert_layer(
            &bonused.resistances.shield,
            (32.5, 46.0, 59.5, 66.25),
            "hardener shield",
        );
        assert_layer(
            &bonused.resistances.armor,
            (60.0, 35.0, 25.0, 10.0),
            "hardener armor base",
        );
        assert_layer(
            &bonused.resistances.hull,
            (33.0, 33.0, 33.0, 33.0),
            "hardener hull base",
        );
    }

    #[test]
    fn real_rifter_stacked_hardener_quantity_expansion() {
        let catalogue = bundled();
        let two_rows = bonused_available(
            &fitting(
                587,
                vec![item("MedSlot0", 1, 11642), item("MedSlot1", 1, 11642)],
            ),
            &catalogue,
        );
        // 0.4 * 0.45 * (1 - 0.55 * exp(-(1/2.67)^2)) = 0.093957...
        assert_percent(
            two_rows.resistances.armor.em,
            Some(90.60428781),
            "two armor hardeners",
        );
        let one_stacked_row =
            bonused_available(&fitting(587, vec![item("MedSlot0", 2, 11642)]), &catalogue);
        assert_eq!(
            one_stacked_row.resistances.armor.em,
            two_rows.resistances.armor.em
        );
        assert_eq!(two_rows.excluded_modules, one_stacked_row.excluded_modules);
        assert_eq!(
            two_rows.unapplied_modules,
            one_stacked_row.unapplied_modules
        );
        assert_percent(
            two_rows.resistances.armor.thermal,
            Some(35.0),
            "armor thermal base",
        );
    }

    #[test]
    fn real_rig_partial_carrier() {
        let catalogue = bundled();
        let bonused =
            bonused_available(&fitting(587, vec![item("RigSlot0", 1, 25736)]), &catalogue);
        assert_percent(bonused.resistances.armor.em, Some(72.0), "rig armor EM");
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
    }

    #[test]
    fn real_counts() {
        let catalogue = bundled();
        let abyssal = bonused_available(&fitting(587, vec![item("LoSlot0", 1, 52227)]), &catalogue);
        assert_eq!(abyssal.excluded_modules, 0);
        assert_eq!(abyssal.unapplied_modules, 1);
        let base = ship_resistances(&fitting(587, vec![]), &catalogue);
        assert_eq!(
            abyssal.resistances,
            match base {
                ShipResistancesOutcome::Available(r) => r,
                ShipResistancesOutcome::Unavailable => panic!("base unavailable"),
            }
        );
        let polarized =
            bonused_available(&fitting(587, vec![item("HiSlot0", 1, 34272)]), &catalogue);
        assert_eq!(polarized.unapplied_modules, 1);
        let layered = bonused_available(&fitting(587, vec![item("LoSlot0", 1, 1272)]), &catalogue);
        assert_eq!(layered.excluded_modules, 0);
        assert_eq!(layered.unapplied_modules, 0);
        let unknown =
            bonused_available(&fitting(587, vec![item("LoSlot0", 1, 999999)]), &catalogue);
        assert_eq!(unknown.excluded_modules, 1);
        let unknown_cargo =
            bonused_available(&fitting(587, vec![item("Cargo", 1, 999999)]), &catalogue);
        assert_eq!(unknown_cargo.excluded_modules, 0);
        assert_eq!(unknown_cargo.unapplied_modules, 0);
        let triple = bonused_available(&fitting(587, vec![item("LoSlot0", 3, 52227)]), &catalogue);
        assert_eq!(triple.unapplied_modules, 3);
        let zero = bonused_available(&fitting(587, vec![item("LoSlot0", 0, 2048)]), &catalogue);
        assert_eq!(zero.excluded_modules, 0);
        assert_eq!(zero.unapplied_modules, 0);
        let negative =
            bonused_available(&fitting(587, vec![item("LoSlot0", -5, 2048)]), &catalogue);
        assert_eq!(negative.excluded_modules, 0);
        assert_eq!(negative.unapplied_modules, 0);
        for type_id in [0, -1] {
            let skipped =
                bonused_available(&fitting(587, vec![item("LoSlot0", 1, type_id)]), &catalogue);
            assert_eq!(skipped.excluded_modules, 0);
            assert_eq!(skipped.unapplied_modules, 0);
        }
    }

    #[test]
    fn flag_gates() {
        let catalogue = bundled();
        for flag in [
            "LoSlot0",
            "MedSlot0",
            "HiSlot0",
            "RigSlot0",
            "SubSystemSlot0",
        ] {
            let bonused = bonused_available(&fitting(587, vec![item(flag, 1, 2048)]), &catalogue);
            assert_percent(
                bonused.resistances.armor.em,
                Some(66.0),
                &format!("{flag} contributes"),
            );
        }
        for flag in ["DroneBay", "Cargo", "FighterBay", "Invalid"] {
            let bonused = bonused_available(&fitting(587, vec![item(flag, 1, 2048)]), &catalogue);
            assert_percent(
                bonused.resistances.armor.em,
                Some(60.0),
                &format!("{flag} does not contribute"),
            );
            assert_eq!(bonused.excluded_modules, 0);
            assert_eq!(bonused.unapplied_modules, 0);
        }
        // A known non-carrier row (blueprint 2049 in a
        // counted flag) contributes nothing and counts nowhere.
        let blueprint =
            bonused_available(&fitting(587, vec![item("MedSlot0", 1, 2049)]), &catalogue);
        assert_eq!(blueprint.excluded_modules, 0);
        assert_eq!(blueprint.unapplied_modules, 0);
    }

    #[test]
    fn unavailable_coincides_with_base() {
        let catalogue = bundled();
        for ship_type_id in [999999, 2048, 0, -1] {
            assert_eq!(
                ship_resistances_with_module_bonuses(&fitting(ship_type_id, vec![]), &catalogue),
                BonusedShipResistancesOutcome::Unavailable,
                "ship {ship_type_id}"
            );
        }
    }

    #[test]
    fn no_counted_items_equals_base() {
        let catalogue = bundled();
        let bonused = bonused_available(&fitting(587, vec![]), &catalogue);
        let base = ship_resistances(&fitting(587, vec![]), &catalogue);
        assert_eq!(
            bonused.resistances,
            match base {
                ShipResistancesOutcome::Available(r) => r,
                ShipResistancesOutcome::Unavailable => panic!("base unavailable"),
            }
        );
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
    }

    #[test]
    fn guards_rejected_default_negative_and_bounded() {
        // Absent base resonance stays None even when modified.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Gapped Hull","categoryId":6,"slotEffects":[],
                 "shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.65,
                 "armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67},
                {"typeId":101,"typeName":"Hardener","categoryId":7,"slotEffects":[13],"resistanceModifiers":[[271,6,-55.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(&fitting(42, vec![item("MedSlot0", 1, 101)]), &catalogue);
        assert_percent(
            bonused.resistances.shield.em,
            None,
            "absent base stays None",
        );
        assert_percent(
            bonused.resistances.shield.thermal,
            Some(20.0),
            "others bonus normally",
        );

        // Bad entries mark the item unapplied once per unit
        // while good entries still apply.
        let catalogue = synthetic_catalogue(
            r#"{"typeId":106,"typeName":"Mixed","categoryId":7,"slotEffects":[13],"resistanceModifiers":[[271,7,-55.0],[274,6,-50.0],[272,6,0.0],[999,6,-10.0]]}"#,
        );
        let bonused = bonused_available(&fitting(42, vec![item("MedSlot0", 1, 106)]), &catalogue);
        assert_eq!(bonused.unapplied_modules, 1);
        assert_percent(
            bonused.resistances.shield.em,
            Some(0.0),
            "bad operator skipped",
        );
        assert_percent(
            bonused.resistances.shield.thermal,
            Some(75.0),
            "good entry applies",
        );

        // Forced-negative bonused resonance is no data.
        let catalogue = synthetic_catalogue(
            r#"{"typeId":107,"typeName":"Over","categoryId":7,"slotEffects":[13],"resistanceModifiers":[[271,6,-150.0]]}"#,
        );
        let bonused = bonused_available(&fitting(42, vec![item("MedSlot0", 1, 107)]), &catalogue);
        assert_percent(
            bonused.resistances.shield.em,
            None,
            "negative bonused resonance",
        );

        // Bounded hostile quantity: i64::MAX hardeners
        // return and match the quantity-100 result (the
        // stacking penalty underflows to exactly 0.0 at
        // n = 74, freezing every later factor at 1.0).
        let catalogue = bundled();
        let huge = bonused_available(
            &fitting(587, vec![item("MedSlot0", i64::MAX, 2281)]),
            &catalogue,
        );
        let hundred =
            bonused_available(&fitting(587, vec![item("MedSlot0", 100, 2281)]), &catalogue);
        assert_eq!(huge.resistances, hundred.resistances);
        assert_eq!(huge.excluded_modules, 0);
        assert_eq!(huge.unapplied_modules, 0);
    }

    #[test]
    fn mul_product_minus_one_is_decided_by_parity() {
        // A -1.0 operand never stalls, reaches 0.0, or goes
        // non-finite, so a hostile count must still return
        // immediately with the parity product.
        assert_eq!(mul_product(-1.0, u64::MAX), -1.0);
        assert_eq!(mul_product(-1.0, u64::MAX - 1), 1.0);
        assert_eq!(mul_product(-1.0, 0), 1.0);
        assert_eq!(mul_product(0.5, 3), 0.125);
    }

    // --- Bonused shield recharge duration helper pins
    // (docs/shield-recharge-bonuses-design.md sections 4, 8;
    // denominator side of the coupled pair) ---

    #[test]
    fn shield_recharge_duration_bundled_oracles() {
        let catalogue = bundled();
        // Oracle 1 denominator
        let fit = fitting(587, vec![item("MedSlot0", 1, 394)]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("Some");
        assert_eq!(duration.recharge_ms, Some(531250.0));
        assert_eq!(duration.excluded_modules, 0);
        assert_eq!(duration.shield_recharge_unapplied_modules, 0);
        // Oracle 3 denominator
        let fit = fitting(587, vec![item("LoSlot0", 1, 1256)]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("Some");
        assert_eq!(duration.recharge_ms, Some(437500.0));
        // Oracle 5 denominator (slower than base)
        let fit = fitting(587, vec![item("RigSlot0", 1, 4399)]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("Some");
        assert_eq!(duration.recharge_ms, Some(687500.0));
        // Oracle 6 denominator
        let fit = fitting(587, vec![item("LoSlot0", 1, 1541)]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("Some");
        assert_eq!(duration.recharge_ms, Some(571875.0));
        // Oracle 7 denominator stays base with unapplied count
        let fit = fitting(587, vec![item("LoSlot0", 1, 1445)]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("Some");
        assert_eq!(duration.recharge_ms, Some(625000.0));
        assert_eq!(duration.shield_recharge_unapplied_modules, 1);
        assert_eq!(duration.excluded_modules, 0);
    }

    #[test]
    fn shield_recharge_duration_identity_and_gates() {
        let catalogue = bundled();
        // Empty == base exactly
        let fit = fitting(587, vec![]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("Some");
        assert_eq!(duration.recharge_ms, Some(625000.0));
        // Identity 1.0 multiplier
        let fit = fitting(587, vec![item("LoSlot0", 1, 1353)]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("Some");
        assert_eq!(duration.recharge_ms, Some(625000.0));
        // Ship gate: helper None exactly on gate
        for ship in [999999, 2048, 0, -1] {
            assert!(
                bonused_shield_recharge_duration(&fitting(ship, vec![]), &catalogue).is_none(),
                "ship {ship}"
            );
        }
        // Base unusable -> recharge_ms None but helper Some
        let bare = FittingTypes::from_json(
            r#"{"types":[{"typeId":42,"typeName":"Bare Hull","categoryId":6,"slotEffects":[]}]}"#,
        )
        .expect("fixture parses");
        let duration = bonused_shield_recharge_duration(&fitting(42, vec![]), &bare).expect("Some");
        assert_eq!(duration.recharge_ms, None);
    }

    #[test]
    fn shield_recharge_duration_hostile_and_guards() {
        let hull = r#"{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"shieldCapacity":450.0,"shieldRechargeRate":625000.0}"#;
        // percent -100 -> Some(0.0)
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,6,-100.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let duration = bonused_shield_recharge_duration(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        )
        .expect("Some");
        assert_eq!(duration.recharge_ms, Some(0.0));
        // i64::MAX percent stalls to subnormal -> None
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,6,-20.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let duration = bonused_shield_recharge_duration(
            &fitting(42, vec![item("RigSlot0", i64::MAX, 101)]),
            &catalogue,
        )
        .expect("Some");
        assert_eq!(duration.recharge_ms, None);
        // additive hostile stays finite
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,2,1000.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let duration = bonused_shield_recharge_duration(
            &fitting(42, vec![item("MedSlot0", i64::MAX, 101)]),
            &catalogue,
        )
        .expect("Some");
        assert_eq!(
            duration.recharge_ms,
            Some(625000.0 + 1000.0 * (i64::MAX as f64))
        );
        // Runtime guards: bad entries count once, good still apply
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,0,0.9],[479,4,0.85],[263,4,0.8]]}}]}}"#),
        )
        .expect("fixture parses");
        let duration = bonused_shield_recharge_duration(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        )
        .expect("Some");
        assert_eq!(duration.shield_recharge_unapplied_modules, 1);
        assert_eq!(duration.recharge_ms, Some(531250.0));
    }

    // --- Bonused outputs helper pins
    // (docs/output-bonuses-design.md sections 4, 8) ---

    fn assert_output_close(actual: Option<f64>, expected: f64, label: &str) {
        let actual = actual.unwrap_or_else(|| panic!("{label}: expected Some, got None"));
        assert!(
            (actual - expected).abs() < 1e-9,
            "{label}: expected {expected}, got {actual}"
        );
    }

    #[test]
    fn bonused_outputs_oracle_helper_values() {
        let catalogue = bundled();
        // Oracle 1: RCU multiplier
        let fit = fitting(587, vec![item("LoSlot0", 1, 1355)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(out.values[0], 130.0, "oracle 1 cpu");
        assert_output_close(out.values[1], 47.15, "oracle 1 power");
        assert_eq!(out.cpu_output_unapplied_modules, 0);
        assert_eq!(out.power_output_unapplied_modules, 0);
        // Two units both ways (two slots then one quantity-2 row)
        let two_slots = fitting(
            587,
            vec![item("LoSlot0", 1, 1355), item("LoSlot1", 1, 1355)],
        );
        let out = bonused_outputs(&two_slots, &catalogue, None).expect("Some");
        assert_output_close(out.values[1], 54.2225, "oracle 1 two slots");
        let stacked = fitting(587, vec![item("LoSlot0", 2, 1355)]);
        let out = bonused_outputs(&stacked, &catalogue, None).expect("Some");
        assert_output_close(out.values[1], 54.2225, "oracle 1 stacked");
        // Oracle 2: MAPC flat add
        let fit = fitting(587, vec![item("LoSlot0", 1, 4254)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(out.values[1], 53.0, "oracle 2 power");
        assert_output_close(out.values[0], 130.0, "oracle 2 cpu");
        let fit = fitting(587, vec![item("LoSlot0", 2, 4254)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(out.values[1], 65.0, "oracle 2 stacked");
        // Oracle 3: Co-Processor
        let fit = fitting(587, vec![item("LoSlot0", 1, 3888)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(out.values[0], 143.0, "oracle 3 cpu");
        assert_output_close(out.values[1], 41.0, "oracle 3 power");
        assert_eq!(out.cpu_output_unapplied_modules, 0);
        assert_eq!(out.power_output_unapplied_modules, 0);
        // Oracle 4: PDS dual + two multipliers
        let fit = fitting(587, vec![item("LoSlot0", 1, 1541)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(out.values[1], 43.46, "oracle 4a power");
        assert_output_close(out.values[0], 130.0, "oracle 4a cpu");
        let fit = fitting(
            587,
            vec![item("LoSlot0", 1, 1541), item("LoSlot1", 1, 1355)],
        );
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(out.values[1], 49.979, "oracle 4b power");
        let fit = fitting(
            587,
            vec![item("LoSlot0", 1, 1355), item("LoSlot1", 1, 1541)],
        );
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(out.values[1], 49.979, "oracle 4b reversed");
        // Oracle 6: rig percents
        let fit = fitting(587, vec![item("RigSlot0", 1, 4399)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(out.values[0], 142.48, "oracle 6a cpu");
        assert_output_close(out.values[1], 41.0, "oracle 6a power");
        let fit = fitting(587, vec![item("RigSlot0", 1, 26370)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(out.values[1], 47.15, "oracle 6b power");
        let fit = fitting(
            587,
            vec![item("RigSlot0", 1, 26370), item("RigSlot1", 1, 25956)],
        );
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(out.values[1], 51.865, "oracle 6c power");
        // Oracle 6(d): non-counted flags never contribute
        let fit = fitting(587, vec![item("Cargo", 1, 4399)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_eq!(out.values[0], Some(130.0));
        assert_eq!(out.values[1], Some(41.0));
        assert_eq!(out.cpu_output_unapplied_modules, 0);
        assert_eq!(out.power_output_unapplied_modules, 0);
        // Oracle 7: drawback shrinks the output
        let fit = fitting(587, vec![item("RigSlot0", 1, 25908)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(out.values[0], 117.0, "oracle 7 cpu");
        // Oracle 8: absent-split, exact identity under the
        // marked carrier with the count still raised
        let fit = fitting(587, vec![item("LoSlot0", 1, 1445)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_eq!(out.values[0], Some(130.0));
        assert_eq!(out.values[1], Some(41.0));
        assert_eq!(out.cpu_output_unapplied_modules, 0);
        assert_eq!(out.power_output_unapplied_modules, 1);
        let fit = fitting(587, vec![item("LoSlot0", 2, 1445)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_eq!(out.power_output_unapplied_modules, 2);
        let fit = fitting(587, vec![item("LoSlot0", 1, 1445)]);
        let out = bonused_outputs(&fit, &catalogue, Some((5, 5))).expect("Some");
        assert_eq!(out.values[1], Some(51.25));
        assert_eq!(out.power_output_unapplied_modules, 1);
        // Oracle 10 helper side: 5x DC + Co-Processor
        let items: Vec<FittingItem> = (0..5)
            .map(|n| item(&format!("LoSlot{n}"), 1, 2048))
            .chain([item("LoSlot5", 1, 3888)])
            .collect();
        let out = bonused_outputs(&fitting(587, items), &catalogue, None).expect("Some");
        assert_output_close(out.values[0], 143.0, "oracle 10 cpu");
    }

    #[test]
    fn bonused_outputs_composition_and_identity() {
        let catalogue = bundled();
        // Oracle 5: adds before skill percent, on the helper
        let fit = fitting(
            587,
            vec![
                item("LoSlot0", 1, 1355),
                item("LoSlot1", 1, 3888),
                item("LoSlot2", 1, 4254),
            ],
        );
        let none = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_output_close(none.values[0], 143.0, "oracle 5 cpu None");
        assert_output_close(none.values[1], 60.95, "oracle 5 power None");
        let zero = bonused_outputs(&fit, &catalogue, Some((0, 0))).expect("Some");
        assert_eq!(zero.values, none.values);
        assert_eq!(
            zero.cpu_output_unapplied_modules,
            none.cpu_output_unapplied_modules
        );
        assert_eq!(
            zero.power_output_unapplied_modules,
            none.power_output_unapplied_modules
        );
        let skilled = bonused_outputs(&fit, &catalogue, Some((5, 5))).expect("Some");
        assert_output_close(skilled.values[0], 178.75, "oracle 5 cpu skilled");
        assert_output_close(skilled.values[1], 76.1875, "oracle 5 power skilled");
        // Internal re-clamp: Some((99, -1)) equals Some((5, 0))
        let reclamped = bonused_outputs(&fit, &catalogue, Some((99, -1))).expect("Some");
        let clamped = bonused_outputs(&fit, &catalogue, Some((5, 0))).expect("Some");
        assert_eq!(reclamped.values, clamped.values);
        assert_eq!(
            reclamped.cpu_output_unapplied_modules,
            clamped.cpu_output_unapplied_modules
        );
        assert_eq!(
            reclamped.power_output_unapplied_modules,
            clamped.power_output_unapplied_modules
        );
        // Oracle 7 at CPU Management 5: 117.0 * 1.25 = 146.25
        let fit = fitting(587, vec![item("RigSlot0", 1, 25908)]);
        let out = bonused_outputs(&fit, &catalogue, Some((5, 0))).expect("Some");
        assert_output_close(out.values[0], 146.25, "oracle 7 skilled");
        // Oracle 9: bit-exact association (assert_eq against
        // the locked order, not within tolerance)
        let fit = fitting(587, vec![item("RigSlot0", 1, 26370)]);
        let out = bonused_outputs(&fit, &catalogue, Some((0, 5))).expect("Some");
        assert_eq!(
            out.values[1],
            Some((41.0 + 0.0) * 1.0 * ((1.0 * 1.25) * 1.15))
        );
        let fit = fitting(587, vec![item("RigSlot0", 1, 4399)]);
        let out = bonused_outputs(&fit, &catalogue, Some((5, 0))).expect("Some");
        assert_eq!(
            out.values[0],
            Some((130.0 + 0.0) * 1.0 * ((1.0 * 1.25) * (1.0 + 9.6 / 100.0)))
        );
        let fit = fitting(587, vec![item("RigSlot0", 1, 25908)]);
        let out = bonused_outputs(&fit, &catalogue, Some((2, 0))).expect("Some");
        assert_output_close(out.values[0], 128.7, "oracle 9c");
        // Empty == base exactly on both arms; None equals
        // Some((0, 0)); skill factor bit-identical to shipped
        let hull_only = fitting(587, vec![]);
        let none = bonused_outputs(&hull_only, &catalogue, None).expect("Some");
        assert_eq!(none.values, [Some(130.0), Some(41.0)]);
        assert_eq!(none.cpu_output_unapplied_modules, 0);
        assert_eq!(none.power_output_unapplied_modules, 0);
        let zero = bonused_outputs(&hull_only, &catalogue, Some((0, 0))).expect("Some");
        assert_eq!(zero.values, none.values);
        for level in 0..=5 {
            let out = bonused_outputs(&hull_only, &catalogue, Some((level, level))).expect("Some");
            assert_eq!(out.values[0], Some(130.0 * (1.0 + 0.05 * level as f64)));
            assert_eq!(out.values[1], Some(41.0 * (1.0 + 0.05 * level as f64)));
        }
        // Ship gate: helper None exactly on gate
        for ship in [999999, 2048, 0, -1] {
            assert!(
                bonused_outputs(&fitting(ship, vec![]), &catalogue, None).is_none(),
                "ship {ship}"
            );
        }
        // Catalogue-absent counted rows are not counted by
        // this helper (the resources-side excluded rule owns
        // them): a fully absent rig leaves values at base
        // with no unapplied count.
        let fit = fitting(587, vec![item("RigSlot0", 1, 999999)]);
        let out = bonused_outputs(&fit, &catalogue, None).expect("Some");
        assert_eq!(out.values, [Some(130.0), Some(41.0)]);
        assert_eq!(out.cpu_output_unapplied_modules, 0);
        assert_eq!(out.power_output_unapplied_modules, 0);
    }

    #[test]
    fn bonused_outputs_partiality_zero_and_hostile() {
        // Absent base never resurrected, per dimension
        let hull = r#"{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0}"#;
        let no_power = FittingTypes::from_json(
            r#"{"types":[{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"cpuOutput":130.0},
                {"typeId":101,"typeName":"Mapc","categoryId":7,"slotEffects":[11],"powerOutputModifiers":[[11,2,12.0]]}]}"#,
        )
        .expect("fixture parses");
        let out = bonused_outputs(&fitting(42, vec![item("LoSlot0", 1, 101)]), &no_power, None)
            .expect("Some");
        assert_eq!(out.values, [Some(130.0), None]);
        let no_cpu = FittingTypes::from_json(
            r#"{"types":[{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"powerOutput":41.0},
                {"typeId":101,"typeName":"Coproc","categoryId":7,"slotEffects":[11],"cpuOutputModifiers":[[48,4,1.1]]}]}"#,
        )
        .expect("fixture parses");
        let out = bonused_outputs(&fitting(42, vec![item("LoSlot0", 1, 101)]), &no_cpu, None)
            .expect("Some");
        assert_eq!(out.values, [None, Some(41.0)]);
        // Present 0.0 is a real zero: a flat add raises it,
        // a -100% percent zeroes it honestly.
        let zero_hull = FittingTypes::from_json(
            r#"{"types":[{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":0.0},
                {"typeId":101,"typeName":"Mapc","categoryId":7,"slotEffects":[11],"powerOutputModifiers":[[11,2,12.0]]}]}"#,
        )
        .expect("fixture parses");
        let out = bonused_outputs(
            &fitting(42, vec![item("LoSlot0", 1, 101)]),
            &zero_hull,
            None,
        )
        .expect("Some");
        assert_eq!(out.values[1], Some(12.0));
        assert_eq!(out.values[0], Some(130.0));
        let minus_hundred = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Zero","categoryId":7,"slotEffects":[11],"powerOutputModifiers":[[11,6,-100.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let out = bonused_outputs(
            &fitting(42, vec![item("LoSlot0", 1, 101)]),
            &minus_hundred,
            None,
        )
        .expect("Some");
        assert_eq!(out.values[1], Some(0.0));

        // hostile -20% rig stalls to a positive subnormal
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"powerOutputModifiers":[[11,6,-20.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let out = bonused_outputs(
            &fitting(42, vec![item("RigSlot0", i64::MAX, 101)]),
            &catalogue,
            None,
        )
        .expect("Some");
        assert_eq!(out.values[1], None);
        assert_eq!(out.values[0], Some(130.0));
        // Real 25908 (0.9) stalls subnormal under shipped
        // mul_product (settles at 0x0.0000000000005p-1022)
        let catalogue = bundled();
        let out = bonused_outputs(
            &fitting(587, vec![item("RigSlot0", i64::MAX, 25908)]),
            &catalogue,
            None,
        )
        .expect("Some");
        assert_eq!(out.values[0], None);
        assert_eq!(out.values[1], Some(41.0));
        // Real 1355 (1.15) overflows non-finite
        let out = bonused_outputs(
            &fitting(587, vec![item("LoSlot0", i64::MAX, 1355)]),
            &catalogue,
            None,
        )
        .expect("Some");
        assert_eq!(out.values[1], None);
        // Real 4254 flat add stays finite by formula
        let out = bonused_outputs(
            &fitting(587, vec![item("LoSlot0", i64::MAX, 4254)]),
            &catalogue,
            None,
        )
        .expect("Some");
        assert_eq!(out.values[1], Some(41.0 + 12.0 * (i64::MAX as f64)));
        // Negative results are no data
        for entries in ["[[11,6,-150.0]]", "[[11,4,-1.15]]"] {
            let catalogue = FittingTypes::from_json(
                &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Neg","categoryId":7,"slotEffects":[11],"powerOutputModifiers":{entries}}}]}}"#),
            )
            .expect("fixture parses");
            let out = bonused_outputs(
                &fitting(42, vec![item("LoSlot0", 1, 101)]),
                &catalogue,
                None,
            )
            .expect("Some");
            assert_eq!(out.values[1], None, "entries {entries}");
        }
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"NegAdd","categoryId":7,"slotEffects":[11],"powerOutputModifiers":[[11,2,-50.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let out = bonused_outputs(
            &fitting(42, vec![item("LoSlot0", 1, 101)]),
            &catalogue,
            None,
        )
        .expect("Some");
        assert_eq!(out.values[1], None);
    }

    #[test]
    fn bonused_outputs_runtime_guards() {
        let hull = r#"{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0}"#;
        // Marked-unapplied with an applicable entry: counted
        // once, entry still applied.
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Marked","categoryId":7,"slotEffects":[11],"powerOutputModifiers":[[11,4,1.15]],"powerOutputModifiersUnapplied":true}}]}}"#),
        )
        .expect("fixture parses");
        let out = bonused_outputs(
            &fitting(42, vec![item("LoSlot0", 1, 101)]),
            &catalogue,
            None,
        )
        .expect("Some");
        assert_eq!(out.power_output_unapplied_modules, 1);
        assert_eq!(out.cpu_output_unapplied_modules, 0);
        assert_output_close(out.values[1], 47.15, "marked still applied");
        // Unsupported operators count once in that family
        // only and contribute nothing (a non-finite operand
        // shares this same guard branch; JSON cannot carry
        // one, so the zero-operand case below pins it).
        for operator in [0, 3, 5, 7] {
            let catalogue = FittingTypes::from_json(
                &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[11],"powerOutputModifiers":[[11,{operator},1.15]]}}]}}"#),
            )
            .expect("fixture parses");
            let out = bonused_outputs(
                &fitting(42, vec![item("LoSlot0", 1, 101)]),
                &catalogue,
                None,
            )
            .expect("Some");
            assert_eq!(out.power_output_unapplied_modules, 1, "operator {operator}");
            assert_eq!(out.cpu_output_unapplied_modules, 0, "operator {operator}");
            assert_eq!(out.values[1], Some(41.0), "operator {operator}");
            assert_eq!(out.values[0], Some(130.0), "operator {operator}");
        }
        // Two bad entries on one item still count once; a
        // good entry on the same item still applies.
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[11],"powerOutputModifiers":[[11,0,1.15],[11,3,1.2],[11,4,1.1]]}}]}}"#),
        )
        .expect("fixture parses");
        let out = bonused_outputs(
            &fitting(42, vec![item("LoSlot0", 1, 101)]),
            &catalogue,
            None,
        )
        .expect("Some");
        assert_eq!(out.power_output_unapplied_modules, 1);
        assert_output_close(out.values[1], 45.1, "good still applies");
        // Wrong modified ids count in the family they sit in
        // only; the other dimension is untouched.
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[11],"powerOutputModifiers":[[482,4,1.15]]}}]}}"#),
        )
        .expect("fixture parses");
        let out = bonused_outputs(
            &fitting(42, vec![item("LoSlot0", 1, 101)]),
            &catalogue,
            None,
        )
        .expect("Some");
        assert_eq!(out.power_output_unapplied_modules, 1);
        assert_eq!(out.cpu_output_unapplied_modules, 0);
        assert_eq!(out.values, [Some(130.0), Some(41.0)]);
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[11],"cpuOutputModifiers":[[11,4,1.15]]}}]}}"#),
        )
        .expect("fixture parses");
        let out = bonused_outputs(
            &fitting(42, vec![item("LoSlot0", 1, 101)]),
            &catalogue,
            None,
        )
        .expect("Some");
        assert_eq!(out.cpu_output_unapplied_modules, 1);
        assert_eq!(out.power_output_unapplied_modules, 0);
        assert_eq!(out.values, [Some(130.0), Some(41.0)]);
        // Zero operand counts once and contributes nothing
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[11],"powerOutputModifiers":[[11,4,0.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let out = bonused_outputs(
            &fitting(42, vec![item("LoSlot0", 1, 101)]),
            &catalogue,
            None,
        )
        .expect("Some");
        assert_eq!(out.power_output_unapplied_modules, 1);
        assert_eq!(out.cpu_output_unapplied_modules, 0);
        assert_eq!(out.values[1], Some(41.0));
        // The grounded-but-uncensused CPU flat add applies
        // as a flat add, composed with the skill percent.
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"CpuAdd","categoryId":7,"slotEffects":[11],"cpuOutputModifiers":[[48,2,25.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let out = bonused_outputs(
            &fitting(42, vec![item("LoSlot0", 1, 101)]),
            &catalogue,
            None,
        )
        .expect("Some");
        assert_output_close(out.values[0], 155.0, "cpu add");
        let out = bonused_outputs(
            &fitting(42, vec![item("LoSlot0", 1, 101)]),
            &catalogue,
            Some((5, 0)),
        )
        .expect("Some");
        assert_output_close(out.values[0], 193.75, "cpu add skilled");
    }
}
