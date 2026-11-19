//! Pure ship base effective hit points calculation over the bundled
//! catalogue.
//!
//! [`ship_base_ehp`] reads the hull's base hit points and base
//! damage resonances for one [`CharacterFitting`] from base
//! (unmodified) dogma attributes only and computes the base omni
//! effective hit points (EHP) per layer plus a total: each layer
//! is its hit points divided by the share-weighted resonance
//! under the omni damage profile (equal quarters of EM, thermal,
//! kinetic, and explosive damage), summed shield, then armor,
//! then hull for the total. See
//! `docs/ship-base-ehp-design.md`.
//!
//! No modifier of any kind is applied: fitted modules, rigs,
//! subsystems, skills, implants, and ship bonuses contribute
//! nothing, so the values describe the bare hull against omni
//! damage only and can differ from EVE.
//!
//! [`ship_ehp_with_module_bonuses`] applies the grounded
//! fitted-module resistance bonuses of
//! `docs/bonused-ehp-design.md` to the denominator only: the
//! numerator stays the hull's base hit points, so only the
//! resistances carry fitted-module bonuses.
//!
//! The module is pure computation over the bundled catalogue — no
//! egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] and [`FittingTypes`], the same
//! dependencies `ship_stats.rs` and `ship_resistances.rs` take.
//! It logs nothing: it runs at render cadence, so per-frame
//! `[FITTING]` logging would spam the log; the catalogue load
//! already logs counts once.

use crate::esi::models::CharacterFitting;
use crate::fitting::ship_resistances::bonused_resonances;
use crate::names::fitting_types::FittingTypes;

/// Omni damage profile share for EM damage (equal quarters).
const OMNI_EM_SHARE: f64 = 0.25;
/// Omni damage profile share for thermal damage (equal quarters).
const OMNI_THERMAL_SHARE: f64 = 0.25;
/// Omni damage profile share for kinetic damage (equal quarters).
const OMNI_KINETIC_SHARE: f64 = 0.25;
/// Omni damage profile share for explosive damage (equal quarters).
const OMNI_EXPLOSIVE_SHARE: f64 = 0.25;

/// One hull's base omni effective hit points, per layer and
/// total. Each field is full-precision `f64` hit points against
/// omni damage (equal EM/thermal/kinetic/explosive quarters)
/// from base hit points and base resonances only; `None` means
/// that layer (or the total) cannot honestly be computed from
/// the catalogue data: the caller omits it, never renders a
/// zero. `total` is `Some` only when all three layers are
/// `Some`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ShipBaseEhp {
    pub shield: Option<f64>,
    pub armor: Option<f64>,
    pub hull: Option<f64>,
    pub total: Option<f64>,
}

/// Base omni effective hit points outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ShipBaseEhpOutcome {
    Available(ShipBaseEhp),
    /// The catalogue has no complete base hit point and
    /// resonance data for any layer of this fitting's ship, so
    /// no honest numbers exist.
    Unavailable,
}

/// Bonused omni effective hit points plus the fitted-module
/// counts the caller must disclose beside them. The hit
/// points are the hull's base hit points; only the
/// resistances carry fitted-module bonuses.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BonusedShipEhp {
    pub ehp: ShipBaseEhp,
    /// Same definition, units, and source as
    /// `BonusedShipResistances::excluded_modules`.
    pub excluded_modules: usize,
    /// Same definition, units, and source as
    /// `BonusedShipResistances::unapplied_modules`.
    pub unapplied_modules: usize,
}

/// Bonused omni effective hit points outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BonusedShipEhpOutcome {
    Available(BonusedShipEhp),
    /// No complete base hit point and bonused-resonance data
    /// for any layer of this fitting's ship, so no honest
    /// numbers exist.
    Unavailable,
}

/// A catalogue hit point value is usable only when present,
/// finite, and non-negative. A present `0.0` stays a real zero
/// (the #578 rule).
fn usable_hit_points(value: Option<f64>) -> Option<f64> {
    value.filter(|v| v.is_finite() && *v >= 0.0)
}

/// A catalogue resonance is usable only when present, finite,
/// and non-negative — there is no upper bound, so a resonance
/// above 1 is usable data contributing more than its share to
/// the denominator (the #579 rule). Anything else is no data.
fn usable_resonance(value: Option<f64>) -> Option<f64> {
    value.filter(|v| v.is_finite() && *v >= 0.0)
}

/// Effective hit points for one layer from its hit points and
/// four resonances (EM, thermal, kinetic, explosive order).
/// `None` unless the hit points and all four resonances are
/// usable and the arithmetic stays finite.
fn layer_ehp(
    hit_points: Option<f64>,
    em: Option<f64>,
    thermal: Option<f64>,
    kinetic: Option<f64>,
    explosive: Option<f64>,
) -> Option<f64> {
    let hit_points = usable_hit_points(hit_points)?;
    let em = usable_resonance(em)?;
    let thermal = usable_resonance(thermal)?;
    let kinetic = usable_resonance(kinetic)?;
    let explosive = usable_resonance(explosive)?;
    let denominator = OMNI_EM_SHARE * em
        + OMNI_THERMAL_SHARE * thermal
        + OMNI_KINETIC_SHARE * kinetic
        + OMNI_EXPLOSIVE_SHARE * explosive;
    if !denominator.is_finite() {
        return None;
    }
    if denominator <= 0.0 {
        return Some(hit_points);
    }
    let ehp = hit_points / denominator;
    if ehp.is_finite() {
        Some(ehp)
    } else {
        None
    }
}

/// Base omni effective hit points for one fitting. The fitting's
/// items are never read, and availability is independent of
/// [`crate::fitting::resources::FittingResources`],
/// [`crate::fitting::ship_stats::ShipBaseStats`], and
/// [`crate::fitting::ship_resistances::ShipResistances`]: this
/// function keys off the three hit point fields plus the twelve
/// resonance fields only, with per-layer completeness.
pub fn ship_base_ehp(fitting: &CharacterFitting, catalogue: &FittingTypes) -> ShipBaseEhpOutcome {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        return ShipBaseEhpOutcome::Unavailable;
    };
    if ship.category_id != 6 {
        return ShipBaseEhpOutcome::Unavailable;
    }
    let shield = layer_ehp(
        ship.shield_capacity,
        ship.shield_em_resonance,
        ship.shield_thermal_resonance,
        ship.shield_kinetic_resonance,
        ship.shield_explosive_resonance,
    );
    let armor = layer_ehp(
        ship.armor_hp,
        ship.armor_em_resonance,
        ship.armor_thermal_resonance,
        ship.armor_kinetic_resonance,
        ship.armor_explosive_resonance,
    );
    let hull = layer_ehp(
        ship.hull_hp,
        ship.hull_em_resonance,
        ship.hull_thermal_resonance,
        ship.hull_kinetic_resonance,
        ship.hull_explosive_resonance,
    );
    let total = match (shield, armor, hull) {
        (Some(shield), Some(armor), Some(hull)) => {
            let sum = shield + armor + hull;
            if sum.is_finite() {
                Some(sum)
            } else {
                None
            }
        }
        _ => None,
    };
    if shield.is_none() && armor.is_none() && hull.is_none() {
        return ShipBaseEhpOutcome::Unavailable;
    }
    ShipBaseEhpOutcome::Available(ShipBaseEhp {
        shield,
        armor,
        hull,
        total,
    })
}

