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
    /// SSO metadata document (provenance for OAUTH_JWKS_URL; not
    /// fetched at runtime in this slice — see JWT design J1).
    pub const OAUTH_METADATA_URL: &str =
        "https://login.eveonline.com/.well-known/oauth-authorization-server";
    /// JWKS for EVE SSO access-token signatures, as linked from
    /// OAUTH_METADATA_URL per CCP's JWT validation guide.
    pub const OAUTH_JWKS_URL: &str = "https://login.eveonline.com/oauth/jwks";
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

    /// Market step-up scopes: read the character's own open orders.
    /// Granted after first sign-in via step-up, never at first auth.
    /// Public regional orders and history need no scope at all.
    pub const MARKET_SCOPES: &[&str] = &["esi-markets.read_character_orders.v1"];

    /// Character-detail step-up scopes (clones, standings, and the
    /// location trio). Implants and attributes are already covered
    /// by FIRST_AUTH_SCOPES and are deliberately absent.
    pub const CHARACTER_DETAIL_SCOPES: &[&str] = &[
        "esi-clones.read_clones.v1",
        "esi-characters.read_standings.v1",
        "esi-location.read_location.v1",
        "esi-location.read_ship_type.v1",
        "esi-location.read_online.v1",
    ];

    /// Industry step-up scopes: read the character's industry jobs
    /// and blueprint library. Granted after first sign-in via
    /// step-up, never at first auth. Both scopes are required: the
    /// industry decision records that name only the jobs scope are
    /// incomplete and must not be copied (design section 2.3).
    pub const INDUSTRY_SCOPES: &[&str] = &[
        "esi-characters.read_blueprints.v1",
        "esi-industry.read_character_jobs.v1",
    ];

    /// Planetary Industry step-up scope: read the character's colonies
    /// and colony detail. Granted after first sign-in via step-up,
    /// never at first auth.
    pub const PLANETS_SCOPES: &[&str] = &["esi-planets.manage_planets.v1"];

    /// Saved-fittings read step-up scope: read the character's
    /// saved fittings. Granted after first sign-in via step-up,
    /// never at first auth. Reading never implies permission to
    /// change them; the write scope is its own group below.
    pub const FITTINGS_SCOPES: &[&str] = &["esi-fittings.read_fittings.v1"];

    /// Saved-fittings write step-up scope: save a fitting to a
    /// character's in-game list or delete one from it. Granted
    /// after first sign-in via step-up, never at first auth.
    /// Separate from FITTINGS_SCOPES: reading fittings must
    /// never imply permission to change them.
    pub const FITTINGS_WRITE_SCOPES: &[&str] = &["esi-fittings.write_fittings.v1"];

    /// Player-structure name step-up scope: look up a
    /// player-built structure's name with the active
    /// character's token. Granted after first sign-in via
    /// step-up, never at first auth.
    pub const STRUCTURE_SCOPES: &[&str] = &["esi-universe.read_structures.v1"];

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

    pub fn corporation_logo_url(corporation_id: i64, size: u32) -> String {
        format!(
            "{}/corporations/{}/logo?size={}",
            Self::IMAGE_SERVER_URL,
            corporation_id,
            size
        )
    }

    pub fn alliance_logo_url(alliance_id: i64, size: u32) -> String {
        format!(
            "{}/alliances/{}/logo?size={}",
            Self::IMAGE_SERVER_URL,
            alliance_id,
            size
        )
    }

    /// Faction logo URL. Factions are served by the corporations
    /// endpoint in the image server (the `FactionLogo` precedent);
    /// the helper name states the entity, the path states the
    /// verified endpoint.
    pub fn faction_logo_url(faction_id: i64, size: u32) -> String {
        format!(
            "{}/corporations/{}/logo?size={}",
            Self::IMAGE_SERVER_URL,
            faction_id,
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
    fn market_scopes_is_the_single_stepup_scope() {
        assert_eq!(
            EveConfig::MARKET_SCOPES,
            ["esi-markets.read_character_orders.v1"]
        );
        assert!(!EveConfig::FIRST_AUTH_SCOPES.contains(&"esi-markets.read_character_orders.v1"));
    }

    #[test]
    fn character_detail_scopes_are_the_five_stepup_scopes() {
        assert_eq!(
            EveConfig::CHARACTER_DETAIL_SCOPES,
            [
                "esi-clones.read_clones.v1",
                "esi-characters.read_standings.v1",
                "esi-location.read_location.v1",
                "esi-location.read_ship_type.v1",
                "esi-location.read_online.v1",
            ]
        );
        assert!(
            !EveConfig::CHARACTER_DETAIL_SCOPES.contains(&"esi-clones.read_implants.v1"),
            "implants is first-auth and stays out of the step-up set"
        );
        for scope in EveConfig::CHARACTER_DETAIL_SCOPES {
            assert!(
                !EveConfig::FIRST_AUTH_SCOPES.contains(scope),
                "step-up scope {scope} must be disjoint from first-auth"
            );
        }
    }

    #[test]
    fn industry_scopes_are_the_two_stepup_scopes() {
        assert_eq!(
            EveConfig::INDUSTRY_SCOPES,
            [
                "esi-characters.read_blueprints.v1",
                "esi-industry.read_character_jobs.v1",
            ]
        );
        for scope in EveConfig::INDUSTRY_SCOPES {
            assert!(
                !EveConfig::FIRST_AUTH_SCOPES.contains(scope),
                "step-up scope {scope} must be disjoint from first-auth"
            );
        }
    }

    #[test]
    fn planets_scopes_is_the_single_stepup_scope() {
        assert_eq!(EveConfig::PLANETS_SCOPES, ["esi-planets.manage_planets.v1"]);
        for scope in EveConfig::PLANETS_SCOPES {
            assert!(
                !EveConfig::FIRST_AUTH_SCOPES.contains(scope),
                "step-up scope {scope} must be disjoint from first-auth"
            );
        }
    }

    #[test]
    fn fittings_scopes_is_the_single_stepup_scope() {
        assert_eq!(
            EveConfig::FITTINGS_SCOPES,
            ["esi-fittings.read_fittings.v1"]
        );
        for scope in EveConfig::FITTINGS_SCOPES {
            assert!(
                !EveConfig::FIRST_AUTH_SCOPES.contains(scope),
                "step-up scope {scope} must be disjoint from first-auth"
            );
        }
    }

    #[test]
    fn fittings_write_scopes_is_the_single_stepup_scope() {
        assert_eq!(
            EveConfig::FITTINGS_WRITE_SCOPES,
            ["esi-fittings.write_fittings.v1"]
        );
        for scope in EveConfig::FITTINGS_WRITE_SCOPES {
            assert!(
                !EveConfig::FIRST_AUTH_SCOPES.contains(scope),
                "step-up scope {scope} must be disjoint from first-auth"
            );
            assert!(
                !EveConfig::FITTINGS_SCOPES.contains(scope),
                "write scope {scope} must be disjoint from the read group"
            );
        }
    }

    #[test]
    fn structure_scopes_is_the_single_stepup_scope() {
        assert_eq!(
            EveConfig::STRUCTURE_SCOPES,
            ["esi-universe.read_structures.v1"]
        );
        for scope in EveConfig::STRUCTURE_SCOPES {
            assert!(
                !EveConfig::FIRST_AUTH_SCOPES.contains(scope),
                "step-up scope {scope} must be disjoint from first-auth"
            );
        }
    }

    #[test]
    fn portrait_url_shape() {
        assert_eq!(
            EveConfig::portrait_url(123, 128),
            "https://images.evetech.net/characters/123/portrait?size=128"
        );
    }

    #[test]
    fn corporation_logo_url_shape() {
        assert_eq!(
            EveConfig::corporation_logo_url(1000166, 64),
            "https://images.evetech.net/corporations/1000166/logo?size=64"
        );
    }

    #[test]
    fn alliance_logo_url_shape() {
        assert_eq!(
            EveConfig::alliance_logo_url(99003581, 64),
            "https://images.evetech.net/alliances/99003581/logo?size=64"
        );
    }

    #[test]
    fn faction_logo_url_shape() {
        assert_eq!(
            EveConfig::faction_logo_url(500001, 64),
            "https://images.evetech.net/corporations/500001/logo?size=64"
        );
    }

    #[test]
    fn jwks_and_metadata_urls_are_on_oauth_host() {
        let host_prefix = format!("https://{}/", EveConfig::OAUTH_HOST);
        assert!(EveConfig::OAUTH_METADATA_URL.starts_with(&host_prefix));
        assert!(EveConfig::OAUTH_JWKS_URL.starts_with(&host_prefix));
    }

    #[test]
    fn now_unix_is_plausible() {
        assert!(now_unix() > 1_700_000_000);
    }
}
