//! Skills: queue with live finish countdowns and the SDE catalogue.
//! Skill names always come from the SDE, never raw IDs.

use std::collections::BTreeMap;

use chrono::Utc;

use super::portraits::{
    ensure_type_icon_requested, show_type_icon, PortraitImageCache, TYPE_ICON_PX,
};
use super::widgets;
use crate::app::state::{AppState, LoadState, SkillPlanConfirm, SkillPlanEditor};
use crate::esi::models::{CharacterAttributes, SkillQueueItem};
use crate::names::sde::{Sde, SdeSkillType};
use crate::skills::plans::{normalize_plan_text, SkillPlan, SkillPlanAction, SkillPlanEntry};
use crate::skills::prereqs::{plan_prerequisite_warnings, unmet_prerequisites, UnmetPrerequisite};
use crate::skills::training::{plan_progress, EntryEstimate, PlanProgress, TrainedSkill};

/// Global rendered-row budget for the skill catalogue: at
/// most this many skill rows render (and therefore ensure icons)
/// per frame, matching the assets view's global cap. The
/// budget is spent inside the collapsing bodies, so a collapsed
/// group renders and ensures nothing.
pub const SKILLS_CATALOGUE_RENDER_MAX: usize = 100;

/// One catalogue line: a skill row carries its bundled skill
/// type id for the icon; a prerequisite line carries none.
struct CatalogueRow {
    /// `Some` for a skill row (icon + name), `None` for its
    /// prerequisite line (text only). State-only: never
    /// formatted into a rendered string, never logged.
    skill_type_id: Option<i64>,
    text: String,
}

/// Queue sorted into training order (input order is not trusted).
pub fn sorted_queue(queue: &[SkillQueueItem]) -> Vec<&SkillQueueItem> {
    let mut sorted: Vec<&SkillQueueItem> = queue.iter().collect();
    sorted.sort_by_key(|item| item.queue_position);
    sorted
}

/// Trained level per skill id, for catalogue display.
pub fn trained_levels(state: &AppState) -> BTreeMap<i64, i32> {
    match state.skills.as_ready() {
        Some(data) => data
            .skills
            .skills
            .iter()
            .map(|s| (s.skill_id, s.trained_skill_level))
            .collect(),
        None => BTreeMap::new(),
    }
}

// --- Skill plans (design section 8) ---
//
// Every user-visible string below is verbatim-locked; the
// small pure fns/consts let section 12's T18 pin them
// without a frame. Skill names always resolve through `Sde`
// (`skill_name_quiet` for per-frame rows); a raw numeric
// skill id never renders. Numbers render through
// `widgets::format_sp`, durations through
// `widgets::format_countdown(minutes * 60)`.

const SKILL_PLANS_HEADING: &str = "Skill plans";
const SKILL_PLANS_DEMO_LABEL: &str =
    "Demo mode: skill plans are kept in memory for this session and are not saved.";
const SKILL_PLANS_DISCLOSURE: &str = "Estimates use this character's current attributes as loaded. They ignore the training queue and any future attribute remap.";

/// Locked delete heading (design section 8.4).
fn delete_plan_heading(name: &str) -> String {
    format!("Delete plan \"{name}\"?")
}

/// Locked delete summary: the entry count is a bare number
/// with a plural noun even at 1, following the fittings copy
/// precedent (design section 8.4).
fn delete_plan_summary(name: &str, entry_count: usize) -> String {
    format!("\"{name}\" and its {entry_count} entries will be deleted from this device. This cannot be undone.")
}

/// Locked remove heading (design section 8.4).
fn remove_entry_heading(skill_name: &str, plan_name: &str) -> String {
    format!("Remove \"{skill_name}\" from \"{plan_name}\"?")
}

/// Locked remove summary (design section 8.4).
fn remove_entry_summary(skill_name: &str) -> String {
    format!(
        "\"{skill_name}\" will be removed from this plan. Trained levels in EVE are not changed."
    )
}

/// One plan's list summary line (design section 8.2). A total
/// part is shown only when present and positive; an unknown
/// total simply omits its part — the list never shows a
/// partial total and never explains at length.
fn plan_list_summary(progress: &PlanProgress, trained_loaded: bool) -> String {
    let total = progress.entries.len();
    if total == 0 {
        return "No skills in this plan yet.".to_string();
    }
    if !trained_loaded {
        return if total == 1 {
            "1 skill".to_string()
        } else {
            format!("{total} skills")
        };
    }
    let mut line = format!("{} of {total} complete", progress.complete_count);
    if let Some(sp) = progress.total_sp_remaining {
        if sp > 0 {
            line += &format!(" — {} remaining", widgets::format_sp(sp));
        }
    }
    if let Some(minutes) = progress.total_minutes {
        if minutes > 0 {
            line += &format!(" — about {}", widgets::format_countdown(minutes * 60));
        }
    }
    line
}

/// The totals block under a plan's entries (design section
/// 8.4): exactly one of the six locked lines. Empty beats
/// not-loaded (the section 8.6 table words the empty selected
/// plan unconditionally); all-complete beats the total forms
/// (a fully trained plan has no remaining SP to total).
fn plan_totals_line(progress: &PlanProgress, trained_loaded: bool) -> String {
    if progress.entries.is_empty() {
        return "No skills in this plan yet. Add skills to get started.".to_string();
    }
    if !trained_loaded {
        return "Estimates will appear when trained skills are loaded.".to_string();
    }
    if progress.complete_count == progress.entries.len() {
        return "All target levels reached.".to_string();
    }
    let Some(sp) = progress.total_sp_remaining else {
        return "Total remaining: unavailable (one or more skills could not be estimated)."
            .to_string();
    };
    match progress.total_minutes {
        None => format!(
            "Total remaining: {} — training time unavailable.",
            widgets::format_sp(sp)
        ),
        Some(minutes) => format!(
            "Total remaining: {} — about {}",
            widgets::format_sp(sp),
            widgets::format_countdown(minutes * 60)
        ),
    }
}

/// One entry row's text (design section 8.4), 1-based
/// position. Completion is the estimate's level fact, never
/// derived here from SP.
fn entry_row_text(
    position: usize,
    skill_name: &str,
    target_level: i32,
    estimate: &EntryEstimate,
) -> String {
    let base = format!("{position}. {skill_name} — target level {target_level}");
    let Some(trained_level) = estimate.trained_level else {
        return format!("{base} — trained level unavailable");
    };
    if estimate.complete {
        return format!("{base} — trained level {trained_level}, complete");
    }
    match estimate.sp_remaining {
        Some(sp) => match estimate.minutes {
            Some(minutes) => format!(
                "{base} — trained level {trained_level}, {} remaining, about {}",
                widgets::format_sp(sp),
                widgets::format_countdown(minutes * 60)
            ),
            None => format!(
                "{base} — trained level {trained_level}, {} remaining, training time unavailable",
                widgets::format_sp(sp)
            ),
        },
        None => format!("{base} — trained level {trained_level}, estimate unavailable"),
    }
}

