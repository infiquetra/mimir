//! Application state: characters, active character, per-view load state.
//!
//! F3 owns this state. Live data arrives from F1/F2 through the integrator:
//! views only set the request flags (`refresh_requested`, `login_requested`,
//! `logout_requested_id`, `delete_requested_id`, `retry_requested`,
//! `stepup_requested`) and the integrator drains them each frame. Nothing
//! here performs network or disk work, and no token material is ever
//! stored in this struct.

use std::collections::{HashMap, HashSet};
use std::sync::Arc;

use crate::esi::endpoints::WriteFailureClass;
use crate::esi::models::*;
use crate::fitting::editor::{BrowserRow, ShipRow};
use crate::fitting::eft::{ImportSection, ImportedFitting};
use crate::invention_calculator::{
    DEFAULT_BASE_PROBABILITY, DEFAULT_DECRYPTOR_MULTIPLIER, DEFAULT_SKILL_LEVEL,
};
use crate::names::exploration_ref::{EffectFamily, ExplorationRef};
use crate::names::sde::Sde;
use crate::portraits::ImageKind;
use crate::production_chain::DEFAULT_QUANTITY;
use crate::reaction_calculator::{DEFAULT_FACILITY_BONUS_PERCENT, DEFAULT_RUNS};
use crate::skills::plans::{SkillPlan, SkillPlanAction};
use crate::storage::repositories::CharacterRow;
use crate::trade_calculator::{DEFAULT_BROKER_FEE_PERCENT, DEFAULT_SALES_TAX_PERCENT};

/// The eleven views (keys 1-9, 0 and E in the shell).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum View {
    #[default]
    Dashboard,
    Characters,
    Skills,
    Wallet,
    Assets,
    Market,
    Industry,
    Planets,
    Fittings,
    Settings,
    Exploration,
}

impl View {
    pub const ALL: [View; 11] = [
        View::Dashboard,
        View::Characters,
        View::Skills,
        View::Wallet,
        View::Assets,
        View::Market,
        View::Industry,
        View::Planets,
        View::Fittings,
        View::Settings,
        View::Exploration,
    ];

    pub fn label(&self) -> &'static str {
        match self {
            View::Dashboard => "Dashboard",
            View::Characters => "Characters",
            View::Skills => "Skills",
            View::Wallet => "Wallet",
            View::Assets => "Assets",
            View::Market => "Market",
            View::Industry => "Industry",
            View::Planets => "Planets",
            View::Fittings => "Fittings",
            View::Settings => "Settings",
            View::Exploration => "Exploration",
        }
    }

    pub fn from_index(index: usize) -> Option<View> {
        View::ALL.get(index).copied()
    }

    pub fn index(&self) -> usize {
        View::ALL.iter().position(|v| v == self).unwrap_or(0)
    }

    pub fn next(&self) -> View {
        View::ALL[(self.index() + 1) % View::ALL.len()]
    }

    pub fn previous(&self) -> View {
        View::ALL[(self.index() + View::ALL.len() - 1) % View::ALL.len()]
    }
}

/// Per-view load state (ports the Flutter Empty/Loading/Error contract).
#[derive(Debug, Clone, Default)]
pub enum LoadState<T> {
    #[default]
    Loading,
    Ready(T),
    Empty,
    Error(String),
}

impl<T> LoadState<T> {
    pub fn is_loading(&self) -> bool {
        matches!(self, LoadState::Loading)
    }

    pub fn is_ready(&self) -> bool {
        matches!(self, LoadState::Ready(_))
    }

    pub fn as_ready(&self) -> Option<&T> {
        match self {
            LoadState::Ready(value) => Some(value),
            _ => None,
        }
    }

    pub fn error_message(&self) -> Option<&str> {
        match self {
            LoadState::Error(message) => Some(message),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum AuthState {
    #[default]
    Idle,
    AwaitingCallback,
    Exchanging,
    Success,
    Error,
}

impl AuthState {
    pub fn label(&self) -> &'static str {
        match self {
            AuthState::Idle => "Not signing in",
            AuthState::AwaitingCallback => "Waiting for EVE SSO in your browser...",
            AuthState::Exchanging => "Finishing sign-in...",
            AuthState::Success => "Signed in",
            AuthState::Error => "Sign-in failed",
        }
    }

    pub fn is_busy(&self) -> bool {
        matches!(self, AuthState::AwaitingCallback | AuthState::Exchanging)
    }
}

/// Step-up sign-in request: re-run EVE SSO for an existing character to
/// grant `scopes` in addition to what it already granted. Set by views;
/// drained by the shell. Scopes are not secrets; no token material here.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StepUpRequest {
    pub character_id: i64,
    pub scopes: Vec<String>,
}

impl StepUpRequest {
    pub fn new(character_id: i64, scopes: &[&str]) -> Self {
        tracing::debug!(
            "[AUTH] step-up request created character_id={} scopes={}",
            character_id,
            scopes.join(" ")
        );
        Self {
            character_id,
            scopes: scopes.iter().map(|s| s.to_string()).collect(),
        }
    }
}

/// Armed (not yet confirmed) fitting write, stamped with the
/// character and target it was armed for (design section 6).
/// Arming swaps the arm button for the confirmation block; at
/// most one is armed app-wide and arming one replaces any
/// other. Memory only: never persisted, and cleared whenever
/// the stamped target is no longer visible.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FittingWriteConfirm {
    SaveImported { character_id: i64 },
    SaveCopy { character_id: i64, fitting_id: i64 },
    Delete { character_id: i64, fitting_id: i64 },
}

/// A confirmed fitting write waiting to be drained by the
/// shell (design section 7). The save request body is the
/// finished `SaveFittingRequest` built in the confirmation
/// frame, so the shell never touches mapping logic.
#[derive(Debug, Clone)]
pub enum FittingWriteRequest {
    Save {
        character_id: i64,
        request: SaveFittingRequest,
    },
    Delete {
        character_id: i64,
        fitting_id: i64,
    },
}

/// What kind of fitting write is in flight (or just landed).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FittingWriteKind {
    Save,
    Delete,
}

impl FittingWriteKind {
    pub fn label(&self) -> &'static str {
        match self {
            FittingWriteKind::Save => "save",
            FittingWriteKind::Delete => "delete",
        }
    }
}

/// Record of the one write currently in flight (design
/// section 7.1). Single-flight is global: at most one value
/// in the whole app. `fitting_id` is `Some` for a delete (the
/// target) and `None` for a save (there is no server fitting
/// yet).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FittingWriteInFlight {
    pub character_id: i64,
    pub kind: FittingWriteKind,
    pub fitting_id: Option<i64>,
}

/// How one fitting write ended (design section 8). `Saved`
/// and `Deleted` carry the receipt the server returned (for a
/// delete, the target that was deleted); `Failed` carries the
/// classifier verdict.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FittingWriteOutcome {
    Saved {
        fitting_id: i64,
    },
    Deleted {
        fitting_id: i64,
    },
    Failed {
        class: WriteFailureClass,
        needs_reauthorize: bool,
    },
}

/// Armed (not yet confirmed) skill-plan mutation, stamped with
/// the character and plan it was armed for (design section 7).
/// Arming swaps the arm button for the confirmation block; at
/// most one is armed app-wide. Memory only: never persisted,
/// and cleared whenever the stamped target is no longer visible
/// — a confirmation never outlives the thing it confirms.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SkillPlanConfirm {
    DeletePlan {
        character_id: i64,
        plan_id: i64,
    },
    RemoveEntry {
        character_id: i64,
        plan_id: i64,
        skill_id: i64,
    },
}

/// The inline create/rename editor, stamped with the character
/// (and, for `Edit`, the plan) it edits (design section 7).
/// Memory only: drafts are user text, never logged, never
/// persisted except through a confirmed action.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SkillPlanEditor {
    Create { character_id: i64 },
    Edit { character_id: i64, plan_id: i64 },
}

/// Wallet period filter shared by the wallet view and the dashboard.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum WalletPeriod {
    #[default]
    All,
    Days7,
    Days30,
    Days90,
}

impl WalletPeriod {
    pub const ALL: [WalletPeriod; 4] = [
        WalletPeriod::All,
        WalletPeriod::Days7,
        WalletPeriod::Days30,
        WalletPeriod::Days90,
    ];

    pub fn label(&self) -> &'static str {
        match self {
            WalletPeriod::All => "All time",
            WalletPeriod::Days7 => "7 days",
            WalletPeriod::Days30 => "30 days",
            WalletPeriod::Days90 => "90 days",
        }
    }

    /// Window length in days; `None` means no window.
    pub fn days(&self) -> Option<i64> {
        match self {
            WalletPeriod::All => None,
            WalletPeriod::Days7 => Some(7),
            WalletPeriod::Days30 => Some(30),
            WalletPeriod::Days90 => Some(90),
        }
    }
}

/// Wallet view data bundle. Field set is a cross-builder contract (F4 demo
/// seeding constructs this literally); do not add fields here.
#[derive(Debug, Clone, Default)]
pub struct WalletData {
    pub balance: f64,
    pub journal: Vec<WalletJournalItem>,
    pub transactions: Vec<WalletTransactionItem>,
    pub loyalty: Vec<LoyaltyPointItem>,
}

/// Skills view data bundle. Field set is a cross-builder contract (F4 demo
/// seeding constructs this literally); do not add fields here.
#[derive(Debug, Clone, Default)]
pub struct SkillsData {
    pub skills: CharacterSkills,
    pub queue: Vec<SkillQueueItem>,
}

/// Assets view data bundle: raw ESI rows plus per-item custom names for
/// singletons (ships, containers), keyed by item_id. Custom names are
/// per-instance and never enter the universe name resolver.
#[derive(Debug, Clone, Default)]
pub struct AssetsData {
    pub items: Vec<AssetItem>,
    pub custom_names: HashMap<i64, String>,
}

/// One character-detail section's failure. `needs_reauthorize` is the
/// typed scope outcome (HTTP 401/403 via
/// `endpoints::needs_reauthorize`), never parsed from `message`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SectionError {
    pub message: String,
    pub needs_reauthorize: bool,
}

pub type SectionResult<T> = Result<T, SectionError>;

/// Character-detail bundle: seven independent section results.
/// Field set is a cross-builder contract (demo seeding and the
/// shell construct this literally); do not add fields here.
#[derive(Debug, Clone)]
pub struct CharacterDetailData {
    pub attributes: SectionResult<CharacterAttributes>,
    pub implants: SectionResult<Vec<i64>>,
    pub clones: SectionResult<CharacterClones>,
    pub standings: SectionResult<Vec<Standing>>,
    pub location: SectionResult<CharacterLocation>,
    pub ship: SectionResult<CharacterShip>,
    pub online: SectionResult<CharacterOnline>,
}

impl CharacterDetailData {
    /// True when a step-up-protected section failed for scope reasons.
    /// Attributes and implants are first-auth and never trigger this.
    pub fn needs_detail_stepup(&self) -> bool {
        fn reauth<T>(result: &SectionResult<T>) -> bool {
            matches!(result, Err(e) if e.needs_reauthorize)
        }
        reauth(&self.clones)
            || reauth(&self.standings)
            || reauth(&self.location)
            || reauth(&self.ship)
            || reauth(&self.online)
    }
}

/// What the user is looking at in Market, and under which character
/// context (None = public sections only). Also the identity stamped
/// on every market fetch/message: results that do not carry the
/// current selection are dropped, never applied. `type_name` is the
/// resolved name captured at selection time (words only; the numeric
/// ids here are state, never rendered).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MarketSelection {
    pub type_id: i64,
    pub type_name: String,
    pub region_id: i64,
    pub character_id: Option<i64>,
}

#[derive(Debug, Clone, Default)]
pub struct PublicOrdersData {
    pub orders: Vec<RegionalOrder>,
    pub truncated: bool,
}

#[derive(Debug, Clone, Default)]
pub struct CharacterOrdersData {
    pub orders: Vec<CharacterOrder>,
    pub truncated: bool,
}

/// Market bundle: three independent section results fetched for one
/// selection. Field set is a cross-builder contract (the shell and
/// demo seeding construct this literally); do not add fields here.
#[derive(Debug, Clone)]
pub struct MarketData {
    pub selection: MarketSelection,
    pub public_orders: SectionResult<PublicOrdersData>,
    pub history: SectionResult<Vec<MarketHistoryEntry>>,
    pub character_orders: SectionResult<CharacterOrdersData>,
}

#[derive(Debug, Clone, Default)]
pub struct IndustryJobsData {
    pub jobs: Vec<IndustryJob>,
    pub truncated: bool,
}

#[derive(Debug, Clone, Default)]
pub struct BlueprintsData {
    pub blueprints: Vec<CharacterBlueprint>,
    pub truncated: bool,
}

/// Industry bundle: two independent section results for the
/// active character. Field set is a cross-builder contract (the
/// shell and demo seeding construct this literally); do not add
/// fields here.
#[derive(Debug, Clone)]
pub struct IndustryData {
    pub jobs: SectionResult<IndustryJobsData>,
    pub blueprints: SectionResult<BlueprintsData>,
}

impl IndustryData {
    /// True when either section failed for scope reasons.
    pub fn needs_industry_stepup(&self) -> bool {
        fn reauth<T>(result: &SectionResult<T>) -> bool {
            matches!(result, Err(e) if e.needs_reauthorize)
        }
        reauth(&self.jobs) || reauth(&self.blueprints)
    }
}

/// Fetch/message identity for one colony detail: the character and
/// planet the fetch was stamped for. The numeric ids here are
/// state, never rendered.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PlanetSelection {
    pub character_id: i64,
    pub planet_id: i64,
}

/// One selected colony's detail section, stamped with the selection
/// it was fetched for so a stale result can never display.
#[derive(Debug, Clone)]
pub struct SelectedColonyDetail {
    pub selection: PlanetSelection,
    pub result: SectionResult<PlanetColonyDetail>,
}

/// Planetary bundle: the colonies list plus the one selected
/// colony's detail. Field set is a cross-builder contract (the
/// shell and demo seeding construct this literally); do not add
/// fields here.
#[derive(Debug, Clone)]
pub struct PlanetaryData {
    pub colonies: SectionResult<Vec<PlanetColony>>,
    pub detail: Option<SelectedColonyDetail>,
}

impl PlanetaryData {
    /// True when the colonies section or a present detail failed
    /// for scope reasons.
    pub fn needs_planetary_stepup(&self) -> bool {
        fn reauth<T>(result: &SectionResult<T>) -> bool {
            matches!(result, Err(e) if e.needs_reauthorize)
        }
        reauth(&self.colonies) || self.detail.as_ref().is_some_and(|d| reauth(&d.result))
    }
}

/// Saved-fittings bundle: the one list section for the active
/// character. Field set is a cross-builder contract (the
/// shell and demo seeding construct this literally); do not
/// add fields here.
#[derive(Debug, Clone)]
pub struct FittingsData {
    pub fittings: SectionResult<Vec<CharacterFitting>>,
}

impl FittingsData {
    /// True when the list section failed for scope reasons.
    pub fn needs_fittings_stepup(&self) -> bool {
        matches!(&self.fittings, Err(e) if e.needs_reauthorize)
    }
}

/// Bundled Exploration reference: the one offline catalogue for the
/// Exploration view. It is character-independent static data loaded
/// once at startup, so character switches and removals never clear
/// it (locked in design section 7.1).
#[derive(Debug, Clone)]
pub struct ExplorationData {
    /// Shared behind `Arc` so the view can hold the catalogue across
    /// a frame without deep-cloning 2,631 systems every render.
    pub reference: Arc<ExplorationRef>,
}

/// Which Exploration section is shown (design section 7.1).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ExplorationSection {
    #[default]
    Types,
    Systems,
    Effects,
}

impl ExplorationSection {
    pub const ALL: [ExplorationSection; 3] = [
        ExplorationSection::Types,
        ExplorationSection::Systems,
        ExplorationSection::Effects,
    ];

    pub fn label(&self) -> &'static str {
        match self {
            ExplorationSection::Types => "Types",
            ExplorationSection::Systems => "Systems",
            ExplorationSection::Effects => "Effects",
        }
    }
}

/// Wormhole destination filter chip (design section 7.1). `JSpace`
/// matches the six J-space class labels `C1`..`C6`; the other
/// variants match their `destination_label()` exactly.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DestinationFilter {
    Highsec,
    Lowsec,
    Nullsec,
    Pochven,
    JSpace,
}

impl DestinationFilter {
    pub const ALL: [DestinationFilter; 5] = [
        DestinationFilter::Highsec,
        DestinationFilter::Lowsec,
        DestinationFilter::Nullsec,
        DestinationFilter::Pochven,
        DestinationFilter::JSpace,
    ];

    pub fn label(&self) -> &'static str {
        match self {
            DestinationFilter::Highsec => "Highsec",
            DestinationFilter::Lowsec => "Lowsec",
            DestinationFilter::Nullsec => "Nullsec",
            DestinationFilter::Pochven => "Pochven",
            DestinationFilter::JSpace => "J-space",
        }
    }
}

/// Blueprint library filter: every blueprint, originals only,
/// or copies only. Classification is `runs == -1` (section 7.3).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum BlueprintKindFilter {
    #[default]
    All,
    Originals,
    Copies,
}

impl BlueprintKindFilter {
    pub const ALL: [BlueprintKindFilter; 3] = [
        BlueprintKindFilter::All,
        BlueprintKindFilter::Originals,
        BlueprintKindFilter::Copies,
    ];

    pub fn label(&self) -> &'static str {
        match self {
            BlueprintKindFilter::All => "All",
            BlueprintKindFilter::Originals => "Originals (BPO)",
            BlueprintKindFilter::Copies => "Copies (BPC)",
        }
    }
}

/// One selectable market region. `name` is the curated display
/// fallback (Flutter `kTradeHubRegions` parity); a resolver hit for
/// `id` wins in the view. The numeric id is never rendered.
pub struct MarketRegion {
    pub id: i64,
    pub name: &'static str,
}

pub const MARKET_REGIONS: [MarketRegion; 5] = [
    MarketRegion {
        id: 10000002,
        name: "The Forge (Jita)",
    },
    MarketRegion {
        id: 10000043,
        name: "Domain (Amarr)",
    },
    MarketRegion {
        id: 10000032,
        name: "Sinq Laison (Dodixie)",
    },
    MarketRegion {
        id: 10000042,
        name: "Metropolis (Hek)",
    },
    MarketRegion {
        id: 10000030,
        name: "Heimatar (Rens)",
    },
];

