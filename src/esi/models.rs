//! Serde models for the Phase-1 ESI endpoint set. Field sets mirror the
//! Flutter models in `lib/core/network/esi_client.dart`; unknown ESI fields
//! are ignored and every field defaults so partial payloads still parse.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterPublicInfo {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub corporation_id: i64,
    #[serde(default)]
    pub alliance_id: Option<i64>,
    #[serde(default)]
    pub birthday: String,
    #[serde(default)]
    pub bloodline_id: i64,
    #[serde(default)]
    pub race_id: i64,
    #[serde(default)]
    pub security_status: f64,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub faction_id: Option<i64>,
    #[serde(default)]
    pub gender: Option<String>,
    #[serde(default)]
    pub title: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Skill {
    #[serde(default)]
    pub skill_id: i64,
    #[serde(default)]
    pub active_skill_level: i32,
    #[serde(default)]
    pub trained_skill_level: i32,
    #[serde(default)]
    pub skillpoints_in_skill: i64,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterSkills {
    #[serde(default)]
    pub skills: Vec<Skill>,
    #[serde(default)]
    pub total_sp: i64,
    #[serde(default)]
    pub unallocated_sp: Option<i64>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SkillQueueItem {
    #[serde(default)]
    pub skill_id: i64,
    #[serde(default)]
    pub finished_level: i32,
    #[serde(default)]
    pub queue_position: i32,
    #[serde(default)]
    pub start_date: Option<String>,
    #[serde(default)]
    pub finish_date: Option<String>,
    #[serde(default)]
    pub level_start_sp: Option<i64>,
    #[serde(default)]
    pub level_end_sp: Option<i64>,
    #[serde(default)]
    pub training_start_sp: Option<i64>,
}

impl SkillQueueItem {
    /// True for the head-of-queue item that has started training.
    pub fn is_training(&self) -> bool {
        self.queue_position == 0 && self.start_date.is_some()
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterAttributes {
    #[serde(default)]
    pub charisma: i32,
    #[serde(default)]
    pub intelligence: i32,
    #[serde(default)]
    pub memory: i32,
    #[serde(default)]
    pub perception: i32,
    #[serde(default)]
    pub willpower: i32,
    #[serde(default)]
    pub bonus_remaps: Option<i32>,
    #[serde(default)]
    pub last_remap_date: Option<String>,
    #[serde(default)]
    pub accrued_remap_cooldown_date: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct WalletJournalItem {
    #[serde(default)]
    pub id: i64,
    #[serde(default)]
    pub amount: f64,
    #[serde(default)]
    pub balance: f64,
    #[serde(default)]
    pub date: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub ref_type: String,
    #[serde(default)]
    pub first_party_id: Option<i64>,
    #[serde(default)]
    pub second_party_id: Option<i64>,
    #[serde(default)]
    pub context_id: Option<i64>,
    #[serde(default)]
    pub context_id_type: Option<String>,
    #[serde(default)]
    pub reason: Option<String>,
    #[serde(default)]
    pub tax: Option<f64>,
    #[serde(default)]
    pub tax_receiver_id: Option<i64>,
}

impl WalletJournalItem {
    pub fn is_income(&self) -> bool {
        self.amount >= 0.0
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct WalletTransactionItem {
    #[serde(default)]
    pub transaction_id: i64,
    #[serde(default)]
    pub journal_ref_id: i64,
    #[serde(default)]
    pub date: String,
    #[serde(default)]
    pub type_id: i64,
    #[serde(default)]
    pub quantity: i64,
    #[serde(default)]
    pub unit_price: f64,
    #[serde(default)]
    pub is_buy: bool,
    #[serde(default)]
    pub is_personal: bool,
    #[serde(default)]
    pub client_id: i64,
    #[serde(default)]
    pub location_id: i64,
}

impl WalletTransactionItem {
    pub fn total_value(&self) -> f64 {
        self.unit_price * self.quantity as f64
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct LoyaltyPointItem {
    #[serde(default)]
    pub corporation_id: i64,
    #[serde(default)]
    pub loyalty_points: i64,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterLocation {
    #[serde(default)]
    pub solar_system_id: i64,
    #[serde(default)]
    pub station_id: Option<i64>,
    #[serde(default)]
    pub structure_id: Option<i64>,
}

impl CharacterLocation {
    /// Station or structure the character is docked in, if any. Callers must
    /// resolve this ID to a name before display (never show the raw ID).
    pub fn docked_location_id(&self) -> Option<i64> {
        self.station_id.or(self.structure_id)
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterShip {
    #[serde(default)]
    pub ship_item_id: i64,
    #[serde(default)]
    pub ship_name: String,
    #[serde(default)]
    pub ship_type_id: i64,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterOnline {
    #[serde(default)]
    pub online: bool,
    #[serde(default)]
    pub last_login: Option<String>,
    #[serde(default)]
    pub last_logout: Option<String>,
    #[serde(default)]
    pub logins: Option<i64>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct JumpClone {
    #[serde(default)]
    pub jump_clone_id: i64,
    #[serde(default)]
    pub location_id: i64,
    #[serde(default)]
    pub location_type: String,
    #[serde(default)]
    pub implants: Vec<i64>,
    #[serde(default)]
    pub name: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct HomeLocation {
    #[serde(default)]
    pub location_id: i64,
    #[serde(default)]
    pub location_type: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterClones {
    #[serde(default)]
    pub jump_clones: Vec<JumpClone>,
    #[serde(default)]
    pub last_clone_jump_date: Option<String>,
    #[serde(default)]
    pub last_station_change_date: Option<String>,
    #[serde(default)]
    pub home_location: Option<HomeLocation>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Standing {
    #[serde(default)]
    pub from_id: i64,
    #[serde(default)]
    pub from_type: String,
    #[serde(default)]
    pub standing: f64,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct UniverseName {
    #[serde(default)]
    pub id: i64,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub category: String,
}

/// One resolved entity inside a `POST /universe/ids/` response category.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct UniverseIdEntry {
    #[serde(default)]
    pub id: i64,
    #[serde(default)]
    pub name: String,
}

/// `POST /universe/ids/` response: names grouped by category.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct UniverseIds {
    #[serde(default)]
    pub characters: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub corporations: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub alliances: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub factions: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub inventory_types: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub regions: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub constellations: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub systems: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub planets: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub stargates: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub stars: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub stations: Vec<UniverseIdEntry>,
    #[serde(default)]
    pub agents: Vec<UniverseIdEntry>,
}

impl UniverseIds {
    /// Flatten every category into `UniverseName` rows with `category` set
    /// to the ESI category name, so callers treat `/ids/` like `/names/`.
    pub fn flatten(&self) -> Vec<UniverseName> {
        let groups: [(&str, &Vec<UniverseIdEntry>); 13] = [
            ("character", &self.characters),
            ("corporation", &self.corporations),
            ("alliance", &self.alliances),
            ("faction", &self.factions),
            ("inventory_type", &self.inventory_types),
            ("region", &self.regions),
            ("constellation", &self.constellations),
            ("solar_system", &self.systems),
            ("planet", &self.planets),
            ("stargate", &self.stargates),
            ("star", &self.stars),
            ("station", &self.stations),
            ("agent", &self.agents),
        ];
        let mut out = Vec::new();
        for (category, entries) in groups {
            for e in entries {
                out.push(UniverseName {
                    id: e.id,
                    name: e.name.clone(),
                    category: category.to_string(),
                });
            }
        }
        out
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StationInfo {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub system_id: i64,
    #[serde(default)]
    pub type_id: i64,
    #[serde(default)]
    pub owner: Option<i64>,
    #[serde(default)]
    pub race_id: Option<i64>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StructureInfo {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub solar_system_id: i64,
    #[serde(default)]
    pub type_id: i64,
    #[serde(default)]
    pub owner_id: Option<i64>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CorporationInfo {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub ticker: String,
    #[serde(default)]
    pub member_count: i64,
    #[serde(default)]
    pub alliance_id: Option<i64>,
    #[serde(default)]
    pub ceo_id: Option<i64>,
    #[serde(default)]
    pub tax_rate: Option<f64>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AllianceInfo {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub ticker: String,
    #[serde(default)]
    pub creator_corporation_id: Option<i64>,
    #[serde(default)]
    pub executor_corporation_id: Option<i64>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AssetItem {
    #[serde(default)]
    pub item_id: i64,
    #[serde(default)]
    pub type_id: i64,
    #[serde(default)]
    pub quantity: i64,
    #[serde(default)]
    pub location_id: i64,
    #[serde(default)]
    pub location_flag: String,
    #[serde(default)]
    pub location_type: String,
    #[serde(default)]
    pub is_singleton: bool,
    #[serde(default)]
    pub is_blueprint_copy: Option<bool>,
}

/// One custom name for a singleton item instance, from
/// `POST /characters/{id}/assets/names/`. Names are per-instance and
/// must never enter the universe-name resolver cache (design D6).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AssetName {
    #[serde(default)]
    pub item_id: i64,
    #[serde(default)]
    pub name: String,
}

/// One public regional order from `GET /markets/{region_id}/orders/`.
/// `order_id` is an invisible sort tie-break only: never rendered,
/// never name-resolved, never logged per-row.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RegionalOrder {
    #[serde(default)]
    pub order_id: i64,
    #[serde(default)]
    pub type_id: i64,
    #[serde(default)]
    pub location_id: i64,
    #[serde(default)]
    pub system_id: i64,
    #[serde(default)]
    pub price: f64,
    #[serde(default)]
    pub volume_remain: i64,
    #[serde(default)]
    pub volume_total: i64,
    #[serde(default)]
    pub min_volume: i64,
    #[serde(default)]
    pub is_buy_order: bool,
    #[serde(default)]
    pub issued: String,
    #[serde(default)]
    pub duration: i64,
    #[serde(default)]
    pub range: String,
}

/// One of a character's own open orders from
/// `GET /characters/{character_id}/orders/`. `region_id` parses and
/// is carried, but is never rendered or scheduled for naming.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterOrder {
    #[serde(default)]
    pub order_id: i64,
    #[serde(default)]
    pub type_id: i64,
    #[serde(default)]
    pub region_id: i64,
    #[serde(default)]
    pub location_id: i64,
    #[serde(default)]
    pub price: f64,
    #[serde(default)]
    pub volume_remain: i64,
    #[serde(default)]
    pub volume_total: i64,
    #[serde(default)]
    pub min_volume: i64,
    #[serde(default)]
    pub is_buy_order: bool,
    #[serde(default)]
    pub issued: String,
    #[serde(default)]
    pub duration: i64,
    #[serde(default)]
    pub range: String,
    #[serde(default)]
    pub is_corporation: bool,
    #[serde(default)]
    pub escrow: Option<f64>,
}

/// One day of `GET /markets/{region_id}/history/`. Volume and
/// order-count sums over these rows saturate (design section 7.3).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MarketHistoryEntry {
    #[serde(default)]
    pub date: String,
    #[serde(default)]
    pub average: f64,
    #[serde(default)]
    pub highest: f64,
    #[serde(default)]
    pub lowest: f64,
    #[serde(default)]
    pub order_count: i64,
    #[serde(default)]
    pub volume: i64,
}

/// One of a character's blueprints from
/// `GET /characters/{character_id}/blueprints/`. `item_id` is an
/// item-instance id: an invisible sort tie-break only, never
/// rendered and never name-resolved. `quantity` carries the ESI
/// sentinels -1 and -2 and `runs` carries -1 for an original;
/// both render as words in the view (design section 7.3), never
/// as raw counts. `location_flag` parses and is carried but is
/// not rendered in this slice.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterBlueprint {
    #[serde(default)]
    pub item_id: i64,
    #[serde(default)]
    pub type_id: i64,
    #[serde(default)]
    pub location_id: i64,
    #[serde(default)]
    pub location_flag: String,
    #[serde(default)]
    pub quantity: i64,
    #[serde(default)]
    pub time_efficiency: i64,
    #[serde(default)]
    pub material_efficiency: i64,
    #[serde(default)]
    pub runs: i64,
}

/// One character industry job from
/// `GET /characters/{character_id}/industry/jobs/`. `job_id`,
/// `blueprint_id` (the used blueprint's item-instance id),
/// `installer_id`, and `completed_character_id` are never
/// rendered and never name-resolved; `job_id` is an invisible
/// sort tie-break only. `cost`, `probability`,
/// `licensed_production_runs`, `duration`, `location_id`, and
/// `output_location_id` parse and are carried but are never
/// rendered and never enter any computation (no calculator).
/// Nullability is preserved exactly: a null `cost` stays `None`
/// and is never coerced to zero.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct IndustryJob {
    #[serde(default)]
    pub job_id: i64,
    #[serde(default)]
    pub installer_id: i64,
    #[serde(default)]
    pub facility_id: i64,
    #[serde(default)]
    pub location_id: i64,
    #[serde(default)]
    pub activity_id: i64,
    #[serde(default)]
    pub blueprint_id: i64,
    #[serde(default)]
    pub blueprint_type_id: i64,
    #[serde(default)]
    pub output_location_id: i64,
    #[serde(default)]
    pub runs: i64,
    #[serde(default)]
    pub cost: Option<f64>,
    #[serde(default)]
    pub licensed_production_runs: Option<i64>,
    #[serde(default)]
    pub probability: Option<f64>,
    #[serde(default)]
    pub product_type_id: Option<i64>,
    #[serde(default)]
    pub status: String,
    #[serde(default)]
    pub duration: i64,
    #[serde(default)]
    pub start_date: String,
    #[serde(default)]
    pub end_date: String,
    #[serde(default)]
    pub pause_date: Option<String>,
    #[serde(default)]
    pub completed_date: Option<String>,
    #[serde(default)]
    pub completed_character_id: Option<i64>,
    #[serde(default)]
    pub successful_runs: Option<i64>,
}

/// One colony from `GET /characters/{character_id}/planets/`.
/// `planet_id` is a per-instance identity: selection identity and
/// invisible sort tie-break only, never rendered and never sent to
/// universe name resolution. `planet_type` is the ESI word (e.g.
/// `temperate`); it is rendered only through the view whitelist,
/// never echoed verbatim. `solar_system_id` is resolved via the
/// location path.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PlanetColony {
    #[serde(default)]
    pub planet_id: i64,
    #[serde(default)]
    pub planet_type: String,
    #[serde(default)]
    pub solar_system_id: i64,
    #[serde(default)]
    pub last_update: String,
    #[serde(default)]
    pub upgrade_level: i64,
    #[serde(default)]
    pub num_pins: i64,
}

/// One colony's detail object from
/// `GET /characters/{character_id}/planets/{planet_id}/`. `links`
/// and `routes` are carried raw and never rendered, counted, or
/// name-resolved; their lengths may appear in one `[PI]` info log
/// line only.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PlanetColonyDetail {
    #[serde(default)]
    pub pins: Vec<PlanetPin>,
    #[serde(default)]
    pub links: Vec<serde_json::Value>,
    #[serde(default)]
    pub routes: Vec<serde_json::Value>,
}

/// One pin inside a colony detail. `pin_id` is a per-instance
/// identity: an invisible sort tie-break only, never rendered and
/// never name-resolved. `type_id` resolves via the item-name path.
/// `latitude`/`longitude` and `install_time` are carried but never
/// rendered; `schematic_id` is carried but never rendered,
/// resolved, or computed with (no calculator in this slice).
/// Nullability is preserved exactly: `None` is never coerced to
/// zero.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PlanetPin {
    #[serde(default)]
    pub pin_id: i64,
    #[serde(default)]
    pub type_id: i64,
    #[serde(default)]
    pub latitude: f64,
    #[serde(default)]
    pub longitude: f64,
    #[serde(default)]
    pub install_time: String,
    #[serde(default)]
    pub expiry_time: Option<String>,
    #[serde(default)]
    pub last_cycle_start: Option<String>,
    #[serde(default)]
    pub schematic_id: Option<i64>,
    #[serde(default)]
    pub extractor_details: Option<ExtractorDetails>,
    #[serde(default)]
    pub contents: Vec<PinContent>,
}

/// Extractor fields carried on a pin, present only when the wire
/// payload carries an `extractor_details` object. Nullability is
/// preserved exactly: `None` is never coerced to zero.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ExtractorDetails {
    #[serde(default)]
    pub product_type_id: Option<i64>,
    #[serde(default)]
    pub qty_per_cycle: Option<i64>,
    #[serde(default)]
    pub cycle_time: Option<i64>,
}

/// One stored-items entry inside a pin's `contents`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PinContent {
    #[serde(default)]
    pub type_id: i64,
    #[serde(default)]
    pub amount: i64,
}

/// ESI error body shape: `{"error": "..."}`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EsiErrorBody {
    #[serde(default)]
    pub error: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn journal_with_optionals_parses() {
        let item: WalletJournalItem = serde_json::from_str(
            r#"{"id":7,"amount":-50.5,"balance":900.0,"date":"2026-01-01T00:00:00Z",
                "description":"x","ref_type":"market_transaction","context_id":42,
                "context_id_type":"market_transaction_id","tax":1.5}"#,
        )
        .expect("parses");
        assert_eq!(item.context_id, Some(42));
        assert!(!item.is_income());
    }

    #[test]
    fn transaction_total_value() {
        let t = WalletTransactionItem {
            quantity: 3,
            unit_price: 10.0,
            ..Default::default()
        };
        assert_eq!(t.total_value(), 30.0);
    }

    #[test]
    fn universe_ids_flatten_sets_categories() {
        let ids: UniverseIds = serde_json::from_str(
            r#"{"characters":[{"id":1,"name":"A"}],"systems":[{"id":30000142,"name":"Jita"}]}"#,
        )
        .expect("parses");
        let flat = ids.flatten();
        assert_eq!(flat.len(), 2);
        assert_eq!(flat[1].name, "Jita");
        assert_eq!(flat[1].category, "solar_system");
    }

    #[test]
    fn asset_item_full_row_parses() {
        let item: AssetItem = serde_json::from_str(
            r#"{"item_id":710000002,"type_id":587,"quantity":1,
                "location_id":60003760,"location_flag":"Hangar",
                "location_type":"station","is_singleton":true,
                "is_blueprint_copy":false}"#,
        )
        .expect("parses");
        assert_eq!(item.item_id, 710000002);
        assert_eq!(item.type_id, 587);
        assert_eq!(item.quantity, 1);
        assert_eq!(item.location_id, 60003760);
        assert_eq!(item.location_flag, "Hangar");
        assert_eq!(item.location_type, "station");
        assert!(item.is_singleton);
        assert_eq!(item.is_blueprint_copy, Some(false));
    }

    #[test]
    fn asset_item_defaults_and_blueprint_copy_variants() {
        let empty: AssetItem = serde_json::from_str("{}").expect("parses");
        assert_eq!(empty.item_id, 0);
        assert_eq!(empty.type_id, 0);
        assert_eq!(empty.quantity, 0);
        assert_eq!(empty.location_id, 0);
        assert!(empty.location_flag.is_empty());
        assert!(empty.location_type.is_empty());
        assert!(!empty.is_singleton);
        assert_eq!(empty.is_blueprint_copy, None);

        let copy: AssetItem =
            serde_json::from_str(r#"{"is_blueprint_copy":true}"#).expect("parses");
        assert_eq!(copy.is_blueprint_copy, Some(true));
        let null: AssetItem =
            serde_json::from_str(r#"{"is_blueprint_copy":null}"#).expect("parses");
        assert_eq!(null.is_blueprint_copy, None);
    }

    #[test]
    fn asset_name_parses_and_defaults() {
        let name: AssetName =
            serde_json::from_str(r#"{"item_id":710000002,"name":"Aria's Rifter"}"#)
                .expect("parses");
        assert_eq!(name.item_id, 710000002);
        assert_eq!(name.name, "Aria's Rifter");
        let empty: AssetName = serde_json::from_str("{}").expect("parses");
        assert_eq!(empty.item_id, 0);
        assert!(empty.name.is_empty());
    }

    #[test]
    fn regional_order_full_row_parses_and_defaults() {
        let order: RegionalOrder = serde_json::from_str(
            r#"{"order_id":123456,"type_id":34,"location_id":60003760,
                "system_id":30000142,"price":5.5,"volume_remain":900,
                "volume_total":1000,"min_volume":1,"is_buy_order":true,
                "issued":"2026-11-01T12:00:00Z","duration":90,"range":"station",
                "unknown_future_field":true}"#,
        )
        .expect("parses");
        assert_eq!(order.order_id, 123456);
        assert_eq!(order.type_id, 34);
        assert_eq!(order.location_id, 60003760);
        assert_eq!(order.system_id, 30000142);
        assert_eq!(order.price, 5.5);
        assert_eq!(order.volume_remain, 900);
        assert_eq!(order.volume_total, 1000);
        assert_eq!(order.min_volume, 1);
        assert!(order.is_buy_order);
        assert_eq!(order.issued, "2026-11-01T12:00:00Z");
        assert_eq!(order.duration, 90);
        assert_eq!(order.range, "station");

        let empty: RegionalOrder = serde_json::from_str("{}").expect("parses");
        assert_eq!(empty.order_id, 0);
        assert_eq!(empty.type_id, 0);
        assert_eq!(empty.location_id, 0);
        assert_eq!(empty.system_id, 0);
        assert_eq!(empty.price, 0.0);
        assert_eq!(empty.volume_remain, 0);
        assert_eq!(empty.volume_total, 0);
        assert_eq!(empty.min_volume, 0);
        assert!(!empty.is_buy_order);
        assert!(empty.issued.is_empty());
        assert_eq!(empty.duration, 0);
        assert!(empty.range.is_empty());
    }

    #[test]
    fn character_order_full_row_parses_defaults_and_escrow_variants() {
        let order: CharacterOrder = serde_json::from_str(
            r#"{"order_id":654321,"type_id":587,"region_id":10000002,
                "location_id":60003760,"price":350000.0,"volume_remain":1,
                "volume_total":2,"min_volume":1,"is_buy_order":false,
                "issued":"2026-11-02T09:30:00Z","duration":30,"range":"station",
                "is_corporation":true,"escrow":700000.0,
                "unknown_future_field":"x"}"#,
        )
        .expect("parses");
        assert_eq!(order.order_id, 654321);
        assert_eq!(order.type_id, 587);
        assert_eq!(order.region_id, 10000002);
        assert_eq!(order.location_id, 60003760);
        assert_eq!(order.price, 350000.0);
        assert_eq!(order.volume_remain, 1);
        assert_eq!(order.volume_total, 2);
        assert_eq!(order.min_volume, 1);
        assert!(!order.is_buy_order);
        assert_eq!(order.issued, "2026-11-02T09:30:00Z");
        assert_eq!(order.duration, 30);
        assert_eq!(order.range, "station");
        assert!(order.is_corporation);
        assert_eq!(order.escrow, Some(700000.0));

        let empty: CharacterOrder = serde_json::from_str("{}").expect("parses");
        assert_eq!(empty.order_id, 0);
        assert_eq!(empty.type_id, 0);
        assert_eq!(empty.region_id, 0);
        assert_eq!(empty.location_id, 0);
        assert_eq!(empty.price, 0.0);
        assert_eq!(empty.volume_remain, 0);
        assert_eq!(empty.volume_total, 0);
        assert_eq!(empty.min_volume, 0);
        assert!(!empty.is_buy_order);
        assert!(empty.issued.is_empty());
        assert_eq!(empty.duration, 0);
        assert!(empty.range.is_empty());
        assert!(!empty.is_corporation);
        assert_eq!(empty.escrow, None);

        let null_escrow: CharacterOrder =
            serde_json::from_str(r#"{"escrow":null}"#).expect("parses");
        assert_eq!(null_escrow.escrow, None);
    }

    #[test]
    fn market_history_entry_full_row_parses_and_defaults() {
        let entry: MarketHistoryEntry = serde_json::from_str(
            r#"{"date":"2026-11-14","average":5.25,"highest":6.0,"lowest":4.9,
                "order_count":1234,"volume":987654,"unknown_future_field":1}"#,
        )
        .expect("parses");
        assert_eq!(entry.date, "2026-11-14");
        assert_eq!(entry.average, 5.25);
        assert_eq!(entry.highest, 6.0);
        assert_eq!(entry.lowest, 4.9);
        assert_eq!(entry.order_count, 1234);
        assert_eq!(entry.volume, 987654);

        let empty: MarketHistoryEntry = serde_json::from_str("{}").expect("parses");
        assert!(empty.date.is_empty());
        assert_eq!(empty.average, 0.0);
        assert_eq!(empty.highest, 0.0);
        assert_eq!(empty.lowest, 0.0);
        assert_eq!(empty.order_count, 0);
        assert_eq!(empty.volume, 0);
    }

    #[test]
    fn character_blueprint_full_row_parses_and_defaults() {
        let bp: CharacterBlueprint = serde_json::from_str(
            r#"{"item_id":710001001,"type_id":681,"location_id":60003760,
                "location_flag":"Hangar","quantity":-2,"time_efficiency":10,
                "material_efficiency":8,"runs":5,"runs_remaining":3,
                "unknown_future_field":true}"#,
        )
        .expect("parses");
        assert_eq!(bp.item_id, 710001001);
        assert_eq!(bp.type_id, 681);
        assert_eq!(bp.location_id, 60003760);
        assert_eq!(bp.location_flag, "Hangar");
        assert_eq!(bp.quantity, -2);
        assert_eq!(bp.time_efficiency, 10);
        assert_eq!(bp.material_efficiency, 8);
        assert_eq!(bp.runs, 5);

        let original: CharacterBlueprint =
            serde_json::from_str(r#"{"quantity":-1,"runs":-1}"#).expect("parses");
        assert_eq!(original.quantity, -1);
        assert_eq!(original.runs, -1);

        let empty: CharacterBlueprint = serde_json::from_str("{}").expect("parses");
        assert_eq!(empty.item_id, 0);
        assert_eq!(empty.type_id, 0);
        assert_eq!(empty.location_id, 0);
        assert!(empty.location_flag.is_empty());
        assert_eq!(empty.quantity, 0);
        assert_eq!(empty.time_efficiency, 0);
        assert_eq!(empty.material_efficiency, 0);
        assert_eq!(empty.runs, 0);
    }

    #[test]
    fn industry_job_full_row_parses_defaults_and_option_variants() {
        let job: IndustryJob = serde_json::from_str(
            r#"{"job_id":710000101,"installer_id":90000001,"facility_id":60003760,
                "location_id":60003760,"activity_id":1,"blueprint_id":710001001,
                "blueprint_type_id":681,"output_location_id":60003760,"runs":3,
                "cost":12345.5,"licensed_production_runs":10,"probability":0.4,
                "product_type_id":587,"status":"active","duration":3600,
                "start_date":"2026-11-14T10:00:00Z","end_date":"2026-11-15T11:00:00Z",
                "pause_date":"2026-11-14T12:00:00Z",
                "completed_date":"2026-11-15T11:05:00Z",
                "completed_character_id":90000001,"successful_runs":2,
                "unknown_future_field":"x"}"#,
        )
        .expect("parses");
        assert_eq!(job.job_id, 710000101);
        assert_eq!(job.installer_id, 90000001);
        assert_eq!(job.facility_id, 60003760);
        assert_eq!(job.location_id, 60003760);
        assert_eq!(job.activity_id, 1);
        assert_eq!(job.blueprint_id, 710001001);
        assert_eq!(job.blueprint_type_id, 681);
        assert_eq!(job.output_location_id, 60003760);
        assert_eq!(job.runs, 3);
        assert_eq!(job.cost, Some(12345.5));
        assert_eq!(job.licensed_production_runs, Some(10));
        assert_eq!(job.probability, Some(0.4));
        assert_eq!(job.product_type_id, Some(587));
        assert_eq!(job.status, "active");
        assert_eq!(job.duration, 3600);
        assert_eq!(job.start_date, "2026-11-14T10:00:00Z");
        assert_eq!(job.end_date, "2026-11-15T11:00:00Z");
        assert_eq!(job.pause_date.as_deref(), Some("2026-11-14T12:00:00Z"));
        assert_eq!(job.completed_date.as_deref(), Some("2026-11-15T11:05:00Z"));
        assert_eq!(job.completed_character_id, Some(90000001));
        assert_eq!(job.successful_runs, Some(2));

        let empty: IndustryJob = serde_json::from_str("{}").expect("parses");
        assert_eq!(empty.job_id, 0);
        assert_eq!(empty.activity_id, 0);
        assert!(empty.status.is_empty());
        assert_eq!(empty.cost, None);
        assert_eq!(empty.licensed_production_runs, None);
        assert_eq!(empty.probability, None);
        assert_eq!(empty.product_type_id, None);
        assert_eq!(empty.pause_date, None);
        assert_eq!(empty.completed_date, None);
        assert_eq!(empty.completed_character_id, None);
        assert_eq!(empty.successful_runs, None);

        let nulls: IndustryJob = serde_json::from_str(
            r#"{"cost":null,"licensed_production_runs":null,"probability":null,
                "product_type_id":null,"pause_date":null,"completed_date":null,
                "completed_character_id":null,"successful_runs":null}"#,
        )
        .expect("parses");
        assert_eq!(nulls.cost, None);
        assert_eq!(nulls.licensed_production_runs, None);
        assert_eq!(nulls.probability, None);
        assert_eq!(nulls.product_type_id, None);
        assert_eq!(nulls.pause_date, None);
        assert_eq!(nulls.completed_date, None);
        assert_eq!(nulls.completed_character_id, None);
        assert_eq!(nulls.successful_runs, None);
    }

    #[test]
    fn planet_colony_full_row_parses() {
        let colonies: Vec<PlanetColony> = serde_json::from_str(
            r#"[{"planet_id":700000001,"planet_type":"temperate",
                "solar_system_id":30000142,"last_update":"2026-11-14T10:00:00Z",
                "upgrade_level":2,"num_pins":9,"unknown_future_field":true},
               {"planet_id":700000002,"planet_type":"oceanic",
                "solar_system_id":30002187,"last_update":"2026-11-13T09:00:00Z",
                "upgrade_level":1,"num_pins":4}]"#,
        )
        .expect("parses");
        assert_eq!(colonies.len(), 2);
        assert_eq!(colonies[0].planet_id, 700000001);
        assert_eq!(colonies[0].planet_type, "temperate");
        assert_eq!(colonies[0].solar_system_id, 30000142);
        assert_eq!(colonies[0].last_update, "2026-11-14T10:00:00Z");
        assert_eq!(colonies[0].upgrade_level, 2);
        assert_eq!(colonies[0].num_pins, 9);
        assert_eq!(colonies[1].planet_id, 700000002);
        assert_eq!(colonies[1].planet_type, "oceanic");
        assert_eq!(colonies[1].solar_system_id, 30002187);
    }

    #[test]
    fn planet_colony_detail_parses_pins_extractor_contents_and_raw_links_routes() {
        let detail: PlanetColonyDetail = serde_json::from_str(
            r#"{"pins":[{"pin_id":700000011,"type_id":20001,"latitude":0.5,
                "longitude":-0.25,"install_time":"2026-11-01T08:00:00Z",
                "expiry_time":"2026-11-21T08:00:00Z",
                "last_cycle_start":"2026-11-14T10:00:00Z","schematic_id":15462,
                "extractor_details":{"product_type_id":34,"qty_per_cycle":120,
                "cycle_time":7200},
                "contents":[{"type_id":35,"amount":500},{"type_id":36,"amount":250}],
                "unknown_future_field":"x"}],
               "links":[{"source_pin_id":700000011,"destination_pin_id":700000012}],
               "routes":[{"source_pin_id":700000011,"destination_pin_id":700000012,
               "route_type":"basic"}]}"#,
        )
        .expect("parses");
        assert_eq!(detail.pins.len(), 1);
        let pin = &detail.pins[0];
        assert_eq!(pin.pin_id, 700000011);
        assert_eq!(pin.type_id, 20001);
        assert_eq!(pin.latitude, 0.5);
        assert_eq!(pin.longitude, -0.25);
        assert_eq!(pin.install_time, "2026-11-01T08:00:00Z");
        assert_eq!(pin.expiry_time.as_deref(), Some("2026-11-21T08:00:00Z"));
        assert_eq!(
            pin.last_cycle_start.as_deref(),
            Some("2026-11-14T10:00:00Z")
        );
        assert_eq!(pin.schematic_id, Some(15462));
        let extractor = pin.extractor_details.as_ref().expect("extractor");
        assert_eq!(extractor.product_type_id, Some(34));
        assert_eq!(extractor.qty_per_cycle, Some(120));
        assert_eq!(extractor.cycle_time, Some(7200));
        assert_eq!(pin.contents.len(), 2);
        assert_eq!(pin.contents[0].type_id, 35);
        assert_eq!(pin.contents[0].amount, 500);
        assert_eq!(pin.contents[1].type_id, 36);
        assert_eq!(pin.contents[1].amount, 250);
        assert_eq!(detail.links.len(), 1);
        assert_eq!(detail.routes.len(), 1);
        assert!(detail.links[0].is_object());
        assert!(detail.routes[0].is_object());
    }

    #[test]
    fn planet_pin_without_extractor_or_contents_parses_to_none_and_empty() {
        let pin: PlanetPin = serde_json::from_str(
            r#"{"pin_id":700000021,"type_id":20003,"latitude":0.1,
                "longitude":0.2,"install_time":"2026-11-02T08:00:00Z"}"#,
        )
        .expect("parses");
        assert_eq!(pin.pin_id, 700000021);
        assert_eq!(pin.type_id, 20003);
        assert_eq!(pin.expiry_time, None);
        assert_eq!(pin.last_cycle_start, None);
        assert_eq!(pin.schematic_id, None);
        assert!(pin.extractor_details.is_none());
        assert!(pin.contents.is_empty());

        let nulls: PlanetPin = serde_json::from_str(
            r#"{"pin_id":700000022,"type_id":20001,"latitude":0.0,"longitude":0.0,
                "install_time":"2026-11-02T08:00:00Z","expiry_time":null,
                "last_cycle_start":null,"schematic_id":null,
                "extractor_details":{"product_type_id":null,"qty_per_cycle":null,
                "cycle_time":null},"contents":[]}"#,
        )
        .expect("parses");
        assert_eq!(nulls.expiry_time, None);
        assert_eq!(nulls.last_cycle_start, None);
        assert_eq!(nulls.schematic_id, None);
        let extractor = nulls.extractor_details.as_ref().expect("extractor");
        assert_eq!(extractor.product_type_id, None);
        assert_eq!(extractor.qty_per_cycle, None);
        assert_eq!(extractor.cycle_time, None);
        assert!(nulls.contents.is_empty());
    }

    #[test]
    fn planet_models_default_everywhere() {
        let colony: PlanetColony = serde_json::from_str("{}").expect("parses");
        assert_eq!(colony.planet_id, 0);
        assert!(colony.planet_type.is_empty());
        assert_eq!(colony.solar_system_id, 0);
        assert!(colony.last_update.is_empty());
        assert_eq!(colony.upgrade_level, 0);
        assert_eq!(colony.num_pins, 0);

        let detail: PlanetColonyDetail = serde_json::from_str("{}").expect("parses");
        assert!(detail.pins.is_empty());
        assert!(detail.links.is_empty());
        assert!(detail.routes.is_empty());

        let pin: PlanetPin = serde_json::from_str("{}").expect("parses");
        assert_eq!(pin.pin_id, 0);
        assert_eq!(pin.type_id, 0);
        assert_eq!(pin.latitude, 0.0);
        assert_eq!(pin.longitude, 0.0);
        assert!(pin.install_time.is_empty());
        assert_eq!(pin.expiry_time, None);
        assert_eq!(pin.last_cycle_start, None);
        assert_eq!(pin.schematic_id, None);
        assert!(pin.extractor_details.is_none());
        assert!(pin.contents.is_empty());

        let extractor: ExtractorDetails = serde_json::from_str("{}").expect("parses");
        assert_eq!(extractor.product_type_id, None);
        assert_eq!(extractor.qty_per_cycle, None);
        assert_eq!(extractor.cycle_time, None);

        let content: PinContent = serde_json::from_str("{}").expect("parses");
        assert_eq!(content.type_id, 0);
        assert_eq!(content.amount, 0);
    }

    #[test]
    fn clones_home_location_parses() {
        let clones: CharacterClones = serde_json::from_str(
            r#"{"jump_clones":[],"home_location":{"location_id":60003760,"location_type":"station"}}"#,
        )
        .expect("parses");
        assert_eq!(clones.home_location.expect("home").location_id, 60003760);
    }
}
