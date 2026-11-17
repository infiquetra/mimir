//! Pure bay-usage calculation over the bundled catalogue.
//!
//! [`bay_usage`] computes four used-versus-capacity dimensions
//! for one [`CharacterFitting`] from base (unmodified) catalogue
//! data only: cargo bay volume, drone bay volume, drone
//! bandwidth, and fighter bay volume. See
//! `docs/bay-capacities-design.md`.
//!
//! The module is pure computation over the bundled catalogue — no
//! egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] / [`FittingItem`] and [`FittingTypes`],
//! the same dependencies the EFT parser already takes. It tests
//! ESI flag strings itself instead of depending on the UI enum,
//! following the [`crate::fitting::resources`] flag-prefix
//! independence precedent. It logs nothing: it runs at render
//! cadence, so per-frame `[FITTING]` logging would spam the log;
//! the catalogue load already logs counts once.
//!
//! Sources, locked by the design: ship cargo capacity is the
//! `invTypes.capacity` column (dogma 38 has zero rows);
//! per-type volume is the `invTypes.volume` column (dogma 161
//! is a decoy, and Flutter's key 38 was its synthesized
//! volume); ship drone capacity is dogma 283, ship drone
//! bandwidth is dogma 1271, ship fighter capacity is dogma 2055,
//! and per-drone bandwidth cost is dogma 1272. Bandwidth is a
//! plain fitted sum, never capped at the ship's bandwidth.

use crate::esi::models::{CharacterFitting, FittingItem};
use crate::names::fitting_types::FittingTypes;

/// One bay dimension: plain item-volume (or bandwidth) sum over
/// counted fitted items against the hull's base capacity.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BayBudget {
    pub used: f64,
    pub capacity: f64,
    /// Counted-section rows with no usable value for this
    /// dimension (absent from the catalogue, no volume row, or
    /// an unusable value). Counted in quantity units, never
    /// silently zero.
    pub excluded_items: usize,
}

impl BayBudget {
    pub fn remaining(&self) -> f64 {
        self.capacity - self.used
    }

    pub fn is_over(&self) -> bool {
        self.used > self.capacity
    }
}

/// Base bay usages for one fitting. Each field is `None` when
/// the hull has no usable capacity data for that bay; the other
/// bays are unaffected.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BayUsage {
    pub cargo: Option<BayBudget>,
    pub drone: Option<BayBudget>,
    pub drone_bandwidth: Option<BayBudget>,
    pub fighter: Option<BayBudget>,
}

/// Bay-usage outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BayUsageOutcome {
    Available(BayUsage),
    /// The catalogue has no usable bay capacity data for this
    /// fitting's ship, so no honest numbers exist.
    Unavailable,
}

/// Which bay a flag's rows count toward, following the grouped
/// item list predicate in `src/ui/fittings.rs` (`section_for_flag`):
/// exact `DroneBay` / `FighterBay` select the drone/fighter bay,
/// slot prefixes count toward no bay, and every other flag —
/// including `Cargo`, `Invalid`, `ServiceSlot0`, `""`, and any
/// unknown flag — counts toward cargo. Counting is flag-driven,
/// never category-driven.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum BaySection {
    Slot,
    Drone,
    Fighter,
    Cargo,
}

fn bay_section(flag: &str) -> BaySection {
    if flag.starts_with("LoSlot")
        || flag.starts_with("MedSlot")
        || flag.starts_with("HiSlot")
        || flag.starts_with("RigSlot")
        || flag.starts_with("SubSystemSlot")
    {
        BaySection::Slot
    } else if flag == "DroneBay" {
        BaySection::Drone
    } else if flag == "FighterBay" {
        BaySection::Fighter
    } else {
        BaySection::Cargo
    }
}

/// A catalogue value is usable only when present, finite, and
/// non-negative. A present `0.0` stays a real zero; anything else
/// is treated as no data for that dimension.
fn usable(value: Option<f64>) -> Option<f64> {
    value.filter(|v| v.is_finite() && *v >= 0.0)
}

