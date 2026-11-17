//! Bundled fitting-types catalogue (`assets/sde/fitting_types.json`):
//! reverse name-to-type lookup for EFT fitting import.
//!
//! The skills-only [`Sde`](super::sde::Sde) cannot resolve ships,
//! modules, charges, drones, or cargo, and slot identity must come
//! from dogma effects (Flutter `sde_service.dart` `_slotTypeFor` at
//! `ed698d3`), so this slice ships one generated extract (see
//! `scripts/sde/generate_fitting_types_sde.py`, design section 4.1).
//! Matching is full-table normalized-exact (trim, collapse
//! whitespace, lowercase — Flutter `_normalizeName`), never
//! substring, prefix, fuzzy, or alias-based. An ambiguous name is
//! never resolved to its first match.

use std::collections::{HashMap, HashSet};

use serde::Deserialize;

use crate::error::{AppError, AppResult};

/// One published inventory type in the bundled extract.
#[derive(Debug, Clone, Deserialize, PartialEq)]
pub struct FittingType {
    #[serde(rename = "typeId")]
    pub type_id: i64,
    #[serde(rename = "typeName")]
    pub name: String,
    #[serde(rename = "categoryId")]
    pub category_id: i64,
    #[serde(rename = "slotEffects", default)]
    pub slot_effects: Vec<i64>,
    #[serde(rename = "cpuOutput", default)]
    pub cpu_output: Option<f64>,
    #[serde(rename = "powerOutput", default)]
    pub power_output: Option<f64>,
    #[serde(rename = "cpu", default)]
    pub cpu: Option<f64>,
    #[serde(rename = "power", default)]
    pub power: Option<f64>,
    // Base ship stats (docs/ship-base-stats-design.md section 2):
    // dogma attributes 263 shieldCapacity, 265 armorHP,
    // 9 hp, 482 capacitorCapacity, 37 maxVelocity. The catalogue
    // key for hull keeps the SDE name `hp`; the field is `hull_hp`
    // so call sites read as what the value is (attribute 9
    // "Structure Hitpoints", labelled `Hull` on screen).
    #[serde(rename = "shieldCapacity", default)]
    pub shield_capacity: Option<f64>,
    #[serde(rename = "armorHP", default)]
    pub armor_hp: Option<f64>,
    #[serde(rename = "hp", default)]
    pub hull_hp: Option<f64>,
    #[serde(rename = "capacitorCapacity", default)]
    pub capacitor_capacity: Option<f64>,
    #[serde(rename = "maxVelocity", default)]
    pub max_velocity: Option<f64>,
    // Recharge durations (docs/ship-recharge-times-design.md):
    // dogma attributes 479 shieldRechargeRate and 55
    // rechargeRate, raw milliseconds in the catalogue; the
    // pure layer converts to seconds.
    #[serde(rename = "shieldRechargeRate", default)]
    pub shield_recharge_rate: Option<f64>,
    #[serde(rename = "rechargeRate", default)]
    pub capacitor_recharge_rate: Option<f64>,
    // Base ship resonances (docs/ship-resistances-design.md
    // section 2): dogma attributes 271/274/273/272 shield,
    // 267/270/269/268 armor, and 113/110/109/111 hull (the
    // emDamageResonance family, NOT 974-977 hullEmDamageResonance
    // et al., which are Damage Control bonus-attribute inputs).
    // Fields hold resonances, never pre-converted percentages;
    // the percentage exists only past the pure function. The
    // hull catalogue keys keep the SDE names
    // (`emDamageResonance` etc.) as the `hp` -> `hull_hp` field
    // above keeps `hp`: the key keeps the SDE name and the field
    // reads as what the value is.
    #[serde(rename = "shieldEmDamageResonance", default)]
    pub shield_em_resonance: Option<f64>,
    #[serde(rename = "shieldThermalDamageResonance", default)]
    pub shield_thermal_resonance: Option<f64>,
    #[serde(rename = "shieldKineticDamageResonance", default)]
    pub shield_kinetic_resonance: Option<f64>,
    #[serde(rename = "shieldExplosiveDamageResonance", default)]
    pub shield_explosive_resonance: Option<f64>,
    #[serde(rename = "armorEmDamageResonance", default)]
    pub armor_em_resonance: Option<f64>,
    #[serde(rename = "armorThermalDamageResonance", default)]
    pub armor_thermal_resonance: Option<f64>,
    #[serde(rename = "armorKineticDamageResonance", default)]
    pub armor_kinetic_resonance: Option<f64>,
    #[serde(rename = "armorExplosiveDamageResonance", default)]
    pub armor_explosive_resonance: Option<f64>,
    #[serde(rename = "emDamageResonance", default)]
    pub hull_em_resonance: Option<f64>,
    #[serde(rename = "thermalDamageResonance", default)]
    pub hull_thermal_resonance: Option<f64>,
    #[serde(rename = "kineticDamageResonance", default)]
    pub hull_kinetic_resonance: Option<f64>,
    #[serde(rename = "explosiveDamageResonance", default)]
    pub hull_explosive_resonance: Option<f64>,
    // Bay usage (docs/bay-capacities-design.md section 3.1):
    // `volume` is the invTypes `volume` column on every row,
    // `cargoCapacity` is the invTypes `capacity` column on
    // category 6 rows only, and the dogma keys are sparse:
    // `droneCapacity` 283, `droneBandwidth` 1271, `fighterCapacity`
    // 2055 on category 6 rows, `droneBandwidthUsed` 1272 wherever
    // a row exists (all such rows are category 18). Dogma 38 and
    // 161 are decoys and never read here.
    #[serde(rename = "volume", default)]
    pub volume: Option<f64>,
    #[serde(rename = "cargoCapacity", default)]
    pub cargo_capacity: Option<f64>,
    #[serde(rename = "droneCapacity", default)]
    pub drone_capacity: Option<f64>,
    #[serde(rename = "droneBandwidth", default)]
    pub drone_bandwidth: Option<f64>,
    #[serde(rename = "fighterCapacity", default)]
    pub fighter_capacity: Option<f64>,
    #[serde(rename = "droneBandwidthUsed", default)]
    pub drone_bandwidth_used: Option<f64>,
    // Rig calibration (docs/rig-calibration-design.md section 3.1):
    // dogma 1132 `upgradeCapacity` on category 6 rows and dogma
    // 1153 `upgradeCost` on slot-effect-2663 (rig) rows, sparse.
    #[serde(rename = "upgradeCapacity", default)]
    pub upgrade_capacity: Option<f64>,
    #[serde(rename = "upgradeCost", default)]
    pub upgrade_cost: Option<f64>,
    // Slot layout (docs/slot-layout-design.md section 3.1):
    // dogma 14 `hiSlots`, 13 `medSlots`, 12 `lowSlots`, 1137
    // `rigSlots`, 1367 `maxSubSystems`, 102 `turretSlotsLeft`,
    // 101 `launcherSlotsLeft` on category 6 rows only, sparse.
    // The hardware field names read as what the value is used
    // as (`turretSlotsLeft` -> `turret_hardpoints`,
    // `launcherSlotsLeft` -> `launcher_hardpoints`, the `hp` ->
    // `hull_hp` precedent). Hardpoint markers are effect 40
    // `launcherFitted` and effect 42 `turretFitted`, sparse
    // true-only; absence loads as `false`. Dogma 1154,
    // attribute 47, and the subsystem modifiers are never
    // emitted and never read here.
    #[serde(rename = "hiSlots", default)]
    pub hi_slots: Option<f64>,
    #[serde(rename = "medSlots", default)]
    pub med_slots: Option<f64>,
    #[serde(rename = "lowSlots", default)]
    pub low_slots: Option<f64>,
    #[serde(rename = "rigSlots", default)]
    pub rig_slots: Option<f64>,
    #[serde(rename = "maxSubSystems", default)]
    pub max_sub_systems: Option<f64>,
    #[serde(rename = "turretSlotsLeft", default)]
    pub turret_hardpoints: Option<f64>,
    #[serde(rename = "launcherSlotsLeft", default)]
    pub launcher_hardpoints: Option<f64>,
    #[serde(rename = "turretFitted", default)]
    pub turret_fitted: bool,
    #[serde(rename = "launcherFitted", default)]
    pub launcher_fitted: bool,
    // Navigation and targeting (docs/nav-targeting-design.md
    // section 4): dogma 600 `warpSpeedMultiplier` (unit `x`;
    // rendered as AU/s under the 1281 base-warp-speed
    // invariant of design section 2.1, 1281 never emitted),
    // 70 `agility`, 552 `signatureRadius`, 76 `maxTargetRange`
    // (raw metres), 564 `scanResolution`, 208
    // `scanRadarStrength`, 209 `scanLadarStrength`, 210
    // `scanMagnetometricStrength`, 211 `scanGravimetricStrength`,
    // 192 `maxLockedTargets` (a count, no unit) on category 6
    // rows only, sparse, plus `mass` from the invTypes `mass`
    // column (the `volume` precedent). Dogma 4, 1169, and 1908
    // are never emitted and never read here.
    #[serde(rename = "warpSpeedMultiplier", default)]
    pub warp_speed_multiplier: Option<f64>,
    #[serde(rename = "agility", default)]
    pub agility: Option<f64>,
    #[serde(rename = "signatureRadius", default)]
    pub signature_radius: Option<f64>,
    #[serde(rename = "maxTargetRange", default)]
    pub max_target_range: Option<f64>,
    #[serde(rename = "scanResolution", default)]
    pub scan_resolution: Option<f64>,
    #[serde(rename = "scanRadarStrength", default)]
    pub scan_radar_strength: Option<f64>,
    #[serde(rename = "scanLadarStrength", default)]
    pub scan_ladar_strength: Option<f64>,
    #[serde(rename = "scanMagnetometricStrength", default)]
    pub scan_magnetometric_strength: Option<f64>,
    #[serde(rename = "scanGravimetricStrength", default)]
    pub scan_gravimetric_strength: Option<f64>,
    #[serde(rename = "maxLockedTargets", default)]
    pub max_locked_targets: Option<f64>,
    #[serde(rename = "mass", default)]
    pub mass: Option<f64>,
    // Damage per second (docs/fitting-dps-design.md
    // section 3.1): dogma 51 `speed` (raw milliseconds,
    // never converted here), 64 `damageMultiplier` on
    // category 7/18 rows; 114 `emDamage`,
    // 116 `explosiveDamage`, 117 `kineticDamage`,
    // 118 `thermalDamage` on category 8/18 rows; the
    // fighter per-type keys (2215 squadron size, 2212/2213/
    // 2214 class flags, 2226/2227/2228/2229/2230/2233
    // attack ability, 2130/2131/2132/2133/2134/2182
    // missiles ability) on category 87 rows; 2216 tubes
    // plus 2217/2218/2219 class caps on category 6 rows;
    // sparse true-only ability markers for effects 6465
    // `fighterAbilityAttackM` (truncated in the SDE) and
    // 6431 `fighterAbilityMissiles`, loaded as `false` when
    // absent (the `turret_fitted` precedent). Dogma 212 is
    // never emitted and never read here.
    #[serde(rename = "speed", default)]
    pub speed: Option<f64>,
    #[serde(rename = "damageMultiplier", default)]
    pub damage_multiplier: Option<f64>,
    #[serde(rename = "emDamage", default)]
    pub em_damage: Option<f64>,
    #[serde(rename = "explosiveDamage", default)]
    pub explosive_damage: Option<f64>,
    #[serde(rename = "kineticDamage", default)]
    pub kinetic_damage: Option<f64>,
    #[serde(rename = "thermalDamage", default)]
    pub thermal_damage: Option<f64>,
    #[serde(rename = "fighterSquadronMaxSize", default)]
    pub fighter_squadron_max_size: Option<f64>,
    #[serde(rename = "fighterSquadronIsLight", default)]
    pub fighter_squadron_is_light: Option<f64>,
    #[serde(rename = "fighterSquadronIsSupport", default)]
    pub fighter_squadron_is_support: Option<f64>,
    #[serde(rename = "fighterSquadronIsHeavy", default)]
    pub fighter_squadron_is_heavy: Option<f64>,
    #[serde(rename = "fighterAbilityAttackMissileDamageMultiplier", default)]
    pub fighter_attack_damage_multiplier: Option<f64>,
    #[serde(rename = "fighterAbilityAttackMissileDamageEM", default)]
    pub fighter_attack_damage_em: Option<f64>,
    #[serde(rename = "fighterAbilityAttackMissileDamageTherm", default)]
    pub fighter_attack_damage_therm: Option<f64>,
    #[serde(rename = "fighterAbilityAttackMissileDamageKin", default)]
    pub fighter_attack_damage_kin: Option<f64>,
    #[serde(rename = "fighterAbilityAttackMissileDamageExp", default)]
    pub fighter_attack_damage_exp: Option<f64>,
    #[serde(rename = "fighterAbilityAttackMissileDuration", default)]
    pub fighter_attack_duration: Option<f64>,
    #[serde(rename = "fighterAbilityMissilesDamageMultiplier", default)]
    pub fighter_missiles_damage_multiplier: Option<f64>,
    #[serde(rename = "fighterAbilityMissilesDamageEM", default)]
    pub fighter_missiles_damage_em: Option<f64>,
    #[serde(rename = "fighterAbilityMissilesDamageTherm", default)]
    pub fighter_missiles_damage_therm: Option<f64>,
    #[serde(rename = "fighterAbilityMissilesDamageKin", default)]
    pub fighter_missiles_damage_kin: Option<f64>,
    #[serde(rename = "fighterAbilityMissilesDamageExp", default)]
    pub fighter_missiles_damage_exp: Option<f64>,
    #[serde(rename = "fighterAbilityMissilesDuration", default)]
    pub fighter_missiles_duration: Option<f64>,
    #[serde(rename = "fighterTubes", default)]
    pub fighter_tubes: Option<f64>,
    #[serde(rename = "fighterLightSlots", default)]
    pub fighter_light_slots: Option<f64>,
    #[serde(rename = "fighterSupportSlots", default)]
    pub fighter_support_slots: Option<f64>,
    #[serde(rename = "fighterHeavySlots", default)]
    pub fighter_heavy_slots: Option<f64>,
    #[serde(rename = "fighterAbilityAttackM", default)]
    pub fighter_ability_attack: bool,
    #[serde(rename = "fighterAbilityMissiles", default)]
    pub fighter_ability_missiles: bool,
}

