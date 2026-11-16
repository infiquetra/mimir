//! Bundled Exploration reference (`assets/sde/exploration.json`): wormhole
//! types, special-class systems, and the 36 system-effect rows.
//!
//! Data is generated once by `scripts/sde/generate_exploration_sde.py`
//! from the pinned CCP SDE 3503375 archive; this module only parses and
//! validates it. Loading performs no network or disk work beyond the
//! bundled `include_str!`. Every parse or validation failure is a typed
//! [`crate::error::AppError`]; the loader never panics and never returns
//! a partial catalogue.
//!
//! Pure deriver ports (`destination_label`, `group_by_code`,
//! `search_types`, security helpers, `effect_for_system`, and
//! `apply_resonance`) live here because they shape the reference data.
//! Rendering formatters live in `src/ui/exploration.rs` (Builder B).

use std::collections::{BTreeMap, HashMap, HashSet};

use serde::Deserialize;

use crate::error::{AppError, AppResult};

pub const CAPITAL_JUMP_THRESHOLD_KG: f64 = 1_000_000_000.0;
pub const STATICS_UNAVAILABLE: &str = "Static information unavailable";
pub const VORTON_EFFECT_IDS: [i64; 4] = [11946, 11947, 11948, 11953];

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum EffectFamily {
    #[default]
    Pulsar,
    BlackHole,
    CataclysmicVariable,
    Magnetar,
    RedGiant,
    WolfRayet,
}

