//! Offline demo data: bundled invented fixtures behind the same model and
//! repository types the live ESI path uses (`crate::esi::models`,
//! `crate::storage::repositories`, `crate::app::state`). No EVE
//! credentials, no network, and no real player data are involved: every
//! character, corporation, and ISK figure in `assets/demo/*.json` is
//! fictional.

use std::collections::{HashMap, HashSet};

use chrono::{DateTime, Utc};

use crate::app::state::{
    market_region_name, ship_display_name, summary_location_name, AppState, AssetsData,
    BlueprintsData, CharacterDetailData, CharacterOrdersData, CharacterSummary, FittingsData,
    IndustryData, IndustryJobsData, LoadState, MarketData, MarketSelection, PlanetSelection,
    PlanetaryData, PublicOrdersData, SelectedColonyDetail, SkillsData, WalletData,
};
use crate::error::{AppError, AppResult};
use crate::esi::models::*;
use crate::names::resolver::NameResolver;
use crate::names::sde::Sde;
use crate::storage::repositories::{
    self, CharacterRow, CharacterSkillRow, LoyaltyRow, SkillQueueRow, UniverseNameRow,
    WalletBalanceRow, WalletJournalRow, WalletTransactionRow,
};

pub const DEMO_CHARACTERS_JSON: &str = include_str!("../../assets/demo/characters.json");
pub const DEMO_SKILLQUEUE_JSON: &str = include_str!("../../assets/demo/skillqueue.json");
pub const DEMO_WALLET_JSON: &str = include_str!("../../assets/demo/wallet.json");
pub const DEMO_NAMES_JSON: &str = include_str!("../../assets/demo/names.json");
pub const DEMO_ASSETS_JSON: &str = include_str!("../../assets/demo/assets.json");
pub const DEMO_CHARACTER_DETAIL_JSON: &str =
    include_str!("../../assets/demo/character_detail.json");
pub const DEMO_MARKET_JSON: &str = include_str!("../../assets/demo/market.json");
pub const DEMO_INDUSTRY_JSON: &str = include_str!("../../assets/demo/industry.json");
pub const DEMO_PLANETS_JSON: &str = include_str!("../../assets/demo/planets.json");
pub const DEMO_FITTINGS_JSON: &str = include_str!("../../assets/demo/fittings.json");

/// Command-line flag that selects demo mode (design section 1).
pub const DEMO_FLAG: &str = "--demo";
/// Environment variable that selects demo mode when set to a truthy value
/// (`1`, `true`, `yes`, `on`, case-insensitive).
pub const DEMO_ENV_VAR: &str = "MIMIR_DEMO";

/// Demo mode was requested via CLI flag or environment variable. Pure so
/// the selection rule is unit-testable without touching process state.
pub fn is_demo_requested(args: &[String], env_value: Option<&str>) -> bool {
    let by_flag = args.iter().any(|a| a == DEMO_FLAG);
    let by_env = env_value
        .map(|v| {
            matches!(
                v.trim().to_ascii_lowercase().as_str(),
                "1" | "true" | "yes" | "on"
            )
        })
        .unwrap_or(false);
    tracing::debug!("[DEMO] is_demo_requested flag={} env={}", by_flag, by_env);
    by_flag || by_env
}

/// Demo selection from this process's arguments and environment. The
/// integrator wires this into `src/main.rs` in place of the scaffold's
/// flag-only check.
pub fn demo_requested_from_process() -> bool {
    let args: Vec<String> = std::env::args().collect();
    let env = std::env::var(DEMO_ENV_VAR).ok();
    let requested = is_demo_requested(&args, env.as_deref());
    tracing::info!("[DEMO] demo_requested_from_process={}", requested);
    requested
}

#[derive(Debug, Clone, Default, serde::Deserialize)]
pub struct DemoCharacter {
    #[serde(default)]
    pub character_id: i64,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub corporation_id: i64,
    #[serde(default)]
    pub alliance_id: Option<i64>,
    #[serde(default)]
    pub security_status: f64,
}

/// One demo character's market fixture: the selection plus raw row
/// sets. Demo seeding composes a `MarketData` from this with the
/// character being applied, so this is deliberately not `MarketData`.
#[derive(Debug, Clone, Default)]
pub struct DemoMarketData {
    pub selected_type_id: i64,
    pub region_id: i64,
    pub public_orders: Vec<RegionalOrder>,
    pub public_orders_truncated: bool,
    pub history: Vec<MarketHistoryEntry>,
    pub character_orders: Vec<CharacterOrder>,
    pub character_orders_truncated: bool,
}

/// One demo character's industry fixture: raw row sets. Demo
/// seeding composes an `IndustryData` from this with both
/// sections Ok, so this is deliberately not `IndustryData`.
#[derive(Debug, Clone, Default)]
pub struct DemoIndustryData {
    pub jobs: Vec<IndustryJob>,
    pub jobs_truncated: bool,
    pub blueprints: Vec<CharacterBlueprint>,
    pub blueprints_truncated: bool,
}

/// One demo character's planetary fixture: the colonies list, the
/// pre-selected colony, and one detail per colony. Demo seeding
/// composes a `PlanetaryData` from this with both sections Ok, so
/// this is deliberately not `PlanetaryData`.
#[derive(Debug, Clone, Default)]
pub struct DemoPlanetaryData {
    pub colonies: Vec<PlanetColony>,
    pub selected_planet_id: Option<i64>,
    pub details: HashMap<i64, PlanetColonyDetail>,
}

/// One demo character's fittings fixture: the fittings list and the
/// pre-selected fitting. Demo seeding composes a `FittingsData`
/// from this with the list Ok, so this is deliberately not
/// `FittingsData`.
#[derive(Debug, Clone, Default)]
pub struct DemoFittingsData {
    pub fittings: Vec<CharacterFitting>,
    pub selected_fitting_id: Option<i64>,
}

/// Everything one demo character shows in the Phase-1 views.
#[derive(Debug, Clone, Default)]
pub struct DemoCharacterData {
    pub skills: CharacterSkills,
    pub queue: Vec<SkillQueueItem>,
    pub balance: f64,
    pub journal: Vec<WalletJournalItem>,
    pub transactions: Vec<WalletTransactionItem>,
    pub loyalty: Vec<LoyaltyPointItem>,
    pub assets: Vec<AssetItem>,
    pub custom_names: Vec<AssetName>,
    pub detail: Option<CharacterDetailData>,
    pub market: Option<DemoMarketData>,
    pub industry: Option<DemoIndustryData>,
    pub planets: Option<DemoPlanetaryData>,
    pub fittings: Option<DemoFittingsData>,
}

#[derive(Debug, Clone, Default)]
pub struct DemoBundle {
    pub characters: Vec<DemoCharacter>,
    /// Per-character view data keyed by character id.
    pub data: HashMap<i64, DemoCharacterData>,
}

impl DemoBundle {
    pub fn character_data(&self, character_id: i64) -> Option<&DemoCharacterData> {
        self.data.get(&character_id)
    }

    pub fn first_character_id(&self) -> Option<i64> {
        self.characters.first().map(|c| c.character_id)
    }
}

#[derive(serde::Deserialize)]
struct CharactersFile {
    #[serde(default)]
    characters: Vec<DemoCharacter>,
}

#[derive(serde::Deserialize, Default)]
struct SkillFileEntry {
    #[serde(default)]
    skills: CharacterSkills,
    #[serde(default)]
    queue: Vec<SkillQueueItem>,
}

#[derive(serde::Deserialize, Default)]
struct WalletFileEntry {
    #[serde(default)]
    balance: f64,
    #[serde(default)]
    journal: Vec<WalletJournalItem>,
    #[serde(default)]
    transactions: Vec<WalletTransactionItem>,
    #[serde(default)]
    loyalty: Vec<LoyaltyPointItem>,
}

#[derive(serde::Deserialize, Default)]
struct AssetsFileEntry {
    #[serde(default)]
    assets: Vec<AssetItem>,
    #[serde(default)]
    custom_names: Vec<AssetName>,
}

#[derive(serde::Deserialize, Default)]
struct CharacterDetailFileEntry {
    #[serde(default)]
    attributes: CharacterAttributes,
    #[serde(default)]
    implants: Vec<i64>,
    #[serde(default)]
    clones: CharacterClones,
    #[serde(default)]
    standings: Vec<Standing>,
    #[serde(default)]
    location: CharacterLocation,
    #[serde(default)]
    ship: CharacterShip,
    #[serde(default)]
    online: CharacterOnline,
}

#[derive(serde::Deserialize, Default)]
struct IndustryFileEntry {
    #[serde(default)]
    jobs: Vec<IndustryJob>,
    #[serde(default)]
    jobs_truncated: bool,
    #[serde(default)]
    blueprints: Vec<CharacterBlueprint>,
    #[serde(default)]
    blueprints_truncated: bool,
}

#[derive(serde::Deserialize, Default)]
struct MarketFileEntry {
    #[serde(default)]
    selected_type_id: i64,
    #[serde(default)]
    region_id: i64,
    #[serde(default)]
    public_orders: Vec<RegionalOrder>,
    #[serde(default)]
    public_orders_truncated: bool,
    #[serde(default)]
    history: Vec<MarketHistoryEntry>,
    #[serde(default)]
    character_orders: Vec<CharacterOrder>,
    #[serde(default)]
    character_orders_truncated: bool,
}

#[derive(serde::Deserialize, Default)]
struct PlanetsFileEntry {
    #[serde(default)]
    colonies: Vec<PlanetColony>,
    #[serde(default)]
    selected_planet_id: Option<i64>,
    #[serde(default)]
    details: HashMap<String, PlanetColonyDetail>,
}

#[derive(serde::Deserialize, Default)]
struct FittingsFileEntry {
    #[serde(default)]
    fittings: Vec<CharacterFitting>,
    #[serde(default)]
    selected_fitting_id: Option<i64>,
}

fn parse_character_key(key: &str) -> AppResult<i64> {
    key.parse::<i64>().map_err(|_| {
        AppError::Message(format!(
            "[DEMO] demo fixture key is not a character id: {key}"
        ))
    })
}

/// Parse a bundle from explicit JSON texts (the bundled constants in
/// production, small literals in tests so error paths are reachable).
/// Kept with its original meaning — a bundle with no assets — so existing
/// three-argument callers and fixtures keep working unchanged.
pub fn load_demo_bundle_from(
    characters_json: &str,
    skillqueue_json: &str,
    wallet_json: &str,
) -> AppResult<DemoBundle> {
    load_demo_bundle_with_assets(characters_json, skillqueue_json, wallet_json, "{}")
}

/// Parse a bundle including the per-character assets file. Kept with
/// its original meaning — no character detail — so four-argument
/// callers keep working unchanged (`detail: None` for everyone).
pub fn load_demo_bundle_with_assets(
    characters_json: &str,
    skillqueue_json: &str,
    wallet_json: &str,
    assets_json: &str,
) -> AppResult<DemoBundle> {
    load_demo_bundle_with_detail(
        characters_json,
        skillqueue_json,
        wallet_json,
        assets_json,
        "{}",
    )
}

