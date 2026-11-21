//! Token storage: OS keyring primary, `0600` JSON file fallback. The token
//! newtypes redact in `Debug` so tokens can never reach a log line. Token
//! values are only written to the keyring entry or the fallback file; they
//! are never logged.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;

use serde::{Deserialize, Serialize};

use crate::auth::oauth::{expiry_for_verified, needs_refresh, JwtClaims, TokenResponse};
use crate::config::{now_unix, EveConfig};
use crate::error::{AppError, AppResult};

#[derive(Clone, Default, PartialEq, Eq)]
pub struct AccessToken(pub String);

impl AccessToken {
    pub fn as_str(&self) -> &str {
        &self.0
    }
    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }
}

impl std::fmt::Debug for AccessToken {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("AccessToken(<redacted>)")
    }
}

#[derive(Clone, Default, PartialEq, Eq)]
pub struct RefreshToken(pub String);

impl RefreshToken {
    pub fn as_str(&self) -> &str {
        &self.0
    }
    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }
}

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

impl StoredTokens {
    /// Build stored tokens from a token response whose access token has
    /// already been signature-verified; expiry comes from the verified
    /// claims, never from an unverified re-parse.
    pub fn from_token_response(
        character_id: i64,
        response: &TokenResponse,
        claims: &JwtClaims,
    ) -> Self {
        tracing::debug!("[AUTH] building StoredTokens character_id={}", character_id);
        Self {
            character_id,
            access: AccessToken(response.access_token.clone()),
            refresh: RefreshToken(response.refresh_token.clone()),
            expires_at_unix: expiry_for_verified(response, claims),
        }
    }

    /// Merge a refresh response whose access token has already been
    /// signature-verified: EVE rotates refresh tokens, but keep the
    /// old one if a response ever omits the field. Expiry comes from
    /// the verified claims.
    pub fn apply_refresh(&mut self, response: &TokenResponse, claims: &JwtClaims) {
        tracing::debug!(
            "[AUTH] applying refreshed tokens character_id={}",
            self.character_id
        );
        self.access = AccessToken(response.access_token.clone());
        if !response.refresh_token.is_empty() {
            self.refresh = RefreshToken(response.refresh_token.clone());
        }
        self.expires_at_unix = expiry_for_verified(response, claims);
    }

    pub fn needs_refresh_at(&self, now_unix_secs: i64) -> bool {
        self.access.is_empty() || needs_refresh(self.expires_at_unix, now_unix_secs)
    }

    pub fn needs_refresh_now(&self) -> bool {
        self.needs_refresh_at(now_unix())
    }
}

/// On-disk / keyring payload. Field names are explicit; values are secrets.
#[derive(Clone, Serialize, Deserialize)]
struct TokenPayload {
    access_token: String,
    refresh_token: String,
    expires_at_unix: i64,
}

impl From<&StoredTokens> for TokenPayload {
    fn from(t: &StoredTokens) -> Self {
        Self {
            access_token: t.access.0.clone(),
            refresh_token: t.refresh.0.clone(),
            expires_at_unix: t.expires_at_unix,
        }
    }
}

impl TokenPayload {
    fn into_stored(self, character_id: i64) -> StoredTokens {
        StoredTokens {
            character_id,
            access: AccessToken(self.access_token),
            refresh: RefreshToken(self.refresh_token),
            expires_at_unix: self.expires_at_unix,
        }
    }
}

pub struct TokenStore {
    pub fallback_path: PathBuf,
    use_keyring: bool,
    file_lock: Mutex<()>,
}

impl TokenStore {
    pub fn new(app_data_dir: PathBuf) -> Self {
        let fallback_path = app_data_dir.join(EveConfig::TOKEN_FILE_FILENAME);
        tracing::debug!(
            "[AUTH] TokenStore::new fallback={}",
            fallback_path.display()
        );
        Self {
            fallback_path,
            use_keyring: true,
            file_lock: Mutex::new(()),
        }
    }

    /// Store that skips the OS keyring (tests, headless hosts).
    pub fn file_only(fallback_path: PathBuf) -> Self {
        tracing::debug!(
            "[AUTH] TokenStore::file_only path={}",
            fallback_path.display()
        );
        Self {
            fallback_path,
            use_keyring: false,
            file_lock: Mutex::new(()),
        }
    }

