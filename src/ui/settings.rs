//! Settings and auth: startup view, demo toggle, sign-in status, and
//! the structured in-app log view. Tokens are never shown or logged here.

use crate::app::state::{AppState, AuthState, View};

/// Bracketed feature tags the log filter can select (design section 1).
pub const LOG_TAGS: [&str; 14] = [
    "[AUTH]",
    "[ESI]",
    "[ASSETS]",
    "[WALLET]",
    "[SKILLS]",
    "[CHAR]",
    "[INDUSTRY]",
    "[PI]",
    "[FITTING]",
    "[EXPLORE]",
    "[DB]",
    "[DEMO]",
    "[UI]",
    "[STARTUP]",
];

/// Pure log filter: substring (case-insensitive) plus optional tag.
/// Malformed lines are kept when they match; nothing panics.
pub fn filter_log_lines<'a>(lines: &'a [String], query: &str, tag: Option<&str>) -> Vec<&'a str> {
    lines
        .iter()
        .map(|line| line.as_str())
        .filter(|line| tag.map(|t| line.contains(t)).unwrap_or(true))
        .filter(|line| query.is_empty() || line.to_lowercase().contains(&query.to_lowercase()))
        .collect()
}

pub fn show(ui: &mut egui::Ui, state: &mut AppState) {
    ui.heading("Settings");

    // --- Auth ---
    ui.heading("EVE account (auth)");
    ui.label(format!("Sign-in: {}", state.auth.label()));
    ui.label(format!(
        "{} character(s) added{}",
        state.characters.len(),
        if state.demo { " (demo data)" } else { "" }
    ));
    ui.horizontal(|ui| {
        let enabled = !state.auth.is_busy();
        if ui
            .add_enabled(enabled, egui::Button::new("Add character (EVE SSO)"))
            .clicked()
        {
            tracing::info!("[AUTH] add-character requested from Settings view");
            state.login_requested = true;
            state.status_message =
                "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();
        }
        if let Some(active_id) = state.active_character_id {
            if ui.button("Log out active character").clicked() {
                tracing::info!("[AUTH] logout requested from Settings view");
                state.logout_requested_id = Some(active_id);
            }
        }
    });
    if state.auth == AuthState::Error {
        ui.colored_label(
            egui::Color32::LIGHT_RED,
            "Last sign-in attempt failed; see the log below for details.",
        );
    }
    ui.label("Tokens live in the OS keyring and never appear in logs.");
    ui.separator();

    // --- Behavior ---
    ui.heading("Behavior");
    let mut demo = state.demo;
    if ui
        .checkbox(&mut demo, "Demo mode (offline sample data)")
        .changed()
    {
        tracing::info!("[UI] demo toggle changed to {}", demo);
        state.demo = demo;
        if demo {
            crate::demo::data::seed_demo_state(state);
        } else {
            state.status_message =
                "Demo off. Live characters load after sign-in/refresh.".to_string();
        }
    }
    ui.horizontal(|ui| {
        ui.label("Startup view:");
        for view in View::ALL {
            if ui
                .selectable_label(state.startup_view == view, view.label())
                .clicked()
            {
                tracing::info!("[UI] startup view set to {}", view.label());
                state.startup_view = view;
                state.status_message = format!(
                    "Startup view set to {} (saved with the next settings write).",
                    view.label()
                );
            }
        }
    });
    if state.offline {
        ui.label("Status: offline (showing cached data).");
    } else if state.demo {
        ui.label("Status: demo mode (no network).");
    } else {
        ui.label("Status: online mode (live data after sign-in).");
    }
    ui.separator();

    // --- Keyboard help ---
    ui.heading("Keyboard");
    ui.monospace("1-9, 0, E views | Ctrl/Cmd+R refresh | / focus search | PgUp/PgDn character | Up/Down table rows");
    ui.separator();

    // --- Structured log / status view ---
    ui.heading("Logs");
    ui.label("Structured tracing output (tokens are never logged).");
    ui.horizontal(|ui| {
        ui.label("Filter:");
        let response = ui.text_edit_singleline(&mut state.log_filter);
        state.text_input_focused |= response.has_focus();
        if response.has_focus() {
            state.focus_search = false;
        }
        if ui.button("Clear").clicked() {
            state.log_filter.clear();
            state.log_tag_filter = None;
        }
    });
    ui.horizontal(|ui| {
        if ui
            .selectable_label(state.log_tag_filter.is_none(), "All tags")
            .clicked()
        {
            state.log_tag_filter = None;
        }
        for tag in LOG_TAGS {
            let selected = state.log_tag_filter.as_deref() == Some(tag);
            if ui.selectable_label(selected, tag).clicked() {
                tracing::debug!("[UI] log tag filter {}", tag);
                state.log_tag_filter = if selected {
                    None
                } else {
                    Some(tag.to_string())
                };
            }
        }
    });
    let filtered = filter_log_lines(
        &state.log_lines,
        &state.log_filter,
        state.log_tag_filter.as_deref(),
    );
    ui.label(format!(
        "{} of {} log lines",
        filtered.len(),
        state.log_lines.len()
    ));
    egui::ScrollArea::vertical()
        .max_height(300.0)
        .stick_to_bottom(true)
        .show(ui, |ui| {
            if filtered.is_empty() {
                ui.label("No log lines match the current filters.");
            }
            for line in &filtered {
                ui.monospace(*line);
            }
        });
    if !state.status_message.is_empty() {
        ui.label(format!("Status: {}", state.status_message));
    }
    ui.separator();

    // --- About ---
    ui.heading("About");
    ui.label("Mimir — EVE Online companion (Rust/egui).");
    ui.label(format!("Version {}", env!("CARGO_PKG_VERSION")));
    ui.label("Data: EVE ESI (esi.evetech.net) after EVE SSO sign-in; demo mode is fully offline.");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn log_filter_by_text_and_tag() {
        let lines = vec![
            "INFO [WALLET] balance loaded".to_string(),
            "WARN [AUTH] refresh needed".to_string(),
            "plain line without tag".to_string(),
        ];
        assert_eq!(filter_log_lines(&lines, "", None).len(), 3);
        assert_eq!(filter_log_lines(&lines, "wallet", None).len(), 1);
        assert_eq!(filter_log_lines(&lines, "", Some("[AUTH]")).len(), 1);
        assert_eq!(filter_log_lines(&lines, "zzz", None).len(), 0);
        assert_eq!(filter_log_lines(&[], "", None).len(), 0);
        assert!(LOG_TAGS.contains(&"[WALLET]"));
        assert!(LOG_TAGS.contains(&"[ASSETS]"));
        assert!(LOG_TAGS.contains(&"[INDUSTRY]"));
        assert!(LOG_TAGS.contains(&"[PI]"));
        assert!(LOG_TAGS.contains(&"[FITTING]"));
        assert!(LOG_TAGS.contains(&"[EXPLORE]"));
    }
}
