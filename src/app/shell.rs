//! egui application shell: character rail, view switcher, top bar,
//! keyboard-first navigation, and per-second repaints for countdowns.

use std::collections::{HashMap, HashSet};
use std::sync::mpsc::{Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use super::state::{
    ship_display_name, summary_location_name, AppState, AssetsData, AuthState, BlueprintsData,
    CharacterDetailData, CharacterOrdersData, CharacterSummary, ExplorationData,
    FittingWriteInFlight, FittingWriteKind, FittingWriteOutcome, FittingWriteRequest, FittingsData,
    IndustryData, IndustryJobsData, LoadState, MarketData, MarketSelection, PlanetSelection,
    PlanetaryData, PortraitState, PublicOrdersData, SectionError, SectionResult,
    SelectedColonyDetail, SkillsData, StepUpRequest, View, WalletData,
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
use crate::names::industry_ref::IndustryRef;
use crate::names::planet_schematics::PlanetSchematicsRef;
use crate::names::resolver::{
    is_displayable_name, is_structure_id, resolve_names_resilient, structure_lookup_batch,
    NameResolver,
};
use crate::names::sde::Sde;
use crate::portraits::{
    ImageKind, PortraitError, PortraitService, LOGO_SIZE, PORTRAIT_SIZE, TYPE_ICON_SIZE,
};
use crate::skills::plans::{apply_demo_action, DemoApplyOutcome, SkillPlan, SkillPlanAction};
use crate::storage::db;
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
    /// Portrait fetch/cache service: public image-service client,
    /// on-disk cache under the app cache directory, and the one
    /// semaphore bounding in-flight portraits. Construction performs
    /// no network or disk I/O.
    pub portraits: Arc<PortraitService>,
}

impl Backends {
    /// Open the persistent SQLite database, token store, JWT verifier,
    /// ESI client, and portrait service for live mode. Shared between
    /// startup and runtime transitions out of `--demo`.
    pub fn open_live() -> Option<Self> {
        match db::open_db(&db::db_path()) {
            Ok(conn) => {
                tracing::info!(
                    "[DB] startup database open ok path={}",
                    db::db_path().display()
                );
                let token_store = Arc::new(TokenStore::new(db::app_data_dir()));
                let jwt_verifier = match JwtVerifier::new() {
                    Ok(verifier) => Some(Arc::new(verifier)),
                    Err(e) => {
                        tracing::warn!("[AUTH] JWT verifier construction failed: {}", e);
                        None
                    }
                };
                let attach_verifier = |client: EsiClient| match &jwt_verifier {
                    Some(verifier) => client.with_jwt_verifier(verifier.clone()),
                    None => client,
                };
                let portraits = Arc::new(PortraitService::new(db::app_cache_dir()));
                let esi = match EsiClient::new() {
                    Ok(client) => client.with_token_store(token_store.clone()),
                    Err(e) => {
                        tracing::warn!("[ESI] client construction failed: {}", e);
                        EsiClient::default().with_token_store(token_store.clone())
                    }
                };
                Some(Self {
                    esi: Arc::new(attach_verifier(esi)),
                    token_store,
                    db: Arc::new(Mutex::new(conn)),
                    jwt_verifier,
                    portraits,
                })
            }
            Err(e) => {
                tracing::warn!("[DB] startup database open failed: {}", e);
                None
            }
        }
    }
}

#[derive(Clone)]
struct BackendSender {
    tx: Sender<BackendMsg>,
    ctx: Arc<Mutex<Option<egui::Context>>>,
}

impl BackendSender {
    fn new(tx: Sender<BackendMsg>) -> Self {
        Self {
            tx,
            ctx: Arc::new(Mutex::new(None)),
        }
    }

    fn attach_ctx(&self, ctx: egui::Context) {
        if let Ok(mut guard) = self.ctx.lock() {
            *guard = Some(ctx);
        }
    }

    fn attach_ctx_if_unset(&self, ctx: &egui::Context) {
        if let Ok(mut guard) = self.ctx.lock() {
            if guard.is_none() {
                *guard = Some(ctx.clone());
            }
        }
    }

    fn request_repaint(&self) {
        if let Ok(guard) = self.ctx.lock() {
            if let Some(ctx) = guard.as_ref() {
                ctx.request_repaint();
            }
        }
    }

    fn send(&self, msg: BackendMsg) {
        if self.tx.send(msg).is_ok() {
            self.request_repaint();
        }
    }
}

enum BackendMsg {
    Refreshed {
        generation: u64,
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
        generation: u64,
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
        rejected: Vec<i64>,
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
    PortraitFetched {
        kind: ImageKind,
        id: i64,
        image: Result<Arc<image::DynamicImage>, PortraitError>,
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
    pub industry_data: Option<Arc<IndustryRef>>,
    pub planet_schematics: Option<Arc<PlanetSchematicsRef>>,
    pub resolver: NameResolver,
    pub log_buffer: Arc<Mutex<Vec<String>>>,
    runtime: Option<tokio::runtime::Runtime>,
    backends: Option<Backends>,
    demo_bundle: Option<DemoBundle>,
    last_active_id: Option<i64>,
    /// Demo flag as of the last drain: demo entry/exit can happen
    /// inside a view (`seed_demo_state`, the settings toggle), so
    /// the shell detects the transition here and reloads skill
    /// plans from the destination mode's source (design section
    /// 11.1 call point 3) even when the active id did not change.
    last_demo_mode: bool,
    demo_in_memory_backends: bool,
    refresh_generation: HashMap<i64, u64>,
    tx: BackendSender,
    rx: Receiver<BackendMsg>,
    demo_names_loaded: bool,
    persisted_startup_view: Option<String>,
    /// Handle to an in-flight EVE SSO login or step-up callback task so demo
    /// entry can abort it promptly and release `127.0.0.1:54321`.
    auth_task: Option<tokio::task::JoinHandle<()>>,
    /// Uploaded portrait textures, one per character with a Ready
    /// portrait. A `TextureHandle` must outlive the frame that
    /// created it, so this cache lives on the app (the view layer)
    /// and is passed into the character views each frame.
    pub portrait_textures: ui::portraits::PortraitImageCache,
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

/// Why a confirmed fitting write must not start (write design
/// section 7.2 refusal table). Pure so the refusal order — and
/// with it single-flight and zero-HTTP-before-scope — is
/// table-testable instead of inspection-only.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum FittingWriteRefusal {
    Demo,
    AuthBusy,
    FlightActive,
    UnknownCharacter,
    NotActive,
    BackendsMissing,
    ScopeAbsent,
}

impl FittingWriteRefusal {
    /// The exact status line the refusal shows. These are the
    /// design's locked strings; the view never words them itself.
    fn status_message(&self) -> &'static str {
        match self {
            FittingWriteRefusal::Demo => {
                "Demo mode uses sample data. Saving or deleting fittings in EVE is disabled."
            }
            FittingWriteRefusal::AuthBusy => {
                "Finish sign-in in your browser before changing fittings in EVE."
            }
            FittingWriteRefusal::FlightActive => {
                "A fitting change is already in progress. Wait for it to finish."
            }
            FittingWriteRefusal::UnknownCharacter => {
                "That character is no longer in Mimir. Nothing was sent to EVE."
            }
            FittingWriteRefusal::NotActive => {
                "The active character changed. Nothing was sent to EVE."
            }
            FittingWriteRefusal::BackendsMissing => {
                "Fitting changes are unavailable: live backends not wired."
            }
            FittingWriteRefusal::ScopeAbsent => {
                "Saving and deleting fittings needs one more EVE permission. Re-authorize in the Fittings view."
            }
        }
    }
}

/// Inputs to the refusal decision, captured by the shell before
/// any spawn. `scope_granted` is only consulted after every
/// earlier refusal, so the shell may pass `false` for it whenever
/// the backends (and thus the token-metadata read) are absent.
#[derive(Debug, Clone, Copy)]
struct FittingWriteStart {
    demo: bool,
    auth_busy: bool,
    flight_active: bool,
    character_known: bool,
    is_active: bool,
    backends_wired: bool,
    scope_granted: bool,
}

/// Decide whether a confirmed write may start. Order is the
/// design refusal order: demo, sign-in busy, flight already
/// active, character gone, active character changed, no
/// backends, write scope absent. `None` means start exactly one
/// write. Every `Some` refusal is synchronous: no flight record,
/// no spawn, no HTTP.
fn decide_fitting_write_start(start: FittingWriteStart) -> Option<FittingWriteRefusal> {
    if start.demo {
        return Some(FittingWriteRefusal::Demo);
    }
    if start.auth_busy {
        return Some(FittingWriteRefusal::AuthBusy);
    }
    if start.flight_active {
        return Some(FittingWriteRefusal::FlightActive);
    }
    if !start.character_known {
        return Some(FittingWriteRefusal::UnknownCharacter);
    }
    if !start.is_active {
        return Some(FittingWriteRefusal::NotActive);
    }
    if !start.backends_wired {
        return Some(FittingWriteRefusal::BackendsMissing);
    }
    if !start.scope_granted {
        return Some(FittingWriteRefusal::ScopeAbsent);
    }
    None
}

/// Why portrait fetches must not start (portrait design section
/// 5). Pure so the refusal order — demo first (zero network calls,
/// placeholder states), then missing backends — is table-testable
/// instead of inspection-only.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum PortraitStartRefusal {
    Demo,
    BackendsMissing,
}

/// Decide whether drained portrait requests may spawn. `None` means
/// spawn one task per requested id. In demo mode the queue is
/// drained without spawning, so demo makes zero network calls; with
/// no live backends or runtime the requests become `Failed` so
/// views show the failure placeholder instead of spinning forever.
fn decide_portrait_start(demo: bool, backends_wired: bool) -> Option<PortraitStartRefusal> {
    if demo {
        return Some(PortraitStartRefusal::Demo);
    }
    if !backends_wired {
        return Some(PortraitStartRefusal::BackendsMissing);
    }
    None
}

/// Where skill-plan loads and actions go (skill-plans design
/// section 9). Demo is checked **first**, so the live-database arm
/// is unreachable in demo even when a database is open: demo plan
/// data can never reach the live database. Plans need only the
/// local database, never the network, so `backends_wired` here is
/// `backends.is_some()` — no runtime is involved at any point.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SkillPlanRoute {
    DemoMemory,
    LiveDatabase,
    Unavailable,
}

fn decide_skill_plan_route(demo: bool, backends_wired: bool) -> SkillPlanRoute {
    if demo {
        return SkillPlanRoute::DemoMemory;
    }
    if backends_wired {
        SkillPlanRoute::LiveDatabase
    } else {
        SkillPlanRoute::Unavailable
    }
}

/// Outcome of applying one drained plan action, in the shared
/// vocabulary of storage and the demo applier (design section
/// 11.2 point 4): created id / applied / no longer there.
enum SkillPlanApplyOutcome {
    Created(i64),
    Applied,
    NotFound,
}

/// Repository `bool` in the shared outcome vocabulary: `false`
/// means the plan row was no longer there for that character.
fn bool_outcome(applied: bool) -> SkillPlanApplyOutcome {
    if applied {
        SkillPlanApplyOutcome::Applied
    } else {
        SkillPlanApplyOutcome::NotFound
    }
}

/// Section 8.7 success wording per action kind. No plan name or
/// description ever appears in a status string (section 10).
fn skill_plan_success_status(action: &SkillPlanAction) -> &'static str {
    match action {
        SkillPlanAction::Create { .. } => "Skill plan created.",
        SkillPlanAction::UpdateText { .. } => "Skill plan renamed.",
        SkillPlanAction::DeletePlan { .. } => "Skill plan deleted.",
        SkillPlanAction::ReplaceEntries { .. } => "Skill plan updated.",
    }
}

