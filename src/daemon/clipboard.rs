//! SDE-validated clipboard classification for EFT fits, DNA links,
//! and survey scans.
//!
//! The classifier never reads the OS clipboard; `arboard` polling is
//! shell wiring behind an opt-in guard. Classification is validated
//! against the bundled [`FittingTypes`] catalogue: a paste is only
//! recognized when the repo's real importers
//! ([`crate::fitting::eft::parse_eft`] /
//! [`crate::fitting::dna::parse_dna`]) resolve its hull to a known
//! ship (category 6), or when every survey row names a known
//! asteroid (category 25). Shape-only guesses are never recognized,
//! so everyday text (times, JSON arrays, spreadsheet rows) is
//! `Ignored`, dropped in memory, and never logged beyond its variant,
//! never persisted, and never displayed. Recognized kinds carry only
//! the catalogue-resolved hull name (never the user's fit name or any
//! other clipboard substring) or a survey row count.

use crate::fitting::dna::parse_dna;
use crate::fitting::eft::{parse_eft, EftImportOutcome, ImportFormat, ImportedFitting};
use crate::names::fitting_types::{FittingTypes, NameLookup};

/// EVE asteroid/ore category in the bundled catalogue (the survey
/// scanner's first column must resolve to a row in this category).
const CATEGORY_ASTEROID: i64 = 25;
/// EVE ship category; importers already enforce it for hulls.
const CATEGORY_SHIP: i64 = 6;

/// Recognized clipboard payloads. Only catalogue-resolved hull names
/// and counts are carried, so nothing copied from the clipboard can
/// be echoed back on screen. `Ignored` carries nothing.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ClipboardKind {
    EftFit { ship: String },
    ShipDna { ship: String },
    SurveyScan { rows: usize },
    Ignored,
}

impl ClipboardKind {
    pub fn variant_name(&self) -> &'static str {
        match self {
            Self::EftFit { .. } => "EftFit",
            Self::ShipDna { .. } => "ShipDna",
            Self::SurveyScan { .. } => "SurveyScan",
            Self::Ignored => "Ignored",
        }
    }
}

/// Hash-only dedupe key for clipboard text: the raw text is never
/// stored, logged, or persisted beyond the classify call.
pub fn clipboard_text_hash(text: &str) -> u64 {
    use std::hash::{Hash, Hasher};
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    text.hash(&mut hasher);
    hasher.finish()
}

/// Pure demo / opt-in guard for the clipboard poller.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ClipboardGuard {
    pub demo: bool,
    pub clipboard_opt_in: bool,
}

impl ClipboardGuard {
    pub fn may_poll(self) -> bool {
        !self.demo && self.clipboard_opt_in
    }
}

/// Run one guarded clipboard read through `read` and classify it
/// against the bundled catalogue.
///
/// When the guard denies polling, `read` is never called (zero
/// reads). `Ignored` results collapse to `None`: dropped, never
/// persisted. A recognized kind surfaces only as a typed suggestion;
/// this function never mutates any active fit.
pub fn poll_clipboard_once(
    guard: ClipboardGuard,
    types: &FittingTypes,
    read: impl FnOnce() -> Option<String>,
) -> Option<ClipboardKind> {
    if !guard.may_poll() {
        tracing::debug!(
            "[DAEMON] clipboard poll skipped demo={} opt_in={}",
            guard.demo,
            guard.clipboard_opt_in
        );
        return None;
    }
    let text = read()?;
    match classify_validated(&text, types) {
        ClipboardKind::Ignored => None,
        kind => Some(kind),
    }
}

fn is_survey_number(field: &str) -> bool {
    let mut cleaned = field.trim();
    for suffix in ["m³", "m3", "km", "m"] {
        if let Some(rest) = cleaned.strip_suffix(suffix) {
            cleaned = rest.trim();
            break;
        }
    }
    let cleaned: String = cleaned.replace([',', ' '], "");
    !cleaned.is_empty()
        && cleaned.chars().all(|c| c.is_ascii_digit() || c == '.')
        && cleaned.chars().any(|c| c.is_ascii_digit())
        && cleaned.matches('.').count() <= 1
}

