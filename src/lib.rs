//! Alidade — EVE Online companion app (Rust/egui rewrite).
//!
//! Cross-builder contracts (scaffold-owned; change only via scaffold owner):
//! F1 exposes `EsiClient`, `TokenStore`, and the ESI model structs; F2
//! exposes repository functions plus `NameResolver::name(id)`; F3 consumes
//! both through `AppState`; F4 seeds demo data through F2 repositories only.
//! Every public function logs at debug with a bracketed feature tag
//! (`[AUTH]`, `[ESI]`, `[WALLET]`, `[SKILLS]`, `[CHAR]`, `[DB]`, `[DEMO]`,
//! `[UI]`, `[STARTUP]`). Access and refresh tokens never appear in logs or
//! `Debug` output. User interface code shows resolved EVE names, never raw
//! numeric IDs (unresolved skills show "Unknown Skill").

pub mod app;
pub mod auth;
pub mod config;
pub mod daemon;
pub mod demo;
pub mod error;
pub mod esi;
pub mod fitting;
pub mod invention_calculator;
pub mod names;
pub mod portraits;
pub mod production_chain;
pub mod reaction_calculator;
pub mod sde;
pub mod skills;
pub mod storage;
pub mod trade_calculator;
pub mod ui;

pub use app::shell::MimirApp;
pub use app::state::{AppState, LoadState, View};
pub use auth::token_store::TokenStore;
pub use config::EveConfig;
pub use error::{AppError, AppResult, AuthError, EsiError};
pub use esi::client::EsiClient;
pub use names::resolver::NameResolver;
