//! Fitting import: pure parsing over the bundled fitting-types
//! catalogue. No egui, no state, no network, no database.

pub mod active_repair;
pub mod active_tank;
pub mod bay_usage;
pub mod breacher_dot;
pub mod calibration;
pub mod dna;
pub mod dogma_catalogue;
pub mod dogma_pipeline;
pub mod dps;
pub mod editor;
pub mod eft;
pub mod propulsion;
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
pub use active_tank::{
    fitting_active_tank, fitting_active_tank_with_catalogue, ActiveTankLayer, AncillaryPasteState,
    FittingActiveTank, SustainedBasis, ARMOR_REPAIR_ATTRIBUTE_ID, HULL_REPAIR_ATTRIBUTE_ID,
    SHIELD_REPAIR_ATTRIBUTE_ID,
};
pub use bay_usage::{bay_usage, BayBudget, BayUsage, BayUsageOutcome};
pub use breacher_dot::{
    breacher_dps, breacher_dps_against, breacher_dps_multi, breacher_time_to_kill_secs,
    BreacherPod, BreacherTarget, SCARAB_POD_M, SCARAB_POD_S,
};
pub use calibration::{rig_calibration, CalibrationBudget, CalibrationOutcome};
pub use dna::{parse_dna, parse_import, MAX_DNA_EXPANDED_ITEMS, MAX_DNA_SEGMENTS};
pub use dogma_catalogue::{
    evaluate_ship_attribute, fitting_location_skill_modifiers, fitting_ship_modifiers,
    propulsion_inputs, scaled_speed_factor_percent, shared_bundled_dogma, skill_location_modifiers,
    DogmaCatalogue, DogmaType, EffectModifier, FittingShipModifiers, ShipAttributeEvaluation,
    UnsupportedModifier, ACCELERATION_CONTROL_SKILL_ID, ATTR_ARMOR_DAMAGE_AMOUNT, ATTR_DURATION,
    ATTR_MASS_ADDITION, ATTR_MAX_VELOCITY, ATTR_SHIELD_BONUS, ATTR_SPEED_FACTOR,
    ATTR_STRUCTURE_DAMAGE_AMOUNT, ATTR_THRUST, REPAIR_SYSTEMS_SKILL_ID,
};
pub use dogma_pipeline::{
    evaluate_attribute, evaluate_attributes, stacking_effectiveness, DogmaModifier, DogmaOperator,
    EvaluatedAttribute, ModifierSource, ModuleState, OperandScaling, SkillContext, UnappliedEffect,
    UnappliedReason,
};
pub use dps::{fitting_dps, FamilyDps, FittingDps, FittingDpsOutcome};
pub use editor::{add_item, remove_item, rename, set_quantity, EditRefusal};
pub use eft::{
    parse_eft, EftImportOutcome, ImportFatal, ImportFormat, ImportIssue, ImportIssueKind,
    ImportReport, ImportSection, ImportedCharge, ImportedFitting, ImportedItem,
    MAX_EFT_IMPORT_BYTES, MAX_EFT_IMPORT_LINES, MAX_STACK_QUANTITY,
};
pub use propulsion::{
    align_time_secs, fitting_propulsion, mass_with_percent, propelled_max_velocity,
    FittingPropulsion, FittingPropulsionOutcome, PropulsionModule,
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
pub use ship_nav_targeting::{
    ship_nav_targeting, ship_nav_targeting_with_module_bonuses, BonusedShipNavTargeting,
    BonusedShipNavTargetingOutcome, ShipNavTargeting, ShipNavTargetingOutcome,
};
pub use ship_peak_recharge::{
    ship_base_peak_recharge, ship_shield_peak_recharge_with_module_bonuses,
    BonusedShieldPeakRecharge, BonusedShieldPeakRechargeOutcome, ShipBasePeakRecharge,
};
pub use ship_resistances::{
    resistance_stacking_penalty, ship_resistances, ship_resistances_with_module_bonuses,
    BonusedShipResistances, BonusedShipResistancesOutcome, ResistLayer, ShipResistances,
    ShipResistancesOutcome,
};
pub use ship_stats::{ship_base_stats, ShipBaseStats, ShipBaseStatsOutcome};
pub use slot_layout::{slot_layout, SlotBudget, SlotLayout, SlotLayoutOutcome};
pub use write_map::{build_save_request, DropReason, DroppedFittingItem, SaveMapping};
