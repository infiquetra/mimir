//! egui application shell: character rail, view switcher, top bar,
//! keyboard-first navigation, and per-second repaints for countdowns.

use std::sync::mpsc::{Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use super::state::{
    AppState, AssetsData, AuthState, CharacterSummary, LoadState, SkillsData, StepUpRequest, View,
    WalletData,
};
use crate::auth::callback_server::CallbackServer;
use crate::auth::jwt_verify::JwtVerifier;
use crate::auth::oauth;
use crate::auth::token_store::{StoredTokens, TokenStore};
use crate::demo::data::DemoBundle;
use crate::esi::endpoints;
use crate::esi::models::{
    CharacterPublicInfo, CharacterSkills, LoyaltyPointItem, Skill, SkillQueueItem, UniverseName,
    WalletJournalItem, WalletTransactionItem,
};
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
    pub jwt_verifier: Option<Arc<JwtVerifier>>,
}

enum BackendMsg {
    Refreshed {
        character_id: i64,
        info: Box<CharacterPublicInfo>,
        skills: Box<SkillsData>,
        wallet: Box<WalletData>,
        assets: Result<Box<AssetsData>, String>,
        assets_needs_reauthorize: bool,
    },
    RefreshFailed {
        message: String,
    },
    LoggedIn {
        row: CharacterRow,
    },
    StepUpLoggedIn {
        character_id: i64,
    },
    LoginFailed {
        message: String,
    },
    NamesResolved {
        names: Vec<UniverseName>,
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
    persisted_startup_view: Option<String>,
}

#[derive(Default)]
struct KeyActions {
    switch_view: Option<View>,
    refresh: bool,
    focus_search: bool,
    cycle_character: isize,
}

/// Fill skills/wallet/summary state from the last persisted refresh so a
/// live launch renders cached data before (or without) network access.
fn load_cached_state(
    conn: &rusqlite::Connection,
    sde: &Sde,
    state: &mut AppState,
    character_id: i64,
) {
    let queue_rows = repositories::list_skill_queue(conn, character_id).unwrap_or_default();
    let skill_rows = repositories::list_character_skills(conn, character_id).unwrap_or_default();
    if !queue_rows.is_empty() || !skill_rows.is_empty() {
        tracing::info!(
            "[DB] cached skills loaded character_id={} skills={} queue={}",
            character_id,
            skill_rows.len(),
            queue_rows.len()
        );
        state.skills = LoadState::Ready(SkillsData {
            skills: CharacterSkills {
                skills: skill_rows
                    .iter()
                    .map(|r| Skill {
                        skill_id: r.skill_id,
                        active_skill_level: r.active_skill_level,
                        trained_skill_level: r.trained_skill_level,
                        skillpoints_in_skill: r.skillpoints_in_skill,
                    })
                    .collect(),
                total_sp: repositories::total_skillpoints(conn, character_id).unwrap_or_default(),
                unallocated_sp: None,
            },
            queue: queue_rows
                .iter()
                .map(|r| SkillQueueItem {
                    skill_id: r.skill_id,
                    finished_level: r.finished_level,
                    queue_position: r.queue_position,
                    start_date: r.start_date.clone(),
                    finish_date: r.finish_date.clone(),
                    ..Default::default()
                })
                .collect(),
        });
    }
    if let Ok(Some(balance)) = repositories::wallet_balance(conn, character_id) {
        tracing::info!("[DB] cached wallet loaded character_id={}", character_id);
        state.wallet = LoadState::Ready(WalletData {
            balance,
            journal: repositories::list_journal(conn, character_id)
                .unwrap_or_default()
                .iter()
                .map(|r| WalletJournalItem {
                    id: r.id,
                    amount: r.amount,
                    balance: r.balance,
                    date: r.date.clone(),
                    description: r.description.clone(),
                    ref_type: r.ref_type.clone(),
                    first_party_id: r.first_party_id,
                    second_party_id: r.second_party_id,
                    ..Default::default()
                })
                .collect(),
            transactions: repositories::list_transactions(conn, character_id)
                .unwrap_or_default()
                .iter()
                .map(|r| WalletTransactionItem {
                    transaction_id: r.transaction_id,
                    journal_ref_id: r.journal_ref_id,
                    date: r.date.clone(),
                    type_id: r.type_id,
                    quantity: r.quantity,
                    unit_price: r.unit_price,
                    is_buy: r.is_buy,
                    is_personal: r.is_personal,
                    client_id: r.client_id,
                    location_id: r.location_id,
                })
                .collect(),
            loyalty: repositories::list_loyalty(conn, character_id)
                .unwrap_or_default()
                .iter()
                .map(|r| LoyaltyPointItem {
                    corporation_id: r.corporation_id,
                    loyalty_points: r.loyalty_points,
                })
                .collect(),
        });
        state.summaries.insert(
            character_id,
            CharacterSummary {
                balance: Some(balance),
                training_skill_name: queue_rows.first().map(|q| sde.skill_name(q.skill_id)),
                training_finish_date: queue_rows.first().and_then(|q| q.finish_date.clone()),
                queue_len: Some(queue_rows.len()),
                total_sp: Some(
                    repositories::total_skillpoints(conn, character_id).unwrap_or_default(),
                ),
                location_name: None,
                ship_name: None,
            },
        );
    }
    if let Some(row) = state
        .characters
        .iter()
        .find(|c| c.character_id == character_id)
        .cloned()
    {
        let info = CharacterPublicInfo {
            name: row.name,
            corporation_id: row.corporation_id,
            alliance_id: row.alliance_id,
            ..Default::default()
        };
        state.dashboard = LoadState::Ready(info.clone());
        state.character_detail = LoadState::Ready(info);
    }
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
        let mut persisted_startup_view: Option<String> = None;
        if let Some(b) = &backends {
            if let Ok(conn) = b.db.lock() {
                // Demo data stays in memory from the bundled fixtures; it is
                // never seeded into the live database, so invented characters
                // cannot leak into a later live launch.
                if demo {
                    tracing::info!(
                        "[DEMO] demo uses bundled in-memory data; live database untouched"
                    );
                }
                match resolver.hydrate_from_db(&conn) {
                    Ok(n) => tracing::info!("[ESI] hydrated {} cached universe names", n),
                    Err(e) => tracing::warn!("[ESI] name hydrate failed: {}", e),
                }
                if !demo {
                    // One-time cleanup for databases polluted by earlier demo
                    // seeding: drop rows whose id AND name match the bundle.
                    if let Ok(bundle) = crate::demo::data::load_demo_bundle() {
                        for demo_char in &bundle.characters {
                            if let Ok(Some(row)) =
                                repositories::get_character(&conn, demo_char.character_id)
                            {
                                if row.name == demo_char.name {
                                    tracing::warn!(
                                        "[DEMO] removing polluted demo character row {}",
                                        row.name
                                    );
                                    let _ = repositories::delete_character(
                                        &conn,
                                        demo_char.character_id,
                                    );
                                }
                            }
                        }
                    }
                    match repositories::list_characters(&conn) {
                        Ok(rows) => {
                            tracing::info!("[CHAR] loaded {} stored characters", rows.len());
                            state.active_character_id =
                                rows.iter().find(|r| r.is_active).map(|r| r.character_id);
                            state.characters = rows;
                        }
                        Err(e) => tracing::warn!("[CHAR] list_characters failed: {}", e),
                    }
                    // Offline-first: render last persisted skills/wallet for
                    // the active character immediately; the startup refresh
                    // replaces them when the network answers.
                    if let Some(active_id) = state.active_character_id {
                        load_cached_state(&conn, &sde, &mut state, active_id);
                    }
                }
                if let Ok(Some(saved)) = repositories::get_setting(&conn, "startup_view") {
                    persisted_startup_view = Some(saved.clone());
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
            persisted_startup_view,
        };
        app.ensure_demo_names();
        if !demo && app.state.active_character_id.is_some() {
            app.state.request_refresh("startup");
        }
        app
    }

    /// Runtime "Try demo" entry points only seed `AppState`; load the full
    /// bundle lazily so demo character switching works on that path too.
    fn ensure_demo_bundle(&mut self) {
        if self.state.demo && self.demo_bundle.is_none() {
            match crate::demo::data::load_demo_bundle() {
                Ok(bundle) => {
                    tracing::info!("[DEMO] demo bundle lazy-loaded for runtime demo entry");
                    self.demo_bundle = Some(bundle);
                }
                Err(e) => tracing::warn!("[DEMO] bundle load failed: {}", e),
            }
        }
    }

    /// Resolve names for IDs visible in live state (corporations, wallet
    /// counterparties, items, stations) so views show names, not unknowns.
    /// Player structures are excluded: `/universe/names/` cannot resolve
    /// them and the authenticated structure lookup stays a follow-up.
    fn schedule_name_resolution(&mut self) {
        if self.state.demo {
            return;
        }
        let mut ids: Vec<i64> = Vec::new();
        for c in &self.state.characters {
            ids.push(c.corporation_id);
            ids.extend(c.alliance_id);
        }
        if let LoadState::Ready(wallet) = &self.state.wallet {
            for entry in &wallet.journal {
                ids.extend(entry.first_party_id);
                ids.extend(entry.second_party_id);
                ids.extend(entry.tax_receiver_id);
            }
            for tx in &wallet.transactions {
                ids.push(tx.type_id);
                ids.push(tx.client_id);
                if !crate::names::resolver::is_structure_id(tx.location_id) {
                    ids.push(tx.location_id);
                }
            }
            for lp in &wallet.loyalty {
                ids.push(lp.corporation_id);
            }
        }
        if let LoadState::Ready(assets) = &self.state.assets {
            for item in &assets.items {
                ids.push(item.type_id);
                if !crate::names::resolver::is_structure_id(item.location_id) {
                    ids.push(item.location_id);
                }
            }
        }
        let missing = self.resolver.missing(&ids);
        if missing.is_empty() {
            return;
        }
        let (Some(backends), Some(runtime)) = (self.backends.as_ref(), self.runtime.as_ref())
        else {
            return;
        };
        let esi = backends.esi.clone();
        let tx = self.tx.clone();
        tracing::info!("[ESI] resolving {} missing universe names", missing.len());
        runtime.spawn(async move {
            let mut all: Vec<UniverseName> = Vec::new();
            for chunk in missing.chunks(1000) {
                match endpoints::resolve_names(&esi, chunk).await {
                    Ok(mut names) => all.append(&mut names),
                    Err(e) => {
                        tracing::warn!("[ESI] universe name resolution failed: {}", e);
                        break;
                    }
                }
            }
            if !all.is_empty() {
                let _ = tx.send(BackendMsg::NamesResolved { names: all });
            }
        });
    }

    fn drain_requests(&mut self) {
        self.ensure_demo_bundle();
        while let Ok(msg) = self.rx.try_recv() {
            match msg {
                BackendMsg::Refreshed {
                    character_id,
                    info,
                    skills,
                    wallet,
                    assets,
                    assets_needs_reauthorize,
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
                    if self.state.active_character_id != Some(character_id) {
                        // Refresh started for a character the user switched
                        // away from: the keyed summary above is safe, but
                        // per-view states belong to the active character.
                        tracing::warn!(
                            "[ESI] ignoring per-view refresh for inactive character_id={}",
                            character_id
                        );
                    } else {
                        self.state.dashboard = LoadState::Ready((*info).clone());
                        self.state.character_detail = LoadState::Ready(*info);
                        self.state.skills = LoadState::Ready(*skills);
                        self.state.wallet = LoadState::Ready(*wallet);
                        match assets {
                            Ok(data) => {
                                self.state.assets = LoadState::Ready(*data);
                                self.state.assets_needs_reauthorize = false;
                            }
                            Err(message) if assets_needs_reauthorize => {
                                // The assets scope was refused: replace any
                                // stale rows rather than present them current.
                                self.state.assets = LoadState::Error(message);
                                self.state.assets_needs_reauthorize = true;
                            }
                            Err(message) => {
                                self.state.assets_needs_reauthorize = false;
                                if !self.state.assets.is_ready() {
                                    self.state.assets = LoadState::Error(message);
                                }
                            }
                        }
                        self.state.offline = false;
                        self.state.status_message = "Refresh complete.".to_string();
                        self.schedule_name_resolution();
                    }
                }
                BackendMsg::NamesResolved { names } => {
                    tracing::info!("[ESI] resolved {} universe names", names.len());
                    self.resolver.extend_from_universe_names(&names);
                    if let Some(b) = &self.backends {
                        if let Ok(conn) = b.db.lock() {
                            let rows: Vec<repositories::UniverseNameRow> = names
                                .iter()
                                .map(|n| repositories::UniverseNameRow {
                                    id: n.id,
                                    name: n.name.clone(),
                                    category: n.category.clone(),
                                })
                                .collect();
                            let _ = repositories::upsert_universe_names(&conn, &rows);
                        }
                    }
                }
                BackendMsg::RefreshFailed { message } => {
                    tracing::warn!("[ESI] refresh failed: {}", message);
                    self.state.offline = true;
                    self.state.status_message = format!("Refresh failed: {message}");
                    if !self.state.skills.is_ready() {
                        self.state.skills = LoadState::Error(message.clone());
                    }
                    if !self.state.wallet.is_ready() {
                        self.state.wallet = LoadState::Error(message.clone());
                    }
                    if !self.state.assets.is_ready() {
                        self.state.assets = LoadState::Error(message);
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
                BackendMsg::StepUpLoggedIn { character_id } => {
                    tracing::info!("[AUTH] step-up complete character_id={}", character_id);
                    self.state.auth = AuthState::Success;
                    if self.state.active_character_id == Some(character_id) {
                        // Do NOT clear assets_needs_reauthorize here: login
                        // success alone does not prove the grant loads data.
                        // The Refreshed Ok(assets) arm clears it once a
                        // refresh actually succeeds; a failed refresh leaves
                        // the Re-authorize panel in place.
                        // request_refresh sets its own generic status, so the
                        // specific step-up status must be set after it.
                        self.state.request_refresh("post-stepup");
                        self.state.status_message = "Permission granted. Refreshing...".to_string();
                    } else {
                        self.state.status_message = "Permission granted. Refreshing...".to_string();
                        tracing::warn!(
                            "[AUTH] step-up finished for non-active character_id={}",
                            character_id
                        );
                    }
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
        if let Some(request) = self.state.stepup_requested.take() {
            self.start_stepup_login(request);
        }
        if let Some(id) = self.state.logout_requested_id.take() {
            // UI disables these buttons while busy; this drain guard is
            // the backstop so no path can delete tokens mid-callback.
            if self.state.auth.is_busy() {
                tracing::warn!(
                    "[AUTH] ignoring logout while sign-in in progress character_id={}",
                    id
                );
                self.state.status_message =
                    "Finish sign-in in your browser before logging out or deleting characters."
                        .to_string();
            } else {
                self.logout(id);
            }
        }
        if let Some(id) = self.state.delete_requested_id.take() {
            if self.state.auth.is_busy() {
                tracing::warn!(
                    "[AUTH] ignoring delete while sign-in in progress character_id={}",
                    id
                );
                self.state.status_message =
                    "Finish sign-in in your browser before logging out or deleting characters."
                        .to_string();
            } else {
                self.delete_character(id);
            }
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
                // Assets are a tolerant sub-fetch (never `?`): first-sign-in
                // tokens lack esi-assets.read_assets.v1, and that refusal
                // must not fail the character/skills/wallet refresh above.
                let (assets, assets_needs_reauthorize) =
                    match endpoints::get_assets(&esi, id).await {
                        Ok(items) => {
                            let singleton_ids: Vec<i64> = items
                                .iter()
                                .filter(|a| a.is_singleton)
                                .map(|a| a.item_id)
                                .collect();
                            let mut custom_names = std::collections::HashMap::new();
                            for chunk in singleton_ids.chunks(1000) {
                                match endpoints::get_asset_names(&esi, id, chunk).await {
                                    Ok(names) => {
                                        for entry in names {
                                            let trimmed = entry.name.trim();
                                            if !trimmed.is_empty() && trimmed != "None" {
                                                custom_names
                                                    .insert(entry.item_id, trimmed.to_string());
                                            }
                                        }
                                    }
                                    Err(e) => tracing::warn!(
                                        "[ASSETS] custom-name batch failed character_id={} count={} error={}",
                                        id,
                                        chunk.len(),
                                        e
                                    ),
                                }
                            }
                            tracing::info!(
                                "[ASSETS] assets ready character_id={} items={} custom_names={}",
                                id,
                                items.len(),
                                custom_names.len()
                            );
                            (Ok(AssetsData { items, custom_names }), false)
                        }
                        Err(e) => {
                            let reauthorize = endpoints::needs_reauthorize(&e);
                            tracing::warn!(
                                "[ASSETS] assets fetch failed character_id={} needs_reauthorize={} error={}",
                                id,
                                reauthorize,
                                e
                            );
                            (Err(e.to_string()), reauthorize)
                        }
                    };
                Ok::<_, crate::AppError>((
                    info,
                    SkillsData { skills, queue },
                    wallet,
                    assets,
                    assets_needs_reauthorize,
                ))
            }
            .await;
            match result {
                Ok((info, skills, wallet, assets, assets_needs_reauthorize)) => {
                    // Persist the full refresh so the next launch renders
                    // cached skills/wallet offline (load_cached_state).
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
                        let queue_rows: Vec<repositories::SkillQueueRow> = skills
                            .queue
                            .iter()
                            .map(|q| repositories::SkillQueueRow {
                                character_id: id,
                                queue_position: q.queue_position,
                                skill_id: q.skill_id,
                                finished_level: q.finished_level,
                                start_date: q.start_date.clone(),
                                finish_date: q.finish_date.clone(),
                            })
                            .collect();
                        let _ = repositories::replace_skill_queue(&conn, id, &queue_rows);
                        let skill_rows: Vec<repositories::CharacterSkillRow> = skills
                            .skills
                            .skills
                            .iter()
                            .map(|s| repositories::CharacterSkillRow {
                                character_id: id,
                                skill_id: s.skill_id,
                                active_skill_level: s.active_skill_level,
                                trained_skill_level: s.trained_skill_level,
                                skillpoints_in_skill: s.skillpoints_in_skill,
                            })
                            .collect();
                        let _ = repositories::replace_character_skills(&conn, id, &skill_rows);
                        let _ = repositories::set_wallet_balance(
                            &conn,
                            &repositories::WalletBalanceRow {
                                character_id: id,
                                balance: wallet.balance,
                            },
                        );
                        let journal_rows: Vec<repositories::WalletJournalRow> = wallet
                            .journal
                            .iter()
                            .map(|j| repositories::WalletJournalRow {
                                id: j.id,
                                character_id: id,
                                amount: j.amount,
                                balance: j.balance,
                                date: j.date.clone(),
                                description: j.description.clone(),
                                ref_type: j.ref_type.clone(),
                                first_party_id: j.first_party_id,
                                second_party_id: j.second_party_id,
                            })
                            .collect();
                        let _ = repositories::upsert_journal(&conn, &journal_rows);
                        let transaction_rows: Vec<repositories::WalletTransactionRow> = wallet
                            .transactions
                            .iter()
                            .map(|t| repositories::WalletTransactionRow {
                                transaction_id: t.transaction_id,
                                character_id: id,
                                journal_ref_id: t.journal_ref_id,
                                date: t.date.clone(),
                                type_id: t.type_id,
                                quantity: t.quantity,
                                unit_price: t.unit_price,
                                is_buy: t.is_buy,
                                is_personal: t.is_personal,
                                client_id: t.client_id,
                                location_id: t.location_id,
                            })
                            .collect();
                        let _ = repositories::upsert_transactions(&conn, &transaction_rows);
                        let loyalty_rows: Vec<repositories::LoyaltyRow> = wallet
                            .loyalty
                            .iter()
                            .map(|l| repositories::LoyaltyRow {
                                character_id: id,
                                corporation_id: l.corporation_id,
                                loyalty_points: l.loyalty_points,
                            })
                            .collect();
                        let _ = repositories::replace_loyalty(&conn, id, &loyalty_rows);
                        tracing::info!(
                            "[DB] refresh persisted character_id={} queue={} journal={}",
                            id,
                            queue_rows.len(),
                            journal_rows.len()
                        );
                    }
                    let _ = tx.send(BackendMsg::Refreshed {
                        character_id: id,
                        info: Box::new(info),
                        skills: Box::new(skills),
                        wallet: Box::new(wallet),
                        assets: assets.map(Box::new),
                        assets_needs_reauthorize,
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
        if self.state.demo {
            // Demo mode is fully local: no browser flow and zero
            // verification (JWKS) network calls.
            tracing::warn!("[AUTH] sign-in ignored in demo mode");
            self.state.status_message =
                "Demo mode uses sample data; EVE sign-in is disabled.".to_string();
            return;
        }
        let (Some(backends), Some(runtime)) = (self.backends.as_ref(), self.runtime.as_ref())
        else {
            self.state.status_message = "Sign-in unavailable: live backends not wired.".to_string();
            return;
        };
        // Fail before the browser, not after the callback: never let the
        // user complete an EVE consent flow whose token could not be
        // verified for a local wiring reason known beforehand.
        let Some(jwt_verifier) = backends.jwt_verifier.clone() else {
            tracing::warn!("[AUTH] sign-in blocked: token verification not wired");
            self.state.status_message =
                "Sign-in unavailable: token verification not wired.".to_string();
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
                // Verify the signature before any claims field is read:
                // a rejection aborts via LoginFailed with nothing saved.
                let claims = jwt_verifier.verify(&tokens.access_token).await?;
                let character_id = claims
                    .character_id()
                    .ok_or(crate::AuthError::MalformedToken)?;
                let stored = StoredTokens::from_token_response(character_id, &tokens, &claims);
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

    fn start_stepup_login(&mut self, request: StepUpRequest) {
        if self.state.demo {
            tracing::warn!(
                "[AUTH] step-up ignored in demo mode character_id={}",
                request.character_id
            );
            self.state.status_message =
                "Demo mode uses sample data; EVE sign-in is disabled.".to_string();
            return;
        }
        if self.state.auth.is_busy() {
            tracing::warn!(
                "[AUTH] step-up ignored; sign-in already in progress character_id={}",
                request.character_id
            );
            self.state.status_message =
                "Sign-in already in progress; finish it in your browser first.".to_string();
            return;
        }
        let (Some(backends), Some(runtime)) = (self.backends.as_ref(), self.runtime.as_ref())
        else {
            self.state.status_message =
                "Step-up sign-in unavailable: live backends not wired.".to_string();
            return;
        };
        if !self
            .state
            .characters
            .iter()
            .any(|c| c.character_id == request.character_id)
        {
            tracing::warn!(
                "[AUTH] step-up skipped for unknown character_id={}",
                request.character_id
            );
            self.state.status_message =
                "Step-up sign-in skipped: that character is no longer in Mimir.".to_string();
            return;
        }
        let granted: Vec<String> = match backends.db.lock() {
            Ok(conn) => match repositories::get_token_meta(&conn, request.character_id) {
                Ok(Some(meta)) => oauth::split_scopes(&meta.scopes),
                Ok(None) => {
                    tracing::debug!(
                        "[AUTH] step-up no token_meta row; treating granted scopes as empty character_id={}",
                        request.character_id
                    );
                    Vec::new()
                }
                Err(e) => {
                    tracing::warn!(
                        "[AUTH] step-up token_meta read failed character_id={} error={}",
                        request.character_id,
                        e
                    );
                    Vec::new()
                }
            },
            Err(e) => {
                tracing::warn!(
                    "[AUTH] step-up token_meta lock failed character_id={} error={}",
                    request.character_id,
                    e
                );
                Vec::new()
            }
        };
        let missing = oauth::missing_scopes(&granted, &request.scopes);
        tracing::info!(
            "[AUTH] step-up pre-check character_id={} granted={} requested={} missing={}",
            request.character_id,
            granted.len(),
            request.scopes.join(" "),
            missing.len()
        );
        if missing.is_empty() {
            tracing::info!(
                "[AUTH] step-up skipped; scopes already granted character_id={}",
                request.character_id
            );
            // request_refresh sets its own generic status, so the specific
            // already-granted status must be set after it.
            self.state.request_refresh("stepup-already-granted");
            self.state.status_message =
                "That permission is already granted. Refreshing...".to_string();
            return;
        }
        // Fail before the browser (after the already-granted shortcut
        // above, which needs no step-up tail): never let the user
        // complete an EVE consent flow whose token could not be
        // verified for a local wiring reason known beforehand.
        let Some(jwt_verifier) = backends.jwt_verifier.clone() else {
            tracing::warn!(
                "[AUTH] step-up blocked: token verification not wired character_id={}",
                request.character_id
            );
            self.state.status_message =
                "Step-up sign-in unavailable: token verification not wired.".to_string();
            return;
        };
        let union = oauth::union_scopes(&granted, &request.scopes);
        let scopes_string = oauth::join_scopes(&union);
        tracing::debug!(
            "[AUTH] step-up scope union scopes={} count={}",
            union.join(" "),
            union.len()
        );
        let auth_request = match oauth::create_authorization_request_with_scopes(&scopes_string) {
            Ok(r) => r,
            Err(e) => {
                self.state.auth = AuthState::Error;
                self.state.status_message = format!("Step-up sign-in failed: {e}");
                return;
            }
        };
        tracing::info!("[AUTH] opening browser for EVE SSO step-up (url not logged with state)");
        if let Err(e) = open::that(auth_request.authorize_url.as_str()) {
            self.state.auth = AuthState::Error;
            self.state.status_message = format!("Could not open browser: {e}");
            return;
        }
        self.state.auth = AuthState::AwaitingCallback;
        let token_store = backends.token_store.clone();
        let db = backends.db.clone();
        let tx = self.tx.clone();
        let expected_character_id = request.character_id;
        // The callback must prove the returned token retains every
        // previously granted scope plus the requested ones, not just
        // the newly requested delta.
        let expected_scopes = union;
        runtime.spawn(async move {
            let outcome = async {
                let params = CallbackServer::new().wait_for_callback().await?;
                let code = params.into_result(&auth_request.state)?;
                let tokens = oauth::exchange_code(&code, &auth_request.pkce.verifier).await?;
                // Verify the signature before the character/scope checks:
                // a rejection aborts via LoginFailed with nothing saved.
                // Those checks keep their logic, now on verified claims.
                let claims = jwt_verifier.verify(&tokens.access_token).await?;
                let character_id =
                    oauth::validate_expected_character(&claims, expected_character_id)?;
                let still_missing = oauth::missing_scopes(&claims.scp, &expected_scopes);
                if !still_missing.is_empty() {
                    tracing::warn!(
                        "[AUTH] step-up returned without granted or requested scopes character_id={} missing={}",
                        character_id,
                        still_missing.join(" ")
                    );
                    return Err(crate::AppError::from(crate::AuthError::Message(
                        "EVE did not grant the requested scope(s); nothing was saved"
                            .to_string(),
                    )));
                }
                // The character may have been removed during the browser
                // wait (UI and drain guards block the known paths; this
                // save-time re-check is the backstop so deleted characters
                // never regain stored tokens).
                {
                    let conn = db.lock().map_err(|_| {
                        crate::AppError::from(crate::AuthError::Message(
                            "could not verify the character still exists; nothing was saved"
                                .to_string(),
                        ))
                    })?;
                    if repositories::get_character(&conn, character_id)?.is_none() {
                        tracing::warn!(
                            "[AUTH] discarding step-up tokens for removed character_id={} (nothing saved)",
                            character_id
                        );
                        return Err(crate::AppError::from(crate::AuthError::Message(
                            "that character was removed during sign-in; nothing was saved"
                                .to_string(),
                        )));
                    }
                }
                let stored = StoredTokens::from_token_response(character_id, &tokens, &claims);
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
                Ok::<_, crate::AppError>(character_id)
            }
            .await;
            match outcome {
                Ok(character_id) => {
                    let _ = tx.send(BackendMsg::StepUpLoggedIn { character_id });
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
                egui::Key::Num6,
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
        // Persist startup-view choice only when it actually changed since
        // the last write (settings view edits it); no per-frame DB reads.
        if self.persisted_startup_view.as_deref() != Some(self.state.startup_view.label()) {
            if let Some(backends) = self.backends.as_ref() {
                if let Ok(conn) = backends.db.lock() {
                    if repositories::set_setting(
                        &conn,
                        "startup_view",
                        self.state.startup_view.label(),
                    )
                    .is_ok()
                    {
                        self.persisted_startup_view =
                            Some(self.state.startup_view.label().to_string());
                    }
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
            ui.heading("Views (keys 1-6)");
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
                View::Assets => ui::assets::show(ui, &mut self.state, &self.resolver),
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
                ui.label("Keys: 1-6 views, Ctrl+R refresh, / search, PgUp/PgDn character");
            });
        });
    }
}
