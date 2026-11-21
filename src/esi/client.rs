//! ESI HTTP client (`/latest` + tranquility, Bearer auth, error-limit
//! tracking), ported from `lib/core/network/esi_client.dart`.
//!
//! Mockable HTTP: construct with `EsiClient::with_base_url(...)` or
//! `EsiClient::with_http(...)` to point at a local test server, and with a
//! file-only `TokenStore` for authenticated calls. Access tokens are
//! fetched (and refreshed when inside the 60 s buffer) from the token
//! store per character; token values are never logged.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use serde::de::DeserializeOwned;
use serde::Serialize;

use crate::auth::jwt_verify::JwtVerifier;
use crate::auth::oauth;
use crate::auth::token_store::{AccessToken, TokenStore};
use crate::config::{now_unix, EveConfig};
use crate::error::{AppError, AppResult, AuthError, EsiError};

/// Metadata captured from response headers alongside a decoded body.
#[derive(Debug, Clone, Copy, Default)]
pub struct EsiMeta {
    /// `X-Pages` header (total pages for paged endpoints), when present.
    pub pages: Option<u32>,
    pub error_limit_remain: u32,
    pub error_limit_reset_secs: u32,
}

#[derive(Clone, Copy)]
struct ErrorLimit {
    remain: u32,
    reset_secs: u32,
    updated_at: Instant,
}

impl ErrorLimit {
    fn refresh_if_elapsed(&mut self) -> bool {
        if self.remain == 0
            && self.updated_at.elapsed() >= Duration::from_secs(u64::from(self.reset_secs))
        {
            self.remain = EveConfig::MAX_ERRORS_PER_MINUTE;
            self.reset_secs = 0;
            self.updated_at = Instant::now();
            true
        } else {
            false
        }
    }

    fn remaining_reset_secs(&self) -> u32 {
        if self.remain == 0 {
            let elapsed = self.updated_at.elapsed().as_secs();
            u64::from(self.reset_secs).saturating_sub(elapsed) as u32
        } else {
            self.reset_secs
        }
    }
}

pub struct EsiClient {
    http: reqwest::Client,
    base_url: String,
    token_endpoint: String,
    client_id: String,
    token_store: Option<Arc<TokenStore>>,
    jwt_verifier: Option<Arc<JwtVerifier>>,
    error_limit: Mutex<ErrorLimit>,
    refresh_locks: Mutex<HashMap<i64, Arc<tokio::sync::Mutex<()>>>>,
}

impl EsiClient {
    pub fn new() -> AppResult<Self> {
        Self::with_base_url(EveConfig::ESI_BASE_URL.to_string())
    }

    pub fn with_base_url(base_url: String) -> AppResult<Self> {
        tracing::info!("[ESI] creating ESI client base={}", base_url);
        let http = reqwest::Client::builder()
            .timeout(Duration::from_millis(EveConfig::DEFAULT_TIMEOUT_MS))
            .user_agent(EveConfig::USER_AGENT)
            .build()
            .map_err(|e| AppError::Message(e.to_string()))?;
        Ok(Self::with_http(http, base_url))
    }

    /// Injected-HTTP constructor (the mockable seam).
    pub fn with_http(http: reqwest::Client, base_url: String) -> Self {
        Self {
            http,
            base_url: base_url.trim_end_matches('/').to_string(),
            token_endpoint: EveConfig::OAUTH_TOKEN_URL.to_string(),
            client_id: EveConfig::CLIENT_ID.to_string(),
            token_store: None,
            jwt_verifier: None,
            error_limit: Mutex::new(ErrorLimit {
                remain: EveConfig::MAX_ERRORS_PER_MINUTE,
                reset_secs: 0,
                updated_at: Instant::now(),
            }),
            refresh_locks: Mutex::new(HashMap::new()),
        }
    }

    /// Attach the token store used for authenticated calls + auto-refresh.
    pub fn with_token_store(mut self, store: Arc<TokenStore>) -> Self {
        tracing::debug!("[ESI] token store attached");
        self.token_store = Some(store);
        self
    }

    /// Attach the shared JWT verifier. A needed refresh without one
    /// fails closed (see `valid_access_token`); it never skips
    /// verification silently.
    pub fn with_jwt_verifier(mut self, verifier: Arc<JwtVerifier>) -> Self {
        tracing::debug!("[ESI] JWT verifier attached");
        self.jwt_verifier = Some(verifier);
        self
    }

