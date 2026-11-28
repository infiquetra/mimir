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
//! ship_resistances_with_module_bonuses`], and repair
//! scaling from [`crate::fitting::dogma_pipeline`]
//! modifiers keyed to the REAL per-layer repair-amount
//! attributes (shield bonus 68, armor damage amount 84,
//! structure damage amount 83), evaluated per layer under
//! [`SkillContext::Trained`], [`SkillContext::AllFive`], or
//! [`SkillContext::BaseOnly`] with the tag disclosed. A
//! modifier scoped to one layer can therefore never
//! inflate another: Repair Systems (3393), which shortens
//! armor/hull repairer cycles, boosts armor and hull
//! only.
//!
//! [`fitting_active_tank_with_catalogue`] builds those
//! modifiers from bundled Dogma itself (hull repair
//! traits, subsystem bonuses, implants, rigs, and repair
//! skills via [`crate::fitting::dogma_catalogue`]) and
//! additionally applies per-layer cycle-duration scaling:
//! when every counted repairer in a layer requires the
//! same skill, that skill's duration modifiers (Repair
//! Systems: -5% cycle per level) divide into the layer's
//! HP/s. Mixed-skill layers disclose instead of guessing.
//!
//! EHP/s uses the uniform damage profile: one layer's
//! divisor is the mean resonance over its present damage
//! types. Burst is the while-cycling rate (ancillary
//! reload is never added — the `active_repair.rs`
//! precedent); sustained applies a caller-supplied uptime
//! fraction when one is given, and otherwise equals burst
//! with [`SustainedBasis::WhileCyclingOnly`] disclosed, so
//! a reload-limited fit is never silently presented as
//! reload-modelled. Ancillary armor repairers always
//! count at dry (unloaded) amounts; Nanite Repair Paste
//! would multiply their repair amount (SDE attribute
//! 1886), and [`AncillaryPasteState`] on every result says
//! so explicitly whenever one is fitted.
//!
//! Pure computation over the bundled catalogues — no
//! egui, no state, no network, no database. Fitting-level
//! entries log one `[FITTING]` debug line with counts.

use crate::esi::models::CharacterFitting;
use crate::fitting::active_repair::fitting_active_repair;
use crate::fitting::dogma_catalogue::{
    fitting_location_skill_modifiers, fitting_ship_modifiers, skill_location_modifiers,
    DogmaCatalogue, ATTR_ARMOR_DAMAGE_AMOUNT, ATTR_DURATION, ATTR_REQUIRED_SKILL_1,
    ATTR_SHIELD_BONUS, ATTR_STRUCTURE_DAMAGE_AMOUNT,
};
use crate::fitting::dogma_pipeline::{
    evaluate_attribute, DogmaModifier, DogmaOperator, SkillContext, UnappliedEffect,
    UnappliedReason,
};
use crate::fitting::ship_resistances::{
    ship_resistances_with_module_bonuses, BonusedShipResistancesOutcome, ResistLayer,
};
use crate::names::fitting_types::FittingTypes;

/// Shield-layer repair-amount attribute (`shieldBonus`).
/// Repair modifiers for the shield layer are keyed with
/// this real SDE id and evaluate only against shield HP/s.
pub const SHIELD_REPAIR_ATTRIBUTE_ID: i64 = ATTR_SHIELD_BONUS;
/// Armor-layer repair-amount attribute
/// (`armorDamageAmount`).
pub const ARMOR_REPAIR_ATTRIBUTE_ID: i64 = ATTR_ARMOR_DAMAGE_AMOUNT;
/// Hull-layer repair-amount attribute
/// (`structureDamageAmount`).
pub const HULL_REPAIR_ATTRIBUTE_ID: i64 = ATTR_STRUCTURE_DAMAGE_AMOUNT;

/// Whether fitted ancillary armor repairers are present
/// and therefore whether the armor figures assume dry
/// (unloaded) amounts. Loaded with Nanite Repair Paste an
/// ancillary armor repairer repairs at its SDE 1886
/// multiplier (x3) while charges last; that loaded state
/// is never modelled silently.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum AncillaryPasteState {
    /// No ancillary (fueled) armor repairer is fitted and
    /// counted; paste state cannot affect the figures.
    NoAncillaryArmorRepairers,
    /// Ancillary armor repairers are fitted and counted
    /// at dry amounts. Loaded burst would be higher (SDE
    /// attribute 1886 on the ancillary portion) and is
    /// not included in any figure.
    DryAmountsAssumed { ancillary_modules: u64 },
}

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
    /// Dry-vs-loaded disclosure for ancillary armor
    /// repairers (Nanite Repair Paste never modelled).
    pub ancillary_paste: AncillaryPasteState,
    /// Evaluated cycle-duration multiplier per layer from
    /// repair skills (catalogue entry point only):
    /// `Some(0.75)` means cycles run at 75% duration and
    /// HP/s was divided by it; `Some(1.0)` evaluated with
    /// no change; `None` when no uniform layer skill
    /// exists (plain entry point, mixed skills, or no
    /// counted repairer) and no duration scaling applied.
    pub shield_duration_factor: Option<f64>,
    pub armor_duration_factor: Option<f64>,
    pub hull_duration_factor: Option<f64>,
}

