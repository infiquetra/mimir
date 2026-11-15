//! Port of `lib/core/config/eve_config.dart` (EVE SSO + ESI constants).

/// EVE Online API configuration. The client id is public per the OAuth2
/// PKCE flow (no client secret exists); it is carried over from Flutter.
pub struct EveConfig;

impl EveConfig {
    pub const ESI_BASE_URL: &str = "https://esi.evetech.net/latest";
    pub const IMAGE_SERVER_URL: &str = "https://images.evetech.net";
    pub const DATASOURCE: &str = "tranquility";

    pub const OAUTH_AUTHORIZE_URL: &str = "https://login.eveonline.com/v2/oauth/authorize";
    pub const OAUTH_TOKEN_URL: &str = "https://login.eveonline.com/v2/oauth/token";
    pub const OAUTH_REVOKE_URL: &str = "https://login.eveonline.com/v2/oauth/revoke";
    /// Rust uses the localhost callback only; the Flutter `eveauth-mimir://`
    /// deep-link path is dropped (see design decision table).
    pub const REDIRECT_URI: &str = "http://127.0.0.1:54321/callback";
    pub const CALLBACK_BIND: &str = "127.0.0.1:54321";
    pub const CLIENT_ID: &str = "43d0fef53e004c3e856ca3a716769125";

    /// Least-privilege first-auth scope set (design ADR-007 resolution).
    pub const FIRST_AUTH_SCOPES: &[&str] = &[
        "publicData",
        "esi-skills.read_skills.v1",
        "esi-skills.read_skillqueue.v1",
        "esi-wallet.read_character_wallet.v1",
        "esi-clones.read_implants.v1",
    ];

    pub const ACCESS_TOKEN_LIFETIME_SECS: i64 = 1199;
    pub const TOKEN_REFRESH_BUFFER_SECS: i64 = 60;
    pub const MAX_ERRORS_PER_MINUTE: u32 = 100;
    pub const DEFAULT_TIMEOUT_MS: u64 = 30_000;

    pub const SKILL_QUEUE_REFRESH_SECS: u64 = 300;
    pub const WALLET_REFRESH_SECS: u64 = 600;
    pub const CHARACTER_REFRESH_SECS: u64 = 21_600;

    pub const DB_FILENAME: &str = "mimir.db";
    pub const TOKEN_FILE_FILENAME: &str = "tokens.json";

    pub fn first_auth_scopes_string() -> String {
        Self::FIRST_AUTH_SCOPES.join(" ")
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
