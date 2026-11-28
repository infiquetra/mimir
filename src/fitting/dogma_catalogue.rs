//! Bundled Dogma catalogue and fitting-level modifier
//! resolution (#639 P1-5 wiring).
//!
//! [`DogmaCatalogue`] loads the two generated SDE extracts
//! that carry complete Dogma (`assets/sde/dogma.json`:
//! every type's attributes and effect list;
//! `assets/sde/effect_modifiers.json`: every effect's
//! modifier rows) and builds real
//! [`DogmaModifier`]s for one fitting: hull traits
//! (category 6), fitted modules and rigs (category 7),
//! charges (category 8), trained skills (category 16),
//! implants and boosters (category 20), and T3C subsystems
//! (category 32), plus overheated state for caller-named
//! module types. The shipped `ship_*` blocks keep their
//! baked catalogue families untouched; this module is the
//! general evaluator the new fitting-level entry points
//! (`fitting_propulsion`, `fitting_active_tank`, and
//! [`evaluate_ship_attribute`]) consume.
//!
//! Resolution rules, all grounded in the bundled rows:
//!
//! - Operator codes use the repo-locked Flutter map shared
//!   with the baked families: `0`/`4` postMul, `2` modAdd,
//!   `6` postPercent. Any other operator on a ship-scoped
//!   modifier is disclosed in
//!   [`FittingShipModifiers::unsupported`], never guessed.
//! - Only `ItemModifier` rows with domain `shipID` become
//!   ship-attribute modifiers. Other ship-scoped funcs
//!   (`LocationRequiredSkillModifier`,
//!   `LocationGroupModifier`,
//!   `OwnerRequiredSkillModifier`) target fitted items,
//!   groups, drones, or charges; they are counted as
//!   unsupported for ship attributes (the duration subset
//!   is consumed separately through
//!   [`skill_location_modifiers`]). Non-`shipID` domains
//!   never claimed to modify the ship and are skipped.
//! - Per-level scaling is data-driven: an operand
//!   attribute is per-level exactly when some skill type
//!   carries a modifier `modified == operand attribute,
//!   modifying == 280` (the skill level attribute) — the
//!   chain every skill bonus, hull trait, and subsystem
//!   bonus uses in the SDE — AND that skill is the owner
//!   itself (skill bonuses) or one of the owner's
//!   required skills (attributes 182/183; hull traits and
//!   subsystem bonuses). A module or rig that merely
//!   reuses a bonus attribute id (Auxiliary Thrusters on
//!   315) therefore stays flat, never skill-scaled.
//! - The bundled extracts carry no per-attribute
//!   `stackable` metadata, so module/rig/subsystem
//!   modifiers assume a non-stackable target (the
//!   `ship_resistances.rs` family precedent).
//! - Fitted items are `Online`; types the caller names
//!   overheated are `Overheated` and additionally include
//!   their `overload*` ship-scoped modifiers. Offline
//!   state is not present in saved-fitting data.
//!
//! Pure computation over bundled data — no egui, no state,
//! no network, no database. Fitting-level entry points log
//! one `[FITTING]` debug line with counts only.

use std::collections::HashMap;

use serde::Deserialize;

use crate::error::AppResult;
use crate::esi::models::CharacterFitting;
use crate::fitting::dogma_pipeline::{
    evaluate_attribute, DogmaModifier, DogmaOperator, EvaluatedAttribute, ModifierSource,
    ModuleState, OperandScaling, SkillContext,
};

/// `speedFactor` (propulsion boost percent input).
pub const ATTR_SPEED_FACTOR: i64 = 20;
/// `maxVelocity`.
pub const ATTR_MAX_VELOCITY: i64 = 37;
/// `shieldBonus` (shield booster repair amount).
pub const ATTR_SHIELD_BONUS: i64 = 68;
/// Module cycle `duration` in milliseconds.
pub const ATTR_DURATION: i64 = 73;
/// `structureDamageAmount` (hull repairer amount).
pub const ATTR_STRUCTURE_DAMAGE_AMOUNT: i64 = 83;
/// `armorDamageAmount` (armor repairer amount).
pub const ATTR_ARMOR_DAMAGE_AMOUNT: i64 = 84;
/// `requiredSkill1`.
pub const ATTR_REQUIRED_SKILL_1: i64 = 182;
/// Skill level attribute (the per-level chain link).
pub const ATTR_SKILL_LEVEL: i64 = 280;
/// Propulsion thrust in newtons.
pub const ATTR_THRUST: i64 = 567;
/// Propulsion own mass addition in kilograms.
pub const ATTR_MASS_ADDITION: i64 = 796;
/// Ancillary loaded-charge repair multiplier.
pub const ATTR_ANCILLARY_MULTIPLIER: i64 = 1886;

