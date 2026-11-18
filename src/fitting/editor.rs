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
//! current rows (design section 4.5); the parse-history counters
//! stay frozen. Logs carry counts and fixed tokens only —
//! canonical catalogue names of successfully added items may be
//! logged (bundled data, not user input); refused names are
//! never logged.

use std::collections::HashMap;

use crate::fitting::eft::{
    absorb_stack, classify_module, parse_stack_quantity, ImportIssueKind, ImportSection,
    ImportedFitting, ImportedItem, ModuleOutcome, CATEGORY_DRONE, CATEGORY_FIGHTER,
    CATEGORY_MODULE, CATEGORY_SUBSYSTEM,
};
use crate::names::fitting_types::{FittingTypes, NameLookup};

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
    use crate::fitting::eft::{parse_eft, EftImportOutcome, ImportedFitting, MAX_STACK_QUANTITY};
    use crate::ui::fittings::fitting_to_eft;
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
}
