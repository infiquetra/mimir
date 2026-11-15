//! Characters: list/detail, add via EVE SSO, delete/logout.

use super::widgets;
use crate::app::state::{AppState, LoadState};
use crate::names::resolver::NameResolver;

pub fn show(ui: &mut egui::Ui, state: &mut AppState, resolver: &NameResolver) {
    ui.heading("Characters");
    if state.characters.is_empty() {
        widgets::no_character_panel(ui);
        if ui.button("Add character (EVE SSO)").clicked() {
            tracing::info!("[AUTH] add-character requested from Characters view (stub)");
        }
        return;
    }
    for c in &state.characters {
        let corp = resolver.name(c.corporation_id);
        ui.label(format!("{} — corporation: {}", c.name, corp));
    }
    ui.separator();
    match &state.character_detail {
        LoadState::Ready(info) => {
            ui.label(format!("Name: {}", info.name));
            ui.label(format!("Security status: {:.2}", info.security_status));
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading character..."),
        LoadState::Empty => widgets::empty_panel(ui, "Select a character to see details."),
        LoadState::Error(e) => widgets::error_panel(ui, e),
    }
    if ui.button("Log out active character").clicked() {
        tracing::info!("[CHAR] logout requested (stub)");
    }
}
