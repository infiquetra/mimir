//! Pure fitting-resources calculation over the bundled catalogue.
//!
//! Computes base CPU and power grid used versus the hull's base
//! output for one [`CharacterFitting`]. This is the first honest
//! slice of a fitting simulator (docs/fitting-resources-design.md):
//! only base (unmodified) dogma attributes are summed. Skills,
//! implants, and bonuses from modules, rigs, subsystems, and the
//! ship itself are not applied, so totals can differ from EVE.
//!
//! The module is pure computation over the bundled catalogue — no
//! egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] / [`FittingItem`] and [`FittingTypes`],
//! the same dependencies the EFT parser already takes. It tests
//! ESI flag prefixes itself instead of depending on the UI enum,
//! following the [`crate::fitting::eft::ImportSection`]
//! independence precedent.

use crate::esi::models::{CharacterFitting, FittingItem};
use crate::names::fitting_types::FittingTypes;

/// One resource dimension: base need summed over counted fitted
/// modules against the hull's base output.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ResourceBudget {
    pub used: f64,
    pub output: f64,
    /// Consuming-section rows with no usable value for this
    /// dimension (absent from the catalogue, no attribute row, or
    /// an unusable value). Counted in rows, never silently zero.
    pub excluded_modules: usize,
}

impl ResourceBudget {
    pub fn remaining(&self) -> f64 {
        self.output - self.used
    }

    pub fn is_over(&self) -> bool {
        self.used > self.output
    }
}

/// Base CPU / power grid outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FittingResources {
    Available {
        cpu: ResourceBudget,
        power: ResourceBudget,
    },
    /// The catalogue has no usable ship output for this fitting's
    /// ship, so no honest numbers exist.
    ShipNoOutput,
}

/// ESI flags whose items consume CPU or power grid: low, medium,
/// or high slots only. Rigs, subsystems, drones, fighters, cargo,
/// catch-all flags, and loaded charges never consume.
fn is_consuming_flag(flag: &str) -> bool {
    flag.starts_with("LoSlot") || flag.starts_with("MedSlot") || flag.starts_with("HiSlot")
}

/// A catalogue value is usable only when present, finite, and
/// non-negative. A present `0.0` stays a real zero; anything else
/// is treated as no data for that dimension.
fn usable(value: Option<f64>) -> Option<f64> {
    value.filter(|v| v.is_finite() && *v >= 0.0)
}

pub fn fitting_resources(fitting: &CharacterFitting, catalogue: &FittingTypes) -> FittingResources {
    let mut counted_rows: usize = 0;
    let mut cpu_excluded: usize = 0;
    let mut power_excluded: usize = 0;

    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        tracing::debug!(
            "[FITTING] fitting resources counted={} cpu_excluded={} power_excluded={} outcome=ship_no_output",
            counted_rows,
            cpu_excluded,
            power_excluded
        );
        return FittingResources::ShipNoOutput;
    };
    if ship.category_id != 6 {
        tracing::debug!(
            "[FITTING] fitting resources counted={} cpu_excluded={} power_excluded={} outcome=ship_no_output",
            counted_rows,
            cpu_excluded,
            power_excluded
        );
        return FittingResources::ShipNoOutput;
    }
    let Some(cpu_output) = usable(ship.cpu_output) else {
        tracing::debug!(
            "[FITTING] fitting resources counted={} cpu_excluded={} power_excluded={} outcome=ship_no_output",
            counted_rows,
            cpu_excluded,
            power_excluded
        );
        return FittingResources::ShipNoOutput;
    };
    let Some(power_output) = usable(ship.power_output) else {
        tracing::debug!(
            "[FITTING] fitting resources counted={} cpu_excluded={} power_excluded={} outcome=ship_no_output",
            counted_rows,
            cpu_excluded,
            power_excluded
        );
        return FittingResources::ShipNoOutput;
    };

    let mut cpu_used: f64 = 0.0;
    let mut power_used: f64 = 0.0;
    for item in &fitting.items {
        if !consuming_item(item) {
            continue;
        }
        let quantity = item.quantity.max(0);
        if quantity == 0 {
            continue;
        }
        counted_rows = counted_rows.saturating_add(1);
        let quantity_f = quantity as f64;
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            cpu_excluded = cpu_excluded.saturating_add(1);
            power_excluded = power_excluded.saturating_add(1);
            continue;
        };
        match usable(row.cpu) {
            Some(value) => cpu_used += quantity_f * value,
            None => cpu_excluded = cpu_excluded.saturating_add(1),
        }
        match usable(row.power) {
            Some(value) => power_used += quantity_f * value,
            None => power_excluded = power_excluded.saturating_add(1),
        }
    }

    tracing::debug!(
        "[FITTING] fitting resources counted={} cpu_excluded={} power_excluded={} outcome=available",
        counted_rows,
        cpu_excluded,
        power_excluded
    );
    FittingResources::Available {
        cpu: ResourceBudget {
            used: cpu_used,
            output: cpu_output,
            excluded_modules: cpu_excluded,
        },
        power: ResourceBudget {
            used: power_used,
            output: power_output,
            excluded_modules: power_excluded,
        },
    }
}

