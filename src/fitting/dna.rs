//! Pure DNA (EVE fitting-link) parser and format router for fitting
//! import.
//!
//! A DNA link is the single colon-separated line of type numbers the
//! EVE client produces ("Copy to clipboard"): a ship number, then
//! item segments, ending in `::`. Every number resolves against the
//! bundled catalogue offline; the parser is pure — no egui, no state,
//! no network, no database — mirroring `parse_eft` in
//! [`super::eft`]. Strictness follows the strict AAR adapter
//! (`aar_fit_import_parser.dart` at `ed698d3`), expressed through
//! the shipped per-segment report model, so every segment is
//! accounted and never silently dropped. The parser never panics
//! on any input, never guesses a name, never renders a pasted
//! number as if it were a name, and logs counts only — never
//! pasted text.
//!
//! Grounding: `docs/fittings-dna-import-design.md` sections 4–7.

use super::eft::{
    slot_section, EftImportOutcome, ImportFatal, ImportFormat, ImportIssue, ImportIssueKind,
    ImportReport, ImportedFitting, ImportedItem, CATEGORY_MODULE, CATEGORY_SHIP,
    CATEGORY_SUBSYSTEM, MAX_EFT_IMPORT_BYTES, MAX_STACK_QUANTITY,
};
use crate::names::fitting_types::FittingTypes;

/// Maximum accounted body segments in one DNA link (design section
/// 5.3, in the 1,000-line EFT cap family).
pub const MAX_DNA_SEGMENTS: usize = 1_000;
/// Maximum expanded fitted items in one DNA link (the AAR
/// `maxExpandedModules` value verbatim, design section 5.3).
pub const MAX_DNA_EXPANDED_ITEMS: usize = 4_096;

fn failed(fatal: ImportFatal) -> EftImportOutcome {
    tracing::debug!("[FITTING] parse failed fatal={fatal:?}");
    EftImportOutcome::Failed(fatal)
}

/// The one positive-number validator of design section 4.5,
/// shared by the ship field, item fields, and quantity fields:
/// non-empty, at most 10 characters, all ASCII digits, never
/// starting with `0`, value at most `MAX_STACK_QUANTITY`.
fn parse_positive_number(field: &str) -> Option<i64> {
    if field.is_empty() || field.len() > 10 {
        return None;
    }
    if !field.bytes().all(|byte| byte.is_ascii_digit()) {
        return None;
    }
    if field.starts_with('0') {
        return None;
    }
    let value: i64 = field.parse().ok()?;
    if value > MAX_STACK_QUANTITY {
        return None;
    }
    Some(value)
}

/// Display text for one segment issue (design section 6.3): the
/// canonical catalogue name when the segment's first field is a
/// valid number resolving by lookup, else the fixed
/// `unresolved item`. Display-only; never changes the kind.
fn display_text(first_field: &str, types: &FittingTypes) -> String {
    parse_positive_number(first_field)
        .and_then(|type_id| types.lookup_by_id(type_id))
        .map(|row| row.name.clone())
        .unwrap_or_else(|| "unresolved item".to_string())
}