/// Parse a bundle including assets and the character-detail file.
/// Kept with its original meaning — no market — so five-argument
/// callers keep working unchanged (`market: None` for everyone).
pub fn load_demo_bundle_with_detail(
    characters_json: &str,
    skillqueue_json: &str,
    wallet_json: &str,
    assets_json: &str,
    character_detail_json: &str,
) -> AppResult<DemoBundle> {
    load_demo_bundle_with_market(
        characters_json,
        skillqueue_json,
        wallet_json,
        assets_json,
        character_detail_json,
        "{}",
    )
}

/// Parse a bundle including assets, character detail, and the market
/// file. Kept with its original meaning — no industry — so
/// six-argument callers keep working unchanged (`industry: None`
/// for everyone). A `"{}"` market text yields `market: None`
/// everywhere.
pub fn load_demo_bundle_with_market(
    characters_json: &str,
    skillqueue_json: &str,
    wallet_json: &str,
    assets_json: &str,
    character_detail_json: &str,
    market_json: &str,
) -> AppResult<DemoBundle> {
    load_demo_bundle_with_industry(
        characters_json,
        skillqueue_json,
        wallet_json,
        assets_json,
        character_detail_json,
        market_json,
        "{}",
    )
}

/// Parse a bundle including assets, character detail, market, and the
/// industry file. Kept with its original meaning — no planets — so
/// seven-argument callers keep working unchanged (`planets: None`
/// for everyone).
pub fn load_demo_bundle_with_industry(
    characters_json: &str,
    skillqueue_json: &str,
    wallet_json: &str,
    assets_json: &str,
    character_detail_json: &str,
    market_json: &str,
    industry_json: &str,
) -> AppResult<DemoBundle> {
    load_demo_bundle_with_planets(
        characters_json,
        skillqueue_json,
        wallet_json,
        assets_json,
        character_detail_json,
        market_json,
        industry_json,
        "{}",
    )
}

/// Parse a bundle including assets, character detail, market, the
/// industry file, and the planets file. A `"{}"` planets text
/// yields `planets: None` everywhere. Kept with its original
/// meaning — no fittings — so eight-argument callers keep working
/// unchanged (`fittings: None` for everyone).
#[allow(clippy::too_many_arguments)]
pub fn load_demo_bundle_with_planets(
    characters_json: &str,
    skillqueue_json: &str,
    wallet_json: &str,
    assets_json: &str,
    character_detail_json: &str,
    market_json: &str,
    industry_json: &str,
    planets_json: &str,
) -> AppResult<DemoBundle> {
    load_demo_bundle_with_fittings(
        characters_json,
        skillqueue_json,
        wallet_json,
        assets_json,
        character_detail_json,
        market_json,
        industry_json,
        planets_json,
        "{}",
    )
}

/// Parse a bundle including assets, character detail, market, the
/// industry file, the planets file, and the fittings file. A `"{}"`
/// fittings text is valid and yields `fittings: None` everywhere.
#[allow(clippy::too_many_arguments)]
pub fn load_demo_bundle_with_fittings(
    characters_json: &str,
    skillqueue_json: &str,
    wallet_json: &str,
    assets_json: &str,
    character_detail_json: &str,
    market_json: &str,
    industry_json: &str,
    planets_json: &str,
    fittings_json: &str,
) -> AppResult<DemoBundle> {
    tracing::debug!("[DEMO] parsing demo bundle");
    let characters: CharactersFile = serde_json::from_str(characters_json)?;
    let skills_by_id: HashMap<String, SkillFileEntry> = serde_json::from_str(skillqueue_json)?;
    let wallet_by_id: HashMap<String, WalletFileEntry> = serde_json::from_str(wallet_json)?;
    let assets_by_id: HashMap<String, AssetsFileEntry> = serde_json::from_str(assets_json)?;
    let detail_by_id: HashMap<String, CharacterDetailFileEntry> =
        serde_json::from_str(character_detail_json)?;
    let market_by_id: HashMap<String, MarketFileEntry> = serde_json::from_str(market_json)?;
    let industry_by_id: HashMap<String, IndustryFileEntry> = serde_json::from_str(industry_json)?;
    let planets_by_id: HashMap<String, PlanetsFileEntry> = serde_json::from_str(planets_json)?;
    let fittings_by_id: HashMap<String, FittingsFileEntry> = serde_json::from_str(fittings_json)?;

    let mut data: HashMap<i64, DemoCharacterData> = HashMap::new();
    for (key, entry) in skills_by_id {
        let id = parse_character_key(&key)?;
        let slot = data.entry(id).or_default();
        slot.skills = entry.skills;
        slot.queue = entry.queue;
        slot.queue.sort_by_key(|q| q.queue_position);
    }
    for (key, entry) in wallet_by_id {
        let id = parse_character_key(&key)?;
        let slot = data.entry(id).or_default();
        slot.balance = entry.balance;
        slot.journal = entry.journal;
        slot.transactions = entry.transactions;
        slot.loyalty = entry.loyalty;
    }
    for (key, entry) in assets_by_id {
        let id = parse_character_key(&key)?;
        tracing::debug!(
            "[DEMO] character_id={} assets={} custom_names={}",
            id,
            entry.assets.len(),
            entry.custom_names.len()
        );
        let slot = data.entry(id).or_default();
        slot.assets = entry.assets;
        slot.custom_names = entry.custom_names;
    }
    for (key, entry) in detail_by_id {
        let id = parse_character_key(&key)?;
        tracing::debug!(
            "[DEMO] character_id={} detail implants={} clones={} standings={}",
            id,
            entry.implants.len(),
            entry.clones.jump_clones.len(),
            entry.standings.len()
        );
        let slot = data.entry(id).or_default();
        slot.detail = Some(CharacterDetailData {
            attributes: Ok(entry.attributes),
            implants: Ok(entry.implants),
            clones: Ok(entry.clones),
            standings: Ok(entry.standings),
            location: Ok(entry.location),
            ship: Ok(entry.ship),
            online: Ok(entry.online),
        });
    }

    for (key, entry) in market_by_id {
        let id = parse_character_key(&key)?;
        tracing::debug!(
            "[DEMO] character_id={} market public_orders={} history={} character_orders={}",
            id,
            entry.public_orders.len(),
            entry.history.len(),
            entry.character_orders.len()
        );
        let slot = data.entry(id).or_default();
        slot.market = Some(DemoMarketData {
            selected_type_id: entry.selected_type_id,
            region_id: entry.region_id,
            public_orders: entry.public_orders,
            public_orders_truncated: entry.public_orders_truncated,
            history: entry.history,
            character_orders: entry.character_orders,
            character_orders_truncated: entry.character_orders_truncated,
        });
    }

    for (key, entry) in industry_by_id {
        let id = parse_character_key(&key)?;
        tracing::debug!(
            "[DEMO] character_id={} industry jobs={} blueprints={}",
            id,
            entry.jobs.len(),
            entry.blueprints.len()
        );
        let slot = data.entry(id).or_default();
        slot.industry = Some(DemoIndustryData {
            jobs: entry.jobs,
            jobs_truncated: entry.jobs_truncated,
            blueprints: entry.blueprints,
            blueprints_truncated: entry.blueprints_truncated,
        });
    }

    for (key, entry) in planets_by_id {
        let id = parse_character_key(&key)?;
        let mut details: HashMap<i64, PlanetColonyDetail> = HashMap::new();
        for (planet_key, detail) in entry.details {
            let planet_id = parse_character_key(&planet_key)?;
            details.insert(planet_id, detail);
        }
        tracing::debug!(
            "[DEMO] character_id={} planets colonies={} details={}",
            id,
            entry.colonies.len(),
            details.len()
        );
        let slot = data.entry(id).or_default();
        slot.planets = Some(DemoPlanetaryData {
            colonies: entry.colonies,
            selected_planet_id: entry.selected_planet_id,
            details,
        });
    }

    for (key, entry) in fittings_by_id {
        let id = parse_character_key(&key)?;
        tracing::debug!(
            "[DEMO] character_id={} fittings={}",
            id,
            entry.fittings.len()
        );
        let slot = data.entry(id).or_default();
        slot.fittings = Some(DemoFittingsData {
            fittings: entry.fittings,
            selected_fitting_id: entry.selected_fitting_id,
        });
    }

    let bundle = DemoBundle {
        characters: characters.characters,
        data,
    };
    validate_bundle(&bundle)?;
    tracing::info!(
        "[DEMO] bundle loaded characters={} with_data={}",
        bundle.characters.len(),
        bundle.data.len()
    );
    Ok(bundle)
}

/// Load the bundled demo JSON files into typed structures.
pub fn load_demo_bundle() -> AppResult<DemoBundle> {
    tracing::debug!("[DEMO] loading bundled demo fixtures");
    load_demo_bundle_with_fittings(
        DEMO_CHARACTERS_JSON,
        DEMO_SKILLQUEUE_JSON,
        DEMO_WALLET_JSON,
        DEMO_ASSETS_JSON,
        DEMO_CHARACTER_DETAIL_JSON,
        DEMO_MARKET_JSON,
        DEMO_INDUSTRY_JSON,
        DEMO_PLANETS_JSON,
        DEMO_FITTINGS_JSON,
    )
}