pub const DEFAULT_MARKET_REGION_ID: i64 = 10000002; // The Forge

pub fn market_region_name(region_id: i64) -> Option<&'static str> {
    MARKET_REGIONS
        .iter()
        .find(|r| r.id == region_id)
        .map(|r| r.name)
}

/// Summary location string: docked name, else solar-system name, else
/// `None` ("not loaded"). Inputs come from `resolver.cached()` so an
/// unresolved id stays distinguishable from the `Unknown Location` word.
pub fn summary_location_name(docked: Option<&str>, solar_system: Option<&str>) -> Option<String> {
    docked.or(solar_system).map(str::to_string)
}

/// Summary ship string from the custom ship name and the resolved type
/// name. Trimmed empty and trimmed `"None"` custom names are absent
/// (the Assets placeholder filter); both present and different gives
/// `"{custom} ({type})"`, one present gives that one, neither `None`.
pub fn ship_display_name(custom_name: &str, resolved_type: Option<&str>) -> Option<String> {
    let custom = custom_name.trim();
    let custom = (!custom.is_empty() && custom != "None").then_some(custom);
    let resolved = resolved_type.map(str::trim).filter(|t| !t.is_empty());
    match (custom, resolved) {
        (Some(c), Some(t)) if c != t => Some(format!("{c} ({t})")),
        (Some(c), _) => Some(c.to_string()),
        (None, Some(t)) => Some(t.to_string()),
        (None, None) => None,
    }
}

/// Image load state for one `(kind, id)` key in `AppState::portraits`.
/// `Ready` carries the decoded image (decode happens once at
/// landing, never per frame); every other variant renders as the
/// name/initial (character) or blank-box (logo) placeholder — never
/// a fabricated or stock face, never another entity's image.
#[derive(Debug, Clone, Default)]
pub enum PortraitState {
    #[default]
    NotRequested,
    Loading,
    Ready(Arc<image::DynamicImage>),
    Failed,
}

/// One row of the multi-character overview grid. The integrator fills this
/// from F2 repositories / F1 endpoints per character; `None` fields render
/// as "not loaded" instead of a guessed value. Display strings (`training`,
/// `location`, `ship`) must already be resolved EVE names, never raw IDs.
#[derive(Debug, Clone, Default)]
pub struct CharacterSummary {
    pub balance: Option<f64>,
    pub training_skill_name: Option<String>,
    pub training_finish_date: Option<String>,
    pub queue_len: Option<usize>,
    pub total_sp: Option<i64>,
    pub location_name: Option<String>,
    pub ship_name: Option<String>,
}

#[derive(Debug, Default)]
pub struct AppState {
    pub view: View,
    pub characters: Vec<CharacterRow>,
    pub active_character_id: Option<i64>,
    pub auth: AuthState,
    pub demo: bool,
    pub offline: bool,
    pub dashboard: LoadState<CharacterPublicInfo>,
    pub character_detail: LoadState<CharacterPublicInfo>,
    pub skills: LoadState<SkillsData>,
    pub wallet: LoadState<WalletData>,
    pub assets: LoadState<AssetsData>,
    /// The assets fetch failed with the typed scope error, so the Assets
    /// view shows step-up guidance instead of a retry panel.
    pub assets_needs_reauthorize: bool,
    /// A name-resolution pass found player-structure
    /// locations for the active character but stored token
    /// metadata does not carry the structures scope, so the
    /// Assets view shows the structure step-up banner.
    pub structures_needs_reauthorize: bool,
    pub character_details: LoadState<CharacterDetailData>,
    pub market: LoadState<MarketData>,
    pub industry: LoadState<IndustryData>,
    pub planetary: LoadState<PlanetaryData>,
    pub fittings: LoadState<FittingsData>,
    pub exploration: LoadState<ExplorationData>,
    pub log_lines: Vec<String>,
    pub status_message: String,

    // Multi-character overview, keyed by character id (integrator-filled).
    pub summaries: HashMap<i64, CharacterSummary>,

    // Per-entity image states (character portraits plus corporation
    // and alliance logos), keyed by `(kind, id)`. Keyed like
    // `summaries`, so a late landing writes only its own slot and a
    // character switch never clears the map; `remove_character`
    // drops the removed character's entry and any logo entry no
    // remaining row references. `portrait_requests` is the drained
    // request queue (views call `request_portrait`).
    pub portraits: HashMap<(ImageKind, i64), PortraitState>,
    pub portrait_requests: Vec<(ImageKind, i64)>,

    // Bundled skill catalogue type ids, installed once at
    // startup from the SDE extract (design skill-icons section
    // 4). State-only: never rendered, never logged as a list.
    pub skill_catalogue_type_ids: HashSet<i64>,

    // View-local UI state (survives across frames, unlike egui closures).
    pub skill_search: String,
    pub wallet_search: String,
    pub assets_search: String,
    pub wallet_period: WalletPeriod,
    pub wallet_ref_filter: Option<String>,
    pub log_filter: String,
    pub log_tag_filter: Option<String>,
    pub selected_queue_row: usize,
    pub selected_journal_row: usize,
    pub startup_view: View,
    pub confirm_delete_id: Option<i64>,
    pub focus_search: bool,
    pub text_input_focused: bool,
    // View-local market UI state. The selection lives outside
    // `LoadState<MarketData>` so it survives a failed fetch.
    pub market_search: String,
    pub market_selected_type_id: Option<i64>,
    pub market_selected_type_name: Option<String>,
    pub market_region_id: i64,
    pub market_candidates: Vec<UniverseName>,
    pub market_lookup_message: Option<String>,
    pub market_generation: u64,
    // View-local trade calculator drafts (market trade calculator
    // design section 3): session-only String drafts for the
    // Market view's Trade Calculator block. Prices start empty;
    // fee drafts seed from the pure module's starting-value
    // constants in `AppState::new`. Selection changes, region
    // changes, refreshes, and character switches never touch
    // them; nothing is stored.
    pub market_trade_buy_price: String,
    pub market_trade_sell_price: String,
    pub market_trade_broker_fee_percent: String,
    pub market_trade_sales_tax_percent: String,
    // View-local industry UI state.
    pub industry_search: String,
    pub industry_blueprint_kind: BlueprintKindFilter,
    // View-local invention calculator drafts (industry calculators
    // design section 3): session-only String drafts for the
    // Industry view's Invention Calculator block. All five seed
    // from the pure module's starting-value constants in
    // `AppState::new`; the derived Default would leave them empty,
    // and an empty field must mean "reader cleared it", not the
    // app's starting state. Blueprint filtering, industry
    // refreshes, and character switches never touch them; nothing
    // is stored.
    pub industry_invention_base_probability: String,
    pub industry_invention_encryption_skill: String,
    pub industry_invention_datacore_skill1: String,
    pub industry_invention_datacore_skill2: String,
    pub industry_invention_decryptor_multiplier: String,
    // View-local reaction calculator drafts (industry reaction
    // design section 5): session-only String drafts for the
    // Industry view's Reaction Calculator block. The selection
    // is an internal catalogue key that is never rendered or
    // logged. Seeded from the pure module's starting-value
    // constants in `AppState::new`; the derived Default would
    // leave the numeric drafts empty, and an empty field must
    // mean "reader cleared it", not the app's starting state.
    // Character switches, blueprint filtering, industry
    // refreshes, and demo seeding never touch them; nothing is
    // stored.
    pub industry_reaction_search: String,
    pub industry_reaction_selected_type_id: Option<i64>,
    pub industry_reaction_runs: String,
    pub industry_reaction_facility_bonus_percent: String,
    // View-local production chain drafts (production chain design
    // section 5): session-only String drafts for the Industry view's
    // Production Chain Calculator block. The selection holds a product
    // type as an internal catalogue key that is never rendered or
    // logged. Seeded from the pure module's starting-value constant in
    // `AppState::new`; the derived Default would leave the quantity
    // empty, and an empty field must mean "reader cleared it", not the
    // app's starting state. Character switches, blueprint filtering,
    // industry refreshes, and demo seeding never touch them; nothing is
    // stored.
    pub industry_chain_search: String,
    pub industry_chain_selected_type_id: Option<i64>,
    pub industry_chain_quantity: String,
    // View-local planetary UI state. The selected planet lives
    // outside `LoadState<PlanetaryData>` so a failed detail fetch
    // cannot lose the selection.
    pub planetary_selected_planet_id: Option<i64>,
    pub planetary_generation: u64,
    // View-local fittings UI state.
    pub fittings_search: String,
    pub fittings_selected_fitting_id: Option<i64>,
    // View-local EFT import state (design section 8.1): the pasted text,
    // the last imported fitting, its fatal error, and the character it
    // was imported for. Memory only: never persisted, never ESI, never
    // inserted into FittingsData, cleared on character switch/removal.
    pub fittings_import_text: String,
    pub fittings_imported: Option<ImportedFitting>,
    pub fittings_import_error: Option<String>,
    pub fittings_import_owner: Option<i64>,
    // View-local fitting-editor state (fitting-editor design section
    // 4.1): sibling fields beside the import fields. Memory only,
    // like the import draft itself: cleared at every site that
    // clears `fittings_imported`, plus the panel's Clear import,
    // demo-sample, and new-import paths. The per-row quantity
    // drafts are keyed by draft row index and dropped on any
    // successful edit, since indices shift when rows are removed.
    pub fittings_editor_add_name: String,
    pub fittings_editor_add_quantity: String,
    pub fittings_editor_error: Option<String>,
    pub fittings_import_edited: bool,
    pub fittings_editor_quantity: HashMap<usize, String>,
    // Rename box draft: None until the panel seeds it from the
    // imported fitting's name; the draft name changes only
    // when the Rename control applies this text.
    pub fittings_editor_name: Option<String>,
    // Module-browser view state (module browser design
    // section 8): the selected tab, the search text, and the
    // cached candidate rows with the tab they were built for.
    // Memory only, like the edit state: cleared wherever the
    // draft dies. The cache is rebuilt only when the cached
    // section differs from the selected tab (design section 7).
    pub fittings_browser_section: ImportSection,
    pub fittings_browser_search: String,
    pub fittings_browser_rows: Vec<BrowserRow>,
    pub fittings_browser_rows_section: Option<ImportSection>,
    // Ship-chooser view state (new fitting from scratch design
    // section 9): the search text and the cached ship
    // candidates with whether they were built, beside the
    // browser cache they mirror. Memory only, like the edit
    // state: cleared wherever the draft dies. A boolean, not
    // an `Option`: the browser's `Option<ImportSection>`
    // records which tab its cache is for, and the chooser has
    // one list, so one bit is the honest state. An empty `Vec`
    // alone cannot serve, because a built empty list (fixture
    // catalogues) must not rebuild every frame.
    pub fittings_ship_search: String,
    pub fittings_ship_rows: Vec<ShipRow>,
    pub fittings_ship_rows_built: bool,
    // Fitting-write state (write design sections 3.2, 6, 7, 8).
    // Memory only: never persisted. `fittings_write_needs_reauthorize`
    // is a sibling `AppState` boolean rather than part of
    // `FittingsData` (its field set is a cross-builder contract),
    // because a write refusal is not a list state. The pending
    // selection records a just-saved fitting id until the first
    // judged refresh lands (design section 8.1).
    pub fittings_write_needs_reauthorize: bool,
    pub fittings_write_confirm: Option<FittingWriteConfirm>,
    pub fittings_write_requested: Option<FittingWriteRequest>,
    pub fittings_write_in_flight: Option<FittingWriteInFlight>,
    pub fittings_pending_selection: Option<(i64, i64)>,
    // View-local skill-plan state (design section 7). The loaded
    // plans are storage-confirmed truth (or the demo applier's);
    // everything else is memory-only view state: selection,
    // editor drafts, the armed confirmation, the one-slot drain
    // channel, and the picker. `skill_plans_owner` is the
    // `fittings_import_owner` precedent: the view renders plans
    // only when it equals the active character, so a list can
    // never display under the wrong character. Demo plans live
    // in `demo_skill_plans` keyed by demo character id, plus a
    // session counter starting at 1; they are never written to
    // the live database (the app's first non-ESI rows are the
    // live plan tables, which demo never touches).
    pub skill_plans: LoadState<Vec<SkillPlan>>,
    pub skill_plans_owner: Option<i64>,
    pub selected_skill_plan_id: Option<i64>,
    pub skill_plan_editor: Option<SkillPlanEditor>,
    pub skill_plan_name_draft: String,
    pub skill_plan_description_draft: String,
    pub skill_plan_confirm: Option<SkillPlanConfirm>,
    pub skill_plan_action: Option<SkillPlanAction>,
    pub skill_plan_picker_open: bool,
    pub skill_plan_picker_search: String,
    pub demo_skill_plans: HashMap<i64, Vec<SkillPlan>>,
    pub demo_next_plan_id: i64,
    // View-local exploration UI state (design section 7.1). The
    // bundled reference is character-independent static data, so
    // character switches and removals never reset these fields or
    // the loaded catalogue; selections use stable keys, never row
    // indices.
    pub exploration_search: String,
    pub exploration_section: ExplorationSection,
    pub exploration_destination: Option<DestinationFilter>,
    pub exploration_capital_only: bool,
    pub exploration_selected_code: Option<String>,
    pub exploration_selected_system_id: Option<i64>,
    pub exploration_selected_family: Option<EffectFamily>,
    pub exploration_selected_strength: u8,

    // Request flags for the integrator to drain (set by views, never faked
    // as completed work). See the module comment.
    pub refresh_requested: bool,
    pub retry_requested: bool,
    pub login_requested: bool,
    pub stepup_requested: Option<StepUpRequest>,
    pub logout_requested_id: Option<i64>,
    pub delete_requested_id: Option<i64>,
    pub market_fetch_requested: bool,
    pub market_lookup_requested: Option<String>,
    pub planetary_detail_fetch_requested: bool,
}

impl AppState {
    pub fn new(demo: bool) -> Self {
        tracing::info!("[STARTUP] AppState::new demo={}", demo);
        Self {
            demo,
            // Explicit: `..Self::default()` would leave the region at
            // 0, outside the locked hub set.
            market_region_id: DEFAULT_MARKET_REGION_ID,
            // Trade calculator fee drafts seed from the pure
            // module's starting values: the derived Default would
            // leave them empty, and an empty fee must mean
            // "reader cleared it", not the app's starting state
            // (design section 3). Price drafts start empty.
            market_trade_broker_fee_percent: format!("{:.1}", DEFAULT_BROKER_FEE_PERCENT),
            market_trade_sales_tax_percent: format!("{:.1}", DEFAULT_SALES_TAX_PERCENT),
            // Invention calculator drafts seed from the pure
            // module's starting values for the same reason (design
            // section 3): an empty field must mean "reader cleared
            // it", not the app's starting state.
            industry_invention_base_probability: format!("{:.2}", DEFAULT_BASE_PROBABILITY),
            industry_invention_encryption_skill: DEFAULT_SKILL_LEVEL.to_string(),
            industry_invention_datacore_skill1: DEFAULT_SKILL_LEVEL.to_string(),
            industry_invention_datacore_skill2: DEFAULT_SKILL_LEVEL.to_string(),
            industry_invention_decryptor_multiplier: format!("{:.1}", DEFAULT_DECRYPTOR_MULTIPLIER),
            // Reaction calculator drafts seed from the pure module's
            // starting values (design section 5): empty means "reader
            // cleared it", not the starting state. Search starts
            // empty and selection starts empty under Default.
            industry_reaction_runs: DEFAULT_RUNS.to_string(),
            industry_reaction_facility_bonus_percent: format!(
                "{:.1}",
                DEFAULT_FACILITY_BONUS_PERCENT
            ),
            // Production chain drafts seed from the pure module's
            // starting value (design section 5): empty means "reader
            // cleared it", not the starting state. Search starts empty
            // and selection starts empty under Default.
            industry_chain_quantity: DEFAULT_QUANTITY.to_string(),
            // Effect strength defaults to 1 (design section 7.1) and
            // is clamped to 1..=6 by the view on every use.
            exploration_selected_strength: 1,
            // Demo plan ids are session-assigned starting at 1
            // (design section 9); the derived default 0 would hand
            // out a zero id first.
            demo_next_plan_id: 1,
            status_message: if demo {
                "Demo mode: sample data, no network.".to_string()
            } else {
                "No character yet. Add a character or try the demo.".to_string()
            },
            ..Self::default()
        }
    }

    pub fn active_character(&self) -> Option<&CharacterRow> {
        let id = self.active_character_id?;
        self.characters.iter().find(|c| c.character_id == id)
    }

    /// Select the one market type. A different type discards the
    /// loaded bundle to Loading; reselecting the same type keeps the
    /// rows and just refetches. Either way the generation bumps so a
    /// slower earlier result can never win the race.
    pub fn set_market_selection(&mut self, type_id: i64, type_name: String) {
        let trimmed = type_name.trim();
        let word = if trimmed.is_empty() || trimmed.parse::<i64>().is_ok() {
            "Unknown Item".to_string()
        } else {
            trimmed.to_string()
        };
        let changed = self.market_selected_type_id != Some(type_id);
        tracing::info!("[MARKET] selected item name={} changed={}", word, changed);
        self.market_selected_type_id = Some(type_id);
        self.market_selected_type_name = Some(word);
        self.market_candidates.clear();
        self.market_lookup_message = None;
        if changed {
            self.market = LoadState::Loading;
        }
        self.market_generation = self.market_generation.wrapping_add(1);
        self.market_fetch_requested = true;
    }

    /// Select one colony. The generation always bumps (reselecting
    /// the same planet refetches too), so a slower earlier detail
    /// result can never win the race. The loaded bundle is left
    /// untouched: staleness is handled by matching the detail's
    /// stamped selection against this one.
    pub fn set_planetary_selection(&mut self, planet_id: i64) {
        self.planetary_selected_planet_id = Some(planet_id);
        self.planetary_generation = self.planetary_generation.wrapping_add(1);
        self.planetary_detail_fetch_requested = true;
        tracing::info!(
            "[PI] colony selected character_id={} planet_id={} generation={}",
            self.active_character_id.unwrap_or(0),
            planet_id,
            self.planetary_generation
        );
    }

