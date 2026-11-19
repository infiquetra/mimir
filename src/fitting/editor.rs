//! Pure edit operations on an imported fitting draft.
//!
//! The editor mutates only the in-memory import draft
//! ([`ImportedFitting`]); saved EVE fittings are never touched.
//! Every rule here is the importer's, called or mirrored exactly
//! (fitting-editor design sections 3 and 4): name lookup,
//! slot-effect proof, stacked-item classification, and quantity
//! bounds share one grammar with import, and a refusal is
//! delivered in the importer's fixed wording, never a guess.
//!
//! Pure: no egui, no state, no network, no database. After every
//! successful edit the charges counter is recounted from the
//! current rows (design section 4.5), `set_charge` and
//! `clear_charge` included; the parse-history counters
//! stay frozen. One edit deliberately does not recount: a ship
//! change cannot move a charge between rows, so it leaves the
//! charges counter and the whole parse report untouched instead
//! (change-ship design section 3.2). Logs carry counts and fixed
//! tokens only —
//! canonical catalogue names of successfully added items may be
//! logged (bundled data, not user input); refused names are
//! never logged.

use std::collections::HashMap;

use crate::fitting::eft::{
    absorb_stack, classify_module, parse_stack_quantity, slot_section, ImportFormat,
    ImportIssueKind, ImportReport, ImportSection, ImportedCharge, ImportedFitting, ImportedItem,
    ModuleOutcome, CATEGORY_CHARGE, CATEGORY_DRONE, CATEGORY_FIGHTER, CATEGORY_MODULE,
    CATEGORY_SHIP, CATEGORY_SUBSYSTEM,
};
use crate::names::fitting_types::{normalize_type_name, FittingTypes, NameLookup};

/// One refusal kind per import condition. The user-facing
/// wording delegates to the matching
/// [`ImportIssueKind::reason`] so the editor and the importer
/// never drift (fitting-editor design section 6.4).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EditRefusal {
    UnknownName,
    AmbiguousName,
    NotAModule,
    NoSlotForModule,
    StackedModule,
    InvalidQuantity,
    QuantityTooLarge,
}

impl EditRefusal {
    /// Fixed refusal wording, shared verbatim with the importer.
    pub fn reason(&self) -> &'static str {
        match self {
            EditRefusal::UnknownName => ImportIssueKind::UnknownName.reason(),
            EditRefusal::AmbiguousName => ImportIssueKind::AmbiguousName.reason(),
            EditRefusal::NotAModule => ImportIssueKind::NotAModule.reason(),
            EditRefusal::NoSlotForModule => ImportIssueKind::NoSlotForModule.reason(),
            EditRefusal::StackedModule => ImportIssueKind::StackedModule.reason(),
            EditRefusal::InvalidQuantity => ImportIssueKind::InvalidQuantity.reason(),
            EditRefusal::QuantityTooLarge => ImportIssueKind::QuantityTooLarge.reason(),
        }
    }
}

fn refusal_for_kind(kind: ImportIssueKind) -> EditRefusal {
    match kind {
        ImportIssueKind::UnknownName => EditRefusal::UnknownName,
        ImportIssueKind::AmbiguousName => EditRefusal::AmbiguousName,
        ImportIssueKind::NotAModule => EditRefusal::NotAModule,
        ImportIssueKind::NoSlotForModule => EditRefusal::NoSlotForModule,
        // `classify_module` yields only these four kinds; every
        // quantity condition is validated by
        // `parse_stack_quantity` instead.
        _ => EditRefusal::UnknownName,
    }
}

fn refused(kind: EditRefusal) -> EditRefusal {
    tracing::debug!("[FITTING] editor add refused kind={kind:?}");
    kind
}

/// One refusal kind per charge-edit condition (charge-editing
/// design section 4.1): a separate enum, not new
/// [`EditRefusal`] variants. The first three reasons delegate
/// to the matching [`ImportIssueKind::reason`] verbatim;
/// `IncompatibleCharge` carries this design's one new fixed
/// sentence.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChargeRefusal {
    UnknownCharge,
    AmbiguousCharge,
    NotACharge,
    IncompatibleCharge,
}

impl ChargeRefusal {
    /// Fixed refusal wording: the first three share the
    /// importer's reason strings; the fourth is this
    /// design's locked sentence.
    pub fn reason(&self) -> &'static str {
        match self {
            ChargeRefusal::UnknownCharge => ImportIssueKind::UnknownCharge.reason(),
            ChargeRefusal::AmbiguousCharge => ImportIssueKind::AmbiguousCharge.reason(),
            ChargeRefusal::NotACharge => ImportIssueKind::NotACharge.reason(),
            ChargeRefusal::IncompatibleCharge => {
                "Mimir's bundled data does not list this charge as one this module can be loaded with"
            }
        }
    }
}

fn charge_refused(kind: ChargeRefusal) -> ChargeRefusal {
    tracing::debug!("[FITTING] editor charge refused kind={kind:?}");
    kind
}

/// Recount charges from the current rows (design section 4.5).
/// Runs on every successful edit so the counter always describes
/// the draft, never the parse.
fn recount_charges(fitting: &mut ImportedFitting) {
    fitting.report.charges_noted = fitting
        .items
        .iter()
        .filter(|item| item.charge.is_some())
        .count();
}

/// Append one fitted slot item, classified exactly as the
/// importer classifies a plain line (design section 3.1). The
/// slot is proven by the bundled catalogue's dogma slot
/// effects; an unprovable slot is refused, never guessed.
fn add_slot(
    fitting: &mut ImportedFitting,
    types: &FittingTypes,
    name: &str,
) -> Result<(), EditRefusal> {
    match classify_module(types, name) {
        ModuleOutcome::Slot {
            type_id,
            name,
            section,
        } => {
            fitting.items.push(ImportedItem {
                type_id,
                name: name.clone(),
                section,
                quantity: 1,
                charge: None,
            });
            recount_charges(fitting);
            tracing::debug!(
                "[FITTING] editor item added name={name} section={section:?} items={}",
                fitting.items.len()
            );
            Ok(())
        }
        ModuleOutcome::Issue(kind) => Err(refused(refusal_for_kind(kind))),
    }
}

/// Append or merge one stacked drones/fighters/cargo entry,
/// classified exactly as the importer classifies a stacked
/// `Name xN` line (design section 3.2). The quantity is the
/// bare digits the user typed, without an `x` prefix.
fn add_stacked(
    fitting: &mut ImportedFitting,
    types: &FittingTypes,
    name: &str,
    quantity: &str,
) -> Result<(), EditRefusal> {
    let Some(amount) = parse_stack_quantity(quantity.trim()) else {
        return Err(refused(EditRefusal::InvalidQuantity));
    };
    let (type_id, type_name, category_id) = match types.lookup(name) {
        NameLookup::Unknown => return Err(refused(EditRefusal::UnknownName)),
        NameLookup::Ambiguous => return Err(refused(EditRefusal::AmbiguousName)),
        NameLookup::Found(row) => (row.type_id, row.name.clone(), row.category_id),
    };
    let section = match category_id {
        CATEGORY_DRONE => ImportSection::Drones,
        CATEGORY_FIGHTER => ImportSection::Fighters,
        CATEGORY_MODULE | CATEGORY_SUBSYSTEM => {
            return Err(refused(EditRefusal::StackedModule));
        }
        _ => ImportSection::Cargo,
    };
    let mut index: HashMap<i64, usize> = HashMap::new();
    for (position, item) in fitting.items.iter().enumerate() {
        index.entry(item.type_id).or_insert(position);
    }
    if absorb_stack(
        &mut fitting.items,
        &mut index,
        type_id,
        &type_name,
        section,
        amount,
    ) {
        recount_charges(fitting);
        tracing::debug!(
            "[FITTING] editor item added name={type_name} section={section:?} items={}",
            fitting.items.len()
        );
        Ok(())
    } else {
        Err(refused(EditRefusal::QuantityTooLarge))
    }
}

/// Add an item by exact catalogue name (design section 2.3):
/// `None` fits one slot item, `Some` adds a stacked quantity.
/// On success the charges counter is recounted.
pub fn add_item(
    fitting: &mut ImportedFitting,
    types: &FittingTypes,
    name: &str,
    quantity: Option<&str>,
) -> Result<(), EditRefusal> {
    match quantity {
        None => add_slot(fitting, types, name),
        Some(quantity) => add_stacked(fitting, types, name, quantity),
    }
}

/// A name made only of digits (with an optional leading
/// sign) reads as a raw number, never as a display name.
/// Digit-checking instead of parsing keeps digit strings
/// beyond the `i64` range excluded too.
fn is_numeric_name(trimmed: &str) -> bool {
    let digits = trimmed.strip_prefix(['-', '+']).unwrap_or(trimmed);
    !digits.is_empty() && digits.bytes().all(|byte| byte.is_ascii_digit())
}

/// An output figure the resources block can actually use:
/// present, finite, and non-negative (zero passes) — the
/// same usability rule the resources computation applies.
fn output_usable(value: Option<f64>) -> bool {
    value.is_some_and(|v| v.is_finite() && v >= 0.0)
}

/// One browsable catalogue row for the module browser
/// (design section 3.1). `type_id` is an internal key and sort
/// tiebreak only, never rendered and never logged; `name` is the
/// trimmed catalogue name a click passes to the add path;
/// `cpu` and `power` copy the row's optional need figures
/// untouched, so absence stays visible.
#[derive(Debug, Clone, PartialEq)]
pub struct BrowserRow {
    pub type_id: i64,
    pub name: String,
    pub cpu: Option<f64>,
    pub power: Option<f64>,
}

