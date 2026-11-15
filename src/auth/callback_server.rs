//! Localhost OAuth callback listener (`127.0.0.1:54321/callback`).

use crate::config::EveConfig;
use crate::error::AuthError;

/// Query parameters returned by the SSO redirect.
#[derive(Debug, Clone, Default)]
pub struct CallbackParams {
    pub code: String,
    pub state: String,
}

pub struct CallbackServer {
    pub bind_addr: String,
}

impl Default for CallbackServer {
    fn default() -> Self {
        Self {
            bind_addr: EveConfig::CALLBACK_BIND.to_string(),
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

    pub fn bind_addr(&self) -> &str {
        &self.bind_addr
    }

    /// Success HTML served to the browser after the redirect lands.
    pub fn success_html() -> &'static str {
        "<html><body><h1>Mimir login complete</h1><p>You can close this tab.</p></body></html>"
    }

    pub async fn wait_for_callback(&self) -> Result<CallbackParams, AuthError> {
        tracing::debug!("[AUTH] wait_for_callback entry (stub)");
        Err(AuthError::NotWired(
            "callback listener lands with F1".to_string(),
        ))
    }
}