/// Structural guarantees the views rely on: at least two fictional
/// characters, unique ids, data for every character, contiguous queue
/// positions, parseable queue dates, and journal ids unique across the
/// whole bundle (the `wallet_journal` primary key is the journal id).
pub fn validate_bundle(bundle: &DemoBundle) -> AppResult<()> {
    tracing::debug!(
        "[DEMO] validating bundle characters={}",
        bundle.characters.len()
    );
    let fail = |msg: String| AppError::Message(format!("[DEMO] invalid demo bundle: {msg}"));
    if bundle.characters.len() < 2 {
        return Err(fail("at least two demo characters are required".into()));
    }
    let mut character_ids = HashSet::new();
    let mut journal_ids = HashSet::new();
    for character in &bundle.characters {
        if !character_ids.insert(character.character_id) {
            return Err(fail(format!(
                "duplicate character_id {}",
                character.character_id
            )));
        }
        if character.name.trim().is_empty() {
            return Err(fail(format!(
                "character {} has an empty name",
                character.character_id
            )));
        }
        let Some(per) = bundle.data.get(&character.character_id) else {
            return Err(fail(format!(
                "character {} has no skill/wallet data",
                character.character_id
            )));
        };
        if per.queue.is_empty() {
            return Err(fail(format!(
                "character {} has an empty skill queue",
                character.character_id
            )));
        }
        for (expected, item) in per.queue.iter().enumerate() {
            if item.queue_position != expected as i32 {
                return Err(fail(format!(
                    "character {} queue_position {} expected {}",
                    character.character_id, item.queue_position, expected
                )));
            }
            for raw in [&item.start_date, &item.finish_date].into_iter().flatten() {
                if parse_esi_datetime(raw).is_none() {
                    return Err(fail(format!(
                        "character {} queue date does not parse: {raw}",
                        character.character_id
                    )));
                }
            }
        }
        for entry in &per.journal {
            if !journal_ids.insert(entry.id) {
                return Err(fail(format!("duplicate journal id {}", entry.id)));
            }
        }
        // Assets are optional (old literals carry none); validate only
        // what is present: item IDs unique within the character.
        let mut asset_item_ids = HashSet::new();
        for asset in &per.assets {
            if !asset_item_ids.insert(asset.item_id) {
                return Err(fail(format!(
                    "character {} duplicate asset item_id {}",
                    character.character_id, asset.item_id
                )));
            }
        }
        // Character detail is optional the same way; validate only when
        // present: jump clone IDs unique, every present date parses.
        if let Some(detail) = &per.detail {
            let check_dates = |dates: [&Option<String>; 2]| -> AppResult<()> {
                for raw in dates.into_iter().flatten() {
                    if parse_esi_datetime(raw).is_none() {
                        return Err(fail(format!(
                            "character {} detail date does not parse: {raw}",
                            character.character_id
                        )));
                    }
                }
                Ok(())
            };
            if let Ok(attributes) = &detail.attributes {
                check_dates([
                    &attributes.last_remap_date,
                    &attributes.accrued_remap_cooldown_date,
                ])?;
            }
            if let Ok(clones) = &detail.clones {
                let mut clone_ids = HashSet::new();
                for clone in &clones.jump_clones {
                    if !clone_ids.insert(clone.jump_clone_id) {
                        return Err(fail(format!(
                            "character {} duplicate jump_clone_id {}",
                            character.character_id, clone.jump_clone_id
                        )));
                    }
                }
                check_dates([
                    &clones.last_clone_jump_date,
                    &clones.last_station_change_date,
                ])?;
            }
            if let Ok(online) = &detail.online {
                check_dates([&online.last_login, &online.last_logout])?;
            }
        }
        // Market is optional the same way; validate only when present:
        // hub region, public rows scoped to the selected type, unique
        // order IDs and history dates, every date parses.
        if let Some(market) = &per.market {
            if market_region_name(market.region_id).is_none() {
                return Err(fail(format!(
                    "character {} market region is outside the hub set",
                    character.character_id
                )));
            }
            let mut public_ids = HashSet::new();
            for order in &market.public_orders {
                if order.type_id != market.selected_type_id {
                    return Err(fail(format!(
                        "character {} public order type differs from selected type",
                        character.character_id
                    )));
                }
                if !public_ids.insert(order.order_id) {
                    return Err(fail(format!(
                        "character {} duplicate public order id {}",
                        character.character_id, order.order_id
                    )));
                }
                if parse_esi_datetime(&order.issued).is_none() {
                    return Err(fail(format!(
                        "character {} public order issued does not parse: {}",
                        character.character_id, order.issued
                    )));
                }
            }
            let mut character_ids = HashSet::new();
            for order in &market.character_orders {
                if !character_ids.insert(order.order_id) {
                    return Err(fail(format!(
                        "character {} duplicate character order id {}",
                        character.character_id, order.order_id
                    )));
                }
                if parse_esi_datetime(&order.issued).is_none() {
                    return Err(fail(format!(
                        "character {} character order issued does not parse: {}",
                        character.character_id, order.issued
                    )));
                }
            }
            let mut history_dates = HashSet::new();
            for entry in &market.history {
                if chrono::NaiveDate::parse_from_str(&entry.date, "%Y-%m-%d").is_err() {
                    return Err(fail(format!(
                        "character {} history date does not parse: {}",
                        character.character_id, entry.date
                    )));
                }
                if !history_dates.insert(&entry.date) {
                    return Err(fail(format!(
                        "character {} duplicate history date {}",
                        character.character_id, entry.date
                    )));
                }
            }
        }
        // Industry is optional the same way; validate only when
        // present: job and blueprint item IDs unique, every job
        // start/end and present pause/completed date parses.
        if let Some(industry) = &per.industry {
            let mut job_ids = HashSet::new();
            for job in &industry.jobs {
                if !job_ids.insert(job.job_id) {
                    return Err(fail(format!(
                        "character {} duplicate industry job id {}",
                        character.character_id, job.job_id
                    )));
                }
                for raw in [&job.start_date, &job.end_date] {
                    if parse_esi_datetime(raw).is_none() {
                        return Err(fail(format!(
                            "character {} industry job date does not parse: {raw}",
                            character.character_id
                        )));
                    }
                }
                for raw in [&job.pause_date, &job.completed_date].into_iter().flatten() {
                    if parse_esi_datetime(raw).is_none() {
                        return Err(fail(format!(
                            "character {} industry job date does not parse: {raw}",
                            character.character_id
                        )));
                    }
                }
            }
            let mut item_ids = HashSet::new();
            for blueprint in &industry.blueprints {
                if !item_ids.insert(blueprint.item_id) {
                    return Err(fail(format!(
                        "character {} duplicate blueprint item_id {}",
                        character.character_id, blueprint.item_id
                    )));
                }
            }
        }
        // Planets are optional the same way; validate only when
        // present: unique colony IDs, parseable last-update dates,
        // a selected colony among the list, a detail for every
        // selectable colony and none extra, unique pin IDs within
        // each detail.
        if let Some(planets) = &per.planets {
            let mut colony_ids = HashSet::new();
            for colony in &planets.colonies {
                if !colony_ids.insert(colony.planet_id) {
                    return Err(fail(format!(
                        "character {} duplicate colony planet_id {}",
                        character.character_id, colony.planet_id
                    )));
                }
                if !colony.last_update.is_empty()
                    && parse_esi_datetime(&colony.last_update).is_none()
                {
                    return Err(fail(format!(
                        "character {} colony last_update does not parse: {}",
                        character.character_id, colony.last_update
                    )));
                }
            }
            if !planets.colonies.is_empty() {
                let selected = planets.selected_planet_id.unwrap_or(0);
                if !colony_ids.contains(&selected) {
                    return Err(fail(format!(
                        "character {} selected planet is not among colonies",
                        character.character_id
                    )));
                }
            }
            for colony_id in &colony_ids {
                if !planets.details.contains_key(colony_id) {
                    return Err(fail(format!(
                        "character {} colony {} has no detail",
                        character.character_id, colony_id
                    )));
                }
            }
            for detail_id in planets.details.keys() {
                if !colony_ids.contains(detail_id) {
                    return Err(fail(format!(
                        "character {} detail for unknown colony {}",
                        character.character_id, detail_id
                    )));
                }
            }
            for detail in planets.details.values() {
                let mut pin_ids = HashSet::new();
                for pin in &detail.pins {
                    if !pin_ids.insert(pin.pin_id) {
                        return Err(fail(format!(
                            "character {} duplicate pin id {}",
                            character.character_id, pin.pin_id
                        )));
                    }
                }
            }
        }
        // Fittings are optional the same way; validate only when
        // present: unique fitting IDs, ship and item type IDs
        // present in the demo name set, and a selected fitting
        // among the list.
        if let Some(fittings) = &per.fittings {
            let demo_names: HashSet<i64> = load_demo_names()?.into_iter().map(|n| n.id).collect();
            let mut fitting_ids = HashSet::new();
            for fitting in &fittings.fittings {
                if !fitting_ids.insert(fitting.fitting_id) {
                    return Err(fail(format!(
                        "character {} duplicate fitting_id {}",
                        character.character_id, fitting.fitting_id
                    )));
                }
                if !demo_names.contains(&fitting.ship_type_id) {
                    return Err(fail(format!(
                        "character {} fitting fitting_id {} ship_type_id {} not in demo names",
                        character.character_id, fitting.fitting_id, fitting.ship_type_id
                    )));
                }
                for item in &fitting.items {
                    if !demo_names.contains(&item.type_id) {
                        return Err(fail(format!(
                            "character {} fitting fitting_id {} item type_id {} not in demo names",
                            character.character_id, fitting.fitting_id, item.type_id
                        )));
                    }
                }
            }
            if !fittings.fittings.is_empty() {
                let selected = fittings.selected_fitting_id.unwrap_or(0);
                if !fitting_ids.contains(&selected) {
                    return Err(fail(format!(
                        "character {} selected fitting is not among fittings",
                        character.character_id
                    )));
                }
            }
        }
    }
    tracing::debug!("[DEMO] bundle validation ok");
    Ok(())
}

/// Pre-resolved universe names for demo rows.
pub fn load_demo_names() -> AppResult<Vec<UniverseName>> {
    tracing::debug!("[DEMO] loading demo universe names");
    let names: Vec<UniverseName> = serde_json::from_str(DEMO_NAMES_JSON)?;
    tracing::info!("[DEMO] demo names loaded count={}", names.len());
    Ok(names)
}

/// The demo word for a type id from the bundled name table, used to
/// seed the market selection where no resolver is at hand. Falls back
/// to the resolver's word, never the raw number.
pub fn demo_type_name(type_id: i64) -> String {
    let word = load_demo_names()
        .ok()
        .and_then(|names| names.into_iter().find(|n| n.id == type_id).map(|n| n.name))
        .unwrap_or_else(|| "Unknown Item".to_string());
    tracing::debug!("[DEMO] demo_type_name resolved={}", word);
    word
}

/// Insert every bundled demo name into a resolver; returns how many.
pub fn seed_resolver(resolver: &mut NameResolver) -> AppResult<usize> {
    let names = load_demo_names()?;
    let count = names.len();
    for name in names {
        resolver.insert(name.id, name.name);
    }
    tracing::info!("[DEMO] resolver seeded names={}", count);
    Ok(count)
}

/// A `NameResolver` preloaded with the demo name table. Unknown ids fall
/// back to `Unknown Item` / `Unknown Location`, never a raw numeric ID.
pub fn demo_resolver() -> AppResult<NameResolver> {
    tracing::debug!("[DEMO] building demo name resolver");
    let mut resolver = NameResolver::new();
    seed_resolver(&mut resolver)?;
    Ok(resolver)
}

// ---------------------------------------------------------------------------
// Queue finish math (pure; the same dates the live ESI queue carries)
// ---------------------------------------------------------------------------

/// Parse an ESI ISO-8601 date (`2026-11-20T12:00:00Z`).
pub fn parse_esi_datetime(value: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(value)
        .ok()
        .map(|dt| dt.with_timezone(&Utc))
}

/// Seconds from `now` until this queue item finishes (negative when it
/// already finished); `None` for paused entries without a finish date.
pub fn seconds_until_finish(item: &SkillQueueItem, now: DateTime<Utc>) -> Option<i64> {
    let finish = parse_esi_datetime(item.finish_date.as_deref()?)?;
    Some((finish - now).num_seconds())
}

