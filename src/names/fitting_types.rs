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
                || row.max_velocity.is_some();
            for value in [
                row.shield_capacity,
                row.armor_hp,
                row.hull_hp,
                row.capacitor_capacity,
                row.max_velocity,
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
                        && row.max_velocity.is_some(),
                    "ship without all five base stats: {:?}",
                    row.name
                );
            } else {
                assert!(
                    !has_base_stat,
                    "non-ship carrying base ship stats: {:?}",
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
        }
    }
}
