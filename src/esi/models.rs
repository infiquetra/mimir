//! Serde models for the Phase-1 ESI endpoint set.

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
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterClones {
    #[serde(default)]
    pub jump_clones: Vec<JumpClone>,
    #[serde(default)]
    pub last_clone_jump_date: Option<String>,
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

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StationInfo {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub system_id: i64,
    #[serde(default)]
    pub type_id: i64,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StructureInfo {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub solar_system_id: i64,
    #[serde(default)]
    pub type_id: i64,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CorporationInfo {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub ticker: String,
    #[serde(default)]
    pub member_count: i64,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AllianceInfo {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub ticker: String,
}