/// List every catalogue row that clicks straight into
/// `section` (design section 3.2): the name resolves to
/// exactly one type number, the trimmed name is non-empty and
/// not purely numeric, and the editor classifier's own
/// predicates prove the section — category 7 or 32 with
/// `slot_section` for slot tabs, `CATEGORY_DRONE` or
/// `CATEGORY_FIGHTER` for the stacked tabs. `Cargo` yields an
/// empty list: it has no positive membership, only catch-all
/// routing, so no tab ever browses it. Sorted by lowercased
/// name, then name, then type number (design section 3.4).
pub fn browser_candidates(types: &FittingTypes, section: ImportSection) -> Vec<BrowserRow> {
    // Named deferral, recorded in code: Cargo has no positive
    // membership to browse.
    if section == ImportSection::Cargo {
        return Vec::new();
    }
    // Distinct type numbers per normalized name, de-duplicated
    // by (name, type number) with first row in file order
    // winning — the load index's own semantics, computed here
    // without a per-row lookup log line.
    let mut counts: HashMap<String, std::collections::HashSet<i64>> = HashMap::new();
    let mut seen: std::collections::HashSet<(String, i64)> = std::collections::HashSet::new();
    for row in &types.types {
        let key = normalize_type_name(&row.name);
        if seen.insert((key.clone(), row.type_id)) {
            counts.entry(key).or_default().insert(row.type_id);
        }
    }
    let mut rows = Vec::new();
    // Emission de-duplicates on the same (normalized name,
    // type number) pair, first row in file order winning:
    // a later duplicate row the lookup index ignores must
    // never be listed (it could carry a different slot proof
    // than the row a click would actually add).
    let mut emitted: std::collections::HashSet<(String, i64)> = std::collections::HashSet::new();
    for row in &types.types {
        if !emitted.insert((normalize_type_name(&row.name), row.type_id)) {
            continue;
        }
        let trimmed = row.name.trim();
        if trimmed.is_empty() || is_numeric_name(trimmed) {
            continue;
        }
        let key = normalize_type_name(trimmed);
        if counts.get(&key).map(|ids| ids.len()) != Some(1) {
            continue;
        }
        let listed = match section {
            ImportSection::High
            | ImportSection::Medium
            | ImportSection::Low
            | ImportSection::Rig
            | ImportSection::Subsystem => {
                (row.category_id == CATEGORY_MODULE || row.category_id == CATEGORY_SUBSYSTEM)
                    && slot_section(&row.slot_effects) == Some(section)
            }
            ImportSection::Drones => row.category_id == CATEGORY_DRONE,
            ImportSection::Fighters => row.category_id == CATEGORY_FIGHTER,
            // Unreachable: Cargo returns above.
            ImportSection::Cargo => false,
        };
        if !listed {
            continue;
        }
        rows.push(BrowserRow {
            type_id: row.type_id,
            name: trimmed.to_string(),
            cpu: row.cpu,
            power: row.power,
        });
    }
    rows.sort_by(|a, b| {
        a.name
            .to_lowercase()
            .cmp(&b.name.to_lowercase())
            .then_with(|| a.name.cmp(&b.name))
            .then_with(|| a.type_id.cmp(&b.type_id))
    });
    rows
}

/// One choosable catalogue row for the new-fitting ship chooser
/// (design section 3.5). `type_id` is an internal key and sort
/// tiebreak only, never rendered and never logged; `name` is the
/// trimmed catalogue name a click uses to build the draft.
/// Unlike [`BrowserRow`], no figures are carried: a ship's output
/// pair is a membership proof, never row content, and the draft's
/// own statistic blocks print the real outputs once the hull is
/// chosen.
#[derive(Debug, Clone, PartialEq)]
pub struct ShipRow {
    pub type_id: i64,
    pub name: String,
}

/// List every catalogue row a click can turn into a valid empty
/// draft (design section 3.1): category 6 ([`CATEGORY_SHIP`], the
/// parsers' own constant), the trimmed name non-empty and not
/// purely numeric, the shipped unique-normalized-name guard (the
/// name maps to exactly one distinct type number across the whole
/// catalogue), and the stat-presence proof `cpu_output` and
/// `power_output` both present, finite, and non-negative —
/// dogma 48/11, the pair the resources block needs to print
/// bare-hull numbers, under the same usability rule that
/// block applies. Zero output passes. Sorted by lowercased name, then
/// name, then type number (design section 3.4).
pub fn ship_candidates(types: &FittingTypes) -> Vec<ShipRow> {
    // Distinct type numbers per normalized name, de-duplicated
    // by (name, type number) with first row in file order
    // winning — the browser's counting, mirrored exactly.
    let mut counts: HashMap<String, std::collections::HashSet<i64>> = HashMap::new();
    let mut seen: std::collections::HashSet<(String, i64)> = std::collections::HashSet::new();
    for row in &types.types {
        let key = normalize_type_name(&row.name);
        if seen.insert((key.clone(), row.type_id)) {
            counts.entry(key).or_default().insert(row.type_id);
        }
    }
    let mut rows = Vec::new();
    // Emission de-duplicates on the same (normalized name,
    // type number) pair, first row in file order winning: a
    // later duplicate row the lookup index ignores must never
    // be the row a click appears to choose.
    let mut emitted: std::collections::HashSet<(String, i64)> = std::collections::HashSet::new();
    for row in &types.types {
        if !emitted.insert((normalize_type_name(&row.name), row.type_id)) {
            continue;
        }
        let trimmed = row.name.trim();
        if trimmed.is_empty() || is_numeric_name(trimmed) {
            continue;
        }
        if row.category_id != CATEGORY_SHIP {
            continue;
        }
        if !output_usable(row.cpu_output) || !output_usable(row.power_output) {
            continue;
        }
        let key = normalize_type_name(trimmed);
        if counts.get(&key).map(|ids| ids.len()) != Some(1) {
            continue;
        }
        rows.push(ShipRow {
            type_id: row.type_id,
            name: trimmed.to_string(),
        });
    }
    rows.sort_by(|a, b| {
        a.name
            .to_lowercase()
            .cmp(&b.name.to_lowercase())
            .then_with(|| a.name.cmp(&b.name))
            .then_with(|| a.type_id.cmp(&b.type_id))
    });
    rows
}

/// Build the empty draft for a chosen ship row (design section
/// 5.2). The input is re-validated, never trusted: the type
/// number must resolve to a category-6 row carrying both outputs
/// whose trimmed name equals the row's name, otherwise `None`
/// and the caller stops. On success the draft carries
/// `ImportFormat::Created`, the name `New {ship} Fit`, and
/// all-zero import counters, because nothing was parsed. No
/// import text is synthesized and no parser is called.
pub fn new_fitting(types: &FittingTypes, ship: &ShipRow) -> Option<ImportedFitting> {
    let row = types.lookup_by_id(ship.type_id)?;
    if row.category_id != CATEGORY_SHIP
        || !output_usable(row.cpu_output)
        || !output_usable(row.power_output)
        || row.name.trim() != ship.name
    {
        return None;
    }
    Some(ImportedFitting {
        name: format!("New {} Fit", row.name.trim()),
        ship_type_id: row.type_id,
        ship_name: row.name.clone(),
        format: ImportFormat::Created,
        items: Vec::new(),
        report: ImportReport {
            imported_lines: 0,
            placeholder_lines: 0,
            charges_noted: 0,
            issues: Vec::new(),
        },
    })
}

/// How one ship-change attempt ended (change-ship design
/// section 3.1): the hull moved, the draft was already on the
/// target hull, or the input row failed validation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShipChangeOutcome {
    Changed,
    SameShip,
    Refused,
}

/// Move a draft onto a different ship (change-ship design
/// section 3). The input is re-validated exactly as
/// [`new_fitting`] validates it — the type number must resolve
/// to a category-6 row carrying both outputs whose trimmed name
/// equals the row's name — because a row the listing proof
/// would hand the panel is still untrusted input here. Any
/// failure returns [`ShipChangeOutcome::Refused`], mutates
/// nothing, and logs nothing; the caller logs the refusal
/// without the row's name, number, or search text. When the
/// validated row is the draft's own hull the outcome is
/// [`ShipChangeOutcome::SameShip`]: nothing is assigned, not
/// even `ship_name`, because a same-number click must not
/// silently respell a copied draft's resolver display name.
/// Otherwise exactly the ship pair is assigned from the
/// catalogue row — name, format, items, and the whole report
/// stay identical, with deliberately no charges recount: a hull
/// change cannot move a charge between rows, so recounting
/// would only rewrite a counter this operation has no business
/// touching. Only [`ShipChangeOutcome::Changed`] logs, at the
/// other edits' `debug` level, with the new catalogue name and
/// the carried item count.
pub fn change_ship(
    fitting: &mut ImportedFitting,
    types: &FittingTypes,
    ship: &ShipRow,
) -> ShipChangeOutcome {
    let Some(row) = types.lookup_by_id(ship.type_id) else {
        return ShipChangeOutcome::Refused;
    };
    if row.category_id != CATEGORY_SHIP
        || !output_usable(row.cpu_output)
        || !output_usable(row.power_output)
        || row.name.trim() != ship.name
    {
        return ShipChangeOutcome::Refused;
    }
    if row.type_id == fitting.ship_type_id {
        return ShipChangeOutcome::SameShip;
    }
    fitting.ship_type_id = row.type_id;
    fitting.ship_name = row.name.clone();
    tracing::debug!(
        "[FITTING] editor ship changed ship={} items={}",
        row.name,
        fitting.items.len()
    );
    ShipChangeOutcome::Changed
}

/// Remove the whole row at `index`, charge included. Returns
/// false and changes nothing when `index` is out of range.
pub fn remove_item(fitting: &mut ImportedFitting, index: usize) -> bool {
    if index >= fitting.items.len() {
        return false;
    }
    fitting.items.remove(index);
    recount_charges(fitting);
    tracing::debug!(
        "[FITTING] editor item removed items={} charges={}",
        fitting.items.len(),
        fitting.report.charges_noted
    );
    true
}

