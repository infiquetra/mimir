//! ESI HTTP client (`/latest` + tranquility, Bearer auth, error-limit
//! tracking), ported from `lib/core/network/esi_client.dart`.
//!
//! Mockable HTTP: construct with `EsiClient::with_base_url(...)` or
//! `EsiClient::with_http(...)` to point at a local test server, and with a
//! file-only `TokenStore` for authenticated calls. Access tokens are
//! fetched (and refreshed when inside the 60 s buffer) from the token
//! store per character; token values are never logged.

use std::sync::{Arc, Mutex};
use std::time::Duration;

use serde::de::DeserializeOwned;
use serde::Serialize;

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
}

pub struct EsiClient {
    http: reqwest::Client,
    base_url: String,
    token_endpoint: String,
    client_id: String,
    token_store: Option<Arc<TokenStore>>,
    error_limit: Mutex<ErrorLimit>,
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
            error_limit: Mutex::new(ErrorLimit {
                remain: EveConfig::MAX_ERRORS_PER_MINUTE,
                reset_secs: 0,
            }),
        }
    }

    /// Attach the token store used for authenticated calls + auto-refresh.
    pub fn with_token_store(mut self, store: Arc<TokenStore>) -> Self {
        tracing::debug!("[ESI] token store attached");
        self.token_store = Some(store);
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
        self.error_limit.lock().map(|g| g.remain).unwrap_or(0)
    }

    pub fn error_limit_reset_secs(&self) -> u32 {
        self.error_limit.lock().map(|g| g.reset_secs).unwrap_or(0)
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
            self.update_error_limit(remain, self.error_limit_reset_secs());
        }
    }

    fn check_error_limit(&self, path: &str) -> AppResult<()> {
        if self.error_limit_remain() == 0 {
            let reset_secs = self.error_limit_reset_secs();
            tracing::warn!(
                "[ESI] error limit exhausted; refusing {} reset={}s",
                path,
                reset_secs
            );
            return Err(EsiError::ErrorLimitExhausted { reset_secs }.into());
        }
        Ok(())
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
        let mut tokens = store
            .load(character_id)?
            .ok_or_else(|| AppError::from(EsiError::NoTokens(character_id)))?;
        if tokens.needs_refresh_at(now_unix()) {
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
            tokens.apply_refresh(&refreshed);
            store.save(&tokens)?;
        }
        Ok(tokens.access)
    }

    async fn send<T: DeserializeOwned>(
        &self,
        request: reqwest::RequestBuilder,
        path: &str,
    ) -> AppResult<(T, EsiMeta)> {
        self.check_error_limit(path)?;
        let response = request.send().await.map_err(EsiError::from)?;
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
        let body = response.text().await.map_err(EsiError::from)?;
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
            AppError::from(EsiError::Decode(format!("{path}: {e}")))
        })?;
        tracing::debug!("[ESI] request ok path={} status={}", path, status.as_u16());
        Ok((parsed, meta))
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
    async fn auth_get_refreshes_expired_token_via_mock() {
        // Token endpoint mock.
        let (token_base, token_request) = mock_server(
            200,
            "",
            r#"{"access_token":"fresh-access","refresh_token":"fresh-refresh","expires_in":1199,"token_type":"Bearer"}"#,
        )
        .await;
        // ESI mock.
        let (base, esi_request) = mock_server(200, "", r#"{"total_sp":10,"skills":[]}"#).await;
        let dir = tempfile::tempdir().expect("tempdir");
        let store = Arc::new(TokenStore::file_only(dir.path().join("tokens.json")));
        store
            .save(&StoredTokens {
                character_id: 99,
                access: AccessToken("stale-access".to_string()),
                refresh: RefreshToken("stale-refresh".to_string()),
                expires_at_unix: 1, // long expired -> must refresh
            })
            .expect("seed tokens");
        let client = EsiClient::with_http(reqwest::Client::new(), base)
            .with_token_store(store.clone())
            .with_token_endpoint(
                format!("{token_base}/oauth/token"),
                "test-client".to_string(),
            );
        let value: serde_json::Value = client
            .auth_get("/characters/99/skills/", 99)
            .await
            .expect("auth get");
        assert_eq!(value["total_sp"], 10);
        let refresh_body = token_request.await.expect("refresh captured");
        assert!(refresh_body.contains("grant_type=refresh_token"));
        let esi_req = esi_request.await.expect("esi captured");
        assert!(esi_req.contains("Bearer fresh-access"));
        let persisted = store.load(99).expect("load").expect("persisted");
        assert_eq!(persisted.access.as_str(), "fresh-access");
        assert_eq!(persisted.refresh.as_str(), "fresh-refresh");
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
}