fn classify_survey_validated(text: &str, types: &FittingTypes) -> Option<usize> {
    let lines: Vec<&str> = text.lines().filter(|l| !l.trim().is_empty()).collect();
    if lines.is_empty() {
        return None;
    }
    for line in &lines {
        let cols: Vec<&str> = line.split('\t').collect();
        // Survey format: name, quantity, then volume/distance columns.
        if cols.len() < 3 {
            return None;
        }
        let name = cols[0].trim();
        if name.is_empty() {
            return None;
        }
        // First column must be a known asteroid/ore (category 25)
        // resolved from bundled data via FittingTypes.
        match types.lookup(name) {
            NameLookup::Found(row) if row.category_id == CATEGORY_ASTEROID => {}
            _ => return None,
        }
        // Quantity column must be numeric.
        if !is_survey_number(cols[1]) {
            return None;
        }
        // At least one further column (volume / distance) numeric.
        if !cols[2..].iter().any(|col| is_survey_number(col)) {
            return None;
        }
    }
    Some(lines.len())
}

fn kind_from_import(fitting: &ImportedFitting) -> ClipboardKind {
    // Hull was already resolved to category 6 by the importer; the
    // name carried forward is the catalogue-canonical hull name.
    debug_assert!(!fitting.ship_name.is_empty());
    match fitting.format {
        ImportFormat::Dna => ClipboardKind::ShipDna {
            ship: fitting.ship_name.clone(),
        },
        _ => ClipboardKind::EftFit {
            ship: fitting.ship_name.clone(),
        },
    }
}

/// Classify one clipboard string in memory against the bundled
/// catalogue. No OS access; the text itself is never logged (the
/// variant only, never its length or any substring).
pub fn classify_validated(text: &str, types: &FittingTypes) -> ClipboardKind {
    let trimmed = text.trim();
    let kind = classify_validated_inner(trimmed, types);
    tracing::debug!(
        "[DAEMON] clipboard classify variant={}",
        kind.variant_name()
    );
    kind
}