    /// Select one of the locked hub regions; anything outside the
    /// set is ignored with no state change.
    pub fn set_market_region(&mut self, region_id: i64) {
        let Some(name) = market_region_name(region_id) else {
            tracing::warn!("[MARKET] ignoring region outside the hub set");
            return;
        };
        tracing::info!("[MARKET] selected region name={}", name);
        self.market_region_id = region_id;
        self.market_generation = self.market_generation.wrapping_add(1);
        if self.market_selected_type_id.is_some() {
            self.market = LoadState::Loading;
            self.market_fetch_requested = true;
        }
    }

    pub fn set_active_character(&mut self, character_id: i64) {
        if !self
            .characters
            .iter()
            .any(|c| c.character_id == character_id)
        {
            tracing::warn!(
                "[CHAR] ignoring set_active for unknown character_id={}",
                character_id
            );
            return;
        }
        let previous = self.active_character_id;
        tracing::info!("[CHAR] set active character_id={}", character_id);
        self.active_character_id = Some(character_id);
        for c in &mut self.characters {
            c.is_active = c.character_id == character_id;
        }
        if let Some(previous_id) = previous {
            if previous_id != character_id {
                // Assets are fetched tolerantly (a failed sub-fetch keeps
                // Ready rows), so ownership must reset at the switch
                // boundary or the previous character's rows would render
                // under the new character. Same-character reselect keeps
                // the loaded rows and grant flag.
                tracing::debug!(
                    "[ASSETS] clearing assets on character switch from={} to={}",
                    previous_id,
                    character_id
                );
                self.assets = LoadState::Loading;
                self.assets_needs_reauthorize = false;
                // The structure banner's scope fact is per character;
                // never carry it across a switch. Same-character
                // reselect keeps it, like the assets grant flag.
                self.structures_needs_reauthorize = false;
                // Same ownership argument as assets: detail sections are
                // fetched tolerantly, so reset at the switch boundary.
                tracing::debug!(
                    "[CHAR] clearing character details on character switch from={} to={}",
                    previous_id,
                    character_id
                );
                self.character_details = LoadState::Loading;
                // Same ownership argument: the skills bundle carries
                // the previous character's trained levels, which gate
                // fitting resource outputs. Reset at the switch
                // boundary so a replacement active character never
                // inherits them (fitting skill resources design section 3).
                tracing::debug!(
                    "[SKILLS] clearing skills on character switch from={} to={}",
                    previous_id,
                    character_id
                );
                self.skills = LoadState::Loading;
                // Same ownership argument: the loaded bundle carries
                // the previous character's own orders. Selection,
                // region, and search text survive the switch.
                tracing::debug!("[MARKET] clearing market on character switch");
                if self.market_selected_type_id.is_some() {
                    self.market = LoadState::Loading;
                }
                self.market_candidates.clear();
                self.market_lookup_message = None;
                self.market_generation = self.market_generation.wrapping_add(1);
                // Same ownership argument as assets and detail: industry
                // sections are fetched tolerantly, so reset at the switch
                // boundary. Search text and kind filter are view-local
                // and survive, like every other view's filter text.
                tracing::debug!(
                    "[INDUSTRY] clearing industry on character switch from={} to={}",
                    previous_id,
                    character_id
                );
                self.industry = LoadState::Loading;
                // Same ownership argument: colonies are fetched
                // tolerantly and detail is identity-stamped, so
                // reset at the switch boundary.
                tracing::debug!(
                    "[PI] clearing planetary on character switch from={} to={}",
                    previous_id,
                    character_id
                );
                self.planetary = LoadState::Loading;
                self.planetary_selected_planet_id = None;
                self.planetary_detail_fetch_requested = false;
                self.planetary_generation = self.planetary_generation.wrapping_add(1);
                tracing::debug!(
                    "[FITTING] clearing fittings on character switch from={} to={}",
                    previous_id,
                    character_id
                );
                self.fittings = LoadState::Loading;
                self.fittings_selected_fitting_id = None;
                // The imported fitting is per-character working state; never
                // carry it, its error, its owner, or its paste text across a
                // character switch.
                self.fittings_import_text.clear();
                self.fittings_imported = None;
                self.fittings_import_error = None;
                self.fittings_import_owner = None;
                self.fittings_editor_add_name.clear();
                self.fittings_editor_add_quantity.clear();
                self.fittings_editor_error = None;
                self.fittings_import_edited = false;
                self.fittings_editor_quantity.clear();
                self.fittings_editor_name = None;
                self.fittings_browser_section = ImportSection::High;
                self.fittings_browser_search.clear();
                self.fittings_browser_rows.clear();
                self.fittings_browser_rows_section = None;
                self.fittings_ship_search.clear();
                self.fittings_ship_rows.clear();
                self.fittings_ship_rows_built = false;
                // Write design section 3.2: the write state is per
                // character too. An armed confirmation or a queued
                // request must never outlive its character; the
                // in-flight record is deliberately kept (its landing
                // drops whole on the identity mismatch, design
                // section 8 step 2) so it still unblocks the UI.
                self.fittings_write_needs_reauthorize = false;
                self.fittings_write_confirm = None;
                self.fittings_write_requested = None;
                self.fittings_pending_selection = None;
                // Same ownership argument as the fittings blocks:
                // the loaded plan list and every piece of
                // plan working state are stamped for the previous
                // character. `demo_skill_plans` is keyed by
                // character and is deliberately NOT cleared here
                // (the `summaries`/`portraits` keyed-map precedent).
                tracing::debug!(
                    "[PLANS] clearing skill plans on character switch from={} to={}",
                    previous_id,
                    character_id
                );
                self.skill_plans = LoadState::Loading;
                self.skill_plans_owner = None;
                self.selected_skill_plan_id = None;
                self.skill_plan_editor = None;
                self.skill_plan_name_draft.clear();
                self.skill_plan_description_draft.clear();
                self.skill_plan_confirm = None;
                self.skill_plan_action = None;
                self.skill_plan_picker_open = false;
                self.skill_plan_picker_search.clear();
            }
        }
        self.selected_queue_row = 0;
        self.selected_journal_row = 0;
    }

    /// Cycle the active character by `delta` positions (wraps). No-op when
    /// there are no characters.
    pub fn cycle_character(&mut self, delta: isize) {
        if self.characters.is_empty() {
            tracing::debug!("[CHAR] cycle_character with no characters");
            return;
        }
        let len = self.characters.len() as isize;
        let current = self
            .active_character_id
            .and_then(|id| self.characters.iter().position(|c| c.character_id == id))
            .map(|p| p as isize)
            .unwrap_or(0);
        let next = (current + delta).rem_euclid(len) as usize;
        let id = self.characters[next].character_id;
        self.set_active_character(id);
    }

    /// Remove a character locally and pick a new active character when the
    /// removed one was active. Persistence/token cleanup is the
    /// integrator's job via `delete_requested_id`.
    pub fn remove_character(&mut self, character_id: i64) {
        tracing::info!("[CHAR] remove character_id={}", character_id);
        self.characters.retain(|c| c.character_id != character_id);
        self.summaries.remove(&character_id);
        // Demo plans are keyed per character (design section 7):
        // removing a character drops its demo entry too, so a
        // late landing can never resurrect plans for a gone
        // character. Unconditional — harmless for live characters,
        // whose map entries never exist.
        tracing::debug!(
            "[PLANS] dropping demo skill plans of removed character_id={}",
            character_id
        );
        self.demo_skill_plans.remove(&character_id);
        // Image entries are keyed by (kind, id): a character entry
        // drops only with its own character, while a corporation or
        // alliance entry survives while any remaining row still
        // references it. Evaluated against the retained character
        // list above, so a late landing can never resurrect a
        // dropped entry.
        tracing::debug!(
            "[PORTRAIT] dropping image of removed character_id={}",
            character_id
        );
        // A logo also survives while the loaded character detail
        // references it (fresh EVE data the rows may not carry
        // yet) — the same sources `image_id_known` consults.
        let detail_corp = self
            .character_detail
            .as_ready()
            .map(|info| info.corporation_id);
        let detail_alliance = self
            .character_detail
            .as_ready()
            .and_then(|info| info.alliance_id);
        // Standings source, captured before the active-removal
        // reset below (design section 5.3): the retain must see the
        // pre-removal standings exactly as the detail lines do.
        let standing_pairs: Vec<(String, i64)> = self
            .character_details
            .as_ready()
            .and_then(|bundle| bundle.standings.as_ref().ok())
            .map(|standings| {
                standings
                    .iter()
                    .map(|s| (s.from_type.clone(), s.from_id))
                    .collect()
            })
            .unwrap_or_default();
        // Saved-fittings source, captured before the
        // active-removal reset below: the retain must see the
        // pre-removal fittings exactly as the detail lines do.
        let fitting_type_ids: Vec<i64> = self
            .fittings
            .as_ready()
            .and_then(|bundle| bundle.fittings.as_ref().ok())
            .map(|fittings| {
                let mut ids = Vec::new();
                for fitting in fittings {
                    ids.push(fitting.ship_type_id);
                    ids.extend(fitting.items.iter().map(|item| item.type_id));
                }
                ids
            })
            .unwrap_or_default();
        // Loaded-assets source, captured before the active-removal
        // reset below (design asset-icons section 4): the retain
        // must see the pre-removal holdings exactly as the detail
        // lines do.
        let asset_type_ids: Vec<i64> = self
            .assets
            .as_ready()
            .map(|data| data.items.iter().map(|item| item.type_id).collect())
            .unwrap_or_default();
        // Selected-market-type source (design market-icon section 3):
        // the retain must see the pre-removal selection exactly as
        // the detail lines do; the selection itself survives the
        // active-removal reset below.
        let market_type_id = self.market_selected_type_id;
        // Bundled-skill-catalogue source (design skill-icons
        // section 4): static bundled data, identical before and
        // after any removal.
        let skill_catalogue_type_ids: Vec<i64> =
            self.skill_catalogue_type_ids.iter().copied().collect();
        let characters = &self.characters;
        let logo_known = |kind: &ImageKind, id: i64| match kind {
            ImageKind::Character => id != character_id,
            ImageKind::Corporation => {
                characters.iter().any(|c| c.corporation_id == id)
                    || detail_corp == Some(id)
                    || standing_pairs.iter().any(|(from_type, from_id)| {
                        *from_id == id && (from_type == "npc_corp" || from_type == "corporation")
                    })
            }
            ImageKind::Alliance => {
                characters.iter().any(|c| c.alliance_id == Some(id)) || detail_alliance == Some(id)
            }
            ImageKind::Faction => standing_pairs
                .iter()
                .any(|(from_type, from_id)| *from_id == id && from_type == "faction"),
            ImageKind::Type => {
                fitting_type_ids.contains(&id)
                    || asset_type_ids.contains(&id)
                    || market_type_id == Some(id)
                    || skill_catalogue_type_ids.contains(&id)
            }
        };
        self.portraits.retain(|(kind, id), _| logo_known(kind, *id));
        self.portrait_requests
            .retain(|(kind, id)| logo_known(kind, *id));
        if self.active_character_id == Some(character_id) {
            self.active_character_id = None;
            // The removed character owned the loaded assets; never show
            // them under the replacement active character. set_active
            // below cannot detect this (previous is already None), and
            // the is_empty branch further down overrides this to Empty.
            tracing::debug!("[ASSETS] clearing assets of removed active character");
            self.assets = LoadState::Loading;
            tracing::debug!("[CHAR] clearing character details of removed active character");
            self.character_details = LoadState::Loading;
            tracing::debug!("[SKILLS] clearing skills of removed active character");
            self.skills = LoadState::Loading;
            tracing::debug!("[MARKET] clearing market of removed active character");
            if self.market_selected_type_id.is_some() {
                self.market = LoadState::Loading;
            }
            self.market_candidates.clear();
            self.market_lookup_message = None;
            self.market_generation = self.market_generation.wrapping_add(1);
            tracing::debug!("[INDUSTRY] clearing industry of removed active character");
            self.industry = LoadState::Loading;
            tracing::debug!("[PI] clearing planetary of removed active character");
            self.planetary = LoadState::Loading;
            self.planetary_selected_planet_id = None;
            self.planetary_detail_fetch_requested = false;
            self.planetary_generation = self.planetary_generation.wrapping_add(1);
            tracing::debug!("[FITTING] clearing fittings of removed active character");
            self.fittings = LoadState::Loading;
            self.fittings_selected_fitting_id = None;
            // The removed character owned the import state; never show it
            // under the replacement active character.
            self.fittings_import_text.clear();
            self.fittings_imported = None;
            self.fittings_import_error = None;
            self.fittings_import_owner = None;
            self.fittings_editor_add_name.clear();
            self.fittings_editor_add_quantity.clear();
            self.fittings_editor_error = None;
            self.fittings_import_edited = false;
            self.fittings_editor_quantity.clear();
            self.fittings_editor_name = None;
            self.fittings_browser_section = ImportSection::High;
            self.fittings_browser_search.clear();
            self.fittings_browser_rows.clear();
            self.fittings_browser_rows_section = None;
            self.fittings_ship_search.clear();
            self.fittings_ship_rows.clear();
            self.fittings_ship_rows_built = false;
            // Write state reset (design section 3.2), same
            // ownership argument as the import state.
            self.fittings_write_needs_reauthorize = false;
            self.fittings_write_confirm = None;
            self.fittings_write_requested = None;
            self.fittings_pending_selection = None;
            // Plan state reset (design section 7): the removed
            // active character owned the loaded list and every
            // piece of working state.
            tracing::debug!("[PLANS] clearing skill plans of removed active character");
            self.skill_plans = LoadState::Loading;
            self.skill_plans_owner = None;
            self.selected_skill_plan_id = None;
            self.skill_plan_editor = None;
            self.skill_plan_name_draft.clear();
            self.skill_plan_description_draft.clear();
            self.skill_plan_confirm = None;
            self.skill_plan_action = None;
            self.skill_plan_picker_open = false;
            self.skill_plan_picker_search.clear();
            if let Some(first) = self.characters.first().map(|c| c.character_id) {
                self.set_active_character(first);
            }
        }
        self.assets_needs_reauthorize = false;
        self.structures_needs_reauthorize = false;
        if self.stepup_requested.as_ref().map(|r| r.character_id) == Some(character_id) {
            tracing::debug!(
                "[AUTH] clearing pending step-up request for removed character_id={}",
                character_id
            );
            self.stepup_requested = None;
        }
        if self.characters.is_empty() {
            tracing::debug!("[PORTRAIT] clearing portraits when no characters remain");
            self.portraits.clear();
            self.portrait_requests.clear();
            self.skills = LoadState::Empty;
            self.wallet = LoadState::Empty;
            self.assets = LoadState::Empty;
            self.character_detail = LoadState::Empty;
            self.character_details = LoadState::Empty;
            self.market = LoadState::Empty;
            self.market_generation = self.market_generation.wrapping_add(1);
            self.industry = LoadState::Empty;
            self.planetary = LoadState::Empty;
            self.planetary_selected_planet_id = None;
            self.planetary_detail_fetch_requested = false;
            self.planetary_generation = self.planetary_generation.wrapping_add(1);
            self.fittings = LoadState::Empty;
            self.fittings_selected_fitting_id = None;
            self.fittings_import_text.clear();
            self.fittings_imported = None;
            self.fittings_import_error = None;
            self.fittings_import_owner = None;
            self.fittings_editor_add_name.clear();
            self.fittings_editor_add_quantity.clear();
            self.fittings_editor_error = None;
            self.fittings_import_edited = false;
            self.fittings_editor_quantity.clear();
            self.fittings_editor_name = None;
            self.fittings_browser_section = ImportSection::High;
            self.fittings_browser_search.clear();
            self.fittings_browser_rows.clear();
            self.fittings_browser_rows_section = None;
            self.fittings_ship_search.clear();
            self.fittings_ship_rows.clear();
            self.fittings_ship_rows_built = false;
            self.fittings_write_needs_reauthorize = false;
            self.fittings_write_confirm = None;
            self.fittings_write_requested = None;
            self.fittings_pending_selection = None;
            tracing::debug!("[PLANS] clearing skill plans when no characters remain");
            self.skill_plans = LoadState::Empty;
            self.skill_plans_owner = None;
            self.selected_skill_plan_id = None;
            self.skill_plan_editor = None;
            self.skill_plan_name_draft.clear();
            self.skill_plan_description_draft.clear();
            self.skill_plan_confirm = None;
            self.skill_plan_action = None;
            self.skill_plan_picker_open = false;
            self.skill_plan_picker_search.clear();
            self.dashboard = LoadState::Empty;
        }
    }

    pub fn switch_view(&mut self, view: View) {
        if self.view != view {
            tracing::debug!("[UI] switch view to {}", view.label());
        }
        self.view = view;
    }

    pub fn request_refresh(&mut self, reason: &str) {
        tracing::info!("[UI] refresh requested reason={}", reason);
        self.refresh_requested = true;
        self.status_message = if self.demo {
            "Demo mode: showing bundled sample data (no network refresh).".to_string()
        } else {
            "Refresh requested...".to_string()
        };
    }

    /// Whether one `(kind, id)` names an entity this state knows
    /// from EVE's own data: a character row for `Character`, a row
    /// `corporation_id`, the loaded public info, or a standings
    /// entry for `Corporation`, a row `alliance_id` or the loaded
    /// public info for `Alliance`, the loaded standings only for
    /// `Faction`, and the active character's loaded saved fittings
    /// (ship and fitted items), the active character's loaded
    /// assets, the selected market type, or one of the bundled
    /// skill catalogue's skill types (static bundled data
    /// installed at startup; the one non-loaded-state source,
    /// locked by the skill-icons design section 3) for `Type`.
    /// This is the single definition of "this id may be
    /// fetched", shared by `request_portrait`, the shell landing,
    /// and texture prune. The dashboard is deliberately not
    /// consulted: every landing writes the same info to it and to
    /// `character_detail` together, so it can know nothing the
    /// other two lack.
    pub fn image_id_known(&self, kind: ImageKind, id: i64) -> bool {
        match kind {
            ImageKind::Character => self.characters.iter().any(|c| c.character_id == id),
            ImageKind::Corporation => {
                self.characters.iter().any(|c| c.corporation_id == id)
                    || self
                        .character_detail
                        .as_ready()
                        .is_some_and(|info| info.corporation_id == id)
                    || self.standing_known(kind, id)
            }
            ImageKind::Alliance => {
                self.characters.iter().any(|c| c.alliance_id == Some(id))
                    || self
                        .character_detail
                        .as_ready()
                        .is_some_and(|info| info.alliance_id == Some(id))
            }
            ImageKind::Faction => self.standing_known(kind, id),
            ImageKind::Type => {
                self.fitting_type_known(id)
                    || self.asset_type_known(id)
                    || self.market_selected_type_id == Some(id)
                    || self.skill_catalogue_type_known(id)
            }
        }
    }

