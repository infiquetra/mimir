//! Pure ship base stats calculation over the bundled catalogue.
//!
//! [`ship_base_stats`] reads the hull's base shield, armor, and
//! hull hit points, capacitor capacity, and maximum velocity for
//! one [`CharacterFitting`] from base (unmodified) dogma
//! attributes only. No modifier of any kind is applied: fitted
//! modules, rigs, subsystems, skills, implants, and ship bonuses
//! contribute nothing, so the values describe the bare hull and
//! can differ from EVE. See
//! `docs/ship-base-stats-design.md`.
//!
//! The module is pure computation over the bundled catalogue — no
//! egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] and [`FittingTypes`], the same
//! dependencies `resources.rs` takes. It logs nothing: it runs at
//! render cadence, so per-frame `[FITTING]` logging would spam
//! the log; the catalogue load already logs counts once.

use crate::esi::models::CharacterFitting;
use crate::names::fitting_types::FittingTypes;

/// One hull's base ship values. Each field is the catalogue
/// value when usable (present, finite, non-negative); a present
/// `0.0` stays a real zero. `None` means no data for that stat:
/// the caller omits the line, never renders a zero.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ShipBaseStats {
    pub shield_capacity: Option<f64>,
    pub armor_hp: Option<f64>,
    pub hull_hp: Option<f64>,
    pub capacitor_capacity: Option<f64>,
    pub max_velocity: Option<f64>,
}

/// Base ship values outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ShipBaseStatsOutcome {
    Available(ShipBaseStats),
    /// The catalogue has no usable base ship data for this
    /// fitting's ship, so no honest numbers exist.
    Unavailable,
}

/// A catalogue value is usable only when present, finite, and
/// non-negative. A present `0.0` stays a real zero; anything else
/// is treated as no data for that stat (`resources.rs` uses the
/// same rule for its dimensions).
fn usable(value: Option<f64>) -> Option<f64> {
    value.filter(|v| v.is_finite() && *v >= 0.0)
}

