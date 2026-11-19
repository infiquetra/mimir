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
}
