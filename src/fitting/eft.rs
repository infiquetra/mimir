//! Pure EFT (EVE Fitting Tool text format) parser for fitting import.
//!
//! Grounding (design section 5): Flutter `format_parser.dart` and the
//! strict AAR adapter (`aar_fit_import_parser.dart`) at `ed698d3`,
//! plus the PR #569 exporter in `src/ui/fittings.rs` which this
//! parser inverts. Slot identity comes only from dogma effects —
//! blank-line position is never consulted, because the exporter omits
//! empty sections. Every non-blank body line either contributes,
//! counts as an ignored placeholder, or yields exactly one
//! [`ImportIssue`]; there is no silent drop anywhere.
//!
//! The parser never panics on any input, never guesses a name, never
//! renders or embeds raw EVE IDs in user-facing strings, and logs
//! counts only — never pasted text.

use std::collections::HashMap;

use crate::esi::models::{CharacterFitting, FittingItem};
use crate::names::fitting_types::{FittingTypes, NameLookup};
use crate::names::resolver::NameResolver;

/// Maximum accepted paste size in bytes (design section 7).
pub const MAX_EFT_IMPORT_BYTES: usize = 65_536;
/// Maximum accepted paste size in post-normalize split lines.
pub const MAX_EFT_IMPORT_LINES: usize = 1_000;
/// Maximum stacked quantity (AAR signed-32-bit cap, verbatim).
pub const MAX_STACK_QUANTITY: i64 = 2_147_483_647;

// Category IDs (AAR constants at aar_fit_import_parser.dart:57-61,
// plus charge 8 from generate_dogma_sde.py TARGET_CATEGORIES).
const CATEGORY_SHIP: i64 = 6;
const CATEGORY_MODULE: i64 = 7;
const CATEGORY_CHARGE: i64 = 8;
const CATEGORY_DRONE: i64 = 18;
const CATEGORY_SUBSYSTEM: i64 = 32;
const CATEGORY_FIGHTER: i64 = 87;

// Dogma slot-effect IDs in Flutter `_slotTypeFor` check order:
// 12 high, 13 medium, 11 low, 2663 rig, 3772 subsystem.
const EFFECT_HIGH: i64 = 12;
const EFFECT_MEDIUM: i64 = 13;
const EFFECT_LOW: i64 = 11;
const EFFECT_RIG: i64 = 2663;
const EFFECT_SUBSYSTEM: i64 = 3772;

/// The five exact empty-slot markers (AAR `_placeholders` set,
/// case-sensitive). Any other bracketed line is an issue.
const EMPTY_SLOT_MARKERS: [&str; 5] = [
    "[Empty Low slot]",
    "[Empty Med slot]",
    "[Empty High slot]",
    "[Empty Rig slot]",
    "[Empty Subsystem slot]",
];

/// The parser's own section enum, independent of the view's
/// `FittingSection` so this pure module never depends on the UI.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ImportSection {
    Low,
    Medium,
    High,
    Rig,
    Subsystem,
    Drones,
    Fighters,
    Cargo,
}

/// One per-line problem. `text` echoes the user's own trimmed pasted
/// line; `reason` wording is fixed and never contains type IDs.
#[derive(Debug, Clone, PartialEq)]
pub struct ImportIssue {
    pub line: usize,
    pub text: String,
    pub kind: ImportIssueKind,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ImportIssueKind {
    UnknownName,
    AmbiguousName,
    BracketedLine,
    InvalidQuantity,
    QuantityTooLarge,
    StackedModule,
    NotAModule,
    NoSlotForModule,
    MalformedChargeLine,
    UnknownCharge,
    AmbiguousCharge,
    NotACharge,
}

impl ImportIssueKind {
    /// Fixed reason wording for the UI (design section 5.6).
    pub fn reason(&self) -> &'static str {
        match self {
            ImportIssueKind::UnknownName => {
                "no item in Mimir's bundled data has this exact name"
            }
            ImportIssueKind::AmbiguousName => {
                "this name matches more than one item in Mimir's bundled data"
            }
            ImportIssueKind::BracketedLine => {
                "bracketed lines other than empty-slot markers are not part of a fitting"
            }
            ImportIssueKind::InvalidQuantity => {
                "the quantity must be a whole number from 1 to 2,147,483,647, written like x5"
            }
            ImportIssueKind::QuantityTooLarge => {
                "the combined quantity for this item would exceed 2,147,483,647"
            }
            ImportIssueKind::StackedModule => {
                "modules are listed once per fitted slot, without a quantity suffix like x5"
            }
            ImportIssueKind::NotAModule => {
                "this item is not a fitted module; drones, fighters, and cargo need a quantity suffix like x5"
            }
            ImportIssueKind::NoSlotForModule => {
                "Mimir's bundled data does not say which slot this module fits"
            }
            ImportIssueKind::MalformedChargeLine => {
                "a fitted module line may name one loaded charge, like Module Name, Charge Name"
            }
            ImportIssueKind::UnknownCharge => {
                "the loaded charge after the comma has no exact match in Mimir's bundled data"
            }
            ImportIssueKind::AmbiguousCharge => {
                "the loaded charge after the comma matches more than one item in Mimir's bundled data"
            }
            ImportIssueKind::NotACharge => "the name after the comma is not a charge",
        }
    }
}

/// Parse-report counters riding on the imported fitting (section 5.6).
#[derive(Debug, Clone)]
pub struct ImportReport {
    pub imported_lines: usize,
    pub placeholder_lines: usize,
    pub charges_noted: usize,
    pub issues: Vec<ImportIssue>,
}

/// Fatal parse outcomes: no fitting at all (section 5.7).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ImportFatal {
    Empty,
    TooLarge,
    TooManyLines,
    HeaderMalformed,
    ShipUnknown,
    ShipAmbiguous,
    ShipNotShip,
}

