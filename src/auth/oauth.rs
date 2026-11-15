//! EVE SSO OAuth2 + PKCE (S256), ported from
//! `lib/core/auth/oauth_service.dart`. Token exchange/refresh/revoke go
//! through an injected `reqwest::Client` and token URL so tests need no
//! network. Token values are never logged.

use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use rand::RngCore;
use serde::{Deserialize, Deserializer, Serialize};
use sha2::{Digest, Sha256};

use crate::config::{now_unix, EveConfig};
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

/// One authorization attempt: open `authorize_url` in the browser, then
/// exchange the returned code with `pkce.verifier` after checking `state`.
/// `Debug` redacts the URL and state (the URL embeds the CSRF state).
pub struct AuthorizationRequest {
    pub authorize_url: url::Url,
    pub pkce: PkcePair,
    pub state: String,
}

impl std::fmt::Debug for AuthorizationRequest {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("AuthorizationRequest(<redacted>)")
    }
}

fn deserialize_scp<'de, D>(deserializer: D) -> Result<Vec<String>, D::Error>
where
    D: Deserializer<'de>,
{
    // EVE sends `scp` as a space-separated string or a JSON array.
    let value = Option::<serde_json::Value>::deserialize(deserializer)?;
    Ok(match value {
        Some(serde_json::Value::String(s)) => ssplit_scopes(&s),
        Some(serde_json::Value::Array(items)) => items
            .iter()
            .filter_map(|v| v.as_str().map(|s| s.to_string()))
            .collect(),
        _ => Vec::new(),
    })
}

fn ssplit_scopes(s: &str) -> Vec<String> {
    s.split_whitespace().map(|p| p.to_string()).collect()
}

/// JWT claims parsed without signature verification (same as Flutter; JWKS
/// verification is a named hardening follow-up in the design).
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
    #[serde(default, deserialize_with = "deserialize_scp")]
    pub scp: Vec<String>,
    #[serde(default)]
    pub iss: Option<String>,
    #[serde(default)]
    pub owner: Option<String>,
}

impl JwtClaims {
    /// EVE `sub` has the form `CHARACTER:EVE:<id>`.
    pub fn character_id(&self) -> Option<i64> {
        let mut parts = self.sub.split(':');
        if parts.next()? != "CHARACTER" || parts.next()? != "EVE" {
            return None;
        }
        parts.next()?.parse::<i64>().ok()
    }

    pub fn is_expired_at(&self, now_unix_secs: i64) -> bool {
        self.exp > 0 && now_unix_secs >= self.exp
    }
}

/// Token endpoint response. The token strings are secrets; `Debug` redacts
/// them and callers should move them into `token_store` newtypes promptly.
#[derive(Clone, Default, Serialize, Deserialize)]
pub struct TokenResponse {
    #[serde(default)]
    pub access_token: String,
    #[serde(default)]
    pub refresh_token: String,
    #[serde(default)]
    pub expires_in: i64,
    #[serde(default)]
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

impl TokenResponse {
    /// Unix expiry for the access token (uses `expires_in`, falling back to
    /// the documented 1199 s lifetime when the field is absent/zero).
    pub fn expires_at_unix(&self, now_unix_secs: i64) -> i64 {
        let lifetime = if self.expires_in > 0 {
            self.expires_in
        } else {
            EveConfig::ACCESS_TOKEN_LIFETIME_SECS
        };
        now_unix_secs + lifetime
    }

