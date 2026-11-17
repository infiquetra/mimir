//! Pure base damage-per-second calculation over the bundled
//! catalogue.
//!
//! [`fitting_dps`] computes per-family base damage rates for
//! one [`CharacterFitting`] from base (unmodified) catalogue
//! data only: turret, launcher, drone, and fighter families,
//! plus the count of fitted weapon candidates with no
//! loaded-charge pairing on the current surface. See
//! `docs/fitting-dps-design.md`.
//!
//! The module is pure computation over the bundled catalogue —
//! no egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] / [`FittingItem`] (the saved shape),
//! [`ImportedFitting`] (charge pairings, EFT surface only),
//! and [`FittingTypes`], mirroring the [`bay_usage`] shape. It
//! tests ESI flag strings itself instead of depending on the
//! UI enum, following the `bay_usage` flag-prefix independence
//! precedent. It logs nothing: it runs at render cadence, so
//! per-frame `[FITTING]` logging would spam the log; the
//! catalogue load already logs counts once.
//!
//! Formulas are Flutter's (`dogma_engine.dart` at `ed698d3`),
//! quoted in design sections 2.2 and 4, at base values only.
//! No total is ever returned: the four families are reported
//! independently and the caller never sums them.

use crate::esi::models::{CharacterFitting, FittingItem};
use crate::fitting::eft::{ImportFormat, ImportSection, ImportedFitting};
use crate::names::fitting_types::{FittingType, FittingTypes};

/// One weapon family's base damage rate. `dps` is an
/// unrounded `f64`; rounding exists only in the UI formatter.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FamilyDps {
    pub dps: f64,
    /// Counted-section items with no usable damage data for
    /// this family, in quantity units, never silently zero.
    pub excluded_items: usize,
}

/// Base damage rates for one fitting. Each family is `None`
/// when that family has no honest number on this surface
/// (design section 5): turrets/launchers without an EFT
/// surface, drones without ship bandwidth, fighters without
/// fighter capacity plus tubes. A present `Some` at 0.0 DPS
/// is a real zero, never a placeholder.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FittingDps {
    pub turrets: Option<FamilyDps>,
    pub launchers: Option<FamilyDps>,
    pub drones: Option<FamilyDps>,
    pub fighters: Option<FamilyDps>,
    /// Fitted weapon candidates with no loaded-charge pairing
    /// on this surface (design section 2.3), in quantity
    /// units.
    pub unloaded_weapons: usize,
}

/// Damage-per-second outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FittingDpsOutcome {
    Available(FittingDps),
    /// The catalogue has no usable ship row, or no family is
    /// available and no weapon is counted as unloaded.
    Unavailable,
}

/// Whether a saved-fitting flag is a slot-section flag,
/// following the grouped item list predicate in
/// `src/ui/fittings.rs` (`section_for_flag`) via the
/// `bay_usage` slot predicate: the `LoSlot` / `MedSlot` /
/// `HiSlot` / `RigSlot` / `SubSystemSlot` prefixes count as
/// slots; every other flag — including `DroneBay`,
/// `FighterBay`, `Cargo`, `Invalid`, `ServiceSlot0`, `""`,
/// and any unknown flag — does not. The weapon candidate
/// pass is flag-driven (then category- and cycle-bounded),
/// never category-driven alone.
fn is_slot_flag(flag: &str) -> bool {
    flag.starts_with("LoSlot")
        || flag.starts_with("MedSlot")
        || flag.starts_with("HiSlot")
        || flag.starts_with("RigSlot")
        || flag.starts_with("SubSystemSlot")
}

/// A catalogue value is usable only when present, finite,
/// and non-negative. A present `0.0` stays a real zero;
/// anything else is treated as no data for that computation.
fn usable(value: Option<f64>) -> Option<f64> {
    value.filter(|v| v.is_finite() && *v >= 0.0)
}

/// Sum of a fighter ability's four damage components with
/// the same absent-0.0 / present-unusable-excludes rule as
/// [`damage_sum`]. Fighter ability damage lives on the
/// ability-specific attributes (2227-2230 attack,
/// 2131-2134 missiles), never on the charge/drone fields.
fn fighter_damage_sum(
    em: Option<f64>,
    therm: Option<f64>,
    kin: Option<f64>,
    exp: Option<f64>,
) -> Option<f64> {
    let mut sum = 0.0;
    for component in [em, therm, kin, exp] {
        match component {
            None => {}
            Some(0.0) => {}
            Some(value) if value.is_finite() && value >= 0.0 => sum += value,
            Some(_) => return None,
        }
    }
    Some(sum)
}

/// A cycle or duration value is usable for damage only when
/// present, finite, and strictly positive.
fn usable_cycle(value: Option<f64>) -> Option<f64> {
    value.filter(|v| v.is_finite() && *v > 0.0)
}

/// Sum of the four damage components on a catalogued row:
/// an absent component reads as 0.0 (the SDE default, design
/// section 2.2). A present-but-unusable component yields
/// `None` so the caller excludes that item (fixture
/// catalogues only; the shipped catalogue never carries one).
fn damage_sum(row: &FittingType) -> Option<f64> {
    let mut sum = 0.0;
    for component in [
        row.em_damage,
        row.explosive_damage,
        row.kinetic_damage,
        row.thermal_damage,
    ] {
        match component {
            None => {}
            Some(0.0) => {}
            Some(value) if value.is_finite() && value >= 0.0 => sum += value,
            Some(_) => return None,
        }
    }
    Some(sum)
}

/// Quantity in units for an item row: clamped at zero, so a
/// negative quantity contributes and excludes nothing.
fn item_units(item: &FittingItem) -> usize {
    usize::try_from(item.quantity.max(0)).unwrap_or(0)
}

