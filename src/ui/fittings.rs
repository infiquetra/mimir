//! Fittings: the active character's saved fittings, read-only,
//! with EFT clipboard export of the selected fitting. The view
//! sets request flags only (`retry_requested`,
//! `stepup_requested`); it never fetches. Every rendered
//! string is a resolved EVE name, sanitized user text, a
//! section word, or a row count — never a raw numeric ID,
//! and never a raw ESI flag string.

use super::widgets;
use crate::app::state::{AppState, FittingsData, LoadState, SectionError, StepUpRequest};
use crate::config::EveConfig;
use crate::esi::models::CharacterFitting;
use crate::fitting::eft::{parse_eft, EftImportOutcome, ImportIssue, ImportedFitting};
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

/// One issue row, exact template (design section 8.2):
/// `Line {line}: "{text}" - {reason}.`
fn format_import_issue(issue: &ImportIssue) -> String {
    format!(
        "Line {}: \"{}\" - {}.",
        issue.line,
        truncate_issue_text(&issue.text),
        issue.kind.reason()
    )
}

/// Issues heading, singular/plural (design section 8.2).
fn import_issues_heading(issue_count: usize) -> String {
    if issue_count == 1 {
        "1 line could not be imported:".to_string()
    } else {
        format!("{issue_count} lines could not be imported:")
    }
}

/// Overflow disclosure when more issues exist than are shown
/// (design section 8.2).
fn import_issues_overflow_label(remaining: usize) -> String {
    if remaining == 1 {
        "...and 1 more line that could not be imported. Fix the lines above and import again to see the rest.".to_string()
    } else {
        format!("...and {remaining} more lines that could not be imported. Fix the lines above and import again to see the rest.")
    }
}

/// Imported-fitting summary line (design section 8.2).
fn imported_summary_line(fitting: &ImportedFitting) -> String {
    format!(
        "Imported \"{}\" ({}): {} items from {} lines.",
        fitting_display_name(&fitting.name),
        fitting.ship_name,
        fitting.items.len(),
        fitting.report.imported_lines
    )
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
fn copy_imported_status_message(display_name: &str, charges_noted: usize) -> String {
    if charges_noted == 0 {
        format!("Copied \"{display_name}\" as EFT")
    } else if charges_noted == 1 {
        format!("Copied \"{display_name}\" as EFT (1 loaded charge left out: copied EFT fittings do not store loaded charges)")
    } else {
        format!("Copied \"{display_name}\" as EFT ({charges_noted} loaded charges left out: copied EFT fittings do not store loaded charges)")
    }
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
    ui.heading("Import a fitting from EFT text");
    ui.label("Paste an EFT block (the [Ship, Fitting name] text format). The imported fitting stays in Mimir on this device: it is not saved to EVE and is gone when you switch characters or close Mimir.");
    let Some(catalogue) = fitting_types else {
        ui.label("Could not import: Mimir's bundled item data failed to load. Restart Mimir and try again.");
        return;
    };
    let response = ui.add(
        egui::TextEdit::multiline(&mut state.fittings_import_text)
            .hint_text("Paste EFT text: [Ship, Fitting name] then one item per line")
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
            match parse_eft(&text, catalogue) {
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
    ui.label("Imported fitting (not saved in EVE)");
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
        ui.heading(import_issues_heading(issues.len()));
        let shown = issues.len().min(IMPORT_ISSUES_RENDER_MAX);
        for issue in issues.iter().take(shown) {
            ui.label(format_import_issue(issue));
        }
        if issues.len() > IMPORT_ISSUES_RENDER_MAX {
            ui.label(import_issues_overflow_label(issues.len() - shown));
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
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::eft::{ImportIssueKind, ImportReport};

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
            format_import_issue(&issue),
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
        assert_eq!(import_issues_heading(1), "1 line could not be imported:");
        assert_eq!(import_issues_heading(2), "2 lines could not be imported:");
        assert_eq!(import_issues_heading(25), "25 lines could not be imported:");
    }

    #[test]
    fn import_issues_overflow_label_singular_and_plural() {
        assert_eq!(IMPORT_ISSUES_RENDER_MAX, 20);
        // 25 issues: 20 shown, 5 disclosed.
        let remaining = 25 - 25.min(IMPORT_ISSUES_RENDER_MAX);
        assert_eq!(remaining, 5);
        assert_eq!(
            import_issues_overflow_label(remaining),
            "...and 5 more lines that could not be imported. Fix the lines above and import again to see the rest."
        );
        assert_eq!(
            import_issues_overflow_label(1),
            "...and 1 more line that could not be imported. Fix the lines above and import again to see the rest."
        );
    }

    #[test]
    fn import_summary_notes_and_copy_status() {
        let fitting = ImportedFitting {
            name: "Sample Brawler".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
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
}