    pub fn keyring_service() -> &'static str {
        EveConfig::KEYRING_SERVICE
    }

    fn keyring_user(character_id: i64) -> String {
        character_id.to_string()
    }

    pub fn save(&self, tokens: &StoredTokens) -> AppResult<()> {
        tracing::debug!(
            "[AUTH] TokenStore::save character_id={}",
            tokens.character_id
        );
        let payload = TokenPayload::from(tokens);
        let text = serde_json::to_string(&payload)?;
        if self.use_keyring {
            match keyring::Entry::new(
                Self::keyring_service(),
                &Self::keyring_user(tokens.character_id),
            ) {
                Ok(entry) => match entry.set_password(&text) {
                    Ok(()) => {
                        tracing::info!(
                            "[AUTH] tokens saved to keyring character_id={}",
                            tokens.character_id
                        );
                        return Ok(());
                    }
                    Err(e) => {
                        tracing::warn!("[AUTH] keyring save failed, using file fallback: {}", e);
                    }
                },
                Err(e) => {
                    tracing::warn!("[AUTH] keyring unavailable, using file fallback: {}", e);
                }
            }
        }
        self.save_to_file(tokens.character_id, &payload)
    }

    pub fn load(&self, character_id: i64) -> AppResult<Option<StoredTokens>> {
        tracing::debug!("[AUTH] TokenStore::load character_id={}", character_id);
        if self.use_keyring {
            if let Ok(entry) =
                keyring::Entry::new(Self::keyring_service(), &Self::keyring_user(character_id))
            {
                match entry.get_password() {
                    Ok(text) => {
                        if let Ok(payload) = serde_json::from_str::<TokenPayload>(&text) {
                            tracing::debug!(
                                "[AUTH] tokens loaded from keyring character_id={}",
                                character_id
                            );
                            return Ok(Some(payload.into_stored(character_id)));
                        }
                        tracing::warn!(
                            "[AUTH] keyring payload undecodable character_id={}",
                            character_id
                        );
                    }
                    Err(keyring::Error::NoEntry) => {}
                    Err(e) => {
                        tracing::warn!("[AUTH] keyring load failed, trying file fallback: {}", e);
                    }
                }
            }
        }
        self.load_from_file(character_id)
    }

    pub fn delete(&self, character_id: i64) -> AppResult<()> {
        tracing::debug!("[AUTH] TokenStore::delete character_id={}", character_id);
        if self.use_keyring {
            if let Ok(entry) =
                keyring::Entry::new(Self::keyring_service(), &Self::keyring_user(character_id))
            {
                match entry.delete_credential() {
                    Ok(()) => tracing::info!(
                        "[AUTH] tokens deleted from keyring character_id={}",
                        character_id
                    ),
                    Err(keyring::Error::NoEntry) => {}
                    Err(e) => tracing::warn!("[AUTH] keyring delete failed: {}", e),
                }
            }
        }
        let _guard = self
            .file_lock
            .lock()
            .unwrap_or_else(|poison| poison.into_inner());
        let mut map = self.read_file_map()?;
        if map.remove(&character_id.to_string()).is_some() {
            self.write_file_map(&map)?;
            tracing::info!(
                "[AUTH] tokens deleted from fallback file character_id={}",
                character_id
            );
        }
        Ok(())
    }

    /// Character IDs present in the fallback file. Keyring entries cannot be
    /// enumerated portably, so keyring-only installs report via `load`.
    pub fn file_character_ids(&self) -> AppResult<Vec<i64>> {
        tracing::debug!("[AUTH] TokenStore::file_character_ids");
        let _guard = self
            .file_lock
            .lock()
            .unwrap_or_else(|poison| poison.into_inner());
        let map = self.read_file_map()?;
        let mut ids: Vec<i64> = map.keys().filter_map(|k| k.parse::<i64>().ok()).collect();
        ids.sort_unstable();
        Ok(ids)
    }

    fn save_to_file(&self, character_id: i64, payload: &TokenPayload) -> AppResult<()> {
        let _guard = self
            .file_lock
            .lock()
            .unwrap_or_else(|poison| poison.into_inner());
        let mut map = self.read_file_map()?;
        map.insert(character_id.to_string(), payload.clone());
        self.write_file_map(&map)?;
        tracing::info!(
            "[AUTH] tokens saved to fallback file character_id={}",
            character_id
        );
        Ok(())
    }

    fn load_from_file(&self, character_id: i64) -> AppResult<Option<StoredTokens>> {
        let _guard = self
            .file_lock
            .lock()
            .unwrap_or_else(|poison| poison.into_inner());
        let map = self.read_file_map()?;
        Ok(map
            .get(&character_id.to_string())
            .cloned()
            .map(|p| p.into_stored(character_id)))
    }

    fn read_file_map(&self) -> AppResult<BTreeMap<String, TokenPayload>> {
        if !self.fallback_path.exists() {
            return Ok(BTreeMap::new());
        }
        let text = std::fs::read_to_string(&self.fallback_path)?;
        if text.trim().is_empty() {
            return Ok(BTreeMap::new());
        }
        serde_json::from_str(&text).map_err(|e| {
            tracing::warn!("[AUTH] fallback token file undecodable: {}", e);
            AppError::from(e)
        })
    }

    fn write_file_map(&self, map: &BTreeMap<String, TokenPayload>) -> AppResult<()> {
        if let Some(parent) = self.fallback_path.parent() {
            if !parent.as_os_str().is_empty() {
                std::fs::create_dir_all(parent)?;
            }
        }
        let text = serde_json::to_string_pretty(map)?;
        write_private_file(&self.fallback_path, &text)?;
        Ok(())
    }
}