/// Base damage rates for one fitting. `imported` is the
/// imported fitting on the imported detail (EFT pairings are
/// read from it; DNA behaves like the saved surface) and
/// `None` on the saved detail. Ship resolution mirrors
/// `bay_usage`: `ship_type_id` must be positive, resolve in
/// the catalogue, and be category 6, else `Unavailable`.
pub fn fitting_dps(
    fitting: &CharacterFitting,
    imported: Option<&ImportedFitting>,
    catalogue: &FittingTypes,
) -> FittingDpsOutcome {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        return FittingDpsOutcome::Unavailable;
    };
    if ship.category_id != 6 {
        return FittingDpsOutcome::Unavailable;
    }

    // Weapon pass (turrets and launchers), in input order.
    // On the EFT surface both families start as `Some(0.0)`
    // (design section 4), so an EFT fitting lists them even
    // when nothing pairs; on saved/DNA surfaces they stay
    // `None` and candidates count as unloaded instead.
    let is_eft = imported.is_some_and(|imp| imp.format == ImportFormat::Eft);
    let mut turret_state: Option<FamilyDps> = is_eft.then_some(FamilyDps {
        dps: 0.0,
        excluded_items: 0,
    });
    let mut launcher_state: Option<FamilyDps> = is_eft.then_some(FamilyDps {
        dps: 0.0,
        excluded_items: 0,
    });
    let mut unloaded_weapons: usize = 0;
    for (type_id, quantity, charge_type_id) in slot_rows(fitting, imported) {
        let Some(row) = catalogue.lookup_by_id(type_id) else {
            // A catalogue-absent row cannot be classified;
            // the resources block already discloses it.
            continue;
        };
        // Candidate gate (design section 2.4): category 7 or
        // 32, and a usable cycle strictly above zero. The
        // category bound excludes a category-18 drone filed
        // under a slot flag (the demo's 28270 pin).
        if !matches!(row.category_id, 7 | 32) {
            continue;
        }
        let Some(cycle) = usable_cycle(row.speed) else {
            continue;
        };
        let units = usize::try_from(quantity.max(0)).unwrap_or(0);
        if units == 0 {
            continue;
        }
        if !is_eft {
            // Saved and DNA surfaces carry no pairing by
            // construction (design section 2.3).
            unloaded_weapons = unloaded_weapons.saturating_add(units);
            continue;
        }
        // Family is decided first by attribute 64 presence,
        // never by the hardpoint booleans.
        let is_turret = row.damage_multiplier.is_some();
        let family = if is_turret {
            turret_state.as_mut().expect("EFT turret family exists")
        } else {
            launcher_state.as_mut().expect("EFT launcher family exists")
        };
        let Some(charge_id) = charge_type_id else {
            unloaded_weapons = unloaded_weapons.saturating_add(units);
            continue;
        };
        // Turret severity: a present-but-unusable multiplier
        // excludes the candidate into the turret family.
        let multiplier = if is_turret {
            match usable(row.damage_multiplier) {
                Some(value) => value,
                None => {
                    family.excluded_items = family.excluded_items.saturating_add(units);
                    continue;
                }
            }
        } else {
            1.0
        };
        let Some(charge_row) = catalogue.lookup_by_id(charge_id) else {
            family.excluded_items = family.excluded_items.saturating_add(units);
            continue;
        };
        let Some(charge_sum) = damage_sum(charge_row) else {
            family.excluded_items = family.excluded_items.saturating_add(units);
            continue;
        };
        // A zero charge sum is a known zero: neither
        // unloaded nor excluded.
        if charge_sum <= 0.0 {
            continue;
        }
        family.dps += charge_sum * multiplier / (cycle / 1000.0);
    }

    // Drone pass, in `DroneBay` fit order.
    let drones = drone_dps(fitting, ship, catalogue);

    // Fighter pass, in `FighterBay` fit order.
    let fighters = fighter_dps(fitting, ship, catalogue);

    if turret_state.is_none()
        && launcher_state.is_none()
        && drones.is_none()
        && fighters.is_none()
        && unloaded_weapons == 0
    {
        return FittingDpsOutcome::Unavailable;
    }

    FittingDpsOutcome::Available(FittingDps {
        turrets: turret_state,
        launchers: launcher_state,
        drones,
        fighters,
        unloaded_weapons,
    })
}

/// Slot-section rows as (type, quantity, charge type) in
/// input order. On the imported surface the sections come
/// from the imported items (so EFT pairings survive); on
/// the saved surface they come from the saved slot flags.
fn slot_rows(
    fitting: &CharacterFitting,
    imported: Option<&ImportedFitting>,
) -> Vec<(i64, i64, Option<i64>)> {
    if let Some(imp) = imported {
        return imp
            .items
            .iter()
            .filter(|item| {
                matches!(
                    item.section,
                    ImportSection::Low
                        | ImportSection::Medium
                        | ImportSection::High
                        | ImportSection::Rig
                        | ImportSection::Subsystem
                )
            })
            .map(|item| {
                (
                    item.type_id,
                    item.quantity,
                    item.charge.as_ref().map(|charge| charge.type_id),
                )
            })
            .collect();
    }
    fitting
        .items
        .iter()
        .filter(|item| is_slot_flag(&item.flag))
        .map(|item| (item.type_id, item.quantity, None))
        .collect()
}

/// Drone pass (`DroneBay` rows in fit order). Available only
/// when the ship's drone bandwidth is usable; an absent
/// bandwidth (2863 Primae) yields `None` and the rows then
/// accumulate nothing, not even excluded counts. Active
/// count is bandwidth-capped, in Flutter's order (design
/// sections 2.2 and 2.6 rule 2): bandwidth is consumed by
/// the active count before the cycle check, and drones past
/// the cap are known-not-flying spares (neither DPS nor
/// excluded).
fn drone_dps(
    fitting: &CharacterFitting,
    ship: &FittingType,
    catalogue: &FittingTypes,
) -> Option<FamilyDps> {
    let mut bandwidth_left = usable(ship.drone_bandwidth)?;
    let mut family = FamilyDps {
        dps: 0.0,
        excluded_items: 0,
    };
    for item in &fitting.items {
        if item.flag != "DroneBay" || item.type_id <= 0 {
            continue;
        }
        let units = item_units(item);
        if units == 0 {
            continue;
        }
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            family.excluded_items = family.excluded_items.saturating_add(units);
            continue;
        };
        // Volley: components absent = 0.0; multiplied by the
        // damage modifier when present and usable. A
        // present-but-unusable component or multiplier
        // excludes the group before allocation (fixture
        // catalogues only; shipped rows never carry one).
        let Some(components) = damage_sum(row) else {
            family.excluded_items = family.excluded_items.saturating_add(units);
            continue;
        };
        let volley = match usable(row.damage_multiplier) {
            Some(multiplier) => components * multiplier,
            None if row.damage_multiplier.is_some() => {
                family.excluded_items = family.excluded_items.saturating_add(units);
                continue;
            }
            None => components,
        };
        // The bandwidth gate, in Flutter's order. A usable
        // cost caps the active count and consumes bandwidth
        // even when volley or cycle then yields zero DPS. An
        // absent or unusable cost consumes nothing; a
        // damaging group with a usable cycle then counts as
        // excluded (design section 2.6 rule 3), otherwise it
        // is a silent known zero.
        let quantity_f = units as f64;
        let active: f64 = match usable(row.drone_bandwidth_used) {
            Some(needed) if needed > 0.0 => {
                let cap = (bandwidth_left / needed).floor();
                let active = quantity_f.min(cap.max(0.0));
                bandwidth_left -= active * needed;
                active
            }
            Some(_) => quantity_f,
            None => {
                if volley > 0.0 && usable_cycle(row.speed).is_some() {
                    family.excluded_items = family.excluded_items.saturating_add(units);
                }
                continue;
            }
        };
        if let Some(cycle) = usable_cycle(row.speed) {
            family.dps += active * volley / (cycle / 1000.0);
        }
    }
    Some(family)
}

