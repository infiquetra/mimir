//! Token storage: OS keyring primary, `0600` file fallback. The token
//! newtypes redact in `Debug` so tokens can never reach a log line.

use std::path::PathBuf;

use crate::config::EveConfig;
use crate::error::AppResult;

#[derive(Clone, Default)]
pub struct AccessToken(pub String);

impl std::fmt::Debug for AccessToken {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("AccessToken(<redacted>)")
    }
}

#[derive(Clone, Default)]
pub struct RefreshToken(pub String);

impl std::fmt::Debug for RefreshToken {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("RefreshToken(<redacted>)")
    }
}

#[derive(Clone, Default)]
pub struct StoredTokens {
    pub character_id: i64,
    pub access: AccessToken,
    pub refresh: RefreshToken,
    pub expires_at_unix: i64,
}

impl std::fmt::Debug for StoredTokens {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("StoredTokens")
            .field("character_id", &self.character_id)
            .field("access", &"<redacted>")
            .field("refresh", &"<redacted>")
            .field("expires_at_unix", &self.expires_at_unix)
            .finish()
    }
}

pub struct TokenStore {
    pub fallback_path: PathBuf,
}

impl TokenStore {
    pub fn new(app_data_dir: PathBuf) -> Self {
        let fallback_path = app_data_dir.join(EveConfig::TOKEN_FILE_FILENAME);
        tracing::debug!(
            "[AUTH] TokenStore::new fallback={}",
            fallback_path.display()
        );
        Self { fallback_path }
    }

    pub fn keyring_service() -> &'static str {
        "mimir"
    }

    pub fn save(&self, _tokens: &StoredTokens) -> AppResult<()> {
        tracing::debug!("[AUTH] TokenStore::save entry (stub)");
        Ok(())
    }

    pub fn load(&self, character_id: i64) -> AppResult<Option<StoredTokens>> {
        tracing::debug!(
            "[AUTH] TokenStore::load character_id={} (stub)",
            character_id
        );
        Ok(None)
    }

    pub fn delete(&self, character_id: i64) -> AppResult<()> {
        tracing::debug!(
            "[AUTH] TokenStore::delete character_id={} (stub)",
            character_id
        );
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn token_debug_never_contains_value() {
        let tokens = StoredTokens {
            character_id: 1,
            access: AccessToken("secret-access-value".to_string()),
            refresh: RefreshToken("secret-refresh-value".to_string()),
            expires_at_unix: 0,
        };
        let rendered = format!("{tokens:?}");
        assert!(!rendered.contains("secret-access-value"));
        assert!(!rendered.contains("secret-refresh-value"));
        assert!(rendered.contains("redacted"));
    }
}