/// Base ship values for one fitting. The fitting's items are
/// never read, and availability is independent of
/// [`crate::fitting::resources::FittingResources`]: this function
/// keys off the five base stat fields only.
pub fn ship_base_stats(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> ShipBaseStatsOutcome {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        return ShipBaseStatsOutcome::Unavailable;
    };
    if ship.category_id != 6 {
        return ShipBaseStatsOutcome::Unavailable;
    }
    let stats = ShipBaseStats {
        shield_capacity: usable(ship.shield_capacity),
        armor_hp: usable(ship.armor_hp),
        hull_hp: usable(ship.hull_hp),
        capacitor_capacity: usable(ship.capacitor_capacity),
        max_velocity: usable(ship.max_velocity),
    };
    if stats.shield_capacity.is_none()
        && stats.armor_hp.is_none()
        && stats.hull_hp.is_none()
        && stats.capacitor_capacity.is_none()
        && stats.max_velocity.is_none()
    {
        return ShipBaseStatsOutcome::Unavailable;
    }
    ShipBaseStatsOutcome::Available(stats)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::resources::fitting_resources;

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

    fn available(result: ShipBaseStatsOutcome) -> ShipBaseStats {
        match result {
            ShipBaseStatsOutcome::Available(stats) => stats,
            ShipBaseStatsOutcome::Unavailable => panic!("expected Available, got Unavailable"),
        }
    }

    // Oracle rows read from scripts/sde/dgmTypeAttributes.csv.bz2
    // (every row has valueInt None, valueFloat shown):
    // Rifter 587: 263 450.0, 265 450.0, 9 350.0, 482 250.0,
    // 37 365.0. Punisher 597: 350.0, 500.0, 450.0, 400.0, 355.0.
    // Legion 29986: 1800.0, 2900.0, 1800.0, 1800.0, 185.0.
    // Raven 638: 7700.0, 6380.0, 7040.0, 5500.0, 113.0.
    #[test]
    fn oracle_ships_return_all_five_literal_values() {
        let catalogue = bundled();
        let cases = [
            (587, 450.0, 450.0, 350.0, 250.0, 365.0),
            (597, 350.0, 500.0, 450.0, 400.0, 355.0),
            (29986, 1800.0, 2900.0, 1800.0, 1800.0, 185.0),
            (638, 7700.0, 6380.0, 7040.0, 5500.0, 113.0),
        ];
        for (ship_type_id, shield, armor, hull, capacitor, velocity) in cases {
            let stats = available(ship_base_stats(&fitting(ship_type_id, vec![]), &catalogue));
            assert_eq!(stats.shield_capacity, Some(shield), "ship {ship_type_id}");
            assert_eq!(stats.armor_hp, Some(armor), "ship {ship_type_id}");
            assert_eq!(stats.hull_hp, Some(hull), "ship {ship_type_id}");
            assert_eq!(
                stats.capacitor_capacity,
                Some(capacitor),
                "ship {ship_type_id}"
            );
            assert_eq!(stats.max_velocity, Some(velocity), "ship {ship_type_id}");
        }
    }

    // Fractional pins from the same cache: Echelon 3532
    // capacitor 187.5, Helios 11172 capacitor 218.75, Mekubal
    // 78333 velocity 322.3. Exact in the API; only display rounds.
    #[test]
    fn fractional_values_are_exact_in_the_api() {
        let catalogue = bundled();
        let echelon = available(ship_base_stats(&fitting(3532, vec![]), &catalogue));
        assert_eq!(echelon.capacitor_capacity, Some(187.5));
        let helios = available(ship_base_stats(&fitting(11172, vec![]), &catalogue));
        assert_eq!(helios.capacitor_capacity, Some(218.75));
        let mekubal = available(ship_base_stats(&fitting(78333, vec![]), &catalogue));
        assert_eq!(mekubal.max_velocity, Some(322.3));
    }

    // The no-modifiers lock as a test: fitted modules — including
    // an unknown type and a stacked quantity — change nothing.
    #[test]
    fn fitted_items_are_ignored() {
        let catalogue = bundled();
        let hull_only = ship_base_stats(&fitting(587, vec![]), &catalogue);
        let fitted = ship_base_stats(
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
            let result = ship_base_stats(&fitting(ship_type_id, vec![]), &catalogue);
            assert_eq!(
                result,
                ShipBaseStatsOutcome::Unavailable,
                "ship {ship_type_id}"
            );
        }
    }

    // Absent versus zero, via fixture catalogue: shipped data has
    // no such ship (all 404 ships carry all five positive values),
    // so only fixtures can exercise the distinction.
    #[test]
    fn absent_stat_is_none_and_present_zero_renders() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"armorHP":0.0,"hp":350.0,"capacitorCapacity":250.0,"maxVelocity":365.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let stats = available(ship_base_stats(&fitting(42, vec![]), &catalogue));
        assert_eq!(stats.shield_capacity, None);
        assert_eq!(stats.armor_hp, Some(0.0));
        assert_eq!(stats.hull_hp, Some(350.0));
        assert_eq!(stats.capacitor_capacity, Some(250.0));
        assert_eq!(stats.max_velocity, Some(365.0));
    }

    #[test]
    fn all_absent_collapses_to_unavailable_and_single_stat_stays_available() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Bare Hull","categoryId":6,"slotEffects":[]},
                {"typeId":43,"typeName":"Lone Stat","categoryId":6,"slotEffects":[],"shieldCapacity":450.0}]}"#,
        )
        .expect("fixture catalogue parses");
        assert_eq!(
            ship_base_stats(&fitting(42, vec![]), &catalogue),
            ShipBaseStatsOutcome::Unavailable
        );
        let stats = available(ship_base_stats(&fitting(43, vec![]), &catalogue));
        assert_eq!(stats.shield_capacity, Some(450.0));
        assert_eq!(stats.armor_hp, None);
        assert_eq!(stats.hull_hp, None);
        assert_eq!(stats.capacitor_capacity, None);
        assert_eq!(stats.max_velocity, None);
    }

    // Guard pin: a negative catalogue value is no data for that
    // stat only; the other stats still render. JSON cannot spell
    // NaN, so the non-finite half is pinned through the shared
    // usable rule's symmetry with resources.rs, whose tests
    // already pin it directly.
    #[test]
    fn negative_value_is_no_data_for_that_stat_only() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"shieldCapacity":-1.0,"armorHP":450.0,"hp":350.0,"capacitorCapacity":250.0,"maxVelocity":365.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let stats = available(ship_base_stats(&fitting(42, vec![]), &catalogue));
        assert_eq!(stats.shield_capacity, None);
        assert_eq!(stats.armor_hp, Some(450.0));
        assert_eq!(stats.hull_hp, Some(350.0));
        assert_eq!(stats.capacitor_capacity, Some(250.0));
        assert_eq!(stats.max_velocity, Some(365.0));
    }

    #[test]
    fn usable_guard_rejects_non_finite_and_negative() {
        assert_eq!(usable(Some(2.5)), Some(2.5));
        assert_eq!(usable(Some(0.0)), Some(0.0));
        assert_eq!(usable(None), None);
        assert_eq!(usable(Some(-1.0)), None);
        assert_eq!(usable(Some(f64::INFINITY)), None);
        assert_eq!(usable(Some(f64::NEG_INFINITY)), None);
        assert_eq!(usable(Some(f64::NAN)), None);
    }

    // Independence from resources, in both directions (fixtures):
    // outputs without stats give resources Available and stats
    // Unavailable; stats without outputs give the reverse.
    #[test]
    fn availability_is_independent_of_resources() {
        let outputs_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Outputs Only","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        assert!(matches!(
            fitting_resources(&fit, &outputs_only),
            crate::fitting::resources::FittingResources::Available { .. }
        ));
        assert_eq!(
            ship_base_stats(&fit, &outputs_only),
            ShipBaseStatsOutcome::Unavailable
        );

        let stats_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":43,"typeName":"Stats Only","categoryId":6,"slotEffects":[],"shieldCapacity":450.0,"armorHP":450.0,"hp":350.0,"capacitorCapacity":250.0,"maxVelocity":365.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(43, vec![]);
        assert_eq!(
            fitting_resources(&fit, &stats_only),
            crate::fitting::resources::FittingResources::ShipNoOutput
        );
        assert!(matches!(
            ship_base_stats(&fit, &stats_only),
            ShipBaseStatsOutcome::Available(_)
        ));
    }

    // Real-catalogue companion: the Echelon (3532) is a
    // present-zero-output ship whose stats are fully Available —
    // resources reads 0.0/0.0 outputs while the stats block shows
    // real hull numbers (cache: 3532 outputs 0.0/0.0, stats
    // 235.0/305.0/274.0/187.5/404.0).
    #[test]
    fn echelon_zero_outputs_with_full_stats() {
        let catalogue = bundled();
        let fit = fitting(3532, vec![]);
        match fitting_resources(&fit, &catalogue) {
            crate::fitting::resources::FittingResources::Available { cpu, power } => {
                assert_eq!(cpu.output, 0.0);
                assert_eq!(power.output, 0.0);
            }
            crate::fitting::resources::FittingResources::ShipNoOutput => {
                panic!("Echelon resources must be Available with 0.0 outputs")
            }
        }
        let stats = available(ship_base_stats(&fit, &catalogue));
        assert_eq!(stats.shield_capacity, Some(235.0));
        assert_eq!(stats.armor_hp, Some(305.0));
        assert_eq!(stats.hull_hp, Some(274.0));
        assert_eq!(stats.capacitor_capacity, Some(187.5));
        assert_eq!(stats.max_velocity, Some(404.0));
    }
}
