//! Pure ship base resistances calculation over the bundled catalogue.
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
}
