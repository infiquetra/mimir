//! Pure rig-calibration calculation over the bundled catalogue.
//!
//! [`rig_calibration`] computes rig calibration used versus the
//! hull's base calibration for one [`CharacterFitting`] from base
//! (unmodified) catalogue data only: a plain sum of rig
//! calibration costs over rig-slot rows against dogma 1132
//! `upgradeCapacity` (unit 120 `points`). See
//! `docs/rig-calibration-design.md`.
//!
//! The module is pure computation over the bundled catalogue — no
//! egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] / [`FittingItem`] and [`FittingTypes`],
//! the same dependencies the EFT parser already takes. It tests
//! the `RigSlot` flag prefix itself instead of depending on the
//! UI enum, following the [`crate::fitting::resources`]
//! flag-prefix independence precedent. It logs nothing: it runs
//! at render cadence, so per-frame `[FITTING]` logging would spam
//! the log; the catalogue load already logs counts once.
//!
//! Sources, locked by the design: ship capacity is dogma 1132
//! `upgradeCapacity` (unit 120 `attributePoints`, display
//! `points`); rig cost is dogma 1153 `upgradeCost` (unitless in
//! dogma, same points in game). Dogma 560
//! `cloakingTargetingDelay` is the recalibration decoy and is
//! never read. Flutter at `ed698d3` read 1153 as the ship
//! capacity behind a magic `400` fallback (computed but never
//! displayed); this slice reads 1132 as capacity and 1153 as
//! cost with no fallback of any kind.

use crate::esi::models::{CharacterFitting, FittingItem};
use crate::names::fitting_types::FittingTypes;

/// Base rig calibration for one fitting: plain rig-cost sum over
/// counted rig-slot rows against the hull's base calibration.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CalibrationBudget {
    pub used: f64,
    pub capacity: f64,
    /// Rig-slot rows with no usable cost (absent from the
    /// catalogue, no cost row, or an unusable value). Counted
    /// in quantity units, never silently zero.
    pub excluded_rigs: usize,
}

impl CalibrationBudget {
    pub fn remaining(&self) -> f64 {
        self.capacity - self.used
    }

    pub fn is_over(&self) -> bool {
        self.used > self.capacity
    }
}

/// Base rig-calibration outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum CalibrationOutcome {
    Available(CalibrationBudget),
    /// The catalogue has no usable calibration data for this
    /// fitting's ship, so no honest numbers exist.
    Unavailable,
}

/// A catalogue value is usable only when present, finite, and
/// non-negative. A present `0.0` stays a real zero; anything else
/// is treated as no data for that dimension.
fn usable(value: Option<f64>) -> Option<f64> {
    value.filter(|v| v.is_finite() && *v >= 0.0)
}

/// Base rig calibration for one fitting. Ship resolution mirrors
/// `resources.rs`: `ship_type_id` must be positive, resolve in
/// the catalogue, and be category 6 with a usable
/// `upgrade_capacity`, else `Unavailable`. Every item under a
/// `RigSlot` flag prefix with `type_id > 0` and positive quantity
/// contributes `quantity * upgrade_cost` when usable, otherwise
/// one excluded count per quantity unit.
pub fn rig_calibration(fitting: &CharacterFitting, catalogue: &FittingTypes) -> CalibrationOutcome {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        return CalibrationOutcome::Unavailable;
    };
    if ship.category_id != 6 {
        return CalibrationOutcome::Unavailable;
    }
    let Some(capacity) = usable(ship.upgrade_capacity) else {
        return CalibrationOutcome::Unavailable;
    };

    let mut used: f64 = 0.0;
    let mut excluded_rigs: usize = 0;
    for item in &fitting.items {
        if !rig_item(item) {
            continue;
        }
        let quantity = item.quantity.max(0);
        if quantity == 0 {
            continue;
        }
        let quantity_f = quantity as f64;
        // Excluded counts rigs, matching the multiplied sums:
        // a stacked row of five unknown rigs reports five.
        let quantity_units = usize::try_from(quantity).unwrap_or(0);
        match catalogue
            .lookup_by_id(item.type_id)
            .and_then(|row| usable(row.upgrade_cost))
        {
            Some(cost) => used += quantity_f * cost,
            None => excluded_rigs = excluded_rigs.saturating_add(quantity_units),
        }
    }

    CalibrationOutcome::Available(CalibrationBudget {
        used,
        capacity,
        excluded_rigs,
    })
}