/// Parse a DNA fitting link against the bundled catalogue.
/// Pure: no egui, no state, no network, no database.
pub fn parse_dna(text: &str, types: &FittingTypes) -> EftImportOutcome {
    tracing::debug!("[FITTING] parse_dna bytes={}", text.len());
    // Bounds first (design section 4.1): over-limit input is
    // refused whole on the raw paste, mirroring `parse_eft`.
    if text.len() > MAX_EFT_IMPORT_BYTES {
        return failed(ImportFatal::TooLarge);
    }
    // AAR line-ending normalization: CRLF first, then lone CR.
    let normalized = text.replace("\r\n", "\n").replace('\r', "\n");
    // A leading byte-order mark (U+FEFF) is dropped, as in `parse_eft`.
    let body: &str = normalized.strip_prefix('\u{FEFF}').unwrap_or(&normalized);
    let trimmed = body.trim();
    if trimmed.is_empty() {
        return failed(ImportFatal::Empty);
    }
    // Single line only: leading and trailing blank lines are gone
    // after the trim, so any remaining line feed means the paste
    // holds more than one link.
    if trimmed.contains('\n') {
        return failed(ImportFatal::DnaMalformed);
    }
    let parts: Vec<&str> = trimmed.split(':').collect();
    if parts.len() < 2 {
        return failed(ImportFatal::DnaMalformed);
    }
    let Some(&ship_field) = parts.first() else {
        return failed(ImportFatal::DnaMalformed);
    };
    let Some(ship_id) = parse_positive_number(ship_field) else {
        return failed(ImportFatal::DnaMalformed);
    };
    let Some(ship_row) = types.lookup_by_id(ship_id) else {
        return failed(ImportFatal::DnaShipUnknown);
    };
    if ship_row.category_id != CATEGORY_SHIP {
        return failed(ImportFatal::DnaShipNotShip);
    }
    let ship_name = ship_row.name.clone();
    let ship_type_id = ship_row.type_id;
    // Strip at most two trailing empty parts: the `::` terminator
    // the EVE client writes. Zero, one, or two trailing colons are
    // all accepted; the terminator carries no segment.
    let mut candidates: Vec<&str> = parts.iter().skip(1).copied().collect();
    let mut stripped: usize = 0;
    while stripped < 2 {
        let trailing_empty = matches!(candidates.last(), Some(&last) if last.is_empty());
        if trailing_empty {
            candidates.pop();
            stripped = stripped.saturating_add(1);
        } else {
            break;
        }
    }
    // Segment cap: refused whole, never truncated.
    if candidates.len() > MAX_DNA_SEGMENTS {
        return failed(ImportFatal::DnaTooManySegments);
    }
    let mut items: Vec<ImportedItem> = Vec::new();
    let mut imported_lines: usize = 0;
    let mut issues: Vec<ImportIssue> = Vec::new();
    let mut total_expanded: usize = 0;
    for (index, segment) in candidates.iter().enumerate() {
        let line = index.saturating_add(1);
        if segment.is_empty() {
            issues.push(ImportIssue {
                line,
                text: String::new(),
                kind: ImportIssueKind::EmptySegment,
            });
            continue;
        }
        let fields: Vec<&str> = segment.split(';').collect();
        if fields.len() > 2 {
            let first_field = fields.first().copied().unwrap_or("");
            issues.push(ImportIssue {
                line,
                text: display_text(first_field, types),
                kind: ImportIssueKind::ExtraSegmentFields,
            });
            continue;
        }
        let first_field = fields.first().copied().unwrap_or("");
        let Some(type_id) = parse_positive_number(first_field) else {
            issues.push(ImportIssue {
                line,
                text: display_text(first_field, types),
                kind: ImportIssueKind::InvalidTypeId,
            });
            continue;
        };
        let quantity: i64 = if fields.len() == 2 {
            let quantity_field = fields.get(1).copied().unwrap_or("");
            let Some(quantity) = parse_positive_number(quantity_field) else {
                issues.push(ImportIssue {
                    line,
                    text: display_text(first_field, types),
                    kind: ImportIssueKind::InvalidSegmentQuantity,
                });
                continue;
            };
            quantity
        } else {
            1
        };
        let Some(row) = types.lookup_by_id(type_id) else {
            issues.push(ImportIssue {
                line,
                text: display_text(first_field, types),
                kind: ImportIssueKind::UnknownTypeId,
            });
            continue;
        };
        if row.category_id != CATEGORY_MODULE && row.category_id != CATEGORY_SUBSYSTEM {
            issues.push(ImportIssue {
                line,
                text: row.name.clone(),
                kind: ImportIssueKind::UnsupportedDnaItem,
            });
            continue;
        }
        let Some(section) = slot_section(&row.slot_effects) else {
            issues.push(ImportIssue {
                line,
                text: row.name.clone(),
                kind: ImportIssueKind::NoSlotForModule,
            });
            continue;
        };
        // Checked before expanding: the items vector never grows
        // past the expanded cap whatever quantities spell.
        let quantity_usize = usize::try_from(quantity).unwrap_or(usize::MAX);
        let Some(new_total) = total_expanded.checked_add(quantity_usize) else {
            return failed(ImportFatal::DnaTooManyItems);
        };
        if new_total > MAX_DNA_EXPANDED_ITEMS {
            return failed(ImportFatal::DnaTooManyItems);
        }
        total_expanded = new_total;
        for _ in 0..quantity_usize {
            items.push(ImportedItem {
                type_id: row.type_id,
                name: row.name.clone(),
                section,
                quantity: 1,
                charge: None,
            });
        }
        imported_lines = imported_lines.saturating_add(1);
    }
    tracing::debug!(
        "[FITTING] parse_dna complete segments={} items={} issues={}",
        candidates.len(),
        items.len(),
        issues.len()
    );
    EftImportOutcome::Imported(ImportedFitting {
        name: format!("Imported {ship_name}"),
        ship_type_id,
        ship_name,
        format: ImportFormat::Dna,
        items,
        report: ImportReport {
            imported_lines,
            placeholder_lines: 0,
            charges_noted: 0,
            issues,
        },
    })
}

