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
    }
}