impl ImportFatal {
    /// Fixed fatal wording for the UI.
    pub fn message(&self) -> &'static str {
        match self {
            ImportFatal::Empty => "Paste an EFT fitting first - the import box is empty.",
            ImportFatal::TooLarge => {
                "That paste is too large to import (limit 64 KiB). Nothing was imported."
            }
            ImportFatal::TooManyLines => {
                "That paste has too many lines to import (limit 1,000 lines). Nothing was imported."
            }
            ImportFatal::HeaderMalformed => {
                "Could not import: the first line must look like [Ship name, Fitting name]. Nothing was imported."
            }
            ImportFatal::ShipUnknown => {
                "Could not import: Mimir's bundled data has no ship with that exact name. Nothing was imported."
            }
            ImportFatal::ShipAmbiguous => {
                "Could not import: that ship name matches more than one item in Mimir's bundled data. Nothing was imported."
            }
            ImportFatal::ShipNotShip => {
                "Could not import: the first name in the header is not a ship. Nothing was imported."
            }
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct ImportedCharge {
    pub type_id: i64,
    pub name: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ImportedItem {
    pub type_id: i64,
    pub name: String,
    pub section: ImportSection,
    /// Always 1 for slot sections; merged total for stacked sections.
    pub quantity: i64,
    pub charge: Option<ImportedCharge>,
}

#[derive(Debug, Clone)]
pub struct ImportedFitting {
    /// Header fitting name, trimmed; may be empty.
    pub name: String,
    /// Resolved ship type ID (> 0, category 6).
    pub ship_type_id: i64,
    /// Canonical catalogue ship name.
    pub ship_name: String,
    pub items: Vec<ImportedItem>,
    pub report: ImportReport,
}

#[derive(Debug, Clone)]
pub enum EftImportOutcome {
    Imported(ImportedFitting),
    Failed(ImportFatal),
}

impl ImportedFitting {
    /// Synthesize a `CharacterFitting` for the existing renderer and
    /// exporter, unchanged (design section 6.2). Charges are display
    /// only and excluded here; copy-back discloses the omission.
    pub fn to_character_fitting(&self) -> CharacterFitting {
        tracing::debug!("[FITTING] to_character_fitting items={}", self.items.len());
        let mut counters = [0usize; 5];
        let mut fitting = CharacterFitting {
            fitting_id: -1,
            name: self.name.clone(),
            description: None,
            ship_type_id: self.ship_type_id,
            items: Vec::with_capacity(self.items.len()),
        };
        for item in &self.items {
            let flag = match item.section {
                ImportSection::Low => {
                    let flag = format!("LoSlot{}", counters[0]);
                    counters[0] = counters[0].saturating_add(1);
                    flag
                }
                ImportSection::Medium => {
                    let flag = format!("MedSlot{}", counters[1]);
                    counters[1] = counters[1].saturating_add(1);
                    flag
                }
                ImportSection::High => {
                    let flag = format!("HiSlot{}", counters[2]);
                    counters[2] = counters[2].saturating_add(1);
                    flag
                }
                ImportSection::Rig => {
                    let flag = format!("RigSlot{}", counters[3]);
                    counters[3] = counters[3].saturating_add(1);
                    flag
                }
                ImportSection::Subsystem => {
                    let flag = format!("SubSystemSlot{}", counters[4]);
                    counters[4] = counters[4].saturating_add(1);
                    flag
                }
                ImportSection::Drones => "DroneBay".to_string(),
                ImportSection::Fighters => "FighterBay".to_string(),
                ImportSection::Cargo => "Cargo".to_string(),
            };
            fitting.items.push(FittingItem {
                flag,
                quantity: item.quantity,
                type_id: item.type_id,
            });
        }
        fitting
    }

    /// Fresh local resolver holding canonical names for the ship,
    /// every item, and every stored charge (design section 6.3). The
    /// imported detail and its copy button run against this, never
    /// the app resolver.
    pub fn name_resolver(&self) -> NameResolver {
        tracing::debug!("[FITTING] name_resolver items={}", self.items.len());
        let mut resolver = NameResolver::new();
        resolver.insert(self.ship_type_id, self.ship_name.clone());
        for item in &self.items {
            resolver.insert(item.type_id, item.name.clone());
            if let Some(charge) = &item.charge {
                resolver.insert(charge.type_id, charge.name.clone());
            }
        }
        resolver
    }
}

fn failed(fatal: ImportFatal) -> EftImportOutcome {
    tracing::debug!("[FITTING] parse failed fatal={fatal:?}");
    EftImportOutcome::Failed(fatal)
}

fn issue(line: usize, text: &str, kind: ImportIssueKind) -> ImportIssue {
    ImportIssue {
        line,
        text: text.to_string(),
        kind,
    }
}

/// Slot from dogma effects, checked in Flutter `_slotTypeFor` order.
/// A module with no slot effect is an issue, never a guess.
fn slot_section(effects: &[i64]) -> Option<ImportSection> {
    if effects.contains(&EFFECT_HIGH) {
        Some(ImportSection::High)
    } else if effects.contains(&EFFECT_MEDIUM) {
        Some(ImportSection::Medium)
    } else if effects.contains(&EFFECT_LOW) {
        Some(ImportSection::Low)
    } else if effects.contains(&EFFECT_RIG) {
        Some(ImportSection::Rig)
    } else if effects.contains(&EFFECT_SUBSYSTEM) {
        Some(ImportSection::Subsystem)
    } else {
        None
    }
}

enum ModuleOutcome {
    Slot {
        type_id: i64,
        name: String,
        section: ImportSection,
    },
    Issue(ImportIssueKind),
}

/// Resolve and classify a plain module name (section 5.3 step 5),
/// shared by plain lines and charge-line module parts.
fn classify_module(types: &FittingTypes, name: &str) -> ModuleOutcome {
    match types.lookup(name) {
        NameLookup::Unknown => ModuleOutcome::Issue(ImportIssueKind::UnknownName),
        NameLookup::Ambiguous => ModuleOutcome::Issue(ImportIssueKind::AmbiguousName),
        NameLookup::Found(row) => {
            if row.category_id != CATEGORY_MODULE && row.category_id != CATEGORY_SUBSYSTEM {
                return ModuleOutcome::Issue(ImportIssueKind::NotAModule);
            }
            match slot_section(&row.slot_effects) {
                Some(section) => ModuleOutcome::Slot {
                    type_id: row.type_id,
                    name: row.name.clone(),
                    section,
                },
                None => ModuleOutcome::Issue(ImportIssueKind::NoSlotForModule),
            }
        }
    }
}

/// True when a name resolves to at least one catalogue row (found or
/// ambiguous). Used so an exact real item name wins over the comma
/// and bracket delimiter heuristics: 18 published names contain a
/// comma or start with `[` and must not be misclassified.
fn name_resolves(types: &FittingTypes, name: &str) -> bool {
    !matches!(types.lookup(name), NameLookup::Unknown)
}

/// True when a stacked suffix looks like a malformed quantity rather
/// than part of an item name: an optional sign followed by numeric
/// characters (including non-ASCII digits). Pure ASCII-digit
/// suffixes never reach here; `split_stack` claims them first.
fn looks_like_bad_quantity(suffix: &str) -> bool {
    let digits = suffix
        .strip_prefix('+')
        .or_else(|| suffix.strip_prefix('-'))
        .unwrap_or(suffix);
    !digits.is_empty() && digits.chars().all(|ch| ch.is_numeric())
}

/// Split a stacked `Name xN` line without regex (design 5.3 step 4):
/// the last ` x` whose tail is all ASCII digits. Returns
/// `(name part, digit suffix)` when the shape holds, else `None` and
/// the line falls to the plain path.
fn split_stack(line: &str) -> Option<(&str, &str)> {
    let pos = line.rfind(" x")?;
    let name = &line[..pos];
    let suffix = &line[pos + 2..];
    if name.is_empty() || suffix.is_empty() {
        return None;
    }
    if !suffix.bytes().all(|byte| byte.is_ascii_digit()) {
        return None;
    }
    Some((name, suffix))
}

/// AAR-strict quantity: first digit 1-9, at most 10 digits, at most
/// `MAX_STACK_QUANTITY`. Anything else is `InvalidQuantity`.
fn parse_stack_quantity(suffix: &str) -> Option<i64> {
    if suffix.len() > 10 || suffix.starts_with('0') {
        return None;
    }
    // All digits and at most 10 of them: always fits in an i64.
    let value: i64 = suffix.parse().ok()?;
    if value > MAX_STACK_QUANTITY {
        return None;
    }
    Some(value)
}

/// Merge a stacked line into items by type, keeping first-appearance
/// order. Returns false when the merge would exceed the cap (the
/// crossing line is an issue; earlier lines stand).
fn absorb_stack(
    items: &mut Vec<ImportedItem>,
    index: &mut HashMap<i64, usize>,
    type_id: i64,
    name: &str,
    section: ImportSection,
    quantity: i64,
) -> bool {
    if let Some(&slot_index) = index.get(&type_id) {
        let Some(slot) = items.get_mut(slot_index) else {
            return false;
        };
        if slot.quantity + quantity > MAX_STACK_QUANTITY {
            return false;
        }
        slot.quantity += quantity;
        return true;
    }
    index.insert(type_id, items.len());
    items.push(ImportedItem {
        type_id,
        name: name.to_string(),
        section,
        quantity,
        charge: None,
    });
    true
}

/// Parse EFT text against the bundled catalogue. Pure: no egui, no
/// state, no network, no database.
pub fn parse_eft(text: &str, types: &FittingTypes) -> EftImportOutcome {
    tracing::debug!("[FITTING] parse_eft bytes={}", text.len());
    // Bounds first (section 7): over-limit input is refused whole.
    if text.len() > MAX_EFT_IMPORT_BYTES {
        return failed(ImportFatal::TooLarge);
    }
    // AAR line-ending normalization: CRLF first, then lone CR.
    let normalized = text.replace("\r\n", "\n").replace('\r', "\n");
    // A leading byte-order mark (U+FEFF, prepended by some editors)
    // is dropped: Dart's trim() strips it in both Flutter parsers,
    // and the invisible character must not reject a whole paste.
    let body: &str = normalized.strip_prefix('\u{FEFF}').unwrap_or(&normalized);
    let raw_lines: Vec<&str> = body.split('\n').collect();
    if raw_lines.len() > MAX_EFT_IMPORT_LINES {
        return failed(ImportFatal::TooManyLines);
    }
    // The header is the first non-blank line.
    let mut header_index: Option<usize> = None;
    for (index, raw) in raw_lines.iter().enumerate() {
        if !raw.trim().is_empty() {
            header_index = Some(index);
            break;
        }
    }
    let Some(header_index) = header_index else {
        return failed(ImportFatal::Empty);
    };
    let header = raw_lines[header_index].trim();
    let Some(inner) = header
        .strip_prefix('[')
        .and_then(|rest| rest.strip_suffix(']'))
    else {
        return failed(ImportFatal::HeaderMalformed);
    };
    // First-comma split (design 5.2): fit names may contain commas.
    let Some(comma) = inner.find(',') else {
        return failed(ImportFatal::HeaderMalformed);
    };
    let ship_raw = inner[..comma].trim();
    if ship_raw.is_empty() {
        return failed(ImportFatal::HeaderMalformed);
    }
    let fit_name = inner[comma + 1..].trim().to_string();
    let (ship_type_id, ship_name) = match types.lookup(ship_raw) {
        NameLookup::Unknown => return failed(ImportFatal::ShipUnknown),
        NameLookup::Ambiguous => return failed(ImportFatal::ShipAmbiguous),
        NameLookup::Found(row) => {
            if row.category_id != CATEGORY_SHIP {
                return failed(ImportFatal::ShipNotShip);
            }
            (row.type_id, row.name.clone())
        }
    };

    let mut items: Vec<ImportedItem> = Vec::new();
    let mut stack_index: HashMap<i64, usize> = HashMap::new();
    let mut imported_lines: usize = 0;
    let mut placeholder_lines: usize = 0;
    let mut charges_noted: usize = 0;
    let mut issues: Vec<ImportIssue> = Vec::new();

    for (index, raw) in raw_lines.iter().enumerate().skip(header_index + 1) {
        let line_no = index + 1;
        let line = raw.trim();
        if line.is_empty() {
            continue;
        }
        // Step 1: exact empty-slot markers are ignored placeholders.
        if EMPTY_SLOT_MARKERS.contains(&line) {
            placeholder_lines = placeholder_lines.saturating_add(1);
            continue;
        }
        // Exact catalogue names win over delimiter heuristics: one
        // published name starts with `[` and must reach the stacked
        // or plain path like any other name.
        let exact_name_line = name_resolves(types, line)
            || split_stack(line).is_some_and(|(name, _)| name_resolves(types, name));
        // Step 2: any other bracketed line is an issue.
        if line.starts_with('[') && !exact_name_line {
            issues.push(issue(line_no, line, ImportIssueKind::BracketedLine));
            continue;
        }
        // Step 3: comma lines are Module, Charge lines, never stacked
        // — unless the whole line (or its stacked name part) is itself
        // an exact catalogue name containing a comma.
        if let Some(comma) = line.find(',').filter(|_| !exact_name_line) {
            let module_part = line[..comma].trim();
            let charge_part = line[comma + 1..].trim();
            if module_part.is_empty() || charge_part.is_empty() || charge_part.contains(',') {
                issues.push(issue(line_no, line, ImportIssueKind::MalformedChargeLine));
                continue;
            }
            let (module_type, module_name, module_section) =
                match classify_module(types, module_part) {
                    ModuleOutcome::Slot {
                        type_id,
                        name,
                        section,
                    } => (type_id, name, section),
                    ModuleOutcome::Issue(kind) => {
                        issues.push(issue(line_no, line, kind));
                        continue;
                    }
                };
            let charge = match types.lookup(charge_part) {
                NameLookup::Unknown => {
                    issues.push(issue(line_no, line, ImportIssueKind::UnknownCharge));
                    continue;
                }
                NameLookup::Ambiguous => {
                    issues.push(issue(line_no, line, ImportIssueKind::AmbiguousCharge));
                    continue;
                }
                NameLookup::Found(row) => {
                    if row.category_id != CATEGORY_CHARGE {
                        issues.push(issue(line_no, line, ImportIssueKind::NotACharge));
                        continue;
                    }
                    ImportedCharge {
                        type_id: row.type_id,
                        name: row.name.clone(),
                    }
                }
            };
            items.push(ImportedItem {
                type_id: module_type,
                name: module_name,
                section: module_section,
                quantity: 1,
                charge: Some(charge),
            });
            imported_lines = imported_lines.saturating_add(1);
            charges_noted = charges_noted.saturating_add(1);
            continue;
        }
        // Step 4: stacked Name xN lines.
        if let Some((name_part, quantity_part)) = split_stack(line) {
            let Some(quantity) = parse_stack_quantity(quantity_part) else {
                issues.push(issue(line_no, line, ImportIssueKind::InvalidQuantity));
                continue;
            };
            let (type_id, type_name, category_id) = match types.lookup(name_part) {
                NameLookup::Unknown => {
                    issues.push(issue(line_no, line, ImportIssueKind::UnknownName));
                    continue;
                }
                NameLookup::Ambiguous => {
                    issues.push(issue(line_no, line, ImportIssueKind::AmbiguousName));
                    continue;
                }
                NameLookup::Found(row) => (row.type_id, row.name.clone(), row.category_id),
            };
            let section = match category_id {
                CATEGORY_DRONE => ImportSection::Drones,
                CATEGORY_FIGHTER => ImportSection::Fighters,
                CATEGORY_MODULE | CATEGORY_SUBSYSTEM => {
                    issues.push(issue(line_no, line, ImportIssueKind::StackedModule));
                    continue;
                }
                _ => ImportSection::Cargo,
            };
            if absorb_stack(
                &mut items,
                &mut stack_index,
                type_id,
                &type_name,
                section,
                quantity,
            ) {
                imported_lines = imported_lines.saturating_add(1);
            } else {
                issues.push(issue(line_no, line, ImportIssueKind::QuantityTooLarge));
            }
            continue;
        }
        // Step 5: plain module lines, one fitted slot each, never merged.
        match classify_module(types, line) {
            ModuleOutcome::Slot {
                type_id,
                name,
                section,
            } => {
                items.push(ImportedItem {
                    type_id,
                    name,
                    section,
                    quantity: 1,
                    charge: None,
                });
                imported_lines = imported_lines.saturating_add(1);
            }
            ModuleOutcome::Issue(kind) => {
                // A known name followed by a malformed quantity
                // (`x-1`, `x+5`, non-ASCII digits) is a quantity
                // problem, not an unknown name: point the fixed
                // reason at the part that is actually wrong.
                let kind = if kind == ImportIssueKind::UnknownName
                    && line.rfind(" x").is_some_and(|pos| {
                        name_resolves(types, &line[..pos])
                            && looks_like_bad_quantity(&line[pos + 2..])
                    }) {
                    ImportIssueKind::InvalidQuantity
                } else {
                    kind
                };
                issues.push(issue(line_no, line, kind));
            }
        }
    }

    tracing::debug!(
        "[FITTING] parse complete items={} issues={} placeholders={} charges={}",
        items.len(),
        issues.len(),
        placeholder_lines,
        charges_noted
    );
    EftImportOutcome::Imported(ImportedFitting {
        name: fit_name,
        ship_type_id,
        ship_name,
        items,
        report: ImportReport {
            imported_lines,
            placeholder_lines,
            charges_noted,
            issues,
        },
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::CharacterFitting;
    use crate::ui::fittings::fitting_to_eft;

    /// Small hand-written catalogue: one type per category/effect
    /// combination, so grammar rules are pinned independent of SDE
    /// contents. Mirrors the fitting_types.rs literal-fixture style.
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
        match parse_eft(text, types) {
            EftImportOutcome::Imported(fitting) => fitting,
            EftImportOutcome::Failed(fatal) => panic!("expected import, got {fatal:?}"),
        }
    }

    fn fatal(text: &str, types: &FittingTypes) -> ImportFatal {
        match parse_eft(text, types) {
            EftImportOutcome::Failed(fatal) => fatal,
            EftImportOutcome::Imported(_) => panic!("expected failure"),
        }
    }

    fn issue_kinds(fitting: &ImportedFitting) -> Vec<ImportIssueKind> {
        fitting.report.issues.iter().map(|item| item.kind).collect()
    }

    /// Independent recount of non-blank body lines for the invariant.
    fn non_blank_body_lines(text: &str) -> usize {
        let normalized = text.replace("\r\n", "\n").replace('\r', "\n");
        let lines: Vec<&str> = normalized.split('\n').collect();
        let mut header_seen = false;
        let mut count = 0;
        for raw in lines {
            if !header_seen {
                if !raw.trim().is_empty() {
                    header_seen = true;
                }
                continue;
            }
            if !raw.trim().is_empty() {
                count += 1;
            }
        }
        count
    }

    fn assert_invariant(text: &str, fitting: &ImportedFitting) {
        let total = fitting.report.imported_lines
            + fitting.report.placeholder_lines
            + fitting.report.issues.len();
        assert_eq!(
            total,
            non_blank_body_lines(text),
            "imported+placeholders+issues must equal non-blank body lines"
        );
    }

    #[test]
    fn slot_typed_full_fitting_from_aar_shape() {
        let types = bundled_types();
        let text = "[Rifter, Fight Fit]\n\
            Damage Control II\n\
            1MN Afterburner II\n\
            200mm AutoCannon II\n\
            Small Projectile Burst Aerator I\n\
            Hobgoblin II x5\n";
        let fitting = imported(text, &types);
        assert_eq!(fitting.ship_type_id, 587);
        assert_eq!(fitting.ship_name, "Rifter");
        assert_eq!(fitting.name, "Fight Fit");
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.items.len(), 5);
        let by_name: HashMap<&str, (i64, ImportSection, i64)> = fitting
            .items
            .iter()
            .map(|item| {
                (
                    item.name.as_str(),
                    (item.type_id, item.section, item.quantity),
                )
            })
            .collect();
        assert_eq!(
            by_name.get("Damage Control II"),
            Some(&(2048, ImportSection::Low, 1))
        );
        assert_eq!(
            by_name.get("1MN Afterburner II"),
            Some(&(438, ImportSection::Medium, 1))
        );
        assert_eq!(
            by_name.get("200mm AutoCannon II"),
            Some(&(2889, ImportSection::High, 1))
        );
        assert_eq!(
            by_name.get("Small Projectile Burst Aerator I"),
            Some(&(31668, ImportSection::Rig, 1))
        );
        assert_eq!(
            by_name.get("Hobgoblin II"),
            Some(&(2456, ImportSection::Drones, 5))
        );
        assert_eq!(fitting.report.imported_lines, 5);
        assert_eq!(fitting.report.placeholder_lines, 0);
        assert_eq!(fitting.report.charges_noted, 0);
        assert_invariant(text, &fitting);
    }

    #[test]
    fn header_only_is_valid_empty_fitting() {
        let types = bundled_types();
        let fitting = imported("[Rifter, Test]\n", &types);
        assert_eq!(fitting.ship_type_id, 587);
        assert!(fitting.items.is_empty());
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.report.imported_lines, 0);
    }

    #[test]
    fn placeholders_and_crlf_import_the_real_module() {
        let types = bundled_types();
        let text = "[Rifter, T]\r\n\r\nDamage Control II\r\n\r\n[Empty Low slot]\r\n";
        let fitting = imported(text, &types);
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].type_id, 2048);
        assert_eq!(fitting.report.placeholder_lines, 1);
        assert!(fitting.report.issues.is_empty());
        assert_invariant(text, &fitting);
    }

