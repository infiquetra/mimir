//! Localhost OAuth callback listener (`127.0.0.1:54321/callback`), ported
//! from `lib/core/auth/oauth_callback_server.dart`. Serves a success page
//! to the browser and hands the code/state back to the caller.

use std::net::SocketAddr;
use std::time::Duration;

use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::sync::Mutex;

use crate::config::EveConfig;
use crate::error::AuthError;

/// Query parameters returned by the SSO redirect. `Debug` redacts the
/// authorization code and CSRF state so a stray `{:?}` log cannot leak them.
#[derive(Clone, Default)]
pub struct CallbackParams {
    pub code: String,
    pub state: String,
    pub error: Option<String>,
    pub error_description: Option<String>,
}

impl std::fmt::Debug for CallbackParams {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("CallbackParams(<redacted>)")
    }
}

impl CallbackParams {
    /// Parse from a query string (the part after `?`).
    pub fn from_query(query: &str) -> Self {
        let mut params = CallbackParams::default();
        for (key, value) in url::form_urlencoded::parse(query.as_bytes()) {
            match key.as_ref() {
                "code" => params.code = value.into_owned(),
                "state" => params.state = value.into_owned(),
                "error" => params.error = Some(value.into_owned()),
                "error_description" => params.error_description = Some(value.into_owned()),
                _ => {}
            }
        }
        params
    }

    /// Convert to the validated outcome the OAuth flow consumes.
    pub fn into_result(self, expected_state: &str) -> Result<String, AuthError> {
        if let Some(error) = self.error {
            let description = self
                .error_description
                .unwrap_or_else(|| "Unknown error".to_string());
            tracing::warn!("[AUTH] SSO callback carried error={}", error);
            return Err(AuthError::Denied(format!("{error} - {description}")));
        }
        if self.state != expected_state {
            tracing::warn!("[AUTH] callback state mismatch");
            return Err(AuthError::StateMismatch);
        }
        if self.code.is_empty() {
            return Err(AuthError::MissingCode);
        }
        Ok(self.code)
    }
}

pub struct CallbackServer {
    pub bind_addr: String,
    listener: Mutex<Option<TcpListener>>,
}

impl Default for CallbackServer {
    fn default() -> Self {
        Self {
            bind_addr: EveConfig::CALLBACK_BIND.to_string(),
            listener: Mutex::new(None),
        }
    }
}

impl CallbackServer {
    pub fn new() -> Self {
        tracing::debug!(
            "[AUTH] CallbackServer::new bind={}",
            EveConfig::CALLBACK_BIND
        );
        Self::default()
    }

    pub fn with_bind_addr(bind_addr: impl Into<String>) -> Self {
        let bind_addr = bind_addr.into();
        tracing::debug!("[AUTH] CallbackServer::with_bind_addr bind={}", bind_addr);
        Self {
            bind_addr,
            listener: Mutex::new(None),
        }
    }

    pub fn bind_addr(&self) -> &str {
        &self.bind_addr
    }