    /// Point token refresh at a different endpoint (tests).
    pub fn with_token_endpoint(mut self, endpoint: String, client_id: String) -> Self {
        tracing::debug!("[ESI] token endpoint overridden");
        self.token_endpoint = endpoint;
        self.client_id = client_id;
        self
    }

    pub fn http(&self) -> &reqwest::Client {
        &self.http
    }

    pub fn base_url(&self) -> &str {
        &self.base_url
    }

    pub fn error_limit_remain(&self) -> u32 {
        self.error_limit
            .lock()
            .map(|mut g| {
                if g.refresh_if_elapsed() {
                    tracing::info!("[ESI] error limit cooldown elapsed; resuming requests");
                }
                g.remain
            })
            .unwrap_or(0)
    }

    pub fn error_limit_reset_secs(&self) -> u32 {
        self.error_limit
            .lock()
            .map(|mut g| {
                if g.refresh_if_elapsed() {
                    tracing::info!("[ESI] error limit cooldown elapsed; resuming requests");
                }
                g.remaining_reset_secs()
            })
            .unwrap_or(0)
    }

    pub fn is_near_error_limit(&self) -> bool {
        self.error_limit_remain() < EveConfig::ERROR_LIMIT_WARN_REMAIN
    }

    /// Record `X-ESI-Error-Limit-Remain` / `-Reset` values.
    pub fn update_error_limit(&self, remain: u32, reset_secs: u32) {
        tracing::debug!("[ESI] error limit remain={} reset={}s", remain, reset_secs);
        if remain < EveConfig::ERROR_LIMIT_WARN_REMAIN {
            tracing::warn!(
                "[ESI] near error limit remain={} reset={}s",
                remain,
                reset_secs
            );
        }
        if let Ok(mut guard) = self.error_limit.lock() {
            guard.remain = remain;
            guard.reset_secs = reset_secs;
            guard.updated_at = Instant::now();
        }
    }

    fn update_error_limit_from_headers(&self, headers: &reqwest::header::HeaderMap) {
        let parse = |name: &str| {
            headers
                .get(name)
                .and_then(|v| v.to_str().ok())
                .and_then(|s| s.trim().parse::<u32>().ok())
        };
        if let (Some(remain), Some(reset)) = (
            parse("x-esi-error-limit-remain"),
            parse("x-esi-error-limit-reset"),
        ) {
            self.update_error_limit(remain, reset);
        } else if let Some(remain) = parse("x-esi-error-limit-remain") {
            let reset = self.error_limit_reset_secs();
            self.update_error_limit(remain, reset);
        }
    }

    fn check_error_limit(&self, path: &str) -> AppResult<()> {
        if let Ok(mut guard) = self.error_limit.lock() {
            if guard.refresh_if_elapsed() {
                tracing::info!("[ESI] error limit cooldown elapsed; resuming requests");
                return Ok(());
            }
            if guard.remain == 0 {
                let reset_secs = guard.remaining_reset_secs();
                tracing::warn!(
                    "[ESI] error limit exhausted; refusing {} reset={}s",
                    path,
                    reset_secs
                );
                return Err(EsiError::ErrorLimitExhausted { reset_secs }.into());
            }
        }
        Ok(())
    }

    fn refresh_lock(&self, character_id: i64) -> Arc<tokio::sync::Mutex<()>> {
        let mut guard = self
            .refresh_locks
            .lock()
            .unwrap_or_else(|poison| poison.into_inner());
        guard
            .entry(character_id)
            .or_insert_with(|| Arc::new(tokio::sync::Mutex::new(())))
            .clone()
    }

    /// Absolute URL for an ESI path, with `datasource=tranquility` appended
    /// (extra `query` pairs are added by the request builder).
    pub fn build_url(&self, path: &str) -> String {
        let separator = if path.contains('?') { '&' } else { '?' };
        format!(
            "{}{}{}datasource={}",
            self.base_url,
            path,
            separator,
            EveConfig::DATASOURCE
        )
    }