/// Bonused omni effective hit points for one fitting
/// (`docs/bonused-ehp-design.md` section 4). The numerator
/// is the hull's base hit points and only the resistances
/// carry the fitted-module bonuses, in the same omni profile
/// as [`ship_base_ehp`]: each layer is its base hit points
/// divided by the share-weighted bonused resonance, summed
/// shield, then armor, then hull for the total, with
/// per-layer completeness identical to the base function.
/// Never panics; there is no error channel.
pub fn ship_ehp_with_module_bonuses(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> BonusedShipEhpOutcome {
    let Some(bonused) = bonused_resonances(fitting, catalogue) else {
        return BonusedShipEhpOutcome::Unavailable;
    };
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        return BonusedShipEhpOutcome::Unavailable;
    };
    if ship.category_id != 6 {
        return BonusedShipEhpOutcome::Unavailable;
    }
    let shield = layer_ehp(
        ship.shield_capacity,
        bonused.resonances[0],
        bonused.resonances[1],
        bonused.resonances[2],
        bonused.resonances[3],
    );
    let armor = layer_ehp(
        ship.armor_hp,
        bonused.resonances[4],
        bonused.resonances[5],
        bonused.resonances[6],
        bonused.resonances[7],
    );
    let hull = layer_ehp(
        ship.hull_hp,
        bonused.resonances[8],
        bonused.resonances[9],
        bonused.resonances[10],
        bonused.resonances[11],
    );
    let total = match (shield, armor, hull) {
        (Some(shield), Some(armor), Some(hull)) => {
            let sum = shield + armor + hull;
            if sum.is_finite() {
                Some(sum)
            } else {
                None
            }
        }
        _ => None,
    };
    if shield.is_none() && armor.is_none() && hull.is_none() {
        return BonusedShipEhpOutcome::Unavailable;
    }
    BonusedShipEhpOutcome::Available(BonusedShipEhp {
        ehp: ShipBaseEhp {
            shield,
            armor,
            hull,
            total,
        },
        excluded_modules: bonused.excluded_modules,
        unapplied_modules: bonused.unapplied_modules,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::resources::fitting_resources;
    use crate::fitting::ship_resistances::{
        ship_resistances, ship_resistances_with_module_bonuses, BonusedShipResistances,
        BonusedShipResistancesOutcome,
    };
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

    fn available(result: ShipBaseEhpOutcome) -> ShipBaseEhp {
        match result {
            ShipBaseEhpOutcome::Available(ehp) => ehp,
            ShipBaseEhpOutcome::Unavailable => panic!("expected Available, got Unavailable"),
        }
    }

    fn bonused_available(result: BonusedShipEhpOutcome) -> BonusedShipEhp {
        match result {
            BonusedShipEhpOutcome::Available(bonused) => bonused,
            BonusedShipEhpOutcome::Unavailable => panic!("expected Available, got Unavailable"),
        }
    }

    fn bonused_resistances_available(
        result: BonusedShipResistancesOutcome,
    ) -> BonusedShipResistances {
        match result {
            BonusedShipResistancesOutcome::Available(bonused) => bonused,
            BonusedShipResistancesOutcome::Unavailable => {
                panic!("expected Available, got Unavailable")
            }
        }
    }

    fn assert_counts_match_resistances(
        bonused: &BonusedShipEhp,
        fit: &CharacterFitting,
        catalogue: &FittingTypes,
        label: &str,
    ) {
        let resistances =
            bonused_resistances_available(ship_resistances_with_module_bonuses(fit, catalogue));
        assert_eq!(
            bonused.excluded_modules, resistances.excluded_modules,
            "{label} excluded"
        );
        assert_eq!(
            bonused.unapplied_modules, resistances.unapplied_modules,
            "{label} unapplied"
        );
    }

    /// Hand-derived catalogue oracle: absolute tolerance 1e-6
    /// with literals carrying at least seven decimal places, so
    /// the literal's own truncation stays well inside the band
    /// (design section 8, tier 2).
    fn assert_ehp_close(actual: Option<f64>, expected: f64, label: &str) {
        match actual {
            Some(value) => assert!(
                (value - expected).abs() < 1e-6,
                "{label}: expected {expected}, got {value}"
            ),
            None => panic!("{label}: expected Some({expected}), got None"),
        }
    }

    /// Flutter bare-hull parity: tolerance 0.01, mirroring the
    /// Flutter assertions' own `closeTo(..., 0.01)` verbatim
    /// (design section 8, tier 3).
    fn assert_ehp_parity(actual: Option<f64>, expected: f64, label: &str) {
        match actual {
            Some(value) => assert!(
                (value - expected).abs() < 0.01,
                "{label}: expected {expected}, got {value}"
            ),
            None => panic!("{label}: expected Some({expected}), got None"),
        }
    }

    // All four omni shares are equal, so no EHP value can detect
    // a share wired to the wrong damage type; only the constants
    // themselves can be pinned (design section 4).
    #[test]
    fn omni_share_constants_are_each_quarter_and_sum_to_one() {
        assert_eq!(OMNI_EM_SHARE, 0.25);
        assert_eq!(OMNI_THERMAL_SHARE, 0.25);
        assert_eq!(OMNI_KINETIC_SHARE, 0.25);
        assert_eq!(OMNI_EXPLOSIVE_SHARE, 0.25);
        assert_eq!(
            OMNI_EM_SHARE + OMNI_THERMAL_SHARE + OMNI_KINETIC_SHARE + OMNI_EXPLOSIVE_SHARE,
            1.0
        );
    }

    // Oracle rows read from the bundled catalogue (assets/sde/
    // fitting_types.json), hit points shield/armor/hull and
    // resonances EM/thermal/kinetic/explosive per layer:
    // Rifter 587: HP 450/450/350; shield 1.0/0.8/0.6/0.5,
    // armor 0.4/0.65/0.75/0.9, hull 0.67 x4. Each denominator
    // is 0.25*em + 0.25*thermal + 0.25*kinetic + 0.25*explosive;
    // each layer is HP / denominator, total is shield + armor +
    // hull summed before any rounding.
    //   Shield: denominator 0.725, 450 / 0.725 = 620.6896552
    //   Armor: denominator 0.675, 450 / 0.675 = 666.6666667
    //   Hull: denominator 0.67, 350 / 0.67 = 522.3880597
    //   Total: 620.6896552 + 666.6666667 + 522.3880597
    //          = 1809.7443815
    // The hull value is also the 974-977 tripwire: an
    // implementation reading the Damage Control bonus set (1.0)
    // instead of the emDamageResonance family would show 350.0
    // here. Flutter parity pins (T8.1/E0b.1 bare hull): hull
    // 522.388, total 1809.744 within 0.01.
    #[test]
    fn rifter_oracle_matches_hand_derived_values_and_flutter_parity() {
        let catalogue = bundled();
        let ehp = available(ship_base_ehp(&fitting(587, vec![]), &catalogue));
        assert_ehp_close(ehp.shield, 620.6896552, "Rifter shield");
        assert_ehp_close(ehp.armor, 666.6666667, "Rifter armor");
        assert_ehp_close(ehp.hull, 522.3880597, "Rifter hull");
        assert_ehp_close(ehp.total, 1809.7443815, "Rifter total");
        assert_ehp_parity(ehp.hull, 522.388, "Rifter hull Flutter parity");
        assert_ehp_parity(ehp.total, 1809.744, "Rifter total Flutter parity");
    }

    // Punisher 597: HP 350/500/450; shield 1.0/0.8/0.6/0.5,
    // armor 0.5/0.65/0.75/0.8, hull 0.67 x4.
    //   Shield: denominator 0.725, 350 / 0.725 = 482.7586207
    //   Armor: denominator 0.675, 500 / 0.675 = 740.7407407
    //   Hull: denominator 0.67, 450 / 0.67 = 671.6417910
    //   Total: 482.7586207 + 740.7407407 + 671.6417910
    //          = 1895.1411525
    #[test]
    fn punisher_oracle_matches_hand_derived_values() {
        let catalogue = bundled();
        let ehp = available(ship_base_ehp(&fitting(597, vec![]), &catalogue));
        assert_ehp_close(ehp.shield, 482.7586207, "Punisher shield");
        assert_ehp_close(ehp.armor, 740.7407407, "Punisher armor");
        assert_ehp_close(ehp.hull, 671.6417910, "Punisher hull");
        assert_ehp_close(ehp.total, 1895.1411525, "Punisher total");
    }

    // Legion 29986: HP 1800/2900/1800; shield 1.0/0.8/0.45/0.25,
    // armor 0.5/0.65/0.5625/0.4, hull 0.67 x4.
    //   Shield: denominator 0.625, 1800 / 0.625 = 2880.0 exact.
    //   Armor: denominator 0.528125, 2900 / 0.528125
    //          = 5491.1242604
    //   Hull: denominator 0.67, 1800 / 0.67 = 2686.5671642
    //   Total: 2880.0 + 5491.1242604 + 2686.5671642
    //          = 11057.6914245
    #[test]
    fn legion_shield_is_exact_and_other_values_match_hand_derived() {
        let catalogue = bundled();
        let ehp = available(ship_base_ehp(&fitting(29986, vec![]), &catalogue));
        assert_eq!(ehp.shield, Some(2880.0));
        assert_ehp_close(ehp.armor, 5491.1242604, "Legion armor");
        assert_ehp_close(ehp.hull, 2686.5671642, "Legion hull");
        assert_ehp_close(ehp.total, 11057.6914245, "Legion total");
    }

    // Raven 638: HP 7700/6380/7040; shield 1.0/0.8/0.6/0.5,
    // armor 0.5/0.55/0.75/0.9, hull 0.67 x4.
    //   Shield: denominator 0.725, 7700 / 0.725 = 10620.6896552
    //   Armor: denominator 0.675, 6380 / 0.675 = 9451.8518519
    //   Hull: denominator 0.67, 7040 / 0.67 = 10507.4626866
    //   Total: 10620.6896552 + 9451.8518519 + 10507.4626866
    //          = 30580.0041936
    #[test]
    fn raven_oracle_matches_hand_derived_values() {
        let catalogue = bundled();
        let ehp = available(ship_base_ehp(&fitting(638, vec![]), &catalogue));
        assert_ehp_close(ehp.shield, 10620.6896552, "Raven shield");
        assert_ehp_close(ehp.armor, 9451.8518519, "Raven armor");
        assert_ehp_close(ehp.hull, 10507.4626866, "Raven hull");
        assert_ehp_close(ehp.total, 30580.0041936, "Raven total");
    }

    // The no-modifiers lock as a test: fitted modules —
    // including the Damage Control II whose own 974-977 bonus
    // attributes are the decoy hull set — plus an unknown type
    // and a stacked quantity change nothing.
    #[test]
    fn fitted_items_are_ignored() {
        let catalogue = bundled();
        let hull_only = ship_base_ehp(&fitting(587, vec![]), &catalogue);
        let fitted = ship_base_ehp(
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
            let result = ship_base_ehp(&fitting(ship_type_id, vec![]), &catalogue);
            assert_eq!(
                result,
                ShipBaseEhpOutcome::Unavailable,
                "ship {ship_type_id}"
            );
        }
    }

    // Missing-data matrix, via fixture catalogues: shipped data
    // has no partial ship (all 404 ships carry all three hit
    // point values and all twelve resonances), so only fixtures
    // can exercise the honesty paths. The full fixture uses
    // 1000/800/600 hit points with 1.0 x4 resonances per layer,
    // so every layer is exactly its hit points (denominator
    // 1.0) and the total is exactly 2400.0.
    #[test]
    fn full_fixture_row_computes_all_layers_and_total() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Full Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":1000.0,"armorHP":800.0,"hp":600.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":1.0,"shieldKineticDamageResonance":1.0,"shieldExplosiveDamageResonance":1.0,
                 "armorEmDamageResonance":1.0,"armorThermalDamageResonance":1.0,"armorKineticDamageResonance":1.0,"armorExplosiveDamageResonance":1.0,
                 "emDamageResonance":1.0,"thermalDamageResonance":1.0,"kineticDamageResonance":1.0,"explosiveDamageResonance":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let ehp = available(ship_base_ehp(&fitting(42, vec![]), &catalogue));
        assert_eq!(ehp.shield, Some(1000.0));
        assert_eq!(ehp.armor, Some(800.0));
        assert_eq!(ehp.hull, Some(600.0));
        assert_eq!(ehp.total, Some(2400.0));
    }

    // Exactly one complete layer (shield HP 450 with shield
    // resonances 1.0 x4, so shield EHP is exactly 450.0; armor
    // and hull inputs entirely absent): Available with that
    // layer Some, the other two and the total None.
    #[test]
    fn exactly_one_complete_layer_omits_the_rest_and_the_total() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Shield Only","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":1.0,"shieldKineticDamageResonance":1.0,"shieldExplosiveDamageResonance":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let ehp = available(ship_base_ehp(&fitting(42, vec![]), &catalogue));
        assert_eq!(ehp.shield, Some(450.0));
        assert_eq!(ehp.armor, None);
        assert_eq!(ehp.hull, None);
        assert_eq!(ehp.total, None);
    }

    // Hit points present with one armor resonance absent (the
    // Rifter row minus armorThermalDamageResonance): armor
    // None, total None, shield and hull unaffected.
    #[test]
    fn one_absent_armor_resonance_omits_armor_and_total_only() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        let ehp = available(ship_base_ehp(&fitting(42, vec![]), &catalogue));
        assert_ehp_close(ehp.shield, 620.6896552, "Fixture shield");
        assert_eq!(ehp.armor, None);
        assert_ehp_close(ehp.hull, 522.3880597, "Fixture hull");
        assert_eq!(ehp.total, None);
    }

    // Resonances complete with armor hit points absent (the
    // Rifter row minus armorHP): armor None, total None, shield
    // and hull unaffected.
    #[test]
    fn absent_armor_hit_points_omits_armor_and_total_only() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"hp":350.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.65,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        let ehp = available(ship_base_ehp(&fitting(42, vec![]), &catalogue));
        assert_ehp_close(ehp.shield, 620.6896552, "Fixture shield");
        assert_eq!(ehp.armor, None);
        assert_ehp_close(ehp.hull, 522.3880597, "Fixture hull");
        assert_eq!(ehp.total, None);
    }

    // One negative resonance (armor EM -1.0, the Rifter row
    // otherwise complete): that layer None only — no data, never
    // clamped, never Flutter's silent default.
    #[test]
    fn one_negative_resonance_omits_that_layer_only() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":-1.0,"armorThermalDamageResonance":0.65,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        let ehp = available(ship_base_ehp(&fitting(42, vec![]), &catalogue));
        assert_ehp_close(ehp.shield, 620.6896552, "Fixture shield");
        assert_eq!(ehp.armor, None);
        assert_ehp_close(ehp.hull, 522.3880597, "Fixture hull");
        assert_eq!(ehp.total, None);
    }

    // One negative hit point value (armorHP -1.0, the Rifter row
    // otherwise complete): that layer None only.
    #[test]
    fn one_negative_hit_points_omits_that_layer_only() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":-1.0,"hp":350.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.65,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        let ehp = available(ship_base_ehp(&fitting(42, vec![]), &catalogue));
        assert_ehp_close(ehp.shield, 620.6896552, "Fixture shield");
        assert_eq!(ehp.armor, None);
        assert_ehp_close(ehp.hull, 522.3880597, "Fixture hull");
        assert_eq!(ehp.total, None);
    }

    // Resonances-only, hit-points-only, and no-key rows have no
    // complete layer, so all three collapse to Unavailable.
    #[test]
    fn resonances_only_hit_points_only_and_empty_rows_are_unavailable() {
        let resonances_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Resonances Only","categoryId":6,"slotEffects":[],
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.65,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        assert_eq!(
            ship_base_ehp(&fitting(42, vec![]), &resonances_only),
            ShipBaseEhpOutcome::Unavailable
        );

        let hit_points_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Hit Points Only","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0}]}"#,
        )
        .expect("fixture catalogue parses");
        assert_eq!(
            ship_base_ehp(&fitting(42, vec![]), &hit_points_only),
            ShipBaseEhpOutcome::Unavailable
        );

        let empty = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Bare Hull","categoryId":6,"slotEffects":[]}]}"#,
        )
        .expect("fixture catalogue parses");
        assert_eq!(
            ship_base_ehp(&fitting(42, vec![]), &empty),
            ShipBaseEhpOutcome::Unavailable
        );
    }

    // Present-zero hit points on one layer with complete
    // resonances (1000/800/600 with 1.0 x4 per layer, shield HP
    // present as 0.0): that layer is Some(0.0), a real zero, and
    // the total is still computed over all three (0 + 800 +
    // 600 = 1400.0).
    #[test]
    fn present_zero_hit_points_is_a_real_zero_and_total_still_computes() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Zero Shield","categoryId":6,"slotEffects":[],
                 "shieldCapacity":0.0,"armorHP":800.0,"hp":600.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":1.0,"shieldKineticDamageResonance":1.0,"shieldExplosiveDamageResonance":1.0,
                 "armorEmDamageResonance":1.0,"armorThermalDamageResonance":1.0,"armorKineticDamageResonance":1.0,"armorExplosiveDamageResonance":1.0,
                 "emDamageResonance":1.0,"thermalDamageResonance":1.0,"kineticDamageResonance":1.0,"explosiveDamageResonance":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let ehp = available(ship_base_ehp(&fitting(42, vec![]), &catalogue));
        assert_eq!(ehp.shield, Some(0.0));
        assert_eq!(ehp.armor, Some(800.0));
        assert_eq!(ehp.hull, Some(600.0));
        assert_eq!(ehp.total, Some(1400.0));
    }

    // Denominator edges through the private helper and the
    // public function. The guard (resonances 0.0 x4 with 1000
    // hit points -> exactly 1000.0) is Flutter C.8; the
    // denominator-1.0 and 1.0/0.5/0.5/0.5 -> 1600.0 pins are
    // Flutter T3.5/T3.3 in resonance space; the 0.0/1.0/1.0/1.0
    // case is denominator 0.75 with 900 hit points, exactly
    // 1200.0. All exact in binary.
    #[test]
    fn denominator_edges_are_exact_through_the_helper() {
        // Guard: 0.0 x4 -> denominator 0.0 -> raw hit points.
        assert_eq!(
            layer_ehp(Some(1000.0), Some(0.0), Some(0.0), Some(0.0), Some(0.0)),
            Some(1000.0)
        );
        // Denominator 1.0: 1.0 x4 -> exactly the hit points.
        assert_eq!(
            layer_ehp(Some(1000.0), Some(1.0), Some(1.0), Some(1.0), Some(1.0)),
            Some(1000.0)
        );
        // 1.0/0.5/0.5/0.5 -> denominator 0.625, 1000 / 0.625.
        assert_eq!(
            layer_ehp(Some(1000.0), Some(1.0), Some(0.5), Some(0.5), Some(0.5)),
            Some(1600.0)
        );
        // 0.0/1.0/1.0/1.0 -> denominator 0.75, 900 / 0.75.
        assert_eq!(
            layer_ehp(Some(900.0), Some(0.0), Some(1.0), Some(1.0), Some(1.0)),
            Some(1200.0)
        );
        // Absent inputs are no data even with the guard.
        assert_eq!(
            layer_ehp(None, Some(0.0), Some(0.0), Some(0.0), Some(0.0)),
            None
        );
        assert_eq!(
            layer_ehp(Some(1000.0), None, Some(0.0), Some(0.0), Some(0.0)),
            None
        );
    }

    // Denominator edges through the public function over
    // fixtures: resonances 0.0 x4 per layer with 1000 hit
    // points per layer show the guard on every layer (each
    // exactly 1000.0, total 3000.0, all finite — never
    // infinity). Resonances above 1 stay unclamped (mirroring
    // #579's signed fixture values 1.1/7.0/0.6/0.5 on 450 hit
    // points: denominator 0.25(1.1) + 0.25(7.0) + 0.25(0.6) +
    // 0.25(0.5) = 2.3, EHP 450 / 2.3 = 195.6521739, below the
    // raw hit points, never clamped up).
    #[test]
    fn guard_and_above_one_edges_through_the_public_function() {
        let guard = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Guard Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":1000.0,"armorHP":1000.0,"hp":1000.0,
                 "shieldEmDamageResonance":0.0,"shieldThermalDamageResonance":0.0,"shieldKineticDamageResonance":0.0,"shieldExplosiveDamageResonance":0.0,
                 "armorEmDamageResonance":0.0,"armorThermalDamageResonance":0.0,"armorKineticDamageResonance":0.0,"armorExplosiveDamageResonance":0.0,
                 "emDamageResonance":0.0,"thermalDamageResonance":0.0,"kineticDamageResonance":0.0,"explosiveDamageResonance":0.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let ehp = available(ship_base_ehp(&fitting(42, vec![]), &guard));
        assert_eq!(ehp.shield, Some(1000.0));
        assert_eq!(ehp.armor, Some(1000.0));
        assert_eq!(ehp.hull, Some(1000.0));
        assert_eq!(ehp.total, Some(3000.0));

        let above_one = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Above One","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,
                 "shieldEmDamageResonance":1.1,"shieldThermalDamageResonance":7.0,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5}]}"#,
        )
        .expect("fixture catalogue parses");
        let ehp = available(ship_base_ehp(&fitting(42, vec![]), &above_one));
        assert_ehp_close(ehp.shield, 195.6521739, "Above-one shield");
        assert_eq!(ehp.armor, None);
        assert_eq!(ehp.hull, None);
        assert_eq!(ehp.total, None);
    }

    // Non-finite inputs are rejected through the private
    // helper (JSON cannot spell NaN). A quotient that
    // overflows (hit points 1e308 over tiny positive
    // resonances 1e-300) is no data for that layer.
    #[test]
    fn non_finite_inputs_and_overflowing_quotient_are_no_data() {
        assert_eq!(
            layer_ehp(Some(f64::NAN), Some(1.0), Some(1.0), Some(1.0), Some(1.0)),
            None
        );
        assert_eq!(
            layer_ehp(
                Some(f64::INFINITY),
                Some(1.0),
                Some(1.0),
                Some(1.0),
                Some(1.0)
            ),
            None
        );
        assert_eq!(
            layer_ehp(
                Some(1000.0),
                Some(f64::NAN),
                Some(1.0),
                Some(1.0),
                Some(1.0)
            ),
            None
        );
        assert_eq!(
            layer_ehp(
                Some(1000.0),
                Some(f64::INFINITY),
                Some(1.0),
                Some(1.0),
                Some(1.0)
            ),
            None
        );
        assert_eq!(
            layer_ehp(
                Some(1.0e308),
                Some(1.0e-300),
                Some(1.0e-300),
                Some(1.0e-300),
                Some(1.0e-300)
            ),
            None
        );
    }

    // Three finite huge layers whose sum overflows (hit
    // points 1e308, resonances 1.0 x4 per layer, so each layer
    // is 1e308/1.0 = 1e308): the layers stay Some and only the
    // total is None (3e308 is not finite).
    #[test]
    fn overflowing_total_is_none_while_layers_stay() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Huge Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":1e308,"armorHP":1e308,"hp":1e308,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":1.0,"shieldKineticDamageResonance":1.0,"shieldExplosiveDamageResonance":1.0,
                 "armorEmDamageResonance":1.0,"armorThermalDamageResonance":1.0,"armorKineticDamageResonance":1.0,"armorExplosiveDamageResonance":1.0,
                 "emDamageResonance":1.0,"thermalDamageResonance":1.0,"kineticDamageResonance":1.0,"explosiveDamageResonance":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let ehp = available(ship_base_ehp(&fitting(42, vec![]), &catalogue));
        assert_eq!(ehp.shield, Some(1.0e308));
        assert_eq!(ehp.armor, Some(1.0e308));
        assert_eq!(ehp.hull, Some(1.0e308));
        assert_eq!(ehp.total, None);
    }

    // Independence from resources, base stats, and resistances
    // in all directions (fixtures, reusing the sibling fixture
    // shapes and calling all four pure functions as the #579
    // independence test does): resistances without hit points
    // give resistances Available and EHP Unavailable; hit
    // points without resonances give base stats Available and
    // EHP Unavailable; capacitor alone gives base stats
    // Available and EHP Unavailable (capacitor and velocity
    // are never read); outputs alone give resources Available
    // and EHP Unavailable; one complete layer gives EHP
    // Available (partial, no total) with both siblings
    // Available and resources ShipNoOutput; and a layer
    // missing exactly one resonance leaves resistances
    // Available while that layer's EHP and the total are
    // withheld here.
    #[test]
    fn availability_is_independent_of_resources_stats_and_resistances() {
        let resistances_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Resistances Only","categoryId":6,"slotEffects":[],
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.65,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        assert_eq!(
            ship_base_ehp(&fit, &resistances_only),
            ShipBaseEhpOutcome::Unavailable
        );
        assert!(matches!(
            ship_resistances(&fit, &resistances_only),
            crate::fitting::ship_resistances::ShipResistancesOutcome::Available(_)
        ));
        assert_eq!(
            ship_base_stats(&fit, &resistances_only),
            crate::fitting::ship_stats::ShipBaseStatsOutcome::Unavailable
        );
        assert_eq!(
            fitting_resources(&fit, &resistances_only),
            crate::fitting::resources::FittingResources::ShipNoOutput
        );

        let hit_points_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Hit Points Only","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        assert_eq!(
            ship_base_ehp(&fit, &hit_points_only),
            ShipBaseEhpOutcome::Unavailable
        );
        assert!(matches!(
            ship_base_stats(&fit, &hit_points_only),
            crate::fitting::ship_stats::ShipBaseStatsOutcome::Available(_)
        ));
        assert_eq!(
            ship_resistances(&fit, &hit_points_only),
            crate::fitting::ship_resistances::ShipResistancesOutcome::Unavailable
        );
        assert_eq!(
            fitting_resources(&fit, &hit_points_only),
            crate::fitting::resources::FittingResources::ShipNoOutput
        );

        let capacitor_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Capacitor Only","categoryId":6,"slotEffects":[],
                 "capacitorCapacity":250.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        assert_eq!(
            ship_base_ehp(&fit, &capacitor_only),
            ShipBaseEhpOutcome::Unavailable
        );
        assert!(matches!(
            ship_base_stats(&fit, &capacitor_only),
            crate::fitting::ship_stats::ShipBaseStatsOutcome::Available(_)
        ));
        assert_eq!(
            fitting_resources(&fit, &capacitor_only),
            crate::fitting::resources::FittingResources::ShipNoOutput
        );

        let outputs_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Outputs Only","categoryId":6,"slotEffects":[],
                 "cpuOutput":130.0,"powerOutput":41.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        assert_eq!(
            ship_base_ehp(&fit, &outputs_only),
            ShipBaseEhpOutcome::Unavailable
        );
        assert!(matches!(
            fitting_resources(&fit, &outputs_only),
            crate::fitting::resources::FittingResources::Available { .. }
        ));
        assert_eq!(
            ship_base_stats(&fit, &outputs_only),
            crate::fitting::ship_stats::ShipBaseStatsOutcome::Unavailable
        );
        assert_eq!(
            ship_resistances(&fit, &outputs_only),
            crate::fitting::ship_resistances::ShipResistancesOutcome::Unavailable
        );

        let one_layer = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"One Layer","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":1.0,"shieldKineticDamageResonance":1.0,"shieldExplosiveDamageResonance":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        let ehp = available(ship_base_ehp(&fit, &one_layer));
        assert_eq!(ehp.shield, Some(450.0));
        assert_eq!(ehp.armor, None);
        assert_eq!(ehp.hull, None);
        assert_eq!(ehp.total, None);
        assert_eq!(
            fitting_resources(&fit, &one_layer),
            crate::fitting::resources::FittingResources::ShipNoOutput
        );
        assert!(matches!(
            ship_base_stats(&fit, &one_layer),
            crate::fitting::ship_stats::ShipBaseStatsOutcome::Available(_)
        ));
        assert!(matches!(
            ship_resistances(&fit, &one_layer),
            crate::fitting::ship_resistances::ShipResistancesOutcome::Available(_)
        ));

        let armor_missing_one = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Armor Missing One","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        let ehp = available(ship_base_ehp(&fit, &armor_missing_one));
        assert_eq!(ehp.armor, None);
        assert_eq!(ehp.total, None);
        assert!(matches!(
            ship_resistances(&fit, &armor_missing_one),
            crate::fitting::ship_resistances::ShipResistancesOutcome::Available(_)
        ));
    }

    // Oracle 1a (design section 8): Rifter with Damage Control
    // II. Base HP 450/450/350; bonused resonances shield
    // 0.875/0.70/0.525/0.4375 (denominator 0.634375),
    // armor 0.34/0.5525/0.6375/0.765 (0.57375), hull 0.402 x4.
    // Each denominator is 0.25 x the resonance sum.
    //   Shield: 450 / 0.634375 = 709.3596059
    //   Armor: 450 / 0.57375 = 784.3137255
    //   Hull: 350 / 0.402 = 870.6467662
    //   Total: 709.3596059 + 784.3137255 + 870.6467662
    //          = 2364.3200976
    #[test]
    fn rifter_damage_control_oracle() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 2048)]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_ehp_close(bonused.ehp.shield, 709.3596059, "DC shield");
        assert_ehp_close(bonused.ehp.armor, 784.3137255, "DC armor");
        assert_ehp_close(bonused.ehp.hull, 870.6467662, "DC hull");
        assert_ehp_close(bonused.ehp.total, 2364.3200976, "DC total");
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "DC");
    }

    // Oracle 1b: Rifter with Multispectrum Shield Hardener II.
    // Every shield resonance scales by 0.675, so the shield
    // denominator is 0.725 x 0.675 = 0.489375.
    //   Shield: 450 / 0.489375 = 919.5402299
    //   Armor and hull stay at base (666.6666667 +
    //   522.3880597); total 919.5402299 + 666.6666667 +
    //   522.3880597 = 2108.5949563.
    #[test]
    fn rifter_hardener_oracle() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("MedSlot0", 1, 2281)]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_ehp_close(bonused.ehp.shield, 919.5402299, "Hardener shield");
        assert_ehp_close(bonused.ehp.armor, 666.6666667, "Hardener armor");
        assert_ehp_close(bonused.ehp.hull, 522.3880597, "Hardener hull");
        assert_ehp_close(bonused.ehp.total, 2108.5949563, "Hardener total");
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "Hardener");
    }

    // Oracle 1c: Rifter with 2x EM Armor Hardener II. Armor EM
    // resonance 0.0939571219, armor denominator
    // 0.25 x (0.0939571219 + 0.65 + 0.75 + 0.9) = 0.5984892805.
    //   Armor: 450 / 0.5984892805 = 751.8931661
    // Shield and hull stay at base; total 620.6896552 +
    // 751.8931661 + 522.3880597 = 1894.9708810.
    #[test]
    fn rifter_stacked_hardener_oracle() {
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![item("MedSlot0", 1, 11642), item("MedSlot1", 1, 11642)],
        );
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_ehp_close(bonused.ehp.armor, 751.8931661, "Stacked armor");
        assert_ehp_close(bonused.ehp.shield, 620.6896552, "Stacked shield base");
        assert_ehp_close(bonused.ehp.hull, 522.3880597, "Stacked hull base");
        assert_ehp_close(bonused.ehp.total, 1894.9708810, "Stacked total");
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "Stacked");
    }

    // Pin 2: empty fitting equals base EHP exactly (assert_eq
    // on the whole ShipBaseEhp), for the Rifter and one other
    // bundled hull, with only non-counted items fitted, and
    // with a counted non-carrier module fitted. Counts are
    // zero throughout.
    #[test]
    fn empty_fitting_equals_base_ehp_exactly() {
        let catalogue = bundled();
        for ship_type_id in [587, 597] {
            let fit = fitting(ship_type_id, vec![]);
            let base = available(ship_base_ehp(&fit, &catalogue));
            let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
            assert_eq!(bonused.ehp, base, "hull-only ship {ship_type_id}");
            assert_eq!(bonused.excluded_modules, 0);
            assert_eq!(bonused.unapplied_modules, 0);
            assert_counts_match_resistances(&bonused, &fit, &catalogue, "hull-only");
        }

        let fit = fitting(
            587,
            vec![
                item("Cargo", 1, 2048),
                item("DroneBay", 1, 2281),
                item("LoSlot0", 0, 2048),
                item("LoSlot1", 1, 0),
                item("LoSlot2", 1, -1),
                item("LoSlot3", -5, 2048),
            ],
        );
        let base = available(ship_base_ehp(&fit, &catalogue));
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.ehp, base);
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "non-counted");

        let fit = fitting(587, vec![item("MedSlot0", 1, 2049)]);
        let base = available(ship_base_ehp(&fit, &catalogue));
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.ehp, base);
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "non-carrier");
    }

    // Pin 3: partial layers. Armor thermal absent: armor None,
    // total None, shield bonused and hull at base. Shield EM
    // 1.0 with -55% becomes 0.45, so the shield denominator is
    // 0.25 x (0.45 + 0.8 + 0.6 + 0.5) = 0.5875.
    //   Shield: 450 / 0.5875 = 765.9574468
    // The second entry targets the absent armor thermal and
    // does not resurrect the armor layer.
    #[test]
    fn partial_layer_absent_resonance_omits_one_layer_and_total() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67},
                {"typeId":101,"typeName":"Carriers","categoryId":7,"slotEffects":[13],
                 "resistanceModifiers":[[271,6,-55.0],[270,6,-50.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 101)]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_ehp_close(bonused.ehp.shield, 765.9574468, "Partial shield bonused");
        assert_eq!(bonused.ehp.armor, None);
        assert_ehp_close(bonused.ehp.hull, 522.3880597, "Partial hull");
        assert_eq!(bonused.ehp.total, None);
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "absent resonance");
    }

    // Pin 3 continued: one hit point field absent gives the
    // same shape. The shield carrier still bonuses the shield.
    #[test]
    fn partial_layer_absent_hit_points_omits_one_layer_and_total() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"hp":350.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.65,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67},
                {"typeId":101,"typeName":"Hardener","categoryId":7,"slotEffects":[13],
                 "resistanceModifiers":[[271,6,-55.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 101)]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_ehp_close(bonused.ehp.shield, 765.9574468, "No armor HP shield");
        assert_eq!(bonused.ehp.armor, None);
        assert_ehp_close(bonused.ehp.hull, 522.3880597, "No armor HP hull");
        assert_eq!(bonused.ehp.total, None);
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "absent hit points");
    }

    // Pin 4: unavailable ship gates and independence. Unknown,
    // non-ship, 0, and negative ship ids are Unavailable.
    // Resonances without hit points are bonused EHP
    // Unavailable while bonused resistances render; hit
    // points without resonances are bonused EHP Unavailable.
    #[test]
    fn unavailable_cases_and_independence_from_resistances() {
        let catalogue = bundled();
        for ship_type_id in [999999, 2048, 0, -1] {
            let result = ship_ehp_with_module_bonuses(&fitting(ship_type_id, vec![]), &catalogue);
            assert_eq!(
                result,
                BonusedShipEhpOutcome::Unavailable,
                "ship {ship_type_id}"
            );
        }

        let resonances_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Resonances Only","categoryId":6,"slotEffects":[],
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.8,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.65,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        assert_eq!(
            ship_ehp_with_module_bonuses(&fit, &resonances_only),
            BonusedShipEhpOutcome::Unavailable
        );
        assert!(matches!(
            ship_resistances_with_module_bonuses(&fit, &resonances_only),
            BonusedShipResistancesOutcome::Available(_)
        ));

        let hit_points_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Hit Points Only","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        assert_eq!(
            ship_ehp_with_module_bonuses(&fit, &hit_points_only),
            BonusedShipEhpOutcome::Unavailable
        );
        assert_eq!(
            ship_resistances_with_module_bonuses(&fit, &hit_points_only),
            BonusedShipResistancesOutcome::Unavailable
        );
    }

    // Pin 5: forced-negative bonused product. Shield EM 1.0
    // with -150% becomes -0.5, so that resonance and its layer
    // are None; armor and hull stay at base.
    #[test]
    fn negative_bonused_product_omits_that_layer_and_total() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.5,
                 "shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.65,"armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67},
                {"typeId":107,"typeName":"Over","categoryId":7,"slotEffects":[13],
                 "resistanceModifiers":[[271,6,-150.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 107)]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.ehp.shield, None);
        assert_ehp_close(bonused.ehp.armor, 666.6666667, "Negative armor");
        assert_ehp_close(bonused.ehp.hull, 522.3880597, "Negative hull");
        assert_eq!(bonused.ehp.total, None);
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "negative");
    }

    // Pin 5: overflowing quotient and overflowing total mirror
    // base EHP. Shield HP 1e308 over tiny resonances 1e-300
    // overflows to no data for that layer; three 1e308 layers
    // stay Some with the total None.
    #[test]
    fn overflowing_quotient_and_total_are_no_data() {
        let quotient = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Overflow Quotient","categoryId":6,"slotEffects":[],
                 "shieldCapacity":1e308,"armorHP":800.0,"hp":600.0,
                 "shieldEmDamageResonance":1e-300,"shieldThermalDamageResonance":1e-300,"shieldKineticDamageResonance":1e-300,"shieldExplosiveDamageResonance":1e-300,
                 "armorEmDamageResonance":1.0,"armorThermalDamageResonance":1.0,"armorKineticDamageResonance":1.0,"armorExplosiveDamageResonance":1.0,
                 "emDamageResonance":1.0,"thermalDamageResonance":1.0,"kineticDamageResonance":1.0,"explosiveDamageResonance":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &quotient));
        assert_eq!(bonused.ehp.shield, None);
        assert_eq!(bonused.ehp.armor, Some(800.0));
        assert_eq!(bonused.ehp.hull, Some(600.0));
        assert_eq!(bonused.ehp.total, None);
        assert_counts_match_resistances(&bonused, &fit, &quotient, "overflow quotient");

        let total = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Huge Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":1e308,"armorHP":1e308,"hp":1e308,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":1.0,"shieldKineticDamageResonance":1.0,"shieldExplosiveDamageResonance":1.0,
                 "armorEmDamageResonance":1.0,"armorThermalDamageResonance":1.0,"armorKineticDamageResonance":1.0,"armorExplosiveDamageResonance":1.0,
                 "emDamageResonance":1.0,"thermalDamageResonance":1.0,"kineticDamageResonance":1.0,"explosiveDamageResonance":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &total));
        assert_eq!(bonused.ehp.shield, Some(1.0e308));
        assert_eq!(bonused.ehp.armor, Some(1.0e308));
        assert_eq!(bonused.ehp.hull, Some(1.0e308));
        assert_eq!(bonused.ehp.total, None);
        assert_counts_match_resistances(&bonused, &fit, &total, "overflow total");
    }

    // Pin 5: denominator guard with four bonused 0.0
    // resonances gives the raw base hit points, never
    // infinity.
    #[test]
    fn denominator_guard_with_bonused_zero_resonances() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Guard Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":1000.0,"armorHP":1000.0,"hp":1000.0,
                 "shieldEmDamageResonance":0.0,"shieldThermalDamageResonance":0.0,"shieldKineticDamageResonance":0.0,"shieldExplosiveDamageResonance":0.0,
                 "armorEmDamageResonance":0.0,"armorThermalDamageResonance":0.0,"armorKineticDamageResonance":0.0,"armorExplosiveDamageResonance":0.0,
                 "emDamageResonance":0.0,"thermalDamageResonance":0.0,"kineticDamageResonance":0.0,"explosiveDamageResonance":0.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.ehp.shield, Some(1000.0));
        assert_eq!(bonused.ehp.armor, Some(1000.0));
        assert_eq!(bonused.ehp.hull, Some(1000.0));
        assert_eq!(bonused.ehp.total, Some(3000.0));
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "guard");
    }

    // Pin 5: hostile quantity. i64::MAX hardeners equal the
    // quantity-100 result (bounded arithmetic inherited from
    // the helper).
    #[test]
    fn hostile_quantity_is_bounded() {
        let catalogue = bundled();
        let huge = bonused_available(ship_ehp_with_module_bonuses(
            &fitting(587, vec![item("MedSlot0", i64::MAX, 2281)]),
            &catalogue,
        ));
        let hundred = bonused_available(ship_ehp_with_module_bonuses(
            &fitting(587, vec![item("MedSlot0", 100, 2281)]),
            &catalogue,
        ));
        assert_eq!(huge, hundred);
        let fit = fitting(587, vec![item("MedSlot0", i64::MAX, 2281)]);
        assert_counts_match_resistances(&huge, &fit, &catalogue, "hostile quantity");
    }

    // Pin 5: a resonance above 1.0 bonused further stays
    // unclamped. Base 2.0 x4 with a 1.5 mul on shield EM
    // gives 3.0/2.0/2.0/2.0, denominator 2.25.
    //   Shield: 450 / 2.25 = 200.0 exact, below the raw hit
    //   points.
    #[test]
    fn above_one_bonused_further_stays_unclamped() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Above One","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,
                 "shieldEmDamageResonance":2.0,"shieldThermalDamageResonance":2.0,"shieldKineticDamageResonance":2.0,"shieldExplosiveDamageResonance":2.0},
                {"typeId":108,"typeName":"Amplifier","categoryId":7,"slotEffects":[13],
                 "resistanceModifiers":[[271,0,1.5]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 108)]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.ehp.shield, Some(200.0));
        assert_eq!(bonused.ehp.armor, None);
        assert_eq!(bonused.ehp.hull, None);
        assert_eq!(bonused.ehp.total, None);
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 0);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "above one");
    }

    // Pin 6: counts pinned at the EHP level and equal to the
    // bonused resistances counts on every fixture. Unknown
    // counted rows count in quantity units; the unapplied
    // carrier and the mixed carrier count once per unit while
    // applicable entries still apply.
    #[test]
    fn counts_match_resistances_and_applicable_entries_still_apply() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 2, 999999)]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        let base = available(ship_base_ehp(&fit, &catalogue));
        assert_eq!(bonused.excluded_modules, 2);
        assert_eq!(bonused.unapplied_modules, 0);
        assert_eq!(bonused.ehp, base);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "excluded quantity 2");

        let fit = fitting(587, vec![item("LoSlot0", 1, 52227)]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 1);
        let base = available(ship_base_ehp(&fit, &catalogue));
        assert_eq!(bonused.ehp, base);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "unapplied carrier");

        // Mixed carrier: bad operator, zero operand, and
        // unknown attribute mark the row unapplied once
        // while the good thermal entry still applies. Base
        // shield thermal 0.5 with -50% becomes 0.25, so the
        // shield denominator is 0.25 x (1.0 + 0.25 + 0.6 +
        // 0.5) = 0.5875.
        //   Shield: 450 / 0.5875 = 765.9574468
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":0.5,
                 "shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.65,
                 "armorKineticDamageResonance":0.75,"armorExplosiveDamageResonance":0.9,
                 "emDamageResonance":0.67,"thermalDamageResonance":0.67,
                 "kineticDamageResonance":0.67,"explosiveDamageResonance":0.67},
                {"typeId":106,"typeName":"Mixed","categoryId":7,"slotEffects":[13],
                 "resistanceModifiers":[[271,7,-55.0],[274,6,-50.0],[272,6,0.0],[999,6,-10.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![item("MedSlot0", 1, 106)]);
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_ehp_close(bonused.ehp.shield, 765.9574468, "Mixed shield");
        assert_ehp_close(bonused.ehp.armor, 666.6666667, "Mixed armor");
        assert_ehp_close(bonused.ehp.hull, 522.3880597, "Mixed hull");
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.unapplied_modules, 1);
        assert_counts_match_resistances(&bonused, &fit, &catalogue, "mixed");
    }

    // Pin 7: base independence regression. The Damage
    // Control II changes the bonused result while the base
    // result on the same fitting stays at the base oracles.
    #[test]
    fn base_ehp_ignores_fitted_bonuses() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 2048)]);
        let base = available(ship_base_ehp(&fit, &catalogue));
        assert_ehp_close(base.shield, 620.6896552, "Base shield");
        assert_ehp_close(base.armor, 666.6666667, "Base armor");
        assert_ehp_close(base.hull, 522.3880597, "Base hull");
        assert_ehp_close(base.total, 1809.7443815, "Base total");
        let bonused = bonused_available(ship_ehp_with_module_bonuses(&fit, &catalogue));
        assert_ehp_close(bonused.ehp.shield, 709.3596059, "Bonused shield");
        assert_ehp_close(bonused.ehp.armor, 784.3137255, "Bonused armor");
        assert_ehp_close(bonused.ehp.hull, 870.6467662, "Bonused hull");
        assert_ehp_close(bonused.ehp.total, 2364.3200976, "Bonused total");
        assert_ne!(bonused.ehp, base);
    }
}