/// Count fitted ancillary (fueled) armor repairer units
/// the repair block would count, for the paste disclosure.
fn ancillary_paste_state(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> AncillaryPasteState {
    let mut ancillary_modules: u64 = 0;
    for item in &fitting.items {
        if item.type_id <= 0 || item.quantity.max(0) == 0 {
            continue;
        }
        let slot = item.flag.starts_with("LoSlot")
            || item.flag.starts_with("MedSlot")
            || item.flag.starts_with("HiSlot")
            || item.flag.starts_with("RigSlot")
            || item.flag.starts_with("SubSystemSlot");
        if !slot {
            continue;
        }
        if let Some(row) = catalogue.lookup_by_id(item.type_id) {
            if row.fueled_armor_repair {
                ancillary_modules = ancillary_modules.saturating_add(item.quantity.max(0) as u64);
            }
        }
    }
    if ancillary_modules == 0 {
        AncillaryPasteState::NoAncillaryArmorRepairers
    } else {
        AncillaryPasteState::DryAmountsAssumed { ancillary_modules }
    }
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
/// repair-AMOUNT modifiers keyed to the real per-layer
/// SDE attributes ([`SHIELD_REPAIR_ATTRIBUTE_ID`],
/// [`ARMOR_REPAIR_ATTRIBUTE_ID`],
/// [`HULL_REPAIR_ATTRIBUTE_ID`]); each layer evaluates
/// only its own modifiers as a multiplier over its base
/// rate under `skills`, so an armor repair bonus can
/// never inflate shield boosting. Modifiers keyed to any
/// other attribute are disclosed in `unapplied_effects`.
/// Pass an empty slice for unbonused base repair.
/// `sustained_uptime` is an optional 0..=1 duty fraction
/// for the sustained figures. Cycle-duration skills are
/// applied only by [`fitting_active_tank_with_catalogue`].
pub fn fitting_active_tank(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
    skills: &SkillContext,
    repair_modifiers: &[DogmaModifier],
    sustained_uptime: Option<f64>,
) -> FittingActiveTank {
    let repair = fitting_active_repair(fitting, catalogue);
    let layer_scaling = |attribute_id: i64| {
        let own: Vec<DogmaModifier> = repair_modifiers
            .iter()
            .filter(|m| m.attribute_id == attribute_id)
            .cloned()
            .collect();
        evaluate_attribute(1.0, &own, skills)
    };
    let shield_scaling = layer_scaling(SHIELD_REPAIR_ATTRIBUTE_ID);
    let armor_scaling = layer_scaling(ARMOR_REPAIR_ATTRIBUTE_ID);
    let hull_scaling = layer_scaling(HULL_REPAIR_ATTRIBUTE_ID);
    let mut unapplied_effects: Vec<UnappliedEffect> = Vec::new();
    let mut inactive_offline: usize = 0;
    for scaling in [&shield_scaling, &armor_scaling, &hull_scaling] {
        unapplied_effects.extend(scaling.unapplied_effects.iter().cloned());
        inactive_offline = inactive_offline.saturating_add(scaling.inactive_offline);
    }
    for modifier in repair_modifiers {
        if !matches!(
            modifier.attribute_id,
            SHIELD_REPAIR_ATTRIBUTE_ID | ARMOR_REPAIR_ATTRIBUTE_ID | HULL_REPAIR_ATTRIBUTE_ID
        ) {
            unapplied_effects.push(UnappliedEffect {
                label: modifier.label.clone(),
                source_type_id: modifier.source_type_id,
                operator: modifier.operator,
                reason: UnappliedReason::UnknownAttribute,
            });
        }
    }
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
        shield_scaling.value,
        resistances.as_ref().and_then(|r| mean_resonance(&r.shield)),
        mode,
    );
    let armor = layer(
        repair.armor_hp_per_sec,
        armor_scaling.value,
        resistances.as_ref().and_then(|r| mean_resonance(&r.armor)),
        mode,
    );
    let hull = layer(
        repair.hull_hp_per_sec,
        hull_scaling.value,
        resistances.as_ref().and_then(|r| mean_resonance(&r.hull)),
        mode,
    );
    tracing::debug!(
        "[FITTING] active tank evaluated counted={} excluded={} unapplied={} context={}",
        repair.counted_modules,
        repair.excluded_modules,
        unapplied_effects.len(),
        skills.tag()
    );
    FittingActiveTank {
        shield,
        armor,
        hull,
        counted_modules: repair.counted_modules,
        excluded_modules: repair.excluded_modules,
        resistance_excluded_modules: resistance_excluded,
        resistance_unapplied_modules: resistance_unapplied,
        unapplied_effects,
        inactive_offline,
        skill_context_tag: skills.tag(),
        sustained_basis: basis,
        ancillary_paste: ancillary_paste_state(fitting, catalogue),
        shield_duration_factor: None,
        armor_duration_factor: None,
        hull_duration_factor: None,
    }
}

/// Required skill (SDE attribute 182) of every counted
/// repairer in one layer, or `None` when the layer has no
/// counted repairer or mixes required skills.
fn uniform_layer_skill(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
    dogma: &DogmaCatalogue,
    amount_attribute_id: i64,
) -> Option<i64> {
    let mut uniform: Option<i64> = None;
    for item in &fitting.items {
        if item.type_id <= 0 || item.quantity.max(0) == 0 {
            continue;
        }
        let slot = item.flag.starts_with("LoSlot")
            || item.flag.starts_with("MedSlot")
            || item.flag.starts_with("HiSlot")
            || item.flag.starts_with("RigSlot")
            || item.flag.starts_with("SubSystemSlot");
        if !slot {
            continue;
        }
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            continue;
        };
        let (family, amount) = if row.armor_repair
            || row.fueled_armor_repair
            || row.armor_damage_amount.is_some()
        {
            (ARMOR_REPAIR_ATTRIBUTE_ID, row.armor_damage_amount)
        } else if row.shield_boosting || row.fueled_shield_boosting || row.shield_bonus.is_some() {
            (SHIELD_REPAIR_ATTRIBUTE_ID, row.shield_bonus)
        } else if row.structure_repair || row.structure_damage_amount.is_some() {
            (HULL_REPAIR_ATTRIBUTE_ID, row.structure_damage_amount)
        } else {
            continue;
        };
        if family != amount_attribute_id {
            continue;
        }
        // Mirror the repair block's counted rule: usable
        // positive amount and cycle.
        let counted = matches!(amount, Some(a) if a.is_finite() && a > 0.0)
            && matches!(row.duration, Some(d) if d.is_finite() && d > 0.0);
        if !counted {
            continue;
        }
        let required = dogma
            .attribute(item.type_id, ATTR_REQUIRED_SKILL_1)
            .filter(|v| v.is_finite() && v.fract() == 0.0 && *v > 0.0)
            .map(|v| v as i64);
        match (uniform, required) {
            (None, Some(skill)) => uniform = Some(skill),
            (Some(existing), Some(skill)) if existing == skill => {}
            _ => return None,
        }
    }
    uniform
}

