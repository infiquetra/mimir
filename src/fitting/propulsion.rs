//! Pure propulsion math: afterburner / microwarpdrive
//! maximum velocity and align time under mass additions.
//!
//! Maximum velocity under an active propulsion module is
//! the EVE thrust-over-mass rule
//! `v_max = v_bonused * (1.0 + boost_factor * (thrust / mass_total))`,
//! where `v_bonused` is the hull's max velocity after real
//! Dogma evaluation (fitted velocity modules such as
//! Overdrive Injectors and Nanofibers, velocity rigs such
//! as Auxiliary Thrusters, hull traits, subsystems,
//! implants, and the Navigation skill —
//! [`crate::fitting::dogma_catalogue`]), `boost_factor` is
//! the module's speed-factor percent divided by 100 (SDE
//! attribute 20 `speedFactor`: 135 on a 1MN Afterburner
//! II, 510 on a 5MN Microwarpdrive II), scaled by
//! Acceleration Control when the module type is known,
//! `thrust` is SDE attribute 567 in newtons, and
//! `mass_total` includes every mass addition — the
//! propulsion module's own (SDE attribute 796, applied
//! while the module is active; this module always models
//! an active propulsion module), armor plates, and
//! percent mass effects such as Higgs Anchor rigs. Align
//! time is the repo-locked
//! `-ln(0.25) * agility * mass / 1_000_000` (the
//! `ship_nav_targeting.rs` formula), recomputed here over
//! the same total mass so velocity and align always agree
//! on what the ship weighs.
//!
//! Velocity carriers that cannot be applied are counted
//! in [`FittingPropulsion::velocity_unapplied_modules`],
//! and every result carries its
//! [`SkillContext`](crate::fitting::dogma_pipeline::SkillContext)
//! tag so the Navigation / Acceleration Control assumption
//! is always disclosed. The module's boost, thrust, and
//! own mass addition arrive as a [`PropulsionModule`]
//! (explicit SDE values, or resolved from the bundled
//! Dogma catalogue by type id).
//!
//! The module is pure computation over the bundled
//! catalogues — no egui, no state, no network, no
//! database. The fitting entry point logs one `[FITTING]`
//! debug line with counts.

use crate::esi::models::CharacterFitting;
use crate::fitting::dogma_catalogue::{
    evaluate_ship_attribute, propulsion_inputs, scaled_speed_factor_percent, DogmaCatalogue,
    ATTR_MAX_VELOCITY,
};
use crate::fitting::dogma_pipeline::SkillContext;
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
    /// The module's own mass addition in kilograms (SDE
    /// attribute 796). Propulsion mass addition applies
    /// while the module is active; the figures here always
    /// model an active module, so it always weighs in.
    pub mass_addition: f64,
    /// Catalogue type id when resolved from the Dogma
    /// catalogue; enables Acceleration Control scaling of
    /// the speed factor. `None` for explicit SDE inputs.
    pub type_id: Option<i64>,
}

impl PropulsionModule {
    /// Build from raw SDE attribute values (20, 567, 796).
    pub fn from_sde(speed_factor_percent: f64, thrust: f64, mass_addition: f64) -> Self {
        Self {
            boost_factor: speed_factor_percent / 100.0,
            thrust,
            mass_addition,
            type_id: None,
        }
    }

