//! Application error types (thiserror). No token values ever enter these.

use thiserror::Error;

pub type AppResult<T> = Result<T, AppError>;

#[derive(Debug, Error)]
pub enum EsiError {
    #[error("[ESI] http error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("[ESI] request failed with status {0}")]
    Status(u16),
    #[error("[ESI] re-authorization required (403)")]
    Reauthorize,
    #[error("[ESI] not wired yet: {0}")]
    NotWired(String),
    #[error("[ESI] {0}")]
    Message(String),
}

#[derive(Debug, Error)]
pub enum AuthError {
    #[error("[AUTH] state mismatch")]
    StateMismatch,
    #[error("[AUTH] token exchange failed with status {0}")]
    Exchange(u16),
    #[error("[AUTH] malformed token")]
    MalformedToken,
    #[error("[AUTH] callback timed out")]
    CallbackTimeout,
    #[error("[AUTH] not wired yet: {0}")]
    NotWired(String),
    #[error("[AUTH] {0}")]
    Message(String),
}

#[derive(Debug, Error)]
pub enum AppError {
    #[error(transparent)]
    Esi(#[from] EsiError),
    #[error(transparent)]
    Auth(#[from] AuthError),
    #[error("[DB] database error: {0}")]
    Db(#[from] rusqlite::Error),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("url error: {0}")]
    Url(#[from] url::ParseError),
    #[error("{0}")]
    Message(String),
}