fn consuming_item(item: &FittingItem) -> bool {
    item.type_id > 0 && is_consuming_flag(&item.flag)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fitting::eft::{parse_eft, EftImportOutcome};

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

    fn budgets(result: FittingResources) -> (ResourceBudget, ResourceBudget) {
        match result {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("expected Available, got ShipNoOutput"),
        }
    }

    fn assert_close(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "expected {expected}, got {actual}"
        );
    }

    // Oracle rows read from scripts/sde/dgmTypeAttributes.csv.bz2:
    // (587, 48) = 130.0, (587, 11) = 41.0; (2048, 50) = 30.0,
    // (2048, 30) = 1.0; (1183, 50/30) = 6.0/6.0; (438, 50/30) =
    // 15.0/11.0; (448, 50/30) = 36.0/1.0; (2889, 50/30) = 9.0/4.0.
    #[test]
    fn hull_only_rifter_has_zero_used_and_full_remaining() {
        let catalogue = bundled();
        let (cpu, power) = budgets(fitting_resources(&fitting(587, vec![]), &catalogue));
        assert_close(cpu.used, 0.0);
        assert_close(cpu.output, 130.0);
        assert_close(power.used, 0.0);
        assert_close(power.output, 41.0);
        assert_close(cpu.remaining(), 130.0);
        assert_close(power.remaining(), 41.0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
        assert!(!cpu.is_over());
        assert!(!power.is_over());
    }

    #[test]
    fn rifter_with_damage_control_ii_in_low_slot() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 2048)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 30.0);
        assert_close(power.used, 1.0);
        assert_close(cpu.remaining(), 100.0);
        assert_close(power.remaining(), 40.0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
    }

    // Sample-fit oracle through the shared synthesis path. Used is
    // 30+6+15+36+9*3 = 114.0 CPU and 1+6+11+1+4*3 = 31.0 power;
    // remaining 16.0/10.0; the rig, the loaded charge, the drones,
    // and the cargo neither count nor exclude.
    #[test]
    fn sample_fit_oracle_through_eft_synthesis() {
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
        let (cpu, power) = budgets(fitting_resources(&synth, &catalogue));
        assert_close(cpu.used, 114.0);
        assert_close(power.used, 31.0);
        assert_close(cpu.remaining(), 16.0);
        assert_close(power.remaining(), 10.0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
    }

    // (2049) has no 50/30 rows in the cache (it is a blueprint,
    // category 9, so the generator emits no needs); (1236) is a
    // genuine zero-cost module with no rows; 999999 is absent from
    // the catalogue. Each adds 1 to both excluded counts and 0 to
    // both sums.
    #[test]
    fn unknown_and_dataless_slot_rows_are_excluded_not_zeroed() {
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![
                item("LoSlot0", 1, 999999),
                item("LoSlot1", 1, 2049),
                item("LoSlot2", 1, 1236),
            ],
        );
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 0.0);
        assert_close(power.used, 0.0);
        assert_eq!(cpu.excluded_modules, 3);
        assert_eq!(power.excluded_modules, 3);
    }

    // (33981) Limited Hyperspatial Accelerator carries only a power
    // row: (30) = 1.0, no (50) row in the cache.
    #[test]
    fn power_only_row_counts_power_and_excludes_cpu() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 33981)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 0.0);
        assert_close(power.used, 1.0);
        assert_eq!(cpu.excluded_modules, 1);
        assert_eq!(power.excluded_modules, 0);
    }

    // (1355) Reactor Control Unit II carries (50) = 22.0 and
    // (30) = 0.0: a present explicit zero, not an absence.
    #[test]
    fn explicit_zero_power_counts_as_real_zero() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 1355)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 22.0);
        assert_close(power.used, 0.0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
    }

    // The same counted module under a non-consuming flag
    // contributes nothing and excludes nothing, including an
    // unknown type under DroneBay.
    #[test]
    fn non_consuming_sections_neither_count_nor_exclude() {
        let catalogue = bundled();
        let flags = [
            "RigSlot0",
            "SubSystemSlot0",
            "DroneBay",
            "FighterBay",
            "Cargo",
            "Foo",
            "",
        ];
        for flag in flags {
            let fit = fitting(587, vec![item(flag, 1, 2048)]);
            let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
            assert_close(cpu.used, 0.0);
            assert_close(power.used, 0.0);
            assert_eq!(cpu.excluded_modules, 0, "flag {flag}");
            assert_eq!(power.excluded_modules, 0, "flag {flag}");
        }
        let fit = fitting(587, vec![item("DroneBay", 1, 999999)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 0.0);
        assert_close(power.used, 0.0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
    }

    // Slot belonging is never judged: Damage Control II costs the
    // same in any low/medium/high slot, dated by the flag prefix.
    #[test]
    fn slot_flag_prefixes_consume_regardless_of_module() {
        let catalogue = bundled();
        for flag in ["LoSlot0", "MedSlot7", "HiSlot3"] {
            let fit = fitting(587, vec![item(flag, 1, 2048)]);
            let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
            assert_close(cpu.used, 30.0);
            assert_close(power.used, 1.0);
            assert_eq!(cpu.excluded_modules, 0, "flag {flag}");
            assert_eq!(power.excluded_modules, 0, "flag {flag}");
        }
    }

    #[test]
    fn quantity_multiplies_and_clamps() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 3, 2048)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 90.0);
        assert_close(power.used, 3.0);

        for quantity in [0, -5] {
            let fit = fitting(587, vec![item("LoSlot0", quantity, 2048)]);
            let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
            assert_close(cpu.used, 0.0);
            assert_close(power.used, 0.0);
            assert_eq!(cpu.excluded_modules, 0);
            assert_eq!(power.excluded_modules, 0);
        }
        for type_id in [0, -1] {
            let fit = fitting(587, vec![item("LoSlot0", 1, type_id)]);
            let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
            assert_close(cpu.used, 0.0);
            assert_close(power.used, 0.0);
            assert_eq!(cpu.excluded_modules, 0);
            assert_eq!(power.excluded_modules, 0);
        }
    }

    #[test]
    fn huge_quantity_stays_finite_and_reports_over() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", i64::MAX, 2048)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert!(cpu.used.is_finite());
        assert!(cpu.is_over());
        assert!(power.used.is_finite());
        assert!(power.is_over());
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
    }

    #[test]
    fn ship_failures_return_no_output() {
        let catalogue = bundled();
        for ship_type_id in [999999, 2048, 0, -1] {
            let result = fitting_resources(&fitting(ship_type_id, vec![]), &catalogue);
            assert_eq!(
                result,
                FittingResources::ShipNoOutput,
                "ship {ship_type_id}"
            );
        }
    }

    // Fixture catalogue for the Zephyr/Echelon shape: a category-6
    // row with outputs present as Some(0.0).
    fn zero_output_catalogue() -> FittingTypes {
        FittingTypes::from_json(
            r#"{"types":[
                {"typeId":2078,"typeName":"Zephyr","categoryId":6,"slotEffects":[],"cpuOutput":0.0,"powerOutput":0.0},
                {"typeId":2048,"typeName":"Damage Control II","categoryId":7,"slotEffects":[11],"cpu":30.0,"power":1.0}]}"#,
        )
        .expect("fixture catalogue parses")
    }

    #[test]
    fn zero_output_ship_is_not_over_hull_only_and_is_over_with_a_module() {
        let catalogue = zero_output_catalogue();
        let (cpu, power) = budgets(fitting_resources(&fitting(2078, vec![]), &catalogue));
        assert_close(cpu.remaining(), 0.0);
        assert_close(power.remaining(), 0.0);
        assert!(!cpu.is_over());
        assert!(!power.is_over());

        let fit = fitting(2078, vec![item("LoSlot0", 1, 2048)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.remaining(), -30.0);
        assert_close(power.remaining(), -1.0);
        assert!(cpu.is_over());
        assert!(power.is_over());
    }

    // 5 x Damage Control II = 150.0 CPU > 130.0, 5.0 power <= 41.0.
    #[test]
    fn over_budget_cpu_only_keeps_exact_numbers() {
        let catalogue = bundled();
        let items: Vec<FittingItem> = (0..5)
            .map(|n| item(&format!("LoSlot{n}"), 1, 2048))
            .collect();
        let (cpu, power) = budgets(fitting_resources(&fitting(587, items), &catalogue));
        assert_close(cpu.used, 150.0);
        assert_close(power.used, 5.0);
        assert!(cpu.is_over());
        assert!(!power.is_over());
        assert_close(cpu.remaining(), -20.0);
        assert_close(power.remaining(), 36.0);
    }

    // Fixture guards: an absent key loads as None; a negative value
    // is treated as excluded, never summed.
    #[test]
    fn fixture_guards_exclude_negative_and_absent_values() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0},
                {"typeId":1001,"typeName":"Negative Cpu","categoryId":7,"slotEffects":[11],"cpu":-5.0,"power":2.0},
                {"typeId":1003,"typeName":"Absent Cpu","categoryId":7,"slotEffects":[11],"power":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(
            587,
            vec![item("LoSlot0", 1, 1001), item("LoSlot1", 1, 1003)],
        );
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 0.0);
        assert_close(power.used, 3.0);
        assert_eq!(cpu.excluded_modules, 2);
        assert_eq!(power.excluded_modules, 0);

        // A negative ship output yields no numbers at all.
        let bad_ship = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":-1.0,"powerOutput":41.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let result = fitting_resources(&fitting(587, vec![]), &bad_ship);
        assert_eq!(result, FittingResources::ShipNoOutput);
    }

    // serde_json rejects 1e999 as "number out of range", so no JSON
    // fixture can carry a non-finite value into the catalogue. The
    // shared usable predicate — the single branch both the ship
    // outputs and the module needs flow through — is pinned here
    // instead.
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
}