/// Image landing (portrait design section 5): insert the result
/// under its own `(kind, id)` only when that entity is still known
/// per `AppState::image_id_known`, returning whether it applied.
/// The keyed insert is the whole correctness argument for
/// switched-away characters — a late result writes its own slot
/// and can never paint the active character's image, because the
/// kind is part of the key — while a result for an unknown or
/// no-longer-referenced id is dropped whole (the `Refreshed`
/// summary precedent).
fn apply_portrait_landing(
    state: &mut AppState,
    kind: ImageKind,
    id: i64,
    image: Result<Arc<image::DynamicImage>, PortraitError>,
) -> bool {
    if !state.image_id_known(kind, id) {
        return false;
    }
    match image {
        Ok(image) => {
            state
                .portraits
                .insert((kind, id), PortraitState::Ready(image));
        }
        Err(e) => {
            tracing::warn!(
                "[PORTRAIT] image fetch failed kind={} id={} error={}",
                kind.as_str(),
                id,
                e
            );
            // A slow failed fetch (e.g. from before a remove/re-add)
            // must not overwrite an image that already landed.
            if !matches!(
                state.portraits.get(&(kind, id)),
                Some(PortraitState::Ready(_))
            ) {
                state.portraits.insert((kind, id), PortraitState::Failed);
            }
        }
    }
    true
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
        WriteFailureClass::RateLimited { reset_secs } => {
            // A missing reset header arrives as 0; never tell the
            // user to wait zero seconds.
            let wait = if reset_secs == 0 {
                "wait a few seconds".to_string()
            } else {
                format!("wait {reset_secs} seconds")
            };
            format!(
                "EVE is rate-limiting requests. Nothing was {}; {wait} and try again.",
                match kind {
                    FittingWriteKind::Save => "saved",
                    FittingWriteKind::Delete => "deleted",
                }
            )
        }
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

/// One-time startup load of the bundled industry reaction data
/// (design section 3): success stores the validated catalogue and
/// logs its count once; any failure logs a `[INDUSTRY]` warning
/// and stores `None`, so the reaction block shows its fixed
/// unavailable sentence instead of treating an empty catalogue as
/// valid.
fn industry_load(result: crate::error::AppResult<IndustryRef>) -> Option<Arc<IndustryRef>> {
    match result {
        Ok(catalogue) => {
            tracing::info!(
                "[INDUSTRY] bundled industry data loaded manufacturing={} reactions={}",
                catalogue.manufacturing_blueprint_count(),
                catalogue.reaction_blueprint_count()
            );
            Some(Arc::new(catalogue))
        }
        Err(e) => {
            tracing::warn!("[INDUSTRY] bundled industry data failed to load: {}", e);
            None
        }
    }
}

/// One-time startup load of the bundled planet schematics
/// (pi-schematics design section 5): success stores the validated
/// catalogue and logs its count once; any failure logs a `[PI]`
/// warning and stores `None`, so any colony with factory pins shows
/// the fixed unavailable sentence instead of treating an empty
/// catalogue as valid.
fn planet_schematics_load(
    result: crate::error::AppResult<PlanetSchematicsRef>,
) -> Option<Arc<PlanetSchematicsRef>> {
    match result {
        Ok(catalogue) => {
            tracing::info!(
                "[PI] bundled planet schematics loaded schematics={}",
                catalogue.schematic_count()
            );
            Some(Arc::new(catalogue))
        }
        Err(e) => {
            tracing::warn!("[PI] bundled planet schematics failed to load: {}", e);
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
        let now = chrono::Utc::now();
        let mut sorted_queue: Vec<&repositories::SkillQueueRow> = queue_rows.iter().collect();
        sorted_queue.sort_by_key(|q| q.queue_position);
        let training = sorted_queue
            .iter()
            .copied()
            .find(|q| match q.finish_date.as_deref() {
                None => true,
                Some(raw) => ui::widgets::parse_esi_date(raw)
                    .map(|dt| dt > now)
                    .unwrap_or(false),
            })
            .or_else(|| sorted_queue.first().copied());
        state.summaries.insert(
            character_id,
            CharacterSummary {
                balance: Some(balance),
                training_skill_name: training.map(|q| sde.skill_name(q.skill_id)),
                training_finish_date: training.and_then(|q| q.finish_date.clone()),
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
        let industry_data = industry_load(IndustryRef::load_bundled());
        let planet_schematics = planet_schematics_load(PlanetSchematicsRef::load_bundled());
        let (raw_tx, rx) = std::sync::mpsc::channel();
        let tx = BackendSender::new(raw_tx);
        let demo_in_memory_backends =
            demo && backends.as_ref().is_some_and(|b| b.jwt_verifier.is_none());
        let mut state = AppState::new(demo);
        // Bundled offline reference, loaded exactly once (design
        // section 9): identical in demo and live modes, never
        // refetched, and independent of characters and network.
        state.exploration = exploration_load_state(ExplorationRef::load_bundled());
        // Bundled skill catalogue ids as a fetch-authorization
        // source (skill-icons design section 4): installed once
        // with the SDE; an SDE that failed to load installs an
        // empty set and authorizes nothing.
        state.install_skill_catalogue_type_ids(&sde);
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
                        Ok(mut rows) => {
                            tracing::info!("[CHAR] loaded {} stored characters", rows.len());
                            let had_explicit_active = rows.iter().any(|r| r.is_active);
                            let active = rows
                                .iter()
                                .find(|r| r.is_active)
                                .or_else(|| rows.first())
                                .map(|r| r.character_id);
                            for c in &mut rows {
                                c.is_active = Some(c.character_id) == active;
                            }
                            if let Some(active_id) = active {
                                if !had_explicit_active {
                                    tracing::info!(
                                        "[CHAR] defaulting active character on live startup character_id={}",
                                        active_id
                                    );
                                    let _ = repositories::set_active_character(&conn, active_id);
                                }
                            }
                            state.active_character_id = active;
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
            industry_data,
            planet_schematics,
            resolver,
            log_buffer,
            runtime,
            backends,
            demo_bundle,
            last_active_id,
            last_demo_mode: demo,
            demo_in_memory_backends,
            refresh_generation: HashMap::new(),
            tx,
            rx,
            demo_names_loaded: false,
            persisted_startup_view,
            auth_task: None,
            portrait_textures: ui::portraits::PortraitImageCache::new(),
        };
        app.ensure_demo_names();
        // Skill plans are local data: present before first render,
        // offline included (design section 11.1 call point 1; the
        // live path already ran `load_cached_state` above and the
        // demo path already seeded its characters).
        app.load_skill_plans_into_state();
        if !demo && app.state.active_character_id.is_some() {
            app.state.request_refresh("startup");
        }
        app
    }

    /// Attach the egui context so background workers can wake the UI thread
    /// as soon as async messages arrive.
    pub fn attach_egui_ctx(&self, ctx: egui::Context) {
        self.tx.attach_ctx(ctx);
    }

    /// Override the active view from CLI startup options (`--view`).
    pub fn apply_initial_view(&mut self, view: View) {
        tracing::info!(
            "[STARTUP] CLI --view override applied view={}",
            view.label()
        );
        self.state.view = view;
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

    fn is_ship_internal_flag(flag: &str) -> bool {
        flag.starts_with("HiSlot")
            || flag.starts_with("MedSlot")
            || flag.starts_with("LoSlot")
            || flag.starts_with("RigSlot")
            || flag.starts_with("SubSystemSlot")
            || flag.starts_with("ServiceSlot")
            || flag.starts_with("FighterTube")
            || flag.starts_with("Specialized")
            || matches!(
                flag,
                "DroneBay"
                    | "FighterBay"
                    | "Cargo"
                    | "FleetHangar"
                    | "ShipHangar"
                    | "FrigateEscapeBay"
                    | "QuafeBay"
                    | "CorpseBay"
                    | "BoosterBay"
                    | "Implant"
            )
    }

    /// Collect public universe IDs and player-structure location IDs visible
    /// in loaded state, skipping asset/blueprint container `item_id` references.
    fn collect_live_name_ids(
        state: &AppState,
        planet_schematics: Option<&PlanetSchematicsRef>,
    ) -> (Vec<i64>, Vec<i64>) {
        let mut ids: Vec<i64> = Vec::new();
        let mut structure_ids: Vec<i64> = Vec::new();
        for c in &state.characters {
            ids.push(c.corporation_id);
            ids.extend(c.alliance_id);
        }
        if let LoadState::Ready(info) = &state.character_detail {
            ids.push(info.corporation_id);
            ids.extend(info.alliance_id);
        }
        if let LoadState::Ready(wallet) = &state.wallet {
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
        let mut asset_item_ids: HashSet<i64> = HashSet::new();
        if let LoadState::Ready(assets) = &state.assets {
            asset_item_ids.extend(assets.items.iter().map(|item| item.item_id));
        }
        if let LoadState::Ready(bundle) = &state.industry {
            if let Ok(blueprints_data) = &bundle.blueprints {
                asset_item_ids.extend(blueprints_data.blueprints.iter().map(|bp| bp.item_id));
            }
        }
        if let LoadState::Ready(bundle) = &state.character_details {
            if let Ok(ship) = &bundle.ship {
                if ship.ship_item_id > 0 {
                    asset_item_ids.insert(ship.ship_item_id);
                }
            }
        }
        if let LoadState::Ready(assets) = &state.assets {
            for item in &assets.items {
                ids.push(item.type_id);
                // Live ESI puts docked Upwell structure assets under
                // `location_type == "item"` with `location_flag == "Hangar"` /
                // `"Deliveries"` / etc., so only skip container item IDs or
                // ship-internal fitted/cargo flags.
                if asset_item_ids.contains(&item.location_id)
                    || (item.location_type == "item"
                        && Self::is_ship_internal_flag(&item.location_flag))
                {
                    continue;
                }
                if is_structure_id(item.location_id) {
                    structure_ids.push(item.location_id);
                } else {
                    ids.push(item.location_id);
                }
            }
        }
        if let LoadState::Ready(bundle) = &state.character_details {
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
        if let Some(type_id) = state.market_selected_type_id {
            ids.push(type_id);
        }
        if let LoadState::Ready(bundle) = &state.market {
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
        if let LoadState::Ready(bundle) = &state.industry {
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
                    if asset_item_ids.contains(&blueprint.location_id)
                        || Self::is_ship_internal_flag(&blueprint.location_flag)
                    {
                        continue;
                    }
                    if is_structure_id(blueprint.location_id) {
                        structure_ids.push(blueprint.location_id);
                    } else {
                        ids.push(blueprint.location_id);
                    }
                }
            }
        }
        if let LoadState::Ready(bundle) = &state.planetary {
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
                        if let (Some(schematic_id), Some(schematics)) =
                            (pin.schematic_id, planet_schematics)
                        {
                            if let Some(schematic) = schematics.schematic(schematic_id) {
                                ids.push(schematic.output.type_id);
                                ids.extend(schematic.inputs.iter().map(|input| input.type_id));
                            }
                        }
                    }
                }
            }
        }
        if let LoadState::Ready(bundle) = &state.fittings {
            if let Ok(fittings) = &bundle.fittings {
                for fitting in fittings {
                    ids.push(fitting.ship_type_id);
                    for item in &fitting.items {
                        ids.push(item.type_id);
                    }
                }
            }
        }
        (ids, structure_ids)
    }

    /// Resolve names for IDs visible in live state (corporations, wallet
    /// counterparties, items, stations) so views show names, not unknowns.
    /// Structure-class IDs are routed to the bounded authenticated pass
    /// below: `/universe/names/` cannot resolve them.
    fn schedule_name_resolution(&mut self) {
        if self.state.demo {
            return;
        }
        let (ids, structure_ids) =
            Self::collect_live_name_ids(&self.state, self.planet_schematics.as_deref());
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
                let (names, rejected, _fatal) = resolve_names_resilient(&esi, &missing).await;
                if !names.is_empty() || !rejected.is_empty() {
                    tx.send(BackendMsg::NamesResolved { names, rejected });
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
                        tx.send(BackendMsg::StructuresResolved {
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
            let rows: Vec<repositories::UniverseNameRow> = names
                .iter()
                .filter(|n| is_displayable_name(&n.name))
                .map(|n| repositories::UniverseNameRow {
                    id: n.id,
                    name: n.name.clone(),
                    category: n.category.clone(),
                })
                .collect();
            if !rows.is_empty() {
                if let Ok(conn) = b.db.lock() {
                    let _ = repositories::upsert_universe_names(&conn, &rows);
                }
            }
        }
    }

    fn drain_requests(&mut self) {
        self.ensure_demo_bundle();
        while let Ok(msg) = self.rx.try_recv() {
            match msg {
                BackendMsg::Refreshed {
                    generation,
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
                    if self.state.demo
                        || self.refresh_generation.get(&character_id).copied() != Some(generation)
                    {
                        tracing::warn!(
                            "[ESI] ignoring stale refresh result character_id={} generation={}",
                            character_id,
                            generation
                        );
                        continue;
                    }
                    tracing::info!("[ESI] refresh complete character_id={}", character_id);
                    // Update the roster row's public corp/alliance first so
                    // Dashboard, Characters, and schedule_name_resolution see
                    // real IDs immediately (not just after an app restart).
                    let was_in_roster = if let Some(existing) = self
                        .state
                        .characters
                        .iter_mut()
                        .find(|c| c.character_id == character_id)
                    {
                        if !info.name.is_empty() {
                            existing.name = info.name.clone();
                        }
                        existing.corporation_id = info.corporation_id;
                        existing.alliance_id = info.alliance_id;
                        tracing::debug!(
                            "[CHAR] updated roster corp/alliance character_id={} corp_id={} has_alliance={}",
                            character_id,
                            info.corporation_id,
                            info.alliance_id.is_some()
                        );
                        true
                    } else {
                        false
                    };
                    // A refresh landing after its character was removed
                    // must not resurrect that character's summary (the
                    // dashboard combined total sums every summary value).
                    // Summaries for still-present inactive characters are
                    // keyed and safe to keep.
                    if was_in_roster {
                        let training = crate::ui::skills::active_or_first_queue_item(
                            &skills.queue,
                            chrono::Utc::now(),
                        );
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
                        if was_in_roster {
                            self.schedule_name_resolution();
                        }
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
                                .filter(|d| {
                                    d.selection.character_id == character_id
                                        && Some(d.selection.planet_id)
                                            == self.state.planetary_selected_planet_id
                                })
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
                BackendMsg::NamesResolved { names, rejected } => {
                    if self.state.demo {
                        tracing::warn!("[ESI] dropping live resolved names in demo mode");
                        continue;
                    }
                    if !rejected.is_empty() {
                        tracing::info!(
                            "[ESI] marking {} unresolvable universe ids",
                            rejected.len()
                        );
                        self.resolver.mark_unresolved(&rejected);
                    }
                    tracing::info!("[ESI] resolved {} universe names", names.len());
                    self.apply_landed_names(&names);
                }
                BackendMsg::StructuresResolved {
                    character_id,
                    names,
                    denied,
                } => {
                    if self.state.demo {
                        tracing::warn!(
                            "[ESI] dropping live structure names in demo mode character_id={}",
                            character_id
                        );
                        continue;
                    }
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
                    generation,
                    character_id,
                    message,
                } => {
                    if self.state.demo
                        || self.refresh_generation.get(&character_id).copied() != Some(generation)
                    {
                        tracing::warn!(
                            "[ESI] ignoring stale refresh failure character_id={} generation={}",
                            character_id,
                            generation
                        );
                        continue;
                    }
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
                    self.auth_task = None;
                    if self.state.demo {
                        tracing::warn!(
                            "[AUTH] ignoring live login completion in demo mode character_id={}",
                            row.character_id
                        );
                        self.state.auth = AuthState::Idle;
                        continue;
                    }
                    tracing::info!("[AUTH] login complete character_id={}", row.character_id);
                    self.state.auth = AuthState::Success;
                    let id = row.character_id;
                    if let Some(existing) = self
                        .state
                        .characters
                        .iter_mut()
                        .find(|c| c.character_id == id)
                    {
                        if !row.name.is_empty() && row.name != "Unknown Item" {
                            existing.name = row.name;
                        }
                        if row.corporation_id > 0 {
                            existing.corporation_id = row.corporation_id;
                        }
                        if row.alliance_id.is_some() {
                            existing.alliance_id = row.alliance_id;
                        }
                    } else {
                        self.state.characters.push(row);
                    }
                    self.state.set_active_character(id);
                    self.state.status_message = "Signed in. Refreshing...".to_string();
                    self.state.request_refresh("post-login");
                }
                BackendMsg::StepUpLoggedIn { character_id } => {
                    self.auth_task = None;
                    if self.state.demo {
                        tracing::warn!(
                            "[AUTH] ignoring live step-up completion in demo mode character_id={}",
                            character_id
                        );
                        self.state.auth = AuthState::Idle;
                        continue;
                    }
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
                    if self.state.demo {
                        tracing::warn!("[MARKET] dropping live market result in demo mode");
                        continue;
                    }
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
                    if self.state.demo {
                        tracing::warn!("[PI] dropping live colony detail result in demo mode");
                        continue;
                    }
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
                    if self.state.demo {
                        tracing::warn!("[MARKET] dropping live item-name lookup in demo mode");
                        continue;
                    }
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
                    if self.state.demo {
                        tracing::warn!(
                            "[FITTING] dropping live fitting write result in demo mode character_id={} kind={}",
                            character_id,
                            kind.label()
                        );
                        continue;
                    }
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
                    self.auth_task = None;
                    if self.state.demo {
                        tracing::warn!("[AUTH] ignoring live login failure in demo mode");
                        self.state.auth = AuthState::Idle;
                        continue;
                    }
                    tracing::warn!("[AUTH] login failed: {}", message);
                    self.state.auth = AuthState::Error;
                    self.state.status_message = format!("Sign-in failed: {message}");
                }
                BackendMsg::PortraitFetched { kind, id, image } => {
                    if self.state.demo {
                        tracing::warn!(
                            "[PORTRAIT] dropping live image fetch in demo mode kind={} id={}",
                            kind.as_str(),
                            id
                        );
                        continue;
                    }
                    if apply_portrait_landing(&mut self.state, kind, id, image) {
                        tracing::info!("[PORTRAIT] image landed kind={} id={}", kind.as_str(), id);
                    } else {
                        tracing::warn!(
                            "[PORTRAIT] dropping image for unreferenced kind={} id={}",
                            kind.as_str(),
                            id
                        );
                    }
                }
            }
        }
        // Drain logout/delete FIRST so any active-character promotion runs
        // through the mode/active-character transition logic below in the
        // same frame rather than stranding views on Loading.
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
        // Demo entry/exit runs BEFORE `active_id_changed` so exiting demo
        // syncs `last_active_id` and never leaks a bogus character-switch
        // refresh or stale market fetch into live mode.
        let mut demo_mode_changed = false;
        if self.state.demo != self.last_demo_mode {
            demo_mode_changed = true;
            if let Some(handle) = self.auth_task.take() {
                tracing::info!("[AUTH] aborting in-flight sign-in task on demo mode change");
                handle.abort();
                self.state.auth = AuthState::Idle;
            }
            let exiting_demo = self.last_demo_mode && !self.state.demo;
            self.last_demo_mode = self.state.demo;
            if exiting_demo {
                self.state.clear_for_demo_exit();
                if self.demo_in_memory_backends {
                    self.backends = Backends::open_live();
                    self.demo_in_memory_backends = false;
                }
                self.resolver = NameResolver::new();
                self.demo_names_loaded = false;
                if let Some(b) = &self.backends {
                    self.resolver.attach(b.esi.clone(), b.db.clone());
                    if let Ok(conn) = b.db.lock() {
                        match self.resolver.hydrate_from_db(&conn) {
                            Ok(n) => tracing::info!(
                                "[ESI] hydrated {} cached universe names on demo exit",
                                n
                            ),
                            Err(e) => {
                                tracing::warn!("[ESI] name hydrate on demo exit failed: {}", e);
                            }
                        }
                        match repositories::get_setting(&conn, "startup_view") {
                            Ok(Some(saved)) => {
                                self.persisted_startup_view = Some(saved.clone());
                                self.state.startup_view = view_for_startup_label(&saved);
                            }
                            Ok(None) => {
                                self.persisted_startup_view =
                                    Some(View::Dashboard.label().to_string());
                                self.state.startup_view = View::Dashboard;
                            }
                            Err(_) => {}
                        }
                        match repositories::list_characters(&conn) {
                            Ok(rows) => {
                                tracing::info!(
                                    "[CHAR] reloaded {} stored characters after demo exit",
                                    rows.len()
                                );
                                let active = rows
                                    .iter()
                                    .find(|r| r.is_active)
                                    .or_else(|| rows.first())
                                    .map(|r| r.character_id);
                                self.state.characters = rows;
                                self.state.active_character_id = active;
                                for c in &mut self.state.characters {
                                    c.is_active = Some(c.character_id) == active;
                                }
                                if let Some(active_id) = active {
                                    load_cached_state(&conn, &self.sde, &mut self.state, active_id);
                                    self.state.request_refresh("demo-exit");
                                }
                            }
                            Err(e) => {
                                tracing::warn!("[CHAR] list_characters on demo exit failed: {}", e);
                            }
                        }
                    }
                }
                self.last_active_id = self.state.active_character_id;
                self.load_skill_plans_into_state();
            } else {
                self.resolver = NameResolver::new();
                self.demo_names_loaded = false;
                self.ensure_demo_names();
                self.load_skill_plans_into_state();
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
                self.load_skill_plans_into_state();
            } else {
                self.resolver.forget_unresolved_structures();
                if let Some(id) = self.state.active_character_id {
                    if let Some(backends) = self.backends.as_ref() {
                        if let Ok(conn) = backends.db.lock() {
                            let _ = repositories::set_active_character(&conn, id);
                            load_cached_state(&conn, &self.sde, &mut self.state, id);
                        }
                    }
                    self.state.request_refresh("character-switch");
                    if self.state.market_selected_type_id.is_some() {
                        tracing::debug!("[MARKET] market refetch queued after character switch");
                        self.state.market_fetch_requested = true;
                    }
                }
                self.load_skill_plans_into_state();
            }
        } else if demo_mode_changed && self.state.demo {
            self.load_skill_plans_into_state();
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
        if let Some(action) = self.state.skill_plan_action.take() {
            self.drain_skill_plan_action(action);
        }
        if !self.state.portrait_requests.is_empty() {
            self.start_portrait_fetches();
        }
    }

    /// Load the active character's skill plans into state
    /// (skill-plans design section 11.1). One helper, four call
    /// points: startup, the `last_active_id` change block, demo
    /// entry/exit, and after every drained plan action. Plans are
    /// never part of the refresh persist block and no ESI landing
    /// writes them: what this loads is storage-confirmed truth
    /// (live) or the demo applier's vec (demo), nothing else.
    fn load_skill_plans_into_state(&mut self) {
        let Some(active_id) = self.state.active_character_id else {
            self.state.skill_plans = LoadState::Empty;
            self.state.skill_plans_owner = None;
            return;
        };
        match decide_skill_plan_route(self.state.demo, self.backends.is_some()) {
            SkillPlanRoute::DemoMemory => {
                let plans = self
                    .state
                    .demo_skill_plans
                    .get(&active_id)
                    .cloned()
                    .unwrap_or_default();
                self.set_loaded_skill_plans(active_id, plans);
            }
            SkillPlanRoute::LiveDatabase => {
                let result = match self.backends.as_ref().map(|b| b.db.lock()) {
                    Some(Ok(conn)) => {
                        repositories::list_skill_plans(&conn, active_id).map_err(|e| e.to_string())
                    }
                    _ => Err("database lock unavailable".to_string()),
                };
                match result {
                    Ok(plans) => self.set_loaded_skill_plans(active_id, plans),
                    Err(error) => {
                        // The error is an AppError display string,
                        // never user text (design section 10). The
                        // view renders its own fixed words for this
                        // key; it never sees the storage error.
                        tracing::warn!(
                            "[PLANS] plans load failed character_id={} error={}",
                            active_id,
                            error
                        );
                        self.state.skill_plans =
                            LoadState::Error("skill_plans_unavailable".to_string());
                        self.state.skill_plans_owner = Some(active_id);
                    }
                }
            }
            SkillPlanRoute::Unavailable => {
                // Backend-less shell (tests): emptiness, not error,
                // is that mode's honest state (section 11.1).
                tracing::debug!(
                    "[PLANS] plans load skipped character_id={} reason=unavailable",
                    active_id
                );
                self.state.skill_plans = LoadState::Empty;
                self.state.skill_plans_owner = Some(active_id);
            }
        }
    }

    /// Install a freshly loaded plan list: owner stamped, a
    /// selection the list no longer contains dropped, counts
    /// logged (ids and counts only, design section 10).
    fn set_loaded_skill_plans(&mut self, active_id: i64, plans: Vec<SkillPlan>) {
        let entries: usize = plans.iter().map(|p| p.entries.len()).sum();
        tracing::info!(
            "[PLANS] plans loaded character_id={} plans={} entries={}",
            active_id,
            plans.len(),
            entries
        );
        if let Some(selected) = self.state.selected_skill_plan_id {
            if !plans.iter().any(|p| p.plan_id == selected) {
                self.state.selected_skill_plan_id = None;
            }
        }
        self.state.skill_plans = LoadState::Ready(plans);
        self.state.skill_plans_owner = Some(active_id);
    }

    /// Drain one stamped skill-plan action (design section 11.2):
    /// identity guard, route, apply synchronously (one live
    /// `db.lock()`, or the connection-free demo applier), then
    /// reload so state always shows confirmed data. A failure
    /// leaves `skill_plans` exactly as it was — no reload — so the
    /// screen keeps showing the last confirmed truth, and the
    /// failure reaches the user through the status line, never
    /// only the log.
    fn drain_skill_plan_action(&mut self, action: SkillPlanAction) {
        let (character_id, stamped_plan_id) = match &action {
            SkillPlanAction::Create { character_id, .. } => (*character_id, 0),
            SkillPlanAction::UpdateText {
                character_id,
                plan_id,
                ..
            }
            | SkillPlanAction::DeletePlan {
                character_id,
                plan_id,
            }
            | SkillPlanAction::ReplaceEntries {
                character_id,
                plan_id,
                ..
            } => (*character_id, *plan_id),
        };
        // 1. Identity guard: the user who clicked must still be
        // looking at that character (the fittings landing rule at
        // local scale). No status change on a drop.
        let is_active = self.state.active_character_id == Some(character_id);
        let is_known = self
            .state
            .characters
            .iter()
            .any(|c| c.character_id == character_id);
        if !is_active || !is_known {
            tracing::warn!(
                "[PLANS] action dropped character_id={} reason=not_active",
                character_id
            );
            return;
        }
        // 2+3. Route and apply. No async, no spawn.
        let route = decide_skill_plan_route(self.state.demo, self.backends.is_some());
        let now = chrono::Utc::now().to_rfc3339();
        let (route_label, outcome) = match route {
            SkillPlanRoute::Unavailable => {
                tracing::warn!(
                    "[PLANS] action dropped character_id={} reason=unavailable",
                    character_id
                );
                self.state.status_message =
                    "Skill plan could not be saved. Nothing was changed.".to_string();
                return;
            }
            SkillPlanRoute::DemoMemory => {
                let mut plans = self
                    .state
                    .demo_skill_plans
                    .get(&character_id)
                    .cloned()
                    .unwrap_or_default();
                let outcome =
                    apply_demo_action(&mut plans, &mut self.state.demo_next_plan_id, &action, &now);
                match outcome {
                    DemoApplyOutcome::Created(plan_id) => {
                        self.state.demo_skill_plans.insert(character_id, plans);
                        ("demo", SkillPlanApplyOutcome::Created(plan_id))
                    }
                    DemoApplyOutcome::Applied => {
                        self.state.demo_skill_plans.insert(character_id, plans);
                        ("demo", SkillPlanApplyOutcome::Applied)
                    }
                    DemoApplyOutcome::NotFound => ("demo", SkillPlanApplyOutcome::NotFound),
                    DemoApplyOutcome::Invalid(_) => {
                        // The view validates before stamping, so this
                        // is defense in depth; the carried editor
                        // string is never logged (section 10).
                        tracing::warn!(
                            "[PLANS] action dropped character_id={} reason=invalid",
                            character_id
                        );
                        self.state.status_message =
                            "Skill plan could not be saved. Nothing was changed.".to_string();
                        return;
                    }
                }
            }
            SkillPlanRoute::LiveDatabase => {
                // The lock guard drops at the end of this block, so
                // the reload below can lock again.
                let result: Result<SkillPlanApplyOutcome, String> = {
                    match self.backends.as_ref().map(|b| b.db.lock()) {
                        Some(Ok(conn)) => match &action {
                            SkillPlanAction::Create {
                                name, description, ..
                            } => repositories::create_skill_plan(
                                &conn,
                                character_id,
                                name,
                                description,
                                &now,
                            )
                            .map(SkillPlanApplyOutcome::Created)
                            .map_err(|e| e.to_string()),
                            SkillPlanAction::UpdateText {
                                plan_id,
                                name,
                                description,
                                ..
                            } => repositories::update_skill_plan_text(
                                &conn,
                                character_id,
                                *plan_id,
                                name,
                                description,
                                &now,
                            )
                            .map(bool_outcome)
                            .map_err(|e| e.to_string()),
                            SkillPlanAction::DeletePlan { plan_id, .. } => {
                                repositories::delete_skill_plan(&conn, character_id, *plan_id)
                                    .map(bool_outcome)
                                    .map_err(|e| e.to_string())
                            }
                            SkillPlanAction::ReplaceEntries {
                                plan_id, entries, ..
                            } => repositories::replace_skill_plan_entries(
                                &conn,
                                character_id,
                                *plan_id,
                                entries,
                                &now,
                            )
                            .map(bool_outcome)
                            .map_err(|e| e.to_string()),
                        },
                        _ => Err("database lock unavailable".to_string()),
                    }
                };
                match result {
                    Ok(outcome) => ("live", outcome),
                    Err(error) => {
                        tracing::warn!(
                            "[PLANS] action failed character_id={} error={}",
                            character_id,
                            error
                        );
                        self.state.status_message =
                            "Skill plan could not be saved. Nothing was changed.".to_string();
                        return;
                    }
                }
            }
        };
        // 4. Reload and report.
        match outcome {
            SkillPlanApplyOutcome::Created(plan_id) => {
                self.load_skill_plans_into_state();
                // Only storage (or the demo counter) knows the new
                // id, so selection is set here (section 8.3).
                self.state.selected_skill_plan_id = Some(plan_id);
                self.state.skill_plan_picker_open = false;
                self.state.status_message = skill_plan_success_status(&action).to_string();
                tracing::info!(
                    "[PLANS] action applied route={} character_id={} plan_id={} plans={}",
                    route_label,
                    character_id,
                    plan_id,
                    self.loaded_skill_plan_count()
                );
            }
            SkillPlanApplyOutcome::Applied => {
                self.load_skill_plans_into_state();
                self.state.status_message = skill_plan_success_status(&action).to_string();
                tracing::info!(
                    "[PLANS] action applied route={} character_id={} plan_id={} plans={}",
                    route_label,
                    character_id,
                    stamped_plan_id,
                    self.loaded_skill_plan_count()
                );
            }
            SkillPlanApplyOutcome::NotFound => {
                // State disagreed with storage; storage wins.
                tracing::warn!(
                    "[PLANS] action dropped character_id={} reason=not_found",
                    character_id
                );
                self.state.status_message =
                    "That skill plan is no longer there. Nothing was changed.".to_string();
                self.load_skill_plans_into_state();
            }
        }
    }

    fn loaded_skill_plan_count(&self) -> usize {
        self.state
            .skill_plans
            .as_ready()
            .map(|plans| plans.len())
            .unwrap_or(0)
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

    /// Drain queued image requests (portrait design section 5): one
    /// spawned task per requested `(kind, id)`, each keyed end to
    /// end, bounded app-wide by the service semaphore. Demo mode
    /// never spawns (zero network calls); missing backends or
    /// runtime mark the requests `Failed` so views render the
    /// failure placeholder, not a spinner.
    fn start_portrait_fetches(&mut self) {
        let requests = self.state.take_portrait_requests();
        if requests.is_empty() {
            return;
        }
        let backends_wired = self.backends.is_some() && self.runtime.is_some();
        match decide_portrait_start(self.state.demo, backends_wired) {
            Some(PortraitStartRefusal::Demo) => {
                tracing::debug!(
                    "[PORTRAIT] portrait fetches suppressed in demo mode count={}",
                    requests.len()
                );
            }
            Some(PortraitStartRefusal::BackendsMissing) => {
                tracing::warn!("[PORTRAIT] portrait fetches unavailable: live backends not wired");
                for (kind, id) in requests {
                    self.state
                        .portraits
                        .insert((kind, id), PortraitState::Failed);
                }
            }
            None => {
                let service = self
                    .backends
                    .as_ref()
                    .expect("decide_portrait_start checked wiring")
                    .portraits
                    .clone();
                let runtime = self
                    .runtime
                    .as_ref()
                    .expect("decide_portrait_start checked wiring");
                for (kind, id) in requests {
                    // Re-check the guard at drain time: the queue
                    // may hold a request whose entity stopped being
                    // known (character removed/switched) after it
                    // queued. Skip the fetch; the state entry was
                    // already dropped with its character.
                    if !self.state.image_id_known(kind, id) {
                        tracing::debug!(
                            "[PORTRAIT] image fetch skipped, no longer known kind={} id={}",
                            kind.as_str(),
                            id
                        );
                        continue;
                    }
                    tracing::info!(
                        "[PORTRAIT] image fetch started kind={} id={}",
                        kind.as_str(),
                        id
                    );
                    let service = service.clone();
                    let tx = self.tx.clone();
                    runtime.spawn(async move {
                        let size = match kind {
                            ImageKind::Character => PORTRAIT_SIZE,
                            ImageKind::Corporation | ImageKind::Alliance | ImageKind::Faction => {
                                LOGO_SIZE
                            }
                            ImageKind::Type => TYPE_ICON_SIZE,
                        };
                        let image = service.image(kind, id, size).await;
                        tx.send(BackendMsg::PortraitFetched { kind, id, image });
                    });
                }
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
            tx.send(BackendMsg::MarketFetched {
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
            tx.send(BackendMsg::PlanetaryDetailFetched {
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
            tx.send(BackendMsg::MarketLookupDone {
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
        let generation = {
            let entry = self.refresh_generation.entry(id).or_insert(0);
            *entry = entry.wrapping_add(1);
            *entry
        };
        let esi = backends.esi.clone();
        let db = backends.db.clone();
        let tx = self.tx.clone();
        tracing::info!(
            "[ESI] refresh started character_id={} generation={}",
            id,
            generation
        );
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
                            let mut singleton_ids: Vec<i64> = items
                                .iter()
                                .filter(|a| a.is_singleton)
                                .map(|a| a.item_id)
                                .collect();
                            singleton_ids.sort_unstable();
                            singleton_ids.dedup();
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
                    // cached skills/wallet offline (load_cached_state), unless
                    // the character was deleted while the refresh was in flight.
                    if let Ok(conn) = db.lock() {
                        let existing_active = match repositories::get_character(&conn, id) {
                            Ok(Some(row)) => Some(row.is_active),
                            Ok(None) => None,
                            Err(e) => {
                                tracing::warn!(
                                    "[DB] failed checking character existence before refresh persist character_id={} error={}",
                                    id,
                                    e
                                );
                                None
                            }
                        };
                        if let Some(is_active) = existing_active {
                            let _ = repositories::upsert_character(
                                &conn,
                                &CharacterRow {
                                    character_id: id,
                                    name: info.name.clone(),
                                    corporation_id: info.corporation_id,
                                    alliance_id: info.alliance_id,
                                    is_active,
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
                        } else {
                            tracing::info!(
                                "[DB] skipping refresh persistence for removed character_id={}",
                                id
                            );
                        }
                    }
                    tx.send(BackendMsg::Refreshed {
                        generation,
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
                    tx.send(BackendMsg::RefreshFailed {
                        generation,
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
        if self.state.auth.is_busy() {
            tracing::warn!("[AUTH] sign-in ignored; sign-in already in progress");
            self.state.status_message =
                "Sign-in already in progress; finish it in your browser first.".to_string();
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
        let callback_server = CallbackServer::new();
        if let Err(e) = callback_server.start_sync(runtime.handle()) {
            self.state.auth = AuthState::Error;
            self.state.status_message = format!("Could not start sign-in callback listener: {e}");
            return;
        }
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
        self.auth_task = Some(runtime.spawn(async move {
            let outcome = async {
                let params = callback_server.wait_for_callback().await?;
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
                let mut row = CharacterRow {
                    character_id,
                    name: if claims.name.is_empty() {
                        "Unknown Item".to_string()
                    } else {
                        claims.name.clone()
                    },
                    corporation_id: 0,
                    alliance_id: None,
                    is_active: true,
                };
                if let Ok(conn) = db.lock() {
                    if let Ok(Some(existing)) = repositories::get_character(&conn, character_id) {
                        row.corporation_id = existing.corporation_id;
                        row.alliance_id = existing.alliance_id;
                    }
                    let _ = repositories::set_token_meta(
                        &conn,
                        &TokenMetaRow {
                            character_id,
                            scopes: claims.scp.join(" "),
                            expires_at: claims.exp,
                        },
                    );
                    let _ = repositories::upsert_character(&conn, &row);
                    let _ = repositories::set_active_character(&conn, character_id);
                }
                Ok::<_, crate::AppError>(row)
            }
            .await;
            match outcome {
                Ok(row) => {
                    tx.send(BackendMsg::LoggedIn { row });
                }
                Err(e) => {
                    tx.send(BackendMsg::LoginFailed {
                        message: e.to_string(),
                    });
                }
            }
        }));
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
        let callback_server = CallbackServer::new();
        if let Err(e) = callback_server.start_sync(runtime.handle()) {
            self.state.auth = AuthState::Error;
            self.state.status_message = format!("Could not start sign-in callback listener: {e}");
            return;
        }
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
        self.auth_task = Some(runtime.spawn(async move {
            let outcome = async {
                let params = callback_server.wait_for_callback().await?;
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
                    tx.send(BackendMsg::StepUpLoggedIn { character_id });
                }
                Err(e) => {
                    tx.send(BackendMsg::LoginFailed {
                        message: e.to_string(),
                    });
                }
            }
        }));
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
        // Pre-scope refusals via the pure decision helper (demo is
        // the shell backstop, not the only defense; section 10).
        // scope_granted=true is a placeholder here: the helper
        // consults it only after every refusal decided in this
        // first call, and the token-metadata read below remains
        // the only scope evidence before any HTTP.
        let pre_scope = FittingWriteStart {
            demo: self.state.demo,
            auth_busy: self.state.auth.is_busy(),
            flight_active: self.state.fittings_write_in_flight.is_some(),
            character_known: self
                .state
                .characters
                .iter()
                .any(|c| c.character_id == character_id),
            is_active: self.state.active_character_id == Some(character_id),
            backends_wired: self.backends.is_some() && self.runtime.is_some(),
            scope_granted: true,
        };
        if let Some(refusal) = decide_fitting_write_start(pre_scope) {
            tracing::warn!(
                "[FITTING] fitting write refused character_id={} kind={} refusal={:?}",
                character_id,
                kind_label,
                refusal
            );
            self.state.status_message = refusal.status_message().to_string();
            return;
        }
        let (Some(backends), Some(runtime)) = (self.backends.as_ref(), self.runtime.as_ref())
        else {
            // Unreachable: the decision above already refused when
            // either handle is missing. Kept as a typed unwrap of
            // the two handles, never a panic path.
            tracing::warn!(
                "[FITTING] fitting write refused; backends not wired character_id={} kind={}",
                character_id,
                kind_label
            );
            self.state.status_message = FittingWriteRefusal::BackendsMissing
                .status_message()
                .to_string();
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
        let scope_granted = oauth::missing_scopes(&granted, &wanted).is_empty();
        if let Some(refusal) = decide_fitting_write_start(FittingWriteStart {
            scope_granted,
            ..pre_scope
        }) {
            tracing::info!(
                "[FITTING] fitting write refused; write scope absent character_id={} kind={} refusal={:?}",
                character_id,
                kind_label,
                refusal
            );
            self.state.fittings_write_needs_reauthorize = true;
            self.state.status_message = refusal.status_message().to_string();
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
                    tx.send(BackendMsg::FittingWriteDone {
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
                    tx.send(BackendMsg::FittingWriteDone {
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
        if !self.state.demo {
            if let Some(backends) = self.backends.as_ref() {
                if let Some(runtime) = self.runtime.as_ref() {
                    if let Ok(Some(tokens)) = backends.token_store.load(character_id) {
                        let refresh = tokens.refresh.as_str().to_string();
                        runtime.spawn(async move {
                            let _ = oauth::revoke_token(&refresh).await;
                        });
                    }
                }
                let _ = backends.token_store.delete(character_id);
                if let Ok(conn) = backends.db.lock() {
                    let _ = repositories::delete_character(&conn, character_id);
                }
            }
        }
        self.state.remove_character(character_id);
        self.tx.request_repaint();
    }

    fn delete_character(&mut self, character_id: i64) {
        tracing::info!("[CHAR] delete character_id={}", character_id);
        if !self.state.demo {
            if let Some(backends) = self.backends.as_ref() {
                let _ = backends.token_store.delete(character_id);
                if let Ok(conn) = backends.db.lock() {
                    let _ = repositories::delete_character(&conn, character_id);
                }
            }
        }
        self.state.remove_character(character_id);
        self.tx.request_repaint();
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
        let typing = self.state.text_input_focused || ctx.wants_keyboard_input();
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
            if queue_has_unfinished_skill(&data.queue, chrono::Utc::now()) {
                return true;
            }
        }
        if let LoadState::Ready(bundle) = &self.state.industry {
            if let Ok(jobs_data) = &bundle.jobs {
                if jobs_data
                    .jobs
                    .iter()
                    .any(|job| ui::industry::is_in_progress_status(&job.status))
                {
                    return true;
                }
            }
        }
        if let LoadState::Ready(bundle) = &self.state.planetary {
            if let Some(detail) = &bundle.detail {
                if Some(detail.selection.character_id) == self.state.active_character_id
                    && Some(detail.selection.planet_id) == self.state.planetary_selected_planet_id
                {
                    if let Ok(colony) = &detail.result {
                        return ui::planets::has_active_extractor(&colony.pins, chrono::Utc::now());
                    }
                }
            }
        }
        false
    }

    fn has_pending_work(&self) -> bool {
        !self.state.portrait_requests.is_empty()
            || self.state.refresh_requested
            || self.state.retry_requested
            || self.state.login_requested
            || self.state.stepup_requested.is_some()
            || self.state.logout_requested_id.is_some()
            || self.state.delete_requested_id.is_some()
            || self.state.market_fetch_requested
            || self.state.market_lookup_requested.is_some()
            || self.state.planetary_detail_fetch_requested
            || self.state.fittings_write_requested.is_some()
            || self.state.skill_plan_action.is_some()
            || self.state.demo != self.last_demo_mode
            || self.state.active_character_id != self.last_active_id
    }

    fn persist_startup_view_if_changed(&mut self) {
        // Check both `state.demo` and `last_demo_mode` so unchecking Demo mode
        // mid-frame never flushes a demo-mode `startup_view` into live `mimir.db`
        // before `drain_requests()` reloads the live setting on the next frame.
        if !self.state.demo
            && !self.last_demo_mode
            && self.persisted_startup_view.as_deref() != Some(self.state.startup_view.label())
        {
            if let Some(backends) = self.backends.as_ref() {
                if let Ok(conn) = backends.db.lock() {
                    if repositories::set_setting(
                        &conn,
                        "startup_view",
                        self.state.startup_view.label(),
                    )
                    .is_ok()
                    {
                        let label = self.state.startup_view.label().to_string();
                        tracing::debug!("[UI] persisted startup_view={}", label);
                        self.persisted_startup_view = Some(label);
                    }
                }
            }
        }
    }
}

fn queue_has_unfinished_skill(
    queue: &[crate::esi::models::SkillQueueItem],
    now: chrono::DateTime<chrono::Utc>,
) -> bool {
    queue.iter().any(|item| {
        item.finish_date
            .as_deref()
            .and_then(|d| ui::widgets::seconds_until(d, now))
            .is_some_and(|secs| secs > 0)
    })
}

impl eframe::App for MimirApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.tx.attach_ctx_if_unset(ctx);
        self.drain_requests();
        // Persist startup-view choice only when it actually changed since
        // the last write (settings view edits it); no per-frame DB reads.
        self.persist_startup_view_if_changed();
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

        let bar_frame = egui::Frame::none()
            .fill(ui::theme::BG_PANEL)
            .stroke(egui::Stroke::new(1.0_f32, ui::theme::BORDER_SUBTLE))
            .inner_margin(egui::Margin::symmetric(14.0, 8.0));

        egui::TopBottomPanel::top("top_bar")
            .frame(bar_frame)
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.label(
                        egui::RichText::new("MIMIR")
                            .size(17.0)
                            .strong()
                            .color(ui::theme::ACCENT_CYAN),
                    );
                    if self.state.demo {
                        ui::widgets::badge(ui, "DEMO", ui::theme::WARNING_BG, ui::theme::WARNING);
                    }
                    if self.state.offline {
                        ui::widgets::badge(
                            ui,
                            "OFFLINE",
                            ui::theme::NEGATIVE_BG,
                            ui::theme::NEGATIVE,
                        );
                    }
                    if let Some(active) = self.state.active_character() {
                        ui::widgets::badge(
                            ui,
                            &format!("Active: {}", active.name),
                            ui::theme::BG_CARD_ALT,
                            ui::theme::TEXT_PRIMARY,
                        );
                    }
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        if ui.button("Refresh (Ctrl+R)").clicked() {
                            self.state.request_refresh("top-bar button");
                        }
                        if !self.state.status_message.is_empty() {
                            ui.label(
                                egui::RichText::new(&self.state.status_message)
                                    .size(12.0)
                                    .color(ui::theme::TEXT_SECONDARY),
                            );
                        }
                    });
                });
            });

        let sidebar_frame = egui::Frame::none()
            .fill(ui::theme::BG_PANEL)
            .stroke(egui::Stroke::new(1.0_f32, ui::theme::BORDER_SUBTLE))
            .inner_margin(egui::Margin::symmetric(12.0, 12.0));

        egui::SidePanel::left("character_rail")
            .default_width(210.0)
            .resizable(false)
            .frame(sidebar_frame)
            .show(ctx, |ui| {
                ui.label(
                    egui::RichText::new("CHARACTERS")
                        .size(11.0)
                        .strong()
                        .color(ui::theme::TEXT_MUTED),
                );
                ui.add_space(4.0);
                if self.state.characters.is_empty() {
                    ui.label(
                        egui::RichText::new("No characters yet.").color(ui::theme::TEXT_SECONDARY),
                    );
                    if ui.button("Add character (EVE SSO)").clicked() {
                        tracing::info!("[AUTH] add-character requested from rail");
                        self.state.login_requested = true;
                        self.state.switch_view(View::Characters);
                    }
                    if ui
                        .add_enabled(!self.state.auth.is_busy(), egui::Button::new("Try demo"))
                        .clicked()
                    {
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
                    ui.with_layout(egui::Layout::top_down_justified(egui::Align::LEFT), |ui| {
                        for (id, name) in rows {
                            let selected = self.state.active_character_id == Some(id);
                            if ui.selectable_label(selected, &name).clicked() {
                                self.state.set_active_character(id);
                            }
                        }
                    });
                    ui.add_space(2.0);
                    ui.label(
                        egui::RichText::new("PageUp/PageDown switches character.")
                            .size(11.5)
                            .color(ui::theme::TEXT_MUTED),
                    );
                }
                ui.add_space(6.0);
                ui.separator();
                ui.add_space(4.0);
                ui.label(
                    egui::RichText::new("VIEWS (KEYS 1-9, 0, E)")
                        .size(11.0)
                        .strong()
                        .color(ui::theme::TEXT_MUTED),
                );
                ui.add_space(4.0);
                ui.with_layout(egui::Layout::top_down_justified(egui::Align::LEFT), |ui| {
                    for view in View::ALL.iter() {
                        let selected = self.state.view == *view;
                        if ui
                            .selectable_label(
                                selected,
                                format!("{}  {}", view_key_hint(*view), view.label()),
                            )
                            .clicked()
                        {
                            self.state.switch_view(*view);
                        }
                    }
                });
            });

        let status_frame = egui::Frame::none()
            .fill(ui::theme::BG_PANEL)
            .stroke(egui::Stroke::new(1.0_f32, ui::theme::BORDER_SUBTLE))
            .inner_margin(egui::Margin::symmetric(14.0, 6.0));

        egui::TopBottomPanel::bottom("status_bar")
            .frame(status_frame)
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.label(
                        egui::RichText::new(format!("View: {}", self.state.view.label()))
                            .size(12.0)
                            .color(ui::theme::TEXT_SECONDARY),
                    );
                    ui.label(
                        egui::RichText::new(format!(
                            "Characters: {}",
                            self.state.characters.len()
                        ))
                        .size(12.0)
                        .color(ui::theme::TEXT_SECONDARY),
                    );
                    if self.state.refresh_requested {
                        ui::widgets::badge(
                            ui,
                            "Refresh pending...",
                            ui::theme::ACCENT_BLUE_FILL,
                            ui::theme::ACCENT_CYAN,
                        );
                    }
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        ui.label(
                            egui::RichText::new(
                                "Keys: 1-9, 0, E views  |  Ctrl+R refresh  |  / search  |  PgUp/PgDn character",
                            )
                            .size(11.5)
                            .color(ui::theme::TEXT_MUTED),
                        );
                    });
                });
            });

        let canvas_frame = egui::Frame::none()
            .fill(ui::theme::BG_CANVAS)
            .inner_margin(egui::Margin::same(16.0));

        egui::CentralPanel::default()
            .frame(canvas_frame)
            .show(ctx, |ui| {
                egui::ScrollArea::vertical().show(ui, |ui| match self.state.view {
                    View::Dashboard => ui::dashboard::show(
                        ui,
                        &mut self.state,
                        &self.sde,
                        &self.resolver,
                        &mut self.portrait_textures,
                    ),
                    View::Characters => ui::characters::show(
                        ui,
                        &mut self.state,
                        &self.resolver,
                        &mut self.portrait_textures,
                    ),
                    View::Skills => ui::skills::show(
                        ui,
                        &mut self.state,
                        &self.sde,
                        &mut self.portrait_textures,
                    ),
                    View::Wallet => ui::wallet::show(ui, &mut self.state, &self.resolver),
                    View::Assets => ui::assets::show(
                        ui,
                        &mut self.state,
                        &self.resolver,
                        &mut self.portrait_textures,
                    ),
                    View::Market => ui::market::show(
                        ui,
                        &mut self.state,
                        &self.resolver,
                        &mut self.portrait_textures,
                    ),
                    View::Industry => ui::industry::show(
                        ui,
                        &mut self.state,
                        &self.resolver,
                        self.industry_data.as_deref(),
                        self.fitting_types.as_deref(),
                    ),
                    View::Planets => ui::planets::show(
                        ui,
                        &mut self.state,
                        &self.resolver,
                        self.planet_schematics.as_deref(),
                    ),
                    View::Fittings => ui::fittings::show(
                        ui,
                        &mut self.state,
                        &self.resolver,
                        self.fitting_types.as_deref(),
                        &self.sde,
                        &mut self.portrait_textures,
                    ),
                    View::Settings => ui::settings::show(ui, &mut self.state),
                    View::Exploration => ui::exploration::show(ui, &mut self.state),
                });
            });
        // Persist startup-view edits made inside Settings during this frame and
        // wake egui immediately whenever view rendering or apply_keys queued work
        // after the top-of-frame drain_requests() pass.
        self.persist_startup_view_if_changed();
        if self.has_pending_work() {
            ctx.request_repaint();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::Standing as StandingModel;

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
        // A missing reset header arrives as 0; never "wait 0 seconds".
        assert_eq!(
            fitting_write_status_message(
                Save,
                WriteFailureClass::RateLimited { reset_secs: 0 },
                false
            ),
            "EVE is rate-limiting requests. Nothing was saved; wait a few seconds and try again."
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
    fn fitting_write_start_refusals_follow_design_order() {
        // Every input permissive: the write may start.
        let ready = FittingWriteStart {
            demo: false,
            auth_busy: false,
            flight_active: false,
            character_known: true,
            is_active: true,
            backends_wired: true,
            scope_granted: true,
        };
        assert_eq!(decide_fitting_write_start(ready), None);
        // Each single blocker refuses with its own kind; removing
        // any one guard must fail this table (the reviewer F1
        // mutations: single-flight, scope pre-check, demo).
        let cases: Vec<(FittingWriteStart, FittingWriteRefusal)> = vec![
            (
                FittingWriteStart {
                    demo: true,
                    ..ready
                },
                FittingWriteRefusal::Demo,
            ),
            (
                FittingWriteStart {
                    auth_busy: true,
                    ..ready
                },
                FittingWriteRefusal::AuthBusy,
            ),
            (
                FittingWriteStart {
                    flight_active: true,
                    ..ready
                },
                FittingWriteRefusal::FlightActive,
            ),
            (
                FittingWriteStart {
                    character_known: false,
                    ..ready
                },
                FittingWriteRefusal::UnknownCharacter,
            ),
            (
                FittingWriteStart {
                    is_active: false,
                    ..ready
                },
                FittingWriteRefusal::NotActive,
            ),
            (
                FittingWriteStart {
                    backends_wired: false,
                    ..ready
                },
                FittingWriteRefusal::BackendsMissing,
            ),
            (
                FittingWriteStart {
                    scope_granted: false,
                    ..ready
                },
                FittingWriteRefusal::ScopeAbsent,
            ),
        ];
        for (start, want) in cases {
            assert_eq!(decide_fitting_write_start(start), Some(want));
        }
        // Order: earlier refusals win over later ones, so a demo
        // session with a flight active and no scope still reports
        // the demo refusal, and missing backends outrank the
        // scope (whose evidence needs the backends to exist).
        assert_eq!(
            decide_fitting_write_start(FittingWriteStart {
                demo: true,
                flight_active: true,
                scope_granted: false,
                ..ready
            }),
            Some(FittingWriteRefusal::Demo)
        );
        assert_eq!(
            decide_fitting_write_start(FittingWriteStart {
                backends_wired: false,
                scope_granted: false,
                ..ready
            }),
            Some(FittingWriteRefusal::BackendsMissing)
        );
        // Locked wording pins (independent literals).
        assert_eq!(
            FittingWriteRefusal::Demo.status_message(),
            "Demo mode uses sample data. Saving or deleting fittings in EVE is disabled."
        );
        assert_eq!(
            FittingWriteRefusal::FlightActive.status_message(),
            "A fitting change is already in progress. Wait for it to finish."
        );
        assert_eq!(
            FittingWriteRefusal::ScopeAbsent.status_message(),
            "Saving and deleting fittings needs one more EVE permission. Re-authorize in the Fittings view."
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

    #[test]
    fn industry_startup_load_is_catalogue_or_none() {
        let loaded =
            industry_load(IndustryRef::load_bundled()).expect("bundled industry data must load");
        assert_eq!(loaded.manufacturing_blueprint_count(), 4788);
        assert_eq!(loaded.reaction_blueprint_count(), 112);
        // A failed load stores None so the reaction block shows its
        // fixed unavailable sentence; never an empty catalogue.
        assert!(industry_load(IndustryRef::from_json("{not json")).is_none());
    }

    #[test]
    fn planet_schematics_startup_load_is_catalogue_or_none() {
        let loaded = planet_schematics_load(PlanetSchematicsRef::load_bundled())
            .expect("bundled planet schematics must load");
        assert_eq!(loaded.schematic_count(), 68);
        // A failed load stores None so colonies with factory pins show
        // the fixed unavailable sentence; never an empty catalogue.
        assert!(planet_schematics_load(PlanetSchematicsRef::from_json("{not json")).is_none());
    }

    #[test]
    fn portrait_start_decision_table() {
        use PortraitStartRefusal::*;
        assert_eq!(decide_portrait_start(true, true), Some(Demo));
        // Demo wins even with no backends: zero network calls first.
        assert_eq!(decide_portrait_start(true, false), Some(Demo));
        assert_eq!(decide_portrait_start(false, false), Some(BackendsMissing));
        assert_eq!(decide_portrait_start(false, true), None);
    }

    fn two_character_state() -> AppState {
        let mut state = AppState::new(false);
        state.characters = vec![
            CharacterRow {
                character_id: 1,
                name: "One".to_string(),
                corporation_id: 1000166,
                alliance_id: None,
                is_active: true,
            },
            CharacterRow {
                character_id: 2,
                name: "Two".to_string(),
                corporation_id: 1000166,
                alliance_id: None,
                is_active: false,
            },
        ];
        state.set_active_character(1);
        state
    }

    fn test_image(width: u32, height: u32) -> Arc<image::DynamicImage> {
        Arc::new(image::DynamicImage::new_rgb8(width, height))
    }

    #[test]
    fn portrait_landing_applies_to_a_known_character() {
        let mut state = two_character_state();
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Character,
            1,
            Ok(test_image(8, 8))
        ));
        match state.portrait_state(ImageKind::Character, 1) {
            PortraitState::Ready(image) => {
                assert_eq!(image.width(), 8);
                assert_eq!(image.height(), 8);
            }
            other => panic!("known character must land Ready, got {other:?}"),
        }
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Character,
            2,
            Err(PortraitError::Status(404))
        ));
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 2),
            PortraitState::Failed
        ));
    }

    #[test]
    fn portrait_landing_for_switched_away_character_never_touches_active() {
        let mut state = two_character_state();
        state.set_active_character(2);
        // Late result for character 1 while character 2 is active:
        // it lands in character 1's own slot; character 2's entry
        // stays untouched (no entry, so still NotRequested).
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Character,
            1,
            Ok(test_image(8, 8))
        ));
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 1),
            PortraitState::Ready(_)
        ));
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 2),
            PortraitState::NotRequested
        ));
        assert_eq!(state.active_character_id, Some(2));
    }

    // T20: skill_plan_route_prefers_demo_memory (skill-plans
    // design section 12). The full 2x2, named so a future reorder
    // of the checks fails loudly: demo wins in both demo cells, so
    // the live-database arm is unreachable while demo is on.
    #[test]
    fn skill_plan_route_prefers_demo_memory() {
        assert_eq!(
            decide_skill_plan_route(true, true),
            SkillPlanRoute::DemoMemory
        );
        assert_eq!(
            decide_skill_plan_route(true, false),
            SkillPlanRoute::DemoMemory
        );
        assert_eq!(
            decide_skill_plan_route(false, true),
            SkillPlanRoute::LiveDatabase
        );
        assert_eq!(
            decide_skill_plan_route(false, false),
            SkillPlanRoute::Unavailable
        );
    }

    #[test]
    fn portrait_landing_for_removed_character_drops_whole() {
        let mut state = two_character_state();
        state.remove_character(2);
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Character,
            2,
            Ok(test_image(8, 8))
        ));
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 2),
            PortraitState::NotRequested
        ));
        assert!(!state.portraits.contains_key(&(ImageKind::Character, 2)));
    }

    #[test]
    fn corporation_landing_writes_only_its_slot() {
        let mut state = two_character_state();
        state.set_active_character(2);
        // A corporation landing writes only its own slot: the
        // corporation 1000125 key stays NotRequested and the
        // character keys are untouched. A logo for corporation A
        // never paints under corporation B.
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Corporation,
            1000166,
            Ok(test_image(8, 8))
        ));
        match state.portrait_state(ImageKind::Corporation, 1000166) {
            PortraitState::Ready(image) => {
                assert_eq!(image.width(), 8);
                assert_eq!(image.height(), 8);
            }
            other => panic!("known corporation must land Ready, got {other:?}"),
        }
        assert!(matches!(
            state.portrait_state(ImageKind::Corporation, 1000125),
            PortraitState::NotRequested
        ));
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 1),
            PortraitState::NotRequested
        ));
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 2),
            PortraitState::NotRequested
        ));
    }

    #[test]
    fn landing_with_the_wrong_kind_for_an_id_drops_whole() {
        let mut state = two_character_state();
        // 2 is a character id but no row's corporation; 1000166 is a
        // corporation but not a character.
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Corporation,
            2,
            Ok(test_image(8, 8))
        ));
        assert!(!state.portraits.contains_key(&(ImageKind::Corporation, 2)));
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Character,
            1000166,
            Ok(test_image(8, 8))
        ));
        assert!(!state
            .portraits
            .contains_key(&(ImageKind::Character, 1000166)));
    }

    #[test]
    fn landing_for_an_unreferenced_alliance_drops_whole() {
        let mut state = two_character_state();
        // Every row has alliance_id None, and no detail is loaded.
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Alliance,
            99003581,
            Ok(test_image(8, 8))
        ));
        assert!(!state
            .portraits
            .contains_key(&(ImageKind::Alliance, 99003581)));
        assert!(matches!(
            state.portrait_state(ImageKind::Alliance, 99003581),
            PortraitState::NotRequested
        ));
    }

    #[test]
    fn late_failure_does_not_overwrite_a_ready_logo() {
        let mut state = two_character_state();
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Corporation,
            1000166,
            Ok(test_image(8, 8))
        ));
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Corporation,
            1000166,
            Err(PortraitError::Status(404))
        ));
        assert!(matches!(
            state.portrait_state(ImageKind::Corporation, 1000166),
            PortraitState::Ready(_)
        ));
    }

    /// State whose loaded standings carry one faction entry
    /// (500001); every other detail section is an Err fixture.
    fn standings_state() -> AppState {
        let mut state = two_character_state();
        let err = || SectionError {
            message: "forbidden".to_string(),
            needs_reauthorize: true,
        };
        state.character_details = LoadState::Ready(CharacterDetailData {
            attributes: Err(err()),
            implants: Err(err()),
            clones: Err(err()),
            standings: Ok(vec![StandingModel {
                from_id: 500001,
                from_type: "faction".to_string(),
                standing: 5.0,
            }]),
            location: Err(err()),
            ship: Err(err()),
            online: Err(err()),
        });
        state
    }

    #[test]
    fn standings_landing_applies_then_drops_after_switch() {
        let mut state = standings_state();
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Faction,
            500001,
            Ok(test_image(8, 8))
        ));
        match state.portrait_state(ImageKind::Faction, 500001) {
            PortraitState::Ready(image) => {
                assert_eq!(image.width(), 8);
                assert_eq!(image.height(), 8);
            }
            other => panic!("known faction must land Ready, got {other:?}"),
        }
        // Mid-fetch switch: the bundle resets, so a second
        // landing for the same entity drops whole and writes
        // nothing new.
        state.set_active_character(2);
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Faction,
            500001,
            Ok(test_image(4, 4))
        ));
        match state.portrait_state(ImageKind::Faction, 500001) {
            PortraitState::Ready(image) => {
                assert_eq!(image.width(), 8, "dropped landing must write nothing");
                assert_eq!(image.height(), 8);
            }
            other => panic!("dropped landing must leave the earlier image, got {other:?}"),
        }
    }

    #[test]
    fn standings_landing_rejects_the_wrong_kind() {
        // A faction standing authorizes the faction key only, not
        // the corporation key at the same number.
        let mut state = standings_state();
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Corporation,
            500001,
            Ok(test_image(8, 8))
        ));
        assert!(!state
            .portraits
            .contains_key(&(ImageKind::Corporation, 500001)));
        assert!(matches!(
            state.portrait_state(ImageKind::Corporation, 500001),
            PortraitState::NotRequested
        ));
    }

    fn type_item(type_id: i64) -> crate::esi::models::FittingItem {
        crate::esi::models::FittingItem {
            flag: "Cargo".to_string(),
            quantity: 1,
            type_id,
        }
    }

    fn asset_fixture_state() -> AppState {
        let mut state = two_character_state();
        state.fittings = LoadState::Loading;
        state.assets = LoadState::Ready(AssetsData {
            items: vec![crate::esi::models::AssetItem {
                item_id: 1,
                type_id: 3300,
                quantity: 1,
                location_id: 60003760,
                ..Default::default()
            }],
            custom_names: Default::default(),
        });
        state
    }

    /// Two-character state with the design section 10 fittings
    /// fixture: fitting A (ship 587, items 2048 and 34) and
    /// fitting B (ship 597, item 178).
    fn type_fixture_state() -> AppState {
        let mut state = two_character_state();
        let fitting_a = CharacterFitting {
            fitting_id: 587,
            name: "Fitting".to_string(),
            description: None,
            ship_type_id: 587,
            items: vec![type_item(2048), type_item(34)],
        };
        let fitting_b = CharacterFitting {
            fitting_id: 597,
            name: "Fitting".to_string(),
            description: None,
            ship_type_id: 597,
            items: vec![type_item(178)],
        };
        state.fittings = LoadState::Ready(FittingsData {
            fittings: Ok(vec![fitting_a, fitting_b]),
        });
        state
    }

    #[test]
    fn type_icon_landing_applies_then_drops_after_switch() {
        let mut state = type_fixture_state();
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Type,
            2048,
            Ok(test_image(8, 8))
        ));
        match state.portrait_state(ImageKind::Type, 2048) {
            PortraitState::Ready(image) => {
                assert_eq!(image.width(), 8);
                assert_eq!(image.height(), 8);
            }
            other => panic!("known type must land Ready, got {other:?}"),
        }
        // Mid-fetch switch: the fittings bundle resets, so a
        // second landing for the same type drops whole and
        // writes nothing new.
        state.set_active_character(2);
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Type,
            2048,
            Ok(test_image(4, 4))
        ));
        match state.portrait_state(ImageKind::Type, 2048) {
            PortraitState::Ready(image) => {
                assert_eq!(image.width(), 8, "dropped landing must write nothing");
                assert_eq!(image.height(), 8);
            }
            other => panic!("dropped landing must leave the earlier image, got {other:?}"),
        }
    }

    #[test]
    fn market_type_icon_landing_drops_after_deselect() {
        // X is not in any loaded saved fitting: only the market
        // selection authorizes its type icon.
        let mut state = two_character_state();
        state.set_market_selection(3300, "Type X".to_string());
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Type,
            3300,
            Ok(test_image(8, 8))
        ));
        match state.portrait_state(ImageKind::Type, 3300) {
            PortraitState::Ready(image) => {
                assert_eq!(image.width(), 8);
                assert_eq!(image.height(), 8);
            }
            other => panic!("selected type must land Ready, got {other:?}"),
        }
        // Selecting another item revokes X: a late landing for X
        // drops whole and writes nothing new.
        state.set_market_selection(12345, "Type Y".to_string());
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Type,
            3300,
            Ok(test_image(4, 4))
        ));
        match state.portrait_state(ImageKind::Type, 3300) {
            PortraitState::Ready(image) => {
                assert_eq!(image.width(), 8, "dropped landing must write nothing");
                assert_eq!(image.height(), 8);
            }
            other => panic!("dropped landing must leave the earlier image, got {other:?}"),
        }
    }

    #[test]
    fn asset_type_icon_landing_drops_after_switch() {
        // A (3300) is held as an asset and in no saved fitting:
        // only the loaded assets authorize its type icon.
        let mut state = asset_fixture_state();
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Type,
            3300,
            Ok(test_image(8, 8))
        ));
        match state.portrait_state(ImageKind::Type, 3300) {
            PortraitState::Ready(image) => {
                assert_eq!(image.width(), 8);
                assert_eq!(image.height(), 8);
            }
            other => panic!("held asset type must land Ready, got {other:?}"),
        }
        // Mid-fetch switch: the assets bundle resets to Loading,
        // so a late landing for the same type drops whole and
        // writes nothing new.
        state.set_active_character(2);
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Type,
            3300,
            Ok(test_image(4, 4))
        ));
        match state.portrait_state(ImageKind::Type, 3300) {
            PortraitState::Ready(image) => {
                assert_eq!(image.width(), 8, "dropped landing must write nothing");
                assert_eq!(image.height(), 8);
            }
            other => panic!("dropped landing must leave the earlier image, got {other:?}"),
        }
    }

    #[test]
    fn skill_type_icon_landing_survives_character_switch() {
        // 3300 (Gunnery) is a bundled catalogue skill type only:
        // in no saved fitting, held asset, or market selection,
        // so only the catalogue arm authorizes it — the opposite
        // locked outcome to
        // `asset_type_icon_landing_drops_after_switch`.
        let sde = crate::names::sde::Sde::load_bundled().expect("bundled SDE loads");
        let mut state = two_character_state();
        state.install_skill_catalogue_type_ids(&sde);
        // 999999 is in no catalogue: landing drops whole before
        // and after the switch and writes nothing.
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Type,
            999999,
            Ok(test_image(8, 8))
        ));
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 999999),
            PortraitState::NotRequested
        ));
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 999999)));
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Type,
            3300,
            Ok(test_image(8, 8))
        ));
        match state.portrait_state(ImageKind::Type, 3300) {
            PortraitState::Ready(image) => {
                assert_eq!(image.width(), 8);
                assert_eq!(image.height(), 8);
            }
            other => panic!("catalogue type must land Ready, got {other:?}"),
        }
        // Mid-fetch switch never revokes the static arm, so a
        // late landing still replaces the image.
        state.set_active_character(2);
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Type,
            999999,
            Ok(test_image(4, 4))
        ));
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 999999)));
        assert!(apply_portrait_landing(
            &mut state,
            ImageKind::Type,
            3300,
            Ok(test_image(4, 4))
        ));
        match state.portrait_state(ImageKind::Type, 3300) {
            PortraitState::Ready(image) => {
                assert_eq!(
                    image.width(),
                    4,
                    "landing after switch must replace, not drop"
                );
                assert_eq!(image.height(), 4);
            }
            other => panic!("landing after switch must replace the image, got {other:?}"),
        }
    }

    #[test]
    fn market_type_icon_demo_selection_never_goes_ready() {
        // Demo selection queues normally, but the drain refusal
        // governs: nothing spawns, so the key never becomes Ready.
        let mut state = AppState::new(true);
        state.set_market_selection(3300, "Type X".to_string());
        crate::ui::portraits::ensure_type_icon_requested(&mut state, 3300);
        assert_eq!(
            state.take_portrait_requests(),
            vec![(ImageKind::Type, 3300)]
        );
        assert_eq!(
            decide_portrait_start(true, false),
            Some(PortraitStartRefusal::Demo)
        );
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Loading
        ));
    }

    #[test]
    fn type_id_landing_rejects_the_wrong_kind() {
        // A fitting type id authorizes the type key only, not the
        // corporation key at the same number.
        let mut state = type_fixture_state();
        assert!(!apply_portrait_landing(
            &mut state,
            ImageKind::Corporation,
            2048,
            Ok(test_image(8, 8))
        ));
        assert!(!state
            .portraits
            .contains_key(&(ImageKind::Corporation, 2048)));
        assert!(matches!(
            state.portrait_state(ImageKind::Corporation, 2048),
            PortraitState::NotRequested
        ));
    }

    #[test]
    fn needs_tick_ignores_all_finished_queue() {
        let now = crate::ui::widgets::parse_esi_date("2026-11-21T00:00:00Z").expect("valid date");
        let finished = vec![crate::esi::models::SkillQueueItem {
            skill_id: 3300,
            finished_level: 5,
            queue_position: 0,
            finish_date: Some("2026-11-20T12:00:00Z".to_string()),
            ..Default::default()
        }];
        assert!(!queue_has_unfinished_skill(&finished, now));

        let active = vec![
            finished[0].clone(),
            crate::esi::models::SkillQueueItem {
                skill_id: 3301,
                finished_level: 4,
                queue_position: 1,
                finish_date: Some("2026-11-25T12:00:00Z".to_string()),
                ..Default::default()
            },
        ];
        assert!(queue_has_unfinished_skill(&active, now));
    }

    #[test]
    fn collect_live_name_ids_skips_container_items_and_uses_upwell_threshold() {
        use crate::app::state::AssetsData;
        use crate::esi::models::{AssetItem, CharacterBlueprint, CharacterShip};

        let mut state = AppState::new(false);
        state.characters = vec![CharacterRow {
            character_id: 2_112_625_428,
            name: "Pilot".to_string(),
            corporation_id: 1_000_000_042, // below 1e12, must NOT be treated as a structure
            alliance_id: None,
            is_active: true,
        }];
        let active_ship_id = 1_040_000_000_099;
        let ship_item_id = 1_040_000_000_001;
        let container_item_id = 1_040_000_000_002;
        let real_structure_id = 1_030_000_000_123;
        state.character_details = LoadState::Ready(CharacterDetailData {
            attributes: Ok(Default::default()),
            implants: Ok(Vec::new()),
            clones: Ok(Default::default()),
            standings: Ok(Vec::new()),
            location: Ok(Default::default()),
            ship: Ok(CharacterShip {
                ship_item_id: active_ship_id,
                ship_name: "Active Frigate".to_string(),
                ship_type_id: 587,
            }),
            online: Ok(Default::default()),
        });
        state.assets = LoadState::Ready(AssetsData {
            items: vec![
                AssetItem {
                    item_id: ship_item_id,
                    type_id: 587,
                    quantity: 1,
                    location_id: real_structure_id,
                    // Live ESI uses location_type="item" for items docked in Upwell structures!
                    location_flag: "Hangar".to_string(),
                    location_type: "item".to_string(),
                    is_singleton: true,
                    is_blueprint_copy: None,
                },
                AssetItem {
                    item_id: container_item_id,
                    type_id: 2048,
                    quantity: 1,
                    location_id: ship_item_id,
                    location_flag: "LoSlot0".to_string(),
                    location_type: "item".to_string(),
                    is_singleton: true,
                    is_blueprint_copy: None,
                },
                AssetItem {
                    item_id: 1_040_000_000_003,
                    type_id: 34,
                    quantity: 100,
                    location_id: container_item_id,
                    location_flag: "Cargo".to_string(),
                    // Even if location_type isn't "item", matching parent item_id is skipped.
                    location_type: "other".to_string(),
                    is_singleton: false,
                    is_blueprint_copy: None,
                },
                AssetItem {
                    item_id: 1_040_000_000_005,
                    type_id: 2889,
                    quantity: 1,
                    location_id: active_ship_id,
                    location_flag: "HiSlot0".to_string(),
                    location_type: "item".to_string(),
                    is_singleton: true,
                    is_blueprint_copy: None,
                },
            ],
            custom_names: Default::default(),
        });
        state.industry = LoadState::Ready(IndustryData {
            jobs: Ok(IndustryJobsData::default()),
            blueprints: Ok(BlueprintsData {
                blueprints: vec![CharacterBlueprint {
                    item_id: 1_040_000_000_004,
                    type_id: 681,
                    location_id: container_item_id,
                    location_flag: "Locked".to_string(),
                    quantity: -1,
                    time_efficiency: 0,
                    material_efficiency: 0,
                    runs: -1,
                }],
                truncated: false,
            }),
        });

        let (ids, structures) = MimirApp::collect_live_name_ids(&state, None);
        assert!(ids.contains(&1_000_000_042));
        assert_eq!(structures, vec![real_structure_id]);
    }

    #[test]
    fn collect_live_name_ids_skips_blueprint_ship_internal_flags() {
        use crate::esi::models::CharacterBlueprint;

        let mut state = AppState::new(false);
        let ship_item_id = 1_040_000_000_777;
        let real_structure_id = 1_030_000_000_888;
        state.industry = LoadState::Ready(IndustryData {
            jobs: Ok(IndustryJobsData::default()),
            blueprints: Ok(BlueprintsData {
                blueprints: vec![
                    CharacterBlueprint {
                        item_id: 1_040_000_000_778,
                        type_id: 681,
                        location_id: ship_item_id,
                        location_flag: "Cargo".to_string(),
                        quantity: -1,
                        time_efficiency: 0,
                        material_efficiency: 0,
                        runs: -1,
                    },
                    CharacterBlueprint {
                        item_id: 1_040_000_000_779,
                        type_id: 682,
                        location_id: real_structure_id,
                        location_flag: "Hangar".to_string(),
                        quantity: -1,
                        time_efficiency: 0,
                        material_efficiency: 0,
                        runs: -1,
                    },
                ],
                truncated: false,
            }),
        });

        let (ids, structures) = MimirApp::collect_live_name_ids(&state, None);
        assert!(ids.contains(&681));
        assert!(ids.contains(&682));
        assert_eq!(structures, vec![real_structure_id]);
    }

    #[test]
    fn refreshed_updates_character_corp_and_alliance_in_roster() {
        let mut app = MimirApp::new(false, Arc::new(Mutex::new(Vec::new())), None, None);
        app.state.characters = vec![
            CharacterRow {
                character_id: 101,
                name: "Alpha".to_string(),
                corporation_id: 0,
                alliance_id: None,
                is_active: true,
            },
            CharacterRow {
                character_id: 202,
                name: "Beta".to_string(),
                corporation_id: 0,
                alliance_id: None,
                is_active: false,
            },
        ];
        app.state.set_active_character(101);
        app.refresh_generation.insert(101, 1);
        app.refresh_generation.insert(202, 1);

        let send_refresh = |id: i64, corp_id: i64, alliance_id: Option<i64>, name: &str| {
            app.tx.send(BackendMsg::Refreshed {
                generation: 1,
                character_id: id,
                info: Box::new(CharacterPublicInfo {
                    name: name.to_string(),
                    corporation_id: corp_id,
                    alliance_id,
                    ..Default::default()
                }),
                skills: Box::new(SkillsData::default()),
                wallet: Box::new(WalletData::default()),
                assets: Ok(Box::new(AssetsData::default())),
                assets_needs_reauthorize: false,
                detail: Box::new(CharacterDetailData {
                    attributes: Ok(Default::default()),
                    implants: Ok(Vec::new()),
                    clones: Ok(Default::default()),
                    standings: Ok(Vec::new()),
                    location: Ok(Default::default()),
                    ship: Ok(Default::default()),
                    online: Ok(Default::default()),
                }),
                industry: Box::new(IndustryData {
                    jobs: Ok(IndustryJobsData::default()),
                    blueprints: Ok(BlueprintsData::default()),
                }),
                planetary_colonies: Ok(Vec::new()),
                fittings_list: Ok(Vec::new()),
            });
        };

        send_refresh(101, 98_000_001, Some(99_000_001), "Alpha Renamed");
        send_refresh(202, 98_000_002, None, "Beta");
        app.drain_requests();

        assert_eq!(app.state.characters[0].name, "Alpha Renamed");
        assert_eq!(app.state.characters[0].corporation_id, 98_000_001);
        assert_eq!(app.state.characters[0].alliance_id, Some(99_000_001));
        assert_eq!(app.state.characters[1].corporation_id, 98_000_002);
        let (ids, _) = MimirApp::collect_live_name_ids(&app.state, None);
        assert!(ids.contains(&98_000_001));
        assert!(ids.contains(&99_000_001));
        assert!(ids.contains(&98_000_002));
    }

    #[test]
    fn has_pending_work_detects_queued_portraits_and_clears_after_drain() {
        let mut app = MimirApp::new(false, Arc::new(Mutex::new(Vec::new())), None, None);
        app.state.characters = vec![CharacterRow {
            character_id: 42,
            name: "Pilot".to_string(),
            corporation_id: 1000166,
            alliance_id: None,
            is_active: true,
        }];
        app.state.active_character_id = Some(42);
        app.last_active_id = Some(42);
        assert!(!app.has_pending_work());

        crate::ui::portraits::ensure_portrait_requested(&mut app.state, 42);
        assert!(app.has_pending_work());
        app.drain_requests();
        assert!(!app.has_pending_work());

        app.state.demo = true;
        assert!(app.has_pending_work());
        app.drain_requests();
        assert!(!app.has_pending_work());
    }

    #[test]
    fn demo_mode_drops_late_live_names_portraits_structures_and_fitting_writes() {
        let mut app = MimirApp::new(true, Arc::new(Mutex::new(Vec::new())), None, None);
        let active_id = app
            .state
            .active_character_id
            .expect("demo active character");
        app.state.fittings_write_in_flight = Some(FittingWriteInFlight {
            character_id: active_id,
            kind: FittingWriteKind::Save,
            fitting_id: None,
        });
        let status_before = app.state.status_message.clone();

        app.tx.send(BackendMsg::NamesResolved {
            names: vec![UniverseName {
                id: 98_111_111,
                name: "Live Leak Corp".to_string(),
                category: "corporation".to_string(),
            }],
            rejected: vec![30000142],
        });
        app.tx.send(BackendMsg::StructuresResolved {
            character_id: active_id,
            names: vec![UniverseName {
                id: 1_030_000_000_999,
                name: "Live Leak Keepstar".to_string(),
                category: "structure".to_string(),
            }],
            denied: vec![],
        });
        app.tx.send(BackendMsg::PortraitFetched {
            kind: ImageKind::Type,
            id: 34,
            image: Ok(test_image(8, 8)),
        });
        app.tx.send(BackendMsg::FittingWriteDone {
            character_id: active_id,
            kind: FittingWriteKind::Save,
            outcome: FittingWriteOutcome::Saved { fitting_id: 777 },
        });
        app.drain_requests();

        assert_eq!(app.resolver.cached(98_111_111), None);
        assert_eq!(app.resolver.cached(1_030_000_000_999), None);
        assert!(matches!(
            app.state.portrait_state(ImageKind::Type, 34),
            PortraitState::NotRequested
        ));
        assert!(app.state.fittings_write_in_flight.is_none());
        assert!(app.state.fittings_pending_selection.is_none());
        assert_eq!(app.state.status_message, status_before);
    }

    #[test]
    fn live_startup_activates_first_character_when_none_flagged_active() {
        let conn = db::open_in_memory().expect("in-memory db");
        repositories::upsert_character(
            &conn,
            &CharacterRow {
                character_id: 11,
                name: "Alice".to_string(),
                corporation_id: 1000166,
                alliance_id: None,
                is_active: false,
            },
        )
        .expect("insert 11");
        repositories::upsert_character(
            &conn,
            &CharacterRow {
                character_id: 22,
                name: "Bob".to_string(),
                corporation_id: 1000166,
                alliance_id: None,
                is_active: false,
            },
        )
        .expect("insert 22");

        let dir = tempfile::tempdir().expect("tempdir");
        let backends = Backends {
            esi: Arc::new(EsiClient::default()),
            token_store: Arc::new(TokenStore::file_only(dir.path().join("tokens.json"))),
            db: Arc::new(Mutex::new(conn)),
            jwt_verifier: None,
            portraits: Arc::new(PortraitService::new(dir.path().to_path_buf())),
        };
        let app = MimirApp::new(
            false,
            Arc::new(Mutex::new(Vec::new())),
            None,
            Some(backends),
        );
        assert_eq!(app.state.characters.len(), 2);
        assert_eq!(app.state.active_character_id, Some(11));
        assert!(app.state.characters[0].is_active);
        assert!(!app.state.characters[1].is_active);
    }

    #[test]
    fn demo_exit_does_not_flush_demo_startup_view_into_live_db() {
        let conn = db::open_in_memory().expect("in-memory db");
        repositories::set_setting(&conn, "startup_view", View::Wallet.label())
            .expect("seed startup_view");

        let dir = tempfile::tempdir().expect("tempdir");
        let db_handle = Arc::new(Mutex::new(conn));
        let backends = Backends {
            esi: Arc::new(EsiClient::default()),
            token_store: Arc::new(TokenStore::file_only(dir.path().join("tokens.json"))),
            db: db_handle.clone(),
            jwt_verifier: None,
            portraits: Arc::new(PortraitService::new(dir.path().to_path_buf())),
        };
        let mut app = MimirApp::new(
            false,
            Arc::new(Mutex::new(Vec::new())),
            None,
            Some(backends),
        );
        assert_eq!(app.state.startup_view, View::Wallet);

        // Enter demo and edit startup_view while in demo mode.
        app.state.demo = true;
        crate::demo::data::seed_demo_state(&mut app.state);
        app.drain_requests();
        app.state.startup_view = View::Fittings;
        app.persist_startup_view_if_changed();

        // Exit demo in UI: state.demo becomes false while last_demo_mode is still true.
        app.state.clear_for_demo_exit();
        app.persist_startup_view_if_changed();
        {
            let conn = db_handle.lock().expect("db lock");
            assert_eq!(
                repositories::get_setting(&conn, "startup_view").expect("read setting"),
                Some(View::Wallet.label().to_string())
            );
        }

        // Next frame drain reloads the live startup_view without touching live DB.
        app.drain_requests();
        assert_eq!(app.state.startup_view, View::Wallet);
        app.persist_startup_view_if_changed();
        let conn = db_handle.lock().expect("db lock");
        assert_eq!(
            repositories::get_setting(&conn, "startup_view").expect("read setting"),
            Some(View::Wallet.label().to_string())
        );
    }

    #[test]
    fn needs_tick_ignores_planetary_detail_for_unselected_planet() {
        use crate::esi::models::{ExtractorDetails, PlanetColonyDetail, PlanetPin};

        let mut app = MimirApp::new(false, Arc::new(Mutex::new(Vec::new())), None, None);
        app.state.active_character_id = Some(42);
        app.state.planetary_selected_planet_id = Some(700000002);
        app.state.planetary = LoadState::Ready(PlanetaryData {
            colonies: Ok(Vec::new()),
            detail: Some(SelectedColonyDetail {
                selection: PlanetSelection {
                    character_id: 42,
                    planet_id: 700000001,
                },
                result: Ok(PlanetColonyDetail {
                    pins: vec![PlanetPin {
                        pin_id: 1,
                        type_id: 20001,
                        expiry_time: Some(
                            (chrono::Utc::now() + chrono::Duration::hours(2)).to_rfc3339(),
                        ),
                        extractor_details: Some(ExtractorDetails {
                            product_type_id: Some(34),
                            qty_per_cycle: Some(100),
                            cycle_time: Some(3600),
                        }),
                        ..Default::default()
                    }],
                    links: Vec::new(),
                    routes: Vec::new(),
                }),
            }),
        });

        assert!(
            !app.needs_tick(),
            "detail stamped for planet 700000001 must not trigger ticks while 700000002 is selected"
        );

        app.state.planetary_selected_planet_id = Some(700000001);
        assert!(app.needs_tick());
    }
}
