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
//! The module is pure computation over the bundled catalogue — no
//! egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] and [`FittingTypes`], the same
//! dependencies `ship_stats.rs` and `ship_resistances.rs` take.
//! It logs nothing: it runs at render cadence, so per-frame
//! `[FITTING]` logging would spam the log; the catalogue load
//! already logs counts once.

use crate::esi::models::CharacterFitting;
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::resources::fitting_resources;
    use crate::fitting::ship_resistances::ship_resistances;
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
}
