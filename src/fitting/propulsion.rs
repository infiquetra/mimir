//! Pure propulsion math: afterburner / microwarpdrive
//! maximum velocity and align time under mass additions.
//!
//! Maximum velocity under an active propulsion module is
//! the EVE thrust-over-mass rule
//! `v_max = v_base * (1.0 + boost_factor * (thrust / mass_total))`,
//! where `boost_factor` is the module's speed-factor percent
//! divided by 100 (SDE attribute 20 `speedFactor`: 135 on a
//! 1MN Afterburner II, 510 on a 5MN Microwarpdrive II),
//! `thrust` is SDE attribute 567 in newtons, and
//! `mass_total` includes every mass addition — the
//! propulsion module's own (SDE attribute 796), armor
//! plates, and percent mass effects such as Higgs Anchor
//! rigs. Align time is the repo-locked
//! `-ln(0.25) * agility * mass / 1_000_000` (the
//! `ship_nav_targeting.rs` formula), recomputed here over
//! the same total mass so velocity and align always agree
//! on what the ship weighs.
//!
//! The bundled `fitting_types.json` extract carries hull
//! mass, agility, base velocity, and baked mass modifiers,
//! but not attributes 20/567/796 — so a propulsion module's
//! boost, thrust, and own mass addition arrive as explicit
//! [`PropulsionModule`] inputs the caller resolves from the
//! SDE, exactly like [`crate::fitting::dogma_pipeline`]
//! operands. Nothing is read from `dogma.json` at runtime.
//!
//! The module is pure computation over the bundled
//! catalogue — no egui, no state, no network, no database.
//! It logs nothing (render cadence; the
//! `ship_resistances.rs` precedent).

use crate::esi::models::CharacterFitting;
use crate::fitting::ship_nav_targeting::{
    ship_nav_targeting_with_module_bonuses, BonusedShipNavTargetingOutcome,
};
use crate::fitting::ship_stats::{ship_base_stats, ShipBaseStatsOutcome};
use crate::names::fitting_types::FittingTypes;

/// One active propulsion module's SDE inputs.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PropulsionModule {
    /// Speed-factor as a plain multiplier (SDE attribute 20
    /// divided by 100): 1.35 for a 1MN Afterburner II, 5.10
    /// for a 5MN Microwarpdrive II.
    pub boost_factor: f64,
    /// Thrust in newtons (SDE attribute 567).
    pub thrust: f64,
    /// The module's own mass addition in kilograms while
    /// fitted (SDE attribute 796; propulsion modules add it
    /// whenever online).
    pub mass_addition: f64,
}

impl PropulsionModule {
    /// Build from raw SDE attribute values (20, 567, 796).
    pub fn from_sde(speed_factor_percent: f64, thrust: f64, mass_addition: f64) -> Self {
        Self {
            boost_factor: speed_factor_percent / 100.0,
            thrust,
            mass_addition,
        }
    }
}

/// A value is usable only when finite and non-negative; a
/// present `0.0` stays a real zero (the shared fitting
/// rule).
fn usable(value: f64) -> Option<f64> {
    (value.is_finite() && value >= 0.0).then_some(value)
}

/// Maximum velocity under thrust:
/// `v_base * (1.0 + boost_factor * (thrust / total_mass))`.
/// `total_mass` must already include every mass addition.
/// `None` when any input is unusable, mass is zero, or the
/// result goes non-finite — never a silent zero.
pub fn propelled_max_velocity(
    base_velocity: f64,
    boost_factor: f64,
    thrust: f64,
    total_mass: f64,
) -> Option<f64> {
    let base = usable(base_velocity)?;
    let boost = usable(boost_factor)?;
    let thrust = usable(thrust)?;
    let mass = usable(total_mass).filter(|m| *m > 0.0)?;
    let velocity = base * (1.0 + boost * (thrust / mass));
    velocity.is_finite().then_some(velocity)
}

/// Align time in seconds:
/// `-ln(0.25) * agility * total_mass / 1_000_000`, the
/// `ship_nav_targeting.rs` locked formula over a caller-
/// supplied total mass. `None` on unusable input.
pub fn align_time_secs(agility: f64, total_mass: f64) -> Option<f64> {
    let agility = usable(agility)?;
    let mass = usable(total_mass)?;
    let align = -0.25_f64.ln() * agility * mass / 1_000_000.0;
    align.is_finite().then_some(align)
}

/// Apply a percent mass operand (the Higgs Anchor shape:
/// `+100.0` doubles mass) to a base mass. Negative percents
/// shrink mass; a result at or below zero is `None`.
pub fn mass_with_percent(mass: f64, percent: f64) -> Option<f64> {
    let mass = usable(mass).filter(|m| *m > 0.0)?;
    if !percent.is_finite() {
        return None;
    }
    let result = mass * (1.0 + percent / 100.0);
    (result.is_finite() && result > 0.0).then_some(result)
}