/// Evaluated duration multiplier for one layer plus any
/// location modifiers that had to be disclosed. The
/// multiplier is scale-invariant only for multiplicative
/// operators; an additive duration row makes the layer
/// unresolvable (`None`) instead of guessed.
fn layer_duration_factor(
    fitting: &CharacterFitting,
    dogma: &DogmaCatalogue,
    skills: &SkillContext,
    layer_skill: Option<i64>,
    disclosed: &mut Vec<UnappliedEffect>,
) -> Option<f64> {
    let layer_skill = layer_skill?;
    let mut modifiers: Vec<DogmaModifier> =
        skill_location_modifiers(dogma, layer_skill, ATTR_DURATION);
    for (required, modifier) in fitting_location_skill_modifiers(fitting, dogma, ATTR_DURATION) {
        if required == layer_skill {
            modifiers.push(modifier);
        } else {
            disclosed.push(UnappliedEffect {
                label: modifier.label.clone(),
                source_type_id: modifier.source_type_id,
                operator: modifier.operator,
                reason: UnappliedReason::LayerSkillMismatch,
            });
        }
    }
    if modifiers
        .iter()
        .any(|m| matches!(m.operator, DogmaOperator::ModAdd | DogmaOperator::ModSub))
    {
        return None;
    }
    evaluate_attribute(1.0, &modifiers, skills)
        .value
        .filter(|f| f.is_finite() && *f > 0.0)
}