    /// Valid access token for a character: loads stored tokens, refreshes
    /// when expired/inside the buffer, persists the rotated tokens, and
    /// returns the access token. Never logs token values.
    pub async fn valid_access_token(&self, character_id: i64) -> AppResult<AccessToken> {
        tracing::debug!("[ESI] valid_access_token character_id={}", character_id);
        let store = self
            .token_store
            .as_ref()
            .ok_or_else(|| AppError::from(EsiError::NoTokens(character_id)))?;
        let tokens = store
            .load(character_id)?
            .ok_or_else(|| AppError::from(EsiError::NoTokens(character_id)))?;
        if !tokens.needs_refresh_at(now_unix()) {
            return Ok(tokens.access);
        }
        let lock = self.refresh_lock(character_id);
        let _refresh_guard = lock.lock().await;
        // Re-check after acquiring the per-character lock: a concurrent caller
        // may have already rotated and persisted fresh tokens while we waited.
        let mut tokens = store
            .load(character_id)?
            .ok_or_else(|| AppError::from(EsiError::NoTokens(character_id)))?;
        if !tokens.needs_refresh_at(now_unix()) {
            tracing::debug!(
                "[AUTH] reusing freshly rotated access token character_id={}",
                character_id
            );
            return Ok(tokens.access);
        }
        // Fail closed before the refresh (and therefore before any
        // save) when verification is not wired: never skip it.
        let verifier = self.jwt_verifier.as_ref().ok_or_else(|| {
            tracing::warn!(
                "[AUTH] token verification not wired; refusing refresh character_id={}",
                character_id
            );
            AppError::from(AuthError::JwksUnavailable)
        })?;
        tracing::info!(
            "[AUTH] refreshing access token character_id={}",
            character_id
        );
        let refreshed = oauth::refresh_with(
            &self.http,
            &self.token_endpoint,
            &self.client_id,
            tokens.refresh.as_str(),
        )
        .await
        .map_err(|e| match e {
            AuthError::RefreshRejected => AppError::from(EsiError::Reauthorize),
            other => AppError::from(other),
        })?;
        // Verify before trusting any claim or persisting anything:
        // a rejection drops the whole refresh response, rotated
        // refresh token included, and stored tokens are untouched.
        let claims = verifier
            .verify(&refreshed.access_token)
            .await
            .map_err(|e| match e {
                AuthError::RefreshRejected => AppError::from(EsiError::Reauthorize),
                other => AppError::from(other),
            })?;
        if claims.character_id() != Some(character_id) {
            tracing::warn!(
                "[AUTH] refreshed token names a different character; refusing save character_id={}",
                character_id
            );
            return Err(AppError::from(AuthError::CharacterMismatch));
        }
        tokens.apply_refresh(&refreshed, &claims);
        store.save(&tokens)?;
        Ok(tokens.access)
    }

    async fn send<T: DeserializeOwned>(
        &self,
        request: reqwest::RequestBuilder,
        path: &str,
    ) -> AppResult<(T, EsiMeta)> {
        self.check_error_limit(path)?;
        // Error Display text reaches load-state UI panels: strip the
        // request URL (which embeds numeric character IDs) at this
        // single conversion boundary. Logs below keep the path.
        let response = request
            .send()
            .await
            .map_err(|e| EsiError::from(e.without_url()))?;
        let status = response.status();
        self.update_error_limit_from_headers(response.headers());
        let pages = response
            .headers()
            .get("x-pages")
            .and_then(|v| v.to_str().ok())
            .and_then(|s| s.trim().parse::<u32>().ok());
        let meta = EsiMeta {
            pages,
            error_limit_remain: self.error_limit_remain(),
            error_limit_reset_secs: self.error_limit_reset_secs(),
        };
        let body = response
            .text()
            .await
            .map_err(|e| EsiError::from(e.without_url()))?;
        if !status.is_success() {
            tracing::warn!(
                "[ESI] request failed path={} status={}",
                path,
                status.as_u16()
            );
            return Err(
                EsiError::from_status(status.as_u16(), &body, meta.error_limit_reset_secs).into(),
            );
        }
        let parsed: T = serde_json::from_str(&body).map_err(|e| {
            tracing::warn!("[ESI] decode failed path={}: {}", path, e);
            // Path stays in the log line above; error text reaches UI
            // error panels and must never carry the numeric IDs in it.
            AppError::from(EsiError::Decode(e.to_string()))
        })?;
        tracing::debug!("[ESI] request ok path={} status={}", path, status.as_u16());
        Ok((parsed, meta))
    }