fn classify_validated_inner(trimmed: &str, types: &FittingTypes) -> ClipboardKind {
    if trimmed.is_empty() {
        return ClipboardKind::Ignored;
    }
    // Survey scans are tab-separated and cannot be fits; validate
    // strictly first so tabbed everyday rows are decided by the
    // asteroid catalogue, not by fit shape.
    if trimmed.contains('\t') {
        if let Some(rows) = classify_survey_validated(trimmed, types) {
            return ClipboardKind::SurveyScan { rows };
        }
        return ClipboardKind::Ignored;
    }
    // EFT: first non-blank line starts with '['. Accept only when
    // the real EFT importer resolves the hull to a known ship.
    let first = trimmed.lines().next().unwrap_or("").trim();
    let _ = CATEGORY_SHIP; // hull category enforced inside the importers
    if first.starts_with('[') {
        return match parse_eft(trimmed, types) {
            // An EFT header with no fit name is not a recognized fit.
            EftImportOutcome::Imported(fitting) if !fitting.name.trim().is_empty() => {
                kind_from_import(&fitting)
            }
            _ => ClipboardKind::Ignored,
        };
    }
    // DNA: optional `fitting:` prefix, then the real DNA importer.
    // Accept only when it resolves the ship type id to a known ship.
    let dna_text = trimmed.strip_prefix("fitting:").unwrap_or(trimmed);
    match parse_dna(dna_text, types) {
        // Strict for a suggestion: every segment must resolve (no
        // issues) and at least one fitted item must be present, so
        // colon-separated everyday strings cannot validate on the
        // hull alone while their other segments fail.
        EftImportOutcome::Imported(fitting)
            if fitting.report.issues.is_empty() && fitting.report.imported_lines > 0 =>
        {
            kind_from_import(&fitting)
        }
        _ => ClipboardKind::Ignored,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture_types() -> FittingTypes {
        FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[]},
                {"typeId":626,"typeName":"Vexor","categoryId":6,"slotEffects":[]},
                {"typeId":2001,"typeName":"Test High Module","categoryId":7,"slotEffects":[12]},
                {"typeId":1230,"typeName":"Veldspar","categoryId":25,"slotEffects":[]},
                {"typeId":1228,"typeName":"Scordite","categoryId":25,"slotEffects":[]},
                {"typeId":1224,"typeName":"Pyroxeres","categoryId":25,"slotEffects":[]}]}"#,
        )
        .expect("fixture catalogue")
    }

    #[test]
    fn validated_fixtures_have_full_precision() {
        let types = fixture_types();
        let cases: Vec<(&str, ClipboardKind)> = vec![
            (
                "[Rifter, Brawl]\n200mm AutoCannon I\n[Empty Low slot]\n",
                ClipboardKind::EftFit {
                    ship: "Rifter".into(),
                },
            ),
            (
                "[Vexor, Drone Boat]\n",
                ClipboardKind::EftFit {
                    ship: "Vexor".into(),
                },
            ),
            (
                "fitting:587:2001;1::",
                ClipboardKind::ShipDna {
                    ship: "Rifter".into(),
                },
            ),
            (
                "587:2001;1::",
                ClipboardKind::ShipDna {
                    ship: "Rifter".into(),
                },
            ),
            (
                "Veldspar\t10000\t1000 m3\t5 km\nScordite\t5000\t750 m3\t7 km\n",
                ClipboardKind::SurveyScan { rows: 2 },
            ),
            (
                "Pyroxeres\t12,345\t1,234.5 m3\t10 km",
                ClipboardKind::SurveyScan { rows: 1 },
            ),
            // Negatives: everyday text must be Ignored (P1-2).
            ("10:15:30", ClipboardKind::Ignored),
            ("8080:80", ClipboardKind::Ignored),
            ("[1, 2, 3]", ClipboardKind::Ignored),
            ("[\"a\", \"b\"]", ClipboardKind::Ignored),
            ("[Alice, Bob]", ClipboardKind::Ignored),
            ("Rent\t1200\t2026", ClipboardKind::Ignored),
            ("SSN\t123\t45", ClipboardKind::Ignored),
            ("hello world, just chatting", ClipboardKind::Ignored),
            ("[Empty Low slot]", ClipboardKind::Ignored),
            ("[Rifter]", ClipboardKind::Ignored),
            ("[Rifter, ]", ClipboardKind::Ignored),
            ("https://example.com/fit/587:11577", ClipboardKind::Ignored),
            ("fitting:abc:11577::", ClipboardKind::Ignored),
            ("587:notanumber::", ClipboardKind::Ignored),
            ("Veldspar,10000,1000", ClipboardKind::Ignored),
            ("12:30:45 timestamp text", ClipboardKind::Ignored),
            ("", ClipboardKind::Ignored),
            ("{\"fit\": 587}", ClipboardKind::Ignored),
            ("name\tvalue\nfoo\tbar", ClipboardKind::Ignored),
            // Unknown hull / unknown ore never validate.
            ("[NoSuchShip, Fit]\n", ClipboardKind::Ignored),
            ("999999:2001;1::", ClipboardKind::Ignored),
            ("Unobtainium\t100\t10 m3\t1 km", ClipboardKind::Ignored),
        ];
        assert!(cases.len() >= 12);
        for (input, expected) in cases {
            assert_eq!(
                classify_validated(input, &types),
                expected,
                "input variant mismatch"
            );
        }
    }

    #[test]
    fn eft_carries_only_sde_resolved_hull_name() {
        let types = fixture_types();
        // The user's fit name ("Secret Brawl Name") must not survive.
        let kind = classify_validated("[Rifter, Secret Brawl Name]\n", &types);
        assert_eq!(
            kind,
            ClipboardKind::EftFit {
                ship: "Rifter".into()
            }
        );
        assert!(!format!("{kind:?}").contains("Secret"));
    }

    #[test]
    fn survey_requires_known_ore_and_numeric_columns() {
        let types = fixture_types();
        assert_eq!(
            classify_validated("a,b,c\n1,2,3", &types),
            ClipboardKind::Ignored
        );
        assert!(matches!(
            classify_validated("Veldspar\t100\t10 m3\t1 km", &types),
            ClipboardKind::SurveyScan { rows: 1 }
        ));
        // One bad row poisons the whole paste.
        assert_eq!(
            classify_validated("Veldspar\t100\t10 m3\t1 km\nRent\t5\t6\t7", &types),
            ClipboardKind::Ignored
        );
    }

    #[test]
    fn bundled_catalogue_recognizes_real_rifter_and_veldspar() {
        let types = FittingTypes::load_bundled().expect("bundled catalogue loads");
        assert_eq!(
            classify_validated("[Rifter, Brawl]\n", &types),
            ClipboardKind::EftFit {
                ship: "Rifter".into()
            }
        );
        assert!(matches!(
            classify_validated("587:486;1::", &types),
            ClipboardKind::ShipDna { .. }
        ));
        assert!(matches!(
            classify_validated("Veldspar\t10000\t1000 m3\t5 km", &types),
            ClipboardKind::SurveyScan { rows: 1 }
        ));
        for negative in [
            "10:15:30",
            "8080:80",
            "[1, 2, 3]",
            "[\"a\", \"b\"]",
            "[Alice, Bob]",
            "Rent\t1200\t2026",
            "SSN\t123\t45",
        ] {
            assert_eq!(
                classify_validated(negative, &types),
                ClipboardKind::Ignored,
                "bundled negative must be Ignored"
            );
        }
    }
}
