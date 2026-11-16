//! Fitting import: pure parsing over the bundled fitting-types
//! catalogue. No egui, no state, no network, no database.

pub mod dna;
pub mod eft;
pub mod resources;
pub mod ship_ehp;
pub mod ship_peak_recharge;
pub mod ship_resistances;
pub mod ship_stats;
pub mod write_map;

pub use dna::{parse_dna, parse_import, MAX_DNA_EXPANDED_ITEMS, MAX_DNA_SEGMENTS};
pub use eft::{
    parse_eft, EftImportOutcome, ImportFatal, ImportFormat, ImportIssue, ImportIssueKind,
    ImportReport, ImportSection, ImportedCharge, ImportedFitting, ImportedItem,
    MAX_EFT_IMPORT_BYTES, MAX_EFT_IMPORT_LINES, MAX_STACK_QUANTITY,
};
pub use resources::{
    fitting_resources, fitting_resources_with_skills, resource_skill_levels, FittingResources,
    ResourceBudget, ResourceSkillLevels, CPU_MANAGEMENT_SKILL_ID, POWER_GRID_MANAGEMENT_SKILL_ID,
};
pub use ship_ehp::{ship_base_ehp, ShipBaseEhp, ShipBaseEhpOutcome};
pub use ship_peak_recharge::{ship_base_peak_recharge, ShipBasePeakRecharge};
pub use ship_resistances::{
    ship_resistances, ResistLayer, ShipResistances, ShipResistancesOutcome,
};
pub use ship_stats::{ship_base_stats, ShipBaseStats, ShipBaseStatsOutcome};
pub use write_map::{build_save_request, DropReason, DroppedFittingItem, SaveMapping};
