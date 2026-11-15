//! Application state: characters, active character, per-view load state.
//!
//! F3 owns this state. Live data arrives from F1/F2 through the integrator:
//! views only set the request flags (`refresh_requested`, `login_requested`,
//! `logout_requested_id`, `delete_requested_id`, `retry_requested`) and the
//! integrator drains them each frame. Nothing here performs network or disk
//! work, and no token material is ever stored in this struct.

use std::collections::HashMap;

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
    pub log_lines: Vec<String>,
    pub status_message: String,

    // Multi-character overview, keyed by character id (integrator-filled).
    pub summaries: HashMap<i64, CharacterSummary>,

    // View-local UI state (survives across frames, unlike egui closures).
    pub skill_search: String,
    pub wallet_search: String,
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

    // Request flags for the integrator to drain (set by views, never faked
    // as completed work). See the module comment.
    pub refresh_requested: bool,
    pub retry_requested: bool,
    pub login_requested: bool,
    pub logout_requested_id: Option<i64>,
    pub delete_requested_id: Option<i64>,
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
        tracing::info!("[CHAR] set active character_id={}", character_id);
        self.active_character_id = Some(character_id);
        for c in &mut self.characters {
            c.is_active = c.character_id == character_id;
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
        if self.active_character_id == Some(character_id) {
            self.active_character_id = None;
            if let Some(first) = self.characters.first().map(|c| c.character_id) {
                self.set_active_character(first);
            }
        }
        if self.characters.is_empty() {
            self.skills = LoadState::Empty;
            self.wallet = LoadState::Empty;
            self.character_detail = LoadState::Empty;
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
}

#[cfg(test)]
mod tests {
    use super::*;

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
        assert_eq!(View::Settings.next(), View::Dashboard);
        assert_eq!(View::Dashboard.previous(), View::Settings);
        assert_eq!(View::from_index(3), Some(View::Wallet));
        assert_eq!(View::from_index(9), None);
        assert_eq!(View::Wallet.index(), 3);
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
        state.remove_character(1);
        state.remove_character(2);
        assert_eq!(state.active_character_id, None);
        assert!(matches!(state.wallet, LoadState::Empty));
    }

    #[test]
    fn wallet_period_windows_and_auth_labels() {
        assert_eq!(WalletPeriod::All.days(), None);
        assert_eq!(WalletPeriod::Days30.days(), Some(30));
        assert!(AuthState::AwaitingCallback.is_busy());
        assert!(!AuthState::Idle.is_busy());
        assert!(!AuthState::Error.label().is_empty());
    }
}
