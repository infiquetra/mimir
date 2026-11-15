//! Skills: queue with finish countdowns and the SDE catalogue. Skill
//! names always come from the SDE, never raw IDs.

use super::widgets;
use crate::app::state::{AppState, LoadState};
use crate::names::sde::Sde;

pub fn show(ui: &mut egui::Ui, state: &mut AppState, sde: &Sde) {
    ui.heading("Skills");
    if state.active_character().is_none() {
        widgets::no_character_panel(ui);
        return;
    }
    match &state.skills {
        LoadState::Ready(data) => {
            ui.label(format!(
                "Total skill points: {} (unallocated: {})",
                data.skills.total_sp,
                data.skills.unallocated_sp.unwrap_or(0)
            ));
            ui.separator();
            ui.label("Training queue:");
            if data.queue.is_empty() {
                ui.label("Queue is empty.");
            }
            for item in &data.queue {
                let name = sde.skill_name(item.skill_id);
                let finish = item.finish_date.as_deref().unwrap_or("paused");
                ui.label(format!(
                    "{}. {} level {} — finishes {}",
                    item.queue_position + 1,
                    name,
                    item.finished_level,
                    finish
                ));
            }
            ui.separator();
            ui.label("Catalogue (by SDE group):");
            for group in &sde.groups {
                ui.label(&group.group_name);
            }
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading skills..."),
        LoadState::Empty => widgets::empty_panel(ui, "No skill data yet."),
        LoadState::Error(e) => widgets::error_panel(ui, e),
    }
}
