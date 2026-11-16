//! Application error types (thiserror). No token values ever enter these.

use thiserror::Error;

pub type AppResult<T> = Result<T, AppError>;

#[derive(Debug, Error)]
pub enum EsiError {
    #[error("[ESI] http error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("[ESI] request failed with status {0}: {1}")]
    StatusMessage(u16, String),
    #[error("[ESI] request failed with status {0}")]
    Status(u16),
    #[error("[ESI] unauthorized (401); token missing or expired")]
    Unauthorized,
    #[error("[ESI] re-authorization required (403)")]
    Reauthorize,
    #[error("[ESI] not found (404): {0}")]
    NotFound(String),
    #[error("[ESI] rate limited (retry after {reset_secs}s)")]
    RateLimited { reset_secs: u32 },
    #[error("[ESI] error limit exhausted (retry after {reset_secs}s)")]
    ErrorLimitExhausted { reset_secs: u32 },
    #[error("[ESI] no stored tokens for character {0}")]
    NoTokens(i64),
    #[error("[ESI] response decode failed: {0}")]
    Decode(String),
    #[error("[ESI] not wired yet: {0}")]
    NotWired(String),
    #[error("[ESI] {0}")]
    Message(String),
}

impl EsiError {
    /// Map an HTTP status (+ optional ESI `{"error": ...}` body text) to a
    /// typed error. Mirrors Flutter: 401/403 are auth-class, 420/429 are
    /// rate-limit-class (`EsiException.isRateLimited`).
    pub fn from_status(status: u16, body: &str, reset_secs: u32) -> Self {
        match status {
            401 => EsiError::Unauthorized,
            403 => EsiError::Reauthorize,
            404 => EsiError::NotFound(
                extract_esi_error(body).unwrap_or_else(|| body.chars().take(200).collect()),
            ),
            420 | 429 => EsiError::RateLimited { reset_secs },
            _ => {
                let message = extract_esi_error(body);
                match message {
                    Some(m) => EsiError::StatusMessage(status, m),
                    None => EsiError::Status(status),
                }
            }
        }
    }

    pub fn is_scope_error(&self) -> bool {
        matches!(self, EsiError::Reauthorize)
    }

    pub fn is_rate_limited(&self) -> bool {
        matches!(
            self,
            EsiError::RateLimited { .. } | EsiError::ErrorLimitExhausted { .. }
        )
    }

    pub fn status_code(&self) -> Option<u16> {
        match self {
            EsiError::Status(c) | EsiError::StatusMessage(c, _) => Some(*c),
            EsiError::Unauthorized => Some(401),
            EsiError::Reauthorize => Some(403),
            EsiError::NotFound(_) => Some(404),
            EsiError::RateLimited { .. } => Some(420),
            EsiError::Http(e) => e.status().map(|s| s.as_u16()),
            _ => None,
        }
    }
}

/// Pull the `error` string out of an ESI error body, if it is JSON.
pub fn extract_esi_error(body: &str) -> Option<String> {
    let value: serde_json::Value = serde_json::from_str(body).ok()?;
    value
        .get("error")?
        .as_str()
        .map(|s| s.chars().take(300).collect())
}

#[derive(Debug, Error)]
pub enum AuthError {
    #[error("[AUTH] http error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("[AUTH] state mismatch")]
    StateMismatch,
    #[error("[AUTH] step-up sign-in returned a different character than expected")]
    CharacterMismatch,
    #[error("[AUTH] authorization was denied or failed: {0}")]
    Denied(String),
    #[error("[AUTH] callback did not contain an authorization code")]
    MissingCode,
    #[error("[AUTH] token exchange failed with status {0}")]
    Exchange(u16),
    #[error("[AUTH] token exchange failed with status {status}: {body}")]
    ExchangeBody { status: u16, body: String },
    #[error("[AUTH] token refresh failed with status {0}")]
    Refresh(u16),
    #[error("[AUTH] refresh token rejected; re-authorization required")]
    RefreshRejected,
    #[error("[AUTH] token response was missing a field: {0}")]
    BadTokenResponse(String),
    #[error("[AUTH] malformed token")]
    MalformedToken,
    #[error("[AUTH] EVE signing keys unavailable; token not verified")]
    JwksUnavailable,
    #[error("[AUTH] token signed with an unknown key")]
    UnknownSigningKey,
    #[error("[AUTH] token signature invalid")]
    InvalidSignature,
    #[error("[AUTH] token claims invalid: {0}")]
    InvalidClaims(&'static str),
    #[error("[AUTH] callback timed out")]
    CallbackTimeout,
    #[error("[AUTH] callback listener failed: {0}")]
    Callback(String),
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn status_mapping_covers_auth_and_rate_limit() {
        assert!(matches!(
            EsiError::from_status(401, "", 0),
            EsiError::Unauthorized
        ));
        assert!(matches!(
            EsiError::from_status(403, "", 0),
            EsiError::Reauthorize
        ));
        assert!(EsiError::from_status(420, "", 30).is_rate_limited());
        assert!(EsiError::from_status(429, "", 30).is_rate_limited());
        assert_eq!(
            EsiError::from_status(500, r#"{"error":"boom"}"#, 0).status_code(),
            Some(500)
        );
    }

    #[test]
    fn extract_error_from_json_and_plain() {
        assert_eq!(
            extract_esi_error(r#"{"error":"Token expired"}"#).as_deref(),
            Some("Token expired")
        );
        assert_eq!(extract_esi_error("not json"), None);
    }
}
