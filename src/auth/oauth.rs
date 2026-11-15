//! EVE SSO OAuth2 + PKCE (S256). HTTP exchange is stubbed for F1 wiring;
//! PKCE, authorize-URL, and JWT-claims helpers are real. Token values are
//! never logged.

use base64::engine::general_purpose::{URL_SAFE, URL_SAFE_NO_PAD};
use base64::Engine;
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::config::EveConfig;
use crate::error::AuthError;

/// PKCE verifier/challenge pair. The verifier is a secret until exchange.
pub struct PkcePair {
    pub verifier: String,
    pub challenge: String,
}

impl std::fmt::Debug for PkcePair {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("PkcePair(<redacted>)")
    }
}

/// JWT claims parsed without signature verification (same as Flutter).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct JwtClaims {
    #[serde(default)]
    pub sub: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub exp: i64,
    #[serde(default)]
    pub iat: i64,
    #[serde(default)]
    pub scp: Vec<String>,
}

/// Token endpoint response. The inner token strings are secrets and are
/// only ever held inside the redacted newtypes in `token_store`.
#[derive(Clone, Default, Serialize, Deserialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub expires_in: i64,
    pub token_type: String,
}

impl std::fmt::Debug for TokenResponse {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TokenResponse")
            .field("access_token", &"<redacted>")
            .field("refresh_token", &"<redacted>")
            .field("expires_in", &self.expires_in)
            .field("token_type", &self.token_type)
            .finish()
    }
}

pub fn generate_pkce() -> PkcePair {
    tracing::debug!("[AUTH] generating PKCE pair");
    let mut bytes = [0u8; 32];
    rand::thread_rng().fill_bytes(&mut bytes);
    let verifier = URL_SAFE_NO_PAD.encode(bytes);
    let digest = Sha256::digest(verifier.as_bytes());
    let challenge = URL_SAFE_NO_PAD.encode(digest);
    PkcePair {
        verifier,
        challenge,
    }
}

pub fn generate_state() -> String {
    tracing::debug!("[AUTH] generating OAuth state");
    let mut bytes = [0u8; 16];
    rand::thread_rng().fill_bytes(&mut bytes);
    URL_SAFE_NO_PAD.encode(bytes)
}

pub fn build_authorize_url(challenge: &str, state: &str) -> Result<url::Url, AuthError> {
    tracing::debug!("[AUTH] building authorize URL");
    let mut url = url::Url::parse(EveConfig::OAUTH_AUTHORIZE_URL)
        .map_err(|e| AuthError::Message(e.to_string()))?;
    url.query_pairs_mut()
        .append_pair("response_type", "code")
        .append_pair("redirect_uri", EveConfig::REDIRECT_URI)
        .append_pair("client_id", EveConfig::CLIENT_ID)
        .append_pair("scope", &EveConfig::first_auth_scopes_string())
        .append_pair("code_challenge", challenge)
        .append_pair("code_challenge_method", "S256")
        .append_pair("state", state);
    Ok(url)
}

/// Decode the claims segment of a JWT (no signature check, as in Flutter).
pub fn parse_jwt_claims(token: &str) -> Result<JwtClaims, AuthError> {
    tracing::debug!("[AUTH] parsing JWT claims");
    let payload = token.split('.').nth(1).ok_or(AuthError::MalformedToken)?;
    let bytes = URL_SAFE
        .decode(payload)
        .map_err(|_| AuthError::MalformedToken)?;
    serde_json::from_slice(&bytes).map_err(|_| AuthError::MalformedToken)
}

/// True when the access token is expired or inside the refresh buffer.
pub fn needs_refresh(expires_at_unix: i64, now_unix: i64) -> bool {
    now_unix + EveConfig::TOKEN_REFRESH_BUFFER_SECS >= expires_at_unix
}

pub async fn exchange_code(_code: &str, _verifier: &str) -> Result<TokenResponse, AuthError> {
    tracing::debug!("[AUTH] exchange_code entry (stub)");
    Err(AuthError::NotWired(
        "code exchange lands with F1".to_string(),
    ))
}

pub async fn refresh_access_token(_refresh_token: &str) -> Result<TokenResponse, AuthError> {
    tracing::debug!("[AUTH] refresh_access_token entry (stub)");
    Err(AuthError::NotWired(
        "token refresh lands with F1".to_string(),
    ))
}

pub async fn revoke_token(_token: &str) -> Result<(), AuthError> {
    tracing::debug!("[AUTH] revoke_token entry (stub)");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pkce_challenge_is_sha256_of_verifier() {
        let pair = generate_pkce();
        let digest = Sha256::digest(pair.verifier.as_bytes());
        assert_eq!(pair.challenge, URL_SAFE_NO_PAD.encode(digest));
        assert!(!format!("{pair:?}").contains(&pair.verifier));
    }

    #[test]
    fn authorize_url_carries_pkce_and_state() {
        let url = build_authorize_url("chal", "st").expect("url builds");
        let text = url.as_str();
        assert!(text.contains("code_challenge=chal"));
        assert!(text.contains("code_challenge_method=S256"));
        assert!(text.contains("state=st"));
    }

    #[test]
    fn malformed_jwt_is_rejected() {
        assert!(parse_jwt_claims("not-a-jwt").is_err());
    }

    #[test]
    fn refresh_buffer_math() {
        assert!(needs_refresh(1_000, 941));
        assert!(!needs_refresh(1_000, 900));
    }
}
