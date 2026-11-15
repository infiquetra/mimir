//! Settings: startup behavior, demo toggle, structured log view, about.

use crate::app::state::AppState;

pub fn show(ui: &mut egui::Ui, state: &mut AppState) {
    ui.heading("Settings");
    let mut demo = state.demo;
    if ui
        .checkbox(&mut demo, "Demo mode (offline sample data)")
        .changed()
    {
        tracing::info!("[UI] demo toggle changed to {}", demo);
        state.demo = demo;
        if demo {
            crate::demo::data::seed_demo_state(state);
        }
    }
    ui.label("Startup view choice and log filters land with F3.");
    ui.separator();
    ui.heading("Logs");
    ui.label("Structured tracing output (tokens are never logged).");
    egui::ScrollArea::vertical()
        .max_height(300.0)
        .show(ui, |ui| {
            if state.log_lines.is_empty() {
                ui.label("No log lines captured yet.");
            }
            for line in &state.log_lines {
                ui.monospace(line);
            }
        });
    ui.separator();
    ui.heading("About");
    ui.label("Mimir — EVE Online companion (Rust/egui).");
    ui.label(format!("Version {}", env!("CARGO_PKG_VERSION")));
}
