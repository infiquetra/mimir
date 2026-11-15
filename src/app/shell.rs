//! egui application shell: character rail, view switcher, top bar,
//! keyboard-first navigation, and per-second repaints for countdowns.

use std::sync::mpsc::{Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use super::state::{
    AppState, AuthState, CharacterSummary, LoadState, SkillsData, View, WalletData,
};
use crate::auth::callback_server::CallbackServer;
use crate::auth::oauth;
use crate::auth::token_store::{StoredTokens, TokenStore};
use crate::demo::data::DemoBundle;
use crate::esi::endpoints;
use crate::esi::models::CharacterPublicInfo;
use crate::names::resolver::NameResolver;
use crate::names::sde::Sde;
use crate::storage::repositories::{self, CharacterRow, TokenMetaRow};
use crate::ui;
use crate::EsiClient;

/// Live backends constructed in `src/main.rs` and handed to the shell.
/// Tokens live only inside `token_store`; nothing here logs token values.
pub struct Backends {
    pub esi: Arc<EsiClient>,
    pub token_store: Arc<TokenStore>,
    pub db: Arc<Mutex<rusqlite::Connection>>,
}

enum BackendMsg {
    Refreshed {
        character_id: i64,
        info: Box<CharacterPublicInfo>,
        skills: Box<SkillsData>,
        wallet: Box<WalletData>,
    },
    RefreshFailed {
        message: String,
    },
    LoggedIn {
        row: CharacterRow,
    },
    LoginFailed {
        message: String,
    },
}

pub struct MimirApp {
    pub state: AppState,
    pub sde: Sde,
    pub resolver: NameResolver,
    pub log_buffer: Arc<Mutex<Vec<String>>>,
    runtime: Option<tokio::runtime::Runtime>,
    backends: Option<Backends>,
    demo_bundle: Option<DemoBundle>,
    last_active_id: Option<i64>,
    tx: Sender<BackendMsg>,
    rx: Receiver<BackendMsg>,
    demo_names_loaded: bool,
}

#[derive(Default)]
struct KeyActions {
    switch_view: Option<View>,
    refresh: bool,
    focus_search: bool,
    cycle_character: isize,
}

impl MimirApp {
    pub fn new(
        demo: bool,
        log_buffer: Arc<Mutex<Vec<String>>>,
        runtime: Option<tokio::runtime::Runtime>,
        backends: Option<Backends>,
    ) -> Self {
        tracing::info!("[STARTUP] MimirApp::new demo={}", demo);
        let sde = Sde::load_bundled().unwrap_or_else(|e| {
            tracing::warn!("[SKILLS] bundled SDE failed to load: {}", e);
            Sde::default()
        });
        let (tx, rx) = std::sync::mpsc::channel();
        let mut state = AppState::new(demo);
        let mut resolver = if demo {
            crate::demo::data::demo_resolver().unwrap_or_else(|e| {
                tracing::warn!("[DEMO] demo resolver failed: {}", e);
                NameResolver::new()
            })
        } else {
            NameResolver::new()
        };
        let mut demo_bundle = None;
        if let Some(b) = &backends {
            if let Ok(conn) = b.db.lock() {
                if demo {
                    match crate::demo::data::seed_into_db(&conn) {
                        Ok(()) => tracing::info!("[DEMO] seeded demo rows into database"),
                        Err(e) => tracing::warn!("[DEMO] seed_into_db failed: {}", e),
                    }
                }
                match resolver.hydrate_from_db(&conn) {
                    Ok(n) => tracing::info!("[ESI] hydrated {} cached universe names", n),
                    Err(e) => tracing::warn!("[ESI] name hydrate failed: {}", e),
                }
                if !demo {
                    match repositories::list_characters(&conn) {
                        Ok(rows) => {
                            tracing::info!("[CHAR] loaded {} stored characters", rows.len());
                            state.active_character_id =
                                rows.iter().find(|r| r.is_active).map(|r| r.character_id);
                            state.characters = rows;
                        }
                        Err(e) => tracing::warn!("[CHAR] list_characters failed: {}", e),
                    }
                }
                if let Ok(Some(saved)) = repositories::get_setting(&conn, "startup_view") {
                    if let Some(view) = View::ALL.iter().find(|v| v.label() == saved) {
                        tracing::info!("[STARTUP] applying saved startup view {}", saved);
                        state.startup_view = *view;
                        state.view = *view;
                    }
                }
            }
            resolver.attach(b.esi.clone(), b.db.clone());
        }
        if demo {
            tracing::info!("[DEMO] seeding demo state");
            match crate::demo::data::load_demo_bundle() {
                Ok(bundle) => demo_bundle = Some(bundle),
                Err(e) => tracing::warn!("[DEMO] bundle load failed: {}", e),
            }
            crate::demo::data::seed_demo_state(&mut state);
        }
        let last_active_id = state.active_character_id;
        let mut app = Self {
            state,
            sde,
            resolver,
            log_buffer,
            runtime,
            backends,
            demo_bundle,
            last_active_id,
            tx,
            rx,
            demo_names_loaded: false,
        };
        app.ensure_demo_names();
        if !demo && app.state.active_character_id.is_some() {
            app.state.request_refresh("startup");
        }
        app
    }

    fn drain_requests(&mut self) {
        while let Ok(msg) = self.rx.try_recv() {
            match msg {
                BackendMsg::Refreshed {
                    character_id,
                    info,
                    skills,
                    wallet,
                } => {
                    tracing::info!("[ESI] refresh complete character_id={}", character_id);
                    let training = skills.queue.first();
                    self.state.summaries.insert(
                        character_id,
                        CharacterSummary {
                            balance: Some(wallet.balance),
                            training_skill_name: training.map(|t| self.sde.skill_name(t.skill_id)),
                            training_finish_date: training.and_then(|t| t.finish_date.clone()),
                            queue_len: Some(skills.queue.len()),
                            total_sp: Some(skills.skills.total_sp),
                            location_name: None,
                            ship_name: None,
                        },
                    );
                    self.state.dashboard = LoadState::Ready((*info).clone());
                    self.state.character_detail = LoadState::Ready(*info);
                    self.state.skills = LoadState::Ready(*skills);
                    self.state.wallet = LoadState::Ready(*wallet);
                    self.state.offline = false;
                    self.state.status_message = "Refresh complete.".to_string();
                }
                BackendMsg::RefreshFailed { message } => {
                    tracing::warn!("[ESI] refresh failed: {}", message);
                    self.state.offline = true;
                    self.state.status_message = format!("Refresh failed: {message}");
                    if !self.state.skills.is_ready() {
                        self.state.skills = LoadState::Error(message.clone());
                    }
                    if !self.state.wallet.is_ready() {
                        self.state.wallet = LoadState::Error(message);
                    }
                }
                BackendMsg::LoggedIn { row } => {
                    tracing::info!("[AUTH] login complete character_id={}", row.character_id);
                    self.state.auth = AuthState::Success;
                    let id = row.character_id;
                    if !self.state.characters.iter().any(|c| c.character_id == id) {
                        self.state.characters.push(row);
                    }
                    self.state.set_active_character(id);
                    self.state.status_message = "Signed in. Refreshing...".to_string();
                    self.state.request_refresh("post-login");
                }
                BackendMsg::LoginFailed { message } => {
                    tracing::warn!("[AUTH] login failed: {}", message);
                    self.state.auth = AuthState::Error;
                    self.state.status_message = format!("Sign-in failed: {message}");
                }
            }
        }
        // Demo character switching swaps per-view data from the cached bundle.
        if self.state.active_character_id != self.last_active_id {
            self.last_active_id = self.state.active_character_id;
            if self.state.demo {
                if let (Some(bundle), Some(id)) =
                    (self.demo_bundle.clone(), self.state.active_character_id)
                {
                    crate::demo::data::apply_character(&mut self.state, &bundle, id);
                }
            } else {
                self.state.request_refresh("character-switch");
            }
        }
        if self.state.refresh_requested || self.state.retry_requested {
            self.state.refresh_requested = false;
            self.state.retry_requested = false;
            self.start_refresh();
        }
        if self.state.login_requested {
            self.state.login_requested = false;
            self.start_login();
        }
        if let Some(id) = self.state.logout_requested_id.take() {
            self.logout(id);
        }
        if let Some(id) = self.state.delete_requested_id.take() {
            self.delete_character(id);
        }
    }

    fn start_refresh(&mut self) {
        if self.state.demo {
            if let (Some(bundle), Some(id)) =
                (self.demo_bundle.clone(), self.state.active_character_id)
            {
                crate::demo::data::apply_character(&mut self.state, &bundle, id);
            }
            return;
        }
        let (Some(backends), Some(runtime), Some(id)) = (
            self.backends.as_ref(),
            self.runtime.as_ref(),
            self.state.active_character_id,
        ) else {
            tracing::warn!("[ESI] refresh skipped: no backend/character");
            return;
        };
        let esi = backends.esi.clone();
        let db = backends.db.clone();
        let tx = self.tx.clone();
        tracing::info!("[ESI] refresh started character_id={}", id);
        runtime.spawn(async move {
            let result = async {
                let info = endpoints::get_character(&esi, id).await?;
                let skills = endpoints::get_skills(&esi, id).await?;
                let queue = endpoints::get_skill_queue(&esi, id).await?;
                let wallet = WalletData {
                    balance: endpoints::get_wallet_balance(&esi, id).await?,
                    journal: endpoints::get_wallet_journal(&esi, id).await?,
                    transactions: endpoints::get_wallet_transactions(&esi, id).await?,
                    loyalty: endpoints::get_loyalty_points(&esi, id)
                        .await
                        .unwrap_or_default(),
                };
                Ok::<_, crate::AppError>((info, SkillsData { skills, queue }, wallet))
            }
            .await;
            match result {
                Ok((info, skills, wallet)) => {
                    if let Ok(conn) = db.lock() {
                        let _ = repositories::upsert_character(
                            &conn,
                            &CharacterRow {
                                character_id: id,
                                name: info.name.clone(),
                                corporation_id: info.corporation_id,
                                alliance_id: info.alliance_id,
                                is_active: true,
                            },
                        );
                        let _ = repositories::set_wallet_balance(
                            &conn,
                            &repositories::WalletBalanceRow {
                                character_id: id,
                                balance: wallet.balance,
                            },
                        );
                    }
                    let _ = tx.send(BackendMsg::Refreshed {
                        character_id: id,
                        info: Box::new(info),
                        skills: Box::new(skills),
                        wallet: Box::new(wallet),
                    });
                }
                Err(e) => {
                    let _ = tx.send(BackendMsg::RefreshFailed {
                        message: e.to_string(),
                    });
                }
            }
        });
    }

    fn start_login(&mut self) {
        let (Some(backends), Some(runtime)) = (self.backends.as_ref(), self.runtime.as_ref())
        else {
            self.state.status_message = "Sign-in unavailable: live backends not wired.".to_string();
            return;
        };
        let request = match oauth::create_authorization_request() {
            Ok(r) => r,
            Err(e) => {
                self.state.auth = AuthState::Error;
                self.state.status_message = format!("Sign-in failed: {e}");
                return;
            }
        };
        tracing::info!("[AUTH] opening browser for EVE SSO (url not logged with state)");
        if let Err(e) = open::that(request.authorize_url.as_str()) {
            self.state.auth = AuthState::Error;
            self.state.status_message = format!("Could not open browser: {e}");
            return;
        }
        self.state.auth = AuthState::AwaitingCallback;
        let token_store = backends.token_store.clone();
        let db = backends.db.clone();
        let tx = self.tx.clone();
        runtime.spawn(async move {
            let outcome = async {
                let params = CallbackServer::new().wait_for_callback().await?;
                let code = params.into_result(&request.state)?;
                let tokens = oauth::exchange_code(&code, &request.pkce.verifier).await?;
                let claims = oauth::parse_jwt_claims(&tokens.access_token)?;
                let character_id = claims
                    .character_id()
                    .ok_or(crate::AuthError::MalformedToken)?;
                let stored = StoredTokens::from_token_response(character_id, &tokens);
                token_store.save(&stored)?;
                if let Ok(conn) = db.lock() {
                    let _ = repositories::set_token_meta(
                        &conn,
                        &TokenMetaRow {
                            character_id,
                            scopes: claims.scp.join(" "),
                            expires_at: claims.exp,
                        },
                    );
                }
                Ok::<_, crate::AppError>(CharacterRow {
                    character_id,
                    name: if claims.name.is_empty() {
                        "Unknown Item".to_string()
                    } else {
                        claims.name.clone()
                    },
                    corporation_id: 0,
                    alliance_id: None,
                    is_active: true,
                })
            }
            .await;
            match outcome {
                Ok(row) => {
                    let _ = tx.send(BackendMsg::LoggedIn { row });
                }
                Err(e) => {
                    let _ = tx.send(BackendMsg::LoginFailed {
                        message: e.to_string(),
                    });
                }
            }
        });
    }

    fn logout(&mut self, character_id: i64) {
        tracing::info!("[AUTH] logout character_id={}", character_id);
        if let (Some(backends), Some(runtime)) = (self.backends.as_ref(), self.runtime.as_ref()) {
            if let Ok(Some(tokens)) = backends.token_store.load(character_id) {
                let refresh = tokens.refresh.as_str().to_string();
                runtime.spawn(async move {
                    let _ = oauth::revoke_token(&refresh).await;
                });
            }
            let _ = backends.token_store.delete(character_id);
        }
        self.state.remove_character(character_id);
    }

    fn delete_character(&mut self, character_id: i64) {
        tracing::info!("[CHAR] delete character_id={}", character_id);
        if let Some(backends) = self.backends.as_ref() {
            let _ = backends.token_store.delete(character_id);
            if let Ok(conn) = backends.db.lock() {
                let _ = repositories::delete_character(&conn, character_id);
            }
        }
        self.state.remove_character(character_id);
    }

    /// Demo rows reference invented universe ids; load their pre-resolved
    /// names so demo cells show names, never raw IDs.
    fn ensure_demo_names(&mut self) {
        if !self.state.demo || self.demo_names_loaded {
            return;
        }
        match crate::demo::data::load_demo_names() {
            Ok(names) => {
                tracing::info!("[DEMO] loaded {} demo universe names", names.len());
                for name in names {
                    self.resolver.insert(name.id, name.name);
                }
            }
            Err(e) => {
                tracing::warn!("[DEMO] demo names failed to load: {}", e);
            }
        }
        self.demo_names_loaded = true;
    }

    fn collect_keys(&self, ctx: &egui::Context) -> KeyActions {
        let typing = self.state.text_input_focused;
        ctx.input(|i| {
            let mut actions = KeyActions::default();
            let command_r =
                i.key_pressed(egui::Key::R) && (i.modifiers.command || i.modifiers.ctrl);
            if command_r || i.key_pressed(egui::Key::F5) {
                actions.refresh = true;
            }
            if typing {
                return actions;
            }
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
                if i.key_pressed(*key) && !i.modifiers.command && !i.modifiers.ctrl {
                    actions.switch_view = View::from_index(idx);
                }
            }
            if i.key_pressed(egui::Key::PageDown) {
                actions.cycle_character = 1;
            }
            if i.key_pressed(egui::Key::PageUp) {
                actions.cycle_character = -1;
            }
            for event in &i.events {
                if let egui::Event::Text(text) = event {
                    if text == "/" {
                        actions.focus_search = true;
                    }
                }
            }
            actions
        })
    }

    fn apply_keys(&mut self, actions: KeyActions) {
        if let Some(view) = actions.switch_view {
            tracing::debug!("[UI] keyboard switch to {}", view.label());
            self.state.switch_view(view);
        }
        if actions.refresh {
            self.state.request_refresh("keyboard");
        }
        if actions.cycle_character != 0 {
            self.state.cycle_character(actions.cycle_character);
        }
        if actions.focus_search {
            tracing::debug!("[UI] keyboard focus-search requested");
            self.state.focus_search = true;
        }
    }

    fn needs_tick(&self) -> bool {
        if self.state.auth.is_busy() {
            return true;
        }
        match &self.state.skills {
            LoadState::Ready(data) => data.queue.iter().any(|item| item.finish_date.is_some()),
            _ => false,
        }
    }
}

