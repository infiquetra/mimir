//! Pure active tank: local repair rates as effective hit
//! points per second, sustained vs burst, under an
//! explicit skill context.
//!
//! This module composes shipped blocks and owns no second
//! repair implementation: raw while-cycling HP/s per layer
//! comes from [`crate::fitting::active_repair::
//! fitting_active_repair`] (shield boosters, armor/hull
//! repairers, ancillaries at dry amounts), bonused
//! resistances from [`crate::fitting::ship_resistances::
//! ship_resistances_with_module_bonuses`], and skill-driven
//! repair-amount scaling from
//! [`crate::fitting::dogma_pipeline`] modifiers the caller
//! resolved from the SDE (for example a +5%-per-level
//! repair skill), evaluated under
//! [`SkillContext::Trained`], [`SkillContext::AllFive`], or
//! [`SkillContext::BaseOnly`] with the tag disclosed.
//!
//! EHP/s uses the uniform damage profile: one layer's
//! divisor is the mean resonance over its present damage
//! types. Burst is the while-cycling rate (ancillary
//! reload is never added — the `active_repair.rs`
//! precedent); sustained applies a caller-supplied uptime
//! fraction when one is given, and otherwise equals burst
//! with [`SustainedBasis::WhileCyclingOnly`] disclosed, so
//! a reload-limited fit is never silently presented as
//! reload-modelled.
//!
//! Pure computation over the bundled catalogue — no egui,
//! no state, no network, no database. Logs nothing
//! (render cadence precedent).

use crate::esi::models::CharacterFitting;
use crate::fitting::active_repair::fitting_active_repair;
use crate::fitting::dogma_pipeline::{
    evaluate_attribute, DogmaModifier, SkillContext, UnappliedEffect,
};
use crate::fitting::ship_resistances::{
    ship_resistances_with_module_bonuses, BonusedShipResistancesOutcome, ResistLayer,
};
use crate::names::fitting_types::FittingTypes;

/// Pipeline grouping key for repair-amount modifiers. This
/// is a local key, not an SDE attribute id: the bundled
/// extract bakes no repair-amount modifier family, so
/// callers tag their SDE-resolved skill/implant repair
/// modifiers with it and this module evaluates them as one
/// multiplier over the base rates.
pub const REPAIR_AMOUNT_ATTRIBUTE_ID: i64 = 0;

/// How the sustained figures were derived.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum SustainedBasis {
    /// No uptime supplied: sustained equals the
    /// while-cycling burst. Ancillary reload and capacitor
    /// limits are not modelled.
    WhileCyclingOnly,
    /// Sustained = burst x this uptime fraction (0..=1),
    /// caller-supplied (for example an ancillary
    /// charge-cycle duty factor).
    UptimeScaled(f64),
    /// The supplied uptime was non-finite or outside
    /// 0..=1, so no sustained figure exists.
    InvalidUptime,
}

/// One layer's active tank figures. Each field is `None`
/// when no honest number exists (unusable repair total,
/// non-finite skill scaling, missing resistances, or a
/// zero/negative mean resonance) — never a silent zero. A
/// present `Some(0.0)` is a proven zero-repair layer.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ActiveTankLayer {
    /// Skill-scaled raw HP/s repaired into this layer.
    pub hp_per_sec: Option<f64>,
    /// Burst (while-cycling) EHP/s under the uniform
    /// profile.
    pub burst_ehp_per_sec: Option<f64>,
    /// Sustained EHP/s under [`SustainedBasis`].
    pub sustained_ehp_per_sec: Option<f64>,
}

/// Active tank for one fitting, plus every count a caller
/// must disclose beside the numbers.
#[derive(Debug, Clone, PartialEq)]
pub struct FittingActiveTank {
    pub shield: ActiveTankLayer,
    pub armor: ActiveTankLayer,
    pub hull: ActiveTankLayer,
    /// Repair-module units counted by the repair block.
    pub counted_modules: u64,
    /// Slot-row units whose repair data cannot be proven.
    pub excluded_modules: u64,
    /// Fitted rows with no catalogue row (resistance
    /// block), in quantity units.
    pub resistance_excluded_modules: usize,
    /// Resistance carriers whose bonus cannot be applied
    /// from the bundled data, in quantity units.
    pub resistance_unapplied_modules: usize,
    /// Repair-amount modifiers the pipeline could not
    /// apply, each with its reason.
    pub unapplied_effects: Vec<UnappliedEffect>,
    /// Modifiers skipped because their carrier is offline.
    pub inactive_offline: usize,
    /// Provenance tag of the skill context used.
    pub skill_context_tag: &'static str,
    pub sustained_basis: SustainedBasis,
}

