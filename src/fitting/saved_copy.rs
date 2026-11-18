//! Pure conversion of a saved fitting into an editable draft.
//!
//! A copied draft is the same `ImportedFitting` every downstream
//! block already consumes, built flag-first from a saved fitting's
//! rows: the flag names the section, the quantity rule decides
//! holdability, and the app resolver supplies display names. The
//! converter deliberately takes no `FittingTypes`: bundled data
//! lags EVE, and re-proving rows EVE already placed would silently
//! shrink real fittings. Pure means the shipped meaning: no egui,
//! no state, no network, no database, never panics on any input,
//! and logs counts only — never a name, flag, or type number.

use std::collections::{HashMap, HashSet};

use crate::esi::models::CharacterFitting;
use crate::fitting::eft::{
    ImportFormat, ImportIssue, ImportIssueKind, ImportReport, ImportSection, ImportedFitting,
    ImportedItem, MAX_STACK_QUANTITY,
};
use crate::names::resolver::NameResolver;

/// Conversion result: a draft, or the reason no draft can be titled.
#[derive(Debug, Clone)]
pub enum SavedCopyOutcome {
    Converted(ImportedFitting),
    Refused(SavedCopyRefusal),
}

/// Whole-conversion refusals: the ship gate, the only tier where
/// the entire copy is given up.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SavedCopyRefusal {
    NoShip,
    ShipUnnamed,
}

/// Slot flags with their highest valid index, per section. This is
/// the write mapper's ESI enum table minus its service row: the
/// saved view groups service modules under cargo, but a draft
/// cargo row is a saveability claim those modules cannot honour.
const SLOT_FLAGS: [(&str, u32, ImportSection); 5] = [
    ("HiSlot", 7, ImportSection::High),
    ("MedSlot", 7, ImportSection::Medium),
    ("LoSlot", 7, ImportSection::Low),
    ("RigSlot", 2, ImportSection::Rig),
    ("SubSystemSlot", 3, ImportSection::Subsystem),
];

/// The section a saved flag names, by exact match only. Anything
/// else — including service slots, view catch-alls, and prefix
/// lookalikes the ESI enum rejects — is a counted skip, never a
/// guess.
fn section_for_flag(flag: &str) -> Option<ImportSection> {
    match flag {
        "DroneBay" => return Some(ImportSection::Drones),
        "FighterBay" => return Some(ImportSection::Fighters),
        "Cargo" => return Some(ImportSection::Cargo),
        _ => {}
    }
    for (prefix, max, section) in SLOT_FLAGS {
        let Some(rest) = flag.strip_prefix(prefix) else {
            continue;
        };
        let Ok(index) = rest.parse::<u32>() else {
            return None;
        };
        return if rest == index.to_string() && index <= max {
            Some(section)
        } else {
            None
        };
    }
    None
}

/// Stable rank for the stacked-section merge key, so the same type
/// under two flags stays two stacks. Only stacked sections reach
/// the merge; slot sections map to a rank the merge never uses.
fn stack_rank(section: ImportSection) -> u8 {
    match section {
        ImportSection::Drones => 0,
        ImportSection::Fighters => 1,
        ImportSection::Cargo => 2,
        ImportSection::Low
        | ImportSection::Medium
        | ImportSection::High
        | ImportSection::Rig
        | ImportSection::Subsystem => 255,
    }
}

/// Append one counted skip. `text` is the resolved name when one
/// is known, else empty — never a flag string, never a type
/// number. The lookup never changes the already-decided kind.
fn record_skip(
    issues: &mut Vec<ImportIssue>,
    resolver: &NameResolver,
    line: usize,
    type_id: i64,
    kind: ImportIssueKind,
) {
    let text = resolver.cached(type_id).unwrap_or("").to_string();
    issues.push(ImportIssue { line, text, kind });
}

/// True when the section holds fitted slots (quantity exactly 1);
/// stacked sections hold merged totals instead.
fn is_slot_section(section: ImportSection) -> bool {
    matches!(
        section,
        ImportSection::Low
            | ImportSection::Medium
            | ImportSection::High
            | ImportSection::Rig
            | ImportSection::Subsystem
    )
}

