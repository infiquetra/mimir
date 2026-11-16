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
        Ok(Self {
            types,
            by_normalized,
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
        }
    }
}
