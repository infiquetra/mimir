//! Fitting import: pure parsing over the bundled fitting-types
//! catalogue. No egui, no state, no network, no database.

pub mod active_repair;
pub mod bay_usage;
pub mod calibration;
pub mod dna;
pub mod dps;
pub mod editor;
pub mod eft;
pub mod resources;
pub mod saved_copy;
pub mod ship_cap_stability;
pub mod ship_ehp;
pub mod ship_nav_targeting;
pub mod ship_peak_recharge;
pub mod ship_resistances;
pub mod ship_stats;
pub mod slot_layout;
pub mod write_map;

pub use active_repair::{fitting_active_repair, FittingActiveRepair};
pub use bay_usage::{bay_usage, BayBudget, BayUsage, BayUsageOutcome};
pub use calibration::{rig_calibration, CalibrationBudget, CalibrationOutcome};
pub use dna::{parse_dna, parse_import, MAX_DNA_EXPANDED_ITEMS, MAX_DNA_SEGMENTS};
pub use dps::{fitting_dps, FamilyDps, FittingDps, FittingDpsOutcome};
pub use editor::{add_item, remove_item, rename, set_quantity, EditRefusal};
pub use eft::{
    parse_eft, EftImportOutcome, ImportFatal, ImportFormat, ImportIssue, ImportIssueKind,
    ImportReport, ImportSection, ImportedCharge, ImportedFitting, ImportedItem,
    MAX_EFT_IMPORT_BYTES, MAX_EFT_IMPORT_LINES, MAX_STACK_QUANTITY,
};
pub use resources::{
    fitting_resources, fitting_resources_with_skills, resource_skill_levels, FittingResources,
    ResourceBudget, ResourceSkillLevels, ADVANCED_WEAPON_UPGRADES_SKILL_ID,
    CPU_MANAGEMENT_SKILL_ID, ELECTRONICS_UPGRADES_SKILL_ID, ENERGY_GRID_UPGRADES_SKILL_ID,
    POWER_GRID_MANAGEMENT_SKILL_ID, SHIELD_UPGRADES_SKILL_ID, WEAPON_UPGRADES_SKILL_ID,
};
pub use saved_copy::{convert_saved_fitting, SavedCopyOutcome, SavedCopyRefusal};
pub use ship_cap_stability::{
    fitting_cap_stability, fitting_cap_stability_with_module_bonuses, BonusedFittingCapStability,
    CapStabilityOutcome, FittingCapStability,
};
pub use ship_ehp::{
    ship_base_ehp, ship_ehp_with_module_bonuses, BonusedShipEhp, BonusedShipEhpOutcome,
    ShipBaseEhp, ShipBaseEhpOutcome,
};
pub use ship_nav_targeting::{ship_nav_targeting, ShipNavTargeting, ShipNavTargetingOutcome};
pub use ship_peak_recharge::{ship_base_peak_recharge, ShipBasePeakRecharge};
pub use ship_resistances::{
    resistance_stacking_penalty, ship_resistances, ship_resistances_with_module_bonuses,
    BonusedShipResistances, BonusedShipResistancesOutcome, ResistLayer, ShipResistances,
    ShipResistancesOutcome,
};
pub use ship_stats::{ship_base_stats, ShipBaseStats, ShipBaseStatsOutcome};
pub use slot_layout::{slot_layout, SlotBudget, SlotLayout, SlotLayoutOutcome};
pub use write_map::{build_save_request, DropReason, DroppedFittingItem, SaveMapping};