/// The item training at `now`: started, not yet finished, lowest queue
/// position wins if hand-made data overlaps.
pub fn currently_training(queue: &[SkillQueueItem], now: DateTime<Utc>) -> Option<&SkillQueueItem> {
    let mut sorted: Vec<&SkillQueueItem> = queue.iter().collect();
    sorted.sort_by_key(|q| q.queue_position);
    let found = sorted.into_iter().find(|item| {
        let started = item
            .start_date
            .as_deref()
            .and_then(parse_esi_datetime)
            .map(|start| start <= now)
            .unwrap_or(false);
        let unfinished = seconds_until_finish(item, now)
            .map(|s| s > 0)
            .unwrap_or(false);
        started && unfinished
    });
    tracing::debug!(
        "[DEMO] currently_training found={}",
        found.map(|i| i.skill_id).unwrap_or(0)
    );
    found
}

/// When the whole queue finishes: the latest finish date present.
pub fn queue_end(queue: &[SkillQueueItem]) -> Option<DateTime<Utc>> {
    queue
        .iter()
        .filter_map(|i| i.finish_date.as_deref().and_then(parse_esi_datetime))
        .max()
}

/// Elapsed fraction of one queue item at `now`, clamped to `0.0..=1.0`;
/// `None` when either date is missing or the span is empty.
pub fn training_progress(item: &SkillQueueItem, now: DateTime<Utc>) -> Option<f64> {
    let start = parse_esi_datetime(item.start_date.as_deref()?)?;
    let finish = parse_esi_datetime(item.finish_date.as_deref()?)?;
    let span = (finish - start).num_seconds();
    if span <= 0 {
        return None;
    }
    let elapsed = (now - start).num_seconds();
    Some((elapsed as f64 / span as f64).clamp(0.0, 1.0))
}

// ---------------------------------------------------------------------------
// Wallet aggregation (pure; mirrors the SQL aggregates' meaning in memory)
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct WalletSummary {
    pub income: f64,
    pub expense: f64,
    pub net: f64,
    pub entries: usize,
}

/// Income (sum of positive amounts), expense (sum of negative amounts,
/// kept negative), and net over a journal slice.
pub fn summarize_wallet(journal: &[WalletJournalItem]) -> WalletSummary {
    let mut summary = WalletSummary {
        entries: journal.len(),
        ..WalletSummary::default()
    };
    for entry in journal {
        if entry.amount >= 0.0 {
            summary.income += entry.amount;
        } else {
            summary.expense += entry.amount;
        }
        summary.net += entry.amount;
    }
    tracing::debug!(
        "[DEMO] summarize_wallet entries={} net={:.2}",
        summary.entries,
        summary.net
    );
    summary
}

/// Net ISK per `ref_type`, largest absolute movement first (ties broken by
/// ref_type name so the order is deterministic).
pub fn net_by_ref_type(journal: &[WalletJournalItem]) -> Vec<(String, f64)> {
    let mut totals: HashMap<String, f64> = HashMap::new();
    for entry in journal {
        *totals.entry(entry.ref_type.clone()).or_default() += entry.amount;
    }
    let mut rows: Vec<(String, f64)> = totals.into_iter().collect();
    rows.sort_by(|a, b| {
        b.1.abs()
            .partial_cmp(&a.1.abs())
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| a.0.cmp(&b.0))
    });
    tracing::debug!("[DEMO] net_by_ref_type groups={}", rows.len());
    rows
}

/// Journal entries dated within `days` days before `now` (inclusive).
/// Entries with unparseable dates are excluded.
pub fn journal_since(
    journal: &[WalletJournalItem],
    now: DateTime<Utc>,
    days: i64,
) -> Vec<&WalletJournalItem> {
    let cutoff = now - chrono::Duration::days(days);
    journal
        .iter()
        .filter(|entry| {
            parse_esi_datetime(&entry.date)
                .map(|date| date >= cutoff && date <= now)
                .unwrap_or(false)
        })
        .collect()
}

// ---------------------------------------------------------------------------
// Seeding: UI state and (through F2 repositories only) the database
// ---------------------------------------------------------------------------

/// Show one demo character in the per-view load states. The integrator
/// calls this when the user switches character in demo mode.
pub fn apply_character(state: &mut AppState, bundle: &DemoBundle, character_id: i64) {
    tracing::info!("[DEMO] apply_character character_id={}", character_id);
    let Some(character) = bundle
        .characters
        .iter()
        .find(|c| c.character_id == character_id)
    else {
        tracing::warn!(
            "[DEMO] apply_character unknown character_id={}",
            character_id
        );
        return;
    };
    let Some(per) = bundle.data.get(&character_id) else {
        tracing::warn!(
            "[DEMO] apply_character no data character_id={}",
            character_id
        );
        return;
    };
    let info = CharacterPublicInfo {
        name: character.name.clone(),
        corporation_id: character.corporation_id,
        alliance_id: character.alliance_id,
        security_status: character.security_status,
        ..Default::default()
    };
    state.character_detail = LoadState::Ready(info.clone());
    state.dashboard = LoadState::Ready(info);
    state.skills = LoadState::Ready(SkillsData {
        skills: per.skills.clone(),
        queue: per.queue.clone(),
    });
    state.wallet = LoadState::Ready(WalletData {
        balance: per.balance,
        journal: per.journal.clone(),
        transactions: per.transactions.clone(),
        loyalty: per.loyalty.clone(),
    });
    // Same filter as the live path: ESI's "None" placeholder and empty
    // names never reach AssetsData.
    let custom_names: HashMap<i64, String> = per
        .custom_names
        .iter()
        .filter(|n| !n.name.trim().is_empty() && n.name.trim() != "None")
        .map(|n| (n.item_id, n.name.clone()))
        .collect();
    state.assets = if per.assets.is_empty() {
        LoadState::Empty
    } else {
        LoadState::Ready(AssetsData {
            items: per.assets.clone(),
            custom_names,
        })
    };
    state.assets_needs_reauthorize = false;
    // Empty-if-absent, mirroring assets, so switching can never leave
    // the previous demo character's bundle installed.
    tracing::debug!(
        "[DEMO] apply_character character_id={} detail_present={}",
        character_id,
        per.detail.is_some()
    );
    state.character_details = match &per.detail {
        Some(detail) => LoadState::Ready(detail.clone()),
        None => LoadState::Empty,
    };
    // Empty-if-absent market, same rule: a demo switch can never leave
    // the previous character's bundle or selection installed.
    tracing::debug!(
        "[DEMO] apply_character character_id={} market_present={}",
        character_id,
        per.market.is_some()
    );
    state.clear_market_lookup();
    state.market_generation = state.market_generation.wrapping_add(1);
    match &per.market {
        Some(fixture) => {
            let word = demo_type_name(fixture.selected_type_id);
            state.market_selected_type_id = Some(fixture.selected_type_id);
            state.market_selected_type_name = Some(word.clone());
            state.market_region_id = fixture.region_id;
            state.market = LoadState::Ready(MarketData {
                selection: MarketSelection {
                    type_id: fixture.selected_type_id,
                    type_name: word,
                    region_id: fixture.region_id,
                    character_id: Some(character_id),
                },
                public_orders: Ok(PublicOrdersData {
                    orders: fixture.public_orders.clone(),
                    truncated: fixture.public_orders_truncated,
                }),
                history: Ok(fixture.history.clone()),
                character_orders: Ok(CharacterOrdersData {
                    orders: fixture.character_orders.clone(),
                    truncated: fixture.character_orders_truncated,
                }),
            });
        }
        None => {
            state.market = LoadState::Empty;
            state.market_selected_type_id = None;
            state.market_selected_type_name = None;
        }
    }
    // Empty-if-absent industry, same rule: a demo switch can never
    // leave the previous character's jobs or blueprints installed.
    // Search text and kind filter are view-local and untouched.
    tracing::debug!(
        "[DEMO] apply_character character_id={} industry_present={}",
        character_id,
        per.industry.is_some()
    );
    state.industry = match &per.industry {
        Some(fixture) => LoadState::Ready(IndustryData {
            jobs: Ok(IndustryJobsData {
                jobs: fixture.jobs.clone(),
                truncated: fixture.jobs_truncated,
            }),
            blueprints: Ok(BlueprintsData {
                blueprints: fixture.blueprints.clone(),
                truncated: fixture.blueprints_truncated,
            }),
        }),
        None => LoadState::Empty,
    };
    // Empty-if-absent planetary, same rule: a demo switch can never
    // leave the previous character's colonies, selection, or
    // detail installed.
    tracing::debug!(
        "[DEMO] apply_character character_id={} planets_present={}",
        character_id,
        per.planets.is_some()
    );
    state.planetary_generation = state.planetary_generation.wrapping_add(1);
    state.planetary_detail_fetch_requested = false;
    match &per.planets {
        Some(fixture) if fixture.colonies.is_empty() => {
            // An authored empty character, distinct from absent.
            state.planetary_selected_planet_id = None;
            state.planetary = LoadState::Ready(PlanetaryData {
                colonies: Ok(Vec::new()),
                detail: None,
            });
        }
        Some(fixture) => {
            state.planetary_selected_planet_id = fixture.selected_planet_id;
            let detail = fixture
                .selected_planet_id
                .and_then(|planet_id| fixture.details.get(&planet_id))
                .map(|detail| SelectedColonyDetail {
                    selection: PlanetSelection {
                        character_id,
                        planet_id: fixture.selected_planet_id.unwrap_or(0),
                    },
                    result: Ok(detail.clone()),
                });
            state.planetary = LoadState::Ready(PlanetaryData {
                colonies: Ok(fixture.colonies.clone()),
                detail,
            });
        }
        None => {
            state.planetary = LoadState::Empty;
            state.planetary_selected_planet_id = None;
        }
    }
    // Empty-if-absent fittings, same rule: a demo switch can never
    // leave the previous character's fittings or selection
    // installed. Search text is view-local and untouched.
    tracing::debug!(
        "[DEMO] apply_character character_id={} fittings_present={}",
        character_id,
        per.fittings.is_some()
    );
    match &per.fittings {
        Some(fixture) => {
            let selection = fixture
                .selected_fitting_id
                .filter(|sel| fixture.fittings.iter().any(|f| f.fitting_id == *sel));
            state.fittings_selected_fitting_id = selection;
            state.fittings = LoadState::Ready(FittingsData {
                fittings: Ok(fixture.fittings.clone()),
            });
        }
        None => {
            state.fittings = LoadState::Empty;
            state.fittings_selected_fitting_id = None;
        }
    }
}