/// Base bay usages for one fitting. Ship resolution mirrors
/// `resources.rs`: `ship_type_id` must be positive, resolve in
/// the catalogue, and be category 6, else `Unavailable`. Each
/// bay's capacity is the ship field when usable; absent data
/// yields `None` for that bay only. When every bay is `None`,
/// the outcome is `Unavailable`.
pub fn bay_usage(fitting: &CharacterFitting, catalogue: &FittingTypes) -> BayUsageOutcome {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        return BayUsageOutcome::Unavailable;
    };
    if ship.category_id != 6 {
        return BayUsageOutcome::Unavailable;
    }
    let cargo_capacity = usable(ship.cargo_capacity);
    let drone_capacity = usable(ship.drone_capacity);
    let drone_bandwidth = usable(ship.drone_bandwidth);
    let fighter_capacity = usable(ship.fighter_capacity);
    if cargo_capacity.is_none()
        && drone_capacity.is_none()
        && drone_bandwidth.is_none()
        && fighter_capacity.is_none()
    {
        return BayUsageOutcome::Unavailable;
    }

    let mut cargo_used: f64 = 0.0;
    let mut cargo_excluded: usize = 0;
    let mut drone_used: f64 = 0.0;
    let mut drone_excluded: usize = 0;
    let mut bandwidth_used: f64 = 0.0;
    let mut bandwidth_excluded: usize = 0;
    let mut fighter_used: f64 = 0.0;
    let mut fighter_excluded: usize = 0;

    for item in &fitting.items {
        if item.type_id <= 0 {
            continue;
        }
        let quantity = item.quantity.max(0);
        if quantity == 0 {
            continue;
        }
        let quantity_f = quantity as f64;
        // Excluded counts items, matching the multiplied sums:
        // a stacked row of five unknown items reports five.
        let quantity_units = usize::try_from(quantity).unwrap_or(0);
        match bay_section(&item.flag) {
            BaySection::Slot => continue,
            BaySection::Cargo => {
                // A `None` bay accumulates nothing: no used, no
                // excluded counts without a real capacity.
                if cargo_capacity.is_none() {
                    continue;
                }
                match bay_item_volume(catalogue, item) {
                    Some(value) => cargo_used += quantity_f * value,
                    None => {
                        cargo_excluded = cargo_excluded.saturating_add(quantity_units);
                    }
                }
            }
            BaySection::Drone => {
                if drone_capacity.is_some() {
                    match bay_item_volume(catalogue, item) {
                        Some(value) => drone_used += quantity_f * value,
                        None => {
                            drone_excluded = drone_excluded.saturating_add(quantity_units);
                        }
                    }
                }
                if drone_bandwidth.is_some() {
                    match bay_item_bandwidth(catalogue, item) {
                        Some(value) => bandwidth_used += quantity_f * value,
                        None => {
                            bandwidth_excluded = bandwidth_excluded.saturating_add(quantity_units);
                        }
                    }
                }
            }
            BaySection::Fighter => {
                if fighter_capacity.is_none() {
                    continue;
                }
                match bay_item_volume(catalogue, item) {
                    Some(value) => fighter_used += quantity_f * value,
                    None => {
                        fighter_excluded = fighter_excluded.saturating_add(quantity_units);
                    }
                }
            }
        }
    }

    BayUsageOutcome::Available(BayUsage {
        cargo: cargo_capacity.map(|capacity| BayBudget {
            used: cargo_used,
            capacity,
            excluded_items: cargo_excluded,
        }),
        drone: drone_capacity.map(|capacity| BayBudget {
            used: drone_used,
            capacity,
            excluded_items: drone_excluded,
        }),
        drone_bandwidth: drone_bandwidth.map(|capacity| BayBudget {
            used: bandwidth_used,
            capacity,
            excluded_items: bandwidth_excluded,
        }),
        fighter: fighter_capacity.map(|capacity| BayBudget {
            used: fighter_used,
            capacity,
            excluded_items: fighter_excluded,
        }),
    })
}

fn bay_item_volume(catalogue: &FittingTypes, item: &FittingItem) -> Option<f64> {
    catalogue
        .lookup_by_id(item.type_id)
        .and_then(|row| usable(row.volume))
}