/// Set a stacked row's quantity to the typed absolute value
/// (design section 4.3). Slot rows and unparsable values are
/// refused with `InvalidQuantity`; zero is never accepted
/// because the import grammar has no zero-quantity line.
pub fn set_quantity(
    fitting: &mut ImportedFitting,
    index: usize,
    quantity: &str,
) -> Result<(), EditRefusal> {
    let refused_quantity = || {
        tracing::debug!("[FITTING] editor quantity refused");
        EditRefusal::InvalidQuantity
    };
    let Some(amount) = parse_stack_quantity(quantity.trim()) else {
        return Err(refused_quantity());
    };
    // Only stacked rows accept a quantity; slot rows render no
    // control, and an unknown row index is refused the same way.
    match fitting.items.get(index).map(|item| item.section) {
        Some(ImportSection::Drones | ImportSection::Fighters | ImportSection::Cargo) => {
            if let Some(item) = fitting.items.get_mut(index) {
                item.quantity = amount;
            }
        }
        _ => return Err(refused_quantity()),
    }
    recount_charges(fitting);
    tracing::debug!(
        "[FITTING] editor quantity set items={}",
        fitting.items.len()
    );
    Ok(())
}

/// Set or change the loaded charge on the slot row at
/// `index` by exact catalogue name (charge-editing design
/// section 4.2). Proof order: the row must sit in a slot
/// section; the name resolves by the importer's lookup;
/// the found row's category must be 8; and the charge's
/// group must be listed among the module's accepted
/// groups. Any refusal mutates nothing and logs only the
/// refusal line. On success the stored pair is the
/// catalogue row's canonical name and type number, the
/// charges counter is recounted, and the set line logs.
pub fn set_charge(
    fitting: &mut ImportedFitting,
    types: &FittingTypes,
    index: usize,
    name: &str,
) -> Result<(), ChargeRefusal> {
    let type_id = match fitting
        .items
        .get(index)
        .map(|item| (item.type_id, item.section))
    {
        Some((
            type_id,
            ImportSection::Low
            | ImportSection::Medium
            | ImportSection::High
            | ImportSection::Rig
            | ImportSection::Subsystem,
        )) => type_id,
        _ => return Err(charge_refused(ChargeRefusal::IncompatibleCharge)),
    };
    let (charge_type_id, charge_name, charge_group_id) = match types.lookup(name) {
        NameLookup::Unknown => return Err(charge_refused(ChargeRefusal::UnknownCharge)),
        NameLookup::Ambiguous => return Err(charge_refused(ChargeRefusal::AmbiguousCharge)),
        NameLookup::Found(row) => {
            if row.category_id != CATEGORY_CHARGE {
                return Err(charge_refused(ChargeRefusal::NotACharge));
            }
            (row.type_id, row.name.clone(), row.charge_group_id)
        }
    };
    let Some(module_row) = types.lookup_by_id(type_id) else {
        return Err(charge_refused(ChargeRefusal::IncompatibleCharge));
    };
    let Some(charge_group) = charge_group_id else {
        return Err(charge_refused(ChargeRefusal::IncompatibleCharge));
    };
    let Some(accepted) = module_row.charge_group_ids.as_deref() else {
        return Err(charge_refused(ChargeRefusal::IncompatibleCharge));
    };
    if accepted.is_empty() || !accepted.contains(&charge_group) {
        return Err(charge_refused(ChargeRefusal::IncompatibleCharge));
    }
    if let Some(item) = fitting.items.get_mut(index) {
        item.charge = Some(ImportedCharge {
            type_id: charge_type_id,
            name: charge_name.clone(),
        });
    }
    recount_charges(fitting);
    tracing::debug!(
        "[FITTING] editor charge set name={charge_name} charges={}",
        fitting.report.charges_noted
    );
    Ok(())
}

/// Clear the loaded charge on the slot row at `index`
/// (charge-editing design section 4.3). Returns `false`
/// and changes nothing when `index` is out of range, the
/// row is not a slot row, or the row carries no charge;
/// otherwise it clears the charge, recounts, logs, and
/// returns `true`.
pub fn clear_charge(fitting: &mut ImportedFitting, index: usize) -> bool {
    let eligible = matches!(
        fitting.items.get(index).map(|item| item.section),
        Some(
            ImportSection::Low
                | ImportSection::Medium
                | ImportSection::High
                | ImportSection::Rig
                | ImportSection::Subsystem
        )
    ) && fitting
        .items
        .get(index)
        .is_some_and(|item| item.charge.is_some());
    if !eligible {
        return false;
    }
    if let Some(item) = fitting.items.get_mut(index) {
        item.charge = None;
    }
    recount_charges(fitting);
    tracing::debug!(
        "[FITTING] editor charge cleared charges={}",
        fitting.report.charges_noted
    );
    true
}