    /// Sibling of `send` for operations whose success body is
    /// defined as empty (the fitting DELETE answers 204 with
    /// no body): identical error-limit, transport, and status
    /// handling, but any 2xx returns `Ok(())` without decoding.
    /// `send` itself is untouched, so no read path changes.
    async fn send_unit(&self, request: reqwest::RequestBuilder, path: &str) -> AppResult<()> {
        self.check_error_limit(path)?;
        let response = request
            .send()
            .await
            .map_err(|e| EsiError::from(e.without_url()))?;
        let status = response.status();
        self.update_error_limit_from_headers(response.headers());
        let body = response
            .text()
            .await
            .map_err(|e| EsiError::from(e.without_url()))?;
        if !status.is_success() {
            tracing::warn!(
                "[ESI] request failed path={} status={}",
                path,
                status.as_u16()
            );
            return Err(EsiError::from_status(
                status.as_u16(),
                &body,
                self.error_limit_reset_secs(),
            )
            .into());
        }
        tracing::debug!("[ESI] request ok path={} status={}", path, status.as_u16());
        Ok(())
    }

    pub async fn public_get<T: DeserializeOwned>(&self, path: &str) -> AppResult<T> {
        tracing::debug!("[ESI] GET {}", path);
        let (value, _meta) = self.send(self.http.get(self.build_url(path)), path).await?;
        Ok(value)
    }

    pub async fn public_get_page<T: DeserializeOwned>(
        &self,
        path: &str,
        page: u32,
    ) -> AppResult<(T, EsiMeta)> {
        tracing::debug!("[ESI] GET {} page={}", path, page);
        let request = self
            .http
            .get(self.build_url(path))
            .query(&[("page", page.to_string())]);
        self.send(request, path).await
    }

    pub async fn public_post<T: DeserializeOwned, B: Serialize>(
        &self,
        path: &str,
        body: &B,
    ) -> AppResult<T> {
        tracing::debug!("[ESI] POST {}", path);
        let (value, _meta) = self
            .send(self.http.post(self.build_url(path)).json(body), path)
            .await?;
        Ok(value)
    }

    pub async fn auth_get<T: DeserializeOwned>(
        &self,
        path: &str,
        character_id: i64,
    ) -> AppResult<T> {
        let (value, _meta) = self.auth_get_page(path, character_id, None).await?;
        Ok(value)
    }

    pub async fn auth_get_page<T: DeserializeOwned>(
        &self,
        path: &str,
        character_id: i64,
        page: Option<u32>,
    ) -> AppResult<(T, EsiMeta)> {
        tracing::debug!("[ESI] GET {} character_id={}", path, character_id);
        let token = self.valid_access_token(character_id).await?;
        let mut request = self
            .http
            .get(self.build_url(path))
            .bearer_auth(token.as_str());
        if let Some(page) = page {
            request = request.query(&[("page", page.to_string())]);
        }
        self.send(request, path).await
    }

    /// Authenticated GET with a caller-supplied token (no store needed).
    pub async fn auth_get_with_token<T: DeserializeOwned>(
        &self,
        path: &str,
        access_token: &AccessToken,
    ) -> AppResult<T> {
        tracing::debug!("[ESI] GET {} (explicit token)", path);
        let request = self
            .http
            .get(self.build_url(path))
            .bearer_auth(access_token.as_str());
        let (value, _meta) = self.send(request, path).await?;
        Ok(value)
    }

    pub async fn auth_post<T: DeserializeOwned, B: Serialize>(
        &self,
        path: &str,
        character_id: i64,
        body: &B,
    ) -> AppResult<T> {
        tracing::debug!("[ESI] POST {} character_id={}", path, character_id);
        let token = self.valid_access_token(character_id).await?;
        let request = self
            .http
            .post(self.build_url(path))
            .bearer_auth(token.as_str())
            .json(body);
        let (value, _meta) = self.send(request, path).await?;
        Ok(value)
    }

    pub async fn auth_delete(&self, path: &str, character_id: i64) -> AppResult<()> {
        tracing::debug!("[ESI] DELETE {} character_id={}", path, character_id);
        let token = self.valid_access_token(character_id).await?;
        let request = self
            .http
            .delete(self.build_url(path))
            .bearer_auth(token.as_str());
        self.send_unit(request, path).await
    }
}