fn bay_item_bandwidth(catalogue: &FittingTypes, item: &FittingItem) -> Option<f64> {
    catalogue
        .lookup_by_id(item.type_id)
        .and_then(|row| usable(row.drone_bandwidth_used))
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

    fn available(result: BayUsageOutcome) -> BayUsage {
        match result {
            BayUsageOutcome::Available(usage) => usage,
            BayUsageOutcome::Unavailable => panic!("expected Available, got Unavailable"),
        }
    }

    fn assert_close(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "expected {expected}, got {actual}"
        );
    }

    // Oracle rows read from invTypes.csv.bz2 / dgmTypeAttributes.csv.bz2:
    // Tristan 593 cargo 140.0 (invTypes capacity), drone 40.0 (283),
    // bandwidth 25.0 (1271); Warrior II 2488 volume 5.0, bandwidth
    // used 5.0 (1272); Hobgoblin II 2456 volume 5.0, bandwidth 5.0.
    #[test]
    fn oracle_tristan_with_five_warrior_ii() {
        let catalogue = bundled();
        let usage = available(bay_usage(
            &fitting(593, vec![item("DroneBay", 5, 2488)]),
            &catalogue,
        ));
        // Drone bay: 5 * 5.0 = 25.0 of 40.0.
        let drone = usage.drone.expect("Tristan carries drone capacity");
        assert_close(drone.used, 25.0);
        assert_close(drone.capacity, 40.0);
        assert_close(drone.remaining(), 15.0);
        assert_eq!(drone.excluded_items, 0);
        assert!(!drone.is_over());
        // Bandwidth: 5 * 5.0 = 25.0 of 25.0, exactly at capacity.
        let bandwidth = usage
            .drone_bandwidth
            .expect("Tristan carries drone bandwidth");
        assert_close(bandwidth.used, 25.0);
        assert_close(bandwidth.capacity, 25.0);
        assert_close(bandwidth.remaining(), 0.0);
        assert_eq!(bandwidth.excluded_items, 0);
        assert!(!bandwidth.is_over());
        // Cargo: no cargo items, 0.0 of 140.0.
        let cargo = usage.cargo.expect("Tristan carries cargo capacity");
        assert_close(cargo.used, 0.0);
        assert_close(cargo.capacity, 140.0);
        assert_eq!(cargo.excluded_items, 0);
        assert!(usage.fighter.is_none());
    }

    // Rifter 587 cargo 140.0, drone 0.0, bandwidth 0.0 (present
    // zeros, dogma rows). Hobgoblin II 2456 volume 5.0, cost 5.0.
    #[test]
    fn zero_capacity_hull_reports_over_and_hull_only() {
        let catalogue = bundled();
        let usage = available(bay_usage(
            &fitting(587, vec![item("DroneBay", 5, 2456)]),
            &catalogue,
        ));
        // Drone bay: 5 * 5.0 = 25.0 of 0.0, over.
        let drone = usage.drone.expect("Rifter carries drone 0.0");
        assert_close(drone.used, 25.0);
        assert_close(drone.capacity, 0.0);
        assert!(drone.is_over());
        assert_close(drone.remaining(), -25.0);
        // Bandwidth: 5 * 5.0 = 25.0 of 0.0, over.
        let bandwidth = usage.drone_bandwidth.expect("Rifter carries bandwidth 0.0");
        assert_close(bandwidth.used, 25.0);
        assert_close(bandwidth.capacity, 0.0);
        assert!(bandwidth.is_over());

        // Hull only: 0.0 of 0.0 renders (not over, not None).
        let hull = available(bay_usage(&fitting(587, vec![]), &catalogue));
        let drone = hull.drone.expect("Rifter drone capacity is present 0.0");
        assert_close(drone.used, 0.0);
        assert_close(drone.capacity, 0.0);
        assert!(!drone.is_over());
        let bandwidth = hull
            .drone_bandwidth
            .expect("Rifter bandwidth is present 0.0");
        assert_close(bandwidth.used, 0.0);
        assert_close(bandwidth.capacity, 0.0);
        assert!(!bandwidth.is_over());
        let cargo = hull.cargo.expect("Rifter cargo capacity is present");
        assert_close(cargo.used, 0.0);
        assert_close(cargo.capacity, 140.0);
        assert!(hull.fighter.is_none());
    }

    // Primae 2863 cargo 100.0 present; no 283/1271/2055 rows, so
    // the three dogma bays are None and fitted drones accumulate
    // nothing anywhere.
    #[test]
    fn absent_capacity_hull_omits_dogma_bays() {
        let catalogue = bundled();
        let usage = available(bay_usage(
            &fitting(2863, vec![item("DroneBay", 5, 2488)]),
            &catalogue,
        ));
        let cargo = usage.cargo.expect("Primae carries cargo capacity");
        assert_close(cargo.used, 0.0);
        assert_close(cargo.capacity, 100.0);
        assert_eq!(cargo.excluded_items, 0);
        assert!(usage.drone.is_none());
        assert!(usage.drone_bandwidth.is_none());
        assert!(usage.fighter.is_none());
    }

    // Caiman 45647 fighter 40000.0 (2055), cargo 2750.0, drone 0.0,
    // bandwidth 0.0 (the twelve fighter hulls carry explicit drone
    // zeros: separate hangars, never summed). Templar II 40556
    // volume 1000.0.
    #[test]
    fn fighter_oracle_keeps_bays_independent() {
        let catalogue = bundled();
        let usage = available(bay_usage(
            &fitting(45647, vec![item("FighterBay", 3, 40556)]),
            &catalogue,
        ));
        // Fighter bay: 3 * 1000.0 = 3000.0 of 40000.0.
        let fighter = usage.fighter.expect("Caiman carries fighter capacity");
        assert_close(fighter.used, 3000.0);
        assert_close(fighter.capacity, 40000.0);
        assert_close(fighter.remaining(), 37000.0);
        assert_eq!(fighter.excluded_items, 0);
        assert!(!fighter.is_over());
        // Drone and bandwidth stay at their own 0.0 capacities.
        let drone = usage.drone.expect("Caiman carries drone 0.0");
        assert_close(drone.used, 0.0);
        assert_close(drone.capacity, 0.0);
        let bandwidth = usage.drone_bandwidth.expect("Caiman carries bandwidth 0.0");
        assert_close(bandwidth.used, 0.0);
        assert_close(bandwidth.capacity, 0.0);
        let cargo = usage.cargo.expect("Caiman carries cargo capacity");
        assert_close(cargo.used, 0.0);
        assert_close(cargo.capacity, 2750.0);
    }

    // Unknown counting: an absent type id and a catalogue row
    // without volume add quantity units to that bay only. The
    // mutated drone 60478 (volume 5.0, no 1272 row) counts
    // volume and excludes bandwidth per drone. A present 0.0
    // volume counts and excludes nothing.
    #[test]
    fn unknown_rows_are_counted_not_zeroed() {
        let catalogue = bundled();
        // Stacked unknown cargo: 7 items report 7, used stays 0.0,
        // and the other bays are untouched.
        let usage = available(bay_usage(
            &fitting(593, vec![item("Cargo", 7, 999999)]),
            &catalogue,
        ));
        let cargo = usage.cargo.expect("Tristan carries cargo capacity");
        assert_close(cargo.used, 0.0);
        assert_eq!(cargo.excluded_items, 7);
        let drone = usage.drone.expect("Tristan carries drone capacity");
        assert_close(drone.used, 0.0);
        assert_eq!(drone.excluded_items, 0);
        let bandwidth = usage
            .drone_bandwidth
            .expect("Tristan carries drone bandwidth");
        assert_eq!(bandwidth.excluded_items, 0);
        assert!(usage.fighter.is_none());

        // Unknown drone: both drone dimensions exclude 3 units.
        let usage = available(bay_usage(
            &fitting(593, vec![item("DroneBay", 3, 999999)]),
            &catalogue,
        ));
        let drone = usage.drone.expect("Tristan carries drone capacity");
        assert_close(drone.used, 0.0);
        assert_eq!(drone.excluded_items, 3);
        let bandwidth = usage
            .drone_bandwidth
            .expect("Tristan carries drone bandwidth");
        assert_close(bandwidth.used, 0.0);
        assert_eq!(bandwidth.excluded_items, 3);

        // Mutated drone 60478 Light: volume 5.0, no 1272 row.
        // 2 * 5.0 = 10.0 drone volume; 2 bandwidth units excluded.
        let usage = available(bay_usage(
            &fitting(593, vec![item("DroneBay", 2, 60478)]),
            &catalogue,
        ));
        let drone = usage.drone.expect("Tristan carries drone capacity");
        assert_close(drone.used, 10.0);
        assert_eq!(drone.excluded_items, 0);
        let bandwidth = usage
            .drone_bandwidth
            .expect("Tristan carries drone bandwidth");
        assert_close(bandwidth.used, 0.0);
        assert_eq!(bandwidth.excluded_items, 2);

        // Fixture row without volume: 3 units excluded, used 0.0.
        let fixture = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":593,"typeName":"Tristan","categoryId":6,"slotEffects":[],"cargoCapacity":140.0,"droneCapacity":40.0,"droneBandwidth":25.0,"volume":26500.0},
                {"typeId":1001,"typeName":"No Volume","categoryId":4,"slotEffects":[]}]}"#,
        )
        .expect("fixture catalogue parses");
        let usage = available(bay_usage(
            &fitting(593, vec![item("Cargo", 3, 1001)]),
            &fixture,
        ));
        let cargo = usage.cargo.expect("fixture hull carries cargo");
        assert_close(cargo.used, 0.0);
        assert_eq!(cargo.excluded_items, 3);

        // Present 0.0 volume counts and excludes nothing.
        let zero_volume = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":593,"typeName":"Tristan","categoryId":6,"slotEffects":[],"cargoCapacity":140.0,"volume":26500.0},
                {"typeId":1002,"typeName":"Zero Volume","categoryId":4,"slotEffects":[],"volume":0.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let usage = available(bay_usage(
            &fitting(593, vec![item("Cargo", 5, 1002)]),
            &zero_volume,
        ));
        let cargo = usage.cargo.expect("fixture hull carries cargo");
        assert_close(cargo.used, 0.0);
        assert_eq!(cargo.excluded_items, 0);
    }

    // Section rule: the locked flag set lands exactly as the
    // grouped list files it. Tritanium 34 is category 4, so
    // every assertion below also pins category-independence:
    // belonging is judged by flag, never by category. 100 *
    // 0.01 = 1.0 wherever the row counts.
    #[test]
    fn section_assignment_mirrors_grouped_list() {
        let catalogue = bundled();
        // Cargo catch-all: anything that is not a slot flag and
        // not exactly DroneBay/FighterBay counts as cargo.
        for flag in [
            "Cargo",
            "Invalid",
            "ServiceSlot0",
            "",
            "Foo",
            "DroneBayExtra",
        ] {
            let usage = available(bay_usage(
                &fitting(45647, vec![item(flag, 100, 34)]),
                &catalogue,
            ));
            let cargo = usage.cargo.expect("Caiman carries cargo capacity");
            assert_close(cargo.used, 1.0);
            assert_eq!(cargo.excluded_items, 0, "flag {flag}");
            let drone = usage.drone.expect("Caiman carries drone");
            assert_close(drone.used, 0.0);
            let fighter = usage.fighter.expect("Caiman carries fighter");
            assert_close(fighter.used, 0.0);
        }
        // Case sensitivity pins the exact/prefix split: a
        // lower-case slot word is not a slot flag.
        let usage = available(bay_usage(
            &fitting(45647, vec![item("loslot0", 100, 34)]),
            &catalogue,
        ));
        let cargo = usage.cargo.expect("Caiman carries cargo capacity");
        assert_close(cargo.used, 1.0);
        // Exact DroneBay and FighterBay select their own bays.
        let usage = available(bay_usage(
            &fitting(45647, vec![item("DroneBay", 100, 34)]),
            &catalogue,
        ));
        assert_close(usage.drone.expect("Caiman carries drone").used, 1.0);
        // Tritanium carries no bandwidth row, so all 100 units
        // exclude from bandwidth while counting toward volume.
        let bandwidth = usage.drone_bandwidth.expect("Caiman carries bandwidth");
        assert_close(bandwidth.used, 0.0);
        assert_eq!(bandwidth.excluded_items, 100);
        let usage = available(bay_usage(
            &fitting(45647, vec![item("FighterBay", 100, 34)]),
            &catalogue,
        ));
        let fighter = usage.fighter.expect("Caiman carries fighter");
        assert_close(fighter.used, 1.0);
        assert_eq!(fighter.excluded_items, 0);
        // Slot prefixes count toward no bay.
        for flag in [
            "LoSlot0",
            "MedSlot0",
            "HiSlot0",
            "RigSlot0",
            "SubSystemSlot0",
        ] {
            let usage = available(bay_usage(
                &fitting(45647, vec![item(flag, 100, 34)]),
                &catalogue,
            ));
            assert_close(usage.cargo.expect("Caiman carries cargo").used, 0.0);
            assert_eq!(
                usage.cargo.expect("Caiman carries cargo").excluded_items,
                0,
                "flag {flag}"
            );
            assert_close(usage.drone.expect("Caiman carries drone").used, 0.0);
            assert_eq!(
                usage.drone.expect("Caiman carries drone").excluded_items,
                0,
                "flag {flag}"
            );
            let fighter = usage.fighter.expect("Caiman carries fighter");
            assert_close(fighter.used, 0.0);
            assert_eq!(fighter.excluded_items, 0, "flag {flag}");
        }
    }

    #[test]
    fn quantity_and_type_clamps_follow_resources() {
        let catalogue = bundled();
        // Quantity multiplies: 3 * 5.0 = 15.0 each way.
        let usage = available(bay_usage(
            &fitting(593, vec![item("DroneBay", 3, 2488)]),
            &catalogue,
        ));
        let drone = usage.drone.expect("Tristan carries drone capacity");
        assert_close(drone.used, 15.0);
        assert_eq!(drone.excluded_items, 0);
        // Zero and negative quantities contribute and exclude
        // nothing, even for unknown types.
        for quantity in [0, -5] {
            let usage = available(bay_usage(
                &fitting(593, vec![item("DroneBay", quantity, 2488)]),
                &catalogue,
            ));
            let drone = usage.drone.expect("Tristan carries drone capacity");
            assert_close(drone.used, 0.0);
            assert_eq!(drone.excluded_items, 0);
            let usage = available(bay_usage(
                &fitting(593, vec![item("DroneBay", quantity, 999999)]),
                &catalogue,
            ));
            let drone = usage.drone.expect("Tristan carries drone capacity");
            assert_close(drone.used, 0.0);
            assert_eq!(drone.excluded_items, 0);
        }
        // Type id 0 and negative rows are invisible.
        for type_id in [0, -1] {
            let usage = available(bay_usage(
                &fitting(593, vec![item("DroneBay", 1, type_id)]),
                &catalogue,
            ));
            let drone = usage.drone.expect("Tristan carries drone capacity");
            assert_close(drone.used, 0.0);
            assert_eq!(drone.excluded_items, 0);
            let bandwidth = usage
                .drone_bandwidth
                .expect("Tristan carries drone bandwidth");
            assert_close(bandwidth.used, 0.0);
            assert_eq!(bandwidth.excluded_items, 0);
        }
        // Huge quantity stays finite and reports over:
        // i64::MAX * 5.0 is large but far below f64::MAX.
        let usage = available(bay_usage(
            &fitting(593, vec![item("DroneBay", i64::MAX, 2488)]),
            &catalogue,
        ));
        let drone = usage.drone.expect("Tristan carries drone capacity");
        assert!(drone.used.is_finite());
        assert!(drone.is_over());
        let bandwidth = usage
            .drone_bandwidth
            .expect("Tristan carries drone bandwidth");
        assert!(bandwidth.used.is_finite());
        assert!(bandwidth.is_over());
    }

    #[test]
    fn ship_failures_are_unavailable() {
        let catalogue = bundled();
        for ship_type_id in [999999, 2048, 0, -1] {
            let result = bay_usage(&fitting(ship_type_id, vec![]), &catalogue);
            assert_eq!(result, BayUsageOutcome::Unavailable, "ship {ship_type_id}");
        }
        // A ship with every capacity absent has no honest numbers.
        let bare = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Bare Hull","categoryId":6,"slotEffects":[]}]}"#,
        )
        .expect("fixture catalogue parses");
        assert_eq!(
            bay_usage(&fitting(42, vec![]), &bare),
            BayUsageOutcome::Unavailable
        );
        // A ship with exactly one capacity is Available with the
        // other three None.
        let lone = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":43,"typeName":"Lone Bay","categoryId":6,"slotEffects":[],"cargoCapacity":100.0,"volume":10.0},
                {"typeId":34,"typeName":"Tritanium","categoryId":4,"slotEffects":[],"volume":0.01}]}"#,
        )
        .expect("fixture catalogue parses");
        let usage = available(bay_usage(&fitting(43, vec![item("Cargo", 1, 34)]), &lone));
        let cargo = usage.cargo.expect("Lone Bay carries cargo capacity");
        assert_close(cargo.used, 0.01);
        assert_close(cargo.capacity, 100.0);
        assert!(usage.drone.is_none());
        assert!(usage.drone_bandwidth.is_none());
        assert!(usage.fighter.is_none());
    }

    // Independence from resources, in both directions (fixtures):
    // bay capacities without outputs give resources ShipNoOutput
    // and bay Available; outputs without bay capacities give the
    // reverse. Bay availability ignores base-stat/resonance
    // presence: the bay-only fixture has neither, yet is Available.
    #[test]
    fn availability_is_independent_of_resources() {
        let bay_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Bay Only","categoryId":6,"slotEffects":[],"cargoCapacity":100.0,"volume":10.0},
                {"typeId":34,"typeName":"Tritanium","categoryId":4,"slotEffects":[],"volume":0.01}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![item("Cargo", 1, 34)]);
        assert_eq!(
            fitting_resources(&fit, &bay_only),
            crate::fitting::resources::FittingResources::ShipNoOutput
        );
        assert!(matches!(
            bay_usage(&fit, &bay_only),
            BayUsageOutcome::Available(_)
        ));

        let outputs_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":43,"typeName":"Outputs Only","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(43, vec![]);
        assert!(matches!(
            fitting_resources(&fit, &outputs_only),
            crate::fitting::resources::FittingResources::Available { .. }
        ));
        assert_eq!(bay_usage(&fit, &outputs_only), BayUsageOutcome::Unavailable);
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

    // A negative ship capacity is no data for that bay only; the
    // other bays still render. JSON cannot spell NaN, so the
    // non-finite half is pinned through the usable rule above.
    #[test]
    fn negative_ship_capacity_is_none_for_that_bay_only() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"cargoCapacity":-1.0,"droneCapacity":40.0,"droneBandwidth":25.0,"volume":10.0},
                {"typeId":34,"typeName":"Tritanium","categoryId":4,"slotEffects":[],"volume":0.01}]}"#,
        )
        .expect("fixture catalogue parses");
        let usage = available(bay_usage(
            &fitting(42, vec![item("Cargo", 1, 34)]),
            &catalogue,
        ));
        assert!(usage.cargo.is_none());
        assert!(usage.drone.is_some());
        assert!(usage.drone_bandwidth.is_some());
        assert!(usage.fighter.is_none());
    }

    // Synthesis path: the sample EFT through parse_eft ->
    // to_character_fitting -> bay_usage. Cargo is 200 * 0.0025
    // (185 EMP S) + 8 * 0.01 (28668 paste) = 0.50 + 0.08 = 0.58
    // of 140.0; drones 2 * 5.0 = 10.0 of 0.0 over, bandwidth the
    // same. The loaded charge is synthesized away and counts
    // nowhere. DNA yields present-zero bays by construction.
    #[test]
    fn synthesis_paths_share_one_math_path() {
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
        let usage = available(bay_usage(&synth, &catalogue));
        let cargo = usage.cargo.expect("Rifter carries cargo capacity");
        assert_close(cargo.used, 0.58);
        assert_close(cargo.capacity, 140.0);
        assert_eq!(cargo.excluded_items, 0);
        let drone = usage.drone.expect("Rifter carries drone 0.0");
        assert_close(drone.used, 10.0);
        assert_close(drone.capacity, 0.0);
        assert!(drone.is_over());
        let bandwidth = usage.drone_bandwidth.expect("Rifter carries bandwidth 0.0");
        assert_close(bandwidth.used, 10.0);
        assert_close(bandwidth.capacity, 0.0);
        assert!(bandwidth.is_over());
        assert!(usage.fighter.is_none());

        let dna_text = "587:2048:1183;1:438;1:448;1:2889;3:31668;1::";
        let dna = match parse_dna(dna_text, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("sample DNA must import: {fatal:?}"),
        };
        let usage = available(bay_usage(&dna, &catalogue));
        let cargo = usage.cargo.expect("Rifter carries cargo capacity");
        assert_close(cargo.used, 0.0);
        assert_close(cargo.capacity, 140.0);
        assert_eq!(cargo.excluded_items, 0);
        let drone = usage.drone.expect("Rifter carries drone 0.0");
        assert_close(drone.used, 0.0);
        assert_close(drone.capacity, 0.0);
        assert!(!drone.is_over());
        let bandwidth = usage.drone_bandwidth.expect("Rifter carries bandwidth 0.0");
        assert_close(bandwidth.used, 0.0);
        assert_close(bandwidth.capacity, 0.0);
        assert!(usage.fighter.is_none());
    }
}