    #[test]
    fn lone_cr_line_endings_are_normalized() {
        let types = bundled_types();
        let fitting = imported("[Rifter, T]\rDamage Control II\r", &types);
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].type_id, 2048);
    }

    #[test]
    fn fit_name_may_contain_colon_and_comma() {
        let types = bundled_types();
        let colon = imported("[Rifter, PvP: Armor]\nDamage Control II", &types);
        assert_eq!(colon.name, "PvP: Armor");
        // First-comma rule (design 5.2): the fit name keeps its comma.
        let comma = imported("[Rifter, Brawl, v2]\nDamage Control II", &types);
        assert_eq!(comma.name, "Brawl, v2");
        assert_eq!(comma.ship_type_id, 587);
    }

    #[test]
    fn header_failures_are_distinct_fatals() {
        let types = bundled_types();
        assert_eq!(
            fatal("Rifter, Fit\nDamage Control II", &types),
            ImportFatal::HeaderMalformed
        );
        assert_eq!(
            fatal("[Rifter Fit]\nDamage Control II", &types),
            ImportFatal::HeaderMalformed
        );
        assert_eq!(
            fatal("[, Fit]\nDamage Control II", &types),
            ImportFatal::HeaderMalformed
        );
        assert_eq!(
            fatal("[No Such Ship, Fit]\nDamage Control II", &types),
            ImportFatal::ShipUnknown
        );
        assert_eq!(
            fatal("[Damage Control II, Fit]\nDamage Control II", &types),
            ImportFatal::ShipNotShip
        );
    }

    #[test]
    fn ambiguous_ship_is_its_own_fatal() {
        let types = test_types();
        assert_eq!(
            fatal("[Test Ship, Fit]\nTest Low Module", &types),
            ImportFatal::ShipAmbiguous
        );
        // The unique fixture ship parses fine.
        let fitting = imported("[Solo Ship, Fit]\nTest Low Module", &types);
        assert_eq!(fitting.ship_type_id, 1003);
    }

    #[test]
    fn unknown_module_line_is_reported_not_dropped() {
        let types = bundled_types();
        let text = "[Rifter, T]\nDamage Control II\nNot A Real Module\n1MN Afterburner II";
        let fitting = imported(text, &types);
        assert_eq!(fitting.items.len(), 2);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::UnknownName]);
        let problem = &fitting.report.issues[0];
        assert_eq!(problem.line, 3);
        assert_eq!(problem.text, "Not A Real Module");
        assert_invariant(text, &fitting);
    }

    #[test]
    fn ambiguous_module_name_is_unresolved() {
        let types = test_types();
        let fitting = imported("[Solo Ship, T]\nTest Dup\nTest Low Module", &types);
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::AmbiguousName]);
    }

    #[test]
    fn quantity_rules_are_strict() {
        let types = bundled_types();
        // x0 and x05 violate the first-digit rule (AAR-strict).
        for line in ["Hobgoblin II x0", "Hobgoblin II x05"] {
            let fitting = imported(&format!("[Rifter, T]\n{line}"), &types);
            assert_eq!(
                issue_kinds(&fitting),
                vec![ImportIssueKind::InvalidQuantity],
                "{line}"
            );
        }
        // x-1 has no stacked shape, so it falls to the plain path;
        // the name resolves, so the reason names the quantity.
        let fitting = imported("[Rifter, T]\nHobgoblin II x-1", &types);
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::InvalidQuantity]
        );
        // Same for an explicit plus sign and non-ASCII digits.
        for line in ["Hobgoblin II x+5", "Hobgoblin II x\u{661}"] {
            let fitting = imported(&format!("[Rifter, T]\n{line}"), &types);
            assert_eq!(
                issue_kinds(&fitting),
                vec![ImportIssueKind::InvalidQuantity],
                "{line}"
            );
        }
        // An unknown name with a bad quantity stays an unknown name.
        let fitting = imported("[Rifter, T]\nNot A Real Drone x-1", &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::UnknownName]);
        // A 20-digit quantity never parses; it is InvalidQuantity.
        let fitting = imported("[Rifter, T]\nHobgoblin II x99999999999999999999", &types);
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::InvalidQuantity]
        );
        // Just over the i32 cap is InvalidQuantity; the cap itself imports.
        let fitting = imported("[Rifter, T]\nHobgoblin II x2147483648", &types);
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::InvalidQuantity]
        );
        let fitting = imported("[Rifter, T]\nHobgoblin II x2147483647", &types);
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.items[0].quantity, 2_147_483_647);
    }

    #[test]
    fn leading_byte_order_mark_is_dropped() {
        let types = bundled_types();
        let fitting = imported("\u{FEFF}[Rifter, T]\nDamage Control II", &types);
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.items.len(), 1);
        // A BOM-only paste is empty, not a malformed header.
        match parse_eft("\u{FEFF}", &types) {
            EftImportOutcome::Failed(fatal) => assert_eq!(fatal, ImportFatal::Empty),
            EftImportOutcome::Imported(_) => panic!("BOM-only paste must not import"),
        }
    }

    #[test]
    fn exact_names_with_delimiters_import_as_cargo() {
        let types = bundled_types();
        // 17 published names contain a comma; the charge-comma
        // heuristic must not claim an exact stacked name.
        let fitting = imported("[Rifter, T]\nExotic Dancers, Male x5", &types);
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].section, ImportSection::Cargo);
        assert_eq!(fitting.items[0].quantity, 5);
        // One published name starts with `[`; it is not a bracketed
        // marker line.
        let fitting = imported(
            "[Rifter, T]\n[CNS] Kiirasha Final Broadcast Fragment x2",
            &types,
        );
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].section, ImportSection::Cargo);
        assert_eq!(fitting.items[0].quantity, 2);
        // A duplicate header in the body still reports as bracketed.
        let fitting = imported("[Rifter, T]\n[Rifter, T]\nDamage Control II", &types);
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::BracketedLine]);
    }

    #[test]
    fn fighter_stacks_merge_and_sections_are_effect_driven() {
        let types = bundled_types();
        let text = "[Rifter, T]\nTemplar II x6\nHobgoblin II x2\nTemplar II x6";
        let fitting = imported(text, &types);
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.items.len(), 2);
        // First-appearance order is kept inside the parser...
        assert_eq!(fitting.items[0].type_id, 40556);
        assert_eq!(fitting.items[0].quantity, 12);
        assert_eq!(fitting.items[1].type_id, 2456);
        // ...but re-export through the locked exporter lists drones first.
        let synth = fitting.to_character_fitting();
        let local = fitting.name_resolver();
        let export = fitting_to_eft(&synth, &local).expect("imported fitting re-exports");
        let drone_pos = export
            .text
            .find("Hobgoblin II x2")
            .expect("drones exported");
        let fighter_pos = export
            .text
            .find("Templar II x12")
            .expect("fighters exported");
        assert!(drone_pos < fighter_pos, "{}", export.text);
        assert_invariant(text, &fitting);
    }

    #[test]
    fn charge_lines_store_the_resolved_charge() {
        let types = bundled_types();
        let fitting = imported(
            "[Rifter, T]\n200mm AutoCannon II, Republic Fleet EMP S",
            &types,
        );
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].type_id, 2889);
        assert_eq!(fitting.report.charges_noted, 1);
        let charge = fitting.items[0].charge.as_ref().expect("charge stored");
        assert_eq!(charge.type_id, 21898);
        assert_eq!(charge.name, "Republic Fleet EMP S");
    }

    #[test]
    fn charge_failures_contribute_nothing() {
        let types = bundled_types();
        let fitting = imported("[Rifter, T]\n200mm AutoCannon II, No Such Charge", &types);
        assert!(fitting.items.is_empty());
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::UnknownCharge]);

        // Tritanium resolves but is cargo, not a charge.
        let fitting = imported("[Rifter, T]\n200mm AutoCannon II, Tritanium", &types);
        assert!(fitting.items.is_empty());
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::NotACharge]);

        // Double commas, empty module, and empty charge are structural.
        for line in ["Damage Control II,, EMP S", ", EMP S", "Damage Control II,"] {
            let fitting = imported(&format!("[Rifter, T]\n{line}"), &types);
            assert!(fitting.items.is_empty(), "{line}");
            assert_eq!(
                issue_kinds(&fitting),
                vec![ImportIssueKind::MalformedChargeLine],
                "{line}"
            );
        }
    }

    #[test]
    fn subsystem_imports_to_subsystem_section() {
        let types = bundled_types();
        let text = "[Legion, T]\nLegion Core - Augmented Antimatter Reactor";
        let fitting = imported(text, &types);
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].type_id, 45623);
        assert_eq!(fitting.items[0].section, ImportSection::Subsystem);
        assert_invariant(text, &fitting);
    }

    #[test]
    fn cargo_stacks_import_as_cargo() {
        let types = bundled_types();
        let fitting = imported("[Rifter, T]\nTritanium x500\nEMP S x200", &types);
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.items.len(), 2);
        assert_eq!(fitting.items[0].type_id, 34);
        assert_eq!(fitting.items[0].section, ImportSection::Cargo);
        assert_eq!(fitting.items[0].quantity, 500);
        assert_eq!(fitting.items[1].type_id, 185);
        assert_eq!(fitting.items[1].section, ImportSection::Cargo);
        assert_eq!(fitting.items[1].quantity, 200);
    }

    #[test]
    fn bad_shapes_are_reported_line_by_line() {
        let types = bundled_types();
        let fitting = imported("[Rifter, T]\nDamage Control II x2", &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::StackedModule]);

        let fitting = imported("[Rifter, T]\nHobgoblin II", &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::NotAModule]);

        let fitting = imported("[Rifter, T]\n[Some note]", &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::BracketedLine]);

        // Placeholders are case-sensitive; lowercase is bracketed junk.
        let fitting = imported("[Rifter, T]\n[empty low slot]", &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::BracketedLine]);

        // A second header line is bracketed junk, not a new ship.
        let fitting = imported("[Rifter, T]\n[Rifter, Other]", &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::BracketedLine]);
    }

    #[test]
    fn module_without_slot_effect_is_reported() {
        let types = test_types();
        let fitting = imported("[Solo Ship, T]\nTest Noslot Module", &types);
        assert!(fitting.items.is_empty());
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::NoSlotForModule]
        );
    }

    #[test]
    fn fixture_sections_land_by_effects() {
        let types = test_types();
        let fitting = imported(
            "[Solo Ship, T]\nTest Low Module\nTest Med Module\nTest High Module\nTest Rig Module\nTest Subsystem\nTest Drone x3\nTest Fighter x2\nTest Widget x7",
            &types,
        );
        assert!(
            fitting.report.issues.is_empty(),
            "{:?}",
            fitting.report.issues
        );
        let sections: Vec<ImportSection> = fitting.items.iter().map(|item| item.section).collect();
        assert_eq!(
            sections,
            vec![
                ImportSection::Low,
                ImportSection::Medium,
                ImportSection::High,
                ImportSection::Rig,
                ImportSection::Subsystem,
                ImportSection::Drones,
                ImportSection::Fighters,
                ImportSection::Cargo,
            ]
        );
    }

    #[test]
    fn blank_line_position_never_changes_classification() {
        let types = test_types();
        let with_blanks = "[Solo Ship, T]\n\nTest Low Module\nTest Med Module\n\nTest High Module\n\nTest Rig Module\n\nTest Drone x3\n";
        let compact = "[Solo Ship, T]\nTest Low Module\nTest Med Module\nTest High Module\nTest Rig Module\nTest Drone x3";
        let scrambled = "[Solo Ship, T]\nTest Drone x3\nTest Rig Module\nTest High Module\nTest Med Module\nTest Low Module";
        let key = |fitting: &ImportedFitting| {
            let mut rows: Vec<(i64, ImportSection, i64)> = fitting
                .items
                .iter()
                .map(|item| (item.type_id, item.section, item.quantity))
                .collect();
            rows.sort_by_key(|row| (row.0, row.1 as u8, row.2));
            rows
        };
        let expected = key(&imported(compact, &types));
        assert_eq!(key(&imported(with_blanks, &types)), expected);
        assert_eq!(key(&imported(scrambled, &types)), expected);
        assert_invariant(with_blanks, &imported(with_blanks, &types));
    }

    #[test]
    fn report_invariant_holds_across_mixed_inputs() {
        let types = test_types();
        let inputs = [
            "[Solo Ship, T]\nTest Low Module\nTest Drone x3",
            "[Solo Ship, T]\n\nTest Low Module\n[Empty Low slot]\n[Empty Med slot]\n\nTest Drone x3\n",
            "[Solo Ship, T]\nNope Module\nTest Low Module\nTest Widget x9",
            "[Solo Ship, T]\nTest High Module, Test Charge\nTest Noslot Module\n[Some note]\n",
            "[Solo Ship, T]\nTest Drone x2147483647\nTest Drone x1",
        ];
        for text in inputs {
            let fitting = imported(text, &types);
            assert_invariant(text, &fitting);
        }
    }

    #[test]
    fn reasons_and_fatal_messages_are_exact() {
        assert_eq!(
            ImportIssueKind::UnknownName.reason(),
            "no item in Mimir's bundled data has this exact name"
        );
        assert_eq!(
            ImportIssueKind::AmbiguousName.reason(),
            "this name matches more than one item in Mimir's bundled data"
        );
        assert_eq!(
            ImportIssueKind::BracketedLine.reason(),
            "bracketed lines other than empty-slot markers are not part of a fitting"
        );
        assert_eq!(
            ImportIssueKind::InvalidQuantity.reason(),
            "the quantity must be a whole number from 1 to 2,147,483,647, written like x5"
        );
        assert_eq!(
            ImportIssueKind::QuantityTooLarge.reason(),
            "the combined quantity for this item would exceed 2,147,483,647"
        );
        assert_eq!(
            ImportIssueKind::StackedModule.reason(),
            "modules are listed once per fitted slot, without a quantity suffix like x5"
        );
        assert_eq!(
            ImportIssueKind::NotAModule.reason(),
            "this item is not a fitted module; drones, fighters, and cargo need a quantity suffix like x5"
        );
        assert_eq!(
            ImportIssueKind::NoSlotForModule.reason(),
            "Mimir's bundled data does not say which slot this module fits"
        );
        assert_eq!(
            ImportIssueKind::MalformedChargeLine.reason(),
            "a fitted module line may name one loaded charge, like Module Name, Charge Name"
        );
        assert_eq!(
            ImportIssueKind::UnknownCharge.reason(),
            "the loaded charge after the comma has no exact match in Mimir's bundled data"
        );
        assert_eq!(
            ImportIssueKind::AmbiguousCharge.reason(),
            "the loaded charge after the comma matches more than one item in Mimir's bundled data"
        );
        assert_eq!(
            ImportIssueKind::NotACharge.reason(),
            "the name after the comma is not a charge"
        );
        assert_eq!(
            ImportFatal::Empty.message(),
            "Paste an EFT fitting first - the import box is empty."
        );
        assert_eq!(
            ImportFatal::TooLarge.message(),
            "That paste is too large to import (limit 64 KiB). Nothing was imported."
        );
        assert_eq!(
            ImportFatal::TooManyLines.message(),
            "That paste has too many lines to import (limit 1,000 lines). Nothing was imported."
        );
        assert_eq!(
            ImportFatal::HeaderMalformed.message(),
            "Could not import: the first line must look like [Ship name, Fitting name]. Nothing was imported."
        );
        assert_eq!(
            ImportFatal::ShipUnknown.message(),
            "Could not import: Mimir's bundled data has no ship with that exact name. Nothing was imported."
        );
        assert_eq!(
            ImportFatal::ShipAmbiguous.message(),
            "Could not import: that ship name matches more than one item in Mimir's bundled data. Nothing was imported."
        );
        assert_eq!(
            ImportFatal::ShipNotShip.message(),
            "Could not import: the first name in the header is not a ship. Nothing was imported."
        );
    }

    #[test]
    fn synthesis_flags_resolver_and_charge_exclusion() {
        let types = test_types();
        let fitting = imported(
            "[Solo Ship, Flags]\nTest Low Module\nTest Med Module\nTest High Module\nTest Rig Module\nTest Subsystem\nTest Drone x3\nTest Fighter x2\nTest Widget x7\nTest High Module, Test Charge",
            &types,
        );
        assert!(fitting.report.issues.is_empty());
        let synth = fitting.to_character_fitting();
        assert_eq!(synth.fitting_id, -1);
        assert_eq!(synth.name, "Flags");
        assert_eq!(synth.ship_type_id, 1003);
        assert!(synth.description.is_none());
        let flags: Vec<(&str, i64, i64)> = synth
            .items
            .iter()
            .map(|item| (item.flag.as_str(), item.quantity, item.type_id))
            .collect();
        assert_eq!(
            flags,
            vec![
                ("LoSlot0", 1, 2001),
                ("MedSlot0", 1, 2002),
                ("HiSlot0", 1, 2003),
                ("RigSlot0", 1, 2004),
                ("SubSystemSlot0", 1, 2005),
                ("DroneBay", 3, 3001),
                ("FighterBay", 2, 3002),
                ("Cargo", 7, 5001),
                ("HiSlot1", 1, 2003),
            ]
        );
        // The local resolver knows ship, items, and the stored charge
        // with canonical names.
        let local = fitting.name_resolver();
        assert_eq!(local.cached(1003), Some("Solo Ship"));
        assert_eq!(local.cached(2001), Some("Test Low Module"));
        assert_eq!(local.cached(4001), Some("Test Charge"));
    }

    #[test]
    fn adversarial_inputs_return_outcomes_never_panics() {
        let types = test_types();
        assert_eq!(fatal("", &types), ImportFatal::Empty);
        assert_eq!(fatal("   \n\t  \n", &types), ImportFatal::Empty);
        assert_eq!(fatal("[", &types), ImportFatal::HeaderMalformed);
        assert_eq!(fatal("[]", &types), ImportFatal::HeaderMalformed);
        assert_eq!(fatal("[,]", &types), ImportFatal::HeaderMalformed);
        assert_eq!(fatal("[Solo Ship]", &types), ImportFatal::HeaderMalformed);
        // A DNA blob is malformed EFT, never guessed at.
        assert_eq!(fatal("587:2048;1::", &types), ImportFatal::HeaderMalformed);
        // Emoji ship names fail lookup honestly.
        assert_eq!(
            fatal("[🚀 Ship, Fit]\nTest Low Module", &types),
            ImportFatal::ShipUnknown
        );
        // Control characters survive trim only at line edges; interior
        // NULs simply fail lookup. No panic either way.
        let fitting = imported("[Solo Ship, T]\nTest\x00 Low Module", &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::UnknownName]);
        // Commas-only line: empty module part under the charge rule.
        let fitting = imported("[Solo Ship, T]\n,,,", &types);
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::MalformedChargeLine]
        );
        // A leading-space stack line trims to a bare quantity token,
        // which is a plain unknown name.
        let fitting = imported("[Solo Ship, T]\nx5", &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::UnknownName]);
        // Trailing " x" with no digits is not stacked shape.
        let fitting = imported("[Solo Ship, T]\nTest Low Module x", &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::UnknownName]);
        // A 10,000-character body line is one unknown name.
        let long_body = format!("[Solo Ship, T]\n{}", "a".repeat(10_000));
        let fitting = imported(&long_body, &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::UnknownName]);
        // Leading blanks before the header are fine.
        let fitting = imported("\n\n[Solo Ship, T]\nTest Low Module", &types);
        assert_eq!(fitting.items.len(), 1);
        // Every body line failing still imports as an empty fitting.
        let fitting = imported("[Solo Ship, T]\nNope One\nNope Two", &types);
        assert!(fitting.items.is_empty());
        assert_eq!(fitting.report.issues.len(), 2);
    }

    #[test]
    fn bounds_are_enforced_before_parsing() {
        let types = test_types();
        // 1,001 lines refuse whole; exactly 1,000 import.
        let mut too_many = String::from("[Solo Ship, T]");
        for _ in 0..1_000 {
            too_many.push('\n');
            too_many.push_str("Test Low Module");
        }
        assert_eq!(fatal(&too_many, &types), ImportFatal::TooManyLines);
        let mut exactly_lines = String::from("[Solo Ship, T]");
        for _ in 0..999 {
            exactly_lines.push('\n');
            exactly_lines.push_str("Test Low Module");
        }
        let fitting = imported(&exactly_lines, &types);
        assert_eq!(fitting.report.imported_lines, 999);
        // 65,537 bytes refuse whole; exactly 65,536 import (as one
        // unknown long line).
        let header = "[Solo Ship, T]";
        let body_len = MAX_EFT_IMPORT_BYTES - header.len() - 1;
        let exact_bytes = format!("{header}\n{}", "a".repeat(body_len));
        assert_eq!(exact_bytes.len(), MAX_EFT_IMPORT_BYTES);
        let fitting = imported(&exact_bytes, &types);
        assert_eq!(issue_kinds(&fitting), vec![ImportIssueKind::UnknownName]);
        let over_bytes = format!("{header}\n{}", "a".repeat(body_len + 1));
        assert_eq!(over_bytes.len(), MAX_EFT_IMPORT_BYTES + 1);
        assert_eq!(fatal(&over_bytes, &types), ImportFatal::TooLarge);
    }

    #[test]
    fn merged_stacks_crossing_the_cap_flag_only_the_crossing_line() {
        let types = test_types();
        let fitting = imported(
            "[Solo Ship, T]\nTest Drone x2147483647\nTest Drone x1",
            &types,
        );
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].quantity, 2_147_483_647);
        assert_eq!(fitting.report.imported_lines, 1);
        assert_eq!(
            issue_kinds(&fitting),
            vec![ImportIssueKind::QuantityTooLarge]
        );
        let problem = &fitting.report.issues[0];
        assert_eq!(problem.line, 3);
        assert_eq!(problem.text, "Test Drone x1");
    }

    fn catalogue_resolver(types: &FittingTypes) -> NameResolver {
        let mut resolver = NameResolver::new();
        for row in &types.types {
            resolver.insert(row.type_id, row.name.clone());
        }
        resolver
    }

    fn slot_multiset(fitting: &ImportedFitting, section: ImportSection) -> Vec<i64> {
        let mut ids: Vec<i64> = fitting
            .items
            .iter()
            .filter(|item| item.section == section)
            .map(|item| item.type_id)
            .collect();
        ids.sort_unstable();
        ids
    }

    fn stacked_totals(fitting: &ImportedFitting, section: ImportSection) -> Vec<(i64, i64)> {
        let mut rows: Vec<(i64, i64)> = fitting
            .items
            .iter()
            .filter(|item| item.section == section)
            .map(|item| (item.type_id, item.quantity))
            .collect();
        rows.sort_unstable();
        rows
    }

    #[test]
    fn round_trip_through_exporter_is_equivalent_and_byte_identical() {
        let types = bundled_types();
        let resolver = catalogue_resolver(&types);
        let saved = CharacterFitting {
            fitting_id: 42,
            name: "RoundTrip".to_string(),
            description: None,
            ship_type_id: 587,
            items: vec![
                crate::esi::models::FittingItem {
                    flag: "LoSlot0".to_string(),
                    quantity: 1,
                    type_id: 2048,
                },
                crate::esi::models::FittingItem {
                    flag: "LoSlot1".to_string(),
                    quantity: 1,
                    type_id: 1183,
                },
                crate::esi::models::FittingItem {
                    flag: "MedSlot0".to_string(),
                    quantity: 1,
                    type_id: 438,
                },
                crate::esi::models::FittingItem {
                    flag: "HiSlot0".to_string(),
                    quantity: 1,
                    type_id: 2889,
                },
                crate::esi::models::FittingItem {
                    flag: "RigSlot0".to_string(),
                    quantity: 1,
                    type_id: 31668,
                },
                crate::esi::models::FittingItem {
                    flag: "SubSystemSlot0".to_string(),
                    quantity: 1,
                    type_id: 45623,
                },
                crate::esi::models::FittingItem {
                    flag: "DroneBay".to_string(),
                    quantity: 5,
                    type_id: 2456,
                },
                crate::esi::models::FittingItem {
                    flag: "FighterBay".to_string(),
                    quantity: 2,
                    type_id: 40556,
                },
                crate::esi::models::FittingItem {
                    flag: "Cargo".to_string(),
                    quantity: 500,
                    type_id: 34,
                },
            ],
        };
        let export = fitting_to_eft(&saved, &resolver).expect("saved fitting exports");
        assert_eq!(export.skipped_unknown, 0);
        assert_eq!(export.skipped_empty, 0);
        let fitting = imported(&export.text, &types);
        assert!(
            fitting.report.issues.is_empty(),
            "{:?}",
            fitting.report.issues
        );
        assert_eq!(fitting.ship_type_id, 587);
        assert_eq!(fitting.ship_name, "Rifter");
        assert_eq!(fitting.name, "RoundTrip");
        assert_eq!(
            slot_multiset(&fitting, ImportSection::Low),
            vec![1183, 2048]
        );
        assert_eq!(slot_multiset(&fitting, ImportSection::Medium), vec![438]);
        assert_eq!(slot_multiset(&fitting, ImportSection::High), vec![2889]);
        assert_eq!(slot_multiset(&fitting, ImportSection::Rig), vec![31668]);
        assert_eq!(
            slot_multiset(&fitting, ImportSection::Subsystem),
            vec![45623]
        );
        assert_eq!(
            stacked_totals(&fitting, ImportSection::Drones),
            vec![(2456, 5)]
        );
        assert_eq!(
            stacked_totals(&fitting, ImportSection::Fighters),
            vec![(40556, 2)]
        );
        assert_eq!(
            stacked_totals(&fitting, ImportSection::Cargo),
            vec![(34, 500)]
        );
        // Re-exporting the synthesis is byte-identical to the original.
        let synth = fitting.to_character_fitting();
        assert_eq!(synth.fitting_id, -1);
        let local = fitting.name_resolver();
        let re_export = fitting_to_eft(&synth, &local).expect("import re-exports");
        assert_eq!(re_export.skipped_unknown, 0);
        assert_eq!(re_export.skipped_empty, 0);
        assert_eq!(re_export.text, export.text);
    }

    #[test]
    fn comma_fit_name_imports_intact_and_reexports_sanitized() {
        let types = bundled_types();
        let fitting = imported("[Rifter, Brawl, v2]\nDamage Control II", &types);
        assert_eq!(fitting.name, "Brawl, v2");
        let synth = fitting.to_character_fitting();
        let local = fitting.name_resolver();
        let export = fitting_to_eft(&synth, &local).expect("comma name re-exports");
        assert!(
            export.text.starts_with("[Rifter, Brawl v2]"),
            "{}",
            export.text
        );
    }

    #[test]
    fn canonical_names_replace_pasted_spelling() {
        let types = bundled_types();
        let fitting = imported("[rifter, T]\ndamage  control ii\nHOBGOBLIN II x3", &types);
        assert_eq!(fitting.ship_name, "Rifter");
        assert_eq!(fitting.items[0].name, "Damage Control II");
        assert_eq!(fitting.items[1].name, "Hobgoblin II");
    }
}
