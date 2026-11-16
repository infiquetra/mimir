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
use crate::fitting::dna::parse_import;
use crate::fitting::eft::{EftImportOutcome, ImportFormat, ImportIssue, ImportedFitting};
use crate::fitting::resources::{fitting_resources, FittingResources, ResourceBudget};
use crate::fitting::write_map::{build_save_request, DropReason, DroppedFittingItem, SaveMapping};
use crate::names::fitting_types::FittingTypes;
use crate::names::resolver::NameResolver;
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
/// sentence stays at the callers.
fn render_fitting_items(ui: &mut egui::Ui, item_rows: &[FittingItemRow]) {
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
            if is_slot && row.quantity == 1 {
                ui.label(&row.type_name);
            } else {
                ui.label(format!("{} x{}", row.type_name, row.quantity));
            }
        }
    }
}

/// Locked heading for the base resource block (design section 7).
const FITTINGS_RESOURCES_HEADING: &str = "Fitting resources (base values)";

/// Locked disclosure: the numbers are base values only, never
/// in-game totals (design section 4).
const FITTING_RESOURCES_DISCLOSURE: &str = "Base values from Mimir's bundled item data. Skills, implants, and bonuses from modules, rigs, subsystems, and the ship itself are not applied, so these numbers can differ from EVE.";

const FITTING_RESOURCES_NO_CATALOGUE: &str =
    "Fitting resources unavailable: Mimir's bundled item data failed to load.";
const FITTING_RESOURCES_NO_SHIP_OUTPUT: &str = "Fitting resources unavailable: Mimir's bundled item data has no ship output data for this fitting's ship.";

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

/// Base CPU and power grid block shared by the saved and imported
/// fitting details (design section 7). Renders even when the
/// fitting has no items. Logs nothing itself: the pure function
/// already logged counts.
fn render_fitting_resources(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
) {
    ui.heading(FITTINGS_RESOURCES_HEADING);
    let Some(catalogue) = fitting_types else {
        ui.label(FITTING_RESOURCES_NO_CATALOGUE);
        return;
    };
    match fitting_resources(fitting, catalogue) {
        FittingResources::ShipNoOutput => {
            ui.label(FITTING_RESOURCES_NO_SHIP_OUTPUT);
        }
        FittingResources::Available { cpu, power } => {
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
                }
                EftImportOutcome::Failed(fatal) => {
                    tracing::info!("[FITTING] import failed fatal={fatal:?}");
                    state.fittings_imported = None;
                    state.fittings_import_error = Some(fatal.message().to_string());
                    state.fittings_import_owner = state.active_character_id;
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
        }
        if state.demo && ui.button("Use sample EFT").clicked() {
            tracing::debug!("[FITTING] demo sample EFT loaded");
            state.fittings_import_text = DEMO_SAMPLE_EFT.to_string();
            state.fittings_imported = None;
            state.fittings_import_error = None;
            state.fittings_import_owner = None;
        }
        if state.demo && ui.button("Use sample DNA").clicked() {
            tracing::debug!("[FITTING] demo sample DNA loaded");
            state.fittings_import_text = DEMO_SAMPLE_DNA.to_string();
            state.fittings_imported = None;
            state.fittings_import_error = None;
            state.fittings_import_owner = None;
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
    let Some(imported) = state.fittings_imported.clone() else {
        return;
    };
    ui.label(imported_summary_line(&imported));
    ui.label("Imported fitting");
    if let Some(note) = placeholder_note(imported.report.placeholder_lines) {
        ui.label(note);
    }
    if let Some(note) = charges_note(imported.report.charges_noted) {
        ui.label(note);
    }
    let synth = imported.to_character_fitting();
    let local_resolver = imported.name_resolver();
    let item_rows = fitting_item_rows(&synth, &local_resolver);
    if item_rows.is_empty() {
        ui.label("This fitting has no items to show.");
    } else {
        render_fitting_items(ui, &item_rows);
    }
    render_fitting_resources(ui, &synth, fitting_types);
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
) {
    ui.heading("Fittings");
    widgets::mode_notice(ui, state.demo, state.offline);
    if state.active_character().is_none() {
        widgets::no_character_panel(ui);
        return;
    }
    // Import needs no ESI read scope: render it before the LoadState
    // match so it works while saved fittings load, fail, or await a
    // step-up grant (design section 8.2).
    fittings_import_panel(ui, state, fitting_types);
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
                    ui.label(resolver.name(selected.ship_type_id));
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
                        render_fitting_items(ui, &item_rows);
                    }
                    render_fitting_resources(ui, selected, fitting_types);
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
}