/// Rename the fitting to the trimmed text. Empty is allowed:
/// every consumer has a display fallback (design section 4.4).
pub fn rename(fitting: &mut ImportedFitting, name: &str) {
    fitting.name = name.trim().to_string();
    recount_charges(fitting);
    tracing::debug!("[FITTING] editor renamed");
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fitting::dna::parse_import;
    use crate::fitting::eft::{parse_eft, EftImportOutcome, ImportedFitting, MAX_STACK_QUANTITY};
    use crate::ui::fittings::{fitting_to_dna, fitting_to_eft};
    use std::collections::BTreeSet;

    fn bundled_types() -> FittingTypes {
        FittingTypes::load_bundled().expect("bundled catalogue loads")
    }

    fn draft(text: &str, types: &FittingTypes) -> ImportedFitting {
        match parse_eft(text, types) {
            EftImportOutcome::Imported(fitting) => fitting,
            EftImportOutcome::Failed(fatal) => panic!("expected import, got {fatal:?}"),
        }
    }

    fn empty_draft(types: &FittingTypes) -> ImportedFitting {
        draft("[Rifter, T]\n", types)
    }

    fn item_triples(fitting: &ImportedFitting) -> BTreeSet<(i64, i64, i64)> {
        fitting
            .items
            .iter()
            .map(|item| (item.type_id, item.section as i64, item.quantity))
            .collect()
    }

    #[test]
    fn refusal_reasons_delegate_to_import_wording() {
        assert_eq!(
            EditRefusal::UnknownName.reason(),
            ImportIssueKind::UnknownName.reason()
        );
        assert_eq!(
            EditRefusal::AmbiguousName.reason(),
            ImportIssueKind::AmbiguousName.reason()
        );
        assert_eq!(
            EditRefusal::NotAModule.reason(),
            ImportIssueKind::NotAModule.reason()
        );
        assert_eq!(
            EditRefusal::NoSlotForModule.reason(),
            ImportIssueKind::NoSlotForModule.reason()
        );
        assert_eq!(
            EditRefusal::StackedModule.reason(),
            ImportIssueKind::StackedModule.reason()
        );
        assert_eq!(
            EditRefusal::InvalidQuantity.reason(),
            ImportIssueKind::InvalidQuantity.reason()
        );
        assert_eq!(
            EditRefusal::QuantityTooLarge.reason(),
            ImportIssueKind::QuantityTooLarge.reason()
        );
    }

    #[test]
    fn slot_add_appends_a_low_row_with_next_flag() {
        let types = bundled_types();
        let mut fitting = empty_draft(&types);

        add_item(&mut fitting, &types, "Damage Control II", None).expect("Damage Control II adds");

        assert_eq!(fitting.items.len(), 1);
        let item = &fitting.items[0];
        assert_eq!(item.type_id, 2048);
        assert_eq!(item.name, "Damage Control II");
        assert_eq!(item.section, ImportSection::Low);
        assert_eq!(item.quantity, 1);
        assert!(item.charge.is_none());

        let synth = fitting.to_character_fitting();
        assert_eq!(synth.items.len(), 1);
        assert_eq!(synth.items[0].flag, "LoSlot0");
        assert_eq!(synth.items[0].type_id, 2048);
    }

    #[test]
    fn each_section_is_proven_from_real_effects() {
        let types = bundled_types();
        let mut fitting = empty_draft(&types);

        add_item(&mut fitting, &types, "200mm AutoCannon II", None).expect("autocannon adds");
        add_item(&mut fitting, &types, "1MN Afterburner II", None).expect("afterburner adds");
        add_item(&mut fitting, &types, "Damage Control II", None).expect("dmg ctrl adds");
        add_item(
            &mut fitting,
            &types,
            "Small Projectile Burst Aerator I",
            None,
        )
        .expect("rig adds");

        assert_eq!(fitting.items.len(), 4);
        assert_eq!(fitting.items[0].section, ImportSection::High);
        assert_eq!(fitting.items[0].type_id, 2889);
        assert_eq!(fitting.items[1].section, ImportSection::Medium);
        assert_eq!(fitting.items[1].type_id, 438);
        assert_eq!(fitting.items[2].section, ImportSection::Low);
        assert_eq!(fitting.items[2].type_id, 2048);
        assert_eq!(fitting.items[3].section, ImportSection::Rig);
        assert_eq!(fitting.items[3].type_id, 31668);
        for item in &fitting.items {
            assert_eq!(item.quantity, 1);
            assert!(item.charge.is_none());
        }
    }

    #[test]
    fn slotless_module_is_refused_never_guessed() {
        // "Lux Kontos" is a bundled category-7 row with empty
        // slotEffects, verified against assets/sde/fitting_types.json
        // during implementation.
        let types = bundled_types();
        let mut fitting = empty_draft(&types);

        let result = add_item(&mut fitting, &types, "Lux Kontos", None);

        assert_eq!(result, Err(EditRefusal::NoSlotForModule));
        assert!(fitting.items.is_empty());
        assert_eq!(fitting.report.charges_noted, 0);
    }

    #[test]
    fn unknown_and_ambiguous_names_refuse_unchanged() {
        let types = bundled_types();
        let mut fitting = empty_draft(&types);

        let unknown = add_item(&mut fitting, &types, "Damage Control", None);
        assert_eq!(unknown, Err(EditRefusal::UnknownName));
        assert!(fitting.items.is_empty());

        // "Spiked Quafe" names two bundled rows, so the lookup is
        // ambiguous by construction.
        let ambiguous = add_item(&mut fitting, &types, "Spiked Quafe", None);
        assert_eq!(ambiguous, Err(EditRefusal::AmbiguousName));
        assert!(fitting.items.is_empty());

        let ambiguous_stacked = add_item(&mut fitting, &types, "Spiked Quafe", Some("3"));
        assert_eq!(ambiguous_stacked, Err(EditRefusal::AmbiguousName));
        assert!(fitting.items.is_empty());
    }

    #[test]
    fn drone_needs_a_quantity_and_then_lands_in_drones() {
        let types = bundled_types();
        let mut fitting = empty_draft(&types);

        let no_quantity = add_item(&mut fitting, &types, "Hobgoblin II", None);
        assert_eq!(no_quantity, Err(EditRefusal::NotAModule));
        assert!(fitting.items.is_empty());

        add_item(&mut fitting, &types, "Hobgoblin II", Some("5")).expect("Hobgoblin II x5 adds");

        assert_eq!(fitting.items.len(), 1);
        let item = &fitting.items[0];
        assert_eq!(item.type_id, 2456);
        assert_eq!(item.name, "Hobgoblin II");
        assert_eq!(item.section, ImportSection::Drones);
        assert_eq!(item.quantity, 5);
    }

    #[test]
    fn stacked_adds_merge_and_overflow_is_refused_intact() {
        let types = bundled_types();
        let mut fitting = empty_draft(&types);

        add_item(&mut fitting, &types, "Hobgoblin II", Some("2")).expect("x2 adds");
        add_item(&mut fitting, &types, "Hobgoblin II", Some("3")).expect("x3 merges");

        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].quantity, 5);

        set_quantity(&mut fitting, 0, "2147483647").expect("set to cap");
        assert_eq!(fitting.items[0].quantity, MAX_STACK_QUANTITY);

        let overflow = add_item(&mut fitting, &types, "Hobgoblin II", Some("1"));
        assert_eq!(overflow, Err(EditRefusal::QuantityTooLarge));
        assert_eq!(fitting.items.len(), 1);
        assert_eq!(fitting.items[0].quantity, MAX_STACK_QUANTITY);
    }

    #[test]
    fn module_with_quantity_and_bad_quantities_refuse() {
        let types = bundled_types();
        let mut fitting = empty_draft(&types);

        let stacked = add_item(&mut fitting, &types, "Damage Control II", Some("5"));
        assert_eq!(stacked, Err(EditRefusal::StackedModule));
        assert!(fitting.items.is_empty());

        for bad in ["0", "x5", "2147483648", "05", "-5", "+5", "-0"] {
            let result = add_item(&mut fitting, &types, "Hobgoblin II", Some(bad));
            assert_eq!(result, Err(EditRefusal::InvalidQuantity), "{bad}");
            assert!(fitting.items.is_empty(), "{bad}");
        }
    }

    #[test]
    fn cargo_add_lands_in_cargo() {
        let types = bundled_types();
        let mut fitting = empty_draft(&types);

        add_item(&mut fitting, &types, "Nanite Repair Paste", Some("8")).expect("paste adds");

        assert_eq!(fitting.items.len(), 1);
        let item = &fitting.items[0];
        assert_eq!(item.name, "Nanite Repair Paste");
        assert_eq!(item.section, ImportSection::Cargo);
        assert_eq!(item.quantity, 8);
    }

    #[test]
    fn remove_deletes_the_row_and_recounts_charges() {
        let types = bundled_types();
        // The design-pinned demo sample block, verbatim.
        let text = concat!(
            "[Rifter, Sample Brawler]\n",
            "Damage Control II\n",
            "Small Armor Repairer II\n",
            "\n",
            "1MN Afterburner II\n",
            "Warp Scrambler II\n",
            "\n",
            "200mm AutoCannon II, Republic Fleet EMP S\n",
            "200mm AutoCannon II\n",
            "200mm AutoCannon II\n",
            "\n",
            "Small Projectile Burst Aerator I\n",
            "[Empty Rig slot]\n",
            "\n",
            "Hobgoblin II x2\n",
            "\n",
            "EMP S x200\n",
            "Nanite Repair Paste x8"
        );
        let mut fitting = draft(text, &types);
        assert!(fitting.report.issues.is_empty());
        assert_eq!(fitting.report.imported_lines, 11);
        assert_eq!(fitting.report.placeholder_lines, 1);
        assert_eq!(fitting.report.charges_noted, 1);

        let charged = fitting
            .items
            .iter()
            .position(|item| item.charge.is_some())
            .expect("charged row exists");
        assert_eq!(fitting.items[charged].type_id, 2889);

        assert!(remove_item(&mut fitting, charged));
        assert_eq!(fitting.report.charges_noted, 0);
        assert_eq!(fitting.report.imported_lines, 11);
        assert_eq!(fitting.report.placeholder_lines, 1);
        assert!(fitting.report.issues.is_empty());

        assert!(!remove_item(&mut fitting, 999));
    }

    #[test]
    fn remove_renumbers_later_slots_in_order() {
        let types = bundled_types();
        let mut fitting = draft(
            "[Rifter, T]\n\
            200mm AutoCannon II\n\
            200mm AutoCannon II\n\
            200mm AutoCannon II\n",
            &types,
        );

        assert!(remove_item(&mut fitting, 0));

        let synth = fitting.to_character_fitting();
        let flags: Vec<&str> = synth.items.iter().map(|item| item.flag.as_str()).collect();
        assert_eq!(flags, vec!["HiSlot0", "HiSlot1"]);
    }

    #[test]
    fn set_quantity_replaces_and_refuses() {
        let types = bundled_types();
        let mut fitting = empty_draft(&types);

        add_item(&mut fitting, &types, "Hobgoblin II", Some("5")).expect("x5 adds");
        add_item(&mut fitting, &types, "Damage Control II", None).expect("slot adds");

        set_quantity(&mut fitting, 0, "7").expect("set replaces");
        assert_eq!(fitting.items[0].quantity, 7);

        let on_slot = set_quantity(&mut fitting, 1, "7");
        assert_eq!(on_slot, Err(EditRefusal::InvalidQuantity));
        assert_eq!(fitting.items[1].quantity, 1);

        let zero = set_quantity(&mut fitting, 0, "0");
        assert_eq!(zero, Err(EditRefusal::InvalidQuantity));
        assert_eq!(fitting.items[0].quantity, 7);

        let out_of_range = set_quantity(&mut fitting, 42, "7");
        assert_eq!(out_of_range, Err(EditRefusal::InvalidQuantity));
    }

    #[test]
    fn edited_draft_round_trips_through_eft_copy() {
        let types = bundled_types();
        let mut fitting = draft(
            "[Rifter, T]\n\
            200mm AutoCannon II, Republic Fleet EMP S\n",
            &types,
        );
        add_item(&mut fitting, &types, "Damage Control II", None).expect("slot adds");
        add_item(&mut fitting, &types, "Hobgoblin II", Some("3")).expect("drones add");
        rename(&mut fitting, "  Edited Brawler  ");
        assert_eq!(fitting.name, "Edited Brawler");

        let before = item_triples(&fitting);
        let synth = fitting.to_character_fitting();
        let local = fitting.name_resolver();
        let export = fitting_to_eft(&synth, &local).expect("edited draft exports");
        assert_eq!(export.skipped_unknown, 0);
        assert_eq!(export.skipped_empty, 0);

        let reimported = draft(&export.text, &types);
        assert!(
            reimported.report.issues.is_empty(),
            "{:?}",
            reimported.report.issues
        );
        assert_eq!(reimported.name, "Edited Brawler");
        assert_eq!(item_triples(&reimported), before);
    }

    fn browser_row<'a>(rows: &'a [BrowserRow], name: &str) -> &'a BrowserRow {
        rows.iter()
            .find(|row| row.name == name)
            .expect("demo row lists")
    }

    #[test]
    fn browser_counts_and_first_rows_match_bundled_catalogue() {
        let types = bundled_types();
        let table = [
            (
                ImportSection::High,
                1_371,
                [
                    "'Arbalest' Cruise Launcher I",
                    "'Arbalest' Heavy Missile Launcher",
                    "'Arbalest' Rapid Heavy Missile Launcher I",
                ],
            ),
            (
                ImportSection::Medium,
                903,
                [
                    "'Basic' Capacitor Recharger",
                    "'Basic' EM Shield Amplifier",
                    "'Basic' Explosive Shield Amplifier",
                ],
            ),
            (
                ImportSection::Low,
                1_005,
                [
                    "'Abatis' 100mm Steel Plates",
                    "'Accord' Core Compensation",
                    "'Anguis' Ice Harvester Upgrade",
                ],
            ),
            (
                ImportSection::Rig,
                642,
                [
                    "Capital Algid Energy Administrations Unit I",
                    "Capital Algid Energy Administrations Unit II",
                    "Capital Algid Hybrid Administrations Unit I",
                ],
            ),
            (
                ImportSection::Subsystem,
                48,
                [
                    "Legion Core - Augmented Antimatter Reactor",
                    "Legion Core - Dissolution Sequencer",
                    "Legion Core - Energy Parasitic Complex",
                ],
            ),
            (
                ImportSection::Drones,
                129,
                [
                    "'Augmented' Acolyte",
                    "'Augmented' Berserker",
                    "'Augmented' Hammerhead",
                ],
            ),
            (
                ImportSection::Fighters,
                94,
                ["Ametat I", "Ametat II", "Antaeus I"],
            ),
        ];
        for (section, count, first_three) in table {
            let rows = browser_candidates(&types, section);
            assert_eq!(rows.len(), count, "{section:?}");
            assert_eq!(rows[0].name, first_three[0], "{section:?}");
            assert_eq!(rows[1].name, first_three[1], "{section:?}");
            assert_eq!(rows[2].name, first_three[2], "{section:?}");
            for row in &rows {
                assert!(!row.name.is_empty(), "{section:?}");
                assert!(row.name.parse::<i64>().is_err(), "{section:?}");
                assert_eq!(row.name, row.name.trim(), "{section:?}");
            }
        }
        assert!(browser_candidates(&types, ImportSection::Cargo).is_empty());
    }

    #[test]
    fn browser_demo_pins_list_with_their_figures() {
        let types = bundled_types();

        let low = browser_candidates(&types, ImportSection::Low);
        assert_eq!(browser_row(&low, "Damage Control II").cpu, Some(30.0));
        assert_eq!(browser_row(&low, "Damage Control II").power, Some(1.0));

        let medium = browser_candidates(&types, ImportSection::Medium);
        assert_eq!(browser_row(&medium, "1MN Afterburner II").cpu, Some(15.0));
        assert_eq!(browser_row(&medium, "1MN Afterburner II").power, Some(11.0));

        let high = browser_candidates(&types, ImportSection::High);
        assert_eq!(browser_row(&high, "200mm AutoCannon II").cpu, Some(9.0));
        assert_eq!(browser_row(&high, "200mm AutoCannon II").power, Some(4.0));

        let rig = browser_candidates(&types, ImportSection::Rig);
        assert_eq!(
            browser_row(&rig, "Small Projectile Burst Aerator I").cpu,
            None
        );
        assert_eq!(
            browser_row(&rig, "Small Projectile Burst Aerator I").power,
            None
        );

        let drones = browser_candidates(&types, ImportSection::Drones);
        assert!(browser_row(&drones, "Hobgoblin II").name == "Hobgoblin II");
    }

    #[test]
    fn browser_slot_rows_all_add_into_their_tab() {
        let types = bundled_types();
        for section in [
            ImportSection::High,
            ImportSection::Medium,
            ImportSection::Low,
            ImportSection::Rig,
            ImportSection::Subsystem,
        ] {
            for row in browser_candidates(&types, section) {
                let mut fitting = empty_draft(&types);
                add_item(&mut fitting, &types, &row.name, None)
                    .unwrap_or_else(|refusal| panic!("{}: {refusal:?}", row.name));
                assert_eq!(fitting.items.len(), 1, "{}", row.name);
                assert_eq!(fitting.items[0].section, section, "{}", row.name);
                assert_eq!(fitting.items[0].name, row.name);
            }
        }
    }

    #[test]
    fn browser_stacked_rows_all_add_into_their_tab() {
        let types = bundled_types();
        for section in [ImportSection::Drones, ImportSection::Fighters] {
            for row in browser_candidates(&types, section) {
                let mut fitting = empty_draft(&types);
                add_item(&mut fitting, &types, &row.name, Some("1"))
                    .unwrap_or_else(|refusal| panic!("{}: {refusal:?}", row.name));
                assert_eq!(fitting.items.len(), 1, "{}", row.name);
                assert_eq!(fitting.items[0].section, section, "{}", row.name);
                assert_eq!(fitting.items[0].quantity, 1, "{}", row.name);
            }
        }
    }

    #[test]
    fn browser_exclusions_list_nowhere() {
        let types = bundled_types();
        let sections = [
            ImportSection::High,
            ImportSection::Medium,
            ImportSection::Low,
            ImportSection::Rig,
            ImportSection::Subsystem,
            ImportSection::Drones,
            ImportSection::Fighters,
            ImportSection::Cargo,
        ];
        let listed: BTreeSet<String> = sections
            .iter()
            .flat_map(|section| browser_candidates(&types, *section))
            .map(|row| row.name)
            .collect();
        for name in [
            "Lux Kontos",
            "Standup Anticapital Missile Launcher I",
            "Spiked Quafe",
            "Rifter",
            "EMP S",
        ] {
            assert!(!listed.contains(name), "{name} must not list");
        }
        // "EMP S" and "Nanite Repair Paste" still add by typed name;
        // the deferral is the listing, not the add path.
        let mut fitting = empty_draft(&types);
        add_item(&mut fitting, &types, "Nanite Repair Paste", Some("8")).expect("paste still adds");
        assert_eq!(fitting.items.len(), 1);
    }

    #[test]
    fn browser_fixture_guard_excludes_each_failure_mode() {
        // Shipped dual-fixture style: one catalogue exercising
        // every section 3.2 guard at once.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":100,"typeName":"Ordinary Module","categoryId":7,"slotEffects":[12]},
                {"typeId":101,"typeName":"12345","categoryId":7,"slotEffects":[12]},
                {"typeId":102,"typeName":"Twin Module","categoryId":7,"slotEffects":[12]},
                {"typeId":103,"typeName":"Twin Module","categoryId":7,"slotEffects":[12]},
                {"typeId":104,"typeName":"Structure Module","categoryId":66,"slotEffects":[12]},
                {"typeId":106,"typeName":"Dedup Module","categoryId":7,"slotEffects":[]},
                {"typeId":106,"typeName":"Dedup Module","categoryId":7,"slotEffects":[12]},
                {"typeId":105,"typeName":"Slotless Module","categoryId":7,"slotEffects":[]}]}"#,
        )
        .expect("fixture catalogue parses");
        let rows = browser_candidates(&catalogue, ImportSection::High);
        let names: Vec<&str> = rows.iter().map(|row| row.name.as_str()).collect();
        assert_eq!(names, vec!["Ordinary Module"]);
    }

    #[test]
    fn browser_figure_presence_matches_catalogue() {
        let types = bundled_types();

        let low = browser_candidates(&types, ImportSection::Low);
        let lean = browser_row(&low, "Limited Hyperspatial Accelerator");
        assert_eq!(lean.cpu, None);
        assert_eq!(lean.power, Some(1.0));

        let both = |section| {
            browser_candidates(&types, section)
                .iter()
                .filter(|row| row.cpu.is_some() && row.power.is_some())
                .count()
        };
        assert_eq!(both(ImportSection::High), 1_350);
        assert_eq!(both(ImportSection::Medium), 875);
        assert_eq!(both(ImportSection::Low), 952);
        for section in [
            ImportSection::Rig,
            ImportSection::Subsystem,
            ImportSection::Drones,
            ImportSection::Fighters,
        ] {
            for row in browser_candidates(&types, section) {
                assert_eq!(row.cpu, None, "{} {section:?}", row.name);
                assert_eq!(row.power, None, "{} {section:?}", row.name);
            }
        }
    }

    #[test]
    fn ship_candidates_count_and_ends_match_bundled_catalogue() {
        let types = bundled_types();
        let rows = ship_candidates(&types);
        assert_eq!(rows.len(), 404);
        assert_eq!(rows[0].name, "Abaddon");
        assert_eq!(rows[1].name, "Absolution");
        assert_eq!(rows[2].name, "Adrestia");
        assert_eq!(rows[401].name, "Zealot");
        assert_eq!(rows[402].name, "Zephyr");
        assert_eq!(rows[403].name, "Zirnitra");
        for row in &rows {
            assert!(!row.name.is_empty(), "{row:?}");
            assert!(row.name.parse::<i64>().is_err(), "{row:?}");
            assert_eq!(row.name, row.name.trim(), "{row:?}");
        }
    }

    #[test]
    fn ship_candidates_include_zero_output_hulls() {
        // Presence, never `> 0.0`: the two bundled ships whose
        // output pair is exactly zero still list.
        let types = bundled_types();
        let rows = ship_candidates(&types);
        let names: BTreeSet<&str> = rows.iter().map(|row| row.name.as_str()).collect();
        assert!(names.contains("Zephyr"));
        assert!(names.contains("Echelon"));
    }

    #[test]
    fn ship_construction_is_exhaustive_over_the_404() {
        let types = bundled_types();
        let rows = ship_candidates(&types);
        for row in &rows {
            let draft = new_fitting(&types, row).expect("every listed hull constructs");
            assert_eq!(draft.format, ImportFormat::Created);
            assert_eq!(draft.ship_type_id, row.type_id);
            assert_eq!(draft.ship_name, row.name);
            assert_eq!(draft.name, format!("New {} Fit", row.name));
            assert!(draft.items.is_empty());
            assert_eq!(draft.report.imported_lines, 0);
            assert_eq!(draft.report.placeholder_lines, 0);
            assert_eq!(draft.report.charges_noted, 0);
            assert!(draft.report.issues.is_empty());
        }
        // Full literal plus the shared demo pins: Rifter and
        // Drake both list, and the Rifter constructs by name.
        let rifter = rows
            .iter()
            .find(|row| row.name == "Rifter")
            .expect("Rifter lists");
        let draft = new_fitting(&types, rifter).expect("Rifter constructs");
        assert_eq!(draft.name, "New Rifter Fit");
        assert!(rows.iter().any(|row| row.name == "Drake"));
    }

    #[test]
    fn ship_new_draft_round_trips_through_both_copy_exports() {
        let types = bundled_types();
        let rows = ship_candidates(&types);
        let rifter = rows
            .iter()
            .find(|row| row.name == "Rifter")
            .expect("Rifter lists");
        let draft = new_fitting(&types, rifter).expect("Rifter constructs");
        let synth = draft.to_character_fitting();

        let eft = fitting_to_eft(&synth, &draft.name_resolver()).expect("EFT export");
        assert_eq!(eft.text, "[Rifter, New Rifter Fit]");
        let dna = fitting_to_dna(&synth).expect("DNA export");
        assert_eq!(dna.text, "587::");

        for text in [&eft.text, &dna.text] {
            match parse_import(text, &types) {
                EftImportOutcome::Imported(reimported) => {
                    assert_eq!(reimported.ship_type_id, 587);
                    assert_eq!(reimported.ship_name, "Rifter");
                    assert!(reimported.items.is_empty());
                }
                EftImportOutcome::Failed(fatal) => panic!("{text:?} must re-import: {fatal:?}"),
            }
        }
    }

    #[test]
    fn ship_fixture_guard_excludes_each_failure_mode() {
        // Shipped fixture style: one catalogue exercising
        // every section 3.1 rule at once.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":600,"typeName":"Ordinary Hull","categoryId":6,"cpuOutput":100.0,"powerOutput":50.0},
                {"typeId":601,"typeName":"No Cpu Hull","categoryId":6,"powerOutput":50.0},
                {"typeId":602,"typeName":"No Power Hull","categoryId":6,"cpuOutput":100.0},
                {"typeId":603,"typeName":"Twin Hull","categoryId":6,"cpuOutput":100.0,"powerOutput":50.0},
                {"typeId":604,"typeName":"Twin Hull","categoryId":6,"cpuOutput":100.0,"powerOutput":50.0},
                {"typeId":605,"typeName":"12345","categoryId":6,"cpuOutput":100.0,"powerOutput":50.0},
                {"typeId":607,"typeName":"Negative Hull","categoryId":6,"cpuOutput":-5.0,"powerOutput":50.0},
                {"typeId":608,"typeName":"99999999999999999999999999","categoryId":6,"cpuOutput":100.0,"powerOutput":50.0},
                {"typeId":606,"typeName":"Not A Ship","categoryId":7,"cpuOutput":100.0,"powerOutput":50.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let rows = ship_candidates(&catalogue);
        let names: Vec<&str> = rows.iter().map(|row| row.name.as_str()).collect();
        assert_eq!(names, vec!["Ordinary Hull"]);
        let draft = new_fitting(&catalogue, &rows[0]).expect("ordinary hull constructs");
        assert_eq!(draft.format, ImportFormat::Created);
        assert_eq!(draft.name, "New Ordinary Hull Fit");

        // The constructor re-validates: a row the listing proof
        // would never hand it (or no row at all) refuses.
        let non_ship = ShipRow {
            type_id: 606,
            name: "Not A Ship".to_string(),
        };
        assert!(new_fitting(&catalogue, &non_ship).is_none());
        let absent = ShipRow {
            type_id: 999_999,
            name: "Ordinary Hull".to_string(),
        };
        assert!(new_fitting(&catalogue, &absent).is_none());
        // A forged row for the negative-output hull refuses too:
        // present but unusable outputs prove nothing.
        let negative = ShipRow {
            type_id: 607,
            name: "Negative Hull".to_string(),
        };
        assert!(new_fitting(&catalogue, &negative).is_none());
    }

    fn ship_row<'a>(rows: &'a [ShipRow], name: &str) -> &'a ShipRow {
        rows.iter()
            .find(|row| row.name == name)
            .expect("candidate lists")
    }

    fn assert_carried_over(before: &ImportedFitting, after: &ImportedFitting) {
        assert_eq!(after.name, before.name);
        assert_eq!(after.format, before.format);
        assert_eq!(after.items, before.items);
        assert_eq!(after.report.imported_lines, before.report.imported_lines);
        assert_eq!(
            after.report.placeholder_lines,
            before.report.placeholder_lines
        );
        assert_eq!(after.report.charges_noted, before.report.charges_noted);
        assert_eq!(after.report.issues, before.report.issues);
    }

    fn assert_fitting_unchanged(before: &ImportedFitting, after: &ImportedFitting) {
        assert_eq!(after.ship_type_id, before.ship_type_id);
        assert_eq!(after.ship_name, before.ship_name);
        assert_carried_over(before, after);
    }

    #[test]
    fn change_ship_moves_only_the_hull_pair() {
        let types = bundled_types();
        let mut fitting = draft(
            "[Rifter, Charge Test]\n\
            200mm AutoCannon II, Republic Fleet EMP S\n\
            [Empty Rig slot]\n\
            Not A Real Item Name\n",
            &types,
        );
        assert_eq!(fitting.report.imported_lines, 1);
        assert_eq!(fitting.report.placeholder_lines, 1);
        assert_eq!(fitting.report.charges_noted, 1);
        assert_eq!(fitting.report.issues.len(), 1);
        // A stale counter that disagrees with the live charged
        // items must survive verbatim: ship change never
        // recounts charges (a recount would rewrite it to 1).
        fitting.report.charges_noted = 99;
        let before = fitting.clone();

        let punisher = ship_row(&ship_candidates(&types), "Punisher").clone();
        let outcome = change_ship(&mut fitting, &types, &punisher);

        assert_eq!(outcome, ShipChangeOutcome::Changed);
        assert_eq!(fitting.ship_type_id, 597);
        assert_eq!(fitting.ship_name, "Punisher");
        assert_carried_over(&before, &fitting);
    }

    #[test]
    fn ship_change_is_exhaustive_over_the_404() {
        let types = bundled_types();
        let rows = ship_candidates(&types);
        assert_eq!(rows.len(), 404);
        let base = draft(
            "[Rifter, Sweep]\n\
            Damage Control II\n\
            200mm AutoCannon II, Republic Fleet EMP S\n\
            Hobgoblin II x2\n",
            &types,
        );
        for row in &rows {
            let mut fitting = base.clone();
            let outcome = change_ship(&mut fitting, &types, row);
            if row.name == "Rifter" {
                assert_eq!(outcome, ShipChangeOutcome::SameShip, "{}", row.name);
                assert_fitting_unchanged(&base, &fitting);
            } else {
                assert_eq!(outcome, ShipChangeOutcome::Changed, "{}", row.name);
                assert_eq!(fitting.ship_type_id, row.type_id, "{}", row.name);
                assert_eq!(fitting.ship_name, row.name, "{}", row.name);
                assert_carried_over(&base, &fitting);
            }
        }
    }

    #[test]
    fn change_ship_same_ship_is_no_op_and_forged_rows_refuse() {
        let types = bundled_types();
        let rows = ship_candidates(&types);
        let mut fitting = draft("[Rifter, Stay]\n200mm AutoCannon II\n", &types);
        // A draft ship_name can diverge from the catalogue
        // spelling (copied drafts carry resolver names);
        // SameShip must not respell it from the catalogue row.
        fitting.ship_name = "Rifter (resolver spelling)".to_string();
        let before = fitting.clone();

        let own = ship_row(&rows, "Rifter").clone();
        assert_eq!(
            change_ship(&mut fitting, &types, &own),
            ShipChangeOutcome::SameShip
        );
        assert_fitting_unchanged(&before, &fitting);

        // Validation precedes the same-ship check: a forged row
        // carrying the current hull's type number under a wrong
        // name refuses instead of being blessed as a no-op.
        let forged = ShipRow {
            type_id: own.type_id,
            name: "Not The Rifter".to_string(),
        };
        assert_eq!(
            change_ship(&mut fitting, &types, &forged),
            ShipChangeOutcome::Refused
        );
        assert_fitting_unchanged(&before, &fitting);
    }

    #[test]
    fn change_ship_fixture_refusals_leave_the_draft_unchanged() {
        // The shipped guard catalogue: one listed row, plus a
        // row per failure mode the listing proof excludes.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":600,"typeName":"Ordinary Hull","categoryId":6,"cpuOutput":100.0,"powerOutput":50.0},
                {"typeId":601,"typeName":"No Cpu Hull","categoryId":6,"powerOutput":50.0},
                {"typeId":602,"typeName":"No Power Hull","categoryId":6,"cpuOutput":100.0},
                {"typeId":603,"typeName":"Twin Hull","categoryId":6,"cpuOutput":100.0,"powerOutput":50.0},
                {"typeId":604,"typeName":"Twin Hull","categoryId":6,"cpuOutput":100.0,"powerOutput":50.0},
                {"typeId":605,"typeName":"12345","categoryId":6,"cpuOutput":100.0,"powerOutput":50.0},
                {"typeId":607,"typeName":"Negative Hull","categoryId":6,"cpuOutput":-5.0,"powerOutput":50.0},
                {"typeId":608,"typeName":"99999999999999999999999999","categoryId":6,"cpuOutput":100.0,"powerOutput":50.0},
                {"typeId":606,"typeName":"Not A Ship","categoryId":7,"cpuOutput":100.0,"powerOutput":50.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let rows = ship_candidates(&catalogue);
        let names: Vec<&str> = rows.iter().map(|row| row.name.as_str()).collect();
        assert_eq!(names, vec!["Ordinary Hull"]);
        let mut fitting = new_fitting(&catalogue, &rows[0]).expect("ordinary hull constructs");
        let before = fitting.clone();

        for forged in [
            ShipRow {
                type_id: 606,
                name: "Not A Ship".to_string(),
            },
            ShipRow {
                type_id: 999_999,
                name: "Ordinary Hull".to_string(),
            },
            ShipRow {
                type_id: 607,
                name: "Negative Hull".to_string(),
            },
        ] {
            assert_eq!(
                change_ship(&mut fitting, &catalogue, &forged),
                ShipChangeOutcome::Refused,
                "{forged:?}"
            );
            assert_fitting_unchanged(&before, &fitting);
        }
        assert_eq!(
            change_ship(&mut fitting, &catalogue, &rows[0]),
            ShipChangeOutcome::SameShip
        );
        assert_fitting_unchanged(&before, &fitting);
    }

    #[test]
    fn change_ship_never_renames_the_draft() {
        let types = bundled_types();
        let rows = ship_candidates(&types);
        let punisher = ship_row(&rows, "Punisher").clone();

        // A fresh created draft's synthesized title survives.
        let mut created =
            new_fitting(&types, ship_row(&rows, "Rifter")).expect("Rifter constructs");
        assert_eq!(created.name, "New Rifter Fit");
        assert_eq!(
            change_ship(&mut created, &types, &punisher),
            ShipChangeOutcome::Changed
        );
        assert_eq!(created.name, "New Rifter Fit");

        // The section 4 collision: a hand rename to the same
        // string is indistinguishable from the synthesized one,
        // so it survives too.
        let mut typed = draft("[Rifter, Typed Name]\n200mm AutoCannon II\n", &types);
        rename(&mut typed, "New Rifter Fit");
        assert_eq!(typed.name, "New Rifter Fit");
        assert_eq!(
            change_ship(&mut typed, &types, &punisher),
            ShipChangeOutcome::Changed
        );
        assert_eq!(typed.name, "New Rifter Fit");

        let mut ordinary = draft("[Rifter, My Brawler]\n200mm AutoCannon II\n", &types);
        assert_eq!(
            change_ship(&mut ordinary, &types, &punisher),
            ShipChangeOutcome::Changed
        );
        assert_eq!(ordinary.name, "My Brawler");
    }

    #[test]
    fn ship_change_round_trips_through_both_copy_exports() {
        let types = bundled_types();
        let rows = ship_candidates(&types);
        let punisher = ship_row(&rows, "Punisher").clone();

        // Slot rows only: DNA covers slot sections, so a stacked
        // row would not re-import with the same item count.
        let mut fitting = draft(
            "[Rifter, Paper Trail]\n\
            200mm AutoCannon II\n\
            1MN Afterburner II\n",
            &types,
        );
        assert_eq!(
            change_ship(&mut fitting, &types, &punisher),
            ShipChangeOutcome::Changed
        );
        assert_eq!(fitting.name, "Paper Trail");
        let synth = fitting.to_character_fitting();
        let eft = fitting_to_eft(&synth, &fitting.name_resolver()).expect("EFT export");
        assert_eq!(eft.text.lines().next(), Some("[Punisher, Paper Trail]"));
        let dna = fitting_to_dna(&synth).expect("DNA export");
        for text in [&eft.text, &dna.text] {
            match parse_import(text, &types) {
                EftImportOutcome::Imported(reimported) => {
                    assert_eq!(reimported.ship_type_id, 597);
                    assert_eq!(reimported.ship_name, "Punisher");
                    assert_eq!(reimported.items.len(), fitting.items.len());
                }
                EftImportOutcome::Failed(fatal) => {
                    panic!("{text:?} must re-import: {fatal:?}")
                }
            }
        }

        let mut empty = new_fitting(&types, ship_row(&rows, "Rifter")).expect("Rifter constructs");
        assert_eq!(
            change_ship(&mut empty, &types, &punisher),
            ShipChangeOutcome::Changed
        );
        let synth = empty.to_character_fitting();
        let eft = fitting_to_eft(&synth, &empty.name_resolver()).expect("EFT export");
        assert_eq!(eft.text, "[Punisher, New Rifter Fit]");
        let dna = fitting_to_dna(&synth).expect("DNA export");
        assert_eq!(dna.text, "597::");
        for text in [&eft.text, &dna.text] {
            match parse_import(text, &types) {
                EftImportOutcome::Imported(reimported) => {
                    assert_eq!(reimported.ship_type_id, 597);
                    assert_eq!(reimported.ship_name, "Punisher");
                    assert!(reimported.items.is_empty());
                }
                EftImportOutcome::Failed(fatal) => {
                    panic!("{text:?} must re-import: {fatal:?}")
                }
            }
        }
    }

    const CHARGE_DEMO_EFT: &str = "[Rifter, Sample Brawler]\nDamage Control II\nSmall Armor Repairer II\n\n1MN Afterburner II\nWarp Scrambler II\n\n200mm AutoCannon II, Republic Fleet EMP S\n200mm AutoCannon II\n200mm AutoCannon II\n\nSmall Projectile Burst Aerator I\n[Empty Rig slot]\n\nHobgoblin II x2\n\nEMP S x200\nNanite Repair Paste x8";

    fn assert_charge_draft_unchanged(before: &ImportedFitting, after: &ImportedFitting) {
        assert_eq!(after.name, before.name);
        assert_eq!(after.format, before.format);
        assert_eq!(after.ship_type_id, before.ship_type_id);
        assert_eq!(after.ship_name, before.ship_name);
        assert_eq!(after.items, before.items);
        assert_eq!(after.report.imported_lines, before.report.imported_lines);
        assert_eq!(
            after.report.placeholder_lines,
            before.report.placeholder_lines
        );
        assert_eq!(after.report.charges_noted, before.report.charges_noted);
        assert_eq!(after.report.issues, before.report.issues);
    }

    fn find_slot_index(fitting: &ImportedFitting, type_id: i64, want_charge: bool) -> usize {
        fitting
            .items
            .iter()
            .position(|item| {
                item.type_id == type_id
                    && item.charge.is_some() == want_charge
                    && matches!(
                        item.section,
                        ImportSection::Low
                            | ImportSection::Medium
                            | ImportSection::High
                            | ImportSection::Rig
                            | ImportSection::Subsystem
                    )
            })
            .expect("slot row present")
    }

    // Test 3: set on a chargeless row.
    #[test]
    fn charge_set_stores_canonical_and_recounts() {
        let types = bundled_types();
        let mut fitting = draft(CHARGE_DEMO_EFT, &types);
        assert_eq!(fitting.report.charges_noted, 1);
        let index = find_slot_index(&fitting, 2889, false);
        let before = fitting.clone();
        set_charge(&mut fitting, &types, index, "EMP S").expect("EMP S sets");
        assert_eq!(
            fitting.items[index].charge.as_ref().map(|c| c.type_id),
            Some(185)
        );
        assert_eq!(
            fitting.items[index]
                .charge
                .as_ref()
                .map(|c| c.name.as_str()),
            Some("EMP S")
        );
        assert_eq!(fitting.report.charges_noted, 2);
        assert_eq!(fitting.name, before.name);
        assert_eq!(fitting.format, before.format);
        assert_eq!(fitting.items.len(), before.items.len());
        for (now, old) in fitting.items.iter().zip(before.items.iter()) {
            if std::ptr::eq(now, &fitting.items[index]) {
                assert_eq!(now.type_id, old.type_id);
                assert_eq!(now.name, old.name);
                assert_eq!(now.section, old.section);
                assert_eq!(now.quantity, old.quantity);
            } else {
                assert_eq!(now, old);
            }
        }
        assert_eq!(fitting.report.imported_lines, before.report.imported_lines);
        assert_eq!(
            fitting.report.placeholder_lines,
            before.report.placeholder_lines
        );
        assert_eq!(fitting.report.issues, before.report.issues);
    }

    // Test 4: change and re-set.
    #[test]
    fn charge_change_and_reset() {
        let types = bundled_types();
        let mut fitting = draft(CHARGE_DEMO_EFT, &types);
        let index = find_slot_index(&fitting, 2889, true);
        assert_eq!(fitting.report.charges_noted, 1);
        set_charge(&mut fitting, &types, index, "EMP S").expect("change to EMP S");
        assert_eq!(
            fitting.items[index].charge.as_ref().map(|c| c.type_id),
            Some(185)
        );
        assert_eq!(fitting.report.charges_noted, 1);
        let before = fitting.clone();
        set_charge(&mut fitting, &types, index, "EMP S").expect("re-set succeeds");
        assert_eq!(fitting.items[index].charge, before.items[index].charge);
        assert_eq!(fitting.report.charges_noted, 1);
        set_charge(&mut fitting, &types, index, "  eMp   s  ").expect("respelling succeeds");
        assert_eq!(
            fitting.items[index].charge.as_ref().map(|c| c.type_id),
            Some(185)
        );
        assert_eq!(
            fitting.items[index]
                .charge
                .as_ref()
                .map(|c| c.name.as_str()),
            Some("EMP S")
        );
        assert_eq!(fitting.report.charges_noted, 1);
    }

    // Test 5: clear.
    #[test]
    fn charge_clear_and_false_cases() {
        let types = bundled_types();
        let mut fitting = draft(CHARGE_DEMO_EFT, &types);
        let charged = find_slot_index(&fitting, 2889, true);
        assert!(clear_charge(&mut fitting, charged));
        assert!(fitting.items[charged].charge.is_none());
        assert_eq!(fitting.report.charges_noted, 0);
        let before = fitting.clone();
        assert!(!clear_charge(&mut fitting, charged));
        assert_charge_draft_unchanged(&before, &fitting);
        let stacked = fitting
            .items
            .iter()
            .position(|item| item.type_id == 2456)
            .expect("stacked Hobgoblin present");
        assert!(!matches!(
            fitting.items[stacked].section,
            ImportSection::Low
                | ImportSection::Medium
                | ImportSection::High
                | ImportSection::Rig
                | ImportSection::Subsystem
        ));
        let before = fitting.clone();
        assert!(!clear_charge(&mut fitting, stacked));
        assert_charge_draft_unchanged(&before, &fitting);
        let before = fitting.clone();
        let out_of_range = fitting.items.len();
        assert!(!clear_charge(&mut fitting, out_of_range));
        assert_charge_draft_unchanged(&before, &fitting);
    }

    // Test 6: every refusal changes nothing.
    #[test]
    fn charge_refusals_change_nothing() {
        let types = bundled_types();
        let mut fitting = draft(CHARGE_DEMO_EFT, &types);
        let autocannon = find_slot_index(&fitting, 2889, false);
        let damage_control = find_slot_index(&fitting, 2048, false);
        let stacked = fitting
            .items
            .iter()
            .position(|item| item.type_id == 2456)
            .expect("stacked Hobgoblin present");
        let launcher = draft("[Rifter, T]\nLight Missile Launcher I\n", &types)
            .items
            .len();
        let mut launcher_draft = draft("[Rifter, T]\nLight Missile Launcher I\n", &types);
        assert_eq!(launcher, 1);
        let launcher_index = 0;
        let cases: &[(usize, &str, ChargeRefusal)] = &[
            (autocannon, "No Such Charge", ChargeRefusal::UnknownCharge),
            (autocannon, "  ", ChargeRefusal::UnknownCharge),
            (autocannon, "Tritanium", ChargeRefusal::NotACharge),
            (autocannon, "Damage Control II", ChargeRefusal::NotACharge),
            (
                autocannon,
                "Scourge Light Missile",
                ChargeRefusal::IncompatibleCharge,
            ),
            (autocannon, "Radio S", ChargeRefusal::IncompatibleCharge),
            (damage_control, "EMP S", ChargeRefusal::IncompatibleCharge),
            (stacked, "EMP S", ChargeRefusal::IncompatibleCharge),
        ];
        for (index, name, expected) in cases {
            let before = fitting.clone();
            assert_eq!(
                set_charge(&mut fitting, &types, *index, name),
                Err(*expected),
                "{name:?}"
            );
            assert_charge_draft_unchanged(&before, &fitting);
        }
        // Row-eligibility-first ordering: an unknown name on a
        // stacked row is still the row refusal, never Unknown.
        let before = fitting.clone();
        assert_eq!(
            set_charge(&mut fitting, &types, stacked, "No Such Charge"),
            Err(ChargeRefusal::IncompatibleCharge)
        );
        assert_charge_draft_unchanged(&before, &fitting);
        let before = fitting.clone();
        let out_of_range = fitting.items.len();
        assert_eq!(
            set_charge(&mut fitting, &types, out_of_range, "EMP S"),
            Err(ChargeRefusal::IncompatibleCharge)
        );
        assert_charge_draft_unchanged(&before, &fitting);
        let before = launcher_draft.clone();
        assert_eq!(
            set_charge(
                &mut launcher_draft,
                &types,
                launcher_index,
                "Standup Light Missile"
            ),
            Err(ChargeRefusal::IncompatibleCharge)
        );
        assert_charge_draft_unchanged(&before, &launcher_draft);
    }

    // Test 6 (synthetic): ambiguous and unprovable rows.
    #[test]
    fn charge_refusals_synthetic_fixtures() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":700,"typeName":"Fixture Gun","categoryId":7,"slotEffects":[12],"chargeGroupIds":[83]},
                {"typeId":800,"typeName":"Shared Name","categoryId":8,"slotEffects":[],"chargeGroupId":83},
                {"typeId":801,"typeName":"Shared Name","categoryId":8,"slotEffects":[],"chargeGroupId":83},
                {"typeId":802,"typeName":"No Group Charge","categoryId":8,"slotEffects":[]},
                {"typeId":803,"typeName":"Good Charge","categoryId":8,"slotEffects":[],"chargeGroupId":83}]}"#,
        )
        .expect("synthetic catalogue parses");
        let mut fitting = ImportedFitting {
            name: "Fixture".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
            format: ImportFormat::Eft,
            items: vec![ImportedItem {
                type_id: 700,
                name: "Fixture Gun".to_string(),
                section: ImportSection::High,
                quantity: 1,
                charge: None,
            }],
            report: ImportReport {
                imported_lines: 1,
                placeholder_lines: 0,
                charges_noted: 0,
                issues: Vec::new(),
            },
        };
        let before = fitting.clone();
        assert_eq!(
            set_charge(&mut fitting, &catalogue, 0, "Shared Name"),
            Err(ChargeRefusal::AmbiguousCharge)
        );
        assert_charge_draft_unchanged(&before, &fitting);
        let before = fitting.clone();
        assert_eq!(
            set_charge(&mut fitting, &catalogue, 0, "No Group Charge"),
            Err(ChargeRefusal::IncompatibleCharge)
        );
        assert_charge_draft_unchanged(&before, &fitting);
        let mut hostile = ImportedFitting {
            name: "Fixture".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
            format: ImportFormat::Eft,
            items: vec![ImportedItem {
                type_id: 999_999,
                name: "Orphan Row".to_string(),
                section: ImportSection::High,
                quantity: 1,
                charge: None,
            }],
            report: ImportReport {
                imported_lines: 1,
                placeholder_lines: 0,
                charges_noted: 0,
                issues: Vec::new(),
            },
        };
        let before = hostile.clone();
        assert_eq!(
            set_charge(&mut hostile, &catalogue, 0, "Good Charge"),
            Err(ChargeRefusal::IncompatibleCharge)
        );
        assert_charge_draft_unchanged(&before, &hostile);
    }

    // Test 7: families beyond turrets.
    #[test]
    fn charge_families_beyond_turrets() {
        let types = bundled_types();
        let mut fitting = draft("[Rifter, T]\nLight Missile Launcher I\n", &types);
        set_charge(&mut fitting, &types, 0, "Scourge Light Missile").expect("light missile sets");
        assert_eq!(
            fitting.items[0].charge.as_ref().map(|c| c.type_id),
            Some(210)
        );
        assert_eq!(fitting.report.charges_noted, 1);
        let kept = fitting.items[0].charge.clone();
        assert_eq!(
            set_charge(&mut fitting, &types, 0, "Scourge Torpedo"),
            Err(ChargeRefusal::IncompatibleCharge)
        );
        assert_eq!(fitting.items[0].charge, kept);
        assert_eq!(
            fitting.items[0].charge.as_ref().map(|c| c.type_id),
            Some(210)
        );
        assert_eq!(fitting.report.charges_noted, 1);
        add_item(&mut fitting, &types, "Sensor Booster II", None).expect("sensor booster adds");
        let sensor_index = fitting.items.len() - 1;
        assert_eq!(fitting.items[sensor_index].type_id, 1952);
        set_charge(&mut fitting, &types, sensor_index, "Targeting Range Script")
            .expect("script sets");
        assert_eq!(
            fitting.items[sensor_index]
                .charge
                .as_ref()
                .map(|c| c.type_id),
            Some(29_009)
        );
        let kept = fitting.items[sensor_index].charge.clone();
        assert_eq!(
            set_charge(&mut fitting, &types, sensor_index, "EMP S"),
            Err(ChargeRefusal::IncompatibleCharge)
        );
        assert_eq!(fitting.items[sensor_index].charge, kept);
        add_item(&mut fitting, &types, "Small Capacitor Booster II", None)
            .expect("cap booster adds");
        let cap_index = fitting.items.len() - 1;
        assert_eq!(fitting.items[cap_index].type_id, 3568);
        set_charge(&mut fitting, &types, cap_index, "Cap Booster 400").expect("cap charge sets");
        assert_eq!(
            fitting.items[cap_index].charge.as_ref().map(|c| c.type_id),
            Some(11_287)
        );
    }

    // Test 8: the locked non-check.
    #[test]
    fn charge_size_deferral_accepts_wrong_size() {
        let types = bundled_types();
        let mut fitting = draft("[Rifter, T]\nGatling Pulse Laser I\n", &types);
        set_charge(&mut fitting, &types, 0, "Radio M").expect("Radio M sets by group");
        assert_eq!(
            fitting.items[0].charge.as_ref().map(|c| c.type_id),
            Some(247)
        );
        assert_eq!(fitting.report.charges_noted, 1);
    }

    // Test 9: exhaustive over every carrier.
    #[test]
    fn charge_groups_exhaustive_over_carriers() {
        let types = bundled_types();
        let carriers: Vec<_> = types
            .types
            .iter()
            .filter(|row| row.charge_group_ids.is_some())
            .collect();
        assert_eq!(carriers.len(), 980);
        for module in carriers {
            let accepted = module
                .charge_group_ids
                .as_ref()
                .expect("carrier lists groups");
            let charge = types
                .types
                .iter()
                .find(|row| {
                    row.category_id == 8
                        && row
                            .charge_group_id
                            .is_some_and(|group| accepted.contains(&group))
                })
                .expect("each carrier has a charge");
            let section = slot_section(&module.slot_effects).expect("carrier has a slot");
            let mut fitting = ImportedFitting {
                name: "Sweep".to_string(),
                ship_type_id: 587,
                ship_name: "Rifter".to_string(),
                format: ImportFormat::Created,
                items: vec![ImportedItem {
                    type_id: module.type_id,
                    name: module.name.clone(),
                    section,
                    quantity: 1,
                    charge: None,
                }],
                report: ImportReport {
                    imported_lines: 0,
                    placeholder_lines: 0,
                    charges_noted: 0,
                    issues: Vec::new(),
                },
            };
            set_charge(&mut fitting, &types, 0, &charge.name).expect("first listed charge sets");
            assert_eq!(
                fitting.items[0].charge.as_ref().map(|c| c.type_id),
                Some(charge.type_id)
            );
            assert_eq!(
                fitting.items[0].charge.as_ref().map(|c| c.name.as_str()),
                Some(charge.name.as_str())
            );
        }
    }

    // Test 10: copy round trip.
    #[test]
    fn charge_copy_round_trip_excludes() {
        let types = bundled_types();
        let mut fitting = draft(CHARGE_DEMO_EFT, &types);
        let index = find_slot_index(&fitting, 2889, false);
        set_charge(&mut fitting, &types, index, "EMP S").expect("editor charge sets");
        let synth = fitting.to_character_fitting();
        let eft = fitting_to_eft(&synth, &fitting.name_resolver()).expect("EFT export");
        match parse_import(&eft.text, &types) {
            EftImportOutcome::Imported(reimported) => {
                assert!(reimported.report.issues.is_empty());
                assert_eq!(reimported.items.len(), fitting.items.len());
                assert_eq!(reimported.report.charges_noted, 0);
                assert!(reimported.items.iter().all(|item| item.charge.is_none()));
            }
            EftImportOutcome::Failed(fatal) => panic!("copy must re-import: {fatal:?}"),
        }
    }
}
