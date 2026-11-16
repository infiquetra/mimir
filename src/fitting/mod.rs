//! Fitting import: pure parsing over the bundled fitting-types
//! catalogue. No egui, no state, no network, no database.

pub mod eft;
pub mod write_map;

pub use eft::{
    parse_eft, EftImportOutcome, ImportFatal, ImportIssue, ImportIssueKind, ImportReport,
    ImportSection, ImportedCharge, ImportedFitting, ImportedItem, MAX_EFT_IMPORT_BYTES,
    MAX_EFT_IMPORT_LINES, MAX_STACK_QUANTITY,
};
pub use write_map::{build_save_request, DropReason, DroppedFittingItem, SaveMapping};
