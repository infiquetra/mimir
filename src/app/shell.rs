//! egui application shell: character rail, view switcher, top bar,
//! keyboard-first navigation, and per-second repaints for countdowns.

use std::sync::mpsc::{Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use super::state::{
    ship_display_name, summary_location_name, AppState, AssetsData, AuthState, BlueprintsData,
    CharacterDetailData, CharacterOrdersData, CharacterSummary, ExplorationData,
    FittingWriteInFlight, FittingWriteKind, FittingWriteOutcome, FittingWriteRequest, FittingsData,
    IndustryData, IndustryJobsData, LoadState, MarketData, MarketSelection, PlanetSelection,
    PlanetaryData, PublicOrdersData, SectionError, SectionResult, SelectedColonyDetail, SkillsData,
    StepUpRequest, View, WalletData,
};
use crate::auth::callback_server::CallbackServer;
use crate::auth::jwt_verify::JwtVerifier;
use crate::auth::oauth;
use crate::auth::token_store::{StoredTokens, TokenStore};
use crate::config::EveConfig;
use crate::demo::data::DemoBundle;
use crate::esi::endpoints::{self, WriteFailureClass};
use crate::esi::models::{
    CharacterFitting, CharacterPublicInfo, CharacterSkills, LoyaltyPointItem, PlanetColony,
    PlanetColonyDetail, Skill, SkillQueueItem, UniverseName, WalletJournalItem,
    WalletTransactionItem,
};
use crate::names::exploration_ref::ExplorationRef;
use crate::names::fitting_types::FittingTypes;
use crate::names::resolver::{
    is_displayable_name, is_structure_id, structure_lookup_batch, NameResolver,
};
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
        detail: Box<CharacterDetailData>,
        industry: Box<IndustryData>,
        planetary_colonies: SectionResult<Vec<PlanetColony>>,
        fittings_list: SectionResult<Vec<CharacterFitting>>,
    },
    RefreshFailed {
        character_id: i64,
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
    StructuresResolved {
        character_id: i64,
        names: Vec<UniverseName>,
        denied: Vec<i64>,
    },
    MarketFetched {
        generation: u64,
        data: Box<MarketData>,
    },
    PlanetaryDetailFetched {
        generation: u64,
        selection: PlanetSelection,
        result: SectionResult<PlanetColonyDetail>,
    },
    MarketLookupDone {
        generation: u64,
        query: String,
        result: Result<Vec<UniverseName>, String>,
    },
    FittingWriteDone {
        character_id: i64,
        kind: FittingWriteKind,
        outcome: FittingWriteOutcome,
    },
}

/// Fixed lookup outcome lines (design section 6.1): the submitted text
/// is never echoed inside either sentence, and lookup error detail
/// stays in a `[MARKET]` log line, never on screen.
const MARKET_LOOKUP_NOT_FOUND: &str =
    "No item with that exact name was found. Check the spelling, or pick an item you hold below.";
const MARKET_LOOKUP_FAILED: &str = "Item name lookup failed. Check the connection and try again.";

pub struct MimirApp {
    pub state: AppState,
    pub sde: Sde,
    pub fitting_types: Option<Arc<FittingTypes>>,
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

/// Dashboard/Characters summary strings from a detail bundle (design
/// section 7): resolved names only via `resolver.cached()`, `None` when a
/// section failed or its name is unresolved yet — never the Unknown words
/// and never a raw numeric ID.
fn detail_summary_names(
    detail: &CharacterDetailData,
    resolver: &NameResolver,
) -> (Option<String>, Option<String>) {
    let location_name = match &detail.location {
        Ok(location) => summary_location_name(
            location
                .docked_location_id()
                .and_then(|id| resolver.cached(id)),
            resolver.cached(location.solar_system_id),
        ),
        Err(_) => None,
    };
    let ship_name = match &detail.ship {
        Ok(ship) => ship_display_name(&ship.ship_name, resolver.cached(ship.ship_type_id)),
        Err(_) => None,
    };
    (location_name, ship_name)
}

/// Design section 8.2 identity check: a market bundle applies only
/// when generation, selected type, region, and active character all
/// still match the stamped selection.
fn market_result_matches(state: &AppState, generation: u64, selection: &MarketSelection) -> bool {
    generation == state.market_generation
        && Some(selection.type_id) == state.market_selected_type_id
        && selection.region_id == state.market_region_id
        && selection.character_id == state.active_character_id
}

/// PI design section 7.3 identity check: a colony detail result
/// applies only when generation, selected planet, and active
/// character all still match the stamped selection, so a detail
/// fetched for a previous planet or character can never display.
fn planetary_result_matches(
    state: &AppState,
    generation: u64,
    selection: &PlanetSelection,
) -> bool {
    generation == state.planetary_generation
        && Some(selection.planet_id) == state.planetary_selected_planet_id
        && Some(selection.character_id) == state.active_character_id
}

/// Fittings design section 7.2 selection merge: a successful list
/// is the only evidence that may clear the selection — it is stale
/// only when it names a fitting and the fresh `Ok` list no longer
/// carries that `fitting_id`. A failed list proves nothing, so the
/// selection survives a section error untouched (planetary rule).
fn fittings_selection_is_stale(
    selected: Option<i64>,
    fittings_list: &SectionResult<Vec<CharacterFitting>>,
) -> bool {
    matches!((fittings_list, selected), (Ok(list), Some(id)) if !list.iter().any(|f| f.fitting_id == id))
}

/// Fittings design section 7.3 observed-reality arm: the fittings
/// section already returned a scope refusal this session while the
/// step-up request asks for the fittings scope, so stored token
/// metadata claiming the grant is stale and the already-granted
/// shortcut must not be taken (it would loop the panel's own
/// Re-authorize button without ever opening the browser).
fn fittings_stepup_observed(request_scopes: &[String], state: &AppState) -> bool {
    request_scopes
        .iter()
        .any(|scope| EveConfig::FITTINGS_SCOPES.contains(&scope.as_str()))
        && matches!(&state.fittings, LoadState::Ready(d) if d.needs_fittings_stepup())
}

/// Structure-names design section 5.4 observed-reality arm: a
/// name-resolution pass already found user-visible structure
/// locations lacking the structures scope while the step-up
/// request asks for that scope, so stored token metadata
/// claiming the grant is stale and the already-granted
/// shortcut must not be taken (it would loop the banner's own
/// Re-authorize button without ever opening the browser).
fn structures_stepup_observed(request_scopes: &[String], state: &AppState) -> bool {
    request_scopes
        .iter()
        .any(|scope| EveConfig::STRUCTURE_SCOPES.contains(&scope.as_str()))
        && state.structures_needs_reauthorize
}

/// Fittings-write design section 3.4 observed-reality arm: a
/// write already observed a live 401/403 this session (which
/// set the write flag at landing) while the step-up request
/// asks for the write scope, so stored token metadata
/// claiming the grant is stale and the already-granted
/// shortcut must not be taken.
fn fittings_write_stepup_observed(request_scopes: &[String], state: &AppState) -> bool {
    request_scopes
        .iter()
        .any(|scope| EveConfig::FITTINGS_WRITE_SCOPES.contains(&scope.as_str()))
        && state.fittings_write_needs_reauthorize
}

/// Decide what applying one `FittingWriteDone` mutates, before
/// the landing handler mutates anything (write design section
/// 8). Always clears the flight; a character mismatch drops
/// the result whole (no status, no refresh); a matching
/// landing outside `Saved`/`Deleted`/`Unknown`/`AlreadyGone`
/// queues no refresh because the server state provably did
/// not change.
struct FittingWriteLanding {
    stale: bool,
    status: Option<String>,
    queue_refresh: bool,
    record_pending: Option<(i64, i64)>,
    set_reauthorize: bool,
}

fn decide_fitting_write_landing(
    state: &AppState,
    character_id: i64,
    kind: FittingWriteKind,
    outcome: &FittingWriteOutcome,
) -> FittingWriteLanding {
    if Some(character_id) != state.active_character_id {
        return FittingWriteLanding {
            stale: true,
            status: None,
            queue_refresh: false,
            record_pending: None,
            set_reauthorize: false,
        };
    }
    match outcome {
        FittingWriteOutcome::Saved { fitting_id } => FittingWriteLanding {
            stale: false,
            status: Some("Saved the fitting to EVE. Refreshing your fitting list...".to_string()),
            queue_refresh: true,
            record_pending: Some((character_id, *fitting_id)),
            set_reauthorize: false,
        },
        FittingWriteOutcome::Deleted { .. } => FittingWriteLanding {
            stale: false,
            status: Some(
                "Deleted the fitting from EVE. Refreshing your fitting list...".to_string(),
            ),
            queue_refresh: true,
            record_pending: None,
            set_reauthorize: false,
        },
        FittingWriteOutcome::Failed {
            class,
            needs_reauthorize,
        } => FittingWriteLanding {
            stale: false,
            status: Some(fitting_write_status_message(
                kind,
                *class,
                *needs_reauthorize,
            )),
            queue_refresh: matches!(
                class,
                WriteFailureClass::Unknown | WriteFailureClass::AlreadyGone
            ),
            record_pending: None,
            set_reauthorize: *needs_reauthorize,
        },
    }
}

/// Fixed status wording for a failed write (write design
/// section 9.2). No fitting name, no numeric id, no server
/// error text ever appears here; the only number is the
/// rate-limit reset duration.
fn fitting_write_status_message(
    kind: FittingWriteKind,
    class: WriteFailureClass,
    needs_reauthorize: bool,
) -> String {
    if needs_reauthorize {
        return match kind {
            FittingWriteKind::Save => "EVE refused the save: this character has not granted fitting changes. Re-authorize in the Fittings view.".to_string(),
            FittingWriteKind::Delete => "EVE refused the delete: this character has not granted fitting changes. Re-authorize in the Fittings view.".to_string(),
        };
    }
    match class {
        WriteFailureClass::AlreadyGone => {
            "That fitting is already gone from EVE. Refreshing your fitting list...".to_string()
        }
        WriteFailureClass::RateLimited { reset_secs } => format!(
            "EVE is rate-limiting requests. Nothing was {}; wait {reset_secs} seconds and try again.",
            match kind {
                FittingWriteKind::Save => "saved",
                FittingWriteKind::Delete => "deleted",
            }
        ),
        WriteFailureClass::Unknown => match kind {
            FittingWriteKind::Save => "The save may or may not have reached EVE. Check the refreshed fitting list before saving again, so you do not create a duplicate.".to_string(),
            FittingWriteKind::Delete => "The delete may or may not have reached EVE. Check the refreshed fitting list; if the fitting is still there, you can delete it again.".to_string(),
        },
        WriteFailureClass::NotSent => {
            "Nothing was sent to EVE. Check the connection and try again.".to_string()
        }
        WriteFailureClass::Definitive => match kind {
            FittingWriteKind::Save => {
                "EVE refused the save and nothing was saved. See the log for details.".to_string()
            }
            FittingWriteKind::Delete => {
                "EVE refused the delete and nothing was deleted. See the log for details.".to_string()
            }
        },
    }
}

/// Write design section 8.1: apply a just-saved fitting id to
/// the selection when the first judged refresh names it. Only
/// an `Ok` list for the stamped character judges the pending
/// value; an `Err` list proves nothing (the pending value
/// survives), and a refresh for another character is ignored.
/// Returns the pending value to keep and the fitting id to
/// select.
fn apply_pending_fitting_selection(
    pending: Option<(i64, i64)>,
    applied_character_id: i64,
    fittings_list: &SectionResult<Vec<CharacterFitting>>,
) -> (Option<(i64, i64)>, Option<i64>) {
    let Some((character_id, fitting_id)) = pending else {
        return (None, None);
    };
    if character_id != applied_character_id {
        return (Some((character_id, fitting_id)), None);
    }
    let Ok(list) = fittings_list else {
        return (Some((character_id, fitting_id)), None);
    };
    if list.iter().any(|f| f.fitting_id == fitting_id) {
        (None, Some(fitting_id))
    } else {
        (None, None)
    }
}

/// Design section 8.3 freshness check: a lookup answer applies only
/// when its generation is current and its text is still what the
/// (trimmed) search box holds.
fn market_lookup_is_current(state: &AppState, generation: u64, query: &str) -> bool {
    generation == state.market_generation && query == state.market_search.trim()
}

/// Rail key hint per view (exploration design section 6.2): indices
/// 0-8 keep digits 1-9, Settings (index 9) keeps 0, and the eleventh
/// view takes the mnemonic letter E. Deriving the digit from
/// `(idx + 1) % 10` would print "1" for Exploration, colliding with
/// Dashboard, so the hint comes from the view itself.
fn view_key_hint(view: View) -> &'static str {
    match view {
        View::Dashboard => "1",
        View::Characters => "2",
        View::Skills => "3",
        View::Wallet => "4",
        View::Assets => "5",
        View::Market => "6",
        View::Industry => "7",
        View::Planets => "8",
        View::Fittings => "9",
        View::Settings => "0",
        View::Exploration => "E",
    }
}