/// Propulsion figures for one fitting under one active
/// propulsion module.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FittingPropulsion {
    /// Bare-hull base maximum velocity, m/s.
    pub base_velocity: f64,
    /// Maximum velocity with the module active, m/s.
    pub propelled_velocity: f64,
    /// Total mass in kg: bonused hull mass (fitted plates
    /// and other baked mass modifiers included) plus the
    /// propulsion module's own mass addition.
    pub total_mass: f64,
    /// Align time in seconds at `total_mass` under the
    /// bonused agility.
    pub align_time_secs: f64,
    /// Counted fitted rows whose baked mass bonus could not
    /// be applied (from the navigation block), in quantity
    /// units — disclosed, never silently zero-weight.
    pub mass_unapplied_modules: usize,
    /// Counted fitted rows with no catalogue row at all.
    pub excluded_modules: usize,
}

/// Fitting propulsion outcome.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FittingPropulsionOutcome {
    Available(FittingPropulsion),
    /// The catalogue has no usable hull velocity/mass/
    /// agility for this fitting's ship.
    Unavailable,
}

/// Propulsion figures for one fitting. Hull velocity comes
/// from [`ship_base_stats`]; bonused mass and agility from
/// [`ship_nav_targeting_with_module_bonuses`], so fitted
/// armor plates and other baked mass modifiers already
/// weigh in before the module's own addition.
pub fn fitting_propulsion(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
    module: &PropulsionModule,
) -> FittingPropulsionOutcome {
    let ShipBaseStatsOutcome::Available(stats) = ship_base_stats(fitting, catalogue) else {
        return FittingPropulsionOutcome::Unavailable;
    };
    let BonusedShipNavTargetingOutcome::Available(nav) =
        ship_nav_targeting_with_module_bonuses(fitting, catalogue)
    else {
        return FittingPropulsionOutcome::Unavailable;
    };
    let (Some(base_velocity), Some(bonused_mass), Some(agility)) = (
        stats.max_velocity,
        nav.targeting.mass,
        nav.targeting.agility,
    ) else {
        return FittingPropulsionOutcome::Unavailable;
    };
    let Some(mass_addition) = usable(module.mass_addition) else {
        return FittingPropulsionOutcome::Unavailable;
    };
    let total_mass = bonused_mass + mass_addition;
    let (Some(propelled_velocity), Some(align_time)) = (
        propelled_max_velocity(
            base_velocity,
            module.boost_factor,
            module.thrust,
            total_mass,
        ),
        align_time_secs(agility, total_mass),
    ) else {
        return FittingPropulsionOutcome::Unavailable;
    };
    FittingPropulsionOutcome::Available(FittingPropulsion {
        base_velocity,
        propelled_velocity,
        total_mass,
        align_time_secs: align_time,
        mass_unapplied_modules: nav.mass_unapplied_modules,
        excluded_modules: nav.excluded_modules,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;

    fn assert_close(actual: f64, expected: f64, label: &str) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "{label}: expected {expected}, got {actual}"
        );
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

    // SDE operands below are read from
    // scripts/sde/dgmTypeAttributes.csv.bz2 (valueFloat):
    // 1MN Afterburner II (438): 20=135, 567=1500000,
    // 796=500000. 5MN Microwarpdrive II (440): 20=510,
    // 567=1500000, 796=500000. 50MN Cold-Gas (5975):
    // 20=505, 567=15000000, 796=5000000. 500MN Cold-Gas
    // (5945): 20=505, 567=150000000, 796=50000000. Hull
    // rows: Rifter 365 m/s, 1067000 kg, agility 3.2;
    // Muninn 235, 11000000, 0.571; Raven 113, 99300000,
    // 0.12 (bundled fitting_types.json, cross-checked
    // against the same CSV).

    #[test]
    fn afterburner_velocity_matches_thrust_over_mass() {
        // Rifter + 1MN AB II: total 1067000 + 500000.
        let velocity =
            propelled_max_velocity(365.0, 1.35, 1_500_000.0, 1_567_000.0).expect("usable inputs");
        assert_close(
            velocity,
            365.0 * (1.0 + 1.35 * (1_500_000.0 / 1_567_000.0)),
            "Rifter AB",
        );
    }

    #[test]
    fn microwarpdrive_velocities_across_hull_classes() {
        // Rifter + 5MN MWD II.
        let rifter =
            propelled_max_velocity(365.0, 5.10, 1_500_000.0, 1_567_000.0).expect("usable inputs");
        assert_close(
            rifter,
            365.0 * (1.0 + 5.10 * (1_500_000.0 / 1_567_000.0)),
            "Rifter MWD",
        );
        // Muninn + 50MN: total 11000000 + 5000000.
        let muninn =
            propelled_max_velocity(235.0, 5.05, 15_000_000.0, 16_000_000.0).expect("usable inputs");
        assert_close(
            muninn,
            235.0 * (1.0 + 5.05 * (15_000_000.0 / 16_000_000.0)),
            "Muninn 50MN",
        );
        // Raven + 500MN: total 99300000 + 50000000.
        let raven = propelled_max_velocity(113.0, 5.05, 150_000_000.0, 149_300_000.0)
            .expect("usable inputs");
        assert_close(
            raven,
            113.0 * (1.0 + 5.05 * (150_000_000.0 / 149_300_000.0)),
            "Raven 500MN",
        );
    }

    #[test]
    fn align_time_matches_locked_formula() {
        let align = align_time_secs(3.2, 1_067_000.0).expect("usable inputs");
        assert_close(
            align,
            -0.25_f64.ln() * 3.2 * 1_067_000.0 / 1_000_000.0,
            "Rifter align",
        );
    }

    #[test]
    fn armor_plate_mass_slows_velocity_and_align() {
        // 1600mm Steel Plates II (20353) SDE 796=3750000 on
        // a Raven under a 500MN MWD: mass 99300000 +
        // 50000000 (module) + 3750000 (plate).
        let bare = propelled_max_velocity(113.0, 5.05, 150_000_000.0, 149_300_000.0)
            .expect("usable inputs");
        let plated = propelled_max_velocity(113.0, 5.05, 150_000_000.0, 153_050_000.0)
            .expect("usable inputs");
        assert_close(
            plated,
            113.0 * (1.0 + 5.05 * (150_000_000.0 / 153_050_000.0)),
            "plated velocity",
        );
        assert!(plated < bare, "plate must slow the ship");
        let bare_align = align_time_secs(0.12, 149_300_000.0).expect("usable inputs");
        let plated_align = align_time_secs(0.12, 153_050_000.0).expect("usable inputs");
        assert_close(
            plated_align,
            -0.25_f64.ln() * 0.12 * 153_050_000.0 / 1_000_000.0,
            "plated align",
        );
        assert!(plated_align > bare_align, "plate must slow the align");
    }

    #[test]
    fn higgs_percent_mass_doubles_align_mass() {
        // Small Higgs Anchor I (34266) carries SDE operand
        // 100.0 on attribute 1131 (its mass-percent input):
        // +100% mass doubles the align product.
        let doubled = mass_with_percent(1_067_000.0, 100.0).expect("usable inputs");
        assert_close(doubled, 2_134_000.0, "Higgs mass");
        let align = align_time_secs(3.2, doubled).expect("usable inputs");
        assert_close(
            align,
            -0.25_f64.ln() * 3.2 * 2_134_000.0 / 1_000_000.0,
            "Higgs align",
        );
        // Zero-Point Mass Entangler (49099) carries operand
        // -80.0 on the same attribute 1131: the helper
        // applies it as written (mass x 0.2).
        let reduced = mass_with_percent(1_067_000.0, -80.0).expect("usable inputs");
        assert_close(reduced, 213_400.0, "Entangler operand as written");
    }

    #[test]
    fn fitting_propulsion_reads_bundled_rifter() {
        let catalogue = bundled();
        let module = PropulsionModule::from_sde(135.0, 1_500_000.0, 500_000.0);
        let FittingPropulsionOutcome::Available(result) =
            fitting_propulsion(&fitting(587, vec![]), &catalogue, &module)
        else {
            panic!("Rifter propulsion must be Available");
        };
        assert_close(result.base_velocity, 365.0, "base velocity");
        assert_close(result.total_mass, 1_567_000.0, "total mass");
        assert_close(
            result.propelled_velocity,
            365.0 * (1.0 + 1.35 * (1_500_000.0 / 1_567_000.0)),
            "fitting AB velocity",
        );
        assert_close(
            result.align_time_secs,
            -0.25_f64.ln() * 3.2 * 1_567_000.0 / 1_000_000.0,
            "fitting align",
        );
        assert_eq!(result.mass_unapplied_modules, 0);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn fitting_propulsion_unavailable_without_hull_data() {
        let catalogue = bundled();
        let module = PropulsionModule::from_sde(135.0, 1_500_000.0, 500_000.0);
        assert_eq!(
            fitting_propulsion(&fitting(999999, vec![]), &catalogue, &module),
            FittingPropulsionOutcome::Unavailable
        );
        let _ = item("MedSlot0", 1, 438);
    }

    #[test]
    fn unusable_inputs_are_none() {
        assert_eq!(propelled_max_velocity(365.0, 1.35, 1_500_000.0, 0.0), None);
        assert_eq!(
            propelled_max_velocity(-1.0, 1.35, 1_500_000.0, 1_567_000.0),
            None
        );
        assert_eq!(align_time_secs(f64::NAN, 1_067_000.0), None);
        assert_eq!(mass_with_percent(1_067_000.0, -100.0), None);
        assert_eq!(mass_with_percent(0.0, 100.0), None);
    }
}