    /// Success HTML served to the browser after the redirect lands.
    pub fn success_html() -> &'static str {
        "<!DOCTYPE html><html><head><title>Authorization Successful - Mimir</title></head>\
         <body><h1>Authenticated with Mimir Successfully</h1>\
         <p>You can now close this page.</p></body></html>"
    }

    pub fn failure_html() -> &'static str {
        "<!DOCTYPE html><html><head><title>Authorization Failed - Mimir</title></head>\
         <body><h1>Authorization Failed</h1>\
         <p>Return to Mimir and try again.</p></body></html>"
    }

    /// Bind the listener synchronously inside a Tokio runtime handle so port
    /// conflicts fail immediately before opening the system browser.
    pub fn start_sync(&self, handle: &tokio::runtime::Handle) -> Result<SocketAddr, AuthError> {
        let mut guard = self
            .listener
            .try_lock()
            .map_err(|_| AuthError::Callback("listener locked".to_string()))?;
        if let Some(listener) = guard.as_ref() {
            return listener
                .local_addr()
                .map_err(|e| AuthError::Callback(e.to_string()));
        }
        let std_listener = std::net::TcpListener::bind(&self.bind_addr)
            .map_err(|e| AuthError::Callback(format!("bind {}: {}", self.bind_addr, e)))?;
        std_listener
            .set_nonblocking(true)
            .map_err(|e| AuthError::Callback(e.to_string()))?;
        let _enter = handle.enter();
        let listener =
            TcpListener::from_std(std_listener).map_err(|e| AuthError::Callback(e.to_string()))?;
        let addr = listener
            .local_addr()
            .map_err(|e| AuthError::Callback(e.to_string()))?;
        tracing::info!("[AUTH] callback listener bound addr={}", addr);
        *guard = Some(listener);
        Ok(addr)
    }

    /// Bind the listener now so callers can read the actual address (tests
    /// bind port 0). Idempotent.
    pub async fn start(&self) -> Result<SocketAddr, AuthError> {
        let mut guard = self.listener.lock().await;
        if let Some(listener) = guard.as_ref() {
            return listener
                .local_addr()
                .map_err(|e| AuthError::Callback(e.to_string()));
        }
        let listener = TcpListener::bind(&self.bind_addr)
            .await
            .map_err(|e| AuthError::Callback(format!("bind {}: {}", self.bind_addr, e)))?;
        let addr = listener
            .local_addr()
            .map_err(|e| AuthError::Callback(e.to_string()))?;
        tracing::info!("[AUTH] callback listener bound addr={}", addr);
        *guard = Some(listener);
        Ok(addr)
    }

    pub async fn wait_for_callback(&self) -> Result<CallbackParams, AuthError> {
        self.wait_for_callback_timeout(Duration::from_secs(EveConfig::CALLBACK_TIMEOUT_SECS))
            .await
    }

    /// Accept requests until `/callback` arrives (other paths get 404, like
    /// the Flutter server's favicon traffic) or the timeout elapses.
    pub async fn wait_for_callback_timeout(
        &self,
        timeout: Duration,
    ) -> Result<CallbackParams, AuthError> {
        tracing::debug!("[AUTH] wait_for_callback bind={}", self.bind_addr);
        self.start().await?;
        let deadline = tokio::time::Instant::now() + timeout;
        loop {
            let accepted = {
                let guard = self.listener.lock().await;
                let listener = guard
                    .as_ref()
                    .ok_or_else(|| AuthError::Callback("listener not started".to_string()))?;
                tokio::time::timeout_at(deadline, listener.accept()).await
            };
            let (mut socket, peer) = match accepted {
                Ok(Ok(pair)) => pair,
                Ok(Err(e)) => return Err(AuthError::Callback(format!("accept: {e}"))),
                Err(_) => {
                    tracing::warn!("[AUTH] callback wait timed out");
                    return Err(AuthError::CallbackTimeout);
                }
            };
            tracing::debug!("[AUTH] callback connection peer={}", peer);
            let mut buffer = [0u8; 8192];
            let mut total = 0usize;
            let read_deadline = deadline.min(tokio::time::Instant::now() + Duration::from_secs(5));
            let mut read_failed = false;
            let mut timed_out_overall = false;
            loop {
                let read =
                    tokio::time::timeout_at(read_deadline, socket.read(&mut buffer[total..])).await;
                match read {
                    Ok(Ok(0)) => break,
                    Ok(Ok(n)) => {
                        total += n;
                        if buffer[..total].windows(4).any(|w| w == b"\r\n\r\n")
                            || total >= buffer.len()
                        {
                            break;
                        }
                    }
                    Ok(Err(e)) => {
                        tracing::debug!(
                            "[AUTH] ignoring transient callback peer read error peer={} error={}",
                            peer,
                            e
                        );
                        read_failed = true;
                        break;
                    }
                    Err(_) => {
                        if tokio::time::Instant::now() >= deadline {
                            timed_out_overall = true;
                        } else {
                            tracing::debug!(
                                "[AUTH] callback peer read timed out before overall deadline peer={}",
                                peer
                            );
                        }
                        read_failed = true;
                        break;
                    }
                }
            }
            if timed_out_overall {
                tracing::warn!("[AUTH] callback wait timed out");
                return Err(AuthError::CallbackTimeout);
            }
            if read_failed || total == 0 {
                continue;
            }
            let request = String::from_utf8_lossy(&buffer[..total]);
            let target = request
                .lines()
                .next()
                .and_then(|line| line.split_whitespace().nth(1))
                .unwrap_or("");
            let callback_query = if target == "/callback" {
                Some("")
            } else {
                target.strip_prefix("/callback?")
            };
            if let Some(query) = callback_query {
                let params = CallbackParams::from_query(query);
                let (status, body) = if params.error.is_some() {
                    (200, Self::failure_html())
                } else {
                    (200, Self::success_html())
                };
                write_response(&mut socket, status, body).await;
                tracing::info!(
                    "[AUTH] callback received has_code={}",
                    !params.code.is_empty()
                );
                return Ok(params);
            }
            write_response(&mut socket, 404, "Not found").await;
        }
    }
}