/// Restore a persisted `startup_view` label (design section 6.4): the
/// saved string is matched against `View::label()` values, so the
/// appended "Exploration" label can never reinterpret a label saved
/// before it existed; an unknown label falls back to Dashboard.
fn view_for_startup_label(saved: &str) -> View {
    View::ALL
        .iter()
        .find(|v| v.label() == saved)
        .copied()
        .unwrap_or(View::Dashboard)
}

/// One-time startup load of the bundled fitting-types catalogue
/// (fittings-import design section 10): success stores the validated
/// catalogue and logs its count once; any failure logs a `[FITTING]`
/// warning and stores `None`, so the import panel shows its fixed
/// catalogue-unavailable sentence instead of treating an empty
/// catalogue as valid (the Exploration rule, not the `Sde` fallback).
fn fitting_types_load(result: crate::error::AppResult<FittingTypes>) -> Option<Arc<FittingTypes>> {
    match result {
        Ok(catalogue) => {
            tracing::info!(
                "[FITTING] bundled fitting types loaded types={}",
                catalogue.type_count()
            );
            Some(Arc::new(catalogue))
        }
        Err(e) => {
            tracing::warn!("[FITTING] bundled fitting types failed to load: {}", e);
            None
        }
    }
}

/// One-time startup load of the bundled Exploration reference
/// (design sections 5.2 and 9): success stores the validated
/// catalogue and logs its counts once; any failure becomes the
/// whole-view error state with the fixed section 8.4 sentence.
/// Unlike the Sde load there is no empty-default fallback: an empty
/// reference presented as valid data is exactly the failure this
/// slice forbids. Demo and live modes both take this path, so demo
/// routing stays zero-network and the catalogue is identical.
fn exploration_load_state(
    result: crate::error::AppResult<ExplorationRef>,
) -> LoadState<ExplorationData> {
    match result {
        Ok(reference) => {
            tracing::info!(
                "[EXPLORE] bundled exploration reference loaded sde_build={} types={} systems={} effects={} statics={}",
                reference.manifest.sde_build,
                reference.types.len(),
                reference.systems.len(),
                reference.effects.len(),
                reference.statics.len()
            );
            LoadState::Ready(ExplorationData {
                reference: Arc::new(reference),
            })
        }
        Err(e) => {
            tracing::warn!(
                "[EXPLORE] bundled exploration reference failed to load: {}",
                e
            );
            LoadState::Error(crate::ui::exploration::EXPLORATION_ERROR.to_string())
        }
    }
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
        let fitting_types = fitting_types_load(FittingTypes::load_bundled());
        let (tx, rx) = std::sync::mpsc::channel();
        let mut state = AppState::new(demo);
        // Bundled offline reference, loaded exactly once (design
        // section 9): identical in demo and live modes, never
        // refetched, and independent of characters and network.
        state.exploration = exploration_load_state(ExplorationRef::load_bundled());
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
                    let view = view_for_startup_label(&saved);
                    tracing::info!("[STARTUP] applying saved startup view {}", saved);
                    state.startup_view = view;
                    state.view = view;
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
            fitting_types,
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
    /// Structure-class IDs are routed to the bounded authenticated pass
    /// below: `/universe/names/` cannot resolve them.
    fn schedule_name_resolution(&mut self) {
        if self.state.demo {
            return;
        }
        let mut ids: Vec<i64> = Vec::new();
        let mut structure_ids: Vec<i64> = Vec::new();
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
                if is_structure_id(tx.location_id) {
                    structure_ids.push(tx.location_id);
                } else {
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
                if is_structure_id(item.location_id) {
                    structure_ids.push(item.location_id);
                } else {
                    ids.push(item.location_id);
                }
            }
        }
        if let LoadState::Ready(bundle) = &self.state.character_details {
            // Detail IDs (design section 8): implant integers are type IDs;
            // location-class IDs pass the structure guard. Instance IDs
            // (ship_item_id, jump_clone_id) are never resolved or shown.
            if let Ok(implants) = &bundle.implants {
                ids.extend(implants.iter().copied());
            }
            if let Ok(clones) = &bundle.clones {
                for clone in &clones.jump_clones {
                    if is_structure_id(clone.location_id) {
                        structure_ids.push(clone.location_id);
                    } else {
                        ids.push(clone.location_id);
                    }
                    ids.extend(clone.implants.iter().copied());
                }
                if let Some(home) = &clones.home_location {
                    if is_structure_id(home.location_id) {
                        structure_ids.push(home.location_id);
                    } else {
                        ids.push(home.location_id);
                    }
                }
            }
            if let Ok(standings) = &bundle.standings {
                for standing in standings {
                    ids.push(standing.from_id);
                }
            }
            if let Ok(location) = &bundle.location {
                ids.push(location.solar_system_id);
                if let Some(docked_id) = location.docked_location_id() {
                    if is_structure_id(docked_id) {
                        structure_ids.push(docked_id);
                    } else {
                        ids.push(docked_id);
                    }
                }
            }
            if let Ok(ship) = &bundle.ship {
                ids.push(ship.ship_type_id);
            }
        }
        // Market IDs (design section 8.4): the selected type, displayed
        // top-N public-order locations, and character-order types and
        // locations — every location behind the structure guard. Hub
        // region IDs, order IDs, region/system IDs on rows are never
        // scheduled (constants/fallback words cover regions).
        if let Some(type_id) = self.state.market_selected_type_id {
            ids.push(type_id);
        }
        if let LoadState::Ready(bundle) = &self.state.market {
            if let Ok(public) = &bundle.public_orders {
                let summary = ui::market::summarize_orders(&public.orders);
                for order in summary.top_sells.iter().chain(summary.top_buys.iter()) {
                    if is_structure_id(order.location_id) {
                        structure_ids.push(order.location_id);
                    } else {
                        ids.push(order.location_id);
                    }
                }
            }
            if let Ok(own) = &bundle.character_orders {
                for order in &own.orders {
                    ids.push(order.type_id);
                    if is_structure_id(order.location_id) {
                        structure_ids.push(order.location_id);
                    } else {
                        ids.push(order.location_id);
                    }
                }
            }
        }
        // Industry IDs (design section 6.4): only rendered type IDs and
        // structure-guarded facility/location IDs. Job, blueprint-instance,
        // installer, completer, and output IDs are never scheduled.
        if let LoadState::Ready(bundle) = &self.state.industry {
            if let Ok(jobs_data) = &bundle.jobs {
                for job in &jobs_data.jobs {
                    ids.push(job.blueprint_type_id);
                    ids.extend(job.product_type_id);
                    if is_structure_id(job.facility_id) {
                        structure_ids.push(job.facility_id);
                    } else {
                        ids.push(job.facility_id);
                    }
                }
            }
            if let Ok(blueprints_data) = &bundle.blueprints {
                for blueprint in &blueprints_data.blueprints {
                    ids.push(blueprint.type_id);
                    if is_structure_id(blueprint.location_id) {
                        structure_ids.push(blueprint.location_id);
                    } else {
                        ids.push(blueprint.location_id);
                    }
                }
            }
        }
        // Planetary IDs (PI design section 10): colony solar-system
        // IDs behind the structure guard (location path), plus pin,
        // extractor-product, and stored-item type IDs (item path).
        // Planet/pin instance IDs, schematic IDs, anything inside
        // raw links/routes, and the planet-type word are never
        // scheduled.
        if let LoadState::Ready(bundle) = &self.state.planetary {
            if let Ok(colonies) = &bundle.colonies {
                for colony in colonies {
                    if is_structure_id(colony.solar_system_id) {
                        structure_ids.push(colony.solar_system_id);
                    } else {
                        ids.push(colony.solar_system_id);
                    }
                }
            }
            if let Some(detail) = &bundle.detail {
                if let Ok(detail) = &detail.result {
                    for pin in &detail.pins {
                        ids.push(pin.type_id);
                        if let Some(extractor) = &pin.extractor_details {
                            ids.extend(extractor.product_type_id);
                        }
                        for content in &pin.contents {
                            ids.push(content.type_id);
                        }
                    }
                }
            }
        }
        // Fittings IDs (fittings design section 10): ship and item
        // type IDs take the item-name path (no structure guard;
        // ship/item types are not locations). Fitting IDs (instance
        // identity), flag words, and quantities are never scheduled.
        if let LoadState::Ready(bundle) = &self.state.fittings {
            if let Ok(fittings) = &bundle.fittings {
                for fitting in fittings {
                    ids.push(fitting.ship_type_id);
                    for item in &fitting.items {
                        ids.push(item.type_id);
                    }
                }
            }
        }
        let missing = self.resolver.missing(&ids);
        // Structure-class IDs take the bounded authenticated pass
        // below; the batch only ever sees non-structure ids.
        let structure_batch = structure_lookup_batch(&self.resolver.missing(&structure_ids));
        if missing.is_empty() && structure_batch.is_empty() {
            return;
        }
        let (Some(backends), Some(runtime)) = (self.backends.as_ref(), self.runtime.as_ref())
        else {
            return;
        };
        if !missing.is_empty() {
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
        if structure_batch.is_empty() {
            return;
        }
        // Bounded authenticated structure pass (design sections 5.2,
        // 7, 10.2), independent of the batch spawn above: sequential
        // per-ID GETs under the active character's token, capped per
        // pass, with the structures scope pre-checked from stored
        // token metadata before any request.
        if let Some(character_id) = self.state.active_character_id {
            // No active character means no token: skip without
            // touching the flag (design section 4.2). When one is
            // active, grant metadata decides whether any request is
            // made at all (design section 5.2).
            let granted: Vec<String> = match backends.db.lock() {
                Ok(conn) => match repositories::get_token_meta(&conn, character_id) {
                    Ok(Some(meta)) => oauth::split_scopes(&meta.scopes),
                    Ok(None) => {
                        tracing::debug!(
                            "[ESI] structure pre-check no token_meta row; treating granted scopes as empty character_id={}",
                            character_id
                        );
                        Vec::new()
                    }
                    Err(e) => {
                        tracing::warn!(
                            "[ESI] structure pre-check token_meta read failed character_id={} error={}",
                            character_id,
                            e
                        );
                        Vec::new()
                    }
                },
                Err(e) => {
                    tracing::warn!(
                        "[ESI] structure pre-check token_meta lock failed character_id={} error={}",
                        character_id,
                        e
                    );
                    Vec::new()
                }
            };
            let requested: Vec<String> = EveConfig::STRUCTURE_SCOPES
                .iter()
                .map(|scope| scope.to_string())
                .collect();
            if !oauth::missing_scopes(&granted, &requested).is_empty() {
                // Scope absent: zero requests, every id stays
                // unpinned, and the Assets banner offers the step-up.
                self.state.structures_needs_reauthorize = true;
                tracing::info!(
                    "[ESI] structure name lookup skipped: structures scope not granted character_id={} pending={}",
                    character_id,
                    structure_batch.len()
                );
            } else {
                // Scope present: the pass proves the grant and the
                // banner clears; bounded lookups run below.
                self.state.structures_needs_reauthorize = false;
                let esi = backends.esi.clone();
                let tx = self.tx.clone();
                tracing::info!(
                    "[ESI] resolving {} structure names character_id={}",
                    structure_batch.len(),
                    character_id
                );
                runtime.spawn(async move {
                    let mut names: Vec<UniverseName> = Vec::new();
                    let mut denied: Vec<i64> = Vec::new();
                    for structure_id in structure_batch {
                        match endpoints::get_structure_for_character(
                            &esi,
                            structure_id,
                            character_id,
                        )
                        .await
                        {
                            Ok(info) if is_displayable_name(&info.name) => {
                                names.push(UniverseName {
                                    id: structure_id,
                                    name: info.name,
                                    category: "structure".to_string(),
                                });
                            }
                            Ok(_) => {
                                // ESI answered with no displayable name;
                                // pin the id (design section 6.3).
                                denied.push(structure_id);
                            }
                            Err(e)
                                if matches!(
                                    &e,
                                    crate::error::AppError::Esi(
                                        crate::error::EsiError::Reauthorize
                                            | crate::error::EsiError::NotFound(_)
                                    )
                                ) =>
                            {
                                // 403 in a scope-present pass is an ACL
                                // denial for this character, and 404 is a
                                // destroyed structure or a parent item id
                                // above the structure threshold: pin the
                                // id and continue so one dead id never
                                // head-of-line blocks larger ids.
                                denied.push(structure_id);
                            }
                            Err(e) => {
                                // 401 and transport-class failures abort
                                // the rest of the pass, leaving the
                                // remainder unpinned for the next
                                // scheduled pass.
                                tracing::warn!("[ESI] structure name lookup aborted: {}", e);
                                break;
                            }
                        }
                    }
                    if !names.is_empty() || !denied.is_empty() {
                        let _ = tx.send(BackendMsg::StructuresResolved {
                            character_id,
                            names,
                            denied,
                        });
                    }
                });
            }
        }
    }

    /// Landing tail shared by the batch and structure name passes
    /// (design section 10.3): ingest the landed names, upgrade the
    /// active character's summary strings, and persist the rows.
    /// Never creates a summary entry that does not already exist.
    fn apply_landed_names(&mut self, names: &[UniverseName]) {
        self.resolver.extend_from_universe_names(names);
        // Summary strings were frozen at Refreshed time; upgrade
        // the active character's location/ship now that names
        // landed (design section 6.5). Only the active bundle
        // is in memory; never create a summary entry here.
        if let Some(active_id) = self.state.active_character_id {
            if let LoadState::Ready(bundle) = &self.state.character_details {
                let (location_name, ship_name) = detail_summary_names(bundle, &self.resolver);
                if let Some(summary) = self.state.summaries.get_mut(&active_id) {
                    summary.location_name = location_name;
                    summary.ship_name = ship_name;
                    tracing::debug!(
                        "[ESI] recomputed location/ship summary after name resolution character_id={}",
                        active_id
                    );
                }
            }
        }
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
                    detail,
                    industry,
                    planetary_colonies,
                    fittings_list,
                } => {
                    tracing::info!("[ESI] refresh complete character_id={}", character_id);
                    // A refresh landing after its character was removed
                    // must not resurrect that character's summary (the
                    // dashboard combined total sums every summary value).
                    // Summaries for still-present inactive characters are
                    // keyed and safe to keep.
                    if self
                        .state
                        .characters
                        .iter()
                        .any(|c| c.character_id == character_id)
                    {
                        let training = skills.queue.first();
                        let (location_name, ship_name) =
                            detail_summary_names(&detail, &self.resolver);
                        self.state.summaries.insert(
                            character_id,
                            CharacterSummary {
                                balance: Some(wallet.balance),
                                training_skill_name: training
                                    .map(|t| self.sde.skill_name(t.skill_id)),
                                training_finish_date: training.and_then(|t| t.finish_date.clone()),
                                queue_len: Some(skills.queue.len()),
                                total_sp: Some(skills.skills.total_sp),
                                location_name,
                                ship_name,
                            },
                        );
                    } else {
                        tracing::warn!(
                            "[CHAR] ignoring summary for removed character_id={}",
                            character_id
                        );
                    }
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
                        self.state.character_details = LoadState::Ready(*detail);
                        self.state.industry = LoadState::Ready(*industry);
                        // Planetary merge (PI design section 7.2): the
                        // selection survives unless a successful list
                        // proves its planet is gone (a failed list
                        // proves nothing); a stamped detail is kept
                        // only for this character and a surviving
                        // selection; a surviving selection re-queues
                        // its one identity-guarded detail fetch.
                        let mut selection_survives =
                            self.state.planetary_selected_planet_id.is_some();
                        if let (Ok(colonies), Some(selected)) =
                            (&planetary_colonies, self.state.planetary_selected_planet_id)
                        {
                            if !colonies.iter().any(|c| c.planet_id == selected) {
                                tracing::debug!(
                                    "[PI] clearing selection no longer in refreshed colonies character_id={}",
                                    character_id
                                );
                                self.state.planetary_selected_planet_id = None;
                                self.state.planetary_generation =
                                    self.state.planetary_generation.wrapping_add(1);
                                selection_survives = false;
                            }
                        }
                        let preserved_detail = if selection_survives {
                            self.state
                                .planetary
                                .as_ready()
                                .and_then(|bundle| bundle.detail.clone())
                                .filter(|d| d.selection.character_id == character_id)
                        } else {
                            None
                        };
                        self.state.planetary = LoadState::Ready(PlanetaryData {
                            colonies: planetary_colonies,
                            detail: preserved_detail,
                        });
                        if selection_survives {
                            self.state.planetary_detail_fetch_requested = true;
                        }
                        // Fittings merge (fittings design section 7.2):
                        // the selection survives unless a successful
                        // list proves its fitting is gone (a failed
                        // list proves nothing). No detail is preserved
                        // and no follow-up fetch is queued — selecting
                        // a fitting never fetches (the list carries
                        // its items).
                        if fittings_selection_is_stale(
                            self.state.fittings_selected_fitting_id,
                            &fittings_list,
                        ) {
                            tracing::debug!(
                                "[FITTING] clearing selection no longer in refreshed fittings character_id={}",
                                character_id
                            );
                            self.state.fittings_selected_fitting_id = None;
                        }
                        // A just-saved fitting is selected only if
                        // this first judged refresh names it (write
                        // design section 8.1). A failed list leaves
                        // the pending value unjudged.
                        let (pending, select) = apply_pending_fitting_selection(
                            self.state.fittings_pending_selection,
                            character_id,
                            &fittings_list,
                        );
                        self.state.fittings_pending_selection = pending;
                        if let Some(fitting_id) = select {
                            tracing::debug!(
                                "[FITTING] selecting just-saved fitting character_id={}",
                                character_id
                            );
                            self.state.fittings_selected_fitting_id = Some(fitting_id);
                        }
                        self.state.fittings = LoadState::Ready(FittingsData {
                            fittings: fittings_list,
                        });
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
                    self.apply_landed_names(&names);
                }
                BackendMsg::StructuresResolved {
                    character_id,
                    names,
                    denied,
                } => {
                    // Identity guard (design section 10.3): a late
                    // result for a switched-away character drops
                    // whole — neither the cache nor the pin set may
                    // learn under another character's token.
                    if Some(character_id) != self.state.active_character_id {
                        tracing::warn!(
                            "[ESI] dropping structure names for inactive character_id={}",
                            character_id
                        );
                    } else {
                        tracing::info!(
                            "[ESI] resolved {} structure names ({} denied) character_id={}",
                            names.len(),
                            denied.len(),
                            character_id
                        );
                        self.resolver.mark_unresolved(&denied);
                        self.apply_landed_names(&names);
                    }
                }
                BackendMsg::RefreshFailed {
                    character_id,
                    message,
                } => {
                    if self.state.active_character_id != Some(character_id) {
                        // A failure landing after a character switch must
                        // not overwrite the new active character's states,
                        // offline flag, or status with the old one's error.
                        tracing::warn!(
                            "[ESI] ignoring refresh failure for inactive character_id={}",
                            character_id
                        );
                    } else {
                        tracing::warn!("[ESI] refresh failed: {}", message);
                        self.state.offline = true;
                        self.state.status_message = format!("Refresh failed: {message}");
                        if !self.state.skills.is_ready() {
                            self.state.skills = LoadState::Error(message.clone());
                        }
                        if !self.state.wallet.is_ready() {
                            self.state.wallet = LoadState::Error(message.clone());
                        }
                        if !self.state.character_details.is_ready() {
                            self.state.character_details = LoadState::Error(message.clone());
                        }
                        if !self.state.industry.is_ready() {
                            // Industry's whole-view error panel renders this
                            // string verbatim, and refresh error text can
                            // carry server-controlled body text (including
                            // numeric IDs): fixed wording here, full
                            // detail stays in the [ESI] warn above.
                            self.state.industry =
                                LoadState::Error("character refresh request failed".to_string());
                        }
                        if !self.state.planetary.is_ready() {
                            // Same fixed wording for the Planets
                            // whole-view panel (PI design section 7.4);
                            // the raw refresh message is never installed
                            // into planetary state.
                            self.state.planetary =
                                LoadState::Error("character refresh request failed".to_string());
                        }
                        if !self.state.fittings.is_ready() {
                            // Same fixed wording for the Fittings
                            // whole-view panel (fittings design
                            // section 7.4); the raw refresh message is
                            // never installed into fittings state.
                            self.state.fittings =
                                LoadState::Error("character refresh request failed".to_string());
                        }
                        if !self.state.assets.is_ready() {
                            self.state.assets = LoadState::Error(message);
                        }
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
                        // Re-arm pinned structure ids: the post-stepup
                        // refresh's scheduling tail re-offers them under
                        // the new grant, and the structures banner clears
                        // only when that pass's pre-check sees the scope.
                        self.resolver.forget_unresolved_structures();
                        // request_refresh sets its own generic status, so the
                        // specific step-up status must be set after it.
                        self.state.request_refresh("post-stepup");
                        // Design section 8.5: refill the market bundle
                        // under the newly granted scopes; clear nothing
                        // here — the re-authorize panel clears only when
                        // a later fetch returns character-orders Ok.
                        if self.state.market_selected_type_id.is_some() {
                            tracing::debug!("[MARKET] market refetch queued after step-up");
                            self.state.market_fetch_requested = true;
                        }
                        // PI design section 7.5: post-stepup refresh
                        // refills the colonies list; queue the gated
                        // detail refetch too. Clear nothing — the panel
                        // clears only when a later fetch returns Ok.
                        if self.state.planetary_selected_planet_id.is_some() {
                            tracing::debug!("[PI] colony detail refetch queued after step-up");
                            self.state.planetary_detail_fetch_requested = true;
                        }
                        // Fittings design section 7.3: no fittings
                        // flag here — the post-stepup main refresh
                        // above already refills the fittings list,
                        // and the panel clears only when a later
                        // refresh returns it Ok.
                        // Write design section 3.2: a step-up that
                        // just completed for the active character
                        // clears the write flag (it never resumes a
                        // write — consent is re-given by hand).
                        self.state.fittings_write_needs_reauthorize = false;
                        self.state.status_message = "Permission granted. Refreshing...".to_string();
                    } else {
                        self.state.status_message = "Permission granted. Refreshing...".to_string();
                        tracing::warn!(
                            "[AUTH] step-up finished for non-active character_id={}",
                            character_id
                        );
                    }
                }
                BackendMsg::MarketFetched { generation, data } => {
                    // Design section 8.2: apply only on a full identity
                    // match — generation, selected type, region, and
                    // active character. Any mismatch is a stale result
                    // for a superseded selection: drop it, never apply
                    // or partially merge it.
                    if market_result_matches(&self.state, generation, &data.selection) {
                        tracing::info!("[MARKET] market bundle applied");
                        self.state.market = LoadState::Ready(*data);
                        self.schedule_name_resolution();
                    } else {
                        tracing::warn!(
                            "[MARKET] dropping market result for a superseded selection"
                        );
                    }
                }
                BackendMsg::PlanetaryDetailFetched {
                    generation,
                    selection,
                    result,
                } => {
                    // PI design section 7.3: the Err travels inside
                    // the message, so a stale failure drops by the
                    // same identity check as a stale success.
                    self.apply_planetary_detail_result(generation, selection, result);
                }
                BackendMsg::MarketLookupDone {
                    generation,
                    query,
                    result,
                } => {
                    // Design section 8.3: a lookup whose generation was
                    // superseded, or whose text the user already edited
                    // away from, is stale even if it arrived intact.
                    if !market_lookup_is_current(&self.state, generation, &query) {
                        tracing::warn!("[MARKET] dropping stale item-name lookup result");
                    } else {
                        match result {
                            Ok(candidates) => self.apply_market_lookup_candidates(candidates),
                            Err(e) => {
                                // Error detail is log-only; the view gets
                                // the fixed worded failure line.
                                tracing::warn!("[MARKET] item-name lookup failed: {}", e);
                                self.state.market_lookup_message =
                                    Some(MARKET_LOOKUP_FAILED.to_string());
                            }
                        }
                    }
                }
                BackendMsg::FittingWriteDone {
                    character_id,
                    kind,
                    outcome,
                } => {
                    // Write design section 8, in order: the
                    // flight is over whatever the ids say.
                    self.state.fittings_write_in_flight = None;
                    let landing =
                        decide_fitting_write_landing(&self.state, character_id, kind, &outcome);
                    if landing.stale {
                        // The user switched character or removed
                        // the writer mid-flight: drop the result
                        // whole and claim nothing (the
                        // StructuresResolved precedent). The write
                        // may well have succeeded in EVE for the
                        // original character; switching back and
                        // refreshing shows the server truth.
                        tracing::info!(
                            "[FITTING] stale write result dropped character_id={} kind={}",
                            character_id,
                            kind.label()
                        );
                    } else {
                        if matches!(
                            outcome,
                            FittingWriteOutcome::Saved { .. } | FittingWriteOutcome::Deleted { .. }
                        ) {
                            self.state.fittings_write_needs_reauthorize = false;
                        }
                        if landing.set_reauthorize {
                            self.state.fittings_write_needs_reauthorize = true;
                        }
                        if let Some(pending) = landing.record_pending {
                            self.state.fittings_pending_selection = Some(pending);
                        }
                        if let Some(status) = landing.status {
                            self.state.status_message = status;
                        }
                        if landing.queue_refresh {
                            self.state.refresh_requested = true;
                        }
                        tracing::info!(
                            "[FITTING] fitting write landed character_id={} kind={} outcome={:?}",
                            character_id,
                            kind.label(),
                            outcome
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
                // Structure denials were for the previous character's
                // token; re-arm pinned structure ids under the new
                // active character (design section 6.3 rule 2).
                self.resolver.forget_unresolved_structures();
                self.state.request_refresh("character-switch");
                // Design section 8.5: the switch reset the market
                // bundle to Loading; refill it under the new character
                // when a type is selected.
                if self.state.market_selected_type_id.is_some() {
                    tracing::debug!("[MARKET] market refetch queued after character switch");
                    self.state.market_fetch_requested = true;
                }
            }
        }
        if self.state.refresh_requested || self.state.retry_requested {
            self.state.refresh_requested = false;
            self.state.retry_requested = false;
            self.start_refresh();
        }
        // Market drains (design sections 8.2/8.3): lookup before fetch
        // so a lookup that picks a type starts its fetch this frame.
        if let Some(query) = self.state.market_lookup_requested.take() {
            self.start_market_lookup(query);
        }
        if self.state.market_fetch_requested {
            self.start_market_fetch();
        }
        if self.state.planetary_detail_fetch_requested {
            self.start_planetary_detail_fetch();
        }
        if self.state.login_requested {
            self.state.login_requested = false;
            self.start_login();
        }
        if let Some(request) = self.state.stepup_requested.take() {
            self.start_stepup_login(request);
        }
        if let Some(request) = self.state.fittings_write_requested.take() {
            self.start_fitting_write(request);
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

    /// Shared lookup outcome (design sections 6.1/8.3): one candidate
    /// selects immediately, several become clickable candidates, none
    /// shows the fixed not-found line. Never writes `state.market`.
    fn apply_market_lookup_candidates(&mut self, candidates: Vec<UniverseName>) {
        match candidates.as_slice() {
            [] => {
                tracing::debug!("[MARKET] item-name lookup found no match");
                self.state.market_candidates.clear();
                self.state.market_lookup_message = Some(MARKET_LOOKUP_NOT_FOUND.to_string());
            }
            [only] => {
                let (id, name) = (only.id, only.name.clone());
                tracing::debug!("[MARKET] item-name lookup selected one match");
                self.state.set_market_selection(id, name);
            }
            _ => {
                tracing::debug!(
                    "[MARKET] item-name lookup offered {} candidates",
                    candidates.len()
                );
                self.state.market_candidates = candidates;
                self.state.market_lookup_message = None;
            }
        }
    }

    /// On-demand market fetch (design section 8.2): its own path,
    /// separate from `start_refresh`, keyed by the stamped selection
    /// identity plus generation. In-memory only — no repository call.
    fn start_market_fetch(&mut self) {
        self.state.market_fetch_requested = false;
        if self.state.demo {
            if let (Some(bundle), Some(id)) =
                (self.demo_bundle.clone(), self.state.active_character_id)
            {
                tracing::debug!("[MARKET] demo market fetch re-applies fixture character");
                crate::demo::data::apply_character(&mut self.state, &bundle, id);
            }
            return;
        }
        let Some(type_id) = self.state.market_selected_type_id else {
            tracing::debug!("[MARKET] market fetch skipped: no item selected");
            return;
        };
        let selection = MarketSelection {
            type_id,
            type_name: self
                .state
                .market_selected_type_name
                .clone()
                .unwrap_or_else(|| "Unknown Item".to_string()),
            region_id: self.state.market_region_id,
            character_id: self.state.active_character_id,
        };
        let generation = self.state.market_generation;
        let (Some(backends), Some(runtime)) = (self.backends.as_ref(), self.runtime.as_ref())
        else {
            tracing::warn!("[MARKET] market fetch skipped: live backends not wired");
            self.state.market =
                LoadState::Error("Market data unavailable: live backends not wired.".to_string());
            return;
        };
        let esi = backends.esi.clone();
        let tx = self.tx.clone();
        tracing::info!("[MARKET] market fetch started item={}", selection.type_name);
        runtime.spawn(async move {
            // Three tolerant fetches (never `?`): each section degrades
            // alone. Public sections force needs_reauthorize=false —
            // they need no character and no scope; only the character
            // walk carries the real typed scope outcome.
            let (public_result, history_result, character_result) = tokio::join!(
                endpoints::get_regional_orders(&esi, selection.region_id, selection.type_id),
                endpoints::get_market_history(&esi, selection.region_id, selection.type_id),
                async {
                    match selection.character_id {
                        Some(id) => Some(endpoints::get_character_orders(&esi, id).await),
                        None => None,
                    }
                }
            );
            // SectionError messages render verbatim in the Market view,
            // so they are fixed wording here; full error detail stays in
            // the [MARKET] warn logs above (remote text can embed IDs).
            let public_orders = match public_result {
                Ok((orders, truncated)) => Ok(PublicOrdersData { orders, truncated }),
                Err(e) => {
                    tracing::warn!("[MARKET] market section failed section=public_orders error={}", e);
                    Err(SectionError {
                        message: "public orders request failed".to_string(),
                        needs_reauthorize: false,
                    })
                }
            };
            let history = match history_result {
                Ok(entries) => Ok(entries),
                Err(e) => {
                    tracing::warn!("[MARKET] market section failed section=history error={}", e);
                    Err(SectionError {
                        message: "price history request failed".to_string(),
                        needs_reauthorize: false,
                    })
                }
            };
            let character_orders = match character_result {
                None => Ok(CharacterOrdersData::default()),
                Some(Ok((orders, truncated))) => {
                    Ok(CharacterOrdersData { orders, truncated })
                }
                Some(Err(e)) => {
                    let needs_reauthorize = endpoints::needs_reauthorize(&e);
                    tracing::warn!(
                        "[MARKET] market section failed section=character_orders needs_reauthorize={} error={}",
                        needs_reauthorize,
                        e
                    );
                    Err(SectionError {
                        message: "character orders request failed".to_string(),
                        needs_reauthorize,
                    })
                }
            };
            let data = MarketData {
                selection,
                public_orders,
                history,
                character_orders,
            };
            tracing::info!(
                "[MARKET] market fetch ready public_orders={} public_truncated={} history_days={} character_orders={} character_truncated={}",
                data.public_orders.as_ref().map_or(0, |d| d.orders.len()),
                data.public_orders
                    .as_ref()
                    .is_ok_and(|d| d.truncated),
                data.history.as_ref().map_or(0, Vec::len),
                data.character_orders.as_ref().map_or(0, |d| d.orders.len()),
                data.character_orders
                    .as_ref()
                    .is_ok_and(|d| d.truncated)
            );
            let _ = tx.send(BackendMsg::MarketFetched {
                generation,
                data: Box::new(data),
            });
        });
    }

    /// Install one colony detail result only on a full identity
    /// match (PI design section 7.3). A matching result that lands
    /// while the bundle is not Ready (a refresh error raced it)
    /// drops the same way; the next refresh re-queues per 7.2.
    fn apply_planetary_detail_result(
        &mut self,
        generation: u64,
        selection: PlanetSelection,
        result: SectionResult<PlanetColonyDetail>,
    ) {
        if !planetary_result_matches(&self.state, generation, &selection) {
            tracing::warn!("[PI] dropping colony detail result for a superseded selection");
            return;
        }
        match &result {
            Ok(detail) => tracing::info!(
                "[PI] colony detail applied character_id={} pins={} links={} routes={}",
                selection.character_id,
                detail.pins.len(),
                detail.links.len(),
                detail.routes.len()
            ),
            Err(e) => tracing::info!(
                "[PI] colony detail error applied character_id={} needs_reauthorize={}",
                selection.character_id,
                e.needs_reauthorize
            ),
        }
        match &mut self.state.planetary {
            LoadState::Ready(bundle) => {
                bundle.detail = Some(SelectedColonyDetail { selection, result });
            }
            _ => {
                tracing::warn!("[PI] dropping colony detail result for a superseded selection");
                return;
            }
        }
        self.schedule_name_resolution();
    }

    /// On-demand colony detail fetch (PI design section 7.3): its
    /// own spawn on selection change, keyed by character + planet +
    /// generation. In-memory only — no repository call. Demo answers
    /// from the bundle's per-colony details with zero network and
    /// never changes the demo selection itself.
    fn start_planetary_detail_fetch(&mut self) {
        self.state.planetary_detail_fetch_requested = false;
        let (Some(character_id), Some(planet_id)) = (
            self.state.active_character_id,
            self.state.planetary_selected_planet_id,
        ) else {
            tracing::debug!("[PI] colony detail fetch skipped: no character or colony selected");
            return;
        };
        let selection = PlanetSelection {
            character_id,
            planet_id,
        };
        let generation = self.state.planetary_generation;
        if self.state.demo {
            let detail = self
                .demo_bundle
                .as_ref()
                .and_then(|bundle| bundle.character_data(character_id))
                .and_then(|per| per.planets.as_ref())
                .and_then(|planets| planets.details.get(&planet_id))
                .cloned();
            tracing::debug!(
                "[PI] demo colony detail answered from bundle hit={}",
                detail.is_some()
            );
            let result = detail.ok_or_else(|| SectionError {
                message: "colony detail request failed".to_string(),
                needs_reauthorize: false,
            });
            self.apply_planetary_detail_result(generation, selection, result);
            return;
        }
        let (Some(backends), Some(runtime)) = (self.backends.as_ref(), self.runtime.as_ref())
        else {
            // A detail failure must never blank the colonies list:
            // install the stamped fixed Err through the same match
            // check instead of a whole-view LoadState::Error.
            tracing::warn!("[PI] colony detail fetch skipped: live backends not wired");
            self.apply_planetary_detail_result(
                generation,
                selection,
                Err(SectionError {
                    message: "colony detail request failed".to_string(),
                    needs_reauthorize: false,
                }),
            );
            return;
        };
        let esi = backends.esi.clone();
        let tx = self.tx.clone();
        tracing::info!(
            "[PI] colony detail fetch started character_id={} planet_id={}",
            character_id,
            planet_id
        );
        runtime.spawn(async move {
            // The fixed wording is the only detail failure string
            // that can reach the screen; the full error stays in
            // this [PI] warn line.
            let result = endpoints::get_character_planet(&esi, character_id, planet_id)
                .await
                .map_err(|e| {
                    let needs_reauthorize = endpoints::needs_reauthorize(&e);
                    tracing::warn!("[PI] planetary section failed character_id={} section=colony detail needs_reauthorize={} error={}", character_id, needs_reauthorize, e);
                    SectionError {
                        message: "colony detail request failed".to_string(),
                        needs_reauthorize,
                    }
                });
            let _ = tx.send(BackendMsg::PlanetaryDetailFetched {
                generation,
                selection,
                result,
            });
        });
    }

    /// Exact-name item lookup (design section 8.3). Demo answers
    /// synchronously from quick-pick labels with zero network; live
    /// reuses the existing public `resolve_ids` (no new POST site),
    /// filtered to inventory types.
    fn start_market_lookup(&mut self, query: String) {
        if self.state.demo {
            let candidates: Vec<UniverseName> =
                ui::market::quick_pick_types(&self.state, &self.resolver)
                    .into_iter()
                    .filter(|(_, label)| label.to_lowercase() == query.trim().to_lowercase())
                    .map(|(id, name)| UniverseName {
                        id,
                        name,
                        category: "inventory_type".to_string(),
                    })
                    .collect();
            tracing::debug!(
                "[DEMO] demo item-name lookup matched {} bundled types",
                candidates.len()
            );
            self.apply_market_lookup_candidates(candidates);
            return;
        }
        let generation = self.state.market_generation;
        let (Some(backends), Some(runtime)) = (self.backends.as_ref(), self.runtime.as_ref())
        else {
            tracing::warn!("[MARKET] item-name lookup skipped: live backends not wired");
            self.state.market_lookup_message = Some(MARKET_LOOKUP_FAILED.to_string());
            return;
        };
        let esi = backends.esi.clone();
        let tx = self.tx.clone();
        tracing::debug!("[MARKET] item-name lookup started");
        runtime.spawn(async move {
            let result = endpoints::resolve_ids(&esi, std::slice::from_ref(&query))
                .await
                .map(|names| {
                    let mut types: Vec<UniverseName> = names
                        .into_iter()
                        .filter(|n| n.category == "inventory_type" && n.id > 0)
                        .collect();
                    types.sort_by(|a, b| {
                        a.name
                            .to_lowercase()
                            .cmp(&b.name.to_lowercase())
                            .then_with(|| a.name.cmp(&b.name))
                            .then(a.id.cmp(&b.id))
                    });
                    types
                })
                .map_err(|e| e.to_string());
            let _ = tx.send(BackendMsg::MarketLookupDone {
                generation,
                query,
                result,
            });
        });
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
                            (Err("assets request failed".to_string()), reauthorize)
                        }
                    };
                // Character details are seven tolerant sub-fetches (never
                // `?`): a section failure degrades only that section and
                // never fails the character/skills/wallet/assets refresh.
                // SectionError messages render verbatim in section
                // panels, so they are fixed wording here; full error
                // detail stays in the [CHAR] warn logs above each.
                let attributes = endpoints::get_attributes(&esi, id).await.map_err(|e| {
                    let needs_reauthorize = endpoints::needs_reauthorize(&e);
                    tracing::warn!("[CHAR] character detail section failed character_id={} section=attributes needs_reauthorize={} error={}", id, needs_reauthorize, e);
                    SectionError {
                        message: "attributes request failed".to_string(),
                        needs_reauthorize,
                    }
                });
                let implants = endpoints::get_implants(&esi, id).await.map_err(|e| {
                    let needs_reauthorize = endpoints::needs_reauthorize(&e);
                    tracing::warn!("[CHAR] character detail section failed character_id={} section=implants needs_reauthorize={} error={}", id, needs_reauthorize, e);
                    SectionError {
                        message: "implants request failed".to_string(),
                        needs_reauthorize,
                    }
                });
                let clones = endpoints::get_clones(&esi, id).await.map_err(|e| {
                    let needs_reauthorize = endpoints::needs_reauthorize(&e);
                    tracing::warn!("[CHAR] character detail section failed character_id={} section=clones needs_reauthorize={} error={}", id, needs_reauthorize, e);
                    SectionError {
                        message: "clones request failed".to_string(),
                        needs_reauthorize,
                    }
                });
                let standings = endpoints::get_standings(&esi, id).await.map_err(|e| {
                    let needs_reauthorize = endpoints::needs_reauthorize(&e);
                    tracing::warn!("[CHAR] character detail section failed character_id={} section=standings needs_reauthorize={} error={}", id, needs_reauthorize, e);
                    SectionError {
                        message: "standings request failed".to_string(),
                        needs_reauthorize,
                    }
                });
                let location = endpoints::get_location(&esi, id).await.map_err(|e| {
                    let needs_reauthorize = endpoints::needs_reauthorize(&e);
                    tracing::warn!("[CHAR] character detail section failed character_id={} section=location needs_reauthorize={} error={}", id, needs_reauthorize, e);
                    SectionError {
                        message: "location request failed".to_string(),
                        needs_reauthorize,
                    }
                });
                let ship = endpoints::get_ship(&esi, id).await.map_err(|e| {
                    let needs_reauthorize = endpoints::needs_reauthorize(&e);
                    tracing::warn!("[CHAR] character detail section failed character_id={} section=ship needs_reauthorize={} error={}", id, needs_reauthorize, e);
                    SectionError {
                        message: "ship request failed".to_string(),
                        needs_reauthorize,
                    }
                });
                let online = endpoints::get_online(&esi, id).await.map_err(|e| {
                    let needs_reauthorize = endpoints::needs_reauthorize(&e);
                    tracing::warn!("[CHAR] character detail section failed character_id={} section=online needs_reauthorize={} error={}", id, needs_reauthorize, e);
                    SectionError {
                        message: "online status request failed".to_string(),
                        needs_reauthorize,
                    }
                });
                let detail = CharacterDetailData {
                    attributes,
                    implants,
                    clones,
                    standings,
                    location,
                    ship,
                    online,
                };
                tracing::info!(
                    "[CHAR] character details ready character_id={} implants={} clones={} standings={}",
                    id,
                    detail.implants.as_ref().map_or(0, Vec::len),
                    detail
                        .clones
                        .as_ref()
                        .map_or(0, |c| c.jump_clones.len()),
                    detail.standings.as_ref().map_or(0, Vec::len)
                );
                // Industry is two tolerant sub-fetches (never `?`):
                // a section failure degrades only that section.
                // SectionError messages render verbatim in section
                // panels, so they are fixed wording here; full error
                // detail stays in the [INDUSTRY] warn logs above each.
                let jobs = endpoints::get_character_industry_jobs(&esi, id)
                    .await
                    .map(|(jobs, truncated)| IndustryJobsData { jobs, truncated })
                    .map_err(|e| {
                        let needs_reauthorize = endpoints::needs_reauthorize(&e);
                        tracing::warn!("[INDUSTRY] industry section failed character_id={} section=jobs needs_reauthorize={} error={}", id, needs_reauthorize, e);
                        SectionError {
                            message: "industry jobs request failed".to_string(),
                            needs_reauthorize,
                        }
                    });
                let blueprints = endpoints::get_character_blueprints(&esi, id)
                    .await
                    .map(|(blueprints, truncated)| BlueprintsData {
                        blueprints,
                        truncated,
                    })
                    .map_err(|e| {
                        let needs_reauthorize = endpoints::needs_reauthorize(&e);
                        tracing::warn!("[INDUSTRY] industry section failed character_id={} section=blueprints needs_reauthorize={} error={}", id, needs_reauthorize, e);
                        SectionError {
                            message: "blueprints request failed".to_string(),
                            needs_reauthorize,
                        }
                    });
                let industry = IndustryData { jobs, blueprints };
                tracing::info!(
                    "[INDUSTRY] industry ready character_id={} jobs={} jobs_truncated={} blueprints={} blueprints_truncated={}",
                    id,
                    industry.jobs.as_ref().map_or(0, |d| d.jobs.len()),
                    industry.jobs.as_ref().is_ok_and(|d| d.truncated),
                    industry
                        .blueprints
                        .as_ref()
                        .map_or(0, |d| d.blueprints.len()),
                    industry.blueprints.as_ref().is_ok_and(|d| d.truncated)
                );
                // Colonies list is one tolerant sub-fetch (never `?`,
                // PI design section 7.2): fixed wording on screen,
                // full error detail in the [PI] warn only. Colony
                // detail is never fetched here (no N+1 walk).
                let planetary_colonies = endpoints::get_character_planets(&esi, id)
                    .await
                    .map_err(|e| {
                        let needs_reauthorize = endpoints::needs_reauthorize(&e);
                        tracing::warn!("[PI] planetary section failed character_id={} section=colonies needs_reauthorize={} error={}", id, needs_reauthorize, e);
                        SectionError {
                            message: "colonies request failed".to_string(),
                            needs_reauthorize,
                        }
                    });
                if let Ok(colonies) = &planetary_colonies {
                    tracing::info!(
                        "[PI] colonies ready character_id={} colonies={}",
                        id,
                        colonies.len()
                    );
                }
                // Saved fittings are one tolerant sub-fetch (never
                // `?`, fittings design section 7.2): fixed wording
                // on screen, full error detail in the [FITTING]
                // warn only. In-memory only — nothing about
                // fittings is persisted in the persist block below.
                let fittings_list = endpoints::get_character_fittings(&esi, id)
                    .await
                    .map_err(|e| {
                        let needs_reauthorize = endpoints::needs_reauthorize(&e);
                        tracing::warn!("[FITTING] fittings section failed character_id={} section=fittings needs_reauthorize={} error={}", id, needs_reauthorize, e);
                        SectionError {
                            message: "fittings request failed".to_string(),
                            needs_reauthorize,
                        }
                    });
                if let Ok(fittings) = &fittings_list {
                    tracing::info!(
                        "[FITTING] fittings ready character_id={} fittings={} items={}",
                        id,
                        fittings.len(),
                        fittings
                            .iter()
                            .fold(0usize, |total, f| total.saturating_add(f.items.len()))
                    );
                }
                Ok::<_, crate::AppError>((
                    info,
                    SkillsData { skills, queue },
                    wallet,
                    assets,
                    assets_needs_reauthorize,
                    detail,
                    industry,
                    planetary_colonies,
                    fittings_list,
                ))
            }
            .await;
            match result {
                Ok((
                    info,
                    skills,
                    wallet,
                    assets,
                    assets_needs_reauthorize,
                    detail,
                    industry,
                    planetary_colonies,
                    fittings_list,
                )) => {
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
                        detail: Box::new(detail),
                        industry: Box::new(industry),
                        planetary_colonies,
                        fittings_list,
                    });
                }
                Err(e) => {
                    let _ = tx.send(BackendMsg::RefreshFailed {
                        character_id: id,
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
        // Observed reality outranks stored metadata: if a section for
        // one of the requested scope groups already returned 403 this
        // session, token_meta claiming the grant is stale, and taking
        // the shortcut would loop the panel forever without ever
        // opening the browser the user just asked for.
        let observed_reauthorize = {
            let overlaps = |set: &[&str]| {
                request
                    .scopes
                    .iter()
                    .any(|scope| set.contains(&scope.as_str()))
            };
            (overlaps(EveConfig::ASSETS_SCOPES) && self.state.assets_needs_reauthorize)
                || (overlaps(EveConfig::CHARACTER_DETAIL_SCOPES)
                    && matches!(&self.state.character_details, LoadState::Ready(d) if d.needs_detail_stepup()))
                || (overlaps(EveConfig::INDUSTRY_SCOPES)
                    && matches!(&self.state.industry, LoadState::Ready(d) if d.needs_industry_stepup()))
                || (overlaps(EveConfig::PLANETS_SCOPES)
                    && matches!(&self.state.planetary, LoadState::Ready(d) if d.needs_planetary_stepup()))
                || fittings_stepup_observed(&request.scopes, &self.state)
                || fittings_write_stepup_observed(&request.scopes, &self.state)
                || structures_stepup_observed(&request.scopes, &self.state)
                || (overlaps(EveConfig::MARKET_SCOPES)
                    && matches!(&self.state.market, LoadState::Ready(d) if matches!(&d.character_orders, Err(e) if e.needs_reauthorize)))
        };
        if missing.is_empty() && !observed_reauthorize {
            tracing::info!(
                "[AUTH] step-up skipped; scopes already granted character_id={}",
                request.character_id
            );
            // request_refresh sets its own generic status, so the specific
            // already-granted status must be set after it.
            self.state.request_refresh("stepup-already-granted");
            // The main refresh never touches market state, so queue the
            // market refetch too (mirror StepUpLoggedIn) or the Market
            // re-authorize panel can never clear via its own button when
            // token metadata already claims the scope.
            if self.state.market_selected_type_id.is_some() {
                tracing::debug!("[MARKET] market refetch queued after already-granted step-up");
                self.state.market_fetch_requested = true;
            }
            // PI design section 7.5: the shortcut must queue the
            // same refetch the Planets panel gates — the refresh
            // above covers the list, this queues the gated
            // planetary_detail_fetch_requested detail refetch.
            if self.state.planetary_selected_planet_id.is_some() {
                tracing::debug!("[PI] colony detail refetch queued after already-granted step-up");
                self.state.planetary_detail_fetch_requested = true;
            }
            // Fittings design section 7.3: no fittings flag here
            // either — the already-granted main refresh above
            // already refills the fittings list the panel gates.
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

    /// Start one confirmed fitting write (write design
    /// section 7.2). Refusals are synchronous and never set
    /// the flight or spawn; the scope-absent case (section
    /// 3.3) is detected from token metadata before any HTTP
    /// request is made. On spawn, exactly one endpoint call
    /// runs and exactly one `FittingWriteDone` is sent on
    /// every path. No write is ever retried automatically.
    fn start_fitting_write(&mut self, request: FittingWriteRequest) {
        let (character_id, kind) = match &request {
            FittingWriteRequest::Save { character_id, .. } => {
                (*character_id, FittingWriteKind::Save)
            }
            FittingWriteRequest::Delete { character_id, .. } => {
                (*character_id, FittingWriteKind::Delete)
            }
        };
        let kind_label = kind.label();
        // Demo performs no writes and offers none (section 10):
        // this is the shell backstop, not the only defense.
        if self.state.demo {
            tracing::warn!(
                "[FITTING] fitting write refused in demo character_id={} kind={}",
                character_id,
                kind_label
            );
            self.state.status_message =
                "Demo mode uses sample data. Saving or deleting fittings in EVE is disabled."
                    .to_string();
            return;
        }
        if self.state.auth.is_busy() {
            tracing::warn!(
                "[FITTING] fitting write refused; sign-in in progress character_id={} kind={}",
                character_id,
                kind_label
            );
            self.state.status_message =
                "Finish sign-in in your browser before changing fittings in EVE.".to_string();
            return;
        }
        if self.state.fittings_write_in_flight.is_some() {
            tracing::warn!(
                "[FITTING] fitting write refused; one already in flight character_id={} kind={}",
                character_id,
                kind_label
            );
            self.state.status_message =
                "A fitting change is already in progress. Wait for it to finish.".to_string();
            return;
        }
        if !self
            .state
            .characters
            .iter()
            .any(|c| c.character_id == character_id)
        {
            tracing::warn!(
                "[FITTING] fitting write refused for unknown character_id={} kind={}",
                character_id,
                kind_label
            );
            self.state.status_message =
                "That character is no longer in Mimir. Nothing was sent to EVE.".to_string();
            return;
        }
        if self.state.active_character_id != Some(character_id) {
            tracing::warn!(
                "[FITTING] fitting write refused; active character changed character_id={} kind={}",
                character_id,
                kind_label
            );
            self.state.status_message =
                "The active character changed. Nothing was sent to EVE.".to_string();
            return;
        }
        let (Some(backends), Some(runtime)) = (self.backends.as_ref(), self.runtime.as_ref())
        else {
            tracing::warn!(
                "[FITTING] fitting write refused; backends not wired character_id={} kind={}",
                character_id,
                kind_label
            );
            self.state.status_message =
                "Fitting changes are unavailable: live backends not wired.".to_string();
            return;
        };
        // Scope pre-check (section 3.3): stored token metadata
        // is read the same way the step-up flow reads it; a
        // missing row or read error is treated as absent, and
        // absence sends nothing.
        let granted: Vec<String> = match backends.db.lock() {
            Ok(conn) => match repositories::get_token_meta(&conn, character_id) {
                Ok(Some(meta)) => oauth::split_scopes(&meta.scopes),
                Ok(None) => Vec::new(),
                Err(e) => {
                    tracing::warn!(
                        "[FITTING] fitting write token_meta read failed character_id={} error={}",
                        character_id,
                        e
                    );
                    Vec::new()
                }
            },
            Err(e) => {
                tracing::warn!(
                    "[FITTING] fitting write token_meta lock failed character_id={} error={}",
                    character_id,
                    e
                );
                Vec::new()
            }
        };
        let wanted: Vec<String> = EveConfig::FITTINGS_WRITE_SCOPES
            .iter()
            .map(|s| s.to_string())
            .collect();
        if !oauth::missing_scopes(&granted, &wanted).is_empty() {
            tracing::info!(
                "[FITTING] fitting write refused; write scope absent character_id={} kind={}",
                character_id,
                kind_label
            );
            self.state.fittings_write_needs_reauthorize = true;
            self.state.status_message = "Saving and deleting fittings needs one more EVE permission. Re-authorize in the Fittings view.".to_string();
            return;
        }
        let esi = backends.esi.clone();
        let tx = self.tx.clone();
        match request {
            FittingWriteRequest::Save {
                character_id,
                request,
            } => {
                tracing::info!(
                    "[FITTING] write started character_id={} kind=save items={}",
                    character_id,
                    request.items.len()
                );
                self.state.fittings_write_in_flight = Some(FittingWriteInFlight {
                    character_id,
                    kind: FittingWriteKind::Save,
                    fitting_id: None,
                });
                runtime.spawn(async move {
                    let outcome =
                        match endpoints::save_character_fitting(&esi, character_id, &request).await
                        {
                            Ok(response) => FittingWriteOutcome::Saved {
                                fitting_id: response.fitting_id,
                            },
                            Err(e) => {
                                let (class, needs_reauthorize) =
                                    endpoints::classify_write_error(&e, false);
                                tracing::warn!(
                                    "[FITTING] save failed character_id={} error={}",
                                    character_id,
                                    e
                                );
                                FittingWriteOutcome::Failed {
                                    class,
                                    needs_reauthorize,
                                }
                            }
                        };
                    let _ = tx.send(BackendMsg::FittingWriteDone {
                        character_id,
                        kind: FittingWriteKind::Save,
                        outcome,
                    });
                });
            }
            FittingWriteRequest::Delete {
                character_id,
                fitting_id,
            } => {
                tracing::info!(
                    "[FITTING] write started character_id={} kind=delete",
                    character_id
                );
                self.state.fittings_write_in_flight = Some(FittingWriteInFlight {
                    character_id,
                    kind: FittingWriteKind::Delete,
                    fitting_id: Some(fitting_id),
                });
                runtime.spawn(async move {
                    let outcome =
                        match endpoints::delete_character_fitting(&esi, character_id, fitting_id)
                            .await
                        {
                            Ok(()) => FittingWriteOutcome::Deleted { fitting_id },
                            Err(e) => {
                                let (class, needs_reauthorize) =
                                    endpoints::classify_write_error(&e, true);
                                tracing::warn!(
                                    "[FITTING] delete failed character_id={} error={}",
                                    character_id,
                                    e
                                );
                                FittingWriteOutcome::Failed {
                                    class,
                                    needs_reauthorize,
                                }
                            }
                        };
                    let _ = tx.send(BackendMsg::FittingWriteDone {
                        character_id,
                        kind: FittingWriteKind::Delete,
                        outcome,
                    });
                });
            }
        }
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
                egui::Key::Num7,
                egui::Key::Num8,
                egui::Key::Num9,
            ]
            .iter()
            .enumerate()
            {
                if i.key_pressed(*key) && !i.modifiers.command && !i.modifiers.ctrl {
                    actions.switch_view = View::from_index(idx);
                }
            }
            // Tenth view (Settings, index 9) takes Num0 so keys
            // 1-9 keep their muscle memory (fittings design 9.4).
            if i.key_pressed(egui::Key::Num0) && !i.modifiers.command && !i.modifiers.ctrl {
                actions.switch_view = View::from_index(9);
            }
            // Eleventh view (Exploration, index 10): every digit is
            // taken, so it takes the mnemonic letter E under the same
            // typing/modifier guards (exploration design section 6.2).
            if i.key_pressed(egui::Key::E) && !i.modifiers.command && !i.modifiers.ctrl {
                actions.switch_view = Some(View::Exploration);
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
        if let LoadState::Ready(data) = &self.state.skills {
            if data.queue.iter().any(|item| item.finish_date.is_some()) {
                return true;
            }
        }
        if let LoadState::Ready(bundle) = &self.state.industry {
            if let Ok(jobs_data) = &bundle.jobs {
                return jobs_data
                    .jobs
                    .iter()
                    .any(|job| ui::industry::is_in_progress_status(&job.status));
            }
        }
        false
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
            ui.heading("Views (keys 1-9, 0, E)");
            for view in View::ALL.iter() {
                let selected = self.state.view == *view;
                if ui
                    .selectable_label(
                        selected,
                        format!("{} {}", view_key_hint(*view), view.label()),
                    )
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
                View::Market => ui::market::show(ui, &mut self.state, &self.resolver),
                View::Industry => ui::industry::show(ui, &mut self.state, &self.resolver),
                View::Planets => ui::planets::show(ui, &mut self.state, &self.resolver),
                View::Fittings => ui::fittings::show(
                    ui,
                    &mut self.state,
                    &self.resolver,
                    self.fitting_types.as_deref(),
                ),
                View::Settings => ui::settings::show(ui, &mut self.state),
                View::Exploration => ui::exploration::show(ui, &mut self.state),
            });
        });

        egui::TopBottomPanel::bottom("status_bar").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.label(format!("View: {}", self.state.view.label()));
                ui.label(format!("Characters: {}", self.state.characters.len()));
                if self.state.refresh_requested {
                    ui.label("Refresh pending...");
                }
                ui.label("Keys: 1-9, 0, E views, Ctrl+R refresh, / search, PgUp/PgDn character");
            });
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn selected_state() -> (AppState, MarketSelection) {
        let mut state = AppState::new(false);
        state.active_character_id = Some(42);
        state.set_market_selection(34, "Tritanium".to_string());
        let selection = MarketSelection {
            type_id: 34,
            type_name: "Tritanium".to_string(),
            region_id: state.market_region_id,
            character_id: Some(42),
        };
        (state, selection)
    }

    #[test]
    fn market_result_identity_requires_all_four_matches() {
        let (state, selection) = selected_state();
        let gen = state.market_generation;
        assert!(market_result_matches(&state, gen, &selection));
        // Nothing selected can never match.
        assert!(!market_result_matches(
            &AppState::new(false),
            gen,
            &selection
        ));
        // Each single mismatch alone drops the result.
        assert!(!market_result_matches(
            &state,
            gen.wrapping_add(1),
            &selection
        ));
        assert!(!market_result_matches(
            &state,
            gen,
            &MarketSelection {
                type_id: 35,
                ..selection.clone()
            }
        ));
        assert!(!market_result_matches(
            &state,
            gen,
            &MarketSelection {
                region_id: 10000043,
                ..selection.clone()
            }
        ));
        assert!(!market_result_matches(
            &state,
            gen,
            &MarketSelection {
                character_id: None,
                ..selection.clone()
            }
        ));
        assert!(!market_result_matches(
            &state,
            gen,
            &MarketSelection {
                character_id: Some(7),
                ..selection
            }
        ));
    }

    #[test]
    fn planetary_result_identity_requires_all_three_matches() {
        let mut state = AppState::new(false);
        state.active_character_id = Some(42);
        state.set_planetary_selection(700000001);
        let gen = state.planetary_generation;
        let selection = PlanetSelection {
            character_id: 42,
            planet_id: 700000001,
        };
        assert!(planetary_result_matches(&state, gen, &selection));
        // Nothing selected can never match, even at the same generation.
        let mut unselected = AppState::new(false);
        unselected.active_character_id = Some(42);
        unselected.planetary_generation = gen;
        assert!(!planetary_result_matches(&unselected, gen, &selection));
        // Each single mismatch alone drops the result.
        assert!(!planetary_result_matches(
            &state,
            gen.wrapping_add(1),
            &selection
        ));
        assert!(!planetary_result_matches(
            &state,
            gen,
            &PlanetSelection {
                planet_id: 700000002,
                ..selection
            }
        ));
        assert!(!planetary_result_matches(
            &state,
            gen,
            &PlanetSelection {
                character_id: 7,
                ..selection
            }
        ));
    }

    #[test]
    fn market_lookup_freshness_requires_generation_and_current_text() {
        let (mut state, _) = selected_state();
        state.market_search = "  Tritanium ".to_string();
        let gen = state.market_generation;
        assert!(market_lookup_is_current(&state, gen, "Tritanium"));
        assert!(!market_lookup_is_current(
            &state,
            gen.wrapping_add(1),
            "Tritanium"
        ));
        assert!(!market_lookup_is_current(&state, gen, "Pyerite"));
        assert!(!market_lookup_is_current(&state, gen, "  Tritanium "));
    }

    fn fitting(id: i64) -> CharacterFitting {
        CharacterFitting {
            fitting_id: id,
            ..CharacterFitting::default()
        }
    }

    #[test]
    fn fittings_selection_survives_unless_ok_list_proves_it_gone() {
        let present = Ok(vec![fitting(1), fitting(2)]);
        // A surviving selection is kept.
        assert!(!fittings_selection_is_stale(Some(2), &present));
        // A successful list without the selection clears it.
        assert!(fittings_selection_is_stale(Some(3), &present));
        // No selection is never stale.
        assert!(!fittings_selection_is_stale(None, &present));
        // A failed list proves nothing: the selection survives.
        let failed: SectionResult<Vec<CharacterFitting>> = Err(SectionError {
            message: "fittings request failed".to_string(),
            needs_reauthorize: false,
        });
        assert!(!fittings_selection_is_stale(Some(3), &failed));
        // An empty successful list proves every selection gone.
        assert!(fittings_selection_is_stale(Some(1), &Ok(Vec::new())));
    }

    #[test]
    fn fittings_observed_reauthorize_blocks_shortcut_only_on_scope_refusal() {
        let fittings_scope = vec!["esi-fittings.read_fittings.v1".to_string()];
        let other_scope = vec!["esi-assets.read_assets.v1".to_string()];
        let mut state = AppState::new(false);
        // Nothing loaded yet: shortcut allowed.
        assert!(!fittings_stepup_observed(&fittings_scope, &state));
        state.fittings = LoadState::Ready(FittingsData {
            fittings: Err(SectionError {
                message: "fittings request failed".to_string(),
                needs_reauthorize: true,
            }),
        });
        // Scope refusal + fittings request blocks the shortcut.
        assert!(fittings_stepup_observed(&fittings_scope, &state));
        // An unrelated request is not blocked by the fittings arm.
        assert!(!fittings_stepup_observed(&other_scope, &state));
        // A plain (non-scope) failure does not block it.
        state.fittings = LoadState::Ready(FittingsData {
            fittings: Err(SectionError {
                message: "fittings request failed".to_string(),
                needs_reauthorize: false,
            }),
        });
        assert!(!fittings_stepup_observed(&fittings_scope, &state));
        // A loaded list does not block it.
        state.fittings = LoadState::Ready(FittingsData {
            fittings: Ok(vec![fitting(1)]),
        });
        assert!(!fittings_stepup_observed(&fittings_scope, &state));
    }

    #[test]
    fn structures_observed_reauthorize_blocks_shortcut_only_when_flag_set() {
        let structures_scope = vec!["esi-universe.read_structures.v1".to_string()];
        let other_scope = vec!["esi-assets.read_assets.v1".to_string()];
        let mut state = AppState::new(false);
        // Flag unset: shortcut allowed.
        assert!(!structures_stepup_observed(&structures_scope, &state));
        // Flag set + structures request blocks the shortcut.
        state.structures_needs_reauthorize = true;
        assert!(structures_stepup_observed(&structures_scope, &state));
        // An unrelated request is not blocked by the structures arm.
        assert!(!structures_stepup_observed(&other_scope, &state));
    }

    #[test]
    fn fittings_write_stepup_observed_needs_scope_and_flag() {
        let write_scope = vec!["esi-fittings.write_fittings.v1".to_string()];
        let read_scope = vec!["esi-fittings.read_fittings.v1".to_string()];
        let mut state = AppState::new(false);
        // Flag unset: shortcut allowed even for the write scope.
        assert!(!fittings_write_stepup_observed(&write_scope, &state));
        // Flag set + write scope request blocks the shortcut.
        state.fittings_write_needs_reauthorize = true;
        assert!(fittings_write_stepup_observed(&write_scope, &state));
        // The read scope alone never triggers the write arm.
        assert!(!fittings_write_stepup_observed(&read_scope, &state));
        // Flag clear again: shortcut allowed.
        state.fittings_write_needs_reauthorize = false;
        assert!(!fittings_write_stepup_observed(&write_scope, &state));
    }

    #[test]
    fn fitting_write_landing_drops_whole_on_character_mismatch() {
        let mut state = AppState::new(false);
        state.active_character_id = Some(42);
        let outcomes = [
            FittingWriteOutcome::Saved { fitting_id: 7 },
            FittingWriteOutcome::Deleted { fitting_id: 7 },
            FittingWriteOutcome::Failed {
                class: WriteFailureClass::Unknown,
                needs_reauthorize: false,
            },
        ];
        for outcome in outcomes {
            for kind in [FittingWriteKind::Save, FittingWriteKind::Delete] {
                let landing = decide_fitting_write_landing(&state, 7, kind, &outcome);
                assert!(landing.stale, "mismatch drops whole");
                assert_eq!(landing.status, None, "no status on a stale landing");
                assert!(!landing.queue_refresh, "no refresh on a stale landing");
                assert_eq!(landing.record_pending, None);
                assert!(!landing.set_reauthorize);
            }
        }
    }

    #[test]
    fn fitting_write_landing_matrix_on_match() {
        let mut state = AppState::new(false);
        state.active_character_id = Some(42);
        // Saved: refresh queued, pending selection recorded.
        let landing = decide_fitting_write_landing(
            &state,
            42,
            FittingWriteKind::Save,
            &FittingWriteOutcome::Saved { fitting_id: 4242 },
        );
        assert!(!landing.stale);
        assert_eq!(
            landing.status.as_deref(),
            Some("Saved the fitting to EVE. Refreshing your fitting list...")
        );
        assert!(landing.queue_refresh);
        assert_eq!(landing.record_pending, Some((42, 4242)));
        // Deleted: refresh queued, no pending selection.
        let landing = decide_fitting_write_landing(
            &state,
            42,
            FittingWriteKind::Delete,
            &FittingWriteOutcome::Deleted { fitting_id: 4242 },
        );
        assert_eq!(
            landing.status.as_deref(),
            Some("Deleted the fitting from EVE. Refreshing your fitting list...")
        );
        assert!(landing.queue_refresh);
        assert_eq!(landing.record_pending, None);
        // Unknown: refresh queued (the reconciliation), no pending.
        let landing = decide_fitting_write_landing(
            &state,
            42,
            FittingWriteKind::Save,
            &FittingWriteOutcome::Failed {
                class: WriteFailureClass::Unknown,
                needs_reauthorize: false,
            },
        );
        assert!(landing.queue_refresh);
        assert_eq!(landing.record_pending, None);
        assert!(!landing.set_reauthorize);
        // Definitive: no refresh, no pending.
        let landing = decide_fitting_write_landing(
            &state,
            42,
            FittingWriteKind::Save,
            &FittingWriteOutcome::Failed {
                class: WriteFailureClass::Definitive,
                needs_reauthorize: false,
            },
        );
        assert!(!landing.queue_refresh);
        assert_eq!(landing.record_pending, None);
        // Reauthorize failure: flag set, no refresh.
        let landing = decide_fitting_write_landing(
            &state,
            42,
            FittingWriteKind::Save,
            &FittingWriteOutcome::Failed {
                class: WriteFailureClass::Definitive,
                needs_reauthorize: true,
            },
        );
        assert!(landing.set_reauthorize);
        assert!(!landing.queue_refresh);
        // NotSent: no refresh.
        let landing = decide_fitting_write_landing(
            &state,
            42,
            FittingWriteKind::Save,
            &FittingWriteOutcome::Failed {
                class: WriteFailureClass::NotSent,
                needs_reauthorize: false,
            },
        );
        assert!(!landing.queue_refresh);
        // AlreadyGone: refresh queued.
        let landing = decide_fitting_write_landing(
            &state,
            42,
            FittingWriteKind::Delete,
            &FittingWriteOutcome::Failed {
                class: WriteFailureClass::AlreadyGone,
                needs_reauthorize: false,
            },
        );
        assert!(landing.queue_refresh);
        // RateLimited: no refresh.
        let landing = decide_fitting_write_landing(
            &state,
            42,
            FittingWriteKind::Save,
            &FittingWriteOutcome::Failed {
                class: WriteFailureClass::RateLimited { reset_secs: 42 },
                needs_reauthorize: false,
            },
        );
        assert!(!landing.queue_refresh);
    }

    #[test]
    fn fitting_write_status_wording_matches_the_locked_table() {
        use FittingWriteKind::{Delete, Save};
        // Reauthorize row (either kind).
        assert_eq!(
            fitting_write_status_message(Save, WriteFailureClass::Definitive, true),
            "EVE refused the save: this character has not granted fitting changes. Re-authorize in the Fittings view."
        );
        assert_eq!(
            fitting_write_status_message(Delete, WriteFailureClass::Definitive, true),
            "EVE refused the delete: this character has not granted fitting changes. Re-authorize in the Fittings view."
        );
        // NotSent row (same for both kinds).
        for kind in [Save, Delete] {
            assert_eq!(
                fitting_write_status_message(kind, WriteFailureClass::NotSent, false),
                "Nothing was sent to EVE. Check the connection and try again."
            );
        }
        // Definitive 4xx row.
        assert_eq!(
            fitting_write_status_message(Save, WriteFailureClass::Definitive, false),
            "EVE refused the save and nothing was saved. See the log for details."
        );
        assert_eq!(
            fitting_write_status_message(Delete, WriteFailureClass::Definitive, false),
            "EVE refused the delete and nothing was deleted. See the log for details."
        );
        // AlreadyGone row (delete 404).
        assert_eq!(
            fitting_write_status_message(Delete, WriteFailureClass::AlreadyGone, false),
            "That fitting is already gone from EVE. Refreshing your fitting list..."
        );
        // RateLimited row, {s} = 42 per design section 9.2.
        assert_eq!(
            fitting_write_status_message(
                Save,
                WriteFailureClass::RateLimited { reset_secs: 42 },
                false
            ),
            "EVE is rate-limiting requests. Nothing was saved; wait 42 seconds and try again."
        );
        assert_eq!(
            fitting_write_status_message(
                Delete,
                WriteFailureClass::RateLimited { reset_secs: 42 },
                false
            ),
            "EVE is rate-limiting requests. Nothing was deleted; wait 42 seconds and try again."
        );
        // Unknown row.
        assert_eq!(
            fitting_write_status_message(Save, WriteFailureClass::Unknown, false),
            "The save may or may not have reached EVE. Check the refreshed fitting list before saving again, so you do not create a duplicate."
        );
        assert_eq!(
            fitting_write_status_message(Delete, WriteFailureClass::Unknown, false),
            "The delete may or may not have reached EVE. Check the refreshed fitting list; if the fitting is still there, you can delete it again."
        );
    }

    #[test]
    fn pending_fitting_selection_is_judged_by_first_ok_refresh_only() {
        let pending = Some((42, 4242));
        let contains = Ok(vec![fitting(4242)]);
        let (keep, select) = apply_pending_fitting_selection(pending, 42, &contains);
        assert_eq!(keep, None, "judged pending is consumed");
        assert_eq!(select, Some(4242), "a contained id is selected");
        let missing = Ok(vec![fitting(1)]);
        let (keep, select) = apply_pending_fitting_selection(pending, 42, &missing);
        assert_eq!(keep, None, "a missing id consumes without selecting");
        assert_eq!(select, None);
        let failed: SectionResult<Vec<CharacterFitting>> = Err(SectionError {
            message: "fittings request failed".to_string(),
            needs_reauthorize: false,
        });
        let (keep, select) = apply_pending_fitting_selection(pending, 42, &failed);
        assert_eq!(
            keep,
            Some((42, 4242)),
            "an Err list keeps the pending value"
        );
        assert_eq!(select, None);
        let (keep, select) = apply_pending_fitting_selection(pending, 7, &contains);
        assert_eq!(
            keep,
            Some((42, 4242)),
            "a refresh for another character ignores the pending value"
        );
        assert_eq!(select, None);
        let (keep, select) = apply_pending_fitting_selection(None, 42, &contains);
        assert_eq!(keep, None);
        assert_eq!(select, None);
    }

    #[test]
    fn view_key_hints_keep_digits_and_give_exploration_e() {
        assert_eq!(view_key_hint(View::Dashboard), "1");
        assert_eq!(view_key_hint(View::Fittings), "9");
        assert_eq!(view_key_hint(View::Settings), "0");
        assert_eq!(view_key_hint(View::Exploration), "E");
        let mut hints: Vec<&str> = View::ALL.iter().map(|v| view_key_hint(*v)).collect();
        assert_eq!(hints.len(), 11);
        hints.sort_unstable();
        hints.dedup();
        assert_eq!(hints.len(), 11, "every view hint is unique");
    }

    #[test]
    fn startup_view_labels_round_trip_including_exploration() {
        for view in View::ALL {
            assert_eq!(view_for_startup_label(view.label()), view);
        }
        assert_eq!(view_for_startup_label("Exploration"), View::Exploration);
        // A label saved by a newer build, or garbage, falls back.
        assert_eq!(view_for_startup_label("No Such View"), View::Dashboard);
        assert_eq!(view_for_startup_label(""), View::Dashboard);
    }

    #[test]
    fn exploration_startup_load_is_ready_or_fixed_error_sentence() {
        match exploration_load_state(ExplorationRef::load_bundled()) {
            LoadState::Ready(data) => {
                assert_eq!(data.reference.types.len(), 130);
                assert_eq!(data.reference.systems.len(), 2631);
                assert_eq!(data.reference.effects.len(), 36);
                assert_eq!(data.reference.statics.len(), 0);
                assert_eq!(data.reference.manifest.sde_build, 3503375);
            }
            _ => panic!("bundled exploration reference must load"),
        }
        let failed = exploration_load_state(ExplorationRef::from_json("{not json"));
        match failed {
            LoadState::Error(message) => {
                assert_eq!(message, crate::ui::exploration::EXPLORATION_ERROR)
            }
            _ => panic!("malformed bundled data must be the whole-view error state"),
        }
    }

    #[test]
    fn fitting_types_startup_load_is_catalogue_or_none() {
        let loaded = fitting_types_load(FittingTypes::load_bundled())
            .expect("bundled fitting types must load");
        assert!(loaded.type_count() > 20_000);
        // A failed load stores None so the panel shows its fixed
        // catalogue-unavailable sentence; never an empty catalogue.
        assert!(fitting_types_load(FittingTypes::from_json("{not json")).is_none());
    }
}