/// Mean resonance of one layer over its present damage
/// types under the uniform profile. `None` when no damage
/// type is present or the mean is at/below zero (a 100%+
/// resist layer has no finite EHP).
fn mean_resonance(layer: &ResistLayer) -> Option<f64> {
    let mut sum = 0.0;
    let mut count = 0usize;
    for percent in [layer.em, layer.thermal, layer.kinetic, layer.explosive]
        .into_iter()
        .flatten()
    {
        sum += 1.0 - percent / 100.0;
        count += 1;
    }
    if count == 0 {
        return None;
    }
    let mean = sum / count as f64;
    (mean.is_finite() && mean > 0.0).then_some(mean)
}

/// Internal sustained derivation for one layer.
#[derive(Clone, Copy)]
enum SustainedMode {
    EqualsBurst,
    Scale(f64),
    Unavailable,
}

fn layer(
    raw_hp_per_sec: Option<f64>,
    multiplier: Option<f64>,
    resonance: Option<f64>,
    sustained: SustainedMode,
) -> ActiveTankLayer {
    let hp_per_sec = match (raw_hp_per_sec, multiplier) {
        (Some(raw), Some(scale)) => {
            let scaled = raw * scale;
            scaled.is_finite().then_some(scaled)
        }
        _ => None,
    };
    let burst = match (hp_per_sec, resonance) {
        (Some(hp), Some(divisor)) => {
            let ehp = hp / divisor;
            ehp.is_finite().then_some(ehp)
        }
        _ => None,
    };
    let sustained = match (burst, sustained) {
        (Some(value), SustainedMode::Scale(fraction)) => {
            let scaled = value * fraction;
            scaled.is_finite().then_some(scaled)
        }
        (value, SustainedMode::EqualsBurst) => value,
        (None, SustainedMode::Scale(_)) => None,
        (_, SustainedMode::Unavailable) => None,
    };
    ActiveTankLayer {
        hp_per_sec,
        burst_ehp_per_sec: burst,
        sustained_ehp_per_sec: sustained,
    }
}