    /// Whether the active character's loaded saved fittings name
    /// this item type (a fitting's ship or any fitted item).
    /// EVE-sourced state only: the imported fitting, the loaded
    /// assets, the market selection, the bundled skill catalogue,
    /// and the bundled catalogue are deliberately not consulted,
    /// so nothing user-typed ever authorizes a fetch.
    fn fitting_type_known(&self, id: i64) -> bool {
        self.fittings
            .as_ready()
            .and_then(|bundle| bundle.fittings.as_ref().ok())
            .is_some_and(|fittings| {
                fittings.iter().any(|fitting| {
                    fitting.ship_type_id == id
                        || fitting.items.iter().any(|item| item.type_id == id)
                })
            })
    }

    /// Whether the active character's loaded assets name this item
    /// type (any held row's type). EVE-sourced state only: the
    /// assets search text and the bundled catalogue are deliberately
    /// not consulted, so nothing user-typed ever authorizes a fetch.
    fn asset_type_known(&self, id: i64) -> bool {
        self.assets
            .as_ready()
            .is_some_and(|data| data.items.iter().any(|item| item.type_id == id))
    }

    /// Whether this item type is one of the bundled skill
    /// catalogue's skill types (installed once at startup from
    /// the SDE extract). Static bundled data, deliberately not
    /// character state: the skills catalogue renders bundled
    /// types no loaded state names (untrained skills), and no
    /// user input can add an id to this set — the catalogue
    /// search only filters bundled rows by name.
    fn skill_catalogue_type_known(&self, id: i64) -> bool {
        self.skill_catalogue_type_ids.contains(&id)
    }

    /// Install the bundled skill catalogue's type ids as a
    /// fetch-authorization source (design skill-icons section
    /// 4). Called once at startup with the already-loaded SDE;
    /// an SDE that failed to load installs an empty set and
    /// authorizes nothing.
    pub fn install_skill_catalogue_type_ids(&mut self, sde: &Sde) {
        self.skill_catalogue_type_ids = sde.types.iter().map(|t| t.type_id).collect();
        tracing::info!(
            "[SKILLS] skill catalogue guard installed count={}",
            self.skill_catalogue_type_ids.len()
        );
    }

    /// Whether the loaded standings name `(kind, id)`: a `faction`
    /// standing for `Faction`, an `npc_corp` or `corporation`
    /// standing for `Corporation`, nothing for any other kind.
    fn standing_known(&self, kind: ImageKind, id: i64) -> bool {
        let wanted: &[&str] = match kind {
            ImageKind::Faction => &["faction"],
            ImageKind::Corporation => &["npc_corp", "corporation"],
            ImageKind::Character | ImageKind::Alliance | ImageKind::Type => return false,
        };
        self.character_details
            .as_ready()
            .and_then(|bundle| bundle.standings.as_ref().ok())
            .is_some_and(|standings| {
                standings
                    .iter()
                    .any(|s| s.from_id == id && wanted.contains(&s.from_type.as_str()))
            })
    }

    /// Current image state for one `(kind, id)`; `NotRequested` when
    /// the key has no entry yet.
    pub fn portrait_state(&self, kind: ImageKind, id: i64) -> &PortraitState {
        self.portraits
            .get(&(kind, id))
            .unwrap_or(&PortraitState::NotRequested)
    }

    /// Queue one image fetch for a known `(kind, id)`. Ids at or
    /// below zero and ids unknown per `image_id_known` are ignored;
    /// `Ready`/`Loading` entries no-op; `NotRequested` and `Failed`
    /// entries move to `Loading` with one queued key (deduped). The
    /// shell drains with `take_portrait_requests`.
    pub fn request_portrait(&mut self, kind: ImageKind, id: i64) {
        if id <= 0 {
            tracing::warn!(
                "[PORTRAIT] ignoring image request for nonpositive id kind={} id={}",
                kind.as_str(),
                id
            );
            return;
        }
        if !self.image_id_known(kind, id) {
            tracing::warn!(
                "[PORTRAIT] ignoring image request for unknown kind={} id={}",
                kind.as_str(),
                id
            );
            return;
        }
        match self.portrait_state(kind, id) {
            PortraitState::Ready(_) | PortraitState::Loading => {
                tracing::debug!(
                    "[PORTRAIT] image request skipped kind={} id={}",
                    kind.as_str(),
                    id
                );
            }
            PortraitState::NotRequested | PortraitState::Failed => {
                tracing::info!(
                    "[PORTRAIT] image requested kind={} id={}",
                    kind.as_str(),
                    id
                );
                self.portraits.insert((kind, id), PortraitState::Loading);
                if !self.portrait_requests.contains(&(kind, id)) {
                    self.portrait_requests.push((kind, id));
                }
            }
        }
    }

    /// Drain the queued image requests (shell side). The queue is
    /// cleared even when the shell ends up spawning nothing (demo
    /// mode, missing backends): a stale key must never fetch later.
    pub fn take_portrait_requests(&mut self) -> Vec<(ImageKind, i64)> {
        let drained = std::mem::take(&mut self.portrait_requests);
        tracing::debug!("[PORTRAIT] image requests drained count={}", drained.len());
        drained
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fitting::eft::{ImportFormat, ImportReport, ImportSection, ImportedItem};

    fn row(id: i64, name: &str) -> CharacterRow {
        CharacterRow {
            character_id: id,
            name: name.to_string(),
            corporation_id: 1000166,
            alliance_id: None,
            is_active: false,
        }
    }

    #[test]
    fn view_navigation_wraps_and_indexes() {
        assert_eq!(View::Dashboard.next(), View::Characters);
        // Exploration is appended after Settings (design section 6.1):
        // every index 0-9 is unchanged, Settings.next() is now
        // Exploration and Exploration wraps back to Dashboard.
        assert_eq!(View::Settings.next(), View::Exploration);
        assert_eq!(View::Exploration.next(), View::Dashboard);
        assert_eq!(View::Dashboard.previous(), View::Exploration);
        assert_eq!(View::Exploration.previous(), View::Settings);
        assert_eq!(View::ALL.len(), 11);
        assert_eq!(View::from_index(3), Some(View::Wallet));
        assert_eq!(View::from_index(4), Some(View::Assets));
        assert_eq!(View::from_index(5), Some(View::Market));
        assert_eq!(View::from_index(6), Some(View::Industry));
        assert_eq!(View::from_index(7), Some(View::Planets));
        assert_eq!(View::from_index(8), Some(View::Fittings));
        assert_eq!(View::from_index(9), Some(View::Settings));
        assert_eq!(View::from_index(10), Some(View::Exploration));
        assert_eq!(View::from_index(11), None);
        assert_eq!(View::Wallet.index(), 3);
        assert_eq!(View::Assets.index(), 4);
        assert_eq!(View::Market.index(), 5);
        assert_eq!(View::Industry.index(), 6);
        assert_eq!(View::Planets.index(), 7);
        assert_eq!(View::Fittings.index(), 8);
        assert_eq!(View::Settings.index(), 9);
        assert_eq!(View::Exploration.index(), 10);
        assert_eq!(View::Wallet.next(), View::Assets);
        assert_eq!(View::Assets.next(), View::Market);
        assert_eq!(View::Market.next(), View::Industry);
        assert_eq!(View::Industry.next(), View::Planets);
        assert_eq!(View::Planets.next(), View::Fittings);
        assert_eq!(View::Fittings.next(), View::Settings);
        assert_eq!(View::Settings.previous(), View::Fittings);
        assert_eq!(View::Fittings.previous(), View::Planets);
        assert_eq!(View::Planets.previous(), View::Industry);
        assert_eq!(View::Assets.previous(), View::Wallet);
    }

    #[test]
    fn load_state_helpers_cover_every_variant() {
        let ready: LoadState<i32> = LoadState::Ready(7);
        assert!(ready.is_ready());
        assert_eq!(ready.as_ready(), Some(&7));
        assert_eq!(ready.error_message(), None);
        let err: LoadState<i32> = LoadState::Error("boom".to_string());
        assert_eq!(err.error_message(), Some("boom"));
        assert_eq!(err.as_ready(), None);
        assert!(LoadState::<i32>::Loading.is_loading());
        assert!(!LoadState::<i32>::Empty.is_ready());
    }

    #[test]
    fn active_character_cycle_and_remove_never_panic() {
        let mut state = AppState::new(false);
        state.cycle_character(1); // empty: no-op
        assert_eq!(state.active_character_id, None);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        state.cycle_character(1);
        assert_eq!(state.active_character_id, Some(2));
        state.cycle_character(-2);
        assert_eq!(state.active_character_id, Some(3));
        state.set_active_character(999); // unknown id ignored
        assert_eq!(state.active_character_id, Some(3));
        state.remove_character(3); // active removed -> first becomes active
        assert_eq!(state.active_character_id, Some(1));
        state.assets_needs_reauthorize = true;
        state.remove_character(1);
        assert!(!state.assets_needs_reauthorize, "flag clears on removal");
        state.remove_character(2);
        assert_eq!(state.active_character_id, None);
        assert!(matches!(state.wallet, LoadState::Empty));
        assert!(matches!(state.assets, LoadState::Empty));
        assert!(matches!(state.character_details, LoadState::Empty));
    }

    #[test]
    fn switching_character_clears_stale_assets() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.assets = LoadState::Ready(AssetsData {
            items: Vec::new(),
            custom_names: Default::default(),
        });
        state.assets_needs_reauthorize = true;
        // Reselecting the same character keeps its rows and grant flag.
        state.set_active_character(1);
        assert!(state.assets.is_ready());
        assert!(state.assets_needs_reauthorize);
        // Switching clears them: tolerant sub-fetch errors must never
        // present character One's rows as character Two's.
        state.set_active_character(2);
        assert!(matches!(state.assets, LoadState::Loading));
        assert!(!state.assets_needs_reauthorize);
    }

