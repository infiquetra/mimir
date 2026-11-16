//! Port of `lib/core/config/eve_config.dart` (EVE SSO + ESI constants).

/// EVE Online API configuration. The client id is public per the OAuth2
/// PKCE flow (no client secret exists); it is carried over from Flutter.
pub struct EveConfig;

impl EveConfig {
    pub const ESI_BASE_URL: &str = "https://esi.evetech.net/latest";
    pub const IMAGE_SERVER_URL: &str = "https://images.evetech.net";
    pub const DATASOURCE: &str = "tranquility";
    pub const USER_AGENT: &str = "mimir/0.1.0 (EVE Online companion; rust)";

    pub const OAUTH_AUTHORIZE_URL: &str = "https://login.eveonline.com/v2/oauth/authorize";
    pub const OAUTH_TOKEN_URL: &str = "https://login.eveonline.com/v2/oauth/token";
    pub const OAUTH_REVOKE_URL: &str = "https://login.eveonline.com/v2/oauth/revoke";
    pub const OAUTH_HOST: &str = "login.eveonline.com";
    /// Rust uses the localhost callback only; the Flutter `eveauth-mimir://`
    /// deep-link path is dropped (see design decision table).
    pub const REDIRECT_URI: &str = "http://127.0.0.1:54321/callback";
    pub const CALLBACK_BIND: &str = "127.0.0.1:54321";
    pub const CALLBACK_PORT: u16 = 54321;
    pub const CALLBACK_TIMEOUT_SECS: u64 = 300;
    pub const CLIENT_ID: &str = "43d0fef53e004c3e856ca3a716769125";

    /// Least-privilege first-auth scope set (design ADR-007 resolution).
    pub const FIRST_AUTH_SCOPES: &[&str] = &[
        "publicData",
        "esi-skills.read_skills.v1",
        "esi-skills.read_skillqueue.v1",
        "esi-wallet.read_character_wallet.v1",
        "esi-clones.read_implants.v1",
    ];

    /// Phase-2 fleet scopes (progressive step-up, Flutter parity).
    pub const FLEET_SCOPES: &[&str] = &[
        "esi-location.read_location.v1",
        "esi-location.read_ship_type.v1",
        "esi-location.read_online.v1",
    ];

    /// Phase-3 character-screen scopes (progressive step-up).
    pub const CHARACTER_SCOPES: &[&str] = &[
        "esi-clones.read_clones.v1",
        "esi-clones.read_implants.v1",
        "esi-characters.read_standings.v1",
    ];

    /// Phase-4 enhanced-wallet scopes (progressive step-up).
    pub const WALLET_SCOPES: &[&str] = &[
        "esi-wallet.read_character_wallet.v1",
        "esi-assets.read_assets.v1",
        "esi-characters.read_loyalty.v1",
    ];

    /// Assets step-up scopes: granted after first sign-in via the
    /// step-up OAuth flow, never at first authorization.
    pub const ASSETS_SCOPES: &[&str] = &["esi-assets.read_assets.v1"];

    /// Scopes the Phase-1 Rust endpoint set actually needs, beyond the
    /// first-auth set (location/ship/online/clones/standings/loyalty).
    pub const PHASE1_ENDPOINT_SCOPES: &[&str] = &[
        "publicData",
        "esi-skills.read_skills.v1",
        "esi-skills.read_skillqueue.v1",
        "esi-wallet.read_character_wallet.v1",
        "esi-clones.read_implants.v1",
        "esi-clones.read_clones.v1",
        "esi-characters.read_standings.v1",
        "esi-characters.read_loyalty.v1",
        "esi-location.read_location.v1",
        "esi-location.read_ship_type.v1",
        "esi-location.read_online.v1",
    ];

    pub const ACCESS_TOKEN_LIFETIME_SECS: i64 = 1199;
    pub const TOKEN_REFRESH_BUFFER_SECS: i64 = 60;
    pub const MAX_ERRORS_PER_MINUTE: u32 = 100;
    /// Flutter `isNearRateLimit` threshold (`errorLimitRemain < 20`).
    pub const ERROR_LIMIT_WARN_REMAIN: u32 = 20;
    pub const DEFAULT_TIMEOUT_MS: u64 = 30_000;

    pub const SKILL_QUEUE_REFRESH_SECS: u64 = 300;
    pub const WALLET_REFRESH_SECS: u64 = 600;
    pub const CHARACTER_REFRESH_SECS: u64 = 21_600;

    pub const DB_FILENAME: &str = "mimir.db";
    pub const TOKEN_FILE_FILENAME: &str = "tokens.json";
    pub const KEYRING_SERVICE: &str = "mimir";

    pub const SDE_MANIFEST_URL: &str =
        "https://github.com/infiquetra/mimir-sde/releases/latest/download/manifest.json";
    pub const SDE_DB_FILENAME: &str = "sde.sqlite";

    pub fn first_auth_scopes_string() -> String {
        Self::FIRST_AUTH_SCOPES.join(" ")
    }

    pub fn scopes_string(scopes: &[&str]) -> String {
        scopes.join(" ")
    }

    pub fn portrait_url(character_id: i64, size: u32) -> String {
        format!(
            "{}/characters/{}/portrait?size={}",
            Self::IMAGE_SERVER_URL,
            character_id,
            size
        )
    }
}

/// Current Unix time in seconds (0 if the system clock is before 1970).
pub fn now_unix() -> i64 {
    match std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH) {
        Ok(d) => d.as_secs() as i64,
        Err(_) => 0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn first_auth_scopes_match_least_privilege_set() {
        let s = EveConfig::first_auth_scopes_string();
        assert!(s.contains("esi-skills.read_skills.v1"));
        assert!(s.contains("esi-wallet.read_character_wallet.v1"));
        assert!(!s.contains("esi-assets"));
    }

    #[test]
    fn assets_scopes_is_the_single_stepup_scope() {
        assert_eq!(EveConfig::ASSETS_SCOPES, ["esi-assets.read_assets.v1"]);
        assert!(!EveConfig::FIRST_AUTH_SCOPES.contains(&"esi-assets.read_assets.v1"));
    }

    #[test]
    fn portrait_url_shape() {
        assert_eq!(
            EveConfig::portrait_url(123, 128),
            "https://images.evetech.net/characters/123/portrait?size=128"
        );
    }

    #[test]
    fn now_unix_is_plausible() {
        assert!(now_unix() > 1_700_000_000);
    }
}