/// Acceleration Control (afterburner/microwarpdrive
/// speed-factor skill).
pub const ACCELERATION_CONTROL_SKILL_ID: i64 = 3452;
/// Repair Systems (armor/hull repairer cycle skill).
pub const REPAIR_SYSTEMS_SKILL_ID: i64 = 3393;

/// Per-row fitted-quantity expansion cap: slot rows carry
/// small real quantities; the cap bounds hostile saved
/// data without changing any honest fit.
const MAX_EXPANDED_UNITS: i64 = 100;

#[derive(Debug, Clone, Default, Deserialize)]
struct RawDogmaFile {
    #[serde(default)]
    groups: Vec<RawGroup>,
    #[serde(default)]
    types: Vec<RawType>,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct RawGroup {
    #[serde(rename = "groupId", default)]
    group_id: i64,
    #[serde(rename = "categoryId", default)]
    category_id: i64,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct RawType {
    #[serde(rename = "typeId", default)]
    type_id: i64,
    #[serde(rename = "groupId", default)]
    group_id: i64,
    #[serde(rename = "dogmaAttributes", default)]
    attributes: Vec<RawAttribute>,
    #[serde(rename = "dogmaEffects", default)]
    effects: Vec<RawTypeEffect>,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct RawAttribute {
    #[serde(rename = "attributeId", default)]
    attribute_id: i64,
    #[serde(default)]
    value: f64,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct RawTypeEffect {
    #[serde(rename = "effectId", default)]
    effect_id: i64,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct RawEffect {
    #[serde(default)]
    name: String,
    #[serde(default)]
    modifiers: Vec<RawEffectModifier>,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct RawEffectModifier {
    #[serde(default)]
    func: String,
    #[serde(default)]
    operator: i64,
    #[serde(rename = "modifiedAttributeId", default)]
    modified_attribute_id: i64,
    #[serde(default)]
    domain: String,
    #[serde(rename = "modifyingAttributeId", default)]
    modifying_attribute_id: i64,
    #[serde(rename = "skillTypeId", default)]
    skill_type_id: Option<i64>,
    #[serde(rename = "groupId", default)]
    group_id: Option<i64>,
}

/// One Dogma type row: identity, category (through its
/// group), base attributes, and effect ids.
#[derive(Debug, Clone, PartialEq)]
pub struct DogmaType {
    pub type_id: i64,
    pub group_id: i64,
    pub category_id: i64,
    pub attributes: HashMap<i64, f64>,
    pub effect_ids: Vec<i64>,
}

impl DogmaType {
    /// One base attribute value, when the SDE row carries it.
    pub fn attribute(&self, attribute_id: i64) -> Option<f64> {
        self.attributes.get(&attribute_id).copied()
    }
}

/// One effect modifier row from `effect_modifiers.json`.
#[derive(Debug, Clone, PartialEq)]
pub struct EffectModifier {
    pub func: String,
    pub operator: i64,
    pub modified_attribute_id: i64,
    pub domain: String,
    pub modifying_attribute_id: i64,
    pub skill_type_id: Option<i64>,
    pub group_id: Option<i64>,
}

/// One ship-scoped modifier the evaluator cannot model,
/// disclosed instead of dropped.
#[derive(Debug, Clone, PartialEq)]
pub struct UnsupportedModifier {
    pub attribute_id: i64,
    /// Owner type id, for provenance only.
    pub source_type_id: i64,
    /// Effect name carrying the modifier.
    pub label: String,
}

/// In-memory Dogma index over the bundled extracts.
#[derive(Debug, Clone, Default)]
pub struct DogmaCatalogue {
    types: HashMap<i64, DogmaType>,
    effects: HashMap<i64, (String, Vec<EffectModifier>)>,
    skill_type_ids: Vec<i64>,
    /// Operand attribute id -> skills whose level chain
    /// (`modifying == 280`) scales that attribute.
    per_level_skills: HashMap<i64, Vec<i64>>,
}

/// Shared bundled Dogma catalogue (#648 repair): parsed at most once
/// per process, failure cached too, so no view re-parses per frame.
pub fn shared_bundled_dogma() -> Option<std::sync::Arc<DogmaCatalogue>> {
    use std::sync::OnceLock;
    static SHARED: OnceLock<Result<std::sync::Arc<DogmaCatalogue>, String>> = OnceLock::new();
    let result = SHARED.get_or_init(|| {
        DogmaCatalogue::load_bundled()
            .map(std::sync::Arc::new)
            .map_err(|e| e.to_string())
    });
    match result {
        Ok(arc) => Some(std::sync::Arc::clone(arc)),
        Err(message) => {
            tracing::warn!("[FITTING] shared dogma catalogue unavailable: {message}");
            None
        }
    }
}

impl DogmaCatalogue {
    pub fn load_bundled() -> AppResult<Self> {
        tracing::debug!("[FITTING] loading bundled dogma catalogue");
        Self::from_json(
            include_str!("../../assets/sde/dogma.json"),
            include_str!("../../assets/sde/effect_modifiers.json"),
        )
    }

    pub fn from_json(dogma_json: &str, effect_modifiers_json: &str) -> AppResult<Self> {
        let dogma_file: RawDogmaFile = serde_json::from_str(dogma_json)?;
        let raw_effects: HashMap<String, RawEffect> = serde_json::from_str(effect_modifiers_json)?;
        let category_by_group: HashMap<i64, i64> = dogma_file
            .groups
            .iter()
            .map(|g| (g.group_id, g.category_id))
            .collect();
        let mut types: HashMap<i64, DogmaType> = HashMap::with_capacity(dogma_file.types.len());
        for raw in dogma_file.types {
            let category_id = category_by_group.get(&raw.group_id).copied().unwrap_or(0);
            types.insert(
                raw.type_id,
                DogmaType {
                    type_id: raw.type_id,
                    group_id: raw.group_id,
                    category_id,
                    attributes: raw
                        .attributes
                        .into_iter()
                        .map(|a| (a.attribute_id, a.value))
                        .collect(),
                    effect_ids: raw.effects.into_iter().map(|e| e.effect_id).collect(),
                },
            );
        }
        let mut effects: HashMap<i64, (String, Vec<EffectModifier>)> =
            HashMap::with_capacity(raw_effects.len());
        for (key, raw) in raw_effects {
            let Ok(effect_id) = key.parse::<i64>() else {
                continue;
            };
            effects.insert(
                effect_id,
                (
                    raw.name,
                    raw.modifiers
                        .into_iter()
                        .map(|m| EffectModifier {
                            func: m.func,
                            operator: m.operator,
                            modified_attribute_id: m.modified_attribute_id,
                            domain: m.domain,
                            modifying_attribute_id: m.modifying_attribute_id,
                            skill_type_id: m.skill_type_id,
                            group_id: m.group_id,
                        })
                        .collect(),
                ),
            );
        }
        let skill_type_ids: Vec<i64> = types
            .values()
            .filter(|t| t.category_id == 16)
            .map(|t| t.type_id)
            .collect();
        let mut per_level_skills: HashMap<i64, Vec<i64>> = HashMap::new();
        for skill_id in &skill_type_ids {
            let Some(skill) = types.get(skill_id) else {
                continue;
            };
            for effect_id in &skill.effect_ids {
                let Some((_, modifiers)) = effects.get(effect_id) else {
                    continue;
                };
                for modifier in modifiers {
                    if modifier.modifying_attribute_id == ATTR_SKILL_LEVEL {
                        per_level_skills
                            .entry(modifier.modified_attribute_id)
                            .or_default()
                            .push(*skill_id);
                    }
                }
            }
        }
        tracing::info!(
            "[FITTING] dogma catalogue loaded types={} effects={} skills={}",
            types.len(),
            effects.len(),
            skill_type_ids.len()
        );
        Ok(Self {
            types,
            effects,
            skill_type_ids,
            per_level_skills,
        })
    }

    pub fn type_by_id(&self, type_id: i64) -> Option<&DogmaType> {
        self.types.get(&type_id)
    }

    /// Base attribute of one type, when both exist.
    pub fn attribute(&self, type_id: i64, attribute_id: i64) -> Option<f64> {
        self.types.get(&type_id)?.attribute(attribute_id)
    }

    /// Scaling skill for one operand attribute carried by
    /// `owner`, when the bundled level chain proves the
    /// operand is per-level (module doc rule).
    fn scaling_skill(&self, owner: &DogmaType, operand_attribute_id: i64) -> Option<i64> {
        let candidates = self.per_level_skills.get(&operand_attribute_id)?;
        if candidates.contains(&owner.type_id) {
            return Some(owner.type_id);
        }
        // Required skills 1 and 2 (attributes 182/183):
        // hull traits scale by the hull skill, subsystem
        // bonuses by the subsystem skill, pirate hulls by
        // either racial skill.
        for required_attribute in [ATTR_REQUIRED_SKILL_1, 183] {
            if let Some(required) = owner.attribute(required_attribute) {
                let required_id = required as i64;
                if required.fract() == 0.0 && candidates.contains(&required_id) {
                    return Some(required_id);
                }
            }
        }
        None
    }

    /// Build one pipeline modifier from one ship-scoped
    /// effect row on `owner`.
    fn build_modifier(
        &self,
        owner: &DogmaType,
        effect_name: &str,
        row: &EffectModifier,
        source: ModifierSource,
        state: ModuleState,
    ) -> Option<DogmaModifier> {
        let operator = match row.operator {
            0 | 4 => DogmaOperator::PostMul,
            2 => DogmaOperator::ModAdd,
            6 => DogmaOperator::PostPercent,
            _ => return None,
        };
        let mut modifier = DogmaModifier::new(
            row.modified_attribute_id,
            operator,
            owner.attribute(row.modifying_attribute_id),
            source,
            owner.type_id,
            effect_name.to_string(),
        );
        modifier.state = state;
        if let Some(skill_id) = self.scaling_skill(owner, row.modifying_attribute_id) {
            modifier.scaling = OperandScaling::PerSkillLevel;
            modifier.skill_type_id = Some(skill_id);
        }
        Some(modifier)
    }

    /// Append every ship-attribute modifier one owner type
    /// contributes, counting ship-scoped rows that cannot
    /// be modeled.
    fn owner_modifiers(
        &self,
        owner: &DogmaType,
        source: ModifierSource,
        state: ModuleState,
        include_overload: bool,
        out: &mut Vec<DogmaModifier>,
        unsupported: &mut Vec<UnsupportedModifier>,
    ) {
        for effect_id in &owner.effect_ids {
            let Some((name, rows)) = self.effects.get(effect_id) else {
                continue;
            };
            let is_overload = name.starts_with("overload");
            if is_overload && !include_overload {
                continue;
            }
            for row in rows {
                if row.domain != "shipID" {
                    continue;
                }
                if row.func != "ItemModifier" {
                    unsupported.push(UnsupportedModifier {
                        attribute_id: row.modified_attribute_id,
                        source_type_id: owner.type_id,
                        label: name.clone(),
                    });
                    continue;
                }
                match self.build_modifier(owner, name, row, source, state) {
                    Some(modifier) => out.push(modifier),
                    None => unsupported.push(UnsupportedModifier {
                        attribute_id: row.modified_attribute_id,
                        source_type_id: owner.type_id,
                        label: name.clone(),
                    }),
                }
            }
        }
    }
}

/// Every ship-attribute modifier one fitting carries, plus
/// the disclosure counts.
#[derive(Debug, Clone, PartialEq)]
pub struct FittingShipModifiers {
    pub modifiers: Vec<DogmaModifier>,
    /// Ship-scoped rows the evaluator cannot model.
    pub unsupported: Vec<UnsupportedModifier>,
    /// Fitted slot-row units with no Dogma type row.
    pub excluded_modules: usize,
}

fn is_slot_flag(flag: &str) -> bool {
    flag.starts_with("LoSlot")
        || flag.starts_with("MedSlot")
        || flag.starts_with("HiSlot")
        || flag.starts_with("RigSlot")
        || flag.starts_with("SubSystemSlot")
}

fn source_for(flag: &str, category_id: i64) -> ModifierSource {
    match category_id {
        20 => ModifierSource::Implant,
        32 => ModifierSource::Subsystem,
        8 => ModifierSource::Charge,
        _ if flag.starts_with("SubSystemSlot") => ModifierSource::Subsystem,
        _ if flag.starts_with("RigSlot") => ModifierSource::Rig,
        _ => ModifierSource::Module,
    }
}

/// Build every ship-attribute modifier for one fitting:
/// hull traits, fitted items, and every trained skill
/// with a positive level under `skills`. `overheated`
/// lists fitted module type ids to evaluate overheated
/// (their `overload*` ship-scoped rows join with
/// [`ModuleState::Overheated`]).
pub fn fitting_ship_modifiers(
    fitting: &CharacterFitting,
    dogma: &DogmaCatalogue,
    skills: &SkillContext,
    overheated: &[i64],
) -> FittingShipModifiers {
    let mut modifiers: Vec<DogmaModifier> = Vec::new();
    let mut unsupported: Vec<UnsupportedModifier> = Vec::new();
    let mut excluded_modules: usize = 0;
    if fitting.ship_type_id > 0 {
        match dogma.type_by_id(fitting.ship_type_id) {
            Some(hull) if hull.category_id == 6 => {
                dogma.owner_modifiers(
                    hull,
                    ModifierSource::HullTrait,
                    ModuleState::Online,
                    false,
                    &mut modifiers,
                    &mut unsupported,
                );
            }
            _ => excluded_modules = excluded_modules.saturating_add(1),
        }
    }
    for item in &fitting.items {
        if item.type_id <= 0 {
            continue;
        }
        let quantity = item.quantity.clamp(0, MAX_EXPANDED_UNITS);
        if quantity == 0 {
            continue;
        }
        let Some(row) = dogma.type_by_id(item.type_id) else {
            if is_slot_flag(&item.flag) {
                excluded_modules = excluded_modules.saturating_add(quantity as usize);
            }
            continue;
        };
        // Slot rows and implant/booster rows (category 20,
        // any flag) are fitting owners; cargo and bay rows
        // never modify the ship.
        if !is_slot_flag(&item.flag) && row.category_id != 20 {
            continue;
        }
        let source = source_for(&item.flag, row.category_id);
        let is_hot = overheated.contains(&item.type_id);
        let state = if is_hot {
            ModuleState::Overheated
        } else {
            ModuleState::Online
        };
        for _ in 0..quantity {
            dogma.owner_modifiers(row, source, state, is_hot, &mut modifiers, &mut unsupported);
        }
    }
    for skill_id in &dogma.skill_type_ids {
        if skills.level(*skill_id) <= 0 {
            continue;
        }
        let Some(skill) = dogma.type_by_id(*skill_id) else {
            continue;
        };
        dogma.owner_modifiers(
            skill,
            ModifierSource::Skill,
            ModuleState::Online,
            false,
            &mut modifiers,
            &mut unsupported,
        );
    }
    FittingShipModifiers {
        modifiers,
        unsupported,
        excluded_modules,
    }
}

/// One evaluated ship attribute plus disclosure counts.
#[derive(Debug, Clone, PartialEq)]
pub struct ShipAttributeEvaluation {
    pub evaluated: EvaluatedAttribute,
    /// Ship-scoped rows on this attribute that could not
    /// be modeled.
    pub unsupported_modifiers: usize,
    /// Fitted slot-row units with no Dogma type row.
    pub excluded_modules: usize,
}

/// Evaluate one ship attribute of one fitting from real
/// bundled Dogma: `base` is the hull's base value for
/// `attribute_id` (callers read it from the hull row).
pub fn evaluate_ship_attribute(
    fitting: &CharacterFitting,
    dogma: &DogmaCatalogue,
    attribute_id: i64,
    base: f64,
    skills: &SkillContext,
    overheated: &[i64],
) -> ShipAttributeEvaluation {
    let built = fitting_ship_modifiers(fitting, dogma, skills, overheated);
    let own: Vec<DogmaModifier> = built
        .modifiers
        .into_iter()
        .filter(|m| m.attribute_id == attribute_id)
        .collect();
    let unsupported_modifiers = built
        .unsupported
        .iter()
        .filter(|u| u.attribute_id == attribute_id)
        .count();
    let evaluated = evaluate_attribute(base, &own, skills);
    tracing::debug!(
        "[FITTING] ship attribute evaluated applied={} unapplied={} unsupported={} excluded={} context={}",
        evaluated.applied,
        evaluated.unapplied_effects.len(),
        unsupported_modifiers,
        built.excluded_modules,
        evaluated.skill_context_tag
    );
    ShipAttributeEvaluation {
        evaluated,
        unsupported_modifiers,
        excluded_modules: built.excluded_modules,
    }
}

/// `LocationRequiredSkillModifier` rows one skill applies
/// to fitted modules requiring it (for example Repair
/// Systems on repairer cycle duration), as pipeline
/// modifiers over `modified_attribute_id`. Operands come
/// from the skill type's own attributes with the same
/// per-level chain rule as ship modifiers.
pub fn skill_location_modifiers(
    dogma: &DogmaCatalogue,
    skill_id: i64,
    modified_attribute_id: i64,
) -> Vec<DogmaModifier> {
    let mut out: Vec<DogmaModifier> = Vec::new();
    let Some(skill) = dogma.type_by_id(skill_id) else {
        return out;
    };
    for effect_id in &skill.effect_ids {
        let Some((name, rows)) = dogma.effects.get(effect_id) else {
            continue;
        };
        for row in rows {
            if row.func != "LocationRequiredSkillModifier"
                || row.domain != "shipID"
                || row.modified_attribute_id != modified_attribute_id
                || row.skill_type_id != Some(skill_id)
            {
                continue;
            }
            if let Some(modifier) =
                dogma.build_modifier(skill, name, row, ModifierSource::Skill, ModuleState::Online)
            {
                out.push(modifier);
            }
        }
    }
    out
}

/// `LocationRequiredSkillModifier` rows carried by the
/// fitting's hull and fitted owners (hull traits such as
/// a battlecruiser armor-repair-amount bonus, subsystem
/// bonuses) for one modified attribute, each paired with
/// the skill a fitted module must require for the row to
/// apply to it. Operands come from the owner type with
/// the standard per-level chain rule (scaling by the
/// owner's required skill). Skill-carried rows are served
/// by [`skill_location_modifiers`].
pub fn fitting_location_skill_modifiers(
    fitting: &CharacterFitting,
    dogma: &DogmaCatalogue,
    modified_attribute_id: i64,
) -> Vec<(i64, DogmaModifier)> {
    let mut out: Vec<(i64, DogmaModifier)> = Vec::new();
    let mut owners: Vec<(&DogmaType, ModifierSource, i64)> = Vec::new();
    if fitting.ship_type_id > 0 {
        if let Some(hull) = dogma.type_by_id(fitting.ship_type_id) {
            if hull.category_id == 6 {
                owners.push((hull, ModifierSource::HullTrait, 1));
            }
        }
    }
    for item in &fitting.items {
        if item.type_id <= 0 {
            continue;
        }
        let quantity = item.quantity.clamp(0, MAX_EXPANDED_UNITS);
        if quantity == 0 {
            continue;
        }
        let Some(row) = dogma.type_by_id(item.type_id) else {
            continue;
        };
        if !is_slot_flag(&item.flag) && row.category_id != 20 {
            continue;
        }
        owners.push((row, source_for(&item.flag, row.category_id), quantity));
    }
    for (owner, source, quantity) in owners {
        for effect_id in &owner.effect_ids {
            let Some((name, rows)) = dogma.effects.get(effect_id) else {
                continue;
            };
            if name.starts_with("overload") {
                continue;
            }
            for row in rows {
                if row.func != "LocationRequiredSkillModifier"
                    || row.domain != "shipID"
                    || row.modified_attribute_id != modified_attribute_id
                {
                    continue;
                }
                let Some(required_skill) = row.skill_type_id else {
                    continue;
                };
                if let Some(modifier) =
                    dogma.build_modifier(owner, name, row, source, ModuleState::Online)
                {
                    for _ in 0..quantity {
                        out.push((required_skill, modifier.clone()));
                    }
                }
            }
        }
    }
    out
}

/// Raw propulsion SDE inputs of one module type:
/// `(speedFactor percent, thrust, mass addition)`.
/// `None` when any of attributes 20/567/796 is absent.
pub fn propulsion_inputs(dogma: &DogmaCatalogue, type_id: i64) -> Option<(f64, f64, f64)> {
    Some((
        dogma.attribute(type_id, ATTR_SPEED_FACTOR)?,
        dogma.attribute(type_id, ATTR_THRUST)?,
        dogma.attribute(type_id, ATTR_MASS_ADDITION)?,
    ))
}

/// Skill- and overheat-scaled `speedFactor` percent of one
/// propulsion module type: Acceleration Control (and any
/// other trained skill) contributes through
/// `LocationGroupModifier` rows whose group matches the
/// module's group; when `overheated`, the module's own
/// `overload*` item-scoped speed rows join. `None` when
/// the type carries no usable speed factor or the
/// evaluation goes non-finite.
pub fn scaled_speed_factor_percent(
    dogma: &DogmaCatalogue,
    module_type_id: i64,
    skills: &SkillContext,
    overheated: bool,
) -> Option<f64> {
    let module = dogma.type_by_id(module_type_id)?;
    let base = module.attribute(ATTR_SPEED_FACTOR)?;
    let mut modifiers: Vec<DogmaModifier> = Vec::new();
    for skill_id in &dogma.skill_type_ids {
        if skills.level(*skill_id) <= 0 {
            continue;
        }
        let Some(skill) = dogma.type_by_id(*skill_id) else {
            continue;
        };
        for effect_id in &skill.effect_ids {
            let Some((name, rows)) = dogma.effects.get(effect_id) else {
                continue;
            };
            for row in rows {
                if row.func == "LocationGroupModifier"
                    && row.domain == "shipID"
                    && row.modified_attribute_id == ATTR_SPEED_FACTOR
                    && row.group_id == Some(module.group_id)
                {
                    if let Some(modifier) = dogma.build_modifier(
                        skill,
                        name,
                        row,
                        ModifierSource::Skill,
                        ModuleState::Online,
                    ) {
                        modifiers.push(modifier);
                    }
                }
            }
        }
    }
    if overheated {
        for effect_id in &module.effect_ids {
            let Some((name, rows)) = dogma.effects.get(effect_id) else {
                continue;
            };
            if !name.starts_with("overload") {
                continue;
            }
            for row in rows {
                if row.func == "ItemModifier"
                    && row.domain == "itemID"
                    && row.modified_attribute_id == ATTR_SPEED_FACTOR
                {
                    if let Some(modifier) = dogma.build_modifier(
                        module,
                        name,
                        row,
                        ModifierSource::Module,
                        ModuleState::Overheated,
                    ) {
                        modifiers.push(modifier);
                    }
                }
            }
        }
    }
    evaluate_attribute(base, &modifiers, skills).value
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

    fn bundled() -> DogmaCatalogue {
        DogmaCatalogue::load_bundled().expect("bundled dogma loads")
    }

    fn velocity(
        dogma: &DogmaCatalogue,
        fit: &CharacterFitting,
        base: f64,
        skills: &SkillContext,
    ) -> ShipAttributeEvaluation {
        evaluate_ship_attribute(fit, dogma, ATTR_MAX_VELOCITY, base, skills, &[])
    }

    #[test]
    fn catalogue_loads_real_types_and_skills() {
        let dogma = bundled();
        let rifter = dogma.type_by_id(587).expect("Rifter row");
        assert_eq!(rifter.category_id, 6);
        assert_close(rifter.attribute(37).expect("velocity"), 365.0, "Rifter vel");
        assert_close(
            dogma.attribute(440, ATTR_THRUST).expect("thrust"),
            1_500_000.0,
            "5MN thrust",
        );
        assert_eq!(dogma.type_by_id(3449).expect("Navigation").category_id, 16);
    }

    #[test]
    fn navigation_skill_scales_velocity_per_level() {
        // Navigation (3449): +5% max velocity per level
        // (attribute 315 = 5.0, level chain through 280).
        let dogma = bundled();
        let fit = fitting(587, vec![]);
        let base = velocity(&dogma, &fit, 365.0, &SkillContext::BaseOnly);
        assert_close(base.evaluated.value.expect("value"), 365.0, "base only");
        let all_five = velocity(&dogma, &fit, 365.0, &SkillContext::AllFive);
        assert_close(
            all_five.evaluated.value.expect("value"),
            456.25,
            "Navigation V x1.25",
        );
        assert_eq!(all_five.evaluated.skill_context_tag, "Assumes All V");
        let trained = velocity(&dogma, &fit, 365.0, &SkillContext::Trained(vec![(3449, 3)]));
        assert_close(
            trained.evaluated.value.expect("value"),
            419.75,
            "Navigation III x1.15",
        );
        // The Rifter's turret hull traits are ship-scoped
        // required-skill rows on other attributes: counted
        // unsupported there, never applied to velocity.
        assert_eq!(base.unsupported_modifiers, 0);
        assert_eq!(base.excluded_modules, 0);
    }

    #[test]
    fn hull_trait_scales_by_hull_skill() {
        // Hoarder (651): +5% velocity per Minmatar Hauler
        // (3341) level (attribute 493 = 5.0); Navigation V
        // multiplies on top at All V: 130 x 1.25 x 1.25.
        let dogma = bundled();
        let fit = fitting(651, vec![]);
        let result = velocity(&dogma, &fit, 130.0, &SkillContext::AllFive);
        assert_close(
            result.evaluated.value.expect("value"),
            203.125,
            "Hoarder trait + Navigation at All V",
        );
        let base = velocity(&dogma, &fit, 130.0, &SkillContext::BaseOnly);
        assert_close(base.evaluated.value.expect("value"), 130.0, "Hoarder base");
    }

    #[test]
    fn fitted_velocity_modules_penalize_and_implants_escape() {
        // Overdrive Injector System II (1236): +12.5%
        // velocity (attribute 1076), stacking-penalized.
        // Eifyr NN-602 implant (3096): +2%, never penalized.
        let dogma = bundled();
        let one = fitting(587, vec![item("LoSlot0", 1, 1236)]);
        let result = velocity(&dogma, &one, 365.0, &SkillContext::BaseOnly);
        assert_close(
            result.evaluated.value.expect("value"),
            410.625,
            "one Overdrive x1.125",
        );
        let two = fitting(
            587,
            vec![item("LoSlot0", 1, 1236), item("LoSlot1", 1, 1236)],
        );
        let s1 = crate::fitting::dogma_pipeline::stacking_effectiveness(1);
        let result = velocity(&dogma, &two, 365.0, &SkillContext::BaseOnly);
        assert_close(
            result.evaluated.value.expect("value"),
            365.0 * 1.125 * (1.0 + 0.125 * s1),
            "two Overdrives stack",
        );
        let implanted = fitting(587, vec![item("ImplantSlot0", 1, 3096)]);
        let result = velocity(&dogma, &implanted, 365.0, &SkillContext::BaseOnly);
        assert_close(
            result.evaluated.value.expect("value"),
            372.3,
            "NN-602 implant x1.02 unpenalized",
        );
    }

    #[test]
    fn loki_subsystem_velocity_scales_by_subsystem_skill() {
        // Loki Propulsion - Intercalated Nanofibers
        // (45620): +5% velocity per Minmatar Propulsion
        // Systems (30554) level; Navigation V on top:
        // 185 x 1.25 x 1.25 = 289.0625 at All V.
        let dogma = bundled();
        let fit = fitting(29990, vec![item("SubSystemSlot0", 1, 45620)]);
        let result = velocity(&dogma, &fit, 185.0, &SkillContext::AllFive);
        assert_close(
            result.evaluated.value.expect("value"),
            289.0625,
            "Loki subsystem + Navigation at All V",
        );
        let base = velocity(&dogma, &fit, 185.0, &SkillContext::BaseOnly);
        assert_close(base.evaluated.value.expect("value"), 185.0, "Loki base");
    }

    #[test]
    fn unknown_fitted_type_is_excluded_with_count() {
        let dogma = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 2, 999999)]);
        let result = velocity(&dogma, &fit, 365.0, &SkillContext::BaseOnly);
        assert_eq!(result.excluded_modules, 2);
        assert_close(result.evaluated.value.expect("value"), 365.0, "unchanged");
    }

    #[test]
    fn repair_systems_duration_modifiers_resolve_per_level() {
        // Repair Systems (3393): -5% repairer cycle per
        // level (attribute 312, chain through 280) on
        // modules requiring the skill.
        let dogma = bundled();
        let modifiers = skill_location_modifiers(&dogma, REPAIR_SYSTEMS_SKILL_ID, ATTR_DURATION);
        assert_eq!(modifiers.len(), 1);
        let evaluated = evaluate_attribute(1.0, &modifiers, &SkillContext::AllFive);
        assert_close(evaluated.value.expect("value"), 0.75, "duration x0.75 at V");
        // Shield booster cycles require Shield Operation,
        // which carries no duration row on attribute 73.
        assert!(skill_location_modifiers(&dogma, 3416, ATTR_DURATION).is_empty());
    }

    #[test]
    fn propulsion_inputs_and_speed_factor_scaling() {
        let dogma = bundled();
        let (factor, thrust, mass) = propulsion_inputs(&dogma, 440).expect("5MN inputs");
        assert_close(factor, 510.0, "speed factor");
        assert_close(thrust, 1_500_000.0, "thrust");
        assert_close(mass, 500_000.0, "mass addition");
        // Acceleration Control (3452): +5% speed factor per
        // level on afterburner/microwarpdrive groups.
        let all_five = scaled_speed_factor_percent(&dogma, 440, &SkillContext::AllFive, false)
            .expect("scaled factor");
        assert_close(all_five, 637.5, "510 x1.25 at All V");
        let base = scaled_speed_factor_percent(&dogma, 440, &SkillContext::BaseOnly, false)
            .expect("base factor");
        assert_close(base, 510.0, "base only factor");
        // Overheated: strictly above the All V online value
        // when the bundled overload operand exists, never
        // below it.
        let hot = scaled_speed_factor_percent(&dogma, 440, &SkillContext::AllFive, true)
            .expect("hot factor");
        assert!(hot >= all_five, "overheat never slows: {hot} vs {all_five}");
    }
}