impl Default for EsiClient {
    fn default() -> Self {
        Self::with_http(reqwest::Client::new(), EveConfig::ESI_BASE_URL.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::auth::token_store::{RefreshToken, StoredTokens};
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;

    /// One-shot HTTP/1.1 test server: captures the request, returns `body`.
    async fn mock_server(
        status: u16,
        extra_headers: &'static str,
        body: &'static str,
    ) -> (String, tokio::sync::oneshot::Receiver<String>) {
        let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind mock");
        let addr = listener.local_addr().expect("addr");
        let (tx, rx) = tokio::sync::oneshot::channel::<String>();
        tokio::spawn(async move {
            if let Ok((mut socket, _peer)) = listener.accept().await {
                let mut buffer = vec![0u8; 16384];
                let count = socket.read(&mut buffer).await.unwrap_or(0);
                let _ = tx.send(String::from_utf8_lossy(&buffer[..count]).into_owned());
                let payload = format!(
                    "HTTP/1.1 {status} OK\r\nContent-Type: application/json\r\n{extra_headers}Content-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                );
                let _ = socket.write_all(payload.as_bytes()).await;
                let _ = socket.flush().await;
            }
        });
        (format!("http://{addr}"), rx)
    }

    /// Owned-body variant of `mock_server` for dynamically built bodies
    /// (signed-token responses and JWKS documents).
    async fn mock_server_owned(body: String) -> (String, tokio::sync::oneshot::Receiver<String>) {
        let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind mock");
        let addr = listener.local_addr().expect("addr");
        let (tx, rx) = tokio::sync::oneshot::channel::<String>();
        tokio::spawn(async move {
            if let Ok((mut socket, _peer)) = listener.accept().await {
                let mut buffer = vec![0u8; 16384];
                let count = socket.read(&mut buffer).await.unwrap_or(0);
                let _ = tx.send(String::from_utf8_lossy(&buffer[..count]).into_owned());
                let payload = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                );
                let _ = socket.write_all(payload.as_bytes()).await;
                let _ = socket.flush().await;
            }
        });
        (format!("http://{addr}"), rx)
    }

    // TEST-ONLY signed-token fixtures: a minimal copy of the RS256
    // signing helper in `src/auth/jwt_verify.rs` tests (keys generated
    // in code here, never committed material; the signing is manual and
    // independent of the verifying library).
    struct TestRng;

    impl rsa::rand_core::TryRng for TestRng {
        type Error = std::convert::Infallible;

        fn try_next_u32(&mut self) -> Result<u32, Self::Error> {
            let mut bytes = [0u8; 4];
            self.try_fill_bytes(&mut bytes)?;
            Ok(u32::from_le_bytes(bytes))
        }

        fn try_next_u64(&mut self) -> Result<u64, Self::Error> {
            let mut bytes = [0u8; 8];
            self.try_fill_bytes(&mut bytes)?;
            Ok(u64::from_le_bytes(bytes))
        }

        fn try_fill_bytes(&mut self, dst: &mut [u8]) -> Result<(), Self::Error> {
            rand::RngCore::fill_bytes(&mut rand::thread_rng(), dst);
            Ok(())
        }
    }

    impl rsa::rand_core::TryCryptoRng for TestRng {}

    fn b64(bytes: &[u8]) -> String {
        use base64::Engine as _;
        base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(bytes)
    }

    fn uint_b64(bytes: &[u8]) -> String {
        let mut start = 0;
        while start + 1 < bytes.len() && bytes[start] == 0 {
            start += 1;
        }
        b64(&bytes[start..])
    }

    fn payload_for(character_id: i64) -> serde_json::Value {
        let now = crate::config::now_unix();
        serde_json::json!({
            "sub": format!("CHARACTER:EVE:{character_id}"),
            "name": "Fixture Capsuleer",
            "exp": now + 1199,
            "iat": now,
            "scp": ["esi-skills.read_skills.v1"],
            "iss": "login.eveonline.com",
            "aud": ["test-client", "EVE Online"],
            "owner": "fixture-owner",
        })
    }

    /// Generate a TEST-ONLY 2048-bit RSA key in code, manually sign an
    /// RS256 token for `character_id`, and return it with the JWKS
    /// document carrying the public key.
    fn signed_rs256_token(character_id: i64) -> (String, String) {
        use rsa::sha2::{Digest as _, Sha256 as RsaSha256};
        use rsa::traits::PublicKeyParts as _;
        use rsa::{Pkcs1v15Sign, PrivateKey};
        let private = PrivateKey::new(&mut TestRng, 2048).expect("rsa keygen");
        let jwks = serde_json::json!({
            "keys": [{
                "kty": "RSA", "kid": "rsa-1", "use": "sig", "alg": "RS256",
                "n": uint_b64(&private.n().to_be_bytes()),
                "e": uint_b64(&private.e().to_be_bytes()),
            }]
        })
        .to_string();
        let header = serde_json::json!({"alg": "RS256", "kid": "rsa-1", "typ": "JWT"});
        let signing_input = format!(
            "{}.{}",
            b64(header.to_string().as_bytes()),
            b64(payload_for(character_id).to_string().as_bytes())
        );
        let digest = RsaSha256::digest(signing_input.as_bytes());
        let signature = private
            .sign(Pkcs1v15Sign::new::<RsaSha256>(), &digest)
            .expect("rs256 sign");
        (format!("{signing_input}.{}", b64(&signature)), jwks)
    }

    /// Replace a token's payload segment under its original signature.
    fn tamper_payload(token: &str, character_id: i64) -> String {
        let mut parts = token.split('.');
        let header = parts.next().expect("header segment");
        let _original = parts.next().expect("payload segment");
        let signature = parts.next().expect("signature segment");
        format!(
            "{}.{}.{}",
            header,
            b64(payload_for(character_id).to_string().as_bytes()),
            signature
        )
    }

    fn token_response_body(access_token: &str) -> String {
        serde_json::json!({
            "access_token": access_token,
            "refresh_token": "fresh-refresh",
            "expires_in": 1199,
            "token_type": "Bearer",
        })
        .to_string()
    }

    fn seeded_expired_store(dir: &tempfile::TempDir) -> Arc<TokenStore> {
        let store = Arc::new(TokenStore::file_only(dir.path().join("tokens.json")));
        store
            .save(&StoredTokens {
                character_id: 99,
                access: AccessToken("stale-access".to_string()),
                refresh: RefreshToken("stale-refresh".to_string()),
                expires_at_unix: 1, // long expired -> must refresh
            })
            .expect("seed tokens");
        store
    }

    fn test_verifier(jwks_base: &str) -> Arc<JwtVerifier> {
        Arc::new(JwtVerifier::with_endpoint(
            reqwest::Client::new(),
            format!("{jwks_base}/oauth/jwks"),
            "test-client".to_string(),
        ))
    }

    fn assert_stored_tokens_unchanged(store: &TokenStore) {
        let persisted = store
            .load(99)
            .expect("load")
            .expect("seeded tokens present");
        assert!(persisted.access.as_str() == "stale-access");
        assert!(persisted.refresh.as_str() == "stale-refresh");
        assert_eq!(persisted.expires_at_unix, 1);
    }

    #[test]
    fn build_url_adds_datasource() {
        let client = EsiClient::with_http(reqwest::Client::new(), "http://x/latest/".to_string());
        assert_eq!(
            client.build_url("/characters/1/"),
            "http://x/latest/characters/1/?datasource=tranquility"
        );
    }

    #[tokio::test]
    async fn public_get_decodes_and_tracks_error_limit() {
        let (base, captured) = mock_server(
            200,
            "X-ESI-Error-Limit-Remain: 42\r\nX-ESI-Error-Limit-Reset: 30\r\n",
            r#"{"name":"Fixture"}"#,
        )
        .await;
        let client = EsiClient::with_http(reqwest::Client::new(), base);
        let value: serde_json::Value = client.public_get("/characters/1/").await.expect("get");
        assert_eq!(value["name"], "Fixture");
        assert_eq!(client.error_limit_remain(), 42);
        assert_eq!(client.error_limit_reset_secs(), 30);
        let request = captured.await.expect("captured");
        assert!(request.contains("datasource=tranquility"));
        assert!(!request.to_lowercase().contains("authorization"));
    }

    #[tokio::test]
    async fn status_errors_map_to_typed_errors() {
        let (base, _rx) = mock_server(403, "", r#"{"error":"Forbidden"}"#).await;
        let client = EsiClient::with_http(reqwest::Client::new(), base);
        let result: AppResult<serde_json::Value> = client.public_get("/x/").await;
        assert!(matches!(result, Err(AppError::Esi(EsiError::Reauthorize))));
    }

    #[tokio::test]
    async fn exhausted_error_limit_refuses_requests() {
        let client = EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string());
        client.update_error_limit(0, 45);
        let result: AppResult<serde_json::Value> = client.public_get("/x/").await;
        assert!(matches!(
            result,
            Err(AppError::Esi(EsiError::ErrorLimitExhausted {
                reset_secs: 45
            }))
        ));
    }

    #[tokio::test]
    async fn exhausted_error_limit_recovers_after_cooldown_elapses() {
        let (base, _rx) = mock_server(
            200,
            "X-ESI-Error-Limit-Remain: 100\r\nX-ESI-Error-Limit-Reset: 60\r\n",
            r#"{"ok":true}"#,
        )
        .await;
        let client = EsiClient::with_http(reqwest::Client::new(), base);
        client.update_error_limit(0, 1);
        let refused: AppResult<serde_json::Value> = client.public_get("/x/").await;
        assert!(matches!(
            refused,
            Err(AppError::Esi(EsiError::ErrorLimitExhausted { .. }))
        ));
        tokio::time::sleep(Duration::from_millis(1050)).await;
        let value: serde_json::Value = client
            .public_get("/x/")
            .await
            .expect("requests must resume once reset window elapses");
        assert_eq!(value["ok"], true);
        assert_eq!(client.error_limit_remain(), 100);
    }

    #[tokio::test]
    async fn auth_get_refreshes_expired_token_via_mock() {
        // Properly test-signed RS256 token (case 18): an unverifiable
        // placeholder would now be rejected before any save.
        let (signed_access, jwks_body) = signed_rs256_token(99);
        let (jwks_base, jwks_request) = mock_server_owned(jwks_body).await;
        // Token endpoint mock returns the signed token.
        let (token_base, token_request) =
            mock_server_owned(token_response_body(&signed_access)).await;
        // ESI mock.
        let (base, esi_request) = mock_server(200, "", r#"{"total_sp":10,"skills":[]}"#).await;
        let dir = tempfile::tempdir().expect("tempdir");
        let store = seeded_expired_store(&dir);
        let client = EsiClient::with_http(reqwest::Client::new(), base)
            .with_token_store(store.clone())
            .with_token_endpoint(
                format!("{token_base}/oauth/token"),
                "test-client".to_string(),
            )
            .with_jwt_verifier(test_verifier(&jwks_base));
        let value: serde_json::Value = client
            .auth_get("/characters/99/skills/", 99)
            .await
            .expect("auth get");
        assert_eq!(value["total_sp"], 10);
        let refresh_body = token_request.await.expect("refresh captured");
        assert!(refresh_body.contains("grant_type=refresh_token"));
        let esi_req = esi_request.await.expect("esi captured");
        assert!(esi_req.contains(&format!("Bearer {signed_access}")));
        // The JWKS fetch carries no token material.
        let jwks_req = jwks_request.await.expect("jwks captured");
        assert!(!jwks_req.to_lowercase().contains("authorization"));
        let persisted = store.load(99).expect("load").expect("persisted");
        assert!(persisted.access.as_str() == signed_access);
        assert!(persisted.refresh.as_str() == "fresh-refresh");
        assert!(persisted.expires_at_unix > crate::config::now_unix());
    }

    // Case 19: a tampered refreshed token is rejected and the
    // previously stored tokens are left exactly as seeded.
    #[tokio::test]
    async fn auth_get_rejects_tampered_refreshed_token_and_saves_nothing() {
        let (signed_access, jwks_body) = signed_rs256_token(99);
        // Different payload under the original signature (a regenerated
        // identical payload would not be a tamper).
        let tampered = tamper_payload(&signed_access, 100);
        let (jwks_base, _jwks_request) = mock_server_owned(jwks_body).await;
        let (token_base, _token_request) = mock_server_owned(token_response_body(&tampered)).await;
        let dir = tempfile::tempdir().expect("tempdir");
        let store = seeded_expired_store(&dir);
        let client = EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string())
            .with_token_store(store.clone())
            .with_token_endpoint(
                format!("{token_base}/oauth/token"),
                "test-client".to_string(),
            )
            .with_jwt_verifier(test_verifier(&jwks_base));
        let result: AppResult<serde_json::Value> =
            client.auth_get("/characters/99/skills/", 99).await;
        assert!(matches!(
            result,
            Err(AppError::Auth(AuthError::InvalidSignature))
        ));
        assert_stored_tokens_unchanged(&store);
    }

    // Case 20: a validly signed refreshed token naming a different
    // character is rejected and stored tokens are unchanged.
    #[tokio::test]
    async fn auth_get_rejects_refreshed_token_for_wrong_character() {
        let (signed_access, jwks_body) = signed_rs256_token(100);
        let (jwks_base, _jwks_request) = mock_server_owned(jwks_body).await;
        let (token_base, _token_request) =
            mock_server_owned(token_response_body(&signed_access)).await;
        let dir = tempfile::tempdir().expect("tempdir");
        let store = seeded_expired_store(&dir);
        let client = EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string())
            .with_token_store(store.clone())
            .with_token_endpoint(
                format!("{token_base}/oauth/token"),
                "test-client".to_string(),
            )
            .with_jwt_verifier(test_verifier(&jwks_base));
        let result: AppResult<serde_json::Value> =
            client.auth_get("/characters/99/skills/", 99).await;
        assert!(matches!(
            result,
            Err(AppError::Auth(AuthError::CharacterMismatch))
        ));
        assert_stored_tokens_unchanged(&store);
    }

    // Absence rule: a needed refresh with no verifier attached fails
    // closed before the token endpoint is even called (the endpoint
    // below is unreachable; a refresh attempt would surface a
    // different error), and stored tokens are unchanged.
    #[tokio::test]
    async fn auth_get_refresh_without_verifier_fails_closed() {
        let dir = tempfile::tempdir().expect("tempdir");
        let store = seeded_expired_store(&dir);
        let client = EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string())
            .with_token_store(store.clone())
            .with_token_endpoint(
                "http://127.0.0.1:9/oauth/token".to_string(),
                "test-client".to_string(),
            );
        let result: AppResult<serde_json::Value> =
            client.auth_get("/characters/99/skills/", 99).await;
        assert!(matches!(
            result,
            Err(AppError::Auth(AuthError::JwksUnavailable))
        ));
        assert_stored_tokens_unchanged(&store);
    }