/// Route one paste to the EFT or DNA parser by bracket (design
/// section 7, the AAR `_firstNonemptyStartsWithBracket` rule).
/// There is no fallback in either direction.
pub fn parse_import(text: &str, types: &FittingTypes) -> EftImportOutcome {
    // Replicate the parsers' normalisation for scanning only.
    let normalized = text.replace("\r\n", "\n").replace('\r', "\n");
    let body: &str = normalized.strip_prefix('\u{FEFF}').unwrap_or(&normalized);
    let mut route_eft = true;
    let mut saw_non_blank = false;
    for line in body.split('\n') {
        let line_trimmed = line.trim();
        if line_trimmed.is_empty() {
            continue;
        }
        saw_non_blank = true;
        route_eft = line_trimmed.starts_with('[');
        break;
    }
    let use_eft = !saw_non_blank || route_eft;
    tracing::debug!(
        "[FITTING] parse_import format={}",
        if use_eft { "eft" } else { "dna" }
    );
    if use_eft {
        super::eft::parse_eft(text, types)
    } else {
        parse_dna(text, types)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fitting::eft::{parse_eft, ImportSection};
    use crate::fitting::write_map::build_save_request;
    use crate::ui::fittings::fitting_to_eft;

    /// Small hand-written catalogue reusing the EFT fixture
    /// numbers so the files read alike (design section 11).
    const FIXTURE_JSON: &str = r#"{"types":[
        {"typeId":1003,"typeName":"Solo Ship","categoryId":6,"slotEffects":[]},
        {"typeId":1001,"typeName":"Test Ship","categoryId":6,"slotEffects":[]},
        {"typeId":1002,"typeName":"Test Ship","categoryId":6,"slotEffects":[]},
        {"typeId":2001,"typeName":"Test Low Module","categoryId":7,"slotEffects":[11]},
        {"typeId":2002,"typeName":"Test Med Module","categoryId":7,"slotEffects":[13]},
        {"typeId":2003,"typeName":"Test High Module","categoryId":7,"slotEffects":[12]},
        {"typeId":2004,"typeName":"Test Rig Module","categoryId":7,"slotEffects":[2663]},
        {"typeId":2005,"typeName":"Test Subsystem","categoryId":32,"slotEffects":[3772]},
        {"typeId":2006,"typeName":"Test Noslot Module","categoryId":7,"slotEffects":[]},
        {"typeId":3001,"typeName":"Test Drone","categoryId":18,"slotEffects":[]},
        {"typeId":3002,"typeName":"Test Fighter","categoryId":87,"slotEffects":[]},
        {"typeId":4001,"typeName":"Test Charge","categoryId":8,"slotEffects":[]},
        {"typeId":5001,"typeName":"Test Widget","categoryId":4,"slotEffects":[]},
        {"typeId":6001,"typeName":"Test Dup","categoryId":7,"slotEffects":[11]},
        {"typeId":6002,"typeName":"Test Dup","categoryId":7,"slotEffects":[11]}]}"#;

    fn test_types() -> FittingTypes {
        FittingTypes::from_json(FIXTURE_JSON).expect("fixture parses")
    }

    fn bundled_types() -> FittingTypes {
        FittingTypes::load_bundled().expect("bundled catalogue loads")
    }

    fn imported(text: &str, types: &FittingTypes) -> ImportedFitting {
        match parse_dna(text, types) {
            EftImportOutcome::Imported(fitting) => fitting,
            EftImportOutcome::Failed(fatal) => panic!("expected import, got {fatal:?}"),
        }
    }

    fn imported_via_router(text: &str, types: &FittingTypes) -> ImportedFitting {
        match parse_import(text, types) {
            EftImportOutcome::Imported(fitting) => fitting,
            EftImportOutcome::Failed(fatal) => panic!("expected import, got {fatal:?}"),
        }
    }

    fn fatal(text: &str, types: &FittingTypes) -> ImportFatal {
        match parse_dna(text, types) {
            EftImportOutcome::Failed(fatal) => fatal,
            EftImportOutcome::Imported(_) => panic!("expected failure"),
        }
    }

    fn fatal_via_router(text: &str, types: &FittingTypes) -> ImportFatal {
        match parse_import(text, types) {
            EftImportOutcome::Failed(fatal) => fatal,
            EftImportOutcome::Imported(_) => panic!("expected failure"),
        }
    }

    fn issue_kinds(fitting: &ImportedFitting) -> Vec<ImportIssueKind> {
        fitting
            .report
            .issues
            .iter()
            .map(|issue| issue.kind)
            .collect()
    }

    /// Independent recount of accounted segments for the
    /// invariant, twinned on the EFT `assert_invariant`.
    fn accounted_segments(text: &str) -> usize {
        let normalized = text.replace("\r\n", "\n").replace('\r', "\n");
        let body: &str = normalized.strip_prefix('\u{FEFF}').unwrap_or(&normalized);
        let trimmed = body.trim();
        let parts: Vec<&str> = trimmed.split(':').collect();
        let mut candidates: Vec<&str> = parts.iter().skip(1).copied().collect();
        let mut stripped: usize = 0;
        while stripped < 2 {
            let trailing_empty = matches!(candidates.last(), Some(&last) if last.is_empty());
            if trailing_empty {
                candidates.pop();
                stripped = stripped.saturating_add(1);
            } else {
                break;
            }
        }
        candidates.len()
    }

    fn assert_invariant(text: &str, fitting: &ImportedFitting) {
        assert_eq!(
            fitting.report.imported_lines + fitting.report.issues.len(),
            accounted_segments(text),
            "imported+issues must equal accounted segments"
        );
        assert_eq!(fitting.report.placeholder_lines, 0);
        assert_eq!(fitting.report.charges_noted, 0);
        assert_eq!(fitting.format, ImportFormat::Dna);
    }

    #[test]
    fn bundled_round_trip_oracle() {
        let types = bundled_types();
        let fitting = imported("587:2048;2::", &types);
        assert_eq!(fitting.ship_type_id, 587);
        assert_eq!(fitting.ship_name, "Rifter");
        assert_eq!(fitting.name, "Imported Rifter");
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.items.len(), 2);
        assert_eq!(fitting.items[0].type_id, 2048);
        assert_eq!(fitting.items[0].name, "Damage Control II");
        assert_eq!(fitting.items[0].section, ImportSection::Low);
        assert_eq!(fitting.items[0].quantity, 1);
        assert_eq!(fitting.items[1].type_id, 2048);
        assert_eq!(fitting.report.imported_lines, 1);
        assert_invariant("587:2048;2::", &fitting);
        let synth = fitting.to_character_fitting();
        let local = fitting.name_resolver();
        let export = fitting_to_eft(&synth, &local).expect("re-exports");
        assert_eq!(export.skipped_unknown, 0);
        assert_eq!(export.skipped_empty, 0);
        assert!(export.text.starts_with("[Rifter, Imported Rifter]"));
        let dc_count = export.text.matches("Damage Control II").count();
        assert_eq!(dc_count, 2);
        let reimported = match parse_eft(&export.text, &types) {
            EftImportOutcome::Imported(re) => re,
            EftImportOutcome::Failed(f) => panic!("re-import must succeed, got {f:?}"),
        };
        assert_eq!(reimported.items.len(), 2);
        assert!(reimported.report.issues.is_empty());
    }

    #[test]
    fn bundled_expansion_oracle() {
        let types = bundled_types();
        let fitting = imported("587:2048;2:5973;1:484;3::", &types);
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.items.len(), 6);
        let sections: Vec<ImportSection> = fitting.items.iter().map(|item| item.section).collect();
        assert_eq!(
            sections,
            vec![
                ImportSection::Low,
                ImportSection::Low,
                ImportSection::Medium,
                ImportSection::High,
                ImportSection::High,
                ImportSection::High,
            ]
        );
        let ids: Vec<i64> = fitting.items.iter().map(|item| item.type_id).collect();
        assert_eq!(ids, vec![2048, 2048, 5973, 484, 484, 484]);
        assert_eq!(fitting.report.imported_lines, 3);
        assert_invariant("587:2048;2:5973;1:484;3::", &fitting);
    }

    #[test]
    fn bundled_minimal_and_inverted_oracles() {
        let types = bundled_types();
        let fitting = imported("587:2048;1::", &types);
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].type_id, 2048);
        assert_invariant("587:2048;1::", &fitting);
        let fitting = imported("587:999999;1::", &types);
        assert!(fitting.items.is_empty());
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::UnknownTypeId]);
        assert_eq!(fitting.report.issues[0].line, 1);
        assert_eq!(fitting.report.issues[0].text, "unresolved item");
        assert_eq!(fitting.report.imported_lines, 0);
        assert_invariant("587:999999;1::", &fitting);
    }

    #[test]
    fn routing_colon_in_fit_name_and_no_fallback() {
        let types = bundled_types();
        let fitting = imported_via_router("[Rifter, PvP: Armor]\nDamage Control II", &types);
        assert_eq!(fitting.name, "PvP: Armor");
        assert_eq!(fitting.format, ImportFormat::Eft);
        assert_eq!(fitting.items.len(), 1);
        // A malformed `[` paste fails as EFT, never DNA.
        assert_eq!(
            fatal_via_router("[Rifter Fit]\nDamage Control II", &types),
            ImportFatal::HeaderMalformed
        );
        // parse_eft on DNA stays HeaderMalformed (shipped test untouched).
        match parse_eft("587:2048;1::", &types) {
            EftImportOutcome::Failed(f) => assert_eq!(f, ImportFatal::HeaderMalformed),
            EftImportOutcome::Imported(_) => panic!("DNA blob must not import as EFT"),
        }
        // parse_dna on EFT text is DnaMalformed.
        assert_eq!(
            fatal("[Rifter, Fit]\nDamage Control II", &types),
            ImportFatal::DnaMalformed
        );
        // Non-format words through the router are DnaMalformed.
        assert_eq!(
            fatal_via_router("this is not a fitting", &types),
            ImportFatal::DnaMalformed
        );
        // Leading blank lines before a DNA link still route DNA.
        let fitting = imported_via_router("\n\n587:2048;1::", &types);
        assert_eq!(fitting.format, ImportFormat::Dna);
        assert_eq!(fitting.items.len(), 1);
    }

    #[test]
    fn bounds_empty_large_and_shape() {
        let types = test_types();
        assert_eq!(fatal("", &types), ImportFatal::Empty);
        assert_eq!(fatal("   \n\t  \n", &types), ImportFatal::Empty);
        assert_eq!(fatal_via_router("", &types), ImportFatal::Empty);
        assert_eq!(fatal_via_router("  \n  ", &types), ImportFatal::Empty);
        let big = "a".repeat(MAX_EFT_IMPORT_BYTES + 1);
        assert_eq!(fatal(&big, &types), ImportFatal::TooLarge);
        assert_eq!(fatal_via_router(&big, &types), ImportFatal::TooLarge);
        let blank_big = format!("{}\n{}", " ".repeat(100), "b".repeat(MAX_EFT_IMPORT_BYTES));
        match parse_import(&blank_big, &types) {
            EftImportOutcome::Failed(f) => assert_eq!(f, ImportFatal::TooLarge),
            EftImportOutcome::Imported(_) => panic!("oversized blank must fail"),
        }
        for text in [":", "::", ":::", "1003", "plain words without colons"] {
            assert_eq!(fatal(text, &types), ImportFatal::DnaMalformed, "{text}");
        }
        for text in ["1003:", "1003::"] {
            let fitting = imported(text, &types);
            assert!(fitting.items.is_empty());
            assert!(fitting.report.issues.is_empty());
            assert_eq!(fitting.report.imported_lines, 0);
            assert_eq!(fitting.name, "Imported Solo Ship");
            assert_invariant(text, &fitting);
        }
        for text in ["1003:2001", "1003:2001:", "1003:2001::"] {
            let fitting = imported(text, &types);
            assert_eq!(fitting.items.len(), 1, "{text}");
            assert_eq!(fitting.items[0].type_id, 2001);
            assert_invariant(text, &fitting);
        }
    }

    #[test]
    fn ship_field_and_hull_cat_fatals() {
        let types = test_types();
        for text in [
            "0:2001::",
            "-5:2001::",
            "01003:2001::",
            "abc:2001::",
            "10 03:2001::",
            "2147483648:2001::",
        ] {
            assert_eq!(fatal(text, &types), ImportFatal::DnaMalformed, "{text}");
        }
        assert_eq!(fatal("987651:2001::", &types), ImportFatal::DnaShipUnknown);
        assert_eq!(fatal("2001:2001::", &types), ImportFatal::DnaShipNotShip);
        // Duplicate-name ships import cleanly by number: ambiguity
        // is unreachable in DNA.
        let fitting = imported("1001:2001::", &types);
        assert_eq!(fitting.ship_type_id, 1001);
        assert_eq!(fitting.ship_name, "Test Ship");
        assert_invariant("1001:2001::", &fitting);
        let bundled = bundled_types();
        assert_eq!(
            fatal("2048:2048;1::", &bundled),
            ImportFatal::DnaShipNotShip
        );
    }

    #[test]
    fn normalisation_and_single_line() {
        let types = test_types();
        assert_eq!(
            fatal("1003:2001::\n1003:2001::", &types),
            ImportFatal::DnaMalformed
        );
        // Interior carriage return normalises to a line feed.
        assert_eq!(
            fatal("1003:2001::\r1003:2001::", &types),
            ImportFatal::DnaMalformed
        );
        // CRLF plus outer whitespace plus leading BOM around one link imports.
        let fitting = imported("\u{FEFF}\r\n  1003:2001::  \r\n", &types);
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].type_id, 2001);
        assert_invariant("\u{FEFF}\r\n  1003:2001::  \r\n", &fitting);
        // Trailing newline after the link is fine.
        let fitting = imported("1003:2001::\n", &types);
        assert_eq!(fitting.items.len(), 1);
    }

    #[test]
    fn quantity_forms() {
        let types = test_types();
        // Omitted quantity means 1; explicit `;1` matches.
        for text in ["1003:2001::", "1003:2001;1::"] {
            let fitting = imported(text, &types);
            assert_eq!(fitting.items.len(), 1, "{text}");
            assert_eq!(fitting.items[0].quantity, 1);
            assert_invariant(text, &fitting);
        }
        for qty in [";0", ";-1", ";007", ";abc", ";"] {
            let text = format!("1003:2001{qty}::");
            let fitting = imported(&text, &types);
            assert!(fitting.items.is_empty(), "{text}");
            assert_eq!(
                issue_kinds(&fitting),
                vec![ImportIssueKind::InvalidSegmentQuantity],
                "{text}"
            );
            assert_eq!(fitting.report.issues[0].text, "Test Low Module");
            assert_invariant(&text, &fitting);
        }
        // Form-valid but expansion-crossing is fatal, not an issue.
        assert_eq!(
            fatal("1003:2001;2147483647::", &types),
            ImportFatal::DnaTooManyItems
        );
        for qty in [";2147483648", ";99999999999999999999"] {
            let text = format!("1003:2001{qty}::");
            let fitting = imported(&text, &types);
            assert_eq!(
                issue_kinds(&fitting),
                vec![ImportIssueKind::InvalidSegmentQuantity],
                "{text}"
            );
            assert_invariant(&text, &fitting);
        }
    }

    #[test]
    fn item_field_and_extra_field_forms() {
        let types = test_types();
        for segment in ["0", "-5", "abc", ";1", "02001", "2001 "] {
            let text = format!("1003:{segment}::");
            let fitting = imported(&text, &types);
            assert!(fitting.items.is_empty(), "{text}");
            assert_eq!(
                issue_kinds(&fitting),
                vec![ImportIssueKind::InvalidTypeId],
                "{text}"
            );
            assert_invariant(&text, &fitting);
        }
        // Interior whitespace in the quantity field also fails.
        let fitting = imported("1003:2001; 2::", &types);
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::InvalidSegmentQuantity]
        );
        // Extra fields report once, text is the resolved name.
        let fitting = imported("1003:2001;1;9::", &types);
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::ExtraSegmentFields]
        );
        assert_eq!(fitting.report.issues[0].text, "Test Low Module");
        assert_eq!(fitting.report.issues[0].line, 1);
        assert_invariant("1003:2001;1;9::", &fitting);
        // Extra fields win over the quantity check (order in section 4.4).
        let fitting = imported("1003:2001;abc;9::", &types);
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::ExtraSegmentFields]
        );
        // Unresolvable first field with extra fields shows the fallback.
        let fitting = imported("1003:abc;1;9::", &types);
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::ExtraSegmentFields]
        );
        assert_eq!(fitting.report.issues[0].text, "unresolved item");
        // Quantity is checked before the number is resolved.
        let fitting = imported("1003:987652;abc::", &types);
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::InvalidSegmentQuantity]
        );
        assert_eq!(fitting.report.issues[0].text, "unresolved item");
    }

    #[test]
    fn empty_segments_and_terminator() {
        let types = test_types();
        // Interior empty segment: one issue, valid segments import.
        let fitting = imported("1003:2001::2001::", &types);
        assert_eq!(fitting.items.len(), 2);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::EmptySegment]);
        assert_eq!(fitting.report.issues[0].line, 2);
        assert_eq!(fitting.report.issues[0].text, "");
        assert_invariant("1003:2001::2001::", &fitting);
        // Three trailing colons after a valid segment: one empty extra.
        let fitting = imported("1003:2001:::", &types);
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::EmptySegment]);
        assert_eq!(fitting.report.issues[0].line, 2);
        assert_invariant("1003:2001:::", &fitting);
        // Hull with three colons: one empty segment.
        let fitting = imported("1003:::", &types);
        assert!(fitting.items.is_empty());
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::EmptySegment]);
        assert_eq!(fitting.report.issues[0].line, 1);
        assert_invariant("1003:::", &fitting);
    }

    #[test]
    fn duplicates_never_merge() {
        let types = test_types();
        let fitting = imported("1003:2001;2:2001;1::", &types);
        assert_eq!(fitting.items.len(), 3);
        assert!(fitting.items.iter().all(|item| item.quantity == 1));
        assert_eq!(fitting.report.imported_lines, 2);
        assert_invariant("1003:2001;2:2001;1::", &fitting);
        let fitting = imported("1003:2001:2001::", &types);
        assert_eq!(fitting.items.len(), 2);
        assert_eq!(fitting.report.imported_lines, 2);
        assert_invariant("1003:2001:2001::", &fitting);
    }

    #[test]
    fn expanded_and_segment_caps() {
        let types = test_types();
        assert_eq!(MAX_DNA_SEGMENTS, 1_000);
        assert_eq!(MAX_DNA_EXPANDED_ITEMS, 4_096);
        // Exactly 4,096 imports.
        let fitting = imported("1003:2001;4096::", &types);
        assert_eq!(fitting.items.len(), 4_096);
        assert_eq!(fitting.report.imported_lines, 1);
        assert_invariant("1003:2001;4096::", &fitting);
        // 4,097 in one segment refuses whole.
        assert_eq!(
            fatal("1003:2001;4097::", &types),
            ImportFatal::DnaTooManyItems
        );
        // Crossing split across two segments refuses whole.
        assert_eq!(
            fatal("1003:2001;4096:2001::", &types),
            ImportFatal::DnaTooManyItems
        );
        assert_eq!(
            fatal("1003:2001;2048:2001;2049::", &types),
            ImportFatal::DnaTooManyItems
        );
        // Exactly 1,000 segments import; 1,001 refuse whole.
        let mut thousand = String::from("1003");
        for _ in 0..1_000 {
            thousand.push_str(":2001");
        }
        thousand.push_str("::");
        let fitting = imported(&thousand, &types);
        assert_eq!(fitting.items.len(), 1_000);
        assert_eq!(fitting.report.imported_lines, 1_000);
        assert_invariant(&thousand, &fitting);
        let mut over = String::from("1003");
        for _ in 0..1_001 {
            over.push_str(":2001");
        }
        over.push_str("::");
        assert_eq!(fatal(&over, &types), ImportFatal::DnaTooManySegments);
    }

    #[test]
    fn classification_matrix() {
        let types = test_types();
        // Rig, medium, high land by effect, not by position.
        let fitting = imported("1003:2004:2002:2003::", &types);
        assert!(fitting.report.issues.is_empty());
        let sections: Vec<ImportSection> = fitting.items.iter().map(|item| item.section).collect();
        assert_eq!(
            sections,
            vec![
                ImportSection::Rig,
                ImportSection::Medium,
                ImportSection::High
            ]
        );
        // Subsystems: omitted and `;2` forms.
        let fitting = imported("1003:2005::", &types);
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].section, ImportSection::Subsystem);
        assert_invariant("1003:2005::", &fitting);
        let fitting = imported("1003:2005;2::", &types);
        assert_eq!(fitting.items.len(), 2);
        assert!(fitting
            .items
            .iter()
            .all(|item| item.section == ImportSection::Subsystem));
        // Slotless module is NoSlotForModule with its name shown.
        let fitting = imported("1003:2006::", &types);
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::NoSlotForModule]
        );
        assert_eq!(fitting.report.issues[0].text, "Test Noslot Module");
        // Drone, fighter, charge, widget, ship rows are unsupported.
        for (segment, name) in [
            ("3001", "Test Drone"),
            ("3002", "Test Fighter"),
            ("4001", "Test Charge"),
            ("5001", "Test Widget"),
            ("1003", "Solo Ship"),
        ] {
            let text = format!("1003:{segment}::");
            let fitting = imported(&text, &types);
            assert!(fitting.items.is_empty(), "{text}");
            assert_eq!(
                issue_kinds(&fitting),
                vec![ImportIssueKind::UnsupportedDnaItem],
                "{text}"
            );
            assert_eq!(fitting.report.issues[0].text, name);
            assert_invariant(&text, &fitting);
        }
    }

    #[test]
    fn bundled_classification_twins() {
        let types = bundled_types();
        for (id, name) in [(2456, "Hobgoblin II"), (185, "EMP S"), (34, "Tritanium")] {
            let text = format!("587:{id}::");
            let fitting = imported(&text, &types);
            assert!(fitting.items.is_empty(), "{text}");
            assert_eq!(
                issue_kinds(&fitting),
                vec![ImportIssueKind::UnsupportedDnaItem],
                "{text}"
            );
            assert_eq!(fitting.report.issues[0].text, name);
            assert_invariant(&text, &fitting);
        }
    }

    #[test]
    fn save_and_copy_interplay_for_quantity_three() {
        let types = test_types();
        let fitting = imported("1003:2001;3::", &types);
        assert_eq!(fitting.items.len(), 3);
        let synth = fitting.to_character_fitting();
        let flags: Vec<&str> = synth.items.iter().map(|item| item.flag.as_str()).collect();
        assert_eq!(flags, vec!["LoSlot0", "LoSlot1", "LoSlot2"]);
        let mapping = build_save_request(&synth);
        assert_eq!(mapping.request.items.len(), 3);
        assert!(mapping.request.items.iter().all(|item| item.quantity == 1));
        assert!(mapping.dropped.is_empty());
        let local = fitting.name_resolver();
        let export = fitting_to_eft(&synth, &local).expect("re-exports");
        assert_eq!(export.skipped_unknown, 0);
        assert_eq!(export.skipped_empty, 0);
        let lines: Vec<&str> = export.text.lines().collect();
        assert_eq!(lines.len(), 4);
        assert_eq!(lines[1], "Test Low Module");
    }

    #[test]
    fn reasons_and_fatal_messages_are_exact() {
        assert_eq!(
            ImportIssueKind::EmptySegment.reason(),
            "this segment is empty; DNA segments are separated by single colons"
        );
        assert_eq!(
            ImportIssueKind::ExtraSegmentFields.reason(),
            "a DNA segment is one item, optionally followed by a semicolon and a quantity"
        );
        assert_eq!(
            ImportIssueKind::InvalidTypeId.reason(),
            "the item at the start of this segment is not written as a whole number from 1 to 2,147,483,647"
        );
        assert_eq!(
            ImportIssueKind::UnknownTypeId.reason(),
            "Mimir's bundled data has no item for this segment"
        );
        assert_eq!(
            ImportIssueKind::InvalidSegmentQuantity.reason(),
            "the quantity after the semicolon must be a whole number from 1 to 2,147,483,647"
        );
        assert_eq!(
            ImportIssueKind::UnsupportedDnaItem.reason(),
            "DNA links list fitted modules and subsystems only, and this item is not one"
        );
        assert_eq!(
            ImportIssueKind::NoSlotForModule.reason(),
            "Mimir's bundled data does not say which slot this module fits"
        );
        assert_eq!(
            ImportFatal::DnaMalformed.message(),
            "Could not import: paste an EFT block starting with [Ship name, Fitting name], or a single-line DNA fitting link. Nothing was imported."
        );
        assert_eq!(
            ImportFatal::DnaShipUnknown.message(),
            "Could not import: Mimir's bundled data has no ship for this DNA link. Nothing was imported."
        );
        assert_eq!(
            ImportFatal::DnaShipNotShip.message(),
            "Could not import: this DNA link does not start with a ship in Mimir's bundled data. Nothing was imported."
        );
        assert_eq!(
            ImportFatal::DnaTooManySegments.message(),
            "That DNA link has too many segments to import (limit 1,000 segments). Nothing was imported."
        );
        assert_eq!(
            ImportFatal::DnaTooManyItems.message(),
            "That DNA link has too many fitted items to import (limit 4,096 items). Nothing was imported."
        );
        assert_eq!(
            ImportFatal::Empty.message(),
            "Paste an EFT block or a DNA fitting link first - the import box is empty."
        );
        assert_eq!(
            ImportFatal::TooLarge.message(),
            "That paste is too large to import (limit 64 KiB). Nothing was imported."
        );
    }

    #[test]
    fn never_panics_on_adversarial_corpus() {
        let types = test_types();
        let corpus: Vec<String> = vec![
            "".to_string(),
            "   ".to_string(),
            ":".to_string(),
            ":::".to_string(),
            "1003".to_string(),
            "[\n[,\n]".to_string(),
            "\u{FEFF}".to_string(),
            "1003:2001::".to_string(),
            "1003:😀::".to_string(),
            "1003:2001\x00::".to_string(),
            "1003:\u{661}::".to_string(),
            "1003:99999999999999999999::".to_string(),
            "1003:2001;99999999999999999999::".to_string(),
            "1003:; ; ;::".to_string(),
            "1003:;;;:::".to_string(),
            format!("1003:{}{}::", "9".repeat(10_000), "9".repeat(10_000)),
            "1003:[Rifter, Fit]::".to_string(),
            "[Rifter, Fit]\n🚀".to_string(),
            "987651:987652::".to_string(),
            "0:0;0::".to_string(),
            "1003:2001;2147483647;1::".to_string(),
            "\n\n1003:2001::\n\n".to_string(),
            "1003:2001\r2001::".to_string(),
        ];
        for text in &corpus {
            match parse_import(text, &types) {
                EftImportOutcome::Imported(fitting) => {
                    assert!(
                        fitting.report.imported_lines + fitting.report.issues.len()
                            <= MAX_DNA_SEGMENTS
                    );
                }
                EftImportOutcome::Failed(fatal) => {
                    assert!(!fatal.message().is_empty());
                }
            }
        }
        // Spot outcomes for the corpus hinges.
        let fitting = imported("1003:😀::", &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::InvalidTypeId]);
        assert_eq!(fitting.report.issues[0].text, "unresolved item");
    }

    #[test]
    fn number_display_sweep() {
        let types = test_types();
        // Every DNA fatal message contains none of the pasted numbers
        // used here (987651/987652 collide with neither segment
        // positions nor the fixed limit numbers by construction).
        for (text, want) in [
            ("987651:2001::", ImportFatal::DnaShipUnknown),
            ("2001:2001::", ImportFatal::DnaShipNotShip),
            ("not a link", ImportFatal::DnaMalformed),
        ] {
            let got = fatal(text, &types);
            assert_eq!(got, want);
            for needle in ["987651", "987652"] {
                assert!(
                    !got.message().contains(needle),
                    "{needle} in {:?}",
                    got.message()
                );
            }
        }
        // Unknown segments report the fallback, never the number.
        let fitting = imported("1003:987652::", &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::UnknownTypeId]);
        assert_eq!(fitting.report.issues[0].text, "unresolved item");
        assert!(!fitting.report.issues[0].text.contains("987652"));
        assert!(!fitting.report.issues[0].kind.reason().contains("987652"));
        // No fitting name, item name, or reason echoes a pasted number.
        for text in ["587:999999;1::", "1003:987652;abc::", "1003:2001;1;9::"] {
            let catalogue = if text.starts_with("587") {
                bundled_types()
            } else {
                test_types()
            };
            let fitting = match parse_dna(text, &catalogue) {
                EftImportOutcome::Imported(f) => f,
                EftImportOutcome::Failed(f) => panic!("expected import, got {f:?}"),
            };
            assert!(!fitting.name.contains("999999"));
            for issue in &fitting.report.issues {
                assert!(!issue.text.contains("999999"));
                assert!(!issue.text.contains("987652"));
                assert!(!issue.kind.reason().contains("999999"));
                assert!(!issue.kind.reason().contains("987652"));
            }
        }
    }
}