impl eframe::App for MimirApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.drain_requests();
        // Persist startup-view choice when it changes (settings view edits it).
        if let Some(backends) = self.backends.as_ref() {
            if let Ok(conn) = backends.db.lock() {
                let saved = repositories::get_setting(&conn, "startup_view")
                    .ok()
                    .flatten();
                if saved.as_deref() != Some(self.state.startup_view.label()) {
                    let _ = repositories::set_setting(
                        &conn,
                        "startup_view",
                        self.state.startup_view.label(),
                    );
                }
            }
        }
        let actions = self.collect_keys(ctx);
        self.apply_keys(actions);
        // Reset after key handling; views re-set it while rendering so the
        // next frame knows whether a text box owns the keyboard.
        self.state.text_input_focused = false;
        self.ensure_demo_names();
        if self.needs_tick() {
            ctx.request_repaint_after(Duration::from_secs(1));
        }

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
                if let Some(active) = self.state.active_character() {
                    ui.label(format!("Active: {}", active.name));
                }
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if ui.button("Refresh (Ctrl+R)").clicked() {
                        self.state.request_refresh("top-bar button");
                    }
                });
            });
        });

        egui::SidePanel::left("character_rail").show(ctx, |ui| {
            ui.heading("Characters");
            if self.state.characters.is_empty() {
                ui.label("No characters yet.");
                if ui.button("Add character (EVE SSO)").clicked() {
                    tracing::info!("[AUTH] add-character requested from rail");
                    self.state.login_requested = true;
                    self.state.switch_view(View::Characters);
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
                ui.label("PageUp/PageDown switches character.");
            }
            ui.separator();
            ui.heading("Views (keys 1-5)");
            for (idx, view) in View::ALL.iter().enumerate() {
                let selected = self.state.view == *view;
                if ui
                    .selectable_label(selected, format!("{} {}", idx + 1, view.label()))
                    .clicked()
                {
                    self.state.switch_view(*view);
                }
            }
        });

        egui::CentralPanel::default().show(ctx, |ui| {
            if !self.state.status_message.is_empty() {
                ui.label(&self.state.status_message);
                ui.separator();
            }
            egui::ScrollArea::vertical().show(ui, |ui| match self.state.view {
                View::Dashboard => {
                    ui::dashboard::show(ui, &mut self.state, &self.sde, &self.resolver)
                }
                View::Characters => ui::characters::show(ui, &mut self.state, &self.resolver),
                View::Skills => ui::skills::show(ui, &mut self.state, &self.sde),
                View::Wallet => ui::wallet::show(ui, &mut self.state, &self.resolver),
                View::Settings => ui::settings::show(ui, &mut self.state),
            });
        });

        egui::TopBottomPanel::bottom("status_bar").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.label(format!("View: {}", self.state.view.label()));
                ui.label(format!("Characters: {}", self.state.characters.len()));
                if self.state.refresh_requested {
                    ui.label("Refresh pending...");
                }
                ui.label("Keys: 1-5 views, Ctrl+R refresh, / search, PgUp/PgDn character");
            });
        });
    }
}
