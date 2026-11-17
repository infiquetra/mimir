//! Pure slot-layout calculation over the bundled catalogue.
//!
//! [`slot_layout`] computes slot use versus the hull's base slot
//! layout for one [`CharacterFitting`] from base (unmodified)
//! catalogue data only: distinct occupied slot flags against
//! dogma 14 `hiSlots`, 13 `medSlots`, 12 `lowSlots`, 1137
//! `rigSlots`, 1367 `maxSubSystems`, 102 `turretSlotsLeft`,
//! and 101 `launcherSlotsLeft`, plus turret and launcher
//! hardpoint use from dogma effects 40 `launcherFitted` and
//! 42 `turretFitted` ("Requires a `launcher/turret hardpoint`").
//! See `docs/slot-layout-design.md`.
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
//! Sources, locked by the design: ship base counts are the
//! seven dogma attributes above; hardpoint consumption is the
//! two effect markers — a high-slot row consumes a turret
//! hardpoint exactly when its module carries effect 42 and a
//! launcher hardpoint exactly when it carries effect 40.
//! Attribute 47 `slots`, attribute 1154 `upgradeSlotsLeft`,
//! and the subsystem-granted modifiers 1368
//! `turretHardPointModifier`, 1369 `launcherHardPointModifier`,
//! 1374 `hiSlotModifier`, 1375 `medSlotModifier`, and 1376
//! `lowSlotModifier` are never read here. Dogma 1154 is the
//! unchosen rig source and is never a per-ship fallback. On a
//! hull with a usable `maxSubSystems`, the high, medium, low,
//! turret, and launcher dimensions are suppressed because their
//! live layout comes from fitted subsystems, which this slice
//! does not apply (the tech-3 suppression, design section 4
//! rule 2); rig and subsystem lines keep their base counts.
//! Counting is flag occupancy (one distinct flag, one slot),
//! never a quantity sum, and never via module names.

use std::collections::HashSet;

use crate::esi::models::CharacterFitting;
use crate::names::fitting_types::FittingTypes;

/// One slot or hardpoint dimension: distinct occupied slot flags
/// against the hull's base count for that dimension.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SlotBudget {
    pub used: usize,
    pub capacity: usize,
    /// Hardpoint dimensions only: occupied high slots whose module
    /// is absent from the catalogue, so whether it consumes a
    /// hardpoint cannot be known. Counted in occupied high slots
    /// (one per distinct flag), never silently zero. Slot
    /// dimensions always carry 0.
    pub excluded_modules: usize,
}

impl SlotBudget {
    pub fn remaining(&self) -> i64 {
        (self.capacity as i128 - self.used as i128) as i64
    }

    pub fn is_over(&self) -> bool {
        self.used > self.capacity
    }
}

/// Base slot layout usages for one fitting. Each field is `None`
/// when the hull has no usable base count for that dimension —
/// or, on a subsystem-layout hull, when the dimension is set by
/// subsystems rather than the base hull; the other dimensions
/// are unaffected.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SlotLayout {
    pub high: Option<SlotBudget>,
    pub medium: Option<SlotBudget>,
    pub low: Option<SlotBudget>,
    pub rig: Option<SlotBudget>,
    pub subsystem: Option<SlotBudget>,
    pub turret: Option<SlotBudget>,
    pub launcher: Option<SlotBudget>,
    /// True when the hull's layout is subsystem-defined (usable
    /// `max_sub_systems`) and the five subsystem-dependent
    /// dimensions were suppressed. The UI renders its tech-3
    /// sentence exactly when this is true.
    pub subsystem_layout: bool,
}

/// Base slot layout outcome for one fitting.
/// Seven locked dimensions intrinsic size exceeds the
/// `large_enum_variant` threshold; the shape is locked by the
/// design (section 4) and twins require `Copy`.
#[allow(clippy::large_enum_variant)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SlotLayoutOutcome {
    Available(SlotLayout),
    /// The catalogue has no usable slot layout data for this
    /// fitting's ship, so no honest numbers exist.
    Unavailable,
}

/// A catalogue count is usable only when present, finite,
/// non-negative, integral (`fract() == 0.0`), and at most 2^53
/// (the largest consecutive integer an `f64` spells exactly).
/// A present `0.0` stays a real zero; anything else — absent,
/// negative, NaN, infinite, fractional, or beyond exact-integer
/// range — is no data for that dimension, never a rounded or
/// clamped count.
fn usable_count(value: Option<f64>) -> Option<usize> {
    value
        .filter(|v| v.is_finite() && *v >= 0.0 && v.fract() == 0.0 && *v <= 9_007_199_254_740_992.0)
        .map(|v| v as usize)
}

/// Which slot dimension a flag's rows occupy, by prefix only
/// (the flag-prefix independence precedent: never via the UI
/// enum). Validity is not judged — any suffix, including none,
/// occupies one slot of its dimension.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SlotDimension {
    High,
    Medium,
    Low,
    Rig,
    Subsystem,
}

