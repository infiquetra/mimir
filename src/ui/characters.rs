//! Characters: switcher list/detail, add via EVE SSO, delete/logout.
//! Corporation and alliance cells use resolved names, never raw IDs.
//! Auth and persistence run in F1/F2: this view only sets the request
//! flags on `AppState` and reflects `AuthState`.

use super::widgets;
use crate::app::state::{AppState, AuthState, LoadState};
use crate::names::resolver::NameResolver;

pub fn show(ui: &mut egui::Ui, state: &mut AppState, resolver: &NameResolver) {
    ui.heading("Characters");
    widgets::mode_notice(ui, state.demo, state.offline);

    // --- Auth status + add-character ---
    ui.label(format!("Sign-in: {}", state.auth.label()));
    if state.auth.is_busy() {
        ui.spinner();
        ui.label("Complete the EVE login in your browser; Mimir is waiting on 127.0.0.1:54321.");
    }
    ui.horizontal(|ui| {
        let add_enabled = !state.auth.is_busy();
        if ui
            .add_enabled(add_enabled, egui::Button::new("Add character (EVE SSO)"))
            .clicked()
        {
            tracing::info!("[AUTH] add-character requested from Characters view");
            state.login_requested = true;
            state.status_message =
                "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();
        }
        if state.characters.is_empty() && ui.button("Try demo").clicked() {
            tracing::info!("[DEMO] demo requested from Characters view");
            state.demo = true;
            crate::demo::data::seed_demo_state(state);
        }
    });
    if state.auth == AuthState::Error {
        ui.colored_label(
            egui::Color32::LIGHT_RED,
            "Sign-in failed. Check the log in Settings (key 5), then try again.",
        );
    }

    if state.characters.is_empty() {
        widgets::no_character_panel(ui);
        return;
    }

    // --- Switcher list (PageUp/PageDown also cycles, see shell) ---
    ui.separator();
    ui.heading("Switch character (PageUp/PageDown)");
    let mut switch_to: Option<i64> = None;
    let rows: Vec<(i64, String, String, Option<String>, bool)> = state
        .characters
        .iter()
        .map(|c| {
            (
                c.character_id,
                c.name.clone(),
                resolver.name(c.corporation_id),
                c.alliance_id.map(|id| resolver.name(id)),
                c.is_active,
            )
        })
        .collect();
    for (id, name, corp, alliance, is_active) in &rows {
        let mut label = format!("{} — {}", name, corp);
        if let Some(alliance) = alliance {
            label.push_str(&format!(" / {}", alliance));
        }
        if *is_active {
            label.push_str(" (active)");
        }
        if ui.selectable_label(*is_active, label).clicked() {
            switch_to = Some(*id);
        }
    }
    if let Some(id) = switch_to {
        state.set_active_character(id);
    }

    // --- Active character detail ---
    ui.separator();
    ui.heading("Active character");
    match &state.character_detail {
        LoadState::Ready(info) => {
            let corp = resolver.name(info.corporation_id);
            let portrait_name = if info.name.is_empty() {
                state
                    .active_character()
                    .map(|c| c.name.clone())
                    .unwrap_or_else(|| "Unknown Item".to_string())
            } else {
                info.name.clone()
            };
            egui::Grid::new("character_detail")
                .striped(true)
                .show(ui, |ui| {
                    ui.label("Name");
                    ui.label(&portrait_name);
                    ui.end_row();
                    ui.label("Corporation");
                    ui.label(&corp);
                    ui.end_row();
                    if let Some(alliance_id) = info.alliance_id {
                        ui.label("Alliance");
                        ui.label(resolver.name(alliance_id));
                        ui.end_row();
                    }
                    ui.label("Security status");
                    ui.label(format!("{:.2}", info.security_status));
                    ui.end_row();
                    if !info.birthday.is_empty() {
                        ui.label("Born");
                        ui.label(widgets::format_date_short(&info.birthday));
                        ui.end_row();
                    }
                });
            if let Some(summary) = state
                .active_character_id
                .and_then(|id| state.summaries.get(&id))
            {
                if let Some(location) = &summary.location_name {
                    ui.label(format!("Location: {}", location));
                }
                if let Some(ship) = &summary.ship_name {
                    ui.label(format!("Ship: {}", ship));
                }
                if let Some(sp) = summary.total_sp {
                    ui.label(format!("Skill points: {}", widgets::format_sp(sp)));
                }
            }
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading character..."),
        LoadState::Empty => widgets::empty_panel(ui, "Select a character to see details."),
        LoadState::Error(e) => {
            if widgets::error_panel_with_retry(ui, e) {
                tracing::warn!("[CHAR] retry requested after detail load error");
                state.retry_requested = true;
            }
        }
    }

    // --- Logout / delete (two-step inline confirm, no modal traps) ---
    if let Some(active) = state
        .active_character()
        .map(|c| (c.character_id, c.name.clone()))
    {
        ui.separator();
        ui.horizontal(|ui| {
            if ui.button(format!("Log out {}", active.1)).clicked() {
                tracing::info!("[AUTH] logout requested character selected");
                state.logout_requested_id = Some(active.0);
                state.status_message = "Logout requested (token cleanup runs via F1).".to_string();
            }
            if state.confirm_delete_id == Some(active.0) {
                if ui.button("Confirm delete").clicked() {
                    tracing::warn!("[CHAR] delete confirmed character selected");
                    state.delete_requested_id = Some(active.0);
                    state.confirm_delete_id = None;
                    state.remove_character(active.0);
                    state.status_message = "Character removed locally.".to_string();
                }
                if ui.button("Cancel").clicked() {
                    state.confirm_delete_id = None;
                }
            } else if ui.button("Delete character...").clicked() {
                tracing::info!("[CHAR] delete requested, awaiting confirmation");
                state.confirm_delete_id = Some(active.0);
            }
        });
    }
}