    fn validate(&self, require_refresh: bool) -> Result<(), AuthError> {
        if self.access_token.is_empty() {
            return Err(AuthError::BadTokenResponse("access_token".to_string()));
        }
        if require_refresh && self.refresh_token.is_empty() {
            return Err(AuthError::BadTokenResponse("refresh_token".to_string()));
        }
        Ok(())
    }
}

pub fn generate_pkce() -> PkcePair {
    tracing::debug!("[AUTH] generating PKCE pair");
    let mut bytes = [0u8; 32];
    rand::thread_rng().fill_bytes(&mut bytes);
    let verifier = URL_SAFE_NO_PAD.encode(bytes);
    let challenge = pkce_challenge(&verifier);
    PkcePair {
        verifier,
        challenge,
    }
}

/// `BASE64URL(SHA256(verifier))` (RFC 7636 S256).
pub fn pkce_challenge(verifier: &str) -> String {
    URL_SAFE_NO_PAD.encode(Sha256::digest(verifier.as_bytes()))
}

pub fn generate_state() -> String {
    tracing::debug!("[AUTH] generating OAuth state");
    let mut bytes = [0u8; 32];
    rand::thread_rng().fill_bytes(&mut bytes);
    URL_SAFE_NO_PAD.encode(bytes)
}

pub fn build_authorize_url(challenge: &str, state: &str) -> Result<url::Url, AuthError> {
    build_authorize_url_with_scopes(challenge, state, &EveConfig::first_auth_scopes_string())
}

pub fn build_authorize_url_with_scopes(
    challenge: &str,
    state: &str,
    scopes: &str,
) -> Result<url::Url, AuthError> {
    build_authorize_url_at(
        EveConfig::OAUTH_AUTHORIZE_URL,
        EveConfig::REDIRECT_URI,
        EveConfig::CLIENT_ID,
        challenge,
        state,
        scopes,
    )
}

/// Fully parameterized authorize-URL builder (the mockable seam).
#[allow(clippy::too_many_arguments)]
pub fn build_authorize_url_at(
    authorize_endpoint: &str,
    redirect_uri: &str,
    client_id: &str,
    challenge: &str,
    state: &str,
    scopes: &str,
) -> Result<url::Url, AuthError> {
    tracing::debug!(
        "[AUTH] building authorize URL endpoint={}",
        authorize_endpoint
    );
    let mut url =
        url::Url::parse(authorize_endpoint).map_err(|e| AuthError::Message(e.to_string()))?;
    url.query_pairs_mut()
        .append_pair("response_type", "code")
        .append_pair("redirect_uri", redirect_uri)
        .append_pair("client_id", client_id)
        .append_pair("scope", scopes)
        .append_pair("code_challenge", challenge)
        .append_pair("code_challenge_method", "S256")
        .append_pair("state", state);
    Ok(url)
}

/// Create a first-auth authorization request (least-privilege scopes).
pub fn create_authorization_request() -> Result<AuthorizationRequest, AuthError> {
    create_authorization_request_with_scopes(&EveConfig::first_auth_scopes_string())
}

pub fn create_authorization_request_with_scopes(
    scopes: &str,
) -> Result<AuthorizationRequest, AuthError> {
    tracing::info!("[AUTH] creating authorization request");
    let pkce = generate_pkce();
    let state = generate_state();
    let authorize_url = build_authorize_url_with_scopes(&pkce.challenge, &state, scopes)?;
    Ok(AuthorizationRequest {
        authorize_url,
        pkce,
        state,
    })
}

/// Validate a callback URL: error param, state (CSRF), then code presence.
/// Mirrors Flutter `parseCallbackUrl`. Returns the code on success.
pub fn parse_callback_url(callback: &url::Url, expected_state: &str) -> Result<String, AuthError> {
    tracing::debug!("[AUTH] parsing callback URL host={:?}", callback.host_str());
    let pairs: Vec<(String, String)> = callback
        .query_pairs()
        .map(|(k, v)| (k.into_owned(), v.into_owned()))
        .collect();
    let get = |key: &str| pairs.iter().find(|(k, _)| k == key).map(|(_, v)| v.clone());
    if let Some(error) = get("error") {
        let description = get("error_description").unwrap_or_else(|| "Unknown error".to_string());
        tracing::warn!("[AUTH] SSO returned error={}", error);
        return Err(AuthError::Denied(format!("{error} - {description}")));
    }
    match get("state") {
        Some(returned) if returned == expected_state => {}
        _ => {
            tracing::warn!("[AUTH] callback state mismatch");
            return Err(AuthError::StateMismatch);
        }
    }
    match get("code") {
        Some(code) if !code.is_empty() => Ok(code),
        _ => Err(AuthError::MissingCode),
    }
}

/// Decode the claims segment of a JWT (no signature check, as in Flutter).
pub fn parse_jwt_claims(token: &str) -> Result<JwtClaims, AuthError> {
    tracing::debug!("[AUTH] parsing JWT claims");
    let mut segments = token.split('.');
    let _header = segments.next().ok_or(AuthError::MalformedToken)?;
    let payload = segments.next().ok_or(AuthError::MalformedToken)?;
    if segments.next().is_none() {
        return Err(AuthError::MalformedToken);
    }
    let bytes = URL_SAFE_NO_PAD
        .decode(payload.trim_end_matches('='))
        .map_err(|_| AuthError::MalformedToken)?;
    serde_json::from_slice(&bytes).map_err(|_| AuthError::MalformedToken)
}

/// True when the access token is expired or inside the refresh buffer.
pub fn needs_refresh(expires_at_unix: i64, now_unix_secs: i64) -> bool {
    now_unix_secs + EveConfig::TOKEN_REFRESH_BUFFER_SECS >= expires_at_unix
}

fn default_http() -> Result<reqwest::Client, AuthError> {
    Ok(reqwest::Client::builder()
        .timeout(std::time::Duration::from_millis(
            EveConfig::DEFAULT_TIMEOUT_MS,
        ))
        .user_agent(EveConfig::USER_AGENT)
        .build()?)
}

async fn post_token_form(
    http: &reqwest::Client,
    endpoint: &str,
    host_header: Option<&str>,
    form: &[(&str, &str)],
) -> Result<TokenResponse, AuthError> {
    let mut request = http.post(endpoint).form(form);
    if let Some(host) = host_header {
        request = request.header(reqwest::header::HOST, host);
    }
    let response = request.send().await?;
    let status = response.status();
    let body = response.text().await.unwrap_or_default();
    if !status.is_success() {
        tracing::warn!("[AUTH] token endpoint failed status={}", status.as_u16());
        // Never include form data (it carries codes/tokens) in the error.
        return Err(AuthError::ExchangeBody {
            status: status.as_u16(),
            body: body.chars().take(300).collect(),
        });
    }
    serde_json::from_str::<TokenResponse>(&body)
        .map_err(|e| AuthError::BadTokenResponse(e.to_string()))
}

/// Mockable code exchange: explicit HTTP client, endpoint, and client id.
pub async fn exchange_code_with(
    http: &reqwest::Client,
    token_endpoint: &str,
    client_id: &str,
    code: &str,
    verifier: &str,
) -> Result<TokenResponse, AuthError> {
    tracing::info!("[AUTH] exchanging authorization code for tokens");
    let host = (token_endpoint == EveConfig::OAUTH_TOKEN_URL).then_some(EveConfig::OAUTH_HOST);
    let tokens = post_token_form(
        http,
        token_endpoint,
        host,
        &[
            ("grant_type", "authorization_code"),
            ("code", code),
            ("client_id", client_id),
            ("code_verifier", verifier),
        ],
    )
    .await?;
    tokens.validate(true)?;
    tracing::info!("[AUTH] token exchange ok expires_in={}", tokens.expires_in);
    Ok(tokens)
}

pub async fn exchange_code(code: &str, verifier: &str) -> Result<TokenResponse, AuthError> {
    let http = default_http()?;
    exchange_code_with(
        &http,
        EveConfig::OAUTH_TOKEN_URL,
        EveConfig::CLIENT_ID,
        code,
        verifier,
    )
    .await
}

/// Mockable refresh. A 400/401 from EVE means the refresh token is dead and
/// the user must re-authorize (`AuthError::RefreshRejected`).
pub async fn refresh_with(
    http: &reqwest::Client,
    token_endpoint: &str,
    client_id: &str,
    refresh_token: &str,
) -> Result<TokenResponse, AuthError> {
    tracing::debug!("[AUTH] refreshing access token");
    let host = (token_endpoint == EveConfig::OAUTH_TOKEN_URL).then_some(EveConfig::OAUTH_HOST);
    match post_token_form(
        http,
        token_endpoint,
        host,
        &[
            ("grant_type", "refresh_token"),
            ("refresh_token", refresh_token),
            ("client_id", client_id),
        ],
    )
    .await
    {
        Ok(tokens) => {
            tokens.validate(false)?;
            tracing::info!("[AUTH] token refresh ok expires_in={}", tokens.expires_in);
            Ok(tokens)
        }
        Err(AuthError::ExchangeBody { status, .. }) if status == 400 || status == 401 => {
            tracing::warn!("[AUTH] refresh token rejected status={}", status);
            Err(AuthError::RefreshRejected)
        }
        Err(AuthError::ExchangeBody { status, .. }) => Err(AuthError::Refresh(status)),
        Err(other) => Err(other),
    }
}

pub async fn refresh_access_token(refresh_token: &str) -> Result<TokenResponse, AuthError> {
    let http = default_http()?;
    refresh_with(
        &http,
        EveConfig::OAUTH_TOKEN_URL,
        EveConfig::CLIENT_ID,
        refresh_token,
    )
    .await
}

/// Mockable revocation (best-effort logout, as in Flutter).
pub async fn revoke_with(
    http: &reqwest::Client,
    revoke_endpoint: &str,
    client_id: &str,
    refresh_token: &str,
) -> Result<(), AuthError> {
    tracing::debug!("[AUTH] revoking refresh token");
    let host = (revoke_endpoint == EveConfig::OAUTH_REVOKE_URL).then_some(EveConfig::OAUTH_HOST);
    let mut request = http.post(revoke_endpoint).form(&[
        ("token_type_hint", "refresh_token"),
        ("token", refresh_token),
        ("client_id", client_id),
    ]);
    if let Some(h) = host {
        request = request.header(reqwest::header::HOST, h);
    }
    let response = request.send().await?;
    if response.status().is_success() {
        tracing::info!("[AUTH] token revoke ok");
        Ok(())
    } else {
        tracing::warn!(
            "[AUTH] token revoke failed status={}",
            response.status().as_u16()
        );
        Err(AuthError::Exchange(response.status().as_u16()))
    }
}

pub async fn revoke_token(token: &str) -> Result<(), AuthError> {
    let http = default_http()?;
    revoke_with(
        &http,
        EveConfig::OAUTH_REVOKE_URL,
        EveConfig::CLIENT_ID,
        token,
    )
    .await
}

/// Convenience: expiry instant for a fresh token response, using JWT `exp`
/// when parseable and `expires_in` otherwise.
pub fn expiry_for(tokens: &TokenResponse) -> i64 {
    if let Ok(claims) = parse_jwt_claims(&tokens.access_token) {
        if claims.exp > 0 {
            return claims.exp;
        }
    }
    tokens.expires_at_unix(now_unix())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pkce_challenge_matches_rfc7636_vector() {
        // RFC 7636 Appendix B test vector.
        assert_eq!(
            pkce_challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        );
        let pair = generate_pkce();
        assert_eq!(pair.challenge, pkce_challenge(&pair.verifier));
        assert!(!format!("{pair:?}").contains(&pair.verifier));
    }

    #[test]
    fn authorize_url_carries_pkce_and_state() {
        let url = build_authorize_url("chal", "st").expect("url builds");
        let text = url.as_str();
        assert!(text.contains("code_challenge=chal"));
        assert!(text.contains("code_challenge_method=S256"));
        assert!(text.contains("state=st"));
        assert!(text.contains("response_type=code"));
    }

    fn fake_jwt(payload_json: &str) -> String {
        let header = URL_SAFE_NO_PAD.encode(b"{\"alg\":\"RS256\"}");
        let payload = URL_SAFE_NO_PAD.encode(payload_json.as_bytes());
        format!("{header}.{payload}.sig")
    }

    #[test]
    fn jwt_claims_parse_character_and_scopes() {
        let token = fake_jwt(
            r#"{"sub":"CHARACTER:EVE:12345","name":"Fixture Capsuleer","exp":9999999999,"scp":"esi-skills.read_skills.v1 esi-wallet.read_character_wallet.v1"}"#,
        );
        let claims = parse_jwt_claims(&token).expect("claims parse");
        assert_eq!(claims.character_id(), Some(12345));
        assert_eq!(claims.scp.len(), 2);
        assert!(!claims.is_expired_at(1_700_000_000));
        // Array form of scp too.
        let token2 = fake_jwt(r#"{"sub":"CHARACTER:EVE:9","name":"N","exp":1,"scp":["a","b"]}"#);
        let claims2 = parse_jwt_claims(&token2).expect("claims parse");
        assert_eq!(claims2.scp, vec!["a".to_string(), "b".to_string()]);
        assert!(claims2.is_expired_at(1_700_000_000));
    }

    #[test]
    fn malformed_jwt_is_rejected() {
        assert!(parse_jwt_claims("not-a-jwt").is_err());
        assert!(parse_jwt_claims("a.b").is_err());
        assert!(parse_jwt_claims("a.!!!.c").is_err());
    }

    #[test]
    fn refresh_buffer_math() {
        assert!(needs_refresh(1_000, 941));
        assert!(!needs_refresh(1_000, 900));
    }

    #[test]
    fn callback_url_validation() {
        let ok = url::Url::parse("http://127.0.0.1:54321/callback?code=abc&state=st").expect("url");
        assert_eq!(parse_callback_url(&ok, "st").expect("code"), "abc");
        let bad_state =
            url::Url::parse("http://127.0.0.1:54321/callback?code=abc&state=no").expect("url");
        assert!(matches!(
            parse_callback_url(&bad_state, "st"),
            Err(AuthError::StateMismatch)
        ));
        let denied =
            url::Url::parse("http://127.0.0.1:54321/callback?error=access_denied&state=st")
                .expect("url");
        assert!(matches!(
            parse_callback_url(&denied, "st"),
            Err(AuthError::Denied(_))
        ));
        let no_code = url::Url::parse("http://127.0.0.1:54321/callback?state=st").expect("url");
        assert!(matches!(
            parse_callback_url(&no_code, "st"),
            Err(AuthError::MissingCode)
        ));
    }

    #[test]
    fn token_response_debug_redacts() {
        let t = TokenResponse {
            access_token: "sekrit-a".to_string(),
            refresh_token: "sekrit-r".to_string(),
            expires_in: 1199,
            token_type: "Bearer".to_string(),
        };
        let rendered = format!("{t:?}");
        assert!(!rendered.contains("sekrit-a"));
        assert!(!rendered.contains("sekrit-r"));
        assert_eq!(t.expires_at_unix(1000), 2199);
    }
}