fn slot_dimension(flag: &str) -> Option<SlotDimension> {
    if flag.starts_with("LoSlot") {
        Some(SlotDimension::Low)
    } else if flag.starts_with("MedSlot") {
        Some(SlotDimension::Medium)
    } else if flag.starts_with("HiSlot") {
        Some(SlotDimension::High)
    } else if flag.starts_with("RigSlot") {
        Some(SlotDimension::Rig)
    } else if flag.starts_with("SubSystemSlot") {
        Some(SlotDimension::Subsystem)
    } else {
        None
    }
}

/// Base slot layout for one fitting. Ship resolution mirrors
/// `bay_usage.rs`: `ship_type_id` must be positive, resolve in
/// the catalogue, and be category 6, else `Unavailable`. Each
/// dimension's capacity is `usable_count` of its ship field;
/// absent or unusable yields `None` for that dimension only.
/// When every dimension is `None` (after tech-3 suppression),
/// the outcome is `Unavailable`.
///
/// Counting is distinct-flag occupancy in `fitting.items` order,
/// first row wins; quantity never multiplies; only high flags
/// are hardpoint candidates.
pub fn slot_layout(fitting: &CharacterFitting, catalogue: &FittingTypes) -> SlotLayoutOutcome {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        return SlotLayoutOutcome::Unavailable;
    };
    if ship.category_id != 6 {
        return SlotLayoutOutcome::Unavailable;
    }

    let subsystem_layout = usable_count(ship.max_sub_systems).is_some();
    let high_capacity = if subsystem_layout {
        None
    } else {
        usable_count(ship.hi_slots)
    };
    let medium_capacity = if subsystem_layout {
        None
    } else {
        usable_count(ship.med_slots)
    };
    let low_capacity = if subsystem_layout {
        None
    } else {
        usable_count(ship.low_slots)
    };
    let rig_capacity = usable_count(ship.rig_slots);
    let subsystem_capacity = usable_count(ship.max_sub_systems);
    let turret_capacity = if subsystem_layout {
        None
    } else {
        usable_count(ship.turret_hardpoints)
    };
    let launcher_capacity = if subsystem_layout {
        None
    } else {
        usable_count(ship.launcher_hardpoints)
    };

    if high_capacity.is_none()
        && medium_capacity.is_none()
        && low_capacity.is_none()
        && rig_capacity.is_none()
        && subsystem_capacity.is_none()
        && turret_capacity.is_none()
        && launcher_capacity.is_none()
    {
        return SlotLayoutOutcome::Unavailable;
    }

    let mut high_used: usize = 0;
    let mut medium_used: usize = 0;
    let mut low_used: usize = 0;
    let mut rig_used: usize = 0;
    let mut subsystem_used: usize = 0;
    let mut turret_used: usize = 0;
    let mut launcher_used: usize = 0;
    let mut turret_excluded: usize = 0;
    let mut launcher_excluded: usize = 0;

    let mut seen_flags: HashSet<String> = HashSet::new();
    for item in &fitting.items {
        if item.type_id <= 0 {
            continue;
        }
        let quantity = item.quantity.max(0);
        if quantity == 0 {
            continue;
        }
        let Some(dimension) = slot_dimension(&item.flag) else {
            continue;
        };
        if !seen_flags.insert(item.flag.clone()) {
            continue;
        }
        match dimension {
            SlotDimension::High => {
                high_used = high_used.saturating_add(1);
                match catalogue.lookup_by_id(item.type_id) {
                    Some(row) => {
                        if row.turret_fitted && turret_capacity.is_some() {
                            turret_used = turret_used.saturating_add(1);
                        }
                        if row.launcher_fitted && launcher_capacity.is_some() {
                            launcher_used = launcher_used.saturating_add(1);
                        }
                    }
                    None => {
                        if turret_capacity.is_some() {
                            turret_excluded = turret_excluded.saturating_add(1);
                        }
                        if launcher_capacity.is_some() {
                            launcher_excluded = launcher_excluded.saturating_add(1);
                        }
                    }
                }
            }
            SlotDimension::Medium => {
                medium_used = medium_used.saturating_add(1);
            }
            SlotDimension::Low => {
                low_used = low_used.saturating_add(1);
            }
            SlotDimension::Rig => {
                rig_used = rig_used.saturating_add(1);
            }
            SlotDimension::Subsystem => {
                subsystem_used = subsystem_used.saturating_add(1);
            }
        }
    }

    SlotLayoutOutcome::Available(SlotLayout {
        high: high_capacity.map(|capacity| SlotBudget {
            used: high_used,
            capacity,
            excluded_modules: 0,
        }),
        medium: medium_capacity.map(|capacity| SlotBudget {
            used: medium_used,
            capacity,
            excluded_modules: 0,
        }),
        low: low_capacity.map(|capacity| SlotBudget {
            used: low_used,
            capacity,
            excluded_modules: 0,
        }),
        rig: rig_capacity.map(|capacity| SlotBudget {
            used: rig_used,
            capacity,
            excluded_modules: 0,
        }),
        subsystem: subsystem_capacity.map(|capacity| SlotBudget {
            used: subsystem_used,
            capacity,
            excluded_modules: 0,
        }),
        turret: turret_capacity.map(|capacity| SlotBudget {
            used: turret_used,
            capacity,
            excluded_modules: turret_excluded,
        }),
        launcher: launcher_capacity.map(|capacity| SlotBudget {
            used: launcher_used,
            capacity,
            excluded_modules: launcher_excluded,
        }),
        subsystem_layout,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::calibration::rig_calibration;
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

    fn available(outcome: SlotLayoutOutcome) -> SlotLayout {
        match outcome {
            SlotLayoutOutcome::Available(layout) => layout,
            SlotLayoutOutcome::Unavailable => panic!("expected Available, got Unavailable"),
        }
    }

    // Oracle rows read from scripts/sde/dgmTypeAttributes.csv.bz2
    // / dgmTypeEffects.csv.bz2: Rifter 587 low 4.0, med 3.0,
    // high 3.0, turret 3.0, launcher 2.0, rig 3.0, no 1367
    // row; 2889 carries effect 42, 499 carries effect 40.
    #[test]
    fn hull_only_rifter_has_literal_capacities() {
        let catalogue = bundled();
        let layout = available(slot_layout(&fitting(587, vec![]), &catalogue));
        // Rifter: low 4, medium 3, high 3, rig 3, turret 3,
        // launcher 2, subsystem None, not subsystem-layout.
        let low = layout.low.expect("Rifter carries low slots");
        assert_eq!(low.used, 0);
        assert_eq!(low.capacity, 4);
        assert_eq!(low.remaining(), 4);
        assert_eq!(low.excluded_modules, 0);
        assert!(!low.is_over());
        let medium = layout.medium.expect("Rifter carries medium slots");
        assert_eq!(medium.used, 0);
        assert_eq!(medium.capacity, 3);
        assert_eq!(medium.remaining(), 3);
        assert_eq!(medium.excluded_modules, 0);
        assert!(!medium.is_over());
        let high = layout.high.expect("Rifter carries high slots");
        assert_eq!(high.used, 0);
        assert_eq!(high.capacity, 3);
        assert_eq!(high.remaining(), 3);
        assert_eq!(high.excluded_modules, 0);
        assert!(!high.is_over());
        let rig = layout.rig.expect("Rifter carries rig slots");
        assert_eq!(rig.used, 0);
        assert_eq!(rig.capacity, 3);
        assert_eq!(rig.remaining(), 3);
        assert_eq!(rig.excluded_modules, 0);
        assert!(!rig.is_over());
        let turret = layout.turret.expect("Rifter carries turret hardpoints");
        assert_eq!(turret.used, 0);
        assert_eq!(turret.capacity, 3);
        assert_eq!(turret.remaining(), 3);
        assert_eq!(turret.excluded_modules, 0);
        assert!(!turret.is_over());
        let launcher = layout.launcher.expect("Rifter carries launcher hardpoints");
        assert_eq!(launcher.used, 0);
        assert_eq!(launcher.capacity, 2);
        assert_eq!(launcher.remaining(), 2);
        assert_eq!(launcher.excluded_modules, 0);
        assert!(!launcher.is_over());
        assert!(layout.subsystem.is_none());
        assert!(!layout.subsystem_layout);
    }

    #[test]
    fn non_modal_capacities_trip_the_fallback() {
        let catalogue = bundled();
        // Raven 638 = low 5, med 7, high 7, rig 3, turret 4,
        // launcher 6. Any hidden 3/3/3/3 default fails these.
        let layout = available(slot_layout(&fitting(638, vec![]), &catalogue));
        assert_eq!(layout.low.expect("Raven low").capacity, 5);
        assert_eq!(layout.medium.expect("Raven med").capacity, 7);
        assert_eq!(layout.high.expect("Raven high").capacity, 7);
        assert_eq!(layout.rig.expect("Raven rig").capacity, 3);
        assert_eq!(layout.turret.expect("Raven turret").capacity, 4);
        assert_eq!(layout.launcher.expect("Raven launcher").capacity, 6);
        // Erebus 671 = low 7, med 6, high 8, rig 3, turret 6,
        // launcher 0 present.
        let layout = available(slot_layout(&fitting(671, vec![]), &catalogue));
        assert_eq!(layout.low.expect("Erebus low").capacity, 7);
        assert_eq!(layout.medium.expect("Erebus med").capacity, 6);
        assert_eq!(layout.high.expect("Erebus high").capacity, 8);
        assert_eq!(layout.rig.expect("Erebus rig").capacity, 3);
        assert_eq!(layout.turret.expect("Erebus turret").capacity, 6);
        let launcher = layout.launcher.expect("Erebus launcher present 0");
        assert_eq!(launcher.capacity, 0);
        assert_eq!(launcher.used, 0);
        assert!(!launcher.is_over());
        // Osprey 620 turret 1, launcher 2.
        let layout = available(slot_layout(&fitting(620, vec![]), &catalogue));
        assert_eq!(layout.turret.expect("Osprey turret").capacity, 1);
        assert_eq!(layout.launcher.expect("Osprey launcher").capacity, 2);
    }

    #[test]
    fn present_zero_renders_as_data() {
        let catalogue = bundled();
        // Echelon 3532 carries high/low present as 0.0.
        let layout = available(slot_layout(&fitting(3532, vec![]), &catalogue));
        let high = layout.high.expect("Echelon high present 0");
        assert_eq!(high.capacity, 0);
        assert_eq!(high.used, 0);
        assert_eq!(high.remaining(), 0);
        assert!(!high.is_over());
        let low = layout.low.expect("Echelon low present 0");
        assert_eq!(low.capacity, 0);
        assert_eq!(low.used, 0);
        assert!(!low.is_over());
        // One fitted high row: used 1 of 0, remaining 0 - 1 = -1.
        let layout = available(slot_layout(
            &fitting(3532, vec![item("HiSlot0", 1, 2048)]),
            &catalogue,
        ));
        let high = layout.high.expect("Echelon high present 0");
        assert_eq!(high.used, 1);
        assert_eq!(high.capacity, 0);
        assert_eq!(high.remaining(), -1);
        assert!(high.is_over());
        // Punisher 597 launcher present as 0.0.
        let layout = available(slot_layout(&fitting(597, vec![]), &catalogue));
        let launcher = layout.launcher.expect("Punisher launcher present 0");
        assert_eq!(launcher.capacity, 0);
        assert_eq!(launcher.used, 0);
    }

    #[test]
    fn absent_is_not_zero() {
        let catalogue = bundled();
        // Capsule 670: no slot rows, hardpoints present as 0.0.
        let layout = available(slot_layout(&fitting(670, vec![]), &catalogue));
        assert!(layout.low.is_none());
        assert!(layout.medium.is_none());
        assert!(layout.high.is_none());
        assert!(layout.rig.is_none());
        assert!(layout.subsystem.is_none());
        let turret = layout.turret.expect("Capsule turret present 0");
        assert_eq!(turret.capacity, 0);
        assert_eq!(turret.used, 0);
        let launcher = layout.launcher.expect("Capsule launcher present 0");
        assert_eq!(launcher.capacity, 0);
        assert_eq!(launcher.used, 0);
        assert!(!layout.subsystem_layout);
        // Primae 2863: turret and rig absent, launcher present 0.
        let layout = available(slot_layout(&fitting(2863, vec![]), &catalogue));
        assert!(layout.turret.is_none());
        assert!(layout.rig.is_none());
        let launcher = layout.launcher.expect("Primae launcher present 0");
        assert_eq!(launcher.capacity, 0);
        assert!(layout.low.is_some());
        assert!(layout.medium.is_some());
        assert!(layout.high.is_some());
        // Noctis 2998: turret absent, high 8.
        let layout = available(slot_layout(&fitting(2998, vec![]), &catalogue));
        assert!(layout.turret.is_none());
        assert_eq!(layout.high.expect("Noctis high").capacity, 8);
    }

    #[test]
    fn occupancy_counts_distinct_flags_first_wins() {
        let catalogue = bundled();
        // Two HiSlot0 rows are one occupied slot (first wins).
        let layout = available(slot_layout(
            &fitting(
                587,
                vec![item("HiSlot0", 1, 2048), item("HiSlot0", 1, 2048)],
            ),
            &catalogue,
        ));
        let high = layout.high.expect("Rifter high");
        assert_eq!(high.used, 1);
        assert_eq!(high.capacity, 3);
        assert_eq!(high.remaining(), 2);
        // First-row-wins hardpoint identity: turret module 2889
        // first, then launcher module 499 under the same flag.
        let layout = available(slot_layout(
            &fitting(587, vec![item("HiSlot0", 1, 2889), item("HiSlot0", 1, 499)]),
            &catalogue,
        ));
        let high = layout.high.expect("Rifter high");
        assert_eq!(high.used, 1);
        let turret = layout.turret.expect("Rifter turret");
        assert_eq!(turret.used, 1);
        assert_eq!(turret.excluded_modules, 0);
        let launcher = layout.launcher.expect("Rifter launcher");
        assert_eq!(launcher.used, 0);
        assert_eq!(launcher.excluded_modules, 0);
        // Reversed order mirrors the survivor.
        let layout = available(slot_layout(
            &fitting(587, vec![item("HiSlot0", 1, 499), item("HiSlot0", 1, 2889)]),
            &catalogue,
        ));
        let turret = layout.turret.expect("Rifter turret");
        assert_eq!(turret.used, 0);
        let launcher = layout.launcher.expect("Rifter launcher");
        assert_eq!(launcher.used, 1);
        // Quantity never multiplies: quantity 5 is one slot.
        let layout = available(slot_layout(
            &fitting(587, vec![item("HiSlot0", 5, 2889)]),
            &catalogue,
        ));
        assert_eq!(layout.high.expect("Rifter high").used, 1);
        assert_eq!(layout.turret.expect("Rifter turret").used, 1);
        // HiSlot00 is distinct from HiSlot0: two slots.
        let layout = available(slot_layout(
            &fitting(
                587,
                vec![item("HiSlot0", 1, 2048), item("HiSlot00", 1, 2048)],
            ),
            &catalogue,
        ));
        assert_eq!(layout.high.expect("Rifter high").used, 2);
        // RigSlot7 occupies (validity not judged): Rifter with
        // three more rigs is 4 of 3, remaining 3 - 4 = -1.
        let layout = available(slot_layout(
            &fitting(
                587,
                vec![
                    item("RigSlot0", 1, 31668),
                    item("RigSlot1", 1, 31668),
                    item("RigSlot2", 1, 31668),
                    item("RigSlot7", 1, 31668),
                ],
            ),
            &catalogue,
        ));
        let rig = layout.rig.expect("Rifter rig");
        assert_eq!(rig.used, 4);
        assert_eq!(rig.capacity, 3);
        assert_eq!(rig.remaining(), -1);
        assert!(rig.is_over());
        // Quantity 0 and -5 rows occupy nothing.
        for quantity in [0, -5] {
            let layout = available(slot_layout(
                &fitting(587, vec![item("HiSlot0", quantity, 2889)]),
                &catalogue,
            ));
            assert_eq!(layout.high.expect("Rifter high").used, 0);
            assert_eq!(layout.turret.expect("Rifter turret").used, 0);
            assert_eq!(layout.turret.expect("Rifter turret").excluded_modules, 0);
        }
        // Type id 0 and -1 rows occupy nothing.
        for type_id in [0, -1] {
            let layout = available(slot_layout(
                &fitting(587, vec![item("HiSlot0", 1, type_id)]),
                &catalogue,
            ));
            assert_eq!(layout.high.expect("Rifter high").used, 0);
            assert_eq!(layout.turret.expect("Rifter turret").used, 0);
        }
        // Non-slot flags occupy nothing and exclude nothing.
        for flag in ["DroneBay", "Cargo", "Invalid", "ServiceSlot0", "", "Foo"] {
            let layout = available(slot_layout(
                &fitting(587, vec![item(flag, 1, 2889)]),
                &catalogue,
            ));
            assert_eq!(layout.high.expect("Rifter high").used, 0, "flag {flag}");
            assert_eq!(layout.low.expect("Rifter low").used, 0, "flag {flag}");
            assert_eq!(layout.medium.expect("Rifter med").used, 0, "flag {flag}");
            assert_eq!(layout.rig.expect("Rifter rig").used, 0, "flag {flag}");
            assert_eq!(layout.turret.expect("Rifter turret").used, 0, "flag {flag}");
            assert_eq!(
                layout.turret.expect("Rifter turret").excluded_modules,
                0,
                "flag {flag}"
            );
        }
        // Unknown modules under non-slot flags exclude nothing.
        let layout = available(slot_layout(
            &fitting(587, vec![item("DroneBay", 1, 999999)]),
            &catalogue,
        ));
        assert_eq!(layout.turret.expect("Rifter turret").excluded_modules, 0);
        assert_eq!(
            layout.launcher.expect("Rifter launcher").excluded_modules,
            0
        );
    }

    #[test]
    fn hardpoint_counting_follows_markers() {
        let catalogue = bundled();
        // 2889 turret marker, 499 launcher marker.
        let layout = available(slot_layout(
            &fitting(587, vec![item("HiSlot0", 1, 2889)]),
            &catalogue,
        ));
        assert_eq!(layout.turret.expect("Rifter turret").used, 1);
        assert_eq!(layout.launcher.expect("Rifter launcher").used, 0);
        assert_eq!(layout.turret.expect("Rifter turret").excluded_modules, 0);
        let layout = available(slot_layout(
            &fitting(587, vec![item("HiSlot0", 1, 499)]),
            &catalogue,
        ));
        assert_eq!(layout.turret.expect("Rifter turret").used, 0);
        assert_eq!(layout.launcher.expect("Rifter launcher").used, 1);
        // 405 known neither: neither hardpoint, nothing excluded.
        let layout = available(slot_layout(
            &fitting(587, vec![item("HiSlot0", 1, 405)]),
            &catalogue,
        ));
        assert_eq!(layout.high.expect("Rifter high").used, 1);
        assert_eq!(layout.turret.expect("Rifter turret").used, 0);
        assert_eq!(layout.launcher.expect("Rifter launcher").used, 0);
        assert_eq!(layout.turret.expect("Rifter turret").excluded_modules, 0);
        assert_eq!(
            layout.launcher.expect("Rifter launcher").excluded_modules,
            0
        );
        // Unknown module under HiSlot0 occupies high and excludes
        // on each present hardpoint dimension.
        let layout = available(slot_layout(
            &fitting(587, vec![item("HiSlot0", 1, 999999)]),
            &catalogue,
        ));
        assert_eq!(layout.high.expect("Rifter high").used, 1);
        let turret = layout.turret.expect("Rifter turret");
        assert_eq!(turret.used, 0);
        assert_eq!(turret.excluded_modules, 1);
        let launcher = layout.launcher.expect("Rifter launcher");
        assert_eq!(launcher.used, 0);
        assert_eq!(launcher.excluded_modules, 1);
        // Unknown under LoSlot0 occupies low, no hardpoint exclusion.
        let layout = available(slot_layout(
            &fitting(587, vec![item("LoSlot0", 1, 999999)]),
            &catalogue,
        ));
        assert_eq!(layout.low.expect("Rifter low").used, 1);
        assert_eq!(layout.turret.expect("Rifter turret").excluded_modules, 0);
        assert_eq!(
            layout.launcher.expect("Rifter launcher").excluded_modules,
            0
        );
        // Marker module under LoSlot0 consumes no hardpoint.
        let layout = available(slot_layout(
            &fitting(587, vec![item("LoSlot0", 1, 2889)]),
            &catalogue,
        ));
        assert_eq!(layout.low.expect("Rifter low").used, 1);
        assert_eq!(layout.turret.expect("Rifter turret").used, 0);
        // Category-66 pin: 35921 under HiSlot0 is launcher 1.
        let layout = available(slot_layout(
            &fitting(587, vec![item("HiSlot0", 1, 35921)]),
            &catalogue,
        ));
        assert_eq!(layout.launcher.expect("Rifter launcher").used, 1);
        assert_eq!(layout.turret.expect("Rifter turret").used, 0);
        // Decoy pin: 27914 Bomb Launcher I carries no launcher
        // marker (effect, not name or attribute 47).
        let layout = available(slot_layout(
            &fitting(587, vec![item("HiSlot0", 1, 27914)]),
            &catalogue,
        ));
        assert_eq!(layout.high.expect("Rifter high").used, 1);
        assert_eq!(layout.launcher.expect("Rifter launcher").used, 0);
        assert_eq!(
            layout.launcher.expect("Rifter launcher").excluded_modules,
            0
        );
        assert_eq!(layout.turret.expect("Rifter turret").used, 0);
    }

    #[test]
    fn over_and_exact_tracked_per_dimension() {
        let catalogue = bundled();
        // Exactly at capacity: 3 distinct high flags on Rifter is
        // 3 of 3, remaining 0, not over.
        let layout = available(slot_layout(
            &fitting(
                587,
                vec![
                    item("HiSlot0", 1, 2048),
                    item("HiSlot1", 1, 2048),
                    item("HiSlot2", 1, 2048),
                ],
            ),
            &catalogue,
        ));
        let high = layout.high.expect("Rifter high");
        assert_eq!(high.used, 3);
        assert_eq!(high.capacity, 3);
        assert_eq!(high.remaining(), 0);
        assert!(!high.is_over());
        // Over: 4 distinct flags is 4 of 3, remaining -1.
        let layout = available(slot_layout(
            &fitting(
                587,
                vec![
                    item("HiSlot0", 1, 2048),
                    item("HiSlot1", 1, 2048),
                    item("HiSlot2", 1, 2048),
                    item("HiSlot3", 1, 2048),
                ],
            ),
            &catalogue,
        ));
        let high = layout.high.expect("Rifter high");
        assert_eq!(high.used, 4);
        assert_eq!(high.capacity, 3);
        assert_eq!(high.remaining(), -1);
        assert!(high.is_over());
        // Hardpoint over tracked per dimension: four turret
        // modules over turret and high, launcher untouched.
        let layout = available(slot_layout(
            &fitting(
                587,
                vec![
                    item("HiSlot0", 1, 2889),
                    item("HiSlot1", 1, 2889),
                    item("HiSlot2", 1, 2889),
                    item("HiSlot3", 1, 2889),
                ],
            ),
            &catalogue,
        ));
        let high = layout.high.expect("Rifter high");
        assert_eq!(high.used, 4);
        assert!(high.is_over());
        let turret = layout.turret.expect("Rifter turret");
        assert_eq!(turret.used, 4);
        assert_eq!(turret.capacity, 3);
        assert_eq!(turret.remaining(), -1);
        assert!(turret.is_over());
        let launcher = layout.launcher.expect("Rifter launcher");
        assert_eq!(launcher.used, 0);
        assert_eq!(launcher.capacity, 2);
        assert_eq!(launcher.remaining(), 2);
        assert!(!launcher.is_over());
    }

    #[test]
    fn tech3_hull_suppresses_bare_zeros() {
        let catalogue = bundled();
        // Legion 29986 empty: rig 3 and subsystem 5 only, the
        // five subsystem-dependent dimensions suppressed.
        let layout = available(slot_layout(&fitting(29986, vec![]), &catalogue));
        assert_eq!(layout.rig.expect("Legion rig").capacity, 3);
        assert_eq!(layout.rig.expect("Legion rig").used, 0);
        assert_eq!(layout.subsystem.expect("Legion subsystem").capacity, 5);
        assert!(layout.high.is_none());
        assert!(layout.medium.is_none());
        assert!(layout.low.is_none());
        assert!(layout.turret.is_none());
        assert!(layout.launcher.is_none());
        assert!(layout.subsystem_layout);
        // Legion with fitted highs and 5 subsystem rows: still no
        // high data; subsystem 5 of 5 (remaining 0).
        let mut items = vec![item("HiSlot0", 1, 2889)];
        for index in 0..5 {
            items.push(item(&format!("SubSystemSlot{index}"), 1, 45623));
        }
        let layout = available(slot_layout(&fitting(29986, items), &catalogue));
        assert!(layout.high.is_none());
        assert!(layout.turret.is_none());
        assert!(layout.launcher.is_none());
        let subsystem = layout.subsystem.expect("Legion subsystem");
        assert_eq!(subsystem.used, 5);
        assert_eq!(subsystem.capacity, 5);
        assert_eq!(subsystem.remaining(), 0);
        assert!(!subsystem.is_over());
        // 6 distinct subsystem rows over by one (5 - 6 = -1).
        let mut items = Vec::new();
        for index in 0..6 {
            items.push(item(&format!("SubSystemSlot{index}"), 1, 45623));
        }
        let layout = available(slot_layout(&fitting(29986, items), &catalogue));
        let subsystem = layout.subsystem.expect("Legion subsystem");
        assert_eq!(subsystem.used, 6);
        assert_eq!(subsystem.capacity, 5);
        assert_eq!(subsystem.remaining(), -1);
        assert!(subsystem.is_over());
        // No non-tech-3 hull sets subsystem_layout.
        for ship in [587, 638] {
            let layout = available(slot_layout(&fitting(ship, vec![]), &catalogue));
            assert!(!layout.subsystem_layout, "ship {ship}");
        }
    }

    #[test]
    fn ship_failures_are_unavailable() {
        let catalogue = bundled();
        // 999999 absent, 2048 category 7, 35825 category 65,
        // 0 and -1 have no row.
        for ship_type_id in [999999, 2048, 35825, 0, -1] {
            let outcome = slot_layout(&fitting(ship_type_id, vec![]), &catalogue);
            assert_eq!(
                outcome,
                SlotLayoutOutcome::Unavailable,
                "ship {ship_type_id}"
            );
        }
    }

    #[test]
    fn fixture_defences() {
        // Present 0.0 capacity counts as data.
        let zero = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"hiSlots":0.0,"lowSlots":0.0}]}"#,
        )
        .expect("fixture parses");
        let layout = available(slot_layout(&fitting(587, vec![]), &zero));
        assert_eq!(layout.high.expect("zero high").capacity, 0);
        assert_eq!(layout.low.expect("zero low").capacity, 0);

        // Negative or absent capacity is no data for that
        // dimension only; the other dimensions still render.
        let negative = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"hiSlots":-1.0,"lowSlots":4.0}]}"#,
        )
        .expect("fixture parses");
        let layout = available(slot_layout(&fitting(587, vec![]), &negative));
        assert!(layout.high.is_none());
        assert_eq!(layout.low.expect("low").capacity, 4);

        let absent = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"lowSlots":4.0}]}"#,
        )
        .expect("fixture parses");
        let layout = available(slot_layout(&fitting(587, vec![]), &absent));
        assert!(layout.high.is_none());
        assert_eq!(layout.low.expect("low").capacity, 4);

        // Fractional 2.5 is no data (integral lock).
        let fractional = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"hiSlots":2.5,"lowSlots":4.0}]}"#,
        )
        .expect("fixture parses");
        let layout = available(slot_layout(&fitting(587, vec![]), &fractional));
        assert!(layout.high.is_none());
        assert_eq!(layout.low.expect("low").capacity, 4);

        // 1e20 is beyond exact-integer range: no data.
        let huge = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"hiSlots":1e20,"lowSlots":4.0}]}"#,
        )
        .expect("fixture parses");
        let layout = available(slot_layout(&fitting(587, vec![]), &huge));
        assert!(layout.high.is_none());
        assert_eq!(layout.low.expect("low").capacity, 4);

        // A hull whose every layout key is unusable is
        // Unavailable.
        let all_bad = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"hiSlots":2.5,"lowSlots":-1.0}]}"#,
        )
        .expect("fixture parses");
        assert_eq!(
            slot_layout(&fitting(587, vec![]), &all_bad),
            SlotLayoutOutcome::Unavailable
        );

        // Fixture maxSubSystems on a non-tech-3 id still
        // triggers suppression (data-driven, not an id list).
        let fixture_tech3 = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"hiSlots":3.0,"rigSlots":3.0,"maxSubSystems":5.0}]}"#,
        )
        .expect("fixture parses");
        let layout = available(slot_layout(&fitting(42, vec![]), &fixture_tech3));
        assert!(layout.subsystem_layout);
        assert!(layout.high.is_none());
        assert_eq!(layout.rig.expect("rig").capacity, 3);
        assert_eq!(layout.subsystem.expect("subsystem").capacity, 5);

        // Direct usable_count pins for non-finite values JSON
        // cannot spell (serde_json rejects NaN/Infinity).
        assert_eq!(usable_count(Some(2.5)), None);
        assert_eq!(usable_count(Some(0.0)), Some(0));
        assert_eq!(usable_count(Some(3.0)), Some(3));
        assert_eq!(usable_count(None), None);
        assert_eq!(usable_count(Some(-1.0)), None);
        assert_eq!(usable_count(Some(f64::INFINITY)), None);
        assert_eq!(usable_count(Some(f64::NEG_INFINITY)), None);
        assert_eq!(usable_count(Some(f64::NAN)), None);
        assert_eq!(usable_count(Some(1e20)), None);
        assert_eq!(
            usable_count(Some(9_007_199_254_740_992.0)),
            Some(9_007_199_254_740_992)
        );
    }

    #[test]
    fn availability_is_independent_of_resources_and_calibration() {
        // Fixture hull with layout but no CPU/PG outputs: slot
        // Available, resources ShipNoOutput.
        let fixture = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"hiSlots":3.0,"lowSlots":4.0}]}"#,
        )
        .expect("fixture parses");
        let empty = fitting(587, vec![]);
        assert!(matches!(
            slot_layout(&empty, &fixture),
            SlotLayoutOutcome::Available(_)
        ));
        assert!(matches!(
            fitting_resources(&empty, &fixture),
            crate::fitting::resources::FittingResources::ShipNoOutput
        ));

        let catalogue = bundled();
        // Bundled Primae: slot Available, calibration Unavailable.
        let primae = fitting(2863, vec![]);
        assert!(matches!(
            slot_layout(&primae, &catalogue),
            SlotLayoutOutcome::Available(_)
        ));
        assert_eq!(
            rig_calibration(&primae, &catalogue),
            crate::fitting::calibration::CalibrationOutcome::Unavailable
        );
        // Bundled Capsule: slot Available (hardpoints),
        // calibration Unavailable, resources Available.
        let capsule = fitting(670, vec![]);
        assert!(matches!(
            slot_layout(&capsule, &catalogue),
            SlotLayoutOutcome::Available(_)
        ));
        assert_eq!(
            rig_calibration(&capsule, &catalogue),
            crate::fitting::calibration::CalibrationOutcome::Unavailable
        );
        assert!(matches!(
            fitting_resources(&capsule, &catalogue),
            crate::fitting::resources::FittingResources::Available { .. }
        ));
    }

    #[test]
    fn synthesis_paths_through_eft_and_dna() {
        let catalogue = bundled();
        // Sample EFT: Rifter with 2 low, 2 medium, 3 turret
        // high, 1 rig. Low 2 of 4 (4 - 2 = 2 left), medium 2 of
        // 3 (3 - 2 = 1 left), high 3 of 3 (0 left), rig 1 of 3
        // (3 - 1 = 2 left), turret 3 of 3 (0 left), launcher 0
        // of 2 (2 left).
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
        let layout = available(slot_layout(&synth, &catalogue));
        let low = layout.low.expect("Rifter low");
        assert_eq!(low.used, 2);
        assert_eq!(low.capacity, 4);
        assert_eq!(low.remaining(), 2);
        let medium = layout.medium.expect("Rifter med");
        assert_eq!(medium.used, 2);
        assert_eq!(medium.capacity, 3);
        assert_eq!(medium.remaining(), 1);
        let high = layout.high.expect("Rifter high");
        assert_eq!(high.used, 3);
        assert_eq!(high.capacity, 3);
        assert_eq!(high.remaining(), 0);
        assert!(!high.is_over());
        let rig = layout.rig.expect("Rifter rig");
        assert_eq!(rig.used, 1);
        assert_eq!(rig.capacity, 3);
        assert_eq!(rig.remaining(), 2);
        let turret = layout.turret.expect("Rifter turret");
        assert_eq!(turret.used, 3);
        assert_eq!(turret.capacity, 3);
        assert_eq!(turret.remaining(), 0);
        assert_eq!(turret.excluded_modules, 0);
        let launcher = layout.launcher.expect("Rifter launcher");
        assert_eq!(launcher.used, 0);
        assert_eq!(launcher.capacity, 2);
        assert_eq!(launcher.remaining(), 2);

        // DNA 587:2889;2:499;1:: expands to 2 turret + 1
        // launcher = high 3 of 3, turret 2 of 3 (3 - 2 = 1
        // left), launcher 1 of 2 (2 - 1 = 1 left).
        let dna = match parse_dna("587:2889;2:499;1::", &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("sample DNA must import: {fatal:?}"),
        };
        let layout = available(slot_layout(&dna, &catalogue));
        let high = layout.high.expect("Rifter high");
        assert_eq!(high.used, 3);
        assert_eq!(high.capacity, 3);
        assert_eq!(high.remaining(), 0);
        let turret = layout.turret.expect("Rifter turret");
        assert_eq!(turret.used, 2);
        assert_eq!(turret.capacity, 3);
        assert_eq!(turret.remaining(), 1);
        let launcher = layout.launcher.expect("Rifter launcher");
        assert_eq!(launcher.used, 1);
        assert_eq!(launcher.capacity, 2);
        assert_eq!(launcher.remaining(), 1);

        // EFT with 4 high modules on a Rifter shows over
        // (imports are not capacity-checked).
        let over_eft = concat!(
            "[Rifter, Over Brawler]\n",
            "\n",
            "\n",
            "200mm AutoCannon II\n",
            "200mm AutoCannon II\n",
            "200mm AutoCannon II\n",
            "200mm AutoCannon II"
        );
        let synth = match parse_eft(over_eft, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("over EFT must import: {fatal:?}"),
        };
        let layout = available(slot_layout(&synth, &catalogue));
        let high = layout.high.expect("Rifter high");
        assert_eq!(high.used, 4);
        assert_eq!(high.capacity, 3);
        assert_eq!(high.remaining(), -1);
        assert!(high.is_over());
        let turret = layout.turret.expect("Rifter turret");
        assert_eq!(turret.used, 4);
        assert!(turret.is_over());
    }
}
