//! Pure base active repair calculation over the bundled
//! catalogue.
//!
//! [`fitting_active_repair`] decides, for one
//! [`CharacterFitting`], how many base hit points per second
//! the fitted self-repair modules (shield boosters, armor
//! repairers, hull repairers) would restore per hit-point
//! layer while cycling. The rate replicates Flutter's
//! `dogma_engine.dart` repair block at `ed698d3` (lines
//! 752–777) at base values: `base repair amount / (base
//! duration in milliseconds / 1000)`, summed per layer by
//! effect. See `docs/sustained-tank-design.md`.
//!
//! No modifier of any kind is applied: skills, implants,
//! and bonuses from modules, rigs, subsystems, and the ship
//! itself contribute nothing beyond each module's base
//! amount and cycle, so the values describe base repair and
//! can differ from EVE. Ancillary modules ship dry amounts
//! only: the loaded-charge multiplier (attribute 1886) is
//! never emitted or read, and reload time (1795) is never
//! added to the cycle — the rate is the while-cycling rate,
//! not a long-run average. Resistances are never applied:
//! these are raw hit points per second, never effective hit
//! points per second. Remote repairers, which repair other
//! ships, are not counted. There is no total across layers
//! and no passive-plus-active sum: passive shield recharge
//! peak already ships in the Ship block.
//!
//! The module is pure computation over the bundled catalogue —
//! no egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] and [`FittingTypes`], the same
//! dependencies `resources.rs` takes. It takes no ship
//! input: raw repair rates depend only on fitted modules,
//! so a fitting whose ship type is absent from the catalogue
//! still gets exact module rates. It logs nothing: it runs
//! at render cadence, so per-frame `[FITTING]` logging would
//! spam the log; the catalogue load already logs counts once.

use crate::esi::models::CharacterFitting;
use crate::names::fitting_types::FittingTypes;

/// Base active repair figures for one fitting. Each layer
/// is `Some(sum)` whenever the sum is finite, including
/// `Some(0.0)` when nothing counted — an empty sum over
/// proven data is a known zero, rendered as such, never
/// omitted as if unknown. A sum is `None` only if it goes
/// non-finite; layers are independent, so one layer's
/// `None` never affects another's.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FittingActiveRepair {
    pub shield_hp_per_sec: Option<f64>,
    pub armor_hp_per_sec: Option<f64>,
    pub hull_hp_per_sec: Option<f64>,
    /// Fitted slot-module units that repair (quantity units,
    /// saturating). Known-zero rows (present `0.0` amount)
    /// contribute neither here nor to `excluded_modules`.
    pub counted_modules: u64,
    /// Fitted slot-row units whose base repair data cannot
    /// be proven — unknown type ids, repair candidates
    /// whose amount or cycle is absent or unusable — in
    /// quantity units (the `resources.rs` units precedent:
    /// a stacked slot row of five uncounted modules reports
    /// five), never silently zero.
    pub excluded_modules: u64,
}

/// Whether a saved-fitting flag is a slot-section flag,
/// following the `dps.rs` `is_slot_flag` shape: the `LoSlot`
/// / `MedSlot` / `HiSlot` / `RigSlot` / `SubSystemSlot`
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

