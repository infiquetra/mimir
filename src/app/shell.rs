//! egui application shell: character rail, view switcher, top bar.

use std::sync::{Arc, Mutex};

use super::state::{AppState, View};
use crate::names::resolver::NameResolver;
use crate::names::sde::Sde;
use crate::ui;

pub struct MimirApp {
    pub state: AppState,
    pub sde: Sde,
    pub resolver: NameResolver,
    pub log_buffer: Arc<Mutex<Vec<String>>>,
    _runtime: Option<tokio::runtime::Runtime>,
}

impl MimirApp {
    pub fn new(
        demo: bool,
        log_buffer: Arc<Mutex<Vec<String>>>,
        runtime: Option<tokio::runtime::Runtime>,
    ) -> Self {
        tracing::info!("[STARTUP] MimirApp::new demo={}", demo);
        let sde = Sde::load_bundled().unwrap_or_default();
        let mut state = AppState::new(demo);
        if demo {
            tracing::info!("[DEMO] seeding demo state");
            crate::demo::data::seed_demo_state(&mut state);
        }
        Self {
            state,
            sde,
            resolver: NameResolver::new(),
            log_buffer,
            _runtime: runtime,
        }
    }

    fn handle_keys(&mut self, ctx: &egui::Context) {
        ctx.input(|i| {
            for (idx, key) in [
                egui::Key::Num1,
                egui::Key::Num2,
                egui::Key::Num3,
                egui::Key::Num4,
                egui::Key::Num5,
            ]
            .iter()
            .enumerate()
            {
                if i.key_pressed(*key) {
                    let view = View::ALL[idx];
                    self.state.switch_view(view);
                }
            }
        });
    }
}

impl eframe::App for MimirApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.handle_keys(ctx);
        // Mirror the captured tracing output for the settings log view.
        if let Ok(buf) = self.log_buffer.lock() {
            self.state.log_lines.clone_from(&buf);
        }

        egui::TopBottomPanel::top("top_bar").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.heading("Mimir");
                if self.state.demo {
                    ui.label("[DEMO] Demo mode");
                }
                if self.state.offline {
                    ui.label("Offline: showing cached data");
                }
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if ui.button("Refresh").clicked() {
                        tracing::info!("[UI] manual refresh requested (stub)");
                        self.state.status_message =
                            "Refresh queued (live ESI wiring lands with F1).".to_string();
                    }
                });
            });
        });

        egui::SidePanel::left("character_rail").show(ctx, |ui| {
            ui.heading("Characters");
            if self.state.characters.is_empty() {
                ui.label("No characters yet.");
                if ui.button("Add character (EVE SSO)").clicked() {
                    tracing::info!("[AUTH] add-character requested (stub)");
                    self.state.status_message = "EVE SSO wiring lands with F1.".to_string();
                }
                if ui.button("Try demo").clicked() {
                    tracing::info!("[DEMO] demo requested from rail");
                    self.state.demo = true;
                    crate::demo::data::seed_demo_state(&mut self.state);
                }
            } else {
                let rows: Vec<(i64, String)> = self
                    .state
                    .characters
                    .iter()
                    .map(|c| (c.character_id, c.name.clone()))
                    .collect();
                for (id, name) in rows {
                    let selected = self.state.active_character_id == Some(id);
                    if ui.selectable_label(selected, &name).clicked() {
                        self.state.set_active_character(id);
                    }
                }
            }
            ui.separator();
            ui.heading("Views (keys 1-5)");
            for view in View::ALL {
                let selected = self.state.view == view;
                if ui.selectable_label(selected, view.label()).clicked() {
                    self.state.switch_view(view);
                }
            }
        });

        egui::CentralPanel::default().show(ctx, |ui| {
            if !self.state.status_message.is_empty() {
                ui.label(&self.state.status_message);
                ui.separator();
            }
            match self.state.view {
                View::Dashboard => {
                    ui::dashboard::show(ui, &mut self.state, &self.sde, &self.resolver)
                }
                View::Characters => ui::characters::show(ui, &mut self.state, &self.resolver),
                View::Skills => ui::skills::show(ui, &mut self.state, &self.sde),
                View::Wallet => ui::wallet::show(ui, &mut self.state, &self.resolver),
                View::Settings => ui::settings::show(ui, &mut self.state),
            }
        });
    }
}