/// Seed demo content into the UI state: both fictional characters, the
/// first one active, per-character overview summaries with skill names
/// already resolved through the bundled SDE (never raw skill IDs).
pub fn seed_demo_state(state: &mut AppState) {
    tracing::info!("[DEMO] seed_demo_state entry");
    state.reset_for_mode_switch();
    state.demo = true;
    // Demo hard-off (invariant 5): no clipboard opt-in, no suggestion.
    state.clipboard_opt_in = false;
    state.clipboard_suggestion = None;
    // Host-independent logs path in demo: the settings field
    // must never render the host's expanded home directory
    // (it leaks into screenshots and pixel goldens).
    state.eve_logs_dir = "~/Documents/EVE/logs".to_string();
    state.offline = false;
    match load_demo_bundle() {
        Ok(bundle) => {
            state.characters = bundle
                .characters
                .iter()
                .map(|c| CharacterRow {
                    character_id: c.character_id,
                    name: c.name.clone(),
                    corporation_id: c.corporation_id,
                    alliance_id: c.alliance_id,
                    is_active: false,
                })
                .collect();

            let sde = Sde::load_bundled();
            if let Err(e) = &sde {
                tracing::warn!("[DEMO] SDE unavailable for summaries: {}", e);
            }
            let resolver = demo_resolver();
            if let Err(e) = &resolver {
                tracing::warn!("[DEMO] demo names unavailable for summaries: {}", e);
            }
            let now = state.now_utc();
            state.summaries.clear();
            for character in &bundle.characters {
                let Some(per) = bundle.data.get(&character.character_id) else {
                    continue;
                };
                let training = currently_training(&per.queue, now).or_else(|| per.queue.first());
                // Location/ship summaries come from the detail bundle
                // through the same helpers the live path uses; resolved
                // names only, `None` when anything is missing.
                let (location_name, ship_name) = match (&resolver, &per.detail) {
                    (Ok(resolver), Some(detail)) => {
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
                            Ok(ship) => ship_display_name(
                                &ship.ship_name,
                                resolver.cached(ship.ship_type_id),
                            ),
                            Err(_) => None,
                        };
                        (location_name, ship_name)
                    }
                    _ => (None, None),
                };
                state.summaries.insert(
                    character.character_id,
                    CharacterSummary {
                        balance: Some(per.balance),
                        training_skill_name: match (&sde, training) {
                            (Ok(sde), Some(item)) => Some(sde.skill_name(item.skill_id)),
                            _ => None,
                        },
                        training_finish_date: training.and_then(|item| item.finish_date.clone()),
                        queue_len: Some(per.queue.len()),
                        total_sp: Some(per.skills.total_sp),
                        location_name,
                        ship_name,
                    },
                );
            }

            // Demo Pantry: aggregate every demo character's bundled
            // assets in memory only — zero live-DB reads or writes.
            state.pantry = LoadState::Ready(crate::pantry::PantrySnapshot::new(
                bundle
                    .data
                    .iter()
                    .flat_map(|(character_id, per)| {
                        per.assets.iter().map(move |asset| {
                            crate::pantry::indexer::PantryItem::from_asset(*character_id, asset)
                        })
                    })
                    .collect(),
                Vec::new(),
            ));
            if let Some(first_id) = bundle.first_character_id() {
                state.set_active_character(first_id);
                apply_character(state, &bundle, first_id);
            }
            state.status_message = "Demo mode: sample data, no network.".to_string();
            tracing::info!(
                "[DEMO] seed complete characters={} summaries={}",
                state.characters.len(),
                state.summaries.len()
            );
        }
        Err(e) => {
            tracing::error!("[DEMO] seed failed: {}", e);
            state.status_message = format!("Demo data failed to load: {e}");
            state.skills = LoadState::Error(format!("Demo data failed to load: {e}"));
            state.wallet = LoadState::Error(format!("Demo data failed to load: {e}"));
            state.assets = LoadState::Error(format!("Demo data failed to load: {e}"));
            state.character_details = LoadState::Error(format!("Demo data failed to load: {e}"));
            state.market = LoadState::Error(format!("Demo data failed to load: {e}"));
            state.industry = LoadState::Error(format!("Demo data failed to load: {e}"));
            state.planetary = LoadState::Error(format!("Demo data failed to load: {e}"));
            state.fittings = LoadState::Error(format!("Demo data failed to load: {e}"));
        }
    }
}