    #[test]
    fn structures_flag_clears_on_switch_and_removal() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        state.structures_needs_reauthorize = true;
        // Reselecting the same character keeps the banner state.
        state.set_active_character(1);
        assert!(state.structures_needs_reauthorize);
        // Switching to a different character clears it: the scope
        // fact is per character.
        state.set_active_character(2);
        assert!(!state.structures_needs_reauthorize);
        // Removing a character clears it too, mirroring the assets
        // flag.
        state.structures_needs_reauthorize = true;
        state.remove_character(3);
        assert!(
            !state.structures_needs_reauthorize,
            "flag clears on removal"
        );
    }

    fn detail_bundle(intelligence: i32) -> CharacterDetailData {
        CharacterDetailData {
            attributes: Ok(CharacterAttributes {
                intelligence,
                ..Default::default()
            }),
            implants: Ok(Vec::new()),
            clones: Ok(CharacterClones::default()),
            standings: Ok(Vec::new()),
            location: Ok(CharacterLocation::default()),
            ship: Ok(CharacterShip::default()),
            online: Ok(CharacterOnline::default()),
        }
    }

    fn reauth_error() -> SectionError {
        SectionError {
            message: "forbidden".to_string(),
            needs_reauthorize: true,
        }
    }

    #[test]
    fn switching_character_clears_stale_character_details() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        let mut bundle = detail_bundle(27);
        bundle.clones = Err(reauth_error());
        state.character_details = LoadState::Ready(bundle);
        // Same-character reselect keeps the bundle and its step-up need.
        state.set_active_character(1);
        let kept = state
            .character_details
            .as_ready()
            .expect("reselect keeps details");
        assert_eq!(
            kept.attributes
                .as_ref()
                .expect("attributes ok")
                .intelligence,
            27
        );
        assert!(kept.needs_detail_stepup());
        // Switching clears them, mirroring assets.
        state.set_active_character(2);
        assert!(matches!(state.character_details, LoadState::Loading));
    }

    #[test]
    fn removing_active_character_clears_character_details() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        state.character_details = LoadState::Ready(detail_bundle(27));
        // Removing a non-active character leaves the bundle ready.
        state.remove_character(3);
        assert!(state.character_details.is_ready());
        // Removing the active character never shows its bundle under the
        // replacement character.
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(2));
        assert!(matches!(state.character_details, LoadState::Loading));
        // Removing the last character empties it.
        state.character_details = LoadState::Ready(detail_bundle(27));
        state.remove_character(2);
        assert!(state.characters.is_empty());
        assert!(matches!(state.character_details, LoadState::Empty));
    }

    fn test_plan(plan_id: i64, character_id: i64, name: &str) -> SkillPlan {
        SkillPlan {
            plan_id,
            character_id,
            name: name.to_string(),
            description: String::new(),
            created_at: "2026-11-15T00:00:00Z".to_string(),
            updated_at: "2026-11-15T00:00:00Z".to_string(),
            entries: vec![],
        }
    }

    /// Saturate every skill-plan working field so the reset tests
    /// prove each one clears, not just the loaded list.
    fn fill_skill_plan_state(state: &mut AppState, character_id: i64) {
        state.skill_plans = LoadState::Ready(vec![test_plan(7, character_id, "PvP")]);
        state.skill_plans_owner = Some(character_id);
        state.selected_skill_plan_id = Some(7);
        state.skill_plan_editor = Some(SkillPlanEditor::Create { character_id });
        state.skill_plan_name_draft = "Draft name".to_string();
        state.skill_plan_description_draft = "Draft description".to_string();
        state.skill_plan_confirm = Some(SkillPlanConfirm::DeletePlan {
            character_id,
            plan_id: 7,
        });
        state.skill_plan_action = Some(SkillPlanAction::DeletePlan {
            character_id,
            plan_id: 7,
        });
        state.skill_plan_picker_open = true;
        state.skill_plan_picker_search = "hybrid".to_string();
    }

    fn assert_skill_plan_state_cleared(state: &AppState, loaded: LoadState<Vec<SkillPlan>>) {
        // Loading (switch/removal) or Empty (no characters) — the
        // two states the three reset sites set (design section 7).
        match (&state.skill_plans, &loaded) {
            (LoadState::Loading, LoadState::Loading) => {}
            (LoadState::Empty, LoadState::Empty) => {}
            (actual, expected) => {
                panic!("skill_plans state mismatch: got {actual:?}, want {expected:?}")
            }
        }
        assert_eq!(state.skill_plans_owner, None);
        assert_eq!(state.selected_skill_plan_id, None);
        assert_eq!(state.skill_plan_editor, None);
        assert!(state.skill_plan_name_draft.is_empty());
        assert!(state.skill_plan_description_draft.is_empty());
        assert_eq!(state.skill_plan_confirm, None);
        assert_eq!(state.skill_plan_action, None);
        assert!(!state.skill_plan_picker_open);
        assert!(state.skill_plan_picker_search.is_empty());
    }

    // T16: switching_character_clears_skill_plan_state,
    // removing_active_character_clears_skill_plan_state,
    // removing_last_character_empties_skill_plan_state
    // (design section 12) — the three reset sites, in the shape
    // of the existing character-details reset tests. Companion:
    // reselecting_same_character_keeps_skill_plan_state.
    #[test]
    fn switching_character_clears_skill_plan_state() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        fill_skill_plan_state(&mut state, 1);
        // Same-character reselect keeps everything.
        state.set_active_character(1);
        assert!(state.skill_plans.is_ready());
        assert_eq!(state.skill_plans_owner, Some(1));
        assert_eq!(state.selected_skill_plan_id, Some(7));
        // Switching to a different character clears the whole
        // working set (the demo map is covered by T17).
        state.set_active_character(2);
        assert_skill_plan_state_cleared(&state, LoadState::<Vec<SkillPlan>>::Loading);
    }

    #[test]
    fn removing_active_character_clears_skill_plan_state() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        fill_skill_plan_state(&mut state, 1);
        // Removing a non-active character leaves the plans ready.
        state.remove_character(3);
        assert!(state.skill_plans.is_ready());
        assert_eq!(state.skill_plans_owner, Some(1));
        // Removing the active character never shows its plans
        // under the replacement character.
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(2));
        assert_skill_plan_state_cleared(&state, LoadState::<Vec<SkillPlan>>::Loading);
    }

    #[test]
    fn removing_last_character_empties_skill_plan_state() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One")];
        state.set_active_character(1);
        fill_skill_plan_state(&mut state, 1);
        // Removing the last character empties the plans.
        state.remove_character(1);
        assert!(state.characters.is_empty());
        assert_skill_plan_state_cleared(&state, LoadState::<Vec<SkillPlan>>::Empty);
    }

    // T17: demo_plans_survive_demo_character_switch (design
    // section 12): the keyed demo map is untouched by a switch;
    // a removed character's entry is dropped.
    #[test]
    fn demo_plans_survive_demo_character_switch() {
        let mut state = AppState::new(true);
        state.characters = vec![row(90000001, "Demo One"), row(90000002, "Demo Two")];
        state.set_active_character(90000001);
        state
            .demo_skill_plans
            .insert(90000001, vec![test_plan(1, 90000001, "Demo PvP")]);
        state.demo_next_plan_id = 2;
        // Switching keeps the demo entry (keyed-map precedent).
        state.set_active_character(90000002);
        let kept = state
            .demo_skill_plans
            .get(&90000001)
            .expect("demo entry survives switch");
        assert_eq!(kept.len(), 1);
        assert_eq!(kept[0].name, "Demo PvP");
        assert_eq!(state.demo_next_plan_id, 2, "counter is session-wide");
        // Removing the demo character drops its entry.
        state.remove_character(90000001);
        assert!(!state.demo_skill_plans.contains_key(&90000001));
        assert!(state.demo_skill_plans.is_empty());
    }

    #[test]
    fn needs_detail_stepup_only_for_protected_sections() {
        assert!(!detail_bundle(27).needs_detail_stepup(), "all-Ok bundle");
        let mut only_attributes = detail_bundle(27);
        only_attributes.attributes = Err(reauth_error());
        assert!(!only_attributes.needs_detail_stepup());
        let mut only_implants = detail_bundle(27);
        only_implants.implants = Err(reauth_error());
        assert!(!only_implants.needs_detail_stepup());
        let mut plain_failure = detail_bundle(27);
        plain_failure.clones = Err(SectionError {
            message: "timeout".to_string(),
            needs_reauthorize: false,
        });
        assert!(!plain_failure.needs_detail_stepup());
        let mut clones = detail_bundle(27);
        clones.clones = Err(reauth_error());
        assert!(clones.needs_detail_stepup(), "clones");
        let mut standings = detail_bundle(27);
        standings.standings = Err(reauth_error());
        assert!(standings.needs_detail_stepup(), "standings");
        let mut location = detail_bundle(27);
        location.location = Err(reauth_error());
        assert!(location.needs_detail_stepup(), "location");
        let mut ship = detail_bundle(27);
        ship.ship = Err(reauth_error());
        assert!(ship.needs_detail_stepup(), "ship");
        let mut online = detail_bundle(27);
        online.online = Err(reauth_error());
        assert!(online.needs_detail_stepup(), "online");
    }

    #[test]
    fn summary_location_prefers_docked_then_solar() {
        assert_eq!(
            summary_location_name(Some("Jita IV Station"), Some("Jita")).as_deref(),
            Some("Jita IV Station")
        );
        assert_eq!(
            summary_location_name(None, Some("Jita")).as_deref(),
            Some("Jita")
        );
        assert_eq!(summary_location_name(None, None), None);
    }

    #[test]
    fn ship_display_name_combines_custom_and_type() {
        assert_eq!(
            ship_display_name("Fixture Frigate", Some("Rifter")).as_deref(),
            Some("Fixture Frigate (Rifter)")
        );
        assert_eq!(
            ship_display_name("Rifter", Some("Rifter")).as_deref(),
            Some("Rifter"),
            "custom equal to type shows once"
        );
        assert_eq!(
            ship_display_name("Fixture Frigate", None).as_deref(),
            Some("Fixture Frigate")
        );
        assert_eq!(
            ship_display_name("", Some("Rifter")).as_deref(),
            Some("Rifter")
        );
        assert_eq!(
            ship_display_name("   ", Some("Rifter")).as_deref(),
            Some("Rifter"),
            "trimmed-empty custom is absent"
        );
        assert_eq!(
            ship_display_name(" None ", Some("Rifter")).as_deref(),
            Some("Rifter"),
            "\"None\" placeholder is absent"
        );
        assert_eq!(ship_display_name("", None), None);
        assert_eq!(ship_display_name("None", None), None);
    }

    #[test]
    fn stepup_request_default_set_and_clear_semantics() {
        // Default (including demo entry) is None.
        assert_eq!(AppState::new(false).stepup_requested, None);
        assert_eq!(AppState::new(true).stepup_requested, None);

        // new() copies id + scopes in order.
        let request = StepUpRequest::new(42, &["esi-assets.read_assets.v1", "scope-b"]);
        assert_eq!(request.character_id, 42);
        assert_eq!(
            request.scopes,
            vec![
                "esi-assets.read_assets.v1".to_string(),
                "scope-b".to_string()
            ]
        );

        // Set on request; set_active_character does not touch the flag
        // (design section 3: the request names its own character).
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.stepup_requested = Some(StepUpRequest::new(1, &["esi-assets.read_assets.v1"]));
        state.set_active_character(2);
        assert_eq!(
            state.stepup_requested,
            Some(StepUpRequest::new(1, &["esi-assets.read_assets.v1"])),
            "character switch keeps the named step-up request"
        );

        // Removing a different character keeps the pending request.
        state.remove_character(2);
        assert!(state.stepup_requested.is_some());

        // Removing the named character clears it.
        state.remove_character(1);
        assert_eq!(state.stepup_requested, None);
    }

    fn market_bundle(character_id: Option<i64>) -> MarketData {
        MarketData {
            selection: MarketSelection {
                type_id: 34,
                type_name: "Tritanium".to_string(),
                region_id: DEFAULT_MARKET_REGION_ID,
                character_id,
            },
            public_orders: Ok(PublicOrdersData::default()),
            history: Ok(Vec::new()),
            character_orders: Ok(CharacterOrdersData::default()),
        }
    }

    #[test]
    fn market_defaults_start_on_the_forge_with_no_selection() {
        for demo in [false, true] {
            let state = AppState::new(demo);
            assert_eq!(state.market_region_id, DEFAULT_MARKET_REGION_ID);
            assert_eq!(
                market_region_name(state.market_region_id),
                Some("The Forge (Jita)")
            );
            assert_eq!(state.market_selected_type_id, None);
            assert_eq!(state.market_generation, 0);
            assert!(!state.market_fetch_requested);
            assert_eq!(state.market_lookup_requested, None);
        }
        assert_eq!(market_region_name(42), None);
    }

    #[test]
    fn trade_calculator_drafts_seed_empty_prices_and_starting_fees() {
        for demo in [false, true] {
            let state = AppState::new(demo);
            assert_eq!(state.market_trade_buy_price, "");
            assert_eq!(state.market_trade_sell_price, "");
            assert_eq!(
                state.market_trade_broker_fee_percent,
                format!("{:.1}", DEFAULT_BROKER_FEE_PERCENT)
            );
            assert_eq!(
                state.market_trade_sales_tax_percent,
                format!("{:.1}", DEFAULT_SALES_TAX_PERCENT)
            );
            assert_eq!(state.market_trade_broker_fee_percent, "1.0");
            assert_eq!(state.market_trade_sales_tax_percent, "2.0");
        }
    }

    #[test]
    fn invention_calculator_drafts_seed_from_pure_module_constants() {
        for demo in [false, true] {
            let state = AppState::new(demo);
            assert_eq!(
                state.industry_invention_base_probability,
                format!("{:.2}", DEFAULT_BASE_PROBABILITY)
            );
            assert_eq!(
                state.industry_invention_encryption_skill,
                DEFAULT_SKILL_LEVEL.to_string()
            );
            assert_eq!(
                state.industry_invention_datacore_skill1,
                DEFAULT_SKILL_LEVEL.to_string()
            );
            assert_eq!(
                state.industry_invention_datacore_skill2,
                DEFAULT_SKILL_LEVEL.to_string()
            );
            assert_eq!(
                state.industry_invention_decryptor_multiplier,
                format!("{:.1}", DEFAULT_DECRYPTOR_MULTIPLIER)
            );
            assert_eq!(state.industry_invention_base_probability, "0.30");
            assert_eq!(state.industry_invention_encryption_skill, "4");
            assert_eq!(state.industry_invention_datacore_skill1, "4");
            assert_eq!(state.industry_invention_datacore_skill2, "4");
            assert_eq!(state.industry_invention_decryptor_multiplier, "1.0");
        }
    }

    #[test]
    fn invention_calculator_drafts_survive_character_switch() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.industry_invention_base_probability = "0.40".to_string();
        state.industry_invention_encryption_skill = "5".to_string();
        state.industry_invention_datacore_skill1 = "3".to_string();
        state.industry_invention_datacore_skill2 = "2".to_string();
        state.industry_invention_decryptor_multiplier = "0.6".to_string();
        // Same-character reselect and a character switch both leave
        // all five drafts unchanged.
        state.set_active_character(1);
        state.set_active_character(2);
        assert_eq!(state.industry_invention_base_probability, "0.40");
        assert_eq!(state.industry_invention_encryption_skill, "5");
        assert_eq!(state.industry_invention_datacore_skill1, "3");
        assert_eq!(state.industry_invention_datacore_skill2, "2");
        assert_eq!(state.industry_invention_decryptor_multiplier, "0.6");
    }

    #[test]
    fn reaction_calculator_drafts_seed_from_pure_module_constants() {
        for demo in [false, true] {
            let state = AppState::new(demo);
            assert_eq!(state.industry_reaction_search, "");
            assert_eq!(state.industry_reaction_selected_type_id, None);
            assert_eq!(state.industry_reaction_runs, DEFAULT_RUNS.to_string());
            assert_eq!(state.industry_reaction_runs, "1");
            assert_eq!(
                state.industry_reaction_facility_bonus_percent,
                format!("{:.1}", DEFAULT_FACILITY_BONUS_PERCENT)
            );
            assert_eq!(state.industry_reaction_facility_bonus_percent, "0.0");
        }
    }

    #[test]
    fn reaction_calculator_drafts_survive_character_switch() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.industry_reaction_search = "carbon".to_string();
        state.industry_reaction_selected_type_id = Some(57490);
        state.industry_reaction_runs = "10".to_string();
        state.industry_reaction_facility_bonus_percent = "4.8".to_string();
        state.set_active_character(1);
        state.set_active_character(2);
        assert_eq!(state.industry_reaction_search, "carbon");
        assert_eq!(state.industry_reaction_selected_type_id, Some(57490));
        assert_eq!(state.industry_reaction_runs, "10");
        assert_eq!(state.industry_reaction_facility_bonus_percent, "4.8");
    }

    #[test]
    fn production_chain_drafts_seed_from_pure_module_constants() {
        for demo in [false, true] {
            let state = AppState::new(demo);
            assert_eq!(state.industry_chain_search, "");
            assert_eq!(state.industry_chain_selected_type_id, None);
            assert_eq!(state.industry_chain_quantity, DEFAULT_QUANTITY.to_string());
            assert_eq!(state.industry_chain_quantity, "1");
        }
    }

    #[test]
    fn production_chain_drafts_survive_character_switch() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.industry_chain_search = "orca".to_string();
        state.industry_chain_selected_type_id = Some(28606);
        state.industry_chain_quantity = "3".to_string();
        state.set_active_character(1);
        state.set_active_character(2);
        assert_eq!(state.industry_chain_search, "orca");
        assert_eq!(state.industry_chain_selected_type_id, Some(28606));
        assert_eq!(state.industry_chain_quantity, "3");
    }

    #[test]
    fn trade_calculator_drafts_survive_selection_and_region_changes() {
        let mut state = AppState::new(false);
        state.market_trade_buy_price = "100".to_string();
        state.market_trade_sell_price = "120".to_string();
        state.market_trade_broker_fee_percent = "2.5".to_string();
        state.market_trade_sales_tax_percent = "4.0".to_string();
        state.set_market_selection(34, "Tritanium".to_string());
        state.set_market_region(10000043);
        assert_eq!(state.market_trade_buy_price, "100");
        assert_eq!(state.market_trade_sell_price, "120");
        assert_eq!(state.market_trade_broker_fee_percent, "2.5");
        assert_eq!(state.market_trade_sales_tax_percent, "4.0");
    }

    #[test]
    fn market_selection_change_loads_reselect_keeps_rows() {
        let mut state = AppState::new(false);
        state.set_market_selection(34, "Tritanium".to_string());
        assert!(matches!(state.market, LoadState::Loading));
        assert_eq!(state.market_generation, 1);
        assert!(state.market_fetch_requested);
        state.market = LoadState::Ready(market_bundle(None));
        state.market_fetch_requested = false;
        // Reselect keeps rows, still bumps generation and refetches.
        state.set_market_selection(34, "Tritanium".to_string());
        assert!(state.market.is_ready());
        assert_eq!(state.market_generation, 2);
        assert!(state.market_fetch_requested);
        // A different type discards the bundle.
        state.set_market_selection(587, "Rifter".to_string());
        assert!(matches!(state.market, LoadState::Loading));
        assert_eq!(state.market_selected_type_name.as_deref(), Some("Rifter"));
        // Blank and numeric names become the word fallback.
        state.set_market_selection(35, "  ".to_string());
        assert_eq!(
            state.market_selected_type_name.as_deref(),
            Some("Unknown Item")
        );
        state.set_market_selection(36, "36".to_string());
        assert_eq!(
            state.market_selected_type_name.as_deref(),
            Some("Unknown Item")
        );
    }

    #[test]
    fn market_region_rejects_non_hub_and_refetches_when_selected() {
        let mut state = AppState::new(false);
        state.set_market_region(42);
        assert_eq!(state.market_region_id, DEFAULT_MARKET_REGION_ID);
        assert_eq!(
            state.market_generation, 0,
            "rejected region changes nothing"
        );
        // No type selected: generation bumps, no fetch.
        state.set_market_region(10000043);
        assert_eq!(state.market_region_id, 10000043);
        assert_eq!(state.market_generation, 1);
        assert!(!state.market_fetch_requested);
        // With a type selected the bundle resets and refetches.
        state.set_market_selection(34, "Tritanium".to_string());
        state.market = LoadState::Ready(market_bundle(None));
        state.market_fetch_requested = false;
        state.set_market_region(10000030);
        assert!(matches!(state.market, LoadState::Loading));
        assert!(state.market_fetch_requested);
    }

    #[test]
    fn switching_character_clears_stale_market_bundle() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.set_market_selection(34, "Tritanium".to_string());
        state.market = LoadState::Ready(market_bundle(Some(1)));
        state.market_search = "Trit".to_string();
        let generation = state.market_generation;
        // Same-character reselect is a market no-op.
        state.set_active_character(1);
        assert!(state.market.is_ready());
        assert_eq!(state.market_generation, generation);
        // Switching resets rows but keeps selection, region, search.
        state.set_active_character(2);
        assert!(matches!(state.market, LoadState::Loading));
        assert_eq!(state.market_generation, generation + 1);
        assert_eq!(state.market_selected_type_id, Some(34));
        assert_eq!(state.market_region_id, DEFAULT_MARKET_REGION_ID);
        assert_eq!(state.market_search, "Trit");
    }

    #[test]
    fn removing_active_character_clears_market_and_last_empties() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        state.set_market_selection(34, "Tritanium".to_string());
        state.market = LoadState::Ready(market_bundle(Some(1)));
        state.remove_character(3);
        assert!(state.market.is_ready(), "non-active removal keeps bundle");
        let generation = state.market_generation;
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(2));
        assert!(matches!(state.market, LoadState::Loading));
        assert!(state.market_generation > generation);
        state.market = LoadState::Ready(market_bundle(Some(2)));
        state.remove_character(2);
        assert!(state.characters.is_empty());
        assert!(matches!(state.market, LoadState::Empty));
    }

    fn industry_bundle() -> IndustryData {
        IndustryData {
            jobs: Ok(IndustryJobsData::default()),
            blueprints: Ok(BlueprintsData::default()),
        }
    }

    #[test]
    fn switching_character_clears_stale_industry() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.industry = LoadState::Ready(industry_bundle());
        state.industry_search = "Bantam".to_string();
        state.industry_blueprint_kind = BlueprintKindFilter::Copies;
        // Same-character reselect keeps the bundle.
        state.set_active_character(1);
        assert!(state.industry.is_ready());
        // Switching clears rows but keeps filter text and kind.
        state.set_active_character(2);
        assert!(matches!(state.industry, LoadState::Loading));
        assert_eq!(state.industry_search, "Bantam");
        assert_eq!(state.industry_blueprint_kind, BlueprintKindFilter::Copies);
    }

    #[test]
    fn removing_active_character_clears_industry_and_last_empties() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        state.industry = LoadState::Ready(industry_bundle());
        state.industry_search = "Bantam".to_string();
        state.remove_character(3);
        assert!(state.industry.is_ready(), "non-active removal keeps bundle");
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(2));
        assert!(matches!(state.industry, LoadState::Loading));
        assert_eq!(state.industry_search, "Bantam");
        state.industry = LoadState::Ready(industry_bundle());
        state.remove_character(2);
        assert!(state.characters.is_empty());
        assert!(matches!(state.industry, LoadState::Empty));
    }

    #[test]
    fn needs_industry_stepup_matrix() {
        assert!(!industry_bundle().needs_industry_stepup(), "all-Ok bundle");
        let plain = SectionError {
            message: "timeout".to_string(),
            needs_reauthorize: false,
        };
        let mut jobs_plain = industry_bundle();
        jobs_plain.jobs = Err(plain.clone());
        assert!(!jobs_plain.needs_industry_stepup());
        let mut blueprints_plain = industry_bundle();
        blueprints_plain.blueprints = Err(plain);
        assert!(!blueprints_plain.needs_industry_stepup());
        let mut jobs_reauth = industry_bundle();
        jobs_reauth.jobs = Err(reauth_error());
        assert!(jobs_reauth.needs_industry_stepup(), "jobs reauth");
        let mut blueprints_reauth = industry_bundle();
        blueprints_reauth.blueprints = Err(reauth_error());
        assert!(
            blueprints_reauth.needs_industry_stepup(),
            "blueprints reauth"
        );
        let mut both = industry_bundle();
        both.jobs = Err(reauth_error());
        both.blueprints = Err(reauth_error());
        assert!(both.needs_industry_stepup(), "both reauth");
    }

    #[test]
    fn industry_defaults_are_loading_empty_search_all_kind() {
        let state = AppState::new(false);
        assert!(matches!(state.industry, LoadState::Loading));
        assert_eq!(state.industry_search, "");
        assert_eq!(state.industry_blueprint_kind, BlueprintKindFilter::All);
        assert_eq!(BlueprintKindFilter::All.label(), "All");
        assert_eq!(BlueprintKindFilter::Originals.label(), "Originals (BPO)");
        assert_eq!(BlueprintKindFilter::Copies.label(), "Copies (BPC)");
        assert_eq!(BlueprintKindFilter::ALL.len(), 3);
    }

    fn planetary_bundle() -> PlanetaryData {
        PlanetaryData {
            colonies: Ok(vec![PlanetColony {
                planet_id: 700000001,
                planet_type: "temperate".to_string(),
                solar_system_id: 30000142,
                last_update: "2026-11-14T10:00:00Z".to_string(),
                upgrade_level: 2,
                num_pins: 4,
            }]),
            detail: None,
        }
    }

    fn planetary_bundle_with_detail(planet_id: i64) -> PlanetaryData {
        let mut bundle = planetary_bundle();
        bundle.detail = Some(SelectedColonyDetail {
            selection: PlanetSelection {
                character_id: 700000099,
                planet_id,
            },
            result: Ok(PlanetColonyDetail::default()),
        });
        bundle
    }

    #[test]
    fn needs_planetary_stepup_matrix() {
        assert!(
            !planetary_bundle().needs_planetary_stepup(),
            "all-Ok bundle, no detail"
        );
        let plain = SectionError {
            message: "timeout".to_string(),
            needs_reauthorize: false,
        };
        let mut colonies_plain = planetary_bundle();
        colonies_plain.colonies = Err(plain.clone());
        assert!(!colonies_plain.needs_planetary_stepup());
        let mut colonies_reauth = planetary_bundle();
        colonies_reauth.colonies = Err(reauth_error());
        assert!(colonies_reauth.needs_planetary_stepup(), "colonies reauth");
        let mut detail_plain = planetary_bundle_with_detail(700000001);
        detail_plain.detail.as_mut().expect("detail").result = Err(plain.clone());
        assert!(!detail_plain.needs_planetary_stepup());
        let mut detail_reauth = planetary_bundle_with_detail(700000001);
        detail_reauth.detail.as_mut().expect("detail").result = Err(reauth_error());
        assert!(detail_reauth.needs_planetary_stepup(), "detail reauth");
        // No detail at all never needs step-up on its own.
        let mut no_detail = planetary_bundle();
        no_detail.detail = None;
        assert!(!no_detail.needs_planetary_stepup());
    }

    #[test]
    fn planetary_defaults_are_loading_no_selection_zero_generation() {
        let state = AppState::new(false);
        assert!(matches!(state.planetary, LoadState::Loading));
        assert_eq!(state.planetary_selected_planet_id, None);
        assert_eq!(state.planetary_generation, 0);
        assert!(!state.planetary_detail_fetch_requested);
    }

    #[test]
    fn set_planetary_selection_bumps_generation_and_flags_fetch() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.planetary = LoadState::Ready(planetary_bundle_with_detail(700000001));
        let generation = state.planetary_generation;
        state.set_planetary_selection(700000001);
        assert_eq!(state.planetary_selected_planet_id, Some(700000001));
        assert_eq!(state.planetary_generation, generation + 1);
        assert!(state.planetary_detail_fetch_requested);
        // The bundle is untouched: the stamped detail is now stale
        // (its generation no longer matches) but still installed.
        assert!(state.planetary.is_ready());
        // Reselecting the same planet also bumps and refetches.
        state.planetary_detail_fetch_requested = false;
        state.set_planetary_selection(700000001);
        assert_eq!(state.planetary_generation, generation + 2);
        assert!(state.planetary_detail_fetch_requested);
        // Selecting another planet swaps the selection.
        state.set_planetary_selection(700000002);
        assert_eq!(state.planetary_selected_planet_id, Some(700000002));
        assert_eq!(state.planetary_generation, generation + 3);
    }

    #[test]
    fn switching_character_clears_stale_planetary() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.set_planetary_selection(700000001);
        state.planetary = LoadState::Ready(planetary_bundle());
        let generation = state.planetary_generation;
        // Same-character reselect keeps the bundle and selection.
        state.set_active_character(1);
        assert!(state.planetary.is_ready());
        assert_eq!(state.planetary_selected_planet_id, Some(700000001));
        assert_eq!(state.planetary_generation, generation);
        // Switching clears rows and selection and queues no fetch:
        // the character-switch refresh refills the list instead.
        state.set_active_character(2);
        assert!(matches!(state.planetary, LoadState::Loading));
        assert_eq!(state.planetary_selected_planet_id, None);
        assert!(!state.planetary_detail_fetch_requested);
        assert_eq!(state.planetary_generation, generation + 1);
    }

    #[test]
    fn removing_active_character_clears_planetary_and_last_empties() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        state.set_planetary_selection(700000001);
        state.planetary = LoadState::Ready(planetary_bundle());
        state.remove_character(3);
        assert!(
            state.planetary.is_ready(),
            "non-active removal keeps bundle"
        );
        assert_eq!(state.planetary_selected_planet_id, Some(700000001));
        let generation = state.planetary_generation;
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(2));
        assert!(matches!(state.planetary, LoadState::Loading));
        assert_eq!(state.planetary_selected_planet_id, None);
        assert!(state.planetary_generation > generation);
        state.set_planetary_selection(700000101);
        state.planetary = LoadState::Ready(planetary_bundle());
        state.remove_character(2);
        assert!(state.characters.is_empty());
        assert!(matches!(state.planetary, LoadState::Empty));
        assert_eq!(state.planetary_selected_planet_id, None);
        assert!(!state.planetary_detail_fetch_requested);
    }

    fn fittings_bundle() -> FittingsData {
        FittingsData {
            fittings: Ok(Vec::new()),
        }
    }

    #[test]
    fn needs_fittings_stepup_matrix() {
        assert!(!fittings_bundle().needs_fittings_stepup(), "all-Ok");
        let plain = SectionError {
            message: "timeout".to_string(),
            needs_reauthorize: false,
        };
        let mut plain_bundle = fittings_bundle();
        plain_bundle.fittings = Err(plain);
        assert!(!plain_bundle.needs_fittings_stepup());
        let mut reauth_bundle = fittings_bundle();
        reauth_bundle.fittings = Err(reauth_error());
        assert!(reauth_bundle.needs_fittings_stepup(), "reauth");
    }

    #[test]
    fn fittings_defaults_are_loading_empty_search_no_selection() {
        let state = AppState::new(false);
        assert!(matches!(state.fittings, LoadState::Loading));
        assert_eq!(state.fittings_search, "");
        assert_eq!(state.fittings_selected_fitting_id, None);
    }

    #[test]
    fn switching_character_clears_stale_fittings() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        let mut bundle = fittings_bundle();
        bundle.fittings = Err(reauth_error());
        state.fittings = LoadState::Ready(bundle);
        state.fittings_selected_fitting_id = Some(42);
        state.fittings_search = "Brawler".to_string();
        // Same-character reselect keeps the bundle and its step-up need.
        state.set_active_character(1);
        let kept = state.fittings.as_ready().expect("reselect keeps fittings");
        assert!(kept.needs_fittings_stepup());
        assert_eq!(state.fittings_selected_fitting_id, Some(42));
        // Switching clears rows and selection, mirroring planetary.
        // Search text survives the switch (view-local).
        state.set_active_character(2);
        assert!(matches!(state.fittings, LoadState::Loading));
        assert_eq!(state.fittings_selected_fitting_id, None);
        assert_eq!(state.fittings_search, "Brawler");
    }

    #[test]
    fn removing_active_character_clears_fittings_and_last_empties() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        state.fittings = LoadState::Ready(fittings_bundle());
        state.fittings_selected_fitting_id = Some(1);
        // Removing a non-active character leaves bundle ready.
        state.remove_character(3);
        assert!(state.fittings.is_ready());
        assert_eq!(state.fittings_selected_fitting_id, Some(1));
        // Removing the active character clears.
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(2));
        assert!(matches!(state.fittings, LoadState::Loading));
        assert_eq!(state.fittings_selected_fitting_id, None);
        // Removing the last character empties.
        state.fittings = LoadState::Ready(fittings_bundle());
        state.fittings_selected_fitting_id = Some(2);
        state.remove_character(2);
        assert!(state.characters.is_empty());
        assert!(matches!(state.fittings, LoadState::Empty));
        assert_eq!(state.fittings_selected_fitting_id, None);
    }

    fn skills_bundle_with(rows: Vec<Skill>) -> SkillsData {
        SkillsData {
            skills: CharacterSkills {
                skills: rows,
                total_sp: 0,
                unallocated_sp: None,
            },
            queue: Vec::new(),
        }
    }

    fn skill_row(skill_id: i64, trained: i32) -> Skill {
        Skill {
            skill_id,
            active_skill_level: trained,
            trained_skill_level: trained,
            skillpoints_in_skill: 0,
        }
    }

    #[test]
    fn switching_character_clears_stale_skills() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.skills = LoadState::Ready(skills_bundle_with(vec![skill_row(3413, 5)]));
        // Same-character reselect keeps the loaded rows.
        state.set_active_character(1);
        assert!(state.skills.is_ready());
        // Switching clears them: tolerant fetch errors and the
        // failed-refresh preserve must never present one
        // character's trained levels as another's.
        state.set_active_character(2);
        assert!(matches!(state.skills, LoadState::Loading));
    }

    #[test]
    fn removing_active_character_clears_skills_and_last_empties() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        state.skills = LoadState::Ready(skills_bundle_with(vec![skill_row(3413, 5)]));
        // Removing a non-active character leaves the bundle ready.
        state.remove_character(3);
        assert!(state.skills.is_ready());
        // Removing the active character never shows its levels under the
        // replacement character.
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(2));
        assert!(matches!(state.skills, LoadState::Loading));
        // Removing the last character empties it.
        state.skills = LoadState::Ready(skills_bundle_with(vec![skill_row(3426, 5)]));
        state.remove_character(2);
        assert!(state.characters.is_empty());
        assert!(matches!(state.skills, LoadState::Empty));
    }

    #[test]
    fn demo_switch_still_lands_ready_skills_for_the_switched_to_character() {
        use crate::fitting::resources::resource_skill_levels;
        let bundle = crate::demo::data::load_demo_bundle().expect("bundled demo loads");
        let mut state = AppState::new(true);
        state.characters = bundle
            .characters
            .iter()
            .map(|c| row(c.character_id, &c.name))
            .collect();
        // Seed order: switch, then apply installs the first
        // character's rows synchronously.
        state.set_active_character(90000001);
        crate::demo::data::apply_character(&mut state, &bundle, 90000001);
        let aria = state.skills.as_ready().expect("aria skills ready");
        let aria_levels = resource_skill_levels(&aria.skills);
        assert_eq!(aria_levels.cpu_management, 0);
        assert_eq!(aria_levels.power_grid_management, 5);
        // Switch order: the switch reset lands first, then the
        // shell's apply installs the switched-to character's rows.
        state.set_active_character(90000002);
        assert!(matches!(state.skills, LoadState::Loading));
        crate::demo::data::apply_character(&mut state, &bundle, 90000002);
        let marcus = state.skills.as_ready().expect("marcus skills ready");
        let marcus_levels = resource_skill_levels(&marcus.skills);
        assert_eq!(marcus_levels.cpu_management, 5);
        assert_eq!(marcus_levels.power_grid_management, 0);
    }

    fn seed_import_state(state: &mut AppState) {
        state.fittings_import_text = "[Rifter, Test]\nDamage Control II".to_string();
        state.fittings_imported = Some(ImportedFitting {
            name: "Test".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
            format: ImportFormat::Eft,
            items: Vec::new(),
            report: ImportReport {
                imported_lines: 0,
                placeholder_lines: 0,
                charges_noted: 0,
                issues: Vec::new(),
            },
        });
        state.fittings_import_error = None;
        state.fittings_import_owner = state.active_character_id;
        state.fittings_editor_add_name = "Damage Control II".to_string();
        state.fittings_editor_add_quantity = "5".to_string();
        state.fittings_editor_error = Some("Could not add: refused.".to_string());
        state.fittings_import_edited = true;
        state.fittings_editor_quantity.insert(0, "7".to_string());
        state.fittings_editor_name = Some("Renamed".to_string());
        state.fittings_browser_section = ImportSection::Low;
        state.fittings_browser_search = "damage".to_string();
        state.fittings_browser_rows = vec![BrowserRow {
            type_id: 2048,
            name: "Damage Control II".to_string(),
            cpu: Some(30.0),
            power: Some(1.0),
        }];
        state.fittings_browser_rows_section = Some(ImportSection::Low);
        state.fittings_ship_search = "rift".to_string();
        state.fittings_ship_rows = vec![ShipRow {
            type_id: 587,
            name: "Rifter".to_string(),
        }];
        state.fittings_ship_rows_built = true;
    }

    fn assert_import_cleared(state: &AppState) {
        assert_eq!(state.fittings_import_text, "");
        assert!(state.fittings_imported.is_none());
        assert_eq!(state.fittings_import_error, None);
        assert_eq!(state.fittings_import_owner, None);
        assert_eq!(state.fittings_editor_add_name, "");
        assert_eq!(state.fittings_editor_add_quantity, "");
        assert_eq!(state.fittings_editor_error, None);
        assert!(!state.fittings_import_edited);
        assert!(state.fittings_editor_quantity.is_empty());
        assert_eq!(state.fittings_editor_name, None);
        assert_eq!(state.fittings_browser_section, ImportSection::High);
        assert_eq!(state.fittings_browser_search, "");
        assert!(state.fittings_browser_rows.is_empty());
        assert_eq!(state.fittings_browser_rows_section, None);
        assert_eq!(state.fittings_ship_search, "");
        assert!(state.fittings_ship_rows.is_empty());
        assert!(!state.fittings_ship_rows_built);
    }

    #[test]
    fn switching_character_clears_import_state() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        seed_import_state(&mut state);
        // Same-character reselect keeps everything.
        state.set_active_character(1);
        assert!(state.fittings_imported.is_some());
        assert_eq!(
            state.fittings_import_text,
            "[Rifter, Test]\nDamage Control II"
        );
        assert_eq!(state.fittings_import_owner, Some(1));
        assert_eq!(state.fittings_editor_add_name, "Damage Control II");
        assert!(state.fittings_import_edited);
        assert_eq!(state.fittings_browser_section, ImportSection::Low);
        assert_eq!(state.fittings_browser_search, "damage");
        assert_eq!(state.fittings_browser_rows.len(), 1);
        assert_eq!(
            state.fittings_browser_rows_section,
            Some(ImportSection::Low)
        );
        assert_eq!(state.fittings_ship_search, "rift");
        assert_eq!(state.fittings_ship_rows.len(), 1);
        assert!(state.fittings_ship_rows_built);
        // Switching to a different character clears all four fields.
        state.set_active_character(2);
        assert_import_cleared(&state);
    }

    #[test]
    fn removing_character_clears_import_only_when_active() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        seed_import_state(&mut state);
        // Removing a non-active character keeps import state.
        state.remove_character(3);
        assert!(state.fittings_imported.is_some());
        assert_eq!(state.fittings_import_owner, Some(1));
        assert_eq!(state.fittings_browser_section, ImportSection::Low);
        assert_eq!(state.fittings_browser_rows.len(), 1);
        assert_eq!(state.fittings_ship_search, "rift");
        assert!(state.fittings_ship_rows_built);
        // Removing the active character clears it.
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(2));
        assert_import_cleared(&state);
    }

    #[test]
    fn empty_roster_clears_import_state() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One")];
        state.set_active_character(1);
        seed_import_state(&mut state);
        state.remove_character(1);
        assert!(state.characters.is_empty());
        assert_import_cleared(&state);
    }

    #[test]
    fn exploration_state_is_character_independent_and_never_cleared() {
        // Design section 7.1: the bundled reference is static and
        // character-independent, so switches and removals leave the
        // loaded catalogue and view-local selections untouched. This
        // is the deliberate opposite of the per-character bundles
        // above.
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        let catalogue_len = reference.types.len();
        let mut state = AppState::new(false);
        assert!(matches!(state.exploration, LoadState::Loading));
        assert_eq!(state.exploration_search, "");
        assert_eq!(state.exploration_section, ExplorationSection::Types);
        assert_eq!(state.exploration_destination, None);
        assert!(!state.exploration_capital_only);
        assert_eq!(state.exploration_selected_code, None);
        assert_eq!(state.exploration_selected_system_id, None);
        assert_eq!(state.exploration_selected_family, None);
        assert_eq!(
            state.exploration_selected_strength, 1,
            "effect strength defaults to 1"
        );
        assert_eq!(ExplorationSection::Types.label(), "Types");
        assert_eq!(ExplorationSection::Effects.label(), "Effects");
        assert_eq!(DestinationFilter::Highsec.label(), "Highsec");
        assert_eq!(DestinationFilter::JSpace.label(), "J-space");
        state.exploration = LoadState::Ready(ExplorationData {
            reference: Arc::new(reference),
        });
        state.exploration_search = "B274".to_string();
        state.exploration_section = ExplorationSection::Systems;
        state.exploration_destination = Some(DestinationFilter::Pochven);
        state.exploration_capital_only = true;
        state.exploration_selected_code = Some("B274".to_string());
        state.exploration_selected_system_id = Some(31000005);
        state.exploration_selected_family = Some(EffectFamily::WolfRayet);
        state.exploration_selected_strength = 6;
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        // Switching characters never touches exploration.
        state.set_active_character(2);
        let kept = state.exploration.as_ready().expect("keeps catalogue");
        assert_eq!(kept.reference.types.len(), catalogue_len);
        assert_eq!(state.exploration_search, "B274");
        assert_eq!(state.exploration_section, ExplorationSection::Systems);
        assert_eq!(
            state.exploration_destination,
            Some(DestinationFilter::Pochven)
        );
        assert!(state.exploration_capital_only);
        assert_eq!(state.exploration_selected_code.as_deref(), Some("B274"));
        assert_eq!(state.exploration_selected_system_id, Some(31000005));
        assert_eq!(
            state.exploration_selected_family,
            Some(EffectFamily::WolfRayet)
        );
        assert_eq!(state.exploration_selected_strength, 6);
        // Removing a non-active character never touches it either.
        state.remove_character(3);
        assert!(state.exploration.is_ready());
        // Removing the active character never touches it.
        state.remove_character(2);
        assert_eq!(state.active_character_id, Some(1));
        let after_remove = state.exploration.as_ready().expect("keeps catalogue");
        assert_eq!(after_remove.reference.types.len(), catalogue_len);
        assert_eq!(state.exploration_search, "B274");
        // Removing the last character does not empty it either
        // (no LoadState::Empty flip for this view).
        state.remove_character(1);
        assert!(state.characters.is_empty());
        assert!(state.exploration.is_ready());
        assert_eq!(state.exploration_search, "B274");
    }

    #[test]
    fn wallet_period_windows_and_auth_labels() {
        assert_eq!(WalletPeriod::All.days(), None);
        assert_eq!(WalletPeriod::Days30.days(), Some(30));
        assert!(AuthState::AwaitingCallback.is_busy());
        assert!(!AuthState::Idle.is_busy());
        assert!(!AuthState::Error.label().is_empty());
    }

    fn seed_write_state(state: &mut AppState) {
        state.fittings_write_needs_reauthorize = true;
        state.fittings_write_confirm = Some(FittingWriteConfirm::SaveImported {
            character_id: state.active_character_id.unwrap_or(1),
        });
        state.fittings_write_requested = Some(FittingWriteRequest::Delete {
            character_id: state.active_character_id.unwrap_or(1),
            fitting_id: 42,
        });
        state.fittings_pending_selection = Some((state.active_character_id.unwrap_or(1), 4242));
    }

    fn assert_write_state_cleared(state: &AppState) {
        assert!(!state.fittings_write_needs_reauthorize);
        assert_eq!(state.fittings_write_confirm, None);
        assert!(state.fittings_write_requested.is_none());
        assert_eq!(state.fittings_pending_selection, None);
    }

    #[test]
    fn fitting_write_state_defaults_are_empty_for_demo_and_live() {
        for demo in [false, true] {
            let state = AppState::new(demo);
            assert!(!state.fittings_write_needs_reauthorize);
            assert_eq!(state.fittings_write_confirm, None);
            assert!(state.fittings_write_requested.is_none());
            assert!(state.fittings_write_in_flight.is_none());
            assert_eq!(state.fittings_pending_selection, None);
        }
        assert_eq!(FittingWriteKind::Save.label(), "save");
        assert_eq!(FittingWriteKind::Delete.label(), "delete");
    }

    #[test]
    fn switching_character_clears_fitting_write_state() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        seed_write_state(&mut state);
        // Same-character reselect keeps everything.
        state.set_active_character(1);
        assert!(state.fittings_write_needs_reauthorize);
        assert!(state.fittings_write_confirm.is_some());
        // Switching to a different character clears the whole
        // write state (design section 3.2).
        state.set_active_character(2);
        assert_write_state_cleared(&state);
    }

    #[test]
    fn removing_character_clears_fitting_write_only_when_active() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        seed_write_state(&mut state);
        // Removing a non-active character clears none of the
        // active character's write state.
        state.remove_character(3);
        assert!(state.fittings_write_needs_reauthorize);
        assert!(state.fittings_write_confirm.is_some());
        assert!(state.fittings_write_requested.is_some());
        assert_eq!(state.fittings_pending_selection, Some((1, 4242)));
        // Removing the active character clears it.
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(2));
        assert_write_state_cleared(&state);
    }

    #[test]
    fn empty_roster_clears_fitting_write_state() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One")];
        state.set_active_character(1);
        seed_write_state(&mut state);
        state.remove_character(1);
        assert!(state.characters.is_empty());
        assert_write_state_cleared(&state);
    }

    fn portrait_state_with_dimensions(width: u32, height: u32) -> PortraitState {
        PortraitState::Ready(Arc::new(image::DynamicImage::new_rgb8(width, height)))
    }

    #[test]
    fn portrait_request_queues_once_and_sets_loading() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.request_portrait(ImageKind::Character, 1);
        // Second request while Loading: no duplicate queue entry.
        state.request_portrait(ImageKind::Character, 1);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Character, 1)]);
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 1),
            PortraitState::Loading
        ));
        assert_eq!(
            state.take_portrait_requests(),
            vec![(ImageKind::Character, 1)]
        );
        assert!(state.portrait_requests.is_empty());
    }

    #[test]
    fn portrait_request_ignores_unknown_characters() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One")];
        state.set_active_character(1);
        state.request_portrait(ImageKind::Character, 999);
        assert!(state.portrait_requests.is_empty());
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 999),
            PortraitState::NotRequested
        ));
    }

    #[test]
    fn portrait_request_skips_ready_and_requeues_failed() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.portraits.insert(
            (ImageKind::Character, 1),
            portrait_state_with_dimensions(8, 8),
        );
        state.request_portrait(ImageKind::Character, 1);
        assert!(state.portrait_requests.is_empty());
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 1),
            PortraitState::Ready(_)
        ));
        // A failed portrait is retried on the next request.
        state
            .portraits
            .insert((ImageKind::Character, 2), PortraitState::Failed);
        state.request_portrait(ImageKind::Character, 2);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Character, 2)]);
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 2),
            PortraitState::Loading
        ));
    }

    #[test]
    fn portrait_map_survives_character_switch() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.portraits.insert(
            (ImageKind::Character, 1),
            portrait_state_with_dimensions(8, 8),
        );
        state.set_active_character(2);
        // Keyed like summaries: the switched-away character's
        // portrait stays in its own slot for when the user returns.
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 1),
            PortraitState::Ready(_)
        ));
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 2),
            PortraitState::NotRequested
        ));
    }

    #[test]
    fn removing_character_drops_its_portrait_and_queue() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.portraits.insert(
            (ImageKind::Character, 1),
            portrait_state_with_dimensions(8, 8),
        );
        state
            .portraits
            .insert((ImageKind::Character, 2), PortraitState::Loading);
        state.portrait_requests = vec![(ImageKind::Character, 2)];
        state.remove_character(2);
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 2),
            PortraitState::NotRequested
        ));
        assert!(state.portrait_requests.is_empty());
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 1),
            PortraitState::Ready(_)
        ));
        // Removing the last character clears the whole map.
        state.remove_character(1);
        assert!(state.characters.is_empty());
        assert!(state.portraits.is_empty());
    }

    #[test]
    fn same_numeric_id_in_different_kinds_queues_independently() {
        let mut state = AppState::new(false);
        // row() carries corporation 1000166; no character row has
        // character id 1000166.
        state.characters = vec![row(1, "One")];
        state.set_active_character(1);
        state.request_portrait(ImageKind::Character, 1000166);
        assert!(state.portrait_requests.is_empty());
        state.request_portrait(ImageKind::Corporation, 1000166);
        assert_eq!(
            state.portrait_requests,
            vec![(ImageKind::Corporation, 1000166)]
        );
        assert!(matches!(
            state.portrait_state(ImageKind::Corporation, 1000166),
            PortraitState::Loading
        ));
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 1000166),
            PortraitState::NotRequested
        ));
    }

    #[test]
    fn logo_requests_guard_by_source() {
        // Corporation and alliance known only via the loaded public
        // info queue; in neither source queue nothing.
        let ready_info = |corporation_id: i64, alliance_id: Option<i64>| {
            LoadState::Ready(CharacterPublicInfo {
                corporation_id,
                alliance_id,
                ..Default::default()
            })
        };
        let mut state = AppState::new(false);
        let mut other = row(1, "One");
        other.corporation_id = 1000125;
        state.characters = vec![other];
        state.set_active_character(1);
        // Corporation 1000166 is in neither source yet.
        state.request_portrait(ImageKind::Corporation, 1000166);
        assert!(state.portrait_requests.is_empty());
        // Known via the loaded public info: queues.
        state.character_detail = ready_info(1000166, Some(99003581));
        state.request_portrait(ImageKind::Corporation, 1000166);
        assert_eq!(
            state.portrait_requests,
            vec![(ImageKind::Corporation, 1000166)]
        );
        state.request_portrait(ImageKind::Alliance, 99003581);
        assert_eq!(
            state.portrait_requests,
            vec![
                (ImageKind::Corporation, 1000166),
                (ImageKind::Alliance, 99003581)
            ]
        );
        // An alliance in neither source queues nothing (the row
        // has alliance_id None and the info has 99003581, not this
        // id).
        state.request_portrait(ImageKind::Alliance, 99000001);
        assert_eq!(state.portrait_requests.len(), 2);
        // Known via a row: queues (detail agrees with nothing).
        let mut state = AppState::new(false);
        let mut by_row = row(1, "One");
        by_row.corporation_id = 1000166;
        by_row.alliance_id = Some(99003581);
        state.characters = vec![by_row];
        state.set_active_character(1);
        state.character_detail = ready_info(1000125, None);
        state.request_portrait(ImageKind::Corporation, 1000166);
        assert_eq!(
            state.portrait_requests,
            vec![(ImageKind::Corporation, 1000166)]
        );
        state.request_portrait(ImageKind::Alliance, 99003581);
        assert_eq!(
            state.portrait_requests,
            vec![
                (ImageKind::Corporation, 1000166),
                (ImageKind::Alliance, 99003581)
            ]
        );
        // A corporation in neither source (rows say 1000166, the
        // loaded info says 1000125) queues nothing.
        state.request_portrait(ImageKind::Corporation, 1000199);
        assert_eq!(state.portrait_requests.len(), 2);
    }

    #[test]
    fn nonpositive_ids_queue_nothing_for_any_kind() {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One")];
        state.set_active_character(1);
        for kind in [
            ImageKind::Character,
            ImageKind::Corporation,
            ImageKind::Alliance,
            ImageKind::Faction,
            ImageKind::Type,
        ] {
            for id in [0, -1] {
                state.request_portrait(kind, id);
                assert!(
                    state.portrait_requests.is_empty(),
                    "kind {kind:?} id {id} must queue nothing"
                );
            }
        }
    }

    #[test]
    fn shared_corporation_logo_survives_until_last_row_removed() {
        let mut state = AppState::new(false);
        // Both rows carry corporation 1000166 (the row() default).
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.portraits.insert(
            (ImageKind::Corporation, 1000166),
            portrait_state_with_dimensions(8, 8),
        );
        state.remove_character(1);
        assert!(matches!(
            state.portrait_state(ImageKind::Corporation, 1000166),
            PortraitState::Ready(_)
        ));
        state.remove_character(2);
        assert!(state.characters.is_empty());
        assert!(state.portraits.is_empty());
    }

    #[test]
    fn queued_logo_request_drops_only_when_last_reference_goes() {
        // Survives while a remaining row references it.
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.portrait_requests = vec![(ImageKind::Corporation, 1000166)];
        state.remove_character(1);
        assert_eq!(
            state.portrait_requests,
            vec![(ImageKind::Corporation, 1000166)]
        );
        // Drops when no remaining row references it.
        let mut state = AppState::new(false);
        let mut other = row(2, "Two");
        other.corporation_id = 1000125;
        state.characters = vec![row(1, "One"), other];
        state.set_active_character(1);
        state.portrait_requests = vec![(ImageKind::Corporation, 1000166)];
        state.remove_character(1);
        assert!(state.portrait_requests.is_empty());
    }

    fn standing(id: i64, from_type: &str) -> Standing {
        Standing {
            from_id: id,
            from_type: from_type.to_string(),
            standing: 5.0,
        }
    }

    /// The design section 9 bundle: Ready `character_details`
    /// with the six-entity standings list and every other section
    /// an Err fixture.
    fn standings_fixture_state() -> AppState {
        let err = reauth_error();
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.character_details = LoadState::Ready(CharacterDetailData {
            attributes: Err(err.clone()),
            implants: Err(err.clone()),
            clones: Err(err.clone()),
            standings: Ok(vec![
                standing(500001, "faction"),
                standing(1000125, "npc_corp"),
                standing(1000006, "corporation"),
                standing(3000001, "agent"),
                standing(99000001, "alliance"),
                standing(424242, ""),
            ]),
            location: Err(err.clone()),
            ship: Err(err.clone()),
            online: Err(err),
        });
        state
    }

    #[test]
    fn standings_authorize_only_their_own_kind() {
        // row() carries corporation 1000166, so 1000125 and 1000006
        // are known only from the standings list below.
        let state = standings_fixture_state();
        assert!(state.image_id_known(ImageKind::Faction, 500001));
        assert!(!state.image_id_known(ImageKind::Corporation, 500001));
        assert!(state.image_id_known(ImageKind::Corporation, 1000125));
        assert!(state.image_id_known(ImageKind::Corporation, 1000006));
        assert!(!state.image_id_known(ImageKind::Faction, 1000125));
        assert!(!state.image_id_known(ImageKind::Character, 3000001));
        assert!(!state.image_id_known(ImageKind::Alliance, 99000001));
        for kind in [
            ImageKind::Character,
            ImageKind::Corporation,
            ImageKind::Alliance,
            ImageKind::Faction,
            ImageKind::Type,
        ] {
            assert!(
                !state.image_id_known(kind, 424242),
                "kind {kind:?} at 424242 must be unknown"
            );
        }
    }

    #[test]
    fn standings_known_kinds_queue_through_request_portrait() {
        let mut state = standings_fixture_state();
        state.request_portrait(ImageKind::Faction, 500001);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Faction, 500001)]);
        assert!(matches!(
            state.portrait_state(ImageKind::Faction, 500001),
            PortraitState::Loading
        ));
        state.request_portrait(ImageKind::Faction, 500001);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Faction, 500001)]);
        // Cross-kind: the faction id is not a corporation key.
        state.request_portrait(ImageKind::Corporation, 500001);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Faction, 500001)]);
        assert!(!state
            .portraits
            .contains_key(&(ImageKind::Corporation, 500001)));
    }

    #[test]
    fn err_or_loading_standings_authorize_nothing() {
        let mut state = standings_fixture_state();
        let Some(bundle) = state.character_details.as_ready().cloned() else {
            panic!("fixture bundle must be ready");
        };
        let mut err_bundle = bundle.clone();
        err_bundle.standings = Err(reauth_error());
        state.character_details = LoadState::Ready(err_bundle);
        for kind in [
            ImageKind::Character,
            ImageKind::Corporation,
            ImageKind::Alliance,
            ImageKind::Faction,
            ImageKind::Type,
        ] {
            for id in [500001, 1000125, 1000006] {
                assert!(
                    !state.image_id_known(kind, id),
                    "Err standings must authorize nothing (kind {kind:?} id {id})"
                );
            }
        }
        state.request_portrait(ImageKind::Faction, 500001);
        assert!(state.portrait_requests.is_empty());

        let mut state = standings_fixture_state();
        state.character_details = LoadState::Loading;
        for kind in [
            ImageKind::Character,
            ImageKind::Corporation,
            ImageKind::Alliance,
            ImageKind::Faction,
            ImageKind::Type,
        ] {
            for id in [500001, 1000125, 1000006] {
                assert!(
                    !state.image_id_known(kind, id),
                    "Loading details must authorize nothing (kind {kind:?} id {id})"
                );
            }
        }
        state.request_portrait(ImageKind::Faction, 500001);
        assert!(state.portrait_requests.is_empty());
    }

    #[test]
    fn switching_character_revokes_standings_knowledge() {
        // Standings belong to the active character: A's standings
        // must never authorize a fetch under B (design section
        // 5.2).
        let mut state = standings_fixture_state();
        state.request_portrait(ImageKind::Faction, 500001);
        assert!(state.image_id_known(ImageKind::Faction, 500001));
        state.set_active_character(2);
        assert!(matches!(state.character_details, LoadState::Loading));
        assert!(!state.image_id_known(ImageKind::Faction, 500001));
        assert!(!state.image_id_known(ImageKind::Corporation, 1000125));
    }

    #[test]
    fn removing_character_retains_standings_backed_images_until_guard_loses_them() {
        let mut state = standings_fixture_state();
        state.portraits.insert(
            (ImageKind::Faction, 500001),
            portrait_state_with_dimensions(8, 8),
        );
        state.portraits.insert(
            (ImageKind::Corporation, 1000125),
            portrait_state_with_dimensions(8, 8),
        );
        state.portrait_requests = vec![
            (ImageKind::Faction, 500001),
            (ImageKind::Corporation, 1000125),
        ];
        // Removing a non-active character keeps the active
        // character's standings backing.
        state.remove_character(2);
        assert!(state.character_details.is_ready());
        assert!(state.image_id_known(ImageKind::Faction, 500001));
        assert!(state.image_id_known(ImageKind::Corporation, 1000125));
        assert!(matches!(
            state.portrait_state(ImageKind::Faction, 500001),
            PortraitState::Ready(_)
        ));
        assert!(matches!(
            state.portrait_state(ImageKind::Corporation, 1000125),
            PortraitState::Ready(_)
        ));
        assert_eq!(
            state.portrait_requests,
            vec![
                (ImageKind::Faction, 500001),
                (ImageKind::Corporation, 1000125)
            ]
        );
        // Removing the active character loses the bundle, so both
        // become unknown (the retain ran pre-reset; prune and
        // landing finish the cleanup).
        state.remove_character(1);
        assert!(!state.image_id_known(ImageKind::Faction, 500001));
        assert!(!state.image_id_known(ImageKind::Corporation, 1000125));
    }

    fn fitting_item(type_id: i64) -> FittingItem {
        FittingItem {
            flag: "Cargo".to_string(),
            quantity: 1,
            type_id,
        }
    }

    fn fitting_ship(ship_type_id: i64) -> CharacterFitting {
        CharacterFitting {
            fitting_id: ship_type_id,
            name: "Fitting".to_string(),
            description: None,
            ship_type_id,
            items: Vec::new(),
        }
    }

    /// The design section 10 fixture: characters 1 (active) and 2,
    /// `fittings` Ready with fitting A (ship 587, items 2048 and 34)
    /// and fitting B (ship 597, item 178).
    fn fitting_type_fixture_state() -> AppState {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        let mut fitting_a = fitting_ship(587);
        fitting_a.items = vec![fitting_item(2048), fitting_item(34)];
        let mut fitting_b = fitting_ship(597);
        fitting_b.items = vec![fitting_item(178)];
        state.fittings = LoadState::Ready(FittingsData {
            fittings: Ok(vec![fitting_a, fitting_b]),
        });
        state
    }

    #[test]
    fn fitting_types_authorize_only_the_type_kind() {
        // row() carries corporation 1000166, so no fixture id below
        // is known by row under any entity kind.
        let state = fitting_type_fixture_state();
        assert!(state.image_id_known(ImageKind::Type, 587));
        assert!(state.image_id_known(ImageKind::Type, 2048));
        assert!(state.image_id_known(ImageKind::Type, 34));
        assert!(state.image_id_known(ImageKind::Type, 597));
        assert!(state.image_id_known(ImageKind::Type, 178));
        // Unknown everywhere, a catalogue-real skill type named by
        // no saved fitting, and a faction id.
        assert!(!state.image_id_known(ImageKind::Type, 99999999));
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        assert!(!state.image_id_known(ImageKind::Type, 500001));
        // Cross-kind: a fitting type id is not an entity key.
        for kind in [
            ImageKind::Character,
            ImageKind::Corporation,
            ImageKind::Alliance,
            ImageKind::Faction,
        ] {
            for id in [587, 2048, 34, 597, 178] {
                assert!(
                    !state.image_id_known(kind, id),
                    "kind {kind:?} at {id} must be unknown"
                );
            }
        }
    }

    #[test]
    fn fitting_types_queue_through_request_portrait() {
        let mut state = fitting_type_fixture_state();
        state.request_portrait(ImageKind::Type, 2048);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 2048)]);
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 2048),
            PortraitState::Loading
        ));
        state.request_portrait(ImageKind::Type, 2048);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 2048)]);
        // Unknown ids queue nothing and create no entry.
        state.request_portrait(ImageKind::Type, 99999999);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 2048)]);
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 99999999)));
        state.request_portrait(ImageKind::Type, 3300);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 2048)]);
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 3300)));
        // Non-positive ids queue nothing.
        state.request_portrait(ImageKind::Type, 0);
        state.request_portrait(ImageKind::Type, -1);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 2048)]);
    }

    #[test]
    fn imported_fitting_type_authorizes_nothing() {
        // User-pasted import text is not a guard source: even an
        // imported fitting that names 2048 authorizes nothing while
        // the saved-fittings bundle is still Loading.
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        assert!(matches!(state.fittings, LoadState::Loading));
        state.fittings_imported = Some(ImportedFitting {
            name: "Test".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
            format: ImportFormat::Eft,
            items: vec![ImportedItem {
                type_id: 2048,
                name: "Pasted Module".to_string(),
                section: ImportSection::Low,
                quantity: 1,
                charge: None,
            }],
            report: ImportReport {
                imported_lines: 1,
                placeholder_lines: 0,
                charges_noted: 0,
                issues: Vec::new(),
            },
        });
        assert!(!state.image_id_known(ImageKind::Type, 2048));
        state.request_portrait(ImageKind::Type, 2048);
        assert!(state.portrait_requests.is_empty());
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 2048),
            PortraitState::NotRequested
        ));
    }

    #[test]
    fn err_or_loading_fittings_authorize_nothing() {
        let mut state = fitting_type_fixture_state();
        let Some(bundle) = state.fittings.as_ready().cloned() else {
            panic!("fixture bundle must be ready");
        };
        let mut err_bundle = bundle.clone();
        err_bundle.fittings = Err(reauth_error());
        state.fittings = LoadState::Ready(err_bundle);
        for id in [587, 2048, 34, 597, 178] {
            assert!(
                !state.image_id_known(ImageKind::Type, id),
                "Err fittings must authorize nothing (id {id})"
            );
        }
        state.request_portrait(ImageKind::Type, 2048);
        assert!(state.portrait_requests.is_empty());

        let mut state = fitting_type_fixture_state();
        state.fittings = LoadState::Loading;
        for id in [587, 2048, 34, 597, 178] {
            assert!(
                !state.image_id_known(ImageKind::Type, id),
                "Loading fittings must authorize nothing (id {id})"
            );
        }
        state.request_portrait(ImageKind::Type, 2048);
        assert!(state.portrait_requests.is_empty());

        let mut state = fitting_type_fixture_state();
        state.fittings = LoadState::Empty;
        for id in [587, 2048, 34, 597, 178] {
            assert!(
                !state.image_id_known(ImageKind::Type, id),
                "Empty fittings must authorize nothing (id {id})"
            );
        }
        state.request_portrait(ImageKind::Type, 2048);
        assert!(state.portrait_requests.is_empty());
    }

    #[test]
    fn switching_character_revokes_fitting_type_knowledge() {
        // Saved fittings belong to the active character: A's
        // fitting types must never authorize a fetch under B.
        let mut state = fitting_type_fixture_state();
        state.request_portrait(ImageKind::Type, 2048);
        assert!(state.image_id_known(ImageKind::Type, 587));
        // Same-character reselect keeps the knowledge.
        state.set_active_character(1);
        assert!(state.image_id_known(ImageKind::Type, 587));
        state.set_active_character(2);
        assert!(matches!(state.fittings, LoadState::Loading));
        assert!(!state.image_id_known(ImageKind::Type, 587));
        assert!(!state.image_id_known(ImageKind::Type, 2048));
    }

    #[test]
    fn market_selection_authorizes_only_the_selected_type() {
        // X (3300) is not in any saved fitting: only the selection
        // arm can authorize it (design market-icon section 2).
        let mut state = fitting_type_fixture_state();
        state.fittings = LoadState::Loading;
        state.set_market_selection(3300, "Type X".to_string());
        assert!(state.image_id_known(ImageKind::Type, 3300));
        state.request_portrait(ImageKind::Type, 3300);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Loading
        ));
        state.request_portrait(ImageKind::Type, 3300);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        // An unselected type and a candidate-only type authorize
        // nothing and queue nothing.
        assert!(!state.image_id_known(ImageKind::Type, 99999999));
        state.request_portrait(ImageKind::Type, 99999999);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 99999999)));
        state.market_candidates = vec![UniverseName {
            id: 12345,
            name: "Candidate".to_string(),
            category: "inventory_type".to_string(),
        }];
        assert!(!state.image_id_known(ImageKind::Type, 12345));
        state.request_portrait(ImageKind::Type, 12345);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 12345)));
        // Selecting Y flips X off and Y on.
        state.set_market_selection(12345, "Type Y".to_string());
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        assert!(state.image_id_known(ImageKind::Type, 12345));
        // Non-positive ids queue nothing in any setup.
        state.request_portrait(ImageKind::Type, 0);
        state.request_portrait(ImageKind::Type, -1);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
    }

    #[test]
    fn market_selection_absence_authorizes_nothing() {
        // No selection, and search text alone, authorize no Type
        // fetch when the fittings bundle does not back the id.
        let mut state = fitting_type_fixture_state();
        state.fittings = LoadState::Loading;
        assert_eq!(state.market_selected_type_id, None);
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        state.request_portrait(ImageKind::Type, 3300);
        assert!(state.portrait_requests.is_empty());
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 3300)));
        // Search text is only a query: it never becomes a selected
        // id, even when it looks numeric.
        state.market_search = "3300".to_string();
        assert_eq!(state.market_selected_type_id, None);
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        state.request_portrait(ImageKind::Type, 3300);
        assert!(state.portrait_requests.is_empty());
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 3300)));
        // A fitting-known type stays authorized with no selection.
        let state = fitting_type_fixture_state();
        assert_eq!(state.market_selected_type_id, None);
        assert!(state.image_id_known(ImageKind::Type, 587));
    }

    #[test]
    fn market_selection_survives_switch_while_fitting_arm_revokes() {
        let mut state = fitting_type_fixture_state();
        state.set_market_selection(3300, "Type X".to_string());
        assert!(state.image_id_known(ImageKind::Type, 587));
        assert!(state.image_id_known(ImageKind::Type, 3300));
        state.set_active_character(2);
        assert!(matches!(state.fittings, LoadState::Loading));
        assert!(!state.image_id_known(ImageKind::Type, 587));
        assert!(state.image_id_known(ImageKind::Type, 3300));
    }

    #[test]
    fn removing_character_retains_selected_market_icon() {
        // Three characters so neither removal hits the
        // last-removal branch (which clears all portraits).
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        let mut fitting_a = fitting_ship(587);
        fitting_a.items = vec![fitting_item(2048), fitting_item(34)];
        state.fittings = LoadState::Ready(FittingsData {
            fittings: Ok(vec![fitting_a]),
        });
        state.set_market_selection(3300, "Type X".to_string());
        state.portraits.insert(
            (ImageKind::Type, 3300),
            portrait_state_with_dimensions(8, 8),
        );
        state.portrait_requests = vec![(ImageKind::Type, 3300)];
        // Removing a non-active character keeps the icon.
        state.remove_character(2);
        assert_eq!(state.market_selected_type_id, Some(3300));
        assert!(state.image_id_known(ImageKind::Type, 3300));
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Ready(_)
        ));
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        // Removing the active character loses the fittings bundle
        // but keeps the selection and the entry through the
        // retain closure (design section 3).
        state.portraits.insert(
            (ImageKind::Type, 2048),
            portrait_state_with_dimensions(8, 8),
        );
        state.portrait_requests.push((ImageKind::Type, 2048));
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(3));
        assert_eq!(state.market_selected_type_id, Some(3300));
        assert!(matches!(state.fittings, LoadState::Loading));
        assert!(!state.image_id_known(ImageKind::Type, 2048));
        assert!(state.image_id_known(ImageKind::Type, 3300));
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Ready(_)
        ));
        assert!(state.portrait_requests.contains(&(ImageKind::Type, 3300)));
    }

    #[test]
    fn removing_character_retains_fitting_type_images_until_guard_loses_them() {
        let mut state = fitting_type_fixture_state();
        state.portraits.insert(
            (ImageKind::Type, 2048),
            portrait_state_with_dimensions(8, 8),
        );
        state.portrait_requests = vec![(ImageKind::Type, 2048)];
        // Removing a non-active character keeps the active
        // character's fittings backing.
        state.remove_character(2);
        assert!(state.fittings.is_ready());
        assert!(state.image_id_known(ImageKind::Type, 2048));
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 2048),
            PortraitState::Ready(_)
        ));
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 2048)]);
        // Removing the active character loses the bundle, so the
        // type becomes unknown (the retain ran pre-reset; prune
        // and landing finish the cleanup).
        state.remove_character(1);
        assert!(!state.image_id_known(ImageKind::Type, 2048));
    }

    fn asset_item(item_id: i64, type_id: i64) -> AssetItem {
        AssetItem {
            item_id,
            type_id,
            quantity: 1,
            location_id: 60003760,
            ..Default::default()
        }
    }

    fn asset_holding_state() -> AppState {
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.fittings = LoadState::Loading;
        state.assets = LoadState::Ready(AssetsData {
            items: vec![asset_item(1, 3300), asset_item(2, 3300), asset_item(3, 587)],
            custom_names: HashMap::new(),
        });
        state
    }

    #[test]
    fn asset_holdings_authorize_only_held_types() {
        // Held types authorize; unheld types do not, and queue
        // nothing (mirrors the market-selection ordering test).
        let mut state = asset_holding_state();
        assert!(state.image_id_known(ImageKind::Type, 3300));
        assert!(state.image_id_known(ImageKind::Type, 587));
        state.request_portrait(ImageKind::Type, 3300);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Loading
        ));
        state.request_portrait(ImageKind::Type, 587);
        assert_eq!(
            state.portrait_requests,
            vec![(ImageKind::Type, 3300), (ImageKind::Type, 587)]
        );
        // Duplicate rows of one type queue once (the second row's
        // request hits the Loading entry and no-ops).
        state.request_portrait(ImageKind::Type, 3300);
        assert_eq!(
            state.portrait_requests,
            vec![(ImageKind::Type, 3300), (ImageKind::Type, 587)]
        );
        assert!(!state.image_id_known(ImageKind::Type, 99999999));
        state.request_portrait(ImageKind::Type, 99999999);
        assert_eq!(
            state.portrait_requests,
            vec![(ImageKind::Type, 3300), (ImageKind::Type, 587)]
        );
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 99999999)));
        // Every non-Ready arm authorizes nothing.
        let mut state = asset_holding_state();
        state.assets = LoadState::Loading;
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        state.request_portrait(ImageKind::Type, 3300);
        assert!(state.portrait_requests.is_empty());
        let mut state = asset_holding_state();
        state.assets = LoadState::Empty;
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        state.request_portrait(ImageKind::Type, 3300);
        assert!(state.portrait_requests.is_empty());
        let mut state = asset_holding_state();
        state.assets = LoadState::Error("forbidden".to_string());
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        state.request_portrait(ImageKind::Type, 3300);
        assert!(state.portrait_requests.is_empty());
        // Search text is only a query, never a selected id, even
        // when it looks numeric.
        let mut state = asset_holding_state();
        state.assets = LoadState::Loading;
        state.assets_search = "3300".to_string();
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        state.request_portrait(ImageKind::Type, 3300);
        assert!(state.portrait_requests.is_empty());
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 3300)));
    }

    #[test]
    fn switching_character_revokes_asset_type_knowledge() {
        // Holdings belong to the active character: A's types must
        // never authorize a fetch under B.
        let mut state = asset_holding_state();
        state.request_portrait(ImageKind::Type, 3300);
        assert!(state.image_id_known(ImageKind::Type, 3300));
        // Same-character reselect keeps the knowledge.
        state.set_active_character(1);
        assert!(state.image_id_known(ImageKind::Type, 3300));
        // Switch revokes until reload.
        state.set_active_character(2);
        assert!(matches!(state.assets, LoadState::Loading));
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        assert!(!state.image_id_known(ImageKind::Type, 587));
        // A type also market-selected survives via that arm
        // (the market arm is deliberately not character-keyed).
        let mut state = asset_holding_state();
        state.set_market_selection(3300, "Type X".to_string());
        assert!(state.image_id_known(ImageKind::Type, 3300));
        state.set_active_character(2);
        assert!(matches!(state.assets, LoadState::Loading));
        assert!(state.image_id_known(ImageKind::Type, 3300));
    }

    #[test]
    fn removing_character_retains_held_asset_icon() {
        // Three characters so neither removal hits the
        // last-removal branch (which clears all portraits).
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        state.assets = LoadState::Ready(AssetsData {
            items: vec![asset_item(1, 3300)],
            custom_names: HashMap::new(),
        });
        state.portraits.insert(
            (ImageKind::Type, 3300),
            portrait_state_with_dimensions(8, 8),
        );
        state.portrait_requests = vec![(ImageKind::Type, 3300)];
        // Removing a non-active character keeps the icon.
        state.remove_character(2);
        assert!(state.image_id_known(ImageKind::Type, 3300));
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Ready(_)
        ));
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        // Removing the active character keeps the entry through
        // the retain closure while the guard then reads false.
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(3));
        assert!(matches!(state.assets, LoadState::Loading));
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Ready(_)
        ));
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
    }

    #[test]
    fn skill_catalogue_membership_authorizes_only_bundled_skill_types() {
        // Bundled catalogue membership authorizes (design
        // skill-icons sections 3-4); nothing else loaded.
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let mut state = AppState::new(false);
        state.install_skill_catalogue_type_ids(&sde);
        assert_eq!(state.skill_catalogue_type_ids.len(), 495);
        // 3300 (Gunnery) is a bundled skill type; it queues once.
        assert!(state.image_id_known(ImageKind::Type, 3300));
        state.request_portrait(ImageKind::Type, 3300);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Loading
        ));
        state.request_portrait(ImageKind::Type, 3300);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        // 34 is not a bundled skill type and 999999 is in no
        // catalogue: both unknown, and neither queues anything.
        assert!(!state.image_id_known(ImageKind::Type, 34));
        assert!(!state.image_id_known(ImageKind::Type, 999999));
        state.request_portrait(ImageKind::Type, 34);
        state.request_portrait(ImageKind::Type, 999999);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 34)));
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 999999)));
        // Nothing installed authorizes nothing.
        let state = AppState::default();
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        // Search text never authorizes, numeric or not.
        let mut state = AppState::new(false);
        state.skill_search = "3300".to_string();
        assert!(!state.image_id_known(ImageKind::Type, 3300));
        state.request_portrait(ImageKind::Type, 3300);
        assert!(state.portrait_requests.is_empty());
        assert!(!state.portraits.contains_key(&(ImageKind::Type, 3300)));
        // Trained state is not the source: Ready with an empty
        // trained list still authorizes via the installed set.
        let mut state = AppState::new(false);
        state.install_skill_catalogue_type_ids(&sde);
        state.skills = LoadState::Ready(SkillsData::default());
        assert!(state.image_id_known(ImageKind::Type, 3300));
        // Kind isolation: a catalogue type id is not an entity key.
        assert!(!state.image_id_known(ImageKind::Character, 3300));
        // Non-positive ids queue nothing.
        state.request_portrait(ImageKind::Type, 0);
        state.request_portrait(ImageKind::Type, -1);
        assert!(state.portrait_requests.is_empty());
    }

    #[test]
    fn skill_catalogue_knowledge_survives_character_switch() {
        // The catalogue arm is static bundled data, not character
        // state, so a switch never revokes it — the opposite of
        // the character-keyed arms (design section 4). The
        // survival is the design, not an oversight.
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two")];
        state.set_active_character(1);
        state.install_skill_catalogue_type_ids(&sde);
        state.skills = LoadState::Ready(SkillsData::default());
        state.portraits.insert(
            (ImageKind::Type, 3300),
            portrait_state_with_dimensions(8, 8),
        );
        assert!(state.image_id_known(ImageKind::Type, 3300));
        // Same-character reselect keeps the knowledge.
        state.set_active_character(1);
        assert!(state.image_id_known(ImageKind::Type, 3300));
        // Switch: the loaded skills reset, the catalogue arm stays.
        state.set_active_character(2);
        assert!(matches!(state.skills, LoadState::Loading));
        assert!(state.image_id_known(ImageKind::Type, 3300));
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Ready(_)
        ));
    }

    #[test]
    fn removing_character_retains_skill_catalogue_icon() {
        // Three characters so neither removal hits the
        // last-removal branch (which clears all portraits).
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let mut state = AppState::new(false);
        state.characters = vec![row(1, "One"), row(2, "Two"), row(3, "Three")];
        state.set_active_character(1);
        state.install_skill_catalogue_type_ids(&sde);
        state.portraits.insert(
            (ImageKind::Type, 3300),
            portrait_state_with_dimensions(8, 8),
        );
        state.portrait_requests = vec![(ImageKind::Type, 3300)];
        // Removing a non-active character keeps the icon.
        state.remove_character(2);
        assert!(state.image_id_known(ImageKind::Type, 3300));
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Ready(_)
        ));
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        // Removing the active character keeps the entry and the
        // guard still reads true (static arm, unlike the assets
        // retain test where the guard reads false afterwards).
        state.remove_character(1);
        assert_eq!(state.active_character_id, Some(3));
        assert!(state.image_id_known(ImageKind::Type, 3300));
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Ready(_)
        ));
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        // The stated exception: removing down to zero characters
        // clears all portrait state, but the installed set stays.
        state.remove_character(3);
        assert!(state.characters.is_empty());
        assert!(state.portraits.is_empty());
        assert!(state.portrait_requests.is_empty());
        assert_eq!(state.skill_catalogue_type_ids.len(), 495);
    }
}