/// Active tank for one fitting. `repair_modifiers` are
/// SDE-resolved repair-amount modifiers (skills, implants,
/// rigs) evaluated by the Dogma pipeline as one multiplier
/// over the base rates under `skills`; pass an empty slice
/// for unbonused base repair. `sustained_uptime` is an
/// optional 0..=1 duty fraction for the sustained figures.
pub fn fitting_active_tank(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
    skills: &SkillContext,
    repair_modifiers: &[DogmaModifier],
    sustained_uptime: Option<f64>,
) -> FittingActiveTank {
    let repair = fitting_active_repair(fitting, catalogue);
    let scaling = evaluate_attribute(1.0, repair_modifiers, skills);
    let (resistances, resistance_excluded, resistance_unapplied) =
        match ship_resistances_with_module_bonuses(fitting, catalogue) {
            BonusedShipResistancesOutcome::Available(bonused) => (
                Some(bonused.resistances),
                bonused.excluded_modules,
                bonused.unapplied_modules,
            ),
            BonusedShipResistancesOutcome::Unavailable => (None, 0, 0),
        };
    // An invalid uptime must not fall back to burst.
    let (basis, mode) = match sustained_uptime {
        None => (SustainedBasis::WhileCyclingOnly, SustainedMode::EqualsBurst),
        Some(fraction) if fraction.is_finite() && (0.0..=1.0).contains(&fraction) => (
            SustainedBasis::UptimeScaled(fraction),
            SustainedMode::Scale(fraction),
        ),
        Some(_) => (SustainedBasis::InvalidUptime, SustainedMode::Unavailable),
    };
    let shield = layer(
        repair.shield_hp_per_sec,
        scaling.value,
        resistances.as_ref().and_then(|r| mean_resonance(&r.shield)),
        mode,
    );
    let armor = layer(
        repair.armor_hp_per_sec,
        scaling.value,
        resistances.as_ref().and_then(|r| mean_resonance(&r.armor)),
        mode,
    );
    let hull = layer(
        repair.hull_hp_per_sec,
        scaling.value,
        resistances.as_ref().and_then(|r| mean_resonance(&r.hull)),
        mode,
    );
    FittingActiveTank {
        shield,
        armor,
        hull,
        counted_modules: repair.counted_modules,
        excluded_modules: repair.excluded_modules,
        resistance_excluded_modules: resistance_excluded,
        resistance_unapplied_modules: resistance_unapplied,
        unapplied_effects: scaling.unapplied_effects,
        inactive_offline: scaling.inactive_offline,
        skill_context_tag: scaling.skill_context_tag,
        sustained_basis: basis,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::dogma_pipeline::{DogmaOperator, ModifierSource, OperandScaling};

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

    // Fixture hull: shield resonances all 0.5 (50% resists,
    // mean resonance 0.5), armor all 0.4 (60%, mean 0.4),
    // hull all 1.0 (0%). Repairers reuse the
    // active_repair.rs fixture amounts: armor 920/15s,
    // shield 104/3s, ancillary armor 52/6s dry.
    fn fixture_catalogue() -> FittingTypes {
        FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"shieldCapacity":450.0,"armorHP":450.0,"hp":350.0,"shieldEmDamageResonance":0.5,"shieldThermalDamageResonance":0.5,"shieldKineticDamageResonance":0.5,"shieldExplosiveDamageResonance":0.5,"armorEmDamageResonance":0.4,"armorThermalDamageResonance":0.4,"armorKineticDamageResonance":0.4,"armorExplosiveDamageResonance":0.4,"emDamageResonance":1.0,"thermalDamageResonance":1.0,"kineticDamageResonance":1.0,"explosiveDamageResonance":1.0},
                {"typeId":101,"typeName":"Fixture Armor Repairer II","categoryId":7,"slotEffects":[11],"armorDamageAmount":920.0,"duration":15000.0,"armorRepair":true},
                {"typeId":102,"typeName":"Fixture Shield Booster II","categoryId":7,"slotEffects":[13],"shieldBonus":104.0,"duration":3000.0,"shieldBoosting":true},
                {"typeId":103,"typeName":"Fixture Ancillary Armor Repairer","categoryId":7,"slotEffects":[11],"armorDamageAmount":52.0,"duration":6000.0,"reloadTime":60000.0,"fueledArmorRepair":true}]}"#,
        )
        .expect("fixture catalogue parses")
    }

    fn tank_fit() -> CharacterFitting {
        fitting(
            42,
            vec![
                item("LoSlot0", 1, 101),
                item("LoSlot1", 1, 103),
                item("MedSlot0", 1, 102),
            ],
        )
    }

    fn repair_skill() -> DogmaModifier {
        // Fixture +5% repair amount per level, scaled by
        // skill 3393 (the Repair Systems shape).
        let mut skill = DogmaModifier::new(
            REPAIR_AMOUNT_ATTRIBUTE_ID,
            DogmaOperator::PostPercent,
            Some(5.0),
            ModifierSource::Skill,
            3393,
            "fixture repair skill",
        );
        skill.scaling = OperandScaling::PerSkillLevel;
        skill.skill_type_id = Some(3393);
        skill
    }

    #[test]
    fn base_only_burst_ehp_per_layer() {
        let catalogue = fixture_catalogue();
        let tank = fitting_active_tank(&tank_fit(), &catalogue, &SkillContext::BaseOnly, &[], None);
        // Armor raw: 920/15 + 52/6 (ancillary dry); EHP
        // divides by mean resonance 0.4. Shield raw 104/3
        // over 0.5. Hull repairs nothing: proven zero.
        assert_close(
            tank.armor.hp_per_sec.expect("armor raw"),
            920.0 / 15.0 + 52.0 / 6.0,
            "armor raw",
        );
        assert_close(
            tank.armor.burst_ehp_per_sec.expect("armor burst"),
            (920.0 / 15.0 + 52.0 / 6.0) / 0.4,
            "armor burst",
        );
        assert_close(
            tank.shield.burst_ehp_per_sec.expect("shield burst"),
            (104.0 / 3.0) / 0.5,
            "shield burst",
        );
        assert_eq!(tank.hull.hp_per_sec, Some(0.0));
        assert_eq!(tank.hull.burst_ehp_per_sec, Some(0.0));
        assert_eq!(tank.counted_modules, 3);
        assert_eq!(tank.excluded_modules, 0);
        assert_eq!(tank.skill_context_tag, "Base Only");
        assert_eq!(tank.sustained_basis, SustainedBasis::WhileCyclingOnly);
        // No uptime supplied: sustained equals burst.
        assert_eq!(
            tank.armor.sustained_ehp_per_sec,
            tank.armor.burst_ehp_per_sec
        );
    }

    #[test]
    fn skill_context_scales_repair_amount() {
        let catalogue = fixture_catalogue();
        let modifiers = vec![repair_skill()];
        let all_five = fitting_active_tank(
            &tank_fit(),
            &catalogue,
            &SkillContext::AllFive,
            &modifiers,
            None,
        );
        assert_close(
            all_five.shield.hp_per_sec.expect("all V raw"),
            (104.0 / 3.0) * 1.25,
            "all V x1.25",
        );
        assert_eq!(all_five.skill_context_tag, "Assumes All V");
        let trained = fitting_active_tank(
            &tank_fit(),
            &catalogue,
            &SkillContext::Trained(vec![(3393, 4)]),
            &modifiers,
            None,
        );
        assert_close(
            trained.shield.hp_per_sec.expect("trained raw"),
            (104.0 / 3.0) * 1.20,
            "trained IV x1.20",
        );
        assert_eq!(trained.skill_context_tag, "Trained Character");
        let base = fitting_active_tank(
            &tank_fit(),
            &catalogue,
            &SkillContext::BaseOnly,
            &modifiers,
            None,
        );
        assert_close(
            base.shield.hp_per_sec.expect("base raw"),
            104.0 / 3.0,
            "base only x1.0",
        );
    }

    #[test]
    fn sustained_uptime_scales_and_invalid_uptime_is_none() {
        let catalogue = fixture_catalogue();
        let half = fitting_active_tank(
            &tank_fit(),
            &catalogue,
            &SkillContext::BaseOnly,
            &[],
            Some(0.5),
        );
        assert_close(
            half.shield.sustained_ehp_per_sec.expect("sustained half"),
            ((104.0 / 3.0) / 0.5) * 0.5,
            "sustained half",
        );
        assert_eq!(half.sustained_basis, SustainedBasis::UptimeScaled(0.5));
        let invalid = fitting_active_tank(
            &tank_fit(),
            &catalogue,
            &SkillContext::BaseOnly,
            &[],
            Some(1.5),
        );
        assert_eq!(invalid.sustained_basis, SustainedBasis::InvalidUptime);
        assert_eq!(invalid.shield.sustained_ehp_per_sec, None);
        assert!(invalid.shield.burst_ehp_per_sec.is_some());
    }

    #[test]
    fn missing_resistances_keep_raw_but_drop_ehp() {
        // Ship 999 is absent from the fixture catalogue:
        // raw repair still computes (it needs no hull), but
        // no EHP figure can be honest.
        let catalogue = fixture_catalogue();
        let orphan = fitting(999, vec![item("MedSlot0", 1, 102)]);
        let tank = fitting_active_tank(&orphan, &catalogue, &SkillContext::BaseOnly, &[], None);
        assert_close(
            tank.shield.hp_per_sec.expect("raw"),
            104.0 / 3.0,
            "raw without hull",
        );
        assert_eq!(tank.shield.burst_ehp_per_sec, None);
        assert_eq!(tank.shield.sustained_ehp_per_sec, None);
    }

    #[test]
    fn unknown_repair_operand_is_disclosed_not_guessed() {
        let catalogue = fixture_catalogue();
        let unknown = DogmaModifier::new(
            REPAIR_AMOUNT_ATTRIBUTE_ID,
            DogmaOperator::PostPercent,
            None,
            ModifierSource::Skill,
            3393,
            "unpublished operand",
        );
        let tank = fitting_active_tank(
            &tank_fit(),
            &catalogue,
            &SkillContext::AllFive,
            &[unknown],
            None,
        );
        assert_eq!(tank.unapplied_effects.len(), 1);
        assert_close(
            tank.shield.hp_per_sec.expect("unscaled raw"),
            104.0 / 3.0,
            "operand never guessed",
        );
    }
}