/// Base active repair for one fitting. The entry point runs
/// over the synthesized [`CharacterFitting`] (saved rows by
/// ESI flag prefix, imported rows by slot section via
/// `to_character_fitting()` — one code path, since amount
/// and cycle live on the module). The function is total:
/// saturating counts, values filtered through the shipped
/// `usable()` shape, no panic on hostile saved data.
pub fn fitting_active_repair(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> FittingActiveRepair {
    let mut shield: f64 = 0.0;
    let mut armor: f64 = 0.0;
    let mut hull: f64 = 0.0;
    let mut counted_modules: u64 = 0;
    let mut excluded_modules: u64 = 0;
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
            // rate; excluded-with-count, never silent
            // (`resources.rs:184–188` precedent).
            excluded_modules = excluded_modules.saturating_add(quantity_units);
            continue;
        };
        // Family priority armor, then shield, then hull
        // (Flutter's `else if` chain): a marker or an amount
        // key classifies the row into its family. An amount
        // key without its family's marker — impossible in
        // the shipped catalogue by the loader invariants —
        // still makes the row a candidate of that key's
        // family (defence in depth).
        let armor_family =
            row.armor_repair || row.fueled_armor_repair || row.armor_damage_amount.is_some();
        let shield_family =
            row.shield_boosting || row.fueled_shield_boosting || row.shield_bonus.is_some();
        let hull_family = row.structure_repair || row.structure_damage_amount.is_some();
        if !(armor_family || shield_family || hull_family) {
            // A known non-repairer: neither counted nor
            // excluded (every remote repairer lands here —
            // the generation-time effect gate keeps its
            // amounts out of the catalogue entirely).
            continue;
        }
        let amount_field = if armor_family {
            row.armor_damage_amount
        } else if shield_family {
            row.shield_bonus
        } else {
            row.structure_damage_amount
        };
        let Some(amount) = usable(amount_field) else {
            // Absent amount (the abyssal no-data population)
            // or an unusable one (non-finite or negative —
            // impossible in shipped data): a proven repairer
            // without a provable rate is excluded-with-count,
            // never zero-repair.
            excluded_modules = excluded_modules.saturating_add(quantity_units);
            continue;
        };
        if amount == 0.0 {
            // Known zero (present `0.0` amount): contributes
            // 0 HP/s, neither counted nor excluded (the
            // capacitor slice's present-zero `capacitorNeed`
            // precedent; no such type ships).
            continue;
        }
        // Cycle: raw 73 `duration` and nothing else — never
        // the 51 `speed` fallback, never a present 1795
        // `reloadTime` (Flutter's comment: "Burst HP/s uses
        // raw duration (73), not duration+reactivationDelay";
        // deliberate opposite of the capacitor cycle). The
        // field is never read here.
        let Some(cycle_ms) = usable(row.duration) else {
            // A proven repair amount with no usable cycle is
            // never zero-repair.
            excluded_modules = excluded_modules.saturating_add(quantity_units);
            continue;
        };
        if cycle_ms <= 0.0 {
            excluded_modules = excluded_modules.saturating_add(quantity_units);
            continue;
        }
        counted_modules = counted_modules.saturating_add(quantity_units);
        // Base rate per layer: `quantity * amount /
        // (duration_ms / 1000)` (Flutter `+=` accumulation).
        let rate = quantity as f64 * amount / (cycle_ms / 1000.0);
        if armor_family {
            armor += rate;
        } else if shield_family {
            shield += rate;
        } else {
            hull += rate;
        }
    }
    FittingActiveRepair {
        shield_hp_per_sec: shield.is_finite().then_some(shield),
        armor_hp_per_sec: armor.is_finite().then_some(armor),
        hull_hp_per_sec: hull.is_finite().then_some(hull),
        counted_modules,
        excluded_modules,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::eft::{parse_eft, EftImportOutcome};

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

    /// Hand-derived float with the division shown; uniform
    /// `1e-9` absolute tolerance (design section 8).
    fn assert_close(actual: f64, expected: f64, label: &str) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "{label}: expected {expected}, got {actual}"
        );
    }

    fn shield_of(result: &FittingActiveRepair, label: &str) -> f64 {
        match result.shield_hp_per_sec {
            Some(value) => value,
            None => panic!("{label}: expected Some shield, got None"),
        }
    }

    fn armor_of(result: &FittingActiveRepair, label: &str) -> f64 {
        match result.armor_hp_per_sec {
            Some(value) => value,
            None => panic!("{label}: expected Some armor, got None"),
        }
    }

    fn hull_of(result: &FittingActiveRepair, label: &str) -> f64 {
        match result.hull_hp_per_sec {
            Some(value) => value,
            None => panic!("{label}: expected Some hull, got None"),
        }
    }

    // --- Flutter base-pure oracles as fixture-catalogue
    // cases (`dogma_engine_test.dart` E2 group at `ed698d3`;
    // the cache values for the real types the fixtures mimic
    // are identical, so each oracle is pinned again below
    // against the bundled catalogue).
    fn fixture_catalogue() -> FittingTypes {
        FittingTypes::from_json(
            r#"{"types":[
                {"typeId":101,"typeName":"Fixture Armor Repairer II","categoryId":7,"slotEffects":[11],"armorDamageAmount":920.0,"duration":15000.0,"armorRepair":true},
                {"typeId":102,"typeName":"Fixture Shield Booster II","categoryId":7,"slotEffects":[13],"shieldBonus":104.0,"duration":3000.0,"shieldBoosting":true},
                {"typeId":103,"typeName":"Fixture Ancillary Armor Repairer","categoryId":7,"slotEffects":[11],"armorDamageAmount":52.0,"duration":6000.0,"reloadTime":60000.0,"fueledArmorRepair":true},
                {"typeId":104,"typeName":"Fixture Hull Repairer II","categoryId":7,"slotEffects":[13],"structureDamageAmount":30.0,"duration":24000.0,"structureRepair":true},
                {"typeId":105,"typeName":"Fixture Armor Repairer","categoryId":7,"slotEffects":[11],"armorDamageAmount":92.0,"duration":6000.0,"armorRepair":true},
                {"typeId":106,"typeName":"Fixture Known Zero Repairer","categoryId":7,"slotEffects":[11],"armorDamageAmount":0.0,"duration":6000.0,"armorRepair":true},
                {"typeId":107,"typeName":"Fixture No-Cycle Repairer","categoryId":7,"slotEffects":[11],"armorDamageAmount":92.0,"armorRepair":true},
                {"typeId":108,"typeName":"Fixture Zero-Cycle Repairer","categoryId":7,"slotEffects":[11],"armorDamageAmount":92.0,"duration":0.0,"armorRepair":true},
                {"typeId":109,"typeName":"Fixture Negative-Amount Repairer","categoryId":7,"slotEffects":[11],"armorDamageAmount":-1.0,"duration":6000.0,"armorRepair":true},
                {"typeId":110,"typeName":"Fixture Speed-Only Repairer","categoryId":7,"slotEffects":[11],"armorDamageAmount":92.0,"speed":6000.0,"armorRepair":true},
                {"typeId":111,"typeName":"Fixture Reload Repairer","categoryId":7,"slotEffects":[11],"armorDamageAmount":92.0,"duration":6000.0,"reloadTime":999999.0,"armorRepair":true},
                {"typeId":112,"typeName":"Fixture Ancillary Shield Booster","categoryId":7,"slotEffects":[13],"shieldBonus":52.0,"duration":2000.0,"fueledShieldBoosting":true},
                {"typeId":113,"typeName":"Fixture No-Drain Module","categoryId":7,"slotEffects":[13],"capacitorNeed":32.0,"duration":12000.0},
                {"typeId":114,"typeName":"Fixture Amount-Only Repairer","categoryId":7,"slotEffects":[11],"armorDamageAmount":92.0,"duration":6000.0},
                {"typeId":115,"typeName":"Fixture Multi-Marker Repairer","categoryId":7,"slotEffects":[11],"armorDamageAmount":92.0,"duration":6000.0,"armorRepair":true,"shieldBoosting":true},
                {"typeId":116,"typeName":"Fixture Huge Repairer","categoryId":7,"slotEffects":[13],"shieldBonus":1e308,"duration":1000.0,"shieldBoosting":true}]}"#,
        )
        .expect("fixture catalogue parses")
    }

    fn slot_result(catalogue: &FittingTypes, items: Vec<FittingItem>) -> FittingActiveRepair {
        fitting_active_repair(&fitting(42, items), catalogue)
    }

    #[test]
    fn e2_1_armor_repairs_at_base_rate() {
        // 920.0 / 15.0 = 61.333... armor HP/s (Flutter E2.1).
        let catalogue = fixture_catalogue();
        let result = slot_result(&catalogue, vec![item("LoSlot0", 1, 101)]);
        assert_close(armor_of(&result, "E2.1 armor"), 920.0 / 15.0, "E2.1 armor");
        assert_close(shield_of(&result, "E2.1 shield"), 0.0, "E2.1 shield");
        assert_close(hull_of(&result, "E2.1 hull"), 0.0, "E2.1 hull");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn e2_2_shield_boosts_at_base_rate() {
        // 104.0 / 3.0 = 34.666... shield HP/s (Flutter E2.2).
        let catalogue = fixture_catalogue();
        let result = slot_result(&catalogue, vec![item("MedSlot0", 1, 102)]);
        assert_close(
            shield_of(&result, "E2.2 shield"),
            104.0 / 3.0,
            "E2.2 shield",
        );
        assert_close(armor_of(&result, "E2.2 armor"), 0.0, "E2.2 armor");
        assert_close(hull_of(&result, "E2.2 hull"), 0.0, "E2.2 hull");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn e2_3_ancillary_armor_is_dry_only() {
        // 52.0 / 6.0 = 8.666... armor HP/s dry (Flutter E2.3's
        // unloaded half). The loaded 52.0 * 3.0 / 6.0 = 26.0
        // is never an expectation here, and the fixture's
        // 60000.0 ms reload is never added to the cycle.
        let catalogue = fixture_catalogue();
        let result = slot_result(&catalogue, vec![item("LoSlot0", 1, 103)]);
        assert_close(armor_of(&result, "E2.3 armor"), 52.0 / 6.0, "E2.3 armor");
        assert_close(shield_of(&result, "E2.3 shield"), 0.0, "E2.3 shield");
        assert_close(hull_of(&result, "E2.3 hull"), 0.0, "E2.3 hull");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn e2_4_hull_repairs_at_base_rate() {
        // 30.0 / 24.0 = 1.25 hull HP/s exactly (Flutter E2.4).
        let catalogue = fixture_catalogue();
        let result = slot_result(&catalogue, vec![item("MedSlot0", 1, 104)]);
        assert_close(hull_of(&result, "E2.4 hull"), 30.0 / 24.0, "E2.4 hull");
        assert_close(shield_of(&result, "E2.4 shield"), 0.0, "E2.4 shield");
        assert_close(armor_of(&result, "E2.4 armor"), 0.0, "E2.4 armor");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn reload_never_extends_the_cycle() {
        let catalogue = fixture_catalogue();
        // A fixture pair differing only in `reloadTime` gives
        // equal rates — the field is never read. Both are
        // 92.0 / 6.0 = 15.333...; a reload-added cycle would
        // read 92.0 / 1005.999 = 0.091...
        let plain = slot_result(&catalogue, vec![item("LoSlot0", 1, 105)]);
        let reloaded = slot_result(&catalogue, vec![item("LoSlot0", 1, 111)]);
        assert_close(armor_of(&plain, "plain"), 92.0 / 6.0, "plain");
        assert_close(armor_of(&reloaded, "reloaded"), 92.0 / 6.0, "reloaded");
        assert_eq!(plain.counted_modules, 1);
        assert_eq!(reloaded.counted_modules, 1);
        // The bundled reload-ignored pin in its starkest form:
        // 52.0 / 2.0 = 26.0 shield HP/s, never 52.0 / 62.0.
        let catalogue = bundled();
        let result = slot_result(&catalogue, vec![item("MedSlot0", 1, 32774)]);
        assert_close(
            shield_of(&result, "32774 shield"),
            52.0 / 2.0,
            "32774 shield",
        );
        assert_close(armor_of(&result, "32774 armor"), 0.0, "32774 armor");
        assert_close(hull_of(&result, "32774 hull"), 0.0, "32774 hull");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn multi_module_sum_scales_with_quantity() {
        let catalogue = fixture_catalogue();
        // 2 * (92.0 / 6.0) = 30.666..., as two singleton rows
        // and as one quantity-2 row — the stacked-slot units
        // precedent (a quantity-2 row counts two).
        let two_rows = slot_result(
            &catalogue,
            vec![item("LoSlot0", 1, 105), item("LoSlot1", 1, 105)],
        );
        assert_close(
            armor_of(&two_rows, "two rows"),
            2.0 * (92.0 / 6.0),
            "two rows",
        );
        assert_eq!(two_rows.counted_modules, 2);
        assert_eq!(two_rows.excluded_modules, 0);
        let stacked = slot_result(&catalogue, vec![item("LoSlot0", 2, 105)]);
        assert_close(armor_of(&stacked, "stacked"), 2.0 * (92.0 / 6.0), "stacked");
        assert_eq!(stacked.counted_modules, 2);
        assert_eq!(stacked.excluded_modules, 0);
    }

    #[test]
    fn layers_are_independent() {
        // One module per family sums into three separate
        // layers with no cross-talk and no combined total.
        let catalogue = fixture_catalogue();
        let result = slot_result(
            &catalogue,
            vec![
                item("LoSlot0", 1, 101),
                item("MedSlot0", 1, 102),
                item("MedSlot1", 1, 104),
            ],
        );
        assert_close(armor_of(&result, "armor"), 920.0 / 15.0, "armor");
        assert_close(shield_of(&result, "shield"), 104.0 / 3.0, "shield");
        assert_close(hull_of(&result, "hull"), 30.0 / 24.0, "hull");
        assert_eq!(result.counted_modules, 3);
        assert_eq!(result.excluded_modules, 0);
    }

    // --- Inclusion matrix against a fixture catalogue
    // (design section 4, one test per row; the fictional
    // ship id 42 is absent from the fixture catalogue —
    // raw repair needs no hull data).
    #[test]
    fn known_zero_amount_counts_nothing_and_excludes_nothing() {
        let catalogue = fixture_catalogue();
        // A present `0.0` amount is data: zero HP/s, neither
        // counted nor excluded — and known-zero units mixed
        // with a counted repairer do not inflate either.
        let result = slot_result(&catalogue, vec![item("LoSlot0", 1, 106)]);
        assert_close(armor_of(&result, "known-zero"), 0.0, "known-zero");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 0);
        let mixed = slot_result(
            &catalogue,
            vec![item("LoSlot0", 1, 105), item("LoSlot1", 3, 106)],
        );
        assert_close(armor_of(&mixed, "mixed"), 92.0 / 6.0, "mixed");
        assert_eq!(mixed.counted_modules, 1);
        assert_eq!(mixed.excluded_modules, 0);
    }

    #[test]
    fn amount_without_cycle_is_excluded() {
        let catalogue = fixture_catalogue();
        // Absent `duration`: a proven amount with no rate is
        // excluded-with-count, never zero-repair.
        let absent = slot_result(&catalogue, vec![item("LoSlot0", 1, 107)]);
        assert_close(armor_of(&absent, "absent-cycle"), 0.0, "absent-cycle");
        assert_eq!(absent.counted_modules, 0);
        assert_eq!(absent.excluded_modules, 1);
        // Present-zero `duration` never yields a rate.
        let zero = slot_result(&catalogue, vec![item("LoSlot0", 1, 108)]);
        assert_close(armor_of(&zero, "zero-cycle"), 0.0, "zero-cycle");
        assert_eq!(zero.counted_modules, 0);
        assert_eq!(zero.excluded_modules, 1);
        // The 51 `speed` fallback does not carry over: an
        // amount with only `speed` is still excluded. A
        // present `speed` here means 92.0 / 6.0 counted
        // under the capacitor cycle — the pin below fails
        // under any fallback.
        let speed_only = slot_result(&catalogue, vec![item("LoSlot0", 1, 110)]);
        assert_close(armor_of(&speed_only, "speed-only"), 0.0, "speed-only");
        assert_eq!(speed_only.counted_modules, 0);
        assert_eq!(speed_only.excluded_modules, 1);
    }

    #[test]
    fn unusable_amount_is_excluded() {
        let catalogue = fixture_catalogue();
        // A negative amount (fixture-only — the loader
        // invariants prove no shipped row is negative) is
        // excluded-with-count. JSON cannot spell NaN/Infinity,
        // so the non-finite half rides on the shared
        // `usable` rule `ship_cap_stability.rs` already
        // pins directly.
        let result = slot_result(&catalogue, vec![item("LoSlot0", 1, 109)]);
        assert_close(armor_of(&result, "negative amount"), 0.0, "negative amount");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 1);
    }

    #[test]
    fn amount_only_candidate_counts() {
        let catalogue = fixture_catalogue();
        // Defence in depth (fixture-only — the invariants
        // prove every shipped amount carries its family's
        // marker): an amount key without a marker still
        // classifies the row into that key's family.
        let result = slot_result(&catalogue, vec![item("LoSlot0", 1, 114)]);
        assert_close(armor_of(&result, "amount-only"), 92.0 / 6.0, "amount-only");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn armor_family_wins_over_shield() {
        let catalogue = fixture_catalogue();
        // Flutter's `else if` priority (fixture-only — no
        // shipped type carries two self-repair effects): a
        // row with both the armor and shield markers counts
        // toward armor only.
        let result = slot_result(&catalogue, vec![item("LoSlot0", 1, 115)]);
        assert_close(
            armor_of(&result, "priority armor"),
            92.0 / 6.0,
            "priority armor",
        );
        assert_close(
            shield_of(&result, "priority shield"),
            0.0,
            "priority shield",
        );
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn unknown_type_id_is_excluded_in_quantity_units() {
        let catalogue = fixture_catalogue();
        // A catalogue-absent row is excluded-with-count
        // (`resources.rs:184–188` precedent), in quantity
        // units: a stacked row of three reports three.
        let result = slot_result(&catalogue, vec![item("LoSlot0", 3, 999999)]);
        assert_close(armor_of(&result, "unknown-type"), 0.0, "unknown-type");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 3);
    }

    #[test]
    fn known_non_repairer_is_neither() {
        let catalogue = fixture_catalogue();
        // A known module with a cycle but no repair marker
        // or amount (the remote-repairer shape — and every
        // non-repair module) is neither counted nor
        // excluded.
        let result = slot_result(&catalogue, vec![item("MedSlot0", 1, 113)]);
        assert_close(armor_of(&result, "non-repairer"), 0.0, "non-repairer");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn non_slot_rows_neither_count_nor_exclude() {
        let catalogue = fixture_catalogue();
        // Drones, fighters, cargo, catch-all flags, and
        // loaded charges never produce repair — including
        // a repairer type under one of those flags, and an
        // unknown type id under the same flags.
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
            assert_close(armor_of(&result, "non-slot"), 0.0, "non-slot");
            assert_eq!(result.counted_modules, 0, "flag {flag}");
            assert_eq!(result.excluded_modules, 0, "flag {flag}");
        }
        let result = slot_result(&catalogue, vec![item("DroneBay", 1, 999999)]);
        assert_close(
            armor_of(&result, "non-slot unknown"),
            0.0,
            "non-slot unknown",
        );
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn quantity_clamps_at_zero_and_nonpositive_type_ids_are_ignored() {
        let catalogue = fixture_catalogue();
        // Quantity `max(0)` (`resources.rs:176` precedent):
        // zero and negative quantities neither count nor
        // exclude, even for a repairer type.
        for quantity in [0, -5] {
            let result = slot_result(&catalogue, vec![item("LoSlot0", quantity, 101)]);
            assert_close(armor_of(&result, "zero-quantity"), 0.0, "zero-quantity");
            assert_eq!(result.counted_modules, 0);
            assert_eq!(result.excluded_modules, 0);
        }
        // Rows with `type_id <= 0` are ignored entirely.
        for type_id in [0, -1] {
            let result = slot_result(&catalogue, vec![item("LoSlot0", 1, type_id)]);
            assert_close(
                armor_of(&result, "nonpositive-type"),
                0.0,
                "nonpositive-type",
            );
            assert_eq!(result.counted_modules, 0);
            assert_eq!(result.excluded_modules, 0);
        }
    }

    #[test]
    fn slot_flag_prefixes_count_regardless_of_module() {
        let catalogue = fixture_catalogue();
        // Every slot-section prefix is in scope (the
        // `dps.rs` flag shape). Slot belonging is judged by
        // the flag prefix only: a shield booster under a
        // `LoSlot` flag still counts toward shield.
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
        let shield_under_low = slot_result(&catalogue, vec![item("LoSlot0", 1, 102)]);
        assert_close(
            shield_of(&shield_under_low, "shield under LoSlot"),
            104.0 / 3.0,
            "shield under LoSlot",
        );
        assert_close(
            armor_of(&shield_under_low, "shield under LoSlot"),
            0.0,
            "shield under LoSlot",
        );
        assert_eq!(shield_under_low.counted_modules, 1);
    }

    #[test]
    fn ship_absent_from_catalogue_still_repairs() {
        // No ship input and no availability outcome: a
        // fitting whose ship type is absent still gets exact
        // module rates (the fixture catalogue carries no
        // ship rows at all).
        let catalogue = fixture_catalogue();
        let result =
            fitting_active_repair(&fitting(999999, vec![item("LoSlot0", 1, 101)]), &catalogue);
        assert_close(armor_of(&result, "no-ship"), 920.0 / 15.0, "no-ship");
        assert_close(shield_of(&result, "no-ship"), 0.0, "no-ship");
        assert_close(hull_of(&result, "no-ship"), 0.0, "no-ship");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn nonfinite_sum_yields_none_for_that_layer_only() {
        let catalogue = fixture_catalogue();
        // 2 * (1e308 / 1.0) overflows `f64` to infinity, so
        // shield is `None` (the only `None` outcome); the
        // counted armor module beside it stays exact.
        let result = slot_result(
            &catalogue,
            vec![item("MedSlot0", 2, 116), item("LoSlot0", 1, 105)],
        );
        assert_eq!(result.shield_hp_per_sec, None);
        assert_close(
            armor_of(&result, "intact armor"),
            92.0 / 6.0,
            "intact armor",
        );
        assert_close(hull_of(&result, "intact hull"), 0.0, "intact hull");
        assert_eq!(result.counted_modules, 3);
        assert_eq!(result.excluded_modules, 0);
    }

    // --- Bundled-catalogue pins (design section 7). Demo
    // fittings replicate `assets/demo/fittings.json` rows
    // (verified at build time): Demo Brawler 1 (Rifter 587),
    // Mission Runner 2 (Rifter 587), Demo Runner 10
    // (Punisher 597). No shipped demo fitting carries a
    // self-repair module, so the demo story is three known
    // zeros plus one excluded count pinning the unknown-type
    // rule (type 1535 is absent from the catalogue).
    #[test]
    fn demo_brawler_knows_three_zeros_with_one_excluded() {
        let catalogue = bundled();
        // None of 2048/2049/1225/2050/28270 carries a repair
        // marker or amount, so all five are known
        // non-repairers. Type 1535 is absent from the
        // catalogue, so it is excluded. Drones, fighters,
        // and cargo never count or exclude.
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
        let result = fitting_active_repair(&fit, &catalogue);
        assert_close(shield_of(&result, "brawler shield"), 0.0, "brawler shield");
        assert_close(armor_of(&result, "brawler armor"), 0.0, "brawler armor");
        assert_close(hull_of(&result, "brawler hull"), 0.0, "brawler hull");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 1);
    }

    #[test]
    fn mission_runner_knows_three_zeros() {
        let catalogue = bundled();
        // Fitting 2: both slot rows are known non-repairers,
        // so there is no excluded count either.
        let fit = fitting(
            587,
            vec![
                item("HiSlot0", 1, 2048),
                item("LoSlot0", 1, 2049),
                item("DroneBay", 3, 2456),
                item("Cargo", 10, 37),
            ],
        );
        let result = fitting_active_repair(&fit, &catalogue);
        assert_close(shield_of(&result, "mission shield"), 0.0, "mission shield");
        assert_close(armor_of(&result, "mission armor"), 0.0, "mission armor");
        assert_close(hull_of(&result, "mission hull"), 0.0, "mission hull");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn demo_runner_knows_three_zeros() {
        let catalogue = bundled();
        // Fitting 10: all slot rows are known
        // non-repairers.
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
        let result = fitting_active_repair(&fit, &catalogue);
        assert_close(shield_of(&result, "runner shield"), 0.0, "runner shield");
        assert_close(armor_of(&result, "runner armor"), 0.0, "runner armor");
        assert_close(hull_of(&result, "runner hull"), 0.0, "runner hull");
        assert_eq!(result.counted_modules, 0);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn bundled_real_types_match_flutter_base_oracles() {
        let catalogue = bundled();
        // 3540 Large Armor Repairer II: 920.0 / 15.0
        // = 61.333... armor HP/s (E2.1 on the real type).
        let armor =
            fitting_active_repair(&fitting(587, vec![item("LoSlot0", 1, 3540)]), &catalogue);
        assert_close(armor_of(&armor, "3540 armor"), 920.0 / 15.0, "3540 armor");
        assert_close(shield_of(&armor, "3540 shield"), 0.0, "3540 shield");
        assert_close(hull_of(&armor, "3540 hull"), 0.0, "3540 hull");
        assert_eq!(armor.counted_modules, 1);
        assert_eq!(armor.excluded_modules, 0);
        // 10850 Medium Shield Booster II: 104.0 / 3.0
        // = 34.666... shield HP/s (E2.2).
        let shield =
            fitting_active_repair(&fitting(587, vec![item("MedSlot0", 1, 10850)]), &catalogue);
        assert_close(
            shield_of(&shield, "10850 shield"),
            104.0 / 3.0,
            "10850 shield",
        );
        assert_close(armor_of(&shield, "10850 armor"), 0.0, "10850 armor");
        assert_close(hull_of(&shield, "10850 hull"), 0.0, "10850 hull");
        assert_eq!(shield.counted_modules, 1);
        assert_eq!(shield.excluded_modules, 0);
        // 2355 Small Hull Repairer II: 30.0 / 24.0 = 1.25
        // hull HP/s (E2.4).
        let hull =
            fitting_active_repair(&fitting(587, vec![item("MedSlot0", 1, 2355)]), &catalogue);
        assert_close(hull_of(&hull, "2355 hull"), 30.0 / 24.0, "2355 hull");
        assert_close(shield_of(&hull, "2355 shield"), 0.0, "2355 shield");
        assert_close(armor_of(&hull, "2355 armor"), 0.0, "2355 armor");
        assert_eq!(hull.counted_modules, 1);
        assert_eq!(hull.excluded_modules, 0);
    }

    #[test]
    fn bundled_dry_ancillary_pair() {
        let catalogue = bundled();
        // 33076 Small Ancillary Armor Repairer: 52.0 / 6.0
        // = 8.666... dry, never the loaded 26.0; its
        // 60000.0 ms reload is ignored.
        let armor =
            fitting_active_repair(&fitting(587, vec![item("LoSlot0", 1, 33076)]), &catalogue);
        assert_close(armor_of(&armor, "33076 armor"), 52.0 / 6.0, "33076 armor");
        assert_eq!(armor.counted_modules, 1);
        assert_eq!(armor.excluded_modules, 0);
        // 32774 Small Ancillary Shield Booster: 52.0 / 2.0
        // = 26.0 shield HP/s exactly (reload-ignored pin).
        let shield =
            fitting_active_repair(&fitting(587, vec![item("MedSlot0", 1, 32774)]), &catalogue);
        assert_close(
            shield_of(&shield, "32774 shield"),
            52.0 / 2.0,
            "32774 shield",
        );
        assert_eq!(shield.counted_modules, 1);
        assert_eq!(shield.excluded_modules, 0);
    }

    #[test]
    fn bundled_remote_repairers_are_neither() {
        let catalogue = bundled();
        // 3588 Small Remote Shield Booster II and 11355
        // Small Remote Armor Repairer I carry repair amount
        // rows in the cache but gain no catalogue keys, so
        // fitted remotes are known non-self data — neither
        // counted nor excluded.
        for type_id in [3588, 11355] {
            let result =
                fitting_active_repair(&fitting(587, vec![item("HiSlot0", 1, type_id)]), &catalogue);
            assert_close(shield_of(&result, "remote shield"), 0.0, "remote shield");
            assert_close(armor_of(&result, "remote armor"), 0.0, "remote armor");
            assert_close(hull_of(&result, "remote hull"), 0.0, "remote hull");
            assert_eq!(result.counted_modules, 0, "type {type_id}");
            assert_eq!(result.excluded_modules, 0, "type {type_id}");
        }
    }

    #[test]
    fn bundled_abyssal_repairers_are_excluded_with_count() {
        let catalogue = bundled();
        // 47781 Small Abyssal Shield Booster and 47769 Small
        // Abyssal Armor Repairer are marker-only (no amount
        // rows — mutated modules have no base catalogue
        // stats), so each fitted unit is excluded-with-count
        // and contributes no rate.
        let shield =
            fitting_active_repair(&fitting(587, vec![item("MedSlot0", 1, 47781)]), &catalogue);
        assert_close(shield_of(&shield, "abyssal shield"), 0.0, "abyssal shield");
        assert_close(armor_of(&shield, "abyssal shield"), 0.0, "abyssal shield");
        assert_close(hull_of(&shield, "abyssal shield"), 0.0, "abyssal shield");
        assert_eq!(shield.counted_modules, 0);
        assert_eq!(shield.excluded_modules, 1);
        let armor =
            fitting_active_repair(&fitting(587, vec![item("LoSlot0", 1, 47769)]), &catalogue);
        assert_close(armor_of(&armor, "abyssal armor"), 0.0, "abyssal armor");
        assert_eq!(armor.counted_modules, 0);
        assert_eq!(armor.excluded_modules, 1);
    }

    #[test]
    fn eft_oracle_matches_via_synthesis() {
        // The `resources.rs` / capacitor sample-EFT oracle
        // through `to_character_fitting()`: only 1183
        // (Small Armor Repairer II) is a self-repairer —
        // 92.0 / 6.0 = 15.333... armor HP/s, counted 1. The
        // afterburner, scrambler, and autocannons are known
        // non-repairers and the Damage Control II / rig are
        // too, so nothing is excluded. Listing a nanite
        // paste charge after the repairer (in the sample
        // cargo section below) changes nothing — dry only.
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
        let result = fitting_active_repair(&synth, &catalogue);
        assert_close(armor_of(&result, "eft armor"), 92.0 / 6.0, "eft armor");
        assert_close(shield_of(&result, "eft shield"), 0.0, "eft shield");
        assert_close(hull_of(&result, "eft hull"), 0.0, "eft hull");
        assert_eq!(result.counted_modules, 1);
        assert_eq!(result.excluded_modules, 0);
    }
}
