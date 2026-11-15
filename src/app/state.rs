//! Application state: characters, active character, per-view load state.

use crate::esi::models::*;
use crate::storage::repositories::CharacterRow;

/// The five Phase-1 views (keys 1-5 in the shell).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum View {
    #[default]
    Dashboard,
    Characters,
    Skills,
    Wallet,
    Settings,
}

impl View {
    pub const ALL: [View; 5] = [
        View::Dashboard,
        View::Characters,
        View::Skills,
        View::Wallet,
        View::Settings,
    ];

    pub fn label(&self) -> &'static str {
        match self {
            View::Dashboard => "Dashboard",
            View::Characters => "Characters",
            View::Skills => "Skills",
            View::Wallet => "Wallet",
            View::Settings => "Settings",
        }
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

/// Wallet view data bundle.
#[derive(Debug, Clone, Default)]
pub struct WalletData {
    pub balance: f64,
    pub journal: Vec<WalletJournalItem>,
    pub transactions: Vec<WalletTransactionItem>,
    pub loyalty: Vec<LoyaltyPointItem>,
}

/// Skills view data bundle.
#[derive(Debug, Clone, Default)]
pub struct SkillsData {
    pub skills: CharacterSkills,
    pub queue: Vec<SkillQueueItem>,
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
    pub log_lines: Vec<String>,
    pub status_message: String,
}

impl AppState {
    pub fn new(demo: bool) -> Self {
        tracing::info!("[STARTUP] AppState::new demo={}", demo);
        Self {
            demo,
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

    pub fn set_active_character(&mut self, character_id: i64) {
        tracing::info!("[CHAR] set active character_id={}", character_id);
        self.active_character_id = Some(character_id);
        for c in &mut self.characters {
            c.is_active = c.character_id == character_id;
        }
    }

    pub fn switch_view(&mut self, view: View) {
        tracing::debug!("[UI] switch view to {}", view.label());
        self.view = view;
    }
}