async fn write_response(socket: &mut tokio::net::TcpStream, status: u16, body: &str) {
    let reason = if status == 200 { "OK" } else { "Not Found" };
    let payload = format!(
        "HTTP/1.1 {status} {reason}\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    let _ = socket.write_all(payload.as_bytes()).await;
    let _ = socket.flush().await;
    let _ = socket.shutdown().await;
}

/// Parse a callback query string without starting a server (test helper and
/// the seam for any future deep-link path).
pub fn parse_callback_query(query: &str) -> CallbackParams {
    CallbackParams::from_query(query)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn query_parsing_and_validation() {
        let params = CallbackParams::from_query("code=abc123&state=xyz");
        assert_eq!(params.clone().into_result("xyz").expect("code"), "abc123");
        assert!(matches!(
            params.into_result("nope"),
            Err(AuthError::StateMismatch)
        ));
        let denied = CallbackParams::from_query("error=access_denied&state=xyz");
        assert!(matches!(
            denied.into_result("xyz"),
            Err(AuthError::Denied(_))
        ));
    }

    #[tokio::test]
    async fn listener_roundtrip_on_ephemeral_port() {
        let server = std::sync::Arc::new(CallbackServer::with_bind_addr("127.0.0.1:0"));
        let addr = server.start().await.expect("bind");
        let waiting = {
            let server = server.clone();
            tokio::spawn(async move {
                server
                    .wait_for_callback_timeout(Duration::from_secs(5))
                    .await
            })
        };
        let url = format!("http://{addr}/callback?code=testcode&state=teststate");
        let body = reqwest::get(&url)
            .await
            .expect("browser request")
            .text()
            .await
            .expect("page body");
        assert!(body.contains("Authenticated with Mimir"));
        let params = waiting.await.expect("task").expect("callback");
        assert_eq!(params.code, "testcode");
        assert_eq!(params.into_result("teststate").expect("code"), "testcode");
    }

    #[tokio::test]
    async fn listener_times_out_without_callback() {
        let server = CallbackServer::with_bind_addr("127.0.0.1:0");
        let result = server
            .wait_for_callback_timeout(Duration::from_millis(150))
            .await;
        assert!(matches!(result, Err(AuthError::CallbackTimeout)));
    }

    #[tokio::test]
    async fn listener_ignores_abrupt_drop_before_valid_callback() {
        let server = std::sync::Arc::new(CallbackServer::with_bind_addr("127.0.0.1:0"));
        let addr = server
            .start_sync(&tokio::runtime::Handle::current())
            .expect("sync bind");
        let waiting = {
            let server = server.clone();
            tokio::spawn(async move {
                server
                    .wait_for_callback_timeout(Duration::from_secs(5))
                    .await
            })
        };
        // Connect and drop immediately without sending bytes (like browser preconnect).
        let stream = tokio::net::TcpStream::connect(addr)
            .await
            .expect("preconnect");
        drop(stream);

        let url = format!("http://{addr}/callback?code=recovered&state=s1");
        let body = reqwest::get(&url)
            .await
            .expect("browser request")
            .text()
            .await
            .expect("page body");
        assert!(body.contains("Authenticated with Mimir"));
        let params = waiting.await.expect("task").expect("callback");
        assert_eq!(params.into_result("s1").expect("code"), "recovered");
    }

    #[tokio::test]
    async fn listener_handles_tcp_chunked_request() {
        let server = std::sync::Arc::new(CallbackServer::with_bind_addr("127.0.0.1:0"));
        let addr = server
            .start_sync(&tokio::runtime::Handle::current())
            .expect("sync bind");
        let waiting = {
            let server = server.clone();
            tokio::spawn(async move {
                server
                    .wait_for_callback_timeout(Duration::from_secs(5))
                    .await
            })
        };

        let mut stream = tokio::net::TcpStream::connect(addr).await.expect("connect");
        stream.write_all(b"GET /call").await.expect("first chunk");
        tokio::time::sleep(Duration::from_millis(25)).await;
        stream
            .write_all(b"back?code=chunked&state=s2 HTTP/1.1\r\nHost: localhost\r\n\r\n")
            .await
            .expect("second chunk");
        let mut resp = Vec::new();
        let _ = stream.read_to_end(&mut resp).await;
        assert!(String::from_utf8_lossy(&resp).contains("200 OK"));

        let params = waiting.await.expect("task").expect("callback");
        assert_eq!(params.into_result("s2").expect("code"), "chunked");
    }

    #[tokio::test]
    async fn listener_rejects_callback_prefix_lookalike() {
        let server = std::sync::Arc::new(CallbackServer::with_bind_addr("127.0.0.1:0"));
        let addr = server
            .start_sync(&tokio::runtime::Handle::current())
            .expect("sync bind");
        let waiting = {
            let server = server.clone();
            tokio::spawn(async move {
                server
                    .wait_for_callback_timeout(Duration::from_secs(5))
                    .await
            })
        };

        let lookalike = reqwest::get(format!("http://{addr}/callback.ico"))
            .await
            .expect("lookalike request");
        assert_eq!(lookalike.status(), 404);

        let valid = reqwest::get(format!("http://{addr}/callback?code=real&state=s3"))
            .await
            .expect("callback request");
        assert_eq!(valid.status(), 200);

        let params = waiting.await.expect("task").expect("callback");
        assert_eq!(params.into_result("s3").expect("code"), "real");
    }
}