    /// Resolve from the bundled Dogma catalogue by type
    /// id. `None` when the type carries no usable
    /// 20/567/796 input set.
    pub fn from_catalogue(dogma: &DogmaCatalogue, type_id: i64) -> Option<Self> {
        let (factor, thrust, mass) = propulsion_inputs(dogma, type_id)?;
        let mut module = Self::from_sde(factor, thrust, mass);
        module.type_id = Some(type_id);
        Some(module)
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
    /// Max velocity after fitted velocity modules, rigs,
    /// hull traits, subsystems, implants, and skills
    /// (attribute 37 through the Dogma pipeline), m/s.
    /// This is the `v_base` the propelled figure scales.
    pub bonused_velocity: f64,
    /// Maximum velocity with the module active, m/s.
    pub propelled_velocity: f64,
    /// Total mass in kg: bonused hull mass (fitted plates
    /// and other baked mass modifiers included) plus the
    /// propulsion module's own mass addition.
    pub total_mass: f64,
    /// Align time in seconds at `total_mass` under the
    /// bonused agility.
    pub align_time_secs: f64,
    /// Velocity modifier instances that could not be
    /// applied (missing operands or unsupported rows on
    /// attribute 37), in quantity units — fitted velocity
    /// modules are never silently dropped.
    pub velocity_unapplied_modules: usize,
    /// Whether Acceleration Control (or another trained
    /// speed-factor skill) actually scaled the module's
    /// boost factor. `false` when the module type is
    /// unknown or no such skill contributed.
    pub propulsion_skill_applied: bool,
    /// Provenance tag of the skill context used (the
    /// Navigation / Acceleration Control assumption).
    pub skill_context_tag: &'static str,
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

/// Propulsion figures for one fitting. Bare hull velocity
/// comes from [`ship_base_stats`]; bonused velocity from
/// real Dogma evaluation over `dogma` (fitted velocity
/// modules, rigs, hull traits, subsystems, implants, and
/// skills under `skills`); bonused mass and agility from
/// [`ship_nav_targeting_with_module_bonuses`], so fitted
/// armor plates, Higgs rigs, and mass entanglers already
/// weigh in before the module's own addition. When
/// `module.type_id` is known, its speed factor is scaled
/// by trained propulsion skills (Acceleration Control).
pub fn fitting_propulsion(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
    dogma: &DogmaCatalogue,
    module: &PropulsionModule,
    skills: &SkillContext,
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
    let velocity = evaluate_ship_attribute(
        fitting,
        dogma,
        ATTR_MAX_VELOCITY,
        base_velocity,
        skills,
        &[],
    );
    let Some(bonused_velocity) = velocity.evaluated.value else {
        return FittingPropulsionOutcome::Unavailable;
    };
    let velocity_unapplied_modules = velocity
        .evaluated
        .unapplied_effects
        .len()
        .saturating_add(velocity.unsupported_modifiers);
    let Some(mass_addition) = usable(module.mass_addition) else {
        return FittingPropulsionOutcome::Unavailable;
    };
    let total_mass = bonused_mass + mass_addition;
    let (boost_factor, propulsion_skill_applied) = match module.type_id {
        Some(type_id) => match scaled_speed_factor_percent(dogma, type_id, skills, false) {
            Some(percent) => (
                percent / 100.0,
                (percent / 100.0 - module.boost_factor).abs() > f64::EPSILON,
            ),
            None => (module.boost_factor, false),
        },
        None => (module.boost_factor, false),
    };
    let (Some(propelled_velocity), Some(align_time)) = (
        propelled_max_velocity(bonused_velocity, boost_factor, module.thrust, total_mass),
        align_time_secs(agility, total_mass),
    ) else {
        return FittingPropulsionOutcome::Unavailable;
    };
    tracing::debug!(
        "[FITTING] fitting propulsion evaluated velocity_unapplied={} excluded={} context={}",
        velocity_unapplied_modules,
        nav.excluded_modules,
        velocity.evaluated.skill_context_tag
    );
    FittingPropulsionOutcome::Available(FittingPropulsion {
        base_velocity,
        bonused_velocity,
        propelled_velocity,
        total_mass,
        align_time_secs: align_time,
        velocity_unapplied_modules,
        propulsion_skill_applied,
        skill_context_tag: velocity.evaluated.skill_context_tag,
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

    fn bundled_dogma() -> DogmaCatalogue {
        DogmaCatalogue::load_bundled().expect("bundled dogma loads")
    }

    fn available(
        fit: &CharacterFitting,
        module: &PropulsionModule,
        skills: &SkillContext,
    ) -> FittingPropulsion {
        match fitting_propulsion(fit, &bundled(), &bundled_dogma(), module, skills) {
            FittingPropulsionOutcome::Available(result) => result,
            FittingPropulsionOutcome::Unavailable => panic!("propulsion must be Available"),
        }
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
        let module = PropulsionModule::from_sde(135.0, 1_500_000.0, 500_000.0);
        let result = available(&fitting(587, vec![]), &module, &SkillContext::BaseOnly);
        assert_close(result.base_velocity, 365.0, "base velocity");
        assert_close(result.bonused_velocity, 365.0, "bonused velocity base only");
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
        assert_eq!(result.velocity_unapplied_modules, 0);
        assert!(!result.propulsion_skill_applied);
        assert_eq!(result.skill_context_tag, "Base Only");
        assert_eq!(result.mass_unapplied_modules, 0);
        assert_eq!(result.excluded_modules, 0);
    }

    #[test]
    fn fitting_propulsion_applies_fitted_velocity_modules_and_skills() {
        // Overdrive Injector System II (1236, +12.5%) and
        // Nanofiber Internal Structure II (2605, +9.5%)
        // fitted: velocity modules are evaluated, never
        // silently dropped. BaseOnly: penalized bonus chain
        // [1.125, 1.095] sorted by |f-1|: 1.125 full, then
        // 1 + 0.095 * S(1). At All V, Navigation (+25%,
        // unpenalized skill) multiplies on top and
        // Acceleration Control scales the 1MN AB II (438)
        // speed factor 135 -> 168.75.
        let dogma = bundled_dogma();
        let module = PropulsionModule::from_catalogue(&dogma, 438).expect("1MN AB II inputs");
        let fit = fitting(
            587,
            vec![
                item("MedSlot0", 1, 438),
                item("LoSlot0", 1, 1236),
                item("LoSlot1", 1, 2605),
            ],
        );
        let s1 = crate::fitting::dogma_pipeline::stacking_effectiveness(1);
        let chain = 1.125 * (1.0 + 0.095 * s1);
        let base_only = available(&fit, &module, &SkillContext::BaseOnly);
        assert_close(
            base_only.bonused_velocity,
            365.0 * chain,
            "bonused base only",
        );
        assert_eq!(base_only.velocity_unapplied_modules, 0);
        assert_close(
            base_only.propelled_velocity,
            365.0 * chain * (1.0 + 1.35 * (1_500_000.0 / base_only.total_mass)),
            "propelled base only",
        );
        let all_five = available(&fit, &module, &SkillContext::AllFive);
        assert_close(
            all_five.bonused_velocity,
            365.0 * chain * 1.25,
            "bonused All V",
        );
        assert!(all_five.propulsion_skill_applied);
        assert_eq!(all_five.skill_context_tag, "Assumes All V");
        assert_close(
            all_five.propelled_velocity,
            365.0 * chain * 1.25 * (1.0 + 1.6875 * (1_500_000.0 / all_five.total_mass)),
            "propelled All V with Acceleration Control",
        );
    }

    #[test]
    fn fitting_propulsion_with_fitted_plate_higgs_and_entangler() {
        // The acceptance path itself, on real fitted rows:
        // 1600mm Steel Plates II (20353) on a Raven under a
        // catalogue-resolved 500MN (5945); Higgs Anchor
        // (34266, +100% mass) and Zero-Point Mass Entangler
        // (49099, -80% mass) on a Rifter. Mass comes from
        // the navigation block's baked families.
        let dogma = bundled_dogma();
        let mwd_500 = PropulsionModule::from_catalogue(&dogma, 5945).expect("500MN inputs");
        let plated = available(
            &fitting(638, vec![item("LoSlot0", 1, 20353)]),
            &mwd_500,
            &SkillContext::BaseOnly,
        );
        assert_close(plated.total_mass, 153_050_000.0, "plated total mass");
        assert_close(
            plated.propelled_velocity,
            113.0 * (1.0 + 5.05 * (150_000_000.0 / 153_050_000.0)),
            "plated Raven velocity",
        );
        assert_close(
            plated.align_time_secs,
            -0.25_f64.ln() * 0.12 * 153_050_000.0 / 1_000_000.0,
            "plated Raven align",
        );
        let ab = PropulsionModule::from_sde(135.0, 1_500_000.0, 500_000.0);
        let higgs = available(
            &fitting(587, vec![item("RigSlot0", 1, 34266)]),
            &ab,
            &SkillContext::BaseOnly,
        );
        assert_close(higgs.total_mass, 2_634_000.0, "Higgs total mass");
        // The Higgs rig itself carries -75% max velocity
        // (attribute 315, flat rig operand).
        assert_close(higgs.bonused_velocity, 91.25, "Higgs velocity penalty");
        let entangled = available(
            &fitting(587, vec![item("MedSlot1", 1, 49099)]),
            &ab,
            &SkillContext::BaseOnly,
        );
        assert_close(entangled.total_mass, 713_400.0, "Entangler total mass");
        // The Entangler carries -95% max velocity
        // (attribute 2603): mass drops, velocity collapses.
        assert_close(
            entangled.bonused_velocity,
            18.25,
            "Entangler velocity penalty",
        );
        assert_close(
            entangled.propelled_velocity,
            18.25 * (1.0 + 1.35 * (1_500_000.0 / 713_400.0)),
            "Entangler propelled velocity",
        );
    }

    #[test]
    fn fitting_propulsion_unavailable_without_hull_data() {
        let catalogue = bundled();
        let dogma = bundled_dogma();
        let module = PropulsionModule::from_sde(135.0, 1_500_000.0, 500_000.0);
        assert_eq!(
            fitting_propulsion(
                &fitting(999999, vec![item("MedSlot0", 1, 438)]),
                &catalogue,
                &dogma,
                &module,
                &SkillContext::BaseOnly
            ),
            FittingPropulsionOutcome::Unavailable
        );
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