/// Atomically write with owner-only permissions (0600 on Unix) via a unique
/// sibling temp file and rename so concurrent crashes never leave a truncated file.
fn write_private_file(path: &Path, contents: &str) -> AppResult<()> {
    use std::io::Write;
    static TMP_COUNTER: AtomicU64 = AtomicU64::new(0);

    let parent = path
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let base_name = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("tokens");
    let seq = TMP_COUNTER.fetch_add(1, Ordering::Relaxed);
    let tmp_path = parent.join(format!(".{}.{}.{}.tmp", base_name, std::process::id(), seq));

    let mut options = std::fs::OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }

    let write_res = (|| -> AppResult<()> {
        let mut file = options.open(&tmp_path)?;
        file.write_all(contents.as_bytes())?;
        file.sync_all()?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&tmp_path, std::fs::Permissions::from_mode(0o600))?;
        }
        Ok(())
    })();
    if let Err(e) = write_res {
        let _ = std::fs::remove_file(&tmp_path);
        return Err(e);
    }
    if let Err(e) = std::fs::rename(&tmp_path, path) {
        let _ = std::fs::remove_file(&tmp_path);
        return Err(e.into());
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample(id: i64) -> StoredTokens {
        StoredTokens {
            character_id: id,
            access: AccessToken("secret-access-value".to_string()),
            refresh: RefreshToken("secret-refresh-value".to_string()),
            expires_at_unix: 4_000_000_000,
        }
    }

    #[test]
    fn token_debug_never_contains_value() {
        let tokens = sample(1);
        let rendered = format!("{tokens:?} {:?} {:?}", tokens.access, tokens.refresh);
        assert!(!rendered.contains("secret-access-value"));
        assert!(!rendered.contains("secret-refresh-value"));
        assert!(rendered.contains("redacted"));
    }

    #[test]
    fn file_roundtrip_save_load_delete() {
        let dir = tempfile::tempdir().expect("tempdir");
        let store = TokenStore::file_only(dir.path().join("tokens.json"));
        assert!(store.load(42).expect("load empty").is_none());
        store.save(&sample(42)).expect("save");
        let loaded = store.load(42).expect("load").expect("present");
        assert_eq!(loaded.access.as_str(), "secret-access-value");
        assert_eq!(loaded.expires_at_unix, 4_000_000_000);
        assert_eq!(store.file_character_ids().expect("ids"), vec![42]);
        store.delete(42).expect("delete");
        assert!(store.load(42).expect("load gone").is_none());
    }

    #[cfg(unix)]
    #[test]
    fn fallback_file_is_0600() {
        use std::os::unix::fs::PermissionsExt;
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("tokens.json");
        TokenStore::file_only(path.clone())
            .save(&sample(7))
            .expect("save");
        let mode = std::fs::metadata(&path).expect("meta").permissions().mode() & 0o777;
        assert_eq!(mode, 0o600);
    }

    #[test]
    fn apply_refresh_keeps_old_refresh_when_omitted() {
        let mut tokens = sample(3);
        let response = TokenResponse {
            access_token: "new-access".to_string(),
            refresh_token: String::new(),
            expires_in: 1199,
            token_type: "Bearer".to_string(),
        };
        let claims = JwtClaims {
            exp: now_unix() + 1199,
            ..JwtClaims::default()
        };
        tokens.apply_refresh(&response, &claims);
        assert_eq!(tokens.access.as_str(), "new-access");
        assert_eq!(tokens.refresh.as_str(), "secret-refresh-value");
        assert_eq!(tokens.expires_at_unix, claims.exp);
        assert!(!tokens.needs_refresh_now());
    }

    #[test]
    fn concurrent_file_saves_preserve_all_characters() {
        use std::sync::Arc;
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("tokens.json");
        let store = Arc::new(TokenStore::file_only(path.clone()));
        let mut handles = Vec::new();
        for id in 101..=108 {
            let store = store.clone();
            handles.push(std::thread::spawn(move || {
                store.save(&sample(id)).expect("concurrent save succeeds");
            }));
        }
        for handle in handles {
            handle.join().expect("thread finished");
        }
        let ids = store.file_character_ids().expect("ids");
        assert_eq!(ids, vec![101, 102, 103, 104, 105, 106, 107, 108]);
        for id in 101..=108 {
            assert!(store.load(id).expect("load").is_some());
        }
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = std::fs::metadata(&path).expect("meta").permissions().mode() & 0o777;
            assert_eq!(mode, 0o600);
        }
    }
}
