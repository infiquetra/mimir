//! Pure fitting-resources calculation over the bundled catalogue.
//!
//! [`fitting_resources`] computes CPU and power grid used versus
//! the hull's base output for one [`CharacterFitting`] from base
//! (unmodified) dogma attributes only.
//! [`fitting_resources_with_skills`] is the skill-aware entry point:
//! with `Some(levels)` it raises ship outputs by CPU Management
//! (skill 3426, +5% ship CPU output per trained level) and Power
//! Grid Management (skill 3413, +5% ship power output per trained
//! level), each as one unpenalized percent entry
//! (`output * (1 + 0.05 * level)`, level 5 = ×1.25). With `None` it
//! returns exactly [`fitting_resources`]. Module needs are never
//! scaled. Module need reductions, implants, and bonuses from
//! modules, rigs, subsystems, and the ship itself are not applied,
//! so totals can differ from EVE. See
//! `docs/fitting-skill-resources-design.md`.
//!
//! The module is pure computation over the bundled catalogue — no
//! egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] / [`FittingItem`] and [`FittingTypes`],
//! the same dependencies the EFT parser already takes. It tests
//! ESI flag prefixes itself instead of depending on the UI enum,
//! following the [`crate::fitting::eft::ImportSection`]
//! independence precedent.

use crate::esi::models::{CharacterFitting, CharacterSkills, FittingItem};
use crate::names::fitting_types::FittingTypes;

/// CPU Management: +5% ship CPU output (attribute 48) per trained
/// level. Provenance: Flutter `dogma_engine.dart` `_skillModifiers`
/// at `ed698d3` (3426 → `cpuOutput` = 48 at 0.05/level); name in the
/// bundled skills catalogue.
pub const CPU_MANAGEMENT_SKILL_ID: i64 = 3426;

/// Power Grid Management: +5% ship power output (attribute 11) per
/// trained level. Same provenance (3413 → `powerOutput` = 11 at
/// 0.05/level). Skill 3418 is Capacitor Management and must never
/// appear here.
pub const POWER_GRID_MANAGEMENT_SKILL_ID: i64 = 3413;

/// Trained levels of the two resource skills, already clamped to
/// `0..=5` by [`resource_skill_levels`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ResourceSkillLevels {
    pub cpu_management: i32,
    pub power_grid_management: i32,
}

fn clamp_level(level: i32) -> i32 {
    level.clamp(0, 5)
}

/// Both trained levels from one loaded skills payload. Absent rows
/// and present level-0 rows both yield 0; duplicate rows yield the
/// last row; every value is clamped to `0..=5`. Reads
/// `trained_skill_level` (the grounded parity field), never
/// `active_skill_level`.
pub fn resource_skill_levels(skills: &CharacterSkills) -> ResourceSkillLevels {
    // Last-wins over duplicates, mirroring the BTreeMap::collect
    // precedent in `crate::ui::skills::trained_levels`.
    let mut cpu: Option<i32> = None;
    let mut power: Option<i32> = None;
    for skill in &skills.skills {
        match skill.skill_id {
            CPU_MANAGEMENT_SKILL_ID => cpu = Some(skill.trained_skill_level),
            POWER_GRID_MANAGEMENT_SKILL_ID => power = Some(skill.trained_skill_level),
            _ => {}
        }
    }
    ResourceSkillLevels {
        cpu_management: clamp_level(cpu.unwrap_or(0)),
        power_grid_management: clamp_level(power.unwrap_or(0)),
    }
}

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

/// Base CPU / power grid resources for one fitting. Equivalent to
/// [`fitting_resources_with_skills`] with `None`.
pub fn fitting_resources(fitting: &CharacterFitting, catalogue: &FittingTypes) -> FittingResources {
    fitting_resources_with_skills(fitting, catalogue, None)
}

