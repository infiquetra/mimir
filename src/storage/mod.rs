//! Local storage: rusqlite database plus typed repositories. No token
//! values are stored in this layer (see `repositories::TokenMetaRow`).

pub mod db;
pub mod repositories;