fn rig_item(item: &FittingItem) -> bool {
    item.type_id > 0 && item.flag.starts_with("RigSlot")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fitting::dna::parse_dna;
    use crate::fitting::eft::{parse_eft, EftImportOutcome};
    use crate::fitting::resources::fitting_resources;

    fn item(flag: &str, quantity: i64, type_id: i64) -> FittingItem {
        FittingItem {
            flag: flag.to_string(),
            quantity,
            type_id,
        }
    }

    fn fitting(ship_type_id: i64, items: Vec<FittingItem>) -> CharacterFitting {
        CharacterFitting {
            fitting_id: 1,
            name: "test".to_string(),
            description: None,
            ship_type_id,
            items,
        }
    }

    fn bundled() -> FittingTypes {
        FittingTypes::load_bundled().expect("bundled catalogue loads")
    }

    fn available(outcome: CalibrationOutcome) -> CalibrationBudget {
        match outcome {
            CalibrationOutcome::Available(budget) => budget,
            CalibrationOutcome::Unavailable => panic!("expected Available, got Unavailable"),
        }
    }

    fn assert_close(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "expected {expected}, got {actual}"
        );
    }

    // Oracle rows read from scripts/sde/dgmTypeAttributes.csv.bz2:
    // (587, 1132) = 400.0, (597, 1132) = 400.0; (588, 1132) = 0.0
    // present; (31668, 1153) = 200.0; (25736, 1153) = 50.0;
    // (4395, 1153) = 150.0; (4399, 1153) = 300.0.
    #[test]
    fn hull_only_rifter_has_zero_used_and_full_remaining() {
        let catalogue = bundled();
        let budget = available(rig_calibration(&fitting(587, vec![]), &catalogue));
        assert_close(budget.used, 0.0);
        assert_close(budget.capacity, 400.0);
        assert_close(budget.remaining(), 400.0);
        assert_eq!(budget.excluded_rigs, 0);
        assert!(!budget.is_over());
    }

    #[test]
    fn one_counted_rig() {
        let catalogue = bundled();
        // 1 * 200.0 = 200.0 of 400.0, remaining 400.0 - 200.0 = 200.0.
        let budget = available(rig_calibration(
            &fitting(587, vec![item("RigSlot0", 1, 31668)]),
            &catalogue,
        ));
        assert_close(budget.used, 200.0);
        assert_close(budget.capacity, 400.0);
        assert_close(budget.remaining(), 200.0);
        assert_eq!(budget.excluded_rigs, 0);
        assert!(!budget.is_over());
    }

    #[test]
    fn exactly_at_capacity() {
        let catalogue = bundled();
        // 200.0 + 150.0 + 50.0 = 400.0 of 400.0, remaining 0.0.
        let budget = available(rig_calibration(
            &fitting(
                587,
                vec![
                    item("RigSlot0", 1, 31668),
                    item("RigSlot1", 1, 4395),
                    item("RigSlot2", 1, 25736),
                ],
            ),
            &catalogue,
        ));
        assert_close(budget.used, 400.0);
        assert_close(budget.capacity, 400.0);
        assert_close(budget.remaining(), 0.0);
        assert_eq!(budget.excluded_rigs, 0);
        assert!(!budget.is_over());
    }

    #[test]
    fn over_capacity() {
        let catalogue = bundled();
        // 300.0 + 150.0 = 450.0 of 400.0, remaining 400.0 - 450.0 = -50.0.
        let budget = available(rig_calibration(
            &fitting(
                587,
                vec![item("RigSlot0", 1, 4399), item("RigSlot1", 1, 4395)],
            ),
            &catalogue,
        ));
        assert_close(budget.used, 450.0);
        assert_close(budget.capacity, 400.0);
        assert_close(budget.remaining(), -50.0);
        assert!(budget.is_over());
        assert_eq!(budget.excluded_rigs, 0);
    }

    #[test]
    fn present_zero_capacity_is_available() {
        let catalogue = bundled();
        // Reaper 588 carries 1132 present as 0.0: renders 0.0 of 0.0.
        let budget = available(rig_calibration(&fitting(588, vec![]), &catalogue));
        assert_close(budget.used, 0.0);
        assert_close(budget.capacity, 0.0);
        assert!(!budget.is_over());
        // 200.0 of 0.0 is over.
        let budget = available(rig_calibration(
            &fitting(588, vec![item("RigSlot0", 1, 31668)]),
            &catalogue,
        ));
        assert_close(budget.used, 200.0);
        assert_close(budget.capacity, 0.0);
        assert!(budget.is_over());
    }

    #[test]
    fn absent_capacity_is_unavailable() {
        let catalogue = bundled();
        for ship_type_id in [670, 2863, 33328] {
            let outcome = rig_calibration(
                &fitting(ship_type_id, vec![item("RigSlot0", 1, 31668)]),
                &catalogue,
            );
            assert_eq!(
                outcome,
                CalibrationOutcome::Unavailable,
                "ship {ship_type_id}"
            );
        }
    }

    #[test]
    fn non_modal_capacities_trip_the_fallback() {
        let catalogue = bundled();
        // Revenant 3514 = 350.0, Opux 635 = 300.0, Caldari Shuttle 672 = 1.0.
        // Any hidden 400 fallback fails these literally.
        let budget = available(rig_calibration(&fitting(3514, vec![]), &catalogue));
        assert_close(budget.capacity, 350.0);
        let budget = available(rig_calibration(&fitting(635, vec![]), &catalogue));
        assert_close(budget.capacity, 300.0);
        // 50.0 of 1.0 is over.
        let budget = available(rig_calibration(
            &fitting(672, vec![item("RigSlot0", 1, 25736)]),
            &catalogue,
        ));
        assert_close(budget.used, 50.0);
        assert_close(budget.capacity, 1.0);
        assert!(budget.is_over());
    }

    #[test]
    fn unknown_and_dataless_rig_rows_are_excluded_not_zeroed() {
        let catalogue = bundled();
        // 999999 absent from catalogue, 2048 has no cost row.
        let budget = available(rig_calibration(
            &fitting(
                587,
                vec![item("RigSlot0", 1, 999999), item("RigSlot1", 1, 2048)],
            ),
            &catalogue,
        ));
        assert_close(budget.used, 0.0);
        assert_eq!(budget.excluded_rigs, 2);
        // Stacked unknown counts rigs, not rows: 5 units.
        let budget = available(rig_calibration(
            &fitting(587, vec![item("RigSlot0", 5, 999999)]),
            &catalogue,
        ));
        assert_close(budget.used, 0.0);
        assert_eq!(budget.excluded_rigs, 5);
    }

    #[test]
    fn flag_discipline_only_rig_slot_prefix_counts() {
        let catalogue = bundled();
        for flag in [
            "LoSlot0",
            "MedSlot0",
            "HiSlot0",
            "SubSystemSlot0",
            "DroneBay",
            "FighterBay",
            "Cargo",
            "Invalid",
            "Foo",
            "",
        ] {
            let budget = available(rig_calibration(
                &fitting(587, vec![item(flag, 1, 31668)]),
                &catalogue,
            ));
            assert_close(budget.used, 0.0);
            assert_eq!(budget.excluded_rigs, 0, "flag {flag}");
        }
        // Prefix rule, slot belonging never judged: RigSlot3 counts.
        let budget = available(rig_calibration(
            &fitting(587, vec![item("RigSlot3", 1, 2048)]),
            &catalogue,
        ));
        assert_close(budget.used, 0.0);
        assert_eq!(budget.excluded_rigs, 1);
        // Unknown under Cargo excludes nothing.
        let budget = available(rig_calibration(
            &fitting(587, vec![item("Cargo", 1, 999999)]),
            &catalogue,
        ));
        assert_close(budget.used, 0.0);
        assert_eq!(budget.excluded_rigs, 0);
    }

    #[test]
    fn quantity_multiplies_and_clamps() {
        let catalogue = bundled();
        // 2 * 200.0 = 400.0.
        let budget = available(rig_calibration(
            &fitting(587, vec![item("RigSlot0", 2, 31668)]),
            &catalogue,
        ));
        assert_close(budget.used, 400.0);
        for quantity in [0, -5] {
            let budget = available(rig_calibration(
                &fitting(587, vec![item("RigSlot0", quantity, 31668)]),
                &catalogue,
            ));
            assert_close(budget.used, 0.0);
            assert_eq!(budget.excluded_rigs, 0);
        }
        for type_id in [0, -1] {
            let budget = available(rig_calibration(
                &fitting(587, vec![item("RigSlot0", 1, type_id)]),
                &catalogue,
            ));
            assert_close(budget.used, 0.0);
            assert_eq!(budget.excluded_rigs, 0);
        }
        // Huge quantity stays finite and reports over.
        let budget = available(rig_calibration(
            &fitting(587, vec![item("RigSlot0", i64::MAX, 31668)]),
            &catalogue,
        ));
        assert!(budget.used.is_finite());
        assert!(budget.is_over());
        assert_eq!(budget.excluded_rigs, 0);
    }

    #[test]
    fn ship_failures_are_unavailable() {
        let catalogue = bundled();
        // 999999 absent, 2048 and 31668 category 7, 35825 category 65.
        for ship_type_id in [999999, 2048, 31668, 35825, 0, -1] {
            let outcome = rig_calibration(&fitting(ship_type_id, vec![]), &catalogue);
            assert_eq!(
                outcome,
                CalibrationOutcome::Unavailable,
                "ship {ship_type_id}"
            );
        }
    }

    #[test]
    fn structure_rig_cost_counts_through_pure_path() {
        let catalogue = bundled();
        // Category-66 rig 37146 = 100.0.
        let budget = available(rig_calibration(
            &fitting(587, vec![item("RigSlot0", 1, 37146)]),
            &catalogue,
        ));
        assert_close(budget.used, 100.0);
        assert_eq!(budget.excluded_rigs, 0);
    }

    #[test]
    fn fixture_defences() {
        // Present 0.0 capacity counts as data.
        let zero_capacity = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"upgradeCapacity":0.0},
                {"typeId":31668,"typeName":"Rig","categoryId":7,"slotEffects":[2663],"upgradeCost":200.0}]}"#,
        )
        .expect("fixture parses");
        let budget = available(rig_calibration(&fitting(587, vec![]), &zero_capacity));
        assert_close(budget.capacity, 0.0);

        // Negative or absent capacity -> Unavailable.
        let negative = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"upgradeCapacity":-1.0}]}"#,
        )
        .expect("fixture parses");
        assert_eq!(
            rig_calibration(&fitting(587, vec![]), &negative),
            CalibrationOutcome::Unavailable
        );
        let absent = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[]}]}"#,
        )
        .expect("fixture parses");
        assert_eq!(
            rig_calibration(&fitting(587, vec![]), &absent),
            CalibrationOutcome::Unavailable
        );

        // Fixture rig with 0.0 cost counts and excludes nothing.
        let zero_cost = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"upgradeCapacity":400.0},
                {"typeId":1001,"typeName":"Zero Cost Rig","categoryId":7,"slotEffects":[2663],"upgradeCost":0.0}]}"#,
        )
        .expect("fixture parses");
        let budget = available(rig_calibration(
            &fitting(587, vec![item("RigSlot0", 3, 1001)]),
            &zero_cost,
        ));
        assert_close(budget.used, 0.0);
        assert_eq!(budget.excluded_rigs, 0);

        // Fixture rig with no cost key excludes.
        let no_cost = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"upgradeCapacity":400.0},
                {"typeId":1002,"typeName":"No Cost Rig","categoryId":7,"slotEffects":[2663]}]}"#,
        )
        .expect("fixture parses");
        let budget = available(rig_calibration(
            &fitting(587, vec![item("RigSlot0", 2, 1002)]),
            &no_cost,
        ));
        assert_close(budget.used, 0.0);
        assert_eq!(budget.excluded_rigs, 2);
    }

    #[test]
    fn independence_from_cpu_pg_outputs() {
        // Fixture hull with calibration but no CPU/PG outputs:
        // calibration Available, resources ShipNoOutput.
        let fixture = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"upgradeCapacity":400.0}]}"#,
        )
        .expect("fixture parses");
        let empty = fitting(587, vec![]);
        assert!(matches!(
            rig_calibration(&empty, &fixture),
            CalibrationOutcome::Available(_)
        ));
        assert!(matches!(
            fitting_resources(&empty, &fixture),
            crate::fitting::resources::FittingResources::ShipNoOutput
        ));
        // Bundled Primae: calibration Unavailable, resources Available.
        let catalogue = bundled();
        let primae = fitting(2863, vec![]);
        assert_eq!(
            rig_calibration(&primae, &catalogue),
            CalibrationOutcome::Unavailable
        );
        assert!(matches!(
            fitting_resources(&primae, &catalogue),
            crate::fitting::resources::FittingResources::Available { .. }
        ));
    }

    #[test]
    fn synthesis_paths_through_eft_and_dna() {
        let catalogue = bundled();
        // Sample EFT: one rig 31668 -> 1 * 200.0 = 200.0 of 400.0.
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
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("sample EFT must import: {fatal:?}"),
        };
        let budget = available(rig_calibration(&synth, &catalogue));
        assert_close(budget.used, 200.0);
        assert_close(budget.capacity, 400.0);
        assert_eq!(budget.excluded_rigs, 0);

        // DNA 587:31668;2:: expands to two rig rows -> 2 * 200.0 = 400.0.
        let dna = match parse_dna("587:31668;2::", &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("sample DNA must import: {fatal:?}"),
        };
        let budget = available(rig_calibration(&dna, &catalogue));
        assert_close(budget.used, 400.0);
        assert_close(budget.capacity, 400.0);
        assert!(!budget.is_over());
        assert_eq!(budget.excluded_rigs, 0);
    }
}