    #[tokio::test]
    async fn auth_get_without_tokens_fails_typed() {
        let dir = tempfile::tempdir().expect("tempdir");
        let store = Arc::new(TokenStore::file_only(dir.path().join("tokens.json")));
        let client = EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string())
            .with_token_store(store);
        let result: AppResult<serde_json::Value> = client.auth_get("/x/", 5).await;
        assert!(matches!(result, Err(AppError::Esi(EsiError::NoTokens(5)))));
    }

    #[tokio::test]
    async fn concurrent_valid_access_token_refreshes_once() {
        use std::sync::atomic::{AtomicUsize, Ordering};
        let (signed_access, jwks_body) = signed_rs256_token(99);
        let jwks_listener = TcpListener::bind("127.0.0.1:0").await.expect("bind jwks");
        let jwks_addr = jwks_listener.local_addr().expect("addr");
        tokio::spawn(async move {
            loop {
                let Ok((mut socket, _)) = jwks_listener.accept().await else {
                    break;
                };
                let body = jwks_body.clone();
                tokio::spawn(async move {
                    let mut buf = vec![0u8; 4096];
                    let _ = socket.read(&mut buf).await;
                    let payload = format!(
                        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(payload.as_bytes()).await;
                });
            }
        });

        let token_hits = Arc::new(AtomicUsize::new(0));
        let token_hits_task = token_hits.clone();
        let token_body = token_response_body(&signed_access);
        let token_listener = TcpListener::bind("127.0.0.1:0").await.expect("bind token");
        let token_addr = token_listener.local_addr().expect("addr");
        tokio::spawn(async move {
            loop {
                let Ok((mut socket, _)) = token_listener.accept().await else {
                    break;
                };
                let hits = token_hits_task.clone();
                let body = token_body.clone();
                tokio::spawn(async move {
                    let mut buf = vec![0u8; 4096];
                    let _ = socket.read(&mut buf).await;
                    hits.fetch_add(1, Ordering::SeqCst);
                    tokio::time::sleep(Duration::from_millis(50)).await;
                    let payload = format!(
                        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(payload.as_bytes()).await;
                });
            }
        });

        let dir = tempfile::tempdir().expect("tempdir");
        let store = seeded_expired_store(&dir);
        let client = Arc::new(
            EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string())
                .with_token_store(store)
                .with_token_endpoint(
                    format!("http://{token_addr}/oauth/token"),
                    "test-client".to_string(),
                )
                .with_jwt_verifier(test_verifier(&format!("http://{jwks_addr}"))),
        );
        let (r1, r2) = tokio::join!(client.valid_access_token(99), client.valid_access_token(99));
        let t1 = r1.expect("task 1 succeeds");
        let t2 = r2.expect("task 2 succeeds");
        assert_eq!(t1.as_str(), signed_access);
        assert_eq!(t2.as_str(), signed_access);
        assert_eq!(
            token_hits.load(Ordering::SeqCst),
            1,
            "per-character lock must deduplicate concurrent refresh requests"
        );
    }
}