/// Outcome of a reverse name lookup. `Found` carries the unique
/// catalogue row; `Ambiguous` means more than one distinct `type_id`
/// shares the normalized name and the name must stay unresolved.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum NameLookup<'a> {
    Found(&'a FittingType),
    Unknown,
    Ambiguous,
}

#[derive(Debug, Clone, Deserialize, Default)]
struct FittingTypesFile {
    #[serde(default)]
    types: Vec<FittingType>,
}

/// In-memory index over the bundled fitting-types extract.
#[derive(Debug, Clone, Default)]
pub struct FittingTypes {
    /// Every usable catalogue row, in file order.
    pub types: Vec<FittingType>,
    /// Normalized name to catalogue row indices, de-duplicated by
    /// `type_id` (the AAR `_loadNameIndex` semantics).
    by_normalized: HashMap<String, Vec<usize>>,
    /// Type number to catalogue row index. A duplicated type number
    /// (absent from the shipped asset) resolves to the first row in
    /// file order.
    by_id: HashMap<i64, usize>,
}

/// Flutter `_normalizeName`: trim, collapse every whitespace run to
/// one space, lowercase. `split_whitespace` uses the Unicode
/// White_Space property, so tabs and non-breaking spaces collapse too.
pub fn normalize_type_name(name: &str) -> String {
    name.split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

impl FittingTypes {
    pub fn load_bundled() -> AppResult<Self> {
        tracing::debug!("[FITTING] loading bundled fitting types");
        Self::from_json(include_str!("../../assets/sde/fitting_types.json"))
    }

    pub fn from_json(json: &str) -> AppResult<Self> {
        let file: FittingTypesFile = serde_json::from_str(json)?;
        let mut types = Vec::with_capacity(file.types.len());
        let mut skipped: usize = 0;
        for row in file.types {
            if row.type_id <= 0 || row.name.trim().is_empty() {
                skipped = skipped.saturating_add(1);
                continue;
            }
            types.push(row);
        }
        tracing::info!(
            "[FITTING] fitting types loaded types={} skipped={}",
            types.len(),
            skipped
        );
        if types.is_empty() {
            // An empty catalogue presented as valid is the failure the
            // Exploration loader also forbids.
            return Err(AppError::Message(
                "[FITTING] fitting type catalogue is empty".to_string(),
            ));
        }
        let mut by_normalized: HashMap<String, Vec<usize>> = HashMap::new();
        let mut seen: HashSet<(String, i64)> = HashSet::new();
        for (index, row) in types.iter().enumerate() {
            let key = normalize_type_name(&row.name);
            if seen.insert((key.clone(), row.type_id)) {
                by_normalized.entry(key).or_default().push(index);
            }
        }
        let mut by_id: HashMap<i64, usize> = HashMap::new();
        for (index, row) in types.iter().enumerate() {
            by_id.entry(row.type_id).or_insert(index);
        }
        Ok(Self {
            types,
            by_normalized,
            by_id,
        })
    }

    /// Look up a pasted name by normalized-exact match. The name
    /// itself is user text and is never logged.
    pub fn lookup(&self, name: &str) -> NameLookup<'_> {
        tracing::debug!("[FITTING] lookup name_len={}", name.len());
        let key = normalize_type_name(name);
        let Some(rows) = self.by_normalized.get(&key) else {
            return NameLookup::Unknown;
        };
        match rows.as_slice() {
            [] => NameLookup::Unknown,
            [only] => match self.types.get(*only) {
                Some(row) => NameLookup::Found(row),
                None => NameLookup::Unknown,
            },
            _ => NameLookup::Ambiguous,
        }
    }

    /// Look up a catalogue row by type number. Logs nothing: the
    /// number is pasted input and is never logged in any case.
    /// Returns `None` for any number with no row, including zero and
    /// negatives (such rows are filtered at load).
    pub fn lookup_by_id(&self, type_id: i64) -> Option<&FittingType> {
        self.by_id
            .get(&type_id)
            .and_then(|index| self.types.get(*index))
    }

    /// Number of usable types in the catalogue.
    pub fn type_count(&self) -> usize {
        self.types.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lookup_id(types: &FittingTypes, name: &str) -> Option<i64> {
        match types.lookup(name) {
            NameLookup::Found(row) => Some(row.type_id),
            NameLookup::Unknown => None,
            NameLookup::Ambiguous => None,
        }
    }

    #[test]
    fn bundled_loads_and_resolves_known_types() {
        let types = FittingTypes::load_bundled().expect("bundled catalogue loads");
        assert!(types.type_count() > 20_000);
        let rifter = types.lookup("Rifter");
        match rifter {
            NameLookup::Found(row) => {
                assert_eq!(row.type_id, 587);
                assert_eq!(row.category_id, 6);
            }
            other => panic!("Rifter lookup: {other:?}"),
        }
        match types.lookup("Damage Control II") {
            NameLookup::Found(row) => {
                assert_eq!(row.type_id, 2048);
                assert_eq!(row.category_id, 7);
                assert!(row.slot_effects.contains(&11));
            }
            other => panic!("Damage Control II lookup: {other:?}"),
        }
        assert_eq!(lookup_id(&types, "Hobgoblin II"), Some(2456));
        assert_eq!(lookup_id(&types, "EMP S"), Some(185));
        assert_eq!(lookup_id(&types, "Tritanium"), Some(34));
    }

    #[test]
    fn normalization_matches_case_and_whitespace_variants() {
        let types = FittingTypes::load_bundled().expect("bundled catalogue loads");
        assert_eq!(lookup_id(&types, "damage  control ii"), Some(2048));
        assert_eq!(lookup_id(&types, " DAMAGE CONTROL II "), Some(2048));
        assert_eq!(lookup_id(&types, "damage\tcontrol  ii"), Some(2048));
        assert_eq!(lookup_id(&types, "Damage\tControl\tII"), Some(2048));
    }

    #[test]
    fn exact_match_rejects_prefix_and_suffix() {
        let types = FittingTypes::load_bundled().expect("bundled catalogue loads");
        assert_eq!(types.lookup("Damage Control"), NameLookup::Unknown);
        assert_eq!(types.lookup("Damage Control IIx"), NameLookup::Unknown);
        assert_eq!(types.lookup("oblin II"), NameLookup::Unknown);
    }

    #[test]
    fn duplicate_names_are_ambiguous_but_duplicate_rows_are_found() {
        let ambiguous = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":11,"typeName":"Dup Name","categoryId":7,"slotEffects":[11]},
                {"typeId":12,"typeName":"dup   name","categoryId":7,"slotEffects":[12]}]}"#,
        )
        .expect("fixture parses");
        assert_eq!(ambiguous.lookup("DUP NAME"), NameLookup::Ambiguous);

        let duplicated_rows = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":11,"typeName":"Solo Name","categoryId":7},
                {"typeId":11,"typeName":"Solo Name","categoryId":7}]}"#,
        )
        .expect("fixture parses");
        assert_eq!(lookup_id(&duplicated_rows, "solo name"), Some(11));
    }

    #[test]
    fn invalid_rows_are_skipped_and_empty_or_malformed_fails() {
        let filtered = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":0,"typeName":"Zero","categoryId":7},
                {"typeId":-5,"typeName":"Negative","categoryId":7},
                {"typeId":11,"typeName":"   ","categoryId":7},
                {"typeId":12,"typeName":"Kept","categoryId":6}]}"#,
        )
        .expect("fixture parses");
        assert_eq!(filtered.type_count(), 1);
        assert_eq!(lookup_id(&filtered, "Kept"), Some(12));

        let empty = FittingTypes::from_json(r#"{"types":[]}"#);
        assert!(empty.is_err());
        let all_invalid =
            FittingTypes::from_json(r#"{"types":[{"typeId":0,"typeName":"Zero","categoryId":7}]}"#);
        assert!(all_invalid.is_err());
        let malformed = FittingTypes::from_json("not json at all");
        assert!(malformed.is_err());
    }

    #[test]
    fn lookup_by_id_resolves_bundled_rows() {
        let types = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let rifter = types.lookup_by_id(587).expect("Rifter by number");
        assert_eq!(rifter.name, "Rifter");
        assert_eq!(rifter.category_id, 6);
        let damage_control = types
            .lookup_by_id(2048)
            .expect("Damage Control II by number");
        assert_eq!(damage_control.name, "Damage Control II");
        assert!(damage_control.slot_effects.contains(&11));
        assert_eq!(types.lookup_by_id(999999), None);
        assert_eq!(types.lookup_by_id(0), None);
        assert_eq!(types.lookup_by_id(-5), None);
    }

    #[test]
    fn lookup_by_id_duplicate_number_resolves_to_first_row() {
        let types = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"First Row","categoryId":6,"slotEffects":[]},
                {"typeId":42,"typeName":"Second Row","categoryId":7,"slotEffects":[11]}]}"#,
        )
        .expect("fixture parses");
        let row = types.lookup_by_id(42).expect("duplicated number resolves");
        assert_eq!(row.name, "First Row");
    }

    #[test]
    fn bundled_catalogue_invariants() {
        let types = FittingTypes::load_bundled().expect("bundled catalogue loads");
        for row in &types.types {
            let digits = row
                .name
                .trim()
                .strip_prefix('+')
                .or_else(|| row.name.trim().strip_prefix('-'))
                .unwrap_or(row.name.trim());
            assert!(
                digits.is_empty() || !digits.bytes().all(|b| b.is_ascii_digit()),
                "purely numeric catalogue name: {:?}",
                row.name
            );
            if row.category_id == 6 {
                assert!(
                    !row.name.contains(',') && !row.name.contains('[') && !row.name.contains(']'),
                    "ship name with header delimiter: {:?}",
                    row.name
                );
            }
            // Slot classification assumes at most one slot effect
            // per type (both importers take the shared first-match
            // helper; the strict Flutter adapter required unanimity).
            // A regenerated catalogue breaking this must fail here,
            // loudly, instead of silently changing slots.
            assert!(
                row.slot_effects.len() <= 1,
                "type with multiple slot effects: {:?}",
                row.name
            );
            if row.category_id == 32 {
                assert!(
                    row.slot_effects.is_empty() || row.slot_effects == [3772],
                    "subsystem without the subsystem slot effect: {:?}",
                    row.name
                );
            }
            if row.category_id == 7 {
                assert!(
                    !row.slot_effects.contains(&3772),
                    "module carrying the subsystem slot effect: {:?}",
                    row.name
                );
            }
            // Base resource attributes (design section 5): ships
            // carry outputs, slot modules carry needs, every other
            // row carries neither. Present values are finite and
            // non-negative; absence is distinct from a present 0.0.
            let has_output = row.cpu_output.is_some() || row.power_output.is_some();
            let has_need = row.cpu.is_some() || row.power.is_some();
            for value in [row.cpu_output, row.power_output, row.cpu, row.power]
                .into_iter()
                .flatten()
            {
                assert!(
                    value.is_finite() && value >= 0.0,
                    "negative or non-finite resource value on {:?}",
                    row.name
                );
            }
            if row.category_id == 6 {
                assert!(
                    row.cpu_output.is_some() && row.power_output.is_some(),
                    "ship without both outputs: {:?}",
                    row.name
                );
                assert!(!has_need, "ship carrying module needs: {:?}", row.name);
            } else if row.category_id == 7 && !row.slot_effects.is_empty() {
                assert!(!has_output, "module carrying ship outputs: {:?}", row.name);
            } else {
                assert!(
                    !has_output && !has_need,
                    "non-ship/non-slot row carrying resource values: {:?}",
                    row.name
                );
            }
            if row.category_id == 7 && row.slot_effects == [2663] {
                assert!(
                    row.cpu.is_none() && row.power.is_none(),
                    "rig carrying CPU/power needs: {:?}",
                    row.name
                );
            }
            // Base ship stats (design section 3): ships carry all
            // five, every other row carries none. Present values
            // are finite and non-negative; absence is distinct
            // from a present 0.0.
            let has_base_stat = row.shield_capacity.is_some()
                || row.armor_hp.is_some()
                || row.hull_hp.is_some()
                || row.capacitor_capacity.is_some()
                || row.max_velocity.is_some()
                || row.shield_recharge_rate.is_some()
                || row.capacitor_recharge_rate.is_some();
            for value in [
                row.shield_capacity,
                row.armor_hp,
                row.hull_hp,
                row.capacitor_capacity,
                row.max_velocity,
                row.shield_recharge_rate,
                row.capacitor_recharge_rate,
            ]
            .into_iter()
            .flatten()
            {
                assert!(
                    value.is_finite() && value >= 0.0,
                    "negative or non-finite base ship stat on {:?}",
                    row.name
                );
            }
            if row.category_id == 6 {
                assert!(
                    row.shield_capacity.is_some()
                        && row.armor_hp.is_some()
                        && row.hull_hp.is_some()
                        && row.capacitor_capacity.is_some()
                        && row.max_velocity.is_some()
                        && row.shield_recharge_rate.is_some()
                        && row.capacitor_recharge_rate.is_some(),
                    "ship without all seven base stats: {:?}",
                    row.name
                );
            } else {
                assert!(
                    !has_base_stat,
                    "non-ship carrying base ship stats: {:?}",
                    row.name
                );
            }
            // Base ship resonances (docs/ship-resistances-design.md
            // section 3): ships carry all twelve, every other row
            // carries none. Present values are finite and
            // non-negative with no upper bound (a resonance above
            // 1 renders its true signed percent); absence is
            // distinct from a present 0.0 or 1.0.
            let has_resonance = row.shield_em_resonance.is_some()
                || row.shield_thermal_resonance.is_some()
                || row.shield_kinetic_resonance.is_some()
                || row.shield_explosive_resonance.is_some()
                || row.armor_em_resonance.is_some()
                || row.armor_thermal_resonance.is_some()
                || row.armor_kinetic_resonance.is_some()
                || row.armor_explosive_resonance.is_some()
                || row.hull_em_resonance.is_some()
                || row.hull_thermal_resonance.is_some()
                || row.hull_kinetic_resonance.is_some()
                || row.hull_explosive_resonance.is_some();
            for value in [
                row.shield_em_resonance,
                row.shield_thermal_resonance,
                row.shield_kinetic_resonance,
                row.shield_explosive_resonance,
                row.armor_em_resonance,
                row.armor_thermal_resonance,
                row.armor_kinetic_resonance,
                row.armor_explosive_resonance,
                row.hull_em_resonance,
                row.hull_thermal_resonance,
                row.hull_kinetic_resonance,
                row.hull_explosive_resonance,
            ]
            .into_iter()
            .flatten()
            {
                assert!(
                    value.is_finite() && value >= 0.0,
                    "negative or non-finite ship resonance on {:?}",
                    row.name
                );
            }
            if row.category_id == 6 {
                assert!(
                    row.shield_em_resonance.is_some()
                        && row.shield_thermal_resonance.is_some()
                        && row.shield_kinetic_resonance.is_some()
                        && row.shield_explosive_resonance.is_some()
                        && row.armor_em_resonance.is_some()
                        && row.armor_thermal_resonance.is_some()
                        && row.armor_kinetic_resonance.is_some()
                        && row.armor_explosive_resonance.is_some()
                        && row.hull_em_resonance.is_some()
                        && row.hull_thermal_resonance.is_some()
                        && row.hull_kinetic_resonance.is_some()
                        && row.hull_explosive_resonance.is_some(),
                    "ship without all twelve ship resonances: {:?}",
                    row.name
                );
            } else {
                assert!(
                    !has_resonance,
                    "non-ship carrying ship resonances: {:?}",
                    row.name
                );
            }
            // Bay values (docs/bay-capacities-design.md section
            // 3.4): every present bay value is finite and
            // non-negative; `volume` is present on every row;
            // `cargoCapacity` is present on every category 6 row
            // and on no other row; the three ship bay keys appear
            // only on category 6 rows (absence is allowed, never
            // required); `droneBandwidthUsed` appears only on
            // category 18 rows. Absence stays distinct from 0.0.
            for value in [
                row.volume,
                row.cargo_capacity,
                row.drone_capacity,
                row.drone_bandwidth,
                row.fighter_capacity,
                row.drone_bandwidth_used,
            ]
            .into_iter()
            .flatten()
            {
                assert!(
                    value.is_finite() && value >= 0.0,
                    "negative or non-finite bay value on {:?}",
                    row.name
                );
            }
            assert!(row.volume.is_some(), "row without volume: {:?}", row.name);
            if row.category_id == 6 {
                assert!(
                    row.cargo_capacity.is_some(),
                    "ship without cargoCapacity: {:?}",
                    row.name
                );
            } else {
                assert!(
                    row.cargo_capacity.is_none(),
                    "non-ship carrying cargoCapacity: {:?}",
                    row.name
                );
            }
            if row.drone_capacity.is_some()
                || row.drone_bandwidth.is_some()
                || row.fighter_capacity.is_some()
            {
                assert_eq!(
                    row.category_id, 6,
                    "non-ship carrying ship bay key: {:?}",
                    row.name
                );
            }
            if row.drone_bandwidth_used.is_some() {
                assert_eq!(
                    row.category_id, 18,
                    "non-drone carrying droneBandwidthUsed: {:?}",
                    row.name
                );
            }
            // Rig calibration values (docs/rig-calibration-design.md
            // section 3.4): every present calibration value is
            // finite and non-negative; `upgradeCapacity` only on
            // category 6 rows (absence allowed); `upgradeCost`
            // only on slotEffects == [2663] and on every such row;
            // no row carries both keys.
            for value in [row.upgrade_capacity, row.upgrade_cost]
                .into_iter()
                .flatten()
            {
                assert!(
                    value.is_finite() && value >= 0.0,
                    "negative or non-finite calibration value on {:?}",
                    row.name
                );
            }
            if row.upgrade_capacity.is_some() {
                assert_eq!(
                    row.category_id, 6,
                    "non-ship carrying upgradeCapacity: {:?}",
                    row.name
                );
            }
            if row.upgrade_cost.is_some() {
                assert_eq!(
                    row.slot_effects.as_slice(),
                    [2663],
                    "non-rig carrying upgradeCost: {:?}",
                    row.name
                );
            }
            if row.slot_effects.as_slice() == [2663] {
                assert!(
                    row.upgrade_cost.is_some(),
                    "rig without upgradeCost: {:?}",
                    row.name
                );
            }
            assert!(
                !(row.upgrade_capacity.is_some() && row.upgrade_cost.is_some()),
                "row carrying both calibration keys: {:?}",
                row.name
            );
            // Slot layout values (docs/slot-layout-design.md
            // section 3.4): every present layout value is finite,
            // non-negative, and integral; any layout key implies
            // category 6 (absence is allowed, never required);
            // `turret_fitted || launcher_fitted` implies
            // `slot_effects == [12]`; never both markers true;
            // `max_sub_systems` present only on the four pinned
            // type ids. Absence stays distinct from 0.0.
            for value in [
                row.hi_slots,
                row.med_slots,
                row.low_slots,
                row.rig_slots,
                row.max_sub_systems,
                row.turret_hardpoints,
                row.launcher_hardpoints,
            ]
            .into_iter()
            .flatten()
            {
                assert!(
                    value.is_finite() && value >= 0.0 && value.fract() == 0.0,
                    "negative, non-finite, or non-integral slot layout value on {:?}",
                    row.name
                );
            }
            if row.hi_slots.is_some()
                || row.med_slots.is_some()
                || row.low_slots.is_some()
                || row.rig_slots.is_some()
                || row.max_sub_systems.is_some()
                || row.turret_hardpoints.is_some()
                || row.launcher_hardpoints.is_some()
            {
                assert_eq!(
                    row.category_id, 6,
                    "non-ship carrying slot layout key: {:?}",
                    row.name
                );
            }
            if row.turret_fitted || row.launcher_fitted {
                assert_eq!(
                    row.slot_effects.as_slice(),
                    [12],
                    "hardpoint marker without slotEffects [12]: {:?}",
                    row.name
                );
            }
            assert!(
                !(row.turret_fitted && row.launcher_fitted),
                "row carrying both hardpoint markers: {:?}",
                row.name
            );
            if row.max_sub_systems.is_some() {
                assert!(
                    matches!(row.type_id, 29984 | 29986 | 29988 | 29990),
                    "maxSubSystems on unpinned hull {:?}",
                    row.name
                );
            }
            // Navigation and targeting values
            // (docs/nav-targeting-design.md section 4): every
            // present value is finite and non-negative;
            // `max_locked_targets` is integral; any nav/targeting
            // key implies category 6 (absence is allowed, never
            // required). Absence stays distinct from 0.0.
            for value in [
                row.warp_speed_multiplier,
                row.agility,
                row.signature_radius,
                row.max_target_range,
                row.scan_resolution,
                row.scan_radar_strength,
                row.scan_ladar_strength,
                row.scan_magnetometric_strength,
                row.scan_gravimetric_strength,
                row.max_locked_targets,
                row.mass,
            ]
            .into_iter()
            .flatten()
            {
                assert!(
                    value.is_finite() && value >= 0.0,
                    "negative or non-finite navigation and targeting value on {:?}",
                    row.name
                );
            }
            if let Some(targets) = row.max_locked_targets {
                assert!(
                    targets.fract() == 0.0,
                    "non-integral maxLockedTargets on {:?}",
                    row.name
                );
            }
            if row.warp_speed_multiplier.is_some()
                || row.agility.is_some()
                || row.signature_radius.is_some()
                || row.max_target_range.is_some()
                || row.scan_resolution.is_some()
                || row.scan_radar_strength.is_some()
                || row.scan_ladar_strength.is_some()
                || row.scan_magnetometric_strength.is_some()
                || row.scan_gravimetric_strength.is_some()
                || row.max_locked_targets.is_some()
                || row.mass.is_some()
            {
                assert_eq!(
                    row.category_id, 6,
                    "non-ship carrying navigation and targeting key: {:?}",
                    row.name
                );
            }
            // Damage-per-second values
            // (docs/fitting-dps-design.md section 3.3):
            // every present DPS value is finite and
            // non-negative; `speed`/`damage_multiplier`
            // appear only on category 7 or 18 rows; the
            // four damage components only on category 8 or
            // 18 rows; the fighter per-type keys and both
            // ability markers only on category-87 rows;
            // the four tube/slot keys only on category-6
            // rows. Absence stays distinct from 0.0.
            for value in [
                row.speed,
                row.damage_multiplier,
                row.em_damage,
                row.explosive_damage,
                row.kinetic_damage,
                row.thermal_damage,
                row.fighter_squadron_max_size,
                row.fighter_squadron_is_light,
                row.fighter_squadron_is_support,
                row.fighter_squadron_is_heavy,
                row.fighter_attack_damage_multiplier,
                row.fighter_attack_damage_em,
                row.fighter_attack_damage_therm,
                row.fighter_attack_damage_kin,
                row.fighter_attack_damage_exp,
                row.fighter_attack_duration,
                row.fighter_missiles_damage_multiplier,
                row.fighter_missiles_damage_em,
                row.fighter_missiles_damage_therm,
                row.fighter_missiles_damage_kin,
                row.fighter_missiles_damage_exp,
                row.fighter_missiles_duration,
                row.fighter_tubes,
                row.fighter_light_slots,
                row.fighter_support_slots,
                row.fighter_heavy_slots,
            ]
            .into_iter()
            .flatten()
            {
                assert!(
                    value.is_finite() && value >= 0.0,
                    "negative or non-finite damage-per-second value on {:?}",
                    row.name
                );
            }
            if row.speed.is_some() || row.damage_multiplier.is_some() {
                assert!(
                    matches!(row.category_id, 7 | 18),
                    "non-module/drone carrying cycle key: {:?}",
                    row.name
                );
            }
            if row.em_damage.is_some()
                || row.explosive_damage.is_some()
                || row.kinetic_damage.is_some()
                || row.thermal_damage.is_some()
            {
                assert!(
                    matches!(row.category_id, 8 | 18),
                    "non-charge/drone carrying damage key: {:?}",
                    row.name
                );
            }
            if row.fighter_squadron_max_size.is_some()
                || row.fighter_squadron_is_light.is_some()
                || row.fighter_squadron_is_support.is_some()
                || row.fighter_squadron_is_heavy.is_some()
                || row.fighter_attack_damage_multiplier.is_some()
                || row.fighter_attack_damage_em.is_some()
                || row.fighter_attack_damage_therm.is_some()
                || row.fighter_attack_damage_kin.is_some()
                || row.fighter_attack_damage_exp.is_some()
                || row.fighter_attack_duration.is_some()
                || row.fighter_missiles_damage_multiplier.is_some()
                || row.fighter_missiles_damage_em.is_some()
                || row.fighter_missiles_damage_therm.is_some()
                || row.fighter_missiles_damage_kin.is_some()
                || row.fighter_missiles_damage_exp.is_some()
                || row.fighter_missiles_duration.is_some()
                || row.fighter_ability_attack
                || row.fighter_ability_missiles
            {
                assert_eq!(
                    row.category_id, 87,
                    "non-fighter carrying fighter key: {:?}",
                    row.name
                );
            }
            if row.fighter_tubes.is_some()
                || row.fighter_light_slots.is_some()
                || row.fighter_support_slots.is_some()
                || row.fighter_heavy_slots.is_some()
            {
                assert_eq!(
                    row.category_id, 6,
                    "non-ship carrying fighter tube key: {:?}",
                    row.name
                );
            }
        }
        // Spot pins mirroring the generator oracles (design section
        // 5), read from dgmTypeAttributes.csv.bz2 during design.
        let rifter = types.lookup_by_id(587).expect("Rifter row");
        assert_eq!(rifter.cpu_output, Some(130.0));
        assert_eq!(rifter.power_output, Some(41.0));
        let damage_control = types.lookup_by_id(2048).expect("DC II row");
        assert_eq!(damage_control.cpu, Some(30.0));
        assert_eq!(damage_control.power, Some(1.0));
        let railgun = types.lookup_by_id(37303).expect("railgun row");
        assert_eq!(railgun.cpu, Some(126.5));
        let reactor = types.lookup_by_id(1355).expect("reactor row");
        assert_eq!(reactor.power, Some(0.0));
        let overdrive = types.lookup_by_id(1236).expect("overdrive row");
        assert_eq!(overdrive.cpu, None);
        assert_eq!(overdrive.power, None);
        let rig = types.lookup_by_id(31668).expect("rig row");
        assert_eq!(rig.cpu, None);
        assert_eq!(rig.power, None);
        // Base ship stat spot pins (design section 3), read from
        // dgmTypeAttributes.csv.bz2 during design: Rifter 587
        // (263/265/9/482/37) = 450.0/450.0/350.0/250.0/365.0;
        // Punisher 597 = 350.0/500.0/450.0/400.0/355.0.
        let rifter = types.lookup_by_id(587).expect("Rifter row");
        assert_eq!(rifter.shield_capacity, Some(450.0));
        assert_eq!(rifter.armor_hp, Some(450.0));
        assert_eq!(rifter.hull_hp, Some(350.0));
        assert_eq!(rifter.capacitor_capacity, Some(250.0));
        assert_eq!(rifter.max_velocity, Some(365.0));
        let punisher = types.lookup_by_id(597).expect("Punisher row");
        assert_eq!(punisher.shield_capacity, Some(350.0));
        assert_eq!(punisher.armor_hp, Some(500.0));
        assert_eq!(punisher.hull_hp, Some(450.0));
        assert_eq!(punisher.capacitor_capacity, Some(400.0));
        assert_eq!(punisher.max_velocity, Some(355.0));
        // Recharge pins (docs/ship-recharge-times-design.md):
        // cache rows 587: 479 625000.0, 55 125000.0;
        // 597: 479 625000.0, 55 160000.0 (raw milliseconds).
        assert_eq!(rifter.shield_recharge_rate, Some(625000.0));
        assert_eq!(rifter.capacitor_recharge_rate, Some(125000.0));
        assert_eq!(punisher.shield_recharge_rate, Some(625000.0));
        assert_eq!(punisher.capacitor_recharge_rate, Some(160000.0));
        // Fractional pins: Echelon 3532 capacitor 187.5, Helios
        // 11172 capacitor 218.75, Mekubal 78333 velocity 322.3.
        let echelon = types.lookup_by_id(3532).expect("Echelon row");
        assert_eq!(echelon.capacitor_capacity, Some(187.5));
        let helios = types.lookup_by_id(11172).expect("Helios row");
        assert_eq!(helios.capacitor_capacity, Some(218.75));
        let mekubal = types.lookup_by_id(78333).expect("Mekubal row");
        assert_eq!(mekubal.max_velocity, Some(322.3));
        // Category gate pins: module, rig, and subsystem rows
        // carry none of the five.
        let subsystem = types.lookup_by_id(45623).expect("subsystem row");
        for row in [damage_control, rig, subsystem] {
            assert_eq!(row.shield_capacity, None);
            assert_eq!(row.armor_hp, None);
            assert_eq!(row.hull_hp, None);
            assert_eq!(row.capacitor_capacity, None);
            assert_eq!(row.max_velocity, None);
            assert_eq!(row.shield_recharge_rate, None);
            assert_eq!(row.capacitor_recharge_rate, None);
        }
        // Base ship resonance spot pins (docs/ship-resistances-design.md
        // section 3), read from dgmTypeAttributes.csv.bz2 during design:
        // Rifter 587 shield 1.0/0.8/0.6/0.5 armor 0.4/0.65/0.75/0.9
        // hull 0.67 x4 (974-977 decoy rows at 1.0 never emitted);
        // Punisher 597 shield 1.0/0.8/0.6/0.5 armor 0.5/0.65/0.75/0.8
        // hull 0.67 x4.
        let rifter = types.lookup_by_id(587).expect("Rifter row");
        assert_eq!(rifter.shield_em_resonance, Some(1.0));
        assert_eq!(rifter.shield_thermal_resonance, Some(0.8));
        assert_eq!(rifter.shield_kinetic_resonance, Some(0.6));
        assert_eq!(rifter.shield_explosive_resonance, Some(0.5));
        assert_eq!(rifter.armor_em_resonance, Some(0.4));
        assert_eq!(rifter.armor_thermal_resonance, Some(0.65));
        assert_eq!(rifter.armor_kinetic_resonance, Some(0.75));
        assert_eq!(rifter.armor_explosive_resonance, Some(0.9));
        assert_eq!(rifter.hull_em_resonance, Some(0.67));
        assert_eq!(rifter.hull_thermal_resonance, Some(0.67));
        assert_eq!(rifter.hull_kinetic_resonance, Some(0.67));
        assert_eq!(rifter.hull_explosive_resonance, Some(0.67));
        let punisher = types.lookup_by_id(597).expect("Punisher row");
        assert_eq!(punisher.shield_em_resonance, Some(1.0));
        assert_eq!(punisher.shield_thermal_resonance, Some(0.8));
        assert_eq!(punisher.shield_kinetic_resonance, Some(0.6));
        assert_eq!(punisher.shield_explosive_resonance, Some(0.5));
        assert_eq!(punisher.armor_em_resonance, Some(0.5));
        assert_eq!(punisher.armor_thermal_resonance, Some(0.65));
        assert_eq!(punisher.armor_kinetic_resonance, Some(0.75));
        assert_eq!(punisher.armor_explosive_resonance, Some(0.8));
        assert_eq!(punisher.hull_em_resonance, Some(0.67));
        assert_eq!(punisher.hull_thermal_resonance, Some(0.67));
        assert_eq!(punisher.hull_kinetic_resonance, Some(0.67));
        assert_eq!(punisher.hull_explosive_resonance, Some(0.67));
        // Asymmetric and fractional pins: Mimir 32209 armor EM 0.1,
        // armor thermal 0.325; Falcon 11957 armor kinetic 0.46875,
        // armor thermal 0.20625.
        let mimir = types.lookup_by_id(32209).expect("Mimir row");
        assert_eq!(mimir.armor_em_resonance, Some(0.1));
        assert_eq!(mimir.armor_thermal_resonance, Some(0.325));
        let falcon = types.lookup_by_id(11957).expect("Falcon row");
        assert_eq!(falcon.armor_kinetic_resonance, Some(0.46875));
        assert_eq!(falcon.armor_thermal_resonance, Some(0.20625));
        // Category gate pins: module, rig, and subsystem rows
        // carry none of the twelve.
        for row in [damage_control, rig, subsystem] {
            assert_eq!(row.shield_em_resonance, None);
            assert_eq!(row.shield_thermal_resonance, None);
            assert_eq!(row.shield_kinetic_resonance, None);
            assert_eq!(row.shield_explosive_resonance, None);
            assert_eq!(row.armor_em_resonance, None);
            assert_eq!(row.armor_thermal_resonance, None);
            assert_eq!(row.armor_kinetic_resonance, None);
            assert_eq!(row.armor_explosive_resonance, None);
            assert_eq!(row.hull_em_resonance, None);
            assert_eq!(row.hull_thermal_resonance, None);
            assert_eq!(row.hull_kinetic_resonance, None);
            assert_eq!(row.hull_explosive_resonance, None);
        }
        // Bay spot pins (docs/bay-capacities-design.md section
        // 3.3), read from invTypes.csv.bz2 / dgmTypeAttributes.csv.bz2
        // during design: Rifter 587 cargo 140.0 (invTypes capacity),
        // drone 0.0 / bandwidth 0.0 (dogma 283/1271), volume
        // 27289.0; Tristan 593 140.0/40.0/25.0; Capsule 670 cargo
        // 0.0 present (not absent); Primae 2863 cargo 100.0 with
        // no drone keys (dogma rows absent); Thanatos 23911 fighter
        // 70000.0, cargo 875.0, drone 0.0; Hobgoblin II 2456 volume
        // 5.0 and bandwidth-used 5.0; Tritanium 34 volume 0.01;
        // EMP S 185 volume 0.0025; Templar II 40556 volume 1000.0.
        let rifter = types.lookup_by_id(587).expect("Rifter row");
        assert_eq!(rifter.cargo_capacity, Some(140.0));
        assert_eq!(rifter.drone_capacity, Some(0.0));
        assert_eq!(rifter.drone_bandwidth, Some(0.0));
        assert_eq!(rifter.volume, Some(27289.0));
        assert_eq!(rifter.fighter_capacity, None);
        assert_eq!(rifter.drone_bandwidth_used, None);
        let tristan = types.lookup_by_id(593).expect("Tristan row");
        assert_eq!(tristan.cargo_capacity, Some(140.0));
        assert_eq!(tristan.drone_capacity, Some(40.0));
        assert_eq!(tristan.drone_bandwidth, Some(25.0));
        assert_eq!(tristan.fighter_capacity, None);
        let capsule = types.lookup_by_id(670).expect("Capsule row");
        assert_eq!(capsule.cargo_capacity, Some(0.0));
        let primae = types.lookup_by_id(2863).expect("Primae row");
        assert_eq!(primae.cargo_capacity, Some(100.0));
        assert_eq!(primae.drone_capacity, None);
        assert_eq!(primae.drone_bandwidth, None);
        assert_eq!(primae.fighter_capacity, None);
        let thanatos = types.lookup_by_id(23911).expect("Thanatos row");
        assert_eq!(thanatos.fighter_capacity, Some(70000.0));
        assert_eq!(thanatos.cargo_capacity, Some(875.0));
        assert_eq!(thanatos.drone_capacity, Some(0.0));
        let hobgoblin = types.lookup_by_id(2456).expect("Hobgoblin II row");
        assert_eq!(hobgoblin.volume, Some(5.0));
        assert_eq!(hobgoblin.drone_bandwidth_used, Some(5.0));
        let tritanium = types.lookup_by_id(34).expect("Tritanium row");
        assert_eq!(tritanium.volume, Some(0.01));
        assert_eq!(tritanium.cargo_capacity, None);
        let emp = types.lookup_by_id(185).expect("EMP S row");
        assert_eq!(emp.volume, Some(0.0025));
        let templar = types.lookup_by_id(40556).expect("Templar II row");
        assert_eq!(templar.volume, Some(1000.0));
        // Category gate pins: module, rig, and subsystem rows
        // carry volume (every row does) but no ship/drone bay keys.
        for row in [damage_control, rig, subsystem] {
            assert!(row.volume.is_some());
            assert_eq!(row.cargo_capacity, None);
            assert_eq!(row.drone_capacity, None);
            assert_eq!(row.drone_bandwidth, None);
            assert_eq!(row.fighter_capacity, None);
            assert_eq!(row.drone_bandwidth_used, None);
        }
        // Rig calibration spot pins (docs/rig-calibration-design.md
        // section 3.4), read from dgmTypeAttributes.csv.bz2 during
        // design: Rifter 587 upgradeCapacity 400.0, Reaper 588
        // 0.0 present, Capsule 670 absent, rig 31668 upgradeCost
        // 200.0, structure rig 37146 upgradeCost 100.0, Raitaru
        // 35825 upgradeCapacity absent (category-65 gate).
        let rifter = types.lookup_by_id(587).expect("Rifter row");
        assert_eq!(rifter.upgrade_capacity, Some(400.0));
        assert_eq!(rifter.upgrade_cost, None);
        let reaper = types.lookup_by_id(588).expect("Reaper row");
        assert_eq!(reaper.upgrade_capacity, Some(0.0));
        let capsule = types.lookup_by_id(670).expect("Capsule row");
        assert_eq!(capsule.upgrade_capacity, None);
        let rig = types.lookup_by_id(31668).expect("rig row");
        assert_eq!(rig.upgrade_cost, Some(200.0));
        assert_eq!(rig.upgrade_capacity, None);
        let structure_rig = types.lookup_by_id(37146).expect("structure rig row");
        assert_eq!(structure_rig.upgrade_cost, Some(100.0));
        assert_eq!(structure_rig.upgrade_capacity, None);
        let raitaru = types.lookup_by_id(35825).expect("Raitaru row");
        assert_eq!(raitaru.upgrade_capacity, None);
        // Slot layout spot pins (docs/slot-layout-design.md
        // section 3.4), read from dgmTypeAttributes.csv.bz2 /
        // dgmTypeEffects.csv.bz2 during design: Rifter 587 full
        // layout (low 4.0, med 3.0, high 3.0, turret 3.0,
        // launcher 2.0, rig 3.0, maxSubSystems absent); Legion
        // 29986 zeros + 5.0; Capsule 670 absent/present split;
        // Primae 2863 turret absent; Reaper 588 rig absent
        // (1154 trap); 2889/499/405 markers; 37450 turret
        // marker; 35921 launcher marker; no layout keys on
        // 2048/31668/45623.
        let rifter = types.lookup_by_id(587).expect("Rifter row");
        assert_eq!(rifter.low_slots, Some(4.0));
        assert_eq!(rifter.med_slots, Some(3.0));
        assert_eq!(rifter.hi_slots, Some(3.0));
        assert_eq!(rifter.turret_hardpoints, Some(3.0));
        assert_eq!(rifter.launcher_hardpoints, Some(2.0));
        assert_eq!(rifter.rig_slots, Some(3.0));
        assert_eq!(rifter.max_sub_systems, None);
        let legion = types.lookup_by_id(29986).expect("Legion row");
        assert_eq!(legion.low_slots, Some(0.0));
        assert_eq!(legion.med_slots, Some(0.0));
        assert_eq!(legion.hi_slots, Some(0.0));
        assert_eq!(legion.turret_hardpoints, Some(0.0));
        assert_eq!(legion.launcher_hardpoints, Some(0.0));
        assert_eq!(legion.rig_slots, Some(3.0));
        assert_eq!(legion.max_sub_systems, Some(5.0));
        let capsule = types.lookup_by_id(670).expect("Capsule row");
        assert_eq!(capsule.low_slots, None);
        assert_eq!(capsule.med_slots, None);
        assert_eq!(capsule.hi_slots, None);
        assert_eq!(capsule.rig_slots, None);
        assert_eq!(capsule.max_sub_systems, None);
        assert_eq!(capsule.turret_hardpoints, Some(0.0));
        assert_eq!(capsule.launcher_hardpoints, Some(0.0));
        let primae = types.lookup_by_id(2863).expect("Primae row");
        assert_eq!(primae.turret_hardpoints, None);
        assert_eq!(primae.rig_slots, None);
        assert_eq!(primae.med_slots, Some(0.0));
        assert_eq!(primae.hi_slots, Some(0.0));
        assert_eq!(primae.low_slots, Some(4.0));
        assert_eq!(primae.launcher_hardpoints, Some(0.0));
        let reaper = types.lookup_by_id(588).expect("Reaper row");
        assert_eq!(reaper.rig_slots, None);
        let autocannon = types.lookup_by_id(2889).expect("200mm AutoCannon II row");
        assert!(autocannon.turret_fitted);
        assert!(!autocannon.launcher_fitted);
        let launcher = types
            .lookup_by_id(499)
            .expect("Light Missile Launcher I row");
        assert!(launcher.launcher_fitted);
        assert!(!launcher.turret_fitted);
        let shield_booster = types
            .lookup_by_id(405)
            .expect("Micro Remote Shield Booster row");
        assert!(!shield_booster.turret_fitted);
        assert!(!shield_booster.launcher_fitted);
        let ice_laser = types.lookup_by_id(37450).expect("Ice Mining Laser I row");
        assert!(ice_laser.turret_fitted);
        assert!(!ice_laser.launcher_fitted);
        let standup = types
            .lookup_by_id(35921)
            .expect("Standup Anticapital Missile Launcher I row");
        assert!(standup.launcher_fitted);
        assert!(!standup.turret_fitted);
        // No layout keys on module, rig, and subsystem rows.
        for row in [damage_control, rig, subsystem] {
            assert_eq!(row.hi_slots, None);
            assert_eq!(row.med_slots, None);
            assert_eq!(row.low_slots, None);
            assert_eq!(row.rig_slots, None);
            assert_eq!(row.max_sub_systems, None);
            assert_eq!(row.turret_hardpoints, None);
            assert_eq!(row.launcher_hardpoints, None);
            assert!(!row.turret_fitted);
            assert!(!row.launcher_fitted);
        }
        // Navigation and targeting spot pins
        // (docs/nav-targeting-design.md section 7), read from
        // dgmTypeAttributes.csv.bz2 / invTypes.csv.bz2 during
        // design: Rifter 587 warp 5.0 agility 3.2 mass 1067000.0
        // signature 35.0 range 22500.0 scan 660.0 sensors
        // 0.0/8.0/0.0/0.0 targets 4.0; Punisher 597 warp 5.0
        // agility 2.9 mass 1190000.0 signature 37.0 range
        // 25000.0 scan 640.0 sensors 10.0/0.0/0.0/0.0 targets
        // 4.0; Capsule 670 range 0.0 present, targets 0.0
        // present, scanResolution absent, sensors 0.0/3.0/0.0/0.0.
        let rifter = types.lookup_by_id(587).expect("Rifter row");
        assert_eq!(rifter.warp_speed_multiplier, Some(5.0));
        assert_eq!(rifter.agility, Some(3.2));
        assert_eq!(rifter.mass, Some(1067000.0));
        assert_eq!(rifter.signature_radius, Some(35.0));
        assert_eq!(rifter.max_target_range, Some(22500.0));
        assert_eq!(rifter.scan_resolution, Some(660.0));
        assert_eq!(rifter.scan_radar_strength, Some(0.0));
        assert_eq!(rifter.scan_ladar_strength, Some(8.0));
        assert_eq!(rifter.scan_magnetometric_strength, Some(0.0));
        assert_eq!(rifter.scan_gravimetric_strength, Some(0.0));
        assert_eq!(rifter.max_locked_targets, Some(4.0));
        let punisher = types.lookup_by_id(597).expect("Punisher row");
        assert_eq!(punisher.warp_speed_multiplier, Some(5.0));
        assert_eq!(punisher.agility, Some(2.9));
        assert_eq!(punisher.mass, Some(1190000.0));
        assert_eq!(punisher.signature_radius, Some(37.0));
        assert_eq!(punisher.max_target_range, Some(25000.0));
        assert_eq!(punisher.scan_resolution, Some(640.0));
        assert_eq!(punisher.scan_radar_strength, Some(10.0));
        assert_eq!(punisher.scan_ladar_strength, Some(0.0));
        assert_eq!(punisher.scan_magnetometric_strength, Some(0.0));
        assert_eq!(punisher.scan_gravimetric_strength, Some(0.0));
        assert_eq!(punisher.max_locked_targets, Some(4.0));
        let capsule = types.lookup_by_id(670).expect("Capsule row");
        assert_eq!(capsule.max_target_range, Some(0.0));
        assert_eq!(capsule.max_locked_targets, Some(0.0));
        assert_eq!(capsule.scan_resolution, None);
        assert_eq!(capsule.scan_radar_strength, Some(0.0));
        assert_eq!(capsule.scan_ladar_strength, Some(3.0));
        assert_eq!(capsule.scan_magnetometric_strength, Some(0.0));
        assert_eq!(capsule.scan_gravimetric_strength, Some(0.0));
        // No navigation and targeting keys on module, rig, and
        // subsystem rows.
        for row in [damage_control, rig, subsystem] {
            assert_eq!(row.warp_speed_multiplier, None);
            assert_eq!(row.agility, None);
            assert_eq!(row.signature_radius, None);
            assert_eq!(row.max_target_range, None);
            assert_eq!(row.scan_resolution, None);
            assert_eq!(row.scan_radar_strength, None);
            assert_eq!(row.scan_ladar_strength, None);
            assert_eq!(row.scan_magnetometric_strength, None);
            assert_eq!(row.scan_gravimetric_strength, None);
            assert_eq!(row.max_locked_targets, None);
            assert_eq!(row.mass, None);
        }
        // Damage-per-second spot pins
        // (docs/fitting-dps-design.md section 3.2), read
        // from dgmTypeAttributes.csv.bz2 / dgmTypeEffects.csv.bz2
        // during design: 484 cycle 3000.0 (dogma 51, raw
        // milliseconds) and modifier 2.0625 (64); 2404
        // Light Missile Launcher II cycle 12800.0 with no
        // modifier row (a launcher must never gain 64);
        // 180 Proton S damage 3.0/0.0/2.0/0.0 (114/116/117/
        // 118, explicit zeros present, never absent);
        // 23059 Firbolg I both ability markers true (effects
        // 6465/6431), squadron size 9.0, attack thermal
        // 75.0, attack duration 5000.0; 23911 Thanatos
        // tubes 3.0 with heavy slots absent (the pure layer
        // reads absent as a 0 cap, the catalogue never
        // invents it).
        let autocannon = types
            .lookup_by_id(484)
            .expect("125mm Gatling AutoCannon I row");
        assert_eq!(autocannon.speed, Some(3000.0));
        assert_eq!(autocannon.damage_multiplier, Some(2.0625));
        let launcher = types
            .lookup_by_id(2404)
            .expect("Light Missile Launcher II row");
        assert_eq!(launcher.speed, Some(12800.0));
        assert_eq!(launcher.damage_multiplier, None);
        let proton = types.lookup_by_id(180).expect("Proton S row");
        assert_eq!(proton.em_damage, Some(3.0));
        assert_eq!(proton.kinetic_damage, Some(2.0));
        assert_eq!(proton.explosive_damage, Some(0.0));
        assert_eq!(proton.thermal_damage, Some(0.0));
        let firbolg = types.lookup_by_id(23059).expect("Firbolg I row");
        assert!(firbolg.fighter_ability_attack);
        assert!(firbolg.fighter_ability_missiles);
        assert_eq!(firbolg.fighter_squadron_max_size, Some(9.0));
        assert_eq!(firbolg.fighter_attack_damage_therm, Some(75.0));
        assert_eq!(firbolg.fighter_attack_duration, Some(5000.0));
        let thanatos = types.lookup_by_id(23911).expect("Thanatos row");
        assert_eq!(thanatos.fighter_tubes, Some(3.0));
        assert_eq!(thanatos.fighter_heavy_slots, None);
        // No DPS keys on module, rig, and subsystem rows,
        // and no tube keys on a non-carrier hull.
        for row in [damage_control, rig, subsystem] {
            assert_eq!(row.speed, None);
            assert_eq!(row.damage_multiplier, None);
            assert_eq!(row.em_damage, None);
            assert_eq!(row.fighter_tubes, None);
            assert!(!row.fighter_ability_attack);
            assert!(!row.fighter_ability_missiles);
        }
        let rifter = types.lookup_by_id(587).expect("Rifter row");
        assert_eq!(rifter.fighter_tubes, None);
        assert_eq!(rifter.speed, None);
    }

    #[test]
    fn fixture_parse_dps_fields() {
        // A row with the new keys loads into the new fields;
        // a row without them loads with all None/false (old-
        // catalogue tolerance, the twins' `default` pattern).
        let with_keys = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":484,"typeName":"125mm Gatling AutoCannon I","categoryId":7,"slotEffects":[12],"speed":3000.0,"damageMultiplier":2.0625},
                {"typeId":23059,"typeName":"Firbolg I","categoryId":87,"slotEffects":[],"fighterSquadronMaxSize":9.0,"fighterAbilityAttackM":true}]}"#,
        )
        .expect("fixture parses");
        let gun = with_keys.lookup_by_id(484).expect("gun row");
        assert_eq!(gun.speed, Some(3000.0));
        assert_eq!(gun.damage_multiplier, Some(2.0625));
        let firbolg = with_keys.lookup_by_id(23059).expect("fighter row");
        assert_eq!(firbolg.fighter_squadron_max_size, Some(9.0));
        assert!(firbolg.fighter_ability_attack);
        assert!(!firbolg.fighter_ability_missiles);

        let without_keys = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[]}]}"#,
        )
        .expect("fixture parses");
        let ship = without_keys.lookup_by_id(587).expect("Rifter row");
        assert_eq!(ship.speed, None);
        assert_eq!(ship.damage_multiplier, None);
        assert_eq!(ship.em_damage, None);
        assert_eq!(ship.fighter_squadron_max_size, None);
        assert_eq!(ship.fighter_tubes, None);
        assert_eq!(ship.fighter_heavy_slots, None);
        assert!(!ship.fighter_ability_attack);
        assert!(!ship.fighter_ability_missiles);
    }

    #[test]
    fn fixture_parse_slot_layout_fields() {
        // A row with the new keys loads into the new fields; a
        // row without them loads with all None/false (old-
        // catalogue tolerance, the twins' `default` pattern).
        let with_keys = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"hiSlots":3.0,"turretFitted":true},
                {"typeId":2889,"typeName":"200mm AutoCannon II","categoryId":7,"slotEffects":[12],"turretFitted":true}]}"#,
        )
        .expect("fixture parses");
        let ship = with_keys.lookup_by_id(587).expect("Rifter row");
        assert_eq!(ship.hi_slots, Some(3.0));
        assert!(ship.turret_fitted);
        assert!(!ship.launcher_fitted);
        let module = with_keys.lookup_by_id(2889).expect("module row");
        assert!(module.turret_fitted);

        let without_keys = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[]}]}"#,
        )
        .expect("fixture parses");
        let ship = without_keys.lookup_by_id(587).expect("Rifter row");
        assert_eq!(ship.hi_slots, None);
        assert_eq!(ship.med_slots, None);
        assert_eq!(ship.low_slots, None);
        assert_eq!(ship.rig_slots, None);
        assert_eq!(ship.max_sub_systems, None);
        assert_eq!(ship.turret_hardpoints, None);
        assert_eq!(ship.launcher_hardpoints, None);
        assert!(!ship.turret_fitted);
        assert!(!ship.launcher_fitted);
    }
}