/// Base resources, with ship outputs raised by the two skills when
/// `levels` is `Some`. `None` is exactly [`fitting_resources`].
/// Only `output` scales, by `1 + 0.05 * clamped_level` per dimension.
pub fn fitting_resources_with_skills(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
    levels: Option<ResourceSkillLevels>,
) -> FittingResources {
    let mut cpu_excluded: usize = 0;
    let mut power_excluded: usize = 0;

    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        return FittingResources::ShipNoOutput;
    };
    if ship.category_id != 6 {
        return FittingResources::ShipNoOutput;
    }
    let Some(cpu_output) = usable(ship.cpu_output) else {
        return FittingResources::ShipNoOutput;
    };
    let Some(power_output) = usable(ship.power_output) else {
        return FittingResources::ShipNoOutput;
    };

    // Skill scaling: defensive re-clamp so a hand-built
    // ResourceSkillLevels cannot exceed ×1.25.
    let (cpu_output, power_output) = match levels {
        None => (cpu_output, power_output),
        Some(levels) => {
            let cpu_factor = 1.0 + 0.05 * clamp_level(levels.cpu_management) as f64;
            let power_factor = 1.0 + 0.05 * clamp_level(levels.power_grid_management) as f64;
            (cpu_output * cpu_factor, power_output * power_factor)
        }
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
        let quantity_f = quantity as f64;
        // Excluded counts modules, matching the multiplied sums:
        // a stacked row of five uncounted modules reports five.
        let quantity_units = usize::try_from(quantity).unwrap_or(0);
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            cpu_excluded = cpu_excluded.saturating_add(quantity_units);
            power_excluded = power_excluded.saturating_add(quantity_units);
            continue;
        };
        match usable(row.cpu) {
            Some(value) => cpu_used += quantity_f * value,
            None => cpu_excluded = cpu_excluded.saturating_add(quantity_units),
        }
        match usable(row.power) {
            Some(value) => power_used += quantity_f * value,
            None => power_excluded = power_excluded.saturating_add(quantity_units),
        }
    }

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

    #[test]
    fn excluded_counts_modules_not_rows_for_stacked_rows() {
        // The UI says "N fitted modules"; a stacked slot row of
        // five unknown modules must report five, matching the
        // multiplied sums (reviewer F3).
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 5, 999999)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_eq!(cpu.excluded_modules, 5);
        assert_eq!(power.excluded_modules, 5);
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

    fn skill(skill_id: i64, active: i32, trained: i32) -> crate::esi::models::Skill {
        crate::esi::models::Skill {
            skill_id,
            active_skill_level: active,
            trained_skill_level: trained,
            skillpoints_in_skill: 0,
        }
    }

    fn skills(rows: Vec<crate::esi::models::Skill>) -> CharacterSkills {
        CharacterSkills {
            skills: rows,
            total_sp: 0,
            unallocated_sp: None,
        }
    }

    fn levels(cpu: i32, pg: i32) -> ResourceSkillLevels {
        ResourceSkillLevels {
            cpu_management: cpu,
            power_grid_management: pg,
        }
    }

    // Real Rifter table (×(1 + 0.05·level) on base 130.0/41.0).
    // Level 2 (143.0, not 143.325) and level 5 (162.5, not
    // 130 × 1.05⁵ = 165.916…) kill the per-level compounding mutant.
    #[test]
    fn skill_outputs_follow_real_rifter_table_and_stay_independent() {
        let catalogue = bundled();
        let hull = fitting(587, vec![]);
        let table: [(i32, f64, f64); 6] = [
            (0, 130.0, 41.0),
            (1, 136.5, 43.05),
            (2, 143.0, 45.1),
            (3, 149.5, 47.15),
            (4, 156.0, 49.2),
            (5, 162.5, 51.25),
        ];
        for (level, cpu_expected, pg_expected) in table {
            let (cpu, power) = budgets(fitting_resources_with_skills(
                &hull,
                &catalogue,
                Some(levels(level, level)),
            ));
            assert_close(cpu.output, cpu_expected);
            assert_close(power.output, pg_expected);
        }
        // Independence: CPU L5 + PG L0 scales CPU only, and vice versa.
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(5, 0)),
        ));
        assert_close(cpu.output, 162.5);
        assert_close(power.output, 41.0);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(0, 5)),
        ));
        assert_close(cpu.output, 130.0);
        assert_close(power.output, 51.25);
    }

    // Synthetic Flutter oracle (labelled synthetic): Flutter's
    // synthetic Rifter carries 125.0/37.0; 3426 L5 → 125 × 1.25 =
    // 156.25. Reproducing Flutter's synthetic numbers verbatim.
    #[test]
    fn synthetic_flutter_oracle_cpu_management_l5() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":125.0,"powerOutput":37.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let hull = fitting(587, vec![]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(5, 0)),
        ));
        assert_close(cpu.output, 156.25);
        assert_close(power.output, 37.0);
        // Power grid side of the same synthetic row: 37 × 1.25 = 46.25.
        let (_, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(0, 5)),
        ));
        assert_close(power.output, 46.25);
    }

    #[test]
    fn none_equals_base_on_real_and_no_output_fits() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 2048)]);
        assert_eq!(
            fitting_resources(&fit, &catalogue),
            fitting_resources_with_skills(&fit, &catalogue, None)
        );
        let no_output = fitting(999999, vec![]);
        assert_eq!(
            fitting_resources(&no_output, &catalogue),
            fitting_resources_with_skills(&no_output, &catalogue, None)
        );
        assert_eq!(
            fitting_resources(&no_output, &catalogue),
            FittingResources::ShipNoOutput
        );
    }

    #[test]
    fn lookup_absent_rows_yield_zero_zero() {
        let levels = resource_skill_levels(&skills(vec![]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 0
            }
        );
        // Unrelated rows do not fill the two slots.
        let levels = resource_skill_levels(&skills(vec![skill(3300, 5, 5)]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 0
            }
        );
    }

    #[test]
    fn lookup_reads_trained_not_active() {
        let levels = resource_skill_levels(&skills(vec![
            skill(CPU_MANAGEMENT_SKILL_ID, 5, 2),
            skill(POWER_GRID_MANAGEMENT_SKILL_ID, 1, 4),
        ]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 2,
                power_grid_management: 4
            }
        );
        let present_zero = resource_skill_levels(&skills(vec![
            skill(CPU_MANAGEMENT_SKILL_ID, 5, 0),
            skill(POWER_GRID_MANAGEMENT_SKILL_ID, 5, 0),
        ]));
        assert_eq!(
            present_zero,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 0
            }
        );
    }

    #[test]
    fn lookup_wrong_id_3418_is_noop_and_output_equals_base() {
        // E0c.2 trap: 3418 is Capacitor Management, not a resource
        // skill. It must yield 0/0 and leave outputs at base.
        let levels = resource_skill_levels(&skills(vec![skill(3418, 5, 5)]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 0
            }
        );
        let catalogue = bundled();
        let hull = fitting(587, vec![]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels),
        ));
        assert_close(cpu.output, 130.0);
        assert_close(power.output, 41.0);
    }

    #[test]
    fn lookup_duplicate_rows_last_wins() {
        let levels = resource_skill_levels(&skills(vec![
            skill(CPU_MANAGEMENT_SKILL_ID, 5, 1),
            skill(CPU_MANAGEMENT_SKILL_ID, 5, 4),
            skill(POWER_GRID_MANAGEMENT_SKILL_ID, 5, 2),
            skill(POWER_GRID_MANAGEMENT_SKILL_ID, 5, 3),
        ]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 4,
                power_grid_management: 3
            }
        );
    }

    #[test]
    fn lookup_clamps_negative_seven_and_i32_extremes_without_panic() {
        let levels = resource_skill_levels(&skills(vec![
            skill(CPU_MANAGEMENT_SKILL_ID, -3, -3),
            skill(POWER_GRID_MANAGEMENT_SKILL_ID, 7, 7),
        ]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 5
            }
        );
        let extremes = resource_skill_levels(&skills(vec![
            skill(CPU_MANAGEMENT_SKILL_ID, i32::MIN, i32::MIN),
            skill(POWER_GRID_MANAGEMENT_SKILL_ID, i32::MAX, i32::MAX),
        ]));
        assert_eq!(
            extremes,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 5
            }
        );
    }

    #[test]
    fn hand_built_levels_above_five_are_reclamped_inside() {
        let catalogue = bundled();
        let hull = fitting(587, vec![]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(99, 99)),
        ));
        assert_close(cpu.output, 162.5);
        assert_close(power.output, 51.25);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(-99, -99)),
        ));
        assert_close(cpu.output, 130.0);
        assert_close(power.output, 41.0);
    }

    #[test]
    fn only_output_scales_used_and_excluded_stay_equal() {
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![
                item("LoSlot0", 1, 2048),
                item("LoSlot1", 1, 999999),
                item("LoSlot2", 1, 1236),
            ],
        );
        let base = fitting_resources(&fit, &catalogue);
        let applied = fitting_resources_with_skills(&fit, &catalogue, Some(levels(5, 5)));
        let (base_cpu, base_power) = budgets(base);
        let (applied_cpu, applied_power) = budgets(applied);
        assert_close(applied_cpu.used, base_cpu.used);
        assert_close(applied_power.used, base_power.used);
        assert_eq!(applied_cpu.excluded_modules, base_cpu.excluded_modules);
        assert_eq!(applied_power.excluded_modules, base_power.excluded_modules);
        assert_close(applied_cpu.output, 162.5);
        assert_close(applied_power.output, 51.25);
    }

    #[test]
    fn ship_no_output_and_zero_output_guards_hold_at_l5() {
        let catalogue = bundled();
        assert_eq!(
            fitting_resources_with_skills(&fitting(999999, vec![]), &catalogue, Some(levels(5, 5))),
            FittingResources::ShipNoOutput
        );
        let zero = zero_output_catalogue();
        let fit = fitting(2078, vec![item("LoSlot0", 1, 2048)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &zero,
            Some(levels(5, 5)),
        ));
        assert_close(cpu.output, 0.0);
        assert_close(power.output, 0.0);
        assert_close(cpu.remaining(), -30.0);
        assert_close(power.remaining(), -1.0);
        assert!(cpu.is_over());
        assert!(power.is_over());
        let hull = fitting(2078, vec![]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &zero,
            Some(levels(5, 5)),
        ));
        assert_close(cpu.output, 0.0);
        assert_close(power.output, 0.0);
        assert!(!cpu.is_over());
        assert!(!power.is_over());
    }

    #[test]
    fn over_budget_flips_and_stays_over_against_applied_output() {
        let catalogue = bundled();
        let items5: Vec<FittingItem> = (0..5)
            .map(|n| item(&format!("LoSlot{n}"), 1, 2048))
            .collect();
        let fit5 = fitting(587, items5);
        // 150.0 used is over base 130.0 and under applied 162.5.
        let base = fitting_resources(&fit5, &catalogue);
        let (base_cpu, _) = budgets(base);
        assert!(base_cpu.is_over());
        assert_close(base_cpu.remaining(), -20.0);
        let applied = fitting_resources_with_skills(&fit5, &catalogue, Some(levels(5, 0)));
        let (applied_cpu, _) = budgets(applied);
        assert!(!applied_cpu.is_over());
        assert_close(applied_cpu.output, 162.5);
        assert_close(applied_cpu.used, 150.0);
        assert_close(applied_cpu.remaining(), 12.5);

        let items6: Vec<FittingItem> = (0..6)
            .map(|n| item(&format!("LoSlot{n}"), 1, 2048))
            .collect();
        let fit6 = fitting(587, items6);
        let applied6 = fitting_resources_with_skills(&fit6, &catalogue, Some(levels(5, 0)));
        let (applied6_cpu, _) = budgets(applied6);
        assert!(applied6_cpu.is_over());
        assert_close(applied6_cpu.output, 162.5);
        assert_close(applied6_cpu.used, 180.0);
        assert_close(applied6_cpu.remaining(), -17.5);
    }
}