/// One picker row's base text (design section 8.5), before
/// the already-in-plan / already-trained-5 suffixes.
fn picker_row_label(skill_name: &str, trained_level: Option<i32>) -> String {
    match trained_level {
        Some(level) => format!("{skill_name} — trained level {level}"),
        None => format!("{skill_name} — trained level unavailable"),
    }
}

/// Advisory trained-only disclosure (prerequisites design
/// section 8.1), rendered only alongside a warning.
const PREREQ_DISCLOSURE: &str =
    "Prerequisite warnings use trained levels only. Skills already in this plan are not counted as trained.";

/// The requirement fact for a skill (prerequisites design
/// section 8.1): every direct edge in file order, with no
/// trained-level information.
fn prerequisite_line(sde: &Sde, skill: &SdeSkillType) -> Option<String> {
    if skill.prerequisites.is_empty() {
        return None;
    }
    let parts: Vec<String> = skill
        .prerequisites
        .iter()
        .map(|p| format!("{} level {}", sde.skill_name_quiet(p.skill_id), p.level))
        .collect();
    Some(format!("Requires: {}", parts.join(", ")))
}

/// The unmet subset for one skill (prerequisites design
/// section 8.1), in input (file) order.
fn unmet_warning_line(sde: &Sde, unmet: &[UnmetPrerequisite]) -> Option<String> {
    if unmet.is_empty() {
        return None;
    }
    let segments: Vec<String> = unmet
        .iter()
        .map(|u| {
            let name = sde.skill_name_quiet(u.skill_id);
            if u.trained_level == 0 {
                format!("{name} — need level {} (untrained)", u.required_level)
            } else {
                format!(
                    "{name} — need level {} (have {})",
                    u.required_level, u.trained_level
                )
            }
        })
        .collect();
    Some(format!("Prerequisites not met: {}", segments.join("; ")))
}

/// The totals-block count line (prerequisites design
/// section 8.1): counts entries with a non-empty warning.
fn prerequisite_count_line(warnings: &[Vec<UnmetPrerequisite>]) -> Option<String> {
    let warned = warnings.iter().filter(|w| !w.is_empty()).count();
    if warned == 0 {
        return None;
    }
    Some(format!(
        "Prerequisite warnings: {warned} of {} entries have unmet prerequisites.",
        warnings.len()
    ))
}

/// Whether an armed plan confirmation is no longer renderable
/// (design section 7): the stamped character is not active,
/// the stamped plan is gone from the loaded list, or (for a
/// removal) the stamped skill is gone from that plan. A
/// confirmation never outlives the thing it confirms.
fn skill_plan_confirm_is_stale(state: &AppState) -> bool {
    let Some(confirm) = &state.skill_plan_confirm else {
        return false;
    };
    let Some(plans) = state.skill_plans.as_ready() else {
        return true;
    };
    match confirm {
        SkillPlanConfirm::DeletePlan {
            character_id,
            plan_id,
        } => {
            Some(*character_id) != state.active_character_id
                || !plans.iter().any(|p| p.plan_id == *plan_id)
        }
        SkillPlanConfirm::RemoveEntry {
            character_id,
            plan_id,
            skill_id,
        } => {
            Some(*character_id) != state.active_character_id
                || !plans.iter().any(|p| {
                    p.plan_id == *plan_id && p.entries.iter().any(|e| e.skill_id == *skill_id)
                })
        }
    }
}

/// Whether the open editor is no longer renderable (design
/// section 8.3): its stamped character is not active, or
/// (for rename) its plan left the loaded list.
fn skill_plan_editor_is_stale(state: &AppState) -> bool {
    let Some(editor) = &state.skill_plan_editor else {
        return false;
    };
    match editor {
        SkillPlanEditor::Create { character_id } => {
            Some(*character_id) != state.active_character_id
        }
        SkillPlanEditor::Edit {
            character_id,
            plan_id,
        } => {
            Some(*character_id) != state.active_character_id
                || !state
                    .skill_plans
                    .as_ready()
                    .is_some_and(|plans| plans.iter().any(|p| p.plan_id == *plan_id))
        }
    }
}

/// Open the create editor with blank drafts. Opening the
/// editor clears any armed confirmation: one pending intent
/// at a time (design section 8.3).
fn open_create_editor(state: &mut AppState, character_id: i64) {
    state.skill_plan_editor = Some(SkillPlanEditor::Create { character_id });
    state.skill_plan_name_draft.clear();
    state.skill_plan_description_draft.clear();
    state.skill_plan_confirm = None;
}

/// Open the rename editor, seeding the drafts once from the
/// plan's current text (design section 8.3).
fn open_edit_editor(state: &mut AppState, character_id: i64, plan: &SkillPlan) {
    state.skill_plan_editor = Some(SkillPlanEditor::Edit {
        character_id,
        plan_id: plan.plan_id,
    });
    state.skill_plan_name_draft = plan.name.clone();
    state.skill_plan_description_draft = plan.description.clone();
    state.skill_plan_confirm = None;
}