/// Seed a bundle through the F2 repositories (never raw SQL here, per the
/// design's cross-builder contract). Idempotent: repository upserts and
/// queue/skill replacements make a second seed converge to the same rows.
pub fn seed_bundle_into_db(conn: &rusqlite::Connection, bundle: &DemoBundle) -> AppResult<()> {
    tracing::info!(
        "[DEMO] seed_bundle_into_db characters={}",
        bundle.characters.len()
    );
    let first_id = bundle.first_character_id();
    // Assets, character detail, market, and industry are in-memory
    // only (no tables); nothing to persist for any of them.
    for character in &bundle.characters {
        repositories::upsert_character(
            conn,
            &CharacterRow {
                character_id: character.character_id,
                name: character.name.clone(),
                corporation_id: character.corporation_id,
                alliance_id: character.alliance_id,
                is_active: Some(character.character_id) == first_id,
            },
        )?;
        let Some(per) = bundle.data.get(&character.character_id) else {
            tracing::warn!(
                "[DEMO] seed skipped data for character_id={}",
                character.character_id
            );
            continue;
        };
        let queue_rows: Vec<SkillQueueRow> = per
            .queue
            .iter()
            .map(|q| SkillQueueRow {
                character_id: character.character_id,
                queue_position: q.queue_position,
                skill_id: q.skill_id,
                finished_level: q.finished_level,
                start_date: q.start_date.clone(),
                finish_date: q.finish_date.clone(),
            })
            .collect();
        repositories::replace_skill_queue(conn, character.character_id, &queue_rows)?;
        let skill_rows: Vec<CharacterSkillRow> = per
            .skills
            .skills
            .iter()
            .map(|s| CharacterSkillRow {
                character_id: character.character_id,
                skill_id: s.skill_id,
                active_skill_level: s.active_skill_level,
                trained_skill_level: s.trained_skill_level,
                skillpoints_in_skill: s.skillpoints_in_skill,
            })
            .collect();
        repositories::replace_character_skills(conn, character.character_id, &skill_rows)?;
        repositories::set_wallet_balance(
            conn,
            &WalletBalanceRow {
                character_id: character.character_id,
                balance: per.balance,
            },
        )?;
        let journal_rows: Vec<WalletJournalRow> = per
            .journal
            .iter()
            .map(|j| WalletJournalRow {
                id: j.id,
                character_id: character.character_id,
                amount: j.amount,
                balance: j.balance,
                date: j.date.clone(),
                description: j.description.clone(),
                ref_type: j.ref_type.clone(),
                first_party_id: j.first_party_id,
                second_party_id: j.second_party_id,
            })
            .collect();
        repositories::upsert_journal(conn, &journal_rows)?;
        let transaction_rows: Vec<WalletTransactionRow> = per
            .transactions
            .iter()
            .map(|t| WalletTransactionRow {
                transaction_id: t.transaction_id,
                character_id: character.character_id,
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
        repositories::upsert_transactions(conn, &transaction_rows)?;
        let loyalty_rows: Vec<LoyaltyRow> = per
            .loyalty
            .iter()
            .map(|l| LoyaltyRow {
                character_id: character.character_id,
                corporation_id: l.corporation_id,
                loyalty_points: l.loyalty_points,
            })
            .collect();
        repositories::replace_loyalty(conn, character.character_id, &loyalty_rows)?;
        tracing::debug!(
            "[DEMO] seeded character_id={} queue={} journal={}",
            character.character_id,
            per.queue.len(),
            per.journal.len()
        );
    }
    let name_rows: Vec<UniverseNameRow> = load_demo_names()?
        .into_iter()
        .map(|n| UniverseNameRow {
            id: n.id,
            name: n.name,
            category: n.category,
        })
        .collect();
    repositories::upsert_universe_names(conn, &name_rows)?;
    tracing::info!("[DEMO] seed_bundle_into_db complete");
    Ok(())
}

/// Load the bundled fixtures and seed them through the F2 repositories.
pub fn seed_into_db(conn: &rusqlite::Connection) -> AppResult<()> {
    tracing::debug!("[DEMO] seed_into_db entry");
    let bundle = load_demo_bundle()?;
    seed_bundle_into_db(conn, &bundle)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixed_now() -> DateTime<Utc> {
        parse_esi_datetime("2026-11-15T12:00:00Z").expect("fixed now parses")
    }

    fn item(skill_id: i64, position: i32, start: &str, finish: &str) -> SkillQueueItem {
        SkillQueueItem {
            skill_id,
            queue_position: position,
            finished_level: 5,
            start_date: Some(start.to_string()),
            finish_date: Some(finish.to_string()),
            ..Default::default()
        }
    }

    #[test]
    fn demo_selection_covers_flag_env_and_rejects_other_values() {
        let args = vec!["mimir".to_string()];
        assert!(!is_demo_requested(&args, None));
        assert!(!is_demo_requested(&args, Some("0")));
        assert!(!is_demo_requested(&args, Some("false")));
        assert!(is_demo_requested(&args, Some("1")));
        assert!(is_demo_requested(&args, Some(" TRUE ")));
        let flagged = vec!["mimir".to_string(), "--demo".to_string()];
        assert!(is_demo_requested(&flagged, None));
    }

    #[test]
    fn queue_math_at_a_fixed_instant() {
        let queue = vec![
            item(3300, 0, "2026-11-10T12:00:00Z", "2026-11-20T12:00:00Z"),
            item(3301, 1, "2026-11-20T12:00:00Z", "2026-11-25T12:00:00Z"),
        ];
        let now = fixed_now();
        assert_eq!(
            currently_training(&queue, now).map(|i| i.skill_id),
            Some(3300)
        );
        // Halfway through a 10-day span: 5 days remain, progress is 0.5.
        assert_eq!(seconds_until_finish(&queue[0], now), Some(5 * 24 * 3600));
        let progress = training_progress(&queue[0], now).expect("progress");
        assert!((progress - 0.5).abs() < 1e-9);
        assert_eq!(
            queue_end(&queue),
            parse_esi_datetime("2026-11-25T12:00:00Z")
        );
        // After the queue ends nothing is training and progress clamps.
        let later = parse_esi_datetime("2027-01-01T00:00:00Z").expect("later parses");
        assert!(currently_training(&queue, later).is_none());
        assert_eq!(training_progress(&queue[0], later), Some(1.0));
        // Paused entries (no dates) produce no finish math.
        let paused = SkillQueueItem::default();
        assert_eq!(seconds_until_finish(&paused, now), None);
        assert_eq!(training_progress(&paused, now), None);
    }

    #[test]
    fn wallet_aggregation_and_windows() {
        let journal = vec![
            WalletJournalItem {
                id: 1,
                amount: 100.0,
                date: "2026-11-15T00:00:00Z".into(),
                ref_type: "bounty_prizes".into(),
                ..Default::default()
            },
            WalletJournalItem {
                id: 2,
                amount: -40.0,
                date: "2026-11-10T00:00:00Z".into(),
                ref_type: "market_transaction".into(),
                ..Default::default()
            },
            WalletJournalItem {
                id: 3,
                amount: 50.0,
                date: "2026-01-01T00:00:00Z".into(),
                ref_type: "bounty_prizes".into(),
                ..Default::default()
            },
        ];
        let summary = summarize_wallet(&journal);
        assert_eq!(summary.income, 150.0);
        assert_eq!(summary.expense, -40.0);
        assert_eq!(summary.net, 110.0);
        assert_eq!(summary.entries, 3);
        let by_ref = net_by_ref_type(&journal);
        assert_eq!(by_ref[0], ("bounty_prizes".to_string(), 150.0));
        assert_eq!(by_ref[1], ("market_transaction".to_string(), -40.0));
        assert_eq!(journal_since(&journal, fixed_now(), 7).len(), 2);
        assert_eq!(journal_since(&journal, fixed_now(), 365).len(), 3);
    }

    #[test]
    fn malformed_and_invalid_bundles_are_errors_not_panics() {
        assert!(load_demo_bundle_from("not json", "{}", "{}").is_err());
        // One character only: fails the two-character floor.
        let one = r#"{"characters":[{"character_id":1,"name":"Solo"}]}"#;
        assert!(load_demo_bundle_from(one, "{}", "{}").is_err());
        // Non-numeric character key in the wallet file.
        let two =
            r#"{"characters":[{"character_id":1,"name":"One"},{"character_id":2,"name":"Two"}]}"#;
        assert!(load_demo_bundle_from(two, "{}", r#"{"nope":{}}"#).is_err());
        // "{}" as the detail text is valid and yields no detail anywhere.
        let bundle = load_demo_bundle_with_detail(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            "{}",
        )
        .expect("empty detail text loads");
        assert!(bundle.data.values().all(|per| per.detail.is_none()));
        // Non-numeric character key in the detail file.
        assert!(load_demo_bundle_with_detail(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            r#"{"nope":{}}"#
        )
        .is_err());
    }

    #[test]
    fn bundled_fixtures_load_and_validate() {
        let bundle = load_demo_bundle().expect("bundled demo data loads");
        assert_eq!(bundle.characters.len(), 2);
        for character in &bundle.characters {
            let per = bundle
                .character_data(character.character_id)
                .expect("per-character data");
            assert!(!per.queue.is_empty());
            assert!(!per.journal.is_empty());
            assert!(per.balance > 0.0);
            assert!(!per.assets.is_empty(), "demo assets for {}", character.name);
            let detail = per
                .detail
                .as_ref()
                .unwrap_or_else(|| panic!("demo detail for {}", character.name));
            assert!(
                detail
                    .attributes
                    .as_ref()
                    .expect("demo attributes ok")
                    .intelligence
                    > 0,
                "non-trivial attributes for {}",
                character.name
            );
            assert!(
                !detail
                    .standings
                    .as_ref()
                    .expect("demo standings ok")
                    .is_empty(),
                "standings for {}",
                character.name
            );
            assert!(detail.location.is_ok() && detail.ship.is_ok() && detail.online.is_ok());
        }
    }

    #[test]
    fn three_argument_loader_still_loads_with_empty_assets() {
        // Backwards-compatibility proof: bundled texts through the
        // original three-argument loader carry no assets.
        let bundle =
            load_demo_bundle_from(DEMO_CHARACTERS_JSON, DEMO_SKILLQUEUE_JSON, DEMO_WALLET_JSON)
                .expect("three-argument bundle loads");
        for per in bundle.data.values() {
            assert!(per.assets.is_empty());
            assert!(per.custom_names.is_empty());
            assert!(per.detail.is_none(), "old loader yields no detail");
            assert!(per.market.is_none(), "old loader yields no market");
            assert!(per.industry.is_none(), "old loader yields no industry");
            assert!(per.planets.is_none(), "old loader yields no planets");
            assert!(per.fittings.is_none(), "old loader yields no fittings");
        }
    }

    #[test]
    fn four_argument_loader_still_loads_without_detail() {
        let bundle = load_demo_bundle_with_assets(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
        )
        .expect("four-argument bundle loads");
        for per in bundle.data.values() {
            assert!(!per.assets.is_empty(), "assets still load");
            assert!(
                per.detail.is_none(),
                "four-argument loader yields no detail"
            );
            assert!(
                per.market.is_none(),
                "four-argument loader yields no market"
            );
            assert!(
                per.industry.is_none(),
                "four-argument loader yields no industry"
            );
            assert!(
                per.planets.is_none(),
                "four-argument loader yields no planets"
            );
            assert!(
                per.fittings.is_none(),
                "four-argument loader yields no fittings"
            );
        }
    }

    #[test]
    fn duplicate_jump_clone_id_fails_validation() {
        let mut bundle = load_demo_bundle().expect("bundled bundle loads");
        let first = bundle.first_character_id().expect("first character");
        let per = bundle.data.get_mut(&first).expect("per-character data");
        let clones = per
            .detail
            .as_mut()
            .expect("detail present")
            .clones
            .as_mut()
            .expect("clones ok");
        let dupe = clones.jump_clones[0].clone();
        clones.jump_clones.push(dupe);
        assert!(validate_bundle(&bundle).is_err());
    }

    #[test]
    fn bad_clone_date_fails_validation() {
        let mut bundle = load_demo_bundle().expect("bundled bundle loads");
        let first = bundle.first_character_id().expect("first character");
        let per = bundle.data.get_mut(&first).expect("per-character data");
        per.detail
            .as_mut()
            .expect("detail present")
            .clones
            .as_mut()
            .expect("clones ok")
            .last_clone_jump_date = Some("not a date".to_string());
        assert!(validate_bundle(&bundle).is_err());
    }

    #[test]
    fn apply_character_swaps_character_details() {
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        let mut state = AppState::new(true);
        apply_character(&mut state, &bundle, 90000001);
        let aria = state.character_details.as_ready().expect("aria details");
        assert_eq!(
            aria.attributes
                .as_ref()
                .expect("aria attributes")
                .intelligence,
            27
        );
        assert_eq!(aria.implants.as_ref().expect("aria implants").len(), 2);
        apply_character(&mut state, &bundle, 90000002);
        let marcus = state.character_details.as_ready().expect("marcus details");
        assert_eq!(
            marcus
                .attributes
                .as_ref()
                .expect("marcus attributes")
                .intelligence,
            20,
            "switch installs Marcus's bundle, no stale Aria section"
        );
        assert!(marcus
            .implants
            .as_ref()
            .expect("marcus implants")
            .is_empty());
        assert!(!marcus.online.as_ref().expect("marcus online").online);
    }

    #[test]
    fn duplicate_asset_item_id_fails_validation() {
        let mut bundle = load_demo_bundle().expect("bundled bundle loads");
        let first = bundle.first_character_id().expect("first character");
        let per = bundle.data.get_mut(&first).expect("per-character data");
        let dupe = per.assets[0].clone();
        per.assets.push(dupe);
        assert!(validate_bundle(&bundle).is_err());
    }

    #[test]
    fn none_custom_names_never_reach_assets_data() {
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        let mut state = AppState::new(true);
        apply_character(&mut state, &bundle, 90000001);
        let assets = state.assets.as_ready().expect("assets ready");
        assert_eq!(
            assets.custom_names.get(&710000002).map(String::as_str),
            Some("Aria's Rifter")
        );
        assert!(
            !assets.custom_names.contains_key(&710000003),
            "\"None\" filtered"
        );
        assert!(!state.assets_needs_reauthorize);
    }

    #[test]
    fn bundled_market_loads_for_both_characters_and_empty_text_is_none() {
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        let aria = bundle
            .character_data(90000001)
            .and_then(|per| per.market.as_ref())
            .expect("aria market fixture");
        assert_eq!(aria.selected_type_id, 34);
        assert_eq!(aria.region_id, 10000002);
        assert!(!aria.public_orders.is_empty());
        assert!(aria.history.len() >= 5);
        assert!(aria.public_orders.iter().any(|o| o.is_buy_order));
        assert!(aria.public_orders.iter().any(|o| !o.is_buy_order));
        let marcus = bundle
            .character_data(90000002)
            .and_then(|per| per.market.as_ref())
            .expect("marcus market fixture");
        assert_eq!(marcus.selected_type_id, 35);
        assert_eq!(marcus.region_id, 10000043);
        assert!(marcus.history.len() >= 5);
        // "{}" market text and every older arity yield no market.
        let empty = load_demo_bundle_with_market(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            "{}",
        )
        .expect("empty market text loads");
        assert!(empty.data.values().all(|per| per.market.is_none()));
        let detail_only = load_demo_bundle_with_detail(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
        )
        .expect("five-argument bundle loads");
        assert!(detail_only.data.values().all(|per| per.market.is_none()));
        assert_eq!(demo_type_name(34), "Tritanium");
        assert_eq!(demo_type_name(424242), "Unknown Item");
    }

    #[test]
    fn market_validation_rejects_bad_fixtures() {
        fn mutate(bundle: &mut DemoBundle, f: impl FnOnce(&mut DemoMarketData)) {
            let first = bundle.first_character_id().expect("first character");
            let per = bundle.data.get_mut(&first).expect("per-character data");
            f(per.market.as_mut().expect("market present"));
        }
        let mut wrong_type = load_demo_bundle().expect("bundle");
        mutate(&mut wrong_type, |m| m.public_orders[0].type_id = 587);
        assert!(validate_bundle(&wrong_type).is_err(), "type mismatch");

        let mut bad_region = load_demo_bundle().expect("bundle");
        mutate(&mut bad_region, |m| m.region_id = 42);
        assert!(validate_bundle(&bad_region).is_err(), "non-hub region");

        let mut dupe_order = load_demo_bundle().expect("bundle");
        mutate(&mut dupe_order, |m| {
            let dupe = m.public_orders[0].clone();
            m.public_orders.push(dupe);
        });
        assert!(validate_bundle(&dupe_order).is_err(), "duplicate order id");

        let mut bad_issued = load_demo_bundle().expect("bundle");
        mutate(&mut bad_issued, |m| {
            m.character_orders[0].issued = "not a date".to_string()
        });
        assert!(validate_bundle(&bad_issued).is_err(), "unparseable issued");

        let mut dupe_date = load_demo_bundle().expect("bundle");
        mutate(&mut dupe_date, |m| {
            let dupe = m.history[0].clone();
            m.history.push(dupe);
        });
        assert!(
            validate_bundle(&dupe_date).is_err(),
            "duplicate history date"
        );
    }

    #[test]
    fn apply_character_swaps_market_and_marketless_clears_selection() {
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        let mut state = AppState::new(true);
        apply_character(&mut state, &bundle, 90000001);
        let aria = state.market.as_ready().expect("aria market ready");
        assert_eq!(aria.selection.character_id, Some(90000001));
        assert_eq!(aria.selection.type_name, "Tritanium");
        assert_eq!(state.market_selected_type_id, Some(34));
        assert_eq!(state.market_region_id, 10000002);
        apply_character(&mut state, &bundle, 90000002);
        let marcus = state.market.as_ready().expect("marcus market ready");
        assert_eq!(marcus.selection.character_id, Some(90000002));
        assert_eq!(marcus.selection.type_name, "Pyerite");
        assert_eq!(state.market_region_id, 10000043);
        // A marketless bundle empties the view and clears the selection
        // (stale-bundle regression guard); the region choice survives.
        let marketless = load_demo_bundle_with_detail(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
        )
        .expect("marketless bundle loads");
        apply_character(&mut state, &marketless, 90000002);
        assert!(matches!(state.market, LoadState::Empty));
        assert_eq!(state.market_selected_type_id, None);
        assert_eq!(state.market_selected_type_name, None);
        assert_eq!(state.market_region_id, 10000043);
    }

    #[test]
    fn bundled_industry_loads_for_both_characters_and_empty_text_is_none() {
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        for character in &bundle.characters {
            let industry = bundle
                .character_data(character.character_id)
                .and_then(|per| per.industry.as_ref())
                .unwrap_or_else(|| panic!("demo industry for {}", character.name));
            assert!(!industry.jobs.is_empty(), "jobs for {}", character.name);
            assert!(
                !industry.blueprints.is_empty(),
                "blueprints for {}",
                character.name
            );
            assert!(!industry.jobs_truncated);
            assert!(!industry.blueprints_truncated);
        }
        // Sentinel spread is present in the shipped fixture.
        let aria = bundle
            .character_data(90000001)
            .and_then(|per| per.industry.as_ref())
            .expect("aria industry");
        assert!(aria
            .blueprints
            .iter()
            .any(|b| b.quantity == -1 && b.runs == -1));
        assert!(aria
            .blueprints
            .iter()
            .any(|b| b.quantity == -2 && b.runs > 0));
        assert!(aria.jobs.iter().any(|j| j.successful_runs.is_some()));
        let marcus = bundle
            .character_data(90000002)
            .and_then(|per| per.industry.as_ref())
            .expect("marcus industry");
        assert!(
            marcus.jobs.iter().any(|j| j.activity_id == 11),
            "reaction job"
        );
        // "{}" industry text and every older arity yield no industry.
        let empty = load_demo_bundle_with_industry(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
            "{}",
        )
        .expect("empty industry text loads");
        assert!(empty.data.values().all(|per| per.industry.is_none()));
        let market_only = load_demo_bundle_with_market(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
        )
        .expect("six-argument bundle loads");
        assert!(market_only.data.values().all(|per| per.industry.is_none()));
        // Non-numeric character key in the industry file.
        assert!(load_demo_bundle_with_industry(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
            r#"{"nope":{}}"#
        )
        .is_err());
    }

    #[test]
    fn industry_validation_rejects_bad_fixtures() {
        fn mutate(bundle: &mut DemoBundle, f: impl FnOnce(&mut DemoIndustryData)) {
            let first = bundle.first_character_id().expect("first character");
            let per = bundle.data.get_mut(&first).expect("per-character data");
            f(per.industry.as_mut().expect("industry present"));
        }
        let mut dupe_job = load_demo_bundle().expect("bundle");
        mutate(&mut dupe_job, |i| {
            let dupe = i.jobs[0].clone();
            i.jobs.push(dupe);
        });
        assert!(validate_bundle(&dupe_job).is_err(), "duplicate job id");

        let mut dupe_item = load_demo_bundle().expect("bundle");
        mutate(&mut dupe_item, |i| {
            let dupe = i.blueprints[0].clone();
            i.blueprints.push(dupe);
        });
        assert!(validate_bundle(&dupe_item).is_err(), "duplicate item id");

        let mut bad_end = load_demo_bundle().expect("bundle");
        mutate(&mut bad_end, |i| {
            i.jobs[0].end_date = "not a date".to_string()
        });
        assert!(validate_bundle(&bad_end).is_err(), "unparseable end");

        let mut bad_start = load_demo_bundle().expect("bundle");
        mutate(&mut bad_start, |i| {
            i.jobs[0].start_date = String::new();
        });
        assert!(validate_bundle(&bad_start).is_err(), "empty start");

        let mut bad_completed = load_demo_bundle().expect("bundle");
        mutate(&mut bad_completed, |i| {
            let job = i
                .jobs
                .iter_mut()
                .find(|j| j.completed_date.is_some())
                .expect("a delivered job");
            job.completed_date = Some("not a date".to_string());
        });
        assert!(
            validate_bundle(&bad_completed).is_err(),
            "unparseable completed date"
        );

        let mut bad_pause = load_demo_bundle().expect("bundle");
        mutate(&mut bad_pause, |i| {
            let job = i
                .jobs
                .iter_mut()
                .find(|j| j.pause_date.is_some())
                .expect("a paused job");
            job.pause_date = Some("not a date".to_string());
        });
        assert!(
            validate_bundle(&bad_pause).is_err(),
            "unparseable pause date"
        );
    }

    #[test]
    fn apply_character_installs_industry_and_industryless_empties() {
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        let mut state = AppState::new(true);
        state.industry_search = "Bantam".to_string();
        apply_character(&mut state, &bundle, 90000001);
        let aria = state.industry.as_ready().expect("aria industry ready");
        assert_eq!(aria.jobs.as_ref().expect("jobs ok").jobs.len(), 4);
        assert_eq!(
            aria.blueprints
                .as_ref()
                .expect("blueprints ok")
                .blueprints
                .len(),
            4
        );
        apply_character(&mut state, &bundle, 90000002);
        let marcus = state.industry.as_ready().expect("marcus industry ready");
        assert_eq!(marcus.jobs.as_ref().expect("jobs ok").jobs.len(), 3);
        assert!(marcus
            .jobs
            .as_ref()
            .expect("jobs ok")
            .jobs
            .iter()
            .all(|j| j.installer_id == 90000002));
        assert_eq!(
            state.industry_search, "Bantam",
            "filter text survives apply"
        );
        // An industry-less bundle empties the view (stale-bundle
        // regression guard) and still preserves the search text.
        let industryless = load_demo_bundle_with_market(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
        )
        .expect("industryless bundle loads");
        apply_character(&mut state, &industryless, 90000002);
        assert!(matches!(state.industry, LoadState::Empty));
        assert_eq!(state.industry_search, "Bantam");
    }

    #[test]
    fn bundled_planets_load_for_both_characters_and_empty_text_is_none() {
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        for character in &bundle.characters {
            let planets = bundle
                .character_data(character.character_id)
                .and_then(|per| per.planets.as_ref())
                .unwrap_or_else(|| panic!("demo planets for {}", character.name));
            assert!(
                !planets.colonies.is_empty(),
                "colonies for {}",
                character.name
            );
            let selected = planets.selected_planet_id.expect("selected planet");
            assert!(planets.colonies.iter().any(|c| c.planet_id == selected));
            for colony in &planets.colonies {
                assert!(planets.details.contains_key(&colony.planet_id));
            }
            assert_eq!(planets.details.len(), planets.colonies.len());
            for detail in planets.details.values() {
                assert!(!detail.pins.is_empty());
            }
        }
        // "{}" planets text and every older arity yield no planets.
        let empty = load_demo_bundle_with_planets(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
            DEMO_INDUSTRY_JSON,
            "{}",
        )
        .expect("empty planets text loads");
        assert!(empty.data.values().all(|per| per.planets.is_none()));
        let industry_only = load_demo_bundle_with_industry(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
            DEMO_INDUSTRY_JSON,
        )
        .expect("seven-argument bundle loads");
        assert!(industry_only.data.values().all(|per| per.planets.is_none()));
        // Non-numeric character key in the planets file.
        assert!(load_demo_bundle_with_planets(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
            DEMO_INDUSTRY_JSON,
            r#"{"nope":{}}"#
        )
        .is_err());
    }

    #[test]
    fn planets_validation_rejects_bad_fixtures() {
        fn mutate(bundle: &mut DemoBundle, f: impl FnOnce(&mut DemoPlanetaryData)) {
            let first = bundle.first_character_id().expect("first character");
            let per = bundle.data.get_mut(&first).expect("per-character data");
            f(per.planets.as_mut().expect("planets present"));
        }
        let mut dupe_colony = load_demo_bundle().expect("bundle");
        mutate(&mut dupe_colony, |p| {
            let dupe = p.colonies[0].clone();
            p.colonies.push(dupe);
        });
        assert!(
            validate_bundle(&dupe_colony).is_err(),
            "duplicate colony id"
        );

        let mut bad_date = load_demo_bundle().expect("bundle");
        mutate(&mut bad_date, |p| {
            p.colonies[0].last_update = "not a date".to_string()
        });
        assert!(
            validate_bundle(&bad_date).is_err(),
            "unparseable last_update"
        );

        let mut missing_selected = load_demo_bundle().expect("bundle");
        mutate(&mut missing_selected, |p| p.selected_planet_id = None);
        assert!(validate_bundle(&missing_selected).is_err(), "no selection");

        let mut missing_detail = load_demo_bundle().expect("bundle");
        mutate(&mut missing_detail, |p| {
            let id = p.colonies[0].planet_id;
            p.details.remove(&id);
        });
        assert!(
            validate_bundle(&missing_detail).is_err(),
            "colony without detail"
        );

        let mut extra_detail = load_demo_bundle().expect("bundle");
        mutate(&mut extra_detail, |p| {
            p.details.insert(700000999, PlanetColonyDetail::default());
        });
        assert!(
            validate_bundle(&extra_detail).is_err(),
            "detail for unknown colony"
        );

        let mut dupe_pin = load_demo_bundle().expect("bundle");
        mutate(&mut dupe_pin, |p| {
            let id = p.colonies[0].planet_id;
            let dupe = p.details[&id].pins[0].clone();
            p.details.get_mut(&id).expect("detail").pins.push(dupe);
        });
        assert!(validate_bundle(&dupe_pin).is_err(), "duplicate pin id");
    }

    #[test]
    fn apply_character_installs_planets_and_planetsless_empties() {
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        let mut state = AppState::new(true);
        apply_character(&mut state, &bundle, 90000001);
        let aria = state.planetary.as_ready().expect("aria planetary ready");
        let aria_colonies = aria.colonies.as_ref().expect("colonies ok");
        assert_eq!(aria_colonies.len(), 2);
        assert_eq!(state.planetary_selected_planet_id, Some(700000001));
        assert!(!state.planetary_detail_fetch_requested);
        let aria_detail = aria.detail.as_ref().expect("aria detail");
        assert_eq!(aria_detail.selection.character_id, 90000001);
        assert_eq!(aria_detail.selection.planet_id, 700000001);
        assert!(aria_detail.result.is_ok());
        // Switching swaps in Marcus's colony and detail.
        apply_character(&mut state, &bundle, 90000002);
        let marcus = state.planetary.as_ready().expect("marcus planetary ready");
        assert_eq!(marcus.colonies.as_ref().expect("colonies ok").len(), 1);
        assert_eq!(state.planetary_selected_planet_id, Some(700000101));
        let marcus_detail = marcus.detail.as_ref().expect("marcus detail");
        assert_eq!(marcus_detail.selection.character_id, 90000002);
        assert_eq!(marcus_detail.selection.planet_id, 700000101);
        // A planets-less bundle empties the view and clears the
        // selection (stale-bundle regression guard).
        let planetsless = load_demo_bundle_with_industry(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
            DEMO_INDUSTRY_JSON,
        )
        .expect("planetsless bundle loads");
        apply_character(&mut state, &planetsless, 90000002);
        assert!(matches!(state.planetary, LoadState::Empty));
        assert_eq!(state.planetary_selected_planet_id, None);
        assert!(!state.planetary_detail_fetch_requested);
    }

    #[test]
    fn bundled_fittings_load_for_both_characters_and_empty_text_is_none() {
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        for character in &bundle.characters {
            let fittings = bundle
                .character_data(character.character_id)
                .and_then(|per| per.fittings.as_ref())
                .unwrap_or_else(|| panic!("demo fittings for {}", character.name));
            assert!(
                !fittings.fittings.is_empty(),
                "fittings for {}",
                character.name
            );
            let selected = fittings.selected_fitting_id.expect("selected fitting");
            assert!(fittings.fittings.iter().any(|f| f.fitting_id == selected));
            for fitting in &fittings.fittings {
                assert!(fitting.ship_type_id > 0);
                for _ in &fitting.items {}
            }
        }
        // "{}" fittings text and every older arity yield no fittings.
        let empty = load_demo_bundle_with_fittings(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
            DEMO_INDUSTRY_JSON,
            DEMO_PLANETS_JSON,
            "{}",
        )
        .expect("empty fittings text loads");
        assert!(empty.data.values().all(|per| per.fittings.is_none()));
        let planets_only = load_demo_bundle_with_planets(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
            DEMO_INDUSTRY_JSON,
            DEMO_PLANETS_JSON,
        )
        .expect("eight-argument bundle loads");
        assert!(planets_only.data.values().all(|per| per.fittings.is_none()));
        // Non-numeric character key in the fittings file.
        assert!(load_demo_bundle_with_fittings(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
            DEMO_INDUSTRY_JSON,
            DEMO_PLANETS_JSON,
            r#"{"nope":{}}"#
        )
        .is_err());
    }

    #[test]
    fn fittings_validation_rejects_bad_fixtures() {
        fn mutate(bundle: &mut DemoBundle, f: impl FnOnce(&mut DemoFittingsData)) {
            let first = bundle.first_character_id().expect("first character");
            let per = bundle.data.get_mut(&first).expect("per-character data");
            f(per.fittings.as_mut().expect("fittings present"));
        }
        let mut dupe = load_demo_bundle().expect("bundle");
        mutate(&mut dupe, |f| {
            let dupe = f.fittings[0].clone();
            f.fittings.push(dupe);
        });
        assert!(validate_bundle(&dupe).is_err(), "duplicate fitting id");

        let mut bad_ship = load_demo_bundle().expect("bundle");
        mutate(&mut bad_ship, |f| f.fittings[0].ship_type_id = 424242);
        assert!(
            validate_bundle(&bad_ship).is_err(),
            "ship not in demo names"
        );

        let mut bad_item = load_demo_bundle().expect("bundle");
        mutate(&mut bad_item, |f| {
            if let Some(first) = f.fittings[0].items.first_mut() {
                first.type_id = 424242;
            }
        });
        assert!(
            validate_bundle(&bad_item).is_err(),
            "item not in demo names"
        );

        let mut bad_selected = load_demo_bundle().expect("bundle");
        mutate(&mut bad_selected, |f| f.selected_fitting_id = Some(999999));
        assert!(
            validate_bundle(&bad_selected).is_err(),
            "selected not among fittings"
        );
    }

    #[test]
    fn apply_character_installs_fittings_and_fittingsless_empties() {
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        let mut state = AppState::new(true);
        apply_character(&mut state, &bundle, 90000001);
        let aria_fittings = state.fittings.as_ready().expect("aria fittings ready");
        let aria_list = aria_fittings.fittings.as_ref().expect("fittings ok");
        assert_eq!(aria_list.len(), 2);
        assert_eq!(state.fittings_selected_fitting_id, Some(1));
        assert!(aria_list.iter().any(|f| f.fitting_id == 1));
        apply_character(&mut state, &bundle, 90000002);
        let marcus_fittings = state.fittings.as_ready().expect("marcus fittings ready");
        let marcus_list = marcus_fittings.fittings.as_ref().expect("fittings ok");
        assert_eq!(marcus_list.len(), 1);
        assert_eq!(state.fittings_selected_fitting_id, Some(10));
        assert!(marcus_list.iter().any(|f| f.fitting_id == 10));
        // Switching never leaks previous character's fittings or selection:
        // a fittings-less bundle empties the view and clears the selection.
        let fittingsless = load_demo_bundle_with_planets(
            DEMO_CHARACTERS_JSON,
            DEMO_SKILLQUEUE_JSON,
            DEMO_WALLET_JSON,
            DEMO_ASSETS_JSON,
            DEMO_CHARACTER_DETAIL_JSON,
            DEMO_MARKET_JSON,
            DEMO_INDUSTRY_JSON,
            DEMO_PLANETS_JSON,
        )
        .expect("fittingsless bundle loads");
        apply_character(&mut state, &fittingsless, 90000002);
        assert!(matches!(state.fittings, LoadState::Empty));
        assert_eq!(state.fittings_selected_fitting_id, None);
    }

    #[test]
    fn demo_structure_location_resolves_through_seeded_names() {
        // Structure-names design sections 11/14.5: the first demo
        // character holds an asset inside a player structure whose
        // name is seeded like every other demo name.
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        let aria = bundle.character_data(90000001).expect("aria data");
        assert!(
            aria.assets
                .iter()
                .any(|a| a.location_id == 1_030_000_000_001),
            "aria holds a structure-class asset"
        );
        let resolver = demo_resolver().expect("demo resolver");
        assert_eq!(
            resolver.location_name(1_030_000_000_001),
            "Demo Astrahus - Voss Logistics Hub"
        );
    }

    #[test]
    fn seed_demo_state_clears_live_portraits_and_pending_flags() {
        let mut state = AppState::new(false);
        state.auth = crate::app::state::AuthState::AwaitingCallback;
        state.portraits.insert(
            (crate::portraits::ImageKind::Type, 34),
            crate::app::state::PortraitState::Loading,
        );
        state
            .portrait_requests
            .push((crate::portraits::ImageKind::Type, 34));
        state.confirm_delete_id = Some(123);
        state.refresh_requested = true;
        state.retry_requested = true;
        state.login_requested = true;
        state.stepup_requested = Some(crate::app::state::StepUpRequest::new(123, &["scope"]));
        state.logout_requested_id = Some(123);
        state.delete_requested_id = Some(123);
        state.market_fetch_requested = true;
        state.market_lookup_requested = Some("Tritanium".to_string());
        state.planetary_detail_fetch_requested = true;
        state.assets_needs_reauthorize = true;
        state.structures_needs_reauthorize = true;
        state.fittings_write_needs_reauthorize = true;

        seed_demo_state(&mut state);

        assert!(state.demo);
        assert_eq!(state.auth, crate::app::state::AuthState::Idle);
        assert!(state.portraits.is_empty());
        assert!(state.portrait_requests.is_empty());
        assert_eq!(state.confirm_delete_id, None);
        assert!(!state.refresh_requested);
        assert!(!state.retry_requested);
        assert!(!state.login_requested);
        assert_eq!(state.stepup_requested, None);
        assert_eq!(state.logout_requested_id, None);
        assert_eq!(state.delete_requested_id, None);
        assert!(!state.market_fetch_requested);
        assert_eq!(state.market_lookup_requested, None);
        assert!(!state.planetary_detail_fetch_requested);
        assert!(!state.assets_needs_reauthorize);
        assert!(!state.structures_needs_reauthorize);
        assert!(!state.fittings_write_needs_reauthorize);
    }

    #[test]
    fn seed_demo_state_clears_drafts_even_when_live_character_id_overlaps_demo() {
        let mut state = AppState::new(false);
        state.characters = vec![CharacterRow {
            character_id: 90000001,
            name: "Live Overlap".to_string(),
            corporation_id: 98000001,
            alliance_id: None,
            is_active: true,
        }];
        state.active_character_id = Some(90000001);
        state.selected_queue_row = 4;
        state.selected_journal_row = 7;
        state.fittings_selected_fitting_id = Some(555);
        state.fittings_import_text = "[Rifter, Live Draft]".to_string();
        state.fittings_imported = Some(crate::fitting::eft::ImportedFitting {
            name: "Live Draft".to_string(),
            ship_type_id: 587,
            ship_name: "Rifter".to_string(),
            format: crate::fitting::eft::ImportFormat::Eft,
            items: Vec::new(),
            report: crate::fitting::eft::ImportReport {
                imported_lines: 0,
                placeholder_lines: 0,
                charges_noted: 0,
                issues: Vec::new(),
            },
        });
        state.fittings_import_error = Some("live import error".to_string());
        state.fittings_import_edited = true;
        state.fittings_editor_error = Some("live editor error".to_string());
        state.selected_skill_plan_id = Some(777);
        state.skill_plan_editor = Some(crate::app::state::SkillPlanEditor::Create {
            character_id: 90000001,
        });
        state.skill_plan_name_draft = "Live Plan Draft".to_string();
        state.skill_plan_description_draft = "Secret live draft notes".to_string();
        state.skill_plan_picker_open = true;
        state.skill_plan_picker_search = "Live Filter".to_string();
        state.fittings_editor_add_name = "Damage Control II".to_string();
        state.fittings_editor_quantity.insert(0, "42".to_string());
        state.market_selected_type_id = Some(999_999);
        state.market_selected_type_name = Some("Live Bogus Item".to_string());
        state.planetary_selected_planet_id = Some(999_999);
        state.focus_search = true;

        let prev_active_gen = state.active_character_generation;
        let prev_market_gen = state.market_generation;
        let prev_planetary_gen = state.planetary_generation;

        seed_demo_state(&mut state);

        assert!(state.demo);
        assert_eq!(state.active_character_id, Some(90000001));
        assert!(state.active_character_generation > prev_active_gen);
        assert!(state.market_generation > prev_market_gen);
        assert!(state.planetary_generation > prev_planetary_gen);
        assert_eq!(state.selected_queue_row, 0);
        assert_eq!(state.selected_journal_row, 0);
        assert_ne!(state.fittings_selected_fitting_id, Some(555));
        assert!(state.fittings_import_text.is_empty());
        assert!(state.fittings_imported.is_none());
        assert_eq!(state.fittings_import_error, None);
        assert!(!state.fittings_import_edited);
        assert_eq!(state.fittings_editor_error, None);
        assert!(state.fittings_editor_add_name.is_empty());
        assert!(state.fittings_editor_quantity.is_empty());
        assert_eq!(state.selected_skill_plan_id, None);
        assert_eq!(state.skill_plan_editor, None);
        assert!(state.skill_plan_name_draft.is_empty());
        assert!(state.skill_plan_description_draft.is_empty());
        assert!(!state.skill_plan_picker_open);
        assert!(state.skill_plan_picker_search.is_empty());
        assert_ne!(state.market_selected_type_id, Some(999_999));
        assert_ne!(
            state.market_selected_type_name.as_deref(),
            Some("Live Bogus Item")
        );
        assert_ne!(state.planetary_selected_planet_id, Some(999_999));
        assert!(!state.focus_search);
    }
}