/// Convert one saved fitting into an editable draft. Every row
/// either converts or rides on the draft as a counted skip, in
/// source-row order; only an unusable ship refuses the whole copy.
pub fn convert_saved_fitting(
    source: &CharacterFitting,
    resolver: &NameResolver,
) -> SavedCopyOutcome {
    if source.ship_type_id <= 0 {
        let refusal = SavedCopyRefusal::NoShip;
        tracing::debug!("[FITTING] saved copy refused reason={refusal:?}");
        return SavedCopyOutcome::Refused(refusal);
    }
    let Some(ship_name) = resolver.cached(source.ship_type_id) else {
        let refusal = SavedCopyRefusal::ShipUnnamed;
        tracing::debug!("[FITTING] saved copy refused reason={refusal:?}");
        return SavedCopyOutcome::Refused(refusal);
    };
    let ship_name = ship_name.to_string();

    let mut items: Vec<ImportedItem> = Vec::with_capacity(source.items.len());
    let mut issues: Vec<ImportIssue> = Vec::new();
    let mut claimed_slots: HashSet<String> = HashSet::new();
    let mut stack_index: HashMap<(u8, i64), usize> = HashMap::new();

    for (index, row) in source.items.iter().enumerate() {
        let line = index + 1;
        if row.type_id <= 0 {
            record_skip(
                &mut issues,
                resolver,
                line,
                row.type_id,
                ImportIssueKind::CopiedNotSaveable,
            );
            continue;
        }
        let Some(section) = section_for_flag(&row.flag) else {
            record_skip(
                &mut issues,
                resolver,
                line,
                row.type_id,
                ImportIssueKind::CopiedNoSection,
            );
            continue;
        };
        let slot = is_slot_section(section);
        if slot {
            if row.quantity != 1 {
                record_skip(
                    &mut issues,
                    resolver,
                    line,
                    row.type_id,
                    ImportIssueKind::CopiedBadQuantity,
                );
                continue;
            }
        } else if !(1..=MAX_STACK_QUANTITY).contains(&row.quantity) {
            record_skip(
                &mut issues,
                resolver,
                line,
                row.type_id,
                ImportIssueKind::CopiedBadQuantity,
            );
            continue;
        }
        if slot && claimed_slots.contains(&row.flag) {
            record_skip(
                &mut issues,
                resolver,
                line,
                row.type_id,
                ImportIssueKind::CopiedDuplicateSlot,
            );
            continue;
        }
        let Some(name) = resolver.cached(row.type_id) else {
            issues.push(ImportIssue {
                line,
                text: String::new(),
                kind: ImportIssueKind::CopiedUnnamed,
            });
            continue;
        };
        let name = name.to_string();
        if slot {
            claimed_slots.insert(row.flag.clone());
            items.push(ImportedItem {
                type_id: row.type_id,
                name,
                section,
                quantity: 1,
                charge: None,
            });
            continue;
        }
        let key = (stack_rank(section), row.type_id);
        if let Some(&slot_index) = stack_index.get(&key) {
            let Some(existing) = items.get_mut(slot_index) else {
                continue;
            };
            if existing.quantity + row.quantity > MAX_STACK_QUANTITY {
                issues.push(ImportIssue {
                    line,
                    text: name,
                    kind: ImportIssueKind::CopiedBadQuantity,
                });
                continue;
            }
            existing.quantity += row.quantity;
        } else {
            stack_index.insert(key, items.len());
            items.push(ImportedItem {
                type_id: row.type_id,
                name,
                section,
                quantity: row.quantity,
                charge: None,
            });
        }
    }

    let item_count = items.len();
    let skipped = issues.len();
    tracing::debug!("[FITTING] saved copy converted items={item_count} skipped={skipped}");
    SavedCopyOutcome::Converted(ImportedFitting {
        name: source.name.clone(),
        ship_type_id: source.ship_type_id,
        ship_name,
        format: ImportFormat::Copied,
        items,
        report: ImportReport {
            imported_lines: 0,
            placeholder_lines: 0,
            charges_noted: 0,
            issues,
        },
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::write_map::build_save_request;

    const SHIP: i64 = 587;

    fn fitting(name: &str, ship_type_id: i64, items: Vec<FittingItem>) -> CharacterFitting {
        CharacterFitting {
            fitting_id: 7,
            name: name.to_string(),
            description: Some("original notes".to_string()),
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

    fn resolver_with(names: &[(i64, &str)]) -> NameResolver {
        let mut resolver = NameResolver::new();
        resolver.insert(SHIP, "Rifter".to_string());
        for (type_id, name) in names {
            resolver.insert(*type_id, (*name).to_string());
        }
        resolver
    }

    /// One named type per call site: every fixture type id must
    /// carry a distinct hand-written name so issue text can be
    /// asserted against that literal.
    fn convert(
        source: &CharacterFitting,
        resolver: &NameResolver,
    ) -> (ImportedFitting, Vec<ImportIssue>) {
        match convert_saved_fitting(source, resolver) {
            SavedCopyOutcome::Converted(draft) => {
                let issues = draft.report.issues.clone();
                (draft, issues)
            }
            SavedCopyOutcome::Refused(refusal) => {
                panic!("expected a draft, got refusal {refusal:?}")
            }
        }
    }

    #[test]
    fn flag_table_converts_every_row_to_its_section() {
        let cases: [(&str, ImportSection, i64, &str); 13] = [
            ("HiSlot0", ImportSection::High, 1001, "High One"),
            ("HiSlot7", ImportSection::High, 1002, "High Seven"),
            ("MedSlot0", ImportSection::Medium, 1003, "Med One"),
            ("MedSlot7", ImportSection::Medium, 1004, "Med Seven"),
            ("LoSlot0", ImportSection::Low, 1005, "Low One"),
            ("LoSlot7", ImportSection::Low, 1006, "Low Seven"),
            ("RigSlot0", ImportSection::Rig, 1007, "Rig One"),
            ("RigSlot2", ImportSection::Rig, 1008, "Rig Two"),
            (
                "SubSystemSlot0",
                ImportSection::Subsystem,
                1009,
                "Subsys One",
            ),
            (
                "SubSystemSlot3",
                ImportSection::Subsystem,
                1010,
                "Subsys Three",
            ),
            ("DroneBay", ImportSection::Drones, 1011, "Test Drone"),
            ("FighterBay", ImportSection::Fighters, 1012, "Test Fighter"),
            ("Cargo", ImportSection::Cargo, 1013, "Test Cargo"),
        ];
        for (flag, section, type_id, name) in cases {
            let resolver = resolver_with(&[(type_id, name)]);
            let source = fitting("T", SHIP, vec![item(flag, 1, type_id)]);
            let (draft, issues) = convert(&source, &resolver);
            assert!(issues.is_empty(), "flag {flag} skips nothing");
            assert_eq!(draft.items.len(), 1, "flag {flag}");
            assert_eq!(draft.items[0].section, section, "flag {flag}");
            assert_eq!(draft.items[0].quantity, 1, "flag {flag}");
            assert_eq!(draft.items[0].type_id, type_id, "flag {flag}");
            assert_eq!(draft.items[0].name, name, "flag {flag}");
        }
    }

    #[test]
    fn non_table_flags_are_each_one_no_section_skip() {
        for flag in [
            "ServiceSlot0",
            "ServiceSlot7",
            "Invalid",
            "Hangar",
            "",
            "Foo",
            "LoSlot8",
            "RigSlot3",
            "SubSystemSlot4",
            "HiSlot00",
            "HiSlotX",
            "loslot0",
            "DroneBayExtra",
            "cargo",
        ] {
            let resolver = resolver_with(&[(2001, "Test Widget")]);
            let source = fitting("T", SHIP, vec![item(flag, 1, 2001)]);
            let (draft, issues) = convert(&source, &resolver);
            assert!(draft.items.is_empty(), "flag {flag:?} converts nothing");
            assert_eq!(issues.len(), 1, "flag {flag:?}");
            assert_eq!(issues[0].kind, ImportIssueKind::CopiedNoSection);
            assert_eq!(issues[0].line, 1, "flag {flag:?}");
            assert_eq!(issues[0].text, "Test Widget", "flag {flag:?}");
        }
    }

    #[test]
    fn slot_quantities_convert_only_at_exactly_one() {
        {
            let resolver = resolver_with(&[(2001, "Test Module")]);
            let source = fitting("T", SHIP, vec![item("LoSlot0", 1, 2001)]);
            let (draft, issues) = convert(&source, &resolver);
            assert!(issues.is_empty());
            assert_eq!(draft.items.len(), 1);
            assert_eq!(draft.items[0].quantity, 1);
        }
        for quantity in [0, -3, 5] {
            let resolver = resolver_with(&[(2001, "Test Module")]);
            let source = fitting("T", SHIP, vec![item("LoSlot0", quantity, 2001)]);
            let (draft, issues) = convert(&source, &resolver);
            assert!(draft.items.is_empty(), "quantity {quantity}");
            assert_eq!(issues.len(), 1, "quantity {quantity}");
            assert_eq!(issues[0].kind, ImportIssueKind::CopiedBadQuantity);
        }
    }

    #[test]
    fn stacked_rows_merge_per_section_at_first_appearance() {
        let resolver = resolver_with(&[
            (2001, "Test Cargo"),
            (2002, "Test Drone"),
            (2003, "Test Other"),
        ]);
        let source = fitting(
            "T",
            SHIP,
            vec![
                item("Cargo", 100, 2003),
                item("Cargo", 300, 2001),
                item("Cargo", 200, 2001),
                item("DroneBay", 5, 2001),
            ],
        );
        let (draft, issues) = convert(&source, &resolver);
        assert!(issues.is_empty());
        assert_eq!(draft.items.len(), 3);
        assert_eq!(
            draft.items[0],
            ImportedItem {
                type_id: 2003,
                name: "Test Other".to_string(),
                section: ImportSection::Cargo,
                quantity: 100,
                charge: None,
            }
        );
        assert_eq!(
            draft.items[1],
            ImportedItem {
                type_id: 2001,
                name: "Test Cargo".to_string(),
                section: ImportSection::Cargo,
                quantity: 500,
                charge: None,
            }
        );
        assert_eq!(
            draft.items[2],
            ImportedItem {
                type_id: 2001,
                name: "Test Cargo".to_string(),
                section: ImportSection::Drones,
                quantity: 5,
                charge: None,
            }
        );
    }

    #[test]
    fn same_type_slot_rows_stay_separate_fitted_items() {
        let resolver = resolver_with(&[(2001, "Test Launcher")]);
        let source = fitting(
            "T",
            SHIP,
            vec![item("HiSlot0", 1, 2001), item("HiSlot1", 1, 2001)],
        );
        let (draft, issues) = convert(&source, &resolver);
        assert!(issues.is_empty());
        assert_eq!(draft.items.len(), 2);
        assert_eq!(draft.items[0].quantity, 1);
        assert_eq!(draft.items[1].quantity, 1);
        assert_eq!(draft.items[0].section, ImportSection::High);
        assert_eq!(draft.items[1].section, ImportSection::High);
    }

    #[test]
    fn merge_crossing_the_cap_keeps_the_first_total() {
        let resolver = resolver_with(&[(2001, "Test Cargo")]);
        let source = fitting(
            "T",
            SHIP,
            vec![
                item("Cargo", MAX_STACK_QUANTITY, 2001),
                item("Cargo", 1, 2001),
            ],
        );
        let (draft, issues) = convert(&source, &resolver);
        assert_eq!(draft.items.len(), 1);
        assert_eq!(draft.items[0].quantity, MAX_STACK_QUANTITY);
        assert_eq!(issues.len(), 1);
        assert_eq!(issues[0].kind, ImportIssueKind::CopiedBadQuantity);
        assert_eq!(issues[0].line, 2);
        assert_eq!(issues[0].text, "Test Cargo");
    }

    #[test]
    fn second_claim_on_a_slot_flag_is_a_duplicate_skip() {
        let resolver = resolver_with(&[(2001, "First Weapon"), (2002, "Second Weapon")]);
        let source = fitting(
            "T",
            SHIP,
            vec![item("LoSlot0", 1, 2001), item("LoSlot0", 1, 2002)],
        );
        let (draft, issues) = convert(&source, &resolver);
        assert_eq!(draft.items.len(), 1);
        assert_eq!(draft.items[0].type_id, 2001);
        assert_eq!(issues.len(), 1);
        assert_eq!(issues[0].kind, ImportIssueKind::CopiedDuplicateSlot);
        assert_eq!(issues[0].line, 2);
        assert_eq!(issues[0].text, "Second Weapon");
    }

    #[test]
    fn multi_fault_rows_count_once_under_the_decision_order() {
        // type_id <= 0 beats an unknown flag: NotSaveable.
        let resolver = resolver_with(&[(2001, "Test Widget")]);
        let source = fitting("T", SHIP, vec![item("WeirdFlag", 1, 0)]);
        let (_, issues) = convert(&source, &resolver);
        assert_eq!(issues.len(), 1);
        assert_eq!(issues[0].kind, ImportIssueKind::CopiedNotSaveable);

        // An unknown flag beats a bad quantity: NoSection.
        let source = fitting("T", SHIP, vec![item("WeirdFlag", 0, 2001)]);
        let (_, issues) = convert(&source, &resolver);
        assert_eq!(issues.len(), 1);
        assert_eq!(issues[0].kind, ImportIssueKind::CopiedNoSection);

        // Quantity beats duplication: a duplicate slot with a
        // bad quantity is BadQuantity, not DuplicateSlot.
        let source = fitting(
            "T",
            SHIP,
            vec![item("LoSlot0", 1, 2001), item("LoSlot0", 5, 2001)],
        );
        let (_, issues) = convert(&source, &resolver);
        assert_eq!(issues.len(), 1);
        assert_eq!(issues[0].kind, ImportIssueKind::CopiedBadQuantity);

        // Duplication beats an unresolved name: DuplicateSlot.
        let source = fitting(
            "T",
            SHIP,
            vec![item("LoSlot0", 1, 2001), item("LoSlot0", 1, 9999)],
        );
        let (_, issues) = convert(&source, &resolver);
        assert_eq!(issues.len(), 1);
        assert_eq!(issues[0].kind, ImportIssueKind::CopiedDuplicateSlot);

        // Only a converted row claims its slot: when the first
        // claimant is skipped (unresolved name), the later
        // valid row on the same flag still converts.
        let source = fitting(
            "T",
            SHIP,
            vec![item("LoSlot0", 1, 9999), item("LoSlot0", 1, 2001)],
        );
        let (draft, issues) = convert(&source, &resolver);
        assert_eq!(draft.items.len(), 1);
        assert_eq!(draft.items[0].type_id, 2001);
        assert_eq!(issues.len(), 1);
        assert_eq!(issues[0].kind, ImportIssueKind::CopiedUnnamed);
    }

    #[test]
    fn stacked_quantities_convert_only_in_holdable_range() {
        for quantity in [1, MAX_STACK_QUANTITY] {
            let resolver = resolver_with(&[(2001, "Test Cargo")]);
            let source = fitting("T", SHIP, vec![item("Cargo", quantity, 2001)]);
            let (draft, issues) = convert(&source, &resolver);
            assert!(issues.is_empty(), "quantity {quantity}");
            assert_eq!(draft.items.len(), 1);
            assert_eq!(draft.items[0].quantity, quantity);
        }
        for quantity in [0, -1, MAX_STACK_QUANTITY + 1] {
            let resolver = resolver_with(&[(2001, "Test Cargo")]);
            let source = fitting("T", SHIP, vec![item("Cargo", quantity, 2001)]);
            let (draft, issues) = convert(&source, &resolver);
            assert!(draft.items.is_empty(), "quantity {quantity}");
            assert_eq!(issues.len(), 1, "quantity {quantity}");
            assert_eq!(issues[0].kind, ImportIssueKind::CopiedBadQuantity);
        }
    }

    #[test]
    fn unresolved_item_is_an_unnamed_skip_with_empty_text() {
        let resolver = resolver_with(&[]);
        let source = fitting("T", SHIP, vec![item("LoSlot0", 1, 9999)]);
        let (draft, issues) = convert(&source, &resolver);
        assert!(draft.items.is_empty());
        assert_eq!(issues.len(), 1);
        assert_eq!(issues[0].kind, ImportIssueKind::CopiedUnnamed);
        assert_eq!(issues[0].line, 1);
        assert_eq!(issues[0].text, "");
        assert!(
            !draft.items.iter().any(|item| item.name == "Unknown Item"),
            "the placeholder never becomes an item name"
        );
        for issue in &issues {
            assert!(!issue.text.contains("Unknown Item"));
        }
    }

    #[test]
    fn ship_gate_refuses_only_the_whole_copy() {
        let resolver = resolver_with(&[]);
        let source = fitting("T", 0, vec![item("LoSlot0", 1, 2001)]);
        match convert_saved_fitting(&source, &resolver) {
            SavedCopyOutcome::Refused(SavedCopyRefusal::NoShip) => {}
            other => panic!("expected NoShip refusal, got {other:?}"),
        }

        let source = fitting("T", -3, vec![]);
        match convert_saved_fitting(&source, &resolver) {
            SavedCopyOutcome::Refused(SavedCopyRefusal::NoShip) => {}
            other => panic!("expected NoShip refusal, got {other:?}"),
        }

        let source = fitting("T", 424242, vec![item("LoSlot0", 1, 2001)]);
        match convert_saved_fitting(&source, &resolver) {
            SavedCopyOutcome::Refused(SavedCopyRefusal::ShipUnnamed) => {}
            other => panic!("expected ShipUnnamed refusal, got {other:?}"),
        }
    }

    #[test]
    fn empty_and_all_skipped_fittings_convert_to_empty_drafts() {
        let resolver = resolver_with(&[(2001, "Test Widget")]);
        let source = fitting("T", SHIP, vec![]);
        let (draft, issues) = convert(&source, &resolver);
        assert!(draft.items.is_empty());
        assert!(issues.is_empty());

        let source = fitting(
            "T",
            SHIP,
            vec![item("Invalid", 1, 2001), item("LoSlot0", 0, 2001)],
        );
        let (draft, issues) = convert(&source, &resolver);
        assert!(draft.items.is_empty());
        assert_eq!(issues.len(), 2);
        assert_eq!(issues[0].kind, ImportIssueKind::CopiedNoSection);
        assert_eq!(issues[1].kind, ImportIssueKind::CopiedBadQuantity);
    }

    #[test]
    fn draft_carries_verbatim_name_ship_and_zero_counters() {
        let resolver = resolver_with(&[(2001, "Test Cargo")]);
        let source = fitting("My Brawler", SHIP, vec![item("Cargo", 5, 2001)]);
        let (draft, issues) = convert(&source, &resolver);
        assert!(issues.is_empty());
        assert_eq!(draft.format, ImportFormat::Copied);
        assert_eq!(draft.name, "My Brawler");
        assert_eq!(draft.ship_type_id, SHIP);
        assert_eq!(draft.ship_name, "Rifter");
        assert_eq!(draft.report.imported_lines, 0);
        assert_eq!(draft.report.placeholder_lines, 0);
        assert_eq!(draft.report.charges_noted, 0);
        assert!(draft.items.iter().all(|item| item.charge.is_none()));

        let source = fitting("", SHIP, vec![]);
        let (draft, _) = convert(&source, &resolver);
        assert_eq!(draft.name, "");
    }

    #[test]
    fn issues_ride_in_source_row_order_with_one_based_lines() {
        let resolver = resolver_with(&[(2001, "Test Widget"), (2002, "Test Module")]);
        let source = fitting(
            "T",
            SHIP,
            vec![
                item("Invalid", 1, 2001),
                item("LoSlot0", 1, 2002),
                item("LoSlot0", 1, 2002),
                item("Cargo", 0, 2001),
                item("HiSlot0", 1, 9999),
            ],
        );
        let (draft, issues) = convert(&source, &resolver);
        assert_eq!(draft.items.len(), 1);
        let lines: Vec<usize> = issues.iter().map(|issue| issue.line).collect();
        assert_eq!(lines, [1, 3, 4, 5]);
        let kinds: Vec<ImportIssueKind> = issues.iter().map(|issue| issue.kind).collect();
        assert_eq!(
            kinds,
            [
                ImportIssueKind::CopiedNoSection,
                ImportIssueKind::CopiedDuplicateSlot,
                ImportIssueKind::CopiedBadQuantity,
                ImportIssueKind::CopiedUnnamed,
            ]
        );
    }

    #[test]
    fn conversion_round_trips_through_synthesis_to_hand_checked_normal_form() {
        let resolver = resolver_with(&[
            (2001, "Test Railgun"),
            (2002, "Test Afterburner"),
            (2003, "Test Booster"),
            (2004, "Test Drone"),
            (2005, "Test Fighter"),
            (2006, "Test Cargo"),
            (2007, "Test Widget"),
        ]);
        let source = fitting(
            "Round Trip",
            SHIP,
            vec![
                item("LoSlot3", 1, 2001),
                item("HiSlot0", 1, 2002),
                item("Cargo", 10, 2006),
                item("LoSlot0", 1, 2003),
                item("DroneBay", 3, 2004),
                item("Invalid", 1, 2007),
                item("Cargo", 5, 2006),
                item("FighterBay", 2, 2005),
                item("HiSlot1", 1, 2002),
                item("LoSlot0", 1, 2001),
                item("HiSlot2", 5, 2001),
                item("LoSlot1", 1, 0),
                item("MedSlot0", 1, 9998),
            ],
        );
        let (draft, issues) = convert(&source, &resolver);
        assert_eq!(issues.len(), 5);
        let kinds: Vec<ImportIssueKind> = issues.iter().map(|issue| issue.kind).collect();
        assert_eq!(
            kinds,
            [
                ImportIssueKind::CopiedNoSection,
                ImportIssueKind::CopiedDuplicateSlot,
                ImportIssueKind::CopiedBadQuantity,
                ImportIssueKind::CopiedNotSaveable,
                ImportIssueKind::CopiedUnnamed,
            ]
        );
        assert_eq!(draft.items.len(), 7);

        let synthesized = draft.to_character_fitting();
        assert_eq!(synthesized.fitting_id, -1);
        assert_eq!(synthesized.description, None);
        let expected: Vec<FittingItem> = vec![
            item("LoSlot0", 1, 2001),
            item("HiSlot0", 1, 2002),
            item("Cargo", 15, 2006),
            item("LoSlot1", 1, 2003),
            item("DroneBay", 3, 2004),
            item("FighterBay", 2, 2005),
            item("HiSlot1", 1, 2002),
        ];
        assert_eq!(synthesized.items.len(), 7);
        for (actual, wanted) in synthesized.items.iter().zip(expected.iter()) {
            assert_eq!(actual.flag, wanted.flag);
            assert_eq!(actual.quantity, wanted.quantity);
            assert_eq!(actual.type_id, wanted.type_id);
        }

        let mapping = build_save_request(&synthesized);
        assert!(mapping.dropped.is_empty(), "synthesis drops nothing");

        let (again, again_issues) = convert(&synthesized, &resolver);
        assert!(again_issues.is_empty(), "re-conversion skips nothing");
        assert_eq!(again.items.len(), draft.items.len());
        for (before, after) in draft.items.iter().zip(again.items.iter()) {
            assert_eq!(before.type_id, after.type_id);
            assert_eq!(before.name, after.name);
            assert_eq!(before.section, after.section);
            assert_eq!(before.quantity, after.quantity);
        }
    }

    #[test]
    fn no_user_visible_string_contains_a_source_type_number() {
        let resolver = resolver_with(&[(2001, "Test Widget"), (2002, "Test Module")]);
        let source = fitting(
            "T",
            SHIP,
            vec![
                item("Invalid", 1, 2001),
                item("LoSlot0", 1, 2002),
                item("LoSlot0", 1, 2002),
                item("HiSlot0", 1, 9999),
            ],
        );
        let (draft, issues) = convert(&source, &resolver);
        for needle in ["2001", "2002", "9999"] {
            for issue in &issues {
                assert!(!issue.text.contains(needle), "issue text leaks {needle}");
                assert!(
                    !issue.kind.reason().contains(needle),
                    "reason leaks {needle}"
                );
            }
            for item in &draft.items {
                assert!(!item.name.contains(needle), "item name leaks {needle}");
            }
            assert!(!draft.ship_name.contains(needle));
            assert!(!draft.name.contains(needle));
        }
        for issue in &issues {
            assert_ne!(issue.text, "Invalid");
            assert_ne!(issue.text, "LoSlot0");
        }
        assert_eq!(issues[0].text, "Test Widget");
        assert_eq!(issues[1].text, "Test Module");
        assert_eq!(issues[2].text, "");
    }
}