pub fn show(ui: &mut egui::Ui, state: &mut AppState, sde: &Sde, cache: &mut PortraitImageCache) {
    ui.heading("Skills");
    widgets::mode_notice(ui, state.demo, state.offline);
    cache.prune(state);
    if state.active_character().is_none() {
        widgets::no_character_panel(ui);
        return;
    }
    let snapshot = state.skills.clone();
    match snapshot {
        LoadState::Ready(data) => {
            let now = Utc::now();
            ui.label(format!(
                "Total skill points: {} (unallocated: {})",
                widgets::format_sp(data.skills.total_sp),
                widgets::format_sp(data.skills.unallocated_sp.unwrap_or(0))
            ));

            let queue = sorted_queue(&data.queue);
            ui.separator();
            ui.heading(format!("Training queue ({} skills)", queue.len()));
            if queue.is_empty() {
                widgets::empty_panel(
                    ui,
                    "Queue is empty. Add skills in EVE, then refresh (Ctrl+R).",
                );
            } else {
                if let Some(last) = queue.last() {
                    ui.label(format!(
                        "Queue finishes: {}",
                        widgets::countdown_label(last.finish_date.as_deref(), now)
                    ));
                }
                // Arrow-key row movement (skipped while typing in search).
                if !state.text_input_focused {
                    let (down, up) = ui.ctx().input(|i| {
                        (
                            i.key_pressed(egui::Key::ArrowDown),
                            i.key_pressed(egui::Key::ArrowUp),
                        )
                    });
                    if down && state.selected_queue_row + 1 < queue.len() {
                        state.selected_queue_row += 1;
                    }
                    if up && state.selected_queue_row > 0 {
                        state.selected_queue_row -= 1;
                    }
                }
                if state.selected_queue_row >= queue.len() {
                    state.selected_queue_row = queue.len().saturating_sub(1);
                }
                egui::ScrollArea::vertical()
                    .id_salt("skill_queue_scroll")
                    .max_height(240.0)
                    .show(ui, |ui| {
                        for (idx, item) in queue.iter().enumerate() {
                            let name = sde.skill_name(item.skill_id);
                            let countdown =
                                widgets::countdown_label(item.finish_date.as_deref(), now);
                            let marker = if idx == state.selected_queue_row {
                                ">"
                            } else {
                                " "
                            };
                            ui.label(format!(
                                "{} {}. {} level {} — finishes {} ({})",
                                marker,
                                item.queue_position + 1,
                                name,
                                item.finished_level,
                                countdown,
                                item.finish_date
                                    .as_deref()
                                    .map(widgets::format_date_short)
                                    .unwrap_or_else(|| "paused".to_string())
                            ));
                            if idx == 0 {
                                let fraction = widgets::progress_fraction(
                                    item.start_date.as_deref(),
                                    item.finish_date.as_deref(),
                                    now,
                                );
                                ui.add(
                                    egui::ProgressBar::new(fraction)
                                        .text(format!("{:.0}%", fraction * 100.0)),
                                );
                            }
                        }
                    });
            }

            // --- Catalogue by SDE group, searchable ---
            ui.separator();
            ui.heading("Skill catalogue (by SDE group)");
            let focus = widgets::search_box(
                ui,
                &mut state.skill_search,
                "Search skills (press / to focus)",
                state.focus_search,
            );
            state.text_input_focused |= focus;
            if focus {
                state.focus_search = false;
            }
            let query = state.skill_search.clone();
            let levels: BTreeMap<i64, i32> = data
                .skills
                .skills
                .iter()
                .map(|s| (s.skill_id, s.trained_skill_level))
                .collect();
            if sde.groups.is_empty() {
                widgets::empty_panel(ui, "Bundled skill catalogue is unavailable.");
            }
            egui::ScrollArea::vertical()
                .id_salt("skill_catalogue_scroll")
                .max_height(320.0)
                .show(ui, |ui| {
                    let mut any_match = false;
                    let mut total_filtered: usize = 0;
                    let mut remaining = SKILLS_CATALOGUE_RENDER_MAX;
                    let mut cap_suppressed = false;
                    for group in &sde.groups {
                        let mut rows: Vec<CatalogueRow> = Vec::new();
                        for skill in sde.types.iter().filter(|t| t.group_id == group.group_id) {
                            if !widgets::matches_search(&skill.type_name, &query) {
                                continue;
                            }
                            any_match = true;
                            total_filtered += 1;
                            let level = levels.get(&skill.type_id).copied().unwrap_or(0);
                            rows.push(CatalogueRow {
                                skill_type_id: Some(skill.type_id),
                                text: format!("{} — trained level {}", skill.type_name, level),
                            });
                            if let Some(line) = prerequisite_line(sde, skill) {
                                rows.push(CatalogueRow {
                                    skill_type_id: None,
                                    text: line,
                                });
                            }
                        }
                        if rows.is_empty() {
                            continue;
                        }
                        egui::CollapsingHeader::new(&group.group_name)
                            .default_open(!query.is_empty())
                            .show(ui, |ui| {
                                let mut skill_rendered = false;
                                for row in &rows {
                                    match row.skill_type_id {
                                        Some(type_id) if remaining > 0 => {
                                            remaining -= 1;
                                            skill_rendered = true;
                                            ensure_type_icon_requested(state, type_id);
                                            ui.horizontal(|ui| {
                                                show_type_icon(
                                                    ui,
                                                    cache,
                                                    state,
                                                    type_id,
                                                    TYPE_ICON_PX,
                                                );
                                                ui.label(&row.text);
                                            });
                                        }
                                        Some(_) => {
                                            cap_suppressed = true;
                                            skill_rendered = false;
                                        }
                                        None => {
                                            if skill_rendered {
                                                ui.label(&row.text);
                                            }
                                        }
                                    }
                                }
                            });
                    }
                    if cap_suppressed {
                        ui.label(format!(
                            "Showing {} of {} skills.",
                            total_filtered.min(SKILLS_CATALOGUE_RENDER_MAX),
                            total_filtered
                        ));
                    }
                    if !any_match && !sde.groups.is_empty() {
                        widgets::empty_panel(ui, "No skills match the search.");
                    }
                });
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading skills..."),
        LoadState::Empty => widgets::empty_panel(ui, "No skill data yet."),
        LoadState::Error(e) => {
            if widgets::error_panel_with_retry(ui, &e) {
                tracing::warn!("[SKILLS] retry requested after load error");
                state.retry_requested = true;
            }
        }
    }
    // Skill plans render after the skills match, so they are
    // visible and editable in every skills load state; only
    // their estimates degrade (design section 8.1).
    show_plans_section(ui, state, sde);
}

/// The skill-plans section: list, selected detail, editor.
///
/// The view never mutates plans and never touches storage: it
/// stamps at most one queued `SkillPlanAction` per frame (the
/// one-slot channel, design section 7), and the shell drains
/// it. A click that finds the slot occupied is ignored that
/// frame: every stamping handle below checks
/// `skill_plan_action.is_none()`, so a failed stamp leaves its
/// intent (editor, confirmation) in place for the next frame.
fn show_plans_section(ui: &mut egui::Ui, state: &mut AppState, sde: &Sde) {
    // Sweeps before anything renders under them: selection,
    // confirmation, and editor never outlive their target.
    if let Some(selected) = state.selected_skill_plan_id {
        let still_listed = state
            .skill_plans
            .as_ready()
            .is_some_and(|plans| plans.iter().any(|p| p.plan_id == selected));
        if !still_listed {
            state.selected_skill_plan_id = None;
            state.skill_plan_picker_open = false;
            state.skill_plan_picker_search.clear();
        }
    }
    if skill_plan_confirm_is_stale(state) {
        state.skill_plan_confirm = None;
    }
    if skill_plan_editor_is_stale(state) {
        state.skill_plan_editor = None;
    }

    let Some(active_id) = state.active_character_id else {
        return;
    };

    // Estimate inputs, derived once per frame (design
    // section 8.1): the trained map only from a Ready skills
    // bundle (`active_skill_level` never read), attributes
    // only from a Ready details bundle with `attributes: Ok`.
    let trained: Option<BTreeMap<i64, TrainedSkill>> = state.skills.as_ready().map(|data| {
        data.skills
            .skills
            .iter()
            .map(|s| {
                (
                    s.skill_id,
                    TrainedSkill {
                        trained_level: s.trained_skill_level,
                        skillpoints_in_skill: s.skillpoints_in_skill,
                    },
                )
            })
            .collect()
    });
    // Cloned, not borrowed: the detail below takes `&mut
    // state`, and these inputs are small per-frame copies.
    let attributes: Option<CharacterAttributes> = state
        .character_details
        .as_ready()
        .and_then(|bundle| bundle.attributes.as_ref().ok().cloned());

    ui.separator();
    ui.heading(SKILL_PLANS_HEADING);
    if state.demo {
        ui.label(SKILL_PLANS_DEMO_LABEL);
    }

    // Owner guard (design section 7): plans render only when
    // loaded for the active character; otherwise the loading
    // words, so a list can never display under the wrong
    // character even for one frame during a switch.
    if state.skill_plans_owner != Some(active_id) {
        widgets::loading_panel(ui, "Loading skill plans...");
        return;
    }

    let plans: Vec<SkillPlan> = match &state.skill_plans {
        LoadState::Ready(plans) => plans.clone(),
        LoadState::Empty => Vec::new(),
        LoadState::Loading => {
            widgets::loading_panel(ui, "Loading skill plans...");
            return;
        }
        LoadState::Error(_) => {
            // Fixed words, no Retry: nothing here is retryable
            // into ESI, and the next character switch or
            // restart reloads (design section 8.2). No create
            // affordance renders in this state.
            widgets::error_panel(ui, "Skill plans could not be loaded from local storage.");
            return;
        }
    };

    if plans.is_empty() {
        widgets::empty_panel(ui, "No skill plans yet for this character.");
    }
    if ui.button("New skill plan").clicked() {
        open_create_editor(state, active_id);
    }
    for plan in &plans {
        let progress = plan_progress(plan, sde, trained.as_ref(), attributes.as_ref());
        let selected = state.selected_skill_plan_id == Some(plan.plan_id);
        if ui.selectable_label(selected, plan.name.clone()).clicked() {
            if selected {
                state.selected_skill_plan_id = None;
            } else {
                state.selected_skill_plan_id = Some(plan.plan_id);
            }
        }
        ui.label(plan_list_summary(&progress, trained.is_some()));
        // The bar only reads when trained is loaded and the
        // plan is non-empty; a bar over an unknown or empty
        // denominator would claim a measurement that does not
        // exist (design section 8.2).
        if trained.is_some() && !plan.entries.is_empty() {
            let fraction = progress.complete_count as f32 / plan.entries.len() as f32;
            ui.add(egui::ProgressBar::new(fraction).text(format!("{:.0}%", fraction * 100.0)));
        }
    }

    if let Some(selected_id) = state.selected_skill_plan_id {
        if let Some(plan) = plans.iter().find(|p| p.plan_id == selected_id) {
            show_plan_detail(
                ui,
                state,
                sde,
                active_id,
                trained.as_ref(),
                attributes.as_ref(),
                plan,
            );
        }
    }
    show_plan_editor(ui, state, active_id);
}

/// The selected plan's detail (design section 8.4): heading,
/// description, action buttons (or the delete confirmation
/// replacing them), the add-skill picker, entry rows with
/// reorder/remove, the remove confirmation, totals, and the
/// estimates disclosure.
fn show_plan_detail(
    ui: &mut egui::Ui,
    state: &mut AppState,
    sde: &Sde,
    active_id: i64,
    trained: Option<&BTreeMap<i64, TrainedSkill>>,
    attributes: Option<&CharacterAttributes>,
    plan: &SkillPlan,
) {
    let progress = plan_progress(plan, sde, trained, attributes);
    let warnings = plan_prerequisite_warnings(plan, sde, trained);
    ui.separator();
    ui.heading(format!("Plan: {}", plan.name));
    if !plan.description.is_empty() {
        ui.label(plan.description.clone());
    }

    let delete_armed = matches!(
        state.skill_plan_confirm,
        Some(SkillPlanConfirm::DeletePlan { character_id, plan_id })
            if character_id == active_id && plan_id == plan.plan_id
    );
    if delete_armed {
        // The armed confirmation replaces the buttons row
        // (the fittings delete-confirm shape, local words).
        ui.heading(delete_plan_heading(&plan.name));
        ui.label(delete_plan_summary(&plan.name, plan.entries.len()));
        ui.horizontal(|ui| {
            if ui.button("Confirm delete").clicked() && state.skill_plan_action.is_none() {
                tracing::info!(
                    "[PLANS] delete confirmed character_id={} plan_id={} entries={}",
                    active_id,
                    plan.plan_id,
                    plan.entries.len()
                );
                state.skill_plan_action = Some(SkillPlanAction::DeletePlan {
                    character_id: active_id,
                    plan_id: plan.plan_id,
                });
                state.skill_plan_confirm = None;
                state.selected_skill_plan_id = None;
            }
            if ui.button("Cancel").clicked() {
                state.skill_plan_confirm = None;
            }
        });
    } else {
        ui.horizontal(|ui| {
            if ui.button("Rename plan...").clicked() {
                open_edit_editor(state, active_id, plan);
            }
            let picker_label = if state.skill_plan_picker_open {
                "Hide skill picker"
            } else {
                "Add skills..."
            };
            if ui.button(picker_label).clicked() {
                state.skill_plan_picker_open = !state.skill_plan_picker_open;
            }
            if ui.button("Delete plan...").clicked() {
                // Arming a confirmation closes the editor:
                // one pending intent at a time.
                state.skill_plan_confirm = Some(SkillPlanConfirm::DeletePlan {
                    character_id: active_id,
                    plan_id: plan.plan_id,
                });
                state.skill_plan_editor = None;
            }
        });
    }

    if state.skill_plan_picker_open {
        show_skill_picker(ui, state, sde, active_id, plan, trained);
    }

    egui::ScrollArea::vertical()
        .id_salt("skill_plan_entries_scroll")
        .max_height(320.0)
        .show(ui, |ui| {
            for (idx, entry) in plan.entries.iter().enumerate() {
                let name = sde.skill_name_quiet(entry.skill_id);
                let estimate = &progress.entries[idx];
                ui.label(entry_row_text(idx + 1, &name, entry.target_level, estimate));
                if trained.is_some() {
                    if let Some(line) = unmet_warning_line(sde, &warnings[idx]) {
                        ui.label(line);
                    }
                }
                ui.horizontal(|ui| {
                    let up = ui.add_enabled(idx > 0, egui::Button::new("Move up"));
                    let down = ui.add_enabled(
                        idx + 1 < plan.entries.len(),
                        egui::Button::new("Move down"),
                    );
                    let remove = ui.button("Remove...");
                    if up.clicked() {
                        let mut new_entries = plan.entries.clone();
                        new_entries.swap(idx, idx - 1);
                        if state.skill_plan_action.is_none() {
                            tracing::info!(
                                "[PLANS] entries replace requested character_id={} plan_id={} count={}",
                                active_id,
                                plan.plan_id,
                                new_entries.len()
                            );
                            state.skill_plan_action = Some(SkillPlanAction::ReplaceEntries {
                                character_id: active_id,
                                plan_id: plan.plan_id,
                                entries: new_entries,
                            });
                        }
                    }
                    if down.clicked() {
                        let mut new_entries = plan.entries.clone();
                        new_entries.swap(idx, idx + 1);
                        if state.skill_plan_action.is_none() {
                            tracing::info!(
                                "[PLANS] entries replace requested character_id={} plan_id={} count={}",
                                active_id,
                                plan.plan_id,
                                new_entries.len()
                            );
                            state.skill_plan_action = Some(SkillPlanAction::ReplaceEntries {
                                character_id: active_id,
                                plan_id: plan.plan_id,
                                entries: new_entries,
                            });
                        }
                    }
                    if remove.clicked() {
                        // Arming a confirmation closes the editor.
                        state.skill_plan_confirm = Some(SkillPlanConfirm::RemoveEntry {
                            character_id: active_id,
                            plan_id: plan.plan_id,
                            skill_id: entry.skill_id,
                        });
                        state.skill_plan_editor = None;
                    }
                });
            }
        });

    // The remove confirmation renders as one block under the
    // entry list so rows do not move while confirming.
    if let Some(SkillPlanConfirm::RemoveEntry {
        character_id,
        plan_id,
        skill_id,
    }) = state.skill_plan_confirm
    {
        if character_id == active_id && plan_id == plan.plan_id {
            let skill_name = sde.skill_name_quiet(skill_id);
            ui.heading(remove_entry_heading(&skill_name, &plan.name));
            ui.label(remove_entry_summary(&skill_name));
            ui.horizontal(|ui| {
                if ui.button("Confirm remove").clicked() && state.skill_plan_action.is_none() {
                    let new_entries: Vec<SkillPlanEntry> = plan
                        .entries
                        .iter()
                        .filter(|e| e.skill_id != skill_id)
                        .cloned()
                        .collect();
                    tracing::info!(
                        "[PLANS] entries replace requested character_id={} plan_id={} count={}",
                        active_id,
                        plan.plan_id,
                        new_entries.len()
                    );
                    state.skill_plan_action = Some(SkillPlanAction::ReplaceEntries {
                        character_id: active_id,
                        plan_id: plan.plan_id,
                        entries: new_entries,
                    });
                    state.skill_plan_confirm = None;
                }
                if ui.button("Cancel").clicked() {
                    state.skill_plan_confirm = None;
                }
            });
        }
    }

    ui.label(plan_totals_line(&progress, trained.is_some()));
    if trained.is_some() {
        if let Some(line) = prerequisite_count_line(&warnings) {
            ui.label(line);
            ui.label(PREREQ_DISCLOSURE);
        }
    }
    // The disclosure rides under the totals for any non-empty
    // plan with loaded skills; the not-loaded totals line
    // already says estimates are absent.
    if !plan.entries.is_empty() && trained.is_some() {
        ui.label(SKILL_PLANS_DISCLOSURE);
    }
}

/// The inline create/rename editor (design section 8.3):
/// never a modal. Validation runs every frame through
/// `normalize_plan_text` — the UI renders its exact strings
/// from that one source, never copies.
fn show_plan_editor(ui: &mut egui::Ui, state: &mut AppState, active_id: i64) {
    let Some(editor) = state.skill_plan_editor else {
        return;
    };
    let (heading, is_create, edit_plan_id) = match editor {
        SkillPlanEditor::Create { character_id } if character_id == active_id => {
            ("Create skill plan", true, None)
        }
        SkillPlanEditor::Edit {
            character_id,
            plan_id,
        } if character_id == active_id => ("Rename skill plan", false, Some(plan_id)),
        _ => return, // stale sweep already cleared these
    };
    ui.separator();
    ui.heading(heading);
    ui.label("Plan name");
    let name_response = ui.text_edit_singleline(&mut state.skill_plan_name_draft);
    ui.label("Description (optional)");
    let desc_response = ui.text_edit_multiline(&mut state.skill_plan_description_draft);
    state.text_input_focused |= name_response.has_focus() || desc_response.has_focus();

    let validation = normalize_plan_text(
        &state.skill_plan_name_draft,
        &state.skill_plan_description_draft,
    );
    let normalized = validation.clone();
    if let Err(message) = &validation {
        ui.colored_label(egui::Color32::LIGHT_RED, *message);
    }
    ui.horizontal(|ui| {
        let save_label = if is_create {
            "Create plan"
        } else {
            "Save name"
        };
        if ui
            .add_enabled(
                state.skill_plan_action.is_none() && validation.is_ok(),
                egui::Button::new(save_label),
            )
            .clicked()
        {
            // Validity at click time (validation ran this
            // frame above); the applier re-normalizes on drain.
            if let Ok((name, description)) = normalized {
                match edit_plan_id {
                    None => {
                        tracing::info!("[PLANS] create requested character_id={}", active_id);
                        state.skill_plan_action = Some(SkillPlanAction::Create {
                            character_id: active_id,
                            name,
                            description,
                        });
                    }
                    Some(plan_id) => {
                        tracing::info!(
                            "[PLANS] rename requested character_id={} plan_id={}",
                            active_id,
                            plan_id
                        );
                        state.skill_plan_action = Some(SkillPlanAction::UpdateText {
                            character_id: active_id,
                            plan_id,
                            name,
                            description,
                        });
                    }
                }
                state.skill_plan_editor = None;
                state.skill_plan_name_draft.clear();
                state.skill_plan_description_draft.clear();
            }
        }
        if ui.button("Cancel").clicked() {
            state.skill_plan_editor = None;
            state.skill_plan_name_draft.clear();
            state.skill_plan_description_draft.clear();
        }
    });
}

/// The add-skill picker (design section 8.5), for the
/// selected plan: one search box plus `Sde::search_skills`
/// results. A click stamps `ReplaceEntries` with the new
/// entry appended and leaves the picker open for the next add.
fn show_skill_picker(
    ui: &mut egui::Ui,
    state: &mut AppState,
    sde: &Sde,
    active_id: i64,
    plan: &SkillPlan,
    trained: Option<&BTreeMap<i64, TrainedSkill>>,
) {
    // `grab_focus = false`: the `/` shortcut belongs to the
    // catalogue box in this view; the picker never steals it.
    let focus = widgets::search_box(
        ui,
        &mut state.skill_plan_picker_search,
        "Search skills to add",
        false,
    );
    state.text_input_focused |= focus;
    if sde.groups.is_empty() {
        widgets::empty_panel(ui, "Bundled skill catalogue is unavailable.");
        return;
    }
    let query = state.skill_plan_picker_search.clone();
    let results = sde.search_skills(&query);
    if results.is_empty() {
        widgets::empty_panel(ui, "No skills match the search.");
        return;
    }
    egui::ScrollArea::vertical()
        .id_salt("skill_picker_scroll")
        .max_height(320.0)
        .show(ui, |ui| {
            for skill in &results {
                let trained_level: Option<i32> = trained.map(|map| {
                    map.get(&skill.type_id)
                        .map(|t| t.trained_level.clamp(0, 5))
                        .unwrap_or(0)
                });
                let in_plan = plan.entries.iter().any(|e| e.skill_id == skill.type_id);
                let mut text = picker_row_label(&skill.type_name, trained_level);
                if in_plan {
                    text += " — already in this plan";
                } else if trained_level == Some(5) {
                    text += " — already trained to level 5";
                }
                ui.label(text);
                if let Some(line) = prerequisite_line(sde, skill) {
                    ui.label(line);
                }
                if let Some(map) = trained {
                    let unmet = unmet_prerequisites(sde, skill.type_id, map);
                    if let Some(line) = unmet_warning_line(sde, &unmet) {
                        ui.label(line);
                    }
                }
                if !in_plan && trained_level != Some(5) {
                    ui.horizontal(|ui| {
                        for level in 1..=5 {
                            // Levels at or below the trained
                            // level are disabled; with skills
                            // not loaded every target is enabled
                            // (design section 8.5).
                            let enabled = match trained_level {
                                Some(current) => level > current,
                                None => true,
                            };
                            if ui
                                .add_enabled(enabled, egui::Button::new(level.to_string()))
                                .clicked()
                            {
                                let mut new_entries = plan.entries.clone();
                                new_entries.push(SkillPlanEntry {
                                    skill_id: skill.type_id,
                                    target_level: level,
                                });
                                if state.skill_plan_action.is_none() {
                                    tracing::info!(
                                        "[PLANS] entries replace requested character_id={} plan_id={} count={}",
                                        active_id,
                                        plan.plan_id,
                                        new_entries.len()
                                    );
                                    state.skill_plan_action =
                                        Some(SkillPlanAction::ReplaceEntries {
                                            character_id: active_id,
                                            plan_id: plan.plan_id,
                                            entries: new_entries,
                                        });
                                }
                            }
                        }
                    });
                }
            }
        });
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::app::state::{PortraitState, SkillsData};
    use crate::portraits::ImageKind;
    use crate::storage::repositories::CharacterRow;

    fn item(position: i32, skill: i64) -> SkillQueueItem {
        SkillQueueItem {
            skill_id: skill,
            queue_position: position,
            finished_level: 1,
            ..Default::default()
        }
    }

    #[test]
    fn queue_is_sorted_by_position() {
        let queue = vec![item(2, 3302), item(0, 3300), item(1, 3301)];
        let sorted = sorted_queue(&queue);
        assert_eq!(
            sorted.iter().map(|i| i.skill_id).collect::<Vec<_>>(),
            vec![3300, 3301, 3302]
        );
        assert!(sorted_queue(&[]).is_empty());
    }

    #[test]
    fn trained_levels_empty_when_not_ready() {
        let state = AppState::new(false);
        assert!(trained_levels(&state).is_empty());
    }

    fn estimate(
        trained_level: Option<i32>,
        complete: bool,
        sp_remaining: Option<i64>,
        minutes: Option<i64>,
    ) -> EntryEstimate {
        EntryEstimate {
            skill_id: 3300,
            trained_level,
            complete,
            sp_remaining,
            minutes,
        }
    }

    fn progress_with(
        entries: Vec<EntryEstimate>,
        complete_count: usize,
        total_sp_remaining: Option<i64>,
        total_minutes: Option<i64>,
    ) -> PlanProgress {
        PlanProgress {
            entries,
            complete_count,
            total_sp_remaining,
            total_minutes,
        }
    }

    // T18: plan_wording_matches_design_strings (design
    // section 12): the wording fns/consts pinned verbatim —
    // delete heading/summary, remove heading/summary, totals
    // variants, disclosure, demo label — plus the row and
    // list lines and the editor error strings (which the UI
    // renders from `normalize_plan_text`, one source, never
    // copies). All expectations are hand literals; SP
    // formatting: 210745 -> "210,745 SP"; countdowns:
    // 6022 min * 60 = 361320 s = 4d 4h 22m (4*86400=345600,
    // remainder 15720 = 4h + 1320 s = 22m).
    #[test]
    fn plan_wording_matches_design_strings() {
        // Delete heading/summary, full expected strings.
        assert_eq!(delete_plan_heading("PvP"), "Delete plan \"PvP\"?");
        assert_eq!(
            delete_plan_summary("PvP", 3),
            "\"PvP\" and its 3 entries will be deleted from this device. This cannot be undone."
        );
        // Bare count with plural noun even at 1 and 0.
        assert_eq!(
            delete_plan_summary("PvP", 1),
            "\"PvP\" and its 1 entries will be deleted from this device. This cannot be undone."
        );
        assert_eq!(
            delete_plan_summary("PvP", 0),
            "\"PvP\" and its 0 entries will be deleted from this device. This cannot be undone."
        );
        // Remove heading/summary, full expected strings.
        assert_eq!(
            remove_entry_heading("Gunnery", "PvP"),
            "Remove \"Gunnery\" from \"PvP\"?"
        );
        assert_eq!(
            remove_entry_summary("Gunnery"),
            "\"Gunnery\" will be removed from this plan. Trained levels in EVE are not changed."
        );
        // Totals variants, full expected strings.
        let full = progress_with(
            vec![estimate(Some(4), false, Some(210745), Some(6022))],
            0,
            Some(210745),
            Some(6022),
        );
        assert_eq!(
            plan_totals_line(&full, true),
            "Total remaining: 210,745 SP — about 4d 4h 22m"
        );
        let sp_only = progress_with(
            vec![estimate(Some(4), false, Some(210745), None)],
            0,
            Some(210745),
            None,
        );
        assert_eq!(
            plan_totals_line(&sp_only, true),
            "Total remaining: 210,745 SP — training time unavailable."
        );
        let unknown = progress_with(vec![estimate(Some(4), false, None, None)], 0, None, None);
        assert_eq!(
            plan_totals_line(&unknown, true),
            "Total remaining: unavailable (one or more skills could not be estimated)."
        );
        assert_eq!(
            plan_totals_line(&full, false),
            "Estimates will appear when trained skills are loaded."
        );
        let all_complete = progress_with(
            vec![estimate(Some(5), true, Some(0), Some(0))],
            1,
            Some(0),
            Some(0),
        );
        assert_eq!(
            plan_totals_line(&all_complete, true),
            "All target levels reached."
        );
        let empty = progress_with(vec![], 0, Some(0), Some(0));
        assert_eq!(
            plan_totals_line(&empty, true),
            "No skills in this plan yet. Add skills to get started."
        );
        // Empty beats not-loaded (section 8.6 words the empty
        // selected plan unconditionally).
        assert_eq!(
            plan_totals_line(&empty, false),
            "No skills in this plan yet. Add skills to get started."
        );
        // Disclosure and demo label, verbatim.
        assert_eq!(
            SKILL_PLANS_DISCLOSURE,
            "Estimates use this character's current attributes as loaded. They ignore the training queue and any future attribute remap."
        );
        assert_eq!(
            SKILL_PLANS_DEMO_LABEL,
            "Demo mode: skill plans are kept in memory for this session and are not saved."
        );
        // List summary lines (design section 8.2).
        // `full` has 1 entry, 0 complete.
        assert_eq!(
            plan_list_summary(&full, true),
            "0 of 1 complete — 210,745 SP remaining — about 4d 4h 22m"
        );
        assert_eq!(
            plan_list_summary(&empty, true),
            "No skills in this plan yet."
        );
        assert_eq!(plan_list_summary(&full, false), "1 skill");
        let two_unknown = progress_with(
            vec![
                estimate(None, false, None, None),
                estimate(None, false, None, None),
            ],
            0,
            None,
            None,
        );
        assert_eq!(plan_list_summary(&two_unknown, false), "2 skills");
        // Unknown total omits its part entirely.
        assert_eq!(plan_list_summary(&unknown, true), "0 of 1 complete");
        // Entry rows (design section 8.4).
        assert_eq!(
            entry_row_text(
                1,
                "Gunnery",
                5,
                &estimate(Some(4), false, Some(210745), Some(6022))
            ),
            "1. Gunnery — target level 5 — trained level 4, 210,745 SP remaining, about 4d 4h 22m"
        );
        assert_eq!(
            entry_row_text(2, "Gunnery", 4, &estimate(Some(3), false, Some(35255), None)),
            "2. Gunnery — target level 4 — trained level 3, 35,255 SP remaining, training time unavailable"
        );
        assert_eq!(
            entry_row_text(3, "Gunnery", 5, &estimate(Some(4), false, None, None)),
            "3. Gunnery — target level 5 — trained level 4, estimate unavailable"
        );
        assert_eq!(
            entry_row_text(1, "Gunnery", 5, &estimate(Some(5), true, Some(0), Some(0))),
            "1. Gunnery — target level 5 — trained level 5, complete"
        );
        assert_eq!(
            entry_row_text(1, "Gunnery", 5, &estimate(None, false, None, None)),
            "1. Gunnery — target level 5 — trained level unavailable"
        );
        // Picker base labels (design section 8.5).
        assert_eq!(
            picker_row_label("Gunnery", Some(3)),
            "Gunnery — trained level 3"
        );
        assert_eq!(
            picker_row_label("Gunnery", None),
            "Gunnery — trained level unavailable"
        );
        // Editor error strings: the UI renders these straight
        // from normalize_plan_text (T10 pins the validator);
        // T18 re-asserts the three literals here so the
        // visible contract has one UI-side pin, and the editor
        // carries no competing copies.
        assert_eq!(normalize_plan_text("   ", ""), Err("Plan name is required"));
        assert_eq!(
            normalize_plan_text(&"a".repeat(101), ""),
            Err("Plan name must be 100 characters or less")
        );
        assert_eq!(
            normalize_plan_text("PvP", &"a".repeat(501)),
            Err("Description must be 500 characters or less")
        );
    }

    // U1: prerequisite_line_wording (prerequisites design section 12.3).
    #[test]
    fn prerequisite_line_wording() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let line = |skill_id: i64| {
            let skill = sde.skill(skill_id).expect("skill present");
            prerequisite_line(&sde, skill)
        };
        assert_eq!(
            line(3304),
            Some("Requires: Gunnery level 3, Small Hybrid Turret level 3".to_string())
        );
        assert_eq!(line(3301), Some("Requires: Gunnery level 1".to_string()));
        assert_eq!(
            line(3344),
            Some(
                "Requires: Capital Ships level 5, Gallente Battleship level 3, Leadership level 5"
                    .to_string()
            )
        );
        assert_eq!(line(3300), None);
    }

    // U2: unmet_warning_line_have_and_untrained (section 12.3).
    #[test]
    fn unmet_warning_line_have_and_untrained() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        assert_eq!(
            unmet_warning_line(
                &sde,
                &[
                    UnmetPrerequisite {
                        skill_id: 3300,
                        required_level: 3,
                        trained_level: 1
                    },
                    UnmetPrerequisite {
                        skill_id: 3301,
                        required_level: 3,
                        trained_level: 0
                    },
                ]
            ),
            Some(
                "Prerequisites not met: Gunnery — need level 3 (have 1); Small Hybrid Turret — need level 3 (untrained)"
                    .to_string()
            )
        );
        assert_eq!(
            unmet_warning_line(
                &sde,
                &[UnmetPrerequisite {
                    skill_id: 3301,
                    required_level: 3,
                    trained_level: 2
                }]
            ),
            Some("Prerequisites not met: Small Hybrid Turret — need level 3 (have 2)".to_string())
        );
        assert_eq!(unmet_warning_line(&sde, &[]), None);
    }

    // U3: unmet_warning_line_unknown_never_raw_id (section 12.3).
    #[test]
    fn unmet_warning_line_unknown_never_raw_id() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let line = unmet_warning_line(
            &sde,
            &[UnmetPrerequisite {
                skill_id: 999999,
                required_level: 2,
                trained_level: 0,
            }],
        )
        .expect("unknown id warns");
        assert_eq!(
            line,
            "Prerequisites not met: Unknown Skill — need level 2 (untrained)"
        );
        assert!(!line.contains("999999"));
    }

    // U4: prerequisite_count_line_counts (section 12.3).
    #[test]
    fn prerequisite_count_line_counts() {
        let one = UnmetPrerequisite {
            skill_id: 3300,
            required_level: 3,
            trained_level: 1,
        };
        let two = UnmetPrerequisite {
            skill_id: 3301,
            required_level: 3,
            trained_level: 0,
        };
        assert_eq!(
            prerequisite_count_line(&[vec![one], Vec::new(), vec![one, two]]),
            Some("Prerequisite warnings: 2 of 3 entries have unmet prerequisites.".to_string())
        );
        assert_eq!(
            prerequisite_count_line(&[vec![one]]),
            Some("Prerequisite warnings: 1 of 1 entries have unmet prerequisites.".to_string())
        );
        assert_eq!(prerequisite_count_line(&[Vec::new(), Vec::new()]), None);
        let empty: Vec<Vec<UnmetPrerequisite>> = Vec::new();
        assert_eq!(prerequisite_count_line(&empty), None);
    }

    // U5: prereq_disclosure_verbatim (section 12.3).
    #[test]
    fn prereq_disclosure_verbatim() {
        assert_eq!(
            PREREQ_DISCLOSURE,
            "Prerequisite warnings use trained levels only. Skills already in this plan are not counted as trained."
        );
    }

    // U6: plan_warning_text_end_to_end (section 12.3).
    #[test]
    fn plan_warning_text_end_to_end() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let plan = SkillPlan {
            plan_id: 1,
            character_id: 90000001,
            name: "Test".to_string(),
            description: String::new(),
            created_at: "2026-11-15T00:00:00Z".to_string(),
            updated_at: "2026-11-15T00:00:00Z".to_string(),
            entries: vec![SkillPlanEntry {
                skill_id: 3304,
                target_level: 5,
            }],
        };
        let mut trained = BTreeMap::new();
        trained.insert(
            3300,
            TrainedSkill {
                trained_level: 1,
                skillpoints_in_skill: 0,
            },
        );
        let warnings = plan_prerequisite_warnings(&plan, &sde, Some(&trained));
        assert_eq!(
            unmet_warning_line(&sde, &warnings[0]),
            Some(
                "Prerequisites not met: Gunnery — need level 3 (have 1); Small Hybrid Turret — need level 3 (untrained)"
                    .to_string()
            )
        );
        assert_eq!(
            prerequisite_count_line(&warnings),
            Some("Prerequisite warnings: 1 of 1 entries have unmet prerequisites.".to_string())
        );
    }

    #[test]
    fn skills_catalogue_render_max_is_100() {
        assert_eq!(SKILLS_CATALOGUE_RENDER_MAX, 100);
    }

    /// Active character, `Ready` skills with an empty trained list
    /// and an empty queue, catalogue ids installed: exactly the
    /// test fixture the design section 7 mandates.
    fn ready_catalogue_state(sde: &Sde) -> AppState {
        let mut state = AppState::new(false);
        state.characters = vec![CharacterRow {
            character_id: 1,
            name: "Test Pilot".to_string(),
            corporation_id: 1000166,
            alliance_id: None,
            is_active: false,
        }];
        state.set_active_character(1);
        state.skills = LoadState::Ready(SkillsData::default());
        state.install_skill_catalogue_type_ids(sde);
        state
    }

    #[test]
    fn skills_show_queues_icons_for_rendered_rows_only() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");

        // No active character: show returns at the no-character
        // panel, before the catalogue.
        {
            let mut state = AppState::new(false);
            let mut cache = PortraitImageCache::new();
            let ctx = egui::Context::default();
            let _ = ctx.run(egui::RawInput::default(), |ctx| {
                egui::CentralPanel::default().show(ctx, |ui| {
                    show(ui, &mut state, &sde, &mut cache);
                });
            });
            assert!(state.portrait_requests.is_empty());
            assert!(cache.is_empty());
        }

        // Empty search: every group is collapsed on first store,
        // so nothing renders and nothing queues.
        {
            let mut state = ready_catalogue_state(&sde);
            let mut cache = PortraitImageCache::new();
            let ctx = egui::Context::default();
            let _ = ctx.run(egui::RawInput::default(), |ctx| {
                egui::CentralPanel::default().show(ctx, |ui| {
                    show(ui, &mut state, &sde, &mut cache);
                });
            });
            assert!(state.portrait_requests.is_empty());
            assert!(cache.is_empty());
        }

        // "e" matches 447 bundled skills: exactly one full
        // 100-row window across the open groups, proving the
        // budget is global (a per-group budget would queue
        // hundreds here) and that the 466 `Requires:` lines
        // ensure nothing.
        {
            let mut state = ready_catalogue_state(&sde);
            state.skill_search = "e".to_string();
            let mut cache = PortraitImageCache::new();
            let ctx = egui::Context::default();
            let _ = ctx.run(egui::RawInput::default(), |ctx| {
                egui::CentralPanel::default().show(ctx, |ui| {
                    show(ui, &mut state, &sde, &mut cache);
                });
            });
            assert_eq!(state.portrait_requests.len(), 100);
            let mut queued_ids: Vec<i64> =
                state.portrait_requests.iter().map(|(_, id)| *id).collect();
            queued_ids.sort_unstable();
            queued_ids.dedup();
            assert_eq!(queued_ids.len(), 100, "queued keys must be distinct");
            // 3300 (Gunnery) is the first row in the walk, 3329
            // (Minmatar Frigate) the 100th; 30650 (Amarr
            // Strategic Cruiser, walk position 151) is beyond
            // the cap and not among the first 'e' matches.
            assert!(state.portrait_requests.contains(&(ImageKind::Type, 3300)));
            assert!(state.portrait_requests.contains(&(ImageKind::Type, 3329)));
            assert!(!state.portrait_requests.contains(&(ImageKind::Type, 30650)));
            assert!(cache.is_empty(), "no Ready image means no upload");

            // Every queued key has left NotRequested; a second
            // frame queues nothing new.
            let _ = ctx.run(egui::RawInput::default(), |ctx| {
                egui::CentralPanel::default().show(ctx, |ui| {
                    show(ui, &mut state, &sde, &mut cache);
                });
            });
            assert_eq!(state.portrait_requests.len(), 100);
            assert!(cache.is_empty());

            // Filter before the cap: searching for the
            // beyond-cap row's own name reveals it and queues
            // exactly one additional key.
            state.skill_search = "Amarr Strategic Cruiser".to_string();
            let _ = ctx.run(egui::RawInput::default(), |ctx| {
                egui::CentralPanel::default().show(ctx, |ui| {
                    show(ui, &mut state, &sde, &mut cache);
                });
            });
            assert_eq!(state.portrait_requests.len(), 101);
            assert!(state.portrait_requests.contains(&(ImageKind::Type, 30650)));
        }

        // A Failed catalogue icon never re-queues: seeding
        // (Type, 3300) as Failed leaves the queue at the other
        // 99 rendered rows.
        {
            let mut state = ready_catalogue_state(&sde);
            state.skill_search = "e".to_string();
            state
                .portraits
                .insert((ImageKind::Type, 3300), PortraitState::Failed);
            let mut cache = PortraitImageCache::new();
            let ctx = egui::Context::default();
            let _ = ctx.run(egui::RawInput::default(), |ctx| {
                egui::CentralPanel::default().show(ctx, |ui| {
                    show(ui, &mut state, &sde, &mut cache);
                });
            });
            assert_eq!(state.portrait_requests.len(), 99);
            assert!(!state.portrait_requests.contains(&(ImageKind::Type, 3300)));
            assert!(matches!(
                state.portrait_state(ImageKind::Type, 3300),
                PortraitState::Failed
            ));
            assert!(cache.is_empty());
        }
    }

    #[test]
    fn skills_demo_queues_catalogue_types_but_never_ready() {
        use crate::demo::data::seed_demo_state;

        // Demo installs Ready skills from bundled data and the
        // same bundled catalogue; the shell drain refusal
        // guarantees none spawn in demo, so the queued keys stay
        // Loading and never become Ready.
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let mut state = AppState::new(true);
        seed_demo_state(&mut state);
        assert!(state.skills.is_ready(), "demo must install Ready skills");
        state.install_skill_catalogue_type_ids(&sde);
        state.skill_search = "e".to_string();
        let mut cache = PortraitImageCache::new();
        let ctx = egui::Context::default();
        let _ = ctx.run(egui::RawInput::default(), |ctx| {
            egui::CentralPanel::default().show(ctx, |ui| {
                show(ui, &mut state, &sde, &mut cache);
            });
        });
        assert_eq!(state.portrait_requests.len(), 100);
        let mut queued_ids: Vec<i64> = state.portrait_requests.iter().map(|(_, id)| *id).collect();
        queued_ids.sort_unstable();
        queued_ids.dedup();
        assert_eq!(queued_ids.len(), 100, "queued keys must be distinct");
        assert!(cache.is_empty(), "blank-box path uploads nothing in demo");
        for (_, id) in &state.portrait_requests {
            assert!(!matches!(
                state.portrait_state(ImageKind::Type, *id),
                PortraitState::Ready(_)
            ));
        }
    }
}