impl EffectFamily {
    pub fn label(&self) -> &'static str {
        match self {
            Self::Pulsar => "Pulsar",
            Self::BlackHole => "Black Hole",
            Self::CataclysmicVariable => "Cataclysmic Variable",
            Self::Magnetar => "Magnetar",
            Self::RedGiant => "Red Giant",
            Self::WolfRayet => "Wolf-Rayet",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SecurityCategory {
    Highsec,
    Lowsec,
    Nullsec,
    Unknown,
    Special,
}

#[derive(Debug, Clone, PartialEq)]
pub enum EffectResolution {
    Applied {
        family: EffectFamily,
        strength: u8,
        beacon_type_id: i64,
    },
    None,
    Unknown,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct SourceFile {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub sha256: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ReferenceManifest {
    #[serde(rename = "sdeBuild", default)]
    pub sde_build: i64,
    #[serde(rename = "datasetSchema", default)]
    pub dataset_schema: i64,
    #[serde(rename = "sourceFiles", default)]
    pub source_files: Vec<SourceFile>,
    #[serde(rename = "rowCounts", default)]
    pub row_counts: BTreeMap<String, usize>,
    #[serde(rename = "generatedBy", default)]
    pub generated_by: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct WormholeType {
    #[serde(rename = "typeId", default)]
    pub type_id: i64,
    #[serde(default)]
    pub code: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub published: bool,
    #[serde(rename = "rawTargetClass", default)]
    pub raw_target_class: Option<i64>,
    #[serde(rename = "rawTargetDistribution", default)]
    pub raw_target_distribution: Option<i64>,
    #[serde(rename = "rawMaxStableTimeMinutes", default)]
    pub raw_max_stable_time_minutes: Option<i64>,
    #[serde(rename = "rawTotalMassKg", default)]
    pub raw_total_mass_kg: Option<f64>,
    #[serde(rename = "rawJumpMassKg", default)]
    pub raw_jump_mass_kg: Option<f64>,
    #[serde(rename = "rawRegenKg", default)]
    pub raw_regen_kg: Option<f64>,
}

impl WormholeType {
    pub fn lifetime_seconds(&self) -> Option<i64> {
        self.raw_max_stable_time_minutes.map(|m| m * 60)
    }

    pub fn destination_label(&self) -> String {
        destination_label(self.raw_target_class)
    }

    pub fn is_capital_size(&self) -> bool {
        is_capital_size(self.raw_jump_mass_kg)
    }
}

#[derive(Debug, Clone)]
pub struct CodeGroup {
    pub code: String,
    pub variants: Vec<usize>,
    pub shared_lifetime_seconds: Option<i64>,
    pub shared_jump_mass_kg: Option<f64>,
    pub jump_varies: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RefSystem {
    #[serde(rename = "systemId", default)]
    pub system_id: i64,
    #[serde(default)]
    pub name: String,
    #[serde(rename = "constellationId", default)]
    pub constellation_id: Option<i64>,
    #[serde(rename = "regionId", default)]
    pub region_id: Option<i64>,
    #[serde(rename = "constellationName", default)]
    pub constellation_name: Option<String>,
    #[serde(rename = "regionName", default)]
    pub region_name: Option<String>,
    #[serde(rename = "rawSecurity", default)]
    pub raw_security: Option<f64>,
    #[serde(rename = "rawClass", default)]
    pub raw_class: Option<i64>,
    #[serde(rename = "inheritedClass", default)]
    pub inherited_class: Option<i64>,
    #[serde(rename = "inheritanceSource", default)]
    pub inheritance_source: Option<String>,
    #[serde(rename = "effectBeaconTypeId", default)]
    pub effect_beacon_type_id: Option<i64>,
    #[serde(rename = "visualSunTypeId", default)]
    pub visual_sun_type_id: Option<i64>,
    #[serde(rename = "effectVerifiedAbsent", default)]
    pub effect_verified_absent: bool,
}

impl RefSystem {
    pub fn category(&self) -> SecurityCategory {
        if is_special_class(self.inherited_class) || is_special_class(self.raw_class) {
            return SecurityCategory::Special;
        }
        classify_security(self.raw_security)
    }

    pub fn security_display(&self) -> String {
        format_security(self.raw_security)
    }

    pub fn security_label(&self) -> String {
        security_label(self)
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct RefModifier {
    #[serde(rename = "attributeId", default)]
    pub attribute_id: i64,
    #[serde(default)]
    pub label: String,
    #[serde(default)]
    pub percent: f64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RefEffect {
    #[serde(default)]
    pub family: EffectFamily,
    #[serde(default)]
    pub strength: u8,
    #[serde(rename = "beaconTypeId", default)]
    pub beacon_type_id: i64,
    #[serde(default)]
    pub modifiers: Vec<RefModifier>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct StaticAssignment {
    #[serde(rename = "systemId", default)]
    pub system_id: i64,
    #[serde(default)]
    pub code: Option<String>,
    #[serde(rename = "typeId", default)]
    pub type_id: Option<i64>,
    #[serde(default)]
    pub meaning: String,
    #[serde(default)]
    pub source: String,
    #[serde(default)]
    pub confidence: String,
}

#[derive(Debug, Clone, Deserialize)]
struct ExplorationFile {
    #[serde(default)]
    manifest: Option<ReferenceManifest>,
    #[serde(default)]
    types: Vec<WormholeType>,
    #[serde(default)]
    systems: Vec<RefSystem>,
    #[serde(default)]
    effects: Vec<RefEffect>,
    #[serde(default)]
    statics: Vec<StaticAssignment>,
}

/// In-memory Exploration reference with lookup indexes.
#[derive(Debug, Clone)]
pub struct ExplorationRef {
    pub manifest: ReferenceManifest,
    pub types: Vec<WormholeType>,
    pub systems: Vec<RefSystem>,
    pub effects: Vec<RefEffect>,
    pub statics: Vec<StaticAssignment>,
    type_by_id: HashMap<i64, usize>,
    system_by_id: HashMap<i64, usize>,
    effect_by_beacon: HashMap<i64, usize>,
    codes: HashMap<String, Vec<usize>>,
}

impl ExplorationRef {
    pub fn load_bundled() -> AppResult<Self> {
        tracing::debug!("[EXPLORE] loading bundled exploration reference");
        Self::from_json(include_str!("../../assets/sde/exploration.json"))
    }

    pub fn from_json(json: &str) -> AppResult<Self> {
        let file: ExplorationFile = serde_json::from_str(json)?;
        let manifest = file.manifest.ok_or_else(|| {
            AppError::Message("[EXPLORE] exploration manifest is missing".to_string())
        })?;
        let mut type_by_id: HashMap<i64, usize> = HashMap::new();
        for (i, t) in file.types.iter().enumerate() {
            if type_by_id.contains_key(&t.type_id) {
                return Err(AppError::Message(
                    "[EXPLORE] duplicate wormhole type id".to_string(),
                ));
            }
            type_by_id.insert(t.type_id, i);
        }
        let mut system_by_id: HashMap<i64, usize> = HashMap::new();
        for (i, s) in file.systems.iter().enumerate() {
            if system_by_id.contains_key(&s.system_id) {
                return Err(AppError::Message(
                    "[EXPLORE] duplicate system id".to_string(),
                ));
            }
            system_by_id.insert(s.system_id, i);
        }
        let mut effect_by_beacon: HashMap<i64, usize> = HashMap::new();
        for (i, e) in file.effects.iter().enumerate() {
            if effect_by_beacon.contains_key(&e.beacon_type_id) {
                return Err(AppError::Message(
                    "[EXPLORE] duplicate effect beacon id".to_string(),
                ));
            }
            effect_by_beacon.insert(e.beacon_type_id, i);
        }
        let mut codes: HashMap<String, Vec<usize>> = HashMap::new();
        for (i, t) in file.types.iter().enumerate() {
            codes.entry(t.code.clone()).or_default().push(i);
        }
        let reference = Self {
            manifest,
            types: file.types,
            systems: file.systems,
            effects: file.effects,
            statics: file.statics,
            type_by_id,
            system_by_id,
            effect_by_beacon,
            codes,
        };
        reference.validate()?;
        tracing::info!(
            "[EXPLORE] exploration reference loaded types={} systems={} effects={} statics={}",
            reference.types.len(),
            reference.systems.len(),
            reference.effects.len(),
            reference.statics.len()
        );
        Ok(reference)
    }

    fn validate(&self) -> AppResult<()> {
        if self.manifest.row_counts.get("types") != Some(&self.types.len()) {
            return Err(AppError::Message(
                "[EXPLORE] manifest rowCounts.types mismatches parsed types".to_string(),
            ));
        }
        if self.manifest.row_counts.get("systems") != Some(&self.systems.len()) {
            return Err(AppError::Message(
                "[EXPLORE] manifest rowCounts.systems mismatches parsed systems".to_string(),
            ));
        }
        if self.manifest.row_counts.get("effects") != Some(&self.effects.len()) {
            return Err(AppError::Message(
                "[EXPLORE] manifest rowCounts.effects mismatches parsed effects".to_string(),
            ));
        }
        if self.manifest.row_counts.get("statics") != Some(&self.statics.len()) {
            return Err(AppError::Message(
                "[EXPLORE] manifest rowCounts.statics mismatches parsed statics".to_string(),
            ));
        }
        if self.effects.len() != 36 {
            return Err(AppError::Message(format!(
                "[EXPLORE] effects must be 36 rows, got {}",
                self.effects.len()
            )));
        }
        let mut pairs: HashSet<(String, u8)> = HashSet::new();
        for e in &self.effects {
            if !(1..=6).contains(&e.strength) {
                return Err(AppError::Message(
                    "[EXPLORE] effect strength outside 1..=6".to_string(),
                ));
            }
            let key = (
                match e.family {
                    EffectFamily::Pulsar => "pulsar",
                    EffectFamily::BlackHole => "blackHole",
                    EffectFamily::CataclysmicVariable => "cataclysmicVariable",
                    EffectFamily::Magnetar => "magnetar",
                    EffectFamily::RedGiant => "redGiant",
                    EffectFamily::WolfRayet => "wolfRayet",
                }
                .to_string(),
                e.strength,
            );
            if !pairs.insert(key) {
                return Err(AppError::Message(
                    "[EXPLORE] duplicate (family, strength) effect row".to_string(),
                ));
            }
        }
        for t in &self.types {
            if t.code.is_empty() || t.name.is_empty() {
                return Err(AppError::Message(
                    "[EXPLORE] wormhole row has empty code/name".to_string(),
                ));
            }
            for v in [t.raw_total_mass_kg, t.raw_jump_mass_kg, t.raw_regen_kg]
                .into_iter()
                .flatten()
            {
                if !v.is_finite() || v < 0.0 {
                    return Err(AppError::Message(
                        "[EXPLORE] wormhole mass is negative or non-finite".to_string(),
                    ));
                }
            }
            if let Some(m) = t.raw_max_stable_time_minutes {
                if m < 0 {
                    return Err(AppError::Message(
                        "[EXPLORE] wormhole lifetime minutes is negative".to_string(),
                    ));
                }
            }
        }
        for s in &self.systems {
            if s.name.is_empty() {
                return Err(AppError::Message(
                    "[EXPLORE] system row has empty name".to_string(),
                ));
            }
        }
        Ok(())
    }

    pub fn type_by_id(&self, type_id: i64) -> Option<&WormholeType> {
        self.types.get(*self.type_by_id.get(&type_id)?)
    }

    pub fn system_by_id(&self, system_id: i64) -> Option<&RefSystem> {
        self.systems.get(*self.system_by_id.get(&system_id)?)
    }

    pub fn effect_by_beacon(&self, beacon_type_id: i64) -> Option<&RefEffect> {
        self.effects
            .get(*self.effect_by_beacon.get(&beacon_type_id)?)
    }

    pub fn variants_for_code(&self, code: &str) -> Option<&[usize]> {
        self.codes.get(code).map(Vec::as_slice)
    }
}

/// Deriver port: `WormholeTypeReference.destinationLabel`.
pub fn destination_label(raw_target_class: Option<i64>) -> String {
    let Some(target) = raw_target_class else {
        return "Unknown".to_string();
    };
    match target {
        7 => "Highsec".to_string(),
        8 => "Lowsec".to_string(),
        9 => "Nullsec".to_string(),
        12 => "Thera".to_string(),
        25 => "Pochven".to_string(),
        -1 => "Varies".to_string(),
        13 => "Shattered".to_string(),
        1..=6 => format!("C{target}"),
        14..=18 => "Drifter".to_string(),
        _ => "Unknown".to_string(),
    }
}

pub fn is_capital_size(raw_jump_mass_kg: Option<f64>) -> bool {
    raw_jump_mass_kg.is_some_and(|m| m >= CAPITAL_JUMP_THRESHOLD_KG)
}

pub fn is_special_class(raw_class: Option<i64>) -> bool {
    match raw_class {
        Some(c) if (1..=6).contains(&c) => true,
        Some(12) | Some(13) | Some(25) => true,
        Some(c) if (14..=18).contains(&c) => true,
        _ => false,
    }
}

pub fn classify_security(x: Option<f64>) -> SecurityCategory {
    match x {
        None => SecurityCategory::Unknown,
        Some(v) if v >= 0.45 => SecurityCategory::Highsec,
        Some(v) if v > 0.0 => SecurityCategory::Lowsec,
        Some(_) => SecurityCategory::Nullsec,
    }
}

pub fn format_security(x: Option<f64>) -> String {
    match x {
        None => "Unknown".to_string(),
        Some(v) if v <= 0.0 => "0.0".to_string(),
        Some(v) if v < 0.05 => "0.1".to_string(),
        Some(v) => ((v * 10.0).round() / 10.0).to_string(),
    }
}

fn effective_class(system: &RefSystem) -> Option<i64> {
    if is_special_class(system.inherited_class) {
        return system.inherited_class;
    }
    if is_special_class(system.raw_class) {
        return system.raw_class;
    }
    system.inherited_class.or(system.raw_class)
}

pub fn security_label(system: &RefSystem) -> String {
    match system.category() {
        SecurityCategory::Highsec => "Highsec".to_string(),
        SecurityCategory::Lowsec => "Lowsec".to_string(),
        SecurityCategory::Nullsec => "Nullsec".to_string(),
        SecurityCategory::Unknown => "Unknown".to_string(),
        SecurityCategory::Special => match effective_class(system) {
            Some(12) => "Thera".to_string(),
            Some(25) => "Pochven".to_string(),
            Some(13) => "Shattered".to_string(),
            Some(c) if (1..=6).contains(&c) => "J-space".to_string(),
            _ => "Special".to_string(),
        },
    }
}

pub fn far_side_category(raw_target_class: Option<i64>) -> SecurityCategory {
    match raw_target_class {
        Some(7) => SecurityCategory::Highsec,
        Some(8) => SecurityCategory::Lowsec,
        Some(9) => SecurityCategory::Nullsec,
        Some(12) | Some(13) | Some(25) => SecurityCategory::Special,
        Some(c) if (1..=6).contains(&c) => SecurityCategory::Special,
        Some(c) if (14..=18).contains(&c) => SecurityCategory::Special,
        _ => SecurityCategory::Unknown,
    }
}

pub fn effects_scopes(family: EffectFamily) -> Vec<i64> {
    if family == EffectFamily::WolfRayet {
        VORTON_EFFECT_IDS.to_vec()
    } else {
        Vec::new()
    }
}

pub fn apply_resonance(old_resist: f64, percent_increase: f64) -> f64 {
    1.0 - (1.0 - old_resist) * (1.0 + percent_increase / 100.0)
}

pub fn effect_for_system(system: &RefSystem, reference: &ExplorationRef) -> EffectResolution {
    if system.effect_beacon_type_id.is_none() && system.visual_sun_type_id.is_none() {
        if system.effect_verified_absent {
            return EffectResolution::None;
        }
        return EffectResolution::Unknown;
    }
    let candidate = system.effect_beacon_type_id.or(system.visual_sun_type_id);
    match candidate {
        None => {
            if system.effect_verified_absent {
                EffectResolution::None
            } else {
                EffectResolution::Unknown
            }
        }
        Some(id) => match reference.effect_by_beacon(id) {
            Some(effect) => EffectResolution::Applied {
                family: effect.family,
                strength: effect.strength,
                beacon_type_id: id,
            },
            None => EffectResolution::Unknown,
        },
    }
}

pub fn statics_label(reference: &ExplorationRef, system_id: i64) -> String {
    let codes: Vec<String> = reference
        .statics
        .iter()
        .filter(|a| a.system_id == system_id)
        .filter_map(|a| a.code.clone())
        .filter(|c| !c.is_empty())
        .collect();
    if codes.is_empty() {
        return STATICS_UNAVAILABLE.to_string();
    }
    codes.join(", ")
}

fn code_group_from_variants(
    code: String,
    catalog: &[WormholeType],
    variants: &[usize],
) -> CodeGroup {
    let lifetimes: Vec<Option<i64>> = variants
        .iter()
        .filter_map(|&i| catalog.get(i))
        .map(|t| t.lifetime_seconds())
        .collect();
    let jumps: Vec<Option<f64>> = variants
        .iter()
        .filter_map(|&i| catalog.get(i))
        .map(|t| t.raw_jump_mass_kg)
        .collect();
    let first_lifetime = lifetimes.first().copied().unwrap_or(None);
    let shared_lifetime = if lifetimes.iter().all(|v| *v == first_lifetime) && !lifetimes.is_empty()
    {
        first_lifetime
    } else {
        None
    };
    let first_jump = jumps.first().copied().unwrap_or(None);
    let jump_varies = jumps.iter().any(|v| *v != first_jump);
    let shared_jump = if jump_varies { None } else { first_jump };
    CodeGroup {
        code,
        variants: variants.to_vec(),
        shared_lifetime_seconds: shared_lifetime,
        shared_jump_mass_kg: shared_jump,
        jump_varies,
    }
}

pub fn group_by_code(catalog: &[WormholeType]) -> Vec<CodeGroup> {
    let mut by_code: HashMap<String, Vec<usize>> = HashMap::new();
    for (i, t) in catalog.iter().enumerate() {
        by_code.entry(t.code.clone()).or_default().push(i);
    }
    let mut groups: Vec<CodeGroup> = by_code
        .into_iter()
        .map(|(code, variants)| code_group_from_variants(code, catalog, &variants))
        .collect();
    groups.sort_by(|a, b| a.code.cmp(&b.code));
    groups
}

#[derive(Debug, Clone, Default)]
pub struct TypeSearchQuery {
    pub text: String,
    pub destination_label: Option<String>,
    pub raw_target_class: Option<i64>,
    pub capital_only: bool,
    pub min_jump_mass_kg: Option<f64>,
    pub require_static: bool,
}

fn type_matches(t: &WormholeType, query: &TypeSearchQuery) -> bool {
    let needle = query.text.trim().to_lowercase();
    if !needle.is_empty() {
        let haystacks = [t.code.clone(), t.name.clone(), t.destination_label()];
        let ok = haystacks.iter().any(|v| v.to_lowercase().contains(&needle));
        if !ok {
            return false;
        }
    }
    if let Some(label) = &query.destination_label {
        if t.destination_label() != *label {
            return false;
        }
    }
    if let Some(class) = query.raw_target_class {
        if t.raw_target_class != Some(class) {
            return false;
        }
    }
    if let Some(min) = query.min_jump_mass_kg {
        match t.raw_jump_mass_kg {
            Some(m) if m >= min => {}
            _ => return false,
        }
    }
    if query.capital_only && !t.is_capital_size() {
        return false;
    }
    if query.require_static {
        return false;
    }
    true
}

fn text_rank(group: &CodeGroup, catalog: &[WormholeType], needle: &str) -> u8 {
    let lower = needle.to_lowercase();
    let mut best: u8 = 3;
    for &i in &group.variants {
        let Some(t) = catalog.get(i) else {
            continue;
        };
        for field in [t.code.clone(), t.name.clone(), t.destination_label()] {
            let value = field.to_lowercase();
            if value == lower {
                best = 0;
            } else if value.starts_with(&lower) && best > 1 {
                best = 1;
            } else if value.contains(&lower) && best > 2 {
                best = 2;
            }
        }
    }
    best
}

pub fn search_types(catalog: &[WormholeType], query: &TypeSearchQuery) -> Vec<CodeGroup> {
    let mut hits: Vec<CodeGroup> = Vec::new();
    for group in group_by_code(catalog) {
        let matching: Vec<usize> = group
            .variants
            .iter()
            .copied()
            .filter(|&i| catalog.get(i).is_some_and(|t| type_matches(t, query)))
            .collect();
        if matching.is_empty() {
            continue;
        }
        hits.push(code_group_from_variants(
            group.code.clone(),
            catalog,
            &matching,
        ));
    }
    let needle = query.text.trim();
    if needle.is_empty() {
        return hits;
    }
    hits.sort_by(|a, b| {
        let ra = text_rank(a, catalog, needle);
        let rb = text_rank(b, catalog, needle);
        ra.cmp(&rb).then_with(|| a.code.cmp(&b.code))
    });
    hits
}

#[cfg(test)]
mod tests {
    use super::*;

    #[allow(clippy::too_many_arguments)]
    fn wormhole(
        type_id: i64,
        code: &str,
        name: &str,
        class: Option<i64>,
        minutes: Option<i64>,
        total: Option<f64>,
        jump: Option<f64>,
        regen: Option<f64>,
    ) -> WormholeType {
        WormholeType {
            type_id,
            code: code.to_string(),
            name: name.to_string(),
            published: true,
            raw_target_class: class,
            raw_target_distribution: None,
            raw_max_stable_time_minutes: minutes,
            raw_total_mass_kg: total,
            raw_jump_mass_kg: jump,
            raw_regen_kg: regen,
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn system(
        id: i64,
        name: &str,
        raw_class: Option<i64>,
        inherited: Option<i64>,
        security: Option<f64>,
        beacon: Option<i64>,
        visual: Option<i64>,
        verified_absent: bool,
    ) -> RefSystem {
        RefSystem {
            system_id: id,
            name: name.to_string(),
            constellation_id: None,
            region_id: None,
            constellation_name: Some("C".to_string()),
            region_name: Some("R".to_string()),
            raw_security: security,
            raw_class,
            inherited_class: inherited,
            inheritance_source: Some("constellation".to_string()),
            effect_beacon_type_id: beacon,
            visual_sun_type_id: visual,
            effect_verified_absent: verified_absent,
        }
    }

    fn minimal_valid_json() -> String {
        serde_json::json!({
            "manifest": {
                "sdeBuild": 3503375,
                "datasetSchema": 1,
                "sourceFiles": [{"name": "types.jsonl", "sha256": "x"}],
                "rowCounts": {"types": 1, "systems": 1, "effects": 36, "statics": 0},
                "generatedBy": "test"
            },
            "types": [{
                "typeId": 30677,
                "code": "B274",
                "name": "Wormhole B274",
                "published": true,
                "rawTargetClass": 7,
                "rawMaxStableTimeMinutes": 1440,
                "rawTotalMassKg": 2000000000.0,
                "rawJumpMassKg": 375000000.0,
                "rawRegenKg": 0.0
            }],
            "systems": [{
                "systemId": 31000005,
                "name": "Thera",
                "constellationName": "G-C00324",
                "regionName": "G-R00031",
                "rawSecurity": -0.99,
                "inheritedClass": 12,
                "inheritanceSource": "constellation",
                "effectVerifiedAbsent": false
            }],
            "effects": (1..=6).flat_map(|s| {
                ["pulsar", "blackHole", "cataclysmicVariable", "magnetar", "redGiant", "wolfRayet"]
                    .iter()
                    .map(move |fam| {
                        serde_json::json!({
                            "family": fam,
                            "strength": s,
                            "beaconTypeId": 90000 + s * 100 + fam.len() as i64,
                            "modifiers": []
                        })
                    })
            }).collect::<Vec<_>>(),
            "statics": []
        })
        .to_string()
    }

    #[test]
    fn bundled_exploration_loads_and_matches_manifest() {
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        assert_eq!(reference.manifest.sde_build, 3503375);
        assert_eq!(
            reference.manifest.row_counts.get("types"),
            Some(&reference.types.len())
        );
        assert_eq!(
            reference.manifest.row_counts.get("systems"),
            Some(&reference.systems.len())
        );
        assert_eq!(
            reference.manifest.row_counts.get("effects"),
            Some(&reference.effects.len())
        );
        assert_eq!(
            reference.manifest.row_counts.get("statics"),
            Some(&reference.statics.len())
        );
        assert!(!reference.manifest.source_files.is_empty());
        for sf in &reference.manifest.source_files {
            assert_eq!(sf.sha256.len(), 64);
        }
        assert_eq!(reference.statics.len(), 0);
    }

    #[test]
    fn golden_invariants_from_pinned_sde() {
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        // Effects: exactly 36 unique (family, strength) with the
        // section 3.2 beacon table.
        assert_eq!(reference.effects.len(), 36);
        let expected: &[(EffectFamily, u8, i64)] = &[
            (EffectFamily::Pulsar, 1, 30844),
            (EffectFamily::Pulsar, 2, 30865),
            (EffectFamily::Pulsar, 3, 30866),
            (EffectFamily::Pulsar, 4, 30867),
            (EffectFamily::Pulsar, 5, 30868),
            (EffectFamily::Pulsar, 6, 30869),
            (EffectFamily::BlackHole, 1, 30845),
            (EffectFamily::BlackHole, 2, 30850),
            (EffectFamily::BlackHole, 3, 30851),
            (EffectFamily::BlackHole, 4, 30852),
            (EffectFamily::BlackHole, 5, 30853),
            (EffectFamily::BlackHole, 6, 30854),
            (EffectFamily::CataclysmicVariable, 1, 30846),
            (EffectFamily::CataclysmicVariable, 2, 30880),
            (EffectFamily::CataclysmicVariable, 3, 30881),
            (EffectFamily::CataclysmicVariable, 4, 30884),
            (EffectFamily::CataclysmicVariable, 5, 30883),
            (EffectFamily::CataclysmicVariable, 6, 30882),
            (EffectFamily::Magnetar, 1, 30847),
            (EffectFamily::Magnetar, 2, 30860),
            (EffectFamily::Magnetar, 3, 30861),
            (EffectFamily::Magnetar, 4, 30862),
            (EffectFamily::Magnetar, 5, 30863),
            (EffectFamily::Magnetar, 6, 30864),
            (EffectFamily::RedGiant, 1, 30848),
            (EffectFamily::RedGiant, 2, 30870),
            (EffectFamily::RedGiant, 3, 30871),
            (EffectFamily::RedGiant, 4, 30872),
            (EffectFamily::RedGiant, 5, 30873),
            (EffectFamily::RedGiant, 6, 30874),
            (EffectFamily::WolfRayet, 1, 30849),
            (EffectFamily::WolfRayet, 2, 30875),
            (EffectFamily::WolfRayet, 3, 30876),
            (EffectFamily::WolfRayet, 4, 30877),
            (EffectFamily::WolfRayet, 5, 30878),
            (EffectFamily::WolfRayet, 6, 30879),
        ];
        for (family, strength, beacon) in expected {
            let found = reference
                .effects
                .iter()
                .find(|e| e.family == *family && e.strength == *strength);
            assert_eq!(
                found.map(|e| e.beacon_type_id),
                Some(*beacon),
                "beacon for {:?} {strength}",
                family
            );
        }
        // C729: Product section 4.1 states 28 variants, but pinned
        // build 3503375 contains 27 (counted in types.jsonl and via
        // dogma 1381==-1 on 2026-11-16).  Never invent a 28th row;
        // assert the archive truth.
        let c729 = reference.variants_for_code("C729").expect("C729 present");
        assert_eq!(c729.len(), 27);
        // K162: present, unpublished, all dogma null.
        let k162 = reference
            .types
            .iter()
            .find(|t| t.code == "K162")
            .expect("K162 present");
        assert_eq!(k162.type_id, 30831);
        assert_eq!(k162.raw_target_class, None);
        assert_eq!(k162.lifetime_seconds(), None);
        assert_eq!(k162.raw_jump_mass_kg, None);
        assert_eq!(k162.raw_total_mass_kg, None);
        assert_eq!(k162.raw_regen_kg, None);
        // B274 golden values.
        let b274 = reference.type_by_id(30677).expect("B274");
        assert_eq!(b274.lifetime_seconds(), Some(86400));
        assert_eq!(b274.raw_total_mass_kg, Some(2_000_000_000.0));
        assert_eq!(b274.raw_jump_mass_kg, Some(375_000_000.0));
        assert_eq!(b274.destination_label(), "Highsec");
        // I078 golden values.
        let i078 = reference.type_by_id(92287).expect("I078");
        assert_eq!(i078.lifetime_seconds(), Some(16200));
        assert_eq!(i078.destination_label(), "Pochven");
        // Class-13 systems: exactly 25, all Wolf-Rayet 6.
        let class13: Vec<_> = reference
            .systems
            .iter()
            .filter(|s| s.inherited_class == Some(13))
            .collect();
        assert_eq!(class13.len(), 25);
        for s in &class13 {
            assert_eq!(s.effect_beacon_type_id, Some(30879));
            match effect_for_system(s, &reference) {
                EffectResolution::Applied {
                    family, strength, ..
                } => {
                    assert_eq!(family, EffectFamily::WolfRayet);
                    assert_eq!(strength, 6);
                }
                other => panic!("class-13 not applied: {other:?}"),
            }
        }
        // Beacon-beats-visual regressions keyed by name.
        let j005926 = reference
            .systems
            .iter()
            .find(|s| s.name == "J005926")
            .expect("J005926");
        match effect_for_system(j005926, &reference) {
            EffectResolution::Applied {
                family,
                strength,
                beacon_type_id,
            } => {
                assert_eq!(family, EffectFamily::RedGiant);
                assert_eq!(strength, 1);
                assert_eq!(beacon_type_id, 30848);
            }
            other => panic!("J005926 not Red Giant 1: {other:?}"),
        }
        let j010569 = reference
            .systems
            .iter()
            .find(|s| s.name == "J010569")
            .expect("J010569");
        match effect_for_system(j010569, &reference) {
            EffectResolution::Applied {
                family,
                strength,
                beacon_type_id,
            } => {
                assert_eq!(family, EffectFamily::WolfRayet);
                assert_eq!(strength, 1);
                assert_eq!(beacon_type_id, 30849);
            }
            other => panic!("J010569 not Wolf-Rayet 1: {other:?}"),
        }
        // F2 oracle vector ends.
        let pulsar_s6 = reference
            .effects
            .iter()
            .find(|e| e.family == EffectFamily::Pulsar && e.strength == 6)
            .expect("pulsar 6");
        let cap = pulsar_s6
            .modifiers
            .iter()
            .find(|m| m.attribute_id == 1500)
            .expect("pulsar cap");
        assert_eq!(cap.percent, -50.0);
        let wr_s6 = reference
            .effects
            .iter()
            .find(|e| e.family == EffectFamily::WolfRayet && e.strength == 6)
            .expect("wolf 6");
        let small = wr_s6
            .modifiers
            .iter()
            .find(|m| m.attribute_id == 1493)
            .expect("wolf small");
        assert_eq!(small.percent, 200.0);
        // Golden spot values per table (types/systems/effects/statics).
        assert_eq!(reference.type_by_id(30677).expect("B274").code, "B274");
        assert_eq!(
            reference
                .systems
                .iter()
                .find(|s| s.name == "Thera")
                .expect("Thera")
                .security_label(),
            "Thera"
        );
        assert_eq!(
            reference
                .effects
                .iter()
                .find(|e| e.beacon_type_id == 30869)
                .expect("pulsar 6 by beacon")
                .strength,
            6
        );
        assert_eq!(
            statics_label(&reference, 31000005),
            "Static information unavailable"
        );
    }

    #[test]
    fn malformed_and_truncated_json_is_an_error_not_a_panic() {
        assert!(ExplorationRef::from_json("{not json").is_err());
        // Manifest claims more rows than arrays hold.
        let valid = minimal_valid_json();
        let truncated = valid.replace("\"types\": 1", "\"types\": 2");
        assert!(ExplorationRef::from_json(&truncated).is_err());
        // 35 effects.
        let mut value: serde_json::Value = serde_json::from_str(&valid).expect("minimal parses");
        value["effects"] = serde_json::json!(value["effects"].as_array().expect("array")[..35]);
        assert!(ExplorationRef::from_json(&value.to_string()).is_err());
        // Duplicate type ids.
        let mut dup: serde_json::Value = serde_json::from_str(&valid).expect("minimal parses");
        dup["types"] = serde_json::json!([dup["types"][0].clone(), dup["types"][0].clone()]);
        dup["manifest"]["rowCounts"]["types"] = serde_json::json!(2);
        assert!(ExplorationRef::from_json(&dup.to_string()).is_err());
        // Negative mass.
        let mut neg: serde_json::Value = serde_json::from_str(&valid).expect("minimal parses");
        neg["types"][0]["rawJumpMassKg"] = serde_json::json!(-5.0);
        assert!(ExplorationRef::from_json(&neg.to_string()).is_err());
        // Missing manifest.
        let mut no_manifest: serde_json::Value =
            serde_json::from_str(&valid).expect("minimal parses");
        no_manifest.as_object_mut().expect("obj").remove("manifest");
        assert!(ExplorationRef::from_json(&no_manifest.to_string()).is_err());
    }

    #[test]
    fn f1_minutes_to_seconds_and_capital_boundary() {
        let b274 = wormhole(
            30677,
            "B274",
            "Wormhole B274",
            Some(7),
            Some(1440),
            Some(2e9),
            Some(375e6),
            Some(0.0),
        );
        assert_eq!(b274.lifetime_seconds(), Some(86400));
        assert_eq!(b274.destination_label(), "Highsec");
        assert!(!b274.is_capital_size());
        let q001 = wormhole(
            95001,
            "Q001",
            "Synthetic Q001",
            Some(1),
            None,
            None,
            Some(1_000_000_000.0),
            None,
        );
        assert!(q001.is_capital_size());
        let q002 = wormhole(
            95002,
            "Q002",
            "Synthetic Q002",
            Some(1),
            None,
            None,
            Some(999_999_999.0),
            None,
        );
        assert!(!q002.is_capital_size());
        let k162 = wormhole(30831, "K162", "Wormhole K162", None, None, None, None, None);
        assert_eq!(k162.lifetime_seconds(), None);
        assert_eq!(k162.destination_label(), "Unknown");
        assert!(!k162.is_capital_size());
    }

    #[test]
    fn f1_grouping_agreeing_and_conflicting() {
        let c1 = wormhole(
            94001,
            "C729",
            "Wormhole C729 V1",
            Some(-1),
            Some(720),
            Some(1e9),
            Some(410e6),
            Some(0.0),
        );
        let c2_agree = wormhole(
            94002,
            "C729",
            "Wormhole C729 V2",
            Some(-1),
            Some(720),
            Some(1e9),
            Some(410e6),
            Some(0.0),
        );
        let catalog = vec![c1.clone(), c2_agree.clone()];
        let groups = group_by_code(&catalog);
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].variants.len(), 2);
        assert_eq!(groups[0].shared_lifetime_seconds, Some(43200));
        assert_eq!(groups[0].shared_jump_mass_kg, Some(410_000_000.0));
        assert!(!groups[0].jump_varies);
        let c2_conflict = wormhole(
            94002,
            "C729",
            "Wormhole C729 V2",
            Some(-1),
            Some(720),
            Some(1e9),
            Some(420e6),
            Some(0.0),
        );
        let catalog2 = vec![c1, c2_conflict];
        let groups2 = group_by_code(&catalog2);
        assert!(groups2[0].jump_varies);
        assert_eq!(groups2[0].shared_jump_mass_kg, None);
        assert_eq!(groups2[0].shared_lifetime_seconds, Some(43200));
    }

    #[test]
    fn f1_search_trim_rank_and_same_variant_and() {
        let b274 = wormhole(
            30677,
            "B274",
            "Wormhole B274",
            Some(7),
            Some(1440),
            Some(2e9),
            Some(375e6),
            Some(0.0),
        );
        let k162 = wormhole(30831, "K162", "Wormhole K162", None, None, None, None, None);
        let i078 = wormhole(
            92287,
            "I078",
            "Wormhole I078",
            Some(25),
            Some(270),
            Some(100e6),
            Some(62e6),
            Some(0.0),
        );
        let q001 = wormhole(
            95001,
            "Q001",
            "Synthetic Q001",
            Some(1),
            None,
            None,
            Some(1e9),
            None,
        );
        let q002 = wormhole(
            95002,
            "Q002",
            "Synthetic Q002",
            Some(1),
            None,
            None,
            Some(999_999_999.0),
            None,
        );
        let catalog = vec![b274, k162, i078, q001, q002];
        let padded = search_types(
            &catalog,
            &TypeSearchQuery {
                text: " b274 ".to_string(),
                ..Default::default()
            },
        );
        assert_eq!(padded.len(), 1);
        assert_eq!(padded[0].code, "B274");
        let highsec = search_types(
            &catalog,
            &TypeSearchQuery {
                text: "highsec".to_string(),
                destination_label: Some("Highsec".to_string()),
                ..Default::default()
            },
        );
        assert_eq!(highsec.len(), 1);
        assert_eq!(highsec[0].code, "B274");
        let capital_c1 = search_types(
            &catalog,
            &TypeSearchQuery {
                raw_target_class: Some(1),
                capital_only: true,
                ..Default::default()
            },
        );
        assert_eq!(capital_c1.len(), 1);
        assert_eq!(capital_c1[0].code, "Q001");
        let k162_mass = search_types(
            &catalog,
            &TypeSearchQuery {
                text: "K162".to_string(),
                min_jump_mass_kg: Some(1.0),
                ..Default::default()
            },
        );
        assert!(k162_mass.is_empty());
        // Destination and mass AND must match the same C729 variant.
        let c1 = wormhole(
            94001,
            "C729",
            "Wormhole C729 V1",
            Some(-1),
            Some(720),
            Some(1e9),
            Some(410e6),
            Some(0.0),
        );
        let c2 = wormhole(
            94002,
            "C729",
            "Wormhole C729 V2",
            Some(-1),
            Some(720),
            Some(1e9),
            Some(420e6),
            Some(0.0),
        );
        let c729_catalog = vec![c1, c2];
        let hits = search_types(
            &c729_catalog,
            &TypeSearchQuery {
                raw_target_class: Some(-1),
                min_jump_mass_kg: Some(415_000_000.0),
                ..Default::default()
            },
        );
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].variants.len(), 1);
        let only = &c729_catalog[hits[0].variants[0]];
        assert_eq!(only.type_id, 94002);
    }

    #[test]
    fn f2_security_table_and_special_category() {
        let rows: Vec<(Option<f64>, SecurityCategory, &str)> = vec![
            (Some(-0.01), SecurityCategory::Nullsec, "0.0"),
            (Some(0.0), SecurityCategory::Nullsec, "0.0"),
            (Some(0.0001), SecurityCategory::Lowsec, "0.1"),
            (Some(0.049), SecurityCategory::Lowsec, "0.1"),
            (Some(0.05), SecurityCategory::Lowsec, "0.1"),
            (Some(0.449999), SecurityCategory::Lowsec, "0.4"),
            (Some(0.45), SecurityCategory::Highsec, "0.5"),
            (None, SecurityCategory::Unknown, "Unknown"),
        ];
        for (raw, category, display) in rows {
            assert_eq!(classify_security(raw), category, "raw {raw:?}");
            assert_eq!(format_security(raw), display, "raw {raw:?}");
        }
        let thera = system(
            31000005,
            "Thera",
            Some(12),
            Some(12),
            Some(-0.99),
            None,
            None,
            false,
        );
        assert_eq!(thera.category(), SecurityCategory::Special);
        assert_ne!(thera.category(), SecurityCategory::Nullsec);
        assert_eq!(thera.security_label(), "Thera");
        let pochven = system(
            10000070,
            "Pochven",
            Some(25),
            Some(25),
            Some(-0.99),
            None,
            None,
            false,
        );
        assert_eq!(pochven.category(), SecurityCategory::Special);
        assert_eq!(pochven.security_label(), "Pochven");
        // Inherited-only special (solar row carries no class) is still Special.
        let thera_inherited = system(
            31000005,
            "Thera",
            None,
            Some(12),
            Some(-0.99),
            None,
            None,
            false,
        );
        assert_eq!(thera_inherited.category(), SecurityCategory::Special);
        assert_eq!(far_side_category(Some(7)), SecurityCategory::Highsec);
        assert_eq!(far_side_category(Some(8)), SecurityCategory::Lowsec);
        assert_eq!(far_side_category(Some(9)), SecurityCategory::Nullsec);
        assert_ne!(far_side_category(Some(12)), SecurityCategory::Nullsec);
        assert_ne!(far_side_category(Some(25)), SecurityCategory::Nullsec);
        assert_eq!(far_side_category(None), SecurityCategory::Unknown);
    }

    #[test]
    fn f2_effect_resolution_beacon_beats_visual() {
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        let red = system(
            96001,
            "J005926",
            Some(5),
            Some(5),
            Some(-0.99),
            Some(30848),
            Some(30844),
            false,
        );
        match effect_for_system(&red, &reference) {
            EffectResolution::Applied {
                family,
                strength,
                beacon_type_id,
            } => {
                assert_eq!(family, EffectFamily::RedGiant);
                assert_eq!(strength, 1);
                assert_eq!(beacon_type_id, 30848);
            }
            other => panic!("expected Red Giant: {other:?}"),
        }
        let wolf = system(
            96002,
            "J010569",
            Some(5),
            Some(5),
            Some(-0.99),
            Some(30849),
            Some(30848),
            false,
        );
        match effect_for_system(&wolf, &reference) {
            EffectResolution::Applied {
                family, strength, ..
            } => {
                assert_eq!(family, EffectFamily::WolfRayet);
                assert_eq!(strength, 1);
            }
            other => panic!("expected Wolf-Rayet: {other:?}"),
        }
        // Visual-only fallback still applies.
        let visual_only = system(
            1,
            "Visual",
            Some(1),
            Some(1),
            Some(-0.99),
            None,
            Some(30844),
            false,
        );
        match effect_for_system(&visual_only, &reference) {
            EffectResolution::Applied {
                family, strength, ..
            } => {
                assert_eq!(family, EffectFamily::Pulsar);
                assert_eq!(strength, 1);
            }
            other => panic!("expected visual fallback: {other:?}"),
        }
        // Unrecognised beacon -> Unknown, never Pulsar coercion.
        let mystery = system(
            2,
            "Mystery",
            Some(1),
            Some(1),
            Some(-0.99),
            Some(99999),
            None,
            false,
        );
        assert_eq!(
            effect_for_system(&mystery, &reference),
            EffectResolution::Unknown
        );
        // Missing data -> Unknown; verified absent -> None.
        let missing = system(
            3,
            "Missing",
            Some(5),
            Some(5),
            Some(-0.99),
            None,
            None,
            false,
        );
        assert_eq!(
            effect_for_system(&missing, &reference),
            EffectResolution::Unknown
        );
        let absent = system(4, "Absent", Some(5), Some(5), Some(-0.99), None, None, true);
        assert_eq!(
            effect_for_system(&absent, &reference),
            EffectResolution::None
        );
    }

    #[test]
    fn f2_statics_resonance_and_scopes() {
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        assert_eq!(
            statics_label(&reference, 31000005),
            "Static information unavailable"
        );
        assert!((apply_resonance(0.50, 50.0) - 0.25).abs() < 1e-12);
        assert_eq!(
            effects_scopes(EffectFamily::WolfRayet),
            VORTON_EFFECT_IDS.to_vec()
        );
        assert!(effects_scopes(EffectFamily::Pulsar).is_empty());
        assert_eq!(destination_label(Some(-1)), "Varies");
        assert_eq!(destination_label(Some(7)), "Highsec");
        assert_eq!(destination_label(None), "Unknown");
    }
}
