//! Skills: queue with live finish countdowns and the SDE catalogue.
//! Skill names always come from the SDE, never raw IDs.

use std::collections::BTreeMap;

use chrono::Utc;

use super::widgets;
use crate::app::state::{AppState, LoadState};
use crate::esi::models::SkillQueueItem;
use crate::names::sde::Sde;

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

pub fn show(ui: &mut egui::Ui, state: &mut AppState, sde: &Sde) {
    ui.heading("Skills");
    widgets::mode_notice(ui, state.demo, state.offline);
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
                .max_height(320.0)
                .show(ui, |ui| {
                    let mut any_match = false;
                    for group in &sde.groups {
                        let mut rows: Vec<String> = Vec::new();
                        for skill in sde.types.iter().filter(|t| t.group_id == group.group_id) {
                            if !widgets::matches_search(&skill.type_name, &query) {
                                continue;
                            }
                            any_match = true;
                            let level = levels.get(&skill.type_id).copied().unwrap_or(0);
                            rows.push(format!("{} — trained level {}", skill.type_name, level));
                        }
                        if rows.is_empty() {
                            continue;
                        }
                        egui::CollapsingHeader::new(&group.group_name)
                            .default_open(!query.is_empty())
                            .show(ui, |ui| {
                                for row in &rows {
                                    ui.label(row);
                                }
                            });
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
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