fn scale_layer(layer: &mut ActiveTankLayer, duration_factor: Option<f64>) {
    let Some(factor) = duration_factor else {
        return;
    };
    let rate = |value: Option<f64>| value.map(|v| v / factor).filter(|v| v.is_finite());
    layer.hp_per_sec = rate(layer.hp_per_sec);
    layer.burst_ehp_per_sec = rate(layer.burst_ehp_per_sec);
    layer.sustained_ehp_per_sec = rate(layer.sustained_ehp_per_sec);
}

/// Active tank with modifiers built from bundled Dogma:
/// per-layer repair-amount bonuses (hull traits,
/// subsystem bonuses, implants, rigs, skills) plus
/// per-layer cycle-duration scaling from repair skills.
/// Repair Systems therefore boosts armor and hull HP/s
/// through shorter cycles and never touches shield
/// boosting, whose modules require Shield Operation.
pub fn fitting_active_tank_with_catalogue(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
    dogma: &DogmaCatalogue,
    skills: &SkillContext,
    sustained_uptime: Option<f64>,
) -> FittingActiveTank {
    let built = fitting_ship_modifiers(fitting, dogma, skills, &[]);
    let mut amount_modifiers: Vec<DogmaModifier> = built
        .modifiers
        .into_iter()
        .filter(|m| {
            matches!(
                m.attribute_id,
                SHIELD_REPAIR_ATTRIBUTE_ID | ARMOR_REPAIR_ATTRIBUTE_ID | HULL_REPAIR_ATTRIBUTE_ID
            )
        })
        .collect();
    let layer_skills = [
        (
            SHIELD_REPAIR_ATTRIBUTE_ID,
            uniform_layer_skill(fitting, catalogue, dogma, SHIELD_REPAIR_ATTRIBUTE_ID),
        ),
        (
            ARMOR_REPAIR_ATTRIBUTE_ID,
            uniform_layer_skill(fitting, catalogue, dogma, ARMOR_REPAIR_ATTRIBUTE_ID),
        ),
        (
            HULL_REPAIR_ATTRIBUTE_ID,
            uniform_layer_skill(fitting, catalogue, dogma, HULL_REPAIR_ATTRIBUTE_ID),
        ),
    ];
    let mut disclosed: Vec<UnappliedEffect> = Vec::new();
    for (attribute_id, layer_skill) in layer_skills {
        for (required, modifier) in fitting_location_skill_modifiers(fitting, dogma, attribute_id) {
            if Some(required) == layer_skill {
                amount_modifiers.push(modifier);
            } else {
                disclosed.push(UnappliedEffect {
                    label: modifier.label.clone(),
                    source_type_id: modifier.source_type_id,
                    operator: modifier.operator,
                    reason: UnappliedReason::LayerSkillMismatch,
                });
            }
        }
    }
    let mut tank = fitting_active_tank(
        fitting,
        catalogue,
        skills,
        &amount_modifiers,
        sustained_uptime,
    );
    let shield_factor =
        layer_duration_factor(fitting, dogma, skills, layer_skills[0].1, &mut disclosed);
    let armor_factor =
        layer_duration_factor(fitting, dogma, skills, layer_skills[1].1, &mut disclosed);
    let hull_factor =
        layer_duration_factor(fitting, dogma, skills, layer_skills[2].1, &mut disclosed);
    scale_layer(&mut tank.shield, shield_factor);
    scale_layer(&mut tank.armor, armor_factor);
    scale_layer(&mut tank.hull, hull_factor);
    tank.shield_duration_factor = shield_factor;
    tank.armor_duration_factor = armor_factor;
    tank.hull_duration_factor = hull_factor;
    tank.unapplied_effects.extend(disclosed);
    tracing::debug!(
        "[FITTING] active tank catalogue wiring counted={} amount_modifiers={} context={}",
        tank.counted_modules,
        amount_modifiers.len(),
        skills.tag()
    );
    tank
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
        // Fixture +5% ARMOR repair amount per level, scaled
        // by skill 3393, keyed to the real armor amount
        // attribute. It must never touch the shield layer.
        let mut skill = DogmaModifier::new(
            ARMOR_REPAIR_ATTRIBUTE_ID,
            DogmaOperator::PostPercent,
            Some(5.0),
            ModifierSource::Skill,
            3393,
            "fixture armor repair skill",
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
    fn skill_context_scales_only_its_own_layer() {
        // Per-layer scoping (P1-4): the armor-scoped skill
        // scales armor HP/s and leaves shield HP/s at the
        // unbonused rate under every context.
        let catalogue = fixture_catalogue();
        let modifiers = vec![repair_skill()];
        let armor_raw = 920.0 / 15.0 + 52.0 / 6.0;
        let all_five = fitting_active_tank(
            &tank_fit(),
            &catalogue,
            &SkillContext::AllFive,
            &modifiers,
            None,
        );
        assert_close(
            all_five.armor.hp_per_sec.expect("all V armor"),
            armor_raw * 1.25,
            "armor all V x1.25",
        );
        assert_close(
            all_five.shield.hp_per_sec.expect("all V shield"),
            104.0 / 3.0,
            "shield untouched at All V",
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
            trained.armor.hp_per_sec.expect("trained armor"),
            armor_raw * 1.20,
            "armor trained IV x1.20",
        );
        assert_close(
            trained.shield.hp_per_sec.expect("trained shield"),
            104.0 / 3.0,
            "shield untouched trained",
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
            base.armor.hp_per_sec.expect("base armor"),
            armor_raw,
            "armor base only x1.0",
        );
        // The fixture fits an ancillary armor repairer:
        // dry paste state must be disclosed.
        assert_eq!(
            base.ancillary_paste,
            AncillaryPasteState::DryAmountsAssumed {
                ancillary_modules: 1
            }
        );
        assert_eq!(base.armor_duration_factor, None);
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
            ARMOR_REPAIR_ATTRIBUTE_ID,
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

    #[test]
    fn catalogue_wiring_repair_systems_never_boosts_shield() {
        // Real bundled data: Small Ancillary Shield Booster
        // (32774, 52 HP / 2 s = 26 HP/s) plus Medium Armor
        // Repairer II (3530, 368 HP / 12 s) on a Rifter.
        // At All V, Repair Systems shortens the armor cycle
        // x0.75 (armor HP/s / 0.75) and must leave shield
        // HP/s exactly at base — shield boosters require
        // Shield Operation, which has no duration bonus.
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let dogma = DogmaCatalogue::load_bundled().expect("bundled dogma loads");
        let fit = fitting(
            587,
            vec![item("MedSlot0", 1, 32774), item("LoSlot0", 1, 3530)],
        );
        let base = fitting_active_tank_with_catalogue(
            &fit,
            &catalogue,
            &dogma,
            &SkillContext::BaseOnly,
            None,
        );
        assert_close(
            base.shield.hp_per_sec.expect("shield base"),
            26.0,
            "shield base",
        );
        assert_close(
            base.armor.hp_per_sec.expect("armor base"),
            368.0 / 12.0,
            "armor base",
        );
        assert_eq!(base.armor_duration_factor, Some(1.0));
        let all_five = fitting_active_tank_with_catalogue(
            &fit,
            &catalogue,
            &dogma,
            &SkillContext::AllFive,
            None,
        );
        assert_close(
            all_five.shield.hp_per_sec.expect("shield all V"),
            26.0,
            "Repair Systems never boosts shield",
        );
        assert_close(
            all_five.armor.hp_per_sec.expect("armor all V"),
            (368.0 / 12.0) / 0.75,
            "armor cycle x0.75 at All V",
        );
        assert_eq!(all_five.armor_duration_factor, Some(0.75));
        assert_eq!(all_five.shield_duration_factor, Some(1.0));
        assert_eq!(all_five.skill_context_tag, "Assumes All V");
    }

    #[test]
    fn catalogue_wiring_myrmidon_hull_trait_scales_armor_amount() {
        // Myrmidon (24700): +7.5% armor repair amount per
        // Gallente Battlecruiser level on repairers
        // requiring Repair Systems, plus Repair Systems
        // cycle x0.75 at All V: 368 x 1.375 / (12 x 0.75).
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let dogma = DogmaCatalogue::load_bundled().expect("bundled dogma loads");
        let fit = fitting(24700, vec![item("LoSlot0", 1, 3530)]);
        let all_five = fitting_active_tank_with_catalogue(
            &fit,
            &catalogue,
            &dogma,
            &SkillContext::AllFive,
            None,
        );
        assert_close(
            all_five.armor.hp_per_sec.expect("myrmidon armor"),
            368.0 * 1.375 / 9.0,
            "hull trait amount + duration at All V",
        );
        let base = fitting_active_tank_with_catalogue(
            &fit,
            &catalogue,
            &dogma,
            &SkillContext::BaseOnly,
            None,
        );
        assert_close(
            base.armor.hp_per_sec.expect("myrmidon base"),
            368.0 / 12.0,
            "base only unbonused",
        );
    }
}
