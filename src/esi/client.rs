//! ESI HTTP client (`/latest` + tranquility, Bearer auth, error-limit
//! tracking). Request execution is stubbed for F1 wiring.

use std::time::Duration;

use crate::config::EveConfig;
use crate::error::{AppError, AppResult};

pub struct EsiClient {
    http: reqwest::Client,
    base_url: String,
    error_limit_remain: u32,
    error_limit_reset_secs: u32,
}

impl EsiClient {
    pub fn new() -> AppResult<Self> {
        tracing::info!("[ESI] creating ESI client base={}", EveConfig::ESI_BASE_URL);
        let http = reqwest::Client::builder()
            .timeout(Duration::from_millis(EveConfig::DEFAULT_TIMEOUT_MS))
            .build()
            .map_err(|e| AppError::Message(e.to_string()))?;
        Ok(Self {
            http,
            base_url: EveConfig::ESI_BASE_URL.to_string(),
            error_limit_remain: EveConfig::MAX_ERRORS_PER_MINUTE,
            error_limit_reset_secs: 0,
        })
    }

    pub fn http(&self) -> &reqwest::Client {
        &self.http
    }

    pub fn base_url(&self) -> &str {
        &self.base_url
    }

    pub fn error_limit_remain(&self) -> u32 {
        self.error_limit_remain
    }

    pub fn error_limit_reset_secs(&self) -> u32 {
        self.error_limit_reset_secs
    }

    /// Parse `X-ESI-Error-Limit-Remain` / `-Reset` from response headers.
    pub fn update_error_limit(&mut self, remain: u32, reset_secs: u32) {
        tracing::debug!("[ESI] error limit remain={} reset={}s", remain, reset_secs);
        self.error_limit_remain = remain;
        self.error_limit_reset_secs = reset_secs;
    }
}

impl Default for EsiClient {
    fn default() -> Self {
        Self {
            http: reqwest::Client::new(),
            base_url: EveConfig::ESI_BASE_URL.to_string(),
            error_limit_remain: EveConfig::MAX_ERRORS_PER_MINUTE,
            error_limit_reset_secs: 0,
        }
    }
}