/// Fighter pass (`FighterBay` rows in fit order). Available
/// only when the ship's fighter capacity and fighter tubes
/// are both usable; otherwise `None` and the rows accumulate
/// nothing. Class caps read absent as 0 (the SDE default;
/// Flutter `hullCap`); bay capacity never caps the result.
fn fighter_dps(
    fitting: &CharacterFitting,
    ship: &FittingType,
    catalogue: &FittingTypes,
) -> Option<FamilyDps> {
    usable(ship.fighter_capacity)?;
    let mut tubes_left = int_part(usable(ship.fighter_tubes)?);
    let mut light_left = int_part(usable(ship.fighter_light_slots).unwrap_or(0.0));
    let mut support_left = int_part(usable(ship.fighter_support_slots).unwrap_or(0.0));
    let mut heavy_left = int_part(usable(ship.fighter_heavy_slots).unwrap_or(0.0));
    let mut family = FamilyDps {
        dps: 0.0,
        excluded_items: 0,
    };
    for item in &fitting.items {
        if item.flag != "FighterBay" || item.type_id <= 0 {
            continue;
        }
        let units = item_units(item);
        if units == 0 {
            continue;
        }
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            family.excluded_items = family.excluded_items.saturating_add(units);
            continue;
        };
        // Squadron size: absent, unusable, or with integer
        // part <= 0 excludes the group (a non-fighter row
        // filed under `FighterBay` is honestly "no fighter
        // damage data").
        let Some(size_raw) = usable(row.fighter_squadron_max_size) else {
            family.excluded_items = family.excluded_items.saturating_add(units);
            continue;
        };
        let max_size = int_part(size_raw);
        if max_size == 0 {
            family.excluded_items = family.excluded_items.saturating_add(units);
            continue;
        }
        // Ability: attack preferred, else missiles, else
        // none (design section 2.2). An ability present but
        // its duration absent, unusable, or <= 0 excludes
        // the group and consumes no tube (design section
        // 2.6 rule 6).
        let ability = if row.fighter_ability_attack {
            FighterAbility::Attack
        } else if row.fighter_ability_missiles {
            FighterAbility::Missiles
        } else {
            FighterAbility::None
        };
        let (components, modifier, duration) = match ability {
            FighterAbility::Attack => {
                let Some(duration) = usable_cycle(row.fighter_attack_duration) else {
                    family.excluded_items = family.excluded_items.saturating_add(units);
                    continue;
                };
                let Some(components) = fighter_damage_sum(
                    row.fighter_attack_damage_em,
                    row.fighter_attack_damage_therm,
                    row.fighter_attack_damage_kin,
                    row.fighter_attack_damage_exp,
                ) else {
                    family.excluded_items = family.excluded_items.saturating_add(units);
                    continue;
                };
                let modifier = match usable(row.fighter_attack_damage_multiplier) {
                    Some(value) => value,
                    None if row.fighter_attack_damage_multiplier.is_some() => {
                        family.excluded_items = family.excluded_items.saturating_add(units);
                        continue;
                    }
                    None => 1.0,
                };
                (components, modifier, duration)
            }
            FighterAbility::Missiles => {
                let Some(duration) = usable_cycle(row.fighter_missiles_duration) else {
                    family.excluded_items = family.excluded_items.saturating_add(units);
                    continue;
                };
                let Some(components) = fighter_damage_sum(
                    row.fighter_missiles_damage_em,
                    row.fighter_missiles_damage_therm,
                    row.fighter_missiles_damage_kin,
                    row.fighter_missiles_damage_exp,
                ) else {
                    family.excluded_items = family.excluded_items.saturating_add(units);
                    continue;
                };
                let modifier = match usable(row.fighter_missiles_damage_multiplier) {
                    Some(value) => value,
                    None if row.fighter_missiles_damage_multiplier.is_some() => {
                        family.excluded_items = family.excluded_items.saturating_add(units);
                        continue;
                    }
                    None => 1.0,
                };
                (components, modifier, duration)
            }
            FighterAbility::None => (0.0, 1.0, 0.0),
        };
        // Class from the flags in light -> support -> heavy
        // order. Falling through all three is a known zero
        // consuming nothing.
        let class_left = if usable(row.fighter_squadron_is_light).is_some_and(|v| v > 0.0) {
            &mut light_left
        } else if usable(row.fighter_squadron_is_support).is_some_and(|v| v > 0.0) {
            &mut support_left
        } else if usable(row.fighter_squadron_is_heavy).is_some_and(|v| v > 0.0) {
            &mut heavy_left
        } else {
            continue;
        };
        // Squadrons fill sequentially at sizes
        // `min(maxSize, remaining)`. Only the first squadrons
        // can be active (bounded by remaining tubes and the
        // class cap); the rest are known inactive spares.
        // The active fighters are therefore the first
        // `active_squadrons * maxSize` fighters. Arithmetic
        // is in `i128` so `i64::MAX` quantities stay exact.
        let quantity = i128::from(item.quantity.max(0));
        let size = i128::try_from(max_size).unwrap_or(i128::MAX);
        let total_squadrons = (quantity + size - 1) / size;
        let active_squadrons = total_squadrons
            .min(i128::try_from(tubes_left).unwrap_or(i128::MAX))
            .min(i128::try_from(*class_left).unwrap_or(i128::MAX));
        if active_squadrons > 0 {
            let consumed = usize::try_from(active_squadrons).unwrap_or(0);
            tubes_left = tubes_left.saturating_sub(consumed);
            *class_left = class_left.saturating_sub(consumed);
        }
        if ability == FighterAbility::None || active_squadrons <= 0 {
            continue;
        }
        let active_fighters = (active_squadrons * size).min(quantity);
        let per_fighter = components * modifier / (duration / 1000.0);
        family.dps += active_fighters as f64 * per_fighter;
    }
    Some(family)
}

