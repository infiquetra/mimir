//! Fittings: the active character's saved fittings, read-only,
//! with EFT clipboard export of the selected fitting. The view
//! sets request flags only (`retry_requested`,
//! `stepup_requested`); it never fetches. Every rendered
//! string is a resolved EVE name, sanitized user text, a
//! section word, or a row count — never a raw numeric ID,
//! and never a raw ESI flag string.

use super::widgets;
use crate::app::state::{
    AppState, FittingWriteConfirm, FittingWriteKind, FittingWriteRequest, FittingsData, LoadState,
    SectionError, StepUpRequest,
};
use crate::config::EveConfig;
use crate::esi::models::CharacterFitting;
use crate::fitting::active_repair::{fitting_active_repair, FittingActiveRepair};
use crate::fitting::bay_usage::{bay_usage, BayBudget, BayUsage, BayUsageOutcome};
use crate::fitting::calibration::{rig_calibration, CalibrationBudget, CalibrationOutcome};
use crate::fitting::dna::parse_import;
use crate::fitting::dps::{fitting_dps, FamilyDps, FittingDps, FittingDpsOutcome};
use crate::fitting::editor::{
    add_item as editor_add_item, remove_item as editor_remove_item, rename as editor_rename,
    set_quantity as editor_set_quantity, EditRefusal,
};
use crate::fitting::eft::{
    EftImportOutcome, ImportFormat, ImportIssue, ImportSection, ImportedFitting,
};
#[cfg(test)]
use crate::fitting::resources::fitting_resources;
use crate::fitting::resources::{
    fitting_resources_with_skills, resource_skill_levels, FittingResources, ResourceBudget,
    ResourceSkillLevels, ADVANCED_WEAPON_UPGRADES_SKILL_ID, CPU_MANAGEMENT_SKILL_ID,
    ELECTRONICS_UPGRADES_SKILL_ID, ENERGY_GRID_UPGRADES_SKILL_ID, POWER_GRID_MANAGEMENT_SKILL_ID,
    SHIELD_UPGRADES_SKILL_ID, WEAPON_UPGRADES_SKILL_ID,
};
use crate::fitting::ship_cap_stability::{
    fitting_cap_stability, CapStabilityOutcome, FittingCapStability,
};
use crate::fitting::ship_ehp::{ship_base_ehp, ShipBaseEhp, ShipBaseEhpOutcome};
use crate::fitting::ship_nav_targeting::{
    ship_nav_targeting, ShipNavTargeting, ShipNavTargetingOutcome,
};
use crate::fitting::ship_peak_recharge::ship_base_peak_recharge;
use crate::fitting::ship_resistances::{
    ship_resistances, ResistLayer, ShipResistances, ShipResistancesOutcome,
};
use crate::fitting::ship_stats::{ship_base_stats, ShipBaseStats, ShipBaseStatsOutcome};
use crate::fitting::slot_layout::{slot_layout, SlotBudget, SlotLayout, SlotLayoutOutcome};
use crate::fitting::write_map::{build_save_request, DropReason, DroppedFittingItem, SaveMapping};
use crate::names::fitting_types::FittingTypes;
use crate::names::resolver::NameResolver;
use crate::names::sde::Sde;
use crate::ui::portraits::{
    ensure_type_icon_requested, show_type_icon, PortraitImageCache, TYPE_ICON_PX,
};
use std::collections::HashMap;

pub const FITTINGS_RENDER_MAX: usize = 100;

/// Maximum per-line problems shown in the import report; the rest are
/// disclosed by count (design section 8.2).
pub const IMPORT_ISSUES_RENDER_MAX: usize = 20;

/// Maximum EFT lines one fitted slot row may expand to. No EVE ship
/// has more than eight slots in a section; quantities decode from
/// remote JSON unvalidated, so a hostile quantity must never be able
/// to expand into unbounded clipboard text.
const MAX_EFT_SLOT_REPEATS: usize = 16;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FittingSection {
    Low,
    Medium,
    High,
    Rig,
    Subsystem,
    Drones,
    Fighters,
    Cargo,
}

pub fn section_for_flag(flag: &str) -> FittingSection {
    if flag.starts_with("LoSlot") {
        FittingSection::Low
    } else if flag.starts_with("MedSlot") {
        FittingSection::Medium
    } else if flag.starts_with("HiSlot") {
        FittingSection::High
    } else if flag.starts_with("RigSlot") {
        FittingSection::Rig
    } else if flag.starts_with("SubSystemSlot") {
        FittingSection::Subsystem
    } else if flag == "DroneBay" {
        FittingSection::Drones
    } else if flag == "FighterBay" {
        FittingSection::Fighters
    } else {
        FittingSection::Cargo
    }
}

pub fn section_label(section: FittingSection) -> &'static str {
    match section {
        FittingSection::Low => "Low slots",
        FittingSection::Medium => "Medium slots",
        FittingSection::High => "High slots",
        FittingSection::Rig => "Rigs",
        FittingSection::Subsystem => "Subsystems",
        FittingSection::Drones => "Drones",
        FittingSection::Fighters => "Fighters",
        FittingSection::Cargo => "Cargo and other items",
    }
}

fn section_order(section: FittingSection) -> u8 {
    match section {
        FittingSection::Low => 0,
        FittingSection::Medium => 1,
        FittingSection::High => 2,
        FittingSection::Rig => 3,
        FittingSection::Subsystem => 4,
        FittingSection::Drones => 5,
        FittingSection::Fighters => 6,
        FittingSection::Cargo => 7,
    }
}

const SECTION_ORDER: [FittingSection; 8] = [
    FittingSection::Low,
    FittingSection::Medium,
    FittingSection::High,
    FittingSection::Rig,
    FittingSection::Subsystem,
    FittingSection::Drones,
    FittingSection::Fighters,
    FittingSection::Cargo,
];

fn sanitize_single_line(raw: &str) -> String {
    let replaced: String = raw
        .chars()
        .map(|c| if c.is_control() { ' ' } else { c })
        .collect();
    replaced.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn is_digit_only(s: &str) -> bool {
    !s.is_empty() && s.chars().all(|c| c.is_ascii_digit())
}

fn sanitize_header_name(raw: &str) -> String {
    let preprocessed: String = raw
        .chars()
        .map(|c| if matches!(c, '[' | ']' | ',') { ' ' } else { c })
        .collect();
    sanitize_single_line(&preprocessed)
}

pub fn fitting_display_name(raw_name: &str) -> String {
    let sanitized = sanitize_single_line(raw_name);
    if sanitized.is_empty() || is_digit_only(&sanitized) {
        "Unnamed fitting".to_string()
    } else {
        sanitized
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct FittingRow {
    pub fitting_id: i64,
    pub ship_type_id: i64,
    pub display_name: String,
    pub ship_name: String,
    pub item_count: usize,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FittingItemRow {
    pub type_id: i64,
    pub type_name: String,
    pub section: FittingSection,
    pub quantity: i64,
}

pub fn fitting_rows(fittings: &[CharacterFitting], resolver: &NameResolver) -> Vec<FittingRow> {
    let mut rows: Vec<FittingRow> = fittings
        .iter()
        .map(|fitting| FittingRow {
            fitting_id: fitting.fitting_id,
            ship_type_id: fitting.ship_type_id,
            display_name: fitting_display_name(&fitting.name),
            ship_name: resolver.name(fitting.ship_type_id),
            item_count: fitting.items.len(),
        })
        .collect();
    rows.sort_by(|a, b| {
        a.display_name
            .to_lowercase()
            .cmp(&b.display_name.to_lowercase())
            .then_with(|| a.display_name.cmp(&b.display_name))
            .then_with(|| a.ship_name.to_lowercase().cmp(&b.ship_name.to_lowercase()))
            .then_with(|| a.ship_name.cmp(&b.ship_name))
            .then(a.fitting_id.cmp(&b.fitting_id))
    });
    tracing::debug!("[FITTING] fitting rows={}", rows.len());
    rows
}

pub fn fitting_item_rows(
    fitting: &CharacterFitting,
    resolver: &NameResolver,
) -> Vec<FittingItemRow> {
    let mut skipped: usize = 0;
    let mut rows: Vec<(FittingItemRow, String)> = Vec::new();
    for item in &fitting.items {
        if item.type_id <= 0 {
            skipped = skipped.saturating_add(1);
            continue;
        }
        let section = section_for_flag(&item.flag);
        let row = FittingItemRow {
            type_id: item.type_id,
            type_name: resolver.name(item.type_id),
            section,
            quantity: item.quantity.max(0),
        };
        rows.push((row, item.flag.clone()));
    }
    rows.sort_by(|(a, a_flag), (b, b_flag)| {
        section_order(a.section)
            .cmp(&section_order(b.section))
            .then_with(|| a_flag.cmp(b_flag))
            .then_with(|| a.type_name.to_lowercase().cmp(&b.type_name.to_lowercase()))
            .then_with(|| a.type_name.cmp(&b.type_name))
            .then(a.type_id.cmp(&b.type_id))
    });
    tracing::debug!(
        "[FITTING] fitting item rows fitting_id={} rows={} skipped={}",
        fitting.fitting_id,
        rows.len(),
        skipped
    );
    rows.into_iter().map(|(row, _)| row).collect()
}

fn fitting_matches_search(row: &FittingRow, needle: &str) -> bool {
    widgets::matches_search(&row.display_name, needle)
        || widgets::matches_search(&row.ship_name, needle)
}

#[derive(Debug, Clone, PartialEq)]
pub struct EftExport {
    pub text: String,
    pub skipped_unknown: usize,
    pub skipped_empty: usize,
}

struct StackedAcc {
    type_id: i64,
    name: String,
    total: i64,
    row_count: usize,
}

pub fn fitting_to_eft(fitting: &CharacterFitting, resolver: &NameResolver) -> Option<EftExport> {
    if fitting.ship_type_id <= 0 {
        return None;
    }
    let ship_raw = resolver.cached(fitting.ship_type_id)?;
    // The ship name sits inside the EFT header's bracket/comma
    // structure exactly like the fitting name, so it gets the same
    // header sanitization (brackets and commas stripped).
    let ship_sanitized = sanitize_header_name(ship_raw);
    if ship_sanitized.is_empty() || is_digit_only(&ship_sanitized) {
        return None;
    }
    let ship_name = ship_sanitized;
    let header_name_raw = sanitize_header_name(&fitting.name);
    let header_name = if header_name_raw.is_empty() || is_digit_only(&header_name_raw) {
        "Unnamed fitting".to_string()
    } else {
        header_name_raw
    };
    let header = format!("[{}, {}]", ship_name, header_name);

    let mut skipped_unknown: usize = 0;
    let mut skipped_empty: usize = 0;

    // Collect eligible wire contributions grouped by section for slot repetition.
    // For slot sections: per-row lines; for stacked: aggregated.
    // Keep raw tasks: (section, type_id, name, clamped_qty, flag)
    struct Contributor {
        section: FittingSection,
        type_id: i64,
        name: String,
        clamped: i64,
        flag: String,
    }
    let mut contributors: Vec<Contributor> = Vec::new();
    for item in &fitting.items {
        if item.type_id <= 0 {
            skipped_empty = skipped_empty.saturating_add(1);
            continue;
        }
        let Some(cached) = resolver.cached(item.type_id) else {
            skipped_unknown = skipped_unknown.saturating_add(1);
            continue;
        };
        // Item names land on lines where a comma starts a charge field
        // and brackets delimit structure, so they get header-grade
        // sanitization (controls collapsed, `[`, `]`, `,` stripped).
        let sanitized = sanitize_header_name(cached);
        if sanitized.is_empty() {
            skipped_unknown = skipped_unknown.saturating_add(1);
            continue;
        }
        let section = section_for_flag(&item.flag);
        let clamped = item.quantity.max(0);
        contributors.push(Contributor {
            section,
            type_id: item.type_id,
            name: sanitized,
            clamped,
            flag: item.flag.clone(),
        });
    }

    // Sort contributors to 9.1 row order for deterministic appearance.
    contributors.sort_by(|a, b| {
        section_order(a.section)
            .cmp(&section_order(b.section))
            .then_with(|| a.flag.cmp(&b.flag))
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
            .then_with(|| a.name.cmp(&b.name))
            .then(a.type_id.cmp(&b.type_id))
    });

    let mut section_lines: Vec<Vec<String>> = Vec::new();
    for section in SECTION_ORDER {
        let in_section: Vec<&Contributor> = contributors
            .iter()
            .filter(|c| c.section == section)
            .collect();
        if in_section.is_empty() {
            section_lines.push(Vec::new());
            continue;
        }
        let is_slot = matches!(
            section,
            FittingSection::Low
                | FittingSection::Medium
                | FittingSection::High
                | FittingSection::Rig
                | FittingSection::Subsystem
        );
        if is_slot {
            let mut lines: Vec<String> = Vec::new();
            for c in in_section {
                if c.clamped <= 0 {
                    skipped_empty = skipped_empty.saturating_add(1);
                    continue;
                }
                // Quantities decode from remote JSON unvalidated: cap
                // expansion so a hostile quantity cannot expand into
                // unbounded clipboard text. A truncated row is disclosed
                // once via skipped_empty, like other unexportable rows.
                let requested = usize::try_from(c.clamped).unwrap_or(usize::MAX);
                let repeats = requested.min(MAX_EFT_SLOT_REPEATS);
                if repeats < requested {
                    skipped_empty = skipped_empty.saturating_add(1);
                }
                for _ in 0..repeats {
                    lines.push(c.name.clone());
                }
            }
            section_lines.push(lines);
        } else {
            // stacked: aggregate by type_id
            let mut groups: Vec<StackedAcc> = Vec::new();
            let mut index_by_type: HashMap<i64, usize> = HashMap::new();
            for c in in_section {
                if let Some(&idx) = index_by_type.get(&c.type_id) {
                    let acc = &mut groups[idx];
                    acc.total = acc.total.saturating_add(c.clamped);
                    acc.row_count = acc.row_count.saturating_add(1);
                } else {
                    let idx = groups.len();
                    index_by_type.insert(c.type_id, idx);
                    groups.push(StackedAcc {
                        type_id: c.type_id,
                        name: c.name.clone(),
                        total: c.clamped,
                        row_count: 1,
                    });
                }
            }
            let mut kept: Vec<StackedAcc> = Vec::new();
            for g in groups {
                if g.total <= 0 {
                    skipped_empty = skipped_empty.saturating_add(g.row_count);
                } else {
                    kept.push(g);
                }
            }
            kept.sort_by(|a, b| {
                a.name
                    .to_lowercase()
                    .cmp(&b.name.to_lowercase())
                    .then_with(|| a.name.cmp(&b.name))
                    .then(a.type_id.cmp(&b.type_id))
            });
            let lines: Vec<String> = kept
                .iter()
                .map(|g| format!("{} x{}", g.name, g.total))
                .collect();
            section_lines.push(lines);
        }
    }

    let mut result = header;
    let mut first = true;
    for lines in section_lines {
        if lines.is_empty() {
            continue;
        }
        if first {
            result.push('\n');
            first = false;
        } else {
            result.push_str("\n\n");
        }
        result.push_str(&lines.join("\n"));
    }

    tracing::debug!(
        "[FITTING] eft built fitting_id={} skipped_unknown={} skipped_empty={} text_len={}",
        fitting.fitting_id,
        skipped_unknown,
        skipped_empty,
        result.len()
    );

    Some(EftExport {
        text: result,
        skipped_unknown,
        skipped_empty,
    })
}

#[derive(Debug, Clone, PartialEq)]
pub struct DnaExport {
    pub text: String,
    /// Units in sections DNA cannot hold (drones, fighters, cargo).
    pub skipped_unsupported: usize,
    /// Rows with no usable type id or quantity.
    pub skipped_empty: usize,
    /// Units truncated by the DNA expanded-items cap.
    pub skipped_capped: usize,
}

/// Largest expanded fitting our DNA importer accepts; DNA export
/// never emits a larger total, so its own output always re-imports.
const MAX_DNA_EXPORT_ITEMS: i64 = 4_096;

/// DNA generation order: Flutter `Fitting.allModules` is high,
/// medium, low, rig, subsystem slots; counts merge by type id in
/// first-appearance order across that traversal.
const DNA_SECTION_ORDER: [FittingSection; 5] = [
    FittingSection::High,
    FittingSection::Medium,
    FittingSection::Low,
    FittingSection::Rig,
    FittingSection::Subsystem,
];

/// Build the DNA link text for a fitting (DNA export design
/// section 3). DNA carries type numbers, so no name resolution is
/// involved and an unloaded ship name never blocks a copy; `None`
/// only for a non-positive ship type id. Items DNA cannot hold
/// are counted, never silently absent.
pub fn fitting_to_dna(fitting: &CharacterFitting) -> Option<DnaExport> {
    if fitting.ship_type_id <= 0 {
        return None;
    }
    let mut skipped_unsupported: usize = 0;
    let mut skipped_empty: usize = 0;
    // (type_id, count) in first-appearance order.
    let mut counts: Vec<(i64, i64)> = Vec::new();
    let mut index_by_type: HashMap<i64, usize> = HashMap::new();
    for section in DNA_SECTION_ORDER {
        for item in fitting
            .items
            .iter()
            .filter(|item| section_for_flag(&item.flag) == section)
        {
            if item.type_id <= 0 || item.quantity <= 0 {
                skipped_empty = skipped_empty.saturating_add(1);
                continue;
            }
            if let Some(&idx) = index_by_type.get(&item.type_id) {
                if let Some(entry) = counts.get_mut(idx) {
                    entry.1 = entry.1.saturating_add(item.quantity);
                }
            } else {
                index_by_type.insert(item.type_id, counts.len());
                counts.push((item.type_id, item.quantity));
            }
        }
    }
    for item in &fitting.items {
        let section = section_for_flag(&item.flag);
        if DNA_SECTION_ORDER.contains(&section) {
            continue;
        }
        if item.type_id <= 0 || item.quantity <= 0 {
            skipped_empty = skipped_empty.saturating_add(1);
        } else {
            skipped_unsupported =
                skipped_unsupported.saturating_add(usize::try_from(item.quantity).unwrap_or(0));
        }
    }
    // Cap the emitted total at the importer's expanded-items cap,
    // truncating counts in first-appearance order.
    let mut remaining = MAX_DNA_EXPORT_ITEMS;
    let mut skipped_capped: usize = 0;
    let mut segments: Vec<String> = Vec::new();
    for (type_id, count) in counts {
        if remaining <= 0 {
            skipped_capped = skipped_capped.saturating_add(usize::try_from(count).unwrap_or(0));
            continue;
        }
        let emitted = count.min(remaining);
        skipped_capped =
            skipped_capped.saturating_add(usize::try_from(count - emitted).unwrap_or(0));
        remaining -= emitted;
        segments.push(format!("{type_id};{emitted}"));
    }
    let mut text = format!("{}:", fitting.ship_type_id);
    for segment in &segments {
        text.push_str(segment);
        text.push(':');
    }
    text.push(':');
    tracing::debug!(
        "[FITTING] dna built fitting_id={} segments={} skipped_unsupported={} skipped_empty={} skipped_capped={}",
        fitting.fitting_id,
        segments.len(),
        skipped_unsupported,
        skipped_empty,
        skipped_capped
    );
    Some(DnaExport {
        text,
        skipped_unsupported,
        skipped_empty,
        skipped_capped,
    })
}

fn section_error_label(ui: &mut egui::Ui, error: &SectionError, panel_shown: bool) {
    if error.needs_reauthorize && panel_shown {
        ui.label("Not authorized yet. Re-authorize above to load this section.");
    } else if error.needs_reauthorize {
        ui.label("Not authorized yet for this character.");
    } else {
        ui.label(format!("Could not load fittings: {}", error.message));
    }
}

fn fittings_reauthorize_panel(ui: &mut egui::Ui, state: &mut AppState) {
    ui.heading("Fittings needs one more EVE permission.");
    ui.label(format!(
        "Saved fittings will not load for this character until this EVE SSO scope is granted: {}. Other views are unaffected.",
        EveConfig::FITTINGS_SCOPES.join(" ")
    ));
    let active_id = state.active_character_id;
    if let Some(name) = state.active_character().map(|c| c.name.clone()) {
        ui.label(format!(
            "Choose Re-authorize and Mimir opens EVE SSO in your browser for {name}, asking for the permissions already granted plus these. Sign in as {name}: approving as a different character is rejected and nothing is saved."
        ));
    }
    let enabled = !state.demo && !state.auth.is_busy() && state.active_character_id.is_some();
    if state.auth.is_busy() {
        ui.spinner();
        ui.label(state.auth.label());
    }
    if ui
        .add_enabled(enabled, egui::Button::new("Re-authorize with EVE SSO"))
        .clicked()
    {
        if let Some(active_id) = active_id {
            tracing::info!(
                "[AUTH] step-up re-authorize requested from Fittings view character_id={} scopes={}",
                active_id,
                EveConfig::FITTINGS_SCOPES.join(" ")
            );
            state.stepup_requested =
                Some(StepUpRequest::new(active_id, EveConfig::FITTINGS_SCOPES));
            state.status_message =
                "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();
        }
    }
}

/// Write step-up panel (write design section 3.2), modeled
/// line-for-line on the read panel but rendering the write
/// scope group. Driven by `fittings_write_needs_reauthorize`;
/// renders only when that flag is set for the active
/// character outside demo, ahead of the read section so it
/// stays reachable while reads await their own grant or fail.
fn fittings_write_reauthorize_panel(ui: &mut egui::Ui, state: &mut AppState) {
    if state.demo || state.active_character_id.is_none() || !state.fittings_write_needs_reauthorize
    {
        return;
    }
    ui.heading("Saving fittings needs one more EVE permission.");
    ui.label(format!(
        "Mimir cannot save or delete fittings for this character until this EVE SSO scope is granted: {}. Reading fittings and other views are unaffected.",
        EveConfig::FITTINGS_WRITE_SCOPES.join(" ")
    ));
    let active_id = state.active_character_id;
    if let Some(name) = state.active_character().map(|c| c.name.clone()) {
        ui.label(format!(
            "Choose Re-authorize and Mimir opens EVE SSO in your browser for {name}, asking for the permissions already granted plus these. Sign in as {name}: approving as a different character is rejected and nothing is saved."
        ));
    }
    let enabled = !state.demo && !state.auth.is_busy() && state.active_character_id.is_some();
    if state.auth.is_busy() {
        ui.spinner();
        ui.label(state.auth.label());
    }
    if ui
        .add_enabled(enabled, egui::Button::new("Re-authorize with EVE SSO"))
        .clicked()
    {
        if let Some(active_id) = active_id {
            tracing::info!(
                "[AUTH] step-up re-authorize requested from Fittings view character_id={} scopes={}",
                active_id,
                EveConfig::FITTINGS_WRITE_SCOPES.join(" ")
            );
            state.stepup_requested = Some(StepUpRequest::new(
                active_id,
                EveConfig::FITTINGS_WRITE_SCOPES,
            ));
            state.status_message =
                "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();
        }
    }
    ui.separator();
}

/// Demo sample EFT block (design section 8.3): real catalogue names,
/// zero issues, one empty-slot marker, one noted loaded charge. Shown
/// by the `Use sample EFT` button in demo mode only.
const DEMO_SAMPLE_EFT: &str = concat!(
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

/// Demo sample DNA link (design section 9.2): the shipped
/// sample Rifter's fitted modules with the placeholder,
/// loaded charge, drones, and cargo removed. Shown by the
/// `Use sample DNA` button in demo mode only.
const DEMO_SAMPLE_DNA: &str = "587:2048:1183;1:438;1:448;1:2889;3:31668;1::";

/// Truncate an issue line for display: the first 120 characters,
/// plus `...` when longer (design section 8.2). User text only;
/// never a type ID.
fn truncate_issue_text(text: &str) -> String {
    let mut chars = text.chars();
    let truncated: String = chars.by_ref().take(120).collect();
    if chars.next().is_some() {
        format!("{truncated}...")
    } else {
        truncated
    }
}

/// One issue row, exact template (design section 8.2, DNA
/// wording section 6.4): EFT `Line {line}: "{text}" - {reason}.`,
/// DNA `Segment {line}: "{text}" - {reason}.`
fn format_import_issue(issue: &ImportIssue, import_format: ImportFormat) -> String {
    match import_format {
        ImportFormat::Eft => format!(
            "Line {}: \"{}\" - {}.",
            issue.line,
            truncate_issue_text(&issue.text),
            issue.kind.reason()
        ),
        ImportFormat::Dna => format!(
            "Segment {}: \"{}\" - {}.",
            issue.line,
            truncate_issue_text(&issue.text),
            issue.kind.reason()
        ),
    }
}

/// Issues heading, singular/plural (design section 8.2, DNA
/// wording section 6.4).
fn import_issues_heading(issue_count: usize, import_format: ImportFormat) -> String {
    match import_format {
        ImportFormat::Eft => {
            if issue_count == 1 {
                "1 line could not be imported:".to_string()
            } else {
                format!("{issue_count} lines could not be imported:")
            }
        }
        ImportFormat::Dna => {
            if issue_count == 1 {
                "1 segment could not be imported:".to_string()
            } else {
                format!("{issue_count} segments could not be imported:")
            }
        }
    }
}

/// Overflow disclosure when more issues exist than are shown
/// (design section 8.2, DNA wording section 6.4).
fn import_issues_overflow_label(remaining: usize, import_format: ImportFormat) -> String {
    match import_format {
        ImportFormat::Eft => {
            if remaining == 1 {
                "...and 1 more line that could not be imported. Fix the lines above and import again to see the rest.".to_string()
            } else {
                format!("...and {remaining} more lines that could not be imported. Fix the lines above and import again to see the rest.")
            }
        }
        ImportFormat::Dna => {
            if remaining == 1 {
                "...and 1 more segment that could not be imported. Fix the segments above and import again to see the rest.".to_string()
            } else {
                format!("...and {remaining} more segments that could not be imported. Fix the segments above and import again to see the rest.")
            }
        }
    }
}

/// Imported-fitting summary line (design section 8.2, DNA
/// wording section 6.4): EFT says "lines", DNA says "segments".
fn imported_summary_line(fitting: &ImportedFitting) -> String {
    match fitting.format {
        ImportFormat::Eft => format!(
            "Imported \"{}\" ({}): {} items from {} lines.",
            fitting_display_name(&fitting.name),
            fitting.ship_name,
            fitting.items.len(),
            fitting.report.imported_lines
        ),
        ImportFormat::Dna => format!(
            "Imported \"{}\" ({}): {} items from {} segments.",
            fitting_display_name(&fitting.name),
            fitting.ship_name,
            fitting.items.len(),
            fitting.report.imported_lines
        ),
    }
}

/// Empty-slot-marker note, or `None` when there were none.
fn placeholder_note(placeholder_lines: usize) -> Option<String> {
    if placeholder_lines == 0 {
        None
    } else if placeholder_lines == 1 {
        Some("1 empty-slot marker ignored.".to_string())
    } else {
        Some(format!("{placeholder_lines} empty-slot markers ignored."))
    }
}

/// Loaded-charge disclosure, or `None` when there were none.
fn charges_note(charges_noted: usize) -> Option<String> {
    if charges_noted == 0 {
        None
    } else if charges_noted == 1 {
        Some("1 loaded charge is listed below the items. It is not included when you copy this fitting as EFT.".to_string())
    } else {
        Some(format!("{charges_noted} loaded charges are listed below the items. They are not included when you copy this fitting as EFT."))
    }
}

/// Copy status message for the imported fitting (design section 8.2).
/// Status line for copying an imported fitting as DNA: the
/// charges disclosure mirrors the EFT copy, and left-out items
/// (sections DNA cannot hold, empty rows, cap truncation) are
/// counted, never silent.
fn copy_imported_dna_status_message(
    display_name: &str,
    charges_noted: usize,
    left_out: usize,
) -> String {
    let mut notes: Vec<String> = Vec::new();
    if charges_noted == 1 {
        notes.push("1 loaded charge left out: DNA links do not store loaded charges".to_string());
    } else if charges_noted > 1 {
        notes.push(format!(
            "{charges_noted} loaded charges left out: DNA links do not store loaded charges"
        ));
    }
    if left_out > 0 {
        notes.push(format!(
            "{left_out} items left out: DNA links hold fitted modules only"
        ));
    }
    if notes.is_empty() {
        format!("Copied \"{display_name}\" as a DNA link")
    } else {
        format!(
            "Copied \"{display_name}\" as a DNA link ({})",
            notes.join("; ")
        )
    }
}

fn copy_imported_status_message(display_name: &str, charges_noted: usize) -> String {
    if charges_noted == 0 {
        format!("Copied \"{display_name}\" as EFT")
    } else if charges_noted == 1 {
        format!("Copied \"{display_name}\" as EFT (1 loaded charge left out: copied EFT fittings do not store loaded charges)")
    } else {
        format!("Copied \"{display_name}\" as EFT ({charges_noted} loaded charges left out: copied EFT fittings do not store loaded charges)")
    }
}

/// Maximum dropped-item lines spelled out in a save
/// confirmation; the rest collapse into one overflow line
/// (write design section 6.4).
pub const WRITE_DROPPED_RENDER_MAX: usize = 8;

/// The one demo label for write affordances (write design
/// section 10): demo performs no writes and offers none.
pub const DEMO_FIT_WRITE_LABEL: &str =
    "Demo mode uses sample data. Saving or deleting fittings in EVE is disabled.";

/// The fixed label shown in place of a write arm button when
/// the mapping cannot be saved (write design section 4.2
/// guards), or `None` when the mapping is saveable.
fn unsaveable_label(mapping: &SaveMapping) -> Option<&'static str> {
    if mapping.request.ship_type_id <= 0 || mapping.request.items.is_empty() {
        Some("This fitting cannot be saved to EVE: nothing in it fits an EVE fitting slot.")
    } else if mapping.request.items.len() > 512 {
        Some("This fitting cannot be saved to EVE: it has more items than EVE allows in one fitting (512).")
    } else {
        None
    }
}

/// Save-confirmation title (write design section 6.1 line 1).
fn save_confirmation_title(name: &str) -> String {
    format!("Save \"{name}\" to EVE?")
}

/// Save-confirmation summary for an imported fitting (section
/// 6.1 line 2). `{ship}` is the catalogue ship name, `{n}`
/// the kept-item count.
fn save_confirmation_imported(name: &str, ship: &str, kept: usize) -> String {
    format!(
        "\"{name}\" ({ship}, {kept} items) will be added to this character's in-game fitting list."
    )
}

/// Save-confirmation summary for a copy of a saved fitting
/// (section 6.2).
fn save_confirmation_copy(name: &str, ship: &str, kept: usize) -> String {
    format!("A copy of \"{name}\" ({ship}, {kept} items) will be added to this character's in-game fitting list. The original stays as it is.")
}

/// Fallback-name disclosure (section 6.1 line 3).
fn fallback_name_line() -> &'static str {
    "The fitting name was empty, so it will be saved as \"Unnamed fit\"."
}

/// Truncated-name disclosure (section 6.1 line 4).
fn truncated_name_line(char_count: usize) -> String {
    format!("EVE fitting names are limited to 50 characters. This name ({char_count} characters) will be saved in the shortened form shown above.")
}

/// Truncated-description disclosure (section 6.1 line 5).
fn description_truncated_line() -> &'static str {
    "The fitting notes are too long for EVE and will be shortened."
}

/// Loaded-charge disclosure for an imported source (section
/// 6.1 line 6).
fn charges_not_sent_line(charges_noted: usize) -> String {
    format!("{charges_noted} loaded charge(s) are shown above but are not part of a saved fitting and will not be sent to EVE.")
}

/// Delete-confirmation title (section 6.3 line 1).
fn delete_confirmation_title(name: &str) -> String {
    format!("Delete \"{name}\" from EVE?")
}

/// Delete-confirmation summary (section 6.3 line 2). The
/// irreversibility sentence is verbatim-locked.
fn delete_confirmation_summary(name: &str, ship: &str, item_count: usize) -> String {
    format!("\"{name}\" ({ship}, {item_count} items) will be deleted from this character's in-game fitting list. This cannot be undone.")
}

/// One dropped-item disclosure line (section 6.4).
fn dropped_item_line(item_name: &str, reason: DropReason) -> String {
    match reason {
        DropReason::NoEsiFlag => {
            format!("{item_name} has no EVE fitting slot and will be left out.")
        }
        DropReason::DuplicateSlot => {
            format!("{item_name} shares a fitting slot with another item and will be left out.")
        }
        DropReason::NotSaveable => format!("{item_name} cannot be saved and will be left out."),
    }
}

/// Dropped-item disclosure lines (section 6.4): named lines
/// first, at most `WRITE_DROPPED_RENDER_MAX` of them, then
/// one overflow line covering items with no resolved name
/// and any beyond the named ones. A dropped item is never
/// rendered as a numeric id.
fn dropped_disclosure_lines(
    dropped: &[DroppedFittingItem],
    resolver: &NameResolver,
) -> Vec<String> {
    let mut lines: Vec<String> = Vec::new();
    let mut overflow: usize = 0;
    for item in dropped {
        let resolved = resolver
            .cached(item.type_id)
            .filter(|name| !name.is_empty() && !is_digit_only(name));
        match resolved {
            Some(name) if lines.len() < WRITE_DROPPED_RENDER_MAX => {
                lines.push(dropped_item_line(name, item.reason));
            }
            _ => overflow = overflow.saturating_add(1),
        }
    }
    if overflow > 0 {
        lines.push(format!("{overflow} more item(s) will be left out."));
    }
    lines
}

/// Whether a write control may be armed or confirmed (write
/// design section 6). `Cancel` is always enabled and is not
/// gated by this.
fn write_enabled(state: &AppState) -> bool {
    !state.demo
        && !state.auth.is_busy()
        && state.fittings_write_in_flight.is_none()
        && state.active_character_id.is_some()
}

/// What a save confirmation block decided (write design
/// section 6): the single snapshot point is the Confirm
/// click, in whose frame the caller builds the request.
enum SaveConfirmAction {
    Confirmed,
    Cancelled,
}

/// Render one save confirmation block (sections 6.1/6.2),
/// recomputed every frame from the current mapping. Returns
/// the action only when the block was clicked; the caller
/// stamps the request and clears the armed confirmation.
fn render_save_confirm(
    ui: &mut egui::Ui,
    enabled: bool,
    mapping: &SaveMapping,
    ship_name: &str,
    copy: bool,
    charges_noted: Option<usize>,
    resolver: &NameResolver,
) -> Option<SaveConfirmAction> {
    let name = &mapping.request.name;
    ui.heading(save_confirmation_title(name));
    if copy {
        ui.label(save_confirmation_copy(
            name,
            ship_name,
            mapping.request.items.len(),
        ));
    } else {
        ui.label(save_confirmation_imported(
            name,
            ship_name,
            mapping.request.items.len(),
        ));
    }
    if mapping.name_was_fallback {
        ui.label(fallback_name_line());
    }
    if let Some(count) = mapping.name_truncated_from {
        ui.label(truncated_name_line(count));
    }
    if mapping.description_truncated {
        ui.label(description_truncated_line());
    }
    if let Some(count) = charges_noted {
        if count > 0 {
            ui.label(charges_not_sent_line(count));
        }
    }
    for line in dropped_disclosure_lines(&mapping.dropped, resolver) {
        ui.label(line);
    }
    if ui
        .add_enabled(enabled, egui::Button::new("Confirm save to EVE"))
        .clicked()
    {
        return Some(SaveConfirmAction::Confirmed);
    }
    if ui.button("Cancel").clicked() {
        return Some(SaveConfirmAction::Cancelled);
    }
    None
}

/// What a delete confirmation block decided (section 6.3).
enum DeleteConfirmAction {
    Confirmed,
    Cancelled,
}

fn render_delete_confirm(
    ui: &mut egui::Ui,
    enabled: bool,
    name: &str,
    ship_name: &str,
    item_count: usize,
) -> Option<DeleteConfirmAction> {
    ui.heading(delete_confirmation_title(name));
    ui.label(delete_confirmation_summary(name, ship_name, item_count));
    if ui
        .add_enabled(enabled, egui::Button::new("Confirm delete"))
        .clicked()
    {
        return Some(DeleteConfirmAction::Confirmed);
    }
    if ui.button("Cancel").clicked() {
        return Some(DeleteConfirmAction::Cancelled);
    }
    None
}

/// Render the in-flight spinner row for a write belonging to
/// the active character (section 6.5). Returns true when a
/// row was rendered.
fn render_write_in_flight(ui: &mut egui::Ui, state: &AppState) -> bool {
    match &state.fittings_write_in_flight {
        Some(flight) if Some(flight.character_id) == state.active_character_id => {
            ui.horizontal(|ui| {
                ui.spinner();
                ui.label(match flight.kind {
                    FittingWriteKind::Save => "Saving to EVE...",
                    FittingWriteKind::Delete => "Deleting from EVE...",
                });
            });
            true
        }
        _ => false,
    }
}

/// Whether an armed write confirmation is no longer
/// renderable (section 6): the stamped character is not
/// active, the stamped fitting is gone from the loaded list,
/// or the imported fitting (or its owner) is gone. A
/// confirmation never outlives the thing it confirms.
fn write_confirm_is_stale(state: &AppState) -> bool {
    let Some(confirm) = &state.fittings_write_confirm else {
        return false;
    };
    match confirm {
        FittingWriteConfirm::SaveImported { character_id } => {
            Some(*character_id) != state.active_character_id
                || state.fittings_import_owner != state.active_character_id
                || state.fittings_imported.is_none()
        }
        FittingWriteConfirm::SaveCopy {
            character_id,
            fitting_id,
        }
        | FittingWriteConfirm::Delete {
            character_id,
            fitting_id,
        } => {
            Some(*character_id) != state.active_character_id
                || *fitting_id <= 0
                || !matches!(&state.fittings, LoadState::Ready(bundle)
                if bundle.fittings.as_ref().is_ok_and(|list| {
                    list.iter().any(|f| f.fitting_id == *fitting_id)
                }))
        }
    }
}

/// Log and queue one confirmed save. Runs in the Confirm
/// click frame, so the displayed block is bit-for-bit what
/// is sent. Counts only, never the fitting name (design
/// section 11).
fn queue_save_request(state: &mut AppState, character_id: i64, mapping: SaveMapping) {
    tracing::info!(
        "[FITTING] save confirmed character_id={} kept={} dropped={}",
        character_id,
        mapping.request.items.len(),
        mapping.dropped.len()
    );
    state.fittings_write_requested = Some(FittingWriteRequest::Save {
        character_id,
        request: mapping.request,
    });
    state.fittings_write_confirm = None;
}

/// Item-section rendering shared by the saved fitting detail and the
/// imported fitting detail (design section 6.2). The empty-fitting
/// sentence stays at the callers. `type_icons` gates the icon path:
/// the saved caller passes `Some((state, cache))` so each rendered
/// row ensures one type icon inside the capped iterator; the
/// imported caller passes `None` and gets byte-identical text rows
/// with no icon widget and no ensure.
fn render_fitting_items(
    ui: &mut egui::Ui,
    item_rows: &[FittingItemRow],
    mut type_icons: Option<(&mut AppState, &mut PortraitImageCache)>,
) {
    for section in SECTION_ORDER {
        let in_section: Vec<&FittingItemRow> =
            item_rows.iter().filter(|r| r.section == section).collect();
        if in_section.is_empty() {
            continue;
        }
        ui.heading(section_label(section));
        let shown = in_section.len().min(FITTINGS_RENDER_MAX);
        if in_section.len() > FITTINGS_RENDER_MAX {
            ui.label(format!("Showing {shown} of {} items.", in_section.len()));
        }
        let is_slot = matches!(
            section,
            FittingSection::Low
                | FittingSection::Medium
                | FittingSection::High
                | FittingSection::Rig
                | FittingSection::Subsystem
        );
        for row in in_section.iter().take(FITTINGS_RENDER_MAX) {
            match &mut type_icons {
                Some((state, cache)) => {
                    ensure_type_icon_requested(state, row.type_id);
                    let label_text = if is_slot && row.quantity == 1 {
                        row.type_name.clone()
                    } else {
                        format!("{} x{}", row.type_name, row.quantity)
                    };
                    ui.horizontal(|ui| {
                        show_type_icon(ui, cache, state, row.type_id, TYPE_ICON_PX);
                        ui.label(label_text);
                    });
                }
                _ => {
                    if is_slot && row.quantity == 1 {
                        ui.label(&row.type_name);
                    } else {
                        ui.label(format!("{} x{}", row.type_name, row.quantity));
                    }
                }
            }
        }
    }
}

/// Fitting-editor heading (fitting-editor design section 6.2).
const FITTINGS_EDITOR_HEADING: &str = "Edit this fitting";

/// Standing editor note (design section 6.3), shown while a draft
/// is shown.
const FITTINGS_EDITOR_NOTE: &str = "Edits change only this imported fitting in Mimir. Nothing is sent to EVE unless you save below. Removing a module also removes its loaded charge. Items can be added only when Mimir's bundled data proves which slot they fit.";

/// Edited summary suffix (design section 6.3): honest parse
/// history once the draft diverges from the paste.
const FITTINGS_EDITOR_EDITED_SUFFIX: &str = " Edited since import.";

/// One imported-draft row for display, carrying the draft index so
/// the remove and quantity controls target the exact row.
#[derive(Debug, Clone, PartialEq)]
struct ImportedItemRow {
    index: usize,
    type_id: i64,
    type_name: String,
    section: FittingSection,
    quantity: i64,
    stacked: bool,
}

/// Mirror of [`ImportedFitting::to_character_fitting`] flag
/// assignment (design section 3.3), used only so the imported
/// rows sort byte-identically to `fitting_item_rows` output.
fn imported_flag_for(section: ImportSection, counters: &mut [usize; 5]) -> String {
    match section {
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
    }
}

/// Imported-draft display rows in the exact order
/// `fitting_item_rows` renders them today (section order, then
/// flag, then name, then type id), so an unedited draft renders
/// byte-identically.
fn imported_item_rows(imported: &ImportedFitting, resolver: &NameResolver) -> Vec<ImportedItemRow> {
    let mut counters = [0usize; 5];
    let mut rows: Vec<(ImportedItemRow, String)> = Vec::new();
    for (index, item) in imported.items.iter().enumerate() {
        if item.type_id <= 0 {
            continue;
        }
        let flag = imported_flag_for(item.section, &mut counters);
        let section = section_for_flag(&flag);
        let stacked = matches!(
            section,
            FittingSection::Drones | FittingSection::Fighters | FittingSection::Cargo
        );
        rows.push((
            ImportedItemRow {
                index,
                type_id: item.type_id,
                type_name: resolver.name(item.type_id),
                section,
                quantity: item.quantity.max(0),
                stacked,
            },
            flag,
        ));
    }
    rows.sort_by(|(a, a_flag), (b, b_flag)| {
        section_order(a.section)
            .cmp(&section_order(b.section))
            .then_with(|| a_flag.cmp(b_flag))
            .then_with(|| a.type_name.to_lowercase().cmp(&b.type_name.to_lowercase()))
            .then_with(|| a.type_name.cmp(&b.type_name))
            .then(a.type_id.cmp(&b.type_id))
    });
    rows.into_iter().map(|(row, _)| row).collect()
}

/// One edit intent recorded while rendering the imported rows;
/// applied to the working draft after rendering (design 8.2).
enum ImportedEditIntent {
    Remove(usize),
    SetQuantity(usize, String),
}

/// Imported-draft item rendering: the same section headings,
/// caps, and text as `render_fitting_items` through `None`, plus
/// a remove control per row and, on stacked rows only, a quantity
/// box with its set control (design sections 6.1 and 6.2). The
/// first intent of the frame wins; simultaneous clicks collapse
/// into one edit per frame.
fn render_imported_item_rows(
    ui: &mut egui::Ui,
    state: &mut AppState,
    rows: &[ImportedItemRow],
) -> Option<ImportedEditIntent> {
    let mut intent: Option<ImportedEditIntent> = None;
    for section in SECTION_ORDER {
        let in_section: Vec<&ImportedItemRow> =
            rows.iter().filter(|r| r.section == section).collect();
        if in_section.is_empty() {
            continue;
        }
        ui.heading(section_label(section));
        let shown = in_section.len().min(FITTINGS_RENDER_MAX);
        if in_section.len() > FITTINGS_RENDER_MAX {
            ui.label(format!("Showing {shown} of {} items.", in_section.len()));
        }
        let is_slot = matches!(
            section,
            FittingSection::Low
                | FittingSection::Medium
                | FittingSection::High
                | FittingSection::Rig
                | FittingSection::Subsystem
        );
        for row in in_section.iter().take(FITTINGS_RENDER_MAX) {
            let label_text = if is_slot && row.quantity == 1 {
                row.type_name.clone()
            } else {
                format!("{} x{}", row.type_name, row.quantity)
            };
            ui.horizontal(|ui| {
                ui.label(label_text);
                if row.stacked {
                    let draft = state
                        .fittings_editor_quantity
                        .entry(row.index)
                        .or_insert_with(|| row.quantity.to_string());
                    let response = ui.add(egui::TextEdit::singleline(draft).desired_width(90.0));
                    state.text_input_focused |= response.has_focus();
                    if ui.button("Set quantity").clicked() && intent.is_none() {
                        let text = state
                            .fittings_editor_quantity
                            .get(&row.index)
                            .cloned()
                            .unwrap_or_default();
                        intent = Some(ImportedEditIntent::SetQuantity(row.index, text));
                    }
                }
                if ui.button("Remove").clicked() && intent.is_none() {
                    intent = Some(ImportedEditIntent::Remove(row.index));
                }
            });
        }
    }
    intent
}

/// Summary line with the edited suffix once the draft has been
/// edited (design section 6.3); unedited drafts keep the
/// byte-identical parse-history line.
fn imported_summary_line_edited(fitting: &ImportedFitting, edited: bool) -> String {
    let mut line = imported_summary_line(fitting);
    if edited {
        line.push_str(FITTINGS_EDITOR_EDITED_SUFFIX);
    }
    line
}

/// Add-refusal template (design section 6.4): the importer's
/// fixed wording, verbatim.
fn add_refusal_message(refusal: EditRefusal) -> String {
    format!("Could not add: {}.", refusal.reason())
}

/// Quantity-refusal template (design section 6.4).
fn quantity_refusal_message(refusal: EditRefusal) -> String {
    format!("Could not set the quantity: {}.", refusal.reason())
}

/// Shared bookkeeping for every successful edit (design sections
/// 4.1 and 5.3): mark the draft edited, clear the refusal, drop
/// index-keyed quantity drafts, and disarm any armed save.
fn note_successful_edit(state: &mut AppState) {
    state.fittings_import_edited = true;
    state.fittings_editor_error = None;
    state.fittings_editor_quantity.clear();
    state.fittings_write_confirm = None;
}

/// Clear every editor field; called wherever the draft dies or is
/// replaced (design section 4.1).
fn clear_editor_state(state: &mut AppState) {
    state.fittings_editor_add_name.clear();
    state.fittings_editor_add_quantity.clear();
    state.fittings_editor_error = None;
    state.fittings_import_edited = false;
    state.fittings_editor_quantity.clear();
    state.fittings_editor_name = None;
}

/// Locked heading for the base resource block (design section 7).
const FITTINGS_RESOURCES_HEADING: &str = "Fitting resources (base values)";

/// Locked heading for the skill-applied block (fitting skill
/// resources design section 6). Chosen only for an `Available`
/// result with loaded skills; unavailable states keep the base
/// heading.
const FITTINGS_RESOURCES_APPLIED_HEADING: &str = "Fitting resources (with skill bonuses)";

/// Locked disclosure: the numbers are base values only, never
/// in-game totals (design section 4).
const FITTING_RESOURCES_DISCLOSURE: &str = "Base values from Mimir's bundled item data. Skills, implants, and bonuses from modules, rigs, subsystems, and the ship itself are not applied, so these numbers can differ from EVE.";

/// Locked applied disclosure (fitting need reductions design
/// section 8): the two skill bonuses and the five need
/// reductions are applied, the rest stays named as excluded.
const FITTING_RESOURCES_APPLIED_DISCLOSURE: &str = "Ship outputs and module needs include only the skill bonuses and reductions above, from Mimir's bundled item data and this character's trained skill levels. Implants, and bonuses and reductions from modules, rigs, subsystems, and the ship itself are not applied, so these numbers can differ from EVE.";

const FITTING_RESOURCES_NO_CATALOGUE: &str =
    "Fitting resources unavailable: Mimir's bundled item data failed to load.";
const FITTING_RESOURCES_NO_SHIP_OUTPUT: &str = "Fitting resources unavailable: Mimir's bundled item data has no ship output data for this fitting's ship.";

/// Locked heading for the ship base values block (ship base stats
/// design section 6). The "(base values)" qualifier keeps every
/// base hull number from reading as a fitted total.
const FITTINGS_SHIP_BASE_STATS_HEADING: &str = "Ship (base values)";

/// Locked disclosure: the numbers are bare-hull base values,
/// never modified by anything fitted or trained (design section
/// 6). This block's own sentence; the resources disclosure above
/// names different applied and excluded sets.
const FITTING_SHIP_BASE_STATS_DISCLOSURE: &str = "Base ship values from Mimir's bundled item data. Fitted modules, rigs, subsystems, skills, implants, and ship bonuses are not applied, so these numbers can differ from EVE.";

const FITTING_SHIP_BASE_STATS_NO_CATALOGUE: &str =
    "Ship values unavailable: Mimir's bundled item data failed to load.";
const FITTING_SHIP_BASE_STATS_NO_SHIP_DATA: &str = "Ship values unavailable: Mimir's bundled item data has no base ship data for this fitting's ship.";

/// Locked heading for the ship base resistances block (ship
/// resistances design section 6). The "(base values)" qualifier
/// keeps every base hull number from reading as a fitted total.
const FITTINGS_SHIP_RESISTANCES_HEADING: &str = "Ship resistances (base values)";

/// Locked disclosure: the numbers are the bare hull's base
/// resistances, never modified by anything fitted or trained
/// (design section 6). This block's own sentence; the ship base
/// values disclosure above names a different set.
const FITTING_SHIP_RESISTANCES_DISCLOSURE: &str = "These are the bare hull's base resistances from Mimir's bundled item data. Fitted modules, rigs, subsystems, skills, implants, and ship bonuses are not applied, so these numbers can differ from EVE.";

const FITTING_SHIP_RESISTANCES_NO_CATALOGUE: &str =
    "Ship resistances unavailable: Mimir's bundled item data failed to load.";
const FITTING_SHIP_RESISTANCES_NO_SHIP_DATA: &str = "Ship resistances unavailable: Mimir's bundled item data has no resistance data for this fitting's ship.";

/// Locked heading for the ship base effective hit points block
/// (ship base EHP design section 6). Both qualifiers are
/// load-bearing: "(base values)" keeps every base hull number
/// from reading as a fitted total, and the named omni profile
/// with its shares keeps every number from reading as
/// profile-free.
const FITTINGS_SHIP_BASE_EHP_HEADING: &str =
    "Ship effective hit points (base values, omni 25/25/25/25)";

/// Locked disclosure: the numbers are the bare hull's base
/// effective hit points against omni damage, never modified by
/// anything fitted or trained (design section 6). This block's
/// own sentence; the ship base values and resistances
/// disclosures above name different sets.
const FITTING_SHIP_BASE_EHP_DISCLOSURE: &str = "These are the bare hull's base effective hit points (EHP) from Mimir's bundled item data, against omni damage: equal quarters (25% each) of EM, thermal, kinetic, and explosive damage. Fitted modules, rigs, subsystems, skills, implants, and ship bonuses are not applied, and a different damage mix would give different numbers, so these numbers can differ from EVE.";

const FITTING_SHIP_BASE_EHP_NO_CATALOGUE: &str =
    "Ship effective hit points unavailable: Mimir's bundled item data failed to load.";
const FITTING_SHIP_BASE_EHP_NO_SHIP_DATA: &str = "Ship effective hit points unavailable: Mimir's bundled item data has no complete base hit point and resistance data for this fitting's ship.";

/// Locked heading for the ship navigation and targeting block
/// (navigation and targeting design section 6). The "(base
/// values)" qualifier keeps every base hull number from
/// reading as a fitted total.
const FITTINGS_SHIP_NAV_TARGETING_HEADING: &str = "Ship navigation and targeting (base values)";

/// Locked disclosure: the numbers are the bare hull's base
/// navigation and targeting values, never modified by
/// anything fitted or trained (design section 6). This
/// block's own sentence; the ship base values and
/// resistances disclosures above name different sets.
const FITTING_SHIP_NAV_TARGETING_DISCLOSURE: &str = "These are the bare hull's base navigation and targeting values from Mimir's bundled item data. Fitted modules, rigs, subsystems, skills, implants, and ship bonuses are not applied, so these numbers can differ from EVE.";

const FITTING_SHIP_NAV_TARGETING_NO_CATALOGUE: &str =
    "Ship navigation and targeting unavailable: Mimir's bundled item data failed to load.";
const FITTING_SHIP_NAV_TARGETING_NO_SHIP_DATA: &str = "Ship navigation and targeting unavailable: Mimir's bundled item data has no navigation or targeting data for this fitting's ship.";

/// One CPU or power grid line (design section 7): `left` with the
/// room remaining, or `over` with the positive overage. Exactly at
/// budget is `0.0 left`, in the normal colour.
fn resource_line(label: &str, budget: &ResourceBudget, unit: &str) -> String {
    let used = widgets::format_fitting_amount(budget.used, unit);
    let output = widgets::format_fitting_amount(budget.output, unit);
    if budget.is_over() {
        let over = widgets::format_fitting_amount(budget.used - budget.output, unit);
        format!("{label}: {used} of {output} used ({over} over)")
    } else {
        let remaining = widgets::format_fitting_amount(budget.remaining(), unit);
        format!("{label}: {used} of {output} used ({remaining} left)")
    }
}

/// Per-dimension excluded-module disclosure, or `None` when every
/// fitted module counted (design section 7).
fn cpu_excluded_line(excluded: usize) -> Option<String> {
    if excluded == 0 {
        None
    } else if excluded == 1 {
        Some(
            "CPU does not count 1 fitted module with no CPU data in Mimir's bundled item data."
                .to_string(),
        )
    } else {
        Some(format!("CPU does not count {excluded} fitted modules with no CPU data in Mimir's bundled item data."))
    }
}

/// Per-dimension excluded-module disclosure for power grid, or
/// `None` when every fitted module counted (design section 7).
fn power_grid_excluded_line(excluded: usize) -> Option<String> {
    if excluded == 0 {
        None
    } else if excluded == 1 {
        Some("Power grid does not count 1 fitted module with no power grid data in Mimir's bundled item data.".to_string())
    } else {
        Some(format!(
            "Power grid does not count {excluded} fitted modules with no power grid data in Mimir's bundled item data."
        ))
    }
}

/// One skill-bonus line (fitting skill resources design section 6),
/// pure like `resource_line`: `dimension` is "CPU output" or "Power
/// grid output", `skill_name` is the resolved SDE name. Levels arrive
/// clamped to `0..=5` from `resource_skill_levels`; the clamp here
/// keeps the displayed level consistent with the defensive re-clamp
/// inside `fitting_resources_with_skills`.
fn skill_line(dimension: &str, skill_name: &str, level: i32) -> String {
    let level = level.clamp(0, 5);
    if level > 0 {
        format!(
            "{dimension} includes {skill_name} level {level} (+{}%).",
            level * 5
        )
    } else {
        format!("{dimension} includes no bonus: {skill_name} is level 0.")
    }
}

/// One before-reductions base-need line (fitting need reductions
/// design section 8), pure like `resource_line`: `label` is "CPU"
/// or "Power grid", `unit` the resource unit. Always rendered in
/// the applied block so the reduced `used` in step 1 never
/// replaces a base figure silently, even when the two are equal.
fn base_need_line(label: &str, budget: &ResourceBudget, unit: &str) -> String {
    format!(
        "{label} need before skill reductions: {}.",
        widgets::format_fitting_amount(budget.base_used, unit)
    )
}

/// One need-reduction skill line (fitting need reductions design
/// section 8), pure like `skill_line`: `dimension` is "CPU need
/// of matching modules" or "Power grid need of matching modules"
/// ("matching modules" is load-bearing — the percent applies per
/// matched module, never to the whole dimension), `skill_name` is
/// the resolved SDE name, `pct_per_level` is 5 for every
/// reduction skill except Advanced Weapon Upgrades, where it is
/// 2. Levels arrive clamped to `0..=5` from
/// `resource_skill_levels`; the clamp here keeps the displayed
/// level consistent with the defensive re-clamp inside
/// `fitting_resources_with_skills`.
fn need_reduction_line(
    dimension: &str,
    skill_name: &str,
    level: i32,
    pct_per_level: i32,
) -> String {
    let level = level.clamp(0, 5);
    if level > 0 {
        format!(
            "{dimension} includes {skill_name} level {level} (-{}%).",
            level * pct_per_level
        )
    } else {
        format!("{dimension} includes no reduction: {skill_name} is level 0.")
    }
}

/// Per-dimension unreduced-module disclosure for CPU, or `None`
/// when every counted module's reduction was proven (design
/// section 8). Counted modules kept at full need because the
/// catalogue row carries no filter data to prove or disprove a
/// reduction; never renders on the shipped catalogue, so a mixed
/// reduced-plus-unprovable total can never present as fully
/// reduced.
fn cpu_unreduced_line(unreduced: usize) -> Option<String> {
    if unreduced == 0 {
        None
    } else if unreduced == 1 {
        Some(
            "CPU counts 1 fitted module at full need: Mimir's bundled item data has no skill-reduction data for them."
                .to_string(),
        )
    } else {
        Some(format!(
            "CPU counts {unreduced} fitted modules at full need: Mimir's bundled item data has no skill-reduction data for them."
        ))
    }
}

/// Per-dimension unreduced-module disclosure for power grid, or
/// `None` when every counted module's reduction was proven
/// (design section 8).
fn power_grid_unreduced_line(unreduced: usize) -> Option<String> {
    if unreduced == 0 {
        None
    } else if unreduced == 1 {
        Some(
            "Power grid counts 1 fitted module at full need: Mimir's bundled item data has no skill-reduction data for them."
                .to_string(),
        )
    } else {
        Some(format!(
            "Power grid counts {unreduced} fitted modules at full need: Mimir's bundled item data has no skill-reduction data for them."
        ))
    }
}

/// CPU and power grid block shared by the saved and imported
/// fitting details (design section 7, extended by the fitting
/// skill resources design sections 5-6 and the fitting need
/// reductions design section 8). `levels` is `Some` only when
/// the owning character's skills are loaded (`Ready`); `None`
/// renders the base block byte-identically to before. The heading
/// is chosen after the outcome is known, so the applied heading
/// never sits over an unavailable sentence. Renders even when
/// the fitting has no items. Logs nothing itself: the pure
/// function already logged counts.
fn render_fitting_resources(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
    levels: Option<ResourceSkillLevels>,
    sde: &Sde,
) {
    let Some(catalogue) = fitting_types else {
        ui.heading(FITTINGS_RESOURCES_HEADING);
        ui.label(FITTING_RESOURCES_NO_CATALOGUE);
        return;
    };
    match fitting_resources_with_skills(fitting, catalogue, levels) {
        FittingResources::ShipNoOutput => {
            ui.heading(FITTINGS_RESOURCES_HEADING);
            ui.label(FITTING_RESOURCES_NO_SHIP_OUTPUT);
        }
        FittingResources::Available { cpu, power } => match levels {
            Some(levels) => {
                ui.heading(FITTINGS_RESOURCES_APPLIED_HEADING);
                let cpu_line = resource_line("CPU", &cpu, "tf");
                if cpu.is_over() {
                    ui.colored_label(egui::Color32::LIGHT_RED, cpu_line);
                } else {
                    ui.label(cpu_line);
                }
                let power_line = resource_line("Power grid", &power, "MW");
                if power.is_over() {
                    ui.colored_label(egui::Color32::LIGHT_RED, power_line);
                } else {
                    ui.label(power_line);
                }
                ui.label(skill_line(
                    "CPU output",
                    &sde.skill_name_quiet(CPU_MANAGEMENT_SKILL_ID),
                    levels.cpu_management,
                ));
                ui.label(skill_line(
                    "Power grid output",
                    &sde.skill_name_quiet(POWER_GRID_MANAGEMENT_SKILL_ID),
                    levels.power_grid_management,
                ));
                ui.label(base_need_line("CPU", &cpu, "tf"));
                ui.label(base_need_line("Power grid", &power, "MW"));
                ui.label(need_reduction_line(
                    "CPU need of matching modules",
                    &sde.skill_name_quiet(WEAPON_UPGRADES_SKILL_ID),
                    levels.weapon_upgrades,
                    5,
                ));
                ui.label(need_reduction_line(
                    "CPU need of matching modules",
                    &sde.skill_name_quiet(ENERGY_GRID_UPGRADES_SKILL_ID),
                    levels.energy_grid_upgrades,
                    5,
                ));
                ui.label(need_reduction_line(
                    "CPU need of matching modules",
                    &sde.skill_name_quiet(ELECTRONICS_UPGRADES_SKILL_ID),
                    levels.electronics_upgrades,
                    5,
                ));
                ui.label(need_reduction_line(
                    "Power grid need of matching modules",
                    &sde.skill_name_quiet(ADVANCED_WEAPON_UPGRADES_SKILL_ID),
                    levels.advanced_weapon_upgrades,
                    2,
                ));
                ui.label(need_reduction_line(
                    "Power grid need of matching modules",
                    &sde.skill_name_quiet(SHIELD_UPGRADES_SKILL_ID),
                    levels.shield_upgrades,
                    5,
                ));
                if let Some(line) = cpu_excluded_line(cpu.excluded_modules) {
                    ui.label(line);
                }
                if let Some(line) = power_grid_excluded_line(power.excluded_modules) {
                    ui.label(line);
                }
                if let Some(line) = cpu_unreduced_line(cpu.unreduced_modules) {
                    ui.label(line);
                }
                if let Some(line) = power_grid_unreduced_line(power.unreduced_modules) {
                    ui.label(line);
                }
                ui.label(FITTING_RESOURCES_APPLIED_DISCLOSURE);
            }
            None => {
                ui.heading(FITTINGS_RESOURCES_HEADING);
                let cpu_line = resource_line("CPU", &cpu, "tf");
                if cpu.is_over() {
                    ui.colored_label(egui::Color32::LIGHT_RED, cpu_line);
                } else {
                    ui.label(cpu_line);
                }
                let power_line = resource_line("Power grid", &power, "MW");
                if power.is_over() {
                    ui.colored_label(egui::Color32::LIGHT_RED, power_line);
                } else {
                    ui.label(power_line);
                }
                if let Some(line) = cpu_excluded_line(cpu.excluded_modules) {
                    ui.label(line);
                }
                if let Some(line) = power_grid_excluded_line(power.excluded_modules) {
                    ui.label(line);
                }
                ui.label(FITTING_RESOURCES_DISCLOSURE);
            }
        },
    }
}

/// One base ship value line (design section 6), pure like
/// `resource_line`: `None` (absent or unusable data) renders no
/// line at all — never a zero, a dash, or placeholder words. A
/// present `0.0` renders like any other value.
fn ship_stat_line(label: &str, value: Option<f64>, unit: &str) -> Option<String> {
    value.map(|v| format!("{label}: {}", widgets::format_fitting_amount(v, unit)))
}

/// The block's stat lines in locked order (shield, armor, hull,
/// capacitor, velocity — the Flutter stats panel's DEFENSE →
/// CAPACITOR → NAVIGATION order). Absent stats are omitted, so a
/// partial block still renders its available values plus the
/// disclosure.
fn ship_base_stat_lines(stats: &ShipBaseStats) -> Vec<String> {
    let peaks = ship_base_peak_recharge(stats);
    [
        ship_stat_line("Shield", stats.shield_capacity, "HP"),
        ship_stat_line("Armor", stats.armor_hp, "HP"),
        ship_stat_line("Hull", stats.hull_hp, "HP"),
        ship_stat_line("Capacitor capacity", stats.capacitor_capacity, "GJ"),
        ship_stat_line("Max speed", stats.max_velocity, "m/s"),
        ship_stat_line("Shield recharge", stats.shield_recharge_secs, "s"),
        ship_stat_line("Capacitor recharge", stats.capacitor_recharge_secs, "s"),
        ship_stat_line("Shield peak recharge", peaks.shield_hp_per_sec, "HP/s"),
        ship_stat_line(
            "Capacitor peak recharge",
            peaks.capacitor_gj_per_sec,
            "GJ/s",
        ),
    ]
    .into_iter()
    .flatten()
    .collect()
}

/// Ship base values block shared by the saved and imported
/// fitting details (ship base stats design section 6). Depends
/// only on the fitting's ship and the catalogue: no skill levels,
/// no SDE handle, so it renders identically for every viewing
/// character. The heading always renders, so the view never
/// silently omits the feature; `Unavailable` swaps all stat lines
/// and the disclosure for the fixed unavailable sentence. Renders
/// even when the fitting has no items. Logs nothing itself: the
/// pure function logs nothing (render cadence).
fn render_ship_base_stats(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
) {
    let Some(catalogue) = fitting_types else {
        ui.heading(FITTINGS_SHIP_BASE_STATS_HEADING);
        ui.label(FITTING_SHIP_BASE_STATS_NO_CATALOGUE);
        return;
    };
    match ship_base_stats(fitting, catalogue) {
        ShipBaseStatsOutcome::Available(stats) => {
            ui.heading(FITTINGS_SHIP_BASE_STATS_HEADING);
            for line in ship_base_stat_lines(&stats) {
                ui.label(line);
            }
            ui.label(FITTING_SHIP_BASE_STATS_DISCLOSURE);
        }
        ShipBaseStatsOutcome::Unavailable => {
            ui.heading(FITTINGS_SHIP_BASE_STATS_HEADING);
            ui.label(FITTING_SHIP_BASE_STATS_NO_SHIP_DATA);
        }
    }
}

/// One resistance segment (design section 6), pure like
/// `ship_stat_line`: `None` (no data) contributes no segment —
/// never a zero, a dash, or placeholder words. A present `0.0`
/// renders like any other value, as does a negative percentage
/// from a resonance above 1.
fn ship_resistance_segment(label: &str, value: Option<f64>) -> Option<String> {
    value.map(|v| format!("{label} {}", widgets::format_fitting_percent(v)))
}

/// One layer line (design section 6): segments in EM, thermal,
/// kinetic, explosive order joined by `, `. A layer with no usable
/// resistance contributes no line at all.
fn ship_resistance_layer_line(layer_name: &str, layer: &ResistLayer) -> Option<String> {
    let segments: Vec<String> = [
        ship_resistance_segment("EM", layer.em),
        ship_resistance_segment("Thermal", layer.thermal),
        ship_resistance_segment("Kinetic", layer.kinetic),
        ship_resistance_segment("Explosive", layer.explosive),
    ]
    .into_iter()
    .flatten()
    .collect();
    if segments.is_empty() {
        None
    } else {
        Some(format!("{layer_name} resistances: {}", segments.join(", ")))
    }
}

/// The block's lines in locked order (shield, armor, hull —
/// section 2). Absent resistances are omitted, so a partial block
/// still renders its available values plus the disclosure.
fn ship_resistance_lines(resistances: &ShipResistances) -> Vec<String> {
    [
        ship_resistance_layer_line("Shield", &resistances.shield),
        ship_resistance_layer_line("Armor", &resistances.armor),
        ship_resistance_layer_line("Hull", &resistances.hull),
    ]
    .into_iter()
    .flatten()
    .collect()
}

/// Ship base resistances block shared by the saved and imported
/// fitting details (ship resistances design section 6). Depends
/// only on the fitting's ship and the catalogue: no skill levels,
/// no SDE handle, so it renders identically for every viewing
/// character. The heading always renders, so the view never
/// silently omits the feature; `Unavailable` swaps all lines and
/// the disclosure for the fixed unavailable sentence. Renders
/// even when the fitting has no items. Logs nothing itself: the
/// pure function logs nothing (render cadence).
fn render_ship_resistances(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
) {
    let Some(catalogue) = fitting_types else {
        ui.heading(FITTINGS_SHIP_RESISTANCES_HEADING);
        ui.label(FITTING_SHIP_RESISTANCES_NO_CATALOGUE);
        return;
    };
    match ship_resistances(fitting, catalogue) {
        ShipResistancesOutcome::Available(resistances) => {
            ui.heading(FITTINGS_SHIP_RESISTANCES_HEADING);
            for line in ship_resistance_lines(&resistances) {
                ui.label(line);
            }
            ui.label(FITTING_SHIP_RESISTANCES_DISCLOSURE);
        }
        ShipResistancesOutcome::Unavailable => {
            ui.heading(FITTINGS_SHIP_RESISTANCES_HEADING);
            ui.label(FITTING_SHIP_RESISTANCES_NO_SHIP_DATA);
        }
    }
}

/// One effective hit points line (design section 6), pure like
/// `ship_stat_line`: `None` (no computable layer) renders no
/// line at all — never a zero, a dash, or placeholder words. A
/// present `0.0` renders like any other value.
fn ship_ehp_line(label: &str, value: Option<f64>) -> Option<String> {
    value.map(|v| format!("{label} EHP: {}", widgets::format_fitting_amount(v, "HP")))
}

/// The block's lines in locked order (shield, armor, hull, then
/// total — design section 6). Non-computable layers and a
/// non-computable total are omitted, so a partial block still
/// renders its available values plus the disclosure.
fn ship_base_ehp_lines(ehp: &ShipBaseEhp) -> Vec<String> {
    [
        ship_ehp_line("Shield", ehp.shield),
        ship_ehp_line("Armor", ehp.armor),
        ship_ehp_line("Hull", ehp.hull),
        ship_ehp_line("Total", ehp.total),
    ]
    .into_iter()
    .flatten()
    .collect()
}

/// Ship base effective hit points block shared by the saved and
/// imported fitting details (ship base EHP design section 6).
/// Depends only on the fitting's ship and the catalogue: no skill
/// levels, no SDE handle, so it renders identically for every
/// viewing character. The heading always renders, so the view
/// never silently omits the feature; `Unavailable` swaps all
/// lines and the disclosure for the fixed unavailable sentence.
/// Renders even when the fitting has no items. Logs nothing
/// itself: the pure function logs nothing (render cadence).
fn render_ship_base_ehp(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
) {
    let Some(catalogue) = fitting_types else {
        ui.heading(FITTINGS_SHIP_BASE_EHP_HEADING);
        ui.label(FITTING_SHIP_BASE_EHP_NO_CATALOGUE);
        return;
    };
    match ship_base_ehp(fitting, catalogue) {
        ShipBaseEhpOutcome::Available(ehp) => {
            ui.heading(FITTINGS_SHIP_BASE_EHP_HEADING);
            for line in ship_base_ehp_lines(&ehp) {
                ui.label(line);
            }
            ui.label(FITTING_SHIP_BASE_EHP_DISCLOSURE);
        }
        ShipBaseEhpOutcome::Unavailable => {
            ui.heading(FITTINGS_SHIP_BASE_EHP_HEADING);
            ui.label(FITTING_SHIP_BASE_EHP_NO_SHIP_DATA);
        }
    }
}

/// One sensor segment (design section 6), pure like
/// `ship_resistance_segment`: `None` (no data) contributes no
/// segment — never a zero, a dash, or placeholder words. A
/// present `0.0` renders like any other value.
fn ship_sensor_segment(label: &str, value: Option<f64>) -> Option<String> {
    value.map(|v| format!("{label} {}", widgets::format_fitting_amount(v, "points")))
}

/// The joined sensor-strength line (design section 6):
/// segments in RADAR, Ladar, Magnetometric, Gravimetric
/// (attribute-id) order joined by `, `. A hull with no
/// sensor data at all contributes no line at all.
fn ship_nav_targeting_sensor_line(targeting: &ShipNavTargeting) -> Option<String> {
    let segments: Vec<String> = [
        ship_sensor_segment("RADAR", targeting.sensor_radar),
        ship_sensor_segment("Ladar", targeting.sensor_ladar),
        ship_sensor_segment("Magnetometric", targeting.sensor_magnetometric),
        ship_sensor_segment("Gravimetric", targeting.sensor_gravimetric),
    ]
    .into_iter()
    .flatten()
    .collect();
    if segments.is_empty() {
        None
    } else {
        Some(format!("Sensor strength: {}", segments.join(", ")))
    }
}

/// One integer-count line (design section 6), pure like
/// `ship_stat_line`: `None` (no data) renders no line at
/// all — never a zero, a dash, or placeholder words. A
/// present `0` renders like any other value. The count is
/// rendered with `{}`, never `format_fitting_amount` — that
/// formatter is for `f64` amounts with units (the `slot_line`
/// comment precedent).
fn ship_count_line(label: &str, value: Option<i64>) -> Option<String> {
    value.map(|v| format!("{label}: {v}"))
}

/// The block's lines in locked order (navigation group, then
/// targeting group — design section 6). Absent values are
/// omitted, so a partial block still renders its available
/// values plus the disclosure. Agility carries no line
/// (design section 2.3).
fn ship_nav_targeting_lines(targeting: &ShipNavTargeting) -> Vec<String> {
    [
        ship_stat_line("Warp speed", targeting.warp_speed, "AU/s"),
        ship_stat_line("Align time", targeting.align_time_secs, "s"),
        ship_stat_line("Mass", targeting.mass, "kg"),
        ship_stat_line("Signature radius", targeting.signature_radius, "m"),
        ship_stat_line("Targeting range", targeting.max_target_range_km, "km"),
        ship_stat_line("Scan resolution", targeting.scan_resolution, "mm"),
        ship_nav_targeting_sensor_line(targeting),
        ship_count_line("Max locked targets", targeting.max_locked_targets),
    ]
    .into_iter()
    .flatten()
    .collect()
}

/// Ship base navigation and targeting block shared by the
/// saved and imported fitting details (navigation and
/// targeting design section 6). Depends only on the
/// fitting's ship and the catalogue: no skill levels, no SDE
/// handle, so it renders identically for every viewing
/// character. The heading always renders, so the view never
/// silently omits the feature; `Unavailable` swaps all
/// lines and the disclosure for the fixed unavailable
/// sentence. Renders even when the fitting has no items.
/// Logs nothing itself: the pure function logs nothing
/// (render cadence).
fn render_ship_nav_targeting(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
) {
    let Some(catalogue) = fitting_types else {
        ui.heading(FITTINGS_SHIP_NAV_TARGETING_HEADING);
        ui.label(FITTING_SHIP_NAV_TARGETING_NO_CATALOGUE);
        return;
    };
    match ship_nav_targeting(fitting, catalogue) {
        ShipNavTargetingOutcome::Available(targeting) => {
            ui.heading(FITTINGS_SHIP_NAV_TARGETING_HEADING);
            for line in ship_nav_targeting_lines(&targeting) {
                ui.label(line);
            }
            ui.label(FITTING_SHIP_NAV_TARGETING_DISCLOSURE);
        }
        ShipNavTargetingOutcome::Unavailable => {
            ui.heading(FITTINGS_SHIP_NAV_TARGETING_HEADING);
            ui.label(FITTING_SHIP_NAV_TARGETING_NO_SHIP_DATA);
        }
    }
}

/// Locked heading for the rig calibration block (rig calibration
/// design section 6). The "(base values)" qualifier keeps every
/// base calibration number from reading as a skill- or
/// bonus-modified total.
const FITTINGS_CALIBRATION_HEADING: &str = "Rig calibration (base values)";

/// Locked disclosure: the numbers are base rig calibration costs
/// against the ship's base calibration (rig calibration design
/// section 6). This block's own sentence; it names skills,
/// implants, and module/rig/subsystem/ship bonuses, which the
/// resources disclosure does not cover in the same words.
const FITTING_CALIBRATION_DISCLOSURE: &str = "Base rig calibration costs against the ship's base calibration, from Mimir's bundled item data. Skills, implants, and bonuses from modules, rigs, subsystems, and the ship itself are not applied, so these numbers can differ from EVE.";

const FITTING_CALIBRATION_NO_CATALOGUE: &str =
    "Rig calibration unavailable: Mimir's bundled item data failed to load.";
const FITTING_CALIBRATION_NO_SHIP_DATA: &str = "Rig calibration unavailable: Mimir's bundled item data has no calibration data for this fitting's ship.";

/// One rig calibration line (rig calibration design section
/// 6.2): `left` with the room remaining, or `over` with the
/// positive overage. Exactly at capacity is `0.0 left`, in the
/// normal colour. Pure like `resource_line`.
fn calibration_line(budget: &CalibrationBudget) -> String {
    let used = widgets::format_fitting_amount(budget.used, "points");
    let capacity = widgets::format_fitting_amount(budget.capacity, "points");
    if budget.is_over() {
        let over = widgets::format_fitting_amount(budget.used - budget.capacity, "points");
        format!("Calibration: {used} of {capacity} used ({over} over)")
    } else {
        let remaining = widgets::format_fitting_amount(budget.remaining(), "points");
        format!("Calibration: {used} of {capacity} used ({remaining} left)")
    }
}

/// Per-block excluded-rig disclosure, or `None` when every
/// fitted rig counted (rig calibration design section 6.2): 0
/// (none), 1 (singular), 2+ (plural). "Fitted rig" is used
/// because counting is driven by the `RigSlot` flag prefix, the
/// item list's `Rigs` section.
fn calibration_excluded_line(excluded: usize) -> Option<String> {
    if excluded == 0 {
        None
    } else if excluded == 1 {
        Some(
            "Calibration does not count 1 fitted rig with no calibration cost data in Mimir's bundled item data."
                .to_string(),
        )
    } else {
        Some(format!(
            "Calibration does not count {excluded} fitted rigs with no calibration cost data in Mimir's bundled item data."
        ))
    }
}

/// Rig calibration block shared by the saved and imported
/// fitting details (rig calibration design section 6). Depends
/// only on the fitting and the catalogue: no skill levels, no
/// SDE handle, so it renders identically for every viewing
/// character. The heading always renders, so the view never
/// silently omits the feature; `Unavailable` swaps the line,
/// the excluded disclosure, and the base disclosure for the
/// fixed unavailable sentence. Renders even when the fitting
/// has no items. Logs nothing itself: the pure function logs
/// nothing (render cadence).
fn render_rig_calibration(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
) {
    let Some(catalogue) = fitting_types else {
        ui.heading(FITTINGS_CALIBRATION_HEADING);
        ui.label(FITTING_CALIBRATION_NO_CATALOGUE);
        return;
    };
    match rig_calibration(fitting, catalogue) {
        CalibrationOutcome::Available(budget) => {
            ui.heading(FITTINGS_CALIBRATION_HEADING);
            let line = calibration_line(&budget);
            if budget.is_over() {
                ui.colored_label(egui::Color32::LIGHT_RED, line);
            } else {
                ui.label(line);
            }
            if let Some(line) = calibration_excluded_line(budget.excluded_rigs) {
                ui.label(line);
            }
            ui.label(FITTING_CALIBRATION_DISCLOSURE);
        }
        CalibrationOutcome::Unavailable => {
            ui.heading(FITTINGS_CALIBRATION_HEADING);
            ui.label(FITTING_CALIBRATION_NO_SHIP_DATA);
        }
    }
}

/// Locked heading for the bay usage block (bay capacities design
/// section 6). The "(base values)" qualifier keeps every base
/// capacity from reading as a skill- or module-modified total.
const FITTINGS_BAYS_HEADING: &str = "Bays (base values)";

/// Locked disclosure: the numbers are base capacities with plain
/// item volumes (bay capacities design section 6). This block's
/// own sentence; it names capacity bonuses and specialized holds,
/// which the bare-hull ship disclosures above do not cover.
const FITTING_BAYS_DISCLOSURE: &str = "Base bay capacities and plain item volumes from Mimir's bundled item data. Capacity bonuses from skills, modules (such as cargo expanders), rigs, subsystems, implants, and the ship itself are not applied, and specialized holds are not counted, so these numbers can differ from EVE.";

const FITTING_BAYS_NO_CATALOGUE: &str =
    "Bay usage unavailable: Mimir's bundled item data failed to load.";
const FITTING_BAYS_NO_SHIP_DATA: &str = "Bay usage unavailable: Mimir's bundled item data has no bay capacity data for this fitting's ship.";

/// One bay line (bay capacities design section 6): `left` with
/// the room remaining, or `over` with the positive overage.
/// Exactly at capacity is `0.0 left`, in the normal colour.
/// Pure like `resource_line`.
fn bay_line(label: &str, budget: &BayBudget, unit: &str) -> String {
    let used = widgets::format_fitting_amount(budget.used, unit);
    let capacity = widgets::format_fitting_amount(budget.capacity, unit);
    if budget.is_over() {
        let over = widgets::format_fitting_amount(budget.used - budget.capacity, unit);
        format!("{label}: {used} of {capacity} used ({over} over)")
    } else {
        let remaining = widgets::format_fitting_amount(budget.remaining(), unit);
        format!("{label}: {used} of {capacity} used ({remaining} left)")
    }
}

/// Per-dimension excluded-item disclosure, or `None` when every
/// counted item contributed (bay capacities design section 6):
/// 0 (none), 1 (singular), 2+ (plural). `label` is one of the
/// four bay labels; "item/items" is used uniformly because
/// counting is flag-driven. `data_noun` is "volume" for the
/// three volume bays and "bandwidth" for drone bandwidth.
fn bay_excluded_line(label: &str, excluded: usize, data_noun: &str) -> Option<String> {
    if excluded == 0 {
        None
    } else if excluded == 1 {
        Some(format!(
            "{label} does not count 1 item with no {data_noun} data in Mimir's bundled item data."
        ))
    } else {
        Some(format!(
            "{label} does not count {excluded} items with no {data_noun} data in Mimir's bundled item data."
        ))
    }
}

/// The block's lines in locked order (cargo bay, drone bay,
/// drone bandwidth, fighter bay — bay capacities design section
/// 6.2), each with whether it renders in the over-capacity red
/// (design section 2.5 rule 4: every bay line carries the
/// over colour, not only the fighter bay). A `None` bay
/// contributes no line. Excluded-item lines follow the bay
/// lines in the same dimension order, only for the bays whose
/// count is positive; they are never over-capacity lines.
fn bay_usage_lines(usage: &BayUsage) -> Vec<(String, bool)> {
    let bays: [(&str, Option<BayBudget>, &str); 4] = [
        ("Cargo bay", usage.cargo, "m3"),
        ("Drone bay", usage.drone, "m3"),
        ("Drone bandwidth", usage.drone_bandwidth, "Mbit/sec"),
        ("Fighter bay", usage.fighter, "m3"),
    ];
    let mut lines: Vec<(String, bool)> = bays
        .iter()
        .filter_map(|(label, budget, unit)| {
            budget.map(|b| (bay_line(label, &b, unit), b.is_over()))
        })
        .collect();
    let excluded: [(&str, Option<BayBudget>, &str); 4] = [
        ("Cargo bay", usage.cargo, "volume"),
        ("Drone bay", usage.drone, "volume"),
        ("Drone bandwidth", usage.drone_bandwidth, "bandwidth"),
        ("Fighter bay", usage.fighter, "volume"),
    ];
    for (label, budget, data_noun) in excluded {
        if let Some(budget) = budget {
            if let Some(line) = bay_excluded_line(label, budget.excluded_items, data_noun) {
                lines.push((line, false));
            }
        }
    }
    lines
}

/// Bay usage block shared by the saved and imported fitting
/// details (bay capacities design section 6). Depends only on
/// the fitting and the catalogue: no skill levels, no SDE
/// handle, so it renders identically for every viewing
/// character. The heading always renders, so the view never
/// silently omits the feature; `Unavailable` swaps all bay
/// lines and the disclosure for the fixed unavailable
/// sentence. Renders even when the fitting has no items.
/// Logs nothing itself: the pure function logs nothing (render
/// cadence).
fn render_bay_usage(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
) {
    let Some(catalogue) = fitting_types else {
        ui.heading(FITTINGS_BAYS_HEADING);
        ui.label(FITTING_BAYS_NO_CATALOGUE);
        return;
    };
    match bay_usage(fitting, catalogue) {
        BayUsageOutcome::Available(usage) => {
            ui.heading(FITTINGS_BAYS_HEADING);
            for (line, is_over) in bay_usage_lines(&usage) {
                if is_over {
                    ui.colored_label(egui::Color32::LIGHT_RED, line);
                } else {
                    ui.label(line);
                }
            }
            ui.label(FITTING_BAYS_DISCLOSURE);
        }
        BayUsageOutcome::Unavailable => {
            ui.heading(FITTINGS_BAYS_HEADING);
            ui.label(FITTING_BAYS_NO_SHIP_DATA);
        }
    }
}

/// Locked heading for the damage-per-second block (fitting DPS
/// design section 6). The "(base values)" qualifier keeps every
/// base damage rate from reading as a skill- or bonus-modified
/// total.
const FITTINGS_DPS_HEADING: &str = "Damage per second (base values)";

/// Locked disclosure: base damage rates with every included
/// and excluded factor named, and the no-combined-DPS-total
/// rule stated plainly (fitting DPS design section 6, as
/// extended by volley-ranges design section 6.2). This block's
/// own sentence; it names the EFT charge-pairing surface, the
/// online/launched assumptions, and every unapplied term,
/// which the bay and calibration disclosures above do not
/// cover in the same words.
const FITTING_DPS_DISCLOSURE: &str = "Base damage per second from Mimir's bundled item data: base charge, drone, and fighter damage per firing cycle, with no skill, implant, ship, module, rig, or subsystem bonuses applied. Turret and launcher damage counts only a loaded charge listed after the module in imported EFT text, exactly as listed; saved and DNA fittings list no loaded charges, and no charge is assumed. Volley is the turret and launcher damage in one firing cycle from those same listed charges; drone and fighter damage is not in the volley. Turret optimal and falloff ranges are averages of the fitted turrets' base ranges, weighted by each turret's share of the turret volley, and each is shown only when every counted turret has that range in the bundled data. Fitted weapons are treated as online, drones and fighters as launched up to the ship's base drone bandwidth and fighter tubes, and every shot is counted at full damage, with no tracking, missile application, reload time, or flight time applied. No combined damage-per-second total is shown, because any family's damage can be unknown while another's is counted.";

const FITTING_DPS_NO_CATALOGUE: &str =
    "Damage per second unavailable: Mimir's bundled item data failed to load.";
const FITTING_DPS_NO_SHIP_DATA: &str = "Damage per second unavailable: Mimir's bundled item data has no damage data for this fitting's ship.";

fn dps_family_line(label: &str, family: &FamilyDps) -> String {
    let amount = widgets::format_fitting_amount(family.dps, "DPS");
    format!("{label} DPS: {amount}")
}

fn dps_volley_line(volley: Option<f64>) -> Option<String> {
    volley.map(|value| {
        let amount = widgets::format_fitting_amount(value, "damage");
        format!("Volley: {amount}")
    })
}

fn dps_optimal_range_line(optimal_range: Option<f64>) -> Option<String> {
    optimal_range.map(|value| {
        let amount = widgets::format_fitting_amount(value / 1000.0, "km");
        format!("Turret optimal range: {amount}")
    })
}

fn dps_falloff_range_line(falloff_range: Option<f64>) -> Option<String> {
    falloff_range.map(|value| {
        let amount = widgets::format_fitting_amount(value / 1000.0, "km");
        format!("Turret falloff range: {amount}")
    })
}

fn dps_excluded_line(label: &str, excluded: usize) -> Option<String> {
    if excluded == 0 {
        None
    } else if excluded == 1 {
        Some(format!(
            "{label} DPS does not count 1 item with no damage data in Mimir's bundled item data."
        ))
    } else {
        Some(format!(
            "{label} DPS does not count {excluded} items with no damage data in Mimir's bundled item data."
        ))
    }
}

fn dps_unloaded_line(unloaded: usize) -> Option<String> {
    if unloaded == 0 {
        None
    } else if unloaded == 1 {
        Some("1 fitted weapon has no loaded charge listed, so it is not counted above.".to_string())
    } else {
        Some(format!(
            "{unloaded} fitted weapons have no loaded charge listed, so they are not counted above."
        ))
    }
}

/// The block's lines in locked order (turret, launcher,
/// drones, fighters, volley, turret optimal range, turret
/// falloff range — fitting DPS design section 6, as
/// extended by volley-ranges design section 6). A `None`
/// family, volley, or range contributes no line; each range
/// is independently conditional on its own field. Excluded-item
/// lines follow in the same family order, only for
/// families whose count is positive; the unloaded-weapons
/// line comes last. No line ever renders in the
/// over-capacity red.
fn dps_lines(dps: &FittingDps) -> Vec<String> {
    let families: [(&str, Option<FamilyDps>); 4] = [
        ("Turret", dps.turrets),
        ("Launcher", dps.launchers),
        ("Drone", dps.drones),
        ("Fighter", dps.fighters),
    ];
    let mut lines: Vec<String> = families
        .iter()
        .filter_map(|(label, family)| family.map(|f| dps_family_line(label, &f)))
        .collect();
    if let Some(line) = dps_volley_line(dps.volley) {
        lines.push(line);
    }
    if let Some(line) = dps_optimal_range_line(dps.optimal_range) {
        lines.push(line);
    }
    if let Some(line) = dps_falloff_range_line(dps.falloff_range) {
        lines.push(line);
    }
    for (label, family) in families {
        if let Some(family) = family {
            if let Some(line) = dps_excluded_line(label, family.excluded_items) {
                lines.push(line);
            }
        }
    }
    if let Some(line) = dps_unloaded_line(dps.unloaded_weapons) {
        lines.push(line);
    }
    lines
}

/// Damage-per-second block shared by the saved and imported
/// fitting details (fitting DPS design section 6). Depends
/// only on the fitting, the imported fitting, and the
/// catalogue: no skill levels, no SDE handle, so it renders
/// identically for every viewing character. The saved site
/// passes `None` for the imported argument; the imported
/// site passes the `ImportedFitting` it already holds
/// alongside its synthesis (the synthesis itself is
/// unchanged and still charge-free). The heading always
/// renders, so the view never silently omits the feature;
/// `Unavailable` swaps all DPS lines and the disclosure
/// for the fixed unavailable sentence. Renders even when
/// the fitting has no items. Logs nothing itself: the pure
/// function logs nothing (render cadence).
fn render_fitting_dps(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    imported: Option<&ImportedFitting>,
    fitting_types: Option<&FittingTypes>,
) {
    let Some(catalogue) = fitting_types else {
        ui.heading(FITTINGS_DPS_HEADING);
        ui.label(FITTING_DPS_NO_CATALOGUE);
        return;
    };
    match fitting_dps(fitting, imported, catalogue) {
        FittingDpsOutcome::Available(dps) => {
            ui.heading(FITTINGS_DPS_HEADING);
            for line in dps_lines(&dps) {
                ui.label(line);
            }
            ui.label(FITTING_DPS_DISCLOSURE);
        }
        FittingDpsOutcome::Unavailable => {
            ui.heading(FITTINGS_DPS_HEADING);
            ui.label(FITTING_DPS_NO_SHIP_DATA);
        }
    }
}

/// Locked heading for the capacitor stability block
/// (capacitor stability design section 6). The "(base values)"
/// qualifier keeps every base capacitor number from reading
/// as a skill- or bonus-modified total.
const FITTINGS_CAP_STABILITY_HEADING: &str = "Capacitor (base values)";

/// Locked disclosure: the continuous-cycling assumption is
/// stated here, never implied, and every unmodelled term is
/// named (capacitor stability design section 6). This block's
/// own sentence; the ship base values disclosure names a
/// different applied and excluded set.
const FITTING_CAP_STABILITY_DISCLOSURE: &str = "Assumes every counted module keeps cycling continuously. Base values from Mimir's bundled item data. Fitted modules, rigs, subsystems, skills, implants, and ship bonuses are not applied to the capacitor, recharge, or module use. Capacitor boosters and effects on other ships (such as energy neutralizers and remote repairers) are not modelled, so these numbers can differ from EVE.";

const FITTING_CAP_STABILITY_NO_CATALOGUE: &str =
    "Capacitor unavailable: Mimir's bundled item data failed to load.";
const FITTING_CAP_STABILITY_NO_SHIP_DATA: &str =
    "No capacitor data is available for this ship in Mimir's bundled item data.";

fn cap_stability_use_line(total_use_per_sec: Option<f64>) -> Option<String> {
    ship_stat_line("Module capacitor use", total_use_per_sec, "GJ/s")
}

fn cap_stability_peak_line(peak_recharge_per_sec: Option<f64>) -> Option<String> {
    ship_stat_line("Capacitor peak recharge", peak_recharge_per_sec, "GJ/s")
}

/// Human-readable form of one stability outcome (design section
/// 6): `Stable at {percent}%` or `Depletes in about
/// {seconds}s` with both figures rounded to whole numbers via
/// `f64::round`. The "about" wording is locked: the seconds
/// figure is the failing activation's event time, never an
/// interpolated empty-instant. Returns `None` for
/// `Unavailable`, whose fixed sentence the renderer prints
/// instead.
fn cap_stability_outcome_line(outcome: &CapStabilityOutcome) -> Option<String> {
    match *outcome {
        CapStabilityOutcome::Stable { percent } => {
            Some(format!("Stable at {}%", percent.round() as i64))
        }
        CapStabilityOutcome::Depletes { seconds } => {
            Some(format!("Depletes in about {}s", seconds.round() as i64))
        }
        CapStabilityOutcome::Unavailable => None,
    }
}

/// Per-block excluded-module disclosure, or `None` when every
/// fitted slot module counted (design section 6): 0 (none),
/// 1 (singular), 2+ (plural). "Fitted module" is used because
/// counting is driven by the slot flags, one quantity unit
/// each.
fn cap_stability_excluded_line(excluded: u64) -> Option<String> {
    if excluded == 0 {
        None
    } else if excluded == 1 {
        Some(
            "1 fitted module is not counted because its base capacitor use is not in Mimir's bundled item data."
                .to_string(),
        )
    } else {
        Some(format!(
            "{excluded} fitted modules are not counted because their base capacitor use is not in Mimir's bundled item data."
        ))
    }
}

/// The block's lines in locked order (module capacitor use,
/// capacitor peak recharge, outcome, excluded-module
/// disclosure — design section 6). A `None` use or peak
/// contributes no line — never a zero, a dash, or placeholder
/// words. For `Unavailable` this returns empty; the
/// renderer's fixed unavailable sentence is the whole block
/// in that case.
fn cap_stability_lines(stability: &FittingCapStability) -> Vec<String> {
    if let CapStabilityOutcome::Unavailable = stability.outcome {
        return Vec::new();
    }
    let mut lines: Vec<String> = [
        cap_stability_use_line(stability.total_use_per_sec),
        cap_stability_peak_line(stability.peak_recharge_per_sec),
        cap_stability_outcome_line(&stability.outcome),
    ]
    .into_iter()
    .flatten()
    .collect();
    if let Some(line) = cap_stability_excluded_line(stability.excluded_modules) {
        lines.push(line);
    }
    lines
}

/// Capacitor stability block shared by the saved and imported
/// fitting details (capacitor stability design section 6).
/// Depends only on the fitting and the catalogue: no skill
/// levels, no SDE handle, so it renders identically for every
/// viewing character. The saved site passes the fitting; the
/// imported site passes its synthesized `CharacterFitting`.
/// The heading always renders, so the view never silently
/// omits the feature; `Unavailable` swaps all lines and the
/// disclosure for the fixed unavailable sentence. Renders
/// even when the fitting has no items. Logs nothing itself:
/// the pure function logs nothing (render cadence).
fn render_fitting_cap_stability(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
) {
    let Some(catalogue) = fitting_types else {
        ui.heading(FITTINGS_CAP_STABILITY_HEADING);
        ui.label(FITTING_CAP_STABILITY_NO_CATALOGUE);
        return;
    };
    let stability = fitting_cap_stability(fitting, catalogue);
    match stability.outcome {
        CapStabilityOutcome::Unavailable => {
            ui.heading(FITTINGS_CAP_STABILITY_HEADING);
            ui.label(FITTING_CAP_STABILITY_NO_SHIP_DATA);
        }
        CapStabilityOutcome::Stable { .. } | CapStabilityOutcome::Depletes { .. } => {
            ui.heading(FITTINGS_CAP_STABILITY_HEADING);
            for line in cap_stability_lines(&stability) {
                ui.label(line);
            }
            ui.label(FITTING_CAP_STABILITY_DISCLOSURE);
        }
    }
}

/// Locked heading for the active repair block
/// (sustained tank design section 6). The "(base values)"
/// qualifier keeps every base repair number from reading
/// as a skill- or bonus-modified total. "Sustained tank"
/// and "Tank" were rejected headings: both promise the
/// resistance-applied, capacitor-checked steady-state
/// figure this block does not compute.
const FITTINGS_ACTIVE_REPAIR_HEADING: &str = "Active repair (base values)";

/// Locked disclosure: the continuous-cycling assumption is
/// stated here, never implied, and every unmodelled term is
/// named (sustained tank design section 6). This block's
/// own sentence; the ship base values disclosure names a
/// different applied and excluded set.
const FITTING_ACTIVE_REPAIR_DISCLOSURE: &str = "Assumes every counted repair module keeps cycling continuously. Base values from Mimir's bundled item data: base hit points restored per cycle at base cycle times, with resistances, skills, implants, and bonuses from modules, rigs, subsystems, and the ship itself not applied — raw hit points per second, not effective hit points per second. Ancillary repair modules are counted at their unloaded repair amount: loaded charges (such as Nanite Repair Paste) and reload time are not modelled, so an ancillary module's rate is its rate while cycling, not a long-run average. Remote repairers, which repair other ships, are not counted. Repair modules' capacitor use is counted in the Capacitor block above; this block does not model whether the capacitor can sustain continuous cycling. Passive shield recharge is shown as shield peak recharge in the Ship block and is not included here, so these numbers can differ from EVE.";

const FITTING_ACTIVE_REPAIR_NO_CATALOGUE: &str =
    "Active repair unavailable: Mimir's bundled item data failed to load.";

fn active_repair_shield_line(shield_hp_per_sec: Option<f64>) -> Option<String> {
    ship_stat_line("Shield boost", shield_hp_per_sec, "HP/s")
}

fn active_repair_armor_line(armor_hp_per_sec: Option<f64>) -> Option<String> {
    ship_stat_line("Armor repair", armor_hp_per_sec, "HP/s")
}

fn active_repair_hull_line(hull_hp_per_sec: Option<f64>) -> Option<String> {
    ship_stat_line("Hull repair", hull_hp_per_sec, "HP/s")
}

/// Per-block excluded-module disclosure, or `None` when every
/// fitted slot module counted (design section 6): 0 (none),
/// 1 (singular), 2+ (plural). "Fitted module" is used because
/// counting is driven by the slot flags, one quantity unit
/// each.
fn active_repair_excluded_line(excluded: u64) -> Option<String> {
    if excluded == 0 {
        None
    } else if excluded == 1 {
        Some(
            "1 fitted module is not counted because its base repair data is not in Mimir's bundled item data."
                .to_string(),
        )
    } else {
        Some(format!(
            "{excluded} fitted modules are not counted because their base repair data is not in Mimir's bundled item data."
        ))
    }
}

/// The block's lines in locked order (shield boost, armor
/// repair, hull repair, excluded-module disclosure —
/// design section 6). A `None` layer contributes no line —
/// never a zero, a dash, or placeholder words. Present
/// zeros render like any other value, so an empty fitting
/// still shows three `0.0 HP/s` lines.
fn active_repair_lines(repair: &FittingActiveRepair) -> Vec<String> {
    let mut lines: Vec<String> = [
        active_repair_shield_line(repair.shield_hp_per_sec),
        active_repair_armor_line(repair.armor_hp_per_sec),
        active_repair_hull_line(repair.hull_hp_per_sec),
    ]
    .into_iter()
    .flatten()
    .collect();
    if let Some(line) = active_repair_excluded_line(repair.excluded_modules) {
        lines.push(line);
    }
    lines
}

/// Active repair block shared by the saved and imported
/// fitting details (sustained tank design section 6).
/// Depends only on the fitting and the catalogue: no skill
/// levels, no SDE handle, so it renders identically for every
/// viewing character. The saved site passes the fitting; the
/// imported site passes its synthesized `CharacterFitting`.
/// The heading always renders, so the view never silently
/// omits the feature; a catalogue that failed to load swaps
/// all lines and the disclosure for the fixed unavailable
/// sentence. Renders even when the fitting has no items.
/// Logs nothing itself: the pure function logs nothing
/// (render cadence).
fn render_fitting_active_repair(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
) {
    let Some(catalogue) = fitting_types else {
        ui.heading(FITTINGS_ACTIVE_REPAIR_HEADING);
        ui.label(FITTING_ACTIVE_REPAIR_NO_CATALOGUE);
        return;
    };
    let repair = fitting_active_repair(fitting, catalogue);
    ui.heading(FITTINGS_ACTIVE_REPAIR_HEADING);
    for line in active_repair_lines(&repair) {
        ui.label(line);
    }
    ui.label(FITTING_ACTIVE_REPAIR_DISCLOSURE);
}

/// Locked heading for the slot layout block (slot layout design
/// section 6). The "(base values)" qualifier keeps every base
/// hull number from reading as a fitted total.
const FITTINGS_SLOT_LAYOUT_HEADING: &str = "Slot layout (base values)";

/// Locked disclosure: the numbers are base slot and hardpoint
/// counts with subsystem-granted slots unapplied (slot layout
/// design section 6.2). This block's own sentence; it names
/// subsystem-granted slots plus skills, implants, and bonuses,
/// which the bay and calibration disclosures above do not cover
/// in the same words.
const FITTING_SLOT_LAYOUT_DISCLOSURE: &str = "Base slot and hardpoint counts from Mimir's bundled item data. Slots and hardpoints granted by fitted subsystems are not applied, and no skill, implant, module, rig, or ship bonuses are applied, so these numbers can differ from EVE.";

/// Locked tech-3 note (slot layout design section 6.2): the
/// five subsystem-dependent dimensions are suppressed on a
/// subsystem-defined hull, so the block names why those lines
/// are missing instead of showing them against bare-hull zeros.
const FITTING_SLOT_LAYOUT_TECH3_NOTE: &str = "This ship's high, medium, and low slots and its turret and launcher hardpoints are set by its fitted subsystems, which are not applied here, so those lines are not shown.";

const FITTING_SLOT_LAYOUT_NO_CATALOGUE: &str =
    "Slot layout unavailable: Mimir's bundled item data failed to load.";
const FITTING_SLOT_LAYOUT_NO_SHIP_DATA: &str = "Slot layout unavailable: Mimir's bundled item data has no slot layout data for this fitting's ship.";

#[cfg(test)]
fn slot_budget(used: usize, capacity: usize) -> SlotBudget {
    SlotBudget {
        used,
        capacity,
        excluded_modules: 0,
    }
}

/// One slot or hardpoint line (slot layout design section
/// 6.2): `left` with the room remaining, or `over` with the
/// positive overage. Exactly at capacity is `0 left`, in the
/// normal colour. Counts are integers rendered with `{}`
/// (`usize`/`i64` display), never `format_fitting_amount` —
/// that formatter is for `f64` amounts with units. Pure like
/// `bay_line`.
fn slot_line(label: &str, budget: &SlotBudget) -> String {
    if budget.is_over() {
        let over = budget.used - budget.capacity;
        format!(
            "{label}: {} of {} used ({over} over)",
            budget.used, budget.capacity
        )
    } else {
        let remaining = budget.remaining();
        format!(
            "{label}: {} of {} used ({remaining} left)",
            budget.used, budget.capacity
        )
    }
}

/// Per-hardpoint-dimension excluded-module disclosure, or
/// `None` when every fitted module counted (slot layout
/// design section 6.2): 0 (none), 1 (singular), 2+ (plural).
/// `label` is one of the two hardpoint labels. "Missing from"
/// is locked over the twins' "with no … data" wording because
/// the only exclusion is a module with no catalogue row at
/// all; a catalogued module without a marker is known to
/// consume no hardpoint. Slot dimensions render no excluded
/// line ever.
fn hardpoint_excluded_line(label: &str, excluded: usize) -> Option<String> {
    if excluded == 0 {
        None
    } else if excluded == 1 {
        Some(format!(
            "{label} does not count 1 fitted module missing from Mimir's bundled item data."
        ))
    } else {
        Some(format!(
            "{label} does not count {excluded} fitted modules missing from Mimir's bundled item data."
        ))
    }
}

/// The block's lines in locked order (Low, Medium, High, Rigs,
/// Subsystems, Turret hardpoints, Launcher hardpoints — slot
/// layout design section 6.2), each with whether it renders
/// in the over-capacity red (every over line carries the over
/// colour, all seven labels). A `None` dimension contributes
/// no line. Excluded-module lines follow the dimension lines
/// in the same dimension order, hardpoint dimensions only;
/// they are never over-capacity lines. The tech-3 sentence is
/// not part of this vec (it is keyed on `subsystem_layout`,
/// not on a budget) and is rendered by `render_slot_layout`
/// between the lines and the disclosure.
fn slot_layout_lines(layout: &SlotLayout) -> Vec<(String, bool)> {
    let dimensions: [(&str, Option<SlotBudget>); 7] = [
        (section_label(FittingSection::Low), layout.low),
        (section_label(FittingSection::Medium), layout.medium),
        (section_label(FittingSection::High), layout.high),
        (section_label(FittingSection::Rig), layout.rig),
        (section_label(FittingSection::Subsystem), layout.subsystem),
        ("Turret hardpoints", layout.turret),
        ("Launcher hardpoints", layout.launcher),
    ];
    let mut lines: Vec<(String, bool)> = dimensions
        .iter()
        .filter_map(|(label, budget)| budget.map(|b| (slot_line(label, &b), b.is_over())))
        .collect();
    let excluded: [(&str, Option<SlotBudget>); 2] = [
        ("Turret hardpoints", layout.turret),
        ("Launcher hardpoints", layout.launcher),
    ];
    for (label, budget) in excluded {
        if let Some(budget) = budget {
            if let Some(line) = hardpoint_excluded_line(label, budget.excluded_modules) {
                lines.push((line, false));
            }
        }
    }
    lines
}

/// Slot layout block shared by the saved and imported
/// fitting details (slot layout design section 6). Depends
/// only on the fitting and the catalogue: no skill levels,
/// no SDE handle, so it renders identically for every
/// viewing character. The heading always renders, so the
/// view never silently omits the feature; `Unavailable`
/// swaps all lines, the tech-3 note, and the disclosure
/// for the fixed unavailable sentence. Renders even when
/// the fitting has no items. Logs nothing itself: the pure
/// function logs nothing (render cadence).
fn render_slot_layout(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
) {
    let Some(catalogue) = fitting_types else {
        ui.heading(FITTINGS_SLOT_LAYOUT_HEADING);
        ui.label(FITTING_SLOT_LAYOUT_NO_CATALOGUE);
        return;
    };
    match slot_layout(fitting, catalogue) {
        SlotLayoutOutcome::Available(layout) => {
            ui.heading(FITTINGS_SLOT_LAYOUT_HEADING);
            for (line, is_over) in slot_layout_lines(&layout) {
                if is_over {
                    ui.colored_label(egui::Color32::LIGHT_RED, line);
                } else {
                    ui.label(line);
                }
            }
            if layout.subsystem_layout {
                ui.label(FITTING_SLOT_LAYOUT_TECH3_NOTE);
            }
            ui.label(FITTING_SLOT_LAYOUT_DISCLOSURE);
        }
        SlotLayoutOutcome::Unavailable => {
            ui.heading(FITTINGS_SLOT_LAYOUT_HEADING);
            ui.label(FITTING_SLOT_LAYOUT_NO_SHIP_DATA);
        }
    }
}

/// The EFT import panel: paste box, Import/Clear/sample actions, the
/// fatal error, and the imported fitting with its honest parse report.
/// Reachable without the fittings read scope (design section 8.2):
/// `show` calls it before the `LoadState` match. Logs counts only,
/// never pasted text.
fn fittings_import_panel(
    ui: &mut egui::Ui,
    state: &mut AppState,
    fitting_types: Option<&FittingTypes>,
    sde: &Sde,
) {
    ui.heading("Import a fitting from EFT or DNA text");
    ui.label("Paste an EFT block (the [Ship, Fitting name] text format) or a DNA fitting link (the single line of separated numbers the EVE client copies). The imported fitting stays in Mimir on this device unless you save it to EVE below, and it is gone when you switch characters or close Mimir.");
    let Some(catalogue) = fitting_types else {
        ui.label("Could not import: Mimir's bundled item data failed to load. Restart Mimir and try again.");
        return;
    };
    let response = ui.add(
        egui::TextEdit::multiline(&mut state.fittings_import_text)
            .hint_text("Paste EFT text ([Ship, Fitting name] then one item per line) or a DNA fitting link (one line, ending ::)")
            .desired_rows(8)
            .desired_width(f32::INFINITY),
    );
    state.text_input_focused |= response.has_focus();
    let import_enabled = !state.fittings_import_text.trim().is_empty();
    let clear_enabled = !state.fittings_import_text.is_empty()
        || state.fittings_imported.is_some()
        || state.fittings_import_error.is_some();
    ui.horizontal(|ui| {
        if ui
            .add_enabled(import_enabled, egui::Button::new("Import fitting"))
            .clicked()
        {
            let text = state.fittings_import_text.clone();
            tracing::info!(
                "[FITTING] import requested bytes={} lines={}",
                text.len(),
                text.lines().count()
            );
            match parse_import(&text, catalogue) {
                EftImportOutcome::Imported(fitting) => {
                    tracing::info!(
                        "[FITTING] import complete items={} issues={} placeholders={} charges={}",
                        fitting.items.len(),
                        fitting.report.issues.len(),
                        fitting.report.placeholder_lines,
                        fitting.report.charges_noted
                    );
                    state.fittings_imported = Some(fitting);
                    state.fittings_import_error = None;
                    state.fittings_import_owner = state.active_character_id;
                    clear_editor_state(state);
                }
                EftImportOutcome::Failed(fatal) => {
                    tracing::info!("[FITTING] import failed fatal={fatal:?}");
                    state.fittings_imported = None;
                    state.fittings_import_error = Some(fatal.message().to_string());
                    state.fittings_import_owner = state.active_character_id;
                    clear_editor_state(state);
                }
            }
        }
        if ui
            .add_enabled(clear_enabled, egui::Button::new("Clear import"))
            .clicked()
        {
            tracing::debug!("[FITTING] import cleared");
            state.fittings_import_text.clear();
            state.fittings_imported = None;
            state.fittings_import_error = None;
            state.fittings_import_owner = None;
            clear_editor_state(state);
        }
        if state.demo && ui.button("Use sample EFT").clicked() {
            tracing::debug!("[FITTING] demo sample EFT loaded");
            state.fittings_import_text = DEMO_SAMPLE_EFT.to_string();
            state.fittings_imported = None;
            state.fittings_import_error = None;
            state.fittings_import_owner = None;
            clear_editor_state(state);
        }
        if state.demo && ui.button("Use sample DNA").clicked() {
            tracing::debug!("[FITTING] demo sample DNA loaded");
            state.fittings_import_text = DEMO_SAMPLE_DNA.to_string();
            state.fittings_imported = None;
            state.fittings_import_error = None;
            state.fittings_import_owner = None;
            clear_editor_state(state);
        }
    });
    // The fatal-error label belongs to its owner like the detail
    // below (equality also covers no-character imports); resets
    // clear it on switch, so this only matters as defense-in-depth.
    if state.fittings_import_owner == state.active_character_id {
        if let Some(error) = state.fittings_import_error.clone() {
            ui.label(error);
        }
    }
    // Render guard (design section 8.1): the imported detail renders only
    // for the character it was imported for. The resets make this an
    // invariant; the check is defense-in-depth.
    let owner_ok = state.fittings_import_owner.is_some()
        && state.fittings_import_owner == state.active_character_id;
    if !owner_ok {
        return;
    }
    // Working clone (design section 8.2): edits mutate the clone;
    // the state draft is written back after rendering, never
    // held borrowed across egui calls.
    let Some(mut imported) = state.fittings_imported.clone() else {
        return;
    };
    ui.label(imported_summary_line_edited(
        &imported,
        state.fittings_import_edited,
    ));
    ui.label("Imported fitting");
    if let Some(note) = placeholder_note(imported.report.placeholder_lines) {
        ui.label(note);
    }
    if let Some(note) = charges_note(imported.report.charges_noted) {
        ui.label(note);
    }
    // Edit block (design section 6.1): heading, standing note,
    // rename row, then the add row; remove and quantity controls
    // sit on the item rows below.
    ui.heading(FITTINGS_EDITOR_HEADING);
    ui.label(FITTINGS_EDITOR_NOTE);
    ui.horizontal(|ui| {
        // The rename box edits a separate draft, seeded from
        // the fitting's name; the fitting itself changes only
        // when Rename applies it (typing alone never edits,
        // so an armed save confirmation cannot be bypassed).
        if state.fittings_editor_name.is_none() {
            state.fittings_editor_name = Some(imported.name.clone());
        }
        let mut apply_rename = false;
        if let Some(name_draft) = state.fittings_editor_name.as_mut() {
            let response = ui.add(egui::TextEdit::singleline(name_draft).hint_text("Fitting name"));
            state.text_input_focused |= response.has_focus();
            apply_rename = ui.button("Rename fitting").clicked();
        }
        if apply_rename {
            if let Some(draft_name) = state.fittings_editor_name.clone() {
                editor_rename(&mut imported, &draft_name);
                state.fittings_editor_name = Some(imported.name.clone());
                note_successful_edit(state);
            }
        }
    });
    ui.horizontal(|ui| {
        let name_response = ui.add(
            egui::TextEdit::singleline(&mut state.fittings_editor_add_name)
                .hint_text("Exact item name, like Damage Control II"),
        );
        state.text_input_focused |= name_response.has_focus();
        let quantity_response = ui.add(
            egui::TextEdit::singleline(&mut state.fittings_editor_add_quantity)
                .hint_text("Quantity (drones, fighters, cargo only)"),
        );
        state.text_input_focused |= quantity_response.has_focus();
        let add_enabled = !state.fittings_editor_add_name.trim().is_empty();
        if ui
            .add_enabled(add_enabled, egui::Button::new("Add item"))
            .clicked()
        {
            let add_name = state.fittings_editor_add_name.clone();
            let add_quantity = state.fittings_editor_add_quantity.clone();
            let quantity_trimmed = add_quantity.trim().to_string();
            let quantity = if quantity_trimmed.is_empty() {
                None
            } else {
                Some(quantity_trimmed.as_str())
            };
            match editor_add_item(&mut imported, catalogue, &add_name, quantity) {
                Ok(()) => note_successful_edit(state),
                Err(refusal) => {
                    state.fittings_editor_error = Some(add_refusal_message(refusal));
                }
            }
        }
    });
    if let Some(error) = state.fittings_editor_error.clone() {
        ui.label(error);
    }
    let local_resolver = imported.name_resolver();
    let item_rows = imported_item_rows(&imported, &local_resolver);
    if item_rows.is_empty() {
        ui.label("This fitting has no items to show.");
    } else if let Some(intent) = render_imported_item_rows(ui, state, &item_rows) {
        match intent {
            ImportedEditIntent::Remove(index) => {
                if editor_remove_item(&mut imported, index) {
                    note_successful_edit(state);
                }
            }
            ImportedEditIntent::SetQuantity(index, text) => {
                match editor_set_quantity(&mut imported, index, &text) {
                    Ok(()) => note_successful_edit(state),
                    Err(refusal) => {
                        state.fittings_editor_error = Some(quantity_refusal_message(refusal));
                    }
                }
            }
        }
    }
    // Write the working draft back, then derive every statistic,
    // copy, and save decision from the edited draft.
    state.fittings_imported = Some(imported.clone());
    let synth = imported.to_character_fitting();
    let levels = state
        .skills
        .as_ready()
        .map(|data| resource_skill_levels(&data.skills));
    render_fitting_resources(ui, &synth, fitting_types, levels, sde);
    render_rig_calibration(ui, &synth, fitting_types);
    render_bay_usage(ui, &synth, fitting_types);
    render_fitting_dps(ui, &synth, Some(&imported), fitting_types);
    render_fitting_cap_stability(ui, &synth, fitting_types);
    render_fitting_active_repair(ui, &synth, fitting_types);
    render_slot_layout(ui, &synth, fitting_types);
    render_ship_base_stats(ui, &synth, fitting_types);
    render_ship_resistances(ui, &synth, fitting_types);
    render_ship_base_ehp(ui, &synth, fitting_types);
    render_ship_nav_targeting(ui, &synth, fitting_types);
    // Loaded charges, in item order (design section 8.2).
    let charged_total = imported
        .items
        .iter()
        .filter(|item| item.charge.is_some())
        .count();
    if charged_total > 0 {
        ui.heading("Loaded charges");
        let shown = charged_total.min(FITTINGS_RENDER_MAX);
        if charged_total > FITTINGS_RENDER_MAX {
            ui.label(format!("Showing {shown} of {} items.", charged_total));
        }
        let mut rendered = 0;
        for item in &imported.items {
            if rendered >= FITTINGS_RENDER_MAX {
                break;
            }
            if let Some(charge) = &item.charge {
                ui.label(format!("{} - {}", item.name, charge.name));
                rendered += 1;
            }
        }
    }
    let issues = &imported.report.issues;
    if !issues.is_empty() {
        let import_format = imported.format;
        ui.heading(import_issues_heading(issues.len(), import_format));
        let shown = issues.len().min(IMPORT_ISSUES_RENDER_MAX);
        for issue in issues.iter().take(shown) {
            ui.label(format_import_issue(issue, import_format));
        }
        if issues.len() > IMPORT_ISSUES_RENDER_MAX {
            ui.label(import_issues_overflow_label(
                issues.len() - shown,
                import_format,
            ));
        }
    }
    if ui.button("Copy imported fitting as EFT").clicked() {
        match fitting_to_eft(&synth, &local_resolver) {
            None => {
                tracing::warn!("[FITTING] copy imported fitting blocked ship not resolved");
                state.status_message = "That fitting cannot be copied yet: its ship name has not loaded. Refresh and try again.".to_string();
            }
            Some(export) => {
                let line_count = export.text.lines().count();
                tracing::info!(
                    "[FITTING] copied imported fitting lines={} skipped_unknown={} skipped_empty={} charges_left_out={}",
                    line_count,
                    export.skipped_unknown,
                    export.skipped_empty,
                    imported.report.charges_noted
                );
                ui.ctx().copy_text(export.text.clone());
                let display_name = fitting_display_name(&imported.name);
                state.status_message =
                    copy_imported_status_message(&display_name, imported.report.charges_noted);
            }
        }
    }
    if ui.button("Copy imported fitting as DNA").clicked() {
        match fitting_to_dna(&synth) {
            None => {
                tracing::warn!("[FITTING] copy imported fitting as DNA blocked");
                state.status_message =
                    "That fitting cannot be copied: it has no ship. Refresh and try again."
                        .to_string();
            }
            Some(export) => {
                let left_out = export
                    .skipped_unsupported
                    .saturating_add(export.skipped_empty)
                    .saturating_add(export.skipped_capped);
                tracing::info!(
                    "[FITTING] copied imported fitting as DNA skipped_unsupported={} skipped_empty={} skipped_capped={} charges_left_out={}",
                    export.skipped_unsupported,
                    export.skipped_empty,
                    export.skipped_capped,
                    imported.report.charges_noted
                );
                ui.ctx().copy_text(export.text.clone());
                let display_name = fitting_display_name(&imported.name);
                state.status_message = copy_imported_dna_status_message(
                    &display_name,
                    imported.report.charges_noted,
                    left_out,
                );
            }
        }
    }
    // Save affordance (write design section 6.1): the arm
    // button, its armed confirmation block, the demo label,
    // or the in-flight row — never more than one.
    if render_write_in_flight(ui, state) {
        return;
    }
    if state.demo {
        ui.label(DEMO_FIT_WRITE_LABEL);
        return;
    }
    let active_id = state.active_character_id;
    let mapping = build_save_request(&synth);
    if matches!(
        state.fittings_write_confirm,
        Some(FittingWriteConfirm::SaveImported { character_id }) if Some(character_id) == active_id
    ) {
        // Recomputed every frame from the current imported
        // fitting: what the block displays is bit-for-bit what
        // Confirm sends. An un-saveable source drops the
        // confirmation (write design section 6.1).
        if let Some(label) = unsaveable_label(&mapping) {
            state.fittings_write_confirm = None;
            ui.label(label);
            return;
        }
        let enabled = write_enabled(state);
        let ship_name = imported.ship_name.clone();
        let charges_noted = imported.report.charges_noted;
        match render_save_confirm(
            ui,
            enabled,
            &mapping,
            &ship_name,
            false,
            Some(charges_noted),
            &local_resolver,
        ) {
            Some(SaveConfirmAction::Confirmed) => {
                if let Some(character_id) = active_id {
                    queue_save_request(state, character_id, mapping);
                }
            }
            Some(SaveConfirmAction::Cancelled) => {
                state.fittings_write_confirm = None;
            }
            None => {}
        }
    } else if let Some(label) = unsaveable_label(&mapping) {
        ui.label(label);
    } else if ui
        .add_enabled(
            write_enabled(state),
            egui::Button::new("Save imported fitting to EVE..."),
        )
        .clicked()
    {
        if let Some(character_id) = active_id {
            tracing::info!(
                "[FITTING] save confirmation armed character_id={} kind=save_imported kept={} dropped={}",
                character_id,
                mapping.request.items.len(),
                mapping.dropped.len()
            );
            state.fittings_write_confirm = Some(FittingWriteConfirm::SaveImported { character_id });
        }
    }
}

pub fn show(
    ui: &mut egui::Ui,
    state: &mut AppState,
    resolver: &NameResolver,
    fitting_types: Option<&FittingTypes>,
    sde: &Sde,
    cache: &mut PortraitImageCache,
) {
    ui.heading("Fittings");
    cache.prune(state);
    widgets::mode_notice(ui, state.demo, state.offline);
    if state.active_character().is_none() {
        widgets::no_character_panel(ui);
        return;
    }
    // Import needs no ESI read scope: render it before the LoadState
    // match so it works while saved fittings load, fail, or await a
    // step-up grant (design section 8.2).
    fittings_import_panel(ui, state, fitting_types, sde);
    ui.separator();
    // A confirmation never outlives the thing it confirms (write
    // design section 6): sweep stale armed values before any
    // confirmation block renders.
    if write_confirm_is_stale(state) {
        state.fittings_write_confirm = None;
    }
    // The write step-up panel stays reachable while the read
    // section awaits its own grant or shows an error (write
    // design section 3.2), ahead of the LoadState match.
    fittings_write_reauthorize_panel(ui, state);
    let snapshot: LoadState<FittingsData> = state.fittings.clone();
    match snapshot {
        LoadState::Loading => widgets::loading_panel(ui, "Loading fittings data..."),
        LoadState::Empty => widgets::empty_panel(ui, "No fittings data yet."),
        LoadState::Error(e) => {
            if widgets::error_panel_with_retry(ui, &e) {
                tracing::warn!("[FITTING] retry requested after load error");
                state.retry_requested = true;
            }
        }
        LoadState::Ready(bundle) => {
            let panel_shown = !state.demo
                && state.active_character_id.is_some()
                && bundle.needs_fittings_stepup();
            match &bundle.fittings {
                Err(error) => {
                    if error.needs_reauthorize && panel_shown {
                        tracing::debug!(
                            "[FITTING] showing step-up guidance (missing fittings scope)"
                        );
                        fittings_reauthorize_panel(ui, state);
                        return;
                    }
                    section_error_label(ui, error, panel_shown);
                }
                Ok(fittings) => {
                    if fittings.is_empty() {
                        ui.label("No saved fittings for this character yet. Fittings you save in EVE will appear here after a refresh.");
                        return;
                    }
                    // Search
                    let focus = widgets::search_box(
                        ui,
                        &mut state.fittings_search,
                        "Search fittings and ships",
                        state.focus_search,
                    );
                    state.text_input_focused |= focus;
                    if focus {
                        state.focus_search = false;
                    }
                    let query = state.fittings_search.clone();
                    let rows = fitting_rows(fittings, resolver);
                    let filtered: Vec<&FittingRow> = rows
                        .iter()
                        .filter(|row| fitting_matches_search(row, &query))
                        .collect();
                    if filtered.is_empty() {
                        ui.label("No fittings match that search.");
                    } else {
                        let shown = filtered.len().min(FITTINGS_RENDER_MAX);
                        ui.label(format!("Showing {shown} of {} fittings.", filtered.len()));
                        for row in filtered.iter().take(FITTINGS_RENDER_MAX) {
                            let selected =
                                Some(row.fitting_id) == state.fittings_selected_fitting_id;
                            if ui
                                .selectable_label(selected, row.display_name.clone())
                                .clicked()
                            {
                                tracing::info!(
                                    "[FITTING] selected fitting name={}",
                                    row.display_name
                                );
                                state.fittings_selected_fitting_id = Some(row.fitting_id);
                                // Write design section 8.1: an
                                // explicit user choice always beats
                                // a pending machine one.
                                state.fittings_pending_selection = None;
                            }
                            ui.label(format!("{} • {} items", row.ship_name, row.item_count));
                        }
                    }
                    // Detail of selected fitting (resolved against full list)
                    let selected_id = state.fittings_selected_fitting_id;
                    let Some(selected) =
                        selected_id.and_then(|sid| fittings.iter().find(|f| f.fitting_id == sid))
                    else {
                        return;
                    };
                    ui.separator();
                    let display_name = fitting_display_name(&selected.name);
                    ui.heading(display_name.clone());
                    let ship_type_id = selected.ship_type_id;
                    if ship_type_id > 0 {
                        ensure_type_icon_requested(state, ship_type_id);
                        let ship_name = resolver.name(ship_type_id).to_string();
                        ui.horizontal(|ui| {
                            show_type_icon(ui, cache, state, ship_type_id, TYPE_ICON_PX);
                            ui.label(ship_name);
                        });
                    } else {
                        ui.label(resolver.name(ship_type_id));
                    }
                    if let Some(desc) = selected.description.as_deref() {
                        let sanitized = sanitize_single_line(desc);
                        if !sanitized.is_empty() {
                            ui.label(sanitized);
                        }
                    }
                    let item_rows = fitting_item_rows(selected, resolver);
                    if item_rows.is_empty() {
                        ui.label("This fitting has no items to show.");
                    } else {
                        render_fitting_items(ui, &item_rows, Some((state, cache)));
                    }
                    let levels = state
                        .skills
                        .as_ready()
                        .map(|data| resource_skill_levels(&data.skills));
                    render_fitting_resources(ui, selected, fitting_types, levels, sde);
                    render_rig_calibration(ui, selected, fitting_types);
                    render_bay_usage(ui, selected, fitting_types);
                    render_fitting_dps(ui, selected, None, fitting_types);
                    render_fitting_cap_stability(ui, selected, fitting_types);
                    render_fitting_active_repair(ui, selected, fitting_types);
                    render_slot_layout(ui, selected, fitting_types);
                    render_ship_base_stats(ui, selected, fitting_types);
                    render_ship_resistances(ui, selected, fitting_types);
                    render_ship_base_ehp(ui, selected, fitting_types);
                    render_ship_nav_targeting(ui, selected, fitting_types);
                    if ui.button("Copy as EFT").clicked() {
                        tracing::info!(
                            "[FITTING] copy as EFT requested for fitting name={}",
                            display_name
                        );
                        match fitting_to_eft(selected, resolver) {
                            None => {
                                tracing::warn!(
                                    "[FITTING] copy as EFT blocked ship not resolved fitting name={}",
                                    display_name
                                );
                                state.status_message = "That fitting cannot be copied yet: its ship name has not loaded. Refresh and try again.".to_string();
                            }
                            Some(export) => {
                                ui.ctx().copy_text(export.text.clone());
                                let skipped =
                                    export.skipped_unknown.saturating_add(export.skipped_empty);
                                let line_count = export.text.lines().count();
                                if skipped == 0 {
                                    state.status_message =
                                        format!("Copied \"{}\" as EFT", display_name);
                                } else {
                                    state.status_message = format!(
                                        "Copied \"{}\" as EFT ({} items left out: names not loaded yet)",
                                        display_name, skipped
                                    );
                                }
                                tracing::info!(
                                    "[FITTING] copied fitting name={} lines={} skipped_unknown={} skipped_empty={}",
                                    display_name,
                                    line_count,
                                    export.skipped_unknown,
                                    export.skipped_empty
                                );
                            }
                        }
                    }
                    if ui.button("Copy as DNA").clicked() {
                        match fitting_to_dna(selected) {
                            None => {
                                tracing::warn!(
                                    "[FITTING] copy as DNA blocked fitting name={}",
                                    display_name
                                );
                                state.status_message = "That fitting cannot be copied: it has no ship. Refresh and try again.".to_string();
                            }
                            Some(export) => {
                                ui.ctx().copy_text(export.text.clone());
                                let skipped = export
                                    .skipped_unsupported
                                    .saturating_add(export.skipped_empty)
                                    .saturating_add(export.skipped_capped);
                                if skipped == 0 {
                                    state.status_message =
                                        format!("Copied \"{}\" as a DNA link", display_name);
                                } else {
                                    state.status_message = format!(
                                        "Copied \"{}\" as a DNA link ({} items left out: DNA links hold fitted modules only)",
                                        display_name, skipped
                                    );
                                }
                                tracing::info!(
                                    "[FITTING] copied fitting as DNA name={} skipped_unsupported={} skipped_empty={} skipped_capped={}",
                                    display_name,
                                    export.skipped_unsupported,
                                    export.skipped_empty,
                                    export.skipped_capped
                                );
                            }
                        }
                    }
                    // Write affordances (write design sections
                    // 6.2/6.3): save-a-copy and delete. The arm
                    // buttons and a single armed block never
                    // coexist for the same target.
                    if render_write_in_flight(ui, state) {
                        // In-flight row replaces the write buttons.
                    } else if state.demo {
                        ui.label(DEMO_FIT_WRITE_LABEL);
                    } else if let Some(active_id) = state.active_character_id {
                        let selected_fitting_id = selected.fitting_id;
                        let mapping = build_save_request(selected);
                        let armed_copy = matches!(
                            state.fittings_write_confirm,
                            Some(FittingWriteConfirm::SaveCopy {
                                character_id,
                                fitting_id,
                            }) if character_id == active_id
                                && fitting_id == selected_fitting_id
                        );
                        let armed_delete = matches!(
                            state.fittings_write_confirm,
                            Some(FittingWriteConfirm::Delete {
                                character_id,
                                fitting_id,
                            }) if character_id == active_id
                                && fitting_id == selected_fitting_id
                        );
                        if armed_copy {
                            // A copy source cannot drift
                            // un-saveable, but the guard keeps the
                            // confirmation honest if it ever did.
                            if let Some(label) = unsaveable_label(&mapping) {
                                state.fittings_write_confirm = None;
                                ui.label(label);
                            } else {
                                let enabled = write_enabled(state);
                                let ship_name = resolver.name(selected.ship_type_id);
                                match render_save_confirm(
                                    ui, enabled, &mapping, &ship_name, true, None, resolver,
                                ) {
                                    Some(SaveConfirmAction::Confirmed) => {
                                        queue_save_request(state, active_id, mapping);
                                    }
                                    Some(SaveConfirmAction::Cancelled) => {
                                        state.fittings_write_confirm = None;
                                    }
                                    None => {}
                                }
                            }
                        } else if armed_delete {
                            let enabled = write_enabled(state);
                            let name = mapping.request.name.clone();
                            let ship_name = resolver.name(selected.ship_type_id);
                            let item_count = selected.items.len();
                            match render_delete_confirm(ui, enabled, &name, &ship_name, item_count)
                            {
                                Some(DeleteConfirmAction::Confirmed) => {
                                    tracing::info!(
                                        "[FITTING] delete confirmed character_id={} fitting_id={}",
                                        active_id,
                                        selected_fitting_id
                                    );
                                    state.fittings_write_requested =
                                        Some(FittingWriteRequest::Delete {
                                            character_id: active_id,
                                            fitting_id: selected_fitting_id,
                                        });
                                    state.fittings_write_confirm = None;
                                }
                                Some(DeleteConfirmAction::Cancelled) => {
                                    state.fittings_write_confirm = None;
                                }
                                None => {}
                            }
                        } else {
                            if let Some(label) = unsaveable_label(&mapping) {
                                ui.label(label);
                            } else if ui
                                .add_enabled(
                                    write_enabled(state),
                                    egui::Button::new("Save a copy to EVE..."),
                                )
                                .clicked()
                            {
                                tracing::info!(
                                    "[FITTING] save confirmation armed character_id={} kind=save_copy kept={} dropped={}",
                                    active_id,
                                    mapping.request.items.len(),
                                    mapping.dropped.len()
                                );
                                state.fittings_write_confirm =
                                    Some(FittingWriteConfirm::SaveCopy {
                                        character_id: active_id,
                                        fitting_id: selected_fitting_id,
                                    });
                            }
                            // Only server-issued ids are delete
                            // targets (write design section 5.2).
                            if selected_fitting_id > 0
                                && ui
                                    .add_enabled(
                                        write_enabled(state),
                                        egui::Button::new("Delete fitting from EVE..."),
                                    )
                                    .clicked()
                            {
                                tracing::info!(
                                    "[FITTING] delete confirmation armed character_id={} fitting_id={}",
                                    active_id,
                                    selected_fitting_id
                                );
                                state.fittings_write_confirm = Some(FittingWriteConfirm::Delete {
                                    character_id: active_id,
                                    fitting_id: selected_fitting_id,
                                });
                            }
                        }
                    }
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::eft::{parse_eft, ImportFormat, ImportIssueKind, ImportReport};
    use crate::portraits::ImageKind;
    use crate::storage::repositories::CharacterRow;

    fn test_resolver() -> NameResolver {
        let mut r = NameResolver::new();
        r.insert(587, "Rifter".to_string());
        r.insert(597, "Punisher".to_string());
        r.insert(2048, "Demo Small Railgun".to_string());
        r.insert(2049, "Demo Small Afterburner".to_string());
        r.insert(2050, "Demo Light Missile Launcher".to_string());
        r.insert(1225, "Demo Small Shield Booster".to_string());
        r.insert(1535, "Demo Small Auxiliary Thruster".to_string());
        r.insert(28270, "Demo Interdiction Subsystem".to_string());
        r.insert(2456, "Demo Light Drone".to_string());
        r.insert(2457, "Demo Light Fighter".to_string());
        r.insert(34, "Tritanium".to_string());
        r.insert(35, "Pyerite".to_string());
        r.insert(36, "Mexallon".to_string());
        r.insert(37, "Isogen".to_string());
        r.insert(636, "Demo Light Missile".to_string());
        r
    }

    fn fitting_with_items(items: Vec<FittingItem>) -> CharacterFitting {
        CharacterFitting {
            fitting_id: 900000001,
            name: "Demo Brawler".to_string(),
            description: Some("Sample".to_string()),
            ship_type_id: 587,
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

    #[test]
    fn sanitize_collapses_crlf_controls_and_whitespace() {
        assert_eq!(
            sanitize_single_line("  Hello\r\nWorld\t\x07  "),
            "Hello World"
        );
        assert_eq!(sanitize_single_line(""), "");
        assert_eq!(sanitize_single_line("   "), "");
        assert_eq!(sanitize_single_line("a  b   c"), "a b c");
        assert_eq!(sanitize_single_line("\x00\r\n"), "");
    }

    #[test]
    fn display_name_fallbacks_empty_and_digit_only() {
        assert_eq!(fitting_display_name("Demo Brawler"), "Demo Brawler");
        assert_eq!(fitting_display_name("  Demo Brawler  "), "Demo Brawler");
        assert_eq!(fitting_display_name(""), "Unnamed fitting");
        assert_eq!(fitting_display_name("   "), "Unnamed fitting");
        assert_eq!(fitting_display_name("123"), "Unnamed fitting");
        assert_eq!(fitting_display_name(" 123 "), "Unnamed fitting");
        assert_eq!(fitting_display_name("000123"), "Unnamed fitting");
        // Mixed alphanumeric is not digit-only and survives.
        assert_eq!(fitting_display_name("123abc"), "123abc");
        assert_eq!(fitting_display_name("A\r\nB"), "A B");
    }

    #[test]
    fn section_for_flag_covers_every_prefix_and_catch_all() {
        assert_eq!(section_for_flag("LoSlot0"), FittingSection::Low);
        assert_eq!(section_for_flag("LoSlot6"), FittingSection::Low);
        assert_eq!(section_for_flag("MedSlot0"), FittingSection::Medium);
        assert_eq!(section_for_flag("MedSlot1"), FittingSection::Medium);
        assert_eq!(section_for_flag("HiSlot0"), FittingSection::High);
        assert_eq!(section_for_flag("HiSlot7"), FittingSection::High);
        assert_eq!(section_for_flag("RigSlot0"), FittingSection::Rig);
        assert_eq!(section_for_flag("RigSlot1"), FittingSection::Rig);
        assert_eq!(
            section_for_flag("SubSystemSlot0"),
            FittingSection::Subsystem
        );
        assert_eq!(
            section_for_flag("SubSystemSlot2"),
            FittingSection::Subsystem
        );
        assert_eq!(section_for_flag("DroneBay"), FittingSection::Drones);
        assert_eq!(section_for_flag("FighterBay"), FittingSection::Fighters);
        assert_eq!(section_for_flag("Cargo"), FittingSection::Cargo);
        assert_eq!(section_for_flag("Invalid"), FittingSection::Cargo);
        assert_eq!(section_for_flag("ServiceSlot0"), FittingSection::Cargo);
        assert_eq!(section_for_flag(""), FittingSection::Cargo);
        assert_eq!(section_for_flag("DroneBayExtra"), FittingSection::Cargo);
        // Prefix matching is case sensitive: lowercase not recognized.
        assert_eq!(section_for_flag("loslot0"), FittingSection::Cargo);
    }

    #[test]
    fn section_labels_are_words_never_flags_or_ids() {
        for section in SECTION_ORDER {
            let label = section_label(section);
            assert!(label.parse::<i64>().is_err(), "{label}");
            assert!(!label.contains("Slot"), "{label}");
        }
        assert_eq!(section_label(FittingSection::Low), "Low slots");
        assert_eq!(section_label(FittingSection::Medium), "Medium slots");
        assert_eq!(section_label(FittingSection::High), "High slots");
        assert_eq!(section_label(FittingSection::Rig), "Rigs");
        assert_eq!(section_label(FittingSection::Subsystem), "Subsystems");
        assert_eq!(section_label(FittingSection::Drones), "Drones");
        assert_eq!(section_label(FittingSection::Fighters), "Fighters");
        assert_eq!(
            section_label(FittingSection::Cargo),
            "Cargo and other items"
        );
    }

    #[test]
    fn fitting_rows_sort_and_count() {
        let resolver = test_resolver();
        let fittings = vec![
            CharacterFitting {
                fitting_id: 900000003,
                name: "b fitting".to_string(),
                ship_type_id: 587,
                items: vec![item("HiSlot0", 1, 2048)],
                ..Default::default()
            },
            CharacterFitting {
                fitting_id: 900000001,
                name: "A fitting".to_string(),
                ship_type_id: 597,
                items: vec![],
                ..Default::default()
            },
            CharacterFitting {
                fitting_id: 900000002,
                name: "a fitting".to_string(),
                ship_type_id: 587,
                items: vec![item("LoSlot0", 1, 2048), item("MedSlot0", 1, 2049)],
                ..Default::default()
            },
        ];
        let rows = fitting_rows(&fittings, &resolver);
        assert_eq!(rows.len(), 3);
        // Case-insensitive display order: "A fitting" < "a fitting" (tie lower) ?
        // "A fitting".to_lowercase == "a fitting".to_lowercase, then case-sensitive "A fitting" < "a fitting"
        // then b fitting last.
        assert_eq!(rows[0].display_name, "A fitting");
        assert_eq!(rows[0].fitting_id, 900000001);
        assert_eq!(rows[1].display_name, "a fitting");
        assert_eq!(rows[1].fitting_id, 900000002);
        assert_eq!(rows[2].display_name, "b fitting");
        assert_eq!(rows[0].item_count, 0);
        assert_eq!(rows[1].item_count, 2);
        assert_eq!(rows[0].ship_name, "Punisher");
        assert_eq!(rows[1].ship_name, "Rifter");
    }

    #[test]
    fn fitting_item_rows_clamp_skip_and_sort() {
        let resolver = test_resolver();
        let fitting = fitting_with_items(vec![
            item("HiSlot0", 1, 2050),
            item("LoSlot0", -5, 2048),
            item("MedSlot0", 1, 2049),
            item("LoSlot1", 1, 2048),
            item("Cargo", 500, 34),
            item("Invalid", 2, 35),
            item("Cargo", 1, 0),
            item("Cargo", 1, -9),
        ]);
        let rows = fitting_item_rows(&fitting, &resolver);
        // Skips 2 non-positive
        assert_eq!(rows.len(), 6);
        assert_eq!(rows.iter().filter(|r| r.type_id <= 0).count(), 0);
        // Negative clamps to 0, still present.
        let zero = rows
            .iter()
            .find(|r| r.type_id == 2048 && r.section == FittingSection::Low && r.quantity == 0)
            .expect("zero row present");
        assert_eq!(zero.quantity, 0);
        // Order: Low first sorted by flag then name
        assert_eq!(rows[0].section, FittingSection::Low);
        assert_eq!(rows[1].section, FittingSection::Low);
        // Medium after Low, High after, Cargo last
        assert_eq!(rows[2].section, FittingSection::Medium);
        assert_eq!(rows[3].section, FittingSection::High);
        assert_eq!(rows[4].section, FittingSection::Cargo);
        assert_eq!(rows[5].section, FittingSection::Cargo);
        // Unknown flag lands in Cargo
        let invalid_row = rows
            .iter()
            .find(|r| r.type_id == 35)
            .expect("invalid flag row");
        assert_eq!(invalid_row.section, FittingSection::Cargo);
        // Detail keeps Unknown Item for unresolved type (not in this fixture, but name resolves)
        // Check that resolved names are not Unknown
        for r in &rows {
            assert_ne!(r.type_name, "Unknown Item");
        }
    }

    #[test]
    fn search_matches_name_and_ship_only_case_insensitive() {
        let row = FittingRow {
            fitting_id: 1,
            ship_type_id: 587,
            display_name: "Demo Brawler".to_string(),
            ship_name: "Rifter".to_string(),
            item_count: 3,
        };
        assert!(fitting_matches_search(&row, "brawler"));
        assert!(fitting_matches_search(&row, "BRAWLER"));
        assert!(fitting_matches_search(&row, "rifter"));
        assert!(fitting_matches_search(&row, "RIF"));
        assert!(!fitting_matches_search(&row, "Tritanium"));
        assert!(fitting_matches_search(&row, ""));
        assert!(!fitting_matches_search(&row, "587"));
    }

    #[test]
    fn eft_header_and_no_blank_after_header() {
        let resolver = test_resolver();
        let fitting = fitting_with_items(vec![item("LoSlot0", 1, 2048), item("MedSlot0", 1, 2049)]);
        let export = fitting_to_eft(&fitting, &resolver).expect("export");
        assert_eq!(
            export.text,
            "[Rifter, Demo Brawler]\nDemo Small Railgun\n\nDemo Small Afterburner"
        );
        assert_eq!(export.skipped_unknown, 0);
        assert_eq!(export.skipped_empty, 0);
        // No blank line after header: second line is module, not empty
        let lines: Vec<&str> = export.text.lines().collect();
        assert_eq!(lines[0], "[Rifter, Demo Brawler]");
        assert_eq!(lines[1], "Demo Small Railgun");
        assert_ne!(lines[1], "");
    }

    #[test]
    fn eft_comma_and_brackets_cannot_corrupt_header() {
        let resolver = test_resolver();
        let mut fitting = fitting_with_items(vec![item("LoSlot0", 1, 2048)]);
        fitting.name = "Evil, Name [With] Brackets".to_string();
        let export = fitting_to_eft(&fitting, &resolver).expect("export");
        // Header sanitized: commas and brackets replaced by space, collapsed
        assert!(export.text.starts_with("[Rifter, Evil Name With Brackets]"));
        assert_eq!(
            export.text.lines().next().unwrap().matches(',').count(),
            1,
            "only header separator comma"
        );
    }

    #[test]
    fn eft_section_order_and_blank_lines_for_empty_sections() {
        let resolver = test_resolver();
        // Provide items out of order; export must order Low, Med, High, Rig, Sub, Drones, Fighters, Cargo
        let fitting = fitting_with_items(vec![
            item("Cargo", 3, 34),
            item("FighterBay", 2, 2457),
            item("DroneBay", 5, 2456),
            item("SubSystemSlot0", 1, 28270),
            item("RigSlot0", 1, 1535),
            item("HiSlot0", 1, 2050),
            item("MedSlot0", 1, 2049),
            item("LoSlot0", 1, 2048),
        ]);
        let export = fitting_to_eft(&fitting, &resolver).expect("export");
        let expected = concat!(
            "[Rifter, Demo Brawler]\n",
            "Demo Small Railgun\n",
            "\n",
            "Demo Small Afterburner\n",
            "\n",
            "Demo Light Missile Launcher\n",
            "\n",
            "Demo Small Auxiliary Thruster\n",
            "\n",
            "Demo Interdiction Subsystem\n",
            "\n",
            "Demo Light Drone x5\n",
            "\n",
            "Demo Light Fighter x2\n",
            "\n",
            "Tritanium x3"
        );
        assert_eq!(export.text, expected);
        assert!(
            !export.text.contains("\n\n\n"),
            "no consecutive blank lines"
        );
        assert!(!export.text.ends_with('\n'), "no trailing newline");
    }

    #[test]
    fn eft_module_repetition_for_quantity_two() {
        let resolver = test_resolver();
        let fitting = fitting_with_items(vec![item("LoSlot0", 2, 2048)]);
        let export = fitting_to_eft(&fitting, &resolver).expect("export");
        assert_eq!(
            export.text,
            "[Rifter, Demo Brawler]\nDemo Small Railgun\nDemo Small Railgun"
        );
    }

    #[test]
    fn eft_slot_quantity_expansion_is_capped() {
        // Slot quantities decode from remote JSON unvalidated: expansion
        // must stay bounded however hostile the quantity is, with the
        // truncation disclosed through skipped_empty (reviewer probe:
        // quantity 100_000 must not produce 100k lines, i64::MAX must
        // return at all).
        let resolver = test_resolver();
        for qty in [100_000i64, i64::MAX] {
            let fitting = fitting_with_items(vec![item("LoSlot0", qty, 2048)]);
            let export = fitting_to_eft(&fitting, &resolver).expect("export");
            assert_eq!(export.text.lines().count(), 1 + MAX_EFT_SLOT_REPEATS);
            assert_eq!(export.skipped_empty, 1);
        }
        // At the cap boundary nothing is disclosed as skipped.
        let at_cap = fitting_with_items(vec![item("LoSlot0", MAX_EFT_SLOT_REPEATS as i64, 2048)]);
        let export = fitting_to_eft(&at_cap, &resolver).expect("export");
        assert_eq!(export.text.lines().count(), 1 + MAX_EFT_SLOT_REPEATS);
        assert_eq!(export.skipped_empty, 0);
    }

    #[test]
    fn eft_ship_and_item_names_cannot_corrupt_structure() {
        let mut resolver = test_resolver();
        // Resolved names land inside the EFT header brackets and on
        // their own lines, where a comma starts a charge suffix.
        resolver.insert(587, "Rifter], Evil\n[Fake, Ship".to_string());
        resolver.insert(2048, "Railgun, [Charge]\nInjected".to_string());
        let fitting = fitting_with_items(vec![item("LoSlot0", 1, 2048)]);
        let export = fitting_to_eft(&fitting, &resolver).expect("export");
        let lines: Vec<&str> = export.text.lines().collect();
        assert_eq!(lines.len(), 2);
        assert_eq!(lines[0], "[Rifter Evil Fake Ship, Demo Brawler]");
        assert_eq!(lines[0].matches(',').count(), 1);
        assert_eq!(lines[0].matches('[').count(), 1);
        assert_eq!(lines[0].matches(']').count(), 1);
        assert_eq!(lines[1], "Railgun Charge Injected");
        assert!(!lines[1].contains(','));
        assert!(!export.text.contains('\r'));
    }

    #[test]
    fn eft_stacked_aggregation_and_saturation() {
        let resolver = test_resolver();
        let fitting = fitting_with_items(vec![
            item("DroneBay", i64::MAX, 2456),
            item("DroneBay", 5, 2456),
        ]);
        let export = fitting_to_eft(&fitting, &resolver).expect("export");
        // saturating_add caps at MAX
        assert!(export
            .text
            .contains(&format!("Demo Light Drone x{}", i64::MAX)));
        assert_eq!(export.skipped_empty, 0);
    }

    #[test]
    fn eft_clamped_zero_stack_dropped_and_counted() {
        let resolver = test_resolver();
        let fitting = fitting_with_items(vec![item("Cargo", -3, 36), item("LoSlot0", 1, 2048)]);
        let export = fitting_to_eft(&fitting, &resolver).expect("export");
        assert_eq!(export.skipped_empty, 1);
        assert!(!export.text.contains("Mexallon"));
        assert_eq!(export.text, "[Rifter, Demo Brawler]\nDemo Small Railgun");
    }

    #[test]
    fn eft_unknown_item_skipped_counted_and_never_rendered_as_id() {
        let resolver = test_resolver();
        let fitting =
            fitting_with_items(vec![item("LoSlot0", 1, 424242), item("LoSlot1", 1, 2048)]);
        let export = fitting_to_eft(&fitting, &resolver).expect("export");
        assert_eq!(export.skipped_unknown, 1);
        assert!(!export.text.contains("Unknown Item"));
        assert!(!export.text.contains("424242"));
        assert_eq!(export.text, "[Rifter, Demo Brawler]\nDemo Small Railgun");
    }

    #[test]
    fn eft_unresolved_ship_returns_none() {
        let resolver = test_resolver();
        let mut fitting = fitting_with_items(vec![item("LoSlot0", 1, 2048)]);
        fitting.ship_type_id = 424242;
        assert!(fitting_to_eft(&fitting, &resolver).is_none());
        fitting.ship_type_id = 0;
        assert!(fitting_to_eft(&fitting, &resolver).is_none());
        fitting.ship_type_id = -1;
        assert!(fitting_to_eft(&fitting, &resolver).is_none());
    }

    #[test]
    fn eft_output_never_contains_fitting_id_or_ship_type_id() {
        let resolver = test_resolver();
        let fitting = fitting_with_items(vec![item("LoSlot0", 1, 2048), item("Cargo", 1, 34)]);
        let export = fitting_to_eft(&fitting, &resolver).expect("export");
        assert!(!export.text.contains(&fitting.fitting_id.to_string()));
        assert!(!export.text.contains(&fitting.ship_type_id.to_string()));
        // Also type ids should not leak as numbers in unknown case already tested,
        // but for known items also must not leak.
        assert!(!export.text.contains("2048"));
        assert!(!export.text.contains("34") || export.text.contains("x1"));
    }

    #[test]
    fn eft_crlf_name_yields_single_line_header() {
        let resolver = test_resolver();
        let mut fitting = fitting_with_items(vec![item("LoSlot0", 1, 2048)]);
        fitting.name = "Demo\r\nBrawler\nName".to_string();
        let export = fitting_to_eft(&fitting, &resolver).expect("export");
        let header = export.text.lines().next().unwrap();
        assert_eq!(header, "[Rifter, Demo Brawler Name]");
        assert!(!header.contains('\r'));
        assert!(!export.text.contains('\r'));
    }

    #[test]
    fn dna_matches_flutter_round_trip_oracle() {
        // Flutter generateDna oracle: Rifter with two LoSlot
        // Damage Control rows generates exactly 587:2048;2::.
        let fitting = fitting_with_items(vec![item("LoSlot0", 1, 2048), item("LoSlot1", 1, 2048)]);
        let export = fitting_to_dna(&fitting).expect("dna export");
        assert_eq!(export.text, "587:2048;2::");
        assert_eq!(export.skipped_unsupported, 0);
        assert_eq!(export.skipped_empty, 0);
        assert_eq!(export.skipped_capped, 0);
    }

    #[test]
    fn dna_counts_follow_flutter_all_modules_order() {
        // Stored order is low, high, medium; Flutter allModules
        // is high, medium, low, rig, subsystem, so the high-slot
        // type is counted first regardless of stored order.
        let fitting = fitting_with_items(vec![
            item("LoSlot0", 1, 2048),
            item("HiSlot0", 1, 484),
            item("MedSlot0", 1, 5973),
            item("LoSlot1", 1, 2048),
        ]);
        let export = fitting_to_dna(&fitting).expect("dna export");
        assert_eq!(export.text, "587:484;1:5973;1:2048;2::");
    }

    #[test]
    fn dna_hull_only_and_ship_guard() {
        let fitting = fitting_with_items(Vec::new());
        let export = fitting_to_dna(&fitting).expect("hull only");
        assert_eq!(export.text, "587::");
        let mut broken = fitting_with_items(Vec::new());
        broken.ship_type_id = 0;
        assert!(fitting_to_dna(&broken).is_none());
    }

    #[test]
    fn dna_unsupported_and_empty_rows_are_counted() {
        let fitting = fitting_with_items(vec![
            item("LoSlot0", 1, 2048),
            item("DroneBay", 5, 2456),
            item("Cargo", 100, 34),
            item("LoSlot1", 0, 2048),
            item("HiSlot0", 1, -7),
        ]);
        let export = fitting_to_dna(&fitting).expect("dna export");
        assert_eq!(export.text, "587:2048;1::");
        assert_eq!(export.skipped_unsupported, 105);
        assert_eq!(export.skipped_empty, 2);
        assert_eq!(export.skipped_capped, 0);
    }

    #[test]
    fn dna_total_is_capped_at_importer_expansion_limit() {
        let fitting =
            fitting_with_items(vec![item("LoSlot0", 4000, 2048), item("HiSlot0", 500, 484)]);
        let export = fitting_to_dna(&fitting).expect("dna export");
        // High section counts first: 500 emitted, then low is
        // truncated to the remaining 3596 of the 4096 total.
        assert_eq!(export.text, "587:484;500:2048;3596::");
        assert_eq!(export.skipped_capped, 404);
    }

    #[test]
    fn dna_export_reimports_to_same_slot_items() {
        let types = crate::names::fitting_types::FittingTypes::load_bundled()
            .expect("bundled catalogue loads");
        let fitting = fitting_with_items(vec![
            item("LoSlot0", 1, 2048),
            item("LoSlot1", 1, 2048),
            item("MedSlot0", 1, 5973),
            item("HiSlot0", 1, 484),
            item("DroneBay", 5, 2456),
        ]);
        let export = fitting_to_dna(&fitting).expect("dna export");
        assert_eq!(export.skipped_unsupported, 5);
        match crate::fitting::dna::parse_dna(&export.text, &types) {
            crate::fitting::eft::EftImportOutcome::Imported(imported) => {
                assert!(imported.report.issues.is_empty());
                let mut ids: Vec<i64> = imported.items.iter().map(|i| i.type_id).collect();
                ids.sort_unstable();
                assert_eq!(ids, vec![484, 2048, 2048, 5973]);
            }
            crate::fitting::eft::EftImportOutcome::Failed(f) => {
                panic!("exported DNA must re-import, got {f:?}")
            }
        }
    }

    #[test]
    fn dna_imported_status_message_discloses_left_out() {
        assert_eq!(
            copy_imported_dna_status_message("Imported Rifter", 0, 0),
            "Copied \"Imported Rifter\" as a DNA link"
        );
        assert_eq!(
            copy_imported_dna_status_message("Imported Rifter", 1, 0),
            "Copied \"Imported Rifter\" as a DNA link (1 loaded charge left out: DNA links do not store loaded charges)"
        );
        assert_eq!(
            copy_imported_dna_status_message("Imported Rifter", 2, 5),
            "Copied \"Imported Rifter\" as a DNA link (2 loaded charges left out: DNA links do not store loaded charges; 5 items left out: DNA links hold fitted modules only)"
        );
    }

    #[test]
    fn render_caps_cover_one_hundred_rows() {
        // Sanity: cap constant is 100 and builder logic respects cap implicitly
        assert_eq!(FITTINGS_RENDER_MAX, 100);
        let resolver = test_resolver();
        let fitting = fitting_with_items((0..105).map(|_| item("Cargo", 1, 34)).collect());
        let rows = fitting_item_rows(&fitting, &resolver);
        assert_eq!(rows.len(), 105);
        // Cap is enforced at render time, not in builder; builder returns all rows.
        // The cap constant usage is verified by clippy and view code.
        assert_eq!(rows.len().min(FITTINGS_RENDER_MAX), 100);
    }

    #[test]
    fn import_issue_row_matches_locked_template() {
        let issue = ImportIssue {
            line: 3,
            text: "Nope".to_string(),
            kind: ImportIssueKind::UnknownName,
        };
        assert_eq!(
            format_import_issue(&issue, ImportFormat::Eft),
            "Line 3: \"Nope\" - no item in Mimir's bundled data has this exact name."
        );
    }

    #[test]
    fn import_issue_text_truncates_at_120_chars() {
        let long = "a".repeat(200);
        assert_eq!(
            truncate_issue_text(&long),
            format!("{}...", "a".repeat(120))
        );
        let exact = "b".repeat(120);
        assert_eq!(truncate_issue_text(&exact), exact);
        let over = "c".repeat(121);
        assert_eq!(
            truncate_issue_text(&over),
            format!("{}...", "c".repeat(120))
        );
        // Truncation counts characters, not bytes.
        let unicode = "é".repeat(200);
        assert_eq!(
            truncate_issue_text(&unicode),
            format!("{}...", "é".repeat(120))
        );
        assert_eq!(truncate_issue_text("short"), "short");
    }

    #[test]
    fn import_issues_heading_singular_and_plural() {
        assert_eq!(
            import_issues_heading(1, ImportFormat::Eft),
            "1 line could not be imported:"
        );
        assert_eq!(
            import_issues_heading(2, ImportFormat::Eft),
            "2 lines could not be imported:"
        );
        assert_eq!(
            import_issues_heading(25, ImportFormat::Eft),
            "25 lines could not be imported:"
        );
    }

    #[test]
    fn import_issues_overflow_label_singular_and_plural() {
        assert_eq!(IMPORT_ISSUES_RENDER_MAX, 20);
        // 25 issues: 20 shown, 5 disclosed.
        let remaining = 25 - 25.min(IMPORT_ISSUES_RENDER_MAX);
        assert_eq!(remaining, 5);
        assert_eq!(
            import_issues_overflow_label(remaining, ImportFormat::Eft),
            "...and 5 more lines that could not be imported. Fix the lines above and import again to see the rest."
        );
        assert_eq!(
            import_issues_overflow_label(1, ImportFormat::Eft),
            "...and 1 more line that could not be imported. Fix the lines above and import again to see the rest."
        );
    }

    #[test]
    fn import_summary_notes_and_copy_status() {
        let fitting = ImportedFitting {
            name: "Sample Brawler".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
            format: ImportFormat::Eft,
            items: Vec::new(),
            report: ImportReport {
                imported_lines: 7,
                placeholder_lines: 1,
                charges_noted: 0,
                issues: Vec::new(),
            },
        };
        assert_eq!(
            imported_summary_line(&fitting),
            "Imported \"Sample Brawler\" (Rifter): 0 items from 7 lines."
        );
        assert_eq!(
            placeholder_note(1).as_deref(),
            Some("1 empty-slot marker ignored.")
        );
        assert_eq!(
            placeholder_note(3).as_deref(),
            Some("3 empty-slot markers ignored.")
        );
        assert_eq!(placeholder_note(0), None);
        assert_eq!(charges_note(0), None);
        assert_eq!(
            charges_note(1).as_deref(),
            Some("1 loaded charge is listed below the items. It is not included when you copy this fitting as EFT.")
        );
        assert_eq!(
            charges_note(2).as_deref(),
            Some("2 loaded charges are listed below the items. They are not included when you copy this fitting as EFT.")
        );
        assert_eq!(
            copy_imported_status_message("Sample Brawler", 0),
            "Copied \"Sample Brawler\" as EFT"
        );
        assert_eq!(
            copy_imported_status_message("Sample Brawler", 1),
            "Copied \"Sample Brawler\" as EFT (1 loaded charge left out: copied EFT fittings do not store loaded charges)"
        );
        assert_eq!(
            copy_imported_status_message("Sample Brawler", 2),
            "Copied \"Sample Brawler\" as EFT (2 loaded charges left out: copied EFT fittings do not store loaded charges)"
        );
    }

    #[test]
    fn demo_sample_parses_with_one_placeholder_and_one_charge() {
        let types = FittingTypes::load_bundled().expect("bundled catalogue loads");
        match parse_eft(DEMO_SAMPLE_EFT, &types) {
            EftImportOutcome::Imported(fitting) => {
                assert!(fitting.report.issues.is_empty());
                assert_eq!(fitting.report.placeholder_lines, 1);
                assert_eq!(fitting.report.charges_noted, 1);
                assert_eq!(fitting.report.imported_lines, 11);
            }
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        }
    }

    #[test]
    fn write_confirmation_lines_match_the_locked_templates() {
        assert_eq!(
            save_confirmation_title("My Rifter"),
            "Save \"My Rifter\" to EVE?"
        );
        assert_eq!(
            save_confirmation_imported("My Rifter", "Rifter", 3),
            "\"My Rifter\" (Rifter, 3 items) will be added to this character's in-game fitting list."
        );
        assert_eq!(
            save_confirmation_copy("My Rifter", "Rifter", 3),
            "A copy of \"My Rifter\" (Rifter, 3 items) will be added to this character's in-game fitting list. The original stays as it is."
        );
        assert_eq!(
            fallback_name_line(),
            "The fitting name was empty, so it will be saved as \"Unnamed fit\"."
        );
        assert_eq!(
            truncated_name_line(51),
            "EVE fitting names are limited to 50 characters. This name (51 characters) will be saved in the shortened form shown above."
        );
        assert_eq!(
            description_truncated_line(),
            "The fitting notes are too long for EVE and will be shortened."
        );
        assert_eq!(
            charges_not_sent_line(2),
            "2 loaded charge(s) are shown above but are not part of a saved fitting and will not be sent to EVE."
        );
        assert_eq!(
            delete_confirmation_title("My Rifter"),
            "Delete \"My Rifter\" from EVE?"
        );
        assert_eq!(
            delete_confirmation_summary("My Rifter", "Rifter", 3),
            "\"My Rifter\" (Rifter, 3 items) will be deleted from this character's in-game fitting list. This cannot be undone."
        );
        assert_eq!(
            dropped_item_line("Demo Small Railgun", DropReason::NoEsiFlag),
            "Demo Small Railgun has no EVE fitting slot and will be left out."
        );
        assert_eq!(
            dropped_item_line("Demo Small Railgun", DropReason::DuplicateSlot),
            "Demo Small Railgun shares a fitting slot with another item and will be left out."
        );
        assert_eq!(
            dropped_item_line("Demo Small Railgun", DropReason::NotSaveable),
            "Demo Small Railgun cannot be saved and will be left out."
        );
        assert_eq!(
            DEMO_FIT_WRITE_LABEL,
            "Demo mode uses sample data. Saving or deleting fittings in EVE is disabled."
        );
    }

    #[test]
    fn unsaveable_labels_match_the_locked_wording() {
        let fitting = |ship_type_id: i64, items: Vec<FittingItem>| CharacterFitting {
            fitting_id: 1,
            name: "Rifter".to_string(),
            description: None,
            ship_type_id,
            items,
        };
        let saveable = build_save_request(&fitting(587, vec![item("LoSlot0", 1, 2048)]));
        assert_eq!(unsaveable_label(&saveable), None);
        let ship_zero = build_save_request(&fitting(0, vec![item("LoSlot0", 1, 2048)]));
        assert_eq!(
            unsaveable_label(&ship_zero),
            Some("This fitting cannot be saved to EVE: nothing in it fits an EVE fitting slot.")
        );
        let no_items = build_save_request(&fitting(587, vec![item("RigSlot3", 1, 2048)]));
        assert_eq!(
            unsaveable_label(&no_items),
            Some("This fitting cannot be saved to EVE: nothing in it fits an EVE fitting slot.")
        );
        let over_cap: Vec<FittingItem> = (0..513).map(|_| item("Cargo", 1, 34)).collect();
        let over = build_save_request(&fitting(587, over_cap));
        assert_eq!(
            unsaveable_label(&over),
            Some("This fitting cannot be saved to EVE: it has more items than EVE allows in one fitting (512).")
        );
        let at_cap: Vec<FittingItem> = (0..512).map(|_| item("Cargo", 1, 34)).collect();
        let at = build_save_request(&fitting(587, at_cap));
        assert_eq!(unsaveable_label(&at), None);
    }

    #[test]
    fn dropped_disclosure_caps_named_lines_then_overflows() {
        let resolver = test_resolver();
        assert_eq!(WRITE_DROPPED_RENDER_MAX, 8);
        // Ten dropped items, all resolved: eight named lines
        // plus the overflow line (write design section 13).
        let dropped: Vec<DroppedFittingItem> = (0..10)
            .map(|_| DroppedFittingItem {
                type_id: 2048,
                flag: "RigSlot3".to_string(),
                reason: DropReason::NoEsiFlag,
            })
            .collect();
        let lines = dropped_disclosure_lines(&dropped, &resolver);
        assert_eq!(lines.len(), 9);
        assert_eq!(
            lines[0],
            "Demo Small Railgun has no EVE fitting slot and will be left out."
        );
        assert_eq!(lines[8], "2 more item(s) will be left out.");
        // Unresolved items collapse into the overflow line and
        // are never rendered as numbers.
        let dropped = vec![
            DroppedFittingItem {
                type_id: 424242,
                flag: "RigSlot3".to_string(),
                reason: DropReason::NoEsiFlag,
            },
            DroppedFittingItem {
                type_id: 2048,
                flag: "HiSlot0".to_string(),
                reason: DropReason::DuplicateSlot,
            },
        ];
        let lines = dropped_disclosure_lines(&dropped, &resolver);
        assert_eq!(lines.len(), 2);
        assert_eq!(
            lines[0],
            "Demo Small Railgun shares a fitting slot with another item and will be left out."
        );
        assert_eq!(lines[1], "1 more item(s) will be left out.");
        assert!(lines.iter().all(|line| !line.contains("424242")));
        assert!(dropped_disclosure_lines(&[], &resolver).is_empty());
    }

    #[test]
    fn write_confirm_staleness_matrix() {
        let mut state = AppState::new(false);
        state.active_character_id = Some(42);
        // Nothing armed is never stale.
        assert!(!write_confirm_is_stale(&state));
        // SaveImported: own character + owner + imported present.
        state.fittings_write_confirm = Some(FittingWriteConfirm::SaveImported { character_id: 42 });
        assert!(write_confirm_is_stale(&state), "no imported fitting yet");
        state.fittings_import_owner = Some(42);
        state.fittings_imported = Some(ImportedFitting {
            name: "Test".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
            format: ImportFormat::Eft,
            items: Vec::new(),
            report: ImportReport {
                imported_lines: 0,
                placeholder_lines: 0,
                charges_noted: 0,
                issues: Vec::new(),
            },
        });
        assert!(!write_confirm_is_stale(&state), "fresh import arm");
        state.active_character_id = Some(7);
        assert!(write_confirm_is_stale(&state), "switched character");
        state.fittings_write_confirm = Some(FittingWriteConfirm::SaveImported { character_id: 7 });
        // SaveCopy/Delete: stamped fitting must be in the list.
        state.fittings_write_confirm = Some(FittingWriteConfirm::SaveCopy {
            character_id: 7,
            fitting_id: 4242,
        });
        assert!(write_confirm_is_stale(&state), "list is Loading");
        state.fittings = LoadState::Ready(FittingsData {
            fittings: Ok(vec![CharacterFitting {
                fitting_id: 4242,
                ..CharacterFitting::default()
            }]),
        });
        assert!(!write_confirm_is_stale(&state), "fitting still loaded");
        state.fittings_write_confirm = Some(FittingWriteConfirm::Delete {
            character_id: 7,
            fitting_id: 4242,
        });
        assert!(!write_confirm_is_stale(&state));
        state.fittings_write_confirm = Some(FittingWriteConfirm::Delete {
            character_id: 7,
            fitting_id: 0,
        });
        assert!(write_confirm_is_stale(&state), "zero id is never a target");
        state.fittings_write_confirm = Some(FittingWriteConfirm::SaveCopy {
            character_id: 42,
            fitting_id: 4242,
        });
        assert!(
            write_confirm_is_stale(&state),
            "stamped for another character"
        );
    }

    #[test]
    fn write_enabled_gate_covers_demo_busy_flight_and_character() {
        // Demo cannot write.
        let demo = AppState::new(true);
        assert!(!write_enabled(&demo));
        let mut state = AppState::new(false);
        assert!(!write_enabled(&state), "no active character");
        state.active_character_id = Some(42);
        assert!(write_enabled(&state));
        state.auth = crate::app::state::AuthState::AwaitingCallback;
        assert!(!write_enabled(&state), "sign-in in progress");
        state.auth = crate::app::state::AuthState::Idle;
        state.fittings_write_in_flight = Some(crate::app::state::FittingWriteInFlight {
            character_id: 42,
            kind: crate::app::state::FittingWriteKind::Save,
            fitting_id: None,
        });
        assert!(!write_enabled(&state), "one flight app-wide");
        // A fresh demo state cannot write even with a character.
        let mut demo2 = AppState::new(true);
        demo2.active_character_id = Some(42);
        assert!(!write_enabled(&demo2));
    }

    #[test]
    fn demo_sample_round_trips_through_exporter_with_zero_skips() {
        let types = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let fitting = match parse_eft(DEMO_SAMPLE_EFT, &types) {
            EftImportOutcome::Imported(fitting) => fitting,
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        let synth = fitting.to_character_fitting();
        let resolver = fitting.name_resolver();
        let export = fitting_to_eft(&synth, &resolver).expect("export");
        assert_eq!(export.skipped_unknown, 0);
        assert_eq!(export.skipped_empty, 0);
        // The copy re-imports cleanly (the stored charge was display-only).
        match parse_eft(&export.text, &types) {
            EftImportOutcome::Imported(reimported) => {
                assert!(reimported.report.issues.is_empty());
            }
            EftImportOutcome::Failed(fatal) => panic!("re-import must succeed, got {fatal:?}"),
        }
    }

    #[test]
    fn dna_issue_row_heading_and_overflow_match_locked_templates() {
        let issue = ImportIssue {
            line: 1,
            text: "unresolved item".to_string(),
            kind: ImportIssueKind::UnknownTypeId,
        };
        assert_eq!(
            format_import_issue(&issue, ImportFormat::Dna),
            "Segment 1: \"unresolved item\" - Mimir's bundled data has no item for this segment."
        );
        assert_eq!(
            import_issues_heading(1, ImportFormat::Dna),
            "1 segment could not be imported:"
        );
        assert_eq!(
            import_issues_heading(2, ImportFormat::Dna),
            "2 segments could not be imported:"
        );
        assert_eq!(
            import_issues_overflow_label(1, ImportFormat::Dna),
            "...and 1 more segment that could not be imported. Fix the segments above and import again to see the rest."
        );
        assert_eq!(
            import_issues_overflow_label(5, ImportFormat::Dna),
            "...and 5 more segments that could not be imported. Fix the segments above and import again to see the rest."
        );
    }

    #[test]
    fn dna_summary_line_uses_segments() {
        let fitting = ImportedFitting {
            name: "Imported Rifter".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
            format: ImportFormat::Dna,
            items: Vec::new(),
            report: ImportReport {
                imported_lines: 6,
                placeholder_lines: 0,
                charges_noted: 0,
                issues: Vec::new(),
            },
        };
        assert_eq!(
            imported_summary_line(&fitting),
            "Imported \"Imported Rifter\" (Rifter): 0 items from 6 segments."
        );
    }

    #[test]
    fn demo_sample_dna_parses_clean_via_router() {
        let types = FittingTypes::load_bundled().expect("bundled catalogue loads");
        match parse_import(DEMO_SAMPLE_DNA, &types) {
            EftImportOutcome::Imported(fitting) => {
                assert!(fitting.report.issues.is_empty());
                assert_eq!(fitting.report.placeholder_lines, 0);
                assert_eq!(fitting.report.charges_noted, 0);
                assert_eq!(fitting.report.imported_lines, 6);
                assert_eq!(fitting.items.len(), 8);
                assert_eq!(fitting.ship_type_id, 587);
                assert_eq!(fitting.ship_name, "Rifter");
                assert_eq!(fitting.name, "Imported Rifter");
                assert_eq!(fitting.format, ImportFormat::Dna);
            }
            EftImportOutcome::Failed(fatal) => panic!("demo DNA must import, got {fatal:?}"),
        }
    }

    #[test]
    fn demo_sample_dna_round_trips_through_exporter_with_zero_skips() {
        let types = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let fitting = match parse_import(DEMO_SAMPLE_DNA, &types) {
            EftImportOutcome::Imported(fitting) => fitting,
            EftImportOutcome::Failed(fatal) => panic!("demo DNA must import, got {fatal:?}"),
        };
        let synth = fitting.to_character_fitting();
        let resolver = fitting.name_resolver();
        let export = fitting_to_eft(&synth, &resolver).expect("export");
        assert_eq!(export.skipped_unknown, 0);
        assert_eq!(export.skipped_empty, 0);
        assert!(export.text.starts_with("[Rifter, Imported Rifter]"));
        match parse_eft(&export.text, &types) {
            EftImportOutcome::Imported(reimported) => {
                assert!(reimported.report.issues.is_empty());
                assert_eq!(reimported.items.len(), 8);
            }
            EftImportOutcome::Failed(fatal) => panic!("re-import must succeed, got {fatal:?}"),
        }
    }

    #[test]
    fn eft_demo_still_routes_as_eft_via_router() {
        let types = FittingTypes::load_bundled().expect("bundled catalogue loads");
        match parse_import(DEMO_SAMPLE_EFT, &types) {
            EftImportOutcome::Imported(fitting) => {
                assert_eq!(fitting.format, ImportFormat::Eft);
                assert!(fitting.report.issues.is_empty());
            }
            EftImportOutcome::Failed(fatal) => panic!("demo EFT must import, got {fatal:?}"),
        }
    }

    fn budget(used: f64, output: f64) -> ResourceBudget {
        ResourceBudget {
            used,
            output,
            excluded_modules: 0,
            // Mechanical extension for the need-reduction
            // fields (design section 6): base equals used and
            // nothing is unreduced in these template pins.
            base_used: used,
            unreduced_modules: 0,
        }
    }

    #[test]
    fn fitting_resource_lines_match_the_locked_templates() {
        assert_eq!(
            resource_line("CPU", &budget(114.0, 130.0), "tf"),
            "CPU: 114.0 tf of 130.0 tf used (16.0 tf left)"
        );
        assert_eq!(
            resource_line("Power grid", &budget(31.0, 41.0), "MW"),
            "Power grid: 31.0 MW of 41.0 MW used (10.0 MW left)"
        );
        assert_eq!(
            resource_line("CPU", &budget(150.0, 130.0), "tf"),
            "CPU: 150.0 tf of 130.0 tf used (20.0 tf over)"
        );
        assert_eq!(
            resource_line("Power grid", &budget(50.0, 41.0), "MW"),
            "Power grid: 50.0 MW of 41.0 MW used (9.0 MW over)"
        );
        // Exactly at budget is not over: 0.0 left, normal colour.
        assert_eq!(
            resource_line("CPU", &budget(130.0, 130.0), "tf"),
            "CPU: 130.0 tf of 130.0 tf used (0.0 tf left)"
        );
    }

    #[test]
    fn fitting_resource_excluded_lines_match_the_locked_templates() {
        assert_eq!(cpu_excluded_line(0), None);
        assert_eq!(
            cpu_excluded_line(1).as_deref(),
            Some(
                "CPU does not count 1 fitted module with no CPU data in Mimir's bundled item data."
            )
        );
        assert_eq!(
            cpu_excluded_line(2).as_deref(),
            Some("CPU does not count 2 fitted modules with no CPU data in Mimir's bundled item data.")
        );
        assert_eq!(power_grid_excluded_line(0), None);
        assert_eq!(
            power_grid_excluded_line(1).as_deref(),
            Some("Power grid does not count 1 fitted module with no power grid data in Mimir's bundled item data.")
        );
        assert_eq!(
            power_grid_excluded_line(2).as_deref(),
            Some("Power grid does not count 2 fitted modules with no power grid data in Mimir's bundled item data.")
        );
    }

    #[test]
    fn fitting_resource_unavailable_and_disclosure_wording() {
        assert_eq!(
            FITTINGS_RESOURCES_HEADING,
            "Fitting resources (base values)"
        );
        assert_eq!(
            FITTING_RESOURCES_NO_CATALOGUE,
            "Fitting resources unavailable: Mimir's bundled item data failed to load."
        );
        assert_eq!(
            FITTING_RESOURCES_NO_SHIP_OUTPUT,
            "Fitting resources unavailable: Mimir's bundled item data has no ship output data for this fitting's ship."
        );
        assert_eq!(
            FITTING_RESOURCES_DISCLOSURE,
            "Base values from Mimir's bundled item data. Skills, implants, and bonuses from modules, rigs, subsystems, and the ship itself are not applied, so these numbers can differ from EVE."
        );
    }

    // Demo story (design section 7): the locked numbers a
    // reviewer sees, computed from the real demo fixture over
    // the real bundled catalogue, so fixture or catalogue
    // drift fails this test instead of surprising a reviewer.
    #[test]
    fn demo_fixture_resources_match_the_locked_demo_story() {
        use crate::demo::data::DEMO_FITTINGS_JSON;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let assert_close = |actual: f64, expected: f64| {
            assert!(
                (actual - expected).abs() < 1e-9,
                "expected {expected}, got {actual}"
            );
        };
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");

        // Demo Brawler (Rifter, 130.0 tf / 41.0 MW): Damage Control
        // II + 2x Gistum hardener counted; blueprint and ore
        // excluded on both dimensions.
        let brawler = match fitting_resources(&find("Demo Brawler"), &catalogue) {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("Demo Brawler must have ship output"),
        };
        assert_close(brawler.0.used, 84.0);
        assert_close(brawler.0.output, 130.0);
        assert_close(brawler.1.used, 3.0);
        assert_close(brawler.1.output, 41.0);
        assert_eq!(brawler.0.excluded_modules, 2);
        assert_eq!(brawler.1.excluded_modules, 2);
        assert_eq!(
            resource_line("CPU", &brawler.0, "tf"),
            "CPU: 84.0 tf of 130.0 tf used (46.0 tf left)"
        );
        assert_eq!(
            resource_line("Power grid", &brawler.1, "MW"),
            "Power grid: 3.0 MW of 41.0 MW used (38.0 MW left)"
        );

        // Mission Runner: one counted module, one excluded.
        let mission = match fitting_resources(&find("Mission Runner"), &catalogue) {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("Mission Runner must have ship output"),
        };
        assert_close(mission.0.used, 30.0);
        assert_close(mission.1.used, 1.0);
        assert_eq!(mission.0.excluded_modules, 1);
        assert_eq!(mission.1.excluded_modules, 1);

        // Demo Runner (Punisher, 140.0 tf / 67.0 MW).
        let runner = match fitting_resources(&find("Demo Runner"), &catalogue) {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("Demo Runner must have ship output"),
        };
        assert_close(runner.0.used, 57.0);
        assert_close(runner.0.output, 140.0);
        assert_close(runner.1.used, 2.0);
        assert_close(runner.1.output, 67.0);
        assert_eq!(runner.0.excluded_modules, 1);
        assert_eq!(runner.1.excluded_modules, 1);

        // The clean showcase: the demo sample import, through
        // the shared synthesis path, with no excluded lines.
        let synth = match parse_eft(DEMO_SAMPLE_EFT, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        let sample = match fitting_resources(&synth, &catalogue) {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("sample must have ship output"),
        };
        assert_close(sample.0.used, 114.0);
        assert_close(sample.1.used, 31.0);
        assert_close(sample.0.remaining(), 16.0);
        assert_close(sample.1.remaining(), 10.0);
        assert_eq!(sample.0.excluded_modules, 0);
        assert_eq!(sample.1.excluded_modules, 0);
        assert_eq!(cpu_excluded_line(sample.0.excluded_modules), None);
        assert_eq!(power_grid_excluded_line(sample.1.excluded_modules), None);
    }

    #[test]
    fn fitting_resource_applied_wording() {
        assert_eq!(
            FITTINGS_RESOURCES_APPLIED_HEADING,
            "Fitting resources (with skill bonuses)"
        );
        assert_eq!(
            FITTING_RESOURCES_APPLIED_DISCLOSURE,
            "Ship outputs and module needs include only the skill bonuses and reductions above, from Mimir's bundled item data and this character's trained skill levels. Implants, and bonuses and reductions from modules, rigs, subsystems, and the ship itself are not applied, so these numbers can differ from EVE."
        );
        // Names resolve through the real bundled SDE, never raw ids.
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let cpu_name = sde.skill_name_quiet(CPU_MANAGEMENT_SKILL_ID);
        let pg_name = sde.skill_name_quiet(POWER_GRID_MANAGEMENT_SKILL_ID);
        assert_eq!(cpu_name, "CPU Management");
        assert_eq!(pg_name, "Power Grid Management");
        // Need-reduction names resolve through the real bundled
        // SDE as well, never raw ids (design section 8).
        let weapon_name = sde.skill_name_quiet(WEAPON_UPGRADES_SKILL_ID);
        let advanced_name = sde.skill_name_quiet(ADVANCED_WEAPON_UPGRADES_SKILL_ID);
        let grid_name = sde.skill_name_quiet(ENERGY_GRID_UPGRADES_SKILL_ID);
        let electronics_name = sde.skill_name_quiet(ELECTRONICS_UPGRADES_SKILL_ID);
        let shield_name = sde.skill_name_quiet(SHIELD_UPGRADES_SKILL_ID);
        assert_eq!(weapon_name, "Weapon Upgrades");
        assert_eq!(advanced_name, "Advanced Weapon Upgrades");
        assert_eq!(grid_name, "Energy Grid Upgrades");
        assert_eq!(electronics_name, "Electronics Upgrades");
        assert_eq!(shield_name, "Shield Upgrades");
        // Level 5 is +25%; level 1 is +5%; level 0 states the absence.
        assert_eq!(
            skill_line("CPU output", &cpu_name, 5),
            "CPU output includes CPU Management level 5 (+25%)."
        );
        assert_eq!(
            skill_line("Power grid output", &pg_name, 5),
            "Power grid output includes Power Grid Management level 5 (+25%)."
        );
        assert_eq!(
            skill_line("CPU output", &cpu_name, 1),
            "CPU output includes CPU Management level 1 (+5%)."
        );
        assert_eq!(
            skill_line("Power grid output", &pg_name, 1),
            "Power grid output includes Power Grid Management level 1 (+5%)."
        );
        assert_eq!(
            skill_line("CPU output", &cpu_name, 0),
            "CPU output includes no bonus: CPU Management is level 0."
        );
        assert_eq!(
            skill_line("Power grid output", &pg_name, 0),
            "Power grid output includes no bonus: Power Grid Management is level 0."
        );
        // Before-reductions lines render the base figure with
        // the same one-decimal shape as every other amount.
        let before = ResourceBudget {
            used: 107.25,
            output: 130.0,
            excluded_modules: 0,
            base_used: 114.0,
            unreduced_modules: 0,
        };
        assert_eq!(
            base_need_line("CPU", &before, "tf"),
            "CPU need before skill reductions: 114.0 tf."
        );
        let before_power = ResourceBudget {
            used: 29.8,
            output: 41.0,
            excluded_modules: 0,
            base_used: 31.0,
            unreduced_modules: 0,
        };
        assert_eq!(
            base_need_line("Power grid", &before_power, "MW"),
            "Power grid need before skill reductions: 31.0 MW."
        );
        // Reduction lines: level 5 is -25% (Advanced -10%),
        // level 1 is -5% (Advanced -2%), level 0 states the
        // absence. Advanced pins the x2 percent: a
        // x5-for-everything mutant fails here.
        assert_eq!(
            need_reduction_line("CPU need of matching modules", &weapon_name, 5, 5),
            "CPU need of matching modules includes Weapon Upgrades level 5 (-25%)."
        );
        assert_eq!(
            need_reduction_line("CPU need of matching modules", &weapon_name, 1, 5),
            "CPU need of matching modules includes Weapon Upgrades level 1 (-5%)."
        );
        assert_eq!(
            need_reduction_line("CPU need of matching modules", &weapon_name, 0, 5),
            "CPU need of matching modules includes no reduction: Weapon Upgrades is level 0."
        );
        assert_eq!(
            need_reduction_line("CPU need of matching modules", &grid_name, 5, 5),
            "CPU need of matching modules includes Energy Grid Upgrades level 5 (-25%)."
        );
        assert_eq!(
            need_reduction_line("CPU need of matching modules", &electronics_name, 5, 5),
            "CPU need of matching modules includes Electronics Upgrades level 5 (-25%)."
        );
        assert_eq!(
            need_reduction_line("Power grid need of matching modules", &advanced_name, 5, 2),
            "Power grid need of matching modules includes Advanced Weapon Upgrades level 5 (-10%)."
        );
        assert_eq!(
            need_reduction_line("Power grid need of matching modules", &advanced_name, 1, 2),
            "Power grid need of matching modules includes Advanced Weapon Upgrades level 1 (-2%)."
        );
        assert_eq!(
            need_reduction_line(
                "Power grid need of matching modules",
                &advanced_name,
                0,
                2
            ),
            "Power grid need of matching modules includes no reduction: Advanced Weapon Upgrades is level 0."
        );
        assert_eq!(
            need_reduction_line("Power grid need of matching modules", &shield_name, 5, 5),
            "Power grid need of matching modules includes Shield Upgrades level 5 (-25%)."
        );
        assert_eq!(
            need_reduction_line(
                "Power grid need of matching modules",
                &shield_name,
                0,
                5
            ),
            "Power grid need of matching modules includes no reduction: Shield Upgrades is level 0."
        );
        // Unreduced lines: none when proven, singular and plural
        // forms otherwise.
        assert_eq!(cpu_unreduced_line(0), None);
        assert_eq!(
            cpu_unreduced_line(1).as_deref(),
            Some(
                "CPU counts 1 fitted module at full need: Mimir's bundled item data has no skill-reduction data for them."
            )
        );
        assert_eq!(
            cpu_unreduced_line(2).as_deref(),
            Some("CPU counts 2 fitted modules at full need: Mimir's bundled item data has no skill-reduction data for them.")
        );
        assert_eq!(power_grid_unreduced_line(0), None);
        assert_eq!(
            power_grid_unreduced_line(1).as_deref(),
            Some("Power grid counts 1 fitted module at full need: Mimir's bundled item data has no skill-reduction data for them.")
        );
        assert_eq!(
            power_grid_unreduced_line(2).as_deref(),
            Some("Power grid counts 2 fitted modules at full need: Mimir's bundled item data has no skill-reduction data for them.")
        );
    }

    // Before-reductions lines on the sample fit at both weapon
    // skills level 5 (fitting need reductions design sections 8-9):
    // real bundled catalogue through the pure function, so the
    // reduced `used` beside the base figure is pinned, not
    // hand-typed. 107.25 renders `107.3`, half away from zero.
    #[test]
    fn sample_fit_before_reduction_lines_match_the_locked_story() {
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let synth = match parse_eft(DEMO_SAMPLE_EFT, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        let levels = ResourceSkillLevels {
            cpu_management: 0,
            power_grid_management: 0,
            weapon_upgrades: 5,
            advanced_weapon_upgrades: 5,
            energy_grid_upgrades: 0,
            electronics_upgrades: 0,
            shield_upgrades: 0,
        };
        let (cpu, power) = match fitting_resources_with_skills(&synth, &catalogue, Some(levels)) {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("sample must have ship output"),
        };
        assert_eq!(
            resource_line("CPU", &cpu, "tf"),
            "CPU: 107.3 tf of 130.0 tf used (22.8 tf left)"
        );
        assert_eq!(
            resource_line("Power grid", &power, "MW"),
            "Power grid: 29.8 MW of 41.0 MW used (11.2 MW left)"
        );
        assert_eq!(
            base_need_line("CPU", &cpu, "tf"),
            "CPU need before skill reductions: 114.0 tf."
        );
        assert_eq!(
            base_need_line("Power grid", &power, "MW"),
            "Power grid need before skill reductions: 31.0 MW."
        );
        assert_eq!(cpu.unreduced_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        assert_eq!(cpu_unreduced_line(cpu.unreduced_modules), None);
        assert_eq!(power_grid_unreduced_line(power.unreduced_modules), None);
    }

    // Unreduced lines from a labelled synthetic catalogue: the
    // shipped catalogue always carries complete filter data, so
    // the count is unreachable on real data. One module without
    // filter keys counts at full need with an unreduced line in
    // each dimension; one module with no needs at all is
    // excluded, never unreduced — both disclosed in one render.
    #[test]
    fn synthetic_unreduced_and_excluded_lines_coexist() {
        use crate::esi::models::FittingItem;
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0},
                {"typeId":9001,"typeName":"Unproven Mod","categoryId":7,"slotEffects":[11],"cpu":10.0,"power":5.0},
                {"typeId":9002,"typeName":"No Needs Mod","categoryId":7,"slotEffects":[11]}]}"#,
        )
        .expect("fixture catalogue parses");
        let item = |flag: &str, type_id: i64| FittingItem {
            flag: flag.to_string(),
            quantity: 1,
            type_id,
        };
        let fitting = CharacterFitting {
            fitting_id: 1,
            name: "synthetic".to_string(),
            description: None,
            ship_type_id: 587,
            items: vec![item("LoSlot0", 9001), item("LoSlot1", 9002)],
        };
        let levels = ResourceSkillLevels {
            cpu_management: 0,
            power_grid_management: 0,
            weapon_upgrades: 5,
            advanced_weapon_upgrades: 5,
            energy_grid_upgrades: 0,
            electronics_upgrades: 0,
            shield_upgrades: 0,
        };
        let (cpu, power) = match fitting_resources_with_skills(&fitting, &catalogue, Some(levels)) {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("synthetic fit must have ship output"),
        };
        // The unproven module counts at full need in both sums.
        assert_eq!(cpu.used, 10.0);
        assert_eq!(cpu.base_used, 10.0);
        assert_eq!(power.used, 5.0);
        assert_eq!(power.base_used, 5.0);
        assert_eq!(cpu.excluded_modules, 1);
        assert_eq!(power.excluded_modules, 1);
        assert_eq!(cpu.unreduced_modules, 1);
        assert_eq!(power.unreduced_modules, 1);
        assert_eq!(
            cpu_excluded_line(cpu.excluded_modules).as_deref(),
            Some(
                "CPU does not count 1 fitted module with no CPU data in Mimir's bundled item data."
            )
        );
        assert_eq!(
            cpu_unreduced_line(cpu.unreduced_modules).as_deref(),
            Some(
                "CPU counts 1 fitted module at full need: Mimir's bundled item data has no skill-reduction data for them."
            )
        );
        assert_eq!(
            power_grid_unreduced_line(power.unreduced_modules).as_deref(),
            Some(
                "Power grid counts 1 fitted module at full need: Mimir's bundled item data has no skill-reduction data for them."
            )
        );
    }

    // Applied demo story (fitting skill resources design section 5):
    // levels come from the real demo skill fixture through
    // `resource_skill_levels`, outputs through the pure function,
    // strings through `resource_line` and `skill_line`, so fixture,
    // catalogue, or rounding drift fails here.
    #[test]
    fn demo_fixture_applied_resources_match_the_locked_demo_story() {
        use crate::demo::data::{DEMO_FITTINGS_JSON, DEMO_SKILLQUEUE_JSON};
        use crate::esi::models::CharacterSkills;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        #[derive(Debug, serde::Deserialize)]
        struct DemoSkillEntry {
            skills: CharacterSkills,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let skills: HashMap<String, DemoSkillEntry> =
            serde_json::from_str(DEMO_SKILLQUEUE_JSON).expect("demo skill fixture parses");
        let aria = skills
            .get("90000001")
            .unwrap_or_else(|| panic!("aria skills present"));
        let marcus = skills
            .get("90000002")
            .unwrap_or_else(|| panic!("marcus skills present"));
        let aria_levels = resource_skill_levels(&aria.skills);
        let marcus_levels = resource_skill_levels(&marcus.skills);
        // The split fixture is unchanged: Aria has 3413 L5 only,
        // Marcus has 3426 L5 only.
        // Mechanical literal extension for the five
        // need-reduction fields (design section 6): all zero
        // here; assertions unchanged.
        assert_eq!(
            aria_levels,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 5,
                weapon_upgrades: 0,
                advanced_weapon_upgrades: 0,
                energy_grid_upgrades: 0,
                electronics_upgrades: 0,
                shield_upgrades: 0
            }
        );
        assert_eq!(
            marcus_levels,
            ResourceSkillLevels {
                cpu_management: 5,
                power_grid_management: 0,
                weapon_upgrades: 0,
                advanced_weapon_upgrades: 0,
                energy_grid_upgrades: 0,
                electronics_upgrades: 0,
                shield_upgrades: 0
            }
        );

        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let cpu_name = sde.skill_name_quiet(CPU_MANAGEMENT_SKILL_ID);
        let pg_name = sde.skill_name_quiet(POWER_GRID_MANAGEMENT_SKILL_ID);
        // Need-reduction names for the level-0 lines below (design
        // section 8 demo story). Neither demo character has any of
        // the five skills, so every reduction line is level 0 and
        // every before-reductions figure equals its used figure.
        let weapon_name = sde.skill_name_quiet(WEAPON_UPGRADES_SKILL_ID);
        let advanced_name = sde.skill_name_quiet(ADVANCED_WEAPON_UPGRADES_SKILL_ID);
        let grid_name = sde.skill_name_quiet(ENERGY_GRID_UPGRADES_SKILL_ID);
        let electronics_name = sde.skill_name_quiet(ELECTRONICS_UPGRADES_SKILL_ID);
        let shield_name = sde.skill_name_quiet(SHIELD_UPGRADES_SKILL_ID);
        // Aria's Gunnery (3300) at trained 4 is a filter skill,
        // not a source skill: it reduces nothing and is part of
        // the locked demo story, not a bug.
        let aria_gunnery = aria
            .skills
            .skills
            .iter()
            .find(|skill| skill.skill_id == 3300)
            .unwrap_or_else(|| panic!("aria Gunnery present"));
        assert_eq!(aria_gunnery.trained_skill_level, 4);

        // Demo Brawler (Aria, PG L5 only): CPU stays base, PG scales
        // to 51.25, rendered half away from zero as 51.3.
        let brawler = match fitting_resources_with_skills(
            &find("Demo Brawler"),
            &catalogue,
            Some(aria_levels),
        ) {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("Demo Brawler must have ship output"),
        };
        assert_eq!(
            resource_line("CPU", &brawler.0, "tf"),
            "CPU: 84.0 tf of 130.0 tf used (46.0 tf left)"
        );
        assert_eq!(
            resource_line("Power grid", &brawler.1, "MW"),
            "Power grid: 3.0 MW of 51.3 MW used (48.3 MW left)"
        );
        assert_eq!(brawler.0.excluded_modules, 2);
        assert_eq!(brawler.1.excluded_modules, 2);
        assert_eq!(
            skill_line("CPU output", &cpu_name, aria_levels.cpu_management),
            "CPU output includes no bonus: CPU Management is level 0."
        );
        assert_eq!(
            skill_line(
                "Power grid output",
                &pg_name,
                aria_levels.power_grid_management
            ),
            "Power grid output includes Power Grid Management level 5 (+25%)."
        );
        // Demo story (need reductions design section 8): before
        // figures equal used, all five lines level 0, nothing
        // unreduced — Aria's Gunnery 4 reduces nothing.
        assert_eq!(brawler.0.base_used, brawler.0.used);
        assert_eq!(brawler.1.base_used, brawler.1.used);
        assert_eq!(brawler.0.unreduced_modules, 0);
        assert_eq!(brawler.1.unreduced_modules, 0);
        assert_eq!(
            base_need_line("CPU", &brawler.0, "tf"),
            "CPU need before skill reductions: 84.0 tf."
        );
        assert_eq!(
            base_need_line("Power grid", &brawler.1, "MW"),
            "Power grid need before skill reductions: 3.0 MW."
        );
        assert_eq!(
            need_reduction_line(
                "CPU need of matching modules",
                &weapon_name,
                aria_levels.weapon_upgrades,
                5
            ),
            "CPU need of matching modules includes no reduction: Weapon Upgrades is level 0."
        );
        assert_eq!(
            need_reduction_line(
                "CPU need of matching modules",
                &grid_name,
                aria_levels.energy_grid_upgrades,
                5
            ),
            "CPU need of matching modules includes no reduction: Energy Grid Upgrades is level 0."
        );
        assert_eq!(
            need_reduction_line(
                "CPU need of matching modules",
                &electronics_name,
                aria_levels.electronics_upgrades,
                5
            ),
            "CPU need of matching modules includes no reduction: Electronics Upgrades is level 0."
        );
        assert_eq!(
            need_reduction_line(
                "Power grid need of matching modules",
                &advanced_name,
                aria_levels.advanced_weapon_upgrades,
                2
            ),
            "Power grid need of matching modules includes no reduction: Advanced Weapon Upgrades is level 0."
        );
        assert_eq!(
            need_reduction_line(
                "Power grid need of matching modules",
                &shield_name,
                aria_levels.shield_upgrades,
                5
            ),
            "Power grid need of matching modules includes no reduction: Shield Upgrades is level 0."
        );

        // Mission Runner (Aria).
        let mission = match fitting_resources_with_skills(
            &find("Mission Runner"),
            &catalogue,
            Some(aria_levels),
        ) {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("Mission Runner must have ship output"),
        };
        assert_eq!(
            resource_line("CPU", &mission.0, "tf"),
            "CPU: 30.0 tf of 130.0 tf used (100.0 tf left)"
        );
        assert_eq!(
            resource_line("Power grid", &mission.1, "MW"),
            "Power grid: 1.0 MW of 51.3 MW used (50.3 MW left)"
        );
        assert_eq!(mission.0.excluded_modules, 1);
        assert_eq!(mission.1.excluded_modules, 1);
        assert_eq!(mission.0.base_used, mission.0.used);
        assert_eq!(mission.1.base_used, mission.1.used);
        assert_eq!(
            base_need_line("CPU", &mission.0, "tf"),
            "CPU need before skill reductions: 30.0 tf."
        );
        assert_eq!(
            base_need_line("Power grid", &mission.1, "MW"),
            "Power grid need before skill reductions: 1.0 MW."
        );

        // Demo Runner (Marcus, CPU L5 only): CPU scales to 175.0,
        // PG stays base.
        let runner = match fitting_resources_with_skills(
            &find("Demo Runner"),
            &catalogue,
            Some(marcus_levels),
        ) {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("Demo Runner must have ship output"),
        };
        assert_eq!(
            resource_line("CPU", &runner.0, "tf"),
            "CPU: 57.0 tf of 175.0 tf used (118.0 tf left)"
        );
        assert_eq!(
            resource_line("Power grid", &runner.1, "MW"),
            "Power grid: 2.0 MW of 67.0 MW used (65.0 MW left)"
        );
        assert_eq!(runner.0.excluded_modules, 1);
        assert_eq!(runner.1.excluded_modules, 1);
        assert_eq!(
            skill_line("CPU output", &cpu_name, marcus_levels.cpu_management),
            "CPU output includes CPU Management level 5 (+25%)."
        );
        assert_eq!(
            skill_line(
                "Power grid output",
                &pg_name,
                marcus_levels.power_grid_management
            ),
            "Power grid output includes no bonus: Power Grid Management is level 0."
        );
        assert_eq!(runner.0.base_used, runner.0.used);
        assert_eq!(runner.1.base_used, runner.1.used);
        assert_eq!(runner.0.unreduced_modules, 0);
        assert_eq!(runner.1.unreduced_modules, 0);
        assert_eq!(
            base_need_line("CPU", &runner.0, "tf"),
            "CPU need before skill reductions: 57.0 tf."
        );
        assert_eq!(
            base_need_line("Power grid", &runner.1, "MW"),
            "Power grid need before skill reductions: 2.0 MW."
        );
        assert_eq!(
            need_reduction_line(
                "CPU need of matching modules",
                &weapon_name,
                marcus_levels.weapon_upgrades,
                5
            ),
            "CPU need of matching modules includes no reduction: Weapon Upgrades is level 0."
        );
        assert_eq!(
            need_reduction_line(
                "Power grid need of matching modules",
                &advanced_name,
                marcus_levels.advanced_weapon_upgrades,
                2
            ),
            "Power grid need of matching modules includes no reduction: Advanced Weapon Upgrades is level 0."
        );
        assert_eq!(
            need_reduction_line(
                "Power grid need of matching modules",
                &shield_name,
                marcus_levels.shield_upgrades,
                5
            ),
            "Power grid need of matching modules includes no reduction: Shield Upgrades is level 0."
        );

        // Sample import under both importers.
        let synth = match parse_eft(DEMO_SAMPLE_EFT, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        let aria_sample = match fitting_resources_with_skills(&synth, &catalogue, Some(aria_levels))
        {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("sample must have ship output"),
        };
        assert_eq!(
            resource_line("CPU", &aria_sample.0, "tf"),
            "CPU: 114.0 tf of 130.0 tf used (16.0 tf left)"
        );
        assert_eq!(
            resource_line("Power grid", &aria_sample.1, "MW"),
            "Power grid: 31.0 MW of 51.3 MW used (20.3 MW left)"
        );
        assert_eq!(aria_sample.0.base_used, aria_sample.0.used);
        assert_eq!(aria_sample.1.base_used, aria_sample.1.used);
        assert_eq!(
            base_need_line("CPU", &aria_sample.0, "tf"),
            "CPU need before skill reductions: 114.0 tf."
        );
        assert_eq!(
            base_need_line("Power grid", &aria_sample.1, "MW"),
            "Power grid need before skill reductions: 31.0 MW."
        );
        let marcus_sample =
            match fitting_resources_with_skills(&synth, &catalogue, Some(marcus_levels)) {
                FittingResources::Available { cpu, power } => (cpu, power),
                FittingResources::ShipNoOutput => panic!("sample must have ship output"),
            };
        assert_eq!(
            resource_line("CPU", &marcus_sample.0, "tf"),
            "CPU: 114.0 tf of 162.5 tf used (48.5 tf left)"
        );
        assert_eq!(
            resource_line("Power grid", &marcus_sample.1, "MW"),
            "Power grid: 31.0 MW of 41.0 MW used (10.0 MW left)"
        );
        assert_eq!(marcus_sample.0.base_used, marcus_sample.0.used);
        assert_eq!(marcus_sample.1.base_used, marcus_sample.1.used);
        assert_eq!(
            base_need_line("CPU", &marcus_sample.0, "tf"),
            "CPU need before skill reductions: 114.0 tf."
        );
        assert_eq!(
            base_need_line("Power grid", &marcus_sample.1, "MW"),
            "Power grid need before skill reductions: 31.0 MW."
        );
    }

    // Ship base values (ship base stats design section 8): the
    // locked five-line blocks, built from real `ship_base_stats`
    // results over the bundled catalogue. Oracle values read from
    // `scripts/sde/dgmTypeAttributes.csv.bz2` (valueInt None,
    // valueFloat shown): Rifter 587: 263 450.0, 265 450.0, 9
    // 350.0, 482 250.0, 37 365.0. Punisher 597: 350.0, 500.0,
    // 450.0, 400.0, 355.0.
    fn ship_stats_lines_for(catalogue: &FittingTypes, ship_type_id: i64) -> Vec<String> {
        let fitting = CharacterFitting {
            fitting_id: 1,
            name: "pin".to_string(),
            description: None,
            ship_type_id,
            items: vec![],
        };
        match ship_base_stats(&fitting, catalogue) {
            ShipBaseStatsOutcome::Available(stats) => ship_base_stat_lines(&stats),
            ShipBaseStatsOutcome::Unavailable => {
                panic!("ship {ship_type_id} must have base stats")
            }
        }
    }

    #[test]
    fn ship_base_stat_lines_match_the_locked_templates() {
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        assert_eq!(
            ship_stats_lines_for(&catalogue, 587),
            [
                "Shield: 450.0 HP",
                "Armor: 450.0 HP",
                "Hull: 350.0 HP",
                "Capacitor capacity: 250.0 GJ",
                "Max speed: 365.0 m/s",
                "Shield recharge: 625.0 s",
                "Capacitor recharge: 125.0 s",
                // 2.5 * 450.0 / 625.0 = 1.8 HP/s; 2.5 * 250.0 / 125.0 = 5.0 GJ/s.
                "Shield peak recharge: 1.8 HP/s",
                "Capacitor peak recharge: 5.0 GJ/s",
            ]
        );
        assert_eq!(
            ship_stats_lines_for(&catalogue, 597),
            [
                "Shield: 350.0 HP",
                "Armor: 500.0 HP",
                "Hull: 450.0 HP",
                "Capacitor capacity: 400.0 GJ",
                "Max speed: 355.0 m/s",
                "Shield recharge: 625.0 s",
                "Capacitor recharge: 160.0 s",
                // 2.5 * 350.0 / 625.0 = 1.4 HP/s; 2.5 * 400.0 / 160.0
                // = 6.25 GJ/s, rendered 6.3 (half away from zero).
                "Shield peak recharge: 1.4 HP/s",
                "Capacitor peak recharge: 6.3 GJ/s",
            ]
        );
    }

    // Formatting pins (design section 8): thousands grouping,
    // catalogue magnitude, fractional values, and the one
    // lossy display rounding. Raven 638 shield 7700.0, Komodo
    // 45649 shield 950000.0, Echelon 3532 capacitor 187.5,
    // Helios 11172 capacitor 218.75 (exact in the API, 218.8
    // GJ on screen), Mekubal 78333 velocity 322.3.
    #[test]
    fn ship_base_stat_formatting_pins() {
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        assert_eq!(
            ship_stats_lines_for(&catalogue, 638)[0],
            "Shield: 7,700.0 HP"
        );
        assert_eq!(
            ship_stats_lines_for(&catalogue, 45649)[0],
            "Shield: 950,000.0 HP"
        );
        assert_eq!(
            ship_stats_lines_for(&catalogue, 3532)[3],
            "Capacitor capacity: 187.5 GJ"
        );
        assert_eq!(
            ship_stats_lines_for(&catalogue, 11172)[3],
            "Capacitor capacity: 218.8 GJ"
        );
        assert_eq!(
            ship_stats_lines_for(&catalogue, 78333)[4],
            "Max speed: 322.3 m/s"
        );
    }

    // Absent versus zero (fixture catalogue; shipped data has no
    // ship with a missing stat): a present 0.0 renders, an absent
    // stat produces no line at all.
    #[test]
    fn ship_base_stat_present_zero_renders_and_absent_omits() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"armorHP":0.0,"hp":350.0,"capacitorCapacity":250.0,"maxVelocity":365.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let lines = ship_stats_lines_for(&catalogue, 42);
        assert_eq!(
            lines,
            [
                "Armor: 0.0 HP",
                "Hull: 350.0 HP",
                "Capacitor capacity: 250.0 GJ",
                "Max speed: 365.0 m/s",
            ]
        );
        assert!(
            lines.iter().all(|line| !line.starts_with("Shield")),
            "absent shield must produce no line: {lines:?}"
        );
    }

    // Peak absence matrix at the line level (peak design
    // section 7; fixture catalogues in the style above). Each
    // peak needs both its capacity and its recharge duration:
    // capacity without recharge shows the capacity line and no
    // peak; recharge without capacity shows the duration line
    // and no peak; a present-zero capacity with a positive
    // recharge renders the honest 0.0 peak line; a 0.0 recharge
    // renders the 0.0 s duration line (unchanged #581
    // behaviour) and no peak line. Catalogue recharge keys are
    // milliseconds (shieldRechargeRate, rechargeRate).
    #[test]
    fn ship_base_peak_lines_absence_matrix() {
        let no_peaks = |lines: &Vec<String>| {
            assert!(
                lines.iter().all(|line| !line.contains("peak recharge")),
                "no peak line without complete inputs: {lines:?}"
            );
        };

        // Capacities present, recharge attributes absent.
        let capacities_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Capacities Only","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"capacitorCapacity":250.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let lines = ship_stats_lines_for(&capacities_only, 42);
        assert_eq!(lines, ["Shield: 450.0 HP", "Capacitor capacity: 250.0 GJ"]);
        no_peaks(&lines);

        // Recharge durations present, capacities absent.
        let recharges_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Recharges Only","categoryId":6,"slotEffects":[],
                 "shieldRechargeRate":625000.0,"rechargeRate":125000.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let lines = ship_stats_lines_for(&recharges_only, 42);
        assert_eq!(
            lines,
            ["Shield recharge: 625.0 s", "Capacitor recharge: 125.0 s"]
        );
        no_peaks(&lines);

        // Present-zero capacities with positive recharges: honest
        // 0.0 peak lines (2.5 * 0 / t is exactly 0).
        let zero_capacities = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Zero Capacities","categoryId":6,"slotEffects":[],
                 "shieldCapacity":0.0,"shieldRechargeRate":625000.0,
                 "capacitorCapacity":0.0,"rechargeRate":125000.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let lines = ship_stats_lines_for(&zero_capacities, 42);
        assert_eq!(
            lines,
            [
                "Shield: 0.0 HP",
                "Capacitor capacity: 0.0 GJ",
                "Shield recharge: 625.0 s",
                "Capacitor recharge: 125.0 s",
                "Shield peak recharge: 0.0 HP/s",
                "Capacitor peak recharge: 0.0 GJ/s",
            ]
        );

        // Zero recharges: duration lines render 0.0 s, no peak.
        let zero_recharges = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Zero Recharges","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"shieldRechargeRate":0.0,
                 "capacitorCapacity":250.0,"rechargeRate":0.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let lines = ship_stats_lines_for(&zero_recharges, 42);
        assert_eq!(
            lines,
            [
                "Shield: 450.0 HP",
                "Capacitor capacity: 250.0 GJ",
                "Shield recharge: 0.0 s",
                "Capacitor recharge: 0.0 s",
            ]
        );
        no_peaks(&lines);
    }

    #[test]
    fn ship_base_stats_unavailable_and_disclosure_wording() {
        assert_eq!(FITTINGS_SHIP_BASE_STATS_HEADING, "Ship (base values)");
        assert_eq!(
            FITTING_SHIP_BASE_STATS_NO_CATALOGUE,
            "Ship values unavailable: Mimir's bundled item data failed to load."
        );
        assert_eq!(
            FITTING_SHIP_BASE_STATS_NO_SHIP_DATA,
            "Ship values unavailable: Mimir's bundled item data has no base ship data for this fitting's ship."
        );
        assert_eq!(
            FITTING_SHIP_BASE_STATS_DISCLOSURE,
            "Base ship values from Mimir's bundled item data. Fitted modules, rigs, subsystems, skills, implants, and ship bonuses are not applied, so these numbers can differ from EVE."
        );
    }

    // Demo story (design section 7): Demo Brawler and Mission
    // Runner are both Rifter 587 and render identical blocks
    // despite their invented sample rows; Demo Runner is Punisher
    // 597. Built from the real demo fixture over the real
    // catalogue, so fixture or catalogue drift fails here.
    #[test]
    fn demo_fixture_ship_stats_match_the_locked_demo_story() {
        use crate::demo::data::DEMO_FITTINGS_JSON;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let lines_for = |fitting: &CharacterFitting| match ship_base_stats(fitting, &catalogue) {
            ShipBaseStatsOutcome::Available(stats) => ship_base_stat_lines(&stats),
            ShipBaseStatsOutcome::Unavailable => panic!("demo fitting must have base stats"),
        };

        let rifter_block = [
            "Shield: 450.0 HP",
            "Armor: 450.0 HP",
            "Hull: 350.0 HP",
            "Capacitor capacity: 250.0 GJ",
            "Max speed: 365.0 m/s",
            "Shield recharge: 625.0 s",
            "Capacitor recharge: 125.0 s",
            "Shield peak recharge: 1.8 HP/s",
            "Capacitor peak recharge: 5.0 GJ/s",
        ];
        assert_eq!(lines_for(&find("Demo Brawler")), rifter_block);
        assert_eq!(lines_for(&find("Mission Runner")), rifter_block);
        assert_eq!(
            lines_for(&find("Demo Runner")),
            [
                "Shield: 350.0 HP",
                "Armor: 500.0 HP",
                "Hull: 450.0 HP",
                "Capacitor capacity: 400.0 GJ",
                "Max speed: 355.0 m/s",
                "Shield recharge: 625.0 s",
                "Capacitor recharge: 160.0 s",
                "Shield peak recharge: 1.4 HP/s",
                "Capacitor peak recharge: 6.3 GJ/s",
            ]
        );

        // Imported path: the demo sample fit through the shared
        // synthesis seam yields the same Rifter block.
        let synth = match parse_eft(DEMO_SAMPLE_EFT, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        assert_eq!(lines_for(&synth), rifter_block);

        // The DNA sample lands on the same hull, so its block is
        // byte-identical too (stats key off the ship, not format).
        let synth_dna = match parse_import(DEMO_SAMPLE_DNA, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => {
                panic!("demo DNA sample must import, got {fatal:?}")
            }
        };
        assert_eq!(lines_for(&synth_dna), rifter_block);
    }

    #[test]
    fn cap_stability_wording_constants() {
        assert_eq!(FITTINGS_CAP_STABILITY_HEADING, "Capacitor (base values)");
        assert_eq!(
            FITTING_CAP_STABILITY_DISCLOSURE,
            "Assumes every counted module keeps cycling continuously. Base values from Mimir's bundled item data. Fitted modules, rigs, subsystems, skills, implants, and ship bonuses are not applied to the capacitor, recharge, or module use. Capacitor boosters and effects on other ships (such as energy neutralizers and remote repairers) are not modelled, so these numbers can differ from EVE."
        );
        assert_eq!(
            FITTING_CAP_STABILITY_NO_CATALOGUE,
            "Capacitor unavailable: Mimir's bundled item data failed to load."
        );
        assert_eq!(
            FITTING_CAP_STABILITY_NO_SHIP_DATA,
            "No capacitor data is available for this ship in Mimir's bundled item data."
        );
    }

    #[test]
    fn cap_stability_excluded_line_counts() {
        assert_eq!(cap_stability_excluded_line(0), None);
        assert_eq!(
            cap_stability_excluded_line(1).as_deref(),
            Some("1 fitted module is not counted because its base capacitor use is not in Mimir's bundled item data.")
        );
        assert_eq!(
            cap_stability_excluded_line(2).as_deref(),
            Some("2 fitted modules are not counted because their base capacitor use is not in Mimir's bundled item data.")
        );
    }

    #[test]
    fn cap_stability_lines_omit_none_figures() {
        // `None` use/peak lines are omitted — never rendered
        // as zeros. A literal with no figures renders only
        // the outcome line plus the excluded disclosure.
        let bare = FittingCapStability {
            outcome: CapStabilityOutcome::Stable { percent: 50.0 },
            total_use_per_sec: None,
            peak_recharge_per_sec: None,
            counted_modules: 0,
            excluded_modules: 3,
        };
        assert_eq!(
            cap_stability_lines(&bare),
            [
                "Stable at 50%",
                "3 fitted modules are not counted because their base capacitor use is not in Mimir's bundled item data.",
            ]
        );
        // `Unavailable` contributes no lines at all: the
        // renderer prints the fixed unavailable sentence
        // instead of the lines.
        let unavailable = FittingCapStability {
            outcome: CapStabilityOutcome::Unavailable,
            total_use_per_sec: None,
            peak_recharge_per_sec: None,
            counted_modules: 1,
            excluded_modules: 2,
        };
        assert!(cap_stability_lines(&unavailable).is_empty());
    }

    // Demo story (design section 7, verified by the pure
    // module's pins): Demo Brawler 1 (Rifter 587, 2× type
    // 2050), Mission Runner 2 (Rifter 587, no counted
    // drains), Demo Runner 10 (Punisher 597, 1× type 2050).
    // Built from the real demo fixture over the real
    // catalogue, so fixture or catalogue drift fails here.
    #[test]
    fn demo_fixture_cap_stability_match_the_locked_demo_story() {
        use crate::demo::data::DEMO_FITTINGS_JSON;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let lines_for = |fitting: &CharacterFitting| {
            cap_stability_lines(&fitting_cap_stability(fitting, &catalogue))
        };

        // 2 × (32.0 / 12.0) = 64.0 / 12.0 = 5.333... GJ/s
        // already exceeds the 5.0 GJ/s peak, so the event
        // simulation depletes at the failing activation,
        // 234.0 s exactly.
        assert_eq!(
            lines_for(&find("Demo Brawler")),
            [
                "Module capacitor use: 5.3 GJ/s",
                "Capacitor peak recharge: 5.0 GJ/s",
                "Depletes in about 234s",
                "5 fitted modules are not counted because their base capacitor use is not in Mimir's bundled item data.",
            ]
        );
        // No counted drains: 0.0 GJ/s and stable at 100%;
        // the excluded count keeps the line honest.
        assert_eq!(
            lines_for(&find("Mission Runner")),
            [
                "Module capacitor use: 0.0 GJ/s",
                "Capacitor peak recharge: 5.0 GJ/s",
                "Stable at 100%",
                "2 fitted modules are not counted because their base capacitor use is not in Mimir's bundled item data.",
            ]
        );
        // 32.0 / 12.0 = 2.666... GJ/s against the 6.25 GJ/s
        // peak; the port's stable percent 76.95496917307892
        // rounds to 77.
        assert_eq!(
            lines_for(&find("Demo Runner")),
            [
                "Module capacitor use: 2.7 GJ/s",
                "Capacitor peak recharge: 6.3 GJ/s",
                "Stable at 77%",
                "2 fitted modules are not counted because their base capacitor use is not in Mimir's bundled item data.",
            ]
        );

        // Imported path: the EFT oracle through the shared
        // synthesis seam. 40.0/6.0 + 22.0/10.0 + 6.0/5.0
        // = 6.666... + 2.2 + 1.2 = 10.066... GJ/s vs the
        // Rifter 5.0 GJ/s peak → depletes at 36.0 s exactly.
        let sample = concat!(
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
        let synth = match parse_eft(sample, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => {
                panic!("sample EFT must import, got {fatal:?}")
            }
        };
        assert_eq!(
            lines_for(&synth),
            [
                "Module capacitor use: 10.1 GJ/s",
                "Capacitor peak recharge: 5.0 GJ/s",
                "Depletes in about 36s",
                "2 fitted modules are not counted because their base capacitor use is not in Mimir's bundled item data.",
            ]
        );

        // Surface symmetry (design section 4): the same
        // slot items through a saved fitting render the
        // identical block.
        let saved = CharacterFitting {
            fitting_id: 900000999,
            name: "Saved replica".to_string(),
            description: None,
            ship_type_id: synth.ship_type_id,
            items: synth.items.clone(),
        };
        assert_eq!(lines_for(&saved), lines_for(&synth));
    }

    #[test]
    fn active_repair_wording_constants() {
        assert_eq!(
            FITTINGS_ACTIVE_REPAIR_HEADING,
            "Active repair (base values)"
        );
        assert_eq!(
            FITTING_ACTIVE_REPAIR_DISCLOSURE,
            "Assumes every counted repair module keeps cycling continuously. Base values from Mimir's bundled item data: base hit points restored per cycle at base cycle times, with resistances, skills, implants, and bonuses from modules, rigs, subsystems, and the ship itself not applied — raw hit points per second, not effective hit points per second. Ancillary repair modules are counted at their unloaded repair amount: loaded charges (such as Nanite Repair Paste) and reload time are not modelled, so an ancillary module's rate is its rate while cycling, not a long-run average. Remote repairers, which repair other ships, are not counted. Repair modules' capacitor use is counted in the Capacitor block above; this block does not model whether the capacitor can sustain continuous cycling. Passive shield recharge is shown as shield peak recharge in the Ship block and is not included here, so these numbers can differ from EVE."
        );
        assert_eq!(
            FITTING_ACTIVE_REPAIR_NO_CATALOGUE,
            "Active repair unavailable: Mimir's bundled item data failed to load."
        );
    }

    #[test]
    fn active_repair_excluded_line_counts() {
        assert_eq!(active_repair_excluded_line(0), None);
        assert_eq!(
            active_repair_excluded_line(1).as_deref(),
            Some("1 fitted module is not counted because its base repair data is not in Mimir's bundled item data.")
        );
        assert_eq!(
            active_repair_excluded_line(2).as_deref(),
            Some("2 fitted modules are not counted because their base repair data is not in Mimir's bundled item data.")
        );
    }

    #[test]
    fn active_repair_lines_omit_none_layers() {
        // `None` layers are omitted — never rendered as zeros
        // or placeholder words. Only the missing layer drops
        // out; the others keep their locked order.
        let partial = FittingActiveRepair {
            shield_hp_per_sec: None,
            armor_hp_per_sec: Some(920.0 / 15.0),
            hull_hp_per_sec: Some(30.0 / 24.0),
            counted_modules: 2,
            excluded_modules: 0,
        };
        assert_eq!(
            active_repair_lines(&partial),
            ["Armor repair: 61.3 HP/s", "Hull repair: 1.3 HP/s",]
        );
        // Known zeros render like any other value: an empty
        // sum over proven data is a stated zero, not an
        // absent line.
        let zeros = FittingActiveRepair {
            shield_hp_per_sec: Some(0.0),
            armor_hp_per_sec: Some(0.0),
            hull_hp_per_sec: Some(0.0),
            counted_modules: 0,
            excluded_modules: 1,
        };
        assert_eq!(
            active_repair_lines(&zeros),
            [
                "Shield boost: 0.0 HP/s",
                "Armor repair: 0.0 HP/s",
                "Hull repair: 0.0 HP/s",
                "1 fitted module is not counted because its base repair data is not in Mimir's bundled item data.",
            ]
        );
    }

    // Demo story (design section 7, verified by the pure
    // module's pins): no shipped demo fitting carries a
    // self-repair module, so every demo block is three known
    // zeros, plus Demo Brawler's one excluded unknown type.
    // Built from the real demo fixture over the real
    // catalogue, so fixture or catalogue drift fails here.
    #[test]
    fn demo_fixture_active_repair_match_the_locked_demo_story() {
        use crate::demo::data::DEMO_FITTINGS_JSON;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let lines_for = |fitting: &CharacterFitting| {
            active_repair_lines(&fitting_active_repair(fitting, &catalogue))
        };

        // Demo Brawler's rig slot carries type 1535, absent
        // from the catalogue: the singular excluded sentence
        // keeps the three zeros honest.
        assert_eq!(
            lines_for(&find("Demo Brawler")),
            [
                "Shield boost: 0.0 HP/s",
                "Armor repair: 0.0 HP/s",
                "Hull repair: 0.0 HP/s",
                "1 fitted module is not counted because its base repair data is not in Mimir's bundled item data.",
            ]
        );
        // Mission Runner and Demo Runner carry only known
        // non-repairers: three zeros, no excluded sentence.
        for name in ["Mission Runner", "Demo Runner"] {
            assert_eq!(
                lines_for(&find(name)),
                [
                    "Shield boost: 0.0 HP/s",
                    "Armor repair: 0.0 HP/s",
                    "Hull repair: 0.0 HP/s",
                ]
            );
        }
    }

    // Non-demo one-decimal renderings (design section 7
    // hand oracles over the bundled catalogue): each real
    // repairer alone on a Rifter shows the formatter's
    // one-decimal rounding with the other two layers at a
    // stated zero.
    #[test]
    fn active_repair_renders_real_type_rates() {
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let lines_for = |type_id: i64, flag: &str| {
            let fitting = fitting_with_items(vec![item(flag, 1, type_id)]);
            active_repair_lines(&fitting_active_repair(&fitting, &catalogue))
        };
        // 920.0 / 15.0 = 61.333... → 61.3 (E2.1).
        assert_eq!(
            lines_for(3540, "LoSlot0"),
            [
                "Shield boost: 0.0 HP/s",
                "Armor repair: 61.3 HP/s",
                "Hull repair: 0.0 HP/s",
            ]
        );
        // 104.0 / 3.0 = 34.666... → 34.7 (E2.2).
        assert_eq!(
            lines_for(10850, "MedSlot0"),
            [
                "Shield boost: 34.7 HP/s",
                "Armor repair: 0.0 HP/s",
                "Hull repair: 0.0 HP/s",
            ]
        );
        // 30.0 / 24.0 = 1.25 exactly → 1.3.
        assert_eq!(
            lines_for(2355, "MedSlot1"),
            [
                "Shield boost: 0.0 HP/s",
                "Armor repair: 0.0 HP/s",
                "Hull repair: 1.3 HP/s",
            ]
        );
        // 92.0 / 6.0 = 15.333... → 15.3.
        assert_eq!(
            lines_for(1183, "LoSlot1"),
            [
                "Shield boost: 0.0 HP/s",
                "Armor repair: 15.3 HP/s",
                "Hull repair: 0.0 HP/s",
            ]
        );
        // 52.0 / 2.0 = 26.0 exactly: the reload-ignored pin.
        assert_eq!(
            lines_for(32774, "MedSlot2"),
            [
                "Shield boost: 26.0 HP/s",
                "Armor repair: 0.0 HP/s",
                "Hull repair: 0.0 HP/s",
            ]
        );
        // 52.0 / 6.0 = 8.666... → 8.7 dry: the loaded 26.0
        // is never an expectation here.
        assert_eq!(
            lines_for(33076, "LoSlot2"),
            [
                "Shield boost: 0.0 HP/s",
                "Armor repair: 8.7 HP/s",
                "Hull repair: 0.0 HP/s",
            ]
        );
    }

    // Plural excluded form (two excluded units) and the
    // empty fitting (three stated zeros), per design
    // section 8. The 30.0 / 24.0 = 1.25 exactness pin
    // lives in the real-rate renderings above.
    #[test]
    fn active_repair_plural_excluded_and_empty_fitting() {
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        // Two rows of a catalogue-absent type render the
        // plural excluded sentence (quantity units, the
        // resources precedent).
        let fitting =
            fitting_with_items(vec![item("RigSlot0", 1, 1535), item("RigSlot1", 1, 1535)]);
        assert_eq!(
            active_repair_lines(&fitting_active_repair(&fitting, &catalogue)),
            [
                "Shield boost: 0.0 HP/s",
                "Armor repair: 0.0 HP/s",
                "Hull repair: 0.0 HP/s",
                "2 fitted modules are not counted because their base repair data is not in Mimir's bundled item data.",
            ]
        );
        // An empty fitting still shows three stated zeros.
        let empty = fitting_with_items(Vec::new());
        assert_eq!(
            active_repair_lines(&fitting_active_repair(&empty, &catalogue)),
            [
                "Shield boost: 0.0 HP/s",
                "Armor repair: 0.0 HP/s",
                "Hull repair: 0.0 HP/s",
            ]
        );
    }

    // Surface symmetry (design section 8): an EFT import
    // listing Nanite Repair Paste after its ancillary
    // repairer renders the same dry number as the saved
    // fitting carrying the synthesized items.
    #[test]
    fn active_repair_imported_and_saved_surfaces_match() {
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let sample = concat!(
            "[Rifter, Sample Brawler]\n",
            "Damage Control II\n",
            "Small Ancillary Armor Repairer, Nanite Repair Paste\n",
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
        let synth = match parse_eft(sample, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => {
                panic!("sample EFT must import, got {fatal:?}")
            }
        };
        let lines_for = |fitting: &CharacterFitting| {
            active_repair_lines(&fitting_active_repair(fitting, &catalogue))
        };
        // The dry ancillary rate renders identically with
        // the paste charge listed: 52.0 / 6.0 = 8.666...
        // → 8.7, never the loaded 26.0.
        assert_eq!(
            lines_for(&synth),
            [
                "Shield boost: 0.0 HP/s",
                "Armor repair: 8.7 HP/s",
                "Hull repair: 0.0 HP/s",
            ]
        );
        // Surface symmetry: the same slot items through a
        // saved fitting render the identical block.
        let saved = CharacterFitting {
            fitting_id: 900000998,
            name: "Saved replica".to_string(),
            description: None,
            ship_type_id: synth.ship_type_id,
            items: synth.items.clone(),
        };
        assert_eq!(lines_for(&saved), lines_for(&synth));
    }

    // Ship base resistances (ship resistances design section 8):
    // the locked three-line blocks, built from real
    // `ship_resistances` results over the bundled catalogue.
    // Oracle resonance rows read from
    // `scripts/sde/dgmTypeAttributes.csv.bz2` (valueInt None,
    // valueFloat shown): Rifter 587: shield 1.0/0.8/0.6/0.5,
    // armor 0.4/0.65/0.75/0.9, hull 0.67 x4 (974-977 decoy rows
    // at 1.0 never emitted; hull 33.0% is the tripwire against a
    // wrong-set 0%). Punisher 597: shield 1.0/0.8/0.6/0.5,
    // armor 0.5/0.65/0.75/0.8, hull 0.67 x4. Mimir 32209:
    // armor 0.1/0.325/0.75/0.9. Percentages are (1 - resonance)
    // * 100 hand-derived, rendered at one decimal.
    fn ship_resistances_lines_for(catalogue: &FittingTypes, ship_type_id: i64) -> Vec<String> {
        let fitting = CharacterFitting {
            fitting_id: 1,
            name: "pin".to_string(),
            description: None,
            ship_type_id,
            items: vec![],
        };
        match ship_resistances(&fitting, catalogue) {
            ShipResistancesOutcome::Available(resistances) => ship_resistance_lines(&resistances),
            ShipResistancesOutcome::Unavailable => {
                panic!("ship {ship_type_id} must have base resistances")
            }
        }
    }

    #[test]
    fn ship_resistance_lines_match_the_locked_templates() {
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        assert_eq!(
            ship_resistances_lines_for(&catalogue, 587),
            [
                "Shield resistances: EM 0.0%, Thermal 20.0%, Kinetic 40.0%, Explosive 50.0%",
                "Armor resistances: EM 60.0%, Thermal 35.0%, Kinetic 25.0%, Explosive 10.0%",
                "Hull resistances: EM 33.0%, Thermal 33.0%, Kinetic 33.0%, Explosive 33.0%",
            ]
        );
        assert_eq!(
            ship_resistances_lines_for(&catalogue, 597),
            [
                "Shield resistances: EM 0.0%, Thermal 20.0%, Kinetic 40.0%, Explosive 50.0%",
                "Armor resistances: EM 50.0%, Thermal 35.0%, Kinetic 25.0%, Explosive 20.0%",
                "Hull resistances: EM 33.0%, Thermal 33.0%, Kinetic 33.0%, Explosive 33.0%",
            ]
        );
    }

    // Formatting pins (design section 8): the one-decimal picks
    // rounding, the exact one-decimal values, the signed render
    // for resonances above 1, and the inherited formatter guards.
    // Mimir 32209 armor thermal 67.5% renders exactly; Falcon
    // 11957 armor thermal 79.375% renders 79.4%; Legion 29986
    // armor kinetic 43.75% renders 43.8%; Nemesis 11377 armor
    // thermal 43.125% renders 43.1%; resonance 0.0 renders
    // 100.0%; resonances 1.1/7.0 render -10.0%/-600.0% through
    // the line helper, never clamped.
    #[test]
    fn ship_resistance_formatting_pins() {
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        assert_eq!(
            ship_resistances_lines_for(&catalogue, 32209)[1],
            "Armor resistances: EM 90.0%, Thermal 67.5%, Kinetic 25.0%, Explosive 10.0%"
        );
        assert!(
            ship_resistances_lines_for(&catalogue, 11957)[1].contains("Thermal 79.4%"),
            "Falcon armor thermal 79.375% rounds to 79.4%"
        );
        assert!(
            ship_resistances_lines_for(&catalogue, 29986)[1].contains("Kinetic 43.8%"),
            "Legion armor kinetic 43.75% rounds to 43.8%"
        );
        assert!(
            ship_resistances_lines_for(&catalogue, 11377)[1].contains("Thermal 43.1%"),
            "Nemesis armor thermal 43.125% rounds to 43.1%"
        );
        // Present 1.0 renders 0.0% (Rifter shield EM) and 0.67
        // renders 33.0% with float dust absorbed; both are in the
        // locked-template test above and repeated here as lines.
        assert_eq!(
            ship_resistances_lines_for(&catalogue, 587)[0],
            "Shield resistances: EM 0.0%, Thermal 20.0%, Kinetic 40.0%, Explosive 50.0%"
        );
        assert_eq!(
            ship_resistances_lines_for(&catalogue, 587)[2],
            "Hull resistances: EM 33.0%, Thermal 33.0%, Kinetic 33.0%, Explosive 33.0%"
        );
        // Signed render through the line helper (direct
        // percentages, the fixture path for 100.0% is in the
        // omission test): resonances above 1 render true
        // negatives, never clamped.
        let signed = ShipResistances {
            shield: ResistLayer {
                em: Some(100.0),
                thermal: Some(-10.0),
                kinetic: Some(-600.0),
                explosive: Some(0.0),
            },
            armor: ResistLayer {
                em: None,
                thermal: None,
                kinetic: None,
                explosive: None,
            },
            hull: ResistLayer {
                em: None,
                thermal: None,
                kinetic: None,
                explosive: None,
            },
        };
        assert_eq!(
            ship_resistance_lines(&signed),
            ["Shield resistances: EM 100.0%, Thermal -10.0%, Kinetic -600.0%, Explosive 0.0%"]
        );
        // Inherited guards through the one percent formatter.
        assert_eq!(widgets::format_fitting_percent(1_234.5), "1,234.5%");
        let huge = widgets::format_fitting_percent(30.0 * i64::MAX as f64);
        assert!(huge.ends_with(".0%"), "huge renders one decimal: {huge}");
        assert!(!huge.starts_with('-'), "positive stays positive: {huge}");
        assert_eq!(widgets::format_fitting_percent(f64::NAN), "0.0%");
        assert_eq!(widgets::format_fitting_percent(f64::INFINITY), "0.0%");
    }

    // Absent versus zero (fixture catalogue; shipped data has no
    // ship with a missing resistance): a present 1.0 renders
    // EM 0.0% and a present 0.0 renders 100.0%, absent segments
    // produce no segment at all, and an all-absent layer produces
    // no line.
    #[test]
    fn ship_resistance_present_zero_renders_and_absent_omits() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldEmDamageResonance":1.0,"shieldKineticDamageResonance":0.6,"shieldExplosiveDamageResonance":0.5,
                 "emDamageResonance":0.0,"thermalDamageResonance":0.67,"kineticDamageResonance":0.67,"explosiveDamageResonance":0.67}]}"#,
        )
        .expect("fixture catalogue parses");
        let lines = ship_resistances_lines_for(&catalogue, 42);
        assert_eq!(
            lines,
            [
                "Shield resistances: EM 0.0%, Kinetic 40.0%, Explosive 50.0%",
                "Hull resistances: EM 100.0%, Thermal 33.0%, Kinetic 33.0%, Explosive 33.0%",
            ]
        );
        assert!(
            lines[0].starts_with("Shield resistances: EM 0.0%"),
            "present 1.0 renders first: {lines:?}"
        );
        assert!(
            !lines[0].contains("Thermal"),
            "absent thermal must produce no segment: {lines:?}"
        );
        assert!(
            lines.iter().all(|line| !line.starts_with("Armor")),
            "all-absent armor must produce no line: {lines:?}"
        );
    }

    #[test]
    fn ship_resistances_unavailable_and_disclosure_wording() {
        assert_eq!(
            FITTINGS_SHIP_RESISTANCES_HEADING,
            "Ship resistances (base values)"
        );
        assert_eq!(
            FITTING_SHIP_RESISTANCES_NO_CATALOGUE,
            "Ship resistances unavailable: Mimir's bundled item data failed to load."
        );
        assert_eq!(
            FITTING_SHIP_RESISTANCES_NO_SHIP_DATA,
            "Ship resistances unavailable: Mimir's bundled item data has no resistance data for this fitting's ship."
        );
        assert_eq!(
            FITTING_SHIP_RESISTANCES_DISCLOSURE,
            "These are the bare hull's base resistances from Mimir's bundled item data. Fitted modules, rigs, subsystems, skills, implants, and ship bonuses are not applied, so these numbers can differ from EVE."
        );
    }

    // Demo story (ship resistances design section 7): Demo
    // Brawler and Mission Runner are both Rifter 587 and render
    // identical blocks despite their invented sample rows (the
    // 974-977 tripwire: a wrong-set implementation shows hull 0%
    // here instead of the locked 33%); Demo Runner is Punisher
    // 597. Built from the real demo fixture over the real
    // catalogue, so fixture or catalogue drift fails here.
    #[test]
    fn demo_fixture_ship_resistances_match_the_locked_demo_story() {
        use crate::demo::data::DEMO_FITTINGS_JSON;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let lines_for = |fitting: &CharacterFitting| match ship_resistances(fitting, &catalogue) {
            ShipResistancesOutcome::Available(resistances) => ship_resistance_lines(&resistances),
            ShipResistancesOutcome::Unavailable => {
                panic!("demo fitting must have base resistances")
            }
        };

        let rifter_block = [
            "Shield resistances: EM 0.0%, Thermal 20.0%, Kinetic 40.0%, Explosive 50.0%",
            "Armor resistances: EM 60.0%, Thermal 35.0%, Kinetic 25.0%, Explosive 10.0%",
            "Hull resistances: EM 33.0%, Thermal 33.0%, Kinetic 33.0%, Explosive 33.0%",
        ];
        assert_eq!(lines_for(&find("Demo Brawler")), rifter_block);
        assert_eq!(lines_for(&find("Mission Runner")), rifter_block);
        assert_eq!(
            lines_for(&find("Demo Runner")),
            [
                "Shield resistances: EM 0.0%, Thermal 20.0%, Kinetic 40.0%, Explosive 50.0%",
                "Armor resistances: EM 50.0%, Thermal 35.0%, Kinetic 25.0%, Explosive 20.0%",
                "Hull resistances: EM 33.0%, Thermal 33.0%, Kinetic 33.0%, Explosive 33.0%",
            ]
        );

        // Imported path: the demo sample fit through the shared
        // synthesis seam yields the same Rifter block.
        let synth = match parse_eft(DEMO_SAMPLE_EFT, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        assert_eq!(lines_for(&synth), rifter_block);

        // The DNA sample lands on the same hull, so its block is
        // byte-identical too (resistances key off the ship, not
        // format).
        let synth_dna = match parse_import(DEMO_SAMPLE_DNA, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => {
                panic!("demo DNA sample must import, got {fatal:?}")
            }
        };
        assert_eq!(lines_for(&synth_dna), rifter_block);
    }

    // Ship base effective hit points (ship base EHP design
    // section 8): the locked four-line blocks, built from real
    // `ship_base_ehp` results over the bundled catalogue. Oracle
    // rows read from the bundled catalogue: Rifter 587 hit points
    // 450/450/350; shield resonances 1.0/0.8/0.6/0.5, armor
    // 0.4/0.65/0.75/0.9, hull 0.67 x4. Punisher 597 hit points
    // 350/500/450; shield 1.0/0.8/0.6/0.5, armor 0.5/0.65/0.75/0.8,
    // hull 0.67 x4. Each denominator is 0.25*em + 0.25*thermal +
    // 0.25*kinetic + 0.25*explosive; each layer is HP / denominator;
    // the total is shield + armor + hull summed before rounding,
    // rendered at one decimal (design section 5).
    //   Rifter shield: denominator 0.725, 450 / 0.725 = 620.6896552
    //     renders 620.7 HP.
    //   Rifter armor: denominator 0.675, 450 / 0.675 = 666.6666667
    //     renders 666.7 HP.
    //   Rifter hull: denominator 0.67, 350 / 0.67 = 522.3880597
    //     renders 522.4 HP.
    //   Rifter total: 620.6896552 + 666.6666667 + 522.3880597
    //     = 1809.7443815 renders 1,809.7 HP (not 1809.8 — the
    //     rendered layers sum to 1809.8; the total is summed from
    //     unrounded values, design section 5, pinned as written).
    //   Punisher shield: denominator 0.725, 350 / 0.725 = 482.7586207
    //     renders 482.8 HP.
    //   Punisher armor: denominator 0.675, 500 / 0.675 = 740.7407407
    //     renders 740.7 HP.
    //   Punisher hull: denominator 0.67, 450 / 0.67 = 671.6417910
    //     renders 671.6 HP.
    //   Punisher total: 482.7586207 + 740.7407407 + 671.6417910
    //     = 1895.1411525 renders 1,895.1 HP.
    fn ship_base_ehp_lines_for(catalogue: &FittingTypes, ship_type_id: i64) -> Vec<String> {
        let fitting = CharacterFitting {
            fitting_id: 1,
            name: "pin".to_string(),
            description: None,
            ship_type_id,
            items: vec![],
        };
        match ship_base_ehp(&fitting, catalogue) {
            ShipBaseEhpOutcome::Available(ehp) => ship_base_ehp_lines(&ehp),
            ShipBaseEhpOutcome::Unavailable => {
                panic!("ship {ship_type_id} must have base effective hit points")
            }
        }
    }

    #[test]
    fn ship_base_ehp_lines_match_the_locked_templates() {
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        assert_eq!(
            ship_base_ehp_lines_for(&catalogue, 587),
            [
                "Shield EHP: 620.7 HP",
                "Armor EHP: 666.7 HP",
                "Hull EHP: 522.4 HP",
                "Total EHP: 1,809.7 HP",
            ]
        );
        assert_eq!(
            ship_base_ehp_lines_for(&catalogue, 597),
            [
                "Shield EHP: 482.8 HP",
                "Armor EHP: 740.7 HP",
                "Hull EHP: 671.6 HP",
                "Total EHP: 1,895.1 HP",
            ]
        );
    }

    // Formatting pins (design section 8): thousands grouping at
    // Raven scale and at capital scale, and the exact Legion
    // shield rendering. Raven 638: hit points 7700/6380/7040;
    // shield 1.0/0.8/0.6/0.5, armor 0.5/0.55/0.75/0.9, hull
    // 0.67 x4; total 10620.6896552 + 9451.8518519 + 10507.4626866
    // = 30580.0041936 renders 30,580.0 HP. Komodo 45649: hit
    // points 950000/450000/525000; shield 1.0/0.8/0.6/0.5,
    // armor 0.5/0.55/0.75/0.9, hull 0.67 x4; shield 950000 /
    // 0.725 = 1310344.8276 renders 1,310,344.8 HP; total
    // 1310344.8276 + 666666.6667 + 783582.0896 = 2760593.5839
    // renders 2,760,593.6 HP. Legion 29986: hit points
    // 1800/2900/1800; shield 1.0/0.8/0.45/0.25, denominator
    // 0.625 (binary-exact), shield 1800 / 0.625 = 2880.0 renders
    // 2,880.0 HP.
    #[test]
    fn ship_base_ehp_formatting_pins() {
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let raven = ship_base_ehp_lines_for(&catalogue, 638);
        assert_eq!(raven[3], "Total EHP: 30,580.0 HP");
        let komodo = ship_base_ehp_lines_for(&catalogue, 45649);
        assert_eq!(komodo[0], "Shield EHP: 1,310,344.8 HP");
        assert_eq!(komodo[3], "Total EHP: 2,760,593.6 HP");
        let legion = ship_base_ehp_lines_for(&catalogue, 29986);
        assert_eq!(legion[0], "Shield EHP: 2,880.0 HP");
    }

    // Present zero versus absent (fixture catalogue; shipped
    // data has no ship with a missing hit point or resonance):
    // a present 0.0 hit point value with complete resonances
    // renders 0.0 HP (0.0 / 1.0 = 0.0), an absent layer produces
    // no line at all. The fixture has shield 0.0 HP with shield
    // resonances 1.0 x4, armor 800 HP and hull 600 HP with 1.0
    // x4 resonances per layer, so armor is 800 / 1.0 = 800.0,
    // hull is 600 / 1.0 = 600.0, and the total is
    // 0.0 + 800.0 + 600.0 = 1400.0.
    #[test]
    fn ship_base_ehp_present_zero_renders_and_absent_omits() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "shieldCapacity":0.0,"armorHP":800.0,"hp":600.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":1.0,"shieldKineticDamageResonance":1.0,"shieldExplosiveDamageResonance":1.0,
                 "armorEmDamageResonance":1.0,"armorThermalDamageResonance":1.0,"armorKineticDamageResonance":1.0,"armorExplosiveDamageResonance":1.0,
                 "emDamageResonance":1.0,"thermalDamageResonance":1.0,"kineticDamageResonance":1.0,"explosiveDamageResonance":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let lines = ship_base_ehp_lines_for(&catalogue, 42);
        assert_eq!(
            lines,
            [
                "Shield EHP: 0.0 HP",
                "Armor EHP: 800.0 HP",
                "Hull EHP: 600.0 HP",
                "Total EHP: 1,400.0 HP",
            ]
        );
        assert_eq!(lines[0], "Shield EHP: 0.0 HP");
    }

    // Omission pins (fixture catalogues): a layer whose hit
    // points or any needed resonance is absent contributes no
    // line, and a partial block shows no total line. One
    // complete layer (shield 450 HP with shield resonances
    // 1.0 x4, so 450 / 1.0 = 450.0) produces exactly one line.
    // Two complete layers (shield 450 and armor 450, each with
    // 1.0 x4 resonances) produce exactly two lines and no total.
    #[test]
    fn ship_base_ehp_omission_pins() {
        let one_layer = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Shield Only","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":1.0,"shieldKineticDamageResonance":1.0,"shieldExplosiveDamageResonance":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let lines = ship_base_ehp_lines_for(&one_layer, 42);
        assert_eq!(lines, ["Shield EHP: 450.0 HP"]);
        assert!(
            lines.iter().all(|line| !line.starts_with("Armor")),
            "absent armor must produce no line: {lines:?}"
        );
        assert!(
            lines.iter().all(|line| !line.starts_with("Hull")),
            "absent hull must produce no line: {lines:?}"
        );
        assert!(
            lines.iter().all(|line| !line.starts_with("Total")),
            "partial block must show no total line: {lines:?}"
        );

        let two_layers = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Shield Armor","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,
                 "shieldEmDamageResonance":1.0,"shieldThermalDamageResonance":1.0,"shieldKineticDamageResonance":1.0,"shieldExplosiveDamageResonance":1.0,
                 "armorEmDamageResonance":1.0,"armorThermalDamageResonance":1.0,"armorKineticDamageResonance":1.0,"armorExplosiveDamageResonance":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let lines = ship_base_ehp_lines_for(&two_layers, 42);
        assert_eq!(lines, ["Shield EHP: 450.0 HP", "Armor EHP: 450.0 HP"]);
        assert!(
            lines.iter().all(|line| !line.starts_with("Total")),
            "two-layer block must show no total line: {lines:?}"
        );
    }

    #[test]
    fn ship_base_ehp_unavailable_and_disclosure_wording() {
        assert_eq!(
            FITTINGS_SHIP_BASE_EHP_HEADING,
            "Ship effective hit points (base values, omni 25/25/25/25)"
        );
        assert_eq!(
            FITTING_SHIP_BASE_EHP_NO_CATALOGUE,
            "Ship effective hit points unavailable: Mimir's bundled item data failed to load."
        );
        assert_eq!(
            FITTING_SHIP_BASE_EHP_NO_SHIP_DATA,
            "Ship effective hit points unavailable: Mimir's bundled item data has no complete base hit point and resistance data for this fitting's ship."
        );
        assert_eq!(
            FITTING_SHIP_BASE_EHP_DISCLOSURE,
            "These are the bare hull's base effective hit points (EHP) from Mimir's bundled item data, against omni damage: equal quarters (25% each) of EM, thermal, kinetic, and explosive damage. Fitted modules, rigs, subsystems, skills, implants, and ship bonuses are not applied, and a different damage mix would give different numbers, so these numbers can differ from EVE."
        );
    }

    // Demo story (ship base EHP design section 7): Demo Brawler
    // and Mission Runner are both Rifter 587 and render
    // identical blocks despite their invented sample rows (the
    // 974-977 tripwire: a wrong-set implementation shows hull
    // EHP 350.0 here instead of 522.4); Demo Runner is Punisher
    // 597. Built from the real demo fixture over the real
    // catalogue, so fixture or catalogue drift fails here.
    // Divisions as pinned above: Rifter 450/0.725, 450/0.675,
    // 350/0.67, total 1809.7443815; Punisher 350/0.725,
    // 500/0.675, 450/0.67, total 1895.1411525.
    #[test]
    fn demo_fixture_ship_base_ehp_match_the_locked_demo_story() {
        use crate::demo::data::DEMO_FITTINGS_JSON;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let lines_for = |fitting: &CharacterFitting| match ship_base_ehp(fitting, &catalogue) {
            ShipBaseEhpOutcome::Available(ehp) => ship_base_ehp_lines(&ehp),
            ShipBaseEhpOutcome::Unavailable => {
                panic!("demo fitting must have base effective hit points")
            }
        };

        let rifter_block = [
            "Shield EHP: 620.7 HP",
            "Armor EHP: 666.7 HP",
            "Hull EHP: 522.4 HP",
            "Total EHP: 1,809.7 HP",
        ];
        assert_eq!(lines_for(&find("Demo Brawler")), rifter_block);
        assert_eq!(lines_for(&find("Mission Runner")), rifter_block);
        assert_eq!(
            lines_for(&find("Demo Runner")),
            [
                "Shield EHP: 482.8 HP",
                "Armor EHP: 740.7 HP",
                "Hull EHP: 671.6 HP",
                "Total EHP: 1,895.1 HP",
            ]
        );

        // Imported path: the demo sample fit through the shared
        // synthesis seam yields the same Rifter block.
        let synth = match parse_eft(DEMO_SAMPLE_EFT, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        assert_eq!(lines_for(&synth), rifter_block);

        // The DNA sample lands on the same hull, so its block is
        // byte-identical too (EHP keys off the ship, not format).
        let synth_dna = match parse_import(DEMO_SAMPLE_DNA, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => {
                panic!("demo DNA sample must import, got {fatal:?}")
            }
        };
        assert_eq!(lines_for(&synth_dna), rifter_block);
    }

    // Ship navigation and targeting (navigation and targeting
    // design section 8): a full synthetic targeting struct
    // renders the eight locked lines verbatim — one-decimal
    // formatter, thousands-grouped mass, joined sensor line,
    // bare integer count, and no agility line.
    fn full_nav_targeting() -> ShipNavTargeting {
        ShipNavTargeting {
            warp_speed: Some(5.0),
            align_time_secs: Some(4.7),
            agility: Some(3.2),
            mass: Some(1_067_000.0),
            signature_radius: Some(35.0),
            max_target_range_km: Some(22.5),
            scan_resolution: Some(660.0),
            sensor_radar: Some(0.0),
            sensor_ladar: Some(8.0),
            sensor_magnetometric: Some(0.0),
            sensor_gravimetric: Some(0.0),
            max_locked_targets: Some(4),
        }
    }

    #[test]
    fn ship_nav_targeting_lines_match_the_locked_templates() {
        assert_eq!(
            ship_nav_targeting_lines(&full_nav_targeting()),
            [
                "Warp speed: 5.0 AU/s",
                "Align time: 4.7 s",
                "Mass: 1,067,000.0 kg",
                "Signature radius: 35.0 m",
                "Targeting range: 22.5 km",
                "Scan resolution: 660.0 mm",
                "Sensor strength: RADAR 0.0 points, Ladar 8.0 points, Magnetometric 0.0 points, Gravimetric 0.0 points",
                "Max locked targets: 4",
            ]
        );
    }

    // Omission: None scan/count/sensors each omit exactly
    // their line; all-None sensors omit the joined line; a
    // present 0.0 range renders `Targeting range: 0.0 km`;
    // a present 0 renders `Max locked targets: 0`.
    #[test]
    fn ship_nav_targeting_omission_and_present_zeros() {
        let mut partial = full_nav_targeting();
        partial.scan_resolution = None;
        partial.sensor_radar = None;
        partial.sensor_ladar = None;
        assert_eq!(
            ship_nav_targeting_lines(&partial),
            [
                "Warp speed: 5.0 AU/s",
                "Align time: 4.7 s",
                "Mass: 1,067,000.0 kg",
                "Signature radius: 35.0 m",
                "Targeting range: 22.5 km",
                "Sensor strength: Magnetometric 0.0 points, Gravimetric 0.0 points",
                "Max locked targets: 4",
            ]
        );

        let mut no_sensors = full_nav_targeting();
        no_sensors.sensor_radar = None;
        no_sensors.sensor_ladar = None;
        no_sensors.sensor_magnetometric = None;
        no_sensors.sensor_gravimetric = None;
        no_sensors.max_target_range_km = Some(0.0);
        no_sensors.max_locked_targets = Some(0);
        assert_eq!(
            ship_nav_targeting_lines(&no_sensors),
            [
                "Warp speed: 5.0 AU/s",
                "Align time: 4.7 s",
                "Mass: 1,067,000.0 kg",
                "Signature radius: 35.0 m",
                "Targeting range: 0.0 km",
                "Scan resolution: 660.0 mm",
                "Max locked targets: 0",
            ]
        );
    }

    // Sensor join order and labels pinned: four positive
    // segments in RADAR, Ladar, Magnetometric, Gravimetric
    // (attribute-id) order — the Apotheosis all-four-positive
    // shape.
    #[test]
    fn ship_nav_targeting_sensor_join_order_and_labels() {
        let mut apotheosis = full_nav_targeting();
        apotheosis.sensor_radar = Some(10.0);
        apotheosis.sensor_ladar = Some(10.0);
        apotheosis.sensor_magnetometric = Some(10.0);
        apotheosis.sensor_gravimetric = Some(10.0);
        let lines = ship_nav_targeting_lines(&apotheosis);
        assert_eq!(
            lines[6],
            "Sensor strength: RADAR 10.0 points, Ladar 10.0 points, Magnetometric 10.0 points, Gravimetric 10.0 points".to_string()
        );
    }

    #[test]
    fn ship_nav_targeting_unavailable_and_disclosure_wording() {
        assert_eq!(
            FITTINGS_SHIP_NAV_TARGETING_HEADING,
            "Ship navigation and targeting (base values)"
        );
        assert_eq!(
            FITTING_SHIP_NAV_TARGETING_NO_CATALOGUE,
            "Ship navigation and targeting unavailable: Mimir's bundled item data failed to load."
        );
        assert_eq!(
            FITTING_SHIP_NAV_TARGETING_NO_SHIP_DATA,
            "Ship navigation and targeting unavailable: Mimir's bundled item data has no navigation or targeting data for this fitting's ship."
        );
        assert_eq!(
            FITTING_SHIP_NAV_TARGETING_DISCLOSURE,
            "These are the bare hull's base navigation and targeting values from Mimir's bundled item data. Fitted modules, rigs, subsystems, skills, implants, and ship bonuses are not applied, so these numbers can differ from EVE."
        );
    }

    // Demo story (navigation and targeting design section 7):
    // Demo Brawler and Mission Runner are both Rifter 587
    // and render identical blocks despite their invented
    // sample rows; Demo Runner is Punisher 597. The rendered
    // decimals are the formatter's one-decimal rounding of
    // the section 7 table values (Rifter align 4.733363…
    // renders 4.7 s; Punisher align 4.784101… renders 4.8 s).
    // Built from the real demo fixture over the real
    // catalogue, so fixture or catalogue drift fails here.
    #[test]
    fn demo_fixture_ship_nav_targeting_match_the_locked_demo_story() {
        use crate::demo::data::DEMO_FITTINGS_JSON;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let lines_for = |fitting: &CharacterFitting| match ship_nav_targeting(fitting, &catalogue) {
            ShipNavTargetingOutcome::Available(targeting) => ship_nav_targeting_lines(&targeting),
            ShipNavTargetingOutcome::Unavailable => {
                panic!("demo fitting must have navigation and targeting data")
            }
        };

        let rifter_block = [
            "Warp speed: 5.0 AU/s",
            "Align time: 4.7 s",
            "Mass: 1,067,000.0 kg",
            "Signature radius: 35.0 m",
            "Targeting range: 22.5 km",
            "Scan resolution: 660.0 mm",
            "Sensor strength: RADAR 0.0 points, Ladar 8.0 points, Magnetometric 0.0 points, Gravimetric 0.0 points",
            "Max locked targets: 4",
        ];
        assert_eq!(lines_for(&find("Demo Brawler")), rifter_block);
        assert_eq!(lines_for(&find("Mission Runner")), rifter_block);
        assert_eq!(
            lines_for(&find("Demo Runner")),
            [
                "Warp speed: 5.0 AU/s",
                "Align time: 4.8 s",
                "Mass: 1,190,000.0 kg",
                "Signature radius: 37.0 m",
                "Targeting range: 25.0 km",
                "Scan resolution: 640.0 mm",
                "Sensor strength: RADAR 10.0 points, Ladar 0.0 points, Magnetometric 0.0 points, Gravimetric 0.0 points",
                "Max locked targets: 4",
            ]
        );

        // Imported path: the demo sample fit through the shared
        // synthesis seam yields the same Rifter block.
        let synth = match parse_eft(DEMO_SAMPLE_EFT, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        assert_eq!(lines_for(&synth), rifter_block);

        // The DNA sample lands on the same hull, so its block
        // is byte-identical too (navigation keys off the ship,
        // not format).
        let synth_dna = match parse_import(DEMO_SAMPLE_DNA, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => {
                panic!("demo DNA sample must import, got {fatal:?}")
            }
        };
        assert_eq!(lines_for(&synth_dna), rifter_block);
    }

    fn bay_budget(used: f64, capacity: f64) -> BayBudget {
        BayBudget {
            used,
            capacity,
            excluded_items: 0,
        }
    }

    #[test]
    fn bay_lines_match_the_locked_templates() {
        // Under capacity: ordered lines, used of capacity, room left.
        assert_eq!(
            bay_line("Cargo bay", &bay_budget(5.0, 140.0), "m3"),
            "Cargo bay: 5.0 m3 of 140.0 m3 used (135.0 m3 left)"
        );
        assert_eq!(
            bay_line("Drone bay", &bay_budget(25.0, 40.0), "m3"),
            "Drone bay: 25.0 m3 of 40.0 m3 used (15.0 m3 left)"
        );
        // At capacity is not over: 0.0 left, normal colour.
        assert_eq!(
            bay_line("Drone bandwidth", &bay_budget(25.0, 25.0), "Mbit/sec"),
            "Drone bandwidth: 25.0 Mbit/sec of 25.0 Mbit/sec used (0.0 Mbit/sec left)"
        );
        // Over capacity: positive overage, flagged for red rendering.
        assert_eq!(
            bay_line("Drone bay", &bay_budget(25.0, 0.0), "m3"),
            "Drone bay: 25.0 m3 of 0.0 m3 used (25.0 m3 over)"
        );
        assert_eq!(
            bay_line("Drone bandwidth", &bay_budget(25.0, 0.0), "Mbit/sec"),
            "Drone bandwidth: 25.0 Mbit/sec of 0.0 Mbit/sec used (25.0 Mbit/sec over)"
        );
        // Digit grouping and the shared one-decimal rounding: a
        // computed 0.58 m3 renders as 0.6 m3.
        assert_eq!(
            bay_line("Fighter bay", &bay_budget(3_000.0, 40_000.0), "m3"),
            "Fighter bay: 3,000.0 m3 of 40,000.0 m3 used (37,000.0 m3 left)"
        );
        assert_eq!(
            bay_line("Cargo bay", &bay_budget(0.58, 140.0), "m3"),
            "Cargo bay: 0.6 m3 of 140.0 m3 used (139.4 m3 left)"
        );
    }

    #[test]
    fn bay_excluded_lines_match_the_locked_templates() {
        // Zero excluded renders no line on any dimension.
        assert_eq!(bay_excluded_line("Cargo bay", 0, "volume"), None);
        assert_eq!(bay_excluded_line("Drone bay", 0, "volume"), None);
        assert_eq!(bay_excluded_line("Drone bandwidth", 0, "bandwidth"), None);
        assert_eq!(bay_excluded_line("Fighter bay", 0, "volume"), None);
        // Singular and plural for all four dimensions.
        assert_eq!(
            bay_excluded_line("Cargo bay", 1, "volume").as_deref(),
            Some(
                "Cargo bay does not count 1 item with no volume data in Mimir's bundled item data."
            )
        );
        assert_eq!(
            bay_excluded_line("Cargo bay", 2, "volume").as_deref(),
            Some("Cargo bay does not count 2 items with no volume data in Mimir's bundled item data.")
        );
        assert_eq!(
            bay_excluded_line("Drone bay", 1, "volume").as_deref(),
            Some(
                "Drone bay does not count 1 item with no volume data in Mimir's bundled item data."
            )
        );
        assert_eq!(
            bay_excluded_line("Drone bay", 2, "volume").as_deref(),
            Some("Drone bay does not count 2 items with no volume data in Mimir's bundled item data.")
        );
        assert_eq!(
            bay_excluded_line("Drone bandwidth", 1, "bandwidth").as_deref(),
            Some("Drone bandwidth does not count 1 item with no bandwidth data in Mimir's bundled item data.")
        );
        assert_eq!(
            bay_excluded_line("Drone bandwidth", 2, "bandwidth").as_deref(),
            Some("Drone bandwidth does not count 2 items with no bandwidth data in Mimir's bundled item data.")
        );
        assert_eq!(
            bay_excluded_line("Fighter bay", 1, "volume").as_deref(),
            Some("Fighter bay does not count 1 item with no volume data in Mimir's bundled item data.")
        );
        assert_eq!(
            bay_excluded_line("Fighter bay", 2, "volume").as_deref(),
            Some("Fighter bay does not count 2 items with no volume data in Mimir's bundled item data.")
        );
    }

    #[test]
    fn bay_usage_unavailable_and_disclosure_wording() {
        assert_eq!(FITTINGS_BAYS_HEADING, "Bays (base values)");
        assert_eq!(
            FITTING_BAYS_NO_CATALOGUE,
            "Bay usage unavailable: Mimir's bundled item data failed to load."
        );
        assert_eq!(
            FITTING_BAYS_NO_SHIP_DATA,
            "Bay usage unavailable: Mimir's bundled item data has no bay capacity data for this fitting's ship."
        );
        assert_eq!(
            FITTING_BAYS_DISCLOSURE,
            "Base bay capacities and plain item volumes from Mimir's bundled item data. Capacity bonuses from skills, modules (such as cargo expanders), rigs, subsystems, implants, and the ship itself are not applied, and specialized holds are not counted, so these numbers can differ from EVE."
        );
    }

    // Demo story (bay capacities design section 7): computed
    // from the real demo fixture over the real bundled
    // catalogue, so fixture or catalogue drift fails here.
    // Demo Brawler cargo 5.02 excludes 200 (type 636, absent
    // from the catalogue) and renders as 5.0; drone and
    // bandwidth sit over the Rifter's present 0.0 capacities;
    // no fighter line (no fighter capacity on the hull).
    #[test]
    fn demo_fixture_bay_usage_match_the_locked_demo_story() {
        use crate::demo::data::DEMO_FITTINGS_JSON;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let assert_close = |actual: f64, expected: f64| {
            assert!(
                (actual - expected).abs() < 1e-9,
                "expected {expected}, got {actual}"
            );
        };
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let usage_for = |fitting: &CharacterFitting| match bay_usage(fitting, &catalogue) {
            BayUsageOutcome::Available(usage) => usage,
            BayUsageOutcome::Unavailable => panic!("demo fitting must have bay usage"),
        };

        // Demo Brawler (Rifter 587, cargo 140.0, drone 0.0,
        // bandwidth 0.0): cargo = 500x0.01 + 2x0.01 (Invalid
        // counts as cargo) = 5.02, 200 excluded; drones 5x5.0.
        let brawler = usage_for(&find("Demo Brawler"));
        let cargo = brawler.cargo.expect("Rifter carries cargo capacity");
        assert_close(cargo.used, 5.02);
        assert_close(cargo.capacity, 140.0);
        assert_eq!(cargo.excluded_items, 200);
        // Over-capacity bay lines flag true (red rendering);
        // the excluded line and under-capacity line flag false.
        assert_eq!(
            bay_usage_lines(&brawler),
            vec![
                (
                    "Cargo bay: 5.0 m3 of 140.0 m3 used (135.0 m3 left)".to_string(),
                    false
                ),
                (
                    "Drone bay: 25.0 m3 of 0.0 m3 used (25.0 m3 over)".to_string(),
                    true
                ),
                (
                    "Drone bandwidth: 25.0 Mbit/sec of 0.0 Mbit/sec used (25.0 Mbit/sec over)"
                        .to_string(),
                    true
                ),
                (
                    "Cargo bay does not count 200 items with no volume data in Mimir's bundled item data."
                        .to_string(),
                    false
                ),
            ]
        );
        assert!(brawler.fighter.is_none());

        // Mission Runner (Rifter): cargo 10x0.01 = 0.1, drones 3x5.0.
        let mission = usage_for(&find("Mission Runner"));
        assert_eq!(
            bay_usage_lines(&mission),
            vec![
                (
                    "Cargo bay: 0.1 m3 of 140.0 m3 used (139.9 m3 left)".to_string(),
                    false
                ),
                (
                    "Drone bay: 15.0 m3 of 0.0 m3 used (15.0 m3 over)".to_string(),
                    true
                ),
                (
                    "Drone bandwidth: 15.0 Mbit/sec of 0.0 Mbit/sec used (15.0 Mbit/sec over)"
                        .to_string(),
                    true
                ),
            ]
        );
        assert!(mission.fighter.is_none());

        // Demo Runner (Punisher 597, cargo 135.0): cargo
        // 20x0.01 = 0.2, drones 3x5.0.
        let runner = usage_for(&find("Demo Runner"));
        assert_eq!(
            bay_usage_lines(&runner),
            vec![
                (
                    "Cargo bay: 0.2 m3 of 135.0 m3 used (134.8 m3 left)".to_string(),
                    false
                ),
                (
                    "Drone bay: 15.0 m3 of 0.0 m3 used (15.0 m3 over)".to_string(),
                    true
                ),
                (
                    "Drone bandwidth: 15.0 Mbit/sec of 0.0 Mbit/sec used (15.0 Mbit/sec over)"
                        .to_string(),
                    true
                ),
            ]
        );
        assert!(runner.fighter.is_none());

        // Imported path: the sample EFT through synthesis —
        // cargo 200x0.0025 + 8x0.01 = 0.58, rendering as 0.6;
        // the loaded charge counts nowhere.
        let synth = match parse_eft(DEMO_SAMPLE_EFT, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        let sample = usage_for(&synth);
        let cargo = sample.cargo.expect("Rifter carries cargo capacity");
        assert_close(cargo.used, 0.58);
        assert_eq!(cargo.excluded_items, 0);
        assert_eq!(
            bay_usage_lines(&sample),
            vec![
                (
                    "Cargo bay: 0.6 m3 of 140.0 m3 used (139.4 m3 left)".to_string(),
                    false
                ),
                (
                    "Drone bay: 10.0 m3 of 0.0 m3 used (10.0 m3 over)".to_string(),
                    true
                ),
                (
                    "Drone bandwidth: 10.0 Mbit/sec of 0.0 Mbit/sec used (10.0 Mbit/sec over)"
                        .to_string(),
                    true
                ),
            ]
        );

        // The DNA sample is modules only, so the bays are
        // present-zero by construction.
        let synth_dna = match parse_import(DEMO_SAMPLE_DNA, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => {
                panic!("demo DNA sample must import, got {fatal:?}")
            }
        };
        assert_eq!(
            bay_usage_lines(&usage_for(&synth_dna)),
            vec![
                (
                    "Cargo bay: 0.0 m3 of 140.0 m3 used (140.0 m3 left)".to_string(),
                    false
                ),
                (
                    "Drone bay: 0.0 m3 of 0.0 m3 used (0.0 m3 left)".to_string(),
                    false
                ),
                (
                    "Drone bandwidth: 0.0 Mbit/sec of 0.0 Mbit/sec used (0.0 Mbit/sec left)"
                        .to_string(),
                    false
                ),
            ]
        );

        // No fighter line anywhere in demo.
        for fitting in [
            &find("Demo Brawler"),
            &find("Mission Runner"),
            &find("Demo Runner"),
        ] {
            assert!(
                bay_usage_lines(&usage_for(fitting))
                    .iter()
                    .all(|(line, _)| !line.starts_with("Fighter bay")),
                "demo has no fighter bay line"
            );
        }
    }

    fn calibration_budget(used: f64, capacity: f64) -> CalibrationBudget {
        CalibrationBudget {
            used,
            capacity,
            excluded_rigs: 0,
        }
    }

    #[test]
    fn calibration_lines_match_the_locked_templates() {
        // Under capacity: 200.0 of 400.0 (400.0 - 200.0 = 200.0 left).
        assert_eq!(
            calibration_line(&calibration_budget(200.0, 400.0)),
            "Calibration: 200.0 points of 400.0 points used (200.0 points left)"
        );
        // At capacity: 400.0 of 400.0 (400.0 - 400.0 = 0.0 left), normal
        // colour.
        assert_eq!(
            calibration_line(&calibration_budget(400.0, 400.0)),
            "Calibration: 400.0 points of 400.0 points used (0.0 points left)"
        );
        // Over capacity: 300.0 + 150.0 = 450.0 of 400.0
        // (450.0 - 400.0 = 50.0 over).
        let over = calibration_budget(450.0, 400.0);
        assert!(over.is_over());
        assert_eq!(
            calibration_line(&over),
            "Calibration: 450.0 points of 400.0 points used (50.0 points over)"
        );
        // Under and at are not over.
        assert!(!calibration_budget(200.0, 400.0).is_over());
        assert!(!calibration_budget(400.0, 400.0).is_over());
    }

    #[test]
    fn calibration_excluded_lines_match_the_locked_templates() {
        assert_eq!(calibration_excluded_line(0), None);
        assert_eq!(
            calibration_excluded_line(1).as_deref(),
            Some(
                "Calibration does not count 1 fitted rig with no calibration cost data in Mimir's bundled item data."
            )
        );
        assert_eq!(
            calibration_excluded_line(2).as_deref(),
            Some(
                "Calibration does not count 2 fitted rigs with no calibration cost data in Mimir's bundled item data."
            )
        );
    }

    #[test]
    fn calibration_unavailable_and_disclosure_wording() {
        assert_eq!(
            FITTINGS_CALIBRATION_HEADING,
            "Rig calibration (base values)"
        );
        assert_eq!(
            FITTING_CALIBRATION_NO_CATALOGUE,
            "Rig calibration unavailable: Mimir's bundled item data failed to load."
        );
        assert_eq!(
            FITTING_CALIBRATION_NO_SHIP_DATA,
            "Rig calibration unavailable: Mimir's bundled item data has no calibration data for this fitting's ship."
        );
        assert_eq!(
            FITTING_CALIBRATION_DISCLOSURE,
            "Base rig calibration costs against the ship's base calibration, from Mimir's bundled item data. Skills, implants, and bonuses from modules, rigs, subsystems, and the ship itself are not applied, so these numbers can differ from EVE."
        );
    }

    // Demo story (rig calibration design section 7): computed from
    // the real demo fixture over the real bundled catalogue, so
    // fixture or catalogue drift fails here. Demo Brawler's rig
    // type 1535 is absent from the catalogue, so it contributes
    // nothing to used and 1 to excluded — the built-in
    // unknown-cost exhibit. The sample imports each fit rig 31668
    // once: 1 * 200.0 = 200.0 of 400.0.
    #[test]
    fn demo_fixture_calibration_match_the_locked_demo_story() {
        use crate::demo::data::DEMO_FITTINGS_JSON;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let assert_close = |actual: f64, expected: f64| {
            assert!(
                (actual - expected).abs() < 1e-9,
                "expected {expected}, got {actual}"
            );
        };
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let budget_for = |fitting: &CharacterFitting| match rig_calibration(fitting, &catalogue) {
            CalibrationOutcome::Available(budget) => budget,
            CalibrationOutcome::Unavailable => panic!("demo fitting must have calibration"),
        };

        // Demo Brawler (Rifter 587, capacity 400.0): the single
        // RigSlot row has no catalogue cost, so used stays 0.0 and
        // the excluded count is 1.
        let brawler = budget_for(&find("Demo Brawler"));
        assert_close(brawler.used, 0.0);
        assert_close(brawler.capacity, 400.0);
        // 400.0 - 0.0 = 400.0 left.
        assert_close(brawler.remaining(), 400.0);
        assert_eq!(brawler.excluded_rigs, 1);
        assert!(!brawler.is_over());
        assert_eq!(
            calibration_line(&brawler),
            "Calibration: 0.0 points of 400.0 points used (400.0 points left)"
        );
        assert_eq!(
            calibration_excluded_line(brawler.excluded_rigs).as_deref(),
            Some(
                "Calibration does not count 1 fitted rig with no calibration cost data in Mimir's bundled item data."
            )
        );

        // Mission Runner (Rifter 587): no RigSlot rows, so a real
        // zero against the present capacity.
        let mission = budget_for(&find("Mission Runner"));
        assert_close(mission.used, 0.0);
        assert_close(mission.capacity, 400.0);
        assert_eq!(mission.excluded_rigs, 0);
        assert_eq!(
            calibration_line(&mission),
            "Calibration: 0.0 points of 400.0 points used (400.0 points left)"
        );
        assert_eq!(calibration_excluded_line(mission.excluded_rigs), None);

        // Demo Runner (Punisher 597, capacity 400.0): the same
        // real-zero shape.
        let runner = budget_for(&find("Demo Runner"));
        assert_close(runner.used, 0.0);
        assert_close(runner.capacity, 400.0);
        assert_eq!(runner.excluded_rigs, 0);
        assert_eq!(
            calibration_line(&runner),
            "Calibration: 0.0 points of 400.0 points used (400.0 points left)"
        );
        assert_eq!(calibration_excluded_line(runner.excluded_rigs), None);

        // Sample EFT through synthesis: 1 * 200.0 = 200.0 of 400.0
        // (400.0 - 200.0 = 200.0 left), excluded 0.
        let synth = match parse_eft(DEMO_SAMPLE_EFT, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        let sample = budget_for(&synth);
        assert_close(sample.used, 200.0);
        assert_close(sample.capacity, 400.0);
        assert_close(sample.remaining(), 200.0);
        assert_eq!(sample.excluded_rigs, 0);
        assert_eq!(
            calibration_line(&sample),
            "Calibration: 200.0 points of 400.0 points used (200.0 points left)"
        );
        assert_eq!(calibration_excluded_line(sample.excluded_rigs), None);

        // Sample DNA through synthesis: the same rig, so the same
        // 1 * 200.0 = 200.0 of 400.0, excluded 0.
        let synth_dna = match parse_import(DEMO_SAMPLE_DNA, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => {
                panic!("demo DNA sample must import, got {fatal:?}")
            }
        };
        let sample_dna = budget_for(&synth_dna);
        assert_close(sample_dna.used, 200.0);
        assert_close(sample_dna.capacity, 400.0);
        assert_close(sample_dna.remaining(), 200.0);
        assert_eq!(sample_dna.excluded_rigs, 0);
        assert_eq!(
            calibration_line(&sample_dna),
            "Calibration: 200.0 points of 400.0 points used (200.0 points left)"
        );
        assert_eq!(calibration_excluded_line(sample_dna.excluded_rigs), None);
    }

    #[test]
    fn slot_lines_match_the_locked_templates() {
        // Under capacity: ordered lines, used of capacity, room
        // left. Arithmetic: 4 - 1 = 3, 3 - 2 = 1, 3 - 1 = 2,
        // 3 - 0 = 3, 2 - 0 = 2, 5 - 5 = 0.
        assert_eq!(
            slot_line("Low slots", &slot_budget(1, 4)),
            "Low slots: 1 of 4 used (3 left)"
        );
        assert_eq!(
            slot_line("Medium slots", &slot_budget(2, 3)),
            "Medium slots: 2 of 3 used (1 left)"
        );
        assert_eq!(
            slot_line("High slots", &slot_budget(2, 3)),
            "High slots: 2 of 3 used (1 left)"
        );
        assert_eq!(
            slot_line("Rigs", &slot_budget(1, 3)),
            "Rigs: 1 of 3 used (2 left)"
        );
        assert_eq!(
            slot_line("Subsystems", &slot_budget(1, 5)),
            "Subsystems: 1 of 5 used (4 left)"
        );
        assert_eq!(
            slot_line("Turret hardpoints", &slot_budget(0, 3)),
            "Turret hardpoints: 0 of 3 used (3 left)"
        );
        assert_eq!(
            slot_line("Launcher hardpoints", &slot_budget(0, 2)),
            "Launcher hardpoints: 0 of 2 used (2 left)"
        );
        // At capacity is not over: 0 left, normal colour.
        assert_eq!(
            slot_line("High slots", &slot_budget(3, 3)),
            "High slots: 3 of 3 used (0 left)"
        );
        assert_eq!(
            slot_line("Subsystems", &slot_budget(5, 5)),
            "Subsystems: 5 of 5 used (0 left)"
        );
        // Over capacity: positive overage, flagged for red
        // rendering. Arithmetic: 4 - 3 = 1, 4 - 2 = 2.
        assert_eq!(
            slot_line("High slots", &slot_budget(4, 3)),
            "High slots: 4 of 3 used (1 over)"
        );
        assert_eq!(
            slot_line("Launcher hardpoints", &slot_budget(4, 2)),
            "Launcher hardpoints: 4 of 2 used (2 over)"
        );
        // Present zero renders as data: 0 of 0 (0 - 0 = 0 left).
        assert_eq!(
            slot_line("High slots", &slot_budget(0, 0)),
            "High slots: 0 of 0 used (0 left)"
        );
        // Under, at, and present-zero are not over.
        assert!(!slot_budget(2, 3).is_over());
        assert!(!slot_budget(3, 3).is_over());
        assert!(!slot_budget(0, 0).is_over());
        assert!(slot_budget(4, 3).is_over());
    }

    #[test]
    fn hardpoint_excluded_lines_match_the_locked_templates() {
        // Zero excluded renders no line on either hardpoint
        // dimension.
        assert_eq!(hardpoint_excluded_line("Turret hardpoints", 0), None);
        assert_eq!(hardpoint_excluded_line("Launcher hardpoints", 0), None);
        // Singular and plural for both labels.
        assert_eq!(
            hardpoint_excluded_line("Turret hardpoints", 1).as_deref(),
            Some(
                "Turret hardpoints does not count 1 fitted module missing from Mimir's bundled item data."
            )
        );
        assert_eq!(
            hardpoint_excluded_line("Turret hardpoints", 2).as_deref(),
            Some(
                "Turret hardpoints does not count 2 fitted modules missing from Mimir's bundled item data."
            )
        );
        assert_eq!(
            hardpoint_excluded_line("Launcher hardpoints", 1).as_deref(),
            Some(
                "Launcher hardpoints does not count 1 fitted module missing from Mimir's bundled item data."
            )
        );
        assert_eq!(
            hardpoint_excluded_line("Launcher hardpoints", 2).as_deref(),
            Some(
                "Launcher hardpoints does not count 2 fitted modules missing from Mimir's bundled item data."
            )
        );
        assert_eq!(
            hardpoint_excluded_line("Turret hardpoints", 3).as_deref(),
            Some(
                "Turret hardpoints does not count 3 fitted modules missing from Mimir's bundled item data."
            )
        );
    }

    #[test]
    fn slot_layout_unavailable_and_disclosure_wording() {
        assert_eq!(FITTINGS_SLOT_LAYOUT_HEADING, "Slot layout (base values)");
        assert_eq!(
            FITTING_SLOT_LAYOUT_NO_CATALOGUE,
            "Slot layout unavailable: Mimir's bundled item data failed to load."
        );
        assert_eq!(
            FITTING_SLOT_LAYOUT_NO_SHIP_DATA,
            "Slot layout unavailable: Mimir's bundled item data has no slot layout data for this fitting's ship."
        );
        assert_eq!(
            FITTING_SLOT_LAYOUT_TECH3_NOTE,
            "This ship's high, medium, and low slots and its turret and launcher hardpoints are set by its fitted subsystems, which are not applied here, so those lines are not shown."
        );
        assert_eq!(
            FITTING_SLOT_LAYOUT_DISCLOSURE,
            "Base slot and hardpoint counts from Mimir's bundled item data. Slots and hardpoints granted by fitted subsystems are not applied, and no skill, implant, module, rig, or ship bonuses are applied, so these numbers can differ from EVE."
        );
    }

    #[test]
    fn slot_layout_lines_ordering_none_skipped_excluded_after_over_flagged() {
        // Locked order with a None subsystem dimension
        // skipped, excluded lines appended after in the same
        // dimension order, and the over flag paired only with
        // the over line. Arithmetic: 4 - 1 = 3, 3 - 0 = 3,
        // 4 - 3 = 1 over, 3 - 1 = 2, 3 - 0 = 3, 2 - 0 = 2.
        let layout = SlotLayout {
            high: Some(SlotBudget {
                used: 4,
                capacity: 3,
                excluded_modules: 0,
            }),
            medium: Some(slot_budget(0, 3)),
            low: Some(slot_budget(1, 4)),
            rig: Some(slot_budget(1, 3)),
            subsystem: None,
            turret: Some(SlotBudget {
                used: 0,
                capacity: 3,
                excluded_modules: 2,
            }),
            launcher: Some(SlotBudget {
                used: 0,
                capacity: 2,
                excluded_modules: 1,
            }),
            subsystem_layout: false,
        };
        assert_eq!(
            slot_layout_lines(&layout),
            vec![
                (
                    "Low slots: 1 of 4 used (3 left)".to_string(),
                    false
                ),
                (
                    "Medium slots: 0 of 3 used (3 left)".to_string(),
                    false
                ),
                (
                    "High slots: 4 of 3 used (1 over)".to_string(),
                    true
                ),
                ("Rigs: 1 of 3 used (2 left)".to_string(), false),
                (
                    "Turret hardpoints: 0 of 3 used (3 left)".to_string(),
                    false
                ),
                (
                    "Launcher hardpoints: 0 of 2 used (2 left)".to_string(),
                    false
                ),
                (
                    "Turret hardpoints does not count 2 fitted modules missing from Mimir's bundled item data."
                        .to_string(),
                    false
                ),
                (
                    "Launcher hardpoints does not count 1 fitted module missing from Mimir's bundled item data."
                        .to_string(),
                    false
                ),
            ]
        );

        // Capsule shape: only the two hardpoint dimensions are
        // present, so exactly two dimension lines render.
        // Arithmetic: 0 - 0 = 0 left on both.
        let capsule = SlotLayout {
            high: None,
            medium: None,
            low: None,
            rig: None,
            subsystem: None,
            turret: Some(slot_budget(0, 0)),
            launcher: Some(slot_budget(0, 0)),
            subsystem_layout: false,
        };
        assert_eq!(
            slot_layout_lines(&capsule),
            vec![
                ("Turret hardpoints: 0 of 0 used (0 left)".to_string(), false),
                (
                    "Launcher hardpoints: 0 of 0 used (0 left)".to_string(),
                    false
                ),
            ]
        );

        // Tech-3 shape: rig and subsystem only are present,
        // and the tech-3 sentence is not part of the vec.
        // Arithmetic: 3 - 0 = 3, 5 - 0 = 5.
        let tech3 = SlotLayout {
            high: None,
            medium: None,
            low: None,
            rig: Some(slot_budget(0, 3)),
            subsystem: Some(slot_budget(0, 5)),
            turret: None,
            launcher: None,
            subsystem_layout: true,
        };
        assert_eq!(
            slot_layout_lines(&tech3),
            vec![
                ("Rigs: 0 of 3 used (3 left)".to_string(), false),
                ("Subsystems: 0 of 5 used (5 left)".to_string(), false),
            ]
        );
    }

    // Demo story (slot layout design section 7): computed from
    // the real demo fixture over the real bundled catalogue,
    // so fixture or catalogue drift fails here.
    #[test]
    fn demo_fixture_slot_layout_match_the_locked_demo_story() {
        use crate::demo::data::DEMO_FITTINGS_JSON;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let layout_for = |fitting: &CharacterFitting| match slot_layout(fitting, &catalogue) {
            SlotLayoutOutcome::Available(layout) => layout,
            SlotLayoutOutcome::Unavailable => panic!("demo fitting must have slot layout"),
        };

        // Demo Brawler (Rifter 587: low 4, med 3, high 3, rig 3,
        // turret 3, launcher 2). Flag-driven counting: LoSlot0
        // 2048 -> low 1 of 4 (4 - 1 = 3 left); MedSlot0 2049
        // and MedSlot1 1225 -> medium 2 of 3 (3 - 2 = 1 left);
        // HiSlot0/HiSlot1 with 2050 (catalogued, no hardpoint
        // marker) -> high 2 of 3 (3 - 2 = 1 left), turret 0 of
        // 3 (3 - 0 = 3 left), launcher 0 of 2 (2 - 0 = 2 left),
        // excluded 0; RigSlot0 1535 (absent from the
        // catalogue) -> rig 1 of 3 (3 - 1 = 2 left); the
        // SubSystemSlot0 row has no subsystem dimension on the
        // Rifter, so no subsystem line and no exclusion.
        let brawler = layout_for(&find("Demo Brawler"));
        assert!(!brawler.subsystem_layout);
        assert!(brawler.subsystem.is_none());
        let turret = brawler.turret.expect("Rifter carries turret hardpoints");
        assert_eq!(turret.used, 0);
        assert_eq!(turret.capacity, 3);
        assert_eq!(turret.excluded_modules, 0);
        let launcher = brawler
            .launcher
            .expect("Rifter carries launcher hardpoints");
        assert_eq!(launcher.used, 0);
        assert_eq!(launcher.capacity, 2);
        assert_eq!(launcher.excluded_modules, 0);
        assert_eq!(
            slot_layout_lines(&brawler),
            vec![
                ("Low slots: 1 of 4 used (3 left)".to_string(), false),
                ("Medium slots: 2 of 3 used (1 left)".to_string(), false),
                ("High slots: 2 of 3 used (1 left)".to_string(), false),
                ("Rigs: 1 of 3 used (2 left)".to_string(), false),
                ("Turret hardpoints: 0 of 3 used (3 left)".to_string(), false),
                (
                    "Launcher hardpoints: 0 of 2 used (2 left)".to_string(),
                    false
                ),
            ]
        );

        // Mission Runner (Rifter 587): HiSlot0 2048 (a low
        // module under a high flag, catalogued, no marker)
        // -> high 1 of 3 (3 - 1 = 2 left); LoSlot0 2049 ->
        // low 1 of 4 (4 - 1 = 3 left); medium, rigs, and both
        // hardpoints present-zero-real against capacity
        // (3 - 0 = 3 left, 3 - 0 = 3 left, 3 - 0 = 3 left,
        // 2 - 0 = 2 left).
        let mission = layout_for(&find("Mission Runner"));
        assert_eq!(
            slot_layout_lines(&mission),
            vec![
                ("Low slots: 1 of 4 used (3 left)".to_string(), false),
                ("Medium slots: 0 of 3 used (3 left)".to_string(), false),
                ("High slots: 1 of 3 used (2 left)".to_string(), false),
                ("Rigs: 0 of 3 used (3 left)".to_string(), false),
                ("Turret hardpoints: 0 of 3 used (3 left)".to_string(), false),
                (
                    "Launcher hardpoints: 0 of 2 used (2 left)".to_string(),
                    false
                ),
            ]
        );

        // Demo Runner (Punisher 597: low 5, med 2, high 4,
        // rig 3, turret 4, launcher 0 present): LoSlot0 2048
        // -> low 1 of 5 (5 - 1 = 4 left); MedSlot0 1225 ->
        // medium 1 of 2 (2 - 1 = 1 left); HiSlot0 2050 ->
        // high 1 of 4 (4 - 1 = 3 left); rigs 0 of 3
        // (3 - 0 = 3 left), turret 0 of 4 (4 - 0 = 4 left),
        // launcher 0 of 0 present-zero (0 - 0 = 0 left) —
        // the demo's present-zero exhibit.
        let runner = layout_for(&find("Demo Runner"));
        let launcher = runner.launcher.expect("Punisher launcher present 0");
        assert_eq!(launcher.capacity, 0);
        assert_eq!(launcher.used, 0);
        assert_eq!(
            slot_layout_lines(&runner),
            vec![
                ("Low slots: 1 of 5 used (4 left)".to_string(), false),
                ("Medium slots: 1 of 2 used (1 left)".to_string(), false),
                ("High slots: 1 of 4 used (3 left)".to_string(), false),
                ("Rigs: 0 of 3 used (3 left)".to_string(), false),
                ("Turret hardpoints: 0 of 4 used (4 left)".to_string(), false),
                (
                    "Launcher hardpoints: 0 of 0 used (0 left)".to_string(),
                    false
                ),
            ]
        );

        // Imported path: the sample EFT through synthesis —
        // 2 low (4 - 2 = 2 left), 2 medium (3 - 2 = 1 left),
        // 3 high of 3 (3 - 3 = 0 left) with 3 x 200mm
        // AutoCannon II 2889 (turret marker) -> turret 3 of 3
        // (3 - 3 = 0 left), 1 rig (3 - 1 = 2 left), launcher
        // 0 of 2 (2 - 0 = 2 left).
        let synth = match parse_eft(DEMO_SAMPLE_EFT, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        assert_eq!(
            slot_layout_lines(&layout_for(&synth)),
            vec![
                ("Low slots: 2 of 4 used (2 left)".to_string(), false),
                ("Medium slots: 2 of 3 used (1 left)".to_string(), false),
                ("High slots: 3 of 3 used (0 left)".to_string(), false),
                ("Rigs: 1 of 3 used (2 left)".to_string(), false),
                ("Turret hardpoints: 3 of 3 used (0 left)".to_string(), false),
                (
                    "Launcher hardpoints: 0 of 2 used (2 left)".to_string(),
                    false
                ),
            ]
        );

        // The DNA sample lands on the same Rifter layout by
        // synthesis (2048 low, 438/448 medium, 2889 x3 high
        // turret, 31668 rig), so its block is byte-identical
        // to the sample EFT above.
        let synth_dna = match parse_import(DEMO_SAMPLE_DNA, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => {
                panic!("demo DNA sample must import, got {fatal:?}")
            }
        };
        assert_eq!(
            slot_layout_lines(&layout_for(&synth_dna)),
            vec![
                ("Low slots: 2 of 4 used (2 left)".to_string(), false),
                ("Medium slots: 2 of 3 used (1 left)".to_string(), false),
                ("High slots: 3 of 3 used (0 left)".to_string(), false),
                ("Rigs: 1 of 3 used (2 left)".to_string(), false),
                ("Turret hardpoints: 3 of 3 used (0 left)".to_string(), false),
                (
                    "Launcher hardpoints: 0 of 2 used (2 left)".to_string(),
                    false
                ),
            ]
        );
    }

    fn dps_family(dps: f64, excluded: usize) -> FamilyDps {
        FamilyDps {
            dps,
            excluded_items: excluded,
        }
    }

    // Test 11: family lines byte-exact, including rounding of the
    // computed values and present-zero lines. Sample-EFT
    // arithmetic: 13.8 * 3.465 = 47.817; 47.817 / 3.75 = 12.7512
    // renders as 12.8; real autocannon 3.4375 renders as 3.4.
    #[test]
    fn dps_family_lines_match_the_locked_templates() {
        assert_eq!(
            dps_family_line("Turret", &dps_family(12.7512, 0)),
            "Turret DPS: 12.8 DPS"
        );
        assert_eq!(
            dps_family_line("Turret", &dps_family(3.4375, 0)),
            "Turret DPS: 3.4 DPS"
        );
        assert_eq!(
            dps_family_line("Launcher", &dps_family(0.0, 0)),
            "Launcher DPS: 0.0 DPS"
        );
        assert_eq!(
            dps_family_line("Drone", &dps_family(39.0, 0)),
            "Drone DPS: 39.0 DPS"
        );
        assert_eq!(
            dps_family_line("Fighter", &dps_family(270.0, 0)),
            "Fighter DPS: 270.0 DPS"
        );
        assert_eq!(
            dps_family_line("Drone", &dps_family(0.0, 0)),
            "Drone DPS: 0.0 DPS"
        );
    }

    // Test 10 (volley-ranges design section 8): volley and
    // range templates byte-exact, including rounding, line
    // order, and the `None`-contributes-no-line rule.
    // Sample-EFT arithmetic: volley 13.8 * 3.465 = 47.817
    // renders as 47.8; ranges 1200.0 / 1000.0 = 1.2,
    // 5160.0 / 1000.0 = 5.16 renders as 5.2. Real autocannon
    // 484 ranges: 800.0 / 1000.0 = 0.8, 4300.0 / 1000.0 = 4.3.
    #[test]
    fn dps_volley_and_range_lines_match_the_locked_templates() {
        assert_eq!(
            dps_volley_line(Some(47.817)).as_deref(),
            Some("Volley: 47.8 damage")
        );
        assert_eq!(
            dps_volley_line(Some(0.0)).as_deref(),
            Some("Volley: 0.0 damage")
        );
        assert_eq!(dps_volley_line(None), None);
        assert_eq!(
            dps_optimal_range_line(Some(1200.0)).as_deref(),
            Some("Turret optimal range: 1.2 km")
        );
        assert_eq!(
            dps_optimal_range_line(Some(800.0)).as_deref(),
            Some("Turret optimal range: 0.8 km")
        );
        assert_eq!(dps_optimal_range_line(None), None);
        assert_eq!(
            dps_falloff_range_line(Some(5160.0)).as_deref(),
            Some("Turret falloff range: 5.2 km")
        );
        assert_eq!(
            dps_falloff_range_line(Some(4300.0)).as_deref(),
            Some("Turret falloff range: 4.3 km")
        );
        assert_eq!(dps_falloff_range_line(None), None);

        // Locked order: family lines, volley, optimal,
        // falloff, excluded, unloaded.
        let dps = FittingDps {
            turrets: Some(dps_family(12.7512, 0)),
            launchers: Some(dps_family(0.0, 1)),
            drones: Some(dps_family(0.0, 0)),
            fighters: None,
            unloaded_weapons: 2,
            volley: Some(47.817),
            optimal_range: Some(1200.0),
            falloff_range: Some(5160.0),
        };
        assert_eq!(
            dps_lines(&dps),
            [
                "Turret DPS: 12.8 DPS".to_string(),
                "Launcher DPS: 0.0 DPS".to_string(),
                "Drone DPS: 0.0 DPS".to_string(),
                "Volley: 47.8 damage".to_string(),
                "Turret optimal range: 1.2 km".to_string(),
                "Turret falloff range: 5.2 km".to_string(),
                "Launcher DPS does not count 1 item with no damage data in Mimir's bundled item data."
                    .to_string(),
                "2 fitted weapons have no loaded charge listed, so they are not counted above."
                    .to_string(),
            ]
        );

        // Missile-only shape: volley present, no ranges.
        let dps = FittingDps {
            turrets: Some(dps_family(0.0, 0)),
            launchers: Some(dps_family(6.484375, 0)),
            drones: Some(dps_family(0.0, 0)),
            fighters: None,
            unloaded_weapons: 0,
            volley: Some(83.0),
            optimal_range: None,
            falloff_range: None,
        };
        assert_eq!(
            dps_lines(&dps),
            [
                "Turret DPS: 0.0 DPS".to_string(),
                "Launcher DPS: 6.5 DPS".to_string(),
                "Drone DPS: 0.0 DPS".to_string(),
                "Volley: 83.0 damage".to_string(),
            ]
        );

        // No volley and no ranges: family lines only.
        let dps = FittingDps {
            turrets: None,
            launchers: None,
            drones: Some(dps_family(0.0, 0)),
            fighters: None,
            unloaded_weapons: 0,
            volley: None,
            optimal_range: None,
            falloff_range: None,
        };
        assert_eq!(dps_lines(&dps), ["Drone DPS: 0.0 DPS".to_string()]);
    }

    // Test 12: excluded and unloaded templates byte-exact for
    // 0 (none), 1 (singular), 2+ (plural), in family order with
    // the unloaded line last.
    #[test]
    fn dps_excluded_and_unloaded_templates_and_ordering() {
        for label in ["Turret", "Launcher", "Drone", "Fighter"] {
            assert_eq!(dps_excluded_line(label, 0), None);
            assert_eq!(
                dps_excluded_line(label, 1).as_deref(),
                Some(
                    "Turret DPS does not count 1 item with no damage data in Mimir's bundled item data."
                        .replace("Turret", label)
                        .as_str()
                )
            );
            assert_eq!(
                dps_excluded_line(label, 2).as_deref(),
                Some(
                    "Turret DPS does not count 2 items with no damage data in Mimir's bundled item data."
                        .replace("Turret", label)
                        .as_str()
                )
            );
        }
        assert_eq!(dps_unloaded_line(0), None);
        assert_eq!(
            dps_unloaded_line(1).as_deref(),
            Some("1 fitted weapon has no loaded charge listed, so it is not counted above.")
        );
        assert_eq!(
            dps_unloaded_line(3).as_deref(),
            Some("3 fitted weapons have no loaded charge listed, so they are not counted above.")
        );

        // Ordering: family lines in Turret/Launcher/Drone/Fighter
        // order, excluded lines in the same order, unloaded last.
        let dps = FittingDps {
            turrets: Some(dps_family(12.7512, 1)),
            launchers: Some(dps_family(0.0, 2)),
            drones: Some(dps_family(0.0, 0)),
            fighters: Some(dps_family(270.0, 3)),
            unloaded_weapons: 1,
            volley: None,
            optimal_range: None,
            falloff_range: None,
        };
        assert_eq!(
            dps_lines(&dps),
            [
                "Turret DPS: 12.8 DPS".to_string(),
                "Launcher DPS: 0.0 DPS".to_string(),
                "Drone DPS: 0.0 DPS".to_string(),
                "Fighter DPS: 270.0 DPS".to_string(),
                "Turret DPS does not count 1 item with no damage data in Mimir's bundled item data."
                    .to_string(),
                "Launcher DPS does not count 2 items with no damage data in Mimir's bundled item data."
                    .to_string(),
                "Fighter DPS does not count 3 items with no damage data in Mimir's bundled item data."
                    .to_string(),
                "1 fitted weapon has no loaded charge listed, so it is not counted above."
                    .to_string(),
            ]
        );
        // None families contribute no line.
        let dps = FittingDps {
            turrets: None,
            launchers: None,
            drones: Some(dps_family(0.0, 0)),
            fighters: None,
            unloaded_weapons: 0,
            volley: None,
            optimal_range: None,
            falloff_range: None,
        };
        assert_eq!(dps_lines(&dps), ["Drone DPS: 0.0 DPS".to_string()]);
    }

    // Test 13 (volley-ranges design section 8): heading,
    // disclosure, and both unavailable sentences byte-exact.
    // Only the disclosure moves; heading and unavailable
    // sentences are byte-identical to shipped.
    #[test]
    fn dps_unavailable_and_disclosure_wording() {
        assert_eq!(FITTINGS_DPS_HEADING, "Damage per second (base values)");
        assert_eq!(
            FITTING_DPS_NO_CATALOGUE,
            "Damage per second unavailable: Mimir's bundled item data failed to load."
        );
        assert_eq!(
            FITTING_DPS_NO_SHIP_DATA,
            "Damage per second unavailable: Mimir's bundled item data has no damage data for this fitting's ship."
        );
        assert_eq!(
            FITTING_DPS_DISCLOSURE,
            "Base damage per second from Mimir's bundled item data: base charge, drone, and fighter damage per firing cycle, with no skill, implant, ship, module, rig, or subsystem bonuses applied. Turret and launcher damage counts only a loaded charge listed after the module in imported EFT text, exactly as listed; saved and DNA fittings list no loaded charges, and no charge is assumed. Volley is the turret and launcher damage in one firing cycle from those same listed charges; drone and fighter damage is not in the volley. Turret optimal and falloff ranges are averages of the fitted turrets' base ranges, weighted by each turret's share of the turret volley, and each is shown only when every counted turret has that range in the bundled data. Fitted weapons are treated as online, drones and fighters as launched up to the ship's base drone bandwidth and fighter tubes, and every shot is counted at full damage, with no tracking, missile application, reload time, or flight time applied. No combined damage-per-second total is shown, because any family's damage can be unknown while another's is counted."
        );
    }

    // Test 14 (volley-ranges design section 8, demo pins):
    // demo pins extended by volley-ranges design section 7.
    // Demo Brawler/Mission Runner/Demo Runner are saved
    // fittings on zero-bandwidth hulls: `Drone DPS: 0.0 DPS`
    // only, no volley or range lines. Sample EFT: Turret DPS
    // 12.8 from one listed charge (13.8 * 3.465 = 47.817;
    // 47.817 / 3.75 = 12.7512), volley 47.817 rendering as
    // 47.8, optimal 1200.0 rendering as 1.2 km, falloff
    // 5160.0 / 1000.0 = 5.16 rendering as 5.2 km, plus a
    // 2-unloaded line. Sample DNA: no volley or range
    // lines, 3-unloaded line. No fighter line anywhere.
    #[test]
    fn demo_fixture_fitting_dps_match_the_locked_demo_story() {
        use crate::demo::data::DEMO_FITTINGS_JSON;

        #[derive(Debug, serde::Deserialize)]
        struct DemoFittingEntry {
            fittings: Vec<CharacterFitting>,
        }

        let by_character: HashMap<String, DemoFittingEntry> =
            serde_json::from_str(DEMO_FITTINGS_JSON).expect("demo fittings fixture parses");
        let all: Vec<CharacterFitting> = by_character
            .values()
            .flat_map(|entry| entry.fittings.iter().cloned())
            .collect();
        let find = |name: &str| {
            all.iter()
                .find(|f| f.name == name)
                .unwrap_or_else(|| panic!("demo fitting {name} present"))
                .clone()
        };
        let catalogue = FittingTypes::load_bundled().expect("bundled catalogue loads");
        let dps_for = |fitting: &CharacterFitting| match fitting_dps(fitting, None, &catalogue) {
            FittingDpsOutcome::Available(dps) => dps,
            FittingDpsOutcome::Unavailable => panic!("demo fitting must have damage data"),
        };

        for name in ["Demo Brawler", "Mission Runner", "Demo Runner"] {
            let dps = dps_for(&find(name));
            assert!(dps.turrets.is_none(), "{name} has no turret family");
            assert!(dps.launchers.is_none(), "{name} has no launcher family");
            let drones = dps.drones.expect("zero-bandwidth hull carries drones");
            assert!(
                (drones.dps - 0.0).abs() < 1e-9,
                "{name} drone DPS is 0.0, got {}",
                drones.dps
            );
            assert_eq!(drones.excluded_items, 0, "{name} drone excluded");
            assert!(dps.fighters.is_none(), "{name} has no fighter family");
            assert_eq!(dps.unloaded_weapons, 0, "{name} unloaded");
            assert_eq!(dps.volley, None, "{name} has no volley on saved surface");
            assert_eq!(
                dps.optimal_range, None,
                "{name} has no optimal range on saved surface"
            );
            assert_eq!(
                dps.falloff_range, None,
                "{name} has no falloff range on saved surface"
            );
            assert_eq!(dps_lines(&dps), ["Drone DPS: 0.0 DPS".to_string()]);
        }

        // Sample EFT: three 200mm AutoCannon II candidates, one
        // with Republic Fleet EMP S (10.35 + 2.3 + 1.15 + 0.0
        // = 13.8; 13.8 * 3.465 = 47.817; 47.817 / 3.75 = 12.7512).
        // The counted turret is the whole turret volley, so both
        // weighted averages are its own ranges: 2889 maxRange
        // 1200.0, falloff 5160.0.
        let imported = match parse_eft(DEMO_SAMPLE_EFT, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting,
            EftImportOutcome::Failed(fatal) => panic!("demo sample must import, got {fatal:?}"),
        };
        let synth = imported.to_character_fitting();
        let sample = match fitting_dps(&synth, Some(&imported), &catalogue) {
            FittingDpsOutcome::Available(dps) => dps,
            FittingDpsOutcome::Unavailable => panic!("demo sample must have damage data"),
        };
        let turrets = sample.turrets.expect("EFT carries turrets");
        assert!(
            (turrets.dps - 12.7512).abs() < 1e-9,
            "turret DPS is 12.7512, got {}",
            turrets.dps
        );
        assert_eq!(turrets.excluded_items, 0);
        let launchers = sample.launchers.expect("EFT carries launchers");
        assert!((launchers.dps - 0.0).abs() < 1e-9);
        assert_eq!(launchers.excluded_items, 0);
        assert!((sample.drones.expect("drones").dps - 0.0).abs() < 1e-9);
        assert!(sample.fighters.is_none());
        assert_eq!(sample.unloaded_weapons, 2);
        let volley = sample.volley.expect("EFT sample carries volley");
        assert!(
            (volley - 47.817).abs() < 1e-9,
            "volley is 47.817, got {volley}"
        );
        let optimal = sample.optimal_range.expect("EFT sample carries optimal");
        assert!(
            (optimal - 1200.0).abs() < 1e-9,
            "optimal is 1200.0, got {optimal}"
        );
        let falloff = sample.falloff_range.expect("EFT sample carries falloff");
        assert!(
            (falloff - 5160.0).abs() < 1e-9,
            "falloff is 5160.0, got {falloff}"
        );
        assert_eq!(
            dps_lines(&sample),
            [
                "Turret DPS: 12.8 DPS".to_string(),
                "Launcher DPS: 0.0 DPS".to_string(),
                "Drone DPS: 0.0 DPS".to_string(),
                "Volley: 47.8 damage".to_string(),
                "Turret optimal range: 1.2 km".to_string(),
                "Turret falloff range: 5.2 km".to_string(),
                "2 fitted weapons have no loaded charge listed, so they are not counted above."
                    .to_string(),
            ]
        );

        // Sample DNA: three turret candidates, no pairings.
        let imported_dna = match parse_import(DEMO_SAMPLE_DNA, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting,
            EftImportOutcome::Failed(fatal) => panic!("demo DNA must import, got {fatal:?}"),
        };
        let synth_dna = imported_dna.to_character_fitting();
        let dna = match fitting_dps(&synth_dna, Some(&imported_dna), &catalogue) {
            FittingDpsOutcome::Available(dps) => dps,
            FittingDpsOutcome::Unavailable => panic!("demo DNA must have damage data"),
        };
        assert!(dna.turrets.is_none());
        assert!(dna.launchers.is_none());
        assert!((dna.drones.expect("DNA drones").dps - 0.0).abs() < 1e-9);
        assert!(dna.fighters.is_none());
        assert_eq!(dna.unloaded_weapons, 3);
        assert_eq!(dna.volley, None);
        assert_eq!(dna.optimal_range, None);
        assert_eq!(dna.falloff_range, None);
        assert_eq!(
            dps_lines(&dna),
            [
                "Drone DPS: 0.0 DPS".to_string(),
                "3 fitted weapons have no loaded charge listed, so they are not counted above."
                    .to_string(),
            ]
        );

        // No fighter line anywhere in demo.
        for name in ["Demo Brawler", "Mission Runner", "Demo Runner"] {
            assert!(
                dps_lines(&dps_for(&find(name)))
                    .iter()
                    .all(|line| !line.starts_with("Fighter DPS")),
                "demo has no fighter damage line"
            );
        }
        assert!(
            dps_lines(&sample)
                .iter()
                .all(|line| !line.starts_with("Fighter DPS")),
            "sample has no fighter damage line"
        );
        assert!(
            dps_lines(&dna)
                .iter()
                .all(|line| !line.starts_with("Fighter DPS")),
            "DNA sample has no fighter damage line"
        );
    }

    fn type_fixture_row(id: i64) -> CharacterRow {
        CharacterRow {
            character_id: id,
            name: "Test Pilot".to_string(),
            corporation_id: 1000166,
            alliance_id: None,
            is_active: false,
        }
    }

    fn type_fixture_item(type_id: i64) -> FittingItem {
        FittingItem {
            flag: "Cargo".to_string(),
            quantity: 1,
            type_id,
        }
    }

    fn type_fixture_ship(ship_type_id: i64) -> CharacterFitting {
        CharacterFitting {
            fitting_id: ship_type_id,
            name: "Fitting".to_string(),
            description: None,
            ship_type_id,
            items: Vec::new(),
        }
    }

    /// The design section 10 fixture: characters 1 and 2,
    /// `fittings` Ready with fitting A (ship 587, items 2048
    /// and 34) and fitting B (ship 597, item 178).
    fn type_fixture_state() -> AppState {
        let mut fitting_a = type_fixture_ship(587);
        fitting_a.items = vec![type_fixture_item(2048), type_fixture_item(34)];
        let mut fitting_b = type_fixture_ship(597);
        fitting_b.items = vec![type_fixture_item(178)];
        AppState {
            characters: vec![type_fixture_row(1), type_fixture_row(2)],
            fittings: LoadState::Ready(FittingsData {
                fittings: Ok(vec![fitting_a, fitting_b]),
            }),
            ..AppState::default()
        }
    }

    #[test]
    fn render_fitting_items_ensures_only_rendered_rows() {
        // Low 2048, Low 2048 again (a second fitted copy), and
        // Cargo 34 render through `Some`; section order puts Low
        // first and the duplicate dedupes to one request.
        let resolver = test_resolver();
        let fitting = fitting_with_items(vec![
            item("LoSlot0", 1, 2048),
            item("LoSlot1", 1, 2048),
            item("Cargo", 1, 34),
        ]);
        let rows = fitting_item_rows(&fitting, &resolver);
        let mut state = type_fixture_state();
        let mut cache = PortraitImageCache::new();
        let ctx = egui::Context::default();
        let _ = ctx.run(egui::RawInput::default(), |ctx| {
            egui::CentralPanel::default().show(ctx, |ui| {
                render_fitting_items(ui, &rows, Some((&mut state, &mut cache)));
            });
        });
        assert_eq!(
            state.portrait_requests,
            vec![(ImageKind::Type, 2048), (ImageKind::Type, 34)]
        );

        // A second run queues nothing further: every key has
        // left `NotRequested`.
        let _ = ctx.run(egui::RawInput::default(), |ctx| {
            egui::CentralPanel::default().show(ctx, |ui| {
                render_fitting_items(ui, &rows, Some((&mut state, &mut cache)));
            });
        });
        assert_eq!(
            state.portrait_requests,
            vec![(ImageKind::Type, 2048), (ImageKind::Type, 34)]
        );
    }

    #[test]
    fn render_fitting_items_imported_path_never_ensures() {
        // The same rows through `None` leave the request queue
        // and the texture cache empty: the user-pasted detail
        // never ensures.
        let resolver = test_resolver();
        let fitting = fitting_with_items(vec![
            item("LoSlot0", 1, 2048),
            item("LoSlot1", 1, 2048),
            item("Cargo", 1, 34),
        ]);
        let rows = fitting_item_rows(&fitting, &resolver);
        let state = type_fixture_state();
        let cache = PortraitImageCache::new();
        let ctx = egui::Context::default();
        let _ = ctx.run(egui::RawInput::default(), |ctx| {
            egui::CentralPanel::default().show(ctx, |ui| {
                render_fitting_items(ui, &rows, None);
            });
        });
        assert!(state.portrait_requests.is_empty());
        assert!(cache.is_empty());
    }

    #[test]
    fn render_fitting_items_cap_bounds_ensures_at_100() {
        // One Cargo section with 101 distinct guard-known ids
        // (1001 through 1101) renders through `Some` and queues
        // exactly 100 requests: the truncated row never ensures.
        let fitting = fitting_with_items((1001..=1101).map(|id| item("Cargo", 1, id)).collect());
        let resolver = test_resolver();
        let rows = fitting_item_rows(&fitting, &resolver);
        assert_eq!(rows.len(), 101);
        let mut guard_fitting = type_fixture_ship(587);
        guard_fitting.items = (1001..=1101).map(type_fixture_item).collect();
        let mut state = AppState {
            characters: vec![type_fixture_row(1), type_fixture_row(2)],
            fittings: LoadState::Ready(FittingsData {
                fittings: Ok(vec![guard_fitting]),
            }),
            ..AppState::default()
        };
        let mut cache = PortraitImageCache::new();
        let ctx = egui::Context::default();
        let _ = ctx.run(egui::RawInput::default(), |ctx| {
            egui::CentralPanel::default().show(ctx, |ui| {
                render_fitting_items(ui, &rows, Some((&mut state, &mut cache)));
            });
        });
        assert_eq!(state.portrait_requests.len(), 100);
        assert!(
            !state.portrait_requests.contains(&(ImageKind::Type, 1101)),
            "the truncated row must never ensure"
        );
    }

    fn editor_test_fitting(format: ImportFormat) -> ImportedFitting {
        ImportedFitting {
            name: "Sample Brawler".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
            format,
            items: Vec::new(),
            report: ImportReport {
                imported_lines: 7,
                placeholder_lines: 0,
                charges_noted: 0,
                issues: Vec::new(),
            },
        }
    }

    #[test]
    fn editor_edited_suffix_only_after_successful_edit() {
        // Locked test 14 (summary half): the suffix appears only
        // when the edited flag is set, for both formats.
        let eft = editor_test_fitting(ImportFormat::Eft);
        assert_eq!(
            imported_summary_line_edited(&eft, false),
            "Imported \"Sample Brawler\" (Rifter): 0 items from 7 lines."
        );
        assert_eq!(
            imported_summary_line_edited(&eft, true),
            "Imported \"Sample Brawler\" (Rifter): 0 items from 7 lines. Edited since import."
        );
        assert_eq!(
            imported_summary_line_edited(&eft, false),
            imported_summary_line(&eft)
        );
        let dna = editor_test_fitting(ImportFormat::Dna);
        assert_eq!(
            imported_summary_line_edited(&dna, false),
            "Imported \"Sample Brawler\" (Rifter): 0 items from 7 segments."
        );
        assert_eq!(
            imported_summary_line_edited(&dna, true),
            "Imported \"Sample Brawler\" (Rifter): 0 items from 7 segments. Edited since import."
        );
    }

    #[test]
    fn editor_refusal_templates_match_import_wording_verbatim() {
        // Locked test 14 (refusal half): string equality against
        // the importer's reason strings, one case per editor
        // refusal kind.
        let cases = [
            (EditRefusal::UnknownName, ImportIssueKind::UnknownName),
            (EditRefusal::AmbiguousName, ImportIssueKind::AmbiguousName),
            (EditRefusal::NotAModule, ImportIssueKind::NotAModule),
            (
                EditRefusal::NoSlotForModule,
                ImportIssueKind::NoSlotForModule,
            ),
            (EditRefusal::StackedModule, ImportIssueKind::StackedModule),
            (
                EditRefusal::InvalidQuantity,
                ImportIssueKind::InvalidQuantity,
            ),
            (
                EditRefusal::QuantityTooLarge,
                ImportIssueKind::QuantityTooLarge,
            ),
        ];
        for (refusal, kind) in cases {
            assert_eq!(
                add_refusal_message(refusal),
                format!("Could not add: {}.", kind.reason())
            );
            assert_eq!(
                quantity_refusal_message(refusal),
                format!("Could not set the quantity: {}.", kind.reason())
            );
        }
        assert_eq!(
            add_refusal_message(EditRefusal::UnknownName),
            "Could not add: no item in Mimir's bundled data has this exact name."
        );
        assert_eq!(
            quantity_refusal_message(EditRefusal::InvalidQuantity),
            "Could not set the quantity: the quantity must be a whole number from 1 to 2,147,483,647, written like x5."
        );
    }

    #[test]
    fn editor_successful_edit_disarms_save_confirmation() {
        // Locked test 15: arming then editing disarms; the
        // bookkeeping also clears the refusal and the quantity
        // drafts and marks the draft edited.
        let mut state = AppState::new(false);
        state.active_character_id = Some(42);
        state.fittings_write_confirm = Some(FittingWriteConfirm::SaveImported { character_id: 42 });
        state.fittings_editor_error = Some("Could not add: refused.".to_string());
        state.fittings_editor_quantity.insert(0, "9".to_string());
        note_successful_edit(&mut state);
        assert_eq!(state.fittings_write_confirm, None);
        assert!(state.fittings_import_edited);
        assert_eq!(state.fittings_editor_error, None);
        assert!(state.fittings_editor_quantity.is_empty());
    }

    #[test]
    fn editor_clear_drops_all_editor_fields() {
        let mut state = AppState::new(false);
        state.fittings_editor_add_name = "Damage Control II".to_string();
        state.fittings_editor_add_quantity = "5".to_string();
        state.fittings_editor_error = Some("Could not add: refused.".to_string());
        state.fittings_import_edited = true;
        state.fittings_editor_quantity.insert(2, "3".to_string());
        state.fittings_editor_name = Some("Renamed".to_string());
        clear_editor_state(&mut state);
        assert_eq!(state.fittings_editor_add_name, "");
        assert_eq!(state.fittings_editor_add_quantity, "");
        assert_eq!(state.fittings_editor_error, None);
        assert!(!state.fittings_import_edited);
        assert!(state.fittings_editor_quantity.is_empty());
        assert_eq!(state.fittings_editor_name, None);
    }

    #[test]
    fn imported_item_rows_preserve_draft_order_and_stacked_flags() {
        // The imported rows carry draft indices in the same
        // section order the saved renderer uses.
        use crate::fitting::eft::{ImportedCharge, ImportedItem};
        let resolver = test_resolver();
        let imported = ImportedFitting {
            name: "T".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
            format: ImportFormat::Eft,
            items: vec![
                ImportedItem {
                    type_id: 34,
                    name: "Nanite Repair Paste".to_string(),
                    section: ImportSection::Cargo,
                    quantity: 8,
                    charge: None,
                },
                ImportedItem {
                    type_id: 2048,
                    name: "Demo Small Railgun".to_string(),
                    section: ImportSection::High,
                    quantity: 1,
                    charge: Some(ImportedCharge {
                        type_id: 1,
                        name: "Charge".to_string(),
                    }),
                },
                ImportedItem {
                    type_id: 2456,
                    name: "Hobgoblin II".to_string(),
                    section: ImportSection::Drones,
                    quantity: 5,
                    charge: None,
                },
            ],
            report: ImportReport {
                imported_lines: 3,
                placeholder_lines: 0,
                charges_noted: 1,
                issues: Vec::new(),
            },
        };
        let rows = imported_item_rows(&imported, &resolver);
        assert_eq!(rows.len(), 3);
        // High before Drones before Cargo, like SECTION_ORDER.
        assert_eq!(rows[0].index, 1);
        assert_eq!(rows[0].section, FittingSection::High);
        assert!(!rows[0].stacked);
        assert_eq!(rows[1].index, 2);
        assert_eq!(rows[1].section, FittingSection::Drones);
        assert!(rows[1].stacked);
        assert_eq!(rows[2].index, 0);
        assert_eq!(rows[2].section, FittingSection::Cargo);
        assert!(rows[2].stacked);
        // The rendered text matches the saved renderer's shape.
        assert_eq!(rows[0].type_name, "Demo Small Railgun");
        assert_eq!(rows[1].quantity, 5);
        assert_eq!(rows[2].quantity, 8);
    }

    #[test]
    fn imported_item_rows_match_saved_row_order() {
        // Order parity with `fitting_item_rows` over a fitting
        // with more than ten same-section items (the flag sort is
        // lexicographic, so a naive regroup would drift).
        use crate::fitting::eft::ImportedItem;
        let resolver = test_resolver();
        let items: Vec<ImportedItem> = (0..12)
            .map(|_| ImportedItem {
                type_id: 2048,
                name: "Demo Small Railgun".to_string(),
                section: ImportSection::High,
                quantity: 1,
                charge: None,
            })
            .collect();
        let imported = ImportedFitting {
            name: "T".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
            format: ImportFormat::Eft,
            items,
            report: ImportReport {
                imported_lines: 12,
                placeholder_lines: 0,
                charges_noted: 0,
                issues: Vec::new(),
            },
        };
        let synth = imported.to_character_fitting();
        let saved = fitting_item_rows(&synth, &resolver);
        let rows = imported_item_rows(&imported, &resolver);
        assert_eq!(rows.len(), saved.len());
        for (mine, theirs) in rows.iter().zip(saved.iter()) {
            assert_eq!(mine.type_id, theirs.type_id);
            assert_eq!(mine.type_name, theirs.type_name);
            assert_eq!(mine.section, theirs.section);
            assert_eq!(mine.quantity, theirs.quantity);
        }
    }
}