/// The damage ability chosen for a fighter group, attack
/// preferred (design section 2.2).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum FighterAbility {
    Attack,
    Missiles,
    None,
}

/// Integer part of a usable catalogue count (tubes, class
/// caps, squadron size), saturating at `usize::MAX`.
fn int_part(value: f64) -> usize {
    if value <= 0.0 || !value.is_finite() {
        return 0;
    }
    let truncated = value.trunc();
    if truncated >= usize::MAX as f64 {
        usize::MAX
    } else {
        truncated as usize
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fitting::dna::parse_import;
    use crate::fitting::eft::{
        parse_eft, EftImportOutcome, ImportFormat, ImportReport, ImportSection, ImportedCharge,
        ImportedFitting, ImportedItem,
    };

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

    fn available(result: FittingDpsOutcome) -> FittingDps {
        match result {
            FittingDpsOutcome::Available(dps) => dps,
            FittingDpsOutcome::Unavailable => panic!("expected Available, got Unavailable"),
        }
    }

    fn unavailable(result: FittingDpsOutcome) {
        assert_eq!(result, FittingDpsOutcome::Unavailable);
    }

    fn assert_close(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "expected {expected}, got {actual}"
        );
    }

    fn imported_eft(ship_type_id: i64, items: Vec<ImportedItem>) -> ImportedFitting {
        ImportedFitting {
            name: "test".to_string(),
            ship_type_id,
            ship_name: "Fixture Ship".to_string(),
            format: ImportFormat::Eft,
            report: ImportReport {
                imported_lines: items.len(),
                placeholder_lines: 0,
                charges_noted: 0,
                issues: Vec::new(),
            },
            items,
        }
    }

    fn imported_item(type_id: i64, quantity: i64, charge: Option<ImportedCharge>) -> ImportedItem {
        ImportedItem {
            type_id,
            name: format!("Item {type_id}"),
            section: ImportSection::High,
            quantity,
            charge,
        }
    }

    fn charge(type_id: i64) -> ImportedCharge {
        ImportedCharge {
            type_id,
            name: format!("Charge {type_id}"),
        }
    }

    /// Fixture ship (600) carrying only drone bandwidth, a
    /// fixture turret (700: speed 4000.0, multiplier 2.0), a
    /// fixture launcher (701: speed 2000.0, no multiplier),
    /// and a fixture charge (702: kinetic 100.0, other
    /// components absent = 0.0).
    fn fixture_weapons() -> FittingTypes {
        FittingTypes::from_json(
            r#"{"types":[
                {"typeId":600,"typeName":"Fixture Ship","categoryId":6,"slotEffects":[],"volume":1.0,"droneBandwidth":0.0},
                {"typeId":700,"typeName":"Fixture Turret","categoryId":7,"slotEffects":[12],"speed":4000.0,"damageMultiplier":2.0},
                {"typeId":701,"typeName":"Fixture Launcher","categoryId":7,"slotEffects":[12],"speed":2000.0},
                {"typeId":702,"typeName":"Fixture Charge","categoryId":8,"slotEffects":[],"kineticDamage":100.0}]}"#,
        )
        .expect("fixture catalogue parses")
    }

    // Test 1: turret synthetic Flutter cross-check (design
    // section 8). Module speed 4000.0, multiplier 2.0; charge
    // kinetic 100.0 (other components absent = 0.0). Volley
    // 100 * 2.0 = 200; 200 / 4.0 = 50.0.
    #[test]
    fn turret_synthetic_flutter_cross_check() {
        let catalogue = fixture_weapons();
        let imp = imported_eft(600, vec![imported_item(700, 1, Some(charge(702)))]);
        let synth = imp.to_character_fitting();
        let dps = available(fitting_dps(&synth, Some(&imp), &catalogue));
        assert_close(dps.turrets.expect("turret family").dps, 50.0);
        assert_eq!(dps.turrets.expect("turret family").excluded_items, 0);
        assert_close(dps.launchers.expect("launcher family").dps, 0.0);
        assert_eq!(dps.launchers.expect("launcher family").excluded_items, 0);
        assert_eq!(dps.unloaded_weapons, 0);
    }

    // Test 2: launcher synthetic and real. Same charge against
    // speed 2000.0 with no multiplier: 100 / 2.0 = 50.0. Real:
    // 2404 speed 12800.0 with 210 kinetic 83.0 through
    // parse_eft text: 83 / 12.8 = 6.484375.
    #[test]
    fn launcher_synthetic_and_real() {
        let catalogue = fixture_weapons();
        let imp = imported_eft(600, vec![imported_item(701, 1, Some(charge(702)))]);
        let synth = imp.to_character_fitting();
        let dps = available(fitting_dps(&synth, Some(&imp), &catalogue));
        assert_close(dps.launchers.expect("launcher family").dps, 50.0);
        assert_close(dps.turrets.expect("turret family").dps, 0.0);
        assert_eq!(dps.unloaded_weapons, 0);

        let catalogue = bundled();
        let text = "[Rifter, Launcher Test]\n\nLight Missile Launcher II, Scourge Light Missile\n";
        let outcome = parse_eft(text, &catalogue);
        let EftImportOutcome::Imported(imp) = outcome else {
            panic!("EFT import succeeds");
        };
        // 83 / (12800 / 1000) = 83 / 12.8 = 6.484375.
        let synth = imp.to_character_fitting();
        let dps = available(fitting_dps(&synth, Some(&imp), &catalogue));
        assert_close(dps.launchers.expect("launcher family").dps, 6.484375);
        assert_close(dps.turrets.expect("turret family").dps, 0.0);
        assert_eq!(dps.unloaded_weapons, 0);
    }

    // Test 3: turret real. 484 (speed 3000.0, multiplier
    // 2.0625) with 180 (3.0 + 0.0 + 2.0 + 0.0 = 5.0): volley
    // 5.0 * 2.0625 = 10.3125; 10.3125 / 3.0 = 3.4375. The
    // sample-EFT arithmetic (2889 with 21898): sum 10.35 +
    // 2.3 + 1.15 + 0.0 = 13.8; 13.8 * 3.465 = 47.817;
    // 47.817 / 3.75 = 12.7512.
    #[test]
    fn turret_real() {
        let catalogue = bundled();
        let text = "[Rifter, Turret Test]\n\n125mm Gatling AutoCannon I, Proton S\n";
        let outcome = parse_eft(text, &catalogue);
        let EftImportOutcome::Imported(imp) = outcome else {
            panic!("EFT import succeeds");
        };
        let synth = imp.to_character_fitting();
        let dps = available(fitting_dps(&synth, Some(&imp), &catalogue));
        assert_close(dps.turrets.expect("turret family").dps, 3.4375);

        let text = "[Rifter, Sample]\n\n200mm AutoCannon II, Republic Fleet EMP S\n";
        let outcome = parse_eft(text, &catalogue);
        let EftImportOutcome::Imported(imp) = outcome else {
            panic!("EFT import succeeds");
        };
        let synth = imp.to_character_fitting();
        let dps = available(fitting_dps(&synth, Some(&imp), &catalogue));
        assert_close(dps.turrets.expect("turret family").dps, 12.7512);
    }

    // Test 4: drones real and capped. Tristan 593 bandwidth
    // 25.0; Warrior II 2488 volley 20.0 * 1.56 = 31.2, per
    // drone 31.2 / 4.0 = 7.8. 5 active (floor(25/5)) ->
    // 39.0. 8 fitted still 5 active -> 39.0, excluded 0.
    // 5 Warriors then 5 Hobgoblins: Warriors consume all
    // bandwidth -> still 39.0 (fit order observable).
    #[test]
    fn drones_real_and_capped() {
        let catalogue = bundled();
        let dps = available(fitting_dps(
            &fitting(593, vec![item("DroneBay", 5, 2488)]),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 39.0);
        assert_eq!(dps.drones.expect("drone family").excluded_items, 0);

        let dps = available(fitting_dps(
            &fitting(593, vec![item("DroneBay", 8, 2488)]),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 39.0);
        assert_eq!(dps.drones.expect("drone family").excluded_items, 0);

        let dps = available(fitting_dps(
            &fitting(
                593,
                vec![item("DroneBay", 5, 2488), item("DroneBay", 5, 2456)],
            ),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 39.0);
    }

    // Test 5: drone synthetic Flutter cap cross-check.
    // Fixture drone explosive 10.0, multiplier 2.0, cycle
    // 4000.0, cost 5.0: volley 20, 5.0 each. Bandwidth 25.0 ->
    // 5 active -> 25.0. Bandwidth 12.0 -> floor(12/5) = 2 ->
    // 10.0. Rifter 587 bandwidth 0.0 + Hobgoblins -> 0.0,
    // family Some.
    #[test]
    fn drone_synthetic_flutter_cap_cross_check() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":601,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"volume":1.0,"droneBandwidth":25.0},
                {"typeId":602,"typeName":"Fixture Drone","categoryId":18,"slotEffects":[],"speed":4000.0,"damageMultiplier":2.0,"explosiveDamage":10.0,"droneBandwidthUsed":5.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let dps = available(fitting_dps(
            &fitting(601, vec![item("DroneBay", 5, 602)]),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 25.0);

        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":601,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"volume":1.0,"droneBandwidth":12.0},
                {"typeId":602,"typeName":"Fixture Drone","categoryId":18,"slotEffects":[],"speed":4000.0,"damageMultiplier":2.0,"explosiveDamage":10.0,"droneBandwidthUsed":5.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let dps = available(fitting_dps(
            &fitting(601, vec![item("DroneBay", 5, 602)]),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 10.0);

        let catalogue = bundled();
        let dps = available(fitting_dps(
            &fitting(587, vec![item("DroneBay", 5, 2456)]),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 0.0);
    }

    // Test 6: drone known-zero and unknown. 60478 (no DPS
    // attributes) on Tristan -> 0.0, excluded 0. Catalogue-
    // absent drone x3 -> 0.0, excluded 3. Fixture drone with
    // volley > 0 and cycle but no bandwidth cost -> excluded
    // by quantity, no bandwidth consumed (a following known-
    // cost group still flies its full count). Fixture non-
    // damaging drone with a cost consumes bandwidth before a
    // later combat group (Flutter consumption order).
    #[test]
    fn drone_known_zero_and_unknown() {
        let catalogue = bundled();
        let dps = available(fitting_dps(
            &fitting(593, vec![item("DroneBay", 2, 60478)]),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 0.0);
        assert_eq!(dps.drones.expect("drone family").excluded_items, 0);

        let dps = available(fitting_dps(
            &fitting(593, vec![item("DroneBay", 3, 999999)]),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 0.0);
        assert_eq!(dps.drones.expect("drone family").excluded_items, 3);

        // Two fixture drones: 610 damaging without a cost,
        // 611 known-cost combat (full fixture shape from
        // test 5). The costless group excludes 2 units and
        // consumes nothing; the known-cost group still
        // flies 5 at bandwidth 25.0 -> 25.0.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":601,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"volume":1.0,"droneBandwidth":25.0},
                {"typeId":610,"typeName":"Costless Drone","categoryId":18,"slotEffects":[],"speed":4000.0,"damageMultiplier":2.0,"explosiveDamage":10.0},
                {"typeId":611,"typeName":"Costed Drone","categoryId":18,"slotEffects":[],"speed":4000.0,"damageMultiplier":2.0,"explosiveDamage":10.0,"droneBandwidthUsed":5.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let dps = available(fitting_dps(
            &fitting(
                601,
                vec![item("DroneBay", 2, 610), item("DroneBay", 5, 611)],
            ),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 25.0);
        assert_eq!(dps.drones.expect("drone family").excluded_items, 2);

        // A non-damaging drone with cost 5.0 (all components
        // absent = 0.0, cycle present) first consumes all
        // bandwidth; the later combat group flies 0.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":601,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"volume":1.0,"droneBandwidth":25.0},
                {"typeId":620,"typeName":"Blank Drone","categoryId":18,"slotEffects":[],"speed":4000.0,"droneBandwidthUsed":5.0},
                {"typeId":611,"typeName":"Costed Drone","categoryId":18,"slotEffects":[],"speed":4000.0,"damageMultiplier":2.0,"explosiveDamage":10.0,"droneBandwidthUsed":5.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let dps = available(fitting_dps(
            &fitting(
                601,
                vec![item("DroneBay", 5, 620), item("DroneBay", 5, 611)],
            ),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 0.0);
        assert_eq!(dps.drones.expect("drone family").excluded_items, 0);
    }

    // Test 7: fighters real. Thanatos 23911 (tubes 3, light 3,
    // support 1, heavy absent -> 0) + 18x23059 Firbolg I
    // (size 9, light, both markers -> attack; thermal 75.0,
    // multiplier 1.0, duration 5000.0): squadrons 9 + 9;
    // each volley 75.0 * 1.0 * 9 = 675; 675 / 5.0 = 135.0
    // each -> 270.0. 10x23059 -> 9 + 1: 135.0 + 15.0 = 150.0.
    #[test]
    fn fighters_real() {
        let catalogue = bundled();
        let dps = available(fitting_dps(
            &fitting(23911, vec![item("FighterBay", 18, 23059)]),
            None,
            &catalogue,
        ));
        assert_close(dps.fighters.expect("fighter family").dps, 270.0);
        assert_eq!(dps.fighters.expect("fighter family").excluded_items, 0);

        let dps = available(fitting_dps(
            &fitting(23911, vec![item("FighterBay", 10, 23059)]),
            None,
            &catalogue,
        ));
        assert_close(dps.fighters.expect("fighter family").dps, 150.0);
    }

    // Test 8: fighter synthetic cross-checks. Flutter shape:
    // components summing 207, multiplier 1.0, size 6, duration
    // 5000.0 -> 6 * 207 / 5 = 248.4. Missiles-only: components
    // 36, size 12, duration 3500.0 -> 12 * 36 / 3.5 =
    // 123.428571.... Tube cap 5 squadrons vs 4 tubes ->
    // 4 * 248.4. Heavy cap 0 -> 0.0, family Some. Absent
    // multiplier -> x1.0. Launchable no-ability consumes a
    // tube from a later group. No-size group excluded, no
    // tube consumed. Non-carrier -> None.
    #[test]
    fn fighter_synthetic_cross_checks() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":601,"typeName":"Fixture Carrier","categoryId":6,"slotEffects":[],"volume":1.0,"fighterCapacity":100000.0,"fighterTubes":10.0,"fighterLightSlots":10.0,"fighterSupportSlots":10.0,"fighterHeavySlots":10.0},
                {"typeId":701,"typeName":"Attack Fighter","categoryId":87,"slotEffects":[],"fighterSquadronMaxSize":6.0,"fighterSquadronIsLight":1.0,"fighterAbilityAttackMissileDamageMultiplier":1.0,"fighterAbilityAttackMissileDamageEM":200.0,"fighterAbilityAttackMissileDamageTherm":7.0,"fighterAbilityAttackMissileDuration":5000.0,"fighterAbilityAttackM":true},
                {"typeId":702,"typeName":"Missiles Fighter","categoryId":87,"slotEffects":[],"fighterSquadronMaxSize":12.0,"fighterSquadronIsLight":1.0,"fighterAbilityMissilesDamageEM":36.0,"fighterAbilityMissilesDuration":3500.0,"fighterAbilityMissiles":true}]}"#,
        )
        .expect("fixture catalogue parses");
        let dps = available(fitting_dps(
            &fitting(601, vec![item("FighterBay", 6, 701)]),
            None,
            &catalogue,
        ));
        assert_close(dps.fighters.expect("fighter family").dps, 248.4);

        let dps = available(fitting_dps(
            &fitting(601, vec![item("FighterBay", 12, 702)]),
            None,
            &catalogue,
        ));
        assert_close(dps.fighters.expect("fighter family").dps, 12.0 * 36.0 / 3.5);

        // Tube cap: 5 squadrons (30 fighters) vs 4 tubes ->
        // 4 * 248.4 = 993.6.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":601,"typeName":"Fixture Carrier","categoryId":6,"slotEffects":[],"volume":1.0,"fighterCapacity":100000.0,"fighterTubes":4.0,"fighterLightSlots":10.0,"fighterSupportSlots":10.0,"fighterHeavySlots":10.0},
                {"typeId":701,"typeName":"Attack Fighter","categoryId":87,"slotEffects":[],"fighterSquadronMaxSize":6.0,"fighterSquadronIsLight":1.0,"fighterAbilityAttackMissileDamageMultiplier":1.0,"fighterAbilityAttackMissileDamageEM":207.0,"fighterAbilityAttackMissileDuration":5000.0,"fighterAbilityAttackM":true}]}"#,
        )
        .expect("fixture catalogue parses");
        let dps = available(fitting_dps(
            &fitting(601, vec![item("FighterBay", 30, 701)]),
            None,
            &catalogue,
        ));
        assert_close(dps.fighters.expect("fighter family").dps, 4.0 * 248.4);

        // Class cap: heavy cap 0 on a heavy group -> 0.0.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":601,"typeName":"Fixture Carrier","categoryId":6,"slotEffects":[],"volume":1.0,"fighterCapacity":100000.0,"fighterTubes":4.0,"fighterLightSlots":4.0,"fighterSupportSlots":4.0},
                {"typeId":701,"typeName":"Heavy Fighter","categoryId":87,"slotEffects":[],"fighterSquadronMaxSize":6.0,"fighterSquadronIsHeavy":1.0,"fighterAbilityAttackMissileDamageMultiplier":1.0,"fighterAbilityAttackMissileDamageEM":207.0,"fighterAbilityAttackMissileDuration":5000.0,"fighterAbilityAttackM":true}]}"#,
        )
        .expect("fixture catalogue parses");
        let dps = available(fitting_dps(
            &fitting(601, vec![item("FighterBay", 6, 701)]),
            None,
            &catalogue,
        ));
        assert_close(dps.fighters.expect("fighter family").dps, 0.0);
        assert_eq!(dps.fighters.expect("fighter family").excluded_items, 0);

        // Absent multiplier -> x1.0 (never x0.0).
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":601,"typeName":"Fixture Carrier","categoryId":6,"slotEffects":[],"volume":1.0,"fighterCapacity":100000.0,"fighterTubes":4.0,"fighterLightSlots":4.0},
                {"typeId":701,"typeName":"Attack Fighter","categoryId":87,"slotEffects":[],"fighterSquadronMaxSize":6.0,"fighterSquadronIsLight":1.0,"fighterAbilityAttackMissileDamageEM":207.0,"fighterAbilityAttackMissileDuration":5000.0,"fighterAbilityAttackM":true}]}"#,
        )
        .expect("fixture catalogue parses");
        let dps = available(fitting_dps(
            &fitting(601, vec![item("FighterBay", 6, 701)]),
            None,
            &catalogue,
        ));
        assert_close(dps.fighters.expect("fighter family").dps, 248.4);

        // Launchable no-ability group first consumes a tube
        // from a later damaging group: 1 tube, 1 no-ability
        // squadron, then a damaging squadron -> 0.0.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":601,"typeName":"Fixture Carrier","categoryId":6,"slotEffects":[],"volume":1.0,"fighterCapacity":100000.0,"fighterTubes":1.0,"fighterLightSlots":2.0},
                {"typeId":701,"typeName":"Plain Fighter","categoryId":87,"slotEffects":[],"fighterSquadronMaxSize":6.0,"fighterSquadronIsLight":1.0},
                {"typeId":702,"typeName":"Attack Fighter","categoryId":87,"slotEffects":[],"fighterSquadronMaxSize":6.0,"fighterSquadronIsLight":1.0,"fighterAbilityAttackMissileDamageEM":207.0,"fighterAbilityAttackMissileDuration":5000.0,"fighterAbilityAttackM":true}]}"#,
        )
        .expect("fixture catalogue parses");
        let dps = available(fitting_dps(
            &fitting(
                601,
                vec![item("FighterBay", 6, 701), item("FighterBay", 6, 702)],
            ),
            None,
            &catalogue,
        ));
        assert_close(dps.fighters.expect("fighter family").dps, 0.0);

        // No squadron size -> excluded by quantity, no tube
        // consumed (the later damaging group still flies).
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":601,"typeName":"Fixture Carrier","categoryId":6,"slotEffects":[],"volume":1.0,"fighterCapacity":100000.0,"fighterTubes":1.0,"fighterLightSlots":2.0},
                {"typeId":701,"typeName":"Sizeless Row","categoryId":87,"slotEffects":[],"fighterSquadronIsLight":1.0},
                {"typeId":702,"typeName":"Attack Fighter","categoryId":87,"slotEffects":[],"fighterSquadronMaxSize":6.0,"fighterSquadronIsLight":1.0,"fighterAbilityAttackMissileDamageEM":207.0,"fighterAbilityAttackMissileDuration":5000.0,"fighterAbilityAttackM":true}]}"#,
        )
        .expect("fixture catalogue parses");
        let dps = available(fitting_dps(
            &fitting(
                601,
                vec![item("FighterBay", 4, 701), item("FighterBay", 6, 702)],
            ),
            None,
            &catalogue,
        ));
        assert_close(dps.fighters.expect("fighter family").dps, 248.4);
        assert_eq!(dps.fighters.expect("fighter family").excluded_items, 4);

        // Non-carrier: Rifter + FighterBay rows -> None.
        let catalogue = bundled();
        let dps = available(fitting_dps(
            &fitting(587, vec![item("DroneBay", 5, 2456)]),
            None,
            &catalogue,
        ));
        assert!(dps.fighters.is_none());
    }

    // Test 9: charge surfaces. The same weapon rows: saved
    // shape -> turrets/launchers None, unloaded = candidate
    // count (a Cargo charge changes nothing); DNA through
    // parse_import identical; EFT with a charge line ->
    // numbers, unloaded reduced. Sigma = 0 charge -> neither
    // unloaded nor excluded. Mining laser 482 and smartbomb
    // 1563 never candidates; category-18 drone under a slot
    // flag never.
    #[test]
    fn charge_surfaces() {
        let catalogue = bundled();
        // Saved: one real turret (2889), one real launcher
        // (2404), plus a Cargo Proton S sitting beside them.
        let dps = available(fitting_dps(
            &fitting(
                587,
                vec![
                    item("HiSlot0", 1, 2889),
                    item("HiSlot1", 1, 2404),
                    item("Cargo", 10, 180),
                    item("DroneBay", 5, 2456),
                ],
            ),
            None,
            &catalogue,
        ));
        assert!(dps.turrets.is_none());
        assert!(dps.launchers.is_none());
        assert_eq!(dps.unloaded_weapons, 2);
        assert_close(dps.drones.expect("drone family").dps, 0.0);

        // DNA: same weapon rows via parse_import (quantity
        // 1 each, so the unloaded count is identical).
        let text = "587:2889:2404";
        let outcome = parse_import(text, &catalogue);
        let EftImportOutcome::Imported(imp) = outcome else {
            panic!("DNA import succeeds");
        };
        assert_eq!(imp.report.charges_noted, 0);
        let synth = imp.to_character_fitting();
        let dps = available(fitting_dps(&synth, Some(&imp), &catalogue));
        assert!(dps.turrets.is_none());
        assert!(dps.launchers.is_none());
        assert_eq!(dps.unloaded_weapons, 2);

        // EFT with one charge line: one pairing counts, the
        // unloaded count drops to the unlisted weapons.
        let text = "[Rifter, Mixed]\n\n200mm AutoCannon II, Republic Fleet EMP S\n200mm AutoCannon II\nLight Missile Launcher II\n";
        let outcome = parse_eft(text, &catalogue);
        let EftImportOutcome::Imported(imp) = outcome else {
            panic!("EFT import succeeds");
        };
        let synth = imp.to_character_fitting();
        let dps = available(fitting_dps(&synth, Some(&imp), &catalogue));
        assert_close(dps.turrets.expect("turret family").dps, 12.7512);
        assert_close(dps.launchers.expect("launcher family").dps, 0.0);
        assert_eq!(dps.unloaded_weapons, 2);

        // Zero-sum charge: fixture probe charge (all
        // components absent = 0.0) -> candidate is neither
        // unloaded nor excluded, family 0.0.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":600,"typeName":"Fixture Ship","categoryId":6,"slotEffects":[],"volume":1.0,"droneBandwidth":0.0},
                {"typeId":700,"typeName":"Fixture Turret","categoryId":7,"slotEffects":[12],"speed":4000.0,"damageMultiplier":2.0},
                {"typeId":703,"typeName":"Probe Charge","categoryId":8,"slotEffects":[]}]}"#,
        )
        .expect("fixture catalogue parses");
        let imp = imported_eft(600, vec![imported_item(700, 1, Some(charge(703)))]);
        let synth = imp.to_character_fitting();
        let dps = available(fitting_dps(&synth, Some(&imp), &catalogue));
        assert_close(dps.turrets.expect("turret family").dps, 0.0);
        assert_eq!(dps.turrets.expect("turret family").excluded_items, 0);
        assert_eq!(dps.unloaded_weapons, 0);

        // Mining laser 482 and smartbomb 1563 never
        // candidates on any surface; category-18 drone
        // 28270 under SubSystemSlot0 never.
        let catalogue = bundled();
        let dps = available(fitting_dps(
            &fitting(
                587,
                vec![
                    item("HiSlot0", 1, 482),
                    item("HiSlot1", 1, 1563),
                    item("SubSystemSlot0", 1, 28270),
                    item("DroneBay", 5, 2456),
                ],
            ),
            None,
            &catalogue,
        ));
        assert_eq!(dps.unloaded_weapons, 0);
        assert!(dps.turrets.is_none());
        assert!(dps.launchers.is_none());
        assert_close(dps.drones.expect("drone family").dps, 0.0);
    }

    // Test 10: clamps and failures. Quantity 0 and negative,
    // type_id <= 0 rows invisible; i64::MAX drone quantity
    // stays finite. Unknown ship, non-category-6 ship ->
    // Unavailable. Primae 2863 + drones -> drones None.
    // Fighter capacity but no tubes -> fighters None. The
    // slot-flag predicate over the locked flag set.
    #[test]
    fn clamps_and_failures() {
        let catalogue = bundled();
        let dps = available(fitting_dps(
            &fitting(
                593,
                vec![
                    item("DroneBay", 0, 2488),
                    item("DroneBay", -3, 2488),
                    item("DroneBay", 5, 0),
                    item("DroneBay", 5, -1),
                ],
            ),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 0.0);
        assert_eq!(dps.drones.expect("drone family").excluded_items, 0);

        // i64::MAX warriors on Tristan: active capped at 5.
        let dps = available(fitting_dps(
            &fitting(593, vec![item("DroneBay", i64::MAX, 2488)]),
            None,
            &catalogue,
        ));
        assert_close(dps.drones.expect("drone family").dps, 39.0);
        assert!(dps.drones.expect("drone family").dps.is_finite());

        // Unknown ship id, non-category-6 ship.
        unavailable(fitting_dps(&fitting(999999, vec![]), None, &catalogue));
        unavailable(fitting_dps(&fitting(34, vec![]), None, &catalogue));

        // Primae 2863 (no drone bandwidth rows at all):
        // drones-only is Unavailable (every family None, no
        // unloaded weapons); with a weapon candidate it is
        // Available with drones None and no excluded
        // leakage, and other families unaffected.
        unavailable(fitting_dps(
            &fitting(2863, vec![item("DroneBay", 5, 2488)]),
            None,
            &catalogue,
        ));
        let dps = available(fitting_dps(
            &fitting(
                2863,
                vec![item("HiSlot0", 1, 2889), item("DroneBay", 5, 2488)],
            ),
            None,
            &catalogue,
        ));
        assert!(dps.drones.is_none());
        assert!(dps.fighters.is_none());
        assert_eq!(dps.unloaded_weapons, 1);

        // Fighter capacity but no tubes: fighters None.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":601,"typeName":"Fixture Carrier","categoryId":6,"slotEffects":[],"volume":1.0,"fighterCapacity":100000.0,"droneBandwidth":25.0},
                {"typeId":602,"typeName":"Fixture Drone","categoryId":18,"slotEffects":[],"speed":4000.0,"damageMultiplier":2.0,"explosiveDamage":10.0,"droneBandwidthUsed":5.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let dps = available(fitting_dps(
            &fitting(601, vec![item("DroneBay", 5, 602)]),
            None,
            &catalogue,
        ));
        assert!(dps.fighters.is_none());
        assert_close(dps.drones.expect("drone family").dps, 25.0);

        // Slot-flag predicate pinned over the locked flag
        // set (the bay cases duplicated).
        let catalogue = bundled();
        let dps = available(fitting_dps(
            &fitting(
                587,
                vec![
                    item("HiSlot0", 1, 2889),
                    item("DroneBay", 5, 2456),
                    item("FighterBay", 3, 40556),
                    item("Cargo", 10, 180),
                    item("Invalid", 1, 2889),
                    item("ServiceSlot0", 1, 2889),
                    item("", 1, 2889),
                    item("LoSlot0", 1, 2889),
                    item("MedSlot0", 1, 2889),
                    item("RigSlot0", 1, 2889),
                    item("SubSystemSlot0", 1, 2889),
                ],
            ),
            None,
            &catalogue,
        ));
        // HiSlot0 + LoSlot0 + MedSlot0 + RigSlot0 +
        // SubSystemSlot0 copies of 2889 are candidates (5);
        // Invalid/ServiceSlot/"" copies are not.
        assert_eq!(dps.unloaded_weapons, 5);
    }
}
